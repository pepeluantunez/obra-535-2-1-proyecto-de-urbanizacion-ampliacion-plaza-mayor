# ESTADO_PROYECTO - 535.2.1 Plaza Mayor

> Estado corto y operativo del expediente.
> Ultima revision: 2026-04-30

## Documentacion tecnica

| Elemento | Estado | Nota corta |
| --- | --- | --- |
| Memoria descriptiva | en revision | Word vivo en `DOCS - MEMORIA/` |
| Pliego de condiciones | en revision | Varias versiones en raiz; falta fijar la vigente |
| BC3 maestro del proyecto | activo — seed sin mediciones | `PRESUPUESTO/535.2.1_maestro.bc3`; 671 conceptos, 0 mediciones (~M); mediciones se incorporan progresivamente desde Civil 3D y delineante |
| BC3 de Seguridad y Salud | activo | `DOCS - ANEJOS/17.- Seguridad y Salud/PRESUPUESTO_DONOR/535.2.1-Seguridad & Salud.bc3` |

## Anejos por disciplina

| Anejo | Nombre | Estado | Carpeta en repo |
| --- | --- | --- | --- |
| 1 | Reportaje Fotografico | base util preparada | si |
| 2 | Cartografia y Topografia | arranque completado | si |
| 3 | Estudio Geotecnico | base util preparada | si |
| 4 | Trazado, Replanteo y Mediciones Auxiliares | arranque completado | si |
| 5 | Dimensionamiento del Firme | arranque completado | si |
| 6 | Red de Agua Potable | arranque completado | si |
| 7 | Red de Saneamiento - Pluviales | borrador | si |
| 8 | Red de Saneamiento - Fecales | arranque completado | si |
| 9 | Red de Media Tension | fuera de alcance civil | sin carpeta en DOCS - ANEJOS |
| 10 | Red de Baja Tension | fuera de alcance civil | sin carpeta en DOCS - ANEJOS |
| 11 | Red de Alumbrado | fuera de alcance civil | sin carpeta en DOCS - ANEJOS |
| 12 | Accesibilidad | arranque completado | si |
| 13 | Estudio de Gestion de Residuos | base util preparada | si |
| 14 | Control de Calidad | base util preparada | si |
| 15 | Plan de Obra | base util preparada | si |
| 16 | Comunicaciones con Companias Suministradoras | base util preparada | si |
| 17 | Seguridad y Salud | activo | si — BC3 propio localizado |
| 18 | Telecomunicaciones | fuera de alcance civil | sin carpeta en DOCS - ANEJOS |

Nota: carpetas de anejos 9-11 y 18 no aparecen en `DOCS - ANEJOS/`; los DOCX pueden estar en otra ubicacion o no haberse creado en este repo.

## Infraestructura del repo

| Elemento | Estado | Nota corta |
| --- | --- | --- |
| CLAUDE.md (raiz) | activo | Creado 2026-04-25; version previa en `PLANNING/OPERATIVA/CLAUDE.md` |
| AGENTS.md | activo | Reglas criticas de BC3, mojibake y operativa |
| MAPA_PROYECTO.md | activo | Actualizado 2026-04-25 |
| FUENTES_MAESTRAS.md | activo | Jerarquia de fuentes fijada |
| DECISIONES_PROYECTO.md | activo | Decisiones operativas consolidadas |
| about-me.md | activo | Perfil del tecnico actualizado |
| tools/ | activo | ~44 scripts PS1 + 3 Python (bc3_tools, excel_tools, mediciones_validator) |
| scripts/ | activo | Scripts especificos del proyecto |
| .claude/skills/ | activo | 17 skills locales instaladas |
| CONTROL/trazabilidad/ | activo | nodes.json, edges.json, coverage.json — semilla real |
| CONFIG/ | activo | project_identity.json, repo_contract.json, toolkit.lock.json y perfiles |
| NORMATIVA/ | pendiente | No existe; falta crear e indexar normativa aplicable |
| Trazabilidad transversal | en revision | Falta cerrar jerarquia con BC3 general cuando se cree |
| Cierre de entrega | borrador | No listo para cierre global |

## Cambios recientes

- Raiz limpiada: `findings.md`, `progress.md`, `task_plan.md` y `535.2.2_POU_PLIEGO DE CONDICIONES.docx` movidos a `scratch/`.
- Pliego de trabajo fijado: `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`.
- Base de precios del ecosistema declarada: GMU Malaga PRECIOS_V5_18_05_2023.
- Skills locales clasificadas: 7 a toolkit, 1 mantener local, 1 retirar. Ver `07_CATALOGO_ECOSISTEMA.md`.
- KANBAN reestructurado en dos carriles (expediente tecnico / plataforma).
- Se confirma normativa activa por via compartida (opcion B): `C:\Users\USUARIO\Documents\Claude\Projects\normativa-obra-civil\catalog.json`.

## Pendientes inmediatos

- Crear BC3 maestro de Plaza Mayor con mediciones propias (base: GMU Malaga PRECIOS_V5_18_05_2023).
- Confirmar estado y ubicacion de anejos 9-11 y 18 (sin carpeta activa en `DOCS - ANEJOS/`).
- Cerrar anejo 7 — Red de Saneamiento Pluviales (unico en borrador).
- Eliminar carpeta `career-ops` de `C:\Users\USUARIO\Documents\Claude\Projects\` (repo ajeno al ecosistema).
- Promover las 7 skills maduras al `urbanizacion-toolkit` cuando el toolkit exista como autoridad real.
- Mantener actualizados `MAPA_PROYECTO.md`, `FUENTES_MAESTRAS.md` y `DECISIONES_PROYECTO.md` cuando cambie una fuente activa.
- Definir allowlist de plugins externos para el ecosistema (prioridad: `anthropics/claude-plugins-official`) y bloquear instalacion ad-hoc sin revision.
- Pilotar una skill de "segundo dictamen" tipo LLM Council solo para decisiones criticas (diseno tecnico, trazabilidad, control de cambios), con evidencia y sin automatizar veredictos.
- Montar evaluaciones de regresion de prompts/skills (p.ej. `promptfoo`) para checks de cierre documental, mojibake y trazabilidad.
- Auditar catalogos masivos de skills (VoltAgent/Antigravity) y promover solo las que pasen filtro local de seguridad, mantenimiento y utilidad real.
- Extraer patrones reutilizables de `anthropics/skills` para endurecer skills propias (estructura, validaciones, progressive disclosure) y planificar promotion a toolkit/plantilla.
