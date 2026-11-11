# Pruebas de humo

Checklist mínimo antes de dar por buena una ISO.

## 1. Build

- [ ] `sudo bash build/build-iso.sh --profile core` termina sin errores.
- [ ] Se genera `out/miso-desktop-0.1.0-core-amd64.iso` y su `.sha256`.
- [ ] `sha256sum -c` pasa.

## 2. Arranque BIOS

```powershell
.\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-core-amd64.iso"
```

- [ ] GRUB muestra las entradas MiSO.
- [ ] El kernel arranca sin `Kernel panic`.
- [ ] Se llega a login o consola.
- [ ] `miso status` funciona.
- [ ] `miso doctor` funciona.
- [ ] La red responde (`ping -c 2 deb.debian.org`).

## 3. Arranque UEFI

```powershell
.\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-core-amd64.iso" -Uefi
```

- [ ] El firmware reconoce la ISO.
- [ ] GRUB arranca.
- [ ] Se llega a login o consola.

## 4. Escritorio

```powershell
.\scripts\run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" `
  -Memory 4G
```

- [ ] SDDM aparece.
- [ ] El usuario `live` entra con contraseña `live`.
- [ ] Plasma inicia.
- [ ] El panel PJD aparece.
- [ ] `miso-welcome` se muestra.
- [ ] `sudo calamares` abre el instalador.

## 5. Instalación

Con un disco virtual:

```powershell
.\scripts\run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" `
  -Memory 4G -Disk "$env:TEMP\miso-disk.qcow2"
```

- [ ] Calamares completa.
- [ ] El sistema instalado arranca sin la ISO.
- [ ] El usuario live no existe.
- [ ] El usuario creado entra en Plasma.
- [ ] `sudo` pide contraseña.
- [ ] `miso status` y `miso doctor` funcionan.
- [ ] `miso update check` funciona.

## 6. Actualización

- [ ] `miso update apply` crea una instantánea (btrfs).
- [ ] La actualización termina o falla de forma controlada.
- [ ] `miso rollback list` muestra la instantánea.
- [ ] El sistema sigue arrancando.

## 7. Logs

- [ ] `journalctl -b -p 3` no muestra errores críticos.
- [ ] `out/qemu-serial.log` no contiene `Kernel panic`.
- [ ] `/var/log/miso/updates.log` existe tras actualizar.
- [ ] `/var/log/miso/misod.log` registra la operación.

## 8. Criterio de salida

Una ISO es aceptable para la fase actual si:

1. Arranca en BIOS y UEFI.
2. Llega al escritorio (perfil desktop) o consola (core).
3. El instalador funciona en un disco virtual.
4. No hay fallos bloqueantes en `miso doctor`.
5. Los logs no muestran pánicos ni bucles de arranque.
