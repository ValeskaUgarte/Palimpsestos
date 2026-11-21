extends Area2D

## Cartel/pista interactuable. El jugador entra en el área, presiona
## "interact" (tecla E), y se muestra el texto de "lines" por el
## DialogueManager. Reutilizable para cualquier pista del juego
## (no solo la del monolito).

@export var lines: Array[String] = ["PLACEHOLDER: escribí acá la pista real."]
@export var speaker_name: String = ""
## true = la pista aparece sola al acercarte (no hace falta pulsar E).
@export var auto_show: bool = true

var _player_in_range: bool = false
var _armed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not _player_in_range or not DialogueManager.can_start_dialogue():
		return
	if Input.is_action_just_pressed("interact") or (auto_show and _armed):
		_armed = false
		AudioLandscape.cue(&"clue",global_position)
		DialogueManager.show_dialogue(lines, speaker_name)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_armed = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
