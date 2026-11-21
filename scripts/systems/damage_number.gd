extends Node2D
## NÚMERO DE GOLPE FLOTANTE: aparece sobre quien recibe el daño (enemigos, Elliot, Jhon, Thomas, compañeros),
## sube un poco y se apaga. Lo crea CombatFX.damage_number(); lo dispara el HealthComponent de cada personaje.

var amount: int = 0
## true = lo recibe un personaje del jugador o compañero (se ve rojo); false = lo recibe un enemigo (se ve dorado).
var on_player_side: bool = false
## Fuerza relativa del golpe (más grande si pega fuerte).
var strength: float = 1.0

const LIFETIME := 0.95
var _age: float = 0.0
var _drift: float = 0.0


func _ready() -> void:
	z_index = 200
	_drift = randf_range(-14.0, 14.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = clampf(_age / LIFETIME, 0.0, 1.0)
	var fade: float = 1.0 - clampf((t - 0.55) / 0.45, 0.0, 1.0)
	# Sale con un pequeño "golpe" de tamaño y sube con suavidad.
	var pop: float = 1.0 + 0.45 * maxf(0.0, 1.0 - t * 6.0)
	var size: int = int(round((20.0 + 6.0 * clampf(strength - 1.0, 0.0, 1.5)) * pop))
	var offset := Vector2(_drift * t, -68.0 * (1.0 - pow(1.0 - t, 2.0)))
	var text: String = "-%d" % amount
	var fill: Color = Color(1.0, 0.38, 0.3, fade) if on_player_side else Color(1.0, 0.86, 0.5, fade)
	var edge := Color(0.06, 0.02, 0.02, 0.95 * fade)
	var width: float = 160.0
	var at := offset + Vector2(-width * 0.5, 0.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 6, edge)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, fill)
