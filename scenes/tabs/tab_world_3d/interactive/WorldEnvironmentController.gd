class_name WorldEnvironmentController
extends RefCounted
## CONTROLADOR DE CLIMA Y AMBIENTE DEL MAPAMUNDI — Componente especialista
## extraído de TabWorld3D.
##
## Centraliza:
##  - El ciclo día/noche y la iluminación global (interpola `DirectionalLight3D`
##    `_sun` y el `Environment` `_env` según `TimeManager.daylight_factor()`, más
##    las luciérnagas nocturnas).
##  - El AMBIENTE data-driven: música por bioma/casilla (`AudioManager.play_music`)
##    y clima probabilístico cacheado por terreno (`WeatherOverlay`).
##
## Mantiene referencia a la `TabWorld3D` propietaria (`_view`), sobre cuyos nodos
## y estado opera. `TabWorld3D` conserva fachadas con las mismas firmas. El
## comportamiento es IDÉNTICO al monolito original.

## Paletas de iluminación de referencia para día pleno y noche cerrada. La
## iluminación real se interpola entre ambas con el factor de luz [0,1], de modo
## que amanecer/atardecer son transiciones suaves y no un corte brusco.
const _DN_DAY := {
	"sun_energy": 0.95,
	"sun_color": Color(0.98, 0.95, 0.90),
	"amb_color": Color(0.58, 0.60, 0.70),
	"amb_energy": 0.42,
	"bg": Color(0.04, 0.05, 0.09),
	"fog": Color(0.05, 0.06, 0.10),
}
const _DN_NIGHT := {
	"sun_energy": 0.22,
	"sun_color": Color(0.55, 0.65, 0.95),
	"amb_color": Color(0.22, 0.28, 0.46),
	"amb_energy": 0.34,
	"bg": Color(0.015, 0.02, 0.045),
	"fog": Color(0.025, 0.035, 0.08),
}

## Vista del mapamundi propietaria del estado y de los nodos 3D.
var _view: Node = null
var _wind_tween: Tween = null
var _current_wind_gust: float = 0.0
var _current_weather_id: String = ""

## Enlaza este controlador con la TabWorld3D propietaria. Debe llamarse una vez
## tras instanciarlo (en `TabWorld3D._ready`).
func setup(view: Node) -> void:
	_view = view

#region CICLO DÍA / NOCHE — ILUMINACIÓN

## Interpola la iluminación del mundo según la hora (TimeManager). `force` reaplica
## aunque el factor no haya cambiado (al construir la escena o volver al mundo).
func apply_daynight_lighting(force: bool) -> void:
	if _view._sun == null or _view._env == null:
		return
	var f: float = TimeManager.daylight_factor()
	# Evita reescribir materiales/entorno cada frame si el factor apenas cambia.
	if not force and absf(f - _view._last_daylight) < 0.004:
		return
	_view._last_daylight = f
	_view._sun.light_energy = lerpf(_DN_NIGHT["sun_energy"], _DN_DAY["sun_energy"], f)
	_view._sun.light_color = (_DN_NIGHT["sun_color"] as Color).lerp(_DN_DAY["sun_color"], f)
	# De noche las sombras nítidas quedan mal (poca luz direccional): las suavizamos.
	_view._sun.shadow_enabled = f > 0.15
	_view._env.ambient_light_color = (_DN_NIGHT["amb_color"] as Color).lerp(_DN_DAY["amb_color"], f)
	_view._env.ambient_light_energy = lerpf(_DN_NIGHT["amb_energy"], _DN_DAY["amb_energy"], f)
	_view._env.background_color = (_DN_NIGHT["bg"] as Color).lerp(_DN_DAY["bg"], f)
	_view._env.fog_light_color = (_DN_NIGHT["fog"] as Color).lerp(_DN_DAY["fog"], f)

	# Luces puntuales de POIs, casas, mazmorras y ciudades (encienden suavemente al anochecer)
	var night_factor: float = clampf(1.0 - (f / 0.5), 0.0, 1.0)
	var poi_lights: Array = _view.get_tree().get_nodes_in_group("poi_night_lights")
	for n in poi_lights:
		if n is OmniLight3D:
			var base_e: float = float(n.get_meta("base_energy", 0.9))
			n.light_energy = base_e * night_factor
			n.visible = night_factor > 0.01

	# Luciérnagas SOLO de noche cerrada (f bajo): el mundo se siente vivo sin
	# distraer durante el día. reduce_motion las desactiva por completo.
	if _view._fireflies != null:
		_view._fireflies.emitting = f < 0.3 and not Locale.reduce_motion
	# Motas de polvo doradas SOLO con sol alto (f alto): mismo patrón que las
	# luciérnagas nocturnas, pero para el día.
	if _view._sun_dust != null:
		_view._sun_dust.emitting = f > 0.55 and not Locale.reduce_motion
	# Destello de sol sobre el agua: sigue el mismo factor de luz, así que de
	# noche el mar deja de brillar en vez de quedarse iluminado artificialmente.
	for water_group in ["sea", "shore"]:
		var wmat: ShaderMaterial = _view._ground_mat_cache.get(water_group, null)
		if wmat != null:
			wmat.set_shader_parameter("sun_specular", f)

#endregion

#region AMBIENTE DATA-DRIVEN (música + clima)

## AMBIENTE DATA-DRIVEN: resuelve música y clima de la casilla actual y los
## aplica (música solo si cambia; clima vía WeatherOverlay). Prioridad de resolución:
##   1) override de la propia casilla (cell.ambience = { music?, weather? }, desde ids.json)
##   2) ambiente por terreno (Design.get_terrain_ambience)
## Un valor "" o ausente = usar el defecto (música "world", sin clima).
func update_ambience(cell: CellResource) -> void:
	if cell == null:
		return
	var _terr_amb := Design.get_terrain_ambience(cell.terrain)
	var over: Dictionary = cell.ambience if (cell.ambience is Dictionary) else {}

	# Música:
	# 1. Override de la propia casilla/POI (si está fijado explícitamente en su JSON)
	# 2. Si está en barco / navegando en agua marina -> música de travesía oceánica
	# 3. Música de la Gran Zona Geográfica (Design.get_zone_music_at)
	var music_id := String(over.get("music", ""))
	if music_id == "":
		if GlobalState.get("is_sailing") == true or (cell.terrain in ["sea", "are"] and GlobalState.has_world_flag("boat_obtained")):
			music_id = "world_boat"
		elif GlobalState.has_world_flag("boss_puerto_activo") and not GlobalState.has_world_flag("boss_puerto_derrotado"):
			var zone_at: Dictionary = Design.get_zone_at(_view.player_pos)
			if String(zone_at.get("id", "")) == "zona_4_celestia":
				music_id = "event_crisis_puerto"
			else:
				music_id = Design.get_zone_music_at(_view.player_pos)
		else:
			music_id = Design.get_zone_music_at(_view.player_pos)

	if music_id != "" and music_id != _view._current_music_id:
		_view._current_music_id = music_id
		if AudioManager != null:
			AudioManager.play_music(music_id, 0.8)

	# Clima: override de casilla > terreno (por PROBABILIDAD, cacheado) > "none".
	# El override de la casilla siempre manda (un POI puede forzar un clima fijo).
	var weather_id: String
	if over.has("weather"):
		weather_id = String(over.get("weather", "none"))
	else:
		# Si la casilla es costa o río ("cst", "riv", "wtr", "sea") y no está navegando en barco,
		# preserva el clima que ya venía activo en el bioma para evitar que pisar la orilla o un puente
		# apague bruscamente el viento ambiental del bosque/pradera.
		if cell.terrain in ["cst", "riv", "wtr", "sea"] and not GlobalState.is_sailing and _current_weather_id != "":
			weather_id = _current_weather_id
		else:
			weather_id = resolve_terrain_weather(cell.terrain)
	_current_weather_id = weather_id
	var wdef := Design.get_weather_def(weather_id)
	if _view._weather_overlay:
		_view._weather_overlay.apply(weather_id, wdef)
	# El césped toma prestado el `drift` (deriva lateral) de la propia definición
	# de clima como intensidad de ráfaga, interpolado suavemente por tween para
	# evitar cortes bruscos al cruzar entre casillas.
	if _view._grass_mat is ShaderMaterial:
		var drift := float(wdef.get("drift", 0.0))
		var target_gust := clampf(drift / 140.0, 0.0, 1.0)
		_animate_wind_gust(target_gust)


func _animate_wind_gust(target: float) -> void:
	if _view == null or not is_instance_valid(_view) or not (_view._grass_mat is ShaderMaterial):
		return
	if is_equal_approx(_current_wind_gust, target):
		return
	if _wind_tween != null and _wind_tween.is_valid():
		_wind_tween.kill()
	_wind_tween = _view.create_tween()
	_wind_tween.tween_method(func(val: float) -> void:
		_current_wind_gust = val
		if _view != null and is_instance_valid(_view) and _view._grass_mat is ShaderMaterial:
			(_view._grass_mat as ShaderMaterial).set_shader_parameter("wind_gust", val)
	, _current_wind_gust, target, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Devuelve el clima del terreno tirando por probabilidad SOLO la primera vez que
## se ve ese terreno (o tras un reset); luego lo sirve cacheado para que sea
## estable mientras recorres el bioma. La re-tirada global ocurre al cambiar de
## fase (ver TabWorld3D._on_world_phase_changed → reroll_weather).
func resolve_terrain_weather(terrain: String) -> String:
	if _view._weather_by_terrain.has(terrain):
		return String(_view._weather_by_terrain[terrain])
	var w := Design.pick_terrain_weather(terrain, randf())
	_view._weather_by_terrain[terrain] = w
	return w

## Re-tira el clima de todos los terrenos (p. ej. al cambiar día↔noche) y lo
## reaplica a la casilla actual para que el cambio se note de inmediato.
func reroll_weather() -> void:
	_view._weather_by_terrain.clear()
	var cell: CellResource = GlobalState.hexagons_db.get(_view.player_pos, null) as CellResource
	if cell:
		update_ambience(cell)

#endregion
