# NarrativeOverlay.gd
# ─────────────────────────────────────────────────────────────────────────────
# Autoload (CanvasLayer) — VISTA UNIFICADA DEL SISTEMA NARRATIVO.
#
# Es la ÚNICA presentación de toda la narrativa del juego: conversaciones,
# carteles, libros, tutoriales, introducciones, cinemáticas, recuerdos, finales...
# Sustituye al antiguo DialoguePopup y a la reproducción ad-hoc de cinemáticas.
#
# No conoce la lógica de las escenas: solo DIBUJA lo que el SceneRunner le pide a
# través de señales y le DEVUELVE el control (advance / choose) cuando el jugador
# interactúa. Así narrativa (datos) y presentación (UI) quedan separadas.
#
# Expresividad (la tarea descarta múltiples retratos y potencia efectos): cada
# nodo `say` puede declarar un bloque `fx` con:
#   · speed   → velocidad del texto (multiplicador del typewriter).
#   · sfx     → sonido al aparecer.
#   · shake   → sacudida del panel (intensidad).
#   · zoom    → "pop" de escala del panel/retrato.
#   · glow    → resplandor del borde del panel.
#   · darken  → oscurecimiento del fondo [0,1].
#
# Construye su UI por código (sin .tscn) para ser un autoload autónomo y estar
# disponible por encima de cualquier vista (mundo, ciudad, mazmorra, combate).
# ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

const BASE_CHARS_PER_SEC: float = 45.0   # velocidad base del typewriter

var _root: Control
var _bg_rect: TextureRect
var _dim: ColorRect
var _panel: PanelContainer
var _portrait: Label
var _speaker: Label
var _text: RichTextLabel
var _hint: Label
var _choices_box: VBoxContainer
var _continue_box: HBoxContainer

# Banner de narración centrado (estilo cinemática, sin panel inferior).
var _banner: Label

# Estado del typewriter
var _typing: bool = false
var _typing_pause: float = 0.0
var _full_text: String = ""
var _reveal: float = 0.0
var _chars_per_sec: float = BASE_CHARS_PER_SEC
var _mode: String = ""   # "say" | "choice" | ""
var _auto_left: float = 0.0     # segundos restantes para auto-avance (0 = manual)
var _style: String = "box"      # "box" (panel inferior) | "banner" (narración centrada)
var _active_npc_id: String = ""
var _info_drawer: Control = null

# ─── SKIP / AUTO / HISTORIAL / INFO (control de lectura del jugador) ─────────
## Modo AUTO: tras revelarse el texto, avanza solo tras una breve pausa.
var _auto_mode: bool = false
## Modo SKIP: acelera el typewriter y encadena avances hasta la próxima decisión.
var _skip_mode: bool = false
## Segundos restantes para el auto-avance del modo AUTO del jugador (0 = inactivo).
var _auto_mode_left: float = 0.0
## Pausa entre líneas en modo AUTO (segundos) tras completar el texto.
const AUTO_MODE_DELAY: float = 1.4
## Historial de líneas mostradas: [{speaker, text}] (acotado a las últimas N).
var _history: Array[Dictionary] = []
const HISTORY_MAX: int = 60
# Controles de UI
var _ctrl_bar: HBoxContainer
var _btn_auto: Button
var _btn_skip: Button
var _btn_history: Button
var _btn_info: Button
var _history_overlay: Control
## Pulso de opacidad del hint "Toca para continuar".
var _hint_pulse_tween: Tween = null

## Modo atract/demo: cinemática de presentación en menú principal sin controles, se cancela al primer toque.
var attract_mode: bool = false
signal attract_interrupted


func _ready() -> void:
	# Por encima de todo y funcional aunque el árbol esté en pausa (cinemáticas).
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_all()
	# Suscripción al intérprete de escenas.
	SceneRunner.scene_started.connect(_on_scene_started)
	SceneRunner.scene_finished.connect(_on_scene_finished)
	SceneRunner.say_shown.connect(_on_say_shown)
	SceneRunner.choice_shown.connect(_on_choice_shown)
	GlobalEvents.subscribe("stat_increased", _on_stat_increased)
	get_viewport().size_changed.connect(_update_responsive_layout)
	if _root != null:
		_root.resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	Locale.theme_changed.connect(_on_theme_changed)


## repinta la caja de diálogo/nombre/pista y, si hay opciones
## visibles en ese instante, sus botones — sin reconstruir la UI (perdería el
## progreso del typewriter/la página actual).
func _on_theme_changed(_theme_id: String) -> void:
	if _panel != null:
		UiKit.premium_frame(_panel, {"pad": 0})
	if _speaker != null:
		_speaker.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	if _text != null:
		_text.add_theme_color_override("default_color", UiKit.theme_color("text", UiKit.TEXT))
	if _hint != null:
		_hint.add_theme_color_override("font_color", UiKit.theme_color("text_dim", UiKit.TEXT_FAINT))
	if _choices_box != null:
		for child in _choices_box.get_children():
			if child is Button:
				var btn := child as Button
				UiKit.premium_button(btn, {"disabled": btn.disabled})


func _update_responsive_layout() -> void:
	if _panel == null or _root == null:
		return
	var sz := _root.get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	var has_choices := _choices_box != null and _choices_box.get_child_count() > 0
	
	if is_landscape:
		_panel.anchor_left = 0.22
		_panel.anchor_right = 0.78
		_panel.anchor_top = 1.0
		_panel.anchor_bottom = 1.0
		_panel.offset_left = 0.0
		_panel.offset_right = 0.0
		_panel.offset_top = -340.0 if has_choices else -240.0
		_panel.offset_bottom = -25.0
		if _portrait != null:
			_portrait.add_theme_font_size_override("font_size", 48)
		if _speaker != null:
			_speaker.add_theme_font_size_override("font_size", 36)
		if _text != null:
			_text.custom_minimum_size = Vector2(0, 130)
			_text.add_theme_font_size_override("normal_font_size", 36)
	else:
		_panel.anchor_left = 0.0
		_panel.anchor_right = 1.0
		_panel.anchor_top = 1.0
		_panel.anchor_bottom = 1.0
		_panel.offset_left = 24.0
		_panel.offset_right = -24.0
		_panel.offset_top = -460.0 if has_choices else -340.0
		_panel.offset_bottom = -24.0
		if _portrait != null:
			_portrait.add_theme_font_size_override("font_size", 52)
		if _speaker != null:
			_speaker.add_theme_font_size_override("font_size", 38)
		if _text != null:
			_text.custom_minimum_size = Vector2(0, 130)
			_text.add_theme_font_size_override("normal_font_size", 38)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA UI
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Fondo opcional (imagen a pantalla completa) para diapositivas narrativas con
	# campo `bg`, p. ej. las de los finales. Va DETRÁS del oscurecedor `_dim`, que
	# lo atenúa para mantener el texto legible. Vacío/oculto por defecto.
	_bg_rect = TextureRect.new()
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.visible = false
	_root.add_child(_bg_rect)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.20)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	_root.add_child(_dim)

	# Panel inferior tipo novela visual (elevado para dar más espacio al texto).
	_panel = PanelContainer.new()
	UiKit.premium_frame(_panel, {"pad": 0})
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 20
	_panel.offset_right = -20
	_panel.offset_top = -210
	_panel.offset_bottom = -20
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.gui_input.connect(_on_dim_input)
	_root.add_child(_panel)

	var margin := UiKit.margins(24, 24, 16, 16)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	# Cabecera: retrato + nombre.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(header)
	_portrait = Label.new()
	_portrait.add_theme_font_size_override("font_size", 42)
	_portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(_portrait)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 36)
	_speaker.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(_speaker)

	# Cuerpo del texto (RichTextLabel).
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 95)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 36)
	_text.add_theme_color_override("default_color", UiKit.theme_color("text", UiKit.TEXT))
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_text)

	# Contenedor de opciones (choice).
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_choices_box)

	# Pie: pista de continuar (say).
	_continue_box = HBoxContainer.new()
	_continue_box.alignment = BoxContainer.ALIGNMENT_END
	_continue_box.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_continue_box)
	_hint = Label.new()
	_hint.text = Locale.pick({"es": "Toca para continuar", "en": "Tap to continue"})
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", UiKit.theme_color("text_dim", UiKit.TEXT_FAINT))
	_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	_continue_box.add_child(_hint)

	# Barra de control de lectura (arriba a la derecha): Auto · Skip · Historial.
	_ctrl_bar = HBoxContainer.new()
	_ctrl_bar.add_theme_constant_override("separation", 10)
	_ctrl_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_ctrl_bar.offset_left = -480
	_ctrl_bar.offset_right = -24
	_ctrl_bar.offset_top = 20
	_ctrl_bar.offset_bottom = 74
	_ctrl_bar.alignment = BoxContainer.ALIGNMENT_END
	_ctrl_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_ctrl_bar)
	_btn_auto = _make_ctrl_button(_on_toggle_auto)
	_ctrl_bar.add_child(_btn_auto)
	_btn_skip = _make_ctrl_button(_on_toggle_skip)
	_ctrl_bar.add_child(_btn_skip)
	_btn_history = _make_ctrl_button(_on_open_history)
	_ctrl_bar.add_child(_btn_history)
	_btn_info = _make_ctrl_button(_on_toggle_info)
	_ctrl_bar.add_child(_btn_info)
	_refresh_ctrl_labels()

	# Banner de narración centrado (estilo cinemática). Alternativo al panel.
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.custom_minimum_size = Vector2(760, 0)
	_banner.offset_left = -380.0
	_banner.offset_right = 380.0
	_banner.add_theme_font_size_override("font_size", 38)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 7)
	_banner.gui_input.connect(_on_dim_input)
	_banner.visible = false
	_root.add_child(_banner)


# ══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if _typing:
		if _typing_pause > 0.0:
			_typing_pause -= delta
			return
		_reveal += delta * _chars_per_sec
		var target = _active_text_label()
		var total := float(target.get_total_character_count())
		if _reveal >= total:
			_reveal = total
			_typing = false
			target.visible_characters = -1
			_show_continue_hint(true)
			_on_text_revealed()
		else:
			target.visible_characters = int(_reveal)
		return
	# Auto-avance (cinemáticas): cuando el texto ya está revelado y el nodo declara
	# una duración `auto`, avanzamos solos sin esperar al jugador.
	if _mode == "say" and _auto_left > 0.0:
		_auto_left -= delta
		if _auto_left <= 0.0:
			_auto_left = 0.0
			SceneRunner.advance()
		return
	# Auto-avance del JUGADOR (modos Auto/Skip): tras revelarse el texto de un `say`
	# manual, avanza solo cuando se agota la pausa. En Skip la pausa es mínima.
	if _mode == "say" and _auto_mode_left > 0.0:
		_auto_mode_left -= delta
		if _auto_mode_left <= 0.0:
			_auto_mode_left = 0.0
			SceneRunner.advance()


func _finish_typing() -> void:
	_typing = false
	var target = _active_text_label()
	_reveal = float(target.get_total_character_count())
	target.visible_characters = -1
	_show_continue_hint(true)
	_on_text_revealed()


## Al quedar el texto de un `say` completamente revelado: si un modo automático
## está activo (Auto/Skip) y el nodo NO es una cinemática auto-temporizada, arma
## el temporizador de auto-avance del jugador (mínimo en Skip).
func _on_text_revealed() -> void:
	if _mode != "say" or _auto_left > 0.0:
		return
	if _skip_mode:
		_auto_mode_left = 0.05
	elif _auto_mode:
		_auto_mode_left = AUTO_MODE_DELAY
	elif attract_mode:
		_auto_mode_left = 2.0


## Etiqueta de texto activa según el estilo actual (panel o banner). Devuelve sin
## tipo estático porque _banner es Label y _text es RichTextLabel: ambos exponen
## `visible_characters` y `get_total_character_count()` pero no comparten una base
## tipada con esas propiedades, así que el acceso debe ser dinámico.
func _active_text_label():
	if _style == "banner":
		return _banner
	else:
		return _text


# ══════════════════════════════════════════════════════════════════════════════
# SEÑALES DEL SCENE RUNNER
# ══════════════════════════════════════════════════════════════════════════════
## Notificación visual al cambiar una Faceta o la Relación con
## un PNJ durante un diálogo presentado por la overlay global (fuera de un POI,
## donde ya lo hacía ViewPlace._on_stat_increased). Reutiliza UiKit.show_stat_toast.
func _on_stat_increased(payload: Dictionary) -> void:
	if SceneRunner.has_external_presenter():
		return
	UiKit.show_stat_toast(_root, payload, _btn_info)


func _on_scene_started(_scene_id: String) -> void:
	# Cada nueva escena arranca en velocidad y modo normal (no hereda skip de la anterior).
	_set_auto(false)
	_set_skip(false)
	# Si una vista tomó la presentación (ViewBuilding/ViewPlace), la overlay global
	# se inhibe: el motor es el mismo, pero dibuja la otra vista.
	if SceneRunner.has_external_presenter():
		_hide_all()
		return
	visible = true
	_root.visible = true
	_reset_dim()
	# La overlay aparecía de golpe (corte seco); ahora se funde
	# de entrada, coherente con las transiciones del resto del juego.
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.18 if not Locale.reduce_motion else 0.05).set_trans(Tween.TRANS_SINE)


func _on_scene_finished(_scene_id: String) -> void:
	_set_auto(false)
	_set_skip(false)
	if _root != null and is_instance_valid(_root):
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not visible or _root == null or not is_instance_valid(_root) or Locale.reduce_motion:
		_hide_all()
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_hide_all)


func _on_say_shown(data: Dictionary) -> void:
	if SceneRunner.has_external_presenter():
		return
	_mode = "say"
	visible = true
	_root.visible = true
	_update_responsive_layout()
	_clear_choices()
	_style = String(data.get("style", "box"))
	var current_scene_id := SceneRunner.active_scene_id if SceneRunner != null else ""
	_active_npc_id = String(data.get("npc_id", current_scene_id.trim_prefix("npc:")))

	var fx: Dictionary = data.get("fx", {}) if data.get("fx") is Dictionary else {}
	# La velocidad final combina la del propio nodo (fx.speed) con el ajuste global
	# de accesibilidad (Locale.text_speed), para respetar la preferencia del jugador.
	_chars_per_sec = BASE_CHARS_PER_SEC * float(fx.get("speed", 1.0)) * Locale.text_speed
	_full_text = String(data.get("text", ""))
	_apply_bg(String(data.get("bg", "")))

	if _style == "banner":
		# Narración centrada a pantalla (estilo cinemática): sin panel ni retrato.
		_panel.visible = false
		_banner.visible = true
		_banner.text = _full_text
		_banner.visible_characters = 0
	else:
		_panel.visible = true
		_banner.visible = false
		_portrait.text = String(data.get("portrait", ""))
		_portrait.visible = _portrait.text != ""
		_speaker.text = String(data.get("speaker", ""))
		_speaker.visible = _speaker.text != ""
		_text.text = _full_text
		_text.visible_characters = 0

	_reveal = 0.0
	_typing = _full_text != ""
	_typing_pause = 0.18 # Pausa previa al tipeo (~180ms)
	_auto_left = float(data.get("auto", 0.0)) if not bool(data.get("require_click", false)) else 0.0
	_auto_mode_left = 0.0
	_update_ctrl_bar_visibility()
	_show_continue_hint(not _typing and _auto_left <= 0.0)
	_apply_fx(fx)
	if not _typing:
		_active_text_label().visible_characters = -1
	# Historial: recuerda cada línea mostrada (para releer con el botón 📜).
	_record_history(String(data.get("speaker", "")), _full_text)
	# En modo SKIP el texto se revela de golpe para encadenar rápido.
	if _skip_mode and _typing:
		_finish_typing()
	elif not _typing:
		_on_text_revealed()


func _on_choice_shown(prompt: String, options: Array) -> void:
	if SceneRunner.has_external_presenter():
		return
	_mode = "choice"
	visible = true
	_root.visible = true
	_typing = false
	_auto_left = 0.0
	_auto_mode_left = 0.0
	_style = "box"
	# El SKIP se detiene ante una decisión: el jugador debe elegir conscientemente.
	if _skip_mode:
		_set_skip(false)
	# Durante la elección solo tiene sentido el Historial (Auto/Skip no avanzan).
	_update_ctrl_bar_visibility()
	# Las opciones siempre se muestran en el panel inferior (no en banner).
	_panel.visible = true
	_banner.visible = false
	_update_responsive_layout()
	_show_continue_hint(false)
	# Si hay un enunciado, se muestra como texto; si no, se conserva el último say.
	if prompt != "":
		_speaker.visible = false
		_portrait.visible = false
		_text.text = prompt
		_text.visible_characters = -1
	_clear_choices()
	for opt in options:
		var idx: int = int(opt.get("index", 0))
		var req := UiKit.check_option_facet_req(opt, _active_npc_id)
		var btn_text := String(opt.get("text", ""))
		var enabled := bool(req.get("met", true))
		if req.get("has_req", false) and not enabled:
			btn_text = "%s: %s" % [req.get("badge_text", "🔒"), btn_text]
		elif req.get("has_req", false):
			btn_text = "%s %s" % [req.get("icon", ""), btn_text]
		var btn := _make_choice_button(btn_text, enabled)
		if enabled:
			btn.pressed.connect(func() -> void: _on_choice_pressed(idx))
		_choices_box.add_child(btn)
	_animate_choices_in()


# ══════════════════════════════════════════════════════════════════════════════
# ENTRADA DEL JUGADOR
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if attract_mode:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed):
			get_viewport().set_input_as_handled()
			attract_interrupted.emit()


func _on_dim_input(event: InputEvent) -> void:
	if attract_mode:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			get_viewport().set_input_as_handled()
			attract_interrupted.emit()
		return
	if _mode != "say":
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_advance_say()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if attract_mode:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			get_viewport().set_input_as_handled()
			attract_interrupted.emit()
		return
	if _mode != "say" and _mode != "choice":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and _mode == "say":
			_advance_say()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB or event.is_action_pressed("ui_cancel", false):
			get_viewport().set_input_as_handled()
			GlobalState.is_movement_locked = false
			if GlobalEvents.has_signal("poi_exited"):
				GlobalEvents.poi_exited.emit("")
			# En vez de abortar sin más (stop(), que descartaba
			# cualquier bandera de quest pendiente), avanzamos en segundo plano
			# por el resto del grafo aplicando state/event antes de cerrar.
			SceneRunner.skip_to_end()
			SceneManager.go_to_world()


## Primer toque completa el typewriter; el segundo avanza al siguiente nodo.
## La narración auto-temporizada (auto > 0) avanza sola: el toque solo completa
## el typewriter, sin adelantar el pase (para respetar el ritmo de la cinemática).
func _advance_say() -> void:
	if _typing:
		_finish_typing()
		return
	if _auto_left > 0.0:
		return
	# Un toque manual cancela el modo AUTO/SKIP (el jugador retoma el control).
	if _auto_mode or _skip_mode:
		_set_auto(false)
		_set_skip(false)
	_auto_mode_left = 0.0
	AudioManager.play_sfx("click")
	SceneRunner.advance()


# ══════════════════════════════════════════════════════════════════════════════
# SKIP / AUTO / HISTORIAL — controles de lectura
# ══════════════════════════════════════════════════════════════════════════════
## Crea un botón compacto para la barra de control.
func _make_ctrl_button(handler: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(104, 46)
	b.add_theme_font_size_override("font_size", 22)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(handler)
	return b


## Refresca las etiquetas/resaltado de los botones según el estado de los modos.
func _refresh_ctrl_labels() -> void:
	if _btn_auto == null:
		return
	_btn_auto.text = Locale.pick({"es": "Pausa", "en": "Pause"}) if _auto_mode \
		else Locale.pick({"es": "Auto", "en": "Auto"})
	_btn_skip.text = Locale.pick({"es": "Saltar", "en": "Skip"})
	_btn_history.text = Locale.pick({"es": "Historial", "en": "Log"})
	_btn_info.text = Locale.pick({"es": "Info", "en": "Info"})
	UiKit.style_segmented_tab(_btn_auto, _auto_mode)
	UiKit.style_segmented_tab(_btn_skip, _skip_mode)
	UiKit.style_segmented_tab(_btn_history, false)
	UiKit.style_segmented_tab(_btn_info, _info_drawer != null and is_instance_valid(_info_drawer))


func _set_auto(value: bool) -> void:
	_auto_mode = value
	if value:
		_skip_mode = false
	_refresh_ctrl_labels()


func _set_skip(value: bool) -> void:
	_skip_mode = value
	if value:
		_auto_mode = false
	_refresh_ctrl_labels()


func _on_toggle_auto() -> void:
	_set_auto(not _auto_mode)
	# Si activamos Auto con el texto ya revelado, arma el avance de inmediato.
	if _auto_mode and not _typing and _mode == "say":
		_on_text_revealed()


func _on_toggle_skip() -> void:
	if attract_mode:
		attract_interrupted.emit()
		return
	_set_skip(not _skip_mode)
	if _skip_mode and _mode == "say":
		if _typing:
			_finish_typing()
		else:
			_on_text_revealed()


## Guarda una línea en el historial (acotado). Ignora líneas vacías.
func _record_history(speaker: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	_history.append({"speaker": speaker, "text": text})
	if _history.size() > HISTORY_MAX:
		_history = _history.slice(_history.size() - HISTORY_MAX)


## Abre un overlay desplazable con las últimas líneas mostradas. Se cierra al tocar.
func _on_open_history() -> void:
	if _history_overlay != null and is_instance_valid(_history_overlay):
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_history())
	ov.add_child(bg)

	var margin := UiKit.margins(40, 40, 60, 60)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "📜  " + Locale.pick({"es": "Historial", "en": "Dialogue log"})
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	if _history.is_empty():
		var empty := Label.new()
		empty.text = Locale.pick({"es": "Sin líneas todavía.", "en": "No lines yet."})
		empty.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		list.add_child(empty)
	else:
		for entry in _history:
			list.add_child(_make_history_row(String(entry.get("speaker", "")), String(entry.get("text", ""))))

	var hint := Label.new()
	hint.text = Locale.pick({"es": "Toca para cerrar", "en": "Tap to close"})
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	vb.add_child(hint)

	_history_overlay = ov
	add_child(ov)
	# Desplaza al final (lo más reciente) tras un frame para tener tamaños.
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _make_history_row(speaker: String, text: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	if speaker != "":
		var sp := Label.new()
		sp.text = speaker
		sp.add_theme_font_size_override("font_size", 22)
		sp.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		row.add_child(sp)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 24)
	body.add_theme_color_override("default_color", UiKit.TEXT)
	body.text = text
	row.add_child(body)
	return row


func _close_history() -> void:
	if _history_overlay != null and is_instance_valid(_history_overlay):
		_history_overlay.queue_free()
	_history_overlay = null


func _on_choice_pressed(index: int) -> void:
	AudioManager.play_sfx("click")
	SceneRunner.choose(index)


# ══════════════════════════════════════════════════════════════════════════════
# EFECTOS EXPRESIVOS (fx del nodo say)
# ══════════════════════════════════════════════════════════════════════════════
func _apply_fx(fx: Dictionary) -> void:
	if fx.is_empty():
		return
	# Sonido de aparición.
	var sfx := String(fx.get("sfx", ""))
	if sfx != "":
		AudioManager.play_sfx(sfx)
	# Oscurecimiento del fondo.
	if fx.has("darken"):
		var d := clampf(float(fx.get("darken", 0.5)), 0.0, 1.0)
		_dim.color = Color(0.02, 0.02, 0.04, 0.4 + d * 0.55)
	# Zoom / pop del panel.
	if fx.has("zoom"):
		_pop_panel(float(fx.get("zoom", 1.05)))
	# Sacudida del panel.
	if fx.has("shake"):
		_shake_panel(float(fx.get("shake", 1.0)))
	# Resplandor del borde.
	if fx.has("glow"):
		_glow_panel(float(fx.get("glow", 0.5)))


func _pop_panel(pop_scale: float) -> void:
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * clampf(pop_scale, 0.8, 1.4)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _shake_panel(intensity: float) -> void:
	var amt := clampf(intensity, 0.2, 3.0) * 10.0
	var base := _panel.position
	var tw := create_tween()
	for i in 5:
		var off := Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
		tw.tween_property(_panel, "position", base + off, 0.04)
	tw.tween_property(_panel, "position", base, 0.05)


func _glow_panel(strength: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	var glow_val := UiKit.theme_float("frame_glow", 0.35) + s * 0.5
	UiKit.premium_frame(_panel, {"glow_strength": glow_val, "pad": 0})
	var tw := create_tween()
	tw.tween_callback(func() -> void:
		UiKit.premium_frame(_panel, {"pad": 0})
	).set_delay(0.6)


## color de acento del tema activo con un alfa dado — evita
## repetir `Color(theme_color("accent")..., alpha)` en cada punto que pinta el
## borde/resplandor del panel de diálogo.
func _accent_soft_alpha(alpha: float) -> Color:
	var c := UiKit.theme_color("accent", UiKit.ACCENT)
	return Color(c.r, c.g, c.b, alpha)


# ══════════════════════════════════════════════════════════════════════════════
# HELPERS DE UI
# ══════════════════════════════════════════════════════════════════════════════
func _make_choice_button(txt: String, enabled: bool = true) -> Button:
	var btn := Button.new()
	btn.text = UiKit.strip_emojis(txt)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 84)
	btn.add_theme_font_size_override("font_size", 36)
	UiKit.premium_button(btn, {"disabled": not enabled})
	if enabled:
		btn.mouse_entered.connect(func() -> void: UiKit.pop(btn, 1.02, 0.12))
	return btn


func _on_toggle_info() -> void:
	if _info_drawer != null and is_instance_valid(_info_drawer):
		_close_info_drawer()
		return
	_info_drawer = UiKit.create_narrative_info_drawer(_active_npc_id, _close_info_drawer)
	_info_drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_info_drawer.offset_left = -440
	_info_drawer.offset_right = -18
	_info_drawer.offset_top = 70
	_info_drawer.offset_bottom = 580
	_root.add_child(_info_drawer)


func _close_info_drawer() -> void:
	if _info_drawer != null and is_instance_valid(_info_drawer):
		_info_drawer.queue_free()
	_info_drawer = null


func _animate_choices_in() -> void:
	var delay := 0.0
	for child in _choices_box.get_children():
		child.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(child, "modulate:a", 1.0, 0.22).set_delay(delay).set_ease(Tween.EASE_OUT)
		delay += 0.08


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()


func _show_continue_hint(p_visible: bool) -> void:
	if attract_mode:
		_continue_box.visible = false
		return
	_continue_box.visible = p_visible and _mode == "say"
	# Pequeño pulso animado al aparecer, para que el jugador
	# note que hay más texto/puede continuar sin tener que intentarlo a ciegas,
	# en vez de un texto estático fácil de pasar por alto.
	if _continue_box.visible:
		_animate_continue_hint()
	elif _hint_pulse_tween != null and _hint_pulse_tween.is_valid():
		_hint_pulse_tween.kill()
		_hint_pulse_tween = null
		if _hint != null:
			_hint.modulate.a = 1.0


## Pulso de opacidad muy sutil del hint "▶ Toca para continuar", en bucle
## mientras esté visible. Anima `modulate` (no `position`) para no pelear con el
## layout del `HBoxContainer` que lo contiene. Mata cualquier tween anterior
## antes de arrancar uno nuevo (evita acumular tweens entre líneas de diálogo).
func _animate_continue_hint() -> void:
	if _hint == null or Locale.reduce_motion:
		return
	if _hint_pulse_tween != null and _hint_pulse_tween.is_valid():
		_hint_pulse_tween.kill()
	_hint.modulate.a = 1.0
	_hint_pulse_tween = _hint.create_tween().set_loops()
	_hint_pulse_tween.tween_property(_hint, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_pulse_tween.tween_property(_hint, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_dim() -> void:
	_dim.color = Color(0.02, 0.02, 0.04, 0.5)


## Muestra u oculta la imagen de fondo de la diapositiva narrativa. `bg_name` es el
## nombre de archivo dentro de `res://assets/vn/bg/`. Si está vacío o la textura no
## existe todavía (arte pendiente), el rect se oculta y la escena sigue con solo el
## oscurecedor + panel (degradado seguro, sin romper el flujo).
func _apply_bg(bg_name: String) -> void:
	if _bg_rect == null:
		return
	if bg_name == "":
		_bg_rect.visible = false
		_bg_rect.texture = null
		return
	var tex: Texture2D = UiKit.load_texture_safe("res://assets/vn/bg/" + bg_name)
	_bg_rect.texture = tex
	_bg_rect.visible = tex != null


func _hide_all() -> void:
	_mode = ""
	_typing = false
	_auto_left = 0.0
	_auto_mode_left = 0.0
	_style = "box"
	attract_mode = false
	_set_auto(false)
	_set_skip(false)
	visible = false
	if _root:
		_root.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _banner:
		_banner.visible = false
	if _hint_pulse_tween != null and _hint_pulse_tween.is_valid():
		_hint_pulse_tween.kill()
		_hint_pulse_tween = null
		if _hint != null:
			_hint.modulate.a = 1.0
	_clear_choices()
	_close_history()
	_close_info_drawer()
	_update_ctrl_bar_visibility()
	_reset_dim()
	if _bg_rect != null:
		_bg_rect.visible = false
		_bg_rect.texture = null


## Muestra la barra de control solo mientras hay narrativa activa (say/choice) y en
## el estilo de panel (no en banners cinemáticos, que buscan inmersión total).
## En modo attract/demo se oculta siempre para que no haya botones.
func _update_ctrl_bar_visibility() -> void:
	if _ctrl_bar == null:
		return
	if attract_mode:
		_ctrl_bar.visible = false
		return
	_ctrl_bar.visible = (_mode == "say" or _mode == "choice") and _style != "banner"
