extends "res://scripts/characters/player.gd"

# Phase 1 sandbox: real body gravity, no top-down visual-height simulation.
@export var controls_enabled: bool = true
@export var lateral_gravity: float = 1500.0
@export var fall_speed_limit: float = 900.0
@export var coyote_seconds: float = 0.10
@export var jump_buffer_seconds: float = 0.12
@export var air_control: float = 0.75
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _jump_clock: float = 0.0
var landing_count: int = 0
var last_jump_used_coyote: bool = false
var _landing_pose_left: float = 0.0

func _ready() -> void:
	super._ready()
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 6.0
	up_direction = Vector2.UP
	collision_mask = 1
	var body := RectangleShape2D.new()
	body.size = Vector2(58, 250)
	$CollisionShape2D.shape = body
	$CollisionShape2D.position = Vector2(0, -125)
	anim.frame_changed.connect(_align_lateral_pose)
	_play_ground_animation(&"idle")

func _physics_process(delta: float) -> void:
	if _dead: return
	var was_grounded: bool = is_on_floor()
	_landing_pose_left = maxf(0,_landing_pose_left-delta)
	_coyote_left = coyote_seconds if was_grounded else maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if _await_action_release and not (Input.is_action_pressed("jump") or Input.is_action_pressed("attack") or Input.is_action_pressed("kick")):
		_await_action_release = false
	if controls_enabled and Input.is_action_just_pressed("jump") and not _await_action_release:
		_jump_buffer_left = jump_buffer_seconds
	velocity.y = minf(velocity.y + lateral_gravity * delta, fall_speed_limit)
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		last_jump_used_coyote = not was_grounded
		_begin_jump()
	if controls_enabled and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5
	if _before_lateral_move(delta, was_grounded): return
	var axis: float = _horizontal_axis()
	var response: float = movement_braking if is_zero_approx(axis) or velocity.x * axis < 0 else movement_acceleration
	velocity.x = move_toward(velocity.x, axis * speed, response * (1.0 if was_grounded else air_control) * delta)
	if not is_zero_approx(axis):
		facing = Vector2.LEFT if axis < 0 else Vector2.RIGHT
		anim.flip_h = axis < 0
	move_and_slide()
	is_jumping = not is_on_floor()
	jump_height = 0.0 # Body is physically elevated; never offset the sprite/hurtbox again.
	if is_on_floor() and not was_grounded:
		landing_count += 1
		_landing_pose_left = .16
		# Consume a buffered tap even if the contact occurred this physics tick.
		if _jump_buffer_left > 0.0:
			_begin_jump()
			is_jumping = true
	if is_jumping:
		_jump_clock += delta
		if SpriteFit.has_clip(anim.sprite_frames, &"jump"):
			_play_ground_animation(&"jump")
			anim.pause()
			var count: int = anim.sprite_frames.get_frame_count("jump")
			var half: int = maxi(count / 2, 1)
			anim.frame = mini(int(_jump_clock / 0.33 * half), half - 1) if velocity.y < 0 else mini(half + int(maxf(velocity.y, 0.0) / fall_speed_limit * half), count - 1)
	else:
		if _landing_pose_left > 0 and absf(velocity.x) <= 8 and SpriteFit.has_clip(anim.sprite_frames, &"land"):
			_play_ground_animation(&"land")
			anim.pause()
			anim.frame = 0 if _landing_pose_left > .08 else 1
		else:
			_play_ground_animation(&"walk" if absf(velocity.x) > 8.0 else &"idle")

	_after_lateral_move()

func _horizontal_axis() -> float:
	var axis: float = Input.get_axis("move_left", "move_right")
	if Input.is_physical_key_pressed(KEY_LEFT): axis = -1.0
	if Input.is_physical_key_pressed(KEY_RIGHT): axis = 1.0
	return axis if controls_enabled else 0.0

func _before_lateral_move(_delta: float, _grounded: bool) -> bool:
	return false

func _after_lateral_move() -> void:
	pass

func _begin_jump() -> void:
	velocity.y = -jump_impulse
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_jump_clock = 0.0
	is_jumping = true

# En el modo lateral los pies apoyan en el origen del cuerpo; la escala y el desfase de cada pose
# salen de los mismos datos (fit_*) que usa el juego principal.
func _foot_line() -> float:
	return 0.0

func _play_ground_animation(clip: StringName) -> void:
	# Ranura sin sprites todavía: usa la de respaldo (run -> walk -> idle...).
	clip = SpriteFit.resolve_clip(anim.sprite_frames, clip)
	if clip == &"":
		return
	anim.speed_scale = clampf(absf(velocity.x) / maxf(speed, 1.0), 0.55, 1.15) if clip == &"walk" else 1.0
	anim.play(clip)
	_fit_pose()

func _align_lateral_pose() -> void:
	_fit_pose()

func ground_position() -> Vector2:
	return global_position
