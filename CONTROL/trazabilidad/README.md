# Trazabilidad Real - 535.2.1 Plaza Mayor

Esta carpeta deja una red minima y verificable de trazabilidad local.

## Capas

- `nodes.json`: artefactos rastreables del proyecto.
- `edges.json`: relaciones explicitadas entre esos artefactos.
- `coverage.json`: metricas agregadas y huecos conocidos.

## Regla de autoridad

- La fuente documental o tecnica sigue mandando en su capa original.
- Estos JSON no sustituyen a la fuente; la describen y conectan.
- Las matrices e informes de `CONTROL/` son presentacion o salida de control, no autoridad maestra.

## Alcance actual

La semilla actual cubre:

- memoria principal
- anejos DOCX
- Excel fuente detectados
- BC3 localizado
- salidas de control que ya resumen o comprueban el proyecto

Lo que aun no cubre con detalle:

- secciones internas de memoria
- tablas Word individuales
- conceptos BC3 a nivel de partida

## Regla de austeridad

Si una relacion no puede justificarse de forma razonable, se deja fuera o se marca `needs_review`.
