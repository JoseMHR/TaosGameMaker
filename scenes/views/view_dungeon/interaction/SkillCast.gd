# SkillCast.gd
# ─────────────────────────────────────────────────────────────────────────────
# LOCALIZADOR DE OBJETIVOS PARA HABILIDADES
#
# Helper estático que las habilidades usan para encontrar `Interactable`s SIN
# conocer los objetos concretos. Ofrece dos formas de apuntado:
#   · raycast dirigido (para habilidades tipo mirada: agarre, restaurar puntual…).
#   · esfera de área (para habilidades de zona: onda, revelar, distorsión…).
#
# Siempre filtra por VERBO: solo devuelve objetos cuyo Interactable `accepts(verb)`.
# ─────────────────────────────────────────────────────────────────────────────
class_name SkillCast
extends RefCounted


## Lanza un rayo desde `from` en `dir` (normalizada) hasta `dist`. Devuelve el
## primer `Interactable` que responda a `verb`, con el punto de impacto:
##   { "interactable": Interactable, "point": Vector3, "collider": Node }
## o {} si no golpea ninguno compatible.
static func ray(world: Node3D, from: Vector3, dir: Vector3, dist: float, verb: String, exclude: Array = []) -> Dictionary:
	if world == null:
		return {}
	var space := world.get_world_3d().direct_space_state
	var end_pos := from + dir.normalized() * dist
	var params := PhysicsRayQueryParameters3D.create(from, end_pos)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var rids: Array[RID] = []
	if not exclude.is_empty():
		for e in exclude:
			if e is CollisionObject3D:
				rids.append((e as CollisionObject3D).get_rid())
	var current_excludes: Array[RID] = rids.duplicate()
	for _attempt in range(16):
		params.exclude = current_excludes
		var hit := space.intersect_ray(params)
		if hit.is_empty():
			return {}
		var col = hit.get("collider")
		var inter := Interactable.of(col)
		if inter != null:
			if inter.accepts(verb):
				return {"interactable": inter, "point": hit.get("position", from), "collider": col}
			if not (col is Area3D):
				return {}
			if col is CollisionObject3D:
				current_excludes.append((col as CollisionObject3D).get_rid())
				continue
		else:
			if col is Area3D:
				if col is CollisionObject3D:
					current_excludes.append((col as CollisionObject3D).get_rid())
					continue
			return {}
	return {}


## Lanza un rayo desde `from` en `dir` (normalizada) hasta `dist` para habilidades
## proyectadas hacia delante (Onda Cinética). Devuelve:
##   { "interactable": Interactable (o null), "point": Vector3, "hit": bool }
## donde `point` es el punto de impacto físico (objeto o pared) o `from + dir * dist`
## si recorre todo el alcance sin chocar.
static func ray_impact(world: Node3D, from: Vector3, dir: Vector3, dist: float, verb: String, exclude: Array = []) -> Dictionary:
	var end_pos := from + dir.normalized() * dist
	if world == null:
		return {"interactable": null, "point": end_pos, "hit": false}
	var space := world.get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, end_pos)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var rids: Array[RID] = []
	if not exclude.is_empty():
		for e in exclude:
			if e is CollisionObject3D:
				rids.append((e as CollisionObject3D).get_rid())
	var current_excludes: Array[RID] = rids.duplicate()
	for _attempt in range(16):
		params.exclude = current_excludes
		var hit := space.intersect_ray(params)
		if hit.is_empty():
			return {"interactable": null, "point": end_pos, "hit": false}
		var hit_point: Vector3 = hit.get("position", end_pos)
		var col = hit.get("collider")
		var inter := Interactable.of(col)
		if inter != null:
			if inter.accepts(verb):
				return {"interactable": inter, "point": hit_point, "hit": true}
			if not (col is Area3D):
				return {"interactable": null, "point": hit_point, "hit": true}
			if col is CollisionObject3D:
				current_excludes.append((col as CollisionObject3D).get_rid())
				continue
		else:
			if col is Area3D:
				if col is CollisionObject3D:
					current_excludes.append((col as CollisionObject3D).get_rid())
					continue
			return {"interactable": null, "point": hit_point, "hit": true}
	return {"interactable": null, "point": end_pos, "hit": false}



## Como `ray`, pero SIN filtrar por verbo: devuelve el primer `Interactable`
## golpeado por el rayo (o null). Lo usa la ayuda visual de apuntado, que decide
## por su cuenta si resaltar según las habilidades desbloqueadas.
static func ray_any(world: Node3D, from: Vector3, dir: Vector3, dist: float, exclude: Array = []) -> Interactable:
	if world == null:
		return null
	var space := world.get_world_3d().direct_space_state
	var end_pos := from + dir.normalized() * dist
	var params := PhysicsRayQueryParameters3D.create(from, end_pos)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var rids: Array[RID] = []
	if not exclude.is_empty():
		for e in exclude:
			if e is CollisionObject3D:
				rids.append((e as CollisionObject3D).get_rid())
	var current_excludes: Array[RID] = rids.duplicate()
	for _attempt in range(16):
		params.exclude = current_excludes
		var hit := space.intersect_ray(params)
		if hit.is_empty():
			return null
		var col = hit.get("collider")
		var inter := Interactable.of(col)
		if inter != null:
			return inter
		if col is Area3D:
			if col is CollisionObject3D:
				current_excludes.append((col as CollisionObject3D).get_rid())
				continue
		return null
	return null


## Devuelve todos los `Interactable` en una esfera de radio `radius` centrada en
## `center` que respondan a `verb`, ordenados por cercanía. Usa el grupo global
## "interactable" (barato para las cantidades típicas de una sala de mazmorra).
static func sphere(tree: SceneTree, center: Vector3, radius: float, verb: String) -> Array:
	var out: Array = []
	if tree == null:
		return out
	var r2 := radius * radius
	for node in tree.get_nodes_in_group(Interactable.GROUP):
		var inter := node as Interactable
		if inter == null or not inter.accepts(verb):
			continue
		var h := inter.host()
		if h == null:
			continue
		if h.global_position.distance_squared_to(center) <= r2:
			out.append(inter)
	out.sort_custom(func(a, b):
		return a.host().global_position.distance_squared_to(center) < b.host().global_position.distance_squared_to(center))
	return out
