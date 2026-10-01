extends Node3D

## Indicador de actividad de las refinerías: una columna de humo sobre la chimenea (celda
## "chimenea" de Economia.puestos) mientras Economia.esta_refinando() sea verdadero. Cada refinería
## futura mostrará su actividad a su manera (acorde a su naturaleza); el humo es el de la siderúrgica.
##
## Hijo de VoxelWorld (en el origen, celdas de 1x1x1): coordenadas locales = coordenadas del mundo.
## Sin assets: la textura es un degradado radial (bola difusa). Para un humo mejor basta cambiar
## _crear_textura() por una textura cargada (p. ej. un paquete CC0 de humo); el resto no cambia.

const INTERVALO := 0.5  # segundos entre chequeos de las refinerías
const CANTIDAD := 28
const VIDA := 4.0

var _emisores: Dictionary = {}  # Vector2i (esquina del puesto) -> GPUParticles3D
var _acumulado := 0.0
var _material: ParticleProcessMaterial
var _malla: QuadMesh


func _ready() -> void:
	_material = _crear_material_particulas()
	_malla = QuadMesh.new()
	_malla.size = Vector2(1, 1)
	var material_malla := StandardMaterial3D.new()
	material_malla.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_malla.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_malla.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material_malla.vertex_color_use_as_albedo = true
	material_malla.albedo_texture = _crear_textura()
	_malla.material = material_malla


func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < INTERVALO:
		return
	_acumulado = 0.0
	actualizar()


## Crea los emisores de las refinerías nuevas, quita los de las que ya no existen y enciende o
## apaga el humo de cada una según Economia.esta_refinando().
func actualizar() -> void:
	var vivas := {}
	for esquina in Economia.puestos:
		var chimenea: Vector3i = Economia.puestos[esquina].get("chimenea", Economia.SIN_DEPOSITO)
		if chimenea == Economia.SIN_DEPOSITO or not Economia.es_refineria(esquina):
			continue
		vivas[esquina] = true
		if not _emisores.has(esquina):
			_emisores[esquina] = _crear_emisor(chimenea)
		_emisores[esquina].emitting = Economia.esta_refinando(esquina)
	for esquina in _emisores.keys():
		if not vivas.has(esquina):
			_emisores[esquina].queue_free()
			_emisores.erase(esquina)


func _crear_emisor(chimenea: Vector3i) -> GPUParticles3D:
	var particulas := GPUParticles3D.new()
	particulas.amount = CANTIDAD
	particulas.lifetime = VIDA
	particulas.process_material = _material
	particulas.draw_pass_1 = _malla
	particulas.emitting = false
	particulas.local_coords = false  # el humo ya emitido no sigue a la chimenea
	particulas.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	add_child(particulas)
	particulas.position = Vector3(chimenea.x + 0.5, chimenea.y + 1.0, chimenea.z + 0.5)
	return particulas


func _crear_material_particulas() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 12.0
	m.initial_velocity_min = 0.8
	m.initial_velocity_max = 1.3
	m.gravity = Vector3(0.25, 0.1, 0)  # una brisa leve y empuje hacia arriba
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.angular_velocity_min = -20.0
	m.angular_velocity_max = 20.0
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 1.5
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.15
	var crece := Curve.new()
	crece.add_point(Vector2(0, 0.6))
	crece.add_point(Vector2(1, 2.6))
	var curva := CurveTexture.new()
	curva.curve = crece
	m.scale_curve = curva
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	degradado.colors = PackedColorArray([Color(0.2, 0.2, 0.2, 0.0), Color(0.3, 0.3, 0.3, 0.55), Color(0.75, 0.75, 0.75, 0.0)])
	var rampa := GradientTexture1D.new()
	rampa.gradient = degradado
	m.color_ramp = rampa
	return m


## Bola difusa: opaca al centro y transparente en el borde.
func _crear_textura() -> GradientTexture2D:
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 1.0])
	degradado.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 64
	textura.height = 64
	return textura
