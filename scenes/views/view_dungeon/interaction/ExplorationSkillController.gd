# ExplorationSkillController.gd
# ─────────────────────────────────────────────────────────────────────────────
# RUNTIME DE LAS HABILIDADES DE EXPLORACIÓN
#
# Es el puente entre los DATOS (`ExplorationSkills`) y los OBJETOS
# (`Interactable`/`SkillReaction`). Dado un id de habilidad:
#   1) valida desbloqueo, enfriamiento y energía;
#   2) construye el contexto (origen/dirección desde el nodo de apuntado);
#   3) localiza objetivos con `SkillCast` según el modo y emite el VERBO;
#   4) consume energía y arranca el enfriamiento.
#
# No conoce los objetos ni el jugador concreto: recibe un `aim_node` (Node3D cuyo
# -Z es la mirada) y opera sobre `GlobalState.energy`. Así puede engancharse tanto
# al jugador de mazmorra como al Laboratorio Debug o a un tutorial.
# ─────────────────────────────────────────────────────────────────────────────
class_name ExplorationSkillController
extends Node

## Emitida cuando una habilidad se usa con éxito.
signal skill_used(skill_id: String)
## Emitida cuando una habilidad no se pudo usar. reason: "locked" | "cooldown" |
## "energy" | "no_target".
signal skill_failed(skill_id: String, reason: String)
## Emitida al cambiar el elemento activo de la Afinidad Elemental.
signal element_changed(element: String)
## Emitida cuando cambia el objeto al que apunta el jugador. `accepted_verbs` son
## los verbos que ese objeto acepta de entre las habilidades DESBLOQUEADAS (vacío
## si no se apunta a ningún objeto interactivo). El HUD lo usa para resaltar los
## botones cuya habilidad tendría efecto sobre lo apuntado.
signal target_changed(accepted_verbs: PackedStringArray)

## Verbos que se resuelven por ÁREA (esfera). El resto son dirigidos (raycast).
const AREA_VERBS := ["timeshift", "reveal", "restore"]

## Radio HORIZONTAL (m) del alcance POR CERCANÍA de las reacciones `proximity`
## (absorber de una hoguera/agua, purificar/restaurar una casilla): cubre la casilla
## propia y sus 8 adyacentes —incluidas diagonales— con tamaño de casilla estándar
## (3 m → diagonal 4.24 m) y EXCLUYE las que están a dos casillas (6 m). Así "junto a"
## significa realmente contiguo.
const PROXIMITY_RADIUS := 5.5

## Nodo cuya orientación define el apuntado (-Z hacia delante). Lo asigna el
## jugador/escena. Si es null, se usa `origin_node`.
var aim_node: Node3D = null
## Nodo desde el que parten los efectos (mano/cámara). Si es null, usa `aim_node`.
var origin_node: Node3D = null
## Cuerpo del jugador a excluir de los raycast dirigidos.
var player_body: CollisionObject3D = null

## Elemento activo de la Afinidad Elemental. Arranca VACÍO ("" = sin elemento): se
## carga cogiéndolo de una fuente (hoguera → fuego, casilla de agua → agua…).
var current_element: String = ""

## Enfriamientos activos por id: { skill_id: segundos_restantes }.
var _cooldowns: Dictionary = {}
## Estado de las habilidades toggle (p.ej. time_distort activo).
var _toggled: Dictionary = {}
## Objeto actualmente apuntado y resaltado (ayuda visual). null si no hay ninguno.
var _aim_target: Interactable = null


func _ready() -> void:
	# Al arrancar, si hay habilidades con estado inicial activo (p.ej. Distorsión
	# Temporal si viniera precargada), se reflejaría aquí.
	pass


func _process(_delta: float) -> void:
	# Decrementar enfriamientos activos.
	for id in _cooldowns.keys():
		var left: float = float(_cooldowns[id]) - _delta
		if left <= 0.0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = left

	# Consumo continuo de energía para habilidades tipo toggle activas.
	for id in _toggled.keys():
		if not bool(_toggled[id]):
			continue
		var drain_per_sec := float(ExplorationSkills.energy_cost(id)) * 0.25
		if GlobalState.energy < drain_per_sec * _delta:
			# Sin energía suficiente para mantenerla: desactivar automáticamente.
			try_use(id)
		else:
			GlobalState.energy = maxf(0.0, GlobalState.energy - drain_per_sec * _delta)
			GlobalState.state_updated.emit()
			# Si la distorsión temporal está activa y la energía cae a 0, apagar.
			if id == "time_distort" and GlobalState.energy <= 0.0:
				try_use("time_distort")

	_update_aim_highlight()


func _exit_tree() -> void:
	# Al retirar el controlador, limpiar el resaltado del objeto apuntado.
	if _aim_target != null and is_instance_valid(_aim_target):
		_aim_target.set_highlight(false)
	_aim_target = null


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Segundos de enfriamiento restantes de una habilidad (0 si lista).
func cooldown_left(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


## ¿Está activada una habilidad tipo toggle (p.ej. Distorsión Temporal)?
func is_toggled(skill_id: String) -> bool:
	return bool(_toggled.get(skill_id, false))


## ¿Está lista para usarse (desbloqueada, sin CD y con energía)?
func is_ready(skill_id: String) -> bool:
	if not ExplorationSkills.is_unlocked(skill_id):
		return false
	if cooldown_left(skill_id) > 0.0:
		return false
	return GlobalState.energy >= float(ExplorationSkills.energy_cost(skill_id))


## Fija el elemento activo de la Afinidad Elemental.
func set_element(element: String) -> void:
	if element == current_element:
		return
	current_element = element
	element_changed.emit(element)


func set_stored_element(element: String) -> void:
	set_element(element)


## Intenta usar una habilidad por id. Devuelve true si tuvo efecto.
func try_use(skill_id: String) -> bool:
	if not ExplorationSkills.has_skill(skill_id):
		return false
	if not ExplorationSkills.is_unlocked(skill_id):
		skill_failed.emit(skill_id, "locked")
		return false
	if cooldown_left(skill_id) > 0.0:
		skill_failed.emit(skill_id, "cooldown")
		return false

	var verb := ExplorationSkills.verb(skill_id)
	var mode := ExplorationSkills.mode(skill_id)
	var reach := ExplorationSkills.range_of(skill_id)

	# Distorsión Temporal: desactivar es gratis y sin CD.
	var toggling_off := mode == ExplorationSkills.MODE_TOGGLE and bool(_toggled.get(skill_id, false))

	var cost := 0 if toggling_off else ExplorationSkills.energy_cost(skill_id)
	if GlobalState.energy < float(cost):
		skill_failed.emit(skill_id, "energy")
		return false

	var ctx := _build_ctx(skill_id, verb)
	var handled := _dispatch(skill_id, verb, mode, reach, ctx)

	# El Agarre Psíquico ("grab") y la Onda Cinética ("impact") SIEMPRE se disparan
	# (lanzan su haz/onda aunque no haya objetivo), igual que el gancho clásico; así
	# el jugador ve el efecto siempre y gasta energía al usar la habilidad.
	var always_fires := verb in AREA_VERBS or verb == "grab" or verb == "impact"
	if not handled and not always_fires:
		skill_failed.emit(skill_id, "no_target")
		return false

	if mode == ExplorationSkills.MODE_TOGGLE:
		_toggled[skill_id] = not bool(_toggled.get(skill_id, false))

	if cost > 0:
		GlobalState.energy = maxf(0.0, GlobalState.energy - float(cost))
		GlobalState.state_updated.emit()
	if not toggling_off:
		_cooldowns[skill_id] = ExplorationSkills.cooldown(skill_id)

	skill_used.emit(skill_id)
	return true


# ══════════════════════════════════════════════════════════════════════════════
# INTERNOS
# ══════════════════════════════════════════════════════════════════════════════

## Construye el contexto de la habilidad a partir del nodo de apuntado.
func _build_ctx(skill_id: String, verb: String) -> Dictionary:
	var aim := aim_node if aim_node != null else origin_node
	var src := origin_node if origin_node != null else aim_node
	var origin := src.global_position if src != null else Vector3.ZERO
	var dir := -aim.global_transform.basis.z if aim != null else Vector3.FORWARD
	var ctx := {
		"origin": origin,
		"direction": dir.normalized(),
		"source": _skill_source(),
		"strength": 1.0,
	}
	if verb == "element":
		ctx["element"] = current_element
	var extra := ExplorationSkills.get_skill(skill_id)
	if extra.has("duration"):
		ctx["duration"] = float(extra["duration"])
	return ctx


## La "fuente" que ven las reacciones (p.ej. Anchor pide `pull_self_to`). Es el
## cuerpo del jugador si expone la API, si no el propio nodo de apuntado.
func _skill_source() -> Node:
	if player_body != null:
		return player_body
	return aim_node


## Localiza objetivos y emite el verbo. Devuelve true si algún objeto reaccionó.
func _dispatch(_skill_id: String, verb: String, _mode: String, reach: float, ctx: Dictionary) -> bool:
	var handled := false
	var origin: Vector3 = ctx.get("origin", Vector3.ZERO)
	var dir: Vector3 = ctx.get("direction", Vector3.FORWARD)
	if verb in AREA_VERBS:
		for inter in SkillCast.sphere(get_tree(), origin, reach, verb):
			if (inter as Interactable).react(verb, ctx):
				handled = true
	elif verb == "impact":
		var exclude := [player_body] if player_body != null else []
		var hit_res := SkillCast.ray_impact(_world(), origin, dir, reach, verb, exclude)
		var target := hit_res.get("interactable") as Interactable
		if target != null:
			var ctx2 := ctx.duplicate()
			ctx2["point"] = hit_res.get("point", origin + dir * reach)
			handled = target.react(verb, ctx2)
	else:
		var exclude := [player_body] if player_body != null else []
		for _aim_try in range(4):
			var hit := SkillCast.ray(_world(), origin, dir, reach, verb, exclude)
			if hit.is_empty():
				break
			var target := hit["interactable"] as Interactable
			# Si el jugador lleva un elemento en la mano (p.ej. agua, fuego), puede proyectarlo
			# hacia cualquier objetivo que apunte directamente dentro del alcance (reach).
			# Si tiene las manos vacías y el objeto es de cercanía (recoger fuego/agua),
			# se requiere contigüidad (_is_adjacent).
			var is_casting_element := verb == "element" and String(ctx.get("element", "")) != ""
			if not target.has_proximity() or is_casting_element or _is_adjacent(origin, target):
				var ctx2 := ctx.duplicate()
				ctx2["point"] = hit.get("point", origin)
				if target.react(verb, ctx2):
					handled = true
					break
			# Si el objetivo alcanzado por el raycast no reaccionó (p.ej. la casilla bajo los pies
			# que ya contiene el mismo elemento), excluimos sus colisionadores y relanzamos el raycast
			# en la misma dirección para alcanzar el elemento al que realmente está apuntando la mira.
			var hit_col = hit.get("collider")
			if hit_col is CollisionObject3D and not exclude.has(hit_col):
				exclude.append(hit_col)
			var h := target.host()
			if h != null:
				for c in h.find_children("*", "CollisionObject3D"):
					if c is CollisionObject3D and not exclude.has(c):
						exclude.append(c)
		# Fase de CERCANÍA: activa el objeto `proximity` compatible dentro de las casillas
		# adyacentes (casilla venenosa/agua a tus pies, lava/hoguera/puente contiguos),
		# aunque no lo estés apuntando con precisión de cirujano.
		if not handled:
			handled = _proximity_fallback(verb, origin, ctx)
	return handled


## ¿Está `target` a una casilla o menos del origen? Mide en HORIZONTAL (plano de la
## rejilla), ignorando la altura de la cámara, para que "junto a" sea fiel a la
## rejilla independientemente de dónde mire el jugador.
func _is_adjacent(origin: Vector3, target: Interactable) -> bool:
	var h := target.host()
	if h == null:
		return false
	var d := Vector2(h.global_position.x - origin.x, h.global_position.z - origin.z)
	return d.length() <= PROXIMITY_RADIUS


## Activa el objeto `proximity` compatible dentro de `PROXIMITY_RADIUS`.
## Para `restore` (purificación) limpia TODAS las casillas adyacentes.
## Para el resto, prueba candidatos ordenados de menor a mayor distancia hasta
## que uno reaccione con éxito (evita que un pozo contiguo bloquee apagar lava contigua).
func _proximity_fallback(verb: String, origin: Vector3, ctx: Dictionary) -> bool:
	var radius_sq := PROXIMITY_RADIUS * PROXIMITY_RADIUS
	if verb == "restore":
		var handled := false
		for node in get_tree().get_nodes_in_group(Interactable.GROUP):
			var i := node as Interactable
			if i == null or not i.accepts(verb) or not i.has_proximity():
				continue
			var h := i.host()
			if h == null:
				continue
			var d := Vector2(h.global_position.x - origin.x, h.global_position.z - origin.z).length_squared()
			if d <= radius_sq:
				if i.react(verb, ctx):
					handled = true
		return handled

	var candidates: Array = []
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var i := node as Interactable
		if i == null or not i.accepts(verb) or not i.has_proximity():
			continue
		var h := i.host()
		if h == null:
			continue
		var d := Vector2(h.global_position.x - origin.x, h.global_position.z - origin.z).length_squared()
		if d <= radius_sq:
			candidates.append({"inter": i, "dist": d})

	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])

	for cand in candidates:
		var target := cand["inter"] as Interactable
		if target.react(verb, ctx):
			return true

	return false


## Nodo 3D del mundo para los raycast (usa el nodo de apuntado como referencia).
func _world() -> Node3D:
	if aim_node != null:
		return aim_node
	if origin_node != null:
		return origin_node
	return null


# ══════════════════════════════════════════════════════════════════════════════
# AYUDA VISUAL: RESALTADO DEL OBJETO APUNTADO
# ══════════════════════════════════════════════════════════════════════════════

var _last_emitted_verbs: PackedStringArray = PackedStringArray()


## Cada frame: localiza el objeto interactivo bajo la mirada (y objetos en alcance / proximidad)
## y resalta sus botones en el HUD.
func _update_aim_highlight() -> void:
	var target := _acquire_aim_target()
	if target != _aim_target:
		if _aim_target != null and is_instance_valid(_aim_target):
			_aim_target.set_highlight(false)
		_aim_target = target
		if _aim_target != null:
			_aim_target.set_highlight(true)

	var verbs := PackedStringArray()
	if _aim_target != null:
		verbs = _accepted_unlocked_verbs(_aim_target)

	# FASE DE ALCANCE Y VISIÓN ESTRICTA:
	# Un objeto solo activa el resaltado si:
	# 1. Está en el mismo piso (diferencia de altura |Y| < 1.2).
	# 2. Está delante del jugador (producto escalar > 0.1 o contiguo).
	# 3. Está dentro del alcance de la habilidad.
	# 4. Existe línea de visión libre (sin pared bloqueando el trayecto).
	var aim := origin_node if origin_node != null else aim_node
	if aim != null:
		var origin := aim.global_position
		var forward := -aim.global_transform.basis.z
		for node in get_tree().get_nodes_in_group(Interactable.GROUP):
			var inter := node as Interactable
			if inter == null:
				continue
			var h: Node3D = inter.host()
			var pos: Vector3 = h.global_position if h != null else inter.global_position

			# 1. Comprobar que esté en el mismo piso (diferencia de altura |Y| < 2.2 para cubrir suelo a techo)
			if absf(pos.y - origin.y) > 2.2:
				continue

			var to_target := pos - origin
			var dist := to_target.length()
			var to_target_dir := to_target.normalized() if dist > 0.001 else forward

			# 2. Comprobar que esté delante del jugador (o a los pies)
			if dist > 0.8 and forward.dot(to_target_dir) < 0.1:
				continue

			# 4. Comprobar línea de visión
			if dist > 0.8 and not _has_line_of_sight(origin, pos, h if h != null else inter):
				continue

			for id in ExplorationSkills.unlocked_ids():
				var v := ExplorationSkills.verb(id)
				if v == "" or verbs.has(v):
					continue
				var reach := ExplorationSkills.range_of(id)
				var max_d := maxf(reach, PROXIMITY_RADIUS)
				if dist <= max_d and inter.accepts(v):
					verbs.append(v)

	if verbs != _last_emitted_verbs:
		_last_emitted_verbs = verbs.duplicate()
		target_changed.emit(verbs)


## Comprueba si existe línea de visión sin paredes bloqueantes entre from y to.
func _has_line_of_sight(from: Vector3, to: Vector3, target_host: Node) -> bool:
	var w := _world()
	if w == null or not w.is_inside_tree():
		return true
	var space := w.get_world_3d().direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var exclude: Array = [player_body] if player_body != null else []
	if target_host != null:
		exclude.append(target_host)
	q.exclude = exclude
	var res: Dictionary = space.intersect_ray(q)
	if res.is_empty():
		return true
	var collider = res.get("collider", null)
	if collider == null or collider == target_host or (target_host != null and target_host.is_ancestor_of(collider)):
		return true
	return false


## Raycast desde el origen en la dirección de la mirada hasta el mayor alcance de
## las habilidades desbloqueadas. Devuelve el `Interactable` golpeado si acepta
## algún verbo desbloqueado, o null.
func _acquire_aim_target() -> Interactable:
	var world := _world()
	if world == null:
		return null
	var aim := aim_node if aim_node != null else origin_node
	var src := origin_node if origin_node != null else aim_node
	if aim == null or src == null:
		return null
	var reach := _max_unlocked_range()
	if reach <= 0.0:
		return null
	var origin := src.global_position
	var dir := -aim.global_transform.basis.z
	var exclude := [player_body] if player_body != null else []
	var fallback_feet_target: Interactable = null
	for _try in range(3):
		var hit := SkillCast.ray_any(world, origin, dir.normalized(), reach, exclude)
		if hit == null:
			break
		var h := hit.host()
		if h != null and fallback_feet_target == null:
			var d_sq := Vector2(h.global_position.x - origin.x, h.global_position.z - origin.z).length_squared()
			if d_sq < 1.44:
				fallback_feet_target = hit
				for c in h.find_children("*", "CollisionObject3D"):
					if c is CollisionObject3D and not exclude.has(c):
						exclude.append(c)
				continue
		if not _accepted_unlocked_verbs(hit).is_empty():
			return hit
	if fallback_feet_target != null and not _accepted_unlocked_verbs(fallback_feet_target).is_empty():
		return fallback_feet_target
	return null


## Verbos que `inter` acepta de entre las habilidades desbloqueadas (sin repetir).
func _accepted_unlocked_verbs(inter: Interactable) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ExplorationSkills.unlocked_ids():
		var v := ExplorationSkills.verb(id)
		if v == "" or out.has(v):
			continue
		if inter.accepts(v):
			out.append(v)
	return out


## Mayor alcance entre las habilidades desbloqueadas (14.5 m por defecto).
func _max_unlocked_range() -> float:
	var best := 0.0
	for id in ExplorationSkills.unlocked_ids():
		best = maxf(best, ExplorationSkills.range_of(id))
	return best if best > 0.0 else 14.5
