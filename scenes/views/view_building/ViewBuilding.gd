# ViewBuilding.gd
# Hereda de ViewPlace (renderizador unificado de Novela Visual / POI).
# Mantiene la clase por compatibilidad, retornando por defecto a la vista de ciudad.
class_name ViewBuilding
extends ViewPlace

func setup(data_or_id, return_target: String = "city") -> void:
	super.setup(data_or_id, return_target)
