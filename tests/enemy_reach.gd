extends SceneTree
# Alcance real de golpes: para cada enemigo de cada capítulo, Elliot ataca desde
# la izquierda y desde la derecha, con física activa, y se comprueba que la vida baje.
# Un enemigo que no recibe golpe desde algún lado es un fallo (se ve en el log).
const SCENES := [
	"res://scenes/levels/cuento1_escena1.tscn",
	"res://scenes/levels/cuento1_escena2.tscn",
	"res://scenes/levels/cuento1_escena3.tscn",
	"res://scenes/levels/cuento1_escena4.tscn",
]
const GAP := 95.0          # distancia entre el pie de Elliot y el del enemigo (px)
var failures: int = 0
var checked: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		push_error(message)

func _band_y(path: Node, x: float) -> float:
	var top: float = path._height_at(path.upper_edge, x) + 26.0
	var bottom: float = path._height_at(path.lower_edge, x) - 26.0
	return (top + bottom) * 0.5

func _place_foot(actor: Node2D, foot: Vector2) -> void:
	actor.global_position += foot - actor.ground_position()

func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = "/tmp/enemy-reach-prefs.cfg"
	for scene_path in SCENES:
		var level = load(scene_path).instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		var path: Node = level.get_node_or_null("WalkablePath")
		var enemies: Array = []
		for child in level.get_children():
			if child.is_in_group("enemy") and child is Node2D:
				enemies.append(child)
		var elliot = level.get_node("Elliot")
		for enemy in enemies:
			for other in level.get_children():
				if other is CharacterBody2D and other != elliot:
					other.set_physics_process(false)
			for side in [-1.0, 1.0]:
				if path == null:
					break
				var foot_x: float = enemy.ground_position().x
				var foot_y: float = _band_y(path, foot_x)
				enemy.health.current_health = enemy.health.max_health
				_place_foot(enemy, Vector2(foot_x, foot_y))
				# side -1: Elliot a la izquierda (mira a la derecha); side 1: a la derecha.
				var stand := Vector2(enemy.ground_position().x - GAP * side * -1.0, foot_y)
				_place_foot(elliot, stand)
				# _do_hit toma la dirección de 'facing' (no de anim.flip_h): se fija aquí.
				elliot.facing = Vector2.LEFT if side > 0.0 else Vector2.RIGHT
				elliot.anim.flip_h = side > 0.0
				elliot.velocity = Vector2.ZERO
				elliot._locomotion = Vector2.ZERO
				var before: int = enemy.health.current_health
				elliot._do_hit("attack")
				await create_timer(1.6).timeout
				var dealt: int = before - enemy.health.current_health
				var label := "izquierda" if side < 0.0 else "derecha"
				print("REACH %s %s desde_%s dano=%d" % [level.name, enemy.name, label, dealt])
				check(dealt > 0, "Sin golpe: %s / %s / desde %s" % [level.name, enemy.name, label])
		level.queue_free()
		await process_frame
	print("ENEMY_REACH checked=%d failures=%d" % [checked, failures])
	quit(1 if failures > 0 else 0)
