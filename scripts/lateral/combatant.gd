extends "res://scripts/prototypes/lateral_player.gd"
# El demo usa los mismos spritesheets que el juego (Elliot, Jhon y Thomas).
@export var fighter_id: String = "elliot"
var _heard_landings: int = 0
var _presentation_clock: float = 0
var _combat_guard_left: float = 0
func _play_ground_animation(clip: StringName) -> void:
	if clip == &"idle" and _combat_guard_left > 0 and SpriteFit.has_clip(anim.sprite_frames, &"idle_combat"):
		clip = &"idle_combat"
	super._play_ground_animation(clip)
func _refresh_attack_contact() -> void:
	var was_presented: bool = _swing_presented
	super._refresh_attack_contact()
	if not was_presented and _swing_presented and is_inside_tree():
		var stroke := Node2D.new()
		stroke.set_script(preload("res://scripts/lateral/attack_stroke.gd"))
		stroke.sword = fighter_id == "jhon"
		stroke.heavy = combo_step == 3 or fighter_id == "thomas"
		stroke.facing_sign = facing.x
		get_parent().add_child(stroke)
		stroke.global_position = global_position+Vector2(25*facing.x,-125)
func _ready() -> void:
	if not has_node("Camera2D"):
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		camera.set_script(preload("res://scripts/systems/cinematic_camera.gd"))
		add_child(camera)
	var existing_camera := get_node("Camera2D") as Camera2D
	if not existing_camera.has_method("configure_bounds"):
		existing_camera.set_script(preload("res://scripts/systems/cinematic_camera.gd"))
		existing_camera._ready()
	controls_enabled = not is_companion
	super._ready()
	var hurt := RectangleShape2D.new()
	hurt.size = Vector2(90, 250)
	$Hurtbox.position = Vector2.ZERO
	$Hurtbox/CollisionShape2D.shape = hurt
	$Hurtbox/CollisionShape2D.position = Vector2(0, -125)
	var definition: Resource = load("res://resources/lateral/" + fighter_id + ".tres")
	speed = definition.speed
	air_control = definition.air_control
	attack_1_profile = attack_1_profile.duplicate()
	attack_2_profile = attack_2_profile.duplicate()
	finisher_profile = finisher_profile.duplicate()
	kick_profile = kick_profile.duplicate()
	for profile in [attack_1_profile, attack_2_profile, finisher_profile]:
		profile.playback_speed *= definition.attack_speed
		profile.hitbox_size.x = definition.attack_width
		profile.hitbox_offset.x = definition.attack_offset
		profile.impact_strength *= definition.weight
	kick_profile.playback_speed *= definition.attack_speed
	var shadow := Node2D.new()
	shadow.set_script(preload("res://scripts/lateral/physical_shadow.gd"))
	add_child(shadow)
	var steps := Node.new()
	steps.set_script(preload("res://scripts/audio/footsteps.gd"))
	add_child(steps)
func _physics_process(delta: float) -> void:
	if _dead: return
	_combat_guard_left = maxf(0,_combat_guard_left-delta)
	if ScenePages.busy:
		velocity.x = 0
		velocity.y = minf(velocity.y + lateral_gravity * delta, fall_speed_limit)
		move_and_slide()
		return
	super._physics_process(delta)
	_update_secondary_motion(delta)

func _update_secondary_motion(delta: float) -> void:
	_presentation_clock += delta
	# Horizontal follow-through preserves feet height, collisions and timings.
	var target: float = 0
	if is_attacking:
		target = facing.x*sin(clampf(_attack_progress,0,1)*PI)*4
	elif anim.animation == &"walk":
		target = clampf(velocity.x*.018,-3,3)
	elif is_on_floor() and _hurt_presentation_time <= 0 and _interaction_time <= 0:
		target = sin(_presentation_clock*1.6)*.7
	anim.position.x = lerpf(anim.position.x,target,1-exp(-delta*14))

func _on_hitbox_area_entered(area: Area2D) -> void:
	if ScenePages.busy: return
	super._on_hitbox_area_entered(area)

func _horizontal_axis() -> float:
	if not is_companion: return super._horizontal_axis()
	var target = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(target): return 0.0
	var distance: float = target.position.x + companion_follow_offset.x - position.x
	return signf(distance) if absf(distance) > 35 else 0.0
func _before_lateral_move(delta: float, _grounded: bool) -> bool:
	if is_companion and _grounded and not is_attacking and _hurt_presentation_time <= 0:
		var direction: float = _horizontal_axis()
		if direction != 0:
			var query := PhysicsRayQueryParameters2D.create(global_position+Vector2(direction*32,-20),global_position+Vector2(direction*80,-20),1)
			if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): _begin_jump()
	_damage_recoil = move_toward(_damage_recoil, 0.0, delta * 0.8)
	anim.rotation = _damage_recoil
	if not is_attacking and _interaction_time > 0 and is_on_floor():
		if controls_enabled and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("kick")):
			_interaction_time = 0
		else:
			_interaction_time = maxf(0,_interaction_time-delta)
			velocity.x = knockback.x
			move_and_slide()
			if _interaction_time == 0: _play_ground_animation("idle")
			return true
	if not is_attacking and _hurt_presentation_time <= 0:
		if combo_timer > 0:
			combo_timer -= delta
			if combo_timer <= 0: combo_step = 0
		return false
	if is_attacking:
		if _fallback_attack:
			_fallback_elapsed += delta
			_attack_progress = minf(_fallback_elapsed / _attack_duration, 1)
		else: _attack_progress = _attack_profile.clip_progress(anim)
		_refresh_attack_contact()
		var advance: float = _attack_profile.advance_pixels / maxf(_attack_duration * (_attack_profile.contact_end - 0.15), 0.01) if _attack_progress >= 0.15 and _attack_progress < _attack_profile.contact_end else 0.0
		velocity.x = facing.x * advance + knockback.x
		if controls_enabled:
			if Input.is_action_just_pressed("attack") and not _await_action_release: buffered_action = "attack"
			elif Input.is_action_just_pressed("kick") and not _await_action_release: buffered_action = "kick"
	else:
		_hurt_presentation_time = maxf(0, _hurt_presentation_time - delta)
		velocity.x = knockback.x
		if _hurt_presentation_time == 0: _play_ground_animation("idle")
	move_and_slide()
	knockback = knockback.move_toward(Vector2.ZERO, 900 * delta)
	is_jumping = not is_on_floor()
	if _contact_active:
		for area in hitbox.get_overlapping_areas(): _on_hitbox_area_entered(area)
	if _fallback_attack and _attack_progress >= 1: _end_attack()
	return true
func _begin_jump() -> void:
	super._begin_jump()
	AudioLandscape.cue(&"jump_takeoff", ground_position())

func _after_lateral_move() -> void:
	if landing_count > _heard_landings:
		_heard_landings = landing_count
		AudioLandscape.cue(&"jump_land", ground_position())
		var mist := Node2D.new()
		mist.set_script(preload("res://scripts/lateral/ground_mist.gd"))
		get_parent().add_child(mist)
		mist.global_position = ground_position()
	if is_companion:
		var target = get_tree().get_first_node_in_group("player")
		if is_on_floor() and is_instance_valid(target) and target.position.y < position.y - 30 and absf(target.position.x - position.x) < 250: _begin_jump()
		return
	knockback = knockback.move_toward(Vector2.ZERO, 900 * get_physics_process_delta_time())
	if not is_on_floor() or _await_action_release: return
	if Input.is_action_just_pressed("attack"): _do_hit("attack")
	elif Input.is_action_just_pressed("kick"): _do_hit("kick")
func _do_hit(action: String) -> void:
	if not is_on_floor() or ScenePages.busy: return
	super._do_hit(action)
	if is_attacking:
		_combat_guard_left = 1.2
		var offset: Vector2 = _attack_profile.hitbox_offset
		hitbox.position = Vector2(offset.x * facing.x, offset.y)
func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	super.take_damage(amount, from_position)
	if not _dead:
		if not is_attacking and not is_jumping:
			_hurt_presentation_time = .2
		velocity.x = knockback.x
		# A physical jump may continue; damage never adds an upward impulse.
func _on_died() -> void:
	if _dead: return
	_dead = true
	is_attacking = false
	_contact_active = false
	buffered_action = ""
	velocity = Vector2.ZERO
	hitbox_shape.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	anim.pause()
	anim.modulate = Color(.4,.43,.45)
	AudioLandscape.cue(&"death", ground_position())
	if is_companion:
		remove_from_group("companion")
		$CollisionShape2D.set_deferred("disabled", true)
	else:
		get_parent().defeat.call_deferred()
