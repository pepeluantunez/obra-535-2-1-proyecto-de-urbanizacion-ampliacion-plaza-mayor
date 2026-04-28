# Instrucciones de proyecto — Urbanización Plaza Mayor 535.2.1

Lee `about-me.md` antes de responder a cualquier tarea.

## Reglas

- Brief ambiguo → AskUserQuestion antes de ejecutar
- Dato no confirmado → decir "no consta", nunca inventar
- Discrepancia de cantidades → Excel es fuente de verdad (Excel > Word > bc3)
- Entregables con numeración del expediente (535.2.1)
- Terminología normalizada: medición, partida, precio unitario, importe, anejo, POU
- No resumir al final lo que ya está en el documento
- Responder en español, directo y sin adornos

## Skills (`.claude/skills/`)

**Urbanización:**
- `arranque-documental-pou` — inicialización POU
- `matriz-trazabilidad-pou` — estado anejos/excels/planos
- `redaccion-controlada-anejo` — redacción solo con fuentes verificadas
- `pou-viario` — obras de urbanización viaria
- `cierre-documental-office` — cierre y entrega
- `harvest-fuentes-proyecto` — extracción de fuentes
- `dispatching-parallel-agents` — subagentes paralelos, mental test incluido
- `verification-before-completion` — verificación antes de cerrar tarea

**Genéricas:**
- `fiebdc-parser` — archivos bc3 FIEBDC-3/2020
- `control-calidad` — frecuencias PG-3, déficit de ensayos
- `redaccion-tecnica` — estilo de redacción técnica profesional
- `task-master` — tareas en fases con gates obligatorios
- `council-ingenieria` — debate multidisciplinar, modo estocástico disponible
- `gestion-contexto` — /compact, /rewind, /clear, subagentes
- `glosario-proyecto` — vocabulario normalizado del expediente
- `briefing-tecnico` — interrogar antes de ejecutar, una pregunta a la vez, brief aprobado obligatorio

## Herramientas (`tools/`)

⚠ Reglas absolutas — nunca saltarse los scripts para escribir o leer datos:

- `bc3_tools.py` — ÚNICA forma de modificar archivos bc3. El LLM nunca escribe bc3 directamente.
  Comandos: info, show, extract, rename, compare, export, modify, modify-descomp, merge, recalc, validate
- `excel_tools.py` — lectura determinista de xlsx. Usar SIEMPRE antes de leer cantidades del Excel.
  El LLM lee los CSV resultantes, no el xlsx directamente (79-85 rangos combinados → invención de valores).
  Comandos: info, sheets, read, find
- `mediciones_validator.py` — cruce programático bc3 vs Excel. Sin LLM para las cantidades.
  Uso: `python3 tools/mediciones_validator.py presupuesto.bc3 hoja.xlsx --sheet=HOJA --col-code=B --col-qty=H`

## Normativa

Ver carpeta NORMATIVA. Principal: PG-3, PGOU Málaga, Decreto 293/2009.
