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
## Petición para abrir el panel de puesto si esta obra era un puesto y se completó.
signal solicitar_abrir_puesto(esquina: Vector2i)

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
var _fila_prioridad := HBoxContainer.new()
var _icono_prioridad := TextureRect.new()
var _lbl_prioridad := TemaHUD.etiqueta()
var _btn_prioridad_subir := Button.new()
var _btn_prioridad_bajar := Button.new()
var _prioridad := Button.new()
var _demoler := Button.new()
var _asignar_nucleo := Button.new()
var _dialogo_demoler := ConfirmationDialog.new()
var _dialogo_traslado := ConfirmationDialog.new()
var _dialogo_remodelar := ConfirmationDialog.new()

var _caja_mejoras: VBoxContainer = null
var _lbl_mejoras_titulo: Label = null
var _lista_mejoras: VBoxContainer = null
var _cont_pm_activo: VBoxContainer = null
var _lbl_pm_estado: Label = null
var _barra_pm: ProgressBar = null
var _items_mejoras: Dictionary = {}
var _btn_reconversion: Button = null
var _dialogo_reconversion := ConfirmationDialog.new()
var _id_mejora_reconversion: String = ""


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
	_fila_prioridad.add_theme_constant_override("separation", 6)
	_fila_prioridad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono_prioridad.custom_minimum_size = Vector2(16, 16)
	_icono_prioridad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fila_prioridad.add_child(_icono_prioridad)

	_lbl_prioridad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_prioridad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_prioridad.size_flags_vertical = Control.SIZE_FILL
	_fila_prioridad.add_child(_lbl_prioridad)

	_btn_prioridad_subir.icon = IconosHUD.icono("btn_subir")
	_btn_prioridad_subir.custom_minimum_size = Vector2(24, 24)
	_btn_prioridad_subir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_prioridad_subir.expand_icon = true
	_btn_prioridad_subir.tooltip_text = "Aumentar prioridad de construcción"
	TemaHUD.estilizar_boton_icono(_btn_prioridad_subir)
	_btn_prioridad_subir.pressed.connect(_on_subir_prioridad)
	_fila_prioridad.add_child(_btn_prioridad_subir)

	_btn_prioridad_bajar.icon = IconosHUD.icono("btn_bajar")
	_btn_prioridad_bajar.custom_minimum_size = Vector2(24, 24)
	_btn_prioridad_bajar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_prioridad_bajar.expand_icon = true
	_btn_prioridad_bajar.tooltip_text = "Reducir prioridad de construcción"
	TemaHUD.estilizar_boton_icono(_btn_prioridad_bajar)
	_btn_prioridad_bajar.pressed.connect(_on_bajar_prioridad)
	_fila_prioridad.add_child(_btn_prioridad_bajar)

	caja.add_child(_fila_prioridad)

	for boton in [_toggle_colonizable, _remodelar, _pausar, _demoler, _asignar_nucleo]:
		boton.expand_icon = true
		TemaHUD.estilizar_boton(boton)
		caja.add_child(boton)
	_prioridad.visible = false
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

	_caja_mejoras = VBoxContainer.new()
	_caja_mejoras.add_theme_constant_override("separation", 4)
	caja.add_child(_caja_mejoras)

	_lbl_mejoras_titulo = TemaHUD.etiqueta("Mejoras Prácticas:")
	_lbl_mejoras_titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_caja_mejoras.add_child(_lbl_mejoras_titulo)

	_lista_mejoras = VBoxContainer.new()
	_lista_mejoras.add_theme_constant_override("separation", 4)
	_caja_mejoras.add_child(_lista_mejoras)

	_cont_pm_activo = VBoxContainer.new()
	_cont_pm_activo.add_theme_constant_override("separation", 2)
	_lbl_pm_estado = TemaHUD.etiqueta()
	_lbl_pm_estado.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_cont_pm_activo.add_child(_lbl_pm_estado)
	_barra_pm = ProgressBar.new()
	_barra_pm.show_percentage = true
	_barra_pm.custom_minimum_size = Vector2(250, 14)
	_cont_pm_activo.add_child(_barra_pm)
	_cont_pm_activo.visible = false
	_lista_mejoras.add_child(_cont_pm_activo)

	for id_m in Ajustes.MEJORAS_PRACTICAS_CATALOGO:
		var m_box := VBoxContainer.new()
		m_box.add_theme_constant_override("separation", 2)

		var lbl_m := TemaHUD.etiqueta()
		lbl_m.visible = false
		m_box.add_child(lbl_m)

		var btn_m := Button.new()
		TemaHUD.estilizar_boton(btn_m)
		var id_cap_m: String = id_m
		btn_m.pressed.connect(func() -> void:
			var esq: Vector2i = _esquina_de_puesto()
			if esq != Vector2i(-1, -1) and Economia != null and Economia.has_method("iniciar_mejora_practica"):
				Economia.iniciar_mejora_practica(esq, id_cap_m)
				_actualizar()
		)
		btn_m.visible = false
		m_box.add_child(btn_m)

		m_box.visible = false
		_lista_mejoras.add_child(m_box)
		_items_mejoras[id_m] = {
			"contenedor": m_box,
			"lbl": lbl_m,
			"btn": btn_m,
		}

	_btn_reconversion = Button.new()
	_btn_reconversion.text = Strings.RECONVERSION_BTN_INICIAR
	_btn_reconversion.icon = IconosHUD.icono("modo_construir")
	_btn_reconversion.expand_icon = true
	_btn_reconversion.tooltip_text = Strings.RECONVERSION_TOOLTIP
	TemaHUD.estilizar_boton(_btn_reconversion)
	_btn_reconversion.pressed.connect(func() -> void:
		if _id_mejora_reconversion != "":
			_dialogo_reconversion.popup_centered()
	)
	_caja_mejoras.add_child(_btn_reconversion)

	_dialogo_reconversion.title = Strings.RECONVERSION_BTN_INICIAR
	_dialogo_reconversion.dialog_text = "¿Deseas iniciar la reconversión industrial doctrinal de este edificio?"
	_dialogo_reconversion.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_reconversion.cancel_button_text = Strings.PANEL_PUESTO_BTN_CANCELAR
	_dialogo_reconversion.confirmed.connect(_confirmar_reconversion)
	TemaHUD.estilizar_dialogo(_dialogo_reconversion)
	add_child(_dialogo_reconversion)


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


func _on_subir_prioridad() -> void:
	if obras == null or not obras.has_method("fijar_prioridad"):
		return
	var p: int = obras.prioridad_de(id) if obras.has_method("prioridad_de") else Ajustes.OBRAS_PRIORIDAD_NORMAL
	if p < Ajustes.OBRAS_PRIORIDAD_ALTA:
		obras.fijar_prioridad(id, p + 1)
		_actualizar()


func _on_bajar_prioridad() -> void:
	if obras == null or not obras.has_method("fijar_prioridad"):
		return
	var p: int = obras.prioridad_de(id) if obras.has_method("prioridad_de") else Ajustes.OBRAS_PRIORIDAD_NORMAL
	if p > Ajustes.OBRAS_PRIORIDAD_BAJA:
		obras.fijar_prioridad(id, p - 1)
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

	if estado == "completo":
		var esq_p: Vector2i = _esquina_de_puesto()
		if esq_p != Vector2i(-1, -1) and Recoleccion != null and Recoleccion.puestos.has(esq_p):
			solicitar_abrir_puesto.emit(esq_p)
			cerrar()
			return

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
	_fila_prioridad.visible = (estado == "construccion")
	_lbl_prioridad.text = "Prioridad: %s" % nom_p
	_icono_prioridad.texture = IconosHUD.icono("prio_alta" if p_actual == Ajustes.OBRAS_PRIORIDAD_ALTA else ("prio_baja" if p_actual == Ajustes.OBRAS_PRIORIDAD_BAJA else "prio_normal"))
	_btn_prioridad_subir.disabled = (p_actual >= Ajustes.OBRAS_PRIORIDAD_ALTA)
	_btn_prioridad_bajar.disabled = (p_actual <= Ajustes.OBRAS_PRIORIDAD_BAJA)
	_prioridad.visible = false

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

	if _caja_mejoras != null:
		var esq: Vector2i = _esquina_de_puesto()
		if esq != Vector2i(-1, -1) and Economia.tiene_puesto(esq):
			var puesto: Dictionary = Economia.puestos[esq]
			var tipo_puesto: String = puesto.get("tipo", "")
			var posibles_mejoras: Array = []
			for id_m in Ajustes.MEJORAS_PRACTICAS_CATALOGO:
				var m_data: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO[id_m]
				if m_data.get("edificio_tipo", "") == tipo_puesto:
					posibles_mejoras.append(id_m)

			if posibles_mejoras.is_empty():
				_caja_mejoras.visible = false
			else:
				_caja_mejoras.visible = true
				var instaladas: Array = puesto.get("mejoras", [])
				var pm: Dictionary = puesto.get("proyecto_mejora", {})
				var era_actual_ciudad: int = ciudad.era_actual if (ciudad != null and "era_actual" in ciudad) else 1

				if not pm.is_empty():
					_cont_pm_activo.visible = true
					var id_act_m: String = pm.get("id", "")
					var info_pm: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(id_act_m, {})
					var nom_pm: String = info_pm.get("nombre", id_act_m)
					var estado_pm: String = pm.get("estado", "ESPERANDO_PERSONAL")
					var es_rec: bool = pm.get("es_reconversion", false) or puesto.get("estado_operativo", "") == "RECONVERSION"
					var req_inv: int = int(pm.get("investigadores_requeridos", 1))

					var id_proy: String = "mejora_%d_%d" % [esq.x, esq.y]
					var presentes_inv: int = 0
					if colonos != null and "comisiones_activas" in colonos and colonos.comisiones_activas.has(id_proy):
						var com_info: Dictionary = colonos.comisiones_activas[id_proy]
						var dest_proy: Vector3i = com_info.get("destino", Vector3i.ZERO)
						for cid in com_info.get("miembros", []):
							if colonos.colonos.has(cid) and colonos.colonos[cid].get("celda") == dest_proy:
								presentes_inv += 1

					var desc_est := "Esperando personal científico (%d/%d)" % [presentes_inv, req_inv]
					if estado_pm == "EN_EJECUCION":
						desc_est = "En ejecución (%d/%d)" % [presentes_inv, req_inv]
					var prefijo := "Reconversión" if es_rec else "Mejora"
					_lbl_pm_estado.text = "⚙ %s: %s\nEstado: %s" % [prefijo, nom_pm, desc_est]

					var prog_m: float = float(pm.get("progreso", 0.0))
					var t_total: float = float(pm.get("tiempo", 1.0))
					_barra_pm.max_value = t_total
					_barra_pm.value = prog_m

					for id_m in _items_mejoras:
						_items_mejoras[id_m]["contenedor"].visible = false
					_btn_reconversion.visible = false
				else:
					_cont_pm_activo.visible = false
					var incompatible_para_reconversion: String = ""
					for id_m in _items_mejoras:
						var item_m: Dictionary = _items_mejoras[id_m]
						var info_m: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO[id_m]
						if info_m.get("edificio_tipo", "") != tipo_puesto:
							item_m["contenedor"].visible = false
							continue

						item_m["contenedor"].visible = true
						var nom_m: String = info_m.get("nombre", id_m)
						var doc_m: String = info_m.get("doctrina", "")
						var nom_doc: String = Strings.DOCTRINA_NOMBRES.get(doc_m, doc_m.capitalize())

						if instaladas.has(id_m):
							item_m["lbl"].visible = true
							item_m["lbl"].text = "✅ %s (%s)" % [nom_m, nom_doc]
							item_m["lbl"].add_theme_color_override("font_color", TemaHUD.color_doctrina(doc_m))
							item_m["btn"].visible = false
						else:
							var prerreq_m: String = info_m.get("prerrequisito", "")
							var req_ok: bool = prerreq_m == "" or (ciudad != null and ciudad.has_method("esta_ciencia_descubierta") and ciudad.esta_ciencia_descubierta(prerreq_m))
							var era_ok: bool = int(info_m.get("era", 1)) <= era_actual_ciudad

							var es_incompatible: bool = false
							for ex in info_m.get("excluye", []):
								if instaladas.has(ex):
									es_incompatible = true
									break
							for m_inst in instaladas:
								var inst_data: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(m_inst, {})
								if inst_data.get("excluye", []).has(id_m):
									es_incompatible = true
									break
								if inst_data.get("doctrina", "") != "" and doc_m != "" and inst_data.get("doctrina", "") != doc_m:
									es_incompatible = true

							if es_incompatible:
								if req_ok and era_ok:
									incompatible_para_reconversion = id_m
								item_m["lbl"].visible = true
								item_m["lbl"].text = "⚠ %s (Incompatible)" % nom_m
								item_m["lbl"].add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
								item_m["btn"].visible = false
							elif not req_ok:
								var nom_req: String = Ajustes.CIENCIAS_TEORICAS_CATALOGO.get(prerreq_m, {}).get("nombre", prerreq_m)
								item_m["lbl"].visible = true
								item_m["lbl"].text = "🔒 %s (Requiere: %s)" % [nom_m, nom_req]
								item_m["lbl"].add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
								item_m["btn"].visible = false
							elif not era_ok:
								item_m["lbl"].visible = true
								item_m["lbl"].text = "🔒 %s (Requiere Era %d)" % [nom_m, int(info_m.get("era", 1))]
								item_m["lbl"].add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
								item_m["btn"].visible = false
							else:
								item_m["lbl"].visible = false
								item_m["btn"].visible = true
								item_m["btn"].text = "Instalar: %s (%s)" % [nom_m, nom_doc]
								item_m["btn"].disabled = false

					if incompatible_para_reconversion != "" and instaladas.size() > 0:
						_btn_reconversion.visible = true
						_id_mejora_reconversion = incompatible_para_reconversion
						_btn_reconversion.text = "%s: %s" % [Strings.RECONVERSION_BTN_INICIAR, Ajustes.MEJORAS_PRACTICAS_CATALOGO[incompatible_para_reconversion]["nombre"]]
					else:
						_btn_reconversion.visible = false
		else:
			_caja_mejoras.visible = false


func _esquina_de_puesto() -> Vector2i:
	var mundo_obj = obras.get("mundo") if obras != null else null
	if mundo_obj != null and "edificio_metadata" in mundo_obj:
		var meta: Dictionary = mundo_obj.edificio_metadata.get(id, {})
		if meta.has("puesto") and meta["puesto"] is Vector2i:
			return meta["puesto"]
		if meta.has("puesto_nuevo") and meta["puesto_nuevo"] is Dictionary and meta["puesto_nuevo"].has("esquina"):
			return meta["puesto_nuevo"]["esquina"]
	if Economia != null and Economia.get("puestos") != null:
		for e in Economia.puestos:
			if obras != null and obras.has_method("id_en_columna") and obras.id_en_columna(e) == id:
				return e
	return Vector2i(-1, -1)


func _confirmar_reconversion() -> void:
	if _id_mejora_reconversion != "" and Economia != null and Economia.has_method("iniciar_reconversion_industrial"):
		var esq: Vector2i = _esquina_de_puesto()
		if esq != Vector2i(-1, -1):
			var exito: bool = Economia.iniciar_reconversion_industrial(esq, _id_mejora_reconversion)
			if exito:
				var nom_m: String = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(_id_mejora_reconversion, {}).get("nombre", _id_mejora_reconversion)
				aviso.emit(Strings.RECONVERSION_AVISO_COMPLETADA % nom_m)
		_actualizar()




func _en_almacen(recurso: String) -> float:
	var almacen: Dictionary = ciudad.almacen
	if recurso == "madera":
		var cant_m: float = almacen["madera"].cantidad if almacen.has("madera") else 0.0
		var cant_t: float = almacen["tablas"].cantidad if almacen.has("tablas") else 0.0
		return cant_m + cant_t
	elif recurso == "piedra":
		var cant_p: float = almacen["piedra"].cantidad if almacen.has("piedra") else 0.0
		var cant_bp: float = almacen["bloques_piedra"].cantidad if almacen.has("bloques_piedra") else 0.0
		return cant_p + cant_bp
	elif recurso == "vidrio":
		var cant_v: float = almacen["vidrio"].cantidad if almacen.has("vidrio") else 0.0
		var cant_t: float = almacen["tierra"].cantidad if almacen.has("tierra") else 0.0
		return cant_v + floorf(cant_t / 3.0)
	return almacen[recurso].cantidad if almacen.has(recurso) else 0.0
