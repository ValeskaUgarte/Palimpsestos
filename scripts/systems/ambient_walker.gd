@tool
extends Node2D
## Aldeano o animal de ambiente: camina de un lado a otro entre x_min y x_max, se detiene un rato y vuelve a caminar.
## El nodo está parado en los pies del personaje. No tiene colisión ni interactúa con el jugador.

@export var frames: SpriteFrames:
	set(value):
		frames = value
		if is_inside_tree() and Engine.is_editor_hint():
			_setup_editor_preview()
@export var x_min: float = -400.0
@export var x_max: float = 400.0
## Si está activo, x_min/x_max se miden desde donde pongas al personaje (así lo mueves y su recorrido va con él).
@export var relative_range: bool = true
## false = el personaje arranca justo donde lo pusiste. true = arranca en un punto al azar de su recorrido.
@export var start_random: bool = false
var _lo: float = -400.0
var _hi: float = 400.0
@export var speed: float = 45.0
@export var move_animation: StringName = &"walk"
@export var pause_min: float = 1.5
@export var pause_max: float = 4.5
## Alto en pantalla de la figura. Se usa para ajustar solo los frames sin medidas guardadas.
@export var standing_height: float = 300.0
## Probabilidad (0 a 1) de que un recorrido sea CORRIENDO (animación "run", más rápido). 0 = siempre camina.
## Mientras la ranura "run" esté vacía se usa "walk".
@export_range(0.0, 1.0, 0.05) var run_chance: float = 0.0
@export var run_speed_multiplier: float = 2.2
## Si es mayor que 0: cuando el jugador se acerca a esta distancia se queda quieto y reproduce "react"
## (ladrido, maullido, saludo...). 0 = no reacciona. Si "react" está vacía no hace nada.
@export var react_distance: float = 0.0
## Si está activo, el tamaño se ajusta solo a standing_height. Desactívalo para cambiar el tamaño a mano (Sprite > Scale).
@export var auto_fit: bool = true

var _sprite: AnimatedSprite2D
var _target_x: float = 0.0
var _pause: float = 0.0
var _dir: float = 1.0
var _running: bool = false
var _reacting: bool = false


func _get_sprite() -> AnimatedSprite2D:
	var existing := get_node_or_null("Sprite") as AnimatedSprite2D
	if existing != null:
		return existing
	var created := AnimatedSprite2D.new()
	created.name = "Sprite"
	add_child(created)
	return created


func _setup_editor_preview() -> void:
	if _sprite == null:
		_sprite = _get_sprite()
	_sprite.sprite_frames = frames
	if frames != null and frames.has_animation(&"idle"):
		_sprite.animation = &"idle"
		_sprite.frame = 0
	if auto_fit:
		_fit()
	queue_redraw()


# En el editor se ve el personaje parado y una línea con el recorrido (x_min a x_max).
func _edge(value: float) -> float:
	return value if relative_range else value - position.x


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(_edge(x_min), 0), Vector2(_edge(x_max), 0), Color(0.2, 1, 0.5, 0.9), 3.0)
		draw_circle(Vector2(_edge(x_min), 0), 6.0, Color(0.2, 1, 0.5, 0.9))
		draw_circle(Vector2(_edge(x_max), 0), 6.0, Color(0.2, 1, 0.5, 0.9))


func _ready() -> void:
	_lo = position.x + x_min if relative_range else x_min
	_hi = position.x + x_max if relative_range else x_max
	if Engine.is_editor_hint():
		_setup_editor_preview()
		return
	_sprite = _get_sprite()
	_sprite.sprite_frames = frames
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if start_random:
		position.x = rng.randf_range(_lo, _hi)
	_pick_target(rng)
	_play_move()
	if auto_fit:
		_fit()


# Reproduce una animación; si su ranura todavía no tiene sprites usa la de respaldo (run -> walk -> idle).
func _play_clip(clip: StringName) -> void:
	var resolved: StringName = SpriteFit.resolve_clip(frames, clip)
	if resolved == &"":
		_sprite.stop()
	else:
		_sprite.play(resolved)


func _play_move() -> void:
	_play_clip(&"run" if _running else move_animation)


func _player_is_near() -> bool:
	if react_distance <= 0.0:
		return false
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	return player != null and absf(player.global_position.x - global_position.x) < react_distance


func _pick_target(rng: RandomNumberGenerator) -> void:
	_running = rng.randf() < run_chance
	_target_x = rng.randf_range(_lo, _hi)
	if absf(_target_x - position.x) < 120.0:
		_target_x = clampf(position.x + _dir * -1.0 * 240.0, _lo, _hi)
	_dir = signf(_target_x - position.x)
	if _dir == 0.0:
		_dir = 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _sprite == null:
		return
	if react_distance > 0.0 and SpriteFit.has_clip(frames, &"react"):
		if _player_is_near():
			if not _reacting:
				_reacting = true
				_sprite.play(&"react")
			_fit()
			return
		elif _reacting:
			_reacting = false
			_pause = 0.6
			_play_clip(&"idle")
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			_pick_target(rng)
			_play_move()
		_fit()
		return
	position.x += _dir * speed * (run_speed_multiplier if _running else 1.0) * delta
	if (_dir > 0.0 and position.x >= _target_x) or (_dir < 0.0 and position.x <= _target_x):
		var rng2 := RandomNumberGenerator.new()
		rng2.randomize()
		_pause = rng2.randf_range(pause_min, pause_max)
		_play_clip(&"idle")
	_sprite.flip_h = _dir < 0.0
	_fit()


# Tamaño y apoyo de cada frame (metadatos fit_*), igual que en los personajes jugables.
func _fit() -> void:
	if not auto_fit or frames == null or _sprite == null:
		return
	var texture: Texture2D = frames.get_frame_texture(_sprite.animation, _sprite.frame)
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
		var measured: Dictionary = SpriteFit.metrics(texture)
		var first: Dictionary = SpriteFit.metrics(frames.get_frame_texture(_sprite.animation, 0))
		if measured.is_empty() or first.is_empty() or int(first["bottom"]) - int(first["top"]) <= 0:
			return
		fit_scale = standing_height / float(int(first["bottom"]) - int(first["top"]))
		fit_baseline = float(measured["bottom"]) - float(measured["h"]) * 0.5
		fit_offset_x = -(float(first["cx"]) - float(first["w"]) * 0.5)
	var side: float = -1.0 if _sprite.flip_h else 1.0
	_sprite.scale = Vector2.ONE * fit_scale
	_sprite.position = Vector2(fit_offset_x * fit_scale * side, -fit_baseline * fit_scale)
