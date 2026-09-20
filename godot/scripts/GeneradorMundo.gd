extends RefCounted

## Generación pura del mapa de alturas del mundo — sin nodos de escena, sin
## GridMap. Ver spec: docs/superpowers/specs/2026-09-07-mundo-procedural-design.md,
## docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md (vetas
## de hierro). Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd:
## evitar el bug de caché de clases globales de Godot) — se usa vía preload().new().

const ALTURA_MINIMA := 0
const ALTURA_MAXIMA := 130
const GROSOR_TIERRA := 4

## Umbral de get_noise_3d() (rango [-1, 1]) por encima del cual una celda de
## piedra se convierte en hierro — ver tipo_en_profundidad(). El rango teórico
## es [-1, 1], pero para esta semilla/frecuencia el rango observado de
## get_noise_3d() no se acerca a esos extremos (tope real ~0.37-0.4) — un
## umbral de 0.55 (o incluso 0.4) nunca se alcanza y nunca produciría hierro.
## Recalibrado empíricamente a 0.2, que sigue dejando al hierro como clara
## minoría frente a la piedra en la capa profunda.
const UMBRAL_HIERRO := 0.2

## Profundidad mínima bajo superficie (profundidad_bajo_superficie) y umbral
## de _ruido_mineral.get_noise_3d() para carbón, cobre y tierras raras — ver
## tipo_en_profundidad(). Comparten el mismo campo de ruido que hierro (no uno
## nuevo por mineral): lo que cambia es a partir de qué profundidad empieza a
## poder aparecer cada uno y qué tan alto debe ser el ruido en esa celda.
## Concentración pedida por el usuario, de más común a más rara: carbón >
## cobre > hierro > tierras_raras (umbral creciente); profundidad creciente
## en el mismo orden para que una mina nivel 1 (alcance
## Recoleccion.PROFUNDIDAD_MINA_NIVEL_1 = 8) apenas roce el borde superior de
## la veta de hierro y nunca llegue a tierras raras, nivel 2 (alcance 16)
## cubra bien hierro y roce tierras raras, y nivel 3 (alcance 24) cubra bien
## tierras raras.
const PROFUNDIDAD_CARBON := GROSOR_TIERRA
const UMBRAL_CARBON := -0.1
const PROFUNDIDAD_COBRE := 6
## Subido de 0.0 a 0.12 (2026-09-17): con 0.0 el cobre salía visiblemente en
## exceso jugando en vivo — sigue estrictamente entre UMBRAL_CARBON (-0.1) y
## UMBRAL_HIERRO (0.2), conservando el orden de rareza carbón > cobre > hierro
## > tierras_raras pedido por el usuario, solo que más cerca de hierro.
const UMBRAL_COBRE := 0.12
## Profundidad mínima de hierro — antes el hierro no tenía piso propio (solo
## GROSOR_TIERRA), pero para que una mina nivel 1 (alcance 8) apenas roce el
## borde de la veta necesita empezar justo en ese alcance, no en la
## superficie del subsuelo.
const PROFUNDIDAD_HIERRO := 8
const PROFUNDIDAD_TIERRAS_RARAS := 16
const UMBRAL_TIERRAS_RARAS := 0.3

## Umbral de _ruido_bosque.get_noise_2d() (rango [-1, 1]) por encima del cual
## una columna cae dentro de una zona de bosque real — ver densidad_arbol_en().
## 0.0 da ~50% de cobertura de zona (la mitad del bioma es "bosque posible"),
## dejando que UMBRAL_ARBOL (VoxelWorld.gd) recorte más adentro de cada zona
## — calibrado empíricamente junto con la frecuencia de _ruido_bosque, mismo
## patrón que las demás constantes de este archivo.
const UMBRAL_ZONA_BOSQUE := 0.0

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

## Cuántas unidades de altura aporta _ruido_medio (frecuencia intermedia,
## ver _init()) — a diferencia de AMPLITUD_DETALLE_RELIEVE, esta se suma en
## TODO punto del mapa, no solo cerca de picos/cuencas. Dio colinas/valles
## reales para ríos/bioma (ver PoC_6 3.16), pero con amplitud alta (30) hacía
## que TODO el mapa se sintiera "ocupado" de relieve — el usuario pidió
## explícitamente pocas montañas puntuales y el resto llano/colinas suaves
## (ver PoC_6 3.17-3.18), así que esta capa ahora es solo la textura suave
## de la llanura — la altura "dramática" viene de _altura_montana() (picos
## explícitos), no de esto. Bajada de 30 a 10 en consecuencia.
const AMPLITUD_MEDIA_RELIEVE := 10.0

## Techo de altura del terreno "base" (llanura/colinas suaves, sin contar
## montañas) — ver _altura_flotante()/_altura_montana(). El resto de la
## altura hasta ALTURA_MAXIMA solo lo alcanzan las MONTANAS_PICOS. Valor
## inicial calibrado empíricamente (2026-09-17, PoC_6 3.18): bajo frente a
## ALTURA_MAXIMA a propósito, para que el mapa se sienta mayormente llano.
const ALTURA_BASE_MAXIMA := 30.0

## Cuántos picos de montaña explícitos genera el mundo — ver
## _generar_picos_montana()/_altura_montana(). El usuario pidió "una o dos
## montañas altas" en vez de relieve accidentado por todo el mapa (2026-09-17,
## PoC_6 3.18, con captura real de un mundo demasiado "ocupado" de picos).
const NUM_MONTANAS := 2

## Radio (en celdas) dentro del cual un pico de montaña influye en la altura
## — fuera de este radio, la altura vuelve a depender solo del terreno base
## (llanura/colinas). Sorteado por pico entre estos dos valores, para que no
## todas las montañas tengan exactamente el mismo tamaño.
const RADIO_MONTANA_MIN := 45.0
const RADIO_MONTANA_MAX := 70.0

## Distancia mínima al borde del mundo para el centro de un pico de montaña
## — evita montañas cortadas a la mitad por el borde del mapa.
const MARGEN_BORDE_MONTANA := 35

## Percentil (sobre la distribución real de altura_en() en todo el grid) que
## define nivel_mar — ver _calcular_nivel_mar(). Fijo por ahora; en un
## desarrollo futuro dependerá del "tipo de mundo" elegido (archipiélago,
## continental, etc.) — ver spec docs/superpowers/specs/2026-09-08-cuerpos-de-agua-design.md.
const PERCENTIL_NIVEL_MAR := 0.15

## Cuántas unidades de altura por encima de nivel_mar sigue habiendo bioma
## (vegetación/fauna) antes de volverse tierra estéril — ver es_bioma_en().
## Valor inicial calibrado empíricamente, mismo patrón que GROSOR_TIERRA/
## UMBRAL_HIERRO/EXPONENTE_RELIEVE: ajustar aquí si en el editor real la
## banda resulta demasiado angosta o demasiado ancha. Escalada de 4 a 34
## (2026-09-16, proporcional al aumento de ALTURA_MAXIMA de 15 a 130, mismo
## criterio que MARGEN_NACIENTE_RIO) — sin reescalar, 4 unidades sobre un
## rango de 130 dejaba el bioma como una franja angosta pegada a la costa
## (18% del mapa, confirmado jugando en vivo con captura real), obligando de
## facto a construir cerca del mar.
const BANDA_BIOMA := 34

## Altura por debajo de la cual una columna se considera inundada (ver
## es_agua_en()). Calculada una vez en _init() a partir de
## PERCENTIL_NIVEL_MAR sobre la distribución real del grid (ancho_mundo x
## largo_mundo) — no es un valor fijo, para ser robusta a cambios de
## semilla, frecuencia de ruido o EXPONENTE_RELIEVE.
var nivel_mar: int

## Picos de montaña generados una vez en _init() — ver
## _generar_picos_montana()/_altura_montana(). Cada entrada es
## {"pos": Vector2, "radio": float}.
var _picos_montana: Array[Dictionary] = []

## Semilla del mundo, guardada para sembrar el RNG propio de cada
## _trazar_rio() (ver ahí) — determinista por (semilla, origen), sin
## compartir estado con el RNG de _generar_rios() (semilla+5).
var _semilla: int

var _ruido: FastNoiseLite
var _ruido_medio: FastNoiseLite
var _ruido_mineral: FastNoiseLite
var _ruido_fauna: FastNoiseLite
var _ruido_frutal: FastNoiseLite
var _ruido_arbol: FastNoiseLite
var _ruido_bosque: FastNoiseLite
var _ruido_detalle: FastNoiseLite
var _ruido_peces: FastNoiseLite


func _init(semilla: int, ancho_mundo: int, largo_mundo: int) -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_PERLIN
	# Escalada a la baja junto con ALTURA_MAXIMA (era 0.02 cuando ALTURA_MAXIMA
	# era 15): la misma frecuencia con un rango de salida 8.7x mayor daba
	# pendientes casi verticales (picos injugables, confirmado jugando en
	# vivo) — bajar la frecuencia estira la longitud de onda en la misma
	# proporción, para que el mismo relieve "se sienta" igual de suave.
	_ruido.frequency = 0.0023

	# Frecuencia intermedia entre _ruido (0.0023) y _ruido_detalle (0.1) — ver
	# AMPLITUD_MEDIA_RELIEVE: da colinas/valles reales de ~25 celdas de ancho
	# en TODO el mapa (no solo cerca de extremos), para que haya suficientes
	# cuencas de drenaje/variación de altura en el interior. Calibrada
	# empíricamente junto con AMPLITUD_MEDIA_RELIEVE: frecuencias más bajas
	# (menos colinas, más anchas) fusionaban las regiones candidatas a
	# naciente de río en un solo bloque conectado gigante (peor que sin esta
	# capa — de 4 ríos reales bajó a 0); esta combinación dio 6 ríos reales
	# (el objetivo de NUM_RIOS) con la semilla real del mundo, sin superar
	# una pendiente máxima de 8 bloques/celda.
	_ruido_medio = FastNoiseLite.new()
	_ruido_medio.seed = semilla + 8
	_ruido_medio.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_medio.frequency = 0.03

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

	# Semilla derivada distinta de _ruido, _ruido_mineral (+1), _ruido_fauna
	# (+2), _ruido_frutal (+3), _ruido_arbol (+4), el RNG de _generar_rios()
	# (+5), _ruido_detalle (+6) y _ruido_medio (+8, ver más arriba) —
	# siguiente offset libre.
	_ruido_peces = FastNoiseLite.new()
	_ruido_peces.seed = semilla + 7
	_ruido_peces.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_peces.frequency = 0.05

	# Frecuencia baja a propósito — ver UMBRAL_ZONA_BOSQUE/densidad_arbol_en():
	# define parches de bosque real (2026-09-17, confirmado jugando en vivo
	# con captura real: sin esto, todo el bioma se veía como un solo bosque
	# continuo — ver PoC_6 3.17), no un solo umbral de densidad por celda
	# como fauna/frutal. Offset +9 (siguiente libre tras _ruido_medio, +8).
	_ruido_bosque = FastNoiseLite.new()
	_ruido_bosque.seed = semilla + 9
	_ruido_bosque.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_bosque.frequency = 0.015

	_semilla = semilla

	# Picos de montaña ANTES de nivel_mar: altura_en() (que nivel_mar necesita
	# muestrear en todo el grid) ya depende de _picos_montana.
	_generar_picos_montana(semilla, ancho_mundo, largo_mundo)
	nivel_mar = _calcular_nivel_mar(ancho_mundo, largo_mundo)
	_generar_rios(semilla, ancho_mundo, largo_mundo)


## Altura de la superficie en (x, z), determinista para (semilla, x, z).
## get_noise_2d() devuelve un valor en [-1, 1]; se remapea linealmente a
## [ALTURA_MINIMA, ALTURA_MAXIMA] y se redondea a entero.
func altura_en(x: int, z: int) -> int:
	return clampi(roundi(_altura_flotante(x, z)), ALTURA_MINIMA, ALTURA_MAXIMA)


## Misma altura que altura_en(), sin redondear a entero — ver _trazar_rio():
## el trazado de ríos por descenso de gradiente necesita esta versión
## continua, no la entera. Con relativamente pocas alturas enteras posibles
## (ALTURA_MAXIMA - ALTURA_MINIMA + 1; 16 cuando esto se descubrió, con el
## rango de relieve original de esta PoC), comparar altura_en() (entero)
## entre vecinos deja la mayor parte del relieve como "mesetas" artificiales
## de igual altura entera — el descenso por gradiente se atascaba casi de
## inmediato (bug real, encontrado jugando: los 6 ríos del mundo real
## quedaban en 1-2 celdas de longitud, sin llegar nunca al mar). Comparando
## la altura continua en vez de la entera, el descenso solo se detiene en un
## mínimo local real del ruido, no en un artefacto de la cuantización.
func _altura_flotante(x: int, z: int) -> float:
	var valor: float = _ruido.get_noise_2d(x, z)
	var valor_redistribuido: float = _redistribuir(valor, EXPONENTE_RELIEVE)
	var t: float = (valor_redistribuido + 1.0) / 2.0
	# Techo bajo a propósito (ALTURA_BASE_MAXIMA, no ALTURA_MAXIMA): esta es
	# la altura de la llanura/colinas suaves. La altura "dramática" hasta
	# ALTURA_MAXIMA solo la dan los picos de montaña explícitos (ver
	# _altura_montana() más abajo) — ver PoC_6 3.18.
	var altura_base: float = ALTURA_MINIMA + t * (ALTURA_BASE_MAXIMA - ALTURA_MINIMA)

	# Colinas/valles suaves de frecuencia intermedia (ver
	# AMPLITUD_MEDIA_RELIEVE) — se suma en TODO punto del mapa, no solo cerca
	# de extremos, para que el interior (ni montaña ni costa) tenga algo de
	# variación real de altura en vez de una llanura perfectamente lisa.
	var medio: float = _ruido_medio.get_noise_2d(x, z) * AMPLITUD_MEDIA_RELIEVE

	# Detalle de alta frecuencia (ver AMPLITUD_DETALLE_RELIEVE) escalado por
	# qué tan cerca está esta celda de un extremo del relieve BASE — rompe las
	# mesetas cerca de picos/cuencas de la llanura sin afectar mucho las
	# pendientes medias.
	var detalle: float = _ruido_detalle.get_noise_2d(x, z)
	var factor_extremo: float = abs(valor_redistribuido)

	return altura_base + medio + detalle * AMPLITUD_DETALLE_RELIEVE * factor_extremo + _altura_montana(x, z)


## Cuántas unidades de altura extra aporta la montaña más cercana en (x, z),
## por encima del terreno base — 0.0 si (x, z) cae fuera del radio de
## cualquier pico (ver _picos_montana/_generar_picos_montana()). Usa
## smoothstep (no una rampa lineal) para que la ladera se una al terreno
## base sin un quiebre visible en el borde del radio de influencia. Si dos
## radios se solapan, se usa el mayor de los dos (no se suman) — evita
## picos imposiblemente altos donde dos montañas se acercan.
func _altura_montana(x: int, z: int) -> float:
	var maximo := 0.0
	for pico in _picos_montana:
		var distancia: float = Vector2(x, z).distance_to(pico["pos"])
		var radio: float = pico["radio"]
		if distancia >= radio:
			continue
		var t: float = 1.0 - distancia / radio
		var factor: float = t * t * (3.0 - 2.0 * t)  # smoothstep
		maximo = maxf(maximo, factor * (ALTURA_MAXIMA - ALTURA_BASE_MAXIMA))
	return maximo


## Sortea NUM_MONTANAS posiciones/radios de pico, deterministas por semilla
## (RNG propio, offset +10 — siguiente libre tras _ruido_bosque, +9). Se
## llama una única vez desde _init(), antes de nivel_mar (que ya depende de
## altura_en(), y por lo tanto de estos picos).
func _generar_picos_montana(semilla: int, ancho_mundo: int, largo_mundo: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla + 10
	for i in range(NUM_MONTANAS):
		var x: float
		var z: float
		var radio: float
		# Hasta 20 intentos para que este pico no se solape con uno ya
		# colocado — dos radios que se tocan crean una "silla" entre ambas
		# cumbres (2026-09-17, PoC_6 3.18): un punto ahí queda con relieve
		# más alto en casi todas direcciones salvo una franja angosta, así
		# que _trazar_rio() se atasca en 1-2 pasos, sin importar
		# NUM_MONTANAS — confirmado midiendo el mundo real, no solo
		# observado. Si los 20 intentos fallan (mapa chico/muchas montañas),
		# se acepta el último intento igual — es mejor que un bucle infinito,
		# y un solape ocasional no rompe nada, solo reduce la chance de que
		# ese pico en particular dé un río real.
		for intento in range(20):
			x = rng.randf_range(MARGEN_BORDE_MONTANA, ancho_mundo - MARGEN_BORDE_MONTANA)
			z = rng.randf_range(MARGEN_BORDE_MONTANA, largo_mundo - MARGEN_BORDE_MONTANA)
			radio = rng.randf_range(RADIO_MONTANA_MIN, RADIO_MONTANA_MAX)
			var se_solapa := false
			for otro in _picos_montana:
				if Vector2(x, z).distance_to(otro["pos"]) < radio + otro["radio"]:
					se_solapa = true
					break
			if not se_solapa:
				break
		_picos_montana.append({"pos": Vector2(x, z), "radio": radio})


## Curva de potencia sign(x)*pow(abs(x), exponente): comprime o expande los
## valores cercanos a 0 según el exponente recibido (ver EXPONENTE_RELIEVE más
## arriba para el efecto real usado por altura_en()), preservando siempre el
## signo y los extremos exactos (-1, 0, 1). Función estática pura (sin
## depender de _ruido) para poder probarla con valores conocidos.
static func _redistribuir(valor: float, exponente: float) -> float:
	return sign(valor) * pow(abs(valor), exponente)


## Ancho de cauce (ANCHO_MINIMO_RIO..ANCHO_MAXIMO_RIO) para un río cuya
## naciente está a "altura", dentro de la banda [altura_min_naciente,
## altura_max_naciente] de MARGEN_NACIENTE_RIO — un río que nace más cerca
## de altura_max_naciente (más cerca de una cumbre real) da un cauce más
## ancho. Lineal a propósito (sin curva ni aleatoriedad extra): la banda de
## nacientes ya es angosta, así que una curva no marcaría una diferencia
## perceptible. Función estática pura, testable con valores conocidos.
static func _ancho_por_altura(altura: int, altura_min_naciente: int, altura_max_naciente: int) -> int:
	if altura_max_naciente <= altura_min_naciente:
		return ANCHO_MAXIMO_RIO
	var t: float = clampf(float(altura - altura_min_naciente) / float(altura_max_naciente - altura_min_naciente), 0.0, 1.0)
	return roundi(lerp(float(ANCHO_MINIMO_RIO), float(ANCHO_MAXIMO_RIO), t))


## Tipo de bloque de subsuelo en la columna/profundidad dados: "tierra" cerca
## de la superficie (por debajo de GROSOR_TIERRA), "piedra" más profundo, o
## "hierro"/"cobre"/"carbon"/"tierras_raras" si el ruido de vetas supera el
## umbral del mineral más profundo cuya PROFUNDIDAD_* ya se alcanzó (ver
## PROFUNDIDAD_CARBON/UMBRAL_CARBON y hermanas) — ningún mineral aparece en la
## capa de tierra, sin importar el ruido (el chequeo de profundidad corta
## antes de consultar _ruido_mineral). Se revisa de más profundo/raro a más
## superficial/común (tierras_raras, hierro, cobre, carbón) porque sus
## umbrales son crecientes en ese orden: una celda que supera el umbral de
## tierras_raras también supera el de carbón, así que hay que darle prioridad
## al mineral más raro antes de caer al más común. (x, y, z) son coordenadas
## absolutas del mundo (y = altura de superficie - profundidad_bajo_superficie)
## — necesarias para el ruido 3D, a diferencia de la versión anterior de esta
## función que solo dependía de la profundidad relativa.
func tipo_en_profundidad(x: int, y: int, z: int, profundidad_bajo_superficie: int) -> String:
	if profundidad_bajo_superficie < GROSOR_TIERRA:
		return "tierra"
	var ruido: float = _ruido_mineral.get_noise_3d(x, y, z)
	if profundidad_bajo_superficie >= PROFUNDIDAD_TIERRAS_RARAS and ruido > UMBRAL_TIERRAS_RARAS:
		return "tierras_raras"
	if profundidad_bajo_superficie >= PROFUNDIDAD_HIERRO and ruido > UMBRAL_HIERRO:
		return "hierro"
	if profundidad_bajo_superficie >= PROFUNDIDAD_COBRE and ruido > UMBRAL_COBRE:
		return "cobre"
	if profundidad_bajo_superficie >= PROFUNDIDAD_CARBON and ruido > UMBRAL_CARBON:
		return "carbon"
	return "piedra"


## Altura correspondiente al percentil PERCENTIL_NIVEL_MAR de la
## distribución real de altura_en() sobre el grid (ancho_mundo x
## largo_mundo) — ver nivel_mar.
## Usa un histograma (solo hay ALTURA_MAXIMA - ALTURA_MINIMA + 1 alturas
## enteras posibles, así que es barato) en vez de indexar un array
## ordenado por posición ordinal: el índice
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


## true si (x, z) es agua de cualquier tipo — mar/lago (es_agua_en()) o río
## (es_rio_en(), que puede estar muy por encima del nivel del mar). Punto
## único para cualquier lógica que deba tratar ambos tipos de agua por
## igual (señales de peces/algas, radio de acción del puesto de pesca) —
## ver VoxelWorld._tronco_toca_agua(), que ya usaba este mismo criterio
## compuesto de forma independiente.
func es_agua_o_rio_en(x: int, z: int) -> bool:
	return es_agua_en(x, z) or es_rio_en(x, z)


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
## no es bioma (ver es_bioma_en()) o si cae fuera de una zona de bosque real
## (ver UMBRAL_ZONA_BOSQUE/_ruido_bosque: frecuencia baja a propósito, para
## que el bosque salga en parches — 2026-09-17, confirmado jugando en vivo
## con captura real: sin esta zona, la densidad por celda sola cubría de
## árboles ~40% de TODO el mapa, un bosque continuo en vez de agrupado, ver
## PoC_6 3.17). Dentro de una zona de bosque, VoxelWorld._generar_arboles()
## coloca un árbol real donde esta densidad supera un umbral (ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md).
func densidad_arbol_en(x: int, z: int) -> float:
	if not es_bioma_en(x, z):
		return 0.0
	if _ruido_bosque.get_noise_2d(x, z) < UMBRAL_ZONA_BOSQUE:
		return 0.0
	var valor: float = _ruido_arbol.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0


## Densidad de peces en la columna de agua (x, z), en [0, 1] — 0.0 si la
## columna no es agua (ver es_agua_en()). Ruido puro (mismo patrón que
## densidad_fauna_en()/densidad_frutal_en()/densidad_arbol_en()): crea
## "nubes" de más/menos peces tanto en el mar como en cualquier río, sin
## relación con la profundidad real de esa columna (decisión explícita:
## una señal solo basada en profundidad resultaba demasiado plana/predecible).
func densidad_peces_en(x: int, z: int) -> float:
	if not es_agua_o_rio_en(x, z):
		return 0.0
	var valor: float = _ruido_peces.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0


## Profundidad relativa de la columna de agua (x, z) en [0, 1], normalizada
## contra el techo realista de SU tipo de cuerpo de agua (río vs. mar/lago),
## para que un río (profundidad máxima PROFUNDIDAD_MAXIMA_RIO) y un mar
## (profundidad máxima nivel_mar - ALTURA_MINIMA) sean comparables en la
## misma escala relativa. 0.0 si la columna no es agua.
func _profundidad_relativa_agua_en(x: int, z: int) -> float:
	if es_rio_en(x, z):
		return float(profundidad_rio_en(x, z)) / float(PROFUNDIDAD_MAXIMA_RIO)
	if not es_agua_en(x, z):
		return 0.0
	var techo: int = nivel_mar - ALTURA_MINIMA
	if techo <= 0:
		return 0.0
	var profundidad: int = nivel_mar - altura_en(x, z)
	return clampf(float(profundidad) / float(techo), 0.0, 1.0)


## Densidad de algas/frutos del mar en la columna de agua (x, z), en [0, 1]
## — 0.0 si la columna no es agua. Geométrica, no ruido: inversa a la
## profundidad relativa (agua somera = más luz = más señal) — a diferencia
## de densidad_peces_en(), tiene sentido que dependa de geometría real.
func densidad_algas_en(x: int, z: int) -> float:
	if not es_agua_o_rio_en(x, z):
		return 0.0
	return 1.0 - _profundidad_relativa_agua_en(x, z)


## Cuántas nacientes de río se generan por mundo (Sección 1 del spec) —
## constante ajustable como UMBRAL_HIERRO/EXPONENTE_RELIEVE.
const NUM_RIOS := 6

## Banda de altura [margen_inferior, margen_superior] dentro de la cual una
## columna es candidata a naciente de río, medida como distancia por debajo
## de ALTURA_MAXIMA (Sección 1): candidata si su altura está en
## [ALTURA_MAXIMA - margen_inferior, ALTURA_MAXIMA - margen_superior]. Por
## ejemplo, con ALTURA_MAXIMA = 15 y esta banda [5, 1], califican las
## columnas con altura entre 10 y 14 (inclusive).
## Antes era un único umbral inferior sin techo (cualquier altura >= cierto
## valor calificaba) — bug real, encontrado jugando en vivo con
## AMPLITUD_DETALLE_RELIEVE alto: el ruido de detalle es más fuerte
## precisamente cerca de las cumbres (factor_extremo ~1), así que la propia
## cumbre exacta queda con relieve local caótico y _trazar_rio() se atasca
## ahí de inmediato (cauce de 1 sola celda, descartado). El margen superior
## excluye esa franja más alta y caótica, dejando nacer los ríos desde el
## "hombro" más estable de la montaña, un poco por debajo de la cumbre.
const MARGEN_NACIENTE_RIO: Array[int] = [35, 17]

## Distancia mínima en línea recta (celdas) entre dos nacientes elegidas —
## evita que varios de los NUM_RIOS ríos nazcan todos de la misma montaña
## (decisión tomada jugando en vivo, junto con MARGEN_NACIENTE_RIO arriba).
## Se aplica como filtro tras cada elección (Sección 1): las candidatas
## demasiado cerca de la naciente recién elegida quedan fuera del resto del
## sorteo. Si el terreno alto está muy concentrado, esto puede dejar menos
## de NUM_RIOS nacientes disponibles — _generar_rios() simplemente genera
## los que alcancen, no es un error.
const MIN_DISTANCIA_NACIENTES := 10

const ANCHO_MINIMO_RIO := 2
## Subido de 6 a 8 (2026-09-17, PoC_6 3.18) — pedido explícito del usuario
## junto con NUM_MONTANAS: los ríos que nacen más alto (más cerca de una
## cumbre real) ahora tallan cauces más anchos, ver _ancho_por_altura().
const ANCHO_MAXIMO_RIO := 8

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

## (x,z) -> caída de altura (Sección 5) hacia la siguiente celda del cauce,
## para TODA celda de río (no solo cascadas) — ver caida_en(). Un tramo llano
## queda en 0; es_cascada_en() es simplemente caida_en() >= UMBRAL_CASCADA.
var _caida_rio: Dictionary = {}  # Vector2i -> int


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

## Las 4 direcciones cardinales de avance de un cauce (N/E/S/O) — un paso de
## _trazar_rio() siempre se mueve una celda a lo largo de uno de estos ejes,
## nunca en diagonal (el resto del sistema de ríos — _celdas_franja_en(),
## _aplicar_ancho_profundidad(), direccion_flujo_en() — asume avance
## ortogonal).
const DIRECCIONES_CARDINALES: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

## Radio (en celdas) donde _trazar_rio() mira antes de decidir hacia dónde
## avanzar — ver ahí. 2026-09-17 (PoC_6 3.18): con el terreno mayormente
## llano fuera de las montañas, mirar solo el vecino inmediato (radio 1, el
## diseño original) atascaba el cauce en depresiones minúsculas y reales de
## menos de 1 bloque de profundidad — confirmado midiendo el mundo real, no
## solo observado (ver notas del commit). Mirar más lejos encuentra la
## bajada real aunque esté a varias celdas, sin necesitar que el cauce
## "suba" para escapar.
const RADIO_VISTA_RIO := 5

## Traza el cauce crudo desde "origen" (Sección 2 del spec, reescrito
## 2026-09-17 — pedido explícito del usuario, PoC_6 3.18): en cada paso,
## primero busca el punto más bajo dentro de RADIO_VISTA_RIO celdas; si lo
## encuentra, apunta el siguiente paso (1 celda cardinal) hacia él. Si la
## vecindad es plana (nada más bajo cerca), mantiene la dirección con la que
## venía — así el cauce SÍ puede atravesar terreno llano en línea recta, no
## solo bajar. Si el siguiente paso en esa dirección subiría, gira hacia una
## de las otras direcciones cardinales (elegida al azar, pero determinista —
## RNG propio de este trazado, sembrado por semilla+origen) que no suba.
## Nunca se mueve a una celda más alta que la actual — eso es lo único que
## de verdad no puede pasar (a diferencia del diseño anterior, que exigía
## bajar en CADA paso). Termina al entrar a una celda de agua ya existente
## (incluida como último elemento) o si ninguna dirección (ni las 4
## cardinales inmediatas ni nada dentro de RADIO_VISTA_RIO) lleva a una
## celda no visitada que no suba — mesa/valle de verdad cerrado, se conserva
## el cauce parcial, no es un error. Un tope de pasos evita recorridos
## patológicos en mesetas totalmente planas.
func _trazar_rio(origen: Vector2i, ancho_mundo: int, largo_mundo: int) -> Array[Vector2i]:
	var cauce: Array[Vector2i] = [origen]
	var visitadas: Dictionary = {origen: true}
	var actual: Vector2i = origen
	var max_pasos: int = ancho_mundo + largo_mundo
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(_semilla, origen.x, origen.y))
	var direccion: Vector2i = Vector2i.ZERO

	for _paso in range(max_pasos):
		if es_agua_en(actual.x, actual.y):
			break
		var altura_actual: float = _altura_flotante(actual.x, actual.y)

		var objetivo: Vector2i = _punto_mas_bajo_en_radio(actual, altura_actual, visitadas, ancho_mundo, largo_mundo)
		if objetivo != actual:
			direccion = _direccion_cardinal_hacia(actual, objetivo)
		elif direccion == Vector2i.ZERO:
			direccion = DIRECCIONES_CARDINALES[rng.randi() % DIRECCIONES_CARDINALES.size()]

		var candidata: Vector2i = actual + direccion
		if not _celda_transitable(candidata, altura_actual, visitadas, ancho_mundo, largo_mundo):
			# La dirección actual está bloqueada (sube, sale del mundo, o ya
			# se visitó) — probar el resto de direcciones cardinales en
			# orden aleatorio (determinista, RNG propio de este trazado)
			# hasta encontrar una que no suba.
			var alternativas: Array[Vector2i] = DIRECCIONES_CARDINALES.duplicate()
			_barajar(alternativas, rng)
			var encontrada := false
			for alt in alternativas:
				var c: Vector2i = actual + alt
				if _celda_transitable(c, altura_actual, visitadas, ancho_mundo, largo_mundo):
					direccion = alt
					candidata = c
					encontrada = true
					break
			if not encontrada:
				break  # de verdad encerrado: cada dirección sube o ya está visitada

		visitadas[candidata] = true
		cauce.append(candidata)
		actual = candidata
	return cauce


## Punto más bajo (estrictamente menor que "altura_actual") dentro de
## RADIO_VISTA_RIO celdas de "actual", sin contar celdas ya visitadas ni
## fuera del mundo — o "actual" mismo si no hay ninguno (vecindad plana o
## solo con subidas). Usado por _trazar_rio() para decidir hacia dónde
## apuntar el siguiente paso.
func _punto_mas_bajo_en_radio(actual: Vector2i, altura_actual: float, visitadas: Dictionary, ancho_mundo: int, largo_mundo: int) -> Vector2i:
	var mejor: Vector2i = actual
	var mejor_altura: float = altura_actual
	for dx in range(-RADIO_VISTA_RIO, RADIO_VISTA_RIO + 1):
		for dz in range(-RADIO_VISTA_RIO, RADIO_VISTA_RIO + 1):
			if dx == 0 and dz == 0:
				continue
			if Vector2(dx, dz).length() > RADIO_VISTA_RIO:
				continue
			var candidata := Vector2i(actual.x + dx, actual.y + dz)
			if candidata.x < 0 or candidata.x >= ancho_mundo or candidata.y < 0 or candidata.y >= largo_mundo:
				continue
			if visitadas.has(candidata):
				continue
			var h: float = _altura_flotante(candidata.x, candidata.y)
			if h < mejor_altura:
				mejor_altura = h
				mejor = candidata
	return mejor


## Dirección cardinal (una de DIRECCIONES_CARDINALES) que más acerca a
## "objetivo" desde "origen" — el eje (X o Z) con mayor distancia gana el
## desempate, para avanzar realmente hacia el objetivo un paso a la vez.
static func _direccion_cardinal_hacia(origen: Vector2i, objetivo: Vector2i) -> Vector2i:
	var delta: Vector2i = objetivo - origen
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


## true si "celda" es un paso válido para _trazar_rio(): dentro del mundo,
## no visitada, y su altura continua no es mayor que "altura_actual" (puede
## ser igual — cruzar terreno llano está permitido — pero nunca mayor).
func _celda_transitable(celda: Vector2i, altura_actual: float, visitadas: Dictionary, ancho_mundo: int, largo_mundo: int) -> bool:
	if celda.x < 0 or celda.x >= ancho_mundo or celda.y < 0 or celda.y >= largo_mundo:
		return false
	if visitadas.has(celda):
		return false
	return _altura_flotante(celda.x, celda.y) <= altura_actual


## Fisher-Yates in-place con un RandomNumberGenerator propio — Array.shuffle()
## usa el RNG global de Godot, no reproducible por semilla de mundo.
static func _barajar(arreglo: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arreglo.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arreglo[i]
		arreglo[i] = arreglo[j]
		arreglo[j] = tmp


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


## Registra la caída de altura (_caida_rio) de cada paso de "cauce" (ya
## truncado) sobre toda su franja, y marca cascada (_celdas_cascada) los
## pasos cuya caída sea >= UMBRAL_CASCADA (Sección 5). Debe llamarse DESPUÉS
## de _aplicar_ancho_profundidad() sobre el mismo "cauce" (ver _generar_rios()):
## solo registra una celda de franja que _aplicar_ancho_profundidad() ya haya
## registrado en _profundidad_rio para ESTE río — así una celda bajo agua o ya
## reclamada por otro río (más fuerte, procesado antes) nunca puede quedar
## marcada como cascada sin ser también río (es_cascada_en => es_rio_en, ver
## TEST 25/TEST 26b).
func _marcar_cascadas(cauce: Array[Vector2i], ancho: int, ancho_mundo: int, largo_mundo: int) -> void:
	for i in range(cauce.size() - 1):
		var actual: Vector2i = cauce[i]
		if es_agua_en(actual.x, actual.y):
			continue
		var siguiente: Vector2i = cauce[i + 1]
		var caida: int = altura_en(actual.x, actual.y) - altura_en(siguiente.x, siguiente.y)
		for celda_franja in _celdas_franja_en(cauce, i, ancho):
			if celda_franja.x < 0 or celda_franja.x >= ancho_mundo or celda_franja.y < 0 or celda_franja.y >= largo_mundo:
				continue
			if es_agua_en(celda_franja.x, celda_franja.y):
				continue
			if not _profundidad_rio.has(celda_franja):
				continue
			_caida_rio[celda_franja] = caida
			if caida >= UMBRAL_CASCADA:
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
	var altura_min_naciente: int = ALTURA_MAXIMA - MARGEN_NACIENTE_RIO[0]
	var altura_max_naciente: int = ALTURA_MAXIMA - MARGEN_NACIENTE_RIO[1]
	var candidatos_brutos: Array[Vector2i] = []
	for x in range(ancho_mundo):
		for z in range(largo_mundo):
			var h: int = altura_en(x, z)
			if h >= altura_min_naciente and h <= altura_max_naciente:
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

	# Se sigue sorteando mientras falten ríos y queden candidatas — no solo
	# NUM_RIOS sorteos — descartando de inmediato (sin ocupar un cupo) las
	# candidatas cuyo cauce crudo ni siquiera llega a desembocar en agua. Bug
	# real, encontrado jugando en vivo: con el diseño anterior (exactamente
	# NUM_RIOS sorteos, sin reintentar), en un mundo real la mayoría de las
	# regiones elevadas son cuencas cerradas que nunca llegan al mar —
	# bastaba con que el sorteo cayera en varias de esas para terminar con
	# CERO ríos visibles en todo el mapa, sin ningún error. Reintentar con
	# la siguiente candidata hasta agotar la lista es la corrección: mismo
	# criterio de descarte ya usado más abajo (Sección 2b), aplicado antes
	# de gastar uno de los NUM_RIOS cupos.
	var rios: Array[Dictionary] = []
	while rios.size() < NUM_RIOS and not candidatos.is_empty():
		var idx: int = rng.randi() % candidatos.size()
		var origen: Vector2i = candidatos[idx]
		candidatos.remove_at(idx)
		# El sorteo de ancho se sigue consumiendo aquí (mismo lugar en la
		# secuencia del RNG que antes, para no romper la reproducción exacta
		# de esta secuencia en GeneradorMundoTest.gd) pero ya no decide el
		# ancho real — ver _ancho_por_altura(): un río que nace más alto
		# (más cerca de una cumbre real) talla un cauce más ancho, pedido
		# explícito del usuario junto con NUM_MONTANAS (PoC_6 3.18).
		rng.randi_range(ANCHO_MINIMO_RIO, ANCHO_MAXIMO_RIO)
		var ancho: int = _ancho_por_altura(altura_en(origen.x, origen.y), altura_min_naciente, altura_max_naciente)
		var cauce_crudo: Array[Vector2i] = _trazar_rio(origen, ancho_mundo, largo_mundo)

		# Filtrar candidatas demasiado cerca de la naciente recién elegida
		# (MIN_DISTANCIA_NACIENTES) — no consume el RNG, así que no afecta el
		# determinismo de los sorteos siguientes. Se aplica siempre, haya
		# tenido éxito esta naciente o no (evita reintentar la misma zona).
		var candidatos_lejanos: Array[Vector2i] = []
		for c in candidatos:
			if Vector2(c.x - origen.x, c.y - origen.y).length() >= MIN_DISTANCIA_NACIENTES:
				candidatos_lejanos.append(c)
		candidatos = candidatos_lejanos

		if cauce_crudo.size() < 2 or not es_agua_en(cauce_crudo[cauce_crudo.size() - 1].x, cauce_crudo[cauce_crudo.size() - 1].y):
			continue

		rios.append({
			"indice": rios.size(),
			"origen": origen,
			"ancho": ancho,
			"altura_nacimiento": altura_en(origen.x, origen.y),
			"cauce_crudo": cauce_crudo,
		})

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


## Caída de altura (Sección 5) hacia la siguiente celda del cauce en (x,z) —
## 0 si no es río o el tramo es llano. es_cascada_en(x,z) == caida_en(x,z) >=
## UMBRAL_CASCADA. Base de la corriente del río (Player._empuje_corriente()):
## a mayor caida_en(), mayor empuje.
func caida_en(x: int, z: int) -> int:
	return _caida_rio.get(Vector2i(x, z), 0)
