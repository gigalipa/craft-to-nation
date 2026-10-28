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

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")
const HUDScript = preload("res://scripts/HUD.gd")

const ANCHO_VENTANA := 320.0
const ALTURA_VENTANA := 260.0

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
	# Centrada con altura fija acotada: evita desbordar la pantalla en resoluciones
	# o ventanas pequeñas. El título "BAÚL" con la "X" arriba y el botón "Extraer todo"
	# abajo quedan siempre visibles, mientras que la lista de recursos hace scroll.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(ANCHO_VENTANA, ALTURA_VENTANA)
	size = Vector2(ANCHO_VENTANA, ALTURA_VENTANA)
	offset_left = -ANCHO_VENTANA / 2.0
	offset_right = ANCHO_VENTANA / 2.0
	offset_top = -ALTURA_VENTANA / 2.0
	offset_bottom = ALTURA_VENTANA / 2.0
	resized.connect(func() -> void:
		offset_left = -size.x / 2.0
		offset_right = size.x / 2.0
		offset_top = -size.y / 2.0
		offset_bottom = size.y / 2.0)
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 6)
	add_child(caja)

	caja.add_child(_fila_titulo())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)

	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_contenido)

	for recurso in Ciudad.almacen:
		_contenido.add_child(_crear_fila_recurso(recurso))

	var fila_botones := HBoxContainer.new()
	var extraer := Button.new()
	extraer.text = "Extraer todo"
	extraer.icon = IconosHUD.icono("extraer_todo")
	extraer.expand_icon = true
	extraer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaHUD.estilizar_boton(extraer)
	extraer.pressed.connect(func() -> void:
		Economia.retirar_deposito(esquina))
	fila_botones.add_child(extraer)
	caja.add_child(fila_botones)


var _frame_apertura := -1


func abrir(nueva_esquina: Vector2i) -> void:
	if not Economia.tiene_puesto(nueva_esquina):
		return
	esquina = nueva_esquina
	visible = true
	_frame_apertura = Engine.get_process_frames()
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
		if Engine.get_process_frames() == _frame_apertura:
			return
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
	return Ajustes.VENTANA_BAUL_PASO_UNIDAD if Input.is_key_pressed(KEY_SHIFT) else 1.0


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
		f["nombre"].text = nombre
		f["etiqueta"].text = "%.1f" % cantidad_local
		f["menos"].disabled = cantidad_local <= 0.0
		f["mas"].disabled = lleno or Ciudad.almacen[recurso].cantidad <= 0.0


func _crear_fila_recurso(recurso: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icono := TextureRect.new()
	icono.name = "Icono_%s" % recurso
	icono.custom_minimum_size = Vector2(20, 20)
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.texture = IconosHUD.icono(IconosHUD.icono_recurso(recurso))
	icono.visible = true
	fila.add_child(icono)
	var lbl_nombre := TemaHUD.etiqueta()
	lbl_nombre.custom_minimum_size.x = 135.0
	lbl_nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_nombre.size_flags_vertical = Control.SIZE_FILL
	fila.add_child(lbl_nombre)
	var etiqueta := TemaHUD.etiqueta()
	etiqueta.custom_minimum_size.x = 65.0
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.size_flags_vertical = Control.SIZE_FILL
	fila.add_child(etiqueta)
	var cont_acciones := HBoxContainer.new()
	cont_acciones.add_theme_constant_override("separation", 4)
	cont_acciones.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mas := Button.new()
	mas.icon = IconosHUD.icono("btn_subir")
	if mas.icon == null:
		mas.text = "+"
	mas.expand_icon = true
	mas.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mas.custom_minimum_size = Vector2(24, 24)
	mas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mas.tooltip_text = "Ingresar al baúl"
	TemaHUD.estilizar_boton_icono(mas)
	mas.pressed.connect(func() -> void:
		Economia.agregar_uno(esquina, recurso, _incremento()))
	var menos := Button.new()
	menos.icon = IconosHUD.icono("btn_bajar")
	if menos.icon == null:
		menos.text = "-"
	menos.expand_icon = true
	menos.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menos.custom_minimum_size = Vector2(24, 24)
	menos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menos.tooltip_text = "Retirar del baúl"
	TemaHUD.estilizar_boton_icono(menos)
	menos.pressed.connect(func() -> void:
		Economia.retirar_uno(esquina, recurso, _incremento()))
	cont_acciones.add_child(mas)
	cont_acciones.add_child(menos)
	fila.add_child(cont_acciones)
	_filas[recurso] = {"fila": fila, "nombre": lbl_nombre, "etiqueta": etiqueta, "menos": menos, "mas": mas}
	return fila


func _fila_titulo() -> Control:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := IconosHUD.crear_rect("baul", 20)
	fila.add_child(ic)
	var titulo := TemaHUD.etiqueta(Strings.VENTANA_BAUL_TITULO_DEFECTO.to_upper())
	titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cerrar_boton := Button.new()
	cerrar_boton.icon = IconosHUD.icono("cruz")
	cerrar_boton.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(cerrar_boton)
	cerrar_boton.pressed.connect(cerrar)
	fila.add_child(titulo)
	fila.add_child(cerrar_boton)
	return fila
