extends Control
class_name Bienvenida

## Pantalla de bienvenida cinematográfica (Boot / Splash Screen).
## Muestra el logotipo oficial con animación de pulso sutil y proporciones 10%-50%-5%-25%-10%.
## Precarga en segundo plano la caché de partidas y configuraciones antes de abrir el Menú Principal.

const RUTA_LOGO := "res://assets/logo/craft-to-nation-logo.png"
const RUTA_TEXTO := "res://assets/logo/craft_to_nation_text.png"
const ESCENA_MENU_INICIO := "res://scenes/MenuInicio.tscn"

@export var duracion_pantalla: float = 2.0
@export var duracion_fade_out: float = 0.5

var _logo_rect: TextureRect
var _texto_rect: TextureRect
var _fondo: ColorRect
var _tween_pulso: Tween
var _transicionando: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fondo temático verde noche
	_fondo = ColorRect.new()
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.color = Color(0.043, 0.086, 0.071, 1.0) # #0b1612
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)

	# Logo con escalado centrado
	_logo_rect = TextureRect.new()
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.texture = _cargar_textura(RUTA_LOGO)
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo_rect)

	# Texto tipográfico con escalado centrado
	_texto_rect = TextureRect.new()
	_texto_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texto_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texto_rect.texture = _cargar_textura(RUTA_TEXTO)
	_texto_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texto_rect)

	_actualizar_geometria()
	get_viewport().size_changed.connect(_actualizar_geometria)

	_iniciar_pulso()
	_ejecutar_precargas()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_actualizar_geometria()


func _actualizar_geometria() -> void:
	if _logo_rect == null or _texto_rect == null:
		return

	var vp_size := get_viewport_rect().size
	if vp_size.y <= 0:
		vp_size = Vector2(1280, 720)

	var w := vp_size.x
	var h := vp_size.y

	# Proporciones exactas: 10% margen superior, 50% logo, 5% separación, 25% texto, 10% margen inferior
	var margen_top := h * 0.10
	var alto_logo := h * 0.50
	var separador := h * 0.05
	var alto_texto := h * 0.25

	_logo_rect.position = Vector2(0, margen_top)
	_logo_rect.size = Vector2(w, alto_logo)
	_logo_rect.pivot_offset = Vector2(w * 0.5, alto_logo * 0.5)

	_texto_rect.position = Vector2(0, margen_top + alto_logo + separador)
	_texto_rect.size = Vector2(w, alto_texto)
	_texto_rect.pivot_offset = Vector2(w * 0.5, alto_texto * 0.5)


func _iniciar_pulso() -> void:
	if _tween_pulso != null and _tween_pulso.is_valid():
		_tween_pulso.kill()

	_tween_pulso = create_tween().set_loops()
	_tween_pulso.tween_property(_logo_rect, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_pulso.parallel().tween_property(_logo_rect, "modulate", Color(1.05, 1.05, 1.05, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_pulso.tween_property(_logo_rect, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_pulso.parallel().tween_property(_logo_rect, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _cargar_textura(ruta: String) -> Texture2D:
	if FileAccess.file_exists(ruta + ".import"):
		var t = load(ruta) as Texture2D
		if t != null:
			return t

	var ruta_global := ProjectSettings.globalize_path(ruta)
	if FileAccess.file_exists(ruta) or FileAccess.file_exists(ruta_global):
		var img := Image.load_from_file(ruta_global)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


func _ejecutar_precargas() -> void:
	# Precarga de caché de partidas
	if GestorPartida != null and GestorPartida.has_method("precargar_metadatos_partidas"):
		GestorPartida.precargar_metadatos_partidas()

	# Carga de configuraciones de usuario
	if Configuracion != null and Configuracion.has_method("cargar_configuracion"):
		Configuracion.cargar_configuracion()

	# Espera para disfrute visual y transición suave
	await get_tree().create_timer(duracion_pantalla).timeout
	_avanzar_a_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_avanzar_a_menu()
	elif event is InputEventMouseButton and event.pressed:
		_avanzar_a_menu()


func _avanzar_a_menu() -> void:
	if _transicionando:
		return
	_transicionando = true

	if _tween_pulso != null and _tween_pulso.is_valid():
		_tween_pulso.kill()

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duracion_fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	get_tree().change_scene_to_file(ESCENA_MENU_INICIO)
