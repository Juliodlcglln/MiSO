# Reporte del proyecto MiSO Desktop

**Versión del documento:** 1.0 · **Fecha:** 2026-11-07
**Autor:** Equipo MiSO · **Estado:** Fase 0 completada

---

## 1. Resumen ejecutivo

MiSO Desktop es una distribución Linux de escritorio para laboratorio, orientada a
equipos x86_64 modernos. Se construye sobre Debian 13 «Trixie» y KDE Plasma 6, y añade
cuatro capas propias: un modelo de **anillos** de entrega, un sistema de
**actualizaciones con instantáneas y rollback**, un **broker de privilegios** y un
**instalador/shell con identidad MiSO**.

La decisión central es dejar de escribir un kernel desde cero (MiSO Core) y usar el
kernel Linux como cimiento. MiSO no reescribe el kernel: **lo compila desde el código
fuente de Linux con una configuración propia, versionada y auditable** (`6.12.x-miso`).
El valor del proyecto no está en reimplementar drivers,
scheduler o memoria virtual, sino en **integrar, asegurar y dar identidad** a un
escritorio que funcione en el laboratorio y que se pueda instalar, actualizar y
recuperar sin fricción.

El alcance de 0.1.0 es una ISO live con Plasma 6, Calamares y la base MiSO. La meta 1.0
añade actualizaciones A/B atómicas, anillos completos, Secure Boot y validación en
hardware real.

---

## 2. Antecedentes y decisión

### 2.1 Lo que había

MiSO Core era un kernel educativo de 32 bits con arranque GRUB/Multiboot, consola VGA,
teclado y mouse PS/2, IDT/PIC/PIT, paginación, heap, hilos y una shell con sistema de
archivos en RAM. Las etapas 1–6 se completaron y probaron en QEMU.

Ese trabajo demostró dominio de los fundamentos, pero no escala a un escritorio real:
harían falta drivers de GPU, red, audio, USB, almacenamiento, sistema de archivos,
actualizaciones, sandboxing y un ecosistema de aplicaciones. Es un proyecto de años y
no produce el producto que el laboratorio necesita.

### 2.2 La decisión

**Archivar MiSO Core y construir MiSO Desktop sobre Linux.** No se borra el código
anterior: queda como referencia histórica en el repositorio.

Sobre esa base, MiSO **compila su propio kernel** a partir del código fuente de Linux
6.12 y de la configuración de Debian 13, con cambios propios mínimos y documentados
(`kernel/config-miso-x86_64`). El resultado se identifica como `6.12.x-miso`, expone
su configuración en `/proc/config.gz` y se empaqueta como `linux-image-*-miso`.

Criterios que guiaron la decisión:

1. **GUI real y apps:** KDE Plasma 6 y Flatpak existen y funcionan hoy.
2. **Hardware de laboratorio:** el kernel Linux cubre GPUs, red, audio, impresoras y
   periféricos sin trabajo propio.
3. **Mantenibilidad:** un equipo pequeño no puede mantener un kernel desde cero;
   compilar Linux con configuración propia sí es sostenible.
4. **Originalidad viable:** la identidad se construye en la integración, la seguridad,
   el instalador, las actualizaciones y la experiencia, no en el kernel.
5. **Licencia:** GPL es aceptable; Linux (GPL-2.0) y el resto del stack son compatibles.

---

## 3. Comparativa de bases

| Base | Ventajas | Inconvenientes | Veredicto |
|---|---|---|---|
| **Debian 13 + KDE** | Estable, enorme ecosistema, debootstrap/live-build, Calamares, soporte a largo plazo | Actualizaciones no atómicas por defecto; Plasma llega algo después que en Fedora | **Elegida** |
| Fedora Kinoite / bootc | Imagen inmutable y atómica desde el día 1, Plasma actualizado | Curva de bootc/OCI, ecosistema RPM, menos control del instalador clásico | Alternativa para 2.0 |
| Arch + KDE | Rolling release, Plasma muy reciente | Inestabilidad incompatible con laboratorio; mantenimiento alto | Descartada |
| Linux From Scratch | Control total | Semanas para un sistema frágil; sin ventaja de producto | Descartada |
| Ubuntu + KDE | Familiar, buen hardware support | Snap y decisiones de Canonical; menos control | Descartada |

**Por qué Debian y no Fedora Kinoite:** el equipo necesita un camino claro para
construir, instalar y depurar. Debian ofrece debootstrap, Calamares, apt y una base
predecible; la atomicidad se añade con btrfs/GRUB en la Fase 4. Si en 2.0 la atomicidad
y la actualización por imagen demuestran ser superiores, migrar a `bootc` es una
decisión reversible a nivel de arquitectura, no de producto.

---

## 4. Definición del producto

### 4.1 Usuario objetivo

- Laboratorios de cómputo con PCs x86_64 modernos (UEFI, 8–16 GB RAM, SSD).
- Docentes y estudiantes que necesitan un escritorio estable, software científico y
  capacidad de reinstalar o recuperar rápido.
- Administradores que valoran instalación desatendida, actualizaciones controladas y
  diagnóstico claro.

### 4.2 Propuesta de valor

1. **Un escritorio que no se rompe:** instantánea antes de actualizar y rollback.
2. **Anillos claros:** el laboratorio decide qué recibe y cuándo.
3. **Privilegio mínimo:** nada de aplicaciones corriendo como root.
4. **Instalación repetible:** ISO híbrida BIOS/UEFI, Calamares y post-instalación MiSO.
5. **Identidad propia:** PJD Shell, branding, comandos `miso` y experiencia coherente.

### 4.3 No objetivos de 0.1.0

- Secure Boot firmado, dm-verity y arranque medido.
- Actualización A/B completa por imagen.
- Repositorios propios firmados con todos los paquetes de Debian espejados.
- Shell PJD basada en Quickshell o compositor propio.
- Soporte ARM, telefónica o servidor.

---

## 5. Arquitectura en una página

```text
┌──────────────────────────────────────────────────────────────┐
│  Aplicaciones: Flatpak (Apps) · Discover · navegador · office │
├──────────────────────────────────────────────────────────────┤
│  PJD Shell: panel, lanzador, tema, layout, splash, SDDM      │
├──────────────────────────────────────────────────────────────┤
│  Anillo Desktop: KDE Plasma 6, sesión Wayland/X11            │
├──────────────────────────────────────────────────────────────┤
│  Anillo Core: Debian 13 + kernel Linux + systemd + MiSO base  │
├──────────────────────────────────────────────────────────────┤
│  Hardware x86_64: CPU, GPU, red, audio, USB, disco            │
└──────────────────────────────────────────────────────────────┘
```

Flujo de privilegios:

```text
usuario → miso (CLI) → pkexec → polkit → misod (root) → apt/systemd/btrfs
```

Flujo de actualización 0.1.0:

```text
miso update apply
  → misod valida y eleva
  → miso-updated crea instantánea btrfs
  → apt dist-upgrade
  → se conserva la instantánea para recuperación manual
```

Flujo objetivo 1.0:

```text
miso update apply
  → descarga imagen/paquetes al slot inactivo
  → verifica firmas y espacio
  → escribe entrada de arranque A/B
  → reinicia en el slot nuevo
  → health check; si falla, vuelve al slot anterior
```

---

## 6. Cómo se construye

### 6.1 Pipeline

1. **Preparar host:** Ubuntu/WSL2 con debootstrap, squashfs-tools, xorriso, GRUB.
2. **debootstrap:** rootfs Debian 13 mínimo.
3. **APT:** repos main/contrib/non-free-firmware y actualización base.
4. **Paquetes:** listas por perfil (`core`, `desktop`, `lab`).
5. **Marca y configuración:** overlays, herramientas MiSO, PJD, Calamares, assets.
6. **Initramfs:** `update-initramfs` con hooks de live-boot.
7. **Squashfs:** compresión zstd.
8. **ISO híbrida:** `grub-mkrescue` para BIOS y UEFI.
9. **Pruebas:** QEMU BIOS/UEFI, instalación, post-instalación.

### 6.2 Por qué este pipeline

- **Transparente:** cada etapa es un comando entendible, sin una caja negra.
- **Reproducible:** configuración versionada y versiones fijadas por suite.
- **Extensible:** añadir un anillo es añadir una lista y un hook.
- **Original:** no se remasteriza una ISO de Debian; se construye el rootfs y la ISO.

### 6.3 Perfiles

| Perfil | Contenido | Uso |
|---|---|---|
| `core` | Base, red, herramientas, live-boot | Validar arranque y pipeline |
| `desktop` | core + Plasma 6 + Calamares + Flatpak + PJD | Producto 0.1.0 |
| `lab` | desktop + software científico y educativo | Laboratorio completo |

---

## 7. Modelo de anillos

| Anillo | Contenido | Cadencia | Riesgo | Entrega |
|---|---|---|---|---|
| **Core** | Kernel, base, systemd, drivers, seguridad | Trimestral | Bajo | apt + instantánea |
| **Desktop** | Plasma, PJD, SDDM, portales | Mensual | Medio | apt + instantánea |
| **Lab** | Toolchain, ciencia, ofimática, virtualización | Semestral / opcional | Medio | meta-paquetes |
| **Apps** | Flatpak de usuario | Continua | Aislado | Flathub / MiSO Apps |

Reglas:

- Un fallo en Apps no debe impedir arrancar el sistema.
- Core y Desktop son obligatorios; Lab y Apps son opt-in.
- Cada anillo tiene su propio canal y su propia ventana de pruebas.
- Las actualizaciones de Core son las únicas que pueden requerir reinicio.

---

## 8. Actualizaciones y recuperación

### 8.1 0.1.0

- `miso update check` muestra paquetes pendientes.
- `miso update apply` crea una instantánea btrfs de solo lectura y ejecuta
  `apt dist-upgrade`.
- Si la actualización falla, la instantánea queda disponible para recuperación manual.
- `miso rollback list` lista instantáneas.
- `miso rollback restore <snap>` restaura los archivos del sistema desde una
  instantánea, conservando `/home` y `/.snapshots`, y deja una instantánea de
  seguridad del estado anterior.

Limitación conocida: en 0.1.0 todavía no se genera automáticamente una entrada de
arranque para cada instantánea ni un rollback automático. Eso llega con el diseño
A/B de una fase posterior.

### 8.2 Meta 1.0

- Dos slots de sistema (`A` y `B`) en subvolúmenes btrfs.
- El actualizador escribe en el slot inactivo, nunca en el que está corriendo.
- `grubenv` guarda el slot por defecto, el slot de intento y el contador de fallos.
- Un servicio de health check marca el arranque como bueno o programa el rollback.
- Las actualizaciones de Core se aplican por imagen; las de Apps no reinician.

---

## 9. Seguridad y privilegios

Controles incluidos en el diseño:

- **polkit + `misod`:** ninguna app necesita root; el broker valida verbo y argumentos.
- **AppArmor:** perfiles para servicios y aplicaciones compatibles.
- **Flatpak:** sandbox para aplicaciones de usuario con portales XDG.
- **Sin login root:** el administrador usa su usuario y `sudo`/polkit.
- **Repos firmados:** apt verifica firmas; HTTPS para metadatos.
- **Instantáneas:** recuperación ante una actualización defectuosa.
- **Firewall:** nftables/ufw con perfil de laboratorio.
- **LUKS opcional:** cifrado de disco desde Calamares.

Pendiente para 1.0: Secure Boot con claves propias, dm-verity para Core, arranque
medido, SBOM y compilación reproducible. El modelo de amenazas completo está en
`docs/03-anillos-y-seguridad.md`.

---

## 10. Instalador

Calamares se usa como motor gráfico, con configuración propia:

- Branding MiSO (logo, colores, textos en español).
- Particionado asistido y manual; btrfs por defecto, LUKS opcional.
- Usuario administrador en el grupo `sudo`; sin contraseña de root.
- Post-instalación: elimina el usuario live, habilita SDDM y servicios MiSO, configura
  Flatpak y deja el sistema listo para el primer arranque.
- El instalador se prueba en QEMU BIOS y UEFI antes de cada release.

---

## 11. Shell PJD

PJD no es un compositor nuevo. Es una **capa de experiencia** sobre Plasma:

- Look-and-feel `org.miso.pjd.desktop`.
- Layout de panel: lanzador, tareas, reloj, bandeja y escritorios.
- Esquema de color, tipografía, iconos y fondos MiSO.
- Splash de Plasma, tema SDDM y tema Plymouth.
- CLI `pjd` para restaurar el layout y alternar perfiles.

Esta decisión reduce riesgo y permite tener una identidad propia sin mantener un
compositor. Si en el futuro se quiere una shell totalmente distinta, Quickshell es la
vía natural, pero no bloquea el producto.

---

## 12. Aplicaciones

- **Flatpak + Discover** para el catálogo de usuario.
- Remoto Flathub y, más adelante, un remoto MiSO Apps curado por el laboratorio.
- Las apps no forman parte del anillo Core y no pueden romper el arranque.
- Las aplicaciones legacy se pueden ejecutar con `firejail` si no hay Flatpak.

---

## 13. Alcance por versión

| Versión | Alcance |
|---|---|
| **0.1.0 «Génesis»** | ISO live core/desktop, Plasma 6, PJD básico, Calamares, CLI y broker |
| **0.2.0** | Instalación verificada, primer arranque, branding completo, pruebas UEFI/BIOS |
| **0.3.0** | Anillos Lab/Apps, Flatpak, `miso doctor` completo |
| **0.4.0** | Actualizaciones con instantánea y rollback manual guiado |
| **1.0.0** | A/B atómico, Secure Boot, hardening, validación en hardware de laboratorio |

---

## 14. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Descargas y tiempos de build altos | Retraso | Perfil `core` primero; caché de APT; build incremental |
| Plasma Wayland falla en QEMU/GPU vieja | Bloqueo de pruebas | Entrada de arranque con X11 y `nomodeset` |
| Calamares no crea subvolúmenes A/B | Retraso Fase 4 | Módulo propio `miso-slotify` o instalador propio |
| Actualización de Plasma rompe sesión | Usuario bloqueado | Anillo Desktop separado y rollback |
| Falta de Secure Boot en 1.0 | Requisito de laboratorio | Plan de claves y shim en Fase 6 |
| Equipo pequeño | Mantenimiento | Automatización, documentación y alcance acotado |
| Dependencia de un solo host de build | Pérdida de reproducibilidad | Scripts versionados y build en contenedor/CI |

---

## 15. Criterios de éxito

Un release se considera aceptable cuando:

1. La ISO arranca en QEMU BIOS y UEFI sin errores bloqueantes.
2. Plasma 6 inicia en Wayland y existe fallback X11.
3. El instalador completa en un disco virtual y el sistema instalado arranca.
4. `miso status`, `miso doctor` y `miso update check` funcionan.
5. El usuario live no queda en el sistema instalado.
6. Las actualizaciones crean instantánea y no dejan el sistema inarrancable.
7. La documentación y el CHANGELOG describen el release.
8. No hay secretos, claves privadas ni binarios generados en el repositorio.

---

## 16. Estado actual y próximos pasos

**Hecho en Fase 0:**

- Carpeta `MiSO Desktop` y estructura del proyecto.
- Documentación completa (reporte, arquitectura, seguridad, componentes, build,
  pruebas, roadmap, ADRs, licencias).
- Pipeline de ISO y listas de paquetes.
- Prototipos de `miso`, `misod`, `miso-updated`, `miso-rings`, `miso-doctor`.
- Branding base y configuración inicial de Calamares/PJD.

**Hecho en Fase 1 (verificado en QEMU BIOS y UEFI):**

- ISO `core` de ~530 MB con Debian 13 y kernel Linux 6.12.
- Arranque GRUB, login `live`/`live` y consola por serial.
- Red DHCP y `ping` funcionando.
- `miso status`, `miso doctor`, `miso ring list` y `miso rollback list`.
- AppArmor, nftables y política de root sin login.
- Prueba automática por serial (`scripts/serial-smoke.ps1`).

**Hecho en Fase 2 (verificado con captura de pantalla):**

- ISO `desktop` de ~2.3 GiB con KDE Plasma 6.3.6.
- Sesión Wayland (`kwin_wayland` + `plasmashell`), SDDM y PJD aplicado.
- Branding MiSO en GRUB, Plymouth, fondos, logo y login.

**Hecho en Fase 3 (verificado con `scripts/test-install.sh`):**

- Instalación en disco con subvolúmenes btrfs `@`, `@home` y `@snapshots`.
- Post-instalación real: usuario administrador, `live` eliminado, root sin shell.
- GRUB BIOS y UEFI; el sistema instalado arranca sin la ISO.

**Hecho en Fase 4 (rollback manual):**

- Instantáneas de solo lectura antes de actualizar.
- `miso rollback restore` restaura el sistema y conserva `/home`.
- Reinicio verificado después de restaurar.

**Siguiente:**

1. Recorrer la interfaz gráfica de Calamares de principio a fin.
2. Añadir entradas de arranque para instantáneas y rollback automático.
3. Probar LUKS y audio en hardware real.
4. Validar en dos modelos de PC de laboratorio.

---

## 17. Conclusión

MiSO Desktop no compite por tener el kernel más original, sino por ser un escritorio
de laboratorio **confiable, recuperable y con identidad propia**. Debian y Plasma
aportan la base; MiSO aporta los anillos, la seguridad, las actualizaciones, el
instalador, la shell y la marca. Esa es la diferencia entre un remaster y un producto.
