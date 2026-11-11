#!/usr/bin/env bash
# Construye una ISO live de MiSO Desktop.
#
# Uso:
#   sudo bash build/build-iso.sh [--profile core|desktop|lab] [--clean] [--no-iso]
#
# Requiere un host Debian/Ubuntu (o WSL2) con las dependencias de
# build/install-host-deps.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=config/build.conf
source "${SCRIPT_DIR}/config/build.conf"

PROFILE="${DEFAULT_PROFILE}"
CLEAN=0
NO_ISO=0

usage() {
  cat <<EOF
MiSO Desktop ${MISO_VERSION} - constructor de ISO

Uso: sudo bash build/build-iso.sh [opciones]

Opciones:
  --profile core|desktop|lab   Perfil de la imagen (por defecto: ${DEFAULT_PROFILE})
  --clean                      Borra rootfs y staging antes de empezar
  --no-iso                     Detiene el build después del squashfs
  -h, --help                   Muestra esta ayuda

Variables:
  MISO_WORKDIR   Directorio de trabajo (por defecto: /var/tmp/miso-build)
  MISO_OUTDIR    Directorio de salida   (por defecto: <proyecto>/out)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:?Falta el valor de --profile}"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#*=}"
      shift
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    --no-iso)
      NO_ISO=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Opción desconocida: $1"
      ;;
  esac
done

case "$PROFILE" in
  core|desktop|lab) ;;
  *) die "Perfil inválido: $PROFILE (usa core, desktop o lab)" ;;
esac

require_root
for cmd in debootstrap mksquashfs xorriso grub-mkrescue sha256sum; do
  require_cmd "$cmd"
done

ROOTFS="${WORKDIR}/rootfs"
ISOROOT="${WORKDIR}/isoroot"

mkdir -p "$WORKDIR" "$OUTDIR"
chmod 755 "$WORKDIR"

cleanup() {
  umount_chroot "$ROOTFS" 2>/dev/null || true
}
trap cleanup EXIT

if [[ $CLEAN -eq 1 ]]; then
  log "Limpiando ${WORKDIR}"
  cleanup
  rm -rf "$ROOTFS" "$ISOROOT"
fi

# ---------------------------------------------------------------------------
# Etapa 1: rootfs base con debootstrap
# ---------------------------------------------------------------------------
stage_prepare() {
  if [[ -f "${ROOTFS}/etc/os-release" ]]; then
    log "Reutilizando rootfs existente en ${ROOTFS}"
    return 0
  fi

  log "Etapa 1/7: debootstrap ${DEBIAN_SUITE} (${MISO_ARCH})"
  rm -rf "$ROOTFS"
  mkdir -p "$ROOTFS"

  debootstrap \
    --arch="${MISO_ARCH}" \
    --variant=minbase \
    --components="${DEBIAN_COMPONENTS}" \
    --include=ca-certificates,apt-transport-https \
    "${DEBIAN_SUITE}" "$ROOTFS" "$DEBIAN_MIRROR"

  ok "Rootfs base creado"
}

# ---------------------------------------------------------------------------
# Etapa 2: APT, locale, red y herramientas base
# ---------------------------------------------------------------------------
stage_configure() {
  log "Etapa 2/7: configurando APT y el sistema base"
  mount_chroot "$ROOTFS"

  cp -L /etc/resolv.conf "${ROOTFS}/etc/resolv.conf"

  cat > "${ROOTFS}/etc/apt/sources.list" <<EOF
deb ${DEBIAN_MIRROR} ${DEBIAN_SUITE} ${DEBIAN_COMPONENTS//,/ }
deb ${DEBIAN_MIRROR} ${DEBIAN_UPDATES} ${DEBIAN_COMPONENTS//,/ }
deb ${DEBIAN_SECURITY_MIRROR} ${DEBIAN_SECURITY} ${DEBIAN_COMPONENTS//,/ }
EOF

  chroot_run "$ROOTFS" apt-get update
  chroot_run "$ROOTFS" apt-get -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    upgrade

  chroot_run "$ROOTFS" apt-get install -y --no-install-recommends \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    systemd-sysv dbus polkitd pkexec sudo \
    locales console-setup keyboard-configuration tzdata \
    network-manager iproute2 iputils-ping \
    ca-certificates curl wget nano less bash-completion \
    btrfs-progs rsync util-linux

  ok "Sistema base configurado"
}

# ---------------------------------------------------------------------------
# Etapa 3: paquetes del perfil
# ---------------------------------------------------------------------------
stage_packages() {
  log "Etapa 3/7: instalando perfil '${PROFILE}'"

  apt_install_list "$ROOTFS" "${SCRIPT_DIR}/packages/core.list" no-recommends

  if [[ "$PROFILE" == "desktop" || "$PROFILE" == "lab" ]]; then
    apt_install_list "$ROOTFS" "${SCRIPT_DIR}/packages/desktop.list" recommends
    apt_install_list "$ROOTFS" "${SCRIPT_DIR}/packages/installer.list" recommends
  fi

  if [[ "$PROFILE" == "lab" ]]; then
    apt_install_list "$ROOTFS" "${SCRIPT_DIR}/packages/lab.list" recommends
  fi

  # ping necesita cap_net_raw; el postinst del paquete no siempre la aplica
  # dentro de un chroot sin libcap2-bin.
  if [[ -x "${ROOTFS}/usr/bin/ping" ]]; then
    chroot_run "$ROOTFS" setcap cap_net_raw+ep /usr/bin/ping 2>/dev/null || \
      warn "No se pudo aplicar cap_net_raw a ping"
  fi

  install_miso_kernel

  ok "Perfil '${PROFILE}' instalado"
}

# ---------------------------------------------------------------------------
# Kernel propio de MiSO (opcional)
# ---------------------------------------------------------------------------
install_miso_kernel() {
  local outdir="${PROJECT_ROOT}/kernel/out"
  local debs=( "${outdir}"/linux-image-*-miso_*.deb "${outdir}"/linux-headers-*-miso_*.deb )
  local deb base found=0

  for deb in "${debs[@]}"; do
    [[ -f "$deb" ]] || continue
    found=1
    base="$(basename "$deb")"
    cp -f "$deb" "${ROOTFS}/tmp/${base}"
    if chroot_run "$ROOTFS" dpkg -i "/tmp/${base}"; then
      ok "Kernel MiSO instalado: ${base}"
    else
      warn "No se pudo instalar ${base}; revisa el log del build"
    fi
    rm -f "${ROOTFS}/tmp/${base}"
  done

  if [[ $found -eq 0 ]]; then
    log "Kernel MiSO no encontrado en kernel/out; se usa el kernel de Debian"
  fi
}

# ---------------------------------------------------------------------------
# Etapa 4: identidad MiSO, herramientas, PJD, branding e instalador
# ---------------------------------------------------------------------------
stage_identity() {
  log "Etapa 4/7: aplicando identidad y configuración MiSO"

  # Configuración base versionada.
  # rsync normaliza dueño y permisos: el repo vive en un montaje de Windows
  # donde los archivos aparecen como 777 y propiedad del usuario del host.
  rsync -a --chown=root:root --chmod=D755,F644 \
    "${SCRIPT_DIR}/overlays/" "${ROOTFS}/"

  # Herramientas propias
  install -Dm755 "${PROJECT_ROOT}/tools/bin/miso"         "${ROOTFS}/usr/bin/miso"
  install -Dm755 "${PROJECT_ROOT}/tools/bin/miso-updated" "${ROOTFS}/usr/bin/miso-updated"
  install -Dm755 "${PROJECT_ROOT}/tools/bin/miso-rings"   "${ROOTFS}/usr/bin/miso-rings"
  install -Dm755 "${PROJECT_ROOT}/tools/bin/miso-doctor"  "${ROOTFS}/usr/bin/miso-doctor"
  install -Dm755 "${PROJECT_ROOT}/tools/bin/miso-welcome" "${ROOTFS}/usr/bin/miso-welcome"
  install -Dm755 "${PROJECT_ROOT}/tools/libexec/misod"    "${ROOTFS}/usr/libexec/miso/misod"

  for helper in miso-boot-ok miso-firstboot; do
    install -Dm755 "${PROJECT_ROOT}/tools/libexec/${helper}" \
      "${ROOTFS}/usr/libexec/miso/${helper}"
  done

  # Polkit
  install -Dm644 "${PROJECT_ROOT}/tools/polkit/org.miso.desktop.policy" \
    "${ROOTFS}/usr/share/polkit-1/actions/org.miso.desktop.policy"

  # Unidades systemd
  cp -a "${PROJECT_ROOT}/tools/systemd/." "${ROOTFS}/etc/systemd/system/"
  find "${ROOTFS}/etc/systemd/system" -maxdepth 1 -name 'miso-*.service' \
    -exec chown root:root {} + -exec chmod 644 {} +

  # Listas de anillos disponibles
  install -Dm644 "${SCRIPT_DIR}/packages/lab.list" \
    "${ROOTFS}/usr/share/miso/rings/lab.list"
  install -Dm644 "${PROJECT_ROOT}/repos/rings.yaml" \
    "${ROOTFS}/etc/miso/rings.yaml"

  # Instalador (solo perfiles con escritorio)
  if [[ "$PROFILE" == "desktop" || "$PROFILE" == "lab" ]]; then
    mkdir -p "${ROOTFS}/etc/calamares"
    cp -a "${PROJECT_ROOT}/installer/calamares/." "${ROOTFS}/etc/calamares/"
    chmod 755 "${ROOTFS}/etc/calamares/scripts/miso-postinstall.sh" 2>/dev/null || true

    # Autologin solo para la sesión live; la post-instalación lo elimina.
    mkdir -p "${ROOTFS}/etc/sddm.conf.d"
    cat > "${ROOTFS}/etc/sddm.conf.d/20-miso-live.conf" <<EOF
[Autologin]
User=${MISO_LIVE_USER}
Session=plasma
Relogin=false
EOF
  fi

  # Branding (genera PNG y copia temas)
  if [[ -f "${PROJECT_ROOT}/branding/render-assets.sh" ]]; then
    bash "${PROJECT_ROOT}/branding/render-assets.sh" "$ROOTFS" || \
      warn "No se pudieron generar todos los assets de branding"
  fi

  # PJD Shell
  if [[ -f "${PROJECT_ROOT}/pjd-shell/install.sh" ]]; then
    bash "${PROJECT_ROOT}/pjd-shell/install.sh" "$ROOTFS" || \
      warn "PJD Shell no se pudo instalar por completo"
  fi

  # Normalizar dueño y permisos de los árboles copiados desde el repo.
  local norm
  for norm in \
    "etc/calamares" \
    "usr/share/plasma/look-and-feel/org.miso.pjd.desktop" \
    "usr/share/color-schemes" \
    "usr/share/doc/miso-desktop" \
    "boot/grub/themes/miso"; do
    [[ -e "${ROOTFS}/${norm}" ]] || continue
    chown -R root:root "${ROOTFS}/${norm}"
    find "${ROOTFS}/${norm}" -type d -exec chmod 755 {} +
    find "${ROOTFS}/${norm}" -type f -exec chmod 644 {} +
  done
  [[ -f "${ROOTFS}/etc/calamares/scripts/miso-postinstall.sh" ]] && \
    chmod 755 "${ROOTFS}/etc/calamares/scripts/miso-postinstall.sh"

  # El lanzador del instalador en el escritorio debe ser ejecutable para que
  # Plasma lo trate como un acceso directo de confianza.
  chmod 755 "${ROOTFS}/etc/skel/Desktop/miso-install.desktop" 2>/dev/null || true

  # Documentación dentro del sistema
  mkdir -p "${ROOTFS}/usr/share/doc/miso-desktop"
  cp -a "${PROJECT_ROOT}/docs/." "${ROOTFS}/usr/share/doc/miso-desktop/"
  cp -a "${PROJECT_ROOT}/README.md" "${ROOTFS}/usr/share/doc/miso-desktop/README.md"
  if [[ -f "${PROJECT_ROOT}/LICENSE" ]]; then
    cp -a "${PROJECT_ROOT}/LICENSE" "${ROOTFS}/usr/share/doc/miso-desktop/LICENSE"
  fi

  # Versión y estado
  mkdir -p "${ROOTFS}/etc/miso" "${ROOTFS}/var/lib/miso"
  cat > "${ROOTFS}/etc/miso/release" <<EOF
MISO_VERSION=${MISO_VERSION}
MISO_CODENAME=${MISO_CODENAME}
MISO_BASE=debian-13-${DEBIAN_SUITE}
MISO_PROFILE=${PROFILE}
MISO_CHANNEL=stable
EOF
  printf '%s\n' "$PROFILE" > "${ROOTFS}/etc/miso/active-ring"

  # Locale, teclado y zona horaria
  sed -i "s/^# *${MISO_LOCALE} UTF-8/${MISO_LOCALE} UTF-8/" "${ROOTFS}/etc/locale.gen" || true
  grep -q "^${MISO_LOCALE} UTF-8" "${ROOTFS}/etc/locale.gen" || \
    printf '%s UTF-8\n' "$MISO_LOCALE" >> "${ROOTFS}/etc/locale.gen"
  chroot_run "$ROOTFS" locale-gen
  printf 'LANG=%s\n' "$MISO_LOCALE" > "${ROOTFS}/etc/default/locale"

  cat > "${ROOTFS}/etc/default/keyboard" <<EOF
XKBMODEL="pc105"
XKBLAYOUT="${MISO_KEYMAP}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

  ln -sf "/usr/share/zoneinfo/${MISO_TIMEZONE}" "${ROOTFS}/etc/localtime"
  printf '%s\n' "$MISO_TIMEZONE" > "${ROOTFS}/etc/timezone"

  # Usuario live (se elimina en la post-instalación)
  if ! chroot_run "$ROOTFS" id "${MISO_LIVE_USER}" >/dev/null 2>&1; then
    for group in audio video plugdev netdev render; do
      chroot_run "$ROOTFS" getent group "$group" >/dev/null 2>&1 || \
        chroot_run "$ROOTFS" groupadd "$group" || true
    done
    chroot_run "$ROOTFS" useradd -m -s /bin/bash \
      -c "$MISO_LIVE_FULLNAME" \
      -G sudo,audio,video,plugdev,netdev,render,adm,systemd-journal \
      "$MISO_LIVE_USER"
  fi
  # Garantiza grupos correctos también en rebuilds incrementales.
  chroot_run "$ROOTFS" usermod -aG \
    sudo,audio,video,plugdev,netdev,render,adm,systemd-journal \
    "$MISO_LIVE_USER" 2>/dev/null || true

  # Acceso directo al instalador en el escritorio de la sesión live.
  if [[ -f "${ROOTFS}/usr/share/applications/miso-install.desktop" ]]; then
    chroot_run "$ROOTFS" install -d -o "$MISO_LIVE_USER" -g "$MISO_LIVE_USER" \
      "/home/${MISO_LIVE_USER}/Desktop"
    chroot_run "$ROOTFS" install -o "$MISO_LIVE_USER" -g "$MISO_LIVE_USER" -m 755 \
      "/usr/share/applications/miso-install.desktop" \
      "/home/${MISO_LIVE_USER}/Desktop/miso-install.desktop"
  fi

  # Desactiva el Centro de bienvenida de KDE: MiSO tiene su propia bienvenida.
  if [[ -f "${ROOTFS}/etc/skel/.config/kded6rc" ]]; then
    chroot_run "$ROOTFS" install -d -o "$MISO_LIVE_USER" -g "$MISO_LIVE_USER" \
      "/home/${MISO_LIVE_USER}/.config"
    chroot_run "$ROOTFS" install -o "$MISO_LIVE_USER" -g "$MISO_LIVE_USER" -m 644 \
      "/etc/skel/.config/kded6rc" "/home/${MISO_LIVE_USER}/.config/kded6rc"
  fi

  printf '%s:%s\n' "$MISO_LIVE_USER" "$MISO_LIVE_PASSWORD" | \
    chroot_run "$ROOTFS" chpasswd

  # Sin login de root: la cuenta queda bloqueada y sin shell de login.
  if [[ -x "${ROOTFS}/usr/sbin/nologin" ]]; then
    chroot_run "$ROOTFS" usermod -s /usr/sbin/nologin root 2>/dev/null || true
  fi

  # Servicios
  chroot_run "$ROOTFS" systemctl enable NetworkManager.service >/dev/null 2>&1 || true
  chroot_run "$ROOTFS" systemctl enable nftables.service >/dev/null 2>&1 || true
  chroot_run "$ROOTFS" systemctl enable miso-firstboot.service >/dev/null 2>&1 || true
  chroot_run "$ROOTFS" systemctl enable miso-boot-ok.service >/dev/null 2>&1 || true

  if [[ "$PROFILE" == "desktop" || "$PROFILE" == "lab" ]]; then
    chroot_run "$ROOTFS" systemctl enable sddm.service >/dev/null 2>&1 || \
      warn "No se pudo habilitar SDDM"
    chroot_run "$ROOTFS" systemctl set-default graphical.target >/dev/null 2>&1 || true
  else
    chroot_run "$ROOTFS" systemctl set-default multi-user.target >/dev/null 2>&1 || true
  fi

  ok "Identidad MiSO aplicada"
}

# ---------------------------------------------------------------------------
# Etapa 5: initramfs
# ---------------------------------------------------------------------------
stage_initramfs() {
  log "Etapa 5/7: generando initramfs"
  chroot_run "$ROOTFS" update-initramfs -u -k all
  ok "Initramfs generado"
}

# ---------------------------------------------------------------------------
# Etapa 6: squashfs
# ---------------------------------------------------------------------------
stage_squashfs() {
  log "Etapa 6/7: generando squashfs"
  umount_chroot "$ROOTFS"

  # Limpieza para reducir tamaño
  rm -f "${ROOTFS}"/var/cache/apt/archives/*.deb 2>/dev/null || true
  rm -rf "${ROOTFS}/var/lib/apt/lists"/* 2>/dev/null || true
  rm -rf "${ROOTFS}/tmp"/* 2>/dev/null || true
  rm -f "${ROOTFS}/etc/resolv.conf" 2>/dev/null || true

  local kernel initrd
  kernel="$(find "${ROOTFS}/boot" -maxdepth 1 -name 'vmlinuz-*' -type f | sort -V | tail -n 1)"
  initrd="$(find "${ROOTFS}/boot" -maxdepth 1 -name 'initrd.img-*' -type f | sort -V | tail -n 1)"
  [[ -n "$kernel" ]] || die "No se encontró el kernel en ${ROOTFS}/boot"
  [[ -n "$initrd" ]] || die "No se encontró el initramfs en ${ROOTFS}/boot"

  rm -rf "$ISOROOT"
  mkdir -p "${ISOROOT}/live"
  cp "$kernel" "${ISOROOT}/live/vmlinuz"
  cp "$initrd" "${ISOROOT}/live/initrd.img"

  # WSL puede caerse si mksquashfs satura todos los núcleos; se limita por
  # defecto a 4 procesos y se puede ajustar con MISO_SQUASHFS_PROCESSORS.
  local squash_processors="${MISO_SQUASHFS_PROCESSORS:-4}"
  mksquashfs "$ROOTFS" "${ISOROOT}/live/filesystem.squashfs" \
    -processors "$squash_processors" -mem 1500M \
    -comp zstd -Xcompression-level 15 -noappend

  ok "Squashfs generado"
}

# ---------------------------------------------------------------------------
# Etapa 7: ISO híbrida BIOS + UEFI
# ---------------------------------------------------------------------------
stage_iso() {
  log "Etapa 7/7: generando ISO híbrida"

  mkdir -p "${ISOROOT}/boot/grub"
  if [[ -d "${PROJECT_ROOT}/branding/grub" ]]; then
    mkdir -p "${ISOROOT}/boot/grub/themes/miso"
    cp -a "${PROJECT_ROOT}/branding/grub/." "${ISOROOT}/boot/grub/themes/miso/"
  fi

  cat > "${ISOROOT}/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5
set theme=/boot/grub/themes/miso/theme.txt

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "MiSO Desktop ${MISO_VERSION} (Live)" {
    linux /live/vmlinuz boot=live components quiet splash \\
        live-config.username=${MISO_LIVE_USER} \\
        live-config.hostname=${MISO_HOSTNAME} \\
        live-config.locales=${MISO_LOCALE} \\
        live-config.keyboard-layouts=${MISO_KEYMAP} \\
        live-config.timezone=${MISO_TIMEZONE} \\
        console=tty0 console=ttyS0,115200
    initrd /live/initrd.img
}

menuentry "MiSO Desktop ${MISO_VERSION} (Live, gráficos seguros)" {
    linux /live/vmlinuz boot=live components nomodeset quiet splash \\
        live-config.username=${MISO_LIVE_USER} \\
        live-config.hostname=${MISO_HOSTNAME} \\
        console=tty0 console=ttyS0,115200
    initrd /live/initrd.img
}

menuentry "MiSO Desktop ${MISO_VERSION} (Live, consola)" {
    linux /live/vmlinuz boot=live components systemd.unit=multi-user.target \\
        live-config.username=${MISO_LIVE_USER} \\
        live-config.hostname=${MISO_HOSTNAME} \\
        console=tty0 console=ttyS0,115200
    initrd /live/initrd.img
}
EOF

  local iso="${OUTDIR}/miso-desktop-${MISO_VERSION}-${PROFILE}-${MISO_ARCH}.iso"
  rm -f "$iso"

  grub-mkrescue -o "$iso" "$ISOROOT" -- -volid "$ISO_VOLID"
  sha256sum "$iso" > "${iso}.sha256"

  ok "ISO lista: ${iso}"
  log "SHA-256: $(cut -d' ' -f1 "${iso}.sha256")"
}

# ---------------------------------------------------------------------------
# Ejecución
# ---------------------------------------------------------------------------
log "MiSO Desktop ${MISO_VERSION} «${MISO_CODENAME}»"
log "Perfil: ${PROFILE} · Suite: ${DEBIAN_SUITE} · Arquitectura: ${MISO_ARCH}"
log "Workdir: ${WORKDIR}"
log "Salida:  ${OUTDIR}"

stage_prepare
stage_configure
stage_packages
stage_identity
stage_initramfs
stage_squashfs

if [[ $NO_ISO -eq 1 ]]; then
  ok "Build detenido antes de generar la ISO (--no-iso)"
  exit 0
fi

stage_iso
ok "Build completado"
