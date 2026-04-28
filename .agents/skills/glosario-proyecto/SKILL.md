---
name: glosario-proyecto
description: >
  Keep project terminology consistent in Plaza Mayor work. Use when wording is ambiguous, when the
  same concept appears with competing names, or when drafting/reviewing text that must preserve the
  project's vocabulary and source hierarchy.
---

# Glosario Proyecto

## Objective

Prevent vocabulary drift across annexes, memory, Excel-derived tables, and budget language.

This skill is local to project wording, not a general writing framework.

## When to use

Use when:

1. A term could mean different things depending on context.
2. The user asks which term should be used in this project.
3. A draft mixes generic wording with project wording.
4. A normative term and a project term coexist and must not be conflated.

Do not use as a substitute for source hierarchy. Terminology does not overrule `FUENTES_MAESTRAS.md`.

## Read order

Read only what is needed:

1. `FUENTES_MAESTRAS.md`
2. `DECISIONES_PROYECTO.md`
3. The affected local document or annex
4. `CONTROL/trazabilidad/` only if the wording affects cross-document traceability

## Core glossary for Plaza Mayor

Prefer these terms unless the source document or applicable standard requires another:

- `anejo`
  Avoid: `anexo tecnico`, `apendice`

- `medicion`
  Avoid: `metrica`, `cuantificacion`

- `partida`
  Avoid: `linea presupuestaria`, `item`

- `precio unitario`
  Avoid: `coste unitario`, `precio base`

- `importe`
  Avoid: `subtotal` when it is not a literal subtotal

- `expediente`
  Meaning: the full project record identified by code

- `ambito`
  Use as the project's technical term for the intervention area, not as a loose synonym of any zone

- `trazabilidad transversal`
  Meaning: coherence of data across disciplines and project artifacts

- `arranque documental`
  Meaning: early structured drafting stage; not final validated technical content

- `marco documental de partida`
  Meaning: documented starting set before full technical consolidation

## Decision rules

1. If the project already uses a stable term in its authority documents, keep it.
2. If normative wording differs from project wording, preserve both in their proper contexts.
3. If Excel, BC3, and Word use different names for the same concept, prefer the term that preserves traceability to the governing source.
4. If a term is still ambiguous after reading the local context, say so explicitly instead of normalizing it silently.

## Output contract

When this skill is used, report:

```text
Termino revisado:
Forma recomendada:
Variantes a evitar:
Contexto fuente:
Impacto en trazabilidad:
```

## Stop rules

Do not invent a glossary entry just because a term sounds plausible.

Stop and flag ambiguity when:

1. Two authoritative sources use conflicting terms.
2. A term is only inferred from memory and not found in the project files.
3. The normalized wording would break traceability to a source table, caption, code, or BC3 concept.
