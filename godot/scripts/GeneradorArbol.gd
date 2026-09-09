extends RefCounted

## Generación procedural de la forma de un árbol (tronco + follaje) y su
## registro de salud/tala — sin nodos de escena. Ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md.
## Sin class_name (mismo motivo que GeneradorMundo.gd/Zonificacion.gd:
## evitar el bug de caché de clases globales de Godot) — se usa vía
## preload().new().

const ALTURA_TRONCO_MIN := 3
const ALTURA_TRONCO_MAX := 8
const LADO_TRONCO_MIN := 1
const LADO_TRONCO_MAX := 2

var _siguiente_id := 0
var _arboles: Dictionary = {}  # int -> {"celdas": Array, "salud": int}
var _celda_a_arbol: Dictionary = {}  # Vector3i -> int


## Elige (altura_tronco, lado_tronco, radio_follaje) deterministamente a
## partir de semilla_arbol — usado tanto por generar_forma_aleatoria() como
## por medir_pisada(), para que ambas coincidan siempre en el mismo árbol
## (mismo orden de llamadas a RandomNumberGenerator, así que el mismo
## semilla_arbol produce siempre los mismos tres valores en ambas).
func _elegir_parametros(semilla_arbol: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla_arbol
	var altura_tronco: int = rng.randi_range(ALTURA_TRONCO_MIN, ALTURA_TRONCO_MAX)
	var lado_tronco: int = rng.randi_range(LADO_TRONCO_MIN, LADO_TRONCO_MAX)
	# El radio de follaje es proporcional al lado del tronco (no un rango
	# propio independiente) para que la copa nunca quede más angosta que
	# el tronco que la sostiene — placeholder simple; a futuro esta
	# relación podrá variar por tipo de bioma (selva húmeda vs. sabana).
	var radio_follaje: int = lado_tronco
	return {
		"altura_tronco": altura_tronco,
		"lado_tronco": lado_tronco,
		"radio_follaje": radio_follaje,
	}


## Tamaño que tendría el árbol de semilla_arbol (altura/lado de tronco,
## radio de follaje) sin construir la forma completa — usado por
## VoxelWorld para decidir si un árbol candidato cabe (espaciado) antes de
## generarlo y colocarlo de verdad. Mismos valores que usará
## generar_forma_aleatoria() para la misma semilla_arbol.
func medir_pisada(semilla_arbol: int) -> Dictionary:
	return _elegir_parametros(semilla_arbol)


## Forma procedural determinista de un árbol: tronco recto cuadrado (lado
## variable en columnas, no un disco euclidiano) rematado por una copa
## esférica de follaje. La misma semilla_arbol produce siempre la misma
## altura de tronco, el mismo lado de tronco, el mismo radio de follaje y
## exactamente los mismos offsets. Devuelve un Dictionary Vector3i ->
## String ("madera" o "follaje" — "madera" es el tipo de bloque/recurso
## real que ocupa el tronco; solo "madera" cuenta como recurso extraíble,
## "follaje" es cosmético), con offsets relativos a la base del árbol
## (Vector3i(0,0,0) es la esquina de la capa de tronco más baja).
func generar_forma_aleatoria(semilla_arbol: int) -> Dictionary:
	var parametros: Dictionary = _elegir_parametros(semilla_arbol)
	var altura_tronco: int = parametros["altura_tronco"]
	var lado_tronco: int = parametros["lado_tronco"]
	var radio_follaje: int = parametros["radio_follaje"]

	var forma: Dictionary = {}
	for y in range(altura_tronco):
		for dx in range(lado_tronco):
			for dz in range(lado_tronco):
				forma[Vector3i(dx, y, dz)] = "madera"

	# Centro del cuadrado del tronco (aproximado por división entera —
	# suficiente para un placeholder; con lado par el centro cae medio
	# bloque desviado hacia la esquina (0,0), no exactamente en el medio).
	@warning_ignore("integer_division")
	var centro_xz: int = (lado_tronco - 1) / 2
	var centro_follaje := Vector3i(centro_xz, altura_tronco, centro_xz)
	for dx in range(-radio_follaje, radio_follaje + 1):
		for dy in range(-radio_follaje, radio_follaje + 1):
			for dz in range(-radio_follaje, radio_follaje + 1):
				if dx * dx + dy * dy + dz * dz <= radio_follaje * radio_follaje:
					var offset: Vector3i = centro_follaje + Vector3i(dx, dy, dz)
					if not forma.has(offset):
						forma[offset] = "follaje"

	return forma


## Registra un árbol nuevo con las celdas mundiales dadas (tronco y
## follaje) y la salud máxima indicada (número de celdas "madera" — ver
## generar_forma_aleatoria()). Devuelve el id asignado.
func registrar(celdas_mundiales: Array, salud_maxima: int) -> int:
	var id: int = _siguiente_id
	_siguiente_id += 1
	_arboles[id] = {"celdas": celdas_mundiales, "salud": salud_maxima}
	for celda in celdas_mundiales:
		_celda_a_arbol[celda] = id
	return id


## -1 si la celda no pertenece a ningún árbol registrado.
func obtener_arbol_de(celda: Vector3i) -> int:
	return _celda_a_arbol.get(celda, -1)


## Todas las celdas mundiales (tronco y follaje) del árbol con ese id.
## Array vacío si el id no existe (p. ej. ya fue eliminado).
func celdas_de(id: int) -> Array:
	if not _arboles.has(id):
		return []
	return _arboles[id]["celdas"].duplicate()


## Resta "dano" a la salud del árbol "id". Devuelve true si la salud quedó
## en 0 o menos (árbol completamente talado) — no borra bloques ni el
## registro, eso es responsabilidad del llamador (ver VoxelWorld.
## talar_bloque_de_arbol()).
func danar(id: int, dano: int) -> bool:
	if not _arboles.has(id):
		return false
	_arboles[id]["salud"] -= dano
	return _arboles[id]["salud"] <= 0


## Limpia el registro del árbol "id": su entrada y todas sus celdas del
## índice inverso.
func eliminar(id: int) -> void:
	if not _arboles.has(id):
		return
	for celda in _arboles[id]["celdas"]:
		_celda_a_arbol.erase(celda)
	_arboles.erase(id)
