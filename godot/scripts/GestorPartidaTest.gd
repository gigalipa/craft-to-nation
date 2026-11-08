extends Node

## Suite de pruebas unitarias para GestorPartida.gd y la serialización del estado de juego.

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_inicializacion()
	test_guardar_y_listar_partidas()
	test_cache_metadatos_partidas()
	test_guardado_rapido()
	test_guardar_modificar_y_cargar()
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
