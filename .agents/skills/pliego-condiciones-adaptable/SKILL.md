---
name: pliego-condiciones-adaptable
description: >
  Reutiliza y adapta el pliego de condiciones base de un proyecto POU a un proyecto nuevo sin
  rehacer el documento entero. Usar cuando el usuario pida crear, clonar, actualizar o revisar un
  pliego de condiciones DOCX a partir de la base de Guadalmar o de la plantilla maestra del repo.
---

# Skill: Pliego de Condiciones Adaptable

Usa esta skill cuando haya que preparar un pliego de condiciones nuevo a partir del base
`DOCS - PLANTILLAS/PLIEGO DE CONDICIONES/PLANTILLA_PLIEGO_CONDICIONES_BASE.docx`.

## Entradas esperadas

- `CONFIG/proyecto.template.json`
- `CONFIG/pliego_condiciones.template.json`

Si falta alguno, crear un borrador minimo antes de tocar el DOCX.

## Archivos de referencia

- Leer `references/mapeo_base.md` para localizar los cambios de alta prioridad.
- No cargar mas referencias salvo necesidad.

## Criterio de reutilizacion

- Mantener la estructura y maquetacion del pliego base.
- Editar solo lo necesario.
- No hacer reemplazos globales ciegos sobre `Malaga`, `Ayuntamiento` o nombres cortos, porque hay
  apariciones legitimas en promotor, pie y normativa.
- Revisar siempre si el nuevo proyecto realmente incluye riego, alumbrado, telecomunicaciones,
  agua regenerada o condicionantes de companias concretas.

## Flujo operativo

1. Duplicar la plantilla base a la ruta de trabajo del nuevo proyecto.
   Alternativa recomendada: ejecutar `.\scripts\adapt_pliego_condiciones.ps1` con el JSON de
   configuracion del proyecto.
2. Actualizar portada:
- fecha
- autores
- promotor
- titulo del proyecto
- municipio

3. Actualizar las referencias duras en cuerpo y metadatos:
- articulo 100.2
- articulo 102
- portada interior e indice si arrastran el nombre del proyecto anterior
- `docProps/core.xml` (`dc:title` y `dc:subject`)
- codigo de expediente en pie si cambia

4. Revisar alcance tecnico:
- normativa municipal y sectorial del nuevo proyecto
- companias suministradoras y organismos afectados
- apartados heredados que no apliquen

5. Cerrar con control documental obligatorio.

## Controles obligatorios

Ejecutar siempre:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_office_mojibake.ps1 -Paths "<docx>"
```

Si se toca maquetacion, tablas o tipografia, ejecutar tambien:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_docx_tables_consistency.ps1 -Paths "<docx>" -ExpectedFont "Montserrat"
```

Si se revisa el alcance normativo, ejecutar tambien:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_normativa_scope.ps1 -Paths "<docx_o_carpeta>" -FailOnMissing
```

## Respuesta minima al cerrar

Indicar siempre:

1. DOCX base usado.
2. Campos adaptados.
3. Revisiones tecnicas pendientes, si las hay.
4. Comandos de verificacion ejecutados y si hubo incidencias.
