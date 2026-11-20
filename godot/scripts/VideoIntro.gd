extends Control
class_name VideoIntro

## Reproductor cinematográfico de video introductorio (Intro Video / Logo Reveal).
## Se reproduce antes del splash de Craft to Nation (Bienvenida.tscn).
## Soporta salto con tecla o clic y escala con letterboxing 16:9.

const RUTA_VIDEO := "res://assets/video/DPD_Logo_Reveal.ogv"
const ESCENA_SIGUIENTE := "res://scenes/Bienvenida.tscn"
const DURACION_FADE_OUT: float = 0.4

@export var auto_iniciar: bool = true

var _fondo: ColorRect
var _aspect_container: AspectRatioContainer
var _video_player: VideoStreamPlayer
var _transicionando: bool = false


func _ready() -> void:
	if Configuracion != null and Configuracion.has_method("aplicar_modo_pantalla"):
		Configuracion.aplicar_modo_pantalla()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fondo negro cinemático
	_fondo = ColorRect.new()
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.color = Color.BLACK
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)

	# Contenedor con relación de aspecto 16:9 (1280x720)
	_aspect_container = AspectRatioContainer.new()
	_aspect_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aspect_container.ratio = 16.0 / 9.0
	_aspect_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_aspect_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aspect_container)

	# Reproductor de video
	_video_player = VideoStreamPlayer.new()
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aspect_container.add_child(_video_player)

	# Cargar flujo de video
	var stream_recurso = _cargar_stream_video(RUTA_VIDEO)
	if stream_recurso != null:
		_video_player.stream = stream_recurso
		_video_player.finished.connect(_on_video_finalizado)
		if auto_iniciar and DisplayServer.get_name() != "headless":
			_video_player.play()
	else:
		push_warning("VideoIntro: No se pudo cargar el video '%s'. Avanzando a bienvenida..." % RUTA_VIDEO)
		if auto_iniciar:
			call_deferred("_avanzar_a_bienvenida")


func _cargar_stream_video(ruta: String) -> VideoStream:
	if ResourceLoader.exists(ruta):
		var s = load(ruta) as VideoStream
		if s != null:
			return s

	if FileAccess.file_exists(ruta):
		var theora := VideoStreamTheora.new()
		theora.file = ruta
		return theora

	return null


func _on_video_finalizado() -> void:
	_avanzar_a_bienvenida()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_avanzar_a_bienvenida()
	elif event is InputEventMouseButton and event.pressed:
		_avanzar_a_bienvenida()


func _avanzar_a_bienvenida() -> void:
	if _transicionando:
		return
	_transicionando = true
	set_process_unhandled_input(false)

	if _video_player != null and _video_player.is_playing():
		_video_player.stop()

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, DURACION_FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	get_tree().change_scene_to_file(ESCENA_SIGUIENTE)
