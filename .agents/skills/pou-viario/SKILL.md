---
name: pou-viario
description: >
  Skill generico para proyectos de obras de urbanizacion (POU) viarios en Andalucia y Espana.
  Activa cuando el usuario menciona POU, urbanizacion viaria, mejora de carretera, proyecto de obra
  viaria, presupuesto de urbanizacion, anejos POU, o solicita asistencia tecnica sobre un proyecto
  de carretera o vial urbano en tramitacion municipal o autonómica.
triggers:
  - POU
  - urbanizacion viaria
  - mejora carretera
  - proyecto obra viaria
  - anejos POU
  - presupuesto urbanizacion
  - vial urbano
  - obra urbanizacion
---

# Skill: POU Viario Generico

## Variables del proyecto (rellenar al inicializar)

Las siguientes variables deben personalizarse para cada proyecto nuevo.
Se corresponden con los tokens de `CONFIG/proyecto.template.json`.

| Variable                  | Descripcion                                      | Ejemplo                        |
|---------------------------|--------------------------------------------------|--------------------------------|
| `{{CODIGO_EXPEDIENTE}}`   | Codigo interno del expediente                    | 535.2.2                        |
| `{{NOMBRE_PROYECTO}}`     | Nombre completo del proyecto                     | Mejora Carretera Guadalmar     |
| `{{LOCALIDAD}}`           | Municipio donde se ubica la obra                 | Malaga                         |
| `{{PROVINCIA}}`           | Provincia                                        | Malaga                         |
| `{{PROMOTOR}}`            | Entidad promotora (Ayuntamiento, Junta, etc.)    | Ayuntamiento de Malaga         |
| `{{REDACTOR}}`            | Empresa o tecnico redactor del proyecto          | Empresa Tecnica S.L.           |
| `{{FECHA_REDACCION}}`     | Fecha de redaccion del proyecto                  | Abril 2026                     |
| `{{PEM_APROX}}`           | Presupuesto de Ejecucion Material aproximado (€) | 2.500.000                      |
| `{{LONGITUD_VIAL}}`       | Longitud total del vial o tramo (m)              | 1.200                          |
| `{{AMBITO_ACTUACION}}`    | Descripcion sintetica del ambito                 | Tramo urbano, doble calzada    |
| `{{PGOU_VIGENTE}}`        | PGOU o instrumento urbanistico de referencia     | PGOU Malaga 2011 (rev. 2023)   |
| `{{NORMATIVA_ESPECIFICA}}`| Normativas adicionales propias del promotor      | NTE-Malaga-2022                |

---

## Estructura estandar de anejos — POU viario Andalucia

La estructura minima admitida para un POU viario en Andalucia es la siguiente.
El numero de anejos puede ampliarse segun el alcance tecnico especifico.

| N.° | Titulo del anejo                                | Contenido minimo obligatorio                                         |
|-----|--------------------------------------------------|----------------------------------------------------------------------|
| 01  | Reportaje fotografico y levantamiento            | Fotos numeradas, tabla de ubicaciones, estado previo del vial        |
| 02  | Estudio hidrologico e hidraulico                 | Cuencas, caudales de calculo (T=10, T=100), colectores existentes    |
| 03  | Geotecnia y firmes                               | Sondeos, categoria de explanada, seccion de firme justificada        |
| 04  | Topografia y replanteo                           | Tabla de vertices, perfil longitudinal, secciones transversales      |
| 05  | Movimiento de tierras                            | Volumetria (desmonte/terraplén), balance de tierras                  |
| 06  | Abastecimiento de agua                           | Red existente, trazado nuevo, dimensionado hidraulico, materiales    |
| 07  | Saneamiento — Pluviales                          | Calculo SSA, dimensionado colectores, pozos, acometidas              |
| 08  | Saneamiento — Fecales                            | Trazado, dimensionado, impulsion si procede, vertido                 |
| 09  | Alumbrado publico                                | Calculo luminotecnico, reglamento REEIAE, eficiencia energetica      |
| 10  | Electricidad BT / MT                             | Red existente, afecciones, reposicion y coordinacion compañia        |
| 11  | Telecomunicaciones                               | Canalización, tubos, arquetas, coordinacion operadores               |
| 12  | Accesibilidad y supresion de barreras            | Real Decreto 1/2013, Decreto 293/2009 Junta; vados, pavimento guia  |
| 13  | Estudio de gestion de residuos                   | Ley 7/2022; estimacion RCD por capitulo, destino gestor autorizado   |
| 14  | Control de calidad                               | Plan de ensayos, criterios de aceptacion, lotes de control           |
| 15  | Plan de obra                                     | Diagrama de Gantt, camino critico, plazo total en semanas/meses      |
| 16  | Justificacion de precios                         | Mano de obra, maquinaria, materiales; cuadros de precios descompuestos|
| 17  | Seguridad y salud                                | Ley 32/2006, RD 1627/1997; EPI, riesgos especificos, valoracion SS  |

> **Nota:** Anejos adicionales habituales segun alcance: 18-Señalizacion y balizamiento,
> 19-Coordinacion con servicios afectados, 20-Estudio de impacto ambiental (si procede).

---

## Criterios tecnicos genericos

### Firmes y pavimentos

- Explanada minima E2 en viales urbanos con trafico ligero-medio (CBR ≥ 5).
- Secciones de firme de referencia segun IC 6.1 (Norma 6.1-IC):
  - Categoria de trafico T31/T32: sección tipo AC + ZA + subbbase granular.
  - Calzada rodada: AC16 surf S (o AC11 surf S) + AC22 bin S + ZA25 (e=20 cm).
  - Acera: loseta hidraulica o terrazo sobre base de hormigon HM-15 (e=10 cm).
- Fresado previo cuando el firme existente tiene deformaciones > 20 mm o IRI > 4.
- Pendiente minima de calzada: 0,5 %. Maxima en zonas urbanas: 10 % (recomendado < 8 %).

### Explanada y movimiento de tierras

- Clasificacion segin PG-3 articulos 330-341 (terraplenes) y 320-321 (desmontes).
- Compactacion: 100 % PM en coronacion de terraplen; 95 % PM en nucleo.
- Tolerar asientos diferenciales < 3 cm en vial acabado antes de extender firme definitivo.

### Redes de saneamiento — Pluviales

- Metodo racional (hidrograma unitario para cuencas > 50 ha).
- Periodo de retorno de calculo: T=10 años para colectores urbanos primarios; T=25 años para
  colectores maestros.
- Velocidad minima 0,6 m/s; maxima 4,0 m/s (sin revestimiento especial).
- Material preferente: hormigon armado HA-25 o PVC-SN8 DN ≥ 300 mm.

### Abastecimiento

- Presion de servicio entre 10 y 60 mca (recomendado 20-45 mca).
- Caudal de incendio segun NBE-CPI o normativa municipal.
- Material preferente: PEAD PE100 PN16 o fundicion ductil.

### Alumbrado

- Reglamento de Eficiencia Energetica en Instalaciones de Alumbrado Exterior (REEIAE).
- Clase de alumbrado segun tipo de via (ME4/ME5 para viales locales; ME3b para arteriales).
- Nivel de iluminancia Em ≥ 15 lux en viales ME4; factor de uniformidad Uo ≥ 0,40.

---

## Normativas de referencia obligatorias

| Ambito                    | Normativa                                                            |
|---------------------------|----------------------------------------------------------------------|
| Carreteras / firmes       | Instruccion IC 6.1-IC y 6.2-IC (firmes y pavimentos)                |
| Pliego general de obra    | PG-3 (Pliego de Prescripciones Técnicas Generales)                  |
| Estructuras hormigon      | EHE-08 (Instruccion de Hormigon Estructural)                        |
| Instalaciones termicas    | RITE 2007 (si aplica en edificaciones asociadas)                     |
| Instalaciones electricas  | REBT 2002 (Reglamento Electrotecnico Baja Tension)                  |
| Seguridad y salud         | Ley 32/2006 subcontratacion; RD 1627/1997 SS obras                  |
| Gestion de residuos       | Ley 7/2022 residuos y suelos contaminados; RD 105/2008 RCD          |
| Accesibilidad             | RD Legislativo 1/2013; Decreto 293/2009 Junta de Andalucia          |
| Alumbrado exterior        | RD 1890/2008 REEIAE                                                  |
| Urbanismo (referencia)    | LOUA (Ley 7/2002) / LISTA (Ley 7/2021) segun tramitacion            |
| PGOU aplicable            | {{PGOU_VIGENTE}}                                                     |
| Normativa especifica      | {{NORMATIVA_ESPECIFICA}}                                             |

---

## Archivos esperados por carpeta (estructura minima)

```
PROYECTO/
├── DOCS/
│   ├── Documentos de Trabajo/
│   │   ├── 01.- Reportaje fotografico/
│   │   │   └── ANEJO_01_Reportaje_Fotografico.docx
│   │   ├── 03.- Geotecnia y Firmes/
│   │   │   └── ANEJO_03_Geotecnia_Firmes.docx
│   │   └── ... (un DOCX activo por anejo)
│   ├── Memoria/
│   │   └── MEMORIA_{{CODIGO_EXPEDIENTE}}.docx
│   └── Plantillas/
│       └── PLANTILLA_MAESTRA_ANEJOS.docx
├── PRESUPUESTO/
│   ├── BC3/
│   │   └── {{CODIGO_EXPEDIENTE}}_presupuesto.bc3    ← archivo maestro FIEBDC-3
│   └── Mediciones/
│       └── *.xlsx o *.csv                          ← mediciones fuente por red
├── PLANOS/
│   ├── 01_RefExt/                                  ← ortofoto, cartografia base
│   ├── 02_CAD/                                     ← DWG/DXF editables
│   ├── 03_PDF/                                     ← planos sellados PDF
│   └── 04_CIVIL3D/                                 ← archivos Civil 3D
├── ENTREGABLES/
│   └── (versiones firmadas para entrega)
├── CONTROL_CALIDAD/
│   └── registro_cambios.md
├── CONFIG/
│   └── proyecto.template.json                      ← datos del proyecto
└── .Codex/
    └── skills/ agents/ commands/                   ← esta plantilla
```

---

## Protocolo de coherencia entre anejos

Antes de cerrar cualquier anejo, verificar los cruces obligatorios:

| Anejo origen       | Cruza con               | Dato a verificar                                        |
|--------------------|-------------------------|---------------------------------------------------------|
| 03 Geotecnia       | BC3 capitulo firmes     | Tipo de explanada y espesor de capas coinciden          |
| 04 Topografia      | 05 Mov. tierras         | Volumetria de desmonte/terraplen coherente              |
| 05 Mov. tierras    | BC3 capitulo tierras    | m³ de desmonte y terraplen cuadran con medicion BC3     |
| 06 Abastecimiento  | BC3 cap. abastecimiento | ML de tuberia y unidades de valvuleria coinciden        |
| 07 Pluviales       | BC3 cap. pluviales      | ML colectores, UD de pozos y sumideros cuadran          |
| 08 Fecales         | BC3 cap. fecales        | ML colectores, UD de pozos y acometidas cuadran         |
| 13 Residuos        | BC3 (todas)             | Volumetria RCD coherente con volumen de obra total      |
| 15 Plan de obra    | BC3 presupuesto total   | Plazo de ejecucion coherente con PEM y rendimientos     |
| 16 Precios         | BC3 descompuestos       | Precios unitarios coinciden con descomposicion BC3      |
| 17 SyS             | BC3 cap. SyS            | Valoracion de SS coincide con partida alzada BC3        |

---

## Estado de anejos (tabla de seguimiento)

Actualizar esta tabla en el SKILL.md especifico del proyecto.

| N.° | Titulo                       | Autor    | Fecha cierre | Estado      | Observaciones               |
|-----|------------------------------|----------|--------------|-------------|-----------------------------|
| 01  | Reportaje fotografico        |          |              | PENDIENTE   |                             |
| 02  | Hidrologico e hidraulico     |          |              | PENDIENTE   |                             |
| 03  | Geotecnia y firmes           |          |              | PENDIENTE   |                             |
| 04  | Topografia y replanteo       |          |              | PENDIENTE   |                             |
| 05  | Movimiento de tierras        |          |              | PENDIENTE   |                             |
| 06  | Abastecimiento               |          |              | PENDIENTE   |                             |
| 07  | Pluviales                    |          |              | PENDIENTE   |                             |
| 08  | Fecales                      |          |              | PENDIENTE   |                             |
| 09  | Alumbrado                    |          |              | PENDIENTE   |                             |
| 10  | Electricidad                 |          |              | PENDIENTE   |                             |
| 11  | Telecomunicaciones           |          |              | PENDIENTE   |                             |
| 12  | Accesibilidad                |          |              | PENDIENTE   |                             |
| 13  | Gestion de residuos          |          |              | PENDIENTE   |                             |
| 14  | Control de calidad           |          |              | PENDIENTE   |                             |
| 15  | Plan de obra                 |          |              | PENDIENTE   |                             |
| 16  | Justificacion de precios     |          |              | PENDIENTE   |                             |
| 17  | Seguridad y salud            |          |              | PENDIENTE   |                             |

Estados validos: `PENDIENTE` | `EN REDACCION` | `REVISION` | `CERRADO`

