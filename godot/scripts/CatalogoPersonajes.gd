extends RefCounted

## Catálogo modular de personajes 3D, equipamiento por oficio, paletas de piel
## y color de equipo, con cachés compartidos de escenas y materiales.
## Funciona de forma 100 % plug-and-play: cuando aún no existe un .glb en disco,
## resuelve limpiamente el nivel anterior de fallback (atuendo -> base -> placeholder).

const Ajustes = preload("res://scripts/ajustes.gd")

const RUTA_BASE := "res://assets/personajes/base/"
const RUTA_ATUENDOS := "res://assets/personajes/atuendos/"
const RUTA_EQUIPAMIENTO := "res://assets/personajes/equipamiento/"
const RUTA_ANIMACIONES := "res://assets/personajes/animaciones/humanoide_base.glb"
const RUTA_AVATAR_M := "res://assets/personajes/avatar/avatar.glb"
const RUTA_AVATAR_F := "res://assets/personajes/avatar/avatar_f.glb"

## Huesos candidatos por slot lógico (SkeletonProfileHumanoid de Godot 4).
const SLOTS_HUESO := {
	"Head": ["Head"],
	"Chest": ["Chest", "UpperChest", "Spine"],
	"RightHand": ["RightHand"],
	"LeftHand": ["LeftHand"],
}

static var _cache_escenas: Dictionary = {}  # ruta -> PackedScene
static var _cache_mat_piel: Dictionary = {}  # clave -> StandardMaterial3D
static var _cache_mat_equipo: Dictionary = {}  # clave -> StandardMaterial3D
static var _cache_anim_lib: AnimationLibrary = null
static var _cache_anim_buscada := false


static func limpiar_caches() -> void:
	_cache_escenas.clear()
	_cache_mat_piel.clear()
	_cache_mat_equipo.clear()
	_cache_anim_lib = null
	_cache_anim_buscada = false


static func normalizar_genero(genero: String) -> String:
	return "F" if genero.strip_edges().to_upper() == "F" else "M"


static func sufijo_genero(genero: String) -> String:
	return "f" if normalizar_genero(genero) == "F" else "m"


static func normalizar_tono_piel(tono: int) -> int:
	if Ajustes.TONOS_PIEL_COLONOS.is_empty():
		return 0
	return clampi(tono, 0, Ajustes.TONOS_PIEL_COLONOS.size() - 1)


static func color_piel(tono: int) -> Color:
	if Ajustes.TONOS_PIEL_COLONOS.is_empty():
		return Ajustes.COLOR_PIEL_COLONO
	return Ajustes.TONOS_PIEL_COLONOS[normalizar_tono_piel(tono)]


static func _existe_recurso(ruta: String, existe_fn: Callable = Callable()) -> bool:
	if ruta.is_empty():
		return false
	if existe_fn.is_valid():
		return bool(existe_fn.call(ruta))
	return ResourceLoader.exists(ruta)


## Resuelve la Capa 1 (atuendo por rango + género -> cuerpo base por género -> placeholder).
static func resolver_modelo_capa1(rango: String, genero: String, existe_fn: Callable = Callable()) -> Dictionary:
	var g_suf := sufijo_genero(genero)
	var rango_limpio := rango.strip_edges().to_lower()
	if rango_limpio.is_empty():
		rango_limpio = "desempleado"
	var ruta_atuendo := "%s%s_%s.glb" % [RUTA_ATUENDOS, rango_limpio, g_suf]
	var ruta_base := "%s%s_%s.glb" % [RUTA_BASE, "cuerpo", g_suf]
	var tiene_base := _existe_recurso(ruta_base, existe_fn)
	if _existe_recurso(ruta_atuendo, existe_fn):
		return {
			"modo": "atuendo",
			"ruta_atuendo": ruta_atuendo,
			"ruta_base": ruta_base if tiene_base else "",
		}
	if tiene_base:
		return {
			"modo": "base",
			"ruta_atuendo": "",
			"ruta_base": ruta_base,
		}
	return {
		"modo": "placeholder",
		"ruta_atuendo": "",
		"ruta_base": "",
	}


static func resolver_ruta_equipamiento(pieza_id: String, existe_fn: Callable = Callable()) -> String:
	if pieza_id.is_empty():
		return ""
	var ruta := "%s%s.glb" % [RUTA_EQUIPAMIENTO, pieza_id]
	return ruta if _existe_recurso(ruta, existe_fn) else ""


## Resuelve la Capa 2 (slot -> pieza rígida) a partir del oficio, rol, tarea y tipo de puesto.
static func resolver_equipamiento(colono: Dictionary, tipo_puesto: String = "", _era: int = 1) -> Dictionary:
	var tipo := str(colono.get("tipo", "desempleado")).strip_edges().to_lower()
	if tipo == "militar":
		if str(colono.get("subtipo_militar", "")).to_lower() == "arquero":
			return {"Head": "casco_militar", "LeftHand": "arco"}
		return {"Head": "casco_militar", "RightHand": "espada", "LeftHand": "escudo"}

	var tarea: Dictionary = colono.get("tarea", {}) if colono.get("tarea", {}) is Dictionary else {}
	if str(tarea.get("tipo", "")) == "investigador_itinerante":
		return {"LeftHand": "maletin_ciencia"}
	if not tarea.is_empty():
		return {"RightHand": "martillo"}

	var trabajo: Dictionary = colono.get("trabajo", {}) if colono.get("trabajo", {}) is Dictionary else {}
	if not trabajo.is_empty():
		if str(trabajo.get("rol", "")) == "acarreador":
			return {"Chest": "canasta_acarreo"}
		match tipo_puesto.strip_edges().to_lower():
			"mina":
				return {"Head": "casco_minero", "RightHand": "pico"}
			"centro_extraccion":
				return {"Head": "casco_minero", "RightHand": "martillo"}
			"maderero", "aserradero":
				return {"RightHand": "hacha"}
			"caza_recoleccion":
				return {"LeftHand": "arco_caza"}
			"pesca_frutos_mar":
				return {"RightHand": "cana_pesca"}
			"siderurgica", "refineria_tierras_raras", "fabrica_bloques", "vidriera", "carbonera", "refineria_petrolera", "productor_combustible", "central_termoelectrica", "estacion_bombeo", "taller_transporte":
				return {"Head": "gafas_industriales", "RightHand": "martillo"}
			"escuela_tecnica", "escuela_especialistas", "universidad":
				return {"LeftHand": "maletin_ciencia"}
			"cuartel":
				return {"Head": "casco_militar"}
			"almacen":
				return {"Chest": "canasta_acarreo"}
			_:
				return {}
	return {}


static func cargar_escena_cacheada(ruta: String) -> PackedScene:
	if ruta.is_empty():
		return null
	if _cache_escenas.has(ruta):
		return _cache_escenas[ruta] as PackedScene
	if not ResourceLoader.exists(ruta):
		return null
	var rec: Resource = ResourceLoader.load(ruta)
	if rec is PackedScene:
		_cache_escenas[ruta] = rec
		return rec as PackedScene
	return null


static func obtener_biblioteca_animaciones() -> AnimationLibrary:
	if _cache_anim_buscada:
		return _cache_anim_lib
	_cache_anim_buscada = true
	var escena := cargar_escena_cacheada(RUTA_ANIMACIONES)
	if escena == null:
		return null
	var inst := escena.instantiate()
	var ap := buscar_nodo_por_clase(inst, "AnimationPlayer") as AnimationPlayer
	if ap != null:
		var lib := AnimationLibrary.new()
		for anim_name: StringName in ap.get_animation_list():
			var anim := ap.get_animation(anim_name)
			if anim != null:
				lib.add_animation(anim_name, anim)
		_cache_anim_lib = lib
	inst.queue_free()
	return _cache_anim_lib


static func obtener_material_piel(base_mat: Material, tono_piel: int) -> StandardMaterial3D:
	var tono := normalizar_tono_piel(tono_piel)
	var nombre_orig := base_mat.resource_name if base_mat != null else "mat_piel"
	var base_id := str(base_mat.get_meta("ct_base_mat_id", base_mat.get_instance_id())) if base_mat != null else "default_piel"
	var clave := "%s|%d" % [base_id, tono]
	if _cache_mat_piel.has(clave):
		return _cache_mat_piel[clave] as StandardMaterial3D
	var mat_out: StandardMaterial3D
	if base_mat is StandardMaterial3D:
		mat_out = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		mat_out = StandardMaterial3D.new()
	mat_out.resource_name = nombre_orig if not nombre_orig.is_empty() else "mat_piel"
	mat_out.set_meta("ct_base_mat_id", base_id)
	mat_out.albedo_color = color_piel(tono)
	_cache_mat_piel[clave] = mat_out
	return mat_out


static func obtener_material_equipo(base_mat: Material, color_equipo: Color) -> StandardMaterial3D:
	var nombre_orig := base_mat.resource_name if base_mat != null else "mat_color_equipo"
	var base_id := str(base_mat.get_meta("ct_base_mat_id", base_mat.get_instance_id())) if base_mat != null else "default_equipo"
	var clave := "%s|%s" % [base_id, color_equipo.to_html(false)]
	if _cache_mat_equipo.has(clave):
		return _cache_mat_equipo[clave] as StandardMaterial3D
	var mat_out: StandardMaterial3D
	if base_mat is StandardMaterial3D:
		mat_out = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		mat_out = StandardMaterial3D.new()
	mat_out.resource_name = nombre_orig if not nombre_orig.is_empty() else "mat_color_equipo"
	mat_out.set_meta("ct_base_mat_id", base_id)
	mat_out.albedo_color = color_equipo
	_cache_mat_equipo[clave] = mat_out
	return mat_out


## Recorre los MeshInstance3D bajo "raiz" y aplica overrides cacheados a los slots
## nombrados con prefijo "mat_piel"/"skin" o "mat_color_equipo"/"team_color".
static func aplicar_materiales_identidad(raiz: Node, tono_piel: int, color_equipo: Color) -> Dictionary:
	var conteo := {"piel": 0, "equipo": 0}
	if raiz == null:
		return conteo
	var pila: Array[Node] = [raiz]
	while not pila.is_empty():
		var actual: Node = pila.pop_back()
		if actual is MeshInstance3D:
			var mi := actual as MeshInstance3D
			if mi.mesh != null:
				for i in range(mi.mesh.get_surface_count()):
					var mat_base: Material = mi.get_surface_override_material(i)
					if mat_base == null:
						mat_base = mi.mesh.surface_get_material(i)
					if mat_base == null:
						continue
					var nombre := mat_base.resource_name.strip_edges().to_lower()
					if nombre.begins_with("mat_piel") or nombre.begins_with("skin"):
						mi.set_surface_override_material(i, obtener_material_piel(mat_base, tono_piel))
						conteo["piel"] = int(conteo["piel"]) + 1
					elif nombre.begins_with("mat_color_equipo") or nombre.begins_with("team_color"):
						mi.set_surface_override_material(i, obtener_material_equipo(mat_base, color_equipo))
						conteo["equipo"] = int(conteo["equipo"]) + 1
		for hijo in actual.get_children():
			pila.append(hijo)
	return conteo


static func buscar_nodo_por_clase(raiz: Node, clase: String) -> Node:
	if raiz == null:
		return null
	if raiz.get_class() == clase or raiz.is_class(clase):
		return raiz
	for hijo in raiz.get_children():
		var hallado := buscar_nodo_por_clase(hijo, clase)
		if hallado != null:
			return hallado
	return null
