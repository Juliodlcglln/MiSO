# Pruebas

- `smoke.md`: checklist manual de build, arranque, escritorio, instalación y
  actualización.
- `check-serial.ps1`: revisa `out/qemu-serial.log` en busca de pánicos y confirma
  que el arranque llegó a multi-user o graphical.
- `scripts/serial-smoke.ps1`: prueba automática de extremo a extremo; arranca la ISO
  sin ventana, entra como `live`, comprueba red, anillos y ejecuta `miso doctor`.

## Uso

```powershell
.\tests\check-serial.ps1 -Log "out\qemu-serial.log"
```

Códigos de salida:

- `0`: log limpio y arranque detectado.
- `1`: se encontró un patrón de fallo.
- `2`: no se pudo confirmar el arranque completo.

Las pruebas de hardware real están en `docs/06-instalacion-y-pruebas.md`.
