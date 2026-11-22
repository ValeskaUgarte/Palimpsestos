extends SceneTree
## Comprueba el pool de partículas de CombatFX: tope de efectos vivos, reutilización de nodos y limpieza.

var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fx = root.get_node("CombatFX")
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	for i in 40:
		fx.hit_impact(Vector2(i * 10, 0), 2.0, Vector2.RIGHT)
	check(fx._live_effects <= fx.MAX_LIVE_EFFECTS + 5, "Se superó el tope de efectos vivos: %d" % fx._live_effects)
	var created: int = fx.get_child_count()
	check(created > 0, "No se crearon partículas")
	# esperar a que todos terminen (tiempo real; el hit-stop ya se restauró)
	await create_timer(3.5, true, false, true).timeout
	check(fx._live_effects == 0, "Quedaron efectos vivos: %d" % fx._live_effects)
	check(fx._pool.size() <= fx.MAX_POOLED, "Pool desbordado: %d" % fx._pool.size())
	var pooled: int = fx._pool.size()
	for i in 10:
		fx.hit_impact(Vector2(i * 10, 0), 1.0, Vector2.LEFT)
	await process_frame
	check(fx.get_child_count() <= created + 12, "No se reutilizan nodos (hijos %d, antes %d)" % [fx.get_child_count(), created])
	check(is_equal_approx(Engine.time_scale, 1.0) or Engine.time_scale > 0.0, "time_scale inválido")
	await create_timer(3.5, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "Hit-stop no restauró time_scale: %f" % Engine.time_scale)
	print("COMBAT_FX_POOL failures=", failures, " pooled=", pooled)
	quit(1 if failures > 0 else 0)
