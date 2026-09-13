extends Node

## Pruebas aisladas de la señal VoxelWorld.bloque_translucido_cambiado y de
## TranslucidosRenderer (mismo patrón que GeneradorMundoTest.gd/
## BlueprintValidatorTest.gd). Corre esta escena (TranslucidosRendererTest.tscn)
## con F6 en el editor de Godot y revisa el panel "Output": debe imprimir
## todas las pruebas y no debe lanzar ningún error de assert().
## Ver docs/superpowers/specs/2026-09-13-culling-caras-translucidas-design.md.

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const TranslucidosRendererScript = preload("res://scripts/TranslucidosRenderer.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: bloque_translucido_cambiado() se emite solo para cambios que involucran un tipo translúcido ===")
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()

	var celdas_emitidas: Array[Vector3i] = []
	mundo.bloque_translucido_cambiado.connect(func(celda: Vector3i) -> void:
		celdas_emitidas.append(celda)
	)

	# Colocar un bloque sólido (pared): NO debe emitir.
	mundo.colocar_bloque(Vector3i(0, 0, 0), "pared", true)
	assert(celdas_emitidas.is_empty(), "colocar un bloque sólido no debe emitir la señal")

	# Colocar agua: SÍ debe emitir.
	mundo.colocar_bloque(Vector3i(1, 0, 0), "agua")
	assert(celdas_emitidas == [Vector3i(1, 0, 0)], "colocar agua debe emitir exactamente esa celda")

	# Sustituir esa agua por piedra: SÍ debe emitir (el tipo ANTERIOR era translúcido).
	celdas_emitidas.clear()
	mundo.colocar_bloque(Vector3i(1, 0, 0), "piedra")
	assert(celdas_emitidas == [Vector3i(1, 0, 0)], "sustituir agua por un tipo no translúcido debe emitir igual")

	# Colocar una ventana y minarla: ambos deben emitir.
	celdas_emitidas.clear()
	mundo.colocar_bloque(Vector3i(2, 0, 0), "ventana", true)
	assert(celdas_emitidas == [Vector3i(2, 0, 0)], "colocar una ventana debe emitir")
	celdas_emitidas.clear()
	mundo.minar_bloque(Vector3i(2, 0, 0))
	assert(celdas_emitidas == [Vector3i(2, 0, 0)], "minar una ventana debe emitir")

	# Minar un bloque no translúcido: NO debe emitir.
	celdas_emitidas.clear()
	mundo.minar_bloque(Vector3i(0, 0, 0))
	assert(celdas_emitidas.is_empty(), "minar un bloque sólido no debe emitir la señal")

	# drenar_agua(): cada celda de agua reemplazada debe emitir.
	mundo.colocar_bloque(Vector3i(3, 0, 0), "tierra")
	mundo.colocar_bloque(Vector3i(3, 1, 0), "agua")
	mundo.colocar_bloque(Vector3i(3, 2, 0), "agua")
	celdas_emitidas.clear()
	var reemplazados: int = mundo.drenar_agua(3, 0)
	assert(reemplazados == 2)
	assert(celdas_emitidas == [Vector3i(3, 1, 0), Vector3i(3, 2, 0)], "drenar_agua() debe emitir cada celda reemplazada, en orden")

	print("OK: bloque_translucido_cambiado() se emite exactamente cuando un tipo translúcido entra o sale de una celda.")

	print("\n=== TEST 2: _chunk_de() agrupa por chunks de CHUNK_SIZE, con división de piso real ===")
	const CS := TranslucidosRendererScript.CHUNK_SIZE
	assert(TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0)) == Vector3i(0, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(CS - 1, CS - 1, CS - 1)) == Vector3i(0, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(CS, 0, 0)) == Vector3i(1, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(-1, 0, 0)) == Vector3i(-1, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(-CS, 0, 0)) == Vector3i(-1, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(-CS - 1, 0, 0)) == Vector3i(-2, 0, 0))
	print("OK: _chunk_de() da la misma clave dentro de un chunk, cambia al cruzar el borde, y respeta coordenadas negativas.")

	print("\n=== TEST 3: _cara_visible() solo oculta la cara entre dos celdas del MISMO tipo translúcido ===")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua") == false)
	assert(TranslucidosRendererScript._cara_visible("ventana", "ventana") == false)
	assert(TranslucidosRendererScript._cara_visible("agua", "") == true)
	assert(TranslucidosRendererScript._cara_visible("agua", "ventana") == true)
	assert(TranslucidosRendererScript._cara_visible("agua", "pared") == true)
	assert(TranslucidosRendererScript._cara_visible("ventana", "") == true)
	print("OK: _cara_visible() oculta agua-agua y ventana-ventana; cualquier otra combinación se dibuja.")

	print("\n=== TEST 4: _esquinas_cara() da 4 esquinas en sentido CCW visto desde la dirección de la cara ===")
	for direccion: Vector3i in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]:
		var esquinas: Array[Vector3] = TranslucidosRendererScript._esquinas_cara(Vector3.ZERO, direccion)
		assert(esquinas.size() == 4)
		var arista1: Vector3 = esquinas[1] - esquinas[0]
		var arista2: Vector3 = esquinas[2] - esquinas[0]
		var normal_calculada: Vector3 = arista1.cross(arista2).normalized()
		var normal_esperada := Vector3(direccion.x, direccion.y, direccion.z)
		assert(normal_calculada.is_equal_approx(normal_esperada), "la cara en dirección %s debe tener normal %s, dio %s" % [direccion, normal_esperada, normal_calculada])
		for esquina in esquinas:
			assert(absf(esquina.dot(normal_esperada) - 0.5) < 0.0001, "cada esquina debe quedar en la cara del cubo unitario, a 0.5 de distancia en la dirección de la normal")
	print("OK: las 4 esquinas de cada una de las 6 caras quedan en sentido CCW visto desde su dirección, sobre la superficie del cubo unitario.")

	print("\n=== Las pruebas de TranslucidosRenderer pasaron correctamente ===")
