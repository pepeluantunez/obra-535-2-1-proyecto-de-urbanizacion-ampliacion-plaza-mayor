---
name: arranque-documental-pou
description: >
  Arranque documental seguro para proyectos de urbanizacion. Usar cuando haya que dejar memoria y anejos
  listos para empezar redaccion: personalizar titulos, crear memoria, rellenar objeto/antecedentes/normativa
  base, limpiar restos donor visibles y cerrar con controles DOCX/Office sin inventar contenido tecnico.
---

# Arranque Documental POU

## Objetivo

Dejar el expediente listo para redactar sin meter calculos, mediciones ni afirmaciones no soportadas.

## Flujo

1. Leer `CONFIG/proyecto.template.json`.
2. Verificar que existen `DOCS - ANEJOS\Plantillas\PLANTILLA_MAESTRA_ANEJOS.docx` y `PLANTILLA_MAESTRA_MEMORIA.docx`.
3. Ejecutar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\bootstrap_memory_and_annexes.ps1' -ProjectConfig '.\CONFIG\proyecto.template.json'"
```

4. Revisar visualmente o por extraccion el resultado en:
   - titulo del proyecto
   - titulo del anejo
   - `1. OBJETO`
   - `2. ANTECEDENTES / INFORMACION DE PARTIDA`
   - normativa base
5. Cerrar con:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\check_template_completion.ps1' -Paths @('.\DOCS - ANEJOS','.\DOCS - MEMORIA')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\check_office_mojibake.ps1' -Paths @('.\DOCS - ANEJOS','.\DOCS - MEMORIA')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\check_docx_tables_consistency.ps1' -Paths @('.\DOCS - ANEJOS','.\DOCS - MEMORIA') -ExpectedFont 'Montserrat'"
```

## Reglas

- Rellenar solo contenido de arranque defendible.
- No tocar calculos ni conclusiones tecnicas salvo que el usuario lo pida y existan fuentes.
- Si aparece texto donor visible, sustituirlo o neutralizarlo.
- Si la memoria no existe, crearla.
- Si algun anejo ya tiene texto tecnico real, preservar lo existente y completar solo huecos de plantilla.

## Resultado esperado

- Memoria creada o actualizada.
- Anejos titulados y personalizados.
- Arranque limpio de placeholders obvios.
- Controles de mojibake y consistencia ejecutados antes de responder.
