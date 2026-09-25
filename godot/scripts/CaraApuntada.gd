extends MeshInstance3D

## Overlay verde translúcido y brillante sobre la cara del bloque que apunta el
## raycast del avatar (1ª persona). Player lo muestra solo si el raycast golpea
## algo — su largo (5 bloques) es el alcance de colocar y minar — y lo oculta si
## no. Es un quad de 1x1: sobre piezas que no son un cubo entero (puerta,
## ventana) no ajusta perfecto.

const COLOR := Color(0.3, 1.0, 0.45, 0.38)
## Separación respecto a la cara, para evitar el parpadeo por profundidad.
const DESFASE := 0.01
const VELOCIDAD_PULSO := 4.0

var _material := StandardMaterial3D.new()
var _tiempo := 0.0


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh = quad
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = COLOR
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true  # su transform es siempre global, aunque cuelgue del avatar
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_tiempo += delta
	_material.albedo_color.a = COLOR.a + 0.15 * sin(_tiempo * VELOCIDAD_PULSO)


## "centro_cara" es el centro de la cara (global); "normal" apunta hacia afuera del bloque.
func mostrar_en(centro_cara: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	var arriba := Vector3.UP if absf(n.y) < 0.99 else Vector3.FORWARD
	# El quad mira hacia +Z; looking_at() apunta -Z, así que se le pasa -n.
	global_transform = Transform3D(Basis.looking_at(-n, arriba), centro_cara + n * DESFASE)
	visible = true


func ocultar() -> void:
	visible = false
