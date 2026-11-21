@tool
class_name StoryPickup
extends Area2D
## OBJETO, PISTA O TABLERO DEL CAMINO. Es un nodo normal de la escena: se ve en el editor, lo arrastras
## con el ratón para moverlo y todo se cambia en el Inspector (sin tocar código).
##  - Un OBJETO (item_id) se recoge al pasar sobre él (una sola vez, queda guardado).
##  - Una PISTA o un TABLERO (sin item_id) se lee con E cuando estás cerca. Se puede leer cuantas veces quieras.
##    Si tiene cartel (poster_texture) se muestra esa imagen grande; si no, el texto de lines.
## Para agregar uno nuevo: duplica uno (Ctrl+D) dentro del nodo RutaCuento, muévelo y cambia sus datos.
## Importante: cada uno necesita un "key" distinto (así el juego recuerda qué objeto ya se recogió).

## Id del objeto de la mochila (pastel, vino, flores, pluma, huella, carta, mapa, pocion). Vacío = pista o tablero.
@export var item_id: String = "":
	set(value):
		item_id = value
		queue_redraw()
@export var amount: int = 1
## Texto que se lee con E (una línea por mensaje). Se ignora si hay cartel.
@export var lines: Array[String] = []
## Frases de los autores que se oyen al recoger un objeto (vacío = ninguna).
@export var author_lines: Array[String] = []
## Identificador único para guardar la partida. Si lo dejas vacío se usa el nombre del nodo.
@export var key: String = ""
## Imagen del objeto, tablero o pista (vacío = la del objeto, o un tablero por defecto). Mejor PNG con fondo transparente.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		queue_redraw()
## Ancho con el que se dibuja (el alto sigue la proporción de la imagen).
@export var draw_width: float = 72.0:
	set(value):
		draw_width = value
		queue_redraw()
## Cartel grande que se muestra al pulsar E (tablero con anuncio).
@export var poster_texture: Texture2D

## Zona de cada tablero donde se "clava" el anuncio (fracciones del dibujo: x, y, ancho, alto).
## Si pones un tablero nuevo con otra imagen, añade aquí su nombre de archivo (sin .png).
const POSTER_FACES := {
	"cartel_tablero": Rect2(0.22, 0.36, 0.56, 0.34),
	"cartel_flechas": Rect2(0.06, 0.17, 0.88, 0.40),
	"tablero_flechas": Rect2(0.12, 0.22, 0.76, 0.40),
	"tablero_1": Rect2(0.12, 0.2, 0.76, 0.5),
	"tablero_2": Rect2(0.2, 0.25, 0.6, 0.45),
}
const DEFAULT_POSTER_FACE := Rect2(0.2, 0.25, 0.6, 0.4)

var _taken: bool = false
var _near: bool = false
var _base_y: float = 0.0
var _clock: float = 0.0
var _icon: Texture2D = null
var _last_hint: int = -100000

## Compatibilidad: rutas en texto (las usa el modo antiguo de StoryTrail). Si las rellenas, se cargan en _ready.
var icon_path: String = ""
var poster_path: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 70.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if icon_texture == null and icon_path != "" and ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path) as Texture2D
	if poster_texture == null and poster_path != "" and ResourceLoader.exists(poster_path):
		poster_texture = load(poster_path) as Texture2D
	_icon = icon_texture
	if _icon == null and item_id != "":
		var path: String = StoryItems.info(item_id)["icon"]
		if path != "" and ResourceLoader.exists(path):
			_icon = load(path) as Texture2D
	if _icon == null:
		_icon = load("res://assets/ui/diario/tablero_1.png") as Texture2D
	if key == "":
		key = "%s_%s" % [get_tree().current_scene.name if get_tree().current_scene != null else "", name]
	_base_y = position.y
	# Tableros y pistas (sin objeto) van por delante de los personajes (z_index 1): Elliot pasa por detrás.
	if item_id == "":
		z_index = 2
	if item_id != "" and GameSession.has_flag("pick:" + key):
		queue_free()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clock += delta
	if item_id != "":
		position.y = _base_y + sin(_clock * 2.6) * 3.0
	queue_redraw()


func _draw() -> void:
	var texture: Texture2D = icon_texture if Engine.is_editor_hint() else _icon
	if texture != null:
		var ratio := float(texture.get_height()) / float(texture.get_width())
		var width := draw_width
		draw_texture_rect(texture, Rect2(-width * 0.5, -width * ratio, width, width * ratio), false)
		if texture.resource_path.contains("flechas"):
			_draw_pinned_poster(texture, width, ratio)
		if Engine.is_editor_hint():
			_draw_editor_tag(-width * ratio)
		elif item_id == "" and _near and not Mochila.poster_open():
			draw_string(ThemeDB.fallback_font, Vector2(-60, -width * ratio - 12), "E · leer", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(0.98, 0.92, 0.7))
		return
	draw_rect(Rect2(-20, -28, 40, 52), Color(0.86, 0.79, 0.62))
	draw_rect(Rect2(-20, -28, 40, 52), Color(0.4, 0.3, 0.18), false, 2.0)
	if Engine.is_editor_hint():
		_draw_editor_tag(-28.0)


# El anuncio del tablero se ve CLAVADO sobre el propio tablero (también en el editor), y se lee grande con E.
func _draw_pinned_poster(board: Texture2D, width: float, ratio: float) -> void:
	if item_id != "" or poster_texture == null:
		return
	var board_name: String = board.resource_path.get_file().get_basename()
	var face: Rect2 = POSTER_FACES.get(board_name, DEFAULT_POSTER_FACE)
	var height := width * ratio
	var area := Rect2(-width * 0.5 + face.position.x * width, -height + face.position.y * height, face.size.x * width, face.size.y * height)
	var fit := minf(area.size.x / float(poster_texture.get_width()), area.size.y / float(poster_texture.get_height()))
	var size := Vector2(poster_texture.get_width(), poster_texture.get_height()) * fit
	var center := area.get_center()
	draw_set_transform(center, -0.03, Vector2.ONE)
	draw_rect(Rect2(-size * 0.5 + Vector2(2, 3), size), Color(0, 0, 0, 0.35))
	draw_texture_rect(poster_texture, Rect2(-size * 0.5, size), false)
	draw_circle(Vector2(0, -size.y * 0.5 + 3), 2.5, Color(0.25, 0.2, 0.12))  # la chincheta
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Solo en el editor: el nombre del nodo sobre el dibujo y un círculo con la zona donde se activa.
func _draw_editor_tag(top: float) -> void:
	draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 32, Color(0.3, 1.0, 0.6, 0.5), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-80, top - 8.0), String(name), HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.4, 1.0, 0.7))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if item_id == "":
		_near = true
		var now: int = Time.get_ticks_msec()
		if now - _last_hint > 4000:
			_last_hint = now
			var presentation := get_parent().get_node_or_null("ChapterPresentation")
			if presentation != null and presentation.has_method("rewrite"):
				presentation.rewrite("E · leer")
		return
	_pick_item()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false
		# Al alejarte del tablero el cartel se cierra solo (los de la escena usan poster_texture, no poster_path).
		if poster_texture != null or poster_path != "":
			Mochila.hide_poster()


func _unhandled_input(event: InputEvent) -> void:
	if not _near or DialogueManager.visible or ScenePages.busy or get_tree().paused:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if Mochila.poster_open():
			Mochila.hide_poster()
		else:
			_read()


func _read() -> void:
	if poster_texture != null:
		Mochila.show_poster_texture(poster_texture)
	elif not lines.is_empty():
		DialogueManager.show_dialogue(lines.duplicate(), "", null)


func _pick_item() -> void:
	if _taken:
		return
	_taken = true
	GameSession.set_flag("pick:" + key)
	var first_time: bool = GameSession.item_count(item_id) == 0
	GameSession.add_item(item_id, amount)
	Mochila.show_found(item_id, first_time, GameSession.item_count(item_id))
	if not author_lines.is_empty():
		Autores.say(author_lines)
	set_deferred("monitoring", false)
	visible = false
	queue_free()
