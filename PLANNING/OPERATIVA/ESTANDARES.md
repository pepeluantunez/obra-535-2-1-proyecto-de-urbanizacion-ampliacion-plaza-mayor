# Estandares del Proyecto

## 1) Estructura de carpetas

Todo proyecto nuevo debe mantener esta estructura minima:

- `DOCS/`
- `PLANNING/`
- `PLANOS/01_RefExt`
- `PLANOS/02_CAD`
- `PLANOS/03_PDF`
- `PLANOS/04_CIVIL3D`
- `PLANOS/05_Navisworks`
- `PRESUPUESTO/`
- `ENTREGABLES/`
- `CONTROL_CALIDAD/`
- `scripts/`
- `tools/`

## 2) Convencion de nombres

- Carpeta del proyecto: `CODIGO - NOMBRE`.
- Entregables: `CODIGO_TIPO_DOC_VERSION_FECHA.ext` (ejemplo: `535.2_MEMORIA_V01_2026-04-13.docx`).
- Evitar espacios dobles, nombres ambiguos y sufijos temporales en entregables finales.

## 3) Reglas de trabajo

- No editar directamente originales sin backup previo.
- Registrar cada cambio relevante en `CONTROL_CALIDAD/registro_cambios.md`.
- Mantener una unica version vigente por entregable en `ENTREGABLES/`.

## 4) Revisiones minimas obligatorias

- Revision tecnica de consistencia (memoria, planos y presupuesto).
- Revision de formato (titulos, tablas, indices, numeracion).
- Revision de trazabilidad de partidas criticas.

## 5) Cierre

- Checklist de cierre completo.
- Resumen ejecutivo final en `ENTREGABLES/`.
- Archivar backups intermedios fuera de la carpeta principal del proyecto.
