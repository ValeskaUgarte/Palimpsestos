extends Control
## MAPA DEL JUEGO. Tiene DOS vistas:
##   1) VISTA DE CUENTO (STORY): solo el mapa del cuento que se está jugando (Cuento I · Caperucita Roja), grande y centrado,
##      con el trayecto que Elliot lleva recorrido iluminado y un punto por cada escena. Es la que se ve DENTRO del juego
##      (botón "Mapa" / tecla M) y la que se abre al elegir el cuento I desde la vista de todos los cuentos.
##   2) VISTA DE TODOS LOS CUENTOS (OVERVIEW): la que sale desde el menú de inicio. Muestra los 9 cuentos en una cuadrícula.
##      El cuento I (Caperucita) está desbloqueado desde el principio; cada uno de los demás se desbloquea al terminar el anterior
##      (GameSession.story_unlocked). Un cuento bloqueado muestra su candado (mapa_bloqN.png); al desbloquearse, su mapa (mapa_cuentoN.png).
##   - Elegir una escena: clic sobre su punto, o A con el mando / Enter.
##   - Volver: el botón Volver, Start o Esc. Dentro del juego cierra el mapa; desde el menú, en la vista de cuento vuelve a
##     la vista de todos los cuentos, y en esta última vuelve al menú.
## Las imágenes están en assets/ui/kit/ (mapa_cuento1..9.png = cuentos abiertos, mapa_bloq2..9.png = cuentos bloqueados).
## Para mover los puntos de escena sobre el camino cambia SCENE_MARKS (0 = inicio del camino, 1 = final).
## El dibujo del trayecto está en scripts/ui/story_tile.gd.

const STORY_TITLE := "Cuento I · Caperucita Roja"
const STORY_COUNT := 9
const ACTIVE_TILE := "res://assets/ui/kit/mapa_cuento1.png"
const OPEN_TILE := "res://assets/ui/kit/mapa_cuento%d.png"  # %d = 1..9 (cuento desbloqueado)
const LOCKED_TILE := "res://assets/ui/kit/mapa_bloq%d.png"  # %d = 2..9 (cuento bloqueado)
const POINT_SIZE := Vector2(30, 30)

enum { MODE_STORY, MODE_OVERVIEW }

@onready var map_image: TextureRect = $MapImage

## true = el mapa se abrió desde el juego (encima de la escena). Al cerrarlo se vuelve al juego, no al menú.
static var overlay: bool = false

var _mode: int = MODE_STORY
var _points: Array = []
var _header: Label = null
var _subheader: Label = null
var _subheader_frame: Control = null
var _big: StoryTile = null  # mapa del cuento activo (vista de cuento)
var _story_tiles: Array = []  # vista de todos los cuentos: {"number", "tile" (Control), "button" (Button)}


func _ready() -> void:
	# Antes de mostrar el mapa: nada de velos, pausas ni transiciones pendientes.
	if not overlay:
		ScenePages.reset()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node_name in ["Chapter1Button", "Chapter1Label", "BottomBar/PlayButton"]:
		var old := get_node_or_null(node_name)
		if old != null:
			old.hide()
	# El mapa antiguo queda solo como ambiente, muy tenue.
	map_image.modulate = Color(1, 1, 1, 0.14)
	_build_header()
	_build_story_view()
	# Dentro del juego solo se ve el cuento actual: la cuadrícula con todos los cuentos solo existe al abrir el mapa desde el menú.
	if not overlay:
		_build_overview()
	_mode = MODE_OVERVIEW if not overlay else MODE_STORY
	resized.connect(_layout)
	_apply_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_back()


func _build_header() -> void:
	# Títulos en marcos de madera tallada (igual que el diario y los demás títulos del juego).
	var column := VBoxContainer.new()
	column.name = "TitulosMapa"
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.offset_top = 8
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var main_frame := UIKit.wood_title("", 340.0, 20)
	main_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(main_frame)
	_header = main_frame.get_child(main_frame.get_child_count() - 1) as Label
	_subheader_frame = UIKit.wood_title("", 300.0, 15)
	_subheader_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_subheader_frame)
	_subheader = _subheader_frame.get_child(_subheader_frame.get_child_count() - 1) as Label


# Texto del encabezado: la primera línea va en el marco grande; la segunda, en el marco pequeño (si la hay).
func _set_header_text(text: String) -> void:
	if _header == null:
		return
	var parts := text.split("\n", false, 1)
	_header.text = parts[0]
	var has_sub := parts.size() > 1
	_subheader_frame.visible = has_sub
	_subheader.text = parts[1] if has_sub else ""


# VISTA DE CUENTO: el mapa del cuento activo (grande) y un punto por cada escena.
func _build_story_view() -> void:
	_big = StoryTile.new()
	_big.texture = load(ACTIVE_TILE) as Texture2D
	_big.progress = StoryTile.overall_progress()
	var big_marks: Array[float] = []
	for part in GameSession.PARTS:
		big_marks.append(float(part.mark))
	_big.marks = big_marks
	add_child(_big)
	for index in GameSession.PARTS.size():
		_points.append(_make_point(index, GameSession.OPEN_ALL_PARTS or index <= GameSession.reached_index()))


# VISTA DE TODOS LOS CUENTOS: nueve tarjetas. Las desbloqueadas muestran su mapa; las bloqueadas, su candado.
func _build_overview() -> void:
	for number in range(1, STORY_COUNT + 1):
		var unlocked: bool = GameSession.story_unlocked(number)
		var tile: Control
		if number == 1:
			# El cuento I lleva dibujado el trayecto recorrido (sin los puntos de escena: esos están en su vista de cuento).
			var first := StoryTile.new()
			first.texture = load(OPEN_TILE % number) as Texture2D
			first.progress = StoryTile.overall_progress()
			tile = first
		else:
			var rect := TextureRect.new()
			rect.texture = load((OPEN_TILE if unlocked else LOCKED_TILE) % number) as Texture2D
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile = rect
		add_child(tile)
		# Botón transparente encima: da el foco con el mando, el clic y el texto de arriba.
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var focus_style := StyleBoxFlat.new()
		focus_style.bg_color = Color(0, 0, 0, 0)
		focus_style.border_color = Color(1, 0.95, 0.8)
		focus_style.set_border_width_all(3)
		focus_style.set_corner_radius_all(8)
		button.add_theme_stylebox_override("focus", focus_style)
		button.pressed.connect(_open_story.bind(number))
		button.focus_entered.connect(_show_story.bind(number))
		button.mouse_entered.connect(_show_story.bind(number))
		tile.add_child(button)
		_story_tiles.append({"number": number, "tile": tile, "button": button})


func _make_point(index: int, unlocked: bool) -> Dictionary:
	var marker := Button.new()
	marker.custom_minimum_size = POINT_SIZE
	marker.size = POINT_SIZE
	marker.focus_mode = Control.FOCUS_ALL
	marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var gold := Color(0.93, 0.78, 0.45) if unlocked else Color(0.4, 0.38, 0.36)
	# El punto es un anillo transparente: el dibujo de la escena ya lo marca el mapa; esto solo lo hace clicable.
	marker.add_theme_stylebox_override("normal", _dot_style(Color(gold, 0.12), gold, 2))
	marker.add_theme_stylebox_override("hover", _dot_style(Color(gold, 0.35), Color(1, 0.95, 0.8), 2))
	marker.add_theme_stylebox_override("pressed", _dot_style(Color(gold, 0.5), Color(1, 0.95, 0.8), 2))
	marker.add_theme_stylebox_override("focus", _dot_style(Color(gold, 0.35), Color(1, 1, 1), 4))
	marker.add_theme_stylebox_override("disabled", _dot_style(Color(0, 0, 0, 0.25), Color(0.35, 0.33, 0.31), 2))
	marker.disabled = not unlocked
	if unlocked:
		marker.pressed.connect(_enter.bind(index))
	marker.focus_entered.connect(_show_point.bind(index))
	marker.mouse_entered.connect(_show_point.bind(index))
	add_child(marker)
	return {"marker": marker, "mark": float(GameSession.PARTS[index].mark), "index": index, "unlocked": unlocked}


func _dot_style(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(POINT_SIZE.x * 0.5))
	return style


# Muestra solo la vista activa (cuento o todos los cuentos), actualiza el texto de arriba y el foco.
func _apply_mode() -> void:
	var story: bool = _mode == MODE_STORY
	_big.visible = story
	for entry in _points:
		(entry["marker"] as Control).visible = story
	for entry in _story_tiles:
		(entry["tile"] as Control).visible = not story
	if story:
		_show_default()
	else:
		_show_overview()
	_layout()
	if story:
		_focus_first_open_point.call_deferred()
	elif not _story_tiles.is_empty():
		(_story_tiles[0]["button"] as Button).grab_focus.call_deferred()


# Arriba: el cuento y la escena del punto elegido.
func _show_point(index: int) -> void:
	if _header == null:
		return
	var unlocked: bool = GameSession.OPEN_ALL_PARTS or index <= GameSession.reached_index()
	var scene_line := "Escena %d · %s" % [index + 1, GameSession.PARTS[index].title] if unlocked else "Escena %d · Aún no alcanzada" % (index + 1)
	_set_header_text("%s\n%s" % [STORY_TITLE, scene_line])


# Arriba, en la vista de todos los cuentos: el cuento sobre el que está el cursor.
func _show_story(number: int) -> void:
	if _header == null:
		return
	if number == 1:
		_set_header_text("%s\nDesbloqueado · pulsa para ver sus escenas" % STORY_TITLE)
	elif GameSession.story_unlocked(number):
		_set_header_text("Cuento %d\nDesbloqueado: su historia aún se está escribiendo" % number)
	else:
		_set_header_text("Cuento %d\nBloqueado: se abrirá al terminar el cuento anterior" % number)


func _show_default() -> void:
	if _header != null:
		_set_header_text("%s\nElige una escena del mapa" % STORY_TITLE)


func _show_overview() -> void:
	if _header != null:
		_set_header_text("Cuentos\nElige un cuento desbloqueado")


# Elegir un cuento en la vista de todos los cuentos: el I abre su mapa con las escenas; los demás aún no tienen historia.
func _open_story(number: int) -> void:
	if number == 1:
		_mode = MODE_STORY
		_apply_mode()
	else:
		_show_story(number)


# Foco en el primer punto disponible: el mando empieza en el mapa.
func _focus_first_open_point() -> void:
	for entry in _points:
		var marker: Button = entry["marker"]
		if not marker.disabled:
			marker.grab_focus()
			return


# Coloca la vista activa: un solo mapa centrado (cuento) o la cuadrícula de nueve tarjetas (todos los cuentos).
func _layout() -> void:
	if _big == null or _big.texture == null:
		return
	var aspect: float = StoryTile.SOURCE_SIZE.x / StoryTile.SOURCE_SIZE.y
	var area := Rect2(Vector2(40, 96), size - Vector2(80, 96 + 76))
	if _mode == MODE_STORY:
		# El mapa del cuento ocupa todo el alto disponible y queda centrado, con sus puntos de escena encima.
		var big_h := area.size.y
		var big_w := big_h * aspect
		if big_w > area.size.x:
			big_w = area.size.x
			big_h = big_w / aspect
		_big.position = Vector2(area.position.x + (area.size.x - big_w) * 0.5, area.position.y + (area.size.y - big_h) * 0.5)
		_big.size = Vector2(big_w, big_h)
		for entry in _points:
			var marker: Button = entry["marker"]
			marker.position = _big.position + _big.point_at(float(entry["mark"])) - POINT_SIZE * 0.5
		return
	# Cuadrícula de cuentos: 5 arriba y 4 abajo, centradas.
	var gap := 16.0
	var columns := 5
	var cell_w := minf((area.size.x - gap * float(columns - 1)) / float(columns), ((area.size.y - gap) * 0.5) * aspect)
	var cell_h := cell_w / aspect
	var top := area.position.y + (area.size.y - (cell_h * 2.0 + gap)) * 0.5
	for index in _story_tiles.size():
		var row := index / columns
		var in_row: int = columns if row == 0 else _story_tiles.size() - columns
		var column := index % columns
		var row_w := cell_w * float(in_row) + gap * float(in_row - 1)
		var left := area.position.x + (area.size.x - row_w) * 0.5
		var tile: Control = _story_tiles[index]["tile"]
		tile.position = Vector2(left + float(column) * (cell_w + gap), top + float(row) * (cell_h + gap))
		tile.size = Vector2(cell_w, cell_h)


# Elegir una escena: si el mapa estaba encima del juego, primero se quita la capa (si no, tapa la escena nueva).
func _enter(index: int) -> void:
	if overlay:
		overlay = false
		get_tree().paused = false
		var layer := get_parent()
		if layer is CanvasLayer:
			layer.queue_free()
		queue_free()
	GameSession.enter_part(index)


func _back() -> void:
	if overlay:
		# Cerrar el mapa del juego: se quita la capa y se sigue jugando donde estaba Elliot.
		overlay = false
		var layer := get_parent()
		get_tree().paused = false
		if layer is CanvasLayer:
			layer.queue_free()
		queue_free()
		return
	if _mode == MODE_STORY:
		# Desde el menú: del mapa del cuento se vuelve a la vista de todos los cuentos.
		_mode = MODE_OVERVIEW
		_apply_mode()
		return
	ScenePages.travel("res://scenes/main_menu.tscn")


func _on_back_pressed() -> void:
	_back()


# El botón "Iniciar" del mapa se ocultó: iniciar una partida nueva borraría el progreso.
func _on_play_pressed() -> void:
	pass
