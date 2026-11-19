extends Node3D

## Dibuja a los colonos (una cápsula placeholder por colono) y les da un cuerpo
## físico para que el avatar no pueda atravesarlos. Toda la lógica vive en el
## autoload Colonos; esto solo refleja su estado. Las unidades definitivas
## (Quaternius/KayKit, GDD Sección 11) solo cambiarían la malla.
## ponytail: un MeshInstance3D + AnimatableBody3D por colono; pasar a
## MultiMesh si la población llega a miles.

const Ajustes = preload("res://scripts/ajustes.gd")

const ALTURA_COLONO := 1.8
const RADIO_COLONO := 0.3

static var COLORES_TIPO: Dictionary = Ajustes.COLORES_COLONOS

var _cuerpos: Dictionary = {}  # int (id de colono) -> AnimatableBody3D
var _marcadores_ordenes: Node3D
var _firma_marcadores_prev: String = ""
var _mat_casco: StandardMaterial3D
var _mat_visera: StandardMaterial3D
var _mat_escudo: StandardMaterial3D
var _mat_aro_militar: StandardMaterial3D
var _mat_aro_subgrupo: StandardMaterial3D
var _mat_aro_civil: StandardMaterial3D
var _mat_marcador_orden: StandardMaterial3D
var _mat_marcador_ataque: StandardMaterial3D
var _mat_marcador_patrulla: StandardMaterial3D


func _ready() -> void:
	_inicializar_materiales()
	_marcadores_ordenes = Node3D.new()
	_marcadores_ordenes.name = "MarcadoresOrdenes"
	add_child(_marcadores_ordenes)
	Colonos.colono_creado.connect(_on_colono_creado)
	Colonos.colono_retirado.connect(_on_colono_retirado)
	for id in Colonos.colonos:
		_on_colono_creado(id)


func _on_colono_creado(id: int) -> void:
	var tipo: String = Colonos.colonos[id]["tipo"]
	var cuerpo := AnimatableBody3D.new()
	# Capa 2: el avatar ya no choca con los colonos (Player.collision_mask = 1): él los empuja
	# (Colonos.actualizar_avatar()) y ellos no pueden moverlo; el raycast del jugador y el picking de CamaraCenital (máscara 1) los
	# atraviesan, así un clic sobre un colono elige el terreno de debajo.
	cuerpo.collision_layer = 2
	cuerpo.collision_mask = 0

	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = RADIO_COLONO
	capsula.height = ALTURA_COLONO
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORES_TIPO.get(tipo, Color.WHITE)
	capsula.material = material
	malla.mesh = capsula
	malla.position = Vector3(0, ALTURA_COLONO / 2.0, 0)
	cuerpo.add_child(malla)

	var forma := CollisionShape3D.new()
	var capsula_fisica := CapsuleShape3D.new()
	capsula_fisica.radius = RADIO_COLONO
	capsula_fisica.height = ALTURA_COLONO
	forma.shape = capsula_fisica
	forma.position = Vector3(0, ALTURA_COLONO / 2.0, 0)
	cuerpo.add_child(forma)

	add_child(cuerpo)
	_cuerpos[id] = cuerpo
	cuerpo.set_meta("colono_id", id)
	cuerpo.global_position = Colonos.colonos[id]["posicion"]
	_asegurar_visuales_unidad(cuerpo, id)


func _on_colono_retirado(id: int) -> void:
	if _cuerpos.has(id):
		_cuerpos[id].queue_free()
		_cuerpos.erase(id)


func _physics_process(_delta: float) -> void:
	for id in _cuerpos:
		if Colonos.colonos.has(id):
			_cuerpos[id].global_position = Colonos.colonos[id]["posicion"]
			# El tipo cambia al graduarse o al emplearse: el color sigue al tipo actual.
			var material: StandardMaterial3D = _cuerpos[id].get_child(0).mesh.material
			material.albedo_color = COLORES_TIPO.get(Colonos.colonos[id]["tipo"], Color.WHITE)
			_asegurar_visuales_unidad(_cuerpos[id], id)
	_actualizar_marcadores_ordenes()


func _inicializar_materiales() -> void:
	_mat_casco = StandardMaterial3D.new()
	_mat_casco.albedo_color = Color(0.28, 0.34, 0.42)
	_mat_casco.metallic = 0.6
	_mat_casco.roughness = 0.35

	_mat_visera = StandardMaterial3D.new()
	_mat_visera.albedo_color = Color(0.10, 0.14, 0.18)

	_mat_escudo = StandardMaterial3D.new()
	_mat_escudo.albedo_color = Color(0.22, 0.32, 0.52)
	_mat_escudo.metallic = 0.4

	_mat_aro_militar = _crear_mat_unshaded(Color(0.95, 0.78, 0.22, 0.90))
	_mat_aro_subgrupo = _crear_mat_unshaded(Color(1.0, 0.94, 0.45, 0.98))
	_mat_aro_civil = _crear_mat_unshaded(Color(0.35, 0.78, 0.96, 0.85))
	_mat_marcador_orden = _crear_mat_unshaded(Color(0.25, 0.92, 0.48, 0.80))
	_mat_marcador_ataque = _crear_mat_unshaded(Color(0.95, 0.30, 0.25, 0.85))
	_mat_marcador_patrulla = _crear_mat_unshaded(Color(0.30, 0.85, 1.0, 0.75))


func _crear_mat_unshaded(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	return mat


func _asegurar_visuales_unidad(cuerpo: AnimatableBody3D, id: int) -> void:
	if _mat_casco == null:
		_inicializar_materiales()
	var c: Dictionary = Colonos.colonos.get(id, {})
	var es_militar: bool = (str(c.get("tipo", "")) == "militar")

	var casco := cuerpo.get_node_or_null("CascoMilitar") as Node3D
	var escudo := cuerpo.get_node_or_null("EscudoMilitar") as MeshInstance3D
	if es_militar and casco == null:
		casco = Node3D.new()
		casco.name = "CascoMilitar"
		var copa := MeshInstance3D.new()
		var m_copa := CylinderMesh.new()
		m_copa.height = 0.18
		m_copa.top_radius = 0.26
		m_copa.bottom_radius = 0.31
		copa.mesh = m_copa
		copa.material_override = _mat_casco
		copa.position = Vector3(0.0, ALTURA_COLONO - 0.12, 0.0)
		casco.add_child(copa)
		var visera := MeshInstance3D.new()
		var m_vis := BoxMesh.new()
		m_vis.size = Vector3(0.42, 0.06, 0.16)
		visera.mesh = m_vis
		visera.material_override = _mat_visera
		visera.position = Vector3(0.0, ALTURA_COLONO - 0.20, -0.24)
		casco.add_child(visera)
		cuerpo.add_child(casco)

	if es_militar and escudo == null:
		escudo = MeshInstance3D.new()
		escudo.name = "EscudoMilitar"
		var m_esc := BoxMesh.new()
		m_esc.size = Vector3(0.08, 0.50, 0.38)
		escudo.mesh = m_esc
		escudo.material_override = _mat_escudo
		escudo.position = Vector3(RADIO_COLONO + 0.06, ALTURA_COLONO * 0.52, -0.06)
		cuerpo.add_child(escudo)

	if casco != null:
		casco.visible = es_militar
	if escudo != null:
		escudo.visible = es_militar

	var aro := cuerpo.get_node_or_null("AroSeleccion") as MeshInstance3D
	if aro == null:
		aro = MeshInstance3D.new()
		aro.name = "AroSeleccion"
		var m_aro := TorusMesh.new()
		m_aro.inner_radius = 0.38
		m_aro.outer_radius = 0.50
		m_aro.rings = 16
		m_aro.ring_segments = 6
		aro.mesh = m_aro
		aro.position = Vector3(0.0, 0.03, 0.0)
		cuerpo.add_child(aro)

	var seleccionado: bool = Colonos.unidades_seleccionadas.has(id)
	aro.visible = seleccionado
	if seleccionado:
		if es_militar:
			var en_subgrupo: bool = (Colonos.subgrupo_activo != "" and str(c.get("rango", "")) == Colonos.subgrupo_activo)
			aro.material_override = _mat_aro_subgrupo if en_subgrupo else _mat_aro_militar
		else:
			aro.material_override = _mat_aro_civil


func _actualizar_marcadores_ordenes() -> void:
	if _marcadores_ordenes == null:
		return
	var firmas: Array[String] = []
	var entradas: Array = []
	for cid in Colonos.militares_seleccionados(false):
		var ord: Dictionary = Colonos.colonos[cid].get("orden_militar", {})
		if ord.is_empty():
			continue
		var tipo_o: String = str(ord.get("tipo", ""))
		if tipo_o == "patrullar":
			var wps: Array = ord.get("waypoints", [])
			if not wps.is_empty():
				firmas.append("%d:pat:%s" % [cid, str(wps)])
				entradas.append({"tipo": "patrullar", "waypoints": wps})
		elif ord.has("destino") and ord["destino"] is Vector3i and ord["destino"] != Colonos.INVALIDA:
			var dest: Vector3i = ord["destino"]
			firmas.append("%d:%s:%s" % [cid, tipo_o, str(dest)])
			entradas.append({"tipo": tipo_o, "destino": dest})

	var firma_actual: String = "|".join(firmas)
	if firma_actual == _firma_marcadores_prev:
		return
	_firma_marcadores_prev = firma_actual

	for hijo in _marcadores_ordenes.get_children():
		hijo.queue_free()

	var destinos_vistos: Dictionary = {}
	for ent in entradas:
		var d: Dictionary = ent
		var tipo_e: String = str(d.get("tipo", ""))
		if tipo_e == "patrullar":
			var wps: Array = d.get("waypoints", [])
			for i in range(wps.size()):
				var wp: Vector3i = wps[i]
				var pos_wp := Vector3(wp.x + 0.5, wp.y + 0.30, wp.z + 0.5)
				var poste := MeshInstance3D.new()
				var m_poste := CylinderMesh.new()
				m_poste.height = 0.60
				m_poste.top_radius = 0.06
				m_poste.bottom_radius = 0.06
				poste.mesh = m_poste
				poste.material_override = _mat_marcador_patrulla
				poste.position = pos_wp
				_marcadores_ordenes.add_child(poste)
				if i > 0:
					var wp_prev: Vector3i = wps[i - 1]
					var a := Vector3(wp_prev.x + 0.5, wp_prev.y + 0.05, wp_prev.z + 0.5)
					var b := Vector3(wp.x + 0.5, wp.y + 0.05, wp.z + 0.5)
					var dist := a.distance_to(b)
					if dist > 0.05:
						var seg := MeshInstance3D.new()
						var m_seg := BoxMesh.new()
						m_seg.size = Vector3(0.06, 0.03, dist)
						seg.mesh = m_seg
						seg.material_override = _mat_marcador_patrulla
						seg.position = (a + b) * 0.5
						_marcadores_ordenes.add_child(seg)
						seg.look_at_from_position(seg.position, b, Vector3.UP)
		else:
			var dest: Vector3i = d["destino"]
			var clave_dest := "%s:%s" % [tipo_e, str(dest)]
			if destinos_vistos.has(clave_dest):
				continue
			destinos_vistos[clave_dest] = true
			var disco := MeshInstance3D.new()
			var m_disco := CylinderMesh.new()
			m_disco.height = 0.05
			m_disco.top_radius = 0.38
			m_disco.bottom_radius = 0.38
			disco.mesh = m_disco
			disco.material_override = _mat_marcador_ataque if tipo_e == "atacar" else _mat_marcador_orden
			disco.position = Vector3(dest.x + 0.5, dest.y + 0.03, dest.z + 0.5)
			_marcadores_ordenes.add_child(disco)
