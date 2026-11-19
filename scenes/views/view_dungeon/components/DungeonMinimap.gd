# DungeonMinimap.gd
# ─────────────────────────────────────────────────────────────────────────────
# MINIMAPA de orientación dentro de la mazmorra (Game Feel / UX): las mazmorras
# son rejillas ciegas vistas en primera persona sin ningún punto de referencia
# — es fácil perderse en cuanto crecen más allá de un pasillo recto. Dibuja,
# con NIEBLA DE GUERRA (solo muestra casillas ya visitadas, como cualquier
# radar de mazmorra), un recuadro centrado en el jugador con su orientación
# real. 100% procedural (_draw): sin texturas ni assets nuevos.
#
# Lo pilota ViewDungeon: `set_floor_data()` al entrar o cambiar de planta
# (reinicia la niebla — cada planta se explora de cero) y `update_player()`
# cada frame con la posición/orientación reales del CharacterBody3D.
# ─────────────────────────────────────────────────────────────────────────────
extends Control
class_name DungeonMinimap

const DEFAULT_VIEW_RADIUS: int = 6
const REVEAL_RADIUS: int = 2     # radio "de antorcha" que se revela al pasar
# Ligeramente más grande que antes (168→192) para leerse mejor de un vistazo
# rápido durante la exploración: "mejóralo ya que lo estamos tocando".
const SIZE_PX: float = 192.0

var view_radius: int = DEFAULT_VIEW_RADIUS
var _cells: Array = []           # floor.cells de la planta actual (Array de Array de Dictionary)
var _cell_size: float = 3.0
var _visited: Dictionary = {}    # "x,y" -> true (niebla de guerra de la planta actual)
var _player_gx: int = 0
var _player_gy: int = 0
var _facing: Vector2 = Vector2.UP  # avance (x,z) normalizado


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	size = Vector2(SIZE_PX, SIZE_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


var _boss_defeated: bool = false


func set_boss_defeated(val: bool) -> void:
	if _boss_defeated != val:
		_boss_defeated = val
		queue_redraw()


## Cambia de planta (o inicia la mazmorra): reinicia la niebla de guerra —
## cada planta se explora de cero, como cualquier mapa de mazmorra.
func set_floor_data(cells: Array, cell_size: float) -> void:
	_cells = cells
	_cell_size = maxf(0.1, cell_size)
	_visited.clear()
	queue_redraw()


## Llamado cada frame por ViewDungeon con la posición/orientación reales del
## jugador (en metros de mundo). `facing_xz` es el vector de avance (x,z); no
## necesita venir normalizado. Solo redibuja si la casilla o la rotación cambian.
func update_player(world_pos: Vector3, facing_xz: Vector2) -> void:
	var last_gx := _player_gx
	var last_gy := _player_gy
	var last_facing := _facing

	_player_gx = int(round(world_pos.x / _cell_size))
	_player_gy = int(round(world_pos.z / _cell_size))

	var new_facing := _facing
	if facing_xz.length_squared() > 0.0001:
		new_facing = facing_xz.normalized()

	var pos_changed := (_player_gx != last_gx or _player_gy != last_gy)
	var rot_changed := (new_facing.dot(last_facing) < 0.9995)

	if pos_changed or _visited.is_empty():
		_facing = new_facing
		_reveal_around(_player_gx, _player_gy)
		queue_redraw()
	elif rot_changed:
		_facing = new_facing
		queue_redraw()


func _reveal_around(gx: int, gy: int) -> void:
	for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			_visited[Vector2i(gx + dx, gy + dy)] = true


func _cell_at(gx: int, gy: int) -> Dictionary:
	if gy < 0 or gy >= _cells.size():
		return {}
	var row = _cells[gy]
	if not (row is Array) or gx < 0 or gx >= row.size():
		return {}
	var c = row[gx]
	return c if c is Dictionary else {}


func _draw() -> void:
	# Fondo: panel oscuro semitransparente (mismo lenguaje visual que el
	# joystick virtual de ViewDungeon) + marco acento.
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), Color(0.05, 0.05, 0.07, 0.6))

	var r := SIZE_PX * 0.5
	var cell_px: float = SIZE_PX / float(view_radius * 2 + 1)
	for dy in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			var gx := _player_gx + dx
			var gy := _player_gy + dy
			if not _visited.has(Vector2i(gx, gy)):
				continue
			var cell := _cell_at(gx, gy)
			if cell.is_empty() or String(cell.get("t", "void")) == "void":
				continue
			var px := r + float(dx) * cell_px - cell_px * 0.5
			var py := r + float(dy) * cell_px - cell_px * 0.5
			var solid: bool = bool(Design.get_dungeon_tile(String(cell.get("t", ""))).get("solid", false))
			var col: Color = Color(0.13, 0.13, 0.16, 0.92) if solid else Color(0.62, 0.58, 0.5, 0.55)
			draw_rect(Rect2(px, py, cell_px - 1.0, cell_px - 1.0), col)
			var is_boss_tp := bool(cell.get("is_boss_teleport", false))
			if is_boss_tp and not _boss_defeated:
				continue
			var marker = _marker_color(String(cell.get("t", "")))
			if marker != null:
				draw_circle(Vector2(px + cell_px * 0.5, py + cell_px * 0.5), cell_px * 0.28, marker)

	# Marco/marcador con el color de marca del TEMA activo (antes fijo
	# dorado-apagado siempre, sin relación con el tema elegido en Opciones).
	var accent := UiKit.theme_color("accent", UiKit.ACCENT)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), Color(accent.r, accent.g, accent.b, 0.55), false, 2.0)

	# Jugador (siempre en el centro): triángulo orientado según su avance real.
	var fwd := _facing
	var side := Vector2(-fwd.y, fwd.x)
	var center := Vector2(r, r)
	var tip := center + fwd * 9.0
	var back_l := center - fwd * 6.0 + side * 5.0
	var back_r := center - fwd * 6.0 - side * 5.0
	draw_colored_polygon(PackedVector2Array([tip, back_l, back_r]), accent)


## Color del marcador de punto de interés para un tipo de casilla, o `null` si
## ese tipo no necesita marcador propio (paredes/suelo ya se distinguen por el
## color base de la celda).
func _marker_color(t: String):
	match t:
		"monster": return Color(0.95, 0.25, 0.25)
		"chest": return Color(1.0, 0.85, 0.3)
		"teleport", "stairs": return Color(0.4, 0.85, 1.0)
	return null
