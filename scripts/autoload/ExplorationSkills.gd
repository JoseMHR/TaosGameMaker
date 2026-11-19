# ExplorationSkills.gd
# ─────────────────────────────────────────────────────────────────────────────
# REGISTRO DATA-DRIVEN DE LAS 6 HABILIDADES DE EXPLORACIÓN
#
# Sustituye al antiguo sistema de "tres almas" (Sarah/Taos/Yui). Existe UN único
# set de 6 habilidades permanentes, cada una ligada a una profesión y desbloqueada
# al aprenderla. Cada habilidad emite un VERBO; los Objetos Inteligentes deciden
# cómo reaccionar (el motor y las habilidades NUNCA conocen los objetos).
#
# Este autoload solo describe las habilidades y ofrece consultas. El estado de
# desbloqueo persistente vive en `GlobalState.unlocked_skills`.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

## Modos de activación de una habilidad.
##   instant  → se ejecuta al pulsar (impacto, restaurar…).
##   directed → dirigida por la mirada (agarre).
##   toggle   → alterna un estado (distorsión temporal).
##   pulse    → efecto temporal de utilidad (instinto).
##   store    → almacena/aplica un recurso (afinidad elemental).
const MODE_INSTANT := "instant"
const MODE_DIRECTED := "directed"
const MODE_TOGGLE := "toggle"
const MODE_PULSE := "pulse"
const MODE_STORE := "store"

## Orden canónico (define el orden del HUD).
const ORDER: Array[String] = [
	"kinetic_wave",
	"psychic_grab",
	"time_distort",
	"explorer_instinct",
	"elemental_affinity",
	"restoration",
]

## Definición de cada habilidad. `energy` y `cooldown` calibrados para que el uso
## sostenido agote la barra (regen 18/s, MAX 100) sin impedir usos puntuales.
const SKILLS: Dictionary = {
	"kinetic_wave": {
		"profession": "Guerrero",
		"name": {"es": "Onda Cinética", "en": "Kinetic Wave", "fr": "Onde cinétique", "it": "Onda cinetica", "de": "Kinetische Welle", "zh": "动能冲击波", "ja": "キネティックウェーブ"},
		"verb": "impact",
		"mode": MODE_INSTANT,
		"energy": 28,
		"cooldown": 0.6,
		"range": 13.5,
		"icon": "res://assets/dungeon/skills/kinetic_wave.png",
		"color": Color(0.95, 0.55, 0.20),
	},
	"psychic_grab": {
		"profession": "Psíquico",
		"name": {"es": "Agarre Psíquico", "en": "Psychic Grab", "fr": "Emprise psychique", "it": "Presa psichica", "de": "Psychischer Griff", "zh": "精神抓握", "ja": "サイキックグラブ"},
		"verb": "grab",
		"mode": MODE_DIRECTED,
		"energy": 30,
		"cooldown": 0.8,
		"range": 14.5,
		"icon": "res://assets/dungeon/skills/psychic_grab.png",
		"color": Color(0.65, 0.35, 0.95),
	},
	"time_distort": {
		"profession": "Tiempo",
		"name": {"es": "Distorsión Temporal", "en": "Time Distortion", "fr": "Distorsion temporelle", "it": "Distorsione temporale", "de": "Zeitverzerrung", "zh": "时间扭曲", "ja": "タイムディストーション"},
		"verb": "timeshift",
		"mode": MODE_TOGGLE,
		"energy": 20,
		"cooldown": 0.5,
		"range": 14.0,
		"icon": "res://assets/dungeon/skills/time_distort.png",
		"color": Color(0.25, 0.80, 0.85),
	},
	"explorer_instinct": {
		"profession": "Arquero",
		"name": {"es": "Instinto del Explorador", "en": "Explorer's Instinct", "fr": "Instinct de l'explorateur", "it": "Istinto dell'esploratore", "de": "Instinkt des Entdeckers", "zh": "探险家的直觉", "ja": "探検家の直感"},
		"verb": "reveal",
		"mode": MODE_PULSE,
		"energy": 40,
		"cooldown": 6.0,
		"range": 18.0,
		"duration": 2.5,
		"icon": "res://assets/dungeon/skills/explorer_instinct.png",
		"color": Color(0.35, 0.85, 0.45),
	},
	"elemental_affinity": {
		"profession": "Elementalista",
		"name": {"es": "Afinidad Elemental", "en": "Elemental Affinity", "fr": "Affinité élémentaire", "it": "Affinità elementale", "de": "Elementare Affinität", "zh": "元素亲和", "ja": "エレメンタルアフィニティ"},
		"verb": "element",
		"mode": MODE_STORE,
		"energy": 25,
		"cooldown": 0.5,
		"range": 10.0,
		"icon": "res://assets/dungeon/skills/elemental_affinity.png",
		"color": Color(0.55, 0.75, 0.92),
	},
	"restoration": {
		"profession": "Sacerdote",
		"name": {"es": "Restauración", "en": "Restoration", "fr": "Restauration", "it": "Restaurazione", "de": "Wiederherstellung", "zh": "回复", "ja": "リストレーション"},
		"verb": "restore",
		"mode": MODE_INSTANT,
		"energy": 35,
		"cooldown": 0.8,
		"range": 8.0,
		"icon": "res://assets/dungeon/skills/restoration.png",
		"color": Color(0.95, 0.85, 0.40),
	},
}


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTAS DE DEFINICIÓN
# ══════════════════════════════════════════════════════════════════════════════

## Definición de una habilidad por id (o {} si no existe).
func get_skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})


## ¿Existe una habilidad con este id?
func has_skill(id: String) -> bool:
	return SKILLS.has(id)


## Todos los ids en orden canónico.
func all_ids() -> Array[String]:
	return ORDER.duplicate()


## Id de la habilidad de una profesión (o "" si la profesión no tiene ninguna).
func for_profession(profession: String) -> String:
	for id in ORDER:
		if String(SKILLS[id].get("profession", "")) == profession:
			return id
	return ""


## Nombre localizado de la habilidad.
func display_name(id: String) -> String:
	var s: Dictionary = get_skill(id)
	if s.is_empty():
		return id
	return Locale.pick(s.get("name", {"es": id, "en": id, "fr": id, "it": id, "de": id, "zh": id, "ja": id}))


## Verbo que emite la habilidad (impact/grab/timeshift/reveal/element/restore).
func verb(id: String) -> String:
	return String(get_skill(id).get("verb", ""))


## Coste de energía de la habilidad (0 si no existe).
func energy_cost(id: String) -> int:
	return int(get_skill(id).get("energy", 0))


## Enfriamiento en segundos (0 si no existe).
func cooldown(id: String) -> float:
	return float(get_skill(id).get("cooldown", 0.0))


## Alcance efectivo en metros (0 si no existe).
func range_of(id: String) -> float:
	return float(get_skill(id).get("range", 0.0))


## Modo de activación (instant/directed/toggle/pulse/store).
func mode(id: String) -> String:
	return String(get_skill(id).get("mode", MODE_INSTANT))


# ══════════════════════════════════════════════════════════════════════════════
# ESTADO DE DESBLOQUEO  (persistente en GlobalState.unlocked_skills)
# ══════════════════════════════════════════════════════════════════════════════

## Desbloqueos TEMPORALES de sesión (no persisten en el guardado). Los usan los
## tutoriales para permitir practicar la habilidad ANTES de obtenerla de forma
## permanente al completar la mini-mazmorra. Se limpian al entrar a cualquier
## escenario de mazmorra.
var _session_unlocks: Dictionary = {}

## Sesión EXCLUSIVA (Senderos de profesión): mientras está activa, SOLO cuentan
## los desbloqueos de sesión, ignorando los permanentes. Así, dentro de la prueba
## de una profesión, el jugador solo dispone de la habilidad de ESE sendero aunque
## ya domine otras. Se limpia con `clear_session()`.
var _session_exclusive: bool = false


## ¿Está desbloqueada la habilidad para el jugador? En una sesión EXCLUSIVA solo
## valen los desbloqueos de sesión; si no, permanente O de sesión.
func is_unlocked(id: String) -> bool:
	if _session_exclusive:
		return _session_unlocks.has(id)
	return GlobalState.unlocked_skills.has(id) or _session_unlocks.has(id)


## Concede un desbloqueo TEMPORAL (solo esta sesión, sin persistir).
func grant_session(id: String) -> void:
	if has_skill(id):
		_session_unlocks[id] = true


## Inicia una sesión EXCLUSIVA con una única habilidad (prueba de profesión):
## limpia lo anterior, activa el modo exclusivo y concede solo `id`.
func begin_exclusive_session(id: String) -> void:
	_session_unlocks.clear()
	_session_exclusive = true
	if has_skill(id):
		_session_unlocks[id] = true


## Limpia todos los desbloqueos temporales de sesión (y el modo exclusivo).
func clear_session() -> void:
	_session_unlocks.clear()
	_session_exclusive = false


## Desbloquea una habilidad de forma permanente. Devuelve true si era nueva.
func unlock(id: String) -> bool:
	if not has_skill(id) or GlobalState.unlocked_skills.has(id):
		return false
	GlobalState.unlocked_skills.append(id)
	return true


## Desbloquea la habilidad asociada a una profesión (al aprenderla). Devuelve el
## id desbloqueado o "" si esa profesión no tiene habilidad.
func unlock_for_profession(profession: String) -> String:
	var id := for_profession(profession)
	if id != "" and unlock(id):
		return id
	return ""


## Ids desbloqueados, en orden canónico (para pintar el HUD).
func unlocked_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if GlobalState.unlocked_skills.has(id):
			out.append(id)
	return out
