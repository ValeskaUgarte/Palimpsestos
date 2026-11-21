class_name StoryItems
extends RefCounted
## CATÁLOGO DE OBJETOS DEL CUENTO (mochila).
##   kind = "objeto" (pista o cosa del cuento)
##        | "pocion" (recupera la vida indicada en "heal")
##        | "comida" (se usa desde la mochila: quita cansancio / calma el miedo / cura un poco; ver "efecto")
##        | "sello"  (mejora permanente o cura grande; ver "efecto")
##   "efecto" = {heal, cansancio, miedo, combo_temp, habilidad, combo, guardia}. Los números de cansancio y miedo
##   son lo que se RESTA (0-100). Todo se aplica en PlayerStatus.use_item().
##   icon = ruta de la imagen (vacío = se dibuja el nombre). Para cambiarla, pon el PNG y ajusta la ruta aquí.
## Para agregar un objeto nuevo: añádelo a ITEMS y ponlo en un StoryTrail (o en un puzle) con ese id.

const ITEMS := {
	"pastel": {"name": "Pastel", "kind": "objeto", "icon": "res://assets/ui/diario/item_pastel.png",
		"desc": "Un pastel envuelto en un paño, tirado en el barro. Alguien lo llevaba a algún lugar."},
	"vino": {"name": "Botella de vino", "kind": "objeto", "icon": "res://assets/ui/diario/item_vino.png",
		"desc": "Una botella junto al pastel. Quien la llevaba pensaba cenar con alguien."},
	"flores": {"name": "Flores del claro", "kind": "objeto", "icon": "res://assets/ui/diario/item_flores.png",
		"desc": "Flores recién cortadas, todas del mismo lado del sendero. Quien las cortó se apartó del camino."},
	"pluma": {"name": "Pluma de pájaro", "kind": "objeto", "icon": "res://assets/ui/diario/item_pluma.png",
		"desc": "Una pluma clara, enganchada en una rama baja. Algo cantaba aquí, y nadie lo vigiló."},
	"huella": {"name": "Huella de garra", "kind": "objeto", "icon": "res://assets/ui/diario/item_huella.png",
		"desc": "Una huella grande, con garras. Pisa sobre otras pisadas, más pequeñas."},
	"carta": {"name": "Carta de la abuelita", "kind": "objeto", "icon": "res://assets/ui/pack_gotico/obj_pergamino.png",
		"desc": "Un papel doblado, con letra antigua: «Toma el camino corto, por la piedra». Alguien quiso que fuera por un lugar concreto."},
	"mapa": {"name": "Mapa del camino", "kind": "objeto", "icon": "res://assets/ui/pack_gotico/obj_papiro.png",
		"desc": "Un mapa dibujado a mano. Uno de los dos caminos aparece marcado como un rodeo."},
	# POCIONES: cada color recupera una cantidad distinta de vida (Elliot tiene 1000 de vida máxima).
	# "pocion" es la roja (se conserva el id para que las partidas guardadas sigan funcionando).
	"pocion": {"name": "Poción roja", "kind": "pocion", "icon": "res://assets/ui/items/pocion_roja.png",
		"efecto": {"heal": 150}, "desc": "Un frasco con un líquido rojo. Recupera 150 de vida."},
	"pocion_verde": {"name": "Poción verde", "kind": "pocion", "icon": "res://assets/ui/items/pocion_verde.png",
		"efecto": {"heal": 300}, "desc": "Un frasco verde con olor a hierba. Recupera 300 de vida."},
	"pocion_azul": {"name": "Poción azul", "kind": "pocion", "icon": "res://assets/ui/items/pocion_azul.png",
		"efecto": {"heal": 500}, "desc": "Un frasco azul que brilla como un cielo de noche. Recupera 500 de vida."},
	"pocion_amarilla": {"name": "Poción dorada", "kind": "pocion", "icon": "res://assets/ui/items/pocion_amarilla.png",
		"efecto": {"heal": 800}, "desc": "Un frasco dorado, el más fuerte. Recupera 800 de vida."},
	# COMIDA: el cansancio sube mientras Elliot camina y pelea; comer lo baja.
	"pan": {"name": "Pan de masa madre", "kind": "comida", "icon": "res://assets/ui/items/pan.png",
		"efecto": {"cansancio": 35, "heal": 50}, "desc": "Pan duro y tibio. Quita 35 de cansancio y cura un poco."},
	"empanada": {"name": "Empanada", "kind": "comida", "icon": "res://assets/ui/items/empanada.png",
		"efecto": {"cansancio": 25, "heal": 120}, "desc": "Una empanada de horno. Quita 25 de cansancio y recupera 120 de vida."},
	"sopa": {"name": "Sopa caliente", "kind": "comida", "icon": "res://assets/ui/items/sopa.png",
		"efecto": {"cansancio": 20, "heal": 250}, "desc": "Sopa de verduras. Cura las heridas (250 de vida) y quita 20 de cansancio."},
	"mate": {"name": "Mate", "kind": "comida", "icon": "res://assets/ui/items/mate.png",
		"efecto": {"cansancio": 50, "miedo": 15}, "desc": "Un mate bien cargado. Quita 50 de cansancio y 15 de miedo."},
	"leche": {"name": "Jarra de leche", "kind": "comida", "icon": "res://assets/ui/items/leche.png",
		"efecto": {"miedo": 40, "heal": 100}, "desc": "Leche tibia. Calma el miedo (40) y recupera 100 de vida."},
	"pastel_frutas": {"name": "Pastel de frutas", "kind": "comida", "icon": "res://assets/ui/items/pastel.png",
		"efecto": {"combo_temp": 90, "cansancio": 15}, "desc": "Dulce y pesado. Durante 90 segundos los remates del combo pegan el doble de fuerte."},
	# SELLOS (las cuatro fichas): mejoras permanentes.
	"sello_verde": {"name": "Sello de habilidad", "kind": "sello", "icon": "res://assets/ui/items/sello_verde.png",
		"efecto": {"habilidad": 1}, "desc": "Sube la habilidad de Elliot: +10% de daño en todos sus golpes (máximo 5 sellos)."},
	"sello_rojo": {"name": "Sello de combo", "kind": "sello", "icon": "res://assets/ui/items/sello_rojo.png",
		"efecto": {"combo": 1}, "desc": "Sube el poder del combo: +4 de daño en el tercer golpe (máximo 5 sellos)."},
	"sello_azul": {"name": "Sello de guardia", "kind": "sello", "icon": "res://assets/ui/items/sello_azul.png",
		"efecto": {"guardia": 1}, "desc": "Elliot recibe menos daño: -8% por sello (máximo 5 sellos)."},
	"sello_amarillo": {"name": "Sello de sanación", "kind": "sello", "icon": "res://assets/ui/items/sello_amarillo.png",
		"efecto": {"heal": 400, "miedo": 30}, "desc": "Cura las heridas: recupera 400 de vida y quita 30 de miedo."},
}


## true si el objeto se puede USAR desde la mochila (poción, comida o sello).
static func is_usable(id: String) -> bool:
	return String(info(id).get("kind", "objeto")) in ["pocion", "comida", "sello"]


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "kind": "objeto", "icon": "", "desc": "", "efecto": {}})
