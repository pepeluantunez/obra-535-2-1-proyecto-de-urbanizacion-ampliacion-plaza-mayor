# KANBAN - 535.2.1 Plaza Mayor

Gestion ligera del trabajo del repo. Sin story points, sin burocracia.
Dos carriles separados: expediente tecnico (A) y plataforma/toolkit (B).

## Regla minima

Cada item debe indicar:

- `owner`
- `prioridad`: `P1`, `P2` o `P3`
- `done`: prueba o control exigido para cerrarlo
- `bloqueo`: solo si existe

---

## CARRIL A — Expediente tecnico 535.2.1

Producir el expediente: anejos cerrados, mediciones cuadradas, BC3 coherente.

---

### [A] Decisiones pendientes — desbloquear antes de ejecutar

- `[P1] Decidir si se crea BC3 maestro general y con que fuente de medicion` ✓ RESUELTO
  owner: JL
  done: decision registrada en `DECISIONES_PROYECTO.md` y `FUENTES_MAESTRAS.md` — donor partidas Guadalmar, precio GMU Malaga PRECIOS_V5_18_05_2023, mediciones progresivas Civil 3D y delineante

- `[P1] Fijar el pliego vigente y retirar versiones antiguas de raiz` ✓ RESUELTO
  owner: JL
  done: pliego de trabajo = `535.2.1_POU_PLIEGO DE CONDICIONES_REFINADO_v2.docx`; `535.2.2_POU_PLIEGO DE CONDICIONES.docx` movido a `scratch/`; `FUENTES_MAESTRAS.md` actualizado

---

### [A] Ready

- `[P1] Crear BC3 maestro de Plaza Mayor — estructura inicial sin mediciones` ✓ HECHO
  owner: Claude
  done: `PRESUPUESTO/535.2.1_maestro.bc3` creado — 671 conceptos, 0 mediciones; validate: 0 errores criticos (aviso leve GR-1.18); SHA256: 9BD753143AAA4FE68844EB329E21ECBBA2BA03CC6FD4116BC838EA4DB12A8B78; 19 errores jerarquia donor corregidos; recalc ejecutado (PEM = 5.108.559,83 EUR); `FUENTES_MAESTRAS.md` y `MANIFEST_VIGENCIA.md` actualizados

- `[P1] Auditar libros Excel con arrastre visible de Guadalmar` ✓ RESUELTO
  owner: JL
  done: todos los Excels del repo son donor/plantilla en estado esperado — misma estructura que Guadalmar, pendientes de recibir datos propios de Plaza Mayor conforme avance el proyecto. No hay arrastre de datos falsos.

- `[P1] Limpiar residuos de raiz` ✓ HECHO
  owner: JL / Claude
  done: `findings.md`, `progress.md`, `task_plan.md` y `535.2.2_POU_PLIEGO DE CONDICIONES.docx` movidos a `scratch/`

- `[P1] Cerrar anejo 7 — Red de Saneamiento Pluviales`
  owner: JL
  bloqueo: sin datos de Civil 3D ni calculo hidrologico de Plaza Mayor — proceso identico a Guadalmar, distintas subcuencas y geometria de red
  done: Excel de calculo con subcuencas y caudales de Plaza Mayor; exportacion Civil 3D/SSA con colectores dimensionados; Word con tablas captionadas coherentes con Excel y BC3; control anti-mojibake pasado

- `[P1] Resolver huecos del working tree — anejos 9, 10, 11 y 18` ✓ HECHO
  owner: JL / Claude
  done: anejos 9, 10 y 11 → `out_of_scope` (tecnico electrico externo); anejo 18 → `does_not_exist` (el expediente termina en el 17). Registrado en `DECISIONES_PROYECTO.md` y `CONTROL/trazabilidad/nodes.json`.

- `[P2] Cerrar anejo 5 — Dimensionamiento del Firme`
  owner: JL
  done: Word, Excel de calculo y partidas BC3 coherentes; tablas captionadas; control anti-mojibake pasado

- `[P2] Cerrar anejo 6 — Red de Agua Potable`
  owner: JL
  done: Word, Excel de medicion y partidas BC3 coherentes; tablas captionadas; control anti-mojibake pasado

- `[P2] Cerrar anejo 8 — Red de Saneamiento Fecales`
  owner: JL
  done: Word, Excel de medicion y partidas BC3 coherentes; tablas captionadas; control anti-mojibake pasado

- `[P2] Cerrar anejo 12 — Accesibilidad`
  owner: JL
  done: Word y fuente tecnica coherentes; tablas captionadas con Decreto 293/2009 referenciado; control anti-mojibake pasado

- `[P2] Poblar la capa DATA con datos trazables reales`
  owner: JL
  done: `DATA/presupuesto_normalizado.csv`, `DATA/cronograma_base.csv` y `DATA/redes/*.csv` contienen filas reales de Plaza Mayor trazadas a fuente; manifest en `CONTROL/ai_runs/`
  nota: sin bloqueo — se puebla progresivamente conforme entren mediciones de Civil 3D y del delineante

- `[P2] Extender la gramatica de trazabilidad a agua potable, pluviales y fecales`
  owner: JL
  done: nodos `word_table`, `excel_source` o `bc3_concept` presentes en `CONTROL/trazabilidad/` para anejos 6, 7 y 8

- `[P2] Declarar tablas o manifest estable en SyS para trazabilidad Word`
  owner: JL
  done: anejo 17 declara piezas Word verificables ademas de `excel` y `bc3` en `CONTROL/trazabilidad/`

- `[P3] Crear NORMATIVA/ e indexar normativa aplicable`
  owner: JL
  done: carpeta `NORMATIVA/` existe; `catalog.json` operativo con PG-3, PGOU, Decreto 293/2009, RD 1627/1997 y RD 140/2003 accesibles

---

---

### [A] Done

- `[P1] Contrato estructural del repo`
  owner: codex
  done: `tools/check_repo_contract.ps1` devuelve `0 errors / 0 warnings`

- `[P1] Limpieza de autoridad duplicada en raiz`
  owner: codex
  done: `TRIAGE.md` y operativa secundaria salen de raiz y quedan absorbidos o archivados

- `[P1] Semilla minima de trazabilidad real`
  owner: codex
  done: `nodes.json`, `edges.json`, `coverage.json` y `tools/check_traceability_graph_seed.ps1` presentes y validados

- `[P1] Abrir memoria principal por secciones utiles`
  owner: codex
  done: `CONTROL/trazabilidad` enlaza memoria con anejos disciplinarios clave

- `[P1] Declarar tablas Word con fuente Excel en residuos y control de calidad`
  owner: codex
  done: `CONTROL/trazabilidad` declara tablas captionadas de anejos 13 y 14 con su fuente Excel

- `[P1] Bajar SyS de archivo BC3 a conceptos trazables`
  owner: codex
  done: `bc3.17.sys` deja de ser nodo unico y ya enlaza bloques Q409C1-Q409C4

- `[P1] Definir contratos minimos por anejo para salidas tecnicas y validaciones`
  owner: codex
  done: existe `technical_direction/anejo_contracts/` con contratos semilla para anejos 7, 8, 14, 15 y 17

- `[P1] Implantar capa de direccion tecnica digital`
  owner: codex
  done: existen `technical_direction/OUTPUT_CATALOG_PREMIUM.md`, `technical_direction/AGENTE_COHERENCIA_TOTAL.md` y `technical_direction/DECISION_SYSTEM/DECISION_LOG.md`

- `[P2] Crear capa de riesgos de aprobacion y revision dura`
  owner: codex
  done: existen `technical_direction/APPROVAL_RISKS/` y `technical_direction/AGENTE_REVISOR_DURO.md`

- `[P1] Crear capa minima DATA para outputs premium`
  owner: codex
  done: existen `DATA/presupuesto_normalizado.csv`, `DATA/cronograma_base.csv` y `DATA/redes/*.csv` como esqueleto profesional

- `[P1] Poblar presupuesto_normalizado.csv con la primera slice trazable`
  owner: codex
  done: `DATA/presupuesto_normalizado.csv` incluye ambito SyS trazado al BC3 maestro de SyS y manifest en `CONTROL/ai_runs/`

---

## CARRIL B — Plataforma y toolkit

Construir la maquina reutilizable: toolkit, plantilla-base, repos limpios.
Referencia: `PLANNING/ECOSISTEMA/2026-04-22-maquina-perfecta.md`

---

### [B] Ready

- `[P1] Clasificar las 10 skills locales pendientes de revision funcional` ✓ HECHO
  owner: Claude / JL
  done: 7 promover a toolkit, 1 mantener local hasta desacoplar, 1 retirar tras plantilla-base; decisiones en `07_CATALOGO_ECOSISTEMA.md` (2026-04-27)

- `[P2] Promover skills maduras al toolkit` ✓ HECHO
  owner: Claude
  done: 8 skills copiadas a `Projects/urbanizacion-toolkit/skills/`: anejo-generator, arranque-documental-pou, biblioteca-anejos-trazables, harvest-fuentes-proyecto, matriz-trazabilidad-pou, mediciones-validator, redaccion-controlada-anejo, revision-ortotipografica-docx (2026-04-27)

- `[P2] Decontaminar Guadalmar — eliminar repos anidados y residuos` ◑ EN CURSO
  owner: JL
  nota: `urbanizacion-toolkit` y `urbanizacion-plantilla-base` copiados a `Projects/` (2026-04-27). JL debe borrar manualmente las 3 carpetas de Guadalmar (sandbox sin permisos de borrado).
  done: `urbanizacion-toolkit/`, `urbanizacion-plantilla-base/` y `00_PLANTILLA_BASE/` eliminados del repo de Guadalmar; `CONFIG/toolkit.lock.json` y `CONFIG/repo_contract.json` instalados; `check_repo_contract.ps1` devuelve `0 errors`

- `[P2] Reconstruir urbanizacion-plantilla-base como producto real` ✓ HECHO
  owner: JL / Claude
  done: `nuevo_proyecto.ps1` creado — arranque interactivo en un comando; bootstrap manifest completo con todos los tools nuevos; sync_from_toolkit con path canonico corregido; lecciones_operativas.md incluida en template; CLAUDE.md actualizado (2026-04-27)

- `[P3] Implantar verificacion de estructura en CI en todos los repos`
  owner: JL
  done: `.github/workflows/validate-structure.yml` activo en Plaza Mayor, Guadalmar y toolkit; ningun merge bypasea el contrato estructural

---

### [B] Blocked

- `[P2] Promover toolkit a autoridad real del ecosistema`
  owner: JL
  bloqueo: depende de clasificacion de skills y de que Plaza Mayor este estabilizado como repo limpio primero
  done: `AGENTS_CORE.md` fusionado en `AGENTS.md`; tools y scripts genericos movidos fuera de repos de proyecto; repos de proyecto usan wrappers, no copias de logica global; `07_CATALOGO_ECOSISTEMA.md` actualizado

---

### [B] Done

- `[P1] Clasificar skills y crear BC3 maestro` ✓ — ver items de Ready marcados HECHO

- `[P2] Toolkit operativo como autoridad del ecosistema` ✓ HECHO
  owner: Claude
  done: 8 skills en `toolkit/skills/`; catalog.json con 41 items; CLAUDE.md creado; `ecosystem_health_check.ps1` en `toolkit/scripts/`; `sync_from_toolkit.ps1` corregido en Plaza Mayor y plantilla-base (path canonico + sync de skills); `check_tools_sync.ps1` apunta a toolkit como fuente canonica; duplicidad shared-tools resuelta (2026-04-27)
