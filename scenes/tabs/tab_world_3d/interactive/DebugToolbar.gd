# DebugToolbar.gd
# ─────────────────────────────────────────────────────────────────────────────
# BARRA DE HERRAMIENTAS Y TELETRANSPORTE POR ZONAS DEL MODO DEBUG.
#
# Permite probar y debugear cada zona del juego de forma aislada y realista,
# configurando automáticamente:
#   · Posición y cámara en el mapamundi.
#   · Nivel base y nivel de profesiones correspondiente a esa zona.
#   · Estado de las quests principales y banderas de mundo.
#   · Transformaciones de mundo necesarias (presa, puente del mono, etc.).
#   · Inventario, herramientas y equipamiento realista de ese hito.
#   · Control de velocidad (1x / 3x) y botón de recursos (+1000 oro y +10 mats).
# ─────────────────────────────────────────────────────────────────────────────
class_name DebugToolbar
extends RefCounted

const ZONE_INFOS: Dictionary = {
	1: {"name": "Zona 1: Yelmo", "coord": Vector2i(19, 41), "level": 1, "desc": "Inicio · Nv 1 · Don Nadie · Sin ítems"},
	2: {"name": "Zona 2: Paso Nevado", "coord": Vector2i(33, 38), "level": 10, "desc": "Tras la Presa · Nv 10 · Don Nadie · Tienda, Caña y Hacha"},
	3: {"name": "Zona 3: Sylphrena", "coord": Vector2i(66, 38), "level": 10, "desc": "Llegada a Sylphrena · Nv 10 · Don Nadie (Pre-Profesiones)"},
	4: {"name": "Zona 4: Celestia", "coord": Vector2i(83, 30), "level": 15, "desc": "Puente del Mono superado · Nv 15 · Pico"},
	5: {"name": "Zona 5: Gloriam", "coord": Vector2i(59, 17), "level": 25, "desc": "Jefe Puerto vencido · Nv 25 · Barco y Desierto"},
	6: {"name": "Zona 6: Arcanum", "coord": Vector2i(24, 13), "level": 35, "desc": "Centinela superado · Nv 35 · Tecnología"},
	7: {"name": "Zona 7: Santuario Final", "coord": Vector2i(8, 23), "level": 45, "desc": "Quests Arcanum listas · Nv 45 · Cueva Origen"},
	8: {"name": "Zona 8: Zona Secreta", "coord": Vector2i(39, 59), "level": 50, "desc": "Post-game / Guardián · Nv 50 · Equipo Máximo"},
}


## Construye la barra flotante en la esquina inferior izquierda
static func build_debug_toolbar(world: Node) -> Control:
	var root := PanelContainer.new()
	root.name = "DebugToolbar"
	root.anchor_left = 0.0
	root.anchor_right = 0.0
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 16.0
	root.offset_right = 690.0
	root.offset_top = -120.0
	root.offset_bottom = -16.0
	root.grow_horizontal = Control.GROW_DIRECTION_END
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var panel_sb := UiKit.panel(Color(UiKit.BG_BASE.r, UiKit.BG_BASE.g, UiKit.BG_BASE.b, 0.88), UiKit.ACCENT, 14, 2)
	panel_sb.shadow_color = Color(0, 0, 0, 0.6)
	panel_sb.shadow_size = 10
	root.add_theme_stylebox_override("panel", panel_sb)
	world.add_child(root)

	var margin := UiKit.margins(12, 12, 10, 10)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Fila 1: Botones numéricos de Zona 1 a 8
	var hb_zones := HBoxContainer.new()
	hb_zones.add_theme_constant_override("separation", 5)
	vbox.add_child(hb_zones)

	var lbl_title := Label.new()
	lbl_title.text = "🛠️"
	lbl_title.add_theme_font_size_override("font_size", 18)
	hb_zones.add_child(lbl_title)

	for z in range(1, 9):
		var info: Dictionary = ZONE_INFOS.get(z, {})
		var btn := Button.new()
		btn.text = str(z)
		btn.custom_minimum_size = Vector2(36, 32)
		btn.add_theme_font_size_override("font_size", 16)
		btn.tooltip_text = "%s\n%s" % [info.get("name", ""), info.get("desc", "")]
		_style_debug_btn(btn)
		var zone_idx := z
		btn.pressed.connect(func() -> void:
			warp_to_zone(zone_idx, world)
		)
		hb_zones.add_child(btn)

	# Fila 2: Velocidad + +Recursos + Curar + 👑 Desbloquear 6 Jobs
	var hb_controls := HBoxContainer.new()
	hb_controls.add_theme_constant_override("separation", 6)
	vbox.add_child(hb_controls)

	# Botón de velocidad
	var btn_speed := Button.new()
	btn_speed.custom_minimum_size = Vector2(95, 30)
	btn_speed.add_theme_font_size_override("font_size", 14)
	_style_debug_btn(btn_speed, true)
	_update_speed_button_label(btn_speed)
	btn_speed.pressed.connect(func() -> void:
		GlobalState.debug_speed_mult = 1.0 if GlobalState.debug_speed_mult > 1.5 else 3.0
		_update_speed_button_label(btn_speed)
		UiKit.toast(world, Locale.pick({
			"es": "⚡ Velocidad: x%d" % int(GlobalState.debug_speed_mult),
			"en": "⚡ Speed: x%d" % int(GlobalState.debug_speed_mult)
		}), UiKit.ACCENT)
	)
	hb_controls.add_child(btn_speed)

	# Botón +Recursos
	var btn_res := Button.new()
	btn_res.text = "💎 +Recursos"
	btn_res.custom_minimum_size = Vector2(100, 30)
	btn_res.add_theme_font_size_override("font_size", 13)
	_style_debug_btn(btn_res)
	btn_res.pressed.connect(func() -> void:
		add_debug_resources(world)
	)
	hb_controls.add_child(btn_res)

	# Botón Curar
	var btn_heal := Button.new()
	btn_heal.text = "❤️ Curar"
	btn_heal.custom_minimum_size = Vector2(80, 30)
	btn_heal.add_theme_font_size_override("font_size", 13)
	_style_debug_btn(btn_heal)
	btn_heal.pressed.connect(func() -> void:
		GlobalState.hp = GlobalState.max_hp
		GlobalState.mp = GlobalState.max_mp
		GlobalState.energy = float(GlobalState.max_energy)
		GlobalState.is_poisoned = false
		GlobalState.state_updated.emit()
		UiKit.toast(world, Locale.pick({"es": "❤️ ¡Salud y maná al máximo!", "en": "❤️ Fully healed!"}), UiKit.GOOD)
	)
	hb_controls.add_child(btn_heal)

	# Botón Desbloquear 6 Profesiones (para probar la audiencia con el Rey)
	var btn_jobs := Button.new()
	btn_jobs.text = "👑 6 Jobs"
	btn_jobs.tooltip_text = "Desbloquear las 6 profesiones de maestría al Nivel 10 para probar la audiencia con el Rey"
	btn_jobs.custom_minimum_size = Vector2(90, 30)
	btn_jobs.add_theme_font_size_override("font_size", 13)
	_style_debug_btn(btn_jobs)
	btn_jobs.pressed.connect(func() -> void:
		unlock_all_professions_debug(world)
	)
	hb_controls.add_child(btn_jobs)

	# Controles de Nivel: -Nv y +Nv para testear stats
	var btn_lvl_down := Button.new()
	btn_lvl_down.text = "-Nv"
	btn_lvl_down.tooltip_text = "Reducir 1 nivel y reajustar puntos de stats"
	btn_lvl_down.custom_minimum_size = Vector2(48, 30)
	btn_lvl_down.add_theme_font_size_override("font_size", 13)
	_style_debug_btn(btn_lvl_down)
	hb_controls.add_child(btn_lvl_down)

	var lbl_lvl := Label.new()
	lbl_lvl.text = "Nv.%d" % GlobalState.level
	lbl_lvl.add_theme_font_size_override("font_size", 13)
	lbl_lvl.add_theme_color_override("font_color", UiKit.ACCENT)
	lbl_lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb_controls.add_child(lbl_lvl)

	var btn_lvl_up := Button.new()
	btn_lvl_up.text = "+Nv"
	btn_lvl_up.tooltip_text = "Aumentar 1 nivel y otorgar puntos de stats"
	btn_lvl_up.custom_minimum_size = Vector2(48, 30)
	btn_lvl_up.add_theme_font_size_override("font_size", 13)
	_style_debug_btn(btn_lvl_up)
	hb_controls.add_child(btn_lvl_up)

	btn_lvl_down.pressed.connect(func() -> void:
		if GlobalState.level <= 1:
			if world != null:
				UiKit.toast(world, "⚠️ Nivel mínimo alcanzado (1)", UiKit.HP)
			return
		GlobalState.debug_remove_level()
		lbl_lvl.text = "Nv.%d" % GlobalState.level
		if world != null:
			UiKit.toast(world, "📉 Nivel reducido a %d" % GlobalState.level, UiKit.HP)
	)

	btn_lvl_up.pressed.connect(func() -> void:
		GlobalState.debug_add_level()
		lbl_lvl.text = "Nv.%d" % GlobalState.level
		if world != null:
			UiKit.toast(world, "📈 ¡Nivel aumentado a %d! (+%d puntos de stats)" % [GlobalState.level, GameConfig.STAT_POINTS_PER_LEVEL], UiKit.GOOD)
	)

	var on_state_updated := func() -> void:
		if is_instance_valid(lbl_lvl):
			lbl_lvl.text = "Nv.%d" % GlobalState.level
	GlobalState.state_updated.connect(on_state_updated)
	root.tree_exited.connect(func() -> void:
		if GlobalState.state_updated.is_connected(on_state_updated):
			GlobalState.state_updated.disconnect(on_state_updated)
	)

	return root


static func _update_speed_button_label(btn: Button) -> void:
	if GlobalState.debug_speed_mult > 1.5:
		btn.text = "⚡ Vel: x3"
		btn.add_theme_color_override("font_color", UiKit.ACCENT)
	else:
		btn.text = "🚶 Vel: x1"
		btn.add_theme_color_override("font_color", UiKit.TEXT)


static func _style_debug_btn(btn: Button, accent: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16, 0.92) if not accent else Color(0.20, 0.16, 0.08, 0.95)
	sb.border_color = UiKit.ACCENT if accent else Color(0.35, 0.38, 0.45, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.border_color = UiKit.ACCENT
	sb_h.bg_color = Color(0.22, 0.22, 0.28, 0.95)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_color_override("font_color", UiKit.TEXT)
	btn.add_theme_color_override("font_hover_color", UiKit.ACCENT)


## Añade 10000 de oro y suma recursos del juego (materiales, bombas, consumibles, etc.)
static func add_debug_resources(world: Node = null) -> void:
	GlobalState.gold += 10000
	GlobalState.grant_all_game_items(20, true)
	GlobalState.state_updated.emit()
	if world != null:
		UiKit.toast(world, Locale.pick({
			"es": "📦 +20 a todos los recursos y +10000 Oro añadidos",
			"en": "📦 +20 to all resources and +10000 Gold added"
		}), UiKit.GOOD)


## Teletransporta al jugador y configura el estado completo de la zona elegida (1-8)
static func warp_to_zone(zone_idx: int, world: Node = null) -> void:
	# 1. Limpieza base de inventario, equipo y estados
	GlobalState.inventory.clear()
	GlobalState.equipped = {
		"helmet": null, "weapon": null, "shield": null,
		"armor": null, "shoes": null, "accessory": null,
	}
	GlobalState.food_buffs.clear()
	GlobalState.is_poisoned = false
	GlobalState.gold = 0
	GlobalState.world_flags.clear()
	GlobalState.achievements_unlocked.clear()
	GlobalState.tutorials_progress.clear()
	GlobalState.npc_memory.clear()
	GlobalState.quests.clear()
	GlobalState.defeated_bosses.clear()
	GlobalState.opened_chests.clear()
	GlobalState.dam_opened = false
	GlobalState.cave_cleared = false
	GlobalState.is_sailing = false
	GlobalState.has_built_base = false
	GlobalState.base_coord = Vector2i(-1, -1)
	GlobalState.campfire_coord = Vector2i(-1, -1)
	GlobalState.camp_level = 0
	GlobalState.camp_structures = {}
	GlobalState.lore_discovered.clear()

	var info: Dictionary = ZONE_INFOS.get(zone_idx, ZONE_INFOS[1])
	var target_coord: Vector2i = info.get("coord", Vector2i(19, 41))

	match zone_idx:
		1:
			# Zona 1: El Despertar / Páramo del Yelmo (19, 41)
			# Nivel 1, Don Nadie, 0 ítems encima
			GlobalState.level = 1
			GlobalState.xp = 0
			GlobalState.xp_needed = GameConfig.START_XP_NEEDED
			GlobalState.stat_points = 0
			GlobalState.stats = GameConfig.START_STATS.duplicate(true)
			GlobalState.profession = "Don Nadie"
			GlobalState.unlocked_professions = ["Don Nadie"]
			GlobalState.job_level = 1
			GlobalState.job_xp = 0
			GlobalState.job_xp_needed = GameConfig.xp_needed_for_job_level(2)
			GlobalState.profession_levels = {
				"Don Nadie": {"level": 1, "xp": 0, "xp_needed": GameConfig.xp_needed_for_job_level(2)}
			}
			GlobalState.unlocked_skills = []
			GlobalState.active_combat_skills.clear()
			GlobalState.active_combat_skills["Don Nadie"] = GlobalState._default_combat_skill_slots("Don Nadie")
			GlobalState.quest_state = "not_started"

		2:
			# Zona 2: Paso Nevado / Tras la Presa (33, 38)
			# Nivel 10, Don Nadie Nv. 10 (única profesión desbloqueada), presa abierta, hacha, caña y tienda
			GlobalState.level = 10
			GlobalState.stat_points = 20
			GlobalState.stats = {"str": 18, "dex": 18, "int": 18, "con": 18}
			_set_jobs_subset_level(["Don Nadie"], 10)
			GlobalState.unlocked_skills = []
			GlobalState.dam_opened = true
			GlobalState.cave_cleared = true
			GlobalState.world_flags["dam_opened"] = true
			GlobalState.world_flags["cave_cleared"] = true
			GlobalState.world_flags["anciana_axe_given"] = true
			GlobalState.world_flags["anciana_stone_given"] = true
			GlobalState.world_flags["anciana_rod_given"] = true
			GlobalState.world_flags["recluso_tent_given"] = true
			GlobalState.quest_state = "yelmo_tunnel_cleared"
			GlobalState.add_item("hacha", 1)
			GlobalState.add_item("tent", 1)
			GlobalState.add_item("cana_pescar", 1)
			GlobalState.add_item("potion", 5)
			GlobalState.add_item("wood", 10)
			GlobalState.add_item("fish", 5)
			_equip_item_safely("bronze_sword")
			_equip_item_safely("wooden_shield")
			_equip_item_safely("leather_armor")
			_equip_item_safely("leather_cap")

		3:
			# Zona 3: Sylphrena / Bosques (66, 38)
			# Nivel 10, Don Nadie Nv. 10 (única profesión desbloqueada; aquí se aprenden las 3 primeras profesiones)
			GlobalState.level = 10
			GlobalState.stat_points = 20
			GlobalState.stats = {"str": 20, "dex": 20, "int": 20, "con": 20}
			_set_jobs_subset_level(["Don Nadie"], 10)
			GlobalState.unlocked_skills = ExplorationSkills.all_ids()
			GlobalState.dam_opened = true
			GlobalState.cave_cleared = true
			GlobalState.world_flags["dam_opened"] = true
			GlobalState.world_flags["cave_cleared"] = true
			GlobalState.world_flags["anciana_axe_given"] = true
			GlobalState.world_flags["anciana_rod_given"] = true
			GlobalState.world_flags["recluso_tent_given"] = true
			GlobalState.world_flags["snow_cross_completed"] = true
			GlobalState.quest_state = "sylphrena_arrived"
			GlobalState.add_item("hacha", 1)
			GlobalState.add_item("tent", 1)
			GlobalState.add_item("cana_pescar", 1)
			GlobalState.add_item("potion", 8)
			GlobalState.add_item("cooked_fish", 5)
			GlobalState.add_item("wood", 15)
			_equip_item_safely("iron_sword")
			_equip_item_safely("iron_shield")
			_equip_item_safely("iron_armor")
			_equip_item_safely("bronze_helmet")

		4:
			# Zona 4: Celestia / Valle y Puente del Mono (83, 30)
			# Nivel 15, Don Nadie + 3 Primeras Profesiones (Guerrero, Arquero, Psíquico) Nv. 10
			# Las otras 3 profesiones (Elementalista, Sacerdote, Tiempo) se dominan en los senderos de Celestia.
			GlobalState.level = 15
			GlobalState.stat_points = 30
			GlobalState.stats = {"str": 35, "dex": 35, "int": 35, "con": 35}
			_set_jobs_subset_level(["Don Nadie", "Guerrero", "Arquero", "Psíquico"], 10)
			GlobalState.unlocked_skills = ExplorationSkills.all_ids()
			GlobalState.dam_opened = true
			GlobalState.cave_cleared = true
			GlobalState.world_flags["dam_opened"] = true
			GlobalState.world_flags["cave_cleared"] = true
			GlobalState.world_flags["anciana_axe_given"] = true
			GlobalState.world_flags["anciana_rod_given"] = true
			GlobalState.world_flags["recluso_tent_given"] = true
			GlobalState.world_flags["snow_cross_completed"] = true
			GlobalState.world_flags["explorer_saved"] = true
			GlobalState.world_flags["item_found"] = true
			GlobalState.world_flags["banana_obtained"] = true
			GlobalState.world_flags["monkey_cleared"] = true
			GlobalState.world_flags["bandits_cave_cleared"] = true
			GlobalState.world_flags["boss_puerto_activo"] = false
			GlobalState.world_flags["boss_puerto_derrotado"] = false
			GlobalState.world_flags["puerto_bajo_ataque"] = false
			GlobalState.world_flags["all_professions_mastered"] = false
			GlobalState.world_flags["king_audience_done"] = false
			GlobalState.quest_state = "celestia_arrived"
			GlobalState.add_item("hacha", 1)
			GlobalState.add_item("pico", 1)
			GlobalState.add_item("tent", 1)
			GlobalState.add_item("cana_pescar", 1)
			GlobalState.add_item("potion_mid", 8)
			GlobalState.add_item("carne_asada", 8)
			GlobalState.add_item("wood", 20)
			GlobalState.add_item("stone", 10)
			_equip_item_safely("steel_sword")
			_equip_item_safely("iron_shield")
			_equip_item_safely("plate_armor")
			_equip_item_safely("knight_helmet")

		5:
			# Zona 5: Gloriam / Puerto y Desierto (59, 17)
			# Nivel 25, jobs 10, rey hablado, jefe del puerto derrotado, barco entregado
			GlobalState.level = 25
			GlobalState.stat_points = 50
			GlobalState.stats = {"str": 50, "dex": 50, "int": 50, "con": 50}
			_set_all_jobs_level(10)
			GlobalState.unlocked_skills = ExplorationSkills.all_ids()
			GlobalState.dam_opened = true
			GlobalState.cave_cleared = true
			GlobalState.world_flags["dam_opened"] = true
			GlobalState.world_flags["cave_cleared"] = true
			GlobalState.world_flags["monkey_cleared"] = true
			GlobalState.world_flags["all_professions_mastered"] = true
			GlobalState.world_flags["king_audience_done"] = true
			GlobalState.world_flags["harbor_boss_defeated"] = true
			GlobalState.world_flags["ship_unlocked"] = true
			GlobalState.quest_state = "gloriam_arrived"
			GlobalState.add_item("hacha", 1)
			GlobalState.add_item("pico", 1)
			GlobalState.add_item("pala", 1)
			GlobalState.add_item("tent", 1)
			GlobalState.add_item("cana_pescar", 1)
			GlobalState.add_item("potion_mid", 15)
			GlobalState.add_item("hamburguesa", 10)
			GlobalState.add_item("bebida_refrescante", 10)
			_equip_item_safely("imperial_blade")
			_equip_item_safely("aegis_shield")
			_equip_item_safely("silk_vest")
			_equip_item_safely("botas_arena")

		6:
			# Zona 6: Arcanum / Cañón y Frontera (24, 13)
			# Nivel 35, jobs 10, centinela de frontera superado
			GlobalState.level = 35
			GlobalState.stat_points = 70
			GlobalState.stats = {"str": 70, "dex": 70, "int": 70, "con": 70}
			_set_all_jobs_level(10)
			GlobalState.unlocked_skills = ExplorationSkills.all_ids()
			GlobalState.dam_opened = true
			GlobalState.cave_cleared = true
			GlobalState.world_flags["dam_opened"] = true
			GlobalState.world_flags["cave_cleared"] = true
			GlobalState.world_flags["monkey_cleared"] = true
			GlobalState.world_flags["ship_unlocked"] = true
			GlobalState.world_flags["solar_relic_found"] = true
			GlobalState.world_flags["sentinel_passed"] = true
			GlobalState.quest_state = "arcanum_arrived"
			GlobalState.add_item("hacha", 1)
			GlobalState.add_item("pico", 1)
			GlobalState.add_item("pala", 1)
			GlobalState.add_item("tent", 1)
			GlobalState.add_item("cana_pescar", 1)
			GlobalState.add_item("potion_high", 10)
			GlobalState.add_item("elixir_max", 5)
			_equip_item_safely("flame_blade")
			_equip_item_safely("escudo_plasma")
			_equip_item_safely("peto_arcanium")
			_equip_item_safely("botas_arena")

		7:
			# Zona 7: Santuario Final / Cueva del Origen (8, 23)
			# Nivel 45, jobs 10, quests de Arcanum completadas
			GlobalState.level = 45
			GlobalState.stat_points = 90
			GlobalState.stats = {"str": 90, "dex": 90, "int": 90, "con": 90}
			_set_all_jobs_level(10)
			GlobalState.unlocked_skills = ExplorationSkills.all_ids()
			GlobalState.dam_opened = true
			GlobalState.cave_cleared = true
			GlobalState.world_flags["dam_opened"] = true
			GlobalState.world_flags["cave_cleared"] = true
			GlobalState.world_flags["monkey_cleared"] = true
			GlobalState.world_flags["ship_unlocked"] = true
			GlobalState.world_flags["sentinel_passed"] = true
			GlobalState.world_flags["lab_docs_found"] = true
			GlobalState.world_flags["truth_revealed"] = true
			GlobalState.world_flags["temple_awakening"] = true
			GlobalState.quest_state = "final_sanctuary_reached"
			GlobalState.add_item("hacha", 1)
			GlobalState.add_item("pico", 1)
			GlobalState.add_item("pala", 1)
			GlobalState.add_item("tent", 1)
			GlobalState.add_item("cana_pescar", 1)
			GlobalState.add_item("potion_high", 15)
			GlobalState.add_item("elixir_max", 10)
			_equip_item_safely("plasma_staff")
			_equip_item_safely("plasma_barrier")
			_equip_item_safely("alloy_mesh")
			_equip_item_safely("crown_of_light")

		8:
			# Zona 8: Zona Secreta / Post-Game (39, 59)
			# Nivel 50, jobs al máximo (30), juego completado al 100%
			GlobalState.level = 50
			GlobalState.stat_points = 100
			GlobalState.stats = {"str": 100, "dex": 100, "int": 100, "con": 100}
			_set_all_jobs_level(GameConfig.MAX_JOB_LEVEL)
			GlobalState.unlocked_skills = ExplorationSkills.all_ids()
			GlobalState.dam_opened = true
			GlobalState.cave_cleared = true
			GlobalState.world_flags["dam_opened"] = true
			GlobalState.world_flags["cave_cleared"] = true
			GlobalState.world_flags["monkey_cleared"] = true
			GlobalState.world_flags["ship_unlocked"] = true
			GlobalState.world_flags["sentinel_passed"] = true
			GlobalState.world_flags["guardian_defeated"] = true
			GlobalState.world_flags["game_completed"] = true
			GlobalState.quest_state = "game_completed"
			GlobalState.add_item("hacha", 1)
			GlobalState.add_item("pico", 1)
			GlobalState.add_item("pala", 1)
			GlobalState.add_item("tent", 1)
			GlobalState.add_item("cana_pescar", 1)
			GlobalState.add_item("potion_high", 20)
			GlobalState.add_item("elixir_max", 20)
			_equip_item_safely("aegis_slayer")
			_equip_item_safely("titanium_plate")
			_equip_item_safely("crown_of_light")

	GlobalState.player_pos = target_coord
	GlobalState.recalculate_derived_stats()
	if zone_idx == 1:
		GlobalState.hp = 1
		GlobalState.mp = 1
	else:
		GlobalState.hp = GlobalState.max_hp
		GlobalState.mp = GlobalState.max_mp
	GlobalState.energy = float(GlobalState.max_energy)

	# Reconstruir mapa de acuerdo a las banderas de la zona
	WorldMapBuilder.build_into_global()

	if world != null:
		world.player_pos = target_coord
		world._current_cell = target_coord
		var wp: Vector3 = world._cell_to_world(target_coord)
		if world._player != null:
			world._player.position = wp
		if world._cam != null:
			world._cam.position = wp + Vector3(0.0, world.CAM_HEIGHT, world.CAM_BACK)
			world._cam_look_target = wp
			world._cam.look_at(wp, Vector3.UP)
		world._rebuild_tiles()
		if world._streamer != null:
			world._streamer.update_active_chunks(world, target_coord)
		var cell: CellResource = GlobalState.hexagons_db.get(target_coord, null) as CellResource
		if cell != null:
			world._update_location_panel(cell)
		UiKit.toast(world, "📍 %s (Nv. %d)" % [info.get("name", ""), info.get("level", 1)], UiKit.ACCENT)

	GlobalState.state_updated.emit()


## Desbloquea las 6 profesiones de maestría al Nivel Máximo para pruebas
static func unlock_all_professions_debug(world: Node = null) -> void:
	_set_all_jobs_level(GameConfig.MAX_JOB_LEVEL)
	GlobalState.world_flags["all_professions_mastered"] = true
	GlobalState.quest_state = "all_professions_mastered"
	GlobalState.state_updated.emit()
	if world != null:
		UiKit.toast(world, Locale.pick({
			"es": "👑 ¡6 Profesiones de Maestría dominadas! Habla con el Rey en Celestia.",
			"en": "👑 All 6 Mastery Professions mastered! Speak with the King in Celestia."
		}), UiKit.GOOD)


static func _set_jobs_subset_level(prof_list: Array, lvl: int) -> void:
	GlobalState.unlocked_professions.clear()
	for p in prof_list:
		GlobalState.unlocked_professions.append(String(p))
	GlobalState.profession = String(prof_list[1]) if prof_list.size() > 1 else String(prof_list[0])
	GlobalState.job_level = lvl
	GlobalState.job_xp = 0
	GlobalState.job_xp_needed = 100 if lvl < GameConfig.MAX_JOB_LEVEL else 1
	GlobalState.profession_levels.clear()
	for p_key in prof_list:
		var pk := String(p_key)
		GlobalState.profession_levels[pk] = {
			"level": lvl,
			"xp": 0,
			"xp_needed": 100 if lvl < GameConfig.MAX_JOB_LEVEL else 1
		}
		GlobalState.active_combat_skills[pk] = GlobalState._default_combat_skill_slots(pk)


static func _set_all_jobs_level(lvl: int) -> void:
	var pro_keys: Array = Design.get_professions().keys()
	GlobalState.unlocked_professions.assign(pro_keys)
	GlobalState.profession = "Guerrero" if pro_keys.has("Guerrero") else (pro_keys[0] if not pro_keys.is_empty() else "Don Nadie")
	GlobalState.job_level = lvl
	GlobalState.job_xp = 0
	GlobalState.job_xp_needed = 100 if lvl < GameConfig.MAX_JOB_LEVEL else 1
	GlobalState.profession_levels.clear()
	GlobalState.active_combat_skills.clear()
	for p_key: String in pro_keys:
		GlobalState.profession_levels[p_key] = {
			"level": lvl,
			"xp": 0,
			"xp_needed": 100 if lvl < GameConfig.MAX_JOB_LEVEL else 1
		}
		GlobalState.active_combat_skills[p_key] = GlobalState._default_combat_skill_slots(p_key)


static func _equip_item_safely(item_id: String) -> void:
	var def: Dictionary = Design.get_item(item_id)
	if def.is_empty():
		return
	# BUG: antes se creaba el equipo dos veces por separado -
	# `add_equipment_item` lo metía en el inventario con UNA instancia de
	# EquipmentResource, y aquí se construía OTRA instancia distinta (con
	# rareza/color potencialmente diferente, ya que `add_equipment_item` sin
	# argumento de rareza usa "" mientras que aquí se leía la rareza real del
	# item) que se asignaba directamente a `equipped[slot]`, sin quitar nunca
	# la copia del inventario. Resultado: la misma pieza aparecía DOS veces en
	# la pantalla de equipo (una en el inventario, otra puesta), ambas
	# marcadas como "equipada" por coincidir el id. Usar el flujo normal de
	# equipar (añadir al inventario y equipar ESE MISMO objeto) evita la
	# duplicación.
	GlobalState.add_equipment_item(item_id)
	GlobalState.equip_item(item_id)
