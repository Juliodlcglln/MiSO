# Proceso de build

---

## 1. Requisitos del host

### 1.1 Recomendado

- Windows 11 con WSL2 y Ubuntu 24.04 LTS (o superior).
- 8 GB de RAM (16 GB recomendado para el perfil desktop).
- 25 GB libres en el disco de WSL.
- Conexión a Internet.
- QEMU 9+ en Windows para pruebas.

### 1.2 Alternativa

- Debian 13 o Ubuntu 24.04 nativo.
- Los mismos paquetes de host.
- Ejecutar los scripts con `sudo`.

### 1.3 Dependencias

`build/install-host-deps.sh` instala:

```text
debootstrap squashfs-tools xorriso mtools
grub-pc-bin grub-efi-amd64-bin grub-common
dosfstools rsync ca-certificates curl
librsvg2-bin imagemagick shellcheck
```

---

## 2. Estructura del build

```text
build/
├── build-iso.sh
├── install-host-deps.sh
├── clean.sh
├── config/build.conf
├── lib/common.sh
├── packages/
│   ├── core.list
│   ├── desktop.list
│   ├── installer.list
│   └── lab.list
└── overlays/
    ├── etc/
    └── usr/
```

---

## 3. Perfiles

| Perfil | Listas | Uso | Tamaño aproximado |
|---|---|---|---|
| `core` | core | Validar arranque, consola y red | 700 MB – 1.2 GB |
| `desktop` | core + desktop + installer | Producto 0.1.0 | 3.5 – 5 GB |
| `lab` | desktop + lab | Laboratorio completo | 6 – 8 GB |

El tamaño es orientativo y depende de la versión de Debian y de las recomendaciones de
los paquetes.

---

## 4. Comandos

### 4.1 Preparar el host

```bash
cd "/mnt/c/Users/luis_/OneDrive/Desktop/Julio/MiSO/MiSO Desktop"
sudo bash build/install-host-deps.sh
```

### 4.2 Construir

```bash
# Perfil mínimo para validar el pipeline
sudo bash build/build-iso.sh --profile core

# Escritorio completo
sudo bash build/build-iso.sh --profile desktop

# Laboratorio
sudo bash build/build-iso.sh --profile lab
```

Opciones:

```text
--profile core|desktop|lab   Perfil de la ISO
--clean                      Borra el rootfs y el staging antes de empezar
--no-iso                     Detiene el build después del squashfs
-h, --help                   Ayuda
```

Variables de entorno:

```bash
MISO_WORKDIR=/var/tmp/miso-build
MISO_OUTDIR="$PWD/out"
```

### 4.3 Limpiar

```bash
sudo bash build/clean.sh
```

### 4.4 Rebuild incremental

Si el rootfs existe, el build lo reutiliza. Para forzar desde cero:

```bash
sudo bash build/build-iso.sh --profile core --clean
```

---

## 5. Etapas del pipeline

| Etapa | Qué hace | Salida |
|---|---|---|
| 1. Preparar | `debootstrap` de Debian 13 mínimo | `$WORKDIR/rootfs` |
| 2. Configurar | APT, locale, systemd, red, herramientas | rootfs actualizado |
| 3. Paquetes | Instala listas del perfil | rootfs con el perfil |
| 4. Identidad | Overlays, `miso`, `misod`, PJD, branding, Calamares | rootfs MiSO |
| 5. Initramfs | `update-initramfs` con live-boot | `/boot/vmlinuz`, `/boot/initrd.img` |
| 6. Squashfs | Comprime el rootfs | `filesystem.squashfs` |
| 7. ISO | `grub-mkrescue` BIOS+UEFI | `.iso` + `.sha256` |

### 5.1 Etapa 1: debootstrap

```bash
debootstrap \
  --arch=amd64 \
  --variant=minbase \
  --components=main,contrib,non-free-firmware \
  trixie "$ROOTFS" http://deb.debian.org/debian
```

### 5.2 Etapa 2: configuración

- Escribe `/etc/apt/sources.list` con `trixie`, `trixie-updates` y
  `trixie-security`.
- Copia `/etc/resolv.conf`.
- Instala base: systemd, dbus, polkit, sudo, NetworkManager, herramientas.
- Configura locale `es_MX.UTF-8`, teclado `latam`, zona `America/Mexico_City`.

### 5.3 Etapa 3: paquetes

- `core.list` siempre.
- `desktop.list` + `installer.list` para `desktop` y `lab`.
- `lab.list` solo para `lab`.
- Los paquetes de escritorio usan recomendaciones; los de core no.

#### Kernel MiSO

Si existe `kernel/out/linux-image-*-miso_*.deb`, la etapa 3 lo instala en el
rootfs (y los headers si están). La etapa 5 regenera el initramfs y la etapa 6
empaqueta el kernel más reciente, que será el `-miso`. Si no hay paquetes en
`kernel/out`, se usa el kernel de Debian.

```bash
sudo bash kernel/build-kernel.sh   # ver kernel/README.md
```

### 5.4 Etapa 4: identidad

- Copia `build/overlays/` al rootfs.
- Instala `tools/bin/*` en `/usr/bin` y `tools/libexec/misod` en `/usr/libexec/miso`.
- Copia política polkit y unidades systemd.
- Copia `installer/calamares/` a `/etc/calamares/`.
- Ejecuta `branding/render-assets.sh`.
- Ejecuta `pjd-shell/install.sh`.
- Crea el usuario live `live` (contraseña `live`, solo live).
- Copia el acceso directo **Instalar MiSO Desktop** (`pkexec calamares`) al
  escritorio de la sesión live y al menú de aplicaciones.
- Escribe `/etc/miso/release` con versión y perfil.
- Habilita servicios.

La configuración de Calamares se valida contra los esquemas instalados
(`/usr/lib/x86_64-linux-gnu/calamares/modules/*/*.schema.yaml`). Los subvolúmenes
btrfs y las opciones de montaje viven en `modules/mount.conf`; `modules/fstab.conf`
solo define `tmpOptions` y `crypttabOptions`. `unpackfs.conf` debe declarar
`sourcefs: "squashfs"`.

### 5.5 Etapa 5: initramfs

- `update-initramfs -u -k all` dentro del chroot.
- Verifica que `live-boot` esté instalado.
- Copia kernel e initrd al staging de la ISO.

### 5.6 Etapa 6: squashfs

```bash
MISO_SQUASHFS_PROCESSORS=4 mksquashfs "$ROOTFS" "$ISOROOT/live/filesystem.squashfs" \
  -processors 4 -mem 1500M -comp zstd -Xcompression-level 15 -noappend
```

`MISO_SQUASHFS_PROCESSORS` (por defecto `4`) limita los procesos de compresión.
Con WSL y 8 núcleos, dejar que `mksquashfs` use todos ha provocado caídas del
servicio (`Wsl/Service/E_UNEXPECTED`); 4 procesos son estables y casi igual de
rápidos.

### 5.7 Etapa 7: ISO

- Genera `grub.cfg` con entradas Live, Live seguro y rescate.
- `grub-mkrescue` produce una ISO híbrida.
- Calcula SHA-256.

---

## 6. Salidas

```text
out/
├── miso-desktop-0.1.0-core-amd64.iso
├── miso-desktop-0.1.0-core-amd64.iso.sha256
├── miso-desktop-0.1.0-desktop-amd64.iso
└── miso-desktop-0.1.0-desktop-amd64.iso.sha256
```

El rootfs y el staging quedan en `/var/tmp/miso-build` para rebuild incremental.

### 6.1 Pruebas automatizadas

```text
scripts/
├── run-qemu.ps1            Arranque interactivo (BIOS/UEFI)
├── serial-smoke.ps1        Smoke test por consola serie
├── desktop-screenshot.ps1  Captura del framebuffer (BIOS/UEFI)
├── install-gui-smoke.ps1   Arranque + Calamares con capturas
└── test-install.sh         Instalación reproducible en imagen de disco
```

- `serial-smoke.ps1` arranca la ISO o un disco instalado, espera el login y ejecuta
  comandos; sirve para verificar identidad, red, servicios y `miso doctor`.
- `desktop-screenshot.ps1` usa el monitor de QEMU (`screendump`) para capturar la
  pantalla sin interacción manual.
- `install-gui-smoke.ps1` arranca la ISO con un disco vacío, enfoca la consola de
  bienvenida, lanza `sudo calamares` y guarda capturas del asistente.
- `test-install.sh` extrae `filesystem.squashfs` a una imagen GPT (BIOS + ESP +
  raíz btrfs/ext4), crea los subvolúmenes `@`, `@home` y `@snapshots`, ejecuta el
  `miso-postinstall.sh` real e instala GRUB para BIOS y UEFI. Copia las herramientas
  actuales del repo para iterar sin reconstruir el ISO.

Ejemplo:

```bash
sudo bash scripts/test-install.sh \
  --img /var/tmp/miso-disk.img --fs btrfs --size 12G
```

---

## 7. Reproducibilidad

Estado actual:

- Suite Debian fijada (`trixie`), pero los paquetes avanzan dentro de la suite.
- El build no fija versiones exactas ni fechas de snapshot.
- No hay compilación reproducible de paquetes propios.

Mejoras planificadas:

1. Usar un snapshot de Debian (`snapshot.debian.org`) con fecha fija.
2. Fijar versiones en un lockfile.
3. Construir en contenedor con imagen versionada.
4. Publicar SBOM y checksums.
5. Firmar la ISO y los repos.

---

## 8. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `debootstrap: no such script: trixie` | debootstrap viejo | Actualiza el host o usa Debian 13 |
| `grub-mkrescue: command not found` | Falta GRUB | `sudo bash build/install-host-deps.sh` |
| `chroot: failed to run command` | Falta montar `/proc` o arquitectura distinta | Revisa `mount_chroot`; usa `--clean` |
| APT pide interacción | Falta `DEBIAN_FRONTEND=noninteractive` | Revisa `common.sh`; borra rootfs |
| La ISO no arranca en UEFI | Falta `grub-efi-amd64-bin` | Instala dependencias y reconstruye |
| Plasma no inicia en QEMU | GPU/Wayland | Prueba la entrada de rescate con X11/`nomodeset` |
| Disco lleno | Rootfs + squashfs + ISO | Libera espacio o usa `--clean` |
| `mount: /dev busy` | Chroot montado | `sudo bash build/clean.sh` |
| El usuario live no entra | Contraseña o SDDM | Usa `live/live`; revisa `journalctl -u sddm` |
| `Package X is not available` | Paquete transicional eliminado en Trixie | Usa el paquete que apt sugiere (p. ej. `plasma-workspace`) |
| `grub-pc : Conflicts: grub-efi-amd64` | Los meta-paquetes de GRUB son excluyentes | Usa `grub-pc-bin` y `grub-efi-amd64-bin` |
| `ping: missing cap_net_raw` | Falta la capacidad en el binario | El build aplica `setcap`; instala `libcap2-bin` |
| Archivos de `/etc` con dueño 1000 | Copia desde el montaje de Windows | El build usa `rsync --chown=root:root` |
| APT se detiene en un conffile | `plymouth`/`grub` piden decisión interactiva | El build usa `--force-confold` |
| `btrfs subvolume show /` falla | La raíz es el subvolumen superior, no `@` | Instala con subvolúmenes o usa `miso-updated apply --force` |
| `mount: /dev/vda3[/@]` inválido | `findmnt` incluye el subvolumen entre corchetes | El script recorta el sufijo `[...]` |
| Calamares no abre por configuración | Clave desconocida o falta `sourcefs`/`tmpOptions` | Valida contra `*.schema.yaml` y revisa `journalctl` |

### 8.1 Logs

- Build: salida estándar del script.
- Sistema live: `journalctl -b`.
- Instalador: `/var/log/calamares/` y `journalctl`.
- Actualizaciones: `/var/log/miso/updates.log`.
- Broker: `/var/log/miso/misod.log`.

---

## 9. Buenas prácticas

- No construir como usuario normal: debootstrap y chroot requieren root.
- No editar archivos dentro de `$WORKDIR/rootfs` a mano; cambia overlays y reconstruye.
- Un cambio en `build/` debe probarse con `--clean` antes de un release.
- No commitear `out/`, `work/` ni rootfs.
- Ejecutar `shellcheck` sobre los scripts antes de un PR.
- Probar BIOS y UEFI en cada release.

---

## 10. Próximos pasos del build

1. [x] Validar el perfil `core` en QEMU BIOS/UEFI.
2. [x] Añadir un test automático que compruebe el arranque por serial.
3. [x] Construir `desktop` y corregir dependencias de Plasma.
4. [x] Validar la instalación en un disco virtual (`scripts/test-install.sh`).
5. [ ] Probar la interfaz gráfica de Calamares de principio a fin.
6. [ ] Añadir firma de ISO y snapshot de Debian.
