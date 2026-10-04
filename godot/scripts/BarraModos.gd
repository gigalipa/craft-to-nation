extends HBoxContainer

## Barras de modos de la cenital, en la esquina inferior izquierda: la barra
## principal (Ver/Construir/Zonificar/Demoler), y a su derecha, según el modo:
## las categorías de Construir (Residencial/Periférico/Industrial/
## Investigación/Vías), los edificios de la categoría elegida, o las zonas
## (Zona Residencial/Zona Industrial/Borrar). Navegación puramente posicional
## (Esc + números, ver docs/superpowers/specs/2026-09-30-hud-menu-numerico-
## design.md): cada tecla numérica vale para el nivel donde está el jugador,
## nunca una letra fija. Solo pide cambios (señales): el modo real lo decide
## CamaraCenital, que lo devuelve con HUD.set_modo(). Tras cada clic la barra
## se resincroniza con el modo real, así un modo que no llega a activarse no
## queda marcado.

signal modo_pedido(modo: String)
signal categoria_pedida(categoria: String)
signal construccion_pedida(tipo: String)
signal zona_pedida(tipo: String)

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const MiniaturaRendererScript = preload("res://scripts/MiniaturaRenderer.gd")
const BlueprintValidatorScript = preload("res://scripts/BlueprintValidator.gd")
const PlantillasPuestoScript = preload("res://scripts/PlantillasPuesto.gd")

## Tipos sin malla real en BlockLibrary (a propósito: otro sistema los
## dibuja — ver VoxelWorld/Puertas.gd/TranslucidosRenderer.gd). La miniatura
## de una construcción completa los salta: es una vista general del
## edificio, no necesita reproducir cada mueble.
const TIPOS_SIN_MALLA_MINIATURA := ["vidrio", "puerta_inferior", "puerta_superior"]

## Esquina superior-derecha-FRONTAL (el frente/puerta de plantillas y
## blueprints mira a -Z, ver PlantillasPuesto.gd) — no la diagonal simétrica
## que usa Hotbar para bloques sueltos sin frente definido.
const DIRECCION_CAMARA_MINIATURA := Vector3(1, 1, -1)
const TAMANO_MINIATURA := 40.0
const ZONA_RESIDENCIAL := "residencial_investigacion"

## [id, nombre, tecla, ícono opcional (null: sin arte todavía)]
const MODOS := [
	["ver", "Ver", "Esc", null],
	["construir", "Construir", "1", null],
	["zonificar", "Zonificar", "2", null],
	["demoler", "Demoler", "3", null],
]

## Categorías del menú Construir (GDD: Núcleo A = Residencial/Investigación,
## Núcleo B = Industrial; Periférico son los puestos de recolección fuera de
## la ciudad). Industrial tiene la siderúrgica e Investigación la escuela técnica
## (ver CONSTRUCCIONES_POR_CATEGORIA).
const CATEGORIAS := [
	["residencial", "Residencial", "1"],
	["periferico", "Periférico", "2"],
	["industrial", "Industrial", "3"],
	["investigacion", "Investigación", "4"],
	["vias", "Vías", "5"],
]

## categoría -> [tipo, nombre, tecla] de sus edificios, en el orden en que
## aparecen los botones (y en el que CamaraCenital._manejar_tecla_construir()
## indexa las teclas numéricas — deben coincidir).
const CONSTRUCCIONES_POR_CATEGORIA := {
	"residencial": [
		["residencial", "Residencial", "1"],
		["residencial_1", "Residencial 2", "2"],
		["residencial_2", "Residencial 3", "3"],
		["residencial_3", "Residencial 4", "4"],
		["residencial_4", "Residencial 5", "5"],
	],
	"periferico": [
		["caza_recoleccion", "Caza", "1"],
		["maderero", "Madera", "2"],
		["mina", "Mina", "3"],
		["pesca_frutos_mar", "Pesca", "4"],
	],
	"industrial": [
		["siderurgica", "Siderúrgica", "1"],
		["refineria_tierras_raras", "Tierras raras", "2"],
		["aserradero", "Aserradero", "3"],
		["carbonera", "Carbonera", "4"],
		["refineria_petrolera", "Refinería petrolera", "5"],
		["productor_combustible", "Productor combustible", "6"],
		["central_termoelectrica", "Central termoeléctrica", "7"],
	],
	"investigacion": [
		["escuela_tecnica", "Escuela técnica", "1"],
		["escuela_especialistas", "Escuela de especialistas", "2"],
		["universidad", "Universidad", "3"],
	],
	"vias": [
		["vias", "Trazar vía", "1"],
	],
}

## Tipos con miniatura 3D real (mina/caza/madera/pesca + el blueprint
## residencial); "vias" no tiene malla que previsualizar, es un botón de texto.
const TIPOS_CON_MINIATURA := ["residencial", "mina", "caza_recoleccion", "maderero", "pesca_frutos_mar", "siderurgica", "refineria_tierras_raras", "aserradero", "carbonera", "refineria_petrolera", "productor_combustible", "central_termoelectrica", "escuela_tecnica", "escuela_especialistas", "universidad"]

## [tipo de zona, nombre, tecla, ícono opcional (null: sin arte todavía)]
var ZONAS := [
	[Zonificacion.ZONAS_PINTABLES[0], "Zona Residencial", "1", null],
	[Zonificacion.ZONAS_PINTABLES[1], "Zona Industrial", "2", null],
	[Zonificacion.MARCADOR_BORRAR, "Borrar", "3", null],
]

var _panel_principal := PanelContainer.new()
var _panel_categorias := PanelContainer.new()
var _panel_zonas := PanelContainer.new()
var _botones := {}  # id de modo -> Button
var _botones_categoria := {}  # id de categoría -> Button
var _botones_construccion := {}  # tipo de edificio -> Button
var _botones_zona := {}  # tipo de zona -> Button
var _paneles_construccion := {}  # id de categoría -> PanelContainer (uno visible a la vez)
var _miniaturas_construccion := {}  # tipo con miniatura -> TextureRect
var _miniaturas_residencial_extra := {}  # residencial_1..4 -> TextureRect
## SubViewport vivo detrás de cada miniatura actual — se libera (queue_free())
## antes de crear el siguiente en cada re-render, para no acumular uno por
## cada rotación/refresco (reporte de revisión, 2026-09-30).
var _viewports_construccion := {}  # tipo con miniatura -> SubViewport
var _viewports_residenciales_extra := {}  # residencial_1..4 -> SubViewport
var _biblioteca_construccion: MeshLibrary
var _giros_menu := 0
var _modo := ""
var _categoria := ""  # categoría activa dentro de Construir ("" = lista de categorías)
var _puesto := ""  # tipo de edificio activo (Construir) o tipo de zona activo (Zonificar)


func _ready() -> void:
	# Anclas y offsets explícitos (set_anchors_preset() en _ready() no ubicaba la barra).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 8.0
	offset_bottom = -8.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 6)

	for panel in [_panel_principal, _panel_categorias, _panel_zonas]:
		TemaHUD.aplicar_panel(panel)
		panel.size_flags_vertical = Control.SIZE_SHRINK_END  # ambas alineadas abajo

	add_child(_panel_principal)
	add_child(_panel_categorias)
	var columna := _nueva_columna(_panel_principal)
	for modo in MODOS:
		var id: String = modo[0]
		var boton := _crear_boton(modo[1], Vector2(88, 56), modo[3], modo[2])
		boton.pressed.connect(func() -> void:
			modo_pedido.emit(id)
			_refrescar()
		)
		columna.add_child(boton)
		_botones[id] = boton

	var columna_categorias := _nueva_columna(_panel_categorias)
	for categoria in CATEGORIAS:
		var id: String = categoria[0]
		var boton := _crear_boton(categoria[1], Vector2(88, 56), null, categoria[2])
		boton.pressed.connect(func() -> void:
			categoria_pedida.emit(id)
			_refrescar()
		)
		columna_categorias.add_child(boton)
		_botones_categoria[id] = boton

	for categoria in CATEGORIAS:
		var id: String = categoria[0]
		var panel := PanelContainer.new()
		TemaHUD.aplicar_panel(panel)
		panel.size_flags_vertical = Control.SIZE_SHRINK_END
		panel.visible = false
		add_child(panel)
		_paneles_construccion[id] = panel
		var edificios: Array = CONSTRUCCIONES_POR_CATEGORIA[id]
		if edificios.is_empty():
			var columna_vacia := _nueva_columna(panel)
			columna_vacia.add_child(TemaHUD.etiqueta("Próximamente"))
			continue
		var columna_edificios := _nueva_columna(panel)
		for edificio in edificios:
			var tipo: String = edificio[0]
			var boton: Button = _crear_boton_construccion(tipo, edificio[1], edificio[2])
			boton.pressed.connect(func() -> void:
				construccion_pedida.emit(tipo)
				_refrescar()
			)
			columna_edificios.add_child(boton)
			_botones_construccion[tipo] = boton

	add_child(_panel_zonas)
	var columna_zonas := _nueva_columna(_panel_zonas)
	for zona in ZONAS:
		var tipo: String = zona[0]
		var boton := _crear_boton(zona[1], Vector2(88, 40), zona[3], zona[2])
		boton.pressed.connect(func() -> void:
			zona_pedida.emit(tipo)
			_refrescar()
		)
		columna_zonas.add_child(boton)
		_botones_zona[tipo] = boton
	_refrescar()


func _nueva_columna(panel: PanelContainer) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(columna)
	return columna


## "icono" es opcional (null en todos los llamadores hoy — no hay arte
## todavía, ver docs/superpowers/specs/2026-09-30-previsualizacion-
## construcciones-cenital-design.md, Sección 9): sin él, el botón se ve
## exactamente igual que siempre (texto directo en el Button). Con él,
## antepone un TextureRect de 24x24 y mueve el texto a un Label hijo — deja
## el mecanismo listo para cuando exista el ícono real de cada modo/zona.
func _crear_boton(texto: String, tamano: Vector2, icono: Texture2D = null, tecla: String = "") -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.custom_minimum_size = tamano
	TemaHUD.estilizar_boton(boton)
	if icono == null:
		boton.text = texto
		_poner_tecla(boton, tecla, boton.get_theme_font("font").get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, boton.get_theme_font_size("font_size")).x)
		return boton

	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 2)

	var imagen := TextureRect.new()
	imagen.custom_minimum_size = Vector2(24, 24)
	imagen.texture = icono
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(imagen)

	var etiqueta := TemaHUD.etiqueta(texto)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(etiqueta)

	boton.add_child(columna)
	_poner_tecla(boton, tecla, etiqueta.get_minimum_size().x)
	return boton


## Acceso directo de un botón: texto dorado de 12 px en la esquina inferior izquierda, por dentro del
## marco, como en la hotbar de 1ª persona (ver Hotbar.gd). Sin "tecla" no hace nada. El botón se ensancha
## si hace falta para que la tecla (a cada lado, para no descentrar el nombre) no pise "ancho_texto".
## Un Control simple (no un Container) respeta las anclas de sus hijos, y MOUSE_FILTER_IGNORE deja
## pasar el clic al Button.
func _poner_tecla(boton: Button, tecla: String, ancho_texto: float) -> void:
	if tecla == "":
		return
	var esquinas := Control.new()
	esquinas.set_anchors_preset(Control.PRESET_FULL_RECT)
	esquinas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(esquinas)
	var etiqueta_tecla := TemaHUD.etiqueta(tecla)
	etiqueta_tecla.add_theme_font_size_override("font_size", 12)
	etiqueta_tecla.add_theme_color_override("font_color", TemaHUD.DORADO)
	esquinas.add_child(etiqueta_tecla)
	TemaHUD.poner_en_esquina_inferior(etiqueta_tecla)  # a MARGEN_X / MARGEN_Y del marco
	var margen: float = etiqueta_tecla.get_minimum_size().x + TemaHUD.MARGEN_X + 4.0
	boton.custom_minimum_size.x = maxf(boton.custom_minimum_size.x, ancho_texto + 2.0 * margen)


## Botón del submenú Construir: miniatura 3D (espacio fijo TAMANO_MINIATURA x
## TAMANO_MINIATURA, ver _actualizar_miniaturas(); solo los tipos de
## TIPOS_CON_MINIATURA) arriba y el nombre abajo; el ancho se adapta al nombre.
## La tecla de acceso directo va en la esquina inferior izquierda, en dorado,
## como en la hotbar de 1ª persona (ver Hotbar.gd). Los hijos llevan
## MOUSE_FILTER_IGNORE para que el clic siga llegando al Button de abajo.
func _crear_boton_construccion(tipo: String, nombre: String, tecla: String) -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	TemaHUD.estilizar_boton(boton)

	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 2)

	if TIPOS_CON_MINIATURA.has(tipo) or tipo.begins_with("residencial_"):
		var miniatura := TextureRect.new()
		miniatura.custom_minimum_size = Vector2(TAMANO_MINIATURA, TAMANO_MINIATURA)
		miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		miniatura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		columna.add_child(miniatura)
		if tipo.begins_with("residencial_"):
			_miniaturas_residencial_extra[tipo] = miniatura
		else:
			_miniaturas_construccion[tipo] = miniatura

	var etiqueta := TemaHUD.etiqueta(nombre)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(etiqueta)
	boton.add_child(columna)

	boton.custom_minimum_size = Vector2(88, 64)
	_poner_tecla(boton, tecla, etiqueta.get_minimum_size().x)
	return boton


## Cambia el giro compartido de las miniaturas (0-3, normalizado con posmod)
## y las vuelve a renderizar. La llama CamaraCenital cada vez que Ctrl+rueda
## rota un puesto o un blueprint en colocación — ver HUD.set_giros_construccion().
func set_giros(giros: int) -> void:
	_giros_menu = posmod(giros, 4)
	_actualizar_miniaturas()


func _actualizar_miniaturas() -> void:
	for tipo in _miniaturas_construccion:
		(_miniaturas_construccion[tipo] as TextureRect).texture = _renderizar_miniatura(tipo)
	for tipo in _miniaturas_residencial_extra:
		var idx: int = tipo.trim_prefix("residencial_").to_int()
		if idx < Blueprints.cantidad_residenciales():
			(_miniaturas_residencial_extra[tipo] as TextureRect).texture = _renderizar_miniatura_extra(tipo, idx)
		else:
			(_miniaturas_residencial_extra[tipo] as TextureRect).texture = null


func _renderizar_miniatura_extra(tipo: String, idx: int) -> Texture2D:
	if _viewports_residenciales_extra.has(tipo):
		(_viewports_residenciales_extra[tipo] as SubViewport).queue_free()
		_viewports_residenciales_extra.erase(tipo)

	var celdas: Dictionary = _celdas_residencial_giradas(idx)
	if celdas.is_empty():
		return null
	if _biblioteca_construccion == null:
		_biblioteca_construccion = MiniaturaRendererScript.cargar_biblioteca()
	var piezas: Array = []
	for celda in celdas:
		var tipo_bloque: String = celdas[celda]
		if TIPOS_SIN_MALLA_MINIATURA.has(tipo_bloque):
			continue
		var malla: Mesh = MiniaturaRendererScript.malla_de_item(_biblioteca_construccion, tipo_bloque)
		if malla != null:
			piezas.append([malla, Vector3(celda.x, celda.y, celda.z), null])
	if piezas.is_empty():
		return null
	var viewport: SubViewport = MiniaturaRendererScript.renderizar_viewport(piezas, DIRECCION_CAMARA_MINIATURA, self)
	_viewports_residenciales_extra[tipo] = viewport
	return viewport.get_texture()


## Libera el SubViewport anterior de "tipo" (si había uno) antes de armar el
## siguiente, para que _viewports_construccion nunca acumule más de uno por
## tipo sin importar cuántas veces se llame (rotaciones, refrescos).
func _renderizar_miniatura(tipo: String) -> Texture2D:
	if _viewports_construccion.has(tipo):
		(_viewports_construccion[tipo] as SubViewport).queue_free()
		_viewports_construccion.erase(tipo)

	var celdas: Dictionary = _celdas_residencial_giradas() if tipo == "residencial" else PlantillasPuestoScript.celdas(tipo, _giros_menu)
	if celdas.is_empty():
		return null
	if _biblioteca_construccion == null:
		_biblioteca_construccion = MiniaturaRendererScript.cargar_biblioteca()
	var piezas: Array = []
	for celda in celdas:
		var tipo_bloque: String = celdas[celda]
		if TIPOS_SIN_MALLA_MINIATURA.has(tipo_bloque):
			continue
		var malla: Mesh = MiniaturaRendererScript.malla_de_item(_biblioteca_construccion, tipo_bloque)
		if malla != null:
			piezas.append([malla, Vector3(celda.x, celda.y, celda.z), null])
	if piezas.is_empty():
		return null
	var viewport: SubViewport = MiniaturaRendererScript.renderizar_viewport(piezas, DIRECCION_CAMARA_MINIATURA, self)
	_viewports_construccion[tipo] = viewport
	return viewport.get_texture()


## Celdas del blueprint residencial declarado, giradas _giros_menu cuartos de
## vuelta con la misma fórmula que CamaraCenital._rotar_blueprint() (vía
## BlueprintValidator.rotar_celdas_3d()) — sin mutar el blueprint guardado en
## Blueprints, solo una vista para la miniatura. {} si no hay ninguno
## declarado todavía.
func _celdas_residencial_giradas(indice: int = 0) -> Dictionary:
	var blueprint: Dictionary = Blueprints.obtener_residencial(indice)
	if blueprint.is_empty():
		blueprint = Blueprints.obtener(ZONA_RESIDENCIAL, indice)
	if blueprint.is_empty():
		return {}
	var celdas: Dictionary = blueprint["celdas_3d"]
	var ancho: int = blueprint["ancho"]
	var profundidad: int = blueprint["profundidad"]
	for _i in range(_giros_menu):
		celdas = BlueprintValidatorScript.rotar_celdas_3d(celdas, profundidad)
		var previo := ancho
		ancho = profundidad
		profundidad = previo
	return celdas


## "modo" es el id de MODOS ("" = Ver); "sub" es el tipo de edificio activo
## (Construir) o el tipo de zona activo (Zonificar); "categoria" solo aplica a
## Construir: la categoría cuyo panel de edificios está abierto ("" = todavía
## en la lista de categorías).
func set_modo(modo: String, sub: String = "", categoria: String = "") -> void:
	_modo = modo
	_puesto = sub
	_categoria = categoria
	if is_inside_tree():
		_refrescar()


func _cambiar_texto_boton_construccion(btn: Button, nuevo_texto: String) -> void:
	for hijo in btn.get_children():
		if hijo is VBoxContainer:
			for nieto in hijo.get_children():
				if nieto is Label:
					nieto.text = nuevo_texto
					return


func _refrescar() -> void:
	var activo := _modo if _modo != "" else "ver"
	for id in _botones:
		_botones[id].set_pressed_no_signal(id == activo)

	_panel_categorias.visible = _modo == "construir"
	for id in _botones_categoria:
		_botones_categoria[id].set_pressed_no_signal(id == _categoria)
	for id in _paneles_construccion:
		_paneles_construccion[id].visible = _modo == "construir" and _categoria == id
	for tipo in _botones_construccion:
		_botones_construccion[tipo].set_pressed_no_signal(_modo == "construir" and tipo == _puesto)

	var cant_res := Blueprints.cantidad_residenciales()
	for i in range(5):
		var id_res := "residencial" if i == 0 else "residencial_%d" % i
		if _botones_construccion.has(id_res):
			var btn: Button = _botones_construccion[id_res]
			if cant_res == 0:
				if i == 0:
					btn.visible = true
					_cambiar_texto_boton_construccion(btn, "Residencial")
					btn.modulate = Color(1.0, 1.0, 1.0, 0.4)
				else:
					btn.visible = false
			else:
				if i < cant_res:
					btn.visible = true
					var bp: Dictionary = Blueprints.obtener_residencial(i)
					var nom: String = bp.get("nombre", "Residencial" if i == 0 else "Residencial %d" % (i + 1))
					_cambiar_texto_boton_construccion(btn, nom)
					btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
				else:
					btn.visible = false

	if _modo == "construir" and (_categoria == "residencial" or _categoria == "periferico" or _categoria == "investigacion"):
		_actualizar_miniaturas()

	_panel_zonas.visible = _modo == "zonificar"
	for tipo in _botones_zona:
		_botones_zona[tipo].set_pressed_no_signal(tipo == _puesto)


func boton_activo() -> String:
	return _modo if _modo != "" else "ver"


func construccion_visible() -> bool:
	return _modo == "construir"


func categoria_activa() -> String:
	return _categoria if _modo == "construir" else ""


func construccion_activa() -> String:
	return _puesto if _modo == "construir" else ""


func zonificar_visible() -> bool:
	return _modo == "zonificar"


func zona_activa() -> String:
	return _puesto if _modo == "zonificar" else ""
