# Criterios De Diseno Para Skills Y Agentes

Fecha: 2026-04-25
Origen: lecciones utiles extraidas de `prompt-master`

## Objetivo

Recoger solo las ideas trasladables al ecosistema de urbanizacion, sin importar el estilo ni el marketing del repositorio fuente.

## Ideas adoptadas

### 1. Confirmar siempre el destino real

Antes de redactar un prompt, skill o agente, hay que saber para que motor o entorno va:

- Codex/Codex desktop
- Claude Code
- ChatGPT
- Slack intake
- workflow programado

Aplicacion:
- ninguna skill nueva debe ser "universal" por defecto
- si el destino es ambiguo, preguntar o enrutar antes de producir instrucciones largas

### 2. Maximo 3 preguntas de aclaracion

Principio util:
- si faltan datos criticos, aclarar rapido
- no convertir el arranque en un interrogatorio largo

Aplicacion:
- el triage debe resolver por lectura primero
- solo preguntar cuando falte informacion bloqueante
- limite recomendado: 3 preguntas maximo antes de ejecutar

### 3. Stop conditions obligatorias en agentes

Esto es especialmente valido para agentes que editan o usan herramientas.

Aplicacion:
- toda prompt/skill de agente debe declarar:
  - estado inicial
  - estado objetivo
  - acciones permitidas
  - acciones prohibidas
  - condiciones de parada
  - checkpoints de revision humana

Especialmente obligatorio en:
- `document-closeout-agent`
- futuros `BC3 Safety Agent`
- futuros agentes de Slack o automacion

### 4. Output contract fijo

Una instruccion buena no solo dice que hacer; tambien bloquea como se reporta.

Aplicacion:
- cada skill debe devolver un bloque fijo y corto cuando proceda
- evitar respuestas libres que oculten si realmente se ejecutaron checks

### 5. Restricciones criticas al principio

Las restricciones mas importantes deben ir al principio de la instruccion o prompt.

Aplicacion:
- poner arriba:
  - rutas permitidas
  - no tocar ciertos archivos
  - stop before delete
  - criterio de cierre

### 6. Skills cortas, referencias largas fuera

La idea buena aqui no es "mas prompting", sino mejor empaque.

Aplicacion:
- `SKILL.md` debe contener:
  - objetivo
  - activacion
  - flujo corto
  - output contract
- el detalle largo debe ir a `references/`

Beneficio:
- menos drift
- menos mojibake
- menos skills gordas y repetitivas

### 7. No usar tecnicas teatrales que no se puedan sostener

Traslado util:
- no meter marcos grandilocuentes o pseudo-multiagente dentro de una skill si en realidad no existen como ejecucion real

Aplicacion:
- evitar skills que prometen "council", "graph thinking", "multi expert" o similares si no hay implementacion trazable
- preferir instrucciones concretas, verificables y acotadas

### 8. Pensar las skills como artefactos medibles

La idea util no es el "prompt engineering", sino el control de calidad.

Aplicacion:
- evaluar una skill por:
  - si pide demasiado contexto
  - si hace demasiadas lecturas
  - si obliga a repreguntar demasiado
  - si produce salidas verificables

## Ideas no adoptadas tal cual

- no crear una skill local para escribir prompts para cualquier IA; eso no es la prioridad de estos repos
- no convertir el ecosistema en una coleccion de frameworks de prompting
- no copiar perfiles para 30 herramientas si no tienen uso real aqui

## Impacto inmediato en Plaza Mayor

Estas reglas se aplican ya a:

- `.agents/skills/ecosystem-triage/SKILL.md`
- `.agents/skills/document-closeout-agent/SKILL.md`

Y deben aplicarse despues a:

- consolidacion de `verification-before-completion`
- consolidacion de `dispatching-parallel-agents`
- futuros agentes `traceability`, `repo-governance` y `bc3-safety`
