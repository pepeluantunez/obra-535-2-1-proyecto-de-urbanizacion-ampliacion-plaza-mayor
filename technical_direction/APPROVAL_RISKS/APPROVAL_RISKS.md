# APPROVAL_RISKS

Fecha: 2026-04-25
Estado: semilla local

## Objetivo

Registrar riesgos de aprobacion del expediente antes de entrega o de revisiones internas exigentes.

## Riesgos activos

| ID | Riesgo | Impacto | Probabilidad | Afecta a | Mitigacion |
| --- | --- | --- | --- | --- | --- |
| AR-001 | No existe BC3 maestro general confirmado para el proyecto, lo que limita comparativas y outputs economicos transversales. | Alto | Alta | presupuesto, trazabilidad, outputs premium economicos | mantener visible la limitacion, no vender comparativas globales como cerradas y decidir fuente maestra general |
| AR-002 | El estado operativo actual y el inventario automatizado discrepan en anejos 9, 10, 11 y 18. | Alto | Media | estado del proyecto, coherencia transversal, revisiones internas | reclasificar esos anejos con decision expresa y actualizar inventarios derivados |
| AR-003 | Pluviales sigue en borrador y sin fuente tecnica cerrada para outputs premium hidraulicos. | Alto | Alta | anejo 7, coherencia total, graficos y tablas de red | no generar outputs hidraulicos cerrados sin base y dejar pendientes visibles |
| AR-004 | El pliego en raiz sigue con vigencia no resuelta y con archivo ajeno del expediente Guadalmar mezclado. | Medio | Alta | lectura del repo, revisiones internas, preparacion de entrega | cerrar version vigente y retirar el archivo ajeno de raiz |
| AR-005 | La capa `DATA/` aun no existe para presupuesto y cronograma, lo que limita Gantt, curva S y dashboards serios. | Alto | Alta | plan de obra, dashboards, graficos premium | crear normalizacion minima de datos antes de automatizar outputs avanzados |
| AR-006 | La trazabilidad fuerte hoy cubre mejor residuos, control de calidad y SyS que agua, pluviales y fecales. | Alto | Media | coherencia transversal, revision de redes, salidas premium por red | extender la gramatica de trazabilidad a anejos 6, 7 y 8 |
| AR-007 | Varios libros Excel del proyecto muestran referencias visibles a Guadalmar, lo que puede contaminar outputs si se usan como fuente sin validacion previa. | Alto | Alta | `DATA/`, control de calidad, residuos, SyS, revision dura | revisar libro por libro y no convertir esos datos en confirmados hasta aclarar su vigencia |

## Regla de uso

- no meter aqui riesgos vagos;
- cada riesgo debe apuntar a una capa o salida concreta;
- si un riesgo ya no aplica, moverlo fuera de activos en vez de dejarlo ambiguo.
