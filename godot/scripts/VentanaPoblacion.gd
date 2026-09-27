extends PanelContainer

## Ventana emergente (clic en "Población" de la barra superior, solo cenital):
## censo por tipo, camas totales y la distribución de trabajadores por puesto.
## Se reconstruye entera cada vez que se abre; no hace falta refrescarla en
## vivo porque se cierra antes de volver a interactuar con el mundo.

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")

const NOMBRES_TIPO := {
	"ciudadano": "Ciudadanos",
	"desempleado": "Desempleados",
	"obrero": "Obreros",
	"tecnico": "Técnicos",
	"especialista": "Especialistas",
	"investigador": "Investigadores",
	"militar": "Militares",
}

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
	_caja.add_child(_fila_titulo("Población"))
	_caja.add_child(TemaHUD.etiqueta("Camas construidas: %d" % Ciudad.capacidad_camas_construida))
	_caja.add_child(TemaHUD.etiqueta(""))
	for tipo in NOMBRES_TIPO:
		var cantidad: int = Ciudad.demografia.get(tipo, 0)
		if cantidad > 0:
			_caja.add_child(TemaHUD.etiqueta("%s: %d" % [NOMBRES_TIPO[tipo], cantidad]))
	_caja.add_child(TemaHUD.etiqueta(""))
	_caja.add_child(TemaHUD.etiqueta("Puestos de trabajo:"))
	if Economia.puestos.is_empty():
		_caja.add_child(TemaHUD.etiqueta("  Ninguno todavía"))
	for esquina in Economia.puestos:
		var puesto: Dictionary = Economia.puestos[esquina]
		var t: Dictionary = Economia.trabajadores_de(esquina)
		var nombre: String = PanelPuestoScript.NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"])
		_caja.add_child(TemaHUD.etiqueta("  %s: %d recolectores, %d acarreadores" % [nombre, t["recolectores"], t["acarreadores"]]))
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
