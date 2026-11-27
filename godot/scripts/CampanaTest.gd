extends Node

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")
const CampanaCatalogo = preload("res://scripts/CampanaCatalogo.gd")
const MenuInicioScript = preload("res://scripts/MenuInicio.gd")
const SecuenciaScript = preload("res://scripts/SecuenciaVideoCampana.gd")


func _ready() -> void:
	_test_semilla_campana()
	_test_menu_inicio_boton_campana()
	_test_progresion_completa_y_tolerancia()
	_test_persistencia_voz_y_epilogo()
	_test_hitos_bbcode_excepciones_y_sucesion()
	Campana.desactivar()
	Strings.actualizar_idioma("es")
	print("CampanaTest: todas las pruebas pasaron")
	get_tree().quit(0)


func _test_semilla_campana() -> void:
	var gen := GeneradorMundo.new(Ajustes.SEMILLA_CAMPANA, Ajustes.ANCHO_MUNDO, Ajustes.LARGO_MUNDO)
	var cx: int = Ajustes.ANCHO_MUNDO / 2
	var cz: int = Ajustes.LARGO_MUNDO / 2
	assert(not gen.es_agua_en(cx, cz) and not gen.es_rio_en(cx, cz), "Spawn de campana debe ser tierra firme")

	var arboles := 0
	var agua := 0
	var mineral := 0
	for dx in range(-35, 36):
		for dz in range(-35, 36):
			var x := cx + dx
			var z := cz + dz
			var h: int = gen.altura_en(x, z)
			if gen.densidad_arbol_en(x, z) > Ajustes.UMBRAL_ARBOL and not gen.es_agua_en(x, z) and not gen.es_rio_en(x, z):
				arboles += 1
			if gen.es_agua_en(x, z) or gen.es_rio_en(x, z):
				agua += 1
			if dx % 4 == 0 and dz % 4 == 0:
				for prof in range(4, 15, 2):
					var t := gen.tipo_en_profundidad(x, h - prof, z, prof)
					if t == "carbon" or t == "hierro":
						mineral += 1
						break
	assert(arboles >= 10, "Semilla de campana debe tener bosque cercano")
	assert(agua >= 5, "Semilla de campana debe tener agua cercana")
	assert(mineral >= 5, "Semilla de campana debe tener minerales accesibles")


func _test_menu_inicio_boton_campana() -> void:
	var menu := MenuInicioScript.new()
	add_child(menu)
	menu._mostrar_subpanel(menu._panel_nueva_partida)
	assert(menu._btn_campana != null and menu._btn_campana.visible, "Debe existir boton Campana en Nueva Partida")
	assert(menu._btn_campana.icon != null, "Boton Campana debe tener icono")
	Strings.actualizar_idioma("en")
	menu._actualizar_textos_idioma()
	assert(menu._btn_campana.text == "Campaign / Tutorial", "Boton Campana debe traducirse a ingles")
	Strings.actualizar_idioma("es")
	menu._actualizar_textos_idioma()
	assert(menu._btn_campana.text == "Campaña / Tutorial", "Boton Campana debe volver a espanol")
	menu.queue_free()


func _test_progresion_completa_y_tolerancia() -> void:
	Campana.iniciar_nueva_campana()
	assert(Campana.fase == Campana.Fase.PROLOGO)
	assert(Ajustes.SEMILLA == Ajustes.SEMILLA_CAMPANA)

	Campana.comenzar_actos_en_mundo({"madera": 0.0, "piedra": 0.0, "tierra": 0.0, "comida": 0.0, "tablas": 0.0})
	assert(Campana.esta_activa())
	assert(Campana.obtener_paso_actual()["id"] == "A1_01")

	var epilogo_disparado := {"ok": false}
	Campana.epilogo_solicitado.connect(func(): epilogo_disparado["ok"] = true)

	var ctx := {
		"id_nucleo": -1,
		"cenital_activa": false,
		"tiene_zona_a": false,
		"tiene_zona_b": false,
		"total_colonos": 0,
		"bloques_estructurales_colocados": 0,
		"tiene_puerta": false,
		"tiene_ventana": false,
		"tiene_cama": false,
		"tiene_baul": false,
		"apuntando_puerta_modo_t": false,
		"tiene_obra_residencial_extra": false,
		"tiene_residencial_completado": false,
		"tiene_obra_puesto_comida": false,
		"tiene_puesto_comida": false,
		"comida_tiene_recolector": false,
		"comida_tiene_acarreador": false,
		"puesto_comida_con_personal": false,
		"tiene_obra_puesto_material": false,
		"tiene_puesto_material": false,
		"material_tiene_recolector": false,
		"material_tiene_acarreador": false,
		"tiene_puesto_material_con_personal": false,
		"total_celdas_via": 0,
		"tiene_escuela_tecnica": false,
		"total_tecnicos": 0,
		"tiene_aserradero": false,
		"aserradero_con_personal": false,
		"aserradero_produciendo": false,
		"lampara_encendida": false,
		"escaner_extractor_activo": false,
		"consulto_almacen": false,
		"stocks": {"madera": 0.0},
	}

	# A1_01 -> A1_02 (no debe avanzar con hitos parciales)
	ctx["stocks"] = {"madera": 5.0}
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_01", "A1_01 no debe avanzar solo con madera")
	ctx["stocks"] = {"madera": 5.0, "piedra": 3.0, "comida": 2.0}
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_01", "A1_01 no debe avanzar sin abrir el almacen [Z]")
	ctx["consulto_almacen"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_02")

	# A1_02 -> A1_03 -> A1_04 -> A2_01 (no debe avanzar solo con bloques + cama)
	ctx["bloques_estructurales_colocados"] = 14
	ctx["tiene_cama"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_02", "A1_02 no debe avanzar sin puerta, ventana ni baul")
	ctx["tiene_puerta"] = true
	ctx["tiene_ventana"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_02", "A1_02 no debe avanzar sin baul")
	ctx["tiene_baul"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_03")
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_03")
	ctx["apuntando_puerta_modo_t"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_03", "A1_03 no debe avanzar sin declarar el Nucleo")
	assert(Campana.ultimos_hitos_cumplidos[0] == true, "A1_03 hito 1 debe quedar marcado")
	ctx["apuntando_puerta_modo_t"] = false
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.ultimos_hitos_cumplidos[0] == true, "A1_03 hito 1 no debe desmarcarse al dejar de apuntar")
	ctx["id_nucleo"] = 1
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A1_04")
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A2_01")

	# A2_01 -> A2_04 -> A3_01
	ctx["cenital_activa"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A2_02")
	ctx["tiene_zona_a"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A2_03")
	ctx["tiene_residencial_completado"] = true
	ctx["total_colonos"] = 1
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A2_04")
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A3_01")

	# A3_01 -> A3_05 -> A4_01
	ctx["tiene_puesto_comida"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A3_02")
	ctx["comida_tiene_recolector"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A3_02", "A3_02 no debe avanzar sin acarreador")
	ctx["comida_tiene_acarreador"] = true
	ctx["puesto_comida_con_personal"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A3_03")
	ctx["tiene_puesto_material"] = true
	ctx["material_tiene_recolector"] = true
	ctx["material_tiene_acarreador"] = true
	ctx["tiene_puesto_material_con_personal"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A3_04")
	ctx["total_celdas_via"] = 4
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A3_05")
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A4_01")

	# A4_01 -> A4_05 -> espera epilogo -> epilogo_solicitado
	ctx["lampara_encendida"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A4_02")
	ctx["tiene_zona_b"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A4_03")
	ctx["tiene_escuela_tecnica"] = true
	ctx["total_tecnicos"] = 1
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A4_04")
	ctx["tiene_aserradero"] = true
	ctx["aserradero_con_personal"] = true
	ctx["aserradero_produciendo"] = true
	Campana.evaluar_progreso(ctx, 0.5, true)
	assert(Campana.obtener_paso_actual()["id"] == "A4_05")
	assert(Campana.fase == Campana.Fase.ESPERANDO_EPILOGO)

	Campana.evaluar_progreso(ctx, Ajustes.CAMPANA_RETRASO_EPILOGO_S + 0.1, true)
	assert(epilogo_disparado["ok"], "Debe emitir epilogo_solicitado tras el retraso")
	assert(Campana.fase == Campana.Fase.EPILOGO)

	Campana.pasar_a_modo_libre()
	assert(not Campana.esta_activa())
	assert(Campana.fase == Campana.Fase.MODO_LIBRE)


func _test_persistencia_voz_y_epilogo() -> void:
	Campana.iniciar_nueva_campana()
	Campana.comenzar_actos_en_mundo({"madera": 0.0})
	Campana.indice_paso = CampanaCatalogo.indice_de_paso("A3_03")
	var est := Campana.exportar_estado()
	Campana.desactivar()
	Campana.importar_estado(est)
	assert(Campana.esta_activa())
	assert(Campana.obtener_paso_actual()["id"] == "A3_03")

	# Canal de voz: todas las 18 locuciones deben cargar con duracion valida
	for p in CampanaCatalogo.PASOS:
		var id_linea: String = str(p["id"])
		var stream_v: AudioStream = Sonidos.obtener_stream_voz(id_linea)
		assert(stream_v != null, "Debe cargar locucion de campana %s" % id_linea)
		assert(stream_v.get_length() > 5.0, "Locucion %s debe tener duracion valida (>5s)" % id_linea)
	var player_v := Sonidos.reproducir_voz("A1_01")
	assert(player_v != null, "Debe reproducir A1_01")
	Sonidos.detener_voz()

	# Cierre de acto A1_04 espera la duracion de la locucion antes de avanzar a A2_01
	Campana.iniciar_nueva_campana()
	Campana.comenzar_actos_en_mundo({"madera": 0.0})
	Campana.indice_paso = CampanaCatalogo.indice_de_paso("A1_04")
	Campana._activar_paso_actual()
	assert(Campana.duracion_voz_actual_s > 5.0, "A1_04 debe registrar duracion real de voz")
	Campana.evaluar_progreso({"id_nucleo": 1}, 3.0, false)
	assert(Campana.obtener_paso_actual()["id"] == "A1_04", "No debe cortar la locucion de A1_04 antes de tiempo")
	Campana.evaluar_progreso({"id_nucleo": 1}, Campana.duracion_voz_actual_s + 1.0, false)
	assert(Campana.obtener_paso_actual()["id"] == "A2_01", "Debe avanzar a A2_01 tras finalizar la locucion")
	Sonidos.detener_voz()

	# Overlay de Epilogo + Post-Epilogo y verificacion del video de prologo
	var sec := SecuenciaScript.new()
	sec.es_epilogo = true
	sec.auto_iniciar = false
	add_child(sec)
	assert(ResourceLoader.exists(Ajustes.CAMPANA_RUTA_VIDEO_PROLOGO), "El video de prologo campana_prologo.ogv debe estar importado")
	var stream_prologo := sec._cargar_stream_video(Ajustes.CAMPANA_RUTA_VIDEO_PROLOGO)
	assert(stream_prologo != null, "SecuenciaVideoCampana debe cargar campana_prologo.ogv como VideoStream")
	sec._on_saltar_o_finalizar()
	assert(sec._panel_post_epilogo.visible, "Al finalizar epilogo debe mostrar panel Post-Epilogo")
	sec.queue_free()


func _test_hitos_bbcode_excepciones_y_sucesion() -> void:
	var PanelCampanaScript: GDScript = preload("res://scripts/PanelCampanaHUD.gd")
	var HUDScript: GDScript = preload("res://scripts/HUD.gd")

	# 1. Formateo BBCode de teclas e iconos de raton/recursos
	var bb: String = PanelCampanaScript.formatear_bbcode_controles("Pulsa [B] y {click_izq} con {ico:madera}")
	assert(bb.contains("[img=12x16]res://assets/icons/click_izq.svg[/img]"), "Debe insertar icono de clic izquierdo")
	assert(bb.contains("madera.svg"), "Debe insertar icono de madera")
	assert(bb.contains("[b] B [/b]"), "Debe renderizar keycap de tecla B")

	# 2. PanelCampanaHUD tacha hitos completados con [s]...[/s]
	var panel: Node = PanelCampanaScript.new()
	add_child(panel)
	Campana.iniciar_nueva_campana()
	Campana.comenzar_actos_en_mundo({"madera": 0.0})
	Campana.evaluar_progreso({"gano_madera": true, "gano_piedra_o_tierra": false, "gano_comida": false}, 0.2, false)
	assert(panel._rtl_hitos.text.contains("[s]") and panel._rtl_hitos.text.contains("✔"), "Debe tachar el sub-hito completado")
	panel.queue_free()

	# 3. Almacen en 1a persona con alternar_ventana_almacen_1p()
	var hud_test: CanvasLayer = HUDScript.new()
	add_child(hud_test)
	assert(not hud_test.ventana_almacen_abierta())
	assert(hud_test.alternar_ventana_almacen_1p())
	assert(hud_test.ventana_almacen_abierta())
	assert(not hud_test.alternar_ventana_almacen_1p())
	assert(not hud_test.ventana_almacen_abierta())
	hud_test.queue_free()

	# 4. Excepcion de campana: sin residencial extra no llegan colonos
	Ciudad.edificios_residenciales.clear()
	Ciudad.demografia["desempleado"] = 0
	Ciudad.sin_techo = 0
	Ciudad.migracion_activa = true
	Ciudad._migrantes_acumulados = 5.0
	Ciudad.moral = 90.0
	Ciudad.id_nucleo = 1
	assert(Ciudad._migrar(false) == 0, "En campana activa no deben llegar colonos antes del 1er residencial")

	# 5. Sucesion por genero en ciudad: sin colono del mismo genero -> -1 (Game Over)
	Colonos.reiniciar()
	Ciudad.genero_avatar = "F"
	Colonos.agregar_colono("desempleado", Vector3i(1, 1, 1), -1, {"genero": "M", "tono_piel": 2})
	assert(Colonos.elegir_colono_sucesion_ciudad("F") == -1, "Sin colono del mismo genero debe retornar -1 para Game Over")
	var id_f: int = Colonos.agregar_colono("obrero", Vector3i(2, 1, 1), -1, {"genero": "F", "tono_piel": 3})
	assert(Colonos.elegir_colono_sucesion_ciudad("F") == id_f, "Debe elegir al colono del mismo genero")
	Ciudad.demografia["obrero"] = 1
	var res_suc: Dictionary = Ciudad.completar_sucesion_desde_colono(id_f, Colonos)
	assert(bool(res_suc.get("exito", false)), "Sucesion desde colono debe completarse")
	assert(Ciudad.tono_piel_avatar == 3, "Avatar debe heredar tono de piel del sucesor")
	assert(not Colonos.colonos.has(id_f), "Colono sucesor debe retirarse de Colonos al asumir el Avatar")
	Colonos.reiniciar()

	# 6. Recursos iniciales de campana (2500 comida + supervivencia) y limpieza de Blueprints
	var perfil_prev: String = Ajustes.ECONOMIA_RECURSOS_INICIALES
	Ajustes.ECONOMIA_RECURSOS_INICIALES = "altos"
	Blueprints.guardar({"zona_permitida": "residencial_investigacion", "celdas": {Vector3i(0, 0, 0): "adobe"}})
	assert(Blueprints.cantidad_residenciales() >= 1, "Debe haber al menos un blueprint previo")
	Campana.iniciar_nueva_campana()
	GestorPartida.reiniciar_partida()
	assert(Blueprints.cantidad_residenciales() == 0, "Nueva campana debe limpiar Blueprints de partidas anteriores")
	assert(is_equal_approx(Ciudad.almacen["comida"].cantidad, 2500.0), "Campana debe iniciar con 2500 de alimento")
	assert(is_equal_approx(Ciudad.almacen["madera"].cantidad, 0.0), "Campana debe iniciar con recursos de supervivencia (madera=0)")
	assert(is_equal_approx(Ciudad.almacen["hierro"].cantidad, 0.0), "Campana debe iniciar con recursos de supervivencia (hierro=0)")
	Ajustes.ECONOMIA_RECURSOS_INICIALES = perfil_prev
	Campana.desactivar()
	GestorPartida.reiniciar_partida()
