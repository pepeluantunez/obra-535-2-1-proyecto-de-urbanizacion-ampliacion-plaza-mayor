# Auditoria De Ruido Del Repo

Fecha: 2026-04-25
Alcance: `obra-535-2-1-proyecto-de-urbanizacion-ampliacion-plaza-mayor`

## Regla de trabajo

Eliminar solo lo que tenga evidencia de sobra o desplazamiento. Si hay trabajo vivo o vigencia dudosa, no borrar: mover o decidir primero.

## Hallazgos

### Retirada ya encaminada, no restaurar

Estos artefactos aparecen retirados del working tree. La señal es buena: no conviene reintroducirlos en raiz.

- `TRIAGE.md`
- `ESTANDARES.md`
- `COMANDOS_RAPIDOS_MAQUETACION.md`
- `PLANTILLA_ORDEN_TRABAJO.md`
- `GUIA_FUNCIONAMIENTO_SKILLS_AGENTES_2026-04-14.md`
- `GUIA_OPERATIVA_AGENTES_STRICT_2026-04-14.md`
- `PACK_SKILLS_URBANIZACION_VERIFICADO_2026-04-14.md`

Motivo:
- duplicaban o fragmentaban autoridad que ahora ya esta absorbida por `MAPA_PROYECTO.md`, `FUENTES_MAESTRAS.md`, `DECISIONES_PROYECTO.md`, `AGENTS.md` y `CONFIG/repo_contract.json`

### Candidato serio a democion desde raiz

- `CLAUDE.md`

Motivo:
- `tools/check_repo_contract.ps1` sigue emitiendo una advertencia explicita sobre este archivo en raiz
- si su contenido ya esta absorbido por las autoridades cortas y por `AGENTS.md`, mantenerlo arriba vuelve a meter otra capa de entrada

Accion recomendada:
- revisar si contiene algo todavia exclusivo
- si no lo contiene, moverlo a `PLANNING/OPERATIVA/` o retirarlo

Estado 2026-04-25:
- retirado del working tree local tras comprobar duplicacion funcional y mojibake visible

### Candidato fuerte a salir de raiz

- `535.2.2_POU_PLIEGO DE CONDICIONES.docx`

Motivo:
- `FUENTES_MAESTRAS.md` lo marca como ajeno a Plaza Mayor
- molesta en raiz y contamina lectura

Accion recomendada:
- mover fuera del repo o archivar en ubicacion correcta del expediente al que pertenece

### Mantener por ahora, pero decidir pronto

- `535.2.1_POU_PLIEGO DE CONDICIONES.docx`
- `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO.docx`
- `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`

Motivo:
- siguen siendo borradores con vigencia no cerrada
- no deben vivir indefinidamente en raiz, pero borrarlos ahora seria prematuro

Accion recomendada:
- fijar cual manda y archivar o mover el resto cuando haya decision expresa

### Inflacion de skills locales

- `.claude/skills/` contiene 22 skills locales
- `.agents/skills/` contiene 4 skills locales

Lectura:
- hay mas conocimiento operativo del que hoy cabe mantener con criterio en un proyecto vivo
- es probable que parte de estas skills deba fusionarse, moverse al toolkit o retirarse

Accion recomendada:
- inventario funcional skill por skill
- clasificar cada una como `mantener`, `mover a toolkit`, `fusionar`, `retirar`

### No es ruido ahora mismo

- `task_plan.md`, `findings.md`, `progress.md`
  Motivo: memoria operativa de la sesion

- `535.2.1-Seguridad & Salud.bc3.bak`
  Motivo: `FUENTES_MAESTRAS.md` ya indica conservar la copia `.bak` para recuperacion si hace falta

- `AGENTS.md`, `MAPA_PROYECTO.md`, `FUENTES_MAESTRAS.md`, `DECISIONES_PROYECTO.md`, `ESTADO_PROYECTO.md`
  Motivo: forman la capa corta de autoridad actual

## Siguiente limpieza con mejor ROI

1. sacar de raiz el pliego ajeno `535.2.2_*`
2. cerrar la vigencia del pliego de Plaza Mayor y archivar duplicados
3. auditar `.claude/skills` para adelgazar lo que no aporte
4. revisar si `verification-before-completion` y `document-closeout-agent` deben fusionarse cuando salgan a capa comun
5. consolidar duplicados directos entre `.claude/skills` y `.agents/skills`
6. seguir recortando duplicados exactos entre `.claude/skills` y `.agents/skills` cuando aparezcan nuevos
7. seguir retirando skills genericas con mojibake y sin anclaje real en la operativa actual del repo
8. revisar `about-me.md` como posible autoridad residual que aun nombra skills ya retiradas

Estado 2026-04-25:
- `about-me.md` ya fue saneado para eliminar referencias obsoletas a skills retiradas y marcos ficticios
- `glosario-proyecto` y `redaccion-tecnica` no se retiraron como ruido: se conservaron como capacidad local, pero reescritas en `.agents/skills`
