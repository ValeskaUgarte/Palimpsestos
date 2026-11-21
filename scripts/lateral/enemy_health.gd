extends "res://scripts/systems/enemy_health_bar.gd"
## Barra de vida de los enemigos del DEMO (la agrega enemy.gd).
## Es exactamente la misma barra que en el cuento (scripts/systems/enemy_health_bar.gd: marco ornamentado,
## relleno rojo, valor en números y trozo dorado del golpe recibido); aquí solo cambia la altura fija.
## El jefe no la usa: tiene su barra grande abajo (scripts/ui/boss_health.gd).

func _ready() -> void:
	_enemy = get_parent()
	if _enemy.boss_encounter:
		hide()
		set_process(false)
		return
	auto_place = false
	super._ready()
	position.y = -155
	z_index = 20
