extends PanelContainer

## Barra vertical izquierda de la cenital: un botón por modo y, bajo Puestos,
## una subtira con los 4 tipos de puesto. Solo pide cambios (señales): el modo
## real lo decide CamaraCenital, que lo devuelve con HUD.set_modo(). Tras cada
## clic la barra se resincroniza con el modo real, así un modo que no llega a
## activarse no queda marcado.

signal modo_pedido(modo: String)
signal puesto_pedido(tipo: String)

const TemaHUD = preload("res://scripts/TemaHUD.gd")

## [id, nombre, tecla]
const MODOS := [
	["ver", "Ver", "Esc"],
	["construir", "Construir", "B"],
	["zonas", "Zonas", "Z"],
	["vias", "Vías", "V"],
	["puestos", "Puestos", "M/H/L/F"],
]
const PUESTOS := [
	["mina", "Mina", "M"],
	["caza_recoleccion", "Caza", "H"],
	["maderero", "Madera", "L"],
	["pesca_frutos_mar", "Pesca", "F"],
]

var _botones := {}  # id de modo -> Button
var _botones_puesto := {}  # tipo de puesto -> Button
var _modo := ""
var _puesto := ""


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 8.0
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(columna)
	for modo in MODOS:
		var id: String = modo[0]
		var boton := _crear_boton("%s\n[%s]" % [modo[1], modo[2]], Vector2(88, 56))
		boton.pressed.connect(func() -> void:
			modo_pedido.emit(id)
			_refrescar()
		)
		columna.add_child(boton)
		_botones[id] = boton
	for puesto in PUESTOS:
		var tipo: String = puesto[0]
		var boton := _crear_boton("%s [%s]" % [puesto[1], puesto[2]], Vector2(88, 28))
		boton.pressed.connect(func() -> void:
			puesto_pedido.emit(tipo)
			_refrescar()
		)
		columna.add_child(boton)
		_botones_puesto[tipo] = boton
	_refrescar()


func _crear_boton(texto: String, tamano: Vector2) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.custom_minimum_size = tamano
	TemaHUD.estilizar_boton(boton)
	return boton


## "modo" es el id de MODOS ("" = Ver); "puesto" el tipo activo cuando modo es "puestos".
func set_modo(modo: String, puesto: String = "") -> void:
	_modo = modo
	_puesto = puesto
	if is_inside_tree():
		_refrescar()


func _refrescar() -> void:
	var activo := _modo if _modo != "" else "ver"
	for id in _botones:
		_botones[id].set_pressed_no_signal(id == activo)
	for tipo in _botones_puesto:
		_botones_puesto[tipo].visible = _modo == "puestos"
		_botones_puesto[tipo].set_pressed_no_signal(tipo == _puesto)


func boton_activo() -> String:
	return _modo if _modo != "" else "ver"


func puestos_visibles() -> bool:
	return _modo == "puestos"


func puesto_activo() -> String:
	return _puesto
