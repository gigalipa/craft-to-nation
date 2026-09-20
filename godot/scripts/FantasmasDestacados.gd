extends Node3D

## Marca con un color propio las puertas y ventanas de los edificios en
## construcción que todavía son bloques "fantasma" (ver
## docs/superpowers/specs/2026-09-20-destacar-puertas-ventanas-fantasma-design.md).
## "fantasma" es un solo tipo de la MeshLibrary y GridMap no admite material
## por celda, así que esto dibuja una caja translúcida de color ENCIMA de
## cada celda destacada — solo visual: GridMap sigue siendo la única fuente
## de verdad de ocupación/colisión.
## También dibuja un marcador fantasma azul sobre las celdas pendientes que aún están ocupadas por agua o follaje (una celda guarda un solo bloque, no admite un fantasma real; ver docs/superpowers/specs/2026-09-20-drenado-y-follaje-progresivos-design.md).
## Mismo patrón que TranslucidosRenderer:
## VoxelWorld._ready() asigna "voxel_world" y conecta la señal.

## Mismo desfase que CamaraCenital.gd/TranslucidosRenderer.gd: una celda
## "celda" ocupa [celda, celda+1] en cada eje, así que su centro real está
## en celda + DESF.
const DESF := 0.5

## Un poco más grande que la celda para no competir (z-fighting) con las
## caras del bloque "fantasma" que hay debajo.
const TAMANO_MARCADOR := 1.02

## Mismo azul translúcido del bloque "fantasma" (Mat_fantasma en
## BlockLibrarySource.tscn): el marcador hace que una celda ocupada por agua o
## follaje se lea como un fantasma más del edificio.
const COLOR_FANTASMA_OCUPADO := Color(0.6, 0.7, 1.0, 0.35)

## Asignado por VoxelWorld._ready() antes de conectar la señal. Nunca null
## en uso real.
var voxel_world: Node

var _sucio := false
var _marcadores: Array[MeshInstance3D] = []
var _malla := BoxMesh.new()


func _init() -> void:
	_malla.size = Vector3.ONE * TAMANO_MARCADOR


## Conectada a VoxelWorld.fantasmas_cambiados. Solo marca: la reconstrucción
## ocurre una vez por fotograma en _process(), sin importar cuántas veces se
## emita la señal (surtir con clic sostenido la emite muchas veces).
func marcar_sucio() -> void:
	_sucio = true


func _process(_delta: float) -> void:
	if not _sucio:
		return
	_sucio = false
	_reconstruir()


## Pocas celdas por edificio, así que se recrean todas en vez de mantener un pool.
func _reconstruir() -> void:
	for marcador in _marcadores:
		marcador.queue_free()
	_marcadores.clear()
	var destacadas: Dictionary = voxel_world.celdas_fantasma_destacadas()
	for celda: Vector3i in destacadas:
		_agregar_marcador(celda, voxel_world.COLOR_DESTACADO[destacadas[celda]])
	for celda: Vector3i in voxel_world.celdas_fantasma_ocupadas():
		_agregar_marcador(celda, COLOR_FANTASMA_OCUPADO)


func _agregar_marcador(celda: Vector3i, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var marcador := MeshInstance3D.new()
	marcador.mesh = _malla
	marcador.material_override = material
	marcador.position = Vector3(celda) + Vector3(DESF, DESF, DESF)
	add_child(marcador)
	_marcadores.append(marcador)
