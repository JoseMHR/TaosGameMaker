#!/usr/bin/env python3
# ============================================================================
# gen_codemap.py  ·  Genera el MAPA DE CÓDIGO del proyecto (para humanos + IA)
# ----------------------------------------------------------------------------
# HERRAMIENTA PERMANENTE. Escanea el código GDScript y emite dos índices:
#   · docs/CODEMAP.md   → mapa navegable por ÁREA con funciones, @exports y #regions.
#   · docs/SYMBOLS.tsv  → índice plano "grepeable" symbol \t kind \t file \t line.
#
# Uso:  python tools/gen_codemap.py
# ============================================================================

import re
from pathlib import Path
from collections import OrderedDict

ROOT = Path(__file__).resolve().parent.parent
SCAN_DIRS = ["scripts", "scenes", "resources"]
CODEMAP_PATH = ROOT / "docs" / "CODEMAP.md"
SYMBOLS_PATH = ROOT / "docs" / "SYMBOLS.tsv"

# ── Regex de declaraciones GDScript ──────────────────────────────────────────
RE_CLASS = re.compile(r"^class_name\s+(\w+)")
RE_EXTENDS = re.compile(r"^extends\s+(.+?)\s*$")
RE_SIGNAL = re.compile(r"^signal\s+(\w+)\s*(\(.*\))?")
RE_FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*(\(.*?\))?\s*(->\s*[\w\.\[\], ]+)?\s*:")
RE_EXPORT = re.compile(r"^@export\s+var\s+(\w+)")
RE_REGION = re.compile(r"^#region\s+(.+)")

SEP_CHARS = set("─=-—#·•*_ ")

def read_lines(path: Path):
    text = path.read_text(encoding="utf-8-sig")
    return text.replace("\r\n", "\n").replace("\r", "\n").split("\n")

def is_separator(comment_body: str) -> bool:
    body = comment_body.strip()
    return body == "" or all(ch in SEP_CHARS for ch in body)

def file_summary(lines) -> str:
    summary = ""
    for ln in lines:
        s = ln.strip()
        if s.startswith("#"):
            body = s.lstrip("#").strip()
            if is_separator(body) or re.match(r"^[\w/]+\.gd\b", body):
                continue
            summary = body
            break
        elif s == "":
            continue
        else:
            break
    return summary

def preceding_doc(lines, idx) -> str:
    doc_lines = []
    j = idx - 1
    while j >= 0:
        s = lines[j].strip()
        if s.startswith("##"):
            doc_lines.append(s.lstrip("#").strip())
            j -= 1
        else:
            break
    if not doc_lines:
        return ""
    doc_lines.reverse()
    return " ".join(d for d in doc_lines if d)[:140]

def parse_file(path: Path):
    lines = read_lines(path)
    info = {
        "class_name": "",
        "extends": "",
        "summary": file_summary(lines),
        "n_lines": len(lines) - (1 if lines and lines[-1] == "" else 0),
        "signals": [],   # (name, line, doc)
        "exports": [],   # (name, line)
        "regions": [],   # (name, line)
        "funcs": [],     # (name, line, doc, is_static, sig, is_private)
    }

    for i, raw in enumerate(lines):
        line_no = i + 1
        s_raw = raw.strip()

        # Detección de bloques #region
        m_reg = RE_REGION.match(s_raw)
        if m_reg:
            info["regions"].append((m_reg.group(1).strip(), line_no))
            continue

        # Solo declaraciones de nivel superior
        if raw[:1] in (" ", "\t"):
            continue

        m = RE_CLASS.match(raw)
        if m:
            info["class_name"] = m.group(1)
            continue
        m = RE_EXTENDS.match(raw)
        if m and not info["extends"]:
            info["extends"] = m.group(1).strip()
            continue
        m = RE_SIGNAL.match(raw)
        if m:
            info["signals"].append((m.group(1), line_no, preceding_doc(lines, i)))
            continue
        m = RE_EXPORT.match(raw)
        if m:
            info["exports"].append((m.group(1), line_no))
            continue
        m = RE_FUNC.match(raw)
        if m:
            is_static = bool(m.group(1))
            name = m.group(2)
            sig = (m.group(3) or "()").strip()
            is_private = name.startswith("_")
            info["funcs"].append((name, line_no, preceding_doc(lines, i), is_static, sig, is_private))
            continue
    return info

def load_autoload_names():
    names = {}
    pg = ROOT / "project.godot"
    if not pg.exists():
        return names
    in_section = False
    for raw in read_lines(pg):
        s = raw.strip()
        if s.startswith("["):
            in_section = (s == "[autoload]")
            continue
        if in_section and "=" in s:
            key, _, val = s.partition("=")
            key = key.strip()
            path = val.strip().strip('"').lstrip("*")
            if path.startswith("res://"):
                names[path[len("res://"):]] = key
    return names

AREA_ORDER = [
    "Autoloads (singletons)",
    "Sistemas (scripts/systems)",
    "Config (scripts/config)",
    "Recursos (resources)",
    "Game Root / navegación",
    "Tabs (pestañas inferiores)",
    "Vistas (scenes/views)",
    "Componentes (scenes/components)",
    "UI (scenes/ui)",
    "Otros",
]

def area_for(rel: str) -> str:
    rel = rel.replace("\\", "/")
    if rel.startswith("scripts/autoload/"): return "Autoloads (singletons)"
    if rel.startswith("scripts/systems/"): return "Sistemas (scripts/systems)"
    if rel.startswith("scripts/config/"): return "Config (scripts/config)"
    if rel.startswith("resources/"): return "Recursos (resources)"
    if rel.startswith("scenes/game/"): return "Game Root / navegación"
    if rel.startswith("scenes/tabs/"): return "Tabs (pestañas inferiores)"
    if rel.startswith("scenes/views/"): return "Vistas (scenes/views)"
    if rel.startswith("scenes/components/"): return "Componentes (scenes/components)"
    if rel.startswith("scenes/ui/"): return "UI (scenes/ui)"
    return "Otros"

def main():
    files = []
    for d in SCAN_DIRS:
        base = ROOT / d
        if base.exists():
            files.extend(sorted(base.rglob("*.gd")))

    autoloads = load_autoload_names()
    parsed = [(f.relative_to(ROOT).as_posix(), parse_file(f)) for f in files]

    # ── docs/SYMBOLS.tsv ──
    tsv = ["symbol\tkind\tfile\tline\tvisibility\tsignature"]
    for rel, info in parsed:
        if info["class_name"]:
            tsv.append(f"{info['class_name']}\tclass\t{rel}\t1\tpublic\textends {info['extends']}")
        for name, line, _ in info["signals"]:
            tsv.append(f"{name}\tsignal\t{rel}\t{line}\tpublic\t")
        for name, line in info["exports"]:
            tsv.append(f"{name}\texport_var\t{rel}\t{line}\tpublic\t")
        for name, line, _, is_static, sig, is_priv in info["funcs"]:
            kind = "static_func" if is_static else "func"
            vis = "private" if is_priv else "public"
            tsv.append(f"{name}\t{kind}\t{rel}\t{line}\t{vis}\t{sig}")

    CODEMAP_PATH.parent.mkdir(parents=True, exist_ok=True)
    SYMBOLS_PATH.write_text("\n".join(tsv) + "\n", encoding="utf-8")

    # ── docs/CODEMAP.md ──
    groups = OrderedDict((a, []) for a in AREA_ORDER)
    for rel, info in parsed:
        groups[area_for(rel)].append((rel, info))

    total_funcs = sum(len(i["funcs"]) for _, i in parsed)
    total_lines = sum(i["n_lines"] for _, i in parsed)

    out = []
    out.append("# CODEMAP — Mapa de código (autogenerado)")
    out.append("")
    out.append("> ⚙️ **Fichero AUTOGENERADO por `tools/gen_codemap.py`. NO editar a mano.**")
    out.append("> Regénералo tras cambios estructurales:  `python tools/gen_codemap.py`")
    out.append(">")
    out.append("> Índice de ALTA SEÑAL para localizar *dónde tocar* sin abrir ficheros enormes.")
    out.append("> Para saltar a un símbolo concreto, busca en `docs/SYMBOLS.tsv` (`symbol · kind · file · line`).")
    out.append("")
    out.append(f"**Totales:** {len(parsed)} ficheros `.gd` · {total_lines} líneas · {total_funcs} funciones.")
    out.append("")
    out.append("Leyenda: `nombre Lnn` = función en la línea *nn*. `(s)` = static · `_nombre` = privada.")
    out.append("")

    for area, items in groups.items():
        if not items:
            continue
        out.append(f"## {area}")
        out.append("")
        items.sort(key=lambda x: x[0])
        for rel, info in items:
            title = info["class_name"] or Path(rel).stem
            al = autoloads.get(rel)
            head = f"### `{title}`"
            if al:
                head += f"  ·  autoload **{al}**"
            out.append(head)
            meta = f"`{rel}` · {info['n_lines']} líneas"
            if info["extends"]:
                meta += f" · extends `{info['extends']}`"
            out.append(meta)
            if info["summary"]:
                out.append("")
                out.append(info["summary"])
            if info["regions"]:
                out.append("")
                regs = ", ".join(f"`{n}` L{ln}" for n, ln in info["regions"])
                out.append(f"- **regions:** {regs}")
            if info["signals"]:
                out.append("")
                sigs = ", ".join(f"`{n}` L{ln}" for n, ln, _ in info["signals"])
                out.append(f"- **signals:** {sigs}")
            if info["funcs"]:
                pub = [f for f in info["funcs"] if not f[5]]
                priv = [f for f in info["funcs"] if f[5]]

                def fmt(fn):
                    name, line, _, is_static, _, _ = fn
                    tag = "(s)" if is_static else ""
                    return f"`{name}`{tag} L{line}"

                def emit_list(label, fns, per_line=8):
                    if not fns:
                        return
                    items_fmt = [fmt(f) for f in fns]
                    first = True
                    for k in range(0, len(items_fmt), per_line):
                        chunk = ", ".join(items_fmt[k:k + per_line])
                        out.append(f"- **{label}:** {chunk}" if first else f"  {chunk}")
                        first = False

                emit_list("funcs", pub)
                emit_list("privadas", priv)
            out.append("")

    CODEMAP_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"OK · {CODEMAP_PATH.relative_to(ROOT)} ({len(out)} líneas) · {SYMBOLS_PATH.relative_to(ROOT)} ({len(tsv)} símbolos)")

if __name__ == "__main__":
    main()