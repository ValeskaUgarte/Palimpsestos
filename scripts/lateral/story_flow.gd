extends Node
# Escenas de la demo: una por mundo, todas en scenes/demo/ (editables en el editor).
const WORLDS = ["res://scenes/demo/mundos/demo1_bosque.tscn","res://scenes/demo/mundos/demo2_camino.tscn","res://scenes/demo/mundos/demo3_historias.tscn"]
const UNDERWORLDS = ["","res://scenes/demo/inframundos/inframundo2.tscn","res://scenes/demo/inframundos/inframundo3.tscn"]
const WORLD = "res://scenes/demo/mundos/demo1_bosque.tscn"
var realm: String = "normal"
var chapter: int = 0
var resolved: Array = []
var party_health: Dictionary = {}
var entry_health: Dictionary = {}
var selected: String = "elliot"
var return_x: float = 300
var encounter_id: String = ""
var completed: bool = false
var enabled: bool = true
var save_path: String = "user://lateral-story-v2.json"
var last_error: Error = OK
var _timer: float = 0
func _process(delta: float) -> void:
	if not enabled or get_tree().paused or ScenePages.busy: return
	_timer += delta
	if _timer < 5: return
	_timer = 0
	var scene = get_tree().current_scene
	if scene != null and (scene.scene_file_path in WORLDS or scene.scene_file_path in UNDERWORLDS):
		var actor = get_tree().get_first_node_in_group("player")
		if actor and actor.is_on_floor() and not actor.is_attacking and not actor._dead:
			return_x = clampf(actor.position.x, 100, 2300)
			capture_party()
			save_game()
func new_game() -> void:
	realm = "normal"; chapter = 0; resolved = []; party_health = {}; entry_health = {}; selected = "elliot"; return_x = 300; encounter_id = ""; completed = false
	save_game()
	ScenePages.travel(world_scene())
func capture_party() -> void:
	for actor in get_tree().get_nodes_in_group("lateral_actor"):
		party_health[actor.fighter_id] = actor.health.current_health
func save_game() -> bool:
	if not enabled: return true
	var data = {"version":2,"realm":realm,"chapter":chapter,"resolved":resolved,"party_health":party_health,"entry_health":entry_health,"selected":selected,"return_x":return_x,"encounter_id":encounter_id,"completed":completed}
	var file = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null: last_error = FileAccess.get_open_error(); return false
	file.store_string(JSON.stringify(data))
	file.flush()
	last_error = file.get_error()
	file.close()
	if last_error != OK: return false
	if not _read(save_path).is_empty():
		last_error = DirAccess.copy_absolute(save_path, save_path + ".bak")
		if last_error != OK: return false
	last_error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	return last_error == OK
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	var parsed = json.data
	if not parsed is Dictionary: return {}
	if parsed.get("version") != 2 or not parsed.get("chapter") is float or parsed.chapter < 0 or parsed.chapter > 2: return {}
	if not parsed.get("realm","normal") in ["normal","underworld"]: return {}
	if not parsed.get("resolved") is Array or not parsed.get("party_health") is Dictionary or not parsed.get("selected") in ["elliot","jhon","thomas"]: return {}
	if not parsed.get("encounter_id") in ["","guardian_0","guardian_1","guardian_2"]: return {}
	if not parsed.get("return_x") is float or not is_finite(parsed.return_x) or not parsed.get("encounter_id") is String or not parsed.get("completed") is bool: return {}
	for id in parsed.resolved:
		if not id is String: return {}
	if not parsed.get("entry_health",{}) is Dictionary: return {}
	for states in [parsed.party_health,parsed.get("entry_health",{})]:
		for id in states:
			if not id in ["elliot","jhon","thomas"] or not states[id] is float or not is_finite(states[id]) or states[id] < 0 or states[id] > 1000: return {}
	return parsed
func continue_game() -> bool:
	var data = _read(save_path)
	if data.is_empty(): data = _read(save_path + ".bak")
	if data.is_empty(): return false
	realm = data.get("realm","normal")
	chapter = int(data.chapter); resolved = data.resolved; party_health = data.party_health; selected = data.selected; return_x = clampf(data.return_x,100,2300); encounter_id = data.encounter_id; completed = data.completed
	entry_health = data.get("entry_health",{}).duplicate(true)
	if encounter_id != "" and not entry_health.is_empty(): party_health = entry_health.duplicate(true)
	# A saved encounter resumes at its safe entrance, never a half-finished attack.
	ScenePages.travel(encounter().arena_scene if encounter_id != "" else world_scene())
	return true
func world_scene() -> String:
	return UNDERWORLDS[chapter] if realm == "underworld" and chapter > 0 else WORLDS[clampi(chapter,0,2)]
func encounter() -> Resource:
	return load(["res://resources/lateral/encounters/forest.tres","res://resources/lateral/encounters/edge.tres","res://resources/lateral/encounters/corrupted.tres"][chapter])
func enter_arena(id: String, fighter: String) -> void:
	var definition: Resource = encounter()
	if ScenePages.busy or id in resolved or definition.mode != 1 or id != definition.encounter_id: return
	capture_party()
	if not fighter in ["elliot","jhon","thomas"] or party_health.get(fighter,1000) <= 0: return
	if (fighter == "jhon" and chapter < 1) or (fighter == "thomas" and chapter < 2): return
	if not ResourceLoader.exists(definition.arena_scene) or not ResourceLoader.exists(definition.enemy_scene): return
	selected = fighter
	entry_health = party_health.duplicate(true)
	encounter_id = id
	save_game()
	ScenePages.travel(definition.arena_scene)
func victory() -> void:
	capture_party()
	if not encounter_id in resolved: resolved.append(encounter_id)
	encounter_id = ""
	entry_health = {}
	selected = "elliot"
	save_game()
	ScenePages.travel(world_scene())
func retry() -> void:
	if not entry_health.is_empty(): party_health = entry_health.duplicate(true)
	else: party_health[selected] = 1000
	save_game()
	ScenePages.travel(encounter().arena_scene if encounter_id != "" else world_scene())

func import_legacy_checkpoint() -> bool:
	if not FileAccess.file_exists(GameSession.save_path): return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(GameSession.save_path)) != OK: return false
	var old = json.data
	if not old is Dictionary or old.get("version") != 1 or not old.get("level") in GameSession.LEVELS: return false
	if not old.get("health") is float or not is_finite(old.health) or old.health <= 0 or old.health > 1000: return false
	realm = "normal"
	chapter = GameSession.LEVELS.find(old.level)
	selected = "elliot"; encounter_id = ""; return_x = 300; resolved = []; entry_health = {}
	party_health = {"elliot":old.health}
	var legacy_party: Dictionary = old.get("party",{}) if old.get("party",{}) is Dictionary else {}
	for pair in [["Jhon","jhon"],["Thomas","thomas"]]:
		var value = legacy_party.get(pair[0],1000)
		if value is float or value is int:
			if is_finite(value): party_health[pair[1]] = clampf(value,0,1000)
	if chapter == 0 and old.get("puzzle") == true: resolved.append("runes_0")
	completed = old.get("completed") == true
	if not save_game(): return false
	ScenePages.travel(world_scene())
	return true
