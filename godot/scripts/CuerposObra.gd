extends Node3D

## Colisión de los bloques "fantasma" de cada obra. GridMap no permite
## colisión por celda ni por cara (su colisión sale de las formas del ítem de
## la MeshLibrary, en una sola capa por nodo), así que el ítem "fantasma" no
## lleva formas (ver VoxelWorld._indexar_biblioteca()) y la colisión la da un
## StaticBody3D POR OBRA con una caja por celda fantasma pendiente. Así quien
## tiene permiso de salida sobre una obra puede ignorar solo ESA obra con
## add_collision_exception_with(). Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Sección 6).
##
## Hijo de VoxelWorld (que está en el origen y usa celdas de 1x1x1, así que las
## coordenadas locales son las del mundo): la caja de la celda c está centrada
## en c + (0.5, 0.5, 0.5). Capa de colisión 1, la del mundo, para que el
## raycast del jugador y el picking de CamaraCenital los siga detectando.

var _caja := BoxShape3D.new()  # 1x1x1 por defecto; se comparte entre todas las formas
var _cuerpos: Dictionary = {}  # int (id de obra) -> StaticBody3D
var _formas: Dictionary = {}  # int -> Dictionary (Vector3i -> CollisionShape3D)


## Deja el cuerpo de la obra "id" con una caja por cada celda distinta de
## "celdas": añade las que faltan y quita las que sobran. Sin celdas libera el
## cuerpo por completo.
func sincronizar(id: int, celdas: Array) -> void:
	var deseadas: Dictionary = {}
	for celda: Vector3i in celdas:
		deseadas[celda] = true
	if deseadas.is_empty():
		liberar(id)
		return
	if not _cuerpos.has(id):
		var nuevo := StaticBody3D.new()
		nuevo.name = "Obra_%d" % id
		nuevo.collision_layer = 1
		add_child(nuevo)
		_cuerpos[id] = nuevo
		_formas[id] = {}
	var cuerpo: StaticBody3D = _cuerpos[id]
	var formas: Dictionary = _formas[id]
	for celda: Vector3i in formas.keys():
		if not deseadas.has(celda):
			var sobrante: CollisionShape3D = formas[celda]
			cuerpo.remove_child(sobrante)
			sobrante.free()
			formas.erase(celda)
	for celda: Vector3i in deseadas:
		if not formas.has(celda):
			var forma := CollisionShape3D.new()
			forma.shape = _caja
			forma.position = Vector3(celda) + Vector3(0.5, 0.5, 0.5)
			cuerpo.add_child(forma)
			formas[celda] = forma


## Usa free() inmediato (no queue_free) para poder recrear un cuerpo con el mismo
## id en el mismo frame; llamarla fuera de callbacks de consulta de física — hoy
## se invoca desde surtir/deconstruir en _physics_process, que está permitido.
func liberar(id: int) -> void:
	if not _cuerpos.has(id):
		return
	var cuerpo: StaticBody3D = _cuerpos[id]
	remove_child(cuerpo)
	cuerpo.free()
	_cuerpos.erase(id)
	_formas.erase(id)


func cuerpo_de(id: int) -> StaticBody3D:
	return _cuerpos.get(id, null)


func cantidad_formas(id: int) -> int:
	return _formas[id].size() if _formas.has(id) else 0
