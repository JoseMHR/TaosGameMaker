## WorldChunkStreamer.gd
## ─────────────────────────────────────────────────────────────────────────────
## Gestiona el streaming de chunks 3D del
## mapamundi (3×3 chunks de 32×32 casillas alrededor del jugador). Mismo patrón
## que el resto de módulos de `interactive/` (WorldEnemies.gd, CampTentSystem.gd):
## funciones que reciben `view: Node` y operan sobre su estado.
##
## Ciclo de vida de un chunk:
##  1. `update_active_chunks()` calcula el conjunto deseado (3×3 alrededor del
##     chunk del jugador). Los chunks que quedan fuera se descargan de
##     inmediato (`view._unload_chunk()`, barato: solo `queue_free()` + limpieza
##     de diccionarios).
##  2. Para cada chunk NUEVO que entra en el conjunto, se lanza una tarea en
##     `WorkerThreadPool` que llama a `WorldMeshBaker.classify_chunk_cells()`
##     (solo lectura de `GlobalState.hexagons_db`, sin tocar el árbol de escena).
##  3. `poll_pending()` (llamado cada frame desde `TabWorld3D._process`)
##     comprueba qué tareas han terminado y, en el HILO PRINCIPAL, termina de
##     construir ese chunk (`view._finalize_chunk_from_classified()`): aquí sí
##     se crean MultiMesh/nodos, que no son seguros desde un hilo secundario.
##
## El primer build (arranque del mundo) se hace síncrono vía `initialize()`
## para no complicar el primer frame con tareas en vuelo.
##
## IMPORTANTE: ni `update_active_chunks()`
## ni `poll_pending()` deben BLOQUEAR nunca el hilo principal esperando a un
## worker en marcha. `WorkerThreadPool.wait_for_task_completion()` sólo se
## invoca cuando `is_task_completed()` ya ha devuelto `true` (join inmediato,
## sin espera real) — únicamente para liberar los recursos internos de la
## tarea. Los chunks que dejan de interesar mientras su tarea sigue en vuelo
## no se cancelan a la fuerza: se marcan en `_cancelled` y su resultado se
## descarta sin construir nada cuando por fin termine.
class_name WorldChunkStreamer
extends RefCounted

const CHUNK_SIZE: int = 32
## Radio en chunks alrededor del jugador que se mantiene cargado: 1 (ventana 3×3 = 96×96 casillas = 144×144m).
## Cubre sobradamente el campo de visión de la cámara cenital tanto en PC como en móvil
## manteniendo 60 FPS estables sin tirones de streaming.
static var ACTIVE_RADIUS: int = 1

var _center: Vector2i = Vector2i(999999, 999999)   # fuerza el primer cálculo real
var _pending_tasks: Dictionary = {}      # chunk_coord(Vector2i) -> task_id(int)
var _pending_results: Dictionary = {}    # chunk_coord(Vector2i) -> Array[Dictionary] (relleno por el hilo de fondo)
var _results_mutex := Mutex.new()        # protege _pending_results (se escribe desde WorkerThreadPool)
var _cancelled: Dictionary = {}          # chunk_coord(Vector2i) -> true; tareas en vuelo cuyo resultado ya no interesa


## Coordenada de chunk (32×32) a la que pertenece una casilla del mundo.
static func chunk_coord_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(CHUNK_SIZE)), floori(float(cell.y) / float(CHUNK_SIZE)))


## Construye SÍNCRONAMENTE los chunks iniciales (arranque del mundo/teleport
## completo). Sin WorkerThreadPool: es un único frame de carga, igual que antes.
func initialize(view: Node, player_cell: Vector2i) -> void:
	_center = chunk_coord_of(player_cell)
	for c in _desired_chunks(_center):
		_build_one_sync(view, c)


## Recalcula el conjunto de chunks activos (3×3) alrededor de la casilla actual
## del jugador. Sin cambios si sigue en el mismo chunk que la última vez.
func update_active_chunks(view: Node, player_cell: Vector2i) -> void:
	var new_center: Vector2i = chunk_coord_of(player_cell)
	if new_center == _center and not view._chunk_roots.is_empty():
		return
	_center = new_center
	var desired: Array[Vector2i] = _desired_chunks(_center)
	var desired_set: Dictionary = {}
	for c in desired:
		desired_set[c] = true

	# Descargar los chunks que ya no tocan (barato: queue_free + limpieza).
	for existing in view._chunk_roots.keys().duplicate():
		if not desired_set.has(existing):
			view._unload_chunk(existing)

	# Descartar (sin bloquear) las tareas en vuelo de chunks que ya no
	# interesan: se dejan terminar en segundo plano con normalidad y
	# `poll_pending()` descartará su resultado en cuanto acaben (ver `_cancelled`).
	for pending in _pending_tasks.keys().duplicate():
		if not desired_set.has(pending):
			_cancelled[pending] = true

	# Pedir en segundo plano los que faltan. Solo extraemos las casillas del CHUNK
	# (32x32 = 1024 casillas) en vez de duplicar los 50.000 elementos de hexagons_db.
	for c in desired:
		if view._chunk_roots.has(c) or _pending_tasks.has(c):
			continue
		var bounds := _chunk_bounds(view, c)
		var c_min: Vector2i = bounds[0]
		var c_max: Vector2i = bounds[1]
		if c_min.x > c_max.x or c_min.y > c_max.y:
			continue   # totalmente fuera del rectángulo jugable (todo mar), nada que construir

		var chunk_snapshot: Dictionary = {}
		for cy in range(c_min.y - 1, c_max.y + 2):
			for cx in range(c_min.x - 1, c_max.x + 2):
				var coord := Vector2i(cx, cy)
				var cell = GlobalState.hexagons_db.get(coord, null)
				if cell != null:
					chunk_snapshot[coord] = cell

		var mutex := _results_mutex
		var results := _pending_results
		var task_id := WorkerThreadPool.add_task(func() -> void:
			var cells := WorldMeshBaker.classify_chunk_cells(c_min, c_max, chunk_snapshot)
			mutex.lock()
			results[c] = cells
			mutex.unlock()
		)
		_pending_tasks[c] = task_id


## Debe llamarse cada frame (ver `TabWorld3D._process`). Termina en el hilo
## principal cualquier chunk cuya clasificación en segundo plano ya esté lista.
## Nunca bloquea: solo actúa sobre tareas para las que `is_task_completed()`
## ya devuelve `true`.
func poll_pending(view: Node) -> void:
	if _pending_tasks.is_empty():
		return
	for c in _pending_tasks.keys().duplicate():
		var task_id: int = _pending_tasks[c]
		if not WorkerThreadPool.is_task_completed(task_id):
			continue
		WorkerThreadPool.wait_for_task_completion(task_id)   # join inmediato: ya está completada
		_pending_tasks.erase(c)
		_results_mutex.lock()
		var cells: Array = _pending_results.get(c, [])
		_pending_results.erase(c)
		_results_mutex.unlock()
		if _cancelled.has(c):
			_cancelled.erase(c)
			continue   # el chunk dejó de interesar mientras se clasificaba: descartar
		if not view._chunk_roots.has(c):
			view._finalize_chunk_from_classified(c, cells)
			break   # Finalizar como máximo 1 chunk por frame para mantener 60 FPS estables sin tirones


## Fuerza la reconstrucción de TODOS los chunks actualmente activos (usado tras
## una modificación física del mundo — herramientas de terreno — donde antes se
## llamaba a `_rebuild_tiles()` a secas). Síncrono, igual que `initialize()`.
func rebuild_active_chunks(view: Node) -> void:
	var active: Array = view._chunk_roots.keys().duplicate()
	for c in active:
		view._unload_chunk(c)
	for c in active:
		_build_one_sync(view, c)


func _build_one_sync(view: Node, c: Vector2i) -> void:
	var bounds: Array = _chunk_bounds(view, c)
	var c_min: Vector2i = bounds[0]
	var c_max: Vector2i = bounds[1]
	if c_min.x > c_max.x or c_min.y > c_max.y:
		return
	var cells: Array = WorldMeshBaker.classify_chunk_cells(c_min, c_max, GlobalState.hexagons_db)
	view._finalize_chunk_from_classified(c, cells)


func _desired_chunks(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			out.append(center + Vector2i(dx, dy))
	return out


## Límites [c_min, c_max] (inclusive, en coordenadas de casilla) de un chunk,
## recortados al rectángulo jugable (`view.build_min`/`build_max`).
func _chunk_bounds(view: Node, c: Vector2i) -> Array:
	var c_min := Vector2i(c.x * CHUNK_SIZE, c.y * CHUNK_SIZE)
	var c_max := Vector2i(c_min.x + CHUNK_SIZE - 1, c_min.y + CHUNK_SIZE - 1)
	c_min.x = maxi(c_min.x, view.build_min.x)
	c_min.y = maxi(c_min.y, view.build_min.y)
	c_max.x = mini(c_max.x, view.build_max.x)
	c_max.y = mini(c_max.y, view.build_max.y)
	return [c_min, c_max]
