# Plantilla Base de Proyecto

Esta carpeta es la base reutilizable para arrancar nuevos proyectos con el mismo metodo de trabajo.

## Contenido

- `ESTANDARES.md`: reglas de nombres, estructura y control documental.
- `AGENTS.md`: reglas operativas de agentes, cierres y controles obligatorios.
- `PLANTILLA_ORDEN_TRABAJO.md`: formato corto para pedir tareas sin ambiguedad.
- `CHECKLISTS/`: flujo operativo repetible (inicio, control de calidad y cierre).
- `DOCS/Plantillas/`: plantillas documentales reutilizables.
- `.github/`: plantillas de issues y PR para trabajar con GitHub sin perder controles de calidad.
- `PLANOS/`, `PLANNING/`, `PRESUPUESTO/`: estructura minima estandar.
- `scripts/` y `tools/`: automatizaciones y utilidades heredadas del sistema comun.
- `CONFIG/proyecto.template.json`: datos base del nuevo expediente.
- `CONFIG/bootstrap.copy-manifest.json`: seleccion curada de rutas que si se copian en el arranque.
- `CONFIG/trazabilidad_profiles.json`: perfiles de documentos oficiales para revision de trazabilidad.

## Como se crea ahora un proyecto nuevo

El arranque ya no debe copiar toda la plantilla a ciegas.

- `scripts/iniciar_proyecto_estandar.ps1` lee `CONFIG/bootstrap.copy-manifest.json`.
- Solo se copian rutas curadas y reutilizables.
- Quedan fuera artefactos de referencia, temporales y piezas demasiado especificas del proyecto origen.

Esto permite mantener `00_PLANTILLA_BASE` como base de trabajo viva sin contaminar automaticamente cada expediente nuevo.

## Estandarizacion operativa incluida

La plantilla base ya incorpora controles listos para usar en proyectos nuevos:

- Anti-mojibake Office: `tools/check_office_mojibake.ps1`
- Integridad BC3: `tools/check_bc3_integrity.ps1`
- Trazabilidad transversal y por perfil: `tools/check_traceability_consistency.ps1`, `tools/run_traceability_profile.ps1`
- Guardas de formulas Excel: `tools/check_excel_formula_guard.ps1`
- Estilo seguro de Excel (sin perder formulas): `tools/excel_style_safe.ps1`
- Coherencia DOCX de tablas/captions/fuente: `tools/check_docx_tables_consistency.ps1`
- Autofix de captions de tablas en DOCX: `tools/autofix_docx_captions.ps1`
- Cierre mixto completo: `tools/run_project_closeout.ps1`

## Tokens de personalizacion

Los siguientes tokens se sustituyen automaticamente al crear un proyecto nuevo:

- `535.2.1`
- `Proyecto de Urbanizacion - Ampliacion Plaza Mayor`
- `PENDIENTE`
- `2026-04-15`
- `535.2.1 - Proyecto de Urbanizacion - Ampliacion Plaza Mayor`
- `obra-535-2-1-proyecto-de-urbanizacion-ampliacion-plaza-mayor`
- `535.2.1 - Proyecto de Urbanizacion - Ampliacion Plaza Mayor`

