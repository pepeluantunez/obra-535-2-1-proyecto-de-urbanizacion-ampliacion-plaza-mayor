---
name: sync-apartados-guadalmar
description: >
  Sincroniza solo los nombres de apartados e indice estructural de los anejos DOCX de un proyecto nuevo
  tomando como donor el anejo homologo de Guadalmar. Usar cuando haya que clonar la estructura base sin
  arrastrar la redaccion tecnica donor.
---

# Sync Apartados Guadalmar

## Objetivo

Copiar la estructura documental de anejos homologos desde Guadalmar a un proyecto nuevo sin copiar el texto tecnico.

## Uso recomendado

Ejecutar cuando el usuario pida que los indices y apartados de cada anejo sean iguales a Guadalmar "de primeras",
manteniendo despues libertad para adaptar cada anejo.

## Comando base

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\sync_docx_section_names_from_guadalmar.ps1'
```

## Parametros utiles

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\sync_docx_section_names_from_guadalmar.ps1' `
  -SourceRoot '..\MEJORA CARRETERA GUADALMAR\PROYECTO 535\535.2\535.2.2 Mejora Carretera Guadalmar\POU 2026\DOCS\Documentos de Trabajo' `
  -TargetRoot '.\DOCS - ANEJOS' `
  -ReportPath '.\CONTROL\guadalmar_docx_structure_sync.md'
```

## Reglas

- Importar solo nombres de apartados, no parrafos de redaccion tecnica donor.
- Mantener portada o preambulo previo del DOCX destino si existe.
- Preferir el DOCX canonico del anejo donor y evitar variantes de maquetado o temporales.
- Revisar siempre el resultado con control anti-mojibake y consistencia DOCX antes de cerrar.

## Cierre obligatorio

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_office_mojibake.ps1' -Paths '.\DOCS - ANEJOS'
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_docx_tables_consistency.ps1' -Paths '.\DOCS - ANEJOS' -ExpectedFont 'Montserrat' -EnforceFont $true -RequireTableCaption $true
```

## Resultado esperado

- Cada anejo conserva su DOCX propio pero adopta la misma jerarquia de apartados del anejo homologo de Guadalmar.
- La operacion queda trazada en un informe Markdown dentro de `CONTROL`.
