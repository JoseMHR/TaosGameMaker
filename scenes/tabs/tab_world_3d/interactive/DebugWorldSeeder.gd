# DebugWorldSeeder.gd
# ─────────────────────────────────────────────────────────────────────────────
# Siembra de objetos de PRUEBA cerca del punto de inicio cuando GlobalState.
# debug_mode está activo (roca demolible, enemigo de ejemplo, cartel de
# ejemplo). Cada función es idempotente: persiste vía world_delta y no repite
# si ya hay algo colocado en la casilla candidata.
#
# Extraído de TabWorld3D.gd::_ready (antes en el #region "OBJETOS INTERACTIVOS"
# de un único fichero de ~5300 líneas) para aislar este código de solo-debug,
# sin tocar código no relacionado. Sin coupling a `self`: solo usa GlobalState.
# ─────────────────────────────────────────────────────────────────────────────
class_name DebugWorldSeeder
extends RefCounted


## ¿La casilla está totalmente vacía (sin localización, recurso, evento, objeto
## interactivo ni enemigo)? Copia local de TabWorld3D._cell_is_bare (no-static,
## sin coupling a `self`): evita depender de una instancia de TabWorld3D solo
## para esta comprobación pura sobre `cell`.
static func _cell_is_bare(cell: CellResource) -> bool:
	if cell == null:
		return false
	return cell.item == "" and cell.resource == "" and cell.event_id == "" \
		and (not (cell.interactive is Dictionary) or cell.interactive.is_empty()) \
		and (not (cell.enemy is Dictionary) or cell.enemy.is_empty())


## DEBUG: coloca una ROCA DEMOLIBLE (obstacle.bombable) cerca del inicio para probar
## las bombas. Al detonar deja pradera y da piedra. Persiste vía world_delta.
static func place_debug_bombable() -> void:
	var spawn: Vector2i = GlobalState.player_pos
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 2)]:
		var nc: Vector2i = spawn + d
		var c: CellResource = GlobalState.hexagons_db.get(nc, null) as CellResource
		if c == null or c.is_solid() or not _cell_is_bare(c):
			continue
		if GlobalState.has_world_delta(nc) or c.terrain in ["sea", "cst"]:
			continue
		GlobalState.record_world_delta(nc, {
			"icon": "🪨",
			"name": {"es": "Roca agrietada", "en": "Cracked rock"},
			"description": {"es": "Una roca frágil. Parece que una explosión la haría añicos.", "en": "A brittle rock. An explosion would surely shatter it."},
			"obstacle": {
				"bombable": true,
				"reward": {"item": "stone", "qty": 3},
				"after": {
					"icon": "🌿",
					"name": {"es": "Escombros", "en": "Rubble"},
					"description": {"es": "Los restos de una roca reventada.", "en": "The remains of a blasted rock."},
				},
				"sfx": "hit",
			},
		})
		return


## DEBUG: coloca un ENEMIGO de ejemplo (slime) a un par de casillas del inicio para
## poder probar el sistema de enemigos del mapamundi. Persiste vía world_delta.
static func place_debug_enemy() -> void:
	var spawn: Vector2i = GlobalState.player_pos
	# Buscar una casilla cercana (distancia 2) transitable, vacía y sin nada.
	for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2)]:
		var nc: Vector2i = spawn + d
		var c: CellResource = GlobalState.hexagons_db.get(nc, null) as CellResource
		if c == null or not c.is_walkable_terrain() or c.is_solid():
			continue
		if c.item != "" or c.resource != "" or c.event_id != "" \
				or (c.interactive is Dictionary and not c.interactive.is_empty()) \
				or (c.enemy is Dictionary and not c.enemy.is_empty()):
			continue
		if GlobalState.has_world_delta(nc) or GlobalState.is_overworld_enemy_defeated(nc):
			continue
		GlobalState.record_world_delta(nc, {"enemy": {
			"enemy_id": "slime",
			"level": 1,
			"sprite": "🟢",
			"radius": 0,
			"speed": 0,
			"move_interval": 2.0,
			"respawn": 30,
		}})
		return


## DEBUG: Cartel de bienvenida (obsoleto / retirado).
static func place_debug_sign() -> void:
	pass
