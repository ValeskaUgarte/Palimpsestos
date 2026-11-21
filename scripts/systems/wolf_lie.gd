extends Node2D
## EL LOBO MIENTE (escena 2). Dos partes, a lo largo del camino:
##
##  1) EL CRUCE. Elliot escucha desde los árboles al lobo hablando con la niña. El lobo dice tres cosas.
##     Elliot decide si cada una es Verdad o Mentira poniendo una ficha en cada ranura del tablero
##     (arrastrando la ficha, o pulsándola y luego pulsando la ranura), comparando con sus hallazgos
##     (mapa, carta, huella). Se confirma con "Aceptar".
##  2) LA CASA. La "abuelita" es el lobo disfrazado. Elliot lo descubre con el hallazgo de la huella.
##     Caperucita no sabe nada de Elliot: vive su cuento. Huye por su propio camino y la salida se abre.
## Los autores comentan lo que pasa. Caperucita no da órdenes ni habla de Elliot.
##
## Todo se guarda: si sales y vuelves, sigue donde lo dejaste.

const FLAG_CROSSING := "lobo_cruce"
const FLAG_UNMASKED := "lobo_desenmascarado"

## Afirmaciones del lobo. "true" = es verdad. "clue" = objeto de la mochila que hace falta para comprobarla.
## Para cambiar las frases del tablero, edita aquí (tres frases, una por ranura).
const STATEMENTS := [
	{"text": "El camino de las flores es el más corto.", "true": false, "clue": "mapa"},
	{"text": "La abuelita te espera en su casa, por el camino de piedra.", "true": true, "clue": "carta"},
	{"text": "Las huellas grandes del bosque son de un perro bueno.", "true": false, "clue": "huella"},
]

## Respuestas posibles a la "abuelita". "correct" = la que destapa el engaño. "clue" = pista necesaria.
const UNMASK_OPTIONS := [
	{"text": "Elliot se fija en sus manos: tienen garras.", "correct": true, "clue": "huella"},
	{"text": "Elliot escucha su voz: habla de pastel y de tiempo.", "correct": false, "clue": ""},
	{"text": "Elliot decide mirar desde más cerca.", "correct": false, "clue": ""},
]

# --- Arte del tablero de Verdad / Mentira (assets/ui/acertijos/) -------------------------------
const BOARD_TEX := "res://assets/ui/acertijos/tablero_verdad_mentira.png"
const TRUE_TOKEN_TEX := "res://assets/ui/acertijos/ficha_verdad.png"
const FALSE_TOKEN_TEX := "res://assets/ui/acertijos/ficha_mentira.png"
const ACCEPT_TEX := "res://assets/ui/kit/btn_aceptar.png"
const CLOSE_TEX := "res://assets/ui/kit/btn_volver.png"
## El tablero mide 668 x 928 px; en pantalla se dibuja a esta escala.
const BOARD_SCALE := 0.70
const BOARD_SOURCE := Vector2(668, 928)
## Zona de texto de cada fila y centro de su ranura, en píxeles de la imagen original del tablero.
const ROW_TEXT := [Rect2(64, 210, 330, 146), Rect2(64, 395, 330, 146), Rect2(64, 580, 330, 146)]
const SLOT_CENTER := [Vector2(511, 289), Vector2(511, 475), Vector2(511, 657)]
const SLOT_SIZE := Vector2(150, 125)
## Cuántas fichas de cada clase hay en la bandeja.
const TOKENS_PER_KIND := 3
const STAGE_SIZE := Vector2(1040, 690)

# --- Interrogatorio de la abuelita (casa) -------------------------------------------------------
## Cosas que Elliot puede observar. Cada una es una tarjeta con imagen (assets/ui/acertijos/) y un texto.
## "core" = siempre aparece. Las demás (core = false) aparecen SOLO si existe su imagen: así puedes ir
## agregando dibujos nuevos sin tocar el código. Hay que mirarlas todas antes de decidir.
const EVIDENCE := [
	{"core": true, "image": "prueba_cuarto.png", "title": "La habitación",
		"text": "Todo está revuelto y huele a bosque mojado. Una abuela enferma no deja así su cuarto."},
	{"core": true, "image": "prueba_tela.png", "title": "Bajo la cama",
		"text": "Una tela con manchas oscuras asoma bajo la cama. En el cuento original, la verdadera abuelita no tuvo suerte."},
	{"core": true, "image": "prueba_abuela.png", "title": "El retrato",
		"text": "En la pared cuelga un retrato de la abuelita: pequeña, de gorro y tejiendo. Quien está en la cama no se le parece."},
	{"core": true, "image": "detalle_ojos.png", "fallback": "prueba_lobo.png", "title": "Los ojos",
		"text": "«Abuelita, ¡qué ojos tan grandes tienes!» «Para verte mejor.» Brillan en la penumbra, demasiado."},
	{"core": false, "image": "detalle_orejas.png", "title": "Las orejas",
		"text": "«Abuelita, ¡qué orejas tan grandes tienes!» «Para oírte mejor.» Asoman bajo el gorro: peludas y puntiagudas."},
	{"core": false, "image": "detalle_manos.png", "title": "Las manos",
		"text": "«Abuelita, ¡qué manos tan grandes tienes!» «Para abrazarte mejor.» Terminan en garras, como la huella que Elliot guarda."},
	{"core": false, "image": "detalle_dientes.png", "title": "Los dientes",
		"text": "«Abuelita, ¡qué dientes tan grandes tienes!» «Para comerte mejor.» Elliot ya sabe cómo termina esa frase."},
]
## Dibujo grande de la abuelita en la cama (opcional). Si no existe se usa abuela.png.
const GRANDMA_BED_TEX := "res://assets/ui/acertijos/abuelita_cama.png"
const GRANDMA_FALLBACK_TEX := "res://assets/ui/acertijos/abuela.png"
const EVIDENCE_DIR := "res://assets/ui/acertijos/"

@export var crossing_position: Vector2 = Vector2(7000, 270)
@export var grandma_path: NodePath = ^"../Abuelita"
@export var girl_path: NodePath = ^"../Caperucita"
@export var exit_path: NodePath = ^"../ChapterExit"
@export var zone_radius: float = 170.0

var _cross_zone_near: bool = false
var _grandma_zone_near: bool = false
var _layer: CanvasLayer = null
var _choices: Array = []
var _feedback: Label = null
var _buttons: Array = []
## Estado del tablero: ficha puesta en cada ranura (null = vacía, true = Verdad, false = Mentira).
var _selected_kind: Variant = null
var _slots: Array = []
var _chips: Array = []
var _tray_true: Array = []
var _tray_false: Array = []
## Interrogatorio: tarjetas ya observadas, texto del cuaderno y botones de decisión.
var _seen: Array = []
var _notebook: Label = null
var _decide_buttons: Array = []
var _seen_marks: Array = []


## Ficha de la bandeja: se arrastra hasta una ranura (o se pulsa para elegirla).
class TokenButton extends TextureButton:
	var kind: bool = true

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if disabled:
			return null
		var preview := TextureRect.new()
		preview.texture = texture_normal
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_SCALE
		preview.size = size
		preview.position = -size * 0.5
		preview.modulate = Color(1, 1, 1, 0.92)
		var holder := Control.new()
		holder.add_child(preview)
		set_drag_preview(holder)
		return {"kind": kind}


## Ranura del tablero: recibe fichas arrastradas y también se maneja con un clic o con el mando.
class SlotButton extends Button:
	var on_drop: Callable

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("kind")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		on_drop.call(bool(data["kind"]))


func _ready() -> void:
	_make_zone(crossing_position, _on_cross_entered, _on_cross_exited)
	var grandma := get_node_or_null(grandma_path) as Node2D
	if grandma != null:
		_make_zone(grandma.position, _on_grandma_entered, _on_grandma_exited)
	var exit := get_node_or_null(exit_path)
	if GameSession.has_flag(FLAG_UNMASKED):
		_unmasked_already(grandma)
	elif exit != null:
		exit.set_deferred("monitoring", false)


func _make_zone(center: Vector2, entered: Callable, exited: Callable) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = center
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(zone_radius * 2.0, 400.0)
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(entered)
	area.body_exited.connect(exited)
	add_child(area)


func _on_cross_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cross_zone_near = true
		_hint("Elliot escucha al lobo desde los árboles. E · comparar lo que dice con lo que has encontrado.")


func _on_cross_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cross_zone_near = false


func _on_grandma_entered(body: Node2D) -> void:
	if body.is_in_group("player") and GameSession.has_flag(FLAG_CROSSING) and not GameSession.has_flag(FLAG_UNMASKED):
		_grandma_zone_near = true
		_hint("La abuelita te observa desde la puerta. E · mirar con atención.")


func _on_grandma_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_grandma_zone_near = false


func _unhandled_input(event: InputEvent) -> void:
	if _layer != null or DialogueManager.visible or ScenePages.busy or get_tree().paused:
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _cross_zone_near and not GameSession.has_flag(FLAG_CROSSING):
		get_viewport().set_input_as_handled()
		_open_crossing()
	elif _grandma_zone_near:
		get_viewport().set_input_as_handled()
		_open_unmask()


func _hint(text: String) -> void:
	var presentation := get_parent().get_node_or_null("ChapterPresentation")
	if presentation != null and presentation.has_method("rewrite"):
		presentation.rewrite(text)


# ---------------------------------------------------------------------------------------------
# PARTE 1: el cruce
# ---------------------------------------------------------------------------------------------
func _open_crossing() -> void:
	var stage := _open_stage()
	var board_size := BOARD_SOURCE * BOARD_SCALE
	var board_pos := Vector2(0.0, (STAGE_SIZE.y - board_size.y) * 0.5)

	# El tablero de madera con la cabeza del lobo y tres filas (frase + ranura).
	var board := TextureRect.new()
	board.texture = load(BOARD_TEX) as Texture2D
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.position = board_pos
	board.size = board_size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(board)

	_choices = []
	_slots = []
	_chips = []
	_selected_kind = null
	for index in STATEMENTS.size():
		var statement: Dictionary = STATEMENTS[index]
		_choices.append(null)
		# Frase del lobo y estado de la pista, dentro del panel oscuro de la fila.
		var text_rect: Rect2 = ROW_TEXT[index]
		var text_box := VBoxContainer.new()
		text_box.position = board_pos + text_rect.position * BOARD_SCALE
		text_box.size = text_rect.size * BOARD_SCALE
		text_box.add_theme_constant_override("separation", 4)
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(text_box)
		var line := _label("«%s»" % statement["text"], 17, Color(0.93, 0.88, 0.78))
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(line)
		var clue_id: String = statement["clue"]
		var has_clue: bool = GameSession.item_count(clue_id) > 0
		var clue_line := _label("%s: %s" % [StoryItems.info(clue_id)["name"], "tienes la pista" if has_clue else "te falta la pista"], 13,
				Color(0.62, 0.8, 0.66) if has_clue else Color(0.9, 0.62, 0.55))
		clue_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(clue_line)

		# Ranura de la derecha: aquí va la ficha de Verdad o de Mentira.
		var slot := SlotButton.new()
		slot.flat = true
		slot.size = SLOT_SIZE * BOARD_SCALE
		slot.position = board_pos + (SLOT_CENTER[index] - SLOT_SIZE * 0.5) * BOARD_SCALE
		slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		slot.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		slot.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		slot.add_theme_stylebox_override("focus", _focus_frame())
		slot.on_drop = _place.bind(index)
		slot.pressed.connect(_slot_pressed.bind(index))
		stage.add_child(slot)
		_slots.append(slot)
		var chip := TextureRect.new()
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(chip)
		_chips.append(chip)

	# Columna de la derecha: título, instrucción, bandeja de fichas, aviso y botones.
	var right_x := board_size.x + 50.0
	var right_w := STAGE_SIZE.x - right_x
	# Título escrito sobre una tabla de madera (UIKit.wood_title), centrado en la columna de la derecha.
	var title := UIKit.wood_title("Lo que dice el lobo", 380.0, 27)
	title.position = Vector2(right_x + (right_w - title.size.x) * 0.5, 12)
	stage.add_child(title)
	var help := _label("Elliot escucha. Decide si cada frase es Verdad o Mentira comparándola con sus hallazgos. Arrastra una ficha hasta la ranura, o pulsa la ficha y luego la ranura.", 15, Color(0.85, 0.82, 0.74))
	help.position = Vector2(right_x, 80)
	help.size = Vector2(right_w, 90)
	stage.add_child(help)
	_tray_true = []
	_tray_false = []
	var token_w := 150.0
	var token_h := token_w * 98.0 / 156.0
	var gap := (right_w - token_w * TOKENS_PER_KIND) / float(TOKENS_PER_KIND - 1)
	for row in 2:
		var says_true := row == 0
		for slot_index in TOKENS_PER_KIND:
			var token := TokenButton.new()
			token.kind = says_true
			token.texture_normal = load(TRUE_TOKEN_TEX if says_true else FALSE_TOKEN_TEX) as Texture2D
			token.ignore_texture_size = true
			token.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			token.size = Vector2(token_w, token_h)
			token.position = Vector2(right_x + slot_index * (token_w + gap), 200.0 + row * (token_h + 26.0))
			token.pressed.connect(_pick_token.bind(says_true))
			stage.add_child(token)
			(_tray_true if says_true else _tray_false).append(token)
	_feedback = _label("", 15, Color(1.0, 0.62, 0.5))
	_feedback.position = Vector2(right_x, 430)
	_feedback.size = Vector2(right_w, 70)
	stage.add_child(_feedback)
	var accept := _art_button(ACCEPT_TEX, 250.0, _check_crossing)
	accept.position = Vector2(right_x, 540)
	stage.add_child(accept)
	var close := _art_button(CLOSE_TEX, 220.0, _close_layer)
	close.position = Vector2(right_x + right_w - 220.0, 540)
	stage.add_child(close)
	_refresh_board()
	(_slots[0] as BaseButton).call_deferred("grab_focus")


# Marco dorado que marca la ranura enfocada (teclado / mando).
func _focus_frame() -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = Color(0.95, 0.8, 0.4)
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(6)
	return frame


# Botón con imagen. Se ilumina al enfocarlo o al pasar el ratón.
func _art_button(path: String, width: float, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	var texture := load(path) as Texture2D
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var ratio: float = float(texture.get_height()) / float(texture.get_width())
	button.size = Vector2(width, width * ratio)
	button.custom_minimum_size = button.size
	button.pressed.connect(action)
	var glow := func(): button.modulate = Color(1.3, 1.18, 0.95)
	var dull := func(): button.modulate = Color.WHITE
	button.focus_entered.connect(glow)
	button.mouse_entered.connect(glow)
	button.focus_exited.connect(dull)
	button.mouse_exited.connect(dull)
	return button


# Elige una ficha de la bandeja (pulsándola otra vez se suelta).
func _pick_token(says_true: bool) -> void:
	_selected_kind = null if _selected_kind == says_true else says_true
	_refresh_board()


# Pone una ficha en una ranura (arrastrada o elegida antes).
func _place(says_true: bool, index: int) -> void:
	_choices[index] = says_true
	_selected_kind = null
	if _feedback != null:
		_feedback.text = ""
	_refresh_board()


# Clic o botón de aceptar sobre una ranura: con una ficha elegida la coloca; sin ficha cambia la ranura
# (vacía -> Verdad -> Mentira -> vacía), para poder jugar también con el mando.
func _slot_pressed(index: int) -> void:
	if _selected_kind != null:
		_place(bool(_selected_kind), index)
		return
	var current: Variant = _choices[index]
	if current == null:
		_choices[index] = true
	elif current == true:
		_choices[index] = false
	else:
		_choices[index] = null
	if _feedback != null:
		_feedback.text = ""
	_refresh_board()


# Redibuja las fichas de las ranuras y la bandeja (las fichas usadas se apagan).
func _refresh_board() -> void:
	var used_true := 0
	var used_false := 0
	for index in _choices.size():
		var value: Variant = _choices[index]
		var chip := _chips[index] as TextureRect
		if value == null:
			chip.texture = null
		elif value == true:
			chip.texture = load(TRUE_TOKEN_TEX) as Texture2D
			used_true += 1
		else:
			chip.texture = load(FALSE_TOKEN_TEX) as Texture2D
			used_false += 1
	_style_tray(_tray_true, used_true, true)
	_style_tray(_tray_false, used_false, false)


func _style_tray(tray: Array, used: int, says_true: bool) -> void:
	var available := TOKENS_PER_KIND - used
	for index in tray.size():
		var token := tray[index] as TokenButton
		var free: bool = index < available
		token.disabled = not free
		if not free:
			token.modulate = Color(1, 1, 1, 0.2)
		elif _selected_kind != null and _selected_kind == says_true:
			token.modulate = Color(1.35, 1.25, 1.0)
		else:
			token.modulate = Color.WHITE


func _check_crossing() -> void:
	for index in STATEMENTS.size():
		if _choices[index] == null:
			_feedback.text = "Marca todas las afirmaciones del lobo."
			return
	for index in STATEMENTS.size():
		var statement: Dictionary = STATEMENTS[index]
		if GameSession.item_count(statement["clue"]) <= 0:
			_feedback.text = "Elliot no puede comprobarla: le falta el hallazgo «%s»." % StoryItems.info(statement["clue"])["name"]
			return
	for index in STATEMENTS.size():
		var statement: Dictionary = STATEMENTS[index]
		if _choices[index] != statement["true"]:
			_feedback.text = "Elliot se equivoca. Algún hallazgo desmiente una de esas frases."
			return
	GameSession.set_flag(FLAG_CROSSING)
	_close_layer()
	DialogueManager.show_dialogue([
		"Elliot: El camino de las flores era un rodeo. El lobo quiso que la niña se perdiera por ahí.",
		"Elliot: Ella sigue por la piedra. Ni siquiera sabe que alguien la observa.",
	], "Elliot")
	Autores.say(["Los autores: el lobo siempre ofrece el rodeo que parece más bonito."])


# ---------------------------------------------------------------------------------------------
# PARTE 2: la abuelita es el lobo
# ---------------------------------------------------------------------------------------------
func _open_unmask() -> void:
	var stage := _open_stage()
	# Tarjetas que se muestran: las principales y las opcionales cuya imagen exista.
	var cards: Array = []
	for evidence in EVIDENCE:
		var path: String = EVIDENCE_DIR + String(evidence["image"])
		if not ResourceLoader.exists(path) and evidence.has("fallback"):
			path = EVIDENCE_DIR + String(evidence["fallback"])
		if ResourceLoader.exists(path) and (evidence["core"] or path.ends_with(String(evidence["image"]))):
			cards.append({"path": path, "title": evidence["title"], "text": evidence["text"]})
	_seen = []
	_seen_marks = []
	_decide_buttons = []

	# Izquierda: la abuelita en la cama (dibujo grande, o el retrato de respaldo).
	var grandma_path := GRANDMA_BED_TEX if ResourceLoader.exists(GRANDMA_BED_TEX) else GRANDMA_FALLBACK_TEX
	var portrait := TextureRect.new()
	portrait.texture = load(grandma_path) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(10, 90)
	portrait.size = Vector2(300, 440)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(portrait)
	var caption := _label("«Acércate, hija mía...»", 16, Color(0.9, 0.82, 0.66))
	caption.position = Vector2(10, 540)
	caption.size = Vector2(300, 30)
	stage.add_child(caption)

	# Derecha: título, instrucción, tarjetas, cuaderno y decisiones.
	var right_x := 340.0
	var right_w := STAGE_SIZE.x - right_x - 10.0
	var title := UIKit.wood_title("La abuelita", 380.0, 27)
	title.position = Vector2(right_x + (right_w - title.size.x) * 0.5, 8)
	stage.add_child(title)
	var help := _label("Elliot la observa desde la puerta. Algo no encaja. Mira cada detalle y luego decide qué ha descubierto.", 15, Color(0.85, 0.82, 0.74))
	help.position = Vector2(right_x, 56)
	help.size = Vector2(right_w, 40)
	stage.add_child(help)
	var columns := 4
	var rows_count: int = ceili(float(cards.size()) / float(columns))
	var card_size := 150.0 if rows_count <= 1 else 120.0
	var gap_x: float = (right_w - card_size * columns) / float(columns - 1)
	var pitch_y := card_size + 30.0
	for index in cards.size():
		var card: Dictionary = cards[index]
		var origin := Vector2(right_x + (index % columns) * (card_size + gap_x), 104.0 + (index / columns) * pitch_y)
		var button := TextureButton.new()
		button.texture_normal = load(card["path"]) as Texture2D
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = origin
		button.size = Vector2(card_size, card_size)
		button.pressed.connect(_observe.bind(index, card))
		var glow := func(): button.modulate = Color(1.3, 1.18, 0.95)
		var dull := func(): button.modulate = Color.WHITE
		button.focus_entered.connect(glow)
		button.mouse_entered.connect(glow)
		button.focus_exited.connect(dull)
		button.mouse_exited.connect(dull)
		stage.add_child(button)
		var name_label := _label(String(card["title"]), 14, Color(0.93, 0.88, 0.78))
		name_label.position = origin + Vector2(0, card_size + 2)
		name_label.size = Vector2(card_size, 22)
		stage.add_child(name_label)
		var mark := _label("", 13, Color(0.62, 0.85, 0.66))
		mark.position = origin + Vector2(0, 2)
		mark.size = Vector2(card_size, 18)
		stage.add_child(mark)
		_seen_marks.append(mark)
		_seen.append(false)
		if index == 0:
			button.call_deferred("grab_focus")
	var notebook_y := 104.0 + rows_count * pitch_y + 6.0
	_notebook = _label("Pulsa cada imagen para observarla.", 16, Color(0.95, 0.9, 0.8))
	_notebook.position = Vector2(right_x, notebook_y)
	_notebook.size = Vector2(right_w, 84)
	stage.add_child(_notebook)
	var decide_y := notebook_y + 92.0
	for option in UNMASK_OPTIONS:
		var decide := Button.new()
		decide.text = String(option["text"])
		decide.position = Vector2(right_x, decide_y)
		decide.size = Vector2(right_w, 38)
		decide.disabled = true
		decide.tooltip_text = "Observa todos los detalles antes de decidir."
		decide.pressed.connect(_answer.bind(option))
		stage.add_child(decide)
		_decide_buttons.append(decide)
		decide_y += 44.0
	_feedback = _label("", 15, Color(1.0, 0.62, 0.5))
	_feedback.position = Vector2(right_x, decide_y)
	_feedback.size = Vector2(right_w - 240.0, 40)
	stage.add_child(_feedback)
	var close := _art_button(CLOSE_TEX, 220.0, _close_layer)
	close.position = Vector2(STAGE_SIZE.x - 230.0, decide_y)
	stage.add_child(close)


# Observa una tarjeta: el cuaderno muestra lo que ve Elliot. Con todas vistas se habilitan las decisiones.
func _observe(index: int, card: Dictionary) -> void:
	_seen[index] = true
	(_seen_marks[index] as Label).text = "visto"
	_notebook.text = String(card["text"])
	AudioLandscape.cue(&"clue", global_position)
	if not _seen.has(false):
		for decide in _decide_buttons:
			(decide as Button).disabled = false
		_feedback.text = "Elliot ya lo ha visto todo. ¿Qué ha descubierto?"
		_feedback.add_theme_color_override("font_color", Color(0.62, 0.85, 0.66))


func _answer(option: Dictionary) -> void:
	var clue: String = option["clue"]
	if clue != "" and GameSession.item_count(clue) <= 0:
		_feedback.text = "Elliot no lo nota: le falta el hallazgo «%s»." % StoryItems.info(clue)["name"]
		return
	if not option["correct"]:
		_feedback.add_theme_color_override("font_color", Color(1.0, 0.62, 0.5))
		_feedback.text = "Nada de eso explica lo que ve. Sigue mirando."
		return
	GameSession.set_flag(FLAG_UNMASKED)
	_close_layer()
	_unmask_sequence()


func _unmask_sequence() -> void:
	var grandma := get_node_or_null(grandma_path) as Node2D
	var girl := get_node_or_null(girl_path) as Node2D
	DialogueManager.show_dialogue([
		"Elliot: La abuelita se quita el disfraz. Es el lobo, y estaba en la casa desde el principio.",
	], "Elliot")
	Autores.say(["Los autores: así lo contaron. Y así lo borramos después."])
	var tween := create_tween()
	tween.set_parallel(true)
	if girl != null:
		tween.tween_property(girl, "position:x", girl.position.x + 1600.0, 2.6)  # huye por su propio camino
	if grandma != null:
		tween.tween_property(grandma, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(_finish_unmask.bind(girl, grandma))


func _finish_unmask(girl: Node2D, grandma: Node2D) -> void:
	if girl != null:
		girl.visible = false
	if grandma != null:
		grandma.visible = false
	_open_exit()


func _unmasked_already(grandma: Node2D) -> void:
	# Ya se descubrió en una partida anterior: el lobo ya no está en la casa.
	if grandma != null:
		grandma.visible = false
	var girl := get_node_or_null(girl_path) as Node2D
	if girl != null:
		girl.visible = false
	_open_exit()


# La salida a la escena 3 se abre cuando el lobo queda desenmascarado Y la cueva está resuelta.
func _open_exit() -> void:
	if not GameSession.has_flag(FLAG_UNMASKED):
		return
	var exit := get_node_or_null(exit_path)
	if exit != null:
		exit.set_deferred("monitoring", true)


# ---------------------------------------------------------------------------------------------
# Panel común
# ---------------------------------------------------------------------------------------------
# Capa para el tablero de Verdad/Mentira: fondo oscuro y un lienzo del tamaño de STAGE_SIZE centrado.
func _open_stage() -> Control:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 80
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	var stage := Control.new()
	stage.custom_minimum_size = STAGE_SIZE
	center.add_child(stage)
	return stage


func _open_layer() -> void:
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.1, 0.97)
	style.border_color = Color(0.55, 0.47, 0.33)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(640, 0)
	var parchment := StyleBoxTexture.new()
	parchment.texture = load("res://assets/ui/acertijos/verdad_mentira.png") as Texture2D
	parchment.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", parchment)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	_panel_column = VBoxContainer.new()
	_panel_column.add_theme_constant_override("separation", 12)
	margin.add_child(_panel_column)


var _panel_column: VBoxContainer = null


func _column_in_panel() -> VBoxContainer:
	return _panel_column


func _action_row(actions: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for action in actions:
		var button := Button.new()
		button.text = action[0]
		button.custom_minimum_size = Vector2(150, 40)
		button.pressed.connect(action[1])
		row.add_child(button)
	return row


func _close_layer() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_panel_column = null
	_feedback = null
	_buttons = []
	_slots = []
	_chips = []
	_tray_true = []
	_tray_false = []
	_selected_kind = null
	_seen = []
	_seen_marks = []
	_decide_buttons = []
	_notebook = null
	get_tree().paused = false


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
