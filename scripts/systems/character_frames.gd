@tool
class_name CharacterFrames
extends SpriteFrames
## ANIMACIONES DE UN PERSONAJE CON TAMAÑO PAREJO (jugables, NPC, enemigos, aldeanos y animales).
##
## Es un SpriteFrames normal: se edita igual en el panel "SpriteFrames" de abajo. Además, al hacer clic en el recurso
## (en el Inspector, propiedad "Sprite Frames" del nodo de animación) aparecen estas propiedades:
##
##   character_height  → alto en pantalla (px) de la figura de pie. TODAS las animaciones miden esto: el juego mide el
##                       dibujo de cada animación (su cuadro más alto) y la escala sola. Así idle, caminar, golpe,
##                       bloqueo o muerte salen del mismo tamaño aunque las hojas estén dibujadas a escalas distintas.
##   animation_scale    → retoque por animación (1 = igual que el resto). Ej. {"attack": 1.05} si el golpe se ve chico
##                       porque en todos sus cuadros el personaje está agachado.
##   animation_offset   → corrimiento fino (px) por animación, ej. {"death": Vector2(0, 8)} para bajar los pies.
##   knockdown_frame    → cuadro de la animación "death" en que queda en el suelo; se usa para la caída por golpe fuerte
##                       (cae hasta ese cuadro y se levanta). -1 = la mitad de la animación.
##
## Si character_height es 0 el personaje usa el ajuste antiguo (medidas guardadas en cada cuadro).

## Alto en pantalla (px) de la figura de pie. 0 = ajuste antiguo.
@export_range(0.0, 900.0, 1.0, "or_greater") var character_height: float = 0.0:
	set(value):
		character_height = value
		emit_changed()
## Multiplicador de tamaño por animación (nombre de la animación → número). Las que no estén usan 1.
@export var animation_scale: Dictionary = {}:
	set(value):
		animation_scale = value
		emit_changed()
## Corrimiento fino en píxeles de pantalla por animación (nombre → Vector2). X positivo = hacia donde mira.
@export var animation_offset: Dictionary = {}:
	set(value):
		animation_offset = value
		emit_changed()
## Cuadro de "death" en que el personaje queda en el suelo al caer por un golpe fuerte (-1 = la mitad).
@export var knockdown_frame: int = -1


func scale_of(animation: StringName) -> float:
	return float(animation_scale.get(String(animation), 1.0))


func offset_of(animation: StringName) -> Vector2:
	var value: Variant = animation_offset.get(String(animation), Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO
