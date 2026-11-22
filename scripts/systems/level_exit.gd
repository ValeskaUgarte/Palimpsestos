extends Area2D

## Área invisible que termina el capítulo (o pasa a la siguiente escena) cuando
## el jugador entra en ella. Solo hay que poner este nodo en cualquier nivel y
## asignarle "next_scene_path" en el Inspector -- no hace falta tocar código
## para agregar más escenas/capítulos más adelante.
@export var next_scene_path: String = "res://scenes/levels/chapter_end.tscn"
@export var one_shot: bool = true
@export var required_enemy: NodePath
## Escena jugable (índice en GameSession.PARTS) a la que lleva la salida. -1 = escena completa.
var next_part: int = -1
## Si no es INF, X donde aparece Elliot en el tramo de destino (volver atrás: junto a su salida derecha).
var arrive_x: float = INF
## Sentido de llegada: 1 = avanzando, -1 = volviendo atrás (los compañeros se colocan al otro lado).
var arrive_dir: float = 1.0
var _blocked_note: bool = false

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not required_enemy.is_empty():
		var enemy=get_node_or_null(required_enemy)
		if enemy:enemy.health.died.connect(_on_guardian_defeated)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		travel()

func travel() -> void:
	if not required_enemy.is_empty():
		var enemy := get_node_or_null(required_enemy)
		if enemy != null and enemy.health.current_health > 0:
			if not _blocked_note:
				_blocked_note=true
				var presentation := get_parent().get_node_or_null("ChapterPresentation")
				if presentation:presentation.rewrite("El guardián aún retiene esta página.")
			return
	if _triggered and one_shot:
		return
	_triggered = true
	# No retirar cuerpos/áreas mientras el motor está despachando contactos.
	_change_scene.call_deferred()

func _change_scene() -> void:
	if not ResourceLoader.exists(next_scene_path):
		_triggered = false
		push_error("No se pudo cruzar al escenario: "+next_scene_path)
		return
	# La energía del grupo pasa a la escena siguiente tal como está (no se restablece).
	GameSession.capture_party_health(get_tree().current_scene)
	GameSession.current_part = next_part
	GameSession.part_start_override = arrive_x
	GameSession.part_arrival_dir = arrive_dir
	ScenePages.travel(next_scene_path)

func _on_guardian_defeated() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			travel.call_deferred()
			break
