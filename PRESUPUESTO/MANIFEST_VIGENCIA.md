# MANIFEST_VIGENCIA — Presupuesto 535.2.1 Plaza Mayor

## Archivo maestro

| Campo | Valor |
|---|---|
| Archivo | `535.2.1_maestro.bc3` |
| Estado | seed activo — sin mediciones |
| Creado | 2026-04-27 |
| Conceptos | 671 |
| Mediciones (~M) | 0 — se incorporan progresivamente |
| SHA256 | 9BD753143AAA4FE68844EB329E21ECBBA2BA03CC6FD4116BC838EA4DB12A8B78 |

## Origen y autoridad

| Capa | Fuente |
|---|---|
| Partidas donor | `bases-precios-compartidas/535.2.2 - PARTIDAS GERENCIA.bc3` (Guadalmar) |
| Precio unitario | GMU Malaga — PRECIOS_V5_18_05_2023 (`bases-precios-compartidas/GMU-Malaga-2023.bc3`) |
| Mediciones | Civil 3D (viario y redes) + delineante — incorporacion progresiva |

## Estructura de capitulos heredada de Guadalmar

| Capitulo | Descripcion | Alcance Plaza Mayor |
|---|---|---|
| MCG-1# | OBRAS MEJORA | capitulo raiz |
| MCG-1.01# | DEMOLICIONES Y SERVICIOS AFECTADOS | activo |
| MCG-1.02# | MOVIMIENTO DE TIERRAS | activo |
| MCG-1.03# | PAVIMENTACION, ACERADO Y BORDILLOS | activo |
| MCG-1.04# | RED DE SANEAMIENTO: AGUAS PLUVIALES | activo |
| MCG-1.05# | RED DE SANEAMIENTO: AGUAS RESIDUALES | activo |
| MCG-1.06# | RED DE AGUA POTABLE | activo |
| MCG-1.07# | RED DE MEDIA TENSION | fuera de alcance civil — no tocar |
| MCG-1.08# | RED DE BAJA TENSION | fuera de alcance civil — no tocar |
| MCG-1.09# | RED DE ALUMBRADO | fuera de alcance civil — no tocar |
| MCG-1.10# | RED DE TELECOMUNICACIONES | fuera de alcance civil — no tocar |
| MCG-1.11# | RED DE RIEGO Y AGUA REGENERADA | revisar segun proyecto |
| MCG-1.12# | JARDINERIA | revisar segun proyecto |
| MCG-1.13# | MOBILIARIO URBANO | activo |
| MCG-1.14# | R.S.U. | activo |
| MCG-1.15# | SENALIZACION | activo |
| MCG-1.16# | CONTROL DE CALIDAD | activo |
| MCG-1.17# | GESTION DE RESIDUOS | activo |
| MCG-1.18# | SEGURIDAD Y SALUD | activo — BC3 propio en DOCS-ANEJOS/17 |

## Advertencias heredadas del donor

- ~~19 referencias ~D a componentes sin ~C~~: RESUELTO 2026-04-27 — referencias corregidas (MCG-1 → MCG-1#, etc.) en el propio BC3 maestro.
- ~~UJP010 desajuste de precio~~: RESUELTO 2026-04-27 — `bc3_tools.py recalc` ejecutado; 535.2.1## = 5.108.559,83 EUR, UJP010 = 847,592 EUR.
- GR-1.18: resumen vacío (aviso no critico, heredado del donor). Sin impacto operativo.

## Regla operativa

- Antes de cualquier modify/merge/recalc: snapshot obligatorio con `tools/bc3_snapshot.ps1`
- Mediciones: incorporar con `bc3_tools.py modify CODIGO medicion=...` o mediante importacion desde Civil 3D
- Partidas nuevas: `bc3_tools.py merge 535.2.1_maestro.bc3 nuevas.bc3 535.2.1_maestro.bc3`
- Verificacion tras cambios: `bc3_tools.py validate 535.2.1_maestro.bc3`
