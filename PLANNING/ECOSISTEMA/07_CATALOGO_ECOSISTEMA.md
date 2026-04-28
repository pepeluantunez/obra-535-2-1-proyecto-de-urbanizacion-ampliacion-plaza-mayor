# Catalogo Canonico Del Ecosistema

Fecha: 2026-04-25
Estado: canonico local mientras la capa comun no viva fuera de Plaza Mayor

## Objetivo

Ser el punto unico de verdad para:

- skills canonicas activas
- agentes implantados o en semilla
- checks canonicos
- piezas retiradas
- piezas candidatas a toolkit o capa comun

Si este catalogo contradice notas antiguas o restos de sesiones, manda este catalogo.

## Principios transversales

Todo lo que se conserve o promueva en el ecosistema debe respetar:

1. pensar antes de ejecutar
2. simplicidad primero
3. cambios quirurgicos
4. cierre verificable
5. contexto explicito en cada handoff
6. no duplicar autoridad local en raiz

## Skills canonicas activas en `.agents/skills`

### Coordinacion y cierre

1. `ecosystem-triage`
   Rol:
   - coordinador de entrada
   Estado:
   - activo
   Uso:
   - clasificar tarea
   - fijar fuente maestra
   - fijar carril y checks
   Destino futuro:
   - toolkit o repo ecosistema

2. `document-closeout-agent`
   Rol:
   - cierre documental y mixto
   Estado:
   - activo
   Uso:
   - office
   - placeholders
   - layout
   - formulas
   - trazabilidad
   Destino futuro:
   - toolkit o repo ecosistema

3. `verification-before-completion`
   Rol:
   - cierre estricto legado reutilizable
   Estado:
   - activo, pero convergente
   Nota:
   - debe converger con `document-closeout-agent`, no competir con el
   Destino futuro:
   - fusionar o simplificar

4. `dispatching-parallel-agents`
   Rol:
   - orquestacion paralela sobria
   Estado:
   - activo
   Uso:
   - solo cuando el usuario pida agentes o el flujo lo justifique de verdad
   Destino futuro:
   - toolkit o repo ecosistema

### Dominio y redaccion

5. `glosario-proyecto`
   Rol:
   - mantener terminologia estable del expediente
   Estado:
   - activo
   Destino futuro:
   - probablemente toolkit con extension local por proyecto

6. `redaccion-tecnica`
   Rol:
   - revision y redaccion tecnica alineada con Plaza Mayor
   Estado:
   - activo
   Destino futuro:
   - toolkit con capa local de estilo

7. `pou-viario`
   Rol:
   - skill de dominio POU viario
   Estado:
   - activo
   Destino futuro:
   - revisar si debe quedarse local o moverse a toolkit

8. `pliego-condiciones-adaptable`
   Rol:
   - adaptacion de pliegos
   Estado:
   - activo
   Destino futuro:
   - puede vivir en toolkit si se usa entre expedientes

## Agentes en semilla o backlog prioritario

1. `Traceability Drift Agent`
   Estado:
   - listo para semilla
   Base:
   - `tools/check_traceability_consistency.ps1`
   - `tools/run_traceability_profile.ps1`

2. `Repo Governance Agent`
   Estado:
   - listo para semilla
   Base:
   - `tools/check_repo_contract.ps1`
   - `CONFIG/repo_contract.json`

3. `BC3 Safety Agent`
   Estado:
   - listo para semilla
   Base:
   - `tools/bc3_snapshot.ps1`
   - `tools/bc3_diff_report.ps1`
   - `tools/check_bc3_integrity.ps1`

4. `Slack Intake Agent`
   Estado:
   - no iniciado
   Dependencia:
   - triage y closeout estabilizados

5. `AGENTE_COHERENCIA_TOTAL`
   Estado:
   - semilla local en `technical_direction/`
   Base:
   - `CONTROL/trazabilidad/*`
   - `FUENTES_MAESTRAS.md`
   - `ESTADO_PROYECTO.md`
   Valor:
   - detectar incoherencias entre memoria, anejos, planos, presupuesto y plan de obra antes de entrega

6. `OUTPUT_CATALOG_PREMIUM`
   Estado:
   - semilla local en `technical_direction/`
   Valor:
   - convertir la produccion AI en un menu profesional de salidas premium y no solo basicas

7. `AGENTE_REVISOR_DURO`
   Estado:
   - semilla local en `technical_direction/`
   Base:
   - `technical_direction/APPROVAL_RISKS/APPROVAL_RISKS.md`
   - `technical_direction/DECISION_SYSTEM/DECISION_LOG.md`
   - `CONTROL/trazabilidad/*`
   Valor:
   - revisar el expediente con criterio duro antes de entrega o revision interna exigente

## Checks canonicos del ecosistema local

### Documental

- `tools/check_office_mojibake.ps1`
- `tools/check_docx_tables_consistency.ps1`
- `tools/check_excel_formula_guard.ps1`
- `tools/check_template_completion.ps1`
- `tools/run_project_closeout.ps1`
- `tools/run_estandar_proyecto.ps1`

### Trazabilidad y gobierno

- `tools/check_traceability_consistency.ps1`
- `tools/run_traceability_profile.ps1`
- `tools/check_repo_contract.ps1`
- `tools/check_normativa_scope.ps1`

### BC3

- `tools/bc3_snapshot.ps1`
- `tools/bc3_diff_report.ps1`
- `tools/check_bc3_integrity.ps1`

## Piezas retiradas o absorbidas

### Retiradas de `.claude/skills`

- `verification-before-completion`
- `pou-viario`
- `dispatching-parallel-agents`
- `cierre-documental-office`
- `briefing-tecnico`
- `task-master`
- `council-ingenieria`
- `control-calidad`
- `fiebdc-parser`
- `gestion-contexto`
- `glosario-proyecto`
- `redaccion-tecnica`

### Autoridades o ruido retirado/saneado

- `CLAUDE.md` en raiz
- referencias obsoletas y marcos ficticios en `about-me.md`

## Clasificacion de skills locales en `.claude/skills`

Revision funcional completada 2026-04-27.

### Promover a toolkit (7 skills)

Cumplen el criterio: funcionan sin contexto oculto, inputs/outputs claros, sin rutas exclusivamente locales, valor en mas de un expediente.

- `anejo-generator` — genera borradores de anejos desde Excel y plantillas; parametrizable
- `arranque-documental-pou` — arranque documental seguro via `project_identity.json`
- `biblioteca-anejos-trazables` — convierte trazabilidad DOCX/XLSX en plantillas reutilizables; disenada para multi-proyecto
- `harvest-fuentes-proyecto` — extrae y consolida fuentes/antecedentes; sin dependencias locales
- `matriz-trazabilidad-pou` — vista de estado documental y cruces obligatorios; transversal
- `mediciones-validator` — cruza BC3 vs Excel; madura y referenciada en CLAUDE.md como herramienta core
- `redaccion-controlada-anejo` — redaccion solo con fuentes verificadas; generica
- `revision-ortotipografica-docx` — revision ortotipografica de DOCX; sin contexto de proyecto

### Mantener local hasta desacoplar (1 skill)

- `normalizar-apertura-anejos-pou` — normaliza portada, indice y apartado 1.OBJETO; depende de `sync_docx_section_names_from_guadalmar.ps1` con ruta Guadalmar hardcodeada; promover cuando se desacople el donor

### Retirar tras implantacion de plantilla-base (1 skill)

- `sync-apartados-guadalmar` — copia estructura de indices desde Guadalmar como donor; util para bootstrap de Plaza Mayor ahora pero tiene dependencia hardcodeada de Guadalmar; retirar cuando `urbanizacion-plantilla-base` este operativa como donor canonico

## Candidatas a toolkit o capa comun

Por madurez o reutilizacion probable (de `.agents/skills` y revision 2026-04-27 de `.claude/skills`):

- `ecosystem-triage`
- `document-closeout-agent`
- `dispatching-parallel-agents`
- `glosario-proyecto`
- `redaccion-tecnica`
- `pliego-condiciones-adaptable`
- `anejo-generator`
- `arranque-documental-pou`
- `biblioteca-anejos-trazables`
- `harvest-fuentes-proyecto`
- `matriz-trazabilidad-pou`
- `mediciones-validator`
- `redaccion-controlada-anejo`
- `revision-ortotipografica-docx`

## Criterio de promocion a toolkit

Una pieza puede salir de Plaza Mayor cuando:

1. ya funciona sin depender de contexto oculto
2. tiene inputs y outputs claros
3. no depende de nombres o rutas exclusivamente locales
4. reusa checks existentes sin reabrir gobierno
5. aporta valor a mas de un expediente

## Regla de mantenimiento

Cada vez que se:

- cree una skill nueva
- retire una skill vieja
- promueva una skill a `.agents`
- declare una pieza lista para toolkit

hay que actualizar este catalogo en la misma iteracion.
