---
name: cierre-anejo
description: Ejecuta el cierre estandar de un anejo del expediente 535.2.1 — checks de mojibake, tablas DOCX, trazabilidad y BC3 — y devuelve un resumen pasa/falla. Invocar cuando el usuario diga que un anejo esta terminado o pida cerrarlo/revisarlo antes de entregar.
---

# cierre-anejo (Plaza Mayor 535.2.1)

Ejecuta en secuencia los checks de cierre sobre el anejo indicado y reporta un resumen
compacto pasa/falla por cada control. **No corregir nada** — solo reportar.

## Argumentos

- `num_anejo` (opcional): numero o nombre del anejo a cerrar (ej. "13", "anejo-13", "Control de Calidad").
- Si el usuario no indica anejo, listar los anejos modificados hoy en `DOCS - ANEJOS/` y preguntar cual cerrar.

## Pasos

Trabajar siempre desde la raiz del proyecto: `C:\Users\USUARIO\Documents\Claude\Projects\535.2.1 - Proyecto de Urbanizacion - Ampliacion Plaza Mayor`.

### 1. Mojibake check sobre Office (DOCX/XLSX)

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_office_mojibake.ps1
```

Si hay secuencias prohibidas (`Ã`, `Â`, `â€"`, `â€œ`, `Ã'`, `Ã"`, etc.), reportar las apariciones por fichero. Esto **debe pasar** antes de declarar cierre OK.

### 2. Tablas DOCX consistentes

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1
```

Reportar tablas vacias, ocultas, desalineadas o sin numeracion `Tabla N. Descripcion`.

### 3. Trazabilidad cruzada

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_traceability_consistency.ps1
```

Reportar incoherencias entre Word, Excel y BC3 del anejo.

### 4. Integridad BC3

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_bc3_integrity.ps1
```

Reportar partidas sin descomposicion, precios desajustados, conceptos huerfanos.

## Resumen final

Tabla compacta con 4 filas:

| Check | Resultado | Errores criticos | Avisos |
|---|---|---|---|
| mojibake | OK / FALLO | n | n |
| tablas DOCX | OK / FALLO | n | n |
| trazabilidad | OK / FALLO | n | n |
| BC3 integridad | OK / FALLO | n | n |

Si **cualquier** check tiene errores criticos: declarar **CIERRE NO OK** y listar concretamente que arreglar antes de entregar el anejo.

Si todos OK: declarar **CIERRE OK — listo para entregar**.

## Notas

- Esta skill **no modifica nada**. Solo reporta.
- Si algun script de los 4 no existe en `tools/`, indicarlo y continuar con los demas (no abortar).
- Salida pensada para copiar en `DOCS/Registros/cierre-anejo-{num}-YYYY-MM-DD.md`.
