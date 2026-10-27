extends PanelContainer

## Ventana emergente (clic en "Almacén" de la barra superior, solo cenital):
## inventario completo del núcleo, con cantidad/límite y tasa de cada recurso.
## Se actualiza en vivo mientras está visible. Arrastrable con el ratón;
## aparece por defecto en la esquina superior izquierda (debajo de la de
## Población, ver POSICION_INICIAL). Hijo de HUD (nunca se destruye): su
## posición y si está abierta o cerrada persisten solas mientras dura la
## partida, incluida al salir y volver a entrar a la cenital (HUD.set_vista()
## la oculta/restaura sin tocarlas).

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")

const POSICION_INICIAL := Vector2(16, 340)

## Contenido dinámico (una fila por recurso): esto es lo único que se
## reconstruye en cada _actualizar(). El título y su botón de cierre se
## crean una sola vez en _ready() (ver _caja_raiz) — reconstruirlos cada
## fotograma (como antes) destruía el botón a mitad de clic (entre el
## press y el release), así que el "pressed" nunca llegaba a emitirse.
var _caja := VBoxContainer.new()
var _caja_raiz := VBoxContainer.new()
var abierta := false
var _arrastrando := false
var _offset_arrastre := Vector2.ZERO
var _desplegado_comida: bool = false


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
	_caja_raiz.add_child(_fila_titulo(Strings.VENTANA_ALMACEN_TITULO))
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_raiz.add_child(_caja)


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


func ocultar_temporalmente() -> void:
	visible = false


func restaurar() -> void:
	visible = abierta


func _actualizar() -> void:
	for hijo in _caja.get_children():
		hijo.free()
	if Ciudad.almacen.is_empty():
		_caja.add_child(TemaHUD.etiqueta(Strings.PANEL_PUESTO_ALMACEN_VACIO))
		return
	var claves: Array = Ciudad.almacen.keys()
	claves.sort_custom(func(a: String, b: String) -> bool:
		var nom_a: String = HUDScript.NOMBRES_RECURSO.get(a, Ciudad.almacen[a].nombre if Ciudad.almacen.has(a) else a)
		var nom_b: String = HUDScript.NOMBRES_RECURSO.get(b, Ciudad.almacen[b].nombre if Ciudad.almacen.has(b) else b)
		return nom_a.nocasecmp_to(nom_b) < 0
	)
	for clave in claves:
		var recurso = Ciudad.almacen[clave]
		var nombre: String = HUDScript.NOMBRES_RECURSO.get(clave, recurso.nombre)

		if clave == "comida" and "sub_almacen_comida" in Ciudad:
			var bloque_comida := VBoxContainer.new()
			bloque_comida.add_theme_constant_override("separation", 2)
			bloque_comida.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_caja.add_child(bloque_comida)

			var btn_comida := Button.new()
			btn_comida.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn_comida.icon = IconosHUD.icono(IconosHUD.icono_recurso("comida"))
			btn_comida.text = "%s %s: %.0f/%.0f %s" % [
				"▼" if _desplegado_comida else "▶",
				nombre,
				recurso.cantidad,
				recurso.limite,
				BarraSuperiorScript.texto_tasa(recurso.tasa_neta_promedio)
			]
			TemaHUD.estilizar_boton(btn_comida)
			if recurso.tasa_neta_promedio < 0.0:
				btn_comida.add_theme_color_override("font_color", TemaHUD.INVALIDO)
			else:
				btn_comida.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
			btn_comida.pressed.connect(func() -> void:
				_desplegado_comida = not _desplegado_comida
				call_deferred("_actualizar")
			)
			bloque_comida.add_child(btn_comida)

			var margen_sub := MarginContainer.new()
			margen_sub.add_theme_constant_override("margin_left", 18)
			margen_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margen_sub.visible = _desplegado_comida
			bloque_comida.add_child(margen_sub)

			var caja_sub := VBoxContainer.new()
			caja_sub.add_theme_constant_override("separation", 2)
			caja_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margen_sub.add_child(caja_sub)

			for sub_cat in Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA:
				var cant_sc: float = Ciudad.sub_almacen_comida.get(sub_cat, 0.0)
				var nom_sub: String = Strings.NOMBRES_SUB_COMIDA.get(sub_cat, sub_cat.capitalize())
				var fila_sub := "%s: %.0f" % [nom_sub, cant_sc]
				var et_sub := TemaHUD.etiqueta(fila_sub)
				et_sub.add_theme_font_size_override("font_size", 12)
				if cant_sc <= 0.0:
					et_sub.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
				caja_sub.add_child(et_sub)
			continue

		var fila_cont := HBoxContainer.new()
		fila_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila_cont.add_theme_constant_override("separation", 6)
		var ic := IconosHUD.crear_rect(IconosHUD.icono_recurso(clave), 20)
		fila_cont.add_child(ic)
		var fila := "%s: %.0f/%.0f %s" % [nombre, recurso.cantidad, recurso.limite, BarraSuperiorScript.texto_tasa(recurso.tasa_neta_promedio)]
		var etiqueta := TemaHUD.etiqueta(fila)
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if recurso.tasa_neta_promedio < 0.0:
			etiqueta.add_theme_color_override("font_color", TemaHUD.INVALIDO)
		fila_cont.add_child(etiqueta)
		_caja.add_child(fila_cont)


func cerrar() -> void:
	abierta = false
	visible = false


func _fila_titulo(texto: String) -> Control:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cont_tit := HBoxContainer.new()
	cont_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := IconosHUD.crear_rect("almacen", 20)
	cont_tit.add_child(ic)
	var titulo := TemaHUD.etiqueta(texto.to_upper())
	titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	cont_tit.add_child(titulo)
	fila.add_child(cont_tit)

	var cerrar_boton := Button.new()
	cerrar_boton.text = ""
	cerrar_boton.icon = IconosHUD.icono("cruz")
	cerrar_boton.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(cerrar_boton)
	cerrar_boton.pressed.connect(cerrar)
	fila.add_child(cerrar_boton)
	return fila
