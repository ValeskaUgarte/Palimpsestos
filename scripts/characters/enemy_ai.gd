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
var _attack_generation: int = 0

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
    _apply_frame_alignment()

func _apply_frame_alignment() -> void:
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
    visual.position.x = _ground_position.x + offset_x * visual.scale.x * _facing_sign

func ground_position() -> Vector2:
    return $CollisionShape2D.global_position + Vector2(0, 12)

func _physics_process(delta: float) -> void:
    if _dead:
        return
    velocity = knockback
    _stagger_left = maxf(0.0, _stagger_left - delta)
    if not is_attacking and _stagger_left <= 0.0:
        if is_instance_valid(player):
            var destination: Vector2 = player.ground_position()
            var displacement: Vector2 = destination - ground_position()
            if absf(displacement.x) > 2.0:
                _face(displacement.x)
            if displacement.length() > attack_range:
                var running: bool = run_distance > 0.0 and displacement.length() > run_distance
                velocity += displacement.normalized() * speed * (run_speed_multiplier if running else 1.0)
                _play_animation("run" if running else "walk")
            elif can_attack:
                _attack()
            else:
                _play_animation("idle")
        else:
            _play_animation("idle")
    move_and_slide()
    if is_instance_valid(_walkable_path):
        var foot: Vector2 = ground_position()
        global_position += _walkable_path.constrain_foot(foot, 26.0) - foot
    knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)

func _face(direction_x: float) -> void:
    _facing_sign = -1.0 if direction_x < 0.0 else 1.0
    visual.flip_h = (_facing_sign < 0.0) if faces_right_by_default else (_facing_sign > 0.0)
    $Hitbox.position.x = absf($Hitbox.position.x) * _facing_sign

func _attack() -> void:
    if _dead or is_attacking:
        return
    _attack_generation += 1
    var generation: int = _attack_generation
    is_attacking = true
    can_attack = false
    _attack_targets.clear()
    _play_animation("attack")
    # La pose de contacto permanece durante la ventana activa; no se adelanta
    # por un ciclo automático ni continúa golpeando durante la recuperación.
    visual.pause()
    visual.frame = 0
    await get_tree().create_timer(attack_windup * 0.5, false).timeout
    if _dead or generation != _attack_generation:
        return
    visual.frame = 1
    await get_tree().create_timer(attack_windup * 0.5, false).timeout
    if _dead or generation != _attack_generation:
        return
    visual.frame = 2
    AudioLandscape.cue(&"attack", ground_position())
    hitbox_shape.set_deferred("disabled", false)
    await get_tree().physics_frame
    await get_tree().physics_frame
    if _dead or generation != _attack_generation:
        return
    for area in $Hitbox.get_overlapping_areas():
        _on_hitbox_area_entered(area)
    await get_tree().create_timer(attack_active_time, false).timeout
    if _dead or generation != _attack_generation:
        return
    hitbox_shape.set_deferred("disabled", true)
    visual.frame = 3
    await get_tree().create_timer(0.20, false).timeout
    if _dead or generation != _attack_generation:
        return
    visual.speed_scale = 1.0
    is_attacking = false
    _play_animation("idle")
    await get_tree().create_timer(attack_cooldown, false).timeout
    if not _dead and generation == _attack_generation:
        can_attack = true

func _on_hitbox_area_entered(area: Area2D) -> void:
    if _dead or not is_attacking or hitbox_shape.disabled or area in _attack_targets:
        return
    if area.is_in_group("player_hurtbox") and area.has_method("take_damage"):
        _attack_targets.append(area)
        area.take_damage(attack_damage, ground_position())
        AudioLandscape.cue(&"impact_heavy" if attack_damage>=20 else &"impact",hitbox_shape.global_position)
        CombatFX.hit_impact(hitbox_shape.global_position, attack_damage / 15.0)

func receive_combat_hit(amount: int, from_position: Vector2, finisher: bool = false) -> void:
    take_damage(amount, from_position)
    if _dead:
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
        _play_animation("idle")
        get_tree().create_timer(0.28, false).timeout.connect(_recover_interrupt.bind(generation))
    elif not is_attacking:
        # Animación "hurt" (si ya tiene sprites; si no, idle) mientras dura el aturdimiento.
        _play_animation("hurt")

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
    if not _dead and body.is_in_group("player"):
        player = body

func _on_player_lost(body: Node2D) -> void:
    if body == player:
        player = null

func _on_died() -> void:
    if _dead:
        return
    _dead = true
    AudioLandscape.cue(&"death",ground_position())
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
    else:
        # Sin animación de muerte todavía: se queda quieto un momento y se desvanece.
        visual.pause()
    await get_tree().create_timer(0.35, false).timeout
    var fade := create_tween()
    fade.tween_property(visual, "modulate:a", 0.0, 0.4)
    await fade.finished
    queue_free()
