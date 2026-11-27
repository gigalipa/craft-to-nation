extends Node

## Suite de pruebas unitarias para GestorPartida.gd y la serialización del estado de juego.

func _ready() -> void:
	var ruta_qs := GestorPartida.obtener_ruta_partida(GestorPartida.ARCHIVO_QUICKSAVE)
	var backup_qs := ""
	if FileAccess.file_exists(ruta_qs):
		backup_qs = FileAccess.get_file_as_string(ruta_qs)
	ejecutar_pruebas()
	if not backup_qs.is_empty():
		var f_rest := FileAccess.open(ruta_qs, FileAccess.WRITE)
		if f_rest != null:
			f_rest.store_string(backup_qs)
			f_rest.close()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_inicializacion()
	test_guardar_y_listar_partidas()
	test_cache_metadatos_partidas()
	test_guardado_rapido()
	test_guardar_modificar_y_cargar()
	test_persistencia_militar_fase4()
	test_persistencia_identidad_personajes_y_equipo()
	test_voxelworld_edificio_volumen_roundtrip()
	test_puestos_recoleccion_y_colonos_renderer_tras_carga()
	test_eliminar_partida()


func test_cache_metadatos_partidas() -> void:
	GestorPartida.precargar_metadatos_partidas()
	assert(GestorPartida._cache_valida == true, "_cache_valida debe ser true tras precargar.")
	var lista := GestorPartida.listar_partidas()
	assert(lista.size() == GestorPartida._cache_partidas.size(), "listar_partidas() debe devolver la lista en caché.")
	print("OK: Caché instantánea de metadatos de partidas.")


func test_inicializacion() -> void:
	assert(GestorPartida != null, "El autoload GestorPartida debe existir.")
	assert(DirAccess.dir_exists_absolute(GestorPartida.CARPETA_GUARDADOS), "La carpeta user://saves/ debe existir.")
	print("OK: Inicialización de GestorPartida.")


func test_guardar_y_listar_partidas() -> void:
	var guardado := GestorPartida.guardar_partida("prueba_guardado.json", "Colonia de Pruebas")
	assert(guardado, "guardar_partida() debe retornar true.")

	var ruta := GestorPartida.obtener_ruta_partida("prueba_guardado.json")
	assert(FileAccess.file_exists(ruta), "El archivo guardado debe existir en disco: " + ruta)

	var lista := GestorPartida.listar_partidas()
	assert(lista.size() > 0, "listar_partidas() debe listar al menos una partida.")

	var encontrada := false
	for p in lista:
		if p.get("nombre_archivo") == "prueba_guardado.json":
			encontrada = true
			assert(p.get("nombre_partida") == "Colonia de Pruebas", "El nombre legible no coincide.")
			assert(p.has("fecha_guardado") and not str(p["fecha_guardado"]).is_empty(), "Debe incluir fecha.")
			break
	assert(encontrada, "La partida guardada debe aparecer en la lista.")
	print("OK: Guardar y listar partidas con metadatos.")


func test_guardado_rapido() -> void:
	var ok := GestorPartida.guardado_rapido()
	assert(ok, "guardado_rapido() debe retornar true.")
	var ruta_qs := GestorPartida.obtener_ruta_partida(GestorPartida.ARCHIVO_QUICKSAVE)
	assert(FileAccess.file_exists(ruta_qs), "El archivo de quicksave debe existir.")
	var encontrado := false
	for p in GestorPartida.listar_partidas(true):
		if p.get("nombre_archivo", "") == GestorPartida.ARCHIVO_QUICKSAVE:
			encontrado = true
			break
	assert(encontrado, "quicksave.json debe aparecer en listar_partidas().")
	print("OK: Guardado rápido (quicksave).")


func test_guardar_modificar_y_cargar() -> void:
	# Modificamos valores conocidos en Ciudad
	Ciudad.demografia["obrero"] = 42
	Ciudad.almacen["madera"].cantidad = 888.0
	Ciudad.horas_juego = 15
	Ciudad.moral = 85.0

	var ok_guardar := GestorPartida.guardar_partida("prueba_restaurar.json", "Partida Para Restaurar")
	assert(ok_guardar, "Debe guardar la partida de prueba de restauración.")

	# Alteramos el estado en memoria
	Ciudad.demografia["obrero"] = 2
	Ciudad.almacen["madera"].cantidad = 5.0
	Ciudad.horas_juego = 0
	Ciudad.moral = 50.0

	# Cargamos desde disco
	var ok_cargar := GestorPartida.cargar_partida("prueba_restaurar.json")
	assert(ok_cargar, "cargar_partida() debe retornar true.")

	assert(Ciudad.demografia["obrero"] == 42, "demografia[obrero] debe restaurarse a 42.")
	assert(abs(Ciudad.almacen["madera"].cantidad - 888.0) < 0.1, "almacen[madera] debe restaurarse a 888.0.")
	assert(Ciudad.horas_juego == 15, "horas_juego debe restaurarse a 15.")
	assert(abs(Ciudad.moral - 85.0) < 0.1, "moral debe restaurarse a 85.0.")

	print("OK: Serialización, exportación y restauración completa.")


func test_persistencia_militar_fase4() -> void:
	Ciudad.reiniciar()
	Colonos.reiniciar()
	Ciudad.registrar_cuartel(55, 4)
	Ciudad.demografia["militar"] = 2
	var m1: int = Colonos.agregar_colono("militar", Vector3i(10, 1, 10), -1)
	var m2: int = Colonos.agregar_colono("militar", Vector3i(12, 1, 12), -1)
	Colonos.seleccionar_unidades([m1, m2])
	Colonos.establecer_subgrupo_activo("soldado_raso")
	Colonos.establecer_postura_seleccion("agresivo")
	Colonos.colonos[m1]["salud"] = 90.0
	Colonos.colonos[m1]["cuartel_origen"] = Vector2i(10, 10)
	Colonos.colonos[m1]["orden_militar"] = {
		"tipo": "patrullar",
		"waypoints": [Vector3i(10, 1, 10), Vector3i(20, 1, 20)],
		"waypoint_idx": 1,
		"waypoint_dir": 1,
	}

	var guardado := GestorPartida.guardar_partida("prueba_militar_f4.json", "F4 Test")
	assert(guardado, "Debe guardar partida con estado militar Fase 4.")

	Colonos.reiniciar()
	Ciudad.reiniciar()
	assert(GestorPartida.cargar_partida("prueba_militar_f4.json"), "Debe cargar partida Fase 4.")
	assert(Ciudad.cuarteles_registrados.has(55) and Ciudad.capacidad_militares == 16)
	assert(Colonos.unidades_seleccionadas == [m1, m2], "La selección de unidades debe persistir.")
	assert(Colonos.subgrupo_activo == "soldado_raso")
	assert(is_equal_approx(Colonos.colonos[m1]["salud"], 90.0))
	assert(Colonos.colonos[m1]["postura"] == "agresivo")
	assert(Colonos.colonos[m1]["cuartel_origen"] == Vector2i(10, 10))
	assert(Colonos.colonos[m1]["orden_militar"]["waypoints"][1] == Vector3i(20, 1, 20))
	GestorPartida.eliminar_partida("prueba_militar_f4.json")
	print("OK: Persistencia militar de Fase 4 (cuarteles, salud, órdenes, selección).")


func test_voxelworld_edificio_volumen_roundtrip() -> void:
	var vw_script = preload("res://scripts/VoxelWorld.gd")
	var vw = vw_script.new()
	vw.edificio_volumen[7] = {"min": Vector3i(10, 1, 10), "max": Vector3i(18, 8, 16)}
	var json_txt := JSON.stringify(vw.exportar_estado())
	var parsed: Dictionary = JSON.parse_string(json_txt)
	vw.edificio_volumen.clear()
	vw.importar_estado(parsed)
	assert(vw.edificio_volumen.has(7), "edificio_volumen[7] debe restaurarse tras exportar/importar JSON")
	assert(vw.edificio_volumen[7]["min"] == Vector3i(10, 1, 10), "min de edificio_volumen debe restaurarse como Vector3i")
	assert(vw.edificio_volumen[7]["max"] == Vector3i(18, 8, 16), "max de edificio_volumen debe restaurarse como Vector3i")

	# Compatibilidad retroactiva con partidas guardadas previamente donde Vector3i se serializó como "(x, y, z)"
	vw.edificio_volumen.clear()
	vw.importar_estado({"edificio_volumen": {"9": {"min": "(2, 1, 3)", "max": "(8, 6, 9)"}}})
	assert(vw.edificio_volumen.has(9) and vw.edificio_volumen[9]["min"] == Vector3i(2, 1, 3) and vw.edificio_volumen[9]["max"] == Vector3i(8, 6, 9), "Debe cargar partidas legacy con edificio_volumen como string '(x, y, z)'")
	vw.free()
	print("OK: Serialización y carga retroactiva de VoxelWorld.edificio_volumen verificada.")


func test_puestos_recoleccion_y_colonos_renderer_tras_carga() -> void:
	Ciudad.reiniciar()
	Economia.reiniciar()
	Colonos.reiniciar()
	Recoleccion.puestos.clear()

	# Instanciar ColonosRenderer ANTES de cargar (igual que en Main.tscn)
	var rend_script = preload("res://scripts/ColonosRenderer.gd")
	var rend = rend_script.new()
	rend.name = "ColonosRenderer"
	add_child(rend)

	var esq_mina := Vector2i(30, 30)
	var esq_sid := Vector2i(42, 30)
	Economia.registrar_puesto(esq_mina, "mina", 5, 5, {"piedra": 10.0}, {"centro": Vector2i(32, 32), "altura": 2, "radio_arboles": 8, "arboles_ref": 4})
	Economia.puestos[esq_mina]["en_curso"]["piedra"] = {"tipo": "bloque", "celda": Vector3i(31, 1, 31), "recurso": "piedra", "restante": 10.0}
	Economia.registrar_puesto(esq_sid, "siderurgica", 7, 5, {})
	var id_c: int = Colonos.agregar_colono("obrero", Vector3i(32, 1, 32), 1)
	Colonos.colonos[id_c]["trabajo"] = {"puesto": esq_mina, "rol": "recolector"}
	Economia.puestos[esq_mina]["recolectores"].append(id_c)
	Economia.puestos[esq_mina]["presentes"][id_c] = true

	assert(GestorPartida.guardar_partida("prueba_puestos_colonos.json", "Puestos y Colonos"))

	# Limpiar estado completo y renderer como al iniciar nueva escena Main
	Economia.reiniciar()
	Colonos.reiniciar()
	Recoleccion.puestos.clear()
	rend.reconstruir()
	assert(rend._cuerpos.is_empty(), "Renderer debe estar vacío antes de cargar")
	assert(Recoleccion.puestos.is_empty(), "Recoleccion.puestos debe estar vacío antes de cargar")

	assert(GestorPartida.cargar_partida("prueba_puestos_colonos.json"))

	# Verificar que Recoleccion.puestos se sincronizó y reconoce la huella de cada puesto
	assert(Recoleccion.puestos.has(esq_mina) and Recoleccion.puestos[esq_mina]["tipo"] == "mina", "Recoleccion debe restaurar mina")
	assert(Recoleccion.puestos.has(esq_sid) and Recoleccion.puestos[esq_sid]["tipo"] == "siderurgica", "Recoleccion debe restaurar siderurgica")
	assert(Recoleccion.esquina_de_puesto_en(Vector2i(32, 32)) == esq_mina, "esquina_de_puesto_en debe localizar la mina restaurada")
	assert(Economia.puestos[esq_mina]["recolectores"].has(id_c), "IDs de recolectores deben restaurarse como int")
	assert(Economia.puestos[esq_mina]["presentes"].has(id_c), "Claves de presentes deben restaurarse como int")
	assert(Economia.puestos[esq_mina]["en_curso"]["piedra"]["celda"] is Vector3i and Economia.puestos[esq_mina]["en_curso"]["piedra"]["celda"] == Vector3i(31, 1, 31), "en_curso.celda debe restaurarse como Vector3i")
	assert(Economia.puestos[esq_mina]["entorno"]["centro"] is Vector2i and Economia.puestos[esq_mina]["entorno"]["centro"] == Vector2i(32, 32), "entorno.centro debe restaurarse como Vector2i")
	assert(Colonos.colonos[id_c]["trabajo"]["puesto"] is Vector2i and Colonos.colonos[id_c]["trabajo"]["puesto"] == esq_mina, "trabajo.puesto del colono debe restaurarse como Vector2i")

	# Verificar compatibilidad retroactiva con en_curso.celda y entorno.centro legacy como strings
	Economia.importar_estado({
		"puestos": {
			"30,30": {
				"tipo": "mina", "ancho": 5, "alto": 5, "nivel": 1,
				"en_curso": {"piedra": {"tipo": "bloque", "celda": "(31, 1, 31)", "recurso": "piedra", "restante": 10.0}},
				"entorno": {"centro": "(32, 32)", "altura": 2},
			}
		}
	})
	assert(Economia.puestos[esq_mina]["en_curso"]["piedra"]["celda"] == Vector3i(31, 1, 31), "Debe parsear en_curso.celda legacy como Vector3i")
	assert(Economia.puestos[esq_mina]["entorno"]["centro"] == Vector2i(32, 32), "Debe parsear entorno.centro legacy como Vector2i")

	# Verificar compatibilidad retroactiva con partidas legacy donde trabajo.puesto era String "(30, 30)"
	Colonos.importar_estado({
		"siguiente_id": 2,
		"colonos": {
			"1": {
				"id": 1, "tipo": "obrero", "hogar": 1,
				"celda": {"x": 32, "y": 1, "z": 32},
				"posicion": {"x": 32.5, "y": 1.0, "z": 32.5},
				"trabajo": {"puesto": "(30, 30)", "rol": "recolector"},
				"ruta": [],
			}
		}
	})
	assert(Colonos.colonos[1]["trabajo"]["puesto"] is Vector2i and Colonos.colonos[1]["trabajo"]["puesto"] == Vector2i(30, 30), "Debe parsear trabajo.puesto legacy '(30, 30)' como Vector2i")
	rend.reconstruir()

	# Verificar que ColonosRenderer reconstruyó el cuerpo visible del colono cargado
	assert(rend._cuerpos.has(id_c), "ColonosRenderer debe mostrar el colono tras cargar partida")

	GestorPartida.eliminar_partida("prueba_puestos_colonos.json")
	rend.queue_free()
	Economia.reiniciar()
	Colonos.reiniciar()
	Recoleccion.puestos.clear()
	print("OK: Restauración de Recoleccion.puestos y cuerpos en ColonosRenderer tras carga verificada.")


func test_eliminar_partida() -> void:
	var borrado_1 := GestorPartida.eliminar_partida("prueba_guardado.json")
	assert(borrado_1, "eliminar_partida('prueba_guardado.json') debe retornar true.")

	var ruta_1 := GestorPartida.obtener_ruta_partida("prueba_guardado.json")
	assert(not FileAccess.file_exists(ruta_1), "El archivo eliminado no debe existir.")

	var borrado_2 := GestorPartida.eliminar_partida("prueba_restaurar.json")
	assert(borrado_2, "eliminar_partida('prueba_restaurar.json') debe retornar true.")

	# Limpiar quicksave de prueba
	GestorPartida.eliminar_partida(GestorPartida.ARCHIVO_QUICKSAVE)

	# Restaurar estado limpio de Ciudad
	Ciudad.reiniciar()
	print("OK: Eliminación de partidas y limpieza.")


func test_persistencia_identidad_personajes_y_equipo() -> void:
	Ciudad.reiniciar()
	Colonos.reiniciar()
	Ciudad.genero_avatar = "F"
	Ciudad.tono_piel_avatar = 3
	Ciudad.establecer_color_equipo(Color("#c93838"))
	Ciudad.registrar_color_equipo("rival_1", Color("#2e8f57"))

	var cid: int = Colonos.agregar_colono("tecnico", Vector3i(8, 1, 8), -1, {
		"genero": "F",
		"tono_piel": 2,
		"equipo_id": "rival_1",
	})
	Colonos.colonos[cid]["orientacion_y"] = 1.25

	assert(GestorPartida.guardar_partida("prueba_identidad_3d.json", "Identidad 3D"), "Debe guardar identidad 3D.")

	Ciudad.reiniciar()
	Colonos.reiniciar()
	assert(GestorPartida.cargar_partida("prueba_identidad_3d.json"), "Debe cargar identidad 3D.")

	assert(Ciudad.genero_avatar == "F", "genero_avatar debe restaurarse.")
	assert(Ciudad.tono_piel_avatar == 3, "tono_piel_avatar debe restaurarse.")
	assert(Ciudad.color_equipo.is_equal_approx(Color("#c93838")), "color_equipo debe restaurarse.")
	assert(Ciudad.color_de_equipo("rival_1").is_equal_approx(Color("#2e8f57")), "colores_equipos rival debe restaurarse.")
	assert(Colonos.colonos.has(cid))
	assert(Colonos.colonos[cid]["genero"] == "F", "genero del colono debe persistir.")
	assert(int(Colonos.colonos[cid]["tono_piel"]) == 2, "tono_piel del colono debe persistir.")
	assert(Colonos.colonos[cid]["equipo_id"] == "rival_1", "equipo_id del colono debe persistir.")
	assert(is_equal_approx(float(Colonos.colonos[cid]["orientacion_y"]), 1.25), "orientacion_y debe persistir.")

	GestorPartida.eliminar_partida("prueba_identidad_3d.json")
	Colonos.reiniciar()
	Ciudad.reiniciar()
	print("OK: Persistencia de identidad 3D y colores de equipo verificada.")
