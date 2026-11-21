extends Area2D

## PUZZLE DEL MONOLITO — entrada/bloqueo del Escenario 2.
##
## Cómo funciona ahora mismo (versión funcional mínima para que puedas
## probarlo ya y seguir iterando vos):
##   1. El jugador entra en el área grande del Monolito (este nodo).
##   2. Si presiona "interact" (tecla E), se muestra una pista por el
##      DialogueManager.
##   3. El jugador debe CAMINAR y tocar con el cuerpo las 3 runas
##      (Runa1, Runa2, Runa3, hijas de este nodo) en el orden correcto
##      definido en "correct_order".
##   4. Si el orden es correcto, se abre el camino: se elimina el nodo
##      indicado en "gate_path" (la pared invisible que bloquea el paso
##      hacia la cueva).
##   5. Si se equivoca el orden, el intento se reinicia (podés cambiar
##      esto por una penalización, un sonido de error, etc.).
##
## QUÉ TENÉS QUE PERSONALIZAR VOS (a propósito lo dejo así, son decisiones
## de diseño/guion, no de programación):
##   - correct_order: el orden "canon" de las runas según la historia.
##   - El texto de la pista en _process() (ahora dice PLACEHOLDER).
##   - El texto de éxito/fracaso.
##   - Opcional: en vez de un orden fijo, podrías generarlo al azar en
##     _ready() con correct_order.shuffle() para que cambie cada partida,
##     y mostrar el orden generado en la pista (o esconderlo en el propio
##     escenario como pistas visuales que el jugador tiene que descubrir).

@export var correct_order: Array[int] = [1, 2, 3]
@export var gate_path: NodePath
@export var already_solved: bool = false

var _player_in_range: bool = false
var _progress: Array[int] = []
var _solved: bool = false

@onready var runes: Array[Node] = [$Runa1, $Runa2, $Runa3]


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	for rune in runes:
		rune.body_entered.connect(_on_rune_touched.bind(rune))
	$DebugZone.hide()
	$DebugLabel.text = "Examinar los sellos · E"
	$DebugLabel.modulate = Color("d4c7a6")
	$DebugLabel.hide()
	if already_solved:
		_solved = true
		$DebugLabel.text = "Camino abierto"
		for rune in runes:
			rune.set_accepted(true)
		_open_gate()


func _process(_delta: float) -> void:
	if not _player_in_range or not Input.is_action_just_pressed("interact") or DialogueManager.visible:
		return
	if _solved:
		# El monolito solo abre el camino: la salida a la siguiente escena la da la mesa de escritura.
		DialogueManager.show_dialogue(["Las runas siguen brillando. El camino hacia la mesa está abierto."], "Monolito")
	else:
		DialogueManager.show_dialogue([
			"El monolito tiene tres runas talladas en la piedra.",
			"Recuerda la nota de la roca: primero un trazo, después dos y al fin tres. Toca los sellos en ese orden caminando sobre ellos.",
		], "Monolito")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		$DebugLabel.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		$DebugLabel.hide()


func _on_rune_touched(body: Node2D, rune: Node) -> void:
	if _solved or not body.is_in_group("player"):
		return

	if body.has_method("present_interaction"):body.present_interaction(rune.global_position)
	var rune_id: int = rune.rune_id
	_progress.append(rune_id)
	var step: int = _progress.size() - 1

	if rune_id != correct_order[step]:
		_progress.clear()
		for seal in runes:
			seal.set_accepted(false)
		rune.reject()
		DialogueManager.show_dialogue(["...no pasa nada. Ese no es el orden."], "Monolito")
		return

	rune.set_accepted(true)
	var impact := Node2D.new()
	impact.set_script(preload("res://scripts/systems/ink_impact.gd"))
	impact.direction = Vector2.UP
	impact.strength = 0.6
	get_parent().add_child(impact)
	impact.global_position = rune.global_position + Vector2(0,-190)
	if _progress.size() == correct_order.size():
		_solved = true
		AudioLandscape.hush()
		var atmosphere := get_parent().get_node_or_null("ForestAtmosphere")
		if atmosphere:atmosphere.rewrite()
		var presentation := get_parent().get_node_or_null("ChapterPresentation")
		if presentation: presentation.rewrite("El camino ha sido reescrito.")
		AudioLandscape.cue(&"puzzle_complete",global_position)
		var portal := get_parent().get_node_or_null("StoryPortal")
		if portal: portal.activate()
		$DebugLabel.text = "Camino abierto"
		$DebugLabel.visible = _player_in_range
		_open_gate()
		GameSession.checkpoint(get_parent())
		DialogueManager.show_dialogue(["Las runas brillan y el camino hacia la mesa se abre."], "Monolito")


func _open_gate() -> void:
	if gate_path.is_empty():
		return
	var gate := get_node_or_null(gate_path)
	if gate:
		if gate.has_method("open"):
			gate.open()
		else:
			gate.queue_free()
