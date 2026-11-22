@tool
extends Node2D
## Obstáculo para saltar (piedra o tronco). El nodo está parado en el suelo.
## Bloquea al jugador mientras camina; si salta con suficiente altura (clear_height) lo pasa por encima.
## En el editor se ve el dibujo y un recuadro amarillo con la zona que bloquea.

@export var texture: Texture2D:
	set(value):
		texture = value
		_refresh()
@export var region: Rect2 = Rect2(0, 0, 100, 100):
	set(value):
		region = value
		_refresh()
@export var target_height: float = 60.0:
	set(value):
		target_height = value
		_refresh()
## Altura mínima del salto para pasar por encima.
@export var clear_height: float = 45.0
## Mitad del ancho de la zona que bloquea (si es 0 se calcula del dibujo).
@export var half_width: float = 0.0

var _sprite: Sprite2D
var _sides: Dictionary = {}  # id del personaje -> lado por el que llegó (-1 izquierda, 1 derecha)


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("jump_obstacle")
	_refresh()


func _zone_half_width() -> float:
	if half_width > 0.0:
		return half_width
	if region.size.y <= 0.0:
		return 30.0
	return region.size.x * (target_height / region.size.y) * 0.32


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.region_enabled = true
	_sprite.region_rect = region
	if region.size.y > 0.0:
		var factor: float = target_height / region.size.y
		_sprite.scale = Vector2.ONE * factor
		_sprite.position = Vector2(0, -region.size.y * factor * 0.5 + 4.0)
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		var half: float = _zone_half_width()
		draw_rect(Rect2(-half, -clear_height, half * 2.0, clear_height), Color(1, 0.9, 0.2, 0.25), false, 2.0)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var half: float = _zone_half_width()
	# Bloquea a CADA personaje (el que controla el jugador y los acompañantes), cada uno con su lado de origen.
	for actor in _actors():
		_block(actor as Node2D, half)


func _actors() -> Array:
	var list: Array = get_tree().get_nodes_in_group("player")
	for companion in get_tree().get_nodes_in_group("companion"):
		if not list.has(companion):
			list.append(companion)
	return list


func _block(actor: Node2D, half: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var shape := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		return
	var id: int = actor.get_instance_id()
	var foot_x: float = actor.global_position.x + shape.position.x
	var dx: float = foot_x - global_position.x
	if absf(dx) >= half:
		_sides[id] = signf(dx)
		return
	if float(actor.get("jump_height")) >= clear_height:
		return
	# Choca: lo devuelve al lado por el que venía.
	var side: float = float(_sides.get(id, -1.0))
	var edge: float = global_position.x + side * half
	actor.global_position.x += edge - foot_x
	if actor.get("_locomotion") != null:
		var motion: Vector2 = actor.get("_locomotion")
		motion.x = 0.0
		actor.set("_locomotion", motion)
