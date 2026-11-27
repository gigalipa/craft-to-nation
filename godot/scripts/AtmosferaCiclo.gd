extends Node3D

## Controlador de cielo procedural, ciclo mensual Día/Noche (360h / 360h) y clima dinámico.

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const SHADER_CIELO := preload("res://assets/shaders/cielo_procedural.gdshader")

enum EstadoClima { DESPEJADO, NUBLADO, LLUVIA, NIEVE }

signal fase_cambiada(es_noche: bool)
signal clima_cambiado(nuevo_estado: int)

@export var luz_solar: DirectionalLight3D
@export var world_env: WorldEnvironment

var estado_clima: int = EstadoClima.DESPEJADO
var horas_restantes_clima: float = 48.0

var cobertura_nubes_actual: float = 0.25
var _cobertura_nubes_objetivo: float = 0.25
var oscuridad_nubes_actual: float = 0.0
var _oscuridad_nubes_objetivo: float = 0.0
var niebla_actual: float = 0.0
var _niebla_objetivo: float = 0.0
var intensidad_nieve_actual: float = 0.0
var _intensidad_nieve_objetivo: float = 0.0

var _shader_mat: ShaderMaterial
var _env: Environment
var _particulas_lluvia: GPUParticles3D
var _particulas_nieve: GPUParticles3D
var _ultima_fase_noche: bool = false
var _tiempo_nubes: float = 0.0
var _hora_actual: float = 180.0


func _ready() -> void:
	_configurar_entorno()
	_configurar_particulas()
	if Ciudad != null and not Ciudad.tick_simulado.is_connected(_on_tick_simulado):
		Ciudad.tick_simulado.connect(_on_tick_simulado)
	var hora_ini: float = float(Ciudad.horas_juego) if Ciudad != null else 180.0
	_ultima_fase_noche = es_de_noche(hora_ini)
	establecer_clima(estado_clima, true)
	sincronizar_hora(hora_ini)


func _configurar_entorno() -> void:
	if world_env == null:
		world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = SHADER_CIELO

	var sky := Sky.new()
	sky.sky_material = _shader_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_sky_contribution = 0.85
	_env.glow_enabled = true
	_env.glow_intensity = Ajustes.GLOW_INTENSIDAD_ATMOSFERA
	_env.glow_bloom = 0.15
	_env.fog_enabled = true
	_env.fog_density = 0.0
	world_env.environment = _env

	if luz_solar == null and get_parent() != null:
		luz_solar = get_parent().get_node_or_null("Luz") as DirectionalLight3D


func _configurar_particulas() -> void:
	_particulas_lluvia = GPUParticles3D.new()
	_particulas_lluvia.name = "ParticulasLluvia"
	_particulas_lluvia.amount = 240
	_particulas_lluvia.lifetime = 0.85
	_particulas_lluvia.emitting = false
	_particulas_lluvia.visibility_aabb = AABB(Vector3(-24, -20, -24), Vector3(48, 40, 48))
	var mat_lluvia := ParticleProcessMaterial.new()
	mat_lluvia.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_lluvia.emission_box_extents = Vector3(18.0, 2.0, 18.0)
	mat_lluvia.direction = Vector3(0, -1, 0)
	mat_lluvia.spread = 4.0
	mat_lluvia.initial_velocity_min = 18.0
	mat_lluvia.initial_velocity_max = 22.0
	mat_lluvia.gravity = Vector3(0, -9.8, 0)
	_particulas_lluvia.process_material = mat_lluvia
	var mesh_lluvia := BoxMesh.new()
	mesh_lluvia.size = Vector3(0.025, 0.55, 0.025)
	var m_lluvia := StandardMaterial3D.new()
	m_lluvia.albedo_color = Color(0.65, 0.8, 0.98, 0.55)
	m_lluvia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_lluvia.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_lluvia.material = m_lluvia
	_particulas_lluvia.draw_pass_1 = mesh_lluvia
	add_child(_particulas_lluvia)

	_particulas_nieve = GPUParticles3D.new()
	_particulas_nieve.name = "ParticulasNieve"
	_particulas_nieve.amount = 180
	_particulas_nieve.lifetime = 2.8
	_particulas_nieve.emitting = false
	_particulas_nieve.visibility_aabb = AABB(Vector3(-24, -20, -24), Vector3(48, 40, 48))
	var mat_nieve := ParticleProcessMaterial.new()
	mat_nieve.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_nieve.emission_box_extents = Vector3(18.0, 2.0, 18.0)
	mat_nieve.direction = Vector3(0.15, -1, 0.08)
	mat_nieve.spread = 18.0
	mat_nieve.initial_velocity_min = 2.2
	mat_nieve.initial_velocity_max = 4.0
	mat_nieve.gravity = Vector3(0, -0.8, 0)
	_particulas_nieve.process_material = mat_nieve
	var mesh_nieve := BoxMesh.new()
	mesh_nieve.size = Vector3(0.08, 0.08, 0.08)
	var m_nieve := StandardMaterial3D.new()
	m_nieve.albedo_color = Color(0.95, 0.98, 1.0, 0.85)
	m_nieve.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_nieve.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_nieve.material = m_nieve
	_particulas_nieve.draw_pass_1 = mesh_nieve
	add_child(_particulas_nieve)


func es_de_noche(hora_consulta: float = -1.0) -> bool:
	var h: float = _hora_actual if hora_consulta < 0.0 else hora_consulta
	var ciclo: float = fposmod(h, Ajustes.CICLO_HORAS_MES)
	return ciclo >= Ajustes.CICLO_HORAS_DIA


func es_nevando() -> bool:
	return estado_clima == EstadoClima.NIEVE


func factor_luz_diurna(hora_consulta: float = -1.0) -> float:
	var h: float = _hora_actual if hora_consulta < 0.0 else hora_consulta
	var ciclo: float = fposmod(h, Ajustes.CICLO_HORAS_MES)
	if ciclo >= Ajustes.CICLO_HORAS_DIA:
		return 0.0
	var trans: float = Ajustes.CICLO_HORAS_TRANSICION_SOLAR
	if ciclo < trans:
		return clampf(ciclo / trans, 0.0, 1.0)
	if ciclo > Ajustes.CICLO_HORAS_DIA - trans:
		return clampf((Ajustes.CICLO_HORAS_DIA - ciclo) / trans, 0.0, 1.0)
	return 1.0


func obtener_nombre_clima() -> String:
	match estado_clima:
		EstadoClima.NUBLADO:
			return Strings.CLIMA_NUBLADO
		EstadoClima.LLUVIA:
			return Strings.CLIMA_LLUVIA
		EstadoClima.NIEVE:
			return Strings.CLIMA_NIEVE
		_:
			return Strings.CLIMA_DESPEJADO


func establecer_clima(nuevo_estado: int, inmediato: bool = false) -> void:
	estado_clima = clampi(nuevo_estado, EstadoClima.DESPEJADO, EstadoClima.NIEVE)
	match estado_clima:
		EstadoClima.DESPEJADO:
			_cobertura_nubes_objetivo = 0.22
			_oscuridad_nubes_objetivo = 0.0
			_niebla_objetivo = 0.0
			_intensidad_nieve_objetivo = 0.0
		EstadoClima.NUBLADO:
			_cobertura_nubes_objetivo = 0.72
			_oscuridad_nubes_objetivo = 0.35
			_niebla_objetivo = 0.0025
			_intensidad_nieve_objetivo = 0.0
		EstadoClima.LLUVIA:
			_cobertura_nubes_objetivo = 0.92
			_oscuridad_nubes_objetivo = 0.72
			_niebla_objetivo = 0.0065
			_intensidad_nieve_objetivo = 0.0
		EstadoClima.NIEVE:
			_cobertura_nubes_objetivo = 0.88
			_oscuridad_nubes_objetivo = 0.45
			_niebla_objetivo = 0.0085
			_intensidad_nieve_objetivo = 1.0

	if inmediato:
		cobertura_nubes_actual = _cobertura_nubes_objetivo
		oscuridad_nubes_actual = _oscuridad_nubes_objetivo
		niebla_actual = _niebla_objetivo
		intensidad_nieve_actual = _intensidad_nieve_objetivo
		_aplicar_uniforms_clima()

	if _particulas_lluvia != null:
		_particulas_lluvia.emitting = (estado_clima == EstadoClima.LLUVIA)
	if _particulas_nieve != null:
		_particulas_nieve.emitting = (estado_clima == EstadoClima.NIEVE)

	clima_cambiado.emit(estado_clima)


func _on_tick_simulado() -> void:
	if Ciudad != null:
		sincronizar_hora(float(Ciudad.horas_juego))
	horas_restantes_clima -= 1.0
	if horas_restantes_clima <= 0.0:
		horas_restantes_clima = float(randi_range(Ajustes.CLIMA_DURACION_MIN_HORAS, Ajustes.CLIMA_DURACION_MAX_HORAS))
		var siguiente := randi() % 4
		if siguiente == estado_clima:
			siguiente = (siguiente + 1) % 4
		establecer_clima(siguiente, false)


func sincronizar_hora(hora_juego: float) -> void:
	_hora_actual = hora_juego
	var noche: bool = es_de_noche(hora_juego)
	if noche != _ultima_fase_noche:
		_ultima_fase_noche = noche
		fase_cambiada.emit(noche)

	var ciclo: float = fposmod(hora_juego, Ajustes.CICLO_HORAS_MES)
	var angulo_solar: float = (ciclo / Ajustes.CICLO_HORAS_MES) * TAU
	var sun_dir := Vector3(cos(angulo_solar), sin(angulo_solar), 0.25).normalized()
	var day_f: float = factor_luz_diurna(hora_juego)
	var crepusculo: float = 1.0 - absf(day_f * 2.0 - 1.0) if not noche else 0.0

	var top_col := Ajustes.COLOR_CIELO_NOCHE_TOP.lerp(Ajustes.COLOR_CIELO_DIA_TOP, day_f)
	top_col = top_col.lerp(Ajustes.COLOR_CIELO_ATARDECER_TOP, crepusculo * 0.65)
	var hor_col := Ajustes.COLOR_CIELO_NOCHE_HORIZONTE.lerp(Ajustes.COLOR_CIELO_DIA_HORIZONTE, day_f)
	hor_col = hor_col.lerp(Ajustes.COLOR_CIELO_ATARDECER_HORIZONTE, crepusculo * 0.85)

	if _shader_mat != null:
		_shader_mat.set_shader_parameter("sun_direction", sun_dir)
		_shader_mat.set_shader_parameter("day_factor", day_f)
		_shader_mat.set_shader_parameter("star_visibility", 1.0 - day_f)
		_shader_mat.set_shader_parameter("sky_top_color", top_col)
		_shader_mat.set_shader_parameter("sky_horizon_color", hor_col)
		_shader_mat.set_shader_parameter("ground_color", Ajustes.COLOR_CIELO_SUELO)
		_shader_mat.set_shader_parameter("sun_color", Ajustes.COLOR_SOL)
		_shader_mat.set_shader_parameter("moon_color", Ajustes.COLOR_LUNA)

	if luz_solar != null:
		var dir_activa := sun_dir if not noche else -sun_dir
		if absf(dir_activa.y) < 0.08:
			dir_activa.y = 0.08
			dir_activa = dir_activa.normalized()
		luz_solar.look_at_from_position(dir_activa * 20.0, Vector3.ZERO, Vector3.UP)
		var energia_dia := Ajustes.LUZ_SOLAR_ENERGIA_MAX * day_f * (1.0 - oscuridad_nubes_actual * 0.45)
		var energia_noche := Ajustes.LUZ_LUNAR_ENERGIA * (1.0 - day_f)
		luz_solar.light_energy = maxf(energia_dia, energia_noche)
		luz_solar.light_color = Ajustes.COLOR_LUNA.lerp(hor_col.lerp(Color.WHITE, 0.6), day_f)

	if _env != null:
		_env.fog_light_color = hor_col


func _aplicar_uniforms_clima() -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("cloud_coverage", cobertura_nubes_actual)
		_shader_mat.set_shader_parameter("cloud_darkness", oscuridad_nubes_actual)
	if _env != null:
		_env.fog_density = niebla_actual
	RenderingServer.global_shader_parameter_set("intensidad_nieve", intensidad_nieve_actual)


func _process(delta: float) -> void:
	_tiempo_nubes += delta
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("time_offset", _tiempo_nubes)

	var t: float = clampf(delta * Ajustes.CLIMA_VELOCIDAD_TRANSICION, 0.0, 1.0)
	cobertura_nubes_actual = lerpf(cobertura_nubes_actual, _cobertura_nubes_objetivo, t)
	oscuridad_nubes_actual = lerpf(oscuridad_nubes_actual, _oscuridad_nubes_objetivo, t)
	niebla_actual = lerpf(niebla_actual, _niebla_objetivo, t)
	intensidad_nieve_actual = lerpf(intensidad_nieve_actual, _intensidad_nieve_objetivo, t)
	_aplicar_uniforms_clima()

	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		var pos_fx := cam.global_position + Vector3(0.0, 10.0, 0.0)
		if _particulas_lluvia != null:
			_particulas_lluvia.global_position = pos_fx
		if _particulas_nieve != null:
			_particulas_nieve.global_position = pos_fx


func exportar_estado() -> Dictionary:
	return {
		"estado_clima": estado_clima,
		"horas_restantes_clima": horas_restantes_clima,
		"intensidad_nieve_actual": intensidad_nieve_actual,
		"cobertura_nubes_actual": cobertura_nubes_actual,
	}


func importar_estado(d: Dictionary) -> void:
	if d.is_empty():
		return
	horas_restantes_clima = float(d.get("horas_restantes_clima", 48.0))
	establecer_clima(int(d.get("estado_clima", EstadoClima.DESPEJADO)), true)
	if d.has("intensidad_nieve_actual"):
		intensidad_nieve_actual = float(d["intensidad_nieve_actual"])
	if d.has("cobertura_nubes_actual"):
		cobertura_nubes_actual = float(d["cobertura_nubes_actual"])
	_aplicar_uniforms_clima()
	var hora_ini: float = float(Ciudad.horas_juego) if Ciudad != null else _hora_actual
	sincronizar_hora(hora_ini)
