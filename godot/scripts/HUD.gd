extends CanvasLayer

## HUD básico (ver PoC_4/, sub-proyecto 2): lee el autoload Ciudad cada
## fotograma y muestra nivel urbano, moral (1 línea cada uno, no tienen una
## "tasa" que valga la pena mostrar todavía), población (ciudadanos/camas
## construidas, en rojo si excede la capacidad — señal de que hace falta
## ampliar zona o construir más edificios residenciales) y comida + recurso
## crítico (2 líneas: cantidad almacenada en blanco, tasa neta del último
## tick en blanco si es >= 0 o rojo si es negativa).

const COLOR_POSITIVO := Color.WHITE
const COLOR_NEGATIVO := Color(1.0, 0.3, 0.3)

const NOMBRES_RECURSO := {
	"comida": "Comida",
	"madera": "Madera",
	"hierro": "Hierro",
}

@onready var nivel_label: Label = $HUD/NivelLabel
@onready var poblacion_label: Label = $HUD/PoblacionLabel
@onready var moral_label: Label = $HUD/MoralLabel
@onready var comida_stock_label: Label = $HUD/ComidaStockLabel
@onready var comida_tasa_label: Label = $HUD/ComidaTasaLabel
@onready var critico_nombre_label: Label = $HUD/CriticoNombreLabel
@onready var critico_stock_label: Label = $HUD/CriticoStockLabel
@onready var critico_tasa_label: Label = $HUD/CriticoTasaLabel

@onready var mina_ficha: VBoxContainer = $MinaFicha
@onready var mina_costo_label: Label = $MinaFicha/CostoLabel
@onready var mina_personal_label: Label = $MinaFicha/PersonalLabel
@onready var mina_almacenamiento_label: Label = $MinaFicha/AlmacenamientoLabel
@onready var mina_tasas_label: Label = $MinaFicha/TasasLabel


func _process(_delta: float) -> void:
	nivel_label.text = "Nivel: %d (potencial: %d)" % [Ciudad.nivel, Ciudad.nivel_potencial]
	poblacion_label.text = "Población: %d / %d" % [Ciudad.censo_total, Ciudad.capacidad_camas_construida]
	poblacion_label.modulate = COLOR_NEGATIVO if Ciudad.censo_total > Ciudad.capacidad_camas_construida else COLOR_POSITIVO
	moral_label.text = "Moral (variedad): %.1f" % Ciudad.bono_moral_variedad

	_actualizar_recurso("comida", comida_stock_label, comida_tasa_label)

	var clave_critica: String = Ciudad.recurso_critico()
	critico_nombre_label.text = "Recurso crítico: %s" % NOMBRES_RECURSO.get(clave_critica, clave_critica)
	if clave_critica != "":
		_actualizar_recurso(clave_critica, critico_stock_label, critico_tasa_label)


func _actualizar_recurso(clave: String, stock_label: Label, tasa_label: Label) -> void:
	var recurso = Ciudad.almacen[clave]
	stock_label.text = "  %s: %.0f / %.0f" % [NOMBRES_RECURSO.get(clave, clave), recurso.cantidad, recurso.limite]
	var tasa: float = recurso.tasa_neta
	var signo := "+" if tasa >= 0 else ""
	tasa_label.text = "  %s%.1f /tick" % [signo, tasa]
	tasa_label.modulate = COLOR_POSITIVO if tasa >= 0 else COLOR_NEGATIVO


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
