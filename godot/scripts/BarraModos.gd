extends HBoxContainer

## Barras de modos de la cenital, en la esquina inferior izquierda: la barra
## principal (un botón por modo) y, a su derecha, una barra de subherramientas
## (Residencial y los 4 puestos con Construir activo; Zona A/B/Borrar con Zonas). Solo pide
## cambios (señales): el modo real lo decide CamaraCenital, que lo devuelve con
## HUD.set_modo(). Tras cada clic la barra se resincroniza con el modo real, así
## un modo que no llega a activarse no queda marcado.

signal modo_pedido(modo: String)
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
	["construir", "Construir", "B", null],
	["zonas", "Zonas", "Z", null],
	["vias", "Vías", "V", null],
]
## Menú de Construir: "residencial" (blueprint) y los tipos de puesto.
const CONSTRUCCIONES := [
	["residencial", "Residencial", "B"],
	["mina", "Mina", "M"],
	["caza_recoleccion", "Caza", "H"],
	["maderero", "Madera", "L"],
	["pesca_frutos_mar", "Pesca", "F"],
]
## [tipo de zona, nombre, tecla, ícono opcional (null: sin arte todavía)]
var ZONAS := [
	[Zonificacion.ZONAS_PINTABLES[0], "Zona A", "1", null],
	[Zonificacion.ZONAS_PINTABLES[1], "Zona B", "2", null],
	[Zonificacion.MARCADOR_BORRAR, "Borrar", "0", null],
]

var _panel_principal := PanelContainer.new()
var _panel_sub := PanelContainer.new()
var _panel_zonas := PanelContainer.new()
var _botones := {}  # id de modo -> Button
var _botones_construccion := {}  # "residencial" o tipo de puesto -> Button
var _botones_zona := {}  # tipo de zona -> Button
var _modo := ""
var _puesto := ""
var _miniaturas_construccion := {}  # "residencial" o tipo de puesto -> TextureRect
var _biblioteca_construccion: MeshLibrary
var _giros_menu := 0


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

	for panel in [_panel_principal, _panel_sub, _panel_zonas]:
		TemaHUD.aplicar_panel(panel)
		panel.size_flags_vertical = Control.SIZE_SHRINK_END  # ambas alineadas abajo
		add_child(panel)
	var columna := _nueva_columna(_panel_principal)
	for modo in MODOS:
		var id: String = modo[0]
		var boton := _crear_boton("%s\n[%s]" % [modo[1], modo[2]], Vector2(88, 56), modo[3])
		boton.pressed.connect(func() -> void:
			modo_pedido.emit(id)
			_refrescar()
		)
		columna.add_child(boton)
		_botones[id] = boton
	var columna_sub := _nueva_columna(_panel_sub)
	for puesto in CONSTRUCCIONES:
		var tipo: String = puesto[0]
		var boton := _crear_boton_construccion(tipo, "%s [%s]" % [puesto[1], puesto[2]])
		boton.pressed.connect(func() -> void:
			construccion_pedida.emit(tipo)
			_refrescar()
		)
		columna_sub.add_child(boton)
		_botones_construccion[tipo] = boton
	var columna_zonas := _nueva_columna(_panel_zonas)
	for zona in ZONAS:
		var tipo: String = zona[0]
		var boton := _crear_boton("%s [%s]" % [zona[1], zona[2]], Vector2(88, 36), zona[3])
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
func _crear_boton(texto: String, tamano: Vector2, icono: Texture2D = null) -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.custom_minimum_size = tamano
	TemaHUD.estilizar_boton(boton)
	if icono == null:
		boton.text = texto
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
	return boton


## Botón del submenú Construir: miniatura 3D (espacio fijo TAMANO_MINIATURA x
## TAMANO_MINIATURA, ver _actualizar_miniaturas()) arriba, texto+tecla abajo
## — a diferencia de _crear_boton(), que solo pone texto. Los hijos llevan
## MOUSE_FILTER_IGNORE para que el clic siga llegando al Button de abajo.
func _crear_boton_construccion(tipo: String, texto: String) -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.custom_minimum_size = Vector2(88, 64)
	TemaHUD.estilizar_boton(boton)

	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 2)

	var miniatura := TextureRect.new()
	miniatura.custom_minimum_size = Vector2(TAMANO_MINIATURA, TAMANO_MINIATURA)
	miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	miniatura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(miniatura)
	_miniaturas_construccion[tipo] = miniatura

	var etiqueta := TemaHUD.etiqueta(texto)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(etiqueta)

	boton.add_child(columna)
	return boton


## Cambia el giro compartido de las 5 miniaturas (0-3, normalizado con
## posmod) y las vuelve a renderizar. La llama CamaraCenital cada vez que
## Ctrl+rueda rota un puesto o un blueprint en colocación — ver
## HUD.set_giros_construccion().
func set_giros(giros: int) -> void:
	_giros_menu = posmod(giros, 4)
	_actualizar_miniaturas()


func _actualizar_miniaturas() -> void:
	for tipo in _miniaturas_construccion:
		(_miniaturas_construccion[tipo] as TextureRect).texture = _miniatura_de(tipo)


func _miniatura_de(tipo: String) -> Texture2D:
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
	return MiniaturaRendererScript.renderizar(piezas, DIRECCION_CAMARA_MINIATURA, self)


## Celdas del blueprint residencial declarado, giradas _giros_menu cuartos de
## vuelta con la misma fórmula que CamaraCenital._rotar_blueprint() (vía
## BlueprintValidator.rotar_celdas_3d()) — sin mutar el blueprint guardado en
## Blueprints, solo una vista para la miniatura. {} si no hay ninguno
## declarado todavía.
func _celdas_residencial_giradas() -> Dictionary:
	var blueprint: Dictionary = Blueprints.obtener(ZONA_RESIDENCIAL)
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


## "modo" es el id de MODOS ("" = Ver); "sub" la subherramienta activa: el tipo
## de construcción con "construir" (residencial o puesto) o el tipo de zona con "zonas".
func set_modo(modo: String, sub: String = "") -> void:
	_modo = modo
	_puesto = sub
	if is_inside_tree():
		_refrescar()


func _refrescar() -> void:
	var activo := _modo if _modo != "" else "ver"
	for id in _botones:
		_botones[id].set_pressed_no_signal(id == activo)
	_panel_sub.visible = _modo == "construir"
	for tipo in _botones_construccion:
		_botones_construccion[tipo].set_pressed_no_signal(tipo == _puesto)
	# Residencial sigue siendo clickeable sin blueprint declarado (el clic
	# dispara la misma notificación de siempre, ver CamaraCenital.
	# _alternar_modo_colocar_blueprint()); solo se atenúa como pista visual.
	_botones_construccion["residencial"].modulate = Color(1.0, 1.0, 1.0, 0.4 if Blueprints.obtener(ZONA_RESIDENCIAL).is_empty() else 1.0)
	_panel_zonas.visible = _modo == "zonas"
	for tipo in _botones_zona:
		_botones_zona[tipo].set_pressed_no_signal(tipo == _puesto)
	if _modo == "construir":
		_actualizar_miniaturas()


func boton_activo() -> String:
	return _modo if _modo != "" else "ver"


func construccion_visible() -> bool:
	return _modo == "construir"


func construccion_activa() -> String:
	return _puesto


func zonas_visibles() -> bool:
	return _modo == "zonas"


func zona_activa() -> String:
	return _puesto if _modo == "zonas" else ""
