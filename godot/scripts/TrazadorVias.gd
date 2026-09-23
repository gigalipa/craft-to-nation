extends RefCounted

## A* sobre VÉRTICES del grid (esquinas entre 4 celdas), para el trazador
## de vías de CamaraCenital.gd — ver spec de vías Sección 4. Distinto de
## BuscadorRutas.gd (que camina por CELDAS 3D con 4 vecinos, para NPCs):
## aquí se camina por VÉRTICES 2D con 8 vecinos (incluye diagonales), y el
## costo de moverse no depende de la física de un personaje sino de si el
## BLOQUE DE VÍA (NiveladorVia.nivel_de_bloque()) que representa ese
## vértice es alcanzable. Clase pura (RefCounted): "mundo" solo necesita
## altura_en(x, z), obtener_tipo(celda: Vector3i) e
## id_de_edificio(celda: Vector3i) -> int.

const NiveladorVia = preload("res://scripts/NiveladorVia.gd")

## Tope de nodos expandidos por consulta — mismo motivo que
## BuscadorRutas.MAX_NODOS_EXPANDIDOS, ajustado a un mapa más chico (esto
## es una previsualización interactiva, no pathfinding de NPCs).
const MAX_NODOS_EXPANDIDOS := 5000

const DIRECCIONES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var mundo: Object
var _nivelador: RefCounted

## Memoización de vertice_transitable()/nivel_de_bloque() por vértice —
## reportado jugando en vivo (2026-09-23): sin esto, vecinos() recalcula
## vertice_transitable(actual) hasta 8 veces (una por dirección) en la
## MISMA llamada, y cada vértice visitado por más de un nodo del A* (algo
## común: dos nodos vecinos comparten varios de sus propios vecinos) lo
## recalculaba otra vez desde cero — con el tope de 5000 nodos expandidos
## en un destino inalcanzable, eso son cientos de miles de consultas al
## mundo por fotograma mientras se traza, y el juego se congelaba unos
## instantes. Vive mientras viva esta instancia (una por sesión de
## trazado — ver CamaraCenital._alternar_modo_trazar_via()): el terreno
## no cambia mientras el modo trazador está activo (es excluyente con
## minar/construir), así que no hay riesgo de quedar desactualizada.
var _cache_transitable: Dictionary = {}  # Vector2i -> bool
var _cache_nivel: Dictionary = {}  # Vector2i -> int


func _init(p_mundo: Object) -> void:
	mundo = p_mundo
	_nivelador = NiveladorVia.new(p_mundo)


## Passthrough a NiveladorVia — para que CamaraCenital.gd no necesite
## instanciar NiveladorVia por separado solo para consultar el bloque.
func bloque_de_vertice(vertice: Vector2i) -> Array[Vector2i]:
	return _nivelador.bloque_de_vertice(vertice)


## true si NINGUNA de las 4 columnas del bloque de soporte de "vertice"
## está ocupada por agua o por un edificio/obra — los árboles NO bloquean
## (se talan al confirmar, ver spec de vías Sección 5). Usa la superficie
## real del mundo (mundo.altura_en(x, z) + 1), igual que
## CamaraCenital._huella_choca_con_otro_puesto().
func vertice_transitable(vertice: Vector2i) -> bool:
	if _cache_transitable.has(vertice):
		return _cache_transitable[vertice]
	var transitable := true
	for col in _nivelador.bloque_de_vertice(vertice):
		var superficie := Vector3i(col.x, mundo.altura_en(col.x, col.y) + 1, col.y)
		if mundo.obtener_tipo(superficie) == "agua" or mundo.id_de_edificio(superficie) != -1:
			transitable = false
			break
	_cache_transitable[vertice] = transitable
	return transitable


## nivel_de_bloque() cacheado — ver _cache_nivel más arriba.
func _nivel_cacheado(vertice: Vector2i) -> int:
	if not _cache_nivel.has(vertice):
		_cache_nivel[vertice] = _nivelador.nivel_de_bloque(vertice)
	return _cache_nivel[vertice]


## true si se puede pasar de "a" a "b" (adyacentes, 1 paso de
## DIRECCIONES): ambos transitables y el desnivel entre sus bloques no
## supera NiveladorVia.LIMITE_DESNIVEL_VIA.
func paso_valido(a: Vector2i, b: Vector2i) -> bool:
	if not (vertice_transitable(a) and vertice_transitable(b)):
		return false
	var desnivel: int = absi(_nivel_cacheado(b) - _nivel_cacheado(a))
	return desnivel <= NiveladorVia.LIMITE_DESNIVEL_VIA


## Vértices alcanzables en 1 paso desde "vertice" (de los 8 de DIRECCIONES).
func vecinos(vertice: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for direccion in DIRECCIONES:
		var candidato: Vector2i = vertice + direccion
		if paso_valido(vertice, candidato):
			resultado.append(candidato)
	return resultado


## Ruta más corta de "origen" a "destino" (SIN incluir el origen); [] si
## no hay ruta, si origen == destino, o si origen/destino no son
## transitables. "max_nodos" (por defecto MAX_NODOS_EXPANDIDOS) permite un
## tope más bajo para la vista previa en vivo (ver CamaraCenital.
## _actualizar_preview_via()): un destino genuinamente inalcanzable (agua,
## acantilado) igual agota el tope completo cada vez que se consulta por
## primera vez, y 5000 nodos por fotograma se sentía pesado jugando en
## vivo — la búsqueda real al confirmar sigue usando el tope completo.
func buscar_ruta(origen: Vector2i, destino: Vector2i, max_nodos: int = MAX_NODOS_EXPANDIDOS) -> Array[Vector2i]:
	var vacia: Array[Vector2i] = []
	if origen == destino:
		return vacia
	if not (vertice_transitable(origen) and vertice_transitable(destino)):
		return vacia

	var costo: Dictionary = {origen: 0}
	var padre: Dictionary = {}
	var cerrados: Dictionary = {}
	var abiertos: Array = []
	var desempate := 0
	_meter(abiertos, [_heuristica(origen, destino), desempate, origen])
	var expandidos := 0
	while not abiertos.is_empty():
		var actual: Vector2i = _sacar(abiertos)[2]
		if cerrados.has(actual):
			continue
		if actual == destino:
			var ruta: Array[Vector2i] = []
			var v: Vector2i = actual
			while v != origen:
				ruta.append(v)
				v = padre[v]
			ruta.reverse()
			return ruta
		cerrados[actual] = true
		expandidos += 1
		if expandidos > max_nodos:
			return vacia
		for vecino in vecinos(actual):
			if cerrados.has(vecino):
				continue
			var nuevo_costo: int = costo[actual] + 1
			if not costo.has(vecino) or nuevo_costo < costo[vecino]:
				costo[vecino] = nuevo_costo
				padre[vecino] = actual
				desempate += 1
				_meter(abiertos, [nuevo_costo + _heuristica(vecino, destino), desempate, vecino])
	return vacia


## Distancia de Chebyshev — admisible con 8 vecinos y costo uniforme 1
## por paso.
static func _heuristica(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Cola de prioridad: montículo binario de [f, orden_de_inserción,
## vértice] — mismo patrón que BuscadorRutas.gd (desempata por orden de
## inserción para que la búsqueda sea determinista).
static func _menor(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	return a[1] < b[1]


static func _meter(monticulo: Array, elemento: Array) -> void:
	monticulo.append(elemento)
	var i: int = monticulo.size() - 1
	while i > 0:
		var padre_i: int = (i - 1) >> 1
		if not _menor(monticulo[i], monticulo[padre_i]):
			break
		var t: Array = monticulo[i]
		monticulo[i] = monticulo[padre_i]
		monticulo[padre_i] = t
		i = padre_i


static func _sacar(monticulo: Array) -> Array:
	var cima: Array = monticulo[0]
	var ultimo: Array = monticulo.pop_back()
	if not monticulo.is_empty():
		monticulo[0] = ultimo
		var i := 0
		var n: int = monticulo.size()
		while true:
			var iz := 2 * i + 1
			var de := iz + 1
			var m := i
			if iz < n and _menor(monticulo[iz], monticulo[m]):
				m = iz
			if de < n and _menor(monticulo[de], monticulo[m]):
				m = de
			if m == i:
				break
			var t: Array = monticulo[i]
			monticulo[i] = monticulo[m]
			monticulo[m] = t
			i = m
	return cima
