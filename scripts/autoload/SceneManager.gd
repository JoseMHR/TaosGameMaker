# SceneManager.gd
# Autoload Singleton — Gestiona la navegación entre vistas sin destruir escenas.
# Todas las escenas del juego emiten señales a través de SceneManager
# y GameRoot escucha para mostrar/ocultar vistas.
extends Node

# ─── SEÑALES ─────────────────────────────────────────────────────────────────

## Emitida para navegar a una vista concreta con datos opcionales.
signal navigate_to(view_name: String, data: Dictionary)

## Emitida para notificar un cambio de vista interna (para refresco de widgets).
signal view_changed(view_name: String)

## Emitida para cambiar el tab activo de la barra de navegación.
signal tab_switched(tab_name: String)

## Emitida cuando el combate comienza (para que GameRoot muestre CombatView).
signal combat_started(enemy_data: Dictionary)

## Emitida cuando el combate termina. `fled`: true si el jugador huyó en vez
## de ganar/perder.
signal combat_ended(victory: bool, fled: bool)


var current_view_name: String = "splash"
var current_tab_name: String = "none"
var in_combat: bool = false


func _ready() -> void:
	navigate_to.connect(func(v_name: String, _data: Dictionary) -> void:
		if v_name != "city_back":
			current_view_name = v_name
			view_changed.emit(v_name)
	)
	tab_switched.connect(func(t_name: String) -> void:
		current_tab_name = t_name
		view_changed.emit(current_view_name)
	)
	combat_started.connect(func(_data: Dictionary) -> void:
		in_combat = true
		view_changed.emit("combat")
	)
	combat_ended.connect(func(_victory: bool, _fled: bool = false) -> void:
		in_combat = false
		view_changed.emit(current_view_name)
	)


## Comprueba si la Esfera de la Verdad debe estar visible (solo en mapamundi o mazmorra activa con partida en curso).
func is_orb_allowed() -> bool:
	if in_combat:
		return false
	var root_scene: Node = get_tree().current_scene if get_tree() != null else null
	if root_scene == null:
		return false
	var rname: String = root_scene.name
	if rname == "MainMenu" or rname.begins_with("MainMenu") or rname == "SplashScreen" or rname.begins_with("Splash"):
		return false
	if SaveManager != null and not SaveManager.active:
		if rname == "GameRoot" or rname == "ViewDungeon":
			SaveManager.active = true
		else:
			return false
	if current_view_name == "menu" or current_view_name == "splash" or current_view_name == "orb_room" or current_view_name == "prologue" or current_view_name == "cinematic":
		return false
	return (current_view_name == "world" or current_view_name == "dungeon") and (current_tab_name == "world" or current_tab_name == "none")


# ══════════════════════════════════════════════════════════════════════════════
# NAVEGACIÓN A VISTAS
# ══════════════════════════════════════════════════════════════════════════════

## Ir a la pantalla cinemática de Splash.
func go_to_splash() -> void:
	current_view_name = "splash"
	current_tab_name = "none"
	if SaveManager != null:
		SaveManager.active = false
	navigate_to.emit("splash", {})
	view_changed.emit("splash")


## Ir al Menú Principal.
func go_to_menu() -> void:
	current_view_name = "menu"
	current_tab_name = "none"
	if SaveManager != null:
		SaveManager.active = false
	navigate_to.emit("menu", {})
	view_changed.emit("menu")


## Ir al mapamundi. Punto único de retorno usado por CUALQUIER vista (mazmorra,
## POI, ciudad, edificio, cocina...): forzar aquí el desbloqueo incondicional
## de movimiento sirve de red de seguridad para que, si algún flujo concreto
## olvida limpiar `GlobalState.is_movement_locked` al salir, el personaje nunca
## quede inmóvil en el mapamundi.
func go_to_world() -> void:
	current_view_name = "world"
	current_tab_name = "world"
	GlobalState.is_movement_locked = false
	Engine.time_scale = 1.0
	if SaveManager != null:
		SaveManager.active = true
		SaveManager.save_game()
	navigate_to.emit("world", {})


## Entrar en la Sala de la Esfera con un contexto de diálogo ("welcome" | "death").
func go_to_orb_room(context: String) -> void:
	current_view_name = "orb_room"
	navigate_to.emit("orb_room", {"context": context})


## Entrar en un Lugar / POI (desde el mapa).
func go_to_place(cell_data: Dictionary) -> void:
	current_view_name = "place"
	navigate_to.emit("place", cell_data)


## Entrar en una ciudad (desde el mapa).
## Recibe la CellResource de la casilla actual para saber qué ciudad es.
func go_to_city(cell_data: Dictionary) -> void:
	current_view_name = "city"
	navigate_to.emit("city", cell_data)


## Entrar en un edificio-NPC de una ciudad. data_or_npc = Dictionary con metadatos o clave String.
func go_to_building(data_or_npc) -> void:
	current_view_name = "building"
	if data_or_npc is Dictionary:
		navigate_to.emit("building", data_or_npc)
	else:
		navigate_to.emit("building", {"key": String(data_or_npc)})


## Regresar de un edificio a la vista de ciudad.
func back_to_city() -> void:
	current_view_name = "city"
	navigate_to.emit("city_back", {})


## Entrar en una mazmorra (desde el mapa).
func go_to_dungeon(cell_data: Dictionary) -> void:
	if SaveManager != null:
		if SaveManager.active and current_view_name != "dungeon":
			SaveManager.save_game()
		SaveManager.active = true
	current_view_name = "dungeon"
	current_tab_name = "world"
	navigate_to.emit("dungeon", cell_data)


## Ir a la vista de Cocina.
func go_to_cook(data: Dictionary = {}) -> void:
	current_view_name = "cook"
	navigate_to.emit("cook", data)


## Ir a la vista de Herrería / Forja.
func go_to_forge(data: Dictionary = {}) -> void:
	current_view_name = "forge"
	navigate_to.emit("forge", data)


## Ir a la vista de Tienda / Mercader.
func go_to_shop(data: Dictionary = {}) -> void:
	current_view_name = "shop"
	navigate_to.emit("shop", data)


## Ir a la vista de Entrenamiento / Muñeco.
func go_to_training(data: Dictionary = {}) -> void:
	current_view_name = "training"
	navigate_to.emit("training", data)


## Ir al Tablón de Encargos (ya sea el de una ciudad o el atajo del Tablón de
## la Base — ver task4.md). Reutiliza la vista/gestor ya existentes
## (ViewEncargos/EncargosManager), accesibles también desde la barra de pestañas.
func go_to_encargos(data: Dictionary = {}) -> void:
	current_view_name = "encargos"
	navigate_to.emit("encargos", data)


## Ir a la vista de Transportista / Viaje rápido en ciudad.
func go_to_transport(data: Dictionary = {}) -> void:
	current_view_name = "transport"
	navigate_to.emit("transport", data)


## Ir a cualquier vista nombrada.
func go_to_view(view_name: String, data: Dictionary = {}) -> void:
	current_view_name = view_name
	navigate_to.emit(view_name, data)


## Cambiar de pestaña (barra inferior: "world" | "character" | "bag" | "info" | "options").
func switch_tab(tab_name: String) -> void:
	current_tab_name = tab_name
	tab_switched.emit(tab_name)


var previous_view_before_combat: String = ""

## Inicia un combate con los datos del enemigo (desde mapa o mazmorra).
func start_combat(enemy_data: Dictionary) -> void:
	previous_view_before_combat = current_view_name
	in_combat = true
	combat_started.emit(enemy_data)


## Finaliza un combate notificando la victoria o derrota. `fled`: true si el
## jugador huyó (en vez de ganar o perder). Se distingue de `victory` porque
## debe volver a la vista anterior (mundo o retomar mazmorra) igual que una
## victoria, pero SIN los efectos de victoria/derrota (sin sonido de derrota,
## sin ir a la Sala de la Esfera).
func end_combat(victory: bool, fled: bool = false) -> void:
	in_combat = false
	Engine.time_scale = 1.0
	combat_ended.emit(victory, fled)


# ══════════════════════════════════════════════════════════════════════════════
# CARGA ASÍNCRONA POR HILOS
# ══════════════════════════════════════════════════════════════════════════════
const LOADING_SCREEN_SCENE: String = "res://scenes/ui/loading/LoadingScreen.tscn"

var _loading_screen: Control = null
var _pending_scene_path: String = ""

## Sustituye a `get_tree().change_scene_to_file()` para transiciones pesadas
## (Menú Principal → GameRoot): muestra `LoadingScreen` mientras
## `ResourceLoader.load_threaded_request()` resuelve la escena en un hilo
## secundario (`WorkerThreadPool` interno del propio ResourceLoader), evitando
## la congelación de pantalla del primer frame. El progreso se sondea cada
## frame en `_process()` — no bloquea el hilo principal en ningún momento.
func change_view_threaded(target_scene_path: String) -> void:
	if _pending_scene_path != "":
		return   # ya hay una carga en curso
	var loading_packed: PackedScene = load(LOADING_SCREEN_SCENE) as PackedScene
	if loading_packed == null:
		# Sin pantalla de carga disponible: fallback al comportamiento anterior
		# (síncrono) antes que dejar al jugador sin poder avanzar.
		get_tree().change_scene_to_file(target_scene_path)
		return
	_pending_scene_path = target_scene_path
	_loading_screen = loading_packed.instantiate() as Control
	get_tree().root.add_child(_loading_screen)
	var err := ResourceLoader.load_threaded_request(target_scene_path)
	if err != OK:
		push_warning("SceneManager: load_threaded_request falló (%d) para %s, cargando de forma síncrona." % [err, target_scene_path])
		_finish_threaded_load()
		return
	set_process(true)


func _process(_delta: float) -> void:
	if _pending_scene_path == "":
		set_process(false)
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_pending_scene_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _loading_screen != null and is_instance_valid(_loading_screen) and _loading_screen.has_method("set_progress"):
				_loading_screen.call("set_progress", float(progress[0]) if progress.size() > 0 else 0.0)
		ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_finish_threaded_load()


func _finish_threaded_load() -> void:
	var path := _pending_scene_path
	_pending_scene_path = ""
	set_process(false)
	var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene   # fallback síncrono si el hilo falló
	if _loading_screen != null and is_instance_valid(_loading_screen):
		_loading_screen.queue_free()
		_loading_screen = null
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		push_error("SceneManager: no se pudo cargar la escena %s ni en hilo ni de forma síncrona." % path)
