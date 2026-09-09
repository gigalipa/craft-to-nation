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

## Exponente de la redistribución por curva de potencia aplicada a la altura
## (ver altura_en() y _redistribuir()) para producir picos y cuencas más
## marcados en vez de colinas suaves — necesario para que el criterio de
## nivel de mar (ver nivel_mar más abajo) separe tierra firme de zonas
## inundadas de forma perceptible.
## sign(x) * pow(abs(x), exponente): un exponente >1 (el valor original,
## 2.0, era un error) COMPRIME |x|<1 hacia 0 (0.5 -> 0.25, más cerca del
## centro, no más lejos) — aplana TODO el relieve hacia el centro en vez de
## acentuar picos/cuencas, y por eso el mundo real terminaba con ~92% de las
## columnas concentradas en solo 2 alturas centrales (ver Task 2, medido con
## SEMILLA_MUNDO/ANCHO_MUNDO/LARGO_MUNDO). Un exponente <1 EXPANDE |x|<1
## alejándolo de 0 (0.5 -> 0.71 con exponente 0.5), lo que sí acentúa picos y
## cuencas reales. Calibrado empíricamente entre 0.5 y 0.7 (ver Task 2); 0.5
## dio la distribución de alturas más pareja de las probadas — ajustar aquí
## si al probar en el editor el relieve resulta demasiado suave o demasiado
## abrupto, siempre con un valor <1.
const EXPONENTE_RELIEVE := 0.5

## Percentil (sobre la distribución real de altura_en() en todo el grid) que
## define nivel_mar — ver _calcular_nivel_mar(). Fijo por ahora; en un
## desarrollo futuro dependerá del "tipo de mundo" elegido (archipiélago,
## continental, etc.) — ver spec docs/superpowers/specs/2026-09-08-cuerpos-de-agua-design.md.
const PERCENTIL_NIVEL_MAR := 0.15

## Cuántas unidades de altura por encima de nivel_mar sigue habiendo bioma
## (vegetación/fauna) antes de volverse tierra estéril — ver es_bioma_en().
## Valor inicial calibrado empíricamente, mismo patrón que GROSOR_TIERRA/
## UMBRAL_HIERRO/EXPONENTE_RELIEVE: ajustar aquí si en el editor real la
## banda resulta demasiado angosta o demasiado ancha.
const BANDA_BIOMA := 4

## Altura por debajo de la cual una columna se considera inundada (ver
## es_agua_en()). Calculada una vez en _init() a partir de
## PERCENTIL_NIVEL_MAR sobre la distribución real del grid (ancho_mundo x
## largo_mundo) — no es un valor fijo, para ser robusta a cambios de
## semilla, frecuencia de ruido o EXPONENTE_RELIEVE.
var nivel_mar: int

var _ruido: FastNoiseLite
var _ruido_mineral: FastNoiseLite
var _ruido_fauna: FastNoiseLite
var _ruido_frutal: FastNoiseLite


func _init(semilla: int, ancho_mundo: int, largo_mundo: int) -> void:
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

	# Semillas derivadas distintas de _ruido (base) y _ruido_mineral
	# (semilla + 1) para que fauna y frutal no queden correlacionadas entre
	# sí ni con el relieve/minerales — igual de deterministas: misma
	# semilla de entrada, mismas señales siempre.
	_ruido_fauna = FastNoiseLite.new()
	_ruido_fauna.seed = semilla + 2
	_ruido_fauna.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_fauna.frequency = 0.05

	_ruido_frutal = FastNoiseLite.new()
	_ruido_frutal.seed = semilla + 3
	_ruido_frutal.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_frutal.frequency = 0.05

	nivel_mar = _calcular_nivel_mar(ancho_mundo, largo_mundo)


## Altura de la superficie en (x, z), determinista para (semilla, x, z).
## get_noise_2d() devuelve un valor en [-1, 1]; se remapea linealmente a
## [ALTURA_MINIMA, ALTURA_MAXIMA] y se redondea a entero.
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var valor_redistribuido: float = _redistribuir(valor, EXPONENTE_RELIEVE)
	var t: float = (valor_redistribuido + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)


## Curva de potencia sign(x)*pow(abs(x), exponente): comprime o expande los
## valores cercanos a 0 según el exponente recibido (ver EXPONENTE_RELIEVE más
## arriba para el efecto real usado por altura_en()), preservando siempre el
## signo y los extremos exactos (-1, 0, 1). Función estática pura (sin
## depender de _ruido) para poder probarla con valores conocidos.
static func _redistribuir(valor: float, exponente: float) -> float:
	return sign(valor) * pow(abs(valor), exponente)


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


## Altura correspondiente al percentil PERCENTIL_NIVEL_MAR de la
## distribución real de altura_en() sobre el grid (ancho_mundo x
## largo_mundo) — ver nivel_mar.
## Usa un histograma (solo hay ALTURA_MAXIMA - ALTURA_MINIMA + 1 = 16
## alturas enteras posibles, así que es barato) en vez de indexar un array
## ordenado por posición ordinal: con solo 16 alturas posibles, el índice
## objetivo (int(total * PERCENTIL_NIVEL_MAR)) casi nunca cae justo en el
## borde de un grupo de alturas — recorremos las alturas en orden ascendente
## y, en el grupo donde cae el objetivo, elegimos la altura h cuyo conteo
## ACUMULADO de alturas < h (antes o después de sumar el grupo de esa
## altura) queda más cerca del índice objetivo — así nivel_mar aproxima el
## percentil real en vez de quedar atado a cualquier lado del grupo.
func _calcular_nivel_mar(ancho_mundo: int, largo_mundo: int) -> int:
	var conteo_por_altura: Array = []
	conteo_por_altura.resize(ALTURA_MAXIMA - ALTURA_MINIMA + 1)
	conteo_por_altura.fill(0)
	var total := 0
	for x in range(ancho_mundo):
		for z in range(largo_mundo):
			var h: int = altura_en(x, z)
			conteo_por_altura[h - ALTURA_MINIMA] += 1
			total += 1

	var objetivo: int = int(total * PERCENTIL_NIVEL_MAR)
	var acumulado := 0
	for h in range(ALTURA_MINIMA, ALTURA_MAXIMA + 1):
		if acumulado >= objetivo:
			return h
		var siguiente: int = acumulado + conteo_por_altura[h - ALTURA_MINIMA]
		if siguiente >= objetivo:
			if objetivo - acumulado <= siguiente - objetivo:
				return h
			acumulado = siguiente
			continue
		acumulado = siguiente
	return ALTURA_MAXIMA


## Verdadero si la columna (x, z) queda por debajo del nivel de mar. Usada
## por VoxelWorld para rellenar de agua (ver Task 4), y pensada para que
## sub-proyectos futuros (adyacencia de puestos de caza/pesca, obstáculos
## para puentes de PoC 9) la consulten sin repetir este cálculo.
func es_agua_en(x: int, z: int) -> bool:
	return altura_en(x, z) < nivel_mar


## Verdadero si la columna (x, z) es tierra firme dentro de la banda de
## bioma (vegetación/fauna) sobre el nivel del mar — falso si es agua o si
## está por encima de esa banda (cumbres estériles). Único tipo de bioma
## por ahora (sin distinguir bosque/pradera/montaña); ver
## densidad_fauna_en()/densidad_frutal_en() para las señales que dependen
## de este criterio.
func es_bioma_en(x: int, z: int) -> bool:
	if es_agua_en(x, z):
		return false
	return altura_en(x, z) <= nivel_mar + BANDA_BIOMA


## Densidad de fauna en la columna (x, z), en [0, 1] — 0.0 si la columna no
## es bioma (ver es_bioma_en()). Un sistema futuro multiplicará esta
## fracción por área para decidir cuántos NPCs de fauna generar; no tiene
## efecto de bloque ni visual todavía.
func densidad_fauna_en(x: int, z: int) -> float:
	if not es_bioma_en(x, z):
		return 0.0
	var valor: float = _ruido_fauna.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0


## Densidad de recursos "frutal" en la columna (x, z), en [0, 1] — 0.0 si la
## columna no es bioma (ver es_bioma_en()). Un sistema futuro multiplicará
## esta fracción por área para decidir cuántos objetos "frutal" generar; no
## tiene efecto de bloque ni visual todavía.
func densidad_frutal_en(x: int, z: int) -> float:
	if not es_bioma_en(x, z):
		return 0.0
	var valor: float = _ruido_frutal.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0
