extends Control

## Menú Contextual de Pausa en Juego (Tecla F11).
## Permite guardar, cargar, ajustar configuraciones de audio, controles y balance,
## o salir al menú principal. Se ejecuta en modo PROCESS_MODE_ALWAYS para responder con el árbol pausado.
## Compatible con localización dinámica en tiempo real (Español / Inglés).

signal reanudar_solicitado
signal salir_al_menu_solicitado

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const ESCENA_PANTALLA_CARGA := "res://scenes/PantallaCarga.tscn"

var _fondo: ColorRect
var _panel_centro: PanelContainer
var _vbox_centro: VBoxContainer

var _panel_principal: VBoxContainer
var _panel_guardar: VBoxContainer
var _panel_cargar: VBoxContainer
var _panel_configuracion: PanelConfiguracionAjustes

var _input_nombre_guardar: LineEdit
var _lbl_notificacion: Label
var _vbox_lista_guardados: VBoxContainer

# Elementos localizables
var _lbl_titulo: Label
var _btn_reanudar: Button
var _btn_quicksave: Button
var _btn_guardar: Button
var _btn_cargar: Button
var _btn_config: Button
var _btn_salir: Button

var _lbl_guardar: Label
var _btn_confirmar_guardar: Button
var _btn_volver_guardar: Button

var _lbl_cargar: Label
var _btn_volver_cargar: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_construir_ui()
	Configuracion.configuracion_cambiada.connect(_on_configuracion_cambiada)
	_actualizar_textos_idioma()


func _on_configuracion_cambiada(clave: String, _valor: Variant) -> void:
	if clave == "idioma":
		_actualizar_textos_idioma()


func _construir_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo oscurecido
	_fondo = ColorRect.new()
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.color = Color(0.0, 0.0, 0.0, 0.70)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fondo)

	# Contenedor central
	_panel_centro = PanelContainer.new()
	_panel_centro.custom_minimum_size = Vector2(540, 540)
	_panel_centro.set_anchors_preset(Control.PRESET_CENTER)
	_panel_centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel_centro.add_theme_stylebox_override("panel", TemaHUD.caja())
	add_child(_panel_centro)

	_vbox_centro = VBoxContainer.new()
	_vbox_centro.add_theme_constant_override("separation", 14)
	_panel_centro.add_child(_vbox_centro)

	# Encabezado
	_lbl_titulo = Label.new()
	_lbl_titulo.text = Strings.t("MENU_PAUSA_TITULO", "PAUSA")
	_lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_titulo.add_theme_color_override("font_color", TemaHUD.DORADO)
	_lbl_titulo.add_theme_font_size_override("font_size", 24)
	_vbox_centro.add_child(_lbl_titulo)

	_lbl_notificacion = Label.new()
	_lbl_notificacion.text = ""
	_lbl_notificacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_notificacion.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_VERDE)
	_lbl_notificacion.add_theme_font_size_override("font_size", 14)
	_lbl_notificacion.visible = false
	_vbox_centro.add_child(_lbl_notificacion)

	_construir_panel_principal()
	_construir_panel_guardar()
	_construir_panel_cargar()
	_construir_panel_configuracion()

	_mostrar_subpanel(_panel_principal)


func _construir_panel_principal() -> void:
	_panel_principal = VBoxContainer.new()
	_panel_principal.add_theme_constant_override("separation", 10)
	_vbox_centro.add_child(_panel_principal)

	_btn_reanudar = Button.new()
	_btn_reanudar.text = Strings.t("MENU_REGRESAR_PARTIDA", "Regresar a la partida")
	_btn_reanudar.icon = IconosHUD.icono("menu_reanudar")
	_btn_reanudar.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(_btn_reanudar)
	_btn_reanudar.pressed.connect(_on_reanudar_pressed)
	_panel_principal.add_child(_btn_reanudar)

	_btn_quicksave = Button.new()
	_btn_quicksave.text = Strings.t("MENU_GUARDADO_RAPIDO", "Guardado Rápido (F12)")
	_btn_quicksave.icon = IconosHUD.icono("menu_quicksave")
	_btn_quicksave.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(_btn_quicksave)
	_btn_quicksave.pressed.connect(_on_quicksave_pressed)
	_panel_principal.add_child(_btn_quicksave)

	_btn_guardar = Button.new()
	_btn_guardar.text = Strings.t("MENU_GUARDAR_PARTIDA_MODAL", "Guardar Partida...")
	_btn_guardar.icon = IconosHUD.icono("menu_guardar")
	_btn_guardar.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(_btn_guardar)
	_btn_guardar.pressed.connect(func(): _mostrar_subpanel(_panel_guardar))
	_panel_principal.add_child(_btn_guardar)

	_btn_cargar = Button.new()
	_btn_cargar.text = Strings.t("MENU_CARGAR_PARTIDA_MODAL", "Cargar Partida...")
	_btn_cargar.icon = IconosHUD.icono("menu_cargar_partida")
	_btn_cargar.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(_btn_cargar)
	_btn_cargar.pressed.connect(_abrir_panel_cargar)
	_panel_principal.add_child(_btn_cargar)

	_btn_config = Button.new()
	_btn_config.text = Strings.t("MENU_CONFIGURACION", "Configuración")
	_btn_config.icon = IconosHUD.icono("menu_configuracion")
	_btn_config.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(_btn_config)
	_btn_config.pressed.connect(_abrir_panel_configuracion)
	_panel_principal.add_child(_btn_config)

	var separador := HSeparator.new()
	separador.add_theme_constant_override("separation", 12)
	_panel_principal.add_child(separador)

	_btn_salir = Button.new()
	_btn_salir.text = Strings.t("MENU_SALIR_PRINCIPAL", "Salir al Menú Principal")
	_btn_salir.icon = IconosHUD.icono("menu_salir")
	_btn_salir.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(_btn_salir)
	_btn_salir.pressed.connect(_on_salir_pressed)
	_panel_principal.add_child(_btn_salir)


func _construir_panel_guardar() -> void:
	_panel_guardar = VBoxContainer.new()
	_panel_guardar.add_theme_constant_override("separation", 12)
	_vbox_centro.add_child(_panel_guardar)

	_lbl_guardar = Label.new()
	_lbl_guardar.text = Strings.t("MENU_GUARDAR_PARTIDA_MODAL", "Guardar Partida")
	_lbl_guardar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_guardar.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_panel_guardar.add_child(_lbl_guardar)

	_input_nombre_guardar = LineEdit.new()
	_input_nombre_guardar.placeholder_text = Strings.t("MENU_NOMBRE_GUARDADO_PLACEHOLDER", "Nombre del guardado...")
	_panel_guardar.add_child(_input_nombre_guardar)

	var hbox_btns := HBoxContainer.new()
	hbox_btns.add_theme_constant_override("separation", 10)
	_panel_guardar.add_child(hbox_btns)

	_btn_confirmar_guardar = Button.new()
	_btn_confirmar_guardar.text = Strings.t("MENU_GUARDAR", "Guardar")
	_btn_confirmar_guardar.icon = IconosHUD.icono("menu_guardar")
	_btn_confirmar_guardar.add_theme_constant_override("icon_max_width", 20)
	_btn_confirmar_guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(_btn_confirmar_guardar)
	_btn_confirmar_guardar.pressed.connect(_confirmar_guardar_partida)
	hbox_btns.add_child(_btn_confirmar_guardar)

	_btn_volver_guardar = Button.new()
	_btn_volver_guardar.text = Strings.t("MENU_VOLVER", "Volver")
	_btn_volver_guardar.icon = IconosHUD.icono("menu_volver")
	_btn_volver_guardar.add_theme_constant_override("icon_max_width", 20)
	_btn_volver_guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(_btn_volver_guardar)
	_btn_volver_guardar.pressed.connect(func(): _mostrar_subpanel(_panel_principal))
	hbox_btns.add_child(_btn_volver_guardar)


func _construir_panel_cargar() -> void:
	_panel_cargar = VBoxContainer.new()
	_panel_cargar.add_theme_constant_override("separation", 10)
	_vbox_centro.add_child(_panel_cargar)

	_lbl_cargar = Label.new()
	_lbl_cargar.text = Strings.t("MENU_CARGAR_PARTIDA_MODAL", "Cargar Partida")
	_lbl_cargar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_cargar.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_panel_cargar.add_child(_lbl_cargar)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 240)
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
	_panel_configuracion.solo_audio_y_camara = true
	_panel_configuracion.guardado_completado.connect(func(msg):
		_mostrar_notificacion(msg)
	)
	_panel_configuracion.volver_solicitado.connect(func():
		_mostrar_subpanel(_panel_principal)
	)
	_vbox_centro.add_child(_panel_configuracion)


func _actualizar_textos_idioma() -> void:
	if _lbl_titulo != null:
		_lbl_titulo.text = Strings.t("MENU_PAUSA_TITULO", "PAUSA")
	if _btn_reanudar != null:
		_btn_reanudar.text = Strings.t("MENU_REGRESAR_PARTIDA", "Regresar a la partida")
	if _btn_quicksave != null:
		_btn_quicksave.text = Strings.t("MENU_GUARDADO_RAPIDO", "Guardado Rápido (F12)")
	if _btn_guardar != null:
		_btn_guardar.text = Strings.t("MENU_GUARDAR_PARTIDA_MODAL", "Guardar Partida...")
	if _btn_cargar != null:
		_btn_cargar.text = Strings.t("MENU_CARGAR_PARTIDA_MODAL", "Cargar Partida...")
	if _btn_config != null:
		_btn_config.text = Strings.t("MENU_CONFIGURACION", "Configuración")
	if _btn_salir != null:
		_btn_salir.text = Strings.t("MENU_SALIR_PRINCIPAL", "Salir al Menú Principal")
	if _lbl_guardar != null:
		_lbl_guardar.text = Strings.t("MENU_GUARDAR_PARTIDA_MODAL", "Guardar Partida")
	if _input_nombre_guardar != null:
		_input_nombre_guardar.placeholder_text = Strings.t("MENU_NOMBRE_GUARDADO_PLACEHOLDER", "Nombre del guardado...")
	if _btn_confirmar_guardar != null:
		_btn_confirmar_guardar.text = Strings.t("MENU_GUARDAR", "Guardar")
	if _btn_volver_guardar != null:
		_btn_volver_guardar.text = Strings.t("MENU_VOLVER", "Volver")
	if _lbl_cargar != null:
		_lbl_cargar.text = Strings.t("MENU_CARGAR_PARTIDA_MODAL", "Cargar Partida")
	if _btn_volver_cargar != null:
		_btn_volver_cargar.text = Strings.t("MENU_VOLVER", "Volver")


func _mostrar_subpanel(subpanel: Control) -> void:
	_panel_principal.visible = (subpanel == _panel_principal)
	_panel_guardar.visible = (subpanel == _panel_guardar)
	_panel_cargar.visible = (subpanel == _panel_cargar)
	_panel_configuracion.visible = (subpanel == _panel_configuracion)


func _mostrar_notificacion(msg: String) -> void:
	_lbl_notificacion.text = msg
	_lbl_notificacion.visible = true


func mostrar() -> void:
	visible = true
	_mostrar_subpanel(_panel_principal)
	_lbl_notificacion.visible = false
	_actualizar_textos_idioma()


func ocultar() -> void:
	visible = false


func esta_abierto() -> bool:
	return visible


func _on_reanudar_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	reanudar_solicitado.emit()


func _on_quicksave_pressed() -> void:
	Sonidos.reproducir("sfx_ui_guardar")
	var ok := GestorPartida.guardado_rapido()
	if ok:
		_mostrar_notificacion(Strings.t("MENU_QUICKSAVE_NOTIF", "¡Guardado rápido realizado (F12)!"))
	else:
		_mostrar_notificacion(Strings.t("MENU_QUICKSAVE_ERROR", "Error al realizar guardado rápido."))


func _confirmar_guardar_partida() -> void:
	var nombre: String = _input_nombre_guardar.text.strip_edges()
	if nombre.is_empty():
		nombre = "Partida " + Time.get_datetime_string_from_system(false, true).replace(":", "-")

	var archivo := nombre.to_lower().replace(" ", "_") + ".json"
	var ok := GestorPartida.guardar_partida(archivo, nombre)
	if ok:
		Sonidos.reproducir("sfx_ui_guardar")
		_mostrar_notificacion(Strings.t("MENU_PARTIDA_GUARDADA_EXITO", "¡Partida guardada con éxito!"))
		_input_nombre_guardar.text = ""
		_mostrar_subpanel(_panel_principal)
	else:
		_mostrar_notificacion(Strings.t("MENU_PARTIDA_ERROR_GUARDAR", "Error al guardar la partida."))


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
		var nom_p: String = str(p.get("nombre_partida", Strings.t("MENU_SIN_NOMBRE", "Sin nombre")))
		var sem: Variant = p.get("semilla", null)
		if sem != null:
			var sem_txt: String = str(int(sem)) if (sem is int or sem is float) else str(sem)
			lbl_nom.text = "%s  (%s)" % [nom_p, Strings.t("MENU_SEMILLA_TAG", "Semilla: %s") % sem_txt]
		else:
			lbl_nom.text = nom_p
		lbl_nom.add_theme_color_override("font_color", TemaHUD.DORADO)
		lbl_nom.add_theme_font_size_override("font_size", 14)
		vbox_info.add_child(lbl_nom)

		var lbl_detalles := Label.new()
		var fecha: String = str(p.get("fecha_guardado", ""))
		var pob: int = int(p.get("poblacion", 0))
		lbl_detalles.text = "%s  |  %s: %d" % [fecha, Strings.t("BARRA_SUPERIOR_POBLACION", "Población"), pob]
		lbl_detalles.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_ATENUADO)
		lbl_detalles.add_theme_font_size_override("font_size", 11)
		vbox_info.add_child(lbl_detalles)

		var btn_cargar := Button.new()
		btn_cargar.text = ""
		btn_cargar.tooltip_text = Strings.t("MENU_CARGAR", "Cargar")
		btn_cargar.icon = IconosHUD.icono("menu_cargar")
		btn_cargar.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_cargar.expand_icon = true
		btn_cargar.custom_minimum_size = Vector2(40, 40)
		btn_cargar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_cargar.add_theme_constant_override("icon_max_width", 24)
		TemaHUD.estilizar_boton_icono(btn_cargar)
		var arch_name: String = str(p.get("nombre_archivo", ""))
		btn_cargar.pressed.connect(func(): _cargar_partida_seleccionada(arch_name))
		hbox.add_child(btn_cargar)

		var btn_eliminar := Button.new()
		btn_eliminar.text = ""
		btn_eliminar.tooltip_text = Strings.t("MENU_ELIMINAR", "X")
		btn_eliminar.icon = IconosHUD.icono("cruz")
		btn_eliminar.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_eliminar.expand_icon = true
		btn_eliminar.custom_minimum_size = Vector2(40, 40)
		btn_eliminar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_eliminar.add_theme_constant_override("icon_max_width", 24)
		TemaHUD.estilizar_boton_icono(btn_eliminar)
		btn_eliminar.pressed.connect(func():
			GestorPartida.eliminar_partida(arch_name)
			_actualizar_lista_guardados()
		)
		hbox.add_child(btn_eliminar)


func _cargar_partida_seleccionada(nombre_archivo: String) -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	GestorPartida.partida_pendiente_a_cargar = nombre_archivo
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_PANTALLA_CARGA)


func _abrir_panel_configuracion() -> void:
	_mostrar_subpanel(_panel_configuracion)
	_panel_configuracion.sincronizar_desde_configuracion()


func _on_salir_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	salir_al_menu_solicitado.emit()
