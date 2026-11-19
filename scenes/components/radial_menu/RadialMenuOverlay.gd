# RadialMenuOverlay.gd
# Menú Radial Rápido Diegético (TAB / "º" / Gamepad L1).
# Proporciona acceso instantáneo en 1 clic a todas las funciones del juego
# (Inventario, Personaje, Diario, Habilidades, Mapa, Esfera) sin detener la vista 3D.
class_name RadialMenuOverlay
extends Control

signal action_selected(action_id: String)
signal closed

var _root: Control
var _dim_bg: ColorRect
var _wheel_container: Control
var _center_btn: Button
var _buttons: Array[Button] = []
var _is_open: bool = false
var _closing: bool = false

## Radio del círculo del menú radial
const RADIUS: float = 235.0
## 5 opciones únicas 1:1 con las 5 pestañas del Hub de
## Personaje (`CharacterHubModal.TABS`). Antes había 7 botones (stats/equip/
## facetas apuntaban los tres a la misma pestaña "character").
## El atajo de teclado ya no va concatenado en el propio
## texto del botón (competía visualmente con el nombre); ahora es un campo
## `key` aparte que se dibuja como una insignia pequeña en la esquina del botón.
## Añadida "Equipo" — ahora son 6 opciones 1:1 con las 6 pestañas
## de `CharacterHubModal.TABS`.
const ACTIONS: Array[Dictionary] = [
	{"id": "character",   "icon": "👤", "name_es": "Personaje",     "name_en": "Character",     "key": "C"},
	{"id": "equip",       "icon": "🛡️", "name_es": "Equipo",       "name_en": "Equipment",     "key": "E"},
	{"id": "bag",         "icon": "🎒", "name_es": "Inventario",    "name_en": "Inventory",     "key": "I"},
	{"id": "professions", "icon": "⚔️", "name_es": "Profesiones",   "name_en": "Professions",   "key": "K"},
	{"id": "journal",     "icon": "📜", "name_es": "Diario & Lore", "name_en": "Journal & Lore","key": "J"},
	{"id": "options",     "icon": "⚙️", "name_es": "Opciones",      "name_en": "Options",       "key": "ESC"},
]


func _ready() -> void:
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _root == null:
		_build_ui()
	visible = _is_open
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_positions)
	# Repintar el radial con el tema activo. Solo reconstruye
	# si está cerrado (si está abierto, se aplica en el próximo open() para no
	# interrumpir la animación/interacción en curso).
	Locale.theme_changed.connect(func(_id: String) -> void:
		if not is_open():
			_build_ui()
	)


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_root = Control.new()
	_root.name = "RootContainer"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Fondo oscurecido tenue semitransparente (backdrop). NO
	# se aplica el shader de blur pedido en la spec: el proyecto usa el renderer
	# "mobile" de Godot, con soporte limitado/nulo de SCREEN_TEXTURE en shaders
	# canvas_item 2D, y no hay forma de verificarlo sin un binario de Godot a
	# mano; el riesgo de romper el render no compensa un efecto puramente
	# cosmético. Mantenemos el scrim semitransparente (mapa 3D visible al fondo).
	_dim_bg = ColorRect.new()
	_dim_bg.name = "DimBg"
	_dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_bg.color = Color(0.02, 0.03, 0.05, 0.5)
	_dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_bg.gui_input.connect(_on_dim_input)
	_root.add_child(_dim_bg)

	# Contenedor central del menú radial
	_wheel_container = Control.new()
	_wheel_container.name = "WheelContainer"
	_wheel_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wheel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_wheel_container)

	# Botón central (cerrar)
	_center_btn = Button.new()
	_center_btn.custom_minimum_size = Vector2(90, 90)
	_center_btn.text = "X"
	_center_btn.add_theme_font_size_override("font_size", 32)
	_center_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_center_btn.focus_mode = Control.FOCUS_NONE

	var center_style := StyleBoxFlat.new()
	center_style.bg_color = UiKit.theme_color("panel_glass", Color(0.06, 0.08, 0.14, 0.92))
	center_style.border_color = UiKit.theme_color("accent", Color(0.32, 0.62, 0.98, 0.8))
	center_style.set_border_width_all(2)
	center_style.set_corner_radius_all(45)
	center_style.shadow_color = Color(0, 0, 0, 0.6)
	center_style.shadow_size = 10
	_center_btn.add_theme_stylebox_override("normal", center_style)
	_center_btn.pressed.connect(close)
	_wheel_container.add_child(_center_btn)

	# Crear las opciones dispuestas circularmente (ver ACTIONS)
	_buttons.clear()
	var count := ACTIONS.size()
	for i in range(count):
		var act := ACTIONS[i]
		var btn := Button.new()
		# Formato cuadrado y cómodo para pulsación táctil con el dedo
		btn.custom_minimum_size = Vector2(140, 135)
		var label_text: String = Locale.pick({"es": act["name_es"], "en": act["name_en"]})
		btn.text = "%s\n%s" % [act["icon"], label_text]
		btn.add_theme_font_size_override("font_size", 18)
		btn.focus_mode = Control.FOCUS_NONE

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = UiKit.theme_color("panel_glass", Color(0.04, 0.06, 0.12, 0.90))
		btn_style.border_color = UiKit.theme_color("accent", Color(0.32, 0.62, 0.98, 0.5))
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(16)
		btn_style.shadow_color = Color(0, 0, 0, 0.5)
		btn_style.shadow_size = 8
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style := btn_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = UiKit.theme_color("panel_bg", Color(0.08, 0.16, 0.28, 0.95)).lightened(0.08)
		hover_style.border_color = UiKit.theme_color("highlight", Color(0.98, 0.80, 0.32, 0.9))
		btn.add_theme_stylebox_override("hover", hover_style)

		# NOTA: se eliminó la insignia con la tecla de acceso rápido de PC
		# ("(C)", "(I)"...) — el objetivo prioritario del juego es móvil táctil,
		# donde esas etiquetas solo ensucian la interfaz sin aportar nada
		# (ver task_bugs_observados.md §1.3). Los atajos de teclado en PC siguen
		# funcionando igual, solo se retiró la insignia visual.

		var act_id: String = String(act["id"])
		btn.pressed.connect(func() -> void: _on_button_pressed(act_id))
		_wheel_container.add_child(btn)
		_buttons.append(btn)

	_update_positions()


func _update_positions() -> void:
	if _root == null or _wheel_container == null:
		return
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = Vector2(DisplayServer.window_get_size())
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = Vector2(1920.0, 1080.0)

	var screen_center := sz * 0.5

	if _center_btn != null:
		_center_btn.position = screen_center - Vector2(45, 45)

	var count := _buttons.size()
	for i in range(count):
		var angle := -PI * 0.5 + float(i) * (TAU / float(count))
		var offset := Vector2(cos(angle), sin(angle)) * RADIUS
		var btn := _buttons[i]
		var btn_sz := btn.custom_minimum_size if btn.custom_minimum_size.x > 0 else Vector2(140, 135)
		btn.position = screen_center + offset - btn_sz * 0.5


func is_open() -> bool:
	return _is_open and visible


func open() -> void:
	if _root == null:
		_build_ui()
	_closing = false
	_is_open = true
	visible = true
	_update_positions()
	call_deferred("_update_positions")
	if _root != null:
		if Locale.reduce_motion:
			_root.modulate = Color.WHITE
			_root.scale = Vector2.ONE
		else:
			_root.pivot_offset = get_viewport_rect().size * 0.5
			_root.scale = Vector2(0.85, 0.85)
			_root.modulate = Color.TRANSPARENT
			var tw := _root.create_tween().set_parallel(true)
			tw.tween_property(_root, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(_root, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if AudioManager != null:
		AudioManager.play_sfx("click")


func close() -> void:
	if _closing:
		return
	_closing = true
	_is_open = false
	if _root != null and not Locale.reduce_motion:
		_root.pivot_offset = get_viewport_rect().size * 0.5
		var tw := _root.create_tween().set_parallel(true)
		tw.tween_property(_root, "scale", Vector2(0.85, 0.85), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(_root, "modulate", Color.TRANSPARENT, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void:
			visible = false
			_closing = false
			closed.emit()
		)
	else:
		visible = false
		_closing = false
		closed.emit()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var sz := get_viewport_rect().size
		var center := sz * 0.5
		if event.position.distance_to(center) > RADIUS + 70.0:
			get_viewport().set_input_as_handled()
			close()


func _on_button_pressed(act_id: String) -> void:
	get_viewport().set_input_as_handled()
	if AudioManager != null:
		AudioManager.play_sfx("click")
	close()
	action_selected.emit(act_id)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()
