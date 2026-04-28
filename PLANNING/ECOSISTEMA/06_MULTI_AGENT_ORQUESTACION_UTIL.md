# Multi-Agent Orquestacion Util

Fecha: 2026-04-25
Origen: notas de arquitectura multi-agente revisadas en esta sesion

## Idea central valida

Un solo agente sirve para tareas acotadas.
Un equipo de agentes especializados mejora tareas complejas si y solo si:

1. cada agente tiene una responsabilidad clara
2. el coordinador controla el flujo
3. el contexto se pasa de forma explicita
4. hay validacion entre etapas

## Lo que si adoptamos

### 1. Arquitectura hub-and-spoke

Aplicacion al ecosistema:
- `ecosystem-triage` actua como hub de entrada
- los agentes especializados actuan como spokes:
  - `document-closeout-agent`
  - futuro `traceability-drift-agent`
  - futuro `repo-governance-agent`
  - futuro `bc3-safety-agent`

Regla:
- los especialistas no deben improvisar su propio flujo general
- el coordinador decide alcance, contexto, checks y criterio de cierre

### 2. Contexto explicito, nunca asumido

Esta es probablemente la regla mas importante.

Aplicacion:
- un especialista no debe "heredar" por magia lo que el coordinador ya sabe
- cada handoff debe incluir:
  - objetivo
  - fuentes maestras
  - rutas en alcance
  - restricciones
  - salida esperada
  - checks de cierre

Bloque minimo recomendado:

```text
Objetivo:
Fuente maestra:
Rutas en alcance:
Rutas fuera de alcance:
Datos confirmados:
Datos pendientes:
Salida esperada:
Checks obligatorios:
```

### 3. Especializacion real

No crear agentes por postureo.

Aplicacion:
- un agente = una responsabilidad dominante
- evitar agentes que hagan a la vez investigar, decidir, redactar y validar

Buenos ejemplos aqui:
- triage
- closeout
- governance
- trazabilidad
- bc3 safety

### 4. Revisor separado cuando el riesgo lo justifica

Idea util:
- en flujos largos, la revision no debe hacerla el mismo agente que genero la salida

Aplicacion:
- para tareas mixtas o delicadas, el cierre debe pasar por un lane distinto o por un agente de closeout
- especialmente util en:
  - DOCX/XLSX/BC3
  - trazabilidad
  - entregas locales

### 5. Incluir fuente original en etapas posteriores

Evita el efecto "telefono roto".

Aplicacion:
- el redactor no debe recibir solo la conclusion del analista
- el revisor no debe recibir solo el texto final
- cuando importe la fidelidad, pasar tambien:
  - datos fuente
  - hallazgos previos
  - restricciones originales

## Lo que NO adoptamos

### 1. Multi-agente por defecto

No toda tarea necesita equipo.

Regla:
- si una tarea cabe limpia en un solo agente con pocos pasos, se hace en uno
- el multi-agente se reserva para:
  - tareas largas
  - salidas claramente separables
  - verificaciones en paralelo
  - contextos donde el output intermedio estorba

### 2. Especialistas que se hablen solos

No conviene en este ecosistema.

Regla:
- toda comunicacion relevante debe pasar por el coordinador o quedar estructurada en handoff

### 3. Decomposicion artificial

No partir tareas en trozos por moda.

Regla:
- solo descomponer si mejora:
  - calidad
  - control
  - verificabilidad
  - velocidad real

## Fallos a evitar

### 1. Narrow decomposition

El coordinador deja fuera parte del alcance.

Prevencion:
- antes de repartir, enumerar el alcance completo y revisar huecos

### 2. Lost context

El especialista no recibe lo que necesita.

Prevencion:
- handoff explicito con bloque minimo obligatorio

### 3. Telephone effect

Cada etapa degrada o simplifica demasiado la anterior.

Prevencion:
- incluir fuente original en etapas criticas
- no pasar solo resmenes si la fidelidad importa

## Decision para este repo

Adoptar multi-agente de forma sobria y dirigida por riesgo.

Orden natural aqui:

1. `ecosystem-triage` como coordinador
2. `document-closeout-agent` como verificador especializado
3. futuros agentes de `traceability`, `governance` y `bc3`

No construir un "team of agents" decorativo. Construir un sistema donde cada agente quite carga real y reduzca errores.
