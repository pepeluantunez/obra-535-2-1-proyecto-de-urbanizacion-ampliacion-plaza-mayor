# Informe de control — Trazabilidad Abastecimiento Civil 3D

## Alcance ejecutado
- Proyecto: 535.2.1 Plaza Mayor.
- Fecha de extracción Civil 3D detectada: 29/04/2026.
- Criterio aplicado: universo propuesto limitado a `FD150 PROPUESTO.csv` y `FD200 PROPUESTO.csv`.
- Listas generales usadas solo para enriquecimiento/verificación.

## Fuentes localizadas
- FD150 PROPUESTO.csv: parseo=True encoding=utf-8-sig filas_detalle=24
- FD200 PROPUESTO.csv: parseo=True encoding=utf-8-sig filas_detalle=54
- LISTA DE TUBERIAS.csv: parseo=True encoding=utf-8-sig filas_detalle=124
- LISTA DE ACCESORIOS.csv: parseo=True encoding=utf-8-sig filas_detalle=112
- LISTA DE EHM.csv: parseo=True encoding=utf-8-sig filas_detalle=4

## Cobertura de cruce
- Universo propuesto (piezas únicas): 48
- Con correspondencia en listas generales: 48 (100.00%)

## Medición propuesta (pre-BC3)
- Tramos de tubería propuestos: 20
- Longitud 3D total propuesta: 466.062 m
- DN150: 150.724 m
- DN200: 315.338 m
- Piezas especiales propuestas (accesorios+EHM): 28

## Estado del mapeo BC3 candidato
- ALTA: 46 elementos
- MEDIA: 2 elementos
- Nota: no se ha modificado BC3 ni se han generado líneas ~M en esta tarea.

## Incidencias
- Sin incidencias bloqueantes.

## Verificaciones finales
- Verificación de integridad de fuentes: hashes SHA256 generados.
- Verificación de codificación de entrada: fallback utf-8-sig/utf-8/cp1252 aplicado.
- Verificación anti-mojibake en salidas UTF-8: completada.
