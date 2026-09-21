extends RefCounted

## A* a pie sobre el mundo voxel. Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Secciones
## 2 y 6).
##
## No usa NavigationServer3D: exige hornear una malla y este mundo cambia
## continuamente (minado, construcción fantasma, agua que fluye). Aquí los
## vecinos se evalúan consultando "mundo" en el momento, así que siempre se
## ve el mundo actual y no hay nada que invalidar.
##
## "mundo" necesita obtener_tipo(celda: Vector3i) -> String ("" = vacía) y,
## solo si se usa ignorar_fantasmas, id_de_edificio(celda: Vector3i) -> int.
## Clase pura (RefCounted), sin nodos: se prueba con un mundo falso.

## Tope de nodos expandidos por consulta: suficiente para cruzar el mapa de
## 200x200. ponytail: búsqueda síncrona con tope fijo; pasar a búsqueda
## asíncrona o jerárquica si el número de NPC lo exige.
const MAX_NODOS_EXPANDIDOS := 20000

## Un NPC sube 1 bloque y cae hasta 3 (como salta y cae el jugador).
const CAIDA_MAXIMA := 3

const ARRIBA := Vector3i(0, 1, 0)

## Celdas por las que un NPC (de 2 celdas de alto) pasa. Todo lo demás es
## sólido, incluidos "fantasma", "follaje", "madera", camas y baúles.
const TIPOS_LIBRES := ["", "puerta_inferior", "puerta_superior"]

const DIRECCIONES: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var mundo: Object
var max_nodos: int = MAX_NODOS_EXPANDIDOS


func _init(p_mundo: Object) -> void:
	mundo = p_mundo


## "ignorar" son ids de obra cuyos bloques "fantasma" cuentan como libres para
## quien pregunta (los que tienen permiso de salida, ver VoxelWorld). Solo
## afecta al cuerpo del NPC; el suelo (ver es_transitable()) sigue viendo un
## fantasma como sólido.
func _libre(celda: Vector3i, ignorar: Array = []) -> bool:
	var tipo: String = mundo.obtener_tipo(celda)
	if TIPOS_LIBRES.has(tipo):
		return true
	return tipo == "fantasma" and not ignorar.is_empty() and ignorar.has(mundo.id_de_edificio(celda))


## Un NPC puede estar en "celda" si ella y la de arriba están libres y la de
## abajo es suelo sólido. Excepción: "celda" puede ser agua si la de arriba es
## libre (agua de 1 bloque de profundidad; con 2 o más ya no se camina, se
## nadaría, y los colonos no nadan). Una cama o un baúl es suelo, así que un
## colono puede pararse encima.
func es_transitable(celda: Vector3i, ignorar: Array = []) -> bool:
	var tipo: String = mundo.obtener_tipo(celda)
	if not (_libre(celda, ignorar) or tipo == "agua"):
		return false
	if not _libre(celda + ARRIBA, ignorar):
		return false
	var suelo: String = mundo.obtener_tipo(celda - ARRIBA)
	return suelo != "agua" and not TIPOS_LIBRES.has(suelo)


## Celdas transitables a un paso de "celda": mismo nivel, subiendo 1 bloque o
## cayendo hasta CAIDA_MAXIMA. Sin diagonales.
func vecinos(celda: Vector3i, ignorar: Array = []) -> Array[Vector3i]:
	var resultado: Array[Vector3i] = []
	for direccion in DIRECCIONES:
		var columna: Vector3i = celda + direccion
		if es_transitable(columna, ignorar):
			resultado.append(columna)
			continue
		var sobre_columna: Vector3i = columna + ARRIBA
		if es_transitable(sobre_columna, ignorar) and _libre(celda + ARRIBA * 2, ignorar):
			resultado.append(sobre_columna)
			continue
		if _libre(columna, ignorar) and _libre(sobre_columna, ignorar):
			for caida in range(1, CAIDA_MAXIMA + 1):
				var abajo: Vector3i = columna - ARRIBA * caida
				if es_transitable(abajo, ignorar):
					resultado.append(abajo)
					break
				if not _libre(abajo, ignorar):
					break
	return resultado


## Celdas a recorrer de "origen" a "destino", SIN incluir el origen; [] si no
## hay ruta (origen o destino no transitables, destino bloqueado, sin camino o
## tope de nodos agotado). opciones.bloqueadas: Dictionary (Vector3i -> true)
## con celdas que no se pueden pisar (otros colonos, el avatar).
## opciones.ignorar_fantasmas: Array de ids de obra cuyos fantasmas son libres
## para este solicitante.
func buscar_ruta(origen: Vector3i, destino: Vector3i, opciones: Dictionary = {}) -> Array[Vector3i]:
	var vacia: Array[Vector3i] = []
	var bloqueadas: Dictionary = opciones.get("bloqueadas", {})
	var ignorar: Array = opciones.get("ignorar_fantasmas", [])
	if origen == destino or bloqueadas.has(destino) or not es_transitable(destino, ignorar):
		return vacia
	return _buscar(
		origen,
		func(celda: Vector3i) -> bool: return celda == destino,
		func(celda: Vector3i) -> int: return _heuristica(celda, destino),
		opciones
	)


## Ruta más corta desde "origen" hasta la primera celda transitable para la
## que esta_dentro.call(celda) es false (la salida de un volumen). Sin
## incluir el origen; [] si no hay ruta o si el origen ya está fuera.
func buscar_salida(origen: Vector3i, esta_dentro: Callable, opciones: Dictionary = {}) -> Array[Vector3i]:
	return _buscar(
		origen,
		func(celda: Vector3i) -> bool: return not esta_dentro.call(celda),
		func(_celda: Vector3i) -> int: return 0,
		opciones
	)


## Búsqueda de coste uniforme/A*: es_meta(celda) -> bool y heuristica(celda) ->
## int. Coste de un paso = 1 + |dy| (así la heurística Manhattan 3D de
## buscar_ruta() es admisible).
func _buscar(origen: Vector3i, es_meta: Callable, heuristica: Callable, opciones: Dictionary) -> Array[Vector3i]:
	var ruta: Array[Vector3i] = []
	var bloqueadas: Dictionary = opciones.get("bloqueadas", {})
	var ignorar: Array = opciones.get("ignorar_fantasmas", [])
	if not es_transitable(origen, ignorar):
		return ruta

	var costo: Dictionary = {origen: 0}
	var padre: Dictionary = {}
	var cerrados: Dictionary = {}
	var abiertos: Array = []
	var desempate := 0
	var h_origen: int = heuristica.call(origen)
	_meter(abiertos, [h_origen, h_origen, desempate, origen])
	var expandidos := 0
	while not abiertos.is_empty():
		var actual: Vector3i = _sacar(abiertos)[3]
		if cerrados.has(actual):
			continue
		if es_meta.call(actual):
			var celda: Vector3i = actual
			while celda != origen:
				ruta.append(celda)
				celda = padre[celda]
			ruta.reverse()
			return ruta
		cerrados[actual] = true
		expandidos += 1
		if expandidos > max_nodos:
			return ruta
		for vecino in vecinos(actual, ignorar):
			if cerrados.has(vecino) or bloqueadas.has(vecino):
				continue
			var nuevo_costo: int = costo[actual] + 1 + absi(vecino.y - actual.y)
			if not costo.has(vecino) or nuevo_costo < costo[vecino]:
				costo[vecino] = nuevo_costo
				padre[vecino] = actual
				desempate += 1
				var h: int = heuristica.call(vecino)
				_meter(abiertos, [nuevo_costo + h, h, desempate, vecino])
	return ruta


static func _heuristica(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y) + absi(a.z - b.z)


## Cola de prioridad: monticulo binario de [f, h, orden_de_inserción, celda].
## Desempata por menor h (más cerca del destino) y luego por orden de inserción,
## que hace determinista la búsqueda. Sin el desempate por h, en terreno llano
## abierto todas las celdas del rectángulo origen-destino tienen el mismo f y
## A* degenera en búsqueda en anchura (agota el tope en rutas largas).
static func _menor(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return a[2] < b[2]


static func _meter(monticulo: Array, elemento: Array) -> void:
	monticulo.append(elemento)
	var i: int = monticulo.size() - 1
	while i > 0:
		var padre_i: int = (i - 1) >> 1
		if not _menor(monticulo[i], monticulo[padre_i]):
			break
		var temporal: Array = monticulo[i]
		monticulo[i] = monticulo[padre_i]
		monticulo[padre_i] = temporal
		i = padre_i


static func _sacar(monticulo: Array) -> Array:
	var cima: Array = monticulo[0]
	var ultimo: Array = monticulo.pop_back()
	if not monticulo.is_empty():
		monticulo[0] = ultimo
		var i := 0
		var n: int = monticulo.size()
		while true:
			var izquierdo := 2 * i + 1
			var derecho := izquierdo + 1
			var menor := i
			if izquierdo < n and _menor(monticulo[izquierdo], monticulo[menor]):
				menor = izquierdo
			if derecho < n and _menor(monticulo[derecho], monticulo[menor]):
				menor = derecho
			if menor == i:
				break
			var temporal: Array = monticulo[i]
			monticulo[i] = monticulo[menor]
			monticulo[menor] = temporal
			i = menor
	return cima
