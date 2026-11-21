class_name StoryTile
extends Control
## MAPA DE UN CUENTO (la tarjeta ilustrada de la plancha de mapas) con el TRAYECTO RECORRIDO encima.
## La usan la pantalla del mapa (grande) y el HUD mientras se juega (pequeña).
##   texture  -> la imagen del cuento (Caperucita = assets/ui/kit/mapa_cuento1.png)
##   progress -> 0..1: cuánto del camino lleva recorrido el jugador; se ilumina en dorado hasta ahí
##   marks    -> posiciones (0..1) de los puntos de escena sobre el camino
## El camino se define con PATH_PX (coordenadas dentro de la imagen original de 251 x 275 px). Si cambias la imagen,
## ajusta esos puntos (de abajo, donde empieza el cuento, hacia arriba).

const SOURCE_SIZE := Vector2(251, 275)
const PATH_PX: Array[Vector2] = [
	Vector2(127, 262), Vector2(121, 238), Vector2(112, 214), Vector2(108, 201), Vector2(121, 191),
	Vector2(135, 181), Vector2(152, 169), Vector2(168, 156), Vector2(150, 147), Vector2(128, 137),
	Vector2(112, 126), Vector2(102, 116), Vector2(80, 118), Vector2(60, 117), Vector2(44, 106),
]
const GOLD := Color(0.98, 0.82, 0.4)

var texture: Texture2D = null:
	set(value):
		texture = value
		queue_redraw()
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var marks: Array[float] = []:
	set(value):
		marks = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
	var points := _points()
	if points.size() < 2:
		return
	var unit := size.x / SOURCE_SIZE.x
	# Trayecto recorrido: brillo suave + línea dorada hasta el progreso actual.
	var walked := _walked_points(points, progress)
	if walked.size() >= 2:
		draw_polyline(walked, Color(1.0, 0.85, 0.4, 0.28), 9.0 * unit, true)
		draw_polyline(walked, Color(1.0, 0.88, 0.5, 0.95), 3.2 * unit, true)
	for mark in marks:
		var point := point_at(mark)
		var reached: bool = mark <= progress + 0.0001
		draw_circle(point, 6.5 * unit, Color(0.07, 0.05, 0.03, 0.9))
		draw_circle(point, 4.5 * unit, GOLD if reached else Color(0.45, 0.4, 0.33))
	# Cabeza del trayecto: donde va Elliot ahora.
	var head := point_at(progress)
	draw_circle(head, 9.0 * unit, Color(1, 0.9, 0.55, 0.3))
	draw_circle(head, 5.5 * unit, Color(0.75, 0.1, 0.1))
	draw_arc(head, 5.5 * unit, 0.0, TAU, 20, Color(1, 0.95, 0.8), 1.6 * unit, true)


## Punto (en coordenadas de este control) que corresponde a una fracción 0..1 del camino.
func point_at(fraction: float) -> Vector2:
	var points := _points()
	if points.is_empty():
		return Vector2.ZERO
	return _along(points, clampf(fraction, 0.0, 1.0))


func _points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var scale_factor := size / SOURCE_SIZE
	for point in PATH_PX:
		result.append(point * scale_factor)
	return result


func _length(points: Array[Vector2]) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total


func _along(points: Array[Vector2], fraction: float) -> Vector2:
	var target := _length(points) * fraction
	var walked := 0.0
	for index in range(1, points.size()):
		var segment := points[index - 1].distance_to(points[index])
		if walked + segment >= target:
			return points[index - 1].lerp(points[index], (target - walked) / maxf(segment, 0.001))
		walked += segment
	return points[points.size() - 1]


func _walked_points(points: Array[Vector2], fraction: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var target := _length(points) * fraction
	var walked := 0.0
	result.append(points[0])
	for index in range(1, points.size()):
		var segment := points[index - 1].distance_to(points[index])
		if walked + segment >= target:
			result.append(points[index - 1].lerp(points[index], (target - walked) / maxf(segment, 0.001)))
			return result
		result.append(points[index])
		walked += segment
	return result


# ---------------------------------------------------------------------------------------------
# AVANCE GUARDADO (lo escribe el HUD mientras se juega y lo lee el mapa)
# ---------------------------------------------------------------------------------------------
## Fracción total 0..1 del Cuento I: las escenas ya superadas cuentan enteras, la actual según hasta dónde llegó.
static func overall_progress() -> float:
	var route: Array = GameSession.progress.get("route", [])
	var reached: int = GameSession.reached_index()
	var total := 0.0
	var count: int = GameSession.PARTS.size()
	for index in count:
		var part := 1.0 if index < reached else 0.0
		if index < route.size():
			part = maxf(part, float(route[index]))
		total += clampf(part, 0.0, 1.0)
	return total / float(count)


## Anota cuánto de la escena lleva recorrido el jugador (solo sube, nunca baja).
static func record(scene_index: int, fraction: float) -> void:
	if scene_index < 0:
		return
	var route: Array = GameSession.progress.get("route", [])
	while route.size() <= scene_index:
		route.append(0.0)
	route[scene_index] = maxf(float(route[scene_index]), clampf(fraction, 0.0, 1.0))
	GameSession.progress["route"] = route
