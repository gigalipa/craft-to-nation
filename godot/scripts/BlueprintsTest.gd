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

	print("\n=== Las 4 pruebas de Blueprints pasaron correctamente ===")
