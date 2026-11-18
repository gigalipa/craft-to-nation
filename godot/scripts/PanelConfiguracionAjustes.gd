extends VBoxContainer
class_name PanelConfiguracionAjustes

## Panel modular de configuración que abarca audio, controles, selector de idioma
## y variables de balance de ajustes.gd. Utilizado tanto en MenuInicio como en MenuPausa.

signal guardado_completado(mensaje: String)
signal volver_solicitado
signal valores_restablecidos

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")

var _lbl_titulo: Label
var _tabs: TabContainer
var _controles_ajustes: Dictionary = {} # clave -> SpinBox
var _etiquetas_ajustes: Dictionary = {} # clave -> Label

var solo_audio_y_camara: bool = false:
	set(val):
		if solo_audio_y_camara == val:
			return
		solo_audio_y_camara = val
		if is_inside_tree() and _tabs != null:
			_reconstruir_tabs()

# Selector de idioma
var _lbl_idioma: Label
var _opt_idioma: OptionButton

# Controles de audio y controles
var _lbl_sfx: Label
var _slider_sfx: HSlider
var _lbl_sfx_val: Label

var _lbl_musica: Label
var _slider_musica: HSlider
var _lbl_musica_val: Label

var _lbl_sens: Label
var _slider_sensibilidad: HSlider
var _lbl_sensibilidad_val: Label

var _lbl_fov: Label
var _slider_fov: HSlider
var _lbl_fov_val: Label

# Botones de acción
var _btn_guardar: Button
var _btn_volver: Button
var _btn_reset: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_construir_ui()
	Configuracion.configuracion_cambiada.connect(_on_configuracion_cambiada)


func _on_configuracion_cambiada(clave: String, _valor: Variant) -> void:
	if clave == "idioma":
		_actualizar_textos_idioma()


func _construir_ui() -> void:
	# Título
	_lbl_titulo = Label.new()
	_lbl_titulo.text = Strings.t("MENU_CONFIGURACION", "Configuración") if solo_audio_y_camara else Strings.t("CONFIG_TITULO", "Configuración y Balance")
	_lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_titulo.add_theme_color_override("font_color", TemaHUD.DORADO)
	_lbl_titulo.add_theme_font_size_override("font_size", 16)
	add_child(_lbl_titulo)

	# TabContainer principal
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(480, 310)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	add_child(_tabs)

	_poblar_tabs()

	# Barra inferior de acciones con 3 botones separados
	var hbox_acciones := HBoxContainer.new()
	hbox_acciones.add_theme_constant_override("separation", 10)
	add_child(hbox_acciones)

	_btn_guardar = Button.new()
	_btn_guardar.text = Strings.t("MENU_GUARDAR", "Guardar")
	_btn_guardar.icon = IconosHUD.icono("menu_guardar")
	_btn_guardar.add_theme_constant_override("icon_max_width", 20)
	_btn_guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(_btn_guardar)
	_btn_guardar.pressed.connect(_on_guardar_pressed)
	hbox_acciones.add_child(_btn_guardar)

	_btn_volver = Button.new()
	_btn_volver.text = Strings.t("MENU_VOLVER", "Volver")
	_btn_volver.icon = IconosHUD.icono("menu_volver")
	_btn_volver.add_theme_constant_override("icon_max_width", 20)
	_btn_volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(_btn_volver)
	_btn_volver.pressed.connect(_on_volver_pressed)
	hbox_acciones.add_child(_btn_volver)

	_btn_reset = Button.new()
	_btn_reset.text = Strings.t("MENU_RESTABLECER", "Restablecer Valores")
	_btn_reset.icon = IconosHUD.icono("menu_reset")
	_btn_reset.add_theme_constant_override("icon_max_width", 20)
	_btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(_btn_reset)
	_btn_reset.pressed.connect(_on_reset_pressed)
	hbox_acciones.add_child(_btn_reset)

	sincronizar_desde_configuracion()
	_actualizar_textos_idioma()


func _poblar_tabs() -> void:
	_construir_tab_audio_controles()
	if not solo_audio_y_camara:
		_construir_tab_categoria("Jugador", "jugador", "CONFIG_TAB_JUGADOR")
	_construir_tab_categoria("Cámara Cenital", "cenital", "CONFIG_TAB_CENITAL")
	if not solo_audio_y_camara:
		_construir_tab_categoria("Ciudad y Simulación", "ciudad", "CONFIG_TAB_CIUDAD")
		_construir_tab_categoria("Economía y Logística", "economia", "CONFIG_TAB_ECONOMIA")


func _reconstruir_tabs() -> void:
	_controles_ajustes.clear()
	_etiquetas_ajustes.clear()
	for child in _tabs.get_children():
		child.queue_free()
	_poblar_tabs()
	sincronizar_desde_configuracion()
	_actualizar_textos_idioma()


func _construir_tab_audio_controles() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = Strings.t("CONFIG_TAB_AUDIO", "Audio y Controles")
	scroll.set_meta("clave_i18n", "CONFIG_TAB_AUDIO")
	scroll.set_meta("nombre_default", "Audio y Controles")
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

	# Selector de Idioma
	var hbox_idioma := HBoxContainer.new()
	_lbl_idioma = Label.new()
	_lbl_idioma.text = Strings.t("CONFIG_LBL_IDIOMA", "Idioma:")
	_lbl_idioma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_idioma.add_theme_color_override("font_color", TemaHUD.TEXTO)
	hbox_idioma.add_child(_lbl_idioma)

	_opt_idioma = OptionButton.new()
	_opt_idioma.add_item("Español", 0)
	_opt_idioma.add_item("English", 1)
	_opt_idioma.custom_minimum_size = Vector2(130, 30)
	_opt_idioma.selected = 1 if Configuracion.idioma.to_lower() == "en" else 0
	_opt_idioma.item_selected.connect(_on_idioma_seleccionado)
	hbox_idioma.add_child(_opt_idioma)
	vbox.add_child(hbox_idioma)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# SFX
	var hbox_sfx := HBoxContainer.new()
	_lbl_sfx = Label.new()
	_lbl_sfx.text = Strings.t("CONFIG_LBL_SFX", "Volumen Efectos (SFX):")
	_lbl_sfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_sfx.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_sfx_val = Label.new()
	_lbl_sfx_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_sfx.add_child(_lbl_sfx)
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
	_lbl_musica = Label.new()
	_lbl_musica.text = Strings.t("CONFIG_LBL_BGM", "Volumen Música (BGM):")
	_lbl_musica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_musica.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_musica_val = Label.new()
	_lbl_musica_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_musica.add_child(_lbl_musica)
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
	_lbl_sens = Label.new()
	_lbl_sens.text = Strings.t("CONFIG_LBL_MOUSE", "Sensibilidad Ratón:")
	_lbl_sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_sens.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_sensibilidad_val = Label.new()
	_lbl_sensibilidad_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_sens.add_child(_lbl_sens)
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
	_lbl_fov = Label.new()
	_lbl_fov.text = Strings.t("CONFIG_LBL_FOV", "FOV Cámara Avatar:")
	_lbl_fov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_fov.add_theme_color_override("font_color", TemaHUD.TEXTO)
	_lbl_fov_val = Label.new()
	_lbl_fov_val.add_theme_color_override("font_color", TemaHUD.DORADO)
	hbox_fov.add_child(_lbl_fov)
	hbox_fov.add_child(_lbl_fov_val)
	vbox.add_child(hbox_fov)

	_slider_fov = HSlider.new()
	_slider_fov.min_value = 50.0
	_slider_fov.max_value = 100.0
	_slider_fov.step = 1.0
	_slider_fov.value_changed.connect(func(v): _lbl_fov_val.text = "%d°" % roundi(v))
	vbox.add_child(_slider_fov)


func _construir_tab_categoria(nombre_tab_default: String, clave_cat: String, clave_i18n_tab: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = Strings.t(clave_i18n_tab, nombre_tab_default)
	scroll.set_meta("clave_i18n", clave_i18n_tab)
	scroll.set_meta("nombre_default", nombre_tab_default)
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
		var clave: String = item["clave"]
		lbl.text = Strings.t("AJUSTE_" + clave, item["etiqueta"]) + ":"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", TemaHUD.TEXTO)
		hbox.add_child(lbl)
		_etiquetas_ajustes[clave] = lbl

		if item.get("tipo") == "opcion":
			var opt := OptionButton.new()
			opt.custom_minimum_size = Vector2(140, 30)
			var opciones: Array = item.get("opciones", [])
			var opciones_textos: Array = item.get("opciones_textos", [])
			for i in range(opciones.size()):
				var txt_key: String = opciones_textos[i] if i < opciones_textos.size() else str(opciones[i])
				opt.add_item(Strings.t(txt_key, str(opciones[i]).capitalize()))
			hbox.add_child(opt)
			_controles_ajustes[clave] = opt
		else:
			var spin := SpinBox.new()
			spin.min_value = item["min"]
			spin.max_value = item["max"]
			spin.step = item["paso"]
			spin.suffix = item["unidad"]
			spin.custom_minimum_size = Vector2(110, 30)
			hbox.add_child(spin)
			_controles_ajustes[clave] = spin


func _on_idioma_seleccionado(idx: int) -> void:
	var nuevo_lang: String = "en" if idx == 1 else "es"
	Configuracion.establecer_idioma(nuevo_lang)
	_actualizar_textos_idioma()


func _actualizar_textos_idioma() -> void:
	if _lbl_titulo != null:
		_lbl_titulo.text = Strings.t("MENU_CONFIGURACION", "Configuración") if solo_audio_y_camara else Strings.t("CONFIG_TITULO", "Configuración y Balance")

	if _lbl_idioma != null:
		_lbl_idioma.text = Strings.t("CONFIG_LBL_IDIOMA", "Idioma:")

	if _lbl_sfx != null:
		_lbl_sfx.text = Strings.t("CONFIG_LBL_SFX", "Volumen Efectos (SFX):")

	if _lbl_musica != null:
		_lbl_musica.text = Strings.t("CONFIG_LBL_BGM", "Volumen Música (BGM):")

	if _lbl_sens != null:
		_lbl_sens.text = Strings.t("CONFIG_LBL_MOUSE", "Sensibilidad Ratón:")

	if _lbl_fov != null:
		_lbl_fov.text = Strings.t("CONFIG_LBL_FOV", "FOV Cámara Avatar:")

	if _btn_guardar != null:
		_btn_guardar.text = Strings.t("MENU_GUARDAR", "Guardar")

	if _btn_volver != null:
		_btn_volver.text = Strings.t("MENU_VOLVER", "Volver")

	if _btn_reset != null:
		_btn_reset.text = Strings.t("MENU_RESTABLECER", "Restablecer Valores")

	if _opt_idioma != null:
		_opt_idioma.selected = 1 if Configuracion.idioma.to_lower() == "en" else 0

	# Actualizar nombres de pestañas
	if _tabs != null:
		for child in _tabs.get_children():
			if child.has_meta("clave_i18n"):
				var k_i18n: String = str(child.get_meta("clave_i18n"))
				var def_nom: String = str(child.get_meta("nombre_default", child.name))
				child.name = Strings.t(k_i18n, def_nom)

	# Actualizar etiquetas de variables de ajustes y opciones
	for cat in Configuracion.AJUSTES_DEFINICIONES.values():
		for item in cat:
			var c: String = item["clave"]
			if _etiquetas_ajustes.has(c):
				var lbl: Label = _etiquetas_ajustes[c]
				lbl.text = Strings.t("AJUSTE_" + c, item["etiqueta"]) + ":"
			if _controles_ajustes.has(c) and _controles_ajustes[c] is OptionButton:
				var opt: OptionButton = _controles_ajustes[c]
				var opciones: Array = item.get("opciones", [])
				var opciones_textos: Array = item.get("opciones_textos", [])
				for i in range(opciones.size()):
					var txt_key: String = opciones_textos[i] if i < opciones_textos.size() else str(opciones[i])
					opt.set_item_text(i, Strings.t(txt_key, str(opciones[i]).capitalize()))


func _obtener_def_ajuste(clave: String) -> Dictionary:
	for cat in Configuracion.AJUSTES_DEFINICIONES.values():
		for item in cat:
			if item["clave"] == clave:
				return item
	return {}


func sincronizar_desde_configuracion() -> void:
	if _opt_idioma != null:
		_opt_idioma.selected = 1 if Configuracion.idioma.to_lower() == "en" else 0

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
		var ctrl = _controles_ajustes[clave]
		if ctrl is SpinBox:
			var val = Configuracion.obtener_valor_ajuste(clave)
			if val != null:
				ctrl.value = float(val)
		elif ctrl is OptionButton:
			var val_str = str(Configuracion.obtener_valor_ajuste(clave, "medios")).to_lower().strip_edges()
			var item_def = _obtener_def_ajuste(clave)
			var ops: Array = item_def.get("opciones", [])
			var idx: int = ops.find(val_str)
			ctrl.selected = idx if idx >= 0 else 0


func _on_guardar_pressed() -> void:
	# Guardar audio y controles
	Configuracion.volumen_sfx = _slider_sfx.value / 100.0
	Configuracion.volumen_musica = _slider_musica.value / 100.0
	Configuracion.sensibilidad_mouse = _slider_sensibilidad.value / 1000.0
	Configuracion.fov_camara = _slider_fov.value

	# Guardar idioma
	var nuevo_lang: String = "en" if _opt_idioma.selected == 1 else "es"
	Configuracion.establecer_idioma(nuevo_lang)

	# Guardar variables de balance
	for clave in _controles_ajustes.keys():
		var ctrl = _controles_ajustes[clave]
		if ctrl is SpinBox:
			Configuracion.establecer_valor_ajuste(clave, ctrl.value)
		elif ctrl is OptionButton:
			var item_def = _obtener_def_ajuste(clave)
			var ops: Array = item_def.get("opciones", [])
			var idx: int = ctrl.selected
			if idx >= 0 and idx < ops.size():
				Configuracion.establecer_valor_ajuste(clave, ops[idx])

	Configuracion.aplicar()
	Configuracion.guardar()
	Sonidos.reproducir("sfx_ui_guardar")
	guardado_completado.emit(Strings.t("MENU_GUARDADO_EXITO", "¡Configuración guardada exitosamente!"))


func _on_volver_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	sincronizar_desde_configuracion() # Descartar cambios sin guardar
	_actualizar_textos_idioma()
	volver_solicitado.emit()


func _on_reset_pressed() -> void:
	Sonidos.reproducir("sfx_ui_boton_clic")
	if solo_audio_y_camara:
		Configuracion.volumen_sfx = 1.0
		Configuracion.volumen_musica = 0.8
		Configuracion.sensibilidad_mouse = 0.003
		Configuracion.fov_camara = 70.0
		Configuracion.idioma = "es"
		for item in Configuracion.AJUSTES_DEFINICIONES.get("cenital", []):
			Configuracion.variables_ajustes[item["clave"]] = item["default"]
		Configuracion.aplicar()
		Configuracion.guardar()
	else:
		Configuracion.restablecer_valores_defecto()
	sincronizar_desde_configuracion()
	_actualizar_textos_idioma()
	valores_restablecidos.emit()
	guardado_completado.emit(Strings.t("MENU_RESTABLECIDO_EXITO", "Valores restablecidos a fábrica."))
