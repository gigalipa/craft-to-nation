extends Node

const Ajustes = preload("res://scripts/ajustes.gd")

## Suite de pruebas unitarias para Sonidos.gd
## Verifica la inicialización del singleton, los pools de reproductores,
## la carga de los 102 efectos de sonido, el director de música adaptativa y la tolerancia a fallos.

func _ready() -> void:
	ejecutar_pruebas()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	Sonidos.volumen_sfx_db = 0.0
	Sonidos.sfx_habilitado = true
	test_inicializacion()
	test_cargar_todos_los_sonidos()
	test_reproduccion_2d()
	test_reproduccion_3d()
	test_tolerancia_fallos()
	test_modulacion_volumen_y_pitch()
	test_assets_y_constantes_musica()
	test_clasificacion_y_catalogo_contextos()
	test_shuffle_bag_sin_repeticion_consecutiva()
	test_prioridad_maquina_estados_y_cooldown_batalla()
	test_histeresis_y_fin_de_pista()
	test_volumen_y_silencio_durante_crossfade()
	test_combate_continuo_no_reinicia_pista()
	test_tolerancia_contextos_invalidos_y_un_elemento()
	test_menu_limpia_estado_combate()
	test_integracion_combate_y_construccion()
	test_volumen_no_cero_y_process_mode_en_crossfade()
	test_desmutear_reanuda_musica_activa()
	test_fin_natural_pista_promueve_candidato_histeresis()
	test_reproducir_musica_juego_limpia_combate()
	test_tipos_industriales_reales_en_main()


func test_inicializacion() -> void:
	assert(Sonidos != null, "El singleton Sonidos debe estar registrado en el árbol.")
	assert(Sonidos._pool_2d.size() == Sonidos.TAMANO_POOL_2D, "El pool 2D debe tener tamaño 16.")
	assert(Sonidos._pool_3d.size() == Sonidos.TAMANO_POOL_3D, "El pool 3D debe tener tamaño 16.")
	assert(Sonidos.sfx_habilitado == true, "SFX debe estar habilitado por defecto.")
	print("OK: Inicialización del singleton y pools.")


func test_cargar_todos_los_sonidos() -> void:
	# Carga y valida que todos los sonidos del catálogo carguen un AudioStream válido
	var ruta_cat := "res://assets/sfx/sfx_catalog.json"
	assert(FileAccess.file_exists(ruta_cat), "El archivo sfx_catalog.json debe existir.")
	var arch := FileAccess.open(ruta_cat, FileAccess.READ)
	assert(arch != null, "Debe poder abrirse sfx_catalog.json.")
	var data = JSON.parse_string(arch.get_as_text())
	assert(data is Dictionary, "El catálogo debe ser un diccionario.")
	assert(data.size() == 102, "El catálogo debe tener exactamente 102 sonidos.")

	var cargados := 0
	for sfx_id in data:
		var stream := Sonidos.obtener_stream(sfx_id)
		assert(stream != null, "El sonido %s debe poder cargarse correctamente." % sfx_id)
		assert(stream.get_length() > 0.0, "La duración del sonido %s debe ser mayor a 0." % sfx_id)
		cargados += 1

	assert(cargados == 102, "Deben haberse cargado los 102 sonidos.")
	assert(Sonidos.cantidad_cargados() >= 102, "La caché interna debe contener al menos 102 streams.")
	print("OK: Validación de carga de los 102 archivos OGG.")


func test_reproduccion_2d() -> void:
	var p1 := Sonidos.reproducir("sfx_ui_boton_clic")
	assert(p1 != null, "reproducir() debe retornar una instancia de AudioStreamPlayer.")
	assert(p1.stream != null, "El player debe tener asignado el AudioStream.")
	assert(p1.volume_db == 0.0, "El volumen debe coincidir con el default.")

	# Reproducción con variación de pitch y volumen
	var p2 := Sonidos.reproducir("sfx_avatar_salto", -3.0, 0.05)
	assert(p2 != null, "reproducir() con parámetros debe ser válido.")
	assert(p2.volume_db == -3.0, "El volumen debe reflejar el offset.")
	assert(abs(p2.pitch_scale - 1.0) <= 0.06, "El pitch debe estar dentro de la tolerancia.")
	print("OK: Reproducción 2D y asignación de stream.")


func test_reproduccion_3d() -> void:
	var pos := Vector3(10.0, 5.0, -12.0)
	var p3d := Sonidos.reproducir_3d("sfx_puerta_abrir", pos, 1.5, 0.0, 40.0)
	assert(p3d != null, "reproducir_3d() debe retornar AudioStreamPlayer3D.")
	assert(p3d.global_position == pos, "La posición del player 3D debe coincidir con el argumento.")
	assert(p3d.max_distance == 40.0, "La distancia máxima debe coincidir.")
	assert(p3d.volume_db == 1.5, "El volumen debe coincidir.")
	print("OK: Reproducción 3D espacial.")


func test_tolerancia_fallos() -> void:
	var invalido := Sonidos.reproducir("sfx_inexistente_totalmente_inventado")
	assert(invalido == null, "Un ID inexistente debe retornar null sin causar error de ejecución.")

	var invalido_3d := Sonidos.reproducir_3d("sfx_inexistente_3d", Vector3.ZERO)
	assert(invalido_3d == null, "Un ID inexistente en 3D debe retornar null sin causar error.")
	print("OK: Tolerancia a fallos con IDs desconocidos.")


func test_modulacion_volumen_y_pitch() -> void:
	Sonidos.volumen_sfx_db = -6.0
	var p := Sonidos.reproducir("sfx_ui_hover", -2.0)
	assert(p != null, "Player debe ser válido.")
	assert(p.volume_db == -8.0, "El volumen final debe sumar el global y el offset (-6 + -2 = -8).")
	Sonidos.volumen_sfx_db = 0.0
	print("OK: Modulación de volumen.")


func test_deshabilitar_sfx() -> void:
	Sonidos.sfx_habilitado = false
	var p := Sonidos.reproducir("sfx_ui_boton_clic")
	assert(p == null, "Con sfx deshabilitado, reproducir debe retornar null.")
	Sonidos.sfx_habilitado = true
	print("OK: Deshabilitación y silencio global.")


func test_assets_y_constantes_musica() -> void:
	assert(is_equal_approx(Ajustes.MUSICA_CROSSFADE_AMBIENTAL_S, 3.0), "MUSICA_CROSSFADE_AMBIENTAL_S debe ser 3.0")
	assert(is_equal_approx(Ajustes.MUSICA_CROSSFADE_BATALLA_S, 0.8), "MUSICA_CROSSFADE_BATALLA_S debe ser 0.8")
	assert(is_equal_approx(Ajustes.MUSICA_HISTERESIS_AMBIENTAL_S, 4.0), "MUSICA_HISTERESIS_AMBIENTAL_S debe ser 4.0")
	assert(is_equal_approx(Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S, 15.0), "MUSICA_PERMANENCIA_MINIMA_PISTA_S debe ser 15.0")
	assert(is_equal_approx(Ajustes.MUSICA_COOLDOWN_BATALLA_S, 15.0), "MUSICA_COOLDOWN_BATALLA_S debe ser 15.0")
	assert(is_equal_approx(Ajustes.MUSICA_RADIO_DETECCION_INDUSTRIA, 12.0), "MUSICA_RADIO_DETECCION_INDUSTRIA debe ser 12.0")
	assert(is_equal_approx(Ajustes.MUSICA_INTERVALO_EVALUACION_S, 1.0), "MUSICA_INTERVALO_EVALUACION_S debe ser 1.0")

	var pistas_esperadas: Array[String] = [
		"Menu & Loading Theme (menu).mp3",
		"Untamed Horizons (exploration).mp3",
		"Wilderness & Discovery (exploration).mp3",
		"Cozy_colony (building).mp3",
		"Foundations & Frameworks (building).mp3",
		"Frontier Blueprint (building).mp3",
		"Seamless_loop  (building).mp3",
		"Automated Pulse (industry).mp3",
		"Clockwork_logistics (industry).mp3",
		"Clockwork_logistics_2 (industry).mp3",
		"Glitch_drift (industry).mp3",
		"Glitch_drift_2 (industry).mp3",
		"Morning_at_the_Steel_Spire (industry).mp3",
		"Hard_stop (battle).mp3",
		"Hard_stop_2 (battle).mp3",
		"Siege Protocols (battle).mp3",
	]
	for nombre in pistas_esperadas:
		var ruta := "res://assets/musica/" + nombre
		assert(FileAccess.file_exists(ruta), "Debe existir la pista OST: %s" % ruta)
		var stream := Sonidos.cargar_stream_musica(ruta, false)
		assert(stream != null and stream.get_length() > 0.0, "La pista OST debe cargar con duración > 0: %s" % ruta)
	assert(not FileAccess.file_exists("res://assets/musica/Cozy_colony (loop).mp3"), "No deben quedar duplicados (loop).mp3 antiguos.")
	assert(not FileAccess.file_exists("res://assets/musica/The_Architect_s_Decree (menu).mp3"), "The_Architect_s_Decree (menu).mp3 debe haber sido eliminada.")
	print("OK: 16 pistas OST y 7 constantes en Ajustes verificadas.")


func test_clasificacion_y_catalogo_contextos() -> void:
	assert(Sonidos.extraer_contexto_musical("Menu & Loading Theme (menu).mp3") == "menu")
	assert(Sonidos.extraer_contexto_musical("Untamed Horizons (exploration).mp3") == "exploration")
	assert(Sonidos.extraer_contexto_musical("Seamless_loop  (building).mp3") == "building")
	assert(Sonidos.extraer_contexto_musical("Automated Pulse (industry).mp3") == "industry")
	assert(Sonidos.extraer_contexto_musical("Siege Protocols (battle).mp3") == "battle")
	assert(Sonidos.extraer_contexto_musical("archivo_sin_etiqueta.mp3") == "")
	assert(Sonidos.extraer_contexto_musical("tema_raro (desconocido).mp3") == "")

	assert(Sonidos.obtener_pistas_contexto("menu").size() == 1, "menu debe tener 1 pista (Menu & Loading Theme)")
	assert(Sonidos.obtener_pistas_contexto("exploration").size() == 2, "exploration debe tener 2 pistas")
	assert(Sonidos.obtener_pistas_contexto("building").size() == 4, "building debe tener 4 pistas")
	assert(Sonidos.obtener_pistas_contexto("industry").size() == 6, "industry debe tener 6 pistas")
	assert(Sonidos.obtener_pistas_contexto("battle").size() == 3, "battle debe tener 3 pistas")
	print("OK: Clasificación y catálogo por los 5 contextos verificados.")


func test_shuffle_bag_sin_repeticion_consecutiva() -> void:
	Sonidos.reiniciar_director_musica()
	for ctx in ["exploration", "building", "industry", "battle"]:
		var previa := ""
		for i in range(10):
			var pista := Sonidos.obtener_siguiente_pista_contexto(ctx)
			assert(pista != "", "Debe entregar una pista válida para %s" % ctx)
			assert(pista != previa, "Shuffle bag no debe repetir consecutivamente en %s (iter %d: %s)" % [ctx, i, pista])
			previa = pista
	print("OK: Shuffle bag sin repetición consecutiva verificado.")


func test_prioridad_maquina_estados_y_cooldown_batalla() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)

	var c1 := Sonidos.evaluar_contexto_musical({
		"tiene_nucleo": false,
		"en_influencia": false,
		"modo_construccion_activo": false,
		"construccion_reciente": false,
		"en_industria": false,
		"panel_industria_abierto": false,
		"en_combate": false,
	}, 1.0)
	assert(c1 == "exploration", "Sin núcleo ni influencia debe ser exploration, obtuvo: %s" % c1)

	Sonidos._tiempo_en_pista_actual_s = Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true}, 2.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "exploration", "2.0s no debe bastar para vencer histéresis de 4.0s")
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true}, 2.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "4.5s continuos debe transicionar a building")

	Sonidos._tiempo_en_pista_actual_s = Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": true}, 4.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "industry", "industry debe prevalecer sobre building")

	Sonidos._tiempo_en_pista_actual_s = 0.0
	Sonidos.notificar_evento_combate()
	assert(Sonidos.obtener_contexto_musica_actual() == "battle", "notificar_evento_combate debe activar battle inmediatamente")

	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 10.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "battle", "Debe mantenerse en battle durante el cooldown")

	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 6.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Al expirar cooldown de batalla debe regresar a building")
	Sonidos.detener_musica()
	print("OK: Prioridad de máquina de estados y cooldown de batalla verificados.")


func test_histeresis_y_fin_de_pista() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos._tiempo_en_pista_actual_s = Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S

	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": true}, 2.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "No debe cambiar tras solo 2.0 s")
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 1.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Al volver a building el candidato industry se reinicia")

	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": true}, 4.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "industry", "4.5 s continuos con permanencia cumplida debe pasar a industry")

	Sonidos._tiempo_en_pista_actual_s = 1.0
	Sonidos._player_musica.stop()
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 4.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Si la pista ya terminó, la histéresis de 4.5s permite cambiar sin esperar 15s")
	Sonidos.detener_musica()
	print("OK: Histéresis anti-rebote y fin de pista verificados.")


func test_volumen_y_silencio_durante_crossfade() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos.establecer_contexto_musica("industry", false)
	Sonidos.actualizar_volumen_musica(0.0)
	assert(not Sonidos.musica_habilitada, "La música debe quedar deshabilitada")
	assert(Sonidos._player_musica.volume_db <= -79.0, "El reproductor activo debe silenciarse de inmediato")
	assert(Sonidos._player_musica_secundario.volume_db <= -79.0, "El reproductor saliente debe silenciarse de inmediato")
	Sonidos.actualizar_volumen_musica(0.75)
	Sonidos.detener_musica()
	print("OK: Silencio y volumen durante crossfade verificados.")


func test_combate_continuo_no_reinicia_pista() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.notificar_evento_combate()
	var stream_inicial := Sonidos._player_musica.stream
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true}, 5.0)
	Sonidos.notificar_evento_combate()
	assert(Sonidos._player_musica.stream == stream_inicial, "Re-notificar combate en battle no debe reiniciar ni cambiar la pista actual")
	assert(is_equal_approx(Sonidos._cooldown_batalla_restante_s, Ajustes.MUSICA_COOLDOWN_BATALLA_S), "El cooldown debe reiniciarse a 15s")
	Sonidos.detener_musica()
	print("OK: Re-notificación de combate mantiene pista actual y reinicia cooldown.")


func test_tolerancia_contextos_invalidos_y_un_elemento() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos.establecer_contexto_musica("contexto_inexistente", true)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Contexto inválido debe ignorarse sin alterar el estado actual")

	var respaldo: Array[String] = Sonidos._pistas_por_contexto["menu"].duplicate()
	Sonidos._pistas_por_contexto["menu"] = [respaldo[0]]
	Sonidos._colas_contexto["menu"] = []
	var p1 := Sonidos.obtener_siguiente_pista_contexto("menu")
	var p2 := Sonidos.obtener_siguiente_pista_contexto("menu")
	assert(p1 == respaldo[0] and p2 == respaldo[0], "Contexto de 1 pista debe devolver esa pista sin bloquearse")
	Sonidos._pistas_por_contexto["menu"] = respaldo
	Sonidos._colas_contexto["menu"] = []
	Sonidos.detener_musica()
	print("OK: Tolerancia a contextos inválidos y pool de 1 pista verificada.")


func test_menu_limpia_estado_combate() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.notificar_evento_combate()
	assert(Sonidos.obtener_contexto_musica_actual() == "battle")
	Sonidos.reproducir_musica_menu()
	assert(Sonidos.obtener_contexto_musica_actual() == "menu", "reproducir_musica_menu debe pasar inmediatamente a menu")
	assert(Sonidos._cooldown_batalla_restante_s <= 0.0, "Volver al menú debe limpiar cooldown de batalla")
	Sonidos.detener_musica()
	print("OK: Transición a menú limpia estado de combate.")


func test_integracion_combate_y_construccion() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)

	var id_u: int = Colonos.agregar_colono("obrero", Vector3i(2, 1, 2), -1)
	Colonos.aplicar_dano_unidad(id_u, 10.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "battle", "Colonos.aplicar_dano_unidad debe disparar contexto battle")

	var cel: Vector3i = Colonos.colonos[id_u]["celda"]
	Colonos.ocupadas.erase(cel)
	Colonos.colonos.erase(id_u)

	var player_script = preload("res://scripts/Player.gd")
	var p = player_script.new()
	assert(not p.construccion_reciente_activa(10.0), "Sin actividad reciente debe devolver false")
	p.registrar_actividad_construccion()
	assert(p.construccion_reciente_activa(10.0), "Tras registrar actividad de construcción debe devolver true")
	p.free()

	Sonidos.detener_musica()
	print("OK: Integración de combate (Colonos) y construcción reciente (Player) verificada.")


func test_volumen_no_cero_y_process_mode_en_crossfade() -> void:
	assert(Sonidos.process_mode == Node.PROCESS_MODE_ALWAYS, "Sonidos debe usar PROCESS_MODE_ALWAYS para no congelar tweens en pausa")
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos.establecer_contexto_musica("industry", false)
	Sonidos.actualizar_volumen_musica(0.25)
	assert(Sonidos._tween_musica == null, "Cambiar volumen > 0 en medio de un crossfade debe cancelar el tween antiguo")
	assert(is_equal_approx(Sonidos._player_musica.volume_db, linear_to_db(0.25)), "El canal activo debe adoptar el nuevo volumen de inmediato")
	assert(not Sonidos._player_musica_secundario.playing, "El canal saliente debe detenerse al cancelar crossfade por cambio de volumen")
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.detener_musica()
	print("OK: Volumen no-cero durante crossfade y PROCESS_MODE_ALWAYS verificados.")


func test_desmutear_reanuda_musica_activa() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.0)
	Sonidos.reproducir_musica_menu()
	assert(Sonidos.obtener_contexto_musica_actual() == "menu")
	assert(not Sonidos._player_musica.playing, "En silencio no debe reproducir")
	Sonidos.actualizar_volumen_musica(0.75)
	assert(Sonidos._player_musica.playing and Sonidos._player_musica.stream != null, "Al desmutear debe reanudar el contexto activo")
	Sonidos.detener_musica()
	print("OK: Desmutear reanuda el contexto musical activo.")


func test_fin_natural_pista_promueve_candidato_histeresis() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos._tiempo_en_pista_actual_s = 2.0
	# Acumular 4.5s de candidato industry sin cumplir aún los 15s de permanencia
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": true}, 4.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Aún no cumple 15s de permanencia")
	# La pista termina naturalmente -> debe promover al candidato en histéresis inmediatamente
	Sonidos._on_player_musica_terminado(Sonidos._player_musica)
	assert(Sonidos.obtener_contexto_musica_actual() == "industry", "Al terminar la pista naturalmente debe promover el candidato que ya cumplió histéresis")
	Sonidos.detener_musica()
	print("OK: Fin natural de pista promueve candidato en histéresis.")


func test_reproducir_musica_juego_limpia_combate() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.notificar_evento_combate()
	assert(Sonidos.obtener_contexto_musica_actual() == "battle")
	Sonidos.reproducir_musica_juego()
	assert(Sonidos._cooldown_batalla_restante_s <= 0.0, "reproducir_musica_juego debe limpiar el cooldown de batalla previo")
	assert(Sonidos.obtener_contexto_musica_actual() != "battle", "reproducir_musica_juego no debe heredar estado battle")
	Sonidos.detener_musica()
	print("OK: reproducir_musica_juego limpia estado de combate.")


func test_tipos_industriales_reales_en_main() -> void:
	var main_script = preload("res://scripts/Main.gd")
	for tipo_real in ["vidriera", "estacion_bombeo", "centro_extraccion", "taller_transporte", "mina", "siderurgica", "central_termoelectrica"]:
		assert(main_script.TIPOS_PUESTOS_INDUSTRIALES.has(tipo_real), "Main.TIPOS_PUESTOS_INDUSTRIALES debe incluir el edificio real: %s" % tipo_real)
	print("OK: Tipos industriales reales en Main.gd verificados.")
