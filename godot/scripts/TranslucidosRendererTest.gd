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
	mundo.colocar_bloque(Vector3i(0, 0, 0), "bloque_piedra", true)
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
	mundo.colocar_bloque(Vector3i(2, 0, 0), "vidrio", true)
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

	print("\n=== TEST 3: _cara_visible() — sólido siempre oculta; arriba del agua siempre se dibuja; abajo del agua nunca; laterales usan la regla general ===")
	const ARRIBA_T3 := Vector3i(0, 1, 0)
	const ABAJO_T3 := Vector3i(0, -1, 0)
	const LATERAL_T3 := Vector3i(1, 0, 0)
	# Regla 1: un vecino sólido oculta SIEMPRE, sin excepción — incluida la
	# cara de arriba del agua.
	assert(TranslucidosRendererScript._cara_visible("agua", "bloque_piedra", ARRIBA_T3) == false, "un vecino sólido oculta incluso la cara de arriba del agua — evita reintroducir el z-fighting")
	assert(TranslucidosRendererScript._cara_visible("agua", "bloque_piedra", LATERAL_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("vidrio", "piedra", LATERAL_T3) == false)
	# Regla 2 (agua, arriba/abajo): no depende del vecino, solo de la dirección.
	assert(TranslucidosRendererScript._cara_visible("agua", "", ARRIBA_T3) == true, "arriba contra aire: se dibuja")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua", ARRIBA_T3) == true, "arriba contra OTRA celda de agua: se dibuja igual — así se apilan capas reales con la profundidad")
	assert(TranslucidosRendererScript._cara_visible("agua", "vidrio", ARRIBA_T3) == true, "arriba contra un tipo translúcido distinto: se dibuja igual")
	assert(TranslucidosRendererScript._cara_visible("agua", "", ABAJO_T3) == false, "abajo NUNCA se dibuja, ni siquiera contra aire")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua", ABAJO_T3) == false)
	# Regla 3 (agua, laterales — y cualquier otro tipo translúcido en
	# cualquier dirección): regla general, se omite solo contra el MISMO
	# tipo. Corrección tras jugar en vivo: omitir las laterales del agua
	# SIEMPRE (incluso contra aire) rompía la continuidad visual de una
	# cascada — necesita su cara lateral expuesta al aire para verse como
	# una caída real, no como pozas escalonadas.
	assert(TranslucidosRendererScript._cara_visible("agua", "", LATERAL_T3) == true, "lateral del agua contra aire: SÍ se dibuja (necesario para cascadas)")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua", LATERAL_T3) == false, "lateral del agua contra OTRA agua: se omite (cara interna)")
	assert(TranslucidosRendererScript._cara_visible("agua", "vidrio", LATERAL_T3) == true, "lateral del agua contra un tipo translúcido distinto: se dibuja")
	assert(TranslucidosRendererScript._cara_visible("vidrio", "vidrio", ARRIBA_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("vidrio", "vidrio", LATERAL_T3) == false)
	assert(TranslucidosRendererScript._cara_visible("vidrio", "", LATERAL_T3) == true)
	assert(TranslucidosRendererScript._cara_visible("vidrio", "agua", LATERAL_T3) == true, "ventana contra un tipo translúcido distinto (agua): se dibuja")
	print("OK: sólido oculta siempre; arriba del agua siempre se dibuja (incluso contra otra agua), abajo nunca, laterales siguen la regla general (solo ocultan contra el mismo tipo).")

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

	print("\n=== TEST 5: dos celdas de agua adyacentes horizontalmente — arriba siempre, la lateral COMPARTIDA se omite, las otras 3 laterales (contra aire) se dibujan ===")
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
	# Cada celda: arriba (1, contra aire) + 3 laterales contra aire (todas
	# menos la que comparten entre sí, que se omite por ser el mismo tipo) +
	# abajo nunca = 4 caras. Dos celdas = 8 caras = 48 vértices.
	var chunk_t5: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var instancia_t5: MeshInstance3D = render_t5._mesh_por_chunk["agua"][chunk_t5]
	var conteo_vertices_t5: int = instancia_t5.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t5 == 8 * 6, "dos celdas de agua adyacentes deben exponer 8 caras en total (48 vértices): arriba + 3 laterales cada una, omitiendo solo la lateral compartida")
	print("OK: cada celda de agua dibuja arriba y sus laterales contra aire; solo omite la lateral compartida con la otra celda de agua.")

	print("\n=== TEST 6: una celda de agua rodeada por sólido en sus 6 caras no dibuja ninguna (el sólido siempre gana, en cualquier dirección) ===")
	var mundo_t6: Node = VoxelWorld.new()
	mundo_t6.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t6.cell_size = Vector3.ONE * 1.0
	mundo_t6._indexar_biblioteca()
	mundo_t6.colocar_bloque(Vector3i(10, 10, 10), "agua")
	for delta_t6: Vector3i in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]:
		mundo_t6.colocar_bloque(Vector3i(10, 10, 10) + delta_t6, "bloque_piedra", true)
	var render_t6: Node3D = TranslucidosRendererScript.new()
	render_t6.voxel_world = mundo_t6
	render_t6._indexar_materiales()
	render_t6.reconstruir_todo()
	var chunk_t6: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(10, 10, 10))
	assert(not render_t6._mesh_por_chunk.get("agua", {}).has(chunk_t6), "una celda de agua completamente rodeada de sólido no debe tener ninguna cara visible, ni siquiera la de arriba")
	print("OK: rodeada de sólido por los 6 lados, la celda de agua no dibuja ninguna cara — el sólido tiene prioridad sobre la regla de 'arriba siempre'.")

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
	assert(conteo_incremental_t7 == 8 * 6, "el camino incremental debe dar el mismo resultado que reconstruir_todo() (TEST 5) para el mismo estado final")
	print("OK: colocar bloques uno a uno vía señal converge exactamente al mismo resultado que reconstruir_todo().")

	print("\n=== TEST 8: una columna de agua encerrada lateralmente apila una cara de arriba REAL por cada celda — más profundidad, más caras superpuestas ===")
	var mundo_t8: Node = VoxelWorld.new()
	mundo_t8.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t8.cell_size = Vector3.ONE * 1.0
	mundo_t8._indexar_biblioteca()
	# 3 celdas de agua apiladas, con sus 4 lados sellados con pared en cada
	# nivel (como un pozo/ducto dentro de un edificio) para aislar el efecto
	# de apilamiento de la regla general de laterales (TEST 5/7 ya la cubre
	# por separado). Cada nivel solo puede mostrar su cara de ARRIBA.
	for y_t8 in range(3):
		mundo_t8.colocar_bloque(Vector3i(0, y_t8, 0), "agua")
		mundo_t8.colocar_bloque(Vector3i(1, y_t8, 0), "bloque_piedra", true)
		mundo_t8.colocar_bloque(Vector3i(-1, y_t8, 0), "bloque_piedra", true)
		mundo_t8.colocar_bloque(Vector3i(0, y_t8, 1), "bloque_piedra", true)
		mundo_t8.colocar_bloque(Vector3i(0, y_t8, -1), "bloque_piedra", true)
	var render_t8: Node3D = TranslucidosRendererScript.new()
	render_t8.voxel_world = mundo_t8
	render_t8._indexar_materiales()
	render_t8.reconstruir_todo()
	var chunk_t8: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var conteo_vertices_t8: int = render_t8._mesh_por_chunk["agua"][chunk_t8].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t8 == 3 * 6, "un pozo de 3 celdas de agua (laterales selladas) debe dibujar 3 caras de arriba reales (18 vértices), una por celda")

	# Tapar la celda superior con un sólido elimina SOLO esa cara de arriba
	# (regla 1 tiene prioridad) — las otras dos siguen intactas.
	mundo_t8.colocar_bloque(Vector3i(0, 3, 0), "bloque_piedra", true)
	render_t8.reconstruir_todo()
	var conteo_vertices_t8b: int = render_t8._mesh_por_chunk["agua"][chunk_t8].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t8b == 2 * 6, "tapar la celda superior con un sólido debe quitar únicamente su cara de arriba, dejando 2 caras (12 vértices)")
	print("OK: cada celda de un pozo de agua apila su propia cara de arriba real (más profundidad = más capas), y un sólido encima solo quita la cara de esa celda puntual.")

	print("\n=== TEST 9: un semibloque de agua de flujo dibuja su cara de arriba más baja, y la fuente vecina dibuja solo la franja lateral expuesta sobre él ===")
	var mundo_t9: Node = VoxelWorld.new()
	mundo_t9.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t9.cell_size = Vector3.ONE * 1.0
	mundo_t9._indexar_biblioteca()
	mundo_t9.colocar_bloque(Vector3i(0, 0, 0), "agua")  # fuente: altura 1.0
	mundo_t9.colocar_bloque(Vector3i(1, 0, 0), "agua")
	mundo_t9._nivel_agua[Vector3i(1, 0, 0)] = 4  # flujo nivel 4: altura (8-4)/8 = 0.5
	assert(is_equal_approx(mundo_t9.altura_agua_en(Vector3i(0, 0, 0)), 1.0))
	assert(is_equal_approx(mundo_t9.altura_agua_en(Vector3i(1, 0, 0)), 0.5))
	var render_t9: Node3D = TranslucidosRendererScript.new()
	render_t9.voxel_world = mundo_t9
	render_t9._indexar_materiales()
	render_t9.reconstruir_todo()
	var chunk_t9: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var vertices_t9: PackedVector3Array = render_t9._mesh_por_chunk["agua"][chunk_t9].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Fuente: arriba + 3 laterales contra aire + la franja hacia el semibloque
	# (más bajo) = 5 caras. Semibloque: arriba + 3 laterales contra aire (la
	# compartida se omite: el vecino es más alto) = 4 caras. Total 9 caras.
	assert(vertices_t9.size() == 9 * 6, "fuente + semibloque deben dibujar 9 caras (54 vértices)")
	var max_y_semibloque := -INF
	for vertice_t9 in vertices_t9:
		if vertice_t9.x > 1.0 - 0.0001 and vertice_t9.x < 2.0 + 0.0001 and vertice_t9.x != 1.0:
			max_y_semibloque = maxf(max_y_semibloque, vertice_t9.y)
	assert(is_equal_approx(max_y_semibloque, 0.5), "los vértices exclusivos del semibloque (x en (1, 2]) no deben subir de su altura 0.5, salió %f" % max_y_semibloque)
	print("OK: el semibloque (nivel 4) llega a 0.5 de altura, y la fuente dibuja una franja lateral hacia él.")

	print("\n=== TEST 10: quitar un fantasma que estaba justo encima del agua le devuelve la cara de arriba (el renderer se entera) ===")
	var mundo_t10: Node = VoxelWorld.new()
	mundo_t10.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t10.cell_size = Vector3.ONE * 1.0
	mundo_t10._indexar_biblioteca()
	var render_t10: Node3D = TranslucidosRendererScript.new()
	render_t10.voxel_world = mundo_t10
	render_t10._indexar_materiales()
	mundo_t10.bloque_translucido_cambiado.connect(render_t10._on_bloque_translucido_cambiado)
	var agua_t10 := Vector3i(0, 0, 0)
	var fantasma_t10 := Vector3i(0, 1, 0)  # celda vacía justo encima del agua: recibe el fantasma
	mundo_t10.colocar_bloque(agua_t10, "agua")
	var id_t10: int = mundo_t10.iniciar_construccion_fantasma([], {}, [fantasma_t10], {fantasma_t10: "bloque_piedra"})
	# Otra celda de agua fuerza reconstruir el chunk con el fantasma ya puesto, como
	# hace en juego el primer bloque de relleno que sustituye agua.
	mundo_t10.colocar_bloque(Vector3i(10, 0, 0), "agua")
	render_t10.flush_pendientes()
	var chunk_t10: Vector3i = TranslucidosRendererScript._chunk_de(agua_t10)
	var con_fantasma_t10: int = render_t10._mesh_por_chunk["agua"][chunk_t10].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	# Celda 1: 4 laterales (el fantasma sólido le oculta la de arriba) = 4 caras. Celda 2 (aislada): 5 caras.
	assert(con_fantasma_t10 == 9 * 6, "con el fantasma encima, el agua no dibuja su cara de arriba (9 caras en total), salió %d vértices" % con_fantasma_t10)
	assert(mundo_t10.procesar_deconstruccion(fantasma_t10)["lista_para_remocion"])
	mundo_t10.eliminar_edificio(id_t10)
	render_t10.flush_pendientes()
	var sin_fantasma_t10: int = render_t10._mesh_por_chunk["agua"][chunk_t10].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(sin_fantasma_t10 == 10 * 6, "al quitar el fantasma el agua recupera su cara de arriba (10 caras en total), salió %d vértices" % sin_fantasma_t10)
	print("OK: eliminar el edificio avisa al renderer y el agua recupera su cara de arriba.")

	print("\n=== TEST 11: bloque crudo se renderiza con culling de caras internas y material de crudo ===")
	var mundo_t11: Node = VoxelWorld.new()
	mundo_t11.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t11.cell_size = Vector3.ONE * 1.0
	mundo_t11._indexar_biblioteca()
	var render_t11: Node3D = TranslucidosRendererScript.new()
	render_t11.voxel_world = mundo_t11
	render_t11._indexar_materiales()
	mundo_t11.bloque_translucido_cambiado.connect(render_t11._on_bloque_translucido_cambiado)

	var celdas_emitidas_crudo: Array[Vector3i] = []
	mundo_t11.bloque_translucido_cambiado.connect(func(c: Vector3i) -> void: celdas_emitidas_crudo.append(c))

	# Colocar dos celdas contiguas de crudo en (0,0,0) y (1,0,0)
	mundo_t11.colocar_bloque(Vector3i(0, 0, 0), "crudo")
	assert(celdas_emitidas_crudo.has(Vector3i(0, 0, 0)), "colocar crudo emite bloque_translucido_cambiado")
	mundo_t11.colocar_bloque(Vector3i(1, 0, 0), "crudo")
	render_t11.flush_pendientes()

	var chunk_t11: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	assert(render_t11._mesh_por_chunk.has("crudo"), "renderiza capa crudo")
	assert(render_t11._mesh_por_chunk["crudo"].has(chunk_t11), "chunk de crudo creado")
	var mesh_crudo: MeshInstance3D = render_t11._mesh_por_chunk["crudo"][chunk_t11]
	assert(mesh_crudo.get_surface_override_material(0) == render_t11._material_por_tipo["crudo"], "usa material de crudo")
	assert(render_t11._material_por_tipo["crudo"].cull_mode == BaseMaterial3D.CULL_DISABLED, "crudo debe tener culling desactivado para verse desde arriba y sumergido")

	var vertices_crudo: PackedVector3Array = mesh_crudo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices_crudo.size() == 8 * 6, "dos celdas contiguas de crudo deben tener culling en cara compartida (8 caras = 48 vértices), salieron %d" % vertices_crudo.size())
	print("\n=== TEST 12: bloque combustible es translucido y liquido, renderizado con material ambar ===")
	assert(VoxelWorld.TIPOS_TRANSLUCIDOS.has("combustible"), "combustible debe ser translucido")
	assert(VoxelWorld.TIPOS_LIQUIDOS.has("combustible"), "combustible debe ser liquido")

	var render_t12: Node3D = TranslucidosRendererScript.new()
	render_t12.voxel_world = mundo_t11
	render_t12._indexar_materiales()
	mundo_t11.bloque_translucido_cambiado.connect(render_t12._on_bloque_translucido_cambiado)
	assert(render_t12._material_por_tipo.has("combustible"), "debe indexar material de combustible")
	var mat_comb: StandardMaterial3D = render_t12._material_por_tipo["combustible"]
	assert(mat_comb != null, "material de combustible no nulo")
	assert(mat_comb.cull_mode == BaseMaterial3D.CULL_DISABLED, "combustible debe tener culling desactivado para verse desde arriba y sumergido")

	mundo_t11.colocar_bloque(Vector3i(10, 0, 0), "combustible")
	mundo_t11.colocar_bloque(Vector3i(11, 0, 0), "combustible")
	render_t12.flush_pendientes()
	var chunk_t12: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(10, 0, 0))
	assert(render_t12._mesh_por_chunk.has("combustible"), "renderiza capa combustible")
	assert(render_t12._mesh_por_chunk["combustible"].has(chunk_t12), "chunk de combustible creado")
	var mesh_comb: MeshInstance3D = render_t12._mesh_por_chunk["combustible"][chunk_t12]
	var vertices_comb: PackedVector3Array = mesh_comb.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices_comb.size() == 8 * 6, "dos celdas contiguas de combustible deben tener culling en cara compartida (8 caras = 48 vertices), salieron %d" % vertices_comb.size())
	print("OK: combustible clasificado, renderizado con culling y material ambar.")

	print("\n=== TEST 13: spreading horizontal diferenciado por tipo de liquido (agua 7, combustible 5, crudo 3) ===")
	assert(VoxelWorld.ALCANCE_FLUJO_AGUA == 7)
	assert(VoxelWorld.ALCANCE_FLUJO_COMBUSTIBLE == 5)
	assert(VoxelWorld.ALCANCE_FLUJO_CRUDO == 3)

	var mundo_t13: Node = VoxelWorld.new()
	mundo_t13.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t13.cell_size = Vector3.ONE * 1.0
	mundo_t13._indexar_biblioteca()

	# Canal lineal para crudo: x en [200..205], y=1, cerrado en laterales
	for x in range(199, 206):
		mundo_t13.colocar_bloque(Vector3i(x, 0, 200), "bloque_piedra")
		mundo_t13.colocar_bloque(Vector3i(x, 1, 199), "bloque_piedra")
		mundo_t13.colocar_bloque(Vector3i(x, 1, 201), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(199, 1, 200), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(205, 1, 200), "bloque_piedra")

	mundo_t13.colocar_bloque(Vector3i(200, 1, 200), "crudo", true)
	mundo_t13._drenar_escurrimiento_para_pruebas()
	assert(mundo_t13.obtener_tipo(Vector3i(201, 1, 200)) == "crudo", "crudo avanza celda 1")
	assert(mundo_t13.obtener_tipo(Vector3i(202, 1, 200)) == "crudo", "crudo avanza celda 2")
	assert(mundo_t13.obtener_tipo(Vector3i(203, 1, 200)) == "crudo", "crudo avanza celda 3")
	assert(mundo_t13.obtener_tipo(Vector3i(204, 1, 200)) == "", "crudo no debe superar alcance 3")

	# Canal lineal para combustible: x en [210..218], y=1
	for x in range(209, 219):
		mundo_t13.colocar_bloque(Vector3i(x, 0, 210), "bloque_piedra")
		mundo_t13.colocar_bloque(Vector3i(x, 1, 209), "bloque_piedra")
		mundo_t13.colocar_bloque(Vector3i(x, 1, 211), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(209, 1, 210), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(218, 1, 210), "bloque_piedra")

	mundo_t13.colocar_bloque(Vector3i(210, 1, 210), "combustible", true)
	mundo_t13._drenar_escurrimiento_para_pruebas()
	for i in range(1, 6):
		assert(mundo_t13.obtener_tipo(Vector3i(210 + i, 1, 210)) == "combustible", "combustible avanza celda %d" % i)
	assert(mundo_t13.obtener_tipo(Vector3i(216, 1, 210)) == "", "combustible no debe superar alcance 5")

	# Canal lineal para agua: x en [220..230], y=1
	for x in range(219, 231):
		mundo_t13.colocar_bloque(Vector3i(x, 0, 220), "bloque_piedra")
		mundo_t13.colocar_bloque(Vector3i(x, 1, 219), "bloque_piedra")
		mundo_t13.colocar_bloque(Vector3i(x, 1, 221), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(219, 1, 220), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(230, 1, 220), "bloque_piedra")

	mundo_t13.colocar_bloque(Vector3i(220, 1, 220), "agua", true)
	mundo_t13._drenar_escurrimiento_para_pruebas()
	for i in range(1, 8):
		assert(mundo_t13.obtener_tipo(Vector3i(220 + i, 1, 220)) == "agua", "agua avanza celda %d" % i)
	assert(mundo_t13.obtener_tipo(Vector3i(228, 1, 220)) == "", "agua no debe superar alcance 7")
	print("OK: alcances horizontales comprobados para agua (7), combustible (5) y crudo (3).")

	print("\n=== TEST 14: desalojo y destruccion inmediata de liquidos al colocar bloques solidos ===")
	var celdas_emitidas_t14: Array[Vector3i] = []
	mundo_t13.bloque_translucido_cambiado.connect(func(c: Vector3i) -> void: celdas_emitidas_t14.append(c))

	mundo_t13.colocar_bloque(Vector3i(300, 0, 300), "crudo")
	celdas_emitidas_t14.clear()
	var colocado_crudo: bool = mundo_t13.colocar_bloque(Vector3i(300, 0, 300), "bloque_piedra", true)
	assert(colocado_crudo, "debe permitir colocar bloque solido sobre crudo")
	assert(mundo_t13.obtener_tipo(Vector3i(300, 0, 300)) == "bloque_piedra", "tipo reemplazado a bloque_piedra")
	assert(mundo_t13.nivel_agua_en(Vector3i(300, 0, 300)) == -1, "nivel de flujo destruido")
	assert(celdas_emitidas_t14.has(Vector3i(300, 0, 300)), "bloque_translucido_cambiado emitido al desalojar crudo")

	mundo_t13.colocar_bloque(Vector3i(301, 0, 300), "agua")
	celdas_emitidas_t14.clear()
	var colocado_agua: bool = mundo_t13.colocar_bloque(Vector3i(301, 0, 300), "tierra", true)
	assert(colocado_agua, "debe permitir colocar bloque solido sobre agua")
	assert(mundo_t13.obtener_tipo(Vector3i(301, 0, 300)) == "tierra", "tipo reemplazado a tierra")
	assert(mundo_t13.nivel_agua_en(Vector3i(301, 0, 300)) == -1, "nivel de flujo destruido")
	assert(celdas_emitidas_t14.has(Vector3i(301, 0, 300)), "bloque_translucido_cambiado emitido al desalojar agua")
	print("OK: colocar bloque solido sobre liquido desaloja y destruye el liquido.")

	print("\n=== TEST 15: inundacion estilo Minecraft al minar bloque solido con agua adyacente lateral o superior ===")
	# Caso lateral: agua en (400, 1, 400), piedra en (401, 1, 400)
	mundo_t13.colocar_bloque(Vector3i(400, 0, 400), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(401, 0, 400), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(400, 1, 400), "agua")
	mundo_t13.colocar_bloque(Vector3i(401, 1, 400), "bloque_piedra")
	mundo_t13.minar_bloque(Vector3i(401, 1, 400))
	assert(mundo_t13.obtener_tipo(Vector3i(401, 1, 400)) == "agua", "inundacion inmediata al minar bloque con vecino lateral de agua")

	# Caso superior: agua en (410, 2, 410), piedra en (410, 1, 410)
	mundo_t13.colocar_bloque(Vector3i(410, 0, 410), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(410, 1, 410), "bloque_piedra")
	mundo_t13.colocar_bloque(Vector3i(410, 2, 410), "agua")
	mundo_t13.minar_bloque(Vector3i(410, 1, 410))
	assert(mundo_t13.obtener_tipo(Vector3i(410, 1, 410)) == "agua", "inundacion inmediata al minar bloque con vecino superior de agua")

	# Caso inferior: agua en (420, 0, 420), piedra en (420, 1, 420) — NO debe subir
	mundo_t13.colocar_bloque(Vector3i(420, 0, 420), "agua")
	mundo_t13.colocar_bloque(Vector3i(420, 1, 420), "bloque_piedra")
	mundo_t13.minar_bloque(Vector3i(420, 1, 420))
	assert(mundo_t13.obtener_tipo(Vector3i(420, 1, 420)) == "", "agua inferior no debe subir al minar celda sobre ella")
	print("OK: inundacion estilo Minecraft confirmada para vecinos laterales y superiores.")

	print("\n=== Las pruebas de TranslucidosRenderer pasaron correctamente ===")
