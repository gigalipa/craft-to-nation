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

	print("\n=== Las 8 pruebas de Colonos pasaron correctamente ===")
