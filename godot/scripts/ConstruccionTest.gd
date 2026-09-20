extends Node

## Pruebas aisladas de Construccion.gd (mismo patrón que
## RecoleccionTest.gd). Corre esta escena (ConstruccionTest.tscn) con F6 en
## el editor de Godot y revisa el panel "Output": debe imprimir las
## pruebas y no debe lanzar ningún error de assert().


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: iniciar() registra todas las celdas de la construcción ===")
	var orden: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	var tipos := {
		Vector3i(0, 0, 0): "tierra",
		Vector3i(1, 0, 0): "piso",
		Vector3i(2, 0, 0): "pared",
	}
	var id: int = Construccion.iniciar(orden, tipos)
	for celda in orden:
		assert(Construccion.construccion_de(celda) == id)
	assert(Construccion.construccion_de(Vector3i(99, 99, 99)) == -1)

	print("\n=== TEST 2: avanzar() convierte la PRIMERA celda pendiente, en orden ===")
	var r1: Dictionary = Construccion.avanzar(id)
	assert(r1["celda"] == Vector3i(0, 0, 0))
	assert(r1["tipo"] == "tierra")
	assert(not r1["completa"])
	var r2: Dictionary = Construccion.avanzar(id)
	assert(r2["celda"] == Vector3i(1, 0, 0))
	assert(r2["tipo"] == "piso")
	assert(not r2["completa"])

	print("\n=== TEST 3: la última celda marca completa=true y limpia el registro ===")
	var r3: Dictionary = Construccion.avanzar(id)
	assert(r3["celda"] == Vector3i(2, 0, 0))
	assert(r3["tipo"] == "pared")
	assert(r3["completa"])
	assert(r3["orden"] == orden)
	for celda in orden:
		assert(Construccion.construccion_de(celda) == -1)

	print("\n=== TEST 4: avanzar() sobre un id ya completado o inexistente devuelve {} ===")
	assert(Construccion.avanzar(id) == {})
	assert(Construccion.avanzar(9999) == {})

	print("\n=== TEST 5: metadata se guarda intacta y se devuelve en cada avanzar() ===")
	var metadata := {"blueprint": {"nombre": "X"}, "esquina": Vector2i(5, 5)}
	var id2: int = Construccion.iniciar([Vector3i(10, 0, 0)], {Vector3i(10, 0, 0): "piso"}, metadata)
	var r4: Dictionary = Construccion.avanzar(id2)
	assert(r4["metadata"] == metadata)
	assert(r4["completa"])

	print("\n=== TEST 6: celdas_pendientes() devuelve las celdas aún no avanzadas, en orden ===")
	var celdas_6: Array[Vector3i] = [Vector3i(20, 0, 0), Vector3i(21, 0, 0), Vector3i(22, 0, 0)]
	var tipos_6 := {celdas_6[0]: "tierra", celdas_6[1]: "tierra", celdas_6[2]: "tierra"}
	var id_6: int = Construccion.iniciar(celdas_6, tipos_6)
	assert(Construccion.celdas_pendientes(id_6).size() == 3)
	Construccion.avanzar(id_6)
	var pendientes_6: Array[Vector3i] = Construccion.celdas_pendientes(id_6)
	assert(pendientes_6.size() == 2 and pendientes_6[0] == celdas_6[1] and pendientes_6[1] == celdas_6[2])
	assert(Construccion.celdas_pendientes(999999).is_empty(), "un id inexistente no tiene pendientes")

	print("\n=== Las 6 pruebas de Construccion pasaron correctamente ===")
