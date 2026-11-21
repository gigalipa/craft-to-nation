extends Node

## Singleton Autoload para gestión y reproducción de efectos de sonido (SFX) y música ambiental (BGM).
## Provee pools de reproductores 2D (UI/Avatar) y 3D (Mundo espacial), reproductor dedicado de música,
## carga perezosa con caché en memoria y microvariación de tono.

const Ajustes = preload("res://scripts/ajustes.gd")

const RUTA_BASE := "res://assets/sfx/"
const RUTA_CATALOGO := "res://assets/sfx/sfx_catalog.json"
const RUTA_MUSICA := "res://assets/musica/"
const TAMANO_POOL_2D := 16
const TAMANO_POOL_3D := 16

const CONTEXTOS_MUSICA_VALIDOS: Array[String] = ["menu", "exploration", "building", "industry", "battle"]
const CATALOGO_MUSICA_POR_CONTEXTO: Dictionary = {
	"menu": [
		"res://assets/musica/Menu & Loading Theme (menu).mp3",
		"res://assets/musica/The_Architect_s_Decree (menu).mp3",
	],
	"exploration": [
		"res://assets/musica/Untamed Horizons (exploration).mp3",
		"res://assets/musica/Wilderness & Discovery (exploration).mp3",
	],
	"building": [
		"res://assets/musica/Cozy_colony (building).mp3",
		"res://assets/musica/Foundations & Frameworks (building).mp3",
		"res://assets/musica/Frontier Blueprint (building).mp3",
		"res://assets/musica/Seamless_loop  (building).mp3",
	],
	"industry": [
		"res://assets/musica/Automated Pulse (industry).mp3",
		"res://assets/musica/Clockwork_logistics (industry).mp3",
		"res://assets/musica/Clockwork_logistics_2 (industry).mp3",
		"res://assets/musica/Glitch_drift (industry).mp3",
		"res://assets/musica/Glitch_drift_2 (industry).mp3",
		"res://assets/musica/Morning_at_the_Steel_Spire (industry).mp3",
	],
	"battle": [
		"res://assets/musica/Hard_stop (battle).mp3",
		"res://assets/musica/Hard_stop_2 (battle).mp3",
		"res://assets/musica/Siege Protocols (battle).mp3",
	],
}

const CATEGORIAS_POR_PREFIJO: Dictionary = {
	"sfx_avatar_": "locomocion",
	"sfx_pala_": "herramientas",
	"sfx_pico_": "herramientas",
	"sfx_bloque_": "herramientas",
	"sfx_hacha_": "herramientas",
	"sfx_arbol_": "herramientas",
	"sfx_follaje_": "herramientas",
	"sfx_cosecha_": "herramientas",
	"sfx_mazo_": "herramientas",
	"sfx_colocar_": "herramientas",
	"sfx_accion_": "herramientas",
	"sfx_puerta_": "mobiliario",
	"sfx_baul_": "mobiliario",
	"sfx_cama_": "mobiliario",
	"sfx_mesa_": "mobiliario",
	"sfx_lampara_": "mobiliario",
	"sfx_colono_": "colonos",
	"sfx_carreta_": "colonos",
	"sfx_carro_": "colonos",
	"sfx_camion_": "colonos",
	"sfx_dron_": "colonos",
	"sfx_trolebus_": "colonos",
	"sfx_puesto_": "industrias",
	"sfx_ind_": "industrias",
	"sfx_acueducto_": "fluidos",
	"sfx_tuberia_": "fluidos",
	"sfx_canalizacion_": "fluidos",
	"sfx_ambiente_": "fluidos",
	"sfx_via_": "urbanismo",
	"sfx_blueprint_": "urbanismo",
	"sfx_zona_": "urbanismo",
	"sfx_obra_": "urbanismo",
	"sfx_ui_": "ui",
}

var sfx_habilitado: bool = true
var volumen_sfx_db: float = 0.0

var musica_habilitada: bool = true
var volumen_musica_db: float = 0.0
var _player_musica: AudioStreamPlayer = null
var _player_musica_secundario: AudioStreamPlayer = null
var _tween_musica: Tween = null
var _en_musica_juego: bool = false
var _contexto_musica_actual: String = ""
var _contexto_candidato: String = ""
var _tiempo_candidato_s: float = 0.0
var _tiempo_en_pista_actual_s: float = 0.0
var _cooldown_batalla_restante_s: float = 0.0
var _pistas_por_contexto: Dictionary = {}
var _colas_contexto: Dictionary = {}
var _ultima_pista_contexto: Dictionary = {}

var _catalogo: Dictionary = {}
var _cache_streams: Dictionary = {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _indice_2d: int = 0
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _indice_3d: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_cargar_catalogo()
	_inicializar_pools()
	_inicializar_catalogo_musica()


func _cargar_catalogo() -> void:
	if FileAccess.file_exists(RUTA_CATALOGO):
		var archivo := FileAccess.open(RUTA_CATALOGO, FileAccess.READ)
		if archivo != null:
			var texto := archivo.get_as_text()
			var json = JSON.parse_string(texto)
			if json is Dictionary:
				_catalogo = json


func _inicializar_pools() -> void:
	for i in range(TAMANO_POOL_2D):
		var player := AudioStreamPlayer.new()
		player.name = "AudioPlayer2D_%d" % i
		player.bus = "Master"
		add_child(player)
		_pool_2d.append(player)

	for i in range(TAMANO_POOL_3D):
		var player3d := AudioStreamPlayer3D.new()
		player3d.name = "AudioPlayer3D_%d" % i
		player3d.bus = "Master"
		player3d.unit_size = 10.0
		player3d.max_distance = 35.0
		player3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player3d)
		_pool_3d.append(player3d)

	_player_musica = AudioStreamPlayer.new()
	_player_musica.name = "AudioPlayerMusica"
	_player_musica.bus = "Master"
	_player_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	_player_musica.finished.connect(_on_player_musica_terminado.bind(_player_musica))
	add_child(_player_musica)

	_player_musica_secundario = AudioStreamPlayer.new()
	_player_musica_secundario.name = "AudioPlayerMusicaFade"
	_player_musica_secundario.bus = "Master"
	_player_musica_secundario.process_mode = Node.PROCESS_MODE_ALWAYS
	_player_musica_secundario.finished.connect(_on_player_musica_terminado.bind(_player_musica_secundario))
	add_child(_player_musica_secundario)


static func extraer_contexto_musical(nombre_archivo: String) -> String:
	var base := nombre_archivo.get_file().get_basename().strip_edges()
	var idx_abre := base.rfind("(")
	var idx_cierra := base.rfind(")")
	if idx_abre == -1 or idx_cierra <= idx_abre:
		return ""
	var etiqueta := base.substr(idx_abre + 1, idx_cierra - idx_abre - 1).strip_edges().to_lower()
	return etiqueta if CONTEXTOS_MUSICA_VALIDOS.has(etiqueta) else ""


func _inicializar_catalogo_musica() -> void:
	_pistas_por_contexto.clear()
	for ctx in CONTEXTOS_MUSICA_VALIDOS:
		var pistas_vacias: Array[String] = []
		var cola_vacia: Array[String] = []
		_pistas_por_contexto[ctx] = pistas_vacias
		_colas_contexto[ctx] = cola_vacia
		_ultima_pista_contexto[ctx] = ""

	var dir := DirAccess.open(RUTA_MUSICA)
	if dir != null:
		dir.list_dir_begin()
		var nombre := dir.get_next()
		while nombre != "":
			if not dir.current_is_dir():
				var limpio := nombre.trim_suffix(".import")
				if limpio.to_lower().ends_with(".mp3"):
					var ctx := extraer_contexto_musical(limpio)
					if ctx != "":
						var ruta_completa := RUTA_MUSICA + limpio
						var lista: Array[String] = _pistas_por_contexto[ctx]
						if not lista.has(ruta_completa):
							lista.append(ruta_completa)
			nombre = dir.get_next()
		dir.list_dir_end()

	for ctx in CONTEXTOS_MUSICA_VALIDOS:
		var lista: Array[String] = _pistas_por_contexto[ctx]
		if lista.is_empty() and CATALOGO_MUSICA_POR_CONTEXTO.has(ctx):
			for ruta in CATALOGO_MUSICA_POR_CONTEXTO[ctx]:
				lista.append(str(ruta))
		lista.sort()


func obtener_pistas_contexto(contexto: String) -> Array[String]:
	var resultado: Array[String] = []
	if not _pistas_por_contexto.has(contexto):
		return resultado
	for ruta in _pistas_por_contexto[contexto]:
		resultado.append(str(ruta))
	return resultado


func obtener_siguiente_pista_contexto(contexto: String) -> String:
	if not _pistas_por_contexto.has(contexto):
		return ""
	var disponibles: Array = _pistas_por_contexto[contexto]
	if disponibles.is_empty():
		return ""
	if disponibles.size() == 1:
		var unica := str(disponibles[0])
		_ultima_pista_contexto[contexto] = unica
		return unica

	var cola: Array = _colas_contexto[contexto]
	if cola.is_empty():
		cola = disponibles.duplicate()
		for i in range(cola.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp: String = str(cola[i])
			cola[i] = cola[j]
			cola[j] = tmp
		var ultima: String = str(_ultima_pista_contexto.get(contexto, ""))
		if ultima != "" and str(cola[0]) == ultima:
			var ult_idx := cola.size() - 1
			var tmp2: String = str(cola[0])
			cola[0] = cola[ult_idx]
			cola[ult_idx] = tmp2
		_colas_contexto[contexto] = cola

	var elegida := str(cola.pop_front())
	_ultima_pista_contexto[contexto] = elegida
	return elegida


func _cancelar_tween_musica() -> void:
	if _tween_musica != null and is_instance_valid(_tween_musica):
		_tween_musica.kill()
	_tween_musica = null


func actualizar_volumen_sfx(lineal: float) -> void:
	sfx_habilitado = lineal > 0.001
	if sfx_habilitado:
		volumen_sfx_db = linear_to_db(clampf(lineal, 0.0001, 1.0))
	else:
		volumen_sfx_db = -80.0


func actualizar_volumen_musica(lineal: float) -> void:
	musica_habilitada = lineal > 0.001
	if musica_habilitada:
		volumen_musica_db = linear_to_db(clampf(lineal, 0.0001, 1.0))
	else:
		volumen_musica_db = -80.0
	_cancelar_tween_musica()
	if _player_musica_secundario != null:
		_player_musica_secundario.volume_db = -80.0
		if _player_musica_secundario.playing:
			_player_musica_secundario.stop()
	if _player_musica != null:
		_player_musica.volume_db = volumen_musica_db
		if musica_habilitada and not _player_musica.playing and _contexto_musica_actual != "":
			var pista := obtener_siguiente_pista_contexto(_contexto_musica_actual)
			if pista != "":
				_transicionar_a_pista(pista, 0.0)


func cargar_stream_musica(ruta: String, en_bucle: bool = false) -> AudioStream:
	if _cache_streams.has(ruta):
		var cached: AudioStream = _cache_streams[ruta]
		if cached is AudioStreamMP3:
			(cached as AudioStreamMP3).loop = en_bucle
		return cached

	var stream: AudioStream = null
	if ResourceLoader.exists(ruta):
		stream = load(ruta) as AudioStream
	elif FileAccess.file_exists(ruta):
		stream = AudioStreamMP3.load_from_file(ruta)

	if stream != null:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = en_bucle
		_cache_streams[ruta] = stream
	return stream


func _transicionar_a_pista(ruta: String, duracion_fade: float) -> void:
	if not musica_habilitada or _player_musica == null or ruta == "":
		return
	var stream := cargar_stream_musica(ruta, false)
	if stream == null:
		return

	_cancelar_tween_musica()
	_tiempo_en_pista_actual_s = 0.0

	var habia_audio := _player_musica.playing and duracion_fade > 0.0 and _player_musica_secundario != null
	if not habia_audio:
		if _player_musica_secundario != null and _player_musica_secundario.playing:
			_player_musica_secundario.stop()
		_player_musica.stream = stream
		_player_musica.volume_db = volumen_musica_db
		_player_musica.play()
		return

	var saliente := _player_musica
	var entrante := _player_musica_secundario
	_player_musica = entrante
	_player_musica_secundario = saliente

	entrante.stop()
	entrante.stream = stream
	entrante.volume_db = minf(-40.0, volumen_musica_db)
	entrante.play()

	_tween_musica = create_tween()
	_tween_musica.set_parallel(true)
	_tween_musica.tween_property(saliente, "volume_db", -60.0, duracion_fade)
	_tween_musica.tween_property(entrante, "volume_db", volumen_musica_db, duracion_fade)
	_tween_musica.chain().tween_callback(func() -> void:
		if is_instance_valid(saliente) and saliente == _player_musica_secundario:
			saliente.stop()
	)


func reproducir_musica(ruta: String, en_bucle: bool = true) -> AudioStreamPlayer:
	_en_musica_juego = false
	if not musica_habilitada or _player_musica == null:
		return null

	var stream := cargar_stream_musica(ruta, en_bucle)
	if stream == null:
		return null

	_cancelar_tween_musica()
	if _player_musica_secundario != null and _player_musica_secundario.playing:
		_player_musica_secundario.stop()
	_player_musica.stream = stream
	_player_musica.volume_db = volumen_musica_db
	_player_musica.play()
	return _player_musica


func establecer_contexto_musica(nuevo_contexto: String, forzar_inmediato: bool = false) -> void:
	if not CONTEXTOS_MUSICA_VALIDOS.has(nuevo_contexto):
		return
	if nuevo_contexto == "menu":
		_en_musica_juego = false
		_cooldown_batalla_restante_s = 0.0
	else:
		_en_musica_juego = true

	if _contexto_musica_actual == nuevo_contexto and _player_musica != null and _player_musica.playing:
		return

	var previo := _contexto_musica_actual
	_contexto_musica_actual = nuevo_contexto
	_contexto_candidato = ""
	_tiempo_candidato_s = 0.0

	var pista := obtener_siguiente_pista_contexto(nuevo_contexto)
	if pista == "":
		return

	var fade := 0.0
	if not forzar_inmediato and previo != "" and _player_musica != null and _player_musica.playing:
		fade = Ajustes.MUSICA_CROSSFADE_BATALLA_S if nuevo_contexto == "battle" else Ajustes.MUSICA_CROSSFADE_AMBIENTAL_S
	_transicionar_a_pista(pista, fade)


func notificar_evento_combate() -> void:
	_cooldown_batalla_restante_s = Ajustes.MUSICA_COOLDOWN_BATALLA_S
	if _contexto_musica_actual != "battle" or (_player_musica != null and not _player_musica.playing):
		establecer_contexto_musica("battle", false)


func obtener_contexto_musica_actual() -> String:
	return _contexto_musica_actual


func evaluar_contexto_musical(estado_juego: Dictionary, delta: float) -> String:
	var dt := maxf(0.0, delta)
	if _player_musica != null and _player_musica.playing:
		_tiempo_en_pista_actual_s += dt
	if _cooldown_batalla_restante_s > 0.0:
		_cooldown_batalla_restante_s = maxf(0.0, _cooldown_batalla_restante_s - dt)

	if bool(estado_juego.get("en_combate", false)):
		_cooldown_batalla_restante_s = Ajustes.MUSICA_COOLDOWN_BATALLA_S

	var deseado := _determinar_contexto_deseado(estado_juego)
	if _contexto_musica_actual == "" or _contexto_musica_actual == "menu":
		establecer_contexto_musica(deseado, _contexto_musica_actual == "")
		return _contexto_musica_actual

	if deseado == "battle":
		if _contexto_musica_actual != "battle":
			establecer_contexto_musica("battle", false)
		return _contexto_musica_actual

	if _contexto_musica_actual == "battle":
		establecer_contexto_musica(deseado, false)
		return _contexto_musica_actual

	if deseado == _contexto_musica_actual:
		_contexto_candidato = ""
		_tiempo_candidato_s = 0.0
		return _contexto_musica_actual

	if deseado == _contexto_candidato:
		_tiempo_candidato_s += dt
	else:
		_contexto_candidato = deseado
		_tiempo_candidato_s = dt

	var pista_terminada := (_player_musica == null or not _player_musica.playing)
	var cumple_histeresis := _tiempo_candidato_s >= Ajustes.MUSICA_HISTERESIS_AMBIENTAL_S
	var cumple_permanencia := pista_terminada or _tiempo_en_pista_actual_s >= Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S
	if cumple_histeresis and cumple_permanencia:
		establecer_contexto_musica(deseado, false)

	return _contexto_musica_actual


func _determinar_contexto_deseado(estado_juego: Dictionary) -> String:
	if _cooldown_batalla_restante_s > 0.0 or bool(estado_juego.get("en_combate", false)):
		return "battle"
	if bool(estado_juego.get("en_industria", false)) or bool(estado_juego.get("panel_industria_abierto", false)):
		return "industry"
	var modo_construccion := bool(estado_juego.get("modo_construccion_activo", false))
	var construccion_reciente := bool(estado_juego.get("construccion_reciente", false))
	var tiene_nucleo := bool(estado_juego.get("tiene_nucleo", false))
	var en_influencia := bool(estado_juego.get("en_influencia", false))
	if modo_construccion or construccion_reciente or (tiene_nucleo and en_influencia):
		return "building"
	return "exploration"


func reiniciar_director_musica() -> void:
	detener_musica()
	_contexto_musica_actual = ""
	_contexto_candidato = ""
	_tiempo_candidato_s = 0.0
	_tiempo_en_pista_actual_s = 0.0
	_cooldown_batalla_restante_s = 0.0
	for ctx in CONTEXTOS_MUSICA_VALIDOS:
		var cola_vacia: Array[String] = []
		_colas_contexto[ctx] = cola_vacia
		_ultima_pista_contexto[ctx] = ""


func reproducir_musica_menu() -> void:
	establecer_contexto_musica("menu", false)


func reproducir_musica_juego() -> void:
	_cooldown_batalla_restante_s = 0.0
	_contexto_candidato = ""
	_tiempo_candidato_s = 0.0
	var ctx_inicial := "exploration"
	if Ciudad != null and "id_nucleo" in Ciudad and Ciudad.id_nucleo != -1:
		ctx_inicial = "building"
	establecer_contexto_musica(ctx_inicial, false)


func detener_musica() -> void:
	_en_musica_juego = false
	_cancelar_tween_musica()
	if _player_musica != null and _player_musica.playing:
		_player_musica.stop()
	if _player_musica_secundario != null and _player_musica_secundario.playing:
		_player_musica_secundario.stop()


func _on_player_musica_terminado(player: AudioStreamPlayer) -> void:
	if player != _player_musica or not musica_habilitada:
		return
	if _contexto_candidato != "" and _contexto_candidato != _contexto_musica_actual and _tiempo_candidato_s >= Ajustes.MUSICA_HISTERESIS_AMBIENTAL_S:
		establecer_contexto_musica(_contexto_candidato, true)
		return
	if _contexto_musica_actual != "":
		var siguiente := obtener_siguiente_pista_contexto(_contexto_musica_actual)
		if siguiente != "":
			_transicionar_a_pista(siguiente, 0.0)


func obtener_ruta(sfx_id: String) -> String:
	if _catalogo.has(sfx_id):
		var rel: String = _catalogo[sfx_id].get("file", "")
		if rel != "":
			if rel.begins_with("sfx/"):
				return "res://assets/" + rel
			return RUTA_BASE + rel
	for prefijo in CATEGORIAS_POR_PREFIJO:
		if sfx_id.begins_with(prefijo):
			var cat: String = CATEGORIAS_POR_PREFIJO[prefijo]
			return RUTA_BASE + "%s/%s.ogg" % [cat, sfx_id]
	return RUTA_BASE + "%s.ogg" % sfx_id


func obtener_stream(sfx_id: String) -> AudioStream:
	if _cache_streams.has(sfx_id):
		return _cache_streams[sfx_id]

	var ruta := obtener_ruta(sfx_id)
	var stream: AudioStream = null
	if ResourceLoader.exists(ruta):
		stream = load(ruta) as AudioStream
	elif FileAccess.file_exists(ruta):
		stream = AudioStreamOggVorbis.load_from_file(ruta)

	if stream != null:
		_cache_streams[sfx_id] = stream
	return stream


## Reproduce un sonido 2D / UI / avatar en el espacio general.
func reproducir(sfx_id: String, volumen_offset_db: float = 0.0, pitch_variacion: float = 0.0) -> AudioStreamPlayer:
	if not sfx_habilitado or _pool_2d.is_empty():
		return null

	var stream := obtener_stream(sfx_id)
	if stream == null:
		return null

	var player := _obtener_siguiente_player_2d()
	player.stream = stream
	player.volume_db = volumen_sfx_db + volumen_offset_db
	if pitch_variacion > 0.0:
		player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variacion, pitch_variacion)
	else:
		player.pitch_scale = 1.0

	player.play()
	return player


## Reproduce un sonido 3D posicional en una coordenada del mundo.
func reproducir_3d(sfx_id: String, posicion: Vector3, volumen_offset_db: float = 0.0, pitch_variacion: float = 0.0, max_distancia: float = 35.0) -> AudioStreamPlayer3D:
	if not sfx_habilitado or _pool_3d.is_empty():
		return null

	var stream := obtener_stream(sfx_id)
	if stream == null:
		return null

	var player := _obtener_siguiente_player_3d()
	player.stream = stream
	player.global_position = posicion
	player.max_distance = max_distancia
	player.volume_db = volumen_sfx_db + volumen_offset_db
	if pitch_variacion > 0.0:
		player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variacion, pitch_variacion)
	else:
		player.pitch_scale = 1.0

	player.play()
	return player


func detener_todo() -> void:
	for p in _pool_2d:
		if p.playing:
			p.stop()
	for p in _pool_3d:
		if p.playing:
			p.stop()
	detener_musica()


func cantidad_cargados() -> int:
	return _cache_streams.size()


func _obtener_siguiente_player_2d() -> AudioStreamPlayer:
	# Busca primero un player que no esté reproduciendo
	for p in _pool_2d:
		if not p.playing:
			return p
	# Si todos están ocupados, usa round-robin
	var p := _pool_2d[_indice_2d]
	_indice_2d = (_indice_2d + 1) % _pool_2d.size()
	return p


func _obtener_siguiente_player_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	var p := _pool_3d[_indice_3d]
	_indice_3d = (_indice_3d + 1) % _pool_3d.size()
	return p
