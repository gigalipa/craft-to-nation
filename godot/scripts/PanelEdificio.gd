extends PanelContainer

## Ventana de un edificio u obra (clic izquierdo sobre él en la cenital, ver
## CamaraCenital._procesar_clic_interaccion). Muestra nombre, tipo, estado, salud, obreros y
## materiales que faltan, y tiene los botones «Pausar/Reanudar» y «Demoler/Cancelar demolición».
## Las reglas viven en Obras/Colonos; esto solo las muestra y les pasa los clics.

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")
const FinalizacionObras = preload("res://scripts/FinalizacionObras.gd")

## Mensaje para el jugador (el HUD lo envía a las notificaciones).
signal aviso(texto: String)

const NOMBRES_ESTADO := {"construccion": "En construcción", "demolicion": "En demolición", "demolicion_programada": "Demolición programada", "completo": "Completo"}

var id := -1
var obras: Object = null
var colonos: Object = null
var ciudad: Object = null

var _icono_titulo := TextureRect.new()
var _titulo := TemaHUD.etiqueta()
var _tipo := TemaHUD.etiqueta()
var _fila_camas := HBoxContainer.new()
var _icono_camas := TextureRect.new()
var _camas := TemaHUD.etiqueta()
var _fila_baules := HBoxContainer.new()
var _icono_baules := TextureRect.new()
var _baules := TemaHUD.etiqueta()
var _residentes := TemaHUD.etiqueta()
var _colonizable := TemaHUD.etiqueta()
var _estado := TemaHUD.etiqueta()
var _salud := TemaHUD.etiqueta()
var _obreros := TemaHUD.etiqueta()
var _materiales := TemaHUD.etiqueta()
var _caja_faltantes := VBoxContainer.new()
var _btn_boost_inmigracion := Button.new()
var _btn_racionamiento := Button.new()
var _toggle_colonizable := Button.new()
var _remodelar := Button.new()
var _pausar := Button.new()
var _prioridad := Button.new()
var _demoler := Button.new()
var _asignar_nucleo := Button.new()
var _dialogo_demoler := ConfirmationDialog.new()
var _dialogo_traslado := ConfirmationDialog.new()
var _dialogo_remodelar := ConfirmationDialog.new()


func _ready() -> void:
	if obras == null:
		obras = Obras
	if colonos == null:
		colonos = Colonos
	if ciudad == null:
		ciudad = Ciudad
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP  # los botones necesitan capturar el clic
	# Abajo a la derecha, como el panel del puesto: arriba las notificaciones ocupan ese lugar.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -280.0
	offset_bottom = -12.0
	offset_right = -12.0
	custom_minimum_size.x = 268.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var caja := VBoxContainer.new()
	add_child(caja)

	var fila_tit := HBoxContainer.new()
	fila_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_tit.add_theme_constant_override("separation", 6)
	_icono_titulo.custom_minimum_size = Vector2(20, 20)
	_icono_titulo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila_tit.add_child(_icono_titulo)
	_titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_tit.add_child(_titulo)
	caja.add_child(fila_tit)

	caja.add_child(_tipo)

	_fila_camas.add_theme_constant_override("separation", 6)
	_fila_camas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono_camas.custom_minimum_size = Vector2(16, 16)
	_icono_camas.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono_camas.texture = IconosHUD.icono("cama")
	_fila_camas.add_child(_icono_camas)
	_fila_camas.add_child(_camas)
	caja.add_child(_fila_camas)

	_fila_baules.add_theme_constant_override("separation", 6)
	_fila_baules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono_baules.custom_minimum_size = Vector2(16, 16)
	_icono_baules.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono_baules.texture = IconosHUD.icono("baul")
	_fila_baules.add_child(_icono_baules)
	_fila_baules.add_child(_baules)
	caja.add_child(_fila_baules)

	for etiqueta in [_residentes, _colonizable, _estado, _salud, _obreros, _materiales]:
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)

	_caja_faltantes.add_theme_constant_override("separation", 4)
	_caja_faltantes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_caja_faltantes)

	_btn_boost_inmigracion.icon = IconosHUD.icono("censo")
	_btn_boost_inmigracion.expand_icon = true
	_btn_boost_inmigracion.text = Strings.VENTANA_MORAL_BTN_BOOST_ACTIVAR
	TemaHUD.estilizar_boton(_btn_boost_inmigracion)
	_btn_boost_inmigracion.pressed.connect(_on_boost_inmigracion)
	caja.add_child(_btn_boost_inmigracion)

	_btn_racionamiento.icon = IconosHUD.icono("comida")
	_btn_racionamiento.expand_icon = true
	TemaHUD.estilizar_boton(_btn_racionamiento)
	_btn_racionamiento.pressed.connect(func() -> void:
		if ciudad != null and ciudad.has_method("alternar_decreto_racionamiento"):
			ciudad.alternar_decreto_racionamiento()
			_actualizar())
	caja.add_child(_btn_racionamiento)
	for boton in [_toggle_colonizable, _remodelar, _pausar, _prioridad, _demoler, _asignar_nucleo]:
		boton.expand_icon = true
		TemaHUD.estilizar_boton(boton)
		caja.add_child(boton)
	_toggle_colonizable.pressed.connect(func() -> void:
		if ciudad != null and ciudad.has_method("alternar_colonizable"):
			ciudad.alternar_colonizable(id)
			_actualizar())
	_remodelar.pressed.connect(_on_remodelar)
	_pausar.pressed.connect(func() -> void:
		obras.alternar_pausa(id)
		_actualizar())
	_prioridad.pressed.connect(_ciclar_prioridad)
	_demoler.pressed.connect(_on_demoler)
	_dialogo_demoler.title = Strings.PANEL_EDIFICIO_MODAL_TITULO_DEMOLER
	_dialogo_demoler.dialog_text = Strings.PANEL_EDIFICIO_MODAL_TEXTO_DEMOLER
	_dialogo_demoler.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_demoler.cancel_button_text = Strings.PANEL_EDIFICIO_BTN_CANCELAR
	_dialogo_demoler.confirmed.connect(_confirmar_demoler)
	TemaHUD.estilizar_dialogo(_dialogo_demoler)
	add_child(_dialogo_demoler)

	_asignar_nucleo.pressed.connect(_on_asignar_nucleo)
	_dialogo_traslado.title = "Confirmar traslado de núcleo"
	_dialogo_traslado.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_traslado.cancel_button_text = Strings.PANEL_EDIFICIO_BTN_CANCELAR
	_dialogo_traslado.confirmed.connect(_confirmar_traslado)
	TemaHUD.estilizar_dialogo(_dialogo_traslado)
	add_child(_dialogo_traslado)

	_dialogo_remodelar.title = Strings.PANEL_EDIFICIO_MODAL_TITULO_REMODELAR
	_dialogo_remodelar.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_remodelar.cancel_button_text = Strings.PANEL_EDIFICIO_BTN_CANCELAR
	_dialogo_remodelar.confirmed.connect(_confirmar_remodelar)
	_dialogo_remodelar.canceled.connect(_cancelar_remodelar)
	TemaHUD.estilizar_dialogo(_dialogo_remodelar)
	add_child(_dialogo_remodelar)


func abrir(nuevo_id: int) -> void:
	if obras.resumen_de(nuevo_id).is_empty():
		return
	id = nuevo_id
	visible = true
	_actualizar()


func cerrar() -> void:
	visible = false
	id = -1


func _process(_delta: float) -> void:
	if not visible:
		return
	if obras.resumen_de(id).is_empty():
		cerrar()  # el edificio desapareció con la ventana abierta
		return
	_actualizar()


func _on_demoler() -> void:
	if (obras.has_method("esta_programada") and obras.esta_programada(id)) or (obras.has_method("esta_marcado") and obras.esta_marcado(id)):
		var motivo: String = ""
		if obras.has_method("cancelar_demolicion"):
			motivo = str(obras.cancelar_demolicion(id))
		else:
			motivo = obras.alternar_marca(id)
		if motivo != "":
			aviso.emit(motivo)
		_actualizar()
		return

	var es_res: bool = false
	var resumen: Dictionary = obras.resumen_de(id)
	if not resumen.is_empty() and resumen.get("tipo", "") == "Residencial":
		es_res = true

	if es_res:
		var total_res := 0
		var desgloses: Array = []
		if colonos != null and colonos.has_method("residentes_en"):
			var conteo: Dictionary = colonos.residentes_en(id)
			for t in conteo:
				if conteo[t] > 0:
					total_res += conteo[t]
					desgloses.append("%s: %d" % [t.capitalize(), conteo[t]])
		var sin_techo: int = 0
		if ciudad != null and ciudad.has_method("calcular_sin_techo_al_remodelar"):
			sin_techo = ciudad.calcular_sin_techo_al_remodelar(id)
		var reubicados: int = max(0, total_res - sin_techo)

		var texto: String = Strings.PANEL_EDIFICIO_MODAL_TEXTO_DEMOLER
		if total_res > 0:
			texto += "\n\nResidentes actuales (%s): %d" % [", ".join(desgloses), total_res]
			texto += "\n• Reubicados en camas libres: %d" % reubicados
			if sin_techo > 0:
				texto += "\n• Advertencia: %d colono(s) quedarán sin techo (%d h para reubicarse)." % [sin_techo, Ajustes.CIUDAD_TOLERANCIA_SIN_TECHO_HORAS]
		_dialogo_demoler.dialog_text = texto
	else:
		_dialogo_demoler.dialog_text = Strings.PANEL_EDIFICIO_MODAL_TEXTO_DEMOLER
	_dialogo_demoler.popup_centered()


func _confirmar_demoler() -> void:
	var motivo: String = ""
	if obras.has_method("programar_demolicion"):
		motivo = obras.programar_demolicion(id, Ajustes.OBRAS_HORAS_PROGRAMADAS)
	else:
		motivo = obras.alternar_marca(id)
	if motivo != "":
		aviso.emit(motivo)
	_actualizar()


func _on_asignar_nucleo() -> void:
	if ciudad != null and ciudad.has_method("esta_traslado_programado") and ciudad.esta_traslado_programado(id):
		ciudad.cancelar_traslado_nucleo()
		_actualizar()
		return
	var deficit: float = 0.0
	if ciudad != null and ciudad.has_method("calcular_deficit_traslado"):
		deficit = ciudad.calcular_deficit_traslado(id)
	if deficit > 0.0:
		_dialogo_traslado.dialog_text = Strings.PANEL_EDIFICIO_MODAL_TEXTO_TRASLADO_DEFICIT % int(ceil(deficit))
	else:
		_dialogo_traslado.dialog_text = Strings.PANEL_EDIFICIO_MODAL_TEXTO_TRASLADO_OK
	_dialogo_traslado.popup_centered()


func _confirmar_traslado() -> void:
	if ciudad != null and ciudad.has_method("programar_traslado_nucleo"):
		ciudad.programar_traslado_nucleo(id, Ajustes.CIUDAD_HORAS_TRASLADO_NUCLEO)
	_actualizar()


func _ciclar_prioridad() -> void:
	if obras == null or not obras.has_method("fijar_prioridad"):
		return
	var p_actual: int = obras.prioridad_de(id) if obras.has_method("prioridad_de") else 1
	var nueva_p: int = 1
	if p_actual == 1:
		nueva_p = 2  # Normal -> Alta
	elif p_actual == 2:
		nueva_p = 0  # Alta -> Baja
	else:
		nueva_p = 1  # Baja -> Normal
	obras.fijar_prioridad(id, nueva_p)
	_actualizar()


func _on_remodelar() -> void:
	var es_nucleo: bool = false
	if obras != null and obras.has_method("es_del_nucleo"):
		es_nucleo = obras.es_del_nucleo(id)
	elif ciudad != null and ciudad.get("id_nucleo") != null and ciudad.id_nucleo == id:
		es_nucleo = true

	if es_nucleo:
		_dialogo_remodelar.dialog_text = "¿Iniciar remodelación del núcleo urbano?\nPasará a modo de edición libre inmediatamente."
	else:
		var total_res := 0
		var desgloses: Array = []
		if colonos != null and colonos.has_method("residentes_en"):
			var conteo: Dictionary = colonos.residentes_en(id)
			for t in conteo:
				if conteo[t] > 0:
					total_res += conteo[t]
					desgloses.append("%s: %d" % [t.capitalize(), conteo[t]])
		var sin_techo: int = 0
		if ciudad != null and ciudad.has_method("calcular_sin_techo_al_remodelar"):
			sin_techo = ciudad.calcular_sin_techo_al_remodelar(id)
		var reubicados: int = max(0, total_res - sin_techo)

		var texto := "¿Iniciar remodelación de este edificio?\nEl edificio pasará a edición libre."
		if total_res > 0:
			texto += "\n\nResidentes actuales (%s): %d" % [", ".join(desgloses), total_res]
			texto += "\n• Reubicados en camas libres: %d" % reubicados
			if sin_techo > 0:
				texto += "\n• Advertencia: %d colono(s) quedarán sin techo (24 h para reubicarse)." % sin_techo
		_dialogo_remodelar.dialog_text = texto
	_dialogo_remodelar.popup_centered()



func solicitar_remodelacion(nuevo_id: int) -> void:
	id = nuevo_id
	_on_remodelar()


func _cancelar_remodelar() -> void:
	_restaurar_cursor_si_jugador()


func _restaurar_cursor_si_jugador() -> void:
	var player = get_node_or_null("/root/Main/Player")
	if player != null and player.get("camara") != null and player.camara.current:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_boost_inmigracion() -> void:
	if ciudad != null and ciudad.has_method("activar_boost_inmigracion"):
		if ciudad.activar_boost_inmigracion():
			aviso.emit("¡Impulso de inmigración activado en el núcleo urbano por 30 días!")
			_actualizar()

func _confirmar_remodelar() -> void:
	var mundo = null
	if obras != null and obras.get("mundo") != null:
		mundo = obras.mundo
	elif get_node_or_null("/root/Main/VoxelWorld") != null:
		mundo = get_node("/root/Main/VoxelWorld")
	if mundo == null:
		return
	var resultado: Dictionary = FinalizacionObras.iniciar_remodelacion(mundo, id)
	if resultado.get("exito", false):
		aviso.emit(resultado.get("mensaje", Strings.PANEL_EDIFICIO_NOTIF_REMODELACION_INICIADA))
		cerrar()
	else:
		aviso.emit(Strings.PANEL_EDIFICIO_ERR_REMODELACION % resultado.get("motivo", ""))
	_restaurar_cursor_si_jugador()


func _actualizar() -> void:
	var r: Dictionary = obras.resumen_de(id)
	if r.is_empty():
		return
	var estado: String = r["estado"]
	var es_nucleo: bool = false
	if obras != null and obras.has_method("es_del_nucleo"):
		es_nucleo = obras.es_del_nucleo(id)
	elif ciudad != null and ciudad.get("id_nucleo") != null and ciudad.id_nucleo == id:
		es_nucleo = true

	var es_residencial: bool = es_nucleo or r["tipo"].to_lower().contains("residencial")

	if es_nucleo:
		_icono_titulo.texture = IconosHUD.icono("ayuntamiento")
		_titulo.text = "Núcleo urbano"
		_tipo.text = "Tipo: Núcleo urbano"
	elif es_residencial:
		_icono_titulo.texture = IconosHUD.icono("cat_residencial")
		_titulo.text = Strings.FINALIZACION_NOMBRE_EDIFICIO_RESIDENCIAL
		_tipo.text = "Tipo: %s" % r["tipo"]
	else:
		_icono_titulo.texture = IconosHUD.icono("modo_construir")
		_titulo.text = r["nombre"]
		_tipo.text = "Tipo: %s" % r["tipo"]

	if es_residencial:
		_fila_camas.visible = true
		_fila_baules.visible = true
		_camas.visible = true
		_baules.visible = true
		_residentes.visible = true
		var cant_camas: int = ciudad.camas_de(id) if ciudad != null and ciudad.has_method("camas_de") else 0
		var cant_baules: int = ciudad.baules_de(id) if ciudad != null and ciudad.has_method("baules_de") else 0
		_camas.text = "Camas: %d" % cant_camas
		_baules.text = "Baúles: %d" % cant_baules

		var partes_res: Array = []
		if colonos != null and colonos.has_method("residentes_en"):
			var conteo: Dictionary = colonos.residentes_en(id)
			for tipo_colono in conteo:
				if conteo[tipo_colono] > 0:
					partes_res.append("%s: %d" % [tipo_colono.capitalize(), conteo[tipo_colono]])
		if partes_res.is_empty():
			_residentes.text = "Residentes: Ninguno"
		else:
			_residentes.text = "Residentes: " + ", ".join(partes_res)
	else:
		_fila_camas.visible = false
		_fila_baules.visible = false
		_camas.visible = false
		_baules.visible = false
		_residentes.visible = false

	if es_residencial and not es_nucleo:
		_colonizable.visible = true
		var col: bool = ciudad.es_colonizable(id) if ciudad != null and ciudad.has_method("es_colonizable") else false
		if col:
			_colonizable.text = "Colonizable: SÍ (inmigración activa)"
			_toggle_colonizable.text = "Pausar colonización"
			_toggle_colonizable.icon = IconosHUD.icono("puerta_candado")
		else:
			var h_rest: int = ciudad.horas_colonizacion_restantes(id) if ciudad != null and ciudad.has_method("horas_colonizacion_restantes") else 0
			if h_rest > 0:
				_colonizable.text = "Colonizable: NO (apertura en %d h)" % h_rest
				_toggle_colonizable.icon = IconosHUD.icono("puerta_reloj")
			else:
				_colonizable.text = "Colonizable: NO (buffer protegido)"
				_toggle_colonizable.icon = IconosHUD.icono("puerta_abierta")
			_toggle_colonizable.text = "Permitir colonización"
		_toggle_colonizable.visible = (estado == "completo")
	else:
		_colonizable.visible = false
		_toggle_colonizable.visible = false

	if estado == "demolicion_programada":
		_estado.text = Strings.PANEL_EDIFICIO_ESTADO_DEMOLICION_PROG % r.get("horas_demolicion", 5)
	else:
		_estado.text = "Estado: " + NOMBRES_ESTADO.get(estado, estado) + (" (pausada)" if r["pausada"] and estado != "completo" else "")
	_salud.text = "Salud: %d %%" % roundi(r["salud"] * 100.0)
	var en_obra: bool = estado != "completo"
	_obreros.visible = en_obra
	_obreros.text = "Obreros: %d" % (colonos.obreros_en(id) if colonos != null and colonos.has_method("obreros_en") else 0)
	var faltan: bool = estado == "construccion" and not r["faltantes"].is_empty()
	_materiales.visible = faltan
	_caja_faltantes.visible = faltan
	for h in _caja_faltantes.get_children():
		h.queue_free()
	if faltan:
		var partes: Array = []
		for recurso in r["faltantes"]:
			var nom_r: String = HUDScript.NOMBRES_RECURSO.get(recurso, recurso).capitalize()
			partes.append("%d %s (hay %d)" % [r["faltantes"][recurso], nom_r, int(_en_almacen(recurso))])
			var fila_mat := HBoxContainer.new()
			fila_mat.add_theme_constant_override("separation", 6)
			fila_mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic_rec := IconosHUD.crear_rect(recurso, 16)
			fila_mat.add_child(ic_rec)
			var lbl_mat := TemaHUD.etiqueta("%d %s (hay %d)" % [r["faltantes"][recurso], nom_r, int(_en_almacen(recurso))])
			fila_mat.add_child(lbl_mat)
			_caja_faltantes.add_child(fila_mat)
		_materiales.text = "Faltan: " + ", ".join(partes)
	if es_nucleo and estado == "completo":
		_btn_boost_inmigracion.visible = true
		if ciudad != null and ciudad.get("horas_boost_inmigracion") != null and ciudad.horas_boost_inmigracion > 0:
			var d_rest: int = ciudad.dias_boost_inmigracion_restantes()
			_btn_boost_inmigracion.text = Strings.VENTANA_MORAL_BTN_BOOST_ACTIVO % d_rest
			_btn_boost_inmigracion.disabled = true
		elif ciudad != null and not ciudad.puede_activar_boost_inmigracion():
			_btn_boost_inmigracion.text = Strings.VENTANA_MORAL_BTN_BOOST_BLOQUEADO_EXODO
			_btn_boost_inmigracion.disabled = true
		else:
			_btn_boost_inmigracion.text = Strings.VENTANA_MORAL_BTN_BOOST_ACTIVAR
			_btn_boost_inmigracion.disabled = false

		_btn_racionamiento.visible = true
		if ciudad != null and ciudad.get("decreto_racionamiento_activo"):
			_btn_racionamiento.text = Strings.PANEL_EDIFICIO_RACIONAMIENTO_ACTIVO
		else:
			_btn_racionamiento.text = Strings.PANEL_EDIFICIO_RACIONAMIENTO_INACTIVO
		_btn_racionamiento.tooltip_text = Strings.PANEL_EDIFICIO_RACIONAMIENTO_TOOLTIP
	else:
		_btn_boost_inmigracion.visible = false
		_btn_racionamiento.visible = false

	_pausar.visible = en_obra
	_pausar.text = Strings.PANEL_PUESTO_BTN_REANUDAR if r["pausada"] else ("Pausar demolición" if estado == "demolicion" else "Pausar construcción")
	_pausar.icon = IconosHUD.icono("btn_play" if r["pausada"] else "btn_pausa")

	var p_actual: int = obras.prioridad_de(id) if obras != null and obras.has_method("prioridad_de") else Ajustes.OBRAS_PRIORIDAD_NORMAL
	var nom_p: String = Strings.NOMBRES_PRIORIDAD.get(p_actual, Strings.NOMBRES_PRIORIDAD.get(1, "Normal"))
	_prioridad.visible = (estado == "construccion")
	_prioridad.text = "Prioridad: %s" % nom_p
	_prioridad.icon = IconosHUD.icono("prio_alta" if p_actual == Ajustes.OBRAS_PRIORIDAD_ALTA else ("prio_baja" if p_actual == Ajustes.OBRAS_PRIORIDAD_BAJA else "prio_normal"))

	_remodelar.visible = (es_residencial or es_nucleo) and (estado == "completo")
	_remodelar.text = "Iniciar remodelación"
	_remodelar.icon = IconosHUD.icono("remodelar")

	if es_nucleo:
		_demoler.visible = false
		_asignar_nucleo.visible = false
	else:
		_demoler.visible = true
		_demoler.text = Strings.PANEL_EDIFICIO_BTN_CANCELAR_DEMOLICION if (estado == "demolicion" or estado == "demolicion_programada") else "Demoler"
		_demoler.icon = IconosHUD.icono("modo_demoler")
		_asignar_nucleo.visible = es_residencial and estado == "completo"
		if _asignar_nucleo.visible:
			_asignar_nucleo.icon = IconosHUD.icono("asignar_nucleo")
			if ciudad != null and ciudad.has_method("esta_traslado_programado") and ciudad.esta_traslado_programado(id):
				_asignar_nucleo.text = "Cancelar traslado (%d h)" % ciudad.horas_traslado_programado()
			else:
				_asignar_nucleo.text = "Asignar como núcleo urbano"


func _en_almacen(recurso: String) -> float:
	var almacen: Dictionary = ciudad.almacen
	if recurso == "madera":
		return almacen["tablas"].cantidad + almacen["madera"].cantidad
	return almacen[recurso].cantidad if almacen.has(recurso) else 0.0
