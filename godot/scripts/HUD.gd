extends CanvasLayer

## HUD por modos (ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md).
## Fachada única para Player y CamaraCenital: crea los widgets (barra superior,
## panel contextual, barra de modos de la cenital, hotbar de 1ª persona) y
## expone la API que los empuja. Conserva la barra de progreso, el oxígeno, la
## ficha de materiales y el panel de puesto.

## Pedidos de la barra de modos (clic): CamaraCenital los traduce a sus
## funciones _alternar_modo_*.
signal modo_pedido(modo: String)
signal puesto_pedido(tipo: String)

const COLOR_POSITIVO := Color.WHITE
const COLOR_NEGATIVO := Color(1.0, 0.3, 0.3)

const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")
const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")
const PanelContextualScript = preload("res://scripts/PanelContextual.gd")
const BarraModosScript = preload("res://scripts/BarraModos.gd")
const HotbarScript = preload("res://scripts/Hotbar.gd")

## Nombres de todos los recursos del almacén (los usa PanelPuesto).
const NOMBRES_RECURSO := {
	"comida": "Comida",
	"madera": "Madera",
	"hierro": "Hierro",
	"tierra": "Tierra",
	"piedra": "Piedra",
	"cobre": "Cobre",
	"carbon": "Carbón",
	"tierras_raras": "Tierras raras",
}

const NOMBRES_TASA := {
	"caza": "caza",
	"recoleccion": "recolección",
	"pesca": "pesca",
	"frutos_mar": "frutos del mar",
}

@onready var oxigeno_label: Label = $OxigenoLabel
@onready var materiales_ficha: Label = $MaterialesFicha

var _panel_puesto: PanelContainer
var _barra_progreso: ProgressBar
var _barra_superior: PanelContainer
var _contexto: PanelContainer
var _barra_modos: PanelContainer
var _hotbar: PanelContainer


## Los widgets se crean en _init(), no en _ready(): en Main.tscn Player y
## CamaraCenital van antes que HUDLayer, así que su _ready() (que llama a
## configurar_hotbar() y conecta las señales) corre antes que el de este nodo.
func _init() -> void:
	_barra_superior = BarraSuperiorScript.new()
	add_child(_barra_superior)
	_contexto = PanelContextualScript.new()
	add_child(_contexto)
	_barra_modos = BarraModosScript.new()
	_barra_modos.modo_pedido.connect(func(modo: String) -> void: modo_pedido.emit(modo))
	_barra_modos.puesto_pedido.connect(func(tipo: String) -> void: puesto_pedido.emit(tipo))
	add_child(_barra_modos)
	_hotbar = HotbarScript.new()
	add_child(_hotbar)
	_panel_puesto = PanelPuestoScript.new()
	add_child(_panel_puesto)


func _ready() -> void:
	set_vista(true)  # la partida empieza en 1ª persona

	# Barra de progreso de minar/talar/recolectar/deconstruir, bajo la mira.
	_barra_progreso = ProgressBar.new()
	_barra_progreso.show_percentage = false
	_barra_progreso.set_anchors_preset(Control.PRESET_CENTER)
	_barra_progreso.offset_left = -90
	_barra_progreso.offset_right = 90
	_barra_progreso.offset_top = 40
	_barra_progreso.offset_bottom = 54
	_barra_progreso.visible = false
	add_child(_barra_progreso)


## true = 1ª persona (hotbar), false = cenital (barra de modos). Cambiar de
## vista descarta el panel contextual; quien lo alimenta lo vuelve a empujar.
func set_vista(primera_persona: bool) -> void:
	_hotbar.visible = primera_persona
	_barra_modos.visible = not primera_persona
	_contexto.set_margen_inferior(84.0 if primera_persona else 12.0)
	_contexto.ocultar()


func configurar_hotbar(tipos: Array) -> void:
	_hotbar.configurar(tipos)


func set_tipo_hotbar(indice: int) -> void:
	_hotbar.seleccionar(indice)


## "modo" es el id de BarraModos.MODOS ("" = Ver); "puesto" el tipo activo si es "puestos".
func set_modo(modo: String, puesto: String = "") -> void:
	_barra_modos.set_modo(modo, puesto)


func mostrar_contexto(nombre: String, costo: Dictionary, acciones: Array, valido: Variant = null, extra: String = "") -> void:
	_contexto.mostrar(nombre, costo, acciones, valido, extra)


func ocultar_contexto() -> void:
	_contexto.ocultar()


## Panel contextual de un puesto de recolección: costo, personal, almacenamiento
## y, en vivo, la recolección prevista por ciudadano según la posición del cursor.
func mostrar_contexto_puesto(tipo: String, valida: bool, tasas: Dictionary) -> void:
	var extra := "Personal máximo: %d · Almacenamiento: %d\n%s" % [Recoleccion.cupo_de(tipo), Recoleccion.capacidad_almacen_de(tipo), texto_tasas(tipo, tasas)]
	_contexto.mostrar(PanelPuestoScript.NOMBRES_PUESTO.get(tipo, tipo), costo_de_puesto(tipo), ["ROTAR (Ctrl+rueda)", "COLOCAR (clic)"], valida, extra)


static func costo_de_puesto(tipo: String) -> Dictionary:
	match tipo:
		"mina": return Recoleccion.COSTO_CONSTRUCCION
		"caza_recoleccion": return Recoleccion.COSTO_CONSTRUCCION_CAZA_RECOLECCION
		"maderero": return Recoleccion.COSTO_CONSTRUCCION_MADERERO
		"pesca_frutos_mar": return Recoleccion.COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR
	return {}


## Recolección prevista de un puesto. Diccionario vacío = nada detectado (en
## pesca también cuando el extremo de agua todavía no es válido).
static func texto_tasas(tipo: String, tasas: Dictionary) -> String:
	match tipo:
		"mina":
			if tasas.is_empty():
				return "Recolección prevista: sin recursos detectados"
			var lineas: Array = []
			for recurso in tasas:
				lineas.append("%.1f %s/h" % [tasas[recurso], recurso])
			return "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)
		"maderero":
			if tasas.get("madera", 0.0) <= 0.0:
				return "Recolección prevista: sin árboles detectados"
			return "Recolección prevista por ciudadano:\n  %.1f madera/h" % tasas["madera"]
		"caza_recoleccion":
			if tasas.get("caza", 0.0) <= 0.0 and tasas.get("recoleccion", 0.0) <= 0.0:
				return "Recolección prevista: sin fauna ni fruta detectada"
		"pesca_frutos_mar":
			if tasas.get("pesca", 0.0) <= 0.0 and tasas.get("frutos_mar", 0.0) <= 0.0:
				return "Recolección prevista: sin agua detectada"
	var lineas_comida: Array = []
	for clave in tasas:
		lineas_comida.append("%.1f comida/h por %s" % [tasas[clave], NOMBRES_TASA.get(clave, clave)])
	return "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas_comida)


## Llamada cada física por Player._procesar_oxigeno() mientras el jugador
## está en agua o recuperando aire — oculta con ocultar_oxigeno() en cuanto
## vuelve a estar a full fuera del agua, para no saturar el HUD en seco.
func actualizar_oxigeno(fraccion: float) -> void:
	oxigeno_label.text = "Oxígeno: %d%%" % round(fraccion * 100)
	oxigeno_label.modulate = COLOR_NEGATIVO if fraccion < 0.3 else COLOR_POSITIVO
	oxigeno_label.visible = true


func ocultar_oxigeno() -> void:
	oxigeno_label.visible = false


## Ficha VISUAL de los materiales que movilizaría el blueprint activo (ver
## docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md):
## no lee ni toca ningún inventario real (no existe todavía).
func mostrar_ficha_materiales() -> void:
	materiales_ficha.text = texto_materiales({})
	materiales_ficha.visible = true


func actualizar_materiales(neto: Dictionary) -> void:
	materiales_ficha.text = texto_materiales(neto)


func ocultar_ficha_materiales() -> void:
	materiales_ficha.visible = false


## "neto" es material -> int (negativo = hace falta, positivo = sobra; ver
## NiveladorTerreno.resumen_materiales()). Lo necesario va sin signo y de
## mayor a menor; el sobrante recogido va después con "+".
static func texto_materiales(neto: Dictionary) -> String:
	var necesarios: Array = []
	var sobrantes: Array = []
	for material in neto:
		var cantidad: int = neto[material]
		if cantidad < 0:
			necesarios.append([-cantidad, material])
		elif cantidad > 0:
			sobrantes.append("+ %d %s" % [cantidad, material])
	necesarios.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lineas: Array = ["Materiales de construcción:"]
	for necesario in necesarios:
		lineas.append("%d %s" % [necesario[0], necesario[1]])
	lineas.append_array(sobrantes)
	if lineas.size() == 1:
		lineas.append("-")
	return "\n".join(lineas)


func abrir_panel_puesto(esquina: Vector2i) -> void:
	_panel_puesto.abrir(esquina)


func cerrar_panel_puesto() -> void:
	_panel_puesto.cerrar()


## Muestra la barra de progreso bajo la mira. "retrocede" (tala, deconstrucción)
## la pinta en naranja: indica lo que le queda a lo que se está desmontando.
func mostrar_progreso(fraccion: float, retrocede: bool = false) -> void:
	_barra_progreso.value = clampf(fraccion, 0.0, 1.0) * 100.0
	_barra_progreso.modulate = Color(1.0, 0.6, 0.2) if retrocede else Color(0.4, 1.0, 0.4)
	_barra_progreso.visible = true


func ocultar_progreso() -> void:
	_barra_progreso.visible = false
