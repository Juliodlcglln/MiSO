# Instalador de MiSO Desktop

Configuración de Calamares para MiSO Desktop.

## Estructura

```text
calamares/
├── settings.conf
├── branding/miso/branding.desc
├── modules/*.conf
└── scripts/miso-postinstall.sh
```

## Cómo se integra

1. El build copia este directorio a `/etc/calamares/` del rootfs.
2. `branding/render-assets.sh` genera `logo.png`, `icon.png` y `welcome.png` dentro de
   `/etc/calamares/branding/miso/`.
3. Calamares arranca desde la sesión live (`sudo calamares`).
4. `unpackfs` copia el squashfs al disco.
5. `shellprocess@miso` ejecuta la post-instalación dentro del sistema destino.
6. `bootloader` instala GRUB en BIOS o UEFI.

## Módulos propios

- **`shellprocess@miso`**: elimina el usuario live, habilita servicios, configura
  Flatpak y deja el estado inicial de MiSO.

## Validación pendiente

- [ ] `settings.conf` aceptado por Calamares 3.3.
- [ ] `unpackfs` encuentra `/run/live/medium/live/filesystem.squashfs`.
- [ ] `partition` crea btrfs y, si se elige, LUKS.
- [ ] `bootloader` instala GRUB en BIOS y UEFI.
- [ ] `miso-postinstall.sh` se ejecuta sin errores.
- [ ] El sistema instalado arranca sin la ISO.

## Notas

- En 0.1.0 el instalador crea una raíz btrfs simple, no los subvolúmenes A/B.
- La entrada de autologin `20-miso-live.conf` se elimina en la post-instalación.
- Si Calamares cambia la sintaxis de `instances`, ajusta `settings.conf` y documenta
  el cambio.
