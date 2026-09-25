extends PanelContainer

## Panel inferior central (ambas vistas): el ítem activo con su costo, las
## acciones disponibles y, si aplica, si la ubicación es válida. Quien manda
## (CamaraCenital, Player) lo empuja vía HUD.mostrar_contexto(); este panel
## no lee ningún estado del juego.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

var titulo := TemaHUD.etiqueta()
var costo := TemaHUD.etiqueta()
var acciones := TemaHUD.etiqueta()
var validez := TemaHUD.etiqueta()
var extra := TemaHUD.etiqueta()

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


static func texto_costo(costo_dic: Dictionary) -> String:
	var partes: Array = []
	for tipo in costo_dic:
		partes.append("%d %s" % [costo_dic[tipo], tipo])
	return " · ".join(partes)


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	visible = false
	custom_minimum_size.x = 380.0
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -_margen_inferior
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra.custom_minimum_size.x = 360.0
	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)
	for etiqueta in [titulo, costo, extra, acciones, validez]:
		caja.add_child(etiqueta)


## "valido": true/false muestra "Ubicación válida"/"no válida"; cualquier otro
## valor (p. ej. null) oculta esa fila. "texto_extra" vacío oculta su línea.
func mostrar(nombre: String, costo_dic: Dictionary, lista_acciones: Array, valido: Variant = null, texto_extra: String = "") -> void:
	titulo.text = nombre.to_upper()
	costo.text = texto_costo(costo_dic)
	costo.visible = not costo_dic.is_empty()
	acciones.text = "  ·  ".join(lista_acciones)
	acciones.visible = not lista_acciones.is_empty()
	validez.visible = typeof(valido) == TYPE_BOOL
	if validez.visible:
		validez.text = "Ubicación válida" if valido else "Ubicación no válida"
		validez.add_theme_color_override("font_color", TemaHUD.VALIDO if valido else TemaHUD.INVALIDO)
	extra.text = texto_extra
	extra.visible = texto_extra != ""
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


## Distancia al borde inferior: en 1ª persona el panel sube para no tapar la hotbar.
func set_margen_inferior(px: float) -> void:
	_margen_inferior = px
	offset_bottom = -px
