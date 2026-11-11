# Roadmap de MiSO Desktop

El roadmap se organiza en fases con entregables y criterios de aceptación. Las
estimaciones son orientativas y asumen un equipo pequeño trabajando en paralelo con
otras responsabilidades.

---

## Resumen

| Fase | Objetivo | Estado | Estimación |
|---|---|---|---|
| F0 | Documentación y esqueleto | **Completada** | — |
| F1 | ISO live mínima (`core`) | **Completada** | 1–2 semanas |
| F2 | ISO live con Plasma + PJD | **Completada** | 2–3 semanas |
| F3 | Instalador y sistema instalado | **Completada** | 2–3 semanas |
| F4 | Actualizaciones con rollback | **Parcial (0.1.0)** | 3–4 semanas |
| F5 | Anillos, Flatpak y `misod` D-Bus | Parcial | 3–4 semanas |
| F6 | Hardening, Secure Boot y laboratorio | Pendiente | 4–6 semanas |

> **Estado de 0.1.0 «Génesis»:** el sistema ya es funcional de punta a punta en
> QEMU: ISO live con Plasma 6, instalación en disco con subvolúmenes btrfs, sistema
> instalado que arranca solo, actualizaciones con instantánea y restauración
> verificada. Lo que falta de F4 es el **arranque directo desde instantánea y el
> rollback automático A/B**; el rollback manual por restauración de archivos ya
> funciona.

---

## Fase 0 — Documentación y esqueleto

**Objetivo:** dejar claro qué se construye, cómo y con qué reglas.

Entregables:

- [x] Carpeta `MiSO Desktop` y estructura del repositorio.
- [x] Reporte del proyecto.
- [x] Arquitectura, anillos, seguridad y componentes.
- [x] Proceso de build, pruebas y roadmap.
- [x] ADRs y licencias.
- [x] Pipeline de ISO y listas de paquetes.
- [x] Prototipos de `miso`, `misod`, `miso-updated`, `miso-rings`, `miso-doctor`.
- [x] Branding base y configuración de Calamares/PJD.

**Criterio de aceptación:** la documentación permite a otra persona entender y ejecutar
el proyecto sin contexto adicional.

---

## Fase 1 — ISO live mínima (`core`)

**Objetivo:** demostrar que el pipeline produce una ISO arrancable.

Entregables:

- [x] ISO `core` que arranca en QEMU BIOS.
- [x] ISO `core` que arranca en QEMU **UEFI** (OVMF).
- [x] Consola con login `live` (contraseña `live`).
- [x] Red funcional (DHCP + `ping` a `deb.debian.org`).
- [x] `miso status`, `miso doctor`, `miso ring list` y `miso rollback list`.
- [x] AppArmor habilitado y firewall nftables activo.
- [x] Logs de arranque legibles por serial.
- [x] Arranque UEFI verificado (OVMF, `[ OK ] Arranque UEFI`).

Tareas:

1. [x] Ejecutar `install-host-deps.sh` en WSL.
2. [x] Construir `--profile core`.
3. [x] Corregir debootstrap, initramfs y GRUB.
4. [x] Probar UEFI.
5. [x] Añadir un smoke test por serial (`scripts/serial-smoke.ps1`).
6. [x] Documentar los comandos que funcionaron.

**Estado:** BIOS y UEFI verificados; login, red, anillos y diagnóstico funcionan.

**Criterio de aceptación:** la ISO arranca en ambos firmware y la red responde sin
pasos manuales.

---

## Fase 2 — ISO live con Plasma + PJD

**Objetivo:** tener el escritorio MiSO funcionando en live.

Entregables:

- [x] ISO `desktop` con KDE Plasma 6 (6.3.6).
- [x] SDDM con branding MiSO (fondo, logo y color).
- [x] PJD Shell aplicado a usuarios nuevos.
- [x] Wayland por defecto y fallback X11.
- [x] Branding: GRUB, Plymouth, fondos, logo.
- [x] `miso-welcome` en la sesión live.
- [x] Calamares instalable desde el escritorio.

Tareas:

1. [x] Ajustar listas de paquetes de Plasma.
2. [x] Validar PJD en Plasma 6.
3. [x] Resolver GPU/Wayland en QEMU.
4. [x] Probar red (audio pendiente de hardware real).
5. [x] Medir RAM y tiempo de arranque.
6. [x] Corregir el tema SDDM/Plymouth.

**Estado:** sesión live verificada con captura de pantalla: `kwin_wayland` +
`plasmashell`, PJD aplicado (`LookAndFeelPackage=org.miso.pjd.desktop`), red
funcional y `miso doctor` sin fallos.

---

## Fase 3 — Instalador y sistema instalado

**Objetivo:** instalar MiSO en disco y arrancar sin la ISO.

Entregables:

- [x] Calamares con branding y módulos MiSO.
- [x] Instalación BIOS y UEFI (GRUB en ambos firmware).
- [x] Post-instalación que elimina el usuario live.
- [x] Sistema instalado con SDDM, PJD y Flatpak.
- [x] Subvolúmenes btrfs `@`, `@home`, `@snapshots` y `fstab` correcto.
- [x] LUKS opcional (configurado en Calamares; sin probar aún).
- [x] Primer arranque funcional sin la ISO.

Tareas:

1. [x] Completar `settings.conf` y módulos.
2. [x] Validar `unpackfs` y `bootloader`.
3. [x] Escribir y probar `miso-postinstall.sh`.
4. [x] Probar instalación automática (`scripts/test-install.sh`) y manual.
5. [ ] Probar LUKS.
6. [x] Documentar el flujo y los errores.

**Estado:** la instalación está verificada de forma reproducible con
`scripts/test-install.sh` (extrae el sistema del ISO, ejecuta el post-instalación
real e instala GRUB BIOS+UEFI). El sistema instalado arranca solo, con usuario
`alumno`, `live` eliminado, root sin shell, SDDM activo y raíz btrfs en `subvol=@`.
La interfaz gráfica de Calamares queda como comprobación de humo pendiente.

---

## Fase 4 — Actualizaciones con rollback

**Objetivo:** que una actualización no deje el sistema inarrancable.

Entregables:

- [x] `miso update apply` con instantánea btrfs.
- [x] `miso rollback list` y recuperación guiada.
- [x] `miso rollback restore <snap>` con restauración de archivos (conserva `/home`).
- [ ] Entradas de arranque para instantáneas o diseño A/B.
- [ ] Health check de arranque.
- [ ] Retención de instantáneas.
- [x] Pruebas de fallo y recuperación (restauración + reinicio verificado).

Tareas:

1. [x] Decidir GRUB+snapshots vs A/B+systemd-boot (0.1.0: GRUB+snapshots).
2. [ ] Implementar montaje del slot inactivo.
3. [ ] Implementar `grubenv` y health check.
4. [ ] Implementar rollback automático.
5. [x] Probar recuperación tras modificar el sistema.
6. [x] Documentar el procedimiento.

**Estado:** el rollback manual está verificado de punta a punta en el sistema
instalado. `miso update apply` crea una instantánea de solo lectura en
`/.snapshots`; `miso rollback restore <snap>` restaura los archivos del sistema
(excepto `/home`, `/.snapshots` y `/boot/efi`), deja una instantánea de seguridad y
el equipo reinicia sin errores. El rollback **automático** y el arranque directo
desde una instantánea quedan para una versión posterior de F4.

---

## Fase 5 — Anillos, Flatpak y `misod` D-Bus

**Objetivo:** completar el modelo de anillos y el ecosistema de apps.

Entregables:

- [x] `miso ring enable lab` y `apps` (estado persistente en `/var/lib/miso/rings`).
- [ ] Repo MiSO firmado (paquetes propios).
- [x] Flathub + Discover (Flatpak configurado en la ISO).
- [ ] `misod` como servicio D-Bus persistente.
- [ ] Pinning de anillos.
- [x] `miso app` básico (`list`, `search`, `install`, `remove`, `update`).

Tareas:

1. [ ] Empaquetar `miso-base-files`, `misod`, `miso-updated`, `miso-rings`, `pjd-shell`.
2. [ ] Montar repo con `aptly` o `reprepro`.
3. [ ] Firmar con clave MiSO.
4. [ ] Implementar D-Bus y polkit persistente.
5. [ ] Curar el catálogo MiSO Apps.
6. [x] Probar actualizaciones por anillo (habilitar/deshabilitar y estado).

**Estado:** los anillos funcionan a nivel de estado y las apps Flatpak se gestionan
con `miso app`; falta el repo firmado y convertir `misod` en servicio D-Bus.

---

## Fase 6 — Hardening, Secure Boot y laboratorio

**Objetivo:** preparar el despliegue real.

Entregables:

- Secure Boot con claves MiSO o MOK.
- dm-verity para Core.
- AppArmor y firewall afinados.
- USBGuard y auditd opcionales.
- SBOM y compilación reproducible.
- Validación en al menos dos modelos de PC.
- Guía de despliegue y recuperación.

Tareas:

1. Generar y custodiar claves.
2. Firmar shim/GRUB/kernel.
3. Probar en hardware real.
4. Medir rendimiento y consumo.
5. Documentar BIOS/UEFI por modelo.
6. Formar al personal del laboratorio.

**Criterio de aceptación:** instalación y recuperación verificadas en hardware de
laboratorio con Secure Boot activo.

---

## Backlog

Ideas no comprometidas:

- PJD basada en Quickshell.
- Actualización por imagen OCI/bootc.
- Soporte de impresoras y escáneres.
- Perfil de kiosco para exámenes.
- Gestión remota del laboratorio.
- Imagen para USB persistente.
- Soporte ARM (no prioritario).
- Telemetría opt-in (solo si hay consentimiento).
- Modo offline con repo local.

---

## Hitos de versión

| Versión | Hito |
|---|---|
| 0.1.0 | ISO core/desktop, instalación verificada, branding y rollback manual |
| 0.2.0 | Arranque directo desde instantánea, retención y rollback automático |
| 0.3.0 | Anillos Lab/Apps con repo firmado y Flatpak curado |
| 0.4.0 | `misod` D-Bus, pinning y actualizaciones por anillo |
| 1.0.0 | A/B, Secure Boot y validación en laboratorio |

---

## Riesgos del roadmap

- El perfil desktop puede tardar más por dependencias de Plasma.
- Calamares puede requerir un módulo propio para A/B.
- Secure Boot exige custodia de claves y pruebas en hardware.
- El equipo pequeño puede retrasar F5/F6.

Mitigación: entregar valor en cada fase, no bloquear F1 por F4, y documentar todo.
