# Referencias Externas Utiles

Fecha: 2026-04-25
Objetivo: recoger ideas trasladables al ecosistema sin importar repos completos que no encajan con un proyecto vivo de urbanizacion.

## Repos revisados

1. `andrej-karpathy-skills`
2. `hermes-agent`
3. `claude-mem`
4. `evolver`
5. `GenericAgent`

## Lo que si merece la pena adoptar

### 1. Karpathy-style execution rules

Fuente:
- [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)

Ideas utiles:
- pensar antes de codificar
- simplicidad primero
- cambios quirurgicos
- ejecucion guiada por criterios de exito verificables

Encaje en este ecosistema:
- muy alto
- refuerza exactamente lo que ya estamos intentando hacer con triage, closeout y cambios minimos

Adopcion recomendada:
- usar estas cuatro ideas como criterio transversal de diseno para skills y agentes
- no importar su `CLAUDE.md` como autoridad adicional en repos de proyecto

### 2. Memoria persistente con recuperacion progresiva

Fuente:
- [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem)

Ideas utiles:
- memoria persistente entre sesiones
- recuperacion por capas para ahorrar tokens
- busqueda antes de cargar detalles completos
- exclusion deliberada de contenido sensible

Encaje en este ecosistema:
- alto
- especialmente util para sesiones largas, trazabilidad y continuidad entre expedientes

Adopcion recomendada:
- no instalar el plugin sin mas
- si se implementa algo parecido, debe ser:
  - opt-in
  - con exclusion de datos sensibles
  - basado en busqueda primero y detalle despues
- candidato fuerte para una futura `memory lane` de ecosistema, no para un repo de proyecto aislado

### 3. Skills, memoria y scheduling como sistema

Fuente:
- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)

Ideas utiles:
- memoria persistente
- skills como memoria procedural
- scheduling/cron
- integracion MCP
- allowlists y aprobaciones de comandos
- compresion de contexto y sesiones

Encaje en este ecosistema:
- medio-alto
- no por el agente entero, sino por el modelo operativo

Adopcion recomendada:
- tomar como inspiracion para:
  - command approval patterns
  - mejor separacion entre memoria, skills y contexto de workspace
  - futuros agentes programados de trazabilidad y governance
- no adoptar el stack completo ni su runtime

### 4. Cristalizacion de tareas repetidas en skills

Fuente:
- [lsdefine/GenericAgent](https://github.com/lsdefine/GenericAgent)

Idea util:
- cuando una tarea ya se resolvio varias veces de forma estable, cristalizarla en una skill reutilizable

Encaje en este ecosistema:
- medio
- la idea es buena; la parte de "self-evolving full system control" no encaja

Adopcion recomendada:
- regla de trabajo:
  - si un flujo se repite 3 veces con el mismo patron y mismo cierre, evaluar convertirlo en skill
- no auto-generar skills sin revision humana

## Lo que no conviene importar

### Evolucion autonoma como framework central

Fuentes:
- [EvoMap/evolver](https://github.com/EvoMap/evolver)
- [lsdefine/GenericAgent](https://github.com/lsdefine/GenericAgent)

Motivos para no adoptarlo como base:
- exceso de complejidad para el problema real del repo
- riesgo alto de inflar mas el sistema antes de estabilizar lo basico
- en `evolver`, parte del motor se distribuye ofuscado; no encaja con una capa comun auditable y mantenible
- en `GenericAgent`, la promesa de auto-crecimiento y control total del sistema es demasiado amplia para un entorno documental y de ingenieria con controles estrictos

Regla:
- aqui primero se estabiliza:
  - triage
  - closeout
  - glosario
  - redaccion
  - governance
  - trazabilidad
- la autoevolucion queda fuera hasta que el sistema base sea auditable y sobrio

## Cambios concretos recomendados a partir de esta revision

1. anadir una `memory lane` de ecosistema a futuro
   - busqueda primero
   - detalle despues
   - exclusion de datos sensibles

2. anadir a las skills canonicas un bloque corto de principios transversales
   - pensar antes de ejecutar
   - simplicidad primero
   - cambios quirurgicos
   - cierre verificable

3. crear una regla de cristalizacion
   - un flujo repetido y estable se puede convertir en skill solo tras validacion humana

4. evitar cualquier marco de autoevolucion compleja por ahora
   - no genes
   - no skill trees auto-generados
   - no control total del sistema

## Decision actual

Adoptar ideas, no repos enteros.

Prioridad de adopcion:

1. `andrej-karpathy-skills`
2. `claude-mem`
3. `hermes-agent`
4. `GenericAgent` solo por la idea de cristalizacion supervisada
5. `evolver` solo como referencia conceptual lejana
