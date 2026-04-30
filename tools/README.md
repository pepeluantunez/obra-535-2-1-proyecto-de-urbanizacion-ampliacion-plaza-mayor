# Tools reutilizables

Esta carpeta contiene utilidades tecnicas compartidas entre proyectos.

Recomendaciones:

- Mantener `bin/` y `obj/` fuera de la plantilla base.
- Si se recompila una herramienta, versionar solo codigo fuente y scripts de build.
- Documentar en cada herramienta sus dependencias y modo de ejecucion.
- Para unificar el espaciado de parrafos de cuerpo en DOCX segun el patron de Guadalmar (Anejo 2, apartado 2), usar: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\normalize_docx_body_spacing.ps1 -Paths @('.\DOCS - ANEJOS')`.
- Regla de guardia portada/indice: tras cambios de maquetacion DOCX, ejecutar `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_frontmatter_spacing.ps1 -Paths @('.\DOCS - ANEJOS') -FailOnIssue` para evitar que se pegue el bloque `proyecto -> anejo -> indice`.
