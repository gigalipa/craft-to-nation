extends PanelContainer

## Ventana emergente (botón "Ocupaciones" de Población, solo cenital): una fila-botón
## por sitio de trabajo (nombre, trabajadores/cupo, estado). Clic en una fila:
## edificio_pedido(esquina) -> CamaraCenital centra la cámara y abre su panel.
## Mismo comportamiento que VentanaPoblacion (hijo de HUD, arrastrable, ocultar/restaurar).
## Las filas solo se reconstruyen si cambia el conjunto de puestos: un botón recreado
## cada fotograma perdería el clic entre el press y el release (ver VentanaPoblacion).

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")

signal edificio_pedido(esquina: Vector2i)

## A la derecha de Población (16 + 320 de ancho + hueco), sin solaparse con ella ni con Almacén.
const POSICION_INICIAL := Vector2(352, 56)

const CATEGORIAS := ["recoleccion", "industria", "investigacion", "energia"]

const NOMBRES_CATEGORIA := {
	"recoleccion": "Recolección",
	"industria": "Industria",
	"investigacion": "Investigación",
	"energia": "Energía",
}

const CATEGORIA_DE_TIPO := {
	"mina": "recoleccion",
	"caza_recoleccion": "recoleccion",
	"maderero": "recoleccion",
	"pesca_frutos_mar": "recoleccion",

	"siderurgica": "industria",
	"refineria_tierras_raras": "industria",
	"aserradero": "industria",
	"carbonera": "industria",
	"refineria_petrolera": "industria",
	"productor_combustible": "industria",

	"escuela_tecnica": "investigacion",
	"escuela_especialistas": "investigacion",
	"universidad": "investigacion",

	"central_termoelectrica": "energia",
}

var _caja := VBoxContainer.new()
var _caja_raiz := VBoxContainer.new()
var abierta := false
var _arrastrando := false
var _offset_arrastre := Vector2.ZERO
var _firma: Array = []  # esquinas en orden de visualización
var _botones := {}  # esquina -> Button
var _desplegadas := {
	"recoleccion": true,
	"industria": true,
	"investigacion": true,
	"energia": true,
}
var _headers_categoria := {}  # cat -> Button
var _contenedores_categoria := {}  # cat -> Control


static func categoria_de(tipo: String) -> String:
	return CATEGORIA_DE_TIPO.get(tipo, "industria")


static func orden_de(esquina: Vector2i) -> int:
	if not Economia.puestos.has(esquina):
		return 0
	var p: Dictionary = Economia.puestos[esquina]
	if p.has("orden_construccion"):
		return p["orden_construccion"]
	return Economia.puestos.keys().find(esquina)


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
	_caja_raiz.add_child(_fila_titulo("Ocupaciones"))
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


## Oculta sin marcarla como cerrada (HUD.set_vista() al entrar a 1ª persona).
func ocultar_temporalmente() -> void:
	visible = false


func restaurar() -> void:
	visible = abierta


func cerrar() -> void:
	abierta = false
	visible = false


func _actualizar() -> void:
	var por_cat: Dictionary = {
		"recoleccion": [],
		"industria": [],
		"investigacion": [],
		"energia": [],
	}
	for esquina in Economia.puestos:
		var tipo: String = Economia.puestos[esquina].get("tipo", "")
		if Recoleccion.TIPOS_PUESTO_TRABAJO.has(tipo):
			var cat := categoria_de(tipo)
			por_cat[cat].append(esquina)

	var firma_nueva: Array = []
	for cat in CATEGORIAS:
		por_cat[cat].sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return orden_de(a) > orden_de(b)
		)
		firma_nueva.append_array(por_cat[cat])

	if firma_nueva != _firma or (_firma.is_empty() and _caja.get_child_count() == 0):
		_firma = firma_nueva
		_reconstruir(por_cat)

	for esquina in _firma:
		if _botones.has(esquina):
			_botones[esquina].text = _texto_fila(esquina)


func _reconstruir(por_cat: Dictionary) -> void:
	for hijo in _caja.get_children():
		hijo.free()
	_botones.clear()
	_headers_categoria.clear()
	_contenedores_categoria.clear()

	if _firma.is_empty():
		_caja.add_child(TemaHUD.etiqueta("Ninguno todavía"))
		return

	for cat in CATEGORIAS:
		var lista: Array = por_cat[cat]
		if lista.is_empty():
			continue

		var caja_cat := VBoxContainer.new()
		caja_cat.add_theme_constant_override("separation", 3)
		caja_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caja.add_child(caja_cat)

		var header := Button.new()
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		TemaHUD.estilizar_boton(header)
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		caja_cat.add_child(header)
		_headers_categoria[cat] = header

		var margen := MarginContainer.new()
		margen.add_theme_constant_override("margin_left", 12)
		margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja_cat.add_child(margen)
		_contenedores_categoria[cat] = margen

		var caja_filas := VBoxContainer.new()
		caja_filas.add_theme_constant_override("separation", 2)
		caja_filas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margen.add_child(caja_filas)

		var desplegada: bool = _desplegadas.get(cat, true)
		margen.visible = desplegada
		_actualizar_header(header, cat, lista.size(), desplegada)

		header.pressed.connect(func() -> void:
			var nuevo_estado: bool = not _desplegadas.get(cat, true)
			_desplegadas[cat] = nuevo_estado
			margen.visible = nuevo_estado
			_actualizar_header(header, cat, lista.size(), nuevo_estado)
		)

		for esquina: Vector2i in lista:
			var boton := Button.new()
			boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
			TemaHUD.estilizar_boton(boton)
			boton.pressed.connect(func() -> void: edificio_pedido.emit(esquina))
			caja_filas.add_child(boton)
			_botones[esquina] = boton


func _actualizar_header(btn: Button, cat: String, cantidad: int, desplegada: bool) -> void:
	var flecha := "▼" if desplegada else "▶"
	btn.text = "%s %s (%d)" % [flecha, NOMBRES_CATEGORIA.get(cat, cat.capitalize()), cantidad]


func _texto_fila(esquina: Vector2i) -> String:
	var puesto: Dictionary = Economia.puestos[esquina]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	var nombre: String = PanelPuestoScript.NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"])
	return "%s %d/%d%s" % [nombre, t["recolectores"] + t["acarreadores"], puesto["cupo"], estado]


func _fila_titulo(texto: String) -> Control:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titulo := TemaHUD.etiqueta(texto.to_upper())
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cerrar_boton := Button.new()
	cerrar_boton.text = "X"
	cerrar_boton.custom_minimum_size = Vector2(28, 28)
	TemaHUD.estilizar_boton(cerrar_boton)
	cerrar_boton.pressed.connect(cerrar)
	fila.add_child(titulo)
	fila.add_child(cerrar_boton)
	return fila
