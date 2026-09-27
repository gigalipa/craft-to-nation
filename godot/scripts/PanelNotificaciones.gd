extends Control

## Notificaciones emergentes, esquina superior derecha, debajo de la barra
## superior (ver HUD.notificar()): cada una aparece con fade-in, dura
## DURACION_VISIBLE y se desvanece con fade-out. Varias notificaciones se
## apilan verticalmente (VBoxContainer: la más vieja arriba, las nuevas se
## agregan abajo) y cada una se desvanece de forma independiente, así que la
## de arriba (la más antigua) desaparece primero.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

const DURACION_VISIBLE := 2.5
const DURACION_FADE := 0.25
const ANCHO := 320.0

var _lista: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -ANCHO - 12.0
	offset_right = -12.0
	# 44 = alto de BarraSuperior, +12 de margen.
	offset_top = 56.0
	_lista = VBoxContainer.new()
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista.alignment = BoxContainer.ALIGNMENT_BEGIN
	_lista.add_theme_constant_override("separation", 8)
	add_child(_lista)


## Encola una notificación con este texto; aparece, se queda y se desvanece
## sola, sin bloquear ni desplazar a las demás.
func notificar(texto: String) -> void:
	var panel := PanelContainer.new()
	TemaHUD.aplicar_panel(panel)
	panel.modulate.a = 0.0
	panel.custom_minimum_size.x = ANCHO
	var etiqueta := TemaHUD.etiqueta(texto)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size.x = ANCHO
	panel.add_child(etiqueta)
	_lista.add_child(panel)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, DURACION_FADE)
	tween.tween_interval(DURACION_VISIBLE)
	tween.tween_property(panel, "modulate:a", 0.0, DURACION_FADE)
	tween.tween_callback(panel.queue_free)
