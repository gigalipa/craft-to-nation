extends PanelContainer

## Hotbar de 1ª persona: una casilla por tipo de bloque (teclas 1-N), con la
## seleccionada resaltada. Cada casilla admite una cantidad opcional, oculta
## por ahora: el inventario del avatar será el almacén central y la aportará
## cuando exista el consumo de materiales por tipo.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

const NOMBRES := {
	"pared": "Pared",
	"puerta": "Puerta",
	"ventana": "Ventana",
	"piso": "Piso",
	"cama": "Cama",
	"baul": "Baúl",
}

var _fila := HBoxContainer.new()
var _casillas: Array = []  # de {"panel": PanelContainer, "cantidad": Label}
var _seleccionada := 0


static func nombre_de(tipo: String) -> String:
	return NOMBRES.get(tipo, tipo.capitalize())


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -12.0
	_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fila.add_theme_constant_override("separation", 6)
	add_child(_fila)


func configurar(tipos: Array) -> void:
	for casilla in _casillas:
		casilla["panel"].queue_free()
	_casillas.clear()
	for i in range(tipos.size()):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(72, 60)
		var caja := VBoxContainer.new()
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nombre := TemaHUD.etiqueta(nombre_de(tipos[i]))
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cantidad := TemaHUD.etiqueta()
		cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cantidad.visible = false
		var tecla := TemaHUD.etiqueta(str(i + 1))
		tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for etiqueta in [nombre, cantidad, tecla]:
			caja.add_child(etiqueta)
		panel.add_child(caja)
		_fila.add_child(panel)
		_casillas.append({"panel": panel, "cantidad": cantidad})
	_seleccionada = 0
	_resaltar()


func seleccionar(indice: int) -> void:
	if indice < 0 or indice >= _casillas.size():
		return
	_seleccionada = indice
	_resaltar()


func indice_seleccionado() -> int:
	return _seleccionada


## "cantidad" < 0 oculta el número de la casilla.
func set_cantidad(indice: int, cantidad: int) -> void:
	if indice < 0 or indice >= _casillas.size():
		return
	var etiqueta: Label = _casillas[indice]["cantidad"]
	etiqueta.visible = cantidad >= 0
	etiqueta.text = str(cantidad)


func cantidad_visible(indice: int) -> bool:
	return _casillas[indice]["cantidad"].visible


func _resaltar() -> void:
	for i in range(_casillas.size()):
		var estilo := TemaHUD.caja(TemaHUD.VERDE_CLARO, Color(1.0, 0.8, 0.3)) if i == _seleccionada else TemaHUD.caja()
		_casillas[i]["panel"].add_theme_stylebox_override("panel", estilo)
