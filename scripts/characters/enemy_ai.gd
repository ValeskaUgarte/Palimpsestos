extends CharacterBody2D

@export var speed: float = 90.0
@export var attack_damage: int = 15
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.0
@export var detection_radius: float = 260.0
@export var faces_right_by_default: bool = true
@export var attack_windup: float = 0.34
@export var attack_active_time: float = 0.18
@export_range(0.0, 1.0) var impact_resistance: float = 0.0
## Si es mayor que 0: cuando el jugador está más lejos que esta distancia el enemigo CORRE (usa la animación "run").
## 0 = nunca corre (comportamiento clásico). Mientras la ranura "run" esté vacía se usa "walk".
@export var run_distance: float = 0.0
@export var run_speed_multiplier: float = 1.6
## Tamaño de ESTA instancia respecto al alto del personaje (character_height en su SpriteFrames). 1 = normal.
## Sirve para un enemigo más grande que los de su misma especie (p. ej. el lobo gigante).
@export var size_multiplier: float = 1.0
## Vida de ESTA instancia respecto a la de su escena (1 = igual). Ej. 2 para un lobo gigante.
@export var health_multiplier: float = 1.0
## --- Combate con más acción ---
## Probabilidad (0 a 1) de que un ataque sea FUERTE: se anuncia (destello y pausa más larga) y, si no lo bloqueas, te derriba.
@export_range(0.0, 1.0, 0.05) var heavy_attack_chance: float = 0.0
@export var heavy_attack_multiplier: float = 1.8
## Probabilidad (0 a 1) de cubrirse de un golpe cuando no está atacando: recibe solo block_damage_factor del daño.
@export_range(0.0, 1.0, 0.05) var block_chance: float = 0.0
@export_range(0.0, 1.0, 0.05) var block_damage_factor: float = 0.2
## Probabilidad (0 a 1) de caer al suelo al recibir el remate de un combo (cae, se queda un momento y se levanta).
@export_range(0.0, 1.0, 0.05) var knockdown_chance: float = 0.0
## true = no persigue ni ataca hasta que una escena lo despierte (engage). Para encuentros con diálogo antes de la pelea.
@export var dormant: bool = false

@onready var visual: AnimatedSprite2D = $Visual
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var health: Node = $HealthComponent
@onready var hurtbox: Area2D = $Hurtbox
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D

var player: Node2D = null
var is_attacking: bool = false
var can_attack: bool = true
var visual_base_scale_x: float = 1.0
var knockback: Vector2 = Vector2.ZERO
var _ground_scale: Vector2
var _ground_position: Vector2
var _dead: bool = false
var _attack_targets: Array[Area2D] = []
var _facing_sign: float = 1.0
var _flash_generation: int = 0
var _walkable_path: Node = null
var _stagger_left: float = 0.0
## Tiempo en que se mantiene la animación "hurt" tras un golpe (solo visual: no frena al enemigo).
var _hurt_hold: float = 0.0
const HURT_VISUAL_TIME := 0.34
var _attack_generation: int = 0
var _attack_is_heavy: bool = false
var _rushing: bool = false          # embestida al despertar (engage): corre hacia el jugador
var _guard_left: float = 0.0        # tiempo que mantiene la guardia tras bloquear
var _down_phase: int = 0            # 0 de pie · 1 cayendo · 2 en el suelo · 3 levantándose
var _down_timer: float = 0.0
var _down_frame: int = 0

func _ready() -> void:
	_walkable_path = get_parent().get_node_or_null("WalkablePath")
	_ground_scale = visual.scale
	_ground_position = visual.position
	add_to_group("enemy")
	visual.frame_changed.connect(_apply_frame_alignment)
	visual_base_scale_x = absf(visual.scale.x)
	hitbox_shape.disabled = true
	hurtbox.add_to_group("enemy_hurtbox")
	health.died.connect(_on_died)
	# Un enemigo más grande también pega desde más lejos (si no, su dibujo tapa al jugador antes de alcanzarlo).
	attack_range *= size_multiplier
	detection_radius *= size_multiplier
	if not is_equal_approx(health_multiplier, 1.0):
		health.max_health = maxi(1, int(round(health.max_health * health_multiplier)))
		health.current_health = health.max_health
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	$DetectionArea.body_entered.connect(_on_player_detected)
	$DetectionArea.body_exited.connect(_on_player_lost)
	detection_shape.shape = detection_shape.shape.duplicate()
	if detection_shape.shape is CircleShape2D:
		detection_shape.shape.radius = detection_radius

func _play_animation(animation: StringName) -> void:
	# Ranura sin sprites todavía (0 frames): usa la de respaldo (run -> walk -> idle, hurt -> idle...).
	animation = SpriteFit.resolve_clip(visual.sprite_frames, animation)
	if animation == &"":
		return
	visual.scale = _ground_scale
	visual.position = _ground_position
	var art_scale: float = float(visual.sprite_frames.get_meta(String(animation) + "_art_scale", 1.0))
	visual.scale *= art_scale
	# Todas las poses comparten el mismo punto de apoyo, también ataque y muerte.
	visual.position.y = $CollisionShape2D.position.y + 12.0 - 200.0 * visual.scale.y
	visual.play(animation)
	_apply_flip()
	_apply_frame_alignment()

# Espejo del sprite según hacia dónde mira. Un clip dibujado al revés que el resto (por ejemplo la muerte del Wolf1)
# se marca en su SpriteFrames con el metadato "flip_<clip>" = true y se invierte solo.
func _apply_flip() -> void:
	var base_flip: bool = (_facing_sign < 0.0) if faces_right_by_default else (_facing_sign > 0.0)
	var clip_flip: bool = bool(visual.sprite_frames.get_meta("flip_" + String(visual.animation), false))
	visual.flip_h = base_flip != clip_flip

func _apply_frame_alignment() -> void:
	# Tamaño parejo editable en el propio SpriteFrames (CharacterFrames: character_height / animation_scale).
	var hf: Dictionary = SpriteFit.height_fit(visual.sprite_frames, visual.animation, visual.frame)
	if not hf.is_empty():
		var hscale: float = float(hf["scale"]) * size_multiplier
		var hside: float = -1.0 if visual.flip_h else 1.0
		var shift: Vector2 = hf["shift"]
		visual.scale = Vector2.ONE * hscale
		visual.position.y = $CollisionShape2D.position.y + 12.0 - float(hf["baseline"]) * hscale + shift.y
		visual.position.x = _ground_position.x + (float(hf["offset_x"]) * hscale + shift.x) * hside
		return
	var texture: Texture2D = visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	var art_scale: float = float(visual.sprite_frames.get_meta(String(visual.animation) + "_art_scale", 1.0))
	var baseline: float = 200.0
	var offset_x: float = 0.0
	if texture != null and texture.has_meta("pose_art_scale"):
		art_scale = float(texture.get_meta("pose_art_scale"))
		baseline = float(texture.get_meta("pose_art_baseline", 200.0))
		offset_x = float(texture.get_meta("pose_art_offset_x", 0.0))
	elif texture != null and visual.sprite_frames.has_animation("idle"):
		# Frame sin medidas guardadas (agregado a mano): se mide solo y queda con la altura del idle.
		var measured: Dictionary = SpriteFit.metrics(texture)
		var first: Dictionary = SpriteFit.metrics(visual.sprite_frames.get_frame_texture(visual.animation, 0))
		var idle: Dictionary = SpriteFit.metrics(visual.sprite_frames.get_frame_texture("idle", 0))
		if not measured.is_empty() and not first.is_empty() and not idle.is_empty():
			var first_height: float = float(int(first["bottom"]) - int(first["top"]))
			if first_height > 0.0:
				art_scale = float(int(idle["bottom"]) - int(idle["top"])) / first_height
				baseline = float(measured["bottom"]) - float(measured["h"]) * 0.5
				offset_x = -(float(first["cx"]) - float(first["w"]) * 0.5)
	visual.scale = _ground_scale * art_scale
	visual.position.y = $CollisionShape2D.position.y + 12.0 - baseline * visual.scale.y
	# El lado sale del flip real del sprite (no de _facing_sign): con faces_right_by_default=false ambos difieren.
	visual.position.x = _ground_position.x + offset_x * visual.scale.x * (-1.0 if visual.flip_h else 1.0)

func ground_position() -> Vector2:
	return $CollisionShape2D.global_position + Vector2(0, 12)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	velocity = knockback
	_stagger_left = maxf(0.0, _stagger_left - delta)
	_hurt_hold = maxf(0.0, _hurt_hold - delta)
	if _down_phase > 0:
		_update_down(delta)
		move_and_slide()
		_stick_to_path()
		knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
		return
	if _guard_left > 0.0:
		_guard_left -= delta
		if _guard_left <= 0.0 and not is_attacking:
			_play_locomotion("idle")
	if dormant:
		_play_locomotion("idle")
		move_and_slide()
		_stick_to_path()
		knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		return
	if not is_attacking and _stagger_left <= 0.0 and _guard_left <= 0.0:
		if is_instance_valid(player):
			var destination: Vector2 = player.ground_position()
			var displacement: Vector2 = destination - ground_position()
			if absf(displacement.x) > 2.0:
				_face(displacement.x)
			if displacement.length() <= attack_range:
				_rushing = false
			if displacement.length() > attack_range:
				var running: bool = _rushing or (run_distance > 0.0 and displacement.length() > run_distance)
				velocity += displacement.normalized() * speed * (run_speed_multiplier if running else 1.0)
				_play_locomotion("run" if running else "walk")
			elif can_attack:
				_attack()
			else:
				_play_locomotion("idle")
		else:
			_play_locomotion("idle")
	move_and_slide()
	_stick_to_path()
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)

func _stick_to_path() -> void:
	if is_instance_valid(_walkable_path):
		var foot: Vector2 = ground_position()
		global_position += _walkable_path.constrain_foot(foot, 26.0) - foot

## Despierta al enemigo y lo lanza corriendo hacia el objetivo (después del grito de un encuentro).
func engage(target: Node2D) -> void:
	if _dead:
		return
	dormant = false
	player = target
	_rushing = true

## Animación de grito/provocación (usa "taunt"; si no tiene, idle) con un pequeño sacudón del dibujo.
func taunt() -> void:
	if _dead:
		return
	_play_animation(&"taunt")
	AudioLandscape.cue(&"impact_heavy", ground_position())
	var base_x: float = visual.position.x
	var t := create_tween()
	for i in 6:
		t.tween_property(visual, "position:x", base_x + (7.0 if i % 2 == 0 else -7.0), 0.05)
	t.tween_property(visual, "position:x", base_x, 0.05)

# Animación de movimiento/reposo; no pisa el "hurt" mientras dura su reproducción.
func _play_locomotion(animation: StringName) -> void:
	if _hurt_hold > 0.0:
		return
	visual.speed_scale = 1.0
	_play_animation(animation)

# Reacción al golpe: la animación "hurt" se acelera para caber en HURT_VISUAL_TIME y se lee como un impacto seco.
func _play_hurt() -> void:
	var clip: StringName = SpriteFit.resolve_clip(visual.sprite_frames, &"hurt")
	if clip == &"":
		return
	_hurt_hold = HURT_VISUAL_TIME if clip == &"hurt" else 0.0
	_play_animation(&"hurt")
	if clip == &"hurt":
		var frames: SpriteFrames = visual.sprite_frames
		var natural: float = float(frames.get_frame_count(clip)) / maxf(frames.get_animation_speed(clip), 0.01)
		visual.speed_scale = clampf(natural / HURT_VISUAL_TIME, 1.0, 4.0)

func _face(direction_x: float) -> void:
	_facing_sign = -1.0 if direction_x < 0.0 else 1.0
	_apply_flip()
	$Hitbox.position.x = absf($Hitbox.position.x) * _facing_sign

func _attack() -> void:
	if _dead or is_attacking:
		return
	_attack_generation += 1
	var generation: int = _attack_generation
	is_attacking = true
	can_attack = false
	_attack_targets.clear()
	if not _attack_is_heavy:
		_attack_is_heavy = heavy_attack_chance > 0.0 and randf() < heavy_attack_chance
	var windup: float = attack_windup * (1.9 if _attack_is_heavy else 1.0)
	_play_animation("attack")
	# La pose de contacto permanece durante la ventana activa; no se adelanta
	# por un ciclo automático ni continúa golpeando durante la recuperación.
	visual.pause()
	visual.frame = 0
	if _attack_is_heavy:
		# Aviso del golpe fuerte: destello amarillo. Es el momento de bloquear (L / RT) o apartarse.
		visual.modulate = Color(1.0, 0.85, 0.35) if GamePreferences.flashes else Color.WHITE
		AudioLandscape.cue(&"swing", ground_position())
	await get_tree().create_timer(windup * 0.5, false).timeout
	if _dead or generation != _attack_generation or not is_inside_tree():
		return
	visual.frame = 1
	await get_tree().create_timer(windup * 0.5, false).timeout
	if _dead or generation != _attack_generation or not is_inside_tree():
		return
	visual.frame = 2
	if _attack_is_heavy:
		visual.modulate = Color.WHITE
	AudioLandscape.cue(&"attack", ground_position())
	hitbox_shape.set_deferred("disabled", false)
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if _dead or generation != _attack_generation or not is_inside_tree():
		return
	for area in $Hitbox.get_overlapping_areas():
		_on_hitbox_area_entered(area)
	await get_tree().create_timer(attack_active_time, false).timeout
	if _dead or generation != _attack_generation or not is_inside_tree():
		return
	hitbox_shape.set_deferred("disabled", true)
	visual.frame = 3
	await get_tree().create_timer(0.20, false).timeout
	if _dead or generation != _attack_generation or not is_inside_tree():
		return
	visual.speed_scale = 1.0
	is_attacking = false
	_attack_is_heavy = false
	_play_animation("idle")
	await get_tree().create_timer(attack_cooldown, false).timeout
	if not _dead and generation == _attack_generation and is_inside_tree():
		can_attack = true

func _on_hitbox_area_entered(area: Area2D) -> void:
	if _dead or not is_attacking or hitbox_shape.disabled or area in _attack_targets:
		return
	if area.is_in_group("player_hurtbox") and area.has_method("take_damage"):
		_attack_targets.append(area)
		var damage: int = int(round(attack_damage * (heavy_attack_multiplier if _attack_is_heavy else 1.0)))
		area.take_damage(damage, ground_position(), _attack_is_heavy)
		AudioLandscape.cue(&"impact_heavy" if damage>=20 else &"impact",hitbox_shape.global_position)
		CombatFX.hit_impact(hitbox_shape.global_position, damage / 15.0)

func receive_combat_hit(amount: int, from_position: Vector2, finisher: bool = false) -> void:
	if _down_phase > 0:
		# En el suelo los golpes pasan muy debilitados (no se le puede rematar sin fin).
		take_damage(maxi(1, amount / 4), from_position)
		return
	dormant = false
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	# Se cubre: cuando no está atacando puede bloquear el golpe y contraatacar enseguida.
	if not is_attacking and block_chance > 0.0 and randf() < block_chance:
		_block_hit(amount, from_position)
		return
	take_damage(amount, from_position)
	if _dead:
		return
	if finisher and knockdown_chance > 0.0 and randf() < knockdown_chance:
		_begin_down(from_position)
		return
	var response: float = 1.0 - impact_resistance
	_stagger_left = maxf(_stagger_left, (0.22 if finisher else 0.09) * response)
	if from_position != Vector2.INF:
		var direction: float = signf(ground_position().x - from_position.x)
		if is_zero_approx(direction):
			direction = -_facing_sign
		knockback = Vector2(direction * (320.0 if finisher else 190.0) * response, 0)
	if finisher and impact_resistance < 0.75 and is_attacking:
		# El token invalida TODOS los awaits del ataque anterior.
		_attack_generation += 1
		var generation: int = _attack_generation
		is_attacking = false
		can_attack = false
		hitbox_shape.set_deferred("disabled", true)
		visual.speed_scale = 1.0
		_play_hurt()
		if _hurt_hold <= 0.0:
			_play_animation("idle")
		get_tree().create_timer(0.28, false).timeout.connect(_recover_interrupt.bind(generation))
	elif not is_attacking:
		# Animación "hurt" (si ya tiene sprites; si no, idle) mientras dura el aturdimiento.
		_play_hurt()
		if _hurt_hold <= 0.0:
			_play_animation("hurt")

func _block_hit(amount: int, from_position: Vector2) -> void:
	if from_position != Vector2.INF:
		_face(from_position.x - ground_position().x)
	health.take_damage(maxi(1, int(round(amount * block_damage_factor))))
	if _dead:
		return
	_guard_left = 0.35
	_play_animation(&"block")
	AudioLandscape.cue(&"impact", ground_position())
	CombatFX.hit_impact(ground_position() + Vector2(_facing_sign * 60.0, -170.0), 0.6)
	if from_position != Vector2.INF:
		knockback = Vector2(signf(ground_position().x - from_position.x) * 110.0, 0.0)
	# Destello blanco: se lee como "lo paró".
	visual.modulate = Color(1.6, 1.6, 1.6) if GamePreferences.flashes else Color.WHITE
	get_tree().create_timer(0.1, false).timeout.connect(_clear_flash)
	can_attack = true

func _clear_flash() -> void:
	if not _dead:
		visual.modulate = Color.WHITE

# Caída: animación "death" hasta knockdown_frame (o la mitad), un momento en el suelo y se levanta (cuadros al revés).
func _begin_down(from_position: Vector2) -> void:
	if not SpriteFit.has_clip(visual.sprite_frames, &"death"):
		return
	_attack_generation += 1
	is_attacking = false
	_attack_is_heavy = false
	hitbox_shape.set_deferred("disabled", true)
	visual.modulate = Color.WHITE
	var count: int = visual.sprite_frames.get_frame_count(&"death")
	var target: int = count / 2
	if visual.sprite_frames is CharacterFrames and (visual.sprite_frames as CharacterFrames).knockdown_frame >= 0:
		target = (visual.sprite_frames as CharacterFrames).knockdown_frame
	_down_frame = clampi(target, 1, count - 1)
	_down_phase = 1
	_hurt_hold = 0.0
	if from_position != Vector2.INF:
		knockback = Vector2(signf(ground_position().x - from_position.x) * 340.0, 0.0)
	_play_animation(&"death")
	visual.speed_scale = 1.6
	CombatFX.hit_impact(ground_position() + Vector2(0, -120), 1.4)

func _update_down(delta: float) -> void:
	match _down_phase:
		1:
			if visual.frame >= _down_frame or not visual.is_playing():
				visual.pause()
				_down_phase = 2
				_down_timer = 0.9
		2:
			_down_timer -= delta
			if _down_timer <= 0.0:
				_down_phase = 3
				visual.speed_scale = 1.8
				visual.play_backwards(&"death")
		3:
			if visual.frame <= 0 or not visual.is_playing():
				_down_phase = 0
				visual.speed_scale = 1.0
				can_attack = true
				_play_animation(&"idle")

func _recover_interrupt(generation: int) -> void:
	if not _dead and generation == _attack_generation:
		can_attack = true

func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	if _dead:
		return
	health.take_damage(amount)
	if _dead:
		return
	_flash_generation += 1
	var flash: int = _flash_generation
	visual.modulate = Color(1, 0.45, 0.38) if GamePreferences.flashes else Color.WHITE
	if from_position != Vector2.INF:
		knockback = (ground_position() - from_position).normalized() * 220.0
	await get_tree().create_timer(0.12, false).timeout
	if not _dead and flash == _flash_generation:
		visual.modulate = Color.WHITE

func _on_player_detected(body: Node2D) -> void:
	if not _dead and not dormant and body.is_in_group("player"):
		player = body

func _on_player_lost(body: Node2D) -> void:
	if body == player:
		player = null

func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_down_phase = 0
	AudioLandscape.cue(&"death",ground_position())
	CombatFX.death_burst(ground_position() + Vector2(0, -50), 1.0)
	is_attacking = false
	remove_from_group("enemy")
	set_physics_process(false)
	hitbox_shape.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	$CollisionShape2D.set_deferred("disabled", true)
	visual.speed_scale = 1.0
	visual.modulate = Color.WHITE
	var has_death: bool = SpriteFit.has_clip(visual.sprite_frames, &"death")
	_play_animation("death")
	if has_death:
		await visual.animation_finished
	if not is_inside_tree():
		return
	else:
		# Sin animación de muerte todavía: se queda quieto un momento y se desvanece.
		visual.pause()
	await get_tree().create_timer(0.35, false).timeout
	var fade := create_tween()
	fade.tween_property(visual, "modulate:a", 0.0, 0.4)
	await fade.finished
	queue_free()
