extends PanelContainer

## Ventana emergente (clic en "Población" de la barra superior, solo cenital):
## población total, camas construidas y empleo por tipo (los puestos, en Ocupaciones).
## Se actualiza en vivo mientras está visible. Arrastrable con el ratón;
## aparece por defecto en la esquina superior izquierda. Es un hijo más de
## HUD (nunca se destruye), así que su posición y si está abierta o cerrada
## persisten solas mientras dura la partida — incluida al salir y volver a
## entrar a la cenital (HUD.set_vista() la oculta/restaura sin tocarlas).

const TemaHUD = preload("res://scripts/TemaHUD.gd")

const NOMBRES_TIPO := {
	"ciudadano": "Ciudadanos",
	"desempleado": "Desempleados",
	"obrero": "Obreros",
	"tecnico": "Técnicos",
	"especialista": "Especialistas",
	"investigador": "Investigadores",
	"militar": "Militares",
}

## El botón "Ocupaciones" (HUD abre VentanaOcupaciones).
signal ocupaciones_pedidas

const POSICION_INICIAL := Vector2(16, 56)

## Contenido dinámico (demografía/puestos): esto es lo único que se
## reconstruye en cada _actualizar(). El título y su botón de cierre se
## crean una sola vez en _ready() (ver _caja_raiz) — reconstruirlos cada
## fotograma (como antes) destruía el botón a mitad de clic (entre el
## press y el release), así que el "pressed" nunca llegaba a emitirse.
var _caja := VBoxContainer.new()
var _caja_raiz := VBoxContainer.new()
var _boton_ocupaciones := Button.new()
## true mientras el usuario la dejó abierta (independiente de "visible": en
## 1ª persona se oculta sin cambiar esto, ver ocultar_temporalmente()).
var abierta := false
var _arrastrando := false
var _offset_arrastre := Vector2.ZERO


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
	_caja_raiz.add_child(_fila_titulo("Población"))
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_raiz.add_child(_caja)
	# Fuera de _caja: lo de dentro se destruye cada fotograma (ver arriba).
	_boton_ocupaciones.text = "Ocupaciones"
	TemaHUD.estilizar_boton(_boton_ocupaciones)
	_boton_ocupaciones.pressed.connect(func() -> void: ocupaciones_pedidas.emit())
	_caja_raiz.add_child(_boton_ocupaciones)


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


## Restaura la visibilidad si el usuario la había dejado abierta (HUD.set_vista()
## al volver a la cenital).
func restaurar() -> void:
	visible = abierta


func _actualizar() -> void:
	for hijo in _caja.get_children():
		hijo.free()
	_caja.add_child(TemaHUD.etiqueta("Población total: %d" % Ciudad.censo_total))
	_caja.add_child(TemaHUD.etiqueta("Camas construidas: %d" % Ciudad.capacidad_camas_construida))
	_caja.add_child(TemaHUD.etiqueta(""))
	var empleados := _empleados_por_tipo()
	for tipo in NOMBRES_TIPO:
		var cantidad: int = Ciudad.demografia.get(tipo, 0)
		if cantidad <= 0:
			continue
		if tipo == "ciudadano" or tipo == "desempleado":  # sin puesto posible: solo el total
			_caja.add_child(TemaHUD.etiqueta("%s: %d" % [NOMBRES_TIPO[tipo], cantidad]))
		else:
			var con_puesto: int = empleados.get(tipo, 0)
			_caja.add_child(TemaHUD.etiqueta("%s: %d · %d empleados · %d sin empleo" % [NOMBRES_TIPO[tipo], cantidad, con_puesto, maxi(cantidad - con_puesto, 0)]))


## Colonos con puesto, por tipo (un aprendiz es obrero empleado; un técnico libre, sin empleo).
func _empleados_por_tipo() -> Dictionary:
	var cuenta := {}
	for id in Colonos.colonos:
		var colono: Dictionary = Colonos.colonos[id]
		if not colono["trabajo"].is_empty():
			cuenta[colono["tipo"]] = cuenta.get(colono["tipo"], 0) + 1
	return cuenta


func cerrar() -> void:
	abierta = false
	visible = false


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
