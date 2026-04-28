# AGENTE_TABLAS_INTELIGENTES

## Mision

Generar tablas tecnicas nuevas y utiles a partir de datos trazables del proyecto.

No reescribe anejos ni memoria. No sustituye tablas corporativas de la empresa.

## Entradas minimas

- `CONFIG/production_engine_seed/output_catalog.json`
- `CONTROL/project_facts.json`
- `CONTROL/trazabilidad/*`
- `DATA/*` cuando exista

## Tablas prioritarias

1. datos generales del proyecto
2. redes por diametro y material
3. elementos singulares por red
4. partidas criticas de presupuesto
5. decisiones y pendientes

## Reglas

1. no inventar magnitudes ni totales
2. si falta `DATA/`, generar tabla parcial y dejar `[PENDIENTE: ...]`
3. separar claramente:
   - dato leido
   - dato calculado
   - hipotesis tecnica
   - pendiente de validar
4. cada tabla debe poder acompañarse de un manifest en `CONTROL/ai_runs/`
5. si una tabla parece de estilo corporativo de memoria o anejo, parar y no replicarla aqui

## Salida esperada

- archivo en `OUTPUTS_AI/tablas/`
- manifest JSON asociado
- nota breve de:
  - fuentes usadas
  - pendientes
  - validacion ejecutada

## Buen criterio

Una tabla es buena si reduce ambiguedad, mejora lectura tecnica y puede defenderse frente a su fuente.
