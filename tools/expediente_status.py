#!/usr/bin/env python3
"""
expediente_status.py
Estado del expediente POU: por anejo, que tiene y que falta.

Genera tabla con:
  - Word (docx) presente / ausente / solo donor
  - Excel (xlsx) en CALCULOS/ presente / ausente / solo donor
  - Partidas BC3 enlazadas (de capitulo correspondiente)
  - Estado derivado de KANBAN.md
  - Bloqueos registrados

Uso:
    python3 tools/expediente_status.py [--proyecto=RUTA] [--json] [--md]
    python3 tools/expediente_status.py --proyecto="C:/ruta/al/proyecto"

Salida:
    Tabla coloreada en terminal + opcionalmente JSON/Markdown en CONTROL/
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path
from datetime import datetime

# ── Mapa anejo → capitulo BC3 ──────────────────────────────────────────────
ANEJO_BC3_MAP = {
    1:  {'nombre': 'Reportaje Fotografico',               'bc3_cap': None},
    2:  {'nombre': 'Cartografia y Topografia',            'bc3_cap': None},
    3:  {'nombre': 'Estudio Geotecnico',                  'bc3_cap': None},
    4:  {'nombre': 'Trazado, Replanteo y Med. Aux.',      'bc3_cap': ['MCG-1.01#', 'MCG-1.02#']},
    5:  {'nombre': 'Dimensionamiento del Firme',          'bc3_cap': ['MCG-1.03#']},
    6:  {'nombre': 'Red de Agua Potable',                 'bc3_cap': ['MCG-1.06#']},
    7:  {'nombre': 'Red Saneamiento Pluviales',           'bc3_cap': ['MCG-1.04#']},
    8:  {'nombre': 'Red Saneamiento Fecales',             'bc3_cap': ['MCG-1.05#']},
    9:  {'nombre': 'Electricidad MT',                     'bc3_cap': ['MCG-1.07#'], 'scope': 'OUT_OF_SCOPE'},
    10: {'nombre': 'Electricidad BT',                     'bc3_cap': ['MCG-1.08#'], 'scope': 'OUT_OF_SCOPE'},
    11: {'nombre': 'Alumbrado Publico',                   'bc3_cap': ['MCG-1.09#'], 'scope': 'OUT_OF_SCOPE'},
    12: {'nombre': 'Accesibilidad',                       'bc3_cap': ['MCG-1.15#']},
    13: {'nombre': 'Gestion de Residuos',                 'bc3_cap': ['MCG-1.14#', 'MCG-1.17#']},
    14: {'nombre': 'Control de Calidad',                  'bc3_cap': ['MCG-1.16#']},
    15: {'nombre': 'Plan de Obra',                        'bc3_cap': None},
    16: {'nombre': 'Comunicaciones con Companias',        'bc3_cap': None},
    17: {'nombre': 'Seguridad y Salud',                   'bc3_cap': ['MCG-1.18#']},
    18: {'nombre': 'Telecomunicaciones',                  'bc3_cap': ['MCG-1.10#'], 'scope': 'DOES_NOT_EXIST'},
}

# ── Colores ANSI ────────────────────────────────────────────────────────────
GRN  = '\033[92m'
YEL  = '\033[93m'
RED  = '\033[91m'
CYA  = '\033[96m'
GRY  = '\033[90m'
BLD  = '\033[1m'
DIM  = '\033[2m'
RST  = '\033[0m'


def find_project_root(start=None):
    if start is None:
        start = Path.cwd()
    for p in [Path(start)] + list(Path(start).parents):
        if (p / 'CLAUDE.md').exists() or (p / 'PRESUPUESTO').exists():
            return p
    return Path(start)


def find_anejo_dir(anejos_root: Path, num: int):
    """Busca la carpeta del anejo N en DOCS - ANEJOS/."""
    pattern = re.compile(rf'^{num}[.\-\s]', re.IGNORECASE)
    try:
        for d in sorted(anejos_root.iterdir()):
            if d.is_dir() and pattern.match(d.name):
                return d
    except Exception:
        pass
    return None


def check_word(anejo_dir: Path):
    """
    Busca el docx principal del anejo (no temporales, no donor).
    Devuelve: 'present' | 'donor_only' | 'missing'
    """
    if anejo_dir is None:
        return 'missing'

    # Buscar docx en raiz del anejo (no en FUENTES/)
    candidates = [
        f for f in anejo_dir.glob('*.docx')
        if not f.name.startswith('~') and 'DONOR' not in f.name.upper()
    ]
    if candidates:
        return 'present'

    # ¿Solo en FUENTES/DONOR?
    donor = list(anejo_dir.rglob('*.docx'))
    if donor:
        return 'donor_only'

    return 'missing'


def check_excel(anejo_dir: Path):
    """
    Busca xlsx propio en CALCULOS/ (no donor, no fuentes).
    Devuelve: 'present' | 'donor_only' | 'missing'
    """
    if anejo_dir is None:
        return 'missing'

    calculos = anejo_dir / 'CALCULOS'
    if calculos.exists():
        own = [
            f for f in calculos.glob('*.xlsx')
            if not f.name.startswith('~')
            and 'DONOR' not in f.name.upper()
        ]
        if own:
            return 'present'

    # Buscar en toda la carpeta del anejo, excluyendo FUENTES/DONOR
    own_any = [
        f for f in anejo_dir.rglob('*.xlsx')
        if not f.name.startswith('~')
        and 'FUENTES' not in str(f.parent).upper()
        and 'DONOR' not in f.name.upper()
    ]
    if own_any:
        return 'present'

    # Solo donor?
    donors = list(anejo_dir.rglob('*.xlsx'))
    if donors:
        return 'donor_only'

    return 'missing'


def count_bc3_partidas(bc3_data, bc3_caps):
    """Cuenta partidas hoja en los capitulos indicados."""
    if not bc3_caps or bc3_data is None:
        return None
    total = 0
    for cap in bc3_caps:
        children = bc3_data.get('descomps', {}).get(cap, [])
        total += len(children)
    return total


def parse_kanban_status(kanban_path: Path):
    """
    Lee KANBAN.md y extrae estado de anejos.
    Devuelve dict: {anejo_num: {'status': str, 'bloqueo': str}}
    """
    status = {}
    if not kanban_path or not kanban_path.exists():
        return status
    text = kanban_path.read_text(encoding='utf-8', errors='replace')

    # Buscar items de anejos (patron: "anejo N" en cualquier forma)
    pattern_anejo = re.compile(
        r'(?i)anejo\s+(\d+)[^`\n]*?\n'
        r'(?:.*?owner:.*?\n)*'
        r'(?:.*?bloqueo:([^\n]+)\n)?',
        re.DOTALL
    )

    # Extraer estado de anejos de forma simple
    lines = text.split('\n')
    in_blocked = False
    in_done = False
    for i, line in enumerate(lines):
        if '### [A] Blocked' in line or '### [B] Blocked' in line:
            in_blocked = True
            in_done = False
        elif '### [A] Done' in line or '### [B] Done' in line:
            in_done = True
            in_blocked = False
        elif line.startswith('### '):
            in_blocked = False
            in_done = False

        m = re.search(r'anejo\s+(\d+)', line, re.IGNORECASE)
        if m:
            num = int(m.group(1))
            if '✓ HECHO' in line or '✓ RESUELTO' in line or '✓ CERRADO' in line:
                s = 'DONE'
            elif '◑ EN CURSO' in line:
                s = 'IN_PROGRESS'
            elif in_done:
                s = 'DONE'
            elif in_blocked:
                s = 'BLOCKED'
            else:
                s = 'READY'

            bloqueo = ''
            for j in range(i + 1, min(i + 5, len(lines))):
                if 'bloqueo:' in lines[j].lower():
                    bloqueo = lines[j].split(':', 1)[-1].strip()
                    break

            if num not in status or s == 'DONE':
                status[num] = {'status': s, 'bloqueo': bloqueo}

    return status


def load_bc3(project_root: Path):
    """Carga el BC3 maestro si existe."""
    presupuesto = project_root / 'PRESUPUESTO'
    if not presupuesto.exists():
        return None
    bc3_files = list(presupuesto.glob('*maestro*.bc3'))
    if not bc3_files:
        return None
    try:
        tools_path = str(project_root / 'tools')
        if tools_path not in sys.path:
            sys.path.insert(0, tools_path)
        import bc3_tools
        return bc3_tools.parse_bc3(str(bc3_files[0]))
    except Exception as e:
        print(f'{YEL}  Aviso: no se pudo cargar BC3: {e}{RST}')
        return None


def symbol(status):
    if status == 'present':   return f'{GRN}✓{RST}'
    if status == 'donor_only': return f'{YEL}D{RST}'
    return f'{RED}✗{RST}'


def status_color(s):
    if s == 'DONE':        return f'{GRN}DONE{RST}'
    if s == 'IN_PROGRESS': return f'{CYA}EN CURSO{RST}'
    if s == 'BLOCKED':     return f'{RED}BLOQUEADO{RST}'
    if s == 'READY':       return f'{YEL}PENDIENTE{RST}'
    return f'{GRY}?{RST}'


def main():
    parser = argparse.ArgumentParser(description='Estado del expediente POU')
    parser.add_argument('--proyecto', default=None, help='Ruta raiz del proyecto')
    parser.add_argument('--json', action='store_true', help='Exportar JSON a CONTROL/')
    parser.add_argument('--md', action='store_true', help='Exportar Markdown a CONTROL/')
    args = parser.parse_args()

    project_root = Path(args.proyecto) if args.proyecto else find_project_root()
    anejos_root = project_root / 'DOCS - ANEJOS'
    kanban_path = project_root / 'PLANNING' / 'KANBAN.md'

    print(f'\n{BLD}{CYA}══════════════════════════════════════════════════════{RST}')
    print(f'{BLD}{CYA}  ESTADO DEL EXPEDIENTE — {project_root.name[:40]}{RST}')
    print(f'{BLD}{CYA}  {datetime.now().strftime("%Y-%m-%d %H:%M")}{RST}')
    print(f'{BLD}{CYA}══════════════════════════════════════════════════════{RST}\n')

    bc3_data = load_bc3(project_root)
    if bc3_data:
        print(f'{GRN}  BC3 cargado: {len(bc3_data["conceptos"])} conceptos{RST}')
    else:
        print(f'{YEL}  BC3 no encontrado o no accesible{RST}')

    kanban = parse_kanban_status(kanban_path)

    print()
    # Cabecera tabla
    H = f'{BLD}'
    print(f'{H}{"AN":>2}  {"NOMBRE ANEJO":<32} {"WORD":^4} {"XLSX":^4} {"BC3 PARTIDAS":^14} {"ESTADO":<14} {"BLOQUEO/NOTA"}{RST}')
    print('─' * 110)

    results = []
    n_word_ok = n_xl_ok = n_bc3_ok = 0

    for num in sorted(ANEJO_BC3_MAP.keys()):
        info = ANEJO_BC3_MAP[num]
        scope = info.get('scope', 'in_scope')

        if scope in ('OUT_OF_SCOPE', 'DOES_NOT_EXIST'):
            tag = 'FUERA ALCANCE' if scope == 'OUT_OF_SCOPE' else 'NO EXISTE'
            print(f'{GRY}{num:>2}  {info["nombre"]:<32} {"—":^4} {"—":^4} {"—":^14} {tag:<14}{RST}')
            results.append({'anejo': num, 'nombre': info['nombre'], 'scope': scope})
            continue

        anejo_dir = find_anejo_dir(anejos_root, num)
        word_st = check_word(anejo_dir)
        xl_st   = check_excel(anejo_dir)
        bc3_n   = count_bc3_partidas(bc3_data, info.get('bc3_cap'))

        if word_st == 'present': n_word_ok += 1
        if xl_st   == 'present': n_xl_ok   += 1
        if bc3_n is not None and bc3_n > 0: n_bc3_ok += 1

        k = kanban.get(num, {})
        st_str  = status_color(k.get('status', '?'))
        bloqueo = k.get('bloqueo', '')[:50] if k.get('bloqueo') else ''

        bc3_str = f'{GRN}{bc3_n:>5} partidas{RST}' if bc3_n else (f'{GRY}{"—":^14}{RST}' if bc3_n is None else f'{YEL}  0 partidas{RST}')

        row = f'{num:>2}  {info["nombre"]:<32} {symbol(word_st):^4} {symbol(xl_st):^4} {bc3_str:<24} {st_str:<24} {GRY}{bloqueo}{RST}'
        print(row)

        results.append({
            'anejo': num,
            'nombre': info['nombre'],
            'scope': 'in_scope',
            'word': word_st,
            'excel': xl_st,
            'bc3_partidas': bc3_n,
            'kanban_status': k.get('status', 'unknown'),
            'bloqueo': k.get('bloqueo', ''),
        })

    in_scope = [r for r in results if r.get('scope') == 'in_scope']
    print('─' * 110)
    total_in_scope = len(in_scope)
    needs_excel = [r for r in in_scope if r.get('excel') == 'missing' and
                   ANEJO_BC3_MAP[r['anejo']].get('bc3_cap') is not None]

    print(f'\n  Anejos en alcance: {total_in_scope}')
    print(f'  Word presente:    {GRN}{n_word_ok}/{total_in_scope}{RST}')
    print(f'  Excel propio:     {GRN if n_xl_ok >= total_in_scope//2 else YEL}{n_xl_ok}/{total_in_scope}{RST}')
    print(f'  BC3 con partidas: {GRN}{n_bc3_ok}{RST} capitulos con conceptos')

    if needs_excel:
        print(f'\n  {YEL}Anejos sin Excel propio (y con partidas BC3): {", ".join(str(r["anejo"]) for r in needs_excel)}{RST}')

    print(f'\n  {GRY}Leyenda: ✓=presente  D=solo donor  ✗=ausente{RST}')
    print()

    # Exportar JSON
    if args.json:
        out = {
            'generated_at': datetime.now().isoformat(),
            'project': project_root.name,
            'anejos': results,
            'summary': {
                'total_in_scope': total_in_scope,
                'word_present': n_word_ok,
                'excel_present': n_xl_ok,
                'bc3_caps_with_concepts': n_bc3_ok,
            }
        }
        out_path = project_root / 'CONTROL' / 'expediente_status.json'
        out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding='utf-8')
        print(f'  JSON: {out_path}')

    # Exportar Markdown
    if args.md:
        lines_md = [
            f'# Estado del Expediente — {project_root.name}',
            f'',
            f'Generado: {datetime.now().strftime("%Y-%m-%d %H:%M")}',
            f'',
            f'| An | Nombre | Word | Excel | BC3 part. | Estado | Bloqueo |',
            f'|----|--------|:----:|:-----:|----------:|--------|---------|',
        ]
        for r in results:
            scope = r.get('scope', 'in_scope')
            if scope != 'in_scope':
                lines_md.append(f'| {r["anejo"]:02d} | {r["nombre"]} | — | — | — | {scope} | |')
                continue
            w = '✓' if r.get('word') == 'present' else ('D' if r.get('word') == 'donor_only' else '✗')
            x = '✓' if r.get('excel') == 'present' else ('D' if r.get('excel') == 'donor_only' else '✗')
            b = str(r.get('bc3_partidas', '—'))
            st = r.get('kanban_status', '?')
            bl = r.get('bloqueo', '')[:60]
            lines_md.append(f'| {r["anejo"]:02d} | {r["nombre"]} | {w} | {x} | {b} | {st} | {bl} |')

        lines_md += [
            '',
            f'## Resumen',
            f'',
            f'- Anejos en alcance: **{total_in_scope}**',
            f'- Word presente: **{n_word_ok}/{total_in_scope}**',
            f'- Excel propio: **{n_xl_ok}/{total_in_scope}**',
            f'- Capítulos BC3 con conceptos: **{n_bc3_ok}**',
        ]
        out_md = project_root / 'CONTROL' / 'expediente_status.md'
        out_md.write_text('\n'.join(lines_md), encoding='utf-8')
        print(f'  MD:   {out_md}')


if __name__ == '__main__':
    main()
