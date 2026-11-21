extends StaticBody2D

## Raíces/tinta localizadas; el collider original conserva el bloqueo del camino.
var _opening: bool = false

func _ready() -> void:
	$DebugGate.hide()
	queue_redraw()

func _draw() -> void:
	for branch in range(7):
		var points := PackedVector2Array()
		for step in range(12):
			var y: float = -340.0 + step * 58.0
			var x: float = sin(step * 0.65 + branch * 1.8) * 17 + (branch - 3) * 6
			points.append(Vector2(x, y))
		# Las puntas se afinan: evita que las raíces parezcan una franja recortada.
		for segment in range(points.size() - 1):
			var progress: float = (segment + 0.5) / (points.size() - 1)
			var width: float = 1.0 + 10.0 * pow(sin(progress * PI), 0.7)
			draw_line(points[segment], points[segment + 1], Color(0.07, 0.05, 0.035, 0.95), width, true)
			draw_line(points[segment], points[segment + 1], Color(0.31, 0.24, 0.16, 0.75), maxf(width * 0.18, 1), true)
		for point in [points[3], points[6], points[9]]:
			draw_line(point, point + Vector2(22 if branch % 2 else -22, -30), Color(0.14, 0.1, 0.06, 0.9), 5, true)

func open() -> void:
	if _opening:
		return
	_opening = true
	AudioLandscape.cue(&"door_open",global_position)
	$CollisionShape2D.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.65)
	tween.tween_property(self, "scale:x", 0.3, 0.65).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(queue_free)
