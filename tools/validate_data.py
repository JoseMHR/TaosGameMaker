#!/usr/bin/env python3
# ============================================================================
# validate_data.py  ·  Validador de integridad cruzada de los datos del juego
# ----------------------------------------------------------------------------
# HERRAMIENTA PERMANENTE (ver docs/tasks/task_arreglos.md §2). Recorre TODO
# `data/` y comprueba referencias cruzadas entre ficheros que, si están rotas,
# fallan en SILENCIO durante el juego (una opción de diálogo que no hace nada,
# un item inexistente que nunca se resuelve, un lever que apunta a un eid que
# no existe...). No sustituye a jugar/probar, pero atrapa el error tipográfico
# más común y barato de cometer al escribir contenido a mano en volumen.
#
# Comprobaciones:
#   1. Tokens `item:<id>`/`-item:<id>` y `has_item("id")`/`no_item("id")` en
#      `reward`/`condition` -> deben existir en data/items/<id>.json.
#   2. Tokens `prof:<id>` en `reward` -> deben existir en professions.json.
#   3. Ids de habilidad citados en professions.json (`skills[].id`) -> deben
#      existir en skills.json.
#   4. `next: ["nodo", ...]` de cada NPC -> el nodo debe existir en el MISMO
#      fichero (o ser un sentinel reservado: "close").
#   5. Tokens `dialogue:<id>` / `cine:<id>` en `reward`/`condition` -> deben
#      existir en dialogues.json / data/scenes/ respectivamente (o en
#      data/scenes/ ambos, ya que una Escena puede sustituir a un diálogo).
#   6. Mazmorras: todo `targets[].eid` debe apuntar a un `eid` definido en el
#      MISMO fichero de mazmorra (se ignoran eid vacíos "").
#   7. Mazmorras: todo tile `"t"` debe existir como `data/dungeon_tiles/<t>.json`.
#   8. Mapamundi: todo `"terrain"` de world.json/world_test.json debe existir
#      como `data/world_terrains/<terrain>.json`.
#   9. Mapamundi: todo id citado en el `content` de una ciudad (data/ids/*.json)
#      debe existir como data/ids/<id>.json.
#
# Ignora ficheros de copia de seguridad (*.bak, *.backup, "* - copia*").
#
# Uso:  python tools/validate_data.py
# Código de salida: 0 si no hay errores, 1 si se ha encontrado alguno.
# ============================================================================

import json
import re
import sys
from pathlib import Path

# Consolas Windows (cp1252) no imprimen emoji/acentos por defecto: forzar UTF-8.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

BACKUP_PATTERNS = ("*.bak", "*.backup", "* - copia*", "* - copy*")

# Sentinels reservados del motor de diálogo que NO son nodos reales.
NEXT_SENTINELS = {"close", ""}

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def is_backup(path: Path) -> bool:
    name = path.name
    return any(path.match(pat) or name.endswith(".bak") or name.endswith(".backup") or " - copia" in name or " - copy" in name
                for pat in BACKUP_PATTERNS)


def load_json(path: Path):
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception as e:
        err(f"[JSON inválido] {rel(path)}: {e}")
        return None


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def dir_ids(dirpath: Path) -> set[str]:
    """Ids disponibles en un directorio 'una entidad por fichero' (nombre sin .json)."""
    if not dirpath.is_dir():
        return set()
    return {p.stem for p in dirpath.glob("*.json") if not is_backup(p)}


def iter_data_json():
    """Todos los .json activos de data/ (recursivo), sin backups."""
    for p in DATA.rglob("*.json"):
        if is_backup(p):
            continue
        yield p


# ── Recolectar catálogos base ────────────────────────────────────────────────
ITEM_IDS = dir_ids(DATA / "items")
PROFESSIONS = load_json(DATA / "professions.json") or {}
PROFESSION_IDS = set(PROFESSIONS.keys()) if isinstance(PROFESSIONS, dict) else set()
SKILLS = load_json(DATA / "skills.json") or {}
SKILL_IDS = set(SKILLS.keys()) if isinstance(SKILLS, dict) else set()
DIALOGUE_IDS = set((load_json(DATA / "dialogues.json") or {}).keys())
DUNGEON_TILE_TYPES = dir_ids(DATA / "dungeon_tiles")
WORLD_TERRAIN_CODES = dir_ids(DATA / "world_terrains")
IDS_CATALOG = dir_ids(DATA / "ids")
SCENES_IDS = dir_ids(DATA / "scenes") | set((load_json(DATA / "scenes.json") or {}).keys())
CINEMATICS_IDS = dir_ids(DATA / "cinematics")
# Catálogos añadidos (Task 6 · G2/G3/G4): tokens que el editor (validator.js) ya
# cruzaba pero la CLI no. `worldt`/`combat`/`event`/`questf`/`quests`.
WORLD_TRANSFORM_IDS = set((load_json(DATA / "world_transforms.json") or {}).keys())
ENEMY_IDS = dir_ids(DATA / "enemies")
EVENT_IDS = set((load_json(DATA / "events.json") or {}).keys())
WORLD_RESOURCE_CODES = dir_ids(DATA / "world_resources")
_QUESTS_DOC = load_json(DATA / "quests.json") or {}
QUEST_STATES = set(_QUESTS_DOC.get("order", []) if isinstance(_QUESTS_DOC, dict) else [])


# ── 1/2/5: tokens de reward/condition (mini-lenguaje de Design.gd) ──────────
RE_ITEM_TOKEN = re.compile(r"(?<!-)\bitem:([a-zA-Z0-9_]+)")
RE_NEG_ITEM_TOKEN = re.compile(r"-item:([a-zA-Z0-9_]+)")
RE_PROF_TOKEN = re.compile(r"\bprof:([^;]+)")
RE_DIALOGUE_TOKEN = re.compile(r"\bdialogue:([a-zA-Z0-9_]+)")
RE_CINE_TOKEN = re.compile(r"\bcine:([a-zA-Z0-9_]+)")
RE_HAS_ITEM_COND = re.compile(r"(?:has_item|no_item)\(\s*[\"']([a-zA-Z0-9_]+)[\"']")
# Task 6 · G2: tokens que faltaban en la CLI (ya presentes en validator.js).
RE_WORLDT_TOKEN = re.compile(r"\bworldt:([a-zA-Z0-9_]+)")
RE_COMBAT_TOKEN = re.compile(r"\bcombat:([a-zA-Z0-9_]+)")   # combat:id[:lvl[:boss]] → captura id
RE_EVENT_TOKEN = re.compile(r"\bevent:([a-zA-Z0-9_]+)")
RE_QUEST_TOKEN = re.compile(r"\b(?:questf|quests):([a-zA-Z0-9_]+)")


def check_reward_string(reward: str, where: str) -> None:
    for m in RE_ITEM_TOKEN.finditer(reward):
        item_id = m.group(1)
        if item_id not in ITEM_IDS:
            err(f"[item inexistente] {where}: token 'item:{item_id}' no existe en data/items/")
    for m in RE_NEG_ITEM_TOKEN.finditer(reward):
        item_id = m.group(1)
        if item_id not in ITEM_IDS:
            err(f"[item inexistente] {where}: token '-item:{item_id}' no existe en data/items/")
    for m in RE_PROF_TOKEN.finditer(reward):
        prof_id = m.group(1).strip()
        if prof_id and prof_id not in PROFESSION_IDS:
            err(f"[profesión inexistente] {where}: token 'prof:{prof_id}' no coincide con ninguna clave de professions.json")
    for m in RE_DIALOGUE_TOKEN.finditer(reward):
        d_id = m.group(1)
        if d_id not in DIALOGUE_IDS and d_id not in SCENES_IDS and d_id not in CINEMATICS_IDS:
            err(f"[diálogo inexistente] {where}: token 'dialogue:{d_id}' no existe en dialogues.json, scenes/ ni cinematics/")
    for m in RE_CINE_TOKEN.finditer(reward):
        c_id = m.group(1)
        if c_id not in SCENES_IDS and c_id not in CINEMATICS_IDS:
            err(f"[cinemática inexistente] {where}: token 'cine:{c_id}' no existe en data/cinematics/ ni scenes/")
    # ── Task 6 · G2: tokens antes solo validados en el editor ──
    for m in RE_WORLDT_TOKEN.finditer(reward):
        w_id = m.group(1)
        if w_id not in WORLD_TRANSFORM_IDS:
            err(f"[transformación inexistente] {where}: token 'worldt:{w_id}' no existe en world_transforms.json")
    for m in RE_COMBAT_TOKEN.finditer(reward):
        e_id = m.group(1)
        if e_id not in ENEMY_IDS:
            err(f"[enemigo inexistente] {where}: token 'combat:{e_id}' no existe en data/enemies/")
    for m in RE_EVENT_TOKEN.finditer(reward):
        ev_id = m.group(1)
        if ev_id not in EVENT_IDS:
            err(f"[evento inexistente] {where}: token 'event:{ev_id}' no existe en events.json")
    # `questf`/`quests` referencian un estado de la questline. Si el estado no
    # está en quests.json.order es un AVISO (puede ser un estado dinámico), no error.
    for m in RE_QUEST_TOKEN.finditer(reward):
        q_state = m.group(1)
        if QUEST_STATES and q_state not in QUEST_STATES:
            warn(f"[estado de misión no declarado] {where}: token de misión '{m.group(0)}' usa un estado que no está en quests.json.order")


def check_condition_string(cond: str, where: str) -> None:
    for m in RE_HAS_ITEM_COND.finditer(cond):
        item_id = m.group(1)
        if item_id not in ITEM_IDS:
            err(f"[item inexistente] {where}: condición referencia has_item/no_item('{item_id}') que no existe en data/items/")


def walk_reward_condition(obj, where_prefix: str) -> None:
    """Recorre recursivamente cualquier estructura buscando claves 'reward'/'condition'
    (cubre npcs, events.json, quests.json, dungeon_kits.json, etc. sin asumir un
    esquema rígido por fichero)."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "reward" and isinstance(v, str) and v:
                check_reward_string(v, where_prefix)
            elif k == "condition" and isinstance(v, str) and v:
                check_condition_string(v, where_prefix)
            elif k == "actions" and isinstance(v, list):
                for a in v:
                    if isinstance(a, str):
                        check_reward_string(a, where_prefix)
            else:
                walk_reward_condition(v, where_prefix)
    elif isinstance(obj, list):
        for item in obj:
            walk_reward_condition(item, where_prefix)


# ── 3: habilidades citadas en professions.json ──────────────────────────────
def check_profession_skills() -> None:
    if not isinstance(PROFESSIONS, dict):
        return
    for prof_id, prof_def in PROFESSIONS.items():
        if not isinstance(prof_def, dict):
            continue
        for sk in prof_def.get("skills", []) or []:
            if not isinstance(sk, dict):
                continue
            sk_id = sk.get("id")
            if sk_id and sk_id not in SKILL_IDS:
                err(f"[habilidad inexistente] professions.json[{prof_id}]: skill '{sk_id}' no existe en skills.json")


# ── 4: integridad next[] de diálogos de NPC ─────────────────────────────────
def check_npc_dialogues() -> None:
    npcs_dir = DATA / "npcs"
    if not npcs_dir.is_dir():
        return
    for path in sorted(npcs_dir.glob("*.json")):
        if is_backup(path):
            continue
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        node_ids = set(data.keys())
        for node_id, node in data.items():
            if not isinstance(node, dict):
                continue
            for nxt in node.get("next", []) or []:
                if not isinstance(nxt, str):
                    continue
                if nxt in node_ids or nxt in NEXT_SENTINELS:
                    continue
                err(f"[next roto] {rel(path)}[{node_id}]: 'next' apunta a '{nxt}', que no existe en el mismo NPC")
        walk_reward_condition(data, f"{rel(path)}")


# ── 6/7: integridad de mazmorras (eid/targets, tile types) ──────────────────
def collect_eids(obj, found: set[str]) -> None:
    if isinstance(obj, dict):
        eid = obj.get("eid")
        if isinstance(eid, str) and eid != "":
            found.add(eid)
        for v in obj.values():
            collect_eids(v, found)
    elif isinstance(obj, list):
        for item in obj:
            collect_eids(item, found)


def collect_target_refs(obj, refs: list[tuple[str, dict]]) -> None:
    if isinstance(obj, dict):
        targets = obj.get("targets")
        if isinstance(targets, list):
            for t in targets:
                if isinstance(t, dict):
                    t_eid = t.get("eid")
                    if isinstance(t_eid, str) and t_eid != "":
                        refs.append((t_eid, obj))
        for v in obj.values():
            collect_target_refs(v, refs)
    elif isinstance(obj, list):
        for item in obj:
            collect_target_refs(item, refs)


def collect_tile_types(obj, found: set[str]) -> None:
    if isinstance(obj, dict):
        t = obj.get("t")
        if isinstance(t, str) and t != "":
            found.add(t)
        for v in obj.values():
            collect_tile_types(v, found)
    elif isinstance(obj, list):
        for item in obj:
            collect_tile_types(item, found)


def check_dungeons() -> None:
    dungeons_dir = DATA / "dungeons"
    if not dungeons_dir.is_dir():
        return
    for path in sorted(dungeons_dir.glob("*.json")):
        if is_backup(path):
            continue
        data = load_json(path)
        if not isinstance(data, dict):
            continue

        defined_eids: set[str] = set()
        collect_eids(data, defined_eids)
        refs: list[tuple[str, dict]] = []
        collect_target_refs(data, refs)
        for t_eid, _owner in refs:
            if t_eid not in defined_eids:
                err(f"[eid roto] {rel(path)}: 'targets' apunta a eid '{t_eid}', que no está definido en la misma mazmorra")

        used_tiles: set[str] = set()
        collect_tile_types(data, used_tiles)
        for t in used_tiles:
            if t not in DUNGEON_TILE_TYPES:
                warn(f"[tile_type desconocido] {rel(path)}: usa tile \"t\":\"{t}\", sin ficha en data/dungeon_tiles/")

        walk_reward_condition(data, f"{rel(path)}")


# ── 8: terrenos del mapamundi ────────────────────────────────────────────────
def check_world_terrains() -> None:
    for fname in ("world.json", "world_test.json"):
        path = DATA / fname
        if not path.is_file():
            continue
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        used_terrains: set[str] = set()
        for row in data.get("tiles", []) or []:
            if not isinstance(row, list):
                continue
            for cell in row:
                if isinstance(cell, dict):
                    terr = cell.get("terrain")
                    if isinstance(terr, str) and terr:
                        used_terrains.add(terr)
        for t in used_terrains:
            if t not in WORLD_TERRAIN_CODES:
                err(f"[terreno inexistente] {rel(path)}: usa terrain '{t}', sin ficha en data/world_terrains/")


# ── 9: referencias cruzadas de POIs (data/ids/*.json) ───────────────────────
def check_ids_content() -> None:
    ids_dir = DATA / "ids"
    if not ids_dir.is_dir():
        return
    for path in sorted(ids_dir.glob("*.json")):
        if is_backup(path):
            continue
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        for poi_id in data.get("content", []) or []:
            if isinstance(poi_id, str) and poi_id not in IDS_CATALOG:
                err(f"[POI inexistente] {rel(path)}: 'content' referencia '{poi_id}', sin ficha en data/ids/")
        walk_reward_condition(data, f"{rel(path)}")


# ── Resto de ficheros sueltos con reward/condition (events.json, quests.json...) ──
def check_misc_files() -> None:
    handled_dirs = {DATA / "npcs", DATA / "dungeons", DATA / "ids"}
    for path in iter_data_json():
        if any(str(path).startswith(str(d)) for d in handled_dirs):
            continue
        data = load_json(path)
        if data is None:
            continue
        walk_reward_condition(data, rel(path))


# -- Task 6 - G3: integridad de loot inline de enemigos --------------------
# Modelo REAL: tiradas INDEPENDIENTES por entrada (`chance` en [0,1]), NO
# porcentaje acumulado. Se valida chance/min-max y las referencias de cada kind.
def _check_loot_entry(entry: dict, where: str) -> None:
    if not isinstance(entry, dict):
        return
    kind = entry.get("kind")
    ch = entry.get("chance")
    if ch is not None:
        if not isinstance(ch, (int, float)) or ch < 0 or ch > 1:
            err(f"[botin chance invalida] {where}: 'chance'={ch!r} debe ser un numero en [0.0, 1.0]")
    mn, mx = entry.get("min"), entry.get("max")
    if isinstance(mn, (int, float)) and isinstance(mx, (int, float)) and mn > mx:
        err(f"[botin min>max] {where}: 'min'={mn} es mayor que 'max'={mx}")
    # kind item/consumable/resource conceden un ITEM del inventario
    # (LootManager.grant_loot_entries -> _state.add_item(id)); su `id` debe existir
    # en data/items/.
    if kind in ("item", "consumable", "resource"):
        iid = entry.get("id")
        if isinstance(iid, str) and iid and iid not in ITEM_IDS:
            err(f"[botin item inexistente] {where}: kind '{kind}' id '{iid}' no existe en data/items/")


def check_loot_tables() -> None:
    # loot inline en enemigos (lista de entradas, ya no hay tablas compartidas).
    enemies_dir = DATA / "enemies"
    if enemies_dir.is_dir():
        for path in sorted(enemies_dir.glob("*.json")):
            if is_backup(path):
                continue
            data = load_json(path)
            if not isinstance(data, dict):
                continue
            loot = data.get("loot")
            if isinstance(loot, list):
                for entry in loot:
                    _check_loot_entry(entry, f"{rel(path)}[loot]")


# ── Task 6 · G4: guardas económicas preventivas de tiendas (shops.json) ──────
def check_shops() -> None:
    shops = load_json(DATA / "shops.json")
    if not isinstance(shops, dict):
        return
    for stock_id, lines in shops.items():
        if not isinstance(lines, list):
            continue
        for line in lines:
            if not isinstance(line, dict):
                continue
            iid = line.get("id")
            price = line.get("price")
            if isinstance(iid, str) and iid and iid not in ITEM_IDS:
                err(f"[tienda item inexistente] shops.json[{stock_id}]: '{iid}' no existe en data/items/")
            if not isinstance(price, (int, float)) or price <= 0:
                err(f"[tienda precio inválido] shops.json[{stock_id}]: '{iid}' tiene price={price!r} (debe ser > 0)")


# ── Task 6 · G2 (raíz de G1): reconciliación de banderas globales (gflag) ─────
# EMISIONES: token `gflag:<x>` en data + `set_world_flag("<x>"...)` en scripts.
# LECTURAS : `gflag("<x>")`/`no_gflag("<x>")` en data/scripts +
#            `has_world_flag("<x>")`/`get_world_flag_val("<x>"...)` en scripts.
# Se avisan (no error) las banderas leídas-pero-nunca-emitidas y viceversa.
# `\\?` tolera las comillas ESCAPADAS de JSON (`gflag(\"x\")`) además de las
# comillas normales de GDScript (`gflag("x")`).
RE_GFLAG_EMIT_TOKEN = re.compile(r"\bgflag:([a-zA-Z0-9_]+)")
RE_GFLAG_READ = re.compile(r"(?:no_gflag|gflag)\(\s*\\?[\"']([a-zA-Z0-9_]+)")
RE_SET_WORLD_FLAG = re.compile(r"set_world_flag\(\s*\\?[\"']([a-zA-Z0-9_]+)")
RE_HAS_WORLD_FLAG = re.compile(r"(?:has_world_flag|get_world_flag_val)\(\s*\\?[\"']([a-zA-Z0-9_]+)")


def _strip_gd_comment(line: str) -> str:
    """Recorta el comentario de una línea GDScript (naive) para no capturar los
    EJEMPLOS de banderas que aparecen en docstrings (`# Uso: gflag("nombre")`)."""
    h = line.find("#")
    return line if h < 0 else line[:h]


# gflags LEÍDOS que a propósito no tienen emisor de bandera, clasificados para
# que el validador NO los reporte como bug de cableado (seguiría cazando
# cualquier flag huérfano NUEVO no listado aquí):
#   · ALIAS REDUNDANTES: su mecanismo REAL funciona por estado de misión
#     (`quest == "..."` / is_quest_at_least) y la lectura por gflag es
#     defensiva/heredada, no bloquea nada.
# NOTA: "monkey_cleared"/"sentinel_passed" salieron de esta lista (logros
# 'monkey_bridge'/'sentinel_calmed' en achievements.json ya los leen de
# verdad vía gflag()). "act3_islands_reached"/"act3_cinco_fases_done"/
# "monkey_act3_seen" también salieron: eran logros de un Acto 3 (archipiélago
# de los ecos) descartado por STORY.md (versión canónica = Gloriam/desierto);
# se eliminaron esos logros en vez de mantener contenido pendiente huérfano.
KNOWN_UNWIRED_GFLAGS = {
    # Alias redundantes (gestionados por estado de misión):
    "crossed_tunnel", "tunnel_cleared",
}


def check_gflag_reconciliation() -> None:
    emitted: set[str] = set()
    # Las claves de world_transforms.json se LEEN dinámicamente por el bucle de
    # persistencia de WorldMapBuilder (`has_world_flag(transform_name)` al
    # reconstruir el mundo), lectura que el análisis estático no ve. Se siembran
    # como "leídas" para no marcar sus gflag-companion como huérfanos de escritura.
    read: set[str] = set(WORLD_TRANSFORM_IDS)
    # data/ (texto crudo: capta tokens y condiciones dondequiera que estén).
    for path in iter_data_json():
        try:
            text = path.read_text(encoding="utf-8-sig")
        except Exception:
            continue
        emitted.update(RE_GFLAG_EMIT_TOKEN.findall(text))
        read.update(RE_GFLAG_READ.findall(text))
    # GDScript de scripts/ Y scenes/ (ambos contienen .gd: p. ej. ViewDungeon.gd
    # vive en scenes/ y emite banderas). Emisiones y lecturas literales; los
    # argumentos variables se ignoran (p. ej. set_world_flag(String(gp[0])) es un
    # emisor DINÁMICO cubierto por los tokens `gflag:` de data). Sin comentarios.
    for base in ("scripts", "scenes"):
        gd_dir = ROOT / base
        if not gd_dir.is_dir():
            continue
        for gd in gd_dir.rglob("*.gd"):
            try:
                code = "\n".join(_strip_gd_comment(ln) for ln in gd.read_text(encoding="utf-8").splitlines())
            except Exception:
                continue
            emitted.update(RE_SET_WORLD_FLAG.findall(code))
            read.update(RE_GFLAG_READ.findall(code))
            read.update(RE_HAS_WORLD_FLAG.findall(code))
    # Los nombres terminados en '_' provienen de banderas construidas
    # DINÁMICAMENTE (p. ej. `gflag("apprentice_" + id)`); no son literales reales.
    def _is_dynamic(f: str) -> bool:
        return f.endswith("_")
    for flag in sorted(read - emitted):
        if _is_dynamic(flag) or flag in KNOWN_UNWIRED_GFLAGS:
            continue
        warn(f"[gflag huérfano de lectura] '{flag}' se LEE en una condición pero NUNCA se emite (gflag:/set_world_flag). La condición nunca se cumplirá.")
    for flag in sorted(emitted - read):
        if _is_dynamic(flag) or flag in KNOWN_UNWIRED_GFLAGS:
            continue
        warn(f"[gflag huérfano de escritura] '{flag}' se EMITE pero NUNCA se lee en ninguna condición.")


def main() -> int:
    check_profession_skills()
    check_npc_dialogues()
    check_dungeons()
    check_world_terrains()
    check_ids_content()
    check_misc_files()
    check_loot_tables()
    check_shops()
    check_gflag_reconciliation()

    print(f"validate_data.py — {len(list(iter_data_json()))} ficheros JSON analizados en data/\n")

    if warnings:
        print(f"⚠️  {len(warnings)} aviso(s):")
        for w in warnings:
            print(f"   - {w}")
        print()

    if errors:
        print(f"❌ {len(errors)} error(es) de integridad encontrados:")
        for e in errors:
            print(f"   - {e}")
        return 1

    print("✅ Sin errores de integridad cruzada.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
