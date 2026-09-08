extends RefCounted

## Generación pura del mapa de alturas del mundo — sin nodos de escena, sin
## GridMap. Ver spec: docs/superpowers/specs/2026-09-07-mundo-procedural-design.md,
## docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md (vetas
## de hierro). Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd:
## evitar el bug de caché de clases globales de Godot) — se usa vía preload().new().

const ALTURA_MINIMA := 0
const ALTURA_MAXIMA := 15
const GROSOR_TIERRA := 4

## Umbral de get_noise_3d() (rango [-1, 1]) por encima del cual una celda de
## piedra se convierte en hierro — ver tipo_en_profundidad(). El rango teórico
## es [-1, 1], pero para esta semilla/frecuencia el rango observado de
## get_noise_3d() no se acerca a esos extremos (tope real ~0.37-0.4) — un
## umbral de 0.55 (o incluso 0.4) nunca se alcanza y nunca produciría hierro.
## Recalibrado empíricamente a 0.2, que sigue dejando al hierro como clara
## minoría frente a la piedra en la capa profunda.
const UMBRAL_HIERRO := 0.2

var _ruido: FastNoiseLite
var _ruido_mineral: FastNoiseLite


func _init(semilla: int) -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido.frequency = 0.02

	# Semilla derivada (no la misma que _ruido) para que las vetas de hierro
	# no queden correlacionadas con el relieve de superficie — sigue siendo
	# determinista: misma semilla de entrada, mismas vetas siempre.
	_ruido_mineral = FastNoiseLite.new()
	_ruido_mineral.seed = semilla + 1
	_ruido_mineral.noise_type = FastNoiseLite.TYPE_PERLIN
	# Frecuencia baja a propósito (más baja que _ruido) para producir vetas/
	# grumos grandes y deformes en vez de ruido puntual disperso celda a celda.
	_ruido_mineral.frequency = 0.05


## Altura de la superficie en (x, z), determinista para (semilla, x, z).
## get_noise_2d() devuelve un valor en [-1, 1]; se remapea linealmente a
## [ALTURA_MINIMA, ALTURA_MAXIMA] y se redondea a entero.
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var t: float = (valor + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)


## Tipo de bloque de subsuelo en la columna/profundidad dados: "tierra" cerca
## de la superficie (por debajo de GROSOR_TIERRA), "piedra" más profundo, o
## "hierro" si el ruido de vetas supera UMBRAL_HIERRO en esa celda exacta —
## el hierro NUNCA aparece en la capa de tierra, sin importar el ruido (el
## chequeo de profundidad corta antes de consultar _ruido_mineral). (x, y, z)
## son coordenadas absolutas del mundo (y = altura de superficie -
## profundidad_bajo_superficie) — necesarias para el ruido 3D, a diferencia
## de la versión anterior de esta función que solo dependía de la profundidad
## relativa.
func tipo_en_profundidad(x: int, y: int, z: int, profundidad_bajo_superficie: int) -> String:
	if profundidad_bajo_superficie < GROSOR_TIERRA:
		return "tierra"
	if _ruido_mineral.get_noise_3d(x, y, z) > UMBRAL_HIERRO:
		return "hierro"
	return "piedra"
