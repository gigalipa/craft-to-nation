extends Node

## Pruebas aisladas de Economia.gd, sin escena: una Ciudad real instanciada
## fuera del árbol (igual que ColonosTest.gd) y una Economia nueva con esa
## ciudad inyectada. Corre esta escena y revisa que no lance ningún assert().

const EconomiaScript = preload("res://scripts/Economia.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")

const ESQ := Vector2i(10, 10)


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

	print("\n=== Las 17 pruebas de Economia pasaron correctamente ===")
