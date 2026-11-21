extends Control
## Créditos sobre pergamino, con desplazamiento lento que se puede tomar
## con la rueda del ratón o las flechas.

const SPEED: float = 26.0
const IDLE_BEFORE_RESUME: float = 3.0

# [tipo, texto]  tipo: h = encabezado, n = nombre, t = texto, s = espacio, q = frase final
const LINES := [
	["q", "PALIMPSESTOS"],
	["t", "Toda nueva historia deja algo atrás."],
	["s", ""],
	["t", "Un palimpsesto es un manuscrito cuya escritura fue raspada\npara escribir encima, sin llegar a borrarla del todo.\nAsí nace este juego: un cuento escrito sobre otro cuento."],
	["s", ""],
	["h", "Equipo del proyecto"],
	["n", "Valeska Ugarte"],
	["n", "Antony Bracho"],
	["s", ""],
	["t", "Diseño, arte, guion y programación:\nel equipo del proyecto."],
	["s", ""],
	["h", "Basado en"],
	["t", "Los cuentos originales de Charles Perrault\ny los hermanos Grimm."],
	["t", "Caperucita Roja, reescrita página a página."],
	["s", ""],
	["h", "Cuento I"],
	["t", "El bosque antiguo"],
	["t", "Más allá del camino"],
	["t", "Las historias olvidadas"],
	["s", ""],
	["h", "El inframundo"],
	["t", "La versión borrada"],
	["t", "Lo que el relato descartó y aún recuerda."],
	["s", ""],
	["h", "Personajes"],
	["t", "Elliot · Jhon · Thomas"],
	["t", "Caperucita · Stephy · Ethan"],
	["t", "La Mamá y la Vecina · Ranger Wood"],
	["t", "El Lobo, guardián de la historia"],
	["s", ""],
	["h", "Música y paisaje sonoro"],
	["t", "Música, ambientes y efectos\ncreados para este proyecto."],
	["s", ""],
	["h", "Hecho con"],
	["t", "Godot Engine"],
	["s", ""],
	["h", "Agradecimientos"],
	["t", "A cada persona que probó el juego,\nencontró un error o dio una opinión sincera\ny ayudó a que esta historia siguiera escribiéndose."],
	["t", "A quienes todavía leen cuentos en voz alta."],
	["s", ""],
	["q", "No todo lo escrito permanece."],
	["t", "La página puede volver a escribirse."],
	["s", ""],
	["h", "Gracias por jugar"],
	["s", ""],
]

var _scroll: ScrollContainer
var _position: float = 0.0
var _idle: float = 0.0

func _ready() -> void:
	var parts: Dictionary = UIKit.parchment(Vector2(1000, 660))
	add_child(parts.root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	(parts.content as MarginContainer).add_child(box)

	var title: Control = UIKit.banner("Créditos", 78)
	if title == null:
		title = UIKit.ink_label("Créditos", 30, UIKit.INK_RED)
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

	var back := Button.new()
	back.text = "Volver"
	box.add_child(back)
	if not UIKit.skin_button(back, "btn_volver", 54):
		UIKit.style_plain_button(back)
	back.pressed.connect(_on_back_pressed)
	back.grab_focus()

func _make_line(kind: String, text: String) -> Control:
	if kind == "s":
		var gap := Control.new()
		gap.custom_minimum_size.y = 26
		return gap
	var font_size: int = 19
	var color: Color = UIKit.INK
	match kind:
		"h":
			font_size = 24
			color = UIKit.INK_RED
		"n":
			font_size = 30
		"q":
			font_size = 28
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
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	ScenePages.travel("res://scenes/main_menu.tscn")
