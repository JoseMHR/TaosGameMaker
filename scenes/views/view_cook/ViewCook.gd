# ViewCook.gd
# Vista de la Cocina (se abre desde la Hoguera de la Base y campamentos).
# Muestra las recetas de GameConfig.COOKING_RECIPES, ingredientes necesarios y
# permite elaborar platos para curarse y conseguir bonificaciones.
class_name ViewCook
extends Control

# ─── REFERENCIAS UI ───────────────────────────────────────────────────────────
var _bg: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _root: VBoxContainer

var _title_lbl: Label
var _level_lbl: Label
var _hint_lbl: Label
var _btn_leave: Button

var _scroll: ScrollContainer
var _list: VBoxContainer

# Contenedor de Estado Vacío (cuando no hay ingredientes para cocinar)
var _empty_container: VBoxContainer
var _empty_title_lbl: Label
var _empty_desc_lbl: Label
var _btn_empty_back: Button
var _open_time_msec: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	get_viewport().size_changed.connect(_update_layout)
	GlobalState.state_updated.connect(_on_state_updated)
	Locale.locale_changed.connect(_refresh_texts)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_open_time_msec = Time.get_ticks_msec()
			_update_layout()
			_refresh_texts()
			_render()
	)
	_open_time_msec = Time.get_ticks_msec()
	_update_layout()
	_refresh_texts()
	_render()


func _on_state_updated() -> void:
	if is_visible_in_tree():
		_render()


## Configuración y apertura explícita de la cocina
func setup(_data: Dictionary = {}) -> void:
	_open_time_msec = Time.get_ticks_msec()
	_update_layout()
	_refresh_texts()
	_render()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# 1. Fondo oscuro translúcido con desenfoque / oscurecimiento
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.03, 0.05, 0.88)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.gui_input.connect(func(event: InputEvent) -> void:
		# Evitar que toques residuales de la transición o clics rápidos al abrir cierren la ventana
		if Time.get_ticks_msec() - _open_time_msec < 350:
			return
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			SceneManager.go_to_world())
	add_child(_bg)

	# 2. Contenedor centrado para garantizar alineación en cualquier resolución
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	# 3. Panel central modal
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 20, 2))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center.add_child(_panel)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 0)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(_root)

	# ── Cabecera ─────────────────────────────────────────────────────────────
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UiKit.header())
	_root.add_child(header)

	var hm := UiKit.margins(24, 24, 16, 16)
	header.add_child(hm)

	var hbox_hdr := HBoxContainer.new()
	hbox_hdr.add_theme_constant_override("separation", 16)
	hm.add_child(hbox_hdr)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 36)
	_title_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	UiKit.apply_heading(_title_lbl)
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox_hdr.add_child(_title_lbl)

	_level_lbl = Label.new()
	_level_lbl.add_theme_font_size_override("font_size", 26)
	_level_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_LIGHT)
	_level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox_hdr.add_child(_level_lbl)

	_btn_leave = Button.new()
	_btn_leave.custom_minimum_size = Vector2(170, 48)
	_btn_leave.add_theme_font_size_override("font_size", 24)
	_btn_leave.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	_btn_leave.pressed.connect(func() -> void: SceneManager.go_to_world())
	hbox_hdr.add_child(_btn_leave)

	# ── Pista / Subtítulo ───────────────────────────────────────────────────
	var hint_margin := UiKit.margins(24, 24, 14, 10)
	_root.add_child(hint_margin)

	_hint_lbl = Label.new()
	_hint_lbl.add_theme_font_size_override("font_size", 24)
	_hint_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_margin.add_child(_hint_lbl)

	# ── Estado Vacío (cuando no hay ingredientes para cocinar) ─────────────────
	_empty_container = VBoxContainer.new()
	_empty_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_container.add_theme_constant_override("separation", 18)
	_empty_container.visible = false
	_root.add_child(_empty_container)

	var empty_margin := UiKit.margins(32, 32, 32, 36)
	empty_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_container.add_child(empty_margin)

	var empty_vb := VBoxContainer.new()
	empty_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	empty_vb.add_theme_constant_override("separation", 16)
	empty_margin.add_child(empty_vb)

	var icon_lbl := Label.new()
	icon_lbl.text = "🍲"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 64)
	empty_vb.add_child(icon_lbl)

	_empty_title_lbl = Label.new()
	_empty_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_title_lbl.add_theme_font_size_override("font_size", 34)
	_empty_title_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
	UiKit.apply_heading(_empty_title_lbl)
	empty_vb.add_child(_empty_title_lbl)

	_empty_desc_lbl = Label.new()
	_empty_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_desc_lbl.add_theme_font_size_override("font_size", 24)
	_empty_desc_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	empty_vb.add_child(_empty_desc_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	empty_vb.add_child(spacer)

	var btn_center := CenterContainer.new()
	empty_vb.add_child(btn_center)

	_btn_empty_back = Button.new()
	_btn_empty_back.custom_minimum_size = Vector2(240, 56)
	_btn_empty_back.add_theme_font_size_override("font_size", 26)
	for st in ["normal", "hover", "pressed", "focus"]:
		_btn_empty_back.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_btn_empty_back.add_theme_color_override(col, UiKit.BG_DEEP)
	_btn_empty_back.pressed.connect(func() -> void: SceneManager.go_to_world())
	btn_center.add_child(_btn_empty_back)

	# ── Lista desplazable de recetas ─────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)

	var cm := UiKit.margins(20, 20, 10, 20)
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(cm)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	cm.add_child(_list)


# ══════════════════════════════════════════════════════════════════════════════
# RENDER Y ACTUALIZACIÓN DE TEXTOS
# ══════════════════════════════════════════════════════════════════════════════
func _refresh_texts() -> void:
	if _title_lbl:
		_title_lbl.text = "🍳  " + Locale.pick({"es": "Cocina y Fogones", "en": "Cooking & Hearth"})
	if _hint_lbl:
		_hint_lbl.text = Locale.pick({
			"es": "Prepara platos reconfortantes usando ingredientes frescos como pescado, carne o arroz.",
			"en": "Prepare hearty dishes using fresh ingredients such as fish, meat, or rice."
		})
	if _btn_leave:
		_btn_leave.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	if _btn_empty_back:
		_btn_empty_back.text = Locale.pick({"es": "Volver", "en": "Back"})
	if _empty_title_lbl:
		_empty_title_lbl.text = Locale.pick({
			"es": "No tienes nada para cocinar",
			"en": "You have nothing to cook"
		})
	if _empty_desc_lbl:
		_empty_desc_lbl.text = Locale.pick({
			"es": "No tienes pescado, carne ni otros ingredientes en tu inventario.\nConsigue provisiones explorando o pescando en los ríos para poder cocinar en los fogones.",
			"en": "You don't have fish, meat, or other ingredients in your inventory.\nGather provisions by exploring or fishing in rivers to cook at the hearth."
		})
	if _level_lbl:
		var cook_level: int = int(GlobalState.skills.get(GameConfig.COOKING_SKILL, {}).get("level", 1))
		_level_lbl.text = "⭐ " + (Locale.pick({"es": "Cocinero Nv. %d", "en": "Cooking Lv. %d"}) % cook_level)


func _count_owned_cooking_ingredients() -> int:
	var total: int = 0
	var counted: Dictionary = {}
	var recipes: Array = GameConfig.COOKING_RECIPES if GameConfig.COOKING_RECIPES is Array else []
	for recipe in recipes:
		if recipe is Dictionary:
			for ing in recipe.get("ingredients", []):
				var iid: String = String(ing.get("id", ""))
				if iid != "" and not counted.has(iid):
					counted[iid] = true
					total += int(GlobalState.get_item(iid).get("quantity", 0))
	return total


func _render() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()

	var cook_level: int = int(GlobalState.skills.get(GameConfig.COOKING_SKILL, {}).get("level", 1))
	if _level_lbl:
		_level_lbl.text = "⭐ " + (Locale.pick({"es": "Cocinero Nv. %d", "en": "Cooking Lv. %d"}) % cook_level)

	var owned_ingredients: int = _count_owned_cooking_ingredients()
	var has_ingredients: bool = (owned_ingredients > 0)

	if not has_ingredients:
		if _scroll: _scroll.visible = false
		if _empty_container: _empty_container.visible = true
		return

	if _scroll: _scroll.visible = true
	if _empty_container: _empty_container.visible = false

	var recipes: Array = GameConfig.COOKING_RECIPES if GameConfig.COOKING_RECIPES is Array else []
	var cookable_recipes: Array = []
	var other_recipes: Array = []

	for recipe in recipes:
		if not (recipe is Dictionary and recipe.has("ingredients")):
			continue
		var req_level: int = int(recipe.get("level_req", 1))
		var is_unlocked: bool = (cook_level >= req_level)
		var can_cook: bool = is_unlocked
		for ing in recipe.get("ingredients", []):
			var iid: String = String(ing.get("id", ""))
			var iqty: int = int(ing.get("qty", 1))
			if int(GlobalState.get_item(iid).get("quantity", 0)) < iqty:
				can_cook = false
				break
		if can_cook:
			cookable_recipes.append({"recipe": recipe, "unlocked": is_unlocked, "level": req_level})
		else:
			other_recipes.append({"recipe": recipe, "unlocked": is_unlocked, "level": req_level})

	# Mostrar recetas cocinables primero, luego el resto
	for item in cookable_recipes:
		_list.add_child(_make_recipe_card(item["recipe"], item["unlocked"], item["level"]))
	for item in other_recipes:
		_list.add_child(_make_recipe_card(item["recipe"], item["unlocked"], item["level"]))


func _make_recipe_card(recipe: Dictionary, is_unlocked: bool, req_level: int) -> Control:
	var out_id: String = String(recipe.get("out_id", ""))
	var ingredients: Array = recipe.get("ingredients", [])
	var out_icon: String = Design.get_item_icon(out_id)
	var out_name: String = Design.get_item_name(out_id)
	var restore: Dictionary = GlobalState.food_restore_values(out_id)

	var card := PanelContainer.new()
	if is_unlocked:
		card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.ACCENT, 14, 1))
	else:
		card.add_theme_stylebox_override("panel", UiKit.card(14))
		card.modulate = Color(1.0, 1.0, 1.0, 0.6)

	var margin := UiKit.margins(16, 16, 12, 12)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# Icono del resultado
	var icon_lbl := Label.new()
	icon_lbl.text = out_icon if is_unlocked else "🔒"
	icon_lbl.add_theme_font_size_override("font_size", 48)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	# Datos de la receta
	var vtext := VBoxContainer.new()
	vtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vtext.alignment = BoxContainer.ALIGNMENT_CENTER
	vtext.add_theme_constant_override("separation", 4)
	hbox.add_child(vtext)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	vtext.add_child(title_row)

	var dish_name_lbl := Label.new()
	dish_name_lbl.text = out_name
	dish_name_lbl.add_theme_font_size_override("font_size", 26)
	dish_name_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT if is_unlocked else UiKit.TEXT_DIM)
	UiKit.apply_heading(dish_name_lbl)
	title_row.add_child(dish_name_lbl)

	if not is_unlocked:
		var lock_tag := Label.new()
		lock_tag.text = "(%s)" % (Locale.pick({"es": "Requiere Nv. %d", "en": "Requires Lv. %d"}) % req_level)
		lock_tag.add_theme_font_size_override("font_size", 22)
		lock_tag.add_theme_color_override("font_color", UiKit.WARN)
		title_row.add_child(lock_tag)

	# Efectos de recuperación (HP / MP)
	var hp_heal := int(restore.get("hp", 0))
	var mp_heal := int(restore.get("mp", 0))
	var effects_parts: Array[String] = []
	if hp_heal > 0:
		effects_parts.append("+%d HP" % hp_heal)
	if mp_heal > 0:
		effects_parts.append("+%d MP" % mp_heal)
	if effects_parts.is_empty():
		effects_parts.append(Locale.pick({"es": "Comida nutritiva", "en": "Nutritious food"}))

	var makes_lbl := Label.new()
	makes_lbl.text = " · ".join(effects_parts)
	makes_lbl.add_theme_font_size_override("font_size", 22)
	makes_lbl.add_theme_color_override("font_color", UiKit.GOOD if is_unlocked else UiKit.TEXT_DIM)
	vtext.add_child(makes_lbl)

	# Ingredientes necesarios y comprobación de inventario
	var has_all_ingredients := is_unlocked and not ingredients.is_empty()
	var ing_strings: Array[String] = []
	for ing in ingredients:
		var iid := String(ing.get("id", ""))
		var iqty := int(ing.get("qty", 1))
		var iowned: int = int(GlobalState.get_item(iid).get("quantity", 0))
		if iowned < iqty:
			has_all_ingredients = false
		var iname := Design.get_item_name(iid)
		var iicon := Design.get_item_icon(iid)
		ing_strings.append("%s %s x%d (tienes: %d)" % [iicon, iname, iqty, iowned])

	var ing_lbl := Label.new()
	ing_lbl.text = "Ingredientes: " + " + ".join(ing_strings)
	ing_lbl.add_theme_font_size_override("font_size", 22)
	ing_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED if has_all_ingredients else UiKit.WARN)
	ing_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vtext.add_child(ing_lbl)

	# Botón de acción
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 56)
	btn.add_theme_font_size_override("font_size", 24)

	if not is_unlocked:
		btn.text = Locale.pick({"es": "🔒 Bloqueado", "en": "🔒 Locked"})
		btn.disabled = true
	elif has_all_ingredients:
		btn.text = "🍳 " + Locale.pick({"es": "Cocinar", "en": "Cook"})
		btn.disabled = false
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UiKit.button_primary(10))
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(col, UiKit.BG_DEEP)
		btn.pressed.connect(func() -> void: _on_cook(recipe))
	else:
		btn.text = Locale.pick({"es": "Faltan ingredientes", "en": "Need ingredients"})
		btn.disabled = true

	hbox.add_child(btn)
	return card


# ══════════════════════════════════════════════════════════════════════════════
# COCINAR
# ══════════════════════════════════════════════════════════════════════════════
func _on_cook(recipe: Dictionary) -> void:
	var out_name: String = Design.get_item_name(recipe.get("out_id", ""))
	var result: String = GlobalState.cook_recipe(recipe)
	match result:
		"ok":
			AudioManager.play_ui("success")
			_show_cook_result_banner(true, Locale.pick({
				"es": "¡Éxito! ¡Has cocinado %s!" % out_name,
				"en": "Success! You cooked %s!" % out_name
			}))
			SaveManager.request_autosave()
		"fail_luck":
			AudioManager.play_ui("error")
			_show_cook_result_banner(false, Locale.pick({
				"es": "¡Te salió un desastre, menudo desperdicio de ingredientes!",
				"en": "It's a disaster, what a waste of ingredients!"
			}))
			SaveManager.request_autosave()
		_:
			AudioManager.play_ui("error")
			UiKit.toast(self, Locale.pick({
				"es": "No tienes los ingredientes necesarios.",
				"en": "You do not have the required ingredients."
			}), UiKit.BAD)
	_render()


## Banner grande y vistoso con el resultado de cocinar (éxito/desastre): a
## diferencia de `UiKit.toast` (pequeño y periférico), este ocupa el centro de
## la pantalla con un "pop" de escala, para que el jugador SIENTA que ha
## pasado algo real al pulsar Cocinar (ver GameConfig.COOK_FAIL_CHANCE).
func _show_cook_result_banner(success: bool, text: String) -> void:
	var accent: Color = UiKit.GOOD if success else UiKit.BAD
	var overlay := CenterContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(clampf(get_viewport_rect().size.x * 0.7, 300.0, 520.0), 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, accent, 20, 3))
	overlay.add_child(panel)

	var margin := UiKit.margins(30, 30, 24, 24)
	panel.add_child(margin)

	var lbl := Label.new()
	lbl.text = ("🎉  " if success else "💥  ") + text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", accent)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.apply_heading(lbl)
	margin.add_child(lbl)

	UiKit.animate_in(panel, 0.22)
	get_tree().create_timer(1.3).timeout.connect(func() -> void:
		UiKit.animate_out(panel, 0.25, overlay.queue_free)
	)


func _update_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _bg != null and is_instance_valid(_bg):
		_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _center != null and is_instance_valid(_center):
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _panel == null or not is_instance_valid(_panel):
		return
	var sz := get_viewport_rect().size
	var is_landscape := sz.x > sz.y
	var pw: float = clampf(sz.x * 0.85, 480.0, 920.0) if is_landscape else clampf(sz.x * 0.94, 320.0, 720.0)
	var ph: float = clampf(sz.y * 0.84, 420.0, 720.0) if is_landscape else clampf(sz.y * 0.84, 480.0, 800.0)
	_panel.custom_minimum_size = Vector2(pw, ph)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		SceneManager.go_to_world()

