# Paquetes propios de MiSO

En 0.1.0 los componentes de MiSO se instalan mediante **overlays** y herramientas
copiadas por `build/build-iso.sh`. Esta carpeta queda reservada para el empaquetado
`.deb` de la Fase 2/5.

## Paquetes previstos

| Paquete | Contenido |
|---|---|
| `miso-base-files` | `/etc/os-release`, `/etc/miso/*`, sysctl, skel |
| `miso-tools` | `miso`, `miso-updated`, `miso-rings`, `miso-doctor`, `miso-welcome` |
| `misod` | Broker de privilegios, política polkit y unidades systemd |
| `miso-branding` | Logo, fondos, GRUB, Plymouth, SDDM |
| `pjd-shell` | Look-and-feel, layout, colores y CLI `pjd` |
| `miso-installer` | Configuración de Calamares y script de post-instalación |
| `miso-rings` | Metapaquetes y listas de los anillos Lab/Apps |

## Convenciones

- Formato Debian (`debian/control`, `debian/rules`, `debian/changelog`).
- `debhelper-compat = 13`.
- Licencia `GPL-3.0-or-later` y encabezados SPDX.
- Sin binarios generados en el repositorio.
- Cada paquete debe poder construirse con `dpkg-buildpackage -us -uc -b`.

## Motivo del enfoque actual

El overlay permite iterar rápido en la ISO sin mantener seis paquetes desde el primer
día. Cuando el pipeline sea estable, se migra a paquetes firmados y se elimina la
copia manual desde `build/`.

## Próximos pasos

1. Crear `miso-base-files` con `debhelper`.
2. Mover las herramientas de `tools/` a `miso-tools`.
3. Crear `misod` con política polkit.
4. Publicar un repo local y probar `apt install miso-tools`.
