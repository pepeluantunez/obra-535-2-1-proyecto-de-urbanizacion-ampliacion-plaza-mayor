# Guía de Funcionamiento: Skills y Agentes

Fecha: 2026-04-14  
Proyecto: 535.2.2 Mejora Carretera Guadalmar

## Qué está instalado

### Skills globales (todos tus chats)

- `command-creator`
- `session-handoff`
- `agent-md-refactor`
- `systematic-debugging`

Ubicación: `C:\Users\USUARIO\.codex\skills\`

### Skills locales (este proyecto)

- `535-guadalmar`
- `auditoria-civil-completa`
- `auditoria-civil-interactiva`

Ubicación: `.claude\skills\`

## Cómo funciona el sistema (orden real)

1. `AGENTS.md` enruta la tarea (documental, BC3, trazabilidad, maquetación).
2. Se activa la skill local del proyecto si aplica (contexto y reglas Guadalmar).
3. Si la tarea encaja, se usan skills globales de soporte.
4. Se ejecutan scripts de control (`tools\...`) para cierre estricto.

## Tu forma de pedirlo (frases cortas)

### Auditoría completa

- "Audita civil completo en estricto."
- "Lanza auditoría integral de proyecto."

### Auditoría parcial

- "Revisa solo BC3 capítulo firmes."
- "Audita solo Anejo 13 y 17."
- "Cruza Excel mediciones con BC3."

### Trazabilidad

- "Pasa trazabilidad estricta global."
- "Pasa trazabilidad estricta Residuos y SyS."

### Maquetación y coherencia

- "Maqueta este anejo en estándar profesional."
- "Revisa tablas DOCX y coherencia con presupuesto."

### Continuidad de sesión

- "Crea handoff de esta sesión."
- "Reanuda desde el último handoff."

### Mejora del sistema

- "Refactoriza AGENTS para reducir ruido."
- "Crea comando nuevo para [tarea repetitiva]."

## Qué tienes que clicar

Nada especial.  
Con frase corta basta. Yo enruto automáticamente al carril/skill correcto.

## Nota importante

Para que Codex detecte las skills recién instaladas en todos los chats, reinicia la app de Codex.

## Limitación actual detectada

La skill `session-handoff` trae scripts Python y esta máquina ahora mismo no tiene `python` en PATH.  
Si quieres, en otra tarea te dejo resuelto:

1. instalar Python, o
2. adaptar handoff a scripts PowerShell equivalentes.
