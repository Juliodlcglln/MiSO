# Changelog

Todas las versiones notables de MiSO Desktop se documentan aquí.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el
versionado usa [SemVer](https://semver.org/lang/es/).

## [No publicado]

### Verificado
- ISO `core` construida con Debian 13 y kernel Linux 6.12, arrancada en QEMU BIOS
  **y UEFI** (OVMF).
- Login `live`/`live`, DHCP funcional y `ping` a `deb.debian.org`.
- `miso status`, `miso doctor`, `miso ring list` y `miso rollback list` sin errores.
- AppArmor habilitado, firewall nftables activo y root sin shell de login.
- Prueba automática por serial (`scripts/serial-smoke.ps1`).
- ISO `desktop` con KDE Plasma 6.3.6 en Wayland, SDDM activo y PJD aplicado
  (`LookAndFeelPackage=org.miso.pjd.desktop`), verificada con captura de pantalla.
- Instalación en disco con subvolúmenes btrfs `@`, `@home` y `@snapshots`,
  `fstab` correcto y GRUB BIOS+UEFI (`rootflags=subvol=@`).
- Sistema instalado arranca sin la ISO: usuario `alumno`, `live` eliminado, root
  `/usr/sbin/nologin`, `graphical.target` y SDDM activo.
- `miso doctor` en el sistema instalado: 10–11 OK, 1–2 avisos, 0 fallos.
- Rollback manual completo: `miso update apply` crea instantánea,
  `miso rollback restore <snap>` restaura el sistema conservando `/home` y
  `/.snapshots`, y el equipo reinicia sin errores.
- `miso update check/apply`, anillos y `miso app` funcionan en el sistema instalado.

### Corregido
- `ping` sin `cap_net_raw` en la ISO: se aplica `setcap` durante el build.
- Archivos de overlay copiados desde Windows con dueño `1000:1000` y modo `777`;
  ahora `rsync --chown=root:root --chmod=D755,F644`.
- `miso ring list` y `miso rollback list` ya no piden autenticación polkit.
- `/etc/issue`, `/etc/issue.net` y `/etc/motd` con identidad MiSO.
- Reglas base de nftables y servicio habilitado.
- Nombre de paquete inválido `kdeplasma-addons` sustituido por los paquetes
  `plasma-*-addons` de Debian 13.
- Conflicto `grub-pc`/`grub-efi-amd64` resuelto usando `grub-pc-bin` y
  `grub-efi-amd64-bin`.
- Conflicto de conffile de Plymouth en APT: se usa `--force-confold`.
- `miso-updated restore` recorta el sufijo de subvolumen que devuelve `findmnt`
  (`/dev/vda3[/@]`) antes de montar.
- `miso-updated` solo crea instantáneas si la raíz es un subvolumen y crea
  `/.snapshots` como subvolumen cuando hace falta.
- La restauración excluye `/mnt`, `/media` y `lost+found` además de los sistemas
  de archivos virtuales.
- Configuración de Calamares corregida y validada contra los esquemas de Debian 13:
  `btrfsSubvolumes` movido a `mount.conf`, `fstab.conf` con `tmpOptions`,
  `unpackfs.conf` con `sourcefs: squashfs`, y claves válidas en
  `bootloader.conf`/`grubcfg.conf`.
- `settings.conf` con instancias en el formato de Calamares 3.3 (`id` corto +
  `module` + `config`) y `branding.desc` con `slideshow` y claves de estilo
  válidas. Sin esto, Calamares se negaba a arrancar.
- Descarga del código fuente del kernel: el CDN de kernel.org corta la conexión
  (`PROTOCOL_ERROR` con HTTP/2, o 0 B/s); ahora usa HTTP/1.1, reanuda con
  `curl -C -`, prueba espejos alternativos y valida el archivo con `xz -t`.

### Añadido
- Estructura inicial del proyecto `MiSO Desktop`.
- Documentación de arquitectura, anillos, seguridad, build, pruebas y roadmap.
- Pipeline de ISO basado en debootstrap + squashfs + grub-mkrescue.
- Listas de paquetes para los perfiles `core`, `desktop` y `lab`.
- CLI `miso`, broker `misod`, actualizador `miso-updated`, anillos `miso-rings`
  y diagnóstico `miso-doctor` (prototipos funcionales).
- Branding base: logo, fondo, tema GRUB y tema Plymouth.
- Branding de SDDM (`branding/sddm/theme.conf.user`) con fondo y logo MiSO.
- Configuración inicial de Calamares y script de post-instalación.
- Subvolúmenes btrfs en `partition.conf` y particionado sin borrado por defecto.
- Look-and-feel `PJD Shell` para KDE Plasma 6.
- `scripts/test-install.sh`: instalación reproducible en imagen de disco
  (btrfs/ext4, GRUB BIOS+UEFI, herramientas actuales del repo).
- `scripts/desktop-screenshot.ps1`: captura del framebuffer de QEMU.
- `scripts/install-gui-smoke.ps1`: arranque de la ISO con disco vacío y capturas
  del asistente Calamares.
- Acceso directo **Instalar MiSO Desktop** en el escritorio de la sesión live y en
  el menú de aplicaciones (`pkexec calamares`).
- Escritorio con **Folder View** en el layout PJD y Centro de bienvenida de KDE
  desactivado (MiSO usa su propia bienvenida en consola).
- `MISO_SQUASHFS_PROCESSORS` para limitar `mksquashfs` y evitar caídas de WSL.
- `miso rollback restore <snap>` y verbo `restore` en `misod`.
- Kernel propio de MiSO (`kernel/`): configuración versionada
  `config-miso-x86_64` derivada de Debian 13 con identidad `-miso`,
  `CONFIG_IKCONFIG_PROC` para `/proc/config.gz`, `CONFIG_DEFAULT_HOSTNAME="miso"`
  y sin información de depuración; `build-kernel.sh` compila Linux 6.12.116 y
  genera `linux-image-*-miso` y `linux-headers-*-miso` como `.deb`.
- `install_miso_kernel()` en `build/build-iso.sh`: instala los paquetes del kernel
  MiSO en el rootfs si existen y deja el kernel de Debian como respaldo en GRUB.

## [0.1.0] — «Génesis» — por definir

Primera versión objetivo: ISO live con KDE Plasma 6, instalador y sistema instalado
con identidad MiSO. Ver `docs/07-roadmap.md`.
