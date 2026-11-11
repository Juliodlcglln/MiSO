# Decisiones técnicas (ADR)

Registro de decisiones de arquitectura. Cada ADR indica contexto, decisión,
consecuencias y alternativas. Una decisión se puede revisar, pero se documenta el cambio.

---

## ADR-001 — Usar Linux (no un kernel desde cero)

**Estado:** aceptada · **Fecha:** 2026-11-07 · **Revisada:** 2026-11-10

**Contexto:** MiSO Core llegó a las etapas 1–6 (arranque, VGA, teclado, interrupciones,
memoria, hilos, shell). El objetivo es un escritorio con GUI, drivers y aplicaciones.

**Decisión:** archivar MiSO Core y usar el kernel Linux como base de MiSO Desktop.
Desde 0.1.0 MiSO **compila su propio kernel** (`6.12.x-miso`) a partir del código
fuente de Linux y de una configuración versionada en `kernel/`; no se reescribe el
kernel ni se mantiene un árbol de parches propio.

**Consecuencias:**

- Se obtienen drivers, seguridad y mantenimiento de la comunidad.
- El equipo se enfoca en integración, seguridad, instalador y experiencia.
- MiSO Core queda como referencia histórica, no como producto.
- El kernel es identificable (`uname -r` → `6.12.x-miso`) y su configuración es
  auditable (`/proc/config.gz`), sin perder el soporte de hardware de Debian.

**Alternativas descartadas:** continuar el kernel desde cero (años de trabajo, sin
ecosistema), usar un kernel de hobby (sin drivers modernos), limitarse a renombrar
el kernel de Debian (no demuestra una configuración propia).

---

## ADR-002 — Debian 13 «Trixie» como base

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** se necesita una base estable, construible y con KDE Plasma 6.

**Decisión:** Debian 13 Trixie, x86_64, con componentes `main`, `contrib` y
`non-free-firmware`.

**Consecuencias:**

- Estabilidad y soporte a largo plazo.
- debootstrap, apt y Calamares bien documentados.
- Plasma llega algo después que en Fedora; se acepta por estabilidad.
- La atomicidad se implementa con btrfs/GRUB, no viene incluida.

**Alternativas:**

- **Fedora Kinoite/bootc:** mejor atomicidad, pero mayor complejidad y menor control.
- **Arch:** Plasma reciente, pero rolling release incompatible con laboratorio.
- **Ubuntu:** Snap y decisiones de Canonical; menos control.
- **LFS:** control total, pero inviable para el equipo.

---

## ADR-003 — KDE Plasma 6 con Wayland y fallback X11

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** se necesita un escritorio maduro, personalizable y con apps.

**Decisión:** Plasma 6 en Wayland por defecto, con sesión X11 disponible.

**Consecuencias:**

- Wayland es el futuro y funciona bien en hardware moderno.
- X11 sigue disponible para GPUs o apps problemáticas.
- PJD puede personalizar Plasma sin mantener un compositor.

**Alternativas:** GNOME (menos personalizable), XFCE (menos moderno), compositor propio
(coste enorme).

---

## ADR-004 — GRUB como gestor de arranque

**Estado:** aceptada para 0.1.0 · **Revisable en Fase 4**

**Contexto:** la ISO y el sistema instalado deben arrancar en BIOS y UEFI.

**Decisión:** GRUB en la ISO y en el sistema instalado.

**Consecuencias:**

- Soporte BIOS/UEFI con una sola configuración.
- Calamares lo soporta de forma nativa.
- Para A/B con systemd-boot/UKI habría que migrar en Fase 4.

**Alternativas:** systemd-boot (simple, pero solo UEFI y menos flexible para BIOS),
EFISTUB (frágil con múltiples kernels).

---

## ADR-005 — btrfs con instantáneas

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** se necesita recuperación ante actualizaciones defectuosas.

**Decisión:** btrfs como sistema de archivos por defecto, con instantáneas de solo
lectura antes de actualizar.

**Consecuencias:**

- Instantáneas eficientes y rollback viable.
- Requiere `btrfs-progs` y cuidado con el espacio.
- En 0.1.0 el rollback es manual (`miso rollback restore`); en 1.0 se automatiza.

**Alternativas:** ext4 + rsync (más lento y espacio), ZFS (licencia y complejidad),
LVM (menos flexible para snapshots de subvolumen).

---

## ADR-006 — Calamares como instalador

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** se necesita un instalador gráfico probado y extensible.

**Decisión:** Calamares con branding, módulos y post-instalación MiSO.

**Consecuencias:**

- Instalador maduro, traducido y con soporte de particionado/LUKS.
- Se personaliza sin reescribir el motor.
- Para A/B hará falta un módulo propio o un paso posterior.

**Alternativas:** instalador propio (mucho trabajo), Anaconda (complejo), Ubiquity
(obsoleto).

---

## ADR-007 — Flatpak para aplicaciones de usuario

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** las apps no deben romper el sistema base ni requerir root.

**Decisión:** Flatpak + Discover, con Flathub y un futuro remoto MiSO Apps.

**Consecuencias:**

- Sandbox y actualizaciones independientes.
- Más espacio en disco y permisos que revisar.
- Las apps legacy pueden usar firejail o paquetes del sistema.

**Alternativas:** solo apt (riesgo para el sistema), Snap (dependencia de Canonical),
AppImage (sin sandbox ni actualizaciones centralizadas).

---

## ADR-008 — PJD como capa sobre Plasma, no compositor propio

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** se quiere identidad propia sin asumir el coste de un compositor.

**Decisión:** PJD es un look-and-feel + layout + tema + CLI sobre Plasma.

**Consecuencias:**

- Identidad y experiencia propias con bajo riesgo.
- Se hereda el trabajo de KDE.
- Si se quiere una shell distinta, Quickshell es la evolución natural.

**Alternativas:** compositor propio (inviable), shell basada en Quickshell desde el
inicio (más riesgo), GNOME personalizado (menos flexible).

---

## ADR-009 — Anillos con apt y pinning (no OSTree en 0.1.0)

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** se necesita separar Core, Desktop, Lab y Apps.

**Decisión:** anillos lógicos sobre apt (listas, pinning y metapaquetes) y Flatpak para
Apps; la atomicidad llega con btrfs/GRUB.

**Consecuencias:**

- Simple y compatible con Debian.
- La separación no es tan fuerte como OSTree/bootc.
- Se puede migrar a imagen completa en 2.0.

**Alternativas:** OSTree (curva y ecosistema), Nix (paradigma distinto), bootc (futuro).

---

## ADR-010 — Build con debootstrap + squashfs + grub-mkrescue

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** se necesita construir una ISO propia, no remasterizar.

**Decisión:** pipeline transparente en bash con debootstrap, mksquashfs y grub-mkrescue.

**Consecuencias:**

- Control total y pasos entendibles.
- Más mantenimiento que live-build, pero sin cajas negras.
- Requiere host Linux/WSL con dependencias.

**Alternativas:** live-build (más configuración y menos control), remasterizar una ISO
(no es el objetivo), image builder (futuro).

---

## ADR-011 — `misod` efímero con pkexec en 0.1.0

**Estado:** aceptada · **Revisable en Fase 5**

**Contexto:** se necesita privilegio separado ya, sin construir un daemon D-Bus.

**Decisión:** `miso` invoca `pkexec /usr/libexec/miso/misod <verbo>`; polkit autentica.

**Consecuencias:**

- Separación real y auditable desde el primer día.
- Una autenticación por operación (aceptable en 0.1.0).
- En Fase 5 se convierte en servicio D-Bus con la misma interfaz.

**Alternativas:** `sudo` directo (menos control), daemon desde el inicio (más trabajo),
setuid (peligroso).

---

## ADR-012 — Documentación en español, código en inglés

**Estado:** aceptada · **Fecha:** 2026-11-07

**Contexto:** el equipo y el laboratorio son hispanohablantes; el ecosistema técnico
está en inglés.

**Decisión:** documentación y mensajes de usuario en español; nombres de código,
variables y commits en inglés.

**Consecuencias:**

- Documentación accesible para el equipo.
- Código consistente con el ecosistema.
- Los mensajes de usuario se pueden traducir en el futuro con gettext.
