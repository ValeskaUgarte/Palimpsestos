extends Area2D
## BAÚL DE LOS CILINDROS (escena 1): PUZLE DE COMBINACIÓN.
##
## En el bosque, una nota (E para leerla) dice lo que hay que girar:
##   «Lo que la siguió. Lo que la distrajo. Lo que cantaba. Lo que llevaba.»
## Cada cilindro muestra un símbolo del camino. Con E (o clic) en el baúl se abre el panel.
## Gira cada cilindro con < y > hasta formar la combinación y pulsa "Probar".
## Al acertar, el baúl se abre: se habilita la salida hacia la escena 2 y se activa el portal.

const FLAG_SOLVED := "mesa_escena1"
const SYMBOLS := ["huella", "flores", "pluma", "pastel"]
## Orden de la combinación: lo que la siguió, lo que la distrajo, lo que cantaba, lo que llevaba.
const SOLUTION := ["huella", "flores", "pluma", "pastel"]

@export var exit_path: NodePath = ^"../ChapterExit"
@export var portal_path: NodePath = ^"../StoryPortal"
@export var chest_texture: Texture2D = preload("res://assets/ui/acertijos/baul_cerrado.png")
@export var chest_width: float = 300.0

var _solved: bool = false
var _near: bool = false
var _layer: CanvasLayer = null
var _cylinders: Array = []   # índice de símbolo elegido en cada cilindro
var _icons: Array = []       # TextureRect del símbolo de cada cilindro
var _names: Array = []       # Label con el nombre del símbolo
var _feedback: Label = null
var _last_hint: int = -100000


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
	_cylinders = [0, 0, 0, 0]


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true
		var now: int = Time.get_ticks_msec()
		if now - _last_hint > 4000:
			_last_hint = now
			var presentation := get_parent().get_node_or_null("ChapterPresentation")
			if presentation != null and presentation.has_method("rewrite"):
				presentation.rewrite("E · abrir el baúl" if not _solved else "El baúl ya está abierto.")


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
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(_label("El baúl de los cilindros", 28, Color(0.96, 0.88, 0.68)))
	if chest_texture != null:
		var chest := TextureRect.new()
		chest.texture = chest_texture
		chest.custom_minimum_size = Vector2(240, 166)
		chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(chest)
	column.add_child(_label("Gira cada cilindro hasta formar la combinación de la nota.", 15, Color(0.85, 0.82, 0.74)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	_icons = []
	_names = []
	for index in 4:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		row.add_child(cell)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(150, 150)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(icon)
		_icons.append(icon)
		var name_label := _label("", 15, Color(0.9, 0.86, 0.78))
		cell.add_child(name_label)
		_names.append(name_label)
		var arrows := HBoxContainer.new()
		arrows.alignment = BoxContainer.ALIGNMENT_CENTER
		arrows.add_theme_constant_override("separation", 8)
		cell.add_child(arrows)
		var left := Button.new()
		left.icon = load("res://assets/ui/kit/btn_flecha_izq.png") as Texture2D
		left.expand_icon = true
		left.custom_minimum_size = Vector2(72, 48)
		left.pressed.connect(_turn.bind(index, -1))
		arrows.add_child(left)
		var right := Button.new()
		right.icon = load("res://assets/ui/kit/btn_flecha_der.png") as Texture2D
		right.expand_icon = true
		right.custom_minimum_size = Vector2(72, 48)
		right.pressed.connect(_turn.bind(index, 1))
		arrows.add_child(right)
		if index == 0:
			left.call_deferred("grab_focus")
	_refresh()

	_feedback = _label("", 15, Color(1.0, 0.62, 0.5))
	column.add_child(_feedback)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	var test := Button.new()
	test.text = "Probar"
	UIKit.skin_by_text(test, 64.0)
	test.pressed.connect(_test)
	actions.add_child(test)
	var close := Button.new()
	close.text = "Cerrar"
	UIKit.skin_by_text(close, 64.0)
	close.pressed.connect(_close_panel)
	actions.add_child(close)


func _turn(index: int, step: int) -> void:
	_cylinders[index] = posmod(int(_cylinders[index]) + step, SYMBOLS.size())
	_feedback.text = ""
	_refresh()


func _refresh() -> void:
	for index in _icons.size():
		var id: String = SYMBOLS[_cylinders[index]]
		var path: String = StoryItems.info(id)["icon"]
		(_icons[index] as TextureRect).texture = load(path) as Texture2D if path != "" else null
		(_names[index] as Label).text = StoryItems.info(id)["name"]


func _test() -> void:
	for index in 4:
		if SYMBOLS[_cylinders[index]] != SOLUTION[index]:
			_feedback.text = "El baúl no cede. Algo no coincide con la nota."
			return
	_solve()


func _solve() -> void:
	_solved = true
	GameSession.set_flag(FLAG_SOLVED)
	AudioLandscape.cue(&"puzzle_complete", global_position)
	var exit := get_node_or_null(exit_path)
	if exit != null:
		exit.set_deferred("monitoring", true)
	_activate_portal()
	GameSession.checkpoint(get_parent())
	_close_panel()
	DialogueManager.show_dialogue([
		"Elliot: Dentro, un papel con la letra de la abuela: el camino corto, marcado con una piedra.",
		"Elliot: La niña lo siguió desde el principio. Algo la desvió y algo la siguió.",
	], "Elliot")
	Autores.say(["Los autores: el papel estuvo siempre ahí. Nadie quiso abrir el baúl."])


func _activate_portal() -> void:
	var portal := get_node_or_null(portal_path)
	if portal != null and portal.has_method("activate"):
		portal.activate()


func _close_panel() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_icons = []
	_names = []
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


func _draw() -> void:
	if chest_texture != null:
		var ratio := float(chest_texture.get_height()) / float(chest_texture.get_width())
		draw_texture_rect(chest_texture, Rect2(-chest_width * 0.5, -chest_width * ratio, chest_width, chest_width * ratio), false)
