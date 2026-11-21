extends Control
## FIN DE CAPÍTULO. Se ve igual que los créditos del menú (pergamino con texto que avanza despacio),
## pero cuenta cómo termina la historia del Capítulo 1. Abajo hay tres botones:
## volver al menú, empezar de nuevo o ir al mapa.
## El texto se cambia en LINES. Tipos: h = encabezado, t = texto, q = frase destacada, s = espacio.

const SPEED: float = 26.0
const IDLE_BEFORE_RESUME: float = 3.0

const LINES := [
	["q", "Fin del Capítulo 1"],
	["s", ""],
	["t", "El lobo cayó y el cuento de Caperucita llegó a su final.\nEse capítulo ya no se está escribiendo: está terminado."],
	["s", ""],
	["t", "Pero los autores no se marcharon.\nSiguen detrás de cada página, y seguirán intentando\nque sus obras no vuelvan a ser ensuciadas."],
	["s", ""],
	["q", "No soltarán a los personajes."],
	["t", "Los mantendrán a su lado, entre líneas, porque serán\nlos primeros en abrir los ojos."],
	["s", ""],
	["t", "Elliot, Jhon y Thomas comprendieron que el lobo era más que una bestia:\nel guardián de lo que el relato decidió olvidar."],
	["s", ""],
	["h", "La historia terminó. La lucha por cuidarla, no."],
	["t", "Una página se cierra. Otra espera."],
	["s", ""],
	["s", ""],
]

var _scroll: ScrollContainer
var _position: float = 0.0
var _idle: float = 0.0


func _ready() -> void:
	GameSession.complete_chapter()
	AudioLandscape.hush(.1, 2)
	# El pergamino de los créditos (mismo módulo de interfaz), con fondo y velo del menú (nodos de la escena).
	var parts: Dictionary = UIKit.parchment(Vector2(1000, 660))
	add_child(parts.root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	(parts.content as MarginContainer).add_child(box)

	var title: Control = UIKit.banner("Fin del capítulo · no todo lo escrito permanece", 78)
	if title == null:
		title = UIKit.ink_label("Fin del capítulo", 30, UIKit.INK_RED)
		(title as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.focus_mode = Control.FOCUS_ALL
	box.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	_scroll.add_child(column)
	for line in LINES:
		column.add_child(_make_line(line[0], line[1]))

	# Botones: menú, empezar de nuevo, mapa.
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var to_menu := _make_button("Volver al menú", "btn_salir_menu", _on_menu_pressed)
	buttons.add_child(to_menu)
	buttons.add_child(_make_button("Nueva partida", "btn_nueva_partida", _on_restart_pressed))
	buttons.add_child(_make_button("Ir al mapa", "", _on_map_pressed))
	to_menu.grab_focus()


# Botón con la imagen del juego si existe; si no (p. ej. "Ir al mapa"), un botón de pergamino liso.
func _make_button(text: String, skin_key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if skin_key == "" or not UIKit.skin_button(button, skin_key, 54):
		# Sin recuadro: solo el texto en dorado, con el mismo tono que el resto del juego.
		button.flat = true
		button.custom_minimum_size = Vector2(190, 54)
		button.add_theme_color_override("font_color", Color("e6d6ae"))
		button.add_theme_color_override("font_hover_color", Color("fff1c9"))
		button.add_theme_color_override("font_pressed_color", Color("c9b27a"))
		button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button


func _make_line(kind: String, text: String) -> Control:
	if kind == "s":
		var gap := Control.new()
		gap.custom_minimum_size.y = 26
		return gap
	var font_size: int = 20
	var color: Color = UIKit.INK
	match kind:
		"h":
			font_size = 24
			color = UIKit.INK_RED
		"q":
			font_size = 30
			color = UIKit.INK_RED
	var label := UIKit.ink_label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _process(delta: float) -> void:
	if _idle > 0.0:
		_idle -= delta
		_position = float(_scroll.scroll_vertical)
		return
	_position += SPEED * delta
	_scroll.scroll_vertical = int(_position)


# La rueda del ratón o las flechas toman el control del texto unos segundos.
func _input(event: InputEvent) -> void:
	var touched: bool = event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN)
	if event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]:
		touched = true
	if touched:
		_idle = IDLE_BEFORE_RESUME
		if event is InputEventKey:
			var step: float = 60.0 if event.keycode in [KEY_UP, KEY_DOWN] else 240.0
			var direction: float = -1.0 if event.keycode in [KEY_UP, KEY_PAGEUP] else 1.0
			_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical + int(step * direction))


func _on_menu_pressed() -> void:
	ScenePages.travel("res://scenes/main_menu.tscn")


# "Nueva partida" empieza el Cuento I otra vez desde la primera escena.
func _on_restart_pressed() -> void:
	GameSession.new_game()


func _on_map_pressed() -> void:
	ScenePages.travel("res://scenes/ui/map_screen.tscn")
