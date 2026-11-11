# Arquitectura de MiSO Desktop

Este documento describe el diseño objetivo 1.0 y señala qué parte existe en 0.1.0.

---

## 1. Principios

1. **Componentes maduros, integración propia.** No reescribimos kernel, compositor ni
   instalador; los integramos con reglas MiSO.
2. **Separación de canales.** Core, Desktop, Lab y Apps evolucionan a distinto ritmo.
3. **Recuperación antes que perfección.** Toda actualización debe poder deshacerse.
4. **Privilegio mínimo.** El escritorio corre como usuario; lo administrativo pasa por
   polkit y `misod`.
5. **Reproducibilidad.** El build se describe con scripts versionados, no con pasos
   manuales.
6. **Hardware primero.** x86_64, UEFI y BIOS, GPUs integradas y discretas, red cableada
   y Wi-Fi, audio y USB.

---

## 2. Capas

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Experiencia      PJD Shell · Plasma · SDDM · Discover · apps        │
├─────────────────────────────────────────────────────────────────────┤
│ Distribución     Anillo Desktop · Anillo Lab · Anillo Apps          │
├─────────────────────────────────────────────────────────────────────┤
│ Sistema base     Anillo Core · Debian 13 · systemd · NetworkManager │
├─────────────────────────────────────────────────────────────────────┤
│ Kernel           Linux 6.12 + config MiSO · módulos · initramfs     │
├─────────────────────────────────────────────────────────────────────┤
│ Hardware         x86_64 · UEFI/BIOS · GPU · red · audio · USB       │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.1 Responsabilidades

| Capa | Responsable | No debe hacer |
|---|---|---|
| Kernel | MiSO (compilado desde Linux) | Branding de escritorio ni decisiones de producto |
| Core | MiSO + Debian | Depender de Plasma |
| Desktop | MiSO + KDE | Cambiar el kernel sin pasar por Core |
| Lab | MiSO (metapaquetes) | Ser obligatorio para arrancar |
| Apps | Flatpak/terceros | Escribir en el sistema base |
| PJD | MiSO | Reimplementar el compositor |

### 2.2 Kernel MiSO

MiSO compila su propio kernel a partir de Linux 6.12 y de la configuración de
Debian 13, con cambios propios mínimos:

| Opción | Valor MiSO | Efecto |
|---|---|---|
| `CONFIG_LOCALVERSION` | `-miso` | `uname -r` → `6.12.x-miso` |
| `CONFIG_IKCONFIG_PROC` | `y` | `/proc/config.gz` auditable |
| `CONFIG_DEBUG_INFO` | `n` | Imagen y módulos más pequeños |
| `CONFIG_DEFAULT_HOSTNAME` | `miso` | Nombre por defecto |

El código, la configuración y el script de compilación viven en `kernel/`. La ISO
instala `linux-image-*-miso` y conserva el kernel de Debian como respaldo en GRUB.

---

## 3. Arranque

### 3.1 ISO live (0.1.0)

```text
Firmware (UEFI/BIOS)
  → GRUB de la ISO
    → /live/vmlinuz + /live/initrd.img
      → live-boot monta /live/filesystem.squashfs con overlay en RAM
        → systemd
          → SDDM
            → sesión live (usuario live)
              → Calamares (instalador)
```

Características:

- ISO híbrida generada con `grub-mkrescue`.
- Soporte BIOS (El Torito) y UEFI (FAT interno de la ISO).
- Overlay en RAM: los cambios de la sesión live no persisten.
- Entrada de arranque de rescate con `nomodeset` y sesión X11.

### 3.2 Sistema instalado (0.1.0)

```text
Firmware
  → GRUB en ESP (/EFI/MiSO/grubx64.efi) o MBR
    → kernel + initramfs en /boot
      → systemd
        → SDDM
          → Plasma Wayland (fallback X11)
```

### 3.3 Sistema instalado (1.0, A/B)

```text
Firmware
  → GRUB
    → slot A (@root-a) o slot B (@root-b), según grubenv
      → kernel del slot
        → systemd
          → health check
            → marca el slot como bueno o programa rollback
```

---

## 4. Almacenamiento

### 4.1 0.1.0

```text
Disco
├── ESP FAT32 (512 MiB)          /boot/efi
├── btrfs (resto)
│   ├── @                        /
│   ├── @home                    /home
│   └── @snapshots               /.snapshots
└── swap (archivo o partición, opcional)
```

- Calamares crea los subvolúmenes `@`, `@home` y `@snapshots` (definidos en
  `mount.conf`).
- `/.snapshots` es un subvolumen aparte para que las instantáneas no se incluyan
  a sí mismas.
- `miso-updated` crea instantáneas de solo lectura de `@` antes de actualizar.
- `miso rollback restore` restaura los archivos de `@` y conserva `/home`.
- El cifrado LUKS es opcional desde el instalador.

### 4.2 1.0

```text
Disco
├── ESP FAT32 (1 GiB)            /boot/efi
├── btrfs
│   ├── @root-a                  slot A
│   ├── @root-b                  slot B
│   ├── @home                    /home
│   ├── @var                     /var
│   ├── @snapshots               /.snapshots
│   └── @swap                    swapfile
└── (opcional) LUKS2
```

Reglas:

- `/home` y `/var` se comparten entre slots para no duplicar datos.
- Cada slot tiene su propio `/usr`, `/etc` y `/boot`.
- Las instantáneas viven fuera del slot activo.
- El ESP contiene kernels/UKIs y entradas de arranque; nunca datos de usuario.

---

## 5. Actualizaciones

### 5.1 0.1.0: instantánea + apt

```text
miso update apply
  → misod (polkit, root)
    → miso-updated apply
      → btrfs subvolume snapshot -r / /.snapshots/rollback-<fecha>
      → apt-get update
      → apt-get dist-upgrade
      → registrar resultado en /var/log/miso/updates.log
```

Ventajas: simple, usa apt y paquetes Debian.
Limitaciones: la actualización ocurre en el sistema vivo; si el arranque queda roto,
la recuperación es manual (`miso rollback restore`). El rollback automático A/B
llega en la meta 1.0.

### 5.2 1.0: A/B atómico

```text
miso update apply
  → verificar espacio y firmas
  → montar slot inactivo
  → aplicar paquetes/imagen en el slot inactivo
  → generar initramfs y entrada GRUB
  → grubenv: default=<nuevo>, try=<nuevo>, fallos=0
  → reiniciar
    → health check (systemd, SDDM, red, disco)
      → OK: marcar slot bueno, limpiar intento
      → FALLO: incrementar contador; GRUB vuelve al slot anterior
```

Propiedades:

- **Atómico:** el slot activo no se modifica.
- **Reversible:** el slot anterior queda intacto.
- **Verificable:** el health check decide si el arranque es válido.
- **Sin downtime de datos:** `/home` y `/var` son compartidos.

### 5.3 Health check

Comprueba, como mínimo:

- systemd alcanzó `multi-user.target`.
- SDDM está activo (si el perfil es desktop).
- La raíz está montada y escribible.
- NetworkManager responde.
- No hay unidades en estado `failed` críticas.
- El espacio libre supera el umbral.

Si falla, escribe `miso_boot_failed=1` en `grubenv` y reinicia.

---

## 6. Paquetes y anillos

### 6.1 Apt para el sistema

- Repos Debian: `main`, `contrib`, `non-free-firmware`.
- Repo MiSO: paquetes propios (`miso-base-files`, `misod`, `miso-updated`,
  `miso-rings`, `pjd-shell`, `miso-branding`).
- Pinning por anillo para evitar que Lab arrastre versiones inestables a Core.

### 6.2 Flatpak para aplicaciones

- Remoto Flathub habilitado por defecto.
- Remoto MiSO Apps (curado) en Fase 5.
- Instalación por usuario (`--user`) salvo apps de sistema justificadas.
- Discover como interfaz; `miso app` como CLI.

### 6.3 Flujo de un paquete

```text
Origen (Debian/MiSO/Flathub)
  → verificación de firma
  → descarga
  → instalación en slot/anillo correspondiente
  → registro en /var/lib/miso/state.json (futuro)
```

---

## 7. Privilegios

```text
┌────────────┐     ┌──────────────┐     ┌────────────┐     ┌──────────────┐
│ App/Usuario│ ──> │ miso (CLI)   │ ──> │ pkexec     │ ──> │ misod (root) │
└────────────┘     └──────────────┘     │ + polkit   │     └──────┬───────┘
                                        └────────────┘            │
                                                                  ▼
                                                        apt · systemd · btrfs
```

Reglas:

- `misod` valida el verbo y los argumentos con listas y expresiones regulares.
- No acepta rutas arbitrarias ni comandos de shell.
- Registra cada operación en `/var/log/miso/misod.log`.
- Las apps de usuario no pueden invocar `misod` sin autenticación polkit.
- En 1.0, `misod` será un servicio D-Bus persistente con la misma interfaz.

---

## 8. Instalador

```text
Calamares
  ├── welcome / locale / keyboard
  ├── partition (btrfs, LUKS opcional)
  ├── users (administrador en sudo)
  ├── unpackfs (squashfs → disco)
  ├── modules de sistema (fstab, locale, red, reloj)
  ├── shellprocess@miso (post-instalación)
  ├── bootloader (GRUB BIOS/UEFI)
  └── finished
```

El módulo `shellprocess@miso`:

- Elimina el usuario live.
- Habilita SDDM, `miso-firstboot` y `miso-boot-ok`.
- Configura Flatpak.
- Deja `/var/lib/miso/installed` como marca.
- No instala software de laboratorio: eso lo decide el usuario con `miso ring`.

---

## 9. Shell PJD

```text
PJD Shell
├── Look-and-feel org.miso.pjd.desktop
├── Layout de panel (Plasma JS)
├── Esquema de color MiSO
├── Splash de Plasma
├── Tema SDDM
├── Tema Plymouth
└── CLI pjd (restaurar layout, perfiles)
```

PJD se instala en `/usr/share/plasma/look-and-feel/org.miso.pjd.desktop/` y se activa
para usuarios nuevos mediante `/etc/skel/.config/kdeglobals`.

---

## 10. Red y hardware

- **Red:** NetworkManager + plasma-nm; DHCP por defecto; Wi-Fi con firmware
  `non-free-firmware`.
- **Audio:** PipeWire + WirePlumber + plasma-pa.
- **Gráficos:** Mesa, Wayland por defecto, X11 como fallback; `nomodeset` para rescate.
- **Impresión:** CUPS + system-config-printer (Fase 2).
- **Bluetooth:** BlueDevil + BlueZ.
- **Energía:** power-profiles-daemon y tlp opcional en laboratorio.

---

## 11. Restricciones de diseño

| Restricción | Consecuencia |
|---|---|
| x86_64 solamente | No se optimiza para ARM ni 32 bits |
| UEFI + BIOS | La ISO y el instalador deben soportar ambos |
| PCs modernas de laboratorio | Se prioriza UEFI, NVMe y GPU integrada |
| Sin nube obligatoria | Todo debe funcionar offline tras instalar |
| Equipo pequeño | Se automatiza y se documenta; se evita mantener código innecesario |
| GPL aceptable | Se puede reutilizar upstream y publicar las modificaciones |

---

## 12. Decisiones abiertas

1. ¿A/B con GRUB o systemd-boot + UKI en 1.0?
2. ¿Imagen completa (bootc/OCI) o paquetes en slot inactivo?
3. ¿Repositorio propio con `aptly`/`reprepro` o snapshot de Debian?
4. ¿PJD se queda en Plasma o migra a Quickshell en 2.0?
5. ¿Secure Boot con shim de distribución o claves propias del laboratorio?

Estas decisiones se registran en `docs/08-decisiones-tecnicas.md` cuando se cierren.
