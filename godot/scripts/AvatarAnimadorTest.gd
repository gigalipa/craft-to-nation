extends Node

## Pruebas de integración del personaje animado (avatar.glb) en Player.tscn,
## AvatarAnimador.gd, Player.gd y Main.gd.

const PlayerScene = preload("res://scenes/Player.tscn")
const AvatarAnimadorScript = preload("res://scripts/AvatarAnimador.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const Ajustes = preload("res://scripts/ajustes.gd")


func _ready() -> void:
	ejecutar_pruebas()


func _crear_jugador_de_escena() -> Dictionary:
	var raiz := Node3D.new()
	add_child(raiz)
	var hud: CanvasLayer = HUDScript.new()
	hud.name = "HUDLayer"
	raiz.add_child(hud)
	var player: Player = PlayerScene.instantiate() as Player
	raiz.add_child(player)
	hud.set_vista(true)
	return {"raiz": raiz, "hud": hud, "player": player}


func _tecla(codigo: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.pressed = true
	ev.echo = false
	return ev


func ejecutar_pruebas() -> void:
	var ctx := _crear_jugador_de_escena()
	var raiz: Node3D = ctx["raiz"]
	var player: Player = ctx["player"]
	var animador: AvatarAnimadorScript = player.animador_avatar()

	print("=== TEST 1: Instanciación de Player.tscn con avatar.glb y AvatarAnimador ===")
	var modelo := player.get_node_or_null("ModeloAvatar") as Node3D
	assert(modelo != null, "Player.tscn debe contener el nodo ModeloAvatar")
	assert(is_equal_approx(absf(modelo.rotation.y), PI), "ModeloAvatar debe rotar 180° en Y para mirar hacia -Z")
	assert(player.camara.position.is_equal_approx(Vector3(0.0, 1.6, -0.14)), "Cámara debe estar adelantada en Z (-0.14)")
	assert(animador != null, "Player debe inicializar AvatarAnimador cuando existe ModeloAvatar")
	var ap: AnimationPlayer = animador.anim_player()
	assert(ap != null and ap.get_animation_list().size() == 47, "avatar.glb debe exponer exactamente 47 animaciones")
	assert(animador.anclaje_mano_derecha() != null and animador.anclaje_mano_derecha().bone_name == &"RightHand", "BoneAttachment3D RightHand listo")
	assert(animador.anclaje_mano_izquierda() != null and animador.anclaje_mano_izquierda().bone_name == &"LeftHand", "BoneAttachment3D LeftHand listo")

	print("=== TEST 2: Configuración de loop_mode en animaciones ===")
	for loop_anim in ["Idle", "Walking", "Swimming", "Cenital_Kneel_Idle", "Sword_Idle", "Bow_Aim_Hold", "Mining_Swing"]:
		assert(ap.get_animation(loop_anim).loop_mode == Animation.LOOP_LINEAR, "%s debe tener LOOP_LINEAR" % loop_anim)
	for oneshot_anim in ["Jump_Start", "Sword_Slash_2", "Cenital_Kneel_Down", "Death", "Hit_React"]:
		assert(ap.get_animation(oneshot_anim).loop_mode == Animation.LOOP_NONE, "%s debe tener LOOP_NONE" % oneshot_anim)

	print("=== TEST 3: Opción B (cabeza oculta en 1ª persona, visible en cenital) ===")
	assert(animador.cabeza_oculta(), "En 1ª persona Head/Neck deben ocultarse")
	assert(animador.animacion_actual() == "Idle", "Estado inicial en suelo debe ser Idle")
	player.iniciar_animacion_cenital()
	assert(not animador.cabeza_oculta(), "Al entrar a cenital debe mostrarse la cabeza completa")
	assert(animador.animacion_actual() == "Cenital_Kneel_Down", "Al entrar a cenital reproduce Cenital_Kneel_Down")
	animador._on_animacion_terminada(&"Cenital_Kneel_Down")
	assert(animador.animacion_actual() == "Cenital_Kneel_Idle", "Tras arrodillarse encadena Cenital_Kneel_Idle")
	player.salir_animacion_cenital(0.6)
	assert(animador.animacion_actual() == "Cenital_Stand_Up", "Al salir de cenital reproduce Cenital_Stand_Up")
	player.finalizar_salida_cenital()
	assert(animador.cabeza_oculta(), "Al volver a 1ª persona vuelve a ocultar cabeza")

	print("=== TEST 4: Locomoción base, agua, aire y minado/construcción ===")
	animador.actualizar_locomocion(Vector3.ZERO, true, false, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Idle")
	animador.actualizar_locomocion(Vector3(0.0, 0.0, -4.0), true, false, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Walking", "Avance -> Walking")
	animador.actualizar_locomocion(Vector3(0.0, 0.0, 3.0), true, false, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Walking_Backward", "Retroceso -> Walking_Backward")
	animador.actualizar_locomocion(Vector3(-3.0, 0.0, 0.0), true, false, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Strafe_Left", "Lateral izq -> Strafe_Left")
	animador.actualizar_locomocion(Vector3(3.0, 0.0, 0.0), true, false, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Strafe_Right", "Lateral der -> Strafe_Right")
	animador.actualizar_locomocion(Vector3(0.0, 0.0, -7.0), true, false, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Running", "Velocidad alta -> Running")
	animador.actualizar_locomocion(Vector3(0.0, -2.0, 0.0), false, false, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Falling_Idle", "Caída -> Falling_Idle")
	animador.actualizar_locomocion(Vector3.ZERO, false, true, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Treading_Water", "Quieto en agua -> Treading_Water")
	animador.actualizar_locomocion(Vector3(0.0, 0.0, -2.5), false, true, false, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Swimming", "Nadando -> Swimming")
	animador.actualizar_locomocion(Vector3.ZERO, true, false, true, "construccion", "espada", 5.75)
	assert(animador.animacion_actual() == "Mining_Swing", "Acción herramienta -> Mining_Swing")

	print("=== TEST 5: Modos Batalla (Espada/Arco), Comandante, Daño y Muerte ===")
	player._input(_tecla(KEY_R))
	assert(animador.animacion_actual() == "Sword_Equip", "Entrar a Batalla con espada reproduce Sword_Equip")
	animador._on_animacion_terminada(&"Sword_Equip")
	animador.actualizar_locomocion(Vector3.ZERO, true, false, false, "batalla", "espada", 5.75)
	assert(animador.animacion_actual() == "Sword_Idle")
	animador.actualizar_locomocion(Vector3(0.0, 0.0, -4.0), true, false, false, "batalla", "espada", 5.75)
	assert(animador.animacion_actual() == "Sword_Run")
	animador.notificar_ataque("espada")
	assert(animador.animacion_actual() == "Sword_Slash_2")
	animador._on_animacion_terminada(&"Sword_Slash_2")

	player._input(_tecla(KEY_2))
	assert(animador.animacion_actual() == "Bow_Equip", "Cambiar a Arco reproduce Bow_Equip")
	animador._on_animacion_terminada(&"Bow_Equip")
	animador.actualizar_locomocion(Vector3.ZERO, true, false, false, "batalla", "arco", 5.75)
	assert(animador.animacion_actual() == "Bow_Idle")
	animador.actualizar_locomocion(Vector3(0.0, 0.0, -3.0), true, false, false, "batalla", "arco", 5.75)
	assert(animador.animacion_actual() == "Bow_Aim_Walk_Forward")
	animador.notificar_ataque("arco")
	assert(animador.animacion_actual() == "Bow_Release")
	animador._on_animacion_terminada(&"Bow_Release")

	player._input(_tecla(KEY_F))
	assert(animador.animacion_actual() == "Bow_Disarm", "Salir de arco reproduce Bow_Disarm")
	animador._on_animacion_terminada(&"Bow_Disarm")
	animador.notificar_orden_comandante("atacar")
	assert(animador.animacion_actual() == "Command_Charge")
	animador._on_animacion_terminada(&"Command_Charge")
	animador.notificar_orden_comandante("moverse")
	assert(animador.animacion_actual() == "Command_Point")
	animador._on_animacion_terminada(&"Command_Point")
	animador.notificar_orden_comandante("defender")
	assert(animador.animacion_actual() == "Command_Rally")
	animador._on_animacion_terminada(&"Command_Rally")

	player.registrar_dano_recibido()
	assert(animador.animacion_actual() == "Hit_React", "Recibir daño dispara Hit_React")
	animador._on_animacion_terminada(&"Hit_React")
	animador.notificar_muerte()
	assert(animador.animacion_actual() == "Death", "Muerte dispara Death")
	animador.reiniciar()
	assert(animador.animacion_actual() == "Idle", "Reiniciar vuelve a Idle")

	raiz.queue_free()
	print("\n=== Las 5 pruebas de AvatarAnimadorTest pasaron correctamente ===")
	get_tree().quit(0)
