#!/usr/bin/env python3
# ============================================================================
# Taos Game Maker · Editor de diseño — servidor de desarrollo
# ----------------------------------------------------------------------------
# Sirve la SPA del editor y expone un pequeño API HTTP para leer/escribir los
# JSON de diseño y servir los assets, SIN depender de la File System Access API
# del navegador (que a menudo está bloqueada por política corporativa).
#
# La raíz del proyecto se AUTODETECTA a partir de la ubicación de este archivo
# (editor/serve.py -> raíz = ../), así que no hay que indicar carpetas.
#
# Uso:
#   python serve.py                (desde editor)
#   python editor/serve.py         (desde la raíz del proyecto)
#   python serve.py --port 8123    (puerto alternativo)
#
# Luego abre:  http://localhost:8000/
# ============================================================================

import argparse
import json
import mimetypes
import os
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote

# ─── Rutas autodetectadas ────────────────────────────────────────────────────
EDITOR_DIR = Path(__file__).resolve().parent          # editor
ROOT = EDITOR_DIR.parent                              # raíz del proyecto
DATA_DIR = ROOT / "data"
ASSETS = ROOT / "assets"
ASSET_DIRS = {
    "bg": ASSETS / "vn" / "bg",
    "npc": ASSETS / "vn" / "npcs",
    "avatar": ASSETS / "vn" / "npcs",
    "enemy": ASSETS / "combat" / "enemies",
    "combat_bg": ASSETS / "combat" / "bg",
    "item": ASSETS / "common" / "items",
    "skill": ASSETS / "combat" / "skills",
    "terrain": ASSETS / "world" / "map",
    "music": ASSETS / "common" / "music",
    "sfx": ASSETS / "common" / "sfx",
    "buildings": ASSETS / "common" / "models" / "buildings",
    "world_model": ASSETS / "common" / "models",
    "dungeon_model": ASSETS / "common" / "models",
    "combat_model": ASSETS / "common" / "models",
    "common_model": ASSETS / "common" / "models",
    "model": ASSETS / "common" / "models",
    "dungeon_tex": ASSETS / "dungeon" / "textures",
}

# Task 6 · E1: ficheros de datos CRÍTICOS que reciben copia .bak antes de
# sobrescribir (los más caros de perder si una escritura queda a medias).
_CRITICAL_DATA_FILES = {"world.json", "world_test.json", "dialogues.json", "quests.json", "events.json"}

# Task 6 · E2: tope de tamaño de cuerpo para PUT/POST (atajo anti-OOM ante un
# Content-Length erróneo o malicioso). 64 MB es holgado para JSON, modelos y audio.
MAX_BODY_BYTES = 64 * 1024 * 1024


def _atomic_write_text(target: Path, text: str, backup: bool = False) -> None:
    """Escribe `text` en `target` de forma ATÓMICA: primero a un fichero temporal
    en la MISMA carpeta (fsync) y luego os.replace() (rename atómico). Si `backup`
    y el destino ya existe, guarda antes una copia `<fichero>.bak`. Así una
    interrupción a mitad de escritura nunca deja el JSON truncado/corrupto."""
    target.parent.mkdir(parents=True, exist_ok=True)
    if backup and target.exists():
        try:
            shutil.copy2(target, target.parent / (target.name + ".bak"))
        except Exception:
            pass  # respaldo best-effort: nunca debe impedir el guardado
    fd, tmp_name = tempfile.mkstemp(dir=str(target.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_name, target)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


# "kind"s de ASSET_DIRS que listan escenas .tscn (Godot) en vez de imágenes.
SCENE_ASSET_KINDS = {"buildings"}
# "kind"s que gestionan modelos 3D (.glb / .obj) subibles desde el editor.
MODEL_ASSET_KINDS = {"model", "world_model", "dungeon_model", "combat_model", "common_model"}

# Ficheros protegidos: los precarga TabWorld3D.gd con `load()` a nivel de variable
# (fuera de world_terrains.json), así que BORRARLOS rompería el arranque del juego
# aunque ningún terreno los referencie por su clave preestablecida. El editor los
# lista pero nunca deja borrarlos (ver _asset_delete).
PROTECTED_ASSETS = {
    "terrain": {"tile_sea.png", "tile_pradera.png", "tile_sand.png", "tile_mountain.png", "tile_snow.png", "tile_yelmo.png", "tile_ice.png", "tile_lava.png", "tile_ground.png", "tile_beach.png", "tile_contaminacion.png"},
}

# Solo estos ficheros de data son leíbles/escribibles (evita path traversal).
# NOTA: npcs.json / enemies.json YA NO viven aquí: se migraron a
# colecciones "un fichero por id" en ALLOWED_COLLECTIONS.
ALLOWED_DATA = {"world.json", "world_test.json", "professions.json", "skills.json", "enemy_skills.json", "synergies.json", "dungeon_kits.json", "events.json", "quests.json", "world_transforms.json", "shops.json", "ambience.json", "dialogues.json", "achievements.json", "tutorials.json", "config.json", "world_buildings_classic.json"}

# ─── COLECCIONES "un fichero por id" (carpeta data/<nombre>/<id>.json) ────────
# Alternativa a ALLOWED_DATA para catálogos que crecerían sin límite en un solo
# JSON (p. ej. mazmorras: cada una con N plantas de rejilla) o que conviene
# tener SIEMPRE localizables/editables como fichero aislado por elemento (p. ej.
# entidades del mapamundi o casillas de mazmorra). Cada colección vive en su
# propia carpeta y se expone vía /api/collection/<name>[/<id>]. Añadir aquí para
# dar el mismo tratamiento a otro catálogo en el futuro.
ALLOWED_COLLECTIONS = {
    "dungeons": DATA_DIR / "dungeons",
    "ids": DATA_DIR / "ids",
    "dungeon_tiles": DATA_DIR / "dungeon_tiles",
    "world_terrains": DATA_DIR / "world_terrains",
    "world_resources": DATA_DIR / "world_resources",
    "world_buildings": DATA_DIR / "world_buildings",
    "npcs": DATA_DIR / "npcs",
    "enemies": DATA_DIR / "enemies",
    # items / scenes / cinematics: colecciones "un fichero por id".
    "items": DATA_DIR / "items",
    "scenes": DATA_DIR / "scenes",
    "cinematics": DATA_DIR / "cinematics",
}

IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".gif")

# Un id de colección es un nombre de fichero seguro: letras/dígitos/_/- (mismo
# alfabeto que usan los event_id del resto del proyecto). Bloquea traversal.
_COLLECTION_ID_RE = re.compile(r"^[A-Za-z0-9_\-]+$")

# Nombre de fichero de asset SUBIDO desde el editor: mismo alfabeto que un id de
# colección, siempre en PNG (requisito del picker de texturas de terreno).
_ASSET_UPLOAD_RE = re.compile(r"^[A-Za-z0-9_\-]+\.png$")
_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
# Modelos 3D subidos: nombre seguro + extensión .glb u .obj.
_MODEL_UPLOAD_RE = re.compile(r"^[A-Za-z0-9_\-]+\.(glb|obj)$", re.IGNORECASE)
_GLB_MAGIC = b"glTF"
# Audio subido desde la Biblioteca de Medios (Task 5, Fase 3): .ogg/.mp3/.wav.
AUDIO_ASSET_KINDS = {"music", "sfx"}
_AUDIO_UPLOAD_RE = re.compile(r"^[A-Za-z0-9_\-]+\.(ogg|mp3|wav)$", re.IGNORECASE)
_OGG_MAGIC = b"OggS"
_WAV_MAGIC = b"RIFF"


class Handler(BaseHTTPRequestHandler):
    server_version = "TaosGameMaker/1.0"

    # ── Utilidades de respuesta ──────────────────────────────────────────────
    def _send(self, code, body=b"", ctype="application/octet-stream", extra=None):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False), "application/json; charset=utf-8")

    def _err(self, code, msg):
        self._json(code, {"error": msg})

    # Task 6 · E2: lee el cuerpo respetando el tope de tamaño. Devuelve los bytes,
    # o None (habiendo respondido ya 413) si el Content-Length excede el máximo.
    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length > MAX_BODY_BYTES:
            self._err(413, "Cuerpo demasiado grande (máx %d MB)." % (MAX_BODY_BYTES // (1024 * 1024)))
            return None
        return self.rfile.read(length) if length else b""

    # ── GET ──────────────────────────────────────────────────────────────────
    def do_GET(self):
        path = unquote(self.path.split("?", 1)[0])
        if path.startswith("/api/"):
            return self._api_get(path)
        return self._static(path)

    def do_HEAD(self):
        self.do_GET()

    # ── PUT (guardado) ─────────────────────────────────────────────────────────
    def do_PUT(self):
        path = unquote(self.path.split("?", 1)[0])
        if path.startswith("/api/collection/"):
            return self._collection_put(path[len("/api/collection/"):])
        if not path.startswith("/api/data/"):
            return self._err(404, "Ruta no válida para PUT.")
        name = path[len("/api/data/"):]
        if name not in ALLOWED_DATA:
            return self._err(403, "Fichero no permitido: %s" % name)
        raw = self._read_body()
        if raw is None:
            return
        try:
            obj = json.loads(raw.decode("utf-8"))
        except Exception as e:
            return self._err(400, "JSON inválido: %s" % e)
        try:
            target = DATA_DIR / name
            text = json.dumps(obj, ensure_ascii=False, indent=4)
            _atomic_write_text(target, text, backup=(name in _CRITICAL_DATA_FILES))
        except Exception as e:
            return self._err(500, "No se pudo escribir %s: %s" % (name, e))
        return self._json(200, {"ok": True, "file": name, "bytes": len(text.encode("utf-8"))})

    # ── POST (subir un asset nuevo, p. ej. una textura PNG o un modelo 3D GLB/OBJ) ───────
    def do_POST(self):
        path = unquote(self.path.split("?", 1)[0])
        if path == "/api/godot/run":
            return self._run_godot()
        if path == "/api/process_image":
            return self._process_image()
        if path.startswith("/api/assets/"):
            return self._asset_upload(path[len("/api/assets/"):])
        return self._err(404, "Ruta no válida para POST.")

    def _run_godot(self):
        godot_paths = [
            "godot",
            "/Applications/Godot.app/Contents/MacOS/Godot",
            "/Applications/Godot_mono.app/Contents/MacOS/Godot",
            "C:\\Program Files\\Godot\\Godot.exe",
        ]
        found_bin = None
        for p in godot_paths:
            if shutil.which(p) or Path(p).is_file():
                found_bin = p
                break
        if not found_bin:
            return self._err(404, "No se encontró el ejecutable de Godot en el sistema.")
        try:
            subprocess.Popen([found_bin, "--path", str(ROOT)])
            return self._json(200, {"ok": True, "message": "Godot ejecutado correctamente."})
        except Exception as e:
            return self._err(500, f"Error iniciando Godot: {e}")

    def _asset_upload(self, rest):
        parts = rest.split("/", 1)
        if len(parts) != 2:
            return self._err(400, "Ruta de asset incompleta (falta <kind>/<fichero>).")
        kind, filename = parts[0], parts[1]
        adir = ASSET_DIRS.get(kind)
        if adir is None:
            return self._err(404, "Tipo de asset desconocido: %s" % kind)
        safe = posixpath.normpath(filename).lstrip("/")
        is_model = kind in MODEL_ASSET_KINDS
        is_audio = kind in AUDIO_ASSET_KINDS
        name_re = _MODEL_UPLOAD_RE if is_model else (_AUDIO_UPLOAD_RE if is_audio else _ASSET_UPLOAD_RE)
        if safe.startswith("..") or "/" in safe or not name_re.match(safe):
            ext = ".glb/.obj" if is_model else (".ogg/.mp3/.wav" if is_audio else ".png")
            return self._err(400, "Nombre de fichero no válido: solo letras/números/_/- y extensión %s." % ext)
        raw = self._read_body()
        if raw is None:
            return
        if is_model:
            lower_name = safe.lower()
            if lower_name.endswith(".glb"):
                if not raw.startswith(_GLB_MAGIC):
                    return self._err(400, "El fichero no es un modelo .glb válido (falta la cabecera glTF).")
            elif lower_name.endswith(".obj"):
                if not raw or b"\x00" in raw[:512]:
                    return self._err(400, "El fichero no es un modelo .obj válido (debe ser formato de texto Wavefront).")
            try:
                adir.mkdir(parents=True, exist_ok=True)
                (adir / safe).write_bytes(raw)
            except Exception as e:
                return self._err(500, "No se pudo guardar %s: %s" % (safe, e))
            return self._json(200, {"ok": True, "kind": kind, "file": safe})
        if is_audio:
            lower_name = safe.lower()
            if lower_name.endswith(".ogg") and not raw.startswith(_OGG_MAGIC):
                return self._err(400, "El fichero no es un .ogg válido (falta la cabecera OggS).")
            if lower_name.endswith(".wav") and not raw.startswith(_WAV_MAGIC):
                return self._err(400, "El fichero no es un .wav válido (falta la cabecera RIFF).")
            if not raw:
                return self._err(400, "El fichero de audio está vacío.")
            try:
                adir.mkdir(parents=True, exist_ok=True)
                (adir / safe).write_bytes(raw)
            except Exception as e:
                return self._err(500, "No se pudo guardar %s: %s" % (safe, e))
            return self._json(200, {"ok": True, "kind": kind, "file": safe})
        if not raw.startswith(_PNG_MAGIC):
            return self._err(400, "El contenido no es un PNG válido.")
        try:
            adir.mkdir(parents=True, exist_ok=True)
            (adir / safe).write_bytes(raw)
        except Exception as e:
            return self._err(500, "No se pudo guardar %s: %s" % (safe, e))
        return self._json(200, {"ok": True, "kind": kind, "file": safe})

    # ── Procesado de imágenes (Task 5, Fase 3: MediaLibrary.js) ───────────────
    # Ejecuta tools/process_image.py IN-PLACE sobre un asset YA SUBIDO (mismo
    # fichero de entrada y salida): normaliza a PNG de 32 bits y, si type es
    # "sprite", elimina el fondo. Nunca opera fuera de ASSET_DIRS.
    def _process_image(self):
        raw = self._read_body()
        if raw is None:
            return
        try:
            payload = json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            return self._err(400, "JSON inválido.")
        kind = payload.get("kind")
        filename = payload.get("file")
        img_type = payload.get("type") or "auto"
        if img_type not in ("auto", "sprite", "background"):
            return self._err(400, "type debe ser auto, sprite o background.")
        adir = ASSET_DIRS.get(kind)
        if adir is None:
            return self._err(404, "Tipo de asset desconocido: %s" % kind)
        if kind in MODEL_ASSET_KINDS or kind in AUDIO_ASSET_KINDS:
            return self._err(400, "process_image solo aplica a assets de imagen.")
        safe = posixpath.normpath(str(filename or "")).lstrip("/")
        if not filename or safe.startswith("..") or "/" in safe or not _ASSET_UPLOAD_RE.match(safe):
            return self._err(400, "Nombre de fichero no válido.")
        target = adir / safe
        if not target.is_file():
            return self._err(404, "No existe %s/%s." % (kind, safe))
        script = ROOT / "tools" / "process_image.py"
        if not script.is_file():
            return self._err(500, "No se encuentra tools/process_image.py.")
        cmd = [sys.executable, str(script), str(target), str(target), "--type", img_type]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        except Exception as e:
            return self._err(500, "Error ejecutando process_image.py: %s" % e)
        if result.returncode != 0:
            return self._err(500, "process_image.py falló: %s" % (result.stderr or result.stdout or "sin detalle"))
        return self._json(200, {"ok": True, "kind": kind, "file": safe})

    # ── DELETE (borrar un elemento de una colección, o un asset subido) ──────
    def do_DELETE(self):
        path = unquote(self.path.split("?", 1)[0])
        if path.startswith("/api/assets/"):
            return self._asset_delete(path[len("/api/assets/"):])
        if not path.startswith("/api/collection/"):
            return self._err(404, "Ruta no válida para DELETE.")
        return self._collection_delete(path[len("/api/collection/"):])

    def _asset_delete(self, rest):
        parts = rest.split("/", 1)
        if len(parts) != 2:
            return self._err(400, "Ruta de asset incompleta (falta <kind>/<fichero>).")
        kind, filename = parts[0], parts[1]
        adir = ASSET_DIRS.get(kind)
        if adir is None:
            return self._err(404, "Tipo de asset desconocido: %s" % kind)
        safe = posixpath.normpath(filename).lstrip("/")
        if safe.startswith("..") or "/" in safe:
            return self._err(403, "Ruta no permitida.")
        if safe in PROTECTED_ASSETS.get(kind, set()):
            return self._err(403, "%s es un asset base del motor y no se puede borrar." % safe)
        fp = adir / safe
        if not fp.is_file():
            return self._err(404, "Asset no encontrado: %s" % safe)
        try:
            fp.unlink()
        except Exception as e:
            return self._err(500, "No se pudo borrar %s: %s" % (safe, e))
        return self._json(200, {"ok": True, "file": safe})

    # ── Colecciones "un fichero por id" (data/<name>/<id>.json) ───────────────
    def _collection_dir_and_id(self, rest):
        """Separa <name>/<id> y valida ambos. Devuelve (dir, id) o (None, None)."""
        parts = rest.split("/", 1)
        cname = parts[0]
        cdir = ALLOWED_COLLECTIONS.get(cname)
        if cdir is None:
            return None, None
        if len(parts) < 2:
            return cdir, None
        cid = parts[1]
        if cid.endswith(".json"):
            cid = cid[:-5]
        if not _COLLECTION_ID_RE.match(cid):
            return cdir, ""
        return cdir, cid

    def _collection_list(self, cname, cdir):
        """Listado de una colección "un fichero por id". Por defecto devuelve el
        contenido COMPLETO de cada elemento (la mayoría de colecciones -ids,
        dungeon_tiles- son fichas pequeñas: no hay motivo para no traerlas
        enteras y ahorrarse una segunda petición por elemento).

        Excepción: si un elemento tiene un array 'floors' (mazmorras, con N
        plantas de rejilla que pueden pesar mucho), el listado lo resume a su
        longitud en vez de mandarlo entero; el contenido completo se pide aparte
        con GET /api/collection/<name>/<id>."""
        out = {}
        if cdir.is_dir():
            for p in sorted(cdir.glob("*.json")):
                try:
                    obj = json.loads(p.read_text(encoding="utf-8"))
                except Exception as e:
                    out[p.stem] = {"error": str(e)}
                    continue
                if isinstance(obj, dict) and isinstance(obj.get("floors"), list):
                    preview = {k: v for k, v in obj.items() if k != "floors"}
                    preview["floors"] = len(obj["floors"])
                    out[p.stem] = preview
                else:
                    out[p.stem] = obj
        return out

    def _collection_get(self, path):
        rest = path[len("/api/collection/"):]
        cdir, cid = self._collection_dir_and_id(rest)
        if cdir is None:
            return self._err(403, "Colección no permitida.")
        if cid is None:
            # Sin id: listado de la colección (completo salvo 'floors' pesados).
            return self._json(200, self._collection_list(rest, cdir))
        if cid == "":
            return self._err(400, "Id de colección no válido.")
        f = cdir / f"{cid}.json"
        if not f.is_file():
            return self._err(404, "No existe %s/%s" % (rest, cid))
        return self._send(200, f.read_bytes(), "application/json; charset=utf-8")

    def _collection_put(self, rest):
        cdir, cid = self._collection_dir_and_id(rest)
        if cdir is None:
            return self._err(403, "Colección no permitida.")
        if not cid:
            return self._err(400, "Falta el id del elemento a escribir.")
        raw = self._read_body()
        if raw is None:
            return
        try:
            obj = json.loads(raw.decode("utf-8"))
        except Exception as e:
            return self._err(400, "JSON inválido: %s" % e)
        try:
            target = cdir / f"{cid}.json"
            text = json.dumps(obj, ensure_ascii=False, indent=4)
            _atomic_write_text(target, text)   # escritura atómica (temp + os.replace)
        except Exception as e:
            return self._err(500, "No se pudo escribir %s: %s" % (cid, e))
        return self._json(200, {"ok": True, "id": cid, "bytes": len(text.encode("utf-8"))})

    def _collection_delete(self, rest):
        cdir, cid = self._collection_dir_and_id(rest)
        if cdir is None:
            return self._err(403, "Colección no permitida.")
        if not cid:
            return self._err(400, "Falta el id del elemento a borrar.")
        target = cdir / f"{cid}.json"
        if not target.is_file():
            return self._err(404, "No existe %s" % cid)
        try:
            target.unlink()
        except Exception as e:
            return self._err(500, "No se pudo borrar %s: %s" % (cid, e))
        return self._json(200, {"ok": True, "id": cid})

    # ── API GET ──────────────────────────────────────────────────────────────
    def _api_get(self, path):
        if path == "/api/info":
            return self._json(200, {
                "name": ROOT.name,
                "root": str(ROOT),
                "hasData": DATA_DIR.is_dir(),
                "hasAssets": any(d.is_dir() for d in ASSET_DIRS.values()),
            })

        if path.startswith("/api/data/"):
            name = path[len("/api/data/"):]
            if name not in ALLOWED_DATA:
                return self._err(403, "Fichero no permitido: %s" % name)
            f = DATA_DIR / name
            if not f.is_file():
                return self._err(404, "No existe %s" % name)
            return self._send(200, f.read_bytes(), "application/json; charset=utf-8")

        # /api/collection/<name>            -> listado de la colección (completo salvo 'floors')
        # /api/collection/<name>/<id>        -> contenido completo de ese elemento
        if path.startswith("/api/collection/"):
            return self._collection_get(path)

        # /api/assets/<kind>/list  |  /api/assets/<kind>/<filename>
        if path.startswith("/api/assets/"):
            rest = path[len("/api/assets/"):]
            parts = rest.split("/", 1)
            if len(parts) != 2:
                return self._err(400, "Ruta de asset incompleta.")
            kind, tail = parts[0], parts[1]
            adir = ASSET_DIRS.get(kind)
            if adir is None:
                return self._err(404, "Tipo de asset desconocido: %s" % kind)
            if tail == "list":
                names = []
                if kind in SCENE_ASSET_KINDS:
                    exts = (".tscn",)
                elif kind in MODEL_ASSET_KINDS:
                    exts = (".glb", ".obj", ".gltf", ".tscn")
                elif kind in AUDIO_ASSET_KINDS:
                    exts = (".ogg", ".mp3", ".wav")
                else:
                    exts = IMAGE_EXTS
                if adir.is_dir():
                    if kind in MODEL_ASSET_KINDS:
                        for p in sorted(adir.rglob("*")):
                            if p.is_file() and p.suffix.lower() in exts:
                                names.append(p.relative_to(adir).as_posix())
                    else:
                        for p in sorted(adir.iterdir()):
                            if p.is_file() and p.suffix.lower() in exts:
                                names.append(p.name)
                return self._json(200, names)
            # Servir un fichero concreto (permitiendo subcarpetas sin traversal).
            safe = posixpath.normpath(tail).lstrip("/")
            if safe.startswith(".."):
                return self._err(403, "Ruta no permitida.")
            fp = (adir / safe).resolve()
            try:
                fp.relative_to(adir.resolve())
            except ValueError:
                return self._err(403, "Ruta fuera de límites.")
            if not fp.is_file():
                return self._err(404, "Asset no encontrado.")
            ctype = mimetypes.guess_type(str(fp))[0] or "application/octet-stream"
            return self._send(200, fp.read_bytes(), ctype)

        return self._err(404, "Endpoint API desconocido.")

    # ── Ficheros estáticos de la SPA (dentro de editor) y assets del proyecto ──
    def _static(self, path):
        if path in ("/", ""):
            path = "/index.html"
        safe = posixpath.normpath(path).lstrip("/")
        
        # Si la ruta apunta a assets/, servirla desde la carpeta assets del proyecto
        if safe.startswith("assets/") or safe == "assets":
            target = (ROOT / safe).resolve()
            try:
                target.relative_to(ASSETS.resolve())
            except ValueError:
                return self._err(403, "Acceso denegado fuera de assets.")
        else:
            target = (EDITOR_DIR / safe).resolve()
            # Evitar salir de EDITOR_DIR.
            try:
                target.relative_to(EDITOR_DIR)
            except ValueError:
                return self._err(403, "Acceso denegado.")
        
        if not target.is_file():
            return self._err(404, "No encontrado: %s" % path)
        ctype = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        if target.suffix == ".js":
            ctype = "text/javascript; charset=utf-8"
        elif target.suffix == ".css":
            ctype = "text/css; charset=utf-8"
        elif target.suffix == ".html":
            ctype = "text/html; charset=utf-8"
        elif target.suffix == ".png":
            ctype = "image/png"
        elif target.suffix in (".jpg", ".jpeg"):
            ctype = "image/jpeg"
        elif target.suffix == ".webp":
            ctype = "image/webp"
        elif target.suffix == ".svg":
            ctype = "image/svg+xml"
        return self._send(200, target.read_bytes(), ctype)

    # Log más limpio.
    def log_message(self, fmt, *args):
        print("  %s - %s" % (self.address_string(), fmt % args))


def main():
    ap = argparse.ArgumentParser(description="Servidor de Taos Game Maker.")
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--no-open", action="store_true", help="No abrir automáticamente el navegador")
    args = ap.parse_args()

    if not DATA_DIR.is_dir():
        print("AVISO: no se encontró la carpeta de datos en %s" % DATA_DIR)
        print("       (¿está serve.py en editor dentro del proyecto?)")

    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    url = "http://%s:%d/" % (args.host, args.port)
    print("=" * 60)
    print("  Taos Game Maker — Servidor de Diseño")
    print("  Raíz del proyecto : %s" % ROOT)
    print("  Datos             : %s" % DATA_DIR)
    print("  Assets            : %s" % (ASSETS if ASSETS.is_dir() else "(no encontrados)"))
    print("  Abre en el navegador:  %s" % url)
    print("  (Ctrl+C para detener)")
    print("=" * 60)

    if not args.no_open:
        # Abrimos el navegador en un hilo de fondo 0.5s después de lanzar el servidor
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido.")


if __name__ == "__main__":
    main()
