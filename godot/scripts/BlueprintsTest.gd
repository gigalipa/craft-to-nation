extends Node

## Pruebas aisladas de Blueprints.gd (mismo patrón que RecoleccionTest.gd).
## Corre esta escena (BlueprintsTest.tscn) con F6 en el editor de Godot y
## revisa el panel "Output": debe imprimir las pruebas y no debe lanzar
## ningún error de assert().


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: obtener() sin nada guardado devuelve {} ===")
	assert(Blueprints.obtener("residencial_investigacion") == {})

	print("\n=== TEST 2: guardar() registra el blueprint por su zona_permitida ===")
	var bp_a := {"zona_permitida": "residencial_investigacion", "nombre": "A"}
	Blueprints.guardar(bp_a)
	assert(Blueprints.obtener("residencial_investigacion") == bp_a)

	print("\n=== TEST 3: guardar() de la misma zona sobrescribe al anterior ===")
	var bp_b := {"zona_permitida": "residencial_investigacion", "nombre": "B"}
	Blueprints.guardar(bp_b)
	assert(Blueprints.obtener("residencial_investigacion") == bp_b)

	print("\n=== TEST 4: zonas distintas no se pisan entre sí ===")
	var bp_militar := {"zona_permitida": "fabricacion_militar", "nombre": "C"}
	Blueprints.guardar(bp_militar)
	assert(Blueprints.obtener("residencial_investigacion") == bp_b)
	assert(Blueprints.obtener("fabricacion_militar") == bp_militar)

	print("\n=== TEST 5: memoria de hasta 5 blueprints residenciales (FIFO / más reciente primero) ===")
	Blueprints.limpiar()
	var bps: Array = []
	for i in range(6):
		bps.append({"zona_permitida": "residencial_investigacion", "nombre": "Casa %d" % (i + 1)})
		Blueprints.guardar(bps[i])

	assert(Blueprints.cantidad_residenciales() == 5, "máximo 5 residenciales")
	assert(Blueprints.obtener_residencial(0) == bps[5], "el 6to ingresado es el 1º (1-1-1)")
	assert(Blueprints.obtener_residencial(1) == bps[4], "el 5to es el 2º (1-1-2)")
	assert(Blueprints.obtener_residencial(2) == bps[3], "el 4to es el 3º (1-1-3)")
	assert(Blueprints.obtener_residencial(3) == bps[2], "el 3ro es el 4º (1-1-4)")
	assert(Blueprints.obtener_residencial(4) == bps[1], "el 2do es el 5º (1-1-5)")
	assert(not Blueprints.todos_residenciales().has(bps[0]), "el 1ro fue eliminado al entrar el 6to")

	print("\n=== Las 5 pruebas de Blueprints pasaron correctamente ===")
