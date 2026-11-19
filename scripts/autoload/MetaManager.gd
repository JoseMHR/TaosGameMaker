# MetaManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# Autoload de META-PROGRESIÓN data-driven:
#   • LOGROS (achievements.json): { name, desc, icon, condition, reward }.
#     Se evalúan tras cada cambio de estado; al cumplirse la `condition` (Godot
#     Expression, reutiliza Design.eval_condition + la función stat()), se marca
#     como desbloqueado, se aplica su `reward` (mini-lenguaje) y se avisa a la UI.
#   • TUTORIALES (tutorials.json): { name, steps:[{ text, done_when }] }.
#     Cada tutorial avanza al siguiente paso cuando la condición `done_when` del
#     paso actual se cumple. Se emite el texto del paso activo para que la UI lo
#     muestre. El progreso (índice por tutorial) se persiste en GlobalState.
#
# Reutiliza el EVALUADOR de condiciones y el aplicador de RECOMPENSAS existentes,
# de modo que no duplica lógica: logros y tutoriales son "datos + condición".
# ─────────────────────────────────────────────────────────────────────────────
extends Node

## Emitida al desbloquear un logro. `data` = { id, name, desc, icon }.
signal achievement_unlocked(data: Dictionary)
## Emitida cuando un tutorial muestra un paso nuevo. `data` = { id, text, index, total }.
signal tutorial_step(data: Dictionary)

## Evita re-entrada: aplicar una recompensa emite state_updated, que dispararía
## otra evaluación en cascada. Con este cerrojo la evaluación no se anida.
var _evaluating: bool = false


func _ready() -> void:
	# Evaluación centralizada: cualquier cambio de estado del juego puede cumplir
	# la condición de un logro o hacer avanzar un tutorial.
	GlobalState.state_updated.connect(_on_state_updated)
	# Primera evaluación (arranque/carga de partida) diferida un frame para que
	# Design haya cargado sus datos y GlobalState su estado.
	call_deferred("evaluate_all")


func _on_state_updated() -> void:
	call_deferred("evaluate_all")


## Evalúa logros y tutoriales. Segura ante re-entrada.
func evaluate_all() -> void:
	if _evaluating:
		return
	_evaluating = true
	_evaluate_achievements()
	_evaluate_tutorials()
	_evaluating = false


# ─── LOGROS ───────────────────────────────────────────────────────────────────
func _evaluate_achievements() -> void:
	for ach_id in Design.achievements.keys():
		if GlobalState.achievements_unlocked.get(ach_id, false):
			continue
		var ach: Dictionary = Design.get_achievement(ach_id)
		var cond := String(ach.get("condition", ""))
		if cond == "" or not Design.eval_condition(cond, ""):
			continue
		# Desbloqueo: persistir ANTES de aplicar la recompensa para no re-disparar.
		GlobalState.achievements_unlocked[ach_id] = true
		var reward := String(ach.get("reward", ""))
		if reward != "":
			Design.apply_reward(reward, "")
		achievement_unlocked.emit({
			"id": ach_id,
			"name": Design._loc_str(ach.get("name", ach_id)),
			"desc": Design._loc_str(ach.get("desc", "")),
			"icon": String(ach.get("icon", "🏆")),
		})


## ¿Está desbloqueado el logro `ach_id`?
func is_achievement_unlocked(ach_id: String) -> bool:
	return bool(GlobalState.achievements_unlocked.get(ach_id, false))


# ─── TUTORIALES ─────────────────────────────────────────────────────────────
func _evaluate_tutorials() -> void:
	for tut_id in Design.tutorials.keys():
		var tut: Dictionary = Design.get_tutorial(tut_id)
		var steps = tut.get("steps", [])
		if not (steps is Array) or steps.is_empty():
			continue
		var idx: int = int(GlobalState.tutorials_progress.get(tut_id, 0))
		# Avanza mientras la condición del paso actual ya esté cumplida (permite
		# saltar varios pasos de golpe si el jugador ya cumplía sus condiciones).
		while idx < steps.size():
			var step = steps[idx]
			var done := String(step.get("done_when", "")) if step is Dictionary else ""
			if done != "" and Design.eval_condition(done, ""):
				idx += 1
			else:
				break
		if idx != int(GlobalState.tutorials_progress.get(tut_id, -1)):
			GlobalState.tutorials_progress[tut_id] = idx
			if idx < steps.size():
				var cur = steps[idx]
				tutorial_step.emit({
					"id": tut_id,
					"text": Design._loc_str(cur.get("text", "")) if cur is Dictionary else "",
					"index": idx,
					"total": steps.size(),
				})


## Índice del paso actual de un tutorial (>= nº de pasos = completado).
func tutorial_index(tut_id: String) -> int:
	return int(GlobalState.tutorials_progress.get(tut_id, 0))
