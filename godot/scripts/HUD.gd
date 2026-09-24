extends CanvasLayer

## HUD básico (ver PoC_4/, sub-proyecto 2): lee el autoload Ciudad cada
## fotograma y muestra nivel urbano, moral (1 línea cada uno, no tienen una
## "tasa" que valga la pena mostrar todavía), población (ciudadanos/camas
## construidas, en rojo si excede la capacidad — señal de que hace falta
## ampliar zona o construir más edificios residenciales) y la lista de los
## recursos del almacén con su tasa neta (una línea por recurso, en blanco si
## el promedio de las últimas horas es >= 0 o roja si es negativa).

const COLOR_POSITIVO := Color.WHITE
const COLOR_NEGATIVO := Color(1.0, 0.3, 0.3)

const NOMBRES_RECURSO := {
	"comida": "Comida",
	"madera": "Madera",
	"hierro": "Hierro",
	"tierra": "Tierra",
	"piedra": "Piedra",
	"cobre": "Cobre",
	"carbon": "Carbón",
	"tierras_raras": "Tierras raras",
}

const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")

const NOMBRES_CAZA_RECOLECCION := {
	"caza": "caza",
	"recoleccion": "recolección",
}

const NOMBRES_PESCA_FRUTOS_MAR := {
	"pesca": "pesca",
	"frutos_mar": "frutos del mar",
}

@onready var nivel_label: Label = $HUD/NivelLabel
@onready var poblacion_label: Label = $HUD/PoblacionLabel
@onready var moral_label: Label = $HUD/MoralLabel
@onready var recursos_lista: VBoxContainer = $HUD

var _recursos_labels := {}  # clave de Ciudad.almacen -> Label
var _panel_puesto: PanelContainer
var _barra_progreso: ProgressBar

@onready var mina_ficha: VBoxContainer = $MinaFicha
@onready var mina_costo_label: Label = $MinaFicha/CostoLabel
@onready var mina_personal_label: Label = $MinaFicha/PersonalLabel
@onready var mina_almacenamiento_label: Label = $MinaFicha/AlmacenamientoLabel
@onready var mina_tasas_label: Label = $MinaFicha/TasasLabel

@onready var caza_ficha: VBoxContainer = $CazaFicha
@onready var caza_costo_label: Label = $CazaFicha/CostoLabel
@onready var caza_personal_label: Label = $CazaFicha/PersonalLabel
@onready var caza_almacenamiento_label: Label = $CazaFicha/AlmacenamientoLabel
@onready var caza_tasas_label: Label = $CazaFicha/TasasLabel

@onready var madero_ficha: VBoxContainer = $MaderoFicha
@onready var madero_costo_label: Label = $MaderoFicha/CostoLabel
@onready var madero_personal_label: Label = $MaderoFicha/PersonalLabel
@onready var madero_almacenamiento_label: Label = $MaderoFicha/AlmacenamientoLabel
@onready var madero_tasas_label: Label = $MaderoFicha/TasasLabel

@onready var pesca_ficha: VBoxContainer = $PescaFicha
@onready var pesca_costo_label: Label = $PescaFicha/CostoLabel
@onready var pesca_personal_label: Label = $PescaFicha/PersonalLabel
@onready var pesca_almacenamiento_label: Label = $PescaFicha/AlmacenamientoLabel
@onready var pesca_tasas_label: Label = $PescaFicha/TasasLabel

@onready var modo_deconstruccion_label: Label = $ModoDeconstruccionLabel
@onready var modo_zonificacion_label: Label = $ModoZonificacionLabel
@onready var modo_trazar_via_label: Label = $ModoTrazarViaLabel

@onready var oxigeno_label: Label = $OxigenoLabel
@onready var materiales_ficha: Label = $MaterialesFicha


func _ready() -> void:
	# Lista de control de recursos: una fila por recurso del almacén central.
	for clave in Ciudad.almacen:
		var etiqueta := Label.new()
		recursos_lista.add_child(etiqueta)
		_recursos_labels[clave] = etiqueta
	_panel_puesto = PanelPuestoScript.new()
	add_child(_panel_puesto)

	# Barra de progreso de minar/talar/recolectar/deconstruir, bajo la mira.
	_barra_progreso = ProgressBar.new()
	_barra_progreso.show_percentage = false
	_barra_progreso.set_anchors_preset(Control.PRESET_CENTER)
	_barra_progreso.offset_left = -90
	_barra_progreso.offset_right = 90
	_barra_progreso.offset_top = 40
	_barra_progreso.offset_bottom = 54
	_barra_progreso.visible = false
	add_child(_barra_progreso)


func _process(_delta: float) -> void:
	nivel_label.text = "Nivel: %d (potencial: %d)" % [Ciudad.nivel, Ciudad.nivel_potencial]
	poblacion_label.text = "Población: %d (vivienda %.1f / %d)" % [Ciudad.censo_total, Ciudad.vivienda_ocupada, Ciudad.capacidad_camas_construida]
	poblacion_label.modulate = COLOR_NEGATIVO if Ciudad.vivienda_ocupada > Ciudad.capacidad_camas_construida else COLOR_POSITIVO
	moral_label.text = "Moral (variedad): %.1f" % Ciudad.bono_moral_variedad

	for clave in _recursos_labels:
		_actualizar_recurso(clave, _recursos_labels[clave])


func _actualizar_recurso(clave: String, etiqueta: Label) -> void:
	var recurso = Ciudad.almacen[clave]
	var tasa: float = recurso.tasa_neta_promedio
	var signo := "+" if tasa >= 0 else ""
	etiqueta.text = "  %s: %.0f / %.0f  (%s%.1f /h)" % [NOMBRES_RECURSO.get(clave, clave), recurso.cantidad, recurso.limite, signo, tasa]
	etiqueta.modulate = COLOR_POSITIVO if tasa >= 0 else COLOR_NEGATIVO


## Muestra la ficha de la mina con sus valores FIJOS (costo, personal,
## almacenamiento — no cambian según la posición del cursor, a diferencia
## de las tasas de recolección, que sí — ver actualizar_tasas_mina()).
func mostrar_ficha_mina() -> void:
	var partes_costo: Array = []
	for tipo in Recoleccion.COSTO_CONSTRUCCION:
		partes_costo.append("%d %s" % [Recoleccion.COSTO_CONSTRUCCION[tipo], tipo])
	mina_costo_label.text = "Costo: %s" % ", ".join(partes_costo)
	mina_personal_label.text = "Personal máximo: %d" % Recoleccion.PERSONAL_MAXIMO
	mina_almacenamiento_label.text = "Almacenamiento: %d" % Recoleccion.CAPACIDAD_ALMACENAMIENTO
	mina_tasas_label.text = "Recolección prevista: -"
	mina_ficha.visible = true


## Recalculada en vivo cada fotograma mientras el modo colocar-mina está
## activo, a partir de Recoleccion.tasas_recoleccion().
func actualizar_tasas_mina(tasas: Dictionary) -> void:
	if tasas.is_empty():
		mina_tasas_label.text = "Recolección prevista: sin recursos detectados"
		return
	var lineas: Array = []
	for tipo in tasas:
		lineas.append("%.1f %s/h" % [tasas[tipo], tipo])
	mina_tasas_label.text = "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)


func ocultar_ficha_mina() -> void:
	mina_ficha.visible = false


## Mismo patrón que mostrar_ficha_mina(): valores FIJOS al activar el modo
## (no cambian según la posición del cursor); las tasas sí varían — ver
## actualizar_tasas_caza().
func mostrar_ficha_caza() -> void:
	var partes_costo: Array = []
	for tipo in Recoleccion.COSTO_CONSTRUCCION_CAZA_RECOLECCION:
		partes_costo.append("%d %s" % [Recoleccion.COSTO_CONSTRUCCION_CAZA_RECOLECCION[tipo], tipo])
	caza_costo_label.text = "Costo: %s" % ", ".join(partes_costo)
	caza_personal_label.text = "Personal máximo: %d" % Recoleccion.PERSONAL_MAXIMO_CAZA_RECOLECCION
	caza_almacenamiento_label.text = "Almacenamiento: %d" % Recoleccion.CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION
	caza_tasas_label.text = "Recolección prevista: -"
	caza_ficha.visible = true


## Recalculada en vivo cada fotograma mientras el modo colocar-puesto (tipo
## "caza_recoleccion") está activo, a partir de
## Recoleccion.tasas_caza_recoleccion(). "tasas" siempre tiene ambas claves
## ("caza"/"recoleccion", ver Recoleccion.gd) — el caso "sin nada detectado"
## se distingue por ambos valores en 0.0, no por un diccionario vacío.
func actualizar_tasas_caza(tasas: Dictionary) -> void:
	if tasas.get("caza", 0.0) <= 0.0 and tasas.get("recoleccion", 0.0) <= 0.0:
		caza_tasas_label.text = "Recolección prevista: sin fauna ni fruta detectada"
		return
	var lineas: Array = []
	for tipo in tasas:
		lineas.append("%.1f comida/h por %s" % [tasas[tipo], NOMBRES_CAZA_RECOLECCION.get(tipo, tipo)])
	caza_tasas_label.text = "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)


func ocultar_ficha_caza() -> void:
	caza_ficha.visible = false


## Mismo patrón que mostrar_ficha_mina()/mostrar_ficha_caza(): valores FIJOS
## al activar el modo; la tasa sí varía — ver actualizar_tasas_madero().
func mostrar_ficha_madero() -> void:
	var partes_costo: Array = []
	for tipo in Recoleccion.COSTO_CONSTRUCCION_MADERERO:
		partes_costo.append("%d %s" % [Recoleccion.COSTO_CONSTRUCCION_MADERERO[tipo], tipo])
	madero_costo_label.text = "Costo: %s" % ", ".join(partes_costo)
	madero_personal_label.text = "Personal máximo: %d" % Recoleccion.PERSONAL_MAXIMO_MADERERO
	madero_almacenamiento_label.text = "Almacenamiento: %d" % Recoleccion.CAPACIDAD_ALMACENAMIENTO_MADERERO
	madero_tasas_label.text = "Recolección prevista: -"
	madero_ficha.visible = true


## Recalculada en vivo cada fotograma mientras el modo colocar-puesto (tipo
## "maderero") está activo, a partir de Recoleccion.tasa_maderero().
func actualizar_tasas_madero(tasas: Dictionary) -> void:
	if tasas.get("madera", 0.0) <= 0.0:
		madero_tasas_label.text = "Recolección prevista: sin árboles detectados"
		return
	madero_tasas_label.text = "Recolección prevista por ciudadano:\n  %.1f madera/h" % tasas["madera"]


func ocultar_ficha_madero() -> void:
	madero_ficha.visible = false


## Mismo patrón que mostrar_ficha_caza(): valores FIJOS al activar el modo;
## las tasas sí varían — ver actualizar_tasas_pesca().
func mostrar_ficha_pesca() -> void:
	var partes_costo: Array = []
	for tipo in Recoleccion.COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR:
		partes_costo.append("%d %s" % [Recoleccion.COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR[tipo], tipo])
	pesca_costo_label.text = "Costo: %s" % ", ".join(partes_costo)
	pesca_personal_label.text = "Personal máximo: %d" % Recoleccion.PERSONAL_MAXIMO_PESCA_FRUTOS_MAR
	pesca_almacenamiento_label.text = "Almacenamiento: %d" % Recoleccion.CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR
	pesca_tasas_label.text = "Recolección prevista: -"
	pesca_ficha.visible = true


## Recalculada en vivo cada fotograma mientras el modo colocar-puesto (tipo
## "pesca_frutos_mar") está activo, a partir de
## Recoleccion.tasas_pesca_frutos_mar(). "tasas" puede ser un Dictionary
## vacío ({}) cuando el extremo de agua todavía no es válido — ver
## CamaraCenital.gd.
func actualizar_tasas_pesca(tasas: Dictionary) -> void:
	if tasas.get("pesca", 0.0) <= 0.0 and tasas.get("frutos_mar", 0.0) <= 0.0:
		pesca_tasas_label.text = "Recolección prevista: sin agua detectada"
		return
	var lineas: Array = []
	for tipo in tasas:
		lineas.append("%.1f comida/h por %s" % [tasas[tipo], NOMBRES_PESCA_FRUTOS_MAR.get(tipo, tipo)])
	pesca_tasas_label.text = "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)


func ocultar_ficha_pesca() -> void:
	pesca_ficha.visible = false


## Muestra/oculta el aviso de que el modo deconstrucción está activo (ver
## Player.gd::_alternar_modo_deconstruccion(), tecla G).
func mostrar_modo_deconstruccion() -> void:
	modo_deconstruccion_label.visible = true


func ocultar_modo_deconstruccion() -> void:
	modo_deconstruccion_label.visible = false


## Aviso del modo zonificación (tecla Z en la cenital, ver
## CamaraCenital._alternar_modo_zonificar()): la zona que se pinta ahora y las
## teclas para cambiarla o salir. "nombre_zona" es "Zona A", "Zona B" o "Borrar".
func mostrar_modo_zonificacion(nombre_zona: String) -> void:
	modo_zonificacion_label.text = "Zonificación: %s   (1 Zona A · 2 Zona B · 0 Borrar · Z/Esc para salir)" % nombre_zona
	modo_zonificacion_label.visible = true


func ocultar_modo_zonificacion() -> void:
	modo_zonificacion_label.visible = false


## Aviso del modo trazador de vías (tecla V en la cenital, ver
## CamaraCenital._alternar_modo_trazar_via()).
func mostrar_modo_trazar_via() -> void:
	modo_trazar_via_label.text = "Trazar vía: clic para fijar puntos · doble clic para confirmar · Esc para salir"
	modo_trazar_via_label.visible = true


func ocultar_modo_trazar_via() -> void:
	modo_trazar_via_label.visible = false


## Llamada cada física por Player._procesar_oxigeno() mientras el jugador
## está en agua o recuperando aire — oculta con ocultar_oxigeno() en cuanto
## vuelve a estar a full fuera del agua, para no saturar el HUD en seco.
func actualizar_oxigeno(fraccion: float) -> void:
	oxigeno_label.text = "Oxígeno: %d%%" % round(fraccion * 100)
	oxigeno_label.modulate = COLOR_NEGATIVO if fraccion < 0.3 else COLOR_POSITIVO
	oxigeno_label.visible = true


func ocultar_oxigeno() -> void:
	oxigeno_label.visible = false


## Ficha VISUAL de los materiales que movilizaría el blueprint activo (ver
## docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md):
## no lee ni toca ningún inventario real (no existe todavía).
func mostrar_ficha_materiales() -> void:
	materiales_ficha.text = texto_materiales({})
	materiales_ficha.visible = true


func actualizar_materiales(neto: Dictionary) -> void:
	materiales_ficha.text = texto_materiales(neto)


func ocultar_ficha_materiales() -> void:
	materiales_ficha.visible = false


## "neto" es material -> int (negativo = hace falta, positivo = sobra; ver
## NiveladorTerreno.resumen_materiales()). Lo necesario va sin signo y de
## mayor a menor; el sobrante recogido va después con "+".
static func texto_materiales(neto: Dictionary) -> String:
	var necesarios: Array = []
	var sobrantes: Array = []
	for material in neto:
		var cantidad: int = neto[material]
		if cantidad < 0:
			necesarios.append([-cantidad, material])
		elif cantidad > 0:
			sobrantes.append("+ %d %s" % [cantidad, material])
	necesarios.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lineas: Array = ["Materiales de construcción:"]
	for necesario in necesarios:
		lineas.append("%d %s" % [necesario[0], necesario[1]])
	lineas.append_array(sobrantes)
	if lineas.size() == 1:
		lineas.append("-")
	return "\n".join(lineas)


func abrir_panel_puesto(esquina: Vector2i) -> void:
	_panel_puesto.abrir(esquina)


func cerrar_panel_puesto() -> void:
	_panel_puesto.cerrar()


## Muestra la barra de progreso bajo la mira. "retrocede" (tala, deconstrucción)
## la pinta en naranja: indica lo que le queda a lo que se está desmontando.
func mostrar_progreso(fraccion: float, retrocede: bool = false) -> void:
	_barra_progreso.value = clampf(fraccion, 0.0, 1.0) * 100.0
	_barra_progreso.modulate = Color(1.0, 0.6, 0.2) if retrocede else Color(0.4, 1.0, 0.4)
	_barra_progreso.visible = true


func ocultar_progreso() -> void:
	_barra_progreso.visible = false
