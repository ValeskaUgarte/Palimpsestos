extends Camera2D

## La cámara conserva su nodo y sigue a Elliot sin modificar sus controles.
## Anticipación = posición; impacto = offset. Nunca compiten por el encuadre.
@export_range(0.7, 1.3, 0.01) var framing_zoom: float = 0.92
@export var framing_offset: Vector2 = Vector2(20.0, 40.0)
@export var look_ahead: Vector2 = Vector2(72.0, 28.0)
@export var lock_vertical: bool = true
@export var fixed_framing: bool = false
@export var fixed_center: Vector2 = Vector2.ZERO
@export_range(1.0, 12.0, 0.1) var follow_speed: float = 6.0
@export_range(0.0, 8.0, 0.1) var maximum_shake: float = 4.0

var _body: CharacterBody2D
var _health: Node
var _bounds: Rect2
var _has_bounds: bool = false
var _anticipation: Vector2 = Vector2.ZERO
var _last_body_position: Vector2
var _shake_left: float = 0.0
var _shake_duration: float = 0.18
var _shake_amplitude: float = 0.0
var _shake_phase: float = 0.0
var _last_clock: int = 0
var _horizon_y: float = 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	position = framing_offset
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed
	limit_smoothed = true
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 1
	if _body != null:
		_last_body_position = _body.global_position
		_health = _body.get_node_or_null("HealthComponent")
	_last_clock = Time.get_ticks_msec()
	get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()


func configure_bounds(world_bounds: Rect2, zoom_value: float, horizon_y: float = 0.0) -> void:
	_bounds = world_bounds
	_horizon_y = horizon_y
	_has_bounds = world_bounds.has_area()
	framing_zoom = zoom_value
	if _has_bounds:
		limit_left = int(ceilf(_bounds.position.x))
		limit_top = int(ceilf(_bounds.position.y))
		limit_right = int(floorf(_bounds.end.x))
		limit_bottom = int(floorf(_bounds.end.y))
	_update_zoom()
	if lock_vertical:
		global_position.y = _horizon_y
	# Evita viajar desde el origen al entrar en un nivel.
	reset_smoothing()
	force_update_scroll()


func _update_zoom() -> void:
	var fitted_zoom: float = framing_zoom
	if _has_bounds:
		var viewport_size: Vector2 = get_viewport_rect().size
		# Ventanas altas/anchas tampoco deben mostrar fuera del escenario.
		fitted_zoom = maxf(fitted_zoom, viewport_size.x / _bounds.size.x)
		fitted_zoom = maxf(fitted_zoom, viewport_size.y / _bounds.size.y)
	zoom = Vector2.ONE * fitted_zoom


func _physics_process(delta: float) -> void:
	if _body == null or not is_current():
		return
	if fixed_framing:
		global_position = fixed_center
		_update_shake()
		return
	var travelled: Vector2 = _body.global_position - _last_body_position
	_last_body_position = _body.global_position
	var desired: Vector2 = Vector2.ZERO
	var alive: bool = _health == null or int(_health.get("current_health")) > 0
	if not bool(_body.get("is_attacking")) and alive:
		# Movimiento real: una pared no provoca anticipación al empujarla.
		var movement: Vector2 = travelled / maxf(delta, 0.001)
		var normal_speed: float = maxf(float(_body.get("speed")), 1.0)
		desired = Vector2(
			clampf(movement.x / normal_speed, -1.0, 1.0) * look_ahead.x,
			clampf(movement.y / normal_speed, -1.0, 1.0) * look_ahead.y
		)
	_anticipation = _anticipation.lerp(desired, 1.0 - exp(-4.0 * delta))
	position = framing_offset + _anticipation
	if lock_vertical:
		# La profundidad se ve en el personaje, no desplazando todo el paisaje.
		global_position.y = _horizon_y
	_update_shake()


func add_impact(strength: float, duration: float) -> void:
	_shake_amplitude = maxf(_shake_amplitude, clampf(strength, 0.0, maximum_shake))
	_shake_duration = maxf(duration, 0.01)
	_shake_left = _shake_duration
	_shake_phase = randf() * TAU
	_last_clock = Time.get_ticks_msec()


func _update_shake() -> void:
	var now: int = Time.get_ticks_msec()
	var real_delta: float = minf(float(now - _last_clock) / 1000.0, 0.05)
	_last_clock = now
	if _shake_left <= 0.0:
		offset = Vector2.ZERO
		_shake_amplitude = 0.0
		return
	_shake_left = maxf(_shake_left - real_delta, 0.0)
	var envelope: float = pow(_shake_left / _shake_duration, 2.0)
	_shake_phase += real_delta * 65.0
	var shake: Vector2 = Vector2(sin(_shake_phase), sin(_shake_phase * 1.37))
	shake *= _shake_amplitude * envelope * GamePreferences.shake
	if _has_bounds:
		# Camera2D permite que offset sobrepase límites: recortamos el impacto.
		var half_view: Vector2 = get_viewport_rect().size / zoom * 0.5
		var center: Vector2 = get_screen_center_position() - offset
		var minimum: Vector2 = _bounds.position + half_view
		var maximum: Vector2 = _bounds.end - half_view
		shake.x = clampf(shake.x, minf(0.0, minimum.x - center.x), maxf(0.0, maximum.x - center.x))
		shake.y = clampf(shake.y, minf(0.0, minimum.y - center.y), maxf(0.0, maximum.y - center.y))
	offset = shake
