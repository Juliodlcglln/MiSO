# Licencias y gobernanza

---

## 1. Licencias del proyecto

| Componente | Licencia | Titular |
|---|---|---|
| Código propio de MiSO Desktop | GPL-3.0-or-later | Equipo MiSO |
| Documentación | CC BY-SA 4.0 | Equipo MiSO |
| Logo, fondos y arte | CC BY-SA 4.0 | Equipo MiSO |
| Kernel Linux | GPL-2.0-only | Comunidad Linux |
| Debian | Diversas licencias libres | Debian Project |
| KDE Plasma | LGPL-2.1+ / GPL-2.0+ | KDE e.V. |
| Calamares | GPL-3.0-or-later | Calamares |
| Flatpak | LGPL-2.1+ | Flatpak |
| Aplicaciones Flatpak | Licencia de cada app | Cada proyecto |

### 1.1 Regla de compatibilidad

- El código MiSO que se enlace con GPL-2.0-only debe ser compatible.
- Preferimos **GPL-3.0-or-later** para código propio.
- No se introduce código propietario en el sistema base.
- Las apps Flatpak conservan su licencia; MiSO no las relicencia.

---

## 2. Cumplimiento GPL

Obligaciones:

1. **Código fuente:** publicar el código propio y las modificaciones a componentes GPL.
2. **Avisos:** conservar copyright y licencias originales.
3. **Oferta de fuente:** incluir la URL del repositorio y, si aplica, una oferta escrita.
4. **Scripts de build:** publicar los scripts necesarios para reconstruir la ISO.
5. **Sin restricciones adicionales:** no imponer términos que limiten los derechos GPL.

Buenas prácticas:

- Cada archivo propio lleva un encabezado SPDX:
  ```text
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (C) 2026 Equipo MiSO
  ```
- El repositorio incluye `LICENSE` con el texto completo de GPL-3.0.
- Los releases incluyen `SOURCE.txt` con instrucciones de reconstrucción.
- Se conservan los avisos de Debian, KDE y Calamares.

---

## 3. Marcas y nombres

- **MiSO** y **MiSO Desktop** son marcas del proyecto.
- **PJD** es el nombre de la capa de escritorio MiSO.
- **Debian** es una marca registrada de Software in the Public Interest.
- **KDE** y **Plasma** son marcas de KDE e.V.
- **Calamares**, **Flatpak** y **Flathub** pertenecen a sus respectivos proyectos.

Reglas:

- No se presenta MiSO como una distribución oficial de Debian o KDE.
- Se usa la fórmula «basado en Debian» o «construido sobre Debian».
- No se usa el logo de Debian/KDE como logo principal de MiSO.
- Los créditos a upstream son visibles en el README y en el instalador.

---

## 4. Contribución

### 4.1 Flujo

1. Abrir un issue con contexto y propuesta.
2. Crear una rama `feat/...`, `fix/...` o `docs/...`.
3. Hacer commits pequeños y descriptivos.
4. Ejecutar `shellcheck` y las pruebas aplicables.
5. Abrir un pull request con:
   - Qué cambia.
   - Por qué.
   - Cómo se probó.
   - Impacto en seguridad/actualizaciones.

### 4.2 Commits

Formato sugerido:

```text
tipo(alcance): descripción breve

Cuerpo opcional.

Refs: #123
```

Tipos: `feat`, `fix`, `docs`, `build`, `test`, `refactor`, `chore`, `security`.

### 4.3 Revisión

- Al menos una revisión para cambios de código.
- Dos revisiones para cambios de seguridad, arranque o actualizaciones.
- No se mezclan cambios de comportamiento y refactors grandes.

### 4.4 DCO

Los commits deben incluir `Signed-off-by:` para certificar que se tiene derecho a
contribuir bajo la licencia del proyecto.

---

## 5. Versionado y releases

### 5.1 SemVer

- **MAJOR:** cambios incompatibles en CLI, formato de actualización o instalación.
- **MINOR:** nuevas funciones compatibles.
- **PATCH:** correcciones y seguridad.

### 5.2 Canales

| Canal | Uso | Audiencia |
|---|---|---|
| `dev` | Builds diarios | Equipo |
| `beta` | Pruebas de fase | Laboratorio piloto |
| `stable` | Release | Laboratorio |

### 5.3 Proceso de release

1. Congelar cambios.
2. Construir ISO `core`, `desktop` y `lab`.
3. Probar matriz BIOS/UEFI e instalación.
4. Actualizar `CHANGELOG.md` y versión.
5. Firmar la ISO y publicar checksums.
6. Publicar notas y guía de actualización.
7. Etiquetar el commit (`v0.1.0`).

---

## 6. Seguridad

- Reportes privados a `seguridad@miso.local` (placeholder).
- Respuesta objetivo: acuse en 48 h, evaluación en 7 días.
- Divulgación coordinada tras publicar el parche.
- No se aceptan backdoors, telemetría oculta ni código ofuscado.

---

## 7. Gobernanza

- **Mantenedores:** deciden arquitectura y releases.
- **Colaboradores:** contribuyen en áreas asignadas.
- **Decisiones:** se documentan como ADR cuando afectan arquitectura o seguridad.
- **Consenso:** se busca; si no hay, decide el mantenedor responsable del área.
- **Transparencia:** issues, ADRs y roadmap son públicos.

---

## 8. Créditos

MiSO Desktop se apoya en el trabajo de:

- Linux Kernel
- Debian Project
- KDE Community
- Calamares
- Flatpak / Flathub
- GNU, systemd y el resto del ecosistema libre

Gracias a todas las personas que mantienen esos proyectos.
