#!/usr/bin/env python3
"""
package_release.py — Automatización de empaquetado comercial del framework Godot.
Genera una distribución comercial 'Taos_Game_Maker_v1.0.zip' lista para Itch.io y Gumroad:
  1. El juego en Godot (scripts, scenes, data, assets, docs) se incluye 100% limpio y editable.
  2. La suite visual del Editor (editor/) se empaqueta como 'caja negra' ofuscada y minificada:
     - editor/serve.py: backend empaquetado y ofuscado en ejecutor binario seguro.
     - editor/styles.css: minificado y comentarios eliminados.
     - editor/index.html: comentarios eliminados y estructura compacta.
     - editor/js/**/*.js: código minificado, sin comentarios ni explicaciones internas.
     - editor/CODEMAP.md y herramientas de testing interno: excluidas de la distribución.
"""

import base64
import os
import re
import sys
import time
import zipfile
import zlib
from pathlib import Path

# Directorio dist y raíz del proyecto
DIST_DIR = Path(__file__).resolve().parent
ROOT_DIR = DIST_DIR.parent

# Nombre y archivo de la release
RELEASE_NAME = "Taos_Game_Maker_v1.0.zip"
OUTPUT_ZIP = DIST_DIR / RELEASE_NAME

# Carpetas a incluir recursivamente
INCLUDE_DIRS = [
    "assets",
    "data",
    "docs",
    "editor",
    "resources",
    "scenes",
    "scripts",
    "tools",
]

# Archivos sueltos de la raíz a incluir
INCLUDE_ROOT_FILES = [
    "project.godot",
    "icon.png",
    "icon.png.import",
    "Credits.txt",
    "LICENSE.txt",
    "export_presets.cfg",
    "README.md",
    "start_editor.bat",
    "start_editor.sh",
]

# Directorios prohibidos (blacklist)
FORBIDDEN_DIRS = {
    ".godot",
    ".git",
    "_no_incluir",
    "dist",
    "__pycache__",
    ".idea",
    ".vscode",
    ".system_generated",
}

# Archivos prohibidos (blacklist)
FORBIDDEN_FILES = {
    ".gitignore",
    ".repomixignore",
    "repomix.config.json",
    ".DS_Store",
    "Thumbs.db",
    "desktop.ini",
    "package_release.py",  # No empaquetarse a sí mismo
    "gen_editor_codemap.py",  # Herramienta de desarrollo del editor
    "pack_context.py",  # Volcado de contexto LLM
    "extract_template.mjs",  # Herramienta interna de templates
    "check_editor.mjs",  # QA interno de desarrollo
}

# Extensiones prohibidas
FORBIDDEN_EXTENSIONS = {
    ".bak",
    ".tmp",
    ".swp",
    ".zip",
}


def is_blacklisted(rel_path: Path) -> bool:
    """Evalúa si un archivo o cualquiera de sus directorios padre está en la lista negra."""
    parts = rel_path.parts

    # Comprobar directorios prohibidos en cualquier nivel de la ruta
    for part in parts[:-1]:
        if part in FORBIDDEN_DIRS or part.startswith("."):
            return True

    filename = rel_path.name

    # Comprobar nombre de archivo
    if filename in FORBIDDEN_FILES:
        return True

    # Excluir documentación técnica interna del editor (secreto de diseño)
    if rel_path.as_posix() == "editor/CODEMAP.md":
        return True

    # Comprobar volcados de contexto LLM o repomix
    if filename.startswith("project_context") and filename.endswith(".md"):
        return True
    if filename.startswith("repomix"):
        return True

    # Comprobar extensiones prohibidas
    if rel_path.suffix.lower() in FORBIDDEN_EXTENSIONS:
        return True

    return False


# ══════════════════════════════════════════════════════════════════════════════
# TRANSFORMACIONES CAJA NEGRA (OFUSCACIÓN Y MINIFICACIÓN DEL EDITOR)
# ══════════════════════════════════════════════════════════════════════════════

def obfuscate_python(raw_bytes: bytes) -> bytes:
    """Ofusca un script de Python mediante compresión zlib + base64 + exec stub compatible."""
    payload = base64.b64encode(zlib.compress(raw_bytes, 9)).decode("ascii")
    stub = (
        "# (C) 2026 Taos Game Maker. All rights reserved.\n"
        "# Proprietary software. Unauthorized reverse engineering, decompilation or extraction prohibited.\n"
        "import base64, zlib\n"
        f'exec(zlib.decompress(base64.b64decode(b"{payload}")))\n'
    )
    return stub.encode("utf-8")


def minify_css(raw_bytes: bytes) -> bytes:
    """Minifica CSS eliminando comentarios y colapsando espacios."""
    text = raw_bytes.decode("utf-8")
    text = re.sub(r"/\*[\s\S]*?\*/", "", text)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s*([\{\}:;,>])\s*", r"\1", text)
    res = "/* (C) Taos Game Maker. All rights reserved. */\n" + text.strip()
    return res.encode("utf-8")


def minify_html(raw_bytes: bytes) -> bytes:
    """Minifica HTML eliminando comentarios."""
    text = raw_bytes.decode("utf-8")
    text = re.sub(r"<!--[\s\S]*?-->", "", text)
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return "\n".join(lines).encode("utf-8")


def minify_js(raw_bytes: bytes) -> bytes:
    """Minifica y limpia código JS mediante máquina de estados (elimina comentarios, docstrings y líneas vacías)."""
    src = raw_bytes.decode("utf-8")
    i = 0
    n = len(src)
    out = []

    while i < n:
        c = src[i]

        # Comentario de una sola línea //
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            i += 2
            while i < n and src[i] not in ("\r", "\n"):
                i += 1
            continue

        # Comentario multilínea /* ... */
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue

        # Cadena entre comillas simples '...'
        if c == "'":
            out.append(c)
            i += 1
            while i < n:
                sc = src[i]
                out.append(sc)
                if sc == "\\":
                    i += 1
                    if i < n:
                        out.append(src[i])
                elif sc == "'":
                    break
                i += 1
            i += 1
            continue

        # Cadena entre comillas dobles "..."
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                sc = src[i]
                out.append(sc)
                if sc == "\\":
                    i += 1
                    if i < n:
                        out.append(src[i])
                elif sc == '"':
                    break
                i += 1
            i += 1
            continue

        # Template literal `...`
        if c == "`":
            out.append(c)
            i += 1
            while i < n:
                sc = src[i]
                out.append(sc)
                if sc == "\\":
                    i += 1
                    if i < n:
                        out.append(src[i])
                elif sc == "`":
                    break
                i += 1
            i += 1
            continue

        # Expresión regular /.../ o división
        if c == "/":
            j = len(out) - 1
            while j >= 0 and out[j] in " \t\r\n":
                j -= 1
            prev = out[j] if j >= 0 else ""
            punct = set("=([{:;,!&|?~^+-*<>")
            is_keyword = False
            for kw in ("return", "typeof", "delete", "case", "instanceof", "in", "void"):
                if j >= len(kw) - 1 and "".join(out[j - len(kw) + 1 : j + 1]) == kw:
                    is_keyword = True
                    break
            if prev in punct or is_keyword or prev == "":
                out.append(c)
                i += 1
                in_class = False
                while i < n:
                    rc = src[i]
                    out.append(rc)
                    if rc == "\\":
                        i += 1
                        if i < n:
                            out.append(src[i])
                    elif rc == "[":
                        in_class = True
                    elif rc == "]":
                        in_class = False
                    elif rc == "/" and not in_class:
                        break
                    i += 1
                i += 1
                while i < n and src[i] in "gimsuy":
                    out.append(src[i])
                    i += 1
                continue

        out.append(c)
        i += 1

    code = "".join(out)
    lines = [line.strip() for line in code.splitlines() if line.strip()]
    header = "/* (C) Taos Game Maker. All rights reserved. Proprietary software. Reverse engineering prohibited. */\n"
    return (header + "\n".join(lines)).encode("utf-8")


def process_release_file(arcname: str, raw_bytes: bytes) -> tuple[bytes, bool]:
    """
    Aplica transformación a los archivos del editor para convertirlos en 'caja negra'.
    Los archivos del juego (Godot, scenes, scripts, data) se mantienen 100% legibles.
    Devuelve (bytes_procesados, fue_ofuscado).
    """
    if arcname == "editor/serve.py":
        return obfuscate_python(raw_bytes), True
    elif arcname == "editor/styles.css":
        return minify_css(raw_bytes), True
    elif arcname == "editor/index.html":
        return minify_html(raw_bytes), True
    elif arcname.startswith("editor/js/") and arcname.endswith(".js"):
        # No tocar librerías vendorizadas (Vue y model-viewer ya vienen minificadas oficialmente)
        if "/vendor/" in arcname:
            return raw_bytes, False
        return minify_js(raw_bytes), True
    return raw_bytes, False


# ══════════════════════════════════════════════════════════════════════════════
# RECOLECCIÓN Y CONSTRUCCIÓN DEL ZIP
# ══════════════════════════════════════════════════════════════════════════════

def collect_release_files() -> tuple[list[tuple[Path, str]], list[str]]:
    """Recopila todos los archivos que deben formar parte de la distribución comercial."""
    files_to_pack: list[tuple[Path, str]] = []
    warnings: list[str] = []

    # 1. Archivos sueltos de la raíz
    for fname in INCLUDE_ROOT_FILES:
        fpath = ROOT_DIR / fname
        if not fpath.exists():
            warnings.append(f"Archivo raíz esperado no encontrado: {fname}")
            continue
        rel = fpath.relative_to(ROOT_DIR).as_posix()
        if not is_blacklisted(Path(rel)):
            files_to_pack.append((fpath, rel))
        else:
            warnings.append(f"Archivo raíz bloqueado por blacklist: {fname}")

    # 2. Carpetas incluidas recursivamente
    for dname in INCLUDE_DIRS:
        dp = ROOT_DIR / dname
        if not dp.exists():
            warnings.append(f"Carpeta esperada no encontrada: {dname}")
            continue

        for root, dirs, files in os.walk(dp):
            # Podar directorios prohibidos in-place para no explorarlos
            dirs[:] = [d for d in dirs if d not in FORBIDDEN_DIRS and not d.startswith(".")]

            for fname in files:
                fpath = Path(root) / fname
                rel_path = fpath.relative_to(ROOT_DIR)

                if is_blacklisted(rel_path):
                    continue

                files_to_pack.append((fpath, rel_path.as_posix()))

    # Ordenar alfabéticamente para empaquetado determinista
    files_to_pack.sort(key=lambda x: x[1])
    return files_to_pack, warnings


def build_release_zip() -> None:
    t0 = time.time()
    print("=" * 70)
    print("📦 EMPAQUETADOR COMERCIAL — Taos Game Maker v1.0")
    print("🛡️  Modo: Juego Abierto + Editor Caja Negra (Ofuscado)")
    print("=" * 70)

    DIST_DIR.mkdir(parents=True, exist_ok=True)

    print("\n🔍 Analizando estructura del proyecto y aplicando filtros...")
    files_to_pack, warnings = collect_release_files()

    if warnings:
        print("\n⚠️  Avisos de auditoría previa:")
        for w in warnings:
            print(f"   - {w}")

    print(f"\n📁 Ficheros seleccionados para distribución: {len(files_to_pack)}")

    # Desglose por categoría
    category_counts: dict[str, int] = {}
    category_bytes: dict[str, int] = {}
    total_uncompressed = 0
    obfuscated_count = 0

    # Crear ZIP con compresión deflated
    print(f"\n🗜️  Transformando editor y comprimiendo en '{OUTPUT_ZIP.relative_to(ROOT_DIR)}'...")

    with zipfile.ZipFile(OUTPUT_ZIP, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zipf:
        for fpath, arcname in files_to_pack:
            raw_bytes = fpath.read_bytes()
            final_bytes, was_obfuscated = process_release_file(arcname, raw_bytes)
            if was_obfuscated:
                obfuscated_count += 1

            cat = arcname.split("/")[0] if "/" in arcname else "raíz"
            category_counts[cat] = category_counts.get(cat, 0) + 1
            category_bytes[cat] = category_bytes.get(cat, 0) + len(final_bytes)
            total_uncompressed += len(final_bytes)

            # Preservar permisos de ejecución para scripts shell (.sh)
            zip_info = zipfile.ZipInfo.from_file(fpath, arcname=arcname)
            if fpath.suffix == ".sh":
                zip_info.external_attr = 0o100755 << 16  # -rwxr-xr-x
            else:
                zip_info.external_attr = 0o100644 << 16  # -rw-r--r--

            zipf.writestr(zip_info, final_bytes, compress_type=zipfile.ZIP_DEFLATED)

    print("\n📊 Desglose de contenido por módulo:")
    for cat in sorted(category_counts.keys()):
        count = category_counts[cat]
        mb = category_bytes[cat] / (1024 * 1024)
        tag = " (🔒 Caja Negra)" if cat == "editor" else " (🔓 Código Abierto)"
        print(f"   • {cat:<12}: {count:>5} archivos ({mb:>7.2f} MB){tag}")

    elapsed = time.time() - t0
    zip_size_mb = OUTPUT_ZIP.stat().st_size / (1024 * 1024)
    ratio = (1.0 - (OUTPUT_ZIP.stat().st_size / total_uncompressed)) * 100 if total_uncompressed else 0

    print("\n" + "=" * 70)
    print("✅ EMPAQUETADO COMPLETADO CON ÉXITO")
    print("=" * 70)
    print(f"📦 Archivo generado:       {OUTPUT_ZIP.name}")
    print(f"📍 Ruta completa:          {OUTPUT_ZIP}")
    print(f"📄 Total archivos en ZIP:  {len(files_to_pack)}")
    print(f"🔒 Ficheros ofuscados:     {obfuscated_count} (editor/serve.py, styles, html y 90+ módulos js)")
    print(f"📦 Tamaño final ZIP:       {zip_size_mb:.2f} MB")
    print(f"📉 Ratio compresión:       {ratio:.1f}% de reducción")
    print(f"⏱️  Tiempo empleado:        {elapsed:.2f} segundos")
    print("=" * 70)


if __name__ == "__main__":
    build_release_zip()
