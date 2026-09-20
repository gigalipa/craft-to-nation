extends Node

## Autoload "Construccion": progreso de construcciones fantasma en curso
## (edificios emplazados desde un blueprint, pendientes de ser surtidos con
## bloques — ver spec:
## docs/superpowers/specs/2026-09-10-blueprints-construccion-fantasma-design.md).
## Una construcción es una lista ORDENADA de celdas pendientes, cada una con
## su tipo real de destino — avanzar() siempre convierte la PRIMERA celda
## pendiente de la lista, sin importar cuál celda fantasma apuntó el
## jugador (ver Player.gd/VoxelWorld.gd): el orden es automático y fijo
## (relleno de tierra -> piso -> paredes/puertas/ventanas -> mobiliario),
## decidido al iniciar la construcción. Mismo patrón de estado puro que
## Recoleccion.gd/Zonificacion.gd/Blueprints.gd.

var _siguiente_id := 1
var _construcciones: Dictionary = {}  # int id -> {"orden": Array[Vector3i], "tipos": Dictionary, "indice": int, "metadata": Dictionary}
var _celda_a_construccion: Dictionary = {}  # Vector3i -> int id


## "orden": Array[Vector3i] ya en el orden exacto de conversión.
## "tipos": Dictionary Vector3i -> String, el tipo real al que se convierte
## cada celda de "orden" cuando le toque su turno.
## "metadata": dato opaco que el llamador necesita al completarse (ver
## avanzar()) — p. ej. para un edificio, {"blueprint": ..., "huella_xz": ...,
## "esquina": ..., "ancho": ..., "profundidad": ...}; {} si no hace falta
## nada. Construccion.gd nunca mira su contenido, solo lo guarda y lo
## devuelve intacto.
func iniciar(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	var id := _siguiente_id
	_siguiente_id += 1
	_construcciones[id] = {"orden": orden, "tipos": tipos, "indice": 0, "metadata": metadata}
	for celda in orden:
		_celda_a_construccion[celda] = id
	return id


func construccion_de(celda: Vector3i) -> int:
	return _celda_a_construccion.get(celda, -1)


## Descarta de la construcción "id" los pasos AÚN PENDIENTES cuyo tipo esté en
## "tipos_a_descartar" (los ya avanzados no se tocan) y libera sus celdas.
## Si no queda nada pendiente, la construcción se limpia por completo.
## Devuelve las celdas descartadas (para que el llamador limpie lo que haya
## en el mundo, p. ej. los fantasmas del relleno). No-op si "id" no existe.
func descartar_pendientes(id: int, tipos_a_descartar: Array) -> Array[Vector3i]:
	var descartadas: Array[Vector3i] = []
	if not _construcciones.has(id):
		return descartadas
	var datos: Dictionary = _construcciones[id]
	var orden: Array = datos["orden"]
	var indice: int = datos["indice"]
	var nuevo_orden: Array = orden.slice(0, indice)
	for i in range(indice, orden.size()):
		var celda: Vector3i = orden[i]
		if tipos_a_descartar.has(datos["tipos"][celda]):
			_celda_a_construccion.erase(celda)
			descartadas.append(celda)
		else:
			nuevo_orden.append(celda)
	datos["orden"] = nuevo_orden
	if nuevo_orden.size() <= indice:
		for c in nuevo_orden:
			_celda_a_construccion.erase(c)
		_construcciones.erase(id)
	return descartadas


## Convierte la SIGUIENTE celda pendiente de la construcción "id" (no
## necesariamente "celda_apuntada", que solo sirvió para identificar la
## construcción). Devuelve {"celda": Vector3i, "tipo": String,
## "completa": bool, "metadata": Dictionary, "orden": Array} —
## "completa" es true si esta era la última celda pendiente, momento en el
## que este autoload limpia su propio registro; "orden" es la lista
## COMPLETA de celdas de la construcción (siempre presente, útil para el
## llamador cuando completa=true — p. ej. para reemparejar puertas/camas,
## ver VoxelWorld.reemparejar_construccion()); "metadata" es la misma que
## se pasó a iniciar(), siempre presente. Falla (dict vacío) si "id" no
## existe o ya está completa.
func avanzar(id: int) -> Dictionary:
	if not _construcciones.has(id):
		return {}
	var datos: Dictionary = _construcciones[id]
	var indice: int = datos["indice"]
	var orden: Array = datos["orden"]
	if indice >= orden.size():
		return {}
	var celda: Vector3i = orden[indice]
	var tipo: String = datos["tipos"][celda]
	var metadata: Dictionary = datos["metadata"]
	datos["indice"] = indice + 1
	var completa: bool = datos["indice"] >= orden.size()
	if completa:
		for c in orden:
			_celda_a_construccion.erase(c)
		_construcciones.erase(id)
	return {"celda": celda, "tipo": tipo, "completa": completa, "metadata": metadata, "orden": orden}
