extends Node

## Pruebas aisladas de Colonos.gd, sin escena visual: un mundo falso, una zona
## falsa y una Ciudad real instanciada fuera del árbol (igual que
## CiudadTest.gd). Corre esta escena y revisa que no lance ningún assert().

const ColonosScript = preload("res://scripts/Colonos.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")
const EconomiaScript = preload("res://scripts/Economia.gd")


class MundoFalso extends RefCounted:
	var celdas: Dictionary = {}
	var edificio_a_celdas: Dictionary = {}
	var lado := 10
	var ids: Dictionary = {}  # Vector3i -> int: la obra de cada fantasma
	var volumenes: Dictionary = {}  # int -> {"min": Vector3i, "max": Vector3i}
	var permisos: Dictionary = {}  # int -> Dictionary (entidad -> true)

	func id_de_edificio(celda: Vector3i) -> int:
		return ids.get(celda, -1)

	func poner_fantasma(celda: Vector3i, id_obra: int) -> void:
		celdas[celda] = "fantasma"
		ids[celda] = id_obra

	func celda_en_volumen(id: int, celda: Vector3i) -> bool:
		var v: Dictionary = volumenes.get(id, {})
		if v.is_empty():
			return false
		return celda.x >= v["min"].x and celda.x <= v["max"].x \
			and celda.y >= v["min"].y and celda.y <= v["max"].y \
			and celda.z >= v["min"].z and celda.z <= v["max"].z

	func otorgar_permiso_salida(id_obra: int, entidad) -> void:
		if not permisos.has(id_obra):
			permisos[id_obra] = {}
		permisos[id_obra][entidad] = true

	func revocar_permiso_salida(id_obra: int, entidad) -> void:
		if permisos.has(id_obra):
			permisos[id_obra].erase(entidad)
			if permisos[id_obra].is_empty():
				permisos.erase(id_obra)

	func obtener_tipo(celda: Vector3i) -> String:
		return celdas.get(celda, "")

	func poner(celda: Vector3i, tipo: String) -> void:
		celdas[celda] = tipo

	## Altura de la columna más alta con bloque (refleja lo colocado con poner()).
	func altura_en(x: int, z: int) -> int:
		if x < 0 or x >= lado or z < 0 or z >= lado:
			return -1
		for y in range(20, -1, -1):
			if celdas.get(Vector3i(x, y, z), "") != "":
				return y
		return -1


## Cuadrado [0, lado) x [0, lado) de zona de influencia.
class ZonaFalsa extends RefCounted:
	var influencia_min := Vector2i(0, 0)
	var influencia_max := Vector2i(9, 9)

	func dentro_de_influencia(celda: Vector2i) -> bool:
		return celda.x >= influencia_min.x and celda.x <= influencia_max.x and celda.y >= influencia_min.y and celda.y <= influencia_max.y

	## Núcleo urbano falso: un bloque de 2x2 en (7,7)-(8,8).
	func huella_del_nucleo() -> Array:
		return [Vector2i(7, 7), Vector2i(8, 7), Vector2i(7, 8), Vector2i(8, 8)]


## Buscador que anota el tope de nodos ("max_nodos") con que se le pide cada ruta.
class BuscadorEspia extends "res://scripts/BuscadorRutas.gd":
	var topes: Array = []

	func buscar_ruta(origen: Vector3i, destino: Vector3i, opciones: Dictionary = {}) -> Array[Vector3i]:
		topes.append(opciones.get("max_nodos", -1))
		return super.buscar_ruta(origen, destino, opciones)

	func buscar_salida(origen: Vector3i, esta_dentro: Callable, opciones: Dictionary = {}) -> Array[Vector3i]:
		topes.append(opciones.get("max_nodos", -1))
		return super.buscar_salida(origen, esta_dentro, opciones)


## Obras falsas: ofrece una tarea fija y anota cada llamada a trabajar().
class ObrasFalsa extends RefCounted:
	var tarea: Dictionary = {}
	var huella: Array = []
	var resultado: Dictionary = {"estado": "avanzo", "espera": 0.0}
	var trabajos: Array = []
	var vetos: Array = []

	func siguiente_tarea(_desde: Vector3i, _id_colono: int = -1) -> Dictionary:
		return tarea

	func huella_de(_id: int) -> Array:
		return huella

	func trabajar(id: int, tipo: String) -> Dictionary:
		trabajos.append([id, tipo])
		return resultado

	func vetar(id: int, id_colono: int) -> void:
		vetos.append([id, id_colono])


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


## Colonos con una Economia real (ciudad inyectada) y un maderero de 2x2 en
## (2, 2) con tasa 3 madera/h; mundo llano de 10x10 y el núcleo en (7..8, 7..8).
func _nuevo_con_puesto(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(Vector2i(2, 2), "maderero", 2, 2, {"madera": 3.0})
	var colonos: Node = _nuevo(_mundo_llano(), ciudad)
	colonos.economia = economia
	return colonos


## Colonos con una siderúrgica de 2x2 en (2, 2): entrada al norte (2, 1), salida al sur (3, 4);
## mundo llano de 10x10 y el núcleo en (7..8, 7..8). Sin plantilla (suelo desconocido): los colonos esperan fuera.
func _nuevo_con_siderurgica(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(Vector2i(2, 2), "siderurgica", 2, 2, {}, {}, Vector2i(2, 1), economia.SIN_DEPOSITO, economia.SIN_SUELO, Vector2i(3, 4))
	var colonos: Node = _nuevo(_mundo_llano(), ciudad)
	colonos.economia = economia
	return colonos


## Colonos con una escuela técnica de 2x2 en (2, 2) (cupo 4, el de la cohorte); mundo llano de 10x10.
func _nuevo_con_escuela(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(Vector2i(2, 2), "escuela_tecnica", 2, 2, {})
	var colonos: Node = _nuevo(_mundo_llano(), ciudad)
	colonos.economia = economia
	return colonos


func _nuevo_con_escuela_especialistas(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(Vector2i(2, 2), "escuela_especialistas", 2, 2, {})
	var colonos: Node = _nuevo(_mundo_llano(), ciudad)
	colonos.economia = economia
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

	print("\n=== TEST 14: Un colono dentro de un sólido se reubica sobre su columna ===")
	var mundo_reub := _mundo_llano()
	var colonos_reub: Node = _nuevo(mundo_reub, CiudadScript.new())
	var id_reub: int = colonos_reub.agregar_colono("obrero", Vector3i(4, 1, 4))
	var c_reub: Dictionary = colonos_reub.colonos[id_reub]
	mundo_reub.poner(Vector3i(4, 1, 4), "pared")
	mundo_reub.poner(Vector3i(4, 2, 4), "pared")
	colonos_reub.avanzar(0.1)
	assert(c_reub["celda"] == Vector3i(4, 3, 4), "se reubica sobre la pared, en lo alto de su columna")
	assert(colonos_reub.ocupadas.get(Vector3i(4, 3, 4), -1) == id_reub, "ocupa la celda nueva")
	assert(not colonos_reub.ocupadas.has(Vector3i(4, 1, 4)), "libera la celda sólida")
	assert(colonos_reub.ocupadas.size() == 1, "solo queda su celda en ocupadas")
	for i in range(200):
		colonos_reub.avanzar(0.1)
		assert(colonos_reub._buscador.es_transitable(c_reub["celda"]), "nunca queda parado en una celda no transitable")

	# Si la celda de reubicación la ocupa otro colono, espera sin moverse.
	var mundo_reub2 := _mundo_llano()
	var colonos_reub2: Node = _nuevo(mundo_reub2, CiudadScript.new())
	var id_a_reub: int = colonos_reub2.agregar_colono("obrero", Vector3i(7, 1, 7))
	var id_b_reub: int = colonos_reub2.agregar_colono("obrero", Vector3i(7, 3, 7))
	colonos_reub2.colonos[id_b_reub]["espera"] = 1000.0
	mundo_reub2.poner(Vector3i(7, 1, 7), "pared")
	mundo_reub2.poner(Vector3i(7, 2, 7), "pared")
	colonos_reub2.avanzar(0.1)
	var a_reub: Dictionary = colonos_reub2.colonos[id_a_reub]
	assert(a_reub["celda"] == Vector3i(7, 1, 7), "no se reubica sobre otro colono")
	assert(a_reub["espera"] > 0.0, "espera y reintenta")
	assert(colonos_reub2.ocupadas[Vector3i(7, 1, 7)] == id_a_reub and colonos_reub2.ocupadas[Vector3i(7, 3, 7)] == id_b_reub, "ocupadas sigue consistente")

	print("\n=== TEST 15: Un colono dentro de una obra recibe permiso, sale y no puede volver a entrar ===")
	var mundo_evac := _mundo_llano()
	for x in range(3, 6):  # cubo fantasma macizo de 3x3x2 (obra 7)
		for z in range(3, 6):
			mundo_evac.poner_fantasma(Vector3i(x, 1, z), 7)
			mundo_evac.poner_fantasma(Vector3i(x, 2, z), 7)
	mundo_evac.volumenes[7] = {"min": Vector3i(3, 1, 3), "max": Vector3i(5, 2, 5)}
	var colonos_evac: Node = _nuevo(mundo_evac, CiudadScript.new())
	var id_evac: int = colonos_evac.agregar_colono("obrero", Vector3i(4, 1, 4))  # en el centro del cubo
	var c_evac: Dictionary = colonos_evac.colonos[id_evac]
	colonos_evac._on_obra_a_fantasma(7)
	assert(c_evac["evacuando"] == 7 and mundo_evac.permisos[7].has(id_evac), "recibe el permiso y empieza a evacuar")
	var salio := false
	for i in range(100):
		colonos_evac.avanzar(0.1)
		if c_evac["evacuando"] == -1:
			salio = true
			break
	assert(salio, "sale del volumen de la obra")
	assert(not mundo_evac.celda_en_volumen(7, c_evac["celda"]), "está fuera")
	assert(not mundo_evac.permisos.has(7), "el permiso se revocó al salir")
	for i in range(600):  # 60 s deambulando: los fantasmas ya son sólidos para él
		colonos_evac.avanzar(0.1)
		assert(not mundo_evac.celda_en_volumen(7, c_evac["celda"]), "no vuelve a entrar")

	print("\n=== TEST 16: Un colono fuera de la obra no recibe permiso ni cambia lo que hace ===")
	var mundo_fuera := _mundo_llano()
	mundo_fuera.poner_fantasma(Vector3i(4, 1, 4), 9)
	mundo_fuera.volumenes[9] = {"min": Vector3i(4, 1, 4), "max": Vector3i(4, 1, 4)}
	var colonos_fuera: Node = _nuevo(mundo_fuera, CiudadScript.new())
	var id_fuera: int = colonos_fuera.agregar_colono("obrero", Vector3i(1, 1, 1))
	colonos_fuera._on_obra_a_fantasma(9)
	assert(colonos_fuera.colonos[id_fuera]["evacuando"] == -1 and not mundo_fuera.permisos.has(9))

	print("\n=== TEST 17: Un colono atrapado en un fantasma sin permiso recibe permiso y sale ===")
	var mundo_atr := _mundo_llano()
	var colonos_atr: Node = _nuevo(mundo_atr, CiudadScript.new())
	var id_atr: int = colonos_atr.agregar_colono("obrero", Vector3i(4, 1, 4))
	var c_atr: Dictionary = colonos_atr.colonos[id_atr]
	# Su celda pasa a fantasma de una obra SIN emitir obra_a_fantasma (a medio paso,
	# o una puerta que revierte a fantasma al deconstruir): no tiene permiso.
	mundo_atr.poner_fantasma(Vector3i(4, 1, 4), 7)
	mundo_atr.poner_fantasma(Vector3i(4, 2, 4), 7)
	mundo_atr.volumenes[7] = {"min": Vector3i(3, 1, 3), "max": Vector3i(5, 2, 5)}
	colonos_atr.avanzar(0.1)
	assert(c_atr["evacuando"] == 7 and mundo_atr.permisos[7].has(id_atr), "al elegir destino recibe permiso y evacúa")
	for i in range(200):
		colonos_atr.avanzar(0.1)
		if c_atr["evacuando"] == -1:
			break
	assert(not mundo_atr.celda_en_volumen(7, c_atr["celda"]), "sale del volumen atrapado")
	assert(not mundo_atr.permisos.has(7), "el permiso se revocó al salir")

	print("\n=== TEST 18: contratar() convierte a un desempleado en obrero asignado al puesto ===")
	var ciudad18: Node = CiudadScript.new()
	var colonos18: Node = _nuevo_con_puesto(ciudad18)
	ciudad18.demografia["desempleado"] = 2
	colonos18.reconciliar()
	assert(colonos18.contratar(Vector2i(2, 2), "recolector"))
	assert(ciudad18.demografia["desempleado"] == 1 and ciudad18.demografia["obrero"] == 1)
	assert(_contar(colonos18, "obrero") == 1 and _contar(colonos18, "desempleado") == 1)
	var trabajador18: Dictionary = {}
	for c in colonos18.colonos.values():
		if c["tipo"] == "obrero":
			trabajador18 = c
	assert(trabajador18["trabajo"] == {"puesto": Vector2i(2, 2), "rol": "recolector"})
	assert(colonos18.economia.trabajadores_de(Vector2i(2, 2))["recolectores"] == 1)
	colonos18.reconciliar()  # la demografía y los colonos siguen coincidiendo: no crea ni retira
	assert(colonos18.colonos.size() == 2)
	assert(not colonos18.contratar(Vector2i(99, 99), "recolector"), "puesto inexistente")
	assert(colonos18.contratar(Vector2i(2, 2), "acarreador"))
	assert(not colonos18.contratar(Vector2i(2, 2), "acarreador"), "ya no quedan desempleados")
	assert(ciudad18.demografia["obrero"] == 2 and ciudad18.demografia["desempleado"] == 0)

	print("\n=== TEST 19: despedir() devuelve al último a desempleado y libera el cupo ===")
	assert(colonos18.despedir(Vector2i(2, 2), "acarreador"))
	assert(ciudad18.demografia["desempleado"] == 1 and ciudad18.demografia["obrero"] == 1)
	assert(colonos18.economia.trabajadores_de(Vector2i(2, 2))["acarreadores"] == 0)
	assert(not colonos18.despedir(Vector2i(2, 2), "acarreador"), "no queda ninguno")
	var despedido19: int = -1
	for c in colonos18.colonos.values():
		if c["tipo"] == "desempleado":
			despedido19 = c["id"]
	assert(colonos18.colonos[despedido19]["trabajo"].is_empty())

	print("\n=== TEST 20: un recolector camina a su puesto, queda presente y produce ===")
	var ciudad20: Node = CiudadScript.new()
	var colonos20: Node = _nuevo_con_puesto(ciudad20)
	var id20: int = colonos20.agregar_colono("desempleado", Vector3i(6, 1, 1))
	ciudad20.demografia["desempleado"] = 1
	assert(colonos20.contratar(Vector2i(2, 2), "recolector"))
	var c20: Dictionary = colonos20.colonos[id20]
	var llego20 := false
	for i in range(400):
		colonos20.avanzar(0.1)
		if colonos20.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 1:
			llego20 = true
			break
	assert(llego20, "llega junto al puesto y se marca presente")
	assert(absi(c20["celda"].x - 2) <= 2 and absi(c20["celda"].z - 2) <= 2, "está junto a la huella 2x2 de (2,2)")
	assert(not (c20["celda"].x in [2, 3] and c20["celda"].z in [2, 3]), "no está dentro de la huella")
	colonos20.economia.simular_hora()
	assert(is_equal_approx(colonos20.economia.almacen_local(Vector2i(2, 2))["madera"], 3.0))
	for i in range(100):  # se queda ahí: no deambula
		colonos20.avanzar(0.1)
	assert(colonos20.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 1, "sigue en su puesto")

	print("\n=== TEST 21: un acarreador lleva la carga al núcleo y la entrega ===")
	var ciudad21: Node = CiudadScript.new()
	var colonos21: Node = _nuevo_con_puesto(ciudad21)
	var madera_inicial: float = ciudad21.almacen["madera"].cantidad
	var carga21: float = colonos21.economia.CAPACIDAD_CARGA
	colonos21.economia.puestos[Vector2i(2, 2)]["almacen"]["madera"] = carga21 + 10.0  # almacén local con carga de sobra
	var id21: int = colonos21.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad21.demografia["desempleado"] = 1
	assert(colonos21.contratar(Vector2i(2, 2), "acarreador"))
	var entregado21 := false
	for i in range(1500):  # hasta 150 s de juego
		colonos21.avanzar(0.1)
		if ciudad21.almacen["madera"].cantidad > madera_inicial:
			entregado21 = true
			break
	assert(entregado21, "el acarreador entrega en el núcleo")
	assert(is_equal_approx(ciudad21.almacen["madera"].cantidad, madera_inicial + carga21), "una carga completa")
	assert(is_equal_approx(colonos21.economia.almacen_local(Vector2i(2, 2))["madera"], 10.0), "quedan 10 en el puesto")
	assert(colonos21.colonos[id21]["carga"].is_empty(), "ya no lleva nada")

	print("\n=== TEST 22: retirar a un trabajador (o quitar su puesto) lo libera ===")
	var ciudad22: Node = CiudadScript.new()
	var colonos22: Node = _nuevo_con_puesto(ciudad22)
	ciudad22.demografia["desempleado"] = 2
	colonos22.reconciliar()
	colonos22.contratar(Vector2i(2, 2), "recolector")
	colonos22.contratar(Vector2i(2, 2), "acarreador")
	assert(colonos22.economia.cupo_libre(Vector2i(2, 2)) == 3)
	var obrero22: int = -1
	for c in colonos22.colonos.values():
		if c["trabajo"].get("rol", "") == "acarreador":
			obrero22 = c["id"]
	colonos22._retirar(obrero22)
	assert(colonos22.economia.cupo_libre(Vector2i(2, 2)) == 4, "retirarlo libera su cupo")
	colonos22.economia.quitar_puesto(Vector2i(2, 2))
	for c in colonos22.colonos.values():
		assert(c["trabajo"].is_empty() and c["tipo"] == "desempleado", "al quitarse el puesto, vuelve a desempleado")
	# El acarreador retirado con _retirar() no se descontó de la demografía (solo se
	# probó la liberación); el recolector devuelto pasó de obrero a desempleado.
	assert(ciudad22.demografia["obrero"] == 1 and ciudad22.demografia["desempleado"] == 1)

	print("\n=== TEST 23: la evacuación de una obra tiene prioridad sobre el trabajo ===")
	var ciudad23: Node = CiudadScript.new()
	var mundo23 := _mundo_llano()
	for x in range(3, 6):
		for z in range(3, 6):
			mundo23.poner_fantasma(Vector3i(x, 1, z), 7)
			mundo23.poner_fantasma(Vector3i(x, 2, z), 7)
	mundo23.volumenes[7] = {"min": Vector3i(3, 1, 3), "max": Vector3i(5, 2, 5)}
	var economia23: Node = EconomiaScript.new()
	economia23.ciudad = ciudad23
	economia23.registrar_puesto(Vector2i(0, 0), "maderero", 2, 2, {"madera": 3.0})
	var colonos23: Node = _nuevo(mundo23, ciudad23)
	colonos23.economia = economia23
	var id23: int = colonos23.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad23.demografia["desempleado"] = 1
	assert(colonos23.contratar(Vector2i(0, 0), "recolector"))
	colonos23._on_obra_a_fantasma(7)
	assert(colonos23.colonos[id23]["evacuando"] == 7)
	var salio23 := false
	for i in range(100):
		colonos23.avanzar(0.1)
		if colonos23.colonos[id23]["evacuando"] == -1:
			salio23 = true
			break
	assert(salio23 and not mundo23.celda_en_volumen(7, colonos23.colonos[id23]["celda"]), "sale de la obra aunque tenga trabajo")

	print("\n=== TEST 24: un trabajador dentro de un sólido se reubica y luego llega a su puesto ===")
	var ciudad24: Node = CiudadScript.new()
	var colonos24: Node = _nuevo_con_puesto(ciudad24)
	var id24: int = colonos24.agregar_colono("desempleado", Vector3i(6, 1, 6))
	ciudad24.demografia["desempleado"] = 1
	assert(colonos24.contratar(Vector2i(2, 2), "recolector"))
	var c24: Dictionary = colonos24.colonos[id24]
	# Como en la prueba 14: su celda pasa a ser sólida sin ninguna señal de obra.
	colonos24.mundo.poner(Vector3i(6, 1, 6), "pared")
	colonos24.mundo.poner(Vector3i(6, 2, 6), "pared")
	colonos24.avanzar(0.1)
	assert(c24["celda"] == Vector3i(6, 3, 6), "se reubica sobre la pared, en lo alto de su columna")
	var llego24 := false
	for i in range(600):
		colonos24.avanzar(0.1)
		if colonos24.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 1:
			llego24 = true
			break
	assert(llego24, "tras reubicarse llega a su puesto y se marca presente")

	print("\n=== TEST 25: un puesto inalcanzable se reintenta con retroceso exponencial ===")
	var ciudad25: Node = CiudadScript.new()
	var colonos25: Node = _nuevo_con_puesto(ciudad25)
	# Anillo cerrado de columnas "pared" de 2 de alto alrededor del puesto (2,2): ninguna
	# celda junto a su huella es alcanzable desde fuera.
	for i in range(6):
		for borde in [Vector2i(i, 0), Vector2i(i, 5), Vector2i(0, i), Vector2i(5, i)]:
			colonos25.mundo.poner(Vector3i(borde.x, 1, borde.y), "pared")
			colonos25.mundo.poner(Vector3i(borde.x, 2, borde.y), "pared")
	var id25: int = colonos25.agregar_colono("desempleado", Vector3i(7, 1, 7))
	ciudad25.demografia["desempleado"] = 1
	assert(colonos25.contratar(Vector2i(2, 2), "recolector"))
	var c25: Dictionary = colonos25.colonos[id25]
	assert(c25["fallos_servicio"] == 0, "sin fallos al contratar")
	var esperas25: Array = []
	var fallos_vistos25: int = 0
	for i in range(250):  # 25 s de juego: fallos a ~0, 1, 3, 7 y 15 s
		colonos25.avanzar(0.1)
		if c25["fallos_servicio"] != fallos_vistos25:
			fallos_vistos25 = c25["fallos_servicio"]
			esperas25.append(c25["espera"])
	assert(c25["fallos_servicio"] >= 3, "acumula fallos (%d)" % c25["fallos_servicio"])
	assert(esperas25.size() >= 3 and esperas25[0] == 1.0 and esperas25[1] == 2.0 and esperas25[2] == 4.0, "espera 1, 2, 4... (%s)" % [esperas25])
	for i in range(1, esperas25.size()):
		assert(esperas25[i] >= esperas25[i - 1] and esperas25[i] <= 8.0, "espera no decreciente y con tope de 8 s")
	assert(colonos25.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 0, "nunca llega a su puesto")

	print("\n=== TEST bono de velocidad: un colono sobre una vía avanza 1.35x más rápido ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var colonos_bono: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id_bono: int = colonos_bono.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c_bono: Dictionary = colonos_bono.colonos[id_bono]
	c_bono["ruta"] = [Vector3i(2, 1, 1)]
	colonos_bono.avanzar(0.2)  # 0.2 s x 2.5 celdas/s x bono 1.0 = 0.5 progreso, sin vía
	assert(is_equal_approx(c_bono["progreso"], 0.5), "sin vía: progreso 0.5")

	var colonos_bono2: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id_bono2: int = colonos_bono2.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c_bono2: Dictionary = colonos_bono2.colonos[id_bono2]
	c_bono2["ruta"] = [Vector3i(2, 1, 1)]
	Vias.agregar([Vector3i(1, 0, 1)], "tierra_pisada")  # soporte bajo la celda de partida (1,1,1)
	colonos_bono2.avanzar(0.2)  # 0.2 s x 2.5 celdas/s x bono 1.35 = 0.675 progreso, con vía
	assert(is_equal_approx(c_bono2["progreso"], 0.675), "con vía: progreso 0.675 (1.35x el caso sin vía)")
	Vias.celdas.clear()
	Vias._columnas.clear()

	print("\n=== TEST 27: con celda de servicio, los recolectores se reparten por la zona de servicio de la puerta ===")
	var ciudad27: Node = CiudadScript.new()
	var economia27: Node = EconomiaScript.new()
	economia27.ciudad = ciudad27
	# Maderero 2x2 en (2,2) con celda de servicio LEJOS del anillo de la huella, en (7,3): zona x 5..9, z 1..5.
	economia27.registrar_puesto(Vector2i(2, 2), "maderero", 2, 2, {"madera": 3.0}, {}, Vector2i(7, 3))
	var colonos27: Node = _nuevo(_mundo_llano(), ciudad27)
	colonos27.economia = economia27
	var ids27: Array[int] = []
	for celda27 in [Vector3i(0, 1, 7), Vector3i(0, 1, 8), Vector3i(0, 1, 9)]:
		ids27.append(colonos27.agregar_colono("desempleado", celda27))
	ciudad27.demografia["desempleado"] = 3
	for i in range(3):
		assert(colonos27.contratar(Vector2i(2, 2), "recolector"))
	var todos27 := false
	for i in range(600):
		colonos27.avanzar(0.1)
		if economia27.trabajadores_de(Vector2i(2, 2))["presentes"] == 3:
			todos27 = true
			break
	assert(todos27, "los tres llegan a la zona de servicio y quedan presentes")
	var celdas27: Dictionary = {}
	for id27 in ids27:
		var c27: Dictionary = colonos27.colonos[id27]
		assert(absi(c27["celda"].x - 7) <= 2 and absi(c27["celda"].z - 3) <= 2, "dentro de la zona de servicio")
		assert(not (c27["celda"].x in [2, 3] and c27["celda"].z in [2, 3]), "no dentro de la huella")
		celdas27[c27["celda"]] = true
	assert(celdas27.size() == 3, "cada uno en su propia celda")

	print("\n=== TEST 28: agotamiento/desactivación: el recolector vuelve a desempleado y el acarreador con carga termina el viaje ===")
	var ciudad28: Node = CiudadScript.new()
	var colonos28: Node = _nuevo_con_puesto(ciudad28)
	var id_rec28: int = colonos28.agregar_colono("desempleado", Vector3i(6, 1, 1))
	var id_acar28: int = colonos28.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad28.demografia["desempleado"] = 2
	assert(colonos28.contratar(Vector2i(2, 2), "recolector"))
	assert(colonos28.contratar(Vector2i(2, 2), "acarreador"))
	# contratar() toma al desempleado de id menor: el recolector es id_rec28 y el acarreador id_acar28.
	var recolector28: Dictionary = colonos28.colonos[id_rec28]
	var acarreador28: Dictionary = colonos28.colonos[id_acar28]
	assert(recolector28["trabajo"]["rol"] == "recolector" and acarreador28["trabajo"]["rol"] == "acarreador")
	acarreador28["fase"] = "entregar"
	acarreador28["carga"] = {"madera": 50.0}
	var madera28: float = ciudad28.almacen["madera"].cantidad
	colonos28.economia.desactivar_puesto(Vector2i(2, 2))
	assert(recolector28["tipo"] == "desempleado" and recolector28["trabajo"].is_empty(), "el recolector queda libre al instante")
	assert(acarreador28["tipo"] == "obrero" and acarreador28.get("retirar_al_entregar", false), "el acarreador cargado sigue hasta entregar")
	var entrego28 := false
	for i in range(1500):
		colonos28.avanzar(0.1)
		if acarreador28["tipo"] == "desempleado":
			entrego28 = true
			break
	assert(entrego28, "entrega y queda libre (aunque el puesto siga inactivo)")
	assert(is_equal_approx(ciudad28.almacen["madera"].cantidad, madera28 + 50.0), "la carga llegó al núcleo")
	assert(acarreador28["carga"].is_empty() and not acarreador28.get("retirar_al_entregar", false))

	print("\n=== TEST 29: un acarreador con carga cuyo puesto se quita entretanto sigue entregando ===")
	var ciudad29: Node = CiudadScript.new()
	var colonos29: Node = _nuevo_con_puesto(ciudad29)
	var id29: int = colonos29.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad29.demografia["desempleado"] = 1
	assert(colonos29.contratar(Vector2i(2, 2), "acarreador"))
	var c29: Dictionary = colonos29.colonos[id29]
	c29["fase"] = "entregar"
	c29["carga"] = {"madera": 30.0}
	colonos29.economia.liberar(id29)  # lo que hace Economia._liberar_de() al agotarse el puesto...
	colonos29.economia.trabajadores_liberados.emit([id29])  # ...con carga a cuestas
	colonos29.economia.quitar_puesto(Vector2i(2, 2))  # y el puesto desaparece antes de que llegue (ya no lo lista entre sus trabajadores)
	assert(c29["tipo"] == "obrero" and c29["carga"].size() == 1, "quitar el puesto no le quita la carga")
	var madera29: float = ciudad29.almacen["madera"].cantidad
	var llego29 := false
	for i in range(1500):
		colonos29.avanzar(0.1)
		if c29["tipo"] == "desempleado":
			llego29 = true
			break
	assert(llego29 and is_equal_approx(ciudad29.almacen["madera"].cantidad, madera29 + 30.0), "no se atasca aunque el puesto ya no exista")

	print("\n=== TEST 30: los colonos entran por la puerta al edificio del puesto (sin taponar la entrada); el resto espera en la zona de servicio ===")
	var ciudad30: Node = CiudadScript.new()
	var mundo30: MundoFalso = _mundo_llano()
	# Edificio 3x4 en (3,2)-(5,5): paredes en y=1 y 2, puerta en (4,2) mirando a -Z, techo en y=3
	# e interior de 2 celdas ((4,3) y (4,4)).
	for x30 in range(3, 6):
		for z30 in range(2, 6):
			mundo30.poner(Vector3i(x30, 3, z30), "pared")
			var es_interior30: bool = x30 == 4 and z30 in [3, 4]
			var es_puerta30: bool = x30 == 4 and z30 == 2
			if es_interior30:
				continue
			for y30 in [1, 2]:
				mundo30.poner(Vector3i(x30, y30, z30), "puerta_inferior" if es_puerta30 and y30 == 1 else ("puerta_superior" if es_puerta30 else "pared"))
	var economia30: Node = EconomiaScript.new()
	economia30.ciudad = ciudad30
	economia30.registrar_puesto(Vector2i(3, 2), "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(4, 1), EconomiaScript.SIN_DEPOSITO, 1)
	var colonos30: Node = _nuevo(mundo30, ciudad30)
	colonos30.economia = economia30
	var ids30: Array[int] = []
	for celda30 in [Vector3i(0, 1, 7), Vector3i(0, 1, 8), Vector3i(0, 1, 9)]:
		ids30.append(colonos30.agregar_colono("desempleado", celda30))
	ciudad30.demografia["desempleado"] = 3
	for i in range(3):
		assert(colonos30.contratar(Vector2i(3, 2), "recolector"))
	var todos30 := false
	for i in range(900):
		colonos30.avanzar(0.1)
		if economia30.trabajadores_de(Vector2i(3, 2))["presentes"] == 3:
			todos30 = true
			break
	assert(todos30, "los tres quedan presentes")
	var dentro30 := 0
	for id30 in ids30:
		var c30: Vector3i = colonos30.colonos[id30]["celda"]
		if c30.x == 4 and c30.z in [3, 4] and c30.y == 1:
			dentro30 += 1
		else:
			assert(absi(c30.x - 4) <= 2 and absi(c30.z - 1) <= 2, "el que no cabe dentro espera en la zona de servicio")
	assert(dentro30 == 1, "uno entra y se queda al fondo; la celda pegada a la puerta queda libre (dentro: %d)" % dentro30)
	for id30 in ids30:
		assert(colonos30.colonos[id30]["celda"] != Vector3i(4, 1, 3), "nadie se queda pegado a la puerta por dentro")
	for id30 in ids30:
		assert(colonos30.colonos[id30]["celda"] != Vector3i(4, 1, 2), "nadie se queda parado en la puerta")
		assert(colonos30.colonos[id30]["celda"] != Vector3i(4, 1, 1), "ni en la celda frente a la puerta")

	print("\n=== TEST 31: si el suelo frente a la puerta queda muy por encima, no se buscan rutas al interior y todos esperan fuera ===")
	var ciudad31: Node = CiudadScript.new()
	var mundo31: MundoFalso = _mundo_llano()
	for x31 in range(3, 6):
		for z31 in range(2, 6):
			mundo31.poner(Vector3i(x31, 3, z31), "pared")
			var es_interior31: bool = x31 == 4 and z31 in [3, 4]
			var es_puerta31: bool = x31 == 4 and z31 == 2
			if es_interior31:
				continue
			for y31 in [1, 2]:
				mundo31.poner(Vector3i(x31, y31, z31), "puerta_inferior" if es_puerta31 and y31 == 1 else ("puerta_superior" if es_puerta31 else "pared"))
	for x31 in range(2, 7):  # el suelo frente a la puerta (fila z=1) sube 3 bloques: no se puede entrar
		for y31 in [1, 2, 3]:
			mundo31.poner(Vector3i(x31, y31, 1), "tierra")
	var economia31: Node = EconomiaScript.new()
	economia31.ciudad = ciudad31
	economia31.registrar_puesto(Vector2i(3, 2), "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(4, 1), EconomiaScript.SIN_DEPOSITO, 1)
	var colonos31: Node = _nuevo(mundo31, ciudad31)
	colonos31.economia = economia31
	assert(not colonos31._entrada_practicable(Vector2i(4, 1), 1), "la puerta no se alcanza desde ese suelo")
	assert(colonos31._celdas_interiores(economia31.huella_de(Vector2i(3, 2)), 1, Vector2i(4, 1)).is_empty(), "sin entrada practicable no hay celdas interiores que buscar")
	assert(colonos30._entrada_practicable(Vector2i(4, 1), 1), "en la casa normal sí se entra")

	print("\n=== TEST 32: buscar el camino a un puesto inalcanzable se reparte entre fotogramas (presupuesto de nodos) en vez de congelar el juego ===")
	var ciudad32: Node = CiudadScript.new()
	var mundo32: MundoFalso = _mundo_llano(60)
	for z32 in range(60):  # muro de lado a lado en x = 12: el puesto (al oeste) no se alcanza desde el este
		for y32 in [1, 2, 3]:
			mundo32.poner(Vector3i(12, y32, z32), "pared")
	var economia32: Node = EconomiaScript.new()
	economia32.ciudad = ciudad32
	economia32.registrar_puesto(Vector2i(2, 2), "maderero", 2, 2, {"madera": 3.0})
	var colonos32: Node = _nuevo(mundo32, ciudad32)
	colonos32.economia = economia32
	var ids32: Array[int] = []
	for k32 in range(4):
		ids32.append(colonos32.agregar_colono("desempleado", Vector3i(40 + k32, 1, 30)))
	ciudad32.demografia["desempleado"] = 4
	for k32 in range(4):
		assert(colonos32.contratar(Vector2i(2, 2), "recolector"))
	var llamadas32 := 0
	var maximo32 := 0
	var todos_fallaron32 := false
	while llamadas32 < 400 and not todos_fallaron32:
		colonos32.avanzar(0.01)
		llamadas32 += 1
		maximo32 = maxi(maximo32, colonos32.NODOS_POR_FRAME - colonos32._nodos_libres)
		todos_fallaron32 = true
		for id32 in ids32:
			if colonos32.colonos[id32]["fallos_servicio"] == 0:
				todos_fallaron32 = false
	assert(todos_fallaron32, "los cuatro terminan sin ruta y pasan a esperar")
	assert(maximo32 <= colonos32.NODOS_POR_FRAME, "cada llamada gasta como mucho el presupuesto (%d)" % maximo32)
	assert(llamadas32 >= 6, "la búsqueda inalcanzable se repartió en varias llamadas (%d)" % llamadas32)

	print("\n=== TEST 33: las búsquedas locales (esquivar, replanificar, evacuar, deambular) usan el tope de nodos reducido, no el de cruzar el mapa ===")
	var espia33 := BuscadorEspia.new(_mundo_llano(20))
	var colonos33: Node = _nuevo(_mundo_llano(20), CiudadScript.new())
	colonos33._buscador = espia33
	var id33: int = colonos33.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c33: Dictionary = colonos33.colonos[id33]
	c33["ruta"] = [Vector3i(5, 1, 5)]
	colonos33._esquivar(c33)
	assert(espia33.topes.back() == colonos33.TOPE_NODOS_DESTINO, "_esquivar usa el tope local")
	c33["ruta"] = [Vector3i(5, 1, 5)]
	colonos33._replanificar(c33)
	assert(espia33.topes.back() == colonos33.TOPE_NODOS_DESTINO, "_replanificar usa el tope local")
	c33["evacuando"] = 7
	espia33.topes.clear()
	colonos33._planear_evacuacion(c33)
	assert(espia33.topes.size() == 1 and espia33.topes.back() == colonos33.TOPE_NODOS_DESTINO, "la evacuación usa el tope local")
	c33["evacuando"] = -1
	colonos33._nodos_libres = 0  # sin presupuesto: solo se prepara la búsqueda de deambular
	espia33.topes.clear()
	colonos33._elegir_destino(c33)
	assert(not c33["busqueda"].is_empty() and c33["busqueda"]["tope"] == colonos33.TOPE_NODOS_DESTINO, "deambular se reparte por fotogramas con el tope local")

	print("\n=== TEST 34: en un edificio con un solo sitio libre (pegado a la puerta) un colono sí lo ocupa ===")
	var ciudad34: Node = CiudadScript.new()
	var mundo34: MundoFalso = _mundo_llano()
	for x34 in range(3, 6):
		for z34 in range(2, 6):
			mundo34.poner(Vector3i(x34, 3, z34), "pared")
			var es_interior34: bool = x34 == 4 and z34 == 3  # solo (4,3), pegado a la puerta
			var es_puerta34: bool = x34 == 4 and z34 == 2
			if es_interior34:
				continue
			for y34 in [1, 2]:
				mundo34.poner(Vector3i(x34, y34, z34), "puerta_inferior" if es_puerta34 and y34 == 1 else ("puerta_superior" if es_puerta34 else "pared"))
	var economia34: Node = EconomiaScript.new()
	economia34.ciudad = ciudad34
	economia34.registrar_puesto(Vector2i(3, 2), "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(4, 1), EconomiaScript.SIN_DEPOSITO, 1)
	var colonos34: Node = _nuevo(mundo34, ciudad34)
	colonos34.economia = economia34
	var ids34: Array[int] = []
	for celda34 in [Vector3i(0, 1, 7), Vector3i(0, 1, 8)]:
		ids34.append(colonos34.agregar_colono("desempleado", celda34))
	ciudad34.demografia["desempleado"] = 2
	for i in range(2):
		assert(colonos34.contratar(Vector2i(3, 2), "recolector"))
	var todos34 := false
	for i in range(900):
		colonos34.avanzar(0.1)
		if economia34.trabajadores_de(Vector2i(3, 2))["presentes"] == 2:
			todos34 = true
			break
	assert(todos34, "los dos quedan presentes")
	var dentro34 := 0
	for id34 in ids34:
		if colonos34.colonos[id34]["celda"] == Vector3i(4, 1, 3):
			dentro34 += 1
	assert(dentro34 == 1, "uno ocupa el único sitio libre del edificio (dentro: %d)" % dentro34)

	print("\n=== TEST 35: el colono que espera fuera entra al edificio en cuanto se libera un sitio dentro ===")
	var ciudad35: Node = CiudadScript.new()
	var mundo35: MundoFalso = _mundo_llano()
	for x35 in range(3, 6):
		for z35 in range(2, 6):
			mundo35.poner(Vector3i(x35, 3, z35), "pared")
			var es_interior35: bool = x35 == 4 and z35 in [3, 4]
			var es_puerta35: bool = x35 == 4 and z35 == 2
			if es_interior35:
				continue
			for y35 in [1, 2]:
				mundo35.poner(Vector3i(x35, y35, z35), "puerta_inferior" if es_puerta35 and y35 == 1 else ("puerta_superior" if es_puerta35 else "pared"))
	var economia35: Node = EconomiaScript.new()
	economia35.ciudad = ciudad35
	economia35.registrar_puesto(Vector2i(3, 2), "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(4, 1), EconomiaScript.SIN_DEPOSITO, 1)
	var colonos35: Node = _nuevo(mundo35, ciudad35)
	colonos35.economia = economia35
	var id35: int = colonos35.agregar_colono("desempleado", Vector3i(0, 1, 7))
	ciudad35.demografia["desempleado"] = 1
	colonos35.ocupadas[Vector3i(4, 1, 4)] = 9999  # el único sitio del fondo está ocupado por otro
	assert(colonos35.contratar(Vector2i(3, 2), "recolector"))
	for i in range(300):
		colonos35.avanzar(0.1)
	var c35: Dictionary = colonos35.colonos[id35]
	assert(economia35.trabajadores_de(Vector2i(3, 2))["presentes"] == 1 and not (c35["celda"].x in [3, 4, 5] and c35["celda"].z in [2, 3, 4, 5]), "primero espera fuera del edificio, presente en la zona de servicio")
	colonos35.ocupadas.erase(Vector3i(4, 1, 4))  # se libera el sitio de dentro
	var entro35 := false
	for i in range(600):
		colonos35.avanzar(0.1)
		if c35["celda"] == Vector3i(4, 1, 4):
			entro35 = true
			break
	assert(entro35, "entra al edificio al liberarse el sitio")

	print("\n=== TEST 36: el edificio se llena desde el fondo: los primeros no sellan la entrada y caben todos ===")
	var ciudad36: Node = CiudadScript.new()
	var mundo36: MundoFalso = _mundo_llano(14)
	# Casa 5x5 en (2,2)-(6,6): puerta en (4,2) mirando a -Z, interior libre 3x3 (x 3..5, z 3..5).
	for x36 in range(2, 7):
		for z36 in range(2, 7):
			mundo36.poner(Vector3i(x36, 3, z36), "pared")
			var es_interior36: bool = x36 in [3, 4, 5] and z36 in [3, 4, 5]
			var es_puerta36: bool = x36 == 4 and z36 == 2
			if es_interior36:
				continue
			for y36 in [1, 2]:
				mundo36.poner(Vector3i(x36, y36, z36), "puerta_inferior" if es_puerta36 and y36 == 1 else ("puerta_superior" if es_puerta36 else "pared"))
	var economia36: Node = EconomiaScript.new()
	economia36.ciudad = ciudad36
	economia36.registrar_puesto(Vector2i(2, 2), "mina", 5, 5, {"hierro": 5.0}, {}, Vector2i(4, 1), EconomiaScript.SIN_DEPOSITO, 1)
	var colonos36: Node = _nuevo(mundo36, ciudad36)
	colonos36.economia = economia36
	var ids36: Array[int] = []
	for celda36 in [Vector3i(0, 1, 9), Vector3i(0, 1, 10), Vector3i(0, 1, 11), Vector3i(0, 1, 12)]:
		ids36.append(colonos36.agregar_colono("desempleado", celda36))
	ciudad36.demografia["desempleado"] = 4
	for i in range(4):
		assert(colonos36.contratar(Vector2i(2, 2), "recolector"))
	for i in range(1500):
		colonos36.avanzar(0.1)
	var dentro36 := 0
	for id36 in ids36:
		var c36: Vector3i = colonos36.colonos[id36]["celda"]
		if c36.x in [3, 4, 5] and c36.z in [3, 4, 5]:
			dentro36 += 1
		assert(c36 != Vector3i(4, 1, 3), "nadie en el vestíbulo")
	assert(dentro36 == 4, "los cuatro caben dentro (dentro: %d)" % dentro36)
	assert(economia36.trabajadores_de(Vector2i(2, 2))["presentes"] == 4)

	print("\n=== TEST 37: una refinería solo contrata técnicos libres; al despedirlos siguen siendo técnicos ===")
	var ciudad37: Node = CiudadScript.new()
	var colonos37: Node = _nuevo_con_siderurgica(ciudad37)
	var id37: int = colonos37.agregar_colono("desempleado", Vector3i(6, 1, 1))
	ciudad37.demografia["desempleado"] = 1
	assert(not colonos37.contratar(Vector2i(2, 2), "recolector"), "una refinería no acepta recolectores")
	assert(not colonos37.contratar(Vector2i(2, 2), "tecnico"), "un desempleado no se convierte en técnico: hace falta formarlo")
	assert(ciudad37.demografia["desempleado"] == 1 and ciudad37.demografia["tecnico"] == 0, "el rechazo no toca la demografía")
	assert(colonos37.colonos[id37]["tipo"] == "desempleado")
	var tecnico37: int = colonos37.agregar_colono("tecnico", Vector3i(6, 1, 2))
	ciudad37.demografia["tecnico"] = 1
	assert(colonos37.tecnicos_libres() == 1)
	assert(colonos37.contratar(Vector2i(2, 2), "tecnico"))
	assert(colonos37.colonos[tecnico37]["tipo"] == "tecnico" and colonos37.colonos[tecnico37]["trabajo"]["puesto"] == Vector2i(2, 2))
	assert(ciudad37.demografia["tecnico"] == 1 and ciudad37.demografia["desempleado"] == 1, "contratar a un técnico libre no cambia la demografía")
	assert(colonos37.tecnicos_libres() == 0, "ya no queda ninguno libre")
	assert(colonos37.despedir(Vector2i(2, 2), "tecnico"))
	assert(colonos37.colonos[tecnico37]["tipo"] == "tecnico" and ciudad37.demografia["tecnico"] == 1 and ciudad37.demografia["desempleado"] == 1, "el técnico despedido sigue siendo técnico")
	assert(colonos37.tecnicos_libres() == 1)
	assert(colonos37.contratar(Vector2i(2, 2), "tecnico"))
	colonos37.economia.quitar_puesto(Vector2i(2, 2))
	assert(colonos37.colonos[tecnico37]["tipo"] == "tecnico" and colonos37.tecnicos_libres() == 1, "al deconstruir la refinería el técnico queda libre")

	print("\n=== TEST 38: un técnico camina a la siderúrgica, queda presente y refina ===")
	var ciudad38: Node = CiudadScript.new()
	var colonos38: Node = _nuevo_con_siderurgica(ciudad38)
	colonos38.agregar_colono("tecnico", Vector3i(6, 1, 1))
	ciudad38.demografia["tecnico"] = 1
	assert(colonos38.contratar(Vector2i(2, 2), "tecnico"))
	var llego38 := false
	for i in range(400):
		colonos38.avanzar(0.1)
		if colonos38.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 1:
			llego38 = true
			break
	assert(llego38, "el técnico llega junto a la entrada y se marca presente")
	colonos38.economia.puestos[Vector2i(2, 2)]["almacen"] = {"hierro": 20.0, "carbon": 20.0}
	colonos38.economia.simular_hora()
	assert(is_equal_approx(colonos38.economia.almacen_local(Vector2i(2, 2))["acero"], 4.0), "1 técnico: 6 hierro + 8 carbón -> 4 acero por hora")

	print("\n=== TEST 39: el acarreador lleva hierro del núcleo a la entrada y trae el acero de la salida al núcleo ===")
	var ciudad39: Node = CiudadScript.new()
	var colonos39: Node = _nuevo_con_siderurgica(ciudad39)
	ciudad39.almacen["hierro"].cantidad = 50.0
	ciudad39.almacen["carbon"].cantidad = 60.0
	colonos39.economia.puestos[Vector2i(2, 2)]["almacen"]["acero"] = 20.0
	var id39: int = colonos39.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad39.demografia["desempleado"] = 1
	assert(colonos39.contratar(Vector2i(2, 2), "acarreador"))
	assert(colonos39.colonos[id39]["tipo"] == "obrero", "el acarreador es obrero")
	var entrego39 := false
	for i in range(3000):  # hasta 300 s de juego
		colonos39.avanzar(0.1)
		if ciudad39.almacen["acero"].cantidad >= 20.0:
			entrego39 = true
			break
	assert(entrego39, "el acero llega al stock central")
	assert(is_equal_approx(ciudad39.almacen["acero"].cantidad, 20.0))
	assert(is_equal_approx(ciudad39.almacen["hierro"].cantidad, 0.0) and is_equal_approx(ciudad39.almacen["carbon"].cantidad, 0.0), "todo el hierro y el carbón salió del stock central")
	assert(is_equal_approx(colonos39.economia.almacen_local(Vector2i(2, 2))["carbon"], 60.0))
	assert(is_equal_approx(colonos39.economia.almacen_local(Vector2i(2, 2))["hierro"], 50.0), "y quedó en el almacén de la siderúrgica")
	assert(not colonos39.economia.almacen_local(Vector2i(2, 2)).has("acero"), "no queda acero")
	assert(colonos39.colonos[id39]["carga"].is_empty())

	print("\n=== TEST 39b: sin hierro en el núcleo ni acero que recoger, el acarreador espera sin viajar ===")
	var ciudad39b: Node = CiudadScript.new()
	var colonos39b: Node = _nuevo_con_siderurgica(ciudad39b)
	var id39b: int = colonos39b.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad39b.demografia["desempleado"] = 1
	colonos39b.contratar(Vector2i(2, 2), "acarreador")
	var celda39b: Vector3i = colonos39b.colonos[id39b]["celda"]
	for i in range(200):
		colonos39b.avanzar(0.1)
	assert(colonos39b.colonos[id39b]["celda"] == celda39b and colonos39b.colonos[id39b]["fase"] == "", "no se mueve ni queda en una fase a medias")
	# Con 9 unidades de acero (< CARGA_MINIMA) tampoco justifica el viaje.
	colonos39b.economia.puestos[Vector2i(2, 2)]["almacen"]["acero"] = 9.0
	for i in range(200):
		colonos39b.avanzar(0.1)
	assert(colonos39b.colonos[id39b]["celda"] == celda39b, "un resto menor al mínimo no mueve al acarreador")

	print("\n=== TEST 39c: si a la siderúrgica no le alcanza para producir, el acarreador le lleva aunque sea poco ===")
	var ciudad39c: Node = CiudadScript.new()
	var colonos39c: Node = _nuevo_con_siderurgica(ciudad39c)
	ciudad39c.almacen["carbon"].cantidad = 5.0  # menos que CARGA_MINIMA
	colonos39c.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad39c.demografia["desempleado"] = 1
	colonos39c.contratar(Vector2i(2, 2), "acarreador")
	assert(colonos39c.economia.falta_insumo(Vector2i(2, 2)) and colonos39c.economia.conviene_cargar(Vector2i(2, 2)))
	var llevo39c := false
	for i in range(3000):
		colonos39c.avanzar(0.1)
		if colonos39c.economia.almacen_local(Vector2i(2, 2)).get("carbon", 0.0) > 0.0:
			llevo39c = true
			break
	assert(llevo39c, "el carbón pedido llega al almacén de la siderúrgica")
	assert(is_equal_approx(colonos39c.economia.almacen_local(Vector2i(2, 2))["carbon"], 5.0))

	print("\n=== TEST 40: si la siderúrgica se desactiva con hierro en camino, el acarreador lo devuelve al stock central ===")
	var ciudad40: Node = CiudadScript.new()
	var colonos40: Node = _nuevo_con_siderurgica(ciudad40)
	var id40: int = colonos40.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad40.demografia["desempleado"] = 1
	colonos40.contratar(Vector2i(2, 2), "acarreador")
	var acarreador40: Dictionary = colonos40.colonos[id40]
	acarreador40["fase"] = "entrada"
	acarreador40["carga"] = {"hierro": 30.0}
	var hierro40: float = ciudad40.almacen["hierro"].cantidad
	colonos40.economia.desactivar_puesto(Vector2i(2, 2))
	assert(acarreador40["fase"] == "entregar" and acarreador40.get("retirar_al_entregar", false), "con carga en cualquier fase, termina el viaje al núcleo")
	var devolvio40 := false
	for i in range(1500):
		colonos40.avanzar(0.1)
		if acarreador40["tipo"] == "desempleado":
			devolvio40 = true
			break
	assert(devolvio40, "devuelve la carga y queda libre")
	assert(is_equal_approx(ciudad40.almacen["hierro"].cantidad, hierro40 + 30.0), "el hierro volvió al stock central")
	assert(ciudad40.demografia["obrero"] == 0 and ciudad40.demografia["desempleado"] == 1)

	print("\n=== TEST 41: despedir o quitar el puesto devuelve el insumo en camino, pero no el producto ===")
	var ciudad41: Node = CiudadScript.new()
	var colonos41: Node = _nuevo_con_siderurgica(ciudad41)
	var id41: int = colonos41.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad41.demografia["desempleado"] = 1
	colonos41.contratar(Vector2i(2, 2), "acarreador")
	colonos41.colonos[id41]["fase"] = "entrada"
	colonos41.colonos[id41]["carga"] = {"hierro": 30.0}
	var hierro41: float = ciudad41.almacen["hierro"].cantidad
	assert(colonos41.despedir(Vector2i(2, 2), "acarreador"))
	assert(is_equal_approx(ciudad41.almacen["hierro"].cantidad, hierro41 + 30.0), "el insumo vuelve al stock central")
	assert(colonos41.colonos[id41]["tipo"] == "desempleado" and colonos41.colonos[id41]["carga"].is_empty())
	assert(ciudad41.demografia["obrero"] == 0 and ciudad41.demografia["desempleado"] == 1)
	colonos41.contratar(Vector2i(2, 2), "acarreador")
	colonos41.colonos[id41]["fase"] = "entregar"
	colonos41.colonos[id41]["carga"] = {"acero": 20.0}
	var acero41: float = ciudad41.almacen["acero"].cantidad
	assert(colonos41.despedir(Vector2i(2, 2), "acarreador"))
	assert(is_equal_approx(ciudad41.almacen["acero"].cantidad, acero41), "el producto no se teletransporta al stock")
	colonos41.contratar(Vector2i(2, 2), "acarreador")
	colonos41.colonos[id41]["fase"] = "entrada"
	colonos41.colonos[id41]["carga"] = {"hierro": 30.0}
	hierro41 = ciudad41.almacen["hierro"].cantidad
	colonos41.economia.quitar_puesto(Vector2i(2, 2))
	assert(is_equal_approx(ciudad41.almacen["hierro"].cantidad, hierro41 + 30.0), "al quitar el puesto el insumo también vuelve")
	assert(colonos41.colonos[id41]["tipo"] == "desempleado" and ciudad41.demografia["obrero"] == 0)

	print("\n=== TEST 42: una cohorte de 4 aprendices estudia 24 h y sale como 3 técnicos libres; el cuarto se va (la vivienda ocupada se conserva) ===")
	var ciudad42: Node = CiudadScript.new()
	var colonos42: Node = _nuevo_con_escuela(ciudad42)
	var ids42: Array[int] = []
	for z42 in range(1, 5):
		ids42.append(colonos42.agregar_colono("desempleado", Vector3i(6, 1, z42)))
	ciudad42.demografia["desempleado"] = 4
	var formados42: Array = []
	colonos42.tecnicos_formados.connect(func(cantidad: int) -> void: formados42.append(cantidad))
	assert(not colonos42.contratar(Vector2i(2, 2), "tecnico") and not colonos42.contratar(Vector2i(2, 2), "acarreador"), "la escuela solo admite aprendices")
	for i42 in range(4):
		assert(colonos42.contratar(Vector2i(2, 2), "aprendiz"))
	assert(ciudad42.demografia["obrero"] == 4 and ciudad42.demografia["desempleado"] == 0, "un aprendiz cuenta como obrero mientras estudia")
	assert(is_equal_approx(ciudad42.vivienda_ocupada, 1.0))
	for id42 in ids42:
		colonos42.economia.marcar_presente(id42, true)
	for hora42 in range(23):
		colonos42.economia.simular_hora()
	assert(formados42.is_empty() and _contar(colonos42, "tecnico") == 0, "a las 23 h todavía no se gradúa")
	colonos42.economia.simular_hora()
	assert(formados42 == [3], "salen 3 técnicos")
	assert(_contar(colonos42, "tecnico") == 3 and colonos42.colonos.size() == 3, "el cuarto colono se fue de la ciudad")
	assert(not colonos42.colonos.has(ids42[3]), "se va el de id mayor")
	assert(ciudad42.demografia["tecnico"] == 3 and ciudad42.demografia["obrero"] == 0 and ciudad42.demografia["desempleado"] == 0)
	assert(is_equal_approx(ciudad42.vivienda_ocupada, 1.0), "la vivienda ocupada se conserva: 4 x 1/4 = 3 x 1/3")
	assert(colonos42.tecnicos_libres() == 3, "los técnicos nuevos quedan sin puesto")
	assert(colonos42.economia.cupo_libre(Vector2i(2, 2)) == 4, "la escuela queda libre para otra cohorte")

	print("\n=== TEST 43: despedir a un aprendiz reinicia la cohorte; deconstruir la escuela devuelve a los aprendices a desempleado ===")
	var ciudad43: Node = CiudadScript.new()
	var colonos43: Node = _nuevo_con_escuela(ciudad43)
	var ids43: Array[int] = []
	for z43 in range(1, 5):
		ids43.append(colonos43.agregar_colono("desempleado", Vector3i(6, 1, z43)))
	ciudad43.demografia["desempleado"] = 4
	for i43 in range(4):
		colonos43.contratar(Vector2i(2, 2), "aprendiz")
	for id43 in ids43:
		colonos43.economia.marcar_presente(id43, true)
	for hora43 in range(10):
		colonos43.economia.simular_hora()
	assert(colonos43.economia.puestos[Vector2i(2, 2)]["progreso"] == 10.0)
	assert(colonos43.despedir(Vector2i(2, 2), "aprendiz"))
	assert(ciudad43.demografia["obrero"] == 3 and ciudad43.demografia["desempleado"] == 1, "el despedido vuelve a desempleado, sin formación")
	assert(colonos43.economia.puestos[Vector2i(2, 2)]["progreso"] == 0.0, "la cohorte empieza de nuevo")
	for hora43 in range(30):
		colonos43.economia.simular_hora()
	assert(_contar(colonos43, "tecnico") == 0 and ciudad43.demografia["tecnico"] == 0, "con 3 aprendices no se gradúa nadie")
	colonos43.economia.quitar_puesto(Vector2i(2, 2))
	assert(ciudad43.demografia["obrero"] == 0 and ciudad43.demografia["desempleado"] == 4 and ciudad43.demografia["tecnico"] == 0, "sin escuela, los aprendices vuelven a desempleado")
	assert(_contar(colonos43, "desempleado") == 4)

	print("\n=== TEST 44: si una hambruna ya bajó la demografía antes de graduarse, esta no queda negativa y reconciliar() iguala colonos y demografía ===")
	var ciudad44: Node = CiudadScript.new()
	var colonos44: Node = _nuevo_con_escuela(ciudad44)
	var ids44: Array[int] = []
	for z44 in range(1, 5):
		ids44.append(colonos44.agregar_colono("desempleado", Vector3i(6, 1, z44)))
	ciudad44.demografia["desempleado"] = 4
	for i44 in range(4):
		colonos44.contratar(Vector2i(2, 2), "aprendiz")
	for id44 in ids44:
		colonos44.economia.marcar_presente(id44, true)
	for hora44 in range(23):
		colonos44.economia.simular_hora()
	ciudad44.demografia["obrero"] = 2  # una hambruna ya se llevó a 2; reconciliar() aún no retiró a sus colonos
	colonos44.economia.simular_hora()
	for tipo44 in ciudad44.demografia:
		assert(ciudad44.demografia[tipo44] >= 0, "la demografía de %s no puede quedar negativa" % tipo44)
	colonos44.reconciliar()
	for tipo44 in ciudad44.demografia:
		assert(_contar(colonos44, tipo44) == ciudad44.demografia[tipo44], "colonos y demografía coinciden en %s" % tipo44)

	print("\n=== TEST 44b: escuela de especialistas: 3 técnicos presentes se gradúan a las 48 h como 2 especialistas, conservando vivienda ===")
	var ciudad44b: Node = CiudadScript.new()
	var colonos44b: Node = _nuevo_con_escuela_especialistas(ciudad44b)
	var ids44b: Array[int] = []
	for z44b in range(1, 4):
		ids44b.append(colonos44b.agregar_colono("tecnico", Vector3i(6, 1, z44b)))
	ciudad44b.demografia["tecnico"] = 3
	for i44b in range(3):
		assert(colonos44b.contratar(Vector2i(2, 2), "aprendiz"))
	assert(ciudad44b.demografia["tecnico"] == 3, "un aprendiz de especialista sigue contando como técnico")
	assert(is_equal_approx(ciudad44b.vivienda_ocupada, 1.0))
	for id44b in ids44b:
		colonos44b.economia.marcar_presente(id44b, true)
	for hora44b in range(47):
		colonos44b.economia.simular_hora()
	assert(_contar(colonos44b, "especialista") == 0, "a las 47 h todavía no se gradúa")
	colonos44b.economia.simular_hora()
	assert(_contar(colonos44b, "especialista") == 2 and colonos44b.colonos.size() == 2, "salen 2 especialistas y el tercero se va")
	assert(ciudad44b.demografia["especialista"] == 2 and ciudad44b.demografia["tecnico"] == 0)
	assert(is_equal_approx(ciudad44b.vivienda_ocupada, 1.0), "la vivienda ocupada se conserva: 3 x 1/3 = 2 x 1/2")
	assert(colonos44b.especialistas_libres() == 2)
	# Reinicio al despedir
	var ids44c: Array[int] = []
	for z44c in range(1, 4):
		ids44c.append(colonos44b.agregar_colono("tecnico", Vector3i(6, 1, z44c)))
	ciudad44b.demografia["tecnico"] = 3
	for i44c in range(3):
		assert(colonos44b.contratar(Vector2i(2, 2), "aprendiz"))
	for id44c in ids44c:
		colonos44b.economia.marcar_presente(id44c, true)
	for hora44c in range(10):
		colonos44b.economia.simular_hora()
	assert(colonos44b.economia.puestos[Vector2i(2, 2)]["progreso"] == 10.0)
	assert(colonos44b.despedir(Vector2i(2, 2), "aprendiz"))
	assert(colonos44b.economia.puestos[Vector2i(2, 2)]["progreso"] == 0.0, "despedir a un aprendiz reinicia el progreso a cero")
	assert(colonos44b.tecnicos_libres() == 1, "el despedido sigue siendo técnico libre")

	print("\n=== TEST 45: el avatar empuja a un colono quieto de su celda a una celda libre; uno que camina no se toca ===")
	var colonos45: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id45: int = colonos45.agregar_colono("obrero", Vector3i(3, 1, 3))
	var c45: Dictionary = colonos45.colonos[id45]
	colonos45.actualizar_avatar(Vector3i(3, 1, 3), Vector3.ZERO)
	assert(c45["celda"] != Vector3i(3, 1, 3), "el colono salió de la celda del avatar")
	assert(colonos45.ocupadas[c45["celda"]] == id45 and not colonos45.ocupadas.has(Vector3i(3, 1, 3)), "quedó en una celda vecina libre, con la reserva movida")
	assert(c45["posicion"] == colonos45._centro_de(c45["celda"]), "y su posición lo sigue")
	var id45b: int = colonos45.agregar_colono("obrero", Vector3i(6, 1, 6))
	var c45b: Dictionary = colonos45.colonos[id45b]
	c45b["moviendo"] = true
	colonos45.actualizar_avatar(Vector3i(6, 1, 6), Vector3.ZERO)
	assert(c45b["celda"] == Vector3i(6, 1, 6), "el que ya camina no se empuja")

	print("\n=== TEST 46: un colono libre va a la obra, trabaja y repite; uno con empleo o con un aprendizaje la ignora; contratar cancela la tarea ===")
	var ciudad46: Node = CiudadScript.new()
	var colonos46: Node = _nuevo_con_puesto(ciudad46)
	var obras46 := ObrasFalsa.new()
	obras46.tarea = {"tipo": "construir", "id": 5}
	obras46.huella = [Vector2i(6, 6), Vector2i(7, 6)]  # una obra de 2 columnas lejos del maderero
	colonos46.obras = obras46
	var id46: int = colonos46.agregar_colono("desempleado", Vector3i(1, 1, 7))
	var c46: Dictionary = colonos46.colonos[id46]
	for _i in range(400):
		colonos46.avanzar(0.1)
		if not obras46.trabajos.is_empty():
			break
	assert(not obras46.trabajos.is_empty() and obras46.trabajos[0] == [5, "construir"], "el colono libre llegó a la obra y trabajó en ella")
	assert(colonos46._junto_a(c46["celda"], obras46.huella), "y trabajó pegado a la obra")
	assert(colonos46.obreros_en(5) == 1 and colonos46.obreros_en(6) == 0, "obreros_en cuenta a los que tienen esa obra como tarea")
	var trabajos_antes46: int = obras46.trabajos.size()
	obras46.resultado = {"estado": "completa", "espera": 0.0}
	for _i in range(60):
		colonos46.avanzar(0.1)
	assert(obras46.trabajos.size() > trabajos_antes46, "mientras la obra avanza, sigue trabajando")
	# Una obra «completa» suelta la tarea: sin trabajo nuevo, el colono vuelve a deambular.
	obras46.tarea = {}
	for _i in range(60):
		colonos46.avanzar(0.1)
	assert(c46["tarea"].is_empty(), "sin obra, el colono no conserva la tarea")
	# Un colono con puesto no pide obras.
	var obras46b := ObrasFalsa.new()
	obras46b.tarea = {"tipo": "construir", "id": 9}
	obras46b.huella = [Vector2i(6, 6)]
	var ciudad46b: Node = CiudadScript.new()
	var colonos46b: Node = _nuevo_con_puesto(ciudad46b)
	colonos46b.obras = obras46b
	var empleado46: int = colonos46b.agregar_colono("desempleado", Vector3i(1, 1, 7))
	ciudad46b.demografia["desempleado"] = 1
	assert(colonos46b.contratar(Vector2i(2, 2), "recolector"), "se contrata al desempleado")
	for _i in range(100):
		colonos46b.avanzar(0.1)
	assert(obras46b.trabajos.is_empty() and colonos46b.colonos[empleado46]["tarea"].is_empty(), "un colono con empleo ignora las obras")
	# Contratar a quien ya tenía tarea la cancela.
	var obras46c := ObrasFalsa.new()
	obras46c.tarea = {"tipo": "construir", "id": 9}
	obras46c.huella = [Vector2i(6, 6)]
	var ciudad46c: Node = CiudadScript.new()
	var colonos46c: Node = _nuevo_con_puesto(ciudad46c)
	colonos46c.obras = obras46c
	var libre46: int = colonos46c.agregar_colono("desempleado", Vector3i(1, 1, 7))
	ciudad46c.demografia["desempleado"] = 1
	for _i in range(3):
		colonos46c.avanzar(0.1)
	assert(not colonos46c.colonos[libre46]["tarea"].is_empty(), "el libre ya tomó una tarea")
	assert(colonos46c.contratar(Vector2i(2, 2), "recolector"), "se contrata")
	assert(colonos46c.colonos[libre46]["tarea"].is_empty(), "contratar cancela la tarea de obra")
	# Un técnico libre también construye.
	var obras46d := ObrasFalsa.new()
	obras46d.tarea = {"tipo": "demoler", "id": 3}
	obras46d.huella = [Vector2i(6, 6)]
	var colonos46d: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	colonos46d.obras = obras46d
	var tecnico46: int = colonos46d.agregar_colono("tecnico", Vector3i(1, 1, 7))
	for _i in range(400):
		colonos46d.avanzar(0.1)
		if not obras46d.trabajos.is_empty():
			break
	assert(not obras46d.trabajos.is_empty() and obras46d.trabajos[0] == [3, "demoler"], "un técnico libre también demuele")
	assert(colonos46d.colonos.has(tecnico46))

	print("\n=== TEST 47: contratar() por oficio en un puesto con niveles; un especialista despedido sigue siéndolo ===")
	var ciudad47: Node = CiudadScript.new()
	var colonos47: Node = _nuevo_con_puesto(ciudad47)  # maderero de 2x2 en (2, 2)
	var desempleado47: int = colonos47.agregar_colono("desempleado", Vector3i(6, 1, 1))
	var tecnico47: int = colonos47.agregar_colono("tecnico", Vector3i(6, 1, 2))
	var especialista47: int = colonos47.agregar_colono("especialista", Vector3i(6, 1, 3))
	ciudad47.demografia["desempleado"] = 1
	ciudad47.demografia["tecnico"] = 1
	ciudad47.demografia["especialista"] = 1
	assert(colonos47.especialistas_libres() == 1 and colonos47.tecnicos_libres() == 1)
	assert(colonos47.contratar(Vector2i(2, 2), "tecnico"))
	assert(colonos47.economia.nivel_de(Vector2i(2, 2)) == 2, "solo técnicos: nivel 2")
	assert(not colonos47.contratar(Vector2i(2, 2), "recolector"), "un obrero no entra a un puesto de nivel 2")
	assert(colonos47.colonos[desempleado47]["tipo"] == "desempleado" and ciudad47.demografia["desempleado"] == 1 and ciudad47.demografia["obrero"] == 0, "el rechazo no toca al colono ni la demografía")
	assert(colonos47.contratar(Vector2i(2, 2), "especialista"))
	assert(colonos47.colonos[especialista47]["tipo"] == "especialista" and colonos47.colonos[especialista47]["trabajo"]["puesto"] == Vector2i(2, 2))
	assert(ciudad47.demografia["especialista"] == 1 and ciudad47.demografia["tecnico"] == 1 and ciudad47.demografia["desempleado"] == 1, "contratar un oficio ya formado no cambia la demografía")
	assert(colonos47.especialistas_libres() == 0)
	assert(colonos47.despedir(Vector2i(2, 2), "especialista"))
	assert(colonos47.colonos[especialista47]["tipo"] == "especialista" and ciudad47.demografia["especialista"] == 1 and colonos47.especialistas_libres() == 1, "el especialista despedido sigue siéndolo")
	assert(colonos47.despedir(Vector2i(2, 2), "tecnico"))
	assert(colonos47.colonos[tecnico47]["tipo"] == "tecnico" and colonos47.economia.nivel_de(Vector2i(2, 2)) == 2, "vacío conserva el nivel 2")
	assert(not colonos47.contratar(Vector2i(2, 2), "recolector"), "ya no admite obreros")

	print("\n=== TEST 48: contratar() en universidad: técnicos/especialistas en nivel 2, solo especialistas en nivel 3 ===")
	var ciudad48: Node = CiudadScript.new()
	var colonos48: Node = _nuevo_con_puesto(ciudad48)
	var esq_u := Vector2i(80, 80)
	colonos48.economia.registrar_puesto(esq_u, "universidad", 5, 5, {})
	var desemp48: int = colonos48.agregar_colono("desempleado", Vector3i(1, 1, 1))
	var tec48: int = colonos48.agregar_colono("tecnico", Vector3i(1, 1, 2))
	var esp48: int = colonos48.agregar_colono("especialista", Vector3i(1, 1, 3))
	ciudad48.demografia["desempleado"] = 1
	ciudad48.demografia["tecnico"] = 1
	ciudad48.demografia["especialista"] = 1

	# Siguiente nivel es 2 (nivel_investigado == 1): admite técnico o especialista, pero no desempleado
	assert(ciudad48.nivel_investigado == 1)
	assert(colonos48.contratar(esq_u, "investigador"))  # contrata al de id menor entre tecnicos y especialistas (tec48)
	assert(colonos48.colonos[tec48]["trabajo"]["rol"] == "investigador")
	assert(colonos48.colonos[tec48]["tipo"] == "tecnico", "conserva oficio tecnico")
	assert(ciudad48.demografia["tecnico"] == 1 and ciudad48.demografia["desempleado"] == 1)

	# Sube a nivel investigado 2 (siguiente nivel 3): solo admite especialista
	ciudad48.nivel_investigado = 2
	assert(colonos48.contratar(esq_u, "investigador"))  # contrata a esp48
	assert(colonos48.colonos[esp48]["trabajo"]["rol"] == "investigador")
	assert(colonos48.colonos[esp48]["tipo"] == "especialista", "conserva oficio especialista")
	assert(colonos48.especialistas_libres() == 0)

	# Con solo desempleados libres no admite contratación para investigador
	assert(not colonos48.contratar(esq_u, "investigador"), "desempleado no puede ser investigador")

	# Despedir devuelve al colono libre con su oficio intacto
	assert(colonos48.despedir(esq_u, "investigador"))
	assert(colonos48.colonos[esp48]["tipo"] == "especialista" and colonos48.colonos[esp48]["trabajo"].is_empty())
	assert(colonos48.especialistas_libres() == 1)

	print("\n=== Las 48 pruebas de Colonos pasaron correctamente ===")
