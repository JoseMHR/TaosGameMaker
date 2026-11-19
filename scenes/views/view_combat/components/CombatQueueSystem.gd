class_name CombatQueueSystem
extends RefCounted
## EVALUADOR DE SINERGIAS Y COLA — Componente especialista extraído de ViewCombat.
##
## Encapsula la resolución de la COLA de habilidades del turno:
##  - Capacidad máxima de ranuras (`get_max_queue_slots`): 2 por defecto y 3 en
##    Sintonía MÁXIMA (100%), para permitir combos dobles y triples.
##  - Fusión data-driven de sinergias (`check_and_fuse_synergies`) consultando
##    `Design.get_synergy` / `Design.get_triple_synergy` (data/synergies.json),
##    sin lógica hardcodeada por nombre. Genera la estructura del combo resultante
##    dentro de la propia cola.
##
## Mantiene referencia a la `ViewCombat` propietaria (`_view`) sobre cuyo estado
## (combat_queue, player_resonance, banderas de Resonancia) opera. `ViewCombat`
## conserva fachadas con las mismas firmas. El comportamiento es IDÉNTICO al
## monolito original.

## Vista de combate propietaria del estado de la cola.
var _view: ViewCombat = null

## Enlaza este sistema con la ViewCombat propietaria. Debe llamarse una vez tras
## instanciarlo (en `ViewCombat._ready`).
func setup(view: ViewCombat) -> void:
	_view = view

## Nº de ranuras de cola disponibles este turno: 1 ranura base
## para "Don Nadie" (profesión sin sinergias registradas), 2 para el resto de
## profesiones, y +1 ranura extra en Sintonía MÁXIMA (100%) → 2 y 3 respectivamente.
func get_max_queue_slots() -> int:
	var base_cap: int = 1 if GlobalState.profession == "Don Nadie" else 2
	if _view.is_resonant_turn or _view.resonant_pending or _view.player_resonance >= 100.0:
		base_cap += 1
	return base_cap

## Fusiona pares (y triples con Sintonía MÁX) de la cola cuyos IDs formen una
## sinergia definida en data/synergies.json. Sin lógica hardcodeada por nombre.
func check_and_fuse_synergies() -> void:
	var combat_queue: Array = _view.combat_queue
	# Caso 3 slots (Sintonía MÁX): buscar triple sinergia primero
	if combat_queue.size() >= 3 and _view.player_resonance >= 100.0:
		var id1 := String(combat_queue[0].get("id", ""))
		var id2 := String(combat_queue[1].get("id", ""))
		var id3 := String(combat_queue[2].get("id", ""))
		var triple: Dictionary = Design.get_triple_synergy(String(GlobalState.profession), id1, id2, id3)
		if not triple.is_empty():
			var n1: String = _view._skill_name(combat_queue[0])
			var n2: String = _view._skill_name(combat_queue[1])
			var n3: String = _view._skill_name(combat_queue[2])
			var fused: Dictionary = triple.duplicate(true)
			fused["pa"] = int(combat_queue[0].get("pa", 1)) + int(combat_queue[1].get("pa", 1)) + int(combat_queue[2].get("pa", 1))
			fused["is_synergy"] = true
			combat_queue.clear()
			combat_queue.append(fused)
			# Reset de Sintonía al usar la sinergia suprema
			_view.player_resonance = 0.0
			_view.is_resonance_active = false
			_view.resonant_pending = false
			_view.is_resonant_turn = false
			_view._update_player_bars()
			# Banner gigante + hitstop
			CombatFx.spawn_word(_view, _view._damage_popups_node, "¡SINERGIA SUPREMA ACTIVADA!", ViewCombat.COL_GOLD, _view._lbl_synergy_chain, "⭐")
			Juice.hit_stop(0.12)
			_view.log_message("[color=gold]⭐ ¡SINERGIA SUPREMA! [b]%s[/b] + [b]%s[/b] + [b]%s[/b] → [b]%s[/b][/color]" % [n1, n2, n3, _view._skill_name(fused)])
			_view._animate_synergy_fusion(0)
			_view._recount_queued_pa()
			return

	# Caso 2 slots: fusionar pares contiguos
	var i := 0
	while i < combat_queue.size() - 1:
		var id1 := String(combat_queue[i].get("id", ""))
		var id2 := String(combat_queue[i + 1].get("id", ""))
		var fusion: Dictionary = Design.get_synergy(GlobalState.profession, id1, id2)
		if not fusion.is_empty():
			var n1: String = _view._skill_name(combat_queue[i])
			var n2: String = _view._skill_name(combat_queue[i + 1])
			var fused: Dictionary = fusion.duplicate(true)
			# Preservar el PA TOTAL ya gastado (suma de los dos slots originales).
			# NO usar el PA del JSON de sinergias, que puede ser menor.
			fused["pa"] = int(combat_queue[i].get("pa", 1)) + int(combat_queue[i + 1].get("pa", 1))
			combat_queue.remove_at(i + 1)
			combat_queue[i] = fused
			_view.log_message("[color=gold]🌟 ¡SINERGIA! %s + %s → [b]%s[/b].[/color]" % [n1, n2, _view._skill_name(fused)])
			_view._animate_synergy_fusion(i)
			i = 0
		else:
			i += 1
	_view._recount_queued_pa()
