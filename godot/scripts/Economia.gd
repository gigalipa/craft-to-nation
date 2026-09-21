extends Node

## Autoload "Economia": producción y acarreo de los puestos de recolección
## (sub-proyecto 2A, ver docs/superpowers/specs/2026-09-21-economia-puestos-
## produccion-acarreo-design.md). Estado y reglas puros, sin escena (mismo
## patrón que Ciudad.gd/Recoleccion.gd): guarda por puesto sus trabajadores,
## su almacén local y sus tasas, y produce una hora de juego por cada
## Ciudad.tick_simulado. El movimiento físico de los colonos (ir al puesto,
## recoger, llevar al núcleo) lo ejecuta Colonos.gd, que llama a
## marcar_presente(), recoger() y entregar(). "ciudad" es inyectable para
## probar sin escena (EconomiaTest.gd).

## Ids de los colonos que se quedaron sin puesto porque este se quitó
## (Colonos.gd los vuelve a desempleado).
signal puesto_quitado(ids: Array)

## Unidades que un acarreador lleva por viaje (placeholder). Con ~20 celdas de ruta
## un acarreador mueve ~16 comida/h, es decir 1 acarreador por cada 2 recolectores;
## los puestos más lejanos rinden menos.
const CAPACIDAD_CARGA := 150.0

const ROLES := ["recolector", "acarreador"]

## Las tasas de un puesto usan las claves de Recoleccion.tasas_*(); estas cuatro
## son formas de obtener comida y se suman en el recurso "comida". El resto de
## claves (minerales, "madera") ya son el nombre del recurso.
const RECURSO_DE_TASA := {
	"caza": "comida", "recoleccion": "comida",
	"pesca": "comida", "frutos_mar": "comida",
}

var ciudad: Object = null  # Ciudad

## Vector2i (esquina de la huella) -> {"tipo", "ancho", "alto", "cupo",
## "capacidad", "tasas" (clave de tasa -> unidades por recolector y hora),
## "recolectores": Array[int], "acarreadores": Array[int],
## "presentes": Dictionary (id de recolector -> true),
## "almacen": Dictionary (recurso -> float)}.
var puestos: Dictionary = {}
## id de colono -> esquina del puesto donde trabaja.
var _puesto_de: Dictionary = {}


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	ciudad.tick_simulado.connect(simular_hora)


## Registra un puesto recién colocado, sin trabajadores. "tasas" son las de
## Recoleccion.tasas_*() calculadas al colocarlo (no se recalculan mientras no
## haya agotamiento de recursos).
func registrar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int, tasas: Dictionary) -> void:
	puestos[esquina] = {
		"tipo": tipo, "ancho": ancho, "alto": alto,
		"cupo": Recoleccion.cupo_de(tipo),
		"capacidad": Recoleccion.capacidad_almacen_de(tipo),
		"tasas": tasas.duplicate(),
		"recolectores": [], "acarreadores": [],
		"presentes": {}, "almacen": {},
	}


## Quita el puesto (se deconstruyó): su almacén local se pierde y sus
## trabajadores quedan libres; se avisa con puesto_quitado. No-op si no existe.
func quitar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var ids: Array = p["recolectores"] + p["acarreadores"]
	for id in ids:
		_puesto_de.erase(id)
	puestos.erase(esquina)
	puesto_quitado.emit(ids)


func tiene_puesto(esquina: Vector2i) -> bool:
	return puestos.has(esquina)


## Celdas (X,Z) de la huella del puesto; [] si no existe.
func huella_de(esquina: Vector2i) -> Array:
	if not puestos.has(esquina):
		return []
	var celdas: Array = []
	for dx in range(puestos[esquina]["ancho"]):
		for dz in range(puestos[esquina]["alto"]):
			celdas.append(Vector2i(esquina.x + dx, esquina.y + dz))
	return celdas


func cupo_libre(esquina: Vector2i) -> int:
	if not puestos.has(esquina):
		return 0
	var p: Dictionary = puestos[esquina]
	return p["cupo"] - p["recolectores"].size() - p["acarreadores"].size()


## Asigna un colono a un puesto con un rol. Falso si el puesto no existe, el
## rol no es válido, el cupo está lleno o el colono ya trabaja en algún puesto.
func asignar(esquina: Vector2i, rol: String, colono_id: int) -> bool:
	if not puestos.has(esquina) or not ROLES.has(rol) or _puesto_de.has(colono_id):
		return false
	if cupo_libre(esquina) <= 0:
		return false
	puestos[esquina]["recolectores" if rol == "recolector" else "acarreadores"].append(colono_id)
	_puesto_de[colono_id] = esquina
	return true


## Quita a un colono de su puesto (despido o muerte). No-op si no trabaja.
func liberar(colono_id: int) -> void:
	if not _puesto_de.has(colono_id):
		return
	var p: Dictionary = puestos[_puesto_de[colono_id]]
	p["recolectores"].erase(colono_id)
	p["acarreadores"].erase(colono_id)
	p["presentes"].erase(colono_id)
	_puesto_de.erase(colono_id)


## El último colono asignado con ese rol, o -1: a quien despide el panel.
func ultimo_de(esquina: Vector2i, rol: String) -> int:
	if not puestos.has(esquina):
		return -1
	var lista: Array = puestos[esquina]["recolectores" if rol == "recolector" else "acarreadores"]
	return lista.back() if not lista.is_empty() else -1


## Un recolector está (o deja de estar) en su puesto: solo entonces produce.
## Ignora a quien no sea recolector asignado.
func marcar_presente(colono_id: int, presente: bool) -> void:
	if not _puesto_de.has(colono_id):
		return
	var p: Dictionary = puestos[_puesto_de[colono_id]]
	if not p["recolectores"].has(colono_id):
		return
	if presente:
		p["presentes"][colono_id] = true
	else:
		p["presentes"].erase(colono_id)


func trabajadores_de(esquina: Vector2i) -> Dictionary:
	if not puestos.has(esquina):
		return {"recolectores": 0, "acarreadores": 0, "presentes": 0}
	var p: Dictionary = puestos[esquina]
	return {
		"recolectores": p["recolectores"].size(),
		"acarreadores": p["acarreadores"].size(),
		"presentes": p["presentes"].size(),
	}


## Unidades por hora de cada recurso con los recolectores presentes ahora.
func produccion_por_hora(esquina: Vector2i) -> Dictionary:
	var resultado: Dictionary = {}
	if not puestos.has(esquina):
		return resultado
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	for clave in p["tasas"]:
		var recurso: String = RECURSO_DE_TASA.get(clave, clave)
		resultado[recurso] = resultado.get(recurso, 0.0) + p["tasas"][clave] * presentes
	return resultado


func almacen_local(esquina: Vector2i) -> Dictionary:
	return puestos[esquina]["almacen"].duplicate() if puestos.has(esquina) else {}


static func _total(almacen: Dictionary) -> float:
	var total := 0.0
	for v in almacen.values():
		total += v
	return total


## Una hora de juego de producción en todos los puestos: cada recolector
## presente suma su tasa al almacén local. Si el total local llegaría a
## pasar de la capacidad, solo entra lo que cabe, en proporción (el exceso se
## pierde: la producción se frena contra el tope y avisa de que falta acarreo).
func simular_hora() -> void:
	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		var producido: Dictionary = produccion_por_hora(esquina)
		var total_producido := _total(producido)
		if total_producido <= 0.0:
			continue
		var espacio: float = p["capacidad"] - _total(p["almacen"])
		if espacio <= 0.0:
			continue
		var factor: float = minf(1.0, espacio / total_producido)
		for recurso in producido:
			p["almacen"][recurso] = p["almacen"].get(recurso, 0.0) + producido[recurso] * factor


## Un acarreador que está en el puesto pide su carga: hasta "capacidad"
## unidades, repartidas por recurso en el orden del almacén. Solo se la dan si
## el almacén ya tiene la carga completa, o si no hay recolectores presentes
## y queda algo (así ningún resto queda atascado ni se hacen viajes de una
## unidad mientras se sigue produciendo). {} si no se cumple.
func recoger(esquina: Vector2i, capacidad: float) -> Dictionary:
	if not puestos.has(esquina):
		return {}
	var p: Dictionary = puestos[esquina]
	var total := _total(p["almacen"])
	if total <= 1e-9:
		return {}
	if total < capacidad and not p["presentes"].is_empty():
		return {}
	var carga: Dictionary = {}
	var restante := capacidad
	for recurso in p["almacen"].keys():
		if restante <= 1e-9:
			break
		var tomado: float = minf(p["almacen"][recurso], restante)
		carga[recurso] = tomado
		restante -= tomado
		p["almacen"][recurso] -= tomado
		if p["almacen"][recurso] <= 1e-9:
			p["almacen"].erase(recurso)
	return carga


## Un acarreador llegó al núcleo urbano: suma su carga al stock central. Lo
## que no cabe (stock lleno) se pierde.
func entregar(carga: Dictionary) -> void:
	for recurso in carga:
		if ciudad.almacen.has(recurso):
			ciudad.almacen[recurso].agregar(carga[recurso])
