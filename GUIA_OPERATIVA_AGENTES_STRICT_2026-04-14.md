# Guia Operativa Agentes/Skills (Strict)

Fecha: 2026-04-14

## Nuevos componentes creados

### Skills

1. `.claude/skills/verification-before-completion/SKILL.md`
2. `.claude/skills/dispatching-parallel-agents/SKILL.md`

### Agente

1. `.claude/agents/normativa-auditor.md`

### Comandos

1. `.claude/commands/cierre-estricto.md`
2. `.claude/commands/trazabilidad-estricta.md`
3. `.claude/commands/normativa-estricta.md`
4. `.claude/commands/despacho-paralelo-estricto.md`
5. `.claude/commands/agente-normativa.md`

## Como usar (frase corta)

1. `/cierre-estricto DOCS\Documentos de Trabajo\14.- Control de Calidad`
2. `/trazabilidad-estricta todo_integral`
3. `/trazabilidad-estricta residuos_sys UAC010.3.6 CLP630`
4. `/normativa-estricta DOCS\Documentos de Trabajo\17.- Seguridad y Salud`
5. `/agente-normativa DOCS\Documentos de Trabajo\13.- Estudio de Gestion de Residuos`
6. `/despacho-paralelo-estricto cierre total residuos y SyS`

## Funcionamiento operativo

1. Se activa skill o comando segun tu frase.
2. Se ejecutan chequeos estrictos con scripts del proyecto.
3. Se bloquea cierre si hay incidencias criticas o controles fallidos.
4. Se devuelve reporte corto con evidencias y acciones.

## Regla de ahorro de uso

Para tareas repetitivas, priorizar comandos en vez de prompts largos:

1. `/cierre-estricto`
2. `/trazabilidad-estricta`
3. `/normativa-estricta`

Esto reduce iteraciones y evita rehacer el mismo flujo.
