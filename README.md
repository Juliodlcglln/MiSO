# MiSO Desktop

**MiSO Desktop** es una distribución Linux de escritorio para laboratorio, x86_64,
construida sobre **Debian 13 «Trixie»** y **KDE Plasma 6**, con capas propias de
integración, seguridad, instalación, actualización e identidad visual.

> **Versión:** 0.1.0 «Génesis»
> **Estado:** funcional en QEMU — ISO `core` y `desktop` verificadas en BIOS/UEFI,
> instalación en disco con btrfs y rollback manual probado de punta a punta.
> **Base:** Debian 13 Trixie · Linux 6.12 (kernel MiSO `-miso`) · KDE Plasma 6 · Wayland (con X11 disponible).

---

## Qué es MiSO Desktop

MiSO Desktop es un **producto de integración original**: toma componentes maduros
(kernel Linux, Debian, KDE Plasma, Calamares, Flatpak) y construye encima un sistema
con identidad y reglas propias.

- **Anillos MiSO:** Core, Desktop, Lab y Apps con cadencias y riesgos separados.
- **Actualizaciones seguras:** instantáneas antes de actualizar y, en la meta 1.0,
  arranque A/B con rollback automático.
- **Privilegio mínimo:** las aplicaciones nunca son root; un broker (`misod`) media
  todas las operaciones administrativas a través de polkit.
- **Instalador propio:** Calamares con branding, módulos y post-instalación MiSO.
- **Shell PJD:** capa de escritorio MiSO sobre Plasma (panel, tema, lanzador y
  experiencia), no un compositor desde cero.
- **Aplicaciones descargables:** Flatpak + Discover, con un anillo Apps separado del
  sistema base.

## Qué no es

- **No es MiSO Core.** El kernel educativo de 32 bits queda archivado; este proyecto
  usa el kernel Linux.
- **No es un remaster de Debian.** Debian es el cimiento; la arquitectura de anillos,
  el actualizador, el broker, el instalador, la shell PJD y la marca son MiSO.
- **No es un kernel desde cero.** Escribir un kernel propio no es el camino para
  tener GUI, drivers y ecosistema de aplicaciones en el laboratorio.

## Stack

| Capa | Tecnología | Por qué |
|---|---|---|
| Kernel | Linux 6.x (Debian) | Drivers, hardware moderno, seguridad y mantenimiento |
| Base | Debian 13 Trixie | Estabilidad, ecosistema, herramientas de construcción |
| Escritorio | KDE Plasma 6 | Madurez, Wayland, personalización y apps |
| Instalador | Calamares + módulos MiSO | Instalador gráfico probado y extensible |
| Actualizaciones | apt + btrfs + GRUB (A/B en 1.0) | Simplicidad hoy, atomicidad después |
| Aplicaciones | Flatpak + Discover | Sandbox y catálogo independiente del sistema |
| Privilegios | polkit + `misod` | Separación de privilegios auditable |
| Shell | PJD sobre Plasma | Identidad propia sin reescribir un compositor |

## Estructura del repositorio

```text
MiSO Desktop/
├── build/              # Pipeline de ISO (debootstrap + squashfs + grub-mkrescue)
│   ├── config/         # Configuración de versión, espejos y perfiles
│   ├── lib/            # Utilidades comunes del build
│   ├── packages/       # Listas de paquetes por anillo/perfil
│   └── overlays/       # Archivos que se copian al rootfs
├── branding/           # Logo, fondos, GRUB, Plymouth, SDDM
├── docs/               # Documentación y reporte del proyecto
├── installer/          # Configuración de Calamares y post-instalación
├── kernel/             # Kernel MiSO: configuración propia y build
├── packages/           # Fuentes de paquetes propios (empaquetado futuro)
├── pjd-shell/          # Look-and-feel y layout de Plasma
├── repos/              # Definición de anillos y repositorios
├── scripts/            # QEMU, USB y utilidades de desarrollo
├── tests/              # Matriz de pruebas y smoke tests
├── tools/              # CLI miso, broker misod, actualizador, doctor
├── CHANGELOG.md
├── LICENSE
├── Makefile
└── README.md
```

## Inicio rápido (Windows + WSL2)

Requisitos: Windows 11, WSL2 con Ubuntu 24.04 o superior, 25 GB libres, 8 GB de RAM
y conexión a Internet.

```powershell
wsl -d Ubuntu
cd "/mnt/c/Users/luis_/OneDrive/Desktop/Julio/MiSO/MiSO Desktop"
sudo bash build/install-host-deps.sh
sudo bash build/build-iso.sh --profile core
```

La ISO se genera en `out/`. Para el escritorio completo:

```bash
sudo bash build/build-iso.sh --profile desktop
```

> El perfil `desktop` descarga KDE Plasma 6, Calamares y Flatpak; requiere más tiempo,
> disco y red. El perfil `core` sirve para validar el pipeline de arranque primero.

## Probar en QEMU

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-core-amd64.iso" -Memory 4G -Cpus 4
```

Para UEFI:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-core-amd64.iso" -Uefi
```

## Documentación

| Documento | Contenido |
|---|---|
| [Reporte del proyecto](docs/01-reporte-del-proyecto.md) | Qué construimos, por qué y cómo |
| [Arquitectura](docs/02-arquitectura.md) | Capas, arranque, discos, actualizaciones |
| [Anillos y seguridad](docs/03-anillos-y-seguridad.md) | Modelo de anillos, amenazas y controles |
| [Componentes](docs/04-componentes.md) | Mapa de componentes e interfaces |
| [Proceso de build](docs/05-proceso-de-build.md) | Pipeline paso a paso |
| [Instalación y pruebas](docs/06-instalacion-y-pruebas.md) | QEMU, USB y matriz de pruebas |
| [Roadmap](docs/07-roadmap.md) | Fases, entregables y criterios de aceptación |
| [Decisiones técnicas](docs/08-decisiones-tecnicas.md) | ADRs y alternativas descartadas |
| [Licencias y gobernanza](docs/09-licencias-y-gobernanza.md) | GPL, marcas y contribución |

## Licencia

El código propio de MiSO Desktop se publica bajo **GPL-3.0-or-later**. El kernel Linux
conserva su licencia GPL-2.0. Las marcas y el arte de MiSO se rigen por la política
descrita en [docs/09-licencias-y-gobernanza.md](docs/09-licencias-y-gobernanza.md).

MiSO Desktop no está afiliado a Debian, KDE, Calamares ni Flatpak.
