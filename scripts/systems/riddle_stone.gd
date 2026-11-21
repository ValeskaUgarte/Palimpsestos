class_name RiddleStone
extends TextureRect
## Piedra con una letra del acertijo de la cueva.
## Se puede pulsar (va a la ranura o vuelve a la bandeja) o arrastrar hasta la ranura.
## Lo gestiona cave_riddle.gd, que decide dónde se suelta.

signal clicked(stone: RiddleStone)
signal released_at(stone: RiddleStone, global_point: Vector2)

## Letra griega que representa la piedra (la que se compara con la respuesta).
var letter: String = ""
## Posición original en la bandeja: así vuelve a su sitio cuando se devuelve.
var order: int = 0

var _pressed: bool = false
var _dragging: bool = false
var _press_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(func(): modulate = Color(1.0, 0.92, 0.6))
	focus_exited.connect(func(): modulate = Color.WHITE)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pressed = true
		_press_point = event.global_position
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		# Mando o teclado: con el foco en la piedra, A la manda a la ranura (o la devuelve).
		accept_event()
		clicked.emit(self)


# El arrastre se sigue en _input para que no dependa de que el mouse se quede sobre la piedra.
func _input(event: InputEvent) -> void:
	if not _pressed:
		return
	if event is InputEventMouseMotion:
		if not _dragging and event.global_position.distance_to(_press_point) > 8.0:
			_begin_drag(event.global_position)
		if _dragging:
			global_position = event.global_position - size * 0.5
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_pressed = false
		get_viewport().set_input_as_handled()
		if _dragging:
			_dragging = false
			top_level = false
			z_index = 0
			released_at.emit(self, event.global_position)
		else:
			clicked.emit(self)


func _begin_drag(point: Vector2) -> void:
	_dragging = true
	# top_level saca la piedra del contenedor mientras se arrastra (el contenedor no la recoloca).
	top_level = true
	z_index = 50
	global_position = point - size * 0.5
