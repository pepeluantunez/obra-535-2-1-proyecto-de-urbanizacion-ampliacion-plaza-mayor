import csv
import json
import re
import shutil
import hashlib
import unicodedata
from pathlib import Path
from datetime import datetime

REPO = Path(r"C:\Users\USUARIO\Documents\Claude\Projects\535.2.1 - Proyecto de Urbanizacion - Ampliacion Plaza Mayor")
IN_DIR = REPO / r"DOCS - ANEJOS\6.- Red de Agua Potable"
OUT_ROOT = REPO / r"CONTROL\trazabilidad\abastecimiento_civil3d_2026-04-29"

INPUT_FILES = {
    "fd150": "FD150 PROPUESTO.csv",
    "fd200": "FD200 PROPUESTO.csv",
    "tuberias": "LISTA DE TUBERIAS.csv",
    "accesorios": "LISTA DE ACCESORIOS.csv",
    "ehm": "LISTA DE EHM.csv",
}

ENCODINGS = ["utf-8-sig", "utf-8", "cp1252"]

SUBDIRS = [
    "00_fuentes_originales",
    "01_normalizado",
    "02_propuesto_fd150_fd200",
    "03_mediciones",
    "04_mapeo_bc3",
    "05_textos_memoria_anejo",
    "06_informe_control",
]

MOJIBAKE_PATTERNS = ["Ã", "Â", "â€“", "â€œ", "â€\x9d", "Ã‘", "Ã“", "COMPROBACIÃ“N", "URBANIZACIÃ“N"]


def ensure_dirs():
    for sd in SUBDIRS:
        (OUT_ROOT / sd).mkdir(parents=True, exist_ok=True)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_text_with_fallback(path: Path):
    last_err = None
    for enc in ENCODINGS:
        try:
            return path.read_text(encoding=enc), enc, None
        except UnicodeDecodeError as e:
            last_err = str(e)
    return None, None, last_err


def normalize_key(s: str) -> str:
    s = (s or "").strip().lower()
    s = unicodedata.normalize("NFD", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = re.sub(r"\s+", " ", s)
    return s


def find_row_index(rows, predicate):
    for i, row in enumerate(rows):
        if not row:
            continue
        joined = ",".join(row)
        if predicate(joined):
            return i
    return None


def parse_civil_csv(path: Path):
    text, used_enc, err = read_text_with_fallback(path)
    if text is None:
        return {
            "ok": False,
            "error": f"No se pudo decodificar con {ENCODINGS}: {err}",
            "encoding": None,
        }

    rows = list(csv.reader(text.splitlines(), delimiter=","))
    meta = {}
    for r in rows[:6]:
        if len(r) >= 2 and r[0].strip():
            meta[r[0].strip().rstrip(":")] = r[1].strip()

    # tabla resumen red
    idx_sum = find_row_index(rows, lambda j: normalize_key(j).startswith("nombre de la red de tuberias"))
    summary = None
    if idx_sum is not None and idx_sum + 1 < len(rows):
        h = rows[idx_sum]
        d = rows[idx_sum + 1]
        summary = {h[i]: (d[i] if i < len(d) else "") for i in range(len(h))}

    idx_det = None
    markers = [
        "distancia de tramo",  # fd150/fd200
        "nombre de tuberia",   # lista tuberias
        "nombre de accesorio", # lista accesorios
        "nombre del elemento hidromecanico", # lista ehm
    ]
    for m in markers:
        idx_det = find_row_index(rows, lambda j, m=m: m in normalize_key(j))
        if idx_det is not None:
            break

    if idx_det is None:
        return {
            "ok": False,
            "error": "No se encontró cabecera de detalle reconocible.",
            "encoding": used_enc,
            "meta": meta,
            "summary": summary,
        }

    hdr = rows[idx_det]
    data = []
    for r in rows[idx_det + 1 :]:
        if not any((c or "").strip() for c in r):
            continue
        if len(r) < len(hdr):
            r = r + [""] * (len(hdr) - len(r))
        data.append({hdr[i]: r[i] for i in range(len(hdr))})

    return {
        "ok": True,
        "encoding": used_enc,
        "meta": meta,
        "summary": summary,
        "header": hdr,
        "rows": data,
        "raw_text": text,
    }


def to_float(v: str):
    if v is None:
        return None
    t = str(v).strip().replace(" ", "")
    if not t:
        return None
    t = t.replace("%", "")
    t = t.replace(",", ".")
    try:
        return float(t)
    except ValueError:
        return None


def parse_piece_id(name: str):
    m = re.search(r"\((\d+)\)", name or "")
    return int(m.group(1)) if m else None


def write_csv(path: Path, rows, fieldnames):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fieldnames})


def load_bc3_concepts(path: Path):
    concepts = []
    txt = path.read_text(encoding="latin-1", errors="replace")
    for ln in txt.splitlines():
        if not ln.startswith("~C|"):
            continue
        p = ln.split("|")
        if len(p) < 7:
            continue
        code = p[1]
        unit = p[2]
        desc = p[3]
        price = p[4]
        # tipo: 0 cap/partida,1 mano obra,2 maq,3 material
        ctype = p[6]
        concepts.append({
            "codigo": code,
            "unidad": unit,
            "descripcion": desc,
            "precio": price,
            "tipo_concepto": ctype,
        })
    return concepts


def candidate_bc3(concepts, dn, tipo_pieza, nombre_pieza, desc_pieza):
    d = normalize_key(desc_pieza)
    tp = normalize_key(tipo_pieza)

    out = []
    for c in concepts:
        cd = normalize_key(c["descripcion"])
        code = c["codigo"]
        unit = normalize_key(c["unidad"])

        score = 0
        motivo = []

        if tipo_pieza == "Tubería a presión":
            if unit in {"m", "ml", "m."}:
                score += 20
                motivo.append("unidad_lineal")
            if "fundici" in cd:
                score += 25
                motivo.append("material_fundicion")
            if dn and f"dn={dn}" in cd:
                score += 35
                motivo.append("dn_exacto")
            elif dn and f"dn {dn}" in cd:
                score += 30
                motivo.append("dn_espacio")
            elif dn and f"d={dn}" in cd:
                score += 30
                motivo.append("d_exacto")
            if code.startswith("AP-"):
                score += 12
                motivo.append("familia_ap")

        elif tipo_pieza in {"Codo", "Unión en T"}:
            if unit in {"ud", "u", "ud."}:
                score += 15
                motivo.append("unidad_ud")
            if tipo_pieza == "Codo" and ("codo" in cd or "bend" in cd):
                score += 35
                motivo.append("tipo_codo")
            if tipo_pieza == "Unión en T" and ("te " in f" {cd} " or " t " in f" {cd} " or "tee" in cd):
                score += 35
                motivo.append("tipo_te")
            if "fundici" in cd:
                score += 20
                motivo.append("material_fundicion")
            if dn and (f"dn {dn}" in cd or f"dn={dn}" in cd or f"d={dn}" in cd):
                score += 20
                motivo.append("dn_aprox")

        elif tipo_pieza in {"Válvula", "Hidrante"}:
            if unit in {"ud", "u", "ud."}:
                score += 15
                motivo.append("unidad_ud")
            if tipo_pieza == "Válvula" and ("valv" in cd):
                score += 38
                motivo.append("tipo_valvula")
            if tipo_pieza == "Hidrante" and ("hidrante" in cd):
                score += 38
                motivo.append("tipo_hidrante")
            if dn and (f"dn {dn}" in cd or f"dn={dn}" in cd or f"d={dn}" in cd):
                score += 22
                motivo.append("dn_aprox")

        if score > 0:
            out.append({
                "codigo_bc3": c["codigo"],
                "unidad_bc3": c["unidad"],
                "descripcion_bc3": c["descripcion"],
                "precio_bc3": c["precio"],
                "score": score,
                "motivo": "+".join(motivo),
            })

    out.sort(key=lambda x: (-x["score"], x["codigo_bc3"]))
    return out[:5]


def main():
    ensure_dirs()

    incidencias = []
    fuentes = {}

    # 00: copia fuente original + inventario
    for key, fn in INPUT_FILES.items():
        src = IN_DIR / fn
        if not src.exists():
            incidencias.append({
                "tipo": "entrada_faltante",
                "archivo": fn,
                "detalle": "No localizado en rutas revisadas del repo."
            })
            continue
        dst = OUT_ROOT / "00_fuentes_originales" / fn
        shutil.copy2(src, dst)

        parsed = parse_civil_csv(src)
        fuentes[key] = {
            "archivo": fn,
            "ruta": str(src),
            "sha256": sha256_file(src),
            "encoding_detectado": parsed.get("encoding"),
            "ok_parseo": parsed.get("ok", False),
            "error_parseo": parsed.get("error"),
            "meta": parsed.get("meta", {}),
            "resumen_red": parsed.get("summary", {}),
            "n_filas_detalle": len(parsed.get("rows", [])) if parsed.get("ok") else 0,
        }

        if not parsed.get("ok"):
            incidencias.append({
                "tipo": "parseo",
                "archivo": fn,
                "detalle": parsed.get("error"),
            })
            continue

        # 01: normalizado detalle
        rows = parsed["rows"]
        out_norm = OUT_ROOT / "01_normalizado" / f"{Path(fn).stem}__detalle_normalizado.csv"
        write_csv(out_norm, rows, parsed["header"])

        # 01: meta
        with (OUT_ROOT / "01_normalizado" / f"{Path(fn).stem}__meta.json").open("w", encoding="utf-8") as f:
            json.dump({
                "encoding_origen": parsed["encoding"],
                "meta": parsed.get("meta", {}),
                "resumen_red": parsed.get("summary", {}),
                "n_filas_detalle": len(rows),
            }, f, ensure_ascii=False, indent=2)

    # si faltan críticas, cerrar con informe mínimo
    required = ["fd150", "fd200", "tuberias", "accesorios", "ehm"]
    if any((k not in fuentes or not fuentes[k].get("ok_parseo")) for k in required):
        with (OUT_ROOT / "06_informe_control" / "informe_control.md").open("w", encoding="utf-8") as f:
            f.write("# Informe de control — Abastecimiento Civil 3D\n\n")
            f.write("## Estado\n")
            f.write("No se pudo completar el cruce por falta de entradas o errores de parseo.\n\n")
            f.write("## Incidencias\n")
            for inc in incidencias:
                f.write(f"- [{inc['tipo']}] {inc.get('archivo','')}: {inc['detalle']}\n")
        return

    # cargar datasets normalizados
    p_fd150 = parse_civil_csv(IN_DIR / INPUT_FILES["fd150"])
    p_fd200 = parse_civil_csv(IN_DIR / INPUT_FILES["fd200"])
    p_tub = parse_civil_csv(IN_DIR / INPUT_FILES["tuberias"])
    p_acc = parse_civil_csv(IN_DIR / INPUT_FILES["accesorios"])
    p_ehm = parse_civil_csv(IN_DIR / INPUT_FILES["ehm"])

    fd_rows = []
    for origen, parsed in [("FD150 PROPUESTO", p_fd150), ("FD200 PROPUESTO", p_fd200)]:
        for r in parsed["rows"]:
            rr = dict(r)
            rr["origen_fd"] = origen
            rr["pieza_id"] = parse_piece_id(r.get("Nombre de pieza", ""))
            fd_rows.append(rr)

    # 02A: filas FD combinadas (muestreo por PK)
    fd_fields = list(p_fd150["header"])
    if "origen_fd" not in fd_fields:
        fd_fields.append("origen_fd")
    if "pieza_id" not in fd_fields:
        fd_fields.append("pieza_id")
    write_csv(OUT_ROOT / "02_propuesto_fd150_fd200" / "fd_muestreo_combinado.csv", fd_rows, fd_fields)

    # 02B: universo propuesto = piezas únicas en FD150/FD200
    by_piece = {}
    for r in fd_rows:
        name = r.get("Nombre de pieza", "")
        if not name:
            continue
        key = name
        if key not in by_piece:
            by_piece[key] = {
                "nombre_pieza": name,
                "pieza_id": parse_piece_id(name),
                "tipo_pieza": r.get("Tipo de pieza", ""),
                "origen_fd": set(),
                "n_muestras_pk": 0,
                "pk_min": None,
                "pk_max": None,
            }
        p = by_piece[key]
        p["origen_fd"].add(r.get("origen_fd", ""))
        p["n_muestras_pk"] += 1

        pk = r.get("Distancia de tramo de tubería", "")
        m = re.match(r"\s*(\d+)\+(\d+(?:\.\d+)?)\s*$", pk)
        if m:
            val = float(m.group(1)) * 1000 + float(m.group(2))
            p["pk_min"] = val if p["pk_min"] is None else min(p["pk_min"], val)
            p["pk_max"] = val if p["pk_max"] is None else max(p["pk_max"], val)

    # índices generales
    idx_tub = {r.get("Nombre de tubería", ""): r for r in p_tub["rows"]}
    idx_acc = {r.get("Nombre de accesorio", ""): r for r in p_acc["rows"]}
    idx_ehm = {r.get("Nombre del elemento hidromecánico", ""): r for r in p_ehm["rows"]}

    proposed_enriched = []
    missing_general = []

    for key, p in sorted(by_piece.items(), key=lambda kv: ((kv[1]["pieza_id"] or 10**9), kv[0])):
        tipo = p["tipo_pieza"]
        gen = None
        tabla_general = ""

        if tipo == "Tubería a presión":
            gen = idx_tub.get(key)
            tabla_general = "LISTA DE TUBERIAS"
        elif tipo in {"Codo", "Unión en T"}:
            gen = idx_acc.get(key)
            tabla_general = "LISTA DE ACCESORIOS"
        elif tipo in {"Válvula", "Hidrante"}:
            gen = idx_ehm.get(key)
            tabla_general = "LISTA DE EHM"
        else:
            # fallback
            gen = idx_tub.get(key) or idx_acc.get(key) or idx_ehm.get(key)
            tabla_general = "AUTO"

        if gen is None:
            missing_general.append(key)

        dn = None
        desc_pieza = ""
        material = ""
        nombre_tecnico = ""
        long_3d = None

        if gen:
            # campos comunes según lista
            dn = to_float(gen.get("Diámetro nominal", ""))
            desc_pieza = gen.get("Descripción de pieza", "") or gen.get("Descripción", "")
            material = gen.get("Material", "")
            nombre_tecnico = gen.get("Descripción", "")
            if "Longitud 3D" in gen:
                long_3d = to_float(gen.get("Longitud 3D", ""))

        proposed_enriched.append({
            "nombre_pieza": key,
            "pieza_id": p["pieza_id"],
            "tipo_pieza": tipo,
            "origen_fd": ";".join(sorted(x for x in p["origen_fd"] if x)),
            "n_muestras_pk": p["n_muestras_pk"],
            "pk_min_m": p["pk_min"] if p["pk_min"] is not None else "",
            "pk_max_m": p["pk_max"] if p["pk_max"] is not None else "",
            "fuente_general": tabla_general,
            "encontrado_en_general": "SI" if gen else "NO",
            "diametro_nominal_mm": dn if dn is not None else "",
            "descripcion_pieza": desc_pieza,
            "material": material,
            "nombre_tecnico_general": nombre_tecnico,
            "longitud_3d_m": long_3d if long_3d is not None else "",
        })

    write_csv(
        OUT_ROOT / "02_propuesto_fd150_fd200" / "universo_propuesto_enriquecido.csv",
        proposed_enriched,
        [
            "nombre_pieza","pieza_id","tipo_pieza","origen_fd","n_muestras_pk","pk_min_m","pk_max_m",
            "fuente_general","encontrado_en_general","diametro_nominal_mm","descripcion_pieza",
            "material","nombre_tecnico_general","longitud_3d_m"
        ],
    )

    if missing_general:
        incidencias.append({
            "tipo": "cruce_general",
            "archivo": "universo_propuesto_enriquecido.csv",
            "detalle": f"{len(missing_general)} piezas propuestas sin correspondencia en listas generales.",
            "piezas": missing_general,
        })

    # 03 mediciones
    pipes = [r for r in proposed_enriched if r["tipo_pieza"] == "Tubería a presión"]
    no_pipes = [r for r in proposed_enriched if r["tipo_pieza"] != "Tubería a presión"]

    med_tuberias = {}
    for r in pipes:
        dn = r["diametro_nominal_mm"]
        key = f"DN{int(dn)}" if isinstance(dn, (int,float)) and dn != "" else "DN_NO_DEFINIDO"
        med_tuberias.setdefault(key, {"grupo": key, "n_tuberias": 0, "longitud_3d_m": 0.0})
        med_tuberias[key]["n_tuberias"] += 1
        l = to_float(r.get("longitud_3d_m", ""))
        if l is not None:
            med_tuberias[key]["longitud_3d_m"] += l

    med_tub_rows = []
    total_long = 0.0
    for k in sorted(med_tuberias.keys()):
        rr = med_tuberias[k]
        total_long += rr["longitud_3d_m"]
        med_tub_rows.append({
            "grupo": rr["grupo"],
            "n_tuberias": rr["n_tuberias"],
            "longitud_3d_m": f"{rr['longitud_3d_m']:.3f}",
        })
    med_tub_rows.append({"grupo": "TOTAL", "n_tuberias": sum(r["n_tuberias"] for r in med_tub_rows), "longitud_3d_m": f"{total_long:.3f}"})

    write_csv(
        OUT_ROOT / "03_mediciones" / "medicion_tuberias_propuestas.csv",
        med_tub_rows,
        ["grupo", "n_tuberias", "longitud_3d_m"],
    )

    med_piezas = {}
    for r in no_pipes:
        k = r["tipo_pieza"] or "TIPO_NO_DEFINIDO"
        med_piezas[k] = med_piezas.get(k, 0) + 1

    med_pz_rows = [{"tipo_pieza": k, "unidades": v} for k, v in sorted(med_piezas.items())]
    med_pz_rows.append({"tipo_pieza": "TOTAL", "unidades": sum(med_piezas.values())})
    write_csv(
        OUT_ROOT / "03_mediciones" / "medicion_piezas_especiales_propuestas.csv",
        med_pz_rows,
        ["tipo_pieza", "unidades"],
    )

    # 04 mapeo BC3 candidato
    bc3_path = REPO / r"PRESUPUESTO\535.2.1_maestro.bc3"
    bc3_concepts = load_bc3_concepts(bc3_path)

    map_rows = []
    unresolved = []

    for r in proposed_enriched:
        dn = to_float(r.get("diametro_nominal_mm", ""))
        dn_i = int(dn) if dn is not None else None
        cands = candidate_bc3(
            bc3_concepts,
            dn_i,
            r.get("tipo_pieza", ""),
            r.get("nombre_pieza", ""),
            r.get("descripcion_pieza", ""),
        )

        top = cands[0] if cands else None
        confianza = "ALTA" if top and top["score"] >= 70 else ("MEDIA" if top and top["score"] >= 45 else ("BAJA" if top else "SIN_MAPEO"))

        row = {
            "nombre_pieza": r.get("nombre_pieza", ""),
            "pieza_id": r.get("pieza_id", ""),
            "tipo_pieza": r.get("tipo_pieza", ""),
            "diametro_nominal_mm": r.get("diametro_nominal_mm", ""),
            "descripcion_pieza": r.get("descripcion_pieza", ""),
            "codigo_bc3_sugerido": top["codigo_bc3"] if top else "",
            "unidad_bc3_sugerida": top["unidad_bc3"] if top else "",
            "descripcion_bc3_sugerida": top["descripcion_bc3"] if top else "",
            "precio_bc3_sugerido": top["precio_bc3"] if top else "",
            "score_mapeo": top["score"] if top else "",
            "confianza": confianza,
            "motivo": top["motivo"] if top else "",
            "alternativas_bc3": " || ".join(
                [f"{c['codigo_bc3']} ({c['score']})" for c in cands[1:4]]
            ) if len(cands) > 1 else "",
        }
        map_rows.append(row)

        if confianza in {"BAJA", "SIN_MAPEO"}:
            unresolved.append(row)

    write_csv(
        OUT_ROOT / "04_mapeo_bc3" / "mapeo_propuesto_a_bc3_candidato.csv",
        map_rows,
        [
            "nombre_pieza","pieza_id","tipo_pieza","diametro_nominal_mm","descripcion_pieza",
            "codigo_bc3_sugerido","unidad_bc3_sugerida","descripcion_bc3_sugerida","precio_bc3_sugerido",
            "score_mapeo","confianza","motivo","alternativas_bc3"
        ],
    )

    if unresolved:
        incidencias.append({
            "tipo": "mapeo_bc3",
            "archivo": "mapeo_propuesto_a_bc3_candidato.csv",
            "detalle": f"{len(unresolved)} elementos con confianza BAJA o SIN_MAPEO.",
        })

    # 05 textos memoria/anejo (sin tocar DOCX)
    tub_dn = {r["grupo"]: r["longitud_3d_m"] for r in med_tub_rows if r["grupo"] != "TOTAL"}
    pz_total = sum(v for k, v in med_piezas.items())

    texto_memoria = (
        "Base trazable Civil 3D (29/04/2026): la red de abastecimiento propuesta se ha delimitado "
        "exclusivamente con los ejes FD150 PROPUESTO y FD200 PROPUESTO. "
        "Las listas generales de tuberías, accesorios y EHM se han usado solo para enriquecer atributos "
        "(DN, tipo de pieza, descripción y material) de los elementos presentes en dichos ejes. "
        f"Resultado provisional: {len(pipes)} tramos de tubería propuestos (longitud 3D total {total_long:.3f} m) "
        f"y {pz_total} piezas especiales (accesorios y EHM)."
    )

    texto_anejo = (
        "Criterio de medición adoptado: \n"
        "1) Universo propuesto = elementos identificados en FD150 PROPUESTO y FD200 PROPUESTO.\n"
        "2) Enriquecimiento = cruce por nombre de pieza con LISTA DE TUBERIAS, LISTA DE ACCESORIOS y LISTA DE EHM.\n"
        "3) Medición lineal = suma de 'Longitud 3D' en la lista general únicamente para tuberías incluidas en el universo propuesto.\n"
        "4) Piezas especiales = recuento unitario por tipo (codos, uniones en T, válvulas, hidrantes) limitado al universo propuesto.\n"
        "5) Integración BC3 = mapeo candidato por similitud de unidad/material/diámetro, pendiente de validación técnica antes de cargar ~M."
    )

    (OUT_ROOT / "05_textos_memoria_anejo" / "texto_memoria_base.txt").write_text(texto_memoria + "\n", encoding="utf-8")
    (OUT_ROOT / "05_textos_memoria_anejo" / "texto_anejo6_base.txt").write_text(texto_anejo + "\n", encoding="utf-8")

    # cobertura y control
    total_universe = len(proposed_enriched)
    covered_general = sum(1 for r in proposed_enriched if r["encontrado_en_general"] == "SI")
    pct_covered = (covered_general / total_universe * 100.0) if total_universe else 0.0

    by_conf = {}
    for r in map_rows:
        by_conf[r["confianza"]] = by_conf.get(r["confianza"], 0) + 1

    # anti-mojibake outputs
    mojibake_hits = []
    for p in OUT_ROOT.rglob("*"):
        if p.is_file() and p.suffix.lower() in {".csv", ".json", ".md", ".txt"}:
            txt = p.read_text(encoding="utf-8", errors="ignore")
            for pat in MOJIBAKE_PATTERNS:
                if pat in txt:
                    mojibake_hits.append({"archivo": str(p.relative_to(OUT_ROOT)), "patron": pat})

    if mojibake_hits:
        incidencias.append({
            "tipo": "mojibake",
            "archivo": "salidas",
            "detalle": f"Detectados {len(mojibake_hits)} patrones sospechosos de mojibake en salidas.",
        })

    # reporte técnico
    report_md = []
    report_md.append("# Informe de control — Trazabilidad Abastecimiento Civil 3D")
    report_md.append("")
    report_md.append("## Alcance ejecutado")
    report_md.append("- Proyecto: 535.2.1 Plaza Mayor.")
    report_md.append("- Fecha de extracción Civil 3D detectada: 29/04/2026.")
    report_md.append("- Criterio aplicado: universo propuesto limitado a `FD150 PROPUESTO.csv` y `FD200 PROPUESTO.csv`.")
    report_md.append("- Listas generales usadas solo para enriquecimiento/verificación.")
    report_md.append("")
    report_md.append("## Fuentes localizadas")
    for k in ["fd150","fd200","tuberias","accesorios","ehm"]:
        fsrc = fuentes.get(k, {})
        report_md.append(f"- {fsrc.get('archivo','N/A')}: parseo={fsrc.get('ok_parseo')} encoding={fsrc.get('encoding_detectado')} filas_detalle={fsrc.get('n_filas_detalle',0)}")
    report_md.append("")
    report_md.append("## Cobertura de cruce")
    report_md.append(f"- Universo propuesto (piezas únicas): {total_universe}")
    report_md.append(f"- Con correspondencia en listas generales: {covered_general} ({pct_covered:.2f}%)")
    report_md.append("")
    report_md.append("## Medición propuesta (pre-BC3)")
    report_md.append(f"- Tramos de tubería propuestos: {len(pipes)}")
    report_md.append(f"- Longitud 3D total propuesta: {total_long:.3f} m")
    for k in sorted(tub_dn.keys()):
        report_md.append(f"- {k}: {tub_dn[k]} m")
    report_md.append(f"- Piezas especiales propuestas (accesorios+EHM): {pz_total}")
    report_md.append("")
    report_md.append("## Estado del mapeo BC3 candidato")
    for k in sorted(by_conf.keys()):
        report_md.append(f"- {k}: {by_conf[k]} elementos")
    report_md.append("- Nota: no se ha modificado BC3 ni se han generado líneas ~M en esta tarea.")
    report_md.append("")
    report_md.append("## Incidencias")
    if incidencias:
        for inc in incidencias:
            report_md.append(f"- [{inc['tipo']}] {inc.get('archivo','')}: {inc['detalle']}")
    else:
        report_md.append("- Sin incidencias bloqueantes.")
    report_md.append("")
    report_md.append("## Verificaciones finales")
    report_md.append("- Verificación de integridad de fuentes: hashes SHA256 generados.")
    report_md.append("- Verificación de codificación de entrada: fallback utf-8-sig/utf-8/cp1252 aplicado.")
    report_md.append("- Verificación anti-mojibake en salidas UTF-8: completada.")

    (OUT_ROOT / "06_informe_control" / "informe_control.md").write_text("\n".join(report_md) + "\n", encoding="utf-8")

    # inventario JSON global
    manifest = {
        "generado_en": datetime.now().isoformat(timespec="seconds"),
        "output_root": str(OUT_ROOT),
        "fuentes": fuentes,
        "incidencias": incidencias,
        "metricas": {
            "universo_propuesto_piezas_unicas": total_universe,
            "tramos_tuberia": len(pipes),
            "longitud_3d_total_m": round(total_long, 3),
            "piezas_especiales": pz_total,
            "cobertura_cruce_general_pct": round(pct_covered, 2),
            "mapeo_bc3_confianza": by_conf,
        },
        "notas": {
            "sin_modificacion_bc3": True,
            "sin_modificacion_docx": True,
        },
    }
    (OUT_ROOT / "06_informe_control" / "manifest_trazabilidad.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
