extends CanvasLayer
## VOZ DE LOS AUTORES (autoload "Autores"): texto en off sobre la escena. No es un personaje ni bloquea el juego.
## Uso: Autores.say(["primera frase", "segunda frase"]). Cada frase aparece, se queda un rato y se desvanece.
## Lo usan los hallazgos importantes, los puzles resueltos y los momentos clave de cada escena.

const FADE := 0.6
const MIN_HOLD := 3.5
const MAX_HOLD := 9.0

var _panel: PanelContainer = null
var _label: Label = null
var _queue: Array = []
var _showing: bool = false
var _fading: bool = false
var _timer: float = 0.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.05, 0.78)
	style.border_color = Color(0.45, 0.38, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.offset_bottom = -110
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.9))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)
	_panel.add_child(margin)
	_panel.hide()


func say(lines: Array) -> void:
	for line in lines:
		_queue.append(String(line))
	if not _showing:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_panel.hide()
		_showing = false
		return
	if DialogueManager.visible:
		_showing = false
		return
	_showing = true
	_fading = false
	_label.text = _queue.pop_front()
	_panel.modulate.a = 0.0
	_panel.show()
	var appear := create_tween()
	appear.tween_property(_panel, "modulate:a", 1.0, FADE)
	_timer = clampf(float(_label.text.length()) / 12.0, MIN_HOLD, MAX_HOLD)


func _process(delta: float) -> void:
	if not _showing and not _queue.is_empty() and not DialogueManager.visible:
		_next()
		return
	if not _showing or _fading:
		return
	_timer -= delta
	if _timer <= 0.0:
		_fading = true
		var vanish := create_tween()
		vanish.tween_property(_panel, "modulate:a", 0.0, FADE)
		vanish.tween_callback(_next)
