extends Node

## Singleton Autoload para gestión centralizada del guardado, carga y persistencia de partidas.
## Serializa atómicamente el estado de Ciudad, Economia, Colonos, Zonificacion, Vias,
## Canalizaciones, VoxelWorld y Player en user://saves/*.json.

signal partida_guardada(nombre_archivo: String)
signal partida_cargada(nombre_archivo: String)

const CARPETA_GUARDADOS := "user://saves/"
const EXTENSION := ".json"
const ARCHIVO_QUICKSAVE := "quicksave.json"

var partida_pendiente_a_cargar: String = ""

var _cache_partidas: Array[Dictionary] = []
var _cache_valida: bool = false


func _ready() -> void:
	_asegurar_directorio()


func _asegurar_directorio() -> void:
	if not DirAccess.dir_exists_absolute(CARPETA_GUARDADOS):
		DirAccess.make_dir_recursive_absolute(CARPETA_GUARDADOS)


func obtener_ruta_partida(nombre_archivo: String) -> String:
	var archivo := nombre_archivo.strip_edges().get_file()
	if not archivo.ends_with(EXTENSION):
		archivo += EXTENSION
	return CARPETA_GUARDADOS + archivo


func guardar_partida(nombre_archivo: String, nombre_legible: String = "") -> bool:
	_asegurar_directorio()
	var ruta := obtener_ruta_partida(nombre_archivo)
	var archivo_limpio := ruta.get_file()

	var nombre_final: String = nombre_legible.strip_edges()
	if nombre_final.is_empty():
		nombre_final = archivo_limpio.get_basename().capitalize()

	var fecha_actual := Time.get_datetime_string_from_system(false, true)
	var tiempo_jugado: float = Ciudad.horas_juego * 3600.0

	var metadatos := {
		"nombre_partida": nombre_final,
		"nombre_archivo": archivo_limpio,
		"fecha_guardado": fecha_actual,
		"tiempo_jugado_segundos": tiempo_jugado,
		"nivel_ciudad": Ciudad.nivel,
		"nombre_ciudad": "Ciudad Nivel %d" % Ciudad.nivel,
		"poblacion": Ciudad.censo_total,
		"oro": Ciudad.almacen["hierro"].cantidad if Ciudad.almacen.has("hierro") else 0.0,
	}

	var data_ciudad: Dictionary = Ciudad.exportar_estado() if Ciudad != null else {}
	var data_economia: Dictionary = Economia.exportar_estado() if Economia != null else {}
	var data_colonos: Dictionary = Colonos.exportar_estado() if Colonos != null else {}
	var data_zonificacion: Dictionary = Zonificacion.exportar_estado() if Zonificacion != null else {}
	var data_vias: Dictionary = Vias.exportar_estado() if Vias != null else {}
	var data_canalizaciones: Dictionary = Canalizaciones.exportar_estado() if Canalizaciones != null else {}

	var data_mundo: Dictionary = {}
	var mundo = get_tree().root.find_child("VoxelWorld", true, false)
	if mundo != null and mundo.has_method("exportar_estado"):
		data_mundo = mundo.exportar_estado()

	var data_avatar: Dictionary = {}
	var player = get_tree().root.find_child("Player", true, false)
	if player != null and player.has_method("exportar_estado"):
		data_avatar = player.exportar_estado()

	var paquete := {
		"version": 1,
		"metadatos": metadatos,
		"ciudad": data_ciudad,
		"economia": data_economia,
		"colonos": data_colonos,
		"zonificacion": data_zonificacion,
		"vias": data_vias,
		"canalizaciones": data_canalizaciones,
		"mundo": data_mundo,
		"avatar": data_avatar,
	}

	var arch := FileAccess.open(ruta, FileAccess.WRITE)
	if arch == null:
		push_error("No se pudo abrir el archivo para guardar: " + ruta)
		return false

	arch.store_string(JSON.stringify(paquete, "\t"))
	_actualizar_cache_con_metadatos(metadatos)
	partida_guardada.emit(archivo_limpio)
	return true


func cargar_partida(nombre_archivo: String) -> bool:
	var ruta := obtener_ruta_partida(nombre_archivo)
	if not FileAccess.file_exists(ruta):
		push_error("El archivo de partida no existe: " + ruta)
		return false

	var arch := FileAccess.open(ruta, FileAccess.READ)
	if arch == null:
		push_error("No se pudo leer la partida: " + ruta)
		return false

	var texto := arch.get_as_text()
	var json = JSON.parse_string(texto)
	if not (json is Dictionary):
		push_error("El archivo de partida no es un JSON válido: " + ruta)
		return false

	var data: Dictionary = json

	if Ciudad != null and data.has("ciudad") and data["ciudad"] is Dictionary:
		Ciudad.importar_estado(data["ciudad"])

	if Economia != null and data.has("economia") and data["economia"] is Dictionary:
		Economia.importar_estado(data["economia"])

	if Colonos != null and data.has("colonos") and data["colonos"] is Dictionary:
		Colonos.importar_estado(data["colonos"])

	if Zonificacion != null and data.has("zonificacion") and data["zonificacion"] is Dictionary:
		Zonificacion.importar_estado(data["zonificacion"])

	if Vias != null and data.has("vias") and data["vias"] is Dictionary:
		Vias.importar_estado(data["vias"])

	if Canalizaciones != null and data.has("canalizaciones") and data["canalizaciones"] is Dictionary:
		Canalizaciones.importar_estado(data["canalizaciones"])

	var mundo = get_tree().root.find_child("VoxelWorld", true, false)
	if mundo != null and mundo.has_method("importar_estado") and data.has("mundo") and data["mundo"] is Dictionary:
		mundo.importar_estado(data["mundo"])

	var player = get_tree().root.find_child("Player", true, false)
	if player != null and player.has_method("importar_estado") and data.has("avatar") and data["avatar"] is Dictionary:
		player.importar_estado(data["avatar"])

	var zona_overlay = get_tree().root.find_child("ZonaOverlay", true, false)
	if zona_overlay != null and zona_overlay.has_method("reconstruir"):
		zona_overlay.reconstruir()

	partida_cargada.emit(ruta.get_file())
	return true


func guardado_rapido() -> bool:
	return guardar_partida(ARCHIVO_QUICKSAVE, "Guardado Rápido")


func cargar_rapido() -> bool:
	return cargar_partida(ARCHIVO_QUICKSAVE)


func precargar_metadatos_partidas() -> void:
	_asegurar_directorio()
	_cache_partidas.clear()
	var dir := DirAccess.open(CARPETA_GUARDADOS)
	if dir != null:
		dir.list_dir_begin()
		var arch := dir.get_next()
		while arch != "":
			if not dir.current_is_dir() and arch.ends_with(EXTENSION):
				var ruta := CARPETA_GUARDADOS + arch
				var f := FileAccess.open(ruta, FileAccess.READ)
				if f != null:
					var parsed = JSON.parse_string(f.get_as_text())
					if parsed is Dictionary and parsed.has("metadatos") and parsed["metadatos"] is Dictionary:
						_cache_partidas.append(parsed["metadatos"])
					else:
						_cache_partidas.append({
							"nombre_partida": arch.get_basename().capitalize(),
							"nombre_archivo": arch,
							"fecha_guardado": "",
							"nivel_ciudad": 1,
							"poblacion": 0,
						})
			arch = dir.get_next()
		dir.list_dir_end()

	_ordenar_cache()
	_cache_valida = true


func _ordenar_cache() -> void:
	_cache_partidas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("fecha_guardado", "")) > str(b.get("fecha_guardado", ""))
	)


func _actualizar_cache_con_metadatos(meta: Dictionary) -> void:
	var archivo: String = meta.get("nombre_archivo", "")
	var encontrado := false
	for i in range(_cache_partidas.size()):
		if _cache_partidas[i].get("nombre_archivo", "") == archivo:
			_cache_partidas[i] = meta
			encontrado = true
			break
	if not encontrado:
		_cache_partidas.append(meta)
	_ordenar_cache()
	_cache_valida = true


func _remover_de_cache(nombre_archivo: String) -> void:
	var archivo_limpio := nombre_archivo.strip_edges().get_file()
	if not archivo_limpio.ends_with(EXTENSION):
		archivo_limpio += EXTENSION
	for i in range(_cache_partidas.size() - 1, -1, -1):
		if _cache_partidas[i].get("nombre_archivo", "") == archivo_limpio:
			_cache_partidas.remove_at(i)
			break


func listar_partidas() -> Array[Dictionary]:
	if not _cache_valida:
		precargar_metadatos_partidas()
	return _cache_partidas.duplicate()


func eliminar_partida(nombre_archivo: String) -> bool:
	var ruta := obtener_ruta_partida(nombre_archivo)
	if FileAccess.file_exists(ruta):
		var err := DirAccess.remove_absolute(ruta)
		if err == OK:
			_remover_de_cache(nombre_archivo)
			return true
	return false


func reiniciar_partida() -> void:
	if Ciudad != null and Ciudad.has_method("reiniciar"):
		Ciudad.reiniciar()
	if Economia != null and Economia.has_method("reiniciar"):
		Economia.reiniciar()
	if Colonos != null and Colonos.has_method("reiniciar"):
		Colonos.reiniciar()
	if Zonificacion != null and Zonificacion.has_method("reiniciar"):
		Zonificacion.reiniciar()
	if Vias != null and Vias.has_method("reiniciar"):
		Vias.reiniciar()
	if Canalizaciones != null and Canalizaciones.has_method("reiniciar"):
		Canalizaciones.reiniciar()
