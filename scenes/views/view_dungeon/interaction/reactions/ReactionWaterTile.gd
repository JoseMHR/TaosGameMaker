# ReactionWaterTile.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: CASILLA DE AGUA Y AGUA PROFUNDA (verbo: element)
#
# Interacción con la Afinidad Elemental:
#   · Estado AGUA:
#       - Manos vacías ("")  → COGE agua ("agua").
#       - Con hielo ("hielo") → Se CONGELA en casilla de hielo resbaladiza
#                               (DungeonIceZone.gd). Se consume el hielo.
#                               Si es agua profunda, activa losa sólida para
#                               poder caminar/deslizar sobre el abismo.
#   · Estado HIELO:
#       - Manos vacías ("")  → COGE hielo ("hielo").
#       - Con fuego ("fuego") → Se DERRITE volviendo a ser casilla de agua.
#                               Se consume el fuego.
#                               Si es agua profunda, desactiva la losa sólida
#                               (si alguien pisa cae al vacío).
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionWaterTile
extends SkillReaction

## True si es agua profunda (sin losa de suelo cuando es agua; se cae al vacío).
@export var is_deep: bool = false
## True si empieza congelada en estado hielo.
@export var frozen: bool = false
## Nodo visual de la lámina de agua.
@export var water_node: NodePath
## Nodo visual del hielo resbaladizo.
@export var ice_node: NodePath
## Área de agua ralentizante (DungeonWaterZone.gd).
@export var water_hazard_node: NodePath
## Área de hielo resbaladizo (DungeonIceZone.gd).
@export var ice_hazard_node: NodePath
## Colisión sólida de hielo (activada al congelar para agua profunda).
@export var ice_collision_node: NodePath
## Evento global opcional al cambiar de estado.
@export var activate_event: String = ""


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if not enabled:
		return false
	var source = ctx.get("source", null)
	if source == null or not (source is Node) or not (source as Node).has_method("set_stored_element"):
		return false

	var holding := String(ctx.get("element", ""))
	if holding == "":
		var full := String(ctx.get("verb", ""))
		var idx := full.find(":")
		if idx >= 0:
			holding = full.substr(idx + 1)

	if not frozen:
		# --- ESTADO AGUA ---
		if holding == "hielo":
			# Congelar en casilla de hielo
			set_frozen(host, true)
			(source as Node).call("set_stored_element", "")
			if activate_event != "":
				GlobalEvents.emit_event(activate_event, {
					"element": "hielo",
					"state": "frozen",
					"position": host.global_position
				})
			return true
		elif holding == "agua":
			# Ya se lleva agua: el agua no interactúa con agua ni se vuelve a coger
			return false
		else:
			# Coger agua con manos vacías o sustituyendo el elemento previo (fuego, etc.)
			(source as Node).call("set_stored_element", "agua")
			return true
	else:
		# --- ESTADO HIELO ---
		if holding == "fuego":
			# Derretir volviendo a casilla de agua
			set_frozen(host, false)
			(source as Node).call("set_stored_element", "")
			if activate_event != "":
				GlobalEvents.emit_event(activate_event, {
					"element": "fuego",
					"state": "water",
					"position": host.global_position
				})
			return true
		elif holding == "hielo":
			# Ya se lleva hielo: el hielo no interactúa con hielo ni se vuelve a coger
			return false
		else:
			# Coger hielo con manos vacías o sustituyendo el elemento previo (agua, etc.)
			(source as Node).call("set_stored_element", "hielo")
			return true


## Cambia entre estado agua y estado hielo actualizando visuales, áreas y colisiones.
func set_frozen(host: Node3D, freeze: bool) -> void:
	frozen = freeze

	var w_vis := host.get_node_or_null(water_node) as Node3D
	if w_vis != null:
		w_vis.visible = not freeze

	var i_vis := host.get_node_or_null(ice_node) as Node3D
	if i_vis != null:
		i_vis.visible = freeze

	# Gestión de área de agua (ralentiza)
	var w_area := host.get_node_or_null(water_hazard_node) as Area3D
	if w_area != null:
		if freeze:
			if w_area.monitoring:
				for b in w_area.get_overlapping_bodies():
					if b.has_method("set_in_water"):
						b.set_in_water(false)
			w_area.monitoring = false
			w_area.monitorable = false
		else:
			w_area.monitoring = true
			w_area.monitorable = true

	# Gestión de área de hielo (resbaladiza)
	var i_area := host.get_node_or_null(ice_hazard_node) as Area3D
	if i_area != null:
		if not freeze:
			if i_area.monitoring:
				for b in i_area.get_overlapping_bodies():
					if b.has_method("set_on_ice"):
						b.set_on_ice(false)
			i_area.monitoring = false
			i_area.monitorable = false
		else:
			i_area.monitoring = true
			i_area.monitorable = true

	# Colisión sólida de hielo para agua profunda
	var i_col := host.get_node_or_null(ice_collision_node) as CollisionShape3D
	if i_col != null:
		if is_deep:
			i_col.disabled = not freeze
		else:
			i_col.disabled = not freeze
