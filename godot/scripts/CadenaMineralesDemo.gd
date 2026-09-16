extends Node2D

## Escena de demostración standalone (PoC 5, sub-proyecto 1) para probar en
## vivo los números de balance de CadenaMinerales.RECETAS — NO se integra
## con Ciudad.almacen ni con ningún estado real del juego, usa su propio
## almacén simulado. Ver docs/superpowers/specs/2026-09-14-cadena-minerales-design.md,
## sección 3.
##
## Controles:
##   1-6: agrega 10 unidades del mineral correspondiente (mismo orden que
##        Recoleccion.TIPOS_MINERALES: tierra/piedra/hierro/cobre/carbon/tierras_raras)
##   Q/W: resta/suma 1 trabajador a la refinería de hierro (mínimo 0)
##   A/S: resta/suma 1 trabajador a la refinería de tierras raras (mínimo 0)
##   Espacio: avanza un tick de 1.0 hora

var ORDEN_MINERALES: Array = Recoleccion.TIPOS_MINERALES
const TECLAS_MINERALES := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]

@onready var texto: Label = $Texto

var almacen: Dictionary = {}
var trabajadores: Dictionary = {"hierro": 0, "tierras_raras": 0}


func _ready() -> void:
	_actualizar_texto()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var tecla := event as InputEventKey

	var indice_mineral := TECLAS_MINERALES.find(tecla.keycode)
	if indice_mineral != -1:
		var tipo: String = ORDEN_MINERALES[indice_mineral]
		almacen[tipo] = almacen.get(tipo, 0.0) + 10.0
		_actualizar_texto()
		return

	match tecla.keycode:
		KEY_Q:
			trabajadores["hierro"] = maxi(trabajadores["hierro"] - 1, 0)
		KEY_W:
			trabajadores["hierro"] += 1
		KEY_A:
			trabajadores["tierras_raras"] = maxi(trabajadores["tierras_raras"] - 1, 0)
		KEY_S:
			trabajadores["tierras_raras"] += 1
		KEY_SPACE:
			almacen = CadenaMinerales.procesar_tick(1.0, almacen, trabajadores)
		_:
			return
	_actualizar_texto()


func _actualizar_texto() -> void:
	var lineas: Array = ["=== Cadena de Minerales — Demo ===", ""]
	lineas.append("Trabajadores: hierro=%d (Q/W)  tierras_raras=%d (A/S)" % [trabajadores["hierro"], trabajadores["tierras_raras"]])
	lineas.append("")
	lineas.append("Almacén (1-6 agregan 10 de cada mineral):")
	var hay_almacen := false
	for tipo in almacen:
		if almacen[tipo] > 0.0:
			lineas.append("  %s: %.1f" % [tipo, almacen[tipo]])
			hay_almacen = true
	if not hay_almacen:
		lineas.append("  (vacío)")
	lineas.append("")
	lineas.append("Tasas por hora (Espacio avanza 1 tick):")
	var tasas: Dictionary = CadenaMinerales.tasas_refinado(trabajadores)
	if tasas.is_empty():
		lineas.append("  (ninguna receta activa)")
	else:
		for tipo_entrada in tasas:
			var info: Dictionary = tasas[tipo_entrada]
			lineas.append("  %s: -%.1f/h -> %s +%.1f/h" % [tipo_entrada, info["consumo"], info["tipo_salida"], info["produccion"]])
	texto.text = "\n".join(lineas)
