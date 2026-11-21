extends Node2D
## RUTA DEL CUENTO: pone en el camino los objetos y las pistas de una escena.
## Elige el "preset" en el Inspector (escena1 / escena2 / escena3). Lo que ya se recogió no vuelve a aparecer.
## Los objetos, pistas y tableros son nodos hijos de este nodo (StoryPickup): arrástralos en el editor.
## PRESETS es la lista de respaldo y la que se usó para crear esos nodos.

@export_enum("escena1", "escena2", "escena3", "ninguno") var preset: String = "ninguno"

## Objetos que Caperucita ya lleva al empezar la escena (se dan una sola vez).
const START_ITEMS := {
	"escena1": ["pastel", "vino"],
}

## Avisos de los tableros del pueblo: ambiente, rumores y desapariciones. Cada tablero muestra uno fijo.
const AVISOS := [
	"SE BUSCA: Brunhilda, leñadora. No vuelve desde la última luna. Quien la vea, que avise en el pueblo.",
	"Cuidado con los lobos del camino de las flores. Anoche atacaron dos ovejas al atardecer.",
	"Se prohíbe salir del camino después del anochecer. Lo ordena el alcalde.",
	"Se perdió un gato gris. Responde al nombre de Pelusa. No respondas si te llaman «lobo».",
	"Hallado en el río: un zapato pequeño y rojo. Su dueña, avisar a la guardia.",
	"Los niños no deben hablar con desconocidos del bosque. Los que lo hacen tardan en volver.",
	"Se busca a un hombre que vende pasteles y cuenta historias. No comprar nada a quien no se conoce.",
]

const PRESETS := {
	"escena1": [
		{"x": 3800, "item": "flores", "lines": [], "autores": ["Los autores: la niña no fue a coger flores. Eso lo añadieron después."]},
		{"x": 4600, "item": "", "avisos": AVISOS, "icono": "cartel_tablero", "ancho": 185.0, "cartel": "periodico"},
		{"x": 5200, "item": "pluma", "lines": []},
		{"x": 8400, "item": "huella", "lines": [], "autores": ["Los autores: lo que dejó esta huella fue borrado de todas las versiones. Lo sabemos."]},
		{"x": 8200, "item": "", "avisos": AVISOS, "icono": "cartel_flechas", "ancho": 185.0, "cartel": "pasteles_caseros"},
		{"x": 12400, "item": "", "avisos": AVISOS, "icono": "cartel_tablero", "ancho": 185.0, "cartel": "se_busca_ayuda"},
		{"x": 9900, "item": "pocion", "lines": []},
		{"x": 11400, "item": "carta", "lines": []},
		{"x": 12900, "item": "", "lines": ["Pisadas que se apartan del camino hacia el bosque. Nadie las siguió."]},
		{"x": 14300, "item": "mapa", "lines": [], "autores": ["Los autores: el mapa siempre estuvo ahí. Nadie quiso leerlo."]},
		{"x": 17500, "item": "", "lines": ["Una nota clavada en el tronco, con letra de abuela: «Lo que la siguió. Lo que la distrajo. Lo que cantaba. Lo que llevaba.»"]},
		{"x": 15600, "item": "pocion", "lines": []},
	],
	"escena2": [
		# Los dos caminos del cuento original: el lobo toma el corto, la niña el de las flores.
		{"x": 1600, "item": "", "lines": ["Un cartel: «CAMINO CORTO →»  «CAMINO DE LAS FLORES ←».", "Como en el cuento: el lobo eligió el corto; la niña, el de las flores."], "icono": "cartel_flechas", "ancho": 185.0},
		{"x": 9000, "item": "", "avisos": AVISOS, "icono": "cartel_tablero", "ancho": 185.0, "cartel": "nina_perdida"},
		# PISTAS DE LOS ANILLOS DE LA CUEVA: el cuento original en orden (casa -> bosque -> flores) y cómo giran.
		{"x": 1100, "item": "", "lines": ["Una nota clavada en un tronco, con letra de madre: «Lleva este pastel y esta botella a tu abuela. Sal de casa ahora, y no te apartes del camino.»", "Así empezó el cuento: con una niña saliendo de la casa de su madre."], "icono": "res://assets/ui/acertijos/nota_arbol.png", "ancho": 130.0},
		{"x": 2100, "item": "", "lines": ["Un árbol grande dibujado en un poste, a la orilla del sendero.", "En el cuento, la niña entró en el bosque y allí se cruzó con el lobo, que la saludó con muy buenos modales."], "icono": "res://assets/ui/acertijos/pista_poste.png", "ancho": 120.0},
		{"x": 2850, "item": "", "lines": ["Una luna creciente tallada en una roca, junto al camino.", "Debajo, rayado: «El lobo espera a la noche. La niña no tiene que esperarla.» Ni la luna ni el hongo cuentan el camino de la niña."], "icono": "res://assets/ui/acertijos/pista_luna.png", "ancho": 120.0},
		{"x": 2500, "item": "", "lines": ["Una tabla con tres anillos grabados y flechas: el de fuera y el de dentro giran con el sol; el del medio, contra él.", "Debajo, en orden: «El cuento tiene tres momentos. Primero, el inicio en casa de la madre. Después, el bosque, donde la niña se cruza con el lobo. Y por último, lo que la aparta del camino. Se lee de fuera hacia dentro, siempre bajo la marca de arriba. La luna y el hongo no cuentan.»"], "icono": "cartel_tablero", "ancho": 185.0},
		{"x": 3800, "item": "", "lines": ["Flores y hojas pisadas, fuera del sendero.", "En el cuento, el lobo le dijo: «Mira qué flores tan bonitas». Y ella se apartó del camino a recogerlas."], "icono": "item_flores", "ancho": 110.0},
		{"x": 4150, "item": "", "lines": ["Bajo la roca, alguien rayó el orden del cuento en la piedra.", "«Primero la casa de la madre. Después el bosque, donde se cruza con el lobo. Por último, lo que la aparta del camino. Se lee de fuera hacia dentro.»"]},
		{"x": 5000, "item": "", "lines": ["Tres marcas de garras en la tierra, cerca de la entrada de la cueva.", "El lobo no siguió el cuento de la niña: la adelantó por el camino corto y llegó antes. Por eso está en el centro de todo."], "icono": "res://assets/ui/acertijos/pista_cueva_garras.png", "ancho": 120.0},
		# Más pociones en la escena 2: la energía ya no se restablece al cambiar de escena.
		{"x": 1850, "item": "pocion", "lines": []},
		{"x": 5600, "item": "pocion", "lines": []},
		{"x": 7600, "item": "pocion", "lines": []},
		{"x": 10500, "item": "pocion", "lines": []},
		{"x": 12000, "item": "pocion", "lines": []},
		{"x": 13600, "item": "pocion", "lines": []},
	],
	"escena3": [
		{"x": 1900, "item": "huella", "lines": []},
		{"x": 2500, "item": "", "avisos": AVISOS, "icono": "cartel_tablero", "ancho": 185.0, "cartel": "venta_caza"},
		{"x": 3900, "item": "pocion", "lines": []},
	],
}

const DEFAULT_Y := 270.0


func _ready() -> void:
	if preset == "ninguno":
		return
	_give_start_items()
	_authors_intro()
	# Los objetos y tableros ahora son nodos de la escena (hijos de este nodo): se mueven en el editor.
	# Solo si no hay ninguno se crean desde PRESETS (modo antiguo, por si borras todos los nodos).
	for child in get_children():
		if child is StoryPickup:
			return
	var entries: Array = PRESETS.get(preset, [])
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var pickup := StoryPickup.new()
		pickup.item_id = entry.get("item", "")
		pickup.amount = int(entry.get("amount", 1))
		pickup.lines.assign(entry.get("lines", []))
		pickup.author_lines.assign(entry.get("autores", []))
		if entry.has("icono"):
			var icon := String(entry["icono"])
			pickup.icon_path = icon if icon.begins_with("res://") else "res://assets/ui/diario/%s.png" % icon
		pickup.draw_width = float(entry.get("ancho", 72.0))
		if entry.has("cartel"):
			pickup.poster_path = "res://assets/ui/tableros/%s.png" % entry["cartel"]
		pickup.key = "%s_%d" % [preset, index]
		if entry.has("avisos"):
			var notices: Array = entry["avisos"]
			pickup.lines.assign([notices[index % notices.size()]])
		pickup.position = Vector2(float(entry["x"]), float(entry.get("y", DEFAULT_Y)))
		add_child(pickup)


# Los autores hablan al entrar a cada escena (una sola vez): la voz existe desde el inicio del juego.
const AUTHORS_START := {
	"escena1": "Los autores: esta historia ya fue contada muchas veces. Nadie recuerda bien cómo empezaba.",
	"escena2": "Los autores: el lobo siempre llega antes de lo que la niña espera.",
	"escena3": "Los autores: al final, todos quieren que el lobo pague. Nadie pregunta qué le pasó antes.",
}


func _authors_intro() -> void:
	var flag := "autores_inicio:" + preset
	if GameSession.has_flag(flag) or not AUTHORS_START.has(preset):
		return
	GameSession.set_flag(flag)
	get_tree().create_timer(4.0, true).timeout.connect(func(): Autores.say([AUTHORS_START[preset]]))


func _give_start_items() -> void:
	var flag := "inicio:" + preset
	if GameSession.has_flag(flag):
		return
	for id in START_ITEMS.get(preset, []):
		GameSession.add_item(id)
	GameSession.set_flag(flag)
