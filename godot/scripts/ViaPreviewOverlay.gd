extends Node3D

## Vista previa del trazador de vías (tecla V en CamaraCenital.gd) — un
## plano por columna del bloque delimitador de los vértices en curso,
## coloreado válido/inválido. Mismo patrón que ZonaOverlay.gd, pero
## efímero: nunca escribe en Vias.gd, solo se usa mientras el jugador
## traza.

const COLOR_VALIDO := Color(1.0, 0.85, 0.0, 0.4)
const COLOR_INVALIDO := Color(1.0, 0.2, 0.2, 0.4)
## 1.02, no 1.01 como ZonaOverlay.gd: con el mismo margen, ambos overlays
## quedaban coplanares en la vista cenital (mismo z-fighting que
## ViasRenderer.gd, ver su comentario en EPSILON_Y).
const ALTURA_SOBRE_SUPERFICIE := 1.02
const DESF := 0.5

@onready var mundo: Node = get_node("../VoxelWorld")

var _planos: Array[MeshInstance3D] = []


## "vertices" es el tramo en curso (origen + ruta hasta el cursor, sin
## deduplicar) — dibuja el rectángulo delimitador de cada paso consecutivo
## (más simple que el bloque 2x2 exacto de cada vértice, suficiente para
## la vista previa; la construcción real usa NiveladorVia.bloque_de_vertice()).
func previsualizar_tramo(vertices: Array[Vector2i], valido: bool) -> void:
	limpiar()
	if vertices.size() < 2:
		return
	var color: Color = COLOR_VALIDO if valido else COLOR_INVALIDO
	var columnas: Dictionary = {}  # Vector2i -> true, sin repetir plano
	for i in range(vertices.size() - 1):
		var a: Vector2i = vertices[i]
		var b: Vector2i = vertices[i + 1]
		for x in range(mini(a.x, b.x) - 1, maxi(a.x, b.x) + 1):
			for z in range(mini(a.y, b.y) - 1, maxi(a.y, b.y) + 1):
				columnas[Vector2i(x, z)] = true
	for col in columnas:
		_agregar_plano(col, color)


func limpiar() -> void:
	for plano in _planos:
		plano.queue_free()
	_planos.clear()


func _agregar_plano(col: Vector2i, color: Color) -> void:
	var altura_superficie: int = mundo.altura_en(col.x, col.y, true)
	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	# Por encima de ZonaOverlay.gd (prioridad 1-2) Y del overlay de vía ya
	# construida (mat_tierra_pisada.tres, prioridad 3) — la previsualización
	# activa siempre debe verse, sin importar qué haya debajo.
	material.render_priority = 4
	var plano := MeshInstance3D.new()
	plano.mesh = malla
	plano.material_override = material
	plano.position = Vector3(col.x + DESF, altura_superficie + ALTURA_SOBRE_SUPERFICIE, col.y + DESF)
	add_child(plano)
	_planos.append(plano)
