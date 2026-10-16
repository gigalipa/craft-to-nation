extends PanelContainer

## Ventana modal interactiva de energía (clic en "Energía" de la barra superior).
## Muestra el balance global (capacidad, demanda, balance neto y cobertura),
## la lista de generadores (centrales termoeléctricas) y la lista de consumidores.
## Al hacer clic en un edificio, cierra la ventana y emite edificio_pedido(esquina)
## para que la cámara se desplace y se abra el panel del edificio.

signal edificio_pedido(esquina: Vector2i)

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")

const ANCHO_VENTANA := 480.0
const ALTURA_VENTANA := 420.0

var abierta := false
var _frame_apertura := -1

var _caja_raiz := VBoxContainer.new()
var _lbl_capacidad := TemaHUD.etiqueta()
var _lbl_demanda := TemaHUD.etiqueta()
var _lbl_balance := TemaHUD.etiqueta()
var _lbl_cobertura := TemaHUD.etiqueta()

var _caja_generadores := VBoxContainer.new()
var _caja_consumidores := VBoxContainer.new()

var _firma_generadores: Array = []
var _firma_consumidores: Array = []
var _botones_generadores: Dictionary = {}  # esquina -> Button
var _botones_consumidores: Dictionary = {}  # esquina -> Button


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

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
		offset_bottom = size.y / 2.0
	)

	_caja_raiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_raiz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caja_raiz.add_theme_constant_override("separation", 8)
	add_child(_caja_raiz)

	_caja_raiz.add_child(_fila_titulo("Red Eléctrica"))

	# Encabezado balance global
	var caja_balance := VBoxContainer.new()
	caja_balance.add_theme_constant_override("separation", 4)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)

	var item_cap := HBoxContainer.new()
	item_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_cap.add_theme_constant_override("separation", 6)
	item_cap.add_child(IconosHUD.crear_rect("central_termoelectrica", 16))
	item_cap.add_child(_lbl_capacidad)
	grid.add_child(item_cap)

	var item_bal := HBoxContainer.new()
	item_bal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_bal.add_theme_constant_override("separation", 6)
	item_bal.add_child(IconosHUD.crear_rect("balanza", 16))
	item_bal.add_child(_lbl_balance)
	grid.add_child(item_bal)

	var item_dem := HBoxContainer.new()
	item_dem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_dem.add_theme_constant_override("separation", 6)
	item_dem.add_child(IconosHUD.crear_rect("modo_construir", 16))
	item_dem.add_child(_lbl_demanda)
	grid.add_child(item_dem)

	var item_cob := HBoxContainer.new()
	item_cob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_cob.add_theme_constant_override("separation", 6)
	item_cob.add_child(IconosHUD.crear_rect("check", 16))
	item_cob.add_child(_lbl_cobertura)
	grid.add_child(item_cob)

	caja_balance.add_child(grid)
	_caja_raiz.add_child(caja_balance)

	var sep := HSeparator.new()
	_caja_raiz.add_child(sep)

	# Scroll para generadores y consumidores
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caja_raiz.add_child(scroll)

	var caja_listas := VBoxContainer.new()
	caja_listas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_listas.add_theme_constant_override("separation", 8)
	scroll.add_child(caja_listas)

	var titulo_gen := TemaHUD.etiqueta("GENERADORES")
	titulo_gen.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	caja_listas.add_child(titulo_gen)
	_caja_generadores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_generadores.add_theme_constant_override("separation", 4)
	caja_listas.add_child(_caja_generadores)

	var sep_listas := HSeparator.new()
	caja_listas.add_child(sep_listas)

	var titulo_con := TemaHUD.etiqueta("CONSUMIDORES")
	titulo_con.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	caja_listas.add_child(titulo_con)
	_caja_consumidores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_consumidores.add_theme_constant_override("separation", 4)
	caja_listas.add_child(_caja_consumidores)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if Engine.get_process_frames() == _frame_apertura:
			return
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and (tecla.keycode == KEY_E or tecla.keycode == KEY_ESCAPE):
			cerrar()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_actualizar()


func abrir() -> void:
	abierta = true
	visible = true
	_frame_apertura = Engine.get_process_frames()
	_actualizar()


func cerrar() -> void:
	abierta = false
	visible = false


func ocultar_temporalmente() -> void:
	visible = false


func restaurar() -> void:
	visible = abierta


func _actualizar() -> void:
	var res: Dictionary = Economia.balance_energia if Economia != null else {}
	var cap: float = res.get("capacidad", 0.0)
	var dem: float = res.get("demanda", 0.0)
	var entregada: float = res.get("entregada", 0.0)
	var balance_neto: float = cap - dem
	var cobertura: float = 100.0 if dem <= 0.0 else clampf((entregada / dem) * 100.0, 0.0, 100.0)

	_lbl_capacidad.text = "Capacidad: %.0f kW" % cap
	_lbl_demanda.text = "Demanda: %.0f kW" % dem
	_lbl_balance.text = "Balance neto: %+.0f kW" % balance_neto
	_lbl_balance.add_theme_color_override("font_color", TemaHUD.INVALIDO if balance_neto < 0.0 else TemaHUD.VALIDO)
	_lbl_cobertura.text = "Cobertura: %.0f%%" % cobertura
	_lbl_cobertura.add_theme_color_override("font_color", TemaHUD.INVALIDO if (cobertura < 100.0 and dem > 0.0) else TemaHUD.VALIDO)

	var gens := _obtener_generadores()
	if gens != _firma_generadores or (_firma_generadores.is_empty() and _caja_generadores.get_child_count() == 0):
		_firma_generadores = gens.duplicate()
		_reconstruir_generadores(gens, res)
	else:
		for esq in _firma_generadores:
			if _botones_generadores.has(esq):
				_botones_generadores[esq].text = _texto_generador(esq, res)

	var cons := _obtener_consumidores()
	if cons != _firma_consumidores or (_firma_consumidores.is_empty() and _caja_consumidores.get_child_count() == 0):
		_firma_consumidores = cons.duplicate()
		_reconstruir_consumidores(cons, res)
	else:
		for esq in _firma_consumidores:
			if _botones_consumidores.has(esq):
				_actualizar_boton_consumidor(_botones_consumidores[esq], esq, res)


func _reconstruir_generadores(gens: Array, res: Dictionary) -> void:
	for hijo in _caja_generadores.get_children():
		hijo.free()
	_botones_generadores.clear()
	if gens.is_empty():
		_caja_generadores.add_child(TemaHUD.etiqueta("Sin generadores"))
		return
	for esq: Vector2i in gens:
		var btn := Button.new()
		btn.text = _texto_generador(esq, res)
		btn.icon = IconosHUD.icono("central_termoelectrica")
		btn.expand_icon = true
		TemaHUD.estilizar_boton(btn)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func() -> void: _on_edificio_pulsado(esq))
		_caja_generadores.add_child(btn)
		_botones_generadores[esq] = btn


func _texto_generador(esquina: Vector2i, res: Dictionary) -> String:
	if Economia == null or not Economia.puestos.has(esquina):
		return "Central termoeléctrica"
	var p: Dictionary = Economia.puestos[esquina]
	var comb_act: String = p.get("combustible_activo", "carbon")
	var alm: Dictionary = p.get("almacen", {})
	var stock_local: float = alm.get(comb_act, 0.0)
	var nom_comb: String = HUDScript.NOMBRES_RECURSO.get(comb_act, comb_act).capitalize()

	var t_pres: int = p["presentes"].size() if p.has("presentes") else 0
	var stock_comb: float = alm.get("combustible", 0.0) + alm.get("crudo", 0.0) + alm.get("carbon", 0.0)
	var cap_esta: float = minf(float(t_pres), stock_comb) * 20.0
	var cap_total: float = res.get("capacidad", 0.0)
	var entregada_total: float = res.get("entregada", 0.0)
	var uso: float = 0.0
	if cap_total > 1e-9:
		uso = entregada_total * (cap_esta / cap_total)
	return "Central termoeléctrica · %s (reserva: %.0f) · Gen: %.0f kW" % [nom_comb, stock_local, uso]


func _reconstruir_consumidores(cons: Array, res: Dictionary) -> void:
	for hijo in _caja_consumidores.get_children():
		hijo.free()
	_botones_consumidores.clear()
	if cons.is_empty():
		_caja_consumidores.add_child(TemaHUD.etiqueta("Sin consumidores"))
		return
	for esq: Vector2i in cons:
		var btn := Button.new()
		TemaHUD.estilizar_boton(btn)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func() -> void: _on_edificio_pulsado(esq))
		_actualizar_boton_consumidor(btn, esq, res)
		_caja_consumidores.add_child(btn)
		_botones_consumidores[esq] = btn


func _actualizar_boton_consumidor(btn: Button, esquina: Vector2i, res: Dictionary) -> void:
	if Economia == null or not Economia.puestos.has(esquina):
		btn.text = "Consumidor"
		return
	var p: Dictionary = Economia.puestos[esquina]
	var tipo: String = p.get("tipo", "")
	var nom: String = PanelPuestoScript.NOMBRES_PUESTO.get(tipo, tipo.capitalize())
	var dem: float = _demanda_consumidor(p)
	var conectados: Dictionary = res.get("conectados", {})
	var conectado: bool = conectados.get(esquina, false)
	var estado: String = "Conectado" if conectado else "Sin conexión"
	btn.text = "%s · Demanda: %.0f kW · %s" % [nom, dem, estado]
	btn.icon = IconosHUD.icono(tipo)
	btn.expand_icon = true
	btn.add_theme_color_override("font_color", TemaHUD.TEXTO if conectado else TemaHUD.INVALIDO)


func _on_edificio_pulsado(esquina: Vector2i) -> void:
	cerrar()
	edificio_pedido.emit(esquina)


func _obtener_generadores() -> Array[Vector2i]:
	var gens: Array[Vector2i] = []
	if Economia == null:
		return gens
	for esquina: Vector2i in Economia.puestos:
		var p: Dictionary = Economia.puestos[esquina]
		if p.get("tipo", "") == "central_termoelectrica":
			gens.append(esquina)
	gens.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Economia.puestos[a].get("orden_construccion", 0) > Economia.puestos[b].get("orden_construccion", 0)
	)
	return gens


func _obtener_consumidores() -> Array[Vector2i]:
	var cons: Array[Vector2i] = []
	if Economia == null:
		return cons
	for esquina: Vector2i in Economia.puestos:
		var p: Dictionary = Economia.puestos[esquina]
		var tipo: String = p.get("tipo", "")
		if tipo == "central_termoelectrica":
			continue
		var dem: float = _demanda_consumidor(p)
		if dem > 0.0 or tipo in ["refineria_petrolera", "productor_combustible", "universidad"]:
			cons.append(esquina)
	cons.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Economia.puestos[a].get("orden_construccion", 0) > Economia.puestos[b].get("orden_construccion", 0)
	)
	return cons


static func _demanda_consumidor(p: Dictionary) -> float:
	var presentes: int = p["presentes"].size() if p.has("presentes") else 0
	var tipo: String = p.get("tipo", "")
	match tipo:
		"refineria_petrolera", "productor_combustible":
			return float(presentes) * 1.0
		"universidad":
			var nivel_inv: int = Ciudad.nivel_investigado if Ciudad != null else 1
			if nivel_inv + 1 == 3:
				return float(presentes) * 2.0
	return 0.0


func _fila_titulo(texto: String) -> Control:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cont_tit := HBoxContainer.new()
	cont_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := IconosHUD.crear_rect("energia_dorado", 20)
	cont_tit.add_child(ic)
	var titulo := TemaHUD.etiqueta(texto.to_upper())
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	cont_tit.add_child(titulo)
	fila.add_child(cont_tit)

	var cerrar_boton := Button.new()
	cerrar_boton.text = "X"
	cerrar_boton.icon = IconosHUD.icono("cruz")
	cerrar_boton.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(cerrar_boton)
	cerrar_boton.pressed.connect(cerrar)
	fila.add_child(cerrar_boton)
	return fila
