# BestiaryViewer.gd
# ─────────────────────────────────────────────────────────────────────────────
# VISOR DE BESTIARIO — overlay reutilizable construido por código.
#
# Muestra el conocimiento PERSISTENTE de los enemigos enfrentados. Los datos viven
# en GlobalState.bestiary (enemy_id -> {seen, kills, weak, resist}) y se rellenan
# durante el combate. Las debilidades/resistencias mostradas son SOLO las
# DESCUBIERTAS golpeando con cada elemento (conocimiento real, no el catálogo
# completo). El catálogo base de enemigos vive en enemies.json (Design).
#
# Antes vivía como sub-pestaña de Personaje; ahora pertenece a la pantalla
# Información. Se cierra con el botón o al tocar el fondo.
# ─────────────────────────────────────────────────────────────────────────────
class_name BestiaryViewer
extends Control

## Emitida cuando el usuario cierra el visor.
signal closed

## Modo embebido: rellena su padre sin fondo oscuro ni botón de cerrar, para usarse
## dentro de la pestaña Información (TabInfo). Asignar ANTES de añadir al árbol.
var embedded: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	if embedded:
		var m := UiKit.margins(30, 30, 26, 26)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(m)
		m.add_child(vbox)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.02, 0.04, 0.92)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.gui_input.connect(_on_bg_input)
		add_child(bg)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(760, 0)
		UiKit.premium_dialog_panel(panel, UiKit.theme_color("accent", UiKit.ACCENT), 26)
		center.add_child(panel)

		var margin := UiKit.margins(40, 40, 36, 36)
		panel.add_child(margin)
		margin.add_child(vbox)

	# Orden: descubiertos primero (jefes arriba), luego no descubiertos.
	var ids: Array = Design.enemies.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var seen_a := _seen(a)
		var seen_b := _seen(b)
		if seen_a != seen_b:
			return seen_a # true primero
		var def_a: Dictionary = Design.get_enemy(a)
		var def_b: Dictionary = Design.get_enemy(b)
		var boss_a: bool = def_a.get("archetype", "") == "boss" or bool(def_a.get("is_boss", false))
		var boss_b: bool = def_b.get("archetype", "") == "boss" or bool(def_b.get("is_boss", false))
		if boss_a != boss_b:
			return boss_a
		return a < b
	)
	var discovered := 0
	for id in ids:
		if _seen(String(id)):
			discovered += 1

	# ── Cabecera: título + progreso ──────────────────────────────────────────
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	title.text = "📖  " + Locale.t("char_bestiary")
	vbox.add_child(title)

	var progress := Label.new()
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 22)
	progress.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	progress.text = Locale.t("bestiary_progress") % [discovered, ids.size()]
	vbox.add_child(progress)

	var intro := Label.new()
	intro.text = Locale.t("bestiary_intro")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	vbox.add_child(intro)

	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(div)

	# ── Lista de fichas (con scroll) ─────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	if discovered == 0:
		var empty := Label.new()
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		empty.text = Locale.t("bestiary_empty")
		list.add_child(empty)
	else:
		for id in ids:
			list.add_child(_build_card(String(id)))

	# ── Botón cerrar (solo overlay; en TabInfo navega la barra de pestañas) ──────
	if not embedded:
		var btn_close := Button.new()
		btn_close.custom_minimum_size = Vector2(0, 72)
		btn_close.add_theme_font_size_override("font_size", 24)
		btn_close.text = Locale.t("menu_back")
		btn_close.pressed.connect(func() -> void: closed.emit())
		vbox.add_child(btn_close)


## ¿El enemigo ha sido VISTO al menos una vez? (entrada de bestiario con seen=true).
func _seen(enemy_id: String) -> bool:
	var e = GlobalState.bestiary.get(enemy_id, {})
	return e is Dictionary and bool(e.get("seen", false))


## Ficha de un enemigo. Si no se ha descubierto, se muestra oculta (❔ + "???");
## si se ha visto, muestra icono, nombre, bajas y las debilidades/resistencias
## DESCUBIERTAS durante el combate.
const FAMILY_LABELS: Dictionary = {
	"beast":     {"icon": "🐺", "es": "Bestia", "en": "Beast"},
	"monster":   {"icon": "👹", "es": "Monstruo", "en": "Monster"},
	"magical":   {"icon": "🔮", "es": "Mágico", "en": "Magical"},
	"humanoid":  {"icon": "⚔️", "es": "Humanoide", "en": "Humanoid"},
	"construct": {"icon": "⚙️", "es": "Autómata", "en": "Construct"},
	"giant":     {"icon": "🗿", "es": "Gigante", "en": "Giant"},
}


func _build_card(enemy_id: String) -> PanelContainer:
	var def: Dictionary = Design.get_enemy(enemy_id)
	var e = GlobalState.bestiary.get(enemy_id, {})
	var seen := e is Dictionary and bool(e.get("seen", false))
	var kills := int(e.get("kills", 0)) if e is Dictionary else 0
	var weak: Array = (e.get("weak", []) as Array) if e is Dictionary and e.get("weak") is Array else []
	var resist: Array = (e.get("resist", []) as Array) if e is Dictionary and e.get("resist") is Array else []
	var is_boss: bool = def.get("archetype", "") == "boss" or bool(def.get("is_boss", false))
	var fam_key := String(def.get("family", "monster"))

	var col: Color = (UiKit.COLOR_GOLD_PRIMARY if is_boss else Color(0.55, 0.45, 0.7)) if seen else Color(0.35, 0.35, 0.4, 0.5)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(col, 14, 14))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	# Cabecera: icono + nombre + badge de jefe/familia + bajas
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var icon_lbl := Label.new()
	icon_lbl.text = String(def.get("icon", "❔")) if seen else "❔"
	icon_lbl.add_theme_font_size_override("font_size", 28)
	head.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = Locale.pick(def.get("name", {})) if seen else Locale.t("bestiary_unknown_name")
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", (UiKit.COLOR_GOLD_PRIMARY if is_boss else UiKit.TEXT) if seen else UiKit.TEXT_FAINT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(name_lbl)

	if seen:
		if is_boss:
			var boss_badge := Label.new()
			boss_badge.text = "👑 " + Locale.pick({"es": "Jefe", "en": "Boss"})
			boss_badge.add_theme_font_size_override("font_size", 16)
			boss_badge.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
			boss_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			head.add_child(boss_badge)
		elif FAMILY_LABELS.has(fam_key):
			var f_info: Dictionary = FAMILY_LABELS[fam_key]
			var fam_badge := Label.new()
			fam_badge.text = "%s %s" % [f_info["icon"], Locale.pick(f_info)]
			fam_badge.add_theme_font_size_override("font_size", 15)
			fam_badge.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			fam_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			head.add_child(fam_badge)

		var kills_lbl := Label.new()
		kills_lbl.text = "💀 %d" % kills
		kills_lbl.add_theme_font_size_override("font_size", 15)
		kills_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		kills_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(kills_lbl)
	vb.add_child(head)

	if not seen:
		return card

	# Debilidades y resistencias DESCUBIERTAS
	if weak.is_empty() and resist.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = Locale.t("bestiary_unknown_reaction")
		none_lbl.add_theme_font_size_override("font_size", 14)
		none_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		vb.add_child(none_lbl)
	else:
		var elem_hb := HBoxContainer.new()
		elem_hb.add_theme_constant_override("separation", 14)
		vb.add_child(elem_hb)

		if not weak.is_empty():
			var w := Label.new()
			w.text = "🔻 %s: %s" % [Locale.t("bestiary_weak"), _element_icons(weak)]
			w.add_theme_font_size_override("font_size", 15)
			w.add_theme_color_override("font_color", UiKit.GOOD)
			elem_hb.add_child(w)
		if not resist.is_empty():
			var r := Label.new()
			r.text = "🛡️ %s: %s" % [Locale.t("bestiary_resist"), _element_icons(resist)]
			r.add_theme_font_size_override("font_size", 15)
			r.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			elem_hb.add_child(r)
	return card


## Iconos concatenados de una lista de elementos (usa el catálogo GameConfig.ELEMENTS).
func _element_icons(elements: Array) -> String:
	var out: Array = []
	for el in elements:
		var icon := String(GameConfig.ELEMENTS.get(String(el), {}).get("icon", ""))
		out.append(icon if icon != "" else String(el))
	return "  ".join(out)


## Cierra el visor al tocar el fondo oscuro (fuera del panel).
func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		closed.emit()
