extends PanelContainer

## Panel de un puesto de recolección (clic izquierdo sobre él en la cenital,
## ver CamaraCenital._procesar_clic). Se construye por código: título, filas
## "Recolectores/Técnicos/Aprendices [-] n [+]" y "Acarreadores [-] n [+]", desempleados/técnicos libres,
## almacén local, producción y distancia al núcleo. Las reglas viven en
## Economia/Colonos; esto solo las muestra y les pasa los clics.

const HUDScript = preload("res://scripts/HUD.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")

const NOMBRES_PUESTO := {
	"mina": "Mina",
	"caza_recoleccion": "Caza y recolección",
	"maderero": "Puesto maderero",
	"pesca_frutos_mar": "Pesca y frutos del mar",
	"siderurgica": "Siderúrgica",
	"refineria_tierras_raras": "Refinería de tierras raras",
	"aserradero": "Aserradero",
	"carbonera": "Carbonera",
	"escuela_tecnica": "Escuela técnica",
}
const NOMBRES_ROL := {"recolector": "Recolectores", "tecnico": "Técnicos", "aprendiz": "Aprendices", "acarreador": "Acarreadores"}

var esquina := Recoleccion.SIN_PUESTO

var _titulo := TemaHUD.etiqueta()
var _trabajadores := TemaHUD.etiqueta()
var _libres := TemaHUD.etiqueta()
var _almacen := TemaHUD.etiqueta()
var _produccion := TemaHUD.etiqueta()
var _distancia := TemaHUD.etiqueta()
var _filas := {}  # rol -> {"cantidad": Label, "menos": Button, "mas": Button}


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP  # los botones +/- necesitan capturar el clic
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -280.0
	offset_top = 72.0
	offset_right = -12.0
	custom_minimum_size.x = 268.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN  # si crece, hacia la izquierda
	var caja := VBoxContainer.new()
	add_child(caja)
	_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	caja.add_child(_titulo)
	for rol in ["recolector", "tecnico", "aprendiz", "acarreador"]:
		caja.add_child(_crear_fila(rol))
	for etiqueta in [_trabajadores, _libres, _almacen, _produccion, _distancia]:
		# Las líneas largas (varios recursos) parten en vez de ensanchar el panel.
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)


func _crear_fila(rol: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var nombre := TemaHUD.etiqueta(NOMBRES_ROL[rol])
	nombre.custom_minimum_size.x = 110.0
	var menos := Button.new()
	menos.text = "-"
	menos.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(menos)
	menos.pressed.connect(func() -> void: Colonos.despedir(esquina, rol))
	var cantidad := TemaHUD.etiqueta()
	cantidad.custom_minimum_size.x = 24.0
	cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mas := Button.new()
	mas.text = "+"
	mas.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(mas)
	mas.pressed.connect(func() -> void: Colonos.contratar(esquina, rol))
	for nodo in [nombre, menos, cantidad, mas]:
		fila.add_child(nodo)
	_filas[rol] = {"fila": fila, "cantidad": cantidad, "menos": menos, "mas": mas}
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
	var es_escuela: bool = Economia.es_escuela(esquina)
	var rol_produccion := "aprendiz" if es_escuela else ("tecnico" if Economia.es_refineria(esquina) else "recolector")
	# Quién se puede contratar: técnicos libres (formados en la escuela) para una refinería, desempleados para el resto.
	var libres: int = Colonos.tecnicos_libres() if rol_produccion == "tecnico" else Ciudad.demografia["desempleado"]
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"]) + estado
	for rol in ["recolector", "tecnico", "aprendiz"]:
		_filas[rol]["fila"].visible = rol == rol_produccion
	_filas["acarreador"]["fila"].visible = not es_escuela  # una escuela no mueve recursos
	_filas[rol_produccion]["cantidad"].text = str(t["recolectores"])  # técnicos y aprendices cuentan bajo "recolectores"
	_filas["acarreador"]["cantidad"].text = str(t["acarreadores"])
	_filas[rol_produccion]["menos"].disabled = t["recolectores"] == 0
	_filas["acarreador"]["menos"].disabled = t["acarreadores"] == 0
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0
	_filas[rol_produccion]["mas"].disabled = sin_cupo or libres <= 0 or not puesto["activo"] or puesto["agotado"]
	_filas["acarreador"]["mas"].disabled = sin_cupo or Ciudad.demografia["desempleado"] <= 0 or not puesto["activo"]
	if es_escuela:
		_trabajadores.text = "Aprendices: %d / %d (presentes: %d)\nFormación de la cohorte: %d / %d h" % [t["recolectores"], puesto["cupo"], t["presentes"], int(puesto["progreso"]), Economia.HORAS_FORMACION]
	else:
		_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	if rol_produccion == "tecnico":
		_libres.text = "Técnicos libres: %d" % libres if libres > 0 else "Técnicos libres: 0 (fórmalos en una escuela técnica)"
	else:
		_libres.text = "Desempleados libres: %d" % libres
	_almacen.visible = not es_escuela
	_produccion.visible = not es_escuela
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
