@tool
extends StaticBody2D

## Bordes del camino en coordenadas locales, de izquierda a derecha.
## Las formas se guardan en la escena y se ven con Debug > Visible Collision Shapes.
@export var upper_edge: PackedVector2Array:
	set(value):
		upper_edge = value
		if is_inside_tree():
			_update_polygons.call_deferred()
@export var lower_edge: PackedVector2Array:
	set(value):
		lower_edge = value
		if is_inside_tree():
			_update_polygons.call_deferred()


func _ready() -> void:
	_update_polygons()


func _update_polygons() -> void:
	var upper := get_node_or_null("UpperBoundary") as CollisionPolygon2D
	var lower := get_node_or_null("LowerBoundary") as CollisionPolygon2D
	if upper != null and upper_edge.size() >= 2:
		var polygon: PackedVector2Array = upper_edge.duplicate()
		polygon.append(Vector2(upper_edge[upper_edge.size() - 1].x, -1200))
		polygon.append(Vector2(upper_edge[0].x, -1200))
		upper.polygon = polygon
	if lower != null and lower_edge.size() >= 2:
		var polygon: PackedVector2Array = lower_edge.duplicate()
		polygon.append(Vector2(lower_edge[lower_edge.size() - 1].x, 1200))
		polygon.append(Vector2(lower_edge[0].x, 1200))
		lower.polygon = polygon


func constrain_foot(point: Vector2, margin: float = 14.0) -> Vector2:
	var local_point: Vector2 = to_local(point)
	var top: float = _height_at(upper_edge, local_point.x) + margin
	var bottom: float = _height_at(lower_edge, local_point.x) - margin
	local_point.y = clampf(local_point.y, top, bottom)
	return to_global(local_point)


func _height_at(edge: PackedVector2Array, x: float) -> float:
	if edge.is_empty():
		return 0.0
	for i in range(1, edge.size()):
		if x <= edge[i].x:
			var span: float = maxf(edge[i].x - edge[i - 1].x, 0.001)
			return lerpf(edge[i - 1].y, edge[i].y, clampf((x - edge[i - 1].x) / span, 0.0, 1.0))
	return edge[edge.size() - 1].y
