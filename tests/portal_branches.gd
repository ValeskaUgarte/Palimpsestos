extends SceneTree
var failures: int = 0
func _initialize():call_deferred("run")
func check(value: bool, message: String):
	if not value:failures+=1;push_error(message)
func run():
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path=OS.get_temp_dir().path_join("palim-branches.cfg")
	root.get_node("AudioLandscape").shutdown()
	var flow=root.get_node("LateralStory")
	flow.enabled=false;flow.chapter=0;flow.realm="normal";flow.return_x=1800;flow.resolved=["guardian_0","runes_0"];flow.party_health={};flow.completed=false;flow.encounter_id=""
	var scene=load(flow.world_scene()).instantiate();root.add_child(scene);current_scene=scene;scene.set_process(false)
	check(scene._side_marker.position.x>1900,"Portal rojo sigue al comienzo")
	check(scene._exit_marker.position.x>1900,"Portal azul fuera de final")
	scene._refresh_world_markers()
	await create_timer(.7).timeout
	check(scene._side_marker.visible and scene._side_marker.scale.is_equal_approx(Vector2.ONE),"Falla aparición animada")
	scene.actor.position.x=2200
	var event := InputEventAction.new()
	event.action="interact";event.pressed=true
	scene._input(event)
	await create_timer(1.2,true,false,true).timeout
	check(flow.chapter==1 and flow.realm=="underworld" and current_scene.scene_file_path.ends_with("inframundo2.tscn"),"Rojo no lleva a inframundo 2")
	var inferno=current_scene;inferno.set_process(false)
	check(get_nodes_in_group("enemy").size()>=3,"Faltan enemigos extra")
	check(inferno.opponent==null,"Se inventó boss diferente")
	flow.resolved.append("guardian_1")
	for enemy in get_nodes_in_group("enemy"):enemy._dead=true;enemy.set_physics_process(false)
	inferno._cross_page("normal")
	await create_timer(1.2,true,false,true).timeout
	check(flow.chapter==2 and flow.realm=="normal" and current_scene.scene_file_path==flow.world_scene(),"No puede regresar al camino normal")
	flow.realm="underworld"
	check(flow.world_scene().ends_with("inframundo3.tscn"),"No existe inframundo 3")
	check(flow.encounter().enemy_scene.ends_with("Lobo.tscn"),"El boss no es común")
	print("PORTAL_BRANCHES failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
