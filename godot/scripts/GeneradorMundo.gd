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

## Cuántas unidades de altura de ruido de detalle (alta frecuencia,
## _ruido_detalle) se suman cerca de los picos/cuencas — bug real, encontrado
## jugando en vivo: un EXPONENTE_RELIEVE bajo aplana grandes áreas de
## terreno a la misma altura entera cerca de los extremos (mesetas en vez de
## picos, ver el comentario de _altura_flotante()). El detalle se escala por
## qué tan cerca está la celda de un extremo (abs(valor_redistribuido), cerca
## de 1 en picos/cuencas, cerca de 0 en pendientes medias), así que rompe la
## meseta sin desordenar el relieve general en las laderas. Valor inicial
## calibrado empíricamente, mismo patrón que las demás constantes de este
## archivo — ajustar si los picos resultan demasiado ruidosos o siguen
## pareciendo mesetas.
const AMPLITUD_DETALLE_RELIEVE := 3.0

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
var _ruido_arbol: FastNoiseLite
var _ruido_detalle: FastNoiseLite


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

	# Semilla derivada distinta de _ruido, _ruido_mineral (semilla+1),
	# _ruido_fauna (semilla+2) y _ruido_frutal (semilla+3) — igual de
	# determinista: misma semilla de entrada, misma densidad de árboles
	# siempre.
	_ruido_arbol = FastNoiseLite.new()
	_ruido_arbol.seed = semilla + 4
	_ruido_arbol.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_arbol.frequency = 0.05

	# Semilla derivada distinta de todas las anteriores (semilla+5 ya la usa
	# el RandomNumberGenerator de _generar_rios(), no otro FastNoiseLite —
	# sin colisión real, pero se salta igual por claridad). Alta frecuencia
	# a propósito: ver AMPLITUD_DETALLE_RELIEVE, rompe las "mesetas" que
	# EXPONENTE_RELIEVE produce cerca de picos/cuencas.
	_ruido_detalle = FastNoiseLite.new()
	_ruido_detalle.seed = semilla + 6
	_ruido_detalle.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_detalle.frequency = 0.1

	nivel_mar = _calcular_nivel_mar(ancho_mundo, largo_mundo)
	_generar_rios(semilla, ancho_mundo, largo_mundo)


## Altura de la superficie en (x, z), determinista para (semilla, x, z).
## get_noise_2d() devuelve un valor en [-1, 1]; se remapea linealmente a
## [ALTURA_MINIMA, ALTURA_MAXIMA] y se redondea a entero.
func altura_en(x: int, z: int) -> int:
	return clampi(roundi(_altura_flotante(x, z)), ALTURA_MINIMA, ALTURA_MAXIMA)


## Misma altura que altura_en(), sin redondear a entero — ver _trazar_rio():
## el trazado de ríos por descenso de gradiente necesita esta versión
## continua, no la entera. Con solo 16 alturas enteras posibles en un mundo
## de 200x200, comparar altura_en() (entero) entre vecinos deja la mayor
## parte del relieve como "mesetas" artificiales de igual altura entera —
## el descenso por gradiente se atascaba casi de inmediato (bug real,
## encontrado jugando: los 6 ríos del mundo real quedaban en 1-2 celdas de
## longitud, sin llegar nunca al mar). Comparando la altura continua en vez
## de la entera, el descenso solo se detiene en un mínimo local real del
## ruido, no en un artefacto de la cuantización a 16 niveles.
func _altura_flotante(x: int, z: int) -> float:
	var valor: float = _ruido.get_noise_2d(x, z)
	var valor_redistribuido: float = _redistribuir(valor, EXPONENTE_RELIEVE)
	var t: float = (valor_redistribuido + 1.0) / 2.0
	var altura_base: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)

	# Detalle de alta frecuencia (ver AMPLITUD_DETALLE_RELIEVE) escalado por
	# qué tan cerca está esta celda de un extremo del relieve — rompe las
	# mesetas cerca de picos/cuencas sin afectar mucho las pendientes medias.
	var detalle: float = _ruido_detalle.get_noise_2d(x, z)
	var factor_extremo: float = abs(valor_redistribuido)
	return altura_base + detalle * AMPLITUD_DETALLE_RELIEVE * factor_extremo


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
## para puentes de PoC 10) la consulten sin repetir este cálculo.
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


## Densidad de árboles en la columna (x, z), en [0, 1] — 0.0 si la columna
## no es bioma (ver es_bioma_en()). VoxelWorld._generar_arboles() coloca un
## árbol real donde esta densidad supera un umbral (ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md).
func densidad_arbol_en(x: int, z: int) -> float:
	if not es_bioma_en(x, z):
		return 0.0
	var valor: float = _ruido_arbol.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0


## Cuántas nacientes de río se generan por mundo (Sección 1 del spec) —
## constante ajustable como UMBRAL_HIERRO/EXPONENTE_RELIEVE.
const NUM_RIOS := 6

## Una columna es candidata a naciente de río si su altura está a lo sumo
## esta distancia por debajo de ALTURA_MAXIMA (Sección 1). Subido de 3 a 6
## (decisión tomada jugando en vivo): con margen 3 (altura >= 12) solo
## calificaban las cumbres más altas del mundo; con 6 (altura >= 9) también
## nacen ríos de colinas medias, no solo picos. Subido después a 10
## (altura >= 5) para ampliar aún más el rango de colinas que pueden dar
## nacimiento a un río.
const MARGEN_NACIENTE_RIO := 10

## Distancia mínima en línea recta (celdas) entre dos nacientes elegidas —
## evita que varios de los NUM_RIOS ríos nazcan todos de la misma montaña
## (decisión tomada jugando en vivo, junto con MARGEN_NACIENTE_RIO arriba).
## Se aplica como filtro tras cada elección (Sección 1): las candidatas
## demasiado cerca de la naciente recién elegida quedan fuera del resto del
## sorteo. Si el terreno alto está muy concentrado, esto puede dejar menos
## de NUM_RIOS nacientes disponibles — _generar_rios() simplemente genera
## los que alcancen, no es un error.
const MIN_DISTANCIA_NACIENTES := 20

const ANCHO_MINIMO_RIO := 2
const ANCHO_MAXIMO_RIO := 6

## Profundidad máxima tallada en el centro de un río, sin importar cuánto
## crezca el ancho (Sección 3) — un río de ancho 6 no talla más hondo que
## uno de ancho 5, según la fórmula de _profundidad_en_franja().
const PROFUNDIDAD_MAXIMA_RIO := 3

## Caída de altura mínima entre dos celdas consecutivas del cauce para
## marcar ese paso como cascada (Sección 5, es_cascada_en()).
const UMBRAL_CASCADA := 3

## (x,z) -> profundidad tallada (1..PROFUNDIDAD_MAXIMA_RIO). Solo contiene
## celdas que son parte de la franja de algún río — ver es_rio_en().
var _profundidad_rio: Dictionary = {}  # Vector2i -> int

## (x,z) -> dirección unitaria hacia la siguiente celda del cauce — ver
## direccion_flujo_en().
var _direccion_flujo_rio: Dictionary = {}  # Vector2i -> Vector2i

## (x,z) marcadas como cascada — ver es_cascada_en().
var _celdas_cascada: Dictionary = {}  # Vector2i -> true


## Dirección de avance para la franja del paso "i" de "cauce" (Sección 3):
## vector unitario entre la celda anterior y la actual; para la naciente
## (i=0, sin "anterior"), entre la naciente y su primer paso.
## Vector2i.ZERO si "cauce" tiene un único elemento (sin dirección
## definible — caso degenerado de una naciente sin ningún paso siguiente).
static func _direccion_avance_en(cauce: Array[Vector2i], i: int) -> Vector2i:
	if i == 0:
		if cauce.size() > 1:
			return cauce[1] - cauce[0]
		return Vector2i.ZERO
	return cauce[i] - cauce[i - 1]


## Celdas de la franja perpendicular al avance en el paso "i" de "cauce"
## (Sección 3): "ancho" celdas consecutivas centradas aproximadamente en
## cauce[i] (para ancho impar, cauce[i] cae exactamente en el centro).
## Función pura de geometría — no consulta altura ni agua; quien la use
## filtra después qué celdas de la franja son válidas.
static func _celdas_franja_en(cauce: Array[Vector2i], i: int, ancho: int) -> Array[Vector2i]:
	var avance: Vector2i = _direccion_avance_en(cauce, i)
	if avance == Vector2i.ZERO:
		return [cauce[i]]
	var perpendicular: Vector2i = Vector2i(0, 1) if avance.x != 0 else Vector2i(1, 0)
	@warning_ignore("integer_division")
	var desde: int = -(ancho / 2)
	var celdas: Array[Vector2i] = []
	for k in range(ancho):
		celdas.append(cauce[i] + perpendicular * (desde + k))
	return celdas


## Profundidad tallada en la posición "indice" (0-based) de una franja de
## "ancho" celdas (Sección 3): borde = 1, sube hacia el centro hasta
## PROFUNDIDAD_MAXIMA_RIO. Fórmula pura: ancho 2 -> [1,1]; ancho 3 ->
## [1,2,1]; ancho 5 -> [1,2,3,2,1]; ancho 6 -> [1,2,3,3,2,1].
static func _profundidad_en_franja(indice: int, ancho: int) -> int:
	return mini(mini(indice, ancho - 1 - indice) + 1, PROFUNDIDAD_MAXIMA_RIO)


## Compara la "fuerza" de dos ríos para _resolver_cruces() (Sección 2b):
## mayor ancho gana; en empate, mayor altura de nacimiento; en empate
## total, el río generado primero (menor índice). true si "a" es más
## fuerte que "b" — da un orden total estricto, sin empates posibles.
static func _es_mas_fuerte(a: Dictionary, b: Dictionary) -> bool:
	if a["ancho"] != b["ancho"]:
		return a["ancho"] > b["ancho"]
	if a["altura_nacimiento"] != b["altura_nacimiento"]:
		return a["altura_nacimiento"] > b["altura_nacimiento"]
	return a["indice"] < b["indice"]


## Resuelve cruces entre los cauces crudos de "rios" (Sección 2b): agrega a
## cada Dictionary la clave "cauce_truncado" (Array[Vector2i]) — el
## prefijo de su "cauce_crudo" hasta la última celda de la que sigue
## siendo dueño (la primera celda ya reclamada por un río más fuerte corta
## el cauce ahí, sin incluirla). Cada Dictionary de "rios" debe traer
## "indice", "ancho", "altura_nacimiento" y "cauce_crudo". Pura sobre los
## datos recibidos — no consulta altura ni agua reales, así se puede
## probar con cauces sintéticos.
static func _resolver_cruces(rios: Array[Dictionary]) -> void:
	var orden_fuerza: Array[Dictionary] = rios.duplicate()
	orden_fuerza.sort_custom(_es_mas_fuerte)

	var dueño: Dictionary = {}  # Vector2i -> int (índice de río)
	for rio in orden_fuerza:
		for celda: Vector2i in rio["cauce_crudo"]:
			if not dueño.has(celda):
				dueño[celda] = rio["indice"]

	for rio in rios:
		var truncado: Array[Vector2i] = []
		for celda: Vector2i in rio["cauce_crudo"]:
			if dueño[celda] != rio["indice"]:
				break
			truncado.append(celda)
		rio["cauce_truncado"] = truncado

## Traza el cauce crudo desde "origen" por descenso por gradiente (Sección
## 2 del spec): en cada paso se mueve a la vecina ortogonal (N/E/S/O, en
## ese orden de desempate) no visitada de menor altura; termina al entrar
## a una celda de agua ya existente (se incluye como último elemento) o si
## ninguna vecina es más baja (mesa/valle cerrado — se conserva el cauce
## parcial, no es un error). Un tope de pasos evita recorridos patológicos
## en mesetas totalmente planas.
func _trazar_rio(origen: Vector2i, ancho_mundo: int, largo_mundo: int) -> Array[Vector2i]:
	var cauce: Array[Vector2i] = [origen]
	var visitadas: Dictionary = {origen: true}
	var actual: Vector2i = origen
	var max_pasos: int = ancho_mundo + largo_mundo
	for _paso in range(max_pasos):
		if es_agua_en(actual.x, actual.y):
			break
		var vecinos: Array[Vector2i] = [
			actual + Vector2i(0, -1),
			actual + Vector2i(1, 0),
			actual + Vector2i(0, 1),
			actual + Vector2i(-1, 0),
		]
		var mejor: Vector2i = actual
		var mejor_altura: float = _altura_flotante(actual.x, actual.y)
		for vecino in vecinos:
			if vecino.x < 0 or vecino.x >= ancho_mundo or vecino.y < 0 or vecino.y >= largo_mundo:
				continue
			if visitadas.has(vecino):
				continue
			var h: float = _altura_flotante(vecino.x, vecino.y)
			if h < mejor_altura:
				mejor_altura = h
				mejor = vecino
		if mejor == actual:
			break
		visitadas[mejor] = true
		cauce.append(mejor)
		actual = mejor
	return cauce


## Talla ancho/profundidad reales sobre "cauce" (ya truncado por
## _resolver_cruces(), Sección 2b) — llena _profundidad_rio/
## _direccion_flujo_rio para cada celda de la franja de cada paso,
## saltando celdas ya bajo el mar/lago, fuera del mundo, o ya reclamadas
## por otro río procesado antes (Sección 3).
func _aplicar_ancho_profundidad(cauce: Array[Vector2i], ancho: int, ancho_mundo: int, largo_mundo: int) -> void:
	for i in range(cauce.size()):
		var celda: Vector2i = cauce[i]
		if es_agua_en(celda.x, celda.y):
			continue
		var franja: Array[Vector2i] = _celdas_franja_en(cauce, i, ancho)
		var direccion_publica: Vector2i = cauce[i + 1] - cauce[i] if i + 1 < cauce.size() else Vector2i.ZERO
		for k in range(franja.size()):
			var celda_franja: Vector2i = franja[k]
			if celda_franja.x < 0 or celda_franja.x >= ancho_mundo or celda_franja.y < 0 or celda_franja.y >= largo_mundo:
				continue
			if es_agua_en(celda_franja.x, celda_franja.y):
				continue
			if _profundidad_rio.has(celda_franja):
				continue
			_profundidad_rio[celda_franja] = _profundidad_en_franja(k, ancho)
			_direccion_flujo_rio[celda_franja] = direccion_publica


## Marca cascadas (es_cascada_en) sobre "cauce" (ya truncado): cualquier
## paso cuya caída de altura hacia la siguiente celda sea >= UMBRAL_CASCADA
## marca TODA su franja como cascada (Sección 5). Debe llamarse DESPUÉS de
## _aplicar_ancho_profundidad() sobre el mismo "cauce" (ver _generar_rios()):
## solo marca cascada una celda de franja que _aplicar_ancho_profundidad()
## ya haya registrado en _profundidad_rio para ESTE río — así una celda bajo
## agua o ya reclamada por otro río (más fuerte, procesado antes) nunca
## puede quedar marcada como cascada sin ser también río (es_cascada_en =>
## es_rio_en, ver TEST 25/TEST 26b).
func _marcar_cascadas(cauce: Array[Vector2i], ancho: int, ancho_mundo: int, largo_mundo: int) -> void:
	for i in range(cauce.size() - 1):
		var actual: Vector2i = cauce[i]
		if es_agua_en(actual.x, actual.y):
			continue
		var siguiente: Vector2i = cauce[i + 1]
		var caida: int = altura_en(actual.x, actual.y) - altura_en(siguiente.x, siguiente.y)
		if caida < UMBRAL_CASCADA:
			continue
		for celda_franja in _celdas_franja_en(cauce, i, ancho):
			if celda_franja.x < 0 or celda_franja.x >= ancho_mundo or celda_franja.y < 0 or celda_franja.y >= largo_mundo:
				continue
			if es_agua_en(celda_franja.x, celda_franja.y):
				continue
			if not _profundidad_rio.has(celda_franja):
				continue
			_celdas_cascada[celda_franja] = true


## Genera todos los ríos del mundo (Secciones 1-5 del spec): elige
## nacientes con un RandomNumberGenerator sembrado (semilla+5, siguiente
## hueco libre tras _ruido_arbol en semilla+4), traza su cauce crudo,
## resuelve cruces, y talla ancho/profundidad + cascadas sobre el cauce ya
## truncado de cada uno. Llamada una única vez desde _init(), después de
## calcular nivel_mar (los cauces necesitan es_agua_en() para saber dónde
## terminan).
## Agrupa "celdas" (candidatas a naciente, ya filtradas por altura) en
## regiones conectadas por 4-vecindad — cada región es una montaña/colina
## separada de las demás por terreno bajo el umbral. Pura función de
## geometría de conjuntos (sin consultar altura) — testable con celdas
## sintéticas, sin necesitar un generador real.
static func _agrupar_regiones_elevadas(celdas: Array[Vector2i]) -> Array:
	var pertenece: Dictionary = {}  # Vector2i -> true, lookup O(1)
	for c in celdas:
		pertenece[c] = true
	var visitadas: Dictionary = {}
	var regiones: Array = []  # Array[Array[Vector2i]]
	for inicio in celdas:
		if visitadas.has(inicio):
			continue
		var region: Array[Vector2i] = []
		var pila: Array[Vector2i] = [inicio]
		visitadas[inicio] = true
		while not pila.is_empty():
			var actual: Vector2i = pila.pop_back()
			region.append(actual)
			for delta in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var vecino: Vector2i = actual + delta
				if pertenece.has(vecino) and not visitadas.has(vecino):
					visitadas[vecino] = true
					pila.append(vecino)
		regiones.append(region)
	return regiones


## Punto representativo de "region" para elegir como naciente (Sección 1):
## el punto real más cercano al centro geométrico de las celdas que
## comparten la altura MÁXIMA de la región (la cumbre, no toda la ladera) —
## así el naciente sale cerca del centro de la parte más alta de la
## montaña, no de cualquier borde que apenas cruce el umbral de altura.
func _representante_de_region(region: Array[Vector2i]) -> Vector2i:
	var max_altura: int = altura_en(region[0].x, region[0].y)
	for celda in region:
		var h: int = altura_en(celda.x, celda.y)
		if h > max_altura:
			max_altura = h
	var cumbre: Array[Vector2i] = []
	for celda in region:
		if altura_en(celda.x, celda.y) == max_altura:
			cumbre.append(celda)
	var suma_x := 0
	var suma_z := 0
	for celda in cumbre:
		suma_x += celda.x
		suma_z += celda.y
	var centro := Vector2(float(suma_x) / cumbre.size(), float(suma_z) / cumbre.size())
	var mejor: Vector2i = cumbre[0]
	var mejor_distancia: float = Vector2(mejor.x, mejor.y).distance_to(centro)
	for celda in cumbre:
		var d: float = Vector2(celda.x, celda.y).distance_to(centro)
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = celda
	return mejor


func _generar_rios(semilla: int, ancho_mundo: int, largo_mundo: int) -> void:
	var candidatos_brutos: Array[Vector2i] = []
	for x in range(ancho_mundo):
		for z in range(largo_mundo):
			if altura_en(x, z) >= ALTURA_MAXIMA - MARGEN_NACIENTE_RIO:
				candidatos_brutos.append(Vector2i(x, z))
	if candidatos_brutos.is_empty():
		return

	# Una candidata por región elevada conectada (una montaña/colina), no una
	# por celda — decisión tomada jugando en vivo: elegir cualquier celda que
	# cruce el umbral de altura por igual dejaba nacer ríos en el borde de
	# una elevación, no cerca de su cumbre. _representante_de_region() elige
	# el punto real más cercano al centro de la parte más alta de esa región.
	var regiones: Array = _agrupar_regiones_elevadas(candidatos_brutos)
	var candidatos: Array[Vector2i] = []
	for region in regiones:
		candidatos.append(_representante_de_region(region))

	var rng := RandomNumberGenerator.new()
	rng.seed = semilla + 5

	var rios: Array[Dictionary] = []
	for i in range(NUM_RIOS):
		if candidatos.is_empty():
			break
		var idx: int = rng.randi() % candidatos.size()
		var origen: Vector2i = candidatos[idx]
		candidatos.remove_at(idx)
		var ancho: int = rng.randi_range(ANCHO_MINIMO_RIO, ANCHO_MAXIMO_RIO)
		rios.append({
			"indice": i,
			"origen": origen,
			"ancho": ancho,
			"altura_nacimiento": altura_en(origen.x, origen.y),
			"cauce_crudo": _trazar_rio(origen, ancho_mundo, largo_mundo),
		})
		# Filtrar candidatas demasiado cerca de la naciente recién elegida
		# (MIN_DISTANCIA_NACIENTES) — no consume el RNG, así que no afecta el
		# determinismo de los sorteos siguientes.
		var candidatos_lejanos: Array[Vector2i] = []
		for c in candidatos:
			if Vector2(c.x - origen.x, c.y - origen.y).length() >= MIN_DISTANCIA_NACIENTES:
				candidatos_lejanos.append(c)
		candidatos = candidatos_lejanos

	_resolver_cruces(rios)

	for rio in rios:
		var truncado: Array[Vector2i] = rio["cauce_truncado"]
		if truncado.size() < 2:
			continue
		# Un cauce que no llega a desembocar en agua (mesa/valle cerrado, o
		# truncado antes de llegar por un cruce con un río más fuerte) se
		# descarta por completo — decisión tomada jugando en vivo: un cauce
		# suelto que no conecta con nada se ve como un error visual, no como
		# un arroyo real que se pierde en un valle. "Llegar a agua" se mide
		# sobre el cauce YA truncado (la última celda que le queda), no sobre
		# el cauce crudo original.
		var ultima_truncada: Vector2i = truncado[truncado.size() - 1]
		if not es_agua_en(ultima_truncada.x, ultima_truncada.y):
			continue
		_aplicar_ancho_profundidad(truncado, rio["ancho"], ancho_mundo, largo_mundo)
		_marcar_cascadas(truncado, rio["ancho"], ancho_mundo, largo_mundo)


## Verdadero si (x,z) cae dentro de la franja de algún río (Sección 5).
func es_rio_en(x: int, z: int) -> bool:
	return _profundidad_rio.has(Vector2i(x, z))


## Dirección unitaria hacia la siguiente celda del cauce en (x,z), o
## Vector2i.ZERO si no es río o es la celda final (Sección 5).
func direccion_flujo_en(x: int, z: int) -> Vector2i:
	return _direccion_flujo_rio.get(Vector2i(x, z), Vector2i.ZERO)


## Profundidad tallada en (x,z) — 0 si no es río (Sección 5).
func profundidad_rio_en(x: int, z: int) -> int:
	return _profundidad_rio.get(Vector2i(x, z), 0)


## Verdadero si (x,z) es parte de una cascada (Sección 5).
func es_cascada_en(x: int, z: int) -> bool:
	return _celdas_cascada.has(Vector2i(x, z))
