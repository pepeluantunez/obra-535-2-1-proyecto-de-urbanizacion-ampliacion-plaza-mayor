# TRIAGE - Selector minimo de tarea

> Este triage es obligatorio antes de abrir medio repo sin necesidad.

## Paso 1. Identificar el tipo de tarea

Elegir una sola categoria principal:

- maquetacion DOCX
- Excel a Word
- auditoria BC3
- trazabilidad documental
- revision civil
- limpieza de mojibake
- actualizacion de memoria del proyecto
- cierre de entrega
- auditoria global

## Paso 2. Fijar el objetivo exacto

Redactar una sola frase:

`Objetivo: actualizar X para conseguir Y sin tocar Z`

## Paso 3. Delimitar lectura

Completar siempre este bloque antes de profundizar:

```text
Tipo de tarea:
Objetivo exacto:
Archivos a leer:
Archivos a ignorar:
Dependencias minimas:
Modo de trabajo:
Salida esperada:
```

## Paso 4. Elegir modo de trabajo

- `triage`: solo estructura, archivos maestros y rutas clave.
- `focalizado`: leer solo los archivos implicados en el cambio.
- `global`: usar solo cuando la tarea sea una auditoria o cierre transversal.

## Paso 5. Reglas de corte

- Si la lista `Archivos a leer` supera 5 rutas sin justificarlo, parar y reducir.
- Si la tarea mezcla proyecto, plantilla y toolkit, separar primero por capa.
- Si el objetivo no identifica una salida concreta, no empezar aun.
- Si hay versiones duplicadas o conflicto de vigencia, consultar `FUENTES_MAESTRAS.md` antes de editar.

## Plantilla rapida

```text
Tipo de tarea: actualizacion de memoria del proyecto
Objetivo exacto: aclarar que archivo manda y que archivos sobran en raiz
Archivos a leer: MAPA_PROYECTO.md, FUENTES_MAESTRAS.md, ESTADO_PROYECTO.md, listado de raiz
Archivos a ignorar: scratch, _archive, DOCX tecnicos no afectados
Dependencias minimas: AGENTS.md, estructura de carpetas, rutas reales
Modo de trabajo: focalizado
Salida esperada: archivos maestros corregidos y diagnostico corto
```
