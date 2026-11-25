extends Node3D

## Representación visual modular de un colono (Capa 1: atuendo/cuerpo/cápsula,
## Identidad: tono de piel + color de equipo, Capa 2: equipamiento rígido en
## BoneAttachment3D). Emplea dirty-checking por firma para no reconstruir ni
## reasignar recursos en _physics_process cuando no hay cambios.

const Ajustes = preload("res://scripts/ajustes.gd")
const CatalogoPersonajes = preload("res://scripts/CatalogoPersonajes.gd")

const ALTURA_PLACEHOLDER := 1.8
const RADIO_PLACEHOLDER := 0.3

var existe_recurso_fn: Callable = Callable()

var _modo_visual: String = "placeholder"
var _firma_capa1: String = ""
var _firma_identidad: String = ""
var _firma_capa2: String = ""

var _raiz_visual: Node3D = null
var _skeleton: Skeleton3D = null
var _anim_player: AnimationPlayer = null
var _anclajes: Dictionary = {}  # slot -> BoneAttachment3D
var _equipamiento_logico: Dictionary = {}  # slot -> pieza_id
var _equipamiento_instanciado: Dictionary = {}  # slot -> pieza_id
var _capsula_malla: MeshInstance3D = null
var _capsula_mat: StandardMaterial3D = null
var _banda_equipo: MeshInstance3D = null
var _banda_equipo_mat: StandardMaterial3D = null
var _anim_actual: String = ""


func modo_visual() -> String:
	return _modo_visual


func equipamiento_logico() -> Dictionary:
	return _equipamiento_logico.duplicate()


func equipamiento_instanciado() -> Dictionary:
	return _equipamiento_instanciado.duplicate()


func obtener_anclaje(slot: String) -> BoneAttachment3D:
	return _anclajes.get(slot, null) as BoneAttachment3D


func obtener_capsula_material() -> StandardMaterial3D:
	return _capsula_mat


func obtener_banda_equipo_material() -> StandardMaterial3D:
	return _banda_equipo_mat


func actualizar_colono(colono: Dictionary, tipo_puesto: String, color_equipo: Color, era: int = 1) -> void:
	var rango := str(colono.get("tipo", "desempleado")).strip_edges().to_lower()
	if rango.is_empty():
		rango = "desempleado"
	var genero := CatalogoPersonajes.normalizar_genero(str(colono.get("genero", "M")))
	var tono_piel := CatalogoPersonajes.normalizar_tono_piel(int(colono.get("tono_piel", 1)))

	var firma1 := "%s|%s" % [rango, genero]
	if firma1 != _firma_capa1:
		_reconstruir_capa1(rango, genero, color_equipo)
		_firma_capa1 = firma1
		_firma_identidad = ""
		_firma_capa2 = ""

	var firma_id := "%s|%d|%s" % [rango, tono_piel, color_equipo.to_html(false)]
	if firma_id != _firma_identidad:
		_aplicar_identidad(rango, tono_piel, color_equipo)
		_firma_identidad = firma_id

	var nuevo_eq := CatalogoPersonajes.resolver_equipamiento(colono, tipo_puesto, era)
	var firma2 := _serializar_equipamiento(nuevo_eq)
	if firma2 != _firma_capa2:
		_actualizar_capa2(nuevo_eq, tono_piel, color_equipo)
		_firma_capa2 = firma2

	if _modo_visual != "placeholder":
		rotation.y = float(colono.get("orientacion_y", 0.0))
		_actualizar_animacion(colono)


func _reconstruir_capa1(rango: String, genero: String, color_equipo: Color) -> void:
	_limpiar_capa1()
	var res := CatalogoPersonajes.resolver_modelo_capa1(rango, genero, existe_recurso_fn)
	var modo := str(res.get("modo", "placeholder"))

	if modo == "atuendo" or modo == "base":
		var inst := _instanciar_modelo_capa1(res, modo)
		if inst != null:
			_modo_visual = modo
			_raiz_visual = inst
			_raiz_visual.rotation.y = PI
			add_child(_raiz_visual)
			_skeleton = CatalogoPersonajes.buscar_nodo_por_clase(_raiz_visual, "Skeleton3D") as Skeleton3D
			_anim_player = CatalogoPersonajes.buscar_nodo_por_clase(_raiz_visual, "AnimationPlayer") as AnimationPlayer
			_configurar_anclajes()
			_configurar_animaciones_base()
			return

	_modo_visual = "placeholder"
	_construir_placeholder(rango, color_equipo)


func _instanciar_modelo_capa1(res: Dictionary, modo: String) -> Node3D:
	if modo == "atuendo":
		var escena_at := CatalogoPersonajes.cargar_escena_cacheada(str(res.get("ruta_atuendo", "")))
		if escena_at == null:
			return null
		var inst_at := escena_at.instantiate() as Node3D
		if inst_at == null:
			return null
		if CatalogoPersonajes.buscar_nodo_por_clase(inst_at, "Skeleton3D") != null:
			return inst_at  # Modo A: escena riggeada autónoma
		# Modo B: acoplar mallas skinned al esqueleto de cuerpo_<m|f>.glb
		var escena_base := CatalogoPersonajes.cargar_escena_cacheada(str(res.get("ruta_base", "")))
		if escena_base == null:
			inst_at.queue_free()
			return null
		var inst_base := escena_base.instantiate() as Node3D
		var skel_base := CatalogoPersonajes.buscar_nodo_por_clase(inst_base, "Skeleton3D") as Skeleton3D
		if skel_base == null:
			inst_at.queue_free()
			if inst_base != null:
				inst_base.queue_free()
			return null
		for hijo in skel_base.get_children():
			if hijo is MeshInstance3D:
				hijo.queue_free()
		_reparentar_mallas_a_skeleton(inst_at, skel_base)
		inst_at.queue_free()
		return inst_base

	var escena_b := CatalogoPersonajes.cargar_escena_cacheada(str(res.get("ruta_base", "")))
	if escena_b == null:
		return null
	return escena_b.instantiate() as Node3D


func _reparentar_mallas_a_skeleton(origen: Node, skel_destino: Skeleton3D) -> void:
	var mallas: Array[MeshInstance3D] = []
	var pila: Array[Node] = [origen]
	while not pila.is_empty():
		var nodo: Node = pila.pop_back()
		if nodo is MeshInstance3D:
			mallas.append(nodo as MeshInstance3D)
		for hijo in nodo.get_children():
			pila.append(hijo)
	for mi in mallas:
		if mi.get_parent() != null:
			mi.get_parent().remove_child(mi)
		skel_destino.add_child(mi)
		mi.skeleton = NodePath("..")


func _configurar_anclajes() -> void:
	_anclajes.clear()
	if _skeleton == null:
		return
	for slot_nombre: String in CatalogoPersonajes.SLOTS_HUESO:
		var candidatos: Array = CatalogoPersonajes.SLOTS_HUESO[slot_nombre]
		var hueso_encontrado := ""
		for h in candidatos:
			if _skeleton.find_bone(str(h)) != -1:
				hueso_encontrado = str(h)
				break
		if hueso_encontrado.is_empty():
			continue
		var anclaje := BoneAttachment3D.new()
		anclaje.name = "Anclaje_" + slot_nombre
		anclaje.bone_name = StringName(hueso_encontrado)
		_skeleton.add_child(anclaje)
		_anclajes[slot_nombre] = anclaje


func _configurar_animaciones_base() -> void:
	var lib := CatalogoPersonajes.obtener_biblioteca_animaciones()
	if lib != null and _raiz_visual != null:
		if _anim_player == null:
			_anim_player = AnimationPlayer.new()
			_anim_player.name = "AnimationPlayer"
			_raiz_visual.add_child(_anim_player)
		if not _anim_player.has_animation_library(""):
			_anim_player.add_animation_library("", lib)
		else:
			var actual_lib := _anim_player.get_animation_library("")
			for anim_name: StringName in lib.get_animation_list():
				if not actual_lib.has_animation(anim_name):
					actual_lib.add_animation(anim_name, lib.get_animation(anim_name))
	if _anim_player != null:
		for loop_nombre in ["Idle", "Walking", "Mining_Swing"]:
			if _anim_player.has_animation(loop_nombre):
				_anim_player.get_animation(loop_nombre).loop_mode = Animation.LOOP_LINEAR


func _construir_placeholder(rango: String, color_equipo: Color) -> void:
	_capsula_malla = MeshInstance3D.new()
	_capsula_malla.name = "CapsulaPlaceholder"
	var capsula := CapsuleMesh.new()
	capsula.radius = RADIO_PLACEHOLDER
	capsula.height = ALTURA_PLACEHOLDER
	_capsula_mat = StandardMaterial3D.new()
	_capsula_mat.albedo_color = Ajustes.COLORES_COLONOS.get(rango, Color.WHITE)
	capsula.material = _capsula_mat
	_capsula_malla.mesh = capsula
	_capsula_malla.position = Vector3(0.0, ALTURA_PLACEHOLDER / 2.0, 0.0)
	add_child(_capsula_malla)

	_banda_equipo = MeshInstance3D.new()
	_banda_equipo.name = "DistintivoEquipo"
	var banda := CylinderMesh.new()
	banda.height = 0.14
	banda.top_radius = RADIO_PLACEHOLDER + 0.015
	banda.bottom_radius = RADIO_PLACEHOLDER + 0.015
	banda.radial_segments = 12
	_banda_equipo_mat = StandardMaterial3D.new()
	_banda_equipo_mat.albedo_color = color_equipo
	banda.material = _banda_equipo_mat
	_banda_equipo.mesh = banda
	_banda_equipo.position = Vector3(0.0, 1.05, 0.0)
	add_child(_banda_equipo)


func _aplicar_identidad(rango: String, tono_piel: int, color_equipo: Color) -> void:
	if _modo_visual == "placeholder":
		if _capsula_mat != null:
			_capsula_mat.albedo_color = Ajustes.COLORES_COLONOS.get(rango, Color.WHITE)
		if _banda_equipo_mat != null:
			_banda_equipo_mat.albedo_color = color_equipo
		return
	if _raiz_visual != null:
		CatalogoPersonajes.aplicar_materiales_identidad(_raiz_visual, tono_piel, color_equipo)


func _actualizar_capa2(nuevo_eq: Dictionary, tono_piel: int, color_equipo: Color) -> void:
	_equipamiento_logico = nuevo_eq.duplicate()
	_equipamiento_instanciado.clear()
	for slot in _anclajes:
		var anclaje := _anclajes[slot] as BoneAttachment3D
		if anclaje == null:
			continue
		for hijo in anclaje.get_children():
			hijo.queue_free()
	if _modo_visual == "placeholder":
		return
	for slot in nuevo_eq:
		var anclaje := _anclajes.get(slot, null) as BoneAttachment3D
		if anclaje == null:
			continue
		var pieza_id := str(nuevo_eq[slot])
		var ruta := CatalogoPersonajes.resolver_ruta_equipamiento(pieza_id, existe_recurso_fn)
		if ruta.is_empty():
			continue
		var escena := CatalogoPersonajes.cargar_escena_cacheada(ruta)
		if escena == null:
			continue
		var pieza := escena.instantiate()
		CatalogoPersonajes.aplicar_materiales_identidad(pieza, tono_piel, color_equipo)
		anclaje.add_child(pieza)
		_equipamiento_instanciado[slot] = pieza_id


func _actualizar_animacion(colono: Dictionary) -> void:
	if _anim_player == null:
		return
	var anim_deseada := "Idle"
	if bool(colono.get("moviendo", false)):
		anim_deseada = "Walking"
	elif colono.get("tarea", {}) is Dictionary and not (colono["tarea"] as Dictionary).is_empty():
		anim_deseada = "Mining_Swing"
	if not _anim_player.has_animation(anim_deseada):
		if _anim_player.has_animation("Idle"):
			anim_deseada = "Idle"
		else:
			return
	if _anim_actual == anim_deseada and _anim_player.is_playing():
		return
	_anim_actual = anim_deseada
	_anim_player.play(anim_deseada, 0.15)


func _serializar_equipamiento(eq: Dictionary) -> String:
	var claves := eq.keys()
	claves.sort()
	var partes: Array[String] = []
	for k in claves:
		partes.append("%s=%s" % [str(k), str(eq[k])])
	return "|".join(partes)


func _limpiar_capa1() -> void:
	_anclajes.clear()
	_skeleton = null
	_anim_player = null
	_anim_actual = ""
	if _raiz_visual != null:
		_raiz_visual.queue_free()
		_raiz_visual = null
	if _capsula_malla != null:
		_capsula_malla.queue_free()
		_capsula_malla = null
	_capsula_mat = null
	if _banda_equipo != null:
		_banda_equipo.queue_free()
		_banda_equipo = null
	_banda_equipo_mat = null
