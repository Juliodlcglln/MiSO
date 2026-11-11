# Repositorios y anillos

Este directorio define el modelo de entrega de MiSO Desktop.

## Archivos

- `rings.yaml`: definición de Core, Desktop, Lab y Apps. El build lo copia a
  `/etc/miso/rings.yaml`.

## Estado 0.1.0

- Los anillos son lógicos: listas de paquetes y estado local.
- No hay repositorio MiSO firmado todavía.
- `miso ring enable lab` instala la lista Lab desde `/usr/share/miso/rings/lab.list`.
- `miso ring enable apps` configura Flathub.

## Estado 1.0

- Repo MiSO firmado con clave propia.
- Pinning por anillo.
- Snapshots de Debian con fecha fija.
- Remoto MiSO Apps curado.
- Canales `stable`, `beta`, `dev`.

## Reglas

1. Core y Desktop son obligatorios.
2. Lab y Apps son opt-in.
3. Un fallo en Apps no debe afectar el arranque.
4. Las actualizaciones de Core pueden requerir reinicio.
5. Todo cambio de repositorio se firma y se documenta.
