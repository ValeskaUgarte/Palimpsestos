extends Node
## ESTADO DEL PERSONAJE (autoload "PlayerStatus").
##
## CANSANCIO (0-100): DINÁMICO, sube y baja todo el rato según lo que hace Elliot:
##   - Pelear y saltar (acciones rápidas) lo suben rápido; en peleas largas, más rápido todavía.
##   - Correr / sprint lo sube rápido (cuando exista esa acción; ya está preparado).
##   - Caminar lo baja un poco.
##   - Quedarse quieto lo baja rápido, y mientras más rato descansa, más rápido.
##   - Cansado, cada esfuerzo cuesta más. Comer (pan, empanada, sopa, mate...) lo baja de golpe.
##   Cansado (60+): -10% de velocidad y de daño. Agotado (85+): -25% de ambos.
## MIEDO (0-100): sube cerca del lobo final, con la vida baja o rodeado de enemigos; baja solo cuando pasa el
##   peligro (o con mate, leche y el sello de sanación). Asustado (50+): -10% de daño. Aterrado (80+): -20%.
## MEJORAS (sellos, se guardan con la partida): habilidad (+10% de daño), combo (+4 al 3er golpe)
##   y guardia (-8% de daño recibido). Máximo MAX_SEALS de cada una.
## El pastel de frutas duplica el remate del combo durante unos segundos (COMBO_TEMP_BONUS).
##
## Todo lo que se puede ajustar está en las constantes de aquí abajo.

signal changed

const TIRED_AT := 60.0
const EXHAUSTED_AT := 85.0
const SCARED_AT := 50.0
const TERROR_AT := 80.0

# CANSANCIO DINÁMICO (puntos por segundo; positivo = sube, negativo = baja). Todo se ajusta desde aquí.
const FATIGUE_WALK := -4.0        # caminar: baja rápido (50 -> 0 en unos 12 s)
const FATIGUE_RUN := 8.0          # correr / sprint: sube muy rápido (sin tecla aún)
const FATIGUE_FIGHT_MIN := 6.0    # pelear: sube muy rápido...
const FATIGUE_FIGHT_MAX := 12.0   # ...y más en peleas largas
const FATIGUE_FIGHT_RAMP := 6.0   # segundos de pelea seguida para llegar al máximo
const FATIGUE_JUMP := 4.0         # mientras está en el aire
const FATIGUE_WINDED := 0.4       # con el cansancio al 100, cada esfuerzo cuesta hasta un 40% más
const FIGHT_GRACE := 1.0          # pausa (s) entre golpes que aún cuenta como "peleando seguido"
# Quieto: baja desde el primer instante, cada vez más rápido (REST_MIN -> REST_MAX en REST_RAMP segundos).
const FATIGUE_REST_MIN := 4.0
const FATIGUE_REST_MAX := 8.0
const FATIGUE_REST_RAMP := 4.0

# Miedo por segundo (positivo sube, negativo baja).
const FEAR_BOSS := 5.0
const FEAR_LOW_LIFE := 3.0
const FEAR_CROWD := 2.0
const FEAR_CALM := -2.5
const FEAR_MAX_FROM_DANGER := 80.0

const MAX_SEALS := 5
const SKILL_PER_SEAL := 0.10
const COMBO_PER_SEAL := 4
const GUARD_PER_SEAL := 0.08
const COMBO_TEMP_BONUS := 8  # se suma al bono base del remate mientras dura el pastel

const DEFAULTS := {"fatiga": 0.0, "miedo": 0.0, "habilidad": 0, "combo": 0, "guardia": 0}

var combo_temp_left: float = 0.0  # segundos que quedan del pastel (no se guarda)
var _fatigue_level: int = 0
var _fear_level: int = 0
var _save_clock: float = 0.0
var _still_time: float = 0.0  # segundos seguidos que Elliot lleva quieto sin atacar
var _fight_time: float = 0.0  # segundos de pelea seguida
var _since_attack: float = 99.0  # segundos desde el último golpe

## Vuelve cansancio, miedo y pastel de combo a cero (nueva partida): ya no arrastra el estado de la partida anterior.
func reset() -> void:
	combo_temp_left = 0.0
	_fatigue_level = 0
	_fear_level = 0
	_still_time = 0.0
	_fight_time = 0.0
	_since_attack = 99.0


func _process(delta: float) -> void:
	var player := _hero()
	if player == null or get_tree().paused or DialogueManager.visible or ScenePages.busy:
		return
	if combo_temp_left > 0.0:
		combo_temp_left = maxf(0.0, combo_temp_left - delta)
	var data := _d()
	# --- cansancio (dinámico: sube y baja según lo que hace) ---
	var moving: bool = player.velocity.length() > 20.0
	var attacking: bool = bool(player.get("is_attacking"))
	var jumping: bool = bool(player.get("is_jumping"))
	# Correr / sprint: se activa si el personaje tiene "is_running" o existe una acción "sprint" (aún no hay).
	var run_flag = player.get("is_running")  # puede no existir (null): por eso no se convierte con bool()
	var running: bool = moving and ((run_flag is bool and run_flag) or (InputMap.has_action("sprint") and Input.is_action_pressed("sprint")))
	var current := float(data["fatiga"])
	if attacking:
		_since_attack = 0.0
		_fight_time += delta
	else:
		_since_attack += delta
		if _since_attack > FIGHT_GRACE:
			_fight_time = 0.0
	var effort := 0.0   # esfuerzo que SUBE el cansancio (positivo)
	if attacking or _since_attack <= FIGHT_GRACE:
		effort += lerpf(FATIGUE_FIGHT_MIN, FATIGUE_FIGHT_MAX, clampf(_fight_time / FATIGUE_FIGHT_RAMP, 0.0, 1.0))
	if running:
		effort += FATIGUE_RUN
	if jumping:
		effort += FATIGUE_JUMP
	var rate := 0.0
	if effort > 0.0:
		# Ya cansado, cada esfuerzo cuesta más.
		rate = effort * (1.0 + FATIGUE_WINDED * (current / 100.0))
		_still_time = 0.0
	elif moving:
		# Caminando tranquilo: baja un poco.
		rate = FATIGUE_WALK
		_still_time = 0.0
	else:
		# Quieto: baja rápido, y más rápido mientras más rato descansa.
		_still_time += delta
		rate = -lerpf(FATIGUE_REST_MIN, FATIGUE_REST_MAX, clampf(_still_time / FATIGUE_REST_RAMP, 0.0, 1.0))
	data["fatiga"] = clampf(current + rate * delta, 0.0, 100.0)
	# --- miedo ---
	var fear_rate := FEAR_CALM
	var danger := false
	var health = player.get("health")
	var boss := get_tree().get_first_node_in_group("story_boss")
	if boss != null and not bool(boss.get("_dead")) and boss.ground_position().distance_to(player.ground_position()) < 850.0:
		fear_rate = FEAR_BOSS
		danger = true
	elif health != null and health.current_health < health.max_health * 0.3:
		fear_rate = FEAR_LOW_LIFE
		danger = true
	elif _enemies_near(player, 450.0) >= 2:
		fear_rate = FEAR_CROWD
		danger = true
	var fear := float(data["miedo"]) + fear_rate * delta
	if danger:
		fear = minf(fear, maxf(FEAR_MAX_FROM_DANGER, float(data["miedo"])))
	data["miedo"] = clampf(fear, 0.0, 100.0)
	_announce_changes(data)
	_save_clock += delta
	if _save_clock >= 1.0:
		_save_clock = 0.0
		changed.emit()


# ---------------------------------------------------------------------------------------------
# CONSULTAS (las usan el HUD y la mochila)
# ---------------------------------------------------------------------------------------------
func fatigue() -> float:
	return float(_d()["fatiga"])


func fear() -> float:
	return float(_d()["miedo"])


func seals(kind: String) -> int:
	return int(_d().get(kind, 0))


func fatigue_name() -> String:
	var value := fatigue()
	if value >= EXHAUSTED_AT:
		return "Agotado"
	if value >= TIRED_AT:
		return "Cansado"
	return "Descansado"


func fear_name() -> String:
	var value := fear()
	if value >= TERROR_AT:
		return "Aterrado"
	if value >= SCARED_AT:
		return "Asustado"
	return "Sereno"


# ---------------------------------------------------------------------------------------------
# MULTIPLICADORES (solo para el personaje que controla el jugador; los compañeros no cambian)
# ---------------------------------------------------------------------------------------------
func _is_hero(player: Node) -> bool:
	return player != null and not bool(player.get("is_companion"))


func speed_multiplier(player: Node) -> float:
	if not _is_hero(player):
		return 1.0
	var factor := 1.0
	var value := fatigue()
	if value >= EXHAUSTED_AT:
		factor *= 0.75
	elif value >= TIRED_AT:
		factor *= 0.9
	return factor


## Daño que hace un golpe de Elliot, ya con habilidad, cansancio y miedo.
func damage_out(base_damage: int, player: Node, is_finisher: bool) -> int:
	if not _is_hero(player):
		return base_damage
	var factor := 1.0 + SKILL_PER_SEAL * seals("habilidad")
	var tired := fatigue()
	if tired >= EXHAUSTED_AT:
		factor *= 0.75
	elif tired >= TIRED_AT:
		factor *= 0.9
	var scared := fear()
	if scared >= TERROR_AT:
		factor *= 0.8
	elif scared >= SCARED_AT:
		factor *= 0.9
	var extra := 0
	if is_finisher:
		extra = COMBO_PER_SEAL * seals("combo")
		if combo_temp_left > 0.0:
			extra += COMBO_TEMP_BONUS
	return maxi(1, int(round((base_damage + extra) * factor)))


## Daño que recibe Elliot, ya con el sello de guardia.
func damage_in(amount: int, player: Node) -> int:
	if not _is_hero(player) or amount <= 0:
		return amount
	var reduction := minf(0.6, GUARD_PER_SEAL * seals("guardia"))
	return maxi(1, int(round(amount * (1.0 - reduction))))


# ---------------------------------------------------------------------------------------------
# USAR UN OBJETO (lo llama la mochila). Devuelve {"ok": bool, "msg": String}.
# Si no sirve de nada ahora mismo, NO se gasta.
# ---------------------------------------------------------------------------------------------
func use_item(id: String, player: Node) -> Dictionary:
	var info := StoryItems.info(id)
	var effect: Dictionary = info.get("efecto", {})
	var health = player.get("health") if player != null else null
	if health == null:
		return {"ok": false, "msg": "Elliot no está en la escena."}
	if health.current_health <= 0:
		return {"ok": false, "msg": "Elliot no puede usarlo ahora."}
	var data := _d()
	var useful := false
	var parts: Array[String] = []
	var heal: int = int(effect.get("heal", 0))
	if heal > 0 and health.current_health < health.max_health:
		var before: int = health.current_health
		health.current_health = mini(health.max_health, health.current_health + heal)
		health.health_changed.emit(health.current_health, health.max_health)
		parts.append("recupera %d de vida" % (health.current_health - before))
		useful = true
	var rest: int = int(effect.get("cansancio", 0))
	if rest > 0 and float(data["fatiga"]) > 0.5:
		var before_f := float(data["fatiga"])
		data["fatiga"] = maxf(0.0, before_f - rest)
		parts.append("se le quita %d de cansancio" % int(round(before_f - float(data["fatiga"]))))
		useful = true
	var calm: int = int(effect.get("miedo", 0))
	if calm > 0 and float(data["miedo"]) > 0.5:
		var before_m := float(data["miedo"])
		data["miedo"] = maxf(0.0, before_m - calm)
		parts.append("se calma %d de miedo" % int(round(before_m - float(data["miedo"]))))
		useful = true
	var temp: int = int(effect.get("combo_temp", 0))
	if temp > 0:
		combo_temp_left = float(temp)
		parts.append("el remate del combo pega más fuerte %d s" % temp)
		useful = true
	for kind in ["habilidad", "combo", "guardia"]:
		if int(effect.get(kind, 0)) > 0:
			if int(data[kind]) >= MAX_SEALS:
				return {"ok": false, "msg": "Ya tiene el máximo de sellos de este tipo (%d)." % MAX_SEALS}
			data[kind] = int(data[kind]) + 1
			parts.append("sube a nivel %d" % int(data[kind]))
			useful = true
	if not useful:
		return {"ok": false, "msg": "Elliot no lo necesita ahora."}
	_announce_changes(data)
	changed.emit()
	return {"ok": true, "msg": "Elliot %s." % ", ".join(parts)}


# ---------------------------------------------------------------------------------------------
# INTERNO
# ---------------------------------------------------------------------------------------------
func _hero() -> Node:
	var scene := get_tree().current_scene
	if scene == null or not scene.scene_file_path in GameSession.LEVELS:
		return null
	return get_tree().get_first_node_in_group("player")


func _d() -> Dictionary:
	var progress: Dictionary = GameSession.progress
	if not progress.has("status") or not progress["status"] is Dictionary:
		progress["status"] = {}
	var data: Dictionary = progress["status"]
	for key in DEFAULTS:
		if not data.has(key):
			data[key] = DEFAULTS[key]
	return data


func _enemies_near(player: Node, radius: float) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("ground_position") and enemy.ground_position().distance_to(player.ground_position()) < radius:
			count += 1
	return count


# Avisos arriba cuando Elliot cruza un umbral (una sola vez por subida).
func _announce_changes(data: Dictionary) -> void:
	var tired := float(data["fatiga"])
	var level_f := 2 if tired >= EXHAUSTED_AT else (1 if tired >= TIRED_AT else 0)
	if level_f > _fatigue_level:
		_say("Elliot está agotado. Necesita comer algo." if level_f == 2 else "Elliot se está cansando. Convendría comer.")
	_fatigue_level = level_f
	var scared := float(data["miedo"])
	var level_m := 2 if scared >= TERROR_AT else (1 if scared >= SCARED_AT else 0)
	if level_m > _fear_level:
		_say("El miedo le tiembla en las manos." if level_m == 2 else "Elliot siente miedo.")
	_fear_level = level_m


func _say(text: String) -> void:
	var scene := get_tree().current_scene
	var presentation := scene.get_node_or_null("ChapterPresentation") if scene != null else null
	if presentation != null and presentation.has_method("show_center"):
		presentation.show_center(text)
	elif presentation != null and presentation.has_method("rewrite"):
		presentation.rewrite(text)
