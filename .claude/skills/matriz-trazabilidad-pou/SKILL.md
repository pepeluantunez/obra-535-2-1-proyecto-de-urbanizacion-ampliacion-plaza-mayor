---
name: matriz-trazabilidad-pou
description: >
  Matriz de estado y trazabilidad para proyectos de urbanizacion. Usar cuando haya que saber que anejo
  depende de que fuentes, excels, BC3 o planos, que esta arrancado o pendiente y donde faltan cruces
  antes de cerrar el expediente o planificar la redaccion.
---

# Matriz Trazabilidad POU

## Objetivo

Tener una vista unica del estado documental y de los cruces obligatorios del proyecto.

## Flujo

1. Ejecutar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\create_annex_status_matrix.ps1' -ProjectRoot '.'"
```

2. Si hay fuentes estructuradas, combinar con:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\build_project_facts.ps1' -ProjectConfig '.\CONFIG\proyecto.template.json' -SkipDiscovery"
```

3. Revisar:
   - anejos sin fuentes
   - anejos arrancados pero no trazables
   - excels sin documento asociado
   - BC3 o CSV sin cruce declarado

## Salidas

- `PLANNING\estado_anejos.md`
- `PLANNING\estado_anejos.csv`
- `PLANNING\estado_anejos.json`

## Campos minimos

- anejo
- ruta_docx
- estado
- fuentes_confirmadas
- excels_asociados
- bc3_asociado
- notas_base
- pendiente_principal
