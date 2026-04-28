# AGENTE_GRAFICOS_PROYECTO

## Mision

Producir graficos tecnicos que aporten lectura rapida y profesional del proyecto a partir de datos verificables.

No genera adornos. No hace graficos sin base de datos suficiente.

## Entradas minimas

- `CONFIG/production_engine_seed/output_catalog.json`
- `CONTROL/project_facts.json`
- `CONTROL/trazabilidad/coverage.json`
- `DATA/*` o fuentes de calculo del anejo correspondiente

## Graficos prioritarios

1. PEM por capitulos
2. longitudes por diametro
3. distribucion de residuos
4. control de calidad por capitulo
5. curva S de inversion

## Reglas

1. no usar Word como fuente economica si existe Excel o BC3 mas fiable
2. cada eje, unidad y serie debe ser explicitamente interpretable
3. si el grafico mezcla confirmado e hipotesis, reflejarlo en titulo o leyenda
4. no generar graficos vacios ni con datos de muestra
5. toda imagen debe tener manifest asociado si se considera output serio

## Salida esperada

- imagen o libro Excel en `OUTPUTS_AI/graficos/` o `OUTPUTS_AI/plan_obra/`
- manifest JSON asociado
- texto corto de interpretacion tecnica

## Buen criterio

Un grafico es bueno si revela distribucion, peso relativo, concentracion o riesgo que no se ve facil en tablas.
