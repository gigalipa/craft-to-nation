extends PanelContainer

## Ventana modal interactiva de Moral y Dinámicas Sociales (clic en "Moral" de la barra superior).
## Muestra el valor de moral actual con emoji de estado anímico, la tendencia horaria,
## el multiplicador continuo de productividad laboral (curva continua acordada en GDD v3.56),
## el régimen migratorio (inmigración continua o éxodo por umbral 20) y el desglose analítico
## de factores (inercia, dieta, recursos, sin techo y peligrosidad de 7 días).

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")

const ANCHO_VENTANA := 380.0
const ALTURA_VENTANA := 440.0

var abierta := false
var _frame_apertura := -1
var _arrastrando := false
var _offset_arrastre := Vector2.ZERO

var _caja_raiz := VBoxContainer.new()
var _lbl_moral_val := TemaHUD.etiqueta()
var _lbl_tendencia := TemaHUD.etiqueta()
var _lbl_productividad := TemaHUD.etiqueta()
var _lbl_migracion := TemaHUD.etiqueta()

var _lbl_factor_inercia := TemaHUD.etiqueta()
var _lbl_factor_dieta := TemaHUD.etiqueta()
var _lbl_factor_recursos := TemaHUD.etiqueta()
var _lbl_factor_sin_techo := TemaHUD.etiqueta()
var _lbl_factor_seguridad := TemaHUD.etiqueta()

var _rect_moral := TextureRect.new()
var _rect_tendencia := TextureRect.new()
var _rect_productividad := TextureRect.new()
var _rect_migracion := TextureRect.new()
var _rect_factor_recursos := TextureRect.new()

var _rect_boost := TextureRect.new()
var _lbl_boost_info := TemaHUD.etiqueta()
var _btn_boost := Button.new()


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2(326, 114)
	custom_minimum_size = Vector2(ANCHO_VENTANA, ALTURA_VENTANA)
	size = Vector2(ANCHO_VENTANA, ALTURA_VENTANA)

	_caja_raiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_raiz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caja_raiz.add_theme_constant_override("separation", 8)
	add_child(_caja_raiz)

	_caja_raiz.add_child(_fila_titulo("MORAL Y COHESIÓN SOCIAL"))

	# 1. Panel de Estado General (Moral, Tendencia, Productividad, Migración)
	var panel_estado := PanelContainer.new()
	TemaHUD.aplicar_panel(panel_estado)
	var vbox_estado := VBoxContainer.new()
	vbox_estado.add_theme_constant_override("separation", 6)

	var hbox_superior := HBoxContainer.new()
	hbox_superior.add_theme_constant_override("separation", 12)
	_rect_moral.custom_minimum_size = Vector2(32, 32)
	_rect_moral.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_superior.add_child(_rect_moral)
	_lbl_moral_val.add_theme_font_size_override("font_size", 18)
	hbox_superior.add_child(_lbl_moral_val)

	_rect_tendencia.custom_minimum_size = Vector2(16, 16)
	_rect_tendencia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_superior.add_child(_rect_tendencia)
	hbox_superior.add_child(_lbl_tendencia)
	vbox_estado.add_child(hbox_superior)

	var sep_est := HSeparator.new()
	vbox_estado.add_child(sep_est)

	var item_prod := HBoxContainer.new()
	item_prod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_prod.add_theme_constant_override("separation", 6)
	_rect_productividad.custom_minimum_size = Vector2(16, 16)
	_rect_productividad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect_productividad.texture = IconosHUD.icono("productividad")
	item_prod.add_child(_rect_productividad)
	item_prod.add_child(_lbl_productividad)
	vbox_estado.add_child(item_prod)

	var item_migr := HBoxContainer.new()
	item_migr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_migr.add_theme_constant_override("separation", 6)
	_rect_migracion.custom_minimum_size = Vector2(16, 16)
	_rect_migracion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_migr.add_child(_rect_migracion)
	item_migr.add_child(_lbl_migracion)
	vbox_estado.add_child(item_migr)

	var sep_boost := HSeparator.new()
	vbox_estado.add_child(sep_boost)

	var hbox_boost_info := HBoxContainer.new()
	hbox_boost_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_boost_info.add_theme_constant_override("separation", 8)
	_rect_boost.custom_minimum_size = Vector2(16, 16)
	_rect_boost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_boost_info.add_child(_rect_boost)
	_lbl_boost_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_boost_info.add_theme_font_size_override("font_size", 13)
	hbox_boost_info.add_child(_lbl_boost_info)
	vbox_estado.add_child(hbox_boost_info)

	_btn_boost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_boost.custom_minimum_size = Vector2(0, 26)
	_btn_boost.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_boost.expand_icon = true
	TemaHUD.estilizar_boton(_btn_boost)
	_btn_boost.pressed.connect(_on_activar_boost)
	vbox_estado.add_child(_btn_boost)

	panel_estado.add_child(vbox_estado)
	_caja_raiz.add_child(panel_estado)

	var sep_mid := HSeparator.new()
	_caja_raiz.add_child(sep_mid)

	# 2. Desglose Analítico de Factores (Scroll)
	var titulo_factores := TemaHUD.etiqueta("Factores que influyen en la tasa")
	titulo_factores.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
	_caja_raiz.add_child(titulo_factores)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caja_raiz.add_child(scroll)

	var vbox_factores := VBoxContainer.new()
	vbox_factores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_factores.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox_factores)

	var item_inercia := HBoxContainer.new()
	item_inercia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_inercia.add_theme_constant_override("separation", 6)
	item_inercia.add_child(IconosHUD.crear_rect("balanza", 16))
	item_inercia.add_child(_lbl_factor_inercia)
	vbox_factores.add_child(item_inercia)

	var item_dieta := HBoxContainer.new()
	item_dieta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_dieta.add_theme_constant_override("separation", 6)
	item_dieta.add_child(IconosHUD.crear_rect("comida", 16))
	item_dieta.add_child(_lbl_factor_dieta)
	vbox_factores.add_child(item_dieta)

	var item_rec := HBoxContainer.new()
	item_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_rec.add_theme_constant_override("separation", 6)
	_rect_factor_recursos.custom_minimum_size = Vector2(16, 16)
	_rect_factor_recursos.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_rec.add_child(_rect_factor_recursos)
	item_rec.add_child(_lbl_factor_recursos)
	vbox_factores.add_child(item_rec)

	var item_st := HBoxContainer.new()
	item_st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_st.add_theme_constant_override("separation", 6)
	item_st.add_child(IconosHUD.crear_rect("sin_techo", 16))
	item_st.add_child(_lbl_factor_sin_techo)
	vbox_factores.add_child(item_st)

	var item_seg := HBoxContainer.new()
	item_seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_seg.add_theme_constant_override("separation", 6)
	item_seg.add_child(IconosHUD.crear_rect("escudo_agrietado", 16))
	item_seg.add_child(_lbl_factor_seguridad)
	vbox_factores.add_child(item_seg)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = evento.pressed
		_offset_arrastre = evento.position
	elif evento is InputEventMouseMotion and _arrastrando:
		position += evento.position - _offset_arrastre


func _fila_titulo(texto: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := IconosHUD.crear_rect("corazon_civico", 20)
	fila.add_child(ic)

	var lbl := TemaHUD.etiqueta(texto)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	lbl.add_theme_font_size_override("font_size", 16)
	fila.add_child(lbl)

	var btn_cerrar := Button.new()
	btn_cerrar.text = ""
	btn_cerrar.icon = IconosHUD.icono("cruz")
	TemaHUD.estilizar_boton(btn_cerrar)
	btn_cerrar.custom_minimum_size = Vector2(28, 24)
	btn_cerrar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_cerrar.pressed.connect(cerrar)
	fila.add_child(btn_cerrar)

	return fila


func _on_activar_boost() -> void:
	if Ciudad != null and Ciudad.has_method("activar_boost_inmigracion"):
		if Ciudad.activar_boost_inmigracion():
			actualizar()


func abrir() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size != Vector2.ZERO:
		position = ((vp_size - size) / 2.0).round()
	visible = true
	abierta = true
	_frame_apertura = Engine.get_process_frames()
	actualizar()


func cerrar() -> void:
	visible = false
	abierta = false


func ocultar_temporalmente() -> void:
	visible = false


func restaurar() -> void:
	visible = abierta


func _process(_delta: float) -> void:
	if visible:
		actualizar()


func actualizar() -> void:
	var m: float = Ciudad.moral if ("moral" in Ciudad) else Ajustes.CIUDAD_MORAL_INICIAL
	var tasa_m: float = Ciudad.tasa_cambio_moral if ("tasa_cambio_moral" in Ciudad) else 0.0

	var color_moral := Color(0.85, 0.95, 0.6)
	if m <= 20.0:
		color_moral = TemaHUD.INVALIDO
	elif m < 35.0:
		color_moral = Color(1.0, 0.65, 0.2)
	elif m <= 65.0:
		color_moral = TemaHUD.TEXTO

	_rect_moral.texture = IconosHUD.icono(IconosHUD.icono_moral(m))
	_lbl_moral_val.text = "Moral: %.1f%%" % m
	_lbl_moral_val.add_theme_color_override("font_color", color_moral)

	var color_tasa := Ajustes.COLOR_HUD_TEXTO_VERDE_CLARO if tasa_m >= 0.0 else TemaHUD.INVALIDO
	_rect_tendencia.texture = IconosHUD.icono(IconosHUD.icono_tasa(tasa_m))
	_lbl_tendencia.text = Strings.VENTANA_MORAL_TENDENCIA_DIA % tasa_m
	_lbl_tendencia.add_theme_color_override("font_color", color_tasa)

	var mult_prod: float = CiudadScript.calcular_multiplicador_productividad(m)
	_lbl_productividad.text = Strings.VENTANA_MORAL_PRODUCTIVIDAD_X % mult_prod

	var boost_horas: int = Ciudad.horas_boost_inmigracion if ("horas_boost_inmigracion" in Ciudad) else 0
	var boost_activo: bool = boost_horas > 0
	var d_rest: int = Ciudad.dias_boost_inmigracion_restantes() if Ciudad.has_method("dias_boost_inmigracion_restantes") else 0
	var mult_boost_num: float = Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION
	var mult_boost_str: String = str(int(mult_boost_num)) if is_equal_approx(mult_boost_num, roundf(mult_boost_num)) else str(mult_boost_num)

	var tasa_mig: float = CiudadScript.calcular_tasa_migracion_mensual(m)
	var tasa_efectiva: float = (tasa_mig * mult_boost_num) if (boost_activo and tasa_mig > 0.0) else tasa_mig

	var str_base: String = Strings.formatear_numero(tasa_mig)
	var str_efectiva: String = Strings.formatear_numero(tasa_efectiva)

	_rect_migracion.texture = IconosHUD.icono("ciudadano" if m > Ajustes.CIUDAD_UMBRAL_EXODO_MORAL else "investigador")
	if m <= Ajustes.CIUDAD_UMBRAL_EXODO_MORAL:
		_lbl_migracion.text = Strings.VENTANA_MORAL_MIGRACION_EXODO_CEREBROS % int(abs(tasa_mig))
		_lbl_migracion.add_theme_color_override("font_color", TemaHUD.INVALIDO)
	elif boost_activo:
		var tipo_txt: String = "Inmigración masiva" if m > Ajustes.CIUDAD_UMBRAL_INMIGRACION_MASIVA else "Inmigración con camas"
		_lbl_migracion.text = Strings.VENTANA_MORAL_MIGRACION_BOOST_FORMATO % [tipo_txt, str_efectiva, str_base, mult_boost_str]
		_lbl_migracion.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_VERDE)
	elif m <= Ajustes.CIUDAD_UMBRAL_INMIGRACION_MASIVA:
		_lbl_migracion.text = Strings.VENTANA_MORAL_MIGRACION_CON_CAMAS % int(tasa_mig)
		_lbl_migracion.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_VERDE_CLARO)
	else:
		_lbl_migracion.text = Strings.VENTANA_MORAL_MIGRACION_MASIVA % int(tasa_mig)
		_lbl_migracion.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_VERDE)

	# Fila de control e información de Boost
	if boost_activo:
		_rect_boost.texture = IconosHUD.icono("rayo")
		_lbl_boost_info.text = Strings.VENTANA_MORAL_BOOST_DETALLE_ACTIVO % [str_efectiva, str_base, mult_boost_str, d_rest]
		_lbl_boost_info.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_VERDE_CLARO)
		_btn_boost.text = Strings.VENTANA_MORAL_BTN_BOOST_ACTIVO % d_rest
		_btn_boost.disabled = true
		_btn_boost.icon = IconosHUD.icono("check")
	elif m <= Ajustes.CIUDAD_UMBRAL_EXODO_MORAL:
		_rect_boost.texture = IconosHUD.icono("cruz")
		_lbl_boost_info.text = Strings.VENTANA_MORAL_BOOST_DETALLE_BLOQUEADO
		_lbl_boost_info.add_theme_color_override("font_color", TemaHUD.INVALIDO)
		_btn_boost.text = Strings.VENTANA_MORAL_BTN_BOOST_BLOQUEADO_EXODO
		_btn_boost.disabled = true
		_btn_boost.icon = IconosHUD.icono("cruz")
	else:
		_rect_boost.texture = IconosHUD.icono("censo")
		_lbl_boost_info.text = Strings.VENTANA_MORAL_BOOST_DETALLE_DISPONIBLE
		_lbl_boost_info.add_theme_color_override("font_color", TemaHUD.TEXTO)
		_btn_boost.text = Strings.VENTANA_MORAL_BTN_BOOST_ACTIVAR
		_btn_boost.disabled = false
		_btn_boost.icon = IconosHUD.icono("censo")

	# Desglose de factores
	var inercia: float = (Ciudad.MORAL_NEUTRAL - m) * Ciudad.INERCIA_MORAL if ("MORAL_NEUTRAL" in Ciudad) else (Ajustes.CIUDAD_MORAL_NEUTRAL - m) * Ajustes.CIUDAD_INERCIA_MORAL
	_lbl_factor_inercia.text = Strings.VENTANA_MORAL_FACTOR_INERCIA_FORMATO % inercia

	var activas_dieta: int = Ciudad.fuentes_comida_en_reserva() if ("fuentes_comida_en_reserva" in Ciudad) else 0
	var delta_d: float = Ciudad.delta_dieta_actual() if ("delta_dieta_actual" in Ciudad) else 0.0
	var tasa_dieta_dia: float = delta_d * 24.0
	if activas_dieta == 1 and Ciudad.horas_monocultivo_continuo > Ajustes.CIUDAD_GRACIA_MONOCULTIVO_HORAS:
		_lbl_factor_dieta.text = "  Variedad (Monocultivo crítico): %+.2f/día" % tasa_dieta_dia
	else:
		_lbl_factor_dieta.text = "  Variedad de alimentos (%d/6 grupos): %+.2f/día" % [activas_dieta, tasa_dieta_dia]

	var detalle_recursos := "Estable"
	var com_rec = Ciudad.almacen.get("comida") if ("almacen" in Ciudad) else null
	if com_rec != null:
		var cap_c: float = com_rec.limite if com_rec.limite > 0.0 else Ajustes.CIUDAD_LIMITE_BASE_COMIDA
		var f_c: float = com_rec.cantidad / cap_c
		if com_rec.cantidad <= 0.0:
			detalle_recursos = "Hambruna crítica (-%.1f/día)" % Ajustes.CIUDAD_PESO_ESCASEZ_COMIDA
		elif f_c >= Ajustes.CIUDAD_UMBRAL_COMIDA_SUPERAVIT:
			detalle_recursos = "Superávit (+%.1f/día)" % Ajustes.CIUDAD_BONO_SUPERAVIT_COMIDA
		elif f_c >= Ajustes.CIUDAD_UMBRAL_COMIDA_ESTABLE:
			detalle_recursos = "Estable (reservas altas)"
		elif com_rec.tasa_neta_promedio < 0.0:
			var h: float = com_rec.cantidad / absf(com_rec.tasa_neta_promedio)
			detalle_recursos = "Escasez: quedan %d h" % int(ceil(h))
		else:
			detalle_recursos = "Escasez en recuperación"
	_rect_factor_recursos.texture = IconosHUD.icono("cornucopia_vacia" if (com_rec != null and com_rec.cantidad <= 0.0) else "cornucopia_llena")
	_lbl_factor_recursos.text = "• Abundancia y reservas: %s" % detalle_recursos

	var sin_techo_cant: int = Ciudad.sin_techo if ("sin_techo" in Ciudad) else 0
	var tasa_st: float = -0.05 * float(sin_techo_cant)
	_lbl_factor_sin_techo.text = "• Ciudadanos sin techo (%d en la calle): %+.2f/día" % [sin_techo_cant, tasa_st]
	if sin_techo_cant > 0:
		_lbl_factor_sin_techo.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	else:
		_lbl_factor_sin_techo.add_theme_color_override("font_color", TemaHUD.TEXTO)

	var imp_peligro: float = Ciudad.impacto_peligrosidad_7d() if Ciudad.has_method("impacto_peligrosidad_7d") else 0.0
	_lbl_factor_seguridad.text = "• Peligrosidad 7 días (bajas/robos): %+.2f/día" % -imp_peligro
