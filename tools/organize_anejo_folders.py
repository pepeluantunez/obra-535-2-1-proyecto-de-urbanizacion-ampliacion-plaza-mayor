#!/usr/bin/env python3
"""
organize_anejo_folders.py
Verifica y corrige la estructura de carpetas de cada anejo POU.

Estructura estandar por anejo:
    DOCS - ANEJOS/
      N.- Nombre del Anejo/
        Anejo N - Nombre.docx          <- documento principal
        00_NOTAS_BASE.md               <- notas y estado
        CALCULOS/                      <- excel propios (no donor)
        FUENTES/                       <- normativa, referencias externas
          DONOR_GUADALMAR/             <- archivos de Guadalmar (solo lectura)

Acciones:
  - check:  reporta desviaciones sin tocar nada
  - fix:    crea carpetas que faltan y mueve archivos mal ubicados

Uso:
    python3 tools/organize_anejo_folders.py [check|fix] [--proyecto=RUTA]

Reglas:
  1. Cada anejo debe tener CALCULOS/ y FUENTES/
  2. Los .xlsx propios (no con DONOR/535.2.2 en nombre) van en CALCULOS/
  3. Los .docx temporales (~$) se reportan (no se tocan)
  4. Los _bak_* .docx se reportan para revisar
  5. 00_NOTAS_BASE.md se crea si no existe (con plantilla minima)
"""

import os
import sys
import re
import shutil
import argparse
from pathlib import Path
from datetime import datetime

# ── Estructura estandar ───────────────────────────────────────────────────────
REQUIRED_SUBDIRS = ['CALCULOS', 'FUENTES']

NOTAS_BASE_TEMPLATE = """\
# Notas de base — Anejo {num}: {nombre}

## Estado
- [ ] Documento Word redactado
- [ ] Excel de cálculo propio completado
- [ ] Tablas del Word cuadran con Excel
- [ ] Partidas BC3 enlazadas y con medición

## Fuentes y referencias
- Donor de referencia: Guadalmar (535.2.2)
- Normativa aplicable: ver FUENTES/

## Bloqueos activos
- (ninguno)

## Registro de cambios
| Fecha | Cambio |
|-------|--------|
| {date} | Carpeta creada/normalizada |
"""

# Anejo N → nombre legible
ANEJO_NOMBRES = {
    1:  'Reportaje Fotografico',
    2:  'Cartografia y Topografia',
    3:  'Estudio Geotecnico',
    4:  'Trazado Replanteo y Mediciones Auxiliares',
    5:  'Dimensionamiento del Firme',
    6:  'Red de Agua Potable',
    7:  'Red de Saneamiento Pluviales',
    8:  'Red de Saneamiento Fecales',
    12: 'Accesibilidad',
    13: 'Estudio de Gestion de Residuos',
    14: 'Control de Calidad',
    15: 'Plan de Obra',
    16: 'Comunicaciones con Companias Suministradoras',
    17: 'Seguridad y Salud',
}

# Anejos fuera de alcance (no tocar)
OUT_OF_SCOPE = {9, 10, 11, 18}

# ── Colores ANSI ──────────────────────────────────────────────────────────────
GRN = '\033[92m'; YEL = '\033[93m'; RED = '\033[91m'
CYA = '\033[96m'; GRY = '\033[90m'; BLD = '\033[1m'; RST = '\033[0m'


def find_project_root(start=None):
    if start is None:
        start = Path.cwd()
    for p in [Path(start)] + list(Path(start).parents):
        if (p / 'CLAUDE.md').exists() or (p / 'PRESUPUESTO').exists():
            return p
    return Path(start)


def parse_anejo_num(folder_name):
    """Extrae el numero de anejo del nombre de carpeta (ej: '5.- Dimensionamiento' → 5)."""
    m = re.match(r'^(\d+)', folder_name)
    return int(m.group(1)) if m else None


def is_donor_excel(filename):
    """Detecta si un Excel es donor (Guadalmar, 535.2.2, etc.)."""
    name = filename.upper()
    return any(kw in name for kw in ('DONOR', '535_2_2', '535.2.2', 'GUADALMAR'))


def is_temp_docx(filename):
    return filename.startswith('~$')


def is_backup_file(filename):
    return '_bak_' in filename.lower() or '_ORIG' in filename


def check_anejo(anejo_dir: Path, anejo_num: int, fix=False):
    """
    Verifica y (opcionalmente) corrige la estructura de un anejo.
    Devuelve lista de hallazgos.
    """
    findings = []
    nombre = ANEJO_NOMBRES.get(anejo_num, f'Anejo {anejo_num}')

    # 1. Subdirectorios obligatorios
    for sub in REQUIRED_SUBDIRS:
        sub_path = anejo_dir / sub
        if not sub_path.exists():
            if fix:
                sub_path.mkdir(exist_ok=True)
                findings.append(('FIX', f'Creado: {sub}/'))
            else:
                findings.append(('MISS', f'Falta: {sub}/'))

    # 2. 00_NOTAS_BASE.md
    notas = anejo_dir / '00_NOTAS_BASE.md'
    if not notas.exists():
        if fix:
            content = NOTAS_BASE_TEMPLATE.format(
                num=anejo_num,
                nombre=nombre,
                date=datetime.now().strftime('%Y-%m-%d')
            )
            notas.write_text(content, encoding='utf-8')
            findings.append(('FIX', '00_NOTAS_BASE.md creado'))
        else:
            findings.append(('MISS', '00_NOTAS_BASE.md ausente'))

    # 3. Excel mal ubicados (en raiz del anejo, no en CALCULOS/)
    calculos = anejo_dir / 'CALCULOS'
    for f in anejo_dir.iterdir():
        if not f.is_file():
            continue
        if f.suffix.lower() in ('.xlsx', '.xls', '.xlsm'):
            if is_donor_excel(f.name):
                if fix:
                    dest_dir = anejo_dir / 'FUENTES' / 'DONOR_GUADALMAR'
                    dest_dir.mkdir(parents=True, exist_ok=True)
                    dest = dest_dir / f.name
                    if not dest.exists():
                        shutil.move(str(f), str(dest))
                        findings.append(('FIX', f'Excel donor movido a FUENTES/DONOR_GUADALMAR/: {f.name}'))
                    else:
                        findings.append(('WARN', f'Excel donor en raiz (destino ya existe): {f.name}'))
                else:
                    findings.append(('WARN', f'Excel donor en raiz (mover a FUENTES/DONOR_GUADALMAR/): {f.name}'))
            elif calculos.exists():
                if fix:
                    dest = calculos / f.name
                    if not dest.exists():
                        shutil.move(str(f), str(dest))
                        findings.append(('FIX', f'Excel movido a CALCULOS/: {f.name}'))
                    else:
                        findings.append(('WARN', f'Excel en raiz (ya existe en CALCULOS/): {f.name}'))
                else:
                    findings.append(('WARN', f'Excel propio en raiz (debe ir a CALCULOS/): {f.name}'))

    # 4. Archivos temporales de Word
    for f in anejo_dir.iterdir():
        if f.is_file() and is_temp_docx(f.name):
            findings.append(('TEMP', f'Temporal Word abierto: {f.name} (cerrar Excel)'))

    # 5. Backups visibles en raiz
    for f in anejo_dir.iterdir():
        if f.is_file() and is_backup_file(f.name) and f.suffix in ('.docx', '.xlsx'):
            findings.append(('WARN', f'Backup en raiz (considerar mover a scratch/): {f.name}'))

    return findings


def main():
    parser = argparse.ArgumentParser(
        description='Verifica y corrige estructura de carpetas de anejos POU'
    )
    parser.add_argument('action', nargs='?', default='check', choices=['check', 'fix'],
                        help='check=solo reportar | fix=crear carpetas y mover archivos')
    parser.add_argument('--proyecto', default=None)
    args = parser.parse_args()

    project_root = Path(args.proyecto) if args.proyecto else find_project_root()
    anejos_root  = project_root / 'DOCS - ANEJOS'
    fix_mode     = (args.action == 'fix')

    print(f'\n{BLD}{CYA}{"═"*60}{RST}')
    print(f'{BLD}{CYA}  ORGANIZAR ANEJOS — {"FIX" if fix_mode else "CHECK"}{RST}')
    print(f'{BLD}{CYA}  {datetime.now().strftime("%Y-%m-%d %H:%M")}{RST}')
    print(f'{BLD}{CYA}{"═"*60}{RST}\n')

    if not anejos_root.exists():
        print(f'{RED}  ERROR: No se encuentra DOCS - ANEJOS/ en {project_root}{RST}')
        sys.exit(1)

    total_issues = 0
    total_fixes  = 0
    total_clean  = 0

    anejo_dirs = sorted(
        [d for d in anejos_root.iterdir() if d.is_dir() and d.name != 'Plantillas'],
        key=lambda d: (parse_anejo_num(d.name) or 99, d.name)
    )

    for anejo_dir in anejo_dirs:
        num = parse_anejo_num(anejo_dir.name)
        if num is None:
            continue
        if num in OUT_OF_SCOPE:
            print(f'{GRY}  {num:02d} {anejo_dir.name[:45]} — fuera de alcance{RST}')
            continue

        findings = check_anejo(anejo_dir, num, fix=fix_mode)

        if not findings:
            print(f'{GRN}  {num:02d} {anejo_dir.name[:45]} — OK{RST}')
            total_clean += 1
        else:
            print(f'{BLD}  {num:02d} {anejo_dir.name[:45]}{RST}')
            for kind, msg in findings:
                if kind == 'FIX':
                    print(f'      {GRN}▶ {msg}{RST}')
                    total_fixes += 1
                elif kind == 'MISS':
                    print(f'      {RED}✗ {msg}{RST}')
                    total_issues += 1
                elif kind == 'WARN':
                    print(f'      {YEL}⚠ {msg}{RST}')
                    total_issues += 1
                elif kind == 'TEMP':
                    print(f'      {GRY}↻ {msg}{RST}')

    print(f'\n{"─"*60}')
    print(f'  Anejos OK:     {GRN}{total_clean}{RST}')
    if fix_mode:
        print(f'  Correcciones:  {GRN}{total_fixes}{RST}')
    print(f'  Hallazgos:     {YEL if total_issues else GRN}{total_issues}{RST}')

    if not fix_mode and total_issues > 0:
        print(f'\n  {YEL}Ejecutar con "fix" para corregir automaticamente:{RST}')
        print(f'  python3 tools/organize_anejo_folders.py fix')
    print()


if __name__ == '__main__':
    main()
