extends "res://scripts/characters/story_boss.gd"
# Los enemigos del demo usan los mismos spritesheets que el juego.
# Tamaño relativo de cuerpo, golpe y alcance según la criatura (el arte ya viene más grande).
const SIZE_BOOST := {"Wolf1":1.45,"Wolf2":1.45,"RangerWood":1.35,"Lobo":1.25,"WolfWhite":1.3,"Gnomo":1.3}
@export var boss_encounter: bool = false
var _fall_velocity: float = 0
func _ready() -> void:
	super._ready()
	if not boss_encounter: remove_from_group("story_boss")
	collision_mask = 1
	var boost: float = SIZE_BOOST.get(scene_file_path.get_file().get_basename(),1.0)
	var body := RectangleShape2D.new()
	body.size = Vector2(90, 250 if boss_encounter else 100) * boost
	$CollisionShape2D.shape = body
	$CollisionShape2D.position = Vector2(0, -body.size.y / 2)
	var hurt := RectangleShape2D.new()
	hurt.size = Vector2(110, 250 if boss_encounter else 140) * boost
	$Hurtbox.position = Vector2.ZERO
	$Hurtbox/CollisionShape2D.shape = hurt
	$Hurtbox/CollisionShape2D.position = Vector2(0, -hurt.size.y / 2)
	var hit := RectangleShape2D.new()
	hit.size = Vector2(210 if boss_encounter else 100, 160 if boss_encounter else 140) * boost
	hitbox_shape.shape = hit
	hitbox_shape.position = Vector2.ZERO
	$Hitbox.position = Vector2(145 if boss_encounter else 80, -125 if boss_encounter else -70) * boost
	attack_range = (145 if boss_encounter else 95) * boost
	if not boss_encounter: detection_radius = maxf(detection_radius, 560.0)
	floor_snap_length = 6
	_play_animation("idle")
	var bar := Node2D.new()
	bar.set_script(preload("res://scripts/lateral/enemy_health.gd"))
	add_child(bar)
func ground_position() -> Vector2: return global_position
func _apply_frame_alignment() -> void:
	super._apply_frame_alignment()
	var texture: Texture2D = visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	var baseline: float = float(texture.get_meta("pose_art_baseline", 200))
	visual.position.y = -baseline * visual.scale.y
func _physics_process(delta: float) -> void:
	if _dead: return
	if ScenePages.busy:
		_fall_velocity = minf(_fall_velocity + 1500 * delta,900)
		velocity = Vector2(0,_fall_velocity)
		move_and_slide()
		if is_on_floor(): _fall_velocity = 0
		return
	player = get_tree().get_first_node_in_group("player")
	_stagger_left = maxf(0, _stagger_left - delta)
	_fall_velocity = minf(_fall_velocity + 1500 * delta, 900)
	velocity = Vector2(knockback.x, _fall_velocity)
	if is_instance_valid(player) and not is_attacking and _stagger_left <= 0:
		var distance: Vector2 = player.ground_position() - ground_position()
		_face(distance.x)
		if absf(distance.x) < detection_radius:
			if absf(distance.x) <= attack_range and absf(distance.y) < 65 and can_attack:
				_attack()
			elif absf(distance.x) > attack_range:
				var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(_facing_sign * 55, -5), global_position + Vector2(_facing_sign * 55, 80), 1)
				var running: bool = run_distance > 0.0 and absf(distance.x) > run_distance
				if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
					velocity.x += _facing_sign * speed * (run_speed_multiplier if running else 1.0)
				_play_animation("run" if running else "walk")
			else: _play_animation("idle")
		else: _play_animation("idle")
	if boss_encounter:
		if _charging and is_attacking and visual.frame == 2: velocity.x = _charge_direction * (440 if _phase_two else 360)
		_warn.position = Vector2.ZERO
		_warn.set("direction", _charge_direction)
		_warn.queue_redraw()
		if not is_attacking or visual.frame == 3: _warn.hide()
		if not _phase_two and health.current_health <= health.max_health / 2:
			_phase_two = true
			get_parent().present_boss_phase()
			AudioLandscape.hush(.4, .6)
			AudioLandscape.cue(&"corruption", global_position)
	move_and_slide()
	if is_on_floor(): _fall_velocity = 0
	knockback = knockback.move_toward(Vector2.ZERO, 900 * delta)
func _on_hitbox_area_entered(area: Area2D) -> void:
	if ScenePages.busy: return
	super._on_hitbox_area_entered(area)
func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	super.take_damage(amount, from_position)
	knockback.y = 0
func _attack() -> void:
	if boss_encounter:
		super._attack()
		return
	if _dead or is_attacking: return
	_attack_generation += 1
	var generation: int = _attack_generation
	is_attacking = true
	can_attack = false
	_attack_targets.clear()
	_play_animation("attack")
	visual.pause()
	visual.frame = 0
	await get_tree().create_timer(.17, false).timeout
	if _dead or generation != _attack_generation: return
	visual.frame = 1
	AudioLandscape.cue(&"attack", global_position)
	await get_tree().create_timer(.17, false).timeout
	if _dead or generation != _attack_generation: return
	visual.frame = 2
	hitbox_shape.set_deferred("disabled", false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _dead or generation != _attack_generation: return
	for area in $Hitbox.get_overlapping_areas(): _on_hitbox_area_entered(area)
	await get_tree().create_timer(.18, false).timeout
	if _dead or generation != _attack_generation: return
	hitbox_shape.set_deferred("disabled", true)
	visual.frame = 3
	await get_tree().create_timer(.2, false).timeout
	if _dead or generation != _attack_generation: return
	is_attacking = false
	_play_animation("idle")
	await get_tree().create_timer(attack_cooldown, false).timeout
	if not _dead and generation == _attack_generation: can_attack = true
