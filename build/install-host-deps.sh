#!/usr/bin/env bash
# Instala las dependencias del host para construir MiSO Desktop.
# Probado en Ubuntu 24.04 (WSL2) y Debian 13.

set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Ejecuta este script como root: sudo bash build/install-host-deps.sh" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Este script requiere apt-get (Debian/Ubuntu/WSL2)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y --no-install-recommends \
  debootstrap \
  debian-archive-keyring \
  squashfs-tools \
  xorriso \
  mtools \
  grub-pc-bin \
  grub-efi-amd64-bin \
  grub-common \
  dosfstools \
  rsync \
  ca-certificates \
  curl \
  gnupg \
  librsvg2-bin \
  imagemagick \
  shellcheck \
  file \
  zstd \
  xz-utils

echo
echo "Dependencias instaladas."
echo "Siguiente paso:"
echo "  sudo bash build/build-iso.sh --profile core"
