# DECISIONES_PROYECTO - 535.2.1 Plaza Mayor

> Decisiones ya tomadas o que deben asumirse como base operativa hasta nueva instruccion.

## Presupuesto y base de precios

- Base de precios fuente del ecosistema: GMU Malaga — `PRECIOS_V5_18_05_2023` (archivo en `bases-precios-compartidas/`).
- Todos los proyectos nuevos deben adaptar sus partidas a esta base. Guadalmar (535.2.2) ya completó la adaptación con PEM 5.108.559,83 EUR.
- BC3 maestro de Plaza Mayor (535.2.1): se crea partiendo de las partidas de Guadalmar (535.2.bc3 / 535.2.2 - PARTIDAS GERENCIA.bc3) como donor de codificacion, con precios de GMU Malaga PRECIOS_V5_18_05_2023 como autoridad de precio unitario. Las mediciones (~M) se van incorporando progresivamente: las de viario y redes desde Civil 3D, otras del delineante. Mismo flujo que se siguio en Guadalmar.
- Este flujo (partidas Guadalmar + GMU + mediciones progresivas Civil 3D / delineante) es el workflow estandar para Plaza Mayor y todos los proyectos futuros del ecosistema.
- El BC3 de SyS (`535.2.1-Seguridad & Salud.bc3`) no es el BC3 maestro; solo gobierna el ambito del anejo 17.

## Pliego de condiciones

- El pliego maestro del ecosistema es `535.2.2_POU_PLIEGO DE CONDICIONES.docx` (Guadalmar), que se edita y adapta para cada proyecto nuevo.
- Para Plaza Mayor, el pliego de trabajo es `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`, adaptado del maestro.
- No declarar ninguna version como vigente de entrega sin confirmacion expresa de JL.
- `535.2.2_POU_PLIEGO DE CONDICIONES.docx` ha sido retirado de la raiz de este repo a `scratch/`.

## Alcance y anejos fuera de scope

- Este repo se centra en obra civil y redes humedas. Ultimo anejo del expediente: 17 (Seguridad y Salud).
- **Anejo 9 — Red de Media Tension**: existe en el expediente, lo redacta un tecnico electrico externo. Sin carpeta ni DOCX en este repo. Estado en trazabilidad: `out_of_scope`.
- **Anejo 10 — Red de Baja Tension**: idem. Tecnico electrico externo. `out_of_scope`.
- **Anejo 11 — Red de Alumbrado**: idem. Tecnico electrico externo. `out_of_scope`.
- **Anejo 18**: no existe en este expediente. Estado en trazabilidad: `does_not_exist`.

## Criterio documental

- Las tablas en Word deben ser tablas reales, no imagenes.
- La tipografia objetivo del proyecto es `Montserrat`.
- Cada tabla tecnica debe quedar contextualizada y con caption del tipo `Tabla N. Descripcion`.
- No rehacer documentos enteros para corregir cambios puntuales si puede evitarse.

## Jerarquia de fuentes

- Si existe Excel o fuente tecnica de medicion para un anejo, esa fuente manda sobre el Word.
- La memoria consolida; no debe imponerse sobre el anejo cuando hay un dato tecnico mas preciso en la fuente del anejo.
- El BC3 de SyS no equivale a un BC3 maestro del proyecto.

## Codificacion y cierre

- Ninguna tarea sobre DOCX, XLSX, XML Office o BC3 se da por cerrada sin control anti-mojibake.
- Si aparece texto corrupto, se rehace la escritura antes de cerrar.
- Las comprobaciones del proyecto tienen prioridad frente a una inspeccion manual superficial.

## Pliego de condiciones

- La raiz esta contaminada por varias versiones del pliego.
- Hasta que JL confirme la version final, no se archiva ni se declara vigente una sola copia de entrega.
- El archivo `535.2.2_POU_PLIEGO DE CONDICIONES.docx` es ajeno al expediente y debe tratarse como error de ubicacion.

## Reglas de consumo y contexto

- No leer todo el repo por defecto.
- Antes de una tarea no trivial, aplicar el bloque de triage resumido de `MAPA_PROYECTO.md`.
- Priorizar cambios focalizados en el archivo afectado frente a auditorias globales.
- No mezclar roles de proyecto vivo, plantilla base y toolkit reutilizable en este repo.
- La autoridad comun de ecosistema debe converger fuera de Plaza Mayor; aqui solo se fijan decisiones locales mientras no exista una capa comun estable.

## Normativa activa

- Se confirma la opcion B para Plaza Mayor (2026-04-30): la autoridad normativa activa es `C:\Users\USUARIO\Documents\Claude\Projects\normativa-obra-civil\catalog.json`.
- No se crea aun `NORMATIVA/` local; esa capa solo se abrira cuando exista curacion propia suficiente del expediente.
- Cualquier cita normativa nueva debe poder trazarse a ese corpus o a una fuente local curada y declarada en `ACTIVE_SOURCES.md`.
