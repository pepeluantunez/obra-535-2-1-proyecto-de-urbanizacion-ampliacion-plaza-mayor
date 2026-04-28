# Handoff

- Agente: Codex
- Fecha: 2026-04-27 09:40
- Rama: sin cambio de rama
- Objetivo: implantar una base de coordinacion entre Claude y Codex dentro del repo

## Archivos tocados

- `PLANNING/OPERATIVA/COORDINACION_CLAUDE_CODEX.md`
- `CONTROL/ai_runs/handoffs/README.md`
- `CONTROL/ai_runs/handoffs/_TEMPLATE.md`
- `PLANNING/OPERATIVA/README.md`

## Hecho

- Se creo un protocolo comun con arranque obligatorio, bloqueo activo, reglas de convivencia y criterio para actualizar autoridades.
- Se habilito `CONTROL/ai_runs/handoffs/` como almacenamiento compartido y versionable de relevos cortos entre sesiones o agentes.
- Se dejo una plantilla minima para que el siguiente handoff no tenga que inventar formato.
- Se anadio una referencia en `PLANNING/OPERATIVA/README.md` para que la coordinacion sea descubrible.

## Checks

- `git diff -- 'PLANNING/OPERATIVA/COORDINACION_CLAUDE_CODEX.md' 'CONTROL/ai_runs/handoffs/README.md' 'CONTROL/ai_runs/handoffs/_TEMPLATE.md' 'PLANNING/OPERATIVA/README.md'`: OK
- `Select-String` con patrones de mojibake sobre los archivos nuevos: sin coincidencias

## Pendiente

- Empezar a usar la tabla de bloqueo activo cuando un agente abra un bloque real de edicion.
- Crear handoff por cada bloque relevante a partir de ahora.
- Si esta coordinacion se consolida, valorar reflejarla mas adelante en una capa comun del ecosistema y no solo en Plaza Mayor.
