# Hallazgos por anejo — qué dicen las cartas y qué hay que hacer

> Vista cruzada. Para cada anejo del POU 535.2.1, los condicionantes extraídos de las cartas registradas y las acciones a tomar.
>
> Última revisión: 2026-04-27. Cubre solo cartas leídas hasta la fecha (32398 EMASA, 32402 Bomberos). Las restantes (33003-1, 33021-1, 33316, 34205-1, Nedgia) están pendientes de extracción.

## Aviso transversal — naturaleza de las cartas archivadas

Las cartas leídas son **antecedentes del DOC (edificio del Designer Outlet Center)**, no respuestas al POU 535.2.1 actual. Aplican como condicionantes vigentes sobre el titular existente y como base para decidir si se necesita nueva consulta a la cía. para la ampliación.

---

## Anejo 6 — Red de Agua Potable

**Fuentes que aplican:** ninguna directa todavía. Las cartas EMASA leídas se refieren a vertido (saneamiento), no a abastecimiento.

**Pendientes:**
- Solicitud específica de **abastecimiento** al POU: caudal punta, presión garantizada, punto de conexión, diámetro, exigencia de hidrantes — falta verificar si está en alguno de los registros pendientes (33003-1, 33021-1, 33316, 34205-1).
- Cruce con A12 / Bomberos: dotación de hidrantes y caudal de incendio (DB-SI 5).

---

## Anejo 7 — Red de Saneamiento (Pluviales)

**Fuentes que aplican:**
- `FICHA_32398_EMASA.md` — autorización de vertido del DOC (favorable, 22/02/2021, ref. EMASA E 2020-29126).

**Lo que dice la carta (relevante para Pluviales):**
- Reglamento aplicable: Reglamento del Servicio de Saneamiento, B.O.P. de Málaga nº 138 de 19/07/2002.
- La autorización vigente cubre el vertido del DOC con condiciones (a) a (i). Aplica al titular DOC SITECO.
- Art. 18.2: cualquier modificación de instalaciones obliga a renovar la autorización.

**Acción a tomar al redactar A7:**
- Citar la autorización vigente como antecedente con la fórmula tipo de la ficha 32398.
- Si la red pluvial proyectada supone modificación de la conexión existente del DOC: dejar constancia de que el titular debe tramitar nueva autorización.
- Verificar trazado de pluviales contra la red municipal — los datos de la red municipal NO constan en estas cartas; **hay que solicitarlos a EMASA específicamente para el POU**.

**Cruce con Civil 3D:**
- Cuando se revise el modelo Civil 3D de pluviales: confirmar que el punto de vertido a red municipal NO altera el punto de medición/depuración del DOC (entre depuración y red, según condición a). Si se altera: nueva autorización.

---

## Anejo 8 — Red de Saneamiento (Fecales)

**Fuentes que aplican:**
- `FICHA_32398_EMASA.md` — misma autorización de vertido del DOC.

**Lo que dice la carta (relevante para Fecales):**
- Las condiciones (a) a (i) afectan al vertido industrial del DOC: analítica anual (DQO, sólidos en suspensión, conductividad, toxicidad, N total, P total), Plan de Autocontrol, comunicación de incidencias, certificado de calibración del medidor de caudal.
- El punto de vertido autorizado está **entre el sistema de depuración propio del DOC y la red municipal**.

**Acción a tomar al redactar A8:**
- Antecedente: el DOC ya tiene autorización de vertido para sus aguas residuales. Las nuevas conexiones del POU (si las hay) deben respetar el punto de vertido autorizado o tramitar nueva autorización.
- Documentar: tipo de efluente que se prevé verter desde la urbanización (si es solo asimilable a doméstico, no aplica el régimen industrial; si hay vertidos industriales adicionales, sí).

**Cruce con Civil 3D:**
- Comprobar que la red de fecales del POU no modifique la conexión del DOC. Si la modifica → renovación obligatoria.

---

## Anejo 4 — Trazado, Replanteo y Mediciones Auxiliares

**Fuentes que aplican:**
- `FICHA_32402_BOMBEROS.md` (cláusula de actualización por modificación de exigencias PCI).

**Acción a tomar al redactar A4:**
- Verificar geometría viaria contra DB-SI 5 (acceso de bomberos): anchura ≥ 3,5 m, altura libre ≥ 4,5 m, capacidad portante ≥ 20 kN/m², radios mínimos (interior ≥ 5,3 m, exterior ≥ 12,5 m), sobreancho 7,2 m en curva.
- Si la nueva geometría no cumple o reduce el cumplimiento que tenía la situación previa, activa la cláusula de actualización del informe SPEIS — nuevo estudio PCI.

**Cruce con Civil 3D:**
- Al revisar trazado en Civil 3D, dejar comprobado el cumplimiento DB-SI 5 explícitamente. **Falta verificar contra la geometría real del proyecto.**

---

## Anejo 12 — Accesibilidad

**Fuentes que aplican:**
- `FICHA_32402_BOMBEROS.md` (en lo relativo a accesos exteriores al edificio).

**Acción a tomar al redactar A12:**
- Comprobar que las modificaciones de los accesos peatonales y rodados al DOC no degraden la accesibilidad de bomberos a fachadas (huecos practicables, espacio de maniobra).

---

## Anejo 16 — Comunicaciones con Cías. Suministradoras

**Fuentes que aplican:** todas las fichas de esta carpeta.

**Acción a tomar al redactar A16:**
- Listar la documentación recibida con su nº de registro, asunto y resolución.
- Distinguir cartas de antecedentes del DOC (32398, 32402) de eventuales respuestas específicas al POU (pendientes de identificar entre los registros 33003-1, 33021-1, 33316, 34205-1).
- Anexar las cartas como apéndice del Anejo 16.

---

## Disciplinas fuera de alcance civil del repo (referencia)

- **Anejo 9-11** (electricidad) — fuera de alcance.
- **Anejo 18** (telecomunicaciones) — fuera de alcance.
- **Gas (Nedgia)** — no es anejo del repo (no se redacta aquí). Documentación archivada como soporte general.

---

## Pendientes globales de la matriz

- [ ] Extraer las 4 cartas escaneadas restantes de Infraestructuras de Red 27042026 (33003-1.EMASA, 33021-1, 33316, 34205-1) — son escaneos sin texto, requieren lectura página a página.
- [ ] Extraer las 4 fichas de Nedgia.
- [ ] Decidir con JL si se solicita formalmente a EMASA y SPEIS información específica del POU (no del DOC).
- [ ] Registrar nodos `cia.emasa.32398` y `cia.bomberos.32402` y sus edges hacia los anejos en `CONTROL/trazabilidad/` cuando se confirme el formato.
