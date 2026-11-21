extends Control
## VISOR DEL PROYECTO (herramienta de edición, no forma parte del juego).
##
## Ábrelo en Godot con F6 sobre scenes/tools/visor_proyecto.tscn.
## Sirve para:
##   - Ver todos los personajes, NPC y enemigos con sus animaciones (botones para reproducirlas).
##   - Ver los diálogos de cada NPC y probarlos con "Probar diálogo".
##   - Saber en qué escenas aparece cada personaje ("Aparece en").
##   - Ver en qué escena están los diálogos y pistas de cada nivel.
##   - Abrir cualquier escena del juego con un clic.
##
## Lee las escenas sin ejecutarlas (SceneState), así que mirar un personaje no dispara lógica del juego.

# [nombre en el menú, carpetas a leer, leer subcarpetas]
const CATEGORIES := [
	["Personajes jugables", ["res://scenes/characters/player"], true],
	["NPC del cuento", ["res://scenes/characters/npc"], true],
	["Pueblo (ambiente)", ["res://scenes/characters/pueblo"], true],
	["Enemigos", ["res://scenes/characters/enemies"], true],
	["Escenas del cuento", ["res://scenes/levels"], true],
	["Demo de combate (mundos, inframundos, arenas, rutas)", ["res://scenes/demo"], true],
	["Menús, UI y otras", ["res://scenes", "res://scenes/ui", "res://scenes/props", "res://scenes/audio", "res://scenes/prototypes", "res://scenes/lateral"], false],
]
const SCENE_ROOT := "res://scenes"
const PREVIEW_SIZE := Vector2(300, 300)
const DIALOGUE_KEYS := ["dialogue_lines", "lines", "conversation_lines"]

var _category_select: OptionButton
var _list: ItemList
var _paths: Array[String] = []
var _title: Label
var _info: RichTextLabel
var _preview_box: Panel
var _preview_root: Node2D
var _anim_flow: HFlowContainer
var _dialog_box: VBoxContainer
var _open_button: Button
var _usage_select: OptionButton
var _usage_paths: Array[String] = []
var _sprite: AnimatedSprite2D
var _static_sprite: Sprite2D
var _current_path: String = ""
var _usage_cache: Dictionary = {}
var _test_lines: Array = []
var _test_speaker: String = ""
var _test_portrait: Texture2D = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.075)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 16
	root.offset_right = -16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# --- Columna izquierda: categorías y lista ---
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	var heading := Label.new()
	heading.text = "Visor del proyecto"
	heading.add_theme_font_size_override("font_size", 24)
	left.add_child(heading)

	_category_select = OptionButton.new()
	for category in CATEGORIES:
		_category_select.add_item(category[0])
	_category_select.item_selected.connect(_on_category_selected)
	left.add_child(_category_select)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	left.add_child(_list)

	_open_button = Button.new()
	_open_button.text = "Abrir escena seleccionada"
	_open_button.pressed.connect(_on_open_pressed)
	left.add_child(_open_button)

	var back := Button.new()
	back.text = "Volver al menú principal"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	left.add_child(back)

	# --- Columna derecha: detalle ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	scroll.add_child(right)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_title)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 16)
	right.add_child(preview_row)

	_preview_box = Panel.new()
	_preview_box.custom_minimum_size = PREVIEW_SIZE
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.13, 0.15, 0.14)
	preview_style.border_color = Color("8d794c")
	preview_style.set_border_width_all(1)
	_preview_box.add_theme_stylebox_override("panel", preview_style)
	preview_row.add_child(_preview_box)

	_preview_root = Node2D.new()
	_preview_root.position = PREVIEW_SIZE * 0.5
	_preview_box.add_child(_preview_root)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(480, 0)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(_info)

	var anim_title := Label.new()
	anim_title.text = "Animaciones (clic para reproducir)"
	anim_title.add_theme_font_size_override("font_size", 18)
	right.add_child(anim_title)
	_anim_flow = HFlowContainer.new()
	_anim_flow.add_theme_constant_override("h_separation", 6)
	_anim_flow.add_theme_constant_override("v_separation", 6)
	right.add_child(_anim_flow)

	var dialog_title := Label.new()
	dialog_title.text = "Diálogos e interacciones"
	dialog_title.add_theme_font_size_override("font_size", 18)
	right.add_child(dialog_title)
	_dialog_box = VBoxContainer.new()
	_dialog_box.add_theme_constant_override("separation", 6)
	right.add_child(_dialog_box)

	var usage_title := Label.new()
	usage_title.text = "Aparece en estas escenas"
	usage_title.add_theme_font_size_override("font_size", 18)
	right.add_child(usage_title)
	_usage_select = OptionButton.new()
	right.add_child(_usage_select)
	var open_usage := Button.new()
	open_usage.text = "Abrir la escena elegida arriba"
	open_usage.pressed.connect(_open_usage_pressed)
	right.add_child(open_usage)

	_on_category_selected(0)


# ---------------------------------------------------------------- listas

func _on_category_selected(index: int) -> void:
	var category: Array = CATEGORIES[index]
	_paths.clear()
	_list.clear()
	var found: Array[String] = []
	for folder in category[1]:
		found.append_array(_scene_files(String(folder), bool(category[2])))
	found.sort()
	for path in found:
		_paths.append(path)
		_list.add_item(path.get_file().get_basename())
	if not _paths.is_empty():
		_list.select(0)
		_show(0)
	else:
		_title.text = "No hay escenas en esta categoría."
		_clear_details()


func _scene_files(folder: String, recursive: bool) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := folder.path_join(entry)
		if dir.current_is_dir():
			if recursive and not entry.begins_with("."):
				out.append_array(_scene_files(full, true))
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _on_item_selected(index: int) -> void:
	_show(index)


func _show(index: int) -> void:
	if index < 0 or index >= _paths.size():
		return
	_current_path = _paths[index]
	_title.text = _current_path
	var state := _read_state(_current_path)
	_show_preview(state)
	_show_animations(state)
	_show_dialogues(state)
	_show_usages()
	_open_button.text = "Abrir escena seleccionada" if _is_level(_current_path) else "Abrir la primera escena donde aparece"


func _is_level(path: String) -> bool:
	return path.begins_with("res://scenes/levels/") or path.begins_with("res://scenes/demo/") or path.get_file() == "main_menu.tscn"


# ---------------------------------------------------------------- lectura de escenas

func _read_state(path: String) -> Dictionary:
	var result := {"frames": null, "texture": null, "dialogues": [], "properties": {}, "nodes": []}
	var packed := load(path) as PackedScene
	if packed == null:
		return result
	var state := packed.get_state()
	result.properties = _node_properties(state, 0)
	for i in range(state.get_node_count()):
		var type := String(state.get_node_type(i))
		var props := _node_properties(state, i)
		if type == "AnimatedSprite2D" and result.frames == null and props.has("sprite_frames"):
			result.frames = props["sprite_frames"]
		if type == "Sprite2D" and result.texture == null and props.has("texture") and props["texture"] is Texture2D:
			result.texture = props["texture"]
		var lines := _dialogue_from_props(props)
		if not lines.is_empty():
			result.dialogues.append({"node": String(state.get_node_name(i)), "lines": lines, "portrait": props.get("portrait", null), "speaker": _speaker_from_props(props, String(state.get_node_name(i)))})
		# Nodos que son otra escena (p. ej. un NPC colocado en el nivel): leemos su diálogo original.
		var instance := state.get_node_instance(i)
		if instance != null and lines.is_empty():
			var inner := _inner_dialogue(instance, String(state.get_node_name(i)))
			if not inner.is_empty():
				result.dialogues.append(inner)
	return result


func _inner_dialogue(packed: PackedScene, node_name: String) -> Dictionary:
	var inner_state := packed.get_state()
	var root_props := _node_properties(inner_state, 0)
	var lines := _dialogue_from_props(root_props)
	if lines.is_empty():
		return {}
	return {"node": node_name, "lines": lines, "portrait": root_props.get("portrait", null), "speaker": _speaker_from_props(root_props, node_name)}


func _node_properties(state: SceneState, index: int) -> Dictionary:
	var props: Dictionary = {}
	if index < 0 or index >= state.get_node_count():
		return props
	for j in range(state.get_node_property_count(index)):
		props[String(state.get_node_property_name(index, j))] = state.get_node_property_value(index, j)
	return props


func _dialogue_from_props(props: Dictionary) -> Array:
	for key in DIALOGUE_KEYS:
		if props.has(key) and props[key] is Array and not (props[key] as Array).is_empty():
			var out: Array = []
			for line in props[key]:
				out.append(str(line))
			return out
	return []


func _speaker_from_props(props: Dictionary, node_name: String) -> String:
	for key in ["speaker_label", "speaker_name", "speaker"]:
		if props.has(key) and str(props[key]) != "":
			return str(props[key])
	return node_name


# ---------------------------------------------------------------- vista previa y animaciones

func _show_preview(state: Dictionary) -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if _static_sprite != null:
		_static_sprite.queue_free()
		_static_sprite = null
	var frames: SpriteFrames = state.frames
	var texture: Texture2D = state.texture
	if frames != null and not frames.get_animation_names().is_empty():
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_preview_root.add_child(_sprite)
		var first := String(frames.get_animation_names()[0])
		_sprite.animation = first
		_sprite.play(first)
		_fit_preview(frames.get_frame_texture(first, 0), _sprite)
	elif texture != null:
		_static_sprite = Sprite2D.new()
		_static_sprite.texture = texture
		_preview_root.add_child(_static_sprite)
		_fit_preview(texture, _static_sprite)
	_info.text = _info_text(state)


func _fit_preview(texture: Texture2D, node: Node2D) -> void:
	if texture == null:
		return
	var size := texture.get_size()
	if size.x <= 0 or size.y <= 0:
		return
	var factor := minf(PREVIEW_SIZE.x / size.x, PREVIEW_SIZE.y / size.y) * 0.9
	node.scale = Vector2.ONE * factor
	node.position = Vector2.ZERO


func _info_text(state: Dictionary) -> String:
	var lines := PackedStringArray()
	var frames: SpriteFrames = state.frames
	if frames != null:
		lines.append("Animaciones: %d" % frames.get_animation_names().size())
	# Godot no guarda en la escena los valores por defecto: aquí se muestran los reales.
	var props: Dictionary = state.properties
	if props.has("dialogue_lines") or props.has("auto_start"):
		lines.append("Repetible: %s" % ("sí" if bool(props.get("repeatable", false)) else "no"))
		lines.append("Empieza sola al acercarte: %s" % ("sí" if bool(props.get("auto_start", true)) else "no"))
	if props.has("lines") or props.has("auto_show"):
		lines.append("Muestra sola al acercarte: %s" % ("sí" if bool(props.get("auto_show", true)) else "no"))
	if props.has("camera_bounds") or props.has("snap_actors_to_path"):
		lines.append("Pega a los personajes al camino: %s" % ("sí" if bool(props.get("snap_actors_to_path", false)) else "no"))
	if lines.is_empty():
		lines.append("Sin datos extra.")
	return "\n".join(lines)


func _show_animations(state: Dictionary) -> void:
	for child in _anim_flow.get_children():
		child.queue_free()
	var frames: SpriteFrames = state.frames
	if frames == null:
		var none := Label.new()
		none.text = "(Este elemento no tiene animaciones propias)"
		_anim_flow.add_child(none)
		return
	for anim in frames.get_animation_names():
		var button := Button.new()
		button.text = ("%s (%d)" % [String(anim), frames.get_frame_count(anim)]) if frames.get_frame_count(anim) > 0 else ("%s (vacía)" % String(anim))
		button.pressed.connect(_play_animation.bind(String(anim)))
		_anim_flow.add_child(button)


func _play_animation(anim: String) -> void:
	if _sprite == null:
		return
	_sprite.play(anim)
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames != null and frames.has_animation(anim):
		_fit_preview(frames.get_frame_texture(anim, 0), _sprite)


# ---------------------------------------------------------------- diálogos

func _show_dialogues(state: Dictionary) -> void:
	for child in _dialog_box.get_children():
		child.queue_free()
	var dialogues: Array = state.dialogues
	if dialogues.is_empty():
		var none := Label.new()
		none.text = "(Sin diálogos en este elemento)"
		_dialog_box.add_child(none)
		return
	for entry in dialogues:
		var lines: Array = entry.lines
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		_dialog_box.add_child(block)

		var header := HBoxContainer.new()
		block.add_child(header)
		var name_label := Label.new()
		name_label.text = "%s · %d líneas" % [String(entry.node), lines.size()]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		var test := Button.new()
		test.text = "Probar diálogo"
		test.pressed.connect(_test_dialogue.bind(lines, String(entry.speaker), entry.portrait))
		header.add_child(test)

		for line in lines:
			var text := Label.new()
			text.text = "  · " + str(line)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			block.add_child(text)


func _test_dialogue(lines: Array, speaker: String, portrait: Variant) -> void:
	var texture: Texture2D = portrait as Texture2D
	var typed: Array[String] = []
	for line in lines:
		typed.append(str(line))
	DialogueManager.show_dialogue(typed, speaker, texture)


# ---------------------------------------------------------------- dónde aparece

func _show_usages() -> void:
	_usage_select.clear()
	_usage_paths.clear()
	var user_scenes := _scenes_using(_current_path)
	for path in user_scenes:
		_usage_paths.append(path)
		_usage_select.add_item(path.trim_prefix(SCENE_ROOT + "/"))
	if _usage_paths.is_empty():
		_usage_select.add_item("(No aparece en ninguna escena; es una escena suelta)")
		_usage_select.disabled = true
	else:
		_usage_select.disabled = false


func _scenes_using(target: String) -> Array[String]:
	if _usage_cache.has(target):
		return _usage_cache[target]
	var out: Array[String] = []
	if target.begins_with(SCENE_ROOT):
		for path in _all_scenes(SCENE_ROOT):
			if path == target:
				continue
			var text := FileAccess.get_file_as_string(path)
			if text.contains(target):
				out.append(path)
	out.sort()
	_usage_cache[target] = out
	return out


func _all_scenes(folder: String) -> Array[String]:
	var out: Array[String] = []
	out.append_array(_scene_files(folder, true))
	return out


func _open_usage_pressed() -> void:
	if _usage_paths.is_empty():
		return
	var index := _usage_select.selected
	if index < 0 or index >= _usage_paths.size():
		return
	get_tree().change_scene_to_file(_usage_paths[index])


func _on_open_pressed() -> void:
	if _current_path.is_empty():
		return
	if _is_level(_current_path):
		get_tree().change_scene_to_file(_current_path)
	elif not _usage_paths.is_empty():
		get_tree().change_scene_to_file(_usage_paths[0])


func _clear_details() -> void:
	_current_path = ""
	_info.text = ""
	for child in _anim_flow.get_children():
		child.queue_free()
	for child in _dialog_box.get_children():
		child.queue_free()
	_usage_select.clear()
	_usage_paths.clear()
