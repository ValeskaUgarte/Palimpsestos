extends CanvasLayer
## DIARIO DE HALLAZGOS (autoload "Mochila"): objetos del cuento, pociones, comida y sellos.
## Se abre con I (teclado) o con el botón Select/Back del mando, dentro de cualquier escena del cuento.
## Izquierda: la rejilla con los hallazgos. Derecha: la nota de Elliot sobre el hallazgo elegido.
## El botón de abajo usa el objeto elegido (poción, comida o sello): lo que hace cada uno está en StoryItems.
## Debajo de la rejilla está el ESTADO de Elliot: cansancio, miedo y sellos (ver PlayerStatus). Cerrar: Esc / Start / I.
##
## Ajuste fino: si los objetos no caen justo dentro de las casillas del marco, cambia SLOT_INSET
## (x, y, ancho, alto como fracción del marco de la rejilla).

const TOGGLE := "mochila"
const GRID_TEX: Texture2D = preload("res://assets/ui/diario/marco_rejilla.png")
const DETAIL_TEX: Texture2D = preload("res://assets/ui/diario/marco_detalle.png")
const GRID_SIZE := Vector2(640, 448)
const DETAIL_SIZE := Vector2(262, 452)
# Alto que ocupan, sumados, el título, las barras de estado, el aviso y los botones (+ márgenes). Lo que sobra de la pantalla
# es para la rejilla y la nota: así Usar y Cerrar siempre quedan dentro de la pantalla, sin escalar nada.
const DIARY_OTHER_HEIGHT := 350.0
const CLOSE_BUTTON_HEIGHT := 54.0
const SLOT_INSET := Rect2(0.075, 0.125, 0.85, 0.79)
const COLUMNS := 6
const ROWS := 4

var _panel: Control = null
var _grid_holder: Control = null  # marco de la rejilla (su tamaño se ajusta al alto de la pantalla cada vez que se abre)
var _detail_holder: Control = null  # marco de la nota de Elliot
var _detail_box: VBoxContainer = null  # texto de la nota
var _grid: GridContainer = null
var _detail_icon: TextureRect = null
var _detail_name: Label = null
var _detail_text: Label = null
var _feedback: Label = null
var _use: Button = null
var _close_button: Button = null
var _fatigue_bar: ProgressBar = null
var _fear_bar: ProgressBar = null
var _fatigue_label: Label = null
var _fear_label: Label = null
var _seals_label: Label = null
var _selected: String = ""


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	_build()
	_panel.hide()


func _register_input() -> void:
	if InputMap.has_action(TOGGLE):
		return
	InputMap.add_action(TOGGLE)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_I
	InputMap.action_add_event(TOGGLE, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(TOGGLE, pad)


func _unhandled_input(event: InputEvent) -> void:
	if not _in_story_level():
		return
	if _panel.visible:
		if event.is_action_pressed("ui_cancel") or (event.is_action_pressed(TOGGLE) and not event.is_echo()):
			get_viewport().set_input_as_handled()
			_close()
		return
	# Un diálogo en pantalla ya no impide abrir la mochila/diario.
	if event.is_action_pressed(TOGGLE) and not event.is_echo() \
			and not ScenePages.busy and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_open()


func _in_story_level() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path in GameSession.LEVELS


var _toast: Control = null
var _toast_icon: TextureRect = null
var _toast_name: Label = null
var _toast_text: Label = null
var _repeat: Label = null
## Tarjeta de objetos recogidos: abajo de las barras de cansancio y miedo, en el costado izquierdo.
const TOAST_SIZE := Vector2(340, 84)
const TOAST_ICON := 72.0
const TOAST_LEFT := 30.0
## Las barras terminan cerca de y=154; la tarjeta empieza justo debajo.
const TOAST_TOP := 164.0
## Cuánto se sube (en píxeles) la tarjeta y el cartel respecto al centro exacto de la pantalla.
const CENTER_LIFT := 70.0
## Alto del cartel de tablero cuando se lee.
const POSTER_HEIGHT := 340.0


## Hallazgo nuevo: tarjeta compacta en el costado izquierdo, debajo de las barras de cansancio y miedo.
## Si ya lo tenías (una poción, por ejemplo): solo una línea arriba con el total. No tapa la escena.
func show_found(id: String, first_time: bool = true, total: int = 1) -> void:
	if _toast == null:
		return
	var info := StoryItems.info(id)
	if first_time:
		_toast_icon.texture = _icon_for(id)
		_toast_name.text = info["name"]
		_toast_text.text = info["desc"]
		_toast.show()
		_toast.modulate.a = 0.0
		var appear := create_tween()
		appear.tween_property(_toast, "modulate:a", 1.0, 0.25)
		get_tree().create_timer(5.0, true).timeout.connect(_hide_toast)
	else:
		_repeat.text = "%s +1 · total %d" % [info["name"], total]
		_repeat.show()
		get_tree().create_timer(2.2, true).timeout.connect(_hide_repeat)


func _hide_toast() -> void:
	if _toast == null or not _toast.visible:
		return
	var vanish := create_tween()
	vanish.tween_property(_toast, "modulate:a", 0.0, 0.4)
	vanish.tween_callback(_toast.hide)


func _hide_repeat() -> void:
	if _repeat != null:
		_repeat.hide()


func _build_toast() -> void:
	_toast = Control.new()
	# TARJETA DE OBJETOS: ahora va en el costado IZQUIERDO, justo debajo de las barras de cansancio y miedo,
	# en tamaño compacto (icono a la izquierda y texto al lado) para no invadir la pantalla.
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_toast.offset_left = TOAST_LEFT
	_toast.offset_top = TOAST_TOP
	_toast.offset_right = TOAST_LEFT + TOAST_SIZE.x
	_toast.offset_bottom = TOAST_TOP + TOAST_SIZE.y
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	# Sin caja ni marco: se ve el objeto y, a su lado, el nombre y una línea corta con contorno oscuro.
	_toast_icon = _frame(null)
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.position = Vector2(0.0, 0.0)
	_toast_icon.size = Vector2(TOAST_ICON, TOAST_ICON)
	_toast.add_child(_toast_icon)
	var box := VBoxContainer.new()
	box.position = Vector2(TOAST_ICON + 10.0, 2.0)
	box.size = Vector2(TOAST_SIZE.x - TOAST_ICON - 10.0, TOAST_SIZE.y - 2.0)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(box)
	_toast_name = _label("", 17, Color(0.98, 0.93, 0.78))
	_toast_text = _label("", 13, Color(0.93, 0.9, 0.82))
	for text_label in [_toast_name, _toast_text]:
		(text_label as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		(text_label as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(text_label as Label).add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		(text_label as Label).add_theme_constant_override("outline_size", 5)
		box.add_child(text_label)
	_toast.hide()
	# Aviso corto cuando se repite un objeto que ya tenías: también abajo de las barras, a la izquierda.
	_repeat = _label("", 15, Color(0.96, 0.9, 0.74))
	_repeat.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_repeat.offset_left = TOAST_LEFT
	_repeat.offset_top = TOAST_TOP
	_repeat.offset_right = TOAST_LEFT + TOAST_SIZE.x
	_repeat.offset_bottom = TOAST_TOP + 28
	_repeat.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_repeat.add_theme_constant_override("outline_size", 5)
	_repeat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_repeat)
	_repeat.hide()


var _poster: TextureRect = null


## Cartel de tablero: se muestra en el centro (un poco arriba) para leerlo; se cierra con E o al alejarte.
func show_poster(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	show_poster_texture(load(path) as Texture2D)


## Igual que show_poster, pero con la textura ya cargada (así no depende de la ruta del archivo).
func show_poster_texture(texture: Texture2D) -> void:
	if _poster == null or texture == null:
		return
	var height := POSTER_HEIGHT
	var width := height * float(texture.get_width()) / float(texture.get_height())
	_poster.texture = texture
	_poster.offset_left = -width * 0.5
	_poster.offset_right = width * 0.5
	_poster.offset_top = -height * 0.5 - CENTER_LIFT
	_poster.offset_bottom = height * 0.5 - CENTER_LIFT
	_poster.show()
	_poster.modulate.a = 0.0
	var appear := create_tween()
	appear.tween_property(_poster, "modulate:a", 1.0, 0.25)


func is_open() -> bool:
	return _panel != null and _panel.visible


func poster_open() -> bool:
	return _poster != null and _poster.visible


## Se cierra con E (o al alejarte del tablero: lo llama StoryPickup).
func hide_poster() -> void:
	if _poster == null or not _poster.visible:
		return
	var vanish := create_tween()
	vanish.tween_property(_poster, "modulate:a", 0.0, 0.25)
	vanish.tween_callback(_poster.hide)


func _build() -> void:
	_poster = TextureRect.new()
	_poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_poster.stretch_mode = TextureRect.STRETCH_SCALE
	_poster.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_poster)
	_poster.hide()
	_build_toast()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var diary_title := UIKit.wood_title("Diario de hallazgos", 360.0, 26)
	diary_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(diary_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	# Rejilla: el marco es el fondo, y encima van las casillas con los hallazgos.
	var grid_holder := Control.new()
	grid_holder.custom_minimum_size = GRID_SIZE
	_grid_holder = grid_holder
	grid_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grid_holder)
	var frame := _frame(GRID_TEX)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_holder.add_child(frame)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	grid_holder.add_child(_grid)

	# Nota de Elliot: el marco de pergamino con el hallazgo arriba y el texto abajo.
	var detail := Control.new()
	detail.custom_minimum_size = DETAIL_SIZE
	_detail_holder = detail
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(detail)
	var detail_frame := _frame(DETAIL_TEX)
	detail_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail.add_child(detail_frame)
	_detail_icon = _frame(null)
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(_detail_icon)
	var text_box := VBoxContainer.new()
	_detail_box = text_box
	text_box.add_theme_constant_override("separation", 6)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(text_box)
	_detail_name = _label("", 20, Color(0.2, 0.15, 0.1))
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_box.add_child(_detail_name)
	_detail_text = _label("", 14, Color(0.25, 0.2, 0.14))
	_detail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_box.add_child(_detail_text)

	_build_status(column)
	_feedback = _label("", 15, Color(1.0, 0.62, 0.5))
	column.add_child(_feedback)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	_use = Button.new()
	_use.text = "Usar"
	_use.custom_minimum_size = Vector2(170, 42)
	_use.pressed.connect(_use_item)
	_use.add_theme_stylebox_override("focus", _slot_style(true))
	buttons.add_child(_use)
	var close := Button.new()
	close.text = "Cerrar"
	UIKit.skin_by_text(close, CLOSE_BUTTON_HEIGHT)
	close.pressed.connect(_close)
	close.add_theme_stylebox_override("focus", _slot_style(true))
	# Sin estiramiento vertical: si el botón Usar es más alto, Cerrar no se deforma.
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(close)
	_close_button = close


func _frame(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# AJUSTE A LA PANTALLA: la rejilla y la nota se hacen más chicas si la pantalla es baja, para que el título, las barras y los
# botones (Usar / Comer / Beber / Cerrar) queden siempre dentro. Se calcula cada vez que se abre el diario.
func _apply_fit() -> void:
	var view_h: float = get_viewport().get_visible_rect().size.y
	var fit: float = clampf((view_h - DIARY_OTHER_HEIGHT) / DETAIL_SIZE.y, 0.55, 1.0)
	var grid_size: Vector2 = GRID_SIZE * fit
	var detail_size: Vector2 = DETAIL_SIZE * fit
	_grid_holder.custom_minimum_size = grid_size
	_grid.position = Vector2(SLOT_INSET.position.x * grid_size.x, SLOT_INSET.position.y * grid_size.y)
	_grid.size = Vector2(SLOT_INSET.size.x * grid_size.x, SLOT_INSET.size.y * grid_size.y)
	_detail_holder.custom_minimum_size = detail_size
	_detail_icon.position = Vector2(detail_size.x * 0.18, detail_size.y * 0.07)
	_detail_icon.size = Vector2(detail_size.x * 0.64, detail_size.y * 0.34)
	_detail_box.position = Vector2(detail_size.x * 0.12, detail_size.y * 0.52)
	_detail_box.size = Vector2(detail_size.x * 0.76, detail_size.y * 0.42)


func _open() -> void:
	_apply_fit()
	_feedback.text = ""
	_refresh()
	_refresh_status()
	get_tree().paused = true
	_panel.show()
	_focus_first.call_deferred()


## Lo llama el botón "Mochila" de la barra superior (HUD).
func open_diary() -> void:
	if _panel.visible or not _in_story_level():
		return
	if ScenePages.busy or get_tree().paused:
		return
	_open()


func _close() -> void:
	_panel.hide()
	get_tree().paused = false


func _refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var cell := Vector2(
		(_grid.size.x - (COLUMNS - 1) * 6.0) / COLUMNS,
		(_grid.size.y - (ROWS - 1) * 6.0) / ROWS)
	var ids: Array = GameSession.item_ids()
	for id in ids:
		var button := Button.new()
		button.custom_minimum_size = cell
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = "" if _icon_for(id) != null else StoryItems.info(id)["name"]
		button.icon = _icon_for(id)
		button.tooltip_text = "%s ×%d" % [StoryItems.info(id)["name"], GameSession.item_count(id)]
		button.add_theme_stylebox_override("normal", _slot_style(false))
		button.add_theme_stylebox_override("hover", _slot_style(true))
		button.add_theme_stylebox_override("focus", _slot_style(true))
		button.add_theme_stylebox_override("pressed", _slot_style(true))
		button.pressed.connect(_select.bind(id))
		_grid.add_child(button)
	if ids.is_empty():
		_selected = ""
		_detail_name.text = "Diario vacío"
		_detail_text.text = "Aún no has encontrado nada del camino. Lo que encuentres se anotará aquí."
		_detail_icon.texture = null
		_use.hide()
		_focus_after_refresh.call_deferred()
		return
	_select(ids[0])
	_focus_after_refresh.call_deferred()


func _slot_style(highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.25) if not highlight else Color(0.9, 0.7, 0.3, 0.12)
	style.border_color = Color(0.93, 0.78, 0.45, 0.9) if highlight else Color(0, 0, 0, 0)
	style.set_border_width_all(2 if highlight else 0)
	style.set_corner_radius_all(3)
	return style


func _icon_for(id: String) -> Texture2D:
	var path: String = StoryItems.info(id)["icon"]
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _select(id: String) -> void:
	_selected = id
	var info := StoryItems.info(id)
	_detail_icon.texture = _icon_for(id)
	_detail_name.text = "%s ×%d" % [info["name"], GameSession.item_count(id)]
	_detail_text.text = "Nota de Elliot: %s" % info["desc"]
	_use.visible = StoryItems.is_usable(id)
	_use.text = {"pocion": "Usar poción", "comida": "Comer / beber", "sello": "Usar sello"}.get(String(info["kind"]), "Usar")
	UIKit.skin_by_text(_use, 96.0)
	_feedback.text = ""


# Usa el objeto elegido (poción, comida o sello). La lógica está en PlayerStatus.use_item().
# Si no sirve de nada en este momento (vida llena, sin cansancio...) NO se gasta.
func _use_item() -> void:
	if _selected == "" or not StoryItems.is_usable(_selected):
		return
	var player := get_tree().get_first_node_in_group("player")
	var result: Dictionary = PlayerStatus.use_item(_selected, player)
	_feedback.text = String(result["msg"])
	if not bool(result["ok"]):
		return
	GameSession.remove_item(_selected)
	_refresh()
	_refresh_status()


# Sección "Estado de Elliot": barras de cansancio y miedo y los sellos que lleva.
func _build_status(column: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(box)
	box.add_child(_label("Estado de Elliot", 18, Color(0.96, 0.88, 0.68)))
	var bars := HBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 28)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bars)
	var fatigue_pair := _status_bar("Cansancio", Color(0.85, 0.62, 0.25))
	_fatigue_bar = fatigue_pair[0]
	_fatigue_label = fatigue_pair[1]
	bars.add_child(fatigue_pair[2])
	var fear_pair := _status_bar("Miedo", Color(0.55, 0.4, 0.8))
	_fear_bar = fear_pair[0]
	_fear_label = fear_pair[1]
	bars.add_child(fear_pair[2])
	_seals_label = _label("", 14, Color(0.93, 0.9, 0.82))
	box.add_child(_seals_label)


# Devuelve [barra, etiqueta, contenedor].
# Mismo diseño que las barras de la pantalla de juego (HUD): marco con icono (rayo / gema) y la barra por detrás.
# frame_path = imagen del marco; hole = (x, y, ancho, alto) del hueco transparente del marco, en píxeles de la imagen.
const GAUGE_WIDTH := 230.0
const GAUGE_FRAME_SIZE := Vector2(258, 55)
const FATIGUE_FRAME := "res://assets/ui/nuevos/barras/barra_cansancio.png"
const FATIGUE_HOLE := Rect2(59, 18, 165, 17)
const FEAR_FRAME := "res://assets/ui/nuevos/barras/barra_miedo.png"
const FEAR_HOLE := Rect2(60, 18, 162, 17)

func _status_bar(title: String, color: Color) -> Array:
	var is_fear: bool = title == "Miedo"
	var frame_path: String = FEAR_FRAME if is_fear else FATIGUE_FRAME
	var hole: Rect2 = FEAR_HOLE if is_fear else FATIGUE_HOLE
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(GAUGE_WIDTH, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label(title, 14, Color(0.93, 0.9, 0.82))
	holder.add_child(label)
	# Contenedor del medidor: la barra va detrás y el marco encima, por su hueco transparente.
	var gauge := Control.new()
	gauge.custom_minimum_size = GAUGE_FRAME_SIZE * (GAUGE_WIDTH / GAUGE_FRAME_SIZE.x)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(gauge)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = hole.position.x / GAUGE_FRAME_SIZE.x
	bar.anchor_top = hole.position.y / GAUGE_FRAME_SIZE.y
	bar.anchor_right = (hole.position.x + hole.size.x) / GAUGE_FRAME_SIZE.x
	bar.anchor_bottom = (hole.position.y + hole.size.y) / GAUGE_FRAME_SIZE.y
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.04, 0.03, 0.6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	gauge.add_child(bar)
	var frame := TextureRect.new()
	frame.texture = load(frame_path) as Texture2D
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gauge.add_child(frame)
	return [bar, label, holder]


func _refresh_status() -> void:
	if _fatigue_bar == null:
		return
	_fatigue_bar.value = PlayerStatus.fatigue()
	_fear_bar.value = PlayerStatus.fear()
	_fatigue_label.text = "Cansancio: %s (%d)" % [PlayerStatus.fatigue_name(), int(PlayerStatus.fatigue())]
	_fear_label.text = "Miedo: %s (%d)" % [PlayerStatus.fear_name(), int(PlayerStatus.fear())]
	var guard := int(round(PlayerStatus.GUARD_PER_SEAL * 100.0 * PlayerStatus.seals("guardia")))
	var skill := int(round(PlayerStatus.SKILL_PER_SEAL * 100.0 * PlayerStatus.seals("habilidad")))
	_seals_label.text = "Habilidad +%d%% de daño · Combo +%d al remate · Guardia -%d%% de daño recibido" % [
		skill, PlayerStatus.COMBO_PER_SEAL * PlayerStatus.seals("combo"), guard]


func _focus_first() -> void:
	if _grid.get_child_count() > 0:
		(_grid.get_child(0) as Control).grab_focus()


# Tras usar una poción la rejilla se reconstruye: el foco vuelve a un objeto (o a Cerrar) para poder seguir con el mando.
func _focus_after_refresh() -> void:
	if not _panel.visible:
		return
	if _grid.get_child_count() > 0:
		(_grid.get_child(0) as Control).grab_focus()
	elif _close_button != null:
		_close_button.grab_focus()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
