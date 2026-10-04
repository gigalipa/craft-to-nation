extends PanelContainer

## Ventana de un edificio u obra (clic izquierdo sobre él en la cenital, ver
## CamaraCenital._procesar_clic_interaccion). Muestra nombre, tipo, estado, salud, obreros y
## materiales que faltan, y tiene los botones «Pausar/Reanudar» y «Demoler/Cancelar demolición».
## Las reglas viven en Obras/Colonos; esto solo las muestra y les pasa los clics.

const HUDScript = preload("res://scripts/HUD.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")

## Mensaje para el jugador (el HUD lo envía a las notificaciones).
signal aviso(texto: String)

const NOMBRES_ESTADO := {"construccion": "En construcción", "demolicion": "En demolición", "demolicion_programada": "Demolición programada", "completo": "Completo"}

var id := -1
var obras: Object = null
var colonos: Object = null
var ciudad: Object = null

var _titulo := TemaHUD.etiqueta()
var _tipo := TemaHUD.etiqueta()
var _camas := TemaHUD.etiqueta()
var _baules := TemaHUD.etiqueta()
var _residentes := TemaHUD.etiqueta()
var _estado := TemaHUD.etiqueta()
var _salud := TemaHUD.etiqueta()
var _obreros := TemaHUD.etiqueta()
var _materiales := TemaHUD.etiqueta()
var _pausar := Button.new()
var _demoler := Button.new()
var _asignar_nucleo := Button.new()
var _dialogo_demoler := ConfirmationDialog.new()
var _dialogo_traslado := ConfirmationDialog.new()


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
	_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	caja.add_child(_titulo)
	for etiqueta in [_tipo, _camas, _baules, _residentes, _estado, _salud, _obreros, _materiales]:
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)
	for boton in [_pausar, _demoler, _asignar_nucleo]:
		TemaHUD.estilizar_boton(boton)
		caja.add_child(boton)
	_pausar.pressed.connect(func() -> void:
		obras.alternar_pausa(id)
		_actualizar())
	_demoler.pressed.connect(_on_demoler)
	_dialogo_demoler.title = "Confirmar demolición"
	_dialogo_demoler.dialog_text = "¿Demoler este edificio? Comenzará en 5 horas de juego."
	_dialogo_demoler.ok_button_text = "Confirmar"
	_dialogo_demoler.cancel_button_text = "Cancelar"
	_dialogo_demoler.confirmed.connect(_confirmar_demoler)
	TemaHUD.estilizar_dialogo(_dialogo_demoler)
	add_child(_dialogo_demoler)

	_asignar_nucleo.pressed.connect(_on_asignar_nucleo)
	_dialogo_traslado.title = "Confirmar traslado de núcleo"
	_dialogo_traslado.ok_button_text = "Confirmar"
	_dialogo_traslado.cancel_button_text = "Cancelar"
	_dialogo_traslado.confirmed.connect(_confirmar_traslado)
	TemaHUD.estilizar_dialogo(_dialogo_traslado)
	add_child(_dialogo_traslado)


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
	_dialogo_demoler.popup_centered()


func _confirmar_demoler() -> void:
	var motivo: String = ""
	if obras.has_method("programar_demolicion"):
		motivo = obras.programar_demolicion(id, 5)
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
		_dialogo_traslado.dialog_text = "Advertencia: El nuevo núcleo no tiene suficientes camas.\nSe desahuciarán colonos (déficit equivalente a %.1f camas).\n¿Confirmar traslado en 5 horas?" % deficit
	else:
		_dialogo_traslado.dialog_text = "¿Asignar este edificio como núcleo urbano?\nEl traslado comenzará en 5 horas de juego."
	_dialogo_traslado.popup_centered()


func _confirmar_traslado() -> void:
	if ciudad != null and ciudad.has_method("programar_traslado_nucleo"):
		ciudad.programar_traslado_nucleo(id, 5)
	_actualizar()


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
		_titulo.text = "Núcleo urbano"
		_tipo.text = "Tipo: Núcleo urbano"
	elif es_residencial:
		_titulo.text = "Edificio residencial"
		_tipo.text = "Tipo: %s" % r["tipo"]
	else:
		_titulo.text = r["nombre"]
		_tipo.text = "Tipo: %s" % r["tipo"]

	if es_residencial:
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
		_camas.visible = false
		_baules.visible = false
		_residentes.visible = false

	if estado == "demolicion_programada":
		_estado.text = "Estado: Demolición programada (inicia en %d h)" % r.get("horas_demolicion", 5)
	else:
		_estado.text = "Estado: " + NOMBRES_ESTADO.get(estado, estado) + (" (pausada)" if r["pausada"] and estado != "completo" else "")
	_salud.text = "Salud: %d %%" % roundi(r["salud"] * 100.0)
	var en_obra: bool = estado != "completo"
	_obreros.visible = en_obra
	_obreros.text = "Obreros: %d" % (colonos.obreros_en(id) if colonos != null and colonos.has_method("obreros_en") else 0)
	var faltan: bool = estado == "construccion" and not r["faltantes"].is_empty()
	_materiales.visible = faltan
	if faltan:
		var partes: Array = []
		for recurso in r["faltantes"]:
			partes.append("%d %s (hay %d)" % [r["faltantes"][recurso], HUDScript.NOMBRES_RECURSO.get(recurso, recurso), int(_en_almacen(recurso))])
		_materiales.text = "Faltan: " + ", ".join(partes)
	_pausar.visible = en_obra
	_pausar.text = "Reanudar" if r["pausada"] else ("Pausar demolición" if estado == "demolicion" else "Pausar construcción")

	if es_nucleo:
		_demoler.visible = false
		_asignar_nucleo.visible = false
	else:
		_demoler.visible = true
		_demoler.text = "Cancelar demolición" if (estado == "demolicion" or estado == "demolicion_programada") else "Demoler"
		_asignar_nucleo.visible = es_residencial and estado == "completo"
		if _asignar_nucleo.visible:
			if ciudad != null and ciudad.has_method("esta_traslado_programado") and ciudad.esta_traslado_programado(id):
				_asignar_nucleo.text = "Cancelar traslado (%d h)" % ciudad.horas_traslado_programado()
			else:
				_asignar_nucleo.text = "Asignar como núcleo urbano"


func _en_almacen(recurso: String) -> float:
	var almacen: Dictionary = ciudad.almacen
	if recurso == "madera":
		return almacen["tablas"].cantidad + almacen["madera"].cantidad
	return almacen[recurso].cantidad if almacen.has(recurso) else 0.0
