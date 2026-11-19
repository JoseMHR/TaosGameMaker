# OrbCompanionOverlay.gd
# ─────────────────────────────────────────────────────────────────────────────
# COMPAÑERO DE LA ESFERA DE LA VERDAD — WIDGET EN PANTALLA & MODO MODAL (REVISIÓN 3)
#
# Administra dos estados visuales (TAMAÑO AMPLIO DRAMÁTICO):
#   1. ESTADO DE REPOSO: Esquina superior izquierda (debajo de la interfaz HUD).
#      Base 140x140 px (casi el doble de tamaño). Al pulsar la Esfera, muestra
#      la pista del siguiente objetivo principal.
#   2. ESTADO DE MENSAJE IMPORTANTE: La Esfera viaja al CENTRO de la pantalla y
#      se AGRANDA MASIVAMENTE (escala x3.0 → ~420px de diámetro), presentando
#      una tarjeta modal mística centrada. Al cerrar, regresa a reposo.
# ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

enum State { REST, IMPORTANT }

var _current_state: State = State.REST
var _root: Control
var _orb_container: Control
var _orb_btn: Button
var _orb_draw_node: Control

# Bocadillo de texto flotante en reposo (*Bark Panel*)
var _bark_panel: PanelContainer
var _bark_lbl: Label

# Panel Modal centrado para Mensajes Importantes
var _modal_center: CenterContainer  # ← Contenedor que centra automáticamente
var _modal_panel: PanelContainer
var _modal_lbl: Label
var _modal_btn: Button
var _modal_title_lbl: Label
var _dim_bg: ColorRect

var _tween: Tween = null
var _move_tween: Tween = null
var _anim_time: float = 0.0

var _rest_pos: Vector2 = Vector2(24.0, 240.0)
var _pending_flag_to_set: String = ""
var _pending_quest_state: String = ""
var _last_dismiss_ms: int = 0


## ¿Hay una modal activa o recién cerrada que deba bloquear la entrada del mapamundi?
func is_modal_active() -> bool:
	return _current_state == State.IMPORTANT or (Time.get_ticks_msec() - _last_dismiss_ms < 450)



func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GlobalEvents.theme_changed.connect(_on_theme_changed)
	if Locale != null and not Locale.locale_changed.is_connected(_on_locale_changed):
		Locale.locale_changed.connect(_on_locale_changed)
	_hide_bark(true)
	_hide_modal(true)
	_set_overlay_visible(false)

	if OrbBarksManager != null:
		OrbBarksManager.bark_requested.connect(_on_bark_requested)
		OrbBarksManager.important_message_requested.connect(_on_important_message_requested)

	if OrbCompanionManager != null:
		OrbCompanionManager.play_orb_bark.connect(_on_companion_bark_requested)

	if SceneManager != null:
		SceneManager.view_changed.connect(_on_scene_view_changed)
		SceneManager.navigate_to.connect(_on_scene_navigate_to)
		SceneManager.tab_switched.connect(_on_scene_tab_switched)
		SceneManager.combat_started.connect(_on_scene_combat_started)
		SceneManager.combat_ended.connect(_on_scene_combat_ended)

	get_viewport().size_changed.connect(_update_responsive_layout)
	if _root != null:
		_root.resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	_update_visibility()


func _update_responsive_layout() -> void:
	if _orb_container == null or _root == null:
		return
	var sz := _root.get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	if is_landscape:
		_rest_pos = Vector2(24.0, 140.0)
		_orb_container.custom_minimum_size = Vector2(120, 120)
		_orb_container.size = Vector2(120, 120)
		_orb_container.pivot_offset = Vector2(60, 60)
		if _bark_panel != null:
			_bark_panel.custom_minimum_size = Vector2(500, 0)
			_bark_panel.position = Vector2(150.0, 140.0)
			if _bark_lbl != null:
				_bark_lbl.add_theme_font_size_override("font_size", 28)
	else:
		_rest_pos = Vector2(24.0, 280.0)
		_orb_container.custom_minimum_size = Vector2(240, 240)
		_orb_container.size = Vector2(240, 240)
		_orb_container.pivot_offset = Vector2(120, 120)
		if _bark_panel != null:
			_bark_panel.custom_minimum_size = Vector2(680, 0)
			_bark_panel.position = Vector2(280.0, 300.0)
			if _bark_lbl != null:
				_bark_lbl.add_theme_font_size_override("font_size", 48)

	if _orb_draw_node != null:
		_orb_draw_node.queue_redraw()

	if _current_state == State.REST:
		_orb_container.position = _rest_pos


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var orb_accent := UiKit.theme_color("accent", UiKit.ACCENT)

	# 0. Fondo de oscurecimiento místico para el estado modal
	_dim_bg = ColorRect.new()
	_dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_bg.color = Color(0.02, 0.03, 0.07, 0.55)
	_dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_bg.visible = false
	_root.add_child(_dim_bg)

	# 1. Contenedor del widget de la Esfera en Reposo (240x240 px base para escalado)
	_orb_container = Control.new()
	_orb_container.custom_minimum_size = Vector2(240, 240)
	_orb_container.position = _rest_pos
	_orb_container.size = Vector2(240, 240)
	_orb_container.pivot_offset = Vector2(120, 120)
	_orb_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_orb_container)

	# Renderizado procedimental de la Esfera brillante
	_orb_draw_node = Control.new()
	_orb_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orb_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_draw_node.draw.connect(_on_draw_orb)
	_orb_container.add_child(_orb_draw_node)

	# Botón táctil sobre la Esfera
	_orb_btn = Button.new()
	_orb_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orb_btn.flat = true
	_orb_btn.focus_mode = Control.FOCUS_NONE

	var empty_style := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		_orb_btn.add_theme_stylebox_override(st, empty_style)

	_orb_btn.pressed.connect(_on_orb_pressed)
	_orb_container.add_child(_orb_btn)

	# 2. Bocadillo de texto flotante en reposo (*Bark Panel*) — más grande y legible
	_bark_panel = PanelContainer.new()
	_bark_panel.custom_minimum_size = Vector2(680, 0)
	_bark_panel.position = Vector2(280.0, 300.0)
	_bark_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.premium_frame(_bark_panel, {"pad": 0, "border_width": 3.0, "corner_radius": 18.0})

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark_panel.add_child(margin)

	_bark_lbl = Label.new()
	_bark_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark_lbl.add_theme_font_size_override("font_size", 48)
	_bark_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	_bark_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_bark_lbl)

	_root.add_child(_bark_panel)

	# 3. CenterContainer que ocupa toda la pantalla y centra automáticamente el modal
	_modal_center = CenterContainer.new()
	_modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_center.visible = false
	_root.add_child(_modal_center)

	# Panel Modal: se dimensiona SOLO por su contenido (CenterContainer lo centra)
	_modal_panel = PanelContainer.new()
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.premium_dialog_panel(_modal_panel, orb_accent, 22, 0)

	var modal_vbox := VBoxContainer.new()
	modal_vbox.add_theme_constant_override("separation", 18)
	
	var m_margin := MarginContainer.new()
	m_margin.add_theme_constant_override("margin_left", 32)
	m_margin.add_theme_constant_override("margin_right", 32)
	m_margin.add_theme_constant_override("margin_top", 32)
	m_margin.add_theme_constant_override("margin_bottom", 32)
	m_margin.add_child(modal_vbox)
	_modal_panel.add_child(m_margin)

	_modal_title_lbl = Label.new()
	_modal_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title_lbl.add_theme_font_size_override("font_size", 42)
	_modal_title_lbl.add_theme_color_override("font_color", orb_accent)
	modal_vbox.add_child(_modal_title_lbl)

	_modal_lbl = Label.new()
	_modal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_lbl.add_theme_font_size_override("font_size", 48)
	_modal_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_modal_lbl.custom_minimum_size = Vector2(760, 0)  # Ancho amplio para texto grande
	modal_vbox.add_child(_modal_lbl)

	_modal_btn = Button.new()
	_modal_btn.custom_minimum_size = Vector2(280, 72)
	_modal_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_btn.focus_mode = Control.FOCUS_NONE
	_modal_btn.add_theme_font_size_override("font_size", 30)
	UiKit.premium_button(_modal_btn, {"border_width": 2.0, "corner_radius": 14.0})
	_modal_btn.pressed.connect(_on_modal_dismissed)
	modal_vbox.add_child(_modal_btn)

	_update_locale_texts()

	_modal_center.add_child(_modal_panel)


func _on_locale_changed() -> void:
	_update_locale_texts()


func _update_locale_texts() -> void:
	if _modal_title_lbl != null:
		_modal_title_lbl.text = Locale.pick({
			"es": "🔮 ESFERA DE LA VERDAD",
			"en": "🔮 SPHERE OF TRUTH",
			"fr": "🔮 SPHÈRE DE LA VÉRITÉ",
			"it": "🔮 SFERA DELLA VERITÀ",
			"de": "🔮 SPHÄRE DER WAHRHEIT",
			"zh": "🔮 真理之球",
			"ja": "🔮 真理の球"
		})
	if _modal_btn != null:
		_modal_btn.text = Locale.pick({
			"es": "ENTENDIDO",
			"en": "UNDERSTOOD",
			"fr": "COMPRIS",
			"it": "HO CAPITO",
			"de": "VERSTANDEN",
			"zh": "明白了",
			"ja": "了解"
		})


## Repinta en caliente ambos estados (reposo/bark y modal) con el marco y color de
## marca del tema activo, SIN reconstruir la UI.
func _on_theme_changed(_theme_id: String) -> void:
	var orb_accent := UiKit.theme_color("accent", UiKit.ACCENT)
	if _bark_panel != null:
		UiKit.premium_frame(_bark_panel, {"pad": 0, "border_width": 3.0, "corner_radius": 18.0})
	if _modal_panel != null:
		UiKit.premium_dialog_panel(_modal_panel, orb_accent, 22, 0)
	if _modal_title_lbl != null:
		_modal_title_lbl.add_theme_color_override("font_color", orb_accent)
	if _modal_btn != null:
		UiKit.premium_button(_modal_btn, {"border_width": 2.0, "corner_radius": 14.0})


func _process(delta: float) -> void:
	if not _root.visible:
		return

	_anim_time += delta

	# En reposo: levitación Y sutil
	if _current_state == State.REST and _orb_container != null and is_instance_valid(_orb_container):
		var offset_y := sin(_anim_time * 2.5) * 4.0
		_orb_container.position.y = _rest_pos.y + offset_y

	if _orb_draw_node != null and is_instance_valid(_orb_draw_node):
		_orb_draw_node.queue_redraw()


## Renderizado procedimental de la Esfera adaptable a cualquier dimensión de contenedor
func _on_draw_orb() -> void:
	var container_sz := _orb_draw_node.size if (_orb_draw_node != null and _orb_draw_node.size.x > 1.0) else (_orb_container.size if (_orb_container != null and _orb_container.size.x > 1.0) else Vector2(120, 120))
	var center := container_sz * 0.5
	var base_r := minf(center.x, center.y)
	if base_r <= 1.0:
		base_r = 60.0
		center = Vector2(60, 60)
	var time := _anim_time

	# 1. Resplandor exterior (Aura pulsante)
	var pulse := 1.0 + sin(time * 3.5) * 0.12
	var aura_radius := base_r * 0.85 * pulse
	var aura_color := Color(0.0, 0.85, 0.95, 0.25 + sin(time * 3.5) * 0.08)
	_orb_draw_node.draw_circle(center, aura_radius, aura_color)

	# 2. Anillo orbital de energía (rotatorio)
	var ring_radius := base_r * 0.65
	var dots_count := 10
	var dot_radius := maxf(2.0, base_r * 0.075)
	for i in range(dots_count):
		var angle := time * 2.2 + float(i) * (TAU / float(dots_count))
		var pos := center + Vector2(cos(angle) * ring_radius, sin(angle) * (ring_radius * 0.5))
		var alpha := clampf(0.3 + sin(angle) * 0.7, 0.1, 0.9)
		_orb_draw_node.draw_circle(pos, dot_radius, Color(1.0, 0.85, 0.4, alpha))

	# 3. Núcleo místico de cristal (gradiente cian/violeta)
	var core_radius := base_r * 0.5
	var core_color := Color(0.0, 0.92, 0.96, 0.92)
	var inner_color := Color(0.52, 0.12, 0.85, 0.75)
	_orb_draw_node.draw_circle(center, core_radius, inner_color)
	_orb_draw_node.draw_circle(center, core_radius * 0.75, core_color)

	# 4. Brillo especular de cristal
	var spec_pos := center + Vector2(-base_r * 0.16, -base_r * 0.16)
	_orb_draw_node.draw_circle(spec_pos, base_r * 0.12, Color(1.0, 1.0, 1.0, 0.78))
	_orb_draw_node.draw_circle(spec_pos + Vector2(-base_r * 0.05, -base_r * 0.05), base_r * 0.05, Color(1.0, 1.0, 1.0, 0.96))


func _update_visibility() -> void:
	var allowed: bool = SceneManager.is_orb_allowed() if SceneManager != null else false
	_set_overlay_visible(allowed)

	if not allowed:
		_hide_modal(true)
		_hide_bark(true)
		_current_state = State.REST
		if _dim_bg != null:
			_dim_bg.visible = false
		if _orb_container != null:
			_orb_container.position = _rest_pos
			_orb_container.scale = Vector2(1.0, 1.0)
		return
		
	# Al hacerse visible en el mapamundi con partida activa, comprobar si hay un hito pendiente
	if _root != null and _root.visible and OrbBarksManager != null and SaveManager != null and SaveManager.active:
		OrbBarksManager.check_overworld_milestones()


func _set_overlay_visible(p_visible: bool) -> void:
	if _root != null:
		_root.visible = p_visible


func _on_orb_pressed() -> void:
	if _current_state == State.IMPORTANT:
		return

	if _orb_container != null:
		UiKit.pop(_orb_container, 1.25, 0.18)

	# Delegar en el gestor dinámico de la esfera (pokes cómicos escalonados + pista)
	if OrbCompanionManager != null:
		OrbCompanionManager.on_orb_clicked()
	elif OrbBarksManager != null:
		var hint_text := OrbBarksManager.get_small_hint()
		var obj_fmt := Locale.pick({
			"es": "Objetivo: %s",
			"en": "Objective: %s",
			"fr": "Objectif : %s",
			"it": "Obiettivo: %s",
			"de": "Ziel: %s",
			"zh": "目标：%s",
			"ja": "目標：%s"
		})
		show_bark(obj_fmt % hint_text)
	elif QuestManager != null:
		var q: Dictionary = QuestManager.get_active_quest()
		var hint_text: String = String(Locale.pick(q.get("hint", {}))) if q.has("hint") else ""
		if hint_text != "":
			var obj_fmt := Locale.pick({
				"es": "Objetivo: %s",
				"en": "Objective: %s",
				"fr": "Objectif : %s",
				"it": "Obiettivo: %s",
				"de": "Ziel: %s",
				"zh": "目标：%s",
				"ja": "目標：%s"
			})
			show_bark(obj_fmt % hint_text)
		else:
			show_bark(Locale.pick({
				"es": "Esfera: 'Explora el valle hacia el Puerto de Celestia.'",
				"en": "Sphere: 'Explore the valley towards the Port of Celestia.'",
				"fr": "Sphère : « Explore la vallée vers le Port de Celestia. »",
				"it": "Sfera: 'Esplora la valle verso il Porto di Celestia.'",
				"de": "Sphäre: 'Erkunde das Tal in Richtung Hafen von Celestia.'",
				"zh": "光球：“向着塞拉斯蒂亚港口探索山谷。”",
				"ja": "光球：「セレスティア港に向かって谷を探索しろ。」"
			}))


func _on_companion_bark_requested(text: String, mode: String) -> void:
	if SceneManager != null and not SceneManager.is_orb_allowed():
		return
	if _root != null:
		_root.visible = true
	if mode == "LARGE":
		show_important_message(text)
	else:
		show_bark(text, 3.8)


func _on_bark_requested(_speaker: String, text: String, duration: float) -> void:
	if SceneManager != null and not SceneManager.is_orb_allowed():
		return
	if _root != null and _root.visible and _current_state == State.REST:
		show_bark(text, duration)


func _on_important_message_requested(text: String, quest_state: String, flag_to_set: String) -> void:
	if SceneManager != null and not SceneManager.is_orb_allowed():
		return
	if _root != null:
		_root.visible = true
		show_important_message(text, quest_state, flag_to_set)


## Presenta un Mensaje Importante (Modo Grande): Esfera al centro con escala 1.8x + Typewriter
func show_important_message(text: String, quest_state: String = "", flag_to_set: String = "") -> void:
	_current_state = State.IMPORTANT
	_pending_flag_to_set = flag_to_set
	_pending_quest_state = quest_state
	_hide_bark(true)

	var vp_size := get_viewport().get_visible_rect().size

	# Activar fondo de oscurecimiento místico
	if _dim_bg != null:
		_dim_bg.visible = true
		_dim_bg.modulate.a = 0.0
		var d_tween := create_tween()
		d_tween.tween_property(_dim_bg, "modulate:a", 1.0, 0.35)

	# 1. Mover la Esfera al centro-superior con escala 1.8x
	var orb_center := Vector2(vp_size.x * 0.5 - 120.0, vp_size.y * 0.25 - 120.0)

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween().set_parallel(true)
	_move_tween.tween_property(_orb_container, "position", orb_center, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(_orb_container, "scale", Vector2(1.8, 1.8), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Configurar texto directo e instantáneo
	_modal_lbl.text = text
	_modal_lbl.visible_ratio = 1.0
	_modal_center.visible = true
	_modal_panel.modulate.a = 0.0
	_modal_panel.scale = Vector2(0.9, 0.9)
	_modal_panel.pivot_offset = _modal_panel.size * 0.5

	var m_tween := create_tween().set_parallel(true)
	m_tween.tween_property(_modal_panel, "modulate:a", 1.0, 0.2).set_delay(0.15).set_trans(Tween.TRANS_SINE)
	m_tween.tween_property(_modal_panel, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.15).set_trans(Tween.TRANS_BACK)

	AudioManager.play_sfx("click")


func _on_modal_dismissed() -> void:
	if _current_state != State.IMPORTANT:
		return

	_last_dismiss_ms = Time.get_ticks_msec()

	# Aplicar flags o estado de misión al cerrar
	if _pending_flag_to_set != "":
		GlobalState.set_world_flag(_pending_flag_to_set, true)
		_pending_flag_to_set = ""

	if _pending_quest_state != "" and QuestManager != null:
		QuestManager.set_quest_forward(_pending_quest_state)
		_pending_quest_state = ""

	_hide_modal()

	# 3. Transición de regreso a reposo (Arriba a la izquierda, escala original 1.0)
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween().set_parallel(true)
	_move_tween.tween_property(_orb_container, "position", _rest_pos, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(_orb_container, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(func() -> void:
		_current_state = State.REST
	)


func show_bark(text: String, duration: float = 4.5) -> void:
	if _bark_lbl == null or _bark_panel == null or _current_state == State.IMPORTANT:
		return

	_bark_lbl.text = text
	_bark_panel.visible = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_bark_panel.modulate.a = 0.0
	_bark_panel.scale = Vector2(0.85, 0.85)
	_bark_panel.pivot_offset = Vector2(0.0, 0.0)

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_bark_panel, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_bark_panel, "scale", Vector2(1.0, 1.0), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	get_tree().create_timer(duration).timeout.connect(func() -> void:
		_hide_bark()
	)


func _hide_bark(immediate: bool = false) -> void:
	if _bark_panel == null:
		return

	if immediate:
		_bark_panel.visible = false
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_bark_panel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_bark_panel, "scale", Vector2(0.9, 0.9), 0.2)
	_tween.finished.connect(func() -> void:
		_bark_panel.visible = false
	)


func _hide_modal(immediate: bool = false) -> void:
	if _modal_center == null:
		return

	if _dim_bg != null:
		if immediate:
			_dim_bg.visible = false
		else:
			var d_tween := create_tween()
			d_tween.tween_property(_dim_bg, "modulate:a", 0.0, 0.2)
			d_tween.finished.connect(func() -> void: _dim_bg.visible = false)

	if immediate:
		_modal_center.visible = false
		return

	var m_tween := create_tween().set_parallel(true)
	m_tween.tween_property(_modal_panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	m_tween.tween_property(_modal_panel, "scale", Vector2(0.9, 0.9), 0.2)
	m_tween.finished.connect(func() -> void:
		_modal_center.visible = false
	)


func _on_scene_view_changed(_view: String) -> void:
	_update_visibility()


func _on_scene_navigate_to(_name: String, _data: Dictionary) -> void:
	_update_visibility()


func _on_scene_tab_switched(_tab: String) -> void:
	_update_visibility()


func _on_scene_combat_started(_data: Dictionary) -> void:
	_set_overlay_visible(false)


func _on_scene_combat_ended(victory: bool, fled: bool = false) -> void:
	_update_visibility()
	if OrbCompanionManager != null:
		OrbCompanionManager.on_combat_ended(victory, fled)

