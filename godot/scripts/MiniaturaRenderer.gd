extends RefCounted

## Renderizador de miniaturas 3D compartido: arma un SubViewport aislado con
## las piezas dadas (malla real + material real, como el bloque/edificio que
## representan) y una cámara ortográfica diagonal, y devuelve su textura.
## Extraído de Hotbar._renderizar_icono()/_malla_de_item() (2026-09-24) para
## que BarraModos.gd lo reutilice con construcciones completas en vez de un
## solo bloque — ver docs/superpowers/specs/2026-09-30-previsualizacion-
## construcciones-cenital-design.md, Sección 2. Sin class_name (mismo motivo
## que PlantillasPuesto.gd/Blueprints.gd: se carga con preload()).

const RUTA_BIBLIOTECA := "res://assets/BlockLibrary.res"
const RESOLUCION_ICONO := 128

## Nombre de tipo de juego -> nombre real del ítem en BlockLibrary.res,
## cuando difieren (hoy solo "adobe": el bloque se llama "tierra_compactada"
## en la biblioteca — ver VoxelWorld.RENOMBRE_BIBLIOTECA).
const NOMBRE_FISICO_BIBLIOTECA := {
	"adobe": "tierra_compactada",
}


## Copia propia de la MeshLibrary (CACHE_MODE_IGNORE): independiente de la
## que usa VoxelWorld en el mundo, para no heredar mutaciones que
## VoxelWorld._indexar_biblioteca() hace en el sitio (p. ej. vacía la malla
## de puerta_inferior/puerta_superior). Cada llamador cachea el resultado en
## su propia variable de instancia (ver Hotbar._biblioteca/BarraModos._biblioteca).
static func cargar_biblioteca() -> MeshLibrary:
	return ResourceLoader.load(RUTA_BIBLIOTECA, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE)


## Malla real del ítem "nombre_item" en "biblioteca", o null si no existe/no
## tiene malla (p. ej. vidrio, puerta_inferior/puerta_superior: malla vacía a
## propósito, ver VoxelWorld — esos tipos los dibuja otro sistema).
static func malla_de_item(biblioteca: MeshLibrary, nombre_item: String) -> Mesh:
	var nombre_fisico: String = NOMBRE_FISICO_BIBLIOTECA.get(nombre_item, nombre_item)
	for id in biblioteca.get_item_list():
		if biblioteca.get_item_name(id) == nombre_fisico:
			return biblioteca.get_item_mesh(id)
	return null


## Igual que renderizar(), pero devuelve el SubViewport en sí en vez de su
## textura — para que el llamador pueda quedarse con la referencia y
## liberarlo (queue_free()) cuando vuelva a renderizar la misma miniatura
## (ver BarraModos._actualizar_miniaturas()): sin esto, cada re-render deja
## un SubViewport (con su propio World3D, luces, cámara y mallas) huérfano
## colgado como hijo de "padre" para siempre — reporte de revisión,
## 2026-09-30. "piezas" es cada una [malla, posición relativa, material o
## null para el de la propia malla]. "direccion_camara" es la dirección
## diagonal de la cámara ortográfica respecto al centro del AABB combinado
## (p. ej. Vector3(1,1,1) para una diagonal simétrica, Vector3(1,1,-1) para
## la esquina superior-derecha-frontal de algo cuyo frente mira a -Z).
## "padre" es el Node ya en el árbol de escena donde se cuelga el
## SubViewport (hace falta estar en el árbol para que el motor lo
## renderice). UPDATE_ONCE: es una miniatura estática, no hace falta
## re-renderizarla cada frame.
static func renderizar_viewport(piezas: Array, direccion_camara: Vector3, padre: Node) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(RESOLUCION_ICONO, RESOLUCION_ICONO)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var aabb: AABB
	for i in range(piezas.size()):
		var malla: Mesh = piezas[i][0]
		var offset: Vector3 = piezas[i][1]
		var material_pieza: Material = piezas[i][2]
		var instancia := MeshInstance3D.new()
		instancia.mesh = malla
		instancia.position = offset
		if material_pieza != null:
			instancia.material_override = material_pieza
		viewport.add_child(instancia)
		var caja := AABB(malla.get_aabb().position + offset, malla.get_aabb().size)
		aabb = caja if i == 0 else aabb.merge(caja)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	viewport.add_child(luz)
	var relleno := DirectionalLight3D.new()
	relleno.light_energy = 0.4
	relleno.rotation_degrees = Vector3(-20.0, 145.0, 0.0)
	viewport.add_child(relleno)

	var centro := aabb.get_center()
	var radio: float = maxf(0.2, aabb.get_longest_axis_size()) * 0.85
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = radio * 2.0
	camara.position = centro + direccion_camara * radio
	viewport.add_child(camara)
	padre.add_child(viewport)
	camara.look_at(centro, Vector3.UP)

	return viewport


## Atajo de renderizar_viewport() para quien no necesita la referencia al
## SubViewport (p. ej. Hotbar.gd, que cachea el ícono para siempre y nunca
## lo re-renderiza, así que no hay nada que liberar).
static func renderizar(piezas: Array, direccion_camara: Vector3, padre: Node) -> Texture2D:
	return renderizar_viewport(piezas, direccion_camara, padre).get_texture()
