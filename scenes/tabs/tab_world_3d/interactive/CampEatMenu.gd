# CampEatMenu.gd
# ─────────────────────────────────────────────────────────────────────────────
# Menú "Comer" del campamento: lista los comestibles de la bolsa y, al elegir
# uno, muestra una previsualización (barras vida/maná antes→después) antes de
# confirmar. Se abre desde CampTentSystem.open_camp_menu().
#
# Extraído de TabWorld3D.gd (antes en el #region "OBJETOS INTERACTIVOS" de un
# único fichero de ~5300 líneas). A diferencia de las maquetas de buildings/
# (sin coupling), este menú SÍ necesita volver a llamar a TabWorld3D para un
# par de cosas (UiKit.overlay(world), world._spawn_world_float(...)): por eso
# cada función recibe `world: Node` explícito como primer parámetro en
# vez de depender de un `self` implícito.
# ─────────────────────────────────────────────────────────────────────────────
class_name CampEatMenu
extends RefCounted


## Abre el menú de Comer: lista los comestibles de la bolsa; al elegir uno se muestra
## una previsualización (barras vida/maná antes→después) antes de confirmar.
static func open_eat_menu(world: Node) -> void:
	var root: Control = UiKit.overlay(world)
	var bg := root.get_child(0) as ColorRect
	if bg != null:
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		bg.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				root.queue_free())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 20, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var margin := UiKit.margins(28, 28, 24, 24)
	margin.add_child(content)
	panel.add_child(margin)
	_render_eat_list(world, root, content)


## Pinta la LISTA de comestibles disponibles dentro del contenedor dado.
static func _render_eat_list(world: Node, root: Control, content: VBoxContainer) -> void:
	for c in content.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = Locale.pick({"es": "🍽️ Comer", "en": "🍽️ Eat"})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	content.add_child(title)

	var foods: Array = []
	for item in GlobalState.inventory:
		if String(item.get("category", "")) == "edible" and int(item.get("quantity", 0)) > 0:
			foods.append(item)

	if foods.is_empty():
		var empty := Label.new()
		empty.text = Locale.pick({"es": "No tienes nada de comer.", "en": "You have no food."})
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 19)
		empty.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		content.add_child(empty)
	else:
		for item in foods:
			content.add_child(_make_food_card(world, root, content, item))

	var close := Button.new()
	close.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	close.custom_minimum_size = Vector2(0, 50)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void: root.queue_free())
	content.add_child(close)


## Tarjeta de un alimento en la lista (icono, nombre xN, recuperación). Al tocarla
## abre la previsualización de ese alimento.
static func _make_food_card(world: Node, root: Control, content: VBoxContainer, item: Dictionary) -> Control:
	var id: String = String(item.get("id", ""))
	var v: Dictionary = GlobalState.food_restore_values(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.ACCENT))
	card.add_theme_color_override("font_color", UiKit.TEXT)
	card.text = "%s  %s  x%d      ❤️+%d   💧+%d" % [
		String(item.get("icon", "🍖")), String(item.get("name", id)),
		int(item.get("quantity", 1)), int(v["hp"]), int(v["mp"])]
	card.pressed.connect(func() -> void: _render_eat_preview(world, root, content, id))
	return card


## Pinta la PREVISUALIZACIÓN de comer `id`: barras vida/maná (actual + proyectado
## en tono claro) y botones Volver / Comer / Cerrar.
static func _render_eat_preview(world: Node, root: Control, content: VBoxContainer, id: String) -> void:
	for c in content.get_children():
		c.queue_free()
	var pv: Dictionary = GlobalState.food_preview(id)
	var def_name: String = Design.get_item_name(id)
	var current_qty: int = int(GlobalState.get_item(id).get("quantity", 0))

	var title := Label.new()
	title.text = "%s %s  (x%d)" % [Design.get_item_icon(id), def_name, current_qty]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	content.add_child(title)

	content.add_child(_make_preview_row(
		Locale.pick({"es": "Vida", "en": "Health"}),
		int(pv["hp_now"]), int(pv["hp_after"]), int(pv["max_hp"]),
		UiKit.HP, Color(1.0, 0.55, 0.55)))
	content.add_child(_make_preview_row(
		Locale.pick({"es": "Maná", "en": "Mana"}),
		int(pv["mp_now"]), int(pv["mp_after"]), int(pv["max_mp"]),
		UiKit.MP, Color(0.6, 0.82, 1.0)))

	var hint := Label.new()
	hint.text = Locale.pick({"es": "Comer hace pasar 1 hora.", "en": "Eating takes 1 hour."})
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	content.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)

	var back := Button.new()
	back.text = Locale.pick({"es": "← Volver", "en": "← Back"})
	back.custom_minimum_size = Vector2(140, 56)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: _render_eat_list(world, root, content))
	row.add_child(back)

	var can_recover: bool = int(pv["hp_after"]) > int(pv["hp_now"]) or int(pv["mp_after"]) > int(pv["mp_now"])
	var eat := Button.new()
	eat.custom_minimum_size = Vector2(210, 56)
	eat.add_theme_font_size_override("font_size", 20)

	if not can_recover:
		eat.text = Locale.pick({"es": "¡Saciado!", "en": "Full!"})
		eat.disabled = true
	elif current_qty <= 0:
		eat.text = Locale.pick({"es": "Agotado", "en": "Depleted"})
		eat.disabled = true
	else:
		eat.text = Locale.pick({"es": "🍽️ Comer", "en": "🍽️ Eat"})
		eat.disabled = false
		for st in ["normal", "hover", "pressed", "focus"]:
			eat.add_theme_stylebox_override(st, UiKit.button_primary(12))
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			eat.add_theme_color_override(col, UiKit.BG_DEEP)
		eat.pressed.connect(func() -> void: _do_eat(world, id, root, content))

	row.add_child(eat)

	var close := Button.new()
	close.text = Locale.pick({"es": "Cerrar", "en": "Close"})
	close.custom_minimum_size = Vector2(130, 56)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void: root.queue_free())
	row.add_child(close)


## Fila de previsualización de una estadística: etiqueta + barra apilada donde el
## relleno CLARO muestra el total proyectado y el SÓLIDO el valor actual.
static func _make_preview_row(label_text: String, now: int, after: int, max_v: int, solid: Color, light: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = "%s   %d → %d / %d" % [label_text, now, after, max_v]
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", UiKit.TEXT)
	box.add_child(lbl)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 30)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(holder)

	# Capa 1 (fondo + relleno CLARO = valor proyectado tras comer).
	var after_bar := ProgressBar.new()
	after_bar.show_percentage = false
	after_bar.max_value = maxf(1.0, float(max_v))
	after_bar.value = float(after)
	after_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiKit.BG_DEEP
	bg.set_corner_radius_all(10)
	bg.set_border_width_all(1)
	bg.border_color = UiKit.BORDER
	after_bar.add_theme_stylebox_override("background", bg)
	after_bar.add_theme_stylebox_override("fill", UiKit.bar_fill(light, 10))
	holder.add_child(after_bar)

	# Capa 2 (relleno SÓLIDO = valor actual), con fondo transparente para ver la 1.
	var now_bar := ProgressBar.new()
	now_bar.show_percentage = false
	now_bar.max_value = maxf(1.0, float(max_v))
	now_bar.value = float(now)
	now_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	now_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	now_bar.add_theme_stylebox_override("fill", UiKit.bar_fill(solid, 10))
	holder.add_child(now_bar)
	return box


## Ejecuta la acción de comer: aplica la recuperación, hace pasar 1 hora, da feedback
## y mantiene el menú abierto para permitir comer varias veces consecutivas.
static func _do_eat(world: Node, id: String, root: Control, content: VBoxContainer) -> void:
	var res: Dictionary = GlobalState.eat_food(id)
	if res.is_empty():
		UiKit.toast(root if is_instance_valid(root) else world, Locale.pick({"es": "No puedes comer más.", "en": "You can't eat more."}), UiKit.HP)
		return
	# Comer hace pasar 1 hora dentro del juego (spec).
	TimeManager.advance_hours(1.0)
	var parts: Array[String] = []
	if int(res.get("hp", 0)) > 0:
		parts.append("❤️+%d" % int(res["hp"]))
	if int(res.get("mp", 0)) > 0:
		parts.append("💧+%d" % int(res["mp"]))
	var feedback_text: String = "  ".join(parts)
	world._spawn_world_float(feedback_text, UiKit.GOOD)
	UiKit.toast(root if is_instance_valid(root) else world, feedback_text, UiKit.GOOD)
	SaveManager.request_autosave()

	# Mantener la ventana abierta: si aún quedan unidades de este alimento, refrescar la vista previa;
	# si se agotaron las unidades, volver al listado general de alimentos.
	var remaining_qty: int = int(GlobalState.get_item(id).get("quantity", 0))
	if remaining_qty > 0:
		_render_eat_preview(world, root, content, id)
	else:
		_render_eat_list(world, root, content)
