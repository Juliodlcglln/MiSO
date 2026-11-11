#!/usr/bin/env bash
# MiSO Desktop - construye el kernel propio a partir de Linux + configuración MiSO.
#
# Uso:
#   sudo bash kernel/build-kernel.sh
#
# Variables:
#   MISO_KERNEL_VERSION  versión de Linux (por defecto 6.12.116)
#   MISO_KERNEL_JOBS     procesos de compilación (por defecto 4)
#   MISO_KERNEL_WORK     directorio de trabajo (por defecto /var/tmp/miso-kernel)
#
# Salida: kernel/out/linux-image-*-miso_*.deb y linux-headers-*-miso_*.deb

set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${MISO_KERNEL_VERSION:-6.12.116}"
JOBS="${MISO_KERNEL_JOBS:-4}"
WORK="${MISO_KERNEL_WORK:-/var/tmp/miso-kernel}"
CONFIG="${HERE}/config-miso-x86_64"
OUT="${HERE}/out"
LOG="${WORK}/build.log"

TARBALL="linux-${VERSION}.tar.xz"
# El CDN principal de kernel.org falla de forma intermitente; hay espejos.
URLS=(
  "https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/${TARBALL}"
  "https://cdn.kernel.org/pub/linux/kernel/v6.x/${TARBALL}"
  "https://mirror.math.princeton.edu/pub/kernel/linux/kernel/v6.x/${TARBALL}"
)
SRC="${WORK}/linux-${VERSION}"

[[ -f "$CONFIG" ]] || { echo "Falta $CONFIG" >&2; exit 1; }
[[ ${EUID} -eq 0 ]] || { echo "Ejecuta este script como root." >&2; exit 1; }

mkdir -p "$WORK" "$OUT"

echo "[miso-kernel] Linux ${VERSION} con config MiSO"
echo "[miso-kernel] Trabajo: ${WORK}"
echo "[miso-kernel] Log:     ${LOG}"

# 1. Descargar el código fuente si hace falta.
if [[ ! -f "${WORK}/${TARBALL}" ]]; then
  for url in "${URLS[@]}"; do
    echo "[miso-kernel] Descargando ${url}"
    # HTTP/2 falla con PROTOCOL_ERROR en el CDN; forzamos HTTP/1.1 y
    # reanudamos la descarga desde el .part si ya existe.
    if curl -fL --http1.1 --retry 3 --retry-all-errors -C - \
         --connect-timeout 20 --speed-limit 20480 --speed-time 30 \
         -o "${WORK}/${TARBALL}.part" "$url"; then
      if xz -t "${WORK}/${TARBALL}.part" 2>/dev/null; then
        mv "${WORK}/${TARBALL}.part" "${WORK}/${TARBALL}"
        break
      fi
      echo "[miso-kernel] ${TARBALL} corrupto; se descarta" >&2
      rm -f "${WORK}/${TARBALL}.part"
    else
      echo "[miso-kernel] ${url} no sirvió; probando otro espejo" >&2
    fi
  done
fi

# 1b. Verificar que el archivo comprimido está completo.
if ! xz -t "${WORK}/${TARBALL}" 2>/dev/null; then
  echo "[miso-kernel] ${TARBALL} corrupto o incompleto; bórralo y reintenta." >&2
  exit 1
fi

# 2. Extraer limpio.
if [[ ! -d "$SRC" ]]; then
  echo "[miso-kernel] Extrayendo ${TARBALL}"
  tar -C "$WORK" -xf "${WORK}/${TARBALL}"
fi

# 3. Configuración MiSO.
cp "$CONFIG" "${SRC}/.config"
make -C "$SRC" olddefconfig >/dev/null

# La versión sale de CONFIG_LOCALVERSION ("-miso"); pasar LOCALVERSION en la
# línea de comandos la duplicaría (6.12.116-miso-miso).
RELEASE="$(make -s -C "$SRC" kernelrelease)"
echo "[miso-kernel] Versión del kernel: ${RELEASE}"

# 4. Compilar y empaquetar (.deb).
echo "[miso-kernel] Compilando con ${JOBS} procesos (esto tarda)"
make -C "$SRC" -j"${JOBS}" \
  KBUILD_BUILD_USER=miso \
  KBUILD_BUILD_HOST=miso-build \
  bindeb-pkg > "$LOG" 2>&1

# 5. Recoger los paquetes.
shopt -s nullglob
debs=(
  "${WORK}/linux-image-${RELEASE}"_*.deb
  "${WORK}/linux-headers-${RELEASE}"_*.deb
)
if [[ ${#debs[@]} -eq 0 ]]; then
  echo "[miso-kernel] No se generaron paquetes; revisa ${LOG}" >&2
  exit 1
fi
rm -f "${OUT}"/*.deb
cp -f "${debs[@]}" "$OUT"/

echo "[miso-kernel] Paquetes en ${OUT}:"
ls -1 "$OUT"
