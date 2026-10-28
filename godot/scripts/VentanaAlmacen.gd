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

const HIJOS_DE_RECURSO := {
	"comida": ["_sub_almacen_comida_"],
	"crudo": ["combustible"],
	"hierro": ["acero"],
	"madera": ["tablas"],
	"piedra": ["bloques_piedra"],
	"tierra": ["vidrio"],
	"tierras_raras": ["mineral_refinado"],
}

var _caja := VBoxContainer.new()
var _caja_raiz := VBoxContainer.new()
var _btn_toggle_todo := Button.new()
var abierta := false
var _arrastrando := false
var _offset_arrastre := Vector2.ZERO
var _desplegados: Dictionary = {}

var _desplegado_comida: bool:
	get: return _desplegados.get("comida", false)
	set(v):
		_desplegados["comida"] = v
		if _contenedores_hijos.has("comida"):
			_contenedores_hijos["comida"].visible = v
		_actualizar_textos()

# Referencias a nodos para actualizar textos sin reconstruir la jerarquía cada fotograma
var _etiquetas_recurso: Dictionary = {}       # clave -> Label
var _botones_desplegable: Dictionary = {}     # clave -> Button
var _contenedores_hijos: Dictionary = {}      # clave -> MarginContainer
var _etiquetas_hijos: Dictionary = {}         # hijo_clave -> Label
var _etiquetas_sub_comida: Dictionary = {}    # sub_cat -> Label
var _claves_almacen_construidas: Array = []


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


func cerrar() -> void:
	abierta = false
	visible = false


func estan_todos_expandidos() -> bool:
	for clave in HIJOS_DE_RECURSO:
		if not _desplegados.get(clave, false):
			return false
	return true


func alternar_expandir_todo() -> void:
	var todos_abiertos := estan_todos_expandidos()
	var nuevo_estado := not todos_abiertos
	for clave in HIJOS_DE_RECURSO:
		_desplegados[clave] = nuevo_estado
		if _contenedores_hijos.has(clave):
			_contenedores_hijos[clave].visible = nuevo_estado
	_actualizar_boton_toggle_todo()
	_actualizar_textos()


func _actualizar_boton_toggle_todo() -> void:
	if _btn_toggle_todo == null:
		return
	if estan_todos_expandidos():
		_btn_toggle_todo.text = "Contraer todo"
		_btn_toggle_todo.icon = IconosHUD.icono("btn_menos")
	else:
		_btn_toggle_todo.text = "Expandir todo"
		_btn_toggle_todo.icon = IconosHUD.icono("btn_mas")


func toggle_desplegado(clave: String) -> void:
	var nuevo_estado: bool = not _desplegados.get(clave, false)
	_desplegados[clave] = nuevo_estado
	if _contenedores_hijos.has(clave):
		_contenedores_hijos[clave].visible = nuevo_estado
	_actualizar_boton_toggle_todo()
	_actualizar_textos()


func _necesita_reconstruir() -> bool:
	if _caja.get_child_count() == 0:
		return true
	if Ciudad.almacen.is_empty():
		return not _claves_almacen_construidas.is_empty()
	var claves_actuales := Ciudad.almacen.keys()
	claves_actuales.sort()
	return claves_actuales != _claves_almacen_construidas


func _actualizar() -> void:
	if _necesita_reconstruir():
		_construir_filas()
	_actualizar_textos()


func _construir_filas() -> void:
	for hijo in _caja.get_children():
		hijo.free()

	_etiquetas_recurso.clear()
	_botones_desplegable.clear()
	_contenedores_hijos.clear()
	_etiquetas_hijos.clear()
	_etiquetas_sub_comida.clear()
	_claves_almacen_construidas.clear()

	if Ciudad.almacen.is_empty():
		_caja.add_child(TemaHUD.etiqueta(Strings.PANEL_PUESTO_ALMACEN_VACIO))
		return

	var claves_ordenadas := Ciudad.almacen.keys()
	claves_ordenadas.sort()
	_claves_almacen_construidas = claves_ordenadas

	var es_hijo := {}
	for p in HIJOS_DE_RECURSO:
		for h in HIJOS_DE_RECURSO[p]:
			if h != "_sub_almacen_comida_":
				es_hijo[h] = true

	var claves_padre: Array = []
	for clave in Ciudad.almacen.keys():
		if not es_hijo.get(clave, false):
			claves_padre.append(clave)

	claves_padre.sort_custom(func(a: String, b: String) -> bool:
		var nom_a: String = HUDScript.NOMBRES_RECURSO.get(a, Ciudad.almacen[a].nombre if Ciudad.almacen.has(a) else a)
		var nom_b: String = HUDScript.NOMBRES_RECURSO.get(b, Ciudad.almacen[b].nombre if Ciudad.almacen.has(b) else b)
		return nom_a.nocasecmp_to(nom_b) < 0
	)

	for clave in claves_padre:
		var hijos: Array = HIJOS_DE_RECURSO.get(clave, [])

		if hijos.is_empty():
			var fila_cont := HBoxContainer.new()
			fila_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fila_cont.add_theme_constant_override("separation", 6)
			var ic := IconosHUD.crear_rect(IconosHUD.icono_recurso(clave), 20)
			fila_cont.add_child(ic)
			var etiqueta := TemaHUD.etiqueta("")
			etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila_cont.add_child(etiqueta)
			_caja.add_child(fila_cont)
			_etiquetas_recurso[clave] = etiqueta
		else:
			var bloque := VBoxContainer.new()
			bloque.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bloque.add_theme_constant_override("separation", 2)
			_caja.add_child(bloque)

			var btn_fila := Button.new()
			btn_fila.flat = true
			btn_fila.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn_fila.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn_fila.icon = IconosHUD.icono(IconosHUD.icono_recurso(clave))
			btn_fila.expand_icon = true
			btn_fila.add_theme_constant_override("icon_max_width", 20)
			btn_fila.add_theme_constant_override("h_separation", 6)
			btn_fila.focus_mode = Control.FOCUS_NONE

			var sb_vacio := StyleBoxEmpty.new()
			var sb_hover := StyleBoxFlat.new()
			sb_hover.bg_color = Color(1.0, 1.0, 1.0, 0.07)
			sb_hover.set_corner_radius_all(3)
			btn_fila.add_theme_stylebox_override("normal", sb_vacio)
			btn_fila.add_theme_stylebox_override("hover", sb_hover)
			btn_fila.add_theme_stylebox_override("pressed", sb_hover)
			btn_fila.add_theme_stylebox_override("focus", sb_vacio)
			btn_fila.add_theme_stylebox_override("disabled", sb_vacio)
			btn_fila.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.88))
			btn_fila.add_theme_color_override("font_pressed_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)

			btn_fila.pressed.connect(func() -> void:
				toggle_desplegado(clave)
			)
			bloque.add_child(btn_fila)
			_botones_desplegable[clave] = btn_fila

			var margen_hijos := MarginContainer.new()
			margen_hijos.add_theme_constant_override("margin_left", 24)
			margen_hijos.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bloque.add_child(margen_hijos)
			_contenedores_hijos[clave] = margen_hijos

			var caja_hijos := VBoxContainer.new()
			caja_hijos.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caja_hijos.add_theme_constant_override("separation", 4)
			margen_hijos.add_child(caja_hijos)

			if clave == "comida" and "sub_almacen_comida" in Ciudad:
				for sub_cat in Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA:
					var fila_sub_cont := HBoxContainer.new()
					fila_sub_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
					fila_sub_cont.add_theme_constant_override("separation", 6)
					var ic_sub := IconosHUD.crear_rect(IconosHUD.icono_recurso("comida"), 20)
					fila_sub_cont.add_child(ic_sub)
					var et_sub := TemaHUD.etiqueta("")
					fila_sub_cont.add_child(et_sub)
					caja_hijos.add_child(fila_sub_cont)
					_etiquetas_sub_comida[sub_cat] = et_sub
			else:
				for hijo_clave in hijos:
					var fila_hijo_cont := HBoxContainer.new()
					fila_hijo_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
					fila_hijo_cont.add_theme_constant_override("separation", 6)
					var ic_hijo := IconosHUD.crear_rect(IconosHUD.icono_recurso(hijo_clave), 20)
					fila_hijo_cont.add_child(ic_hijo)
					var et_hijo := TemaHUD.etiqueta("")
					fila_hijo_cont.add_child(et_hijo)
					caja_hijos.add_child(fila_hijo_cont)
					_etiquetas_hijos[hijo_clave] = et_hijo

			margen_hijos.visible = _desplegados.get(clave, false)


func _actualizar_textos() -> void:
	if Ciudad.almacen.is_empty():
		return

	# 1. Filas sin hijos
	for clave in _etiquetas_recurso:
		if not Ciudad.almacen.has(clave):
			continue
		var recurso = Ciudad.almacen[clave]
		var nombre: String = HUDScript.NOMBRES_RECURSO.get(clave, recurso.nombre)
		var etiqueta: Label = _etiquetas_recurso[clave]
		etiqueta.text = "%s: %.0f/%.0f %s" % [
			nombre,
			recurso.cantidad,
			recurso.limite,
			BarraSuperiorScript.texto_tasa(recurso.tasa_neta_promedio)
		]
		etiqueta.add_theme_color_override("font_color", TemaHUD.INVALIDO if recurso.tasa_neta_promedio < 0.0 else TemaHUD.TEXTO)

	# 2. Filas desplegables
	for clave in _botones_desplegable:
		if not Ciudad.almacen.has(clave):
			continue
		var recurso = Ciudad.almacen[clave]
		var nombre: String = HUDScript.NOMBRES_RECURSO.get(clave, recurso.nombre)
		var esta_abierto: bool = _desplegados.get(clave, false)
		var flecha := "▼" if esta_abierto else "▶"
		var btn: Button = _botones_desplegable[clave]
		btn.text = "%s %s: %.0f/%.0f %s" % [
			flecha,
			nombre,
			recurso.cantidad,
			recurso.limite,
			BarraSuperiorScript.texto_tasa(recurso.tasa_neta_promedio)
		]
		var color_btn: Color = TemaHUD.INVALIDO if recurso.tasa_neta_promedio < 0.0 else TemaHUD.TEXTO
		btn.add_theme_color_override("font_color", color_btn)

		if _contenedores_hijos.has(clave):
			_contenedores_hijos[clave].visible = esta_abierto

	# 3. Subcategorías de comida
	if _contenedores_hijos.get("comida", null) != null and _contenedores_hijos["comida"].visible and "sub_almacen_comida" in Ciudad:
		var rec_comida = Ciudad.almacen.get("comida", null)
		var tasa_neg: bool = rec_comida != null and rec_comida.tasa_neta_promedio < 0.0
		for sub_cat in _etiquetas_sub_comida:
			var cant_sc: float = Ciudad.sub_almacen_comida.get(sub_cat, 0.0)
			var nom_sub: String = Strings.NOMBRES_SUB_COMIDA.get(sub_cat, sub_cat.capitalize())
			var et_sub: Label = _etiquetas_sub_comida[sub_cat]
			et_sub.text = "%s: %.0f" % [nom_sub, cant_sc]
			if tasa_neg:
				et_sub.add_theme_color_override("font_color", TemaHUD.INVALIDO)
			elif cant_sc <= 0.0:
				et_sub.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
			else:
				et_sub.add_theme_color_override("font_color", TemaHUD.TEXTO)

	# 4. Hijos refinados
	for hijo_clave in _etiquetas_hijos:
		if not Ciudad.almacen.has(hijo_clave):
			continue
		var rec_hijo = Ciudad.almacen[hijo_clave]
		var nom_hijo: String = HUDScript.NOMBRES_RECURSO.get(hijo_clave, rec_hijo.nombre)
		var et_hijo: Label = _etiquetas_hijos[hijo_clave]
		et_hijo.text = "%s: %.0f/%.0f %s" % [
			nom_hijo,
			rec_hijo.cantidad,
			rec_hijo.limite,
			BarraSuperiorScript.texto_tasa(rec_hijo.tasa_neta_promedio)
		]
		et_hijo.add_theme_color_override("font_color", TemaHUD.INVALIDO if rec_hijo.tasa_neta_promedio < 0.0 else TemaHUD.TEXTO)


func _fila_titulo(texto: String) -> Control:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 6)
	var cont_tit := HBoxContainer.new()
	cont_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := IconosHUD.crear_rect("almacen", 20)
	cont_tit.add_child(ic)
	var titulo := TemaHUD.etiqueta(texto.to_upper())
	titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	cont_tit.add_child(titulo)
	fila.add_child(cont_tit)

	_btn_toggle_todo.custom_minimum_size = Vector2(104, 24)
	_btn_toggle_todo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_toggle_todo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	TemaHUD.estilizar_boton(_btn_toggle_todo)
	_btn_toggle_todo.add_theme_font_size_override("font_size", 11)
	_btn_toggle_todo.pressed.connect(alternar_expandir_todo)
	_actualizar_boton_toggle_todo()
	fila.add_child(_btn_toggle_todo)

	var cerrar_boton := Button.new()
	cerrar_boton.text = ""
	cerrar_boton.icon = IconosHUD.icono("cruz")
	cerrar_boton.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(cerrar_boton)
	cerrar_boton.pressed.connect(cerrar)
	fila.add_child(cerrar_boton)
	return fila
