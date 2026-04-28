# Coordinacion Claude Codex

Protocolo operativo para que `Claude` y `Codex` compartan estado real del repo sin pisarse cambios ni perder contexto.

## Objetivo

- Compartir por archivos lo que no comparten por memoria de chat.
- Reducir colisiones de edicion, ramas divergentes y "no se por que esto cambio".
- Dejar un relevo corto y verificable al cerrar cada bloque de trabajo.

## Autoridades

- Estado tecnico real del expediente: `ESTADO_PROYECTO.md`
- Decisiones locales vigentes: `DECISIONES_PROYECTO.md`
- Jerarquia de fuentes: `FUENTES_MAESTRAS.md`
- Mapa del repo y limites: `MAPA_PROYECTO.md`
- Trabajo pendiente priorizado: `PLANNING/KANBAN.md`
- Handoffs cortos compartidos: `CONTROL/ai_runs/handoffs/`
- Handoffs locales no versionados, si se quieren usar como espejo temporal: `.claude/handoffs/`

Regla: este documento coordina el trabajo entre agentes. No sustituye ninguna de las autoridades anteriores.

## Arranque obligatorio

Antes de tocar archivos:

1. Leer `MAPA_PROYECTO.md`, `FUENTES_MAESTRAS.md`, `DECISIONES_PROYECTO.md` y `ESTADO_PROYECTO.md` si la tarea no es trivial.
2. Revisar `git status --short`.
3. Revisar `git log --oneline --decorate -5`.
4. Leer el ultimo relevo util en `CONTROL/ai_runs/handoffs/` si existe.
5. Declarar el bloque activo en la tabla de abajo si se va a editar algo mas de un archivo o si el cambio puede durar mas de unos minutos.

## Tabla de bloqueo activo

Usar esta tabla como candado blando. No impide editar, pero obliga a avisar y delimitar alcance.

| Estado | Agente | Fecha hora | Rama | Archivos o area | Objetivo | Salida esperada |
| --- | --- | --- | --- | --- | --- | --- |
| libre | - | - | - | - | Sin bloque activo ahora mismo | - |

Reglas:

- `ocupado`: el agente esta trabajando y aun no ha soltado el bloque.
- `libre`: no hay bloque abierto.
- Si el alcance cambia mucho, actualizar la fila antes de seguir.
- Si dos agentes necesitan la misma zona, dividir por archivos concretos o parar y acordar una secuencia.

## Reglas de convivencia

- No editar a la vez el mismo archivo `docx`, `xlsx`, `xlsm`, `bc3`, `md` o `ps1`.
- En Office y BC3, un solo agente por contenedor mientras el bloque este `ocupado`.
- Si el trabajo afecta una decision o una fuente maestra, actualizar tambien el archivo autoridad correspondiente.
- No dejar cambios "misteriosos": todo bloque cerrado debe dejar relevo o commit claro.
- Si se toca un archivo delicado, anotar tambien el check ejecutado y el resultado.

## Estrategia de Git

### Caso A: misma rama compartida

Usar cuando el trabajo es secuencial o muy corto.

- Actualizar la tabla de bloqueo antes de editar.
- Al terminar, dejar relevo en `CONTROL/ai_runs/handoffs/`.
- No mezclar en el mismo bloque cambios de distintas capas sin explicarlo.

### Caso B: ramas separadas

Usar cuando ambos van a trabajar en paralelo o cuando el cambio es largo.

- `Codex`: preferir ramas `codex/<slug>`.
- `Claude`: usar una convencion equivalente, por ejemplo `claude/<slug>`.
- Cada rama debe dejar un handoff breve con:
  - que cambio
  - archivos tocados
  - checks ejecutados
  - riesgo o conflicto pendiente

## Cuando actualizar las autoridades

- `ESTADO_PROYECTO.md`: cambia el estado real del expediente, del repo o de un anejo.
- `DECISIONES_PROYECTO.md`: se toma una decision que debe mantenerse en sesiones futuras.
- `FUENTES_MAESTRAS.md`: cambia la fuente que manda para un anejo, tabla, Excel o BC3.
- `PLANNING/KANBAN.md`: cambia prioridad, owner, bloqueo o criterio de cierre de una tarea.

Si el cambio no altera estado, decision, fuente ni backlog, basta con el handoff de sesion.

## Handoff minimo por sesion

Guardar en `CONTROL/ai_runs/handoffs/` un Markdown con nombre:

`YYYY-MM-DD-HHMMSS-agent-slug.md`

Contenido minimo:

1. Objetivo del bloque
2. Archivos tocados
3. Cambios hechos
4. Checks ejecutados y resultado
5. Riesgos o bloqueos
6. Siguiente paso recomendado

## Plantilla corta de relevo

```md
# Handoff

- Agente: Codex o Claude
- Fecha: YYYY-MM-DD HH:MM
- Rama: nombre-rama
- Objetivo: una frase

## Archivos tocados

- ruta/archivo1
- ruta/archivo2

## Hecho

- cambio 1
- cambio 2

## Checks

- comando o check: OK o incidencia

## Pendiente

- siguiente paso
- riesgo o conflicto
```

## Checklist de cierre

Antes de soltar un bloque:

1. Revisar `git diff --name-only`.
2. Confirmar que la tabla de bloqueo sigue describiendo el alcance real.
3. Ejecutar los checks minimos del carril correspondiente.
4. Actualizar `ESTADO_PROYECTO.md`, `DECISIONES_PROYECTO.md`, `FUENTES_MAESTRAS.md` o `KANBAN.md` si aplica.
5. Crear o actualizar el handoff en `CONTROL/ai_runs/handoffs/`.
6. Dejar la tabla de bloqueo en `libre` si el bloque ha terminado.

## Criterio practico

Si `Claude` o `Codex` no pueden explicar mirando solo Git, este archivo y el ultimo handoff:

- que se estaba haciendo
- por que se hizo
- que falta
- donde esta el riesgo

entonces la coordinacion no es suficiente y debe mejorarse antes de seguir acumulando cambios.
