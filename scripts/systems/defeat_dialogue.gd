extends Node
## DIÁLOGO AL DERROTAR A UN ENEMIGO (para las últimas palabras de un guardabosque, el aviso de un jefe, etc.).
## Ponlo como nodo en el nivel y rellena en el Inspector:
##  - enemy_path: el enemigo (ej. ../RangerWood).
##  - lines: una entrada por pantalla de texto. Si empieza con "Nombre-" (ej. "Ranger-No continúen..."), habla ese personaje y sale
##    su retrato; si no lleva nombre, es texto de narrador (acotación del guion).
##  - delay: segundos que se espera tras la derrota antes de mostrar el texto.
## Solo se muestra una vez, y solo si el enemigo cae durante la partida (si ya estaba derrotado al cargar, no vuelve a salir).

@export var enemy_path: NodePath
@export var lines: Array[String] = []
@export var delay: float = 1.0

var _shown: bool = false


func _ready() -> void:
	var enemy := get_node_or_null(enemy_path)
	if enemy != null and enemy.get("health") != null:
		enemy.health.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	if _shown or lines.is_empty():
		return
	_shown = true
	await get_tree().create_timer(delay).timeout
	var entries: Array = []
	for line in lines:
		entries.append({"text": line, "speaker": "", "portrait": null})
	DialogueManager.show_conversation(entries)
