extends PanelContainer

## Barra superior del HUD (ambas vistas), de lado a lado de la pantalla. De
## izquierda a derecha: población, moral, comida (con su tasa), almacenamiento
## total, recurso crítico, y a la derecha la era y el nivel urbano. Lee el
## autoload Ciudad cada fotograma. Población en rojo si excede la vivienda
## construida; las tasas en rojo si son negativas. Población y Almacén son
## clicables (solo tienen efecto en la cenital, ver HUD.dato_pedido): abren
## una ventana con el detalle.

## "poblacion" o "almacen"; solo lo escucha CamaraCenital (HUD.dato_pedido).
signal dato_pedido(cual: String)

const TemaHUD = preload("res://scripts/TemaHUD.gd")

## Fija hasta que exista Ciudad.era: las Eras son "visión a futuro, sin
## implementar" en el GDD (Sección 7). Cuando existan, leerla de Ciudad.
const ERA_ACTUAL := "Era 1 · Prehistórica"

var poblacion := TemaHUD.etiqueta()
var moral := TemaHUD.etiqueta()
var comida := TemaHUD.etiqueta()
var almacen_total := TemaHUD.etiqueta()
var critico := TemaHUD.etiqueta()
var energia := TemaHUD.etiqueta()
var era := TemaHUD.etiqueta(ERA_ACTUAL)
var nivel := TemaHUD.etiqueta()

var _barra_moral := ProgressBar.new()


static func texto_poblacion(censo: int, camas: int, desempleados: int) -> String:
	return "Población %d/%d (%d)" % [censo, camas, desempleados]


static func texto_comida(cantidad: float, limite: float, tasa: float) -> String:
	return "Comida %.0f/%.0f %s" % [cantidad, limite, texto_tasa(tasa)]


static func texto_energia(entregada: float, demanda: float) -> String:
	return "Energía: %.0f/%.0f E/h" % [entregada, demanda]


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
	fila.add_theme_constant_override("separation", 28)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)
	poblacion.mouse_filter = Control.MOUSE_FILTER_STOP
	poblacion.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	poblacion.gui_input.connect(_on_clic.bind("poblacion"))
	fila.add_child(poblacion)
	fila.add_child(moral)
	_barra_moral.show_percentage = false
	_barra_moral.max_value = 1.0
	_barra_moral.custom_minimum_size = Vector2(90, 10)
	_barra_moral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barra_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(_barra_moral)
	fila.add_child(comida)
	almacen_total.mouse_filter = Control.MOUSE_FILTER_STOP
	almacen_total.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	almacen_total.gui_input.connect(_on_clic.bind("almacen"))
	fila.add_child(almacen_total)
	fila.add_child(critico)
	fila.add_child(energia)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(espacio)
	fila.add_child(era)
	fila.add_child(nivel)
	actualizar()


func _process(_delta: float) -> void:
	actualizar()


func _on_clic(evento: InputEvent, cual: String) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		dato_pedido.emit(cual)


func actualizar() -> void:
	var desempleados: int = Ciudad.demografia.get("desempleado", 0)
	poblacion.text = texto_poblacion(Ciudad.censo_total, Ciudad.capacidad_camas_construida, desempleados)
	var excede: bool = Ciudad.vivienda_ocupada > Ciudad.capacidad_camas_construida
	poblacion.add_theme_color_override("font_color", TemaHUD.INVALIDO if excede else TemaHUD.TEXTO)
	moral.text = "Moral %+.1f" % Ciudad.bono_moral_variedad
	_barra_moral.value = fraccion_moral(Ciudad.bono_moral_variedad)

	var cantidad_comida := 0.0
	var limite_comida := 0.0
	var tasa_comida := 0.0
	if Ciudad.almacen.has("comida"):
		cantidad_comida = Ciudad.almacen["comida"].cantidad
		limite_comida = Ciudad.almacen["comida"].limite
		tasa_comida = Ciudad.almacen["comida"].tasa_neta_promedio
	comida.text = texto_comida(cantidad_comida, limite_comida, tasa_comida)
	_colorear_por_tasa(comida, tasa_comida)

	var suma: Dictionary = totales(Ciudad.almacen)
	almacen_total.text = "Almacén %.0f/%.0f %s" % [suma["cantidad"], suma["limite"], texto_tasa(suma["tasa"])]
	_colorear_por_tasa(almacen_total, suma["tasa"])

	var clave := clave_critica(Ciudad.almacen)
	if clave == "":
		critico.text = "Crítico —"
		_colorear_por_tasa(critico, 0.0)
	else:
		var recurso = Ciudad.almacen[clave]
		critico.text = "Crítico: %s %s" % [recurso.nombre, texto_tasa(recurso.tasa_neta_promedio)]
		_colorear_por_tasa(critico, recurso.tasa_neta_promedio)

	var res_e: Dictionary = Economia.balance_energia if Economia != null else {}
	var entregada_e: float = res_e.get("entregada", 0.0)
	var demanda_e: float = res_e.get("demanda", 0.0)
	var deficit_e: bool = res_e.get("deficit", false)
	energia.text = texto_energia(entregada_e, demanda_e)
	energia.add_theme_color_override("font_color", TemaHUD.INVALIDO if deficit_e else TemaHUD.TEXTO)

	nivel.text = "Nivel %d" % Ciudad.nivel


func _colorear_por_tasa(etiqueta: Label, tasa: float) -> void:
	etiqueta.add_theme_color_override("font_color", TemaHUD.INVALIDO if tasa < 0.0 else TemaHUD.TEXTO)
