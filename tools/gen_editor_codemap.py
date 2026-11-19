#!/usr/bin/env python3
# ============================================================================
# gen_editor_codemap.py  ·  MAPA DE CÓDIGO del EDITOR (SPA Vue 3) — para IA+humanos
# ----------------------------------------------------------------------------
# HERRAMIENTA PERMANENTE. Escanea `editor/js/**/*.js` y `editor/styles.css`
# y emite un índice de ALTA SEÑAL (`editor/CODEMAP.md`) para localizar "dónde tocar"
# en el editor sin abrir ficheros enteros.
#
# Uso:  python tools/gen_editor_codemap.py
# ============================================================================

import re
from pathlib import Path
from collections import OrderedDict

ROOT = Path(__file__).resolve().parent.parent
EDITOR = ROOT / "editor"
JS_DIR = EDITOR / "js"
CSS_PATH = EDITOR / "styles.css"
OUT_PATH = EDITOR / "CODEMAP.md"

SEP_CHARS = set("─=-—#·•*_/ ")
JS_KEYWORDS = {"if", "for", "while", "switch", "catch", "function", "return", "import", "export"}

RE_EXPORT_FUNC = re.compile(r"^export\s+(?:async\s+)?function\s+(\w+)")
RE_EXPORT_CONST = re.compile(r"^export\s+const\s+(\w+)")
RE_EXPORT_DEFAULT = re.compile(r"^export\s+default\b")
RE_NAME = re.compile(r"^\s*name:\s*['\"](\w+)['\"]")
RE_TEMPLATE = re.compile(r"^\s*template:\s*[`'\"]")
RE_TEMPLATE_IMPORT = re.compile(r"^import\s+TEMPLATE\s+from\s+['\"](.+?)['\"]")

# Captura sintaxis estándar + sintaxis concisa de objetos Vue: `metodo() {` o `async metodo() {`
RE_FUNC_FULL = re.compile(
    r"^\s*(?:export\s+)?(?:async\s+)?(?:function\s+(\w+)|const\s+(\w+)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>|(?:async\s+)?([a-zA-Z_$]\w*)\s*\([^)]*\)\s*\{)"
)
RE_SECTION = re.compile(r"^\s*//\s*[─\-]{2,}\s*(.+?)\s*[─\-]{2,}")

def read_lines(path: Path):
    text = path.read_text(encoding="utf-8-sig")
    return text.replace("\r\n", "\n").replace("\r", "\n").split("\n")

def is_separator(body: str) -> bool:
    body = body.strip()
    return body == "" or all(ch in SEP_CHARS for ch in body)

def file_summary(lines) -> str:
    for ln in lines:
        s = ln.strip()
        if s.startswith("//"):
            body = s.lstrip("/").strip()
            if is_separator(body) or re.match(r"^[\w/]+\.js\b", body):
                continue
            return body
        elif s == "":
            continue
        else:
            break
    return ""

def parse_js(path: Path):
    lines = read_lines(path)
    info = {
        "summary": file_summary(lines),
        "n_lines": len(lines) - (1 if lines and lines[-1] == "" else 0),
        "component": "",
        "exports": [],
        "template_line": 0,
        "template_file": "",
        "sections": [],
        "funcs": [],
    }
    seen_funcs = set()

    for i, raw in enumerate(lines):
        line_no = i + 1

        # Detección de secciones de comentario
        m_sec = RE_SECTION.match(raw)
        if m_sec:
            info["sections"].append((m_sec.group(1).strip(), line_no))
            continue

        m = RE_EXPORT_FUNC.match(raw)
        if m:
            info["exports"].append((m.group(1), line_no, "func"))
            continue
        m = RE_EXPORT_CONST.match(raw)
        if m:
            info["exports"].append((m.group(1), line_no, "const"))
            continue
        if RE_EXPORT_DEFAULT.match(raw):
            info["exports"].append(("default", line_no, "default"))
            continue
        if not info["component"]:
            m = RE_NAME.match(raw)
            if m:
                info["component"] = m.group(1)
        if not info["template_line"] and RE_TEMPLATE.match(raw):
            info["template_line"] = line_no
        if not info["template_file"]:
            m = RE_TEMPLATE_IMPORT.match(raw)
            if m:
                info["template_file"] = m.group(1).lstrip("./")

        m_fn = RE_FUNC_FULL.match(raw)
        if m_fn:
            fn_name = m_fn.group(1) or m_fn.group(2) or m_fn.group(3)
            if fn_name and fn_name not in JS_KEYWORDS and fn_name not in seen_funcs:
                seen_funcs.add(fn_name)
                info["funcs"].append((fn_name, line_no))

    return info

def parse_tabs():
    coll = JS_DIR / "collections.js"
    tabs = OrderedDict()
    if not coll.exists():
        return tabs
    text = "\n".join(read_lines(coll))
    for m in re.finditer(r"\{\s*key:\s*'(\w+)'([^}]*)\}", text):
        key, rest = m.group(1), m.group(2)
        lbl = re.search(r"label:\s*'([^']*)'", rest)
        ico = re.search(r"icon:\s*'([^']*)'", rest)
        grp = re.search(r"group:\s*'([^']*)'", rest)
        cmp = re.search(r"component:\s*'(\w+)'", rest)
        tabs[key] = {
            "label": lbl.group(1) if lbl else key,
            "icon": ico.group(1) if ico else "",
            "group": grp.group(1) if grp else "",
            "component": cmp.group(1) if cmp else "—",
        }
    return tabs

def parse_css_sections():
    if not CSS_PATH.exists():
        return []
    out = []
    lines = read_lines(CSS_PATH)
    for i, raw in enumerate(lines):
        s = raw.strip()
        m = re.match(r"^/\*\s*[─\-]{2,}\s*(.+?)\s*[─\-]{2,}\s*\*/$", s)
        if m:
            out.append((m.group(1).strip(), i + 1))
            continue
        if re.match(r"^/\*\s*[═=]{6,}", s):
            nxt = lines[i + 1].strip() if i + 1 < len(lines) else ""
            title = nxt.lstrip("*").strip() if nxt and not nxt.startswith("*/") else ""
            if title:
                out.append((title[:70], i + 1))
    return out

def area_for(rel: str) -> str:
    r = rel.replace("\\", "/")
    if r.startswith("js/components/templates/"):
        return "Plantillas Markup (js/components/templates)"
    if r.startswith("js/components/"):
        return "Componentes (editores por sistema)"
    if r.startswith("js/lib/"):
        return "Composables / lógica común (js/lib)"
    if r.startswith("js/ui/"):
        return "Design System (js/ui)"
    if r in ("js/app.js", "js/store.js", "js/nav.js", "js/fs.js", "js/validator.js"):
        return "Raíz / shell"
    return "Otros"

AREA_ORDER = [
    "Raíz / shell",
    "Componentes (editores por sistema)",
    "Plantillas Markup (js/components/templates)",
    "Composables / lógica común (js/lib)",
    "Design System (js/ui)",
    "Otros",
]

def main():
    files = sorted(f for f in JS_DIR.rglob("*.js") if "vendor" not in f.parts)
    parsed = [(f.relative_to(EDITOR).as_posix(), parse_js(f)) for f in files]

    tabs = parse_tabs()
    css_sections = parse_css_sections()
    total_lines = sum(i["n_lines"] for _, i in parsed)

    groups = OrderedDict((a, []) for a in AREA_ORDER)
    for rel, info in parsed:
        groups[area_for(rel)].append((rel, info))

    out = []
    out.append("# CODEMAP del EDITOR — Mapa de código (autogenerado)")
    out.append("")
    out.append("> ⚙️ **Fichero AUTOGENERADO por `tools/gen_editor_codemap.py`. NO editar a mano.**")
    out.append("> Regénералo tras cambios estructurales:  `python tools/gen_editor_codemap.py`")
    out.append(">")
    out.append("> Índice de ALTA SEÑAL para tocar el editor (`editor/`) sin abrir ficheros enteros.")
    out.append("> Verifica tus cambios con:  `node tools/check_editor.mjs`")
    out.append("")
    out.append(f"**Totales:** {len(parsed)} ficheros `.js` · {total_lines} líneas.")
    out.append("")
    out.append("Leyenda: `nombre Lnn` = símbolo/función en la línea *nn*. `template: Lnn` = inicio plantilla inline.")
    out.append("")

    out.append("## ¿Qué abro para editar…? (espejo de `docs/INDEX.md`)")
    out.append("")
    out.append("| Pestaña (activeTab) | Etiqueta | Grupo | Componente |")
    out.append("|---------------------|----------|-------|------------|")
    for key, t in tabs.items():
        comp = t["component"] or "—"
        out.append(f"| `{key}` | {t['icon']} {t['label']} | {t['group']} | `{comp}` |")
    out.append("")

    for area in AREA_ORDER:
        items = groups.get(area) or []
        if not items:
            continue
        out.append(f"## {area}")
        out.append("")
        items.sort(key=lambda x: x[0])
        for rel, info in items:
            title = info["component"] or Path(rel).stem
            out.append(f"### `{title}`")
            meta = f"`editor/{rel}` · {info['n_lines']} líneas"
            if info["template_line"]:
                meta += f" · template: L{info['template_line']}"
            elif info["template_file"]:
                meta += f" · plantilla → `{info['template_file']}`"
            out.append(meta)
            if info["summary"]:
                out.append("")
                out.append(info["summary"])
            if info["sections"]:
                secs = ", ".join(f"`{n}` L{ln}" for n, ln in info["sections"])
                out.append("")
                out.append(f"- **secciones:** {secs}")
            if info["exports"]:
                exps = ", ".join(f"`{n}`{'(def)' if k=='default' else ''} L{ln}" for n, ln, k in info["exports"])
                out.append("")
                out.append(f"- **exports:** {exps}")
            if info["funcs"]:
                def emit(fns, per_line=8):
                    items2 = [f"`{n}` L{ln}" for n, ln in fns]
                    first = True
                    for k in range(0, len(items2), per_line):
                        chunk = ", ".join(items2[k:k + per_line])
                        out.append(f"- **funcs:** {chunk}" if first else f"  {chunk}")
                        first = False
                emit(info["funcs"])
            out.append("")

    if css_sections:
        out.append("## Secciones de `styles.css`")
        out.append("")
        out.append(f"`editor/styles.css` · {len(read_lines(CSS_PATH))} líneas. Secciones:")
        out.append("")
        for title, line in css_sections:
            out.append(f"- **{title}** · L{line}")
        out.append("")

    OUT_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"OK · {OUT_PATH.relative_to(ROOT)} ({len(out)} líneas) · {len(parsed)} JS · {len(tabs)} pestañas · {len(css_sections)} secciones CSS")

if __name__ == "__main__":
    main()