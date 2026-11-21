extends Node

# CombatFX — hace que los golpes "se sientan".
#
# Actualmente el juego solo mueve un poco al personaje (knockback) y le pone
# un tinte de color, pero eso no comunica un impacto: no hay pausa, no hay
# sacudida, no hay nada que "explote" en el punto de contacto.
#
# Esta autoload agrega las 3 técnicas clásicas de "juice" para peleas 2D:
#   1) Hit-stop: freeze de una fracción de segundo justo al conectar el golpe.
#   2) Screen shake: sacude la cámara activa brevemente.
#   3) Chispazo (spark): una ráfaga de partículas en el punto exacto de contacto.
#
# CÓMO USARLO desde cualquier script (ya está conectado en player.gd y
# enemy_ai.gd, no hace falta tocar nada más):
#
#   CombatFX.hit_impact(punto_de_contacto_global, fuerza)
#
# "fuerza" es opcional (1.0 por defecto). Usa valores más altos para golpes
# fuertes (ej. el finisher del combo, o el jefe Lobo) y más bajos para golpes
# débiles.
#
# IMPORTANTE: para que funcione, este script debe estar cargado como
# Autoload (Project > Project Settings > Autoload) con el nombre "CombatFX".
# Ya lo dejamos configurado en project.godot.

@export var default_hitstop_time: float = 0.06
@export var default_shake_strength: float = 2.0
@export var default_shake_duration: float = 0.18

var _shake_timer: float = 0.0
var _shake_duration: float = 0.001
var _shake_strength: float = 0.0
var _hitstop_active: bool = false
var _fallback_camera: Camera2D
var _fallback_offset: Vector2 = Vector2.ZERO
var _previous_time_scale: float = 1.0


func _process(delta: float) -> void:
	if _shake_timer <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		_restore_fallback_camera()
		_shake_timer = 0.0
		return
	if cam != _fallback_camera:
		_restore_fallback_camera()
		_shake_timer = 0.0
		return
	_shake_timer -= delta
	var falloff: float = clampf(_shake_timer / _shake_duration, 0.0, 1.0)
	if _shake_timer <= 0.0:
		_restore_fallback_camera()
	else:
		cam.offset = _fallback_offset + Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * _shake_strength * falloff


# Hojas y polvo en la pelea. Cada golpe levanta polvo; algunos golpes también dejan caer hojas
# (siempre el remate). La probabilidad se ajusta aquí.
@export_range(0.0, 1.0) var leaf_chance: float = 0.4
var _leaf_texture: Texture2D = null

func hit_impact(global_pos: Vector2, strength: float = 1.0, direction: Vector2 = Vector2.RIGHT) -> void:
	strength = clampf(strength, 0.4, 2.0)
	_spawn_spark(global_pos, strength)
	_spawn_dust(global_pos, strength)
	if strength >= 1.6 or randf() < leaf_chance:
		_spawn_leaves(global_pos, strength)
	var scene := get_tree().current_scene
	if scene != null:
		var stroke := Node2D.new()
		stroke.set_script(preload("res://scripts/systems/ink_impact.gd"))
		stroke.set("strength", strength)
		stroke.set("direction", direction.normalized())
		scene.add_child(stroke)
		stroke.global_position = global_pos
	_do_shake(default_shake_strength * strength, default_shake_duration)
	_do_hitstop(clampf(default_hitstop_time * strength, 0.025, 0.085))


# Número de golpe flotante sobre quien lo recibe. actor = el personaje (CharacterBody2D) que perdió vida.
# Lo llama HealthComponent solo; funciona igual para enemigos, Elliot, Jhon, Thomas y compañeros.
func damage_number(actor: Node, amount: int) -> void:
	if not (actor is Node2D) or amount <= 0:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var popup := Node2D.new()
	popup.set_script(preload("res://scripts/systems/damage_number.gd"))
	popup.set("amount", amount)
	popup.set("on_player_side", actor.is_in_group("player") or actor.is_in_group("companion") or actor.is_in_group("player_hurtbox"))
	popup.set("strength", float(amount) / 12.0)
	root.add_child(popup)
	# Sobre la cabeza: arriba de la zona de golpe (Hurtbox) y, si tiene barra de vida, un poco más arriba.
	var head: Vector2 = (actor as Node2D).global_position + Vector2(0, -190)
	var hurt_shape := actor.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	if hurt_shape != null and hurt_shape.shape is RectangleShape2D:
		head = hurt_shape.global_position + Vector2(0, -(hurt_shape.shape as RectangleShape2D).size.y * 0.5 * absf(hurt_shape.global_scale.y))
	if actor.has_node("HealthBar"):
		head.y -= 44.0
	popup.global_position = head + Vector2(0, -10)


func _do_shake(strength: float, duration: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if cam.has_method("add_impact"):
		_restore_fallback_camera()
		_shake_timer = 0.0
		cam.call("add_impact", strength, duration)
		return
	if cam != _fallback_camera:
		_restore_fallback_camera()
		_fallback_camera = cam
		_fallback_offset = cam.offset
	_shake_strength = strength
	_shake_duration = max(duration, 0.001)
	_shake_timer = duration


func _restore_fallback_camera() -> void:
	if is_instance_valid(_fallback_camera):
		_fallback_camera.offset = _fallback_offset
	_fallback_camera = null


func _do_hitstop(duration: float) -> void:
	if duration <= 0.0 or _hitstop_active:
		return
	_hitstop_active = true
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 0.05
	# ignore_time_scale = true -> este timer corre en tiempo REAL,
	# así el freeze dura lo mismo sin importar que Engine.time_scale esté en 0.05.
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = _previous_time_scale
		_hitstop_active = false
	)


func _spawn_spark(global_pos: Vector2, strength: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles2D.new()
	root.add_child(p)
	p.global_position = global_pos
	p.z_index = 100
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(8 + 6 * strength)
	p.lifetime = 0.22
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 90.0 * strength
	p.initial_velocity_max = 200.0 * strength
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0 * strength
	p.color = Color(0.84, 0.75, 0.52)
	var ink := Gradient.new()
	ink.colors = PackedColorArray([Color(0.88,0.8,0.57,1), Color(0.12,0.1,0.075,0)])
	p.color_ramp = ink
	p.gravity = Vector2(0, 65)
	p.emitting = true
	var cleanup_timer := get_tree().create_timer(p.lifetime + 0.15, true, false, true)
	# Bound node callables disconnect when a scene frees their target.
	cleanup_timer.timeout.connect(p.queue_free)


# --- Polvo: una nube breve que sube y se disipa al golpear.
func _spawn_dust(global_pos: Vector2, strength: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles2D.new()
	root.add_child(p)
	p.global_position = global_pos + Vector2(0, 6)
	p.z_index = 90
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = int(7 + 5 * strength)
	p.lifetime = 0.75
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, -12)
	p.initial_velocity_min = 25.0 * strength
	p.initial_velocity_max = 70.0 * strength
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0 * strength
	p.color = Color(0.55, 0.5, 0.42, 0.55)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.emitting = true
	var cleanup := get_tree().create_timer(p.lifetime + 0.2, true, false, true)
	cleanup.timeout.connect(p.queue_free)


# --- Hojas: unas pocas caen despacio desde el punto del golpe, girando.
func _spawn_leaves(global_pos: Vector2, strength: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles2D.new()
	root.add_child(p)
	p.global_position = global_pos + Vector2(0, -40)
	p.texture = _get_leaf_texture()
	p.z_index = 60
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.25
	p.amount = int(5 + 4 * strength)
	p.lifetime = 2.4
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.gravity = Vector2(0, 42)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 2.6
	p.color = Color(0.5, 0.42, 0.22)
	var tint := Gradient.new()
	tint.colors = PackedColorArray([Color(0.62, 0.5, 0.24, 1), Color(0.36, 0.42, 0.18, 1), Color(0.5, 0.36, 0.2, 1)])
	p.color_initial_ramp = tint
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.emitting = true
	var cleanup := get_tree().create_timer(p.lifetime + 0.3, true, false, true)
	cleanup.timeout.connect(p.queue_free)


# Textura de hoja dibujada por código (óvalo con nervadura), sin archivos nuevos.
func _get_leaf_texture() -> Texture2D:
	if _leaf_texture != null:
		return _leaf_texture
	var w := 12
	var h := 7
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx := (float(x) - (w - 1) * 0.5) / ((w - 1) * 0.5)
			var dy := (float(y) - (h - 1) * 0.5) / ((h - 1) * 0.5)
			if dx * dx + dy * dy <= 1.0:
				var vein := absf(dy) < 0.12
				img.set_pixel(x, y, Color(0.95, 0.95, 0.95, 1.0) if vein else Color(1, 1, 1, 1))
	_leaf_texture = ImageTexture.create_from_image(img)
	return _leaf_texture

