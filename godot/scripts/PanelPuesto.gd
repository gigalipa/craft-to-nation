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
	"escuela_especialistas": "Escuela de especialistas",
	"universidad": "Universidad",
	"refineria_petrolera": "Refinería petrolera",
	"productor_combustible": "Productor de combustible",
	"central_termoelectrica": "Central termoeléctrica",
}
## Mensaje para el jugador (el HUD lo envía a las notificaciones).
signal aviso(texto: String)

const NOMBRES_ROL := {"recolector": "Obreros", "tecnico": "Técnicos", "especialista": "Especialistas", "aprendiz": "Aprendices", "investigador": "Investigadores", "acarreador": "Acarreadores"}

var esquina := Recoleccion.SIN_PUESTO

var _titulo := TemaHUD.etiqueta()
var _trabajadores := TemaHUD.etiqueta()
var _libres := TemaHUD.etiqueta()
var _almacen := TemaHUD.etiqueta()
var _produccion := TemaHUD.etiqueta()
var _energia := TemaHUD.etiqueta()
var _distancia := TemaHUD.etiqueta()
var _demoler := Button.new()
var _dialogo_demoler := ConfirmationDialog.new()
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
	for rol in ["recolector", "tecnico", "especialista", "aprendiz", "investigador", "acarreador"]:
		caja.add_child(_crear_fila(rol))
	for etiqueta in [_trabajadores, _libres, _almacen, _produccion, _energia, _distancia]:
		# Las líneas largas (varios recursos) parten en vez de ensanchar el panel.
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)
	TemaHUD.estilizar_boton(_demoler)
	_demoler.pressed.connect(_on_demoler)
	caja.add_child(_demoler)
	_dialogo_demoler.title = "Confirmar demolición"
	_dialogo_demoler.dialog_text = "¿Demoler este puesto? Comenzará en 5 horas de juego."
	_dialogo_demoler.ok_button_text = "Confirmar"
	_dialogo_demoler.cancel_button_text = "Cancelar"
	_dialogo_demoler.confirmed.connect(_confirmar_demoler)
	TemaHUD.estilizar_dialogo(_dialogo_demoler)
	add_child(_dialogo_demoler)


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
	_filas[rol] = {"fila": fila, "nombre": nombre, "cantidad": cantidad, "menos": menos, "mas": mas, "libres": libres}
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
	var es_universidad: bool = Economia.es_universidad(esquina)
	var con_niveles: bool = Economia.tiene_niveles(esquina)
	# Oficios que producen aquí: investigadores en la universidad, aprendices en la escuela, solo técnicos en la refinería, los tres oficios en los puestos con niveles.
	var oficios: Array = ["investigador"] if es_universidad else (["aprendiz"] if es_escuela else (["recolector", "tecnico", "especialista"] if con_niveles else ["tecnico"]))
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	var nivel := ", nivel %d" % Economia.nivel_de(esquina) if con_niveles else ""
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"]) + nivel + estado
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0
	var origen_escuela: String = Recoleccion.ESCUELAS[puesto["tipo"]]["origen"] if es_escuela else ""
	var nombre_aprendiz: String = "Técnicos en formación" if origen_escuela == "tecnico" else "Aprendices"
	_filas["aprendiz"]["nombre"].text = nombre_aprendiz
	for rol in ["recolector", "tecnico", "especialista", "aprendiz", "investigador"]:
		var fila: Dictionary = _filas[rol]
		if rol != "aprendiz" or not es_escuela:
			fila["nombre"].text = NOMBRES_ROL[rol]
		var empleados: int = _empleados(rol, t, con_niveles)
		var libres: int = _libres_de(rol)
		fila["fila"].visible = oficios.has(rol)
		fila["cantidad"].text = str(empleados)
		fila["libres"].text = "(%d libres)" % libres
		fila["menos"].disabled = empleados == 0
		var limite_inv: bool = (rol == "investigador" and not Ciudad.COSTOS_INVESTIGACION.has(Ciudad.nivel_investigado + 1))
		fila["mas"].disabled = sin_cupo or libres <= 0 or not puesto["activo"] or not Economia.admite_rol(esquina, rol) or limite_inv
	var acarreadores: Dictionary = _filas["acarreador"]
	acarreadores["fila"].visible = not es_escuela and not es_universidad  # ni una escuela ni una universidad mueven recursos
	acarreadores["cantidad"].text = str(t["acarreadores"])
	acarreadores["libres"].text = "(%d libres)" % Ciudad.demografia["desempleado"]
	acarreadores["menos"].disabled = t["acarreadores"] == 0
	acarreadores["mas"].disabled = sin_cupo or Ciudad.demografia["desempleado"] <= 0 or not puesto["activo"]
	if es_universidad:
		var siguiente: int = Ciudad.nivel_investigado + 1
		if Ciudad.COSTOS_INVESTIGACION.has(siguiente):
			var info_inv: Dictionary = Ciudad.COSTOS_INVESTIGACION[siguiente]
			var req: String = "Técnicos o especialistas" if siguiente == 2 else "Especialistas"
			var prog: float = Ciudad.progreso_investigacion.get(siguiente, 0.0)
			var meta: float = float(info_inv["horas_investigador"])
			_trabajadores.text = "Investigadores: %d / %d (presentes: %d)\nProyecto: %s (Nivel %d)\nRequisito: %s\nProgreso: %.1f / %.1f h\nCostos: %d hierro, %d madera" % [t["recolectores"], puesto["cupo"], t["presentes"], info_inv["nombre"], siguiente, req, prog, meta, info_inv["hierro"], info_inv["madera"]]
		else:
			_trabajadores.text = "Investigadores: %d / %d (presentes: %d)\nTodas las investigaciones completadas" % [t["recolectores"], puesto["cupo"], t["presentes"]]
	elif es_escuela:
		var horas: int = Recoleccion.ESCUELAS[puesto["tipo"]]["horas"]
		_trabajadores.text = "%s: %d / %d (presentes: %d)\nFormación de la cohorte: %d / %d h" % [nombre_aprendiz, t["recolectores"], puesto["cupo"], t["presentes"], int(puesto["progreso"]), horas]
	else:
		_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	var siguiente_inv: int = Ciudad.nivel_investigado + 1
	var sin_candidatos_inv: bool = es_universidad and _libres_de("investigador") == 0 and Ciudad.COSTOS_INVESTIGACION.has(siguiente_inv)
	_libres.visible = (not es_escuela and not con_niveles and not es_universidad and Colonos.tecnicos_libres() == 0) or sin_candidatos_inv
	if sin_candidatos_inv:
		_libres.text = "Sin candidatos libres: requiere %s" % ("técnicos o especialistas" if siguiente_inv == 2 else "especialistas")
	else:
		_libres.text = "Sin técnicos libres: fórmalos en una escuela técnica"
	_almacen.visible = not es_escuela and not es_universidad
	_produccion.visible = not es_escuela and not es_universidad and puesto["tipo"] != "central_termoelectrica"
	_almacen.text = "Almacén local: " + _texto_recursos(Economia.almacen_local(esquina), "vacío") + " (máx. %d)" % puesto["capacidad"]
	_produccion.text = "Producción: " + _texto_recursos(Economia.produccion_por_hora(esquina), "ninguna", "/h")

	if puesto["tipo"] == "central_termoelectrica":
		_energia.visible = true
		var t_pres: int = t["presentes"]
		var alm: Dictionary = puesto["almacen"]
		var stock: float = alm.get("combustible", 0.0) + alm.get("crudo", 0.0) + alm.get("carbon", 0.0)
		var cap_esta: float = minf(float(t_pres), stock) * 20.0
		var res: Dictionary = Economia.balance_energia
		var cap_total: float = res.get("capacidad", 0.0)
		var entregada_total: float = res.get("entregada", 0.0)
		var uso: float = 0.0
		if cap_total > 1e-9:
			uso = entregada_total * (cap_esta / cap_total)
		var comb_actual := "ninguno"
		for c in ["combustible", "crudo", "carbon"]:
			if alm.get(c, 0.0) > 1e-9:
				comb_actual = "%s (%.1f)" % [HUDScript.NOMBRES_RECURSO.get(c, c), alm[c]]
				break
		_energia.text = "Capacidad: %.0f E/h\nGeneración usada: %.1f E/h\nCombustible actual: %s" % [cap_esta, uso, comb_actual]
	elif puesto["tipo"] == "refineria_petrolera" or puesto["tipo"] == "productor_combustible" or es_universidad:
		_energia.visible = true
		var res: Dictionary = Economia.balance_energia
		var conectados: Dictionary = res.get("conectados", {})
		var conectado: bool = conectados.get(esquina, false)
		var demanda: float = 0.0
		if puesto["tipo"] == "refineria_petrolera" or puesto["tipo"] == "productor_combustible":
			demanda = float(t["presentes"]) * 1.0
		elif es_universidad and Ciudad.nivel_investigado + 1 == 3:
			demanda = float(t["presentes"]) * 2.0
		var factor: float = Economia.factor_energia_de(esquina)
		var cap_red: float = res.get("capacidad", 0.0)
		var estado_e: String = texto_estado_energia(conectado, demanda, factor, cap_red)
		_energia.text = "Energía: %s" % estado_e
	else:
		_energia.visible = false

	_distancia.text = "Distancia al núcleo: %s" % _distancia_al_nucleo()
	var id_puesto: int = Obras.id_en_columna(esquina)
	var en_demo: bool = Obras.esta_marcado(id_puesto) or Obras.esta_programada(id_puesto)
	_demoler.text = "Cancelar demolición" if en_demo else "Demoler"


static func texto_estado_energia(conectado: bool, demanda: float, factor: float, capacidad_red: float) -> String:
	if not conectado:
		return "Sin conexión"
	if demanda <= 0.0:
		return "Sin demanda"
	if capacidad_red <= 0.0:
		return "Sin generación"
	if factor < 1.0 - 1e-9:
		return "Déficit %d %%" % roundi(factor * 100.0)
	return "Con energía"



## Cuántos del oficio "rol" trabajan en el puesto: en los puestos con niveles se cuenta por rango; en la
## refinería y la escuela, todos sus recolectores (técnicos o aprendices).
func _empleados(rol: String, t: Dictionary, con_niveles: bool) -> int:
	if con_niveles:
		return Economia.contar_rango(esquina, Economia.RANGO_DE_ROL.get(rol, 0))
	return t["recolectores"]


## Colonos libres de ese oficio que se podrían contratar: técnicos y especialistas libres, o desempleados.
func _libres_de(rol: String) -> int:
	if rol == "investigador":
		var libres_inv: int = Colonos.investigadores_libres() if Colonos.has_method("investigadores_libres") else 0
		return libres_inv + Colonos.especialistas_libres()
	if rol == "aprendiz" and Economia.puestos.has(esquina):
		var tipo_p: String = Economia.puestos[esquina]["tipo"]
		if Recoleccion.ESCUELAS.has(tipo_p) and Recoleccion.ESCUELAS[tipo_p]["origen"] == "tecnico":
			return Colonos.tecnicos_libres()
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
	if Obras.esta_programada(id) or Obras.esta_marcado(id):
		var motivo: String = Obras.cancelar_demolicion(id)
		if motivo != "":
			aviso.emit(motivo)
		_actualizar()
		return
	_dialogo_demoler.popup_centered()


func _confirmar_demoler() -> void:
	var id: int = Obras.id_en_columna(esquina)
	if id == -1:
		aviso.emit("No se encontró el edificio del puesto.")
		return
	var motivo: String = Obras.programar_demolicion(id, 5)
	if motivo != "":
		aviso.emit(motivo)
	_actualizar()


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
