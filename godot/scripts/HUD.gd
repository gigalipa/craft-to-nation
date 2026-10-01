extends CanvasLayer

## HUD por modos (ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md).
## Fachada única para Player y CamaraCenital: crea los widgets (barra superior,
## panel contextual, barra de modos de la cenital, hotbar de 1ª persona) y
## expone la API que los empuja. Conserva la barra de progreso, el oxígeno, la
## ficha de materiales y el panel de puesto.

## Pedidos de la barra de modos (clic): CamaraCenital los traduce a sus
## funciones _alternar_modo_*.
signal modo_pedido(modo: String)
signal categoria_pedida(categoria: String)
signal construccion_pedida(tipo: String)
signal zona_pedida(tipo: String)
## "poblacion" o "almacen" (clic en la barra superior); solo lo escucha
## CamaraCenital, que decide si tiene sentido abrir la ventana (ver dato_pedido).
signal dato_pedido(cual: String)

const COLOR_POSITIVO := Color.WHITE
const COLOR_NEGATIVO := Color(1.0, 0.3, 0.3)

const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")
const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")
const PanelContextualScript = preload("res://scripts/PanelContextual.gd")
const BarraModosScript = preload("res://scripts/BarraModos.gd")
const HotbarScript = preload("res://scripts/Hotbar.gd")
const VentanaPoblacionScript = preload("res://scripts/VentanaPoblacion.gd")
const VentanaAlmacenScript = preload("res://scripts/VentanaAlmacen.gd")
const VentanaBaulScript = preload("res://scripts/VentanaBaul.gd")
const PanelNotificacionesScript = preload("res://scripts/PanelNotificaciones.gd")

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
	"acero": "Acero",
}

const NOMBRES_TASA := {
	"caza": "caza",
	"recoleccion": "recolección",
	"pesca": "pesca",
	"frutos_mar": "frutos del mar",
}

@onready var oxigeno_label: Label = $OxigenoLabel

var _panel_puesto: PanelContainer
var _barra_progreso: ProgressBar
var _barra_superior: PanelContainer
var _contexto: PanelContainer
var _barra_modos: Control
var _hotbar: PanelContainer
var _ventana_poblacion: PanelContainer
var _ventana_almacen: PanelContainer
var _ventana_baul: PanelContainer
var _notificaciones: Control


## Los widgets se crean en _init(), no en _ready(): en Main.tscn Player y
## CamaraCenital van antes que HUDLayer, así que su _ready() (que llama a
## configurar_hotbar() y conecta las señales) corre antes que el de este nodo.
func _init() -> void:
	_barra_superior = BarraSuperiorScript.new()
	_barra_superior.dato_pedido.connect(func(cual: String) -> void: dato_pedido.emit(cual))
	add_child(_barra_superior)
	_ventana_poblacion = VentanaPoblacionScript.new()
	add_child(_ventana_poblacion)
	_ventana_almacen = VentanaAlmacenScript.new()
	add_child(_ventana_almacen)
	_ventana_baul = VentanaBaulScript.new()
	add_child(_ventana_baul)
	_contexto = PanelContextualScript.new()
	add_child(_contexto)
	_barra_modos = BarraModosScript.new()
	_barra_modos.modo_pedido.connect(func(modo: String) -> void: modo_pedido.emit(modo))
	_barra_modos.categoria_pedida.connect(func(categoria: String) -> void: categoria_pedida.emit(categoria))
	_barra_modos.construccion_pedida.connect(func(tipo: String) -> void: construccion_pedida.emit(tipo))
	_barra_modos.zona_pedida.connect(func(tipo: String) -> void: zona_pedida.emit(tipo))
	add_child(_barra_modos)
	_hotbar = HotbarScript.new()
	add_child(_hotbar)
	_panel_puesto = PanelPuestoScript.new()
	add_child(_panel_puesto)
	_notificaciones = PanelNotificacionesScript.new()
	add_child(_notificaciones)


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
	# Alto real de la hotbar (no una constante fija: se desincroniza en
	# cuanto cambia su contenido, p. ej. al pasar a íconos — reporte del
	# usuario 2026-09-30) + su propio margen respecto al borde + un hueco de 8.
	_contexto.set_margen_inferior(-_hotbar.offset_bottom + _hotbar.get_combined_minimum_size().y + 8.0 if primera_persona else 12.0)
	_contexto.ocultar()
	# Las ventanas de Población/Almacén solo tienen sentido en la cenital;
	# ocultarlas/restaurarlas conserva su posición y si el usuario las dejó
	# abiertas (ver VentanaPoblacion/VentanaAlmacen).
	if primera_persona:
		_ventana_poblacion.ocultar_temporalmente()
		_ventana_almacen.ocultar_temporalmente()
	else:
		_ventana_poblacion.restaurar()
		_ventana_almacen.restaurar()
	# La ventana del baúl solo tiene sentido junto al baúl que la abrió: al
	# cambiar de vista se cierra del todo (no se restaura, a diferencia de
	# Población/Almacén).
	_ventana_baul.cerrar()


## Crossfade entre la hotbar (1ª persona) y la barra de modos (cenital)
## mientras Main.gd anima el vuelo de cámara: la saliente se desvanece,
## set_vista() cambia la visibilidad real a medio camino (con alfa en 0, sin
## salto visible) y la entrante aparece. "a_cenital" es hacia dónde va la
## transición (mismo sentido que Main.cenital_activa).
func iniciar_transicion(a_cenital: bool, duracion: float) -> void:
	_contexto.ocultar()
	var saliente: Control = _hotbar if a_cenital else _barra_modos
	var entrante: Control = _barra_modos if a_cenital else _hotbar
	var mitad := duracion / 2.0
	var tween := create_tween()
	tween.tween_property(saliente, "modulate:a", 0.0, mitad)
	tween.tween_callback(func() -> void:
		set_vista(not a_cenital)
		entrante.modulate.a = 0.0
	)
	tween.tween_property(entrante, "modulate:a", 1.0, mitad)
	tween.tween_callback(func() -> void: saliente.modulate.a = 1.0)


func configurar_hotbar(tipos: Array) -> void:
	_hotbar.configurar(tipos)


func set_tipo_hotbar(indice: int) -> void:
	_hotbar.seleccionar(indice)


## "modo" es el id de BarraModos.MODOS ("" = Ver); "sub" el tipo de edificio
## activo (Construir) o el tipo de zona activo (Zonificar); "categoria" solo
## aplica a Construir (ver BarraModos.set_modo()).
func set_modo(modo: String, sub: String = "", categoria: String = "") -> void:
	_barra_modos.set_modo(modo, sub, categoria)


## Rotación compartida de las 5 miniaturas del submenú Construir (0-3, ver
## BarraModos.set_giros()); CamaraCenital la llama cada vez que Ctrl+rueda
## rota un puesto o un blueprint en colocación.
func set_giros_construccion(giros: int) -> void:
	_barra_modos.set_giros(giros)


func mostrar_contexto(nombre: String, costo: Dictionary, acciones: Array, valido: Variant = null, extra: String = "") -> void:
	_contexto.mostrar(nombre, costo, acciones, valido, extra)


## Panel que aparece con fade-in deslizante, se desvanece solo y no muestra
## validez (1ª persona: 1-6). Para el que debe quedarse fijo, mostrar_contexto().
func mostrar_contexto_temporal(nombre: String, costo: Dictionary, acciones: Array, segundos: float = 2.5) -> void:
	_contexto.mostrar_temporal(nombre, costo, acciones, segundos)


## Tarjeta completa (ícono, tipo/uso/obtención, disponibilidad) del bloque
## de la hotbar en "indice" (Player, al seleccionar con 1-9): la fuente de
## verdad del ícono y la disponibilidad es la propia hotbar, ya que ambos
## dependen de su estado (caché de íconos, stock actual del almacén).
func mostrar_contexto_bloque(indice: int, tipo: String) -> void:
	_contexto.mostrar_bloque_temporal(indice, tipo, _hotbar.icono_de(tipo), _hotbar.cantidad_de(indice))


func ocultar_contexto() -> void:
	_contexto.ocultar()


## Panel contextual de un puesto de recolección: costo real (ver
## CamaraCenital._resumen_materiales_puesto() — antes de esta rama era un
## placeholder fijo, "10 tierra · 10 madera · 5 piedra" para los 4 tipos por
## igual, reporte del usuario 2026-09-30), personal, almacenamiento y, en
## vivo, la recolección prevista por ciudadano según la posición del cursor.
func mostrar_contexto_puesto(tipo: String, valida: bool, tasas: Dictionary, costo: Dictionary = {}, bloques: Dictionary = {}) -> void:
	var extra := "Personal máximo: %d · Almacenamiento: %d\n%s" % [Recoleccion.cupo_de(tipo), Recoleccion.capacidad_almacen_de(tipo), texto_tasas(tipo, tasas)]
	_contexto.mostrar(PanelPuestoScript.NOMBRES_PUESTO.get(tipo, tipo), costo, ["ROTAR (Ctrl+rueda)", "COLOCAR (clic)"], valida, extra, bloques)


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
		"siderurgica":
			var t_ref: Dictionary = CadenaMinerales.tasas_refinado({"hierro": 1})["hierro"]
			return "Refinado previsto por técnico:\n  %.1f hierro + %.1f carbón/h → %.1f acero/h" % [t_ref["consumo"]["hierro"], t_ref["consumo"]["carbon"], t_ref["produccion"]]
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


## Resumen de materiales (y, para un edificio residencial, camas/baúles) en
## la línea "extra" del cuadro de información (PanelContextual). Ya no la
## usa CamaraCenital (calcula el texto con texto_materiales() y lo pasa
## directo como texto_extra de mostrar_contexto(), para que
## mostrar_contexto() no lo borre de un frame al siguiente — ver
## CamaraCenital._actualizar_previsualizacion_blueprint()); queda como
## utilidad para quien necesite actualizar solo esta línea sin volver a
## llamar mostrar(). "camas"/"baules" negativos (por defecto) los omiten.
func actualizar_materiales(neto: Dictionary, camas: int = -1, baules: int = -1) -> void:
	_contexto.set_extra(texto_materiales(neto, camas, baules))


## "neto" es material -> int (negativo = hace falta, positivo = sobra; ver
## NiveladorTerreno.resumen_materiales()). Lo necesario va sin signo y de
## mayor a menor; el sobrante recogido va después con "+". "camas"/"baules"
## >= 0 anteponen una línea de conteo (edificio residencial); negativos
## (por defecto) la omiten. "bloques" (material -> cantidad de bloques
## reales de pared/estructura, ver NiveladorTerreno.contar_bloques()) suma
## "(N bloques)" a lo NECESARIO cuando hay conteo para ese material — el
## jugador pide el recurso crudo (madera) y cuántos bloques colocados
## representa (bloque_madera), no solo uno de los dos (reporte del usuario,
## 2026-09-30). Sin "bloques" (default {}), el texto es igual que siempre.
static func texto_materiales(neto: Dictionary, camas: int = -1, baules: int = -1, bloques: Dictionary = {}) -> String:
	var necesarios: Array = []
	var sobrantes: Array = []
	for material in neto:
		var cantidad: int = neto[material]
		if cantidad < 0:
			necesarios.append([-cantidad, material])
		elif cantidad > 0:
			sobrantes.append("+ %d %s" % [cantidad, material])
	necesarios.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lineas: Array = []
	if camas >= 0 or baules >= 0:
		lineas.append("Camas: %d · Baúles: %d" % [max(camas, 0), max(baules, 0)])
	lineas.append("Materiales de construcción:")
	var inicio_materiales := lineas.size()
	for necesario in necesarios:
		var cantidad: int = necesario[0]
		var material: String = necesario[1]
		if bloques.has(material):
			lineas.append("%d %s (%d bloques)" % [cantidad, material, bloques[material]])
		else:
			lineas.append("%d %s" % [cantidad, material])
	lineas.append_array(sobrantes)
	if lineas.size() == inicio_materiales:
		lineas.append("-")
	return "\n".join(lineas)


## "cual" es "poblacion" o "almacen". Ambas ventanas pueden estar abiertas a
## la vez (decisión del usuario, 2026-09-27): cada una se coloca por defecto
## en su propia esquina (ver POSICION_INICIAL de cada una) para no solaparse.
func abrir_ventana_dato(cual: String) -> void:
	if cual == "poblacion":
		_ventana_poblacion.abrir()
	elif cual == "almacen":
		_ventana_almacen.abrir()


func abrir_panel_puesto(esquina: Vector2i) -> void:
	_panel_puesto.abrir(esquina)


func cerrar_panel_puesto() -> void:
	_panel_puesto.cerrar()


## Ventana de interacción del baúl (E apuntando al depósito de un puesto,
## ver Player._interactuar()).
func abrir_ventana_baul(esquina: Vector2i) -> void:
	_ventana_baul.abrir(esquina)


func cerrar_ventana_baul() -> void:
	_ventana_baul.cerrar()


## Muestra la barra de progreso bajo la mira. "retrocede" (tala, deconstrucción)
## la pinta en naranja: indica lo que le queda a lo que se está desmontando.
func mostrar_progreso(fraccion: float, retrocede: bool = false) -> void:
	_barra_progreso.value = clampf(fraccion, 0.0, 1.0) * 100.0
	_barra_progreso.modulate = Color(1.0, 0.6, 0.2) if retrocede else Color(0.4, 1.0, 0.4)
	_barra_progreso.visible = true


func ocultar_progreso() -> void:
	_barra_progreso.visible = false


## Notificación emergente, esquina superior derecha (ver PanelNotificaciones):
## eventos puntuales del juego (colocación rechazada, edificio construido,
## nuevo colono, etc.), no estado continuo.
func notificar(texto: String) -> void:
	_notificaciones.notificar(texto)
