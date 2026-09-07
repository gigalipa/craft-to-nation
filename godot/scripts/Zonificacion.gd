extends Node

## Autoload "Zonificacion": estado puro y lógica de la zona de influencia y
## las zonas pintables (Núcleo A/Núcleo B) sobre el grid XZ. Sin class_name
## (colisionaría con el nombre del autoload, mismo motivo que Ciudad.gd). No
## depende de ningún nodo de escena — ver spec:
## docs/superpowers/specs/2026-09-07-zonificacion-design.md
##
## Convención: Vector2i(x, z) para celdas del grid en planta — Vector2i no
## tiene componente .z, así que la coordenada mundial Z vive en el campo .y
## (misma convención que BlueprintValidator._parsear_celda).

const MARGEN_ZONA_INFLUENCIA := 15
const ZONAS_PINTABLES := ["residencial_investigacion", "fabricacion_militar"]

var nucleo_declarado := false
var influencia_min := Vector2i.ZERO
var influencia_max := Vector2i.ZERO
var zonas: Dictionary = {}  # Vector2i(x,z) -> String


## Bootstrap del núcleo urbano: se llama una sola vez, cuando se declara el
## primer edificio residencial válido (ver Player.gd::_declarar_edificio).
## Llamadas repetidas se ignoran — el núcleo urbano no se puede redeclarar.
func declarar_nucleo(huella: Array) -> void:
	if nucleo_declarado:
		return

	var x_min: int = huella[0].x
	var x_max: int = huella[0].x
	var z_min: int = huella[0].y
	var z_max: int = huella[0].y
	for celda in huella:
		x_min = min(x_min, celda.x)
		x_max = max(x_max, celda.x)
		z_min = min(z_min, celda.y)
		z_max = max(z_max, celda.y)

	influencia_min = Vector2i(x_min - MARGEN_ZONA_INFLUENCIA, z_min - MARGEN_ZONA_INFLUENCIA)
	influencia_max = Vector2i(x_max + MARGEN_ZONA_INFLUENCIA, z_max + MARGEN_ZONA_INFLUENCIA)
	nucleo_declarado = true

	for celda in huella:
		zonas[celda] = "residencial_investigacion"


func dentro_de_influencia(celda: Vector2i) -> bool:
	if not nucleo_declarado:
		return false
	return (
		celda.x >= influencia_min.x and celda.x <= influencia_max.x
		and celda.y >= influencia_min.y and celda.y <= influencia_max.y
	)


## Pinta el rectángulo entre las dos esquinas (inclusive), recortado a la
## zona de influencia. Devuelve cuántas celdas se pintaron realmente, para
## que quien llama (CamaraCenital.gd) pueda avisar si el rectángulo cayó
## total o parcialmente fuera de la zona de influencia.
func pintar_zona(esquina_a: Vector2i, esquina_b: Vector2i, tipo: String) -> int:
	if not ZONAS_PINTABLES.has(tipo):
		return 0

	var x_min: int = min(esquina_a.x, esquina_b.x)
	var x_max: int = max(esquina_a.x, esquina_b.x)
	var z_min: int = min(esquina_a.y, esquina_b.y)
	var z_max: int = max(esquina_a.y, esquina_b.y)

	var pintadas := 0
	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			var celda := Vector2i(x, z)
			if dentro_de_influencia(celda):
				zonas[celda] = tipo
				pintadas += 1
	return pintadas


func consultar_zona(celda: Vector2i) -> String:
	return zonas.get(celda, "periferia")
