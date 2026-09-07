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

const ALTURA_SOBRE_SUPERFICIE := 0.05

@onready var mundo: Node = get_node("../VoxelWorld")


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
		# Sin prueba de profundidad: el relieve real puede tener bloques más
		# altos junto a una celda pintada más baja, tapándola desde ciertos
		# ángulos de la cámara oblicua — el overlay debe verse siempre, sin
		# importar qué haya delante desde el punto de vista actual.
		material.no_depth_test = true

		# La altura de la superficie varía con el relieve real del mundo (ver
		# GeneradorMundo/VoxelWorld._generar_terreno()) — un y fijo dejaba el
		# overlay enterrado bajo el terreno en casi toda el área, invisible
		# desde la cámara cenital.
		var altura_superficie: int = mundo.generador.altura_en(celda.x, celda.y)

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.position = Vector3(celda.x, altura_superficie + ALTURA_SOBRE_SUPERFICIE, celda.y)
		add_child(plano)
