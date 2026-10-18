extends PanelContainer

## Ventana informativa de la lámpara del jugador (esquina superior izquierda).
## Muestra el modo (eléctrica/térmica), estado (encendida/apagada),
## batería/tiempo restante y recurso en consumo.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

var _titulo: Label
var _detalle: Label

# Elementos visuales con íconos
var _icono_lampara: TextureRect
var _fila_electrica: HBoxContainer
var _icono_bateria: TextureRect
var _barra_bateria: ProgressBar
var _lbl_horas_electrica: Label

var _fila_termica: HBoxContainer
var _icono_reloj: TextureRect
var _lbl_horas_termica: Label
var _icono_recurso: TextureRect


func _init() -> void:
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(columna)

	var fila_encabezado := HBoxContainer.new()
	fila_encabezado.add_theme_constant_override("separation", 6)
	fila_encabezado.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_icono_lampara = IconosHUD.crear_rect("lampara_electrica_off", Vector2(16, 16))
	fila_encabezado.add_child(_icono_lampara)

	_titulo = TemaHUD.etiqueta()
	_titulo.add_theme_font_size_override("font_size", 13)
	fila_encabezado.add_child(_titulo)
	columna.add_child(fila_encabezado)

	# Fila eléctrica (batería icono + ProgressBar + horas)
	_fila_electrica = HBoxContainer.new()
	_fila_electrica.add_theme_constant_override("separation", 6)
	_fila_electrica.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_icono_bateria = IconosHUD.crear_rect("bateria", Vector2(16, 16))
	_fila_electrica.add_child(_icono_bateria)

	_barra_bateria = ProgressBar.new()
	_barra_bateria.show_percentage = false
	_barra_bateria.max_value = 100.0
	_barra_bateria.custom_minimum_size = Vector2(60, 10)
	_barra_bateria.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barra_bateria.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fila_electrica.add_child(_barra_bateria)

	_lbl_horas_electrica = TemaHUD.etiqueta()
	_lbl_horas_electrica.add_theme_font_size_override("font_size", 12)
	_fila_electrica.add_child(_lbl_horas_electrica)
	columna.add_child(_fila_electrica)

	# Fila térmica (reloj icono + horas + icono del recurso sin cantidad numérica)
	_fila_termica = HBoxContainer.new()
	_fila_termica.add_theme_constant_override("separation", 6)
	_fila_termica.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_icono_reloj = IconosHUD.crear_rect("reloj_arena", Vector2(16, 16))
	_fila_termica.add_child(_icono_reloj)

	_lbl_horas_termica = TemaHUD.etiqueta()
	_lbl_horas_termica.add_theme_font_size_override("font_size", 12)
	_fila_termica.add_child(_lbl_horas_termica)

	_icono_recurso = IconosHUD.crear_rect("carbon", Vector2(16, 16))
	_fila_termica.add_child(_icono_recurso)
	columna.add_child(_fila_termica)

	_detalle = TemaHUD.etiqueta()
	_detalle.add_theme_font_size_override("font_size", 12)
	_detalle.visible = false
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
		_icono_lampara.texture = IconosHUD.icono("lampara_electrica_on" if encendida else "lampara_electrica_off")
		_fila_electrica.visible = true
		_fila_termica.visible = false

		var recargando: bool = estado.get("recargando", false)
		var descarga: bool = estado.get("descarga", false)
		var pct: int = int(estado.get("bateria_pct", 100))
		var horas: int = int(estado.get("bateria_horas", 72))
		_barra_bateria.value = float(pct)
		_barra_bateria.modulate = color_bateria(float(pct))
		var signo := "+" if recargando else ("-" if descarga else "")
		_lbl_horas_electrica.text = "%s%d h" % [signo, horas]
		_detalle.text = texto_detalle_electrica(recargando, descarga, pct, horas)
	else:
		_icono_lampara.texture = IconosHUD.icono("lampara_termica_on" if encendida else "lampara_termica_off")
		_fila_electrica.visible = false
		_fila_termica.visible = true

		var horas_rest: int = int(estado.get("tiempo_restante_h", 0))
		var cant: int = int(estado.get("recurso_cantidad", 0))
		var nom: String = estado.get("recurso_nombre", "")
		_lbl_horas_termica.text = "%d h" % horas_rest

		var clave_rec := nom.to_lower()
		if clave_rec.contains("carb"):
			clave_rec = "carbon"
		elif clave_rec.contains("crud"):
			clave_rec = "crudo"
		elif clave_rec.contains("comb"):
			clave_rec = "combustible"
		_icono_recurso.texture = IconosHUD.icono(clave_rec)

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


static func color_bateria(pct: float) -> Color:
	if pct > 50.0:
		return Color(0.2, 0.9, 0.2)
	elif pct > 25.0:
		return Color(0.9, 0.85, 0.2)
	elif pct > 10.0:
		return Color(1.0, 0.55, 0.1)
	else:
		return Color(0.95, 0.2, 0.2)
