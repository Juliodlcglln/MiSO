#!/usr/bin/env bash
# Genera los assets raster de MiSO y los instala en un rootfs.
#
# Uso: bash branding/render-assets.sh <rootfs>

set -Eeuo pipefail

ROOTFS="${1:-}"
[[ -n "$ROOTFS" ]] || { echo "Uso: $0 <rootfs>" >&2; exit 1; }
[[ -d "$ROOTFS" ]] || { echo "No existe el rootfs: $ROOTFS" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOGO_SVG="${HERE}/logo/miso-logo.svg"
WALL_SVG="${HERE}/wallpapers/miso-default.svg"

render() {
  local svg="$1" out="$2" width="$3" height="$4"
  mkdir -p "$(dirname "$out")"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$width" -h "$height" "$svg" -o "$out"
  elif command -v convert >/dev/null 2>&1; then
    convert -background none -density 192 "$svg" -resize "${width}x${height}!" "$out"
  else
    echo "[warn] No hay rsvg-convert ni ImageMagick; se omite $out" >&2
    return 1
  fi
}

echo "[miso] Generando assets de branding"
render "$LOGO_SVG" "${ROOTFS}/usr/share/pixmaps/miso-logo.png" 256 256 || true
render "$LOGO_SVG" "${ROOTFS}/usr/share/pixmaps/miso-logo-64.png" 64 64 || true
render "$WALL_SVG" "${ROOTFS}/usr/share/wallpapers/miso-default.png" 1920 1080 || true
render "$WALL_SVG" "${ROOTFS}/usr/share/backgrounds/miso-default.png" 1920 1080 || true

# Plymouth
install -Dm644 "${HERE}/plymouth/miso.plymouth" \
  "${ROOTFS}/usr/share/plymouth/themes/miso/miso.plymouth"
install -Dm644 "${HERE}/plymouth/miso.script" \
  "${ROOTFS}/usr/share/plymouth/themes/miso/miso.script"
render "$LOGO_SVG" "${ROOTFS}/usr/share/plymouth/themes/miso/logo.png" 192 192 || true
install -Dm644 "${HERE}/plymouth/plymouthd.conf" \
  "${ROOTFS}/etc/plymouth/plymouthd.conf"

# GRUB
mkdir -p "${ROOTFS}/boot/grub/themes/miso"
cp -a "${HERE}/grub/." "${ROOTFS}/boot/grub/themes/miso/"

# SDDM
install -Dm644 "${HERE}/sddm/10-miso.conf" \
  "${ROOTFS}/etc/sddm.conf.d/10-miso.conf"
# Branding del tema Breeze (fondo, logo y color de MiSO).
if [[ -d "${ROOTFS}/usr/share/sddm/themes/breeze" ]]; then
  install -Dm644 "${HERE}/sddm/theme.conf.user" \
    "${ROOTFS}/usr/share/sddm/themes/breeze/theme.conf.user"
fi

# Logo vectorial
install -Dm644 "$LOGO_SVG" "${ROOTFS}/usr/share/pixmaps/miso-logo.svg"

# Iconos del tema hicolor: Plasma resuelve aquí "miso-logo" y "start-here-miso".
ICON_APPS="${ROOTFS}/usr/share/icons/hicolor"
install -Dm644 "$LOGO_SVG" "${ICON_APPS}/scalable/apps/miso-logo.svg"
render "$LOGO_SVG" "${ICON_APPS}/256x256/apps/miso-logo.png" 256 256 || true
render "$LOGO_SVG" "${ICON_APPS}/64x64/apps/miso-logo.png" 64 64 || true
install -Dm644 "$LOGO_SVG" "${ICON_APPS}/scalable/apps/start-here-miso.svg"
render "$LOGO_SVG" "${ICON_APPS}/256x256/apps/start-here-miso.png" 256 256 || true
render "$LOGO_SVG" "${ICON_APPS}/64x64/apps/start-here-miso.png" 64 64 || true

# Refrescar la caché de iconos si el rootfs ya tiene gtk-update-icon-cache.
if [[ -x "${ROOTFS}/usr/bin/gtk-update-icon-cache" ]]; then
  chroot "$ROOTFS" gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
fi

# Calamares
CAL_BRAND="${ROOTFS}/etc/calamares/branding/miso"
if [[ -d "$CAL_BRAND" ]]; then
  render "$LOGO_SVG" "${CAL_BRAND}/logo.png" 256 256 || true
  render "$LOGO_SVG" "${CAL_BRAND}/icon.png" 64 64 || true
  render "$WALL_SVG" "${CAL_BRAND}/welcome.png" 900 500 || true
fi

echo "[miso] Branding instalado"
