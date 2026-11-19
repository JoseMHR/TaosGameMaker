# Revealable.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: REVELABLE  (verbo: reveal)
#
# Elemento oculto (suelo invisible, pared falsa, cofre secreto, pasadizo)
# que se hace VISIBLE con el Instinto del Explorador/Cazador. Permanece visible
# hasta salir de la mazmorra.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionRevealable
extends SkillReaction

## Segundos que permanece revelado (si <= 0, permanece visible hasta salir de la mazmorra).
@export var reveal_seconds: float = 0.0
## Si true, arranca oculto (visible = false) al iniciar la escena.
@export var start_hidden: bool = true

var _timer: SceneTreeTimer = null
var _host: Node3D = null
var _is_revealed: bool = false


func _ready() -> void:
	# El padre es el Interactable, que conoce el host (raíz del objeto).
	var inter := get_parent() as Interactable
	if inter != null:
		_host = inter.host()
	if start_hidden and _host != null:
		_host.visible = false


func apply(host: Node3D, _ctx: Dictionary) -> bool:
	_host = host
	if _is_revealed:
		return true
	_is_revealed = true
	_host.visible = true
	if reveal_seconds > 0.0:
		_timer = host.get_tree().create_timer(reveal_seconds)
		_timer.timeout.connect(_on_hide, CONNECT_ONE_SHOT)
	return true


func _on_hide() -> void:
	if not _is_revealed and start_hidden and is_instance_valid(_host):
		_host.visible = false
