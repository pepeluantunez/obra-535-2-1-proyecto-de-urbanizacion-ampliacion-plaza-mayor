# MAPA_PROYECTO - 535.2.1 Plaza Mayor

> Expediente: 535.2.1
> Nombre corto: Proyecto de Urbanizacion - Ampliacion Plaza Mayor

## Objeto

Proyecto de urbanizacion de la ampliacion de la Plaza Mayor. El alcance principal en este repo es obra civil y redes humedas: viario, firme, agua potable, saneamiento, accesibilidad, residuos y seguridad y salud.

## Estructura viva del repo

- `AGENTS.md`: reglas operativas del proyecto.
- `MAPA_PROYECTO.md`, `FUENTES_MAESTRAS.md`, `DECISIONES_PROYECTO.md`, `ESTADO_PROYECTO.md`, `TRIAGE.md`: capa corta de contexto del proyecto.
- `DOCS - MEMORIA/`: memoria descriptiva viva.
- `DOCS - ANEJOS/`: anejos tecnicos por disciplina.
- `DOCS - ANEJOS/Plantillas/`: plantillas base para memoria, anejos y ESS.
- `CONFIG/`: configuracion de trazabilidad, perfiles y plantillas JSON.
- `tools/`: utilidades del proyecto y comprobaciones de cierre.
- `scripts/`: automatizaciones especificas del proyecto.
- `PLANNING/`, `CONTROL/`, `CONTROL_CALIDAD/`, `CHECKLISTS/`: seguimiento y control operativo.

## Carpetas activas

- `DOCS - MEMORIA/`
- `DOCS - ANEJOS/`
- `DOCS - ANEJOS/Plantillas/`
- `CONFIG/`
- `tools/`
- `scripts/`
- `PLANNING/`
- `CONTROL/`

## No revisar salvo peticion expresa

- `scratch/`: residuos y trabajo temporal de sesiones.
- `.codex_tmp/`: temporales de herramientas.
- `.claude/skills/` y `agents/`: solo si la tarea afecta a skills o agentes.
- `DOCS - ANEJOS/17.- Seguridad y Salud/PRESUPUESTO_DONOR/`: solo para tareas de SyS o BC3 de SyS.
- `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO.docx` y `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`: borradores del pliego.
- `535.2.2_POU_PLIEGO DE CONDICIONES.docx`: archivo de Guadalmar colocado por error en esta raiz.

## Documentos principales

- Memoria: `DOCS - MEMORIA/Memoria descriptiva - Proyecto de Urbanizacion - Ampliacion Plaza Mayor.docx`
- Pliego: ver `FUENTES_MAESTRAS.md`; hay varias versiones en raiz y no hay una definitiva confirmada.
- Anejo 17: `DOCS - ANEJOS/17.- Seguridad y Salud/Anexo 17 - Estudio de Seguridad y Salud.docx`
- Plantilla maestra de anejos: `DOCS - ANEJOS/Plantillas/PLANTILLA_MAESTRA_ANEJOS.docx`

## Relacion entre memoria, anejos, Excel, BC3, tablas e informes

- La memoria resume y consolida informacion derivada de anejos y fuentes tecnicas.
- Cada anejo tecnico debe apoyarse en su fuente de calculo o medicion correspondiente.
- Si existe Excel de calculo o medicion para un anejo, ese Excel manda sobre la tabla Word del mismo anejo.
- No existe todavia un BC3 maestro activo del proyecto; el unico BC3 localizado es el de Seguridad y Salud.
- El BC3 de SyS solo gobierna el ambito del anejo 17; no sustituye a un BC3 general del proyecto.

## Dependencias principales

- Plantillas DOCX en `DOCS - ANEJOS/Plantillas/`
- Configuracion de trazabilidad en `CONFIG/`
- Scripts y comprobaciones en `tools/` y `scripts/`
- Fuentes tecnicas por anejo dentro de `DOCS - ANEJOS/`

## Limites de alcance

- Alcance principal de trabajo en este repo: civil, redes humedas, accesibilidad, residuos y SyS.
- Anejos 9, 10 y 11: parte electrica, no tocar salvo orden expresa.
- Anejo 18: telecomunicaciones, no tocar salvo orden expresa.
- No usar este repo como plantilla base ni como toolkit reutilizable.
