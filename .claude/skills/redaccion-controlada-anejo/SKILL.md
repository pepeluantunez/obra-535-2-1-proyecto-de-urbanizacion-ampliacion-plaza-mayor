---
name: redaccion-controlada-anejo
description: >
  Redaccion controlada de anejos y memoria en proyectos de urbanizacion. Usar cuando haya que redactar
  solo lo soportado por fuentes disponibles: objeto, antecedentes, normativa, descripcion general o
  partes tecnicas limitadas, evitando inventar calculos o cerrar secciones sin trazabilidad.
---

# Redaccion Controlada Anejo

## Modos

### Modo arranque

Rellenar:
- portada interna
- objeto
- antecedentes
- normativa base

### Modo antecedentes

Redactar:
- cronologia
- ambito
- promotores
- condicionantes previos

### Modo normativa

Redactar:
- marco normativo general
- normativa especifica del anejo
- limitaciones o pendientes de contraste

### Modo tecnico

Solo usar si existen calculos, tablas, planos o exportaciones reales contrastables.

## Reglas

- Cada parrafo debe apoyarse en una fuente identificable o en una formulacion prudente de arranque.
- No completar `4. JUSTIFICACION / CALCULOS / DESARROLLO` sin datos tecnicos.
- No completar conclusiones tecnicas si solo existe documentacion base.
- Si hay texto donor util, reescribirlo para Plaza Mayor; no arrastrarlo literalmente.

## Herramientas utiles

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\check_template_completion.ps1' -Paths @('<docx_o_carpeta>')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\check_office_mojibake.ps1' -Paths @('<docx_o_carpeta>')"
```

## Resultado esperado

Documento profesional, prudente y trazable, aunque todavia no este tecnicamente cerrado.
