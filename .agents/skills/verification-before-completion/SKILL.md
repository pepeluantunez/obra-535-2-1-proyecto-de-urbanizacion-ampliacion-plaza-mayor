---
name: verification-before-completion
description: >
  Strict closeout skill for Guadalmar project tasks. Use when a task is about to be marked complete
  and touches DOCX/DOCM, XLSX/XLSM, BC3/PZH, maquetacion, traceability, or mixed documentation-budget work.
  Enforce mandatory anti-mojibake checks, DOCX table and caption consistency, Excel formula preservation,
  BC3 integrity review (~C/~D/~T/~M), and explicit reporting of checks executed plus incidents.
---

# Verification Before Completion

## Objective

Close every task with objective checks before confirming completion.

Do not mark a task as done without:

1. Running the correct check set for the edited artifacts.
2. Reporting check results and incidents.
3. Declaring whether mojibake risk is clear or unresolved.

## Mandatory closeout lanes

### Office lane (DOCX/DOCM/XLSX/XLSM/PPTX/PPTM)

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_office_mojibake.ps1 -Paths "<ruta_o_carpeta>"
```

### DOCX layout lane

When DOCX tables or formatting are touched, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1 -Paths "<docx_o_carpeta>" -ExpectedFont "Montserrat" -EnforceFont $true -RequireTableCaption $true
```

### Excel formulas lane

When XLSX/XLSM are touched, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths "<excel_o_carpeta>"
```

### BC3 lane

When BC3/PZH are touched, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_bc3_integrity.ps1 -Paths "<bc3_o_carpeta>"
```

Review affected `~C`, `~D`, `~T`, and `~M` lines before closing.

### Traceability lane

When coherence between BC3/DOCX/XLSX/CSV/MD/TXT is requested, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "todo_integral" -StrictProfile
```

Use project-specific profiles when requested (`base_general`, `pluviales_fecales`, `control_calidad_plan_obra`, `residuos_sys`, `todo_integral`).

## One-command strict closeout

For mixed tasks or uncertain scope, prefer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('<ruta1>','<ruta2>') -Modo estricto -TraceProfile 'todo_integral'"
```

## Response contract

Always report:

1. Files/paths validated.
2. Commands executed.
3. Result per command: `OK`, `WARN`, or `FAIL`.
4. If any mojibake risk was detected (broken byte sequences, unreadable symbols, or corrupted punctuation).
5. If the task is truly safe to close or needs remediation.
