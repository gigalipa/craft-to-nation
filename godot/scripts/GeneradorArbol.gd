extends RefCounted

## Generación procedural de la forma de un árbol (tronco + follaje) y su
## registro de salud/tala — sin nodos de escena. Ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md.
## Sin class_name (mismo motivo que GeneradorMundo.gd/Zonificacion.gd:
## evitar el bug de caché de clases globales de Godot) — se usa vía
## preload().new().

const ALTURA_TRONCO_MIN := 3
const ALTURA_TRONCO_MAX := 8
const RADIO_TRONCO_MIN := 1
const RADIO_TRONCO_MAX := 4
const RADIO_FOLLAJE_MIN := 1
const RADIO_FOLLAJE_MAX := 2


## Forma procedural determinista de un árbol: tronco recto (cilindro de
## radio variable) rematado por una copa esférica de follaje. La misma
## semilla_arbol produce siempre la misma altura de tronco, el mismo radio
## de tronco, el mismo radio de follaje y exactamente los mismos offsets.
## Devuelve un Dictionary Vector3i -> String ("tronco" o "follaje"), con
## offsets relativos a la base del árbol (Vector3i(0,0,0) es el centro de
## la capa de tronco más baja).
func generar_forma_aleatoria(semilla_arbol: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla_arbol
	var altura_tronco: int = rng.randi_range(ALTURA_TRONCO_MIN, ALTURA_TRONCO_MAX)
	var radio_tronco: int = rng.randi_range(RADIO_TRONCO_MIN, RADIO_TRONCO_MAX)
	var radio_follaje: int = rng.randi_range(RADIO_FOLLAJE_MIN, RADIO_FOLLAJE_MAX)

	var forma: Dictionary = {}
	for y in range(altura_tronco):
		for dx in range(-radio_tronco, radio_tronco + 1):
			for dz in range(-radio_tronco, radio_tronco + 1):
				if dx * dx + dz * dz <= radio_tronco * radio_tronco:
					forma[Vector3i(dx, y, dz)] = "tronco"

	var centro_follaje := Vector3i(0, altura_tronco, 0)
	for dx in range(-radio_follaje, radio_follaje + 1):
		for dy in range(-radio_follaje, radio_follaje + 1):
			for dz in range(-radio_follaje, radio_follaje + 1):
				if dx * dx + dy * dy + dz * dz <= radio_follaje * radio_follaje:
					var offset: Vector3i = centro_follaje + Vector3i(dx, dy, dz)
					if not forma.has(offset):
						forma[offset] = "follaje"

	return forma
