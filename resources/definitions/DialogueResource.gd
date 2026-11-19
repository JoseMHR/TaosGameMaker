# DialogueResource.gd
# Recurso personalizado para diseñar diálogos estilo Novela Visual.
# Permite crear nuevos diálogos desde el editor: clic derecho -> Nuevo Recurso -> DialogueResource
class_name DialogueResource
extends Resource

@export var npc_name: String = "Grog"
@export var npc_avatar: String = "🧔"
@export var dialogue_text: String = "Hola, viajero..."

# Array de diccionarios para las decisiones de diálogo.
# Formato de cada entrada:
# {
#   "text": "Texto de la opción",
#   "action": "id_accion",
#   "req_facet": "valentia",  <- Faceta requerida (opcional)
#   "req_val": 2              <- Valor mínimo de faceta (opcional)
# }
@export var choices: Array[Dictionary] = []
