extends PanelContainer

## Ventana modal interactiva de Moral y Dinámicas Sociales (clic en "Moral" de la barra superior).
## Muestra el valor de moral actual con emoji de estado anímico, la tendencia horaria,
## el multiplicador continuo de productividad laboral (curva continua acordada en GDD v3.56),
## el régimen migratorio (inmigración continua o éxodo por umbral 20) y el desglose analítico
## de factores (inercia, dieta, recursos, sin techo y peligrosidad de 7 días).

const TemaHUD = preload("res://scripts/TemaHUD.gd")

const ANCHO_VENTANA := 500.0
const ALTURA_VENTANA := 420.0

var abierta := false
var _frame_apertura := -1

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


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(ANCHO_VENTANA, ALTURA_VENTANA)
	size = Vector2(ANCHO_VENTANA, ALTURA_VENTANA)
	offset_left = -ANCHO_VENTANA / 2.0
	offset_right = ANCHO_VENTANA / 2.0
	offset_top = -ALTURA_VENTANA / 2.0
	offset_bottom = ALTURA_VENTANA / 2.0
	resized.connect(func() -> void:
		offset_left = -size.x / 2.0
		offset_right = size.x / 2.0
		offset_top = -size.y / 2.0
		offset_bottom = size.y / 2.0
	)

	_caja_raiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_raiz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caja_raiz.add_theme_constant_override("separation", 8)
	add_child(_caja_raiz)

	_caja_raiz.add_child(_fila_titulo("Moral y Cohesión Social"))

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

	var grid_indicadores := GridContainer.new()
	grid_indicadores.columns = 2
	grid_indicadores.add_theme_constant_override("h_separation", 20)
	grid_indicadores.add_theme_constant_override("v_separation", 4)

	var item_prod := HBoxContainer.new()
	item_prod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_prod.add_theme_constant_override("separation", 6)
	_rect_productividad.custom_minimum_size = Vector2(16, 16)
	_rect_productividad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect_productividad.texture = IconosHUD.icono("productividad")
	item_prod.add_child(_rect_productividad)
	item_prod.add_child(_lbl_productividad)
	grid_indicadores.add_child(item_prod)

	var item_migr := HBoxContainer.new()
	item_migr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_migr.add_theme_constant_override("separation", 6)
	_rect_migracion.custom_minimum_size = Vector2(16, 16)
	_rect_migracion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_migr.add_child(_rect_migracion)
	item_migr.add_child(_lbl_migracion)
	grid_indicadores.add_child(item_migr)

	vbox_estado.add_child(grid_indicadores)

	panel_estado.add_child(vbox_estado)
	_caja_raiz.add_child(panel_estado)

	var sep_mid := HSeparator.new()
	_caja_raiz.add_child(sep_mid)

	# 2. Desglose Analítico de Factores (Scroll)
	var titulo_factores := TemaHUD.etiqueta("FACTORES QUE INFLUYEN EN LA TASA")
	titulo_factores.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
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


func _fila_titulo(texto: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := IconosHUD.crear_rect("corazon_civico", 20)
	fila.add_child(ic)

	var lbl := TemaHUD.etiqueta(texto)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
	lbl.add_theme_font_size_override("font_size", 16)
	fila.add_child(lbl)

	var btn_cerrar := Button.new()
	btn_cerrar.icon = IconosHUD.icono("cruz")
	TemaHUD.estilizar_boton(btn_cerrar)
	btn_cerrar.custom_minimum_size = Vector2(28, 24)
	btn_cerrar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_cerrar.pressed.connect(cerrar)
	fila.add_child(btn_cerrar)

	return fila


func abrir() -> void:
	visible = true
	abierta = true
	_frame_apertura = Engine.get_process_frames()
	actualizar()


func cerrar() -> void:
	visible = false
	abierta = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			get_viewport().set_input_as_handled()
			cerrar()


func _process(_delta: float) -> void:
	if visible:
		actualizar()


func actualizar() -> void:
	var m: float = Ciudad.moral if ("moral" in Ciudad) else 75.0
	var tasa_m: float = Ciudad.tasa_cambio_moral if ("tasa_cambio_moral" in Ciudad) else 0.0

	var emoji := "🙂"
	var color_moral := Color(0.85, 0.95, 0.6)
	if m < 20.0:
		emoji = "😡"
		color_moral = TemaHUD.INVALIDO
	elif m < 35.0:
		emoji = "🙁"
		color_moral = Color(1.0, 0.65, 0.2)
	elif m <= 65.0:
		emoji = "😐"
		color_moral = TemaHUD.TEXTO

	_rect_moral.texture = IconosHUD.icono(IconosHUD.icono_moral(m))
	_lbl_moral_val.text = "%s Moral: %.1f%%" % [emoji, m]
	_lbl_moral_val.add_theme_color_override("font_color", color_moral)

	var color_tasa := Color(0.85, 0.95, 0.6) if tasa_m >= 0.0 else TemaHUD.INVALIDO
	_rect_tendencia.texture = IconosHUD.icono(IconosHUD.icono_tasa(tasa_m))
	_lbl_tendencia.text = "Tendencia: %+.2f / hora" % tasa_m
	_lbl_tendencia.add_theme_color_override("font_color", color_tasa)

	var mult_prod: float = Ciudad.calcular_multiplicador_productividad(m) if Ciudad.has_method("calcular_multiplicador_productividad") else 1.0
	_lbl_productividad.text = "Productividad laboral: %.2fx" % mult_prod

	_rect_migracion.texture = IconosHUD.icono("ciudadano" if m >= 20.0 else "investigador")
	if m >= 20.0:
		_lbl_migracion.text = "Migración: Inmigración activa"
		_lbl_migracion.add_theme_color_override("font_color", Color(0.85, 0.95, 0.6))
	else:
		_lbl_migracion.text = "Migración: ⚠ Éxodo de cerebros (<20)"
		_lbl_migracion.add_theme_color_override("font_color", TemaHUD.INVALIDO)

	# Desglose de factores
	var inercia: float = (Ciudad.MORAL_NEUTRAL - m) * Ciudad.INERCIA_MORAL if ("MORAL_NEUTRAL" in Ciudad) else (50.0 - m) * 0.02
	_lbl_factor_inercia.text = "• Tendencia natural al equilibrio (50%%): %+.2f/h" % inercia

	var activas_dieta := 0
	if "fuentes_comida_activas" in Ciudad:
		for v in Ciudad.fuentes_comida_activas.values():
			if v > 0:
				activas_dieta += 1
	var tasa_dieta: float = (float(activas_dieta) / 6.0) * 0.5
	_lbl_factor_dieta.text = "• Variedad de alimentos (%d/6 grupos): %+.2f/h" % [activas_dieta, tasa_dieta]

	var detalle_recursos := "Estable"
	var com_rec = Ciudad.almacen.get("comida") if ("almacen" in Ciudad) else null
	if com_rec != null and com_rec.cantidad <= 0.0:
		detalle_recursos = "Hambruna crítica (-3.0/h)"
	elif com_rec != null and com_rec.tasa_neta_promedio < 0.0:
		detalle_recursos = "Déficit de comida (-0.6/h)"
	_rect_factor_recursos.texture = IconosHUD.icono("cornucopia_vacia" if (com_rec != null and com_rec.cantidad <= 0.0) else "cornucopia_llena")
	_lbl_factor_recursos.text = "• Abundancia y reservas: %s" % detalle_recursos

	var sin_techo_cant: int = Ciudad.sin_techo if ("sin_techo" in Ciudad) else 0
	var tasa_st: float = -0.05 * float(sin_techo_cant)
	_lbl_factor_sin_techo.text = "• Ciudadanos sin techo (%d en la calle): %+.2f/h" % [sin_techo_cant, tasa_st]
	if sin_techo_cant > 0:
		_lbl_factor_sin_techo.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	else:
		_lbl_factor_sin_techo.add_theme_color_override("font_color", TemaHUD.TEXTO)

	var imp_peligro: float = Ciudad.impacto_peligrosidad_7d() if Ciudad.has_method("impacto_peligrosidad_7d") else 0.0
	_lbl_factor_seguridad.text = "• Peligrosidad 7 días (bajas/robos): %+.2f/h" % -imp_peligro
