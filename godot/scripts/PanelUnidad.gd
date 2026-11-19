extends PanelContainer

## Panel lateral inferior derecho para inspección de unidades civiles o control
## táctico de tropas militares seleccionadas en cámara cenital (Fase 4).

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const IconosHUD = preload("res://scripts/IconosHUD.gd")

signal modo_orden_pedido(orden: String)

var colonos_ref = null
var economia_ref = null
var obras_ref = null

var _ids: Array[int] = []
var _icono_titulo: TextureRect
var _titulo: Label
var _lbl_subtitulo: Label
var _lbl_salud: Label
var _caja_civil: VBoxContainer
var _lbl_trabajo: Label
var _lbl_edificio: Label
var _caja_militar: VBoxContainer
var _lbl_postura: Label
var _lbl_comandos: Label
var _botones_postura: Dictionary = {}
var _botones_comando: Dictionary = {}


func _col():
	return colonos_ref if colonos_ref != null else Colonos


func _eco():
	return economia_ref if economia_ref != null else Economia


func _obr():
	return obras_ref if obras_ref != null else Obras


func _init() -> void:
	TemaHUD.aplicar_panel(self)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -280.0
	offset_top = -280.0
	offset_right = -12.0
	offset_bottom = -12.0
	custom_minimum_size = Vector2(268.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)

	var fila_tit := HBoxContainer.new()
	fila_tit.add_theme_constant_override("separation", 6)
	fila_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono_titulo = TextureRect.new()
	_icono_titulo.custom_minimum_size = Vector2(20, 20)
	_icono_titulo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila_tit.add_child(_icono_titulo)

	_titulo = TemaHUD.etiqueta("")
	_titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_tit.add_child(_titulo)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "×"
	btn_cerrar.custom_minimum_size = Vector2(24, 24)
	TemaHUD.estilizar_boton_icono(btn_cerrar)
	btn_cerrar.pressed.connect(func() -> void:
		var c = _col()
		if c != null and c.has_method("limpiar_seleccion"):
			c.limpiar_seleccion()
		cerrar()
	)
	fila_tit.add_child(btn_cerrar)
	caja.add_child(fila_tit)

	_lbl_subtitulo = TemaHUD.etiqueta("")
	_lbl_subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_lbl_subtitulo)

	_lbl_salud = TemaHUD.etiqueta("")
	_lbl_salud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_lbl_salud)

	_caja_civil = VBoxContainer.new()
	_caja_civil.add_theme_constant_override("separation", 4)
	_caja_civil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_trabajo = TemaHUD.etiqueta("")
	_lbl_trabajo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_trabajo.custom_minimum_size.x = 248.0
	_lbl_edificio = TemaHUD.etiqueta("")
	_lbl_edificio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_edificio.custom_minimum_size.x = 248.0
	_caja_civil.add_child(_lbl_trabajo)
	_caja_civil.add_child(_lbl_edificio)
	caja.add_child(_caja_civil)

	_caja_militar = VBoxContainer.new()
	_caja_militar.add_theme_constant_override("separation", 6)
	_caja_militar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_lbl_postura = TemaHUD.etiqueta("")
	_lbl_postura.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_caja_militar.add_child(_lbl_postura)

	var fila_postura := HBoxContainer.new()
	fila_postura.add_theme_constant_override("separation", 4)
	fila_postura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in ["pasivo", "defensivo", "agresivo"]:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		TemaHUD.estilizar_boton(btn)
		btn.pressed.connect(func() -> void:
			var c = _col()
			if c != null and c.has_method("establecer_postura_seleccion"):
				c.establecer_postura_seleccion(p)
			actualizar()
		)
		_botones_postura[p] = btn
		fila_postura.add_child(btn)
	_caja_militar.add_child(fila_postura)

	_lbl_comandos = TemaHUD.etiqueta("")
	_lbl_comandos.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_caja_militar.add_child(_lbl_comandos)

	var grid_cmd := GridContainer.new()
	grid_cmd.columns = 2
	grid_cmd.add_theme_constant_override("h_separation", 4)
	grid_cmd.add_theme_constant_override("v_separation", 4)
	grid_cmd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ord_clave in ["mover", "atacar", "proteger", "patrullar", "mantener"]:
		var btn_cmd := Button.new()
		btn_cmd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_cmd.expand_icon = true
		TemaHUD.estilizar_boton(btn_cmd)
		btn_cmd.pressed.connect(func() -> void:
			if ord_clave == "mantener":
				var c = _col()
				if c != null and c.has_method("ordenar_mantener"):
					c.ordenar_mantener()
				actualizar()
			else:
				modo_orden_pedido.emit(ord_clave)
		)
		_botones_comando[ord_clave] = btn_cmd
		grid_cmd.add_child(btn_cmd)
	_caja_militar.add_child(grid_cmd)
	caja.add_child(_caja_militar)


func abrir(ids: Array) -> void:
	mostrar_unidades(ids)


func mostrar_unidades(ids: Array) -> void:
	var c_sys = _col()
	_ids.clear()
	if c_sys != null:
		for raw_id in ids:
			var cid := int(raw_id)
			if c_sys.colonos.has(cid) and not _ids.has(cid):
				_ids.append(cid)
	if _ids.is_empty():
		cerrar()
		return
	visible = true
	actualizar()


func cerrar() -> void:
	visible = false
	_ids.clear()


func ids_mostrados() -> Array[int]:
	return _ids.duplicate()


func _process(_delta: float) -> void:
	if visible:
		actualizar()


func actualizar() -> void:
	var c_sys = _col()
	if c_sys == null:
		cerrar()
		return
	var vigentes: Array[int] = []
	for cid in _ids:
		if c_sys.colonos.has(cid):
			vigentes.append(cid)
	_ids = vigentes
	if _ids.is_empty():
		cerrar()
		return

	var primero: Dictionary = c_sys.colonos[_ids[0]]
	var es_militar: bool = str(primero.get("tipo", "")) == "militar"

	if not es_militar and _ids.size() == 1:
		_actualizar_civil(primero)
	else:
		_actualizar_militares(c_sys)


func _actualizar_civil(c: Dictionary) -> void:
	_caja_civil.visible = true
	_caja_militar.visible = false
	_lbl_subtitulo.visible = false

	var tipo: String = str(c.get("tipo", "ciudadano"))
	_icono_titulo.texture = IconosHUD.icono(tipo)
	_titulo.text = str(Strings.NOMBRES_ROL_EDIFICIO.get(tipo, tipo.capitalize()))

	var salud: float = float(c.get("salud", Ajustes.SALUD_CIVIL))
	var salud_max: float = float(c.get("salud_max", Ajustes.SALUD_CIVIL))
	_lbl_salud.text = Strings.t("UNIDAD_SALUD") % [salud, salud_max]

	var trabajo_txt: String = Strings.t("UNIDAD_OCIOSO")
	var edificio_txt: String = "-"
	var trab: Dictionary = c.get("trabajo", {})
	if not trab.is_empty():
		var rol: String = str(trab.get("rol", tipo))
		trabajo_txt = str(Strings.NOMBRES_ROL_EDIFICIO.get(rol, rol.capitalize()))
		var esq: Vector2i = trab.get("puesto", Vector2i(-1, -1))
		edificio_txt = _nombre_puesto_en(esq)
	else:
		var tarea: Dictionary = c.get("tarea", {})
		if not tarea.is_empty():
			var t_tipo: String = str(tarea.get("tipo", "")).replace("_", " ").capitalize()
			trabajo_txt = t_tipo if t_tipo != "" else Strings.t("UNIDAD_OCIOSO")
			var id_ob: int = int(tarea.get("id", -1))
			var obr_sys = _obr()
			if id_ob != -1 and obr_sys != null and obr_sys.has_method("resumen_de"):
				var res: Dictionary = obr_sys.resumen_de(id_ob)
				if not res.is_empty():
					edificio_txt = str(res.get("nombre", "-"))

	_lbl_trabajo.text = Strings.t("UNIDAD_TRABAJO") % trabajo_txt
	_lbl_edificio.text = Strings.t("UNIDAD_EDIFICIO") % edificio_txt


func _actualizar_militares(c_sys) -> void:
	_caja_civil.visible = false
	_caja_militar.visible = true
	_icono_titulo.texture = IconosHUD.icono("militar")

	var salud_tot := 0.0
	var salud_max_tot := 0.0
	var postura_ref: String = ""
	var posturas_mixtas := false
	for cid in _ids:
		var u: Dictionary = c_sys.colonos[cid]
		salud_tot += float(u.get("salud", Ajustes.SALUD_MILITAR))
		salud_max_tot += float(u.get("salud_max", Ajustes.SALUD_MILITAR))
		var p_u: String = str(u.get("postura", "defensivo"))
		if postura_ref == "":
			postura_ref = p_u
		elif postura_ref != p_u:
			posturas_mixtas = true

	if _ids.size() == 1:
		var u0: Dictionary = c_sys.colonos[_ids[0]]
		_titulo.text = str(Strings.NOMBRES_ROL_EDIFICIO.get("militar", "Militar"))
		_lbl_subtitulo.visible = true
		_lbl_subtitulo.text = Strings.t("UNIDAD_RANGO") % _nombre_rango(str(u0.get("rango", "soldado_raso")))
	else:
		_titulo.text = Strings.t("UNIDAD_TITULO_ESCUADRA") % _ids.size()
		_lbl_subtitulo.visible = false

	_lbl_salud.text = Strings.t("UNIDAD_SALUD") % [salud_tot, salud_max_tot]

	_lbl_postura.text = Strings.t("UNIDAD_POSTURA")
	(_botones_postura["pasivo"] as Button).text = Strings.t("POSTURA_PASIVO")
	(_botones_postura["defensivo"] as Button).text = Strings.t("POSTURA_DEFENSIVO")
	(_botones_postura["agresivo"] as Button).text = Strings.t("POSTURA_AGRESIVO")
	for p in _botones_postura:
		var btn := _botones_postura[p] as Button
		btn.set_pressed_no_signal((not posturas_mixtas) and postura_ref == p)

	_lbl_comandos.text = Strings.t("UNIDAD_COMANDOS")
	(_botones_comando["mover"] as Button).text = Strings.t("ORDEN_MOVERSE")
	(_botones_comando["atacar"] as Button).text = Strings.t("ORDEN_ATACAR")
	(_botones_comando["proteger"] as Button).text = Strings.t("ORDEN_DEFENDER")
	(_botones_comando["patrullar"] as Button).text = Strings.t("ORDEN_PATRULLAR")
	(_botones_comando["mantener"] as Button).text = Strings.t("ORDEN_MANTENER")


func _nombre_puesto_en(esq: Vector2i) -> String:
	var eco_sys = _eco()
	if eco_sys != null and eco_sys.puestos.has(esq):
		var tipo_p: String = str(eco_sys.puestos[esq].get("tipo", ""))
		if Strings.NOMBRES_PUESTO.has(tipo_p):
			return str(Strings.NOMBRES_PUESTO[tipo_p])
		if tipo_p != "":
			return tipo_p.capitalize()
	return "%s" % str(esq)


func _nombre_rango(rango: String) -> String:
	if rango == "soldado_raso":
		return Strings.t("RANGO_SOLDADO_RASO")
	return rango.replace("_", " ").capitalize()
