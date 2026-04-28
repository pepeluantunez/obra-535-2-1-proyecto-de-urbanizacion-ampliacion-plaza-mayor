---
name: biblioteca-anejos-trazables
description: Usa esta skill cuando el usuario quiera convertir la trazabilidad DOCX/XLSX de Guadalmar en plantillas reutilizables por anejo o por familia para proyectos futuros, sin tocar primero los anejos vivos.
---

# Skill: Biblioteca de Anejos Trazables

Usa esta skill cuando el encargo sea del tipo:

- "esto se repite en muchos proyectos"
- "haz plantillas por anejo"
- "quiero reutilizar Guadalmar"
- "mapea DOCX y Excel donor para futuros proyectos"
- "no adaptes a mano, deja un sistema"

## Regla base

No empieces editando anejos vivos si el problema real es de arquitectura documental.

Primero crea o actualiza la biblioteca reusable:

1. Revisa `CONFIG/annex_template_profiles.json`.
2. Ejecuta `tools/analyze_annex_template_profiles.ps1` para confirmar donors, apartados, tablas y Excels.
3. Ejecuta `tools/build_annex_template_library.ps1` para materializar paquetes por anejo en `DOCS - ANEJOS/Plantillas/Por Anejo`.
4. Usa esos paquetes como base para futuros proyectos o para preparar una derivacion fiel a la plantilla maestra.

## Como pensar los perfiles

Clasifica cada anejo en una de estas dos categorias:

- `specific_template`: el anejo repite siempre casi la misma estructura, tablas y soporte Excel.
- `family_candidate`: la forma es reusable, pero todavia falta cerrar todos los donors auxiliares.

## Que debe contener cada perfil

- DOCX donor principal
- Excel donor asociado, si existe
- soportes auxiliares de trazabilidad (`csv`, `xls`, scripts, `xml`, etc.)
- lista de inputs variables del proyecto
- familia documental

## Criterio de calidad

- La plantilla maestra sigue siendo el contrato de cabecera, pie, portada, indice y saltos.
- Guadalmar aporta estructura tecnica y trazabilidad donor.
- No des por hecha una "plantilla final" solo por copiar un DOCX donor: primero deja claro si es paquete donor, plantilla especifica cerrada o familia candidata.

## Cierre minimo

Despues de generar o actualizar la biblioteca:

- ejecutar `tools/check_office_mojibake.ps1` sobre la carpeta creada
- si hay DOCX copiados, ejecutar `tools/check_docx_tables_consistency.ps1`
- si hay Excels copiados, ejecutar `tools/check_excel_formula_guard.ps1`

## Artefactos esperados

- `CONTROL/annex_template_profile_analysis.md`
- `CONTROL/annex_template_library.md`
- `DOCS - ANEJOS/Plantillas/Por Anejo/*/profile.manifest.json`
