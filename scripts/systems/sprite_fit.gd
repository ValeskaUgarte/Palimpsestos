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


static var _reference_cache: Dictionary = {}
## Animaciones en las que el apoyo de los pies se mide en cada cuadro (en el resto se usa el del primer cuadro).
const PER_FRAME_FEET := [&"walk", &"run", &"jump", &"death", &"land"]


## Cuadro de referencia de una animación: su PRIMER cuadro con dibujo (la pose base: de pie, en guardia...).
## No se usa el más alto porque un brazo en alto o un salto harían ver chico al personaje en esa animación.
## El salto ("jump") se mide con la referencia del reposo: la figura se encoge y se estira dentro del salto sin cambiar de tamaño.
static func reference_frame(frames: SpriteFrames, animation: StringName) -> Dictionary:
	if animation == &"jump" and has_clip(frames, &"idle"):
		animation = &"idle"
	var key := "%d|%s|%d" % [frames.get_instance_id(), animation, frames.get_frame_count(animation)]
	if _reference_cache.has(key):
		return _reference_cache[key]
	var best: Dictionary = {}
	for index in frames.get_frame_count(animation):
		var m: Dictionary = metrics(frames.get_frame_texture(animation, index))
		if not m.is_empty() and int(m["bottom"]) - int(m["top"]) > 0:
			best = m
			break
	_reference_cache[key] = best
	return best


## true si el SpriteFrames trae un alto de personaje (CharacterFrames con character_height > 0).
static func uses_height(frames: SpriteFrames) -> bool:
	return frames is CharacterFrames and (frames as CharacterFrames).character_height > 0.0


## Ajuste común de tamaño y apoyo para un cuadro (todos los personajes usan esto cuando su SpriteFrames tiene
## character_height). Devuelve {scale, baseline, offset_x, shift}:
##   scale: escala del sprite · baseline: fila de los pies medida desde el centro del cuadro (en px de la textura)
##   offset_x: corrimiento para centrar la figura (px de textura) · shift: corrimiento extra en px de pantalla.
## Vacío si el SpriteFrames no usa el sistema o el cuadro no tiene dibujo.
static func height_fit(frames: SpriteFrames, animation: StringName, frame: int) -> Dictionary:
	if not uses_height(frames) or not frames.has_animation(animation):
		return {}
	var texture: Texture2D = frames.get_frame_texture(animation, frame)
	var measured: Dictionary = metrics(texture)
	var ref: Dictionary = reference_frame(frames, animation)
	if measured.is_empty() or ref.is_empty():
		return {}
	var ref_height: float = float(int(ref["bottom"]) - int(ref["top"]))
	if ref_height <= 0.0:
		return {}
	var cf := frames as CharacterFrames
	# Centrado: con el primer cuadro de la propia animación (el salto toma la escala del reposo, pero se centra con su hoja).
	var center: Dictionary = ref
	if animation == &"jump":
		var own: Dictionary = metrics(frames.get_frame_texture(animation, 0))
		if not own.is_empty():
			center = own
	# Apoyo de los pies: la medida guardada del cuadro si la tiene; si no, la del primer cuadro de la animación.
	# (Medirlo en cada cuadro hacía subir y bajar al personaje cuando un cuadro se medía mal.)
	var baseline: float = float(ref["bottom"]) - float(ref["h"]) * 0.5
	# Caminar, correr, saltar y caer cambian de pie de apoyo en cada cuadro: ahí se mide cuadro a cuadro.
	if animation in PER_FRAME_FEET:
		baseline = float(measured["bottom"]) - float(measured["h"]) * 0.5
	if texture.has_meta("pose_art_baseline"):
		baseline = float(texture.get_meta("pose_art_baseline"))
	elif texture.has_meta("fit_baseline"):
		baseline = float(texture.get_meta("fit_baseline"))
	return {
		"scale": cf.character_height * cf.scale_of(animation) / ref_height,
		"baseline": baseline,
		"offset_x": -(float(center["cx"]) - float(center["w"]) * 0.5),
		"shift": cf.offset_of(animation),
	}


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
	&"block": [&"idle"],
	&"drink": [&"interact", &"idle"],
	&"taunt": [&"talk", &"idle"],
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
