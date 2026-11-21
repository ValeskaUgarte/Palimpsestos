extends Node2D
## MONOLITO DE LOS ANILLOS (escena 2, entrada de la cueva): PUZLE DE ANILLOS GIRATORIOS.
##
## Una roca grande tapa la entrada de la cueva. En su cara hay tres anillos concéntricos con símbolos
## (árbol, hongo, hoja, casa, luna) y la cabeza del lobo en el centro.
## Cada anillo gira en un solo sentido, de a un paso (un símbolo) por pulsación:
##   - anillo exterior: con el sol (sentido de las agujas del reloj)
##   - anillo medio:    contra el sol
##   - anillo interior: con el sol
## Hay que dejar, bajo la marca de arriba, el cuento original de Caperucita contado en orden, de fuera hacia dentro:
##   CASA (la niña sale de casa de su madre) -> ÁRBOL (entra al bosque y se cruza con el lobo)
##   -> HOJA (se aparta del camino a recoger flores).  El lobo, en el centro, ya corrió por el camino corto.
## Las pistas están repartidas por el camino de la escena 2 (nodo RutaCuento, preset "escena2") y se leen con E.
## Con E junto al monolito se abre el panel. Al acertar, la roca se desliza y aparece la entrada de la cueva:
## Elliot entra desde ese mismo lugar y pasa a la escena 3 (nodo ExitCueva).

const FLAG_SOLVED := "cueva_resuelta"
const FLAG_CALLED := "abuela_envia_cueva"

## Imagen de cada anillo, de fuera hacia dentro (en assets/ui/acertijos/).
const RING_FILES := [
	"res://assets/ui/acertijos/anillo_exterior.png",
	"res://assets/ui/acertijos/anillo_medio.png",
	"res://assets/ui/acertijos/anillo_centro_lobo.png",
]
const RING_NAMES := ["exterior", "medio", "interior"]
## Lado del lienzo de cada imagen (px). El círculo del anillo es un poco menor porque la flecha de arriba sobresale.
const RING_CANVAS := [746.0, 373.0, 176.0]
## Centro real del círculo de cada imagen (px del lienzo, medido sobre el dibujo). No es el centro del lienzo:
## el anillo gira sobre este punto y todos se colocan con él en el mismo centro de la rueda.
const RING_CENTER := [Vector2(374.0, 361.0), Vector2(186.0, 181.0), Vector2(87.5, 86.0)]
## Ajuste de tamaño para que encajen unos dentro de otros (el disco del lobo es un poco mayor que el hueco del medio).
const RING_FIT := [1.0, 1.0, 1.04]
## Diámetro del círculo del anillo exterior en su imagen original (px).
const OUTER_CIRCLE := 670.0
## Un paso = un símbolo (hay cinco por anillo).
const STEP := TAU / 5.0
## Símbolos de cada anillo, en el sentido de las agujas del reloj empezando por arriba (como vienen en la imagen).
const SYMBOLS_PER_RING := [
	["árbol", "hongo", "hoja", "casa", "árbol"],
	["árbol", "luna", "hoja", "casa", "hongo"],
	["árbol", "hongo", "hoja", "casa", "árbol"],
]
## Sentido de giro de cada anillo: 1 = con el sol (↻), -1 = contra el sol (↺).
const TURN_DIR := [1, -1, 1]
## Pasos con los que empieza cada anillo (ninguno empieza resuelto).
const START_STEPS := [4, 3, 4]
## Símbolo que debe quedar arriba en cada anillo (de fuera hacia dentro): el cuento original en orden.
const SOLUTION := ["casa", "árbol", "hoja"]
## Si un anillo no está bien, la roca lo cuenta con una frase del cuento (sin dar la respuesta).
const WRONG_HINTS := [
	"La roca no se mueve. El cuento todavía no empieza donde debe: ¿de dónde salió la niña?",
	"La roca tiembla, pero no cede. Falta el lugar donde la niña se cruzó con el lobo.",
	"Casi. Falta lo que la hizo apartarse del camino.",
]
## Imágenes del paquete nuevo (assets/ui/acertijos/paquete/).
const PACK := "res://assets/ui/acertijos/paquete/"
const RING_BUTTON_FILES := [PACK + "anillo_exterior.png", PACK + "anillo_medio.png", PACK + "anillo_interior.png"]
const WAY_SUN := PACK + "con_el_sol.png"
const WAY_AGAINST := PACK + "contra_el_sol.png"
const TITLE_FILE := PACK + "anillos_del_lobo.png"
const PROBAR_FILE := PACK + "btn_probar.png"
const CERRAR_FILE := PACK + "btn_cerrar_a.png"

## Tamaño del panel de los anillos (lado del anillo exterior en pantalla) y espacio para la marca de arriba.
const WHEEL_BOX := 400.0
const WHEEL_TOP := 24.0
## Medidas del dibujo del monolito (363 x 602 px) y centro de su cara, para montar los anillos encima.
const STONE_FACE_CENTER := Vector2(0.5, 0.41)
const WHEEL_ON_STONE := 0.9

@export var examine_position: Vector2 = Vector2(4365, 272)
@export var zone_half_width: float = 170.0
## Roca gigante que tapa la entrada de la cueva (nodo Sprite2D de la escena).
@export var rock_path: NodePath = ^"../RocaCueva"
@export var slab_rect: Rect2 = Rect2(4230, -240, 270, 280)
@export var slide_distance: float = 260.0
## La abuela (guía) que manda a volver a la cueva. Hasta que habla con ella, el monolito no responde.
@export var guide_path: NodePath = ^"../Abuelita"
## Salida de la cueva a la escena 3 (se abre al resolver los anillos).
@export var exit_path: NodePath = ^"../ExitCueva"
@export var monolith_texture: Texture2D = preload("res://assets/ui/acertijos/monolito_discos.png")

var _solved: bool = false
var _near: bool = false
var _slide: float = 0.0
var _layer: CanvasLayer = null
var _feedback: Label = null
var _last_hint: int = -100000
var _zone: Area2D = null
var _active: bool = false
## Pasos dados por cada anillo (0 a 4) y ángulo actual / de destino (radianes).
var _steps: Array = []
var _angle: Array = []
var _target: Array = []
var _tweens: Array = [null, null, null]
var _ring_textures: Array = []
var _ring_rects: Array = []


func _ready() -> void:
	# La roca se dibuja POR ENCIMA del fondo (antes z_index=-1 quedaba escondida detrás de la imagen de la cueva).
	z_index = 0
	for path in RING_FILES:
		_ring_textures.append(load(path) as Texture2D)
	_steps = START_STEPS.duplicate()
	for index in 3:
		var start: float = float(TURN_DIR[index]) * float(_steps[index]) * STEP
		_angle.append(start)
		_target.append(start)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = examine_position
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(zone_half_width * 2.0, 400.0)
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(_on_zone_entered)
	area.body_exited.connect(_on_zone_exited)
	add_child(area)
	_zone = area
	var guide := get_node_or_null(guide_path)
	if guide != null and guide.has_signal("conversation_finished"):
		guide.conversation_finished.connect(_on_grandma_done)
	if GameSession.has_flag(FLAG_SOLVED):
		# Partida guardada con la cueva ya abierta: la roca queda apartada y la entrada funciona.
		_solved = true
		_slide = slide_distance
		_set_solved_angles()
		_enable_exit()
	if GameSession.has_flag(FLAG_CALLED) or GameSession.has_flag(FLAG_SOLVED):
		_active = true
	_zone.monitoring = _active


# La abuela termina de hablar: manda a Elliot de vuelta a la cueva y el monolito empieza a responder.
func _on_grandma_done() -> void:
	if _active or _solved:
		return
	_active = true
	GameSession.set_flag(FLAG_CALLED)
	_zone.monitoring = true
	Autores.say(["Los autores: la abuela sabía dónde estaba la roca. Solo había que volver."])


func _on_zone_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true
		var now: int = Time.get_ticks_msec()
		if now - _last_hint > 4000:
			_last_hint = now
			_say_hint("E · examinar los anillos" if not _solved else "La roca se apartó: entra en la cueva.")


func _on_zone_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false


func _say_hint(text: String) -> void:
	var presentation := get_parent().get_node_or_null("ChapterPresentation")
	if presentation != null and presentation.has_method("rewrite"):
		presentation.rewrite(text)


func _unhandled_input(event: InputEvent) -> void:
	if _solved or not _near or _layer != null:
		return
	if DialogueManager.visible or ScenePages.busy or get_tree().paused:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_open_panel()


# ---------------------------------------------------------------------------------------------
# Panel de los anillos
# ---------------------------------------------------------------------------------------------
func _open_panel() -> void:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 80
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	column.add_child(_picture(TITLE_FILE, 460.0))
	var hint := _label("Gira los anillos hasta que, bajo la marca de arriba, se cuente el cuento de la niña en orden: de fuera hacia dentro.", 15, Color(0.85, 0.82, 0.74))
	hint.custom_minimum_size = Vector2(720, 0)
	column.add_child(hint)

	# La rueda: tres anillos (cada uno gira sobre su centro) y una marca fija arriba.
	# La rueda va a la izquierda y los tres botones de giro a su costado (derecha), para que Probar y Cerrar queden a la vista.
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 28)
	column.add_child(body)
	var wheel_holder := CenterContainer.new()
	body.add_child(wheel_holder)
	var wheel := Control.new()
	wheel.custom_minimum_size = Vector2(WHEEL_BOX, WHEEL_BOX + WHEEL_TOP)
	wheel_holder.add_child(wheel)
	_ring_rects = []
	var scale_k: float = WHEEL_BOX / float(RING_CANVAS[0])
	var wheel_center := Vector2(WHEEL_BOX * 0.5, WHEEL_TOP + WHEEL_BOX * 0.5)
	for index in 3:
		var rect := TextureRect.new()
		rect.texture = _ring_textures[index]
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side: float = float(RING_CANVAS[index]) * scale_k * float(RING_FIT[index])
		var pivot: Vector2 = RING_CENTER[index] * scale_k * float(RING_FIT[index])
		rect.size = Vector2(side, side)
		rect.position = wheel_center - pivot
		rect.pivot_offset = pivot
		rect.rotation = _angle[index]
		wheel.add_child(rect)
		_ring_rects.append(rect)
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(0, 20)])
	marker.color = Color(0.93, 0.78, 0.38)
	marker.position = Vector2(WHEEL_BOX * 0.5, 0.0)
	wheel.add_child(marker)

	# Un botón por anillo, con su nombre del paquete (ANILLO EXTERIOR / MEDIO / INTERIOR).
	var turns := VBoxContainer.new()
	turns.alignment = BoxContainer.ALIGNMENT_CENTER
	turns.add_theme_constant_override("separation", 18)
	body.add_child(turns)
	for index in 3:
		var turn := _art_button(RING_BUTTON_FILES[index], 230.0, _turn_ring.bind(index))
		turns.add_child(turn)
		if index == 0:
			turn.call_deferred("grab_focus")
	_feedback = _label("", 15, Color(1.0, 0.62, 0.5))
	_feedback.custom_minimum_size = Vector2(720, 22)
	column.add_child(_feedback)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	column.add_child(actions)
	actions.add_child(_art_button(PROBAR_FILE, 190.0, _test))
	actions.add_child(_art_button(CERRAR_FILE, 170.0, _close_panel))


# Botón con imagen (la piedra "Probar" / "Cerrar" del acertijo). Se ilumina al enfocarlo o pasar el ratón.
# Imagen sin función (título, sentido de giro): mantiene su proporción y no bloquea el ratón.
func _picture(path: String, width: float) -> TextureRect:
	var rect := TextureRect.new()
	var texture := load(path) as Texture2D
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(width, width * float(texture.get_height()) / float(texture.get_width()))
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _art_button(path: String, width: float, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	var texture := load(path) as Texture2D
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var ratio: float = float(texture.get_height()) / float(texture.get_width())
	button.custom_minimum_size = Vector2(width, width * ratio)
	button.pressed.connect(action)
	var glow := func(): button.modulate = Color(1.3, 1.18, 0.95)
	var dull := func(): button.modulate = Color.WHITE
	button.focus_entered.connect(glow)
	button.mouse_entered.connect(glow)
	button.focus_exited.connect(dull)
	button.mouse_exited.connect(dull)
	return button


# Símbolo que queda arriba (bajo la marca) en un anillo, según sus pasos y su sentido de giro.
func _top_symbol(index: int) -> String:
	var slot: int = posmod(-int(TURN_DIR[index]) * int(_steps[index]), 5)
	return SYMBOLS_PER_RING[index][slot]


# Un paso del anillo en su sentido (con animación). Las pulsaciones seguidas se acumulan sin descuadrarse.
func _turn_ring(index: int) -> void:
	_steps[index] = posmod(int(_steps[index]) + 1, 5)
	_target[index] = float(_target[index]) + float(TURN_DIR[index]) * STEP
	if _feedback != null:
		_feedback.text = ""
	AudioLandscape.cue(&"clue", global_position)
	var old: Tween = _tweens[index]
	if old != null:
		old.kill()
	# Con el panel abierto el juego está en pausa: el tween debe correr igual.
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_angle.bind(index), float(_angle[index]), float(_target[index]), 0.28)
	_tweens[index] = tween


func _set_angle(value: float, index: int) -> void:
	_angle[index] = value
	if index < _ring_rects.size() and is_instance_valid(_ring_rects[index]):
		(_ring_rects[index] as Control).rotation = value


# Deja los anillos exactamente en la solución (para la roca ya abierta).
func _set_solved_angles() -> void:
	for index in 3:
		var slot: int = (SYMBOLS_PER_RING[index] as Array).find(SOLUTION[index])
		# Arriba queda el símbolo de la posición "slot": hacen falta -dir*pasos = slot (mod 5).
		var steps: int = posmod(-slot * int(TURN_DIR[index]), 5)
		_steps[index] = steps
		_angle[index] = float(TURN_DIR[index]) * float(steps) * STEP
		_target[index] = _angle[index]


func _test() -> void:
	for index in 3:
		if _top_symbol(index) != SOLUTION[index]:
			_feedback.text = WRONG_HINTS[index]
			return
	_solve()


func _solve() -> void:
	_solved = true
	GameSession.set_flag(FLAG_SOLVED)
	AudioLandscape.cue(&"puzzle_complete", to_global(slab_rect.get_center()))
	GameSession.checkpoint(get_parent())
	_close_panel()
	var tween := create_tween()
	tween.tween_property(self, "_slide", slide_distance, 2.0)
	tween.tween_callback(_open_exit_after_slide)
	DialogueManager.show_dialogue([
		"Elliot: La casa de su madre, el bosque, las flores del desvío... y el lobo esperando en el centro.",
		"Elliot: Así empieza el cuento. La roca lo reconoce y se aparta.",
	], "Elliot")
	Autores.say(["Los autores: cada anillo guarda un momento del cuento. La roca solo se abre a quien lo cuenta en orden."])


# La roca terminó de deslizarse: se abre la entrada y, si Elliot sigue ahí, entra por ella.
func _open_exit_after_slide() -> void:
	_enable_exit()
	_say_hint("La entrada de la cueva está abierta. Sigue adelante.")
	# Esperar dos fotogramas de física a que el área empiece a vigilar y comprobar si Elliot ya está dentro.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var exit := get_node_or_null(exit_path)
	if exit != null and exit.has_method("travel"):
		for body in exit.get_overlapping_bodies():
			if body.is_in_group("player"):
				exit.travel()
				break


# Activa la salida de la cueva (nodo ExitCueva). Se usa al resolver y al cargar una partida ya resuelta.
func _enable_exit() -> void:
	var exit := get_node_or_null(exit_path)
	if exit != null:
		exit.set_deferred("monitoring", true)


func _close_panel() -> void:
	for index in 3:
		var running: Tween = _tweens[index]
		if running != null:
			running.kill()
		_tweens[index] = null
	# Al cerrar, los anillos del mundo quedan en su posición final aunque se cierre a mitad de giro.
	for index in 3:
		_angle[index] = _target[index]
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_ring_rects = []
	_feedback = null
	get_tree().paused = false


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Aquí NO se dibuja nada: el acertijo (anillos) solo se ve en el panel cuando Elliot examina la roca.
	# La roca gigante es el Sprite2D "RocaCueva" de la escena (se puede mover o cambiar en el editor).
	# Al resolver el acertijo se desvanece hasta desaparecer.
	var rock := get_node_or_null(rock_path) as CanvasItem
	if rock == null:
		return
	var fade := clampf(1.0 - _slide / maxf(slide_distance, 1.0), 0.0, 1.0)
	rock.modulate.a = fade
	rock.visible = fade > 0.0
