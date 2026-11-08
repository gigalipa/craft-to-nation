extends Control
class_name PantallaCarga

## Pantalla de carga asíncrona con fondo slideshow y barra de progreso de derecha a izquierda.
## Carga Main.tscn en segundo plano usando ResourceLoader.load_threaded_request sin congelar la ventana.

const ESCENA_OBJETIVO := "res://scenes/Main.tscn"

@export var auto_iniciar_carga: bool = true

var _slideshow: SlideshowFondo
var _panel_inferior: PanelContainer
var _lbl_estado: Label
var _barra_progreso: ProgressBar
var _lbl_porcentaje: Label

var _progreso_visual: float = 0.0
var _progreso_real: float = 0.0
var _carga_completada: bool = false
var _tiempo_minimo_transcurrido: float = 0.0
const TIEMPO_MINIMO_PANTALLA: float = 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1. Fondo Slideshow
	_slideshow = SlideshowFondo.new()
	_slideshow.intervalo_segundos = 6.0
	add_child(_slideshow)

	# 2. Contenedor inferior estilizado
	_construir_interfaz_carga()

	# 3. Iniciar carga threaded si corresponde
	if auto_iniciar_carga:
		iniciar_carga()


func iniciar_carga() -> void:
	ResourceLoader.load_threaded_request(ESCENA_OBJETIVO)


func _construir_interfaz_carga() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margen.add_theme_constant_override("margin_left", 60)
	margen.add_theme_constant_override("margin_right", 60)
	margen.add_theme_constant_override("margin_bottom", 40)
	add_child(margen)

	_panel_inferior = PanelContainer.new()
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.051, 0.129, 0.098, 0.92) # #0d2119eb
	style_box.border_color = Color(0.78, 0.62, 0.25, 0.9) # Oro #c79e40
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	style_box.content_margin_left = 24
	style_box.content_margin_right = 24
	style_box.content_margin_top = 16
	style_box.content_margin_bottom = 16
	_panel_inferior.add_theme_stylebox_override("panel", style_box)
	margen.add_child(_panel_inferior)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel_inferior.add_child(vbox)

	var hbox_header := HBoxContainer.new()
	vbox.add_child(hbox_header)

	_lbl_estado = Label.new()
	_lbl_estado.text = "Iniciando mundo..."
	_lbl_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_estado.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90, 1.0))
	_lbl_estado.add_theme_font_size_override("font_size", 16)
	hbox_header.add_child(_lbl_estado)

	_lbl_porcentaje = Label.new()
	_lbl_porcentaje.text = "0%"
	_lbl_porcentaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_porcentaje.add_theme_color_override("font_color", Color(0.78, 0.62, 0.25, 1.0))
	_lbl_porcentaje.add_theme_font_size_override("font_size", 16)
	hbox_header.add_child(_lbl_porcentaje)

	# Barra de carga de derecha a izquierda
	_barra_progreso = ProgressBar.new()
	_barra_progreso.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_barra_progreso.show_percentage = false
	_barra_progreso.custom_minimum_size = Vector2(0, 18)

	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.03, 0.07, 0.05, 0.95)
	bg_bar.set_corner_radius_all(4)
	_barra_progreso.add_theme_stylebox_override("background", bg_bar)

	var fill_bar := StyleBoxFlat.new()
	fill_bar.bg_color = Color(0.45, 0.90, 0.45, 0.95) # Verde esmeralda vivo
	fill_bar.border_color = Color(0.78, 0.62, 0.25, 1.0)
	fill_bar.set_border_width_all(1)
	fill_bar.set_corner_radius_all(4)
	_barra_progreso.add_theme_stylebox_override("fill", fill_bar)

	vbox.add_child(_barra_progreso)


func _process(delta: float) -> void:
	if not auto_iniciar_carga:
		return

	_tiempo_minimo_transcurrido += delta

	var progress_array: Array = []
	var status := ResourceLoader.load_threaded_get_status(ESCENA_OBJETIVO, progress_array)

	if not progress_array.is_empty():
		_progreso_real = float(progress_array[0]) * 100.0

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_progreso_real = 100.0

	# Interpolación fluida de la barra
	_progreso_visual = move_toward(_progreso_visual, _progreso_real, delta * 90.0)
	_barra_progreso.value = _progreso_visual
	_lbl_porcentaje.text = "%d%%" % int(_progreso_visual)

	# Mensajes dinámicos contextuales
	if _progreso_visual < 25.0:
		_lbl_estado.text = "Cargando sistemas y recursos..."
	elif _progreso_visual < 50.0:
		_lbl_estado.text = "Generando terreno procedural y biomas..."
	elif _progreso_visual < 75.0:
		_lbl_estado.text = "Trazando redes viales y canalizaciones..."
	elif _progreso_visual < 95.0:
		_lbl_estado.text = "Inicializando colonos y economía..."
	else:
		_lbl_estado.text = "¡Mundo listo!"

	# Verificar culminación
	if status == ResourceLoader.THREAD_LOAD_LOADED and _progreso_visual >= 99.0 and _tiempo_minimo_transcurrido >= TIEMPO_MINIMO_PANTALLA:
		if not _carga_completada:
			_carga_completada = true
			set_process(false)
			_finalizar_transicion()


func _finalizar_transicion() -> void:
	var escena_packed := ResourceLoader.load_threaded_get(ESCENA_OBJETIVO) as PackedScene
	if escena_packed != null:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		await tw.finished
		get_tree().change_scene_to_packed(escena_packed)
	else:
		get_tree().change_scene_to_file(ESCENA_OBJETIVO)
