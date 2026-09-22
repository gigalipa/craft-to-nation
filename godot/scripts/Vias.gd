extends Node

## Autoload "Vias": estado puro y catálogo de las vías (ver GDD Sección 4,
## docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md). Sin
## class_name (colisionaría con el nombre del autoload, mismo motivo que
## Ciudad.gd/Zonificacion.gd). No depende de ningún nodo de escena.
##
## Convención: Vector2i(x, z) para columnas en planta — la coordenada
## mundial Z vive en el campo .y (misma convención que Zonificacion.gd).

## Catálogo por datos. Único tipo implementado: "tierra_pisada". Tipos
## futuros (calzada, vía férrea, cintas, tuberías, calzada peatonal — ver
## GDD Sección 3.1/4) se agregan aquí como filas nuevas cuando se
## implementen, nunca antes.
var TIPOS: Dictionary = {
	"tierra_pisada": {
		"ancho": 2,
		"sentido": "doble",
		"bono_velocidad": 1.35,
		"costo": {},
		"material": preload("res://assets/mat_tierra_pisada.tres"),
	},
}

## Celda de SOPORTE (el bloque que lleva la vía en su cara superior:
## terreno nivelado, relleno, o una cuna_recta/cuna_esquina) -> tipo.
var celdas: Dictionary = {}  # Vector3i -> String

## Índice derivado de "celdas" por columna XZ, para hay_via_en_columna()
## sin recorrer "celdas" entero — mantenido en agregar()/quitar().
var _columnas: Dictionary = {}  # Vector2i -> int (cuántas celdas de esa columna hay en "celdas")

## Emitida cuando agregar()/quitar() cambian el registro — ViasRenderer la
## escucha para reconstruir solo los chunks afectados (ver spec Sección 3).
signal vias_cambiadas(celdas: Array)


func es_via(soporte: Vector3i) -> bool:
	return celdas.has(soporte)


func tipo_en(soporte: Vector3i) -> String:
	return celdas.get(soporte, "")


## Multiplicador de velocidad de la celda de SOPORTE "soporte" (el bloque
## bajo los pies, no la celda donde está parado el personaje) — 1.0 si no
## es vía. Ver spec Sección 7.
func bono_en(soporte: Vector3i) -> float:
	if not es_via(soporte):
		return 1.0
	return TIPOS[tipo_en(soporte)]["bono_velocidad"]


func hay_via_en_columna(xz: Vector2i) -> bool:
	return _columnas.get(xz, 0) > 0


func agregar(celdas_nuevas: Array, tipo: String) -> void:
	for celda: Vector3i in celdas_nuevas:
		if not celdas.has(celda):
			var xz := Vector2i(celda.x, celda.z)
			_columnas[xz] = _columnas.get(xz, 0) + 1
		celdas[celda] = tipo
	vias_cambiadas.emit(celdas_nuevas)


func quitar(celdas_a_quitar: Array) -> void:
	var quitadas: Array = []
	for celda: Vector3i in celdas_a_quitar:
		if not celdas.has(celda):
			continue
		celdas.erase(celda)
		var xz := Vector2i(celda.x, celda.z)
		_columnas[xz] = _columnas.get(xz, 1) - 1
		if _columnas[xz] <= 0:
			_columnas.erase(xz)
		quitadas.append(celda)
	if not quitadas.is_empty():
		vias_cambiadas.emit(quitadas)
