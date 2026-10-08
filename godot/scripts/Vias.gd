extends Node

## Autoload "Vias": estado puro y catálogo de las vías (ver GDD Sección 4,
## docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md). Sin
## class_name (colisionaría con el nombre del autoload, mismo motivo que
## Ciudad.gd/Zonificacion.gd). No depende de ningún nodo de escena.
##
## Convención: Vector2i(x, z) para columnas en planta — la coordenada
## mundial Z vive en el campo .y (misma convención que Zonificacion.gd).

## Catálogo por datos. Único tipo implementado: "tierra_pisada". Tipos
## futuros (calzada, vía férrea, cintas, tuberías, calzada peatonal — ver
## GDD Sección 3.1/4) se agregan aquí como filas nuevas cuando se
## implementen, nunca antes.
var TIPOS: Dictionary = {
	"tierra_pisada": {
		"nombre": "Vía de tierra pisada",
		"ancho": 2,
		"sentido": "doble",
		"bono_velocidad": 1.35,
		"costo": {},
		"energia": false,
		"transito": "No",
		"material": preload("res://assets/mat_tierra_pisada.tres"),
	},
}


## Ficha técnica para la tarjeta contextual al trazar vías (ver GDD Sección 4).
## "cantidad_celdas": 0 muestra el costo unitario por celda (p. ej. "2 piedra/celda" o "N/A"),
## > 0 muestra el costo total calculado para ese tramo (p. ej. "16 piedra" o "N/A").
func ficha_tecnica(tipo: String, cantidad_celdas: int = 0) -> String:
	if not TIPOS.has(tipo):
		return ""
	var datos: Dictionary = TIPOS[tipo]
	var nombre: String = datos.get("nombre", tipo.capitalize())
	var costo_dic: Dictionary = datos.get("costo", {})

	var recursos_str := "N/A"
	if not costo_dic.is_empty():
		var partes: Array = []
		if cantidad_celdas > 0:
			for recurso in costo_dic:
				partes.append("%d %s" % [costo_dic[recurso] * cantidad_celdas, recurso])
			recursos_str = " + ".join(partes)
		else:
			for recurso in costo_dic:
				partes.append("%d %s" % [costo_dic[recurso], recurso])
			recursos_str = "%s/celda" % " + ".join(partes)

	var bono: float = datos.get("bono_velocidad", 1.0)
	var pct: int = roundi((bono - 1.0) * 100)
	var vel_str: String = ("+%d%%" % pct) if pct >= 0 else ("%d%%" % pct)

	var energia_str: String = "Sí" if datos.get("energia", false) else "No"
	var transito_str: String = datos.get("transito", "No")

	return "%s\nRecursos: %s\nVelocidad: %s\nTransmisión de energía: %s\nTránsito vehicular: %s" % [
		nombre,
		recursos_str,
		vel_str,
		energia_str,
		transito_str
	]

## Celda de SOPORTE (el bloque que lleva la vía en su cara superior:
## terreno nivelado, relleno, o una cuna_recta/cuna_esquina) -> tipo.
var celdas: Dictionary = {}  # Vector3i -> String

## Índice derivado de "celdas" por columna XZ, para hay_via_en_columna()
## sin recorrer "celdas" entero — mantenido en agregar()/quitar().
var _columnas: Dictionary = {}  # Vector2i -> int (cuántas celdas de esa columna hay en "celdas")

## Celda de soporte -> esquina LOCAL (0 o 1 en cada eje) que su overlay
## plano debe OMITIR, dibujando un triángulo en vez de un cuadrado
## completo — para que el borde visual de una vía diagonal quede recto
## en vez de escalonado (ver NiveladorVia.notches_de_paso(), spec de vías
## Sección 1). Sin entrada = celda normal, overlay cuadrado completo.
var notches: Dictionary = {}  # Vector3i -> Vector2i

## Emitida cuando agregar()/quitar() cambian el registro — ViasRenderer la
## escucha para reconstruir solo los chunks afectados (ver spec Sección 3).
signal vias_cambiadas(celdas: Array)


func es_via(soporte: Vector3i) -> bool:
	return celdas.has(soporte)


func tipo_en(soporte: Vector3i) -> String:
	return celdas.get(soporte, "")


## Multiplicador de velocidad de la celda de SOPORTE "soporte" (el bloque
## bajo los pies, no la celda donde está parado el personaje) — 1.0 si no
## es vía. Ver spec Sección 7.
func bono_en(soporte: Vector3i) -> float:
	if not es_via(soporte):
		return 1.0
	return TIPOS[tipo_en(soporte)]["bono_velocidad"]


func hay_via_en_columna(xz: Vector2i) -> bool:
	return _columnas.get(xz, 0) > 0


## Columnas XZ con al menos una celda de vía.
func columnas() -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for k in _columnas:
		resultado.append(k)
	return resultado


## Esquina local (0 o 1 en cada eje) que el overlay de "soporte" debe
## omitir, o Vector2i(-1, -1) si no es una celda "notch" (overlay
## cuadrado normal) — ver "notches" más arriba.
func notch_en(soporte: Vector3i) -> Vector2i:
	return notches.get(soporte, Vector2i(-1, -1))


func marcar_notch(soporte: Vector3i, esquina_omitida: Vector2i) -> void:
	notches[soporte] = esquina_omitida


func agregar(celdas_nuevas: Array, tipo: String) -> void:
	for celda: Vector3i in celdas_nuevas:
		if not celdas.has(celda):
			var xz := Vector2i(celda.x, celda.z)
			_columnas[xz] = _columnas.get(xz, 0) + 1
		celdas[celda] = tipo
	vias_cambiadas.emit(celdas_nuevas)


func quitar(celdas_a_quitar: Array) -> void:
	var quitadas: Array = []
	for celda: Vector3i in celdas_a_quitar:
		if not celdas.has(celda):
			continue
		celdas.erase(celda)
		notches.erase(celda)
		var xz := Vector2i(celda.x, celda.z)
		_columnas[xz] = _columnas.get(xz, 1) - 1
		if _columnas[xz] <= 0:
			_columnas.erase(xz)
		quitadas.append(celda)
	if not quitadas.is_empty():
		vias_cambiadas.emit(quitadas)


const COLUMNAS_BLOQUE_REL: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
]

const DIRECCIONES_VERTICES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## Devuelve la primera celda 3D de vía encontrada en la columna (x, z), o Vector3i.ZERO si no hay.
func celda_en_columna(xz: Vector2i) -> Vector3i:
	for c in celdas:
		if c.x == xz.x and c.z == xz.y:
			return c
	return Vector3i.ZERO


## Devuelve todas las celdas 3D de vía registradas en la columna (x, z).
func celdas_en_columna(xz: Vector2i) -> Array[Vector3i]:
	var res: Array[Vector3i] = []
	for c in celdas:
		if c.x == xz.x and c.z == xz.y:
			res.append(c)
	return res


## Las 4 columnas (X, Z) del bloque 2x2 correspondiente al vértice v.
func bloque_de_vertice(v: Vector2i) -> Array[Vector2i]:
	var esquina := v - Vector2i(1, 1)
	var resultado: Array[Vector2i] = []
	for rel in COLUMNAS_BLOQUE_REL:
		resultado.append(esquina + rel)
	return resultado


## Comprueba si un vértice forma parte de la red de vías (al menos una de sus 4 columnas tiene vía).
func es_vertice_de_via(v: Vector2i) -> bool:
	for col in bloque_de_vertice(v):
		if hay_via_en_columna(col):
			return true
	return false


## Devuelve cuántas de las 4 columnas del bloque del vértice contienen vía.
func puntuacion_vertice(v: Vector2i) -> int:
	var punt := 0
	for col in bloque_de_vertice(v):
		if hay_via_en_columna(col):
			punt += 1
	return punt


## Encuentra el vértice que mejor representa la columna (x, z) dentro de la red de vías.
func vertice_mas_cercano_en_via(xz: Vector2i) -> Vector2i:
	var candidatos: Array[Vector2i] = [
		Vector2i(xz.x, xz.y),
		Vector2i(xz.x + 1, xz.y),
		Vector2i(xz.x, xz.y + 1),
		Vector2i(xz.x + 1, xz.y + 1),
	]
	var mejor_vertice := Vector2i(xz.x + 1, xz.y + 1)
	var mejor_puntuacion := -1
	for v in candidatos:
		var punt := puntuacion_vertice(v)
		if punt > mejor_puntuacion:
			mejor_puntuacion = punt
			mejor_vertice = v
	return mejor_vertice


## Devuelve todas las celdas de vía (las 4 celdas del bloque 2x2) de la sección a la que pertenece la columna.
func celdas_de_seccion(xz: Vector2i) -> Array[Vector3i]:
	var v := vertice_mas_cercano_en_via(xz)
	var res: Array[Vector3i] = []
	for col in bloque_de_vertice(v):
		for c in celdas_en_columna(col):
			if not res.has(c):
				res.append(c)
	if res.is_empty():
		return celdas_en_columna(xz)
	return res


## Devuelve todas las celdas 3D de vía para una lista de vértices y sus transiciones (ambos canales).
func celdas_de_vertices(vertices: Array[Vector2i]) -> Array[Vector3i]:
	var cols: Dictionary = {}
	for i in range(vertices.size()):
		var v: Vector2i = vertices[i]
		for col in bloque_de_vertice(v):
			cols[col] = true
		if i < vertices.size() - 1:
			var a: Vector2i = vertices[i]
			var b: Vector2i = vertices[i + 1]
			for x in range(mini(a.x, b.x) - 1, maxi(a.x, b.x) + 1):
				for z in range(mini(a.y, b.y) - 1, maxi(a.y, b.y) + 1):
					cols[Vector2i(x, z)] = true

	var res: Array[Vector3i] = []
	for col in cols:
		for c in celdas_en_columna(col):
			if not res.has(c):
				res.append(c)
	return res


## Busca el camino más corto de vértices sobre la red de vías entre dos vértices.
## Prefiere pasos ortogonales sobre diagonales para no cortar esquinas en giros de 90° y abarcar la esquina completa.
func buscar_camino_vertices_en_red(inicio: Vector2i, fin: Vector2i) -> Array[Vector2i]:
	if not es_vertice_de_via(inicio) or not es_vertice_de_via(fin):
		return []
	if inicio == fin:
		return [inicio]

	var dist: Dictionary = {inicio: 0}
	var previos: Dictionary = {}
	var cola: Array = [[0, inicio]]  # [costo, vertice]

	while not cola.is_empty():
		var menor_idx := 0
		var menor_costo: int = cola[0][0]
		for i in range(1, cola.size()):
			if cola[i][0] < menor_costo:
				menor_costo = cola[i][0]
				menor_idx = i
		var item: Array = cola[menor_idx]
		cola.remove_at(menor_idx)
		var actual_costo: int = item[0]
		var actual: Vector2i = item[1]

		if actual == fin:
			break
		if actual_costo > dist.get(actual, 999999999):
			continue

		for dir in DIRECCIONES_VERTICES:
			var vecina: Vector2i = actual + dir
			if not es_vertice_de_via(vecina):
				continue

			var comparten_via := false
			var cols_actual: Array[Vector2i] = bloque_de_vertice(actual)
			for col in bloque_de_vertice(vecina):
				if cols_actual.has(col) and hay_via_en_columna(col):
					comparten_via = true
					break

			if not comparten_via:
				continue

			var es_diag: bool = (dir.x != 0 and dir.y != 0)
			var peso: int = (25 if es_diag else 10) + (4 - puntuacion_vertice(vecina)) * 10
			var nuevo_costo: int = actual_costo + peso
			if nuevo_costo < dist.get(vecina, 999999999):
				dist[vecina] = nuevo_costo
				previos[vecina] = actual
				cola.append([nuevo_costo, vecina])

	if not previos.has(fin):
		return []

	var camino: Array[Vector2i] = []
	var paso: Vector2i = fin
	while paso != inicio:
		camino.push_front(paso)
		paso = previos[paso]
	camino.push_front(inicio)
	return camino


## Busca el camino sobre la red vial devolviendo todas las celdas 3D involucradas (sección completa de 4 celdas/ancho 2).
func buscar_camino_en_red(inicio: Vector3i, fin: Vector3i) -> Array[Vector3i]:
	var v_inicio := vertice_mas_cercano_en_via(Vector2i(inicio.x, inicio.z))
	var v_fin := vertice_mas_cercano_en_via(Vector2i(fin.x, fin.z))
	var camino_v := buscar_camino_vertices_en_red(v_inicio, v_fin)
	if camino_v.is_empty():
		return []
	return celdas_de_vertices(camino_v)

