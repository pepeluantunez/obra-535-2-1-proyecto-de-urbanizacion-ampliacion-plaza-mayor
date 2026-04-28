# DATA

Esta carpeta contiene capas de datos normalizados para outputs tecnicos y revision de coherencia.

No sustituye a la fuente maestra.

Su funcion es:

1. concentrar datos reutilizables por agentes y scripts;
2. separar dato leido, dato calculado e hipotesis de forma limpia;
3. permitir graficos, tablas, dashboards y plan de obra sin releer DOCX a ciegas.

Reglas:

- si un dato viene de Word pero existe Excel o BC3 mas fiable, prevalece la fuente tecnica;
- no rellenar estas capas con datos inventados;
- si una fila no puede cerrarse, dejarla pendiente y documentarlo en el manifest o decision log;
- estos CSV son capas de trabajo y deben mantenerse legibles.

Archivos semilla iniciales:

- `presupuesto_normalizado.csv`
- `cronograma_base.csv`
- `redes/agua_potable.csv`
- `redes/pluviales.csv`
- `redes/fecales.csv`
