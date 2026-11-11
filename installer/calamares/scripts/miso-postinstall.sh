#!/usr/bin/env bash
# Post-instalación de MiSO Desktop.
# Calamares lo ejecuta dentro del sistema destino (chroot).

set -Eeuo pipefail

LOG="/var/log/miso-postinstall.log"
mkdir -p /var/log
exec > >(tee -a "$LOG") 2>&1

echo "[miso] Post-instalación iniciada: $(date -Is)"

# 1. Eliminar el usuario live y sus restos.
if id live >/dev/null 2>&1; then
  userdel -r live 2>/dev/null || true
  echo "[miso] Usuario live eliminado"
fi
rm -rf /home/live
rm -f /etc/sudoers.d/90-miso-live
rm -f /etc/sddm.conf.d/20-miso-live.conf
rm -f /etc/xdg/autostart/miso-welcome.desktop

# 1b. Sin login de root en el sistema instalado.
if [ -x /usr/sbin/nologin ]; then
  usermod -s /usr/sbin/nologin root 2>/dev/null || true
fi

# 1c. Consola serie para diagnóstico y gestión headless del laboratorio.
#     Es inocua en equipos sin puerto serie.
if [ -f /etc/default/grub ]; then
  if ! grep -q 'console=ttyS0' /etc/default/grub; then
    sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash console=tty0 console=ttyS0,115200"|' \
      /etc/default/grub
  fi
fi

# 2. Servicios del sistema instalado.
systemctl enable NetworkManager.service >/dev/null 2>&1 || true
systemctl enable nftables.service >/dev/null 2>&1 || true
systemctl enable sddm.service >/dev/null 2>&1 || true
systemctl enable miso-firstboot.service >/dev/null 2>&1 || true
systemctl enable miso-boot-ok.service >/dev/null 2>&1 || true
systemctl set-default graphical.target >/dev/null 2>&1 || true

# 3. Flatpak (remoto del sistema).
if command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --system --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi

# 4. Estado de MiSO.
mkdir -p /var/lib/miso /var/lib/miso/rings
touch /var/lib/miso/installed
if findmnt -n -o FSTYPE / 2>/dev/null | grep -qx btrfs; then
  mkdir -p /.snapshots
fi

# 5. Limpieza.
apt-get clean 2>/dev/null || true
rm -rf /var/lib/apt/lists/* 2>/dev/null || true

echo "[miso] Post-instalación completada: $(date -Is)"
exit 0
