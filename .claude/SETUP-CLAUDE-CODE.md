# Setup Claude Code para esta repo

Documento de onboarding para que cualquiera del equipo deje Claude Code listo
en este proyecto con la misma configuracion.

## 1. Marketplace oficial de Anthropic

Marketplace verificado: `anthropics/claude-plugins-official`
(repo: https://github.com/anthropics/claude-plugins-official, mantenido por
Anthropic, descripcion literal del repo: "Official, Anthropic-managed
directory of high quality Claude Code Plugins").

Anadelo una vez en tu Claude Code:

```
/plugin marketplace add anthropics/claude-plugins-official
```

Para refrescarlo cuando salgan plugins nuevos:

```
/plugin marketplace update claude-plugins-official
```

## 2. Plugin recomendado: `claude-code-setup`

Es una skill **read-only** publicada por Anthropic (autora: Isabella He,
`isabella@anthropic.com`). No modifica ficheros: analiza el repo y devuelve
recomendaciones de automatizaciones (hooks, skills, MCP servers, subagents,
slash commands).

Instalacion:

```
/plugin install claude-code-setup@claude-plugins-official
```

Uso tipico, una vez instalado, dentro de Claude Code en este repo:

- "recommend automations for this project"
- "help me set up Claude Code"
- "what hooks should I use?"

## 3. Que hacer con sus recomendaciones

Importante: el plugin solo sugiere. **No aplicar nada automaticamente.**

Flujo propuesto:

1. Ejecutar el plugin en este repo y guardar la salida en `.claude/handoffs/`
   con fecha (p. ej. `claude-code-setup-recs-YYYY-MM-DD.md`).
2. Revisar caso por caso. Para cada recomendacion:
   - Si es un hook: escribir/auditar el codigo del hook antes de anadirlo.
     Bloquear cualquier hook que abra red, lea `.env`, `~/.ssh`, o ejecute
     binarios externos sin justificar.
   - Si es un MCP server: revisar el repo de origen, fijar version, mirar
     que credenciales pide.
   - Si es un subagente o slash command: leer el prompt integro antes de
     activarlo.
3. Aprobar en PR los cambios al `.claude/` para que queden versionados y
   compartidos.

## 4. Otros plugins del marketplace oficial a evaluar

Visibles en `anthropics/claude-plugins-official` y `anthropics/claude-code`
(verificar disponibilidad a dia de hoy con `/plugin marketplace`):

- `code-simplifier`
- `frontend-design`
- `feature-dev`
- `ralph-wiggum` (marcado como inestable en algunos sistemas segun la
  comunidad - falta verificar estado actual)

## 5. Fuentes externas consultadas

- `centminmod/my-claude-code-setup`: util como referencia para estructura
  de `CLAUDE.md` y seleccion de MCP servers de terceros. **No adoptar tal
  cual.**
- `mrgoonie/claude-code-setup`: idea de subagentes con roles. **No usar
  su slash command `/cmp` que hace `commit + push` automatico.**

## 6. Lo que falta verificar

- Schema exacta para registrar el marketplace dentro de `.claude/settings.json`
  a nivel de proyecto. De momento cada dev corre el comando manualmente.
- Lista actual de plugins disponibles en el marketplace oficial (anadir aqui
  cuando se confirme).
