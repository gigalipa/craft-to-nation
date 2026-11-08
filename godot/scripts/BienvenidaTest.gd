extends Node

## Suite de pruebas unitarias para Bienvenida.gd.

const BienvenidaScript = preload("res://scripts/Bienvenida.gd")

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_instanciacion_bienvenida()
	test_geometria_y_proporciones()
	test_animacion_pulso()


func test_instanciacion_bienvenida() -> void:
	var bienv := BienvenidaScript.new()
	bienv.duracion_pantalla = 999.0 # Evitar autoavance durante test
	add_child(bienv)

	assert(bienv._fondo != null, "Bienvenida debe tener fondo ColorRect.")
	assert(bienv._logo_rect != null, "Bienvenida debe tener TextureRect de logo.")
	assert(bienv._texto_rect != null, "Bienvenida debe tener TextureRect de texto.")

	assert(bienv._logo_rect.texture != null, "El logo debe tener textura cargada.")
	assert(bienv._texto_rect.texture != null, "El texto debe tener textura cargada.")

	bienv.queue_free()
	print("OK: Instanciación de pantalla de bienvenida.")


func test_geometria_y_proporciones() -> void:
	var bienv := BienvenidaScript.new()
	bienv.duracion_pantalla = 999.0
	add_child(bienv)

	var vp_size := bienv.get_viewport_rect().size
	if vp_size.y <= 0:
		vp_size = Vector2(1280, 720)

	var h := vp_size.y
	var w := vp_size.x

	var margen_top := h * 0.10
	var alto_logo := h * 0.50
	var separador := h * 0.05
	var alto_texto := h * 0.25

	# Margen y alto del logo
	assert(abs(bienv._logo_rect.position.y - margen_top) < 1.0, "Margen superior del logo debe ser 10% de la altura.")
	assert(abs(bienv._logo_rect.size.y - alto_logo) < 1.0, "Altura del logo debe ser 50% de la altura.")

	# Posición y alto del texto
	var esperado_y_texto := margen_top + alto_logo + separador
	assert(abs(bienv._texto_rect.position.y - esperado_y_texto) < 1.0, "Texto debe estar separado 5% bajo el logo.")
	assert(abs(bienv._texto_rect.size.y - alto_texto) < 1.0, "Altura del texto debe ser 25% de la altura.")

	# Verificación de centrado horizontal
	assert(bienv._logo_rect.position.x == 0.0, "Logo debe iniciar en x=0 para centrado con STRETCH_KEEP_ASPECT_CENTERED.")
	assert(abs(bienv._logo_rect.size.x - w) < 1.0, "Ancho del logo debe cubrir todo el ancho de viewport.")
	assert(bienv._logo_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Logo debe tener modo STRETCH_KEEP_ASPECT_CENTERED.")

	assert(bienv._texto_rect.position.x == 0.0, "Texto debe iniciar en x=0 para centrado con STRETCH_KEEP_ASPECT_CENTERED.")
	assert(abs(bienv._texto_rect.size.x - w) < 1.0, "Ancho del texto debe cubrir todo el ancho de viewport.")
	assert(bienv._texto_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Texto debe tener modo STRETCH_KEEP_ASPECT_CENTERED.")

	bienv.queue_free()
	print("OK: Proporciones exactas 10%-50%-5%-25%-10% y centrado horizontal.")


func test_animacion_pulso() -> void:
	var bienv := BienvenidaScript.new()
	bienv.duracion_pantalla = 999.0
	add_child(bienv)

	assert(bienv._tween_pulso != null, "Tween de pulso debe estar instanciado.")
	assert(bienv._tween_pulso.is_valid(), "Tween de pulso debe ser válido.")

	bienv.queue_free()
	print("OK: Animación continua de pulso sutil del logo.")
