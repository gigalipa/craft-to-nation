extends Node

## Singleton Autoload para gestión y reproducción de efectos de sonido (SFX) y música ambiental (BGM).
## Provee pools de reproductores 2D (UI/Avatar) y 3D (Mundo espacial), reproductor dedicado de música,
## carga perezosa con caché en memoria y microvariación de tono.

const RUTA_BASE := "res://assets/sfx/"
const RUTA_CATALOGO := "res://assets/sfx/sfx_catalog.json"
const TAMANO_POOL_2D := 16
const TAMANO_POOL_3D := 16

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
var _en_musica_juego: bool = false
var _indice_musica: int = 0
var _playlist_juego: Array[String] = [
	"res://assets/musica/Cozy_colony (loop).mp3",
	"res://assets/musica/Morning_at_the_Steel_Spire (loop).mp3",
	"res://assets/musica/Clockwork_logistics (loop).mp3",
]

var _catalogo: Dictionary = {}
var _cache_streams: Dictionary = {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _indice_2d: int = 0
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _indice_3d: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_cargar_catalogo()
	_inicializar_pools()


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
	_player_musica.finished.connect(_on_musica_terminada)
	add_child(_player_musica)


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
	if _player_musica != null:
		_player_musica.volume_db = volumen_musica_db


func cargar_stream_musica(ruta: String, en_bucle: bool = false) -> AudioStream:
	if _cache_streams.has(ruta):
		var cached: AudioStream = _cache_streams[ruta]
		if cached is AudioStreamMP3:
			(cached as AudioStreamMP3).loop = en_bucle
		return cached

	if not FileAccess.file_exists(ruta):
		return null

	var stream := AudioStreamMP3.load_from_file(ruta)
	if stream != null:
		stream.loop = en_bucle
		_cache_streams[ruta] = stream
	return stream


func reproducir_musica(ruta: String, en_bucle: bool = true) -> AudioStreamPlayer:
	_en_musica_juego = false
	if not musica_habilitada or _player_musica == null:
		return null

	var stream := cargar_stream_musica(ruta, en_bucle)
	if stream == null:
		return null

	_player_musica.stream = stream
	_player_musica.volume_db = volumen_musica_db
	_player_musica.play()
	return _player_musica


func reproducir_musica_menu() -> void:
	_en_musica_juego = false
	reproducir_musica("res://assets/musica/The_Architect_s_Decree (menu).mp3", true)


func reproducir_musica_juego() -> void:
	_en_musica_juego = true
	if _playlist_juego.is_empty() or not musica_habilitada or _player_musica == null:
		return

	var ruta := _playlist_juego[_indice_musica]
	var stream := cargar_stream_musica(ruta, false)
	if stream == null:
		return

	_player_musica.stream = stream
	_player_musica.volume_db = volumen_musica_db
	_player_musica.play()


func detener_musica() -> void:
	_en_musica_juego = false
	if _player_musica != null and _player_musica.playing:
		_player_musica.stop()


func _on_musica_terminada() -> void:
	if _en_musica_juego and not _playlist_juego.is_empty():
		_indice_musica = (_indice_musica + 1) % _playlist_juego.size()
		reproducir_musica_juego()


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
	if not FileAccess.file_exists(ruta):
		return null

	var stream := AudioStreamOggVorbis.load_from_file(ruta)
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
	if _player_musica != null and _player_musica.playing:
		_player_musica.stop()


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
