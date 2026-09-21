extends Node

## Pruebas aisladas de BuscadorRutas.gd con un mundo falso determinista (mismo
## patrón que RecoleccionTest.gd). Corre esta escena con F6 o en headless y
## revisa la salida: no debe lanzar ningún error de assert().

const BuscadorRutas = preload("res://scripts/BuscadorRutas.gd")


## Mundo mínimo: solo sabe decir qué hay en una celda ("" si está vacía).
class MundoFalso extends RefCounted:
	var celdas: Dictionary = {}
	var ids: Dictionary = {}  # Vector3i -> int: la obra a la que pertenece cada fantasma

	func id_de_edificio(celda: Vector3i) -> int:
		return ids.get(celda, -1)

	func poner_fantasma(celda: Vector3i, id_obra: int) -> void:
		celdas[celda] = "fantasma"
		ids[celda] = id_obra

	func obtener_tipo(celda: Vector3i) -> String:
		return celdas.get(celda, "")

	func poner(celda: Vector3i, tipo: String) -> void:
		celdas[celda] = tipo


func _ready() -> void:
	ejecutar_pruebas()


## Suelo de "tierra" en y=0 para x en [0, ancho) y z en [0, largo). Las celdas
## por las que se camina están en y=1.
func _llano(mundo: MundoFalso, ancho: int, largo: int) -> void:
	for x in range(ancho):
		for z in range(largo):
			mundo.poner(Vector3i(x, 0, z), "tierra")


func _adyacentes(a: Vector3i, b: Vector3i) -> bool:
	return absi(a.x - b.x) + absi(a.z - b.z) == 1 and absi(a.y - b.y) <= 3


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Ruta recta en terreno llano ===")
	var m1 := MundoFalso.new()
	_llano(m1, 6, 3)
	var b1 := BuscadorRutas.new(m1)
	var ruta1: Array[Vector3i] = b1.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	print("Ruta: ", ruta1)
	assert(ruta1.size() == 4, "4 pasos en línea recta")
	assert(ruta1.back() == Vector3i(4, 1, 0))
	assert(ruta1[0] != Vector3i(0, 1, 0), "la ruta no incluye el origen")

	print("\n=== TEST 2: Rodea un muro ===")
	var m2 := MundoFalso.new()
	_llano(m2, 6, 8)
	for z in range(7):  # muro en x=2, con hueco en z=7
		m2.poner(Vector3i(2, 1, z), "pared")
		m2.poner(Vector3i(2, 2, z), "pared")
	var ruta2: Array[Vector3i] = BuscadorRutas.new(m2).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(not ruta2.is_empty(), "hay ruta por el hueco")
	assert(ruta2.size() > 4, "es más larga que la recta")
	for celda in ruta2:
		assert(m2.obtener_tipo(celda) == "", "no pisa el muro")

	print("\n=== TEST 3: Sube 1 bloque y no sube 2 ===")
	var m3 := MundoFalso.new()  # una sola fila (z=0): sin rodeos posibles
	_llano(m3, 6, 1)
	m3.poner(Vector3i(2, 1, 0), "tierra")
	m3.poner(Vector3i(3, 1, 0), "tierra")
	var ruta3: Array[Vector3i] = BuscadorRutas.new(m3).buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 2, 0))
	assert(ruta3.size() == 3 and ruta3.back() == Vector3i(3, 2, 0), "sube un escalón de 1 bloque")
	var m3b := MundoFalso.new()
	_llano(m3b, 6, 1)
	for y in range(1, 3):  # muro de 2 bloques
		m3b.poner(Vector3i(2, y, 0), "tierra")
		m3b.poner(Vector3i(3, y, 0), "tierra")
	assert(BuscadorRutas.new(m3b).buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 3, 0)).is_empty(), "no sube 2 bloques")

	print("\n=== TEST 4: Cae hasta 3 bloques y no 4 ===")
	var m4 := MundoFalso.new()
	for y in range(0, 4):  # torre de 4 de tierra en x=0: se pisa en y=4
		m4.poner(Vector3i(0, y, 0), "tierra")
	m4.poner(Vector3i(1, 0, 0), "tierra")
	m4.poner(Vector3i(2, 0, 0), "tierra")
	var ruta4: Array[Vector3i] = BuscadorRutas.new(m4).buscar_ruta(Vector3i(0, 4, 0), Vector3i(1, 1, 0))
	assert(ruta4.size() == 1 and ruta4[0] == Vector3i(1, 1, 0), "cae 3 bloques")
	var m4b := MundoFalso.new()
	for y in range(0, 5):  # torre de 5: caída de 4
		m4b.poner(Vector3i(0, y, 0), "tierra")
	m4b.poner(Vector3i(1, 0, 0), "tierra")
	assert(BuscadorRutas.new(m4b).buscar_ruta(Vector3i(0, 5, 0), Vector3i(1, 1, 0)).is_empty(), "no cae 4 bloques")

	print("\n=== TEST 5: Agua de 1 bloque se cruza, de 2 no ===")
	var m5 := MundoFalso.new()
	_llano(m5, 6, 1)
	m5.poner(Vector3i(2, 1, 0), "agua")
	var ruta5: Array[Vector3i] = BuscadorRutas.new(m5).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(ruta5.size() == 4 and ruta5.has(Vector3i(2, 1, 0)), "cruza 1 bloque de agua")
	var m5b := MundoFalso.new()
	_llano(m5b, 6, 1)
	m5b.poner(Vector3i(2, 1, 0), "agua")
	m5b.poner(Vector3i(2, 2, 0), "agua")
	assert(BuscadorRutas.new(m5b).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0)).is_empty(), "no cruza 2 bloques de agua")

	print("\n=== TEST 6: Las puertas se atraviesan ===")
	var m6 := MundoFalso.new()
	_llano(m6, 6, 1)
	m6.poner(Vector3i(2, 1, 0), "puerta_inferior")
	m6.poner(Vector3i(2, 2, 0), "puerta_superior")
	var ruta6: Array[Vector3i] = BuscadorRutas.new(m6).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(ruta6.size() == 4 and ruta6.has(Vector3i(2, 1, 0)), "pasa por la puerta")

	print("\n=== TEST 7: Un colono puede subirse a una cama ===")
	var m7 := MundoFalso.new()
	_llano(m7, 6, 1)
	m7.poner(Vector3i(2, 1, 0), "cama_cabecera")
	m7.poner(Vector3i(3, 1, 0), "cama_pies")
	var ruta7: Array[Vector3i] = BuscadorRutas.new(m7).buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 2, 0))
	assert(not ruta7.is_empty() and ruta7.back() == Vector3i(3, 2, 0), "llega a estar encima de la cama")

	print("\n=== TEST 8: Sin ruta, origen o destino no transitables ===")
	var m8 := MundoFalso.new()
	_llano(m8, 7, 7)
	for x in range(2, 5):  # destino (3,1,3) encerrado por un anillo de paredes
		for z in range(2, 5):
			if not (x == 3 and z == 3):
				m8.poner(Vector3i(x, 1, z), "pared")
				m8.poner(Vector3i(x, 2, z), "pared")
	var b8 := BuscadorRutas.new(m8)
	assert(b8.buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 1, 3)).is_empty(), "destino encerrado")
	assert(b8.buscar_ruta(Vector3i(0, 0, 0), Vector3i(1, 1, 0)).is_empty(), "origen dentro de un bloque sólido")
	assert(b8.buscar_ruta(Vector3i(0, 1, 0), Vector3i(1, 5, 0)).is_empty(), "destino en el aire sin suelo")
	assert(b8.buscar_ruta(Vector3i(0, 1, 0), Vector3i(0, 1, 0)).is_empty(), "origen == destino")

	print("\n=== TEST 9: Tope de nodos expandidos ===")
	var m9 := MundoFalso.new()
	_llano(m9, 30, 30)
	var b9 := BuscadorRutas.new(m9)
	assert(not b9.buscar_ruta(Vector3i(0, 1, 0), Vector3i(29, 1, 29)).is_empty(), "con el tope por defecto llega")
	b9.max_nodos = 5
	assert(b9.buscar_ruta(Vector3i(0, 1, 0), Vector3i(29, 1, 29)).is_empty(), "con un tope de 5 nodos se rinde")

	print("\n=== TEST 10: Determinismo ===")
	var m10 := MundoFalso.new()
	_llano(m10, 10, 10)
	m10.poner(Vector3i(4, 1, 4), "pared")
	m10.poner(Vector3i(4, 2, 4), "pared")
	var b10 := BuscadorRutas.new(m10)
	assert(b10.buscar_ruta(Vector3i(0, 1, 0), Vector3i(9, 1, 9)) == b10.buscar_ruta(Vector3i(0, 1, 0), Vector3i(9, 1, 9)))

	print("\n=== TEST 11: Recalcular cuando una celda de la ruta se vuelve sólida ===")
	var m11 := MundoFalso.new()
	_llano(m11, 6, 2)
	var b11 := BuscadorRutas.new(m11)
	var ruta11: Array[Vector3i] = b11.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(ruta11.has(Vector3i(2, 1, 0)))
	m11.poner(Vector3i(2, 1, 0), "pared")
	m11.poner(Vector3i(2, 2, 0), "pared")
	assert(not b11.es_transitable(Vector3i(2, 1, 0)), "la celda ya no es transitable")
	var nueva11: Array[Vector3i] = b11.buscar_ruta(Vector3i(1, 1, 0), Vector3i(4, 1, 0))
	assert(not nueva11.is_empty() and not nueva11.has(Vector3i(2, 1, 0)), "la nueva ruta la evita (ve el mundo actual)")

	print("\n=== TEST 12: Celdas bloqueadas por otros ===")
	var m12 := MundoFalso.new()
	_llano(m12, 6, 2)
	var b12 := BuscadorRutas.new(m12)
	var bloqueadas12 := {Vector3i(2, 1, 0): true}
	var ruta12: Array[Vector3i] = b12.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"bloqueadas": bloqueadas12})
	assert(not ruta12.is_empty() and not ruta12.has(Vector3i(2, 1, 0)), "esquiva la celda bloqueada")
	assert(b12.buscar_ruta(Vector3i(0, 1, 0), Vector3i(2, 1, 0), {"bloqueadas": bloqueadas12}).is_empty(), "un destino bloqueado no tiene ruta")
	var m12b := MundoFalso.new()
	_llano(m12b, 6, 1)  # una sola fila: bloquear el paso la corta
	assert(BuscadorRutas.new(m12b).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"bloqueadas": bloqueadas12}).is_empty())

	print("\n=== TEST 13: Cada paso es a una celda contigua ===")
	for i in range(1, ruta2.size()):
		assert(_adyacentes(ruta2[i - 1], ruta2[i]), "pasos contiguos")

	print("\n=== TEST 14: Cruce largo en campo abierto con el tope por defecto ===")
	var m14 := MundoFalso.new()
	_llano(m14, 150, 150)
	var t14 := Time.get_ticks_msec()
	var ruta14: Array[Vector3i] = BuscadorRutas.new(m14).buscar_ruta(Vector3i(0, 1, 0), Vector3i(149, 1, 149))
	print("Ruta larga: ", ruta14.size(), " pasos en ", Time.get_ticks_msec() - t14, " ms")
	assert(not ruta14.is_empty(), "la diagonal de 150x150 no agota el tope")
	assert(ruta14.size() == 298 and ruta14.back() == Vector3i(149, 1, 149), "298 pasos hasta el destino")
	for i in range(1, ruta14.size()):
		assert(_adyacentes(ruta14[i - 1], ruta14[i]), "pasos contiguos en el cruce largo")

	print("\n=== TEST 15: Un fantasma solo se atraviesa con el permiso de SU obra ===")
	var m15 := MundoFalso.new()
	_llano(m15, 6, 1)  # una sola fila
	m15.poner_fantasma(Vector3i(2, 1, 0), 7)
	m15.poner_fantasma(Vector3i(2, 2, 0), 7)
	var b15 := BuscadorRutas.new(m15)
	assert(not b15.es_transitable(Vector3i(2, 1, 0)), "sin permiso, un fantasma es sólido")
	assert(b15.es_transitable(Vector3i(2, 1, 0), [7]), "con el permiso de su obra, es libre")
	assert(not b15.es_transitable(Vector3i(2, 1, 0), [8]), "el permiso de otra obra no sirve")
	assert(b15.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0)).is_empty())
	var ruta15: Array[Vector3i] = b15.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"ignorar_fantasmas": [7]})
	assert(ruta15.size() == 4 and ruta15.has(Vector3i(2, 1, 0)), "con permiso cruza la pared fantasma")
	assert(b15.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"ignorar_fantasmas": [8]}).is_empty())

	print("\n=== TEST 16: buscar_salida() lleva desde dentro de la obra hasta la primera celda de fuera ===")
	var m16 := MundoFalso.new()
	_llano(m16, 7, 7)
	for x in range(2, 5):  # un cubo fantasma macizo de 3x3x2
		for z in range(2, 5):
			m16.poner_fantasma(Vector3i(x, 1, z), 7)
			m16.poner_fantasma(Vector3i(x, 2, z), 7)
	var b16 := BuscadorRutas.new(m16)
	var esta_dentro := func(celda: Vector3i) -> bool:
		return celda.x >= 2 and celda.x <= 4 and celda.z >= 2 and celda.z <= 4
	var salida16: Array[Vector3i] = b16.buscar_salida(Vector3i(3, 1, 3), esta_dentro, {"ignorar_fantasmas": [7]})
	print("Ruta de salida: ", salida16)
	assert(salida16.size() == 2, "del centro al borde del cubo y un paso más")
	assert(not esta_dentro.call(salida16.back()), "termina fuera del volumen")
	assert(b16.buscar_salida(Vector3i(3, 1, 3), esta_dentro).is_empty(), "sin permiso, el origen es un sólido: no hay ruta")

	print("\n=== TEST 17: Si el origen ya está fuera, no hay nada que recorrer ===")
	assert(b16.buscar_salida(Vector3i(0, 1, 0), esta_dentro).is_empty())

	print("\n=== Las 17 pruebas de BuscadorRutas pasaron correctamente ===")
