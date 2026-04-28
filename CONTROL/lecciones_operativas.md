# Lecciones operativas — 535.2.1 Plaza Mayor

> Reglas derivadas de correcciones reales. Se leen al inicio de cualquier tarea no trivial.
> Después de cada corrección de JL: añadir la regla aquí antes de cerrar la sesión.
> Formato: regla → Por qué → Cómo aplicar.

---

## BC3 y codificación

**Regla: nunca escribir archivos BC3 con encoding UTF-8.**
Por qué: Presto lee los BC3 en ANSI (Windows-1252 / latin-1). Si se escribe con UTF-8 aparecen secuencias multibyte que Presto muestra como mojibake (Ã, â€", Ã"N, etc.). Esto ocurrió en la creación del BC3 maestro de Plaza Mayor y obligó a rehacerlo.
Cómo aplicar: siempre usar `encoding=bc3['encoding']` (que devuelve `latin-1`) al escribir con bc3_tools como librería. Verificar con `tools/check_bc3_encoding.ps1` antes de cerrar.

**Regla: las referencias ~D a componentes usan el mismo sufijo # que los ~C.**
Por qué: el donor de Guadalmar tenía 19 descomposiciones con referencias sin # (MCG-1, MCG-1.01…) pero los conceptos ~C estaban codificados con # (MCG-1#, MCG-1.01#). Esto generó 19 errores "COMPONENTE SIN ~C" en validate.
Cómo aplicar: tras cualquier merge o creación de BC3 desde donor, ejecutar `bc3_tools.py validate` y revisar errores de jerarquía. Si el código referenciado no existe pero código+'#' sí existe, corregir la referencia.

**Regla: ejecutar recalc después de corregir referencias o estructura de BC3.**
Por qué: tras corregir las 19 referencias, el capítulo raíz 535.2.1## tenía precio declarado 0.0 pero calculado 5.108.559,83 EUR. El validate lo detecta como error hasta que se ejecuta recalc.
Cómo aplicar: `bc3_tools.py recalc <archivo.bc3>` siempre tras modify masivo. Snapshot obligatorio antes.

**Regla: `bc3_tools.py rename` tiene un bug secundario de logging (NameError: Path) pero la operación de renombrado sí se ejecuta correctamente.**
Por qué: el bug aparece en el log de salida pero no aborta el rename. Confundirlo con un fallo real llevaría a repetir la operación innecesariamente.
Cómo aplicar: ignorar el NameError en la salida de rename; verificar resultado con `bc3_tools.py show` o `info`.

---

## Gestión de archivos y repos

**Regla: antes de eliminar cualquier carpeta con contenido, moverla y verificar que la copia está completa.**
Por qué: al abordar "Decontaminar Guadalmar", el KANBAN decía "eliminar" pero los tres repos (urbanizacion-toolkit, urbanizacion-plantilla-base, 00_PLANTILLA_BASE) tenían contenido real y git history. Borrarlos directamente habría supuesto pérdida irreversible.
Cómo aplicar: copiar primero (`cp -r`), verificar recuento de archivos y presencia de `.git`, luego eliminar el origen. Si el sandbox no tiene permisos para eliminar, avisar a JL para que lo haga manualmente.

**Regla: repos git anidados dentro de otro repo son un problema estructural, no una opción válida.**
Por qué: git trata un repo dentro de otro como submodule no declarado. Claude no sabe a qué repo está sirviendo, los commits del padre no capturan los cambios del hijo.
Cómo aplicar: cuando se detecte un `.git` dentro de la carpeta de trabajo de otro repo, moverlo a su nivel correcto antes de operar.

**Regla: `shared-tools/` es la fuente canónica de bc3_tools.py, excel_tools.py y mediciones_validator.py.**
Por qué: si la copia local en `tools/` diverge de shared-tools, las herramientas del proyecto quedan desincronizadas del ecosistema.
Cómo aplicar: ejecutar `tools/check_tools_sync.ps1` antes de tareas que usen las herramientas. Si hay drift, copiar desde shared-tools.

---

## Excel y mediciones

**Regla: nunca leer cantidades de un xlsx directamente — usar siempre `excel_tools.py`.**
Por qué: los Excel del proyecto tienen hasta 85 rangos de celdas combinadas. Leer el xlsx a ojo o con openpyxl sin la tool lleva a inventar cantidades que no corresponden a las celdas reales.
Cómo aplicar: `python3 tools/excel_tools.py read <archivo.xlsx> --sheet=<hoja>`. Leer el CSV resultante, nunca el xlsx directamente.

---

## Trazabilidad y decisiones

**Regla: comprobar DECISIONES_PROYECTO.md antes de reabrir cualquier decisión arquitectónica.**
Por qué: decisiones como la base de precios (GMU Málaga), el workflow BC3, el pliego vigente o el alcance de los anejos eléctricos ya están cerradas. Reabrirlas genera trabajo duplicado y confusión.
Cómo aplicar: consultar DECISIONES_PROYECTO.md al inicio de cualquier tarea relacionada con presupuesto, pliego o alcance. No preguntar a JL lo que ya está decidido.

**Regla: los anejos 9, 10 y 11 son out_of_scope (técnico eléctrico externo). El anejo 18 no existe.**
Por qué: el expediente termina en el anejo 17 (SyS). Los anejos eléctricos existen en el expediente pero son responsabilidad de otro técnico y no tienen representación en este repo.
Cómo aplicar: estado en trazabilidad = `out_of_scope` / `does_not_exist`. No crear carpetas ni DOCX para estos anejos.

---

## Cierre de tareas

**Regla: una tarea sobre BC3, DOCX o XLSX no se cierra sin verificación explícita.**
Por qué: el control anti-mojibake y el validate de BC3 han detectado errores reales que una revisión visual no hubiera encontrado.
Cómo aplicar:
- BC3: `bc3_tools.py validate` + `check_bc3_encoding.ps1` + SHA256 actualizado en FUENTES_MAESTRAS y MANIFEST_VIGENCIA
- DOCX/XLSX: control anti-mojibake (buscar Ã, Â, â€", Ã', Ã" en el XML interno)
- Nunca responder "hecho" antes de pasar estos controles

**Regla: actualizar el SHA256 en FUENTES_MAESTRAS.md, MANIFEST_VIGENCIA.md, KANBAN.md y memoria después de cualquier modificación al BC3 maestro.**
Por qué: el SHA desfasado genera confusión sobre qué versión es la canónica. Ocurrió al finalizar el recalc del BC3 maestro de Plaza Mayor.
Cómo aplicar: `sha256sum <archivo.bc3>` → actualizar los cuatro destinos en la misma sesión.

---

## Auto-mejora

**Regla: después de cada corrección de JL, añadir la regla derivada a este archivo antes de cerrar la sesión.**
Por qué: sin este registro, los mismos errores se repiten en sesiones futuras porque el contexto no persiste.
Cómo aplicar: identificar la causa raíz de la corrección → formular la regla en formato "Regla / Por qué / Cómo aplicar" → añadirla a la sección correspondiente de este archivo → confirmar a JL que la lección está registrada.
