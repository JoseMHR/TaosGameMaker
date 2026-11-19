#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/process_image.py  ·  Procesador de assets gráficos para 'Leyendas del Yelmo'
----------------------------------------------------------------------------
1. Convierte imágenes (JPEGs disfrazados de PNG) a PNG real de 32 bits (RGBA).
2. Elimina fondos de sprites/NPCs/enemigos mediante Flood-Fill por distancia de color.
3. Aplica suavizado de bordes (anti-halo) y redimensionado opcional.

Uso:
  python tools/process_image.py input.png output.png --type sprite
  python tools/process_image.py input.png output.png --resize 512x512
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from collections import deque, Counter
from pathlib import Path
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from PIL.Image import Image as PILImage

def _configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            if stream.encoding != "utf-8":
                stream.reconfigure(encoding="utf-8")
        except (AttributeError, OSError):
            pass

def _import_pil():
    try:
        from PIL import Image
        return Image
    except ImportError as exc:
        print("ERROR: Pillow no está instalado. Instálalo con: pip install Pillow", file=sys.stderr)
        raise SystemExit(1) from exc

def _lanczos(Image_module: Any):
    try:
        return Image_module.Resampling.LANCZOS
    except AttributeError:
        return Image_module.LANCZOS

def _is_background_path(path: Path) -> bool:
    parts = re.split(r"[/\\_.\-]+", path.as_posix())
    return any(p.lower() in ("bg", "background", "backgrounds") for p in parts)

def _parse_resize(value: str) -> tuple[int, int]:
    value = value.strip().lower()
    if "x" in value:
        w, _, h = value.partition("x")
        return int(w), int(h)
    n = int(value)
    return n, n

def _color_distance(c1: tuple[int, int, int], c2: tuple[int, int, int]) -> float:
    """Calcula la distancia euclídea entre dos colores RGB."""
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))

def _detect_bg_color(pixels: Any, width: int, height: int) -> tuple[int, int, int]:
    """Obtiene el color de fondo más probable analizando las esquinas y bordes."""
    sample_points = [
        (0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1),
        (width // 2, 0), (width // 2, height - 1), (0, height // 2), (width - 1, height // 2)
    ]
    colors = [pixels[x, y][:3] for x, y in sample_points]
    
    rounded_colors = [tuple((c // 10) * 10 for c in col) for col in colors]
    most_common_rounded = Counter(rounded_colors).most_common(1)[0][0]
    
    matching_colors = [col for col in colors if tuple((c // 10) * 10 for c in col) == most_common_rounded]
    avg_r = int(sum(c[0] for c in matching_colors) / len(matching_colors))
    avg_g = int(sum(c[1] for c in matching_colors) / len(matching_colors))
    avg_b = int(sum(c[2] for c in matching_colors) / len(matching_colors))
    return (avg_r, avg_g, avg_b)

def _remove_background(img: Any, tolerance: float = 35.0) -> Any:
    """Elimina el fondo por flood-fill adaptativo y suaviza los bordes."""
    img = img.convert("RGBA")
    width, height = img.size
    pixels = img.load()

    bg_color = _detect_bg_color(pixels, width, height)
    visited = [bytearray(height) for _ in range(width)]
    q: deque[tuple[int, int]] = deque()

    for x in range(width):
        for y in (0, height - 1):
            if _color_distance(pixels[x, y][:3], bg_color) <= tolerance and not visited[x][y]:
                q.append((x, y))
                visited[x][y] = 1

    for y in range(height):
        for x in (0, width - 1):
            if _color_distance(pixels[x, y][:3], bg_color) <= tolerance and not visited[x][y]:
                q.append((x, y))
                visited[x][y] = 1

    while q:
        cx, cy = q.popleft()
        r, g, b, _ = pixels[cx, cy]
        pixels[cx, cy] = (r, g, b, 0)

        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height and not visited[nx][ny]:
                if _color_distance(pixels[nx, ny][:3], bg_color) <= tolerance:
                    visited[nx][ny] = 1
                    q.append((nx, ny))

    for x in range(1, width - 1):
        for y in range(1, height - 1):
            if pixels[x, y][3] > 0:
                dist = _color_distance(pixels[x, y][:3], bg_color)
                if dist <= tolerance * 1.3:
                    has_transparent_neighbor = any(
                        pixels[x + dx, y + dy][3] == 0 for dx, dy in ((1,0), (-1,0), (0,1), (0,-1))
                    )
                    if has_transparent_neighbor:
                        alpha_factor = max(0.0, min(1.0, (dist - tolerance * 0.5) / (tolerance * 0.8)))
                        r, g, b, _ = pixels[x, y]
                        pixels[x, y] = (r, g, b, int(255 * alpha_factor))

    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    return img

def process_image(
    input_path: Path,
    output_path: Path,
    *,
    image_type: str = "auto",
    remove_bg: bool | None = None,
    threshold: int = 35,
    resize: tuple[int, int] | None = None,
) -> Path:
    Image_module = _import_pil()

    try:
        with Image_module.open(input_path) as loaded_img:
            img = loaded_img.copy()
    except Exception as exc:
        print(f"ERROR: no se pudo abrir '{input_path}': {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    if image_type == "background":
        should_remove_bg = False
    elif image_type == "sprite":
        should_remove_bg = True
    else:
        should_remove_bg = not (_is_background_path(input_path) or _is_background_path(output_path))

    if remove_bg is not None:
        should_remove_bg = remove_bg

    if should_remove_bg:
        img = _remove_background(img, tolerance=float(threshold))
    else:
        if img.mode in ("RGBA", "LA", "P"):
            img = img.convert("RGB")

    if resize is not None:
        img = img.resize(resize, _lanczos(Image_module))

    if output_path.is_dir():
        output_path = output_path / (input_path.stem + ".png")
    else:
        output_path = output_path.with_suffix(".png")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        img.save(output_path, "PNG")
    except Exception as exc:
        print(f"ERROR: no se pudo guardar '{output_path}': {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    print(f"OK -> {output_path} ({img.size[0]}x{img.size[1]})")
    return output_path

def main() -> int:
    _configure_stdio()

    parser = argparse.ArgumentParser(
        description="Procesa assets gráficos: convierte a PNG real, borra fondos de sprites y redimensiona."
    )
    parser.add_argument("input", type=Path, help="Imagen de entrada")
    parser.add_argument("output", type=Path, help="Ruta o carpeta de salida PNG")
    parser.add_argument("--resize", type=_parse_resize, metavar="SIZE", help='Ej: "512" o "1024x1024"')
    parser.add_argument("--threshold", type=int, default=35, help="Tolerancia de color de fondo (10-80). Default: 35")
    parser.add_argument("--type", choices=["auto", "sprite", "background"], default="auto", help="auto, sprite o background")
    
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--remove-bg", action="store_true", dest="remove_bg", default=None, help="Fuerza borrar fondo")
    group.add_argument("--no-remove-bg", action="store_false", dest="remove_bg", default=None, help="Fuerza NO borrar fondo")

    args = parser.parse_args()

    if not args.input.is_file():
        print(f"ERROR: no existe el fichero de entrada: {args.input}", file=sys.stderr)
        return 1

    process_image(
        args.input,
        args.output,
        image_type=args.type,
        remove_bg=args.remove_bg,
        threshold=args.threshold,
        resize=args.resize,
    )
    return 0

if __name__ == "__main__":
    sys.exit(main())