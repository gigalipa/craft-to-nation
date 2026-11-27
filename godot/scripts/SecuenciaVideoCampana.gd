extends Control

## Reproductor de video narrativo para Prólogo (desde MenuInicio) y Epílogo
## (overlay sobre Main con opciones Post-Epílogo sin pérdida de progreso).
## Si el archivo .ogv aún no existe en res://assets/video/, muestra una
## tarjeta narrativa estilizada como fallback limpio.

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")

signal continuar_ciudad_solicitado
signal nueva_nacion_solicitada

const ESCENA_PANTALLA_CARGA := "res://scenes/PantallaCarga.tscn"

@export var es_epilogo: bool = false
@export var auto_iniciar: bool = true

var _fondo: ColorRect
var _aspect_container: AspectRatioContainer
var _video_player: VideoStreamPlayer
var _panel_fallback: PanelContainer
var _panel_post_epilogo: PanelContainer
var _btn_saltar: Button
var _transicionando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_fondo = ColorRect.new()
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.color = Color(0.02, 0.03, 0.04, 0.96 if es_epilogo else 1.0)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)

	_aspect_container = AspectRatioContainer.new()
	_aspect_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aspect_container.ratio = 16.0 / 9.0
	_aspect_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_aspect_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aspect_container)

	_video_player = VideoStreamPlayer.new()
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aspect_container.add_child(_video_player)

	_construir_fallback_narrativo()
	_construir_panel_post_epilogo()

	_btn_saltar = Button.new()
	_btn_saltar.text = Strings.t("CAMPANA_SALTAR_VIDEO", "Saltar")
	_btn_saltar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_btn_saltar.offset_left = -150
	_btn_saltar.offset_top = -62
	_btn_saltar.offset_right = -24
	_btn_saltar.offset_bottom = -20
	TemaHUD.estilizar_boton(_btn_saltar)
	_btn_saltar.pressed.connect(_on_saltar_o_finalizar)
	add_child(_btn_saltar)

	if auto_iniciar:
		_iniciar_reproduccion()


func _construir_fallback_narrativo() -> void:
	_panel_fallback = PanelContainer.new()
	_panel_fallback.custom_minimum_size = Vector2(620, 260)
	_panel_fallback.set_anchors_preset(Control.PRESET_CENTER)
	_panel_fallback.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_fallback.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel_fallback.add_theme_stylebox_override("panel", TemaHUD.caja())
	_panel_fallback.visible = false
	add_child(_panel_fallback)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_panel_fallback.add_child(vbox)

	var lbl_titulo := Label.new()
	lbl_titulo.text = Strings.t("CAMPANA_TITULO_EPILOGO", "Epílogo: El Despertar") if es_epilogo else Strings.t("CAMPANA_TITULO_PROLOGO", "Prólogo: La Fractura Multiversal")
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_color_override("font_color", TemaHUD.DORADO)
	lbl_titulo.add_theme_font_size_override("font_size", 22)
	vbox.add_child(lbl_titulo)

	var lbl_desc := Label.new()
	lbl_desc.text = Strings.t("CAMPANA_RESUMEN_EPILOGO", "") if es_epilogo else Strings.t("CAMPANA_RESUMEN_PROLOGO", "")
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.add_theme_color_override("font_color", TemaHUD.TEXTO)
	lbl_desc.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl_desc)

	var btn_cont := Button.new()
	btn_cont.text = Strings.t("CAMPANA_SALTAR_VIDEO", "Continuar") if es_epilogo else Strings.t("CAMPANA_CONTINUAR_VIDEO_PLACEHOLDER", "Comenzar aventura")
	btn_cont.custom_minimum_size = Vector2(240, 44)
	btn_cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	TemaHUD.estilizar_boton(btn_cont)
	btn_cont.pressed.connect(_on_saltar_o_finalizar)
	vbox.add_child(btn_cont)


func _construir_panel_post_epilogo() -> void:
	_panel_post_epilogo = PanelContainer.new()
	_panel_post_epilogo.custom_minimum_size = Vector2(560, 260)
	_panel_post_epilogo.set_anchors_preset(Control.PRESET_CENTER)
	_panel_post_epilogo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_post_epilogo.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel_post_epilogo.add_theme_stylebox_override("panel", TemaHUD.caja())
	_panel_post_epilogo.visible = false
	add_child(_panel_post_epilogo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel_post_epilogo.add_child(vbox)

	var lbl_tit := Label.new()
	lbl_tit.text = Strings.t("CAMPANA_TITULO_EPILOGO", "Epílogo: El Despertar")
	lbl_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tit.add_theme_color_override("font_color", TemaHUD.DORADO)
	lbl_tit.add_theme_font_size_override("font_size", 22)
	vbox.add_child(lbl_tit)

	var lbl_msg := Label.new()
	lbl_msg.text = Strings.t("CAMPANA_POST_EPILOGO_TITULO", "Has completado el despertar de tu civilización.\nTu ciudad sigue viva y el continente apenas comienza a revelarse.")
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.add_theme_color_override("font_color", TemaHUD.TEXTO)
	lbl_msg.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_msg)

	var btn_ciudad := Button.new()
	btn_ciudad.text = Strings.t("CAMPANA_BTN_CONTINUAR_CIUDAD", "Continuar en esta ciudad (Modo Libre)")
	btn_ciudad.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(btn_ciudad)
	btn_ciudad.pressed.connect(func(): continuar_ciudad_solicitado.emit())
	vbox.add_child(btn_ciudad)

	var btn_nueva := Button.new()
	btn_nueva.text = Strings.t("CAMPANA_BTN_NUEVA_NACION", "Iniciar una nueva nación")
	btn_nueva.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(btn_nueva)
	btn_nueva.pressed.connect(func(): nueva_nacion_solicitada.emit())
	vbox.add_child(btn_nueva)


func _iniciar_reproduccion() -> void:
	var ruta: String = Ajustes.CAMPANA_RUTA_VIDEO_EPILOGO if es_epilogo else Ajustes.CAMPANA_RUTA_VIDEO_PROLOGO
	var stream := _cargar_stream_video(ruta)
	if stream != null and DisplayServer.get_name() != "headless":
		if Sonidos != null and Sonidos.has_method("detener_musica"):
			Sonidos.detener_musica()
		_video_player.stream = stream
		if not _video_player.finished.is_connected(_on_saltar_o_finalizar):
			_video_player.finished.connect(_on_saltar_o_finalizar)
		_video_player.play()
		_panel_fallback.visible = false
	else:
		_panel_fallback.visible = true


func _cargar_stream_video(ruta: String) -> VideoStream:
	if ResourceLoader.exists(ruta):
		var s := load(ruta) as VideoStream
		if s != null:
			return s
	if FileAccess.file_exists(ruta):
		var theora := VideoStreamTheora.new()
		theora.file = ruta
		return theora
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _panel_post_epilogo.visible:
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_saltar_o_finalizar()
		get_viewport().set_input_as_handled()


func _on_saltar_o_finalizar() -> void:
	if _transicionando:
		return
	if _video_player != null and _video_player.is_playing():
		_video_player.stop()

	if es_epilogo:
		_panel_fallback.visible = false
		_aspect_container.visible = false
		_btn_saltar.visible = false
		_panel_post_epilogo.visible = true
		return

	_transicionando = true
	if GestorPartida != null:
		GestorPartida.reiniciar_partida()
		GestorPartida.partida_pendiente_a_cargar = ""
	get_tree().change_scene_to_file(ESCENA_PANTALLA_CARGA)
