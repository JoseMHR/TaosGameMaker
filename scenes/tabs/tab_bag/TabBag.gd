# TabBag.gd
# Controlador de la pestaña de la Bolsa/Inventario.
# Filtra los ítems por categoría e implementa el uso de consumibles.
class_name TabBag
extends Control

# ─── REFERENCIAS UI (construida por código, barra de categorías abajo) ────────
var _grid: GridContainer          # Rejilla del inventario
var _cat_btns: Dictionary = {}    # key de categoría -> Button
var _scroll: ScrollContainer
var _catbar_panel_h: PanelContainer
var _catbar_panel_v: PanelContainer
var _catbar_h: HBoxContainer
var _catbar_v: VBoxContainer
var _landscape_cats: bool = false

# ─── ESTADO INTERNO ──────────────────────────────────────────────────────────
var _active_category: String = "important"
var _dirty: bool = true

## Categorías de la bolsa: 4 buckets claros. El remapeo es NO DESTRUCTIVO
## (no se toca items.json): cada bucket agrupa una o varias categorías crudas de los
## ítems (`includes`). Así "Comida", "Utillaje" y "Otros" desaparecen sin re-etiquetar
## nada: la comida entra en Consumibles, las herramientas en Importante y el resto de
## materias primas en Materiales.
const CATEGORIES: Array = [
	{"key": "important",  "icon": "⭐",   "includes": ["important", "tool"]},
	{"key": "consumable", "icon": "🧪",  "includes": ["consumable", "edible"]},
	{"key": "equipment",  "icon": "🛡️", "includes": ["equipment"]},
	{"key": "material",   "icon": "📦",  "includes": ["other"]},
]


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
var _is_updating_layout: bool = false


func _ready() -> void:
	_build_shell()
	GlobalState.state_updated.connect(_refresh_ui)
	Locale.locale_changed.connect(_on_locale_changed)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_update_responsive_layout()
			call_deferred("_update_responsive_layout")
			if _dirty:
				_refresh_ui()
	)
	resized.connect(_render_inventory)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	call_deferred("_update_responsive_layout")
	_switch_category("important")


func _update_responsive_layout() -> void:
	if not is_inside_tree() or _is_updating_layout or _scroll == null:
		return
	_is_updating_layout = true
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		_is_updating_layout = false
		return
	var is_landscape := sz.x > sz.y
	const MARGIN: float = 14.0
	const CAT_W: float = 170.0
	const CAT_H: float = 110.0

	for entry in CATEGORIES:
		var key: String = entry["key"]
		var b: Button = _cat_btns.get(key, null) as Button
		if b == null:
			continue
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_landscape:
			b.custom_minimum_size = Vector2(0, 110)
			b.add_theme_font_size_override("font_size", 30)
		else:
			b.custom_minimum_size = Vector2(0, 100)
			b.add_theme_font_size_override("font_size", 30)
		b.text = "%s\n%s" % [entry["icon"], Locale.t("bag_" + key)]

	# Reparentar botones al contenedor activo solo cuando cambia orientación.
	if _landscape_cats != is_landscape:
		_landscape_cats = is_landscape
		if is_landscape:
			_refresh_v_catbar()
		else:
			for entry in CATEGORIES:
				var key: String = entry["key"]
				var b: Button = _cat_btns[key]
				if b.get_parent() != null:
					b.get_parent().remove_child(b)
				_catbar_h.add_child(b)

	if is_landscape:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		custom_minimum_size = Vector2.ZERO

		_catbar_panel_h.visible = false
		_catbar_panel_v.visible = true
		_catbar_panel_v.anchor_left = 0.0
		_catbar_panel_v.anchor_right = 0.0
		_catbar_panel_v.anchor_top = 0.0
		_catbar_panel_v.anchor_bottom = 1.0
		_catbar_panel_v.offset_left = 0.0
		_catbar_panel_v.offset_right = CAT_W
		_catbar_panel_v.offset_top = 0.0
		_catbar_panel_v.offset_bottom = 0.0

		_scroll.anchor_left = 0.0
		_scroll.anchor_right = 1.0
		_scroll.anchor_top = 0.0
		_scroll.anchor_bottom = 1.0
		_scroll.offset_left = CAT_W + MARGIN
		_scroll.offset_right = -MARGIN
		_scroll.offset_top = MARGIN
		_scroll.offset_bottom = -MARGIN
	else:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		anchor_left = 0.04
		anchor_right = 0.96
		anchor_top = 0.04
		anchor_bottom = 0.96
		offset_left = 0.0
		offset_right = 0.0
		offset_top = 10.0
		offset_bottom = -10.0
		custom_minimum_size = Vector2.ZERO

		_catbar_panel_h.visible = true
		_catbar_panel_v.visible = false
		_catbar_panel_h.anchor_left = 0.0
		_catbar_panel_h.anchor_right = 1.0
		_catbar_panel_h.anchor_top = 1.0
		_catbar_panel_h.anchor_bottom = 1.0
		_catbar_panel_h.offset_left = 0.0
		_catbar_panel_h.offset_right = 0.0
		_catbar_panel_h.offset_top = -CAT_H
		_catbar_panel_h.offset_bottom = 0.0
		_catbar_panel_h.custom_minimum_size = Vector2(0, CAT_H)

		_scroll.anchor_left = 0.0
		_scroll.anchor_right = 1.0
		_scroll.anchor_top = 0.0
		_scroll.anchor_bottom = 1.0
		_scroll.offset_left = MARGIN
		_scroll.offset_right = -MARGIN
		_scroll.offset_top = MARGIN
		_scroll.offset_bottom = -(CAT_H + MARGIN)

	_is_updating_layout = false


## Construye el armazón: fondo, rejilla desplazable y barra de
## categorías que en horizontal pasa al lateral izquierdo.
func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Antes esta pestaña dibujaba su propio "ModalCard" con
	# borde cian, redundante ahora que vive embebida dentro del panel dorado
	# del Hub (CharacterHubModal._content_panel). Se elimina ese envoltorio y
	# el contenido rellena directamente el marco que ya proporciona el Hub.
	var holder := Control.new()
	holder.name = "Holder"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)

	# Rejilla desplazable del inventario.
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(_scroll)
	_enable_drag_scroll(_scroll)

	var margin := UiKit.margins(12, 12, 12, 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.columns = 2
	margin.add_child(_grid)

	# Barra de categorías inferior (vertical).
	_catbar_panel_h = PanelContainer.new()
	_catbar_panel_h.name = "CatBarPanelH"
	var bar_style_h := StyleBoxFlat.new()
	bar_style_h.bg_color = UiKit.BG_BASE
	bar_style_h.border_width_top = 2
	bar_style_h.border_color = UiKit.BORDER
	_catbar_panel_h.add_theme_stylebox_override("panel", bar_style_h)
	holder.add_child(_catbar_panel_h)

	_catbar_h = HBoxContainer.new()
	_catbar_h.name = "CatBarH"
	_catbar_h.alignment = BoxContainer.ALIGNMENT_CENTER
	_catbar_h.add_theme_constant_override("separation", 6)
	_catbar_panel_h.add_child(_catbar_h)

	# Barra de categorías lateral (horizontal).
	_catbar_panel_v = PanelContainer.new()
	_catbar_panel_v.name = "CatBarPanelV"
	var bar_style_v := StyleBoxFlat.new()
	bar_style_v.bg_color = UiKit.BG_BASE
	bar_style_v.border_width_right = 2
	bar_style_v.border_color = UiKit.BORDER
	_catbar_panel_v.add_theme_stylebox_override("panel", bar_style_v)
	holder.add_child(_catbar_panel_v)

	_catbar_v = VBoxContainer.new()
	_catbar_v.name = "CatBarV"
	_catbar_v.alignment = BoxContainer.ALIGNMENT_BEGIN
	_catbar_v.add_theme_constant_override("separation", 6)
	_catbar_panel_v.add_child(_catbar_v)

	_cat_btns.clear()
	for entry in CATEGORIES:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		var key: String = entry["key"]
		b.text = "%s\n%s" % [entry["icon"], Locale.t("bag_" + key)]
		b.pressed.connect(func() -> void: _switch_category(key))
		_catbar_h.add_child(b)
		_cat_btns[key] = b
	_refresh_v_catbar()


var _sp_v: Control = null
var _btn_close_v: Button = null

func _refresh_v_catbar() -> void:
	if _catbar_v == null:
		return
	for c in _catbar_v.get_children():
		_catbar_v.remove_child(c)

	for entry in CATEGORIES:
		var key: String = entry["key"]
		if _cat_btns.has(key):
			var b: Button = _cat_btns[key]
			if b.get_parent() != null:
				b.get_parent().remove_child(b)
			_catbar_v.add_child(b)

	if _sp_v == null:
		_sp_v = Control.new()
		_sp_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catbar_v.add_child(_sp_v)

	# Redundante cuando esta pestaña vive embebida en el Hub (que ya tiene su
	# propio botón "🚪 Cerrar" arriba a la derecha, ver `CharacterHubModal`):
	# se omite ahí y se conserva solo para el uso standalone (vía barra de
	# pestañas inferior, sin Hub alrededor que ofrezca otra forma de cerrar).
	if not _is_inside_hub():
		if _btn_close_v == null:
			_btn_close_v = Button.new()
			_btn_close_v.text = "🚪 " + Locale.pick({"es": "Cerrar", "en": "Close"})
			_btn_close_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_btn_close_v.custom_minimum_size = Vector2(0, 60)
			_btn_close_v.add_theme_font_size_override("font_size", 20)
			for st in ["normal", "hover", "pressed", "focus"]:
				_btn_close_v.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.BAD))
			_btn_close_v.pressed.connect(_on_close_pressed)
		_catbar_v.add_child(_btn_close_v)
	elif _btn_close_v != null and _btn_close_v.get_parent() != null:
		_btn_close_v.get_parent().remove_child(_btn_close_v)


## ¿Esta pestaña vive embebida dentro de un `CharacterHubModal` (caso normal,
## vía el Hub) en vez de como escena de primer nivel standalone (uso histórico
## vía la barra de pestañas inferior)?
func _is_inside_hub() -> bool:
	var n: Node = get_parent()
	while n != null:
		if n is CharacterHubModal:
			return true
		n = n.get_parent()
	return false

## Cierra el Hub si esta pestaña vive embebida dentro de él (caso normal); si
## no tiene un CharacterHubModal como ancestro (uso histórico como escena de
## primer nivel vía GameRoot), conserva el comportamiento antiguo de volver
## directamente al mundo.
func _on_close_pressed() -> void:
	var n: Node = get_parent()
	while n != null:
		if n is CharacterHubModal:
			n.close()
			return
		n = n.get_parent()
	SceneManager.go_to_world()


func _refresh_ui() -> void:
	if GlobalState.is_test_room and not GlobalState.has_item("tent"):
		GlobalState.grant_all_game_items(10)
	if not is_visible_in_tree():
		_dirty = true
		return
	_dirty = false
	for key in _cat_btns:
		UiKit.style_segmented_tab(_cat_btns[key], key == _active_category)
	_render_inventory()


## Reacciona al cambio de idioma: reetiqueta la barra de categorías y refresca.
func _on_locale_changed() -> void:
	for entry in CATEGORIES:
		if _cat_btns.has(entry["key"]):
			(_cat_btns[entry["key"]] as Button).text = "%s\n%s" % [entry["icon"], Locale.t("bag_" + entry["key"])]
	_refresh_ui()


# ══════════════════════════════════════════════════════════════════════════════
# CATEGORÍAS
# ══════════════════════════════════════════════════════════════════════════════
func _switch_category(category: String) -> void:
	_active_category = category
	_refresh_ui()


## Categorías crudas de items.json que agrupa el bucket activo (ver CATEGORIES).
func _active_includes() -> Array:
	for entry in CATEGORIES:
		if entry["key"] == _active_category:
			return entry.get("includes", [_active_category])
	return [_active_category]


## ¿El ítem se puede USAR directamente desde la bolsa? Solo pociones y similares:
## `usable` en items.json y con efecto heal/mana (los que aplica use_consumable).
## La comida (efecto hp/mp) se come en la hoguera y las bombas se colocan en el
## mundo, así que NO son usables desde aquí aunque compartan bucket Consumibles.
func _is_bag_usable(item_id: String) -> bool:
	if item_id == "":
		return false
	var def: Dictionary = Design.get_item(item_id)
	if def.is_empty() or not bool(def.get("usable", false)):
		return false
	var effects: Dictionary = def.get("effects", {})
	# BUG: solo comprobaba las claves legado `heal`/`mana` (enteras), pero
	# todas las pociones actuales (potion.json/potion_mid.json/potion_high.json/
	# elixir_max.json) usan `heal_pct`/`mana_pct` (ver `use_consumable` en
	# CookingBuffsManager.gd) — nunca se detectaban como usables desde la
	# bolsa y tocarlas no hacía nada.
	return float(effects.get("heal_pct", 0.0)) > 0.0 or float(effects.get("mana_pct", 0.0)) > 0.0 \
		or int(effects.get("heal", 0)) > 0 or int(effects.get("mana", 0)) > 0


# ══════════════════════════════════════════════════════════════════════════════
# RENDERIZADO DEL INVENTARIO
# ══════════════════════════════════════════════════════════════════════════════
func _render_inventory() -> void:
	if not is_visible_in_tree():
		_dirty = true
		return
	# Limpiar grid
	for child in _grid.get_children():
		child.queue_free()

	# Filtrar items por el bucket activo (remapeo no destructivo: cada bucket agrupa
	# una o varias categorías crudas de items.json, ver CATEGORIES.includes).
	var includes: Array = _active_includes()
	var filtered: Array[Dictionary] = []

	# Si la categoría activa incluye equipo, añadir primero los ítems actualmente equipados
	if includes.has("equipment"):
		for slot in GlobalState.equipped.keys():
			var eq: EquipmentResource = GlobalState.equipped[slot]
			if eq != null:
				filtered.append({
					"id": eq.id,
					"name": eq.name,
					"quantity": 1,
					"category": "equipment",
					"icon": eq.icon,
					"resource": eq,
					"is_equipped": true,
					"equipped_slot": slot,
				})

	for item in GlobalState.inventory:
		if includes.has(item.get("category")):
			var eq_res = item.get("resource")
			var already_in_equipped := false
			if eq_res != null:
				for slot in GlobalState.equipped.keys():
					if GlobalState.equipped[slot] == eq_res:
						already_in_equipped = true
						break
			if not already_in_equipped:
				filtered.append(item)

	if filtered.is_empty():
		_grid.columns = 1
		var lbl_empty := Label.new()
		lbl_empty.text = Locale.t("bag_empty")
		lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_empty.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		lbl_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_empty.add_theme_font_size_override("font_size", 20)
		_grid.add_child(lbl_empty)
		return

	# Rejilla de cuadrados con columnas adaptadas al ancho disponible.
	_grid.columns = _columns_for_width()
	for item in filtered:
		_grid.add_child(_make_item_card(item))


## Crea una tarjeta cuadrada para un ítem, con icono, nombre y contador (si >1).
func _make_item_card(item: Dictionary) -> Control:
	# "Usable desde la bolsa" se decide POR ÍTEM (no por bucket): solo pociones y
	# similares (usable + efecto heal/mana). Comida/bombas aparecen en Consumibles
	# pero no se usan aquí (comer es en la hoguera; la bomba se coloca en el mundo).
	var is_consumable: bool = _is_bag_usable(String(item.get("id", "")))
	var is_equipped: bool = bool(item.get("is_equipped", false))

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = UiKit.SURFACE
	
	# Color de borde según la RAREZA real del equipo, o la categoría para el resto.
	var border_col: Color = UiKit.BORDER
	match _active_category:
		"important":
			border_col = Color(UiKit.MAGIC.r, UiKit.MAGIC.g, UiKit.MAGIC.b, 0.6)
		"consumable":
			border_col = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.6)
		"equipment":
			var eq: EquipmentResource = item.get("resource")
			var rc: Color = UiKit.rarity_color(eq.rarity) if (eq != null and eq.rarity != "") else UiKit.MP
			if is_equipped:
				border_col = UiKit.GOOD
				style.set_border_width_all(3)
				style.shadow_color = Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.35)
				style.shadow_size = 7
			else:
				border_col = Color(rc.r, rc.g, rc.b, 0.75)
		"material":
			border_col = Color(UiKit.TEXT_FAINT.r, UiKit.TEXT_FAINT.g, UiKit.TEXT_FAINT.b, 0.5)
			
	style.border_color = border_col
	if not is_equipped:
		style.set_border_width_all(2)
		style.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.18)
		style.shadow_size = 5
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var inner := Control.new()
	inner.custom_minimum_size = Vector2(0, 250)
	# Dejar pasar el toque hasta card.gui_input (si no, este Control lo intercepta
	# con su MOUSE_FILTER por defecto STOP y no se puede usar el consumible).
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(cc)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(vbox)

	var icon := Label.new()
	icon.text = item.get("icon", "❓")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 58)
	vbox.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(0, 32)
	name_lbl.add_theme_font_size_override("font_size", 25)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	vbox.add_child(name_lbl)

	# Estadísticas de equipo (si las tiene)
	var stats_text := _get_item_bonuses_text(item)
	if stats_text != "":
		var stat_lbl := Label.new()
		stat_lbl.text = stats_text
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_lbl.add_theme_font_size_override("font_size", 21)
		stat_lbl.add_theme_color_override("font_color", UiKit.GOOD)
		vbox.add_child(stat_lbl)
		# Un equipo con varios bonus (p. ej. "STR +5, DEX +3, VIT +4…") puede
		# envolver en 2-3 líneas: dar más margen vertical a la tarjeta para que
		# el texto no se salga del recuadro (incidencia reportada).
		inner.custom_minimum_size.y = 310.0

	var is_usable_important: bool = (_active_category == "important" and item.get("id") == "tent")

	if is_consumable or is_usable_important:
		var hint := Label.new()
		hint.text = Locale.pick({"es": "Toca para establecer base", "en": "Tap to establish base"}) if is_usable_important else Locale.t("bag_use")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 22)
		hint.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		vbox.add_child(hint)

	# Contador en la esquina superior derecha (o insignia "E" si está actualmente equipado).
	var qty: int = item.get("quantity", 1)
	if is_equipped:
		var e_badge := PanelContainer.new()
		var e_style := StyleBoxFlat.new()
		e_style.bg_color = UiKit.GOOD
		e_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
		e_style.set_border_width_all(2)
		e_style.set_corner_radius_all(10)
		e_style.content_margin_left = 8
		e_style.content_margin_right = 8
		e_style.content_margin_top = 2
		e_style.content_margin_bottom = 2
		e_style.shadow_color = Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.5)
		e_style.shadow_size = 5
		e_badge.add_theme_stylebox_override("panel", e_style)
		e_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var e_lbl := Label.new()
		e_lbl.text = "E"
		e_lbl.add_theme_font_size_override("font_size", 23)
		e_lbl.add_theme_color_override("font_color", UiKit.BG_DEEP)
		e_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e_badge.add_child(e_lbl)
		inner.add_child(e_badge)
		e_badge.anchor_left = 1.0
		e_badge.anchor_right = 1.0
		e_badge.anchor_top = 0.0
		e_badge.anchor_bottom = 0.0
		e_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		e_badge.grow_vertical = Control.GROW_DIRECTION_END
		e_badge.offset_left = -38
		e_badge.offset_top = 8
		e_badge.offset_right = -8
		e_badge.offset_bottom = 38
	elif qty > 1:
		var badge := PanelContainer.new()
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = UiKit.ACCENT
		bstyle.set_corner_radius_all(12)
		bstyle.content_margin_left = 10
		bstyle.content_margin_right = 10
		bstyle.content_margin_top = 4
		bstyle.content_margin_bottom = 4
		badge.add_theme_stylebox_override("panel", bstyle)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var blbl := Label.new()
		blbl.text = "x%d" % qty
		blbl.add_theme_font_size_override("font_size", 20)
		blbl.add_theme_color_override("font_color", UiKit.BG_DEEP)
		blbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(blbl)
		inner.add_child(badge)
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.anchor_top = 0.0
		badge.anchor_bottom = 0.0
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_END
		badge.offset_left = -70
		badge.offset_top = 8
		badge.offset_right = -8
		badge.offset_bottom = 38

	# Insignia de nivel de REFINAMIENTO (+N, ver task5.md) en la esquina superior
	# IZQUIERDA — la derecha ya la ocupa el contador de cantidad de arriba.
	var eq_res = item.get("resource")
	if eq_res is EquipmentResource and eq_res.refine_level > 0:
		var rbadge := PanelContainer.new()
		var rstyle := StyleBoxFlat.new()
		rstyle.bg_color = UiKit.COLOR_GOLD_PRIMARY
		rstyle.set_corner_radius_all(12)
		rstyle.content_margin_left = 10
		rstyle.content_margin_right = 10
		rstyle.content_margin_top = 4
		rstyle.content_margin_bottom = 4
		rbadge.add_theme_stylebox_override("panel", rstyle)
		rbadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rlbl := Label.new()
		rlbl.text = "+%d" % eq_res.refine_level
		rlbl.add_theme_font_size_override("font_size", 20)
		rlbl.add_theme_color_override("font_color", UiKit.COLOR_BG_DARK)
		rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rbadge.add_child(rlbl)
		inner.add_child(rbadge)
		rbadge.anchor_left = 0.0
		rbadge.anchor_right = 0.0
		rbadge.anchor_top = 0.0
		rbadge.anchor_bottom = 0.0
		rbadge.grow_horizontal = Control.GROW_DIRECTION_END
		rbadge.grow_vertical = Control.GROW_DIRECTION_END
		rbadge.offset_left = 8
		rbadge.offset_top = 8
		rbadge.offset_right = 62
		rbadge.offset_bottom = 38

	# Equipamiento, Consumibles y Tienda de Campaña: tocar la tarjeta para interactuar
	var item_cat: String = String(item.get("category", ""))
	var is_equipment: bool = (item_cat == "equipment")
	if is_consumable or is_usable_important or is_equipment:
		var item_id: String = item.get("id", "")
		var press_pos_ref := [Vector2.ZERO]
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
				press_pos_ref[0] = ev.global_position
			elif (ev is InputEventScreenTouch and not ev.pressed) or (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
				if (press_pos_ref[0] as Vector2).distance_to(ev.global_position) < 14.0:
					if is_consumable:
						_use_consumable(item_id, card)
					elif is_usable_important:
						_use_important_item(item_id)
					elif is_equipment:
						_inspect_equipment(item)
		)

	return card


## Habilita el desplazamiento vertical por arrastre con ratón o pantalla táctil en ScrollContainer.
func _enable_drag_scroll(scroll: ScrollContainer) -> void:
	var drag_state := {"active": false, "start_y": 0.0, "scroll_start": 0}
	scroll.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch:
			if ev.pressed:
				drag_state["active"] = true
				drag_state["start_y"] = ev.global_position.y
				drag_state["scroll_start"] = scroll.scroll_vertical
			else:
				drag_state["active"] = false
		elif (ev is InputEventMouseMotion or ev is InputEventScreenDrag) and bool(drag_state["active"]):
			var dy: float = ev.global_position.y - float(drag_state["start_y"])
			scroll.scroll_vertical = maxi(0, int(float(drag_state["scroll_start"]) - dy))
	)


## Devuelve una cadena formateada con las estadísticas del equipo (ej: "Fuerza +5 · Defensa F. +12").
func _get_item_bonuses_text(item: Dictionary) -> String:
	var bonuses: Dictionary = {}
	var eq: EquipmentResource = item.get("resource")
	if eq != null and not eq.stat_bonuses.is_empty():
		# Valores EFECTIVOS (con el +10%/nivel de refinamiento ya aplicado, ver
		# task5.md), no los crudos guardados en `stat_bonuses`.
		for k in eq.stat_bonuses.keys():
			bonuses[k] = eq.effective_stat_bonus(String(k))
	else:
		var item_id: String = String(item.get("id", ""))
		var def: Dictionary = Design.get_item(item_id)
		bonuses = def.get("stat_bonuses", {})
		if bonuses.is_empty():
			bonuses = def.get("bonuses", {})

	if bonuses.is_empty():
		return ""

	var parts: Array[String] = []
	for k in bonuses:
		var val: int = int(bonuses[k])
		if val != 0:
			var stat_key: String = String(k)
			var stat_name: String = Locale.t("stat_" + stat_key)
			if stat_name.begins_with("stat_"):
				stat_name = stat_key.capitalize()
			parts.append("%s %+d" % [stat_name, val])
	return " · ".join(parts)


## Número de columnas de la rejilla según el ancho actual (mín 2, máx 5).
## Tarjetas más grandes → menos columnas para que se vean bien en el móvil.
func _columns_for_width() -> int:
	var w: float = size.x
	if w <= 0.0:
		w = 1080.0
	return clampi(int(w / 300.0), 2, 5)


# ══════════════════════════════════════════════════════════════════════════════
# COMPORTAMIENTO DE POCIONES / CONSUMIBLES
# ══════════════════════════════════════════════════════════════════════════════
func _use_consumable(item_id: String, card: Control = null) -> void:
	# El efecto de cada consumible se define en el campo "effects" de items.json
	# (poción, pescado cocinado, …) y lo aplica GlobalState.use_consumable()
	# (ya reproduce el SFX "heal"). Aquí solo añadimos el feedback visual: pop
	# de la tarjeta + aviso de lo recuperado.
	var hp_before := GlobalState.hp
	var mp_before := GlobalState.mp
	if GlobalState.use_consumable(item_id):
		SaveManager.request_autosave()
		if card != null and is_instance_valid(card):
			UiKit.pop(card, 1.08, 0.2)
		var gained: Array[String] = []
		if GlobalState.hp > hp_before:
			gained.append("❤️ +%d" % (GlobalState.hp - hp_before))
		if GlobalState.mp > mp_before:
			gained.append("💧 +%d" % (GlobalState.mp - mp_before))
		if not gained.is_empty():
			UiKit.toast(self, " ".join(gained), UiKit.GOOD)


func _use_important_item(item_id: String) -> void:
	if item_id == "tent":
		var player_coord := GlobalState.player_pos
		if not GlobalState.can_establish_base_at(player_coord):
			UiKit.toast(self, Locale.pick({
				"es": "No puedes montar la tienda aquí: la casilla y la de abajo (para la hoguera) deben estar despejadas.",
				"en": "Cannot pitch tent here: current tile and the tile below it (for campfire) must be clear."
			}), UiKit.HP)
			return
		GlobalState.establish_base_at(player_coord)
		GlobalState.remove_item("tent", 1)
		AudioManager.play_ui("success")
		GlobalState.state_updated.emit()
		_render_inventory()
		UiKit.toast(self, Locale.pick({"es": "🏕️ ¡Campamento montado!", "en": "🏕️ Camp established!"}), UiKit.GOOD)
		if GlobalState.camp_level == 1 and OrbBarksManager != null:
			OrbBarksManager.trigger_bark(Locale.pick({
				"es": "¡Menudo palacio de tela! Ahora monta la hoguera justo debajo: te servirá para cocinar tus provisiones y recuperar fuerzas... que entre tú y yo, tienes una pinta de hecho polvo que da pena.",
				"en": "Quite the canvas palace! Now build the campfire right below it to cook your provisions and recover your strength... because honestly, you look completely wrecked."
			}), 7.0)


## Modal de inspección y equipamiento rápido desde la bolsa con comparativa de stats.
func _inspect_equipment(item: Dictionary) -> void:
	var item_id: String = String(item.get("id", ""))
	var eq: EquipmentResource = item.get("resource")
	if eq == null:
		var def: Dictionary = Design.get_item(item_id)
		eq = EquipmentResource.new()
		eq.id = item_id
		eq.name = String(item.get("name", def.get("name", {}).get("es", item_id)))
		eq.slot = String(def.get("slot", "weapon"))
		eq.icon = String(item.get("icon", def.get("icon", "⚔️")))
		eq.stat_bonuses = def.get("stat_bonuses", {}).duplicate()
		eq.rarity = String(def.get("rarity", "common"))

	var current: EquipmentResource = GlobalState.equipped.get(eq.slot)
	var is_currently_equipped: bool = bool(item.get("is_equipped", false)) or (current != null and (current == eq or (current.id == eq.id and current.refine_level == eq.refine_level)))

	var rc: Color = UiKit.rarity_color(eq.rarity) if eq.rarity != "" else UiKit.ACCENT
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.02, 0.05, 0.8)
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.SURFACE, rc, 20, 2))
	center.add_child(panel)

	var margin := UiKit.margins(24, 24, 20, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	# Cabecera
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)

	var icon_lbl := Label.new()
	icon_lbl.text = eq.icon
	icon_lbl.add_theme_font_size_override("font_size", 36)
	head.add_child(UiKit.with_corner_badge(icon_lbl, UiKit.refine_badge(eq.refine_level)))

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_vb)

	var name_lbl := Label.new()
	name_lbl.text = eq.name
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", rc)
	title_vb.add_child(name_lbl)

	var slot_lbl := Label.new()
	slot_lbl.text = Locale.t("equip_slot_" + eq.slot) if not Locale.t("equip_slot_" + eq.slot).begins_with("equip_slot_") else eq.slot.capitalize()
	slot_lbl.add_theme_font_size_override("font_size", 18)
	slot_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	title_vb.add_child(slot_lbl)

	# Estadísticas de esta pieza
	var stats_str := _get_item_bonuses_text(item)
	if stats_str != "":
		var st_lbl := Label.new()
		st_lbl.text = "📊 " + stats_str
		st_lbl.add_theme_font_size_override("font_size", 20)
		st_lbl.add_theme_color_override("font_color", UiKit.GOOD)
		vb.add_child(st_lbl)

	# Comparativa con el objeto equipado en la misma ranura
	var comp_panel := PanelContainer.new()
	comp_panel.add_theme_stylebox_override("panel", UiKit.card(false, 10, 8))
	vb.add_child(comp_panel)

	var comp_vb := VBoxContainer.new()
	comp_vb.add_theme_constant_override("separation", 4)
	var comp_m := UiKit.margins(10, 10, 6, 6)
	comp_m.add_child(comp_vb)
	comp_panel.add_child(comp_m)

	if current != null:
		var cur_lbl := Label.new()
		cur_lbl.text = Locale.pick({
			"es": "Actualmente equipado: %s" % current.name,
			"en": "Currently equipped: %s" % current.name
		})
		cur_lbl.add_theme_font_size_override("font_size", 17)
		cur_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		comp_vb.add_child(cur_lbl)
	else:
		var cur_lbl := Label.new()
		cur_lbl.text = Locale.pick({
			"es": "Ranura actualmente vacía",
			"en": "Slot currently empty"
		})
		cur_lbl.add_theme_font_size_override("font_size", 17)
		cur_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		comp_vb.add_child(cur_lbl)

	# Botones de acción
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)

	if is_currently_equipped:
		var btn_unequip := Button.new()
		btn_unequip.text = Locale.pick({"es": "🛡️ Desequipar", "en": "🛡️ Unequip"})
		btn_unequip.custom_minimum_size = Vector2(160, 42)
		UiKit.premium_button(btn_unequip, {"bg_color": Color(0.20, 0.06, 0.08, 0.9), "border_color": UiKit.BAD})
		btn_unequip.add_theme_color_override("font_color", UiKit.BAD)
		btn_unequip.pressed.connect(func():
			GlobalState.unequip_item(eq.slot)
			AudioManager.play_ui("cancel")
			layer.queue_free()
			_render_inventory()
			UiKit.toast(self, Locale.pick({"es": "%s desequipado" % eq.name, "en": "%s unequipped" % eq.name}), UiKit.TEXT_DIM)
		)
		btn_row.add_child(btn_unequip)
	else:
		var btn_equip := Button.new()
		btn_equip.text = Locale.pick({"es": "⚔️ Equipar", "en": "⚔️ Equip"})
		btn_equip.custom_minimum_size = Vector2(160, 42)
		UiKit.premium_button(btn_equip)
		btn_equip.pressed.connect(func():
			GlobalState.equip_resource(eq)
			AudioManager.play_ui("confirm")
			layer.queue_free()
			_render_inventory()
			UiKit.toast(self, Locale.pick({"es": "¡%s equipado!" % eq.name, "en": "%s equipped!" % eq.name}), rc)
		)
		btn_row.add_child(btn_equip)

	var btn_close := Button.new()
	btn_close.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	btn_close.custom_minimum_size = Vector2(110, 42)
	btn_close.add_theme_stylebox_override("normal", UiKit.button_ghost())
	btn_close.add_theme_stylebox_override("hover", UiKit.button_ghost())
	btn_close.pressed.connect(func():
		AudioManager.play_sfx("click")
		layer.queue_free()
	)
	btn_row.add_child(btn_close)

	UiKit.pop(panel, 1.05, 0.2)


# La barra de categorías se construye y conecta por código en _build_shell().
