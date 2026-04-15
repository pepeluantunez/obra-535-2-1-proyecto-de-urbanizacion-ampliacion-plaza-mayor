---
description: Ejecuta cierre estricto de cambios (Office, BC3, tablas DOCX, formulas Excel y anti-mojibake)
argument-hint: [ruta1] [ruta2] [ruta3]
---

# Cierre Estricto

Aplicar cierre tecnico obligatorio antes de dar por terminada una tarea.

## Pasos

1. Determinar rutas de revision:
   - Si el usuario pasa rutas, usar esas rutas.
   - Si no pasa rutas, usar `.` (workspace actual).
2. Ejecutar cierre estricto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_project_closeout.ps1' -Paths @('<ruta1>','<ruta2>') -StrictDocxLayout $true -RequireTableCaption $true -CheckExcelFormulas $true"
```

3. Si la tarea es mixta o requiere cierre integral, ejecutar ademas:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('<ruta1>','<ruta2>') -Modo estricto -TraceProfile 'todo_integral'"
```

4. Reportar:
   - Comandos ejecutados.
   - Resultado por control (`OK/WARN/FAIL`).
   - Incidencias detectadas y siguiente accion.

No responder "terminado" si algun control falla.
