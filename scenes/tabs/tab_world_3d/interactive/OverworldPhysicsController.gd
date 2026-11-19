class_name OverworldPhysicsController
extends RefCounted
## CONTROLADOR DE FÍSICA Y DESLIZAMIENTO DEL MAPAMUNDI — Componente especialista
## extraído de TabWorld3D.
##
## Aísla la mecánica de superficie del HIELO RESBALADIZO (campo data-driven
## `slippery: true` en `data/world_terrains/<code>.json`):
##  - Detección al ENTRAR en una casilla y arranque de la inercia en la dirección
##    de entrada (`apply_slippery_on_enter`).
##  - Fin de la inercia al salir del bioma resbaladizo (misma función, casilla no
##    resbaladiza o inexistente) o al quedar bloqueado contra un obstáculo
##    (`maybe_stop_slide`), lo que restaura el control de inmediato.
##
## El estado (`_sliding`, `_slide_dir`) permanece en `TabWorld3D` porque el bucle
## de movimiento libre lo lee directamente; este controlador sólo gestiona las
## TRANSICIONES. El comportamiento es IDÉNTICO al monolito original.

## Vista del mapamundi propietaria del estado de deslizamiento.
var _view: Node = null

## Enlaza este controlador con la TabWorld3D propietaria. Debe llamarse una vez
## tras instanciarlo (en `TabWorld3D._ready`).
func setup(view: Node) -> void:
	_view = view

## Evalúa el deslizamiento al ENTRAR en `cell`. Si la casilla es resbaladiza,
## fuerza el deslizamiento en la dirección con la que se entró; si ya no lo es
## (o es nula), restaura el control. Reproduce el aviso flotante "¡Resbalando!".
func apply_slippery_on_enter(cell: CellResource) -> void:
	if cell != null and Design.terrain_is_slippery(cell.terrain):
		if not _view._sliding:
			_view._sliding = true
			var raw_dir: Vector2 = _view._last_move_dir
			# El hielo resbaladizo prohíbe diagonales: siempre sobre eje X o eje Y
			if absf(raw_dir.x) >= absf(raw_dir.y):
				_view._slide_dir = Vector2(signf(raw_dir.x) if not is_zero_approx(raw_dir.x) else 1.0, 0.0)
			else:
				_view._slide_dir = Vector2(0.0, signf(raw_dir.y) if not is_zero_approx(raw_dir.y) else 1.0)
			_view._spawn_world_float("🧊 ¡Resbalando!", Color(0.62, 0.82, 1.0))
	else:
		_view._sliding = false

## Detiene la inercia si el jugador, deslizándose, apenas se ha movido este frame
## (choque contra un obstáculo): restaura el control de inmediato.
func maybe_stop_slide(pos: Vector3, start_pos: Vector3, step: float) -> void:
	if _view._sliding and pos.distance_to(start_pos) < step * 0.1:
		_view._sliding = false
