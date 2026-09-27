extends PanelContainer

## Ventana emergente (clic en "Almacén" de la barra superior, solo cenital):
## inventario completo del núcleo, con cantidad/límite y tasa de cada recurso.
## Se actualiza en vivo mientras está visible. Arrastrable con el ratón;
## aparece por defecto en la esquina superior izquierda (debajo de la de
## Población, ver POSICION_INICIAL). Hijo de HUD (nunca se destruye): su
## posición y si está abierta o cerrada persisten solas mientras dura la
## partida, incluida al salir y volver a entrar a la cenital (HUD.set_vista()
## la oculta/restaura sin tocarlas).

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
	_caja_raiz.add_child(_fila_titulo("Almacén"))
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
		_caja.add_child(TemaHUD.etiqueta("Vacío"))
	for clave in Ciudad.almacen:
		var recurso = Ciudad.almacen[clave]
		var nombre: String = HUDScript.NOMBRES_RECURSO.get(clave, recurso.nombre)
		var fila := "%s: %.0f/%.0f %s" % [nombre, recurso.cantidad, recurso.limite, BarraSuperiorScript.texto_tasa(recurso.tasa_neta_promedio)]
		var etiqueta := TemaHUD.etiqueta(fila)
		if recurso.tasa_neta_promedio < 0.0:
			etiqueta.add_theme_color_override("font_color", TemaHUD.INVALIDO)
		_caja.add_child(etiqueta)


func cerrar() -> void:
	abierta = false
	visible = false


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
