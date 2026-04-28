# Despliegue De Agentes Por Prioridad

Fecha: 2026-04-25
Estado: vivo

## Objetivo

Implantar agentes de verdad, uno a uno, solo cuando mejoren el sistema actual y sin meter mas ruido en los repos.

## Orden de implantacion

1. `Ecosystem Triage Agent`
   Estado: implantado localmente en Plaza Mayor como skill semilla en `.agents/skills/ecosystem-triage/SKILL.md`
   Mejora concreta:
   - convierte peticiones ambiguas en ordenes de trabajo limpias
   - fuerza lectura minima y fuente maestra
   - separa carriles y checks antes de tocar archivos delicados
   Salto siguiente:
   - promoverlo a toolkit o repo ecosistema cuando el catalogo comun quede fijado

2. `Document Closeout Agent`
   Estado: implantado localmente en Plaza Mayor como skill semilla en `.agents/skills/document-closeout-agent/SKILL.md`
   Base actual:
   - `.agents/skills/verification-before-completion/SKILL.md`
   Mejora concreta:
   - obliga a declarar paths, carril y cambio esperado antes del cierre
   - normaliza la salida final con comandos y resultados
   - reutiliza checks existentes sin reabrir gobierno
   Salto siguiente:
   - convergerlo con `verification-before-completion` cuando el catalogo comun salga de Plaza Mayor
   Valor:
   - evita cierres blandos sobre DOCX/XLSX/BC3

3. `Traceability Drift Agent`
   Estado: listo para semilla
   Base actual:
   - `tools/check_traceability_consistency.ps1`
   - `tools/run_traceability_profile.ps1`
   Valor:
   - detectar incoherencias periodicas antes de entrega

4. `Repo Governance Agent`
   Estado: listo para semilla
   Base actual:
   - `tools/check_repo_contract.ps1`
   - `CONFIG/repo_contract.json`
   Valor:
   - evitar que vuelvan a crecer raiz, duplicidades y mezclas de capas

5. `BC3 Safety Agent`
   Estado: listo para semilla
   Base actual:
   - `tools/bc3_snapshot.ps1`
   - `tools/bc3_diff_report.ps1`
   - `tools/check_bc3_integrity.ps1`
   Valor:
   - reducir riesgo alto en presupuesto y mediciones

6. `Slack Intake Agent`
   Estado: no iniciado
   Dependencia:
   - tener triage y closeout ya estabilizados

## Criterio para seguir

No pasar al siguiente agente si el anterior no cumple:

1. reduce pasos manuales reales
2. no duplica autoridad
3. tiene entradas y salidas claras
4. reusa checks existentes
5. no empeora el ruido del repo
6. declara `stop conditions` y checkpoints humanos si usa herramientas o edita
7. pone las restricciones criticas al principio
8. no depende de skills infladas cuando un `references/` bastaria
9. aplica principios transversales de cambios minimos, simplicidad y cierre verificable

## Regla de capas

Mientras el catalogo comun no viva fuera de Plaza Mayor:

- este repo solo aloja semillas locales y pruebas de integracion
- toolkit o un repo ecosistema debera alojar la version compartida
- no volver a inflar la raiz para documentar agentes

## Regla de orquestacion

- usar coordinador + especialistas solo cuando la tarea gane control, calidad o verificabilidad
- todo handoff entre agentes debe pasar contexto explicito
- evitar especialistas que mezclen investigacion, redaccion y cierre en la misma unidad
