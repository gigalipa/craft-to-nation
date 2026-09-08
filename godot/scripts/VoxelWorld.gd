extends GridMap

## Mundo voxel acotado sobre GridMap + MeshLibrary (assets/BlockLibrary.res,
## generada desde scenes/BlockLibrarySource.tscn). Reemplaza la versión previa
## de celdas por código (MeshInstance3D/StaticBody3D manuales) ahora que el
## editor de Godot está disponible para exportar la MeshLibrary.

const TAMANO_CELDA := 1.0

const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")

const ANCHO_MUNDO := 200
const LARGO_MUNDO := 200
const PROFUNDIDAD_SUBSUELO := 24
const SEMILLA_MUNDO := 12345

## Rango de búsqueda vertical de altura_en() (ver más abajo) — generoso para
## cubrir cualquier construcción del jugador por encima del relieve máximo
## (GeneradorMundo.ALTURA_MAXIMA = 15) y el subsuelo generado por debajo.
const ALTURA_BUSQUEDA_MAX := 50
const ALTURA_BUSQUEDA_MIN := -30

var generador: RefCounted

## Tipos de bloque que pueden formar parte de un edificio declarado (ver
## detectar_estructura()). "piso" queda deliberadamente fuera: es un
## material de terreno/relleno (ver _generar_terreno() y el modo de
## nivelación de CamaraCenital), nunca un material de construcción — para
## la PoC, el único material estructural es "pared" (más adelante: madera,
## piedra, metal, vidrio). Si el jugador usa "piso" para rellenar un hueco
## de terreno bajo su edificio, ese relleno no debe "pegarse" a la
## estructura declarada ni distorsionar su huella.
const TIPOS_ESTRUCTURA := [
	"pared", "puerta_inferior", "puerta_superior", "ventana",
	"cama_cabecera", "cama_pies", "baul",
]

const VECINOS_3D: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _id_por_tipo: Dictionary = {}  # String -> int
var _tipo_por_id: Dictionary = {}  # int -> String

## Celdas colocadas por el jugador (Vector3i -> true). El terreno generado por
## _generar_terreno() nunca se marca aquí, así que "declarar un edificio"
## (ver Player.gd) nunca puede incluir el suelo del mundo como parte de la
## estructura, sin importar su tipo de bloque.
var colocado_por_jugador: Dictionary = {}

## Vínculo bidireccional entre las dos celdas de un objeto multi-celda
## (puerta: 2 celdas verticales; cama: 2 celdas horizontales). Minar
## cualquiera de las dos celdas borra ambas — ver minar_bloque().
var pareja: Dictionary = {}  # Vector3i -> Vector3i


func _ready() -> void:
	cell_size = Vector3.ONE * TAMANO_CELDA
	_indexar_biblioteca()
	generador = GeneradorMundo.new(SEMILLA_MUNDO, ANCHO_MUNDO, LARGO_MUNDO)
	_generar_terreno()


func _indexar_biblioteca() -> void:
	for id in mesh_library.get_item_list():
		var nombre: String = mesh_library.get_item_name(id)
		_id_por_tipo[nombre] = id
		_tipo_por_id[id] = nombre


## Genera el mundo una única vez al arrancar la escena: para cada columna
## (x, z) coloca la celda de superficie ("piso", reutilizando el bloque
## caminable existente) y el subsuelo debajo (tierra cerca de la
## superficie, piedra más profundo, o vetas de "hierro" en la capa profunda
## — ver GeneradorMundo.tipo_en_profundidad), y si la columna queda por
## debajo del nivel de mar, agrega bloques "agua" encima de la superficie
## hasta ese nivel (ver GeneradorMundo.es_agua_en/nivel_mar).
## Ninguna de estas celdas se marca colocado_por_jugador: el terreno del
## mundo nunca puede ser parte de un edificio declarado por el jugador.
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var y: int = altura - profundidad
				var tipo: String = generador.tipo_en_profundidad(x, y, z, profundidad)
				colocar_bloque(Vector3i(x, y, z), tipo)
			if generador.es_agua_en(x, z):
				for y_agua in range(altura + 1, generador.nivel_mar + 1):
					colocar_bloque(Vector3i(x, y_agua, z), "agua")


## Altura de la celda sólida más alta en la columna (x, z) del mundo REAL —
## no la del ruido original de GeneradorMundo, que nunca se actualiza tras
## minar, construir o nivelar. Usada por los overlays visuales (ZonaOverlay,
## huella fantasma de nivelación) y por NiveladorTerreno (se le pasa esta
## instancia de VoxelWorld en vez de "generador" para que razone sobre el
## relieve real, no el original) — de otro modo, cualquier zona pintada u
## huella de nivelación sobre una celda ya modificada por el jugador se veía
## a una altura "fantasma" que no correspondía a ningún bloque real.
func altura_en(x: int, z: int) -> int:
	for y in range(ALTURA_BUSQUEDA_MAX, ALTURA_BUSQUEDA_MIN, -1):
		if get_cell_item(Vector3i(x, y, z)) != GridMap.INVALID_CELL_ITEM:
			return y
	return generador.altura_en(x, z)  # respaldo, no debería alcanzarse nunca


func colocar_bloque(celda: Vector3i, tipo: String, por_jugador: bool = false) -> bool:
	if get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
		return false
	if not _id_por_tipo.has(tipo):
		return false
	set_cell_item(celda, _id_por_tipo[tipo])
	if por_jugador:
		colocado_por_jugador[celda] = true
	return true


func minar_bloque(celda: Vector3i) -> bool:
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	return true


func obtener_tipo(celda: Vector3i) -> String:
	return _tipo_por_id.get(get_cell_item(celda), "")


func _celda_libre(celda: Vector3i) -> bool:
	return get_cell_item(celda) == GridMap.INVALID_CELL_ITEM


## Coloca una puerta de 2 celdas verticales: "base" es la mitad inferior,
## la superior se agrega automáticamente encima. Falla (sin colocar nada)
## si cualquiera de las dos celdas ya está ocupada.
func colocar_puerta(base: Vector3i) -> bool:
	var arriba := base + Vector3i(0, 1, 0)
	if not (_celda_libre(base) and _celda_libre(arriba)):
		return false
	colocar_bloque(base, "puerta_inferior", true)
	colocar_bloque(arriba, "puerta_superior", true)
	pareja[base] = arriba
	pareja[arriba] = base
	return true


## Coloca una cama de 2 celdas horizontales: "base" es la cabecera,
## "direccion" (un vector cardinal, ver Player._direccion_cardinal) indica
## hacia dónde queda el pie de la cama. Falla si falta espacio en cualquiera
## de las dos celdas.
func colocar_cama(base: Vector3i, direccion: Vector3i) -> bool:
	var pies := base + direccion
	if not (_celda_libre(base) and _celda_libre(pies)):
		return false
	colocar_bloque(base, "cama_cabecera", true)
	colocar_bloque(pies, "cama_pies", true)
	pareja[base] = pies
	pareja[pies] = base
	return true


## Flood-fill 3D (6-conectividad) sobre bloques ESTRUCTURALES (ver
## TIPOS_ESTRUCTURA) colocados por el jugador, partiendo de "origen". No
## razona sobre espacio/aire transitable: dos habitaciones con puertas
## propias, cada una cerrada, quedan igualmente unidas si sus paredes se
## tocan físicamente con el pasillo que las conecta. Un bloque de "piso"
## colocado por el jugador (p.ej. relleno de terreno bajo el edificio) ni se
## incluye ni propaga el flood-fill, aunque sea colocado_por_jugador.
## Devuelve {} si "origen" no es un bloque estructural colocado por el
## jugador (p.ej. es terreno, o es "piso").
func detectar_estructura(origen: Vector3i) -> Dictionary:
	if not es_celda_estructural(origen):
		return {}

	var visitados: Dictionary = {}  # Vector3i -> String (tipo)
	var pendientes: Array = [origen]
	while not pendientes.is_empty():
		var actual: Vector3i = pendientes.pop_back()
		if visitados.has(actual) or not es_celda_estructural(actual):
			continue
		visitados[actual] = obtener_tipo(actual)
		for delta in VECINOS_3D:
			var vecino: Vector3i = actual + delta
			if not visitados.has(vecino):
				pendientes.append(vecino)
	return visitados


## Pública (no solo para detectar_estructura): también la usa ZonaOverlay.gd
## para no pintar el overlay de zona sobre el techo de un edificio — un
## bloque "piso" de relleno de terreno (nunca estructural, ver TIPOS_
## ESTRUCTURA) sigue contando como parte del terreno para esto.
func es_celda_estructural(celda: Vector3i) -> bool:
	return colocado_por_jugador.get(celda, false) and TIPOS_ESTRUCTURA.has(obtener_tipo(celda))
