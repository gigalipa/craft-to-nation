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
## Bloques "estructurales" (material de construcción: paredes, puertas,
## ventanas) vs. mobiliario (cama, baúl) vs. relleno de terreno ("piso").
## Se usa para reconocer losas de suelo/techo (ver
## _es_losa_parcial/_es_losa_completa). "piso" NUNCA es estructural, ni
## siquiera para una losa de suelo/techo: es material de terreno/relleno
## (ver VoxelWorld.TIPOS_ESTRUCTURA y _generar_terreno/nivelación), nunca un
## material de construcción — para la PoC el único material estructural es
## "pared" (más adelante: madera, piedra, metal, vidrio). Coincide, por
## tanto, con TIPOS_CELDA_SOLIDA (regla de perímetro 2D).
const TIPOS_ESTRUCTURALES := ["pared", "puerta", "ventana"]
## Relleno genérico sin significado especial a nivel de Blueprint: una celda
## con este tipo, heredada de la plantilla de suelo/techo (ver
## estructura_a_blueprint), siempre puede ser sobrescrita por el bloque real
## de una capa de pared (aunque ese bloque también sea "pared" liso) — solo
## un tipo ESPECIAL (puerta/ventana/cama/baúl) ya asignado se protege de ser
## pisado por un "pared" posterior. "piso" ya no puede aparecer aquí (nunca
## es estructural), pero VoxelWorld.detectar_estructura() ya excluye "piso"
## del flood-fill, así que este caso ni siquiera llega a estructura_a_blueprint().
const TIPOS_RELLENO_GENERICO := ["pared"]
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


## Solo estructura_a_blueprint() (ver más abajo) marca "suelo_completo"/
## "techo_completo" — un Blueprint hecho a mano (JSON, PoC 2) no los trae,
## y se asume true (no cambia el comportamiento de esos Blueprints, que
## nunca modelaron el techo en 3D). Comprueba que la historia detectada
## realmente tenga una losa sólida debajo (suelo propio, no aire) y otra
## encima (techo, o el suelo de la historia siguiente) — sin esto, un
## flood-fill podía dar "válido" a un edificio sin techo, porque la
## validación de cerramiento solo mira el perímetro en planta (X/Z), nunca
## si la construcción está cerrada verticalmente.
static func validar_techo_y_suelo(piso: Dictionary) -> Array:
	var errores: Array = []
	if not piso.get("suelo_completo", true):
		errores.append("Piso %d: falta un suelo sólido debajo" % piso["nivel"])
	if not piso.get("techo_completo", true):
		errores.append("Piso %d: falta un techo sólido encima" % piso["nivel"])
	return errores


## Altura mínima por piso: 3 capas de Y de historia habitable (sin contar la
## losa base/de suelo). El jugador puede hacer pisos más altos libremente,
## pero no más bajos — es el espacio que garantiza que la puerta (2 celdas)
## y la cama (con 2 celdas libres exigidas encima) siempre quepan. Solo
## estructura_a_blueprint() marca "altura_capas"; un Blueprint hecho a mano
## (JSON, PoC 2) no lo trae y se asume válido (3 por defecto).
const ALTURA_MINIMA_PISO := 3


static func validar_altura_piso(piso: Dictionary) -> Array:
	var altura: int = piso.get("altura_capas", ALTURA_MINIMA_PISO)
	if altura < ALTURA_MINIMA_PISO:
		return [
			"Piso %d: altura insuficiente (%d bloque(s)), mínimo %d"
			% [piso["nivel"], altura, ALTURA_MINIMA_PISO]
		]
	return []


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


## Una capa de Y es una "losa completa" (suelo base o techo exterior) si
## TODAS las columnas de la huella real (ver estructura_a_blueprint(), NO
## la caja delimitadora completa — un edificio en L no llena su caja) están
## presentes y son de un tipo ESTRUCTURAL (pared/puerta/ventana/piso). Se
## exige solo para la losa más baja (cimiento) y la más alta (techo
## exterior) del edificio completo — nunca deben tener huecos.
static func _es_losa_completa(capa: Dictionary, huella_real: Dictionary) -> bool:
	for clave in huella_real:
		var tipo = capa.get(clave)
		if tipo == null or not TIPOS_ESTRUCTURALES.has(tipo):
			return false
	return true


## Una columna de la huella real es "interior" si sus 4 vecinos ortogonales
## (VECINOS_ORTOGONALES) también pertenecen a la huella real — mismo
## criterio que ya usa validar_cerramiento() para decidir qué celda es
## borde. Generaliza "no está en el anillo perimetral de la caja
## delimitadora" (válido solo para un rectángulo) a cualquier forma.
static func _es_columna_interior(pos: Vector2i, huella_real: Dictionary) -> bool:
	for delta in VECINOS_ORTOGONALES:
		var vecino: Vector2i = pos + delta
		if not huella_real.has("%d,%d" % [vecino.x, vecino.y]):
			return false
	return true


## Una capa de Y es una "losa parcial" (borde entre dos historias, puede
## tener un hueco de escalera) si más de la mitad de sus columnas
## INTERIORES de la huella real (ver _es_columna_interior(), generaliza
## "excluyendo el anillo perimetral de la caja delimitadora" a cualquier
## forma) son de tipo estructural. Una capa de pared normal tiene el
## interior mayormente vacío (aire transitable, a lo sumo con mobiliario
## disperso: cama, baúl, que NO cuentan como estructurales), mientras que
## una losa de piso con hueco de escalera solo tiene un hueco pequeño en,
## por lo demás, una superficie sólida.
## Caso límite: si la huella real no tiene ninguna columna interior (huella
## demasiado angosta, en cualquier forma), no hay forma de distinguir por
## interior — se cae a exigir la losa completa.
static func _es_losa_parcial(capa: Dictionary, huella_real: Dictionary) -> bool:
	var interiores: Array = []
	for clave in huella_real:
		if _es_columna_interior(_parsear_celda(clave), huella_real):
			interiores.append(clave)
	if interiores.is_empty():
		return _es_losa_completa(capa, huella_real)
	var total_estructural := 0
	for clave in interiores:
		var tipo = capa.get(clave)
		if tipo != null and TIPOS_ESTRUCTURALES.has(tipo):
			total_estructural += 1
	return float(total_estructural) / float(interiores.size()) > 0.5


## Convierte el resultado de VoxelWorld.detectar_estructura() (Vector3i -> tipo)
## en un Blueprint listo para validar_blueprint(). Normaliza las coordenadas
## x/z a locales al edificio (mínimo = 0).
##
## Remapeo de tipos físicos (VoxelWorld) a tipos abstractos (Blueprint):
## - "puerta_inferior" -> "puerta"; "puerta_superior" se omite (es solo el
##   volumen de altura de la puerta, no aporta información nueva).
## - "cama_cabecera"/"cama_pies" y "baul" pasan como celdas no sólidas.
##
## Agrupación en "pisos" (historias), NO por cada capa de Y por separado:
## una casa real tiene varias capas de Y por historia (suelo sólido + capas
## de pared con aire interior + techo sólido), y tratar cada capa como su
## propio "piso" generaba dos problemas: el suelo/techo (100% sólidos, sin
## puerta/ventana) fallaban "falta puerta/ventana"; y el mobiliario en una
## capa de pared, con la celda de aire interior vecina (el espacio donde
## camina el jugador, sin ningún bloque) sin registrar en esa misma capa,
## se marcaba como "hueco en el perímetro" — falso positivo.
##
## Solución: las capas 100% sólidas (losas de suelo/techo) NO generan su
## propio "piso" — se usan como PLANTILLA BASE (ya sin huecos, por
## construcción) de la historia que tienen encima (o debajo, si no hay una
## abajo). Las capas de pared de esa historia se superponen sobre esa
## plantilla, sobrescribiendo solo las celdas donde hay puerta/ventana/
## mobiliario; el resto de la plantilla (aire interior sin nada especial)
## queda con el tipo sólido de la losa, así que nunca genera un hueco falso.
## Si una historia no tiene ninguna losa sólida adyacente (p. ej. una capa
## única sin suelo/techo propios, como en pruebas con datos mínimos), se usa
## la unión simple de sus capas — mismo comportamiento que antes.
##
## ponytail: zona_permitida se fija a un valor válido de relleno porque esta
## PoC no tiene zonificación real todavía (esa es Fase 2) — sin esto,
## validar_zona_permitida() rechazaría cualquier estructura detectada. Cuando
## exista zonificación, pasar la zona real del terreno donde se construyó.
static func estructura_a_blueprint(celdas: Dictionary) -> Dictionary:
	# "puerta_superior" se remapea a "pared" (nunca se omite): físicamente
	# tapa el muro, y si se omitiera por completo dejaría un "agujero
	# fantasma" en su capa de Y — si esa capa fuera además el techo del
	# edificio, _es_losa_solida() la rechazaría por esa única celda faltante,
	# aunque el techo esté completo. "pared" nunca compite con "puerta" (la
	# mitad inferior) gracias a la regla de fusión que no pisa un tipo
	# especial ya asignado con un "pared" de otra capa (ver más abajo).
	var celdas_relevantes: Dictionary = {}
	for pos in celdas.keys():
		celdas_relevantes[pos] = "pared" if celdas[pos] == "puerta_superior" else celdas[pos]
	if celdas_relevantes.is_empty():
		return {}

	var y_min: int = celdas_relevantes.keys()[0].y
	var x_min: int = celdas_relevantes.keys()[0].x
	var z_min: int = celdas_relevantes.keys()[0].z
	var x_max: int = x_min
	var z_max: int = z_min
	for pos in celdas_relevantes.keys():
		y_min = min(y_min, pos.y)
		x_min = min(x_min, pos.x)
		z_min = min(z_min, pos.z)
		x_max = max(x_max, pos.x)
		z_max = max(z_max, pos.z)
	x_max -= x_min
	z_max -= z_min

	var celdas_por_capa: Dictionary = {}  # int (capa de Y) -> Dictionary ("x,z" -> tipo)
	var huella_real: Dictionary = {}  # "x,z" -> true, unión de columnas del edificio en cualquier capa
	for pos in celdas_relevantes.keys():
		var capa: int = pos.y - y_min
		var clave := "%d,%d" % [pos.x - x_min, pos.z - z_min]
		var tipo: String = celdas_relevantes[pos]
		if tipo == "puerta_inferior":
			tipo = "puerta"
		if not celdas_por_capa.has(capa):
			celdas_por_capa[capa] = {}
		celdas_por_capa[capa][clave] = tipo
		huella_real[clave] = true

	var indices_capa: Array = celdas_por_capa.keys()
	indices_capa.sort()
	var es_losa: Dictionary = {}  # int -> bool ("losa parcial": límite entre historias)
	for capa in indices_capa:
		es_losa[capa] = _es_losa_parcial(celdas_por_capa[capa], huella_real)

	# Primera pasada: encontrar las bandas (historias) sin construirlas
	# todavía, para saber cuál es la más baja y cuál la más alta del
	# edificio — solo esas dos exigen una losa COMPLETA (sin huecos): el
	# cimiento no puede tener un agujero al vacío, y el techo exterior no
	# puede tener un agujero al cielo. Las losas intermedias (entre dos
	# historias apiladas) solo necesitan ser una losa parcial: pueden tener
	# un hueco de escalera que conecte ambas historias.
	var bandas: Array = []  # Array de [inicio_banda, fin_banda] (índices en indices_capa)
	var i := 0
	while i < indices_capa.size():
		if es_losa[indices_capa[i]]:
			i += 1
			continue
		var inicio_banda := i
		while i < indices_capa.size() and not es_losa[indices_capa[i]]:
			i += 1
		bandas.append([inicio_banda, i - 1])

	var pisos: Array = []
	for banda_idx in range(bandas.size()):
		var inicio_banda: int = bandas[banda_idx][0]
		var fin_banda: int = bandas[banda_idx][1]
		var es_piso_mas_bajo := banda_idx == 0
		var es_piso_mas_alto := banda_idx == bandas.size() - 1

		var capa_bajo_banda: int = indices_capa[inicio_banda] - 1
		var capa_sobre_banda: int = indices_capa[fin_banda] + 1
		var hay_losa_bajo: bool = es_losa.get(capa_bajo_banda, false)
		var hay_losa_sobre: bool = es_losa.get(capa_sobre_banda, false)
		var suelo_ok: bool = hay_losa_bajo and (
			not es_piso_mas_bajo or _es_losa_completa(celdas_por_capa[capa_bajo_banda], huella_real)
		)
		var techo_ok: bool = hay_losa_sobre and (
			not es_piso_mas_alto or _es_losa_completa(celdas_por_capa[capa_sobre_banda], huella_real)
		)

		var plantilla: Dictionary = {}
		if hay_losa_bajo:
			plantilla = celdas_por_capa[capa_bajo_banda].duplicate()
		elif hay_losa_sobre:
			plantilla = celdas_por_capa[capa_sobre_banda].duplicate()

		# Si dos capas de la misma historia difieren en una celda (p.ej.
		# "puerta" en la capa baja, "pared" continuando el muro en la capa
		# alta sobre la puerta), gana el tipo especial sobre "pared" — nunca
		# se pisa una celda ya especial con un "pared" de otra capa. Un
		# "pared" real de una capa de muro SÍ sobrescribe el relleno
		# genérico heredado de la plantilla de suelo/techo (TIPOS_RELLENO_
		# GENERICO incluye "piso": sin esto, un jugador que usa el bloque
		# "piso" real del juego para su losa —en vez de "pared", como hacían
		# los datos de prueba antiguos— se encontraba con "hueco en el
		# perímetro" en casi todo el borde, porque "piso" nunca calificaba
		# para ser sobrescrito). Si dos capas tuvieran tipos especiales
		# DISTINTOS en la misma celda (caso raro, no debería ocurrir en una
		# construcción real), gana el de la capa más alta procesada — no hay
		# una regla de prioridad más fina todavía.
		for j in range(inicio_banda, fin_banda + 1):
			for clave in celdas_por_capa[indices_capa[j]]:
				var tipo_capa = celdas_por_capa[indices_capa[j]][clave]
				if not plantilla.has(clave) or TIPOS_RELLENO_GENERICO.has(plantilla[clave]) or tipo_capa != "pared":
					plantilla[clave] = tipo_capa

		var camas: Array = []
		for clave in plantilla:
			if plantilla[clave] == "cama_cabecera":
				camas.append({"pos": clave})

		pisos.append({
			"nivel": pisos.size(),
			"celdas": plantilla,
			"camas": camas,
			"suelo_completo": suelo_ok,
			"techo_completo": techo_ok,
			"altura_capas": fin_banda - inicio_banda + 1,
		})

	# celdas_3d conserva la forma real completa (puerta_inferior/
	# puerta_superior, cama_cabecera/cama_pies, ventana, etc. en su altura
	# exacta), normalizada al mismo origen (x_min, y_min, z_min) que ya usa
	# el resto de la función — a diferencia de "pisos", que aplana estas
	# celdas a un template 2D por piso para poder validar reglas de
	# perímetro/esquina, esto es lo que permite RECONSTRUIR el edificio
	# exacto al emplazar una copia (ver Construccion.gd). Se construye a
	# partir de "celdas" (el parámetro original, SIN el remapeo de
	# puerta_superior->pared que ya sufrió "celdas_relevantes" más arriba).
	var celdas_3d: Dictionary = {}  # Vector3i (normalizado) -> tipo original
	for pos in celdas.keys():
		celdas_3d[pos - Vector3i(x_min, y_min, z_min)] = celdas[pos]

	var huella_relativa: Array[Vector2i] = []
	for clave in huella_real:
		huella_relativa.append(_parsear_celda(clave))

	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,       # x_max ya es (máximo - x_min), ver arriba
		"profundidad": z_max + 1,
		"huella_relativa": huella_relativa,
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
		errores.append_array(validar_techo_y_suelo(piso))
		errores.append_array(validar_altura_piso(piso))

	errores.append_array(validar_camas_y_almacenamiento(blueprint))
	errores.append_array(validar_zona_permitida(blueprint))

	if zona_destino != "":
		errores.append_array(validar_colocacion(blueprint, zona_destino))
	if not blueprint_anterior.is_empty():
		errores.append_array(validar_evolucion(blueprint, blueprint_anterior))
	if blueprint.get("tipo", "") == "produccion" and not blueprint_original_produccion.is_empty():
		errores.append_array(validar_personalizacion_produccion(blueprint, blueprint_original_produccion))

	return {"valido": errores.is_empty(), "errores": errores}
