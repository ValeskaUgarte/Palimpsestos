extends Area2D
## MESA DE ESCRITURA (escena 1): el primer puzle del cuento.
##
## Ordena lo que recogiste en el camino: cada objeto de la mochila con lo que significa en la historia.
## Hay 6 parejas (12 cartas). Objetos en la primera fila, significados en la segunda, siempre en el mismo orden.
## Se destapan dos cartas: si son un objeto y su significado, quedan emparejadas; si no, se vuelven a cubrir.
## No hay límite de intentos. Si te falta algún objeto, la mesa no se abre hasta encontrarlo.
##
## Al resolverla se abre la salida hacia la escena 2 (ChapterExit) y se activa el portal. Queda guardado.

const FLAG_SOLVED := "mesa_escena1"

signal solved
const CARD_SIZE := Vector2(176, 150)

## Objetos de la mochila que se usan (en orden). Todos deben estar en la mochila para abrir la mesa.
@export var pair_items: PackedStringArray = PackedStringArray(["carta", "mapa", "flores", "pluma", "huella", "pastel"])
## Lo que significa cada objeto en el cuento (mismo orden que pair_items). \n parte la línea.
@export var pair_meanings: PackedStringArray = PackedStringArray([
	"Alguien le pidió\nel camino corto",
	"El camino de las flores\nera un rodeo",
	"Algo la apartó\ndel sendero",
	"Los pájaros la\ndistrajeron",
	"Algo grande\nla siguió",
	"Iba a llevarle el pastel\na alguien",
])
@export var back_texture: Texture2D = preload("res://assets/ui/pack_gotico/carta_dorso.png")
@export var table_texture: Texture2D = preload("res://assets/ui/pack_gotico/mesa.png")
## Ancho de la mesa en el escenario (la altura sale de la proporción de la imagen).
@export var table_width: float = 300.0
@export var exit_path: NodePath = ^"../ChapterExit"
@export var portal_path: NodePath = ^"../StoryPortal"

var _solved: bool = false
var _near: bool = false
var _busy: bool = false
var _layer: CanvasLayer = null
var _grid: GridContainer = null
var _deck: Array = []   # cada carta: {pair, kind (0 objeto / 1 significado), button, revealed, matched}
var _open: Array = []   # índices de las cartas destapadas esperando pareja
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
		# La salida a la escena 2 queda cerrada hasta ordenar la mesa.
		exit.set_deferred("monitoring", false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true
		if _solved:
			_say("La mesa ya está ordenada. El camino sigue hacia la casa.")
		else:
			_say("Mesa de escritura · E para ordenar lo que encontraste")


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
	for id in pair_items:
		if GameSession.item_count(id) <= 0:
			missing.append(StoryItems.info(id)["name"])
	if not missing.is_empty():
		DialogueManager.show_dialogue([
			"Elliot: Todavía no tengo suficiente para ordenar esto.",
			"Elliot: Me faltan: %s." % ", ".join(missing),
		], "Elliot")
		return
	_open_panel()


# ---------------------------------------------------------------------------------------------
# PANEL DE LAS CARTAS
# ---------------------------------------------------------------------------------------------
func _open_panel() -> void:
	_busy = false
	_open.clear()
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
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(_label("Lo que Elliot ha reunido", 30, Color(0.96, 0.88, 0.68)))
	column.add_child(_label("Une cada hallazgo con lo que crees que significó. Son tus conclusiones, no las del cuento.", 16, Color(0.85, 0.82, 0.74)))
	_grid = GridContainer.new()
	_grid.columns = pair_items.size()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(_grid)
	var close := Button.new()
	close.text = "Cerrar"
	UIKit.skin_by_text(close, 64.0)
	close.pressed.connect(_close_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(close)
	column.add_child(row)
	_deal()


func _deal() -> void:
	_deck.clear()
	_open.clear()
	_busy = false
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	# Fila 1: los hallazgos. Fila 2: lo que Elliot deduce de cada uno (la carta i y la i+N son pareja).
	for pair in pair_items.size():
		_deck.append({"pair": pair, "kind": 0, "revealed": false, "matched": false, "button": null})
	for pair in pair_meanings.size():
		_deck.append({"pair": pair, "kind": 1, "revealed": false, "matched": false, "button": null})
	for index in _deck.size():
		var button := Button.new()
		button.custom_minimum_size = CARD_SIZE
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_card_pressed.bind(index))
		_grid.add_child(button)
		_deck[index]["button"] = button
		_paint(index)
	if not _deck.is_empty():
		(_deck[0]["button"] as Button).call_deferred("grab_focus")


func _paint(index: int) -> void:
	var card: Dictionary = _deck[index]
	var button: Button = card["button"]
	var pair: int = card["pair"]
	if not card["revealed"] and not card["matched"]:
		button.icon = back_texture
		button.text = "" if back_texture != null else "?"
		button.modulate = Color.WHITE
		return
	if card["kind"] == 0:
		var id: String = pair_items[pair]
		var texture := _item_texture(id)
		button.icon = texture
		button.text = "" if texture != null else StoryItems.info(id)["name"]
	else:
		button.icon = null
		button.text = pair_meanings[pair]
	button.modulate = Color(0.75, 1.0, 0.88) if card["matched"] else Color.WHITE


func _item_texture(id: String) -> Texture2D:
	var path: String = StoryItems.info(id)["icon"]
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _on_card_pressed(index: int) -> void:
	if _solved or _busy or _layer == null:
		return
	var card: Dictionary = _deck[index]
	if card["revealed"] or card["matched"]:
		return
	card["revealed"] = true
	_paint(index)
	AudioLandscape.cue(&"page_turn")
	_open.append(index)
	if _open.size() < 2:
		return
	_busy = true
	var first: int = _open[0]
	var second: int = _open[1]
	var a: Dictionary = _deck[first]
	var b: Dictionary = _deck[second]
	if a["pair"] == b["pair"] and a["kind"] != b["kind"]:
		a["matched"] = true
		b["matched"] = true
		_paint(first)
		_paint(second)
		_open.clear()
		_busy = false
		if _all_matched():
			_solve()
		return
	AudioLandscape.cue(&"rune_error", global_position)
	await get_tree().create_timer(0.9, true).timeout
	if _layer == null or not is_instance_valid(self):
		return
	a["revealed"] = false
	b["revealed"] = false
	_paint(first)
	_paint(second)
	_open.clear()
	_busy = false


func _all_matched() -> bool:
	for card in _deck:
		if not card["matched"]:
			return false
	return true


func _solve() -> void:
	_solved = true
	_close_panel()
	GameSession.set_flag(FLAG_SOLVED)
	AudioLandscape.cue(&"puzzle_complete", global_position)
	_open_exit()
	_activate_portal()
	GameSession.checkpoint(get_parent())
	DialogueManager.show_dialogue([
		"Elliot: Alguien mandó a la niña por el camino corto. Algo la apartó con flores y pájaros. Algo grande la siguió.",
		"Elliot: No sé quién es ni cómo llegué aquí, pero ahora sé por dónde seguir.",
	], "Elliot")
	Autores.say(["Los autores: así empieza el engaño. Un rodeo que parece un regalo."])
	solved.emit()


func _open_exit() -> void:
	var exit := get_node_or_null(exit_path)
	if exit != null:
		exit.set_deferred("monitoring", true)


func _activate_portal() -> void:
	var portal := get_node_or_null(portal_path)
	if portal != null and portal.has_method("activate"):
		portal.activate()


func _close_panel() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_grid = null
	_deck.clear()
	_open.clear()
	get_tree().paused = false


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


# Mensaje corto en pantalla (no interrumpe como un diálogo).
func _say(text: String) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_whisper < 4000:
		return
	_last_whisper = now
	var presentation := get_parent().get_node_or_null("ChapterPresentation")
	if presentation != null and presentation.has_method("rewrite"):
		presentation.rewrite(text)


func _draw() -> void:
	# Mesa de piedra: con imagen si la hay, si no, una losa oscura para ubicarla en el escenario.
	if table_texture != null:
		var ratio := float(table_texture.get_height()) / float(table_texture.get_width())
		draw_texture_rect(table_texture, Rect2(-table_width * 0.5, -table_width * ratio, table_width, table_width * ratio), false)
	else:
		var glow := Color(0.65, 0.88, 0.79, 0.35) if _solved else Color(0.2, 0.19, 0.17, 0.9)
		draw_rect(Rect2(-95, -44, 190, 44), glow)
		draw_rect(Rect2(-95, -44, 190, 44), Color(0.5, 0.44, 0.32, 0.8), false, 2.0)
