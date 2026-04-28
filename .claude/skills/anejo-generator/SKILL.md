---
name: anejo-generator
description: Genera borradores de anejos técnicos de proyectos de obra civil en España a partir de datos del Excel y plantillas del proyecto. Úsala cuando el usuario diga "genera el anejo", "redacta el anejo", "borrador del anejo", "escribe la memoria", "anejo de control de calidad", "anejo de mediciones".
---

# Skill: Generador de Anejos Técnicos

## Cuándo usar esta skill

Cuando el usuario necesite:
- Generar o actualizar el borrador de un anejo técnico a partir de datos del Excel
- Redactar la parte textual de un anejo con los datos ya calculados
- Actualizar un anejo existente con nuevos valores
- Crear la estructura documental de un anejo desde cero

Palabras clave: "genera el anejo", "redacta el anejo", "actualiza el Word", "borrador", "memoria técnica", "anejo número X".

---

## Proceso

### Paso 1 — Identificar qué anejo generar

Pregunta al usuario (si no lo especifica):
- ¿Qué anejo? (control de calidad, justificación de precios, mediciones, estudio de seguridad, etc.)
- ¿Hay una plantilla existente (.docx) o hay que partir de cero?
- ¿Hay datos en Excel que poblar el anejo?

### Paso 2 — Leer la plantilla o estructura existente

Si hay .docx existente: desempaquetarlo con `scripts/office/unpack.py` y leer la estructura (capítulos, tablas, índice).
Si no hay plantilla: usar la estructura estándar del tipo de anejo (ver referencias más abajo).

#### Comandos de unpack.py

```bash
# Estructura completa en JSON (por defecto) — parseable por el LLM
python3 scripts/office/unpack.py anejo.docx

# Solo esquema de capítulos + estadísticas (output reducido, más rápido)
python3 scripts/office/unpack.py anejo.docx --outline-only

# Texto legible para revisión humana
python3 scripts/office/unpack.py anejo.docx --format=text
```

El JSON devuelve:
- `outline` — lista de encabezados `{level, style, text}` (Heading 1/2/3…)
- `tables` — cada tabla con `{rows, cols, header_row}`
- `images` — imágenes embebidas `{filename, size_bytes}`
- `styles_used` — estilos presentes y frecuencia
- `stats` — párrafos, palabras, páginas estimadas, conteos
- `properties` — título, autor, fechas de creación/modificación
- `sections` — orientación y tamaño de página por sección

Código de salida 0 = OK, 1 = error (stderr contiene JSON `{error: ...}`).

### Paso 3 — Extraer datos del Excel

⚠ **REGLA ABSOLUTA: nunca leer los valores numéricos del Excel directamente con el LLM.**
Los Excel del proyecto tienen 79-85 rangos combinados. El LLM inventa valores, confunde filas
y pierde decimales sin avisar. Usar SIEMPRE `tools/excel_tools.py`:

```bash
# Ver qué hojas tiene el Excel
python3 tools/excel_tools.py sheets archivo.xlsx

# Exportar la hoja a CSV con valores exactos
python3 tools/excel_tools.py read archivo.xlsx "NOMBRE_HOJA" --output=datos.csv

# Buscar un código o descripción específica
python3 tools/excel_tools.py find archivo.xlsx "E01.01"
```

El CSV resultante tiene separador `;` y codificación UTF-8 BOM — se puede abrir en Excel
para verificar. El LLM entonces trabaja sobre el CSV (texto plano), no sobre el .xlsx.

Leer el CSV para identificar:
- Tablas de ensayos o partidas
- Totales e importes
- Mediciones
- Cualquier dato que deba aparecer en el anejo

### Paso 4 — Generar el documento

Usar la skill `docx` para:
- Mantener el formato y estilos del documento original
- Poblar las tablas con los datos del Excel
- Redactar los párrafos de texto técnico con los valores correctos
- Actualizar los totales y resúmenes

Guardar como `[nombre-anejo] ACTUALIZADO.docx` en la carpeta del proyecto.

### Paso 5 — Verificación

Antes de entregar, verificar:
- Los totales del Word coinciden con los del Excel
- No hay celdas vacías donde debería haber datos
- La numeración de capítulos es correcta
- Los códigos de partida o referencia están correctamente trasladados

---

## Estructura estándar por tipo de anejo

### Anejo de Control de Calidad
1. Introducción y objeto
2. Normativa de referencia
3. Organización del control
4. Plan de ensayos por capítulos de obra
   - Movimiento de tierras
   - Firmes y pavimentos
   - Obras de drenaje
   - Señalización y balizamiento
5. Presupuesto del control de calidad
6. Conclusión

### Anejo de Justificación de Precios
1. Introducción
2. Mano de obra
3. Maquinaria
4. Materiales
5. Precios auxiliares
6. Precios unitarios descompuestos

### Anejo de Mediciones
Estructura según capítulos del presupuesto. Para cada partida:
- Código y descripción
- Descripción de la medición (con fórmulas de cálculo)
- Parciales y total

---

## Gotchas

- Al actualizar un .docx existente, usar siempre la skill `docx` con el método unpack → edit XML → pack para preservar estilos
- No regenerar el documento completo si solo cambian algunas celdas — editar las celdas específicas
- Los anejos de proyecto tienen numeración fija (Anejo 1, Anejo 2...) — respetar la numeración existente del expediente
- Los valores monetarios en anejos españoles usan punto de miles y coma decimal: 17.958,00 €
- Guardar siempre con sufijo "ACTUALIZADO" hasta que el usuario confirme que es la versión definitiva
