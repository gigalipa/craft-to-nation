extends PanelContainer

## Ventana de información de una canalización (acueducto o tubería) en vista cenital.
## Muestra el tipo de ducto, recurso transportado, edificios conectados en sus
## extremos y estado de la red (activo, derrame, abierto).

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")

signal aviso(texto: String)

var id_red: int = -1

var _icono_titulo := TextureRect.new()
var _titulo := TemaHUD.etiqueta()
var _tipo := TemaHUD.etiqueta()
var _recurso := TemaHUD.etiqueta()
var _longitud := TemaHUD.etiqueta()
var _conexiones := TemaHUD.etiqueta()
var _estado := TemaHUD.etiqueta()
var _demoler := Button.new()
var _dialogo_demoler := ConfirmationDialog.new()


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -280.0
	offset_bottom = -12.0
	offset_right = -12.0
	custom_minimum_size.x = 268.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var caja := VBoxContainer.new()
	add_child(caja)

	var fila_titulo := HBoxContainer.new()
	fila_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_titulo.add_theme_constant_override("separation", 6)
	_icono_titulo.custom_minimum_size = Vector2(20, 20)
	_icono_titulo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila_titulo.add_child(_icono_titulo)
	_titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var boton_x := Button.new()
	boton_x.icon = IconosHUD.icono("cruz")
	boton_x.custom_minimum_size = Vector2(24, 24)
	TemaHUD.estilizar_boton(boton_x)
	boton_x.pressed.connect(cerrar)
	fila_titulo.add_child(_titulo)
	fila_titulo.add_child(boton_x)
	caja.add_child(fila_titulo)

	for etiqueta in [_tipo, _recurso, _longitud, _conexiones, _estado]:
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)

	_demoler.icon = IconosHUD.icono("modo_demoler")
	_demoler.expand_icon = true
	TemaHUD.estilizar_boton(_demoler)
	_demoler.text = "Demoler canalización"
	_demoler.pressed.connect(_on_demoler)
	caja.add_child(_demoler)

	_dialogo_demoler.title = "Confirmar demolición"
	_dialogo_demoler.dialog_text = "¿Demoler esta canalización y recuperar los materiales?"
	_dialogo_demoler.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_demoler.cancel_button_text = Strings.PANEL_EDIFICIO_BTN_CANCELAR
	_dialogo_demoler.confirmed.connect(_confirmar_demoler)
	TemaHUD.estilizar_dialogo(_dialogo_demoler)
	add_child(_dialogo_demoler)


func abrir(nuevo_id: int) -> void:
	if not Canalizaciones.tipo_por_red.has(nuevo_id):
		return
	id_red = nuevo_id
	visible = true
	_actualizar()


func cerrar() -> void:
	visible = false
	id_red = -1


func _actualizar() -> void:
	if id_red == -1 or not Canalizaciones.tipo_por_red.has(id_red):
		cerrar()
		return

	var info: Dictionary = Canalizaciones.info_de_red(id_red)
	var tipo_str: String = Strings.CANALIZACIONES_NOMBRE_TUBERIA if info["tipo"] == "tuberia" else Strings.CANALIZACIONES_NOMBRE_ACUEDUCTO
	_titulo.text = "%s #%d" % [tipo_str, id_red]
	_icono_titulo.texture = IconosHUD.icono(info["tipo"])
	_tipo.text = "Tipo: %s" % ("Tubería industrial" if info["tipo"] == "tuberia" else "Acueducto elevado")

	var rec: String = info["recurso"]
	if rec == "agua":
		_recurso.text = "Recurso: 💧 Agua"
	elif rec == "crudo":
		_recurso.text = "Recurso: 🛢️ Crudo"
	elif rec == "combustible":
		_recurso.text = "Recurso: ⛽ Combustible"
	else:
		_recurso.text = "Recurso: ⚪ Sin fluido asignado"

	_longitud.text = "Longitud: %d celdas (%d columnas)" % [info["celdas_ducto"], info["celdas_columna"]]

	var lineas_con: Array[String] = ["Edificios conectados:"]
	var puertos: Array = info["puertos"]
	if puertos.is_empty():
		lineas_con.append("• Ninguno")
	else:
		for p_info in puertos:
			var simb := "🟢"
			if p_info["estado"] == "derrame":
				simb = "🔴"
			elif p_info["estado"] == "desconectado":
				simb = "⚪"
			lineas_con.append("• %s: %s (%s) %s" % [p_info["direccion"], p_info["edificio"], p_info["recurso"].capitalize(), simb])

	_conexiones.text = "\n".join(lineas_con)

	if not info["derrames"].is_empty():
		_estado.visible = true
		_estado.text = "⚠️ Estado: Derrame activo"
		_estado.add_theme_color_override("font_color", TemaHUD.INVALIDO)
	elif not info["extremos_abiertos"].is_empty():
		_estado.visible = true
		_estado.text = "⚠️ Estado: Extremo sin conectar"
		_estado.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		_estado.visible = true
		_estado.text = "Estado: Conexión cerrada"
		_estado.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))


func _on_demoler() -> void:
	_dialogo_demoler.popup_centered()


func _confirmar_demoler() -> void:
	if id_red == -1:
		return
	var m: Object = Economia.mundo if Economia != null and Economia.mundo != null else (get_tree().root.find_child("VoxelWorld", true, false) if get_tree() != null and get_tree().root != null else null)
	var celdas_a_quitar: Array = Canalizaciones.red_a_celdas.get(id_red, []).duplicate()
	for col: Vector3i in Canalizaciones.columnas.keys():
		if Canalizaciones.columnas[col] == id_red:
			celdas_a_quitar.append(col)
	Canalizaciones.quitar_celdas(celdas_a_quitar, m)
	aviso.emit("Canalización demolida.")
	cerrar()
