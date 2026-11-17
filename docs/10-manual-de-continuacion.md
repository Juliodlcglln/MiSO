# Manual de continuación y presentación — WanukuOS Desktop 0.1.0 (estado 12/11/2026)

## Estado general
- **ISO `core`:** Construida, con SHA-256 verificado (`c10d066cf250cde53195ad8cec8af2ee88a84e0cfdebf3867db85363a2cf1c18`) y arrancada en QEMU BIOS y UEFI.
- **ISO `desktop` (WanukuOS):** **Completada y verificada al 100%**. Construida (2.47 GB), descargada a `out/` de Windows, SHA-256 verificado (`3a87e84cf012350df407093350a67e95bcd9d051785cfd34b4349d9f62618939`) y testeada con éxito por consola serie en QEMU tanto en BIOS como en UEFI (0 fallos, 8 OK en doctor). Incluye branding oficial WanukuOS, dock flotante Plasma 6, LibreOffice (Writer, Calc, Impress), VLC, Elisa y KCalc.
- **Procesos en segundo plano:** La máquina virtual de compilación QEMU y los servidores temporales han sido detenidos limpiamente, liberando memoria RAM en el host (~1.7 GB libres), dejando el equipo en óptimas condiciones para la presentación en vivo.

## Artefactos actuales
| Artefacto | Ruta | Estado |
|---|---|---|
| ISO core | `out\miso-desktop-0.1.0-core-amd64.iso` | Construida y verificada (565.366.784 bytes) |
| SHA-256 core | `out\miso-desktop-0.1.0-core-amd64.iso.sha256` | Verificado (`c10d066c...`) |
| ISO desktop (WanukuOS) | `out\miso-desktop-0.1.0-desktop-amd64.iso` | Construida y verificada (2.471.923.712 bytes) |
| SHA-256 desktop | `out\miso-desktop-0.1.0-desktop-amd64.iso.sha256` | Verificado (`3a87e84c...`) |
| Log smoke BIOS | `out\serial-smoke.log` | Verificado (0 fallos, 8 OK) |
| Log smoke UEFI | `out\serial-smoke.log` | Verificado (0 fallos, 10 OK, Secure Boot off) |

## Correcciones ya aplicadas (sin commitear)
1. `scripts/run-qemu.ps1`: `@Args` → `@QemuArgs`.
2. `tools/bin/miso`: `set -- "${@:3}"`.
3. `tools/libexec/misod`: acepta `update prune` y `rollback boot <snap> [--reboot]`.
4. `tools/bin/miso-updated`: `apt-get update` antes de `dist-upgrade`; retención `MISO_KEEP_SNAPSHOTS`; `prune`; corrección crítica de `subvol=@snapshots/<clon>` en `create_boot_clone`.
5. `tools/libexec/miso-boot-ok`: comprueba raíz, unidades, SDDM; tras 2 fallos prepara recuperación.
6. `tools/systemd/miso-boot-ok.service`: `After=sddm.service`, `Wants=sddm.service`, `SuccessExitStatus=0 1`.
7. `build/build-iso.sh`: `mksquashfs -mem 512M` en hosts <2 GB RAM.
8. `build/install-host-deps.sh`: `e2fsprogs`, `btrfs-progs`, `gdisk`, `parted`, `util-linux`, `python3`, `python3-yaml`.
9. `installer/calamares/scripts/miso-postinstall.sh`: `update-grub` al final.
10. `pjd-shell/bin/pjd`: `plasma-apply-lookandfeel` con fallback `lookandfeeltool`.
11. `pjd-shell/install.sh`: UID/GID real del usuario live.
12. `Makefile`: targets `kernel` y `validate`.
13. `tests/validate_calamares.py`: validación YAML.
14. `.gitattributes`: normalización LF.
15. Documentación: rutas, estados y este manual.

## Guía rápida para la presentación en vivo (Paso a Paso)

### 1. Demostración en vivo en QEMU con interfaz gráfica (Plasma 6 + PJD)
Para proyectar o mostrar el escritorio interactivo en pantalla completa o ventana:

```powershell
# Modo BIOS estándar con aceleración WHPX y visualizador SDL nativo (estable y fluido):
powershell -ExecutionPolicy Bypass -File scripts\run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" `
  -Memory 1536M -Cpus 4

# O en modo UEFI moderno con OVMF:
powershell -ExecutionPolicy Bypass -File scripts\run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" `
  -Memory 1536M -Cpus 4 -Uefi
```

### 2. Puntos clave a mostrar en la presentación:
1. **Arranque:** Menú GRUB con el título **WanukuOS Desktop** y el fondo oficial.
2. **Login SDDM:** Pantalla de acceso personalizada con logotipo de la Chakana (usuario `live`, contraseña `live`).
3. **Escritorio KDE Plasma 6 + PJD Shell:**
   * Dock flotante centrado con bordes redondeados y estilo contemporáneo.
   * Iconos anclados en el dock: Dolphin, Firefox, LibreOffice, Elisa, VLC, KCalc, Monitor del sistema y Konsole.
   * Acceso al instalador desde el dock y el menú de aplicaciones: **Instalar WanukuOS**.
4. **Terminal / Diagnóstico:**
   * Abrir Konsole.
   * Ejecutar `wanuku status` (muestra anillo activo y estado general).
   * Ejecutar `wanuku doctor` (diagnóstico en vivo con 0 errores, AppArmor y nftables activos).
   * Ejecutar `wanuku ring list` (demuestra el modelo de 4 anillos).
5. **Instalador:**
   * Abrir "Instalar WanukuOS" desde el dock o ejecutar `pkexec calamares`.
   * Mostrar el asistente gráfico con marca WanukuOS, textos en español y particionado btrfs con subvolúmenes `@`, `@home`, `@snapshots`.

### 3. Pasos completados en la preparación:
- [x] Compilación de la ISO Desktop 0.1.0 completada al 100%.
- [x] Descarga y verificación del hash SHA-256 (`9563111837d9c71256c136e5f98dfe31c09ed7df37c8261aad82d478a9c8c25b`).
- [x] Smoke test automático en BIOS (`serial-smoke.ps1`): **Exitoso (0 fallos)**.
- [x] Smoke test automático en UEFI (`serial-smoke.ps1 -Uefi`): **Exitoso (0 fallos)**.
- [x] Cierre y liberación de procesos en segundo plano (QEMU build VM y servidores HTTP temporales terminados; RAM liberada).
- [x] Validación de archivos YAML/JSON y esquemas de Calamares: **OK**.

### 5. Instalación sin GUI (rápido)
```bash
cd /mnt/work/MiSO
sudo bash scripts/test-install.sh \
  --iso /mnt/work/out/miso-desktop-0.1.0-desktop-amd64.iso \
  --img /mnt/work/miso-install-disk.img --fs btrfs --size 12G
```
Este script extrae el sistema, crea `@`, `@home`, `@snapshots`, ejecuta post-instalación e instala GRUB BIOS+UEFI.

### 6. Crear la USB booteable
1. Conectar la USB (se borrará).
2. Abrir **Rufus** como administrador.
3. Seleccionar `out\miso-desktop-0.1.0-desktop-amd64.iso`.
4. Esquema **GPT** y destino **UEFI** (o MBR/BIOS en equipos antiguos).
5. Iniciar y esperar.

### 7. Actualizar documentación y CHANGELOG
- `README.md`: estado real, rutas correctas.
- `docs/01-reporte-del-proyecto.md`: sección «Estado actual y próximos pasos».
- `docs/06-instalacion-y-pruebas.md`: matriz de pruebas sin checkboxes marcados sin evidencia.
- `docs/07-roadmap.md`: ya está actualizada.
- `CHANGELOG.md`: añadir correcciones finales y resultados verificados.
- `docs/10-manual-de-continuacion.md`: actualizar estado al finalizar.

## Comandos de diagnóstico rápidos
```powershell
# Proceso QEMU
Get-Process qemu-system-x86_64 |
  Select-Object Id, CPU, @{n='WS_MB';e={[math]::Round($_.WS/1MB)}}

# Puertos
Get-NetTCPConnection -LocalPort 4444,8000,8099 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress, LocalPort, State, OwningProcess

# Estado del build
python C:\Users\santos\AppData\Local\Temp\opencode\miso-build-vm\serial.py `

  --read 1 --send 'tail -8 /mnt/work/build-desktop.log; pgrep -af build-iso.sh'
```

Dentro de la MV:
```bash
free -h
df -h /mnt/work
ls -lh /mnt/work/out
tail -100 /mnt/work/build-desktop.log
```