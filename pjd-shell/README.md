# PJD Shell

Capa de escritorio de MiSO Desktop sobre **KDE Plasma 6**. No es un compositor ni un
fork de Plasma: es un paquete de look-and-feel, un layout de panel, un esquema de color
y una CLI de soporte.

## Contenido

```text
pjd-shell/
├── metadata.json
├── contents/
│   ├── defaults
│   └── layouts/org.kde.plasma.desktop-layout.js
├── color-schemes/MiSO.colors
├── skel/kdeglobals
├── bin/pjd
└── install.sh
```

## Instalación

El build de la ISO ejecuta:

```bash
bash pjd-shell/install.sh /var/tmp/miso-build/rootfs
```

Destino:

```text
/usr/share/plasma/look-and-feel/org.miso.pjd.desktop/
/usr/share/color-schemes/MiSO.colors
/etc/skel/.config/kdeglobals
/usr/bin/pjd
```

## Activación

Para usuarios nuevos, `/etc/skel/.config/kdeglobals` contiene:

```ini
[KDE]
LookAndFeelPackage=org.miso.pjd.desktop
```

Para el usuario actual:

```bash
pjd apply
```

## Estado

Esqueleto para 0.1.0. Pendiente:

- [ ] Validar el layout JS en Plasma 6.3.
- [ ] Añadir splash de Plasma.
- [ ] Añadir previsualización (`previews/`).
- [ ] Tema SDDM propio (hoy se usa Breeze + fondo MiSO).
- [ ] Perfiles de layout (laboratorio, kiosco, presentación).
