# TravelSystem.gd
# ─────────────────────────────────────────────────────────────────────────────
# VIAJE RÁPIDO: overlay con los destinos descubiertos (incluida la tienda de
# campaña si está montada); al elegir uno, cobra el oro del transportista,
# funde a negro y teletransporta.
#
# Extraído de TabWorld3D.gd (antes en el #region "OBJETOS INTERACTIVOS" de un
# único fichero de ~5300 líneas). Usa `world._travel_overlay` (estado propio
# de TabWorld3D) para saber si el overlay ya está abierto, por eso cada función
# recibe `world: Node` explícito como primer parámetro en vez de
# depender de un `self` implícito.
# ─────────────────────────────────────────────────────────────────────────────
class_name TravelSystem
extends RefCounted


## Abre un overlay con los destinos descubiertos; al elegir uno, funde y teletransporta.
static func open_travel_menu(world: Node) -> void:
	if world._travel_overlay != null and is_instance_valid(world._travel_overlay):
		return
	if SceneRunner.is_active():
		return
	AudioManager.play_sfx("click")
	var destinations := GlobalState.get_travel_points()
	# La tienda de campaña, si está montada, es también un destino de viaje.
	if GlobalState.has_built_base and GlobalState.base_coord != Vector2i(-1, -1):
		destinations.append({"coord": GlobalState.base_coord, "name": Locale.pick({"es": "Campamento", "en": "Camp"}), "icon": "⛺", "raw_name": true})

	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close_travel_overlay(world))
	ov.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.SURFACE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.6), 22, 2))
	center.add_child(panel)
	var margin := UiKit.margins(28, 28, 24, 24)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "🚚  " + Locale.pick({"es": "Transportista", "en": "Transporter"})
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vb.add_child(title)

	var cost := GameConfig.TRAVEL_GOLD_COST
	var cost_lbl := Label.new()
	cost_lbl.text = Locale.pick({"es": "Cada viaje cuesta 💰 %d oro", "en": "Each trip costs 💰 %d gold"}) % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	vb.add_child(cost_lbl)

	for dest in destinations:
		var coord: Vector2i = dest["coord"]
		var here: bool = coord == world.player_pos
		var raw_name: bool = bool(dest.get("raw_name", false))
		var dest_cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		var dest_name: String
		if dest_cell != null:
			dest_name = dest_cell.get_display_name()
		elif raw_name:
			dest_name = String(dest["name"])
		else:
			dest_name = Locale.translate_cell_name(String(dest["name"]))
		var can_afford := GlobalState.gold >= cost
		var btn := Button.new()
		if here:
			var here_tag := Locale.pick({
				"es": "  (aquí)", "en": "  (here)", "fr": "  (ici)",
				"it": "  (qui)", "de": "  (hier)", "zh": "  (在此)", "ja": "  (現在地)"
			})
			btn.text = "%s  %s%s" % [String(dest["icon"]), dest_name, here_tag]
		else:
			btn.text = "%s  %s   (💰 %d)" % [String(dest["icon"]), dest_name, cost]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.disabled = here or not can_afford
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.ACCENT))
		btn.add_theme_color_override("font_color", UiKit.TEXT)
		btn.pressed.connect(func() -> void: travel_to(world, coord))
		vb.add_child(btn)

	# Botón CANCELAR explícito: tocar fuera del panel también cierra, pero al no
	# siempre resultar evidente (bug reportado: "no me deja salir del menú"),
	# esto garantiza una salida clara y visible en cualquier caso.
	var cancel := Button.new()
	cancel.text = Locale.pick({"es": "Cancelar", "en": "Cancel"})
	cancel.custom_minimum_size = Vector2(0, 52)
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.pressed.connect(func() -> void: close_travel_overlay(world))
	vb.add_child(cancel)

	world._travel_overlay = ov
	world.add_child(ov)


## Ejecuta el viaje: cobra el oro del transportista, cierra el overlay, funde a
## negro, teletransporta y regresa.
static func travel_to(world: Node, coord: Vector2i) -> void:
	if coord == world.player_pos:
		return
	var cost := GameConfig.TRAVEL_GOLD_COST
	if GlobalState.gold < cost:
		UiKit.toast(world, Locale.pick({"es": "No tienes suficiente oro para el viaje.", "en": "Not enough gold for the trip."}), UiKit.HP)
		return
	GlobalState.gold -= cost
	GlobalState.state_updated.emit()
	close_travel_overlay(world)
	AudioManager.play_sfx("click")
	Juice.transition(func() -> void: world.teleport_player_to(coord))
	SaveManager.request_autosave()


static func close_travel_overlay(world: Node) -> void:
	if world._travel_overlay != null and is_instance_valid(world._travel_overlay):
		world._travel_overlay.queue_free()
	world._travel_overlay = null
