extends Node

## Pruebas aisladas de Economia.gd, sin escena: una Ciudad real instanciada
## fuera del árbol (igual que ColonosTest.gd) y una Economia nueva con esa
## ciudad inyectada. Corre esta escena y revisa que no lance ningún assert().

const EconomiaScript = preload("res://scripts/Economia.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")

const ESQ := Vector2i(10, 10)
const ESQ_REF := Vector2i(30, 30)
const ESQ_ESC := Vector2i(50, 50)


## Generador falso: fauna 0.8 y frutal 0.4 en todas partes.
class GeneradorFaunaFalso:
	func densidad_fauna_en(_x: int, _z: int) -> float:
		return 0.8
	func densidad_frutal_en(_x: int, _z: int) -> float:
		return 0.4
	func densidad_arbol_en(_x: int, _z: int) -> float:
		return 0.6


## Solo lo que tasas_de_entorno() lee del mundo para caza/recolección.
class MundoBosqueFalso:
	var generador = GeneradorFaunaFalso.new()
	var arboles = preload("res://scripts/GeneradorArbol.gd").new()


func _ready() -> void:
	ejecutar_pruebas()


## Una Economia con un maderero (5 de cupo) en ESQ y tasa 3 madera/h.
func _nueva(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0})
	return economia


## Una Economia con una siderúrgica de 5x5 en ESQ_REF: entrada al norte, salida al sur.
func _con_siderurgica(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(ESQ_REF, "siderurgica", 5, 5, {}, {}, Vector2i(32, 29), EconomiaScript.SIN_DEPOSITO, EconomiaScript.SIN_SUELO, Vector2i(32, 35))
	return economia


## Una Economia con una escuela técnica de 5x5 en ESQ_ESC (cupo 4: el de la cohorte).
func _con_escuela(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(ESQ_ESC, "escuela_tecnica", 5, 5, {})
	return economia


## Un VoxelWorld sin _ready() (mismo patrón que RecoleccionTest.gd) con el registro de árboles listo.
func _mundo_nuevo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	mundo.arboles = GeneradorArbolScript.new()
	return mundo


## Veta de 3 bloques de hierro (30 unidades) bajo (500,500): superficie en y=9 y un hierro a
## profundidad 1 (y=8) que la mina no toca; extraíbles: (500,7,500), (501,7,500) y (500,6,500), en ese orden.
func _mundo_con_veta() -> Node:
	var mundo: Node = _mundo_nuevo()
	mundo.colocar_bloque(Vector3i(500, 9, 500), "piedra")
	mundo.colocar_bloque(Vector3i(501, 9, 500), "piedra")
	mundo.colocar_bloque(Vector3i(500, 8, 500), "hierro")
	mundo.colocar_bloque(Vector3i(500, 7, 500), "hierro")
	mundo.colocar_bloque(Vector3i(501, 7, 500), "hierro")
	mundo.colocar_bloque(Vector3i(500, 6, 500), "hierro")
	return mundo


## Un árbol de 3 troncos (salud 3 = 30 unidades de madera) en (600,600), registrado en el mundo.
func _mundo_con_arbol() -> Array:
	var mundo: Node = _mundo_nuevo()
	var celdas: Array = [Vector3i(600, 5, 600), Vector3i(600, 6, 600), Vector3i(600, 7, 600)]
	for celda in celdas:
		mundo.colocar_bloque(celda, "madera")
	var id: int = mundo.arboles.registrar(celdas, 3)
	return [mundo, id]


func ejecutar_pruebas() -> void:
	print("=== TEST 1: registrar_puesto() y huella_de() ===")
	var e1: Node = _nueva(CiudadScript.new())
	assert(e1.tiene_puesto(ESQ) and not e1.tiene_puesto(Vector2i(0, 0)))
	assert(e1.huella_de(ESQ).size() == 12 and e1.huella_de(ESQ).has(Vector2i(12, 13)))
	assert(e1.huella_de(Vector2i(0, 0)).is_empty())
	assert(e1.cupo_libre(ESQ) == 5, "el maderero admite 5 trabajadores")
	assert(e1.trabajadores_de(ESQ) == {"recolectores": 0, "acarreadores": 0, "presentes": 0})

	print("\n=== TEST 2: asignar() respeta el cupo total y no repite colonos ===")
	for id in range(1, 6):
		assert(e1.asignar(ESQ, "recolector" if id <= 3 else "acarreador", id))
	assert(e1.cupo_libre(ESQ) == 0)
	assert(not e1.asignar(ESQ, "recolector", 6), "cupo lleno")
	assert(e1.trabajadores_de(ESQ)["recolectores"] == 3 and e1.trabajadores_de(ESQ)["acarreadores"] == 2)
	e1.liberar(4)
	assert(e1.cupo_libre(ESQ) == 1)
	assert(not e1.asignar(ESQ, "recolector", 1), "un colono ya asignado no se asigna otra vez")
	assert(not e1.asignar(Vector2i(0, 0), "recolector", 9), "un puesto inexistente no admite trabajadores")
	assert(not e1.asignar(ESQ, "jardinero", 9), "rol desconocido")
	assert(e1.ultimo_de(ESQ, "recolector") == 3 and e1.ultimo_de(ESQ, "acarreador") == 5)
	assert(e1.ultimo_de(Vector2i(0, 0), "recolector") == -1)

	print("\n=== TEST 3: solo producen los recolectores PRESENTES ===")
	var e3: Node = _nueva(CiudadScript.new())
	e3.asignar(ESQ, "recolector", 1)
	e3.asignar(ESQ, "recolector", 2)
	e3.asignar(ESQ, "acarreador", 3)
	e3.simular_hora()
	assert(e3.almacen_local(ESQ).is_empty(), "nadie presente: no produce")
	e3.marcar_presente(1, true)
	e3.marcar_presente(3, true)  # un acarreador no cuenta como productor
	assert(e3.trabajadores_de(ESQ)["presentes"] == 1)
	e3.simular_hora()
	assert(is_equal_approx(e3.almacen_local(ESQ)["madera"], 3.0))
	assert(is_equal_approx(e3.produccion_por_hora(ESQ)["madera"], 3.0))
	e3.marcar_presente(2, true)
	e3.simular_hora()
	assert(is_equal_approx(e3.almacen_local(ESQ)["madera"], 9.0), "3 + 2 recolectores x 3")
	e3.marcar_presente(2, false)
	assert(e3.trabajadores_de(ESQ)["presentes"] == 1)

	print("\n=== TEST 4: el almacén local tiene tope (el de su tipo de puesto) y el exceso se pierde ===")
	var e4: Node = _nueva(CiudadScript.new())
	e4.registrar_puesto(Vector2i(50, 50), "mina", 5, 5, {"hierro": 30.0, "piedra": 10.0})
	e4.asignar(Vector2i(50, 50), "recolector", 1)
	e4.marcar_presente(1, true)
	var tope4: float = Recoleccion.capacidad_almacen_de("mina")
	for i in range(int(ceil(tope4 / 40.0)) + 2):  # 40/h de producción: se pasa del tope seguro
		e4.simular_hora()
	var local4: Dictionary = e4.almacen_local(Vector2i(50, 50))
	assert(is_equal_approx(local4["hierro"] + local4["piedra"], tope4), "nunca pasa del tope del puesto")
	assert(is_equal_approx(local4["hierro"] / local4["piedra"], 3.0), "conserva la proporción de la tasa")

	print("\n=== TEST 5: caza, frutos, pesca y algas suman en comida ===")
	var e5: Node = _nueva(CiudadScript.new())
	e5.registrar_puesto(Vector2i(60, 60), "caza_recoleccion", 4, 4, {"caza": 7.5, "recoleccion": 1.25})
	e5.asignar(Vector2i(60, 60), "recolector", 1)
	e5.marcar_presente(1, true)
	e5.simular_hora()
	var local5: Dictionary = e5.almacen_local(Vector2i(60, 60))
	assert(local5.size() == 1 and is_equal_approx(local5["comida"], 8.75))
	e5.registrar_puesto(Vector2i(70, 70), "pesca_frutos_mar", 4, 6, {"pesca": 2.5, "frutos_mar": 0.3})
	e5.asignar(Vector2i(70, 70), "recolector", 2)
	e5.marcar_presente(2, true)
	e5.simular_hora()
	assert(is_equal_approx(e5.almacen_local(Vector2i(70, 70))["comida"], 2.8))

	print("\n=== TEST 6: recoger() entrega carga completa, o el resto si ya no hay recolectores ===")
	var e6: Node = _nueva(CiudadScript.new())
	e6.asignar(ESQ, "recolector", 1)
	e6.marcar_presente(1, true)
	for i in range(3):
		e6.simular_hora()  # 9 madera
	assert(e6.recoger(ESQ, 20.0).is_empty(), "con recolectores presentes espera a tener la carga completa")
	for i in range(4):
		e6.simular_hora()  # 21 madera
	var carga6: Dictionary = e6.recoger(ESQ, 20.0)
	assert(is_equal_approx(carga6["madera"], 20.0))
	assert(is_equal_approx(e6.almacen_local(ESQ)["madera"], 1.0), "queda el resto")
	assert(e6.recoger(ESQ, 20.0).is_empty(), "queda 1 y sigue habiendo un recolector presente")
	e6.marcar_presente(1, false)
	var resto6: Dictionary = e6.recoger(ESQ, 20.0)
	assert(is_equal_approx(resto6["madera"], 1.0), "sin recolectores presentes se lleva lo que quede")
	assert(e6.almacen_local(ESQ).is_empty(), "el almacén queda vacío, sin claves en cero")
	assert(e6.recoger(ESQ, 20.0).is_empty(), "vacío: nada que llevar")
	assert(e6.recoger(Vector2i(0, 0), 20.0).is_empty(), "puesto inexistente")

	print("\n=== TEST 7: recoger() reparte la carga entre recursos sin pasarse ===")
	var e7: Node = _nueva(CiudadScript.new())
	e7.registrar_puesto(Vector2i(50, 50), "mina", 5, 5, {"hierro": 12.0, "piedra": 12.0})
	e7.asignar(Vector2i(50, 50), "recolector", 1)
	e7.marcar_presente(1, true)
	e7.simular_hora()
	e7.simular_hora()  # 24 hierro + 24 piedra = 48 en total
	var carga7: Dictionary = e7.recoger(Vector2i(50, 50), 20.0)
	var total7 := 0.0
	for v in carga7.values():
		total7 += v
	assert(is_equal_approx(total7, 20.0), "lleva exactamente la capacidad")
	var quedan7 := 0.0
	for v in e7.almacen_local(Vector2i(50, 50)).values():
		quedan7 += v
	assert(is_equal_approx(quedan7, 28.0))

	print("\n=== TEST 8: entregar() suma al stock central y respeta su límite ===")
	var ciudad8: Node = CiudadScript.new()
	var e8: Node = _nueva(ciudad8)
	var antes8: float = ciudad8.almacen["madera"].cantidad
	e8.entregar({"madera": 20.0, "tierras_raras": 4.0})
	assert(is_equal_approx(ciudad8.almacen["madera"].cantidad, antes8 + 20.0))
	assert(is_equal_approx(ciudad8.almacen["tierras_raras"].cantidad, 4.0))
	e8.entregar({"madera": 5000.0})
	assert(ciudad8.almacen["madera"].cantidad == ciudad8.almacen["madera"].limite, "lo que no cabe se pierde")

	print("\n=== TEST 9: quitar_puesto() libera a los trabajadores y avisa ===")
	var e9: Node = _nueva(CiudadScript.new())
	e9.asignar(ESQ, "recolector", 1)
	e9.asignar(ESQ, "acarreador", 2)
	var avisados := []
	e9.puesto_quitado.connect(func(ids: Array) -> void: avisados.append_array(ids))
	e9.quitar_puesto(ESQ)
	assert(not e9.tiene_puesto(ESQ))
	assert(avisados.size() == 2 and avisados.has(1) and avisados.has(2))
	assert(e9.asignar(Vector2i(0, 0), "recolector", 1) == false)
	e9.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0})
	assert(e9.asignar(ESQ, "recolector", 1), "los colonos liberados quedan libres para otro puesto")
	e9.quitar_puesto(Vector2i(0, 0))  # inexistente: no hace nada

	print("\n=== TEST 10: simular_hora() se dispara con Ciudad.tick_simulado ===")
	var ciudad10: Node = CiudadScript.new()
	ciudad10.migracion_activa = false
	var e10: Node = _nueva(ciudad10)
	e10._ready()  # conecta el tick (fuera del árbol no se llama solo)
	e10.asignar(ESQ, "recolector", 1)
	e10.marcar_presente(1, true)
	ciudad10.simular_tick(0.0)
	assert(is_equal_approx(e10.almacen_local(ESQ)["madera"], 3.0))

	print("\n=== TEST 11: una mina consume sus bloques y se agota ===")
	var mundo11: Node = _mundo_con_veta()
	var e11: Node = EconomiaScript.new()
	e11.ciudad = CiudadScript.new()
	e11.mundo = mundo11
	var esq11 := Vector2i(50, 50)
	e11.registrar_puesto(esq11, "mina", 5, 5, {"hierro": 12.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e11.asignar(esq11, "recolector", 1)
	e11.marcar_presente(1, true)
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 12.0))
	assert(mundo11.obtener_tipo(Vector3i(500, 7, 500)) == "", "el bloque más cercano ya se retiró")
	assert(mundo11.obtener_tipo(Vector3i(501, 7, 500)) == "hierro", "el segundo va a medias (8 de 10)")
	assert(mundo11.obtener_tipo(Vector3i(500, 8, 500)) == "hierro", "la profundidad 1 nunca se toca")
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 24.0))
	assert(mundo11.obtener_tipo(Vector3i(501, 7, 500)) == "", "una hora agotó un bloque y empezó el siguiente")
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 30.0), "solo quedaban 6 unidades de las 12 pedidas")
	assert(mundo11.obtener_tipo(Vector3i(500, 6, 500)) == "")
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 30.0), "mina agotada: no produce nada más")
	assert(mundo11.obtener_tipo(Vector3i(500, 8, 500)) == "hierro" and mundo11.obtener_tipo(Vector3i(500, 9, 500)) == "piedra")

	print("\n=== TEST 12: un maderero tala árboles enteros y se agota ===")
	var datos12: Array = _mundo_con_arbol()
	var mundo12: Node = datos12[0]
	var id12: int = datos12[1]
	var e12: Node = EconomiaScript.new()
	e12.ciudad = CiudadScript.new()
	e12.mundo = mundo12
	var entorno12 := {"centro": Vector2i(600, 600), "altura": 5, "radio_arboles": 12, "arboles_ref": 1}
	e12.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 12.0}, entorno12)
	e12.asignar(ESQ, "recolector", 1)
	e12.marcar_presente(1, true)
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 12.0))
	assert(mundo12.arboles.salud_de(id12) == 2, "un tronco (10 unidades) ya se consumió")
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 24.0))
	assert(mundo12.arboles.salud_de(id12) == 1)
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 30.0), "el árbol solo rendía 30")
	assert(mundo12.arboles.salud_de(id12) == 0 and mundo12.obtener_tipo(Vector3i(600, 5, 600)) == "", "el árbol cayó entero")
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 30.0), "sin árboles no hay madera")

	print("\n=== TEST 13: si el avatar tala el árbol o mina el bloque en curso, el puesto no produce gratis ===")
	var datos13: Array = _mundo_con_arbol()
	var e13: Node = EconomiaScript.new()
	e13.ciudad = CiudadScript.new()
	e13.mundo = datos13[0]
	e13.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 12.0}, {"centro": Vector2i(600, 600), "altura": 5, "radio_arboles": 12, "arboles_ref": 1})
	e13.asignar(ESQ, "recolector", 1)
	e13.marcar_presente(1, true)
	e13.simular_hora()
	datos13[0].talar_bloque_de_arbol(Vector3i(600, 5, 600), 99)  # el avatar lo derriba
	e13.simular_hora()
	assert(is_equal_approx(e13.almacen_local(ESQ)["madera"], 12.0), "el bloque en curso ya no existe: no suma")
	var mundo13b: Node = _mundo_con_veta()
	var e13b: Node = EconomiaScript.new()
	e13b.ciudad = CiudadScript.new()
	e13b.mundo = mundo13b
	e13b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e13b.asignar(ESQ, "recolector", 1)
	e13b.marcar_presente(1, true)
	e13b.simular_hora()  # deja (500,7,500) a medias
	mundo13b.minar_bloque(Vector3i(500, 7, 500))  # el avatar lo mina
	e13b.simular_hora()
	assert(mundo13b.obtener_tipo(Vector3i(501, 7, 500)) == "hierro", "el puesto pasa al siguiente bloque sin retirarlo entero")
	assert(is_equal_approx(e13b.almacen_local(ESQ)["hierro"], 10.0))

	print("\n=== TEST 14: las tasas se recalculan cada TICKS_RECALCULO horas ===")
	assert(EconomiaScript.TICKS_RECALCULO == 6)
	var e14: Node = EconomiaScript.new()
	e14.ciudad = CiudadScript.new()
	e14.mundo = _mundo_con_veta()
	# Tasa desactualizada a propósito (1/h): al recalcular, hierro vale 5 (1 tipo x tasa base 5).
	e14.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 1.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e14.asignar(ESQ, "recolector", 1)
	e14.marcar_presente(1, true)
	for i in range(EconomiaScript.TICKS_RECALCULO - 1):
		e14.simular_hora()
	assert(is_equal_approx(e14.produccion_por_hora(ESQ)["hierro"], 1.0), "todavía no toca recalcular")
	e14.simular_hora()
	assert(is_equal_approx(e14.produccion_por_hora(ESQ)["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]))

	print("\n=== TEST 15: recalcular_tasas() con el área agotada deja la producción en 0, y caza/recolección sigue los árboles ===")
	var e15: Node = EconomiaScript.new()
	e15.ciudad = CiudadScript.new()
	var mundo15: Node = _mundo_con_veta()
	e15.mundo = mundo15
	e15.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e15.asignar(ESQ, "recolector", 1)
	e15.marcar_presente(1, true)
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		mundo15.minar_bloque(celda)
	e15.recalcular_tasas(ESQ)
	assert(e15.produccion_por_hora(ESQ).is_empty(), "sin bloques extraíbles no hay tasas")
	e15.simular_hora()
	assert(e15.almacen_local(ESQ).is_empty())
	e15.recalcular_tasas(Vector2i(0, 0))  # puesto inexistente: no falla
	var mundo_bosque := MundoBosqueFalso.new()
	var ids15: Array = []
	for i in range(1, 5):
		ids15.append(mundo_bosque.arboles.registrar([Vector3i(i, 5, i)], 3))
	var e15b: Node = EconomiaScript.new()
	e15b.ciudad = CiudadScript.new()
	e15b.mundo = mundo_bosque
	var esq15 := Vector2i(70, 70)
	var entorno15: Dictionary = Recoleccion.entorno_de_puesto("caza_recoleccion", mundo_bosque, Vector2i(0, 0), 5)
	e15b.registrar_puesto(esq15, "caza_recoleccion", 4, 4, Recoleccion.tasas_de_entorno("caza_recoleccion", mundo_bosque, entorno15), entorno15)
	e15b.asignar(esq15, "recolector", 1)
	e15b.marcar_presente(1, true)
	var comida_llena: float = e15b.produccion_por_hora(esq15)["comida"]
	mundo_bosque.arboles.eliminar(ids15[0])
	mundo_bosque.arboles.eliminar(ids15[1])
	e15b.recalcular_tasas(esq15)
	assert(is_equal_approx(e15b.produccion_por_hora(esq15)["comida"], comida_llena * 0.5), "la mitad de los árboles: la mitad de la comida")

	print("\n=== TEST 16: con el área agotada se acarrea el resto aunque haya recolectores; produciendo, la carga parcial se rechaza ===")
	var mundo16: Node = _mundo_con_veta()
	var e16: Node = EconomiaScript.new()
	e16.ciudad = CiudadScript.new()
	e16.mundo = mundo16
	e16.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e16.asignar(ESQ, "recolector", 1)
	e16.marcar_presente(1, true)
	e16.simular_hora()
	assert(e16.recoger(ESQ, 150.0).is_empty(), "produciendo con recolectores: no se da una carga parcial")
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		mundo16.minar_bloque(celda)
	e16.recalcular_tasas(ESQ)
	var carga16: Dictionary = e16.recoger(ESQ, 150.0)
	assert(carga16.has("hierro") and is_equal_approx(carga16["hierro"], 5.0), "agotado: se acarrea el resto")

	print("\n=== TEST 17: un bloque en curso reemplazado por uno del jugador no se retira ni rinde ===")
	var mundo17: Node = _mundo_con_veta()
	var e17: Node = EconomiaScript.new()
	e17.ciudad = CiudadScript.new()
	e17.mundo = mundo17
	e17.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e17.asignar(ESQ, "recolector", 1)
	e17.marcar_presente(1, true)
	e17.simular_hora()  # deja (500,7,500) a medias
	mundo17.minar_bloque(Vector3i(500, 7, 500))
	mundo17.colocar_bloque(Vector3i(500, 7, 500), "hierro", true)
	e17.simular_hora()
	assert(mundo17.obtener_tipo(Vector3i(500, 7, 500)) == "hierro", "el bloque del jugador no se retira")
	assert(mundo17.obtener_tipo(Vector3i(501, 7, 500)) == "hierro", "el siguiente natural sigue a medias")
	assert(is_equal_approx(e17.almacen_local(ESQ)["hierro"], 10.0), "solo rindió el natural")

	print("\n=== TEST 18: un puesto se registra activo, sin agotar y, sin celda de servicio ni depósito, con los valores «ninguno» ===")
	var e18: Node = _nueva(CiudadScript.new())
	assert(e18.puestos[ESQ]["activo"] and not e18.puestos[ESQ]["agotado"])
	assert(e18.servicio_de(ESQ) == EconomiaScript.SIN_SERVICIO, "sin celda de servicio, Colonos usa el anillo de la huella")
	assert(e18.puestos[ESQ]["deposito"] == EconomiaScript.SIN_DEPOSITO)
	assert(e18.suelo_de(ESQ) == EconomiaScript.SIN_SUELO, "sin plantilla no hay piso interior")
	assert(e18.servicio_de(Vector2i(0, 0)) == EconomiaScript.SIN_SERVICIO, "puesto inexistente")

	print("\n=== TEST 19: desactivar_puesto() libera a todos, es idempotente, pasa el almacén al núcleo y no admite contratar ===")
	var ciudad19: Node = CiudadScript.new()
	var madera19: float = ciudad19.almacen["madera"].cantidad
	var e19: Node = _nueva(ciudad19)
	e19.asignar(ESQ, "recolector", 1)
	e19.asignar(ESQ, "acarreador", 2)
	e19.marcar_presente(1, true)
	e19.puestos[ESQ]["almacen"]["madera"] = 5.0
	var liberados19: Array = []
	e19.trabajadores_liberados.connect(func(ids: Array) -> void: liberados19.append_array(ids))
	e19.desactivar_puesto(ESQ)
	liberados19.sort()
	assert(liberados19 == [1, 2], "los dos quedan libres")
	assert(not e19.puestos[ESQ]["activo"] and e19.cupo_libre(ESQ) == 5)
	assert(e19.almacen_local(ESQ).is_empty() and is_equal_approx(ciudad19.almacen["madera"].cantidad, madera19 + 5.0), "el almacén local pasa al núcleo")
	e19.desactivar_puesto(ESQ)
	assert(liberados19.size() == 2, "desactivar dos veces no vuelve a emitir")
	assert(not e19.asignar(ESQ, "recolector", 3) and not e19.asignar(ESQ, "acarreador", 3), "inactivo: no se contrata")
	e19.marcar_presente(1, true)
	e19.simular_hora()
	assert(e19.almacen_local(ESQ).is_empty(), "inactivo no produce")
	e19.reactivar_puesto(ESQ)
	assert(e19.puestos[ESQ]["activo"] and e19.asignar(ESQ, "recolector", 3), "reactivado: se contrata de nuevo")
	e19.desactivar_puesto(Vector2i(0, 0))  # inexistente: no falla

	print("\n=== TEST 20: retirar_deposito() pasa al stock central solo lo que cabe y deja el resto en el puesto ===")
	var ciudad20: Node = CiudadScript.new()
	var e20: Node = EconomiaScript.new()
	e20.ciudad = ciudad20
	e20.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(11, 9), Vector3i(11, 5, 11), 5)
	assert(e20.suelo_de(ESQ) == 5, "la altura del piso interior transitable se guarda")
	assert(e20.puesto_con_deposito(Vector3i(11, 5, 11)) == ESQ)
	assert(e20.puesto_con_deposito(Vector3i(0, 0, 0)) == Recoleccion.SIN_PUESTO)
	assert(e20.servicio_de(ESQ) == Vector2i(11, 9))
	ciudad20.almacen["madera"].cantidad = ciudad20.almacen["madera"].limite - 40.0
	e20.puestos[ESQ]["almacen"]["madera"] = 100.0
	var tomado20: Dictionary = e20.retirar_deposito(ESQ)
	assert(is_equal_approx(tomado20["madera"], 40.0), "solo cabían 40")
	assert(is_equal_approx(e20.almacen_local(ESQ)["madera"], 60.0), "el resto queda en el puesto")
	assert(e20.retirar_deposito(ESQ).is_empty(), "con el stock lleno no pasa nada")
	assert(e20.retirar_deposito(Vector2i(0, 0)).is_empty(), "puesto inexistente")

	print("\n=== TEST 21: al agotarse el área se liberan los recolectores, los acarreadores siguen hasta vaciar el almacén y reactivar recalcula el agotamiento ===")
	var mundo21: Node = _mundo_con_veta()
	var e21: Node = EconomiaScript.new()
	e21.ciudad = CiudadScript.new()
	e21.mundo = mundo21
	e21.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e21.asignar(ESQ, "recolector", 1)
	e21.asignar(ESQ, "recolector", 2)
	e21.asignar(ESQ, "acarreador", 3)
	e21.marcar_presente(1, true)
	e21.marcar_presente(2, true)
	var liberados21: Array = []
	e21.trabajadores_liberados.connect(func(ids: Array) -> void: liberados21.append_array(ids))
	e21.recalcular_tasas(ESQ)
	assert(liberados21.is_empty() and not e21.puestos[ESQ]["agotado"], "con veta no se agota")
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		mundo21.minar_bloque(celda)
	e21.puestos[ESQ]["almacen"]["hierro"] = 20.0
	e21.recalcular_tasas(ESQ)
	assert(e21.puestos[ESQ]["agotado"], "sin bloques minerales, todas las tasas son 0")
	liberados21.sort()
	assert(liberados21 == [1, 2], "se liberan los recolectores")
	assert(e21.trabajadores_de(ESQ)["recolectores"] == 0 and e21.trabajadores_de(ESQ)["acarreadores"] == 1, "el acarreador se queda")
	assert(not e21.asignar(ESQ, "recolector", 4), "agotado: no se contratan recolectores")
	e21.simular_hora()
	assert(e21.trabajadores_de(ESQ)["acarreadores"] == 1, "con almacén no se libera al acarreador")
	var carga21: Dictionary = e21.recoger(ESQ, 150.0)
	assert(is_equal_approx(carga21["hierro"], 20.0), "se acarrea el resto")
	e21.simular_hora()
	liberados21.sort()
	assert(liberados21 == [1, 2, 3], "vacío y agotado: se libera al acarreador")
	# Reactivar tras deconstruir con el recurso ya agotado: sigue agotado (recalcula al reactivar).
	e21.desactivar_puesto(ESQ)
	e21.reactivar_puesto(ESQ)
	assert(e21.puestos[ESQ]["agotado"] and not e21.asignar(ESQ, "recolector", 5))
	# Agotamiento con el almacén ya vacío libera a los acarreadores en el mismo recálculo.
	var e21b: Node = EconomiaScript.new()
	e21b.ciudad = CiudadScript.new()
	e21b.mundo = _mundo_con_veta()
	e21b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e21b.asignar(ESQ, "acarreador", 7)
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		e21b.mundo.minar_bloque(celda)
	e21b.recalcular_tasas(ESQ)
	assert(e21b.trabajadores_de(ESQ)["acarreadores"] == 0, "agotado y sin almacén: el acarreador también se libera")

	print("\n=== TEST 22: agregar_deposito() pasa al puesto solo lo que cabe en su almacén local y deja el resto en el stock central ===")
	var ciudad22: Node = CiudadScript.new()
	var e22: Node = EconomiaScript.new()
	e22.ciudad = ciudad22
	e22.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(11, 9), Vector3i(11, 5, 11), 5)
	e22.puestos[ESQ]["almacen"]["madera"] = 950.0  # capacidad del maderero: 1000 (solo caben 50 más)
	ciudad22.almacen["madera"].cantidad = 80.0
	var entregado22: Dictionary = e22.agregar_deposito(ESQ)
	assert(is_equal_approx(entregado22["madera"], 50.0), "solo cabían 50")
	assert(is_equal_approx(e22.almacen_local(ESQ)["madera"], 1000.0), "el puesto queda al tope")
	assert(is_equal_approx(ciudad22.almacen["madera"].cantidad, 30.0), "el resto queda en el stock central")
	assert(e22.agregar_deposito(ESQ).is_empty(), "con el puesto lleno no pasa nada")
	assert(e22.agregar_deposito(Vector2i(0, 0)).is_empty(), "puesto inexistente")

	print("\n=== TEST 23: retirar_uno()/agregar_uno() mueven de a uno (VentanaBaul, botones -/+) ===")
	var ciudad23: Node = CiudadScript.new()
	var e23: Node = EconomiaScript.new()
	e23.ciudad = ciudad23
	e23.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(11, 9), Vector3i(11, 5, 11), 5)
	e23.puestos[ESQ]["almacen"]["madera"] = 15.0
	ciudad23.almacen["madera"].cantidad = 0.0  # arranca en 200: limpiarlo simplifica los montos esperados
	assert(is_equal_approx(e23.retirar_uno(ESQ, "madera", 10.0), 10.0), "retira lo pedido (Shift = 10)")
	assert(is_equal_approx(e23.almacen_local(ESQ)["madera"], 5.0), "el resto queda en el puesto")
	assert(is_equal_approx(ciudad23.almacen["madera"].cantidad, 10.0), "y lo retirado llega al stock central")
	assert(is_equal_approx(e23.retirar_uno(ESQ, "madera", 10.0), 5.0), "no retira más de lo que había")
	assert(e23.almacen_local(ESQ).is_empty(), "vacío: la clave se limpia")
	assert(e23.retirar_uno(ESQ, "madera", 1.0) == 0.0, "sin nada que retirar, no pasa nada")
	assert(e23.retirar_uno(ESQ, "recurso_inexistente", 1.0) == 0.0, "recurso inexistente")
	ciudad23.almacen["madera"].cantidad = 10.0
	assert(is_equal_approx(e23.agregar_uno(ESQ, "madera", 1.0), 1.0), "agrega lo pedido (sin Shift = 1)")
	assert(is_equal_approx(e23.almacen_local(ESQ)["madera"], 1.0), "llega al puesto")
	assert(is_equal_approx(ciudad23.almacen["madera"].cantidad, 9.0), "y sale del stock central")
	e23.puestos[ESQ]["almacen"]["madera"] = 999.0
	assert(is_equal_approx(e23.agregar_uno(ESQ, "madera", 10.0), 1.0), "solo cabía 1 (capacidad 1000)")
	assert(e23.agregar_uno(Vector2i(0, 0), "madera", 1.0) == 0.0, "puesto inexistente")

	print("\n=== TEST 24: la siderúrgica es una refinería con cupo 4, almacén de 1000 y roles técnico/acarreador ===")
	var ciudad24: Node = CiudadScript.new()
	var e24: Node = _con_siderurgica(ciudad24)
	assert(e24.es_refineria(ESQ_REF) and not e24.es_refineria(Vector2i(0, 0)))
	assert(e24.puestos[ESQ_REF]["cupo"] == 4 and e24.puestos[ESQ_REF]["capacidad"] == 1000)
	assert(e24.insumo_de(ESQ_REF) == "hierro" and e24.producto_de(ESQ_REF) == "acero")
	assert(e24.salida_de(ESQ_REF) == Vector2i(32, 35) and e24.servicio_de(ESQ_REF) == Vector2i(32, 29))
	assert(e24.asignar(ESQ_REF, "tecnico", 1), "un técnico entra a la refinería")
	assert(not e24.asignar(ESQ_REF, "recolector", 2), "un recolector no entra a una refinería")
	assert(e24.asignar(ESQ_REF, "acarreador", 3))
	assert(e24.trabajadores_de(ESQ_REF)["recolectores"] == 1, "los técnicos cuentan bajo recolectores")
	assert(e24.ultimo_de(ESQ_REF, "tecnico") == 1 and e24.ultimo_de(ESQ_REF, "acarreador") == 3)
	var e24b: Node = _nueva(ciudad24)
	assert(e24b.asignar(ESQ, "tecnico", 9) and not e24b.asignar(ESQ_REF, "especialista", 8), "un técnico recolecta en un puesto de recolección; el especialista no opera refinerías")
	var e24c: Node = _nueva(ciudad24)
	e24c.registrar_puesto(Vector2i(60, 60), "siderurgica", 5, 5, {})
	assert(e24c.salida_de(Vector2i(60, 60)) == EconomiaScript.SIN_SERVICIO, "sin salida indicada, SIN_SERVICIO")

	print("\n=== TEST 25: refina hierro y carbón en acero según los técnicos presentes, sin producir de la nada ===")
	var ciudad25: Node = CiudadScript.new()
	var e25: Node = _con_siderurgica(ciudad25)
	e25.puestos[ESQ_REF]["almacen"] = {"hierro": 40.0, "carbon": 40.0}
	e25.simular_hora()
	assert(e25.almacen_local(ESQ_REF) == {"hierro": 40.0, "carbon": 40.0}, "sin técnicos presentes no refina ni deja claves en 0")
	e25.asignar(ESQ_REF, "tecnico", 1)
	e25.asignar(ESQ_REF, "tecnico", 2)
	e25.marcar_presente(1, true)
	e25.simular_hora()
	# 1 técnico presente: 2 lotes -> consume 6 hierro y 8 carbón, produce 4 acero.
	var l25: Dictionary = e25.almacen_local(ESQ_REF)
	assert(is_equal_approx(l25["hierro"], 34.0) and is_equal_approx(l25["carbon"], 32.0) and is_equal_approx(l25["acero"], 4.0))
	e25.marcar_presente(2, true)
	e25.simular_hora()
	# 2 presentes: 4 lotes -> 12 hierro, 16 carbón, 8 acero (más técnicos, más rápido).
	l25 = e25.almacen_local(ESQ_REF)
	assert(is_equal_approx(l25["hierro"], 22.0) and is_equal_approx(l25["carbon"], 16.0) and is_equal_approx(l25["acero"], 12.0))
	assert(is_equal_approx(e25.produccion_por_hora(ESQ_REF)["acero"], 8.0), "el panel muestra 8 acero/h con 2 técnicos")
	e25.puestos[ESQ_REF]["almacen"] = {"acero": 5.0, "hierro": 30.0}
	e25.simular_hora()
	assert(e25.almacen_local(ESQ_REF) == {"acero": 5.0, "hierro": 30.0}, "sin carbón no pasa nada")
	e25.puestos[ESQ_REF]["activo"] = false
	e25.puestos[ESQ_REF]["almacen"] = {"hierro": 20.0, "carbon": 20.0}
	e25.simular_hora()
	assert(e25.almacen_local(ESQ_REF) == {"hierro": 20.0, "carbon": 20.0}, "una refinería inactiva no refina")

	print("\n=== TEST 26: helpers de acarreo: cargar insumos del stock central (3:4), descargarlos y recoger el producto ===")
	var ciudad26: Node = CiudadScript.new()
	var e26: Node = _con_siderurgica(ciudad26)
	ciudad26.almacen["hierro"].cantidad = 300.0
	ciudad26.almacen["carbon"].cantidad = 300.0
	var plan26: Dictionary = e26.insumos_a_cargar(ESQ_REF)
	assert(is_equal_approx(plan26["hierro"], 150.0 * 3.0 / 7.0) and is_equal_approx(plan26["carbon"], 150.0 * 4.0 / 7.0), "tope de carga repartido 3:4")
	assert(is_equal_approx(e26.insumo_a_cargar(ESQ_REF), 150.0))
	var carga26: Dictionary = e26.cargar_insumo(ESQ_REF)
	assert(is_equal_approx(carga26["hierro"], plan26["hierro"]) and is_equal_approx(ciudad26.almacen["carbon"].cantidad, 300.0 - plan26["carbon"]), "salen del stock central")
	e26.descargar_insumo(ESQ_REF, carga26)
	assert(is_equal_approx(e26.almacen_local(ESQ_REF)["carbon"], plan26["carbon"]))
	# Cada insumo tiene su tope local (3/7 y 4/7 de 1000): uno no llena el almacén.
	e26.puestos[ESQ_REF]["almacen"] = {"hierro": 420.0, "carbon": 500.0}
	plan26 = e26.insumos_a_cargar(ESQ_REF)
	assert(is_equal_approx(plan26["hierro"], 1000.0 * 3.0 / 7.0 - 420.0) and is_equal_approx(plan26["carbon"], 1000.0 * 4.0 / 7.0 - 500.0), "queda el hueco de cada uno")
	# Sin espacio libre total (el producto ocupa el resto): no se retira nada.
	e26.puestos[ESQ_REF]["almacen"] = {"hierro": 100.0, "acero": 900.0}
	assert(e26.insumo_a_cargar(ESQ_REF) == 0.0 and e26.cargar_insumo(ESQ_REF).is_empty(), "almacén lleno: no se retira insumo")
	# Solo hay uno de los dos insumos en el stock central: se lleva ese.
	ciudad26.almacen["carbon"].cantidad = 0.0
	e26.puestos[ESQ_REF]["almacen"] = {}
	assert(e26.insumos_a_cargar(ESQ_REF).keys() == ["hierro"], "sin carbón en el stock central solo se lleva hierro")
	ciudad26.almacen["hierro"].cantidad = 0.0
	assert(e26.insumo_a_cargar(ESQ_REF) == 0.0, "stock central sin insumos: nada que cargar")
	# Lo que no cabe al descargar vuelve al stock central (no se pierde).
	e26.puestos[ESQ_REF]["almacen"] = {"acero": 990.0}
	e26.descargar_insumo(ESQ_REF, {"hierro": 40.0})
	assert(is_equal_approx(e26.almacen_local(ESQ_REF)["hierro"], 10.0) and is_equal_approx(ciudad26.almacen["hierro"].cantidad, 30.0))
	# Producto: se recoge hasta la capacidad de carga.
	e26.puestos[ESQ_REF]["almacen"] = {"hierro": 5.0, "acero": 200.0}
	assert(is_equal_approx(e26.producto_pendiente(ESQ_REF), 200.0))
	var producto26: Dictionary = e26.recoger_producto(ESQ_REF, e26.CAPACIDAD_CARGA)
	assert(producto26 == {"acero": 150.0} and is_equal_approx(e26.almacen_local(ESQ_REF)["acero"], 50.0), "solo el producto, hasta 150")
	assert(e26.recoger_producto(Vector2i(0, 0), 150.0).is_empty(), "puesto inexistente")

	print("\n=== TEST 27: falta_insumo(), conviene_cargar() y esta_refinando() (humo de la chimenea) ===")
	var ciudad28: Node = CiudadScript.new()
	var e28: Node = _con_siderurgica(ciudad28)
	assert(e28.falta_insumo(ESQ_REF), "vacía: le falta insumo")
	assert(not e28.conviene_cargar(ESQ_REF), "pero sin nada en el stock central no hay viaje")
	ciudad28.almacen["carbon"].cantidad = 5.0
	assert(e28.conviene_cargar(ESQ_REF), "le falta y hay algo (aunque < CARGA_MINIMA): lo pide")
	ciudad28.almacen["carbon"].cantidad = 0.0
	e28.puestos[ESQ_REF]["almacen"] = {"hierro": 1.4, "carbon": 50.0}
	assert(e28.falta_insumo(ESQ_REF), "1.4 hierro no alcanza para 1 acero (1.5)")
	e28.puestos[ESQ_REF]["almacen"] = {"hierro": 1.5, "carbon": 2.0}
	assert(not e28.falta_insumo(ESQ_REF), "1.5 hierro y 2 carbón alcanzan para 1 acero")
	ciudad28.almacen["hierro"].cantidad = 100.0
	assert(e28.conviene_cargar(ESQ_REF), "no le falta pero hay mucho que llevar: rellena por adelantado")
	e28.puestos[ESQ_REF]["almacen"] = {"hierro": 3.0, "carbon": 4.0}
	assert(not e28.esta_refinando(ESQ_REF), "sin técnicos presentes no hay humo")
	e28.asignar(ESQ_REF, "tecnico", 1)
	e28.marcar_presente(1, true)
	assert(e28.esta_refinando(ESQ_REF), "técnico + 3 hierro + 4 carbón + espacio: humea")
	e28.puestos[ESQ_REF]["almacen"] = {"hierro": 2.9, "carbon": 4.0}
	assert(not e28.esta_refinando(ESQ_REF), "menos de 3 hierro")
	e28.puestos[ESQ_REF]["almacen"] = {"hierro": 3.0, "carbon": 3.9}
	assert(not e28.esta_refinando(ESQ_REF), "menos de 4 carbón")
	e28.puestos[ESQ_REF]["almacen"] = {"hierro": 3.0, "carbon": 4.0, "acero": 993.0}
	assert(not e28.esta_refinando(ESQ_REF), "baúl lleno")
	e28.puestos[ESQ_REF]["almacen"] = {"hierro": 3.0, "carbon": 4.0}
	e28.puestos[ESQ_REF]["activo"] = false
	assert(not e28.esta_refinando(ESQ_REF), "inactiva (deconstruyéndose)")
	assert(not e28.esta_refinando(Vector2i(0, 0)), "puesto inexistente")

	print("\n=== TEST 28: al deconstruir, el almacén local pasa al núcleo (lo que quepa) ===")
	var ciudad27: Node = CiudadScript.new()
	var e27: Node = _nueva(ciudad27)
	var madera27: float = ciudad27.almacen["madera"].cantidad
	e27.puestos[ESQ]["almacen"] = {"madera": 100.0, "piedra": 50.0}
	e27.desactivar_puesto(ESQ)
	assert(is_equal_approx(ciudad27.almacen["madera"].cantidad, madera27 + 100.0), "la madera pasó al stock central")
	assert(e27.almacen_local(ESQ).is_empty(), "el almacén local quedó vacío")
	# Si el stock está casi lleno, solo pasa lo que cabe; el resto se reintenta al quitar el puesto.
	var ciudad27b: Node = CiudadScript.new()
	var e27b: Node = _nueva(ciudad27b)
	ciudad27b.almacen["madera"].cantidad = ciudad27b.almacen["madera"].limite - 30.0
	e27b.puestos[ESQ]["almacen"] = {"madera": 100.0}
	e27b.desactivar_puesto(ESQ)
	assert(is_equal_approx(e27b.almacen_local(ESQ)["madera"], 70.0), "solo cupieron 30")
	ciudad27b.almacen["madera"].cantidad = 0.0  # el stock se vació mientras tanto
	e27b.quitar_puesto(ESQ)
	assert(is_equal_approx(ciudad27b.almacen["madera"].cantidad, 70.0), "al quitar el puesto se reintenta con lo que quedaba")
	# La siderúrgica devuelve su hierro (y su acero) al núcleo en vez de perderlos.
	var ciudad27c: Node = CiudadScript.new()
	var e27c: Node = _con_siderurgica(ciudad27c)
	e27c.puestos[ESQ_REF]["almacen"] = {"hierro": 300.0, "acero": 40.0}
	e27c.desactivar_puesto(ESQ_REF)
	assert(is_equal_approx(ciudad27c.almacen["hierro"].cantidad, 300.0) and is_equal_approx(ciudad27c.almacen["acero"].cantidad, 40.0))

	print("\n=== TEST 29: la escuela técnica forma cohortes: el conteo solo avanza con los 4 aprendices presentes y a las 24 h se gradúan ===")
	var e29: Node = _con_escuela(CiudadScript.new())
	assert(e29.es_escuela(ESQ_ESC) and not e29.es_refineria(ESQ_ESC) and not e29.es_escuela(Vector2i(0, 0)))
	assert(e29.puestos[ESQ_ESC]["cupo"] == 4 and e29.puestos[ESQ_ESC]["capacidad"] == 0, "cupo = cohorte; sin almacén local")
	assert(e29.roles_de(ESQ_ESC) == ["aprendiz"], "solo aprendices")
	assert(not e29.asignar(ESQ_ESC, "recolector", 1) and not e29.asignar(ESQ_ESC, "tecnico", 1) and not e29.asignar(ESQ_ESC, "acarreador", 1), "la escuela solo admite aprendices")
	var e29b: Node = _nueva(CiudadScript.new())
	assert(not e29b.asignar(ESQ, "aprendiz", 9), "un puesto de recolección no admite aprendices")
	var e29c: Node = _con_siderurgica(CiudadScript.new())
	assert(not e29c.asignar(ESQ_REF, "aprendiz", 9), "una refinería tampoco")
	var graduadas29: Array = []
	e29.cohorte_graduada.connect(func(esquina: Vector2i, ids: Array) -> void: graduadas29.append([esquina, ids]))
	for id29 in range(1, 4):
		assert(e29.asignar(ESQ_ESC, "aprendiz", id29))
		e29.marcar_presente(id29, true)
	for hora29 in range(30):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 0.0 and graduadas29.is_empty(), "con 3 aprendices no hay conteo, pasen las horas que pasen")
	assert(e29.asignar(ESQ_ESC, "aprendiz", 4))
	for hora29 in range(5):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 0.0, "el cuarto está asignado pero no presente: el conteo no empieza")
	e29.marcar_presente(4, true)
	for hora29 in range(5):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 5.0, "con los 4 presentes avanza 1 h por hora de juego")
	e29.marcar_presente(2, false)
	for hora29 in range(3):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 5.0, "si uno falta, el conteo se pausa")
	e29.marcar_presente(2, true)
	for hora29 in range(18):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 23.0 and graduadas29.is_empty(), "a las 23 h todavía no se gradúa")
	e29.simular_hora()
	assert(graduadas29.size() == 1 and graduadas29[0][0] == ESQ_ESC and graduadas29[0][1] == [1, 2, 3, 4], "a las 24 h se gradúa la cohorte")
	assert(e29.puestos[ESQ_ESC]["progreso"] == 0.0 and e29.cupo_libre(ESQ_ESC) == 4, "la escuela queda libre para otra cohorte")
	assert(e29.trabajadores_de(ESQ_ESC) == {"recolectores": 0, "acarreadores": 0, "presentes": 0}, "los 4 ya no trabajan ahí")

	print("\n=== TEST 29b: despedir a un aprendiz reinicia el conteo ===")
	var e29d: Node = _con_escuela(CiudadScript.new())
	for id29d in range(1, 5):
		e29d.asignar(ESQ_ESC, "aprendiz", id29d)
		e29d.marcar_presente(id29d, true)
	for hora29d in range(10):
		e29d.simular_hora()
	assert(e29d.puestos[ESQ_ESC]["progreso"] == 10.0)
	e29d.liberar(4)
	assert(e29d.puestos[ESQ_ESC]["progreso"] == 0.0, "al irse uno, la cohorte empieza de nuevo")
	assert(e29d.asignar(ESQ_ESC, "aprendiz", 5))
	assert(e29d.puestos[ESQ_ESC]["progreso"] == 0.0)

	print("\n=== TEST 30: niveles — radios, profundidades, multiplicadores, entorno por nivel y franjas de la mina ===")
	assert(Recoleccion.radio_de_nivel(12, 1) == 12 and Recoleccion.radio_de_nivel(12, 2) == 18 and Recoleccion.radio_de_nivel(12, 3) == 24)
	assert(Recoleccion.radio_de_nivel(25, 2) == 37 and Recoleccion.radio_de_nivel(25, 3) == 50)
	assert(Recoleccion.profundidad_de_nivel(1) == 8 and Recoleccion.profundidad_de_nivel(2) == 16 and Recoleccion.profundidad_de_nivel(3) == 24)
	assert(Recoleccion.multiplicador_de_nivel("mina", 3) == 1.0, "la mina no gana velocidad")
	assert(Recoleccion.multiplicador_de_nivel("maderero", 2) == 1.5 and Recoleccion.multiplicador_de_nivel("pesca_frutos_mar", 3) == 2.0)
	assert(Recoleccion.multiplicador_de_nivel("maderero", 1) == 1.0)
	var mundo30 := MundoBosqueFalso.new()
	for i in range(1, 5):
		mundo30.arboles.registrar([Vector3i(i, 5, i)], 3)
	mundo30.arboles.registrar([Vector3i(15, 5, 0)], 3)  # a 15 celdas: fuera del radio 12, dentro del 18
	var entorno30: Dictionary = Recoleccion.entorno_de_puesto("maderero", mundo30, Vector2i(0, 0), 5)
	assert(entorno30["radio_arboles"] == 12 and entorno30["arboles_ref"] == 4)
	var nivel2_30: Dictionary = Recoleccion.entorno_de_nivel("maderero", mundo30, entorno30, 2)
	assert(nivel2_30["radio_arboles"] == 18 and nivel2_30["arboles_ref"] == 5, "el anillo nuevo suma su árbol a la referencia")
	assert(Recoleccion.entorno_de_nivel("maderero", mundo30, nivel2_30, 2) == nivel2_30, "es idempotente")
	assert(entorno30["radio_arboles"] == 12, "no toca el entorno original")
	# Un maderero colocado sin árboles (referencia 0) empieza a producir al subir si el anillo nuevo tiene árboles.
	var mundo30b := MundoBosqueFalso.new()
	mundo30b.arboles.registrar([Vector3i(15, 5, 0)], 3)
	var vacio30: Dictionary = Recoleccion.entorno_de_puesto("maderero", mundo30b, Vector2i(0, 0), 5)
	assert(vacio30["arboles_ref"] == 0 and Recoleccion.tasas_de_entorno("maderero", mundo30b, vacio30)["madera"] == 0.0)
	var sube30: Dictionary = Recoleccion.entorno_de_nivel("maderero", mundo30b, vacio30, 2)
	assert(sube30["arboles_ref"] == 1 and Recoleccion.tasas_de_entorno("maderero", mundo30b, sube30, 2)["madera"] > 0.0)
	# Franjas de la mina: el hierro de la veta (y=7) queda a 21-22 de profundidad con altura 28 (solo franja del nivel 3) y a 3-4 con altura 10 (solo nivel 1).
	var franjas30: Array = Recoleccion.tasas_mina_por_nivel(_mundo_con_veta(), Vector2i(500, 500), 28)
	assert(franjas30.size() == 3 and franjas30[0].is_empty() and franjas30[1].is_empty(), "a 21-22 de profundidad: solo la franja del nivel 3")
	assert(is_equal_approx(franjas30[2]["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]))
	var franjas30b: Array = Recoleccion.tasas_mina_por_nivel(_mundo_con_veta(), Vector2i(500, 500), 10)
	assert(franjas30b[0].has("hierro") and franjas30b[1].is_empty() and franjas30b[2].is_empty(), "a 3-4 de profundidad: solo el nivel 1")

	print("\n=== TEST 31: el nivel del puesto es el rango mínimo de sus recolectores y limita a quién admite ===")
	var e31: Node = _nueva(CiudadScript.new())
	assert(e31.nivel_de(ESQ) == 1 and e31.tiene_niveles(ESQ))
	assert(e31.asignar(ESQ, "recolector", 1) and e31.asignar(ESQ, "tecnico", 2))
	assert(e31.nivel_de(ESQ) == 1, "con un obrero manda el mínimo")
	e31.liberar(1)
	assert(e31.nivel_de(ESQ) == 2, "solo técnicos: nivel 2")
	assert(not e31.asignar(ESQ, "recolector", 3), "un obrero no entra a un puesto de nivel 2")
	assert(e31.asignar(ESQ, "especialista", 4), "un especialista sí")
	assert(e31.nivel_de(ESQ) == 2 and e31.contar_rango(ESQ, 2) == 1 and e31.contar_rango(ESQ, 3) == 1)
	e31.liberar(2)
	assert(e31.nivel_de(ESQ) == 3, "solo especialistas: nivel 3")
	assert(not e31.asignar(ESQ, "tecnico", 5))
	e31.liberar(4)
	assert(e31.nivel_de(ESQ) == 3 and e31.puestos[ESQ]["recolectores"].is_empty(), "sin recolectores conserva su nivel")
	var e31b: Node = _nueva(CiudadScript.new())
	assert(e31b.asignar(ESQ, "especialista", 1) and e31b.nivel_de(ESQ) == 3, "con especialistas desde el inicio arranca en nivel 3")
	var e31c: Node = _con_siderurgica(CiudadScript.new())
	assert(not e31c.tiene_niveles(ESQ_REF) and e31c.nivel_de(ESQ_REF) == 1)
	assert(e31c.asignar(ESQ_REF, "tecnico", 1) and e31c.nivel_de(ESQ_REF) == 1, "una refinería no tiene niveles")
	var e31d: Node = _con_escuela(CiudadScript.new())
	assert(not e31d.asignar(ESQ_ESC, "tecnico", 1) and not e31d.asignar(ESQ_ESC, "especialista", 1), "la escuela solo admite aprendices")

	print("\n=== TEST 32: los acarreadores no cuentan para el nivel; velocidad por nivel; ultimo_de() por oficio ===")
	var e32: Node = _nueva(CiudadScript.new())
	assert(e32.asignar(ESQ, "acarreador", 1) and e32.nivel_de(ESQ) == 1)
	assert(e32.asignar(ESQ, "tecnico", 2) and e32.nivel_de(ESQ) == 2, "el acarreador (obrero) no frena el nivel")
	e32.marcar_presente(2, true)
	assert(is_equal_approx(e32.produccion_por_hora(ESQ)["madera"], 3.0 * 1.5), "nivel 2: velocidad x1,5")
	assert(e32.ultimo_de(ESQ, "tecnico") == 2 and e32.ultimo_de(ESQ, "recolector") == -1 and e32.ultimo_de(ESQ, "acarreador") == 1)
	var e32b: Node = EconomiaScript.new()
	e32b.ciudad = CiudadScript.new()
	e32b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0})
	assert(e32b.asignar(ESQ, "recolector", 1) and e32b.asignar(ESQ, "tecnico", 2))
	assert(e32b.ultimo_de(ESQ, "recolector") == 1 and e32b.ultimo_de(ESQ, "tecnico") == 2, "cada fila despide a los de su oficio")
	e32b.liberar(1)
	e32b.marcar_presente(2, true)
	assert(e32b.nivel_de(ESQ) == 2 and is_equal_approx(e32b.produccion_por_hora(ESQ)["hierro"], 5.0), "la mina no gana velocidad con el nivel")

	print("\n=== TEST 33: agotado a su nivel, el puesto despide a los de rango mínimo y sube con quien queda ===")
	var e33: Node = EconomiaScript.new()
	e33.ciudad = CiudadScript.new()
	e33.mundo = _mundo_con_veta()
	# Con altura 28 el hierro (y=7) queda a 21-22 de profundidad: solo es alcanzable en el nivel 3.
	e33.registrar_puesto(ESQ, "mina", 5, 5, {}, {"centro": Vector2i(500, 500), "altura": 28})
	e33.recalcular_tasas(ESQ)
	assert(e33.puestos[ESQ]["agotado"] and e33.nivel_de(ESQ) == 1)
	assert(not e33.asignar(ESQ, "recolector", 1), "agotado en nivel 1: no entran obreros")
	assert(e33.asignar(ESQ, "tecnico", 2))
	assert(e33.nivel_de(ESQ) == 2 and e33.puestos[ESQ]["agotado"] and e33.puestos[ESQ]["recolectores"].is_empty(), "sube a 2, sigue agotado y despide al técnico")
	assert(not e33.asignar(ESQ, "tecnico", 3), "agotado en nivel 2: solo especialistas")
	assert(e33.asignar(ESQ, "especialista", 4))
	assert(e33.nivel_de(ESQ) == 3 and not e33.puestos[ESQ]["agotado"] and e33.puestos[ESQ]["recolectores"] == [4], "en nivel 3 alcanza el hierro")
	assert(is_equal_approx(e33.puestos[ESQ]["tasas"]["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]))
	# Personal mixto: al agotarse se va el obrero, el especialista se queda y el puesto sube.
	var e33b: Node = EconomiaScript.new()
	e33b.ciudad = CiudadScript.new()
	e33b.mundo = _mundo_con_veta()
	e33b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 28})
	assert(e33b.asignar(ESQ, "recolector", 1) and e33b.asignar(ESQ, "especialista", 2) and e33b.nivel_de(ESQ) == 1)
	e33b.recalcular_tasas(ESQ)
	assert(e33b.puestos[ESQ]["recolectores"] == [2] and e33b.nivel_de(ESQ) == 3 and not e33b.puestos[ESQ]["agotado"])

	print("\n=== Las 33 pruebas de Economia pasaron correctamente ===")
