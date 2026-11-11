#!/usr/bin/env bash
# Arranca una ISO de MiSO Desktop en QEMU desde Linux.
#
# Uso:
#   bash scripts/run-qemu.sh [iso] [--uefi] [--tcg] [--disk disco.qcow2]

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ISO="${PROJECT_ROOT}/out/miso-desktop-0.1.0-core-amd64.iso"
UEFI=0
TCG=0
DISK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uefi) UEFI=1; shift ;;
    --tcg) TCG=1; shift ;;
    --disk) DISK="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    -*)
      echo "Opción desconocida: $1" >&2
      exit 2
      ;;
    *)
      ISO="$1"
      shift
      ;;
  esac
done

[[ -f "$ISO" ]] || {
  echo "No existe la ISO: $ISO" >&2
  echo "Construye primero: sudo bash build/build-iso.sh --profile core" >&2
  exit 1
}

command -v qemu-system-x86_64 >/dev/null 2>&1 || {
  echo "Falta qemu-system-x86_64." >&2
  exit 1
}

ARGS=(
  -name "MiSO Desktop"
  -machine q35
  -smp 4
  -m 4G
)

if [[ $TCG -eq 1 ]]; then
  ARGS+=(-accel tcg -cpu max)
elif [[ -w /dev/kvm ]]; then
  ARGS+=(-accel kvm -cpu host)
else
  ARGS+=(-accel tcg -cpu max)
fi

if [[ $UEFI -eq 1 ]]; then
  CODE=""
  VARS_TEMPLATE=""
  for candidate in \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /usr/share/qemu/OVMF_CODE.fd; do
    [[ -f "$candidate" ]] && { CODE="$candidate"; break; }
  done
  for candidate in \
    /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/OVMF/OVMF_VARS_4M.fd \
    /usr/share/edk2/x64/OVMF_VARS.fd \
    /usr/share/qemu/OVMF_VARS.fd; do
    [[ -f "$candidate" ]] && { VARS_TEMPLATE="$candidate"; break; }
  done

  [[ -n "$CODE" && -n "$VARS_TEMPLATE" ]] || {
    echo "No se encontró OVMF. Instala el paquete ovmf o arranca sin --uefi." >&2
    exit 1
  }

  VARS="${TMPDIR:-/tmp}/miso-ovmf-vars.fd"
  cp -f "$VARS_TEMPLATE" "$VARS"
  ARGS+=(
    -drive "if=pflash,format=raw,readonly=on,file=${CODE}"
    -drive "if=pflash,format=raw,file=${VARS}"
  )
fi

ARGS+=(
  -drive "file=${ISO},media=cdrom,readonly=on"
  -boot d
  -device virtio-vga
  -nic "user,model=virtio-net-pci"
  -device qemu-xhci
  -usb
  -serial "file:${PROJECT_ROOT}/out/qemu-serial.log"
)

if [[ -n "$DISK" ]]; then
  if [[ ! -f "$DISK" ]]; then
    qemu-img create -f qcow2 "$DISK" 40G
  fi
  ARGS+=(-drive "file=${DISK},if=virtio,format=qcow2")
fi

echo "MiSO Desktop - QEMU"
echo "  ISO:  $ISO"
echo "  Modo: $([[ $UEFI -eq 1 ]] && echo UEFI || echo BIOS)"
echo

exec qemu-system-x86_64 "${ARGS[@]}"
