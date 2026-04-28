---
name: document-closeout-agent
description: >
  Shared closeout skill for Plaza Mayor document-heavy work. Use when a task is about to be closed
  and touched DOCX, DOCM, XLSX, XLSM, PPTX, PPTM, BC3, PZH, maquetacion, mixed document-budget
  work, or cross-document traceability.
---

# Document Closeout Agent

## Objective

Standardize the final verification step so a task is not marked complete on intuition alone.

This skill does not replace project authority. It packages the existing closeout discipline into a reusable output contract.

## Required inputs

Before running closeout, state:

```text
Paths validados:
Tipo de artefacto:
Carril principal:
Cambio esperado:
```

## Lane map

Choose the smallest lane that covers the actual edit:

1. `office`
   Trigger:
   - `DOCX`, `DOCM`, `XLSX`, `XLSM`, `PPTX`, `PPTM`
   Run:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_office_mojibake.ps1 -Paths "<ruta_o_carpeta>"`

2. `template-completion`
   Trigger:
   - placeholders
   - restos donor
   - documentos prefijados desde plantilla
   Run:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_template_completion.ps1 -Paths "<ruta_o_carpeta>"`

3. `docx-layout`
   Trigger:
   - tablas Word
   - captions
   - maquetacion
   - tipografia o legibilidad
   Run:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1 -Paths "<docx_o_carpeta>" -ExpectedFont "Montserrat" -EnforceFont $true -RequireTableCaption $true`

4. `excel-formulas`
   Trigger:
   - formulas
   - formato seguro en `XLSX` o `XLSM`
   Run:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths "<excel_o_carpeta>"`

5. `bc3`
   Trigger:
   - `BC3`
   - `PZH`
   - presupuesto
   Required sequence:
   - snapshot antes
   - operacion
   - snapshot despues
   - diff
   - integridad
   Run:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_bc3_integrity.ps1 -Paths "<bc3_o_carpeta>"`
   Review:
   - `~C`
   - `~D`
   - `~T`
   - `~M`

6. `traceability`
   Trigger:
   - coherence across Word, Excel, BC3, CSV, JSON, memory, annexes
   Run:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_traceability_consistency.ps1 -Paths "<ruta_o_carpeta>"`
   Optional formal profile:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "<perfil>" -StrictProfile`

7. `mixed`
   Trigger:
   - task touches more than one lane or the safe closeout is not obvious
   Run:
   - `powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_project_closeout.ps1' -Paths @('<ruta1>','<ruta2>') -StrictDocxLayout $true -RequireTableCaption $true -CheckExcelFormulas $true"`
   If traceability is cross-cutting:
   - `powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('<ruta1>','<ruta2>','<ruta3>') -Modo estricto -TraceProfile 'base_general'"`

## Stop rules

Do not confirm completion if any of these remains true:

1. Mojibake risk is unverified.
2. The lane was guessed but not stated.
3. A required check was skipped without explanation.
4. A BC3 task lacks snapshot or diff evidence.
5. A mixed task has no integrated closeout.
6. A template-based document still has placeholders or donor remnants.

## Output contract

Report final closeout like this:

```text
Paths validados:
Comandos ejecutados:
Resultado por comando:
Incidencias:
Riesgo de mojibake:
Seguro para cerrar:
```

## Relationship with existing skills

- Use together with `.agents/skills/ecosystem-triage/SKILL.md` when the lane is still unclear.
- Reuses the same project checks already enforced in `AGENTS.md`.
- Supersedes ad-hoc closeout prose that does not list commands and outcomes.
- Absorbs the useful placeholder and donor check previously duplicated in `.claude/skills/cierre-documental-office/SKILL.md`.
