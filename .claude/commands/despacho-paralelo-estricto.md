---
description: Descompone una tarea grande en carriles paralelos y cierra con validacion estricta final
argument-hint: <objetivo>
---

# Despacho Paralelo Estricto

Usar este comando cuando el usuario pida explicitamente trabajar con agentes en paralelo.

## Protocolo

1. Definir objetivo y alcance del comando.
2. Dividir trabajo en carriles con ownership no solapado:
   - Carril documental
   - Carril BC3
   - Carril trazabilidad
   - Carril normativa
3. Delegar carriles independientes y mantener trabajo local para integracion.
4. Exigir a cada carril:
   - Archivos tocados/revisados
   - Chequeos ejecutados
   - Incidencias con severidad
5. Integrar resultados y resolver contradicciones entre carriles.
6. Ejecutar cierre estricto en rutas afectadas:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_project_closeout.ps1' -Paths @('<ruta1>','<ruta2>') -StrictDocxLayout $true -RequireTableCaption $true -CheckExcelFormulas $true"
```

7. Si hubo trazabilidad transversal, ejecutar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "todo_integral" -StrictProfile
```

## Reglas de cierre

- No cerrar si hay incidencias `critical`.
- No cerrar si falla el cierre estricto final.
- No cerrar si no hay evidencia de anti-mojibake y coherencia BC3.
