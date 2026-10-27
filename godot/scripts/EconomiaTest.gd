extends Node

## Pruebas aisladas de Economia.gd, sin escena: una Ciudad real instanciada
## fuera del árbol (igual que ColonosTest.gd) y una Economia nueva con esa
## ciudad inyectada. Corre esta escena y revisa que no lance ningún assert().

const EconomiaScript = preload("res://scripts/Economia.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")
const Ajustes = preload("res://scripts/ajustes.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")
const EnergiaScript = preload("res://scripts/Energia.gd")

class ZonificacionFalsaEconomia:
	var celdas_influencia: Dictionary = {}
	func dentro_de_influencia(celda: Vector2i) -> bool:
		return celdas_influencia.has(celda)

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



func _ciudad_nueva() -> Node:
	var c: Node = CiudadScript.new()
	c.moral = 50.0  # Moral neutral (1.0x) para pruebas unitarias previas
	return c

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
	var e1: Node = _nueva(_ciudad_nueva())
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
	var e3: Node = _nueva(_ciudad_nueva())
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
	var e4: Node = _nueva(_ciudad_nueva())
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
	var e5: Node = _nueva(_ciudad_nueva())
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
	var e6: Node = _nueva(_ciudad_nueva())
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
	var e7: Node = _nueva(_ciudad_nueva())
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
	var ciudad8: Node = _ciudad_nueva()
	var e8: Node = _nueva(ciudad8)
	var antes8: float = ciudad8.almacen["madera"].cantidad
	e8.entregar({"madera": 20.0, "tierras_raras": 4.0})
	assert(is_equal_approx(ciudad8.almacen["madera"].cantidad, antes8 + 20.0))
	assert(is_equal_approx(ciudad8.almacen["tierras_raras"].cantidad, 4.0))
	e8.entregar({"madera": 5000.0})
	assert(ciudad8.almacen["madera"].cantidad == ciudad8.almacen["madera"].limite, "lo que no cabe se pierde")

	print("\n=== TEST 9: quitar_puesto() libera a los trabajadores y avisa ===")
	var e9: Node = _nueva(_ciudad_nueva())
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
	var ciudad10: Node = _ciudad_nueva()
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
	e11.ciudad = _ciudad_nueva()
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
	e12.ciudad = _ciudad_nueva()
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
	e13.ciudad = _ciudad_nueva()
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
	e13b.ciudad = _ciudad_nueva()
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
	e14.ciudad = _ciudad_nueva()
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
	e15.ciudad = _ciudad_nueva()
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
	e15b.ciudad = _ciudad_nueva()
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
	e16.ciudad = _ciudad_nueva()
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
	e17.ciudad = _ciudad_nueva()
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
	var e18: Node = _nueva(_ciudad_nueva())
	assert(e18.puestos[ESQ]["activo"] and not e18.puestos[ESQ]["agotado"])
	assert(e18.servicio_de(ESQ) == EconomiaScript.SIN_SERVICIO, "sin celda de servicio, Colonos usa el anillo de la huella")
	assert(e18.puestos[ESQ]["deposito"] == EconomiaScript.SIN_DEPOSITO)
	assert(e18.suelo_de(ESQ) == EconomiaScript.SIN_SUELO, "sin plantilla no hay piso interior")
	assert(e18.servicio_de(Vector2i(0, 0)) == EconomiaScript.SIN_SERVICIO, "puesto inexistente")

	print("\n=== TEST 19: desactivar_puesto() libera a todos, es idempotente, pasa el almacén al núcleo y no admite contratar ===")
	var ciudad19: Node = _ciudad_nueva()
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
	var ciudad20: Node = _ciudad_nueva()
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
	e21.ciudad = _ciudad_nueva()
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
	e21b.ciudad = _ciudad_nueva()
	e21b.mundo = _mundo_con_veta()
	e21b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e21b.asignar(ESQ, "acarreador", 7)
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		e21b.mundo.minar_bloque(celda)
	e21b.recalcular_tasas(ESQ)
	assert(e21b.trabajadores_de(ESQ)["acarreadores"] == 0, "agotado y sin almacén: el acarreador también se libera")

	print("\n=== TEST 22: agregar_deposito() pasa al puesto solo lo que cabe en su almacén local y deja el resto en el stock central ===")
	var ciudad22: Node = _ciudad_nueva()
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
	var ciudad23: Node = _ciudad_nueva()
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
	var ciudad24: Node = _ciudad_nueva()
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
	var ciudad25: Node = _ciudad_nueva()
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
	var ciudad26: Node = _ciudad_nueva()
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
	var ciudad28: Node = _ciudad_nueva()
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
	var ciudad27: Node = _ciudad_nueva()
	var e27: Node = _nueva(ciudad27)
	var madera27: float = ciudad27.almacen["madera"].cantidad
	e27.puestos[ESQ]["almacen"] = {"madera": 100.0, "piedra": 50.0}
	e27.desactivar_puesto(ESQ)
	assert(is_equal_approx(ciudad27.almacen["madera"].cantidad, madera27 + 100.0), "la madera pasó al stock central")
	assert(e27.almacen_local(ESQ).is_empty(), "el almacén local quedó vacío")
	# Si el stock está casi lleno, solo pasa lo que cabe; el resto se reintenta al quitar el puesto.
	var ciudad27b: Node = _ciudad_nueva()
	var e27b: Node = _nueva(ciudad27b)
	ciudad27b.almacen["madera"].cantidad = ciudad27b.almacen["madera"].limite - 30.0
	e27b.puestos[ESQ]["almacen"] = {"madera": 100.0}
	e27b.desactivar_puesto(ESQ)
	assert(is_equal_approx(e27b.almacen_local(ESQ)["madera"], 70.0), "solo cupieron 30")
	ciudad27b.almacen["madera"].cantidad = 0.0  # el stock se vació mientras tanto
	e27b.quitar_puesto(ESQ)
	assert(is_equal_approx(ciudad27b.almacen["madera"].cantidad, 70.0), "al quitar el puesto se reintenta con lo que quedaba")
	# La siderúrgica devuelve su hierro (y su acero) al núcleo en vez de perderlos.
	var ciudad27c: Node = _ciudad_nueva()
	var e27c: Node = _con_siderurgica(ciudad27c)
	e27c.puestos[ESQ_REF]["almacen"] = {"hierro": 300.0, "acero": 40.0}
	e27c.desactivar_puesto(ESQ_REF)
	assert(is_equal_approx(ciudad27c.almacen["hierro"].cantidad, 300.0) and is_equal_approx(ciudad27c.almacen["acero"].cantidad, 40.0))

	print("\n=== TEST 29: la escuela técnica forma cohortes: el conteo solo avanza con los 4 aprendices presentes y a las 24 h se gradúan ===")
	var e29: Node = _con_escuela(_ciudad_nueva())
	assert(e29.es_escuela(ESQ_ESC) and not e29.es_refineria(ESQ_ESC) and not e29.es_escuela(Vector2i(0, 0)))
	assert(e29.puestos[ESQ_ESC]["cupo"] == 4 and e29.puestos[ESQ_ESC]["capacidad"] == 0, "cupo = cohorte; sin almacén local")
	assert(e29.roles_de(ESQ_ESC) == ["aprendiz"], "solo aprendices")
	assert(not e29.asignar(ESQ_ESC, "recolector", 1) and not e29.asignar(ESQ_ESC, "tecnico", 1) and not e29.asignar(ESQ_ESC, "acarreador", 1), "la escuela solo admite aprendices")
	var e29b: Node = _nueva(_ciudad_nueva())
	assert(not e29b.asignar(ESQ, "aprendiz", 9), "un puesto de recolección no admite aprendices")
	var e29c: Node = _con_siderurgica(_ciudad_nueva())
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
	var e29d: Node = _con_escuela(_ciudad_nueva())
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

	print("\n=== TEST 29c: la escuela de especialistas dura 48 h y tiene cupo 3 ===")
	assert(Recoleccion.cupo_de("escuela_especialistas") == 3)
	assert(Recoleccion.ESCUELAS["escuela_tecnica"]["horas"] == 24)
	assert(Recoleccion.ESCUELAS["escuela_especialistas"]["horas"] == 48)
	var e29e: Node = EconomiaScript.new()
	e29e.ciudad = _ciudad_nueva()
	e29e.registrar_puesto(ESQ_ESC, "escuela_especialistas", 5, 5, {})
	assert(e29e.puestos[ESQ_ESC]["cupo"] == 3)
	for id_esp in range(1, 4):
		assert(e29e.asignar(ESQ_ESC, "aprendiz", id_esp))
		e29e.marcar_presente(id_esp, true)
	var graduadas_esp: Array = []
	e29e.cohorte_graduada.connect(func(esquina: Vector2i, ids: Array) -> void: graduadas_esp.append([esquina, ids]))
	for h_esp in range(47):
		e29e.simular_hora()
	assert(e29e.puestos[ESQ_ESC]["progreso"] == 47.0 and graduadas_esp.is_empty())
	e29e.simular_hora()
	assert(graduadas_esp.size() == 1 and graduadas_esp[0][1] == [1, 2, 3])
	assert(e29e.puestos[ESQ_ESC]["progreso"] == 0.0)

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
	var e31: Node = _nueva(_ciudad_nueva())
	assert(e31.nivel_de(ESQ) == 1 and e31.tiene_niveles(ESQ))
	assert(e31.asignar(ESQ, "recolector", 1) and e31.asignar(ESQ, "tecnico", 2))
	assert(e31.nivel_de(ESQ) == 1, "con un obrero manda el mínimo")
	e31.liberar(1)
	assert(e31.nivel_de(ESQ) == 2, "solo técnicos: nivel 2")
	assert(e31.asignar(ESQ, "recolector", 3), "un obrero entra si nivel 1 no está agotado")
	assert(e31.nivel_de(ESQ) == 1, "retrocede a nivel 1")
	e31.liberar(3)
	assert(e31.nivel_de(ESQ) == 2, "vuelve a nivel 2")
	assert(e31.asignar(ESQ, "especialista", 4), "un especialista sí")
	assert(e31.nivel_de(ESQ) == 2 and e31.contar_rango(ESQ, 2) == 1 and e31.contar_rango(ESQ, 3) == 1)
	e31.liberar(2)
	assert(e31.nivel_de(ESQ) == 3, "solo especialistas: nivel 3")
	assert(e31.asignar(ESQ, "tecnico", 5), "un técnico entra si nivel 2 no está agotado")
	assert(e31.nivel_de(ESQ) == 2, "retrocede a nivel 2")
	e31.liberar(5)
	assert(e31.nivel_de(ESQ) == 3)
	e31.liberar(4)
	assert(e31.nivel_de(ESQ) == 3 and e31.puestos[ESQ]["recolectores"].is_empty(), "sin recolectores conserva su nivel")
	var e31b: Node = _nueva(_ciudad_nueva())
	assert(e31b.asignar(ESQ, "especialista", 1) and e31b.nivel_de(ESQ) == 3, "con especialistas desde el inicio arranca en nivel 3")
	var e31c: Node = _con_siderurgica(_ciudad_nueva())
	assert(not e31c.tiene_niveles(ESQ_REF) and e31c.nivel_de(ESQ_REF) == 1)
	assert(e31c.asignar(ESQ_REF, "tecnico", 1) and e31c.nivel_de(ESQ_REF) == 1, "una refinería no tiene niveles")
	var e31d: Node = _con_escuela(_ciudad_nueva())
	assert(not e31d.asignar(ESQ_ESC, "tecnico", 1) and not e31d.asignar(ESQ_ESC, "especialista", 1), "la escuela solo admite aprendices")

	print("\n=== TEST 32: los acarreadores no cuentan para el nivel; velocidad por nivel; ultimo_de() por oficio ===")
	var e32: Node = _nueva(_ciudad_nueva())
	assert(e32.asignar(ESQ, "acarreador", 1) and e32.nivel_de(ESQ) == 1)
	assert(e32.asignar(ESQ, "tecnico", 2) and e32.nivel_de(ESQ) == 2, "el acarreador (obrero) no frena el nivel")
	e32.marcar_presente(2, true)
	assert(is_equal_approx(e32.produccion_por_hora(ESQ)["madera"], 3.0 * 1.5), "nivel 2: velocidad x1,5")
	assert(e32.ultimo_de(ESQ, "tecnico") == 2 and e32.ultimo_de(ESQ, "recolector") == -1 and e32.ultimo_de(ESQ, "acarreador") == 1)
	var e32b: Node = EconomiaScript.new()
	e32b.ciudad = _ciudad_nueva()
	e32b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0})
	assert(e32b.asignar(ESQ, "recolector", 1) and e32b.asignar(ESQ, "tecnico", 2))
	assert(e32b.ultimo_de(ESQ, "recolector") == 1 and e32b.ultimo_de(ESQ, "tecnico") == 2, "cada fila despide a los de su oficio")
	e32b.liberar(1)
	e32b.marcar_presente(2, true)
	assert(e32b.nivel_de(ESQ) == 2 and is_equal_approx(e32b.produccion_por_hora(ESQ)["hierro"], 5.0), "la mina no gana velocidad con el nivel")

	print("\n=== TEST 33: agotado a su nivel, el puesto despide a los de rango mínimo y sube con quien queda ===")
	var e33: Node = EconomiaScript.new()
	e33.ciudad = _ciudad_nueva()
	e33.mundo = _mundo_con_veta()
	# Con altura 28 el hierro (y=7) queda a 21-22 de profundidad: solo es alcanzable en el nivel 3.
	e33.registrar_puesto(ESQ, "mina", 5, 5, {}, {"centro": Vector2i(500, 500), "altura": 28})
	e33.recalcular_tasas(ESQ)
	assert(e33.puestos[ESQ]["agotado"] and e33.nivel_de(ESQ) == 1)
	assert(not e33.asignar(ESQ, "recolector", 1), "agotado en nivel 1: no entran obreros")
	assert(not e33.asignar(ESQ, "tecnico", 2), "contratado y despedido al instante: asignar devuelve falso")
	assert(e33.nivel_de(ESQ) == 2 and e33.puestos[ESQ]["agotado"] and e33.puestos[ESQ]["recolectores"].is_empty(), "sube a 2, sigue agotado y despide al técnico")
	assert(not e33.asignar(ESQ, "tecnico", 3), "agotado en nivel 2: solo especialistas")
	assert(e33.asignar(ESQ, "especialista", 4))
	assert(e33.nivel_de(ESQ) == 3 and not e33.puestos[ESQ]["agotado"] and e33.puestos[ESQ]["recolectores"] == [4], "en nivel 3 alcanza el hierro")
	assert(is_equal_approx(e33.puestos[ESQ]["tasas"]["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]))
	# Personal mixto: al agotarse se va el obrero, el especialista se queda y el puesto sube.
	var e33b: Node = EconomiaScript.new()
	e33b.ciudad = _ciudad_nueva()
	e33b.mundo = _mundo_con_veta()
	e33b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 28})
	assert(e33b.asignar(ESQ, "recolector", 1) and e33b.asignar(ESQ, "especialista", 2) and e33b.nivel_de(ESQ) == 1)
	e33b.recalcular_tasas(ESQ)
	assert(e33b.puestos[ESQ]["recolectores"] == [2] and e33b.nivel_de(ESQ) == 3 and not e33b.puestos[ESQ]["agotado"])

	print("\n=== TEST 34: desactivar_puesto() no sube el nivel según el orden de las bajas y avisa una vez por colono ===")
	# Con el técnico primero el puesto subiría a 2 y rechazaría al obrero: el único orden posible es obrero, técnico.
	var e34: Node = _nueva(_ciudad_nueva())
	var liberados34: Array = []
	e34.trabajadores_liberados.connect(func(ids: Array) -> void: liberados34.append_array(ids))
	assert(e34.asignar(ESQ, "recolector", 1) and e34.asignar(ESQ, "tecnico", 2) and e34.nivel_de(ESQ) == 1)
	e34.desactivar_puesto(ESQ)
	liberados34.sort()
	assert(e34.nivel_de(ESQ) == 1 and liberados34 == [1, 2], "el nivel no sube y cada id se avisa una vez")
	e34.reactivar_puesto(ESQ)
	assert(e34.asignar(ESQ, "recolector", 3), "tras reactivar sigue en nivel 1 y admite obreros")

	print("\n=== TEST 35: universidad como puesto de investigación, agregación de horas y liberación al completar ===")
	var c35: Node = _ciudad_nueva()
	c35.instalaciones["tipo_2"] = 3  # habilita nivel potencial 2
	c35.almacen["hierro"].cantidad = 500.0
	c35.almacen["madera"].cantidad = 500.0
	var e35: Node = EconomiaScript.new()
	e35.ciudad = c35
	var esq_uni := Vector2i(70, 70)
	e35.registrar_puesto(esq_uni, "universidad", 5, 5, {})
	assert(e35.puestos[esq_uni]["cupo"] == 3)
	assert(e35.puestos[esq_uni]["capacidad"] == 0)
	assert(e35.roles_de(esq_uni) == ["investigador"])
	assert(e35.asignar(esq_uni, "investigador", 101))
	assert(e35.asignar(esq_uni, "investigador", 102))
	assert(not e35.asignar(esq_uni, "recolector", 103), "no admite recolector")
	assert(e35.iniciar_investigacion(esq_uni, 2))
	# Sin presencia no suma horas
	e35.simular_hora()
	assert(c35.progreso_investigacion[2] == 0.0)
	# Marcando 2 presentes: suma 2 horas por simular_hora()
	e35.marcar_presente(101, true)
	e35.marcar_presente(102, true)
	e35.simular_hora()
	assert(c35.progreso_investigacion[2] == 2.0)
	# Pausa de investigación
	e35.pausar_investigacion(esq_uni, true)
	e35.simular_hora()
	assert(c35.progreso_investigacion[2] == 2.0, "pausado no avanza")
	e35.pausar_investigacion(esq_uni, false)
	# Avanzamos hasta completar el nivel 2 (meta 20 h, faltan 18 h -> 9 horas con 2 presentes)
	for _i in range(8):
		e35.simular_hora()
	assert(c35.progreso_investigacion[2] == 18.0)
	assert(c35.nivel_investigado == 1)
	assert(e35.puestos[esq_uni]["recolectores"].size() == 2)
	# La 9ª hora completa los 20 h y activa la investigación
	var finalizada_notificada := [false]
	e35.investigacion_finalizada.connect(func(_nom: String) -> void: finalizada_notificada[0] = true)
	e35.simular_hora()
	assert(c35.nivel_investigado == 2)
	assert(finalizada_notificada[0], "emite señal de investigación finalizada")
	assert(e35.puestos[esq_uni]["investigacion_activa"] == 0, "limpia investigación activa al completar")
	assert(e35.puestos[esq_uni]["recolectores"].size() == 2, "al completar investigación preserva a los investigadores")
	# Probar cancelación y reembolso
	assert(e35.iniciar_investigacion(esq_uni, 3))
	var h_antes: float = c35.almacen["hierro"].cantidad
	var m_antes: float = c35.almacen["madera"].cantidad
	c35.consumir_costos({"hierro": 800, "madera": 100})
	e35.cancelar_investigacion(esq_uni)
	assert(e35.puestos[esq_uni]["investigacion_activa"] == 0)
	assert(c35.almacen["hierro"].cantidad == h_antes, "reembolsa hierro")
	assert(c35.almacen["madera"].cantidad == m_antes, "reembolsa madera")

	print("\n=== TEST 36: acarreo de productor_combustible solo carga carbon (agua excluida de acarreo) ===")
	var c36: Node = _ciudad_nueva()
	c36.almacen["carbon"].cantidad = 500.0
	c36.almacen["agua"].cantidad = 500.0
	var e36: Node = EconomiaScript.new()
	e36.ciudad = c36
	var esq_prod := Vector2i(90, 90)
	e36.registrar_puesto(esq_prod, "productor_combustible", 5, 5, {})
	assert(e36.es_refineria(esq_prod))
	assert(e36.insumo_de(esq_prod) == "combustible_sintetico")
	var entradas36: Dictionary = e36.entradas_de(esq_prod)
	assert(entradas36 == {"carbon": 3, "agua": 1})
	var carga36: Dictionary = e36.insumos_a_cargar(esq_prod)
	# Agua es líquido (se excluye de acarreo); todo el cupo de acarreo de insumo va a carbon
	assert(is_equal_approx(carga36["carbon"], 150.0))
	assert(not carga36.has("agua"), "el agua no se transporta por acarreo")

	print("\n=== TEST 37: Balance energético, factor de déficit y consumo proporcional en centrales ===")
	var c37: Node = _ciudad_nueva()
	var e37: Node = EconomiaScript.new()
	e37.ciudad = c37
	var z37 := ZonificacionFalsaEconomia.new()
	for x in range(21):
		for z in range(21):
			z37.celdas_influencia[Vector2i(x, z)] = true
	e37.zonificacion = z37

	# Registramos una central térmica en [0, 0]
	var esq_central := Vector2i(0, 0)
	e37.registrar_puesto(esq_central, "central_termoelectrica", 5, 5, {})
	e37.puestos[esq_central]["presentes"] = {1: true, 2: true, 3: true}
	e37.puestos[esq_central]["almacen"] = {"combustible": 10.0}

	# Caso A: demanda 0 / capacidad 60 => quema 0
	e37.simular_hora()
	var resA: Dictionary = e37.resumen_energia()
	assert(resA["demanda"] == 0.0)
	assert(resA["capacidad"] == 60.0)
	assert(resA["entregada"] == 0.0)
	assert(resA["factor"] == 1.0)
	assert(resA["deficit"] == false)
	assert(is_equal_approx(e37.puestos[esq_central]["almacen"]["combustible"], 10.0))

	# Caso B: demanda 15 / capacidad 60 => quema 0.75
	var esq_ref := Vector2i(5, 5)
	e37.registrar_puesto(esq_ref, "refineria_petrolera", 5, 5, {})
	var pres_ref := {}
	for i in range(15):
		pres_ref[10 + i] = true
	e37.puestos[esq_ref]["presentes"] = pres_ref
	e37.puestos[esq_ref]["almacen"] = {"crudo": 100.0}

	e37.simular_hora()
	var resB: Dictionary = e37.resumen_energia()
	assert(is_equal_approx(resB["demanda"], 15.0))
	assert(is_equal_approx(resB["capacidad"], 60.0))
	assert(is_equal_approx(resB["entregada"], 15.0))
	assert(is_equal_approx(resB["factor"], 1.0))
	assert(resB["deficit"] == false)
	assert(is_equal_approx(e37.puestos[esq_central]["almacen"]["combustible"], 9.25))

	# Caso C: demanda 50 / capacidad 20 => factor 0.4 para todos; desconectado => factor 0
	e37.puestos[esq_central]["presentes"] = {1: true}
	var pres50 := {}
	for i in range(50):
		pres50[100 + i] = true
	e37.puestos[esq_ref]["presentes"] = pres50
	var esq_desc := Vector2i(50, 50)
	e37.registrar_puesto(esq_desc, "productor_combustible", 5, 5, {})
	e37.puestos[esq_desc]["presentes"] = {200: true, 201: true}

	var redC: Dictionary = EnergiaScript.calcular(e37.puestos, z37, e37.vias, c37)
	assert(is_equal_approx(redC["resumen"]["demanda"], 50.0))
	assert(is_equal_approx(redC["resumen"]["capacidad"], 20.0))
	assert(is_equal_approx(redC["resumen"]["factor"], 0.4))
	assert(is_equal_approx(redC["factores"][esq_ref], 0.4))
	assert(redC["factores"][esq_desc] == 0.0)

	# Caso D: dos centrales reparten quema proporcionalmente a su capacidad (20 vs 60, total 80)
	var esq_central2 := Vector2i(10, 0)
	e37.registrar_puesto(esq_central2, "central_termoelectrica", 5, 5, {})
	e37.puestos[esq_central2]["presentes"] = {301: true, 302: true, 303: true}
	e37.puestos[esq_central]["almacen"] = {"combustible": 5.0}
	e37.puestos[esq_central2]["almacen"] = {"combustible": 5.0}
	var pres20 := {}
	for i in range(20):
		pres20[i] = true
	e37.puestos[esq_ref]["presentes"] = pres20
	e37.puestos.erase(esq_desc)

	e37.simular_hora()
	assert(is_equal_approx(e37.puestos[esq_central]["almacen"]["combustible"], 5.0 - 0.25))
	assert(is_equal_approx(e37.puestos[esq_central2]["almacen"]["combustible"], 5.0 - 0.75))

	# Caso E: prioridad combustible -> crudo -> carbon
	e37.puestos.erase(esq_central2)
	e37.puestos[esq_central]["presentes"] = {1: true}
	e37.puestos[esq_central]["almacen"] = {"combustible": 0.2, "crudo": 0.5, "carbon": 2.0}
	e37.simular_hora()
	assert(not e37.puestos[esq_central]["almacen"].has("combustible"))
	assert(not e37.puestos[esq_central]["almacen"].has("crudo"))
	assert(is_equal_approx(e37.puestos[esq_central]["almacen"]["carbon"], 1.7))

	print("\n=== TEST 38: Puestos industriales de combustible y energía (cupo, capacidad, no acarreo de líquidos, selector) ===")
	var c38: Node = _ciudad_nueva()
	c38.almacen["crudo"].cantidad = 50.0
	c38.almacen["combustible"].cantidad = 40.0
	c38.almacen["carbon"].cantidad = 60.0
	var e38: Node = EconomiaScript.new()
	e38.ciudad = c38

	# Refinería petrolera: solo técnicos, no admite acarreadores, no carga líquidos
	var esq_pet := Vector2i(10, 10)
	e38.registrar_puesto(esq_pet, "refineria_petrolera", 5, 5, {})
	assert(e38.puestos[esq_pet]["cupo"] == 4)
	assert(e38.puestos[esq_pet]["capacidad"] == 1000)
	assert(e38.roles_de(esq_pet) == ["tecnico"], "refineria petrolera solo admite tecnicos")
	var carga_pet: Dictionary = e38.insumos_a_cargar(esq_pet)
	assert(carga_pet.is_empty(), "acarreadores no cargan crudo ni liquidos")

	# Central termoeléctrica: selector de combustible (carbon por defecto, o combustible, o crudo)
	var esq_cen := Vector2i(20, 20)
	e38.registrar_puesto(esq_cen, "central_termoelectrica", 5, 5, {})
	assert(e38.puestos[esq_cen]["cupo"] == 4)
	assert(e38.puestos[esq_cen]["capacidad"] == 500)
	# Modo carbon: admite acarreador y carga carbón
	assert(e38.roles_de(esq_cen) == ["tecnico", "acarreador"])
	var carga_cen_carbon: Dictionary = e38.insumos_a_cargar(esq_cen)
	assert(carga_cen_carbon.has("carbon") and is_equal_approx(carga_cen_carbon["carbon"], 60.0))
	assert(not carga_cen_carbon.has("combustible") and not carga_cen_carbon.has("crudo"))

	# Cambiar central a combustible líquido: desalojar acarreadores y no cargar líquidos
	assert(e38.asignar(esq_cen, "acarreador", 101))
	assert(e38.puestos[esq_cen]["acarreadores"].has(101))
	e38.cambiar_combustible_central(esq_cen, "combustible")
	assert(e38.roles_de(esq_cen) == ["tecnico"], "modo combustible no admite acarreadores")
	assert(not e38.puestos[esq_cen]["acarreadores"].has(101), "acarreador liberado al cambiar a liquido")
	assert(e38.insumos_a_cargar(esq_cen).is_empty(), "en modo liquido no hay carga por acarreo")

	print("\n=== TEST 39: puesto en nivel 2 permite retroceder a nivel 1 al contratar obrero si no está agotado en nivel 1 ===")
	var c39: Node = _ciudad_nueva()
	var e39: Node = EconomiaScript.new()
	e39.ciudad = c39
	var esq_mina := Vector2i(30, 30)
	e39.mundo = _mundo_con_veta()
	# Con altura 10, la veta en y=7..8 queda a profundidad 2..3 (alcanzable en nivel 1)
	e39.registrar_puesto(esq_mina, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	# Se asigna solo un técnico: el puesto pasa a nivel 2
	assert(e39.asignar(esq_mina, "tecnico", 1))
	assert(e39.nivel_de(esq_mina) == 2, "solo técnicos: nivel 2")
	# Dado que nivel 1 no está agotado, admite_rol debe permitir recolector (obrero)
	assert(e39.admite_rol(esq_mina, "recolector"), "admite recolector porque nivel 1 tiene hierro")
	# Asignar un obrero hace retroceder el puesto a nivel 1
	assert(e39.asignar(esq_mina, "recolector", 2))
	assert(e39.nivel_de(esq_mina) == 1, "con un obrero y un técnico el nivel retrocede a 1 (manda el menor)")

	print("\n=== TEST 40: roles de estacion_bombeo, centro_extraccion, productor_combustible y supresión de acarreo de líquidos ===")
	var c40: Node = _ciudad_nueva()
	c40.almacen["agua"].cantidad = 100.0
	c40.almacen["carbon"].cantidad = 50.0
	var e40: Node = EconomiaScript.new()
	e40.ciudad = c40

	var esq_bom40 := Vector2i(40, 40)
	e40.registrar_puesto(esq_bom40, "estacion_bombeo", 4, 6, {"agua": 4.0})
	assert(e40.puestos[esq_bom40]["cupo"] == 3)
	assert(e40.roles_de(esq_bom40) == ["tecnico"])
	assert(e40.recoger(esq_bom40, 50.0).is_empty(), "recoger no entrega liquidos a acarreadores")

	var esq_ext40 := Vector2i(50, 50)
	e40.registrar_puesto(esq_ext40, "centro_extraccion", 5, 5, {"crudo": 5.0})
	assert(e40.puestos[esq_ext40]["cupo"] == 3)
	assert(e40.roles_de(esq_ext40) == ["tecnico"])
	assert(e40.recoger(esq_ext40, 50.0).is_empty())

	var esq_prod40 := Vector2i(60, 60)
	e40.registrar_puesto(esq_prod40, "productor_combustible", 5, 5, {})
	assert(e40.roles_de(esq_prod40) == ["tecnico", "acarreador"])
	var carga_prod40: Dictionary = e40.insumos_a_cargar(esq_prod40)
	assert(carga_prod40.has("carbon"), "productor combustible carga carbon por acarreo")
	assert(not carga_prod40.has("agua"), "productor combustible no carga agua por acarreo")

	print("\n=== TEST 41: Red de distribución compartida entre almacenes para fluidos ===")
	var c41: Node = _ciudad_nueva()
	var e41: Node = EconomiaScript.new()
	e41.ciudad = c41

	# Registrar dos almacenes distantes
	var esq_alm_a := Vector2i(10, 10)
	var esq_alm_b := Vector2i(80, 80)
	e41.registrar_puesto(esq_alm_a, "almacen", 5, 5, {})
	e41.registrar_puesto(esq_alm_b, "almacen", 5, 5, {})

	assert(e41.reserva_fluidos.has("agua"), "reserva_fluidos contiene agua")
	assert(e41.reserva_fluidos.has("crudo"), "reserva_fluidos contiene crudo")
	assert(e41.reserva_fluidos.has("combustible"), "reserva_fluidos contiene combustible")

	# Ingresar agua en Almacén A
	var ingresado: float = e41.ingresar_fluido_almacen("agua", 120.0)
	assert(ingresado == 120.0, "se ingresan 120 unidades de agua")
	assert(e41.reserva_fluidos["agua"] == 120.0, "reserva global de agua tiene 120")

	# Retirar agua a través de Almacén B
	var extraido: float = e41.extraer_fluido_almacen("agua", 50.0)
	assert(extraido == 50.0, "se extraen 50 unidades de agua desde el pool compartido")
	assert(e41.reserva_fluidos["agua"] == 70.0, "quedan 70 unidades en la reserva")
	print("OK: Red compartida de almacenes permite extraer fluidos desde cualquier almacén.")

	print("\n=== TEST 42: Logística de carbón para central (capacidad 500) y partición estricta en refinería petrolera (400/600) ===")
	var c42: Node = _ciudad_nueva()
	c42.almacen["carbon"].cantidad = 300.0
	c42.almacen["crudo"].cantidad = 500.0
	var e42: Node = EconomiaScript.new()
	e42.ciudad = c42

	# 1. Central termoeléctrica: capacidad 500, acarreo de 150 si stock < 500
	var esq_cen42 := Vector2i(25, 25)
	e42.registrar_puesto(esq_cen42, "central_termoelectrica", 5, 5, {})
	assert(e42.puestos[esq_cen42]["capacidad"] == 500, "capacidad fijada en 500")
	assert(e42.es_central_termoelectrica(esq_cen42))

	# Si stock < 500, insumos_a_cargar ofrece 150 (CAPACIDAD_CARGA)
	var plan_cen: Dictionary = e42.insumos_a_cargar(esq_cen42)
	assert(plan_cen.has("carbon") and is_equal_approx(plan_cen["carbon"], 150.0))

	# Carga de carbón de núcleo retira 150
	var cargado42: Dictionary = e42.cargar_carbon_de_nucleo(150.0)
	assert(is_equal_approx(cargado42["carbon"], 150.0))
	assert(is_equal_approx(c42.almacen["carbon"].cantidad, 150.0))

	# Descarga en la central: con stock 0, espacio es 500 >= 150, se entregan 150
	e42.descargar_insumo(esq_cen42, cargado42)
	assert(is_equal_approx(e42.almacen_local(esq_cen42)["carbon"], 150.0))

	# Si stock es 400, el espacio es 100 (< 150): descargar_insumo solo admite lo que cabe
	e42.puestos[esq_cen42]["almacen"]["carbon"] = 400.0
	assert(is_equal_approx(e42.espacio_disponible_para(esq_cen42, "carbon"), 100.0))
	var carga_exceso := {"carbon": 150.0}
	e42.descargar_insumo(esq_cen42, carga_exceso)
	assert(is_equal_approx(e42.almacen_local(esq_cen42)["carbon"], 500.0))
	assert(is_equal_approx(c42.almacen["carbon"].cantidad, 200.0), "el exceso (50) volvió al núcleo")

	# Si stock >= 500, no se pide más carbón
	assert(e42.insumos_a_cargar(esq_cen42).is_empty(), "con stock 500 no se cargan insumos")

	# Modo combustible o crudo no admite acarreadores
	e42.cambiar_combustible_central(esq_cen42, "crudo")
	assert(e42.roles_de(esq_cen42) == ["tecnico"], "modo crudo solo admite técnicos")
	assert(e42.insumos_a_cargar(esq_cen42).is_empty(), "modo crudo no admite carga por acarreo")

	# 2. Refinería petrolera: capacidad 1000, max 400 crudo (40%) y 600 combustible (60%)
	var esq_ref42 := Vector2i(45, 45)
	e42.registrar_puesto(esq_ref42, "refineria_petrolera", 5, 5, {})
	assert(e42.puestos[esq_ref42]["capacidad"] == 1000)
	assert(is_equal_approx(e42.espacio_disponible_para(esq_ref42, "crudo"), 400.0), "espacio inicial para crudo es 400")
	assert(is_equal_approx(e42.espacio_disponible_para(esq_ref42, "combustible"), 600.0), "espacio inicial para combustible es 600")

	# Inyección de 350 unidades de crudo
	var inyectado_1: float = e42.inyectar_fluido_puesto(esq_ref42, "crudo", 350.0)
	assert(is_equal_approx(inyectado_1, 350.0))
	assert(is_equal_approx(e42.puestos[esq_ref42]["almacen"]["crudo"], 350.0))
	assert(is_equal_approx(e42.espacio_disponible_para(esq_ref42, "crudo"), 50.0), "quedan 50 unidades de espacio de crudo")

	# Inyectar 100 unidades más de crudo: solo debe aceptar 50 hasta alcanzar 400
	var inyectado_2: float = e42.inyectar_fluido_puesto(esq_ref42, "crudo", 100.0)
	assert(is_equal_approx(inyectado_2, 50.0), "solo admite 50 unidades para no superar 400")
	assert(is_equal_approx(e42.puestos[esq_ref42]["almacen"]["crudo"], 400.0))

	# Con stock de crudo >= 400, inyección se detiene (0 admitido)
	var inyectado_3: float = e42.inyectar_fluido_puesto(esq_ref42, "crudo", 50.0)
	assert(is_equal_approx(inyectado_3, 0.0), "detiene inyección si stock crudo >= 400")
	assert(is_equal_approx(e42.espacio_disponible_para(esq_ref42, "crudo"), 0.0))

	# Combustible puede inyectarse / acumularse hasta 600
	var inyectado_comb: float = e42.inyectar_fluido_puesto(esq_ref42, "combustible", 700.0)
	assert(is_equal_approx(inyectado_comb, 600.0), "combustible se limita a reserva de 600")
	assert(is_equal_approx(e42.puestos[esq_ref42]["almacen"]["combustible"], 600.0))
	assert(is_equal_approx(e42.espacio_disponible_para(esq_ref42, "combustible"), 0.0))

	print("\n=== TEST 43: reserva_insumo en refinerías y central termoeléctrica ===")
	var c43: Node = _ciudad_nueva()
	var e43: Node = EconomiaScript.new()
	e43.ciudad = c43
	assert(e43.PORCENTAJES_RESERVA_INSUMO == [0.0, 0.10, 0.20, 0.35, 0.50])

	var esq_aserradero := Vector2i(10, 10)
	e43.registrar_puesto(esq_aserradero, "aserradero", 5, 5, {})
	assert(e43.obtener_reserva_insumo(esq_aserradero) == 0.0, "reserva inicial es 0")

	# Subir y bajar reserva por porcentajes
	assert(is_equal_approx(e43.subir_reserva_insumo(esq_aserradero), 0.10))
	assert(is_equal_approx(e43.subir_reserva_insumo(esq_aserradero), 0.20))
	assert(is_equal_approx(e43.subir_reserva_insumo(esq_aserradero), 0.35))
	assert(is_equal_approx(e43.subir_reserva_insumo(esq_aserradero), 0.50))
	assert(is_equal_approx(e43.subir_reserva_insumo(esq_aserradero), 0.50), "tope máximo en 50%")
	assert(is_equal_approx(e43.bajar_reserva_insumo(esq_aserradero), 0.35))
	assert(is_equal_approx(e43.bajar_reserva_insumo(esq_aserradero), 0.20))
	assert(is_equal_approx(e43.bajar_reserva_insumo(esq_aserradero), 0.10))
	assert(is_equal_approx(e43.bajar_reserva_insumo(esq_aserradero), 0.0))
	assert(is_equal_approx(e43.bajar_reserva_insumo(esq_aserradero), 0.0), "tope mínimo en 0%")

	# Reserva porcentual sobre almacén: límite de madera es 500, reserva de 20% = 100 u.
	c43.almacen["madera"].limite = 500.0
	e43.establecer_reserva_insumo(esq_aserradero, 0.20)
	assert(is_equal_approx(e43.calcular_reserva_en_unidades(esq_aserradero, "madera"), 100.0))

	# Insumos a cargar respetando la reserva porcentual
	c43.almacen["madera"].cantidad = 130.0
	# Disponible en ciudad: 130 - 100 = 30. Carga = min(30, 30) = 30.
	var plan1: Dictionary = e43.insumos_a_cargar(esq_aserradero)
	assert(is_equal_approx(plan1.get("madera", 0.0), 30.0))

	# Si ciudad tiene 115 de madera y reserva es 100: disponible = 15 < 30. Carga = 15.
	c43.almacen["madera"].cantidad = 115.0
	var plan2: Dictionary = e43.insumos_a_cargar(esq_aserradero)
	assert(is_equal_approx(plan2.get("madera", 0.0), 15.0))

	# Si ciudad tiene 100 o menos de madera y reserva es 100: disponible = 0. No carga nada.
	c43.almacen["madera"].cantidad = 90.0
	var plan3: Dictionary = e43.insumos_a_cargar(esq_aserradero)
	assert(plan3.is_empty(), "bajo la reserva no se cargan insumos")

	# Compatibilidad con valores fijos directos (ej. 50 u fijas):
	var esq_fabrica := Vector2i(20, 20)
	e43.registrar_puesto(esq_fabrica, "fabrica_bloques", 5, 6, {})
	e43.establecer_reserva_insumo(esq_fabrica, 50.0)
	c43.almacen["piedra"].cantidad = 60.0
	var plan_fb: Dictionary = e43.insumos_a_cargar(esq_fabrica)
	assert(is_equal_approx(plan_fb.get("piedra", 0.0), 10.0), "solo puede cargar 10 de piedra dejando 50 de reserva")

	# Prueba con central termoeléctrica
	var esq_termo := Vector2i(30, 30)
	e43.registrar_puesto(esq_termo, "central_termoelectrica", 5, 5, {})
	e43.establecer_reserva_insumo(esq_termo, 250.0)
	c43.almacen["carbon"].cantidad = 260.0
	var plan_termo: Dictionary = e43.insumos_a_cargar(esq_termo)
	assert(is_equal_approx(plan_termo.get("carbon", 0.0), 10.0), "central termoeléctrica solo carga 10 de carbón")

	print("\n=== TEST 44: Modulación de Productividad y Refinado por Moral Ciudadana ===")
	var c44: Node = CiudadScript.new()
	var e44: Node = EconomiaScript.new()
	e44.ciudad = c44

	var esq_mad := Vector2i(5, 5)
	e44.registrar_puesto(esq_mad, "maderero", 3, 4, {"madera": 10.0})
	e44.asignar(esq_mad, "recolector", 101)
	e44.marcar_presente(101, true)

	# 1. Moral 50 -> Factor 1.0 (Producción nominal: 10.0)
	c44.moral = 50.0
	var prod_50: Dictionary = e44.produccion_por_hora(esq_mad)
	assert(is_equal_approx(prod_50.get("madera", 0.0), 10.0), "moral 50 rinde al 100%% (1.0x)")

	# 2. Moral 0 -> Factor 0.5 (Producción mínima: 5.0)
	c44.moral = 0.0
	var prod_0: Dictionary = e44.produccion_por_hora(esq_mad)
	assert(is_equal_approx(prod_0.get("madera", 0.0), 5.0), "moral 0 rinde al 50%% (0.5x)")

	# 3. Moral 100 -> Factor 2.0 (Producción máxima: 20.0)
	c44.moral = 100.0
	var prod_100: Dictionary = e44.produccion_por_hora(esq_mad)
	assert(is_equal_approx(prod_100.get("madera", 0.0), 20.0), "moral 100 rinde al 200%% (2.0x)")

	# 4. Refinado modulado por moral en siderúrgica
	var esq_sid := Vector2i(15, 15)
	e44.registrar_puesto(esq_sid, "siderurgica", 5, 5, {})
	e44.asignar(esq_sid, "tecnico", 201)
	e44.marcar_presente(201, true)
	c44.moral = 100.0
	var prod_ref_100: Dictionary = e44.produccion_por_hora(esq_sid)
	# Tasa nominal de siderúrgica con 1 técnico es 4.0 acero/h; con moral 100 (2.0x) debe ser 8.0
	assert(is_equal_approx(prod_ref_100.get("acero", 0.0), 8.0), "refinado a moral 100 se modula al 2.0x")

	print("\n=== TEST 45: Productividad protegida para puestos de comida a moral cero ===")
	var c_m0: Node = CiudadScript.new()
	c_m0.moral = 0.0
	var e_m0: Node = _nueva(c_m0)
	e_m0.asignar(ESQ, "recolector", 1)
	e_m0.marcar_presente(1, true)
	# Maderero (no alimento): rinde a 0.5x
	var prod_mad: Dictionary = e_m0.produccion_por_hora(ESQ)
	assert(is_equal_approx(prod_mad["madera"], 3.0 * 0.5), "maderero a moral 0 rinde a 0.5x")
	# Puesto de caza (alimento): rinde a 0.75x mínimo
	e_m0.registrar_puesto(Vector2i(60, 60), "caza_recoleccion", 4, 4, {"caza": 4.0})
	e_m0.asignar(Vector2i(60, 60), "recolector", 2)
	e_m0.marcar_presente(2, true)
	var prod_caza: Dictionary = e_m0.produccion_por_hora(Vector2i(60, 60))
	assert(is_equal_approx(prod_caza["comida"], 4.0 * 0.75), "puesto de comida a moral 0 rinde al 0.75x")

	print("\n=== TEST 46: Generación horaria de puntos de ciencia ===")
	var e46: Node = EconomiaScript.new()
	var delta_pts: float = e46.calcular_delta_puntos_ciencia(4, 1.0, true) # 4 inv, 1.0 moral, con energia
	assert(is_equal_approx(delta_pts, 4.0))
	var delta_sin_e: float = e46.calcular_delta_puntos_ciencia(4, 1.0, false)
	assert(is_equal_approx(delta_sin_e, 2.0))
	var delta_moral: float = e46.calcular_delta_puntos_ciencia(4, 0.5, true)
	assert(is_equal_approx(delta_moral, 2.0))

	# Integración con ciudad en _tick_universidad
	var c46: Node = CiudadScript.new()
	c46.era_actual = 2
	c46.moral = 50.0
	assert(c46.iniciar_ciencia_teorica("metalurgia_hornos"))
	e46.ciudad = c46
	var esq_uni46 := Vector2i(10, 10)
	e46.registrar_puesto(esq_uni46, "universidad", 5, 5, {})
	e46.puestos[esq_uni46]["presentes"] = {1: true, 2: true} # 2 investigadores
	e46._tick_universidad(esq_uni46, 1.0)
	# 2 investigadores * 1.0 moral * 1.0 energia = 2.0 puntos acumulados
	assert(is_equal_approx(c46.progreso_ciencia_teorica.get("metalurgia_hornos", 0.0), 2.0))

	print("\n=== TEST 47: Capa 2 - Aplicación Práctica y Reconversión Doctrinal ===")
	var e47: Node = EconomiaScript.new()
	var c47: Node = CiudadScript.new()
	e47.ciudad = c47
	# Asignar recursos suficientes para sufragar mejoras y reconversión
	for r in ["acero", "combustible", "cristal", "tierras_raras", "hierro", "madera", "piedra", "tierra"]:
		if not c47.almacen.has(r):
			c47.almacen[r] = CiudadScript.Recurso.new(r.capitalize(), 1000.0, 5000.0)
		else:
			c47.almacen[r].cantidad = 1000.0

	# Registrar central termoeléctrica
	var esq_termo47 := Vector2i(10, 10)
	e47.registrar_puesto(esq_termo47, "central_termoelectrica", 5, 5, {})
	c47.ciencias_teoricas_descubiertas.append("quimica_hidrocarburos")
	c47.ciencias_teoricas_descubiertas.append("biotecnologia_fototermia")

	# Instalar mejora dieselpunk
	assert(e47.iniciar_mejora_practica(esq_termo47, "caldera_diesel"))
	assert(e47.puestos[esq_termo47]["proyecto_mejora"]["estado"] == "ESPERANDO_PERSONAL")
	# Simular llegada y finalización
	e47.completar_mejora_en_puesto(esq_termo47)
	assert(e47.puestos[esq_termo47]["mejoras"].has("caldera_diesel"))
	assert(c47.balanza_doctrinal["dieselpunk"] >= 15.0)

	# Reconversión a Solarpunk
	assert(e47.iniciar_reconversion_industrial(esq_termo47, "ciclo_solarpunk"))
	assert(e47.puestos[esq_termo47]["estado_operativo"] == "RECONVERSION")
	# Producción penalizada al 25% durante reconversión
	assert(is_equal_approx(e47.multiplicador_operativo_puesto(esq_termo47), 0.25))

	# Completar reconversión (Review Focus 4: Puntos dieselpunk eliminados, solarpunk sumados)
	e47.completar_mejora_en_puesto(esq_termo47)
	assert(not e47.puestos[esq_termo47]["mejoras"].has("caldera_diesel"))
	assert(e47.puestos[esq_termo47]["mejoras"].has("ciclo_solarpunk"))
	assert(c47.balanza_doctrinal["dieselpunk"] == 0.0)
	assert(c47.balanza_doctrinal["solarpunk"] >= 15.0)

	# Exclusión doctrinal en iniciar_mejora_practica sin reconversión
	c47.ciencias_teoricas_descubiertas.append("automatizacion_cibernetica")
	assert(not e47.iniciar_mejora_practica(esq_termo47, "control_cibernetico"))

	# Demolición del edificio purga puntos doctrinales e inventario de mejoras
	e47.quitar_puesto(esq_termo47)
	assert(c47.balanza_doctrinal["solarpunk"] == 0.0)
	assert(not c47.mejoras_practicas_instaladas.has("ciclo_solarpunk"))

	print("\n=== TEST 48: Recogida de Carga Masiva y Entrega con Almacén Saturado (Review Focus 1) ===")
	var e48: Node = EconomiaScript.new()
	var c48: Node = CiudadScript.new()
	e48.ciudad = c48
	var esq48 := Vector2i(5, 5)
	e48.registrar_puesto(esq48, "siderurgica", 5, 5, {})
	e48.puestos[esq48]["almacen"]["acero"] = 2500.0
	var carga48: Dictionary = e48.recoger(esq48, 1800.0)
	assert(is_equal_approx(carga48["acero"], 1800.0))
	assert(is_equal_approx(e48.puestos[esq48]["almacen"]["acero"], 700.0))

	# Review Focus 1: Almacén con solo 200 u de espacio libre
	# Stock de acero con límite 1000 y 800 ya ocupados
	c48.almacen["acero"].limite = 1000.0
	c48.almacen["acero"].cantidad = 800.0
	var carga_camion: Dictionary = {"acero": 1800.0}
	var sobrante: Dictionary = e48.entregar(carga_camion)
	assert(is_equal_approx(c48.almacen["acero"].cantidad, 1000.0), "almacen se llena exactamente hasta su tope")
	assert(is_equal_approx(sobrante.get("acero", 0.0), 1600.0), "sobrante retiene 1600 u")
	assert(is_equal_approx(carga_camion.get("acero", 0.0), 1600.0), "diccionario de carga retiene 1600 u")

	print("\n=== TEST 49: Edificio Evolutivo Taller de Transporte ===")
	var e49: Node = EconomiaScript.new()
	var c49: Node = CiudadScript.new()
	e49.ciudad = c49
	c49.era_actual = 2
	var esq_taller := Vector2i(50, 50)
	e49.registrar_puesto(esq_taller, "taller_transporte", 5, 5, {})
	assert(e49.puestos[esq_taller].has("cola_fabricacion"), "debe inicializar cola_fabricacion vacia")
	assert(e49.puestos[esq_taller]["cola_fabricacion"].is_empty(), "cola_fabricacion debe ser un array vacio")
	assert(e49.obtener_nombre_evolutivo_taller(esq_taller) == "Taller de Carretas")
	assert(e49.vehiculos_fabricables_en_taller(esq_taller) == ["carreta_mano"])

	# Simular investigación de tracción animal y granja animal activa
	c49.ciencias_teoricas_descubiertas.append("traccion_animal_engranajes")
	e49.registrar_puesto(Vector2i(20, 20), "granjas_animales", 5, 5, {})
	assert(e49.obtener_nombre_evolutivo_taller(esq_taller) == "Establo de Transporte")
	assert(e49.vehiculos_fabricables_en_taller(esq_taller).has("carro_caballos"))

	# Avanzar a Era 3 y química de hidrocarburos
	c49.era_actual = 3
	c49.ciencias_teoricas_descubiertas.append("quimica_hidrocarburos")
	assert(e49.obtener_nombre_evolutivo_taller(esq_taller) == "Taller de Maquinaria y Transporte")
	assert(e49.vehiculos_fabricables_en_taller(esq_taller).has("camion_diesel"))

	print("\n=== TEST 50: Cola de Fabricación y Despliegue de Vehículos en Puestos ===")
	var e50: Node = EconomiaScript.new()
	var c50: Node = CiudadScript.new()
	e50.ciudad = c50
	c50.era_actual = 2
	var esq_taller50 := Vector2i(50, 50)
	e50.registrar_puesto(esq_taller50, "taller_transporte", 5, 5, {})

	# 1. Deducción atómica de costos al ordenar fabricación
	c50.almacen["madera"].cantidad = 100.0
	c50.almacen["hierro"].cantidad = 50.0
	var costo_carreta: Dictionary = Ajustes.TRANSPORTE_CATALOGO_UNIDADES["carreta_mano"]["costo_fabricacion"]
	assert(e50.ordenar_fabricacion_vehiculo(esq_taller50, "carreta_mano"))
	assert(is_equal_approx(c50.almacen["madera"].cantidad, 100.0 - costo_carreta["madera"]))
	assert(is_equal_approx(c50.almacen["hierro"].cantidad, 50.0 - costo_carreta["hierro"]))
	assert(e50.puestos[esq_taller50]["cola_fabricacion"].size() == 1)
	assert(e50.puestos[esq_taller50]["cola_fabricacion"][0]["tipo"] == "carreta_mano")

	# 2. Avance de progreso con obreros asignados y completitud
	e50.puestos[esq_taller50]["obreros"] = 2
	var tiempo_req: float = float(Ajustes.TRANSPORTE_CATALOGO_UNIDADES["carreta_mano"]["tiempo_fabricacion"])
	e50._tick_taller_transporte(esq_taller50, 5.0)
	assert(is_equal_approx(e50.puestos[esq_taller50]["cola_fabricacion"][0]["progreso"], 10.0))
	e50.completar_fabricacion_en_taller(esq_taller50)
	assert(e50.puestos[esq_taller50]["cola_fabricacion"].is_empty())
	assert(c50.parque_transporte_disponible["carreta_mano"] == 1)

	# 3. Asignación a un puesto de trabajo (aserradero)
	var esq_aser50 := Vector2i(60, 60)
	e50.registrar_puesto(esq_aser50, "aserradero", 5, 5, {})
	assert(e50.asignar_tipo_transporte_puesto(esq_aser50, "carreta_mano"))
	assert(c50.parque_transporte_disponible["carreta_mano"] == 0)
	assert(c50.parque_transporte_asignado["carreta_mano"] == 1)
	assert(e50.puestos[esq_aser50]["tipo_transporte"] == "carreta_mano")

	# 4. Review Focus 5: Demoler el aserradero retorna la carreta al parque disponible
	e50.quitar_puesto(esq_aser50)
	assert(c50.parque_transporte_disponible["carreta_mano"] == 1)
	assert(c50.parque_transporte_asignado["carreta_mano"] == 0)

	# 5. Review Focus 4: Dron Autónomo de Carga opera con tripulación 0 sin restar obreros al censo
	c50.era_actual = 4
	c50.ciencias_teoricas_descubiertas.append("automatizacion_cibernetica")
	c50.almacen["acero"].cantidad = 100.0
	c50.almacen["tierras_raras"].cantidad = 50.0
	c50.almacen["cobre"].cantidad = 60.0
	assert(e50.ordenar_fabricacion_vehiculo(esq_taller50, "dron_carga"))
	e50.completar_fabricacion_en_taller(esq_taller50)
	assert(c50.parque_transporte_disponible["dron_carga"] == 1)

	var esq_mina50 := Vector2i(70, 70)
	e50.registrar_puesto(esq_mina50, "mina", 5, 5, {})
	var obreros_censo_inicial: int = c50.demografia.get("obrero", 0)
	assert(e50.asignar_tipo_transporte_puesto(esq_mina50, "dron_carga"))
	assert(c50.parque_transporte_disponible["dron_carga"] == 0)
	assert(c50.parque_transporte_asignado["dron_carga"] == 1)
	assert(e50.puestos[esq_mina50]["tipo_transporte"] == "dron_carga")
	assert(e50.puestos[esq_mina50]["acarreadores"].size() == 0, "Dron autónomo opera con 0 acarreadores humanos")
	assert(c50.demografia.get("obrero", 0) == obreros_censo_inicial, "Dron autónomo no consume obreros del censo urbano")
	assert(not e50.roles_de(esq_mina50).has("acarreador"), "Puesto con dron no admite rol de acarreador humano")

	# Desasignar el dron volviendo a acarreador_pie retorna el dron a disponibles
	assert(e50.asignar_tipo_transporte_puesto(esq_mina50, "acarreador_pie"))
	assert(c50.parque_transporte_disponible["dron_carga"] == 1)
	assert(c50.parque_transporte_asignado["dron_carga"] == 0)
	assert(e50.puestos[esq_mina50]["tipo_transporte"] == "acarreador_pie")
	assert(e50.roles_de(esq_mina50).has("acarreador"), "Al volver a pie se reactiva el rol de acarreador")

	print("\n=== Las 50 pruebas de Economia pasaron correctamente ===")

