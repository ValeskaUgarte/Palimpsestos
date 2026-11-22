extends "res://scripts/characters/enemy_ai.gd"
## LOBO FINAL (guardián de la historia). Ajustes que se cambian en el Inspector del nodo Lobo:
## Cada golpe que recibe se multiplica por esto: con 5000 de vida y compañeros peleando, el combate dura y es difícil.
@export var damage_taken_scale: float = 4.0
## "El ring": el lobo no sale de esta franja de X del mundo, así la pelea ocurre en el centro y no en la entrada.
## Con los dos en 0 no hay límite.
@export var arena_min_x: float = 0.0
@export var arena_max_x: float = 0.0
## Alcance de su ataque normal y de su embestida (el lobo es más grande, así que llega más lejos).
@export var melee_range: float = 190.0
@export var charge_range: float = 300.0
## En la segunda fase su daño se multiplica por esto.
@export var phase_two_damage_bonus: float = 1.3

var _charge_pattern: bool = false
var _charging: bool = false
var _charge_direction: float = 1.0
var _phase_two: bool = false
var _warn: Node2D

func _ready() -> void:
	super._ready()
	add_to_group("story_boss")
	attack_range=melee_range
	detection_radius=760
	if detection_shape.shape is CircleShape2D:detection_shape.shape.radius=760
	_warn=Node2D.new()
	_warn.set_script(preload("res://scripts/systems/boss_warning.gd"))
	add_child(_warn)
	_warn.hide()

func _physics_process(delta: float) -> void:
	if _dead:return
	if _charging and is_attacking and visual.frame==2:
		knockback=Vector2(_charge_direction*(440 if _phase_two else 360),0)
	super._physics_process(delta)
	# Se queda dentro del ring: si el movimiento lo sacó, se le devuelve a la franja.
	if arena_max_x>arena_min_x:
		var held:=clampf(global_position.x,arena_min_x,arena_max_x)
		if not is_equal_approx(held,global_position.x):
			global_position.x=held
			velocity.x=0.0
	if not is_attacking or visual.frame==3:_warn.hide()
	_warn.position=Vector2(0,$CollisionShape2D.position.y+12)
	_warn.set("direction",_charge_direction)
	_warn.queue_redraw()
	if not _phase_two and health.current_health <= health.max_health / 2:
		_phase_two=true
		attack_damage=int(round(attack_damage*phase_two_damage_bonus))
		var presentation=get_parent().get_node_or_null("ChapterPresentation")
		if presentation:presentation.rewrite("Una segunda versión despierta.")
		AudioLandscape.hush(.4,.6)
		AudioLandscape.cue(&"corruption",ground_position())

# Todo lo que le pega (Elliot y sus compañeros) pasa por aquí: se multiplica por damage_taken_scale.
func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	super.take_damage(maxi(1,int(round(amount*damage_taken_scale))),from_position)

func _attack() -> void:
	if _dead or is_attacking:return
	_charge_direction=_facing_sign
	_charging=_charge_pattern
	attack_windup=.8 if _charge_pattern else .5
	attack_active_time=.3 if _charge_pattern else .16
	attack_cooldown=.75 if _phase_two else 1.1
	_warn.set("charge",_charge_pattern)
	_warn.show()
	# super._attack() suma 1 a _attack_generation al empezar: si un remate la interrumpe, esta cola no debe pisar el ataque nuevo.
	var generation: int = _attack_generation + 1
	await super._attack()
	if _dead or generation != _attack_generation:return
	_charging=false
	knockback=Vector2.ZERO
	_warn.hide()
	_charge_pattern=not _charge_pattern
	attack_range=charge_range if _charge_pattern else melee_range

func _on_died() -> void:
	if _warn:_warn.hide()
	_charging=false
	# Solo el jefe real cierra el relato; los lobos normales del demo no deben mostrar este texto ni callar el audio.
	if is_in_group("story_boss"):
		var presentation=get_parent().get_node_or_null("ChapterPresentation")
		if presentation:presentation.rewrite("La bestia pierde su nombre. El relato continúa.")
		AudioLandscape.hush(.2,1.2)
	super._on_died()
