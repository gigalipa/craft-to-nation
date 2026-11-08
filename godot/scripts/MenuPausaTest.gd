extends Node

## Suite de pruebas unitarias para MenuPausa.gd con íconos, atajo F12 y panel extendido.

const MenuPausaScript = preload("res://scripts/MenuPausa.gd")

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_instanciacion_y_process_mode()
	test_iconos_y_atajo_f12()
	test_visibilidad_y_alternancia()
	test_senales_menu_pausa()
	test_controles_configuracion_en_pausa()
	test_guardado_rapido_desde_menu()


func test_instanciacion_y_process_mode() -> void:
	var menu := MenuPausaScript.new()
	add_child(menu)
	assert(menu.process_mode == Node.PROCESS_MODE_ALWAYS, "MenuPausa debe procesar siempre (incluso en pausa).")
	assert(not menu.visible, "MenuPausa debe iniciar oculto.")
	assert(not menu.esta_abierto(), "esta_abierto() debe ser falso al inicio.")
	menu.queue_free()
	print("OK: Instanciación y process_mode de MenuPausa.")


func test_iconos_y_atajo_f12() -> void:
	var menu := MenuPausaScript.new()
	add_child(menu)

	var quicksave_encontrado := false
	for child in menu._panel_principal.get_children():
		if child is Button:
			var btn := child as Button
			assert(btn.icon != null, "El botón '%s' debe tener un ícono asignado." % btn.text)
			if "F12" in btn.text:
				quicksave_encontrado = true

	assert(quicksave_encontrado, "El botón de guardado rápido debe indicar el atajo F12.")

	menu.queue_free()
	print("OK: Íconos en botones de pausa y etiqueta de atajo F12.")


func test_visibilidad_y_alternancia() -> void:
	var menu := MenuPausaScript.new()
	add_child(menu)
	menu.mostrar()
	assert(menu.visible, "mostrar() debe hacer visible el menú.")
	assert(menu.esta_abierto(), "esta_abierto() debe ser true tras mostrar().")

	menu.ocultar()
	assert(not menu.visible, "ocultar() debe ocultar el menú.")
	assert(not menu.esta_abierto(), "esta_abierto() debe ser false tras ocultar().")
	menu.queue_free()
	print("OK: Visibilidad y alternancia de MenuPausa.")


func test_senales_menu_pausa() -> void:
	var menu := MenuPausaScript.new()
	add_child(menu)

	var estado := {"reanudo": false, "salio": false}
	menu.reanudar_solicitado.connect(func(): estado["reanudo"] = true)
	menu._on_reanudar_pressed()
	assert(estado["reanudo"] == true, "Al presionar reanudar debe emitirse la señal reanudar_solicitado.")

	menu.salir_al_menu_solicitado.connect(func(): estado["salio"] = true)
	menu._on_salir_pressed()
	assert(estado["salio"] == true, "Al presionar salir debe emitirse la señal salir_al_menu_solicitado.")

	menu.queue_free()
	print("OK: Señales de reanudar y salir.")


func test_controles_configuracion_en_pausa() -> void:
	var menu := MenuPausaScript.new()
	add_child(menu)
	menu.mostrar()
	menu._abrir_panel_configuracion()

	assert(menu._panel_configuracion != null, "MenuPausa debe contener PanelConfiguracionAjustes.")
	assert(menu._panel_configuracion._slider_sfx != null, "Debe existir slider SFX.")

	menu._panel_configuracion._slider_sfx.value = 50.0
	menu._panel_configuracion._slider_musica.value = 40.0
	menu._panel_configuracion._on_guardar_pressed()

	assert(abs(Configuracion.volumen_sfx - 0.5) < 0.05, "Modificar slider SFX debe actualizar Configuracion.volumen_sfx.")
	assert(abs(Configuracion.volumen_musica - 0.4) < 0.05, "Modificar slider Música debe actualizar Configuracion.volumen_musica.")

	# Restaurar defaults
	menu._panel_configuracion._on_reset_pressed()

	menu.queue_free()
	print("OK: Modificación de configuración en tiempo real desde menú de pausa.")


func test_guardado_rapido_desde_menu() -> void:
	var menu := MenuPausaScript.new()
	add_child(menu)
	menu._on_quicksave_pressed()
	var ruta_qs := GestorPartida.obtener_ruta_partida(GestorPartida.ARCHIVO_QUICKSAVE)
	assert(FileAccess.file_exists(ruta_qs), "El botón de guardado rápido debe persistir quicksave.json.")
	GestorPartida.eliminar_partida(GestorPartida.ARCHIVO_QUICKSAVE)
	menu.queue_free()
	print("OK: Botón de Guardado Rápido en menú de pausa.")
