extends RefCounted

## Helper puro para cálculo de red de transmisión y balance energético.
## Sin estado ni autoload. Ver docs/superpowers/specs/2026-10-04-formacion-investigacion-energia-design.md.

const CONSUMO_COMBUSTIBLE_POR_LOTE := 1.0
const ENERGIA_POR_LOTE_CENTRAL := 20.0
const ORDEN_COMBUSTIBLES := ["combustible", "crudo", "carbon"]


## Determina qué columnas de vía y edificios están conectados a la red urbana,
## calcula la demanda conectada y la capacidad de las centrales térmicas, y distribuye
## la energía y el consumo de combustible de forma proporcional.
static func calcular(puestos: Dictionary, zonificacion: Object, vias: Object, ciudad: Object = null) -> Dictionary:
	# ponytail: recalcular toda la red es suficiente para 200×200; cachear solo si un perfil muestra costo.
	var conectadas_vias := _calcular_vias_conectadas(zonificacion, vias)
	var conectados_puestos := {}
	for esquina: Vector2i in puestos:
		conectados_puestos[esquina] = _puesto_esta_conectado(puestos[esquina], esquina, zonificacion, conectadas_vias)

	var nivel_investigado := 1
	if ciudad != null:
		nivel_investigado = ciudad.nivel_investigado

	# 1. Demanda conectada
	var demanda_total := 0.0
	var demandas := {}
	for esquina: Vector2i in puestos:
		var p: Dictionary = puestos[esquina]
		if not p.get("activo", false) or not conectados_puestos.get(esquina, false):
			demandas[esquina] = 0.0
			continue
		var presentes: int = p["presentes"].size() if p.has("presentes") else 0
		if presentes <= 0:
			demandas[esquina] = 0.0
			continue
		var dem := 0.0
		match p["tipo"]:
			"refineria_petrolera", "productor_combustible":
				dem = float(presentes) * 1.0
			"universidad":
				if nivel_investigado + 1 == 3:
					dem = float(presentes) * 2.0
		demandas[esquina] = dem
		demanda_total += dem

	# 2. Capacidad de generación conectada
	var capacidad_total := 0.0
	var capacidades := {}
	for esquina: Vector2i in puestos:
		var p: Dictionary = puestos[esquina]
		if p["tipo"] != "central_termoelectrica" or not p.get("activo", false) or not conectados_puestos.get(esquina, false):
			capacidades[esquina] = 0.0
			continue
		var presentes: int = p["presentes"].size() if p.has("presentes") else 0
		if presentes <= 0:
			capacidades[esquina] = 0.0
			continue
		var almacen: Dictionary = p.get("almacen", {})
		var stock_comb: float = almacen.get("combustible", 0.0) + almacen.get("crudo", 0.0) + almacen.get("carbon", 0.0)
		var lotes_posibles: float = minf(float(presentes), stock_comb)
		var cap: float = lotes_posibles * ENERGIA_POR_LOTE_CENTRAL
		capacidades[esquina] = cap
		capacidad_total += cap

	# 3. Factor y entrega
	var entregada: float = minf(demanda_total, capacidad_total)
	var factor: float = 1.0 if demanda_total <= 0.0 else (entregada / demanda_total)

	var factores := {}
	for esquina: Vector2i in puestos:
		var p: Dictionary = puestos[esquina]
		if p["tipo"] == "central_termoelectrica":
			factores[esquina] = 0.0  # la central no se autoalimenta
		elif conectados_puestos.get(esquina, false):
			factores[esquina] = factor
		else:
			factores[esquina] = 0.0

	# 4. Quema proporcional en centrales térmicas
	var quema := {}
	var combustible_total_quemar: float = entregada / ENERGIA_POR_LOTE_CENTRAL
	for esquina: Vector2i in puestos:
		var p: Dictionary = puestos[esquina]
		if p["tipo"] != "central_termoelectrica":
			continue
		var cap_esta: float = capacidades.get(esquina, 0.0)
		if cap_esta <= 0.0 or capacidad_total <= 0.0 or combustible_total_quemar <= 0.0:
			quema[esquina] = {}
			continue
		var porcion_combustible: float = combustible_total_quemar * (cap_esta / capacidad_total)
		var quema_esta := {}
		var restante := porcion_combustible
		var almacen: Dictionary = p.get("almacen", {})
		for tipo_comb in ORDEN_COMBUSTIBLES:
			if restante <= 1e-9:
				break
			var disponible: float = almacen.get(tipo_comb, 0.0)
			if disponible > 0.0:
				var tomar: float = minf(disponible, restante)
				quema_esta[tipo_comb] = tomar
				restante -= tomar
		quema[esquina] = quema_esta

	var resumen := {
		"demanda": demanda_total,
		"capacidad": capacidad_total,
		"entregada": entregada,
		"factor": factor,
		"deficit": demanda_total > 0.0 and entregada < demanda_total - 1e-9,
		"conectados": conectados_puestos,
	}

	return {
		"factores": factores,
		"resumen": resumen,
		"quema": quema,
	}


static func _calcular_vias_conectadas(zonificacion: Object, vias: Object) -> Dictionary:
	var conectadas := {}
	if vias == null:
		return conectadas
	var cols: Array = []
	if vias.has_method("columnas"):
		cols = vias.columnas()
	elif vias.get("_columnas") is Dictionary:
		cols = (vias._columnas as Dictionary).keys()
	if cols.is_empty():
		return conectadas

	var todas_vias := {}
	for c in cols:
		todas_vias[Vector2i(c.x, c.y)] = true

	var cola: Array[Vector2i] = []
	var direcciones := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for c in todas_vias:
		var toca_influencia := false
		if zonificacion != null and zonificacion.dentro_de_influencia(c):
			toca_influencia = true
		elif zonificacion != null:
			for d in direcciones:
				if zonificacion.dentro_de_influencia(c + d):
					toca_influencia = true
					break
		if toca_influencia:
			conectadas[c] = true
			cola.append(c)

	var idx := 0
	while idx < cola.size():
		var actual: Vector2i = cola[idx]
		idx += 1
		for d in direcciones:
			var vecino: Vector2i = actual + d
			if todas_vias.has(vecino) and not conectadas.has(vecino):
				conectadas[vecino] = true
				cola.append(vecino)

	return conectadas


static func _puesto_esta_conectado(p: Dictionary, esquina: Vector2i, zonificacion: Object, conectadas_vias: Dictionary) -> bool:
	var ancho: int = p.get("ancho", 1)
	var alto: int = p.get("alto", 1)
	var direcciones := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dx in range(ancho):
		for dz in range(alto):
			var celda := Vector2i(esquina.x + dx, esquina.y + dz)
			if zonificacion != null and zonificacion.dentro_de_influencia(celda):
				return true
			for d in direcciones:
				var vecino: Vector2i = celda + d
				if conectadas_vias.has(vecino):
					return true
	return false
