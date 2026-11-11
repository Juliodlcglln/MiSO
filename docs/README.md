# Documentación de MiSO Desktop

Índice de la documentación del proyecto. Está pensada para leerse en orden la primera
vez y como referencia después.

| # | Documento | Para qué sirve |
|---|---|---|
| 01 | [Reporte del proyecto](01-reporte-del-proyecto.md) | Resumen ejecutivo, decisión de base, alcance y riesgos |
| 02 | [Arquitectura](02-arquitectura.md) | Capas, arranque, discos, actualizaciones y flujos |
| 03 | [Anillos y seguridad](03-anillos-y-seguridad.md) | Modelo de anillos, amenazas, privilegios y hardening |
| 04 | [Componentes](04-componentes.md) | Mapa de componentes, rutas e interfaces |
| 05 | [Proceso de build](05-proceso-de-build.md) | Requisitos, etapas y Solución de problemas |
| 06 | [Instalación y pruebas](06-instalacion-y-pruebas.md) | QEMU, instalación, USB y matriz de pruebas |
| 07 | [Roadmap](07-roadmap.md) | Fases, entregables y criterios de aceptación |
| 08 | [Decisiones técnicas](08-decisiones-tecnicas.md) | ADRs y alternativas consideradas |
| 09 | [Licencias y gobernanza](09-licencias-y-gobernanza.md) | GPL, marcas, contribución y releases |

## Convenciones

- **MiSO Core** se refiere al kernel educativo anterior, hoy archivado.
- **MiSO Desktop** es este proyecto.
- **Anillo** es un canal de entrega con cadencia y riesgo propios.
- **PJD** es la capa de escritorio de MiSO sobre KDE Plasma.
- **`misod`** es el broker de privilegios; **`miso`** es la CLI de usuario.

## Estado de la documentación

La documentación describe el **diseño objetivo 1.0** y marca explícitamente qué existe
en 0.1.0. Si un documento y el código difieren, el código manda; abre un issue o
actualiza el documento en el mismo cambio.
