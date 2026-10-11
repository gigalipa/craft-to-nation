extends PanelContainer

## Ventana informativa de la lámpara del jugador (esquina superior izquierda).
## Muestra el modo (eléctrica/térmica), estado (encendida/apagada),
## batería/tiempo restante y recurso en consumo.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

var _titulo: Label
var _detalle: Label


func _init() -> void:
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(columna)

	_titulo = TemaHUD.etiqueta()
	_titulo.add_theme_font_size_override("font_size", 13)
	columna.add_child(_titulo)

	_detalle = TemaHUD.etiqueta()
	_detalle.add_theme_font_size_override("font_size", 12)
	columna.add_child(_detalle)

	visible = false


func actualizar(estado: Dictionary) -> void:
	if not estado.get("visible", false):
		visible = false
		return

	visible = true
	var tipo: String = estado.get("tipo", "electrica")
	var encendida: bool = estado.get("encendida", false)
	_titulo.text = texto_titulo(tipo, encendida)

	if tipo == "electrica":
		var recargando: bool = estado.get("recargando", false)
		var descarga: bool = estado.get("descarga", false)
		var pct: int = int(estado.get("bateria_pct", 100))
		var horas: int = int(estado.get("bateria_horas", 72))
		_detalle.text = texto_detalle_electrica(recargando, descarga, pct, horas)
	else:
		var horas_rest: int = int(estado.get("tiempo_restante_h", 0))
		var cant: int = int(estado.get("recurso_cantidad", 0))
		var nom: String = estado.get("recurso_nombre", "")
		_detalle.text = texto_detalle_termica(horas_rest, cant, nom)


static func texto_titulo(tipo: String, encendida: bool) -> String:
	var icono := "🟡" if encendida else "⚫"
	var nombre_tipo := "ELÉCTRICA" if tipo == "electrica" else "TÉRMICA"
	return "LÁMPARA %s%s" % [nombre_tipo, icono]


static func texto_detalle_electrica(recargando: bool, descarga: bool, pct: int, horas: int) -> String:
	var signo := ""
	if recargando:
		signo = "+"
	elif descarga:
		signo = "-"
	return "Batería: %s%d%% | %d h" % [signo, pct, horas]


static func texto_detalle_termica(horas_restantes: int, cantidad: int, nombre_recurso: String) -> String:
	return "Tiempo restante: %d h | %d %s" % [horas_restantes, cantidad, nombre_recurso]
