---
name: docx-toc-safe-lane
description: Repara o regenera indices de Word en Plaza Mayor sin romper campos, marcadores, cabeceras ni contenido no pedido.
---

# DOCX TOC Safe Lane

Usar cuando una tarea afecte al indice de un `DOCX` de anejos o cuando aparezcan sintomas como:

- numeros de pagina desaparecidos
- `Error. Marcador no definido.`
- placeholders del donor en el indice
- TOC reconstruido como texto plano

## Flujo

1. Identificar el menor alcance posible.
2. Leer headings reales del documento, no de la plantilla.
3. Preservar cabeceras, pies y cuerpo no pedido.
4. Regenerar las entradas `TDC*` desde los headings reales.
5. Recrear marcadores `_Toc...` validos y alinear cada `PAGEREF` con su marcador.
6. Marcar `updateFields=true` en `word/settings.xml`.
7. Verificar que el numero de headings coincide con:
   - entradas TOC
   - marcadores `_Toc...`
   - referencias `PAGEREF`
8. Cerrar con anti-mojibake.

## Prohibido

- Copiar el resultado visible del indice desde la plantilla y dejarlo tal cual.
- Aplanar un TOC de Word a parrafos simples.
- Tocar cabeceras o pies como efecto lateral de una normalizacion de apertura.
- Dar por bueno un indice con `PAGEREF` que apunte a marcadores inexistentes.

## Comprobacion minima

- `tools\restore_docx_toc_fields.ps1`
- `tools\check_office_mojibake.ps1`

## Nota

Si Word COM no arranca, no insistir a ciegas. Resolver el TOC por XML solo es valido si se reconstruyen tambien los marcadores y se valida que no quedan referencias colgadas.
