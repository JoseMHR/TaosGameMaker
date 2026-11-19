# TimeManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# Autoload Singleton — RELOJ DEL MUNDO (ciclo día/noche) reutilizable.
#
# Modela un reloj in-game de 24 horas que avanza a distinto ritmo REAL según la
# fase: el día dura `GameConfig.DAY_DURATION_SEC` segundos reales y la noche
# `GameConfig.NIGHT_DURATION_SEC`. Las horas de amanecer/anochecer y las duraciones
# NO están hardcodeadas: se leen de `data/config.json` vía GameConfig (editables
# desde el Editor).
#
# Es un SISTEMA CENTRAL Y ESCALABLE: no dibuja nada por sí mismo. Otros sistemas
# se suscriben a sus señales o consultan su API para reaccionar:
#   · TabWorld3D    → oscurece el mapa e interpola la iluminación (daylight_factor).
#   · POIs/tiendas  → disponibilidad según is_day()/is_night().
#   · Clima, NPCs   → futuros consumidores (NPCs nocturnos, climas por hora...).
#
# La hora se PERSISTE en GlobalState.world_hour (fuente de verdad del guardado):
# TimeManager la lee al cargar y la escribe mientras avanza, de modo que el ciclo
# continúa exactamente donde se dejó entre sesiones.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

## Emitida al cambiar de fase (cruce día↔noche). `phase` = "day" | "night".
signal phase_changed(phase: String)
## Emitida cada vez que la hora entera in-game cambia (p. ej. de 8 a 9). Útil para
## relojes de UI y para lógica basada en horas. `hour` = entero [0,23].
signal hour_changed(hour: int)

const PHASE_DAY: String = "day"
const PHASE_NIGHT: String = "night"

## Hora in-game actual en el rango [0, 24). Fuente de verdad en memoria; se
## sincroniza con GlobalState.world_hour para el guardado.
var hour: float = 8.0

## Si está en pausa, el reloj no avanza (p. ej. en menús, cinemáticas o combate).
var paused: bool = false

var _last_phase: String = PHASE_DAY
var _last_hour_int: int = -1


func _ready() -> void:
	# El reloj solo debe avanzar con una partida en curso; al cargar/empezar una
	# partida sincronizamos la hora desde el estado persistente.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if SaveManager.has_signal("game_loaded"):
		SaveManager.game_loaded.connect(_sync_from_state)
	_sync_from_state()


## Sincroniza la hora en memoria desde el estado persistente (al cargar partida).
func _sync_from_state() -> void:
	hour = clampf(GlobalState.world_hour, 0.0, 24.0)
	_last_phase = _phase_for_hour(hour)
	_last_hour_int = int(floor(hour))


func _process(delta: float) -> void:
	# Solo avanza con partida activa y sin pausa.
	if paused or not SaveManager.active:
		return
	if delta <= 0.0:
		return
	_advance(_hours_per_second(hour) * delta)


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Fase actual: "day" o "night".
func phase() -> String:
	return _phase_for_hour(hour)

## ¿Es de día ahora mismo?
func is_day() -> bool:
	return phase() == PHASE_DAY

## ¿Es de noche ahora mismo?
func is_night() -> bool:
	return phase() == PHASE_NIGHT

## Hora in-game actual (float [0,24)).
func get_hour() -> float:
	return hour

## Hora formateada "HH:MM" para la UI.
func get_clock_string() -> String:
	var h: int = int(floor(hour)) % 24
	var m: int = int(floor((hour - floor(hour)) * 60.0))
	return "%02d:%02d" % [h, m]

## Factor de luz diurna suave en [0,1]: 1.0 pleno día, 0.0 plena noche, con una
## transición lineal (amanecer/atardecer) de `DAY_TWILIGHT_HOURS` horas en cada
## borde. Lo usa TabWorld3D para interpolar la iluminación de forma continua.
func daylight_factor() -> float:
	var dawn: float = GameConfig.DAY_START_HOUR
	var dusk: float = GameConfig.NIGHT_START_HOUR
	var tw: float = maxf(0.01, GameConfig.DAY_TWILIGHT_HOURS)
	if hour < dawn or hour >= dusk:
		return 0.0   # noche plena
	# Dentro del día: rampas de amanecer y atardecer.
	var up: float = clampf((hour - dawn) / tw, 0.0, 1.0)
	var down: float = clampf((dusk - hour) / tw, 0.0, 1.0)
	return minf(up, down)

## Avanza el reloj `h` horas in-game (reutilizable: comer, descansar, "pasar
## tiempo" en la hoguera...). Emite las señales de fase/hora si procede.
func advance_hours(h: float) -> void:
	if h <= 0.0:
		return
	_advance(h)

## Fija la hora directamente (útil para eventos/cinemáticas o pruebas).
func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	GlobalState.world_hour = hour
	_emit_transitions()

## Pausa/reanuda el avance del reloj.
func set_paused(p: bool) -> void:
	paused = p

## Duración REAL (segundos) de un ciclo completo de 24 horas in-game (día +
## noche). Útil para sistemas que maduran/expiran a esa escala (p. ej. los
## cultivos del Agricultor) sin depender de un contador de "días" que el reloj
## no lleva (`hour` da la vuelta cada 24h in-game, no acumula días).
func full_day_duration_sec() -> float:
	return GameConfig.DAY_DURATION_SEC + GameConfig.NIGHT_DURATION_SEC


# ══════════════════════════════════════════════════════════════════════════════
# INTERNOS
# ══════════════════════════════════════════════════════════════════════════════

## Avance común: suma horas con envoltura [0,24), actualiza el estado persistente
## y emite las señales de transición (fase/hora).
func _advance(h: float) -> void:
	hour = fposmod(hour + h, 24.0)
	# Escribimos la hora en el estado SIN emitir state_updated (evita autoguardado
	# cada frame); el guardado la recoge cuando ocurra por otros eventos.
	GlobalState.world_hour = hour
	_emit_transitions()

## Emite phase_changed / hour_changed si la fase o la hora entera han cambiado.
func _emit_transitions() -> void:
	var ph: String = _phase_for_hour(hour)
	if ph != _last_phase:
		_last_phase = ph
		phase_changed.emit(ph)
		# Un cambio de fase es un buen momento para persistir el progreso.
		if SaveManager.active:
			SaveManager.request_autosave()
	var hi: int = int(floor(hour))
	if hi != _last_hour_int:
		_last_hour_int = hi
		hour_changed.emit(hi)

## Ritmo de avance (horas in-game por segundo real) según la fase de `h`.
func _hours_per_second(h: float) -> float:
	var day_hours: float = _day_span_hours()
	var night_hours: float = 24.0 - day_hours
	if _phase_for_hour(h) == PHASE_DAY:
		return day_hours / maxf(0.01, GameConfig.DAY_DURATION_SEC)
	return night_hours / maxf(0.01, GameConfig.NIGHT_DURATION_SEC)

## Nº de horas in-game que dura el día (desde el amanecer hasta el anochecer).
func _day_span_hours() -> float:
	var span: float = GameConfig.NIGHT_START_HOUR - GameConfig.DAY_START_HOUR
	return clampf(span, 0.5, 23.5)

## Fase ("day"/"night") correspondiente a una hora dada.
func _phase_for_hour(h: float) -> String:
	if h >= GameConfig.DAY_START_HOUR and h < GameConfig.NIGHT_START_HOUR:
		return PHASE_DAY
	return PHASE_NIGHT
