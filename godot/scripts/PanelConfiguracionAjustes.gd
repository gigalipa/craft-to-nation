extends VBoxContainer
class_name PanelConfiguracionAjustes

## Panel modular de configuración que abarca audio, controles y variables de balance de ajustes.gd.
## Utilizado tanto en MenuInicio como en MenuPausa.

signal guardado_completado(mensaje: String)
signal volver_solicitado
signal valores_restablecidos

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")

var _tabs: TabContainer
var _controles_ajustes: Dictionary = {} # clave -> SpinBox

# Controles de audio y controles
var _slider_sfx: HSlider
var _lbl_sfx_val: Label
var _slider_musica: HSlider
var _lbl_musica_val: Label
var _slider_sensibilidad: HSlider
var _lbl_sensibilidad_val: Label
var _slider_fov: HSlider
var _lbl_fov_val: Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_construir_ui()


func _construir_ui() -> void:
	# Título
	var lbl_titulo := Label.new()
	lbl_titulo.text = "Configuración y Balance"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_color_override("font_color", TemaHUD.DORADO)
	lbl_titulo.add_theme_font_size_override("font_size", 16)
	add_child(lbl_titulo)

	# TabContainer principal
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(480, 310)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	add_child(_tabs)

	_construir_tab_audio_controles()
	_construir_tab_categoria("Jugador", "jugador")
	_construir_tab_categoria("Cámara Cenital", "cenital")
	_construir_tab_categoria("Ciudad y Simulación", "ciudad")
	_construir_tab_categoria("Economía y Logística", "economia")

	# Barra inferior de acciones con 3 botones separados
	var hbox_acciones := HBoxContainer.new()
	hbox_acciones.add_theme_constant_override("separation", 10)
	add_child(hbox_acciones)

	var btn_guardar := Button.new()
	btn_guardar.text = "Guardar"
	btn_guardar.icon = IconosHUD.icono("menu_guardar")
	btn_guardar.add_theme_constant_override("icon_max_width", 20)
	btn_guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(btn_guardar)
	btn_guardar.pressed.connect(_on_guardar_pressed)
	hbox_acciones.add_child(btn_guardar)

	var btn_volver := Button.new()
	btn_volver.text = "Volver"
	btn_volver.icon = IconosHUD.icono("menu_volver")
	btn_volver.add_theme_constant_override("icon_max_width", 20)
	btn_volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(btn_volver)
	btn_volver.pressed.connect(_on_volver_pressed)
	hbox_acciones.add_child(btn_volver)

	var btn_reset := Button.new()
	btn_reset.text = "Restablecer Valores"
	btn_reset.icon = IconosHUD.icono("menu_reset")
	btn_reset.add_theme_constant_override("icon_max_width", 20)
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(btn_reset)
	btn_reset.pressed.connect(_on_reset_pressed)
	hbox_acciones.add_child(btn_reset)

	sincronizar_desde_configuracion()


func _construir_tab_audio_controles() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Audio y Controles"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# SFX
	var hbox_sfx := HBoxContainer.new()
	var lbl_sfx := Label.new()
	lbl_sfx.text = "Volumen Efectos (SFX):"
	lbl_sfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sfx.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_sfx_val = Label.new()
	_lbl_sfx_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_sfx.add_child(lbl_sfx)
	hbox_sfx.add_child(_lbl_sfx_val)
	vbox.add_child(hbox_sfx)

	_slider_sfx = HSlider.new()
	_slider_sfx.min_value = 0.0
	_slider_sfx.max_value = 100.0
	_slider_sfx.step = 1.0
	_slider_sfx.value_changed.connect(func(v): _lbl_sfx_val.text = "%d%%" % roundi(v))
	vbox.add_child(_slider_sfx)

	# Música BGM
	var hbox_musica := HBoxContainer.new()
	var lbl_mus := Label.new()
	lbl_mus.text = "Volumen Música (BGM):"
	lbl_mus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_mus.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_musica_val = Label.new()
	_lbl_musica_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_musica.add_child(lbl_mus)
	hbox_musica.add_child(_lbl_musica_val)
	vbox.add_child(hbox_musica)

	_slider_musica = HSlider.new()
	_slider_musica.min_value = 0.0
	_slider_musica.max_value = 100.0
	_slider_musica.step = 1.0
	_slider_musica.value_changed.connect(func(v): _lbl_musica_val.text = "%d%%" % roundi(v))
	vbox.add_child(_slider_musica)

	# Sensibilidad Ratón
	var hbox_sens := HBoxContainer.new()
	var lbl_sens := Label.new()
	lbl_sens.text = "Sensibilidad Ratón:"
	lbl_sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sens.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_sensibilidad_val = Label.new()
	_lbl_sensibilidad_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_sens.add_child(lbl_sens)
	hbox_sens.add_child(_lbl_sensibilidad_val)
	vbox.add_child(hbox_sens)

	_slider_sensibilidad = HSlider.new()
	_slider_sensibilidad.min_value = 1.0
	_slider_sensibilidad.max_value = 20.0
	_slider_sensibilidad.step = 0.5
	_slider_sensibilidad.value_changed.connect(func(v): _lbl_sensibilidad_val.text = "%.1f" % v)
	vbox.add_child(_slider_sensibilidad)

	# FOV Avatar
	var hbox_fov := HBoxContainer.new()
	var lbl_fov := Label.new()
	lbl_fov.text = "FOV Cámara Avatar:"
	lbl_fov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_fov.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_fov_val = Label.new()
	_lbl_fov_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_fov.add_child(lbl_fov)
	hbox_fov.add_child(_lbl_fov_val)
	vbox.add_child(hbox_fov)

	_slider_fov = HSlider.new()
	_slider_fov.min_value = 50.0
	_slider_fov.max_value = 100.0
	_slider_fov.step = 1.0
	_slider_fov.value_changed.connect(func(v): _lbl_fov_val.text = "%d°" % roundi(v))
	vbox.add_child(_slider_fov)


func _construir_tab_categoria(nombre_tab: String, clave_cat: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = nombre_tab
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var lista_defs: Array = Configuracion.AJUSTES_DEFINICIONES.get(clave_cat, [])
	for item in lista_defs:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(hbox)

		var lbl := Label.new()
		lbl.text = item["etiqueta"] + ":"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", TemaHUD.TEXTO)
		hbox.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = item["min"]
		spin.max_value = item["max"]
		spin.step = item["paso"]
		spin.suffix = item["unidad"]
		spin.custom_minimum_size = Vector2(110, 30)
		hbox.add_child(spin)

		_controles_ajustes[item["clave"]] = spin


func sincronizar_desde_configuracion() -> void:
	if _slider_sfx != null:
		_slider_sfx.value = Configuracion.volumen_sfx * 100.0
		_lbl_sfx_val.text = "%d%%" % roundi(_slider_sfx.value)

	if _slider_musica != null:
		_slider_musica.value = Configuracion.volumen_musica * 100.0
		_lbl_musica_val.text = "%d%%" % roundi(_slider_musica.value)

	if _slider_sensibilidad != null:
		_slider_sensibilidad.value = Configuracion.sensibilidad_mouse * 1000.0
		_lbl_sensibilidad_val.text = "%.1f" % _slider_sensibilidad.value

	if _slider_fov != null:
		_slider_fov.value = Configuracion.fov_camara
		_lbl_fov_val.text = "%d°" % roundi(_slider_fov.value)

	for clave in _controles_ajustes.keys():
		var spin: SpinBox = _controles_ajustes[clave]
		if spin != null:
			var val = Configuracion.obtener_valor_ajuste(clave)
			if val != null:
				spin.value = float(val)


func _on_guardar_pressed() -> void:
	# Guardar audio y controles
	Configuracion.volumen_sfx = _slider_sfx.value / 100.0
	Configuracion.volumen_musica = _slider_musica.value / 100.0
	Configuracion.sensibilidad_mouse = _slider_sensibilidad.value / 1000.0
	Configuracion.fov_camara = _slider_fov.value

	# Guardar variables de balance
	for clave in _controles_ajustes.keys():
		var spin: SpinBox = _controles_ajustes[clave]
		if spin != null:
			Configuracion.establecer_valor_ajuste(clave, spin.value)

	Configuracion.aplicar()
	Configuracion.guardar()
	Sonidos.reproducir("sfx_ui_guardar")
	guardado_completado.emit("¡Configuración guardada exitosamente!")


func _on_volver_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	sincronizar_desde_configuracion() # Descartar cambios sin guardar
	volver_solicitado.emit()


func _on_reset_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	Configuracion.restablecer_valores_defecto()
	sincronizar_desde_configuracion()
	valores_restablecidos.emit()
	guardado_completado.emit("Valores restablecidos a fábrica.")
