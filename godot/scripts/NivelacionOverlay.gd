extends Node3D

## Overlays de la previsualización del blueprint (ver
## docs/superpowers/specs/2026-09-20-nivelacion-frente-y-overlays-design.md):
## (1) las celdas RESERVADAS delante de puertas y ventanas — cajas cian, y
## rojas las bloqueadas por un árbol, una estructura u otro edificio; (2) la
## región NIVELADA — un plano por columna a ras del terreno actual, naranja
## donde se cava, azul donde se rellena y verde tenue donde ya está a nivel.
## Solo visual: CamaraCenital.gd calcula los datos y llama a mostrar()/
## ocultar(); este nodo no conoce el mundo.

## Mismo desfase que CamaraCenital.gd: una celda "celda" ocupa
## [celda, celda+1] en cada eje, así que su centro real está en celda + DESF.
const DESF := 0.5

## Altura de los planos sobre la Y del bloque superior de la columna: un poco
## por encima de los planos de puesto (1.01) y de las zonas pintadas.
const ALTURA_PLANO := 1.02

## Un poco menor que la celda para que la caja no compita con las caras del
## terreno que la rodea.
const TAMANO_CAJA := 0.96

const COLOR_RESERVADA := Color(0.2, 0.9, 1.0, 0.35)
const COLOR_BLOQUEADA := Color(1.0, 0.2, 0.2, 0.5)
const COLOR_REGION := {
	"cavar": Color(1.0, 0.5, 0.1, 0.35),
	"rellenar": Color(0.2, 0.5, 1.0, 0.35),
	"nivel": Color(0.3, 1.0, 0.4, 0.25),
}

var _nodos: Array[MeshInstance3D] = []
var _malla_caja := BoxMesh.new()
var _malla_plano := PlaneMesh.new()


func _init() -> void:
	_malla_caja.size = Vector3.ONE * TAMANO_CAJA
	_malla_plano.size = Vector2(1.0, 1.0)


## "reservadas": Array de {"celda": Vector3i, "bloqueada": bool}. "region":
## Array de {"columna": Vector2i, "y": int, "accion": String}. Reemplaza lo que
## hubiera dibujado antes.
func mostrar(reservadas: Array, region: Array) -> void:
	ocultar()
	for r: Dictionary in reservadas:
		var celda: Vector3i = r["celda"]
		var color: Color = COLOR_BLOQUEADA if r["bloqueada"] else COLOR_RESERVADA
		_agregar(_malla_caja, color, Vector3(celda) + Vector3(DESF, DESF, DESF))
	for p: Dictionary in region:
		var columna: Vector2i = p["columna"]
		_agregar(_malla_plano, COLOR_REGION[p["accion"]], Vector3(columna.x + DESF, p["y"] + ALTURA_PLANO, columna.y + DESF))


func ocultar() -> void:
	for nodo in _nodos:
		nodo.queue_free()
	_nodos.clear()


## Un puñado de nodos por actualización (y solo cuando cambia la esquina), así
## que se recrean todos en vez de mantener un pool.
func _agregar(malla: Mesh, color: Color, posicion: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.material_override = material
	nodo.top_level = true
	nodo.position = posicion
	add_child(nodo)
	_nodos.append(nodo)
