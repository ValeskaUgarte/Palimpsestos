@tool
extends AnimatedSprite2D
## MOVIMIENTOS EDITABLES DE UN NPC DE LA HISTORIA (Ethan, Caperucita, Abuelita, Mamá, Vecina, Stephy...).
##
## Este nodo ("Motion") cuelga del NPC y trae todas las ranuras de animación ya creadas:
##   idle (quieto) · talk (hablando) · walk (caminar) · run (correr) · react (reacción)
## Cómo agregar sprites: selecciona el nodo Motion > Inspector > Sprite Frames > abre el recurso
## (panel "SpriteFrames" abajo) > elige la animación > arrastra tus imágenes o spritesheets.
##
## Mientras una ranura esté vacía NO pasa nada malo: se usa la de respaldo (talk -> idle, run -> walk...)
## y, si tampoco hay, se sigue viendo el dibujo fijo de siempre (el nodo "Visual").
## En cuanto una ranura tiene frames, el dibujo fijo se oculta solo y se usa la animación.

## Alto en pantalla de la figura. 0 = igual que el dibujo fijo actual (así tus sprites nuevos salen del mismo tamaño).
@export var standing_height: float = 0.0
## true = el tamaño y los pies de cada frame se ajustan solos. Desmárcalo si prefieres escalar el nodo a mano.
@export var auto_fit: bool = true
## true = este script NO toca la posición ni la escala del nodo Motion (ni en el editor ni en el juego): colócalo y escálalo
## tú a mano en el editor. El giro hacia el jugador y las animaciones siguen funcionando.
@export var manual_placement: bool = false
## true = tus sprites miran a la derecha. Si los dibujaste mirando a la izquierda, desmárcalo.
@export var faces_right_by_default: bool = true
## true = se gira hacia el jugador cuando está cerca o mientras habla con él.
@export var face_player: bool = true
## true = reproduce la animación "talk" todo el tiempo (por ejemplo dos vecinas conversando entre sí), aunque no esté hablando contigo.
@export var always_talk: bool = false
## Si es mayor que 0: reproduce "talk" mientras el jugador está a esta distancia (px). Sirve para NPC cuyo diálogo lo dispara otro nodo de la escena.
@export var talk_when_near: float = 0.0
## Hacia dónde mira cuando nadie lo obliga a girar: 1 = derecha, -1 = izquierda, 0 = como esté. Sirve para que dos NPC conversen mirándose.
@export_range(-1.0, 1.0, 1.0) var idle_face_direction: float = 0.0
## Dónde apoya los pies (centro X, suelo Y) respecto al origen del NPC. Se usa cuando el NPC ya no tiene el dibujo fijo \"Visual\".
## Mueve el NPC entero en el editor para colocarlo; esto solo ajusta el apoyo fino del dibujo.
@export var foot_position: Vector2 = Vector2.ZERO
## Cuánto se pasea a cada lado de su lugar (en píxeles). 0 = se queda quieto donde lo pusiste.
@export var wander_range: float = 0.0
@export var wander_speed: float = 55.0
## Probabilidad (0 a 1) de que un paseo sea corriendo (animación "run" y más rápido).
@export_range(0.0, 1.0, 0.05) var run_chance: float = 0.0
@export var run_speed_multiplier: float = 2.2
@export var pause_min: float = 1.5
@export var pause_max: float = 4.5

var _npc: Node2D
var _legacy: Node2D
var _talking: bool = false
var _target_height: float = 300.0
var _foot_y: float = 0.0
var _center_x: float = 0.0
var _home_x: float = 0.0
var _target_x: float = 0.0
var _pause_left: float = 1.0
var _moving: bool = false
var _running: bool = false
var _dir: float = 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_npc = get_parent() as Node2D
	if _npc == null:
		return
	_legacy = _npc.get_node_or_null("Visual") as Node2D
	if Engine.is_editor_hint():
		# Vista previa fiel: en el editor el NPC se ve con el mismo tamaño y apoyo que tendrá en el juego.
		# Ya NO se fuerza la animación idle: puedes elegir cualquier animación en el panel SpriteFrames y verla.
		_measure_legacy()
		_preview()
		_editor_signature = _current_signature()
		return
	_rng.randomize()
	_home_x = _npc.position.x
	_target_x = _home_x
	_measure_legacy()
	if _npc.has_signal("conversation_started"):
		_npc.conversation_started.connect(func(): _talking = true)
	if _npc.has_signal("conversation_finished"):
		_npc.conversation_finished.connect(func(): _talking = false)
	_refresh()


# Mide el dibujo fijo actual (Visual) para que los sprites nuevos queden del mismo tamaño y apoyados igual.
func _measure_legacy() -> void:
	if standing_height > 0.0:
		_target_height = standing_height
	if _legacy == null:
		_foot_y = foot_position.y
		_center_x = foot_position.x
	if _legacy is Sprite2D and (_legacy as Sprite2D).texture != null:
		var sprite := _legacy as Sprite2D
		var texture: Texture2D = sprite.texture
		if sprite.region_enabled:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = sprite.region_rect
			texture = atlas
		var metrics: Dictionary = SpriteFit.metrics(texture)
		if not metrics.is_empty():
			if standing_height <= 0.0:
				_target_height = float(int(metrics["bottom"]) - int(metrics["top"])) * absf(sprite.scale.y)
			_foot_y = sprite.position.y + (float(metrics["bottom"]) - float(metrics["h"]) * 0.5) * sprite.scale.y
			_center_x = sprite.position.x + (float(metrics["cx"]) - float(metrics["w"]) * 0.5) * sprite.scale.x


# Vista previa en el editor: solo ajusta tamaño y pies. La animación y el cuadro los eliges tú (panel SpriteFrames);
# solo se pone idle si el nodo no tiene una animación válida.
func _preview() -> void:
	if sprite_frames == null or not auto_fit or manual_placement:
		return
	if animation == &"" or not SpriteFit.has_clip(sprite_frames, animation):
		var clip: StringName = SpriteFit.resolve_clip(sprite_frames, &"idle", false)
		if clip == &"":
			return
		animation = clip
		frame = 0
	_fit()


var _editor_signature: String = ""

# Qué cosas, si cambian, obligan a recalcular el ajuste en el editor (así no se pisa tu edición cuadro a cuadro).
func _current_signature() -> String:
	return "%s|%d|%s|%s|%s|%s|%s" % [str(animation), frame, str(flip_h), str(standing_height), str(foot_position), str(sprite_frames.get_instance_id() if sprite_frames != null else 0), str(auto_fit) + str(manual_placement)]


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if _npc != null and not manual_placement:
			var signature := _current_signature()
			if signature != _editor_signature:
				_editor_signature = signature
				_measure_legacy()
				_preview()
		return
	if _npc == null:
		return
	_update_wander(delta)
	_refresh()


func _update_wander(delta: float) -> void:
	if wander_range <= 0.0 or _talking:
		_moving = false
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_moving = false
		if _pause_left <= 0.0:
			_running = _rng.randf() < run_chance
			_target_x = _home_x + _rng.randf_range(-wander_range, wander_range)
			if absf(_target_x - _npc.position.x) < 60.0:
				_target_x = clampf(_npc.position.x - _dir * 160.0, _home_x - wander_range, _home_x + wander_range)
			_dir = signf(_target_x - _npc.position.x) if _target_x != _npc.position.x else _dir
			_moving = true
		return
	var step: float = wander_speed * (run_speed_multiplier if _running else 1.0) * delta
	_npc.position.x = move_toward(_npc.position.x, _target_x, step)
	_moving = true
	if is_equal_approx(_npc.position.x, _target_x):
		_moving = false
		_pause_left = _rng.randf_range(pause_min, pause_max)


# Elige la animación según lo que hace el NPC y muestra Motion o el dibujo fijo.
func _refresh() -> void:
	var wanted: StringName = &"idle"
	# Si pasea, camina (no se desliza en la animación de hablar); solo habla quieto.
	if _talking or ((always_talk or _player_is_near()) and not _moving):
		wanted = &"talk"
	elif _moving:
		wanted = &"run" if _running else &"walk"
	var clip: StringName = SpriteFit.resolve_clip(sprite_frames, wanted, false)
	var has_art: bool = clip != &""
	visible = has_art
	if _legacy != null:
		_legacy.visible = not has_art
	if not has_art:
		return
	if animation != clip or not is_playing():
		play(clip)
	_face()
	if auto_fit:
		_fit()


func _player_is_near() -> bool:
	if talk_when_near <= 0.0:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and absf(player.global_position.x - _npc.global_position.x) <= talk_when_near


func _face() -> void:
	var direction: float = _dir if _moving else 0.0
	# Mientras camina por su recorrido mira hacia donde va; solo se gira al jugador cuando está quieto o hablando con él.
	var in_range: Variant = _npc.get("player_in_range")
	if face_player and not (_moving and not _talking) and (_talking or (in_range is bool and in_range)):
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			direction = signf(player.global_position.x - _npc.global_position.x)
	if direction == 0.0:
		direction = idle_face_direction
	if direction == 0.0:
		return
	flip_h = (direction < 0.0) if faces_right_by_default else (direction > 0.0)


# Tamaño y apoyo de cada frame (mismo método que usan los aldeanos y los personajes jugables).
var _reference_cache: Dictionary = {}


# Cuadro de referencia de una animación: el más alto. Así un cuadro bajo (una pose agachada) no agranda al personaje.
func _reference(animation_name: StringName) -> Dictionary:
	if _reference_cache.has(animation_name):
		return _reference_cache[animation_name]
	var best: Dictionary = {}
	var best_height: float = -1.0
	for index in sprite_frames.get_frame_count(animation_name):
		var metrics: Dictionary = SpriteFit.metrics(sprite_frames.get_frame_texture(animation_name, index))
		if metrics.is_empty():
			continue
		var height: float = float(int(metrics["bottom"]) - int(metrics["top"]))
		if height > best_height:
			best_height = height
			best = metrics
	_reference_cache[animation_name] = best
	return best


func _fit() -> void:
	if manual_placement:
		return
	var texture: Texture2D = sprite_frames.get_frame_texture(animation, frame)
	if texture == null:
		return
	var measured: Dictionary = SpriteFit.metrics(texture)
	var first: Dictionary = _reference(animation)
	if measured.is_empty() or first.is_empty():
		return
	var visible_height: float = float(int(first["bottom"]) - int(first["top"]))
	if visible_height <= 0.0:
		return
	var fit_scale: float = _target_height / visible_height
	var baseline: float = float(measured["bottom"]) - float(measured["h"]) * 0.5
	var offset_x: float = -(float(first["cx"]) - float(first["w"]) * 0.5)
	var side: float = -1.0 if flip_h else 1.0
	scale = Vector2.ONE * fit_scale
	position = Vector2(_center_x + offset_x * fit_scale * side, _foot_y - baseline * fit_scale)
