# FUENTES_MAESTRAS - 535.2.1 Plaza Mayor

> Esta hoja fija que documento manda en cada tema y que no debe usarse por defecto.

## Presupuesto y mediciones

| Tema | Fuente maestra | Derivados | No usar por defecto |
| --- | --- | --- | --- |
| BC3 maestro del proyecto | `PRESUPUESTO/535.2.1_maestro.bc3` — 671 conceptos, 0 mediciones (~M). Donor: `535.2.2 - PARTIDAS GERENCIA.bc3`; precio GMU Malaga PRECIOS_V5_18_05_2023. SHA256: 9BD753143AAA4FE68844EB329E21ECBBA2BA03CC6FD4116BC838EA4DB12A8B78 | Tablas de presupuesto, mediciones y resumen PEM | Cualquier BC3 fuera de esta ruta o de una decision expresa |
| Base de precios fuente | GMU Malaga — `PRECIOS_V5_18_05_2023` en `bases-precios-compartidas/` | Codificacion y precios unitarios de todas las partidas | Bases de precios de otros proyectos o versiones anteriores |
| BC3 de Seguridad y Salud | `DOCS - ANEJOS/17.- Seguridad y Salud/PRESUPUESTO_DONOR/535.2.1-Seguridad & Salud.bc3` | Contenido economico del anejo 17 | Su `.bak` salvo recuperacion |
| Mediciones por anejo | El Excel o fuente tecnica vigente del anejo, si existe | Tablas Word del mismo anejo | El Word si discrepa con la fuente de calculo |
| Mediciones auxiliares de obra civil | Anejo 4 y sus fuentes tecnicas asociadas | Futuras lineas `~M` de un BC3 general | Resumenes manuales no trazables |

## Documentacion tecnica

| Tema | Fuente maestra | Derivados | Notas |
| --- | --- | --- | --- |
| Memoria descriptiva | `DOCS - MEMORIA/Memoria descriptiva - Proyecto de Urbanizacion - Ampliacion Plaza Mayor.docx` | Tablas de resumen y referencias cruzadas | Es el documento central de entrega de memoria |
| Plantilla de anejos | `DOCS - ANEJOS/Plantillas/PLANTILLA_MAESTRA_ANEJOS.docx` | Nuevos anejos o regeneraciones controladas | No usar plantillas externas sin justificarlo |
| Plantilla de ESS | `DOCS - ANEJOS/Plantillas/PLANTILLA_MAESTRA_ESS.docx` | Anejo 17 | Solo para SyS |

## Capa de control y trazabilidad

| Tema | Autoridad | Papel |
| --- | --- | --- |
| Red minima de trazabilidad | `CONTROL/trazabilidad/nodes.json`, `CONTROL/trazabilidad/edges.json`, `CONTROL/trazabilidad/coverage.json` | Declara relaciones verificables entre memoria, anejos, Excel, BC3 y salidas de control |
| Inventario de hechos de proyecto | `CONTROL/project_facts.json` | Salida de control derivada; no sustituye a la fuente tecnica |
| Matriz de estado de anejos | `CONTROL/matriz_estado_anejos.json` | Salida de revision; no sustituye a la fuente documental |

## Pliego de condiciones

La raiz contiene tres archivos de pliego propios de Plaza Mayor:

1. `535.2.1_POU_PLIEGO DE CONDICIONES.docx` — version inicial
2. `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO.docx` — refinado intermedio
3. `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx` — borrador mas avanzado (usar para trabajo)

Pliego maestro del ecosistema: `535.2.2_POU_PLIEGO DE CONDICIONES.docx` (Guadalmar) — se adapta para cada proyecto nuevo. El archivo de Guadalmar ha sido retirado de la raiz de este repo a `scratch/`.

Regla operativa:

- Para lectura y edicion de trabajo: `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`.
- Para entrega: no declarar vigente sin confirmacion expresa de JL.

## Jerarquia ante conflicto

1. Fuente tecnica del anejo o Excel de medicion vigente
2. Word vigente del anejo correspondiente
3. Memoria descriptiva
4. BC3 especifico de SyS para el anejo 17
5. Plantillas base

## Regla corta

- Excel o fuente tecnica manda sobre Word.
- Word vigente manda sobre resmenes manuales.
- El BC3 de SyS solo manda en SyS.
- La red de `CONTROL/trazabilidad/` manda sobre matrices manuales cuando haya conflicto sobre una relacion declarada.
- Si un documento esta en este repo pero pertenece a Guadalmar, se ignora y se reubica en cuanto se pueda.
