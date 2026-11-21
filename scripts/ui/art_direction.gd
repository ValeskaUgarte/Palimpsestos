extends Node
const THEME: Theme = preload("res://resources/ui/manuscript_theme.tres")
func _ready() -> void:
	get_tree().node_added.connect(_on_node)
	for node in get_tree().root.get_children():_skin_tree(node)
func _skin_tree(node: Node) -> void:
	_skin(node)
	for child in node.get_children():_skin_tree(child)
func _on_node(node: Node) -> void:
	_skin_id.call_deferred(node.get_instance_id())
func _skin_id(id: int) -> void:
	var node=instance_from_id(id)
	if is_instance_valid(node):_skin(node)
func _skin(node: Node) -> void:
	if not is_instance_valid(node):return
	if node is Control and not node.get_parent() is Control:
		node.theme=THEME
	if node is TextureRect and node.name == "Background":
		var material := ShaderMaterial.new()
		material.shader=load("res://assets/shaders/forest_atmosphere.gdshader")
		material.set_shader_parameter("night_mix",0.55)
		node.material=material
	if node is BaseButton and not node.has_meta("manuscript_skin"):
		node.set_meta("manuscript_skin",true)
		node.mouse_entered.connect(_tint.bind(node,Color(1.08,1.04,0.93)))
		node.mouse_exited.connect(_tint.bind(node,Color.WHITE))
		node.focus_entered.connect(_tint.bind(node,Color(1.08,1.04,0.93)))
		node.focus_exited.connect(_tint.bind(node,Color.WHITE))
		node.pressed.connect(func():AudioLandscape.cue(&"ui_accept"))
		# Marco dorado visible cuando el botón tiene el foco (stick, cruceta o teclado).
		var frame := ReferenceRect.new()
		frame.name = "FocusFrame"
		frame.editor_only = false
		frame.border_color = Color("d6b25e")
		frame.border_width = 3.0
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.visible = node.has_focus()
		node.add_child(frame)
		node.focus_entered.connect(frame.set.bind("visible", true))
		node.focus_exited.connect(frame.set.bind("visible", false))
func _tint(button: BaseButton, color: Color) -> void:
	if not is_instance_valid(button):return
	var previous: Tween = button.get_meta("tint_tween") if button.has_meta("tint_tween") else null
	if previous:previous.kill()
	var tween := button.create_tween()
	button.set_meta("tint_tween",tween)
	tween.tween_property(button,"modulate",color,0.13)
