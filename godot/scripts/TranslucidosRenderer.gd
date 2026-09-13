extends Node3D

## Dibuja la geometría visible de los bloques translúcidos (VoxelWorld.
## TIPOS_TRANSLUCIDOS: "agua", "ventana") con culling de caras internas —
## GridMap coloca la malla COMPLETA de un cubo por celda sin saber qué hay
## en las celdas vecinas, así que dos celdas translúcidas del mismo tipo
## pegadas dibujan ambas su cara compartida, y el alpha blend las combina
## en un "panel" visible (bug real, reportado jugando en vivo). Ver
## docs/superpowers/specs/2026-09-13-culling-caras-translucidas-design.md.
## GridMap sigue siendo la ÚNICA fuente de verdad para ocupación/colisión:
## los ítems "agua"/"ventana" de la MeshLibrary tienen una malla vacía
## (ver BlockLibrarySource.tscn), así que este nodo es todo lo que se ve.

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const MATERIAL_AGUA := preload("res://assets/mat_agua.tres")
const MATERIAL_VENTANA := preload("res://assets/mat_ventana.tres")

const CHUNK_SIZE := 16

## Para cada dirección cardinal (una de VoxelWorld.VECINOS_3D), los dos ejes
## tangentes [u, v] de la cara perpendicular a esa dirección, en el orden
## que da u×v == direccion (ver _esquinas_cara()) — así el sentido de
## dibujado (CCW visto desde la dirección) queda garantizado por
## construcción, no por prueba y error visual.
const _EJES_POR_DIRECCION := {
	Vector3i(1, 0, 0): [Vector3(0, 1, 0), Vector3(0, 0, 1)],
	Vector3i(-1, 0, 0): [Vector3(0, 0, 1), Vector3(0, 1, 0)],
	Vector3i(0, 1, 0): [Vector3(0, 0, 1), Vector3(1, 0, 0)],
	Vector3i(0, -1, 0): [Vector3(1, 0, 0), Vector3(0, 0, 1)],
	Vector3i(0, 0, 1): [Vector3(1, 0, 0), Vector3(0, 1, 0)],
	Vector3i(0, 0, -1): [Vector3(0, 1, 0), Vector3(1, 0, 0)],
}

## Asignado por VoxelWorld._ready() antes de llamar a reconstruir_todo() —
## ver Sección 6 del spec. Nunca null en uso real; en pruebas se asigna a
## mano sobre un VoxelWorld.new() fuera del árbol (mismo patrón que
## BlueprintValidatorTest.gd).
var voxel_world: Node

var _material_por_tipo: Dictionary = {}  # String -> Material
var _mesh_por_chunk: Dictionary = {}  # String -> Dictionary (Vector3i -> MeshInstance3D)


## Clave de chunk de "celda" — división de PISO real (floori()), no
## truncamiento, para que coordenadas negativas (el mundo las admite, ver
## VoxelWorld.ALTURA_BUSQUEDA_MIN) den chunks negativos consistentes en vez
## de "rebotar" hacia 0.
static func _chunk_de(celda: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(celda.x) / CHUNK_SIZE),
		floori(float(celda.y) / CHUNK_SIZE),
		floori(float(celda.z) / CHUNK_SIZE),
	)


## true si debe dibujarse la cara entre una celda de tipo "tipo_propio" (uno
## de VoxelWorld.TIPOS_TRANSLUCIDOS) y su vecino de tipo "tipo_vecino" ("" si
## el vecino está vacío). Se omite ÚNICAMENTE cuando ambos lados son del
## MISMO tipo translúcido — cualquier otra combinación (aire, sólido, u otro
## tipo translúcido distinto) sí se dibuja.
static func _cara_visible(tipo_propio: String, tipo_vecino: String) -> bool:
	return tipo_vecino != tipo_propio


## Las 4 esquinas (orden CCW visto desde "direccion") de la cara de un cubo
## unitario centrado en "centro", en la dirección "direccion". Función pura
## de geometría — no toca SurfaceTool ni GridMap, testable comparando el
## producto cruzado de sus dos primeras aristas contra "direccion".
static func _esquinas_cara(centro: Vector3, direccion: Vector3i) -> Array[Vector3]:
	var ejes: Array = _EJES_POR_DIRECCION[direccion]
	var u: Vector3 = ejes[0]
	var v: Vector3 = ejes[1]
	var normal := Vector3(direccion.x, direccion.y, direccion.z) * 0.5
	var centro_cara: Vector3 = centro + normal
	var esquinas: Array[Vector3] = [
		centro_cara - u * 0.5 - v * 0.5,
		centro_cara + u * 0.5 - v * 0.5,
		centro_cara + u * 0.5 + v * 0.5,
		centro_cara - u * 0.5 + v * 0.5,
	]
	return esquinas
