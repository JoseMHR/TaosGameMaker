# Interactable.gd
# ─────────────────────────────────────────────────────────────────────────────
# COMPONENTE DE OBJETO INTELIGENTE
#
# Se añade como hijo de cualquier objeto de mazmorra (la raíz suele ser un
# RigidBody3D / StaticBody3D). Agrupa las reacciones (`SkillReaction`) hijas y
# expone un contrato mínimo que las habilidades usan SIN conocer el objeto:
#
#   accepts(verb)        -> ¿alguna reacción responde a este verbo?
#   react(verb, ctx)     -> ejecuta las reacciones que casan; true si se gestionó.
#   set_highlight(on)    -> ayuda visual al apuntar con una habilidad compatible.
#
# El objeto se registra en el grupo "interactable" para que las habilidades lo
# localicen por área/raycast.
# ─────────────────────────────────────────────────────────────────────────────
class_name Interactable
extends Node

const GROUP := "interactable"

## Raíz física/visual del objeto. Si se deja vacío, se usa el nodo padre.
@export var host_path: NodePath

## Color del resaltado al apuntar con una habilidad compatible.
@export var highlight_color: Color = Color(1.0, 0.92, 0.45)

## Intensidad de la emisión del resaltado.
@export var highlight_energy: float = 0.6

var _host: Node3D
var _reactions: Array[SkillReaction] = []
var _highlighted: bool = false
## mesh -> material original (para restaurar al quitar el resaltado).
var _mesh_backup: Dictionary = {}


func _ready() -> void:
	if _host == null:
		_host = get_node_or_null(host_path) as Node3D if not host_path.is_empty() else get_parent() as Node3D
	_collect_reactions()
	add_to_group(GROUP)


## Recolecta las reacciones hijas (permite reordenarlas/activarlas en el editor).
func _collect_reactions() -> void:
	_reactions.clear()
	for child in get_children():
		if child is SkillReaction:
			_reactions.append(child)


## Nodo raíz del objeto (host) que manipulan las reacciones.
func host() -> Node3D:
	return _host


func set_host(node: Node3D) -> void:
	_host = node


## ¿Alguna reacción responde a este verbo?
func accepts(verb: String) -> bool:
	for r in _reactions:
		if r.matches(verb):
			return true
	return false


## ¿Alguna reacción activa admite activación POR CERCANÍA? Lo usa el controller
## para permitir que un verbo dirigido (restore/element) actúe sobre objetos a los
## que el jugador no apunta exactamente pero tiene al lado (casilla venenosa/agua,
## hoguera contigua).
func has_proximity() -> bool:
	for r in _reactions:
		if r.enabled and r.proximity:
			return true
	return false


## Ejecuta todas las reacciones que casan con el verbo. Devuelve true si alguna
## gestionó el efecto.
func react(verb: String, ctx: Dictionary) -> bool:
	if _host == null:
		return false
	var handled := false
	var full_ctx := ctx.duplicate()
	full_ctx["verb"] = verb
	for r in _reactions:
		if r.matches(verb):
			if r.apply(_host, full_ctx):
				handled = true
				break
	return handled


## Activa/desactiva el resaltado visual sobre las mallas del objeto.
func set_highlight(on: bool) -> void:
	if on == _highlighted or _host == null:
		return
	_highlighted = on
	if on:
		_apply_highlight()
	else:
		_clear_highlight()


func _apply_highlight() -> void:
	for mi in _iter_meshes(_host):
		if not _mesh_backup.has(mi):
			_mesh_backup[mi] = mi.material_overlay
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = highlight_color
		mat.emission_energy_multiplier = highlight_energy
		mi.material_overlay = mat


func _clear_highlight() -> void:
	for mi in _mesh_backup.keys():
		if is_instance_valid(mi):
			mi.material_overlay = _mesh_backup[mi]
	_mesh_backup.clear()


## Devuelve todas las MeshInstance3D del subárbol del host.
func _iter_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_iter_meshes(child))
	return out


# ── Localización estática (para las habilidades) ─────────────────────────────

## Devuelve el `Interactable` asociado a un nodo (él mismo, un hijo o un
## ascendiente cercano), o null. Permite que una habilidad, tras un raycast que
## golpea el cuerpo físico, obtenga su componente inteligente.
static func of(node: Node) -> Interactable:
	if node == null:
		return null
	var n := node
	# Buscar hacia arriba (el cuerpo físico suele ser el padre del Interactable
	# o el propio host cuyo hijo es el Interactable).
	for child in n.get_children():
		if child is Interactable:
			return child
	var parent := n.get_parent()
	while parent != null:
		for child in parent.get_children():
			if child is Interactable:
				return child
		if parent is Interactable:
			return parent
		parent = parent.get_parent()
	return null
