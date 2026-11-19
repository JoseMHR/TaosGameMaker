class_name CombatDamageResolver
extends RefCounted
## RESOLUCIÓN DE COMBATE, DAÑO Y ESTADOS ALTERADOS — Componente especialista
## extraído de ViewCombat.
##
## NOTA de implementación: se modela como `RefCounted` (no `Node`), igual que
## `CombatTurnEngine`/`CombatQueueSystem`, porque no
## se añade al árbol de escena. No usa API exclusiva de Node: los tweens se
## crean vía `_view.create_tween()`.
##
## Encapsula: la intro de entrada al combate, aplicar daño a enemigo/jugador
## (incluida resurrección), el fin de combate (victoria/derrota + recompensas),
## la resolución de un ataque (precisión/crítico/elemento/defensa) y todo el
## sistema de ESTADOS ALTERADOS (aplicar/consumir/decrementar, iconos de estado).
##
## Mantiene una referencia a la `ViewCombat` propietaria (`_view`), sobre cuyos
## nodos y estado opera. `ViewCombat` mantiene fachadas con las mismas firmas
## públicas (`apply_damage_to_enemy`, `apply_damage_to_player`, `_end_combat`,
## `_resolve_attack_on_enemy`, `_reveal_elemental_reaction`, `_consume_status`,
## `_status_tick`, `_decrement_statuses`, `_apply_status`,
## `_try_apply_status_to_enemy`, `_try_apply_status_to_player`,
## `_apply_skill_status`, `_update_status_labels`, `_rebuild_status_icons`,
## `_rebuild_status_icons_deferred`, `_status_summary`, `_status_icon`,
## `_status_color`, `_status_label`, `_play_intro_sequence`) que redirigen a
## este componente, de modo que ningún llamante externo (incluido
## `CombatTurnEngine`, que ya invoca algunas de ellas vía `_view.`) cambia. El
## comportamiento es IDÉNTICO al monolito original.

## Vista de combate propietaria del estado y de los nodos UI.
var _view: ViewCombat = null

## Enlaza este componente con la ViewCombat propietaria. Debe llamarse una vez
## tras instanciarlo (en `ViewCombat._ready`).
func setup(view: ViewCombat) -> void:
	_view = view


func _play_intro_sequence() -> Tween:
	if _view == null:
		return null

	_view.reset_hero_position()
	_view.is_intro_playing = true

	# 1. Ocultar HUDs al inicio de la animación
	if _view._combat_console != null:
		_view._combat_console.modulate.a = 0.0
	if _view._enemy_panel != null:
		_view._enemy_panel.modulate.a = 0.0
	if _view._bg_texture_rect != null:
		_view._bg_texture_rect.modulate.a = 0.0

	# 2. Guardar posiciones objetivo reales y desplazar los combatientes fuera de pantalla
	var enemy_node: Control = _view._enemy_sprite_container if _view._enemy_sprite_container != null else _view._enemy_img_rect
	var enemy_base_x: float = enemy_node.position.x if enemy_node != null else 0.0
	var hero_node: Control = _view._hero_sprite_rect
	var hero_base_x: float = hero_node.position.x if hero_node != null else 0.0

	var slide_offset: float = 450.0

	if enemy_node != null:
		enemy_node.position.x = enemy_base_x - slide_offset
		enemy_node.modulate.a = 0.0
	if _view._enemy_platform != null:
		_view._enemy_platform.modulate.a = 0.0

	if hero_node != null and hero_node.visible:
		hero_node.position.x = hero_base_x + slide_offset
		hero_node.modulate.a = 0.0

	# 3. Crear Tween secuenciado
	var tw := _view.create_tween()

	# Paso A: Fade in del fondo
	if _view._bg_texture_rect != null:
		tw.tween_property(_view._bg_texture_rect, "modulate:a", 1.0, 0.25)

	# Paso B: Los dos luchadores se deslizan suavemente hacia el centro desde los laterales
	var slide_dur: float = 0.70
	if enemy_node != null:
		tw.parallel().tween_property(enemy_node, "position:x", enemy_base_x, slide_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(enemy_node, "modulate:a", 1.0, slide_dur * 0.75)
	if _view._enemy_platform != null:
		tw.parallel().tween_property(_view._enemy_platform, "modulate:a", 1.0, slide_dur)

	if hero_node != null and hero_node.visible:
		tw.parallel().tween_property(hero_node, "position:x", hero_base_x, slide_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(hero_node, "modulate:a", 1.0, slide_dur * 0.75)

	# Paso C: Tras deslizarse los personajes, aparecen las barras y la consola
	var hud_dur: float = 0.35
	if _view._enemy_panel != null:
		tw.chain().tween_property(_view._enemy_panel, "modulate:a", 1.0, hud_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _view._combat_console != null:
		if _view._enemy_panel != null:
			tw.parallel().tween_property(_view._combat_console, "modulate:a", 1.0, hud_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			tw.chain().tween_property(_view._combat_console, "modulate:a", 1.0, hud_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Paso D: Concluye la intro, restaura salvaguardas y arranca el combate
	tw.chain().tween_callback(func() -> void:
		if enemy_node != null:
			enemy_node.position.x = enemy_base_x
			enemy_node.modulate.a = 1.0
		if _view._enemy_platform != null:
			_view._enemy_platform.modulate.a = 1.0
		if hero_node != null:
			hero_node.position.x = hero_base_x
			hero_node.modulate.a = 1.0
		if _view._enemy_panel != null:
			_view._enemy_panel.modulate.a = 1.0
		if _view._combat_console != null:
			_view._combat_console.modulate.a = 1.0
		_view.is_intro_playing = false
		var terrain_code := String(_view.enemy_data.get("terrain", "grs"))
		CombatFx.spawn_biome_particles(_view._damage_popups_node, terrain_code)
	)
	return tw


func apply_damage_to_enemy(amount: int, is_critical: bool = false, element: String = "") -> void:
	if amount > 0:
		if is_critical:
			AudioManager.play_sfx("hit_critical")
		else:
			AudioManager.play_sfx("hit")
		CombatFx.play_hit_reaction(_view, _view._enemy_img_rect, is_critical)
		var pop_type := "critical" if is_critical else "damage_enemy"
		var pop_pos := (_view._enemy_img_rect.global_position + _view._enemy_img_rect.size * 0.5 - Vector2(100, 40)) if _view._enemy_img_rect else Vector2(1350, 450)
		CombatFx.spawn_floating_number(_view, _view._damage_popups_node, pop_pos, amount, pop_type, element)
		# ideas.md #12: la sacudida ya no distingue solo crítico/normal — también
		# escala con el % real de vida del enemigo que se acaba de quitar, para
		# que un golpe que lo deja al borde de la muerte se note más que un
		# crítico de cosquillas contra un enemigo con mucha vida.
		var enemy_severity := clampf(float(amount) / float(max(_view.enemy_max_hp, 1)), 0.0, 1.0)
		Juice.shake(_view, (10.0 if is_critical else 4.0) + enemy_severity * 10.0, 0.2)
		_view.add_sintonia(float(amount) * 0.15)

	_view.enemy_hp = max(_view.enemy_hp - amount, 0)
	_view._bar_enemy_hp.max_value = _view.enemy_max_hp
	_view._bar_enemy_hp_ghost.max_value = _view.enemy_max_hp
	_view._animate_hp_bar(_view._bar_enemy_hp, _view._bar_enemy_hp_ghost, _view.enemy_hp, true)
	_view._lbl_enemy_hp.text = "%d / %d HP" % [_view.enemy_hp, _view.enemy_max_hp]

	if _view.enemy_hp <= 0:
		var is_dummy: bool = bool(_view.enemy_data.get("is_training_dummy", false)) or String(_view.enemy_data.get("id", "")) == "muneco_entrenamiento"
		if is_dummy:
			_view.enemy_hp = _view.enemy_max_hp
			_view._animate_hp_bar(_view._bar_enemy_hp, _view._bar_enemy_hp_ghost, _view.enemy_hp, true)
			_view._lbl_enemy_hp.text = "%d / %d HP" % [_view.enemy_hp, _view.enemy_max_hp]
			_view.log_message("[color=cyan]✨ ¡El muñeco absorbió todo el daño y se restaura por completo para seguir practicando![/color]")
			CombatFx.spawn_word(_view, _view._damage_popups_node, "¡RESTAURADO!", Color(0.3, 0.9, 1.0), _view._enemy_img_rect, "✨", 46)
		else:
			_end_combat(true)


## Nota: la mitigación QTE de Defensa/Parry ya se aplica
## ANTES de llegar aquí, en `_execute_enemy_action` (vía `_block_quality` /
## `_block_damage_mult`, fijados por `_on_btn_defense_pressed`). Este `amount`
## llega ya mitigado; NO se debe volver a comprobar la ventana QTE aquí.
func apply_damage_to_player(amount: int) -> void:
	if amount > 0:
		AudioManager.play_sfx("hit")
		var strength := clampf(float(amount) / float(max(GlobalState.max_hp, 1)), 0.0, 1.0)
		_view._shake(10.0 + strength * 14.0)
		CombatFx.blood_screen_fx(_view, strength)
		var hero_target: Control = (_view._hero_sprite_rect as Control) if (_view._hero_sprite_rect != null and _view._hero_sprite_rect.visible) else (_view._portrait_frame as Control)
		var pop_pos := (hero_target.global_position + hero_target.size * 0.5 - Vector2(80, 50)) if hero_target != null else Vector2(200, 600)
		CombatFx.spawn_floating_number(_view, _view._damage_popups_node, pop_pos, amount, "damage_player")
		_view.add_sintonia(float(amount) * 0.25)
		_view.play_hero_hurt_reaction(1.0)

	var new_hp: int = int(max(GlobalState.hp - amount, 0))

	if new_hp <= 0 and _view._pending_revive_pct > 0:
		new_hp = int(GlobalState.max_hp * _view._pending_revive_pct / 100.0)
		_view._pending_revive_pct = 0
		CombatFx.spawn_word(_view, _view._damage_popups_node, "¡RESURRECCIÓN!", Color(0.9, 0.9, 0.4), _view._lbl_player_hp)
		_view.log_message("[color=gold]✨ ¡Vuelves a la vida con %d HP![/color]" % new_hp)
	elif new_hp <= 0 and GlobalState.profession == "Sacerdote" and GlobalState.job_level >= 60 and not _view._resurreccion_used:
		_view._resurreccion_used = true
		new_hp = 1
		CombatFx.spawn_word(_view, _view._damage_popups_node, "¡RESURRECCIÓN!", Color(0.9, 0.9, 0.4), _view._lbl_player_hp)
		_view.log_message("[color=gold]✨ ¡Resurrección celestial! Evitas el daño letal y te mantienes a 1 HP.[/color]")

	GlobalState.hp = new_hp
	_view._update_player_bars()

	if GlobalState.hp <= 0:
		_end_combat(false)


func _end_combat(victory: bool, enemy_fled: bool = false) -> void:
	# Salvaguarda: restaurar Engine.time_scale y _world_time_scale a 1.0 de inmediato
	# para evitar cualquier ralentización o congelación fuera o al final del combate.
	_view._force_end_defense_effects()
	Engine.time_scale = 1.0
	_view._world_time_scale = 1.0
	_view.is_combat_active = false
	_view._last_victory = victory
	_view.combat_queue.clear()
	_view.update_queue_ui_elements()

	if victory:
		var raw_xp: int = _view.enemy_data.get("xp_reward", GameConfig.COMBAT_DEFAULT_XP_REWARD)
		var enemy_lvl: int = int(_view.enemy_data.get("level", 1))
		var player_lvl: int = max(1, GlobalState.level)
		# Escalado por diferencia de nivel: si el enemigo es de nivel inferior, la XP decae cuadráticamente.
		var ratio: float = float(enemy_lvl) / float(player_lvl)
		var diff_mult: float = clampf(pow(ratio, 2.0), 0.05, 1.5) if ratio < 1.0 else clampf(ratio, 1.0, 2.0)
		if String(_view.enemy_data.get("id", "")) in ["orco_berserker", "eco_fragmentado"] or bool(_view.enemy_data.get("is_boss", false)):
			diff_mult = 1.0
		var xp_reward: int = max(1, int(round(raw_xp * diff_mult)))
		var gold_reward: int = _view.enemy_data.get("gold_reward", GameConfig.COMBAT_DEFAULT_GOLD_REWARD)
		GlobalState.add_xp(xp_reward)
		# XP de profesión INDIVIDUAL por trabajo PARTICIPANTE (no solo la activa
		# al terminar): cada profesión que ejecutó al menos una habilidad de
		# verdad durante este combate recibe su propia ración completa (no
		# dividida), incentivando probar varias en el mismo combate en vez de
		# penalizarlo (ver docs/design/PROGRESSION.md §3.3). Si por lo que sea
		# no se registró ninguna (p. ej. victoria sin encolar nada), se cae al
		# comportamiento anterior: solo la profesión activa.
		var job_xp_amount := int(xp_reward * 0.7)
		var jobs_used: Array = _view._jobs_used_this_combat
		if jobs_used.is_empty():
			if GlobalState.profession != "Don Nadie":
				GlobalState.add_job_xp(job_xp_amount)
		else:
			for job in jobs_used:
				if String(job) != "Don Nadie":
					GlobalState.add_job_xp_to(String(job), job_xp_amount)
		GlobalState.gold += gold_reward
		GlobalState.report_kill()
		GlobalState.record_enemy_kill(String(_view.enemy_data.get("id", "")))   # bestiario: baja registrada

		var drops := GlobalState.grant_loot(_view.enemy_data)

		# Notificar misiones
		var enemy_id: String = _view.enemy_data.get("id", "")
		var cell_coord: Vector2i = _view.enemy_data.get("cell_coord", Vector2i(-1, -1))
		if _view.enemy_data.get("is_boss", false):
			GlobalState.mark_boss_defeated(String(_view.enemy_data.get("boss_key", enemy_id)))
			if QuestManager.has_method("on_combat_victory"):
				QuestManager.on_combat_victory(enemy_id, cell_coord)
		if cell_coord != Vector2i(-1, -1):
			# Enemigo del mapamundi: marcar derrotado con respawn de 120 segundos.
			var respawn_secs: int = int(_view.enemy_data.get("overworld_respawn", 120))
			if respawn_secs <= 0:
				respawn_secs = 120
			GlobalState.defeat_overworld_enemy(cell_coord, respawn_secs)

		if enemy_fled:
			_view.lbl_result.text = "🏆 ¡VICTORIA POR BOCHORNO!"
			_view.lbl_result.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
			_view.lbl_result_detail.text = "¡El enemigo no pudo soportar la vergüenza ajena de tus súplicas y se marchó!\n\nGanas %d XP y %d Monedas." % [xp_reward, gold_reward]
			if not drops.is_empty():
				_view.lbl_result_detail.text += "\n\nBotín: %s" % _view._format_drops(drops)
			_view.log_message("[color=gold]🏆 ¡Victoria! El enemigo huyó avergonzado. +%d XP, +%d oro[/color]" % [xp_reward, gold_reward])
			for d in drops:
				_view.log_message("[color=#%s]🎁 %s %s[/color]" % [String(d.get("color", "b8c0cc")), String(d.get("icon", "")), String(d.get("name", ""))])

			CombatFx.play_enemy_flee_animation(_view, _view._enemy_img_rect, _view._enemy_platform, func():
				_view.result_panel.visible = true
				_view._animate_result_panel(true)
				_view.combat_ended.emit(true)
			)
		else:
			_view.lbl_result.text = "🏆 ¡VICTORIA!"
			_view.lbl_result.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
			_view.lbl_result_detail.text = "Ganas %d XP y %d Monedas." % [xp_reward, gold_reward]
			if not drops.is_empty():
				_view.lbl_result_detail.text += "\n\nBotín: %s" % _view._format_drops(drops)

			_view.log_message("[color=gold]🏆 ¡Victoria! +%d XP, +%d oro[/color]" % [xp_reward, gold_reward])
			for d in drops:
				_view.log_message("[color=#%s]🎁 %s %s[/color]" % [String(d.get("color", "b8c0cc")), String(d.get("icon", "")), String(d.get("name", ""))])

			CombatFx.play_enemy_death_animation(_view, _view._enemy_img_rect, _view._enemy_platform, func():
				_view.result_panel.visible = true
				_view._animate_result_panel(true)
				_view.combat_ended.emit(true)
			)
	else:
		# El tono del mensaje de derrota depende de cuánta vida le quedaba al
		# enemigo: si casi no le has hecho daño es más ridículo/gracioso que si
		# estaba a un paso de caer también.
		var enemy_hp_pct: float = float(_view.enemy_hp) / float(max(1, _view.enemy_max_hp))
		var title := "💀 DERROTA"
		var detail := "Has sido derrotado por el enemigo."
		if enemy_hp_pct >= 0.9:
			title = "💀 Derrota ridícula"
			detail = "El enemigo se ríe en tu cara... ni se ha despeinado."
		elif enemy_hp_pct >= 0.5:
			title = "💀 Derrota Aplastante"
			detail = "Ni ha tenido que sudar para acabar contigo."
		elif enemy_hp_pct >= 0.25:
			title = "💀 Derrota ajustada"
			detail = "Casi lo tenías... pero \"casi\" solo vale en la petanca."
		else:
			title = "💀 Derrota a medias"
			detail = "Solo le faltaba un toque más. Además de manco, tienes mala suerte."
		_view.lbl_result.text = title
		_view.lbl_result.add_theme_color_override("font_color", UiKit.BAD)
		_view.lbl_result_detail.text = detail
		_view.log_message("[color=red]💀 Has sido derrotado en combate.[/color]")

		# Guarda la causa de la muerte para que la Sala de la Esfera (ViewOrbRoom)
		# elija una frase acorde: nivel 1 (mensaje genérico de siempre), jefe,
		# o enemigo normal (según cuánta vida le quedaba, >=50% o <50%).
		if GlobalState.level <= 1:
			GlobalState.pending_death_cause = {"cause": "level1"}
		elif bool(_view.enemy_data.get("is_boss", false)):
			GlobalState.pending_death_cause = {"cause": "boss"}
		elif enemy_hp_pct >= 0.5:
			GlobalState.pending_death_cause = {"cause": "normal_high"}
		else:
			GlobalState.pending_death_cause = {"cause": "normal_low"}

		CombatFx.play_hero_defeat_animation(_view, _view._hero_sprite_rect, func():
			_view.result_panel.visible = true
			_view._animate_result_panel(false)
			_view.combat_ended.emit(false)
		)


## Resuelve un ataque del jugador sobre el enemigo. Los modificadores provienen de
## los ATRIBUTOS de la habilidad (effect) y de los ESTADOS activos (data-driven),
## no de comprobaciones por nombre.
func _resolve_attack_on_enemy(raw_damage: int, type: String, element: String, combo: bool, skill: Dictionary = {}) -> Dictionary:
	var sid := String(skill.get("id", ""))
	var stag := String(skill.get("tag", ""))
	# Caso especial Don Nadie - "Guantazo": quita exactamente el mismo número que el nivel del héroe
	if sid == "nob_punch" or stag == "nobody_punch":
		var fixed_dmg: int = max(1, GlobalState.level)
		return {"miss": false, "crit": false, "weak": false, "resist": false, "combo": false, "damage": fixed_dmg, "element": "physical"}

	var effect: String = String(skill.get("effect", ""))
	var unblockable := effect.find("unblockable") != -1 or bool(skill.get("never_miss", false))

	# Si la habilidad es ataque físico básico sin elemento, hereda el elemento del arma equipada si tiene cualidad activa
	var active_element := element
	if active_element == "physical" or active_element == "":
		var weapon: EquipmentResource = GlobalState.equipped.get("weapon")
		if weapon != null:
			if weapon.element != "" and weapon.element != "none" and weapon.element != "physical":
				active_element = weapon.element
			else:
				for trait_entry in weapon.active_traits():
					if trait_entry.get("type") == "element_attack":
						active_element = String(trait_entry.get("element", "physical"))
						break

	# Precisión (esquiva del enemigo), salvo golpes imbloqueables o con acierto garantizado.
	if not unblockable:
		var hit_chance: float = GlobalState.get_accuracy() - float(_view.enemy_data.get("dodge", 0.0))
		if randf() * 100.0 > hit_chance:
			return {"miss": true, "crit": false, "weak": false, "resist": false, "combo": false, "damage": 0}

	# Cualidades de equipamiento activo (bonus de crítico, penetración, etc.)
	var extra_crit_chance: float = 0.0
	var extra_crit_mult: float = 0.0
	var armor_pen: float = 0.0
	var elem_dmg_bonus: float = 0.0

	for eq_slot in GlobalState.equipped.keys():
		var eq_res: EquipmentResource = GlobalState.equipped[eq_slot]
		if eq_res != null:
			for trait_entry in eq_res.active_traits():
				var tr_type: String = String(trait_entry.get("type", ""))
				if tr_type == "crit_chance":
					extra_crit_chance += float(trait_entry.get("value", 0.0))
				elif tr_type == "crit_damage":
					extra_crit_mult += float(trait_entry.get("value", 0.0))
				elif tr_type == "armor_penetration":
					armor_pen += float(trait_entry.get("value", 0.0))
				elif tr_type == "fire_damage_bonus" and active_element == "fire":
					elem_dmg_bonus += float(trait_entry.get("value", 0.0))
				elif tr_type == "lightning_damage_bonus" and active_element == "lightning":
					elem_dmg_bonus += float(trait_entry.get("value", 0.0))
				elif tr_type == "mag_damage_bonus" and type == "magic":
					elem_dmg_bonus += float(trait_entry.get("value", 0.0))

	# Crítico: base + estados + cualidades de equipo; forzado por effect/estado guaranteed_crit.
	var crit_chance: float = (GlobalState.get_crit() / 100.0) + extra_crit_chance + GameConfig.status_crit_add(_view.player_statuses)
	var force_crit := GameConfig.status_any_flag(_view.player_statuses, "force_crit") \
		or effect.find("guaranteed_crit") != -1 or effect.find("high_crit") != -1
	var crit: bool = force_crit or randf() < crit_chance
	if GameConfig.status_any_flag(_view.player_statuses, "force_crit"):
		_consume_status(_view.player_statuses, "guaranteed_crit")

	var dmg: float = float(raw_damage)

	# Buffs/debuffs ofensivos del portador (berserk/focus/blessing/concentración…).
	dmg *= GameConfig.status_out_mult(_view.player_statuses)
	# "Mente serena": el siguiente hechizo hace el doble (estado, no nombre).
	if type == "magic" and _view.player_statuses.has("mente_serena"):
		dmg *= 2.0
		_consume_status(_view.player_statuses, "mente_serena")

	if crit:
		dmg *= (GameConfig.CRIT_MULTIPLIER + extra_crit_mult)

	if elem_dmg_bonus > 0.0:
		dmg *= (1.0 + elem_dmg_bonus)

	var weak := false
	var resist := false
	var enemy_weaks: Array = _view.enemy_data.get("weak_to", [])
	var enemy_resists: Array = _view.enemy_data.get("resist", [])
	if active_element in enemy_weaks or type in enemy_weaks or stag in enemy_weaks:
		dmg *= GameConfig.ELEMENT_WEAK_MULT
		weak = true
	elif active_element in enemy_resists or type in enemy_resists or stag in enemy_resists:
		dmg *= GameConfig.ELEMENT_RESIST_MULT
		resist = true

	# Defensa del enemigo (mágica o física), reducida por debuffs de estado y penetración de armadura…
	var edef: float = float(_view.enemy_data.get("mag_defense", 0)) if type == "magic" else float(_view.enemy_data.get("phys_defense", 0))
	var def_mult_key := "mdef_mult" if type == "magic" else "pdef_mult"
	for st in _view.enemy_statuses:
		edef *= float(GameConfig.status_def(st).get(def_mult_key, 1.0))
	# …y por el effect de ignorar defensa de la habilidad o cualidad de arma.
	if effect.find("ignore_def_full") != -1 or (type == "magic" and effect.find("ignore_mdef") != -1):
		edef = 0.0
	elif effect.find("ignore_def_half") != -1:
		edef *= 0.5
	elif armor_pen > 0.0:
		edef *= clampf(1.0 - armor_pen, 0.0, 1.0)

	var final_dmg: int = GameConfig.mitigate(dmg, edef)
	return {"miss": false, "crit": crit, "weak": weak, "resist": resist, "combo": combo, "damage": final_dmg, "element": active_element}


## DEBILIDADES VISIBLES: al golpear con un elemento, muestra si el enemigo es
## DÉBIL o RESISTENTE a él y lo memoriza en el bestiario (conocimiento persistente).
func _reveal_elemental_reaction(element: String, result: Dictionary) -> void:
	var weak := bool(result.get("weak", false))
	var resist := bool(result.get("resist", false))
	if not weak and not resist:
		return
	if weak:
		CombatFx.spawn_word(_view, _view._damage_popups_node, "¡DÉBIL!", UiKit.GOOD, _view._enemy_img_rect, "▲")
	else:
		CombatFx.spawn_word(_view, _view._damage_popups_node, "RESISTE", UiKit.TEXT_DIM, _view._enemy_img_rect, "▼")
	GlobalState.discover_enemy_reaction(String(_view.enemy_data.get("id", "")), element, weak, resist)


## Elimina un estado del portador (si existe) y refresca las etiquetas.
func _consume_status(statuses: Dictionary, key: String) -> void:
	if statuses.has(key):
		statuses.erase(key)
		_update_status_labels()


func _status_tick(statuses: Dictionary) -> Dictionary:
	var dot: int = 0
	var regen_frac: float = 0.0
	var stun := false
	var slow := false
	for type in statuses.keys():
		var st: Dictionary = statuses[type]
		var def: Dictionary = GameConfig.STATUS_EFFECTS.get(type, {})
		if bool(def.get("dot", false)):
			dot += int(st.get("power", 0))
		regen_frac += float(def.get("regen", 0.0))
		if bool(def.get("skip", false)):
			stun = true
		if float(def.get("atb_mult", 1.0)) < 1.0:
			slow = true
	return {"dot": dot, "regen": regen_frac, "stun": stun, "slow": slow}


func _decrement_statuses(statuses: Dictionary) -> void:
	for type in statuses.keys():
		var st: Dictionary = statuses[type]
		st["turns"] = int(st.get("turns", 0)) - 1
		if int(st["turns"]) <= 0:
			statuses.erase(type)


func _apply_status(statuses: Dictionary, type: String, turns: int, power: int) -> void:
	var cur: Dictionary = statuses.get(type, {"turns": 0, "power": 0})
	statuses[type] = {
		"turns": max(int(cur.get("turns", 0)), turns),
		"power": max(int(cur.get("power", 0)), power),
	}


func _try_apply_status_to_enemy(status: Dictionary, dmg: int) -> void:
	if randf() > float(status.get("chance", 1.0)):
		return
	var type: String = String(status.get("type", ""))
	if type == "" or not GameConfig.STATUS_EFFECTS.has(type):
		return
	var power: int = int(status.get("power", 0))
	if power <= 0 and bool(GameConfig.STATUS_EFFECTS[type].get("dot", false)):
		power = max(1, int(dmg * 0.3))
	_apply_status(_view.enemy_statuses, type, int(status.get("turns", 2)), power)
	CombatFx.spawn_word(_view, _view._damage_popups_node, _status_label(type), Color(_status_color(type)), _view._enemy_img_rect)
	_view.log_message("[color=#%s]%s %s: %s[/color]" % [_status_color(type), _status_icon(type), _view._enemy_name(), _status_label(type)])
	_update_status_labels()


func _try_apply_status_to_player(soh: Dictionary) -> void:
	if randf() > float(soh.get("chance", 1.0)):
		return
	var type: String = String(soh.get("type", ""))
	if type == "" or not GameConfig.STATUS_EFFECTS.has(type):
		return
	_apply_status(_view.player_statuses, type, int(soh.get("turns", 2)), int(soh.get("power", 0)))
	CombatFx.spawn_word(_view, _view._damage_popups_node, _status_label(type), Color(_status_color(type)), _view._lbl_player_hp)
	_view.log_message("[color=#%s]%s %s: %s[/color]" % [_status_color(type), _status_icon(type), Locale.t("combat_you"), _status_label(type)])
	_update_status_labels()


func _apply_skill_status(skill: Dictionary, dmg: int) -> void:
	var status = skill.get("status", {})
	if status.is_empty():
		return
	if randf() > float(status.get("chance", 1.0)):
		return
	var type: String = String(status.get("type", ""))
	if type == "" or not GameConfig.STATUS_EFFECTS.has(type):
		return

	# El destino lo decide el campo `status.target` ("self"/"enemy"); si falta, se
	# infiere del tipo de la habilidad (soporte/curación => a uno mismo).
	var target := String(status.get("target", ""))
	var to_self: bool
	if target != "":
		to_self = (target == "self")
	else:
		to_self = (String(skill.get("type", "physical")) in ["buff", "defense", "heal", "support"])

	var turns := int(status.get("turns", 2))
	var power := int(status.get("power", 0))
	if power <= 0 and bool(GameConfig.STATUS_EFFECTS[type].get("dot", false)):
		power = max(1, int(dmg * 0.3))

	if to_self:
		_apply_status(_view.player_statuses, type, turns, power)
		CombatFx.spawn_word(_view, _view._damage_popups_node, _status_label(type), Color(_status_color(type)), _view._lbl_player_hp)
		_view.log_message("[color=#%s]%s %s: %s[/color]" % [_status_color(type), _status_icon(type), Locale.t("combat_you"), _status_label(type)])
	else:
		_apply_status(_view.enemy_statuses, type, turns, power)
		CombatFx.spawn_word(_view, _view._damage_popups_node, _status_label(type), Color(_status_color(type)), _view._enemy_img_rect)
		_view.log_message("[color=#%s]%s %s: %s[/color]" % [_status_color(type), _status_icon(type), _view._enemy_name(), _status_label(type)])
	_update_status_labels()


func _update_status_labels() -> void:
	if _view._lbl_enemy_status:
		_view._lbl_enemy_status.text = _status_summary(_view.enemy_statuses)
	if _view._enemy_debuffs_container:
		_rebuild_status_icons(_view._enemy_debuffs_container, _view.enemy_statuses)
	if _view._lbl_player_status:
		_view._lbl_player_status.text = _status_summary(_view.player_statuses)
		# Refrescar los iconos circulares de estado
		if _view._lbl_player_status.has_meta("icon_row"):
			_rebuild_status_icons(_view._lbl_player_status.get_meta("icon_row"), _view.player_statuses)


func _rebuild_status_icons(row: HBoxContainer, statuses: Dictionary) -> void:
	# Vaciar todos los hijos excepto el label oculto (con call_deferred para evitar
	# conflictos con queue_free asincrono)
	for child in row.get_children():
		if child != _view._lbl_player_status:
			child.queue_free()
	if statuses.is_empty():
		return
	# Crear los iconos en el siguiente frame para que queue_free haya terminado
	call_deferred("_rebuild_status_icons_deferred", row, statuses)


func _rebuild_status_icons_deferred(row: HBoxContainer, statuses: Dictionary) -> void:
	# Por si el nodo fue liberado entre frames
	if not is_instance_valid(row):
		return
	# Limpiar de nuevo por si quedaron hijos
	for child in row.get_children():
		if child != _view._lbl_player_status and is_instance_valid(child):
			child.queue_free()
	for status_key in statuses.keys():
		var icon_txt := _status_icon(status_key)
		var turns: int = int(statuses[status_key].get("turns", 0))
		var col_hex := _status_color(status_key)
		# Asegurar que el color tiene el prefijo # para is_valid_html_color()
		if not col_hex.begins_with("#"):
			col_hex = "#" + col_hex
		var fill_col := Color(col_hex) if col_hex.is_valid_html_color() else Color(0.5, 0.5, 0.9)

		# Contenedor circular (PanelContainer con borde del tema)
		var bubble := PanelContainer.new()
		bubble.custom_minimum_size = Vector2(26, 26)
		var bubble_style := StyleBoxFlat.new()
		bubble_style.bg_color = fill_col.darkened(0.45)
		bubble_style.set_corner_radius_all(999)
		bubble_style.set_border_width_all(2)
		bubble_style.border_color = _view._theme_color("border", Color(1.0, 1.0, 1.0, 0.9))
		bubble_style.shadow_color = fill_col.lightened(0.2)
		bubble_style.shadow_size = 4
		bubble.add_theme_stylebox_override("panel", bubble_style)
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Icono centrado
		var lbl := Label.new()
		lbl.text = icon_txt
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", _view._theme_color("text", Color.WHITE))
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(lbl)

		# Badge de turnos restantes (esquina inferior-derecha)
		if turns > 0:
			var badge := Label.new()
			badge.text = str(turns)
			badge.add_theme_font_size_override("font_size", 9)
			badge.add_theme_color_override("font_color", _view._theme_color("text", Color.WHITE))
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bubble.add_child(badge)

		row.add_child(bubble)
		bubble.tooltip_text = "%s %s (%d turnos)" % [icon_txt, _status_label(status_key), turns]


func _status_summary(statuses: Dictionary) -> String:
	if statuses.is_empty():
		return ""
	var parts: Array = []
	for type in statuses.keys():
		parts.append("%s%d" % [_status_icon(type), int(statuses[type].get("turns", 0))])
	return "  ".join(parts)


func _status_icon(type: String) -> String:
	return String(GameConfig.STATUS_EFFECTS.get(type, {}).get("icon", "✨"))


func _status_color(type: String) -> String:
	return String(GameConfig.STATUS_EFFECTS.get(type, {}).get("color", "ffffff"))


func _status_label(type: String) -> String:
	return Locale.t(String(GameConfig.STATUS_EFFECTS.get(type, {}).get("loc", type)))
