extends Node

## Pruebas aisladas de GeneradorArbol.gd (mismo patrón que
## GeneradorMundoTest.gd). Corre esta escena (GeneradorArbolTest.tscn) con
## F6 en el editor de Godot y revisa el panel "Output": debe imprimir
## todas las pruebas y no debe lanzar ningún error de assert().

const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: generar_forma_aleatoria es determinista para la misma semilla ===")
	var gen_a: RefCounted = GeneradorArbolScript.new()
	var gen_b: RefCounted = GeneradorArbolScript.new()
	var forma_a: Dictionary = gen_a.generar_forma_aleatoria(123)
	var forma_b: Dictionary = gen_b.generar_forma_aleatoria(123)
	assert(forma_a.size() == forma_b.size())
	for offset in forma_a:
		assert(forma_b.has(offset))
		assert(forma_a[offset] == forma_b[offset])
	print("OK: la misma semilla_arbol produce exactamente los mismos offsets y tipos.")

	print("\n=== TEST 2: todo offset 'tronco' respeta el rango de altura y el cuadrado de lado ===")
	var gen_rango: RefCounted = GeneradorArbolScript.new()
	for semilla in [1, 2, 3, 42, 999]:
		var forma: Dictionary = gen_rango.generar_forma_aleatoria(semilla)
		var altura_recuperada := 0
		var lado_recuperado := 0
		for offset in forma:
			if forma[offset] == "tronco":
				altura_recuperada = max(altura_recuperada, offset.y + 1)
				lado_recuperado = max(lado_recuperado, offset.x + 1)
				lado_recuperado = max(lado_recuperado, offset.z + 1)
		assert(altura_recuperada >= GeneradorArbolScript.ALTURA_TRONCO_MIN)
		assert(altura_recuperada <= GeneradorArbolScript.ALTURA_TRONCO_MAX)
		assert(lado_recuperado >= GeneradorArbolScript.LADO_TRONCO_MIN)
		assert(lado_recuperado <= GeneradorArbolScript.LADO_TRONCO_MAX)
		for offset in forma:
			if forma[offset] == "tronco":
				assert(offset.y >= 0 and offset.y < altura_recuperada)
				assert(offset.x >= 0 and offset.x < lado_recuperado)
				assert(offset.z >= 0 and offset.z < lado_recuperado)
	print("OK: la altura y el lado recuperados de las celdas 'tronco' quedan dentro de los rangos configurados, y ninguna celda 'tronco' cae fuera de su propio cuadrado/altura.")

	print("\n=== TEST 3: el follaje nunca sobrescribe una celda de tronco ===")
	var gen_solape: RefCounted = GeneradorArbolScript.new()
	var forma_solape: Dictionary = gen_solape.generar_forma_aleatoria(7)
	var altura_solape := 0
	var lado_solape := 0
	for offset in forma_solape:
		if forma_solape[offset] == "tronco":
			altura_solape = max(altura_solape, offset.y + 1)
			lado_solape = max(lado_solape, offset.x + 1)
			lado_solape = max(lado_solape, offset.z + 1)
	for y in range(altura_solape):
		for dx in range(lado_solape):
			for dz in range(lado_solape):
				var celda := Vector3i(dx, y, dz)
				assert(forma_solape.get(celda, "") == "tronco")
	print("OK: toda celda dentro del cuadrado/altura del tronco quedó marcada 'tronco', incluso donde el follaje podría solaparse.")

	print("\n=== TEST 4: registrar/obtener_arbol_de/celdas_de son consistentes ===")
	var gen_reg: RefCounted = GeneradorArbolScript.new()
	var celdas_1: Array = [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0)]
	var id_1: int = gen_reg.registrar(celdas_1, 2)
	var celdas_2: Array = [Vector3i(10, 0, 10), Vector3i(10, 1, 10)]
	var id_2: int = gen_reg.registrar(celdas_2, 2)
	assert(id_1 != id_2)
	for celda in celdas_1:
		assert(gen_reg.obtener_arbol_de(celda) == id_1)
	for celda in celdas_2:
		assert(gen_reg.obtener_arbol_de(celda) == id_2)
	assert(gen_reg.celdas_de(id_1) == celdas_1)
	assert(gen_reg.celdas_de(id_2) == celdas_2)
	print("OK: cada celda registrada devuelve el id correcto, y celdas_de() devuelve exactamente el conjunto original.")

	print("\n=== TEST 5: obtener_arbol_de devuelve -1 para una celda nunca registrada ===")
	assert(gen_reg.obtener_arbol_de(Vector3i(999, 999, 999)) == -1)
	print("OK: una celda que nunca fue registrada devuelve -1.")

	print("\n=== TEST 6: danar reduce la salud y solo devuelve true al agotarla ===")
	var gen_danio: RefCounted = GeneradorArbolScript.new()
	var id_danio: int = gen_danio.registrar([Vector3i(5, 0, 5)], 5)
	assert(gen_danio.danar(id_danio, 2) == false)
	assert(gen_danio.danar(id_danio, 2) == false)
	assert(gen_danio.danar(id_danio, 2) == true)
	print("OK: un árbol de salud 5 sigue en pie tras 2+2 de daño, y queda talado al recibir el tercer golpe de 2 (acumulado 6 >= 5).")

	print("\n=== TEST 7: danar con daño mayor a la salud restante talan de inmediato ===")
	var gen_danio_grande: RefCounted = GeneradorArbolScript.new()
	var id_grande: int = gen_danio_grande.registrar([Vector3i(6, 0, 6)], 3)
	assert(gen_danio_grande.danar(id_grande, 10) == true)
	print("OK: un daño mayor a la salud restante tala el árbol en un solo golpe.")

	print("\n=== TEST 8: eliminar limpia el registro por completo ===")
	var gen_elim: RefCounted = GeneradorArbolScript.new()
	var celdas_elim: Array = [Vector3i(7, 0, 7), Vector3i(7, 1, 7)]
	var id_elim: int = gen_elim.registrar(celdas_elim, 2)
	gen_elim.eliminar(id_elim)
	for celda in celdas_elim:
		assert(gen_elim.obtener_arbol_de(celda) == -1)
	assert(gen_elim.celdas_de(id_elim) == [])
	print("OK: tras eliminar, ninguna de sus celdas ni su id siguen en el registro.")

	print("\n=== TEST 9: medir_pisada coincide con la forma que generar_forma_aleatoria produciría para la misma semilla ===")
	var gen_medida: RefCounted = GeneradorArbolScript.new()
	for semilla in [1, 2, 3, 42, 999, 123456]:
		var medida: Dictionary = gen_medida.medir_pisada(semilla)
		var forma: Dictionary = gen_medida.generar_forma_aleatoria(semilla)
		var altura_recuperada := 0
		var lado_recuperado := 0
		for offset in forma:
			if forma[offset] == "tronco":
				altura_recuperada = max(altura_recuperada, offset.y + 1)
				lado_recuperado = max(lado_recuperado, offset.x + 1)
				lado_recuperado = max(lado_recuperado, offset.z + 1)
		assert(medida["altura_tronco"] == altura_recuperada)
		assert(medida["lado_tronco"] == lado_recuperado)
	print("OK: medir_pisada() predice exactamente la altura y el lado de tronco que generar_forma_aleatoria() produce para la misma semilla.")

	print("\n=== Las 9 pruebas de GeneradorArbol pasaron correctamente ===")
