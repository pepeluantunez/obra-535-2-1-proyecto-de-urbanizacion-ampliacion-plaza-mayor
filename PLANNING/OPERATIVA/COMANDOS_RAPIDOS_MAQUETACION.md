# Comandos Rapidos de Estandarizacion

## 1) Cierre rapido flexible (iteracion)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('.\DOCS\Documentos de Trabajo\14.- Control de Calidad\Anexo 14 - Control de calidad.docx','.\DOCS\Documentos de Trabajo\14.- Control de Calidad\535.2.2 Control-Calidad.xlsx','.\PRESUPUESTO\535.2.bc3') -Modo flexible"
```

## 2) Cierre estricto final
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('.\DOCS\Documentos de Trabajo\14.- Control de Calidad\Anexo 14 - Control de calidad.docx','.\DOCS\Documentos de Trabajo\14.- Control de Calidad\535.2.2 Control-Calidad.xlsx','.\PRESUPUESTO\535.2.bc3') -Modo estricto"
```

## 3) Cierre estricto + trazabilidad base
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('.\DOCS\Documentos de Trabajo\7.- Red de Saneamiento - Pluviales','.\DOCS\Documentos de Trabajo\8.- Red de Saneamiento - Fecales','.\PRESUPUESTO\535.2.bc3') -Modo estricto -TraceProfile 'pluviales_fecales'"
```

## 4) Trazabilidad por perfil (sin cierre documental)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile base_general -StrictProfile
```

## 5) Trazabilidad por perfil y conceptos clave
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile pluviales_fecales -Needles "MCG-1.04#","UAC010.3.6","CLP630" -StrictProfile
```

## 6) Guardar baseline de formulas Excel
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths ".\DOCS\Documentos de Trabajo\14.- Control de Calidad\535.2.2 Control-Calidad.xlsx" -WriteManifestPath ".\.codex_tmp\excel_formulas_before.json"
```

## 7) Verificar formulas Excel tras cambios
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths ".\DOCS\Documentos de Trabajo\14.- Control de Calidad\535.2.2 Control-Calidad.xlsx" -BaselineManifestPath ".\.codex_tmp\excel_formulas_before.json"
```

## 8) Autofix de captions de tablas DOCX + validacion
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\autofix_docx_captions.ps1 -Paths ".\DOCS\Documentos de Trabajo\14.- Control de Calidad\Anexo 14 - Control de calidad.docx" -CaptionPrefix "Tabla" -DefaultDescription "Descripcion"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1 -Paths ".\DOCS\Documentos de Trabajo\14.- Control de Calidad\Anexo 14 - Control de calidad.docx" -ExpectedFont "Montserrat" -EnforceFont 1 -RequireTableCaption 1
```

## 9) Trazabilidad estricta Residuos + SyS
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile residuos_sys -StrictProfile
```

## 10) Trazabilidad estricta global (todo el proyecto)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile todo_integral -StrictProfile
```
