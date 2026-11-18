extends Node

## Suite de pruebas unitarias para VideoIntro.gd.

const VideoIntroScript = preload("res://scripts/VideoIntro.gd")

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_instanciacion_video_intro()
	test_stream_video()
	test_configuracion_escena_siguiente()


func test_instanciacion_video_intro() -> void:
	var intro := VideoIntroScript.new()
	intro.auto_iniciar = false
	add_child(intro)

	assert(intro._fondo != null, "VideoIntro debe tener fondo ColorRect.")
	assert(intro._fondo.color == Color.BLACK, "El fondo debe ser negro cinemático.")
	assert(intro._aspect_container != null, "VideoIntro debe tener AspectRatioContainer.")
	assert(is_equal_approx(intro._aspect_container.ratio, 16.0 / 9.0), "La relación de aspecto debe ser 16:9.")
	assert(intro._video_player != null, "VideoIntro debe contener un VideoStreamPlayer.")
	assert(intro._video_player.stream != null, "El VideoStreamPlayer debe tener el flujo de video cargado.")

	intro.queue_free()
	print("OK: Instanciación e interfaz de VideoIntro.")


func test_stream_video() -> void:
	assert(FileAccess.file_exists(VideoIntroScript.RUTA_VIDEO), "El archivo de video OGV debe existir en assets/video/.")
	var stream = VideoIntroScript.new()._cargar_stream_video(VideoIntroScript.RUTA_VIDEO)
	assert(stream != null, "El stream de video Theora debe cargarse correctamente.")
	print("OK: Carga de stream de video.")


func test_configuracion_escena_siguiente() -> void:
	assert(VideoIntroScript.ESCENA_SIGUIENTE == "res://scenes/Bienvenida.tscn", "La escena siguiente debe ser Bienvenida.tscn.")
	assert(ResourceLoader.exists(VideoIntroScript.ESCENA_SIGUIENTE), "La escena Bienvenida.tscn debe existir en el proyecto.")
	print("OK: Configuración y destino de transición a Bienvenida.")
