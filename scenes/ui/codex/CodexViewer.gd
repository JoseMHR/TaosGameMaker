# CodexViewer.gd
# ─────────────────────────────────────────────────────────────────────────────
# CÓDICE DE CURIOSIDADES (Task 2) — visor reutilizable construido por código.
#
# Muestra el "Códice de Descubrimientos": las entradas de lore ambiental que el
# jugador desbloquea inspeccionando POIs de inspección y conociendo PNJs
# singulares (token de recompensa `discover:<id>`, ver Design._apply_token).
#
# Cada entrada del catálogo `data/codex.json` (Design.codex) se dibuja como una
# tarjeta coleccionable:
#   · BLOQUEADA  → silueta "❓" + pista enigmática de ubicación (`hint`).
#   · DESCUBIERTA → icono real, título (tipografía de encabezado), lore completo
#                   y fecha/hora del hallazgo (`GlobalState.lore_discovered[id]`).
# Arriba, un contador de progreso "Descubrimientos: X / Y". Al 100 %, un banner
# celebra el título *Erudito de lo Absurdo* (world_flag `codex_complete`).
#
# Se usa embebido dentro de la pestaña Información (TabInfo), igual que
# EncyclopediaViewer/BestiaryViewer. De solo lectura. Data-driven.
# ─────────────────────────────────────────────────────────────────────────────
class_name CodexViewer
extends Control

## Emitida cuando el usuario cierra el visor (modo overlay).
signal closed

## Modo embebido: rellena su padre sin fondo oscuro ni botón de cerrar, para usarse
## dentro de la pestaña Información (TabInfo). Asignar ANTES de añadir al árbol.
var embedded: bool = false

## Orden y etiqueta de las 7 zonas canónicas del mundo (PROGRESSION.md).
const ZONE_ORDER: Array = ["zona_1", "zona_2", "zona_3", "zona_4", "zona_5", "zona_6", "zona_7"]
const ZONE_LABELS: Dictionary = {
	"zona_1": {"es": "🛡️ Zona 1: Valle del Yelmo", "en": "🛡️ Zone 1: Helm Valley"},
	"zona_2": {"es": "❄️ Zona 2: Travesía Helada", "en": "❄️ Zone 2: Frozen Crossing"},
	"zona_3": {"es": "🌿 Zona 3: Praderas de Sylphrena", "en": "🌿 Zone 3: Sylphrena Meadows"},
	"zona_4": {"es": "👑 Zona 4: Reino de Celestia", "en": "👑 Zone 4: Kingdom of Celestia"},
	"zona_5": {"es": "🏜️ Zona 5: Desierto de Gloriam", "en": "🏜️ Zone 5: Gloriam Desert"},
	"zona_6": {"es": "⚡ Zona 6: Ruinas de Arcanum", "en": "⚡ Zone 6: Arcanum Ruins"},
	"zona_7": {"es": "✨ Zona 7: Templo del Origen", "en": "✨ Zone 7: Temple of Origin"},
}


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

	# ── Cabecera ───────────────────────────────────────────────────────────────
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	title.text = "🔍  " + Locale.pick({"es": "Códice de Curiosidades", "en": "Codex of Curiosities"})
	vbox.add_child(title)

	# ── Contador de progreso + barra ─────────────────────────────────────────────
	var total := Design.codex_total()
	var discovered := 0
	for cid in Design.codex.keys():
		if GlobalState.is_lore_discovered(String(cid)):
			discovered += 1
	vbox.add_child(_build_progress(discovered, total))

	# ── Banner de completismo (solo al 100 %). ──────────────────────────────────
	if total > 0 and discovered >= total:
		vbox.add_child(_build_completion_banner())

	vbox.add_child(_divider())

	# ── Scroll con la rejilla de tarjetas por zona ──────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	if total == 0:
		list.add_child(_empty_note())
	else:
		_build_zones(list)

	# ── Botón cerrar (solo overlay). ─────────────────────────────────────────────
	if not embedded:
		var btn_close := Button.new()
		btn_close.custom_minimum_size = Vector2(0, 72)
		btn_close.add_theme_font_size_override("font_size", 24)
		btn_close.text = Locale.t("menu_back")
		btn_close.pressed.connect(func() -> void: closed.emit())
		vbox.add_child(btn_close)


## Cabecera con el contador "Descubrimientos: X / Y" y una barra de progreso.
func _build_progress(discovered: int, total: int) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.12)
	sb.border_color = UiKit.ACCENT
	sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	row.add_child(vb)

	var hb := HBoxContainer.new()
	vb.add_child(hb)

	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", UiKit.TEXT)
	lbl.text = Locale.pick({"es": "Lugares y Curiosidades Visitadas", "en": "Places & Curiosities Visited"})
	hb.add_child(lbl)

	var count_lbl := Label.new()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_size_override("font_size", 24)
	count_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	count_lbl.text = "%d / %d" % [discovered, total]
	hb.add_child(count_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.min_value = 0
	bar.max_value = maxi(total, 1)
	bar.value = discovered
	bar.show_percentage = false
	vb.add_child(bar)

	return row


## Banner del premio de completismo (aparece solo al descubrir todo).
func _build_completion_banner() -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.bg_color = Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.14)
	sb.border_color = UiKit.GOOD
	sb.set_border_width_all(2)
	row.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	row.add_child(vb)

	var t := Label.new()
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", UiKit.GOOD)
	t.text = "🏆  " + Locale.pick({"es": "Erudito de lo Absurdo", "en": "Scholar of the Absurd"})
	UiKit.apply_heading(t)
	vb.add_child(t)

	var d := Label.new()
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 18)
	d.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	d.text = Locale.pick({
		"es": "Has catalogado cada rareza del mundo. Recompensa: +5 % de experiencia permanente.",
		"en": "You've catalogued every oddity in the world. Reward: +5% permanent experience.",
	})
	vb.add_child(d)

	return row


## Dibuja las tarjetas agrupadas por zona geográfica (Zona 1, Zona 2, Zona 3).
func _build_zones(list: VBoxContainer) -> void:
	var by_zone: Dictionary = {}
	for cid in Design.codex_ids():
		var z := String(Design.get_codex_entry(cid).get("zone", "zona_1"))
		if not by_zone.has(z):
			by_zone[z] = []
		(by_zone[z] as Array).append(cid)

	var zones: Array = []
	for z in ZONE_ORDER:
		if by_zone.has(z):
			zones.append(z)
	for z in by_zone.keys():
		if not (z in zones):
			zones.append(z)

	for z in zones:
		list.add_child(_section_label(_zone_label(String(z))))
		for cid in by_zone[z]:
			list.add_child(_build_codex_card(String(cid)))


## Tarjeta de una entrada del Códice:
## - VISITADO: icono real + título real + descripción completa + fecha de visita.
## - PENDIENTE: silueta "❓" + título anónimo "??? (Por visitar)" + pista enigmática.
func _build_codex_card(codex_id: String) -> PanelContainer:
	var entry := Design.get_codex_entry(codex_id)
	var discovered := GlobalState.is_lore_discovered(codex_id)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	sb.bg_color = UiKit.SURFACE_ALT if discovered else UiKit.SURFACE_ALT.darkened(0.35)
	sb.border_color = UiKit.theme_color("accent", UiKit.ACCENT) if discovered else UiKit.BORDER
	sb.set_border_width_all(2 if discovered else 1)
	card.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)

	var icon := Label.new()
	icon.custom_minimum_size = Vector2(56, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 38)
	icon.text = String(entry.get("icon", "📜")) if discovered else "❓"
	if not discovered:
		icon.modulate = Color(1, 1, 1, 0.45)
	hb.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	hb.add_child(texts)

	var header_hb := HBoxContainer.new()
	header_hb.add_theme_constant_override("separation", 8)
	texts.add_child(header_hb)

	var title_lbl := Label.new()
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 24)
	if discovered:
		title_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		title_lbl.text = Locale.pick(entry.get("title", {}))
		UiKit.apply_heading(title_lbl)
	else:
		title_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		title_lbl.text = Locale.pick({"es": "??? (Lugar por visitar)", "en": "??? (Unvisited place)"})
	header_hb.add_child(title_lbl)

	var status_badge := Label.new()
	status_badge.add_theme_font_size_override("font_size", 16)
	if discovered:
		status_badge.add_theme_color_override("font_color", UiKit.GOOD)
		status_badge.text = "✅ " + Locale.pick({"es": "Visitado", "en": "Visited"})
	else:
		status_badge.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		status_badge.text = "🔒 " + Locale.pick({"es": "Pendiente", "en": "Pending"})
	header_hb.add_child(status_badge)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	if discovered:
		body.add_theme_color_override("font_color", UiKit.TEXT)
		body.text = Locale.pick(entry.get("lore", {}))
	else:
		body.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		body.text = Locale.pick(entry.get("hint", {"es": "Explora esta zona para descubrir este punto de interés.", "en": "Explore this area to discover this point of interest."}))
	texts.add_child(body)

	if discovered:
		var when := int(GlobalState.lore_discovered.get(codex_id, 0))
		if when > 0:
			var date_lbl := Label.new()
			date_lbl.add_theme_font_size_override("font_size", 13)
			date_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
			date_lbl.text = "🕓 " + Time.get_datetime_string_from_unix_time(when, true).replace("T", "  ")
			texts.add_child(date_lbl)

	return card


func _zone_label(zone: String) -> String:
	if ZONE_LABELS.has(zone):
		return Locale.pick(ZONE_LABELS[zone])
	return zone.capitalize()


## Etiqueta de sección (encabezado de categoría).
func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", UiKit.TEXT)
	lbl.text = text
	return lbl


## Nota cuando el catálogo está vacío (codex.json ausente o sin entradas).
func _empty_note() -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	sb.bg_color = UiKit.SURFACE_ALT
	sb.border_color = UiKit.BORDER
	sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	lbl.text = Locale.pick({
		"es": "El mundo aún guarda sus secretos. Explora para llenar este códice.",
		"en": "The world still keeps its secrets. Explore to fill this codex.",
	})
	row.add_child(lbl)
	return row


## Divisor horizontal tenue.
func _divider() -> ColorRect:
	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 2)
	return div


## Cierra el visor al tocar el fondo oscuro (fuera del panel).
func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		closed.emit()
