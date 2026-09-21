extends Node

## Pruebas aisladas de Colonos.gd, sin escena visual: un mundo falso, una zona
## falsa y una Ciudad real instanciada fuera del árbol (igual que
## CiudadTest.gd). Corre esta escena y revisa que no lance ningún assert().

const ColonosScript = preload("res://scripts/Colonos.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")


class MundoFalso extends RefCounted:
	var celdas: Dictionary = {}
	var edificio_a_celdas: Dictionary = {}
	var lado := 10

	func obtener_tipo(celda: Vector3i) -> String:
		return celdas.get(celda, "")

	func poner(celda: Vector3i, tipo: String) -> void:
		celdas[celda] = tipo

	func altura_en(x: int, z: int) -> int:
		return 0 if x >= 0 and x < lado and z >= 0 and z < lado else -1


## Cuadrado [0, lado) x [0, lado) de zona de influencia.
class ZonaFalsa extends RefCounted:
	var influencia_min := Vector2i(0, 0)
	var influencia_max := Vector2i(9, 9)

	func dentro_de_influencia(celda: Vector2i) -> bool:
		return celda.x >= influencia_min.x and celda.x <= influencia_max.x and celda.y >= influencia_min.y and celda.y <= influencia_max.y


func _ready() -> void:
	ejecutar_pruebas()


func _mundo_llano(lado: int = 10, largo: int = -1) -> MundoFalso:
	var mundo := MundoFalso.new()
	mundo.lado = lado
	var z_max: int = lado if largo < 0 else largo
	for x in range(lado):
		for z in range(z_max):
			mundo.poner(Vector3i(x, 0, z), "tierra")
	return mundo


func _nuevo(mundo: MundoFalso, ciudad: Node) -> Node:
	var colonos: Node = ColonosScript.new()
	colonos.ciudad = ciudad
	colonos.zona = ZonaFalsa.new()
	colonos.mundo = mundo
	colonos._rng.seed = 12345
	return colonos


func _contar(colonos: Node, tipo: String) -> int:
	var total := 0
	for c in colonos.colonos.values():
		if c["tipo"] == tipo:
			total += 1
	return total


func ejecutar_pruebas() -> void:
	print("=== TEST 1: reconciliar() crea y retira colonos hasta igualar demografia ===")
	var ciudad1: Node = CiudadScript.new()
	var colonos1: Node = _nuevo(_mundo_llano(), ciudad1)
	var creados := [0]
	var retirados := [0]
	colonos1.colono_creado.connect(func(_id: int) -> void: creados[0] += 1)
	colonos1.colono_retirado.connect(func(_id: int) -> void: retirados[0] += 1)
	ciudad1.demografia["obrero"] = 3
	ciudad1.demografia["militar"] = 1
	colonos1.reconciliar()
	assert(colonos1.colonos.size() == 4)
	assert(_contar(colonos1, "obrero") == 3 and _contar(colonos1, "militar") == 1)
	assert(creados[0] == 4)
	ciudad1.demografia["obrero"] = 1
	colonos1.reconciliar()
	assert(colonos1.colonos.size() == 2)
	assert(retirados[0] == 2)
	for id_ocupante in colonos1.ocupadas.values():
		assert(colonos1.colonos.has(id_ocupante), "ninguna celda queda ocupada por un colono retirado")
	assert(colonos1.ocupadas.size() == 2)

	print("\n=== TEST 2: El hogar es el edificio con menor ocupación relativa ===")
	var ciudad2: Node = CiudadScript.new()
	ciudad2.registrar_edificio_residencial(1, [2, 2])
	ciudad2.registrar_edificio_residencial(2, [2, 2])
	var colonos2: Node = _nuevo(_mundo_llano(), ciudad2)
	ciudad2.demografia["obrero"] = 3
	colonos2.reconciliar()
	var por_hogar := {1: 0, 2: 0}
	for c in colonos2.colonos.values():
		por_hogar[c["hogar"]] += 1
	print("Colonos por hogar: ", por_hogar)
	assert(por_hogar[1] == 2 and por_hogar[2] == 1, "se reparten entre los dos hogares; el empate lo gana el id menor")

	print("\n=== TEST 3: Un hogar demolido reasigna a sus colonos ===")
	ciudad2.retirar_edificio_residencial(1)
	colonos2.reconciliar()
	for c in colonos2.colonos.values():
		assert(c["hogar"] == 2, "todos pasan al único hogar que queda")

	print("\n=== TEST 4: Sin hogares, el colono queda sin hogar (-1) pero existe ===")
	var ciudad4: Node = CiudadScript.new()
	var colonos4: Node = _nuevo(_mundo_llano(), ciudad4)
	ciudad4.demografia["desempleado"] = 1
	colonos4.reconciliar()
	assert(colonos4.colonos.size() == 1)
	for c in colonos4.colonos.values():
		assert(c["hogar"] == -1)

	print("\n=== TEST 5: Un colono recorre su ruta celda a celda ===")
	var colonos5: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id5: int = colonos5.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c5: Dictionary = colonos5.colonos[id5]
	var ruta5: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c5["ruta"] = ruta5
	colonos5.avanzar(0.5)  # 0.5 s x 2.5 celdas/s = 1.25: completa el primer paso
	assert(c5["celda"] == Vector3i(2, 1, 1))
	assert(colonos5.ocupadas.has(Vector3i(2, 1, 1)) and not colonos5.ocupadas.has(Vector3i(1, 1, 1)), "libera la celda que deja")
	colonos5.avanzar(0.5)
	assert(c5["celda"] == Vector3i(3, 1, 1))
	assert(c5["ruta"].is_empty())
	assert(colonos5.ocupadas.size() == 1 and colonos5.ocupadas.has(Vector3i(3, 1, 1)))
	assert(c5["espera"] > 0.0, "al llegar espera unos segundos antes de elegir otro destino")

	print("\n=== TEST 6: Deambular: siempre pisa celdas transitables y se mueve ===")
	var mundo6 := _mundo_llano()
	for z in range(0, 10):  # un muro con un hueco que estorba el paso
		if z != 5:
			mundo6.poner(Vector3i(5, 1, z), "pared")
			mundo6.poner(Vector3i(5, 2, z), "pared")
	var colonos6: Node = _nuevo(mundo6, CiudadScript.new())
	var id6: int = colonos6.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c6: Dictionary = colonos6.colonos[id6]
	var celdas_vistas := {}
	for i in range(400):
		colonos6.avanzar(0.1)
		assert(colonos6._buscador.es_transitable(c6["celda"]), "nunca pisa una celda no transitable")
		celdas_vistas[c6["celda"]] = true
	print("Celdas distintas recorridas: ", celdas_vistas.size())
	assert(celdas_vistas.size() > 5, "el colono efectivamente deambula")

	print("\n=== TEST 7: Un colono con hogar entra a su casa ===")
	var ciudad7: Node = CiudadScript.new()
	ciudad7.registrar_edificio_residencial(1, [2, 2])
	var mundo7 := _mundo_llano()
	# Una casita de 3x3: paredes en el borde y una puerta en (6, 1, 5).
	for x in range(6, 9):
		for z in range(5, 8):
			var borde: bool = x == 6 or x == 8 or z == 5 or z == 7
			if borde:
				mundo7.poner(Vector3i(x, 1, z), "pared")
				mundo7.poner(Vector3i(x, 2, z), "pared")
	mundo7.poner(Vector3i(6, 1, 6), "puerta_inferior")
	mundo7.poner(Vector3i(6, 2, 6), "puerta_superior")
	var celdas_casa: Array[Vector3i] = []
	for x in range(6, 9):
		for z in range(5, 8):
			celdas_casa.append(Vector3i(x, 1, z))
			celdas_casa.append(Vector3i(x, 2, z))
	mundo7.edificio_a_celdas[1] = celdas_casa
	var colonos7: Node = _nuevo(mundo7, ciudad7)
	var id7: int = colonos7.agregar_colono("obrero", Vector3i(2, 1, 6), 1)
	var c7: Dictionary = colonos7.colonos[id7]
	var entro := false
	for i in range(3000):
		colonos7.avanzar(0.1)
		if c7["celda"] == Vector3i(7, 1, 6):  # el único interior de la casa
			entro = true
			break
	assert(entro, "con hogar, tarde o temprano entra a su casa por la puerta")

	print("\n=== TEST 8: Retirar a un colono a medio paso no deja celdas ocupadas ===")
	var colonos8: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id8: int = colonos8.agregar_colono("obrero", Vector3i(1, 1, 1))
	var ruta8: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	colonos8.colonos[id8]["ruta"] = ruta8
	colonos8.avanzar(0.1)  # progreso 0.25: a medio paso, con la celda destino reservada
	assert(colonos8.colonos[id8]["moviendo"] and colonos8.ocupadas.size() == 2)
	colonos8._retirar(id8)
	assert(colonos8.ocupadas.is_empty(), "no queda ni la celda que deja ni la reservada")

	print("\n=== TEST 9: Dos colonos nunca comparten celda; el bloqueado rodea al otro ===")
	var colonos9: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id_a: int = colonos9.agregar_colono("obrero", Vector3i(1, 1, 1))
	var id_b: int = colonos9.agregar_colono("obrero", Vector3i(2, 1, 1))
	var a9: Dictionary = colonos9.colonos[id_a]
	var b9: Dictionary = colonos9.colonos[id_b]
	b9["espera"] = 999.0  # B se queda quieto estorbando
	var ruta9: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	a9["ruta"] = ruta9
	var llego9 := false
	for i in range(80):
		colonos9.avanzar(0.1)
		assert(a9["celda"] != b9["celda"], "nunca comparten celda")
		assert(colonos9.ocupadas.size() == 2 or colonos9.ocupadas.size() == 3, "solo su celda y, a lo sumo, la reservada")
		if a9["celda"] == Vector3i(3, 1, 1):
			llego9 = true  # al llegar se queda esperando y luego deambularía: se comprueba aquí y se corta
			break
	assert(llego9, "tras esperar, A rodea a B y llega a su destino")

	print("\n=== TEST 10: En un pasillo de una celda, el bloqueado abandona su destino ===")
	var colonos10: Node = _nuevo(_mundo_llano(10, 1), CiudadScript.new())  # una sola fila
	var id_a10: int = colonos10.agregar_colono("obrero", Vector3i(1, 1, 0))
	var id_b10: int = colonos10.agregar_colono("obrero", Vector3i(2, 1, 0))
	var a10: Dictionary = colonos10.colonos[id_a10]
	colonos10.colonos[id_b10]["espera"] = 999.0
	var ruta10: Array[Vector3i] = [Vector3i(2, 1, 0), Vector3i(3, 1, 0)]
	a10["ruta"] = ruta10
	for i in range(6):  # 0.6 s > ESPERA_BLOQUEO
		colonos10.avanzar(0.1)
	assert(a10["ruta"].is_empty() and a10["espera"] > 0.0, "sin forma de rodear, abandona el destino")
	assert(a10["celda"] == Vector3i(1, 1, 0))

	print("\n=== TEST 11: Esquivan la celda del avatar, y la de adelante si se mueve ===")
	var colonos11: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id11: int = colonos11.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c11: Dictionary = colonos11.colonos[id11]
	var ruta11: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c11["ruta"] = ruta11
	colonos11.actualizar_avatar(Vector3i(2, 1, 1), Vector3.ZERO)
	assert(colonos11.celdas_avatar.size() == 1, "quieto: solo su celda")
	var llego11 := false
	for i in range(80):
		colonos11.avanzar(0.1)
		assert(c11["celda"] != Vector3i(2, 1, 1), "nunca pisa la celda del avatar")
		if c11["celda"] == Vector3i(3, 1, 1):
			llego11 = true
			break
	assert(llego11, "rodea al avatar y llega")
	colonos11.actualizar_avatar(Vector3i(5, 1, 5), Vector3(5, 0, 0))
	assert(colonos11.celdas_avatar.has(Vector3i(5, 1, 5)) and colonos11.celdas_avatar.has(Vector3i(6, 1, 5)), "en movimiento: su celda y la de adelante")
	colonos11.actualizar_avatar(Vector3i(5, 1, 5), Vector3(0, 0, -5))
	assert(colonos11.celdas_avatar.has(Vector3i(5, 1, 4)), "el sentido lo da la velocidad")

	print("\n=== TEST 12: No huyen del avatar: un avatar junto a la ruta no la cambia ===")
	var colonos12: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id12: int = colonos12.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c12: Dictionary = colonos12.colonos[id12]
	var ruta12: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c12["ruta"] = ruta12
	colonos12.actualizar_avatar(Vector3i(2, 1, 2), Vector3.ZERO)  # pegado a la ruta, no sobre ella
	colonos12.avanzar(0.5)
	colonos12.avanzar(0.5)
	assert(c12["celda"] == Vector3i(3, 1, 1), "sigue su ruta directa, sin desviarse")

	print("\n=== TEST 13: Si el mundo cambia bajo la ruta, recalcula ===")
	var mundo13 := _mundo_llano()
	var colonos13: Node = _nuevo(mundo13, CiudadScript.new())
	var id13: int = colonos13.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c13: Dictionary = colonos13.colonos[id13]
	var ruta13: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c13["ruta"] = ruta13
	mundo13.poner(Vector3i(2, 1, 1), "pared")
	mundo13.poner(Vector3i(2, 2, 1), "pared")
	colonos13.avanzar(0.1)
	assert(c13["celda"] == Vector3i(1, 1, 1), "todavía no se movió")
	assert(not c13["ruta"].is_empty() and not c13["ruta"].has(Vector3i(2, 1, 1)), "la nueva ruta evita la celda que se volvió sólida")
	assert(c13["ruta"].back() == Vector3i(3, 1, 1), "al mismo destino")

	print("\n=== Las 13 pruebas de Colonos pasaron correctamente ===")
