extends Node

const VoxelWorldScript = preload("res://scripts/VoxelWorld.gd")
const TranslucidosScript = preload("res://scripts/TranslucidosRenderer.gd")


func _ready() -> void:
	_test_block_library_texturas()
	_test_variantes_visuales_y_persistencia()
	print("TexturasMundoTest: todas las pruebas pasaron")
	get_tree().quit()


func _test_block_library_texturas() -> void:
	var lib: MeshLibrary = load("res://assets/BlockLibrary.res")
	assert(lib != null, "BlockLibrary.res debe cargar")
	var items_por_nombre := {}
	for id in lib.get_item_list():
		items_por_nombre[lib.get_item_name(id)] = id

	var bloques_1_cara := [
		"tierra_compactada", "estructura_hierro", "bloque_acero", "tierra", "piedra",
		"bedrock", "hierro", "carbon", "cobre", "tierras_raras", "follaje",
		"cama_cabecera", "cama_pies", "bloque_madera", "bloque_piedra",
		"bloque_madera_cruda", "bloque_piedra_rustica"
	]
	for nombre in bloques_1_cara:
		assert(items_por_nombre.has(nombre), "Falta item en BlockLibrary: %s" % nombre)
		var mesh: Mesh = lib.get_item_mesh(items_por_nombre[nombre])
		assert(mesh != null, "Malla nula para %s" % nombre)
		var mat := mesh.surface_get_material(0) as StandardMaterial3D
		assert(mat != null and mat.albedo_texture != null, "Falta albedo_texture en %s" % nombre)
		assert(mat.albedo_color == Color.WHITE, "albedo_color debe ser WHITE en %s" % nombre)

	# Multicara + verificacion geometrica de winding CW hacia afuera
	for nombre_m in ["hierba", "madera", "baul", "mesa_estudio"]:
		assert(items_por_nombre.has(nombre_m), "Falta multicara %s" % nombre_m)
		var mesh_m: Mesh = lib.get_item_mesh(items_por_nombre[nombre_m])
		assert(mesh_m != null and mesh_m.get_surface_count() == 6, "%s debe tener 6 superficies" % nombre_m)
		for s in range(6):
			var sm := mesh_m.surface_get_material(s) as StandardMaterial3D
			assert(sm != null and sm.albedo_texture != null, "Superficie %d de %s sin textura" % [s, nombre_m])
			var arrs := mesh_m.surface_get_arrays(s)
			var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
			var idxs: PackedInt32Array = arrs[Mesh.ARRAY_INDEX] if arrs[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tri_count: int = idxs.size() / 3 if not idxs.is_empty() else verts.size() / 3
			for t in range(tri_count):
				var i0: int = idxs[t * 3] if not idxs.is_empty() else t * 3
				var i1: int = idxs[t * 3 + 1] if not idxs.is_empty() else t * 3 + 1
				var i2: int = idxs[t * 3 + 2] if not idxs.is_empty() else t * 3 + 2
				var orient: float = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).dot(norms[i0])
				assert(orient < 0.0, "Winding invertido en %s sup %d tri %d" % [nombre_m, s, t])

	# Cuñas
	for cuna in ["cuna_recta", "cuna_esquina", "cuna_diag_bajo", "cuna_diag_arriba", "cuna_diag_lat_izq", "cuna_diag_lat_der", "diag_lat"]:
		assert(items_por_nombre.has(cuna), "Falta cuña %s" % cuna)
		var mc: Mesh = lib.get_item_mesh(items_por_nombre[cuna])
		assert(mc != null, "Malla nula en cuña %s" % cuna)
		var mat_c := mc.surface_get_material(0) as StandardMaterial3D
		assert(mat_c != null and mat_c.albedo_texture != null, "Falta textura en cuña %s" % cuna)

	# Materiales base
	var mat_agua := load("res://assets/mat_agua.tres") as StandardMaterial3D
	assert(mat_agua != null and mat_agua.albedo_texture != null, "mat_agua debe tener textura")
	var mat_vent := load("res://assets/mat_ventana.tres") as StandardMaterial3D
	assert(mat_vent != null and mat_vent.albedo_texture != null, "mat_ventana debe tener textura")


func _test_variantes_visuales_y_persistencia() -> void:
	var lib: MeshLibrary = load("res://assets/BlockLibrary.res")
	var mundo := VoxelWorldScript.new()
	mundo.mesh_library = lib
	mundo._indexar_biblioteca()

	# Verificar puertos y ductos indexados con textura
	for p in ["puerto_agua_in", "puerto_agua_out", "puerto_crudo_in", "puerto_crudo_out", "puerto_combustible_in", "puerto_combustible_out", "acueducto_lineal", "tuberia_lineal"]:
		var pid: int = mundo.id_de_tipo(p)
		assert(pid != GridMap.INVALID_CELL_ITEM, "Debe indexar %s" % p)
		var pm: Mesh = mundo.mesh_library.get_item_mesh(pid)
		var pmat := pm.surface_get_material(0) as StandardMaterial3D
		assert(pmat != null and pmat.albedo_texture != null, "Debe tener textura %s" % p)

	var tr := TranslucidosScript.new()
	tr.voxel_world = mundo
	tr._indexar_materiales()
	mundo.bloque_translucido_cambiado.connect(tr._on_bloque_translucido_cambiado)

	# 1. bloque_madera: tablas vs madera cruda
	var c_tablas := Vector3i(1, 5, 1)
	var c_madera := Vector3i(2, 5, 1)
	assert(mundo.colocar_bloque(c_tablas, "bloque_madera", true))
	mundo.aplicar_variante_visual_por_pago(c_tablas, "bloque_madera", {"tablas": 5.0})
	assert(mundo.obtener_tipo(c_tablas) == "bloque_madera")
	assert(mundo.obtener_tipo_visual(c_tablas) == "bloque_madera")

	assert(mundo.colocar_bloque(c_madera, "bloque_madera", true))
	mundo.aplicar_variante_visual_por_pago(c_madera, "bloque_madera", {"madera": 5.0})
	assert(mundo.obtener_tipo(c_madera) == "bloque_madera", "Equivalencia lógica debe seguir siendo bloque_madera")
	assert(mundo.obtener_tipo_visual(c_madera) == "bloque_madera_cruda", "Variante visual debe ser bloque_madera_cruda")

	# 2. bloque_piedra: bloques_piedra vs piedra cruda
	var c_bloques := Vector3i(3, 5, 1)
	var c_piedra := Vector3i(4, 5, 1)
	assert(mundo.colocar_bloque(c_bloques, "bloque_piedra", true))
	mundo.aplicar_variante_visual_por_pago(c_bloques, "bloque_piedra", {"bloques_piedra": 5.0})
	assert(mundo.obtener_tipo_visual(c_bloques) == "bloque_piedra")

	assert(mundo.colocar_bloque(c_piedra, "bloque_piedra", true))
	mundo.aplicar_variante_visual_por_pago(c_piedra, "bloque_piedra", {"piedra": 5.0})
	assert(mundo.obtener_tipo(c_piedra) == "bloque_piedra", "Equivalencia lógica debe seguir siendo bloque_piedra")
	assert(mundo.obtener_tipo_visual(c_piedra) == "bloque_piedra_rustica")

	# 3. vidrio: vidrio vs tierra
	var c_vid := Vector3i(5, 5, 1)
	var c_v_tierra := Vector3i(6, 5, 1)
	assert(mundo.colocar_bloque(c_vid, "vidrio", true, Vector3i(0, 0, 1)))
	mundo.aplicar_variante_visual_por_pago(c_vid, "vidrio", {"vidrio": 1.0})
	assert(mundo.obtener_tipo_visual(c_vid) == "vidrio")

	assert(mundo.colocar_bloque(c_v_tierra, "vidrio", true, Vector3i(0, 0, 1)))
	mundo.aplicar_variante_visual_por_pago(c_v_tierra, "vidrio", {"tierra": 3.0})
	assert(mundo.obtener_tipo(c_v_tierra) == "vidrio", "Equivalencia lógica debe seguir siendo vidrio")
	assert(mundo.obtener_tipo_visual(c_v_tierra) == "vidrio_tierra")

	tr.flush_pendientes()
	assert(tr._mesh_por_chunk.has("vidrio"), "TranslucidosRenderer debe construir malla para vidrio y vidrio_tierra")

	# 4. Modelo 3D de cama en 2 bloques (cama_cabecera y cama_pies) y su orientacion
	for nombre_cama in ["cama_cabecera", "cama_pies"]:
		var mcama: Mesh = lib.get_item_mesh(mundo.id_de_tipo(nombre_cama))
		assert(mcama != null and mcama.get_surface_count() == 2, "%s debe tener 2 superficies (madera y colchon)" % nombre_cama)
		for sc in range(2):
			var smc := mcama.surface_get_material(sc) as StandardMaterial3D
			assert(smc != null and smc.albedo_texture != null, "%s sup %d sin textura" % [nombre_cama, sc])
			var arrs_c := mcama.surface_get_arrays(sc)
			var vc: PackedVector3Array = arrs_c[Mesh.ARRAY_VERTEX]
			var nc: PackedVector3Array = arrs_c[Mesh.ARRAY_NORMAL]
			var ic: PackedInt32Array = arrs_c[Mesh.ARRAY_INDEX] if arrs_c[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tc: int = ic.size() / 3 if not ic.is_empty() else vc.size() / 3
			for t in range(tc):
				var i0: int = ic[t * 3] if not ic.is_empty() else t * 3
				var i1: int = ic[t * 3 + 1] if not ic.is_empty() else t * 3 + 1
				var i2: int = ic[t * 3 + 2] if not ic.is_empty() else t * 3 + 2
				var orient_c: float = (vc[i1] - vc[i0]).cross(vc[i2] - vc[i0]).dot(nc[i0])
				assert(orient_c < 0.0, "Winding invertido en %s sup %d tri %d" % [nombre_cama, sc, t])

	# 5. Cuña orientada con colocar_bloque_orientado y persistencia exportar/importar
	var c_cuna := Vector3i(8, 5, 1)
	assert(mundo.colocar_bloque_orientado(c_cuna, "cuna_recta", 16, true))
	var estado := mundo.exportar_estado()
	var mundo2 := VoxelWorldScript.new()
	mundo2.mesh_library = lib
	mundo2._indexar_biblioteca()
	mundo2.importar_estado(estado)
	assert(mundo2.obtener_tipo(c_cuna) == "cuna_recta", "Cuña debe persistir tras importar")
	assert(mundo2.get_cell_item_orientation(c_cuna) == 16, "Orientación de cuña debe persistir tras importar")
	assert(mundo2.obtener_tipo(c_madera) == "bloque_madera")
	assert(mundo2.obtener_tipo_visual(c_madera) == "bloque_madera_cruda")
	assert(mundo2.obtener_tipo(c_piedra) == "bloque_piedra")
	assert(mundo2.obtener_tipo_visual(c_piedra) == "bloque_piedra_rustica")
	assert(mundo2.obtener_tipo(c_v_tierra) == "vidrio")
	assert(mundo2.obtener_tipo_visual(c_v_tierra) == "vidrio_tierra")

	# 5. Orientacion de cama en las 4 direcciones cardinales
	var dirs_cama := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for k in range(dirs_cama.size()):
		var base_c := Vector3i(20 + k * 4, 5, 1)
		var dir_c: Vector3i = dirs_cama[k]
		assert(mundo.colocar_cama(base_c, dir_c))
		var esperado_ori := mundo._indice_orientacion_cama(dir_c)
		assert(mundo.get_cell_item_orientation(base_c) == esperado_ori, "Cabecera debe orientarse hacia pies")
		assert(mundo.get_cell_item_orientation(base_c + dir_c) == esperado_ori, "Pies deben compartir orientacion")

	for ch in tr.get_children():
		ch.free()
	tr.free()
	mundo.free()
	mundo2.free()
