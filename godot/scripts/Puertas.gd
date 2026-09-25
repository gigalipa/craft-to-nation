extends Node3D

## Puertas interactivas: una lámina fina (1 x 2 x 0.1) por puerta, con su propio
## cuerpo de colisión. Las celdas siguen siendo puerta_inferior/puerta_superior
## en VoxelWorld (su ítem de la MeshLibrary no dibuja ni colisiona); aquí vive
## solo el estado abierta/cerrada. Abrir gira la lámina 90° sobre su eje
## vertical central: de cubrir el hueco (capa 1, bloquea) a verse de canto
## (capa 4, el avatar la atraviesa pero el raycast del jugador aún la apunta).
## Ver docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md.
##
## Hijo de VoxelWorld (en el origen, celdas de 1x1x1): coordenadas locales =
## coordenadas del mundo. Clave de cada puerta: su celda INFERIOR.

const LAMINA := Vector3(1, 2, 0.1)
const CAPA_CERRADA := 1  # capa 1: mundo (bloquea al avatar)
const CAPA_ABIERTA := 8  # capa 4: solo el raycast del jugador
const META_CELDA := "celda_puerta"
const RADIO_APERTURA := 2  # celdas (Chebyshev en XZ): abre antes de que el colono llegue
const INTERVALO := 0.25  # segundos entre chequeos de proximidad

var voxel_world: Node

## Quién aporta el diccionario "colonos" (id -> {"celda": Vector3i}); null =
## el autoload Colonos. Las pruebas inyectan una fuente falsa.
var fuente_colonos: Object = null

var _acumulado := 0.0

var _puertas: Dictionary = {}  # Vector3i (celda inferior) -> Dictionary
var _forma := BoxShape3D.new()
var _malla := BoxMesh.new()
var _material := StandardMaterial3D.new()


func _init() -> void:
	_forma.size = LAMINA
	_malla.size = LAMINA
	_material.albedo_color = Color(0.82, 0.42, 0.0)
	_malla.material = _material


func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado >= INTERVALO:
		_acumulado = 0.0
		tick()


## Un chequeo: recalcula la orientación de cada puerta (las paredes de una obra
## pueden aparecer después) y abre/cierra según los colonos cercanos. Una puerta
## abierta a mano (manual) nunca se cierra sola.
func tick() -> void:
	var fuente: Object = fuente_colonos if fuente_colonos != null else Colonos
	var colonos: Dictionary = fuente.colonos
	for base: Vector3i in _puertas:
		var puerta: Dictionary = _puertas[base]
		var cerca := _hay_colono_cerca(base, colonos)
		if cerca and not puerta["abierta"]:
			puerta["abierta"] = true
			puerta["manual"] = false
		elif not cerca and puerta["abierta"] and not puerta["manual"]:
			puerta["abierta"] = false
		actualizar(base)


func _hay_colono_cerca(base: Vector3i, colonos: Dictionary) -> bool:
	for colono: Dictionary in colonos.values():
		var celda: Vector3i = colono["celda"]
		if absi(celda.x - base.x) <= RADIO_APERTURA and absi(celda.z - base.z) <= RADIO_APERTURA \
				and absi(celda.y - base.y) <= 1:
			return true
	return false


func existe(base: Vector3i) -> bool:
	return _puertas.has(base)


func esta_abierta(base: Vector3i) -> bool:
	return _puertas.has(base) and _puertas[base]["abierta"]


func cuerpo_de(base: Vector3i) -> StaticBody3D:
	return _puertas[base]["cuerpo"] if _puertas.has(base) else null


## Alterna la puerta con celda inferior "base". Abrir a mano la deja abierta
## hasta que se cierre a mano (manual = true); cerrar limpia ese estado.
func alternar(base: Vector3i) -> bool:
	if not _puertas.has(base):
		return false
	var puerta: Dictionary = _puertas[base]
	puerta["abierta"] = not puerta["abierta"]
	puerta["manual"] = puerta["abierta"]
	actualizar(base)
	return true


## Celda inferior de la puerta a la que pertenece "colisionador" (el objeto que
## devuelve RayCast3D.get_collider()), o Vector3i.MAX si no es una puerta.
func celda_de_colisionador(colisionador: Object) -> Vector3i:
	if colisionador is StaticBody3D and (colisionador as StaticBody3D).has_meta(META_CELDA):
		return (colisionador as StaticBody3D).get_meta(META_CELDA)
	return Vector3i.MAX


## Recalcula orientación, giro y capa de la puerta "base" según su estado.
func actualizar(base: Vector3i) -> void:
	var puerta: Dictionary = _puertas[base]
	var cuerpo: StaticBody3D = puerta["cuerpo"]
	var giro: float = 0.0 if _pared_por_x(base) else PI / 2.0
	if puerta["abierta"]:
		giro += PI / 2.0
	cuerpo.rotation.y = giro
	cuerpo.collision_layer = CAPA_ABIERTA if puerta["abierta"] else CAPA_CERRADA


func _on_puerta_cambiada(celda: Vector3i) -> void:
	var tipo: String = voxel_world.obtener_tipo(celda)
	if tipo == "puerta_inferior":
		_sincronizar(celda)
	elif tipo == "puerta_superior":
		_sincronizar(celda + Vector3i(0, -1, 0))
	else:
		# La celda dejó de ser puerta: cae la puerta de la que era mitad.
		_quitar(celda)
		_quitar(celda + Vector3i(0, -1, 0))


func _sincronizar(base: Vector3i) -> void:
	var completa: bool = voxel_world.obtener_tipo(base) == "puerta_inferior" \
			and voxel_world.obtener_tipo(base + Vector3i(0, 1, 0)) == "puerta_superior"
	if completa and not _puertas.has(base):
		_crear(base)
	elif not completa:
		_quitar(base)


func _crear(base: Vector3i) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Puerta_%d_%d_%d" % [base.x, base.y, base.z]
	cuerpo.collision_mask = 0
	cuerpo.position = Vector3(base) + Vector3(0.5, 1.0, 0.5)
	cuerpo.set_meta(META_CELDA, base)
	var malla := MeshInstance3D.new()
	malla.mesh = _malla
	cuerpo.add_child(malla)
	var forma := CollisionShape3D.new()
	forma.shape = _forma
	cuerpo.add_child(forma)
	add_child(cuerpo)
	_puertas[base] = {"abierta": false, "manual": false, "cuerpo": cuerpo}
	actualizar(base)


## free() inmediato (como CuerposObra.liberar()): se llama desde el minado o la
## deconstrucción, fuera de callbacks de consulta de física.
func _quitar(base: Vector3i) -> void:
	if not _puertas.has(base):
		return
	var cuerpo: StaticBody3D = _puertas[base]["cuerpo"]
	remove_child(cuerpo)
	cuerpo.free()
	_puertas.erase(base)


## true si las dos celdas laterales en X de la puerta están ocupadas (la pared
## corre por X) y no lo están las de Z; con ambos pares, o con ninguno, se toma X.
## Un fantasma cuenta como pared (una obra puede surtir la puerta antes que sus
## paredes; el chequeo periódico recalcula cuando aparecen).
func _pared_por_x(base: Vector3i) -> bool:
	var por_x: bool = _ocupada(base + Vector3i(1, 0, 0)) and _ocupada(base + Vector3i(-1, 0, 0))
	var por_z: bool = _ocupada(base + Vector3i(0, 0, 1)) and _ocupada(base + Vector3i(0, 0, -1))
	return por_x or not por_z


func _ocupada(celda: Vector3i) -> bool:
	var tipo: String = voxel_world.obtener_tipo(celda)
	return tipo != "" and tipo != "agua"
