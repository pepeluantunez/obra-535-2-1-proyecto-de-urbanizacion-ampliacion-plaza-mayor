# OUTPUT_CATALOG_PREMIUM

Fecha: 2026-04-25
Estado: semilla local

## Objetivo

Definir salidas premium que elevan el nivel tecnico del proyecto sin tocar plantillas corporativas de memoria o anejos.

Cada output premium debe:

1. apoyarse en datos o fuentes trazables;
2. declarar si mezcla `LEIDO`, `CALCULADO`, `HIPOTESIS`, `PENDIENTE` o `PROPUESTA`;
3. poder acompanarse de manifest en `CONTROL/ai_runs/`.

## Tablas premium

### Tabla de datos generales del proyecto

- valor: resume alcance, estado y magnitudes base
- fuentes: `CONTROL/project_facts.json`, `MAPA_PROYECTO.md`, `ESTADO_PROYECTO.md`

### Tabla de redes por diametro y material

- valor: resume la red proyectada de forma defendible
- fuentes: `DATA/redes/*.csv` o fuente tecnica del anejo correspondiente

### Tabla de elementos singulares por red

- valor: aclara pozos, arquetas, imbornales, acometidas y conexiones
- fuentes: `DATA/redes/*.csv`

### Tabla de partidas criticas

- valor: detecta partidas pesadas, fragiles o con trazabilidad debil
- fuentes: `DATA/presupuesto_normalizado.csv`, BC3, coverage de trazabilidad

### Tabla de decisiones y pendientes

- valor: convierte incertidumbre en trabajo accionable
- fuentes: `DECISION_LOG.md`, `ESTADO_PROYECTO.md`

### Matriz memoria-anexos-planos-presupuesto

- valor: hace visible la coherencia transversal
- fuentes: `CONTROL/trazabilidad/*`, `FUENTES_MAESTRAS.md`

## Graficos premium

### PEM por capitulos

- valor: muestra el peso economico relativo
- fuentes: `DATA/presupuesto_normalizado.csv`

### Pareto de partidas principales

- valor: identifica el 80/20 economico
- fuentes: `DATA/presupuesto_normalizado.csv`

### Longitudes por diametro y por material

- valor: da lectura rapida de las redes
- fuentes: `DATA/redes/*.csv`

### Distribucion de residuos

- valor: resume pesos y tipos de residuos
- fuentes: Excel de residuos o `DATA/residuos/*.csv`

### Control de calidad por capitulo

- valor: visualiza reparto de controles y coste
- fuentes: Excel de control de calidad o `DATA/control_calidad/*.csv`

## Plan de obra premium

### Gantt preliminar

- valor: da una programacion defendible
- condicion: marcar toda duracion no confirmada como `HIPOTESIS`

### Curva S de inversion

- valor: vincula tiempo e inversion
- condicion: usar presupuesto vigente y cronograma trazable

### Histograma mensual de inversion

- valor: facilita lectura de carga economica mensual
- condicion: no generar sin base de presupuesto y fases

### Riesgos de programacion

- valor: anticipa cuellos de botella y dependencias criticas
- condicion: separar riesgo confirmado de supuesto de planificacion

## Direccion tecnica premium

### Informe de incoherencias transversales

- valor: detecta contradicciones entre capas del proyecto
- fuentes: memoria, anejos, planos, presupuesto, plan de obra

### Informe de propuestas de valor anadido

- valor: descubre mejoras profesionales no pedidas expresamente
- fuentes: estado del proyecto, outputs existentes, cobertura de trazabilidad

### Resumen ejecutivo tecnico

- valor: prepara una lectura clara para jefe o cliente
- fuentes: solo datos confirmados o hipotesis claramente marcadas

## Regla corta

Si un output premium no mejora claridad, defendibilidad o capacidad de revision, no entra en este catalogo.
