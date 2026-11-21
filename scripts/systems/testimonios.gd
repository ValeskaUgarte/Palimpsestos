extends Area2D
## MESA DE LOS TESTIMONIOS (escena 1): PUZLE DE PISTAS.
##
## Los vecinos dijeron cuatro cosas en el pueblo. En la mesa, cada testimonio tiene un hueco.
## Elliot arrastra del diario el hallazgo que lo confirma y lo suelta en el hueco.
## Si no encaja, la pieza vuelve a la bandeja y el hueco te dice por qué no. Con el mando: A elige la pieza
## y la coloca en su hueco correcto. Al completar los cuatro huecos la mesa se resuelve:
## se abre la salida hacia la escena 2 y se activa el portal.

const FLAG_SOLVED := "mesa_escena1"

## Cada testimonio, el hallazgo que lo prueba y lo que se entiende al encajarlo.
const CLAIMS := [
	{"who": "Mamá", "text": "«La niña nunca se aparta del camino.»", "evidence": "flores",
		"why": "Las flores cortadas están al lado del sendero: se apartó."},
	{"who": "Vecina", "text": "«Solo oí pájaros cantando cerca del claro.»", "evidence": "pluma",
		"why": "Donde cantan los pájaros, queda una pluma."},
	{"who": "Anciano", "text": "«Algo grande cruzó el sendero después de ella.»", "evidence": "huella",
		"why": "Una huella con garras, sobre otras más pequeñas."},
	{"who": "Guardia", "text": "«Salió con la cesta llena: pastel, como cada semana.»", "evidence": "pastel",
		"why": "Un pastel tirado en el barro: la cesta no llegó entera."},
]

@export var exit_path: NodePath = ^"../ChapterExit"
@export var portal_path: NodePath = ^"../StoryPortal"
@export var table_texture: Texture2D = preload("res://assets/ui/pack_gotico/mesa.png")
@export var table_width: float = 300.0

var _solved: bool = false
var _near: bool = false
var _layer: CanvasLayer = null
var _slots: Array = []     # {"holder": Panel, "label": Label, "locked": bool}
var _tray: HFlowContainer = null
var _feedback: Label = null
var _locked_count: int = 0
var _selected: RiddleStone = null
var _last_whisper: int = -10000


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 130.0
		shape.shape = circle
		add_child(shape)
	collision_layer = 0
	collision_mask = 2
	var exit := get_node_or_null(exit_path)
	if GameSession.has_flag(FLAG_SOLVED):
		_solved = true
		if exit != null:
			exit.set_deferred("monitoring", true)
		_activate_portal.call_deferred()
	elif exit != null:
		exit.set_deferred("monitoring", false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true
		_say("La mesa del pueblo. E para ordenar las pruebas." if not _solved else "La mesa ya está resuelta. El camino sigue hacia la casa.")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false


func _unhandled_input(event: InputEvent) -> void:
	if _solved or not _near or _layer != null:
		return
	if DialogueManager.visible or ScenePages.busy or get_tree().paused:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_try_open()


func _try_open() -> void:
	var missing: Array = []
	for claim in CLAIMS:
		if GameSession.item_count(claim["evidence"]) <= 0:
			missing.append(StoryItems.info(claim["evidence"])["name"])
	if not missing.is_empty():
		DialogueManager.show_dialogue([
			"Elliot: Todavía no tengo pruebas para todos los testimonios.",
			"Elliot: Me falta: %s." % ", ".join(missing),
		], "Elliot")
		return
	_open_panel()


func _open_panel() -> void:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 80
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.11, 0.1, 0.97), Color(0.55, 0.47, 0.33)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(800, 0)
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(_label("Lo que dijeron los vecinos", 28, Color(0.96, 0.88, 0.68)))
	column.add_child(_label("Arrastra cada hallazgo de tu diario al testimonio que lo confirma.", 15, Color(0.85, 0.82, 0.74)))

	_slots = []
	_locked_count = 0
	for index in CLAIMS.size():
		var claim: Dictionary = CLAIMS[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		column.add_child(row)
		var text := _label("%s: %s" % [claim["who"], claim["text"]], 17, Color(0.9, 0.86, 0.78))
		text.custom_minimum_size = Vector2(440, 0)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(text)
		var holder := Panel.new()
		holder.custom_minimum_size = Vector2(300, 84)
		holder.focus_mode = Control.FOCUS_ALL
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.gui_input.connect(_on_slot_input.bind(index))
		holder.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.05, 0.9), Color(0.7, 0.58, 0.35)))
		row.add_child(holder)
		var hint := _label("arrastra aquí", 15, Color(0.55, 0.5, 0.42))
		hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(hint)
		_slots.append({"holder": holder, "label": hint, "locked": false})

	column.add_child(_label("Tu diario", 18, Color(0.85, 0.8, 0.7)))
	_tray = HFlowContainer.new()
	_tray.custom_minimum_size = Vector2(800, 0)
	_tray.add_theme_constant_override("h_separation", 10)
	_tray.add_theme_constant_override("v_separation", 10)
	column.add_child(_tray)
	var owned: Array = GameSession.item_ids()
	for index in owned.size():
		_tray.add_child(_make_stone(owned[index], index))

	_feedback = _label("", 15, Color(1.0, 0.62, 0.5))
	column.add_child(_feedback)
	var close := Button.new()
	close.text = "Cerrar"
	UIKit.skin_by_text(close, 64.0)
	close.pressed.connect(_close_panel)
	var row_close := HBoxContainer.new()
	row_close.alignment = BoxContainer.ALIGNMENT_CENTER
	row_close.add_child(close)
	column.add_child(row_close)
	_focus_first_stone.call_deferred()


func _make_stone(id: String, order: int) -> RiddleStone:
	var stone := RiddleStone.new()
	stone.letter = id
	stone.order = order
	var path: String = StoryItems.info(id)["icon"]
	if path != "" and ResourceLoader.exists(path):
		stone.texture = load(path) as Texture2D
	stone.custom_minimum_size = Vector2(96, 96)
	stone.clicked.connect(_on_stone_clicked)
	stone.released_at.connect(_on_stone_released)
	return stone


func _focus_first_stone() -> void:
	if _tray != null and _tray.get_child_count() > 0:
		(_tray.get_child(0) as Control).grab_focus()


# Soltar: si cae sobre un testimonio que encaja, queda fijada; si no, vuelve a la bandeja.
func _on_stone_released(stone: RiddleStone, point: Vector2) -> void:
	for index in _slots.size():
		var slot: Dictionary = _slots[index]
		if slot["locked"]:
			continue
		if (slot["holder"] as Control).get_global_rect().has_point(point):
			_try_place(stone, index)
			return
	_return_stone(stone)


# Clic (o A con el mando) sobre una pieza: la elige. Luego clic (o A) en el hueco donde va.
func _on_stone_clicked(stone: RiddleStone) -> void:
	if stone.get_parent() != _tray:
		return
	_selected = stone
	stone.modulate = Color(1.0, 0.92, 0.6)
	_feedback.text = "Elegiste: %s. Ahora elige el testimonio que confirma." % StoryItems.info(stone.letter)["name"]
	for index in _slots.size():
		if not _slots[index]["locked"]:
			(_slots[index]["holder"] as Control).grab_focus()
			return


func _on_slot_input(event: InputEvent, index: int) -> void:
	var pressed_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed
	if not (pressed_click or event.is_action_pressed("ui_accept")):
		return
	if _slots[index]["locked"]:
		return
	get_viewport().set_input_as_handled()
	if _selected == null:
		_feedback.text = "Primero elige un hallazgo de tu diario (clic o A)."
		return
	var stone := _selected
	_selected = null
	stone.modulate = Color.WHITE
	_try_place(stone, index)


func _try_place(stone: RiddleStone, index: int) -> void:
	var claim: Dictionary = CLAIMS[index]
	stone.modulate = Color.WHITE
	if stone.letter != claim["evidence"]:
		_feedback.text = "Eso no encaja con lo que dijo %s. Prueba otro hallazgo." % claim["who"]
		_return_stone(stone)
		return
	var slot: Dictionary = _slots[index]
	var holder := slot["holder"] as Control
	_move(stone, holder)
	stone.custom_minimum_size = Vector2(72, 72)
	stone.position = (holder.size - stone.custom_minimum_size) * 0.5
	(slot["label"] as Label).hide()
	slot["locked"] = true
	_locked_count += 1
	_feedback.text = claim["why"]
	if _locked_count == CLAIMS.size():
		_solve()


func _return_stone(stone: RiddleStone) -> void:
	stone.custom_minimum_size = Vector2(96, 96)
	_move(stone, _tray)


func _move(stone: RiddleStone, target: Node) -> void:
	stone.top_level = false
	stone.z_index = 0
	var previous := stone.get_parent()
	if previous != null:
		previous.remove_child(stone)
	target.add_child(stone)


func _solve() -> void:
	_solved = true
	GameSession.set_flag(FLAG_SOLVED)
	AudioLandscape.cue(&"puzzle_complete", global_position)
	var exit := get_node_or_null(exit_path)
	if exit != null:
		exit.set_deferred("monitoring", true)
	_activate_portal()
	GameSession.checkpoint(get_parent())
	get_tree().create_timer(1.2, true).timeout.connect(_finish)


func _finish() -> void:
	_close_panel()
	DialogueManager.show_dialogue([
		"Elliot: Cada uno vio una parte. Ninguno vio todo.",
		"Elliot: La niña se apartó del camino, algo la distrajo y algo grande la siguió.",
	], "Elliot")
	Autores.say(["Los autores: todos cuentan la misma historia, pero nadie se acuerda de la parte que duele."])


func _activate_portal() -> void:
	var portal := get_node_or_null(portal_path)
	if portal != null and portal.has_method("activate"):
		portal.activate()


func _close_panel() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_slots = []
	_tray = null
	_feedback = null
	get_tree().paused = false


func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _say(text: String) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_whisper < 4000:
		return
	_last_whisper = now
	var presentation := get_parent().get_node_or_null("ChapterPresentation")
	if presentation != null and presentation.has_method("rewrite"):
		presentation.rewrite(text)


func _draw() -> void:
	if table_texture != null:
		var ratio := float(table_texture.get_height()) / float(table_texture.get_width())
		draw_texture_rect(table_texture, Rect2(-table_width * 0.5, -table_width * ratio, table_width, table_width * ratio), false)
