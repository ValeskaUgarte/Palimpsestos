class_name SpriteFit
extends RefCounted
## Mide el dibujo visible de un frame (alto, centro y fila donde apoyan los pies) para ajustar tamaño y apoyo
## automáticamente cuando el frame no trae medidas guardadas (metadatos fit_* / pose_art_*).
## Así se pueden agregar frames nuevos con el editor de SpriteFrames normal y el personaje igual queda parejo.

static var _cache: Dictionary = {}


static func metrics(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	if _cache.has(texture):
		return _cache[texture]
	var result: Dictionary = {}
	var image: Image = texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var w: int = image.get_width()
		var h: int = image.get_height()
		var counts := PackedInt32Array()
		counts.resize(h)
		var min_x: int = w
		var max_x: int = -1
		var top: int = -1
		var bottom: int = -1
		for y in h:
			var c: int = 0
			for x in w:
				if image.get_pixel(x, y).a > 0.16:
					c += 1
					if x < min_x:
						min_x = x
					if x > max_x:
						max_x = x
			counts[y] = c
			if c > 0:
				if top < 0:
					top = y
				bottom = y + 1
		if top >= 0:
			# Fila de apoyo: ignora colgajos finos (capa, cola) que cuelgan por debajo de los pies.
			var widest: int = 0
			for y in range(top + int((bottom - top) * 0.6), bottom):
				widest = maxi(widest, counts[y])
			var support: int = bottom
			for y in range(bottom - 1, top - 1, -1):
				if counts[y] >= maxi(6, int(0.3 * float(widest))):
					support = y + 1
					break
			result = {"top": top, "bottom": support, "cx": float(min_x + max_x + 1) * 0.5, "w": w, "h": h}
	_cache[texture] = result
	return result


# ---------------------------------------------------------------------------------------------
# ANIMACIONES EDITABLES (ranuras de movimiento)
# Todos los personajes, NPC, enemigos, aldeanos y animales traen sus ranuras de animación ya
# creadas en su SpriteFrames (idle, walk, run, attack, hurt, death, talk...). Una ranura vacía
# (0 frames) NO se reproduce: el juego usa la siguiente de la cadena (FALLBACKS) hasta llegar a
# idle. Así puedes ir agregando frames a medida que los tengas, sin romper nada mientras tanto.
# ---------------------------------------------------------------------------------------------

## Si una ranura está vacía se prueba con la siguiente de la lista (al final siempre idle).
const FALLBACKS := {
	&"run": [&"walk", &"idle"],
	&"walk": [&"run", &"idle"],
	&"talk": [&"idle"],
	&"hurt": [&"idle"],
	&"death": [&"hurt", &"idle"],
	&"jump": [&"idle"],
	&"land": [&"idle"],
	&"interact": [&"talk", &"idle"],
	&"idle_combat": [&"idle"],
	&"attack_1": [&"attack", &"idle"],
	&"attack_2": [&"attack", &"idle"],
	&"finisher": [&"attack", &"idle"],
	&"kick": [&"attack", &"idle"],
	&"attack": [&"idle"],
	&"react": [&"talk", &"idle"],
}


## true si la animación existe Y tiene al menos un frame dibujado.
static func has_clip(frames: SpriteFrames, clip: StringName) -> bool:
	return frames != null and frames.has_animation(clip) and frames.get_frame_count(clip) > 0


## Devuelve la animación que de verdad se puede reproducir: la pedida si tiene frames; si no, la
## primera de su cadena de respaldo; si no hay ninguna, la primera animación con frames.
## Devuelve &"" solo si el SpriteFrames no tiene ni un frame.
## allow_any = false: no busca "cualquier otra animación" al final (útil cuando hay un dibujo de respaldo).
static func resolve_clip(frames: SpriteFrames, clip: StringName, allow_any: bool = true) -> StringName:
	if frames == null:
		return &""
	if has_clip(frames, clip):
		return clip
	for candidate in FALLBACKS.get(clip, [&"idle"]):
		if has_clip(frames, candidate):
			return candidate
	if has_clip(frames, &"idle"):
		return &"idle"
	if not allow_any:
		return &""
	for name in frames.get_animation_names():
		if has_clip(frames, name):
			return name
	return &""
