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

## Mismo desfase que CamaraCenital.gd/ZonaOverlay.gd: una celda "celda"
## ocupa el rango [celda, celda+1] en cada eje, así que su CENTRO real está
## en celda + DESF, no en celda — ver _reconstruir_chunk().
const DESF := 0.5

## Dirección "arriba" — el agua solo dibuja su cara superior (ver
## _cara_visible()); el resto de direcciones nunca se dibujan para agua.
const ARRIBA := Vector3i(0, 1, 0)

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
var _chunks_sucios: Dictionary = {}  # Vector3i -> true, ver _on_bloque_translucido_cambiado()


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


## true si debe dibujarse la cara de tipo "tipo_propio" (uno de
## VoxelWorld.TIPOS_TRANSLUCIDOS) hacia la dirección "direccion", contra un
## vecino de tipo "tipo_vecino" ("" si está vacío). Dos reglas, en orden:
##
## 1. Un vecino SÓLIDO (ocupado y no translúcido) oculta SIEMPRE la cara, sin
##    excepción — bug real, encontrado jugando en vivo: esa cara queda
##    exactamente coincidente con la propia cara opaca del sólido (que ya
##    cubre esa unión por completo), así que dibujarla solo produce
##    parpadeo/moiré (z-fighting) sin aportar nada visible.
## 2. Para "agua" específicamente, el resto de la regla no depende del
##    vecino en absoluto, solo de la dirección: la cara de ARRIBA se dibuja
##    SIEMPRE (incluso contra otra celda de agua encima — a propósito: una
##    columna profunda apila varias caras superiores reales, una por celda,
##    y su alpha se combina al verlas desde arriba, dando la impresión de
##    que la opacidad aumenta con la profundidad sin necesitar ningún truco
##    de color por vértice); cualquier otra dirección (laterales y abajo)
##    NUNCA se dibuja, ni siquiera contra aire — decisión de diseño pedida
##    jugando en vivo (docs/superpowers/specs/2026-09-13-culling-caras-
##    translucidas-design.md).
## 3. Para cualquier otro tipo translúcido (p. ej. "ventana"), se mantiene
##    la regla original: se omite solo contra el MISMO tipo (cara interna de
##    una misma pared de ventanas); contra aire o un tipo translúcido
##    distinto, se dibuja.
static func _cara_visible(tipo_propio: String, tipo_vecino: String, direccion: Vector3i) -> bool:
	if tipo_vecino != "" and not VoxelWorld.TIPOS_TRANSLUCIDOS.has(tipo_vecino):
		return false
	if tipo_propio == "agua":
		return direccion == ARRIBA
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


## Carga los materiales de cada tipo translúcido — recursos independientes
## (ver mat_agua.tres/mat_ventana.tres), no leídos de mesh_library: una vez
## vacía la malla del ítem correspondiente (Task 4), ya no habría ninguna
## superficie de la que sacar el material original.
func _indexar_materiales() -> void:
	_material_por_tipo["agua"] = MATERIAL_AGUA
	_material_por_tipo["ventana"] = MATERIAL_VENTANA
	assert(_material_por_tipo.size() == VoxelWorld.TIPOS_TRANSLUCIDOS.size(), "cada tipo en VoxelWorld.TIPOS_TRANSLUCIDOS necesita un material aquí")


func _agregar_cara(st: SurfaceTool, centro: Vector3, direccion: Vector3i) -> void:
	var esquinas: Array[Vector3] = _esquinas_cara(centro, direccion)
	var normal := Vector3(direccion.x, direccion.y, direccion.z)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(esquinas[i])


## Reconstruye desde cero la malla de "chunk" para "tipo": recorre las
## CHUNK_SIZE³ celdas del chunk, y para cada celda de ese tipo agrega solo
## las caras que _cara_visible() aprueba contra cada uno de sus 6 vecinos
## (consultando voxel_world.obtener_tipo(), que cruza libremente el borde
## del chunk hacia chunks vecinos). Si el chunk queda sin ninguna cara para
## ese tipo, borra su MeshInstance3D si existía; si tiene al menos una,
## crea (la primera vez) o reutiliza su MeshInstance3D.
func _reconstruir_chunk(chunk: Vector3i, tipo: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origen: Vector3i = chunk * CHUNK_SIZE
	var hay_caras := false
	for dx in range(CHUNK_SIZE):
		for dy in range(CHUNK_SIZE):
			for dz in range(CHUNK_SIZE):
				var celda: Vector3i = origen + Vector3i(dx, dy, dz)
				if voxel_world.obtener_tipo(celda) != tipo:
					continue
				for direccion: Vector3i in VoxelWorld.VECINOS_3D:
					var vecino: Vector3i = celda + direccion
					var tipo_vecino: String = voxel_world.obtener_tipo(vecino)
					if not _cara_visible(tipo, tipo_vecino, direccion):
						continue
					_agregar_cara(st, Vector3(celda) + Vector3.ONE * DESF, direccion)
					hay_caras = true

	if not hay_caras:
		if _mesh_por_chunk.has(tipo) and _mesh_por_chunk[tipo].has(chunk):
			_mesh_por_chunk[tipo][chunk].queue_free()
			_mesh_por_chunk[tipo].erase(chunk)
		return

	var malla: ArrayMesh = st.commit()
	var instancia: MeshInstance3D
	if _mesh_por_chunk.has(tipo) and _mesh_por_chunk[tipo].has(chunk):
		instancia = _mesh_por_chunk[tipo][chunk]
	else:
		instancia = MeshInstance3D.new()
		add_child(instancia)
		if not _mesh_por_chunk.has(tipo):
			_mesh_por_chunk[tipo] = {}
		_mesh_por_chunk[tipo][chunk] = instancia
	instancia.mesh = malla
	instancia.set_surface_override_material(0, _material_por_tipo[tipo])


## Reconstrucción completa — llamada una única vez desde VoxelWorld._ready(),
## después de _generar_terreno() (Sección 5 del spec). Recorre
## get_used_cells() (nativo de GridMap, ya filtra a celdas ocupadas) UNA
## vez, agrupa por chunk, y reconstruye cada chunk afectado una sola vez —
## sin pasar por bloque_translucido_cambiado celda por celda durante la
## generación masiva inicial (miles de celdas de agua).
func reconstruir_todo() -> void:
	var chunks_por_tipo: Dictionary = {}  # String -> Dictionary (Vector3i -> true)
	for celda in voxel_world.get_used_cells():
		var tipo: String = voxel_world.obtener_tipo(celda)
		if not VoxelWorld.TIPOS_TRANSLUCIDOS.has(tipo):
			continue
		var chunk: Vector3i = _chunk_de(celda)
		if not chunks_por_tipo.has(tipo):
			chunks_por_tipo[tipo] = {}
		chunks_por_tipo[tipo][chunk] = true
	for tipo in chunks_por_tipo:
		for chunk in chunks_por_tipo[tipo]:
			_reconstruir_chunk(chunk, tipo)


## Conectado a VoxelWorld.bloque_translucido_cambiado desde VoxelWorld._ready()
## (Sección 6 del spec — NO desde el propio _ready() de este nodo, porque
## los hijos ejecutan _ready() antes que su padre, y "voxel_world" todavía
## no estaría asignado). Marca sucios el chunk de "celda" y los de sus 6
## vecinos directos (una celda en el borde de un chunk afecta el cálculo de
## caras expuestas del chunk vecino también) — NO reconstruye de inmediato:
## drenar_agua()/eliminar_edificio() (VoxelWorld.gd, ya existentes) emiten
## esta señal muchas veces en una sola acción del jugador (una columna de
## agua entera, un edificio completo), así que reconstruir en cada emisión
## rehace el mismo chunk una y otra vez dentro de esa misma acción. Ver
## flush_pendientes().
func _on_bloque_translucido_cambiado(celda: Vector3i) -> void:
	_chunks_sucios[_chunk_de(celda)] = true
	for delta: Vector3i in VoxelWorld.VECINOS_3D:
		_chunks_sucios[_chunk_de(celda + delta)] = true


## Reconstruye todos los chunks marcados sucios desde la última llamada, y
## limpia el registro — llamado desde _process() en juego real, y
## directamente por las pruebas para forzar el vaciado sin depender del
## bucle de frames (que no corre en instancias fuera del árbol).
func flush_pendientes() -> void:
	for chunk in _chunks_sucios:
		for tipo in VoxelWorld.TIPOS_TRANSLUCIDOS:
			_reconstruir_chunk(chunk, tipo)
	_chunks_sucios.clear()


func _process(_delta: float) -> void:
	flush_pendientes()
