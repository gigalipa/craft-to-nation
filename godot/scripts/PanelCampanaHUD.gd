extends Node

## Controlador UI no invasivo para la Campaña-Tutorial:
## - Tarjeta de objetivos activos con íconos vectoriales, keycaps y sub-hitos tachables
## - Burbuja discreta de la Voz Mística Interior (arriba-centro)

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")

const ICONO_CLIC_DERECHO := "res://assets/icons/click_der.svg"
const ICONO_CLIC_IZQUIERDO := "res://assets/icons/click_izq.svg"
const ICONO_SCROLL := "res://assets/icons/scroll.svg"

const TECLAS_KEYCAP := [
	"F11", "F12", "Shift", "Ctrl", "WASD", "Esc", "1-0",
	"W", "A", "S", "D", "Q", "E", "B", "C", "Z", "L", "T", "V", "G", "R", "F", "+",
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
]

var tarjeta_objetivos: PanelContainer
var burbuja_voz: PanelContainer

var _lbl_acto: Label
var _rtl_hitos: RichTextLabel
var _rtl_guia: RichTextLabel
var _sep_guia: HSeparator
var _caja_detalle: VBoxContainer
var _btn_colapsar: Button
var _lbl_voz: Label
var _colapsado: bool = false
var _tween_burbuja: Tween = null


func _init() -> void:
	_construir_tarjeta()
	_construir_burbuja()


func _ready() -> void:
	if Campana != null:
		Campana.paso_cambiado.connect(_on_paso_cambiado)
		if Campana.has_signal("hitos_cambiados"):
			Campana.hitos_cambiados.connect(_on_hitos_cambiados)
		Campana.estado_campana_cambiado.connect(_on_estado_campana_cambiado)
		sincronizar()
	if Configuracion != null:
		Configuracion.configuracion_cambiada.connect(_on_configuracion_cambiada)


func _construir_tarjeta() -> void:
	tarjeta_objetivos = PanelContainer.new()
	tarjeta_objetivos.custom_minimum_size = Vector2(360, 0)
	tarjeta_objetivos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta_objetivos.visible = false
	TemaHUD.aplicar_panel(tarjeta_objetivos)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta_objetivos.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_lbl_acto = TemaHUD.etiqueta()
	_lbl_acto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_acto.add_theme_color_override("font_color", TemaHUD.DORADO)
	_lbl_acto.add_theme_font_size_override("font_size", 13)
	_lbl_acto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_lbl_acto)

	var btn_voz := Button.new()
	var ic_voz := IconosHUD.icono("btn_play")
	if ic_voz != null:
		btn_voz.icon = ic_voz
		btn_voz.expand_icon = true
	else:
		btn_voz.text = "▶"
	btn_voz.tooltip_text = Strings.t("CAMPANA_HUD_REPETIR_VOZ", "Repetir voz")
	btn_voz.custom_minimum_size = Vector2(28, 24)
	TemaHUD.estilizar_boton_icono(btn_voz)
	btn_voz.pressed.connect(func():
		if Campana != null:
			Campana.repetir_voz_actual()
	)
	header.add_child(btn_voz)

	_btn_colapsar = Button.new()
	_btn_colapsar.text = "▼"
	_btn_colapsar.custom_minimum_size = Vector2(28, 24)
	TemaHUD.estilizar_boton_icono(_btn_colapsar)
	_btn_colapsar.pressed.connect(func():
		_colapsado = not _colapsado
		_btn_colapsar.text = "▶" if _colapsado else "▼"
		_caja_detalle.visible = not _colapsado
	)
	header.add_child(_btn_colapsar)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "×"
	btn_cerrar.tooltip_text = Strings.t("CAMPANA_HUD_MODO_LIBRE", "Modo libre")
	btn_cerrar.custom_minimum_size = Vector2(28, 24)
	TemaHUD.estilizar_boton_icono(btn_cerrar)
	btn_cerrar.pressed.connect(func():
		if Campana != null:
			Campana.pasar_a_modo_libre()
	)
	header.add_child(btn_cerrar)

	_caja_detalle = VBoxContainer.new()
	_caja_detalle.add_theme_constant_override("separation", 6)
	_caja_detalle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_caja_detalle)

	_rtl_hitos = RichTextLabel.new()
	_rtl_hitos.bbcode_enabled = true
	_rtl_hitos.fit_content = true
	_rtl_hitos.scroll_active = false
	_rtl_hitos.custom_minimum_size = Vector2(340, 0)
	_rtl_hitos.add_theme_color_override("default_color", TemaHUD.TEXTO)
	_rtl_hitos.add_theme_font_size_override("normal_font_size", 12)
	_rtl_hitos.add_theme_font_size_override("bold_font_size", 12)
	_rtl_hitos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_detalle.add_child(_rtl_hitos)

	_sep_guia = HSeparator.new()
	_sep_guia.modulate = Color(1.0, 0.85, 0.4, 0.35)
	_sep_guia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_detalle.add_child(_sep_guia)

	_rtl_guia = RichTextLabel.new()
	_rtl_guia.bbcode_enabled = true
	_rtl_guia.fit_content = true
	_rtl_guia.scroll_active = false
	_rtl_guia.custom_minimum_size = Vector2(340, 0)
	_rtl_guia.add_theme_color_override("default_color", Color(0.92, 0.90, 0.82, 0.94))
	_rtl_guia.add_theme_font_size_override("normal_font_size", 11)
	_rtl_guia.add_theme_font_size_override("bold_font_size", 11)
	_rtl_guia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_detalle.add_child(_rtl_guia)


func _construir_burbuja() -> void:
	burbuja_voz = PanelContainer.new()
	burbuja_voz.set_anchors_preset(Control.PRESET_CENTER_TOP)
	burbuja_voz.offset_left = -280
	burbuja_voz.offset_top = 58
	burbuja_voz.offset_right = 280
	burbuja_voz.offset_bottom = 130
	burbuja_voz.grow_horizontal = Control.GROW_DIRECTION_BOTH
	burbuja_voz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burbuja_voz.visible = false
	burbuja_voz.modulate.a = 0.0
	burbuja_voz.add_theme_stylebox_override("panel", TemaHUD.caja(Color("#0d2119eb"), TemaHUD.DORADO))

	_lbl_voz = TemaHUD.etiqueta()
	_lbl_voz.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_voz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_voz.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_lbl_voz.add_theme_font_size_override("font_size", 14)
	_lbl_voz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burbuja_voz.add_child(_lbl_voz)


static func formatear_bbcode_controles(texto: String, color_keycap: String = "#FFE082") -> String:
	var res := texto
	res = res.replace("{click_izq}", "[img=12x16]%s[/img]" % ICONO_CLIC_IZQUIERDO)
	res = res.replace("{click_der}", "[img=12x16]%s[/img]" % ICONO_CLIC_DERECHO)
	res = res.replace("{scroll}", "[img=12x16]%s[/img]" % ICONO_SCROLL)

	var pos_ico := res.find("{ico:")
	while pos_ico != -1:
		var fin_ico := res.find("}", pos_ico)
		if fin_ico == -1:
			break
		var clave := res.substr(pos_ico + 5, fin_ico - pos_ico - 5)
		var tag := IconosHUD.bbcode(clave, 15)
		res = res.substr(0, pos_ico) + tag + res.substr(fin_ico + 1)
		pos_ico = res.find("{ico:")

	for k in TECLAS_KEYCAP:
		var token := "[%s]" % k
		if res.contains(token):
			var cap := "[bgcolor=#1b3b2c][color=%s][b] %s [/b][/color][/bgcolor]" % [color_keycap, k]
			res = res.replace(token, cap)
	return res


func sincronizar() -> void:
	if Campana == null or not Campana.esta_activa():
		tarjeta_objetivos.visible = false
		burbuja_voz.visible = false
		return
	tarjeta_objetivos.visible = true
	var paso: Dictionary = Campana.obtener_paso_actual()
	if not paso.is_empty():
		_actualizar_textos_paso(paso, false, Campana.ultimos_hitos_cumplidos)


func _on_estado_campana_cambiado(activa: bool) -> void:
	tarjeta_objetivos.visible = activa
	if not activa:
		burbuja_voz.visible = false


func _on_paso_cambiado(paso: Dictionary) -> void:
	if paso.is_empty():
		return
	tarjeta_objetivos.visible = true
	var hitos_estado: Array = Campana.ultimos_hitos_cumplidos if Campana != null else []
	_actualizar_textos_paso(paso, true, hitos_estado)


func _on_hitos_cambiados(paso: Dictionary, cumplidos: Array) -> void:
	if paso.is_empty():
		return
	_actualizar_hitos_y_guia(paso, cumplidos)


func _on_configuracion_cambiada(clave: String, _valor: Variant) -> void:
	if clave == "idioma":
		sincronizar()


func _actualizar_hitos_y_guia(paso: Dictionary, cumplidos: Array) -> void:
	var hitos_keys: Array = paso.get("hitos", [])
	var lineas_hitos: Array[String] = []
	if hitos_keys.is_empty():
		lineas_hitos.append(formatear_bbcode_controles(Strings.t(str(paso.get("obj_key", "")))))
	else:
		for i in range(hitos_keys.size()):
			var txt_hito: String = Strings.t(str(hitos_keys[i]))
			var hecho: bool = i < cumplidos.size() and bool(cumplidos[i])
			if hecho:
				var fmt_done := formatear_bbcode_controles(txt_hito, "#9CE8B0")
				lineas_hitos.append("[color=#7BE495]✔ [s]%s[/s][/color]" % fmt_done)
			else:
				var fmt_pend := formatear_bbcode_controles(txt_hito)
				lineas_hitos.append("[color=#FFD54F]○[/color] %s" % fmt_pend)
	_rtl_hitos.text = "\n".join(lineas_hitos)

	var guia_key := str(paso.get("guia_key", ""))
	var texto_guia := Strings.t(guia_key, "") if guia_key != "" else ""
	if texto_guia.is_empty():
		_sep_guia.visible = false
		_rtl_guia.visible = false
	else:
		_sep_guia.visible = true
		_rtl_guia.visible = true
		var pref_guia := Strings.t("CAMPANA_HUD_GUIA_TITULO", "Guía:")
		_rtl_guia.text = "[color=#FFE082][b]%s[/b][/color] %s" % [pref_guia, formatear_bbcode_controles(texto_guia)]


func _actualizar_textos_paso(paso: Dictionary, mostrar_burbuja: bool, cumplidos: Array = []) -> void:
	_lbl_acto.text = Strings.t(str(paso.get("acto_key", "CAMPANA_ACTO_1")))
	_actualizar_hitos_y_guia(paso, cumplidos)
	if not mostrar_burbuja:
		return
	_lbl_voz.text = "«%s»" % Strings.t(str(paso.get("voz_key", "")))
	burbuja_voz.visible = true
	if _tween_burbuja != null and _tween_burbuja.is_valid():
		_tween_burbuja.kill()
	_tween_burbuja = create_tween()
	_tween_burbuja.tween_property(burbuja_voz, "modulate:a", 1.0, 0.35)
	var dur_burbuja: float = Ajustes.CAMPANA_DURACION_BURBUJA_VOZ_S
	if Campana != null and Campana.duracion_voz_actual_s > 0.0:
		dur_burbuja = maxf(dur_burbuja, Campana.duracion_voz_actual_s + 0.5)
	_tween_burbuja.tween_interval(dur_burbuja)
	_tween_burbuja.tween_property(burbuja_voz, "modulate:a", 0.0, 0.6)
	_tween_burbuja.tween_callback(func(): burbuja_voz.visible = false)
