# MinimapViewer.gd
# ─────────────────────────────────────────────────────────────────────────────
# MAPA / MINIMAPA CON NIEBLA DE GUERRA — overlay reutilizable construido por código.
#
# Dibuja una vista cenital del mapamundi usando SOLO las casillas ya descubiertas
# (`GlobalState.explored_coords`), respetando la niebla de guerra: lo no explorado
# no se muestra. Cada casilla se pinta con su `biome_color`; encima se marcan los
# PUNTOS DE INTERÉS (ciudades, mazmorras, campamento, recursos) y la POSICIÓN del
# jugador. Es de solo lectura y se cierra con el botón o tocando fuera.
#
# Todo es data-driven (lee `GlobalState.hexagons_db`/`explored_coords`) y no conoce
# la lógica del mundo 3D: solo la representa en 2D.
# ─────────────────────────────────────────────────────────────────────────────
class_name MinimapViewer
extends Control

## Emitida cuando el usuario cierra el visor.
signal closed

## Lienzo donde se dibuja el mapa base (se dibuja una sola vez).
var _map_canvas: Control = null
## Capa ligera solo para el marcador pulsante del jugador.
var _pin_canvas: Control = null
## Fase de parpadeo del marcador del jugador.
var _pulse: float = 0.0
## Geometría del jugador en el lienzo
var _player_pin_center: Vector2 = Vector2.ZERO
var _player_cell_size: float = 8.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)
	if _pin_canvas != null and is_instance_valid(_pin_canvas):
		_pin_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	UiKit.premium_dialog_panel(panel, UiKit.theme_color("accent", UiKit.ACCENT), 26)
	center.add_child(panel)

	var margin := UiKit.margins(32, 32, 28, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# ── Cabecera ───────────────────────────────────────────────────────────────
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	title.text = "🗺️  " + Locale.pick({"es": "Mapa", "en": "Map"})
	vbox.add_child(title)

	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(div)

	# ── Lienzo del mapa ──────────────────────────────────────────────────────────
	_map_canvas = Control.new()
	_map_canvas.custom_minimum_size = Vector2(760, 520)
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.draw.connect(_draw_map)
	vbox.add_child(_map_canvas)

	# Capa ligera superpuesta para el jugador pulsante (coste CPU/GPU prácticamente cero)
	_pin_canvas = Control.new()
	_pin_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pin_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_canvas.draw.connect(_draw_player_pin)
	_map_canvas.add_child(_pin_canvas)

	# ── Botón cerrar ─────────────────────────────────────────────────────────────
	var btn_close := Button.new()
	btn_close.custom_minimum_size = Vector2(0, 68)
	btn_close.add_theme_font_size_override("font_size", 24)
	btn_close.text = Locale.t("menu_back")
	btn_close.pressed.connect(func() -> void: closed.emit())
	vbox.add_child(btn_close)


# ══════════════════════════════════════════════════════════════════════════════
# DIBUJADO DEL MAPA
# ══════════════════════════════════════════════════════════════════════════════
func _draw_map() -> void:
	var explored: Dictionary = GlobalState.explored_coords
	if explored.is_empty():
		var font := get_theme_default_font()
		var msg := Locale.pick({"es": "Aún no has explorado nada.", "en": "You haven't explored anything yet."})
		var ms := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
		_map_canvas.draw_string(font, _map_canvas.size * 0.5 - ms * 0.5, msg,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.TEXT_DIM)
		return

	# 1) Límites (bounding box) de lo explorado para encuadrar y escalar.
	var min_x := 1 << 30
	var min_y := 1 << 30
	var max_x := -(1 << 30)
	var max_y := -(1 << 30)
	for coord in explored.keys():
		var c: Vector2i = coord
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
		max_x = maxi(max_x, c.x)
		max_y = maxi(max_y, c.y)
	# Margen de una casilla alrededor.
	min_x -= 1; min_y -= 1; max_x += 1; max_y += 1

	var cols := max_x - min_x + 1
	var rows := max_y - min_y + 1
	var cell := minf(_map_canvas.size.x / float(cols), _map_canvas.size.y / float(rows))
	cell = maxf(cell, 3.0)
	# Centrar la rejilla en el lienzo.
	var grid_w := cell * cols
	var grid_h := cell * rows
	var origin := (_map_canvas.size - Vector2(grid_w, grid_h)) * 0.5

	# 2) Casillas descubiertas coloreadas por bioma.
	for coord in explored.keys():
		var c: Vector2i = coord
		var r := _cell_rect(c, min_x, min_y, cell, origin)
		var col := _cell_color(c)
		_map_canvas.draw_rect(r.grow(-0.5), col, true)

	# 3) Marcadores de puntos de interés (ciudades, mazmorras, campamento, recursos).
	for coord in explored.keys():
		var c: Vector2i = coord
		var glyph := _poi_glyph(c)
		if glyph == "":
			continue
		var r := _cell_rect(c, min_x, min_y, cell, origin)
		_draw_glyph(glyph, r.get_center(), maxf(cell * 0.8, 12.0))

	# 4) Guardar coordenadas para la capa ligera del jugador
	var pp: Vector2i = GlobalState.player_pos
	var pr := _cell_rect(pp, min_x, min_y, cell, origin)
	_player_pin_center = pr.get_center()
	_player_cell_size = cell


func _draw_player_pin() -> void:
	if _player_cell_size <= 0.0 or _player_pin_center == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(_pulse)
	_pin_canvas.draw_arc(_player_pin_center, _player_cell_size * 0.55 + 2.0 * pulse, 0.0, TAU, 24,
		Color(1.0, 0.95, 0.4, 0.5 + 0.4 * pulse), 2.5, true)
	_pin_canvas.draw_circle(_player_pin_center, maxf(_player_cell_size * 0.32, 3.0), Color(1.0, 0.95, 0.4))


## Rectángulo en coordenadas de lienzo para la casilla `c`.
func _cell_rect(c: Vector2i, min_x: int, min_y: int, cell: float, origin: Vector2) -> Rect2:
	var x := origin.x + float(c.x - min_x) * cell
	var y := origin.y + float(c.y - min_y) * cell
	return Rect2(x, y, cell, cell)


## Color de bioma de la casilla (o gris tenue si no hay CellResource).
func _cell_color(c: Vector2i) -> Color:
	var cell: CellResource = GlobalState.hexagons_db.get(c, null) as CellResource
	if cell == null:
		return Color(0.16, 0.17, 0.2, 0.85)
	var col: Color = cell.biome_color
	# Aclarar un poco para que se distinga del fondo oscuro del panel.
	return col.lightened(0.12)


const TERRAIN_ICONS: Array[String] = [
	"🌱", "🌾", "🌿", "🍀",
	"❄️", "🧊", "⛄",
	"🏔️", "⛰️", "🪨",
	"🌊", "💧", "🏖️", "🏝️",
	"🏜️", "🌵",
	"🌋",
	"🌲", "🪵", "⛏️", "🪙", "🐄", "🐟"
]


static func _is_terrain_icon(glyph: String) -> bool:
	return glyph in TERRAIN_ICONS


## Glifo del punto de interés en la casilla, o "" si no hay ninguno relevante.
## Solo muestra icono para Ciudades, POI, Mazmorras y Base del jugador.
## Las casillas de terreno sin items (nieve, montaña, agua...) se representan
## limpiamente solo con el color del cuadrado sin emoticono.
func _poi_glyph(c: Vector2i) -> String:
	var cell: CellResource = GlobalState.hexagons_db.get(c, null) as CellResource
	if cell == null:
		return ""

	# 1) Base del jugador / campamento / hoguera
	if cell.resource == "base":
		return "⛺"
	if cell.resource == "campfire":
		return "🔥"

	var eid := cell.event_id.to_lower().strip_edges()
	var item := cell.item.to_lower().strip_edges()
	var has_interactive: bool = cell.interactive is Dictionary and not cell.interactive.is_empty()

	# Si no tiene ni evento, ni item, ni objeto interactivo, es terreno simple: sin icono
	if eid == "" and item == "" and not has_interactive:
		return ""

	# 2) Mazmorras y Templos / Senderos
	if eid.begins_with("dun_") or item == "cueva":
		return "🕳️"
	if eid.begins_with("sendero_") or eid.begins_with("poi_temple_") or item == "templo":
		return "⛩️"

	# 3) Ciudades y Aldeas
	if eid.begins_with("city_") or item in ["ciudad", "aldea"]:
		return "🏛️"

	# 4) Puntos de Interés (POIs), Casas, Tumbas, Ruinas, Infraestructuras
	if eid.begins_with("poi_tumba") or item == "poi_tumba":
		return "🪦"
	if eid.begins_with("house_") or item == "casita":
		var custom_ic := cell.icon.strip_edges()
		if custom_ic != "" and custom_ic != "none" and not _is_terrain_icon(custom_ic):
			return custom_ic
		return "🏠"
	if eid.begins_with("npc_"):
		return "👤"
	if item == "ruinas":
		return "🏚️"
	if item == "presa" or eid == "poi_presa_001":
		return "🚧"
	if item == "puente" or eid == "poi_monkey_001":
		return "🌉"
	if item == "puerto" or eid.ends_with("_puerto") or eid.begins_with("poi_port"):
		return "⚓"

	# Objeto interactivo inline
	if has_interactive:
		var kind: String = String(cell.interactive.get("kind", ""))
		if kind == "tomb":
			return "🪦"
		if kind == "sign":
			return "🪧"
		return "📍"

	# Icono personalizado explícito para un POI / item (si no es un icono genérico de terreno)
	var ic := cell.icon.strip_edges()
	if ic != "" and ic != "none" and not _is_terrain_icon(ic):
		return ic

	if item == "place" or (eid.begins_with("poi_") and not eid.is_empty()):
		return "📍"

	return ""


## Dibuja un glifo centrado en `pos`.
func _draw_glyph(glyph: String, pos: Vector2, fsize: float) -> void:
	var font := get_theme_default_font()
	var fs := int(clampf(fsize, 12.0, 26.0))
	var gs := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	_map_canvas.draw_string(font, pos - gs * 0.5 + Vector2(0, gs.y * 0.35), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))


## Cierra el visor al tocar el fondo oscuro (fuera del panel).
func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		closed.emit()
