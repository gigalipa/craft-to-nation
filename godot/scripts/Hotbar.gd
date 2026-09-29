extends PanelContainer

## Hotbar de 1ª persona: una casilla por tipo de bloque (teclas 1-N), con la
## seleccionada resaltada. Cada casilla admite una cantidad opcional: cuántos
## bloques de ese tipo todavía se pueden colocar con el stock actual del
## almacén central. Se autoactualiza en _process() mientras esté visible,
## mismo patrón que VentanaAlmacen.gd/BarraSuperior.gd (sin depender de que
## Player.gd/HUD.gd la llamen en su propio refresco).

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const NiveladorTerrenoScript = preload("res://scripts/NiveladorTerreno.gd")

const NOMBRES := {
	"tierra": "Tierra",
	"tierra_compactada": "Tierra compactada",
	"bloque_madera": "Bloque de madera",
	"bloque_piedra": "Bloque de piedra",
	"estructura_hierro": "Estructura de hierro",
	"vidrio": "Vidrio",
	"puerta": "Puerta",
	"cama": "Cama",
	"baul": "Baúl",
}

var _fila := HBoxContainer.new()
var _casillas: Array = []  # de {"panel": PanelContainer, "cantidad": Label}
var _seleccionada := 0
var _tipos: Array = []


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
	_tipos = tipos
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


func _process(_delta: float) -> void:
	if visible:
		actualizar_cantidades()


## Pone en cada casilla floor(stock del recurso / costo por bloque); oculta
## el número (cantidad -1) en los tipos sin costo definido en
## NiveladorTerreno.COSTO_POR_CELDA.
func actualizar_cantidades() -> void:
	for i in range(_tipos.size()):
		var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(_tipos[i], {})
		if costo.is_empty():
			set_cantidad(i, -1)
			continue
		var minimo := 999999
		for recurso in costo:
			var disponible: int = int(Ciudad.almacen[recurso].cantidad / costo[recurso])
			minimo = mini(minimo, disponible)
		set_cantidad(i, minimo)


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
