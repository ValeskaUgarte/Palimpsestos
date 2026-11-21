extends CanvasLayer
var _art: TextureRect
var _camera_origin: float = 0
func _ready() -> void:
	layer = 0
	_art = TextureRect.new()
	_art.texture = preload("res://assets/art/presentation/forest-foreground.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.modulate.a = .78
	add_child(_art)
	var camera := get_viewport().get_camera_2d()
	if camera: _camera_origin = camera.global_position.x
func _process(_delta: float) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_2d()
	var drift: float = clampf((camera.global_position.x-_camera_origin)*-.025,-18,18) if camera else 0
	_art.position = Vector2(-size.x*.14+drift,-size.y*.10)
	_art.size = size*Vector2(1.28,1.20)
