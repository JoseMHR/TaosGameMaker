# CampTentSystem.gd
# ─────────────────────────────────────────────────────────────────────────────
# CAMPAMENTO — TIENDA (checkpoint) + HOGUERA (comer/cocinar/descansar/tiempo) +
# MENÚ DE CONSTRUCCIÓN (GameConfig.CAMP_STRUCTURES). La curación NO es gratis
# (filosofía ): solo se recupera vida/maná COMIENDO (ver CampEatMenu).
# Descansar/Pasar tiempo solo avanzan el reloj.
#
# Extraído de TabWorld3D.gd (antes en el #region "OBJETOS INTERACTIVOS" de un
# único fichero de ~5300 líneas). A diferencia de las maquetas de buildings/
# (sin coupling), este sistema SÍ necesita volver a llamar a TabWorld3D para
# varias cosas (overlays, _rebuild_tiles, _spawn_world_float, _tiles_root...):
# por eso cada función recibe `world: Node` explícito como primer
# parámetro en vez de depender de un `self` implícito.
# ─────────────────────────────────────────────────────────────────────────────
class_name CampTentSystem
extends RefCounted


## TIENDA DE CAMPAÑA: al entrar, ofrece DESCANSAR. De día, "Descansar hasta la
## noche"; de noche, "Pasar la noche" (hasta el amanecer). En ambos casos el reloj
## avanza hasta la fase opuesta. La tienda sigue siendo el punto de reaparición.
static func open_tent_menu(world: Node) -> void:
	var is_day: bool = TimeManager.is_day()
	var root: Control = UiKit.overlay(world)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 24, 3))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	var margin := UiKit.margins(36, 36, 32, 32)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = Locale.pick({"es": "⛺ Base nv %d", "en": "⛺ Base lv %d"}) % GlobalState.camp_level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(title)

	var rest_label: Dictionary = {"es": "😴 Descansar hasta la noche", "en": "😴 Rest until night"} if is_day \
		else {"es": "🌙 Pasar la noche", "en": "🌙 Spend the night"}

	var rest := Button.new()
	rest.text = Locale.pick(rest_label)
	rest.custom_minimum_size = Vector2(0, 84)
	rest.add_theme_font_size_override("font_size", 28)
	for st in ["normal", "hover", "pressed", "focus"]:
		rest.add_theme_stylebox_override(st, UiKit.button_primary(14))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		rest.add_theme_color_override(col, UiKit.BG_DEEP)
	rest.pressed.connect(func() -> void:
		root.queue_free()
		tent_rest(world, is_day))
	vbox.add_child(rest)

	# Información de la siguiente mejora del campamento
	var next_key := GlobalState.camp_current_structure_key()
	if next_key != "":
		var next_def := GlobalState.get_camp_structure_def(next_key)
		var next_box := PanelContainer.new()
		next_box.add_theme_stylebox_override("panel", UiKit.panel(UiKit.SURFACE, UiKit.BORDER, 14, 1))
		var next_vbox := VBoxContainer.new()
		next_vbox.add_theme_constant_override("separation", 6)
		var next_m := UiKit.margins(16, 16, 12, 12)
		next_m.add_child(next_vbox)
		next_box.add_child(next_m)

		var next_title := Label.new()
		next_title.text = "%s  %s (%s %d)" % [String(next_def.get("icon", "🏗️")), Locale.pick(next_def.get("name", {})), Locale.pick({"es": "Nivel", "en": "Level"}), GlobalState.camp_level + 1]
		next_title.add_theme_font_size_override("font_size", 20)
		next_title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		next_vbox.add_child(next_title)

		var next_desc := Label.new()
		next_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next_desc.add_theme_font_size_override("font_size", 15)
		next_desc.add_theme_color_override("font_color", UiKit.TEXT)
		next_desc.text = Locale.pick(next_def.get("desc", {}))
		next_vbox.add_child(next_desc)

		var next_cost := Label.new()
		next_cost.add_theme_font_size_override("font_size", 16)
		next_cost.add_theme_color_override("font_color", UiKit.GOOD)
		next_cost.text = "%s: %s" % [Locale.pick({"es": "Coste", "en": "Cost"}), format_costs(next_def.get("costs", {}))]
		next_vbox.add_child(next_cost)

		var next_hint := Label.new()
		next_hint.add_theme_font_size_override("font_size", 14)
		next_hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		next_hint.text = Locale.pick({
			"es": "💡 Pisa una casilla libre alrededor de tu base para construirlo.",
			"en": "💡 Step onto a free tile around your base to build it."
		})
		next_vbox.add_child(next_hint)

		vbox.add_child(next_box)

	# El transportista de la tienda: viaja a cualquier ciudad ya visitada (cobra oro).
	if GlobalState.get_travel_points().size() > 0:
		var travel_btn := Button.new()
		travel_btn.text = Locale.pick({"es": "🚚 Viajar", "en": "🚚 Travel"})
		travel_btn.custom_minimum_size = Vector2(0, 84)
		travel_btn.add_theme_font_size_override("font_size", 28)
		for st in ["normal", "hover", "pressed", "focus"]:
			travel_btn.add_theme_stylebox_override(st, UiKit.button_outline(14))
		travel_btn.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		travel_btn.pressed.connect(func() -> void:
			root.queue_free()
			TravelSystem.open_travel_menu(world))
		vbox.add_child(travel_btn)

	var close := Button.new()
	close.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	close.custom_minimum_size = Vector2(0, 72)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func() -> void: root.queue_free())
	vbox.add_child(close)


## Ejecuta el descanso en la tienda: avanza el reloj hasta el inicio de la noche (si
## era de día) o hasta el amanecer (si era de noche). NO cura (filosofía ).
static func tent_rest(world: Node, was_day: bool) -> void:
	var target: float = GameConfig.NIGHT_START_HOUR if was_day else GameConfig.DAY_START_HOUR
	advance_to_hour(target)
	var msg: Dictionary = {"es": "🌙 Cae la noche…", "en": "🌙 Night falls…"} if was_day \
		else {"es": "☀️ Amanece…", "en": "☀️ Dawn breaks…"}
	world._spawn_world_float(Locale.pick(msg), UiKit.ACCENT_SOFT)
	SaveManager.request_autosave()


## HOGUERA CONSTRUIBLE: diálogo de confirmación para levantar la hoguera en la
## casilla `coord` (a la derecha de la tienda) a cambio de madera (CAMP_WOOD_COST).
static func open_campfire_build_confirm(world: Node, coord: Vector2i) -> void:
	var cost: int = GameConfig.CAMP_WOOD_COST
	var wood: int = int(GlobalState.get_item("wood").get("quantity", 0))
	var enough: bool = wood >= cost

	var root: Control = UiKit.overlay(world, 0.55)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 20, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var margin := UiKit.margins(32, 32, 28, 28)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = Locale.pick({"es": "🔥 Construir Hoguera", "en": "🔥 Build Campfire"})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", UiKit.TEXT)
	body.text = Locale.pick({
		"es": "Levanta una hoguera junto a tu tienda para cocinar tus provisiones.",
		"en": "Set up a campfire next to your tent to cook your provisions."})
	vbox.add_child(body)

	var cost_lbl := Label.new()
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.add_theme_color_override("font_color", UiKit.GOOD if enough else UiKit.HP)
	cost_lbl.text = "🪵 %d / %d" % [wood, cost]
	vbox.add_child(cost_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var cancel := Button.new()
	cancel.text = Locale.pick({"es": "Cancelar", "en": "Cancel"})
	cancel.custom_minimum_size = Vector2(180, 58)
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.pressed.connect(func() -> void: root.queue_free())
	row.add_child(cancel)

	var build := Button.new()
	build.text = Locale.pick({"es": "🔨 Construir (%d 🪵)" % cost, "en": "🔨 Build (%d 🪵)" % cost})
	build.custom_minimum_size = Vector2(260, 58)
	build.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "pressed", "focus"]:
		build.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		build.add_theme_color_override(col, UiKit.BG_DEEP)
	build.disabled = not enough
	build.pressed.connect(func() -> void:
		root.queue_free()
		build_campfire_confirmed(world, coord))
	row.add_child(build)


## Ejecuta la construcción de la hoguera tras confirmar: cobra la madera, coloca la
## hoguera real (deja de mostrarse el fantasma) y refresca el mundo.
static func build_campfire_confirmed(world: Node, coord: Vector2i) -> void:
	var cost: int = GameConfig.CAMP_WOOD_COST
	var err := GlobalState.build_campfire_at(coord, cost)
	if err != "":
		var msg: Dictionary = {"es": "No se pudo construir la hoguera.", "en": "Couldn't build the campfire."}
		if err == "no_resources":
			msg = {"es": "No tienes madera suficiente.", "en": "Not enough wood."}
		UiKit.toast(world, Locale.pick(msg), UiKit.HP)
		return
	AudioManager.play_sfx("gather")
	SaveManager.request_autosave()
	world._rebuild_tiles()   # refresca el mundo (aparece la hoguera real; se quita el fantasma)
	world._update_base_aura()
	# La hoguera es SÓLIDA: si el jugador quedó en su centro, lo empujamos fuera.
	world._nudge_player_off_solid_cell(coord)
	var here: CellResource = GlobalState.hexagons_db.get(world.player_pos, null) as CellResource
	if here:
		world._update_location_panel(here)
	world._spawn_world_float(Locale.pick({"es": "🔥 ¡Hoguera construida!", "en": "🔥 Campfire built!"}), UiKit.GOOD)
	# (Game Feel): nunca debe aparecer de golpe: rebote de aparición +
	# polvo + brillo cálido en la propia hoguera recién construida.
	var built_entry: Dictionary = world._cells.get(coord, {})
	var built_obj: Node3D = built_entry.get("obj") as Node3D
	if built_obj != null:
		WorldFx.build_fx(world, built_obj, built_obj.global_position)


## Recrea la previsualización translúcida de la HOGUERA construible. Se llama tras
## cada reconstrucción de tiles: si hay un sitio válido (casilla a la derecha de la
## tienda, sin hoguera aún), pinta allí una hoguera fantasma; si no, la retira.
static func refresh_campfire_ghost(world: Node) -> void:
	if world._campfire_ghost != null and is_instance_valid(world._campfire_ghost):
		world._campfire_ghost.queue_free()
	world._campfire_ghost = null
	var spot := GlobalState.get_campfire_build_spot()
	if spot == Vector2i(-1, -1):
		return
	world._campfire_ghost = spawn_campfire_ghost(world, spot)


## Crea una hoguera FANTASMA (translúcida, ámbar) sobre `coord` para indicar que se
## Previsualización de la HOGUERA CONSTRUIBLE: marca la casilla a la derecha
## donde el jugador puede construir la hoguera. Muestra una versión holográfica
## translúcida del modelo hoguera.tscn que late suavemente.
static func spawn_campfire_ghost(world: Node, coord: Vector2i) -> Node3D:
	var ghost := Node3D.new()
	ghost.position = world._cell_to_world(coord)
	world._tiles_root.add_child(ghost)

	var campfire_model := ModelLoader.load_model("hoguera", 1.0)
	if campfire_model != null:
		var ghost_mat := StandardMaterial3D.new()
		ghost_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.albedo_color = Color(1.0, 0.65, 0.2, 0.65)
		ghost_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		ghost_mat.emission_enabled = true
		ghost_mat.emission = Color(1.0, 0.55, 0.1)
		ghost_mat.emission_energy_multiplier = 2.0

		for child in campfire_model.find_children("", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			mi.material_override = ghost_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		for light in campfire_model.find_children("", "Light3D", true, false):
			(light as Light3D).visible = false

		ghost.add_child(campfire_model)

	# Latido suave para indicar que es una previsualización construible
	var tw := ghost.create_tween().set_loops()
	tw.tween_property(ghost, "scale", Vector3.ONE * 1.08, 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ghost, "scale", Vector3.ONE, 0.75).set_trans(Tween.TRANS_SINE)
	return ghost


## MODAL DE LA HOGUERA: reducido a su función real (Comer/Cocinar). Ya no
## muestra nivel/servicios del campamento (la evolución de la Base ahora es
## automática al construir, ver `GlobalState.build_camp_structure`) ni
## "Pasar tiempo"/"Construir" (la tienda ya cubre el tiempo; el resto de
## construcciones se levantan andando hasta la casilla deseada, ver
## `open_camp_structure_build_confirm`). Subtítulo = Nivel de Cocinero, el
## oficio cuyo nivel desbloquea las recetas (ver GameConfig.COOKING_SKILL).
static func open_camp_menu(world: Node) -> void:
	var root: Control = UiKit.overlay(world)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 24, 3))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin := UiKit.margins(36, 36, 32, 32)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = Locale.pick({"es": "🔥 Hoguera", "en": "🔥 Campfire"})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(title)

	var cook_level: int = int(GlobalState.skills.get(GameConfig.COOKING_SKILL, {}).get("level", 1))
	var subtitle := Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	subtitle.text = Locale.pick({"es": "Nivel de Cocina %d", "en": "Cooking level %d"}) % cook_level
	vbox.add_child(subtitle)

	var actions: Array = [
		{"icon": "🍽️", "label": {"es": "Comer", "en": "Eat"}, "cb": func() -> void: root.visible = false; root.queue_free(); CampEatMenu.open_eat_menu(world)},
		{"icon": "🍳", "label": {"es": "Cocinar", "en": "Cook"}, "cb": func() -> void: root.visible = false; root.queue_free(); SceneManager.go_to_cook()},
	]
	for a in actions:
		var btn := Button.new()
		btn.text = "%s  %s" % [a["icon"], Locale.pick(a["label"])]
		btn.custom_minimum_size = Vector2(0, 84)
		btn.add_theme_font_size_override("font_size", 28)
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UiKit.button_primary(14))
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(col, UiKit.BG_DEEP)
		btn.pressed.connect(a["cb"])
		vbox.add_child(btn)

	var close := Button.new()
	close.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void: root.queue_free())
	vbox.add_child(close)


## Formatea un diccionario de costes { item: qty } como "🪵 20  🪨 15".
static func format_costs(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for res in costs.keys():
		parts.append("%s %d" % [Design.get_item_icon(String(res)), int(costs[res])])
	return "  ".join(parts)


## CONSTRUCCIÓN GENÉRICA (Muñeco/Cofre/Tablón/Herrería): a diferencia de la
## Hoguera (casilla FIJA junto a la tienda), estas se levantan en la casilla que
## el jugador elija —cualquiera libre alrededor de la tienda (Muñeco/Cofre) o
## dentro del territorio actual (Tablón/Herrería), ver
## `GlobalState.is_valid_camp_build_spot`. Al pulsar ENTRAR sobre una casilla
## válida (ver `TabWorld3D._on_enter_pressed`) se pinta aquí su previsualización
## translúcida y se ofrece el diálogo de confirmación con el coste.
static func open_camp_structure_build_confirm(world: Node, coord: Vector2i, key: String) -> void:
	var def := GlobalState.get_camp_structure_def(key)
	if def.is_empty():
		return
	var costs: Dictionary = def.get("costs", {})
	var enough := true
	for res in costs.keys():
		if not GlobalState.has_item(String(res), int(costs[res])):
			enough = false
	var ghost: Node3D = spawn_generic_structure_ghost(world, coord, def)

	var root: Control = UiKit.overlay(world, 0.55)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 20, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var margin := UiKit.margins(32, 32, 28, 28)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = "%s %s" % [String(def.get("icon", "🏗️")), Locale.pick(def.get("name", {}))]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", UiKit.TEXT)
	body.text = Locale.pick(def.get("desc", {}))
	vbox.add_child(body)

	var cost_lbl := Label.new()
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.add_theme_color_override("font_color", UiKit.GOOD if enough else UiKit.HP)
	cost_lbl.text = format_costs(costs)
	vbox.add_child(cost_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var close_cb := func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
		root.queue_free()

	var cancel := Button.new()
	cancel.text = Locale.pick({"es": "Cancelar", "en": "Cancel"})
	cancel.custom_minimum_size = Vector2(180, 58)
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.pressed.connect(close_cb)
	row.add_child(cancel)

	var build := Button.new()
	build.text = Locale.pick({"es": "🔨 Construir (%s)" % format_costs(costs), "en": "🔨 Build (%s)" % format_costs(costs)})
	build.custom_minimum_size = Vector2(260, 58)
	build.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "focus"]:
		build.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		build.add_theme_color_override(col, UiKit.BG_DEEP)
	build.disabled = not enough
	build.pressed.connect(func() -> void:
		close_cb.call()
		do_build_camp_structure_at(world, coord, key))
	row.add_child(build)


## Ejecuta la construcción genérica en `coord` tras confirmar y da feedback del
## resultado (mismo Game Feel que la Hoguera: SFX, rebote, polvo y brillo).
static func do_build_camp_structure_at(world: Node, coord: Vector2i, key: String) -> void:
	var err := GlobalState.build_camp_structure(key, coord)
	if err == "":
		AudioManager.play_sfx("gather")
		SaveManager.request_autosave()
		world._rebuild_tiles()
		world._update_base_aura()
		world._nudge_player_off_solid_cell(coord)
		var def := GlobalState.get_camp_structure_def(key)
		world._spawn_world_float("🏗️ %s" % Locale.pick(def.get("name", {})), UiKit.GOOD)
		world._spawn_world_float("⬆️ %s" % (Locale.pick({"es": "Base Nivel %d", "en": "Base Level %d"}) % GlobalState.camp_level), UiKit.XP)
		var built_entry: Dictionary = world._cells.get(coord, {})
		var built_obj: Node3D = built_entry.get("obj") as Node3D
		if built_obj != null:
			WorldFx.build_fx(world, built_obj, built_obj.global_position)
		var here: CellResource = GlobalState.hexagons_db.get(world.player_pos, null) as CellResource
		if here:
			world._update_location_panel(here)
		return
	var msg: Dictionary
	match err:
		"no_camp":      msg = {"es": "Monta antes la Base.", "en": "Set up the Base first."}
		"already":      msg = {"es": "Ya está construido.", "en": "Already built."}
		"locked":       msg = {"es": "Todavía no le toca turno a esta construcción.", "en": "This structure isn't up next yet."}
		"no_blueprint": msg = {"es": "Necesitas el plano de construcción.", "en": "You need the building blueprint."}
		"no_resources": msg = {"es": "No tienes recursos suficientes.", "en": "Not enough resources."}
		"no_space":     msg = {"es": "Aquí no se puede construir.", "en": "Can't build here."}
		_:              msg = {"es": "No se pudo construir.", "en": "Couldn't build."}
	UiKit.toast(world, Locale.pick(msg), UiKit.HP)


## Fantasma genérico (plataforma de madera + icono ámbar flotante) para
## previsualizar Muñeco/Cofre/Tablón/Herrería en `coord`, con el mismo lenguaje
## visual que la Hoguera construible (spawn_campfire_ghost).
static func spawn_generic_structure_ghost(world: Node, coord: Vector2i, def: Dictionary) -> Node3D:
	var ghost := Node3D.new()
	ghost.position = world._cell_to_world(coord)
	world._tiles_root.add_child(ghost)

	var mat := StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.55)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 1.4

	var platform := MeshInstance3D.new()
	var plat_mesh := BoxMesh.new()
	plat_mesh.size = Vector3(0.62, 0.16, 0.62)
	platform.mesh = plat_mesh
	platform.material_override = mat
	platform.position.y = 0.08
	ghost.add_child(platform)

	var glyph := Label3D.new()
	glyph.text = String(def.get("icon", "🏗️"))
	glyph.font_size = 130
	glyph.pixel_size = 0.006
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.modulate = Color(1.0, 0.85, 0.55, 0.9)
	glyph.position.y = 0.55
	ghost.add_child(glyph)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = 0.6
	torus.inner_radius = 0.48
	ring.mesh = torus
	ring.material_override = mat
	ring.position = Vector3(0.0, 0.06, 0.0)
	ghost.add_child(ring)

	var tw := ghost.create_tween().set_loops()
	tw.tween_property(ghost, "scale", Vector3.ONE * 1.1, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ghost, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	return ghost


## Interactuar con una construcción física del campamento: abre su funcionalidad
## según la `action` de su definición (muñeco → entrenamiento directo in-situ ·
## cofre → almacén persistente · herrería → forja · etc.).
static func open_camp_structure(world: Node, cell: CellResource) -> void:
	var key := cell.event_id.trim_prefix("camp_")
	var def := GlobalState.get_camp_structure_def(key)
	var action := String(def.get("action", ""))
	if action == "train":
		train_dummy(world, cell)
		return
	AudioManager.play_sfx("click")
	match action:
		"chest":    open_chest_menu(world)
		"forge":    SceneManager.go_to_forge()
		"encargos": SceneManager.go_to_encargos()
		_:          world._spawn_world_float(Locale.pick(def.get("name", {"es": "Construcción", "en": "Structure"})), UiKit.ACCENT_SOFT)


## Inicia el combate de práctica contra el Muñeco de Entrenamiento (Nivel 99, 9999 HP).
static func train_dummy(_world: Node, _cell: CellResource) -> void:
	var dummy_data: Dictionary = Design.get_enemy("muneco_entrenamiento")
	if dummy_data.is_empty():
		dummy_data = {
			"id": "muneco_entrenamiento",
			"name": {"es": "Muñeco de Entrenamiento", "en": "Training Dummy"},
			"level": 99,
			"hp": 9999,
			"max_hp": 9999,
			"image": "res://assets/combat/enemies/en_training_dummy.png",
			"is_training_dummy": true,
			"can_flee": true,
			"zone": "base_camp",
			"context": "training"
		}
	else:
		dummy_data = dummy_data.duplicate()
		dummy_data["id"] = "muneco_entrenamiento"
		dummy_data["level"] = 99
		dummy_data["hp"] = 9999
		dummy_data["max_hp"] = 9999
		dummy_data["is_training_dummy"] = true
		dummy_data["can_flee"] = true
		dummy_data["context"] = "training"

	AudioManager.play_sfx("click")
	SceneManager.start_combat(dummy_data)


## MODAL DEL COFRE: dos columnas (Inventario | Cofre); tocar una entrada
## transfiere TODAS sus unidades al otro lado, preservando el equipo con stats
## propios (EquipmentResource) si lo hubiera — ver `GlobalState._transfer_item_entry`.
## El Cofre nunca pierde su contenido pero SÍ tiene límite (`GameConfig.CHEST_SLOT_CAP`,
## 1000); el del jugador crece con STR (`GlobalState.inventory_slot_cap`), por lo
## que mover algo puede fallar si el lado de destino está lleno.
static func open_chest_menu(world: Node) -> void:
	var root: Control = UiKit.overlay(world)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 24, 3))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var margin := UiKit.margins(30, 30, 26, 26)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = Locale.pick({"es": "📦 Cofre", "en": "📦 Chest"})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(title)

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	hint.text = Locale.pick({
		"es": "Toca un objeto para moverlo entero al otro lado.",
		"en": "Tap an item to move it entirely to the other side."})
	vbox.add_child(hint)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cols)

	var inv_col: Control = _build_chest_column(world, Locale.pick({"es": "🎒 Inventario (%d/%d)", "en": "🎒 Inventory (%d/%d)"}), true)
	var chest_col: Control = _build_chest_column(world, Locale.pick({"es": "📦 Cofre (%d/%d)", "en": "📦 Chest (%d/%d)"}), false)
	cols.add_child(inv_col)
	cols.add_child(chest_col)

	var refresh_all := func() -> void:
		_refresh_chest_column(world, inv_col, true)
		_refresh_chest_column(world, chest_col, false)

	inv_col.set_meta("refresh_fn", refresh_all)
	chest_col.set_meta("refresh_fn", refresh_all)
	refresh_all.call()

	var close := Button.new()
	close.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void: root.queue_free())
	vbox.add_child(close)


## Construye una columna (Inventario o Cofre) del modal del Cofre: cabecera +
## lista con scroll. `is_inventory` decide de qué lado se lee/transfiere.
static func _build_chest_column(world: Node, title_fmt: String, is_inventory: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	col.set_meta("title_fmt", title_fmt)
	col.set_meta("is_inventory", is_inventory)
	col.set_meta("world", world)

	var header := Label.new()
	header.name = "Header"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", UiKit.TEXT)
	col.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	return col


## Repuebla la cabecera + lista de una columna del modal del Cofre con el
## contenido actual (inventario o almacén, según `is_inventory`).
static func _refresh_chest_column(world: Node, col: VBoxContainer, is_inventory: bool) -> void:
	var title_fmt := String(col.get_meta("title_fmt", ""))
	var header := col.get_node_or_null("Header") as Label
	var list := col.get_node_or_null("Scroll/List") as VBoxContainer
	if header == null or list == null:
		return
	for child in list.get_children():
		child.queue_free()

	var items: Array = GlobalState.inventory if is_inventory else GlobalState.chest_storage
	if is_inventory:
		header.text = title_fmt % [GlobalState.inventory_slot_count(), GlobalState.inventory_slot_cap()]
	else:
		header.text = title_fmt % [GlobalState.chest_slot_count(), GameConfig.CHEST_SLOT_CAP]

	if items.is_empty():
		var empty := Label.new()
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		empty.text = Locale.pick({"es": "Vacío", "en": "Empty"})
		list.add_child(empty)
		return

	for item: Dictionary in items.duplicate():
		var id := String(item.get("id", ""))
		var qty := int(item.get("quantity", 1))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 16)
		btn.text = "%s  %s  x%d" % [String(item.get("icon", "❓")), String(item.get("name", id)), qty]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.SURFACE_ALT))
		btn.pressed.connect(func() -> void:
			if is_inventory:
				if not GlobalState.move_item_to_chest(id, qty):
					UiKit.toast(world, Locale.pick({"es": "Cofre lleno.", "en": "Chest full."}), UiKit.HP)
			else:
				var err := GlobalState.move_item_from_chest(id, qty)
				if err == "no_space":
					UiKit.toast(world, Locale.pick({"es": "Inventario lleno.", "en": "Inventory full."}), UiKit.HP)
			SaveManager.request_autosave()
			if col.has_meta("refresh_fn"):
				var rf = col.get_meta("refresh_fn")
				if rf is Callable and rf.is_valid():
					rf.call()
		)
		list.add_child(btn)


## PASAR TIEMPO: avanza el reloj hasta el inicio de la siguiente fase (día↔noche).
## NO cura. Útil para esperar a que abran/cierren los POIs.
static func camp_pass_time(world: Node) -> void:
	var target: float = GameConfig.NIGHT_START_HOUR if TimeManager.is_day() else GameConfig.DAY_START_HOUR
	advance_to_hour(target)
	world._spawn_world_float(Locale.pick({"es": "⏳ Pasa el tiempo…", "en": "⏳ Time passes…"}), UiKit.ACCENT_SOFT)
	SaveManager.request_autosave()


## Avanza el reloj in-game hasta una hora objetivo [0,24), dando la vuelta al día
## si es necesario (si ya estamos en esa hora, avanza un día completo). Sin
## coupling a `self`: solo usa el singleton TimeManager.
static func advance_to_hour(target: float) -> void:
	var cur: float = TimeManager.get_hour()
	var delta: float = fposmod(target - cur, 24.0)
	if delta < 0.01:
		delta = 24.0
	TimeManager.advance_hours(delta)


# ══════════════════════════════════════════════════════════════════════════════
# MONTAR EL CAMPAMENTO (primera vez) — diálogo de confirmación de la tienda
# ══════════════════════════════════════════════════════════════════════════════

## Usar la Tienda de Campaña: NO monta el campamento directamente. Muestra una
## PREVISUALIZACIÓN transparente en la casilla actual y un diálogo de confirmación
## con el coste (10 maderas · ). Solo al confirmar se gasta madera + tienda.
static func on_use_tent_pressed(world: Node) -> void:
	AudioManager.play_sfx("click")
	var coord: Vector2i = world.player_pos
	if not GlobalState.can_establish_base_at(coord):
		UiKit.toast(world, Locale.pick({
			"es": "No puedes construir aquí, hay algo que ocupa el lugar.",
			"en": "Cannot build here, something is occupying the spot."
		}), UiKit.HP)
		return
	open_camp_build_confirm(world, coord)


## Diálogo de construcción del campamento: pinta la previsualización translúcida en
## `coord` y ofrece "Construir Campamento (N maderas)" / "Cancelar". El botón de
## construir se deshabilita si no hay madera suficiente.
static func open_camp_build_confirm(world: Node, coord: Vector2i) -> void:
	var cost: int = GameConfig.CAMP_WOOD_COST
	var wood: int = int(GlobalState.get_item("wood").get("quantity", 0))
	var ghost: Node3D = spawn_camp_ghost(world, coord)

	var root: Control = UiKit.overlay(world, 0.55)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 20, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var margin := UiKit.margins(32, 32, 28, 28)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = Locale.pick({"es": "🏕️ Montar Campamento", "en": "🏕️ Set Up Camp"})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", UiKit.TEXT)
	body.text = Locale.pick({
		"es": "Se montará tu tienda de campaña aquí. Será tu punto de reaparición. Luego podrás construir una hoguera a su lado.",
		"en": "Your tent will be set up here. It becomes your respawn point. You can then build a campfire beside it."})
	vbox.add_child(body)

	var cost_lbl := Label.new()
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 20)
	var enough: bool = wood >= cost
	cost_lbl.add_theme_color_override("font_color", UiKit.GOOD if enough else UiKit.HP)
	cost_lbl.text = "🪵 %d / %d" % [wood, cost]
	vbox.add_child(cost_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var close_cb := func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
		root.queue_free()

	var cancel := Button.new()
	cancel.text = Locale.pick({"es": "Cancelar", "en": "Cancel"})
	cancel.custom_minimum_size = Vector2(180, 58)
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.pressed.connect(close_cb)
	row.add_child(cancel)

	var build := Button.new()
	build.text = Locale.pick({"es": "🔨 Construir (%d 🪵)" % cost, "en": "🔨 Build (%d 🪵)" % cost})
	build.custom_minimum_size = Vector2(260, 58)
	build.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "pressed", "focus"]:
		build.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		build.add_theme_color_override(col, UiKit.BG_DEEP)
	build.disabled = not enough
	build.pressed.connect(func() -> void:
		close_cb.call()
		build_camp_confirmed(world, coord))
	row.add_child(build)


## Ejecuta la construcción del campamento tras confirmar: gasta la madera, consume
## la tienda, monta el campamento (Nivel 1) y refresca el mundo.
static func build_camp_confirmed(world: Node, coord: Vector2i) -> void:
	if not GlobalState.can_establish_base_at(coord):
		UiKit.toast(world, Locale.pick({
			"es": "No puedes construir aquí, hay algo que ocupa el lugar.",
			"en": "Cannot build here, something is occupying the spot."
		}), UiKit.HP)
		return
	var cost: int = GameConfig.CAMP_WOOD_COST
	if not GlobalState.has_item("wood", cost):
		UiKit.toast(world, Locale.pick({"es": "No tienes madera suficiente.", "en": "Not enough wood."}), UiKit.HP)
		return
	GlobalState.remove_item("wood", cost)
	GlobalState.remove_item("tent", 1)

	# Montar el campamento: coloca la TIENDA (dormir) y una HOGUERA adyacente
	# (cocinar). establish_base_at hace toda la lógica y persiste la hoguera.
	GlobalState.establish_base_at(coord)

	# Guardar y reconstruir el mapa para reflejar tienda + hoguera al instante.
	SaveManager.request_autosave()
	world._rebuild_tiles()
	world._update_base_aura()

	# La casilla de la tienda es SÓLIDA con el jugador en su centro: lo empujamos
	# a la primera casilla vecina transitable para que no quede atrapado.
	world._nudge_player_off_solid_cell(coord)
	var here: CellResource = GlobalState.hexagons_db.get(world.player_pos, null) as CellResource
	if here:
		world._update_location_panel(here)
	world._spawn_world_float(Locale.pick({"es": "🏕️ ¡Campamento montado!", "en": "🏕️ Camp established!"}), UiKit.GOOD)
	# (Game Feel): rebote de aparición + polvo + brillo también al
	# montar la tienda (primera construcción del campamento).
	var tent_entry: Dictionary = world._cells.get(coord, {})
	var tent_obj: Node3D = tent_entry.get("obj") as Node3D
	if tent_obj != null:
		WorldFx.build_fx(world, tent_obj, tent_obj.global_position)
	# Pista narrativa de la Esfera al construir la tienda de campaña (Base Nivel 1)
	if GlobalState.camp_level == 1 and OrbBarksManager != null:
		world.get_tree().create_timer(0.4).timeout.connect(func() -> void:
			OrbBarksManager.trigger_bark(Locale.pick({
				"es": "¡Menudo palacio de tela! Ahora monta la hoguera justo debajo: te servirá para cocinar tus provisiones y recuperar fuerzas... que entre tú y yo, tienes una pinta de hecho polvo que da pena.",
				"en": "Quite the canvas palace! Now build the campfire right below it to cook your provisions and recover your strength... because honestly, you look completely wrecked."
			}), 7.0)
		)


## Crea una PREVISUALIZACIÓN translúcida (tienda fantasma) sobre la casilla `coord`
## y la devuelve para poder liberarla al cerrar el diálogo. Verde translúcido.
static func spawn_camp_ghost(world: Node, coord: Vector2i) -> Node3D:
	var ghost := Node3D.new()
	ghost.position = world._cell_to_world(coord)
	world._tiles_root.add_child(ghost)

	var mat := StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 1.0, 0.45, 0.4)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	# Tienda fantasma (prisma), replicando la forma del marcador real.
	var tent := MeshInstance3D.new()
	var tent_mesh := PrismMesh.new()
	tent_mesh.size = Vector3(0.75, 0.65, 0.9)
	tent.mesh = tent_mesh
	tent.material_override = mat
	tent.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	tent.position = Vector3(-0.25, 0.325, -0.05)
	ghost.add_child(tent)

	# Anillo en el suelo para marcar la casilla objetivo.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = 0.55
	torus.inner_radius = 0.48
	ring.mesh = torus
	ring.material_override = mat
	ring.position = Vector3(0.0, 0.05, 0.0)
	ghost.add_child(ring)

	# Latido suave para que se note que es una previsualización.
	var tw := ghost.create_tween().set_loops()
	tw.tween_property(ghost, "scale", Vector3.ONE * 1.06, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ghost, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	return ghost
