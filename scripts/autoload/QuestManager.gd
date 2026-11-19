# QuestManager.gd
# Autoload Singleton que centraliza toda la lógica de misiones y gating.
# Coordina el flujo de eventos entre el mapa, el inventario y los diálogos.
extends Node

# ─── CONSTANTES DE ESTADO DE MISIÓN ─────────────────────────────────────────
const QS_NOT_STARTED       := "not_started"
const QS_EXPLORER_MISSING  := "explorer_missing"
const QS_ITEM_FOUND        := "item_found"
const QS_BANANA_OBTAINED   := "banana_obtained"
const QS_MONKEY_CLEARED    := "monkey_cleared"

# ─── QUESTLINE DE LA PRESA (valle de yelmo inicial) ──────────────────────────
const QS_KNOWS_DAM      := "knows_dam"        # Casita 1 te ha contado lo de la presa
const QS_DAM_NEEDS_WOOD := "dam_needs_wood"   # Casita 2 te pide 5 de madera
const QS_HAS_STONE      := "has_stone"         # Tienes la piedra para la palanca
const QS_DAM_OPENED     := "dam_opened"        # Has reabierto la presa

## Orden monotónico de la questline principal: set_quest_forward nunca retrocede.
const QUEST_ORDER: Array = [
	QS_NOT_STARTED, QS_KNOWS_DAM, QS_DAM_NEEDS_WOOD, QS_HAS_STONE, QS_DAM_OPENED,
]

## Emitida cuando la presa se reabre (el mundo debe transformarse/reconstruirse).
signal dam_opened

# ─── SEÑALES ─────────────────────────────────────────────────────────────────
## Emitida cuando una casilla del mapa debe actualizarse visualmente.
signal map_cell_changed(coord: Vector2i)
## Emitida cuando se debe iniciar un combate.
signal combat_triggered(enemy_data: Dictionary)


# ══════════════════════════════════════════════════════════════════════════════
# PUNTO DE ENTRADA: El jugador acaba de entrar en una casilla
# Llamado por TabWorld3D al entrar en una casilla
# ══════════════════════════════════════════════════════════════════════════════
func on_cell_entered(_coord: Vector2i, cell: CellResource) -> void:
	if cell != null:
		if cell.trigger_quest_state != "":
			set_quest_forward(cell.trigger_quest_state)
		if cell.trigger_event != "":
			handle_choice(cell.trigger_event)

	if OrbBarksManager != null:
		OrbBarksManager.check_overworld_milestones()


# ══════════════════════════════════════════════════════════════════════════════
# QUESTLINE PRINCIPAL (avance monotónico y apertura de la presa)
# ══════════════════════════════════════════════════════════════════════════════
## Comprueba si la questline principal ha alcanzado o superado `required_state`.
func is_quest_at_least(required_state: String) -> bool:
	if required_state == "" or required_state == QS_NOT_STARTED:
		return true
	var order: Array = Design.quest_order()
	if order.is_empty():
		order = QUEST_ORDER
	var ci: int = order.find(GlobalState.quest_state)
	var ni: int = order.find(required_state)
	if ni == -1:
		return GlobalState.quest_state == required_state
	if ci == -1:
		return false
	return ci >= ni


## Fija el estado de misión SOLO si avanza (según el orden); nunca retrocede.
## Los estados fuera del orden (cadena legado del diario) se fijan directos.
## DATA-DRIVEN: el orden se lee de quests.json (`Design.quest_order()`); si ese
## fichero no existe, se usa la constante cableada QUEST_ORDER como fallback.
## Si el jugador se salta pasos, sincroniza automáticamente las transformaciones
## de mundo previas correspondientes a los hitos alcanzados.
func set_quest_forward(state: String) -> void:
	var order: Array = Design.quest_order()
	if order.is_empty():
		order = QUEST_ORDER
	var ci: int = order.find(GlobalState.quest_state)
	var ni: int = order.find(state)
	if ci == -1 or ni == -1 or ni > ci:
		GlobalState.quest_state = state
		GlobalState.state_updated.emit()
		_catch_up_milestones(state, order)


## Sincroniza transformaciones de mundo si se avanza o salta directamente a un hito posterior.
func _catch_up_milestones(new_state: String, order: Array) -> void:
	var ni: int = order.find(new_state)
	if ni == -1:
		return
	
	# Hito Presa: si hemos alcanzado o superado dam_opened, garantiza la transformación
	var dam_idx: int = order.find(QS_DAM_OPENED)
	if dam_idx != -1 and ni >= dam_idx and not GlobalState.dam_opened:
		GlobalState.dam_opened = true
		WorldMapBuilder.apply_transform("dam_opened")
		dam_opened.emit()
	
	# Hito Cueva del Yelmo: si se supera el túnel, asegura el paso despejado
	var yelmo_idx: int = order.find("yelmo_tunnel_cleared")
	if yelmo_idx != -1 and ni >= yelmo_idx and not GlobalState.cave_cleared:
		GlobalState.cave_cleared = true
		run_world_transform("cave_cleared")
	
	# Hito Puente del Mono: si se supera el mono, asegura el puente transitable
	var monkey_idx: int = order.find(QS_MONKEY_CLEARED)
	if monkey_idx != -1 and ni >= monkey_idx:
		run_world_transform("monkey_cleared")


## Reabre la presa: marca los flags, transforma los datos del valle (yelmo →
## río/pradera/tierra) y avisa para que el mundo 3D se reconstruya.
func open_dam() -> void:
	GlobalState.dam_opened = true
	# Bandera GLOBAL de historia (además del bool dedicado): la leen el logro
	# "Aguas Libres" (gflag "dam_opened") y la selección de música ambiental
	# (WorldEnvironmentController). Sin esto la condición nunca se cumplía.
	GlobalState.set_world_flag("dam_opened")
	set_quest_forward(QS_DAM_OPENED)
	WorldMapBuilder.apply_transform("dam_opened")
	GlobalState.state_updated.emit()
	dam_opened.emit()
	AudioManager.play_music("world")


func _show_animal_disclaimer() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	UiKit.show_ephemeral_modal(
		tree.root,
		"🕊️  AVISO",
		"En este juego no se ha dañado a ningún animal",
		"(La gaviota solo estaba un poco desorientada y ya vuela feliz)",
		3.0,
		UiKit.ACCENT
	)


# ══════════════════════════════════════════════════════════════════════════════
# PROCESAR DECISIÓN DEL JUGADOR
# Invocado por el token `qaction:<action>` de una opción de escena (SceneRunner).
# ══════════════════════════════════════════════════════════════════════════════
func handle_choice(action: String) -> void:
	# DATA-FIRST: si events.json define este id, se ejecuta su lista de acciones
	# (mini-lenguaje) y terminamos. Solo si NO existe caemos al flujo cableado.
	if Design.has_event(action):
		Design.run_event(action)
		return

	match action:

		"accept_quest":
			GlobalState.quest_state = QS_EXPLORER_MISSING
			GlobalState.state_updated.emit()

		"start_cave_combat":
			# Lanzar combate contra el Boss de la cueva (definido en EnemyDatabase)
			combat_triggered.emit(EnemyDatabase.build_enemy("sombra_oscura", 1, true))

		"receive_banana":
			# El Noble quita la reliquia y entrega el plátano
			GlobalState.remove_item("diario", 1)
			GlobalState.add_item("banana", 1)
			GlobalState.quest_state = QS_BANANA_OBTAINED
			GlobalState.state_updated.emit()

		"give_banana":
			# El jugador da la banana al mono (lo invoca PlaceDatabase vía quest_action).
			GlobalState.remove_item("banana", 1)
			GlobalState.quest_state = QS_MONKEY_CLEARED
			_unlock_monkey_bridge()
			GlobalState.state_updated.emit()

		"dismiss":
			pass  # No hace nada — el diálogo se cierra solo


# ══════════════════════════════════════════════════════════════════════════════
# VICTORIA EN COMBATE (llamado externamente por ViewCombat / Main)
# ══════════════════════════════════════════════════════════════════════════════
func on_combat_victory(enemy_id: String, cell_coord: Vector2i = Vector2i(-1, -1)) -> void:
	# ENEMIGO DEL MAPAMUNDI: si la victoria trae la coord del punto de
	# aparición, lo marcamos como derrotado (respawn opcional). El actor se retira
	# al volver al mundo (TabWorld3D._refresh_enemies).
	if cell_coord != Vector2i(-1, -1):
		var r_secs: int = 120
		if GlobalState.hexagons_db.has(cell_coord):
			var oc: CellResource = GlobalState.hexagons_db[cell_coord] as CellResource
			if oc != null and oc.enemy is Dictionary and not oc.enemy.is_empty():
				var r_val = oc.enemy.get("respawn", true)
				var r_enabled := bool(r_val) if r_val is bool else (int(r_val) > 0)
				r_secs = int(oc.enemy.get("respawn_time", 120)) if r_enabled else 0
		GlobalState.defeat_overworld_enemy(cell_coord, r_secs)

	# DATA-FIRST: si quests.json define un hook de victoria para este enemigo,
	# ejecutamos su evento y terminamos. Si no, usamos el flujo cableado.
	var hook := Design.quest_combat_event(enemy_id)
	if hook != "":
		Design.run_event(hook)
		return

	match enemy_id:
		"sombra_oscura", "cave_boss":
			if not GlobalState.has_item("diario"):
				GlobalState.add_item(
					"diario", 1,
					"Diario Personal", "important", "📖"
				)
				if GlobalState.quest_state == QS_EXPLORER_MISSING:
					GlobalState.quest_state = QS_ITEM_FOUND
				GlobalState.state_updated.emit()
				# Mostrar diálogo de descubrimiento (UNIFICADO: vía SceneRunner).
				request_dialogue({
					"npc_name":   "Descubrimiento",
					"npc_avatar": "📖",
					"text": "¡Has derrotado al boss de la cueva! Entre sus pertenencias encuentras el Diario Personal perdido.",
					"choices": [
						{"text": "✅  ¡Excelente!", "action": "dismiss"},
					]
				})
		"dungeon_boss":
			# Boss genérico: la recompensa (XP/oro/botín) la concede ViewCombat.
			pass


# ══════════════════════════════════════════════════════════════════════════════
# DESBLOQUEAR EL PUENTE DEL MONO
# Actualiza la CellResource en hexagons_db y notifica al mapa
# ══════════════════════════════════════════════════════════════════════════════
func _unlock_monkey_bridge() -> void:
	for coord in WorldMapBuilder.apply_transform("monkey_cleared"):
		map_cell_changed.emit(coord)


# ══════════════════════════════════════════════════════════════════════════════
# API DATA-DRIVEN: la invoca Design._apply_token desde events.json
# ══════════════════════════════════════════════════════════════════════════════

## Lanza un combate contra `enemy_id` (nivel `level`, jefe si `boss`). Lo usa el
## token de evento `combat:enemy_id[:level[:boss]]`.
func trigger_combat(enemy_id: String, level: int = 1, boss: bool = false) -> void:
	combat_triggered.emit(EnemyDatabase.build_enemy(enemy_id, level, boss))


## Muestra un diálogo. Lo usa el token `dialogue:id`. Si el diálogo está vacío no
## hace nada. UNIFICADO: se ejecuta como una ESCENA en el SceneRunner
## (adaptando el diálogo legado), de modo que toda la narrativa usa un solo motor.
func request_dialogue(data: Dictionary) -> void:
	if data.is_empty():
		return
	SceneRunner.start_built_scene("dialogue", SceneAdapters.dialogue_to_scene(data))


## Muestra un diálogo por su id (dialogues.json) o, preferentemente, una escena
## del Sistema Narrativo con ese mismo id (scenes.json) si existe. Lo usa el token
## `dialogue:id`. Migración progresiva: basta con crear la escena para sustituir
## el diálogo legado sin tocar el resto del contenido.
func request_dialogue_id(dialogue_id: String) -> void:
	if Design.has_scene(dialogue_id):
		SceneRunner.start_scene(dialogue_id)
		return
	request_dialogue(Design.get_dialogue(dialogue_id))


## Reproduce una cinemática por su id. Lo usa el token `cine:id`. La cinemática
## es una ESCENA normal (scenes.json) ejecutada en el SceneRunner: sus nodos
## "event" pueden emitir EVENT_CINE_CAMERA para mover la cámara del mundo, que
## reacciona a él, respetando el desacople de sistemas.
func play_cinematic(cine_id: String) -> void:
	if Design.has_scene(cine_id):
		SceneRunner.start_scene(cine_id)
		return
	push_warning("QuestManager: cinemática/escena '%s' no encontrada en data/scenes/ ni data/cinematics/." % cine_id)


## Aplica una transformación del mundo por nombre (token `worldt:nombre`). Encapsula
## los efectos de historia (flags + mutación de celdas + señales) que antes estaban
## repartidos en métodos cableados, para poder dispararlos desde datos.
func run_world_transform(transform_name: String) -> void:
	match transform_name:
		"dam_opened":
			open_dam()
		"cave_cleared":
			GlobalState.cave_cleared = true
			# Emitir map_cell_changed por cada casilla afectada para que el mundo 3D
			# reconstruya su marcador (igual que monkey_cleared); si no, el cambio de
			# datos no se reflejaría visualmente (seguiría viéndose la cueva vieja).
			for coord in WorldMapBuilder.apply_transform("cave_cleared"):
				map_cell_changed.emit(coord)
			GlobalState.state_updated.emit()
		"monkey_cleared":
			_unlock_monkey_bridge()
			GlobalState.state_updated.emit()
		_:
			# Genérico DATA-FIRST: cualquier transformación nueva declarada en
			# world_transforms.json con `rules` (sin rutina cableada propia) se
			# aplica directamente vía WorldMapBuilder.apply_transform, igual que
			# los 3 casos de arriba, sin necesitar un nuevo caso de código por
			# cada transformación (p. ej. Acto 3: tumbas que desaparecen,
			# reinterpretación de localizaciones ya visitadas).
			var def := Design.get_world_transform(transform_name)
			if def.is_empty():
				push_warning("QuestManager: transformación de mundo desconocida '%s'" % transform_name)
				return
			for coord in WorldMapBuilder.apply_transform(transform_name):
				map_cell_changed.emit(coord)
			GlobalState.state_updated.emit()
			# Task 5 (4.2, `trigger_cinematic`): campo opcional a nivel de
			# transformación (no de regla, ya que no pertenece a una celda
			# concreta) que reproduce una cinemática tras aplicar las reglas.
			var cine_id := String(def.get("cinematic", ""))
			if not cine_id.is_empty():
				play_cinematic(cine_id)


## ══════════════════════════════════════════════════════════════════════════════
## SISTEMA MULTI-QUEST (misiones secundarias/paralelas)
## Independiente de `quest_state` (historia principal, lineal). Los datos viven
## en `GlobalState.quests` (quest_id -> {stage, state, custom_data}); ver
## task_arreglos.md §1. Pensado para escalar a muchas misiones secundarias
## activas a la vez sin pisarse entre sí, a diferencia de `quest_state`.
## ══════════════════════════════════════════════════════════════════════════════

## Inicia una misión secundaria en `initial_stage` (por defecto 0). No hace
## nada si ya estaba iniciada (activa o completada) — devuelve false en ese caso.
func start_quest(quest_id: String, initial_stage: int = 0) -> bool:
	if GlobalState.quests.has(quest_id):
		return false
	GlobalState.quests[quest_id] = {
		"stage": initial_stage,
		"state": "active",
		"custom_data": {},
	}
	GlobalState.state_updated.emit()
	return true

## Cambia la fase de una misión secundaria YA iniciada. No hace nada si no
## existe (usar `start_quest` primero). `state_tag` es opcional (etiqueta legible).
func set_quest_stage(quest_id: String, stage: int, state_tag: String = "") -> void:
	if not GlobalState.quests.has(quest_id):
		return
	GlobalState.quests[quest_id]["stage"] = stage
	if state_tag != "":
		GlobalState.quests[quest_id]["state"] = state_tag
	GlobalState.state_updated.emit()

## Marca una misión secundaria como completada (`stage = -1`).
func complete_quest(quest_id: String) -> void:
	if not GlobalState.quests.has(quest_id):
		return
	GlobalState.quests[quest_id]["stage"] = -1
	GlobalState.quests[quest_id]["state"] = "completed"
	GlobalState.state_updated.emit()

## Marca una misión secundaria como fallida (`stage = -2`).
func fail_quest(quest_id: String) -> void:
	if not GlobalState.quests.has(quest_id):
		return
	GlobalState.quests[quest_id]["stage"] = -2
	GlobalState.quests[quest_id]["state"] = "failed"
	GlobalState.state_updated.emit()

## ¿La misión secundaria está iniciada y en curso (stage >= 0)?
func is_quest_active(quest_id: String) -> bool:
	return GlobalState.quests.has(quest_id) and int(GlobalState.quests[quest_id].get("stage", 0)) >= 0

## ¿La misión secundaria fue completada?
func is_quest_completed(quest_id: String) -> bool:
	return GlobalState.quests.has(quest_id) and int(GlobalState.quests[quest_id].get("stage", 0)) == -1

## ¿La misión secundaria fue fallida?
func is_quest_failed(quest_id: String) -> bool:
	return GlobalState.quests.has(quest_id) and int(GlobalState.quests[quest_id].get("stage", 0)) == -2

## Fase actual de la misión secundaria, o -999 si nunca se inició.
func get_quest_stage(quest_id: String) -> int:
	return int(GlobalState.quests.get(quest_id, {}).get("stage", -999))


## Devuelve la información y pista de la misión activa actual (según GlobalState.quest_state y Design.quest_desc).
func get_active_quest() -> Dictionary:
	var st: String = GlobalState.quest_state
	var info: Dictionary = Design.quest_desc(st)
	if info.is_empty():
		return {
			"id": st,
			"hint": {"es": "Explora las tierras hacia el Puerto de Celestia.", "en": "Explore the lands towards Celestia Port.", "fr": "Explore les terres en direction du Port de Celestia.", "it": "Esplora le terre verso il Porto di Celestia.", "de": "Erkunde das Land in Richtung Celestia-Hafen.", "zh": "探索通往赛勒斯提亚港口的土地。", "ja": "セレスティア港へ向かう土地を探索しよう。"}
		}
	var res := info.duplicate(true)
	res["id"] = st
	return res
