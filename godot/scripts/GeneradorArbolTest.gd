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

	print("\n=== TEST 2: todo offset 'tronco' respeta el rango de altura y el disco de radio ===")
	var gen_rango: RefCounted = GeneradorArbolScript.new()
	for semilla in [1, 2, 3, 42, 999]:
		var forma: Dictionary = gen_rango.generar_forma_aleatoria(semilla)
		var altura_recuperada := 0
		var radio_recuperado := 0
		for offset in forma:
			if forma[offset] == "tronco":
				altura_recuperada = max(altura_recuperada, offset.y + 1)
				if offset.z == 0 and offset.x >= 0:
					radio_recuperado = max(radio_recuperado, offset.x)
		assert(altura_recuperada >= GeneradorArbolScript.ALTURA_TRONCO_MIN)
		assert(altura_recuperada <= GeneradorArbolScript.ALTURA_TRONCO_MAX)
		assert(radio_recuperado >= GeneradorArbolScript.RADIO_TRONCO_MIN)
		assert(radio_recuperado <= GeneradorArbolScript.RADIO_TRONCO_MAX)
		for offset in forma:
			if forma[offset] == "tronco":
				assert(offset.y >= 0 and offset.y < altura_recuperada)
				assert(offset.x * offset.x + offset.z * offset.z <= radio_recuperado * radio_recuperado)
	print("OK: la altura y el radio recuperados de las celdas 'tronco' quedan dentro de los rangos configurados, y ninguna celda 'tronco' cae fuera de su propio disco/altura.")

	print("\n=== TEST 3: el follaje nunca sobrescribe una celda de tronco ===")
	var gen_solape: RefCounted = GeneradorArbolScript.new()
	var forma_solape: Dictionary = gen_solape.generar_forma_aleatoria(7)
	var altura_solape := 0
	var radio_solape := 0
	for offset in forma_solape:
		if forma_solape[offset] == "tronco":
			altura_solape = max(altura_solape, offset.y + 1)
			if offset.z == 0 and offset.x >= 0:
				radio_solape = max(radio_solape, offset.x)
	for y in range(altura_solape):
		for dx in range(-radio_solape, radio_solape + 1):
			for dz in range(-radio_solape, radio_solape + 1):
				if dx * dx + dz * dz <= radio_solape * radio_solape:
					var celda := Vector3i(dx, y, dz)
					assert(forma_solape.get(celda, "") == "tronco")
	print("OK: toda celda dentro del disco/altura del tronco quedó marcada 'tronco', incluso donde el follaje podría solaparse.")

	print("\n=== Las 3 pruebas de GeneradorArbol pasaron correctamente ===")
