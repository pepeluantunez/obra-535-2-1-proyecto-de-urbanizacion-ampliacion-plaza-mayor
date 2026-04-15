---
description: Ejecuta trazabilidad estricta por perfil oficial del proyecto y devuelve incidencias accionables
argument-hint: <perfil> [needle1] [needle2]
---

# Trazabilidad Estricta

Cruzar documentos y presupuesto con los perfiles oficiales del proyecto.

## Pasos

1. Tomar perfil solicitado por el usuario.
2. Si no se indica perfil, usar `todo_integral`.
3. Ejecutar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "<perfil>" -StrictProfile
```

4. Si el usuario aporta conceptos/anclas (`needles`), ejecutar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "<perfil>" -Needles "<needle1>","<needle2>" -StrictProfile
```

5. Reportar:
   - Perfil usado y rutas faltantes/no soportadas.
   - Inconsistencias encontradas.
   - Acciones concretas para cerrar cada inconsistencia.

## Perfiles validos

- `base_general`
- `pluviales_fecales`
- `control_calidad_plan_obra`
- `residuos_sys`
- `todo_integral`
