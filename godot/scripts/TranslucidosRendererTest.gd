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

	print("\n=== TEST 3: _cara_visible() — sólido siempre oculta; agua solo dibuja ARRIBA; otros tipos (ventana) solo ocultan contra el mismo tipo ===")
	const ARRIBA_T3 := Vector3i(0, 1, 0)
	const ABAJO_T3 := Vector3i(0, -1, 0)
	const LATERAL_T3 := Vector3i(1, 0, 0)
	# Regla 1: un vecino sólido oculta SIEMPRE, sin excepción — incluida la
	# cara de arriba del agua.
	assert(TranslucidosRendererScript._cara_visible("agua", "pared", ARRIBA_T3) == false, "un vecino sólido oculta incluso la cara de arriba del agua — evita reintroducir el z-fighting")
	assert(TranslucidosRendererScript._cara_visible("agua", "pared", LATERAL_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("ventana", "piedra", LATERAL_T3) == false)
	# Regla 2 (agua): solo depende de la DIRECCIÓN, nunca del vecino, una vez
	# descartado el caso sólido de la regla 1.
	assert(TranslucidosRendererScript._cara_visible("agua", "", ARRIBA_T3) == true, "arriba contra aire: se dibuja")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua", ARRIBA_T3) == true, "arriba contra OTRA celda de agua: se dibuja igual — así se apilan capas reales con la profundidad")
	assert(TranslucidosRendererScript._cara_visible("agua", "ventana", ARRIBA_T3) == true, "arriba contra un tipo translúcido distinto: se dibuja igual")
	assert(TranslucidosRendererScript._cara_visible("agua", "", ABAJO_T3) == false, "abajo NUNCA se dibuja, ni siquiera contra aire")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua", ABAJO_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("agua", "", LATERAL_T3) == false, "laterales NUNCA se dibujan, ni siquiera contra aire")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua", LATERAL_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("agua", "ventana", LATERAL_T3) == false)
	# Regla 3 (cualquier otro tipo translúcido, p. ej. ventana): la regla
	# original — se omite solo contra el MISMO tipo, sin importar dirección.
	assert(TranslucidosRendererScript._cara_visible("ventana", "ventana", ARRIBA_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("ventana", "ventana", LATERAL_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("ventana", "", LATERAL_T3) == true)
	assert(TranslucidosRendererScript._cara_visible("ventana", "agua", LATERAL_T3) == true, "ventana contra un tipo translúcido distinto (agua): se dibuja")
	print("OK: sólido oculta siempre; agua solo dibuja su cara de arriba (incluso contra otra agua); ventana conserva la regla original (solo oculta contra el mismo tipo).")

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

	print("\n=== TEST 5: dos celdas de agua adyacentes horizontalmente solo muestran su cara de ARRIBA cada una (nunca la lateral compartida) ===")
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
	# Cada celda de agua solo dibuja su cara de ARRIBA (contra aire, ninguna
	# es sólida) — 1 cara x 6 vértices x 2 celdas = 12 vértices. Ninguna cara
	# lateral ni inferior se dibuja nunca para agua, compartida o no.
	var chunk_t5: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var instancia_t5: MeshInstance3D = render_t5._mesh_por_chunk["agua"][chunk_t5]
	var conteo_vertices_t5: int = instancia_t5.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t5 == 2 * 6, "dos celdas de agua solo deben exponer su cara de arriba cada una (12 vértices)")
	print("OK: cada celda de agua expone únicamente su cara de arriba; las laterales (compartida o no) nunca se dibujan.")

	print("\n=== TEST 6: un sólido justo ENCIMA del agua elimina también su cara de arriba (evita reintroducir z-fighting) ===")
	var mundo_t6: Node = VoxelWorld.new()
	mundo_t6.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t6.cell_size = Vector3.ONE * 1.0
	mundo_t6._indexar_biblioteca()
	mundo_t6.colocar_bloque(Vector3i(0, 0, 0), "agua")
	mundo_t6.colocar_bloque(Vector3i(0, 1, 0), "pared", true)  # sólido justo encima
	mundo_t6.colocar_bloque(Vector3i(1, 0, 0), "pared", true)  # sólido lateral (ya irrelevante: lateral nunca se dibuja)
	var render_t6: Node3D = TranslucidosRendererScript.new()
	render_t6.voxel_world = mundo_t6
	render_t6._indexar_materiales()
	render_t6.reconstruir_todo()
	var chunk_t6: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	assert(not render_t6._mesh_por_chunk.get("agua", {}).has(chunk_t6), "sin ninguna cara visible (arriba tapada por el sólido, laterales/abajo siempre ocultas), el chunk de agua no debe tener malla")
	print("OK: un sólido justo encima del agua elimina su única cara posible (arriba); el chunk queda sin malla de agua.")

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
	assert(conteo_incremental_t7 == 2 * 6, "el camino incremental debe dar el mismo resultado que reconstruir_todo() (TEST 5) para el mismo estado final")
	print("OK: colocar bloques uno a uno vía señal converge exactamente al mismo resultado que reconstruir_todo().")

	print("\n=== TEST 8: una columna de agua apila una cara de arriba REAL por cada celda — más profundidad, más caras superpuestas ===")
	var mundo_t8: Node = VoxelWorld.new()
	mundo_t8.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t8.cell_size = Vector3.ONE * 1.0
	mundo_t8._indexar_biblioteca()
	# 3 celdas de agua apiladas, sin nada más en la columna: cada una tiene
	# "arriba" libre (agua u aire, nunca sólido), así que las 3 dibujan su
	# propia cara de arriba — 3 capas reales superpuestas a distinta altura,
	# no coincidentes (sin z-fighting), que el alpha blend combina al mirar
	# desde arriba dando la impresión de mayor opacidad con la profundidad.
	mundo_t8.colocar_bloque(Vector3i(0, 0, 0), "agua")
	mundo_t8.colocar_bloque(Vector3i(0, 1, 0), "agua")
	mundo_t8.colocar_bloque(Vector3i(0, 2, 0), "agua")
	var render_t8: Node3D = TranslucidosRendererScript.new()
	render_t8.voxel_world = mundo_t8
	render_t8._indexar_materiales()
	render_t8.reconstruir_todo()
	var chunk_t8: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var conteo_vertices_t8: int = render_t8._mesh_por_chunk["agua"][chunk_t8].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t8 == 3 * 6, "una columna de 3 celdas de agua debe dibujar 3 caras de arriba reales (18 vértices), una por celda")

	# Tapar la celda superior con un sólido elimina SOLO esa cara de arriba
	# (regla 1 tiene prioridad) — las otras dos siguen intactas.
	mundo_t8.colocar_bloque(Vector3i(0, 3, 0), "pared", true)
	render_t8.reconstruir_todo()
	var conteo_vertices_t8b: int = render_t8._mesh_por_chunk["agua"][chunk_t8].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t8b == 2 * 6, "tapar la celda superior con un sólido debe quitar únicamente su cara de arriba, dejando 2 caras (12 vértices)")
	print("OK: cada celda de una columna de agua apila su propia cara de arriba real (más profundidad = más capas), y un sólido encima solo quita la cara de esa celda puntual.")

	print("\n=== Las pruebas de TranslucidosRenderer pasaron correctamente ===")
