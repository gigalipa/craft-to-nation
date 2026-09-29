extends Node

## Pruebas aisladas de la extracción del avatar (sub-proyecto 2B): ProgresoAccion,
## tiempos de minado, extraer_por_avatar() y frutos de VoxelWorld. Sin escena de
## juego (mismo patrón que RecoleccionTest.gd). Corre esta escena y revisa que
## no lance ningún assert().

const ProgresoAccionScript = preload("res://scripts/ProgresoAccion.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")
const PlayerScript = preload("res://scripts/Player.gd")

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
	Ciudad.almacen["piedra"].cantidad = 5.0
	assert(jugador_costo._cobrar_colocacion("bloque_piedra"), "con 5 piedra alcanza para 1 bloque_piedra (5 piedra)")
	assert(is_equal_approx(Ciudad.almacen["piedra"].cantidad, 0.0), "se descontaron las 5")
	assert(not jugador_costo._cobrar_colocacion("bloque_piedra"), "sin stock, rechaza")
	assert(Ciudad.almacen["piedra"].cantidad == 0.0, "el rechazo no descuenta nada")
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

	print("\n=== Las 11 pruebas de la extracción del avatar pasaron correctamente ===")
