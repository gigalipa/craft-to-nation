extends Node

## Pruebas automatizadas del Sistema Modular de Personajes 3D:
## - Identidad persistente en Colonos.gd y retrocompatibilidad de saves
## - Resolución Capa 1 y Capa 2 en CatalogoPersonajes.gd
## - Materiales dinámicos (4 tonos de piel + color de equipo) con caché
## - PersonajeModular.gd + ColonosRenderer.gd con assets reales y transiciones de rol
## - Regla de género en Elecciones / Sucesión del Avatar y seguro anti-bloqueo
## - Integración con AvatarAnimador / Player.tscn

const Ajustes = preload("res://scripts/ajustes.gd")
const CatalogoPersonajes = preload("res://scripts/CatalogoPersonajes.gd")
const PersonajeModularScript = preload("res://scripts/PersonajeModular.gd")
const ColonosRendererScript = preload("res://scripts/ColonosRenderer.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const PlayerScene = preload("res://scenes/Player.tscn")
const CLIPS_TRABAJO := [
	"Fishing_Cast",
	"Hauler_Box_Idle",
	"Hauler_Carry",
	"Heavy_Swing",
	"Idle",
	"Mining_Dig",
	"Walking",
	"Work_Table",
]


func _ready() -> void:
	ejecutar_pruebas()
	CatalogoPersonajes.limpiar_caches()
	Colonos.reiniciar()
	Ciudad.reiniciar()
	Economia.reiniciar()
	print("Todas las pruebas pasaron correctamente.")
	get_tree().quit(0)


func ejecutar_pruebas() -> void:
	test_identidad_persistente_y_legacy()
	test_catalogo_capa1_y_capa2()
	test_animaciones_por_oficio_y_canasta_dinamica()
	test_equipamiento_real_instanciable()
	test_materiales_piel_y_equipo_en_malla_sintetica()
	test_biblioteca_animaciones_trabajo()
	test_colonos_renderer_modular_assets_reales()
	test_sucesion_genero_y_antibloqueo()
	test_avatar_animador_identidad_y_manos()


func test_identidad_persistente_y_legacy() -> void:
	print("=== TEST 1: Identidad persistente en Colonos y migración legacy ===")
	Colonos.reiniciar()
	var id_rand: int = Colonos.agregar_colono("desempleado", Vector3i(2, 1, 2), -1)
	var c_rand: Dictionary = Colonos.colonos[id_rand]
	assert(c_rand.get("genero", "") in ["M", "F"], "genero aleatorio válido")
	assert(int(c_rand.get("tono_piel", -1)) >= 0 and int(c_rand.get("tono_piel", -1)) <= 3, "tono_piel en 0..3")
	assert(str(c_rand.get("equipo_id", "")) == "jugador", "equipo_id por defecto")
	assert(is_equal_approx(float(c_rand.get("orientacion_y", -99.0)), 0.0), "orientacion_y inicial")

	var id_exp: int = Colonos.agregar_colono("obrero", Vector3i(3, 1, 3), -1, {
		"genero": "F",
		"tono_piel": 3,
		"equipo_id": "rojo_carmesi",
	})
	var c_exp: Dictionary = Colonos.colonos[id_exp]
	assert(c_exp["genero"] == "F" and int(c_exp["tono_piel"]) == 3 and c_exp["equipo_id"] == "rojo_carmesi")

	# Cambio de rango manual preserva identidad
	c_exp["tipo"] = "tecnico"
	assert(c_exp["genero"] == "F" and int(c_exp["tono_piel"]) == 3, "cambio de rango conserva genero y tono_piel")

	# Migración de save legacy sin campos nuevos
	Colonos.importar_estado({
		"siguiente_id": 5,
		"colonos": {
			"4": {
				"id": 4,
				"tipo": "obrero",
				"hogar": -1,
				"celda": {"x": 1, "y": 1, "z": 1},
				"posicion": {"x": 1.5, "y": 1.0, "z": 1.5},
				"ruta": [],
			}
		}
	})
	assert(Colonos.colonos[4]["genero"] in ["M", "F"], "save legacy migra genero")
	assert(int(Colonos.colonos[4]["tono_piel"]) >= 0 and int(Colonos.colonos[4]["tono_piel"]) <= 3, "save legacy migra tono_piel")
	assert(Colonos.colonos[4]["equipo_id"] == "jugador", "save legacy migra equipo_id")


func test_catalogo_capa1_y_capa2() -> void:
	print("=== TEST 2: Resolución Capa 1 y Capa 2 en CatalogoPersonajes ===")
	var fn_todo := func(ruta: String) -> bool:
		return ruta.ends_with("tecnico_f.glb") or ruta.ends_with("cuerpo_f.glb")
	var r1: Dictionary = CatalogoPersonajes.resolver_modelo_capa1("tecnico", "F", fn_todo)
	assert(r1["modo"] == "atuendo" and str(r1["ruta_atuendo"]).ends_with("tecnico_f.glb"), "prioridad 1 = atuendo")

	var r2: Dictionary = CatalogoPersonajes.resolver_modelo_capa1("obrero", "F", fn_todo)
	assert(r2["modo"] == "base" and str(r2["ruta_base"]).ends_with("cuerpo_f.glb"), "prioridad 2 = cuerpo base")

	var fn_nada := func(_ruta: String) -> bool: return false
	var r3: Dictionary = CatalogoPersonajes.resolver_modelo_capa1("obrero", "M", fn_nada)
	assert(r3["modo"] == "placeholder", "prioridad 3 = placeholder")

	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "desempleado", "tarea": {}, "trabajo": {}}) == {})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "obrero", "tarea": {"id": 1, "tipo": "construir"}, "trabajo": {}}) == {"RightHand": "martillo"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "acarreador"}, "moviendo": false, "carga": {}}) == {"RightHand": "canasta_acarreo"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "tecnico", "tarea": {}, "trabajo": {"rol": "recolector"}}, "mina") == {"Head": "casco_minero", "RightHand": "pico"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "recolector"}}, "maderero") == {"RightHand": "hacha"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "recolector"}}, "caza_recoleccion") == {"LeftHand": "arco_caza"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "recolector"}}, "pesca_frutos_mar") == {"RightHand": "cana_pesca"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "especialista", "tarea": {}, "trabajo": {"rol": "recolector"}}, "siderurgica") == {"Head": "gafas_industriales", "RightHand": "martillo"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "investigador", "tarea": {"tipo": "investigador_itinerante"}, "trabajo": {}}) == {"LeftHand": "maletin_ciencia"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "militar", "tarea": {}, "trabajo": {}}) == {"Head": "casco_militar", "RightHand": "espada", "LeftHand": "escudo"})
	assert(CatalogoPersonajes.resolver_equipamiento({"tipo": "militar", "subtipo_militar": "arquero", "tarea": {}, "trabajo": {}}) == {"Head": "casco_militar", "LeftHand": "arco"})


func test_animaciones_por_oficio_y_canasta_dinamica() -> void:
	print("=== TEST 3: Animaciones por oficio y canasta dinámica ===")
	var base := {"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "recolector"}, "moviendo": false, "carga": {}}
	var casos := [
		{"nombre": "acarreador cargado en movimiento", "colono": {"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "acarreador"}, "moviendo": true, "carga": {"madera": 1}}, "puesto": "almacen", "esperado": ["Hauler_Carry"]},
		{"nombre": "caminante común", "colono": {"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "recolector"}, "moviendo": true, "carga": {}}, "puesto": "mina", "esperado": ["Walking"]},
		{"nombre": "acarreador quieto y vacío", "colono": {"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "acarreador"}, "moviendo": false, "carga": {}}, "puesto": "almacen", "esperado": ["Hauler_Box_Idle"]},
		{"nombre": "mina", "colono": base, "puesto": "mina", "esperado": ["Mining_Dig", "Heavy_Swing"]},
		{"nombre": "pesca", "colono": base, "puesto": "pesca_frutos_mar", "esperado": ["Fishing_Cast"]},
		{"nombre": "maderero", "colono": base, "puesto": "maderero", "esperado": ["Heavy_Swing"]},
		{"nombre": "caza y recolección", "colono": base, "puesto": "caza_recoleccion", "esperado": ["Work_Table"]},
		{"nombre": "construcción", "colono": {"tipo": "obrero", "tarea": {"tipo": "construir"}, "trabajo": {}, "moviendo": false, "carga": {}}, "puesto": "", "esperado": ["Heavy_Swing"]},
		{"nombre": "fallback", "colono": {"tipo": "desempleado", "tarea": {}, "trabajo": {}, "moviendo": false, "carga": {}}, "puesto": "", "esperado": ["Idle"]},
	]
	var industriales := ["aserradero", "siderurgica", "refineria_tierras_raras", "fabrica_bloques", "vidriera", "carbonera", "refineria_petrolera", "productor_combustible", "central_termoelectrica", "estacion_bombeo", "taller_transporte"]
	for puesto in industriales:
		casos.append({"nombre": "industrial " + puesto, "colono": base, "puesto": puesto, "esperado": ["Work_Table"]})
	for caso in casos:
		var recibido: Array[String] = CatalogoPersonajes.resolver_animaciones(caso["colono"], caso["puesto"])
		assert(recibido == caso["esperado"], "%s: esperado=%s recibido=%s" % [caso["nombre"], caso["esperado"], recibido])

	var acarreador_quieto := {"tipo": "obrero", "tarea": {}, "trabajo": {"rol": "acarreador"}, "moviendo": false, "carga": {}}
	var acarreador_moviendose := acarreador_quieto.duplicate(true)
	acarreador_moviendose["moviendo"] = true
	var acarreador_cargado := acarreador_quieto.duplicate(true)
	acarreador_cargado["carga"] = {"piedra": 1}
	assert(CatalogoPersonajes.resolver_equipamiento(acarreador_quieto) == {"RightHand": "canasta_acarreo"})
	assert(CatalogoPersonajes.resolver_equipamiento(acarreador_moviendose) == {"Chest": "canasta_acarreo"})
	assert(CatalogoPersonajes.resolver_equipamiento(acarreador_cargado) == {"Chest": "canasta_acarreo"})
	var ajuste_manos := CatalogoPersonajes.ajuste_equipamiento("canasta_acarreo", "RightHand")
	var ajuste_espalda := CatalogoPersonajes.ajuste_equipamiento("canasta_acarreo", "Chest")
	assert(not ajuste_manos.is_equal_approx(Transform3D.IDENTITY), "la canasta en manos requiere offset")
	assert(not ajuste_espalda.is_equal_approx(Transform3D.IDENTITY), "la canasta en espalda requiere offset")
	assert(not ajuste_manos.is_equal_approx(ajuste_espalda), "los dos usos comparten GLB pero no ajuste")


func test_equipamiento_real_instanciable() -> void:
	print("=== TEST 3: Props reales y slots de equipamiento ===")
	var piezas := {
		"martillo": "RightHand",
		"pico": "RightHand",
		"hacha": "RightHand",
		"canasta_acarreo": "Chest",
	}
	for pieza_id in piezas:
		var ruta := CatalogoPersonajes.resolver_ruta_equipamiento(pieza_id)
		assert(not ruta.is_empty(), "%s resuelve una ruta real para %s" % [pieza_id, piezas[pieza_id]])
		var escena := CatalogoPersonajes.cargar_escena_cacheada(ruta)
		assert(escena != null, "%s carga como PackedScene" % pieza_id)
		var instancia := escena.instantiate()
		assert(instancia is Node3D, "%s se instancia como Node3D" % pieza_id)
		instancia.free()


func test_materiales_piel_y_equipo_en_malla_sintetica() -> void:
	print("=== TEST 3: Materiales dinámicos mat_piel y mat_color_equipo con caché ===")
	CatalogoPersonajes.limpiar_caches()
	var m_piel := BoxMesh.new()
	var mat_piel := StandardMaterial3D.new()
	mat_piel.resource_name = "mat_piel"
	m_piel.material = mat_piel

	var m_eq := BoxMesh.new()
	var mat_eq := StandardMaterial3D.new()
	mat_eq.resource_name = "mat_color_equipo.001"
	m_eq.material = mat_eq

	var raiz_a := _crear_malla_sintetica(m_piel, m_eq)
	var raiz_b := _crear_malla_sintetica(m_piel, m_eq)
	var color_rojo := Color("#c93838")

	var res_a: Dictionary = CatalogoPersonajes.aplicar_materiales_identidad(raiz_a, 3, color_rojo)
	var res_b: Dictionary = CatalogoPersonajes.aplicar_materiales_identidad(raiz_b, 3, color_rojo)
	assert(res_a["piel"] == 1 and res_a["equipo"] == 1, "debe detectar mat_piel y mat_color_equipo.001")
	assert(res_b["piel"] == 1 and res_b["equipo"] == 1)

	var mi_piel_a := raiz_a.get_node("Piel") as MeshInstance3D
	var mi_eq_a := raiz_a.get_node("Equipo") as MeshInstance3D
	var mi_piel_b := raiz_b.get_node("Piel") as MeshInstance3D
	var mat_piel_a := mi_piel_a.get_surface_override_material(0) as StandardMaterial3D
	var mat_eq_a := mi_eq_a.get_surface_override_material(0) as StandardMaterial3D
	var mat_piel_b := mi_piel_b.get_surface_override_material(0) as StandardMaterial3D
	assert(mat_piel_a != null and mat_piel_a.albedo_color.is_equal_approx(Ajustes.TONOS_PIEL_COLONOS[3]), "tono de piel oscuro aplicado")
	assert(mat_eq_a != null and mat_eq_a.albedo_color.is_equal_approx(color_rojo), "color de equipo aplicado")
	assert(mat_piel_a == mat_piel_b, "materiales idénticos comparten instancia cacheada")

	# Reaplicar otro tono actualiza sin perder el prefijo
	CatalogoPersonajes.aplicar_materiales_identidad(raiz_a, 0, Color("#2e8f57"))
	assert((mi_piel_a.get_surface_override_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Ajustes.TONOS_PIEL_COLONOS[0]))
	assert((mi_eq_a.get_surface_override_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color("#2e8f57")))
	raiz_a.free()
	raiz_b.free()


func _crear_malla_sintetica(m_piel: Mesh, m_eq: Mesh) -> Node3D:
	var raiz := Node3D.new()
	var mi_piel := MeshInstance3D.new()
	mi_piel.name = "Piel"
	mi_piel.mesh = m_piel
	raiz.add_child(mi_piel)

	var mi_eq := MeshInstance3D.new()
	mi_eq.name = "Equipo"
	mi_eq.mesh = m_eq
	raiz.add_child(mi_eq)
	return raiz


func test_biblioteca_animaciones_trabajo() -> void:
	print("=== TEST 4: Biblioteca compartida de animaciones de trabajo ===")
	CatalogoPersonajes.limpiar_caches()
	var biblioteca: AnimationLibrary = CatalogoPersonajes.obtener_biblioteca_animaciones()
	assert(biblioteca != null, "humanoide_base.glb carga una AnimationLibrary")
	var nombres: Array[String] = []
	for nombre in biblioteca.get_animation_list():
		nombres.append(str(nombre))
	nombres.sort()
	assert(nombres == CLIPS_TRABAJO, "clips esperados=%s recibidos=%s" % [CLIPS_TRABAJO, nombres])


func test_colonos_renderer_modular_assets_reales() -> void:
	print("=== TEST 4: ColonosRenderer + PersonajeModular y cambio dinámico de oficio ===")
	Ciudad.reiniciar()
	Colonos.reiniciar()
	Economia.reiniciar()
	Ciudad.establecer_color_equipo(Color("#d4a437"))

	var esq_mina := Vector2i(15, 15)
	Economia.puestos[esq_mina] = {"tipo": "mina"}
	var cid: int = Colonos.agregar_colono("desempleado", Vector3i(5, 1, 5), -1, {"genero": "M", "tono_piel": 2})

	var rend: Node3D = ColonosRendererScript.new()
	add_child(rend)
	rend._physics_process(0.016)

	var cuerpo: AnimatableBody3D = rend._cuerpos.get(cid, null)
	var modular: Node3D = rend._modulares.get(cid, null)
	assert(cuerpo != null and modular != null, "ColonosRenderer crea PersonajeModular")
	assert(modular.modo_visual() == "base", "desempleado usa cuerpo base real")
	assert(modular.equipamiento_logico() == {}, "desempleado sin equipamiento")

	# Asignar obrero carga el atuendo con chaleco.
	Colonos.colonos[cid]["tipo"] = "obrero"
	rend._physics_process(0.016)
	assert(modular.modo_visual() == "atuendo", "obrero usa atuendo real")

	# Asignar técnico minero
	Colonos.colonos[cid]["tipo"] = "tecnico"
	Colonos.colonos[cid]["trabajo"] = {"puesto": esq_mina, "rol": "recolector"}
	rend._physics_process(0.016)
	assert(modular.modo_visual() == "base", "tecnico sin atuendo propio usa cuerpo base")
	assert(modular.equipamiento_logico() == {"Head": "casco_minero", "RightHand": "pico"}, "tecnico + mina combina capa 1 y capa 2")

	# Cambiar a militar
	Colonos.colonos[cid]["tipo"] = "militar"
	Colonos.colonos[cid]["trabajo"] = {}
	rend._physics_process(0.016)
	assert(modular.modo_visual() == "base", "militar sin atuendo propio usa cuerpo base")
	assert(modular.equipamiento_logico() == {"Head": "casco_militar", "RightHand": "espada", "LeftHand": "escudo"})

	rend.queue_free()


func test_sucesion_genero_y_antibloqueo() -> void:
	print("=== TEST 5: Regla de género en Elecciones / Sucesión + seguro anti-bloqueo ===")
	Ciudad.reiniciar()
	Colonos.reiniciar()
	Ciudad.registrar_edificio_residencial(1, [2])
	Ciudad.registrar_cuartel(2, 4)
	Ciudad.demografia["obrero"] = 1
	Ciudad.demografia["militar"] = 3

	var id_f: int = Colonos.agregar_colono("militar", Vector3i(2, 1, 2), -1, {"genero": "F", "tono_piel": 0})
	var id_m: int = Colonos.agregar_colono("militar", Vector3i(3, 1, 2), -1, {"genero": "M", "tono_piel": 2})
	var id_m2: int = Colonos.agregar_colono("militar", Vector3i(4, 1, 2), -1, {"genero": "M", "tono_piel": 3})

	# Avatar M debe elegir entre militares M (y respetar id menor si misma salud)
	Ciudad.genero_avatar = "M"
	var res1: String = Ciudad.suceder_avatar(Colonos)
	assert(res1 == "sucesion_exitosa")
	assert(not Colonos.colonos.has(id_m), "debe retirarse el candidato masculino elegible")
	assert(Colonos.colonos.has(id_f) and Colonos.colonos.has(id_m2), "la candidata femenina no es retirada para avatar M")
	assert(Ciudad.tono_piel_avatar == 2, "avatar hereda tono_piel del sucesor elegido")
	assert(Ciudad.ultimo_resultado_sucesion.get("origen", "") == "candidato_mismo_genero")

	# Ahora avatar F con 1 candidata F disponible
	Ciudad.genero_avatar = "F"
	var res2: String = Ciudad.suceder_avatar(Colonos)
	assert(res2 == "sucesion_exitosa")
	assert(not Colonos.colonos.has(id_f), "ahora elige a la candidata femenina")
	assert(Ciudad.tono_piel_avatar == 0)

	# Ahora queda 1 militar M (id_m2) y 0 candidatas F -> seguro anti-bloqueo
	Ciudad.genero_avatar = "F"
	var res3: String = Ciudad.suceder_avatar(Colonos)
	assert(res3 == "sucesion_exitosa", "seguro anti-bloqueo impide atasco si hay militares del género opuesto")
	assert(Ciudad.genero_avatar == "F", "el avatar conserva su género")
	assert(Ciudad.demografia["militar"] == 0)
	assert(Ciudad.ultimo_resultado_sucesion.get("origen", "") == "relevo_nucleo_antibloqueo")
	assert(not Colonos.colonos.has(id_m2), "retira militar de respaldo para mantener paridad de censo")

	# Sin militares disponibles -> sin_sucesor_elegible
	var res4: String = Ciudad.suceder_avatar(Colonos)
	assert(res4 == "sin_sucesor_elegible")


func test_avatar_animador_identidad_y_manos() -> void:
	print("=== TEST 6: AvatarAnimador identidad visual y equipamiento sin assets ===")
	var ctx_raiz := Node3D.new()
	add_child(ctx_raiz)
	var hud: CanvasLayer = HUDScript.new()
	hud.name = "HUDLayer"
	ctx_raiz.add_child(hud)
	var player: Player = PlayerScene.instantiate() as Player
	ctx_raiz.add_child(player)
	var animador := player.animador_avatar()
	assert(animador != null)
	var res_mat := animador.aplicar_identidad_visual(2, Color("#2e8f57"))
	assert(res_mat.has("piel") and res_mat.has("equipo"))
	assert(not animador.equipar_en_mano("derecha", "espada", 2, Color("#2e8f57")), "sin espada.glb retorna false limpiamente sin fallar")
	assert(animador.equipar_en_mano("derecha", "", 2, Color("#2e8f57")), "limpiar mano derecha retorna true")
	ctx_raiz.queue_free()
