# CLAUDE.md — Instrucciones específicas de Claude para 535.2.1

> Reglas universales del proyecto (estructura, encoding, BC3, Excel, estilo, herramientas):
> ver **AGENTS.md** — lo lee Claude y Codex. Este archivo es solo lo Claude-específico.

Lee `about-me.md` antes de responder a cualquier tarea.
Lee `CONTROL/lecciones_operativas.md` — reglas derivadas de correcciones reales.

## Reglas de comportamiento Claude

- Brief ambiguo → AskUserQuestion antes de ejecutar
- Dato no confirmado → decir "no consta"; nunca inventar
- No leer el repo entero por defecto; cambios focalizados en el archivo afectado
- No resumir al final lo que ya está en el documento
- Responder en español, directo y sin adornos
- Corrección autónoma de bugs: corregir directamente sin pedir contexto adicional
- Auto-mejora obligatoria: tras cada corrección de JL, añadir regla a `CONTROL/lecciones_operativas.md`

## Briefing de sesión (ejecutar al arrancar)

```
python3 tools/session_briefing.py
```

Muestra bloqueados, P1 pendientes y progreso del expediente antes de empezar.

## Skills (`.claude/skills/`)

**Urbanización (locales):**
- `arranque-documental-pou` — inicialización POU
- `matriz-trazabilidad-pou` — estado anejos/excels/planos
- `redaccion-controlada-anejo` — redacción solo con fuentes verificadas
- `anejo-generator` — generación de anejos
- `biblioteca-anejos-trazables` — biblioteca trazable de anejos
- `normalizar-apertura-anejos-pou` — normalización de aperturas de anejos
- `mediciones-validator` — validación cruzada de mediciones
- `harvest-fuentes-proyecto` — extracción de fuentes
- `sync-apartados-guadalmar` — sincronización de apartados con referencia Guadalmar

**Genéricas (locales):**
- `fiebdc-parser` — archivos bc3 FIEBDC-3/2020
- `control-calidad` — frecuencias PG-3, déficit de ensayos
- `redaccion-tecnica` — estilo de redacción técnica profesional
- `gestion-contexto` — /compact, /rewind, /clear, subagentes
- `glosario-proyecto` — vocabulario normalizado del expediente
- `revision-ortotipografica-docx` — revisión ortotipográfica

## Herramientas (`tools/`)

⚠ Reglas absolutas — nunca saltarse los scripts para leer o escribir datos:

- `bc3_tools.py` — ÚNICA forma de modificar archivos bc3
  Comandos: `info`, `show`, `extract`, `rename`, `compare`, `export`, `modify`, `modify-descomp`, `merge`, `recalc`, `validate`
- `excel_tools.py` — lectura determinista de xlsx
  Comandos: `info`, `sheets`, `read`, `find`
- `mediciones_validator.py` — cruce programático bc3 vs Excel
  Uso: `python3 tools/mediciones_validator.py presupuesto.bc3 hoja.xlsx --sheet=HOJA --col-code=B --col-qty=H`

## Normativa principal

PG-3, PGOU Málaga/Marbella, Decreto 293/2009 (accesibilidad), RD 1627/1997 (SyS),
RD 105/2008 y Ley 7/2022 (residuos), RD 140/2003 (aguas), RD 849/1986 (DPH).

## Corpus normativo compartido

Ruta: `C:\Users\USUARIO\Documents\Claude\Projects\normativa-obra-civil\`

Antes de citar cualquier norma en un anejo:
1. Consultar `catalog.json` por clave (PG-3, DEC293, RD1627, etc.)
2. Extraer el texto del PDF con herramienta, o usar el resumen del README de la subcarpeta
3. Nunca citar normativa de memoria — si no consta en el corpus, indicarlo explícitamente
4. Formato de cita: `[Clave] Art. X.X — "[texto]"`

## Cierre automatico de anejo

IMPORTANT: cuando el usuario diga que un anejo esta terminado o pida cerrarlo/entregarlo
(frases tipo "cierre el anejo X", "termine el anejo Y", "revisa el anejo Z antes de
entregar", "ya esta el anejo N"), **invocar automaticamente la skill `cierre-anejo`
ANTES de declarar la tarea completada**. No responder "hecho" o equivalentes hasta
haber ejecutado el cierre y reportado el resultado pasa/falla de los 4 checks.

Si algun check falla con errores criticos: parar, listar exactamente que arreglar, no
declarar cierre OK.
