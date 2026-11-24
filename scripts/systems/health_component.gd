extends Node

signal died
signal health_changed(current: int, max: int)
## Se emite con el valor del GOLPE cada vez que recibe daño (aunque no lo mate).
signal damaged(amount: int)

@export var max_health: int = 1000
## true = al recibir un golpe sube un número flotante ("-8") sobre quien lo recibe (enemigos y personajes).
@export var show_damage_numbers: bool = true
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	amount = maxi(amount, 0)
	var was_alive: bool = current_health > 0
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	if was_alive and amount > 0:
		damaged.emit(amount)
		if show_damage_numbers:
			var fx: Node = get_node_or_null("/root/CombatFX")
			if fx != null and fx.has_method("damage_number"):
				fx.damage_number(get_parent(), amount)
	if was_alive and current_health <= 0:
		died.emit()

## Recupera vida (sin pasar del máximo). amount <= 0 = vida completa. No revive a quien ya cayó.
func heal(amount: int = 0) -> void:
	if current_health <= 0:
		return
	current_health = max_health if amount <= 0 else mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
