class_name CombatTurnEngine
extends RefCounted
## MOTOR DE TURNOS ATB — Componente especialista extraído de ViewCombat.
##
## NOTA de implementación: se modela como `RefCounted` (no `Node`) porque no se
## añade al árbol de escena —lo conduce `ViewCombat._process`— y así se libera
## automáticamente con la vista sin fugas. No usa API exclusiva de Node: el tween
## de desvanecimiento del escudo se crea vía `_view.create_tween()`.
##
## Encapsula el BUCLE DE PROCESAMIENTO ATB EN TIEMPO REAL: carga/pausa de las
## barras de tiempo del héroe y del enemigo, escala temporal de "cámara lenta"
## al decidir, animación idle del enemigo, cooldown/ventana de defensa activa y
## el arranque de la descarga de ataque enemigo (telegrafía).
##
## Mantiene una referencia a la `ViewCombat` propietaria (`_view`), sobre cuyos
## nodos y estado opera; `ViewCombat._process` sólo delega en `tick(delta)`. El
## comportamiento es IDÉNTICO al monolito original.
##
## Además emite señales desacopladas para consumidores externos que las
## necesiten, sin alterar el flujo interno:
##  - `atb_updated(hero_pct, enemy_pct)`: cada frame de combate activo.
##  - `hero_turn_ready`: al llenarse el ATB del héroe (arranca su turno).
##  - `enemy_turn_ready`: al llenarse el ATB del enemigo (inicia su descarga).

signal atb_updated(hero_pct: float, enemy_pct: float)
signal hero_turn_ready
signal enemy_turn_ready

## Vista de combate propietaria del estado y de los nodos UI.
var _view: ViewCombat = null

## Enlaza este motor con la ViewCombat propietaria. Debe llamarse una vez tras
## instanciarlo (en `ViewCombat._build_ui`/`_ready`).
func setup(view: ViewCombat) -> void:
	_view = view

## Avanza un frame del ATB. Debe invocarse desde `ViewCombat._process(delta)`.
func tick(delta: float) -> void:
	if not _view.is_combat_active:
		return

	# El ATB del jugador SIEMPRE avanza en tiempo real (delta puro); es lo que
	# marca el ritmo de tu turno.
	var real_delta := delta

	# ── ESCALA TEMPORAL ──────────────────────────────────────────────
	# Cuando tu ATB está lleno y esperas decisión (cola aún encolable, no en plena
	# ejecución), el "mundo" (enemigo, animaciones, estados, cooldowns) se ralentiza
	# a COMBAT_DECISION_TIME_SCALE sin pausar del todo: piensas en cámara lenta.
	var target_scale := GameConfig.COMBAT_DECISION_TIME_SCALE if _view._is_awaiting_decision() else 1.0
	# Transición gradual (frame-rate independiente): ~0.15 s de entrada/salida.
	_view._world_time_scale = lerp(_view._world_time_scale, target_scale, clampf(delta * 9.0, 0.0, 1.0))
	var world_delta := delta * _view._world_time_scale

	# Animación de respiración idle del enemigo (escala pulsante). No se aplica
	# mientras el enemigo está cargando/atacando (usa un Tween sobre la posición).
	_view._enemy_anim_time += world_delta
	if _view._enemy_img_rect and _view._enemy_img_rect.texture and not _view._enemy_is_discharging:
		var wave := sin(_view._enemy_anim_time * 2.5)
		# Pivote en el centro para una escala armónica (squash & stretch).
		_view._enemy_img_rect.pivot_offset = _view._enemy_img_rect.size / 2.0
		var pulse := wave * 0.04
		_view._enemy_img_rect.scale.x = 1.0 + pulse
		_view._enemy_img_rect.scale.y = 1.0 - pulse
		# Bob de flotación: el enemigo se eleva y baja suavemente sobre su sombra
		# (siempre por ENCIMA de la base, nunca la atraviesa) para dar vida sin
		# despegarse del suelo.
		var bob := (wave - 1.0) * 6.0             # rango -12..0 px
		_view._enemy_img_rect.position.y = _view._enemy_sprite_base_y + bob
		# La sombra reacciona al bob: al elevarse el enemigo, se encoge y aclara;
		# al asentarse, crece y se oscurece → sensación de contacto con el suelo.
		if _view._enemy_shadow:
			var t := (wave + 1.0) * 0.5           # 0..1 (1 = enemigo abajo/asentado)
			_view._enemy_shadow.pivot_offset = _view._enemy_shadow.size / 2.0
			var sc := 0.84 + t * 0.16
			_view._enemy_shadow.scale = Vector2(sc, sc)
			_view._enemy_shadow.modulate.a = 0.55 + t * 0.45

	# Procesar Cooldown de Defensa Activa (con escala temporal)
	# Procesar temporizador de pose de dolor / herido del protagonista (tiempo real)
	if _view._hero_hurt_timer > 0.0:
		_view._hero_hurt_timer = max(0.0, _view._hero_hurt_timer - real_delta)
		if _view._hero_hurt_timer <= 0.0:
			_view._update_hero_sprite_pose()

	# Procesar temporizador de pose de ataque del protagonista (tiempo real)
	if _view._hero_attack_timer > 0.0:
		_view._hero_attack_timer = max(0.0, _view._hero_attack_timer - real_delta)
		if _view._hero_attack_timer <= 0.0:
			_view._update_hero_sprite_pose()

	# Procesar ventana libre de cooldown de defensa (Reflejo Temporal)
	if _view._defense_free_timer > 0.0:
		_view._defense_free_timer = max(0.0, _view._defense_free_timer - real_delta)
		_view.defense_cooldown = 0.0
		if _view._btn_defense_cooldown_panel != null:
			_view._btn_defense_cooldown_panel.visible = false

	if _view.defense_cooldown > 0.0:
		_view.defense_cooldown = max(0.0, _view.defense_cooldown - world_delta)
		if _view.defense_cooldown <= 0.0:
			_view._btn_defense_cooldown_panel.visible = false
		else:
			_view._btn_defense_cooldown_panel.visible = true
			_view._lbl_defense_cooldown_text.text = "%.1fs" % _view.defense_cooldown

	# Procesar tiempo activo de Defensa (Invulnerabilidad) — escala temporal
	if _view.defense_active_time > 0.0:
		_view.defense_active_time = max(0.0, _view.defense_active_time - world_delta)
		if _view.defense_active_time <= 0.0:
			_view.is_invulnerable = false
			_view._block_quality = ""
			_view.set_hero_defending(false)
			# Ocultar escudo con desvanecimiento suave
			var tw := _view.create_tween()
			tw.tween_property(_view._shield_overlay, "modulate:a", 0.0, 0.25)
			# Activar cooldown de 5s al acabar la protección (salvo si Reflejo Temporal está activo)
			if _view._defense_free_timer > 0.0:
				_view.defense_cooldown = 0.0
				if _view._btn_defense_cooldown_panel != null:
					_view._btn_defense_cooldown_panel.visible = false
			else:
				_view.defense_cooldown = ViewCombat.DEFENSE_COOLDOWN_MAX

	# Cargar ATB del Jugador (tiempo real; se detiene al 100% esperando ATACAR).
	# No carga mientras defiendes, mientras se ejecuta la secuencia, ni mientras el enemigo ataca.
	if _view.defense_active_time <= 0.0 and not _view._executing_queue and not _view._enemy_is_discharging:
		if _view.player_atb < 100.0:
			# AGI → ATB (ver GameConfig.atb_speed_multiplier): la "velocidad"
			# derivada de AGI acelera la carga del ATB del jugador, con tope,
			# además de los multiplicadores de estado (prisa/lentitud).
			var rate := ViewCombat.PLAYER_ATB_CHARGE_RATE * GameConfig.atb_speed_multiplier(GlobalState.get_speed()) * GameConfig.status_atb_mult(_view.player_statuses)
			_view.player_atb = min(100.0, _view.player_atb + rate * real_delta)
			_view._sync_player_atb_labels()
			# Al llenarse, arranca el turno (aplica Estado Resonante si procede).
			if _view.player_atb >= 100.0:
				_view._on_player_turn_ready()
				hero_turn_ready.emit()

	# Estado de los botones de acción (EJECUTAR / DEFENDER) según la fase de turno.
	_view._update_action_buttons()

	# Cargar o Descargar ATB del Enemigo (con escala temporal)
	if _view._enemy_is_discharging:
		# La DESCARGA del ataque enemigo (la
		# cuenta atrás real de su golpe, con la ventana de defensa/parry) debe
		# ir SIEMPRE a velocidad normal — usaba `world_delta` (la cámara lenta
		# de "estás decidiendo"), así que si tu ATB se llenaba justo mientras el
		# enemigo descargaba, su golpe se ralentizaba también, cambiando el
		# timing real de defensa según decidieras rápido o despacio. `real_delta`
		# SÍ es sensible a `Engine.time_scale` (viene del `delta` de
		# `_process`), así que durante el "bullet-time" (task_reforma_defensa.md,
		# FASE 1) el golpe se sigue acercando en los MISMOS puntos de ATB, solo
		# que repartidos en más tiempo REAL — exactamente el efecto buscado.
		_view.enemy_atb = max(0.0, _view.enemy_atb - ViewCombat.ENEMY_DISCHARGE_RATE * real_delta)
		_view._bar_enemy_atb.value = _view.enemy_atb

		# FASE 1/2: entra en "bullet-time" (ralentiza el tiempo + proyecta el
		# anillo de impacto sobre el héroe) en cuanto quedan
		# BULLET_TIME_ATB_WINDOW puntos de ATB para el golpe, y mantiene el
		# anillo sincronizado con la distancia real al impacto cada frame.
		var diff_to_hit := _view.enemy_atb - _view.enemy_hit_threshold
		if not _view._enemy_has_hit and diff_to_hit <= ViewCombat.BULLET_TIME_ATB_WINDOW:
			_view._enter_bullet_time()
		if _view._bullet_time_active and _view._defense_ring != null:
			_view._defense_ring.set_progress(diff_to_hit / ViewCombat.BULLET_TIME_ATB_WINDOW)

		# Comprobar si cruza el umbral para golpear
		if _view.enemy_atb <= _view.enemy_hit_threshold and not _view._enemy_has_hit:
			_view._enemy_has_hit = true
			# Si el jugador nunca pulsó DEFENDER a tiempo, el golpe resuelve la
			# ventana como "fuera de ventana" (no-op si ya se resolvió al pulsar).
			_view._resolve_defense_encounter(_view._block_quality if _view._block_quality != "" else "none")
			_view._execute_enemy_action()

		# Fin de la descarga
		if _view.enemy_atb <= 0.0:
			_view._enemy_is_discharging = false
			_view._enemy_has_hit = false
			_view._exit_camera_focus()
	else:
		# El enemigo no carga ATB si algún estado se lo impide (chrono_lock/stun) o si es el muñeco de entrenamiento.
		var is_dummy: bool = bool(_view.enemy_data.get("is_training_dummy", false)) or String(_view.enemy_data.get("id", "")) == "muneco_entrenamiento"
		var enemy_locked: bool = is_dummy or GameConfig.status_any_flag(_view.enemy_statuses, "no_charge")
		if _view._eco_process_timer > 0.0:
			_view._eco_process_timer = max(0.0, _view._eco_process_timer - real_delta)
			enemy_locked = true
		if _view.enemy_atb < 100.0 and not enemy_locked:
			var rate := ViewCombat.ENEMY_ATB_CHARGE_RATE * GameConfig.status_atb_mult(_view.enemy_statuses)
			_view.enemy_atb = min(100.0, _view.enemy_atb + rate * world_delta)
			_view._bar_enemy_atb.value = _view.enemy_atb

		# Si el ATB del enemigo llega a 100%, inicia la descarga de ataque
		if _view.enemy_atb >= 100.0:
			if GameConfig.status_any_flag(_view.enemy_statuses, "skip"):
				_view.enemy_atb = 0.0
				_view._bar_enemy_atb.value = 0.0
				_view._decrement_statuses(_view.enemy_statuses)
				_view._update_status_labels()
				_view.log_message("[color=cyan]⚡ ¡%s está aturdido / incapacitado! Pierde el turno.[/color]" % _view._enemy_name())
			else:
				# Decidir YA la acción: si es un autobuff (no puede dañar al
				# jugador en absoluto) no tiene sentido activar la fase de
				# descarga/"bullet-time" que le pide defenderse de un golpe que
				# nunca le va a quitar vida — se resuelve al instante, sin
				# congelar el combate ni pedir que bloquee nada.
				var chosen_skill: Dictionary = _view._choose_enemy_skill()
				if not chosen_skill.is_empty() and String(chosen_skill.get("role", "attack")) == "buff":
					_view.enemy_atb = 0.0
					_view._bar_enemy_atb.value = 0.0
					_view._pending_enemy_skill = chosen_skill
					_view._execute_enemy_action()
				else:
					# Iniciar fase de descarga (ataque real: puede dañar)
					_view._enemy_is_discharging = true
					_view._enemy_has_hit = false
					# FASE 1: zoom de cámara de enfoque desde el inicio de la
					# animación de ataque (windup), antes incluso de que arranque
					# el "bullet-time" de los últimos instantes.
					_view._enter_camera_focus()
					_view._play_enemy_windup()
					# TELEGRAFÍA: anuncia la acción ya decidida, dando una ventana
					# de reacción antes de que el golpe cruce el umbral.
					_view._pending_enemy_skill = chosen_skill
					_view._telegraph_enemy_intent(_view._pending_enemy_skill)
					enemy_turn_ready.emit()

	atb_updated.emit(_view.player_atb, _view.enemy_atb)
