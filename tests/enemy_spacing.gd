extends SceneTree
## Enemigos de los niveles: ninguno a menos de 800 px (en X) de un PNJ de la historia, no queda ningún lobo bípedo
## (WolfPunch) y el total por escena se mantiene bajo (los jefes y guardianes siguen en su sitio).
const SCENES := [
	"res://scenes/levels/cuento1_escena1.tscn",
	"res://scenes/levels/cuento1_escena2.tscn",
	"res://scenes/levels/cuento1_escena3.tscn",
	"res://scenes/levels/cuento1_escena4.tscn",
]
## Máximo de enemigos por escena (antes: 18, 31, 22, 0).
const MAX_ENEMIES := [11, 16, 11, 0]
const NPC_RADIUS := 800.0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-spacing-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	for index in SCENES.size():
		var level = load(SCENES[index]).instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		var npcs: Array = []
		var enemies: Array = []
		for child in level.get_children():
			var scripted: bool = child is Area2D and child.get_script() != null and String(child.get_script().resource_path).ends_with("characters/npc.gd")
			if scripted or String(child.name).begins_with("NPC_") or (child is Area2D and child.get_node_or_null("Motion") != null):
				npcs.append(child)
			elif child.is_in_group("enemy"):
				enemies.append(child)
		for enemy in enemies:
			check(not String(enemy.scene_file_path).ends_with("WolfPunch.tscn") and not String(enemy.name).contains("Punch"), "%s: queda un lobo bípedo (%s)" % [level.name, enemy.name])
			for npc in npcs:
				var distance: float = absf((enemy as Node2D).global_position.x - (npc as Node2D).global_position.x)
				check(distance >= NPC_RADIUS, "%s: el enemigo %s está a %.0f px del PNJ %s" % [level.name, enemy.name, distance, npc.name])
		check(enemies.size() <= MAX_ENEMIES[index], "%s: demasiados enemigos (%d)" % [level.name, enemies.size()])
		print("ENEMIES ", level.name, " count=", enemies.size(), " npcs=", npcs.size())
		level.queue_free()
		await process_frame
	print("ENEMY_SPACING failures=", failures)
	quit(1 if failures else 0)
