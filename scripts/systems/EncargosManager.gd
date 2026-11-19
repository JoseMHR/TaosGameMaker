class_name EncargosManager
extends RefCounted
## GESTOR DE ENCARGOS (TABLÓN) — Módulo especialista extraído de GlobalState.
##
## Centraliza la lógica de aceptar/progresar/reclamar encargos repetibles del
## tablón, y los "report_*" que otros sistemas (combate, recolección, visitas a
## NPCs) usan para avanzar su progreso. Los DATOS (`active_encargos`,
## `encargo_progress`, `kills_total`) siguen viviendo en `GlobalState`; este
## manager sólo aloja la LÓGICA y opera sobre esos datos a través de una
## referencia al `GlobalState` propietario (`_state`).
##
## `GlobalState` mantiene wrappers-fachada con las mismas firmas públicas
## (`is_encargo_active`, `encargo_count`, `can_accept_encargo`, `accept_encargo`,
## `is_encargo_done`, `claim_encargo`, `report_gather`, `report_kill`,
## `report_visit`) que redirigen a este manager, de modo que ningún llamante
## externo cambia.

## Referencia al autoload GlobalState propietario de los datos.
var _state: Node = null

## Enlaza este manager con el GlobalState propietario. Debe llamarse una única vez
## durante la inicialización del autoload (`GlobalState._ready`).
func setup(state: Node) -> void:
	_state = state


# ══════════════════════════════════════════════════════════════════════════════
# GENERADOR DE ENCARGOS PARAMÉTRICOS (idea.md §2.1)
# ══════════════════════════════════════════════════════════════════════════════
const BOUNTY_TEMPLATES_PATH := "res://data/templates/bounties_templates.json"
static var _bounty_templates: Dictionary = {}
static var _bounty_templates_loaded: bool = false

## Carga (una única vez, cacheada) el catálogo de plantillas de encargo.
static func _load_bounty_templates() -> Dictionary:
	if _bounty_templates_loaded:
		return _bounty_templates
	_bounty_templates_loaded = true
	if FileAccess.file_exists(BOUNTY_TEMPLATES_PATH):
		var f := FileAccess.open(BOUNTY_TEMPLATES_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_bounty_templates = parsed
	return _bounty_templates

## Genera un encargo PARAMÉTRICO nuevo a partir de las plantillas de
## `data/templates/bounties_templates.json`: elige un tipo al azar (y, para
## "gather", un recurso al azar de `possible_targets`), escala cantidad y
## recompensa con el nivel del jugador, y lo añade al catálogo dinámico
## `GameConfig.GENERATED_ENCARGOS` para que el tablón (`ViewEncargos.gd`) lo
## liste como cualquier otro. Devuelve el id del nuevo encargo (listo para
## `accept_encargo`), o "" si no hay plantillas disponibles.
##
## `avoid_signatures` es una lista de firmas "type|target" (ver
## `_encargo_signature`) que YA existen en el tablón de esa ciudad (disponibles
## o activas): se reintenta varias veces para no generar un encargo idéntico a
## uno ya existente (bug reportado: "avisos duplicados" en el tablón). Si tras
## los reintentos no se encuentra una combinación libre, no se genera nada
## (mejor tener menos avisos que uno repetido).
func generate_encargo(city_id: String, level: int = -1, avoid_signatures: Array = []) -> String:
	var templates := _load_bounty_templates()
	if templates.is_empty():
		return ""
	var types := templates.keys()
	var lvl: int = level if level > 0 else int(_state.level)

	var enc_type := ""
	var tpl: Dictionary = {}
	var target := "any"
	var target_name := ""
	const MAX_ATTEMPTS := 20
	var attempts := 0
	while true:
		enc_type = String(types[randi() % types.size()])
		tpl = templates[enc_type]
		target = "any"
		target_name = ""
		var possible: Array = tpl.get("possible_targets", [])
		if enc_type == "gather" and not possible.is_empty():
			target = String(possible[randi() % possible.size()])
			target_name = Design.get_item_name(target)
		attempts += 1
		if not avoid_signatures.has(_encargo_signature(enc_type, target)):
			break
		if attempts >= MAX_ATTEMPTS:
			return ""

	var amount_base: float = float(tpl.get("amount_base", 5.0))
	var amount_per_level: float = float(tpl.get("amount_per_level", 0.3))
	var amount: int = maxi(1, int(round(amount_base + amount_per_level * lvl)))

	var reward_gold: int = maxi(5, int(round(amount * float(tpl.get("reward_gold_factor", 2.0)))))
	var reward_xp: int = maxi(5, int(round(amount * float(tpl.get("reward_xp_factor", 1.5)))))

	GameConfig.GENERATED_ENCARGO_SEQ += 1
	var id := "gen_%s_%d" % [enc_type, GameConfig.GENERATED_ENCARGO_SEQ]

	var fmt := {"amount": amount, "target_name": target_name}
	var title: Dictionary = (tpl.get("title", {}) as Dictionary).duplicate(true)
	var desc: Dictionary = (tpl.get("desc", {}) as Dictionary).duplicate(true)
	for k in title.keys():
		title[k] = String(title[k]).format(fmt)
	for k in desc.keys():
		desc[k] = String(desc[k]).format(fmt)

	GameConfig.GENERATED_ENCARGOS.append({
		"id": id, "city": city_id, "type": enc_type, "target": target, "amount": amount,
		"icon": String(tpl.get("icon", "📋")),
		"reward_gold": reward_gold, "reward_xp": reward_xp,
		"title_text": title, "desc_text": desc,
	})
	return id

## Firma "type|target" de un encargo: identifica su combinación de objetivo,
## usada para detectar duplicados (dos encargos con la misma firma se leen y
## juegan exactamente igual, aunque tengan ids distintos).
func _encargo_signature(type: String, target: String) -> String:
	return "%s|%s" % [type, target]

## Garantiza que la ciudad `city_id` tenga al menos `min_available` encargos
## DISPONIBLES (no aceptados) en su tablón, generando nuevos con
## `generate_encargo()` si hacen falta. Se invoca al abrir el tablón físico de
## la ciudad (`ViewEncargos.setup`), así el volumen de contenido secundario
## crece solo con jugar sin necesidad de redactarlo todo a mano.
##
## Evita generar avisos DUPLICADOS: recopila las firmas (type|target) de TODOS
## los encargos ya existentes de la ciudad (disponibles o activos, manuales o
## generados) y se las pasa a `generate_encargo` para que no repita ninguna.
func ensure_encargos_for_city(city_id: String, min_available: int = 2) -> void:
	if city_id == "":
		return
	var available := 0
	var existing_signatures: Array = []
	for e in GameConfig.all_encargos():
		if String(e.get("city", "")) != city_id:
			continue
		existing_signatures.append(_encargo_signature(String(e.get("type", "")), String(e.get("target", "any"))))
		if not is_encargo_active(String(e["id"])):
			available += 1
	while available < min_available:
		var new_id := generate_encargo(city_id, -1, existing_signatures)
		if new_id == "":
			break
		var new_e: Dictionary = GameConfig.get_encargo(new_id)
		existing_signatures.append(_encargo_signature(String(new_e.get("type", "")), String(new_e.get("target", "any"))))
		available += 1


func is_encargo_active(id: String) -> bool:
	return bool(_state.active_encargos.get(id, false))

func encargo_count(id: String) -> int:
	return int(_state.encargo_progress.get(id, 0))

func can_accept_encargo() -> bool:
	return _state.active_encargos.size() < GameConfig.ENCARGO_MAX_ACTIVE

func accept_encargo(id: String) -> bool:
	if is_encargo_active(id) or not can_accept_encargo():
		return false
	if GameConfig.get_encargo(id).is_empty():
		return false
	_state.active_encargos[id] = true
	if not _state.encargo_progress.has(id):
		_state.encargo_progress[id] = 0
	_state.state_updated.emit()
	return true

func is_encargo_done(id: String) -> bool:
	var e: Dictionary = GameConfig.get_encargo(id)
	if e.is_empty() or not is_encargo_active(id):
		return false
	return encargo_count(id) >= int(e["amount"])

func claim_encargo(id: String) -> bool:
	if not is_encargo_done(id):
		return false
	var e: Dictionary = GameConfig.get_encargo(id)
	_state.gold += int(e.get("reward_gold", 0))
	_state.encargo_progress[id] = 0   # repetible: reinicia el progreso, sigue activo
	_state.add_xp(encargo_effective_xp(e))   # add_xp ya emite state_updated
	_state.state_updated.emit()
	return true

## XP EFECTIVA que otorga un encargo (al reclamarlo o al mostrarlo en la UI):
## nunca menos que `GameConfig.ENCARGO_MIN_XP_PCT` de la XP que el héroe necesita
## para su PRÓXIMO nivel base, para que los encargos no se queden obsoletos en
## recompensa a medida que se sube de nivel. Se usa tanto para conceder XP
## (`claim_encargo`) como para mostrarla (`ViewEncargos`), así el número de la
## tarjeta es siempre el real que se va a recibir.
func encargo_effective_xp(e: Dictionary) -> int:
	var base_xp: int = int(e.get("reward_xp", 0))
	var min_xp: int = int(GameConfig.ENCARGO_MIN_XP_PCT * float(GameConfig.xp_needed_for_char_level(_state.level + 1)))
	return maxi(base_xp, min_xp)

## Avanza el progreso de los encargos activos que coincidan con (type, target).
func _progress_encargos(type: String, target: String, amount: int) -> void:
	var changed: bool = false
	for id in _state.active_encargos.keys():
		var e: Dictionary = GameConfig.get_encargo(id)
		if e.is_empty() or e["type"] != type:
			continue
		if String(e["target"]) != "any" and String(e["target"]) != target:
			continue
		var cap: int = int(e["amount"])
		var cur: int = int(_state.encargo_progress.get(id, 0))
		if cur < cap:
			_state.encargo_progress[id] = mini(cap, cur + amount)
			changed = true
	if changed:
		_state.state_updated.emit()

## Reporta recolección de un recurso (encargos gather).
func report_gather(res_id: String, amount: int) -> void:
	_progress_encargos("gather", res_id, amount)

## Reporta una victoria en combate (contador + encargos kill).
func report_kill() -> void:
	_state.kills_total += 1
	_progress_encargos("kill", "any", 1)

## Reporta la entrada en un edificio/NPC (memoria + encargos visit).
func report_visit(npc_id: String) -> void:
	_state.mark_npc_visited(npc_id)
	_progress_encargos("visit", "any", 1)
