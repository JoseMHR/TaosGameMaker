## WorldMeshBaker.gd
## ─────────────────────────────────────────────────────────────────────────────
## Parte PURAMENTE de datos del streaming de
## chunks del mapamundi. Sigue el mismo patrón que el resto de módulos de
## `interactive/` (WorldEnemies.gd, CampTentSystem.gd...): funciones estáticas
## que reciben `view: TabWorld3D` y operan sobre su estado, en vez de una clase
## con instancia propia.
##
## `classify_chunk_cells()` es la única función pensada para ejecutarse en un
## hilo de fondo (ver `WorldChunkStreamer.update_active_chunks`, que la lanza
## con `WorkerThreadPool.add_task()`). Para no leer `GlobalState.hexagons_db`
## concurrentemente desde el hilo de fondo mientras el hilo principal pudiera
## mutarlo, el diccionario a clasificar SIEMPRE se recibe por parámetro (`db`):
## quien lanza la tarea en segundo plano debe pasar una copia/snapshot tomada
## en el hilo principal (`GlobalState.hexagons_db.duplicate()`); las llamadas
## síncronas (arranque, rebuild) pueden pasar la referencia viva sin problema
## porque se ejecutan también en el hilo principal. Esta función no toca el
## árbol de escena, RenderingServer ni ningún campo de `view`, así que es
## segura de llamar fuera del hilo principal siempre que `db` sea una copia.
## Todo el resto de la construcción real (MultiMesh, materiales, marcadores)
## sigue viviendo en `TabWorld3D.gd` y se ejecuta siempre en el hilo principal.
class_name WorldMeshBaker
extends RefCounted


## Filtra qué casillas de `db` caen dentro de los límites `[c_min, c_max]`
## (inclusive) de un chunk. Devuelve una lista de `{coord: Vector2i, cell:
## CellResource}` lista para que el hilo principal las registre con
## `TabWorld3D._register_one_tile()` sin volver a escanear todo el diccionario
## del mundo. `db` debe ser `GlobalState.hexagons_db` (llamadas síncronas en el
## hilo principal) o una copia de él (llamadas lanzadas a `WorkerThreadPool`).
static func classify_chunk_cells(c_min: Vector2i, c_max: Vector2i, db: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for coord: Vector2i in db.keys():
		if coord.x < c_min.x or coord.x > c_max.x or coord.y < c_min.y or coord.y > c_max.y:
			continue
		out.append({"coord": coord, "cell": db[coord]})
	return out
