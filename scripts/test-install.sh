#!/usr/bin/env bash
# Simula la instalación de MiSO Desktop en una imagen de disco, sin la GUI de
# Calamares: extrae el sistema del ISO (unpackfs), ejecuta la post-instalación
# real (/etc/calamares/scripts/miso-postinstall.sh) e instala GRUB BIOS + UEFI.
#
# Sirve para validar la Fase 3 de forma reproducible y sin clics.
#
# Uso:
#   sudo bash scripts/test-install.sh [opciones]
#
# Opciones:
#   --iso PATH     ISO de escritorio (por defecto: out/miso-desktop-*-desktop-amd64.iso)
#   --img PATH     Imagen de disco de salida (por defecto: <tmp>/miso-install/disk.img)
#   --size SIZE    Tamaño de la imagen (por defecto: 12G)
#   --fs ext4|btrfs  Sistema de archivos raíz (por defecto: btrfs)
#   --user NAME    Usuario a crear (por defecto: alumno)
#   --password PW  Contraseña del usuario (por defecto: alumno)
#   --no-uefi      No instalar el cargador UEFI
#   --keep         No borrar montajes temporales al fallar

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ISO=""
IMG=""
SIZE="12G"
FS="btrfs"
USER_NAME="alumno"
USER_PASSWORD="alumno"
DO_UEFI=1
KEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="${2:?}"; shift 2 ;;
    --img) IMG="${2:?}"; shift 2 ;;
    --size) SIZE="${2:?}"; shift 2 ;;
    --fs) FS="${2:?}"; shift 2 ;;
    --user) USER_NAME="${2:?}"; shift 2 ;;
    --password) USER_PASSWORD="${2:?}"; shift 2 ;;
    --no-uefi) DO_UEFI=0; shift ;;
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "Ejecuta como root (sudo)." >&2; exit 1; }

if [[ -z "$ISO" ]]; then
  ISO="$(ls -1 "${PROJECT_ROOT}"/out/miso-desktop-*-desktop-amd64.iso 2>/dev/null | sort -V | tail -n 1 || true)"
fi
[[ -f "$ISO" ]] || { echo "No se encontró la ISO. Usa --iso PATH." >&2; exit 1; }

if [[ -z "$IMG" ]]; then
  IMG="/var/tmp/miso-install/disk.img"
fi
mkdir -p "$(dirname "$IMG")"

case "$FS" in
  ext4) MKFS=(mkfs.ext4 -q -F -L MISO) ;;
  btrfs) MKFS=(mkfs.btrfs -q -f -L MISO) ;;
  *) echo "--fs debe ser ext4 o btrfs" >&2; exit 1 ;;
esac

ISO_MNT="/var/tmp/miso-install/iso"
TARGET="/var/tmp/miso-install/target"
LOOP=""

cleanup() {
  set +e
  for d in run sys proc dev/pts dev; do
    mountpoint -q "${TARGET}/${d}" && umount -R "${TARGET}/${d}"
  done
  mountpoint -q "${TARGET}/boot/efi" && umount "${TARGET}/boot/efi"
  mountpoint -q "${TARGET}/.snapshots" && umount "${TARGET}/.snapshots"
  mountpoint -q "${TARGET}/home" && umount "${TARGET}/home"
  mountpoint -q "$TARGET" && umount "$TARGET"
  mountpoint -q "/var/tmp/miso-install/top" && umount "/var/tmp/miso-install/top"
  mountpoint -q "$ISO_MNT" && umount "$ISO_MNT"
  [[ -n "$LOOP" ]] && losetup -d "$LOOP" 2>/dev/null
  if [[ $KEEP -eq 0 ]]; then
    rmdir "$TARGET" "$ISO_MNT" 2>/dev/null
  fi
}
trap cleanup EXIT

echo "[miso-install] ISO:   $ISO"
echo "[miso-install] Imagen: $IMG ($SIZE, $FS)"

# 1. Imagen de disco con tabla GPT: BIOS boot + ESP + raíz.
REUSE=0
[[ -s "$IMG" ]] && REUSE=1

if [[ $REUSE -eq 0 ]]; then
  rm -f "$IMG"
  truncate -s "$SIZE" "$IMG"
  sgdisk -Z "$IMG" >/dev/null
  sgdisk -n 1:2048:+2M   -t 1:ef02 -c 1:BIOS "$IMG" >/dev/null
  sgdisk -n 2:0:+512M    -t 2:ef00 -c 2:ESP  "$IMG" >/dev/null
  sgdisk -n 3:0:0        -t 3:8300 -c 3:MISO "$IMG" >/dev/null
fi

LOOP="$(losetup --find --show -P "$IMG")"
echo "[miso-install] Loop: $LOOP"
udevadm settle 2>/dev/null || sleep 2

if [[ $REUSE -eq 0 ]]; then
  mkfs.vfat -F32 -n ESP "${LOOP}p2" >/dev/null
  "${MKFS[@]}" "${LOOP}p3"
fi

# 2. Montar destino y extraer el sistema del ISO.
mkdir -p "$ISO_MNT" "$TARGET"
TOP_MNT="/var/tmp/miso-install/top"

if [[ "$FS" == "btrfs" ]]; then
  if [[ $REUSE -eq 0 ]]; then
    mkdir -p "$TOP_MNT"
    mount "${LOOP}p3" "$TOP_MNT"
    btrfs subvolume create "$TOP_MNT/@" >/dev/null
    btrfs subvolume create "$TOP_MNT/@home" >/dev/null
    btrfs subvolume create "$TOP_MNT/@snapshots" >/dev/null
    umount "$TOP_MNT"
  fi
  mount -o subvol=@ "${LOOP}p3" "$TARGET"
else
  mount "${LOOP}p3" "$TARGET"
fi

if [[ $REUSE -eq 0 ]]; then
  mount -o loop,ro "$ISO" "$ISO_MNT"
  echo "[miso-install] Extrayendo el sistema (unpackfs)"
  unsquashfs -q -d "$TARGET" "${ISO_MNT}/live/filesystem.squashfs"
else
  echo "[miso-install] Reutilizando imagen existente: $IMG"
fi

if [[ "$FS" == "btrfs" ]]; then
  mkdir -p "${TARGET}/home" "${TARGET}/.snapshots"
  mount -o subvol=@home "${LOOP}p3" "${TARGET}/home"
  mount -o subvol=@snapshots "${LOOP}p3" "${TARGET}/.snapshots"
fi

mkdir -p "${TARGET}/boot/efi"
mount "${LOOP}p2" "${TARGET}/boot/efi"

# 3. fstab y datos de la máquina (lo que hace Calamares en el sistema real).
UUID_ROOT="$(blkid -s UUID -o value "${LOOP}p3")"
UUID_ESP="$(blkid -s UUID -o value "${LOOP}p2")"
if [[ "$FS" == "btrfs" ]]; then
  {
    echo "# /etc/fstab: MiSO Desktop"
    echo "UUID=${UUID_ROOT}  /            btrfs  defaults,noatime,subvol=@           0 1"
    echo "UUID=${UUID_ROOT}  /home        btrfs  defaults,noatime,subvol=@home       0 1"
    echo "UUID=${UUID_ROOT}  /.snapshots  btrfs  defaults,noatime,subvol=@snapshots  0 1"
    echo "UUID=${UUID_ESP}   /boot/efi    vfat   umask=0077                          0 1"
  } > "${TARGET}/etc/fstab"
else
  {
    echo "# /etc/fstab: MiSO Desktop"
    echo "UUID=${UUID_ROOT}  /          ${FS}   defaults,noatime  0 1"
    echo "UUID=${UUID_ESP}   /boot/efi  vfat   umask=0077        0 1"
  } > "${TARGET}/etc/fstab"
fi

# Usa la versión actual del repo: permite iterar el instalador sin reconstruir
# el ISO. En una instalación real el script viene dentro de /etc/calamares.
install -Dm755 "${PROJECT_ROOT}/installer/calamares/scripts/miso-postinstall.sh" \
  "${TARGET}/etc/calamares/scripts/miso-postinstall.sh"

# Herramientas actuales del repo (misma idea: iterar sin reconstruir el ISO).
for tool in miso miso-updated miso-rings miso-doctor miso-welcome; do
  [[ -f "${PROJECT_ROOT}/tools/bin/${tool}" ]] || continue
  install -Dm755 "${PROJECT_ROOT}/tools/bin/${tool}" "${TARGET}/usr/bin/${tool}"
done
install -Dm755 "${PROJECT_ROOT}/tools/libexec/misod" \
  "${TARGET}/usr/libexec/miso/misod"

echo "miso" > "${TARGET}/etc/hostname"
grep -q '^127.0.1.1' "${TARGET}/etc/hosts" || \
  echo "127.0.1.1 miso" >> "${TARGET}/etc/hosts"
cp -L /etc/resolv.conf "${TARGET}/etc/resolv.conf"

# 4. Chroot: post-instalación real, usuario, GRUB e initramfs.
for d in dev dev/pts proc sys run; do
  mkdir -p "${TARGET}/${d}"
  mount --bind "/${d}" "${TARGET}/${d}"
done

chroot "$TARGET" /bin/bash -euo pipefail <<CHROOT
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

echo "[chroot] Post-instalación de Calamares"
/etc/calamares/scripts/miso-postinstall.sh

echo "[chroot] Creando usuario ${USER_NAME}"
if ! id "${USER_NAME}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "${USER_NAME}" \\
    -G sudo,audio,video,plugdev,netdev,render,adm,systemd-journal "${USER_NAME}"
fi
printf '%s:%s\n' "${USER_NAME}" "${USER_PASSWORD}" | chpasswd

echo "[chroot] Identidad de máquina"
systemd-machine-id-setup >/dev/null 2>&1 || true

echo "[chroot] initramfs"
update-initramfs -u -k all

echo "[chroot] GRUB BIOS"
cat >> /etc/default/grub <<'EOF'
GRUB_DISABLE_OS_PROBER=true
GRUB_TIMEOUT=5
EOF
grub-install --target=i386-pc --boot-directory=/boot "${LOOP}"

if [[ "${DO_UEFI}" == "1" ]]; then
  echo "[chroot] GRUB UEFI"
  grub-install --target=x86_64-efi --efi-directory=/boot/efi \\
    --bootloader-id=MiSO --removable
fi

update-grub

echo "[chroot] Comprobaciones"
id "${USER_NAME}"
! id live >/dev/null 2>&1 && echo "OK: usuario live eliminado"
getent passwd root | grep -q '/usr/sbin/nologin' && echo "OK: root sin login"
test -f /var/lib/miso/installed && echo "OK: marca de instalación"
CHROOT

echo "[miso-install] Instalación completada en $IMG"
echo "[miso-install] Arranca con: scripts/serial-smoke.ps1 -Disk \"$IMG\""
