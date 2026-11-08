extends Control
class_name SlideshowFondo

## Fondo animado con transición de imágenes tipo slideshow (fade-out / crossfade).
## Cicla imágenes de res://assets/slideshow/ cada 10 segundos con oscurecimiento para UI.

@export var intervalo_segundos: float = 10.0
@export var duracion_fade: float = 1.2
@export var oscurecimiento: float = 0.40

var _texturas: Array[Texture2D] = []
var _indice_actual: int = 0
var _tiempo_acumulado: float = 0.0

var _rect_a: TextureRect
var _rect_b: TextureRect
var _overlay: ColorRect
var _tween: Tween

const CARPETA_SLIDESHOW := "res://assets/slideshow/"

# Lista fija de respaldo en caso de que DirAccess no liste archivos en export headless
const IMAGENES_DEFAULT := [
	"citycraft-world.jpg",
	"comparison-aerial.jpg",
	"concept-era-evolution.png",
	"fp-building.jpg",
	"fp-defense.jpg",
	"fp-industry.jpg",
	"hud-camara-cenital.png",
	"hud-primera-persona-batalla.png",
	"hud-primera-persona-construccion.png"
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Crear capas visuales
	_rect_a = _crear_texture_rect()
	_rect_b = _crear_texture_rect()
	_rect_b.modulate.a = 0.0

	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, oscurecimiento)

	add_child(_rect_a)
	add_child(_rect_b)
	add_child(_overlay)

	_cargar_imagenes()

	if not _texturas.is_empty():
		_rect_a.texture = _texturas[0]
		_rect_a.modulate.a = 1.0


func _crear_texture_rect() -> TextureRect:
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return tr


func _cargar_imagenes() -> void:
	var rutas: Array[String] = []

	var dir := DirAccess.open(CARPETA_SLIDESHOW)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				var ext := file_name.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp"]:
					rutas.append(CARPETA_SLIDESHOW + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	if rutas.is_empty():
		for nom in IMAGENES_DEFAULT:
			rutas.append(CARPETA_SLIDESHOW + nom)

	for r in rutas:
		var tex := cargar_textura(r)
		if tex != null:
			_texturas.append(tex)


static func cargar_textura(ruta: String) -> Texture2D:
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


func _process(delta: float) -> void:
	if _texturas.size() <= 1:
		return

	_tiempo_acumulado += delta
	if _tiempo_acumulado >= intervalo_segundos:
		_tiempo_acumulado = 0.0
		_transicionar_siguiente()


func _transicionar_siguiente() -> void:
	if _texturas.size() <= 1:
		return

	var siguiente_indice := (_indice_actual + 1) % _texturas.size()
	var siguiente_tex := _texturas[siguiente_indice]

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_rect_b.texture = siguiente_tex
	_rect_b.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_rect_b, "modulate:a", 1.0, duracion_fade)
	_tween.parallel().tween_property(_rect_a, "modulate:a", 0.0, duracion_fade)
	_tween.tween_callback(func():
		_rect_a.texture = siguiente_tex
		_rect_a.modulate.a = 1.0
		_rect_b.modulate.a = 0.0
		_indice_actual = siguiente_indice
	)
