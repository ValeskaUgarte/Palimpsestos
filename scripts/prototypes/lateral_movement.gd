extends Node2D
const WORLD = Rect2(0, 0, 2400, 700)
const BLOCKS = [Rect2(0, 500, 2400, 200), Rect2(560, 450, 240, 50), Rect2(820, 395, 240, 105), Rect2(1860, 195, 200, 25)]
var _status: Label
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Elliot.process_mode = Node.PROCESS_MODE_PAUSABLE
	for rect in BLOCKS + [Rect2(-40, -100, 40, 900), Rect2(2400, -100, 40, 900)]:
		var floor_body := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		floor_body.position = rect.get_center()
		floor_body.collision_layer = 1
		floor_body.collision_mask = 2
		floor_body.add_child(collision)
		add_child(floor_body)
	var texture: Texture2D = preload("res://assets/escenarioCaperusita001.jpg")
	var painting := Sprite2D.new()
	painting.texture = texture
	painting.position = WORLD.get_center()
	painting.scale = Vector2.ONE * maxf(WORLD.size.x / texture.get_width(), WORLD.size.y / texture.get_height())
	painting.z_index = -10
	add_child(painting)
	$Elliot/Camera2D.configure_bounds(WORLD, 0.92, 350.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(20, 16)
	_status.add_theme_color_override("font_color", Color(1, 0.94, 0.78))
	_status.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	_status.add_theme_constant_override("outline_size", 6)
	layer.add_child(_status)
	queue_redraw()
func _process(_delta: float) -> void:
	_status.text = "PALIMPSESTOS · PRUEBA LATERAL (fase 1)\nA/D o ←/→: caminar · SPACE: salto · ESC: pausa\nW/S no desplazan · combate pendiente de fase 3\n" + ("PAUSA" if get_tree().paused else ("SUELO" if $Elliot.is_on_floor() else "SUBIDA" if $Elliot.velocity.y < 0 else "CAÍDA"))
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		$Elliot._await_action_release = true
		get_viewport().set_input_as_handled()
func _draw() -> void:
	for rect in BLOCKS:
		draw_rect(rect, Color(0.12, 0.105, 0.09))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.48, 0.39, 0.25), 3)
