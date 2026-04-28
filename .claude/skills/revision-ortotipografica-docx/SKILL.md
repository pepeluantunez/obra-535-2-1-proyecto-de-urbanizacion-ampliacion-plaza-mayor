---
name: revision-ortotipografica-docx
description: >
  Revisa y corrige ortografia, acentos, grafias tecnicas y detalles ortotipograficos visibles en documentos
  DOCX y DOCM para que el acabado documental sea profesional y consistente.
---

# Revision Ortotipografica DOCX

## Objetivo

Detectar y corregir faltas de ortografia, acentos ausentes, grafias tecnicas impropias y detalles visibles poco profesionales
en documentos Word del proyecto.

## Cuándo usarla

- Cuando haya que revisar un anejo o memoria antes de entregarlo.
- Cuando el usuario pida una revision de ortografia, acentos, escritura o calidad del lenguaje visible.
- Como pasada previa al cierre documental final.

## Flujo recomendado

1. Ejecutar control rapido de mojibake:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_office_mojibake.ps1' -Paths '.\DOCS - ANEJOS'
```

2. Ejecutar control ortotipografico visible:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_docx_ortotipografia.ps1' -Paths '.\DOCS - ANEJOS' -ConfigPath '.\CONFIG\ortotipografia_tecnica_es.json'
```

3. Corregir solo el texto visible que este claramente mal:
   - acentos omitidos
   - grafias tecnicas impropias
   - mayusculas/minusculas incoherentes
   - formas poco profesionales en titulos, indices y cuerpo

4. Repetir controles tras la correccion.

## Reglas

- No reescribir el contenido tecnico si el problema es solo ortografico.
- No cambiar terminologia valida sin justificacion.
- Priorizar titulos, indices, captions de tabla y parrafos introductorios.
- Si una grafia es dudosa, contrastarla antes con el resto del proyecto y con la normativa/fuente interna disponible.

## Cierre obligatorio

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_office_mojibake.ps1' -Paths '.\DOCS - ANEJOS'
powershell -NoProfile -ExecutionPolicy Bypass -File '.\tools\check_docx_ortotipografia.ps1' -Paths '.\DOCS - ANEJOS' -ConfigPath '.\CONFIG\ortotipografia_tecnica_es.json'
```

## Resultado esperado

- Documentos sin faltas visibles obvias de acentuacion o grafia tecnica.
- Acabado mas profesional y consistente.
- Reutilizable en este proyecto y en futuros proyectos POU.
