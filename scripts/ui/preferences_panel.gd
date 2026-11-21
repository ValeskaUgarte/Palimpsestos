extends Control
## "Comodidad y controles" sobre pergamino, con las placas del kit.

const ROW_HEIGHT: float = 41.0
const ACTION_PLAQUES := {
	"move_left": "row_izquierda", "move_right": "row_derecha",
	"move_up": "row_prof_arriba", "move_down": "row_prof_abajo",
	"attack": "row_golpe", "kick": "row_patada", "jump": "row_salto",
	"interact": "row_interactuar", "pause": "row_pausa",
}
const ACTION_NAMES := {
	"move_left": "Izquierda", "move_right": "Derecha",
	"move_up": "Profundidad arriba", "move_down": "Profundidad abajo",
	"attack": "Golpe", "kick": "Patada", "jump": "Salto",
	"interact": "Interactuar", "pause": "Pausa",
}

var _binding: String = ""
var _key_buttons: Dictionary = {}
var _joy_binding: String = ""
var _joy_buttons: Dictionary = {}
var _controller_status: Label = null

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller_status()

func _refresh_controller_status() -> void:
	if _controller_status == null:
		return
	if not GamePreferences.controller_connected():
		_controller_status.text = "Mando: no detectado. Conéctalo por USB o Bluetooth y funciona sin reiniciar."
	elif GamePreferences.gamepad_mode:
		_controller_status.text = "Mando activo: " + GamePreferences.controller_name()
	else:
		_controller_status.text = "Mando conectado (" + GamePreferences.controller_name() + ") pero desactivado en esta opción."

func _ready() -> void:
	add_to_group("preferences_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.dim(0.92))
	var parts: Dictionary = UIKit.parchment(Vector2(1120, 690))
	add_child(parts.root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	(parts.content as MarginContainer).add_child(box)

	var title: Control = UIKit.banner("Comodidad y controles", 68)
	if title == null:
		title = UIKit.ink_label("Comodidad y controles", 28, UIKit.INK_RED)
		(title as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var shake := HSlider.new()
	shake.max_value = 1
	shake.step = 0.1
	shake.value = GamePreferences.shake
	UIKit.style_slider(shake)
	shake.value_changed.connect(func(v: float): GamePreferences.shake = v; GamePreferences.save())
	_cell(grid, "row_sacudida", "Sacudida de cámara", shake)

	var flash := UIKit.toggle(GamePreferences.flashes)
	flash.toggled.connect(func(v: bool): GamePreferences.flashes = v; GamePreferences.save())
	_cell(grid, "row_flashes", "Flashes de daño", flash)

	var auto_dialogue := UIKit.toggle(GamePreferences.auto_dialogue)
	auto_dialogue.toggled.connect(func(v: bool): GamePreferences.set_auto_dialogue(v))
	_cell(grid, "", "Diálogo automático", auto_dialogue)

	var pad := UIKit.toggle(GamePreferences.gamepad_mode)
	pad.toggled.connect(func(v: bool): GamePreferences.set_gamepad_mode(v); _refresh_controller_status())
	_cell(grid, "", "Usar control (mando)", pad)

	var text_slider := HSlider.new()
	text_slider.min_value = 1
	text_slider.max_value = 1.3
	text_slider.step = 0.1
	text_slider.value = GamePreferences.text_scale
	UIKit.style_slider(text_slider)
	text_slider.value_changed.connect(func(v: float): GamePreferences.text_scale = v; GamePreferences.save())
	_cell(grid, "row_texto", "Tamaño del texto", text_slider)

	var full := UIKit.toggle(GamePreferences.fullscreen)
	full.toggled.connect(func(v: bool):
		GamePreferences.fullscreen = v
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
		GamePreferences.save()
	)
	_cell(grid, "row_ventana", "Ventana completa", full)

	for action in GamePreferences.ACTIONS:
		var button: Button = UIKit.key_button(GamePreferences.key_label(action))
		_key_buttons[action] = button
		button.pressed.connect(func(): _binding = action; button.text = "Pulsa una tecla…")
		_cell(grid, ACTION_PLAQUES.get(action, ""), ACTION_NAMES.get(action, action), button)

	# Botones del mando: cada acción se puede asignar a cualquier botón de tu control.
	for action in GamePreferences.JOY_ACTIONS:
		var joy_button: Button = UIKit.key_button(GamePreferences.joy_label(action))
		_joy_buttons[action] = joy_button
		joy_button.pressed.connect(func(): _joy_binding = action; joy_button.text = "Pulsa un botón…")
		_cell(grid, "", "Mando: " + ACTION_NAMES.get(action, action), joy_button)

	if grid.get_child_count() % 2 == 1:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(spacer)

	_controller_status = UIKit.ink_label("", 16, UIKit.INK)
	_controller_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controller_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_controller_status)
	_refresh_controller_status()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	var note := UIKit.ink_label("Mando: stick · A saltar · X golpear · Y patada · B interactuar · Start pausa", 15, UIKit.INK)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)

	var close := Button.new()
	close.text = "Volver al Cuento"
	box.add_child(close)
	if not UIKit.skin_button(close, "btn_volver_cuento", 52):
		UIKit.style_plain_button(close)
	close.pressed.connect(queue_free)
	close.grab_focus()

## Una celda = placa con el nombre + el control a la derecha.
func _cell(grid: GridContainer, plaque_key: String, fallback: String, widget: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(206, ROW_HEIGHT)
	var plaque: Control = UIKit.plaque(plaque_key, ROW_HEIGHT) if plaque_key != "" else null
	if plaque == null:
		plaque = UIKit.ink_label(fallback, 17)
	holder.add_child(plaque)
	row.add_child(holder)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not widget is TextureButton else Control.SIZE_SHRINK_BEGIN
	widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(widget)
	grid.add_child(row)

func _input(event: InputEvent) -> void:
	if not _joy_binding.is_empty():
		if event is InputEventJoypadButton and event.pressed:
			GamePreferences.bind_joy_button(_joy_binding, event.button_index)
			_joy_binding = ""
			for action in _joy_buttons:
				_joy_buttons[action].text = GamePreferences.joy_label(action)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_joy_binding = ""
			for action in _joy_buttons:
				_joy_buttons[action].text = GamePreferences.joy_label(action)
			get_viewport().set_input_as_handled()
			return
	if _binding.is_empty() and event.is_action_pressed("pause"):
		queue_free()
		get_viewport().set_input_as_handled()
		return
	if not _binding.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			GamePreferences.bind_key(_binding, event.physical_keycode)
		_binding = ""
		for action in _key_buttons:
			_key_buttons[action].text = GamePreferences.key_label(action)
		get_viewport().set_input_as_handled()
