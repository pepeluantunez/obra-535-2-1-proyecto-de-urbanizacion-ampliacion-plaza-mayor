# BLOQUES_COMUNES - Anejo 7

Fuente donor: `Anexo 7 - Pluviales.docx`

## Bloques

### 3. C?LCULOS HIDROL?GICOS
- Clasificaci?n: `COMUN_FIJO`
- Placeholders: {{NORMATIVA_DRENAJE}}
- Texto base:
  - [sin cuerpo extra?do]

### 3.1. M?todo de c?lculo
- Clasificaci?n: `COMUN_FIJO`
- Placeholders: {{FORMULA_CAUDAL_PUNTA}}
- Texto base:
  - [sin cuerpo extra?do]

### 3.3. Tiempo de concentraci?n
- Clasificaci?n: `COMUN_PARAMETRIZABLE`
- Placeholders: {{TC_SUBCUENCA}}, {{LONGITUD_CAUCE_M}}, {{PENDIENTE_MEDIA}}
- Texto base:
  - [sin cuerpo extra?do]

### b) Factor de Intensidad (Fint)
- Clasificaci?n: `COMUN_PARAMETRIZABLE`
- Placeholders: {{FINT}}, {{FA}}, {{I1_ID}}
- Texto base:
  - De acuerdo con la nueva instrucción IC-5.2 el Factor de intensidad Fint viene fijado por el mayor de los valores de los factores Fa y Fb.
  - Fint= máx (Fa, Fb)
  - Dado que en la cuenca de estudio no existen pluviómetros instalados, el factor Fb no será de aplicación ya que éste se obtiene a partir de la información de las curvas IDF de posibles pluviógrafos ubicados en la cuenca. Así pues, Fint será igual al valor del factor Fa.
  - Fa es el factor equivalente al índice de torrencialidad de las precipitaciones y viene determinado por la siguiente expresión:
  - expresión 5
  - El valor de la razón I1/ Id se toma de la Instrucción 5.2.-IC “Drenaje superficial“ del mapa del índice de Torrencialidad de la península Ibérica (fig. 2.4). Así pues, el municipio de Marbella se encuentra ubicado próximo a franja 9, con lo que adoptamos este valor del cociente I1/Id.
  - Considerando t igual al tiempo de concentración (tc apartado anterior) y sustituyendo valores en la expresión 5, Fa toma el siguiente valor:
  - Subcuenca A Fint = Fa = 13,206
  - Subcuenca B Fint = Fa = 8,844
  - Como resultado y volviendo a la expresión 3 expuesta al inicio del presente apartado, la intensidad de precipitación I(T,tc) toma los valores siguientes para el periodo de retorno considerados en cada subcuenca:
  - Periodo de retorno T=25
  - Subcuenca A I(T,tc) = 75,10 mm/h
  - Subcuenca B I(T,tc) = 50,29 mm/h
  - Coeficiente de escorrentía
  - El coeficiente C de escorrentía define la proporción de la componente superficial de la precipitación, depende de la razón entre la precipitación diaria Pd y el umbral de escorrentía P0 a través de la siguiente fórmula:
  - expresión 6
  - El valor del umbral de escorrentía P0 representa la precipitación mínima que debe caer sobre la cuenca para que se inicie la generación de escorrentía y viene determinado por la formula siguiente:
  - P0 = P0i x β expresión 7
  - Donde:
  - P0i es el valor inicial del umbral de escorrentía
  - β coeficiente corrector del umbral de escorrentía
