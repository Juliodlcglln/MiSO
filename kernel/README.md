# Kernel MiSO

MiSO Desktop usa un **kernel Linux compilado por el proyecto** a partir del
código fuente oficial de Linux y de la configuración de Debian 13 «Trixie».

No es un kernel escrito desde cero: es Linux 6.12 con una configuración propia,
versionada y documentada en este directorio. La base Debian garantiza el soporte
de hardware, los módulos y el firmware que ya funcionan en la ISO.

---

## 1. Composición

| Elemento | Valor |
|---|---|
| Fuente | Linux 6.12.116 (kernel.org) |
| Configuración base | `/boot/config-6.12.116+deb13-amd64` de Debian 13 |
| Configuración MiSO | [`config-miso-x86_64`](config-miso-x86_64) |
| Versión resultante | `6.12.116-miso` |
| Arquitectura | x86_64 |
| Empaquetado | `linux-image-*-miso` + `linux-headers-*-miso` (.deb) |

## 2. Diferencias respecto a Debian

La configuración parte de la de Debian para conservar drivers, sistemas de
archivos, firmware y opciones de seguridad. Los cambios de MiSO son deliberados
y mínimos:

| Opción | Debian | MiSO | Motivo |
|---|---|---|---|
| `CONFIG_LOCALVERSION` | `""` | `"-miso"` | Identidad visible en `uname -r` y GRUB |
| `CONFIG_IKCONFIG` | no | `y` | Guardar la configuración en el kernel |
| `CONFIG_IKCONFIG_PROC` | no | `y` | Exponerla en `/proc/config.gz` |
| `CONFIG_DEFAULT_HOSTNAME` | `"(none)"` | `"miso"` | Nombre por defecto coherente |
| `CONFIG_DEBUG_INFO` | `y` | `n` | Kernel y módulos sin depuración: imagen más pequeña y build más rápido |

Todo lo demás se mantiene igual que en Debian. La configuración completa está en
`config-miso-x86_64` (11 472 líneas) y se puede comparar con la de Debian con
`diff`.

## 3. Compilar

Requisitos (Debian/Ubuntu):

```bash
sudo apt-get install build-essential libssl-dev libelf-dev bison flex bc \
  dwarves cpio zstd kmod rsync xz-utils dpkg-dev debhelper fakeroot pahole
```

Compilación:

```bash
sudo bash kernel/build-kernel.sh
```

- Descarga `linux-6.12.116.tar.xz` de kernel.org. Usa HTTP/1.1, reanuda con
  `curl -C -` y prueba espejos (`mirrors.edge.kernel.org`,
  `mirror.math.princeton.edu`) si el CDN falla: en este entorno el CDN corta la
  conexión con `PROTOCOL_ERROR` o se queda a 0 B/s. El archivo se valida con
  `xz -t` antes de extraer.
- Aplica `config-miso-x86_64` con `make olddefconfig`.
- Compila con 4 procesos por defecto (`MISO_KERNEL_JOBS`).
- Genera los `.deb` en `kernel/out/`.

Si la descarga se corta, vuelve a ejecutar el script: continúa desde el `.part`.
Si el `.part` queda corrupto, bórralo y reintenta.

Tiempo aproximado: 30–60 minutos en 8 núcleos nativos; en WSL con 6 GB de RAM y
`-j4` tarda bastante más (2–3 h). Si la compilación se interrumpe, vuelve a
ejecutar el script: los objetos ya compilados se reutilizan y continúa donde
quedó. Espacio: ~15 GB en `/var/tmp/miso-kernel`.

> Ejecuta la compilación en segundo plano (`setsid nohup ... &`): si la terminal
> que la lanzó recibe `SIGHUP`, `make` aborta con `Hangup`.

## 4. Integración en la ISO

`build/build-iso.sh` detecta los paquetes de `kernel/out/` y, si existen, los
instala en el rootfs antes de generar el initramfs. Debian conserva su kernel como
respaldo en GRUB, de modo que un fallo del kernel MiSO no deja el equipo
inarrancable.

Verificación:

```bash
uname -r            # 6.12.116-miso
zcat /proc/config.gz | grep CONFIG_LOCALVERSION
```

## 5. Estado

- [x] Configuración MiSO versionada.
- [ ] Compilación verificada (en curso).
- [ ] Arranque de la ISO con el kernel MiSO.
- [ ] Prueba en los PC del laboratorio.
- [ ] Firma y Secure Boot (fase posterior).
