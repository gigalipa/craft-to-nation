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

	print("\n=== TEST 3: _cara_visible() oculta la cara contra el MISMO tipo translúcido y contra cualquier bloque SÓLIDO ===")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua") == false)
	assert(TranslucidosRendererScript._cara_visible("ventana", "ventana") == false)
	assert(TranslucidosRendererScript._cara_visible("agua", "pared") == false, "un vecino sólido ya cubre esa unión con su propia cara opaca — dibujar la del agua ahí solo produce z-fighting")
	assert(TranslucidosRendererScript._cara_visible("ventana", "piedra") == false)
	assert(TranslucidosRendererScript._cara_visible("agua", "") == true)
	assert(TranslucidosRendererScript._cara_visible("ventana", "") == true)
	assert(TranslucidosRendererScript._cara_visible("agua", "ventana") == true, "dos tipos translúcidos DISTINTOS no tienen geometría opaca que reemplace la cara — sí se dibuja")
	print("OK: _cara_visible() oculta agua-agua, ventana-ventana, y cualquier cara contra un sólido; solo se dibuja contra aire o un tipo translúcido distinto.")

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

	print("\n=== TEST 5: reconstruir_todo() omite la cara compartida entre dos celdas de agua adyacentes ===")
	var mundo_t5: Node = VoxelWorld.new()
	mundo_t5.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t5.cell_size = Vector3.ONE * 1.0
	mundo_t5._indexar_biblioteca()
	mundo_t5.colocar_bloque(Vector3i(0, 0, 0), "agua")
	mundo_t5.colocar_bloque(Vector3i(1, 0, 0), "agua")
	var render_t5: Node3D = TranslucidosRendererScript.new()
	render_t5.voxel_world = mundo_t5
	render_t5._indexar_materiales()
	render_t5.reconstruir_todo()
	# Dos celdas de agua sueltas, cada una expone 5 caras (todas menos la que
	# comparten entre sí) = 10 caras = 20 triángulos = 60 vértices (sin
	# indexar, cada cara agrega sus propios 6 vértices — ver _agregar_cara()).
	var chunk_t5: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var instancia_t5: MeshInstance3D = render_t5._mesh_por_chunk["agua"][chunk_t5]
	var conteo_vertices_t5: int = instancia_t5.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t5 == 10 * 6, "dos celdas de agua adyacentes deben exponer 10 caras (60 vértices), no 12 (72)")
	print("OK: reconstruir_todo() omite exactamente la cara compartida entre dos celdas de agua adyacentes.")

	print("\n=== TEST 6: una celda de agua junto a un bloque sólido OMITE esa cara (la pared ya la cubre, evita z-fighting) ===")
	var mundo_t6: Node = VoxelWorld.new()
	mundo_t6.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t6.cell_size = Vector3.ONE * 1.0
	mundo_t6._indexar_biblioteca()
	mundo_t6.colocar_bloque(Vector3i(0, 0, 0), "agua")
	mundo_t6.colocar_bloque(Vector3i(1, 0, 0), "pared", true)
	var render_t6: Node3D = TranslucidosRendererScript.new()
	render_t6.voxel_world = mundo_t6
	render_t6._indexar_materiales()
	render_t6.reconstruir_todo()
	var chunk_t6: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var instancia_t6: MeshInstance3D = render_t6._mesh_por_chunk["agua"][chunk_t6]
	var conteo_vertices_t6: int = instancia_t6.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t6 == 5 * 6, "una celda de agua junto a un sólido debe exponer solo 5 caras (omite la que comparte con la pared)")
	# El único bloque "agua" de este chunk está en la celda (0,0,0), que por
	# convención (misma que CamaraCenital.gd/ZonaOverlay.gd: DESF := 0.5
	# recentra la esquina al centro) ocupa el rango de mundo [0,1] en cada
	# eje — NO [-0.5, 0.5]. Esto pin-ea la POSICIÓN real de la geometría, no
	# solo su conteo: un desfase global de media celda (el bug real que
	# motivó el fix anterior) no cambia el conteo de vértices pero sí los
	# saca de este rango.
	var vertices_t6: PackedVector3Array = instancia_t6.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v: Vector3 in vertices_t6:
		assert(v.x >= 0.0 and v.x <= 1.0 and v.y >= 0.0 and v.y <= 1.0 and v.z >= 0.0 and v.z <= 1.0, "cada vértice de la celda de agua (0,0,0) debe caer en [0,1] por eje, dio %s" % v)
	print("OK: una celda de agua junto a un bloque sólido omite la cara compartida (5 caras, no 6), en el rango de mundo correcto (celda N ocupa [N, N+1]).")

	print("\n=== TEST 7: la reconstrucción incremental (señal) converge al mismo resultado que reconstruir_todo() ===")
	var mundo_t7: Node = VoxelWorld.new()
	mundo_t7.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t7.cell_size = Vector3.ONE * 1.0
	mundo_t7._indexar_biblioteca()
	var render_t7: Node3D = TranslucidosRendererScript.new()
	render_t7.voxel_world = mundo_t7
	render_t7._indexar_materiales()
	mundo_t7.bloque_translucido_cambiado.connect(render_t7._on_bloque_translucido_cambiado)
	mundo_t7.colocar_bloque(Vector3i(0, 0, 0), "agua")  # dispara la señal -> marca chunk sucio
	mundo_t7.colocar_bloque(Vector3i(1, 0, 0), "agua")  # dispara la señal de nuevo, mismo chunk
	# La reconstrucción ya no es síncrona dentro del handler de la señal (ver
	# _on_bloque_translucido_cambiado()/flush_pendientes() — se agrupan los
	# chunks sucios y se reconstruyen juntos). En juego real esto lo dispara
	# _process(); aquí, fuera del árbol, se fuerza explícitamente.
	render_t7.flush_pendientes()
	var chunk_t7: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var conteo_incremental_t7: int = render_t7._mesh_por_chunk["agua"][chunk_t7].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_incremental_t7 == 10 * 6, "el camino incremental debe dar el mismo resultado que reconstruir_todo() (TEST 5) para el mismo estado final")
	print("OK: colocar bloques uno a uno vía señal converge exactamente al mismo resultado que reconstruir_todo().")

	print("\n=== Las pruebas de TranslucidosRenderer pasaron correctamente ===")
