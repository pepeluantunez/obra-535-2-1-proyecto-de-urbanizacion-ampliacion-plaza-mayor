# Auditoria De Skills Locales

Fecha: 2026-04-25
Alcance: `.claude/skills` y `.agents/skills` de Plaza Mayor

## Criterio

Una skill local solo merece quedarse en este repo si:

1. aporta comportamiento especifico de Plaza Mayor
2. no duplica otra skill activa
3. no deberia vivir mejor en toolkit o en skills globales
4. no arrastra mojibake ni instrucciones obsoletas

## Hallazgos de alta confianza

### Fusionar o retirar por duplicidad directa

1. `.claude/skills/dispatching-parallel-agents`
   Estado:
   - duplicada funcionalmente por `.agents/skills/dispatching-parallel-agents`
   Observacion:
   - la copia en `.claude` tiene ampliaciones, pero tambien mojibake visible
   Recomendacion:
   - consolidar una sola version y retirar la duplicada
   Estado 2026-04-25:
   - consolidado el contenido util en `.agents`
   - retirada la copia `.claude`

2. `.claude/skills/verification-before-completion`
   Estado:
   - duplicada funcionalmente por `.agents/skills/verification-before-completion`
   Recomendacion:
   - dejar una sola autoridad local antes de promoverla fuera del repo
   Estado 2026-04-25:
   - retirada la copia duplicada en `.claude`

3. `.claude/skills/pou-viario`
   Estado:
   - duplicada funcionalmente por `.agents/skills/pou-viario`
   Estado 2026-04-25:
   - retirada la copia duplicada en `.claude`

4. `.claude/skills/cierre-documental-office`
   Estado:
   - solapa con `.agents/skills/document-closeout-agent`
   Recomendacion:
   - fusionar el valor especifico que falte y retirar la skill corta antigua
   Estado 2026-04-25:
   - el valor especifico util (`check_template_completion.ps1`) ya se absorbio en `.agents/skills/document-closeout-agent`
   - retirada la copia redundante en `.claude`

### Mover fuera del repo o revisar fuerte

1. `.claude/skills/briefing-tecnico`
   Motivo:
   - es una skill generica de proceso, no especifica de Plaza Mayor
   - contiene mojibake visible
   Riesgo:
   - puede imponer un estilo de trabajo ajeno al modo actual del agente
   Estado 2026-04-25:
   - retirada del repo local por ruido operativo y falta de anclaje real en la capa actual

2. `.claude/skills/task-master`
   Motivo:
   - es una skill de gestion general de fases
   - no deberia vivir como autoridad local del proyecto
   - contiene mojibake visible
   Estado 2026-04-25:
   - retirada del repo local por ruido operativo y falta de anclaje real en la capa actual

3. `.claude/skills/council-ingenieria`
   Motivo:
   - skill generica y teatral de debate
   - no tiene implementacion trazable mas alla del texto
   - contiene mojibake visible
   Estado 2026-04-25:
   - retirada del repo local por ruido operativo y por no encajar con el criterio de skills verificables

## Candidatas probables a mover a toolkit

- `control-calidad`
- `fiebdc-parser`
- `redaccion-tecnica`
- `gestion-contexto`
- `glosario-proyecto`

Razon:
- parecen capacidades reutilizables o genericas
- si siguen siendo utiles, su hogar natural no es un repo de proyecto vivo

Estado 2026-04-25:
- retiradas del repo local por alta confianza: `control-calidad`, `fiebdc-parser`, `gestion-contexto`
- `glosario-proyecto` y `redaccion-tecnica` si aportaban valor local, pero se han promovido a versiones canónicas limpias en `.agents/skills`

## Candidatas plausibles a mantener localmente

- `arranque-documental-pou`
- `biblioteca-anejos-trazables`
- `harvest-fuentes-proyecto`
- `matriz-trazabilidad-pou`
- `normalizar-apertura-anejos-pou`
- `sync-apartados-guadalmar`

Razon:
- por nombre, parecen estar mas pegadas al dominio POU o a migraciones concretas entre expedientes
- aun asi, necesitan revision funcional antes de declararlas buenas

## Proximo paso recomendado

1. revisar headers y alcance de las skills restantes de `.claude/skills`
2. clasificar cada una como `mantener`, `fusionar`, `mover`, `retirar`
3. priorizar las genericas reutilizables que en realidad deberian vivir en toolkit y no en un repo vivo
4. resolver la pareja `glosario-proyecto` y `redaccion-tecnica`, que ya no son ruido tan obvio como las retiradas previas

## Estado del solape local a 2026-04-25

- duplicado real restante entre `.claude/skills` y `.agents/skills`: ninguno de alta confianza
- duplicados exactos ya retirados de `.claude`: `verification-before-completion`, `pou-viario`
- duplicados consolidados y retirados de `.claude`: `dispatching-parallel-agents`
- solape funcional ya absorbido en `.agents` y retirado de `.claude`: `cierre-documental-office` -> `document-closeout-agent`
- skills genericas y ruidosas ya retiradas de `.claude`: `briefing-tecnico`, `task-master`, `council-ingenieria`
- skills genericas reutilizables retiradas de `.claude` por no corresponder a un repo vivo: `control-calidad`, `fiebdc-parser`, `gestion-contexto`
- skills locales utiles reescritas y promovidas a `.agents`: `glosario-proyecto`, `redaccion-tecnica`

## Regla operativa

No borrar en lote. Primero consolidar autoridades; despues retirar duplicados.
