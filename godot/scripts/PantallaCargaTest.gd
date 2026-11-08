extends Node

## Suite de pruebas unitarias para PantallaCarga.gd.

const PantallaCargaScript = preload("res://scripts/PantallaCarga.gd")

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_instanciacion_pantalla_carga()
	test_barra_progreso_invertida()
	test_etiquetas_y_slideshow()


func test_instanciacion_pantalla_carga() -> void:
	var pc := PantallaCargaScript.new()
	pc.auto_iniciar_carga = false
	add_child(pc)

	assert(pc._slideshow != null, "PantallaCarga debe contener un fondo SlideshowFondo.")
	assert(pc._barra_progreso != null, "PantallaCarga debe tener una ProgressBar.")
	assert(pc._lbl_estado != null, "PantallaCarga debe tener una etiqueta de estado.")
	assert(pc._lbl_porcentaje != null, "PantallaCarga debe tener una etiqueta de porcentaje.")

	pc.queue_free()
	print("OK: Instanciación e interfaz de PantallaCarga.")


func test_barra_progreso_invertida() -> void:
	var pc := PantallaCargaScript.new()
	pc.auto_iniciar_carga = false
	add_child(pc)

	# ProgressBar.FILL_END_TO_BEGIN es 1 en Godot 4 (llena de derecha a izquierda)
	assert(pc._barra_progreso.fill_mode == ProgressBar.FILL_END_TO_BEGIN, "La barra de carga debe llenarse de derecha a izquierda (FILL_END_TO_BEGIN).")

	pc.queue_free()
	print("OK: Barra de carga de derecha a izquierda.")


func test_etiquetas_y_slideshow() -> void:
	var pc := PantallaCargaScript.new()
	pc.auto_iniciar_carga = false
	add_child(pc)

	assert(pc._slideshow._texturas.size() > 0, "SlideshowFondo debe tener texturas cargadas.")
	assert(pc._slideshow._overlay != null, "SlideshowFondo debe tener capa de oscurecimiento.")

	pc.queue_free()
	print("OK: Componentes de slideshow y estados dinámicos.")
