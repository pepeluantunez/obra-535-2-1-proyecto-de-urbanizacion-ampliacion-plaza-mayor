# Mapa de Adaptacion del Pliego de Condiciones

Base revisada:
- `C:\Users\USUARIO\Documents\Claude\Projects\535.2.1 - Proyecto de Urbanizacion - Ampliacion Plaza Mayor\535.2.2_POU_PLIEGO DE CONDICIONES.docx`

Plantilla maestra copiada:
- `C:\Users\USUARIO\Documents\Claude\Projects\535.2.1 - Proyecto de Urbanizacion - Ampliacion Plaza Mayor\DOCS - PLANTILLAS\PLIEGO DE CONDICIONES\PLANTILLA_PLIEGO_CONDICIONES_BASE.docx`

## Conclusiones de la revision

- El documento base es reutilizable y mantiene una maquetacion valida con tipografia Montserrat.
- No conviene usar un buscar/reemplazar ciego sobre `Malaga`, porque tambien aparece en promotor, pie corporativo y metadatos.
- Hay referencias duras a Guadalmar en portada, articulado y metadatos del DOCX.
- El pie incluye datos corporativos y el codigo `535.2.2`; debe revisarse si cambia el expediente, pero no debe tocarse a ciegas.

## Campos de sustitucion de alta prioridad

Sustituir o revisar siempre:

1. Portada:
- fecha
- autores
- promotor
- titulo del proyecto
- municipio

2. Cuerpo:
- `PROYECTO ORDINARIO DE URBANIZACION DE MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA`
- `Proyecto Ordinario de Urbanizacion de Mejora de la Carretera de Guadalmar, Malaga`
- la frase de alcance que menciona `la mejora de la Carretera de Guadalmar y su entorno urbano inmediato`

3. Metadatos OOXML:
- `dc:title`
- `dc:subject`

4. Pie:
- codigo de expediente `535.2.2`
- comprobar si deben mantenerse o no los datos corporativos de EDP

## Zonas sensibles que requieren criterio tecnico

- Articulo 101.7 de normativa general: revisar normas municipales, companias suministradoras y normativa sectorial del nuevo ambito.
- Articulo 102 de descripcion de las obras: reescribir el parrafo de alcance para el nuevo proyecto, no dejarlo heredado.
- Capitulos 698, 699, 704 y 705: tratarlos como bloques condicionales segun haya alumbrado, riego, telecomunicaciones o electricidad propios.
- Capitulo 3.5 de riego: mantenerlo solo si el nuevo proyecto incluye red de riego o zonas verdes; en caso contrario, dejarlo expresamente como bloque condicional o eliminarlo en la version final.
- Cualquier referencia a EMASA, telecomunicaciones, alumbrado o agua regenerada debe contrastarse con el alcance real del proyecto.

## Cadenas que NO deben reemplazarse de forma global

- `Malaga` cuando forme parte de razon social, direcciones o pie corporativo
- telefonos, email y web del pie
- referencias normativas generales si siguen siendo validas

## Flujo recomendado

1. Duplicar la plantilla base.
2. Rellenar `CONFIG\pliego_condiciones.template.json`.
3. Si se quiere automatizar el primer pase, ejecutar:
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\adapt_pliego_condiciones.ps1 -SourceDocPath ".\DOCS - PLANTILLAS\PLIEGO DE CONDICIONES\PLANTILLA_PLIEGO_CONDICIONES_BASE.docx" -DestinationDocPath ".\<codigo>_POU_PLIEGO DE CONDICIONES.docx" -ConfigPath ".\CONFIG\pliego_condiciones.template.json"`
4. Adaptar portada, metadatos, articulos 100.2 y 102, y cualquier apartado tecnico afectado.
5. Revisar si procede mantener riego, alumbrado, telecomunicaciones y companias concretas.
6. Ejecutar:
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_office_mojibake.ps1 -Paths "<docx>"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1 -Paths "<docx>" -ExpectedFont "Montserrat"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_normativa_scope.ps1 -Paths "<docx_o_carpeta>" -FailOnMissing`
