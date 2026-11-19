# ExplorationHud.gd
# ─────────────────────────────────────────────────────────────────────────────
# HUD DE HABILIDADES DE EXPLORACIÓN
#
# Distribución de las 6 HABILIDADES DE EXPLORACIÓN (una por profesión) en una
# REJILLA COMPACTA de 2 filas x 3 columnas anclada a la esquina INFERIOR
# DERECHA de la pantalla (horizontal/tablet apaisado; en vertical se mantiene
# la misma rejilla centrada, ver `_layout_grid_portrait`).
#
#   · Grupo único y compacto, alcanzable con el pulgar derecho sin desplazar
#     la mano, con un margen de seguridad respecto a ambos bordes y separado
#     del resto del HUD (joystick a la izquierda, minimapa/controles arriba).
#   · Se visualizan exactamente 6 botones circulares (ExplorationSkillButton),
#     mostrando su estado de desbloqueo (candado 🔒 al inicio), enfriamiento,
#     halo de listo y energía.
# ─────────────────────────────────────────────────────────────────────────────
class_name ExplorationHud
extends Control

## Emitida al pulsar el botón de menú de opciones/pausa
signal menu_pressed()

## Geometría de la cuadrícula de 2x3 botones (en coordenadas del viewport).
const BUTTON_DIAMETER := 114.0
const BUTTON_SPACING_X := 16.0
const BUTTON_SPACING_Y := 12.0
const CENTER_INSET_Y := 185.0
## Margen de seguridad respecto a los bordes derecho/inferior en horizontal.
const EDGE_MARGIN_X := 40.0
const EDGE_MARGIN_Y := 36.0

## Glifos por habilidad.
const SKILL_GLYPH := {
	"kinetic_wave": "💥",
	"psychic_grab": "🧲",
	"time_distort": "⏳",
	"explorer_instinct": "👁",
	"elemental_affinity": "🌀",
	"restoration": "✨",
}

var controller: ExplorationSkillController = null

var _ring_root: Control = null
var _buttons: Dictionary = {}   # skill_id -> ExplorationSkillButton
var _energy_bar: ProgressBar = null

## Contenedor superior derecho y botón de menú de opciones/pausa (task1_botonMenu)
var top_right_container: VBoxContainer = null
var btn_menu: Button = null
var menu_button: Button = null
## Verbos que acepta el objeto actualmente apuntado (para resaltar sus botones).
var _target_verbs: PackedStringArray = PackedStringArray()
## Id de la habilidad resaltada por el tutorial de mazmorra y tiempo restante (s).
var _tutorial_highlight_id: String = ""
var _tutorial_highlight_time: float = 0.0

## Mira/retícula central: aparece siempre como punto tenue y, al apuntar a un
## objeto compatible, se ilumina y muestra el glifo de la(s) habilidad(es) que
## tendrían efecto. Enseña a jugar sin texto (Filosofía Visual).
var _reticle: Control = null
var _reticle_pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	Locale.accessibility_changed.connect(_layout)
	_layout()


## Enlaza el HUD a su controller (lo llama la vista/escena que instancia todo).
func bind(ctrl: ExplorationSkillController) -> void:
	controller = ctrl
	if controller != null:
		if not controller.element_changed.is_connected(_on_element_changed):
			controller.element_changed.connect(_on_element_changed)
		if not controller.target_changed.is_connected(_on_target_changed):
			controller.target_changed.connect(_on_target_changed)
		if not controller.skill_failed.is_connected(_on_skill_failed):
			controller.skill_failed.connect(_on_skill_failed)
		if not controller.skill_used.is_connected(_on_skill_used):
			controller.skill_used.connect(_on_skill_used)
		_on_element_changed(controller.current_element)
	_refresh_static()


# ── Construcción ─────────────────────────────────────────────────────────────
func _build() -> void:
	_ring_root = Control.new()
	_ring_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring_root)

	# Botones de habilidades, exactamente 6
	var ids := ExplorationSkills.all_ids()
	for i in range(ids.size()):
		var id: String = String(ids[i])
		var btn := ExplorationSkillButton.new()
		var skill_def := ExplorationSkills.get_skill(id)
		var col: Color = skill_def.get("color", Color(0.6, 0.6, 0.6))
		var icon_path: String = String(skill_def.get("icon", ""))
		btn.setup(id, col, String(SKILL_GLYPH.get(id, "?")), BUTTON_DIAMETER, icon_path)
		btn.activated.connect(_on_skill_activated)
		_ring_root.add_child(btn)
		_buttons[id] = btn

	# Barra de energía disimulada encima de la fila horizontal en modo apaisado
	_energy_bar = ProgressBar.new()
	_energy_bar.show_percentage = false
	_energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var en_fill := StyleBoxFlat.new()
	en_fill.bg_color = Color("22c55e")
	en_fill.set_corner_radius_all(6)
	_energy_bar.add_theme_stylebox_override("fill", en_fill)

	var en_bg := StyleBoxFlat.new()
	en_bg.bg_color = UiKit.BG_DEEP
	en_bg.set_corner_radius_all(6)
	en_bg.set_border_width_all(1)
	en_bg.border_color = UiKit.BORDER
	_energy_bar.add_theme_stylebox_override("background", en_bg)
	_ring_root.add_child(_energy_bar)

	# Mira/retícula al centro de la pantalla (sobre el punto que apunta la cámara).
	_reticle = Control.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.custom_minimum_size = Vector2(140, 140)
	_reticle.size = Vector2(140, 140)
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)

	# Contenedor superior derecho para minimapa y botón de menú (task1_botonMenu)
	top_right_container = VBoxContainer.new()
	top_right_container.name = "TopRightContainer"
	top_right_container.mouse_filter = Control.MOUSE_FILTER_PASS
	top_right_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right_container.grow_vertical = Control.GROW_DIRECTION_END
	top_right_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_right_container.add_theme_constant_override("separation", 12)
	add_child(top_right_container)

	btn_menu = Button.new()
	btn_menu.name = "BtnMenu"
	btn_menu.text = ""
	btn_menu.tooltip_text = "Menú de personaje"
	btn_menu.custom_minimum_size = Vector2(64.0, 64.0)
	btn_menu.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_menu.draw.connect(_draw_btn_menu_hamburger)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.08, 0.06, 0.12, 0.88)
	btn_sb.set_corner_radius_all(10)
	btn_sb.set_border_width_all(2)
	btn_sb.border_color = Color(0.55, 0.35, 0.9, 0.7)
	btn_sb.content_margin_left = 12
	btn_sb.content_margin_right = 12
	btn_sb.content_margin_top = 8
	btn_sb.content_margin_bottom = 8
	btn_menu.add_theme_stylebox_override("normal", btn_sb)

	var btn_sb_hover := btn_sb.duplicate() as StyleBoxFlat
	btn_sb_hover.bg_color = Color(0.18, 0.12, 0.28, 0.95)
	btn_sb_hover.border_color = Color(0.75, 0.55, 1.0, 0.95)
	btn_menu.add_theme_stylebox_override("hover", btn_sb_hover)

	var btn_sb_press := btn_sb.duplicate() as StyleBoxFlat
	btn_sb_press.bg_color = Color(0.30, 0.18, 0.48, 1.0)
	btn_menu.add_theme_stylebox_override("pressed", btn_sb_press)

	btn_menu.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	btn_menu.add_theme_font_size_override("font_size", 30)
	btn_menu.pressed.connect(_on_menu_button_pressed)
	top_right_container.add_child(btn_menu)
	menu_button = btn_menu


func _draw_btn_menu_hamburger() -> void:
	if btn_menu == null or not is_instance_valid(btn_menu):
		return
	var sz := btn_menu.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var line_w: float = roundf(sz.x * 0.44)
	var line_h: float = maxf(2.5, roundf(sz.y * 0.055))
	var start_x: float = roundf((sz.x - line_w) * 0.5)
	var center_y: float = roundf(sz.y * 0.5)
	var spacing: float = roundf(sz.y * 0.16)
	var col := Color(0.85, 0.65, 1.0)
	btn_menu.draw_rect(Rect2(start_x, center_y - spacing - line_h * 0.5, line_w, line_h), col, true)
	btn_menu.draw_rect(Rect2(start_x, center_y - line_h * 0.5, line_w, line_h), col, true)
	btn_menu.draw_rect(Rect2(start_x, center_y + spacing - line_h * 0.5, line_w, line_h), col, true)


## Recoloca los 6 botones en una REJILLA de 2 filas x 3 columnas: anclada a la
## esquina inferior derecha en Landscape (Fase 6, `docs/tasks/task2.md`:
## sustituye al abanico de 2 arcos anterior por petición explícita de una
## disposición en rejilla compacta, ergonómica para el pulgar derecho en
## móvil/tablet apaisado) y centrada en la parte inferior en Portrait.
func _layout() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = get_viewport_rect().size
	var is_landscape := sz.x > sz.y
	var ids := ExplorationSkills.all_ids()
	var count := ids.size()

	if is_landscape:
		_layout_grid_landscape(sz, ids, count)
	else:
		_layout_grid_portrait(sz, ids, count)

	# Centrar la retícula en el centro del viewport.
	if _reticle != null:
		_reticle.position = sz * 0.5 - _reticle.size * 0.5

	# Anclaje del contenedor superior derecho (minimapa + botón menú) pegado al margen derecho con 16px
	if top_right_container != null and is_instance_valid(top_right_container):
		const MARGIN_RIGHT := 16.0
		const MARGIN_TOP := 16.0
		var tr_w: float = maxf(top_right_container.size.x, top_right_container.get_combined_minimum_size().x)
		top_right_container.position = Vector2(sz.x - tr_w - MARGIN_RIGHT, MARGIN_TOP)


## Distribución en cuadrícula de 2 filas x 3 columnas anclada a la esquina
## INFERIOR DERECHA (horizontal/tablet apaisado): grupo único y compacto,
## alcanzable con el pulgar derecho sin desplazar la mano, con un margen de
## seguridad (`EDGE_MARGIN_X`/`EDGE_MARGIN_Y`) respecto a ambos bordes y
## suficientemente alejado del resto del HUD (joystick/minimapa) para
## identificarse de inmediato como el grupo de habilidades.
func _layout_grid_landscape(sz: Vector2, ids: Array, count: int) -> void:
	var cols := 3
	var rows := int(ceil(float(count) / float(cols)))
	var grid_width := cols * BUTTON_DIAMETER + (cols - 1) * BUTTON_SPACING_X
	var grid_height := rows * BUTTON_DIAMETER + (rows - 1) * BUTTON_SPACING_Y
	# Pivote = centro de la rejilla, con su esquina inferior derecha a
	# EDGE_MARGIN_X/Y px de los bordes de la pantalla.
	var pivot := Vector2(
		sz.x - EDGE_MARGIN_X - grid_width * 0.5,
		sz.y - EDGE_MARGIN_Y - grid_height * 0.5,
	)
	_ring_root.position = pivot

	var start_x := -grid_width * 0.5
	var start_y := -grid_height * 0.5
	for i in range(count):
		var id: String = String(ids[i])
		var btn: ExplorationSkillButton = _buttons.get(id)
		if btn == null:
			continue
		# Horizontal NUNCA se toca: siempre al diámetro base (por si venimos de retrato).
		btn.set_diameter(BUTTON_DIAMETER)
		var col := i % cols
		var row: int = int(float(i) / float(cols))
		var x_pos := start_x + col * (BUTTON_DIAMETER + BUTTON_SPACING_X)
		var y_pos := start_y + row * (BUTTON_DIAMETER + BUTTON_SPACING_Y)
		btn.position = Vector2(x_pos, y_pos)

	if _energy_bar != null:
		_energy_bar.visible = true
		_energy_bar.custom_minimum_size = Vector2(grid_width, 14.0)
		_energy_bar.size = Vector2(grid_width, 14.0)
		_energy_bar.position = Vector2(start_x, start_y - 26.0)


## Distribución en cuadrícula de 2 filas x 3 columnas, centrada en la parte
## inferior — se mantiene para vertical (una mano sola, alcance vertical
## corto: la cuadrícula compacta ya es ergonómica ahí).
func _layout_grid_portrait(sz: Vector2, ids: Array, count: int) -> void:
	# BOOST VERTICAL (mismo factor 2.1x que GameRoot/TabWorld3D): los botones
	# quedaban diminutos en retrato porque `window/stretch/aspect=expand` no
	# amplía el ancho lógico al rotar, solo el alto.
	var boost := 2.1
	var cols := 3
	var rows := int(ceil(float(count) / float(cols)))
	var d := BUTTON_DIAMETER * boost
	var sx := BUTTON_SPACING_X * boost
	var sy := BUTTON_SPACING_Y * boost
	var grid_width := cols * d + (cols - 1) * sx
	var grid_height := rows * d + (rows - 1) * sy
	var center := Vector2(sz.x * 0.5, sz.y - CENTER_INSET_Y * boost)
	_ring_root.position = center

	var start_x := -grid_width * 0.5
	var start_y := -grid_height * 0.5

	for i in range(count):
		var id: String = String(ids[i])
		var btn: ExplorationSkillButton = _buttons.get(id)
		if btn == null:
			continue
		btn.set_diameter(d)
		var col := i % cols
		var row: int = int(float(i) / float(cols))
		var x_pos := start_x + col * (d + sx)
		var y_pos := start_y + row * (d + sy)
		btn.position = Vector2(x_pos, y_pos)

	if _energy_bar != null:
		_energy_bar.visible = false


# ── Actualización por frame ──────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _energy_bar != null and _energy_bar.visible and GlobalState != null:
		_energy_bar.max_value = GlobalState.max_energy
		_energy_bar.value = GlobalState.energy

	if controller == null:
		return

	if _tutorial_highlight_time > 0.0:
		_tutorial_highlight_time -= delta
		if _tutorial_highlight_time <= 0.0:
			_tutorial_highlight_id = ""

	for id in _buttons.keys():
		var btn: ExplorationSkillButton = _buttons[id]
		var unlocked: bool = ExplorationSkills.is_unlocked(id)
		var cd: float = ExplorationSkills.cooldown(id)
		var cd_left: float = controller.cooldown_left(id)
		var cd_ratio: float = (cd_left / cd) if cd > 0.0 else 0.0
		var active: bool = controller.is_toggled(id)
		var target_match: bool = _target_verbs.has(ExplorationSkills.verb(id))
		var tutorial_highlight: bool = _tutorial_highlight_time > 0.0 and id == _tutorial_highlight_id
		btn.set_state(unlocked, controller.is_ready(id), cd_ratio, cd_left, active, target_match, tutorial_highlight)

	# Pulso de la retícula mientras se apunta a un objeto compatible.
	if _reticle != null and not _target_verbs.is_empty():
		_reticle_pulse = fmod(_reticle_pulse + delta * 3.0, TAU)
		_reticle.queue_redraw()


func _refresh_static() -> void:
	if not is_node_ready():
		return
	_layout()


## El controller informa de qué verbos acepta el objeto apuntado (o vacío). Se
## guardan para que `_process` resalte los botones cuya habilidad casa.
func _on_target_changed(accepted_verbs: PackedStringArray) -> void:
	_target_verbs = accepted_verbs
	if _reticle != null:
		_reticle.queue_redraw()


## Resalta la habilidad indicada durante un tiempo. La usa ViewDungeon para el
## tutorial de dun_inicial: cuando la esfera avisa de un obstáculo, el botón del
## skill apropiado brilla más intensamente.
func set_tutorial_highlight(skill_id: String, duration: float = 5.0) -> void:
	if skill_id == "" or not ExplorationSkills.has_skill(skill_id):
		return
	_tutorial_highlight_id = skill_id
	_tutorial_highlight_time = duration


## Dibuja la mira: siempre un punto/crux tenue; al apuntar a un objeto compatible,
## un anillo del color de la habilidad + su glifo encima.
func _draw_reticle() -> void:
	var c := _reticle.size * 0.5
	var has_target := not _target_verbs.is_empty()
	var skills := _skills_for_verbs(_target_verbs)
	var col := Color(1, 1, 1, 0.85)
	if not skills.is_empty():
		col = ExplorationSkills.get_skill(skills[0]).get("color", col)

	if not has_target:
		# Punto neutro pequeño (ayuda de apuntado).
		_reticle.draw_circle(c, 3.0, Color(1, 1, 1, 0.45))
		return

	# Anillo pulsante del color de la habilidad compatible.
	var pulse := 0.5 + 0.5 * sin(_reticle_pulse)
	var radius := 13.0 + 3.0 * pulse
	var ring := Color(col.r, col.g, col.b, 0.55 + 0.35 * pulse)
	_reticle.draw_arc(c, radius, 0.0, TAU, 40, ring, 2.5, true)
	_reticle.draw_circle(c, 2.5, Color(1, 1, 1, 0.9))

	# Glifo(s) de la(s) habilidad(es) que tendrían efecto, encima de la mira.
	if skills.is_empty():
		return
	var font := get_theme_default_font()
	var fsize := 34
	var glyphs := ""
	for sid in skills:
		glyphs += String(SKILL_GLYPH.get(sid, "?")) + " "
	glyphs = glyphs.strip_edges()
	var gs := font.get_string_size(glyphs, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	var gp := c + Vector2(-gs.x * 0.5, -radius - 12.0)
	_reticle.draw_string(font, gp, glyphs, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.95))


## Ids de habilidades DESBLOQUEADAS cuyo verbo está entre `verbs` (para glifo/color).
func _skills_for_verbs(verbs: PackedStringArray) -> Array:
	var out: Array = []
	if verbs.is_empty():
		return out
	for id in ExplorationSkills.all_ids():
		if verbs.has(ExplorationSkills.verb(id)) and ExplorationSkills.is_unlocked(id):
			out.append(id)
	return out


func _on_element_changed(element: String) -> void:
	var btn: ExplorationSkillButton = _buttons.get("elemental_affinity")
	if btn != null:
		if element == "":
			btn.glyph = SKILL_GLYPH.get("elemental_affinity", "🌀")
			btn.base_color = Color(0.55, 0.75, 0.92)
			btn.icon_texture = UiKit.load_texture_safe("res://assets/dungeon/skills/elemental_affinity.png")
		else:
			var elem_glyphs := {
				"fuego": "🔥",
				"hielo": "❄️",
				"rayo": "⚡",
				"agua": "💧",
				"viento": "🌪️",
				"tierra": "🪨"
			}
			var elem_colors := {
				"fuego": Color(1.0, 0.35, 0.1),
				"hielo": Color(0.3, 0.8, 1.0),
				"rayo": Color(0.95, 0.9, 0.2),
				"agua": Color(0.2, 0.6, 1.0),
				"viento": Color(0.4, 0.9, 0.7),
				"tierra": Color(0.7, 0.5, 0.3)
			}
			btn.glyph = String(elem_glyphs.get(element, "🔥"))
			btn.base_color = Color(elem_colors.get(element, Color(1.0, 0.35, 0.1)))
			btn.icon_texture = null
		btn.queue_redraw()


func _on_skill_activated(skill_id: String) -> void:
	if controller == null:
		return
	controller.try_use(skill_id)


func _on_skill_failed(skill_id: String, reason: String) -> void:
	var btn: ExplorationSkillButton = _buttons.get(skill_id, null)
	if btn != null and is_instance_valid(btn):
		UiKit.pop(btn, 1.08, 0.15)

	match reason:
		"energy":
			AudioManager.play_sfx("skill_purificacion")
			if _energy_bar:
				Juice.flash(_energy_bar, UiKit.HP, 0.3)
			UiKit.toast(self, "⚡ " + Locale.pick({"es": "Energía insuficiente", "en": "Not enough energy"}), UiKit.WARN)
		"cooldown":
			AudioManager.play_sfx("click")
		"no_target":
			AudioManager.play_sfx("skill_purificacion")
			UiKit.toast(self, "🎯 " + Locale.pick({"es": "Sin objetivo al alcance", "en": "No target in range"}), UiKit.TEXT_DIM)
		"locked":
			AudioManager.play_sfx("click")
			UiKit.toast(self, "🔒 " + Locale.pick({"es": "Habilidad no desbloqueada", "en": "Skill locked"}), UiKit.TEXT_FAINT)


func _on_skill_used(skill_id: String) -> void:
	var btn: ExplorationSkillButton = _buttons.get(skill_id, null)
	if btn != null and is_instance_valid(btn):
		UiKit.pop(btn, 1.15, 0.18)


func _on_menu_button_pressed() -> void:
	menu_pressed.emit()
	var root: Node = get_tree().get_first_node_in_group("game_root")
	if root != null and root.has_method("open_hub_modal_tab"):
		root.open_hub_modal_tab("character")
	else:
		SceneManager.switch_tab("character")


## Añade el nodo del minimapa al contenedor superior derecho para alinearlo verticalmente con el botón de menú.
func add_minimap(minimap_node: Control) -> void:
	if top_right_container == null or minimap_node == null:
		return
	if minimap_node.get_parent() != null:
		minimap_node.get_parent().remove_child(minimap_node)
	top_right_container.add_child(minimap_node)
	top_right_container.move_child(minimap_node, 0)
	_layout()


## ¿El punto (en coordenadas de viewport) cae sobre cualquier botón de habilidad o menú?
## La vista lo usa para NO arrancar el joystick de movimiento sobre los botones,
## permitiendo así lanzar el joystick desde CUALQUIER otra zona libre (izquierda o derecha).
func blocks_joystick_point(p: Vector2) -> bool:
	if btn_menu != null and is_instance_valid(btn_menu) and btn_menu.is_visible_in_tree():
		if btn_menu.get_global_rect().has_point(p):
			return true
	if top_right_container != null and is_instance_valid(top_right_container) and top_right_container.is_visible_in_tree():
		if top_right_container.get_global_rect().has_point(p):
			return true
	for id in _buttons.keys():
		var btn: Control = _buttons[id]
		if btn != null and btn.get_global_rect().has_point(p):
			return true
	return false
