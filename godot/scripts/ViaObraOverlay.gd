extends MeshInstance3D

## Overlay de contorno guía (wireframe en suelo) para celdas de vías con obra pendiente.
## Dibuja únicamente los bordes de cada celda para diferenciarse de los overlays rellenos
## (zonificación, demolición, etc.).

const COLOR_CONTORNO := Color(1.0, 0.85, 0.2, 0.9)
const EPSILON_Y := 0.03
const PRIORIDAD := 4

var obras: Object = null:
	set(valor):
		if obras != null:
			if obras.obra_via_creada.is_connected(_on_obra_cambiada):
				obras.obra_via_creada.disconnect(_on_obra_cambiada)
			if obras.obra_via_paso.is_connected(_on_obra_paso):
				obras.obra_via_paso.disconnect(_on_obra_paso)
			if obras.obra_via_completada.is_connected(_on_obra_cambiada):
				obras.obra_via_completada.disconnect(_on_obra_cambiada)
		obras = valor
		if obras != null:
			obras.obra_via_creada.connect(_on_obra_cambiada)
			obras.obra_via_paso.connect(_on_obra_paso)
			obras.obra_via_completada.connect(_on_obra_cambiada)
		reconstruir()

var _material: StandardMaterial3D


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = COLOR_CONTORNO
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.render_priority = PRIORIDAD
	material_override = _material


func _ready() -> void:
	if obras == null and has_node("/root/Obras"):
		obras = get_node("/root/Obras")
	reconstruir()


func _on_obra_cambiada(_id_via: int) -> void:
	reconstruir()


func _on_obra_paso(_id_via: int, _celda: Vector3i) -> void:
	reconstruir()


func reconstruir() -> void:
	if obras == null:
		mesh = null
		return
	var celdas: Array[Vector3i] = obras.todas_las_celdas_obras_vias()
	if celdas.is_empty():
		mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for celda in celdas:
		var x := float(celda.x)
		var y := float(celda.y) + 1.0 + EPSILON_Y
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
	mesh = st.commit()
