extends SceneTree
# Presentación de los compañeros (Jhon, Thomas). Invariantes reales del arte actual (celdas de 256 px ajustadas en
# ejecución por Player._fit_pose / SpriteFit):
#  - los pies de cada fotograma de locomoción (idle/walk/...) quedan en la línea de suelo del actor, y en los clips
#    de acción (ataque, salto, daño) lo hace la mediana de los fotogramas (los de estocada/salto pueden despegar);
#  - la altura visible de cada animación se parece a la del reposo (sin saltos de tamaño al cambiar de clip).
# (El formato antiguo 'aligned_companion' de celdas de 800 px ya no existe.)

const FOOT_TOLERANCE := 5.0        # px de pantalla, animaciones de locomoción (el apoyo medido vs. el guardado)
const COMBAT_FOOT_MEDIAN := 12.0   # px, clips de acción: algunos fotogramas son saltos/estocadas con los pies en el aire
const LOCOMOTION := [&"idle", &"walk", &"run", &"talk", &"interact"]
const HEIGHT_TOLERANCE := 0.30     # fracción; los ataques levantan brazos/arma y pueden ser algo más altos

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func _visible_height(actor, animation: StringName, frame: int) -> float:
	actor.anim.animation = animation
	actor.anim.frame = frame
	actor._fit_pose()
	var m: Dictionary = SpriteFit.metrics(actor.anim.sprite_frames.get_frame_texture(animation, frame))
	if m.is_empty():
		return 0.0
	return float(int(m["bottom"]) - int(m["top"])) * absf(actor.anim.scale.y)

func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path=OS.get_temp_dir().path_join("palim-preferences-tests.cfg")
	for character in ["Jhon", "Thomas"]:
		var actor = load("res://scenes/characters/player/" + character + ".tscn").instantiate()
		actor.is_companion = true
		root.add_child(actor)
		actor.set_physics_process(false)
		var frames: SpriteFrames = actor.anim.sprite_frames
		var idle_height: float = _visible_height(actor, &"idle", 0)
		if idle_height <= 0.0:
			failures += 1
			push_error(character + ": idle sin dibujo visible")
		for animation in frames.get_animation_names():
			if frames.get_frame_count(animation) == 0:
				continue
			var first_height: float = _visible_height(actor, animation, 0)
			if animation != &"jump" and idle_height > 0.0 and absf(first_height / idle_height - 1.0) > HEIGHT_TOLERANCE:
				failures += 1
				push_error("%s: altura de '%s' = %.0f vs reposo %.0f" % [character, animation, first_height, idle_height])
			var errors: Array[float] = []
			for frame in frames.get_frame_count(animation):
				_visible_height(actor, animation, frame)   # deja el sprite ajustado a este fotograma
				var m: Dictionary = SpriteFit.metrics(frames.get_frame_texture(animation, frame))
				if m.is_empty():
					continue
				var drawn_foot: float = actor.anim.global_position.y + (float(m["bottom"]) - float(m["h"]) * 0.5) * actor.anim.scale.y
				var error: float = drawn_foot - actor.ground_position().y
				errors.append(absf(error))
				if animation in LOCOMOTION and absf(error) > FOOT_TOLERANCE:
					failures += 1
					push_error("%s: pies desplazados en %s[%d] (%.1f)" % [character, animation, frame, error])
			if not errors.is_empty() and not animation in LOCOMOTION:
				errors.sort()
				if errors[errors.size() / 2] > COMBAT_FOOT_MEDIAN:
					failures += 1
					push_error("%s: pies desplazados en la mediana de %s (%.1f)" % [character, animation, errors[errors.size() / 2]])
		actor.queue_free()
		await process_frame
	print("COMPANION_PRESENTATION failures=", failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
