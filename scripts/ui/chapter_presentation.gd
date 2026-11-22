extends CanvasLayer

## Presentación corta, no modal. El jugador puede moverse inmediatamente.
@export var chapter_title: String = ""
@export var chapter_subtitle: String = ""
@export_range(0.0, 0.5, 0.01) var edge_strength: float = 0.22

@onready var title_card: VBoxContainer = $TitleCard


func _ready() -> void:
	var frame_material := $Frame.material as ShaderMaterial
	# Cada instancia mantiene su propia intensidad.
	frame_material = frame_material.duplicate() as ShaderMaterial
	$Frame.material = frame_material
	frame_material.set_shader_parameter("edge_strength", edge_strength)
	_add_controls_hint()
	present_title(chapter_title, chapter_subtitle)

## Muestra el título (y subtítulo) un momento. Sirve para cambiar el título de cada escena jugable.
func present_title(title_text: String, subtitle_text: String) -> void:
	chapter_title = title_text
	chapter_subtitle = subtitle_text
	$TitleCard/Title.text = title_text
	$TitleCard/Subtitle.text = subtitle_text
	title_card.visible = not title_text.is_empty()
	if _title_tween != null:
		_title_tween.kill()
	if not title_card.visible:
		return
	title_card.modulate.a = 0.0
	_title_tween = create_tween()
	_title_tween.tween_interval(0.25)
	_title_tween.tween_property(title_card, "modulate:a", 1.0, 0.65)
	_title_tween.tween_interval(2.4)
	_title_tween.tween_property(title_card, "modulate:a", 0.0, 0.8)
	_title_tween.tween_callback(title_card.hide)

var _title_tween: Tween = null

var _hint: Label
var _hint_elapsed: float = 0

func _process(delta: float) -> void:
	if not is_instance_valid(_hint):return
	_hint.visible=not DialogueManager.visible
	if not _hint.visible:return
	_hint_elapsed+=delta
	_hint.modulate.a=clampf(minf(_hint_elapsed*3,(8-_hint_elapsed)*2),0,1)
	if _hint_elapsed>=8:
		_hint.queue_free()
		GamePreferences.hints_seen=true
		GamePreferences.save()

func _add_controls_hint() -> void:
	if GamePreferences.hints_seen or get_parent().scene_file_path != "res://scenes/levels/cuento1_escena1.tscn":return
	_hint=Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left=-560;_hint.offset_right=560
	_hint.offset_top=-62;_hint.offset_bottom=-30
	_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size",15)
	_hint.add_theme_color_override("font_color",Color("e2d6b6"))
	_hint.add_theme_color_override("font_shadow_color",Color(.01,.02,.02))
	_hint.add_theme_constant_override("shadow_offset_y",2)
	_hint.text="%s/%s caminar · %s salto · %s golpe · %s patada · %s interactuar" % [GamePreferences.key_label("move_left"),GamePreferences.key_label("move_right"),GamePreferences.key_label("jump"),GamePreferences.key_label("attack"),GamePreferences.key_label("kick"),GamePreferences.key_label("interact")]
	add_child(_hint)

var _memory: Label
var _memory_tween: Tween
var _center: Label
var _center_tween: Tween

## Mensaje grande en el centro de la pantalla (estado de Elliot: miedo, cansancio, hambre).
func show_center(message: String) -> void:
	if _center == null:
		_center = Label.new()
		_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_center.offset_left = -260
		_center.offset_right = 260
		_center.offset_top = -40
		_center.offset_bottom = -12
		_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
		_center.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		_center.add_theme_constant_override("outline_size", 6)
		_center.add_theme_font_size_override("font_size", 20)
		add_child(_center)
	if _center_tween: _center_tween.kill()
	_center.text = message
	_center.show()
	_center.modulate.a = 0
	_center_tween = create_tween()
	_center_tween.tween_property(_center, "modulate:a", 1.0, 0.25)
	_center_tween.tween_interval(1.8)
	_center_tween.tween_property(_center, "modulate:a", 0.0, 0.9)
func rewrite(message: String) -> void:
	if _memory == null:
		_memory = Label.new()
		_memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Abajo al centro (nada de texto en la esquina superior derecha), sobre la pista de controles.
		_memory.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_memory.offset_left = -400
		_memory.offset_right = 400
		_memory.offset_top = -110
		_memory.offset_bottom = -76
		_memory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_memory.add_theme_color_override("font_color", Color(0.87,0.83,0.7))
		_memory.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.02))
		_memory.add_theme_constant_override("shadow_offset_y",2)
		_memory.add_theme_font_size_override("font_size",18)
		add_child(_memory)
	if _memory_tween: _memory_tween.kill()
	_memory.text = message
	_memory.show()
	_memory.modulate.a = 0
	_memory_tween=create_tween()
	_memory_tween.tween_property(_memory,"modulate:a",1.0,0.25)
	_memory_tween.tween_interval(1.2)
	_memory_tween.tween_property(_memory,"modulate:a",0.0,0.8)
	var material := $Frame.material as ShaderMaterial
	var pulse := create_tween()
	pulse.tween_method(func(v: float):material.set_shader_parameter("edge_strength",v),edge_strength,minf(edge_strength+0.12,0.45),0.2)
	pulse.tween_method(func(v: float):material.set_shader_parameter("edge_strength",v),minf(edge_strength+0.12,0.45),edge_strength,0.8)
