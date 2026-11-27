extends Node3D

## Sistema de alumbrado urbano automático para edificios declarados y vías.
## Dibuja 3 geometrías modulares mediante MultiMeshInstance3D (lampara_techo,
## aplique_pared, poste_luz), gestiona iluminación general por clústeres +
## dispersión atmosférica en cenital/larga distancia, y un pool acotado de
## OmniLight3D cercanas al avatar en 1ª persona.

const Ajustes = preload("res://scripts/ajustes.gd")
const TEX_HERRAJE := preload("res://assets/texturas/bloques/tex_metal_herraje.png")
const TEX_HERRAJE_NORMAL := preload("res://assets/texturas/bloques/tex_metal_herraje_normal.png")
const SHADER_HALO := preload("res://assets/shaders/halo_ciudad.gdshader")

enum TipoLuminaria { TECHO, APLIQUE, POSTE }

var mundo: Node
var atmosfera: Node
var modo_cenital: bool = false

## Referencias opcionales para inyección en pruebas (por defecto usan los autoloads).
var ciudad_ref: Object = null
var economia_ref: Object = null
var vias_ref: Object = null
var zonificacion_ref: Object = null

var luminarias: Array[Dictionary] = []
var _clusters: Array[Dictionary] = []
var _sucio: bool = true
var _acumulador_pool: float = 0.0

var _multi_techo: MultiMeshInstance3D
var _multi_aplique: MultiMeshInstance3D
var _multi_poste: MultiMeshInstance3D
var _pool_luces: Array[OmniLight3D] = []
var _pool_clusters: Array[OmniLight3D] = []
var _pool_halos: Array[MeshInstance3D] = []

var _mesh_techo: ArrayMesh
var _mesh_aplique: ArrayMesh
var _mesh_poste: ArrayMesh
var _mat_soporte: StandardMaterial3D
var _mat_foco: StandardMaterial3D


func _ready() -> void:
	_construir_materiales_y_mallas()
	_configurar_multimeshes()
	_configurar_pool_luces()
	_configurar_pool_clusters_y_halos()
	var c := _ciudad()
	if c != null and c.has_signal("tick_simulado") and not c.tick_simulado.is_connected(simular_hora):
		c.tick_simulado.connect(simular_hora)


func _ciudad() -> Object:
	return ciudad_ref if ciudad_ref != null else Ciudad


func _economia() -> Object:
	return economia_ref if economia_ref != null else Economia


func _vias() -> Object:
	return vias_ref if vias_ref != null else Vias


func _zonificacion() -> Object:
	return zonificacion_ref if zonificacion_ref != null else Zonificacion


func _construir_materiales_y_mallas() -> void:
	_mat_soporte = StandardMaterial3D.new()
	_mat_soporte.albedo_color = Color.WHITE
	_mat_soporte.albedo_texture = TEX_HERRAJE
	_mat_soporte.normal_enabled = true
	_mat_soporte.normal_texture = TEX_HERRAJE_NORMAL
	_mat_soporte.metallic = 0.65
	_mat_soporte.roughness = 0.45
	_mat_soporte.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_mat_foco = StandardMaterial3D.new()
	_mat_foco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_foco.vertex_color_use_as_albedo = true
	_mat_foco.albedo_color = Color(2.4, 2.4, 2.4, 1.0)

	_mesh_techo = _crear_malla_techo()
	_mesh_aplique = _crear_malla_aplique()
	_mesh_poste = _crear_malla_poste()


func _agregar_caja(st: SurfaceTool, centro: Vector3, tam: Vector3) -> void:
	var hx := tam.x * 0.5
	var hy := tam.y * 0.5
	var hz := tam.z * 0.5
	var caras := [
		{"n": Vector3(0, 1, 0), "p": [Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz)]},
		{"n": Vector3(0, -1, 0), "p": [Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz)]},
		{"n": Vector3(0, 0, 1), "p": [Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz)]},
		{"n": Vector3(0, 0, -1), "p": [Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, -hy, -hz)]},
		{"n": Vector3(1, 0, 0), "p": [Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz)]},
		{"n": Vector3(-1, 0, 0), "p": [Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz)]},
	]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for c in caras:
		var p: Array = c["p"]
		var n: Vector3 = c["n"]
		var cw_invertido: bool = (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0
		var indices: Array = [0, 2, 1, 0, 3, 2] if cw_invertido else [0, 1, 2, 0, 2, 3]
		for i in indices:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(centro + p[i])


func _crear_malla_techo() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st_sop := SurfaceTool.new()
	st_sop.begin(Mesh.PRIMITIVE_TRIANGLES)
	_agregar_caja(st_sop, Vector3(0.0, -0.08, 0.0), Vector3(0.08, 0.16, 0.08))
	_agregar_caja(st_sop, Vector3(0.0, -0.17, 0.0), Vector3(0.28, 0.05, 0.28))
	st_sop.commit(mesh)
	mesh.surface_set_material(0, _mat_soporte)

	var st_foco := SurfaceTool.new()
	st_foco.begin(Mesh.PRIMITIVE_TRIANGLES)
	_agregar_caja(st_foco, Vector3(0.0, -0.24, 0.0), Vector3(0.18, 0.12, 0.18))
	st_foco.commit(mesh)
	mesh.surface_set_material(1, _mat_foco)
	return mesh


func _crear_malla_aplique() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st_sop := SurfaceTool.new()
	st_sop.begin(Mesh.PRIMITIVE_TRIANGLES)
	_agregar_caja(st_sop, Vector3(0.0, 0.0, 0.04), Vector3(0.12, 0.18, 0.06))
	_agregar_caja(st_sop, Vector3(0.0, 0.03, 0.14), Vector3(0.06, 0.06, 0.18))
	st_sop.commit(mesh)
	mesh.surface_set_material(0, _mat_soporte)

	var st_foco := SurfaceTool.new()
	st_foco.begin(Mesh.PRIMITIVE_TRIANGLES)
	_agregar_caja(st_foco, Vector3(0.0, -0.04, 0.20), Vector3(0.14, 0.14, 0.14))
	st_foco.commit(mesh)
	mesh.surface_set_material(1, _mat_foco)
	return mesh


func _crear_malla_poste() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st_sop := SurfaceTool.new()
	st_sop.begin(Mesh.PRIMITIVE_TRIANGLES)
	_agregar_caja(st_sop, Vector3(0.0, 0.10, 0.0), Vector3(0.18, 0.20, 0.18))
	_agregar_caja(st_sop, Vector3(0.0, 1.35, 0.0), Vector3(0.10, 2.30, 0.10))
	_agregar_caja(st_sop, Vector3(0.0, 2.48, 0.16), Vector3(0.08, 0.08, 0.36))
	st_sop.commit(mesh)
	mesh.surface_set_material(0, _mat_soporte)

	var st_foco := SurfaceTool.new()
	st_foco.begin(Mesh.PRIMITIVE_TRIANGLES)
	_agregar_caja(st_foco, Vector3(0.0, 2.38, 0.30), Vector3(0.18, 0.18, 0.18))
	st_foco.commit(mesh)
	mesh.surface_set_material(1, _mat_foco)
	return mesh


func _configurar_multimeshes() -> void:
	_multi_techo = _crear_mmi("MultiTecho", _mesh_techo)
	_multi_aplique = _crear_mmi("MultiAplique", _mesh_aplique)
	_multi_poste = _crear_mmi("MultiPoste", _mesh_poste)


func _crear_mmi(nombre: String, malla: ArrayMesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nombre
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malla
	mm.instance_count = 0
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


func _configurar_pool_luces() -> void:
	for i in range(Ajustes.ALUMBRADO_POOL_LUCES):
		var luz := OmniLight3D.new()
		luz.name = "PoolLuz_%d" % i
		luz.shadow_enabled = false
		luz.omni_attenuation = 1.15
		luz.visible = false
		add_child(luz)
		_pool_luces.append(luz)


func _configurar_pool_clusters_y_halos() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = Ajustes.ALUMBRADO_HALO_RADIO_BASE
	esfera.height = Ajustes.ALUMBRADO_HALO_RADIO_BASE * 1.4
	esfera.radial_segments = 20
	esfera.rings = 10

	for i in range(Ajustes.ALUMBRADO_POOL_CLUSTERS):
		var luz_c := OmniLight3D.new()
		luz_c.name = "PoolCluster_%d" % i
		luz_c.shadow_enabled = false
		luz_c.omni_attenuation = 0.65
		luz_c.visible = false
		add_child(luz_c)
		_pool_clusters.append(luz_c)

		var halo := MeshInstance3D.new()
		halo.name = "PoolHalo_%d" % i
		halo.mesh = esfera
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat_h := ShaderMaterial.new()
		mat_h.shader = SHADER_HALO
		halo.material_override = mat_h
		halo.visible = false
		add_child(halo)
		_pool_halos.append(halo)


func marcar_sucio(_arg: Variant = null) -> void:
	_sucio = true


func _edificio_completado(id: int) -> bool:
	if not mundo.edificio_orden.has(id):
		return true
	var orden: Array = mundo.edificio_orden[id]
	var prog: int = int(mundo.edificio_progreso.get(id, 0))
	return prog >= orden.size()


func _es_bloque_estructural_solido(celda: Vector3i) -> bool:
	var t: String = mundo.obtener_tipo(celda)
	return t in ["adobe", "bloque_madera", "bloque_piedra", "estructura_hierro", "bloque_acero"]


func _calcular_aire_exterior_capa(y: int, celdas_set: Dictionary, mn: Vector3i, mx: Vector3i) -> Dictionary:
	var alcanzadas: Dictionary = {}
	var inicio := Vector2i(mn.x - 1, mn.z - 1)
	var pendientes: Array[Vector2i] = [inicio]
	alcanzadas[inicio] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not pendientes.is_empty():
		var act: Vector2i = pendientes.pop_back()
		for d in dirs:
			var nx: int = act.x + d.x
			var nz: int = act.y + d.y
			if nx < mn.x - 1 or nx > mx.x + 1 or nz < mn.z - 1 or nz > mx.z + 1:
				continue
			var key := Vector2i(nx, nz)
			if alcanzadas.has(key):
				continue
			if celdas_set.has(Vector3i(nx, y, nz)):
				continue
			alcanzadas[key] = true
			pendientes.append(key)
	return alcanzadas


func _es_aire_exterior_edificio(id_edif: int, celda_aire: Vector3i, edificios_cache: Dictionary) -> bool:
	if mundo.celda_a_edificio.has(celda_aire) or mundo.obtener_tipo(celda_aire) != "":
		return false
	if not edificios_cache.has(id_edif):
		return true
	var info: Dictionary = edificios_cache[id_edif]
	var mn: Vector3i = info["mn"]
	var mx: Vector3i = info["mx"]
	if celda_aire.x < mn.x or celda_aire.x > mx.x or celda_aire.z < mn.z or celda_aire.z > mx.z:
		return true
	var capas: Dictionary = info["capas"]
	var celdas_set: Dictionary = info["celdas_set"]
	if not capas.has(celda_aire.y):
		capas[celda_aire.y] = _calcular_aire_exterior_capa(celda_aire.y, celdas_set, mn, mx)
	var ext_y: Dictionary = capas[celda_aire.y]
	var col := Vector2i(celda_aire.x, celda_aire.z)
	if not ext_y.has(col):
		return false
	if celda_aire.y > mn.y + 1:
		var y_abajo: int = celda_aire.y - 1
		if not capas.has(y_abajo):
			capas[y_abajo] = _calcular_aire_exterior_capa(y_abajo, celdas_set, mn, mx)
		if not (capas[y_abajo] as Dictionary).has(col):
			return false
	return true


func _buscar_aplique_fachada_edificio(id_edif: int, origen: Vector3i, dir_afuera: Vector3i, edificios_cache: Dictionary) -> Dictionary:
	var tangente := Vector3i(-dir_afuera.z, 0, dir_afuera.x)
	var candidatos: Array[Vector3i] = [
		origen + Vector3i(0, 1, 0),
		origen,
	]
	for dy in [0, 1]:
		for step in [1, -1, 2, -2, 3, -3]:
			candidatos.append(origen + tangente * step + Vector3i(0, dy, 0))
	for b in candidatos:
		if mundo.id_de_edificio(b) != id_edif:
			continue
		if not _es_bloque_estructural_solido(b):
			continue
		var aire_afuera: Vector3i = b + dir_afuera
		if _es_aire_exterior_edificio(id_edif, aire_afuera, edificios_cache):
			return {"bloque": b, "aire": aire_afuera}
	return {}


func reconstruir_luminarias() -> void:
	_sucio = false
	luminarias.clear()
	_clusters.clear()
	if mundo == null:
		_sincronizar_multimeshes()
		return

	var dirs_cardinales: Array[Vector3i] = [
		Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)
	]
	var edificios_cache: Dictionary = {}

	for id: int in mundo.edificio_a_celdas:
		if not _edificio_completado(id):
			continue
		var celdas: Array = mundo.edificio_a_celdas[id]
		if celdas.is_empty():
			continue
		var vol: Dictionary = mundo.edificio_volumen.get(id, {})
		if vol.is_empty():
			continue
		var mn: Vector3i = vol["min"]
		var mx: Vector3i = vol["max"]
		var celdas_set: Dictionary = {}
		for c_ed: Vector3i in celdas:
			celdas_set[c_ed] = true
		edificios_cache[id] = {
			"celdas_set": celdas_set,
			"mn": mn,
			"mx": mx,
			"capas": {},
		}
		var centro_x: float = (float(mn.x) + float(mx.x) + 1.0) * 0.5
		var centro_z: float = (float(mn.z) + float(mx.z) + 1.0) * 0.5

		# 1. Exactamente 1 lampara de techo por cada techo interno (solo sobre bloque estructural solido)
		var candidatos_techo_por_y: Dictionary = {}
		for x in range(mn.x + 1, mx.x):
			for z in range(mn.z + 1, mx.z):
				for y in range(mn.y + 2, mx.y + 1):
					var c_techo := Vector3i(x, y, z)
					if _es_bloque_estructural_solido(c_techo) and mundo.obtener_tipo(c_techo + Vector3i(0, -1, 0)) == "":
						if not candidatos_techo_por_y.has(y):
							candidatos_techo_por_y[y] = []
						candidatos_techo_por_y[y].append(c_techo)

		if candidatos_techo_por_y.is_empty():
			# Fallback para edificios muy estrechos (3x3) buscando en toda la huella superior
			for c: Vector3i in celdas:
				if c.y == mx.y and _es_bloque_estructural_solido(c) and mundo.obtener_tipo(c + Vector3i(0, -1, 0)) == "":
					if not candidatos_techo_por_y.has(c.y):
						candidatos_techo_por_y[c.y] = []
					candidatos_techo_por_y[c.y].append(c)

		for y_t: int in candidatos_techo_por_y:
			var lista_t: Array = candidatos_techo_por_y[y_t]
			var mejor_c: Vector3i = lista_t[0]
			var mejor_d2: float = INF
			for c: Vector3i in lista_t:
				var dx: float = (float(c.x) + 0.5) - centro_x
				var dz: float = (float(c.z) + 0.5) - centro_z
				var d2: float = dx * dx + dz * dz
				if d2 < mejor_d2:
					mejor_d2 = d2
					mejor_c = c
			luminarias.append({
				"tipo": TipoLuminaria.TECHO,
				"celda": mejor_c + Vector3i(0, -1, 0),
				"pos": Vector3(float(mejor_c.x) + 0.5, float(mejor_c.y), float(mejor_c.z) + 0.5),
				"rot_y": 0.0,
			})

		# 2. Aplique exterior por puerta, siempre sobre bloque estructural solido (nunca puerta ni vidrio)
		for c: Vector3i in celdas:
			if mundo.obtener_tipo(c) != "puerta_superior":
				continue
			for d in dirs_cardinales:
				var fuera: Vector3i = c + d
				if _es_aire_exterior_edificio(id, fuera, edificios_cache):
					var res_apl := _buscar_aplique_fachada_edificio(id, c, d, edificios_cache)
					if not res_apl.is_empty():
						var b: Vector3i = res_apl["bloque"]
						var aire: Vector3i = res_apl["aire"]
						var rot_y := atan2(float(d.x), float(d.z))
						var pos_aplique := Vector3(float(b.x) + 0.5 + float(d.x) * 0.5, float(b.y) + 0.5, float(b.z) + 0.5 + float(d.z) * 0.5)
						luminarias.append({
							"tipo": TipoLuminaria.APLIQUE,
							"celda": aire,
							"pos": pos_aplique,
							"rot_y": rot_y,
						})
					break

	var vias := _vias()
	if vias != null and not vias.celdas.is_empty():
		var soportes: Array = vias.celdas.keys()
		soportes.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.x != b.x:
				return a.x < b.x
			if a.z != b.z:
				return a.z < b.z
			return a.y < b.y
		)
		var colocadas_vias: Array[Vector3i] = []
		var intervalo: int = Ajustes.ALUMBRADO_INTERVALO_VIAS
		for soporte: Vector3i in soportes:
			var vecinos_via := 0
			for d in dirs_cardinales:
				if vias.es_via(soporte + d) or vias.es_via(soporte + d + Vector3i(0, 1, 0)) or vias.es_via(soporte + d + Vector3i(0, -1, 0)):
					vecinos_via += 1
			var es_interseccion := vecinos_via >= 3
			var muy_cerca := false
			for prev: Vector3i in colocadas_vias:
				var dist_h: int = absi(soporte.x - prev.x) + absi(soporte.z - prev.z)
				if dist_h < (3 if es_interseccion else intervalo):
					muy_cerca = true
					break
			if muy_cerca:
				continue

			var puesta := false
			for d in dirs_cardinales:
				var pared_a: Vector3i = soporte + d + Vector3i(0, 2, 0)
				var pared_b: Vector3i = soporte + d + Vector3i(0, 1, 0)
				var id_edif: int = mundo.id_de_edificio(pared_a)
				var origen_fachada: Vector3i = pared_a
				if id_edif == -1:
					id_edif = mundo.id_de_edificio(pared_b)
					origen_fachada = pared_b + Vector3i(0, 1, 0)
				if id_edif != -1 and _edificio_completado(id_edif):
					var hacia_via := -d
					var res_via := _buscar_aplique_fachada_edificio(id_edif, origen_fachada, hacia_via, edificios_cache)
					if not res_via.is_empty():
						var bv: Vector3i = res_via["bloque"]
						var aire_v: Vector3i = res_via["aire"]
						var rot_y := atan2(float(hacia_via.x), float(hacia_via.z))
						var pos_apl := Vector3(
							float(bv.x) + 0.5 + float(hacia_via.x) * 0.5,
							float(bv.y) + 0.5,
							float(bv.z) + 0.5 + float(hacia_via.z) * 0.5
						)
						luminarias.append({
							"tipo": TipoLuminaria.APLIQUE,
							"celda": aire_v,
							"pos": pos_apl,
							"rot_y": rot_y,
						})
						colocadas_vias.append(soporte)
						puesta = true
						break

			if puesta:
				continue

			for d in dirs_cardinales:
				var lado: Vector3i = soporte + d
				if not vias.es_via(lado) and not vias.es_via(lado + Vector3i(0, 1, 0)) and mundo.obtener_tipo(lado + Vector3i(0, 1, 0)) == "":
					var hacia_via := -d
					var rot_y := atan2(float(hacia_via.x), float(hacia_via.z))
					var pos_poste := Vector3(
						float(soporte.x) + 0.5 + float(d.x) * 0.44,
						float(soporte.y) + 1.0,
						float(soporte.z) + 0.5 + float(d.z) * 0.44
					)
					luminarias.append({
						"tipo": TipoLuminaria.POSTE,
						"celda": soporte + Vector3i(0, 1, 0),
						"pos": pos_poste,
						"rot_y": rot_y,
					})
					colocadas_vias.append(soporte)
					break

	_construir_clusters()
	_sincronizar_multimeshes()


func _construir_clusters() -> void:
	var grupos: Dictionary = {}
	var tam: int = maxi(1, Ajustes.ALUMBRADO_TAMANO_CLUSTER)
	for lum in luminarias:
		var pos: Vector3 = lum["pos"]
		var cx := floori(pos.x / float(tam))
		var cz := floori(pos.z / float(tam))
		var key := Vector2i(cx, cz)
		if not grupos.has(key):
			grupos[key] = {"sum": Vector3.ZERO, "count": 0, "celda": lum["celda"]}
		grupos[key]["sum"] += pos
		grupos[key]["count"] += 1

	for key in grupos:
		var g: Dictionary = grupos[key]
		var cnt: int = g["count"]
		var centro: Vector3 = g["sum"] / float(cnt)
		centro.y += 7.5
		_clusters.append({
			"pos": centro,
			"celda": g["celda"],
			"count": cnt,
		})


func resolver_fuente_en(celda: Vector3i) -> String:
	var zon := _zonificacion()
	var en_red: bool = (zon != null and zon.dentro_de_influencia(Vector2i(celda.x, celda.z)))
	var econ := _economia()
	if en_red and econ != null:
		var balance: Dictionary = econ.balance_energia
		var cap: float = float(balance.get("capacidad", 0.0))
		var dem: float = float(balance.get("demanda", 0.0))
		var fac: float = float(balance.get("factor", 1.0))
		if cap > 0.0 and (dem <= 0.0 or fac > 0.0):
			return "electrica"

	var ciu := _ciudad()
	if ciu != null and ciu.almacen != null:
		for recurso in ["combustible", "carbon", "madera"]:
			if ciu.almacen.has(recurso) and ciu.almacen[recurso].cantidad > 0.0:
				return recurso
	return ""


func _esta_de_noche() -> bool:
	return atmosfera != null and atmosfera.has_method("es_de_noche") and atmosfera.es_de_noche()


func _esta_nevando() -> bool:
	return atmosfera != null and atmosfera.has_method("es_nevando") and atmosfera.es_nevando()


func debe_estar_encendido() -> bool:
	return _esta_de_noche() or _esta_nevando()


func multiplicador_consumo() -> float:
	if not debe_estar_encendido():
		return 0.0
	if _esta_nevando():
		return Ajustes.ALUMBRADO_MULTIPLICADOR_CONSUMO_NIEVE
	return 1.0


func simular_hora() -> void:
	if _sucio:
		reconstruir_luminarias()
	var mult: float = multiplicador_consumo()
	if mult <= 0.0:
		return
	var ciu := _ciudad()
	if ciu == null or ciu.almacen == null:
		return
	var consumo_por_recurso: Dictionary = {}
	for lum in luminarias:
		var fuente: String = resolver_fuente_en(lum["celda"])
		if fuente == "" or fuente == "electrica":
			continue
		var datos: Dictionary = Ajustes.ALUMBRADO_DATOS_FUENTE.get(fuente, {})
		var h_por_u: float = float(datos.get("horas_por_unidad", 0.0))
		if h_por_u <= 0.0:
			continue
		var gasto: float = (1.0 / (h_por_u * Ajustes.ALUMBRADO_RATIO_CONSUMO_AVATAR)) * mult
		consumo_por_recurso[fuente] = consumo_por_recurso.get(fuente, 0.0) + gasto

	for rec in consumo_por_recurso:
		if ciu.almacen.has(rec):
			ciu.almacen[rec].consumir(consumo_por_recurso[rec])


func _sincronizar_multimeshes() -> void:
	var techo_list: Array[Dictionary] = []
	var aplique_list: Array[Dictionary] = []
	var poste_list: Array[Dictionary] = []
	var encendido: bool = debe_estar_encendido()

	for lum in luminarias:
		var fuente: String = resolver_fuente_en(lum["celda"]) if encendido else ""
		var col := Color(0.18, 0.18, 0.20, 1.0)
		if encendido:
			if fuente != "":
				var datos: Dictionary = Ajustes.ALUMBRADO_DATOS_FUENTE.get(fuente, {})
				col = datos.get("color", Color.WHITE)
			else:
				col = Color(0.08, 0.08, 0.10, 1.0)
		var item := {"pos": lum["pos"], "rot_y": lum["rot_y"], "color": col}
		match lum["tipo"]:
			TipoLuminaria.TECHO:
				techo_list.append(item)
			TipoLuminaria.APLIQUE:
				aplique_list.append(item)
			TipoLuminaria.POSTE:
				poste_list.append(item)

	_volcar_multimesh(_multi_techo, techo_list)
	_volcar_multimesh(_multi_aplique, aplique_list)
	_volcar_multimesh(_multi_poste, poste_list)


func _volcar_multimesh(mmi: MultiMeshInstance3D, items: Array[Dictionary]) -> void:
	if mmi == null or mmi.multimesh == null:
		return
	var mm := mmi.multimesh
	mm.instance_count = items.size()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var xf := Transform3D(Basis(Vector3.UP, float(item["rot_y"])), item["pos"])
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, item["color"])


func actualizar_pool_luces(pos_camara: Vector3) -> void:
	if _sucio:
		reconstruir_luminarias()
	else:
		_sincronizar_multimeshes()

	if not debe_estar_encendido():
		for luz in _pool_luces:
			luz.visible = false
		for luz_c in _pool_clusters:
			luz_c.visible = false
		for halo in _pool_halos:
			halo.visible = false
		return

	# 1. Iluminación general por clústeres + halos de dispersión (cenital y 1ª persona lejana)
	var clusters_activos: Array[Dictionary] = []
	for cl in _clusters:
		var fuente_c: String = resolver_fuente_en(cl["celda"])
		if fuente_c == "":
			continue
		var datos_c: Dictionary = Ajustes.ALUMBRADO_DATOS_FUENTE.get(fuente_c, {})
		var dist: float = (cl["pos"] as Vector3).distance_to(pos_camara)
		clusters_activos.append({
			"pos": cl["pos"],
			"count": cl["count"],
			"color": datos_c.get("color", Color.WHITE),
			"dist": dist,
		})
	clusters_activos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["count"] > b["count"])

	for i in range(_pool_clusters.size()):
		var luz_c := _pool_clusters[i]
		var halo := _pool_halos[i]
		if i < clusters_activos.size():
			var cl_a: Dictionary = clusters_activos[i]
			var col_c: Color = cl_a["color"]
			luz_c.global_position = cl_a["pos"]
			luz_c.light_color = col_c
			if modo_cenital:
				luz_c.omni_range = Ajustes.ALUMBRADO_CLUSTER_RANGO_CENITAL
				luz_c.light_energy = Ajustes.ALUMBRADO_CLUSTER_ENERGIA_CENITAL
			else:
				var atenuar: float = 0.6 if cl_a["dist"] < 12.0 else 1.0
				luz_c.omni_range = Ajustes.ALUMBRADO_CLUSTER_RANGO_1P
				luz_c.light_energy = Ajustes.ALUMBRADO_CLUSTER_ENERGIA_1P * atenuar
			luz_c.visible = true

			halo.global_position = cl_a["pos"] - Vector3(0.0, 2.5, 0.0)
			var mat_h := halo.material_override as ShaderMaterial
			if mat_h != null:
				var intens: float = clampf(0.18 + float(cl_a["count"]) * 0.04, 0.18, 0.65) * Ajustes.ALUMBRADO_HALO_OPACIDAD_MAX
				mat_h.set_shader_parameter("glow_color", Vector3(col_c.r, col_c.g, col_c.b))
				mat_h.set_shader_parameter("intensity", intens)
			halo.visible = true
		else:
			luz_c.visible = false
			halo.visible = false

	# 2. Luces específicas cercanas solo en 1ª persona
	if modo_cenital:
		for luz in _pool_luces:
			luz.visible = false
		return

	var radio_max_sq: float = Ajustes.ALUMBRADO_RADIO_ESPECIFICO_1P * Ajustes.ALUMBRADO_RADIO_ESPECIFICO_1P
	var activas: Array[Dictionary] = []
	for lum in luminarias:
		var fuente: String = resolver_fuente_en(lum["celda"])
		if fuente == "":
			continue
		var d2: float = (lum["pos"] as Vector3).distance_squared_to(pos_camara)
		if d2 <= radio_max_sq:
			activas.append({"pos": lum["pos"], "fuente": fuente, "d2": d2})

	activas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d2"] < b["d2"])

	for i in range(_pool_luces.size()):
		var luz := _pool_luces[i]
		if i < activas.size():
			var item: Dictionary = activas[i]
			var datos: Dictionary = Ajustes.ALUMBRADO_DATOS_FUENTE.get(item["fuente"], {})
			luz.global_position = item["pos"]
			luz.light_color = datos.get("color", Color.WHITE)
			luz.omni_range = float(datos.get("rango", 10.0))
			luz.light_energy = float(datos.get("energia", 1.0))
			luz.visible = true
		else:
			luz.visible = false


func _process(delta: float) -> void:
	if _sucio:
		reconstruir_luminarias()
	_acumulador_pool += delta
	if _acumulador_pool < Ajustes.ALUMBRADO_INTERVALO_ACTUALIZACION_POOL_S:
		return
	_acumulador_pool = 0.0
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var pos_cam: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	actualizar_pool_luces(pos_cam)
