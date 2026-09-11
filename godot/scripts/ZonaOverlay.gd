extends Node3D

## Overlay visual de las zonas pintadas (ver Zonificacion.gd, autoload). Un
## plano semitransparente por celda pintada, reconstruido por completo cada
## vez que cambia algo — la zona de influencia está acotada (a lo sumo unos
## cientos de celdas), así que reconstruir todo es más simple que llevar un
## registro incremental de qué celdas ya tienen su plano.

const COLOR_POR_ZONA := {
	"residencial_investigacion": Color(0.2, 0.4, 1.0, 0.15),
	"fabricacion_militar": Color(1.0, 0.5, 0.1, 0.15),
}

## Overlay visual pinta TODA la zona de influencia (rectángulo
## Zonificacion.influencia_min..max) en blanco, muy baja opacidad, sin
## importar si cada celda ya tiene una zona específica pintada encima.
const COLOR_ZONA_INFLUENCIA := Color(1.0, 1.0, 1.0, 0.02)

## Color de la previsualización cuando se está por BORRAR una zona (ver
## Zonificacion.MARCADOR_BORRAR) — gris translúcido, distinto de cualquier
## color real de zona, para que quede claro que esto quita, no pinta.
const COLOR_BORRAR := Color(0.5, 0.5, 0.5, 0.3)

const ALTURA_SOBRE_SUPERFICIE := 1.01
const DESF := 0.5

@onready var mundo: Node = get_node("../VoxelWorld")

## Planos de la previsualización en vivo de la zona que se está pintando
## (ver previsualizar()/limpiar_previsualizacion(), usados por CamaraCenital
## entre el primer y el segundo click). Se rastrean aparte del resto de
## hijos porque se recrean cada fotograma mientras el jugador mueve el
## mouse, sin pasar por reconstruir() completo (recorrer toda la zona de
## influencia cada fotograma sería más costoso de lo necesario).
var _planos_previsualizacion: Array[MeshInstance3D] = []


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_planos_previsualizacion.clear()

	if Zonificacion.nucleo_declarado:
		for x in range(Zonificacion.influencia_min.x, Zonificacion.influencia_max.x + 1):
			for z in range(Zonificacion.influencia_min.y, Zonificacion.influencia_max.y + 1):
				_agregar_plano(Vector2i(x, z), COLOR_ZONA_INFLUENCIA)

	for celda in Zonificacion.zonas:
		var tipo: String = Zonificacion.zonas[celda]
		var color: Color = COLOR_POR_ZONA.get(tipo, Color.WHITE)
		_agregar_plano(celda, color)


## Dibuja (sin modificar Zonificacion.zonas) el rectángulo entre "esquina_a"
## y "esquina_b" con el color de "tipo", recortado a la zona de influencia
## — misma lógica de recorte que Zonificacion.pintar_zona(), sin escribir
## nada todavía. Reemplaza cualquier previsualización anterior.
func previsualizar(esquina_a: Vector2i, esquina_b: Vector2i, tipo: String) -> void:
	limpiar_previsualizacion()
	var color: Color = COLOR_BORRAR if tipo == Zonificacion.MARCADOR_BORRAR else COLOR_POR_ZONA.get(tipo, Color.WHITE)

	var x_min: int = min(esquina_a.x, esquina_b.x)
	var x_max: int = max(esquina_a.x, esquina_b.x)
	var z_min: int = min(esquina_a.y, esquina_b.y)
	var z_max: int = max(esquina_a.y, esquina_b.y)

	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			var celda := Vector2i(x, z)
			if Zonificacion.dentro_de_influencia(celda):
				var plano: MeshInstance3D = _agregar_plano(celda, color)
				if plano != null:
					_planos_previsualizacion.append(plano)


func limpiar_previsualizacion() -> void:
	for plano in _planos_previsualizacion:
		plano.queue_free()
	_planos_previsualizacion.clear()


## Devuelve el MeshInstance3D creado, o null si la celda no se dibujó
## (superficie estructural — ver el chequeo de es_celda_estructural() más
## abajo). El valor de retorno solo lo usa previsualizar(), para poder
## limpiar exactamente sus propios planos sin tocar el resto de hijos.
func _agregar_plano(celda: Vector2i, color: Color) -> MeshInstance3D:
	# Altura REAL de la superficie (VoxelWorld.altura_en(), no
	# GeneradorMundo.altura_en()): esta última nunca se actualiza tras
	# minar/construir/nivelar, así que una celda ya modificada por el
	# jugador se pintaba a una altura "fantasma" que no correspondía a
	# ningún bloque real.
	var altura_superficie: int = mundo.altura_en(celda.x, celda.y, true)

	# El overlay de zona es SOLO para el terreno — nunca debe "pintar" el
	# techo/pared superior de un edificio (celda estructural colocada por el
	# jugador: pared/puerta/ventana/cama/baúl; un "piso" de relleno de
	# terreno NO cuenta como estructural, ver VoxelWorld.TIPOS_ESTRUCTURA).
	# Si la celda superior de esta columna pertenece a un edificio, no se
	# dibuja ningún plano aquí.
	if mundo.es_celda_estructural(Vector3i(celda.x, altura_superficie, celda.y)):
		return null

	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = false

	var plano := MeshInstance3D.new()
	plano.mesh = malla
	plano.material_override = material
	plano.position = Vector3(celda.x + DESF, altura_superficie + ALTURA_SOBRE_SUPERFICIE, celda.y + DESF)
	add_child(plano)
	return plano
