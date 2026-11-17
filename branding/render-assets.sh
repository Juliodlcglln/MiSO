#!/usr/bin/env bash
# Genera los assets raster de WanukuOS (y compatibilidad MiSO) y los instala en un rootfs.
#
# Uso: bash branding/render-assets.sh <rootfs>

set -Eeuo pipefail

ROOTFS="${1:-}"
[[ -n "$ROOTFS" ]] || { echo "Uso: $0 <rootfs>" >&2; exit 1; }
[[ -d "$ROOTFS" ]] || { echo "No existe el rootfs: $ROOTFS" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOGO_SVG="${HERE}/logo/wanuku-logo.svg"
[[ -f "$LOGO_SVG" ]] || LOGO_SVG="${HERE}/logo/miso-logo.svg"

WALL_SVG="${HERE}/wallpapers/wanuku-default.svg"
[[ -f "$WALL_SVG" ]] || WALL_SVG="${HERE}/wallpapers/miso-default.svg"

LOGO_PNG_256="${HERE}/logo/wanuku-logo.png"
LOGO_PNG_64="${HERE}/logo/wanuku-logo-64.png"
WALL_PNG="${HERE}/wallpapers/wanuku-default.png"
WALL_JPG="${HERE}/wallpapers/wanuku-fondo.jpg"

echo "[wanuku] Instalando assets de branding WanukuOS"

# 1. Wallpapers y fondos
mkdir -p "${ROOTFS}/usr/share/wallpapers" "${ROOTFS}/usr/share/backgrounds"
if [[ -f "$WALL_PNG" ]]; then
  cp -f "$WALL_PNG" "${ROOTFS}/usr/share/wallpapers/wanuku-default.png"
  cp -f "$WALL_PNG" "${ROOTFS}/usr/share/wallpapers/miso-default.png"
  cp -f "$WALL_PNG" "${ROOTFS}/usr/share/backgrounds/wanuku-default.png"
  cp -f "$WALL_PNG" "${ROOTFS}/usr/share/backgrounds/miso-default.png"
fi
# Fondo de escritorio elegido para WanukuOS (fotografía 16:9).
if [[ -f "$WALL_JPG" ]]; then
  install -Dm644 "$WALL_JPG" "${ROOTFS}/usr/share/wallpapers/wanuku-fondo.jpg"
  install -Dm644 "$WALL_JPG" "${ROOTFS}/usr/share/backgrounds/wanuku-fondo.jpg"
fi

# 2. Pixmaps y logos del sistema
mkdir -p "${ROOTFS}/usr/share/pixmaps"
if [[ -f "$LOGO_PNG_256" ]]; then
  cp -f "$LOGO_PNG_256" "${ROOTFS}/usr/share/pixmaps/wanuku-logo.png"
  cp -f "$LOGO_PNG_256" "${ROOTFS}/usr/share/pixmaps/miso-logo.png"
fi
if [[ -f "$LOGO_PNG_64" ]]; then
  cp -f "$LOGO_PNG_64" "${ROOTFS}/usr/share/pixmaps/wanuku-logo-64.png"
  cp -f "$LOGO_PNG_64" "${ROOTFS}/usr/share/pixmaps/miso-logo-64.png"
fi
if [[ -f "$LOGO_SVG" ]]; then
  cp -f "$LOGO_SVG" "${ROOTFS}/usr/share/pixmaps/wanuku-logo.svg"
  cp -f "$LOGO_SVG" "${ROOTFS}/usr/share/pixmaps/miso-logo.svg"
fi

# 3. Plymouth
mkdir -p "${ROOTFS}/usr/share/plymouth/themes/miso" "${ROOTFS}/etc/plymouth"
install -Dm644 "${HERE}/plymouth/miso.plymouth" \
  "${ROOTFS}/usr/share/plymouth/themes/miso/miso.plymouth"
install -Dm644 "${HERE}/plymouth/miso.script" \
  "${ROOTFS}/usr/share/plymouth/themes/miso/miso.script"
if [[ -f "${HERE}/plymouth/logo.png" ]]; then
  cp -f "${HERE}/plymouth/logo.png" "${ROOTFS}/usr/share/plymouth/themes/miso/logo.png"
fi
install -Dm644 "${HERE}/plymouth/plymouthd.conf" \
  "${ROOTFS}/etc/plymouth/plymouthd.conf"

# 4. GRUB
mkdir -p "${ROOTFS}/boot/grub/themes/miso"
cp -a "${HERE}/grub/." "${ROOTFS}/boot/grub/themes/miso/"
if [[ -f "$WALL_PNG" ]]; then
  cp -f "$WALL_PNG" "${ROOTFS}/boot/grub/themes/miso/background.png" 2>/dev/null || true
fi

# 5. SDDM
install -Dm644 "${HERE}/sddm/10-miso.conf" \
  "${ROOTFS}/etc/sddm.conf.d/10-miso.conf"
if [[ -d "${ROOTFS}/usr/share/sddm/themes/breeze" ]]; then
  install -Dm644 "${HERE}/sddm/theme.conf.user" \
    "${ROOTFS}/usr/share/sddm/themes/breeze/theme.conf.user"
fi

# 6. Iconos del tema hicolor
ICON_APPS="${ROOTFS}/usr/share/icons/hicolor"
mkdir -p "${ICON_APPS}/scalable/apps" "${ICON_APPS}/256x256/apps" "${ICON_APPS}/64x64/apps"

if [[ -f "$LOGO_SVG" ]]; then
  cp -f "$LOGO_SVG" "${ICON_APPS}/scalable/apps/wanuku-logo.svg"
  cp -f "$LOGO_SVG" "${ICON_APPS}/scalable/apps/start-here-wanuku.svg"
  cp -f "$LOGO_SVG" "${ICON_APPS}/scalable/apps/miso-logo.svg"
  cp -f "$LOGO_SVG" "${ICON_APPS}/scalable/apps/start-here-miso.svg"
fi

if [[ -f "$LOGO_PNG_256" ]]; then
  cp -f "$LOGO_PNG_256" "${ICON_APPS}/256x256/apps/wanuku-logo.png"
  cp -f "$LOGO_PNG_256" "${ICON_APPS}/256x256/apps/start-here-wanuku.png"
  cp -f "$LOGO_PNG_256" "${ICON_APPS}/256x256/apps/miso-logo.png"
  cp -f "$LOGO_PNG_256" "${ICON_APPS}/256x256/apps/start-here-miso.png"
fi

if [[ -f "$LOGO_PNG_64" ]]; then
  cp -f "$LOGO_PNG_64" "${ICON_APPS}/64x64/apps/wanuku-logo.png"
  cp -f "$LOGO_PNG_64" "${ICON_APPS}/64x64/apps/start-here-wanuku.png"
  cp -f "$LOGO_PNG_64" "${ICON_APPS}/64x64/apps/miso-logo.png"
  cp -f "$LOGO_PNG_64" "${ICON_APPS}/64x64/apps/start-here-miso.png"
fi

if [[ -x "${ROOTFS}/usr/bin/gtk-update-icon-cache" ]]; then
  chroot "$ROOTFS" gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
fi

# 7. Calamares branding
CAL_BRAND="${ROOTFS}/etc/calamares/branding/miso"
if [[ -d "$CAL_BRAND" ]]; then
  if [[ -f "${HERE}/../installer/calamares/branding/miso/logo.png" ]]; then
    cp -f "${HERE}/../installer/calamares/branding/miso/logo.png" "${CAL_BRAND}/logo.png"
  fi
  if [[ -f "${HERE}/../installer/calamares/branding/miso/icon.png" ]]; then
    cp -f "${HERE}/../installer/calamares/branding/miso/icon.png" "${CAL_BRAND}/icon.png"
  fi
  if [[ -f "${HERE}/../installer/calamares/branding/miso/welcome.png" ]]; then
    cp -f "${HERE}/../installer/calamares/branding/miso/welcome.png" "${CAL_BRAND}/welcome.png"
  fi
fi

echo "[wanuku] Branding instalado exitosamente"
