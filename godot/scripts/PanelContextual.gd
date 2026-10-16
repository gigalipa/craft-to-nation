extends PanelContainer

## Panel inferior central (ambas vistas): el ítem activo con su costo, las
## acciones disponibles y, si aplica, si la ubicación es válida. Quien manda
## (CamaraCenital, Player) lo empuja vía HUD.mostrar_contexto(); este panel
## no lee ningún estado del juego.

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const HotbarScript = preload("res://scripts/Hotbar.gd")
const ICONO_CLIC_DERECHO := "res://assets/icons/click_der.svg"
const ICONO_CLIC_IZQUIERDO := "res://assets/icons/click_izq.svg"
const ICONO_SCROLL := "res://assets/icons/scroll.svg"
const ICONO_MOUSE_MOVE := "res://assets/icons/mouse_move.svg"
const ANCHO_PANEL := 350.0
const ANCHO_TEXTO := 330.0

var titulo := TemaHUD.etiqueta()
## Índice del bloque en la hotbar ("1"-"9"), en dorado junto al título. Solo
## lo usa mostrar_bloque_temporal(); mostrar()/mostrar_temporal() lo ocultan.
var numero := TemaHUD.etiqueta()
## Miniatura del bloque (ver MiniaturaRenderer.renderizar()). Solo la usa
## mostrar_bloque_temporal().
var icono := TextureRect.new()
var costo := TemaHUD.etiqueta()
var _rich_costo := RichTextLabel.new()
## Tipo, uso ideal y método de obtención del bloque (Hotbar.DESCRIPCION).
## Solo la usa mostrar_bloque_temporal().
var descripcion := TemaHUD.etiqueta()
var acciones := RichTextLabel.new()
## "Disponible: N" del bloque activo. Solo la usa mostrar_bloque_temporal().
var disponible := TemaHUD.etiqueta()
var validez := TemaHUD.etiqueta()
var extra := TemaHUD.etiqueta()
var _rich_extra := RichTextLabel.new()

## Se guarda aparte porque HUD.set_vista() puede llamarse antes de _ready().
var _margen_inferior := 12.0

## true mientras el panel está en modo temporal (aparece con fade y sube desde la
## barra de abajo, y se desvanece solo).
var temporal := false
var _tween: Tween
## Identifica el último mostrar_temporal(): un temporizador viejo no oculta un panel nuevo.
var _version := 0

const DESLIZAMIENTO := 24.0
const DURACION_ENTRADA := 0.2
const DURACION_SALIDA := 0.3


## "bloques_dic" (opcional, material -> cantidad de bloques reales de pared/
## estructura, ver NiveladorTerreno.contar_bloques()) suma "(N bloques)" al
## material que tenga conteo — mismo motivo que HUD.texto_materiales().
static func texto_costo(costo_dic: Dictionary, bloques_dic: Dictionary = {}) -> String:
	var partes: Array = []
	for tipo in costo_dic:
		if bloques_dic.has(tipo):
			partes.append("%d %s (%d bloques)" % [costo_dic[tipo], tipo, bloques_dic[tipo]])
		else:
			partes.append("%d %s" % [costo_dic[tipo], tipo])
	return " · ".join(partes)


## Formatea teclas en estilo visual "keycap" dorado/crema
static func _formatear_keycap(tecla: String) -> String:
	return "[color=#FFE082][b][%s][/b][/color]" % tecla


## Texto BBCode de "lista_acciones" para el RichTextLabel "acciones": cambia
## las marcas de texto por los íconos del ratón y formato keycap.
static func texto_acciones(lista_acciones: Array) -> String:
	var partes: Array = []
	for accion in lista_acciones:
		var lineas: Array = str(accion).split("\n")
		for linea in lineas:
			var parte: String = linea.strip_edges()
			if parte.is_empty():
				continue
			parte = parte.replace("(clic der.)", "[img=12x17]%s[/img]" % ICONO_CLIC_DERECHO)
			parte = parte.replace("(click der.)", "[img=12x17]%s[/img]" % ICONO_CLIC_DERECHO)
			parte = parte.replace("(clic derecho)", "[img=12x17]%s[/img]" % ICONO_CLIC_DERECHO)
			parte = parte.replace("(click derecho)", "[img=12x17]%s[/img]" % ICONO_CLIC_DERECHO)

			parte = parte.replace("(doble clic izq.)", "[img=12x17]%s[/img]x2" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(doble click izq.)", "[img=12x17]%s[/img]x2" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(doble clic der.)", "[img=12x17]%s[/img]x2" % ICONO_CLIC_DERECHO)
			parte = parte.replace("(doble click der.)", "[img=12x17]%s[/img]x2" % ICONO_CLIC_DERECHO)
			parte = parte.replace("(doble clic)", "[img=12x17]%s[/img]x2" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(doble click)", "[img=12x17]%s[/img]x2" % ICONO_CLIC_IZQUIERDO)

			parte = parte.replace("(clic izq.)", "[img=12x17]%s[/img]" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(click izq.)", "[img=12x17]%s[/img]" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(clic izquierdo)", "[img=12x17]%s[/img]" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(click izquierdo)", "[img=12x17]%s[/img]" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(clic)", "[img=12x17]%s[/img]" % ICONO_CLIC_IZQUIERDO)
			parte = parte.replace("(click)", "[img=12x17]%s[/img]" % ICONO_CLIC_IZQUIERDO)

			parte = parte.replace("(mover)", "[img=16x16]%s[/img]" % ICONO_MOUSE_MOVE)

			parte = parte.replace("[Ctrl+rueda]", "%s [img=12x17]%s[/img]" % [_formatear_keycap("Ctrl"), ICONO_SCROLL])
			parte = parte.replace("[Ctrl+scroll]", "%s [img=12x17]%s[/img]" % [_formatear_keycap("Ctrl"), ICONO_SCROLL])
			parte = parte.replace("(Ctrl+rueda)", "%s [img=12x17]%s[/img]" % [_formatear_keycap("Ctrl"), ICONO_SCROLL])
			parte = parte.replace("(Ctrl+scroll)", "%s [img=12x17]%s[/img]" % [_formatear_keycap("Ctrl"), ICONO_SCROLL])
			parte = parte.replace("Ctrl+rueda", "%s [img=12x17]%s[/img]" % [_formatear_keycap("Ctrl"), ICONO_SCROLL])
			parte = parte.replace("Ctrl+scroll", "%s [img=12x17]%s[/img]" % [_formatear_keycap("Ctrl"), ICONO_SCROLL])
			parte = parte.replace("(scroll)", "[img=12x17]%s[/img]" % ICONO_SCROLL)
			parte = parte.replace("(rueda)", "[img=12x17]%s[/img]" % ICONO_SCROLL)

			# Estilo keycap para teclas de control
			for k in ["Esc", "E", "G", "V", "B", "Z", "X", "Ctrl", "Shift"]:
				parte = parte.replace("[%s]" % k, _formatear_keycap(k))

			partes.append(parte)
	return "\n".join(partes)


## Formatea el texto de costo con íconos vectoriales SVG inline
static func _formatear_con_iconos_costo(texto: String) -> String:
	if texto.is_empty():
		return ""
	var partes := texto.split(" · ")
	var formated_partes: Array[String] = []
	var recursos: Array[String] = [
		"bloques_piedra", "mineral_refinado", "tierras_raras",
		"piedra", "madera", "tierra", "hierro", "cobre", "carbon",
		"acero", "tablas", "agua", "crudo", "combustible", "comida"
	]
	for parte in partes:
		var p: String = parte
		for rec: String in recursos:
			if p.contains(rec):
				var ic := IconosHUD.bbcode(rec, 16)
				if ic != "":
					p = "%s %s" % [ic, p]
				break
		formated_partes.append(p)
	return " · ".join(formated_partes)


## Formatea la línea extra (incluyendo materiales de blueprints, distancias y camas/baúles) con íconos vectoriales
static func _formatear_con_iconos_extra(texto: String) -> String:
	if texto.is_empty():
		return ""
	var lineas := texto.split("\n")
	var resultado: Array[String] = []
	var recursos: Array[String] = [
		"bloques_piedra", "mineral_refinado", "tierras_raras",
		"piedra", "madera", "tierra", "hierro", "cobre", "carbon",
		"acero", "tablas", "agua", "crudo", "combustible", "comida"
	]
	for linea in lineas:
		var l: String = linea
		if l.contains("Camas:") or l.contains("Baúles:"):
			l = l.replace("Camas:", "%s Camas:" % IconosHUD.bbcode("cama", 16))
			l = l.replace("Baúles:", "%s Baúles:" % IconosHUD.bbcode("baul", 16))
		elif l.begins_with("Distancia al núcleo:"):
			l = "%s %s" % [IconosHUD.bbcode("brujula", 16), l]
		elif l.contains("Personal máximo:"):
			l = l.replace("Personal máximo:", "%s Personal máximo:" % IconosHUD.bbcode("ciudadano", 16))
			l = l.replace("Almacenamiento:", "%s Almacenamiento:" % IconosHUD.bbcode("almacen", 16))
		elif l.contains("Nivel ") and l.contains(": "):
			var partes_nivel := l.split(": ", true, 1)
			var sub: String = partes_nivel[1]
			for rec: String in recursos:
				if sub.contains(rec):
					var ic := IconosHUD.bbcode(rec, 16)
					if ic != "" and not sub.contains(ic):
						sub = sub.replace(rec, "%s %s" % [ic, rec])
			l = partes_nivel[0] + ": " + sub
		else:
			for rec: String in recursos:
				var patron: String = " " + rec
				if l.contains(patron) or l.strip_edges().ends_with(rec) or l.contains(rec + "/h"):
					var ic := IconosHUD.bbcode(rec, 16)
					if ic != "" and not l.contains(ic):
						if l.strip_edges().begins_with("+ "):
							var partes := l.split("+ ", true, 1)
							l = partes[0] + "+ %s %s" % [ic, partes[1]]
						else:
							var indent := ""
							var trimmed := l
							if l.begins_with("  "):
								indent = "  "
								trimmed = l.substr(2)
							elif l.begins_with(" "):
								indent = " "
								trimmed = l.substr(1)
							l = "%s%s %s" % [indent, ic, trimmed]
					break
		resultado.append(l)
	return "\n".join(resultado)


const DORADO_TEXTO := Color(1.0, 0.85, 0.4)


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	visible = false
	custom_minimum_size.x = ANCHO_PANEL
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -_margen_inferior

	titulo.add_theme_color_override("font_color", DORADO_TEXTO)
	numero.add_theme_color_override("font_color", DORADO_TEXTO)
	numero.visible = false

	icono.custom_minimum_size = Vector2(HotbarScript.TAMANO_ICONO, HotbarScript.TAMANO_ICONO)
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.visible = false

	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descripcion.custom_minimum_size.x = ANCHO_TEXTO
	descripcion.visible = false

	costo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	costo.custom_minimum_size.x = ANCHO_TEXTO
	costo.visible = false

	_rich_costo.bbcode_enabled = true
	_rich_costo.fit_content = true
	_rich_costo.scroll_active = false
	_rich_costo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich_costo.add_theme_color_override("default_color", TemaHUD.TEXTO)
	_rich_costo.custom_minimum_size.x = ANCHO_TEXTO
	_rich_costo.visible = false

	# RichTextLabel (no Label): "(clic der.)"/"(clic izq.)" se reemplazan por
	# el ícono del ratón (ver texto_acciones()) en vez de quedar como texto
	# plano. Ancho explícito: sin él, fit_content mide su alto ANTES de que
	# el HBoxContainer le asigne un ancho real (ancho 0 → todo el texto
	# envuelto palabra por palabra), inflando el panel entero — bug real,
	# reportado 2026-09-30 en la ficha de puesto de la vista cenital, que ni
	# siquiera usa el ícono del clic.
	acciones.bbcode_enabled = true
	acciones.fit_content = true
	acciones.scroll_active = false
	acciones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acciones.add_theme_color_override("default_color", TemaHUD.TEXTO)
	acciones.custom_minimum_size.x = ANCHO_TEXTO

	disponible.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	disponible.visible = false

	extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra.custom_minimum_size.x = ANCHO_TEXTO

	_rich_extra.bbcode_enabled = true
	_rich_extra.fit_content = true
	_rich_extra.scroll_active = false
	_rich_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich_extra.add_theme_color_override("default_color", TemaHUD.TEXTO)
	_rich_extra.custom_minimum_size.x = ANCHO_TEXTO
	_rich_extra.visible = false

	validez.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validez.custom_minimum_size = Vector2(ANCHO_TEXTO, 46.0)
	validez.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	validez.max_lines_visible = 3
	validez.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)

	var dummy := Control.new()
	dummy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dummy.custom_minimum_size = Vector2.ZERO
	dummy.size = Vector2.ZERO
	dummy.modulate.a = 0.0
	dummy.clip_contents = true
	dummy.add_child(costo)
	dummy.add_child(extra)
	add_child(dummy)

	var fila_titulo := HBoxContainer.new()
	fila_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_titulo.add_child(titulo)
	var relleno_titulo := Control.new()
	relleno_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relleno_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_titulo.add_child(relleno_titulo)
	fila_titulo.add_child(numero)
	caja.add_child(fila_titulo)

	var fila_cuerpo := HBoxContainer.new()
	fila_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_cuerpo.add_theme_constant_override("separation", 10)
	fila_cuerpo.add_child(icono)
	var columna_texto := VBoxContainer.new()
	columna_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna_texto.add_child(_rich_costo)
	columna_texto.add_child(descripcion)
	columna_texto.add_child(_rich_extra)
	fila_cuerpo.add_child(columna_texto)
	caja.add_child(fila_cuerpo)

	var fila_pie := HBoxContainer.new()
	fila_pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_pie.add_child(acciones)
	var relleno_pie := Control.new()
	relleno_pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relleno_pie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_pie.add_child(relleno_pie)
	fila_pie.add_child(disponible)
	caja.add_child(fila_pie)

	caja.add_child(validez)


## "valido": true/false muestra "Ubicación válida"/"no válida"; cualquier otro
## valor (p. ej. null) oculta esa fila. "motivo_invalido" explica el motivo exacto si es falso.
func mostrar(nombre: String, costo_dic: Dictionary, lista_acciones: Array, valido: Variant = null, texto_extra: String = "", bloques_dic: Dictionary = {}, motivo_invalido: String = "") -> void:
	numero.visible = false
	icono.visible = false
	descripcion.visible = false
	disponible.visible = false
	titulo.text = nombre.to_upper()
	costo.text = texto_costo(costo_dic, bloques_dic)
	costo.visible = not costo_dic.is_empty()
	_rich_costo.text = _formatear_con_iconos_costo(costo.text)
	_rich_costo.visible = costo.visible
	acciones.text = texto_acciones(lista_acciones)
	acciones.visible = not lista_acciones.is_empty()
	validez.visible = typeof(valido) == TYPE_BOOL
	if validez.visible:
		var es_valido: bool = bool(valido)
		if es_valido:
			validez.text = "Ubicación válida"
			validez.add_theme_color_override("font_color", TemaHUD.VALIDO)
		else:
			var desc_motivo := motivo_invalido.replace("Colocación rechazada: ", "").strip_edges()
			var motivo_str := (": " + desc_motivo) if desc_motivo != "" else ""
			validez.text = "Ubicación no válida%s" % motivo_str
			validez.add_theme_color_override("font_color", TemaHUD.INVALIDO)
	extra.text = texto_extra
	extra.visible = texto_extra != ""
	_rich_extra.text = _formatear_con_iconos_extra(texto_extra)
	_rich_extra.visible = extra.visible
	_dejar_fijo()
	visible = true


## Como mostrar(), pero el panel aparece con fade-in deslizándose hacia arriba
## desde la barra de abajo y se desvanece solo tras "segundos". Sin validez ni
## línea extra: el feedback de ubicación lo da el overlay de la cara apuntada.
func mostrar_temporal(nombre: String, costo_dic: Dictionary, lista_acciones: Array, segundos: float = 2.5) -> void:
	mostrar(nombre, costo_dic, lista_acciones)
	temporal = true
	_version += 1
	var mi_version := _version
	modulate.a = 0.0
	offset_bottom = -_margen_inferior + DESLIZAMIENTO
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, DURACION_ENTRADA)
	_tween.tween_property(self, "offset_bottom", -_margen_inferior, DURACION_ENTRADA).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(segundos).timeout.connect(func() -> void:
		if mi_version == _version and temporal:
			_desvanecer()
	)


## Tarjeta completa de un bloque de la hotbar (Player, al seleccionar con
## 1-9/rueda): índice y nombre en dorado, ícono en miniatura (mismo render
## que MiniaturaRenderer.renderizar()), tipo/uso ideal/método de obtención
## (Hotbar.DESCRIPCION) y disponibilidad — mismo panel y animación que
## mostrar_temporal(), pero con el layout de tarjeta en vez de solo texto.
## "disponibilidad" < 0 (sin costo definido, ver Hotbar.cantidad_de())
## oculta esa línea. Los objetos (Hotbar.TIPOS_INTERACTIVOS: puerta, cama,
## baúl) suman una pista de interacción con "E" una vez colocados.
func mostrar_bloque_temporal(indice: int, tipo: String, icono_textura: Texture2D, disponibilidad: int, segundos: float = 2.5) -> void:
	var lista_acciones: Array = ["(clic der.) COLOCAR"]
	if HotbarScript.TIPOS_INTERACTIVOS.has(tipo):
		lista_acciones.append("[E] INTERACTUAR")
	mostrar_temporal(HotbarScript.nombre_de(tipo), {}, lista_acciones, segundos)
	numero.text = str(indice + 1)
	numero.visible = true
	icono.texture = icono_textura
	icono.visible = icono_textura != null
	descripcion.text = "\n".join(HotbarScript.descripcion_de(tipo))
	descripcion.visible = true
	disponible.visible = disponibilidad >= 0
	if disponible.visible:
		disponible.text = "Disponible: %d" % disponibilidad


func _desvanecer() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, DURACION_SALIDA)
	_tween.tween_callback(ocultar)


## Cancela animaciones y temporizador pendientes y deja el panel opaco y en su sitio.
func _dejar_fijo() -> void:
	temporal = false
	_version += 1
	if _tween != null:
		_tween.kill()
		_tween = null
	modulate.a = 1.0
	offset_bottom = -_margen_inferior


func ocultar() -> void:
	_dejar_fijo()
	visible = false


## Actualiza solo el texto de "extra" (p. ej. el resumen de materiales de un
## blueprint activo, que cambia en vivo mientras el jugador se mueve) sin
## tocar el resto del panel ni su animación.
func set_extra(texto: String) -> void:
	extra.text = texto
	extra.visible = texto != ""
	_rich_extra.text = _formatear_con_iconos_extra(texto)
	_rich_extra.visible = extra.visible


## Distancia al borde inferior: en 1ª persona el panel sube para no tapar la hotbar.
func set_margen_inferior(px: float) -> void:
	_margen_inferior = px
	offset_bottom = -px
