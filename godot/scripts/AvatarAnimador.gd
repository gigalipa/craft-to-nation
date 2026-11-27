extends Node
class_name AvatarAnimador

## Controlador de animaciones del personaje 3D del jugador (avatar.glb).
## Encapsula el AnimationPlayer y Skeleton3D internos para:
##  - Configurar loops en ciclos continuos y desactivarlos en acciones puntuales.
##  - Ocultar los huesos de la cabeza (Head/Neck) en 1ª persona sin romper
##    las animaciones (SkeletonModifier3D), y mostrarla completa en vista cenital.
##  - Exponer BoneAttachment3D en RightHand / LeftHand para acoplar armas/útiles.
##  - Seleccionar la animación adecuada según locomoción, agua, salto, acción,
##    armamento, órdenes de comandante, cámara cenital, daño o muerte.

const Ajustes = preload("res://scripts/ajustes.gd")
const CatalogoPersonajes = preload("res://scripts/CatalogoPersonajes.gd")

const ANIMACIONES_LOOP: Array[String] = [
	"Idle",
	"Walking",
	"Walking_Backward",
	"Strafe_Left",
	"Strafe_Right",
	"Running",
	"Strafe_Left_Run",
	"Strafe_Right_Run",
	"Falling_Idle",
	"Treading_Water",
	"Swimming",
	"Mining_Swing",
	"Cenital_Kneel_Idle",
	"Sword_Idle",
	"Sword_Run",
	"Sword_Strafe",
	"Sword_Block_Idle",
	"Bow_Idle",
	"Bow_Aim_Hold",
	"Bow_Aim_Walk_Forward",
	"Bow_Aim_Walk_Back",
	"Bow_Aim_Walk_Left",
	"Bow_Aim_Walk_Right",
]

const BLEND_POR_DEFECTO := 0.15
const BLEND_RAPIDO := 0.08


class _OcultarCabezaModifier extends SkeletonModifier3D:
	var activo: bool = false
	var huesos: Array[int] = []

	func _process_modification_with_delta(_delta: float) -> void:
		if not activo:
			return
		var skel: Skeleton3D = get_skeleton()
		if skel == null:
			return
		for idx in huesos:
			skel.set_bone_pose_scale(idx, Vector3(0.001, 0.001, 0.001))


var _modelo: Node3D = null
var _anim_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _modificador_cabeza: _OcultarCabezaModifier = null
var _anclaje_mano_der: BoneAttachment3D = null
var _anclaje_mano_izq: BoneAttachment3D = null

var _estado_cenital: String = ""  # "", "bajando", "arrodillado", "levantando"
var _muerto: bool = false
var _en_accion_puntual: bool = false
var _anim_actual: String = ""
var _alternar_tajo: bool = false
var _en_primera_persona: bool = true


func configurar(modelo_avatar: Node3D) -> bool:
	_modelo = modelo_avatar
	if _modelo == null:
		return false
	_anim_player = _buscar_nodo(_modelo, "AnimationPlayer") as AnimationPlayer
	if _anim_player == null:
		return false
	_skeleton = _buscar_nodo(_modelo, "Skeleton3D") as Skeleton3D

	var loops_set: Dictionary = {}
	for nombre_loop in ANIMACIONES_LOOP:
		loops_set[nombre_loop] = true

	for anim_name: StringName in _anim_player.get_animation_list():
		var anim: Animation = _anim_player.get_animation(anim_name)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR if loops_set.has(String(anim_name)) else Animation.LOOP_NONE

	if not _anim_player.animation_finished.is_connected(_on_animacion_terminada):
		_anim_player.animation_finished.connect(_on_animacion_terminada)

	if _skeleton != null:
		_modificador_cabeza = _OcultarCabezaModifier.new()
		_modificador_cabeza.name = "OcultarCabezaModifier"
		var huesos_cab: Array[int] = []
		for nombre_hueso in ["Head", "Neck"]:
			var idx: int = _skeleton.find_bone(nombre_hueso)
			if idx != -1:
				huesos_cab.append(idx)
		_modificador_cabeza.huesos = huesos_cab
		_modificador_cabeza.activo = _en_primera_persona
		_skeleton.add_child(_modificador_cabeza)

		_anclaje_mano_der = BoneAttachment3D.new()
		_anclaje_mano_der.name = "AnclajeManoDerecha"
		_anclaje_mano_der.bone_name = "RightHand"
		_skeleton.add_child(_anclaje_mano_der)

		_anclaje_mano_izq = BoneAttachment3D.new()
		_anclaje_mano_izq.name = "AnclajeManoIzquierda"
		_anclaje_mano_izq.bone_name = "LeftHand"
		_skeleton.add_child(_anclaje_mano_izq)

	_reproducir("Idle", 0.0, 1.0, false)
	return true


func _buscar_nodo(raiz: Node, clase: String) -> Node:
	if raiz.get_class() == clase or raiz.is_class(clase):
		return raiz
	for hijo in raiz.get_children():
		var hallado := _buscar_nodo(hijo, clase)
		if hallado != null:
			return hallado
	return null


func anim_player() -> AnimationPlayer:
	return _anim_player


func animacion_actual() -> String:
	return _anim_actual


func anclaje_mano_derecha() -> BoneAttachment3D:
	return _anclaje_mano_der


func anclaje_mano_izquierda() -> BoneAttachment3D:
	return _anclaje_mano_izq


func cabeza_oculta() -> bool:
	return _modificador_cabeza != null and _modificador_cabeza.activo


func establecer_vista_primera_persona(en_primera: bool) -> void:
	_en_primera_persona = en_primera
	if _modificador_cabeza != null:
		_modificador_cabeza.activo = en_primera


func iniciar_cenital() -> void:
	if _muerto or _anim_player == null:
		return
	_en_accion_puntual = false
	_estado_cenital = "bajando"
	establecer_vista_primera_persona(false)
	_reproducir("Cenital_Kneel_Down", BLEND_POR_DEFECTO, 1.0, false)


func salir_cenital(duracion_transicion: float = 0.6) -> void:
	if _muerto or _anim_player == null:
		return
	_en_accion_puntual = false
	_estado_cenital = "levantando"
	var vel := clampf(2.233 / maxf(duracion_transicion, 0.25), 1.0, 4.0)
	_reproducir("Cenital_Stand_Up", BLEND_POR_DEFECTO, vel, false)


func finalizar_salida_cenital() -> void:
	_estado_cenital = ""
	establecer_vista_primera_persona(true)


func notificar_salto() -> void:
	if _muerto or _estado_cenital != "":
		return
	_reproducir("Jump_Start", 0.05, 1.0, true)


func notificar_aterrizaje(fuerte: bool = false) -> void:
	if not fuerte or _muerto or _estado_cenital != "":
		return
	_reproducir("Jump_Land", BLEND_RAPIDO, 1.5, true)


func notificar_cambio_modo_o_arma(modo: String, arma_id: String, modo_previo: String, arma_previa: String) -> void:
	if _muerto or _estado_cenital != "":
		return
	if modo == "batalla":
		if arma_id == "arco":
			_reproducir("Bow_Equip", BLEND_RAPIDO, 1.4, true)
		else:
			_reproducir("Sword_Equip", BLEND_RAPIDO, 1.4, true)
	elif modo_previo == "batalla" and modo != "batalla":
		if arma_previa == "arco":
			_reproducir("Bow_Disarm", BLEND_RAPIDO, 1.6, true)
		elif arma_previa == "espada":
			_reproducir("Sword_Sheath", BLEND_RAPIDO, 1.8, true)


func notificar_ataque(arma_id: String) -> void:
	if _muerto or _estado_cenital != "":
		return
	if arma_id == "arco":
		_reproducir("Bow_Release", BLEND_RAPIDO, 1.4, true)
	else:
		_alternar_tajo = not _alternar_tajo
		if _alternar_tajo:
			_reproducir("Sword_Slash_2", BLEND_RAPIDO, 1.8, true)
		else:
			_reproducir("Sword_Slash", BLEND_RAPIDO, 2.0, true)


func notificar_orden_comandante(orden_id: String) -> void:
	if _muerto or _estado_cenital != "":
		return
	match orden_id:
		"atacar":
			_reproducir("Command_Charge", BLEND_RAPIDO, 1.8, true)
		"moverse", "patrullar":
			_reproducir("Command_Point", BLEND_RAPIDO, 1.6, true)
		_:
			_reproducir("Command_Rally", BLEND_RAPIDO, 1.6, true)


func notificar_dano() -> void:
	if _muerto or _estado_cenital != "":
		return
	_reproducir("Hit_React", 0.06, 1.4, true)


func notificar_muerte() -> void:
	_muerto = true
	_estado_cenital = ""
	_en_accion_puntual = false
	_reproducir("Death", 0.1, 1.0, false)


func reiniciar() -> void:
	_muerto = false
	_estado_cenital = ""
	_en_accion_puntual = false
	_reproducir("Idle", 0.1, 1.0, false)


func actualizar_locomocion(vel_local: Vector3, en_piso: bool, nadando: bool, accion_herramienta: bool, modo: String, arma_id: String, vel_correr: float) -> void:
	if _anim_player == null or _muerto or _estado_cenital != "" or _en_accion_puntual:
		return
	if accion_herramienta and modo == "construccion":
		_reproducir("Mining_Swing", 0.1, 1.3, false)
		return
	if nadando:
		if vel_local.length_squared() > 0.15:
			_reproducir("Swimming", BLEND_POR_DEFECTO, 1.0, false)
		else:
			_reproducir("Treading_Water", BLEND_POR_DEFECTO, 1.0, false)
		return
	if not en_piso and vel_local.y < -0.5:
		_reproducir("Falling_Idle", BLEND_RAPIDO, 1.0, false)
		return

	var vel_h := Vector2(vel_local.x, vel_local.z)
	var rapidez := vel_h.length()
	var corriendo := rapidez > vel_correr
	var fwd := -vel_local.z
	var strafe := vel_local.x

	if modo == "batalla":
		if arma_id == "arco":
			if rapidez < 0.25:
				_reproducir("Bow_Idle", BLEND_POR_DEFECTO, 1.0, false)
			elif absf(strafe) > absf(fwd) * 1.2:
				_reproducir("Bow_Aim_Walk_Right" if strafe > 0.0 else "Bow_Aim_Walk_Left", BLEND_POR_DEFECTO, 1.0, false)
			elif fwd < -0.1:
				_reproducir("Bow_Aim_Walk_Back", BLEND_POR_DEFECTO, 1.0, false)
			else:
				_reproducir("Bow_Aim_Walk_Forward", BLEND_POR_DEFECTO, 1.0, false)
		else:
			if rapidez < 0.25:
				_reproducir("Sword_Idle", BLEND_POR_DEFECTO, 1.0, false)
			elif absf(strafe) > absf(fwd) * 1.2:
				_reproducir("Sword_Strafe", BLEND_POR_DEFECTO, 1.0, false)
			else:
				_reproducir("Sword_Run", BLEND_POR_DEFECTO, 1.0, false)
		return

	if rapidez < 0.25:
		_reproducir("Idle", BLEND_POR_DEFECTO, 1.0, false)
	elif absf(strafe) > absf(fwd) * 1.2:
		if corriendo:
			_reproducir("Strafe_Right_Run" if strafe > 0.0 else "Strafe_Left_Run", BLEND_POR_DEFECTO, 1.0, false)
		else:
			_reproducir("Strafe_Right" if strafe > 0.0 else "Strafe_Left", BLEND_POR_DEFECTO, 1.0, false)
	elif fwd < -0.1:
		_reproducir("Walking_Backward", BLEND_POR_DEFECTO, 1.0, false)
	elif corriendo:
		_reproducir("Running", BLEND_POR_DEFECTO, 1.0, false)
	else:
		_reproducir("Walking", BLEND_POR_DEFECTO, 1.0, false)


func _on_animacion_terminada(anim_name: StringName) -> void:
	if anim_name == &"Cenital_Kneel_Down" and _estado_cenital == "bajando":
		_estado_cenital = "arrodillado"
		_reproducir("Cenital_Kneel_Idle", BLEND_POR_DEFECTO, 1.0, false)
		return
	if anim_name == &"Cenital_Stand_Up" and _estado_cenital == "levantando":
		_estado_cenital = ""
		return
	if _en_accion_puntual:
		_en_accion_puntual = false


func _reproducir(nombre: String, blend: float = BLEND_POR_DEFECTO, velocidad: float = 1.0, es_puntual: bool = false) -> void:
	if _anim_player == null or not _anim_player.has_animation(nombre):
		return
	if not es_puntual and _anim_actual == nombre and _anim_player.is_playing():
		if not is_equal_approx(_anim_player.speed_scale, velocidad):
			_anim_player.speed_scale = velocidad
		return
	_en_accion_puntual = es_puntual
	_anim_actual = nombre
	_anim_player.speed_scale = velocidad
	_anim_player.play(nombre, blend)


var _equip_der_id: String = ""
var _equip_izq_id: String = ""


func aplicar_identidad_visual(tono_piel: int, color_equipo: Color) -> Dictionary:
	if _modelo == null:
		return {"piel": 0, "equipo": 0}
	return CatalogoPersonajes.aplicar_materiales_identidad(_modelo, tono_piel, color_equipo)


func establecer_resplandor_sucesion(activo: bool, intensidad: float = 2.6, tono_piel: int = 1, color_equipo: Color = Ajustes.COLOR_EQUIPO_DEFECTO) -> void:
	if _modelo == null:
		return
	var mat: StandardMaterial3D = null
	if activo:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Ajustes.COLOR_SUCESION_RESPLANDOR * intensidad
	_aplicar_override_recursivo(_modelo, mat)
	if not activo:
		aplicar_identidad_visual(tono_piel, color_equipo)


func _aplicar_override_recursivo(nodo: Node, mat: Material) -> void:
	if nodo is MeshInstance3D:
		(nodo as MeshInstance3D).material_override = mat
	for hijo in nodo.get_children():
		_aplicar_override_recursivo(hijo, mat)


func equipar_en_mano(lado: String, pieza_id: String, tono_piel: int = 1, color_equipo: Color = Ajustes.COLOR_EQUIPO_DEFECTO) -> bool:
	var es_der := (lado.strip_edges().to_lower() == "derecha")
	var anclaje: BoneAttachment3D = _anclaje_mano_der if es_der else _anclaje_mano_izq
	var actual_id := _equip_der_id if es_der else _equip_izq_id
	if pieza_id == actual_id and (pieza_id.is_empty() or (anclaje != null and anclaje.get_child_count() > 0)):
		return true
	if es_der:
		_equip_der_id = pieza_id
	else:
		_equip_izq_id = pieza_id
	if anclaje == null:
		return false
	for hijo in anclaje.get_children():
		hijo.queue_free()
	if pieza_id.is_empty():
		return true
	var ruta := CatalogoPersonajes.resolver_ruta_equipamiento(pieza_id)
	if ruta.is_empty():
		return false
	var escena := CatalogoPersonajes.cargar_escena_cacheada(ruta)
	if escena == null:
		return false
	var inst := escena.instantiate()
	CatalogoPersonajes.aplicar_materiales_identidad(inst, tono_piel, color_equipo)
	anclaje.add_child(inst)
	return true
