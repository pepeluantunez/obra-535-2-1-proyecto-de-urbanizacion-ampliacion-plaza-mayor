---
name: dispatching-parallel-agents
description: >
  Parallel execution skill for Guadalmar project work. Use when the user explicitly asks to use agents,
  parallelize, accelerate repetitive reviews, or run strict multi-block checks in parallel.
  Split work into disjoint ownership lanes (documental, BC3, traceability, normative), merge results,
  and finish with strict closeout checks before reporting completion.
---

# Dispatching Parallel Agents

## Objective

Speed up repetitive work without losing control or quality, and keep the main context clean when the intermediate output is disposable.

## Activation rule

Use only when the user explicitly requests agents or parallel work.

Before dispatching, apply this mental test:

`Do I need the intermediate output of this task, or only the conclusion?`

- If only the conclusion matters, a subagent is a good fit.
- If the main thread needs the intermediate reasoning to decide the next step, keep it inline.

Typical good-fit cases:

1. Reviewing a long annex and returning only discrepancies.
2. Parsing a BC3 and returning only chapter or concept summaries.
3. Comparing several documents and returning only the status matrix.
4. Generating a bounded draft whose internal generation process does not need to pollute the main context.

Do not dispatch just because a task is long. Dispatch only when context isolation is materially useful.

## Cost discipline

Parallel work adds coordination overhead.

- One bounded subtask can be worth it if it keeps the main thread clean.
- Spawning many small workers usually costs more than it saves.
- Prefer a small number of high-value lanes.
- If a task would produce limited intermediate output, keep it inline.

## Lane design (disjoint ownership)

Assign each lane a non-overlapping scope:

1. Document lane: DOCX/DOCM/XLSX/XLSM formatting and content checks.
2. BC3 lane: budget integrity and `~C/~D/~T/~M` coherence.
3. Traceability lane: cross-document consistency and profile checks.
4. Normative lane: scope-level regulatory consistency.

Do not assign the same file to two writing lanes.

## Required setup before dispatch

State these items first:

```text
Objetivo:
Rutas o archivos en alcance:
Carril por lane:
Resultado esperado por lane:
Condiciones de parada:
Checks de cierre previstos:
```

If any lane would write to `DOCX`, `XLSX`, `XLSM`, `DOCM`, `BC3`, or `PZH`, define the human-review checkpoint before dispatching.

## Mandatory lane outputs

Each lane must return:

1. Files reviewed/edited.
2. Checks executed.
3. Incidents with severity (`critical`, `major`, `minor`).
4. Remaining risks and blocked items.

## Merge protocol

After collecting all lane outputs:

1. Consolidate conflicts and duplicates.
2. Resolve cross-lane contradictions (values, units, names, references).
3. Run strict final closeout on touched paths:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_project_closeout.ps1' -Paths @('<ruta1>','<ruta2>') -StrictDocxLayout $true -RequireTableCaption $true -CheckExcelFormulas $true"
```

4. If scope includes global coherence, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "todo_integral" -StrictProfile
```

## Quality gates

Never report completion if:

1. Any lane has unresolved `critical`.
2. Final strict closeout fails.
3. Mojibake risk remains unverified in Office artifacts.
4. BC3 changes lack integrity confirmation.

## Response contract

Report the merged result like this:

```text
Lanes ejecutados:
Archivos por lane:
Checks por lane:
Incidencias:
Conflictos resueltos:
Cierre final ejecutado:
Seguro para cerrar:
```
