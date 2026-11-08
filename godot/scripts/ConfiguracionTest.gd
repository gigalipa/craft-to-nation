extends Node

## Suite de pruebas unitarias para Configuracion.gd y la integración BGM en Sonidos.gd.

const Ajustes = preload("res://scripts/ajustes.gd")

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_inicializacion_configuracion()
	test_modificacion_y_senales()
	test_persistencia_guardar_y_cargar()
	test_variables_ajustes_persistencia()
	test_integracion_bgm_sonidos()


func test_variables_ajustes_persistencia() -> void:
	Configuracion.establecer_valor_ajuste("PLAYER_VELOCIDAD", 7.5)
	Configuracion.establecer_valor_ajuste("CAMARA_CENITAL_FOV", 75.0)
	Configuracion.aplicar()
	Configuracion.guardar()

	assert(abs(Ajustes.PLAYER_VELOCIDAD - 7.5) < 0.1, "Ajustes.PLAYER_VELOCIDAD debe actualizarse.")
	assert(abs(Player.VELOCIDAD - 7.5) < 0.1, "Player.VELOCIDAD debe actualizarse.")

	# Reiniciar y recargar
	Configuracion.cargar()
	assert(abs(float(Configuracion.obtener_valor_ajuste("PLAYER_VELOCIDAD")) - 7.5) < 0.1, "PLAYER_VELOCIDAD debe recargarse de disco.")

	# Restablecer por defecto
	Configuracion.restablecer_valores_defecto()
	assert(abs(float(Configuracion.obtener_valor_ajuste("PLAYER_VELOCIDAD")) - 5.0) < 0.1, "Debe restaurarse al default 5.0.")
	print("OK: Persistencia y aplicación de variables de balance de ajustes.gd.")


func test_inicializacion_configuracion() -> void:
	assert(Configuracion != null, "El autoload Configuracion debe estar activo.")
	assert(Configuracion.volumen_sfx >= 0.0 and Configuracion.volumen_sfx <= 1.0, "Volumen SFX fuera de rango.")
	assert(Configuracion.volumen_musica >= 0.0 and Configuracion.volumen_musica <= 1.0, "Volumen Música fuera de rango.")
	assert(Configuracion.sensibilidad_mouse > 0.0, "Sensibilidad debe ser positiva.")
	assert(Configuracion.fov_camara >= 50.0 and Configuracion.fov_camara <= 100.0, "FOV debe estar entre 50 y 100.")
	print("OK: Inicialización de Configuracion.")


func test_modificacion_y_senales() -> void:
	var cambios: Dictionary = {}
	var callback = func(clave: String, valor: Variant):
		cambios[clave] = valor
	Configuracion.configuracion_cambiada.connect(callback)

	Configuracion.volumen_sfx = 0.6
	assert(cambios.get("volumen_sfx") == 0.6, "La señal configuracion_cambiada debe reportar volumen_sfx.")
	assert(Sonidos.sfx_habilitado == true, "SFX debe seguir habilitado.")

	Configuracion.volumen_musica = 0.4
	assert(cambios.get("volumen_musica") == 0.4, "La señal configuracion_cambiada debe reportar volumen_musica.")

	Configuracion.sensibilidad_mouse = 0.005
	assert(Ajustes.PLAYER_SENSIBILIDAD_MOUSE == 0.005, "Ajustes.PLAYER_SENSIBILIDAD_MOUSE debe sincronizarse.")
	assert(Player.SENSIBILIDAD_MOUSE == 0.005, "Player.SENSIBILIDAD_MOUSE debe sincronizarse.")

	Configuracion.fov_camara = 85.0
	assert(Configuracion.fov_camara == 85.0, "FOV de cámara debe actualizarse a 85.0.")

	Configuracion.configuracion_cambiada.disconnect(callback)
	print("OK: Modificación reactiva y señales de Configuracion.")


func test_persistencia_guardar_y_cargar() -> void:
	Configuracion.volumen_sfx = 0.75
	Configuracion.volumen_musica = 0.65
	Configuracion.sensibilidad_mouse = 0.0045
	Configuracion.fov_camara = 78.0
	Configuracion.idioma = "es"

	var guardado_exitoso := Configuracion.guardar()
	assert(guardado_exitoso, "Configuracion.guardar() debe retornar true.")
	assert(FileAccess.file_exists(Configuracion.RUTA_CONFIG), "El archivo configuracion.json debe existir en user://")

	# Modifica temporalmente en memoria
	Configuracion.volumen_sfx = 0.1
	Configuracion.volumen_musica = 0.1
	assert(Configuracion.volumen_sfx == 0.1, "Debe haberse modificado localmente.")

	# Carga de nuevo desde disco
	Configuracion.cargar()
	assert(abs(Configuracion.volumen_sfx - 0.75) < 0.01, "volumen_sfx debe restaurarse.")
	assert(abs(Configuracion.volumen_musica - 0.65) < 0.01, "volumen_musica debe restaurarse.")
	assert(abs(Configuracion.sensibilidad_mouse - 0.0045) < 0.0001, "sensibilidad_mouse debe restaurarse.")
	assert(abs(Configuracion.fov_camara - 78.0) < 0.1, "fov_camara debe restaurarse.")
	# Restaurar valores por defecto para no afectar otras pruebas
	Configuracion.volumen_sfx = 1.0
	Configuracion.volumen_musica = 0.8
	Configuracion.sensibilidad_mouse = 0.003
	Configuracion.fov_camara = 70.0
	Configuracion.idioma = "es"
	Configuracion.guardar()
	print("OK: Persistencia en user://configuracion.json.")


func test_integracion_bgm_sonidos() -> void:
	assert(Sonidos._player_musica != null, "Sonidos debe tener un AudioStreamPlayer para música.")
	assert(Sonidos._player_musica.process_mode == Node.PROCESS_MODE_ALWAYS, "El player de música debe correr en pausa.")

	# Probar música de menú
	Sonidos.reproducir_musica_menu()
	assert(Sonidos._player_musica.stream != null, "La música de menú debe haber cargado un stream.")

	# Probar detención
	Sonidos.detener_musica()
	assert(not Sonidos._player_musica.playing, "La música debe haberse detenido.")

	# Probar música de juego
	Sonidos.reproducir_musica_juego()
	assert(Sonidos._player_musica.stream != null, "La música de juego debe haber cargado un stream.")
	Sonidos.detener_musica()

	print("OK: Integración BGM en Sonidos.")
