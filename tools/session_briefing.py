#!/usr/bin/env python3
"""
session_briefing.py
Briefing de sesion: muestra exactamente lo que necesitas saber al empezar a trabajar.

Inspirado en el patron "vault-first" de obsidian-second-brain:
conoce lo que ya esta resuelto, muestra solo lo activo y bloqueado.

Salida compacta:
  - Lecciones operativas relevantes (ultimas N)
  - Items P1 pendientes del KANBAN
  - Bloqueos activos
  - Estado rapido del expediente
  - Decisiones recientes (ultimas 5)

Uso:
    python3 tools/session_briefing.py [--proyecto=RUTA] [--compact]
    python3 tools/session_briefing.py  # desde raiz del proyecto
"""

import re
import sys
import argparse
from pathlib import Path
from datetime import datetime

# ── ANSI ──────────────────────────────────────────────────────────────────────
GRN = '\033[92m'; YEL = '\033[93m'; RED = '\033[91m'
CYA = '\033[96m'; MAG = '\033[95m'; GRY = '\033[90m'
BLD = '\033[1m';  RST = '\033[0m'


def find_project_root(start=None):
    if start is None:
        start = Path.cwd()
    for p in [Path(start)] + list(Path(start).parents):
        if (p / 'CLAUDE.md').exists() or (p / 'PRESUPUESTO').exists():
            return p
    return Path(start)


def read_lecciones(project_root: Path, max_items=5):
    """Lee las ultimas N lecciones de lecciones_operativas.md."""
    path = project_root / 'CONTROL' / 'lecciones_operativas.md'
    if not path.exists():
        return []
    text = path.read_text(encoding='utf-8', errors='replace')
    # Buscar items tipo "### L-N:" o "**Regla:**" o lineas con "→"
    lines = text.split('\n')
    lecciones = []
    current = []
    for line in lines:
        if re.match(r'^#{2,3}\s+L-?\d+', line) or (re.match(r'^###', line) and current):
            if current:
                lecciones.append(' '.join(current).strip())
                current = []
            current = [line.lstrip('#').strip()]
        elif current and line.strip() and not line.startswith('#'):
            current.append(line.strip())
            if len(current) >= 3:
                lecciones.append(' '.join(current[:2]).strip())
                current = []
    if current:
        lecciones.append(' '.join(current[:2]).strip())
    return lecciones[-max_items:]


def parse_kanban(project_root: Path):
    """Lee KANBAN.md y extrae items activos (no DONE)."""
    path = project_root / 'PLANNING' / 'KANBAN.md'
    if not path.exists():
        return {'p1': [], 'p2': [], 'blocked': []}

    text = path.read_text(encoding='utf-8', errors='replace')
    lines = text.split('\n')

    p1 = []; p2 = []; blocked = []
    in_done = False
    in_blocked = False

    for i, line in enumerate(lines):
        if '### [A] Done' in line or '### [B] Done' in line:
            in_done = True
            in_blocked = False
            continue
        if '### [A] Blocked' in line or '### [B] Blocked' in line:
            in_blocked = True
            in_done = False
            continue
        if line.startswith('### '):
            in_done = False
            in_blocked = False
            continue

        if in_done:
            continue

        # Items activos (no marcados como ✓)
        if line.strip().startswith('- `[P') and '✓' not in line:
            # Extraer prioridad y texto
            m = re.search(r'\[P(\d)\]\s+(.*?)`', line)
            if m:
                prio = int(m.group(1))
                texto = m.group(2).strip()
                bloqueo = ''
                # Buscar bloqueo en las siguientes lineas
                for j in range(i+1, min(i+4, len(lines))):
                    if 'bloqueo:' in lines[j].lower():
                        bloqueo = lines[j].split(':', 1)[-1].strip()[:80]
                        break

                item = {'texto': texto[:70], 'bloqueo': bloqueo}
                if in_blocked or bloqueo:
                    blocked.append(item)
                elif prio == 1:
                    p1.append(item)
                elif prio == 2:
                    p2.append(item)

    return {'p1': p1, 'p2': p2, 'blocked': blocked}


def read_decisiones_recientes(project_root: Path, max_n=4):
    """Lee las decisiones mas recientes de DECISIONES_PROYECTO.md."""
    path = project_root / 'DECISIONES_PROYECTO.md'
    if not path.exists():
        return []

    text = path.read_text(encoding='utf-8', errors='replace')
    # Buscar bloques ## DEC-N o ### DECISION
    decisiones = re.findall(
        r'##\s+(DEC-\d+|DECISION[^#\n]*)[^\n]*\n([^\n]{10,120})',
        text, re.IGNORECASE
    )
    result = [(d[0].strip(), d[1].strip()[:100]) for d in decisiones[-max_n:]]
    return result


def expediente_quick_status(project_root: Path):
    """Estado rapido: cuantos anejos tienen Word/Excel."""
    anejos_root = project_root / 'DOCS - ANEJOS'
    if not anejos_root.exists():
        return None

    in_scope = [n for n in range(1, 19) if n not in (9, 10, 11, 18)]

    word_ok = 0; xl_ok = 0; total = len(in_scope)
    for num in in_scope:
        pat = re.compile(rf'^{num}[.\-]')
        dirs = [d for d in anejos_root.iterdir() if d.is_dir() and pat.match(d.name)]
        if not dirs:
            continue
        d = dirs[0]
        if list(d.glob('*.docx')):
            word_ok += 1
        xl = [f for f in d.rglob('*.xlsx') if 'FUENTES' not in str(f.parent).upper()
              and not f.name.startswith('~')]
        if xl:
            xl_ok += 1

    return {'total': total, 'word': word_ok, 'excel': xl_ok}


def print_section(title, items, color=CYA, bullet='•', empty_msg=None):
    if not items and empty_msg is None:
        return
    print(f'\n{BLD}{color}── {title} ──{RST}')
    if not items:
        print(f'  {GRY}{empty_msg}{RST}')
        return
    for item in items:
        print(f'  {color}{bullet}{RST} {item}')


def main():
    parser = argparse.ArgumentParser(description='Briefing de sesion POU')
    parser.add_argument('--proyecto', default=None)
    parser.add_argument('--compact', action='store_true', help='Solo items criticos')
    args = parser.parse_args()

    project_root = Path(args.proyecto) if args.proyecto else find_project_root()

    print(f'\n{BLD}{"═"*58}{RST}')
    print(f'{BLD}{CYA}  BRIEFING DE SESION — {datetime.now().strftime("%Y-%m-%d %H:%M")}{RST}')
    print(f'{BLD}{CYA}  {project_root.name[:50]}{RST}')
    print(f'{BLD}{"═"*58}{RST}')

    # ── Kanban ────────────────────────────────────────────────────────────────
    kanban = parse_kanban(project_root)

    if kanban['blocked']:
        print(f'\n{BLD}{RED}── BLOQUEADOS ──{RST}')
        for item in kanban['blocked']:
            print(f'  {RED}⊘{RST} {item["texto"]}')
            if item['bloqueo']:
                print(f'    {GRY}└─ {item["bloqueo"]}{RST}')

    if kanban['p1']:
        print(f'\n{BLD}{YEL}── P1 PENDIENTES ──{RST}')
        for item in kanban['p1'][:5]:
            print(f'  {YEL}▶{RST} {item["texto"]}')

    if not args.compact and kanban['p2']:
        print(f'\n{GRY}── P2 En cola ──{RST}')
        for item in kanban['p2'][:3]:
            print(f'  {GRY}○{RST} {item["texto"]}')

    # ── Estado expediente ─────────────────────────────────────────────────────
    status = expediente_quick_status(project_root)
    if status:
        word_pct = int(status['word'] / status['total'] * 100)
        xl_pct   = int(status['excel'] / status['total'] * 100)
        w_color  = GRN if word_pct >= 80 else YEL
        xl_color = GRN if xl_pct >= 60 else (YEL if xl_pct >= 30 else RED)
        print(f'\n{BLD}── Expediente ──{RST}')
        print(f'  Word  {w_color}{"█" * (word_pct // 10)}{"░" * (10 - word_pct // 10)}{RST} {status["word"]}/{status["total"]} anejos')
        print(f'  Excel {xl_color}{"█" * (xl_pct // 10)}{"░" * (10 - xl_pct // 10)}{RST} {status["excel"]}/{status["total"]} anejos')

    # ── Decisiones recientes ──────────────────────────────────────────────────
    if not args.compact:
        decisiones = read_decisiones_recientes(project_root)
        if decisiones:
            print(f'\n{GRY}── Decisiones tomadas (no reabrir) ──{RST}')
            for ref, desc in decisiones:
                print(f'  {GRY}✓ {ref}: {desc}{RST}')

    # ── Lecciones clave ───────────────────────────────────────────────────────
    if not args.compact:
        lecciones = read_lecciones(project_root, max_items=3)
        if lecciones:
            print(f'\n{GRY}── Lecciones activas ──{RST}')
            for l in lecciones:
                print(f'  {GRY}↪ {l[:90]}{RST}')

    print(f'\n{BLD}{"─"*58}{RST}')
    print(f'  Comandos utiles:')
    print(f'  {GRY}python3 tools/expediente_status.py --md   → estado completo{RST}')
    print(f'  {GRY}python3 tools/organize_anejo_folders.py   → check carpetas{RST}')
    print(f'  {GRY}python3 tools/apply_project_style.py --dry-run → preview estilos{RST}')
    print()


if __name__ == '__main__':
    main()
