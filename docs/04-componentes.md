# Componentes de MiSO Desktop

Mapa de componentes, rutas e interfaces. El estado indica si el componente existe en
0.1.0 o si es un esqueleto.

---

## 1. Resumen

| Componente | Ruta en el repo | Ruta en el sistema | Estado 0.1.0 |
|---|---|---|---|
| Sistema de build | `build/` | — | Funcional (a validar) |
| Listas de paquetes | `build/packages/` | — | Funcional |
| Overlays | `build/overlays/` | `/` | Funcional |
| CLI `miso` | `tools/bin/miso` | `/usr/bin/miso` | Prototipo |
| Broker `misod` | `tools/libexec/misod` | `/usr/libexec/miso/misod` | Prototipo |
| Actualizador | `tools/bin/miso-updated` | `/usr/bin/miso-updated` | Prototipo |
| Anillos | `tools/bin/miso-rings` | `/usr/bin/miso-rings` | Prototipo |
| Diagnóstico | `tools/bin/miso-doctor` | `/usr/bin/miso-doctor` | Prototipo |
| PJD Shell | `pjd-shell/` | `/usr/share/plasma/look-and-feel/` | Esqueleto |
| Branding | `branding/` | `/usr/share/...` | Base |
| Instalador | `installer/calamares/` | `/etc/calamares/` | Esqueleto |
| Anillos/repos | `repos/` | `/etc/miso/` | Definición |
| Pruebas | `tests/` | — | Matriz manual |

---

## 2. `miso-base-files`

**Responsabilidad:** identidad del sistema, configuración base y archivos comunes.

Incluye:

- `/etc/os-release`, `/etc/miso/release`, `/etc/hostname`, `/etc/hosts`.
- `/etc/default/locale`, `/etc/default/keyboard`, zona horaria.
- `/etc/sudoers.d/` base (sin NOPASSWD en instalado).
- `/etc/sysctl.d/90-miso.conf` (endurecimiento básico).
- `/etc/miso/rings.yaml`.

**Interfaz:** archivos de configuración estándar; no expone comandos.

**Estado:** implementado como overlay en `build/overlays/`; el paquete `.deb` llega en
Fase 2.

---

## 3. `miso` (CLI de usuario)

**Responsabilidad:** punto de entrada único para el usuario.

```text
miso status
miso update [check|apply]
miso rollback [list|boot]
miso ring <list|enable|disable> <anillo>
miso app <list|search|install|remove>
miso doctor
miso info
```

**Diseño:**

- No corre como root.
- Los comandos administrativos usan `pkexec` y `misod`.
- Los comandos de apps usan Flatpak de usuario.
- La salida es legible y en español; los códigos de salida son estables.

**Ruta:** `tools/bin/miso` → `/usr/bin/miso`.

---

## 4. `misod` (broker de privilegios)

**Responsabilidad:** ejecutar operaciones administrativas validadas.

```text
misod update check|apply
misod rollback list|restore <snapshot>|boot <snapshot>
misod ring list|enable|disable <anillo>
misod install <paquete>
misod service <servicio> start|stop|restart|status
```

**Invariantes:**

- Solo root.
- Lista cerrada de verbos.
- Validación estricta de argumentos.
- Log en `/var/log/miso/misod.log`.
- Polkit mediante `org.miso.desktop.admin`.

**Ruta:** `tools/libexec/misod` → `/usr/libexec/miso/misod`.

**Evolución 1.0:** servicio D-Bus `org.miso.Admin1` con la misma semántica.

---

## 5. `miso-updated`

**Responsabilidad:** comprobar y aplicar actualizaciones de forma segura.

```text
miso-updated check                 # simulación de dist-upgrade
miso-updated apply                 # instantánea + apt dist-upgrade
miso-updated list                  # lista instantáneas
miso-updated restore <snap> [--yes] # restaura archivos desde la instantánea
miso-updated boot <snap>           # reservado para Fase 4
```

**Comportamiento 0.1.0:**

1. Verifica que la raíz sea btrfs y un subvolumen (`can_snapshot`).
2. Crea `/.snapshots/rollback-<fecha>` de solo lectura.
3. Ejecuta `apt-get update` y `apt-get dist-upgrade`.
4. Registra el resultado en `/var/log/miso/updates.log`.
5. Conserva la instantánea.

**Restauración (`restore`):**

1. Crea una instantánea de seguridad del estado actual.
2. Monta la instantánea elegida en modo lectura por `subvolid`.
3. Sincroniza con `rsync -aHAX --delete`, excluyendo `/home`, `/.snapshots`,
   `/boot/efi` y los sistemas de archivos virtuales.
4. Registra la fecha en `/var/lib/miso/last-rollback`.

**Limitación:** no genera entrada de arranque para la instantánea; el rollback
automático A/B es una fase posterior.

**Ruta:** `tools/bin/miso-updated` → `/usr/bin/miso-updated`.

---

## 6. `miso-rings`

**Responsabilidad:** habilitar o deshabilitar anillos opcionales.

```text
miso-rings list
miso-rings enable lab|apps
miso-rings disable lab|apps
```

**Reglas:**

- Core y Desktop no se pueden deshabilitar.
- Habilitar Lab instala su lista de paquetes.
- Deshabilitar Lab no desinstala; solo deja de gestionarlo.
- Habilitar Apps configura el remoto Flathub.

**Ruta:** `tools/bin/miso-rings` → `/usr/bin/miso-rings`.

---

## 7. `miso-doctor`

**Responsabilidad:** diagnóstico legible del estado del sistema.

Comprueba:

- Identidad MiSO y versión.
- Kernel y arquitectura.
- Modo de firmware (UEFI/BIOS) y Secure Boot.
- Sistema de archivos y espacio libre.
- Instantáneas disponibles.
- AppArmor y firewall.
- Flatpak y remotos.
- Actualizaciones pendientes.
- Unidades systemd fallidas.
- Errores recientes del journal.
- GPU y memoria.

**Salida:** `[ OK ]`, `[WARN]`, `[FAIL]` y resumen con código de salida.

**Ruta:** `tools/bin/miso-doctor` → `/usr/bin/miso-doctor`.

---

## 8. `miso-welcome`

**Responsabilidad:** dar la bienvenida en la sesión live y orientar al usuario.

- Muestra versión, base, estado de red y accesos rápidos.
- Ofrece `miso doctor`, `miso update check` y el instalador.
- Se lanza desde un `.desktop` de autostart en la sesión live.

**Ruta:** `tools/bin/miso-welcome` → `/usr/bin/miso-welcome`.

---

## 9. PJD Shell

**Responsabilidad:** identidad y experiencia de escritorio sobre Plasma.

Contenido:

```text
pjd-shell/
├── metadata.json
├── contents/
│   ├── defaults
│   ├── layouts/org.kde.plasma.desktop-layout.js
│   └── splash/
├── color-schemes/MiSO.colors
└── install.sh
```

**Instalación:** `/usr/share/plasma/look-and-feel/org.miso.pjd.desktop/`.

**Activación:** `/etc/skel/.config/kdeglobals` con
`LookAndFeelPackage=org.miso.pjd.desktop`.

**Estado:** esqueleto; requiere validación en Plasma 6.

---

## 10. Branding

| Activo | Origen | Destino |
|---|---|---|
| Logo | `branding/logo/miso-logo.svg` | `/usr/share/pixmaps/miso-logo.png` |
| Fondo | `branding/wallpapers/miso-default.svg` | `/usr/share/wallpapers/miso-default.png` |
| Tema GRUB | `branding/grub/` | `/boot/grub/themes/miso/` |
| Plymouth | `branding/plymouth/` | `/usr/share/plymouth/themes/miso/` |
| SDDM | `branding/sddm/10-miso.conf` | `/etc/sddm.conf.d/` |
| Calamares | `installer/calamares/branding/miso/` | `/etc/calamares/branding/miso/` |

Los PNG se generan en el build con `branding/render-assets.sh` (rsvg-convert o
ImageMagick).

---

## 11. Instalador

**Responsabilidad:** instalar el sistema en disco con configuración MiSO.

```text
installer/calamares/
├── settings.conf
├── branding/miso/branding.desc
├── modules/*.conf
└── scripts/miso-postinstall.sh
```

**Módulos propios:**

- `shellprocess@miso`: post-instalación.
- Branding y textos.
- Configuración de arranque y usuarios.

**Estado:** esqueleto funcional a validar en Fase 3.

---

## 12. Sistema de build

| Archivo | Función |
|---|---|
| `build/build-iso.sh` | Orquesta todas las etapas |
| `build/lib/common.sh` | Utilidades, logging, chroot, montajes |
| `build/config/build.conf` | Versión, espejos, locale, perfil |
| `build/packages/*.list` | Paquetes por perfil |
| `build/overlays/` | Configuración que se copia al rootfs |
| `build/install-host-deps.sh` | Dependencias del host |
| `build/clean.sh` | Limpieza de artefactos |

**Salida:** `out/miso-desktop-<versión>-<perfil>-amd64.iso` y `.sha256`.

---

## 13. Repositorios y anillos

`repos/rings.yaml` define:

```yaml
core:    { mandatory: true,  cadence: quarterly }
desktop: { mandatory: true,  cadence: monthly }
lab:     { mandatory: false, cadence: semiannual }
apps:    { mandatory: false, cadence: continuous }
```

En 1.0 se añaden URLs de repos, claves y reglas de pinning. En 0.1.0 es documentación
y estado local.

---

## 14. Dependencias entre componentes

```text
miso ──> misod ──> miso-updated ──> apt/btrfs
  │         └───> miso-rings ─────> apt/flatpak
  └───> miso-doctor

PJD Shell ──> Plasma 6
Instalador ──> Calamares + squashfs
Branding ──> PJD, GRUB, Plymouth, SDDM, Calamares
Build ──> todo lo anterior
```

Regla: ningún componente de usuario depende de PJD; PJD depende de Plasma. El
instalador no depende de `miso` en tiempo de ejecución.
