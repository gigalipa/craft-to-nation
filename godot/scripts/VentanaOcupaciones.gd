extends PanelContainer

## Ventana emergente (botón "Ocupaciones" de Población, solo cenital): una fila-botón
## por sitio de trabajo (nombre, trabajadores/cupo, estado). Clic en una fila:
## edificio_pedido(esquina) -> CamaraCenital centra la cámara y abre su panel.
## Mismo comportamiento que VentanaPoblacion (hijo de HUD, arrastrable, ocultar/restaurar).
## Las filas solo se reconstruyen si cambia el conjunto de puestos: un botón recreado
## cada fotograma perdería el clic entre el press y el release (ver VentanaPoblacion).

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")

signal edificio_pedido(esquina: Vector2i)

## A la derecha de Población (16 + 320 de ancho + hueco), sin solaparse con ella ni con Almacén.
const POSICION_INICIAL := Vector2(352, 56)

var _caja := VBoxContainer.new()
var _caja_raiz := VBoxContainer.new()
var abierta := false
var _arrastrando := false
var _offset_arrastre := Vector2.ZERO
var _firma: Array = []  # esquinas de las filas actuales
var _botones := {}  # esquina -> Button


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = POSICION_INICIAL
	custom_minimum_size = Vector2(320, 0)
	_caja_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caja_raiz)
	_caja_raiz.add_child(_fila_titulo("Ocupaciones"))
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_raiz.add_child(_caja)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = evento.pressed
		_offset_arrastre = evento.position
	elif evento is InputEventMouseMotion and _arrastrando:
		position += evento.position - _offset_arrastre


func _process(_delta: float) -> void:
	if visible:
		_actualizar()


func abrir() -> void:
	abierta = true
	visible = true
	_actualizar()


## Oculta sin marcarla como cerrada (HUD.set_vista() al entrar a 1ª persona).
func ocultar_temporalmente() -> void:
	visible = false


func restaurar() -> void:
	visible = abierta


func cerrar() -> void:
	abierta = false
	visible = false


func _actualizar() -> void:
	var esquinas: Array = []
	for esquina in Economia.puestos:
		if Recoleccion.TIPOS_PUESTO_TRABAJO.has(Economia.puestos[esquina]["tipo"]):
			esquinas.append(esquina)
	if esquinas != _firma or (_firma.is_empty() and _caja.get_child_count() == 0):
		_firma = esquinas
		_reconstruir()
	for esquina in _firma:
		_botones[esquina].text = _texto_fila(esquina)


func _reconstruir() -> void:
	for hijo in _caja.get_children():
		hijo.free()
	_botones.clear()
	if _firma.is_empty():
		_caja.add_child(TemaHUD.etiqueta("Ninguno todavía"))
		return
	for esquina: Vector2i in _firma:
		var boton := Button.new()
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		TemaHUD.estilizar_boton(boton)
		boton.pressed.connect(func() -> void: edificio_pedido.emit(esquina))
		_caja.add_child(boton)
		_botones[esquina] = boton


func _texto_fila(esquina: Vector2i) -> String:
	var puesto: Dictionary = Economia.puestos[esquina]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	var nombre: String = PanelPuestoScript.NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"])
	return "%s %d/%d%s" % [nombre, t["recolectores"] + t["acarreadores"], puesto["cupo"], estado]


func _fila_titulo(texto: String) -> Control:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titulo := TemaHUD.etiqueta(texto.to_upper())
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cerrar_boton := Button.new()
	cerrar_boton.text = "X"
	cerrar_boton.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(cerrar_boton)
	cerrar_boton.pressed.connect(cerrar)
	fila.add_child(titulo)
	fila.add_child(cerrar_boton)
	return fila
