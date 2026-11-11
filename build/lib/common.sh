#!/usr/bin/env bash
# Utilidades comunes del sistema de build de MiSO Desktop.
# shellcheck shell=bash

set -Eeuo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${COMMON_DIR}/../.." && pwd)"
export PROJECT_ROOT

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_BLUE=$'\033[34m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET=""
  C_BOLD=""
  C_BLUE=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
fi

log()  { printf '%s[miso]%s %s\n' "${C_BLUE}${C_BOLD}" "${C_RESET}" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}" "$*"; }
warn() { printf '%s[warn]%s %s\n' "${C_YELLOW}${C_BOLD}" "${C_RESET}" "$*" >&2; }
die()  { printf '%s[error]%s %s\n' "${C_RED}${C_BOLD}" "${C_RESET}" "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  printf '%s[error]%s falló un comando (código %s)\n' \
    "${C_RED}${C_BOLD}" "${C_RESET}" "$exit_code" >&2
  exit "$exit_code"
}
trap on_error ERR

require_root() {
  [[ ${EUID} -eq 0 ]] || die "Este script debe ejecutarse como root (usa sudo)."
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || \
    die "Falta el comando '$1'. Ejecuta build/install-host-deps.sh."
}

# Ejecuta un comando dentro del rootfs con un entorno mínimo y no interactivo.
chroot_run() {
  local rootfs="$1"
  shift
  chroot "$rootfs" /usr/bin/env -i \
    HOME=/root \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    APT_LISTCHANGES_FRONTEND=none \
    LC_ALL=C.UTF-8 \
    "$@"
}

# Instala una lista de paquetes ignorando comentarios y líneas vacías.
# Uso: apt_install_list <rootfs> <lista> [recommends|no-recommends]
apt_install_list() {
  local rootfs="$1"
  local list="$2"
  local mode="${3:-no-recommends}"
  [[ -f "$list" ]] || die "No existe la lista de paquetes: $list"

  local -a packages=()
  mapfile -t packages < <(
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$list" | grep -v '^$' || true
  )
  [[ ${#packages[@]} -gt 0 ]] || { warn "Lista vacía: $list"; return 0; }

  # Sin preguntas de conffile: el build no es interactivo y los overlays
  # pueden haber dejado archivos que el paquete también instala.
  local -a apt_opts=(
    -o Dpkg::Options::=--force-confdef
    -o Dpkg::Options::=--force-confold
  )

  log "Instalando ${#packages[@]} paquetes desde $(basename "$list")"
  if [[ "$mode" == "recommends" ]]; then
    chroot_run "$rootfs" apt-get install -y "${apt_opts[@]}" "${packages[@]}"
  else
    chroot_run "$rootfs" apt-get install -y --no-install-recommends \
      "${apt_opts[@]}" "${packages[@]}"
  fi
}

mount_chroot() {
  local rootfs="$1"
  mkdir -p "$rootfs/dev" "$rootfs/dev/pts" "$rootfs/proc" "$rootfs/sys" "$rootfs/run"
  mountpoint -q "$rootfs/dev"      || mount --bind /dev "$rootfs/dev"
  mountpoint -q "$rootfs/dev/pts"  || mount --bind /dev/pts "$rootfs/dev/pts"
  mountpoint -q "$rootfs/proc"     || mount -t proc proc "$rootfs/proc"
  mountpoint -q "$rootfs/sys"      || mount -t sysfs sysfs "$rootfs/sys"
  mountpoint -q "$rootfs/run"      || mount -t tmpfs -o mode=755 tmpfs "$rootfs/run"
}

umount_chroot() {
  local rootfs="$1"
  [[ -d "$rootfs" ]] || return 0
  local m
  for m in run sys proc dev/pts dev; do
    if mountpoint -q "$rootfs/$m" 2>/dev/null; then
      umount -lf "$rootfs/$m" 2>/dev/null || true
    fi
  done
}
