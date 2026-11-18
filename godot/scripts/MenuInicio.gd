extends Control

## Menú de Inicio principal de Craft to Nation.
## Punto de entrada tras la pantalla de bienvenida.
## Presenta fondo de slideshow dinámico con oscurecimiento, cabecera oficial con logos,
## acceso a nueva partida y carga con pantalla asíncrona, panel de configuración extendido e iconos vectoriales.
## Compatible con localización dinámica en tiempo real (Español / Inglés).

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")

const RUTA_LOGO_EMBLEMA := "res://assets/logo/craft-to-nation-logo.png"
const RUTA_LOGO_TEXTO := "res://assets/logo/craft_to_nation_text.png"
const ESCENA_PANTALLA_CARGA := "res://scenes/PantallaCarga.tscn"

var _slideshow: SlideshowFondo
var _panel_centro: PanelContainer
var _vbox_centro: VBoxContainer

var _panel_principal: VBoxContainer
var _panel_nueva_partida: VBoxContainer
var _panel_cargar: VBoxContainer
var _panel_configuracion: PanelConfiguracionAjustes

var _vbox_lista_guardados: VBoxContainer
var _lbl_notificacion: Label
var _lbl_subtitulo: Label

# Botones y etiquetas localizables
var _btn_nueva: Button
var _btn_cargar: Button
var _btn_config: Button
var _btn_salir: Button
var _lbl_seleccionar_partida: Label
var _btn_volver_cargar: Button

# Componentes del modal Nueva Partida
var _lbl_nueva_partida_titulo: Label
var _lbl_nueva_partida_desc: Label
var _btn_mundo_aleatorio: Button
var _btn_agregar_semilla: Button
var _contenedor_input_semilla: VBoxContainer
var _lbl_input_semilla: Label
var _input_semilla: LineEdit
var _btn_iniciar_con_semilla: Button
var _btn_volver_nueva: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_construir_ui()
	Sonidos.reproducir_musica_menu()
	Configuracion.configuracion_cambiada.connect(_on_configuracion_cambiada)
	_actualizar_textos_idioma()


func _on_configuracion_cambiada(clave: String, _valor: Variant) -> void:
	if clave == "idioma":
		_actualizar_textos_idioma()


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
	_construir_panel_nueva_partida()
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

	_lbl_subtitulo = Label.new()
	_lbl_subtitulo.text = Strings.t("MENU_SUBTITULO", "Voxel Colony Sim & Industrial Automation")
	_lbl_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_subtitulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_lbl_subtitulo.add_theme_font_size_override("font_size", 12)
	vbox_header.add_child(_lbl_subtitulo)


func _construir_panel_principal() -> void:
	_panel_principal = VBoxContainer.new()
	_panel_principal.add_theme_constant_override("separation", 12)
	_vbox_centro.add_child(_panel_principal)

	_btn_nueva = Button.new()
	_btn_nueva.text = Strings.t("MENU_NUEVA_PARTIDA", "Nueva Partida")
	_btn_nueva.icon = IconosHUD.icono("menu_nueva_partida")
	_btn_nueva.add_theme_constant_override("icon_max_width", 22)
	_btn_nueva.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(_btn_nueva)
	_btn_nueva.pressed.connect(_on_nueva_partida_pressed)
	_panel_principal.add_child(_btn_nueva)

	_btn_cargar = Button.new()
	_btn_cargar.text = Strings.t("MENU_CARGAR_PARTIDA", "Cargar Partida")
	_btn_cargar.icon = IconosHUD.icono("menu_cargar_partida")
	_btn_cargar.add_theme_constant_override("icon_max_width", 22)
	_btn_cargar.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(_btn_cargar)
	_btn_cargar.pressed.connect(_abrir_panel_cargar)
	_panel_principal.add_child(_btn_cargar)

	_btn_config = Button.new()
	_btn_config.text = Strings.t("MENU_CONFIGURACION", "Configuración")
	_btn_config.icon = IconosHUD.icono("menu_configuracion")
	_btn_config.add_theme_constant_override("icon_max_width", 22)
	_btn_config.custom_minimum_size = Vector2(0, 44)
	TemaHUD.estilizar_boton(_btn_config)
	_btn_config.pressed.connect(_abrir_panel_configuracion)
	_panel_principal.add_child(_btn_config)

	var separador := HSeparator.new()
	separador.add_theme_constant_override("separation", 8)
	_panel_principal.add_child(separador)

	_btn_salir = Button.new()
	_btn_salir.text = Strings.t("MENU_SALIR", "Salir")
	_btn_salir.icon = IconosHUD.icono("menu_salir")
	_btn_salir.add_theme_constant_override("icon_max_width", 22)
	_btn_salir.custom_minimum_size = Vector2(0, 40)
	TemaHUD.estilizar_boton(_btn_salir)
	_btn_salir.pressed.connect(_on_salir_pressed)
	_panel_principal.add_child(_btn_salir)


func _construir_panel_nueva_partida() -> void:
	_panel_nueva_partida = VBoxContainer.new()
	_panel_nueva_partida.add_theme_constant_override("separation", 10)
	_vbox_centro.add_child(_panel_nueva_partida)

	_lbl_nueva_partida_titulo = Label.new()
	_lbl_nueva_partida_titulo.text = Strings.t("MENU_NUEVA_PARTIDA_TITULO", "Nueva Partida")
	_lbl_nueva_partida_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_nueva_partida_titulo.add_theme_color_override("font_color", TemaHUD.DORADO)
	_lbl_nueva_partida_titulo.add_theme_font_size_override("font_size", 16)
	_panel_nueva_partida.add_child(_lbl_nueva_partida_titulo)

	_lbl_nueva_partida_desc = Label.new()
	_lbl_nueva_partida_desc.text = Strings.t("MENU_NUEVA_PARTIDA_DESC", "Elige cómo deseas generar tu mundo:")
	_lbl_nueva_partida_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_nueva_partida_desc.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_lbl_nueva_partida_desc.add_theme_font_size_override("font_size", 12)
	_panel_nueva_partida.add_child(_lbl_nueva_partida_desc)

	_btn_mundo_aleatorio = Button.new()
	_btn_mundo_aleatorio.text = Strings.t("MENU_GENERAR_ALEATORIO", "Generar mundo aleatorio")
	_btn_mundo_aleatorio.icon = IconosHUD.icono("menu_nueva_partida")
	_btn_mundo_aleatorio.add_theme_constant_override("icon_max_width", 22)
	_btn_mundo_aleatorio.custom_minimum_size = Vector2(0, 42)
	TemaHUD.estilizar_boton(_btn_mundo_aleatorio)
	_btn_mundo_aleatorio.pressed.connect(_iniciar_mundo_aleatorio)
	_panel_nueva_partida.add_child(_btn_mundo_aleatorio)

	_btn_agregar_semilla = Button.new()
	_btn_agregar_semilla.text = Strings.t("MENU_AGREGAR_SEMILLA", "Agregar semilla")
	_btn_agregar_semilla.icon = IconosHUD.icono("menu_configuracion")
	_btn_agregar_semilla.add_theme_constant_override("icon_max_width", 20)
	_btn_agregar_semilla.custom_minimum_size = Vector2(0, 38)
	TemaHUD.estilizar_boton(_btn_agregar_semilla)
	_btn_agregar_semilla.pressed.connect(func():
		_contenedor_input_semilla.visible = not _contenedor_input_semilla.visible
	)
	_panel_nueva_partida.add_child(_btn_agregar_semilla)

	_contenedor_input_semilla = VBoxContainer.new()
	_contenedor_input_semilla.add_theme_constant_override("separation", 6)
	_contenedor_input_semilla.visible = false
	_panel_nueva_partida.add_child(_contenedor_input_semilla)

	_lbl_input_semilla = Label.new()
	_lbl_input_semilla.text = Strings.t("MENU_SEMILLA_LABEL", "Semilla del Mundo:")
	_lbl_input_semilla.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_input_semilla.add_theme_font_size_override("font_size", 12)
	_contenedor_input_semilla.add_child(_lbl_input_semilla)

	_input_semilla = LineEdit.new()
	_input_semilla.placeholder_text = Strings.t("MENU_SEMILLA_PLACEHOLDER", "Escribe o pega una semilla...")
	_input_semilla.custom_minimum_size = Vector2(0, 34)
	_contenedor_input_semilla.add_child(_input_semilla)

	_btn_iniciar_con_semilla = Button.new()
	_btn_iniciar_con_semilla.text = Strings.t("MENU_INICIAR_PARTIDA", "Iniciar Partida")
	_btn_iniciar_con_semilla.icon = IconosHUD.icono("menu_cargar")
	_btn_iniciar_con_semilla.add_theme_constant_override("icon_max_width", 18)
	_btn_iniciar_con_semilla.custom_minimum_size = Vector2(0, 38)
	TemaHUD.estilizar_boton(_btn_iniciar_con_semilla)
	_btn_iniciar_con_semilla.pressed.connect(_iniciar_con_semilla_ingresada)
	_contenedor_input_semilla.add_child(_btn_iniciar_con_semilla)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	_panel_nueva_partida.add_child(sep)

	_btn_volver_nueva = Button.new()
	_btn_volver_nueva.text = Strings.t("MENU_VOLVER", "Volver")
	_btn_volver_nueva.icon = IconosHUD.icono("menu_volver")
	_btn_volver_nueva.add_theme_constant_override("icon_max_width", 20)
	TemaHUD.estilizar_boton(_btn_volver_nueva)
	_btn_volver_nueva.pressed.connect(func(): _mostrar_subpanel(_panel_principal))
	_panel_nueva_partida.add_child(_btn_volver_nueva)


func _iniciar_mundo_aleatorio() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	var semilla_aleatoria: int = randi_range(10000000, 99999999)
	Ajustes.SEMILLA = semilla_aleatoria
	Ajustes.SEMILLA_MUNDO = semilla_aleatoria
	GestorPartida.reiniciar_partida()
	GestorPartida.partida_pendiente_a_cargar = ""
	get_tree().change_scene_to_file(ESCENA_PANTALLA_CARGA)


func _iniciar_con_semilla_ingresada() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	var txt := _input_semilla.text.strip_edges()
	var semilla_elegida: int = Ajustes.SEMILLA_DEF
	if not txt.is_empty():
		if txt.is_valid_int():
			semilla_elegida = int(txt)
		else:
			semilla_elegida = int(txt.hash() & 0x7FFFFFFF)
	Ajustes.SEMILLA = semilla_elegida
	Ajustes.SEMILLA_MUNDO = semilla_elegida
	GestorPartida.reiniciar_partida()
	GestorPartida.partida_pendiente_a_cargar = ""
	get_tree().change_scene_to_file(ESCENA_PANTALLA_CARGA)


func _construir_panel_cargar() -> void:
	_panel_cargar = VBoxContainer.new()
	_panel_cargar.add_theme_constant_override("separation", 10)
	_vbox_centro.add_child(_panel_cargar)

	_lbl_seleccionar_partida = Label.new()
	_lbl_seleccionar_partida.text = Strings.t("MENU_SELECCIONAR_PARTIDA", "Seleccionar Partida")
	_lbl_seleccionar_partida.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_seleccionar_partida.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_panel_cargar.add_child(_lbl_seleccionar_partida)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_cargar.add_child(scroll)

	_vbox_lista_guardados = VBoxContainer.new()
	_vbox_lista_guardados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_lista_guardados.add_theme_constant_override("separation", 6)
	scroll.add_child(_vbox_lista_guardados)

	_btn_volver_cargar = Button.new()
	_btn_volver_cargar.text = Strings.t("MENU_VOLVER", "Volver")
	_btn_volver_cargar.icon = IconosHUD.icono("menu_volver")
	_btn_volver_cargar.add_theme_constant_override("icon_max_width", 20)
	TemaHUD.estilizar_boton(_btn_volver_cargar)
	_btn_volver_cargar.pressed.connect(func(): _mostrar_subpanel(_panel_principal))
	_panel_cargar.add_child(_btn_volver_cargar)


func _construir_panel_configuracion() -> void:
	_panel_configuracion = PanelConfiguracionAjustes.new()
	_panel_configuracion.guardado_completado.connect(func(msg):
		_mostrar_notificacion(msg)
	)
	_panel_configuracion.volver_solicitado.connect(func():
		_mostrar_subpanel(_panel_principal)
	)
	_vbox_centro.add_child(_panel_configuracion)


func _actualizar_textos_idioma() -> void:
	if _btn_nueva != null:
		_btn_nueva.text = Strings.t("MENU_NUEVA_PARTIDA", "Nueva Partida")
	if _btn_cargar != null:
		_btn_cargar.text = Strings.t("MENU_CARGAR_PARTIDA", "Cargar Partida")
	if _btn_config != null:
		_btn_config.text = Strings.t("MENU_CONFIGURACION", "Configuración")
	if _btn_salir != null:
		_btn_salir.text = Strings.t("MENU_SALIR", "Salir")
	if _lbl_seleccionar_partida != null:
		_lbl_seleccionar_partida.text = Strings.t("MENU_SELECCIONAR_PARTIDA", "Seleccionar Partida")
	if _btn_volver_cargar != null:
		_btn_volver_cargar.text = Strings.t("MENU_VOLVER", "Volver")
	if _lbl_subtitulo != null:
		_lbl_subtitulo.text = Strings.t("MENU_SUBTITULO", "Voxel Colony Sim & Industrial Automation")

	if _lbl_nueva_partida_titulo != null:
		_lbl_nueva_partida_titulo.text = Strings.t("MENU_NUEVA_PARTIDA_TITULO", "Nueva Partida")
	if _lbl_nueva_partida_desc != null:
		_lbl_nueva_partida_desc.text = Strings.t("MENU_NUEVA_PARTIDA_DESC", "Elige cómo deseas generar tu mundo:")
	if _btn_mundo_aleatorio != null:
		_btn_mundo_aleatorio.text = Strings.t("MENU_GENERAR_ALEATORIO", "Generar mundo aleatorio")
	if _btn_agregar_semilla != null:
		_btn_agregar_semilla.text = Strings.t("MENU_AGREGAR_SEMILLA", "Agregar semilla")
	if _lbl_input_semilla != null:
		_lbl_input_semilla.text = Strings.t("MENU_SEMILLA_LABEL", "Semilla del Mundo:")
	if _input_semilla != null:
		_input_semilla.placeholder_text = Strings.t("MENU_SEMILLA_PLACEHOLDER", "Escribe o pega una semilla...")
	if _btn_iniciar_con_semilla != null:
		_btn_iniciar_con_semilla.text = Strings.t("MENU_INICIAR_PARTIDA", "Iniciar Partida")
	if _btn_volver_nueva != null:
		_btn_volver_nueva.text = Strings.t("MENU_VOLVER", "Volver")


func _mostrar_subpanel(subpanel: Control) -> void:
	_panel_principal.visible = (subpanel == _panel_principal)
	_panel_nueva_partida.visible = (subpanel == _panel_nueva_partida)
	_panel_cargar.visible = (subpanel == _panel_cargar)
	_panel_configuracion.visible = (subpanel == _panel_configuracion)


func _mostrar_notificacion(msg: String) -> void:
	_lbl_notificacion.text = msg
	_lbl_notificacion.visible = true


func _on_nueva_partida_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	_mostrar_subpanel(_panel_nueva_partida)


func _abrir_panel_cargar() -> void:
	_mostrar_subpanel(_panel_cargar)
	_actualizar_lista_guardados()


func _actualizar_lista_guardados() -> void:
	for child in _vbox_lista_guardados.get_children():
		child.queue_free()

	var lista := GestorPartida.listar_partidas()
	if lista.is_empty():
		var lbl_vacio := Label.new()
		lbl_vacio.text = Strings.t("MENU_SIN_PARTIDAS", "No se encontraron partidas guardadas.")
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
		var nom_p: String = str(p.get("nombre_partida", "Sin nombre"))
		var sem: Variant = p.get("semilla", null)
		if sem != null:
			lbl_nom.text = "%s  (%s)" % [nom_p, Strings.t("MENU_SEMILLA_TAG", "Semilla: %s") % str(sem)]
		else:
			lbl_nom.text = nom_p
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
		btn_cargar.text = Strings.t("MENU_CARGAR", "Cargar")
		btn_cargar.icon = IconosHUD.icono("menu_cargar")
		btn_cargar.add_theme_constant_override("icon_max_width", 18)
		TemaHUD.estilizar_boton_icono(btn_cargar)
		var arch_name: String = str(p.get("nombre_archivo", ""))
		btn_cargar.pressed.connect(func(): _cargar_partida_seleccionada(arch_name))
		hbox.add_child(btn_cargar)

		var btn_eliminar := Button.new()
		btn_eliminar.text = Strings.t("MENU_ELIMINAR", "X")
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
