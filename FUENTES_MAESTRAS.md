# FUENTES_MAESTRAS - 535.2.1 Plaza Mayor

> Esta hoja fija que documento manda en cada tema y que no debe usarse por defecto.

## Presupuesto y mediciones

| Tema | Fuente maestra | Derivados | No usar por defecto |
| --- | --- | --- | --- |
| BC3 maestro del proyecto | No existe archivo vigente confirmado | Futuras tablas de presupuesto y mediciones | Cualquier BC3 que aparezca fuera de una decision expresa |
| BC3 de Seguridad y Salud | `DOCS - ANEJOS/17.- Seguridad y Salud/PRESUPUESTO_DONOR/535.2.1-Seguridad & Salud.bc3` | Contenido economico del anejo 17 | Su `.bak` salvo recuperacion |
| Mediciones por anejo | El Excel o fuente tecnica vigente del anejo, si existe | Tablas Word del mismo anejo | El Word si discrepa con la fuente de calculo |
| Mediciones auxiliares de obra civil | Anejo 4 y sus fuentes tecnicas asociadas | Futuras lineas `~M` de un BC3 general | Resumenes manuales no trazables |

## Documentacion tecnica

| Tema | Fuente maestra | Derivados | Notas |
| --- | --- | --- | --- |
| Memoria descriptiva | `DOCS - MEMORIA/Memoria descriptiva - Proyecto de Urbanizacion - Ampliacion Plaza Mayor.docx` | Tablas de resumen y referencias cruzadas | Es el documento central de entrega de memoria |
| Plantilla de anejos | `DOCS - ANEJOS/Plantillas/PLANTILLA_MAESTRA_ANEJOS.docx` | Nuevos anejos o regeneraciones controladas | No usar plantillas externas sin justificarlo |
| Plantilla de ESS | `DOCS - ANEJOS/Plantillas/PLANTILLA_MAESTRA_ESS.docx` | Anejo 17 | Solo para SyS |

## Pliego de condiciones

La raiz contiene cuatro archivos relacionados con pliego:

1. `535.2.1_POU_PLIEGO DE CONDICIONES.docx`
2. `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO.docx`
3. `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`
4. `535.2.2_POU_PLIEGO DE CONDICIONES.docx`

Regla operativa hasta aclarar la vigencia:

- No existe un pliego unico cerrado y confirmado.
- Para lectura de trabajo, el borrador mas avanzado es `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`.
- Para entrega, no dar por vigente ningun pliego sin confirmacion expresa.
- `535.2.2_POU_PLIEGO DE CONDICIONES.docx` no pertenece a Plaza Mayor y no debe usarse aqui.

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
- Si un documento esta en este repo pero pertenece a Guadalmar, se ignora y se reubica en cuanto se pueda.
