# CLAUDE.md - Adaptador Claude para 535.2.1

Seguir `AGENTS.md`. Este archivo solo anade diferencias utiles para Claude.

## Lecturas extra

- Leer `about-me.md` cuando la tarea dependa de criterio tecnico, tono de redaccion o preferencias del responsable.
- `CONTROL/lecciones_operativas.md` ya forma parte del carril comun; no saltarselo en tareas no triviales.

## Reglas Claude

- Brief ambiguo o peticion de alto impacto: preguntar antes de ejecutar.
- Dato no confirmado: decir "no consta"; no inventar.
- Bug pequeno o correccion clara: corregir directamente sin pedir contexto extra.
- Si una correccion de JL destapa una regla nueva, anadirla a `CONTROL/lecciones_operativas.md`.

## Briefing de sesion

```bash
python3 tools/session_briefing.py
```

## Skills locales

- `.claude/skills/cierre-anejo/`: invocarla antes de dar por cerrado un anejo cuando el usuario pida cierre, entrega o revision final.
- El resto de `.claude/skills/` se mantiene como capa local legacy de Claude; si una regla ya es comun, debe vivir en `AGENTS.md`, no repetida aqui.
