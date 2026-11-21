extends Node2D
## BARRA DE VIDA DE UN ENEMIGO — mismo estilo que la de la demo y la del jefe.
##
## Se dibuja con el marco ornamentado del atlas de la interfaz (assets/ui/botones.png) y el relleno rojo,
## igual que la barra del jefe (boss_health.gd). Muestra:
##   - el VALOR en números ("18 / 25"),
##   - el GOLPE recibido: el trozo que se acaba de perder queda en dorado y se va vaciando
##     (además, sobre el enemigo sube el número del golpe, "-8", ver CombatFX.damage_number).
## level.gd se la agrega a todo enemigo de las escenas del cuento (menos a los guardianes, que ya tienen su
## barra grande abajo) y enemy.gd (demo) usa la misma a través de scripts/lateral/enemy_health.gd.
## Siempre visible mientras el enemigo esté vivo.

const ATLAS: Texture2D = preload("res://assets/ui/botones.png")
## Marco de la barra dentro del atlas (el mismo que usa la barra del jefe).
const FRAME_REGION := Rect2(1067, 402, 204, 37)
## Zona roja de relleno dentro del atlas (la misma que usa la barra del jefe).
const FILL_REGION := Rect2(1072, 414, 159, 13)

## Tamaño de la barra en pantalla (mantiene la proporción del marco 204 x 37).
@export var bar_size: Vector2 = Vector2(150.0, 27.2)
@export var head_gap: float = 16.0
## true = la barra se coloca sola sobre la cabeza según el dibujo del enemigo. false = se queda donde la pongas.
@export var auto_place: bool = true
## Muestra los números "vida / vida máxima" sobre la barra.
@export var show_value: bool = true
@export var value_font_size: int = 11

var _enemy: Node
var _ratio: float = 1.0
var _shown_ratio: float = 1.0
var _current: int = 0
var _maximum: int = 1
var _health: Node = null


func _ready() -> void:
	if _enemy == null:
		_enemy = get_parent()
	z_index = 40
	var health: Node = _enemy.get_node_or_null("HealthComponent")
	if health == null:
		queue_free()
		return
	_health = health
	health.health_changed.connect(_on_health_changed)
	health.died.connect(hide)
	_current = health.current_health
	_maximum = health.max_health
	_ratio = float(_current) / maxf(float(_maximum), 1.0)
	_shown_ratio = _ratio
	if auto_place:
		_place_above_head()


func _place_above_head() -> void:
	var visual := _enemy.get_node_or_null("Visual") as AnimatedSprite2D
	var shape := _enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if visual == null or shape == null or visual.sprite_frames == null:
		position = Vector2(0, -260)
		return
	var frames: SpriteFrames = visual.sprite_frames
	var animation: StringName = &"idle" if frames.has_animation(&"idle") else visual.animation
	var foot_y: float = shape.position.y + 12.0
	var head_y: float = foot_y - 220.0
	if frames.get_frame_count(animation) > 0:
		var metrics: Dictionary = SpriteFit.metrics(frames.get_frame_texture(animation, 0))
		if not metrics.is_empty():
			var art_scale: float = float(frames.get_meta(String(animation) + "_art_scale", 1.0))
			var ground = _enemy.get("_ground_scale")
			var scale_y: float = absf(float(ground.y) if ground is Vector2 else 1.0) * art_scale
			var body_height: float = float(int(metrics["bottom"]) - int(metrics["top"])) * scale_y
			head_y = foot_y - clampf(body_height, 120.0, 420.0)
	position = Vector2(shape.position.x, head_y - head_gap)


func _on_health_changed(current: int, maximum: int) -> void:
	_current = current
	_maximum = maximum
	_ratio = clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	# Lee la vida real en cada cuadro: la barra nunca se queda atrasada, aunque una señal se pierda.
	if _health != null and is_instance_valid(_health):
		_current = _health.current_health
		_maximum = _health.max_health
		_ratio = clampf(float(_current) / maxf(float(_maximum), 1.0), 0.0, 1.0)
	# El trozo perdido baja suave, para que se note cuánto quitó el golpe.
	_shown_ratio = move_toward(_shown_ratio, _ratio, delta * 1.2)
	queue_redraw()


func _draw() -> void:
	# Marco ornamentado del atlas (igual que la barra del jefe) y, encima, nuestro propio relleno dentro del hueco.
	var origin := Vector2(-bar_size.x * 0.5, -bar_size.y * 0.5)
	var factor := Vector2(bar_size.x / FRAME_REGION.size.x, bar_size.y / FRAME_REGION.size.y)
	draw_texture_rect_region(ATLAS, Rect2(origin, bar_size), FRAME_REGION)
	var hole := Rect2(origin + (FILL_REGION.position - FRAME_REGION.position) * factor, FILL_REGION.size * factor)
	draw_rect(hole, Color(0.12, 0.09, 0.08, 1.0))
	if _shown_ratio > _ratio:
		draw_rect(Rect2(hole.position, Vector2(hole.size.x * _shown_ratio, hole.size.y)), Color(0.93, 0.78, 0.45, 0.95))
	if _ratio > 0.0:
		draw_rect(Rect2(hole.position, Vector2(hole.size.x * _ratio, hole.size.y)), Color(0.72, 0.1, 0.1, 1.0))
	if show_value:
		_draw_value(origin)


# Números "vida / vida máxima" centrados sobre el relleno.
func _draw_value(origin: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var text: String = "%d / %d" % [_current, _maximum]
	var center_y: float = origin.y + bar_size.y * 0.5
	var baseline := Vector2(origin.x, center_y + float(value_font_size) * 0.36)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, bar_size.x * 0.92, value_font_size, 4, Color(0.02, 0.015, 0.01, 0.95))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, bar_size.x * 0.92, value_font_size, Color(0.96, 0.9, 0.74))
