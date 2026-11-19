#!/usr/bin/env python3
"""
pack_context.py — Generador de contexto único del proyecto para LLMs (Gemini, Claude, GPT).
Agrupa el proyecto (código fuente, escenas y documentación) en un único fichero Markdown
en la raíz del proyecto, filtrando automáticamente binarios, caché y datos pesados.

Uso:
    python3 tools/pack_context.py              # Por defecto: Código GDScript, escenas .tscn, editor web y docs (~1.5M tokens)
    python3 tools/pack_context.py --with-data  # Añade datos clave de data/ (items, skills, quests, etc.) (~1.9M tokens)
    python3 tools/pack_context.py --full-data  # Añade todo data/ incluyendo mazmorras y diálogos (~3.2M tokens)
    python3 tools/pack_context.py --code-only  # Solo scripts .gd, editor y docs (sin escenas ni data)
    python3 tools/pack_context.py -o salida.md # Cambiar nombre del fichero de salida
"""

import os
import sys
import argparse
from pathlib import Path

# Directorio raíz del proyecto
ROOT_DIR = Path(__file__).resolve().parent.parent

# Extensiones de texto a lenguaje de resaltado
LANG_MAP = {
    ".gd": "gdscript",
    ".js": "javascript",
    ".mjs": "javascript",
    ".py": "python",
    ".md": "markdown",
    ".html": "html",
    ".css": "css",
    ".json": "json",
    ".godot": "ini",
    ".tscn": "ini",
    ".tres": "ini",
}

# Carpetas o patrones siempre ignorados
DEFAULT_IGNORES = {
    ".godot",
    ".git",
    ".import",
    "assets",
    "node_modules",
    "__pycache__",
    ".system_generated",
    "dist",
    "build",
}

DEFAULT_FILE_IGNORES = {
    "project_context.md",
    "project_context.txt",
    "repomix-output.md",
    "repomix-output.txt",
    ".DS_Store",
}


def should_ignore_dir(path: Path) -> bool:
    rel = path.relative_to(ROOT_DIR)
    parts = rel.parts
    for p in parts:
        if p in DEFAULT_IGNORES or p.startswith("."):
            return True
    return False


def collect_files(include_scenes: bool = True, include_data: bool = False, full_data: bool = False) -> list[Path]:
    collected: list[Path] = []

    # 1. Configuración principal de Godot
    project_godot = ROOT_DIR / "project.godot"
    if project_godot.exists():
        collected.append(project_godot)

    # 2. Documentación
    docs_dir = ROOT_DIR / "docs"
    if docs_dir.exists():
        for p in sorted(docs_dir.rglob("*.md")):
            collected.append(p)

    # 3. Scripts del motor (GDScript) y escenas (.tscn)
    for folder in ["scripts", "scenes"]:
        f_path = ROOT_DIR / folder
        if f_path.exists():
            for p in sorted(f_path.rglob("*.gd")):
                collected.append(p)
            if include_scenes:
                for p in sorted(f_path.rglob("*.tscn")):
                    collected.append(p)

    # 4. Editor web y herramientas auxiliares
    editor_dir = ROOT_DIR / "editor"
    if editor_dir.exists():
        for ext in ["*.js", "*.py", "*.html", "*.css"]:
            for p in sorted(editor_dir.rglob(ext)):
                collected.append(p)

    tools_dir = ROOT_DIR / "tools"
    if tools_dir.exists():
        for ext in ["*.py", "*.mjs", "*.js"]:
            for p in sorted(tools_dir.rglob(ext)):
                if p.name != "pack_context.py":
                    collected.append(p)

    # 5. Datos JSON del juego (opcional con --with-data o --full-data)
    if include_data:
        data_dir = ROOT_DIR / "data"
        if data_dir.exists():
            for p in sorted(data_dir.rglob("*.json")):
                if not full_data:
                    # En modo datos clave se omiten mazmorras cuadrícula tile-a-tile (2.8MB) y diálogos crudos (2.7MB)
                    rel_parts = p.relative_to(data_dir).parts
                    if rel_parts and rel_parts[0] in ("dungeons", "npcs"):
                        continue
                collected.append(p)

    # Eliminar duplicados manteniendo orden
    seen = set()
    result = []
    for p in collected:
        if p not in seen and p.name not in DEFAULT_FILE_IGNORES and p.suffix not in (".bak", ".tmp"):
            seen.add(p)
            result.append(p)

    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Empaqueta el contexto del proyecto para LLMs")
    parser.add_argument("-o", "--output", default="project_context.md", help="Fichero de salida (default: project_context.md en la raíz)")
    parser.add_argument("--with-data", action="store_true", help="Incluye datos clave de data/ (habilidades, misiones, objetos, tiendas, etc.)")
    parser.add_argument("--full-data", action="store_true", help="Incluye TODO data/, incluso mazmorras y diálogos masivos (~3.2M tokens)")
    parser.add_argument("--no-scenes", action="store_true", help="Excluye los ficheros de escena (.tscn)")
    parser.add_argument("--code-only", action="store_true", help="Excluye tanto escenas como data/ (solo código y docs)")
    args = parser.parse_args()

    include_scenes = not (args.no_scenes or args.code_only)
    include_data = (args.with_data or args.full_data) and not args.code_only
    full_data = args.full_data

    out_path = ROOT_DIR / args.output
    print(f"📦 Recopilando ficheros del proyecto...")

    files = collect_files(include_scenes=include_scenes, include_data=include_data, full_data=full_data)

    total_chars = 0
    categories: dict[str, int] = {}

    with open(out_path, "w", encoding="utf-8") as out:
        out.write(f"# Contexto del Proyecto: {ROOT_DIR.name}\n\n")
        out.write("> Fichero generado automáticamente para modelos de lenguaje (LLM).\n")
        out.write(f"> Total de ficheros empaquetados: {len(files)}\n\n")

        out.write("## Índice de Archivos\n\n")
        for p in files:
            rel = p.relative_to(ROOT_DIR).as_posix()
            out.write(f"- `{rel}`\n")
            cat = rel.split("/")[0] if "/" in rel else "root"
            categories[cat] = categories.get(cat, 0) + 1
        out.write("\n---\n\n")

        for p in files:
            rel = p.relative_to(ROOT_DIR).as_posix()
            ext = p.suffix.lower()
            lang = LANG_MAP.get(ext, "")

            try:
                content = p.read_text(encoding="utf-8", errors="replace")
            except Exception as e:
                content = f"// Error leyendo archivo: {e}"

            total_chars += len(content)

            out.write(f"## File: `{rel}`\n\n")
            out.write(f"```{lang}\n")
            out.write(content)
            if not content.endswith("\n"):
                out.write("\n")
            out.write("```\n\n")

    size_mb = out_path.stat().st_size / (1024 * 1024)
    est_tokens = total_chars // 4

    print(f"\n✅ Generado con éxito: {out_path.name} (en la raíz del proyecto)")
    print(f"   - Ficheros incluidos: {len(files)}")
    for cat, count in sorted(categories.items()):
        print(f"     • {cat}/: {count} ficheros")
    print(f"   - Tamaño total: {size_mb:.2f} MB")
    print(f"   - Tokens estimados: ~{est_tokens:,} tokens")

    if est_tokens <= 1_000_000:
        print(f"   🟢 Estado LLM: Cabe holgadamente en Gemini 1.5 Pro / Flash y Claude 3.5 (con ventana grande).")
    elif est_tokens <= 2_000_000:
        print(f"   🟡 Estado LLM: Cabe en Gemini 1.5 Pro (límite 2M tokens en Google AI Studio/API y Gemini Advanced).")
    else:
        print(f"   ⚠️  Aviso LLM: Excede los 2M tokens de Gemini 1.5 Pro por ~{(est_tokens - 2_000_000):,} tokens.")
        print(f"      👉 Recomendación: Usa la exportación por defecto sin data/ (~1.5M tokens) para asegurar que entre.")


if __name__ == "__main__":
    main()
