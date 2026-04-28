# MAPA_PROYECTO - 535.2.1 Plaza Mayor

> Expediente: 535.2.1
> Nombre corto: Proyecto de Urbanizacion - Ampliacion Plaza Mayor
> Ultima revision: 2026-04-25

## Objeto

Proyecto de urbanizacion de la ampliacion de la Plaza Mayor. El alcance principal en este repo es obra civil y redes humedas: viario, firme, agua potable, saneamiento, accesibilidad, residuos y seguridad y salud.

## Estructura viva del repo

- `CLAUDE.md`: instrucciones de proyecto para Claude (raiz — lectura automatica).
- `AGENTS.md`: reglas operativas del proyecto (complemento a CLAUDE.md).
- `about-me.md`: perfil del tecnico responsable.
- `MAPA_PROYECTO.md`, `FUENTES_MAESTRAS.md`, `DECISIONES_PROYECTO.md`, `ESTADO_PROYECTO.md`: capa corta de contexto del proyecto.
- `DOCS - MEMORIA/`: memoria descriptiva viva.
- `DOCS - ANEJOS/`: anejos tecnicos por disciplina (anejos 1-8, 12-17 con carpeta activa; 9-11 y 18 fuera de alcance civil).
- `DOCS - ANEJOS/Plantillas/`: plantillas base para memoria, anejos y ESS.
- `CONFIG/`: configuracion de trazabilidad, perfiles y plantillas JSON.
- `tools/`: utilidades del proyecto y comprobaciones de cierre (~44 scripts PS1 y Python).
- `scripts/`: automatizaciones especificas del proyecto.
- `PLANNING/KANBAN.md`: gestion ligera del trabajo del repo.
- `PLANNING/OPERATIVA/`: SOPs, estandares, ordenes de trabajo.
- `PLANNING/PLAZA_MAYOR/`: dossier base y antecedentes del proyecto.
- `PLANNING/ECOSISTEMA/`: arquitectura del ecosistema multi-repo.
- `CONTROL/`: trazabilidad, matrices de estado y logs de comprobaciones.
- `CONTROL/trazabilidad/`: red minima de relaciones (nodes.json, edges.json, coverage.json).
- `CONTROL_CALIDAD/`: registro de cambios de calidad.
- `CHECKLISTS/`: checklists de inicio, control y cierre.
- `NORMATIVA/`: carpeta de normativa indexada — **pendiente de crear**.

## Carpetas activas

- `DOCS - MEMORIA/`
- `DOCS - ANEJOS/` (carpetas 1-8, 12-17 con DOCX; 9-11 y 18 existen en proyecto pero fuera de alcance civil)
- `DOCS - ANEJOS/Plantillas/`
- `CONFIG/`
- `tools/`
- `scripts/`
- `PLANNING/`
- `CONTROL/`
- `CONTROL/trazabilidad/`

## No revisar salvo peticion expresa

- `scratch/`: residuos y trabajo temporal de sesiones.
- `.codex_tmp/`: temporales de herramientas.
- `.claude/skills/` y `agents/`: solo si la tarea afecta a skills o agentes.
- `DOCS - ANEJOS/17.- Seguridad y Salud/PRESUPUESTO_DONOR/`: solo para tareas de SyS o BC3 de SyS.
- `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO.docx` y `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`: borradores del pliego.
- `535.2.2_POU_PLIEGO DE CONDICIONES.docx`: archivo de Guadalmar colocado por error en esta raiz — retirar.
- `AMPLIACION PLAZA MAYOR/`: carpeta vacia, sin contenido activo.
- `findings.md`, `progress.md`, `task_plan.md`: residuos de sesiones de agentes — retirar de raiz.
- `PLANNING/OPERATIVA/CLAUDE.md`: version previa de CLAUDE.md; la raiz es la vigente.

## Documentos principales

- Memoria: `DOCS - MEMORIA/Memoria descriptiva - Proyecto de Urbanizacion - Ampliacion Plaza Mayor.docx`
- Pliego: ver `FUENTES_MAESTRAS.md`; hay varias versiones en raiz y no hay una definitiva confirmada.
- Anejo 17: `DOCS - ANEJOS/17.- Seguridad y Salud/Anexo 17 - Estudio de Seguridad y Salud.docx`
- Plantilla maestra de anejos: `DOCS - ANEJOS/Plantillas/PLANTILLA_MAESTRA_ANEJOS.docx`

## Rutina minima de triage local

La autoridad futura de triage debe vivir en `urbanizacion-toolkit`. Mientras Plaza Mayor converge, aplicar este bloque minimo antes de abrir medio repo:

```text
Tipo de tarea:
Objetivo exacto:
Fuente maestra:
Archivos a leer:
Archivos a ignorar:
Dependencias minimas:
Modo de trabajo:
Salida esperada:
Criterio de cierre:
```

Reglas de corte:

- Si `Archivos a leer` supera 5 rutas sin justificarlo, reducir.
- Si la tarea mezcla proyecto, plantilla y toolkit, separar primero por capa.
- Si no hay `Fuente maestra` identificada, no editar todavia.
- Si hay conflicto de vigencia, consultar `FUENTES_MAESTRAS.md` antes de editar.
- Si el objetivo no identifica una salida concreta, no empezar aun.
- Si no existe `Criterio de cierre` verificable, convertirlo antes de ejecutar.

## Relacion entre memoria, anejos, Excel, BC3, tablas e informes

- La memoria resume y consolida informacion derivada de anejos y fuentes tecnicas.
- Cada anejo tecnico debe apoyarse en su fuente de calculo o medicion correspondiente.
- Si existe Excel de calculo o medicion para un anejo, ese Excel manda sobre la tabla Word del mismo anejo.
- No existe todavia un BC3 maestro activo del proyecto; el unico BC3 localizado es el de Seguridad y Salud.
- El BC3 de SyS solo gobierna el ambito del anejo 17; no sustituye a un BC3 general del proyecto.
- La capa verificable de esta relacion ya no debe vivir solo en matrices sueltas: `CONTROL/trazabilidad/nodes.json`, `edges.json` y `coverage.json` fijan la red minima.

## Dependencias principales

- Plantillas DOCX en `DOCS - ANEJOS/Plantillas/`
- Configuracion de trazabilidad en `CONFIG/`
- Semilla de trazabilidad real en `CONTROL/trazabilidad/`
- Scripts y comprobaciones en `tools/` y `scripts/`
- Fuentes tecnicas por anejo dentro de `DOCS - ANEJOS/`

## Recursos compartidos del ecosistema

Fuera de este repo pero accesibles desde `C:\Users\USUARIO\Documents\Claude\Projects\`:

- `bases-precios-compartidas/` — `GMU-Malaga-2023.bc3` (base de precios fuente), `PRESTO PAVIGESA 2025.3.bc3`, `535.2.2 - PARTIDAS GERENCIA.bc3`
- `normativa-obra-civil/` — corpus normativo compartido; usar `catalog.json` antes de citar cualquier norma en un anejo
- `shared-tools/` — `bc3_tools.py`, `excel_tools.py`, `mediciones_validator.py` (herramientas canonicas)

## Limites de alcance

- Alcance principal de trabajo en este repo: civil, redes humedas, accesibilidad, residuos y SyS.
- Anejos 9, 10 y 11: parte electrica, no tocar salvo orden expresa.
- Anejo 18: telecomunicaciones, no tocar salvo orden expresa.
- No usar este repo como plantilla base ni como toolkit reutilizable.
