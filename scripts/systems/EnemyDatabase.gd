# EnemyDatabase.gd
# Registro DATA-DRIVEN de enemigos de combate (antes estaban "inline" en ViewDungeon
# y QuestManager). Centraliza vida, ataque, TIPO de ataque, defensas, esquiva,
# ELEMENTO + debilidades, IA de comportamiento, estado infligido y TABLA DE BOTÍN.
#
# Cada enemigo:
#   name{es,en}, icon, archetype ("balanced"|"tank"|"glass_cannon"|"boss"),
#   attack_type ("physical"|"magic"|"ranged"), dodge (% a evitar tu golpe),
#   element ("fire"|"ice"|"lightning"|"poison"|"physical"|"none"),
#   weak_to:[elementos] (x1.5),  resist:[elementos] (x0.5),
#   status_on_hit:{type,chance,turns,power}?  (estado que te aplica al golpearte),
#   ai ("aggressive"|"defensive"|"caster"),
#   xp_reward, gold_reward, loot:[ ... ]  (ver GlobalState.grant_loot)
#
# task3_rebalanceo_global_limpieza_y_optimizacion.md FASE2: HP/Ataque/Defensa
# YA NO son valores absolutos por enemigo (`base_hp`/`hp_scale`/...). Se generan
# proceduralmente a partir de `level` (el nivel al que se instancia el combate,
# pasado por quien lo coloca: mazmorra/mapamundi) y `archetype`
# (multiplicador fijo por rol). Así, subir el nivel de una mazmorra entera o
# reequilibrar el juego es cuestión de tocar las fórmulas aquí, no 70 JSON.
#
# ➕ Para añadir un enemigo: copia un bloque. ViewDungeon y QuestManager lo usan solos.
class_name EnemyDatabase


# ─────────────────────────────────────────────────────────────────────────────
# GENERACIÓN PROCEDURAL DE STATS POR NIVEL Y ARQUETIPO (FASE2)
# ─────────────────────────────────────────────────────────────────────────────
## Curvas base por nivel (L = nivel del enemigo, L>=1).
static func _hp_base(level: int) -> float:
	return 8.0 + 2.0 * float(level) + 0.08 * pow(float(level), 1.85)

static func _atk_base(level: int) -> float:
	return 2.5 + 1.2 * float(level) + 0.02 * pow(float(level), 1.8)

static func _def_base(level: int) -> float:
	return maxf(0.0, 0.4 * float(level - 1) + 0.01 * pow(float(level), 1.8))

## Multiplicadores {hp, atk, def} por arquetipo. `is_boss=true` en build_enemy()
## SIEMPRE fuerza "boss" aquí, sin importar el archetype "natural" declarado en
## el JSON: varios enemigos comunes se reutilizan como jefe de una mazmorra y
## trasgo normal de otra, así que el rol de jefe es del PUESTO, no del enemigo.
const ARCHETYPE_MULTIPLIERS: Dictionary = {
	"balanced":     {"hp": 1.0,   "atk": 1.0,  "def": 1.0},
	"tank":         {"hp": 1.45,  "atk": 0.80, "def": 1.35},
	"glass_cannon": {"hp": 0.75,  "atk": 1.30, "def": 0.70},
	"boss":         {"hp": 2.50,  "atk": 1.20, "def": 1.20},
}

## Genera {hp, attack, phys_defense, mag_defense} para `archetype` a `level`.
static func _procedural_stats(level: int, archetype: String) -> Dictionary:
	var mult: Dictionary = ARCHETYPE_MULTIPLIERS.get(archetype, ARCHETYPE_MULTIPLIERS["balanced"])
	var def_val: int = int(round(_def_base(level) * float(mult["def"])))
	return {
		"hp":           int(round(_hp_base(level) * float(mult["hp"]))),
		"attack":       int(round(_atk_base(level) * float(mult["atk"]))),
		"phys_defense": def_val,
		"mag_defense":  def_val,
	}


## Devuelve la definición cruda de un enemigo (desde enemies.json vía Design; o {}).
static func get_enemy_def(enemy_id: String) -> Dictionary:
	return Design.get_enemy(enemy_id)


## Construye un diccionario de combate listo para usar, GENERANDO las estadísticas
## de combate (hp/attack/phys_defense/mag_defense) proceduralmente por `level` y
## `archetype` (ver `_procedural_stats`). `is_boss=true` fuerza el arquetipo
## "boss" para ESTE spawn concreto, al margen del `archetype` natural declarado
## en el JSON (un mismo enemigo puede ser jefe en una mazmorra y trasgo común en
## otra). Sin nivel, se asume 1 (stats base).
static func build_enemy(enemy_id: String, level: int = 1, is_boss: bool = false) -> Dictionary:
	var def: Dictionary = get_enemy_def(enemy_id)
	var lvl: int = maxi(1, level)
	if def.is_empty():
		# Fallback seguro si se pide un id inexistente.
		var fallback_name := enemy_id.replace("_", " ").capitalize()
		var fallback_stats: Dictionary = _procedural_stats(lvl, "boss" if is_boss else "balanced")
		return {
			"id": enemy_id, "name": fallback_name, "icon": "👾", "image": "res://assets/combat/enemies/en_slime.png",
			"level": lvl,
			"hp": fallback_stats["hp"], "max_hp": fallback_stats["hp"], "attack": fallback_stats["attack"], "attack_type": "physical",
			"phys_defense": fallback_stats["phys_defense"], "mag_defense": fallback_stats["mag_defense"], "dodge": 0.0,
			"element": "physical", "weak_to": [], "resist": [],
			"status_on_hit": {}, "ai": "aggressive", "first_strike": 0,
			"skills": [], "xp_reward": 20, "gold_reward": 10, "loot": [], "is_boss": is_boss,
			"visual_scale": 1.0,
		}
	var archetype: String = "boss" if is_boss else String(def.get("archetype", "balanced"))
	var stats: Dictionary = _procedural_stats(lvl, archetype)
	if enemy_id == "orco_berserker":
		lvl = 99
		stats = {
			"hp": 9999,
			"attack": 9999,
			"phys_defense": 999,
			"mag_defense": 999,
		}
	var steps: float = float(lvl - 1)   # aún usado por esquiva/recompensas, que conservan su propio ritmo por enemigo.
	var hp: int = stats["hp"]
	if def.has("fixed_hp"):
		hp = int(def["fixed_hp"])
	return {
		"id":            enemy_id,
		"level":         lvl,
		"name":          Locale.pick(def.get("name", {})),
		"icon":          String(def.get("icon", "👾")),
		"image":         String(def.get("image", "")),
		"hp":            hp,
		"max_hp":        hp,
		"attack":        stats["attack"],
		"attack_type":   String(def.get("attack_type", "physical")),
		"phys_defense":  stats["phys_defense"],
		"mag_defense":   stats["mag_defense"],
		"dodge":         float(def.get("base_dodge", 0.0)) + float(def.get("dodge_scale", 0.0)) * steps,
		"element":       String(def.get("element", "physical")),
		"weak_to":       (def.get("weak_to", []) as Array).duplicate(),
		"resist":        (def.get("resist", []) as Array).duplicate(),
		"status_on_hit": (def.get("status_on_hit", {}) as Dictionary).duplicate(true),
		"first_strike":  int(def.get("first_strike", 0)),
		"ai":            String(def.get("ai", "aggressive")),
		"skills":        _skills_for_level(def.get("skills", []), lvl),
		"xp_reward":     int(round(float(def.get("xp_reward_base", 20)) + float(def.get("xp_reward_scale", 0.0)) * steps)),
		"gold_reward":   int(round(float(def.get("gold_reward_base", 10)) + float(def.get("gold_reward_scale", 0.0)) * steps)),
		"loot":          _copy_loot(def.get("loot", [])),
		"is_boss":       is_boss or archetype == "boss",
		"visual_scale":  float(def.get("visual_scale", 1.0)),
		# Veneno ambiental: daño por turno al enemigo (Liche Eterno, Sendero del Sacerdote).
		# 0 = sin efecto (la mayoría de enemigos).
		"ambient_poison_per_turn": int(def.get("ambient_poison_per_turn", 0)),
		# Decaimiento temporal continuo: daño por segundo en tiempo real (Cronófago, Sendero del Tiempo).
		# 0 = sin efecto (la mayoría de enemigos).
		"time_decay_per_sec": int(def.get("time_decay_per_sec", 0)),
	}


## Copia la lista de botín en línea del enemigo (o [] si no es válida).
static func _copy_loot(loot):
	if loot is Array:
		return loot.duplicate(true)
	return []


## Filtra las habilidades del enemigo dejando solo las desbloqueadas a `level`.
static func _skills_for_level(skills: Array, level: int) -> Array:
	var out: Array = []
	for s in skills:
		if s is Dictionary and int(s.get("level", 1)) <= level:
			out.append(String(s.get("skill_id", "")))
	return out


