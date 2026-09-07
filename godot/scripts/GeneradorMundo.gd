extends RefCounted

## Generación pura del mapa de alturas del mundo — sin nodos de escena, sin
## GridMap. Ver spec: docs/superpowers/specs/2026-09-07-mundo-procedural-design.md
## Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd: evitar el bug
## de caché de clases globales de Godot) — se usa vía preload().new().

const ALTURA_MINIMA := 0
const ALTURA_MAXIMA := 15
const GROSOR_TIERRA := 4

var _ruido: FastNoiseLite


func _init(semilla: int) -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido.frequency = 0.02


## Altura de la superficie en (x, z), determinista para (semilla, x, z).
## get_noise_2d() devuelve un valor en [-1, 1]; se remapea linealmente a
## [ALTURA_MINIMA, ALTURA_MAXIMA] y se redondea a entero.
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var t: float = (valor + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)


## Tipo de bloque de subsuelo según qué tan profundo está bajo la
## superficie: 0 = la celda de superficie misma, 1 = la primera celda
## debajo, etc. "tierra" cerca de la superficie, "piedra" más profundo —
## relativo a GROSOR_TIERRA, no a un número de capa absoluto (para poder
## escalar PROFUNDIDAD_SUBSUELO más adelante sin tocar esta función).
func tipo_en_profundidad(profundidad_bajo_superficie: int) -> String:
	if profundidad_bajo_superficie < GROSOR_TIERRA:
		return "tierra"
	return "piedra"
