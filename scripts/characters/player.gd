extends CharacterBody2D

@export var speed: float = 160.0
@export var movement_acceleration: float = 1800.0
@export var movement_braking: float = 2400.0
var _locomotion: Vector2 = Vector2.ZERO
var _dead: bool = false
@export var punch_damage: int = 10
@export var kick_damage: int = 20          # la patada pega más fuerte
@export var combo_window: float = 0.6      # segundos que hay para encadenar el siguiente golpe
@export var combo_damage_bonus: int = 8    # daño extra en el 3er golpe del combo (el "finisher")
@export var jump_impulse: float = 500.0
@export var jump_gravity: float = 1500.0
@export var jump_art_scale: float = 1.0
@export var jump_art_baseline: float = 0.0
## Velocidad de caída (px/s) a la que el salto llega al último fotograma de su clip. Igual que en el demo lateral (fall_speed_limit).
const JUMP_FALL_FRAME_SPEED: float = 900.0

# Modo compañero (ej: Jhon peleando junto a Elliot, según el guion)
# Activa esto en el Inspector de la instancia (NO en la escena base) para que
# este personaje deje de leer el teclado y en vez de eso siga a otro personaje
# y ataque solo a los enemigos cercanos. Así reutilizamos el mismo player.gd
# para un aliado controlado por IA sin duplicar todo el sistema de combate.
@export var is_companion: bool = false
@export var follow_target_path: NodePath      # normalmente el nodo "Elliot" del nivel
@export var companion_follow_offset: Vector2 = Vector2(-160, 30)
@export var companion_attack_range: float = 70.0
## Hasta qué distancia (en px) el compañero "ve" a un enemigo. Más lejos que esto no avanza solo.
@export var companion_detect_range: float = 520.0
## Si el personaje que juegas se aleja más que esto, el compañero se acerca aunque estés quieto.
@export var companion_leash: float = 700.0
## Separación extra (px) entre un compañero y el siguiente, para que no se amontonen.
@export var companion_spacing: float = 90.0
## Distancia mínima (px) al personaje que juegas: más cerca que esto se aparta aunque estés quieto.
@export var companion_min_distance: float = 110.0
## Distancia máxima cómoda (px): más lejos que esto se apura (camina más rápido) para alcanzarte.
@export var companion_max_distance: float = 420.0
## Qué tan rápido va cuando se apura (multiplica su velocidad).
@export var companion_hurry_multiplier: float = 1.35
## Distancia (px) antes de un obstáculo a la que el compañero salta.
@export var companion_jump_gap: float = 55.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var health: Node = $HealthComponent
@onready var hurtbox: Area2D = $Hurtbox

## Control aéreo del salto (1 = igual que en el suelo). Igual que el modo demo, el personaje responde más lento en el aire.
@export_range(0.2, 1.0, 0.05) var story_air_control: float = 0.75
## Tiempo (s) que se recuerda un salto pulsado un instante antes de poder ejecutarlo (durante un golpe o al caer).
@export var jump_buffer_time: float = 0.12
## Al soltar el botón en la subida, la velocidad vertical se multiplica por esto (salto corto / salto largo).
@export_range(0.1, 1.0, 0.05) var jump_cut_factor: float = 0.5
var _jump_buffer: float = 0.0
var _jump_cut_done: bool = false
var _jump_cut_armed: bool = false  # true solo cuando el salto lo inició el jugador con el botón (no por código ni IA)
var is_attacking: bool = false
var facing: Vector2 = Vector2.RIGHT
var knockback: Vector2 = Vector2.ZERO
var _companion_attack_cooldown: float = 0.0
var _follow_side: float = -1.0  # lado en que se coloca detrás del líder (se actualiza cuando el líder camina)
var _leader_last_pos: Vector2 = Vector2.INF  # posición del líder en el cuadro anterior (para saber si camina)
var _leader_speed: float = 0.0               # velocidad REAL del líder (px/s), medida por su cambio de posición
var _ai_target_id: int = 0                   # enemigo que está atacando ahora
var _ai_target_hp: int = -1                  # su vida en el último golpe (para saber si el golpe sirvió)
var _ai_idle_swings: int = 0                 # golpes seguidos que no le quitaron vida
var _ai_ignore: Dictionary = {}              # enemigos que ignora un rato (id -> ms): no los alcanza
var _hurt_presentation_time: float = 0.0
var _damage_flash_id: int = 0
var jump_height: float = 0.0
var _render_pass: bool = false   # true solo dentro de _process: ahí la altura del salto se suaviza entre ticks de física
## Alto (en pantalla) de la figura de pie. Se usa para ajustar solo los frames sin medidas guardadas.
@export var standing_height: float = 310.0
## Escala fija de CADA animación (todas miden lo mismo en pantalla). Se edita en el Inspector.
## Si una animación no está aquí, usa la de "idle".
@export var clip_scale: Dictionary = {}
var _interaction_time: float = 0.0
var _swing_presented: bool = false
var _await_action_release: bool = false
var is_jumping: bool = false
var _hit_targets: Array[Area2D] = []
var _hit_actor_ids: Dictionary = {}
var _contact_active: bool = false
var _attack_progress: float = 0.0
var _attack_clip: StringName = &""
var _attack_duration: float = 0.5
var _fallback_elapsed: float = 0.0
const COMPANION_KICK_MAX_TIME: float = 0.5
var _fallback_attack: bool = false
var _damage_recoil: float = 0.0
var attack_phase: StringName = &"recovery"
const ATTACK_PROFILE = preload("res://scripts/characters/attack_profile.gd")
@export var attack_1_profile: Resource = preload("res://resources/combat/attack_1.tres")
@export var attack_2_profile: Resource = preload("res://resources/combat/attack_2.tres")
@export var finisher_profile: Resource = preload("res://resources/combat/finisher.tres")
@export var kick_profile: Resource = preload("res://resources/combat/kick.tres")
var _attack_profile: Resource
var _jump_velocity: float = 0.0
var _jump_elapsed: float = 0.0
var _visual_ground_position: Vector2
var _hurtbox_ground_position: Vector2
var _visual_ground_scale: Vector2
var _jump_anchor_y: float = 0.0

# --- Sistema de combo ---
# combo_step cuenta acciones encadenadas (1, 2, 3); se conserva el comportamiento incluso al fallar.
# Si combo_step llega a 3, el golpe se marca como "finisher" (bonus de daño) y se reinicia.
var combo_step: int = 0
var combo_timer: float = 0.0
var buffered_action: String = ""   # "attack" o "kick" que el jugador pulsó DURANTE la animación actual
var active_hit_finisher: bool = false
var active_hit_action: StringName = &"attack"
var active_hit_damage: int = 0     # daño del golpe que está activo ahora mismo en el hitbox


func _ready() -> void:
	_visual_ground_position = anim.position
	_visual_ground_scale = anim.scale
	_hurtbox_ground_position = hurtbox.position
	if is_companion:
		add_to_group("companion")
		add_to_group("party_actor")
	else:
		add_to_group("player")
		$Camera2D.make_current()  # solo el personaje que controla el jugador debe tomar la cámara
	health.died.connect(_on_died)
	hitbox_shape.disabled = true  # el hitbox arranca APAGADO
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hurtbox.add_to_group("player_hurtbox")
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_attack_pose)
	anim.frame_changed.connect(_fit_pose)
	if anim.sprite_frames.get_meta("aligned_companion", false):
		_play_ground_animation("idle")


func _physics_process(delta: float) -> void:
	if _dead:return
	_damage_recoil = move_toward(_damage_recoil, 0.0, delta * 0.8)
	anim.rotation = _damage_recoil
	if _await_action_release and not (Input.is_action_pressed("jump") or Input.is_action_pressed("attack") or Input.is_action_pressed("kick")):
		_await_action_release=false
	# Salto con buffer: el botón pulsado un instante antes (en pleno golpe o aturdimiento) no se pierde.
	if not is_companion and Input.is_action_just_pressed("jump") and not _await_action_release:
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_update_jump(delta)
	if _interaction_time>0 and not is_jumping and not is_attacking:
		_interaction_time=maxf(0,_interaction_time-delta)
		if not Input.is_action_just_pressed("attack") and not Input.is_action_just_pressed("kick"):
			velocity=knockback
			_move_on_path()
			knockback=knockback.move_toward(Vector2.ZERO,900*delta)
			return
		_interaction_time=0
	if _hurt_presentation_time > 0.0:
		_hurt_presentation_time = maxf(0.0, _hurt_presentation_time - delta)
		velocity = knockback
		_move_on_path()
		knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		if _hurt_presentation_time == 0.0:
			_play_ground_animation("idle")
		return
	# Ventana de combo: si se acaba el tiempo sin encadenar, se reinicia el contador.
	if combo_timer > 0.0 and not is_attacking:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0

	if is_attacking:
		if _fallback_attack:
			_fallback_elapsed += delta
			_attack_progress = minf(_fallback_elapsed / _attack_duration, 1.0)
		else:
			_attack_progress = _attack_profile.clip_progress(anim)
		_refresh_attack_contact()
		var advance: float = 0.0
		if not is_companion and _attack_progress >= 0.15 and _attack_progress < _attack_profile.contact_end:
			advance = _attack_profile.advance_pixels / maxf(_attack_duration * (_attack_profile.contact_end - 0.15), 0.01)
		velocity = knockback + Vector2(facing.x * advance, 0)
		_move_on_path()
		if _contact_active:
			for area in hitbox.get_overlapping_areas():
				_on_hitbox_area_entered(area)
		if _fallback_attack and _attack_progress >= 1.0:
			_end_attack()
			return
		knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		# NOTA IMPORTANTE: antes acá se hacía "return" sin leer más inputs.
		# Eso era lo que impedía los combos: cualquier tecla pulsada mientras
		# Elliot seguía en animación de golpe se perdía. Ahora la guardamos
		# en "buffered_action" y se dispara automáticamente en _end_attack().
		if not is_companion:
			if Input.is_action_just_pressed("attack") and not _await_action_release:
				buffered_action = "attack"
			elif Input.is_action_just_pressed("kick") and not _await_action_release:
				buffered_action = "kick"
		return

	if is_companion:
		_companion_ai_step(delta)
		return
	# Con is_jumping el buffer se conserva: al aterrizar el salto pulsado en el aire se ejecuta.
	if _jump_buffer > 0.0 and not _await_action_release and not is_jumping:
		_jump_buffer = 0.0
		# El corte de altura solo aplica si el botón sigue pulsado (un salto con el botón ya suelto sale completo).
		_jump_cut_armed = Input.is_action_pressed("jump")
		_begin_jump()
		_jump_cut_armed = false

	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0  # movimiento en línea recta: solo adelante/atrás (sin subir ni bajar)
	).limit_length(1.0)

	var response: float = movement_braking if input_vector == Vector2.ZERO else movement_acceleration
	if _locomotion.dot(input_vector) < 0.0:
		response = movement_braking
	# El control aéreo se aplica al final: también al invertir la dirección en el aire.
	if is_jumping:
		response *= story_air_control
	_locomotion = _locomotion.move_toward(input_vector * speed * PlayerStatus.speed_multiplier(self), response * delta)
	velocity = _locomotion + knockback
	_move_on_path()
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)

	if _locomotion.length() > 8.0:
		if absf(input_vector.x)>0.1:
			facing = Vector2.LEFT if input_vector.x<0 else Vector2.RIGHT
		if not is_jumping:
			_play_ground_animation("walk")
		if absf(facing.x) > 0.1:
			anim.flip_h = facing.x < 0
	else:
		if not is_jumping:
			_play_ground_animation("idle")
	if is_jumping:
		return

	if Input.is_action_just_pressed("attack") and not _await_action_release:
		_do_hit("attack")
	elif Input.is_action_just_pressed("kick") and not _await_action_release:
		_do_hit("kick")


func _play_ground_animation(animation: StringName) -> void:
	# Ranura todavía sin sprites (0 frames): se usa la de respaldo (run -> walk -> idle, hurt -> idle...).
	# Así puedes ir agregando animaciones nuevas en el editor sin que el personaje desaparezca.
	animation = SpriteFit.resolve_clip(anim.sprite_frames, animation)
	if animation == &"":
		return
	if animation == &"interact" and anim.sprite_frames.has_meta("interact_art_scale"):
		anim.scale=_visual_ground_scale*float(anim.sprite_frames.get_meta("interact_art_scale"))
		anim.position=_visual_ground_position
		anim.position.y=$CollisionShape2D.position.y+12-float(anim.sprite_frames.get_meta("interact_art_baseline"))*anim.scale.y
	elif anim.sprite_frames.get_meta("aligned_companion", false):
		var ratio: float = anim.sprite_frames.get_meta(String(animation) + "_art_scale", 1.0)
		anim.scale = _visual_ground_scale * ratio
		anim.position = _visual_ground_position
		anim.position.y = $CollisionShape2D.position.y + 12.0 - 200.0 * anim.scale.y
	elif animation == &"walk" and anim.sprite_frames.has_meta("walk_art_scale"):
		var ratio: float = anim.sprite_frames.get_meta("walk_art_scale", 1.0)
		var baseline: float = anim.sprite_frames.get_meta("walk_art_baseline", 158.0)
		anim.scale = _visual_ground_scale * ratio
		anim.position = _visual_ground_position
		anim.position.y = $CollisionShape2D.position.y + 12.0 - baseline * anim.scale.y
	else:
		anim.scale = _visual_ground_scale
		anim.position = _visual_ground_position
	anim.speed_scale = clampf(velocity.length() / maxf(speed,1.0),0.55,1.15) if animation == &"walk" else 1.0
	if animation == &"hurt" and _hurt_presentation_time > 0.0:
		# La reacción al golpe se acelera para caber en el tiempo de aturdimiento (se lee como impacto seco).
		var natural: float = float(anim.sprite_frames.get_frame_count(animation)) / maxf(anim.sprite_frames.get_animation_speed(animation), 0.01)
		anim.speed_scale = clampf(natural / _hurt_presentation_time, 1.0, 4.0)
	anim.play(animation)
	_apply_companion_pose()
	_fit_pose()


func _apply_companion_pose() -> void:
	if not anim.sprite_frames.get_meta("aligned_companion", false):
		return
	var texture: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if texture != null and texture.has_meta("pose_art_scale"):
		anim.scale = _visual_ground_scale * float(texture.get_meta("pose_art_scale"))
	else:
		anim.scale = _visual_ground_scale * float(anim.sprite_frames.get_meta(String(anim.animation) + "_art_scale", 1.0))
	anim.position.y = $CollisionShape2D.position.y + 12.0 - 200.0 * anim.scale.y
	if texture != null and texture.has_meta("clip_right_below") and anim.material == null:
		var mask := ShaderMaterial.new()
		mask.shader = load("res://assets/shaders/companion_atlas_mask.gdshader")
		anim.material = mask
	if anim.material is ShaderMaterial:
		anim.material.set_shader_parameter("clip_right_below", texture.get_meta("clip_right_below", Vector2(2,2)))
		anim.material.set_shader_parameter("clip_left_above", texture.get_meta("clip_left_above", Vector2(-1,-1)))


func _move_on_path() -> void:
	move_and_slide()
	var path := get_parent().get_node_or_null("WalkablePath")
	if path != null:
		var foot: Vector2 = ground_position()
		var constrained: Vector2 = path.constrain_foot(foot, 26.0)
		global_position += constrained - foot
		if not is_equal_approx(constrained.y, foot.y):
			knockback.y = 0.0


func _process(_delta: float) -> void:
	_render_pass = true
	_fit_pose()
	_render_pass = false


# Ajusta tamaño, pies y centrado de CADA frame (metadatos fit_* de los spritesheets),
# para que todos los movimientos mantengan la misma altura de personaje y apoyen en el mismo punto.
# Altura (en coordenadas locales) donde apoyan los pies; el modo lateral la sobrescribe.
func _foot_line() -> float:
	return ($CollisionShape2D as CollisionShape2D).position.y + 12.0


func _fit_pose() -> void:
	if not is_instance_valid(anim) or anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
		return
	var texture: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if texture == null:
		return
	var fit_scale: float = 1.0
	var fit_baseline: float = 0.0
	var fit_offset_x: float = 0.0
	if texture.has_meta("fit_scale"):
		fit_scale = float(texture.get_meta("fit_scale"))
		fit_baseline = float(texture.get_meta("fit_baseline", 0.0))
		fit_offset_x = float(texture.get_meta("fit_offset_x", 0.0))
	else:
		# Frame sin medidas guardadas (agregado a mano): se mide solo. La figura del primer frame de la
		# animación queda con la altura 'standing_height' y los pies apoyan en el suelo.
		var measured: Dictionary = SpriteFit.metrics(texture)
		var first: Dictionary = SpriteFit.metrics(anim.sprite_frames.get_frame_texture(anim.animation, 0))
		if measured.is_empty() or first.is_empty() or int(first["bottom"]) - int(first["top"]) <= 0:
			return
		fit_scale = standing_height / float(int(first["bottom"]) - int(first["top"]))
		fit_baseline = float(measured["bottom"]) - float(measured["h"]) * 0.5
		fit_offset_x = -(float(first["cx"]) - float(first["w"]) * 0.5)
	var side: float = -1.0 if anim.flip_h else 1.0
	# Tamaño fijo por animación (Inspector: clip_scale). Mismo alto en caminar, golpear, patear y saltar.
	var key: String = String(anim.animation)
	if clip_scale.has(key):
		fit_scale = float(clip_scale[key])
	elif clip_scale.has("idle"):
		fit_scale = float(clip_scale["idle"])
	# El salto cambia de altura dentro del propio clip (la figura se estira al subir).
	# Cada fotograma se escala para medir siempre 'standing_height', igual que el resto de movimientos.
	if key == "jump":
		# Escala constante del salto = la del reposo. La figura se agacha y se estira dentro del salto,
		# pero no cambia de tamaño. Solo el punto de apoyo (pies) sigue al fotograma.
		fit_scale = float(clip_scale.get("idle", fit_scale))
		var frame_metrics: Dictionary = SpriteFit.metrics(texture)
		if not frame_metrics.is_empty():
			fit_baseline = float(frame_metrics["bottom"]) - float(frame_metrics["h"]) * 0.5
	anim.scale = Vector2.ONE * fit_scale
	anim.position.x = _visual_ground_position.x + fit_offset_x * fit_scale * side
	var foot_y: float = _foot_line() - fit_baseline * fit_scale
	anim.position.y = foot_y - _visual_jump_height()


# Altura del salto para DIBUJAR. La física avanza a 60 ticks/s, pero la pantalla puede dibujar a 120/144 Hz:
# entre dos ticks se estima la altura con la misma parábola, así el sprite sube y baja sin escalones.
# Solo se usa en _process (_render_pass); la lógica (obstáculos, hurtbox) sigue leyendo jump_height tal cual.
func _visual_jump_height() -> float:
	if not is_jumping:
		return 0.0
	if not _render_pass or jump_height <= 0.0:
		return jump_height
	var ahead: float = Engine.time_scale / float(maxi(Engine.physics_ticks_per_second, 1)) * Engine.get_physics_interpolation_fraction()
	return maxf(jump_height + _jump_velocity * ahead - 0.5 * jump_gravity * ahead * ahead, 0.0)


func _begin_jump() -> void:
	if is_jumping or is_attacking or health.current_health <= 0:
		return
	is_jumping = true
	_jump_velocity = jump_impulse
	_jump_elapsed = 0.0
	_jump_cut_done = not _jump_cut_armed
	if SpriteFit.has_clip(anim.sprite_frames, "jump"):
		anim.scale = _visual_ground_scale * jump_art_scale
		var ground_shape := $CollisionShape2D as CollisionShape2D
		_jump_anchor_y = ground_shape.position.y + 12.0 - jump_art_baseline * anim.scale.y
		anim.position.y = _jump_anchor_y
		anim.play("jump")
		anim.pause()
		anim.frame = 0
		_fit_pose()


func _update_jump(delta: float) -> void:
	if not is_jumping:
		return
	_jump_elapsed += delta
	# Altura variable: soltar el botón durante la subida acorta el salto (el modo demo ya lo hacía).
	if not is_companion and not _jump_cut_done and _jump_velocity > 0.0 and not Input.is_action_pressed("jump"):
		_jump_velocity *= jump_cut_factor
		_jump_cut_done = true
	# Altura independiente del plano del camino: jamás atraviesa sus paredes.
	jump_height += _jump_velocity * delta - 0.5 * jump_gravity * delta * delta
	_jump_velocity -= jump_gravity * delta
	if jump_height <= 0.0 and _jump_velocity < 0.0:
		jump_height = 0.0
		is_jumping = false
		anim.position = _visual_ground_position
		anim.scale = _visual_ground_scale
		hurtbox.position = _hurtbox_ground_position
		_play_ground_animation("idle")
	else:
		hurtbox.position = _hurtbox_ground_position + Vector2(0, -jump_height)
		if SpriteFit.has_clip(anim.sprite_frames, "jump"):
			# Mismo reparto que el salto del demo (lateral_player.gd):
			#  - SUBIDA: primera mitad del clip, repartida en el tiempo que tarda en subir.
			#  - BAJADA: segunda mitad, según la velocidad de caída (llega a su último fotograma al tocar suelo).
			# Antes los 20 fotogramas se repartían parejo por TODO el vuelo, y los de "levantarse tras aterrizar"
			# (agachado -> de pie) se veían en el aire: la figura se encogía y estiraba varias veces = parpadeo.
			var count: int = anim.sprite_frames.get_frame_count("jump")
			var half: int = maxi(count / 2, 1)
			var target_frame: int
			if _jump_velocity > 0.0:
				var rise_time: float = jump_impulse / maxf(jump_gravity, 1.0)
				target_frame = mini(int(_jump_elapsed / rise_time * half), half - 1)
			else:
				target_frame = mini(half + int(clampf(-_jump_velocity / JUMP_FALL_FRAME_SPEED, 0.0, 1.0) * half), count - 1)
			if anim.frame != target_frame:
				anim.frame = target_frame
		# _fit_pose() es la ÚNICA que coloca el sprite (escala, pies y altura). Antes _update_jump (física) y
		# _fit_pose (dibujo) le daban posiciones distintas al mismo sprite en cada cuadro.
		_fit_pose()
	var shadow := get_node_or_null("GroundShadow") as Node2D
	if shadow != null:
		var height_ratio: float = clampf(jump_height / 100.0, 0.0, 1.0)
		shadow.scale = Vector2.ONE * lerpf(1.0, 0.7, height_ratio)
		shadow.modulate.a = lerpf(1.0, 0.6, height_ratio)


func _do_hit(action: String) -> void:
	if _dead or is_jumping or _hurt_presentation_time > 0.0:return
	is_attacking = true
	_interaction_time = 0.0
	_locomotion = Vector2.ZERO
	_hit_targets.clear()
	_hit_actor_ids.clear()
	_contact_active = false
	_swing_presented = false
	buffered_action = ""
	combo_step += 1
	active_hit_finisher = combo_step >= 3
	active_hit_action = StringName(action)
	combo_timer = combo_window
	active_hit_damage = (punch_damage if action == "attack" else kick_damage) + (combo_damage_bonus if active_hit_finisher else 0)
	# Habilidad, combo, cansancio y miedo del personaje que controla el jugador (los compañeros no cambian).
	active_hit_damage = PlayerStatus.damage_out(active_hit_damage, self, active_hit_finisher)
	_attack_profile = kick_profile if action == "kick" else (finisher_profile if active_hit_finisher else (attack_2_profile if combo_step == 2 else attack_1_profile))
	# Companions retain their current cadence, poses and reach.
	if is_companion:
		_attack_profile = ATTACK_PROFILE.new()
		_attack_profile.animation = StringName(action)
		_attack_profile.fallback_animation = StringName(action)
		var legacy_frame: int = int(anim.sprite_frames.get_meta(action + "_contact_frame", 2))
		var count: int = maxi(anim.sprite_frames.get_frame_count(action), 1)
		_attack_profile.contact_start = float(legacy_frame) / count
		_attack_profile.contact_end = float(legacy_frame + 1) / count
		_attack_profile.swing_at = float(maxi(legacy_frame - 1, 0)) / count
		_attack_profile.hit_cue = &"finisher_hit" if active_hit_finisher else (&"kick_hit" if action == "kick" else &"attack_hit")
		_attack_profile.impact_strength = 1.8 if active_hit_finisher else (1.2 if action == "kick" else 0.7)
		# Las patadas de los acompañantes traen clips largos (hasta 2.5 s); se aceleran para no dejarlos inmóviles.
		if action == "kick" and SpriteFit.has_clip(anim.sprite_frames, "kick"):
			var natural: float = _attack_profile.clip_duration(anim.sprite_frames, &"kick")
			_attack_profile.playback_speed = maxf(1.0, natural / COMPANION_KICK_MAX_TIME)
	anim.flip_h = facing.x < 0
	# Combat is horizontal even when walking in depth or approaching diagonally.
	facing = Vector2.LEFT if anim.flip_h else Vector2.RIGHT
	if is_companion:
		hitbox.position = facing * 40
	else:
		var rectangle := RectangleShape2D.new()
		rectangle.size = _attack_profile.hitbox_size
		hitbox_shape.shape = rectangle
		hitbox_shape.position = Vector2.ZERO
		var offset: Vector2 = _attack_profile.hitbox_offset
		hitbox.position = $CollisionShape2D.position + Vector2(offset.x * facing.x, 12 + offset.y)
	hitbox_shape.set_deferred("disabled", true)
	_attack_clip = _attack_profile.animation
	if not SpriteFit.has_clip(anim.sprite_frames, _attack_clip):
		_attack_clip = _attack_profile.fallback_animation
	_fallback_attack = not SpriteFit.has_clip(anim.sprite_frames, _attack_clip) or anim.sprite_frames.get_frame_count(_attack_clip) == 0
	_attack_progress = 0.0
	_fallback_elapsed = 0.0
	attack_phase = &"windup"
	if _fallback_attack:
		_attack_duration = 0.5
		_play_ground_animation(&"idle")
		push_warning("%s: REQUIERE ANIMACIÓN %s; contacto temporal con anticipación segura." % [name, _attack_clip])
	else:
		_attack_duration = _attack_profile.clip_duration(anim.sprite_frames, _attack_clip)
		_play_ground_animation(_attack_clip)
		anim.speed_scale = _attack_profile.playback_speed
		anim.set_frame_and_progress(0, 0.0)
		_on_attack_pose()
	if active_hit_finisher:
		combo_step = 0
		combo_timer = 0.0


func _on_attack_pose() -> void:
	_apply_companion_pose()
	if is_attacking and not _fallback_attack and anim.animation == _attack_clip:
		_attack_progress = _attack_profile.clip_progress(anim)
		_refresh_attack_contact()


func _refresh_attack_contact() -> void:
	if not is_attacking:return
	if _attack_progress >= _attack_profile.swing_at and not _swing_presented:
		_swing_presented = true
		AudioLandscape.cue(_attack_profile.swing_cue, ground_position())
	var start: float = clampf(_attack_profile.contact_start, 0.0, 0.99)
	var end: float = clampf(_attack_profile.contact_end, start + 0.001, 1.0)
	attack_phase = &"windup" if _attack_progress < start else (&"contact" if _attack_progress < end else &"recovery")
	var active: bool = attack_phase == &"contact"
	if active != _contact_active:
		_contact_active = active
		hitbox_shape.set_deferred("disabled", not active)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_attacking or not _contact_active or hitbox_shape.disabled or area in _hit_targets or area.get_parent().get_instance_id() in _hit_actor_ids:
		return
	if area.is_in_group("enemy_hurtbox"):
		if area.has_method("take_damage"):
			_hit_targets.append(area)
			_hit_actor_ids[area.get_parent().get_instance_id()] = true
			if area.has_method("receive_combat_hit"):
				area.receive_combat_hit(active_hit_damage, ground_position(), active_hit_finisher)
			else:
				area.take_damage(active_hit_damage, ground_position())
			var contact: Vector2 = hitbox_shape.global_position
			var receiver_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if receiver_shape != null:
				contact = contact.lerp(receiver_shape.global_position, 0.5)
			AudioLandscape.cue(&"finisher_hit" if active_hit_finisher else _attack_profile.hit_cue, contact)
			# Contacto confirmado: tinta/material, hit-stop y micro shake en el punto de impacto.
			# La fuerza escala con el daño para que el finisher del combo se sienta más fuerte.
			var impact_axis: Vector2 = _attack_profile.impact_direction
			impact_axis.x *= facing.x
			CombatFX.hit_impact(contact, 1.8 if active_hit_finisher else _attack_profile.impact_strength, impact_axis)

# Fin de recuperación del clip real; encadena el input retenido sin pausa adicional.
func _end_attack() -> void:
	if not is_attacking:
		return
	is_attacking = false
	_contact_active = false
	attack_phase = &"recovery"
	anim.speed_scale = 1.0
	combo_timer = minf(combo_window, _attack_duration * 1.2) if combo_step > 0 else 0.0
	hitbox_shape.disabled = true
	hitbox.position = Vector2.ZERO

	# Si el jugador pulsó "attack" o "kick" mientras terminaba la animación,
	# lo encadenamos ya mismo: esto es lo que arma el combo.
	if buffered_action != "":
		var next_action := buffered_action
		_do_hit(next_action)


func _on_animation_finished() -> void:
	if is_attacking and anim.animation == _attack_clip:
		_end_attack()


func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	if _dead:return
	# El sello de guardia reduce el daño que recibe el personaje que controla el jugador.
	health.take_damage(PlayerStatus.damage_in(amount, self))
	AudioLandscape.cue(&"damage" if is_companion else &"player_hurt",ground_position())
	if _dead:return
	# El impacto empuja lateralmente sobre el suelo, nunca eleva al actor.
	if from_position != Vector2.INF:
		var direction: float = signf(ground_position().x - from_position.x)
		if is_zero_approx(direction):
			direction = -1.0 if facing.x >= 0.0 else 1.0
		knockback = Vector2(direction * 260.0, 0.0)
	# Recoil is visual only: never raises the body or grants invulnerability.
	if not is_companion:
		_damage_recoil = 0.035 * (-1.0 if knockback.x < 0 else 1.0)
		if not is_attacking and not is_jumping:
			_hurt_presentation_time = 0.18 if SpriteFit.has_clip(anim.sprite_frames, "hurt") else 0.12
			_play_ground_animation("hurt" if SpriteFit.has_clip(anim.sprite_frames, "hurt") else "idle")
	# Un golpe recibido no interrumpe un ataque activo ni deja su hitbox abierto.
	if is_companion and not is_attacking and not is_jumping and SpriteFit.has_clip(anim.sprite_frames, "hurt"):
		_hurt_presentation_time = 0.32
		_play_ground_animation("hurt")
	_damage_flash_id += 1
	var flash_id: int = _damage_flash_id
	anim.modulate = Color(1, 0.62, 0.55) if GamePreferences.flashes else Color.WHITE
	await get_tree().create_timer(0.12, false).timeout
	if is_instance_valid(anim) and flash_id == _damage_flash_id:
		anim.modulate = Color.WHITE


# --- IA del compañero (solo corre si is_companion = true) ---
# REGLAS:
# 1) Solo avanza por su cuenta si DETECTA un enemigo vivo (dentro de companion_detect_range, medido desde él o
#    desde el personaje que juegas). Va hasta quedar a su alcance, alineado, y lo golpea con el mismo _do_hit().
#    Si 3 golpes seguidos no le quitan vida (no lo alcanza), deja ese enemigo 8 segundos en vez de golpear al aire.
# 2) Si no hay enemigos cerca, solo sigue al personaje indicado en "follow_target_path" MIENTRAS ese personaje
#    camina. Si se detiene, el compañero también se detiene donde está (salvo que quede más lejos que
#    companion_leash: entonces se acerca).
# 3) Cada compañero se coloca a una distancia distinta detrás del personaje (companion_spacing).
func _companion_ai_step(delta: float) -> void:
	if _companion_attack_cooldown > 0.0:
		_companion_attack_cooldown -= delta

	var leader := get_node_or_null(follow_target_path) as Node2D
	# Velocidad real del líder: se mide por cuánto cambió su posición (más fiable que leer su "velocity").
	var leader_dir_x := 0.0
	if leader:
		var lead_pos: Vector2 = leader.ground_position()
		if _leader_last_pos != Vector2.INF and delta > 0.0:
			_leader_speed = lerpf(_leader_speed, lead_pos.distance_to(_leader_last_pos) / delta, 0.4)
			leader_dir_x = lead_pos.x - _leader_last_pos.x
		_leader_last_pos = lead_pos
	var leader_moving := _leader_speed > 25.0

	var target := _find_nearest_enemy()
	var move_target_pos: Vector2 = ground_position()
	var should_move := false
	var hurry := false

	if target:
		var me := ground_position()
		var tp: Vector2 = target.ground_position()
		var dx := tp.x - me.x
		var dy := tp.y - me.y
		if absf(dx) <= companion_attack_range and absf(dy) <= 45.0 and not is_jumping:
			# Al alcance y alineado: se queda y ataca.
			facing = Vector2(signf(dx) if dx != 0.0 else facing.x, 0.0)
			anim.flip_h = facing.x < 0
			_play_ground_animation("idle")
			velocity = knockback
			_move_on_path()
			knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
			if _companion_attack_cooldown <= 0.0:
				_companion_attack_cooldown = combo_window + 0.5
				_companion_register_swing(target)
				_do_hit("attack")
			return
		# Todavía no lo alcanza: avanza solo hasta quedar a su lado (no encima).
		move_target_pos = Vector2(tp.x - signf(dx) * companion_attack_range * 0.7, tp.y)
		should_move = me.distance_to(move_target_pos) > 8.0
		hurry = absf(dx) > companion_attack_range * 4.0
	elif leader:
		if leader_moving and absf(leader_dir_x) > 0.2:
			_follow_side = -signf(leader_dir_x)  # se coloca detrás de hacia donde camina
		var slot := _companion_slot()
		var back := absf(companion_follow_offset.x) + companion_spacing * slot
		var side_y := companion_follow_offset.y + (20.0 if slot % 2 == 1 else 0.0)
		var lead_ground: Vector2 = leader.ground_position()
		move_target_pos = lead_ground + Vector2(_follow_side * back, side_y)
		var gap: float = ground_position().distance_to(lead_ground)
		var too_far: bool = gap > companion_max_distance
		var too_close: bool = gap < companion_min_distance
		var off_slot: bool = ground_position().distance_to(move_target_pos) > 24.0
		# Se mueve si el personaje camina, si quedó lejos o si lo está pisando (para dejarle su espacio).
		should_move = off_slot and (leader_moving or too_far or too_close)
		hurry = too_far

	if not should_move:
		velocity = knockback
		if not is_jumping:
			_play_ground_animation("idle")
			# Quieto y sin enemigos: mira hacia el personaje que juegas.
			if target == null and leader != null and absf(leader.global_position.x - global_position.x) > 40.0:
				facing = Vector2.LEFT if leader.global_position.x < global_position.x else Vector2.RIGHT
				anim.flip_h = facing.x < 0
	else:
		var dir := (move_target_pos - ground_position()).normalized()
		# Obstáculo (piedra, tronco) justo delante: salta antes de chocar.
		if _companion_obstacle_ahead(dir.x):
			_begin_jump()
		velocity = dir * speed * (companion_hurry_multiplier if hurry else 1.0) + knockback
		# El giro solo cambia con una dirección clara (evita parpadeo al ajustar la posición).
		if absf(dir.x) > 0.25:
			facing = Vector2.LEFT if dir.x < 0.0 else Vector2.RIGHT
		if not is_jumping:
			_play_ground_animation("walk")
		anim.flip_h = facing.x < 0
	_move_on_path()
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)


# true si hay un obstáculo saltable (grupo "jump_obstacle") justo delante en la dirección en que camina.
func _companion_obstacle_ahead(dir_x: float) -> bool:
	if is_jumping or is_attacking or absf(dir_x) < 0.2:
		return false
	var foot_x: float = ground_position().x
	for obstacle in get_tree().get_nodes_in_group("jump_obstacle"):
		if not is_instance_valid(obstacle) or not (obstacle is Node2D):
			continue
		var dx: float = (obstacle as Node2D).global_position.x - foot_x
		if signf(dx) != signf(dir_x):
			continue
		var half: float = float(obstacle.call("_zone_half_width")) if obstacle.has_method("_zone_half_width") else 30.0
		var gap: float = absf(dx) - half
		# Solo si el salto alcanza para pasarlo por encima.
		var reachable: bool = float(obstacle.get("clear_height")) <= (jump_impulse * jump_impulse) / (2.0 * maxf(jump_gravity, 1.0)) - 8.0
		if reachable and gap <= companion_jump_gap and gap > -half:
			return true
	return false


# Lleva la cuenta de golpes que no sirvieron. Si son 3 seguidos, el enemigo se ignora 8 segundos.
func _companion_register_swing(target: Node2D) -> void:
	var hp := -1
	var health_node = target.get("health")
	if health_node != null:
		hp = int(health_node.current_health)
	var id := target.get_instance_id()
	if id == _ai_target_id and hp >= 0 and hp >= _ai_target_hp:
		_ai_idle_swings += 1
	else:
		_ai_idle_swings = 0
	_ai_target_id = id
	_ai_target_hp = hp
	if _ai_idle_swings >= 3:
		_ai_ignore[id] = Time.get_ticks_msec() + 8000
		_ai_idle_swings = 0
		_ai_target_id = 0


# Número de compañero (0, 1, 2...) para repartir las posiciones detrás del personaje.
func _companion_slot() -> int:
	var slot := 0
	for c in get_tree().get_nodes_in_group("companion"):
		if c != self and is_instance_valid(c) and c.get_instance_id() < get_instance_id():
			slot += 1
	return slot


# Enemigo vivo más cercano que el compañero DETECTA: dentro de companion_detect_range de él o del personaje que juegas.
func _find_nearest_enemy() -> Node2D:
	var leader := get_node_or_null(follow_target_path) as Node2D
	var now := Time.get_ticks_msec()
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var dead_flag = e.get("_dead")  # puede ser null: se lee sin bool() para no dar error
		if dead_flag is bool and dead_flag:
			continue
		# Ignora enemigos que no se pueden golpear: escondidos o inactivos (emboscadas todavía dormidas).
		if e is CanvasItem and not (e as CanvasItem).is_visible_in_tree():
			continue
		if not e.can_process():
			continue
		if int(_ai_ignore.get(e.get_instance_id(), 0)) > now:
			continue
		var d: float = ground_position().distance_to(e.ground_position())
		var d_leader: float = leader.ground_position().distance_to(e.ground_position()) if leader else INF
		if minf(d, d_leader) > companion_detect_range:
			continue
		# No se aleja a perseguir enemigos que están lejos del personaje que juegas.
		if leader != null and d_leader > companion_leash * 0.6 and d > companion_attack_range * 3.0:
			continue
		# Prioriza lo que amenaza al personaje que juegas, sin ignorar lo que tiene a su lado.
		var score: float = d + (d_leader * 0.6 if leader else 0.0)
		if score < nearest_dist:
			nearest_dist = score
			nearest = e
	return nearest


func ground_position() -> Vector2:
	return $CollisionShape2D.global_position + Vector2(0, 12)

func _on_died() -> void:
	if _dead:return
	_dead=true
	_contact_active=false
	CombatFX.death_burst(ground_position() + Vector2(0, -60), 0.8)
	_damage_recoil=0.0
	anim.rotation=0.0
	is_attacking=false
	buffered_action=""
	velocity=Vector2.ZERO
	_locomotion=Vector2.ZERO
	knockback=Vector2.ZERO
	is_jumping=false
	jump_height=0
	var has_death: bool = SpriteFit.has_clip(anim.sprite_frames, "death")
	_play_ground_animation("death" if has_death else "idle")
	hurtbox.position=_hurtbox_ground_position
	hitbox_shape.set_deferred("disabled",true)
	if not has_death:anim.pause()
	anim.modulate=Color(.4,.43,.45)
	AudioLandscape.cue(&"death",ground_position())
	if not is_companion:
		var party:=get_tree().get_first_node_in_group("party")
		if party!=null and party.on_active_died(self):
			remove_from_group("companion")
			$CollisionShape2D.set_deferred("disabled",true)
			$Hurtbox/CollisionShape2D.set_deferred("disabled",true)
			return
	if is_companion:
		remove_from_group("companion")
		$CollisionShape2D.set_deferred("disabled",true)
		$Hurtbox/CollisionShape2D.set_deferred("disabled",true)
		return
	var page:=CanvasLayer.new()
	page.set_script(preload("res://scripts/ui/defeat_page.gd"))
	get_parent().add_child.call_deferred(page)

func present_interaction(target: Vector2) -> void:
	if _dead or is_companion or is_attacking or is_jumping or not SpriteFit.has_clip(anim.sprite_frames, "interact"):return
	_interaction_time=0.20
	_locomotion=Vector2.ZERO
	anim.flip_h=target.x<ground_position().x
	facing = Vector2.LEFT if anim.flip_h else Vector2.RIGHT  # que el siguiente golpe salga hacia donde mira
	_play_ground_animation("interact")
