extends Node2D

## Ambiente ligero en coordenadas del mundo; sin falsas capas de parallax.
@export var fog_color: Color = Color(0.43, 0.59, 0.61, 0.055)
@export var mote_color: Color = Color(0.95, 0.82, 0.5, 0.38)
# Neblina progresiva: al inicio el escenario se ve limpio y se va cerrando al avanzar.
# 'track' es quien avanza; entre 'progress_from' y 'progress_to' (en X) la niebla crece.
var track: Node2D
var progress_from: float = 0.0
var progress_to: float = 1.0
var fixed_density: float = -1.0
var _density: float = 0.0
var _clock: float = 0.0
var _rewrite_left: float = 0.0
var _motes: Array[Vector3] = []
var _camera: Camera2D
var _mist: Texture2D
# Niebla por zonas: cada Vector2 es (X inicial, X final) en coordenadas del mundo.
# Entra y sale suavemente en los bordes (fog_fade). Sin zonas = sin niebla (el resto de las escenas no cambia).
var fog_zones: PackedVector2Array = PackedVector2Array()
var fog_fade: float = 700.0
var fog_density: float = 0.5
var fog_zone_densities: PackedFloat32Array = PackedFloat32Array()
var _night: float = 0.0
# Lluvia por zonas (igual que la niebla): cada Vector2 es (X inicial, X final) del mundo.
var rain_zones: PackedVector2Array = PackedVector2Array()
var rain_fade: float = 600.0
var rain_density: float = 0.5
var _rain: float = 0.0
# La primera vez que hay cámara, la lluvia/niebla arrancan ya en su valor (continuidad entre escenas).
var _snapped: bool = false
var _night_mist: Texture2D

func _ready() -> void:
	z_index = 3
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,0.13), Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 128
	texture.height = 64
	_mist = texture
	var night_gradient := Gradient.new()
	night_gradient.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0)])
	night_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var night_texture := GradientTexture2D.new()
	night_texture.gradient = night_gradient
	night_texture.fill = GradientTexture2D.FILL_RADIAL
	night_texture.fill_from = Vector2(0.5, 0.5)
	night_texture.fill_to = Vector2(1, 0.5)
	night_texture.width = 512
	night_texture.height = 192
	_night_mist = night_texture
	var random := RandomNumberGenerator.new()
	random.seed = 77193
	for i in range(26):
		_motes.append(Vector3(random.randf_range(-200, 1400), random.randf_range(160, 610), random.randf_range(0, TAU)))

func _process(delta: float) -> void:
	var target: float = fixed_density
	if target < 0.0:
		target = 0.0
		if is_instance_valid(track) and progress_to > progress_from:
			target = clampf((track.global_position.x - progress_from) / (progress_to - progress_from), 0.0, 1.0)
	_density = move_toward(_density, target, delta * 0.25)
	_clock += delta
	_rewrite_left = maxf(0.0,_rewrite_left-delta)
	_camera = get_viewport().get_camera_2d()
	if not fog_zones.is_empty() and _camera != null:
		var camera_x: float = _camera.get_screen_center_position().x
		var fog_target: float = 0.0
		for zone_index in fog_zones.size():
			var zone: Vector2 = fog_zones[zone_index]
			var zone_density: float = fog_zone_densities[zone_index] if zone_index < fog_zone_densities.size() else fog_density
			var inside: float = smoothstep(zone.x, zone.x + fog_fade, camera_x) * (1.0 - smoothstep(zone.y - fog_fade, zone.y, camera_x))
			fog_target = maxf(fog_target, inside * zone_density)
		_night = fog_target if not _snapped else move_toward(_night, fog_target, delta * 0.5)
	if not rain_zones.is_empty() and _camera != null:
		var rain_x: float = _camera.get_screen_center_position().x
		var rain_target: float = 0.0
		for rain_zone in rain_zones:
			var rain_inside: float = smoothstep(rain_zone.x, rain_zone.x + rain_fade, rain_x) * (1.0 - smoothstep(rain_zone.y - rain_fade, rain_zone.y, rain_x))
			rain_target = maxf(rain_target, rain_inside)
		_rain = rain_target if not _snapped else move_toward(_rain, rain_target, delta * 0.6)
	if _camera != null: _snapped = true
	queue_redraw()

func _draw() -> void:
	if _camera == null:
		return
	var half: Vector2 = get_viewport_rect().size / _camera.zoom * 0.5
	var center: Vector2 = _camera.get_screen_center_position()
	var left: float = center.x - half.x
	var top: float = center.y - half.y
	var thick: float = smoothstep(0.0, 1.0, _density)
	# Atenuación general del color del paisaje a medida que se avanza.
	if thick > 0.01:
		draw_rect(Rect2(left - 20, top - 20, half.x * 2 + 40, half.y * 2 + 40), Color(0.05, 0.08, 0.1, 0.34 * thick))
	var banks: int = 3 + int(round(thick * 9.0))
	for i in range(banks):
		var x: float = left + fposmod(i * 330.0 + _clock * (8 + i), half.x * 2 + 700) - 350
		var layer: int = i % 3
		var y: float = 245 + layer * 70 + sin(_clock * 0.13 + i) * 22
		var strength: float = (0.35 + thick * 2.6 + _rewrite_left * 0.2) * (1.0 if layer < 2 else 0.8)
		draw_texture_rect(_mist, Rect2(x, y - 55, 760, 170), false, Color(fog_color.r, fog_color.g, fog_color.b, minf(fog_color.a * 10.0 * strength, 0.9)))
	if _night > 0.01:
		_draw_night_fog(left, top, half, center)
	if _rain > 0.01:
		_draw_rain(left, top, half)
	for mote in _motes:
		var x: float = left + fposmod(mote.x + _clock * 6.0, half.x * 2 + 80) - 40
		var y: float = center.y - half.y + mote.y + sin(_clock * 0.7 + mote.z) * 9
		var alpha: float = (0.2 + 0.55 * (sin(_clock * 0.45 + mote.z) * 0.5 + 0.5)) * (1.0 - 0.4 * thick)
		draw_circle(Vector2(x,y), 1.1, Color(mote_color, mote_color.a * alpha))

func rewrite() -> void:
	_rewrite_left = 1.0


func _draw_night_fog(left: float, top: float, half: Vector2, center: Vector2) -> void:
	var width: float = half.x * 2.0
	var height: float = half.y * 2.0
	var dense: float = maxf(0.0, _night - 0.8) * 5.0
	# Velo general frío, más denso hacia el suelo.
	var veil := PackedVector2Array([Vector2(left - 20, top - 20), Vector2(left + width + 20, top - 20), Vector2(left + width + 20, top + height + 20), Vector2(left - 20, top + height + 20)])
	var veil_colors := PackedColorArray([
		Color(0.55, 0.62, 0.72, 0.03 * _night + dense * 0.12), Color(0.55, 0.62, 0.72, 0.03 * _night + dense * 0.12),
		Color(0.62, 0.69, 0.78, 0.10 * _night + dense * 0.26), Color(0.62, 0.69, 0.78, 0.10 * _night + dense * 0.26)])
	draw_polygon(veil, veil_colors)
	# Bancos de niebla que derivan lentamente: una capa baja y densa y otra a media altura.
	for i in range(10):
		var low: bool = i % 4 != 3
		var speed: float = 9.0 + float(i % 5) * 4.0
		var span: float = width + 1500.0
		var x: float = left + fposmod(float(i) * 417.0 + _clock * speed, span) - 750.0
		var y: float
		var size: Vector2
		var alpha: float
		if low:
			y = top + height * (0.66 + 0.06 * float(i % 3)) + sin(_clock * 0.17 + float(i)) * 14.0
			size = Vector2(1250.0, 300.0)
			alpha = 0.30
		else:
			y = top + height * (0.40 + 0.05 * float(i % 4)) + sin(_clock * 0.13 + float(i)) * 20.0
			size = Vector2(1500.0, 340.0)
			alpha = 0.16
		draw_texture_rect(_night_mist, Rect2(x - size.x * 0.5, y - size.y * 0.5, size.x, size.y), false, Color(0.74, 0.8, 0.88, minf(alpha * _night * (1.0 + dense * 1.2), 0.85)))


func _draw_rain(left: float, top: float, half: Vector2) -> void:
	var width: float = half.x * 2.0
	var height: float = half.y * 2.0
	var count: int = int(190.0 * rain_density)
	var color := Color(0.78, 0.85, 0.95, 0.26 * _rain)
	for i in count:
		var fx: float = fposmod(float(i) * 0.6180339, 1.0)
		var phase: float = fposmod(float(i) * 0.381966 + 0.137, 1.0)
		var fall_speed: float = 900.0 + 300.0 * fposmod(float(i) * 0.7548777, 1.0)
		var y: float = top + fposmod(phase * height + _clock * fall_speed, height + 60.0) - 30.0
		var x: float = left + fx * width + (y - top) * 0.18
		draw_line(Vector2(x, y), Vector2(x + 6.0, y + 24.0), color, 1.4)
