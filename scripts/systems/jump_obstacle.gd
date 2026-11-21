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
var _player: Node
var _side: float = -1.0


func _ready() -> void:
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
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var foot_x: float = _player.global_position.x + (_player.get_node("CollisionShape2D") as CollisionShape2D).position.x
	var dx: float = foot_x - global_position.x
	var half: float = _zone_half_width()
	if absf(dx) >= half:
		_side = signf(dx)
		return
	if float(_player.get("jump_height")) >= clear_height:
		return
	# Choca: lo devuelve al lado por el que venía.
	var edge: float = global_position.x + _side * half
	_player.global_position.x += edge - foot_x
	if _player.get("_locomotion") != null:
		var motion: Vector2 = _player.get("_locomotion")
		motion.x = 0.0
		_player.set("_locomotion", motion)
