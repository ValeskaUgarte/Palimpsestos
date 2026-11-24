extends Node
## DIÁLOGO AL DERROTAR A UN ENEMIGO (para las últimas palabras de un guardabosque, el aviso de un jefe, etc.).
## Ponlo como nodo en el nivel y rellena en el Inspector:
##  - enemy_path: el enemigo (ej. ../RangerWood).
##  - lines: una entrada por pantalla de texto. Si empieza con "Nombre-" (ej. "Ranger-No continúen..."), habla ese personaje y sale
##    su retrato; si no lleva nombre, es texto de narrador (acotación del guion).
##  - delay: segundos que se espera tras la derrota antes de mostrar el texto.
## Solo se muestra una vez, y solo si el enemigo cae durante la partida (si ya estaba derrotado al cargar, no vuelve a salir).
##
## POCIÓN DESPUÉS DE LA PELEA (opcional): si potion_texture tiene imagen, al terminar el diálogo aparece una poción en el
## suelo, se dicen potion_lines (ej. Elliot la comenta) y Elliot se detiene a beberla: se ve el gesto y no avanza hasta que
## termina. Recupera heal_amount de vida (0 = toda).

@export var enemy_path: NodePath
@export var lines: Array[String] = []
@export var delay: float = 1.0
@export var potion_texture: Texture2D
@export var potion_lines: Array[String] = []
@export var heal_amount: int = 0
## Quién bebe la poción (por defecto Elliot).
@export var drinker_path: NodePath = ^"../Elliot"

var _shown: bool = false


func _ready() -> void:
	var enemy := get_node_or_null(enemy_path)
	if enemy != null and enemy.get("health") != null:
		enemy.health.died.connect(_on_enemy_died)


func _entries(texts: Array[String]) -> Array:
	var entries: Array = []
	for line in texts:
		entries.append({"text": line, "speaker": "", "portrait": null})
	return entries


func _on_enemy_died() -> void:
	if _shown or (lines.is_empty() and potion_texture == null):
		return
	_shown = true
	var enemy := get_node_or_null(enemy_path) as Node2D
	var drop: Vector2 = enemy.ground_position() if enemy != null and enemy.has_method("ground_position") else Vector2.INF
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	if not lines.is_empty():
		await _say(lines)
	if potion_texture != null and is_inside_tree():
		await _potion(drop)


# Muestra una conversación y espera a que termine (si hay otra abierta, espera su turno).
func _say(texts: Array[String]) -> void:
	while not DialogueManager.can_start_dialogue():
		if not is_inside_tree():
			return
		await get_tree().process_frame
	if not is_inside_tree():
		return
	DialogueManager.show_conversation(_entries(texts))
	await DialogueManager.dialogue_finished


func _potion(drop: Vector2) -> void:
	var drinker := get_node_or_null(drinker_path) as Node2D
	if drinker == null or not drinker.has_method("drink_potion"):
		return
	# La poción aparece en el suelo, junto a donde cayó el enemigo (o junto a Elliot), con un brillo suave.
	var spot: Vector2 = drop if drop != Vector2.INF else drinker.ground_position() + Vector2(90, 0)
	spot.x = clampf(spot.x, drinker.ground_position().x - 220.0, drinker.ground_position().x + 220.0)
	spot.y = drinker.ground_position().y
	var bottle := Sprite2D.new()
	bottle.texture = potion_texture
	bottle.scale = Vector2.ONE * (52.0 / maxf(maxf(potion_texture.get_width(), potion_texture.get_height()), 1.0))
	bottle.z_index = 1
	bottle.global_position = spot + Vector2(0, -40)
	bottle.modulate.a = 0.0
	get_parent().add_child(bottle)
	var appear := bottle.create_tween()
	appear.tween_property(bottle, "modulate:a", 1.0, 0.3)
	var bob := bottle.create_tween().set_loops()
	bob.tween_property(bottle, "position:y", bottle.position.y - 10.0, 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(bottle, "position:y", bottle.position.y, 0.5).set_trans(Tween.TRANS_SINE)
	AudioLandscape.cue(&"clue", spot)
	# Mientras la comentan y la bebe, nadie se mueve.
	var locked: Array = []
	for actor in get_tree().get_nodes_in_group("player"):
		if "input_locked" in actor:
			actor.input_locked = true
			locked.append(actor)
	if not potion_lines.is_empty():
		await _say(potion_lines)
	if not is_inside_tree() or not is_instance_valid(drinker) or not drinker.is_inside_tree():
		_unlock(locked)
		return
	# Elliot mira hacia la poción y la bebe.
	if "facing" in drinker:
		drinker.facing = Vector2.LEFT if spot.x < drinker.ground_position().x else Vector2.RIGHT
	bob.kill()
	bottle.queue_free()
	drinker.drink_potion(potion_texture)
	await drinker.drink_finished
	if not is_inside_tree() or not is_instance_valid(drinker):
		_unlock(locked)
		return
	var health: Node = drinker.get("health")
	if health != null and health.has_method("heal"):
		health.heal(heal_amount)
		var fx: Node = get_node_or_null("/root/CombatFX")
		if fx != null and fx.has_method("hit_impact"):
			fx.hit_impact(drinker.ground_position() + Vector2(0, -160), 0.4)
	_unlock(locked)


func _unlock(locked: Array) -> void:
	for actor in locked:
		if is_instance_valid(actor):
			actor.input_locked = false
