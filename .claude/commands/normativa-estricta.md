---
description: Revisa cobertura normativa por alcance tecnico con severidad y evidencia por archivo
argument-hint: [ruta1] [ruta2] [ruta3]
---

# Normativa Estricta

Lanzar chequeo normativo rapido y generar reporte util para correccion.

## Pasos

1. Si el usuario da rutas, usar esas rutas.
2. Si no da rutas, usar este set por defecto:
   - `DOCS\Documentos de Trabajo\7.- Red de Saneamiento - Pluviales`
   - `DOCS\Documentos de Trabajo\8.- Red de Saneamiento - Fecales`
   - `DOCS\Documentos de Trabajo\12.- Accesibilidad`
   - `DOCS\Documentos de Trabajo\13.- Estudio de Gestion de Residuos`
   - `DOCS\Documentos de Trabajo\14.- Control de Calidad`
   - `DOCS\Documentos de Trabajo\15.- Plan de Obra`
   - `DOCS\Documentos de Trabajo\17.- Seguridad y Salud`
3. Ejecutar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_normativa_scope.ps1 -Paths "<ruta_o_carpeta>" -FailOnMissing
```

4. Reportar por archivo:
   - Dominios tecnicos detectados.
   - Referencias normativas detectadas.
   - Ausencias normativas (si existen).
   - Severidad (`critical/major/minor`) y propuesta de correccion.

No cerrar la revision normativa sin evidencias por archivo.
