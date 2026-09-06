extends RefCounted
class_name BlueprintValidator

## Puerto a GDScript del validador de PoC 2 (ver PoC_2/). Mismas reglas,
## mismos mensajes de error, misma estructura de datos: un Blueprint parseado
## desde JSON es un Dictionary de Godot con la misma forma que el dict de
## Python (JSON.parse_string produce la misma jerarquía que json.loads).
## Deliberadamente NO lee el VoxelWorld en vivo: valida un Blueprint dado
## (por ahora, definido a mano o cargado de archivo), no detecta
## automáticamente qué bloques colocados forman un edificio — esa detección
## (flood-fill / reconocimiento de habitaciones) queda fuera de esta PoC.

const ZONAS_VALIDAS := ["residencial_investigacion", "fabricacion_militar", "periferia"]
const TIPOS_CELDA_SOLIDA := ["pared", "puerta", "ventana"]
const VECINOS_ORTOGONALES := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]


static func _parsear_celda(clave: String) -> Vector2i:
	var partes := clave.split(",")
	return Vector2i(int(partes[0]), int(partes[1]))


static func _huella(piso: Dictionary) -> Array:
	return piso["celdas"].keys()


static func validar_cerramiento(piso: Dictionary) -> Array:
	var errores: Array = []
	var celdas: Dictionary = piso["celdas"]
	var huella: Dictionary = {}  # Vector2i -> true, para búsqueda rápida
	for clave in celdas.keys():
		huella[_parsear_celda(clave)] = true

	for clave in celdas.keys():
		var pos: Vector2i = _parsear_celda(clave)
		var tipo: String = celdas[clave]
		var vecinos_ausentes: Array = []
		for delta in VECINOS_ORTOGONALES:
			if not huella.has(pos + delta):
				vecinos_ausentes.append(delta)

		if vecinos_ausentes.is_empty():
			continue  # celda interior, no es borde

		if not TIPOS_CELDA_SOLIDA.has(tipo):
			errores.append(
				"Piso %d: hueco en el perímetro en la celda (%d,%d), tipo '%s'"
				% [piso["nivel"], pos.x, pos.y, tipo]
			)
			continue

		if vecinos_ausentes.size() == 2:
			var d1: Vector2i = vecinos_ausentes[0]
			var d2: Vector2i = vecinos_ausentes[1]
			var es_perpendicular: bool = d1 != -d2
			if es_perpendicular and tipo != "pared":
				errores.append(
					"Piso %d: la esquina (%d,%d) debe ser 'pared', no '%s'"
					% [piso["nivel"], pos.x, pos.y, tipo]
				)

	return errores


static func validar_aberturas(piso: Dictionary) -> Array:
	var errores: Array = []
	var tipos_presentes: Array = piso["celdas"].values()
	if not tipos_presentes.has("puerta"):
		errores.append("Piso %d: falta al menos una puerta" % piso["nivel"])
	if not tipos_presentes.has("ventana"):
		errores.append("Piso %d: falta al menos una ventana" % piso["nivel"])
	return errores


## Regla de almacenamiento: al menos 1 baúl por cada cama EN TODO EL EDIFICIO,
## sin exigir que cada cama tenga "su" baúl emparejado por posición. Esto da
## libertad de diseño: un barracón puede tener varias camas juntas y una
## sola sección de lockers/baúles en otro punto del edificio, siempre que la
## cantidad total de baúles alcance.
static func validar_camas_y_almacenamiento(blueprint: Dictionary) -> Array:
	var total_camas := 0
	var total_baules := 0
	for piso in blueprint["pisos"]:
		total_camas += (piso.get("camas", []) as Array).size()
		for tipo in (piso["celdas"] as Dictionary).values():
			if tipo == "baul":
				total_baules += 1

	if total_camas == 0:
		return ["El Blueprint no tiene ninguna cama"]
	if total_baules < total_camas:
		return [
			"El Blueprint tiene %d cama(s) pero solo %d baúl(es); se requiere al menos 1 baúl por cama"
			% [total_camas, total_baules]
		]
	return []


static func validar_zona_permitida(blueprint: Dictionary) -> Array:
	var zona: String = blueprint.get("zona_permitida", "")
	if not ZONAS_VALIDAS.has(zona):
		return ["zona_permitida inválida o ausente: '%s'" % zona]
	return []


static func validar_colocacion(blueprint: Dictionary, zona_destino: String) -> Array:
	if blueprint["zona_permitida"] != zona_destino:
		return [
			"El Blueprint '%s' (zona: %s) no puede colocarse en la zona '%s'"
			% [blueprint["nombre"], blueprint["zona_permitida"], zona_destino]
		]
	return []


static func validar_evolucion(blueprint_nuevo: Dictionary, blueprint_anterior: Dictionary) -> Array:
	var errores: Array = []
	var huella_base_anterior: Array = _huella(blueprint_anterior["pisos"][0])
	for piso in blueprint_nuevo["pisos"]:
		for clave in _huella(piso):
			if not huella_base_anterior.has(clave):
				errores.append(
					"Piso %d de la nueva versión excede la huella de la planta base original" % piso["nivel"]
				)
				break
	return errores


static func validar_personalizacion_produccion(blueprint_modificado: Dictionary, blueprint_original: Dictionary) -> Array:
	var errores: Array = []
	var huella_mod: Array = _huella(blueprint_modificado["pisos"][0])
	var huella_orig: Array = _huella(blueprint_original["pisos"][0])
	huella_mod.sort()
	huella_orig.sort()
	if huella_mod != huella_orig:
		errores.append("La personalización modificó la huella del edificio de producción")
	if (blueprint_modificado.get("conexiones", []) as Array).size() != (blueprint_original.get("conexiones", []) as Array).size():
		errores.append("La personalización modificó el número de conexiones (entradas/salidas)")
	return errores


## Convierte el resultado de VoxelWorld.detectar_estructura() (Vector3i -> tipo)
## en un Blueprint listo para validar_blueprint(). Agrupa por altura (Y) en
## "pisos" y normaliza las coordenadas x/z a locales al edificio (mínimo = 0).
##
## Remapeo de tipos físicos (VoxelWorld) a tipos abstractos (Blueprint):
## - "puerta_inferior" -> "puerta": el modelo de validación ya conoce "puerta"
##   como celda sólida de 1x1 por piso; la mitad inferior es la que representa
##   la abertura a nivel de piso.
## - "puerta_superior" se OMITE por completo: es solo el volumen de altura de
##   la puerta (2 celdas verticales), no aporta información nueva a la planta
##   abstracta. Incluirla obligaría a que cada "piso" del Blueprint dejara de
##   ser una sola capa de Y — cambio de modelo que se pospuso deliberadamente
##   (ver conversación de diseño: la altura mínima por piso queda documentada
##   en el GDD, no validada en código todavía).
## - "cama_cabecera"/"cama_pies" se guardan como celdas no sólidas (como
##   "piso", deben quedar en el interior de la planta) y la cabecera además
##   genera una entrada en la lista "camas" de su piso. "baul" (bloque físico
##   de 1 celda) pasa sin remapeo — validar_camas_y_almacenamiento() cuenta
##   cuántas celdas "baul" hay en todo el edificio, sin exigir emparejamiento
##   por posición con ninguna cama en particular.
##
## ponytail: zona_permitida se fija a un valor válido de relleno porque esta
## PoC no tiene zonificación real todavía (esa es Fase 2) — sin esto,
## validar_zona_permitida() rechazaría cualquier estructura detectada. Cuando
## exista zonificación, pasar la zona real del terreno donde se construyó.
static func estructura_a_blueprint(celdas: Dictionary) -> Dictionary:
	var celdas_relevantes: Dictionary = {}
	for pos in celdas.keys():
		if celdas[pos] != "puerta_superior":
			celdas_relevantes[pos] = celdas[pos]
	if celdas_relevantes.is_empty():
		return {}

	var y_min: int = celdas_relevantes.keys()[0].y
	var x_min: int = celdas_relevantes.keys()[0].x
	var z_min: int = celdas_relevantes.keys()[0].z
	for pos in celdas_relevantes.keys():
		y_min = min(y_min, pos.y)
		x_min = min(x_min, pos.x)
		z_min = min(z_min, pos.z)

	var celdas_por_nivel: Dictionary = {}  # int -> Dictionary ("x,z" -> tipo)
	var camas_por_nivel: Dictionary = {}  # int -> Array de {"pos"}
	for pos in celdas_relevantes.keys():
		var nivel: int = pos.y - y_min
		var clave := "%d,%d" % [pos.x - x_min, pos.z - z_min]
		var tipo: String = celdas_relevantes[pos]
		if tipo == "puerta_inferior":
			tipo = "puerta"

		if not celdas_por_nivel.has(nivel):
			celdas_por_nivel[nivel] = {}
			camas_por_nivel[nivel] = []
		celdas_por_nivel[nivel][clave] = tipo
		if tipo == "cama_cabecera":
			camas_por_nivel[nivel].append({"pos": clave})

	var niveles: Array = celdas_por_nivel.keys()
	niveles.sort()
	var pisos: Array = []
	for nivel in niveles:
		pisos.append({"nivel": nivel, "celdas": celdas_por_nivel[nivel], "camas": camas_por_nivel[nivel]})

	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
	}


static func validar_blueprint(
	blueprint: Dictionary,
	zona_destino: String = "",
	blueprint_anterior: Dictionary = {},
	blueprint_original_produccion: Dictionary = {}
) -> Dictionary:
	var errores: Array = []

	for piso in blueprint["pisos"]:
		errores.append_array(validar_cerramiento(piso))
		errores.append_array(validar_aberturas(piso))

	errores.append_array(validar_camas_y_almacenamiento(blueprint))
	errores.append_array(validar_zona_permitida(blueprint))

	if zona_destino != "":
		errores.append_array(validar_colocacion(blueprint, zona_destino))
	if not blueprint_anterior.is_empty():
		errores.append_array(validar_evolucion(blueprint, blueprint_anterior))
	if blueprint.get("tipo", "") == "produccion" and not blueprint_original_produccion.is_empty():
		errores.append_array(validar_personalizacion_produccion(blueprint, blueprint_original_produccion))

	return {"valido": errores.is_empty(), "errores": errores}
