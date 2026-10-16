extends PanelContainer

## Barra superior del HUD (ambas vistas), de lado a lado de la pantalla. De
## izquierda a derecha: población, moral, comida (con su tasa), almacenamiento
## total, recurso crítico, y a la derecha la era y el nivel urbano. Lee el
## autoload Ciudad cada fotograma. Población en rojo si excede la vivienda
## construida; las tasas en rojo si son negativas. Población y Almacén son
## clicables (solo tienen efecto en la cenital, ver HUD.dato_pedido): abren
## una ventana con el detalle.

## "poblacion", "almacen" o "energia"; solo lo escucha CamaraCenital (HUD.dato_pedido).
signal dato_pedido(cual: String)

const TemaHUD = preload("res://scripts/TemaHUD.gd")

## Fija hasta que exista Ciudad.era: las Eras son "visión a futuro, sin
## implementar" en el GDD (Sección 7). Cuando existan, leerla de Ciudad.
const ERA_ACTUAL := "Prehistoria"

var poblacion := Button.new()
var moral := Button.new()
var comida := TemaHUD.etiqueta()
var almacen_total := Button.new()
var critico := TemaHUD.etiqueta()
var energia := Button.new()
var era := TemaHUD.etiqueta(ERA_ACTUAL)
var nivel := TemaHUD.etiqueta()

var _barra_moral := ProgressBar.new()

# Nodos visuales internos para Población
var _lbl_pob_censo: Label
var _lbl_pob_slash: Label
var _icono_camas: TextureRect
var _lbl_pob_camas: Label
var _lbl_pob_par1: Label
var _icono_desempleados: TextureRect
var _lbl_pob_desemp: Label
var _lbl_pob_par2: Label

# Nodos visuales de íconos para BarraSuperior
var _icono_poblacion: TextureRect
var _icono_moral: TextureRect
var _icono_comida: TextureRect
var _icono_comida_tasa: TextureRect
var _icono_almacen: TextureRect
var _lbl_almacen: Label
var _icono_energia: TextureRect
var _lbl_energia: Label
var _icono_critico: TextureRect
var _icono_critico_recurso: TextureRect
var _icono_era: TextureRect
var _icono_nivel: TextureRect


static func texto_poblacion(censo: int, camas: int, desempleados: int) -> String:
	return "Población: %d/%d (%d)" % [censo, camas, desempleados]


static func emoji_moral(m: float) -> String:
	if m <= 20.0:
		return "😡"
	elif m < 35.0:
		return "🙁"
	elif m <= 65.0:
		return "😐"
	return "🙂"


static func texto_moral(m: float) -> String:
	return "%s %.0f%%" % [emoji_moral(m), m]


static func texto_comida(cantidad: float, limite: float, tasa: float) -> String:
	return "Comida: %.0f/%.0f (%s)" % [cantidad, limite, texto_tasa(tasa)]


static func texto_energia(entregada: float, demanda: float, tasa: float = 0.0) -> String:
	return "Energía: %.0f/%.0f (%s)" % [entregada, demanda, texto_tasa(tasa)]


## Fracción 0-1 del bono de moral respecto al máximo (acotada).
static func fraccion_moral(bono: float) -> float:
	return clampf(bono / Ciudad.BONO_MORAL_MAXIMO, 0.0, 1.0)


static func texto_tasa(tasa: float) -> String:
	return "%+.1f/h" % tasa


## Suma de cantidades, límites y tasas de todos los recursos del almacén.
static func totales(almacen: Dictionary) -> Dictionary:
	var suma := {"cantidad": 0.0, "limite": 0.0, "tasa": 0.0}
	for clave in almacen:
		suma["cantidad"] += almacen[clave].cantidad
		suma["limite"] += almacen[clave].limite
		suma["tasa"] += almacen[clave].tasa_neta_promedio
	return suma


## Clave del recurso con la tasa más negativa; si ninguno decrece, el de menor
## tasa positiva. Un recurso con tasa 0 no cuenta (no se mueve). "" si todos
## están en 0.
static func clave_critica(almacen: Dictionary) -> String:
	var elegida := ""
	var menor := 0.0
	for clave in almacen:
		var tasa: float = almacen[clave].tasa_neta_promedio
		if is_zero_approx(tasa):
			continue
		if elegida == "" or tasa < menor:
			elegida = clave
			menor = tasa
	return elegida


static func _separador() -> Label:
	var sep := TemaHUD.etiqueta("|")
	sep.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.7))
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return sep


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	# Anclas y offsets explícitos: set_anchors_preset() en _ready() dejaba la
	# barra con el ancho de su contenido.
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	custom_minimum_size.y = 44.0

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)

	# Grupo izquierdo: [Población] | [Moral] [Barra]
	var grupo_izq := HBoxContainer.new()
	grupo_izq.add_theme_constant_override("separation", 6)
	grupo_izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grupo_izq.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	TemaHUD.estilizar_boton(poblacion)
	poblacion.custom_minimum_size = Vector2(0, 28)
	poblacion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	poblacion.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	poblacion.pressed.connect(func() -> void: dato_pedido.emit("poblacion"))
	poblacion.gui_input.connect(_on_clic.bind("poblacion"))

	var hbox_pob := HBoxContainer.new()
	hbox_pob.add_theme_constant_override("separation", 4)
	hbox_pob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_pob.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox_pob.alignment = BoxContainer.ALIGNMENT_CENTER

	_icono_poblacion = IconosHUD.crear_rect("censo", Vector2(16, 16))
	hbox_pob.add_child(_icono_poblacion)
	_lbl_pob_censo = TemaHUD.etiqueta("0")
	hbox_pob.add_child(_lbl_pob_censo)
	_lbl_pob_slash = TemaHUD.etiqueta("/")
	hbox_pob.add_child(_lbl_pob_slash)
	_icono_camas = IconosHUD.crear_rect("cama", Vector2(16, 16))
	hbox_pob.add_child(_icono_camas)
	_lbl_pob_camas = TemaHUD.etiqueta("0")
	hbox_pob.add_child(_lbl_pob_camas)
	_lbl_pob_par1 = TemaHUD.etiqueta("(")
	hbox_pob.add_child(_lbl_pob_par1)
	_icono_desempleados = IconosHUD.crear_rect("desempleado", Vector2(16, 16))
	hbox_pob.add_child(_icono_desempleados)
	_lbl_pob_desemp = TemaHUD.etiqueta("0")
	hbox_pob.add_child(_lbl_pob_desemp)
	_lbl_pob_par2 = TemaHUD.etiqueta(")")
	hbox_pob.add_child(_lbl_pob_par2)

	poblacion.add_child(hbox_pob)
	poblacion.add_theme_color_override("font_color", Color.TRANSPARENT)
	grupo_izq.add_child(poblacion)

	grupo_izq.add_child(_separador())

	TemaHUD.estilizar_boton(moral)
	moral.custom_minimum_size = Vector2(34, 28)
	moral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moral.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	moral.pressed.connect(func() -> void: dato_pedido.emit("moral"))
	
	_icono_moral = IconosHUD.crear_rect("moral_alta", Vector2(18, 18))
	_icono_moral.set_anchors_preset(Control.PRESET_CENTER)
	moral.add_child(_icono_moral)
	grupo_izq.add_child(moral)

	_barra_moral.show_percentage = false
	_barra_moral.max_value = 1.0
	_barra_moral.custom_minimum_size = Vector2(70, 10)
	_barra_moral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barra_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grupo_izq.add_child(_barra_moral)

	fila.add_child(grupo_izq)

	var espacio_izq := Control.new()
	espacio_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	espacio_izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(espacio_izq)

	# Grupo central: [Almacén] Comida | [Energía] | Crítico
	var grupo_cen := HBoxContainer.new()
	grupo_cen.add_theme_constant_override("separation", 8)
	grupo_cen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grupo_cen.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	almacen_total.text = "Almacén"
	TemaHUD.estilizar_boton(almacen_total)
	almacen_total.custom_minimum_size = Vector2(96, 28)
	almacen_total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	almacen_total.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	almacen_total.pressed.connect(func() -> void: dato_pedido.emit("almacen"))
	almacen_total.add_theme_color_override("font_color", Color.TRANSPARENT)
	var hbox_alm := HBoxContainer.new()
	hbox_alm.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox_alm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_alm.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_alm.add_theme_constant_override("separation", 6)
	_icono_almacen = IconosHUD.crear_rect("almacen", Vector2(16, 16))
	hbox_alm.add_child(_icono_almacen)
	_lbl_almacen = TemaHUD.etiqueta("Almacén")
	hbox_alm.add_child(_lbl_almacen)
	almacen_total.add_child(hbox_alm)
	grupo_cen.add_child(almacen_total)

	var cont_comida := HBoxContainer.new()
	cont_comida.add_theme_constant_override("separation", 4)
	cont_comida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono_comida = IconosHUD.crear_rect("comida", Vector2(18, 18))
	cont_comida.add_child(_icono_comida)
	cont_comida.add_child(comida)
	_icono_comida_tasa = IconosHUD.crear_rect("tasa_neutra", Vector2(12, 12))
	cont_comida.add_child(_icono_comida_tasa)
	grupo_cen.add_child(cont_comida)

	grupo_cen.add_child(_separador())

	TemaHUD.estilizar_boton(energia)
	energia.custom_minimum_size = Vector2(0, 28)
	energia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energia.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	energia.pressed.connect(func() -> void: dato_pedido.emit("energia"))
	energia.add_theme_color_override("font_color", Color.TRANSPARENT)
	var hbox_ene := HBoxContainer.new()
	hbox_ene.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox_ene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_ene.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_ene.add_theme_constant_override("separation", 6)
	_icono_energia = IconosHUD.crear_rect("energia_dorado", Vector2(16, 16))
	hbox_ene.add_child(_icono_energia)
	_lbl_energia = TemaHUD.etiqueta("0 kW")
	hbox_ene.add_child(_lbl_energia)
	energia.add_child(hbox_ene)
	grupo_cen.add_child(energia)

	grupo_cen.add_child(_separador())

	var cont_critico := HBoxContainer.new()
	cont_critico.add_theme_constant_override("separation", 4)
	cont_critico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono_critico = IconosHUD.crear_rect("alerta", Vector2(16, 16))
	cont_critico.add_child(_icono_critico)
	_icono_critico_recurso = IconosHUD.crear_rect("", Vector2(16, 16))
	_icono_critico_recurso.visible = false
	cont_critico.add_child(_icono_critico_recurso)
	cont_critico.add_child(critico)
	grupo_cen.add_child(cont_critico)

	fila.add_child(grupo_cen)

	var espacio_der := Control.new()
	espacio_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	espacio_der.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(espacio_der)

	# Grupo derecho: Era | Nivel
	var grupo_der := HBoxContainer.new()
	grupo_der.add_theme_constant_override("separation", 6)
	grupo_der.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grupo_der.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_icono_era = IconosHUD.crear_rect("era", Vector2(16, 16))
	grupo_der.add_child(_icono_era)
	era.text = "Prehistoria"
	grupo_der.add_child(era)
	grupo_der.add_child(_separador())

	_icono_nivel = IconosHUD.crear_rect("romano_1", Vector2(16, 16))
	grupo_der.add_child(_icono_nivel)
	nivel.visible = false
	grupo_der.add_child(nivel)

	fila.add_child(grupo_der)

	actualizar()


func _process(_delta: float) -> void:
	actualizar()


func _on_clic(evento: InputEvent, cual: String) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		dato_pedido.emit(cual)


func actualizar() -> void:
	var desempleados: int = Ciudad.demografia.get("desempleado", 0)
	var texto_pob := "%d/%d (%d)" % [Ciudad.censo_total, Ciudad.capacidad_camas_construida, desempleados]
	poblacion.text = texto_pob
	var excede: bool = Ciudad.vivienda_ocupada > Ciudad.capacidad_camas_construida
	var color_pob := TemaHUD.INVALIDO if excede else TemaHUD.TEXTO
	if _lbl_pob_censo != null:
		_lbl_pob_censo.text = str(Ciudad.censo_total)
		_lbl_pob_censo.add_theme_color_override("font_color", color_pob)
	if _lbl_pob_camas != null:
		_lbl_pob_camas.text = str(Ciudad.capacidad_camas_construida)
		_lbl_pob_camas.add_theme_color_override("font_color", color_pob)
	if _lbl_pob_desemp != null:
		_lbl_pob_desemp.text = str(desempleados)
		_lbl_pob_desemp.add_theme_color_override("font_color", color_pob)
	if _lbl_pob_slash != null:
		_lbl_pob_slash.add_theme_color_override("font_color", color_pob)
	if _lbl_pob_par1 != null:
		_lbl_pob_par1.add_theme_color_override("font_color", color_pob)
	if _lbl_pob_par2 != null:
		_lbl_pob_par2.add_theme_color_override("font_color", color_pob)

	var m: float = Ciudad.moral if ("moral" in Ciudad) else 75.0
	moral.text = ""
	moral.tooltip_text = "Moral: %.0f%%" % m
	var clave_moral := IconosHUD.icono_moral(m)
	if _icono_moral != null:
		_icono_moral.texture = IconosHUD.icono(clave_moral)
	_barra_moral.value = clampf(m / 100.0, 0.0, 1.0)

	var cantidad_comida := 0.0
	var limite_comida := 0.0
	var tasa_comida := 0.0
	if Ciudad.almacen.has("comida"):
		cantidad_comida = Ciudad.almacen["comida"].cantidad
		limite_comida = Ciudad.almacen["comida"].limite
		tasa_comida = Ciudad.almacen["comida"].tasa_neta_promedio
	comida.text = texto_comida(cantidad_comida, limite_comida, tasa_comida)
	_colorear_por_tasa(comida, tasa_comida)
	if _icono_comida_tasa != null:
		_icono_comida_tasa.texture = IconosHUD.icono(IconosHUD.icono_tasa(tasa_comida))

	almacen_total.text = "Almacén"

	var res_e: Dictionary = Economia.balance_energia if Economia != null else {}
	var entregada_e: float = res_e.get("entregada", 0.0)
	var demanda_e: float = res_e.get("demanda", 0.0)
	var balance_neto: float = entregada_e - demanda_e
	var deficit_e: bool = res_e.get("deficit", false)
	var texto_neto: String
	if is_zero_approx(balance_neto):
		texto_neto = "0 kW"
	elif balance_neto > 0:
		texto_neto = "+%.0f kW" % balance_neto
	else:
		texto_neto = "%.0f kW" % balance_neto

	energia.text = texto_neto
	if _lbl_energia != null:
		_lbl_energia.text = texto_neto
	if deficit_e or (demanda_e > 0.0 and entregada_e < demanda_e):
		if _icono_energia != null:
			_icono_energia.texture = IconosHUD.icono("energia_rojo")
		if _lbl_energia != null:
			_lbl_energia.add_theme_color_override("font_color", TemaHUD.INVALIDO)
	elif entregada_e <= 0.0 and demanda_e <= 0.0:
		if _icono_energia != null:
			_icono_energia.texture = IconosHUD.icono("energia_gris")
		if _lbl_energia != null:
			_lbl_energia.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		if _icono_energia != null:
			_icono_energia.texture = IconosHUD.icono("energia_dorado")
		if _lbl_energia != null:
			_lbl_energia.add_theme_color_override("font_color", TemaHUD.TEXTO)

	var clave := clave_critica(Ciudad.almacen)
	if clave == "":
		critico.text = "Crítico —"
		_icono_critico.visible = false
		if _icono_critico_recurso != null:
			_icono_critico_recurso.visible = false
		_colorear_por_tasa(critico, 0.0)
	else:
		var recurso = Ciudad.almacen[clave]
		critico.text = "Crítico: %s %s" % [clave.capitalize(), texto_tasa(recurso.tasa_neta_promedio)]
		_icono_critico.visible = true
		if _icono_critico_recurso != null:
			_icono_critico_recurso.texture = IconosHUD.icono(clave)
			_icono_critico_recurso.visible = true
		_colorear_por_tasa(critico, recurso.tasa_neta_promedio)

	nivel.text = ""
	if _icono_nivel != null:
		_icono_nivel.texture = IconosHUD.icono(IconosHUD.icono_nivel_romano(Ciudad.nivel))


func _colorear_por_tasa(etiqueta: Label, tasa: float) -> void:
	etiqueta.add_theme_color_override("font_color", TemaHUD.INVALIDO if tasa < 0.0 else TemaHUD.TEXTO)

