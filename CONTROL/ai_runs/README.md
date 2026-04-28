# CONTROL/ai_runs

Carpeta reservada para manifests y registros de ejecucion de salidas tecnicas generadas.

Uso minimo:

- guardar un manifest JSON por output relevante;
- guardar handoffs compartidos en `handoffs/` cuando haya relevo entre agentes;
- nombrar el archivo con fecha y tipo de salida;
- no usar esta carpeta como almacen de documentos finales.

Convencion recomendada:

- `YYYY-MM-DD__tipo-output__nombre-corto.manifest.json`

Ejemplos:

- `2026-04-25__plan-obra__gantt-preliminar.manifest.json`
- `2026-04-25__graficos__pem-por-capitulos.manifest.json`

Regla local de semilla:

- mientras `production_engine` no viva en `urbanizacion-toolkit`, esta carpeta actua como banco de pruebas controlado;
- cualquier semantica reusable validada aqui debe promoverse despues a la capa comun, no quedarse como autoridad final de proyecto.
