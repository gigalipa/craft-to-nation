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
const EPSILON_Y := 0.01  # margen contra z-fighting, ver I3 de la revisión final

## Tipos de cuña cuya propia superficie ya es la cara visible — no llevan
## overlay plano encima (ver spec Sección 3 y el sistema de rampa
## diagonal completo).
const TIPOS_CUNA := ["cuna_recta", "cuna_esquina", "cuna_diag_bajo", "cuna_diag_arriba", "cuna_diag_lat_izq", "cuna_diag_lat_der", "diag_lat"]

## Las 4 esquinas LOCALES de una celda (0 o 1 en cada eje), en el orden
## que usa Vias.notch_en() — ver notches_de_paso().
const ESQUINAS_CELDA: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]

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


## Dibuja un triángulo en la cara superior de "celda" en vez del cuadrado
## completo — las 3 esquinas de ESQUINAS_CELDA distintas de
## "esquina_omitida" (ver Vias.notch_en(), spec de vías Sección 1). Sin
## reutilizar _agregar_cara() de TranslucidosRenderer: esa siempre dibuja
## las 4 esquinas del cuadrado, no sirve para un triángulo. Sin
## preocuparse por el sentido de bobinado — mat_tierra_pisada.tres tiene
## cull_mode = CULL_DISABLED (ver I3 de la revisión final).
func _agregar_triangulo_notch(st: SurfaceTool, celda: Vector3i, esquina_omitida: Vector2i) -> void:
	var y: float = float(celda.y) + 1.0 + EPSILON_Y
	var normal := Vector3.UP
	for esquina in ESQUINAS_CELDA:
		if esquina == esquina_omitida:
			continue
		st.set_normal(normal)
		st.add_vertex(Vector3(celda.x + esquina.x, y, celda.z + esquina.y))


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
				if TIPOS_CUNA.has(tipo):
					continue
				var esquina_omitida: Vector2i = Vias.notch_en(celda)
				if esquina_omitida != Vector2i(-1, -1):
					_agregar_triangulo_notch(st, celda, esquina_omitida)
				else:
					# +0.01 en Y: sin este margen el overlay queda exactamente
					# coplanar con la cara superior del terreno -> z-fighting
					# (ver I3 de la revisión final; mismo margen que usan
					# ZonaOverlay.gd/ViaPreviewOverlay.gd para el mismo problema).
					TranslucidosRenderer._agregar_cara(st, Vector3(celda) + Vector3.ONE * DESF + Vector3(0, 0.01, 0), ARRIBA)
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
