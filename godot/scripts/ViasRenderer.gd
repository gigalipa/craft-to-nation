extends Node3D

## Overlay visual de los tramos PLANOS de vía (ver spec de vías Sección
## 3): una malla delgada pegada a la cara superior de cada celda de
## soporte registrada en Vias.celdas, salvo que el soporte sea una cuña
## (esa ya es la superficie visible). Mismo patrón de chunks que
## TranslucidosRenderer.gd — reconstruye solo el chunk sucio; reutiliza su
## geometría de cara (_agregar_cara()) en vez de reimplementarla.

const TranslucidosRenderer = preload("res://scripts/TranslucidosRenderer.gd")

const CHUNK_SIZE := 16
const DESF := 0.5
const ARRIBA := Vector3i(0, 1, 0)

## Asignado por VoxelWorld._ready() antes de llamar a reconstruir_todo() —
## mismo patrón que TranslucidosRenderer.voxel_world.
var voxel_world: Node

var _mesh_por_chunk: Dictionary = {}  # Vector3i -> MeshInstance3D
var _chunks_sucios: Dictionary = {}  # Vector3i -> true


static func _chunk_de(celda: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(celda.x) / CHUNK_SIZE),
		floori(float(celda.y) / CHUNK_SIZE),
		floori(float(celda.z) / CHUNK_SIZE),
	)


func _reconstruir_chunk(chunk: Vector3i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origen: Vector3i = chunk * CHUNK_SIZE
	var hay_caras := false
	for dx in range(CHUNK_SIZE):
		for dy in range(CHUNK_SIZE):
			for dz in range(CHUNK_SIZE):
				var celda: Vector3i = origen + Vector3i(dx, dy, dz)
				if not Vias.es_via(celda):
					continue
				var tipo: String = voxel_world.obtener_tipo(celda)
				if tipo == "cuna_recta" or tipo == "cuna_esquina":
					continue
				TranslucidosRenderer._agregar_cara(st, Vector3(celda) + Vector3.ONE * DESF, ARRIBA)
				hay_caras = true

	if not hay_caras:
		if _mesh_por_chunk.has(chunk):
			_mesh_por_chunk[chunk].queue_free()
			_mesh_por_chunk.erase(chunk)
		return

	var malla: ArrayMesh = st.commit()
	var instancia: MeshInstance3D
	if _mesh_por_chunk.has(chunk):
		instancia = _mesh_por_chunk[chunk]
	else:
		instancia = MeshInstance3D.new()
		add_child(instancia)
		_mesh_por_chunk[chunk] = instancia
	instancia.mesh = malla
	instancia.set_surface_override_material(0, Vias.TIPOS["tierra_pisada"]["material"])


## Reconstrucción completa — llamada una vez desde VoxelWorld._ready().
func reconstruir_todo() -> void:
	var chunks: Dictionary = {}
	for celda: Vector3i in Vias.celdas:
		chunks[_chunk_de(celda)] = true
	for chunk in chunks:
		_reconstruir_chunk(chunk)


## Conectada a Vias.vias_cambiadas desde VoxelWorld._ready() — mismo
## motivo que TranslucidosRenderer._on_bloque_translucido_cambiado(): no
## reconstruye de inmediato, solo marca sucio (ver flush_pendientes()).
func _on_vias_cambiadas(celdas: Array) -> void:
	for celda: Vector3i in celdas:
		_chunks_sucios[_chunk_de(celda)] = true


func flush_pendientes() -> void:
	for chunk in _chunks_sucios:
		_reconstruir_chunk(chunk)
	_chunks_sucios.clear()


func _process(_delta: float) -> void:
	flush_pendientes()
