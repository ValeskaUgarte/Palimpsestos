extends Node

var config_path: String = "user://preferences.cfg"
var shake: float = 1.0
var flashes: bool = true
var text_scale: float = 1.0
# Los diálogos avanzan solos tras un tiempo de lectura (E sigue sirviendo para adelantar).
var auto_dialogue: bool = true
# Control (mando). Los botones del mando siempre están cargados; este interruptor los activa o desactiva.
var gamepad_mode: bool = true
var fullscreen: bool = false
var hints_seen: bool = false
var bindings: Dictionary = {}
# Versión de la configuración de diálogo. Si el archivo guardado es anterior, el diálogo automático se activa una vez.
const DIALOGUE_VERSION: int = 2
var _joy_events: Dictionary = {}
const ACTIONS = ["move_left","move_right","move_up","move_down","attack","kick","jump","interact","pause"]
# Acciones que se pueden asignar a cualquier botón del mando (en la pantalla de controles).
const JOY_ACTIONS = ["jump","attack","kick","interact","pause"]

func _ready() -> void:
	_setup_controller()
	_setup_ui_controller()
	var config := ConfigFile.new()
	if config.load(config_path) == OK:
		shake = clampf(float(config.get_value("comfort","shake",1.0)),0,1)
		flashes = bool(config.get_value("comfort","flashes",true))
		text_scale = clampf(float(config.get_value("comfort","text_scale",1.0)),1,1.3)
		auto_dialogue = bool(config.get_value("comfort","auto_dialogue",true))
		if int(config.get_value("comfort","dialogue_version",0)) < DIALOGUE_VERSION:
			auto_dialogue = true
		gamepad_mode = bool(config.get_value("controller","gamepad_mode",true))
		for action in JOY_ACTIONS:
			var saved_button: int = int(config.get_value("controller","btn_"+action,-1))
			if saved_button >= 0:
				_set_joy_button(action, saved_button)
		hints_seen=bool(config.get_value("comfort","hints_seen",false))
		fullscreen = bool(config.get_value("display","fullscreen",false))
		for action in ACTIONS:
			var key: int = int(config.get_value("keys",action,0))
			if key > 0:bind_key(action,key,false)
		for bus in ["Music","SFX","Ambient","UI"]:
			set_volume(bus,float(config.get_value("audio",bus,0.8)),false)
	_sync_ui_buttons()
	set_gamepad_mode(gamepad_mode, false)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("PALIMPSESTOS")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func set_auto_dialogue(on: bool, persist: bool = true) -> void:
	auto_dialogue = on
	if persist: save()

func set_gamepad_mode(on: bool, persist: bool = true) -> void:
	gamepad_mode = on
	for action in _joy_events:
		for event in _joy_events[action]:
			if on and not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
			elif not on and InputMap.action_has_event(action, event):
				InputMap.action_erase_event(action, event)
	if persist: save()

func controller_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()

func controller_name() -> String:
	var pads := Input.get_connected_joypads()
	return Input.get_joy_name(pads[0]) if not pads.is_empty() else ""

# Botón del mando (número) asignado a una acción, o -1.
func joy_button_of(action: String) -> int:
	for event in _joy_events.get(action, []):
		if event is InputEventJoypadButton:
			return event.button_index
	return -1

# Texto del botón del mando para una acción (A, B, X, Y, Start...).
func joy_label(action: String) -> String:
	var button := joy_button_of(action)
	return _joy_button_text(button) if button >= 0 else "—"

# Asigna un botón físico del mando a una acción. Si ese botón ya era de otra acción, se intercambian.
func bind_joy_button(action: String, button: int, persist: bool = true) -> void:
	if not action in JOY_ACTIONS or button < 0:
		return
	var previous := joy_button_of(action)
	for other in JOY_ACTIONS:
		if other != action and joy_button_of(other) == button and previous >= 0:
			_set_joy_button(other, previous)
	_set_joy_button(action, button)
	_sync_ui_buttons()
	if persist:
		save()

func _set_joy_button(action: String, button: int) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	_joy_events[action] = [event]
	if gamepad_mode:
		InputMap.action_add_event(action, event)

# Menús: el stick y la cruceta navegan; el botón de Interactuar acepta y Start vuelve.
# Estos eventos no se apagan con "Usar control", para que el menú siempre responda al mando.
func _setup_ui_controller() -> void:
	var nav := {
		"ui_up": [JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
		"ui_down": [JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
		"ui_left": [JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
		"ui_right": [JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
	}
	for action in nav:
		var motion := InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = nav[action][0]
		motion.axis_value = nav[action][1]
		_add_once(action, motion)
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = nav[action][2]
		_add_once(action, button)

func _sync_ui_buttons() -> void:
	for ui_action in ["ui_accept", "ui_cancel"]:
		for event in InputMap.action_get_events(ui_action):
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(ui_action, event)
	var accept_buttons := [JOY_BUTTON_A, joy_button_of("interact")]
	var cancel_buttons := [joy_button_of("pause"), JOY_BUTTON_START]
	for button in accept_buttons:
		if button >= 0:
			_add_joy_button_once("ui_accept", button)
	for button in cancel_buttons:
		if button >= 0:
			_add_joy_button_once("ui_cancel", button)

func _add_joy_button_once(action: String, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	_add_once(action, event)

func _add_once(action: String, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func _joy_button_text(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_START: return "Start"
	return "Botón %d" % button

# Etiqueta para los textos de ayuda: el botón del mando si el control está activo y conectado, si no la tecla.
func hint_label(action: String) -> String:
	if gamepad_mode and controller_connected():
		return joy_label(action)
	return key_label(action)

func set_volume(bus: String,value: float, persist: bool = true) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:return
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(value,0.0001)))
	AudioServer.set_bus_mute(index,value <= 0)
	if persist:save()

func bind_key(action: String,key: int,persist: bool = true) -> void:
	if not action in ACTIONS or key <= 0:return
	if persist:
		var previous_key := 0
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey:previous_key=existing.physical_keycode;break
		for other in ACTIONS:
			if other == action:continue
			for existing in InputMap.action_get_events(other):
				if existing is InputEventKey and existing.physical_keycode == key and previous_key > 0:
					bind_key(other,previous_key,false)
					break
	# Solo cambia teclado: conserva mouse y mando, y los nombres de acciones.
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:InputMap.action_erase_event(action,event)
	var event := InputEventKey.new()
	event.physical_keycode=key
	InputMap.action_add_event(action,event)
	bindings[action]=key
	if persist:save()

func key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:return OS.get_keycode_string(event.physical_keycode)
	return "—"

func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("comfort","hints_seen",hints_seen)
	config.set_value("comfort","shake",shake)
	config.set_value("comfort","flashes",flashes)
	config.set_value("comfort","text_scale",text_scale)
	config.set_value("comfort","auto_dialogue",auto_dialogue)
	config.set_value("comfort","dialogue_version",DIALOGUE_VERSION)
	config.set_value("controller","gamepad_mode",gamepad_mode)
	for action in JOY_ACTIONS:
		var button := joy_button_of(action)
		if button >= 0:
			config.set_value("controller","btn_"+action,button)
	config.set_value("display","fullscreen",fullscreen)
	for action in bindings:config.set_value("keys",action,bindings[action])
	for bus in ["Music","SFX","Ambient","UI"]:
		var index := AudioServer.get_bus_index(bus)
		config.set_value("audio",bus,0.0 if AudioServer.is_bus_mute(index) else db_to_linear(AudioServer.get_bus_volume_db(index)))
	return config.save(config_path)

func _setup_controller() -> void:
	# Guardamos los eventos del mando aparte para poder encender y apagar el control sin perderlos.
	for action in ["move_left","move_right","move_up","move_down"]:
		var motion := InputEventJoypadMotion.new()
		motion.device=-1
		motion.axis = JOY_AXIS_LEFT_X if action in ["move_left","move_right"] else JOY_AXIS_LEFT_Y
		motion.axis_value = -1.0 if action in ["move_left","move_up"] else 1.0
		_joy_events[action] = [motion]
	var buttons := {"jump":JOY_BUTTON_A,"attack":JOY_BUTTON_X,"kick":JOY_BUTTON_Y,"interact":JOY_BUTTON_B,"pause":JOY_BUTTON_START}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.device=-1
		event.button_index=buttons[action]
		_joy_events[action] = [event]
	for action in _joy_events:
		for event in _joy_events[action]:
			InputMap.action_add_event(action,event)
