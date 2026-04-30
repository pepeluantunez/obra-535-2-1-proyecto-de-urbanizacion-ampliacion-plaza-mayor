# SOP - Importacion Profesional de Bloques Comunes DOCX

## Objetivo
Automatizar la importacion de redaccion comun donor -> proyecto preservando formato Word real (runs, listas, tablas, espaciados), sin rehacer el DOCX completo.

## Criterios de clasificacion (obligatorio)
- `COMUN_FIJO`: normativa/metodologia transversal, aplicable casi literal.
- `COMUN_PARAMETRIZABLE`: misma redaccion base con datos de proyecto.
- `ESPECIFICO_PROYECTO`: datos de emplazamiento, mediciones, resultados de calculo propios, referencias singulares de compania.

## Reglas de seguridad
- No tocar cabeceras, pies, TOC, PAGEREF, campos ni marcadores salvo encargo expreso.
- Editar solo `word/document.xml` y solo entre headings mapeados.
- No sustituir por texto plano cuando el bloque donor tenga estructura (listas, tablas, ecuaciones, subparrafos).
- Siempre `dry-run` antes de `apply`.

## Flujo operativo
1. Definir/actualizar mapeo en `CONFIG/docx_common_blocks_import_map.json`.
2. Ejecutar simulacion:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\\tools\\import_docx_common_blocks.ps1 -MappingPath .\\CONFIG\\docx_common_blocks_import_map.json`
3. Revisar reporte:
   - `CONTROL/import_docx_common_blocks_report.json`
4. Ejecutar aplicacion:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\\tools\\import_docx_common_blocks.ps1 -MappingPath .\\CONFIG\\docx_common_blocks_import_map.json -Apply`
5. Validar solo tocados:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\\tools\\check_office_mojibake.ps1 -Paths @('<rutas_tocadas>')`
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\\tools\\check_docx_tables_consistency.ps1 -Paths @('<rutas_tocadas>') -ExpectedFont "Montserrat" -EnforceFont $true -RequireTableCaption $true`

## Politica de placeholders
- Formato unico: `{{MAYUSCULAS_CON_GUION_BAJO}}`.
- No dejar datos donor en bloques `COMUN_PARAMETRIZABLE`.
- Cuando un bloque donor incluya dato local (ej. nombre de via, informe, caudal), sustituir por placeholder antes de cierre.

## Criterio de cierre
- Reporte de importacion sin `missing_source_heading` ni `missing_target_heading` en bloques obligatorios.
- Checks Office y DOCX en `OK`.
- Tabla final de tramos tocados y placeholders activos.
