extends Node

## Autoload "Zonificacion": estado puro y lógica de la zona de influencia y
## las zonas pintables (Núcleo A/Núcleo B) sobre el grid XZ. Sin class_name
## (colisionaría con el nombre del autoload, mismo motivo que Ciudad.gd). No
## depende de ningún nodo de escena — ver spec:
## docs/superpowers/specs/2026-09-07-zonificacion-design.md,
## docs/superpowers/specs/2026-09-11-deconstruccion-edificios-design.md
##
## Convención: Vector2i(x, z) para celdas del grid en planta — Vector2i no
## tiene componente .z, así que la coordenada mundial Z vive en el campo .y
## (misma convención que BlueprintValidator._parsear_celda).

## Margen del núcleo urbano — sin cambios, sigue siendo especial (no tiene
## "categoria", es el único ancla fija de la zona de influencia).
const MARGEN_ZONA_INFLUENCIA := 15

## Margen de ampliación de la zona de influencia por categoría de edificio
## (ver BlueprintValidator.estructura_a_blueprint(), campo "categoria") —
## residencial aporta menos alcance que investigación/industrial, y militar
## el mayor de los cuatro (después del núcleo). Categorías todavía no
## declarables en esta PoC (investigacion/industrial/militar: no existe
## ningún blueprint de esos tipos, "categoria" siempre vale "residencial"
## por ahora) quedan definidas igual, listas para cuando existan.
const MARGEN_POR_CATEGORIA := {
	"residencial": 6,
	"investigacion": 10,
	"industrial": 10,
	"militar": 12,
}
## Margen de respaldo si "categoria" no coincide con ninguna clave conocida
## — nunca debería ocurrir con blueprints reales (estructura_a_blueprint()
## siempre asigna una categoría válida), defensivo por si acaso.
const MARGEN_CATEGORIA_DEFECTO := 6

const ZONAS_PINTABLES := ["residencial_investigacion", "fabricacion_militar"]

## Valor especial de "tipo_zona_seleccionada" (ver CamaraCenital.gd, tecla
## `0`) que activa el modo BORRAR en vez de pintar — nunca aparece como
## valor real en "zonas" (consultar_zona() nunca lo devuelve), solo se usa
## como marcador de modo entre CamaraCenital.gd y despintar_zona().
const MARCADOR_BORRAR := "borrar"

## Tamaño del mundo en celdas (ancho en x, largo en z). Si no es ZERO,
## _caja_expandida() recorta toda caja de influencia a [0, ancho-1] x
## [0, largo-1], para que la zona nunca salga del mapa. ZERO = sin límite.
var limite_mundo := Vector2i.ZERO

var nucleo_declarado := false
var influencia_min := Vector2i.ZERO
var influencia_max := Vector2i.ZERO
var zonas: Dictionary = {}  # Vector2i(x,z) -> String

## Huella del núcleo urbano (fija desde declarar_nucleo(), nunca se quita —
## el núcleo no es deconstruible, ver spec de deconstrucción) y, por cada
## edificio que ha ampliado la zona desde entonces, su huella Y su margen
## (según su categoría en el momento de ampliar) — juntas son la base para
## recalcular influencia_min/influencia_max desde cero en
## _recalcular_influencia(), cada vez que se agrega (ampliar_influencia())
## o se quita (retirar_contribucion()) una.
var _huella_nucleo: Array = []
var _contribuciones: Dictionary = {}  # int (id de edificio) -> {"huella": Array, "margen": int, "caja": Dictionary}

## Caja delimitadora (min/max) del núcleo, expandida por MARGEN_ZONA_
## INFLUENCIA — calculada una sola vez en declarar_nucleo() (el núcleo no
## cambia nunca). Junto con la "caja" de cada contribución en
## _contribuciones, es la unidad real de la zona de influencia: cada
## edificio aporta SU PROPIA caja, y dentro_de_influencia() prueba la UNIÓN
## de todas, no una única caja que las contenga a todas (ver
## dentro_de_influencia()) — así un edificio nuevo cerca del borde de la
## zona la "abulta" hacia su propio lado, sin ensanchar toda la zona en
## las demás direcciones. influencia_min/influencia_max siguen siendo la
## caja delimitadora de TODO (unión de estas cajas), útil para acotar el
## recorrido de ZonaOverlay y para los mensajes de consola, pero ya no es
## lo que dentro_de_influencia() consulta.
var _caja_nucleo: Dictionary = {}


## Bootstrap del núcleo urbano: se llama una sola vez, cuando se declara el
## primer edificio residencial válido (ver Player.gd::_declarar_edificio).
## Llamadas repetidas se ignoran — el núcleo urbano no se puede redeclarar.
func declarar_nucleo(huella: Array) -> void:
	if nucleo_declarado:
		return
	_huella_nucleo = huella.duplicate()
	_caja_nucleo = _caja_expandida(_huella_nucleo, MARGEN_ZONA_INFLUENCIA)
	nucleo_declarado = true
	_recalcular_influencia()

	for celda in huella:
		zonas[celda] = "residencial_investigacion"


## Registra la huella de "id" (con el margen correspondiente a "categoria")
## como contribución a la zona de influencia y recalcula influencia_min/
## influencia_max desde cero (ver _recalcular_influencia()) — reemplaza el
## crecimiento incremental por uno recalculado siempre desde la base, para
## que retirar_contribucion() pueda reducir la zona correctamente más
## adelante. No-op si el núcleo todavía no fue declarado. "id" es el mismo
## que devuelve VoxelWorld.registrar_edificio() para ese edificio;
## "categoria" es blueprint["categoria"].
func ampliar_influencia(id: int, huella: Array, categoria: String) -> void:
	if not nucleo_declarado:
		return
	var margen: int = MARGEN_POR_CATEGORIA.get(categoria, MARGEN_CATEGORIA_DEFECTO)
	_contribuciones[id] = {
		"huella": huella.duplicate(),
		"margen": margen,
		"caja": _caja_expandida(huella, margen),
	}
	_recalcular_influencia()


## Quita la contribución de "id" (ver ampliar_influencia()) y recalcula la
## zona de influencia desde cero — puede REDUCIRLA, a diferencia de
## ampliar_influencia(). Se llama al completarse la deconstrucción total de
## un edificio (ver VoxelWorld.eliminar_edificio()/Player.gd). No-op si
## "id" no tenía ninguna contribución registrada (p. ej. el edificio nunca
## amplió la zona porque ya estaba contenida en ella).
func retirar_contribucion(id: int) -> void:
	if not _contribuciones.has(id):
		return
	_contribuciones.erase(id)
	_recalcular_influencia()


## Caja delimitadora (min/max) de "huella" expandida por "margen" en las 4
## direcciones — unidad básica de la zona de influencia: el núcleo y cada
## edificio aportan SU PROPIA caja (ver _caja_nucleo/_contribuciones),
## nunca una caja compartida.
func _caja_expandida(huella: Array, margen: int) -> Dictionary:
	var min_x: int = huella[0].x - margen
	var max_x: int = huella[0].x + margen
	var min_z: int = huella[0].y - margen
	var max_z: int = huella[0].y + margen
	for celda in huella:
		min_x = min(min_x, celda.x - margen)
		max_x = max(max_x, celda.x + margen)
		min_z = min(min_z, celda.y - margen)
		max_z = max(max_z, celda.y + margen)
	if limite_mundo != Vector2i.ZERO:
		min_x = max(min_x, 0)
		min_z = max(min_z, 0)
		max_x = min(max_x, limite_mundo.x - 1)
		max_z = min(max_z, limite_mundo.y - 1)
	return {"min": Vector2i(min_x, min_z), "max": Vector2i(max_x, max_z)}


func _celda_en_caja(celda: Vector2i, caja: Dictionary) -> bool:
	return (
		celda.x >= caja["min"].x and celda.x <= caja["max"].x
		and celda.y >= caja["min"].y and celda.y <= caja["max"].y
	)


## Recalcula influencia_min/influencia_max como la caja delimitadora de
## TODAS las cajas vigentes (núcleo + cada contribución) — solo sirve para
## acotar el recorrido de ZonaOverlay y los mensajes de consola;
## dentro_de_influencia() ya NO consulta este rectángulo (ver más abajo).
func _recalcular_influencia() -> void:
	var min_x: int = _caja_nucleo["min"].x
	var max_x: int = _caja_nucleo["max"].x
	var min_z: int = _caja_nucleo["min"].y
	var max_z: int = _caja_nucleo["max"].y
	for contribucion in _contribuciones.values():
		var caja: Dictionary = contribucion["caja"]
		min_x = min(min_x, caja["min"].x)
		max_x = max(max_x, caja["max"].x)
		min_z = min(min_z, caja["min"].y)
		max_z = max(max_z, caja["max"].y)
	influencia_min = Vector2i(min_x, min_z)
	influencia_max = Vector2i(max_x, max_z)


## true si "celda" cae dentro de la caja expandida del núcleo O de la de
## CUALQUIER contribución individual — la UNIÓN de las cajas, no la caja
## que las contiene a todas (esa es influencia_min/influencia_max, que ya
## no se usa aquí). Así, un edificio nuevo cerca del borde de la zona la
## "abulta" hacia su propio lado sin ensanchar toda la zona en las demás
## direcciones — la forma real puede dejar de ser rectangular.
func dentro_de_influencia(celda: Vector2i) -> bool:
	if not nucleo_declarado:
		return false
	if _celda_en_caja(celda, _caja_nucleo):
		return true
	for contribucion in _contribuciones.values():
		if _celda_en_caja(celda, contribucion["caja"]):
			return true
	return false


## true si "celda" (X,Z) pertenece a la huella del núcleo urbano — usada
## por Player.gd para negarse a deconstruir el núcleo (exento, ver spec de
## deconstrucción). No expone _huella_nucleo directamente para no acoplar
## a los demás lectores a su representación interna.
func celda_es_del_nucleo(celda: Vector2i) -> bool:
	return _huella_nucleo.has(celda)


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


## Borra cualquier zona pintada dentro del rectángulo entre las dos
## esquinas (inclusive) — inverso de pintar_zona(). Devuelve cuántas
## celdas tenían realmente una zona pintada y se borraron (celdas que ya
## no tenían ninguna zona no cuentan).
func despintar_zona(esquina_a: Vector2i, esquina_b: Vector2i) -> int:
	var x_min: int = min(esquina_a.x, esquina_b.x)
	var x_max: int = max(esquina_a.x, esquina_b.x)
	var z_min: int = min(esquina_a.y, esquina_b.y)
	var z_max: int = max(esquina_a.y, esquina_b.y)

	var borradas := 0
	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			var celda := Vector2i(x, z)
			if zonas.has(celda):
				zonas.erase(celda)
				borradas += 1
	return borradas
