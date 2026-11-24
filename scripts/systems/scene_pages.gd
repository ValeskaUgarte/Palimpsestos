extends CanvasLayer
var busy: bool = false
var _veil: ColorRect
var _material: ShaderMaterial
func _ready() -> void:
	layer=100
	process_mode=Node.PROCESS_MODE_ALWAYS
	_veil=ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_material=ShaderMaterial.new()
	_material.shader=load("res://assets/shaders/page_turn.gdshader")
	_veil.material=_material
	add_child(_veil)
	_veil.hide()
func travel(path: String) -> void:
	if busy:return
	if not ResourceLoader.exists(path):
		push_error("Página inexistente: "+path)
		return
	busy=true
	# Si se sale a mitad de la transición de derrota (cámara lenta), la escena siguiente arranca a velocidad normal.
	Engine.time_scale=1.0
	_travel.call_deferred(path)
func _set_coverage(value: float) -> void:
	_material.set_shader_parameter("coverage",value)
func _travel(path: String) -> void:
	AudioLandscape.cue(&"page_turn")
	_veil.show()
	_veil.mouse_filter=Control.MOUSE_FILTER_STOP
	var ink:=create_tween()
	ink.tween_method(_set_coverage,0.0,1.0,0.32).set_trans(Tween.TRANS_SINE)
	await ink.finished
	get_tree().paused=false
	get_node("/root/DialogueManager").hide()
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:push_error("No se pudo abrir la página: "+path)
	await get_tree().process_frame
	var reveal:=create_tween()
	reveal.tween_method(_set_coverage,1.0,0.0,0.4).set_trans(Tween.TRANS_SINE)
	await reveal.finished
	_veil.hide()
	_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	busy=false


## Devuelve la capa de transición a su estado normal (sin velo, sin bloqueo, sin pausa).
## Lo llaman las pantallas de menú al abrirse, para que nunca queden trabadas por una transición anterior.
func reset() -> void:
	busy = false
	if _veil != null:
		_veil.hide()
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	var dialogue := get_node_or_null("/root/DialogueManager")
	if dialogue != null:
		dialogue.hide()

