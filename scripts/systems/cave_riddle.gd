extends Node2D
## ACERTIJO DE LA CUEVA (escena 2): EL ORDEN DE LO QUE PASÓ.
##
## La roca de la entrada de la cueva guarda el orden en que la niña se perdió del camino.
## Elliot arrastra los hallazgos del diario a la ranura, de lo primero a lo último:
##     cesta (pastel) → flores → pájaros (pluma) → huella del lobo.
## Los demás hallazgos (vino, poción) son de despiste.
##
## Controles: arrastra o pulsa una pieza para enviarla a la ranura; pulsa una de la ranura para devolverla.
## "Borrar" quita la última, "Probar" comprueba, "Cerrar" cierra. Con mando: A elige, stick/cruceta se mueven.
## Las piezas son las imágenes de assets/ui/diario/. Los textos son paneles con texto escrito en código.

## ACERTIJO DE LA CUEVA (escena 2): LA PALABRA DEL LOBO.
##
## Una roca enorme tapa la boca de la cueva. Lleva grabada una palabra griega que describe lo que se
## esconde tras la dulzura:   πονηρός   (ponērós, "malvado, astuto").
## Las pistas las dan los hallazgos y lo que dicen los personajes (Ethan, el cartel de la cueva).
##
## Cómo se juega: la roca está despierta desde el principio. En la cueva, E examina la roca y se abre
## el panel de piedras. Arrastra las letras a la ranura (o púlsalas para enviarlas), "Borrar" quita la
## última, "Probar" comprueba la palabra, "Cerrar" cierra el panel.
##
## Imágenes: assets/ui/riddle/ (piedras, ranura, botones). Los banners son paneles en blanco con el texto
## escrito en código: cambia txt_titulo, txt_pista_1, etc. en el Inspector para cambiar las pistas.

## ACERTIJO DE LA CUEVA (escena 2): LA PALABRA GRIEGA.
##
## Una roca enorme tapa la boca de la cueva. La respuesta es el título del juego en griego:

## formada por dos raíces:   πάλιν (pálin) = "de nuevo"   +   ψάω / ψῆν (psáō / psên) = "raspar, borrar frotando".
##
## Cómo se descubre (todo se puede repetir las veces que haga falta):
##   - La inscripción junto a la cueva (ClueSign) muestra las dos raíces.
##   - Ethan y Caperucita (repeatable) dan el significado de cada una.
##   - La Abuelita manda a Elliot de vuelta a la cueva: al hablar con ella la roca "despierta" y despierta la emboscada.
## Cuando la roca está despierta, junto a la cueva se pulsa E y se abre el panel de piedras.
##   - Arrastra las piedras griegas a la ranura (o púlsalas para mandarlas a la ranura).
##   - Pulsa una piedra de la ranura para devolverla a la bandeja.
##   - "Borrar" quita la última letra, "Probar" comprueba la palabra, "Cerrar" cierra el panel.
##
## Imágenes: todas están en assets/ui/riddle/. En el Inspector del nodo CaveRiddle puedes cambiar cualquier
## textura (banners, botones, ranura y las 17 piedras, en el orden de stone_letters).
##
## Al resolverlo la roca se desvanece, la cueva queda abierta y se habilita la salida (ChapterExit).

signal solved

const FLAG_ARMED := "cueva_activada"
const FLAG_SOLVED := "cueva_resuelta"
const LEFT_W := 520.0
const TRAY_W := 360.0
const TRAY_STONE := Vector2(46, 71)
const SLOT_STONE := Vector2(40, 62)
const BUTTON_W := 160.0
const STONE_FILES := [
	"res://assets/ui/diario/item_pastel.png",
	"res://assets/ui/diario/item_flores.png",
	"res://assets/ui/diario/item_pluma.png",
	"res://assets/ui/diario/item_huella.png",
	"res://assets/ui/diario/item_vino.png",
	"res://assets/ui/diario/item_pocion.png",
]

## Salida que se abre al resolver la roca. Vacío = esta roca no controla ninguna salida.
@export var exit_path: NodePath = ^"../ChapterExit"
## Personaje que despierta la roca al hablar con él. Vacío = la roca está despierta desde el principio.
@export var guide_path: NodePath = ^"../Abuelita"
## Respuesta correcta (en griego). Se comparan las letras de las piedras, sin tildes ni mayúsculas.
## Orden correcto: cesta → flores → pluma → huella.
@export var answer: String = "cfph"
## Código de cada pieza, en el mismo orden que stone_textures.
## c = cesta (pastel), f = flores, p = pluma, h = huella, v = vino (despiste), q = poción (despiste).
@export var stone_letters: PackedStringArray = PackedStringArray(["c", "f", "p", "h", "v", "q"])
## Imagen de cada piedra. Vacío = usa assets/ui/riddle/piedra_XX.png. Arrastra un PNG nuevo aquí para cambiarla.
@export var stone_textures: Array[Texture2D] = []
## true = las piedras empiezan revueltas en la bandeja.
@export var shuffle_stones: bool = true
@export var tex_titulo: Texture2D = preload("res://assets/ui/pack_gotico/panel_ancho.png")
@export var tex_intro: Texture2D = preload("res://assets/ui/pack_gotico/panel_1.png")
@export var tex_pista_1: Texture2D = preload("res://assets/ui/pack_gotico/panel_2.png")
@export var tex_pista_2: Texture2D = preload("res://assets/ui/pack_gotico/panel_3.png")
@export var tex_pregunta: Texture2D = preload("res://assets/ui/pack_gotico/panel_4.png")
@export var txt_titulo: String = "La roca guarda el orden de lo que pasó"
@export var txt_intro: String = "Ordena lo que le ocurrió a la niña, de lo primero a lo último:"
@export var txt_pista_1: String = "Ethan: primero la cesta, después lo que la distrajo del camino."
@export var txt_pista_2: String = "Cartel de la cueva: «Sigue el camino. Los atajos no son de fiar.»"
@export var txt_pregunta: String = "¿En qué orden se perdió la niña?"
@export var tex_ranura: Texture2D = preload("res://assets/ui/riddle/panel_respuesta.png")
@export var tex_borrar: Texture2D = preload("res://assets/ui/riddle/btn_borrar.png")
@export var tex_probar: Texture2D = preload("res://assets/ui/riddle/btn_probar.png")
@export var tex_cerrar: Texture2D = preload("res://assets/ui/riddle/btn_cerrar.png")
## Zona de la boca de la cueva (X, Y, ancho, alto) donde está la roca.
@export var cave_mouth: Rect2 = Rect2(4230, -240, 270, 280)
## Altura de la roca agrandada que tapa la cueva.
@export var rock_height: float = 300.0
## Imagen de las rocas (la misma hoja que usa la escena 1) y recorte de la pila alta de piedras.
@export var rock_texture: Texture2D = preload("res://assets/props/obstaculos.png")
@export var rock_region: Rect2 = Rect2(10, 1, 222, 181)
## Zona del camino donde se puede examinar la roca (X, Y de los pies del jugador).
@export var examine_position: Vector2 = Vector2(4365, 272)
@export var examine_radius: float = 170.0
@export var ambush_group: StringName = &"emboscada"

var _armed: bool = false
var _solved: bool = false
var _near: bool = false
var _rock_alpha: float = 1.0
var _rock_sink: float = 0.0
var _rock_shake: float = 0.0
var _dust: float = 0.0
var _clock: float = 0.0
var _last_whisper: int = -10000
var _layer: CanvasLayer = null
var _slot_panel: Control = null
var _slot_box: HFlowContainer = null
var _tray: HFlowContainer = null
var _hint: Label = null
var _feedback: Label = null
var _buttons_row: HBoxContainer = null


func _ready() -> void:
	var exit := _exit_node()
	var guide := get_node_or_null(guide_path) if String(guide_path) != "" else null
	if guide != null and guide.has_signal("conversation_finished"):
		guide.conversation_finished.connect(_on_guide_spoke)
	# Zona para examinar la roca.
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = examine_position
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(examine_radius * 2.0, 400.0)
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(_on_zone_entered)
	area.body_exited.connect(_on_zone_exited)
	add_child(area)

	# Lo que ya se resolvió o se activó en partidas anteriores se recuerda (GameSession.progress).
	if GameSession.has_flag(FLAG_SOLVED):
		_solved = true
		_rock_alpha = 0.0
		_remove_ambush()
		if exit != null:
			exit.set_deferred("monitoring", true)
		return
	if exit != null:
		exit.set_deferred("monitoring", false)
	if GameSession.has_flag(FLAG_ARMED) or String(guide_path) == "":
		_armed = true
		_set_ambush(true)
	else:
		_set_ambush(false)


func _exit_node() -> Node:
	if String(exit_path) == "":
		return null
	return get_node_or_null(exit_path)


# Los enemigos de la emboscada duermen hasta que la abuela manda volver.
func _set_ambush(awake: bool) -> void:
	for enemy in get_tree().get_nodes_in_group(ambush_group):
		if not is_instance_valid(enemy):
			continue
		enemy.visible = awake
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED


func _remove_ambush() -> void:
	for enemy in get_tree().get_nodes_in_group(ambush_group):
		if is_instance_valid(enemy):
			enemy.queue_free()


func _on_guide_spoke() -> void:
	if _armed or _solved:
		return
	_armed = true
	GameSession.set_flag(FLAG_ARMED)
	_set_ambush(true)
	_say("Vuelve a la cueva.", true)


func _on_zone_entered(body: Node2D) -> void:
	if _solved or not body.is_in_group("player"):
		return
	_near = true
	if _armed:
		_say("E · examinar la roca de la cueva.")
	else:
		_say("La roca guarda una palabra. Alguien por aquí sabrá qué significa.")


func _on_zone_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false


func _unhandled_input(event: InputEvent) -> void:
	if _solved or not _near or _layer != null or not _armed:
		return
	if DialogueManager.visible or ScenePages.busy or get_tree().paused:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_open_panel()


# ---------------------------------------------------------------------------------------------
# PANEL DE LAS PIEDRAS (usa las imágenes de assets/ui/riddle/)
# ---------------------------------------------------------------------------------------------
func _open_panel() -> void:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 80
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 26)
	center.add_child(root)

	# Columna izquierda: banners, ranura y botones.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	left.add_child(_banner(tex_titulo, txt_titulo, 64.0, 22))
	left.add_child(_banner(tex_intro, txt_intro, 50.0, 16))
	left.add_child(_banner(tex_pista_1, txt_pista_1, 50.0, 15))
	left.add_child(_banner(tex_pista_2, txt_pista_2, 50.0, 15))
	left.add_child(_banner(tex_pregunta, txt_pregunta, 46.0, 17))
	left.add_child(_build_slot())
	_feedback = _label("", 16, Color(1.0, 0.62, 0.5))
	left.add_child(_feedback)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	left.add_child(buttons)
	_buttons_row = buttons
	buttons.add_child(_button(tex_borrar, _erase_last))
	buttons.add_child(_button(tex_probar, _try_answer))
	buttons.add_child(_button(tex_cerrar, _close_panel))

	# Columna derecha: la bandeja con las piedras.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(TRAY_W, 0)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	right.add_child(_label("Piedras · arrástralas a la ranura", 16, Color(0.85, 0.82, 0.74)))
	_tray = HFlowContainer.new()
	_tray.custom_minimum_size = Vector2(TRAY_W, 0)
	_tray.add_theme_constant_override("h_separation", 6)
	_tray.add_theme_constant_override("v_separation", 6)
	right.add_child(_tray)
	_build_stones()
	_after_change()
	_focus_first_stone()


func _picture(texture: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture != null:
		picture.custom_minimum_size = Vector2(LEFT_W, LEFT_W * float(texture.get_height()) / float(texture.get_width()))
	return picture


func _build_slot() -> Control:
	_slot_panel = Control.new()
	var height := LEFT_W * float(tex_ranura.get_height()) / float(tex_ranura.get_width())
	_slot_panel.custom_minimum_size = Vector2(LEFT_W, height)
	_slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _picture(tex_ranura)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.custom_minimum_size = Vector2.ZERO
	_slot_panel.add_child(frame)
	_slot_box = HFlowContainer.new()
	_slot_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_box.offset_left = 40
	_slot_box.offset_right = -40
	_slot_box.offset_top = 16
	_slot_box.offset_bottom = -16
	_slot_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_slot_box.add_theme_constant_override("h_separation", 6)
	_slot_box.add_theme_constant_override("v_separation", 6)
	_slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_panel.add_child(_slot_box)
	_hint = _label("Arrastra aquí las piedras en orden", 18, Color(0.7, 0.66, 0.6))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slot_panel.add_child(_hint)
	return _slot_panel


# Banner de panel en blanco con el texto encima (el texto se puede cambiar sin tocar la imagen).
func _banner(texture: Texture2D, text: String, height: float, font_size: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(LEFT_W, height)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	var label := _label(text, font_size, Color(0.96, 0.9, 0.74))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 18
	label.offset_right = -18
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	return holder


func _button(texture: Texture2D, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(BUTTON_W, BUTTON_W * float(texture.get_height()) / float(texture.get_width()))
	button.pressed.connect(action)
	return button


func _build_stones() -> void:
	var indices: Array = range(stone_letters.size())
	if shuffle_stones:
		indices.shuffle()
	for slot_order in indices.size():
		var index: int = indices[slot_order]
		var stone := RiddleStone.new()
		stone.letter = stone_letters[index]
		stone.order = slot_order
		stone.texture = _stone_texture(index)
		stone.custom_minimum_size = TRAY_STONE
		stone.clicked.connect(_on_stone_clicked)
		stone.released_at.connect(_on_stone_released)
		_tray.add_child(stone)


func _stone_texture(index: int) -> Texture2D:
	if index < stone_textures.size() and stone_textures[index] != null:
		return stone_textures[index]
	if index < STONE_FILES.size():
		return load(STONE_FILES[index]) as Texture2D
	return null


func _on_stone_clicked(stone: RiddleStone) -> void:
	if stone.get_parent() == _slot_box:
		_return_stone(stone)
	else:
		_place_stone(stone, _slot_box.get_child_count())
	_after_change()
	# Al mover una piedra el foco se pierde: se devuelve a la piedra para seguir con el mando.
	stone.call_deferred("grab_focus")


func _focus_first_stone() -> void:
	for child in _tray.get_children():
		if child is RiddleStone:
			(child as RiddleStone).call_deferred("grab_focus")
			return
	# Si no quedan piedras en la bandeja, el foco va a "Probar" (segundo botón de la fila).
	if _buttons_row != null and _buttons_row.get_child_count() > 1:
		_buttons_row.get_child(1).call_deferred("grab_focus")


func _on_stone_released(stone: RiddleStone, point: Vector2) -> void:
	if _slot_panel.get_global_rect().has_point(point):
		_place_stone(stone, _insert_index(point.x))
	else:
		_return_stone(stone)
	_after_change()


# Índice de inserción en la ranura según la X donde se suelta la piedra.
func _insert_index(x: float) -> int:
	var index := 0
	for child in _slot_box.get_children():
		if (child as Control).get_global_rect().get_center().x < x:
			index += 1
	return index


func _place_stone(stone: RiddleStone, index: int) -> void:
	stone.custom_minimum_size = SLOT_STONE
	_move_to(stone, _slot_box)
	_slot_box.move_child(stone, clampi(index, 0, _slot_box.get_child_count() - 1))


func _return_stone(stone: RiddleStone) -> void:
	stone.custom_minimum_size = TRAY_STONE
	_move_to(stone, _tray)
	# La bandeja se mantiene en el orden original de las piedras.
	var index := 0
	for child in _tray.get_children():
		if child is RiddleStone and child != stone and child.order < stone.order:
			index += 1
	_tray.move_child(stone, index)


func _move_to(stone: RiddleStone, target: Node) -> void:
	stone.top_level = false
	stone.z_index = 0
	var previous := stone.get_parent()
	if previous != null:
		previous.remove_child(stone)
	target.add_child(stone)


func _after_change() -> void:
	if _hint != null:
		_hint.visible = _slot_box.get_child_count() == 0
	if _feedback != null:
		_feedback.text = ""


func _erase_last() -> void:
	if _slot_box == null or _slot_box.get_child_count() == 0:
		return
	_return_stone(_slot_box.get_child(_slot_box.get_child_count() - 1) as RiddleStone)
	_after_change()


func _try_answer() -> void:
	if _slot_box == null:
		return
	var typed := ""
	for child in _slot_box.get_children():
		typed += (child as RiddleStone).letter
	if typed.is_empty():
		if _feedback != null:
			_feedback.text = "Coloca primero las piedras en la ranura."
		return
	if is_correct(typed):
		_close_panel()
		_solve()
		return
	if _feedback != null:
		_feedback.text = "La piedra no responde. Une las dos raíces."
	_rock_shake = 1.0
	AudioLandscape.cue(&"rune_error", to_global(cave_mouth.get_center()))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _close_panel() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_slot_panel = null
	_slot_box = null
	_tray = null
	_buttons_row = null
	_hint = null
	_feedback = null
	get_tree().paused = false


## true si el texto es la respuesta: se ignoran tildes, mayúsculas, espacios y la diferencia σ / ς.
## Las tildes, las mayúsculas y la diferencia σ / ς no importan.
func is_correct(text: String) -> bool:
	var given: String = _normalize(text)
	if given.is_empty():
		return false
	var wanted: String = _normalize(answer)
	return given == wanted


static func _normalize(text: String) -> String:
	var map := {"ά": "α", "έ": "ε", "ή": "η", "ί": "ι", "ΐ": "ι", "ϊ": "ι", "ό": "ο", "ύ": "υ", "ΰ": "υ", "ϋ": "υ", "ώ": "ω", "ς": "σ",
		"ᾶ": "α", "ῆ": "η", "ῖ": "ι", "ῦ": "υ", "ῶ": "ω", "ὰ": "α", "ὲ": "ε", "ὴ": "η", "ὶ": "ι", "ὸ": "ο", "ὺ": "υ", "ὼ": "ω"}
	var out := ""
	for character in text.to_lower().strip_edges():
		if character == " ":
			continue
		out += map.get(character, character)
	return out


func _solve() -> void:
	_solved = true
	_near = false
	GameSession.set_flag(FLAG_SOLVED)
	AudioLandscape.hush()
	AudioLandscape.cue(&"puzzle_complete", to_global(cave_mouth.get_center()))
	_say("La roca cede. La cueva se abre.", true)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "_rock_alpha", 0.0, 2.0)
	tween.tween_property(self, "_rock_sink", 46.0, 2.0)
	tween.tween_property(self, "_dust", 1.0, 0.4)
	tween.chain().tween_property(self, "_dust", 0.0, 1.6)
	var exit := _exit_node()
	if exit != null:
		exit.set_deferred("monitoring", true)
	GameSession.checkpoint(get_parent())
	DialogueManager.show_dialogue([
		"Elliot: La cesta, las flores, los pájaros y después la huella. Así se perdió la niña.",
		"Elliot: Nadie se lo dijo. Ella sigue creyendo que el camino era el de siempre.",
	], "Elliot")
	Autores.say(["Los autores: en la versión que todos recuerdan, esa parte nunca se contó."])
	solved.emit()


# Mensaje corto en pantalla (no interrumpe como un diálogo). Evita repetirse en cada paso.
func _say(text: String, force: bool = false) -> void:
	var now: int = Time.get_ticks_msec()
	if not force and now - _last_whisper < 4000:
		return
	_last_whisper = now
	var presentation := get_parent().get_node_or_null("ChapterPresentation")
	if presentation != null and presentation.has_method("rewrite"):
		presentation.rewrite(text)


func _process(delta: float) -> void:
	_clock += delta
	_rock_shake = maxf(_rock_shake - delta * 2.2, 0.0)
	queue_redraw()


func _draw() -> void:
	if _rock_alpha <= 0.01 or rock_texture == null:
		_draw_dust()
		return
	# La roca agrandada tapa la boca de la cueva: apoyada en el suelo de la cueva y centrada en ella.
	var factor: float = rock_height / rock_region.size.y
	var size := rock_region.size * factor
	var shake: float = sin(_clock * 70.0) * 7.0 * _rock_shake
	var origin := Vector2(cave_mouth.get_center().x - size.x * 0.5 + shake, cave_mouth.end.y - size.y + _rock_sink + 10.0)
	var glow: float = 0.5 + 0.5 * sin(_clock * 1.6)
	var tint := Color(1, 1, 1, _rock_alpha)
	if _armed and not _solved:
		tint = Color(1.0, 0.97 + 0.03 * glow, 1.0, _rock_alpha)
	draw_texture_rect_region(rock_texture, Rect2(origin, size), rock_region, tint)
	_draw_dust()


func _draw_dust() -> void:
	if _dust <= 0.01:
		return
	var base: Vector2 = Vector2(cave_mouth.get_center().x, cave_mouth.end.y)
	for index in 14:
		var angle: float = float(index) * 0.9
		var spread: float = (float(index) - 7.0) * 26.0
		var rise: float = (1.0 - _dust) * 40.0 + float(index % 4) * 8.0
		draw_circle(base + Vector2(spread + sin(angle) * 10.0, -rise - 18.0 * float(index % 3)), 14.0 + float(index % 5) * 3.0, Color(0.6, 0.57, 0.52, 0.28 * _dust))
