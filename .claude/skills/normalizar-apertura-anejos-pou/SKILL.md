---
name: normalizar-apertura-anejos-pou
description: >
  Normaliza la apertura de anejos DOCX de un proyecto de urbanizacion: inserta 1. OBJETO, añade introduccion
  especifica por anejo, conserva los apartados particulares y homogeneiza el indice y la ortotipografia visible.
---

# Normalizar Apertura Anejos POU

## Objetivo

Dejar todos los anejos con una apertura profesional y homogénea:

- portada coherente
- índice con el mismo estilo
- `1. OBJETO` en todos los anejos
- introducción específica por anejo
- resto de apartados singulares del anejo mantenidos y adaptados

## Flujo

1. Sincronizar apartados base desde Guadalmar si procede:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\sync_docx_section_names_from_guadalmar.ps1'
```

2. Normalizar apertura e índices:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\standardize_annex_openings.ps1' `
  -ProjectConfig '.\CONFIG\proyecto.template.json' `
  -OpeningsConfig '.\CONFIG\apertura_anejos_plaza_mayor.json' `
  -OrthographyConfig '.\CONFIG\ortotipografia_tecnica_es.json' `
  -RunSyncFromGuadalmar
```

3. Cerrar con controles:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_office_mojibake.ps1' -Paths '.\DOCS - ANEJOS'
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_docx_tables_consistency.ps1' -Paths '.\DOCS - ANEJOS' -ExpectedFont 'Montserrat' -EnforceFont 1 -RequireTableCaption 1
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_docx_ortotipografia.ps1' -Paths '.\DOCS - ANEJOS' -ConfigPath '.\CONFIG\ortotipografia_tecnica_es.json'
```

## Reglas

- `1. OBJETO` debe existir siempre salvo excepcion legal expresa.
- No copiar redaccion donor tecnica.
- Conservar los apartados singulares del anejo tras `1. OBJETO`.
- Rellenar solo informacion defendible con las fuentes ya disponibles.
- Corregir grafias y acentos visibles en titulos, indices y textos de arranque.

## Resultado esperado

- Todos los anejos arrancan con el mismo criterio.
- Los indices quedan homogéneos y alineados con el cuerpo.
- El flujo queda reutilizable para futuros proyectos cambiando la configuracion.
