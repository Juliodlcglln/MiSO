# Anillos y seguridad

---

## 1. Modelo de anillos

Un **anillo** es un canal de entrega con cadencia, riesgo y mecanismo de rollback
propios. La separación evita que una actualización de aplicaciones o de software
científico comprometa el arranque del sistema.

| Anillo | Contenido | Cadencia | Riesgo | Obligatorio | Entrega | Rollback |
|---|---|---|---|---|---|---|
| **Core** | Kernel, base Debian, systemd, drivers, seguridad | Trimestral | Bajo | Sí | apt + slot | Instantánea / slot A-B |
| **Desktop** | Plasma, PJD, SDDM, portales, fuentes | Mensual | Medio | Sí | apt | Instantánea |
| **Lab** | Toolchain, ciencia, ofimática, virtualización | Semestral | Medio | No | meta-paquetes | Instantánea |
| **Apps** | Flatpak de usuario | Continua | Aislado | No | Flathub / MiSO Apps | `flatpak` |

### 1.1 Reglas

1. **Core manda.** Ningún otro anillo puede reemplazar paquetes de Core sin pinning.
2. **Desktop no toca el kernel.** Las dependencias se resuelven dentro del anillo.
3. **Lab es opt-in.** Se habilita con `miso ring enable lab`.
4. **Apps no escribe en el sistema.** Flatpak instala en `~/.local/share/flatpak` o
   `/var/lib/flatpak`, nunca en `/usr`.
5. **Todo release se prueba desde el anillo anterior.** No se salta un canal.
6. **Todo cambio de Core requiere reinicio.** Desktop y Apps no.

### 1.2 Estados de un anillo

```text
deshabilitado → habilitado → actualizando → verificado
       ↑                            │
       └──────── fallo ←────────────┘
```

En 0.1.0 solo existen `core`, `desktop` y los estados de `lab`/`apps`; la máquina de
estados completa llega con el actualizador A/B.

---

## 2. Cadena de confianza

```text
Desarrollador
  → commit firmado (futuro)
    → build reproducible (futuro)
      → ISO + checksum SHA-256
        → repos firmados (Release.gpg / InRelease)
          → apt verifica firma
            → sistema instalado
              → actualizaciones firmadas
```

### 2.1 0.1.0

- La ISO se publica con `sha256sum`.
- apt verifica las firmas de Debian.
- Los paquetes MiSO se instalan desde el propio rootfs (aún no hay repo firmado).
- No hay Secure Boot firmado por MiSO.

### 2.2 1.0

- Repo MiSO firmado con clave dedicada.
- Secure Boot: shim + clave MiSO o MOK del laboratorio.
- dm-verity para el anillo Core.
- SBOM por release y compilación reproducible.
- Firmas de commits y tags.

---

## 3. Modelo de amenazas

### 3.1 Activos

- Integridad del sistema base y del arranque.
- Datos de usuarios y del laboratorio.
- Credenciales y claves.
- Disponibilidad para clases y exámenes.
- Reputación y cadena de suministro.

### 3.2 Amenazas y controles

| Amenaza | Vector | Control 0.1.0 | Control 1.0 |
|---|---|---|---|
| Malware en app de usuario | Flatpak/descarga | Sandbox Flatpak, portales | Permisos Flatpak revisados, antivirus opcional |
| Escalada de privilegios | App local | Sin root, polkit, AppArmor | `misod` D-Bus, perfiles más estrictos |
| Actualización maliciosa | Repo/HTTPS | Firmas apt, HTTPS | Repo MiSO firmado, dm-verity |
| Arranque manipulado | ESP/initramfs | Checksums, control físico | Secure Boot, UKI firmada |
| Robo de equipo | Disco | LUKS opcional | LUKS por defecto en laptops |
| USB infectado | Autorun | Sin ejecución automática | USBGuard, montaje `noexec` |
| Phishing/credenciales | Navegador | Navegador actualizado | 2FA institucional, políticas |
| Supply chain | Dependencias | Debian estable, versiones fijas | SBOM, reproducible builds |
| Denegación de servicio | Disco lleno | Alertas en `miso doctor` | Cuotas, health check |
| Error humano | `sudo` | Confirmaciones, logs | Broker con verbos acotados |

### 3.3 Supuestos

- El laboratorio controla el acceso físico a los equipos.
- La red del laboratorio no es confiable.
- Los usuarios no son administradores por defecto.
- El equipo de MiSO no es un objetivo de un atacante estatal.

---

## 4. Separación de privilegios

### 4.1 Diseño

```text
Usuario
  │  miso update apply
  ▼
CLI miso (sin privilegios)
  │  pkexec /usr/libexec/miso/misod update apply
  ▼
polkit  ── autentica según org.miso.desktop.admin
  │
  ▼
misod (root, efímero)
  │  valida verbo + argumentos
  ▼
miso-updated / apt / systemctl / btrfs
```

### 4.2 Reglas de `misod`

- Solo se ejecuta como root; si no, aborta.
- Acepta una lista cerrada de verbos.
- Valida nombres de paquete con `^[a-z0-9][a-z0-9+.-]+$`.
- Valida nombres de servicio con `^[A-Za-z0-9@_.-]+$`.
- No acepta rutas, redirecciones ni fragmentos de shell.
- Registra la operación y el resultado.
- No lee secretos ni variables de entorno del usuario.

### 4.3 Usuarios y grupos

- El usuario del instalador pertenece a `sudo`.
- No se habilita login de `root`.
- El usuario live se elimina en la post-instalación.
- Los grupos de hardware (`audio`, `video`, `render`, `plugdev`) se asignan según
  necesidad, no por defecto a todos.

### 4.4 Contraseñas

- Calamares exige una contraseña de usuario.
- `sudo` pide contraseña; no hay `NOPASSWD` en el sistema instalado.
- La sesión live usa usuario `live` con contraseña `live` (solo live).
- El bloqueo de pantalla se activa a los 5 minutos por defecto (Fase 2).

---

## 5. Sandboxing

| Tecnología | Uso | Límite |
|---|---|---|
| Flatpak | Apps de usuario | Depende de portales; permisos por app |
| AppArmor | Servicios y apps compatibles | No cubre todo el software |
| firejail | Apps legacy sin Flatpak | Configuración por app, no universal |
| systemd sandboxing | Servicios propios | Requiere unidades bien escritas |
| Contenedores | Desarrollo y laboratorio | No es aislamiento de escritorio |

Buenas prácticas:

- Discover muestra permisos de Flatpak; el usuario decide.
- Las apps de laboratorio que necesitan hardware se documentan con sus permisos.
- No se usa `--filesystem=host` salvo justificación.
- Los servicios MiSO usan `ProtectSystem=strict`, `NoNewPrivileges=yes` y
  `PrivateTmp=yes` cuando sea posible.

---

## 6. Integridad y recuperación

### 6.1 Instantáneas

- Antes de cada actualización de Core/Desktop.
- Retención: 3 diarias, 4 semanales, 3 mensuales (Fase 4).
- Verificación de espacio antes de crear la instantánea.
- Las instantáneas no se montan automáticamente.

### 6.2 Rollback

- 0.1.0: recuperación manual desde live o consola.
- 1.0: rollback automático si el health check falla.
- El rollback nunca borra `/home`.

### 6.3 Respaldos

- `/home` es responsabilidad del laboratorio (servidor de archivos o nube).
- MiSO no incluye un sistema de respaldo completo en 0.1.0.
- `miso doctor` recuerda configurar respaldo.

---

## 7. Endurecimiento (hardening)

### 7.1 Incluido en el diseño

- [x] Sin login root.
- [x] polkit + broker para operaciones administrativas.
- [x] Flatpak para apps de usuario.
- [x] AppArmor instalado y habilitado.
- [x] Firewall con perfil de laboratorio.
- [x] Actualizaciones firmadas por Debian.
- [x] Instantánea antes de actualizar.
- [x] Contraseña de usuario y bloqueo de pantalla.
- [x] SSH deshabilitado por defecto.

### 7.2 Pendiente para 1.0

- [ ] Secure Boot con claves MiSO.
- [ ] dm-verity para Core.
- [ ] Arranque medido (TPM 2.0).
- [ ] USBGuard.
- [ ] auditd con reglas mínimas.
- [ ] SBOM y compilación reproducible.
- [ ] Revisión de permisos Flatpak por aplicación.
- [ ] Política de contraseñas y caducidad.
- [ ] Cifrado LUKS por defecto en equipos móviles.

---

## 8. Respuesta a incidentes

1. **Aislar:** desconectar red si hay compromiso activo.
2. **Preservar:** no borrar logs; exportar `journalctl`, `/var/log/miso/`.
3. **Evaluar:** `miso doctor`, estado de anillos, integridad de paquetes.
4. **Recuperar:** arrancar slot/instantánea anterior; reinstalar si es necesario.
5. **Notificar:** seguir el canal de seguridad del laboratorio.
6. **Aprender:** actualizar el modelo de amenazas y los controles.

Canal de reporte de seguridad: `seguridad@miso.local` (placeholder hasta definir el
dominio real).

---

## 9. Limitaciones conocidas de 0.1.0

- Sin Secure Boot firmado por MiSO.
- Sin dm-verity ni arranque medido.
- Sin repo MiSO firmado.
- Sin rollback automático.
- AppArmor no cubre todas las aplicaciones.
- Flatpak depende de portales y de la calidad de los permisos de cada app.
- La sesión live tiene contraseña conocida; no debe usarse en producción.
