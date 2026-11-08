extends Node

## Suite de pruebas unitarias para Sonidos.gd
## Verifica la inicialización del singleton, los pools de reproductores,
## la carga de los 102 efectos de sonido y la tolerancia a fallos.

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	Sonidos.volumen_sfx_db = 0.0
	Sonidos.sfx_habilitado = true
	test_inicializacion()
	test_cargar_todos_los_sonidos()
	test_reproduccion_2d()
	test_reproduccion_3d()
	test_tolerancia_fallos()
	test_modulacion_volumen_y_pitch()


func test_inicializacion() -> void:
	assert(Sonidos != null, "El singleton Sonidos debe estar registrado en el árbol.")
	assert(Sonidos._pool_2d.size() == Sonidos.TAMANO_POOL_2D, "El pool 2D debe tener tamaño 16.")
	assert(Sonidos._pool_3d.size() == Sonidos.TAMANO_POOL_3D, "El pool 3D debe tener tamaño 16.")
	assert(Sonidos.sfx_habilitado == true, "SFX debe estar habilitado por defecto.")
	print("OK: Inicialización del singleton y pools.")


func test_cargar_todos_los_sonidos() -> void:
	# Carga y valida que todos los sonidos del catálogo carguen un AudioStream válido
	var ruta_cat := "res://assets/sfx/sfx_catalog.json"
	assert(FileAccess.file_exists(ruta_cat), "El archivo sfx_catalog.json debe existir.")
	var arch := FileAccess.open(ruta_cat, FileAccess.READ)
	assert(arch != null, "Debe poder abrirse sfx_catalog.json.")
	var data = JSON.parse_string(arch.get_as_text())
	assert(data is Dictionary, "El catálogo debe ser un diccionario.")
	assert(data.size() == 102, "El catálogo debe tener exactamente 102 sonidos.")

	var cargados := 0
	for sfx_id in data:
		var stream := Sonidos.obtener_stream(sfx_id)
		assert(stream != null, "El sonido %s debe poder cargarse correctamente." % sfx_id)
		assert(stream.get_length() > 0.0, "La duración del sonido %s debe ser mayor a 0." % sfx_id)
		cargados += 1

	assert(cargados == 102, "Deben haberse cargado los 102 sonidos.")
	assert(Sonidos.cantidad_cargados() >= 102, "La caché interna debe contener al menos 102 streams.")
	print("OK: Validación de carga de los 102 archivos OGG.")


func test_reproduccion_2d() -> void:
	var p1 := Sonidos.reproducir("sfx_ui_boton_clic")
	assert(p1 != null, "reproducir() debe retornar una instancia de AudioStreamPlayer.")
	assert(p1.stream != null, "El player debe tener asignado el AudioStream.")
	assert(p1.volume_db == 0.0, "El volumen debe coincidir con el default.")

	# Reproducción con variación de pitch y volumen
	var p2 := Sonidos.reproducir("sfx_avatar_salto", -3.0, 0.05)
	assert(p2 != null, "reproducir() con parámetros debe ser válido.")
	assert(p2.volume_db == -3.0, "El volumen debe reflejar el offset.")
	assert(abs(p2.pitch_scale - 1.0) <= 0.06, "El pitch debe estar dentro de la tolerancia.")
	print("OK: Reproducción 2D y asignación de stream.")


func test_reproduccion_3d() -> void:
	var pos := Vector3(10.0, 5.0, -12.0)
	var p3d := Sonidos.reproducir_3d("sfx_puerta_abrir", pos, 1.5, 0.0, 40.0)
	assert(p3d != null, "reproducir_3d() debe retornar AudioStreamPlayer3D.")
	assert(p3d.global_position == pos, "La posición del player 3D debe coincidir con el argumento.")
	assert(p3d.max_distance == 40.0, "La distancia máxima debe coincidir.")
	assert(p3d.volume_db == 1.5, "El volumen debe coincidir.")
	print("OK: Reproducción 3D espacial.")


func test_tolerancia_fallos() -> void:
	var invalido := Sonidos.reproducir("sfx_inexistente_totalmente_inventado")
	assert(invalido == null, "Un ID inexistente debe retornar null sin causar error de ejecución.")

	var invalido_3d := Sonidos.reproducir_3d("sfx_inexistente_3d", Vector3.ZERO)
	assert(invalido_3d == null, "Un ID inexistente en 3D debe retornar null sin causar error.")
	print("OK: Tolerancia a fallos con IDs desconocidos.")


func test_modulacion_volumen_y_pitch() -> void:
	Sonidos.volumen_sfx_db = -6.0
	var p := Sonidos.reproducir("sfx_ui_hover", -2.0)
	assert(p != null, "Player debe ser válido.")
	assert(p.volume_db == -8.0, "El volumen final debe sumar el global y el offset (-6 + -2 = -8).")
	Sonidos.volumen_sfx_db = 0.0
	print("OK: Modulación de volumen.")


func test_deshabilitar_sfx() -> void:
	Sonidos.sfx_habilitado = false
	var p := Sonidos.reproducir("sfx_ui_boton_clic")
	assert(p == null, "Con sfx deshabilitado, reproducir debe retornar null.")
	Sonidos.sfx_habilitado = true
	print("OK: Deshabilitación y silencio global.")
