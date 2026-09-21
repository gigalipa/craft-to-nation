extends RefCounted

## A* a pie sobre el mundo voxel. Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Sección 2).
##
## No usa NavigationServer3D: exige hornear una malla y este mundo cambia
## continuamente (minado, construcción fantasma, agua que fluye). Aquí los
## vecinos se evalúan consultando "mundo" en el momento, así que siempre se
## ve el mundo actual y no hay nada que invalidar.
##
## "mundo" solo necesita obtener_tipo(celda: Vector3i) -> String ("" = vacía).
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


func _libre(celda: Vector3i) -> bool:
	return TIPOS_LIBRES.has(mundo.obtener_tipo(celda))


## Un NPC puede estar en "celda" si ella y la de arriba están libres y la de
## abajo es suelo sólido. Excepción: "celda" puede ser agua si la de arriba es
## libre (agua de 1 bloque de profundidad; con 2 o más ya no se camina, se
## nadaría, y los colonos no nadan). Una cama o un baúl es suelo, así que un
## colono puede pararse encima.
func es_transitable(celda: Vector3i) -> bool:
	var tipo: String = mundo.obtener_tipo(celda)
	if not (TIPOS_LIBRES.has(tipo) or tipo == "agua"):
		return false
	if not _libre(celda + ARRIBA):
		return false
	var suelo: String = mundo.obtener_tipo(celda - ARRIBA)
	return suelo != "agua" and not TIPOS_LIBRES.has(suelo)


## Celdas transitables a un paso de "celda": mismo nivel, subiendo 1 bloque o
## cayendo hasta CAIDA_MAXIMA. Sin diagonales.
func vecinos(celda: Vector3i) -> Array[Vector3i]:
	var resultado: Array[Vector3i] = []
	for direccion in DIRECCIONES:
		var columna: Vector3i = celda + direccion
		if es_transitable(columna):
			resultado.append(columna)
			continue
		var sobre_columna: Vector3i = columna + ARRIBA
		if es_transitable(sobre_columna) and _libre(celda + ARRIBA * 2):
			resultado.append(sobre_columna)
			continue
		if _libre(columna) and _libre(sobre_columna):
			for caida in range(1, CAIDA_MAXIMA + 1):
				var abajo: Vector3i = columna - ARRIBA * caida
				if es_transitable(abajo):
					resultado.append(abajo)
					break
				if not _libre(abajo):
					break
	return resultado


## Celdas a recorrer de "origen" a "destino", SIN incluir el origen; [] si no
## hay ruta (origen o destino no transitables, destino bloqueado, sin camino o
## tope de nodos agotado). opciones.bloqueadas: Dictionary (Vector3i -> true)
## con celdas que no se pueden pisar (otros colonos, el avatar).
## Coste de un paso = 1 + |dy| y heurística Manhattan 3D: admisible.
func buscar_ruta(origen: Vector3i, destino: Vector3i, opciones: Dictionary = {}) -> Array[Vector3i]:
	var ruta: Array[Vector3i] = []
	var bloqueadas: Dictionary = opciones.get("bloqueadas", {})
	if origen == destino or bloqueadas.has(destino):
		return ruta
	if not es_transitable(origen) or not es_transitable(destino):
		return ruta

	var costo: Dictionary = {origen: 0}
	var padre: Dictionary = {}
	var cerrados: Dictionary = {}
	var abiertos: Array = []
	var desempate := 0
	_meter(abiertos, [_heuristica(origen, destino), desempate, origen])
	var expandidos := 0
	while not abiertos.is_empty():
		var actual: Vector3i = _sacar(abiertos)[2]
		if cerrados.has(actual):
			continue
		if actual == destino:
			var celda: Vector3i = destino
			while celda != origen:
				ruta.append(celda)
				celda = padre[celda]
			ruta.reverse()
			return ruta
		cerrados[actual] = true
		expandidos += 1
		if expandidos > max_nodos:
			return ruta
		for vecino in vecinos(actual):
			if cerrados.has(vecino) or bloqueadas.has(vecino):
				continue
			var nuevo_costo: int = costo[actual] + 1 + absi(vecino.y - actual.y)
			if not costo.has(vecino) or nuevo_costo < costo[vecino]:
				costo[vecino] = nuevo_costo
				padre[vecino] = actual
				desempate += 1
				_meter(abiertos, [nuevo_costo + _heuristica(vecino, destino), desempate, vecino])
	return ruta


static func _heuristica(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y) + absi(a.z - b.z)


## Cola de prioridad: monticulo binario de [f, orden_de_inserción, celda]. El
## orden de inserción desempata y hace determinista la búsqueda.
static func _menor(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


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
