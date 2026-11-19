# EquipmentResource.gd
# Recurso personalizado para definir armas, armaduras y accesorios del héroe.
# Permite crear nuevos equipos desde el editor: clic derecho -> Nuevo Recurso -> EquipmentResource
class_name EquipmentResource
extends Resource

@export var id: String = ""
@export var name: String = "Espada de Acero"
@export var icon: String = "🗡️"
@export_enum("helmet", "weapon", "shield", "armor", "shoes", "accessory") var slot: String = "weapon"

# ─── BOTÍN / RAREZA  (solo para equipo soltado o forjado, vacío para equipo fijo) ──
# base_id = plantilla de GameConfig.LOOT_EQUIPMENT de la que deriva (para re-forjar).
# rarity  = clave de GameConfig.RARITIES ("common"…"legendary"); "" = sin rareza.
@export var base_id: String = ""
@export var rarity: String = ""

## Nivel de REFINAMIENTO (+0 a GameConfig.REFINE_MAX_LEVEL) — ver task5.md /
## RefineManager. `stat_bonuses`/los campos de combate de abajo son SIEMPRE el
## valor BASE (sin refinar); el multiplicador se aplica al leerlos mediante
## `effective_stat_bonus`/`effective_combat`, nunca mutando estos campos en sí.
@export var refine_level: int = 0

# Bonus de estadísticas que otorga al equiparse
# Ejemplo: {"str": 5, "vit": 2}
@export var stat_bonuses: Dictionary = {
	"str": 0,
	"agi": 0,
	"vit": 0,
	"int": 0,
	"dex": 0,
	"luk": 0
}

# ─────────────────────────────────────────────────────────────────────────────
# BONUS DE COMBATE DIRECTO  (se SUMAN a las estadísticas finales del héroe)
#   Las armas suelen aportar daño; las armaduras/escudos, defensa. Un objeto puede
#   aportar varias cosas a la vez según su naturaleza.
# ─────────────────────────────────────────────────────────────────────────────
@export var phys_damage: int  = 0   # Daño físico (espadas, mazas…)
@export var mag_damage: int   = 0   # Daño mágico (báculos, varitas…)
@export var range_damage: int = 0   # Daño a distancia (arcos, ballestas…)
@export var phys_defense: int = 0   # Defensa física (armaduras, escudos…)
@export var mag_defense: int  = 0   # Defensa mágica (túnicas, amuletos…)

# Elemento y cualidades pasivas especiales (con requisito de refinamiento opcional)
@export var element: String = ""
@export var traits: Array = []

## Devuelve la lista de cualidades actualmente ACTIVAS según el nivel de refinamiento actual.
func active_traits() -> Array:
	var out: Array = []
	for t in traits:
		if t is Dictionary:
			var min_ref: int = int(t.get("min_refine", 0))
			if refine_level >= min_ref:
				out.append(t)
	return out

## Devuelve el bonus de combate de un campo por su nombre (helper de serialización).
func get_combat(field: String) -> int:
	match field:
		"phys_damage":  return phys_damage
		"mag_damage":   return mag_damage
		"range_damage": return range_damage
		"phys_defense": return phys_defense
		"mag_defense":  return mag_defense
		_:              return 0

## Multiplicador de eficacia por refinamiento (+10%/nivel; +10 = +100% = el doble).
func refine_multiplier() -> float:
	return 1.0 + float(refine_level) * GameConfig.REFINE_BONUS_PER_LEVEL

## Bonus de característica EFECTIVO (base * refine_multiplier), redondeado.
func effective_stat_bonus(stat_name: String) -> int:
	return int(round(float(stat_bonuses.get(stat_name, 0)) * refine_multiplier()))

## Bonus de combate EFECTIVO (base * refine_multiplier), redondeado.
func effective_combat(field: String) -> int:
	return int(round(float(get_combat(field)) * refine_multiplier()))
