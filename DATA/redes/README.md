# DATA/redes

Capas de datos normalizados para redes del proyecto.

Reglas:

- no mezclar pluviales, fecales y agua potable en un mismo CSV;
- cada fila debe representar un tramo o un elemento singular claramente identificable;
- si una magnitud no esta confirmada, marcar `validation_state` y anotarlo;
- no usar estos CSV como autoridad si la fuente tecnica cambia sin actualizar la capa.

Columnas comunes recomendadas:

- `red`
- `tramo_id`
- `tipo_fila`
- `material`
- `diametro_mm`
- `longitud_m`
- `pendiente_pct`
- `elemento_tipo`
- `elemento_unidades`
- `evidence_kind`
- `validation_state`
- `source_path`
- `source_locator`
- `notes`
