# TimeMotion.gd
# ─────────────────────────────────────────────────────────────────────────────
# ANIMADOR DE OBJETO AFECTADO POR EL TIEMPO
#
# Nodo autónomo que mueve/gira un `target` (plataforma, cuchilla, molino, pinchos,
# puerta temporizada…) y multiplica su velocidad por el `time_factor` de una
# `ReactionTimeAffected` hermana. Así la Distorsión Temporal ralentiza el objeto
# sin que la escena contenedora tenga que animarlo. Es data-driven: la pieza de
# kit configura `kind`, `axis`, `amplitude` y `speed`.
# ─────────────────────────────────────────────────────────────────────────────
class_name TimeMotion
extends Node3D

## Tipo de movimiento: spin (giro continuo), slide (vaivén), bob (sube/baja),
## gate (puerta que baja y sube abriendo el paso), shuttle (vaivén de 0 a
## +amplitude y vuelta, sin bajar nunca de la posición base — plataforma
## lanzadera que siempre AVANZA desde donde se coloca, nunca retrocede detrás
## de su origen).
@export var kind: String = "spin"
## Eje afectado ("x", "y", "z").
@export var axis: String = "y"
## Amplitud del vaivén/desplazamiento (m). No aplica a "spin".
@export var amplitude: float = 2.0
## Velocidad base (rad/s para spin, ciclos/s para el resto).
@export var speed: float = 2.0
## Nodo que se anima. Si es null, se anima este mismo nodo.
@export var target_path: NodePath
## Reacción de tiempo cuya `time_factor` modula la velocidad. Si null, va a 1.0.
var time_reaction: ReactionTimeAffected = null

var _target: Node3D = null
var _base_pos: Vector3 = Vector3.ZERO
var _t: float = 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D if not target_path.is_empty() else self
	if _target != null:
		_base_pos = _target.position


func _process(delta: float) -> void:
	if _target == null:
		return
	var factor := 1.0
	if time_reaction != null and is_instance_valid(time_reaction):
		factor = time_reaction.time_factor
	var step := delta * factor
	match kind:
		"spin":
			_spin(step)
		"slide":
			_t += step * speed
			_offset(sin(_t) * amplitude)
		"bob":
			_t += step * speed
			_offset(absf(sin(_t)) * amplitude)
		"gate":
			_t += step * speed
			# 0 = cerrada (arriba), amplitude = abierta (hundida).
			_offset(-(0.5 - 0.5 * cos(_t)) * amplitude)
		"shuttle":
			_t += step * speed
			# 0 = posición base (origen), amplitude = extremo del recorrido.
			# A diferencia de "slide" (que oscila entre -amplitude y +amplitude),
			# esto nunca cruza por debajo de la base: siempre AVANZA desde el
			# origen hacia +amplitude y vuelve, en bucle.
			_offset((0.5 - 0.5 * cos(_t)) * amplitude)
		_:
			_spin(step)


func _spin(step: float) -> void:
	var ang := step * speed
	match axis:
		"x": _target.rotate_x(ang)
		"z": _target.rotate_z(ang)
		_: _target.rotate_y(ang)


func _offset(v: float) -> void:
	match axis:
		"x": _target.position = _base_pos + Vector3(v, 0, 0)
		"z": _target.position = _base_pos + Vector3(0, 0, v)
		_: _target.position = _base_pos + Vector3(0, v, 0)
