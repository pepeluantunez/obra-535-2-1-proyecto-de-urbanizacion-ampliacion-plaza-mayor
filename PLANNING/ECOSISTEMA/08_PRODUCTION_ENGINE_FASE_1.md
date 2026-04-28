# Production Engine - Fase 1

Fecha: 2026-04-25
Estado: semilla local

## Objetivo

Empezar la profesionalizacion productiva por la base correcta:

1. clasificar cada dato con semantica explicita;
2. exigir manifest de trazabilidad para cada salida tecnica nueva;
3. impedir que futuras tablas, graficos o planes mezclen dato confirmado con hipotesis sin marcar.

## Alcance de esta fase

Esta iteracion no crea aun:

- generadores de plan de obra
- dashboards
- graficos
- exportadores DOCX o XLSX

Esta iteracion si crea:

- contrato semilla de estados del dato
- plantilla de manifest de salida
- checker local de manifests
- carpeta de control para ejecuciones AI

## Archivos semilla

- `CONFIG/production_engine_seed/common_trace_contract.json`
- `CONFIG/production_engine_seed/output_trace_manifest.template.json`
- `CONTROL/ai_runs/README.md`
- `tools/check_output_trace_manifest.ps1`

## Regla de uso

Todo output tecnico nuevo que se quiera considerar profesional debe poder responder:

1. que archivo ha salido
2. con que fuentes entro
3. que parte es dato leido
4. que parte es dato calculado
5. que parte es hipotesis
6. que pendientes quedan
7. que checks minimos se han ejecutado

Si no puede responder eso, no debe venderse como salida tecnica fiable.

## Limite de capa

Esta semilla vive aqui solo para validar el modelo.

Cuando el contrato se estabilice, debe promocionarse a `urbanizacion-toolkit` y la `plantilla` solo debera sembrar:

- `DATA/`
- `OUTPUTS_AI/`
- `CONTROL/ai_runs/`

## Siguiente paso recomendado

Una vez usado este manifest en 2 o 3 outputs reales, crear:

1. `OUTPUT_CATALOG.md`
2. `AGENTE_TABLAS_INTELIGENTES`
3. `AGENTE_GRAFICOS_PROYECTO`
4. normalizadores de `DATA/`

## Mejoras pendientes de alta utilidad

Linea propuesta a incorporar en la siguiente fase:

1. capa `technical_direction/` como oficina tecnica digital;
2. `OUTPUT_CATALOG_PREMIUM.md` para entregables premium y valor anadido;
3. `AGENTE_COHERENCIA_TOTAL.md` para revisar memoria, anejos, planos, presupuesto y plan de obra;
4. `DECISION_LOG.md` para decisiones abiertas del proyecto;
5. `APPROVAL_RISKS.md` para riesgos de cuestionamiento por ayuntamiento, companias o supervision;
6. `delivery_packs/` para packs tipo `urbanizacion_basico` y `urbanizacion_premium`;
7. `anejo_contracts/` con datos minimos, salidas recomendadas y validaciones por anejo;
8. `PROJECT_INTELLIGENCE.md` solo como sintesis derivada, nunca como autoridad paralela.

## Prioridad acordada de implantacion

Para no convertir esta linea en burocracia documental, el orden recomendado queda asi:

1. `OUTPUT_CATALOG_PREMIUM.md`
2. `AGENTE_COHERENCIA_TOTAL.md`
3. `DECISION_LOG.md`
4. `anejo_contracts/`
5. `APPROVAL_RISKS.md`
6. `AGENTE_REVISOR_DURO.md`
7. `PROJECT_INTELLIGENCE.md` derivado
