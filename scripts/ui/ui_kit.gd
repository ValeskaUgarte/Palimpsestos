class_name UIKit
extends RefCounted
## Piezas de interfaz recortadas de las hojas de arte (assets/ui/kit).
## Todas las pantallas (ajustes, controles, créditos, pausas y paneles de
## encuentro) usan este módulo para verse igual.

const DIR := "res://assets/ui/kit/"
const GOLD := Color("d9bd7a")
const INK := Color(0.17, 0.10, 0.06)
const INK_RED := Color(0.45, 0.09, 0.07)
const CLEAR := Color(0, 0, 0, 0)

# Texto del botón → imagen. La comparación ignora mayúsculas.
const BUTTONS := {
	"entrar en el claro": "btn_entrar_claro",
	"volver al sendero": "btn_volver_sendero",
	"regresar al sendero": "btn_regresar_sendero",
	"continuar": "btn_continuar",
	"comodidad y controles": "btn_comodidad",
	"guardar y volver al menú": "btn_guardar_salir",
	"guardar y salir": "btn_guardar_salir",
	"guardar y continuar": "btn_guardar_continuar",
	"salir al menú": "btn_salir_menu",
	"volver al menú": "btn_salir_menu",
	"volver al cuento": "btn_volver_cuento",
	"volver al juego": "btn_volver_juego",
	"volver": "btn_volver",
	"salir": "btn_salir",
	"aceptar": "btn_aceptar",
	"créditos": "btn_creditos",
	"nueva partida": "btn_nueva_partida",
	"continuar demo": "btn_continuar_demo",
	"importar checkpoint anterior": "btn_importar_checkpoint",
	"volver al último recuerdo": "btn_volver_ultimo_recuerdo",
	"cerrar el cuento": "btn_cerrar_cuento",
	"probar": "btn_probar",
	"cerrar": "btn_cerrar_b",
	"mochila": "btn_mochila",
	"items": "btn_items",
	"mapa": "btn_mapa",
	"ir al mapa": "btn_ir_al_mapa",
	"usar sello": "btn_usar_sello",
	"usar poción": "btn_usar_pocion",
	"comer / beber": "btn_comer_beber",
	"cerrar esta página": "btn_cerrar_pagina",
}

# Título del panel → banner.
const BANNERS := {
	"un margen de silencio": "banner_margen_silencio",
	"una presencia corrompida bloquea el relato": "banner_presencia_bloquea",
	"el lobo · elige quién escribirá este combate": "banner_el_lobo",
	"el relato puede continuar": "banner_relato_continuar",
	"la página se ha borrado": "banner_pagina_borrada",
	"fin del capítulo · no todo lo escrito permanece": "banner_fin_capitulo",
	"la historia espera": "banner_historia_espera",
	"configuración": "banner_configuracion",
	"créditos": "banner_creditos",
	"comodidad y controles": "banner_comodidad",
}

static var _cache: Dictionary = {}


static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path: String = DIR + key + ".png"
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = texture
	return texture


static func dim(alpha: float = 0.88) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.015, 0.02, 0.025, alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## Pergamino con adornos de tamaño fijo y papel que se estira.
## Devuelve {"root": Control, "content": MarginContainer}; el contenido cae
## siempre dentro del papel, sin tocar el pergamino enrollado ni el sello.
static func parchment(panel_size: Vector2) -> Dictionary:
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -panel_size.x * 0.5
	root.offset_right = panel_size.x * 0.5
	root.offset_top = -panel_size.y * 0.5
	root.offset_bottom = panel_size.y * 0.5
	var art := NinePatchRect.new()
	art.texture = tex("parchment")
	art.patch_margin_left = 130
	art.patch_margin_right = 167
	art.patch_margin_top = 110
	art.patch_margin_bottom = 114
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	var content := MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 96)
	content.add_theme_constant_override("margin_right", 104)
	content.add_theme_constant_override("margin_top", 92)
	content.add_theme_constant_override("margin_bottom", 84)
	root.add_child(content)
	return {"root": root, "content": content}


static func banner(title: String, target_height: float = 0.0) -> TextureRect:
	var key: String = BANNERS.get(title.to_lower(), "")
	var texture: Texture2D = tex(key) if key != "" else null
	if texture == null:
		return null
	return _image(texture, target_height)


static func plaque(key: String, target_height: float = 46.0) -> TextureRect:
	var texture: Texture2D = tex(key)
	if texture == null:
		return null
	return _image(texture, target_height)


static func _image(texture: Texture2D, target_height: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var factor: float = 1.0 if target_height <= 0.0 else target_height / texture.get_height()
	rect.custom_minimum_size = texture.get_size() * factor
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rect


static func ink_label(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	return label


## Cambia un Button por la imagen del kit. El texto original se conserva
## (invisible) para accesibilidad, pruebas y para el tooltip.
static func skin_button(button: Button, key: String, target_height: float = 0.0, align: int = Control.SIZE_SHRINK_CENTER) -> bool:
	var texture: Texture2D = tex(key)
	if texture == null:
		return false
	button.flat = false
	if button.tooltip_text.is_empty():
		button.tooltip_text = button.text
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, CLEAR)
	var factor: float = 1.0 if target_height <= 0.0 else target_height / texture.get_height()
	button.custom_minimum_size = texture.get_size() * factor
	button.size_flags_horizontal = align
	button.add_theme_stylebox_override("normal", _face(texture, Color(1, 1, 1, 1)))
	button.add_theme_stylebox_override("hover", _face(texture, Color(1.28, 1.2, 1.08, 1)))
	button.add_theme_stylebox_override("pressed", _face(texture, Color(0.7, 0.66, 0.62, 1)))
	button.add_theme_stylebox_override("hover_pressed", _face(texture, Color(0.8, 0.76, 0.7, 1)))
	button.add_theme_stylebox_override("disabled", _face(texture, Color(0.45, 0.45, 0.45, 0.8)))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(20)
	focus.set_expand_margin_all(3)
	button.add_theme_stylebox_override("focus", focus)
	return true


static func skin_by_text(button: Button, target_height: float = 0.0) -> bool:
	var key: String = BUTTONS.get(button.text.to_lower(), "")
	if key != "" and skin_button(button, key, target_height):
		return true
	style_plain_button(button)
	return false


static func _face(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	return box


## Botón de reserva (sin imagen en el kit) con el mismo tono oscuro y dorado.
static func style_plain_button(button: Button, min_height: float = 44.0) -> void:
	button.add_theme_color_override("font_color", Color("e6d6ae"))
	button.add_theme_color_override("font_hover_color", Color("fff1c9"))
	button.add_theme_color_override("font_pressed_color", Color("c9b27a"))
	button.add_theme_color_override("font_focus_color", Color("fff1c9"))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, min_height)
	button.add_theme_stylebox_override("normal", _plate(Color(0.07, 0.065, 0.075, 0.96), Color(0.5, 0.38, 0.2)))
	button.add_theme_stylebox_override("hover", _plate(Color(0.16, 0.12, 0.1, 1), GOLD))
	button.add_theme_stylebox_override("pressed", _plate(Color(0.04, 0.035, 0.04, 1), Color(0.6, 0.4, 0.22)))
	button.add_theme_stylebox_override("focus", _plate(Color(0.16, 0.12, 0.1, 1), GOLD))


static func _plate(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


## Botón de tecla para el pergamino: placa oscura con letras claras.
static func key_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 17)
	style_plain_button(button, 40.0)
	return button


## Interruptor ON/OFF del kit.
static func toggle(initial: bool) -> TextureButton:
	var button := TextureButton.new()
	button.toggle_mode = true
	button.texture_normal = tex("toggle_off")
	button.texture_pressed = tex("toggle_on")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(96, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.button_pressed = initial
	button.mouse_entered.connect(func(): button.modulate = Color(1.2, 1.15, 1.05))
	button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
	button.focus_entered.connect(func(): button.modulate = Color(1.2, 1.15, 1.05))
	button.focus_exited.connect(func(): button.modulate = Color.WHITE)
	return button


static func style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.07, 0.06, 0.95)
	track.border_color = Color(0.45, 0.32, 0.17)
	track.set_border_width_all(2)
	track.set_corner_radius_all(8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.12, 0.11)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	var fill_hot := fill.duplicate() as StyleBoxFlat
	fill_hot.bg_color = Color(0.78, 0.17, 0.14)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hot)
	var knob: Texture2D = _knob(Color(0.85, 0.7, 0.4), Color(0.22, 0.09, 0.07))
	var knob_hot: Texture2D = _knob(Color(1, 0.9, 0.6), Color(0.35, 0.12, 0.09))
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob_hot)
	slider.add_theme_icon_override("grabber_disabled", knob)
	slider.custom_minimum_size.y = 30
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func _knob(ring: Color, core: Color) -> Texture2D:
	var size := 28
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var distance: float = (Vector2(x + 0.5, y + 0.5) - center).length()
			var alpha: float = clampf(size * 0.5 - distance, 0.0, 1.0)
			var color: Color = ring if distance > size * 0.5 - 4.5 else core
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)


# TÍTULO SOBRE MADERA: el texto va escrito dentro de uno de los marcos de madera tallada de assets/ui/diario/
# (marco_titulo_corto.png = tabla alargada; marco_titulo_grande.png = tabla con adornos arriba y abajo).
# Se usa en "Diario de hallazgos", "Lo que dice el lobo" y "La abuelita". El tamaño lo da el ancho; la altura sale de la proporción.
const WOOD_TITLE_SHORT := "res://assets/ui/diario/marco_titulo_corto.png"
const WOOD_TITLE_BIG := "res://assets/ui/diario/marco_titulo_grande.png"


static func wood_title(text: String, width: float = 400.0, font_size: int = 26, big: bool = false) -> Control:
	var texture := load(WOOD_TITLE_BIG if big else WOOD_TITLE_SHORT) as Texture2D
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, width * float(texture.get_height()) / float(texture.get_width()))
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plank := TextureRect.new()
	plank.texture = texture
	plank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plank.stretch_mode = TextureRect.STRETCH_SCALE
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(plank)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.97, 0.9, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El texto queda dentro de la madera lisa, sin pisar el borde tallado.
	label.anchor_left = 0.09 if not big else 0.1
	label.anchor_right = 0.91 if not big else 0.9
	label.anchor_top = 0.14 if not big else 0.26
	label.anchor_bottom = 0.86 if not big else 0.8
	holder.add_child(label)
	return holder
