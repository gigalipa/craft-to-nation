extends Node3D

## Overlay visual de las zonas pintadas (ver Zonificacion.gd, autoload). Un
## plano semitransparente por celda pintada, reconstruido por completo cada
## vez que cambia algo — la zona de influencia está acotada (a lo sumo unos
## cientos de celdas), así que reconstruir todo es más simple que llevar un
## registro incremental de qué celdas ya tienen su plano.

const COLOR_POR_ZONA := {
	"residencial_investigacion": Color(0.2, 0.4, 1.0, 0.4),
	"fabricacion_militar": Color(1.0, 0.5, 0.1, 0.4),
}


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()

	for celda in Zonificacion.zonas:
		var tipo: String = Zonificacion.zonas[celda]
		var color: Color = COLOR_POR_ZONA.get(tipo, Color.WHITE)

		var malla := PlaneMesh.new()
		malla.size = Vector2(1.0, 1.0)

		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.position = Vector3(celda.x, 0.05, celda.y)
		add_child(plano)
