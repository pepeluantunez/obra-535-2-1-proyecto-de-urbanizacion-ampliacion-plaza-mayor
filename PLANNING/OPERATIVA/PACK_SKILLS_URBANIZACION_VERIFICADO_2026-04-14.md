# Pack de Skills y Agentes (Verificado)

Fecha: 2026-04-14  
Proyecto: 535.2.2 Mejora Carretera Guadalmar

## Objetivo

Definir un pack corto, profesional y mantenible para proyectos de urbanización,
evitando instalar skills de más y reduciendo trabajo repetitivo.

## Pack recomendado (núcleo)

1. Skill local `535-guadalmar` (contexto y criterios del proyecto).
2. Skill local `auditoria-civil-completa` (auditoría integral civil).
3. Skill local `auditoria-civil-interactiva` (auditoría parcial por módulos).
4. Flujo de trazabilidad por perfiles (`tools/run_traceability_profile.ps1`).
5. Pipeline estricto de cierre (`tools/run_estandar_proyecto.ps1`).

## Skills externas que sí aportan (prioridad alta)

1. `skill-creator` (crear/mejorar skills propias).
2. `session-handoff` (continuidad entre sesiones largas).
3. `command-creator` (comandos reutilizables para tareas repetitivas).
4. `systematic-debugging` (método para análisis causa-raíz, útil en coherencia técnica).
5. `agent-md-refactor` (limpieza de AGENTS.md / instrucciones).

## Skills externas opcionales (solo si usas Git de verdad)

1. `commit-work` (commits atómicos y trazables).
2. `using-git-worktrees` (solo para trabajo paralelo avanzado).

## Criterio de seguridad

- Cualquier skill comunitaria puede ejecutar código.
- Instalar solo lo necesario y revisar contenido antes de usar en producción documental.
- Preferir skills oficiales y skills propias del proyecto para trabajo crítico.

## Plan de adopción recomendado

### Fase 1 (inmediata)

- Mantener 3 skills locales (ya activas).
- Usar solo `session-handoff` y `command-creator` como apoyo.

### Fase 2 (estabilización)

- Añadir `agent-md-refactor` para ordenar instrucciones.
- Añadir `systematic-debugging` para incidencias complejas de coherencia.

### Fase 3 (solo si aplica)

- Añadir `commit-work` si el flujo del proyecto entra en Git operativo diario.

## Comandos de uso en este proyecto

- Auditoría completa civil: usar `auditoria-civil-completa`.
- Auditoría parcial: usar `auditoria-civil-interactiva`.
- Trazabilidad estricta global: `tools/run_traceability_profile.ps1 -Profile todo_integral -StrictProfile`.
- Trazabilidad estricta Residuos + SyS: `tools/run_traceability_profile.ps1 -Profile residuos_sys -StrictProfile`.
- Cierre integral estricto: `tools/run_estandar_proyecto.ps1 -Modo estricto -TraceProfile todo_integral`.

## Referencias verificadas

- OpenAI Skills Catalog: https://github.com/openai/skills
- OpenAI Docs (skills en Codex): https://developers.openai.com/codex/skills
- Artículo WebReactiva (skills recomendadas): https://www.webreactiva.com/blog/mejores-skills-codex
- Repositorio `softaworks/agent-toolkit`: https://github.com/softaworks/agent-toolkit
- `systematic-debugging` en skills.sh: https://skills.sh/obra/superpowers/systematic-debugging
- `session-handoff` en skills.sh: https://skills.sh/softaworks/agent-toolkit/session-handoff
- `command-creator` en skills.sh: https://skills.sh/softaworks/agent-toolkit/command-creator
