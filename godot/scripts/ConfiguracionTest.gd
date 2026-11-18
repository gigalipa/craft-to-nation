extends Node

## Suite de pruebas unitarias para Configuracion.gd y la integración BGM en Sonidos.gd.

const Ajustes = preload("res://scripts/ajustes.gd")

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_inicializacion_configuracion()
	test_modificacion_y_senales()
	test_persistencia_guardar_y_cargar()
	test_variables_ajustes_persistencia()
	test_cambio_idioma_y_traduccion()
	test_integracion_bgm_sonidos()
	test_catalogo_transporte_huellas_y_vias()
	test_selector_recursos_iniciales()


func test_catalogo_transporte_huellas_y_vias() -> void:
	assert("VIAS_PENALIZACION_CARRIL_IZQUIERDO" in Ajustes, "Ajustes debe definir VIAS_PENALIZACION_CARRIL_IZQUIERDO.")
	assert(Ajustes.VIAS_PENALIZACION_CARRIL_IZQUIERDO == 4, "Penalización carril izquierdo debe ser 4.")

	for id_u in Ajustes.TRANSPORTE_CATALOGO_UNIDADES:
		var u: Dictionary = Ajustes.TRANSPORTE_CATALOGO_UNIDADES[id_u]
		assert(u.has("huella"), "Cada unidad en TRANSPORTE_CATALOGO_UNIDADES debe tener campo 'huella'.")
		assert(u["huella"] is Vector2i, "La huella debe ser un Vector2i.")
		assert(u["huella"].x >= 1 and u["huella"].y >= 1, "Las dimensiones de la huella deben ser positivas.")

	assert(Ajustes.TRANSPORTE_CATALOGO_UNIDADES["acarreador_pie"]["huella"] == Vector2i(1, 1))
	assert(Ajustes.TRANSPORTE_CATALOGO_UNIDADES["camion_diesel"]["huella"] == Vector2i(2, 3))
	print("OK: Catálogo de transporte y huellas en Ajustes.")


func test_cambio_idioma_y_traduccion() -> void:
	var strings = preload("res://scripts/strings.gd")
	var barra_superior_script = preload("res://scripts/BarraSuperior.gd")
	var hotbar_script = preload("res://scripts/Hotbar.gd")

	# Cambiar a inglés
	Configuracion.establecer_idioma("en")
	assert(Configuracion.idioma == "en", "El idioma en Configuracion debe ser 'en'.")
	assert(Ajustes.idioma == "en", "El idioma en Ajustes debe ser 'en'.")
	assert(strings.NOMBRES_RECURSO["madera"] == "Wood", "NOMBRES_RECURSO['madera'] debe traducirse a 'Wood'.")
	assert(strings.NOMBRES_RECURSO["comida"] == "Food", "NOMBRES_RECURSO['comida'] debe traducirse a 'Food'.")
	assert(strings.HOTBAR_NOMBRES["bloque_madera"] == "Wood", "HOTBAR_NOMBRES['bloque_madera'] debe ser 'Wood'.")
	assert(strings.HOTBAR_NOMBRES["tierra"] == "Dirt", "HOTBAR_NOMBRES['tierra'] debe ser 'Dirt'.")
	assert(hotbar_script.nombre_hotbar_de("bloque_madera") == "Wood", "nombre_hotbar_de('bloque_madera') debe ser 'Wood'.")
	assert(hotbar_script.nombre_hotbar_de("tierra") == "Dirt", "nombre_hotbar_de('tierra') debe ser 'Dirt'.")
	assert(strings.t("MENU_NUEVA_PARTIDA") == "New Game", "Strings.t('MENU_NUEVA_PARTIDA') debe ser 'New Game'.")
	assert(strings.VENTANA_ALMACEN_TITULO == "Warehouse", "VENTANA_ALMACEN_TITULO debe ser 'Warehouse'.")
	assert(Ciudad.almacen["madera"].nombre == "Wood", "Ciudad.almacen['madera'].nombre debe ser 'Wood'.")
	assert(Ciudad.almacen["comida"].nombre == "Food", "Ciudad.almacen['comida'].nombre debe ser 'Food'.")
	assert(barra_superior_script.texto_comida(100.0, 500.0, -2.0).begins_with("Food:"), "texto_comida en inglés debe comenzar con 'Food:'.")
	assert(IconosHUD.icono("wood") != null, "IconosHUD debe resolver alias 'wood'.")
	assert(IconosHUD.icono("food") != null, "IconosHUD debe resolver alias 'food'.")
	assert(IconosHUD.icono("censo") != null, "IconosHUD debe cargar 'censo'.")
	assert(IconosHUD.icono("comida") != null, "IconosHUD debe cargar 'comida'.")

	# Cambiar a español
	Configuracion.establecer_idioma("es")
	assert(strings.NOMBRES_RECURSO["madera"] == "Madera", "NOMBRES_RECURSO['madera'] debe ser 'Madera'.")
	assert(strings.NOMBRES_RECURSO["comida"] == "Comida", "NOMBRES_RECURSO['comida'] debe ser 'Comida'.")
	assert(strings.HOTBAR_NOMBRES["bloque_madera"] == "Madera", "HOTBAR_NOMBRES['bloque_madera'] debe ser 'Madera'.")
	assert(hotbar_script.nombre_hotbar_de("bloque_madera") == "Madera", "nombre_hotbar_de('bloque_madera') debe ser 'Madera'.")
	assert(strings.t("MENU_NUEVA_PARTIDA") == "Nueva Partida", "Strings.t('MENU_NUEVA_PARTIDA') debe ser 'Nueva Partida'.")
	assert(Ciudad.almacen["comida"].nombre == "Comida", "Ciudad.almacen['comida'].nombre debe ser 'Comida'.")
	assert(barra_superior_script.texto_comida(100.0, 500.0, -2.0).begins_with("Comida:"), "texto_comida en español debe comenzar con 'Comida:'.")
	print("OK: Cambio dinámico de idioma y traducción al inglés verificado.")


func test_variables_ajustes_persistencia() -> void:
	Configuracion.establecer_valor_ajuste("PLAYER_VELOCIDAD", 7.5)
	Configuracion.establecer_valor_ajuste("CAMARA_CENITAL_FOV", 75.0)
	Configuracion.aplicar()
	Configuracion.guardar()

	assert(abs(Ajustes.PLAYER_VELOCIDAD - 7.5) < 0.1, "Ajustes.PLAYER_VELOCIDAD debe actualizarse.")
	assert(abs(Player.VELOCIDAD - 7.5) < 0.1, "Player.VELOCIDAD debe actualizarse.")

	# Reiniciar y recargar
	Configuracion.cargar()
	assert(abs(float(Configuracion.obtener_valor_ajuste("PLAYER_VELOCIDAD")) - 7.5) < 0.1, "PLAYER_VELOCIDAD debe recargarse de disco.")

	# Restablecer por defecto
	Configuracion.restablecer_valores_defecto()
	assert(abs(float(Configuracion.obtener_valor_ajuste("PLAYER_VELOCIDAD")) - 5.0) < 0.1, "Debe restaurarse al default 5.0.")
	print("OK: Persistencia y aplicación de variables de balance de ajustes.gd.")


func test_inicializacion_configuracion() -> void:
	assert(Configuracion != null, "El autoload Configuracion debe estar activo.")
	assert(Configuracion.volumen_sfx >= 0.0 and Configuracion.volumen_sfx <= 1.0, "Volumen SFX fuera de rango.")
	assert(Configuracion.volumen_musica >= 0.0 and Configuracion.volumen_musica <= 1.0, "Volumen Música fuera de rango.")
	assert(Configuracion.sensibilidad_mouse > 0.0, "Sensibilidad debe ser positiva.")
	assert(Configuracion.fov_camara >= 50.0 and Configuracion.fov_camara <= 100.0, "FOV debe estar entre 50 y 100.")
	print("OK: Inicialización de Configuracion.")


func test_modificacion_y_senales() -> void:
	var cambios: Dictionary = {}
	var callback = func(clave: String, valor: Variant):
		cambios[clave] = valor
	Configuracion.configuracion_cambiada.connect(callback)

	Configuracion.volumen_sfx = 0.6
	assert(cambios.get("volumen_sfx") == 0.6, "La señal configuracion_cambiada debe reportar volumen_sfx.")
	assert(Sonidos.sfx_habilitado == true, "SFX debe seguir habilitado.")

	Configuracion.volumen_musica = 0.4
	assert(cambios.get("volumen_musica") == 0.4, "La señal configuracion_cambiada debe reportar volumen_musica.")

	Configuracion.sensibilidad_mouse = 0.005
	assert(Ajustes.PLAYER_SENSIBILIDAD_MOUSE == 0.005, "Ajustes.PLAYER_SENSIBILIDAD_MOUSE debe sincronizarse.")
	assert(Player.SENSIBILIDAD_MOUSE == 0.005, "Player.SENSIBILIDAD_MOUSE debe sincronizarse.")

	Configuracion.fov_camara = 85.0
	assert(Configuracion.fov_camara == 85.0, "FOV de cámara debe actualizarse a 85.0.")

	Configuracion.configuracion_cambiada.disconnect(callback)
	print("OK: Modificación reactiva y señales de Configuracion.")


func test_persistencia_guardar_y_cargar() -> void:
	Configuracion.volumen_sfx = 0.75
	Configuracion.volumen_musica = 0.65
	Configuracion.sensibilidad_mouse = 0.0045
	Configuracion.fov_camara = 78.0
	Configuracion.idioma = "es"

	var guardado_exitoso := Configuracion.guardar()
	assert(guardado_exitoso, "Configuracion.guardar() debe retornar true.")
	assert(FileAccess.file_exists(Configuracion.RUTA_CONFIG), "El archivo configuracion.json debe existir en user://")

	# Modifica temporalmente en memoria
	Configuracion.volumen_sfx = 0.1
	Configuracion.volumen_musica = 0.1
	assert(Configuracion.volumen_sfx == 0.1, "Debe haberse modificado localmente.")

	# Carga de nuevo desde disco
	Configuracion.cargar()
	assert(abs(Configuracion.volumen_sfx - 0.75) < 0.01, "volumen_sfx debe restaurarse.")
	assert(abs(Configuracion.volumen_musica - 0.65) < 0.01, "volumen_musica debe restaurarse.")
	assert(abs(Configuracion.sensibilidad_mouse - 0.0045) < 0.0001, "sensibilidad_mouse debe restaurarse.")
	assert(abs(Configuracion.fov_camara - 78.0) < 0.1, "fov_camara debe restaurarse.")
	# Restaurar valores por defecto para no afectar otras pruebas
	Configuracion.volumen_sfx = 1.0
	Configuracion.volumen_musica = 0.8
	Configuracion.sensibilidad_mouse = 0.003
	Configuracion.fov_camara = 70.0
	Configuracion.idioma = "es"
	Configuracion.guardar()
	print("OK: Persistencia en user://configuracion.json.")


func test_integracion_bgm_sonidos() -> void:
	assert(Sonidos._player_musica != null, "Sonidos debe tener un AudioStreamPlayer para música.")
	assert(Sonidos._player_musica.process_mode == Node.PROCESS_MODE_ALWAYS, "El player de música debe correr en pausa.")

	# Probar música de menú
	Sonidos.reproducir_musica_menu()
	assert(Sonidos._player_musica.stream != null, "La música de menú debe haber cargado un stream.")

	# Probar detención
	Sonidos.detener_musica()
	assert(not Sonidos._player_musica.playing, "La música debe haberse detenido.")

	# Probar música de juego
	Sonidos.reproducir_musica_juego()
	assert(Sonidos._player_musica.stream != null, "La música de juego debe haber cargado un stream.")
	Sonidos.detener_musica()

	print("OK: Integración BGM en Sonidos.")


func test_selector_recursos_iniciales() -> void:
	# 1. Validar categorías y perfiles en Ajustes
	assert("CATEGORIAS_RECURSOS" in Ajustes, "Ajustes debe definir CATEGORIAS_RECURSOS.")
	assert(Ajustes.CATEGORIAS_RECURSOS["minerales"].has("agua"), "El agua debe pertenecer a la categoría 'minerales'.")
	assert(Ajustes.CATEGORIAS_RECURSOS["materias_primas"].has("madera"), "La madera debe ser materia prima.")

	# 2. Perfil Supervivencia
	Configuracion.establecer_valor_ajuste("ECONOMIA_RECURSOS_INICIALES", "supervivencia")
	Configuracion.aplicar()
	assert(Ajustes.ECONOMIA_RECURSOS_INICIALES == "supervivencia")
	var stock_sup: Dictionary = Ajustes.cantidades_recursos_iniciales("supervivencia")
	assert(stock_sup["comida"] == Ajustes.CIUDAD_COMIDA_INICIAL)
	assert(stock_sup["madera"] == 0.0)
	assert(stock_sup["hierro"] == 0.0)
	assert(stock_sup["agua"] == 0.0)
	assert(stock_sup["vidrio"] == 0.0)

	# 3. Perfil Bajos
	var stock_baj: Dictionary = Ajustes.cantidades_recursos_iniciales("bajos")
	assert(stock_baj["comida"] == Ajustes.CIUDAD_COMIDA_INICIAL)
	assert(stock_baj["madera"] == 300.0)
	assert(stock_baj["tierra"] == 300.0)
	assert(stock_baj["piedra"] == 300.0)
	assert(stock_baj["hierro"] == 0.0)
	assert(stock_baj["agua"] == 0.0)

	# 4. Perfil Medios
	var stock_med: Dictionary = Ajustes.cantidades_recursos_iniciales("medios")
	assert(stock_med["comida"] == Ajustes.CIUDAD_COMIDA_INICIAL)
	assert(stock_med["madera"] == 600.0)
	assert(stock_med["hierro"] == 300.0)
	assert(stock_med["agua"] == 300.0)
	assert(stock_med["vidrio"] == 0.0)

	# 5. Perfil Altos
	var stock_alt: Dictionary = Ajustes.cantidades_recursos_iniciales("altos")
	assert(stock_alt["comida"] == Ajustes.CIUDAD_COMIDA_INICIAL)
	assert(stock_alt["madera"] == 1000.0)
	assert(stock_alt["hierro"] == 600.0)
	assert(stock_alt["agua"] == 600.0)
	assert(stock_alt["vidrio"] == 300.0)
	assert(stock_alt["acero"] == 300.0)

	# 6. Integración con Ciudad.reiniciar() y GestorPartida.reiniciar_partida()
	Configuracion.establecer_valor_ajuste("ECONOMIA_RECURSOS_INICIALES", "supervivencia")
	Configuracion.aplicar()
	GestorPartida.reiniciar_partida()
	assert(Ciudad.almacen["madera"].cantidad == 0.0, "Supervivencia debe iniciar madera en 0")
	assert(Ciudad.almacen["comida"].cantidad == Ajustes.CIUDAD_COMIDA_INICIAL)

	Configuracion.establecer_valor_ajuste("ECONOMIA_RECURSOS_INICIALES", "bajos")
	Configuracion.aplicar()
	GestorPartida.reiniciar_partida()
	assert(Ciudad.almacen["madera"].cantidad == 300.0, "Bajos debe iniciar madera en 300")
	assert(Ciudad.almacen["hierro"].cantidad == 0.0, "Bajos debe iniciar hierro en 0")

	Configuracion.establecer_valor_ajuste("ECONOMIA_RECURSOS_INICIALES", "altos")
	Configuracion.aplicar()
	Ciudad.reiniciar()
	assert(Ciudad.almacen["madera"].cantidad == 1000.0)
	assert(Ciudad.almacen["hierro"].cantidad == 600.0)
	assert(Ciudad.almacen["agua"].cantidad == 600.0)
	assert(Ciudad.almacen["vidrio"].cantidad == 300.0)
	assert(Ciudad.almacen["madera"].limite == Ciudad.LIMITE_BASE)

	# 7. Restaurar perfil por defecto a bajos
	Configuracion.establecer_valor_ajuste("ECONOMIA_RECURSOS_INICIALES", "bajos")
	Configuracion.aplicar()
	Ciudad.reiniciar()
	print("OK: Selector y perfiles de recursos iniciales por categorías verificado.")
