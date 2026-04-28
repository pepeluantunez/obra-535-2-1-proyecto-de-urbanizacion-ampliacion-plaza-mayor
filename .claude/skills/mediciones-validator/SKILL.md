---
name: mediciones-validator
description: Valida y cruza mediciones de obra civil entre archivos de medición, presupuesto bc3 y Excel. Detecta diferencias de cantidades entre documentos del mismo expediente. Úsala cuando el usuario diga "valida las mediciones", "cruza mediciones", "no cuadra la medición", "diferencia de cantidades", "medición vs presupuesto".
---

# Skill: Validador de Mediciones

## Cuándo usar esta skill

Cuando el usuario necesite:
- Verificar que las mediciones del Excel cuadran con las del presupuesto bc3
- Detectar partidas con diferencias de cantidad entre documentos
- Validar que una medición modificada está actualizada en todos los documentos
- Cruzar el archivo de mediciones con la certificación o el presupuesto

Palabras clave: "valida mediciones", "cruza cantidades", "diferencia medición", "medición vs presupuesto", "no cuadra la cantidad".

---

## Proceso

### Paso 1 — Identificar documentos

Localizar en la carpeta del proyecto:
- Archivos de medición (en subcarpeta MEDICIONES/ si existe): pueden ser .xlsx, .docx, o .bc3
- Presupuesto principal en bc3 (.bc3)
- Excel de seguimiento o certificación (.xlsx)

Si la carpeta MEDICIONES/ está vacía, informar al usuario — es un problema de trazabilidad.

### Paso 2 — Extraer mediciones de cada fuente

**Del bc3:** usar `tools/bc3_tools.py export` para obtener CSV determinista con todos los conceptos y sus mediciones:
```bash
python3 tools/bc3_tools.py export presupuesto.bc3 --output=bc3_datos
# Genera: bc3_datos_export.csv (conceptos) y bc3_datos_descomps.csv (descomposiciones)
```

**Del Excel:** ⚠ nunca leer valores numéricos directamente con el LLM — usar `tools/excel_tools.py`:
```bash
python3 tools/excel_tools.py sheets archivo.xlsx          # ver hojas disponibles
python3 tools/excel_tools.py read archivo.xlsx "HOJA"     # exportar a CSV exacto
python3 tools/excel_tools.py find archivo.xlsx "E01.01"   # localizar código
```
Los Excel del proyecto tienen 79-85 rangos combinados. Sin el script el LLM inventa valores.

**Del archivo de mediciones .docx:** extraer tablas con columnas de parciales, comentario y total.

### Paso 3 — Cruzar por código de partida

Para cada partida identificada por código:
- ¿Existe en todos los documentos?
- ¿La cantidad coincide (tolerancia: ±0,01 para redondeos)?
- ¿La unidad coincide?

### Paso 4 — Informe de validación

```
VALIDACIÓN DE MEDICIONES — [expediente]
Fecha: [hoy]
Documentos cruzados: [lista]

RESUMEN
- Partidas verificadas: X
- Partidas que cuadran: X
- Partidas con diferencia: X
- Partidas sin medición de soporte: X

DIFERENCIAS DETECTADAS
Código    | Descripción              | Unidad | Medición A | Medición B | Diferencia
----------|--------------------------|--------|-----------|-----------|----------
[código]  | [descripción]            | m²     | 1.250,00  | 1.300,00  | -50,00

PARTIDAS SIN SOPORTE EN MEDICIONES/
[lista de partidas que tienen cantidad en presupuesto pero no tienen archivo de medición]
```

### Paso 5 — Recomendación

Si hay diferencias: señalar cuál es la fuente de verdad (por defecto el Excel) y ofrecer actualizar el bc3 o el documento que esté desactualizado.

Si hay partidas sin soporte: recomendar crear los archivos de medición correspondientes en la carpeta MEDICIONES/.

---

## Gotchas

- Las mediciones de movimiento de tierras (desmontes, terraplenes) suelen calcularse por perfiles — la suma de los parciales puede diferir del total por redondeos en cada perfil
- Las mediciones de firmes son en m² de superficie, pero el presupuesto puede expresarlas en t (toneladas) — verificar que la conversión (densidad × espesor × superficie) es correcta antes de flagear como error
- Las partidas alzadas (PA) no tienen medición desglosada por definición — no reportarlas como error de trazabilidad
- La carpeta MEDICIONES/ vacía es un problema real de trazabilidad, no un error del sistema — reportarlo explícitamente
- Los archivos de medición en .docx pueden usar tablas con celdas combinadas — tratar cada fila de subtotal como parcial, no como línea independiente
