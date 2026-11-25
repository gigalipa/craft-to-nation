extends Node

## Pruebas unitarias y de integración ligera de los modos de 1ª persona en
## Player.gd + Hotbar.gd + HUD.gd:
## T (Construcción), R (Batalla), F (Comandante), Clic Izquierdo vs Derecho,
## crosshair de combate y panel izquierdo de subgrupos mixtos (Shift + 1..9 / 0).

const PlayerScript = preload("res://scripts/Player.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")
const ColonosRendererScript = preload("res://scripts/ColonosRenderer.gd")


func _crear_escena_jugador() -> Dictionary:
	var raiz := Node3D.new()
	add_child(raiz)
	var hud: CanvasLayer = HUDScript.new()
	hud.name = "HUDLayer"
	raiz.add_child(hud)
	var player := PlayerScript.new()
	var cam := Camera3D.new()
	cam.name = "Camara"
	player.add_child(cam)
	var rc := RayCast3D.new()
	rc.name = "RayCast3D"
	cam.add_child(rc)
	raiz.add_child(player)
	player.camara.current = true
	hud.set_vista(true)
	return {"raiz": raiz, "hud": hud, "player": player}


func _tecla(codigo: int, con_shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.pressed = true
	ev.echo = false
	ev.shift_pressed = con_shift
	return ev


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	var ctx := _crear_escena_jugador()
	var hud: CanvasLayer = ctx["hud"]
	var player: Player = ctx["player"]
	var raiz: Node3D = ctx["raiz"]

	print("=== TEST 1: Transiciones T / R / F y salir_de_todas_las_herramientas() ===")
	assert(player.modo_primera_persona == "construccion", "inicia en modo construccion")
	assert(not hud.crosshair_combate().visible, "crosshair combate oculto en construccion")

	player._input(_tecla(KEY_R))
	assert(player.modo_primera_persona == "batalla", "R activa modo batalla")
	assert(hud.crosshair_combate().visible, "crosshair combate visible en batalla")
	assert(hud._hotbar._casillas.size() == Ajustes.ARMAS_AVATAR.size(), "hotbar muestra armas en batalla")

	player._input(_tecla(KEY_F))
	assert(player.modo_primera_persona == "comandante", "F activa modo comandante")
	assert(not hud.crosshair_combate().visible, "crosshair combate oculto en comandante")
	assert(hud._hotbar._casillas.size() == 6, "hotbar muestra 6 ordenes en comandante")

	player._input(_tecla(KEY_T))
	assert(player.modo_primera_persona == "construccion", "T restaura modo construccion")
	assert(hud._hotbar._casillas.size() == player.tipos_disponibles.size(), "hotbar restaurada a bloques")

	player._input(_tecla(KEY_R))
	player.salir_de_todas_las_herramientas()
	assert(player.modo_primera_persona == "construccion", "salir_de_todas_las_herramientas limpia modo batalla")
	assert(not hud.crosshair_combate().visible, "salir_de_todas_las_herramientas oculta crosshair combate")

	print("=== TEST 2: Combate cuerpo a cuerpo/distancia y cooldown ===")
	player._input(_tecla(KEY_R))
	var id_obj: int = Colonos.agregar_colono("obrero", Vector3i(4, 1, 4), -1)
	var salud_ini: float = Colonos.colonos[id_obj]["salud"]
	player._input(_tecla(KEY_1))  # espada (dano 35)
	assert(player.arma_seleccionada == 0)
	var hit1: bool = player.ejecutar_ataque_en_objetivo("unidad", id_obj, Vector3i(4, 1, 4))
	assert(hit1, "primer golpe con espada impacta")
	assert(is_equal_approx(Colonos.colonos[id_obj]["salud"], salud_ini - float(Ajustes.ARMAS_AVATAR[0]["dano"])), "espada aplica dano configurado")
	var hit_spam: bool = player.ejecutar_ataque_en_objetivo("unidad", id_obj, Vector3i(4, 1, 4))
	assert(not hit_spam, "cooldown bloquea ataque inmediato")
	player._cooldown_ataque_avatar = 0.0
	player._input(_tecla(KEY_2))  # arco (dano a distancia)
	assert(player.arma_seleccionada == 1)
	var hit2: bool = player.ejecutar_ataque_en_objetivo("unidad", id_obj, Vector3i(4, 1, 4))
	assert(hit2, "arco impacta tras enfriar cooldown")

	print("=== TEST 3: Matriz de 6 ordenes (Clic Izq vs Clic Der) en Modo Comandante ===")
	var id_m1: int = Colonos.agregar_colono("militar", Vector3i(5, 1, 5), -1)
	var id_m2: int = Colonos.agregar_colono("militar", Vector3i(6, 1, 5), -1)
	Colonos.colonos[id_m2]["rango"] = "cabo_explorador"
	Colonos.seleccionar_unidades([id_m1, id_m2])
	player._input(_tecla(KEY_F))

	# 1: Atacar (Izq = atacar objetivo, Der = postura agresivo)
	player._input(_tecla(KEY_1))
	player.ejecutar_orden_comandante(false, Vector3i(12, 1, 12), id_obj, -1)
	assert(Colonos.colonos[id_m1]["orden_militar"].get("tipo", "") == "atacar", "1 izq ordena atacar")
	player.ejecutar_orden_comandante(true, Vector3i(12, 1, 12))
	assert(Colonos.colonos[id_m1]["postura"] == "agresivo", "1 der cambia postura a agresivo")

	# 2: Defender (Izq = proteger objetivo/punto, Der = postura defensivo)
	player._input(_tecla(KEY_2))
	player.ejecutar_orden_comandante(false, Vector3i(8, 1, 8), -1, 33)
	assert(Colonos.colonos[id_m1]["orden_militar"].get("tipo", "") == "proteger", "2 izq ordena proteger")
	player.ejecutar_orden_comandante(true, Vector3i(8, 1, 8))
	assert(Colonos.colonos[id_m1]["postura"] == "defensivo", "2 der cambia postura a defensivo")

	# 3: Seguir (Izq = seguir unidad apuntada o avatar, Der = seguir avatar)
	player._input(_tecla(KEY_3))
	player.ejecutar_orden_comandante(false, Vector3i(4, 1, 4), id_obj, -1)
	assert(Colonos.colonos[id_m1]["orden_militar"].get("objetivo_tipo", "") == "unidad", "3 izq sigue unidad apuntada")
	player.ejecutar_orden_comandante(true, Vector3i(4, 1, 4), id_obj, -1)
	assert(Colonos.colonos[id_m1]["orden_militar"].get("objetivo_tipo", "") == "avatar", "3 der sigue al avatar")

	# 4: Moverse (Izq = todos, Der = solo 1 soldado)
	player._input(_tecla(KEY_4))
	player.ejecutar_orden_comandante(false, Vector3i(10, 1, 10))
	assert(Colonos.colonos[id_m1]["orden_militar"].get("tipo", "") == "mover" and Colonos.colonos[id_m2]["orden_militar"].get("tipo", "") == "mover", "4 izq mueve toda la tropa")
	var prev_d1: Vector3i = Colonos.colonos[id_m1]["orden_militar"].get("destino", Vector3i.ZERO)
	var prev_d2: Vector3i = Colonos.colonos[id_m2]["orden_militar"].get("destino", Vector3i.ZERO)
	player.ejecutar_orden_comandante(true, Vector3i(20, 1, 20))
	var d1_post: Vector3i = Colonos.colonos[id_m1]["orden_militar"].get("destino", Vector3i.ZERO)
	var d2_post: Vector3i = Colonos.colonos[id_m2]["orden_militar"].get("destino", Vector3i.ZERO)
	var movio_uno: bool = (d1_post == Vector3i(20, 1, 20) and d2_post == prev_d2) or (d2_post == Vector3i(20, 1, 20) and d1_post == prev_d1)
	assert(movio_uno, "4 der mueve solo 1 soldado y el otro mantiene su destino")

	# 5: Patrullar (Izq = anade waypoint, Der = reinicia ruta)
	player._input(_tecla(KEY_5))
	player.ejecutar_orden_comandante(false, Vector3i(11, 1, 11))
	player.ejecutar_orden_comandante(false, Vector3i(14, 1, 14))
	assert(Colonos.colonos[id_m1]["orden_militar"].get("waypoints", []).size() == 3, "5 izq acumula waypoints tras ruta inicial [origen, wp1, wp2]")
	player.ejecutar_orden_comandante(true, Vector3i(3, 1, 3))
	assert(Colonos.colonos[id_m1]["orden_militar"].get("waypoints", []).size() == 2 and Colonos.colonos[id_m1]["orden_militar"]["waypoints"][1] == Vector3i(3, 1, 3), "5 der reinicia ruta de patrulla")

	# 6: Mantener (Izq = mantener, Der = postura pasivo)
	player._input(_tecla(KEY_6))
	player.ejecutar_orden_comandante(false, Vector3i.ZERO)
	assert(Colonos.colonos[id_m1]["orden_militar"].get("tipo", "") == "mantener", "6 izq ordena mantener")
	player.ejecutar_orden_comandante(true, Vector3i.ZERO)
	assert(Colonos.colonos[id_m1]["postura"] == "pasivo", "6 der cambia postura a pasivo")

	print("=== TEST 4: Subgrupos mixtos en panel izquierdo y Shift + 1 / Shift + 0 ===")
	assert(hud.panel_grupos_tropas().visible, "panel de grupos visible en 1a persona con tropas seleccionadas")
	var grupos: Array[Dictionary] = Colonos.grupos_militares_seleccionados()
	assert(grupos.size() == 2, "tropa mixta tiene 2 subgrupos distintos")
	var rango_0: String = str(grupos[0]["rango"])
	player._input(_tecla(KEY_1, true))  # Shift+1
	assert(Colonos.subgrupo_activo == rango_0, "Shift+1 selecciona el primer subgrupo: %s" % Colonos.subgrupo_activo)
	# Orden afecta solo al subgrupo activo
	player._input(_tecla(KEY_4))
	player.ejecutar_orden_comandante(false, Vector3i(25, 1, 25))
	var otro_id: int = id_m2 if Colonos.colonos[id_m1]["rango"] == rango_0 else id_m1
	assert(Colonos.colonos[otro_id]["orden_militar"].get("tipo", "") != "mover", "orden con subgrupo activo no afecta al otro rango")
	player._input(_tecla(KEY_0, true))  # Shift+0 limpia filtro
	assert(Colonos.subgrupo_activo == "", "Shift+0 vuelve a seleccionar todos los subgrupos")

	print("=== TEST 5: Visuales procedurales de tropas y marcadores tacticos en ColonosRenderer ===")
	Colonos.seleccionar_unidades([id_m1])
	Colonos.ordenar_patrullar(Vector3i(9, 1, 9), true)
	var rend: Node3D = ColonosRendererScript.new()
	raiz.add_child(rend)
	rend._physics_process(0.016)
	var cuerpo_m: AnimatableBody3D = rend._cuerpos.get(id_m1, null)
	var cuerpo_c: AnimatableBody3D = rend._cuerpos.get(id_obj, null)
	assert(cuerpo_m != null and cuerpo_c != null, "renderer instancia cuerpos militar y civil")
	assert(cuerpo_m.get_node_or_null("CascoMilitar") != null and cuerpo_m.get_node_or_null("CascoMilitar").visible, "militar tiene casco visible")
	assert(cuerpo_m.get_node_or_null("EscudoMilitar") != null and cuerpo_m.get_node_or_null("EscudoMilitar").visible, "militar tiene escudo visible")
	assert(cuerpo_c.get_node_or_null("CascoMilitar") == null or not cuerpo_c.get_node_or_null("CascoMilitar").visible, "civil no muestra casco militar")
	assert(cuerpo_m.get_node_or_null("AroSeleccion").visible and not cuerpo_c.get_node_or_null("AroSeleccion").visible, "aro visible solo en unidad seleccionada")
	assert(rend._marcadores_ordenes.get_child_count() >= 2, "marcadores tacticos de patrulla visibles para tropa seleccionada")

	Colonos.limpiar_seleccion()
	rend._physics_process(0.016)
	assert(not cuerpo_m.get_node_or_null("AroSeleccion").visible, "aro se oculta al deseleccionar")
	assert(not hud.panel_grupos_tropas().visible, "panel de grupos se oculta sin seleccion militar")

	print("=== TEST 6: Armas iniciales (espada/arco), iconos 64px, alineacion hotbar y PanelContextual ===")
	assert(Ajustes.ARMAS_AVATAR.size() == 2, "solo 2 armas iniciales")
	assert(Ajustes.ARMAS_AVATAR[0]["id"] == "espada" and Ajustes.ARMAS_AVATAR[1]["id"] == "arco", "armas iniciales son espada y arco")
	var tex_soldado: Texture2D = IconosHUD.icono("militar")
	var tex_cuartel: Texture2D = IconosHUD.icono("cuartel")
	assert(tex_soldado != null and tex_cuartel == tex_soldado, "soldado y cuartel conservan icono militar.svg")
	for clave_nueva in ["cat_militar", "espada", "arco", "orden_atacar", "orden_defender", "orden_seguir", "orden_moverse", "orden_patrullar", "orden_mantener"]:
		var tex: Texture2D = IconosHUD.icono(clave_nueva)
		assert(tex != null, "icono nuevo %s carga" % clave_nueva)
		assert(tex != tex_soldado, "icono nuevo %s no reutiliza militar.svg" % clave_nueva)
		assert(tex.get_width() >= 64 and tex.get_height() >= 64, "icono %s tiene alta definicion >= 64x64" % clave_nueva)
	assert(IconosHUD.icono("orden_patrullar") != IconosHUD.icono("orden_moverse"), "patrullar y moverse tienen iconos distintos")

	# Tarjeta informativa en Batalla (Espada y Arco)
	player._input(_tecla(KEY_R))
	assert(hud._contexto.visible, "PanelContextual visible al entrar en modo batalla")
	assert(not hud._contexto.descripcion.text.is_empty(), "tarjeta batalla muestra descripcion")
	assert(hud._contexto.acciones.visible and hud._contexto.acciones.text.contains("[img="), "tarjeta batalla muestra accion de clic con icono")
	player._input(_tecla(KEY_1))
	assert(hud._contexto.icono.texture == IconosHUD.icono("espada"), "pulsar 1 actualiza tarjeta batalla a espada")
	player._input(_tecla(KEY_2))
	assert(hud._contexto.icono.texture == IconosHUD.icono("arco"), "pulsar 2 actualiza tarjeta a arco")

	# Tarjeta informativa y alineacion uniforme en Comandante
	player._input(_tecla(KEY_F))
	assert(hud._contexto.visible, "PanelContextual visible al entrar en modo comandante")
	assert(hud._contexto.acciones.visible and hud._contexto.acciones.text.count("[img=") == 2, "tarjeta comandante muestra iconos clic izq y der")
	var alto_ref: float = -1.0
	for c in hud._hotbar._casillas:
		var lbl: Label = c["nombre"]
		assert(lbl.autowrap_mode == TextServer.AUTOWRAP_OFF, "etiqueta comandante no hace wrap")
		assert(not lbl.text.contains(" ") and not lbl.text.contains("\n"), "titulo comandante corto en 1 palabra: %s" % lbl.text)
		var alto_cont: float = c["contenedor"].get_combined_minimum_size().y
		if alto_ref < 0.0:
			alto_ref = alto_cont
		else:
			assert(is_equal_approx(alto_cont, alto_ref), "todas las casillas comandante tienen misma altura (%f vs %f)" % [alto_cont, alto_ref])
	player._input(_tecla(KEY_1))
	assert(hud._contexto.icono.texture == IconosHUD.icono("orden_atacar"), "pulsar 1 en comandante actualiza tarjeta a atacar")
	player._input(_tecla(KEY_2))
	assert(hud._contexto.icono.texture == IconosHUD.icono("orden_defender"), "pulsar 2 en comandante actualiza tarjeta a defender")
	player._input(_tecla(KEY_6))
	assert(hud._contexto.icono.texture == IconosHUD.icono("orden_mantener"), "pulsar 6 en comandante actualiza tarjeta a mantener")

	print("=== TEST 7: Rueda del ratón cicla la hotbar en Construcción, Batalla y Comandante ===")
	var rueda_abajo := InputEventMouseButton.new()
	rueda_abajo.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rueda_abajo.pressed = true
	var rueda_arriba := InputEventMouseButton.new()
	rueda_arriba.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda_arriba.pressed = true

	# En Comandante: estaba en índice 5 (Mantener) -> rueda abajo envuelve a 0 (Atacar), rueda arriba vuelve a 5
	player._input(rueda_abajo)
	assert(player.orden_comandante_seleccionada == 0, "rueda abajo en último slot de comandante envuelve a 0")
	assert(hud._contexto.icono.texture == IconosHUD.icono("orden_atacar"), "rueda actualiza tarjeta contextual en comandante")
	player._input(rueda_arriba)
	assert(player.orden_comandante_seleccionada == 5, "rueda arriba en slot 0 de comandante envuelve al último slot")

	# En Batalla: ciclar entre Espada (0) y Arco (1)
	player._input(_tecla(KEY_R))
	player._input(_tecla(KEY_1))
	player._input(rueda_abajo)
	assert(player.arma_seleccionada == 1, "rueda abajo en batalla cambia de espada a arco")
	assert(hud._contexto.icono.texture == IconosHUD.icono("arco"), "rueda actualiza tarjeta contextual en batalla")
	player._input(rueda_abajo)
	assert(player.arma_seleccionada == 0, "rueda abajo envuelve de arco a espada")

	# En Construcción: ciclar entre bloques con wrap-around
	player._input(_tecla(KEY_T))
	player._input(_tecla(KEY_1))
	player._input(rueda_arriba)
	assert(player.tipo_seleccionado == player.tipos_disponibles.size() - 1, "rueda arriba desde slot 0 en construcción envuelve al último bloque")
	player._input(rueda_abajo)
	assert(player.tipo_seleccionado == 0, "rueda abajo desde último bloque en construcción envuelve a 0")

	print("=== TEST 8: Bloqueo de transición a cámara cenital (caída, daño 5s y agua) ===")
	player.velocity = Vector3(0.0, -2.5, 0.0)
	assert(player.esta_cayendo(), "velocidad vertical negativa fuera del suelo detecta caída")
	assert(player.motivo_bloqueo_cenital() != "", "caída bloquea paso a vista cenital")
	player.velocity = Vector3.ZERO
	assert(not player.esta_cayendo(), "velocidad cero no está cayendo")
	assert(player.motivo_bloqueo_cenital() == "", "sin caída ni daño ni nado permite vista cenital")

	player.recibir_dano(15.0)
	assert(player.en_cooldown_dano_cenital(), "recibir daño activa cooldown de bloqueo cenital")
	assert(player.motivo_bloqueo_cenital() != "", "daño reciente bloquea vista cenital")
	player._physics_process(3.0)
	assert(player.en_cooldown_dano_cenital(), "tras 3.0s sigue activo el cooldown de 5s")
	assert(is_equal_approx(player._cooldown_dano_cenital_s, 2.0), "cooldown restante tras 3.0s debe ser 2.0s")
	player.recibir_dano(5.0)
	assert(is_equal_approx(player._cooldown_dano_cenital_s, Ajustes.PLAYER_COOLDOWN_DANO_CENITAL_S), "nuevo daño reinicia cooldown a 5.0s")
	player._physics_process(5.1)
	player.velocity = Vector3.ZERO
	assert(not player.en_cooldown_dano_cenital(), "tras 5.1s expira cooldown de daño")
	assert(player.motivo_bloqueo_cenital() == "", "expirado el cooldown permite vista cenital")

	var MainScript = preload("res://scripts/Main.gd")
	var main_stub = MainScript.new()
	main_stub.cenital_activa = false
	main_stub.jugador = player
	main_stub.hud = hud
	player.recibir_dano(10.0)
	main_stub._alternar_camara_cenital()
	assert(not main_stub.cenital_activa, "Main._alternar_camara_cenital debe bloquear paso a cenital mientras hay motivo")
	main_stub.free()

	for cid in [id_obj, id_m1, id_m2]:
		var cel: Vector3i = Colonos.colonos[cid]["celda"]
		Colonos.ocupadas.erase(cel)
		Colonos.colonos.erase(cid)
	raiz.queue_free()

	print("\n=== Las 8 pruebas de PlayerCombateComandanteTest pasaron correctamente ===")
