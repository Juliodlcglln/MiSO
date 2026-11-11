# Scripts de desarrollo

| Script | Uso |
|---|---|
| `run-qemu.ps1` | Arranca una ISO en QEMU desde Windows (BIOS/UEFI) |
| `run-qemu.sh` | Arranca una ISO en QEMU desde Linux/WSL |
| `serial-smoke.ps1` | Arranca sin ventana, entra por serial y ejecuta `miso doctor` |
| `make-usb.ps1` | Escribe una ISO en USB (destructivo, con confirmación) |

## Ejemplos

```powershell
# BIOS, perfil core
.\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-core-amd64.iso"

# UEFI, perfil desktop, con disco para instalar
.\scripts\run-qemu.ps1 `
  -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" `
  -Uefi -Memory 4G -Disk "$env:TEMP\miso-disk.qcow2"
```

```powershell
# Prueba automática por serial (sin ventana)
.\scripts\serial-smoke.ps1 -Iso "out\miso-desktop-0.1.0-core-amd64.iso"
```

```bash
# Linux
bash scripts/run-qemu.sh out/miso-desktop-0.1.0-core-amd64.iso --uefi
```

## Notas

- Si WHPX falla, usa `-Tcg` (Windows) o `--tcg` (Linux).
- Si la sesión gráfica falla, elige la entrada "gráficos seguros" o "consola" en GRUB.
- El log serial se guarda en `out/qemu-serial.log`.
- `make-usb.ps1` no adivina el disco: hay que pasar `-DiskNumber` y confirmar.
