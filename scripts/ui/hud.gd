extends CanvasLayer

@onready var bar: TextureProgressBar = $HealthBar
@onready var label: Label = $HealthBar/HealthLabel

# Bajo la barra de vida: cansancio y miedo. El mapa pequeño va arriba a la derecha, junto a la mochila.
const MINIMAP_SIZE := Vector2(96, 64)
var _fatigue_bar: ProgressBar = null
var _fear_bar: ProgressBar = null
var _minimap: StoryTile = null
var _route_clock: float = 0.0


func _ready() -> void:
	_build_shortcuts()
	_build_status_widgets()


func _process(delta: float) -> void:
	if _fatigue_bar != null:
		_fatigue_bar.value = PlayerStatus.fatigue()
		_fear_bar.value = PlayerStatus.fear()
	# Cada medio segundo se anota hasta dónde ha llegado Elliot y se actualiza el mapa pequeño.
	_route_clock += delta
	if _route_clock >= 0.5:
		_route_clock = 0.0
		_update_route()


# Barra superior derecha: mapa pequeño y mochila, uno al lado del otro.
func _build_shortcuts() -> void:
	var row := HBoxContainer.new()
	row.name = "AtajosSuperiores"
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -360.0
	row.offset_right = -24.0
	row.offset_top = 24.0
	row.offset_bottom = 88.0
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_build_minimap(row)
	var backpack := TextureButton.new()
	backpack.texture_normal = load("res://assets/ui/nuevos/botones_texto/mochila.png") as Texture2D
	backpack.ignore_texture_size = true
	backpack.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	backpack.custom_minimum_size = Vector2(150, 60)
	backpack.focus_mode = Control.FOCUS_NONE
	backpack.tooltip_text = "Mochila [I]"
	backpack.pressed.connect(_on_backpack_pressed)
	row.add_child(backpack)


# Mapa pequeño de Caperucita (clic = abrir el mapa grande).
func _build_minimap(row: Control) -> void:
	_minimap = StoryTile.new()
	_minimap.texture = load("res://assets/ui/kit/mapa_cuento1.png") as Texture2D
	var minimap_marks: Array[float] = []  # un punto por escena jugable (GameSession.PARTS)
	for part in GameSession.PARTS:
		minimap_marks.append(float(part.mark))
	_minimap.marks = minimap_marks
	_minimap.custom_minimum_size = MINIMAP_SIZE
	_minimap.size = MINIMAP_SIZE
	_minimap.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_minimap)
	# Botón invisible encima del mapa pequeño: al pulsarlo se abre el mapa grande.
	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.tooltip_text = "Mapa"
	click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(_on_map_pressed)
	_minimap.add_child(click)
	_update_route()


# Barras finas de cansancio y miedo.
func _build_status_widgets() -> void:
	var column := VBoxContainer.new()
	column.name = "EstadoPersonaje"
	column.position = Vector2(30, 86)
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_fatigue_bar = _thin_bar(column, "Cansancio", Color(0.85, 0.62, 0.25), FRAME_FATIGUE, HOLE_FATIGUE)
	_fear_bar = _thin_bar(column, "Miedo", Color(0.55, 0.4, 0.8), FRAME_FEAR, HOLE_FEAR)


# Barra de estado con el marco nuevo: la barra de progreso va detrás y el marco encima, por el hueco transparente.
# hole = (x, y, ancho, alto) del hueco dentro de la imagen del marco, medido en píxeles.
const GAUGE_WIDTH := 150.0
const FRAME_FATIGUE := "res://assets/ui/nuevos/barras/barra_cansancio.png"
const FRAME_FEAR := "res://assets/ui/nuevos/barras/barra_miedo.png"
const HOLE_FATIGUE := Rect2(59, 18, 165, 17)
const HOLE_FEAR := Rect2(60, 18, 162, 17)
const FRAME_SIZE := Vector2(258, 55)

func _thin_bar(parent: Control, title: String, color: Color, frame_path: String, hole: Rect2) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(72, 0)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var scale_factor := GAUGE_WIDTH / FRAME_SIZE.x
	var gauge := Control.new()
	gauge.custom_minimum_size = FRAME_SIZE * scale_factor
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gauge)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = hole.position.x / FRAME_SIZE.x
	bar.anchor_top = hole.position.y / FRAME_SIZE.y
	bar.anchor_right = (hole.position.x + hole.size.x) / FRAME_SIZE.x
	bar.anchor_bottom = (hole.position.y + hole.size.y) / FRAME_SIZE.y
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.04, 0.03, 0.6)
	bar.add_theme_stylebox_override("background", back)
	gauge.add_child(bar)
	var frame := TextureRect.new()
	frame.texture = load(frame_path) as Texture2D
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gauge.add_child(frame)
	return bar


# Anota el avance de Elliot en la escena actual (x dentro de los límites de la cámara) y lo dibuja en el mapa pequeño.
func _update_route() -> void:
	var scene := get_parent()
	if scene == null:
		return
	var index: int = GameSession.part_for_scene(scene)
	var hero := get_tree().get_first_node_in_group("player")
	var bounds = scene.get("camera_bounds")
	if index >= 0 and hero != null and bounds is Rect2:
		StoryTile.record(index, (hero.global_position.x - bounds.position.x) / maxf(bounds.size.x, 1.0))
	if _minimap != null:
		_minimap.progress = StoryTile.overall_progress()


func _shortcut(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.72)
	style.border_color = Color(0.85, 0.7, 0.4, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68))
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	return button


func _on_backpack_pressed() -> void:
	Mochila.open_diary()


var _l2_down: bool = false


func _unhandled_input(event: InputEvent) -> void:
	var joy := event as InputEventJoypadButton
	if joy != null and joy.pressed and joy.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		get_viewport().set_input_as_handled()
		_on_map_pressed()
		return
	# L2 (gatillo izquierdo) también abre el mapa; R1 se conserva como estaba.
	var trigger := event as InputEventJoypadMotion
	if trigger != null and trigger.axis == JOY_AXIS_TRIGGER_LEFT:
		var down: bool = trigger.axis_value > 0.6
		if down and not _l2_down:
			_l2_down = true
			get_viewport().set_input_as_handled()
			_on_map_pressed()
		elif not down:
			_l2_down = false
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_M:
		get_viewport().set_input_as_handled()
		_on_map_pressed()

func _on_map_pressed() -> void:
	if DialogueManager.visible or ScenePages.busy or get_tree().paused:
		return
	# El mapa se abre ENCIMA del juego y la partida queda en pausa; al cerrarlo se sigue jugando.
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	var map_script := load("res://scripts/ui/map_screen.gd") as GDScript
	map_script.set("overlay", true)
	var map := (load("res://scenes/ui/map_screen.tscn") as PackedScene).instantiate()
	layer.add_child(map)
	get_tree().paused = true


func update_health(current: int, max_health: int) -> void:
	bar.max_value = max_health
	bar.value = current
	label.text = "%d / %d" % [current, max_health]

# Conecta esta función a la señal health_changed del HealthComponent del jugador.
# Se llama desde el script del nivel (level.gd) al iniciar la escena.
func bind_to_health_component(health_component: Node) -> void:
	if not health_component.health_changed.is_connected(update_health):
		health_component.health_changed.connect(update_health)
	update_health(health_component.current_health, health_component.max_health)
