extends Area2D

## Identidad del sello y presentación; el orden sigue perteneciendo al puzzle.
@export var rune_id: int = 1
var _strength: float = 0.0
var _error: float = 0.0
var _near: bool = false
var _accepted: bool = false
var _pulse: Tween
var _pillar: Texture2D
var _light: PointLight2D

func _ready() -> void:
	for child_name in ["DebugDot", "DebugLabel"]:
		var child := get_node_or_null(child_name) as CanvasItem
		if child:
			child.hide()
	_pillar = load("res://assets/props/pillar-%d.tres" % clampi(rune_id,1,3))
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	texture.width = 128
	texture.height = 128
	_light = PointLight2D.new()
	_light.texture = texture
	_light.texture_scale = 1.7
	_light.position = Vector2(0,-180)
	_light.color = Color(0.65,0.88,0.83)
	_light.energy = 0
	add_child(_light)
	set_process(false)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var point: Vector2 = player.ground_position() if player.has_method("ground_position") else player.global_position
	var near: bool = point.distance_to(global_position) < 105.0
	if near != _near:
		_near = near
		_animate_strength(1.0 if _accepted else 0.35 if _near else 0.0)

func set_accepted(value: bool) -> void:
	_accepted = value
	if value: AudioLandscape.cue(&"rune_activate", global_position)
	_animate_strength(1.0 if value else 0.35 if _near else 0.0)

func reject() -> void:
	AudioLandscape.cue(&"rune_error", global_position)
	_error = 1.0
	var tween := create_tween()
	tween.tween_method(_set_error, 1.0, 0.0, 0.55)

func _set_error(value: float) -> void:
	_error = value
	queue_redraw()

func _animate_strength(value: float) -> void:
	if _pulse:
		_pulse.kill()
	_pulse = create_tween()
	_pulse.tween_method(_set_strength, _strength, value, 0.22)

func _set_strength(value: float) -> void:
	_strength = value
	if _light: _light.energy = _strength * 0.35
	queue_redraw()

func _draw() -> void:
	if _pillar == null: return
	var ratio: float = 300.0 / _pillar.get_height()
	var width: float = _pillar.get_width() * ratio
	draw_texture_rect(_pillar, Rect2(-width * 0.5,-300,width,300), false, Color(0.88,0.95,0.95))
	var glyph_center := Vector2(0,-190)
	var ink := Color("7e8981").lerp(Color("c4eadb"), _strength).lerp(Color("d89c78"), _error)
	for ring in range(4):
		draw_circle(glyph_center, 24.0+ring*6, Color(0.48,0.82,0.72,_strength*0.025))
	for stroke in range(rune_id):
		var x: float = (stroke-(rune_id-1)*0.5)*10
		var start := glyph_center+Vector2(x-4,20)
		var end := glyph_center+Vector2(x+4,-20)
		draw_line(start+Vector2(1,2),end+Vector2(1,2),Color(0.025,0.035,0.03),5,true)
		draw_line(start,end,ink,2.3,true)
		draw_line(end,end+Vector2(-7,5),ink,1.8,true)
