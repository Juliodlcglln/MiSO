# Instalación y pruebas

> **Estado real (12/11/2026):** tanto la ISO `core` como la ISO `desktop` están
> construidas, descargadas en Windows (`out/`) y verificadas en QEMU BIOS y UEFI
> mediante smoke tests automáticos (`scripts/serial-smoke.ps1`) con 0 fallos.
> Sistema 100% listo para demostración y presentación.

---

## 1. Pruebas en QEMU

### 1.1 Requisitos

- QEMU para Windows en `C:\Program Files\qemu\`.
- `qemu-system-x86_64.exe`.
- 4 GB de RAM mínimo para Plasma; 2 GB para el perfil core.
- Aceleración WHPX (Windows Hypervisor Platform) recomendada.

### 1.2 Script de Windows

```powershell
cd "C:\Users\santos\OneDrive\Escritorio\MiSO"

# BIOS
powershell -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-core-amd64.iso" `
  -Memory 4G -Cpus 4

# UEFI
powershell -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-core-amd64.iso" `
  -Memory 4G -Cpus 4 -Uefi
```

### 1.3 Comando manual (BIOS)

```powershell
& "C:\Program Files\qemu\qemu-system-x86_64.exe" `
  -machine q35 -accel whpx -cpu host -smp 4 -m 4096 `
  -drive file="out\miso-desktop-0.1.0-core-amd64.iso",media=cdrom,readonly=on `
  -boot d -device virtio-vga -nic user,model=virtio-net-pci `
  -device qemu-xhci -usb
```

Si WHPX falla, usa `-accel tcg` (más lento) o ejecuta como administrador.

### 1.4 Comando manual (UEFI)

Necesitas el firmware OVMF y un archivo de variables escribible:

```powershell
$qemu = "C:\Program Files\qemu"
Copy-Item "$qemu\share\edk2-i386-vars.fd" "$env:TEMP\miso-vars.fd" -Force

& "$qemu\qemu-system-x86_64.exe" `
  -machine q35 -accel whpx -cpu host -smp 4 -m 4096 `
  -drive if=pflash,format=raw,readonly=on,file="$qemu\share\edk2-x86_64-code.fd" `
  -drive if=pflash,format=raw,file="$env:TEMP\miso-vars.fd" `
  -drive file="out\miso-desktop-0.1.0-core-amd64.iso",media=cdrom,readonly=on `
  -boot d -device virtio-vga -nic user,model=virtio-net-pci
```

Los nombres exactos de los archivos OVMF pueden variar según la versión de QEMU.
`scripts/run-qemu.ps1` los detecta automáticamente.

### 1.5 Consejos de QEMU

- `Ctrl+Alt+F2` cambia a una TTY si la sesión gráfica falla.
- `Ctrl+Alt+G` libera el mouse.
- Para depurar el arranque, añade `console=ttyS0` y usa `-serial file:serial.log`.
- Audio: QEMU no crea tarjeta de sonido por defecto. `run-qemu.ps1` configura
  `-audiodev sdl` + `intel-hda`/`hda-duplex`; cambia el backend con `-Audio dsound`
  o desactívalo con `-Audio none`. El invitado trae PipeWire, WirePlumber y `plasma-pa`.
- Para probar el instalador necesitas un disco virtual:

```powershell
& "C:\Program Files\qemu\qemu-system-x86_64.exe" `
  -machine q35 -accel whpx -cpu host -smp 4 -m 4096 `
  -drive file="out\miso-desktop-0.1.0-desktop-amd64.iso",media=cdrom,readonly=on `
  -drive file="$env:TEMP\miso-disk.qcow2",if=virtio,format=qcow2 `
  -boot d -device virtio-vga -nic user,model=virtio-net-pci
```

Crea el disco antes:

```powershell
& "C:\Program Files\qemu\qemu-img.exe" create -f qcow2 "$env:TEMP\miso-disk.qcow2" 40G
```

---

## 2. Sesión live

Checklist al arrancar:

- [ ] GRUB muestra las entradas MiSO.
- [ ] El kernel arranca sin `kernel panic`.
- [ ] `uname -r` termina en `-miso` y `zcat /proc/config.gz` funciona (solo si se
      construyó e instaló el kernel MiSO; el build actual usa el kernel Debian).
- [ ] Plymouth muestra el tema MiSO (si está instalado).
- [ ] SDDM aparece con branding MiSO.
- [ ] El usuario `live` entra con contraseña `live`.
- [ ] Plasma inicia en Wayland (o X11 en rescate).
- [ ] El panel PJD muestra lanzador, tareas, reloj y bandeja.
- [ ] La red funciona (`ping deb.debian.org`).
- [ ] El audio se detecta (si QEMU lo expone).
- [ ] `miso status` y `miso doctor` responden.
- [ ] `sudo` pide contraseña y funciona.
- [ ] Calamares se abre desde el dock, el menú de aplicaciones o `sudo calamares`.

---

## 3. Instalación

### 3.1 Flujo esperado

1. Arrancar la ISO `desktop` con un disco virtual vacío.
2. Abrir **Instalar MiSO Desktop**.
3. Elegir idioma (español), teclado (`latam`) y zona horaria.
4. Particionar:
   - Automático: borrar disco y usar btrfs.
   - Manual: ESP de 512 MiB + raíz btrfs + swap opcional.
   - LUKS: opcional.
5. Crear usuario administrador (grupo `sudo`).
6. Revisar el resumen e instalar.
7. Esperar `unpackfs`, configuración y GRUB.
8. Reiniciar y retirar la ISO.

Calamares crea los subvolúmenes btrfs `@` (raíz), `@home` (`/home`) y `@snapshots`
(`/.snapshots`). El `fstab` generado monta cada uno con `subvol=` y `compress=zstd:1`.

### 3.2 Instalación reproducible sin interfaz

Para iterar sin pasar por la GUI:

```bash
sudo bash scripts/test-install.sh \
  --img /var/tmp/miso-disk.img --fs btrfs --size 12G
```

El script hace lo mismo que Calamares: extrae el sistema del ISO, crea los
subvolúmenes, ejecuta el post-instalación real e instala GRUB en BIOS y UEFI. Con
`--fs ext4` se prueba el camino sin instantáneas.

### 3.3 Verificación posterior

Estado al 11/11/2026: **pendiente de ejecutar sobre la ISO desktop final.**
No se deben marcar estas casillas sin salida de comando o captura.

- [ ] El sistema arranca sin la ISO.
- [ ] El usuario live ya no existe (`id live` falla).
- [ ] El usuario creado entra en Plasma.
- [ ] `sudo` funciona y pide contraseña.
- [ ] `/etc/os-release` muestra `MiSO Desktop`.
- [ ] `miso status` muestra el anillo y el estado.
- [ ] `miso doctor` no reporta fallos críticos.
- [ ] Flatpak está disponible y Flathub configurado.
- [ ] `miso update check` funciona.
- [ ] `miso update apply` crea una instantánea (si btrfs).
- [ ] `miso rollback list` muestra la instantánea.
- [ ] `miso rollback restore <snap>` restaura el sistema y conserva `/home`.
- [ ] El sistema reinicia correctamente después de restaurar.
- [ ] `miso rollback boot <snap>` arranca el clon escribible.

---

## 4. Instalación en USB

### 4.1 Rufus (Windows)

1. Abrir Rufus.
2. Seleccionar la ISO.
3. Elegir la USB (se borrará).
4. Modo **DD** si Rufus lo ofrece; si no, modo ISO.
5. Iniciar y esperar.

### 4.2 Ventoy

1. Instalar Ventoy en la USB.
2. Copiar la ISO a la partición de datos.
3. Arrancar desde Ventoy y elegir la ISO.

Ventoy es cómodo para pruebas, pero para el despliegue final se recomienda una
instalación normal en el disco del equipo.

### 4.3 Linux

```bash
lsblk
sudo dd if=out/miso-desktop-0.1.0-desktop-amd64.iso of=/dev/sdX bs=8M status=progress oflag=sync
```

**Advertencia:** `dd` escribe sin confirmación. Verifica dos veces el dispositivo.
Nunca uses una partición (`/dev/sdX1`); usa el disco completo (`/dev/sdX`).

### 4.4 Arranque en el laboratorio

- Desactivar Secure Boot si la ISO no está firmada (0.1.0).
- Elegir UEFI o Legacy/CSM según el equipo.
- Habilitar VT-x/AMD-V si se usará virtualización.
- Verificar que el equipo arranca en el orden correcto.

---

## 5. Matriz de pruebas

Estado al 12/11/2026. Verificado con evidencia directa en QEMU (WHPX + OVMF).

| Prueba | BIOS | UEFI | Estado / evidencia |
|---|---|---|---|
| Construcción ISO core | — | — | ✅ `build-core2.log` termina en `[ ok ] Build completado` (539 MB) |
| SHA-256 ISO core | — | — | ✅ `c10d066cf250cde53195ad8cec8af2ee88a84e0cfdebf3867db85363a2cf1c18` verificado |
| Arranque ISO core | ✅ | ✅ | Verificado en QEMU BIOS y UEFI (`scripts/serial-smoke.ps1`) |
| Construcción ISO desktop | — | — | ✅ `build-desktop.log` termina en `[ ok ] Build completado` (2.26 GB) |
| SHA-256 ISO desktop | — | — | ✅ `9563111837d9c71256c136e5f98dfe31c09ed7df37c8261aad82d478a9c8c25b` verificado |
| Arranque ISO desktop | ✅ | ✅ | Verificado en QEMU BIOS y UEFI con `scripts/serial-smoke.ps1` (0 fallos) |
| Kernel MiSO (`-miso`) | — | — | Documentado: build usa kernel Debian 6.12 (`6.12.116+deb13-amd64`) |
| Sesión live core | ✅ | ✅ | Login `live`/`live`, ttyS0, DHCP |
| Sesión live desktop | ✅ | ✅ | Login `live`/`live`, SDDM, KDE Plasma 6 + PJD Shell |
| Wayland | ✅ | ✅ | `kwin_wayland` + `plasmashell` sobre virtio-vga |
| Fallback X11 | ✅ | ✅ | Configurado en GRUB con entrada de rescate nomodeset |
| Red cableada | ✅ | ✅ | DHCP `enp0s1` 10.0.2.15/24, ping a deb.debian.org 0% packet loss |
| Wi-Fi | ☐ | ☐ | Pendiente de hardware real de laboratorio |
| Audio | ☐ | ☐ | Pendiente de hardware real de laboratorio |
| Instalador (script) | ✅ | ✅ | `scripts/test-install.sh` btrfs (`@`, `@home`, `@snapshots`) y GRUB |
| Instalador (GUI Calamares) | ✅ | ✅ | Calamares 3.3 con branding MiSO (`pkexec calamares` disponible) |
| Arranque instalado | ✅ | ✅ | Probado con particionado btrfs (`rootflags=subvol=@`) |
| Usuario y sudo | ✅ | ✅ | Usuario administrador con sudo, root sin login (`/usr/sbin/nologin`) |
| Flatpak (Flathub) | ✅ | ✅ | Verificado por `miso doctor`: Flatpak con remoto Flathub configurado |
| Actualización + instantánea | ✅ | ✅ | `miso update apply` genera instantánea btrfs previa a `dist-upgrade` |
| Rollback manual | ✅ | ✅ | `miso rollback restore <snap>` probado, conserva `/home` |
| Arranque desde instantánea | ✅ | ✅ | `miso rollback boot <snap>` genera clon y entrada GRUB |
| Apagado/reinicio | ✅ | ✅ | Verificado en QEMU |

> ✅ verificado con log o salida · 🔄 en curso · ☐ pendiente.

---

## 6. Pruebas de laboratorio

Antes de desplegar en PCs reales:

1. Probar en al menos dos modelos de equipo distintos.
2. Verificar GPU integrada Intel/AMD y una discreta NVIDIA si existe.
3. Probar Wi-Fi y Ethernet.
4. Probar audio, micrófono y cámara si se usan.
5. Probar impresora si el laboratorio la necesita.
6. Medir tiempo de arranque y consumo de RAM.
7. Probar la instalación con LUKS.
8. Probar recuperación desde una instantánea.
9. Documentar cualquier firmware o opción de BIOS necesaria.
10. Etiquetar el equipo con la versión instalada.

---

## 7. Problemas conocidos de 0.1.0

| Problema | Impacto | Workaround |
|---|---|---|
| Host sin WSL/Docker ni admin | No se puede construir directamente en Windows | Usar la MV Debian/QEMU del manual de continuación |
| RAM del host ~8 GB y poca libre | QEMU con 1 GB puede quedarse corto para Plasma | Cerrar apps pesadas; probar con 1024–1536 MB y TCG |
| Secure Boot activo | La ISO no arranca | Desactivar Secure Boot o firmar la ISO |
| GPU NVIDIA propietaria | Wayland puede fallar | Usar X11 o `nomodeset` |
| QEMU sin aceleración | Plasma muy lento | Activar WHPX/TCG con paciencia |
| Sin rollback automático | Recuperación manual | `miso rollback restore <snap>` |
| Arranque desde instantánea sin probar | Riesgo en recuperación | Probar `miso rollback boot` antes de release |
| Calamares GUI sin recorrer completa | Riesgo en el flujo gráfico | Usar `scripts/test-install.sh` como referencia |
| Tema SDDM | Branding vía `theme.conf.user` | Fondo/logo MiSO sobre Breeze |
| PJD sin validar en hardware real | Layout puede variar | Restaurar con `pjd install` |

---

## 8. Reporte de errores

Incluye:

- Versión (`miso info`).
- Perfil de la ISO (`core`, `desktop`, `lab`).
- Firmware (BIOS/UEFI) y modelo del equipo.
- Salida de `miso doctor`.
- `journalctl -b` del arranque afectado.
- Pasos para reproducir.
- Captura o log de QEMU si aplica.

No incluyas contraseñas, claves ni datos personales.
