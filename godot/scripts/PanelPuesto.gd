extends PanelContainer

## Panel de un puesto de recolección (clic izquierdo sobre él en la cenital,
## ver CamaraCenital._procesar_clic). Se construye por código: título, filas
## "Recolectores [-] n [+]" y "Acarreadores [-] n [+]", desempleados libres,
## almacén local, producción y distancia al núcleo. Las reglas viven en
## Economia/Colonos; esto solo las muestra y les pasa los clics.

const HUDScript = preload("res://scripts/HUD.gd")

const NOMBRES_PUESTO := {
	"mina": "Mina",
	"caza_recoleccion": "Caza y recolección",
	"maderero": "Puesto maderero",
	"pesca_frutos_mar": "Pesca y frutos del mar",
}

var esquina := Recoleccion.SIN_PUESTO

var _titulo := Label.new()
var _trabajadores := Label.new()
var _libres := Label.new()
var _almacen := Label.new()
var _produccion := Label.new()
var _distancia := Label.new()
var _filas := {}  # rol -> {"cantidad": Label, "menos": Button, "mas": Button}


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -280.0
	offset_top = 12.0
	offset_right = -12.0
	custom_minimum_size.x = 268.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN  # si crece, hacia la izquierda
	var caja := VBoxContainer.new()
	add_child(caja)
	caja.add_child(_titulo)
	for rol in ["recolector", "acarreador"]:
		caja.add_child(_crear_fila(rol))
	for etiqueta in [_trabajadores, _libres, _almacen, _produccion, _distancia]:
		# Las líneas largas (varios recursos) parten en vez de ensanchar el panel.
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)


func _crear_fila(rol: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = "Recolectores" if rol == "recolector" else "Acarreadores"
	nombre.custom_minimum_size.x = 110.0
	var menos := Button.new()
	menos.text = "-"
	menos.pressed.connect(func() -> void: Colonos.despedir(esquina, rol))
	var cantidad := Label.new()
	cantidad.custom_minimum_size.x = 24.0
	cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mas := Button.new()
	mas.text = "+"
	mas.pressed.connect(func() -> void: Colonos.contratar(esquina, rol))
	for nodo in [nombre, menos, cantidad, mas]:
		fila.add_child(nodo)
	_filas[rol] = {"cantidad": cantidad, "menos": menos, "mas": mas}
	return fila


func abrir(nueva_esquina: Vector2i) -> void:
	if not Economia.tiene_puesto(nueva_esquina):
		return
	esquina = nueva_esquina
	visible = true
	_actualizar()


func cerrar() -> void:
	visible = false
	esquina = Recoleccion.SIN_PUESTO


func _process(_delta: float) -> void:
	if not visible:
		return
	if not Economia.tiene_puesto(esquina):
		cerrar()  # el puesto se deconstruyó con el panel abierto
		return
	_actualizar()


func _actualizar() -> void:
	var puesto: Dictionary = Economia.puestos[esquina]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var libres: int = Ciudad.demografia["desempleado"]
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"])
	_filas["recolector"]["cantidad"].text = str(t["recolectores"])
	_filas["acarreador"]["cantidad"].text = str(t["acarreadores"])
	_filas["recolector"]["menos"].disabled = t["recolectores"] == 0
	_filas["acarreador"]["menos"].disabled = t["acarreadores"] == 0
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0 or libres <= 0
	_filas["recolector"]["mas"].disabled = sin_cupo
	_filas["acarreador"]["mas"].disabled = sin_cupo
	_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	_libres.text = "Desempleados libres: %d" % libres
	_almacen.text = "Almacén local: " + _texto_recursos(Economia.almacen_local(esquina), "vacío") + " (máx. %d)" % puesto["capacidad"]
	_produccion.text = "Producción: " + _texto_recursos(Economia.produccion_por_hora(esquina), "ninguna", "/h")
	_distancia.text = "Distancia al núcleo: %s" % _distancia_al_nucleo()


static func _texto_recursos(recursos: Dictionary, vacio: String, sufijo: String = "") -> String:
	var partes: Array = []
	for recurso in recursos:
		partes.append("%.1f %s%s" % [recursos[recurso], HUDScript.NOMBRES_RECURSO.get(recurso, recurso), sufijo])
	return ", ".join(partes) if not partes.is_empty() else vacio


## Celdas (en línea recta sobre X,Z) entre el centro del puesto y el centro del
## núcleo; "-" si todavía no hay núcleo.
func _distancia_al_nucleo() -> String:
	var nucleo: Array = Zonificacion.huella_del_nucleo()
	if nucleo.is_empty():
		return "-"
	var suma := Vector2.ZERO
	for celda: Vector2i in nucleo:
		suma += Vector2(celda)
	var centro_nucleo: Vector2 = suma / nucleo.size()
	var puesto: Dictionary = Economia.puestos[esquina]
	var centro_puesto := Vector2(esquina) + Vector2(puesto["ancho"], puesto["alto"]) / 2.0
	return "%d celdas" % roundi(centro_nucleo.distance_to(centro_puesto))
