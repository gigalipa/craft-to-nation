extends Node

## Pruebas aisladas de la extracción del avatar (sub-proyecto 2B): ProgresoAccion,
## tiempos de minado, extraer_por_avatar() y frutos de VoxelWorld. Sin escena de
## juego (mismo patrón que RecoleccionTest.gd). Corre esta escena y revisa que
## no lance ningún assert().

const ProgresoAccionScript = preload("res://scripts/ProgresoAccion.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")
const PlayerScript = preload("res://scripts/Player.gd")


class HUDFalso extends CanvasLayer:
	var ultimo_aviso := ""

	func notificar(mensaje: String) -> void:
		ultimo_aviso = mensaje

## Generador falso: densidad frutal fija, la que se le asigne.
class GeneradorFrutalFalso:
	var densidad := 0.5
	func densidad_frutal_en(_x: int, _z: int) -> float:
		return densidad


## Generador falso: altura fija (bajo un río es la superficie del agua).
class GeneradorAlturaFalso:
	var altura := 20
	func altura_en(_x: int, _z: int) -> int:
		return altura


func _mundo_nuevo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	mundo.arboles = GeneradorArbolScript.new()
	return mundo


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: ProgresoAccion avanza, se completa y se reinicia ===")
	var progreso: RefCounted = ProgresoAccionScript.new()
	assert(progreso.fraccion() == 0.0)
	assert(not progreso.avanzar("celda:a", 1.0, 0.4))
	assert(is_equal_approx(progreso.fraccion(), 0.4))
	assert(not progreso.avanzar("celda:a", 1.0, 0.4))
	assert(progreso.avanzar("celda:a", 1.0, 0.4), "0.4 + 0.4 + 0.4 >= 1.0 completa")
	assert(progreso.fraccion() == 0.0, "al completar, el avance vuelve a 0")

	print("\n=== TEST 2: cambiar de objetivo o soltar reinicia el avance ===")
	progreso.avanzar("celda:a", 1.0, 0.5)
	assert(not progreso.avanzar("celda:b", 1.0, 0.1), "otro bloque: empieza de cero")
	assert(is_equal_approx(progreso.fraccion(), 0.1))
	progreso.soltar()
	assert(progreso.fraccion() == 0.0)
	assert(not progreso.avanzar("celda:b", 1.0, 0.1))
	assert(is_equal_approx(progreso.fraccion(), 0.1), "tras soltar no se conserva nada")
	assert(progreso.avanzar("arbol:3", 0.0, 0.0), "una duración 0 completa de inmediato, sin dividir por cero")

	print("\n=== TEST 3: tiempo_minado_de() por tipo y multiplicador de herramienta ===")
	assert(Recoleccion.tiempo_minado_de("tierra") < Recoleccion.tiempo_minado_de("piedra"))
	assert(Recoleccion.tiempo_minado_de("piedra") < Recoleccion.tiempo_minado_de("tierras_raras"))
	assert(Recoleccion.tiempo_minado_de("bloque_piedra") == Recoleccion.TIEMPO_MINADO_DEFECTO * Recoleccion.MULTIPLICADOR_HERRAMIENTA, "tipo sin tabla: tiempo por defecto")
	assert(Recoleccion.MULTIPLICADOR_HERRAMIENTA == 1.0, "sin herramientas todavía")

	print("\n=== TEST 4: extraer_por_avatar() rinde solo por terreno natural ===")
	var mundo: Node = _mundo_nuevo()
	mundo.colocar_bloque(Vector3i(0, 0, 0), "piedra")
	mundo.colocar_bloque(Vector3i(1, 0, 0), "tierra")
	mundo.colocar_bloque(Vector3i(2, 0, 0), "hierba")
	mundo.colocar_bloque(Vector3i(3, 0, 0), "piedra", true)  # lo puso el jugador
	mundo.colocar_bloque(Vector3i(4, 0, 0), "bloque_piedra")
	mundo.celda_a_edificio[Vector3i(4, 0, 0)] = 1  # parte de un edificio
	mundo.colocar_bloque(Vector3i(5, 0, 0), "agua")
	assert(mundo.extraer_por_avatar(Vector3i(0, 0, 0)) == {"piedra": 10.0})
	assert(mundo.obtener_tipo(Vector3i(0, 0, 0)) == "", "el bloque se retiró")
	assert(mundo.extraer_por_avatar(Vector3i(1, 0, 0)) == {"tierra": 1.0})
	assert(mundo.extraer_por_avatar(Vector3i(2, 0, 0)) == {"tierra": 1.0}, "la capa hierba cuenta como tierra")
	assert(mundo.extraer_por_avatar(Vector3i(3, 0, 0)).is_empty(), "un bloque del jugador no rinde")
	assert(mundo.obtener_tipo(Vector3i(3, 0, 0)) == "", "pero sí se retira, como siempre")
	assert(not mundo.es_minable(Vector3i(4, 0, 0)) and mundo.extraer_por_avatar(Vector3i(4, 0, 0)).is_empty())
	assert(mundo.obtener_tipo(Vector3i(4, 0, 0)) == "bloque_piedra", "un edificio no se mina")
	assert(not mundo.es_minable(Vector3i(5, 0, 0)) and mundo.extraer_por_avatar(Vector3i(5, 0, 0)).is_empty(), "el agua no se mina")
	assert(not mundo.es_minable(Vector3i(9, 9, 9)) and mundo.extraer_por_avatar(Vector3i(9, 9, 9)).is_empty(), "el aire tampoco")

	print("\n=== TEST 5: frutos: rinden según la densidad frutal y rebrotan tras HORAS_REBROTE_FRUTOS ===")
	var mundo_f: Node = _mundo_nuevo()
	var generador_f := GeneradorFrutalFalso.new()
	mundo_f.generador = generador_f
	var tronco := Vector3i(10, 5, 10)
	mundo_f.colocar_bloque(tronco, "madera")
	mundo_f.arboles.registrar([tronco], 1)
	assert(is_equal_approx(mundo_f.frutos_disponibles(tronco, 0), Recoleccion.COMIDA_POR_RECOLECCION * 0.5))
	assert(is_equal_approx(mundo_f.recolectar_frutos(tronco, 0), Recoleccion.COMIDA_POR_RECOLECCION * 0.5))
	assert(mundo_f.frutos_disponibles(tronco, 1) == 0.0 and mundo_f.recolectar_frutos(tronco, 1) == 0.0, "recién recolectado: sin frutos")
	assert(mundo_f.obtener_tipo(tronco) == "madera", "recolectar frutos no consume el árbol")
	assert(mundo_f.frutos_disponibles(tronco, Recoleccion.HORAS_REBROTE_FRUTOS - 1) == 0.0)
	assert(mundo_f.frutos_disponibles(tronco, Recoleccion.HORAS_REBROTE_FRUTOS) > 0.0, "rebrota pasadas las horas")
	generador_f.densidad = 0.0
	assert(mundo_f.frutos_disponibles(tronco, 1000) == 0.0, "sin frutales en la zona no hay frutos")
	assert(mundo_f.recolectar_frutos(Vector3i(50, 5, 50), 1000) == 0.0, "una celda sin árbol no da frutos")

	print("\n=== TEST 6: altura_natural_en() no pasa del lecho real bajo un río ===")
	var mundo_h: Node = _mundo_nuevo()
	assert(mundo_h.altura_natural_en(7, 7) == mundo_h.ALTURA_BUSQUEDA_MIN, "sin generador: el escaneo")
	mundo_h.generador = GeneradorAlturaFalso.new()
	assert(mundo_h.altura_natural_en(7, 7) == 20, "columna vacía: la altura del generador")
	mundo_h.colocar_bloque(Vector3i(7, 8, 7), "piedra")
	assert(mundo_h.altura_natural_en(7, 7) == 8, "el lecho real está bajo la superficie que da el generador")

	print("\n=== TEST 7: Player._cobrar_colocacion()/_reembolsar_colocacion() cobran y reembolsan de Ciudad.almacen ===")
	var jugador_costo: CharacterBody3D = PlayerScript.new()
	var hud_costo := HUDFalso.new()
	jugador_costo.hud = hud_costo
	Ciudad.almacen["piedra"].cantidad = 5.0
	assert(jugador_costo._cobrar_colocacion("bloque_piedra"), "con 5 piedra alcanza para 1 bloque_piedra (5 piedra)")
	assert(is_equal_approx(Ciudad.almacen["piedra"].cantidad, 0.0), "se descontaron las 5")
	assert(not jugador_costo._cobrar_colocacion("bloque_piedra"), "sin stock, rechaza")
	assert(Ciudad.almacen["piedra"].cantidad == 0.0, "el rechazo no descuenta nada")
	assert(hud_costo.ultimo_aviso == "No hay suficiente piedra para colocar: bloque de piedra", "el rechazo también se notifica")
	jugador_costo._reembolsar_colocacion("bloque_piedra")
	assert(is_equal_approx(Ciudad.almacen["piedra"].cantidad, 5.0), "reembolsa exactamente lo que costaba")

	print("\n=== TEST 8: volver a minar un bloque REALMENTE pagado (celdas_pagadas) reembolsa exactamente su costo ===")
	var mundo_costo: Node = _mundo_nuevo()
	Ciudad.almacen["piedra"].cantidad = 0.0
	mundo_costo.colocar_bloque(Vector3i(1, 0, 0), "bloque_piedra", true)
	mundo_costo.celdas_pagadas[Vector3i(1, 0, 0)] = true  # simula que Player._colocar() ya lo cobró
	mundo_costo.minar_bloque(Vector3i(1, 0, 0))
	assert(is_equal_approx(Ciudad.almacen["piedra"].cantidad, 5.0), "reembolsa 5 piedra")

	print("\n=== TEST 9: minar terreno natural (hierba) no reembolsa nada ===")
	Ciudad.almacen["tierra"].cantidad = 0.0
	mundo_costo.colocar_bloque(Vector3i(2, 0, 0), "hierba")  # por_jugador=false: terreno natural
	mundo_costo.minar_bloque(Vector3i(2, 0, 0))
	assert(mundo_costo.obtener_tipo(Vector3i(2, 0, 0)) == "", "se minó")
	assert(Ciudad.almacen["tierra"].cantidad == 0.0, "hierba natural no reembolsa: no pasa por COSTO_POR_CELDA")

	print("\n=== TEST 10: minar una puerta por un extremo, REALMENTE pagada, reembolsa las DOS celdas ===")
	Ciudad.almacen["madera"].cantidad = 0.0
	mundo_costo.colocar_puerta(Vector3i(3, 0, 0))
	mundo_costo.celdas_pagadas[Vector3i(3, 0, 0)] = true
	mundo_costo.celdas_pagadas[Vector3i(3, 1, 0)] = true
	mundo_costo.minar_bloque(Vector3i(3, 0, 0))  # mina solo la mitad inferior
	assert(is_equal_approx(Ciudad.almacen["madera"].cantidad, 2.0), "reembolsa 1 + 1 = 2 madera (inferior + superior)")

	print("\n=== TEST 11: colocar_bloque(por_jugador=true) SIN pasar por Player._colocar() (relleno gratis de ConstructorVias/blueprints) no reembolsa al minarlo ===")
	Ciudad.almacen["tierra"].cantidad = 0.0
	mundo_costo.colocar_bloque(Vector3i(4, 0, 0), "tierra", true)  # colocado_por_jugador=true, pero NUNCA cobrado
	mundo_costo.minar_bloque(Vector3i(4, 0, 0))
	assert(Ciudad.almacen["tierra"].cantidad == 0.0, "colocado_por_jugador no basta para reembolsar: solo celdas_pagadas (evita crear tierra de la nada al nivelar vías/rellenar blueprints)")

	print("\n=== TEST 12: minar un bloque pagado con tablas reembolsa tablas, no madera ===")
	Ciudad.almacen["tablas"].cantidad = 0.0
	Ciudad.almacen["madera"].cantidad = 0.0
	mundo_costo.colocar_bloque(Vector3i(5, 0, 0), "bloque_madera", true)
	mundo_costo.celdas_pagadas[Vector3i(5, 0, 0)] = {"tablas": 5.0}
	mundo_costo.minar_bloque(Vector3i(5, 0, 0))
	assert(is_equal_approx(Ciudad.almacen["tablas"].cantidad, 5.0), "reembolsa 5 tablas")
	assert(is_equal_approx(Ciudad.almacen["madera"].cantidad, 0.0), "no crea madera cruda")

	print("\n=== TEST 13: VoxelWorld coloca y retira tubería de hierro reembolsando a Ciudad.almacen ===")
	var mundo13: Node = _mundo_nuevo()
	var col13 := Vector2i(20, 20)
	var y_sup13 := 5
	var y_fondo13 := -2
	# Colocamos tubería desde 4 hasta -2 -> 7 bloques
	var puestos_tubo: int = mundo13.colocar_tuberia_extraccion(col13, y_sup13, y_fondo13)
	assert(puestos_tubo == 7, "debe colocar 7 bloques de estructura_hierro")
	for y in range(y_sup13 - 1, y_fondo13 - 1, -1):
		assert(mundo13.obtener_tipo(Vector3i(col13.x, y, col13.y)) == "estructura_hierro")
	Ciudad.almacen["hierro"].cantidad = 0.0
	var retirados_tubo: int = mundo13.retirar_tuberia_extraccion(col13, y_sup13, y_fondo13)
	assert(retirados_tubo == 7)
	assert(is_equal_approx(Ciudad.almacen["hierro"].cantidad, 35.0), "debe reembolsar 35 hierro (7 bloques x 5)")
	for y in range(y_sup13 - 1, y_fondo13 - 1, -1):
		assert(mundo13.obtener_tipo(Vector3i(col13.x, y, col13.y)) == "")
	mundo13.free()

	print("\n=== TEST 14: Recoleccion detecta bloques conectados de crudo y extrae desde mayor Y hacia el fondo ===")
	var mundo14: Node = _mundo_nuevo()
	var col14 := Vector2i(15, 15)
	mundo14.colocar_bloque(Vector3i(15, -2, 15), "crudo")
	mundo14.colocar_bloque(Vector3i(15, -3, 15), "crudo")
	mundo14.colocar_bloque(Vector3i(15, -4, 15), "crudo")
	mundo14.colocar_bloque(Vector3i(16, -3, 15), "crudo")  # conectado lateralmente
	assert(Recoleccion.contar_crudo_pozo(mundo14, col14, 0, -4) == 4)
	var sig14: Vector3i = Recoleccion.siguiente_bloque_crudo_pozo(mundo14, col14, 0, -4)
	assert(sig14 == Vector3i(15, -2, 15), "el bloque de mayor Y debe ser el primero")
	mundo14.retirar_bloque_extraido(sig14)
	assert(Recoleccion.contar_crudo_pozo(mundo14, col14, 0, -4) == 3)
	sig14 = Recoleccion.siguiente_bloque_crudo_pozo(mundo14, col14, 0, -4)
	assert(sig14.y == -3, "el siguiente debe estar en y=-3")
	mundo14.free()

	print("\n=== TEST 15: Economia consume bloques reales de crudo, actualiza restantes y se agota al terminar ===")
	var mundo15: Node = _mundo_nuevo()
	var col15 := Vector2i(30, 30)
	mundo15.colocar_bloque(Vector3i(30, -1, 30), "crudo")
	mundo15.colocar_bloque(Vector3i(30, -2, 30), "crudo")
	var esq_ext15 := Vector2i(28, 28)
	var dp15 := {
		"perforacion": col15,
		"y_superficie": 0,
		"y_fondo": -2,
		"tipo_pozo": "crudo",
		"bloques_hierro": 2,
	}
	var entorno15: Dictionary = Recoleccion.entorno_de_puesto("centro_extraccion", mundo15, esq_ext15 + Vector2i(2, 2), 0, Recoleccion.SIN_CENTRO, dp15)
	var eco15: Node = preload("res://scripts/Economia.gd").new()
	eco15.ciudad = Ciudad
	eco15.mundo = mundo15
	eco15.registrar_puesto(esq_ext15, "centro_extraccion", 5, 5, {"crudo": 10.0}, entorno15)
	assert(eco15.puestos[esq_ext15]["crudo_restante"] == 2)
	assert(eco15.asignar(esq_ext15, "tecnico", 1))
	eco15.marcar_presente(1, true)
	# Rendimiento por bloque de crudo es 10.0. 1 hora a tasa 10 extrae exactamente 1 bloque
	eco15.simular_hora()
	assert(eco15.puestos[esq_ext15]["almacen"]["crudo"] == 10.0)
	assert(eco15.puestos[esq_ext15]["crudo_restante"] == 1, "queda 1 bloque")
	assert(not eco15.puestos[esq_ext15]["agotado"])
	# Segunda hora: extrae el segundo y último bloque
	eco15.simular_hora()
	assert(eco15.puestos[esq_ext15]["almacen"]["crudo"] == 20.0)
	assert(eco15.puestos[esq_ext15]["crudo_restante"] == 0, "quedan 0 bloques")
	assert(eco15.puestos[esq_ext15]["agotado"], "el pozo de crudo queda agotado")
	assert(eco15.puestos[esq_ext15]["tasas"]["crudo"] == 0.0)
	eco15.free()
	mundo15.free()

	print("\n=== TEST 16: Transporte de fluidos por tubería al almacén general de la ciudad ===")
	var mundo16: Node = _mundo_nuevo()
	var eco16: Node = preload("res://scripts/Economia.gd").new()
	eco16.ciudad = Ciudad
	eco16.mundo = mundo16
	var esq_ext16 := Vector2i(50, 50)
	var esq_alm16 := Vector2i(60, 50)
	eco16.registrar_puesto(esq_ext16, "centro_extraccion", 5, 5, {"crudo": 10.0})
	eco16.registrar_puesto(esq_alm16, "almacen", 5, 5, {})
	eco16.puestos[esq_ext16]["almacen"]["crudo"] = 50.0
	Ciudad.almacen["crudo"].cantidad = 0.0

	# Conectar puerto de salida del centro de extracción con puerto de entrada del almacén
	Canalizaciones.reiniciar()
	var p_out16 := Vector3i(54, 4, 52)
	var p_in16 := Vector3i(60, 4, 52)
	Canalizaciones.tipo_por_puerto[p_out16] = "puerto_crudo_out"
	Canalizaciones.tipo_por_puerto[p_in16] = "puerto_crudo_in"
	Canalizaciones.puertos_conectados[p_out16] = 16
	Canalizaciones.puertos_conectados[p_in16] = 16
	Canalizaciones.recurso_por_red[16] = "crudo"
	Canalizaciones.tipo_por_red[16] = "tuberia"
	# Registrar bloque de puerto en mundo
	mundo16.colocar_bloque(p_out16, "puerto_crudo_out")
	mundo16.colocar_bloque(p_in16, "puerto_crudo_in")

	# Procesar simular_hora en eco16
	eco16.simular_hora()
	assert(eco16.reserva_fluidos["crudo"] == 50.0, "el crudo fue transportado a la reserva de fluidos: %f" % eco16.reserva_fluidos["crudo"])
	assert(Ciudad.almacen["crudo"].cantidad == 50.0, "el crudo fue transportado al almacén de la ciudad: %f" % Ciudad.almacen["crudo"].cantidad)
	assert(eco16.puestos[esq_ext16]["almacen"].get("crudo", 0.0) == 0.0, "el almacén local quedó vacío tras el envío")
	Canalizaciones.reiniciar()
	eco16.free()
	mundo16.free()

	print("\n=== Las 16 pruebas de la extracción pasaron correctamente ===")
