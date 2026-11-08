extends Control

## Menú Contextual de Pausa en Juego (Tecla F11).
## Permite guardar, cargar, ajustar configuraciones de audio, controles y balance,
## o salir al menú principal. Se ejecuta en modo PROCESS_MODE_ALWAYS para responder con el árbol pausado.

signal reanudar_solicitado
signal salir_al_menu_solicitado

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_construir_ui()


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
	var lbl_titulo := Label.new()
	lbl_titulo.text = "PAUSA"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_color_override("font_color", TemaHUD.DORADO)
	lbl_titulo.add_theme_font_size_override("font_size", 24)
	_vbox_centro.add_child(lbl_titulo)

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

	var btn_reanudar := Button.new()
	btn_reanudar.text = "Regresar a la partida"
	btn_reanudar.icon = IconosHUD.icono("menu_reanudar")
	btn_reanudar.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(btn_reanudar)
	btn_reanudar.pressed.connect(_on_reanudar_pressed)
	_panel_principal.add_child(btn_reanudar)

	var btn_quicksave := Button.new()
	btn_quicksave.text = "Guardado Rápido (F12)"
	btn_quicksave.icon = IconosHUD.icono("menu_quicksave")
	btn_quicksave.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(btn_quicksave)
	btn_quicksave.pressed.connect(_on_quicksave_pressed)
	_panel_principal.add_child(btn_quicksave)

	var btn_guardar := Button.new()
	btn_guardar.text = "Guardar Partida..."
	btn_guardar.icon = IconosHUD.icono("menu_guardar")
	btn_guardar.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(btn_guardar)
	btn_guardar.pressed.connect(func(): _mostrar_subpanel(_panel_guardar))
	_panel_principal.add_child(btn_guardar)

	var btn_cargar := Button.new()
	btn_cargar.text = "Cargar Partida..."
	btn_cargar.icon = IconosHUD.icono("menu_cargar_partida")
	btn_cargar.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(btn_cargar)
	btn_cargar.pressed.connect(_abrir_panel_cargar)
	_panel_principal.add_child(btn_cargar)

	var btn_config := Button.new()
	btn_config.text = "Configuración"
	btn_config.icon = IconosHUD.icono("menu_configuracion")
	btn_config.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(btn_config)
	btn_config.pressed.connect(_abrir_panel_configuracion)
	_panel_principal.add_child(btn_config)

	var separador := HSeparator.new()
	separador.add_theme_constant_override("separation", 12)
	_panel_principal.add_child(separador)

	var btn_salir := Button.new()
	btn_salir.text = "Salir al Menú Principal"
	btn_salir.icon = IconosHUD.icono("menu_salir")
	btn_salir.add_theme_constant_override("icon_max_width", 22)
	TemaHUD.estilizar_boton(btn_salir)
	btn_salir.pressed.connect(_on_salir_pressed)
	_panel_principal.add_child(btn_salir)


func _construir_panel_guardar() -> void:
	_panel_guardar = VBoxContainer.new()
	_panel_guardar.add_theme_constant_override("separation", 12)
	_vbox_centro.add_child(_panel_guardar)

	var lbl := Label.new()
	lbl.text = "Guardar Partida"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_panel_guardar.add_child(lbl)

	_input_nombre_guardar = LineEdit.new()
	_input_nombre_guardar.placeholder_text = "Nombre del guardado..."
	_panel_guardar.add_child(_input_nombre_guardar)

	var hbox_btns := HBoxContainer.new()
	hbox_btns.add_theme_constant_override("separation", 10)
	_panel_guardar.add_child(hbox_btns)

	var btn_confirmar := Button.new()
	btn_confirmar.text = "Guardar"
	btn_confirmar.icon = IconosHUD.icono("menu_guardar")
	btn_confirmar.add_theme_constant_override("icon_max_width", 20)
	btn_confirmar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(btn_confirmar)
	btn_confirmar.pressed.connect(_confirmar_guardar_partida)
	hbox_btns.add_child(btn_confirmar)

	var btn_volver := Button.new()
	btn_volver.text = "Volver"
	btn_volver.icon = IconosHUD.icono("menu_volver")
	btn_volver.add_theme_constant_override("icon_max_width", 20)
	btn_volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(btn_volver)
	btn_volver.pressed.connect(func(): _mostrar_subpanel(_panel_principal))
	hbox_btns.add_child(btn_volver)


func _construir_panel_cargar() -> void:
	_panel_cargar = VBoxContainer.new()
	_panel_cargar.add_theme_constant_override("separation", 10)
	_vbox_centro.add_child(_panel_cargar)

	var lbl := Label.new()
	lbl.text = "Cargar Partida"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_panel_cargar.add_child(lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 240)
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
		_mostrar_notificacion("¡Guardado rápido realizado (F12)!")
	else:
		_mostrar_notificacion("Error al realizar guardado rápido.")


func _confirmar_guardar_partida() -> void:
	var nombre: String = _input_nombre_guardar.text.strip_edges()
	if nombre.is_empty():
		nombre = "Partida " + Time.get_datetime_string_from_system(false, true).replace(":", "-")

	var archivo := nombre.to_lower().replace(" ", "_") + ".json"
	var ok := GestorPartida.guardar_partida(archivo, nombre)
	if ok:
		Sonidos.reproducir("sfx_ui_guardar")
		_mostrar_notificacion("¡Partida guardada con éxito!")
		_input_nombre_guardar.text = ""
		_mostrar_subpanel(_panel_principal)
	else:
		_mostrar_notificacion("Error al guardar la partida.")


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
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_PANTALLA_CARGA)


func _abrir_panel_configuracion() -> void:
	_mostrar_subpanel(_panel_configuracion)
	_panel_configuracion.sincronizar_desde_configuracion()


func _on_salir_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	salir_al_menu_solicitado.emit()
