extends SceneTree
var failures: int = 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path="/private/tmp/palim-preferences-tests.cfg"
	var level=load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	for actor in level.get_children():
		if actor is CharacterBody2D:actor.set_physics_process(false)
	var p=level.get_node("Elliot")
	var e=level.get_node("RangerWood")
	p.facing=Vector2.RIGHT
	# Cadena retenida incluso si la preparación/animación consume más de la ventana.
	p._do_hit("attack")
	p.anim.pause()
	p._physics_process(0.8)
	check(p.combo_step==1,"Combo caduca durante ataque")
	p.buffered_action="kick"
	p._end_attack()
	check(p.is_attacking and p.combo_step==2 and p.active_hit_action==&"kick","Buffer no encadena patada")
	p.buffered_action="attack"
	p._end_attack()
	check(p.active_hit_finisher and p.active_hit_damage==p.punch_damage+p.combo_damage_bonus,"Finisher incorrecto")
	p._end_attack()
	check(not p.is_attacking and p.hitbox_shape.disabled,"Finisher no recupera")
	p.combo_step=1
	p.combo_timer=p.combo_window
	p._physics_process(p.combo_window+0.1)
	check(p.combo_step==0,"Cadena no caduca en reposo")
	# Un finisher durante windup cancela el ataque y no revive su ventana antigua.
	e._attack()
	await create_timer(0.05).timeout
	e.receive_combat_hit(1,e.ground_position()-Vector2(50,150),true)
	check(not e.is_attacking and e.knockback.y==0,"Finisher no interrumpe sobre suelo")
	await create_timer(0.45).timeout
	check(e.hitbox_shape.disabled and not e.is_attacking and e.can_attack,"Await antiguo reactiva ataque")
	# Ataque viejo y muerte: ninguna reactivación posterior.
	e._attack()
	await create_timer(0.05).timeout
	e.take_damage(10000)
	await create_timer(0.45).timeout
	check(e._dead and e.hitbox_shape.disabled,"Muerte reactiva contacto")
	var fx=root.get_node("CombatFX")
	Engine.time_scale=0.8
	fx.hit_impact(p.ground_position()-Vector2(0,130),1.8,Vector2.RIGHT)
	await create_timer(0.15,false,false,true).timeout
	check(is_equal_approx(Engine.time_scale,0.8),"Hit-stop no restaura escala anterior")
	Engine.time_scale=1.0
	level.queue_free()
	await process_frame
	print("COMBAT_CADENCE failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
