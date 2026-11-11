#!/usr/bin/env bash
# Limpia los artefactos de build de MiSO Desktop.
#
# Uso:
#   sudo bash build/clean.sh          # rootfs, staging e ISOs
#   sudo bash build/clean.sh --keep-iso
#   sudo bash build/clean.sh --work-only

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=config/build.conf
source "${SCRIPT_DIR}/config/build.conf"

KEEP_ISO=0
WORK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --keep-iso) KEEP_ISO=1 ;;
    --work-only) WORK_ONLY=1 ;;
    -h|--help)
      sed -n '2,9p' "$0"
      exit 0
      ;;
    *)
      die "Opción desconocida: $arg"
      ;;
  esac
done

require_root

if [[ -d "${WORKDIR}" ]]; then
  log "Desmontando y eliminando ${WORKDIR}"
  umount_chroot "${WORKDIR}/rootfs" 2>/dev/null || true
  rm -rf "${WORKDIR}"
else
  log "No existe ${WORKDIR}"
fi

if [[ $WORK_ONLY -eq 0 ]]; then
  if [[ $KEEP_ISO -eq 0 ]]; then
    log "Eliminando ISOs de ${OUTDIR}"
    rm -f "${OUTDIR}"/*.iso "${OUTDIR}"/*.iso.sha256 2>/dev/null || true
  else
    log "Conservando ISOs en ${OUTDIR}"
  fi
fi

ok "Limpieza completada"
