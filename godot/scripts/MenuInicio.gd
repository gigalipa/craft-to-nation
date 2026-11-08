extends Control

## Menú de Inicio principal de Craft to Nation.
## Punto de entrada tras la pantalla de bienvenida.
## Presenta fondo de slideshow dinámico con oscurecimiento, cabecera oficial con logos,
## acceso a nueva partida y carga con pantalla asíncrona, panel de configuración extendido e iconos vectoriales.

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")

const RUTA_LOGO_EMBLEMA := "res://assets/logo/craft-to-nation-logo.png"
const RUTA_LOGO_TEXTO := "res://assets/logo/craft_to_nation_text.png"
const ESCENA_PANTALLA_CARGA := "res://scenes/PantallaCarga.tscn"

var _slideshow: SlideshowFondo
var _panel_centro: PanelContainer
var _vbox_centro: VBoxContainer

var _panel_principal: VBoxContainer
var _panel_cargar: VBoxContainer
var _panel_configuracion: PanelConfiguracionAjustes

var _vbox_lista_guardados: VBoxContainer
var _lbl_notificacion: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_construir_ui()
	Sonidos.reproducir_musica_menu()


func _construir_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 1. Fondo de Slideshow con imágenes de juego y oscurecimiento para legibilidad
	_slideshow = SlideshowFondo.new()
	_slideshow.intervalo_segundos = 10.0
	_slideshow.duracion_fade = 1.2
	_slideshow.oscurecimiento = 0.45
	add_child(_slideshow)

	# 2. Panel central estilizado
	_panel_centro = PanelContainer.new()
	_panel_centro.custom_minimum_size = Vector2(560, 560)
	_panel_centro.set_anchors_preset(Control.PRESET_CENTER)
	_panel_centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel_centro.add_theme_stylebox_override("panel", TemaHUD.caja(Color("#0d2119f0"), TemaHUD.DORADO))
	add_child(_panel_centro)

	_vbox_centro = VBoxContainer.new()
	_vbox_centro.add_theme_constant_override("separation", 14)
	_panel_centro.add_child(_vbox_centro)

	# 3. Cabecera oficial con logotipo y texto gráfico
	_construir_cabecera_logos()

	# 4. Etiqueta de notificación
	_lbl_notificacion = Label.new()
	_lbl_notificacion.text = ""
	_lbl_notificacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_notificacion.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_VERDE)
	_lbl_notificacion.add_theme_font_size_override("font_size", 13)
	_lbl_notificacion.visible = false
	_vbox_centro.add_child(_lbl_notificacion)

	# 5. Subpaneles
	_construir_panel_principal()
	_construir_panel_cargar()
	_construir_panel_configuracion()

	_mostrar_subpanel(_panel_principal)

	# 6. Versión en el pie
	var lbl_version := Label.new()
	lbl_version.text = "v0.5.0 - Early Alpha"
	lbl_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_version.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
	lbl_version.add_theme_font_size_override("font_size", 11)
	_vbox_centro.add_child(lbl_version)


func _construir_cabecera_logos() -> void:
	var vbox_header := VBoxContainer.new()
	vbox_header.add_theme_constant_override("separation", 6)
	_vbox_centro.add_child(vbox_header)

	var hbox_logos := HBoxContainer.new()
	hbox_logos.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_logos.add_theme_constant_override("separation", 12)
	vbox_header.add_child(hbox_logos)

	var tex_emblema := SlideshowFondo.cargar_textura(RUTA_LOGO_EMBLEMA)
	if tex_emblema != null:
		var rect_emblema := TextureRect.new()
		rect_emblema.custom_minimum_size = Vector2(48, 48)
		rect_emblema.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect_emblema.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect_emblema.texture = tex_emblema
		hbox_logos.add_child(rect_emblema)

	var tex_texto := SlideshowFondo.cargar_textura(RUTA_LOGO_TEXTO)
	if tex_texto != null:
		var rect_texto := TextureRect.new()
		rect_texto.custom_minimum_size = Vector2(260, 40)
		rect_texto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect_texto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect_texto.texture = tex_texto
		hbox_logos.add_child(rect_texto)
	else:
		var lbl_fallback := Label.new()
		lbl_fallback.text = "CRAFT TO NATION"
		lbl_fallback.add_theme_color_override("font_color", TemaHUD.DORADO)
		lbl_fallback.add_theme_font_size_override("font_size", 26)
		hbox_logos.add_child(lbl_fallback)

	var lbl_subtitulo := Label.new()
	lbl_subtitulo.text = "Voxel Colony Sim & Industrial Automation"
	lbl_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_subtitulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	lbl_subtitulo.add_theme_font_size_override("font_size", 12)
	vbox_header.add_child(lbl_subtitulo)


func _construir_panel_principal() -> void:
	_panel_principal = VBoxContainer.new()
	_panel_principal.add_theme_constant_override("separation", 12)
	_vbox_centro.add_child(_panel_principal)

	var btn_nueva := Button.new()
	btn_nueva.text = "Nueva Partida"
	btn_nueva.icon = IconosHUD.icono("menu_nueva_partida")
	btn_nueva.add_theme_constant_override("icon_max_width", 22)
	btn_nueva.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(btn_nueva)
	btn_nueva.pressed.connect(_on_nueva_partida_pressed)
	_panel_principal.add_child(btn_nueva)

	var btn_cargar := Button.new()
	btn_cargar.text = "Cargar Partida"
	btn_cargar.icon = IconosHUD.icono("menu_cargar_partida")
	btn_cargar.add_theme_constant_override("icon_max_width", 22)
	btn_cargar.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(btn_cargar)
	btn_cargar.pressed.connect(_abrir_panel_cargar)
	_panel_principal.add_child(btn_cargar)

	var btn_config := Button.new()
	btn_config.text = "Configuración"
	btn_config.icon = IconosHUD.icono("menu_configuracion")
	btn_config.add_theme_constant_override("icon_max_width", 22)
	btn_config.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(btn_config)
	btn_config.pressed.connect(_abrir_panel_configuracion)
	_panel_principal.add_child(btn_config)

	var separador := HSeparator.new()
	separador.add_theme_constant_override("separation", 8)
	_panel_principal.add_child(separador)

	var btn_salir := Button.new()
	btn_salir.text = "Salir"
	btn_salir.icon = IconosHUD.icono("menu_salir")
	btn_salir.add_theme_constant_override("icon_max_width", 22)
	btn_salir.custom_minimum_size = Vector2(0, 40)
	TemaHUD.estilizar_boton(btn_salir)
	btn_salir.pressed.connect(_on_salir_pressed)
	_panel_principal.add_child(btn_salir)


func _construir_panel_cargar() -> void:
	_panel_cargar = VBoxContainer.new()
	_panel_cargar.add_theme_constant_override("separation", 10)
	_vbox_centro.add_child(_panel_cargar)

	var lbl := Label.new()
	lbl.text = "Seleccionar Partida"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_panel_cargar.add_child(lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_cargar.add_child(scroll)

	_vbox_lista_guardados = VBoxContainer.new()
	_vbox_lista_guardados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_lista_guardados.add_theme_constant_override("separation", 6)
	scroll.add_child(_vbox_lista_guardados)

	var btn_volver := Button.new()
	btn_volver.text = "Volver"
	btn_volver.icon = IconosHUD.icono("menu_volver")
	btn_volver.add_theme_constant_override("icon_max_width", 20)
	TemaHUD.estilizar_boton(btn_volver)
	btn_volver.pressed.connect(func(): _mostrar_subpanel(_panel_principal))
	_panel_cargar.add_child(btn_volver)


func _construir_panel_configuracion() -> void:
	_panel_configuracion = PanelConfiguracionAjustes.new()
	_panel_configuracion.guardado_completado.connect(func(msg):
		_mostrar_notificacion(msg)
	)
	_panel_configuracion.volver_solicitado.connect(func():
		_mostrar_subpanel(_panel_principal)
	)
	_vbox_centro.add_child(_panel_configuracion)


func _mostrar_subpanel(subpanel: Control) -> void:
	_panel_principal.visible = (subpanel == _panel_principal)
	_panel_cargar.visible = (subpanel == _panel_cargar)
	_panel_configuracion.visible = (subpanel == _panel_configuracion)


func _mostrar_notificacion(msg: String) -> void:
	_lbl_notificacion.text = msg
	_lbl_notificacion.visible = true


func _on_nueva_partida_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	GestorPartida.reiniciar_partida()
	GestorPartida.partida_pendiente_a_cargar = ""
	get_tree().change_scene_to_file(ESCENA_PANTALLA_CARGA)


func _abrir_panel_cargar() -> void:
	_mostrar_subpanel(_panel_cargar)
	_actualizar_lista_guardados()


func _actualizar_lista_guardados() -> void:
	for child in _vbox_lista_guardados.get_children():
		child.queue_free()

	var lista := GestorPartida.listar_partidas()
	if lista.is_empty():
		var lbl_vacio := Label.new()
		lbl_vacio.text = "No se encontraron partidas guardadas."
		lbl_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_vacio.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
		_vbox_lista_guardados.add_child(lbl_vacio)
		return

	for p in lista:
		var panel_item := PanelContainer.new()
		panel_item.add_theme_stylebox_override("panel", TemaHUD.caja(Color(0.08, 0.2, 0.15, 0.8), TemaHUD.DORADO))
		_vbox_lista_guardados.add_child(panel_item)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		panel_item.add_child(hbox)

		var vbox_info := VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox_info)

		var lbl_nom := Label.new()
		lbl_nom.text = str(p.get("nombre_partida", "Sin nombre"))
		lbl_nom.add_theme_color_override("font_color", TemaHUD.DORADO)
		lbl_nom.add_theme_font_size_override("font_size", 14)
		vbox_info.add_child(lbl_nom)

		var lbl_detalles := Label.new()
		var fecha: String = str(p.get("fecha_guardado", ""))
		var pob: int = int(p.get("poblacion", 0))
		lbl_detalles.text = "%s  |  Población: %d" % [fecha, pob]
		lbl_detalles.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_ATENUADO)
		lbl_detalles.add_theme_font_size_override("font_size", 11)
		vbox_info.add_child(lbl_detalles)

		var btn_cargar := Button.new()
		btn_cargar.text = "Cargar"
		btn_cargar.icon = IconosHUD.icono("menu_cargar")
		btn_cargar.add_theme_constant_override("icon_max_width", 18)
		TemaHUD.estilizar_boton_icono(btn_cargar)
		var arch_name: String = str(p.get("nombre_archivo", ""))
		btn_cargar.pressed.connect(func(): _cargar_partida_seleccionada(arch_name))
		hbox.add_child(btn_cargar)

		var btn_eliminar := Button.new()
		btn_eliminar.text = "X"
		btn_eliminar.icon = IconosHUD.icono("cruz")
		btn_eliminar.add_theme_constant_override("icon_max_width", 16)
		TemaHUD.estilizar_boton_icono(btn_eliminar)
		btn_eliminar.pressed.connect(func():
			GestorPartida.eliminar_partida(arch_name)
			_actualizar_lista_guardados()
		)
		hbox.add_child(btn_eliminar)


func _cargar_partida_seleccionada(nombre_archivo: String) -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	GestorPartida.partida_pendiente_a_cargar = nombre_archivo
	get_tree().change_scene_to_file(ESCENA_PANTALLA_CARGA)


func _abrir_panel_configuracion() -> void:
	_mostrar_subpanel(_panel_configuracion)
	_panel_configuracion.sincronizar_desde_configuracion()


func _on_salir_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	get_tree().quit(0)
