extends PanelContainer

## Ventana emergente (clic en "Almacén" de la barra superior, solo cenital):
## inventario completo del núcleo, con cantidad/límite y tasa de cada recurso.

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")

var _caja := VBoxContainer.new()


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(320, 0)
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caja)


func abrir() -> void:
	for hijo in _caja.get_children():
		hijo.queue_free()
	_caja.add_child(_fila_titulo("Almacén"))
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
	visible = true


func cerrar() -> void:
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
