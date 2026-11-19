# ViewPlace.gd
# Vista de un "Lugar" genérico (ni ciudad ni mazmorra): imagen de fondo + cuadro de
# diálogo inferior. El personaje es OPCIONAL: si el lugar tiene un NPC en npcs.json
# (resuelto por ids.json[event_id].npc) se muestra su sprite y sus opciones; si el
# NPC no tiene avatar (p. ej. la presa) se oculta el sprite y solo se narra el lugar.
# Todo es data-driven vía el autoload `Design` (nodos planos + condición + reward).
class_name ViewPlace
extends Control

# ─── ESTADO ───────────────────────────────────────────────────────────────────
var _cell_data: Dictionary = {}
var _biome: Color = Color("18241b")
var _text_pages: Array[String] = []
var _current_page_idx: int = 0
# Motor data-driven: id del NPC/diálogo activo (resuelto desde ids.json) y nodo actual.
var _npc_id: String = ""
var _poi_id: String = ""
var _has_character: bool = false
var _is_typing: bool = false
var _typing_tween: Tween = null
var _indicator_tween: Tween = null
## Bandera de cierre para no re-entrar en la salida (stop() reemite scene_finished).
var _leaving: bool = false

# ─── REFERENCIAS UI NOVELA VISUAL ─────────────────────────────────────────────
var _bg_rect: TextureRect
var _bg_dim: ColorRect
var _npc_rect: TextureRect
var _dialogue_panel: PanelContainer
var _name_plate: PanelContainer
var _lbl_vn_name: Label
var _lbl_text: Label
var _lbl_more_indicator: Label
var _choices_box: VBoxContainer
var _lbl_name: Label
var _btn_leave: Button
var _btn_info: Button
var _btn_rel: Button
var _info_drawer: Control = null
var _scene_icon: Label
var _header: PanelContainer
var _intro_active: bool = false
var _return_view: String = "world"


func _ready() -> void:
	_build_ui()
	_refresh_static_texts()
	Locale.locale_changed.connect(_refresh_static_texts)
	resized.connect(_update_responsive_layout)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	# SISTEMA NARRATIVO UNIFICADO: el diálogo del lugar se ejecuta en el
	# SceneRunner (adaptador npc_to_scene); esta vista solo aporta su presentación.
	# Se registra como presenter externo para inhibir la NarrativeOverlay global.
	SceneRunner.say_shown.connect(_on_runner_say)
	SceneRunner.choice_shown.connect(_on_runner_choice)
	SceneRunner.scene_finished.connect(_on_runner_finished)
	Locale.theme_changed.connect(_on_theme_changed)


## Al salir de la vista, libera la presentación (defensivo).
func _exit_tree() -> void:
	SceneRunner.release_presenter(self)


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════
func get_location_name() -> String:
	var event_id: String = String(_cell_data.get("event_id", _poi_id))
	if event_id != "":
		var dname: String = Locale.pick(Design.id_name(event_id))
		if dname != "" and dname != event_id:
			return dname
	var name_i18n = _cell_data.get("name_i18n", null)
	if name_i18n is Dictionary and not (name_i18n as Dictionary).is_empty():
		return Locale.pick(name_i18n)
	if _cell_data.has("name"):
		var raw_name = _cell_data.get("name")
		if raw_name is Dictionary:
			return Locale.pick(raw_name)
		elif str(raw_name) != "":
			return Locale.translate_cell_name(str(raw_name))
	if _lbl_name != null and not _lbl_name.text.is_empty():
		return _lbl_name.text
	return Locale.t("loc_place")


func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	if _header != null:
		_header.visible = not is_landscape
	if _btn_rel != null:
		_btn_rel.visible = (_npc_id != "")
		_btn_rel.offset_left = -320
		_btn_rel.offset_top = 8
		_btn_rel.offset_right = -24
		_btn_rel.offset_bottom = 64

	if _dialogue_panel != null:
		if is_landscape:
			var max_w := sz.x - 120.0
			_dialogue_panel.anchor_left = 0.5
			_dialogue_panel.anchor_right = 0.5
			_dialogue_panel.anchor_top = 1.0
			_dialogue_panel.anchor_bottom = 1.0
			_dialogue_panel.offset_left = -max_w * 0.5
			_dialogue_panel.offset_right = max_w * 0.5
			_dialogue_panel.offset_top = -250
			_dialogue_panel.offset_bottom = -16
		else:
			_dialogue_panel.anchor_left = 0.0
			_dialogue_panel.anchor_right = 1.0
			_dialogue_panel.anchor_top = 1.0
			_dialogue_panel.anchor_bottom = 1.0
			_dialogue_panel.offset_left = 24
			_dialogue_panel.offset_right = -24
			_dialogue_panel.offset_top = -460
			_dialogue_panel.offset_bottom = -20

	var name_wrap: Control = get_node_or_null("NameWrap") as Control
	if name_wrap != null:
		if is_landscape:
			var max_w := sz.x - 120.0
			name_wrap.anchor_left = 0.5
			name_wrap.anchor_right = 0.5
			name_wrap.anchor_top = 1.0
			name_wrap.anchor_bottom = 1.0
			name_wrap.offset_left = -max_w * 0.5 + 16.0
			name_wrap.offset_right = max_w * 0.5 - 16.0
			name_wrap.offset_top = -298
			name_wrap.offset_bottom = -250
		else:
			name_wrap.anchor_left = 0.0
			name_wrap.anchor_right = 1.0
			name_wrap.anchor_top = 1.0
			name_wrap.anchor_bottom = 1.0
			name_wrap.offset_left = 48
			name_wrap.offset_right = -48
			name_wrap.offset_top = -512
			name_wrap.offset_bottom = -462

	if _lbl_text != null:
		if is_landscape:
			_lbl_text.add_theme_font_size_override("font_size", 36)
		else:
			_lbl_text.add_theme_font_size_override("font_size", 40)

	if _lbl_vn_name != null:
		if is_landscape:
			_lbl_vn_name.add_theme_font_size_override("font_size", 36)
		else:
			_lbl_vn_name.add_theme_font_size_override("font_size", 40)

	if _npc_rect != null:
		if is_landscape:
			_npc_rect.anchor_top = 1.0
			_npc_rect.anchor_bottom = 1.0
			_npc_rect.custom_minimum_size = Vector2(900, 1100)
			_npc_rect.offset_left = -450
			_npc_rect.offset_right = 450
			_npc_rect.offset_top = -1100
			_npc_rect.offset_bottom = 0
		else:
			_npc_rect.anchor_left = 0.5
			_npc_rect.anchor_right = 0.5
			_npc_rect.anchor_top = 1.0
			_npc_rect.anchor_bottom = 1.0
			_npc_rect.custom_minimum_size = Vector2(900, 1350)
			_npc_rect.offset_left = -450
			_npc_rect.offset_right = 450
			_npc_rect.offset_top = -1450
			_npc_rect.offset_bottom = -250


func setup(data_or_id, return_target: String = "") -> void:
	_leaving = false
	var cell_data: Dictionary = {}
	if data_or_id is Dictionary:
		cell_data = data_or_id.duplicate()
		var poi_id: String = String(cell_data.get("poi_id", cell_data.get("event_id", "")))
		_poi_id = poi_id
		if poi_id != "" and Design.has_id(poi_id):
			cell_data["event_id"] = poi_id
			var spec_init: Dictionary = Design.get_id(poi_id)
			if not cell_data.has("npc") or String(cell_data["npc"]) == "":
				cell_data["npc"] = spec_init.get("npc", "")
			if not cell_data.has("name"):
				cell_data["name"] = Locale.pick(spec_init.get("name", {}))
			if not cell_data.has("icon"):
				cell_data["icon"] = spec_init.get("icon", "🏠")
		_return_view = String(cell_data.get("return_view", "city" if cell_data.has("city") else "world"))
	elif data_or_id is String:
		var raw_str: String = String(data_or_id)
		_poi_id = raw_str
		var event_id_str: String = raw_str
		var real_npc_id: String = raw_str
		if Design.has_id(raw_str):
			event_id_str = raw_str
			real_npc_id = String(Design.get_id(raw_str).get("npc", raw_str))
		cell_data = {
			"event_id": event_id_str,
			"npc": real_npc_id,
			"name": Locale.pick(Design.id_name(event_id_str)) if Design.has_id(event_id_str) else Locale.pick(Design.npc_meta(real_npc_id).get("name", {})),
			"icon": Design.id_icon(event_id_str) if Design.has_id(event_id_str) else Design.npc_meta(real_npc_id).get("avatar", "🏠"),
			"return_view": "city" if return_target.is_empty() else return_target,
		}
		_return_view = cell_data["return_view"]

	if not return_target.is_empty():
		_return_view = return_target

	_cell_data = cell_data
	_biome = cell_data.get("biome_color", _biome)

	var event_id: String = cell_data.get("event_id", "")

	# Resolver el NPC/diálogo del lugar: ids.json[event_id].npc (o presences o el propio event_id).
	_npc_id = ""
	var spec: Dictionary = Design.get_id(event_id)
	var candidate := String(cell_data.get("npc", spec.get("npc", event_id)))
	if spec.has("presences") and spec["presences"] is Array:
		for p in spec["presences"]:
			if not (p is Dictionary):
				continue
			var p_dict: Dictionary = p as Dictionary
			var cond := String(p_dict.get("condition", ""))
			if cond == "default" or cond == "" or Design.eval_condition(cond, ""):
				var actor := String(p_dict.get("actor", ""))
				if actor != "":
					candidate = actor
					break
	if candidate != "":
		_npc_id = candidate

	# Música del POI data-driven (spec.music o ambience.music o fallback a
	# ciudad/zona). BUG: cuando el POI (p. ej. "La Taberna del Dragón") no
	# define su propio `music` ni su `event_id` empieza por "city_", caía al
	# fallback de zona usando `GlobalState.player_pos` — la posición del
	# avatar en EL MAPAMUNDI, que no cambia al entrar en un edificio de la
	# ciudad, así que sonaba lo que estuviera sonando fuera de ella. Si
	# venimos de una ciudad (`cell_data["city"]`, igual que ViewShop/
	# ViewForge/ViewEncargos/ViewTransport), su tema tiene prioridad sobre el
	# de zona: es el que debe seguir sonando mientras navegamos sus POIs.
	if AudioManager != null:
		var poi_music := String(spec.get("music", ""))
		var city_ctx := String(cell_data.get("city", ""))
		if poi_music != "":
			AudioManager.play_music(poi_music)
		elif event_id.begins_with("city_") or candidate.begins_with("city_"):
			AudioManager.play_city_music(event_id)
		elif city_ctx != "":
			AudioManager.play_city_music(city_ctx)
		else:
			var z_music := Design.get_zone_music_at(GlobalState.player_pos)
			if z_music != "":
				AudioManager.play_music(z_music)

	# Asignar imagen de fondo (por defecto bg_default.png)
	var bg_tex: Texture2D = null
	if event_id != "":
		# 1. Si en data/ids/*.json se especificó explícitamente "bg" como String
		if spec.has("bg") and spec["bg"] is String and spec["bg"] != "":
			var explicit_bg: String = spec["bg"]
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/" + explicit_bg)
		# 2. Búsqueda por convención de nombres
		if not bg_tex:
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_place_%s.png" % event_id)
		if not bg_tex:
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_building_%s.png" % event_id)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/common/ui/bg_default.png")
	if _bg_rect and bg_tex:
		_bg_rect.texture = bg_tex

	# Cabecera: nombre e icono del lugar (bilingües vía ids.json cuando existen).
	if _lbl_name:
		_lbl_name.text = Locale.pick(Design.id_name(event_id)) if not spec.is_empty() else String(cell_data.get("name", ""))
	if _scene_icon:
		var ic := Design.id_icon(event_id)
		_scene_icon.text = ic if ic != "" else String(cell_data.get("icon", "🏞️"))

	# Memoria de visitas por lugar (cuenta + banderas), solo si tiene diálogo.
	if _npc_id != "":
		GlobalState.report_visit(_npc_id)

	# Registrar descubrimiento en el Códice de Curiosidades
	if event_id != "":
		GlobalState.discover_lore(event_id)
	if _npc_id != "" and _npc_id != event_id:
		GlobalState.discover_lore(_npc_id)

	GlobalEvents.subscribe("stat_increased", _on_stat_increased)
	tree_exiting.connect(func(): GlobalEvents.unsubscribe_object(self))

	_intro_active = true
	_render()
	_update_responsive_layout()

	if _header:
		_header.modulate.a = 0.0
	_dialogue_panel.modulate.a = 0.0
	if _name_plate:
		_name_plate.modulate.a = 0.0
	_choices_box.modulate.a = 0.0
	if _npc_rect:
		_npc_rect.modulate.a = 0.0

	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_callback(func() -> void:
		_intro_active = false

		var f_tween := create_tween().set_parallel(true)
		if _header:
			f_tween.tween_property(_header, "modulate:a", 1.0, 0.6)
		f_tween.tween_property(_dialogue_panel, "modulate:a", 1.0, 0.6)
		if _name_plate:
			f_tween.tween_property(_name_plate, "modulate:a", 1.0, 0.6)
		f_tween.tween_property(_choices_box, "modulate:a", 1.0, 0.6)

		if _npc_rect and _has_character:
			_npc_rect.modulate.a = 0.0
			var npc_tween := create_tween().set_parallel(true)
			npc_tween.tween_property(_npc_rect, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# 1. Imagen de fondo completa
	_bg_rect = TextureRect.new()
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg_rect.gui_input.connect(_on_dialogue_panel_input)
	add_child(_bg_rect)
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1b. Dimmer de fondo para hacer destacar al NPC y al diálogo
	_bg_dim = ColorRect.new()
	_bg_dim.color = Color(0.0, 0.0, 0.0, 0.4)
	_bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_dim)
	_bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 2. Sprite del NPC centrado, apoyado y recortado por la caja inferior
	_npc_rect = TextureRect.new()
	_npc_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc_rect.custom_minimum_size = Vector2(800, 1200)
	add_child(_npc_rect)
	_npc_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_npc_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_npc_rect.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_npc_rect.offset_left = -400
	_npc_rect.offset_right = 400
	_npc_rect.offset_top = -1500
	_npc_rect.offset_bottom = -350

	# 3. Caja de diálogo FLOTANTE estilo novela visual premium
	_dialogue_panel = PanelContainer.new()
	add_child(_dialogue_panel)

	# Anclada al fondo con márgenes generosos
	_dialogue_panel.anchor_left = 0.0
	_dialogue_panel.anchor_right = 1.0
	_dialogue_panel.anchor_top = 1.0
	_dialogue_panel.anchor_bottom = 1.0
	_dialogue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialogue_panel.offset_left = 24
	_dialogue_panel.offset_right = -24
	_dialogue_panel.offset_top = -460
	_dialogue_panel.offset_bottom = -20

	# Detectar clicks en la caja de diálogo para avanzar texto
	_dialogue_panel.gui_input.connect(_on_dialogue_panel_input)

	# 3b. Placa flotante con el NOMBRE del que habla, encima de la caja.
	var name_wrap := HBoxContainer.new()
	name_wrap.name = "NameWrap"
	name_wrap.anchor_left = 0.0
	name_wrap.anchor_right = 1.0
	name_wrap.anchor_top = 1.0
	name_wrap.anchor_bottom = 1.0
	name_wrap.offset_left = 48
	name_wrap.offset_right = -48
	name_wrap.offset_top = -512
	name_wrap.offset_bottom = -462
	name_wrap.alignment = BoxContainer.ALIGNMENT_BEGIN
	name_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_wrap)

	_name_plate = PanelContainer.new()
	name_wrap.add_child(_name_plate)

	var plate_m := UiKit.margins(22, 22, 6, 6)
	_name_plate.add_child(plate_m)

	_lbl_vn_name = Label.new()
	_lbl_vn_name.add_theme_font_size_override("font_size", 32)
	_lbl_vn_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_vn_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate_m.add_child(_lbl_vn_name)
	_name_plate.visible = false

	var dm := UiKit.margins(36, 36, 24, 20)
	_dialogue_panel.add_child(dm)

	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 12)
	dm.add_child(dbox)

	# Texto de diálogo
	_lbl_text = Label.new()
	_lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_text.add_theme_font_size_override("font_size", 30)
	_lbl_text.add_theme_color_override("font_color", UiKit.TEXT)
	_lbl_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dbox.add_child(_lbl_text)

	# Indicador de continuación
	_lbl_more_indicator = Label.new()
	_lbl_more_indicator.text = "▼"
	_lbl_more_indicator.add_theme_font_size_override("font_size", 22)
	_lbl_more_indicator.add_theme_color_override("font_color", UiKit.ACCENT)
	_lbl_more_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_more_indicator.size_flags_horizontal = Control.SIZE_SHRINK_END
	dbox.add_child(_lbl_more_indicator)

	# 4. Caja de opciones centrada en pantalla sobre el diálogo
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 16)
	_choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_choices_box)
	_choices_box.anchor_left = 0.1
	_choices_box.anchor_right = 0.9
	_choices_box.anchor_top = 0.42
	_choices_box.anchor_bottom = 0.42
	_choices_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choices_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_choices_box.offset_left = 0
	_choices_box.offset_right = 0
	_choices_box.offset_top = 0
	_choices_box.offset_bottom = 0

	# 5. Cabecera superior
	_header = PanelContainer.new()
	_header.add_theme_stylebox_override("panel", UiKit.header(0.85))
	add_child(_header)
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header.grow_vertical = Control.GROW_DIRECTION_END

	var hm := UiKit.margins(24, 24, 20, 20)
	_header.add_child(hm)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hm.add_child(hbox)

	_scene_icon = Label.new()
	_scene_icon.add_theme_font_size_override("font_size", 44)
	_scene_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_scene_icon)

	_lbl_name = Label.new()
	_lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_name.add_theme_font_size_override("font_size", 38)
	_lbl_name.add_theme_color_override("font_color", UiKit.TEXT)
	UiKit.apply_heading(_lbl_name)
	_lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_lbl_name)

	_btn_info = Button.new()
	_btn_info.text = "📖 Status"
	_btn_info.custom_minimum_size = Vector2(170, 68)
	_btn_info.add_theme_font_size_override("font_size", 24)
	_btn_info.pressed.connect(_on_toggle_info)
	hbox.add_child(_btn_info)

	_btn_leave = Button.new()
	_btn_leave.custom_minimum_size = Vector2(220, 68)
	_btn_leave.add_theme_font_size_override("font_size", 26)
	_btn_leave.pressed.connect(_leave)
	hbox.add_child(_btn_leave)

	# Botón de relación/facetas para el modo horizontal (pegado al HUD superior).
	_btn_rel = Button.new()
	_btn_rel.text = Locale.pick({"es": "📖 Facetas y Relación", "en": "📖 Facets & Relation"})
	_btn_rel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_btn_rel.offset_left = -320
	_btn_rel.offset_top = 8
	_btn_rel.offset_right = -24
	_btn_rel.offset_bottom = 64
	_btn_rel.add_theme_font_size_override("font_size", 28)
	_btn_rel.visible = false
	_btn_rel.pressed.connect(_on_toggle_info)
	add_child(_btn_rel)

	_apply_dialogue_theme()


# ══════════════════════════════════════════════════════════════════════════════
# RENDER DE CONTENIDO Y PAGINACIÓN
# ══════════════════════════════════════════════════════════════════════════════
func _render() -> void:
	_refresh_static_texts()

	if _npc_id != "":
		# Lugar con diálogo (personaje opcional según su avatar).
		var meta: Dictionary = Design.npc_meta(_npc_id)
		var avatar := String(meta.get("avatar", ""))
		# Cargar textura del NPC con simetría 1:1 respecto a su fondo de escenario
		var npc_tex: Texture2D = null
		var event_id: String = _cell_data.get("event_id", "")
		var spec: Dictionary = Design.get_id(event_id) if event_id != "" else {}
		var bg_name: String = String(spec.get("bg", ""))

		if avatar.ends_with(".png"):
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/" + avatar)
		if not npc_tex and bg_name.begins_with("bg_"):
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_" + bg_name.substr(3))
		if not npc_tex and _npc_id != "":
			var direct_name := _npc_id if _npc_id.begins_with("npc_") else ("npc_" + _npc_id)
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/%s.png" % direct_name)
		if not npc_tex and spec.has("npc"):
			var spec_npc: String = String(spec.get("npc", ""))
			if spec_npc != "":
				var spec_name := spec_npc if spec_npc.begins_with("npc_") else ("npc_" + spec_npc)
				npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/%s.png" % spec_name)

		_has_character = npc_tex != null

		if _has_character:
			if _npc_rect and npc_tex:
				_npc_rect.texture = npc_tex
				_npc_rect.visible = true
				if not _intro_active:
					_npc_rect.modulate.a = 0.0
					var npc_tween := create_tween().set_parallel(true)
					npc_tween.tween_property(_npc_rect, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			if _scene_icon:
				_scene_icon.visible = false
			if _lbl_vn_name:
				_lbl_vn_name.text = Locale.pick(meta.get("name", {}))
			if _name_plate:
				_name_plate.visible = String(Locale.pick(meta.get("name", {}))) != ""
		else:
			# Lugar sin sprite recortado de personaje: ocultar _npc_rect para lucir
			# la ilustración completa 16:9 de fondo donde el personaje ya está integrado.
			if _npc_rect:
				_npc_rect.visible = false
			var npc_name_str := String(Locale.pick(meta.get("name", {})))
			if _lbl_vn_name:
				_lbl_vn_name.text = npc_name_str
			if _name_plate:
				_name_plate.visible = npc_name_str != ""
			if _scene_icon:
				_scene_icon.visible = true

		# Ejecuta la conversación del lugar como escena en el SceneRunner.
		SceneRunner.acquire_presenter(self)
		SceneRunner.start_built_scene(
			"npc:" + _npc_id, SceneAdapters.npc_to_scene(_npc_id), _npc_id)
	else:
		# Lugar sin diálogo: solo descripción + botón de continuar. NO usamos el
		# SceneRunner (no hay grafo); paginamos la descripción directamente.
		_has_character = false
		if _scene_icon:
			_scene_icon.visible = true
		if _npc_rect:
			_npc_rect.visible = false
		if _name_plate:
			_name_plate.visible = false

		var desc: String = _cell_data.get("description", "")
		var full_text: String = desc if desc != "" else String(_cell_data.get("name", ""))
		_text_pages = _split_text_into_pages(full_text)
		_current_page_idx = 0
		if _choices_box:
			_choices_box.visible = false
			for child in _choices_box.get_children():
				child.queue_free()
		_show_current_page()


func _set_visual_state_say() -> void:
	if _npc_rect != null and is_instance_valid(_npc_rect) and _has_character:
		var sz := get_viewport_rect().size
		var is_landscape := sz.x > sz.y
		var tw := create_tween().set_parallel(true)
		if is_landscape:
			tw.tween_property(_npc_rect, "anchor_left", 0.5, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "anchor_right", 0.5, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_left", -450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_right", 450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_top", -1100, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_bottom", 0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			tw.tween_property(_npc_rect, "anchor_left", 0.5, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "anchor_right", 0.5, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_left", -450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_right", 450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_top", -1450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_bottom", -250, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _choices_box != null:
		_choices_box.visible = false

func _set_visual_state_choice() -> void:
	var sz := get_viewport_rect().size
	var is_landscape := sz.x > sz.y
	if _npc_rect != null and is_instance_valid(_npc_rect) and _has_character:
		var tw := create_tween().set_parallel(true)
		if is_landscape:
			tw.tween_property(_npc_rect, "anchor_left", 0.22, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "anchor_right", 0.22, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_left", -450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_right", 450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_top", -1100, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_bottom", 0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			tw.tween_property(_npc_rect, "anchor_left", 0.5, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "anchor_right", 0.5, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_left", -450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_right", 450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_top", -1450, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(_npc_rect, "offset_bottom", -250, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _choices_box != null:
		if is_landscape:
			_choices_box.anchor_left = 0.48
			_choices_box.anchor_right = 0.95
			_choices_box.anchor_top = 0.08
			_choices_box.anchor_bottom = 0.68
		else:
			_choices_box.anchor_left = 0.08
			_choices_box.anchor_right = 0.92
			_choices_box.anchor_top = 0.16
			_choices_box.anchor_bottom = 0.54
		_choices_box.visible = true

func _on_toggle_info() -> void:
	if _info_drawer != null and is_instance_valid(_info_drawer):
		_close_info_drawer()
		return
	_info_drawer = UiKit.create_narrative_info_drawer(_npc_id, _close_info_drawer)
	_info_drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_info_drawer.offset_left = -580
	_info_drawer.offset_right = -24
	_info_drawer.offset_top = 104
	_info_drawer.offset_bottom = 0
	add_child(_info_drawer)

func _close_info_drawer() -> void:
	if _info_drawer != null and is_instance_valid(_info_drawer):
		_info_drawer.queue_free()
	_info_drawer = null

## El runner pide mostrar un nodo `say`: pagina el texto (ya localizado) e inicia
## la máquina de escribir.
func _on_runner_say(data: Dictionary) -> void:
	if not SceneRunner.is_presenter(self):
		return
	_set_visual_state_say()
	_present_say_text(String(data.get("text", "")))


## El runner pide mostrar un nodo `choice`: dibuja los botones de opción.
func _on_runner_choice(_prompt: String, options: Array) -> void:
	if not SceneRunner.is_presenter(self):
		return
	_set_visual_state_choice()
	_show_choices_from_runner(options)


## La escena terminó: vuelve al mundo.
func _on_runner_finished(_scene_id: String) -> void:
	if not _leaving and not SceneRunner.is_presenter(self):
		return
	_close_view()


func _on_stat_increased(payload: Dictionary) -> void:
	# El "+1" debe volar hacia el botón "📖 Facetas y Relación" (`_btn_rel`,
	# esquina superior derecha — ver `_update_responsive_layout`), no hacia
	# `_btn_info` ("Status", en la cabecera): ahí es donde el jugador
	# encuentra toda la información relevante tras la subida.
	var target_btn: Button = _btn_rel if (_btn_rel != null and _btn_rel.visible) else _btn_info
	UiKit.show_stat_toast(self, payload, target_btn)


func _should_exit_directly_to_world() -> bool:
	# Inmersión: si estamos en el Palacio Real de Celestia y la alarma del boss marino
	# está activa pero aún no ha sido derrotado (el Rey nos urge a salvar el puerto),
	# salimos directamente al mapamundi para acudir a la emergencia de inmediato.
	var poi: String = _poi_id if _poi_id != "" else String(_cell_data.get("poi_id", _cell_data.get("event_id", "")))
	if _npc_id == "king_celestia" or poi == "poi_celestia_palace":
		if GlobalState.has_world_flag("boss_puerto_activo") and not GlobalState.has_world_flag("boss_puerto_derrotado"):
			return true
	return false


## Libera la presentación, detiene la escena si sigue activa y vuelve al mundo.
## Reentrante-seguro: stop() reemite scene_finished pero `_leaving` lo corta.
func _close_view() -> void:
	if _leaving:
		return
	_leaving = true
	_close_info_drawer()
	SceneRunner.release_presenter(self)
	if SceneRunner.is_active():
		SceneRunner.stop()
	if _should_exit_directly_to_world() or _return_view != "city":
		SceneManager.go_to_world()
	else:
		SceneManager.back_to_city()


## Pagina un texto e inicia la máquina de escribir (oculta opciones previas).
func _present_say_text(full_text: String) -> void:
	_text_pages = _split_text_into_pages(full_text)
	_current_page_idx = 0
	if _choices_box:
		_choices_box.visible = false
		for child in _choices_box.get_children():
			child.queue_free()
	_show_current_page()


func _split_text_into_pages(text: String) -> Array[String]:
	var pages: Array[String] = []
	var paragraphs := text.split("\n\n")
	for para in paragraphs:
		var clean_para := para.strip_edges()
		if clean_para == "":
			continue
		if clean_para.length() <= 340:
			pages.append(clean_para)
		else:
			var current_chunk := ""
			var words := clean_para.split(" ")
			for word in words:
				if current_chunk.length() + word.length() + 1 > 320:
					pages.append(current_chunk.strip_edges())
					current_chunk = word
				else:
					if current_chunk == "":
						current_chunk = word
					else:
						current_chunk += " " + word
			if current_chunk != "":
				var last_str := current_chunk.strip_edges()
				if last_str.length() < 25 and not pages.is_empty():
					pages[pages.size() - 1] += " " + last_str
				else:
					pages.append(last_str)
	return pages


func _show_current_page() -> void:
	if _current_page_idx >= _text_pages.size() or not _lbl_text:
		return

	var page_text := _text_pages[_current_page_idx]
	_lbl_text.text = page_text
	_lbl_text.visible_characters = 0
	_is_typing = true

	# Disparador dinámico visual: aparición de la Gaviota noqueada exclusivamente en la presa
	var event_id: String = _cell_data.get("event_id", "")
	if (event_id == "poi_presa_001" or _npc_id == "presa") and (page_text.contains("gaviota") or page_text.contains("seagull") or page_text.contains("De pronto")):
		var gaviota_tex: Texture2D = UiKit.load_texture_safe("res://assets/vn/npcs/npc_gaviota.png")
		if gaviota_tex and _npc_rect and _npc_rect.texture != gaviota_tex:
			var sz := get_viewport_rect().size
			var is_landscape := sz.x > sz.y
			_npc_rect.texture = gaviota_tex
			_npc_rect.visible = true
			_npc_rect.modulate.a = 1.0
			if _scene_icon:
				_scene_icon.visible = false
			if _name_plate and _lbl_vn_name:
				_lbl_vn_name.text = "🐦 Gaviota Noqueada"
				_name_plate.visible = true

			var g_tween := create_tween().set_parallel(true)
			if is_landscape:
				_npc_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
				var g_w := 620.0
				var g_h := 440.0
				_npc_rect.custom_minimum_size = Vector2(g_w, g_h)
				_npc_rect.pivot_offset = Vector2(g_w * 0.5, g_h * 0.5)
				_npc_rect.scale = Vector2(0.2, 0.2)
				_npc_rect.modulate.a = 0.0
				var start_top := -sz.y * 0.5 - g_h * 0.5
				var start_bottom := -sz.y * 0.5 + g_h * 0.5
				var end_top := -g_h * 0.3
				var end_bottom := g_h * 0.7
				_npc_rect.offset_top = start_top
				_npc_rect.offset_bottom = start_bottom
				g_tween.tween_property(_npc_rect, "scale", Vector2(1.0, 1.0), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				g_tween.tween_property(_npc_rect, "modulate:a", 1.0, 0.30).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				g_tween.tween_property(_npc_rect, "offset_top", end_top, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				g_tween.tween_property(_npc_rect, "offset_bottom", end_bottom, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			else:
				_npc_rect.pivot_offset = Vector2(250, 400)
				_npc_rect.scale = Vector2(0.2, 0.2)
				_npc_rect.modulate.a = 0.0
				_npc_rect.offset_top = -1600
				_npc_rect.offset_bottom = -500
				g_tween.tween_property(_npc_rect, "scale", Vector2(1.0, 1.0), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				g_tween.tween_property(_npc_rect, "modulate:a", 1.0, 0.30).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				g_tween.tween_property(_npc_rect, "offset_top", -1400, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				g_tween.tween_property(_npc_rect, "offset_bottom", -300, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

			# Impacto contra la compuerta: sacudida de pantalla + SFX (Fase 1).
			g_tween.chain().tween_callback(func() -> void:
				Juice.shake(self, 4.0, 0.2)
				AudioManager.play_sfx("hit")
			)

	# Disparador dinámico visual: efecto de distorsión/glitch en la tumba propia (poi_tumba_yelmo_03)
	if _npc_id == "poi_tumba_yelmo_03":
		if page_text.contains("taladra las sienes") or page_text.contains("searing, agonizing"):
			Juice.shake(self, 8.0, 0.45)
			if _bg_rect:
				Juice.flash(_bg_rect, Color(0.85, 0.2, 0.3, 0.7), 0.4)
			AudioManager.play_sfx("skill_time_distort")
		elif page_text.contains("espirales de estática") or page_text.contains("ripples of static"):
			Juice.shake(self, 24.0, 1.2)
			if _bg_rect:
				var distort_tw := create_tween()
				distort_tw.tween_property(_bg_rect, "modulate", Color(0.1, 0.9, 0.8, 0.8), 0.07)
				distort_tw.tween_property(_bg_rect, "modulate", Color(0.9, 0.1, 0.3, 0.8), 0.07)
				distort_tw.tween_property(_bg_rect, "modulate", Color(0.05, 0.05, 0.1, 0.6), 0.15)
				distort_tw.tween_property(_bg_rect, "modulate", Color.WHITE, 0.35)
			AudioManager.play_sfx("tremor")

	if _lbl_more_indicator:
		_lbl_more_indicator.visible = false
		if _indicator_tween and _indicator_tween.is_valid():
			_indicator_tween.kill()

	# Detener tween anterior
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()

	# Animar máquina de escribir por carácter con pausa previa (~180ms).
	_typing_tween = create_tween()
	_typing_tween.tween_interval(0.18)
	var char_duration: float = 0.022 / maxf(Locale.text_speed, 0.1)
	_typing_tween.tween_property(_lbl_text, "visible_characters", page_text.length(), page_text.length() * char_duration)
	_typing_tween.finished.connect(func() -> void:
		_is_typing = false
		_update_more_indicator()
	)


func _update_more_indicator() -> void:
	if not _lbl_more_indicator:
		return

	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()

	_lbl_more_indicator.text = Locale.pick({"es": "▼ Toca para continuar", "en": "▼ Tap to continue"})
	_lbl_more_indicator.visible = true

	# Animar parpadeo del indicador
	_lbl_more_indicator.modulate.a = 1.0
	_indicator_tween = _lbl_more_indicator.create_tween().set_loops()
	_indicator_tween.tween_property(_lbl_more_indicator, "modulate:a", 0.3, 0.55).set_ease(Tween.EASE_IN_OUT)
	_indicator_tween.tween_property(_lbl_more_indicator, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_IN_OUT)


func _advance_dialogue() -> void:
	if _is_typing:
		_is_typing = false
		if _typing_tween and _typing_tween.is_valid():
			_typing_tween.kill()
		if _lbl_text:
			_lbl_text.visible_characters = _lbl_text.text.length()
		_update_more_indicator()
		return

	if _current_page_idx < _text_pages.size() - 1:
		_current_page_idx += 1
		_show_current_page()
	else:
		if _lbl_more_indicator:
			_lbl_more_indicator.visible = false
		if _indicator_tween and _indicator_tween.is_valid():
			_indicator_tween.kill()
		if _npc_id != "" and SceneRunner.is_presenter(self) and SceneRunner.is_active():
			SceneRunner.advance()
		else:
			_leave()


## Crea un botón con el estilo "novela visual" (acento del tema activo)
## reutilizable por las opciones de diálogo y el botón de salida.
func _make_vn_button(text: String, enabled: bool = true) -> Button:
	var btn := Button.new()
	btn.text = UiKit.strip_emojis(text)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 92)
	btn.add_theme_font_size_override("font_size", 34)
	_style_vn_button(btn, enabled)
	if enabled:
		btn.mouse_entered.connect(func() -> void: UiKit.pop(btn, 1.03, 0.15))
	return btn


## Aplica (o reaplica al cambiar de tema) el estilo "novela visual" de un botón
## ya creado por `_make_vn_button`, leyendo el acento y marco del tema activo.
func _style_vn_button(btn: Button, enabled: bool) -> void:
	UiKit.premium_button(btn, {"disabled": not enabled, "corner_radius": 16.0, "border_width": 3.0})


## Repinta el panel de diálogo, la placa de nombre y los botones de cabecera
## (info/salir) con el acento y marco del tema activo. Se llama al construir la UI y
## cada vez que el usuario cambia de tema (`Locale.theme_changed`).
func _apply_dialogue_theme() -> void:
	var acc: Color = UiKit.theme_color("accent", UiKit.ACCENT)
	if _dialogue_panel != null:
		UiKit.premium_frame(_dialogue_panel, {"pad": 0})
	if _name_plate != null:
		UiKit.premium_frame(_name_plate, {"pad": 0, "border_width": 3.0, "corner_radius": 14.0})
	if _lbl_vn_name != null:
		_lbl_vn_name.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	if _lbl_name != null:
		_lbl_name.add_theme_color_override("font_color", UiKit.theme_color("text", UiKit.TEXT))
	if _lbl_text != null:
		_lbl_text.add_theme_color_override("font_color", UiKit.theme_color("text", UiKit.TEXT))
	if _lbl_more_indicator != null:
		_lbl_more_indicator.add_theme_color_override("font_color", acc)
	if _btn_info != null:
		UiKit.premium_button(_btn_info, {"border_width": 2.0, "corner_radius": 12.0})
	if _btn_leave != null:
		UiKit.premium_button(_btn_leave, {"border_width": 2.0, "corner_radius": 12.0})
		_btn_leave.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	if _btn_rel != null:
		UiKit.premium_button(_btn_rel, {"border_width": 2.0, "corner_radius": 12.0})
	if _choices_box != null:
		for child in _choices_box.get_children():
			if child is Button:
				_style_vn_button(child, not (child as Button).disabled)


func _on_theme_changed(_theme_id: String) -> void:
	_apply_dialogue_theme()


## Dibuja los botones de opción que emite el motor: [{ text, index }] (ya
## localizados y filtrados por condición). Al pulsar, delega en SceneRunner.choose.
func _show_choices_from_runner(options: Array) -> void:
	if not _choices_box:
		return

	_choices_box.visible = true
	for child in _choices_box.get_children():
		child.queue_free()

	var buttons: Array[Button] = []
	for opt in options:
		var idx: int = int(opt.get("index", 0))
		var req := UiKit.check_option_facet_req(opt, _npc_id)
		var btn_text := String(opt.get("text", ""))
		var enabled := bool(req.get("met", true))
		if req.get("has_req", false) and not enabled:
			btn_text = "%s: %s" % [req.get("badge_text", "🔒"), btn_text]
		elif req.get("has_req", false):
			btn_text = "%s %s" % [req.get("icon", ""), btn_text]
		var btn := _make_vn_button(btn_text, enabled)
		if enabled:
			btn.pressed.connect(func() -> void: _on_choice_selected(idx))
		_choices_box.add_child(btn)
	_animate_buttons_in(buttons)
	if _npc_id == "poi_presa_001" and _npc_rect != null and _npc_rect.visible:
		QuestManager._show_animal_disclaimer()


## El jugador eligió una opción: el motor aplica su recompensa (nodo state) y
## continúa; pedimos autoguardado tras aplicar el cambio de estado.
func _on_choice_selected(index: int) -> void:
	SceneRunner.choose(index)
	SaveManager.request_autosave()


## Botón de continuar: con diálogo avanza la escena (el motor decide si sigue otro
## mensaje o termina → salir); sin diálogo (lugar descriptivo) sale al mundo.
func _show_continue_button() -> void:
	if not _choices_box:
		return

	_set_visual_state_choice()
	_choices_box.visible = true
	for child in _choices_box.get_children():
		child.queue_free()

	var btn := _make_vn_button(Locale.t("place_continue"))
	if _npc_id != "" and SceneRunner.is_presenter(self):
		btn.pressed.connect(func() -> void: SceneRunner.advance())
	else:
		btn.pressed.connect(_leave)
	_choices_box.add_child(btn)
	_animate_buttons_in([btn])


func _animate_buttons_in(buttons: Array) -> void:
	var delay := 0.0
	for btn in buttons:
		btn.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(delay).set_ease(Tween.EASE_OUT)
		delay += 0.15


# ══════════════════════════════════════════════════════════════════════════════
# GESTIÓN DE ENTRADAS (CLICKS Y TECLADO)
# ══════════════════════════════════════════════════════════════════════════════
func _on_dialogue_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_advance_dialogue()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_leave()


func _refresh_static_texts() -> void:
	if _btn_leave:
		_btn_leave.text = Locale.t("place_leave")
	if _lbl_name != null:
		_lbl_name.text = get_location_name()
	var root_scene: Node = get_tree().current_scene if get_tree() != null else null
	if root_scene != null and root_scene.has_method("refresh_hud_location_title"):
		root_scene.call("refresh_hud_location_title")


## Salida segura del lugar (botón "Salir" o ESC/TAB en pleno diálogo). Antes de
## desbloquear el movimiento, fuerza el avance en segundo plano por el resto del
## grafo (SceneRunner.skip_to_end()) para no perder banderas de quest que debían
## otorgarse en esta escena. Reentrante-seguro con `_leaving` (si el skip dispara
## scene_finished -> _close_view(), esta función no se re-ejecuta).
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_close_info_drawer()
	if SceneRunner.is_presenter(self) and SceneRunner.is_active():
		SceneRunner.skip_to_end()
	SceneRunner.release_presenter(self)
	GlobalState.is_movement_locked = false
	if GlobalEvents.has_signal("poi_exited"):
		GlobalEvents.poi_exited.emit(_npc_id)
	if _should_exit_directly_to_world() or _return_view != "city":
		SceneManager.go_to_world()
	else:
		SceneManager.back_to_city()
