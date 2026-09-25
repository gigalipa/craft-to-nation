extends Node

## Pruebas aisladas de la señal VoxelWorld.puerta_cambiada y de Puertas.gd
## (mismo patrón que TranslucidosRendererTest.gd). Corre esta escena
## (PuertasTest.tscn) y revisa el panel "Output": debe imprimir todas las
## pruebas y no lanzar ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md.

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")


func _ready() -> void:
	ejecutar_pruebas()


func _mundo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	return mundo


func ejecutar_pruebas() -> void:
	print("=== TEST 1: puerta_cambiada se emite solo para celdas de puerta ===")
	var mundo: Node = _mundo()
	var emitidas: Array[Vector3i] = []
	mundo.puerta_cambiada.connect(func(celda: Vector3i) -> void:
		emitidas.append(celda)
	)
	var base := Vector3i(0, 0, 0)
	var arriba := Vector3i(0, 1, 0)

	# Una pared no emite.
	mundo.colocar_bloque(Vector3i(5, 0, 0), "pared", true)
	assert(emitidas.is_empty(), "colocar una pared no debe emitir puerta_cambiada")

	# colocar_puerta(): emite las dos celdas, inferior primero.
	assert(mundo.colocar_puerta(base))
	assert(emitidas == [base, arriba], "colocar_puerta() debe emitir base y luego arriba, salió %s" % [emitidas])

	# Minar una de las dos celdas retira las dos y emite las dos.
	emitidas.clear()
	assert(mundo.minar_bloque(base))
	assert(emitidas.has(base) and emitidas.has(arriba), "minar una puerta debe emitir ambas celdas, salió %s" % [emitidas])

	# _revertir_celda(): la celda pasa a fantasma y emite.
	assert(mundo.colocar_puerta(base))
	emitidas.clear()
	mundo._revertir_celda(base)
	assert(emitidas == [base], "revertir a fantasma una celda de puerta debe emitirla, salió %s" % [emitidas])

	# Las celdas de puerta ya no dibujan ni colisionan por GridMap.
	var id_puerta: int = mundo.id_de_tipo("puerta_inferior")
	assert(mundo.mesh_library.get_item_mesh(id_puerta) == null, "el ítem de puerta no debe tener malla")
	assert(mundo.mesh_library.get_item_shapes(id_puerta).is_empty(), "el ítem de puerta no debe tener formas")

	print("OK: puerta_cambiada() se emite exactamente cuando una celda de puerta entra o sale.")
	mundo.free()

	print("\n=== Las pruebas de puertas pasaron correctamente ===")
