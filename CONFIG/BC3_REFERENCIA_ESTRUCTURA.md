# Referencia: Estructura del BC3 del Proyecto

> Basado en el análisis real del archivo `535.2.bc3` del proyecto.
> Usar como guía de referencia al revisar, editar o generar registros BC3.

---

## Registros del formato FIEBDC-3

Cada línea del BC3 empieza con `~X|` donde X es el tipo de registro.
Los campos se separan con `|`. Las listas internas usan `\` como separador.

---

## `~V` — Cabecera del archivo (siempre la primera línea)

```
~V|SOFT S.A.|FIEBDC-3/2002|Presto 8.8||ANSI|
    ^empresa  ^versión       ^programa   ^encoding
```

- Aparece una sola vez al inicio.
- El encoding `ANSI` = CP1252/Latin-1. **Nunca cambiar a UTF-8 sin recodificar todo el archivo.**

---

## `~K` — Configuración de decimales y moneda

```
~K|\2\2\3\2\2\2\2\EUR\|0|
```

- Define los decimales para cada tipo de campo (precios, cantidades, etc.).
- No tocar. Cambiar esto rompe cómo Presto interpreta los valores.

---

## `~C` — Concepto (partida, recurso, capítulo)

```
~C|CODIGO|unidad|resumen|precio|fecha|tipo|
```

| Campo | Posición | Ejemplo real | Notas |
|-------|----------|-------------|-------|
| Código | 1 | `MCG-1.01#` | Identificador único. Puede contener `.`, `-`, `#`, `\` |
| Unidad | 2 | `m`, `m2`, `m3`, `ud`, `h`, `%`, `` (vacío en capítulos) | Vacío en capítulos tipo EA |
| Resumen | 3 | `TUBO DN 300 FC` | Descripción corta (≤256 car.) |
| Precio | 4 | `7.14` | **Punto decimal anglosajón**, nunca coma |
| Fecha | 5 | `260420` | Formato AAMMDD (año 26, abril, 20) |
| Tipo | 6 | `0`, `1`, `2`, `3`, `EA` | Ver tabla abajo |

### Tipos de concepto

| Tipo | Significado | Ejemplo en 535.2 |
|------|-------------|-----------------|
| `0` | Partida de obra | `01.01.01.01`, `RET300FC` |
| `1` | Mano de obra | `A012N100` (Capataz), `A0140000` (Peón) |
| `2` | Maquinaria | Equipos, vehículos |
| `3` | Material / precio auxiliar | `A01JF003` (Mortero), `%CI` |
| `EA` | Capítulo | `MCG-1#`, `MCG-1.01#` |
| `PU` | Precio unitario auxiliar | |
| `PA` | Partida alzada | |

### Estructura de capítulos en este proyecto

```
535.2.2##                          ← Presupuesto raíz
  └── MCG-1#                       ← Capítulo 1 (Red General)
        ├── MCG-1.01#              ← Subcapítulo 1.1
        │     ├── RET300FC        ← Partida de obra
        │     ├── RET250FC
        │     └── ...
        ├── MCG-1.02#              ← Subcapítulo 1.2
        └── ...
```

---

## `~T` — Texto largo (descripción completa de la partida)

```
~T|CODIGO|Descripción extensa que puede contener\nsaltos de línea internos|
```

- Complementa al resumen (~C campo 3) con la descripción técnica completa.
- Los saltos de línea internos van como `\n` (no como salto real del archivo).
- **Si falta el ~T de una partida importante, Presto puede mostrarla sin descripción.**

---

## `~D` — Descomposición (componentes de la partida)

```
~D|CODIGO|comp1\factor\rendimiento\comp2\factor\rendimiento\...\|
```

| Subcampo | Ejemplo | Notas |
|----------|---------|-------|
| Componente | `A012N100` | Código de un recurso (~C tipo 1, 2 o 3) |
| Factor | `1` | Casi siempre 1. Multiplicador de cantidad |
| Rendimiento | `0.337` | Cantidad del componente por unidad de partida |

**Ejemplo real:**
```
~D|0DP010|JAR-MAQ-RETRO\1\0.337\JAR-MAQ-CGR6\1\0.842\JAR-MO-OFJ23\1\0.844\JAR-CD0DP010\1\1\|
         ^código comp.  ^f ^rend  ^código comp.  ^f ^rend  ...
```

**Verificación de precio:**
```
precio ~C = Σ (precio_componente × factor × rendimiento)
```
Si no cuadra con tolerancia > 0,02€ → ejecutar `bc3_tools.py recalc`.

---

## `~M` — Medición (desglose de cantidades)

Esta es la sección **más crítica y más frágil** del BC3. Nunca se modifica sin orden explícita.

### Formato real del proyecto (MCG)

```
~M|CAPITULO\PARTIDA|orden\?\indice\|TOTAL|\descripcion\N\M\A\\\...|
   ^clave            ^posición        ^total  ^lineas de medición
```

**Ejemplo real:**
```
~M|MCG-1.01#\RET300FC|1\1\1\|82|\Según mediciones auxiliares\\\\\\TUB Ø300FC\1\82\\\|
   ^capítulo  ^partida  ^pos  ^82  ^texto descriptivo           ^sublinea: desc\N\M\A
```

**Ejemplo con múltiples sublíneas:**
```
~M|MCG-1.01#\DEM056|1\1\5\|1461|\Red de media tensión\\\\\\Glorieta\1\52\\\\\1\26\\\\\1\20\\\...|
```

### Campos de cada sublínea de medición

```
\descripcion\N\M\A\\\
 ^texto       ^largo ^ancho ^alto (vacíos si no aplican)
```

| Campo | Uso típico | Ejemplo |
|-------|-----------|---------|
| descripción | Texto que identifica el elemento o tramo | `TUB Ø300FC`, `Glorieta` |
| N | Número de unidades o longitud | `82`, `1`, `437` |
| M | Ancho (m²) o segundo factor | vacío en m lineales |
| A | Alto o tercer factor | vacío habitualmente |

### Patrones habituales de descripción en ~M

| Patrón | Cuándo usarlo |
|--------|--------------|
| `Según mediciones auxiliares` | Medición venida de Civil 3D u hoja externa |
| `Según mediciones delineante` | Medición validada por delineante |
| `Segun planos` | Referencia genérica a planos |
| Nombre de tramo (`Glorieta`, `Acerado sur`, `Cruce`) | Desglose por zonas |
| Nombre de sección (`Sección 1.1`) | Desglose por secciones |
| Referencia a fecha/técnico (`ADOQUIN EXISTENTE SEGUN DELINEANTE 09/04/2026`) | Trazabilidad de origen |

### Problemas frecuentes en ~M

| Problema | Síntoma | Cómo detectarlo |
|----------|---------|-----------------|
| Descripción vacía | Sublínea sin texto → valor sin contexto | `bc3_normalize_mediciones.ps1` |
| Total no cuadra | Suma de sublíneas ≠ total declarado | `bc3_normalize_mediciones.ps1` |
| Referencia sin texto | `\1\82\\\` sin descripción previa | `bc3_normalize_mediciones.ps1` |
| Medición duplicada | Mismo tramo contado dos veces | Revisión manual |
| Unidad inconsistente | `m` en ~C pero medición en `m²` | `bc3_tools.py info` |

---

## `~O` — Precios en otras bases (referencia)

```
~O|CODIGO|base1\precio1\base2\precio2\...|
```

- Almacena el precio del concepto en otras bases de precios (Almería 2008, Málaga, etc.).
- Informativo. No afecta al precio activo del ~C.
- **No tocar**, Presto lo gestiona automáticamente.

---

## `~E` — Estructura de capítulos (árbol)

```
~E|COD_RAIZ||C\\\\\\\\\\|\\\|
```

- Define el árbol de capítulos y subcapítulos del presupuesto.
- En este proyecto usa la jerarquía MCG-X.XX#.
- **No editar manualmente** — usar Presto para restructurar capítulos.

---

## `~A` — Texto asociado (notas auxiliares)

```
~A|CODIGO|palabra1\palabra2\...|
```

- Palabras clave o notas asociadas a una partida (usado por algunos sistemas de búsqueda).
- Raramente crítico para el presupuesto.

---

## Orden correcto de registros en el archivo

El orden estándar en el 535.2.bc3 real es:

```
1. ~V   — cabecera (1 vez)
2. ~K   — configuración decimales (1 vez)
3. ~C   — todos los conceptos (recursos, partidas, capítulos mezclados)
4. ~D   — descomposiciones (asociadas a sus ~C)
5. ~T   — textos largos
6. ~O   — precios en otras bases
7. ~M   — mediciones (por capítulo\partida)
8. ~E   — estructura de capítulos
9. ~A   — textos asociados (si los hay)
```

> Presto no es estricto con el orden, pero algunos importadores sí lo son.
> Si se genera un BC3 desde cero, respetar este orden evita problemas.

---

## Convenciones de codificación en este proyecto

| Patrón de código | Tipo | Ejemplo |
|-----------------|------|---------|
| `MCG-X.XX#` | Capítulo/subcapítulo | `MCG-1.01#`, `MCG-1.02#` |
| `MCG-X.XX#\PARTIDA` | Referencia en ~M | `MCG-1.01#\RET300FC` |
| `%6.0CI`, `%CI` | Costes indirectos | `%6.0CI` = 6% CI |
| `A012N100` | Mano de obra (capataz) | estilo BEDEC |
| `A0140000` | Mano de obra (peón) | estilo BEDEC |
| `GR.XX.XX-SD` | Partida de base Pavigesa | `GR.09.22-SD` |
| `DJ-XXX-001` | Partida específica delineante | `DJ-ADOQ-001` |

---

## Comandos de referencia rápida

```powershell
# Ver resumen del BC3: capítulos, n_conceptos, precios desajustados
python3 tools/bc3_tools.py info PRESUPUESTO/535.2.bc3

# Ver ficha completa de una partida
python3 tools/bc3_tools.py show PRESUPUESTO/535.2.bc3 MCG-1.01#

# Exportar a CSV para revisar en Excel
python3 tools/bc3_tools.py export PRESUPUESTO/535.2.bc3

# Detectar inconsistencias en ~M
powershell -NoProfile -ExecutionPolicy Bypass -File tools/bc3_normalize_mediciones.ps1 -Path PRESUPUESTO/535.2.bc3

# Snapshot antes de cualquier cambio
powershell -NoProfile -ExecutionPolicy Bypass -File tools/bc3_snapshot.ps1 -Path PRESUPUESTO/535.2.bc3 -Label "antes-modificacion"

# Comparar dos versiones del BC3
powershell -NoProfile -ExecutionPolicy Bypass -File tools/bc3_diff_report.ps1 -Before scratch/bc3_snapshots/535.2_antes.json -After scratch/bc3_snapshots/535.2_despues.json
```
