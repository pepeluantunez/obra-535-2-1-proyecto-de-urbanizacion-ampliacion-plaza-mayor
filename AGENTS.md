# Instrucciones de Proyecto

## Regla critica: control de mojibake y codificacion
- Ninguna tarea sobre DOCX, XLSX, XML Office o BC3 se dara por terminada sin una verificacion explicita final de codificacion y texto corrupto.
- Es obligatorio comprobar que no aparecen secuencias tipo `Ã`, `Â`, `â€“`, `â€œ`, `â€`, `Ã‘`, `Ã“`, `COMPROBACIÃ“N`, `URBANIZACIÃ“N` u otras equivalentes.
- Si se edita un `docx` por XML o script, hay que verificar tanto el XML interno como el resultado visible esperado.
- Si hay duda sobre la codificacion, rehacer la escritura por un metodo que preserve UTF-8/Office XML antes de cerrar la tarea.

## Regla critica: BC3 y presupuesto
- No crear ni dejar partidas a medias.
- Toda partida nueva o modificada debe quedar con codigo, nombre, descripcion, unidad, descompuesto, recursos enlazados, medicion y precio coherentes.
- No dejar textos como `PRECIO PENDIENTE`, conceptos huerfanos, recursos sin precio ni mediciones mal arrastradas.
- Tras tocar un BC3, comprobar siempre las lineas `~C`, `~D`, `~T` y `~M` afectadas.

## Regla critica: documentos de pluviales
- En anejos y tablas de pluviales no rehacer documentos enteros si no hace falta; tocar solo lo necesario.
- Mantener estilo, estructura y redaccion original salvo correccion necesaria.
- Si se actualizan resultados SSA, contrastar las tablas contra la fuente y hacer control cruzado final para que no queden valores antiguos.

## Regla critica: Excel profesional y formulas
- En ficheros `XLSX` y `XLSM`, cualquier estandarizacion o maquetado debe preservar formulas. No se aceptan sustituciones silenciosas de formulas por valores.
- Si se estandariza un Excel existente, ejecutar control de formulas antes y despues con `tools\check_excel_formula_guard.ps1`.
- Si se crea un Excel nuevo para mediciones o trazabilidad, partir de plantilla o estructura profesional del proyecto, mantener tipografia `Montserrat` y dejar hojas legibles para impresion y revision.
- Cualquier ajuste de formato debe respetar celdas calculadas, rangos de formulas y referencias cruzadas.

## Regla critica: DOCX tablas y coherencia visual
- Las tablas en `DOCX` deben quedar visibles, legibles y coherentes con el texto del anejo. No se admite tabla vacia, oculta o desalineada respecto al contenido.
- En contenido nuevo o normalizado se usara tipografia `Montserrat` de forma consistente, salvo excepcion tecnica justificada.
- Tras editar tablas de Word, ejecutar control de tabla visible y tipografia con `tools\check_docx_tables_consistency.ps1`.
- Toda tabla tecnica en anejos debe llevar numeracion y descripcion en el parrafo de referencia, con formato equivalente a `Tabla N. Descripcion`.

## Regla critica: maquetacion profesional integral
- Mantener una linea grafica unica en el documento tecnico: tipografia `Montserrat`, jerarquia de titulos estable y espaciados consistentes.
- Verificar que cada tabla quede contextualizada en el texto: llamada previa o posterior, titulo claro y unidades coherentes.
- Evitar incongruencias visuales: cabeceras partidas, tablas fuera de margen, textos truncados o filas sin contenido util.
- Mantener consistencia de unidades y precision numerica entre texto, tabla, medicion y presupuesto.
- En documentos largos de anejos, no dar por cerrada una maquetacion sin una pasada final de legibilidad completa.

## Cierre obligatorio de cada tarea documental
- Segunda pasada final de control cruzado.
- Verificacion de coherencia entre calculo, tablas, mediciones y presupuesto.
- Verificacion final anti-mojibake antes de responder al usuario.

## Enrutado automatico por tipo de tarea
- Si la tarea afecta `DOCX`, `DOCM`, `XLSX`, `XLSM`, `PPTX`, `PPTM` o XML Office: usar carril documental. Primero se edita solo lo necesario, despues se revisa el contenido modificado y al final se ejecuta una verificacion anti-mojibake del contenedor Office y del texto visible esperado cuando aplique.
- Si la tarea se pide como `maquetacion`: usar carril de maquetacion profesional. Incluye consistencia visual, tipografia `Montserrat`, control de tablas visibles en Word y control de preservacion de formulas en Excel.
- Si la tarea afecta `BC3`, `PZH` o presupuesto: usar carril BC3. Primero se modifica la partida o estructura necesaria, despues se revisan las lineas afectadas `~C`, `~D`, `~T`, `~M`, y al final se ejecuta control de integridad y mojibake.
- Si la tarea afecta pluviales, SSA o tablas derivadas: usar carril pluviales. Tocar solo el tramo o tabla necesaria, contrastar contra la fuente y cerrar con comprobacion cruzada contra mediciones y presupuesto si hay arrastre.
- Si la tarea mezcla varias capas: actuar como coordinador. Separar primero que parte es documental, que parte es BC3 y que parte es trazabilidad, y cerrar cada una con su control especifico antes de responder.

## Protocolo de ahorro de uso
- No replantear el flujo entero en cada encargo. Clasificar la tarea en su carril y ejecutar el mismo cierre minimo obligatorio.
- Priorizar scripts y checklists del proyecto para tareas pequenas y repetitivas antes de hacer una revision libre larga.
- Para Office usar `tools\check_office_mojibake.ps1`.
- Para BC3 usar `tools\check_bc3_integrity.ps1`.
- Para formulas de Excel usar `tools\check_excel_formula_guard.ps1`.
- Para estandarizar Excel sin perder formulas usar `tools\excel_style_safe.ps1`.
- Para tablas y tipografia de DOCX usar `tools\check_docx_tables_consistency.ps1`.
- Para insertar captions de tablas en DOCX usar `tools\autofix_docx_captions.ps1`.
- Para trazabilidad transversal usar `tools\check_traceability_consistency.ps1`.
- Para trazabilidad por conjunto oficial de documentos usar `tools\run_traceability_profile.ps1` con perfiles en `CONFIG\trazabilidad_profiles.json`.
- Para revision normativa rapida usar `tools\check_normativa_scope.ps1`.
- Para cierres mixtos o rapidos usar `tools\run_project_closeout.ps1`.
- Para orquestar cierre + trazabilidad con un solo comando usar `tools\run_estandar_proyecto.ps1`.
- Para sanear mojibake en skills locales (`.claude\skills\*\SKILL.md`) usar `tools\fix_skill_mojibake.ps1`.
- El agente que edita no se autoaprueba sin una pasada final de control. Si la tarea es minima, el control puede ser breve, pero nunca se omite.
- No responder "terminado" sin indicar que control final se ha ejecutado y si hubo o no incidencias.

## Cierre rapido recomendado
- Un unico `DOCX` o `XLSX`: editar, comprobar el cambio visible, ejecutar `tools\check_office_mojibake.ps1` y responder con resultado.
- Un unico `DOCX` con tablas: ademas de mojibake, ejecutar `tools\check_docx_tables_consistency.ps1`.
- Un unico `XLSX` o `XLSM`: ademas de mojibake, ejecutar `tools\check_excel_formula_guard.ps1`.
- Un unico `BC3`: editar, revisar `~C`, `~D`, `~T`, `~M` afectados, ejecutar `tools\check_bc3_integrity.ps1` y responder con resultado.
- Una revision de coherencia entre `excel`, `docx`, `bc3`, `csv`, `md` o `txt`: ejecutar `tools\check_traceability_consistency.ps1` sobre los archivos relevantes y, si hace falta, limitar la revision a los conceptos cambiados con `-Needles`.
- Una tarea mixta: ejecutar `tools\run_project_closeout.ps1` sobre las rutas tocadas para no olvidar el cierre de ninguna pieza.

## Comandos tipo de maquetacion profesional
- Snapshot previo de formulas Excel: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths "<excel_o_carpeta>" -WriteManifestPath ".\.codex_tmp\excel_formulas_before.json"`.
- Verificacion posterior Excel contra base: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths "<excel_o_carpeta>" -BaselineManifestPath ".\.codex_tmp\excel_formulas_before.json"`.
- Estandarizacion visual segura de Excel: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\excel_style_safe.ps1 -Paths "<excel_o_carpeta>" -FontName "Montserrat"`.
- Control DOCX de tablas y caption: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1 -Paths "<docx_o_carpeta>" -ExpectedFont "Montserrat" -EnforceFont $true -RequireTableCaption $true`.
- Autofix de captions en DOCX: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\autofix_docx_captions.ps1 -Paths "<docx_o_carpeta>" -CaptionPrefix "Tabla" -DefaultDescription "Descripcion"`.
- Revision normativa por alcance: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_normativa_scope.ps1 -Paths "<ruta_o_carpeta>" -FailOnMissing`.
- Cierre mixto estricto: `powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_project_closeout.ps1' -Paths @('<ruta1>','<ruta2>') -StrictDocxLayout $true -RequireTableCaption $true -CheckExcelFormulas $true"`.
- Pipeline unico recomendado: `powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('<ruta1>','<ruta2>','<ruta3>') -Modo estricto -TraceProfile 'base_general'"`.

## Perfiles oficiales de trazabilidad
- Perfil `base_general`: BC3 maestro + auditoria de trazabilidad + anejo 4 + mediciones auxiliares + matriz trazabilidad.
- Perfil `pluviales_fecales`: BC3 + auditoria + anejos 7 y 8 + reportes y CSV trazables de pluviales/fecales.
- Perfil `control_calidad_plan_obra`: BC3 + auditoria + anejo 14 + anejo 15 + SyS (anejo 17 + dimensionado).
- Perfil `residuos_sys`: BC3 + auditoria + anejo 13 (residuos) + Excel GR + BC3 SyS + anejo 17 + dimensionado SyS.
- Perfil `todo_integral`: perfil completo transversal para cierre global (4, 7, 8, 13, 14, 15 y 17 + BC3 + auditoria).
- Ejecucion por perfil: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "base_general" -StrictProfile`.
- Ejecucion por perfil con conceptos forzados: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "pluviales_fecales" -Needles "MCG-1.04#","UAC010.3.6","CLP630" -StrictProfile`.
- Ejecucion global recomendada: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_traceability_profile.ps1 -Profile "todo_integral" -StrictProfile`.
