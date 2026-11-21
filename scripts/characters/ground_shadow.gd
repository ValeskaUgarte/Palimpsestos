extends Node2D

## Sombra de contacto bajo los pies, sin textura externa ni proceso continuo.
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 33.0, Color(0.025, 0.02, 0.03, 0.12))
	draw_circle(Vector2.ZERO, 24.0, Color(0.025, 0.02, 0.03, 0.20))
