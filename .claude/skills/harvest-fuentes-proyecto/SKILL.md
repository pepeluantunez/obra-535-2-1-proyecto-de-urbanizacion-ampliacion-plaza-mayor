---
name: harvest-fuentes-proyecto
description: >
  Extraccion y consolidacion de fuentes para proyectos de urbanizacion. Usar cuando haya carpetas donor,
  antecedentes, informes o documentos previos y se necesite convertirlos en hechos confirmados, cronologia,
  promotores, ambito y fuentes aprovechables para memoria y anejos.
---

# Harvest Fuentes Proyecto

## Objetivo

Convertir carpetas de antecedentes en una base reutilizable de hechos y fuentes, sin mezclar suposiciones con datos confirmados.

## Flujo

1. Identificar carpetas de entrada.
2. Ejecutar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\build_project_facts.ps1' -ProjectConfig '.\CONFIG\proyecto.template.json' -SourcePaths @('<ruta1>','<ruta2>')"
```

3. Revisar los artefactos generados en `PLANNING`.
4. Separar:
   - hechos confirmados
   - pistas fuertes
   - huecos pendientes
5. Enlazar cada fuente util con memoria o anejo destino.

## Artefactos de salida

- `PLANNING\<slug>\facts.yaml`
- `PLANNING\<slug>\facts.md`
- `PLANNING\<slug>\cronologia.md`
- `PLANNING\<slug>\fuentes_por_anejo.md`

## Reglas

- No presentar como hecho lo que solo sea una deduccion por nombre de archivo.
- Incluir ruta fuente siempre que sea posible.
- Priorizar cronologia, ambito, promotores, superficie, normativa, accesos, movilidad y condicionantes sectoriales.
- Si faltan textos extraibles, dejarlo marcado como pendiente en lugar de asumir.
