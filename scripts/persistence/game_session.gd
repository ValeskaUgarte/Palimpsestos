extends Node

const VERSION: int = 1
const LEVELS = ["res://scenes/levels/cuento1_escena1.tscn","res://scenes/levels/cuento1_escena2.tscn","res://scenes/levels/cuento1_escena3.tscn","res://scenes/levels/cuento1_escena4.tscn"]
## ESCENAS JUGABLES DEL CUENTO I. Las 4 escenas originales se dividen en tramos (9 en total).
## Cada tramo es una escena para el mapa, el menú de jugadas guardadas y la demo:
##   level: archivo de la escena original donde está el tramo.
##   from / to: límites en X del mundo (la cámara y las paredes de Elliot se ajustan a ellos).
##   start: X donde aparece Elliot al empezar el tramo (en los tramos que no son el primero de su escena queda a 260 px
##          del borde izquierdo: así los compañeros caben detrás de él, dentro de las paredes del tramo).
##   title / sub: título y subtítulo que se muestran al entrar.
##   mark: posición (0 a 1) del punto de la escena sobre el camino del mapa.
## Para cambiar un corte, edita from/to aquí. Los enemigos, PNJ y pistas fuera del tramo se ocultan y se desactivan.
const PARTS := [
	{"level": "res://scenes/levels/cuento1_escena1.tscn", "from": -1000.0, "to": 6000.0, "start": -265.0, "title": "El bosque antiguo", "sub": "En el margen de un cuento conocido.", "mark": 0.05},
	{"level": "res://scenes/levels/cuento1_escena1.tscn", "from": 6000.0, "to": 13000.0, "start": 6260.0, "title": "El camino de los lobos", "sub": "Cada paso deja una huella.", "mark": 0.1767},
	{"level": "res://scenes/levels/cuento1_escena1.tscn", "from": 13000.0, "to": 19456.0, "start": 13260.0, "title": "Las runas del monolito", "sub": "Solo el orden abre el camino.", "mark": 0.3033},
	{"level": "res://scenes/levels/cuento1_escena2.tscn", "from": 0.0, "to": 4800.0, "start": 500.0, "title": "Dos caminos", "sub": "Donde la piedra guarda memoria.", "mark": 0.38},
	{"level": "res://scenes/levels/cuento1_escena2.tscn", "from": 4800.0, "to": 9000.0, "start": 5060.0, "title": "El rastro de las flores", "sub": "Huellas que no son de nadie.", "mark": 0.5},
	{"level": "res://scenes/levels/cuento1_escena2.tscn", "from": 9000.0, "to": 13200.0, "start": 9260.0, "title": "La casa de la abuelita", "sub": "Nada es lo que parece.", "mark": 0.62},
	{"level": "res://scenes/levels/cuento1_escena3.tscn", "from": -150.0, "to": 6100.0, "start": 450.0, "title": "Las historias olvidadas", "sub": "No todo lo escrito permanece.", "mark": 0.71},
	{"level": "res://scenes/levels/cuento1_escena3.tscn", "from": 6100.0, "to": 12200.0, "start": 6360.0, "title": "El claro del lobo", "sub": "Ya no hay camino de vuelta.", "mark": 0.825},
	{"level": "res://scenes/levels/cuento1_escena4.tscn", "from": -100.0, "to": 2490.0, "start": 289.0, "title": "Lo que quedó en la mesa", "sub": "Nadie preguntó de qué estaba hecha la cena.", "mark": 0.94},
]
## true = todas las escenas están abiertas para saltar a cualquiera desde el mapa o desde Jugadas guardadas (demo).
const OPEN_ALL_PARTS: bool = true
## Escena jugable (índice en PARTS) que se está jugando ahora. -1 = escena completa, sin cortes.
var current_part: int = -1
var save_path: String = "user://chapter-save.json"
var enabled: bool = true
var resume_requested: bool = false
var _data: Dictionary = {}
var _defeated: Dictionary = {}
var _save_elapsed: float = 0.0
var _last_checkpoint: Vector2 = Vector2.INF
var last_error: Error = OK
var _quitting: bool = false
## Energía que se lleva el grupo al pasar de una escena a la siguiente: {nombre del personaje: vida}.
## Se llena al cruzar la salida (capture_party_health) y se aplica al entrar al nivel siguiente.
var _carry_health: Dictionary = {}
## Progreso global (no depende del punto exacto de la partida): escenas alcanzadas y acertijos resueltos.
## Se guarda en user://progreso.json. Sirve para entrar directamente a cualquier escena ya alcanzada.
const PROGRESS_PATH: String = "user://progreso.json"
## Ruta efectiva del progreso (las pruebas la redirigen a un temporal).
var progress_path: String = PROGRESS_PATH
var progress: Dictionary = {"reached": 0, "flags": {}, "items": {}, "seen": {}}
## X de aparición forzada al cambiar de tramo (p. ej. al volver atrás por la izquierda). INF = usar el "start" del tramo.
var part_start_override: float = INF
## Sentido en que llega el grupo al tramo: 1 = avanzando (compañeros detrás, a la izquierda), -1 = volviendo atrás.
var part_arrival_dir: float = 1.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	load_progress()
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(quit_game)

func _process(delta: float) -> void:
	if get_tree().paused or not enabled:return
	_save_elapsed+=delta
	if _save_elapsed<4:return
	_save_elapsed=0
	var level=get_tree().current_scene
	if level==null or not level.scene_file_path in LEVELS:return
	var player=level.get_node_or_null("Elliot")
	if player==null or player.health.current_health<=0 or player.is_attacking or player.is_jumping or DialogueManager.visible:return
	if _last_checkpoint!=Vector2.INF and player.ground_position().distance_to(_last_checkpoint)<600:return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.ground_position().distance_to(player.ground_position())<500:return
	checkpoint(level)

func record_defeat(level_path: String,actor_name: String) -> void:
	var names: Array=_defeated.get(level_path,[])
	if not actor_name in names:names.append(actor_name)
	_defeated[level_path]=names

func checkpoint(level: Node) -> Error:
	if not enabled:return OK
	if not level.scene_file_path in LEVELS:return ERR_INVALID_PARAMETER
	var player=level.get_node_or_null("Elliot")
	if player==null or player.health.current_health<=0:return ERR_INVALID_DATA
	var flags: Array=[]
	for node in get_tree().get_nodes_in_group("narrative_trigger"):
		if level.is_ancestor_of(node) and node._triggered:flags.append(String(level.get_path_to(node)))
	var party: Dictionary={}
	for actor in get_tree().get_nodes_in_group("party_actor"):
		if level.is_ancestor_of(actor):party[String(actor.name)]=actor.health.current_health
	var enemies: Dictionary={}
	for actor in get_tree().get_nodes_in_group("enemy"):
		if level.is_ancestor_of(actor):enemies[String(actor.name)]=actor.health.current_health
	var point: Vector2=player.ground_position()
	var puzzle=level.get_node_or_null("Monolito")
	_data={"version":VERSION,"level":level.scene_file_path,"part":part_for_scene(level),"foot":[point.x,point.y],"health":player.health.current_health,"defeated":_defeated,"flags":flags,"puzzle":puzzle!=null and puzzle._solved,"completed":false,"party":party,"enemies":enemies}
	_last_checkpoint=point
	return _write()

func _write() -> Error:
	var temporary: String=save_path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:
		last_error=FileAccess.get_open_error();return last_error
	file.store_string(JSON.stringify(_data));file.flush();file.close()
	if FileAccess.file_exists(save_path):
		var backup_error:=DirAccess.copy_absolute(save_path,save_path+".bak")
		if backup_error!=OK:last_error=backup_error;return last_error
	last_error=DirAccess.rename_absolute(temporary,save_path)
	return last_error

func read_save() -> bool:
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path):continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path))!=OK:continue
		var parsed=json.data
		if not parsed is Dictionary:continue
		if parsed.get("version",0)!=VERSION or not parsed.get("level","") in LEVELS:continue
		var point=parsed.get("foot",[])
		if not point is Array or point.size()!=2:continue
		if not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int):continue
		if not is_finite(float(point[0])) or not is_finite(float(point[1])):continue
		if not parsed.get("defeated",{}) is Dictionary or not parsed.get("flags",[]) is Array:continue
		var valid := true
		var saved_health=parsed.get("health",0)
		if not (saved_health is int or saved_health is float):continue
		if not is_finite(float(saved_health)) or float(saved_health)<=0:continue
		for level_path in parsed.get("defeated",{}):
			if not level_path in LEVELS or not parsed.defeated[level_path] is Array:
				valid=false;break
			for name in parsed.defeated[level_path]:
				if not name is String:valid=false;break
		for field in ["party","enemies"]:
			var actors=parsed.get(field,{})
			if not actors is Dictionary:valid=false;break
			for actor_name in actors:
				var hp=actors[actor_name]
				if not actor_name is String or not (hp is int or hp is float):valid=false;break
				if not is_finite(float(hp)) or float(hp)<0:valid=false;break
		for flag in parsed.get("flags",[]):
			if not flag is String:valid=false;break
		if not valid:continue
		_data=parsed;_defeated=parsed.get("defeated",{}).duplicate(true)
		return true
	return false

func continue_game() -> bool:
	if not read_save():return false
	if bool(_data.get("completed",false)):
		resume_requested=false
		current_part=-1
		ScenePages.travel("res://scenes/levels/chapter_end.tscn")
		return true
	resume_requested=true
	_carry_health.clear()  # la vida viene del guardado, no de la escena anterior
	current_part=_saved_part()
	ScenePages.travel(_data.level)
	return true

func new_game() -> void:
	_data.clear();_defeated.clear();_carry_health.clear();resume_requested=false;_last_checkpoint=Vector2.INF
	var status := get_node_or_null("/root/PlayerStatus")
	if status != null and status.has_method("reset"):status.reset()
	reset_progress()
	current_part=0
	ScenePages.travel(PARTS[0].level)

## Guarda la vida actual de Elliot y de sus compañeros para que NO se restablezca en la escena siguiente.
func capture_party_health(level: Node) -> void:
	_carry_health.clear()
	var player=level.get_node_or_null("Elliot")
	if player!=null and player.health.current_health>0:_carry_health["Elliot"]=player.health.current_health
	for actor in get_tree().get_nodes_in_group("party_actor"):
		if level.is_ancestor_of(actor) and actor.health.current_health>0:_carry_health[String(actor.name)]=actor.health.current_health

## Aplica la vida guardada al entrar a una escena nueva (cada personaje, por su nombre) y la olvida.
func _apply_carried_health(level: Node) -> void:
	if _carry_health.is_empty():return
	for actor_name in _carry_health:
		var actor=level.get_node_or_null(NodePath(String(actor_name)))
		if actor==null or not level.is_ancestor_of(actor) or actor.get("health")==null:continue
		actor.health.current_health=clampi(int(_carry_health[actor_name]),1,actor.health.max_health)
		actor.health.health_changed.emit(actor.health.current_health,actor.health.max_health)
	_carry_health.clear()

func enter_level(level: Node) -> void:
	var path: String=level.scene_file_path
	if not path in LEVELS:return
	if resume_requested and _data.get("level","")==path:
		resume_requested=false
		var player=level.get_node("Elliot")
		var point:=Vector2(float(_data.foot[0]),float(_data.foot[1]))
		var part:=part_for_scene(level)
		if part>=0:point.x=clampf(point.x,float(PARTS[part].from)+20.0,float(PARTS[part].to)-20.0)
		point=level.get_node("WalkablePath").constrain_foot(point,26)
		player.global_position+=point-player.ground_position()
		player.health.current_health=clampi(int(_data.get("health",1000)),1,player.health.max_health)
		player.health.health_changed.emit(player.health.current_health,player.health.max_health)
		for enemy_name in _defeated.get(path,[]):
			var actor=level.get_node_or_null(NodePath(String(enemy_name)))
			if actor and level.is_ancestor_of(actor) and actor.is_in_group("enemy"):
				actor.health.current_health=0;actor._dead=true
				actor.remove_from_group("enemy");actor.queue_free()
		for field in ["party","enemies"]:
			for actor_name in _data.get(field,{}):
				var actor=level.get_node_or_null(NodePath(String(actor_name)))
				if actor and level.is_ancestor_of(actor) and (actor.is_in_group("party_actor") if field=="party" else actor.is_in_group("enemy")):
					actor.health.current_health=clampi(int(_data[field][actor_name]),0,actor.health.max_health)
					actor.health.health_changed.emit(actor.health.current_health,actor.health.max_health)
					if actor.health.current_health==0:actor._on_died()
		for name in _data.get("flags",[]):
			var trigger=level.get_node_or_null(NodePath(String(name)))
			if trigger and level.is_ancestor_of(trigger) and trigger.is_in_group("narrative_trigger"):trigger._triggered=true
		var puzzle=level.get_node_or_null("Monolito")
		if puzzle and bool(_data.get("puzzle",false)):
			puzzle._solved=true
			for rune in puzzle.runes:rune.set_accepted(true)
			puzzle.get_node("DebugLabel").text="Camino abierto"
			puzzle._open_gate()
			level.get_node("StoryPortal").activate()
		var walk_path=level.get_node_or_null("WalkablePath")
		var spot:=0
		for ally in get_tree().get_nodes_in_group("companion"):
			if not level.is_ancestor_of(ally):continue
			var wanted:Vector2=player.ground_position()+ally.companion_follow_offset+Vector2(-45.0*spot,0.0)
			if part>=0:wanted.x=clampf(wanted.x,float(PARTS[part].from)+50.0,float(PARTS[part].to)-50.0)
			if walk_path!=null:wanted=walk_path.constrain_foot(wanted,26)
			ally.global_position+=wanted-ally.ground_position()
			spot+=1
		player.get_node("Camera2D").reset_smoothing()
	else:_apply_carried_health(level)
	_last_checkpoint=level.get_node("Elliot").ground_position()
	if enabled:checkpoint(level)

func complete_chapter() -> void:
	# Terminar el cuento I (Caperucita) desbloquea el cuento II en el mapa de cuentos.
	set_flag("cuento_1_completo")
	if _data.is_empty():return
	_data.completed=true
	progress["reached"] = PARTS.size() - 1
	if enabled:_write()

func quit_game(exit_code: int = 0) -> void:
	if _quitting:return
	_quitting=true
	var level=get_tree().current_scene
	if level and level.scene_file_path in LEVELS:checkpoint(level)
	GamePreferences.save()
	get_tree().paused=true
	AudioLandscape.shutdown()
	# Dos o más buffers de audio antes de cerrar el motor: libera playbacks WAV
	# también en cambios de nivel rápidos y en el backend headless de pruebas.
	await get_tree().create_timer(0.12,true,false,true).timeout
	get_tree().quit(exit_code)


# ---------------------------------------------------------------------------------------------
# PROGRESO GLOBAL: escenas alcanzadas y acertijos resueltos (entrar directamente a una escena)
# ---------------------------------------------------------------------------------------------
func load_progress() -> void:
	if not FileAccess.file_exists(progress_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if not parsed is Dictionary:
		return
	var version: int = int(parsed.get("version", 1))
	var flags = parsed.get("flags", {})
	if flags is Dictionary:
		progress["flags"] = flags
	var items = parsed.get("items", {})
	if items is Dictionary:
		progress["items"] = items
	# Estado del personaje (cansancio, miedo, sellos) y avance sobre el mapa del cuento.
	var status = parsed.get("status", {})
	if status is Dictionary:
		progress["status"] = status
	var seen = parsed.get("seen", {})
	if seen is Dictionary:
		progress["seen"] = seen
	if version >= 2:
		progress["reached"] = clampi(int(parsed.get("reached", 0)), 0, PARTS.size() - 1)
		var route = parsed.get("route", [])
		if route is Array:
			progress["route"] = route
	else:
		# Progreso anterior (4 escenas): se pasa a las escenas jugables nuevas.
		var old_scene: int = clampi(int(parsed.get("reached", 0)), 0, LEVELS.size() - 1)
		progress["reached"] = first_part_of(LEVELS[old_scene])
		var old_route = parsed.get("route", [])
		var route: Array = []
		route.resize(PARTS.size())
		route.fill(0.0)
		for scene_index in LEVELS.size():
			var fraction: float = float(old_route[scene_index]) if old_route is Array and scene_index < old_route.size() else 0.0
			var first: int = first_part_of(LEVELS[scene_index])
			var count: int = parts_of(LEVELS[scene_index]).size()
			for offset in count:
				route[first + offset] = clampf(fraction * count - offset, 0.0, 1.0)
		progress["route"] = route


func save_progress() -> void:
	var file := FileAccess.open(progress_path, FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		return
	var data: Dictionary = progress.duplicate()
	data["version"] = 2
	file.store_string(JSON.stringify(data))
	file.close()


func reset_progress() -> void:
	progress = {"reached": 0, "flags": {}, "items": {}, "status": {}, "route": [], "seen": {}}
	part_start_override = INF
	part_arrival_dir = 1.0
	save_progress()


## Se llama al entrar a una escena jugable: anota hasta qué escena llegó el jugador (solo sube).
func mark_reached_part(index: int) -> void:
	if index < 0 or index >= PARTS.size() or index <= reached_index():
		return
	progress["reached"] = index
	save_progress()


func reached_index() -> int:
	return int(progress.get("reached", 0))


## Escenas jugables de un archivo de nivel (en orden), y la primera de ellas (-1 si no es del cuento).
func parts_of(level_path: String) -> Array:
	var result: Array = []
	for index in PARTS.size():
		if PARTS[index].level == level_path:
			result.append(index)
	return result


func first_part_of(level_path: String) -> int:
	var parts := parts_of(level_path)
	return parts[0] if not parts.is_empty() else -1


## Escena jugable que se está viendo en este nivel (-1 si el nivel se carga completo).
func part_for_scene(scene: Node) -> int:
	if scene == null or current_part < 0 or current_part >= PARTS.size():
		return -1
	if PARTS[current_part].level != scene.scene_file_path:
		return -1
	return current_part


## Escena jugable de un guardado antiguo (sin dato de escena): la que contiene la posición de Elliot.
func _saved_part() -> int:
	var level_path: String = _data.get("level", "")
	var saved = _data.get("part", -1)
	if (saved is int or saved is float) and int(saved) >= 0 and int(saved) < PARTS.size() and PARTS[int(saved)].level == level_path:
		return int(saved)
	var parts := parts_of(level_path)
	if parts.is_empty():
		return -1
	var foot: Array = _data.get("foot", [0.0, 0.0])
	var x: float = float(foot[0]) if foot.size() > 0 else 0.0
	for index in parts:
		if x >= float(PARTS[index].from) and x <= float(PARTS[index].to):
			return index
	return parts[0]


## Entra a una escena jugable desde el mapa o desde Jugadas guardadas (empieza en su inicio).
func enter_part(index: int) -> void:
	if index < 0 or index >= PARTS.size():
		return
	if not OPEN_ALL_PARTS and index > reached_index():
		return
	resume_requested = false
	current_part = index
	ScenePages.travel(PARTS[index].level)


## CUENTOS DEL MAPA: el primero (Caperucita) siempre está abierto; cada uno de los demás se abre al terminar el anterior
## (flag "cuento_N_completo", que se marca al llegar al final de ese cuento).
func story_unlocked(number: int) -> bool:
	return number <= 1 or has_flag("cuento_%d_completo" % (number - 1))


## Marca un acertijo o hito como hecho (se guarda al momento).
func set_flag(key: String) -> void:
	progress["flags"][key] = true
	save_progress()


func has_flag(key: String) -> bool:
	return bool(progress["flags"].get(key, false))


## DIÁLOGOS AUTOMÁTICOS YA VISTOS (no se repiten al recargar el tramo ni al continuar la partida).
## La clave es: ruta de la escena + nombre del nodo + hash del texto (ver dialogue_key).
static func dialogue_key(scene_path: String, node_name: String, text: String) -> String:
	return "%s|%s|%s" % [scene_path, node_name, text.sha256_text().substr(0, 16)]


## Ruta del nivel (de LEVELS) al que pertenece un nodo, o "" si no está dentro de un nivel del cuento.
static func level_path_of(node: Node) -> String:
	var current: Node = node
	while current != null:
		if current.scene_file_path in LEVELS:
			return current.scene_file_path
		current = current.get_parent()
	return ""


func dialogue_seen(key: String) -> bool:
	return progress.get("seen", {}).has(key)


func mark_dialogue_seen(key: String) -> void:
	if not enabled:
		return
	if not progress.has("seen") or not progress["seen"] is Dictionary:
		progress["seen"] = {}
	if progress["seen"].has(key):
		return
	progress["seen"][key] = true
	save_progress()


## MOCHILA: objetos del cuento con su cantidad (se guardan con el progreso).
func add_item(id: String, amount: int = 1) -> void:
	var items: Dictionary = progress["items"]
	items[id] = int(items.get(id, 0)) + amount
	save_progress()


func remove_item(id: String, amount: int = 1) -> void:
	var items: Dictionary = progress["items"]
	var left := int(items.get(id, 0)) - amount
	if left > 0:
		items[id] = left
	else:
		items.erase(id)
	save_progress()


func item_count(id: String) -> int:
	return int(progress["items"].get(id, 0))


func item_ids() -> Array:
	var ids: Array = []
	for id in progress["items"]:
		if int(progress["items"][id]) > 0:
			ids.append(id)
	ids.sort()
	return ids

