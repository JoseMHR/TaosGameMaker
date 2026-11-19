class_name CombatResultUI
extends RefCounted
## PANEL DE RESULTADO, REFRESCO DE BARRAS/COLA Y BOTONES CONTINUAR/HUIDA —
## Componente especialista extraído de ViewCombat.
##
## NOTA de implementación: se modela como `RefCounted` (no `Node`), igual que
## `CombatTurnEngine`/`CombatQueueSystem`/`CombatDamageResolver`, porque no se
## añade al árbol de escena. No usa API exclusiva de Node: los tweens se crean
## vía `_view.create_tween()`.
##
## Encapsula: la animación de entrada del panel de resultado y el shake de
## pantalla, el pintado de la cola de acciones (slots de PA, fusiones de
## sinergia), el refresco de barras del jugador (HP/MP/Resonancia/ATB) y sus
## pulsos de aviso, la habilitación de los botones EJECUTAR/DEFENDER, y los
## botones CONTINUAR/HUIR del panel de resultado.
##
## Mantiene una referencia a la `ViewCombat` propietaria (`_view`), sobre cuyos
## nodos y estado opera. `ViewCombat` mantiene fachadas con las mismas firmas
## públicas (`_animate_result_panel`, `_shake`, `_build_queue_box_mapping`,
## `update_queue_ui_elements`, `_animate_synergy_badge`, `_on_queue_slot_clicked`,
## `_update_player_bars`, `_update_resonance_glow`, `_start_hp_danger_pulse`,
## `_stop_hp_danger_pulse`, `_sync_player_atb_labels`, `_update_action_buttons`,
## `_refresh_chrome`, `_on_btn_return_pressed`, `_on_btn_flee_pressed`) que
## redirigen a este componente, de modo que ningún llamante externo (incluidos
## `CombatTurnEngine`, `CombatQueueSystem` y `CombatDamageResolver`, que ya
## invocan varias de ellas vía `_view.`) cambia. El comportamiento es IDÉNTICO
## al monolito original.

## Vista de combate propietaria del estado y de los nodos UI.
var _view: ViewCombat = null

## Enlaza este componente con la ViewCombat propietaria. Debe llamarse una vez
## tras instanciarlo (en `ViewCombat._ready`).
func setup(view: ViewCombat) -> void:
	_view = view


## Entrada animada del panel de resultado (escala + fundido) y, en victoria, un
## destello dorado a pantalla completa por detrás del panel.
func _animate_result_panel(victory: bool) -> void:
	if Locale.reduce_motion:
		return
	if victory:
		var flash := ColorRect.new()
		flash.color = Color(1.0, 0.85, 0.35, 0.0)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.add_child(flash)
		_view.move_child(flash, _view.result_panel.get_index())   # detrás del panel
		var ftw := _view.create_tween()
		ftw.tween_property(flash, "color:a", 0.45, 0.12)
		ftw.tween_property(flash, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
		ftw.finished.connect(flash.queue_free)

	_view.result_panel.pivot_offset = _view.result_panel.size * 0.5
	_view.result_panel.scale = Vector2(0.82, 0.82)
	_view.result_panel.modulate.a = 0.0
	var tw := _view.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_view.result_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_view.result_panel, "modulate:a", 1.0, 0.25)


func _shake(intensity: float) -> void:
	if Locale.reduce_motion:
		return
	if _view._shake_tween != null and _view._shake_tween.is_valid():
		return
	var main_node = _view.get_child(1) # El contenedor de Margen Principal
	var home: Vector2 = main_node.position
	_view._shake_tween = _view.create_tween()
	for i in range(5):
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_view._shake_tween.tween_property(main_node, "position", home + off, 0.04)
	_view._shake_tween.tween_property(main_node, "position", home, 0.05)


## Mapeo proporcional de casillas de PA (MAX_QUEUE) → habilidad de la cola que
## ocupa cada una. Compartido por `update_queue_ui_elements()` (pintado) y
## `_on_queue_slot_clicked()` (para saber qué habilidad quitar al pulsar).
func _build_queue_box_mapping() -> Array:
	var box_mapping: Array = []
	for i in range(_view.MAX_QUEUE):
		box_mapping.append(null)

	var current_box_idx := 0
	for skill_idx in range(_view.combat_queue.size()):
		var skill := _view.combat_queue[skill_idx]
		var pa := int(skill.get("pa", 1))
		for k in range(pa):
			if current_box_idx < _view.MAX_QUEUE:
				box_mapping[current_box_idx] = {
					"skill": skill,
					"skill_idx": skill_idx,
					"is_start": k == 0,
					"span": pa
				}
				current_box_idx += 1
	return box_mapping


## Detiene (mata) el tween en bucle del pulso dorado de sinergia de `slot_panel`
## si hay uno corriendo, y restaura su modulate a blanco. Centraliza una
## limpieza que antes solo ponía `syn_pulsing` a `false` SIN matar el tween en
## sí (el bucle seguía re-modulando el panel para siempre en segundo plano).
func _stop_synergy_pulse(slot_panel: Control) -> void:
	# `get_meta(name, default)` con `default = null` NO evita el error/aviso de
	# "the object does not have any 'meta' values..." en Godot: internamente,
	# un default NIL es indistinguible de "no se dio default". Hay que
	# comprobar con `has_meta()` antes de leer.
	if slot_panel.has_meta("syn_tween"):
		var tw = slot_panel.get_meta("syn_tween")
		if tw is Tween and tw.is_valid():
			tw.kill()
		slot_panel.remove_meta("syn_tween")
	if slot_panel.has_meta("syn_pulsing"):
		slot_panel.remove_meta("syn_pulsing")
	slot_panel.modulate = Color.WHITE


func update_queue_ui_elements() -> void:
	if _view._queue_slots.is_empty():
		return

	var max_slots := _view._get_max_queue_slots()
	var box_mapping := _build_queue_box_mapping()

	for i in range(_view.MAX_QUEUE):
		var slot_panel := _view._queue_slots[i]
		var slot_visible := i < max_slots
		slot_panel.visible = slot_visible  # Ocultar slots no alcanzables

		var empty_lbl: Label = slot_panel.get_meta("empty_lbl")
		var hbox: VBoxContainer = slot_panel.get_meta("hbox")
		var icon_rect: TextureRect = slot_panel.get_meta("icon_rect")
		var icon_fallback_lbl: Label = slot_panel.get_meta("icon_fallback_lbl")
		var name_lbl: Label = slot_panel.get_meta("name_lbl")
		var pa_lbl: Label = slot_panel.get_meta("pa_lbl")

		var is_locked := i >= max_slots
		var data = box_mapping[i]

		# Determinar fusiones/sinergias para unir recuadros en rectángulos
		var merge_left := false
		var merge_right := false
		if slot_visible and data != null:
			var skill = data.skill
			var is_syn = skill.get("is_synergy", false)

			if i > 0:
				var prev_data = box_mapping[i - 1]
				if prev_data != null:
					var prev_skill = prev_data.skill
					var prev_syn = prev_skill.get("is_synergy", false)
					if prev_data.skill_idx == data.skill_idx or (is_syn and prev_syn):
						merge_left = true
			if i < max_slots - 1:
				var next_data = box_mapping[i + 1]
				if next_data != null:
					var next_skill = next_data.skill
					var next_syn = next_skill.get("is_synergy", false)
					if next_data.skill_idx == data.skill_idx or (is_syn and next_syn):
						merge_right = true

		# Una fusión de sinergia debe verse como UNA sola
		# carta, no como 2 casillas pegadas. Antes solo se aplanaban los bordes
		# del lado que se toca, pero las 2 `PanelContainer` seguían siendo nodos
		# HERMANOS separados por el `separation` del `HBoxContainer` de la cola
		# (4px), así que el hueco entre ellas seguía siendo visible. La casilla
		# de CONTINUACIÓN (`merge_left`) se oculta por completo (`visible =
		# false`, no solo su contenido): al desaparecer del layout, la casilla
		# de INICIO (que ya tiene `SIZE_EXPAND_FILL`) se expande sola para
		# ocupar exactamente el hueco liberado — sin separación residual.
		if merge_left:
			slot_panel.visible = false

		# Separador visual entre slots (ocultar si el siguiente es invisible o si hay fusión)
		if i < _view.MAX_QUEUE - 1 and i < _view._queue_separators.size():
			var sep := _view._queue_separators[i]
			sep.visible = (i + 1 < max_slots) and not merge_right

		# La casilla de continuación (ahora invisible/fuera del layout) no
		# necesita más trabajo de pintado: saltar directamente a la siguiente.
		# Se detiene cualquier pulso de sinergia que pudiera haber quedado
		# corriendo de un turno anterior en el que este mismo nodo reutilizado
		# fuese la casilla "inicio" (evita un tween en bucle huérfano sobre un
		# nodo ya oculto).
		if merge_left:
			_stop_synergy_pulse(slot_panel)
			continue

		if data != null:
			var skill = data.skill

			if data.is_start:
				empty_lbl.visible = false
				hbox.visible = true

				var skill_id := String(skill.get("id", ""))
				var img_path := ""
				if skill.get("type", "") == "potion" or skill.has("item_id"):
					var item_id := String(skill.get("item_id", ""))
					img_path = "res://assets/combat/skills/item_%s.png" % item_id
				elif skill.get("type", "") == "class_change":
					img_path = CombatTabsUI.get_prof_texture_path(String(skill.get("profession", "")))
				else:
					img_path = "res://assets/combat/skills/%s.png" % skill_id

				var is_syn_icon: bool = skill.get("is_synergy", false)
				if ResourceLoader.exists(img_path):
					icon_rect.texture = load(img_path)
					icon_rect.visible = true
					if icon_fallback_lbl != null:
						icon_fallback_lbl.visible = false
				else:
					icon_rect.texture = null
					# Carta de combo sin PNG dedicado todavía: mostrar el
					# icono de respaldo "⚡" en vez de dejarla vacía/rota.
					if is_syn_icon and icon_fallback_lbl != null:
						icon_rect.visible = false
						icon_fallback_lbl.visible = true
					else:
						icon_rect.visible = true
						if icon_fallback_lbl != null:
							icon_fallback_lbl.visible = false
				name_lbl.text = _view._skill_name(skill)
				pa_lbl.text = "PA %d" % int(skill.get("pa", 1))

				slot_panel.tooltip_text = "%s\nPA: %d" % [_view._skill_name(skill), int(skill.get("pa", 1))]
			else:
				# Casilla de continuación: vacía pero con fondo de unión
				empty_lbl.visible = false
				hbox.visible = false
				slot_panel.tooltip_text = ""

			if is_locked:
				pa_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
			else:
				pa_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))

			var is_syn: bool = skill.get("is_synergy", false)
			var base_style := _view._queue_slot_style(is_syn, false)
			var style := base_style.duplicate() as StyleBoxFlat
			if is_syn:
				# Carta de combo premium — más gruesa y
				# con más resplandor que una casilla normal, para que se lea
				# como "un objeto especial", no como una casilla más.
				style.bg_color = Color(0.22, 0.18, 0.05, 0.95)
				style.border_color = Color(0.98, 0.82, 0.32)
				style.set_border_width_all(3)
				style.shadow_color = Color(0.98, 0.80, 0.32, 0.55)
				style.shadow_size = 10
			# NOTA: ya NO se aplanan las esquinas del lado `merge_left`/
			# `merge_right` — la casilla de continuación se OCULTA por
			# completo (arriba) en vez de quedar pegada, así que esta casilla
			# (la única visible) es ahora una carta AUTÓNOMA y debe conservar
			# sus 4 esquinas redondeadas normales.
			slot_panel.add_theme_stylebox_override("panel", style)

			# Pulso dorado animado para la sinergia (ambas casillas pulsan al unísono)
			if is_syn and not Locale.reduce_motion:
				if not slot_panel.has_meta("syn_pulsing"):
					slot_panel.set_meta("syn_pulsing", true)
					var syn_tw := slot_panel.create_tween().set_loops()
					slot_panel.set_meta("syn_tween", syn_tw)
					syn_tw.tween_property(slot_panel, "modulate", Color(1.6, 1.4, 0.5), 0.5).set_trans(Tween.TRANS_SINE)
					syn_tw.tween_property(slot_panel, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
			else:
				_stop_synergy_pulse(slot_panel)
		else:
			hbox.visible = false
			empty_lbl.visible = true
			slot_panel.tooltip_text = ""
			_stop_synergy_pulse(slot_panel)

			if is_locked:
				empty_lbl.text = "🔒"
				empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.4, 0.45))
				slot_panel.add_theme_stylebox_override("panel", _view._queue_slot_style(false, true))
			else:
				empty_lbl.text = "[ + ]"
				empty_lbl.add_theme_color_override("font_color", Color(0.32, 0.30, 0.40))
				slot_panel.add_theme_stylebox_override("panel", _view._queue_slot_style(false, true))

	# Comprobar e iluminar/rotar la insignia de sinergia entre los 2 slots
	if _view._queue_separators.size() > 0:
		var sep := _view._queue_separators[0]
		var has_synergy := false
		if _view.combat_queue.size() >= 2:
			var id_a := String(_view.combat_queue[0].get("id", ""))
			var id_b := String(_view.combat_queue[1].get("id", ""))
			var syn := Design.get_synergy(String(GlobalState.profession), id_a, id_b)
			has_synergy = not syn.is_empty()
		_animate_synergy_badge(sep, has_synergy)

	# SIN texto instructivo permanente. La propia cola de
	# cartas (con sus casillas fusionadas al detectar sinergia) ya comunica el
	# estado; esta etiqueta solo aparece para ANUNCIAR una sinergia doble/triple
	# ya confirmada (el "bloque fusionado" con nombre del combo resultante).
	if _view._lbl_synergy_chain != null:
		_view._lbl_synergy_chain.visible = false
		if _view.combat_queue.size() == 2:
			var id_a := String(_view.combat_queue[0].get("id", ""))
			var id_b := String(_view.combat_queue[1].get("id", ""))
			var syn := Design.get_synergy(String(GlobalState.profession), id_a, id_b)
			if not syn.is_empty():
				var syn_name: String = Locale.pick(syn.get("name", {"es": "Sinergia Épica", "en": "Epic Synergy"}))
				_view._lbl_synergy_chain.text = "🔥 ¡%s!" % syn_name
				_view._lbl_synergy_chain.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
				_view._lbl_synergy_chain.visible = true
		elif _view.combat_queue.size() >= 3:
			var id_a := String(_view.combat_queue[0].get("id", ""))
			var id_b := String(_view.combat_queue[1].get("id", ""))
			var id_c := String(_view.combat_queue[2].get("id", ""))
			var triple := Design.get_triple_synergy(String(GlobalState.profession), id_a, id_b, id_c)
			if not triple.is_empty():
				var syn_name: String = Locale.pick(triple.get("name", {"es": "Sinergia Suprema", "en": "Supreme Synergy"}))
				_view._lbl_synergy_chain.text = "⭐ ¡%s! (SUPREMA)" % syn_name
				_view._lbl_synergy_chain.add_theme_color_override("font_color", _view.COL_GOLD)
				_view._lbl_synergy_chain.visible = true


func _animate_synergy_badge(badge: Control, active: bool) -> void:
	if badge == null or not is_instance_valid(badge):
		return
	var is_currently_active: bool = badge.has_meta("active") and badge.get_meta("active") == true
	if is_currently_active == active:
		return
	badge.set_meta("active", active)

	var syn_style := StyleBoxFlat.new()
	syn_style.set_corner_radius_all(19)
	syn_style.set_border_width_all(2)

	if active:
		syn_style.bg_color = Color(0.40, 0.30, 0.08, 0.95)
		syn_style.border_color = _view.COL_GOLD
		syn_style.shadow_color = Color(0.98, 0.80, 0.32, 0.6)
		syn_style.shadow_size = 10
		badge.add_theme_stylebox_override("panel", syn_style)

		var tw := badge.create_tween().set_parallel(true)
		tw.tween_property(badge, "rotation_degrees", 360.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(badge, "scale", Vector2(1.3, 1.3), 0.3).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(badge, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_IN)
	else:
		badge.rotation_degrees = 0.0
		badge.scale = Vector2.ONE
		syn_style.bg_color = Color(0.10, 0.08, 0.18, 0.85)
		syn_style.border_color = Color(0.40, 0.35, 0.55, 0.6)
		badge.add_theme_stylebox_override("panel", syn_style)


func _on_queue_slot_clicked(slot_index: int) -> void:
	# Reconstruir box_mapping (helper compartido) para saber qué skill corresponde a esta casilla de PA
	var box_mapping := _build_queue_box_mapping()

	if slot_index < box_mapping.size() and box_mapping[slot_index] != null:
		var skill_idx: int = box_mapping[slot_index].skill_idx
		AudioManager.play_sfx("click")
		_view.combat_queue.remove_at(skill_idx)
		_view._recount_queued_pa()
		update_queue_ui_elements()


func _update_player_bars() -> void:
	_view._bar_player_hp.max_value = GlobalState.max_hp
	_view._bar_player_hp_ghost.max_value = GlobalState.max_hp
	_view._animate_hp_bar(_view._bar_player_hp, _view._bar_player_hp_ghost, GlobalState.hp, false)
	_view._lbl_player_hp.text = "%d / %d HP" % [GlobalState.hp, GlobalState.max_hp]

	# Color dinámico de salud
	var hp_ratio := float(GlobalState.hp) / float(max(GlobalState.max_hp, 1))
	var hp_style := StyleBoxFlat.new()
	hp_style.set_corner_radius_all(4)
	if hp_ratio > 0.5:
		hp_style.bg_color = Color("2ecc71")
	elif hp_ratio >= 0.25:
		hp_style.bg_color = Color("f1c40f")
	else:
		hp_style.bg_color = Color("e74c3c")
	_view._bar_player_hp.add_theme_stylebox_override("fill", hp_style)

	_view._bar_player_mp.max_value = GlobalState.max_mp
	_view._bar_player_mp.value = GlobalState.mp
	_view._lbl_player_mp.text = "%d / %d MP" % [GlobalState.mp, GlobalState.max_mp]

	var in_danger: bool = GlobalState.max_hp > 0 and hp_ratio <= 0.25 and GlobalState.hp > 0
	if in_danger and not _view._hp_was_in_danger:
		_start_hp_danger_pulse()
	elif not in_danger and _view._hp_was_in_danger:
		_stop_hp_danger_pulse()
	_view._hp_was_in_danger = in_danger

	# Además del color de la barra, cambiar el propio texto/
	# icono de la etiqueta "HP" en peligro crítico, para no depender solo del
	# color (accesibilidad daltónica).
	if _view._lbl_hp_tag != null:
		_view._lbl_hp_tag.text = "⚠ HP" if in_danger else "HP"

	# Círculo de RESONANCIA
	if _view._resonance_circle:
		_view._resonance_circle.set_resonance(_view.player_resonance, GameConfig.RESONANCE_MAX, _view.resonant_pending)
	_update_resonance_glow()


## Actualiza (arranca o detiene) el resplandor pulsante del círculo de Resonancia
## cuando está al 100% y pendiente de gastar.
func _update_resonance_glow() -> void:
	if _view._resonance_circle == null:
		return
	if _view.resonant_pending and not Locale.reduce_motion:
		if _view._resonance_glow_tween == null or not _view._resonance_glow_tween.is_valid():
			_view._resonance_glow_tween = _view._resonance_circle.create_tween().set_loops()
			_view._resonance_glow_tween.tween_property(_view._resonance_circle, "modulate", Color(1.6, 1.4, 0.7), 0.45).set_trans(Tween.TRANS_SINE)
			_view._resonance_glow_tween.tween_property(_view._resonance_circle, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		if _view._resonance_glow_tween != null and _view._resonance_glow_tween.is_valid():
			_view._resonance_glow_tween.kill()
			_view._resonance_glow_tween = null
		_view._resonance_circle.modulate = Color.WHITE


## Arranca el pulso rojo de aviso en la barra de HP propia (peligro ≤25%).
func _start_hp_danger_pulse() -> void:
	if _view._bar_player_hp == null or Locale.reduce_motion:
		return
	if _view._hp_danger_tween != null and _view._hp_danger_tween.is_valid():
		_view._hp_danger_tween.kill()
	_view._hp_danger_tween = _view._bar_player_hp.create_tween().set_loops()
	_view._hp_danger_tween.tween_property(_view._bar_player_hp, "modulate", Color(1.6, 0.55, 0.55), 0.45).set_trans(Tween.TRANS_SINE)
	_view._hp_danger_tween.tween_property(_view._bar_player_hp, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


## Detiene el pulso de peligro y restaura el color normal de la barra.
func _stop_hp_danger_pulse() -> void:
	if _view._hp_danger_tween != null and _view._hp_danger_tween.is_valid():
		_view._hp_danger_tween.kill()
		_view._hp_danger_tween = null
	if _view._bar_player_hp != null:
		_view._bar_player_hp.modulate = Color.WHITE


## Sincroniza la barra del ATB del jugador (fila superior),
## añadiendo una ligera animación de brillo JRPG al 100%.
func _sync_player_atb_labels() -> void:
	if _view._bar_player_atb:
		_view._bar_player_atb.value = _view.player_atb
		var is_ready := _view.player_atb >= 100.0
		if is_ready:
			if _view._atb_glow_tween == null or not _view._atb_glow_tween.is_valid():
				_view._bar_player_atb.modulate = Color.WHITE
				_view._atb_glow_tween = _view._bar_player_atb.create_tween().set_loops()
				_view._atb_glow_tween.tween_property(_view._bar_player_atb, "modulate", Color(1.8, 1.8, 1.8), 0.35).set_trans(Tween.TRANS_SINE)
				_view._atb_glow_tween.tween_property(_view._bar_player_atb, "modulate", Color(1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
		else:
			if _view._atb_glow_tween != null and _view._atb_glow_tween.is_valid():
				_view._atb_glow_tween.kill()
				_view._atb_glow_tween = null
			_view._bar_player_atb.modulate = Color.WHITE

		# Indicador breve de a quién le toca actuar, reutilizando
		# el propio título "ATB" (sin añadir nodos nuevos ni arriesgar el layout).
		if _view._lbl_atb_title != null:
			_view._lbl_atb_title.text = "ATB"
			_view._lbl_atb_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if is_ready else Color(0.98, 0.82, 0.32))

	# Actualizar labels legados solo si existen en escena (evitar errores)
	var pct := int(_view.player_atb)
	var ready_legacy := _view.player_atb >= 100.0
	var col_legacy := Color(0.95, 0.82, 0.3) if ready_legacy else Color(0.5, 0.9, 0.6)
	if _view._lbl_player_atb:
		_view._lbl_player_atb.text = "%d%%" % pct
		_view._lbl_player_atb.add_theme_color_override("font_color", col_legacy)
	if _view._lbl_atb_top:
		_view._lbl_atb_top.text = "⚡ ATB %d%%" % pct
		_view._lbl_atb_top.add_theme_color_override("font_color", col_legacy)


## Habilita/inhabilita EJECUTAR y DEFENDER según la fase del turno:
## - EJECUTAR: solo con ATB lleno, cola no vacía y sin ejecutar.
## - DEFENDER: solo mientras el enemigo descarga su ATB (su turno) y sin cooldown.
func _update_action_buttons() -> void:
	var enemy_attacking: bool = _view._enemy_is_discharging
	if _view._btn_attack:
		var can_execute := _view.is_combat_active and _view.player_atb >= 100.0 \
			and not _view.combat_queue.is_empty() and not _view._executing_queue \
			and not enemy_attacking
		_view._btn_attack.disabled = not can_execute
		_view._btn_attack.modulate = Color.WHITE if can_execute else Color(0.55, 0.55, 0.6, 0.6)
		# Pulso "jugoso" en el flanco de subida (justo al quedar disponible).
		if can_execute and not _view._atk_was_enabled and not Locale.reduce_motion:
			UiKit.pop(_view._btn_attack, 1.08, 0.24)
		_view._atk_was_enabled = can_execute

		# Animación de brillo/pulso continuo cuando se puede ejecutar
		if can_execute:
			if _view._atk_pulse_tween == null or not _view._atk_pulse_tween.is_valid():
				var p_size := _view._btn_attack.size if _view._btn_attack.size.x > 0 else Vector2(140, 120)
				_view._btn_attack.pivot_offset = p_size / 2
				_view._atk_pulse_tween = _view._btn_attack.create_tween().set_loops()
				_view._atk_pulse_tween.tween_property(_view._btn_attack, "scale", Vector2(1.03, 1.03), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				_view._atk_pulse_tween.tween_property(_view._btn_attack, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			if _view._atk_pulse_tween != null and _view._atk_pulse_tween.is_valid():
				_view._atk_pulse_tween.kill()
				_view._atk_pulse_tween = null
			_view._btn_attack.scale = Vector2(1.0, 1.0)
	if _view._btn_defense:
		var can_defend := _view.is_combat_active \
			and _view.defense_cooldown <= 0.0 and _view.defense_active_time <= 0.0
		_view._btn_defense.disabled = not can_defend
		var is_incoming := enemy_attacking and not _view._enemy_has_hit
		if is_incoming and can_defend:
			_view._btn_defense.modulate = Color(1.3, 1.25, 0.9)
			if not _view._def_was_enabled and not Locale.reduce_motion:
				UiKit.pop(_view._btn_defense, 1.12, 0.2)
		else:
			_view._btn_defense.modulate = Color.WHITE if can_defend else Color(0.5, 0.55, 0.65, 0.55)
		_view._def_was_enabled = is_incoming

	for tab_btn in _view._tab_buttons:
		if is_instance_valid(tab_btn):
			tab_btn.disabled = enemy_attacking
			tab_btn.modulate = Color(0.5, 0.5, 0.55, 0.6) if enemy_attacking else Color.WHITE
	if is_instance_valid(_view._content_grid):
		_view._content_grid.modulate = Color(0.5, 0.5, 0.55, 0.6) if enemy_attacking else Color.WHITE


func _refresh_chrome() -> void:
	_view.btn_return.text = Locale.t("combat_continue")
	if _view.btn_flee:
		_view._update_flee_button()
	if _view.btn_pause and is_instance_valid(_view.btn_pause):
		var p_icon := "▶️" if _view.is_paused else "⏸️"
		var p_txt := Locale.pick({"es": "SEGUIR", "en": "RESUME"}) if _view.is_paused else Locale.pick({"es": "PAUSA", "en": "PAUSE"})
		_view._set_jrpg_button_labels(_view.btn_pause, p_icon, p_txt)


func _on_btn_return_pressed() -> void:
	AudioManager.play_sfx("click")
	_view.result_panel.visible = false
	SceneManager.end_combat(_view._last_victory)


## 45% de posibilidades de que la huida falle (55% de éxito) con cooldown de 5s:
const FLEE_FAIL_CHANCE := 0.45

func _on_btn_flee_pressed() -> void:
	if not _view.is_combat_active:
		return
	AudioManager.play_sfx("click")

	var is_dummy: bool = bool(_view.enemy_data.get("is_training_dummy", false)) or String(_view.enemy_data.get("id", "")) == "muneco_entrenamiento"
	if not is_dummy and randf() < FLEE_FAIL_CHANCE:
		CombatFx.spawn_center_callout(_view, _view._damage_popups_node, "Parece que además de cobarde torpe,\nhas fallado la huida...", Color(1.0, 0.45, 0.3))
		_view.log_message("[color=orange]🏃 Intentas huir... ¡y fallas![/color]")
		return

	_view.is_combat_active = false
	_view._force_end_defense_effects()
	Engine.time_scale = 1.0
	_view._world_time_scale = 1.0
	_view.combat_queue.clear()
	_view._recount_queued_pa()
	_view.update_queue_ui_elements()

	if is_dummy:
		CombatFx.spawn_center_callout(_view, _view._damage_popups_node, "Has finalizado el entrenamiento.", Color(0.3, 0.85, 1.0))
		_view.log_message("[color=gold]🚪 Finalizas el entrenamiento y regresas a la base.[/color]")
	else:
		CombatFx.spawn_center_callout(_view, _view._damage_popups_node, "Has huido como un cobarde...", Color(1.0, 0.7, 0.35))

	CombatFx.play_hero_flee_animation(_view, _view._hero_sprite_rect, func():
		Engine.time_scale = 1.0
		SceneManager.end_combat(false, true)
	)
