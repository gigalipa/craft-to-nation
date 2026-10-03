extends PanelContainer

## Panel de un puesto de recolección (clic izquierdo sobre él en la cenital,
## ver CamaraCenital._procesar_clic). Se construye por código: título, filas
## "Obreros/Técnicos/Especialistas/Aprendices [-] n [+] (libres)" y "Acarreadores ...", el título muestra el
## nivel del puesto; además almacén local, producción y distancia al núcleo. Las reglas viven en
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
## Mensaje para el jugador (el HUD lo envía a las notificaciones).
signal aviso(texto: String)

const NOMBRES_ROL := {"recolector": "Obreros", "tecnico": "Técnicos", "especialista": "Especialistas", "aprendiz": "Aprendices", "acarreador": "Acarreadores"}

var esquina := Recoleccion.SIN_PUESTO

var _titulo := TemaHUD.etiqueta()
var _trabajadores := TemaHUD.etiqueta()
var _libres := TemaHUD.etiqueta()
var _almacen := TemaHUD.etiqueta()
var _produccion := TemaHUD.etiqueta()
var _distancia := TemaHUD.etiqueta()
var _demoler := Button.new()
var _filas := {}  # rol -> {"fila": HBoxContainer, "cantidad": Label, "menos": Button, "mas": Button, "libres": Label}


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP  # los botones +/- necesitan capturar el clic
	# Abajo a la derecha: arriba las notificaciones ocupan ese lugar (decisión del usuario, 2026-10-02).
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -280.0
	offset_bottom = -12.0
	offset_right = -12.0
	custom_minimum_size.x = 268.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN  # si crece, hacia la izquierda
	grow_vertical = Control.GROW_DIRECTION_BEGIN  # y hacia arriba
	var caja := VBoxContainer.new()
	add_child(caja)
	_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	caja.add_child(_titulo)
	for rol in ["recolector", "tecnico", "especialista", "aprendiz", "acarreador"]:
		caja.add_child(_crear_fila(rol))
	for etiqueta in [_trabajadores, _libres, _almacen, _produccion, _distancia]:
		# Las líneas largas (varios recursos) parten en vez de ensanchar el panel.
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)
	TemaHUD.estilizar_boton(_demoler)
	_demoler.pressed.connect(_on_demoler)
	caja.add_child(_demoler)


func _crear_fila(rol: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var nombre := TemaHUD.etiqueta(NOMBRES_ROL[rol])
	nombre.custom_minimum_size.x = 96.0
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
	var libres := TemaHUD.etiqueta()
	libres.custom_minimum_size.x = 70.0
	for nodo in [nombre, menos, cantidad, mas, libres]:
		fila.add_child(nodo)
	_filas[rol] = {"fila": fila, "cantidad": cantidad, "menos": menos, "mas": mas, "libres": libres}
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
	var con_niveles: bool = Economia.tiene_niveles(esquina)
	# Oficios que producen aquí: aprendices en la escuela, solo técnicos en la refinería, los tres oficios en los puestos con niveles.
	var oficios: Array = ["aprendiz"] if es_escuela else (["recolector", "tecnico", "especialista"] if con_niveles else ["tecnico"])
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	var nivel := ", nivel %d" % Economia.nivel_de(esquina) if con_niveles else ""
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"]) + nivel + estado
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0
	for rol in ["recolector", "tecnico", "especialista", "aprendiz"]:
		var fila: Dictionary = _filas[rol]
		var empleados: int = _empleados(rol, t, con_niveles)
		var libres: int = _libres_de(rol)
		fila["fila"].visible = oficios.has(rol) and (rol != "especialista" or libres > 0 or empleados > 0)
		fila["cantidad"].text = str(empleados)
		fila["libres"].text = "(%d libres)" % libres
		fila["menos"].disabled = empleados == 0
		fila["mas"].disabled = sin_cupo or libres <= 0 or not puesto["activo"] or not Economia.admite_rol(esquina, rol)
	var acarreadores: Dictionary = _filas["acarreador"]
	acarreadores["fila"].visible = not es_escuela  # una escuela no mueve recursos
	acarreadores["cantidad"].text = str(t["acarreadores"])
	acarreadores["libres"].text = "(%d libres)" % Ciudad.demografia["desempleado"]
	acarreadores["menos"].disabled = t["acarreadores"] == 0
	acarreadores["mas"].disabled = sin_cupo or Ciudad.demografia["desempleado"] <= 0 or not puesto["activo"]
	if es_escuela:
		_trabajadores.text = "Aprendices: %d / %d (presentes: %d)\nFormación de la cohorte: %d / %d h" % [t["recolectores"], puesto["cupo"], t["presentes"], int(puesto["progreso"]), Economia.HORAS_FORMACION]
	else:
		_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	# Solo la refinería necesita la pista de dónde salen sus técnicos.
	_libres.visible = not es_escuela and not con_niveles and Colonos.tecnicos_libres() == 0
	_libres.text = "Sin técnicos libres: fórmalos en una escuela técnica"
	_almacen.visible = not es_escuela
	_produccion.visible = not es_escuela
	_almacen.text = "Almacén local: " + _texto_recursos(Economia.almacen_local(esquina), "vacío") + " (máx. %d)" % puesto["capacidad"]
	_produccion.text = "Producción: " + _texto_recursos(Economia.produccion_por_hora(esquina), "ninguna", "/h")
	_distancia.text = "Distancia al núcleo: %s" % _distancia_al_nucleo()
	_demoler.text = "Cancelar demolición" if Obras.esta_marcado(Obras.id_en_columna(esquina)) else "Demoler"


## Cuántos del oficio "rol" trabajan en el puesto: en los puestos con niveles se cuenta por rango; en la
## refinería y la escuela, todos sus recolectores (técnicos o aprendices).
func _empleados(rol: String, t: Dictionary, con_niveles: bool) -> int:
	if con_niveles:
		return Economia.contar_rango(esquina, Economia.RANGO_DE_ROL.get(rol, 0))
	return t["recolectores"]


## Colonos libres de ese oficio que se podrían contratar: técnicos y especialistas libres, o desempleados.
func _libres_de(rol: String) -> int:
	match rol:
		"tecnico": return Colonos.tecnicos_libres()
		"especialista": return Colonos.especialistas_libres()
	return Ciudad.demografia["desempleado"]


## Marca (o desmarca) el edificio del puesto para demolición, sin activar la herramienta.
func _on_demoler() -> void:
	var id: int = Obras.id_en_columna(esquina)
	if id == -1:
		aviso.emit("No se encontró el edificio del puesto.")
		return
	var motivo: String = Obras.alternar_marca(id)
	if motivo != "":
		aviso.emit(motivo)


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
