extends HBoxContainer

## Barras de modos de la cenital, en la esquina inferior izquierda: la barra
## principal (un botón por modo) y, a su derecha, una barra de subherramientas
## (Residencial y los 4 puestos con Construir activo; Zona A/B/Borrar con Zonas). Solo pide
## cambios (señales): el modo real lo decide CamaraCenital, que lo devuelve con
## HUD.set_modo(). Tras cada clic la barra se resincroniza con el modo real, así
## un modo que no llega a activarse no queda marcado.

signal modo_pedido(modo: String)
signal construccion_pedida(tipo: String)
signal zona_pedida(tipo: String)

const TemaHUD = preload("res://scripts/TemaHUD.gd")

## [id, nombre, tecla]
const MODOS := [
	["ver", "Ver", "Esc"],
	["construir", "Construir", "B"],
	["zonas", "Zonas", "Z"],
	["vias", "Vías", "V"],
]
## Menú de Construir: "residencial" (blueprint) y los tipos de puesto.
const CONSTRUCCIONES := [
	["residencial", "Residencial", "B"],
	["mina", "Mina", "M"],
	["caza_recoleccion", "Caza", "H"],
	["maderero", "Madera", "L"],
	["pesca_frutos_mar", "Pesca", "F"],
]
## [tipo de zona, nombre, tecla]
var ZONAS := [
	[Zonificacion.ZONAS_PINTABLES[0], "Zona A", "1"],
	[Zonificacion.ZONAS_PINTABLES[1], "Zona B", "2"],
	[Zonificacion.MARCADOR_BORRAR, "Borrar", "0"],
]

var _panel_principal := PanelContainer.new()
var _panel_sub := PanelContainer.new()
var _panel_zonas := PanelContainer.new()
var _botones := {}  # id de modo -> Button
var _botones_construccion := {}  # "residencial" o tipo de puesto -> Button
var _botones_zona := {}  # tipo de zona -> Button
var _modo := ""
var _puesto := ""


func _ready() -> void:
	# Anclas y offsets explícitos (set_anchors_preset() en _ready() no ubicaba la barra).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 8.0
	offset_bottom = -8.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 6)

	for panel in [_panel_principal, _panel_sub, _panel_zonas]:
		TemaHUD.aplicar_panel(panel)
		panel.size_flags_vertical = Control.SIZE_SHRINK_END  # ambas alineadas abajo
		add_child(panel)
	var columna := _nueva_columna(_panel_principal)
	for modo in MODOS:
		var id: String = modo[0]
		var boton := _crear_boton("%s\n[%s]" % [modo[1], modo[2]], Vector2(88, 56))
		boton.pressed.connect(func() -> void:
			modo_pedido.emit(id)
			_refrescar()
		)
		columna.add_child(boton)
		_botones[id] = boton
	var columna_sub := _nueva_columna(_panel_sub)
	for puesto in CONSTRUCCIONES:
		var tipo: String = puesto[0]
		var boton := _crear_boton("%s [%s]" % [puesto[1], puesto[2]], Vector2(88, 36))
		boton.pressed.connect(func() -> void:
			construccion_pedida.emit(tipo)
			_refrescar()
		)
		columna_sub.add_child(boton)
		_botones_construccion[tipo] = boton
	var columna_zonas := _nueva_columna(_panel_zonas)
	for zona in ZONAS:
		var tipo: String = zona[0]
		var boton := _crear_boton("%s [%s]" % [zona[1], zona[2]], Vector2(88, 36))
		boton.pressed.connect(func() -> void:
			zona_pedida.emit(tipo)
			_refrescar()
		)
		columna_zonas.add_child(boton)
		_botones_zona[tipo] = boton
	_refrescar()


func _nueva_columna(panel: PanelContainer) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(columna)
	return columna


func _crear_boton(texto: String, tamano: Vector2) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.custom_minimum_size = tamano
	TemaHUD.estilizar_boton(boton)
	return boton


## "modo" es el id de MODOS ("" = Ver); "sub" la subherramienta activa: el tipo
## de construcción con "construir" (residencial o puesto) o el tipo de zona con "zonas".
func set_modo(modo: String, sub: String = "") -> void:
	_modo = modo
	_puesto = sub
	if is_inside_tree():
		_refrescar()


func _refrescar() -> void:
	var activo := _modo if _modo != "" else "ver"
	for id in _botones:
		_botones[id].set_pressed_no_signal(id == activo)
	_panel_sub.visible = _modo == "construir"
	for tipo in _botones_construccion:
		_botones_construccion[tipo].set_pressed_no_signal(tipo == _puesto)
	_panel_zonas.visible = _modo == "zonas"
	for tipo in _botones_zona:
		_botones_zona[tipo].set_pressed_no_signal(tipo == _puesto)


func boton_activo() -> String:
	return _modo if _modo != "" else "ver"


func construccion_visible() -> bool:
	return _modo == "construir"


func construccion_activa() -> String:
	return _puesto


func zonas_visibles() -> bool:
	return _modo == "zonas"


func zona_activa() -> String:
	return _puesto if _modo == "zonas" else ""
