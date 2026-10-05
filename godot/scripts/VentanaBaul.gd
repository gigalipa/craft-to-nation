extends PanelContainer

## Ventana de interacción del baúl (pulsar E, no mantener, apuntando al
## depósito físico de un puesto — ver Player._interactuar()). Muestra el
## almacén local del puesto, una fila por cada recurso que exista (en el
## baúl o en el stock central) con sus botones -/+ (1 de cada vez; con
## Shift, 10), y el botón "Extraer todo" para todo lo que
## quepa de una vez ("Agregar todo" se quitó: solo volverá en los baúles de un
## edificio de almacén y del núcleo urbano). Reemplaza al retiro automático por E mantenida que
## hacía antes Player._procesar_frutos(). Solo tiene sentido en 1ª persona,
## cerca del baúl: HUD.set_vista() la cierra al cambiar de vista. Libera el
## ratón al abrir y lo recaptura al cerrar (si un cambio de cámara ocurre a
## la vez, Main._terminar_transicion() fija el modo definitivo después, así
## que no hay conflicto).

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const HUDScript = preload("res://scripts/HUD.gd")

var esquina := Recoleccion.SIN_PUESTO

var _contenido := VBoxContainer.new()
## Una fila por cada recurso del juego, construida UNA sola vez en _ready()
## (mismo patrón que PanelPuesto._filas): _actualizar() (llamada cada
## fotograma por _process()) solo actualiza texto/disabled/visible sobre
## estos nodos ya existentes. Reconstruirlas con free() en cada fotograma
## (como antes) destruía el botón -/+ que el jugador tenía el ratón sobre
## presionado a mitad de clic, así que el clic nunca llegaba a completarse.
var _filas := {}  # recurso -> {"fila", "etiqueta", "menos", "mas"}


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Centrada de verdad: los anchors solos ya centran el ORIGEN, pero el
	# contenido (número de filas visibles) cambia el tamaño de la ventana en
	# cada _actualizar(), así que los offsets se recalculan en cada resize en
	# vez de fijarlos una sola vez en _ready() (con PRESET_CENTER, antes de
	# construir el contenido, quedaban calculados sobre un tamaño de 0x0).
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	resized.connect(func() -> void:
		offset_left = -size.x / 2.0
		offset_right = size.x / 2.0
		offset_top = -size.y / 2.0
		offset_bottom = size.y / 2.0)
	custom_minimum_size = Vector2(300, 0)
	var caja := VBoxContainer.new()
	add_child(caja)
	caja.add_child(_fila_titulo())
	caja.add_child(_contenido)
	for recurso in Ciudad.almacen:
		_contenido.add_child(_crear_fila_recurso(recurso))
	var fila_botones := HBoxContainer.new()
	var extraer := Button.new()
	extraer.text = "Extraer todo"
	extraer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(extraer)
	extraer.pressed.connect(func() -> void:
		Economia.retirar_deposito(esquina))
	fila_botones.add_child(extraer)
	caja.add_child(fila_botones)


func abrir(nueva_esquina: Vector2i) -> void:
	if not Economia.tiene_puesto(nueva_esquina):
		return
	esquina = nueva_esquina
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_actualizar()


func cerrar() -> void:
	if not visible:
		return
	visible = false
	esquina = Recoleccion.SIN_PUESTO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and (tecla.keycode == KEY_E or tecla.keycode == KEY_ESCAPE):
			cerrar()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not Economia.tiene_puesto(esquina):
		cerrar()  # el puesto se deconstruyó con la ventana abierta
		return
	_actualizar()


## Cuánto mueven los botones -/+ de golpe: 10 con Shift, 1 sin ella.
static func _incremento() -> float:
	return 10.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0


func _actualizar() -> void:
	var local: Dictionary = Economia.almacen_local(esquina)
	var total_local := 0.0
	for cantidad in local.values():
		total_local += cantidad
	var lleno: bool = total_local >= Economia.puestos[esquina]["capacidad"]
	for recurso in _filas:
		var cantidad_local: float = local.get(recurso, 0.0)
		var f: Dictionary = _filas[recurso]
		# Solo se listan recursos que existan en algún lado (baúl o stock central).
		f["fila"].visible = cantidad_local > 0.0 or Ciudad.almacen[recurso].cantidad > 0.0
		if not f["fila"].visible:
			continue
		var nombre: String = HUDScript.NOMBRES_RECURSO.get(recurso, recurso)
		f["etiqueta"].text = "%s: %.1f" % [nombre, cantidad_local]
		f["menos"].disabled = cantidad_local <= 0.0
		f["mas"].disabled = lleno or Ciudad.almacen[recurso].cantidad <= 0.0


## Icono opcional por recurso: placeholder oculto hasta que exista el arte
## real (ver Pendientes, punto 1 — "iconos, hoy son texto"). El sufijo del
## nombre del recurso en "name" facilita ubicarlo/asignarle textura después.
func _crear_fila_recurso(recurso: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icono := TextureRect.new()
	icono.name = "Icono_%s" % recurso
	icono.custom_minimum_size = Vector2(20, 20)
	icono.visible = false
	fila.add_child(icono)
	var etiqueta := TemaHUD.etiqueta()
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	var menos := Button.new()
	menos.text = "-"
	menos.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(menos)
	menos.pressed.connect(func() -> void:
		Economia.retirar_uno(esquina, recurso, _incremento()))
	var mas := Button.new()
	mas.text = "+"
	mas.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(mas)
	mas.pressed.connect(func() -> void:
		Economia.agregar_uno(esquina, recurso, _incremento()))
	fila.add_child(menos)
	fila.add_child(mas)
	_filas[recurso] = {"fila": fila, "etiqueta": etiqueta, "menos": menos, "mas": mas}
	return fila


func _fila_titulo() -> Control:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titulo := TemaHUD.etiqueta("BAÚL")
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
