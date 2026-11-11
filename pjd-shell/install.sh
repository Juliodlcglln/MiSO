#!/usr/bin/env bash
# Instala PJD Shell en un rootfs de MiSO.
#
# Uso: bash pjd-shell/install.sh <rootfs>

set -Eeuo pipefail

ROOTFS="${1:-}"
[[ -n "$ROOTFS" ]] || { echo "Uso: $0 <rootfs>" >&2; exit 1; }
[[ -d "$ROOTFS" ]] || { echo "No existe el rootfs: $ROOTFS" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${ROOTFS}/usr/share/plasma/look-and-feel/org.miso.pjd.desktop"

mkdir -p "$DEST"
cp -a "${HERE}/metadata.json" "$DEST/"
cp -a "${HERE}/contents" "$DEST/"

install -Dm644 "${HERE}/color-schemes/MiSO.colors" \
  "${ROOTFS}/usr/share/color-schemes/MiSO.colors"

install -Dm644 "${HERE}/skel/kdeglobals" \
  "${ROOTFS}/etc/skel/.config/kdeglobals"

install -Dm755 "${HERE}/bin/pjd" "${ROOTFS}/usr/bin/pjd"

# Aplicar también al usuario live si ya existe.
if [[ -d "${ROOTFS}/home/live" ]]; then
  install -Dm644 "${HERE}/skel/kdeglobals" \
    "${ROOTFS}/home/live/.config/kdeglobals"
  chroot "$ROOTFS" chown -R 1000:1000 /home/live/.config 2>/dev/null || true
fi

echo "[miso] PJD Shell instalado en ${DEST}"
