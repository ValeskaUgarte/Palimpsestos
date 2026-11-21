extends Node2D

var strength: float = 1.0
var direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
const LIFETIME: float = 0.18

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress: float = clampf(_elapsed / LIFETIME, 0.0, 1.0)
	var radius: float = (18.0 + 12.0 * strength) * (0.65 + progress)
	var axis: Vector2 = direction if direction.length_squared() > 0.1 else Vector2.RIGHT
	for i in range(5):
		var ray: Vector2 = axis.rotated((i - 2) * 0.43)
		var start: Vector2 = ray * radius * 0.2
		var end: Vector2 = ray * radius * (0.65 + 0.1 * (i % 3))
		draw_line(start, end, Color(0.07, 0.06, 0.045, (1.0 - progress) * 0.85), 3.0, true)
		draw_line(start, end * 0.82, Color(0.95, 0.85, 0.62, 1.0 - progress), 1.2, true)
	# Small expelled ink drops extend the contact, without covering actors.
	for i in 6:
		var ray: Vector2 = axis.rotated((i-2.5)*.5)
		var point: Vector2 = ray*radius*(.45+progress*.9)
		draw_circle(point,(1-progress)*(1.5+strength*.4),Color(.05,.055,.055,(1-progress)*.8))
