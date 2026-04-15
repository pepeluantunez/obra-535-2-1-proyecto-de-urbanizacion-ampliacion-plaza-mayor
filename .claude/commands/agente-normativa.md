---
description: Activa el agente normativa-auditor para revision normativa con trazabilidad de evidencias
argument-hint: [ruta1] [ruta2] [ruta3]
---

# Agente Normativa

Usar el agente especializado `normativa-auditor` en `.claude/agents/normativa-auditor.md`.

## Pasos

1. Cargar instrucciones del agente.
2. Definir rutas objetivo (argumentos del comando o set por defecto de normativa-estricta).
3. Ejecutar chequeo inicial:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_normativa_scope.ps1 -Paths "<ruta_o_carpeta>" -FailOnMissing
```

4. Entregar reporte con:
   - Evidencia por archivo.
   - Severidad por hallazgo.
   - Correccion propuesta.
   - Riesgos no verificables.
