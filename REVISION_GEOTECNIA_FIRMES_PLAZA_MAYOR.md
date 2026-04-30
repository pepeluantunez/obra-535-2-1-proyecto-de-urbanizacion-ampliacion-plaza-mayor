# REVISION_GEOTECNIA_FIRMES_PLAZA_MAYOR

## 1. Archivos localizados y analizados
- DOCS - ANEJOS/3.- Estudio Geotecnico/Anexo 3 - Estudio Geotecnico.docx
- DOCS - ANEJOS/5.- Dimensionamiento del firme/Anexo 5 - Dimensionamiento del Firme.docx
- DOCS - ANEJOS/3.- Estudio Geotecnico/6523 Plaza Mayor Shopping.pdf
- DOCS - ANEJOS/3.- Estudio Geotecnico/6863 bis Manzana 8.1 SUNP BM 3.pdf
- DOCS - ANEJOS/3.- Estudio Geotecnico/Proyecto Plaza Mayor incluidas las modificaciones.pdf
- .codex_tmp/guadalmar_ref/Anexo 3 - Estudio Geotécnico.docx (guia estructural)
- .codex_tmp/guadalmar_ref/Anexo 5 - Dimensionamiento del firme.docx (guia estructural)
- DOCS - ANEJOS/3.- Estudio Geotecnico/GPT/Anexo_3_Estudio_Geotecnico_Ampliacion_Plaza_Mayor_REV.docx (apoyo de redaccion)
- DOCS - ANEJOS/3.- Estudio Geotecnico/GPT/Anexo_5_Dimensionamiento_Firme_Ampliacion_Plaza_Mayor_REV.docx (apoyo de redaccion)

## 2. Estructura de Guadalmar usada como guia
- Se mantuvo la logica semantica de bloques de Guadalmar para Geotecnico:
  - introduccion/objeto
  - trabajos y documentacion
  - cartografia-geologia
  - prospecciones (sondeos, penetracion, calicatas)
  - ensayos de laboratorio
  - caracteristicas geologico-geotecnicas
  - estudio de explanada
  - conclusiones
- Se mantuvo la logica semantica de bloques de Guadalmar para Firme:
  - objeto
  - metodologia y marco normativo
  - categoria de trafico
  - explanada
  - firmes (calzada, aceras, carril bici)
  - condiciones de ejecucion/control
  - conclusiones

## 3. Cambios realizados en el Anejo 3
- Redaccion completa tecnica del documento para cierre de entrega.
- Incorporacion de tablas editables de Word (6 tablas):
  - documentacion analizada
  - informacion geotecnica disponible
  - condicionantes geotecnicos
  - explanada mejorada
  - controles minimos
  - datos pendientes
- Integracion de datos del proyecto anterior (zonificacion C1, criterio de sustitucion y necesidad de control de humedad/nivel freatico).
- Incorporacion explicita de la explanada mejorada adoptada: 25 cm, S-2, prestamo, CBR > 20, 95% Proctor Modificado.

## 4. Cambios realizados en el Anejo 5
- Redaccion completa tecnica del dimensionamiento por criterio de continuidad con el proyecto anterior.
- Incorporacion de tablas editables de Word (6 tablas):
  - normativa y criterios aplicables
  - explanada mejorada
  - seccion de firme de referencia
  - justificacion tecnica de capas
  - controles minimos
  - datos pendientes
- Incorporacion exacta de la seccion de firme de referencia para Aparcamiento 1, Aparcamiento 2 y Eje Norte:
  - 5 cm D-12
  - riego de adherencia
  - 9 cm G-25
  - riego de imprimacion
  - 25 cm zahorra artificial
  - 25 cm zahorra natural
  - explanada compactada
- Se mantiene la nomenclatura D-12 y G-25 con nota tecnica de prudencia.

## 5. Datos tecnicos incorporados
- Contexto geotecnico aluvial del ambito Plaza Mayor.
- Referencias a informes geotecnicos historicos del sector (1999, 2002, 2004, 2006) recogidas en la documentacion de partida.
- Dato de nivel freatico local en sondeos SR-1 (2,15 m) y SR-2 (2,27 m) de la documentacion consultada.
- Criterio de continuidad estructural con firme y explanada del proyecto anterior.
- Explanada mejorada de 25 cm S-2 (prestamo), CBR > 20, compactacion 95% Proctor Modificado.

## 6. Datos pendientes
- [PENDIENTE: confirmar categoria de trafico o IMD/IMDp del nuevo viario].
- [PENDIENTE: cierre de seccion definitiva de aceras y confirmacion de carril bici si aplica en alcance final].
- [PENDIENTE: consolidacion de apendices historicos completos para archivo final del Anejo 3].

## 7. Advertencias normativas
- PG-3: aplicado como base para suelos seleccionados, zahorras, riegos y mezclas bituminosas.
- Norma 6.1-IC: usada como referencia tecnica de contraste; no se fuerza categoria T sin IMD/IMDp.
- Norma 6.3-IC: solo como referencia complementaria para encuentros con firme existente cuando proceda.

## 8. Comprobacion de no traslado indebido desde Guadalmar
- Se uso Guadalmar solo como guia de estructura, orden semantico y profundidad tecnica.
- No se trasladaron datos de trafico de Guadalmar.
- No se trasladaron espesores/secciones especificas de Guadalmar.
- En los DOCX finales no aparece la palabra "Guadalmar".

## 9. Comprobacion anti-mojibake
Checks ejecutados:
- `tools/check_office_mojibake.ps1` sobre ambos DOCX finales: **OK**
- `tools/check_docx_tables_consistency.ps1 -ExpectedFont Montserrat -EnforceFont 1 -RequireTableCaption 1`: **OK**
Resultado: sin incidencias de mojibake en los dos archivos finales.

## 10. Lista de archivos finales generados
- DOCS - ANEJOS/3.- Estudio Geotecnico/Anexo 3 - Estudio Geotecnico_REV.docx
- DOCS - ANEJOS/5.- Dimensionamiento del firme/Anexo 5 - Dimensionamiento del Firme_REV.docx
- REVISION_GEOTECNIA_FIRMES_PLAZA_MAYOR.md
