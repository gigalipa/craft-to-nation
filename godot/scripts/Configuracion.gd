extends Node

## Singleton Autoload para gestión y persistencia de configuraciones y preferencias del usuario.
## Guarda en `user://configuracion.json` y sincroniza en tiempo real los volúmenes,
## sensibilidad de mouse, FOV de cámara, idioma y variables de balance de `ajustes.gd`.

const Ajustes = preload("res://scripts/ajustes.gd")

signal configuracion_cambiada(clave: String, valor: Variant)

const RUTA_CONFIG := "user://configuracion.json"
const TAMANO_VENTANA_DEFAULT := Vector2i(1280, 720)

var volumen_sfx: float = 1.0: set = establecer_volumen_sfx
var volumen_musica: float = 0.8: set = establecer_volumen_musica
var sensibilidad_mouse: float = 0.003: set = establecer_sensibilidad_mouse
var fov_camara: float = 70.0: set = establecer_fov_camara
var idioma: String = "es": set = establecer_idioma
var modo_pantalla: String = "pantalla_completa": set = establecer_modo_pantalla

var variables_ajustes: Dictionary = {}

## Definición declarativa de las variables editables de ajustes.gd
const AJUSTES_DEFINICIONES := {
	"jugador": [
		{"clave": "PLAYER_VELOCIDAD", "etiqueta": "Velocidad Jugador", "tipo": "float", "min": 2.0, "max": 15.0, "paso": 0.5, "default": 5.0, "unidad": " m/s"},
		{"clave": "PLAYER_VELOCIDAD_SALTO", "etiqueta": "Fuerza de Salto", "tipo": "float", "min": 3.0, "max": 15.0, "paso": 0.5, "default": 6.86, "unidad": " m/s"},
		{"clave": "PLAYER_ALCANCE_RAYCAST", "etiqueta": "Alcance de Interacción", "tipo": "float", "min": 2.0, "max": 15.0, "paso": 0.5, "default": 5.0, "unidad": " m"},
		{"clave": "PLAYER_OXIGENO_MAXIMO", "etiqueta": "Oxígeno Máximo", "tipo": "float", "min": 5.0, "max": 200.0, "paso": 5.0, "default": 10.0, "unidad": " s"},
		{"clave": "PLAYER_BATERIA_LAMPARA_MAX", "etiqueta": "Batería Lámpara", "tipo": "float", "min": 10.0, "max": 300.0, "paso": 10.0, "default": 72.0, "unidad": " h"},
	],
	"cenital": [
		{"clave": "CAMARA_CENITAL_VELOCIDAD_PANEO", "etiqueta": "Velocidad Paneo", "tipo": "float", "min": 5.0, "max": 60.0, "paso": 1.0, "default": 20.0, "unidad": ""},
		{"clave": "CAMARA_CENITAL_VELOCIDAD_ZOOM", "etiqueta": "Velocidad Zoom", "tipo": "float", "min": 1.0, "max": 15.0, "paso": 0.5, "default": 2.5, "unidad": ""},
		{"clave": "CAMARA_CENITAL_FOV", "etiqueta": "FOV Cámara Cenital", "tipo": "float", "min": 30.0, "max": 90.0, "paso": 5.0, "default": 60.0, "unidad": "°"},
	],
	"ciudad": [
		{"clave": "CIUDAD_SEGUNDOS_POR_TICK", "etiqueta": "Segundos por Tick", "tipo": "float", "min": 0.5, "max": 10.0, "paso": 0.5, "default": 2.0, "unidad": " s"},
		{"clave": "CIUDAD_LIMITE_BASE", "etiqueta": "Capacidad Base Almacén", "tipo": "float", "min": 100.0, "max": 5000.0, "paso": 50.0, "default": 500.0, "unidad": " u"},
		{"clave": "CIUDAD_COMIDA_INICIAL", "etiqueta": "Comida Inicial", "tipo": "float", "min": 100.0, "max": 10000.0, "paso": 100.0, "default": 5000.0, "unidad": " u"},
		{"clave": "CIUDAD_MORAL_INICIAL", "etiqueta": "Moral Inicial", "tipo": "float", "min": 10.0, "max": 100.0, "paso": 5.0, "default": 75.0, "unidad": "%"},
	],
	"economia": [
		{"clave": "ECONOMIA_CAPACIDAD_CARGA", "etiqueta": "Capacidad de Carga", "tipo": "float", "min": 20.0, "max": 1000.0, "paso": 10.0, "default": 150.0, "unidad": " kg"},
		{"clave": "ECONOMIA_HORAS_FORMACION", "etiqueta": "Horas Formación Técnico", "tipo": "int", "min": 2, "max": 100, "paso": 1, "default": 24, "unidad": " h"},
		{"clave": "ECONOMIA_RECURSOS_INICIALES", "etiqueta": "Recursos Iniciales", "tipo": "opcion", "opciones": ["supervivencia", "bajos", "medios", "altos"], "opciones_textos": ["RECURSOS_PERFIL_SUPERVIVENCIA", "RECURSOS_PERFIL_BAJOS", "RECURSOS_PERFIL_MEDIOS", "RECURSOS_PERFIL_ALTOS"], "default": "bajos"},
	],
}


func _ready() -> void:
	_inicializar_defaults_ajustes()
	cargar()
	aplicar()
	call_deferred("aplicar_modo_pantalla")


func _inicializar_defaults_ajustes() -> void:
	for cat in AJUSTES_DEFINICIONES.values():
		for item in cat:
			var c: String = item["clave"]
			var d = item["default"]
			if not variables_ajustes.has(c):
				variables_ajustes[c] = d


func cargar() -> void:
	cargar_configuracion()


func cargar_configuracion() -> void:
	_inicializar_defaults_ajustes()
	if not FileAccess.file_exists(RUTA_CONFIG):
		return

	var arch := FileAccess.open(RUTA_CONFIG, FileAccess.READ)
	if arch == null:
		return

	var texto := arch.get_as_text()
	var json = JSON.parse_string(texto)
	if not (json is Dictionary):
		return

	var datos: Dictionary = json
	if datos.has("volumen_sfx"):
		volumen_sfx = clampf(float(datos["volumen_sfx"]), 0.0, 1.0)
	if datos.has("volumen_musica"):
		volumen_musica = clampf(float(datos["volumen_musica"]), 0.0, 1.0)
	if datos.has("sensibilidad_mouse"):
		sensibilidad_mouse = clampf(float(datos["sensibilidad_mouse"]), 0.0005, 0.02)
	if datos.has("fov_camara"):
		fov_camara = clampf(float(datos["fov_camara"]), 50.0, 100.0)
	if datos.has("idioma"):
		idioma = str(datos["idioma"])
	if datos.has("modo_pantalla"):
		modo_pantalla = _normalizar_modo_pantalla(str(datos["modo_pantalla"]))

	if datos.has("variables_ajustes") and datos["variables_ajustes"] is Dictionary:
		var v_guardadas: Dictionary = datos["variables_ajustes"]
		for k in v_guardadas.keys():
			variables_ajustes[k] = v_guardadas[k]


func guardar() -> bool:
	var arch := FileAccess.open(RUTA_CONFIG, FileAccess.WRITE)
	if arch == null:
		push_error("No se pudo abrir %s para escritura." % RUTA_CONFIG)
		return false

	var datos := {
		"volumen_sfx": volumen_sfx,
		"volumen_musica": volumen_musica,
		"sensibilidad_mouse": sensibilidad_mouse,
		"fov_camara": fov_camara,
		"idioma": idioma,
		"modo_pantalla": modo_pantalla,
		"variables_ajustes": variables_ajustes,
	}
	arch.store_string(JSON.stringify(datos, "\t"))
	return true


func aplicar() -> void:
	# Sincroniza idioma
	Ajustes.idioma = idioma
	var strings = preload("res://scripts/strings.gd")
	strings.actualizar_idioma(idioma)

	# Sincroniza modo de pantalla
	aplicar_modo_pantalla()

	# Sincroniza sensibilidad del mouse en Ajustes y Player
	Ajustes.PLAYER_SENSIBILIDAD_MOUSE = sensibilidad_mouse
	Player.SENSIBILIDAD_MOUSE = sensibilidad_mouse

	# Sincroniza audio en Sonidos si está disponible
	if Engine.has_singleton("Sonidos") or get_node_or_null("/root/Sonidos") != null:
		var sonidos = get_node("/root/Sonidos")
		if sonidos.has_method("actualizar_volumen_sfx"):
			sonidos.actualizar_volumen_sfx(volumen_sfx)
		if sonidos.has_method("actualizar_volumen_musica"):
			sonidos.actualizar_volumen_musica(volumen_musica)

	# Actualiza FOV si hay un Player en el árbol
	var player = get_tree().root.find_child("Player", true, false)
	if player != null and player.has_node("Camara"):
		var cam: Camera3D = player.get_node("Camara") as Camera3D
		if cam != null:
			cam.fov = fov_camara

	# Aplica variables_ajustes a Ajustes
	for clave in variables_ajustes.keys():
		var val = variables_ajustes[clave]
		_aplicar_variable_ajuste(clave, val)


func _aplicar_variable_ajuste(clave: String, val: Variant) -> void:
	match clave:
		"PLAYER_VELOCIDAD":
			Ajustes.PLAYER_VELOCIDAD = float(val)
			Player.VELOCIDAD = float(val)
		"PLAYER_VELOCIDAD_SALTO":
			Ajustes.PLAYER_VELOCIDAD_SALTO = float(val)
			Player.VELOCIDAD_SALTO = float(val)
		"PLAYER_ALCANCE_RAYCAST":
			Ajustes.PLAYER_ALCANCE_RAYCAST = float(val)
			Player.ALCANCE_RAYCAST = float(val)
		"PLAYER_OXIGENO_MAXIMO":
			Ajustes.PLAYER_OXIGENO_MAXIMO = float(val)
		"PLAYER_BATERIA_LAMPARA_MAX":
			Ajustes.PLAYER_BATERIA_LAMPARA_MAX = float(val)
		"CAMARA_CENITAL_VELOCIDAD_PANEO":
			Ajustes.CAMARA_CENITAL_VELOCIDAD_PANEO = float(val)
		"CAMARA_CENITAL_VELOCIDAD_ZOOM":
			Ajustes.CAMARA_CENITAL_VELOCIDAD_ZOOM = float(val)
		"CAMARA_CENITAL_FOV":
			Ajustes.CAMARA_CENITAL_FOV = float(val)
			var cam_cen = get_tree().root.find_child("CamaraCenital", true, false)
			if cam_cen != null and "fov" in cam_cen:
				cam_cen.fov = float(val)
		"CIUDAD_SEGUNDOS_POR_TICK":
			Ajustes.CIUDAD_SEGUNDOS_POR_TICK = float(val)
		"CIUDAD_LIMITE_BASE":
			Ajustes.CIUDAD_LIMITE_BASE = float(val)
		"CIUDAD_COMIDA_INICIAL":
			Ajustes.CIUDAD_COMIDA_INICIAL = float(val)
		"CIUDAD_MORAL_INICIAL":
			Ajustes.CIUDAD_MORAL_INICIAL = float(val)
		"ECONOMIA_CAPACIDAD_CARGA":
			Ajustes.ECONOMIA_CAPACIDAD_CARGA = float(val)
		"ECONOMIA_HORAS_FORMACION":
			Ajustes.ECONOMIA_HORAS_FORMACION = int(val)
		"ECONOMIA_RECURSOS_INICIALES":
			Ajustes.ECONOMIA_RECURSOS_INICIALES = str(val).to_lower().strip_edges()


func obtener_valor_ajuste(clave: String, default_val: Variant = null) -> Variant:
	if variables_ajustes.has(clave):
		return variables_ajustes[clave]
	return default_val


func establecer_valor_ajuste(clave: String, valor: Variant) -> void:
	variables_ajustes[clave] = valor
	configuracion_cambiada.emit(clave, valor)


func restablecer_valores_defecto() -> void:
	volumen_sfx = 1.0
	volumen_musica = 0.8
	sensibilidad_mouse = 0.003
	fov_camara = 70.0
	idioma = "es"
	modo_pantalla = "pantalla_completa"

	for cat in AJUSTES_DEFINICIONES.values():
		for item in cat:
			variables_ajustes[item["clave"]] = item["default"]

	aplicar()
	guardar()


func establecer_volumen_sfx(valor: float) -> void:
	volumen_sfx = clampf(valor, 0.0, 1.0)
	if get_node_or_null("/root/Sonidos") != null:
		var sonidos = get_node("/root/Sonidos")
		if sonidos.has_method("actualizar_volumen_sfx"):
			sonidos.actualizar_volumen_sfx(volumen_sfx)
	configuracion_cambiada.emit("volumen_sfx", volumen_sfx)


func establecer_volumen_musica(valor: float) -> void:
	volumen_musica = clampf(valor, 0.0, 1.0)
	if get_node_or_null("/root/Sonidos") != null:
		var sonidos = get_node("/root/Sonidos")
		if sonidos.has_method("actualizar_volumen_musica"):
			sonidos.actualizar_volumen_musica(volumen_musica)
	configuracion_cambiada.emit("volumen_musica", volumen_musica)


func establecer_sensibilidad_mouse(valor: float) -> void:
	sensibilidad_mouse = clampf(valor, 0.0005, 0.02)
	Ajustes.PLAYER_SENSIBILIDAD_MOUSE = sensibilidad_mouse
	Player.SENSIBILIDAD_MOUSE = sensibilidad_mouse
	configuracion_cambiada.emit("sensibilidad_mouse", sensibilidad_mouse)


func establecer_fov_camara(valor: float) -> void:
	fov_camara = clampf(valor, 50.0, 100.0)
	var player = get_tree().root.find_child("Player", true, false)
	if player != null and player.has_node("Camara"):
		var cam: Camera3D = player.get_node("Camara") as Camera3D
		if cam != null:
			cam.fov = fov_camara
	configuracion_cambiada.emit("fov_camara", fov_camara)


func establecer_idioma(valor: String) -> void:
	idioma = valor
	Ajustes.idioma = idioma
	var strings = preload("res://scripts/strings.gd")
	strings.actualizar_idioma(idioma)
	configuracion_cambiada.emit("idioma", idioma)


func _normalizar_modo_pantalla(valor: String) -> String:
	var v: String = valor.to_lower().strip_edges()
	if v == "ventana" or v == "windowed":
		return "ventana"
	return "pantalla_completa"


func establecer_modo_pantalla(valor: String) -> void:
	modo_pantalla = _normalizar_modo_pantalla(valor)
	aplicar_modo_pantalla()
	configuracion_cambiada.emit("modo_pantalla", modo_pantalla)


func aplicar_modo_pantalla() -> void:
	if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless":
		return
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	var win: Window = tree.root if tree != null else null
	var embebido: bool = Engine.has_method("is_embedded_in_editor") and bool(Engine.call("is_embedded_in_editor"))
	if modo_pantalla == "ventana":
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var tam_win: Vector2i = TAMANO_VENTANA_DEFAULT
		if usable.size != Vector2i.ZERO:
			tam_win = Vector2i(mini(TAMANO_VENTANA_DEFAULT.x, usable.size.x), mini(TAMANO_VENTANA_DEFAULT.y, usable.size.y))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(tam_win)
		if win != null:
			win.borderless = false
			win.mode = Window.MODE_WINDOWED
			win.size = tam_win
		if not embebido and usable.size != Vector2i.ZERO:
			var pos := usable.position + (usable.size - tam_win) / 2
			DisplayServer.window_set_position(pos)
			if win != null:
				win.position = pos
	else:
		if win != null:
			win.mode = Window.MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
