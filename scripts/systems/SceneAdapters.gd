# SceneAdapters.gd
# ─────────────────────────────────────────────────────────────────────────────
# ADAPTADORES DEL SISTEMA NARRATIVO.
#
# Convierte el contenido narrativo LEGADO (diálogos sueltos y grafos de NPC) en
# el formato unificado de ESCENA que interpreta el SceneRunner, SIN
# necesidad de reescribir ni duplicar los datos en scenes.json. Así todo el juego
# pasa a usar UN solo motor narrativo mientras el contenido antiguo sigue vivo.
#
# Todas las funciones son PURAS y estáticas: reciben datos y devuelven un
# Dictionary { entry, nodes:{...} } listo para SceneRunner.start_built_scene().
#
# Mapeos:
#   · dialogues.json (say + choices con `action`) → say → choice → state(qaction).
#   · npcs.json (grafo message/option con reward)   → say/choice/state.
# ─────────────────────────────────────────────────────────────────────────────
class_name SceneAdapters
extends RefCounted


# ══════════════════════════════════════════════════════════════════════════════
# DIÁLOGO SUELTO (dialogues.json)
# ══════════════════════════════════════════════════════════════════════════════
# Formato origen: { npc_name{es,en}, npc_avatar, text{es,en}, choices:[{text{es,en}, action}] }
# Se construye: un nodo `say` con el texto y, si hay opciones, un `choice` cuyas
# ramas ejecutan la `action` a través del mini-lenguaje (token `qaction:`), que
# reenvía a QuestManager.handle_choice (data-first: events.json → cableado).
static func dialogue_to_scene(d: Dictionary) -> Dictionary:
	var nodes: Dictionary = {}
	var speaker = d.get("npc_name", "")
	var portrait := String(d.get("npc_avatar", ""))
	var choices = d.get("choices", [])

	if not (choices is Array) or (choices as Array).is_empty():
		# Diálogo de una sola línea: say → end.
		nodes["say"] = {
			"kind": "say", "speaker": speaker, "portrait": portrait,
			"text": d.get("text", ""), "next": "end",
		}
		nodes["end"] = {"kind": "flow", "op": "end"}
		return {"entry": "say", "nodes": nodes}

	# say (línea) → choice (opciones) → una rama por opción que aplica su acción.
	nodes["say"] = {
		"kind": "say", "speaker": speaker, "portrait": portrait,
		"text": d.get("text", ""), "next": "ask",
	}
	var options: Array = []
	for i in (choices as Array).size():
		var c = choices[i]
		if not (c is Dictionary):
			continue
		var action := String(c.get("action", "dismiss"))
		var opt_node := "opt_%d" % i
		options.append({"text": c.get("text", ""), "to": opt_node})
		if action == "" or action == "dismiss":
			nodes[opt_node] = {"kind": "flow", "op": "end"}
		else:
			# La acción se ejecuta como token `qaction:<action>` (reutiliza el
			# despachador existente: events.json primero, luego cableado).
			nodes[opt_node] = {"kind": "state", "ops": "qaction:" + action, "next": "end"}
	nodes["ask"] = {"kind": "choice", "options": options}
	nodes["end"] = {"kind": "flow", "op": "end"}
	return {"entry": "say", "nodes": nodes}


# ══════════════════════════════════════════════════════════════════════════════
# OBJETO INTERACTIVO DEL MAPA (cartel / lápida / libro / monumento / estatua)
# ══════════════════════════════════════════════════════════════════════════════
# Formato origen (inline en la casilla): { kind?, icon, title{es,en}, text{es,en} }.
# Se construye una escena de UN nodo `say` que muestra el icono + título como
# hablante y el texto como cuerpo. Unifica los "Objetos Interactivos" de la tarea
# (carteles, libros, lápidas...) con el mismo motor narrativo.
static func interactive_to_scene(info: Dictionary) -> Dictionary:
	var icon := String(info.get("icon", "🪧"))
	var title = info.get("title", {"es": "Cartel", "en": "Sign", "fr": "Panneau", "it": "Cartello", "de": "Schild", "zh": "告示牌", "ja": "看板"})
	# El hablante se compone del icono + título para reaprovechar el retrato/nombre.
	var nodes := {
		"say": {
			"kind": "say",
			"portrait": icon,
			"speaker": title,
			"text": info.get("text", ""),
			"fx": {"sfx": "click"},
			"next": "end",
		},
		"end": {"kind": "flow", "op": "end"},
	}
	return {"entry": "say", "nodes": nodes}


# ══════════════════════════════════════════════════════════════════════════════
# GRAFO DE NPC (npcs.json)
# ══════════════════════════════════════════════════════════════════════════════
# Formato origen: nodos { type: meta|message|option, text{es,en}, next:[ids],
# reward:"mini-lenguaje", condition:"Expression" }. El `_meta` define nombre y
# avatar del NPC.
#
# Mapeo al grafo unificado (conservando ids de nodo originales):
#   · message → `say` (speaker/portrait del _meta, text). Su continuación:
#       - si tiene hijos `option` visibles → un `choice` sintético "<id>__ask".
#       - si tiene una continuación `message` → say.next a ese id.
#       - si no → end.
#   · option  → `state` que aplica su `reward` y salta a su primer `next`
#               (message de respuesta) o a end. El `choice` referencia estas
#               opciones con su condición para el filtrado en vivo.
#
# La entrada se calcula igual que el motor actual (primer message no referenciado
# cuya condición se cumpla), delegando en Design.entry_node.
static func npc_to_scene(npc_id: String) -> Dictionary:
	var graph: Dictionary = Design.get_npc(npc_id)
	if graph.is_empty():
		return {}
	var meta := Design.npc_meta(npc_id)
	var speaker = meta.get("name", "")
	var portrait := String(meta.get("avatar", ""))

	# Mapa answer_message -> ask del menú del que cuelga la opción que lleva a él.
	# Sirve para que, tras leer la respuesta de una pregunta, la conversación
	# VUELVA al menú en vez de cerrarse: solo la opción "Despedirse" (que va
	# directa a `close`) debe salir de la conversación.
	var answer_to_menu := _build_answer_to_menu_map(graph)

	var nodes: Dictionary = {}
	for nid in graph.keys():
		if nid == "_meta":
			continue
		var src: Dictionary = graph[nid]
		var ntype := String(src.get("type", ""))
		var nexts: Array = src.get("next", []) if src.get("next") is Array else []
		if ntype == "message" or ntype == "entry" or ntype == "event":
			# Reunir hijos que son opciones (para un choice) y la continuación.
			var option_children: Array = []
			var continue_to := ""
			for nx in nexts:
				var nxs := String(nx)
				if nxs == "close" or nxs == "":
					continue_to = "end"
					continue
				var child = graph.get(nxs, {})
				if child is Dictionary and (String(child.get("type", "")) == "option" or String(child.get("type", "")) == "choice"):
					option_children.append(nxs)
				elif continue_to == "":
					continue_to = nxs
			var say_node := {
				"kind": "say", "speaker": speaker, "portrait": portrait,
				"text": src.get("text", ""),
			}
			if not option_children.is_empty():
				# Nodo choice sintético que enlaza a las opciones (con su condición).
				var ask_id: String = nid + "__ask"
				var options: Array = []
				for oid in option_children:
					var ochild: Dictionary = graph.get(oid, {})
					options.append({
						"text": ochild.get("text", ""),
						"condition": String(ochild.get("condition", "")),
						"once": bool(ochild.get("once", false)),
						"to": oid,
					})
				nodes[ask_id] = {"kind": "choice", "options": options}
				say_node["next"] = ask_id
			elif continue_to == "" or continue_to == "end":
				# Mensaje-hoja: si es la RESPUESTA a una pregunta de un menú, en vez
				# de cerrar la conversación se vuelve al menú de origen.
				say_node["next"] = answer_to_menu.get(nid, "end")
			else:
				say_node["next"] = continue_to
			# Un "message" también puede llevar recompensa propia (p. ej. el mensaje
			# final de un entrenador que concede "gflag:apprentice_sendero_X"). Antes
			# se ignoraba (solo se aplicaba la de los "option"), por lo que esas
			# recompensas nunca se otorgaban. Se intercala un nodo "state" que la
			# aplica justo antes de continuar hacia el destino original.
			var msg_reward := String(src.get("reward", ""))
			if msg_reward != "":
				var reward_id: String = nid + "__reward"
				nodes[reward_id] = {"kind": "state", "ops": msg_reward, "next": say_node["next"]}
				say_node["next"] = reward_id
			nodes[nid] = say_node
		elif ntype == "option" or ntype == "choice":
			# La opción aplica su recompensa y continúa a su primer destino válido según condición.
			var to := "end"
			for nx in nexts:
				var nxs := String(nx)
				if nxs != "close" and nxs != "":
					var target_node: Dictionary = graph.get(nxs, {})
					var cond := String(target_node.get("condition", ""))
					if cond == "" or cond == "default" or Design.eval_condition(cond, npc_id):
						to = nxs
						break
			var reward := String(src.get("reward", ""))
			if reward == "":
				nodes[nid] = {"kind": "flow", "op": "goto", "to": to}
			else:
				nodes[nid] = {"kind": "state", "ops": reward, "next": to}
	nodes["reload_npc"] = {"kind": "flow", "op": "reload_npc", "npc_id": npc_id}
	nodes["end"] = {"kind": "flow", "op": "end"}
	return {"entry": Design.entry_node(npc_id), "nodes": nodes}


## Recorre el grafo de un NPC y devuelve un mapa `answer_id -> "<menu>__ask"` o `"reload_npc"`:
## por cada MENÚ (message con opciones hijas):
##   · Preguntas normales: tras la respuesta se REGRESA al menú (`ask_id`) para seguir preguntando.
##   · Entrega de quests / cambios de estado: tras la respuesta se salta a `reload_npc` para reevaluar
##     el punto de entrada del NPC con el nuevo estado (eliminando la opción entregada sin echar al jugador).
static func _build_answer_to_menu_map(graph: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for mid in graph.keys():
		if mid == "_meta":
			continue
		var msg = graph[mid]
		if not (msg is Dictionary) or String(msg.get("type", "")) != "message":
			continue
		var msg_nexts: Array = msg.get("next", []) if msg.get("next") is Array else []
		# ¿Es un menú? (tiene al menos una opción hija).
		var has_options := false
		for nx in msg_nexts:
			var child = graph.get(String(nx), {})
			if child is Dictionary and String(child.get("type", "")) == "option":
				has_options = true
				break
		if not has_options:
			continue
		var ask_id: String = mid + "__ask"
		# Para cada opción del menú, localizar el mensaje de respuesta al que lleva.
		for nx in msg_nexts:
			var opt = graph.get(String(nx), {})
			if not (opt is Dictionary) or String(opt.get("type", "")) != "option":
				continue
			var opt_nexts: Array = opt.get("next", []) if opt.get("next") is Array else []
			for onx in opt_nexts:
				var onxs := String(onx)
				if onxs == "close" or onxs == "" or onxs == "end":
					continue   # opción de salida directa (ej. "Despedirse"): debe cerrar
				var ans = graph.get(onxs, {})
				if ans is Dictionary and String(ans.get("type", "")) == "message":
					var ans_nexts: Array = ans.get("next", []) if ans.get("next") is Array else []
					# Si el mensaje de destino especifica explícitamente "close", es una despedida/cierre: no reenganchar al menú
					if ans_nexts.has("close"):
						continue
					# Señal EXPLÍCITA y única (ya no se adivina por el contenido del
					# `reward`): una opción marcada "once" cambia estado relevante para
					# el grafo (entrega de quest/objeto/flag) y debe recargar el NPC
					# desde su punto de entrada para que las condiciones se reevalúen
					# de raíz. Sin "once", es informativa y solo vuelve al menú.
					var is_once := bool(opt.get("once", false))
					if is_once:
						out[onxs] = "reload_npc"
					else:
						out[onxs] = ask_id
				break
	return out


## Convierte un encuentro en un POI resuelto (con su fondo, música y actor dinámico)
## en una escena lista para SceneRunner.
static func poi_to_scene(poi_id: String) -> Dictionary:
	var enc := Design.resolve_poi_encounter(poi_id)
	if enc.get("is_empty", false):
		return {
			"meta": { "title": enc.get("name", {}), "bg": enc.get("bg", ""), "music": enc.get("music", "") },
			"entry": "say",
			"nodes": {
				"say": {
					"kind": "say", "speaker": enc.get("name", {}), "portrait": "",
					"text": { "es": "No hay nadie aquí en este momento...", "en": "There is no one here right now...", "fr": "Il n'y a personne ici pour le moment...", "it": "Non c'è nessuno qui in questo momento...", "de": "Hier ist gerade niemand...", "zh": "现在这里没有人……", "ja": "今はここに誰もいない……" },
					"next": "end"
				},
				"end": { "kind": "flow", "op": "end" }
			}
		}

	var actor_id := String(enc.get("actor", ""))
	var sc := npc_to_scene(actor_id)
	if not sc.has("meta"):
		sc["meta"] = {}
	sc["meta"]["bg"] = enc.get("bg", "")
	sc["meta"]["music"] = enc.get("music", "")
	sc["meta"]["title"] = enc.get("name", {})
	if enc.get("entry_node", "") != "":
		sc["entry"] = enc.get("entry_node")
	return sc


# ══════════════════════════════════════════════════════════════════════════════
# CINEMÁTICA / CARRUSEL DE DIAPOSITIVAS (data/cinematics/<id>.json)
# ══════════════════════════════════════════════════════════════════════════════
# Formato origen:
# {
#   "id": "...", "title": {...}, "desc": "...", "music": "...",
#   "slides": [
#     { "bg": "...", "speaker": {...}, "portrait": "...", "text": {...}, "fx": {...} }, ...
#   ],
#   "on_finish": "end" | "credits",
#   "ops": "..."
# }
# Se construye: una secuencia lineal de nodos `say` encadenados por `next`,
# donde cada nodo tiene su fondo `bg`, texto multilingüe y retrato, seguido
# del nodo de cierre (`end` o `credits`, ejecutando `ops` si existen).
static func cinematic_to_scene(c: Dictionary) -> Dictionary:
	var raw_slides = c.get("slides", [])
	var slides: Array = raw_slides if raw_slides is Array else []
	if slides.is_empty():
		return {
			"meta": { "title": c.get("title", {}), "music": c.get("music", "") },
			"entry": "end",
			"nodes": { "end": { "kind": "flow", "op": "end" } }
		}

	var nodes: Dictionary = {}
	var title = c.get("title", {})
	var on_finish := String(c.get("on_finish", "end")).to_lower()
	var ops := String(c.get("ops", "")).strip_edges()

	for i in range(slides.size()):
		var slide: Dictionary = slides[i] if slides[i] is Dictionary else {}
		var node_id := "slide_%d" % (i + 1)
		var next_id := ("slide_%d" % (i + 2)) if (i < slides.size() - 1) else "finish"

		var speaker = slide.get("speaker", title)
		var portrait := String(slide.get("portrait", ""))
		var text = slide.get("text", "")
		var bg := String(slide.get("bg", ""))
		var fx: Dictionary = slide.get("fx", {}) if slide.get("fx") is Dictionary else {}

		var say_node: Dictionary = {
			"kind": "say",
			"speaker": speaker,
			"portrait": portrait,
			"text": text,
			"next": next_id,
		}
		if bg != "":
			say_node["bg"] = bg
		if not fx.is_empty():
			say_node["fx"] = fx

		nodes[node_id] = say_node

	var flow_op := "credits" if (on_finish == "credits" or c.get("roll_credits", false) == true) else "end"
	if ops != "":
		nodes["finish"] = {
			"kind": "state",
			"ops": ops,
			"next": "finish_flow"
		}
		nodes["finish_flow"] = {
			"kind": "flow",
			"op": flow_op
		}
	else:
		nodes["finish"] = {
			"kind": "flow",
			"op": flow_op
		}

	var meta: Dictionary = {
		"title": title,
		"music": c.get("music", ""),
		"desc": c.get("desc", "")
	}

	return {
		"meta": meta,
		"entry": "slide_1",
		"nodes": nodes
	}

