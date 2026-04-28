---
name: ecosystem-triage
description: >
  Entry-point skill for Plaza Mayor and sibling urbanizacion repos. Use when a task must be routed
  before editing, when scope is unclear, when multiple layers may be mixed (proyecto, plantilla,
  toolkit), or when the user asks to clean noise and keep only useful artifacts.
---

# Ecosystem Triage

## Objective

Turn an ambiguous request into a bounded work order that:

1. Uses the right authority files.
2. Reads only the minimum necessary paths.
3. Chooses the correct execution lane.
4. Names the mandatory checks before any risky edit.
5. Flags clutter, drift, or misplaced artifacts without deleting active work blindly.

## Read order

Read in this order unless the task is trivially local:

1. `MAPA_PROYECTO.md`
2. `FUENTES_MAESTRAS.md`
3. `DECISIONES_PROYECTO.md`
4. `ESTADO_PROYECTO.md`
5. `AGENTS.md`

If the task mentions repo structure or ecosystem boundaries, also read:

6. `CONFIG/repo_contract.json`
7. `README.md`
8. `PLANNING/KANBAN.md`

## Stop rules

Do not start edits yet if any of these is true:

1. No `Fuente maestra` can be named.
2. The request mixes proyecto, plantilla, and toolkit without a clear target layer.
3. The read set exceeds 5 paths and cannot be justified.
4. The requested write would touch `DOCX`, `XLSX`, `XLSM`, `DOCM`, `BC3`, or `PZH` without an explicit closeout lane.

## Lane selection

Choose exactly one primary lane:

1. `documental`
   Trigger: `DOCX`, `DOCM`, Office XML, captions, maquetacion, ortotipografia.
   Closeout:
   - `tools\check_office_mojibake.ps1`
   - `tools\check_docx_tables_consistency.ps1` when tables or layout are involved

2. `excel`
   Trigger: `XLSX`, `XLSM`, formulas, styling, plantillas de medicion.
   Closeout:
   - `tools\check_excel_formula_guard.ps1`
   - `tools\check_office_mojibake.ps1`

3. `bc3`
   Trigger: `BC3`, `PZH`, partidas, mediciones, descompuestos.
   Mandatory sequence:
   - `tools\bc3_snapshot.ps1` before
   - operation
   - `tools\bc3_snapshot.ps1` after
   - `tools\bc3_diff_report.ps1`
   - `tools\check_bc3_integrity.ps1`

4. `trazabilidad`
   Trigger: coherence across memory, annexes, Excel, BC3, JSON graphs, delivery sets.
   Closeout:
   - `tools\check_traceability_consistency.ps1`
   - `tools\run_traceability_profile.ps1` when a formal profile applies

5. `normativa`
   Trigger: scope checks, applicable standards, compliance review.
   Closeout:
   - `tools\check_normativa_scope.ps1`

6. `mixto`
   Trigger: more than one lane is genuinely required.
   Closeout:
   - `tools\run_project_closeout.ps1`
   - `tools\run_estandar_proyecto.ps1` when traceability is cross-cutting

## Cleanup lane

When the user asks to remove noise, classify findings before proposing deletion:

1. `retirar ya`
   Examples: duplicate governance docs already retired elsewhere, foreign-project files confirmed as misplaced, generated temp files.

2. `archivar o mover`
   Examples: old drafts, deprecated guides, donor files kept only for recovery.

3. `mantener`
   Examples: active authority docs, donor backups explicitly referenced by project rules, current planning files.

Never remove files only because they "look old". Require either:

1. An authority file that marks them as obsolete.
2. A validated replacement path.
3. Clear evidence they are generated noise.

## Output contract

Return this exact block before substantial edits:

```text
Tipo de tarea:
Objetivo exacto:
Fuente maestra:
Archivos a leer:
Archivos a ignorar:
Carril principal:
Checks obligatorios:
Salida esperada:
Criterio de cierre:
Ruido detectado:
```

## Good outcomes

Good triage reduces coordination cost. It should not create new governance in root, duplicate repo rules, or replace project authority with generic advice.
