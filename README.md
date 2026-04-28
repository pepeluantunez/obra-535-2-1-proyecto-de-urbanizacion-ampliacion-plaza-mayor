# obra-535-2-1-proyecto-de-urbanizacion-ampliacion-plaza-mayor

Repositorio vivo del expediente `535.2.1`, centrado en documentacion tecnica, anejos, memoria y automatizacion especifica de Plaza Mayor.

## Rol del repo

Aqui deben vivir solo piezas propias del proyecto:

- identidad del expediente
- fuentes maestras, decisiones y estado operativo
- memoria y anejos tecnicos
- scripts y tools especificos de Plaza Mayor
- control de trazabilidad local
- red minima de trazabilidad verificable

No debe actuar como plantilla base ni como toolkit reutilizable.

## Gobierno operativo

La autoridad operativa de este repo se reparte asi:

- `MAPA_PROYECTO.md`: punto de entrada, limites y triage minimo.
- `FUENTES_MAESTRAS.md`: autoridad documental y jerarquia entre fuentes.
- `DECISIONES_PROYECTO.md`: criterios ya fijados para trabajar sin reabrir debates locales.
- `AGENTS.md`: reglas especificas de Plaza Mayor, cierres y comandos de comprobacion del proyecto.
- `CONFIG/repo_contract.json`: guardarrailes para evitar inflar la raiz o mezclar capas de ecosistema.

Si una regla o SOP es comun a varios proyectos, no debe consolidarse aqui como autoridad final.

## Punto de entrada corto

Antes de una tarea no trivial, leer en este orden:

1. `MAPA_PROYECTO.md`
2. `FUENTES_MAESTRAS.md`
3. `DECISIONES_PROYECTO.md`
4. `ESTADO_PROYECTO.md`
5. `AGENTS.md`

La rutina minima de triage local ya esta resumida dentro de `MAPA_PROYECTO.md`; no necesita vivir como autoridad separada en raiz.

## Contrato estructural

Este repo ya declara su contrato minimo en:

- `CONFIG/project_identity.json`
- `CONFIG/toolkit.lock.json`
- `CONFIG/repo_contract.json`

Validacion local:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_repo_contract.ps1 -ContractPath .\CONFIG\repo_contract.json -RootPath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_traceability_graph_seed.ps1 -NodesPath .\CONTROL\trazabilidad\nodes.json -EdgesPath .\CONTROL\trazabilidad\edges.json -CoveragePath .\CONTROL\trazabilidad\coverage.json -RootPath .
```

La raiz debe ir reduciendose. La operativa secundaria y la documentacion de migracion se agrupan en `PLANNING/OPERATIVA/` y `PLANNING/ECOSISTEMA/`.
La gestion ligera del trabajo local vive en `PLANNING/KANBAN.md`.

## Estructura principal

- `DOCS - MEMORIA/`
- `DOCS - ANEJOS/`
- `CONFIG/`
- `tools/`
- `scripts/`
- `PLANNING/`
- `CHECKLISTS/`
- `CONTROL/`
- `CONTROL_CALIDAD/`

Dentro de `CONTROL/`, la carpeta `trazabilidad/` pasa a ser la capa minima verificable de relaciones y cobertura. Las matrices o informes legibles siguen siendo utiles, pero ya no deben ser la unica representacion.
