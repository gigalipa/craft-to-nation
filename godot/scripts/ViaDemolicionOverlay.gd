extends Node3D

## Previsualización guiada en color naranja para el trazado de demolición de vías
## (tecla 3 en CamaraCenital al apuntar a una vía construida) y overlay con outline naranja
## persistente para vías con orden de demolición confirmada.

const COLOR_DEMOLICION_VIA := Color(1.0, 0.5, 0.0, 0.45)
const COLOR_OUTLINE_DEMOLICION := Color(1.0, 0.5, 0.0, 0.95)
const ALTURA_SOBRE_SUPERFICIE := 1.03
const EPSILON_Y_OUTLINE := 0.035
const DESF := 0.5
const PRIORIDAD_OUTLINE := 5

@onready var mundo: Node = get_node_or_null("../VoxelWorld")

var obras: Object = null:
	set(valor):
		if obras != null:
			if obras.demolicion_via_creada.is_connected(_on_demolicion_cambiada):
				obras.demolicion_via_creada.disconnect(_on_demolicion_cambiada)
			if obras.demolicion_via_paso.is_connected(_on_demolicion_paso):
				obras.demolicion_via_paso.disconnect(_on_demolicion_paso)
			if obras.demolicion_via_completada.is_connected(_on_demolicion_cambiada):
				obras.demolicion_via_completada.disconnect(_on_demolicion_cambiada)
		obras = valor
		if obras != null:
			obras.demolicion_via_creada.connect(_on_demolicion_cambiada)
			obras.demolicion_via_paso.connect(_on_demolicion_paso)
			obras.demolicion_via_completada.connect(_on_demolicion_cambiada)
		_asegurar_outline_instance()
		reconstruir_outline()

var _planos: Array[MeshInstance3D] = []
var cantidad_celdas: int = 0
var celdas_seleccionadas: Array[Vector3i] = []

var _outline_instance: MeshInstance3D = null
var _material_outline: StandardMaterial3D = null


func _init() -> void:
	_material_outline = StandardMaterial3D.new()
	_material_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_outline.albedo_color = COLOR_OUTLINE_DEMOLICION
	_material_outline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_outline.render_priority = PRIORIDAD_OUTLINE


func _ready() -> void:
	if obras == null and has_node("/root/Obras"):
		obras = get_node("/root/Obras")
	_asegurar_outline_instance()
	reconstruir_outline()


func _asegurar_outline_instance() -> void:
	if _outline_instance == null:
		_outline_instance = MeshInstance3D.new()
		_outline_instance.material_override = _material_outline
		add_child(_outline_instance)


func _on_demolicion_cambiada(_id_dem: int) -> void:
	reconstruir_outline()


func _on_demolicion_paso(_id_dem: int, _celda: Vector3i) -> void:
	reconstruir_outline()


func reconstruir_outline() -> void:
	if _outline_instance == null:
		return
	if obras == null:
		_outline_instance.mesh = null
		return
	var celdas: Array[Vector3i] = obras.todas_las_celdas_demolicion_vias()
	if celdas.is_empty():
		_outline_instance.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for celda in celdas:
		var x := float(celda.x)
		var y := float(celda.y) + 1.0 + EPSILON_Y_OUTLINE
		var z := float(celda.z)
		var p0 := Vector3(x, y, z)
		var p1 := Vector3(x + 1.0, y, z)
		var p2 := Vector3(x + 1.0, y, z + 1.0)
		var p3 := Vector3(x, y, z + 1.0)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p1)
		st.add_vertex(p2)
		st.add_vertex(p2)
		st.add_vertex(p3)
		st.add_vertex(p3)
		st.add_vertex(p0)
	_outline_instance.mesh = st.commit()


func mostrar_tramo(celdas: Array) -> void:
	limpiar()
	for item in celdas:
		var celda: Vector3i = item as Vector3i
		celdas_seleccionadas.append(celda)
		_agregar_plano(celda)
	cantidad_celdas = celdas_seleccionadas.size()


func limpiar() -> void:
	cantidad_celdas = 0
	celdas_seleccionadas.clear()
	for plano in _planos:
		if plano.get_parent() == self:
			remove_child(plano)
		plano.queue_free()
	_planos.clear()


func _agregar_plano(celda: Vector3i) -> void:
	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR_DEMOLICION_VIA
	material.render_priority = 4
	var plano := MeshInstance3D.new()
	plano.mesh = malla
	plano.material_override = material
	plano.position = Vector3(celda.x + DESF, celda.y + ALTURA_SOBRE_SUPERFICIE, celda.z + DESF)
	add_child(plano)
	_planos.append(plano)
