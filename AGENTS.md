# AGENTS.md — Contrato universal del repo 535.2.1
# Proyecto de Urbanización — Ampliación Plaza Mayor
# Leído por Claude Code, Codex y cualquier agente que opere en este repo.
# Instrucciones Claude-específicas (skills, hooks, lecciones): ver CLAUDE.md

## Identidad del proyecto

- Expediente: **535.2.1** — Proyecto de Urbanización, Ampliación Plaza Mayor
- Tipo: Proyecto de Obras de Urbanización (POU)
- Alcance: viario, firme, agua potable, saneamiento, accesibilidad, residuos, SyS
- Fuera de alcance salvo orden expresa: anejos 9, 10, 11 (eléctrico) y 18 (telecom)
- Documentos de contexto (leer antes de cualquier tarea no trivial):
  1. `MAPA_PROYECTO.md` — estructura y triage
  2. `FUENTES_MAESTRAS.md` — qué documento manda en cada tema
  3. `DECISIONES_PROYECTO.md` — decisiones ya tomadas, no reabrir
  4. `ESTADO_PROYECTO.md` — estado actual

## Estilo visual del proyecto (Montserrat + azul corporativo)

Extraído de PLANTILLA_MAESTRA_ANEJOS/MEMORIA/ESS.docx — fuente de autoridad visual:

| Elemento | Valor |
|----------|-------|
| Fuente | **Montserrat** (Word y Excel — nunca Calibri ni Arial como fuente principal) |
| Cabecera tabla bg | `#366092` (azul corporativo) |
| Cabecera tabla texto | `#FFFFFF` (blanco, negrita) |
| Fila alterna | `#D9EAF7` (azul muy pálido) |
| Subtotal / agrupación | `#D9E2F3` (azul suave) |
| Acento oscuro (títulos) | `#0E2841` (dk2 del tema) |
| Neutro / separador | `#F2F2F2` (gris claro) |

Aplicar con: `python3 tools/apply_project_style.py` (hace backup _ORIG automático).

## Formato de commit

```
tipo(alcance): descripcion
```
Tipos válidos: `fix` `feat` `refactor` `docs` `chore` `anejo` `bc3` `excel` `word` `style` `ci` `data` `trazabilidad`

Ejemplos: `anejo(7): primer borrador pluviales` · `bc3(maestro): recalc PEM` · `fix(encoding): mojibake anejo 14`

## Herramientas del proyecto (tools/)

| Script | Uso |
|--------|-----|
| `bc3_tools.py` | ÚNICA forma de tocar BC3: info, show, modify, recalc, validate… |
| `excel_tools.py` | Lectura determinista xlsx: info, sheets, read, find |
| `mediciones_validator.py` | Cruce BC3 vs Excel |
| `expediente_status.py` | Estado Word/Excel/BC3 de todos los anejos |
| `apply_project_style.py` | Estandarizar estilos (Montserrat + paleta corporativa) |
| `organize_anejo_folders.py` | Verificar/crear estructura de carpetas de anejos |
| `session_briefing.py` | Briefing de sesión: bloqueados, P1, progreso |
| `install_git_hooks.ps1` | Instalar pre-commit + commit-msg hooks |

---


## Regla critica: frontera de repositorio y autoridad local
- Este repo es un proyecto vivo; no debe actuar como plantilla base ni como toolkit reutilizable.
- Si una mejora, SOP o regla sirve a varios proyectos, debe proponerse para toolkit o plantilla y no quedarse solo como regla local por defecto.
- No crear autoridades paralelas en raiz para triage, estandares o gobierno si la funcion ya existe en `MAPA_PROYECTO.md`, `FUENTES_MAESTRAS.md`, `DECISIONES_PROYECTO.md` o `CONFIG\repo_contract.json`.
- Si una tarea mezcla proyecto, plantilla y toolkit, separar primero la capa afectada antes de editar.

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

## Regla critica: snapshot obligatorio antes de modificar BC3

ANTES de ejecutar cualquier modify, merge, recalc o edicion manual sobre un .bc3:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\bc3_snapshot.ps1 -Path "<archivo.bc3>" -Label "antes-<operacion>"
```

DESPUES de la operacion, generar el diff para confirmar que no hubo perdidas:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\bc3_diff_report.ps1 -Before ".\scratch\bc3_snapshots\<snapshot_antes>.json" -After ".\scratch\bc3_snapshots\<snapshot_despues>.json"
```

- Si el informe muestra conceptos eliminados (seccion PERDIDA CRITICA), detener y avisar al usuario antes de continuar.
- Si hay mediciones (~M) afectadas sin que el usuario haya pedido --allow-mediciones, tambien detener y avisar.
- Los snapshots se guardan en scratch\bc3_snapshots\ y no se eliminan — son el historial de cambios.
- Flujo minimo obligatorio: snapshot-antes → operacion → snapshot-despues → diff → avisar si hay perdidas.

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

## Regla critica: indices DOCX
- No copiar ni reconstruir el resultado visible del indice desde la plantilla como texto plano.
- No rehacer un TOC de Word clonando parrafos `TDC*` sin regenerar marcadores y referencias `PAGEREF`.
- Si un `DOCX` pierde numeros de pagina en el indice o muestra `Error. Marcador no definido.`, rehacer el indice desde los headings reales del documento y recrear marcadores `_Toc...` validos.
- Cualquier normalizacion de apertura debe dejar intactos cabeceras, pies y el bloque de indice salvo que se use un flujo seguro especifico para TOC.

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

## Matriz minima tarea → verificacion
- `DOCX` o `DOCM` puntual: comprobar cambio visible y ejecutar `tools\check_office_mojibake.ps1`.
- `DOCX` con tablas, captions o maquetacion: `tools\check_docx_tables_consistency.ps1` y, si falta caption, `tools\autofix_docx_captions.ps1`; cerrar ademas con anti-mojibake.
- `XLSX` o `XLSM`: control de formulas con `tools\check_excel_formula_guard.ps1`; si hubo estandarizacion visual, usar `tools\excel_style_safe.ps1` y repetir guardia de formulas.
- `BC3`: snapshot antes y despues con `tools\bc3_snapshot.ps1`, diff con `tools\bc3_diff_report.ps1`, revision de `~C`, `~D`, `~T`, `~M` afectados y cierre con `tools\check_bc3_integrity.ps1`.
- Pluviales o SSA: contrastar contra la fuente tecnica del anejo y cerrar con los checks documentales o BC3 que correspondan segun el arrastre.
- Trazabilidad entre documentos: `tools\check_traceability_consistency.ps1`; si el alcance coincide con un conjunto oficial, usar `tools\run_traceability_profile.ps1`.
- Revision normativa rapida: `tools\check_normativa_scope.ps1`.
- Tarea mixta o cierre de entrega local: `tools\run_project_closeout.ps1`; si ademas hay trazabilidad transversal, `tools\run_estandar_proyecto.ps1`.

## Checks y cierre local
- No replantear el flujo entero en cada encargo. Clasificar la tarea en su carril y ejecutar solo el cierre minimo obligatorio.
- Priorizar scripts y checklists del proyecto frente a una revision libre larga cuando sean suficientes.
- No responder "terminado" sin indicar que control final se ha ejecutado y si hubo o no incidencias.
- Office: `tools\check_office_mojibake.ps1`.
- DOCX con tablas o maquetacion: `tools\check_docx_tables_consistency.ps1`; si hace falta caption, `tools\autofix_docx_captions.ps1`.
- Excel o XLSM: `tools\check_excel_formula_guard.ps1`; para formato seguro, `tools\excel_style_safe.ps1`.
- BC3: snapshot antes y despues, diff con `tools\bc3_diff_report.ps1`, revision de `~C`, `~D`, `~T`, `~M` y cierre con `tools\check_bc3_integrity.ps1`.
- Trazabilidad transversal: `tools\check_traceability_consistency.ps1`; para conjuntos oficiales, `tools\run_traceability_profile.ps1` con perfiles en `CONFIG\trazabilidad_profiles.json`.
- Revision normativa rapida: `tools\check_normativa_scope.ps1`.
- Cierres mixtos: `tools\run_project_closeout.ps1`; si ademas hay trazabilidad, `tools\run_estandar_proyecto.ps1`.
- Mojibake en skills locales: `tools\fix_skill_mojibake.ps1`.

## Aprendizaje de skills y herramientas
- Cuando una skill, script o herramienta falle de forma inesperada, registrar el error antes de responder con `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\skill_error_logger.ps1 -Skill "<nombre_skill>" -Error "<descripcion_error>" -Contexto "<tarea_en_curso>" -Categoria "<script|skill|agente|herramienta>"`.
- Registrar siempre errores de codificacion inesperados, fallos de script, incoherencias detectadas en cierre y resultados incorrectos que obliguen a rehacer.
- No registrar errores de usuario, ausencia de archivos esperados o comportamiento correcto del sistema.
- Cuando el usuario pida revisar errores acumulados, ejecutar `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\skill_self_improve.ps1`.
- Las propuestas de mejora nunca se aplican automaticamente: primero se presentan al usuario y solo se ejecutan tras aprobacion expresa.

## Comandos de referencia local
- Snapshot previo de formulas Excel: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths "<excel_o_carpeta>" -WriteManifestPath ".\.codex_tmp\excel_formulas_before.json"`.
- Verificacion posterior Excel contra base: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_excel_formula_guard.ps1 -Paths "<excel_o_carpeta>" -BaselineManifestPath ".\.codex_tmp\excel_formulas_before.json"`.
- Control DOCX de tablas y caption: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1 -Paths "<docx_o_carpeta>" -ExpectedFont "Montserrat" -EnforceFont $true -RequireTableCaption $true`.
- Revision normativa por alcance: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_normativa_scope.ps1 -Paths "<ruta_o_carpeta>" -FailOnMissing`.
- Cierre mixto estricto: `powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_project_closeout.ps1' -Paths @('<ruta1>','<ruta2>') -StrictDocxLayout $true -RequireTableCaption $true -CheckExcelFormulas $true"`.
- Pipeline unico recomendado: `powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\run_estandar_proyecto.ps1' -Paths @('<ruta1>','<ruta2>','<ruta3>') -Modo estricto -TraceProfile 'base_general'"`.

## Perfiles locales de trazabilidad
- `base_general`: BC3 maestro + auditoria de trazabilidad + anejo 4 + mediciones auxiliares + matriz trazabilidad.
- `pluviales_fecales`: BC3 + auditoria + anejos 7 y 8 + reportes y CSV trazables de pluviales y fecales.
- `control_calidad_plan_obra`: BC3 + auditoria + anejo 14 + anejo 15 + SyS.
- `residuos_sys`: BC3 + auditoria + anejo 13 + Excel GR + BC3 SyS + anejo 17 + dimensionado SyS.
- `todo_integral`: cierre global transversal del conjunto trazable del proyecto.
