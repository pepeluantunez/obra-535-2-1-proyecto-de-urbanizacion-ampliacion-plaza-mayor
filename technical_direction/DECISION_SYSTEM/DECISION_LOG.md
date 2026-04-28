# DECISION_LOG

Fecha de apertura: 2026-04-25
Estado: semilla local

## Objetivo

Registrar decisiones tecnicas y administrativas abiertas o ya tomadas que afecten a coherencia, entregables o produccion premium.

## Regla de uso

- no registrar conversaciones triviales;
- cada decision debe indicar a que capas afecta;
- si sigue abierta, debe reflejarse tambien en outputs y revisiones cuando proceda.

## Decisiones activas

| ID | Decision | Estado | Responsable | Afecta a | Urgencia | Nota |
| --- | --- | --- | --- | --- | --- | --- |
| D-001 | Confirmar BC3 maestro general del proyecto | Pendiente | Pendiente | `FUENTES_MAESTRAS.md`, presupuesto, trazabilidad, outputs premium economicos | Alta | Hoy solo existe BC3 activo de SyS |
| D-002 | Resolver vigencia del pliego de Plaza Mayor y retirar duplicados de raiz | Pendiente | JL | pliego, raiz del repo, fuentes maestras | Media | `FUENTES_MAESTRAS.md` documenta varias versiones sin cierre |
| D-003 | Reclasificar o cerrar el estado de anejos 9, 10, 11 y 18 | Pendiente | Pendiente | `ESTADO_PROYECTO.md`, `CONTROL/trazabilidad/*`, revision de alcance | Alta | Hay conflicto entre inventario antiguo y estado operativo actual |
| D-004 | Definir si se activa capa `DATA/` para redes y presupuesto antes de generar graficos premium | En revision | Codex | `OUTPUTS_AI/`, `technical_direction/`, production engine | Alta | Ya existe esqueleto `DATA/`; falta poblarlo con datos trazables reales |
| D-005 | Fijar criterio de uso de outputs premium en revisiones internas | En revision | Pendiente | `technical_direction/OUTPUT_CATALOG_PREMIUM.md`, `CONTROL/ai_runs/` | Media | Falta decidir cuales son obligatorios y cuales solo recomendables |
| D-006 | Validar si los Excel de residuos, control de calidad y dimensionado SyS contienen arrastre de Guadalmar o solo nomenclatura donor | Pendiente | Pendiente | `DATA/`, outputs premium, revision dura, riesgos de aprobacion | Alta | Se han detectado referencias visibles a Guadalmar en libros del proyecto Plaza Mayor |

## Estados permitidos

- `Pendiente`
- `En revision`
- `Tomada`
- `Descartada`
