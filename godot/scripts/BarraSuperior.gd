extends PanelContainer

## Barra superior del HUD (ambas vistas): recursos del almacén central,
## población, moral y nivel urbano. Lee el autoload Ciudad cada fotograma,
## como el HUD anterior. Población en rojo si excede la vivienda construida.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

const NOMBRES_RECURSO := {
	"comida": "Comida",
	"madera": "Madera",
	"piedra": "Piedra",
	"hierro": "Hierro",
}

## Claves de Ciudad.almacen que se muestran, en orden.
var recursos: Array = ["comida", "madera", "piedra", "hierro"]

var _etiquetas_recurso := {}  # clave -> Label
var _poblacion := TemaHUD.etiqueta()
var _moral := TemaHUD.etiqueta()
var _barra_moral := ProgressBar.new()
var _nivel := TemaHUD.etiqueta()


static func texto_poblacion(censo: int, camas: int) -> String:
	return "Población %d/%d" % [censo, camas]


## Fracción 0-1 del bono de moral respecto al máximo (acotada).
static func fraccion_moral(bono: float) -> float:
	return clampf(bono / Ciudad.BONO_MORAL_MAXIMO, 0.0, 1.0)


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = 44.0
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 28)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)
	for clave in recursos:
		var etiqueta := TemaHUD.etiqueta()
		fila.add_child(etiqueta)
		_etiquetas_recurso[clave] = etiqueta
	fila.add_child(_poblacion)
	fila.add_child(_moral)
	_barra_moral.show_percentage = false
	_barra_moral.max_value = 1.0
	_barra_moral.custom_minimum_size = Vector2(90, 10)
	_barra_moral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barra_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(_barra_moral)
	fila.add_child(_nivel)
	actualizar()


func _process(_delta: float) -> void:
	actualizar()


func actualizar() -> void:
	for clave in _etiquetas_recurso:
		var cantidad := 0.0
		if Ciudad.almacen.has(clave):
			cantidad = Ciudad.almacen[clave].cantidad
		_etiquetas_recurso[clave].text = "%s %.0f" % [NOMBRES_RECURSO.get(clave, String(clave).capitalize()), cantidad]
	_poblacion.text = texto_poblacion(Ciudad.censo_total, Ciudad.capacidad_camas_construida)
	var excede: bool = Ciudad.vivienda_ocupada > Ciudad.capacidad_camas_construida
	_poblacion.add_theme_color_override("font_color", TemaHUD.INVALIDO if excede else TemaHUD.TEXTO)
	_moral.text = "Moral %+.1f" % Ciudad.bono_moral_variedad
	_barra_moral.value = fraccion_moral(Ciudad.bono_moral_variedad)
	_nivel.text = "Nivel %d" % Ciudad.nivel


func texto_de(clave: String) -> String:
	return _etiquetas_recurso[clave].text


func moral_valor() -> float:
	return _barra_moral.value
