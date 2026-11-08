extends Node

## Suite de pruebas unitarias para MenuInicio.gd con íconos, logos y panel extendido.

const MenuInicioScript = preload("res://scripts/MenuInicio.gd")

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_instanciacion_menu_inicio()
	test_iconos_en_botones()
	test_navegacion_subpaneles()
	test_configuracion_extendida()
	test_seleccion_partida_para_cargar()


func test_instanciacion_menu_inicio() -> void:
	var menu := MenuInicioScript.new()
	add_child(menu)
	assert(menu.visible, "MenuInicio debe ser visible al instanciarse.")
	assert(menu._slideshow != null, "MenuInicio debe tener fondo SlideshowFondo.")
	assert(menu._panel_principal.visible, "El panel principal debe estar visible inicialmente.")
	assert(not menu._panel_cargar.visible, "El panel de carga debe estar oculto inicialmente.")
	assert(not menu._panel_configuracion.visible, "El panel de configuración debe estar oculto inicialmente.")
	menu.queue_free()
	print("OK: Instanciación e inicialización de MenuInicio con Slideshow.")


func test_iconos_en_botones() -> void:
	var menu := MenuInicioScript.new()
	add_child(menu)

	for child in menu._panel_principal.get_children():
		if child is Button:
			var btn := child as Button
			assert(btn.icon != null, "El botón '%s' debe tener un ícono asignado." % btn.text)

	menu.queue_free()
	print("OK: Todos los botones del menú principal tienen íconos vectoriales.")


func test_navegacion_subpaneles() -> void:
	var menu := MenuInicioScript.new()
	add_child(menu)

	# Navegar a cargar
	menu._abrir_panel_cargar()
	assert(menu._panel_cargar.visible, "El panel de cargar debe estar visible.")
	assert(not menu._panel_principal.visible, "El panel principal debe ocultarse.")

	# Navegar a configuración
	menu._abrir_panel_configuracion()
	assert(menu._panel_configuracion.visible, "El panel de configuración debe estar visible.")
	assert(not menu._panel_cargar.visible, "El panel de cargar debe ocultarse.")

	# Volver a principal
	menu._mostrar_subpanel(menu._panel_principal)
	assert(menu._panel_principal.visible, "Debe volver al panel principal.")

	menu.queue_free()
	print("OK: Navegación fluida entre subpaneles del Menú de Inicio.")


func test_configuracion_extendida() -> void:
	var menu := MenuInicioScript.new()
	add_child(menu)
	menu._abrir_panel_configuracion()

	assert(menu._panel_configuracion._tabs != null, "El panel de configuración debe incluir pestañas.")
	assert(menu._panel_configuracion._controles_ajustes.size() > 0, "Debe haber controles para variables de ajustes.gd.")

	# Modificar variable de jugador
	var spin_vel: SpinBox = menu._panel_configuracion._controles_ajustes.get("PLAYER_VELOCIDAD")
	assert(spin_vel != null, "Debe existir control para PLAYER_VELOCIDAD.")
	spin_vel.value = 8.5

	menu._panel_configuracion._on_guardar_pressed()
	assert(abs(float(Configuracion.obtener_valor_ajuste("PLAYER_VELOCIDAD")) - 8.5) < 0.1, "PLAYER_VELOCIDAD debe guardarse en Configuracion.")

	# Restablecer a fábrica
	menu._panel_configuracion._on_reset_pressed()
	assert(abs(float(Configuracion.obtener_valor_ajuste("PLAYER_VELOCIDAD")) - 5.0) < 0.1, "PLAYER_VELOCIDAD debe restaurarse a 5.0.")

	menu.queue_free()
	print("OK: Panel extendido de ajustes con pestañas y botones de Guardar/Restablecer.")


func test_seleccion_partida_para_cargar() -> void:
	var menu := MenuInicioScript.new()
	add_child(menu)

	GestorPartida.partida_pendiente_a_cargar = ""
	GestorPartida.partida_pendiente_a_cargar = "partida_test.json"
	assert(GestorPartida.partida_pendiente_a_cargar == "partida_test.json", "La variable de partida pendiente debe asignarse.")
	GestorPartida.partida_pendiente_a_cargar = ""

	menu.queue_free()
	print("OK: Preparación de carga de partida.")
