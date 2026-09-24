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

## Overlay visual pinta TODA la zona de influencia real (la unión de la
## caja de cada edificio — ver Zonificacion.dentro_de_influencia(), no
## necesariamente el rectángulo Zonificacion.influencia_min..max completo)
## en blanco, muy baja opacidad, sin importar si cada celda ya tiene una
## zona específica pintada encima.
const COLOR_ZONA_INFLUENCIA := Color(1.0, 1.0, 1.0, 0.02)

## Color de la previsualización cuando se está por BORRAR una zona (ver
## Zonificacion.MARCADOR_BORRAR) — gris translúcido, distinto de cualquier
## color real de zona, para que quede claro que esto quita, no pinta.
const COLOR_BORRAR := Color(0.5, 0.5, 0.5, 0.3)

const ALTURA_SOBRE_SUPERFICIE := 1.01
const DESF := 0.5

## Dos planos distintos pueden coincidir en la MISMA celda a la MISMA
## altura (una celda con zona pintada lleva su plano de zona de
## influencia Y su plano de zona específica encima, ver reconstruir()) —
## sin diferenciar su render_priority, competían entre sí por transparencia
## (reportado jugando en vivo, 2026-09-23, junto con la pelea contra el
## overlay de vías: ver su propio render_priority más alto en
## ViasRenderer.gd/ViaPreviewOverlay.gd, que debe quedar por encima de
## AMBOS). La zona específica (A/B/borrar) siempre se ve por encima de la
## zona de influencia, que es solo un tinte de fondo.
const PRIORIDAD_INFLUENCIA := 1
const PRIORIDAD_ZONA := 2

const ViasRenderer = preload("res://scripts/ViasRenderer.gd")

@onready var mundo: Node = get_node("../VoxelWorld")

## Pool de planos de la previsualización en vivo de la zona que se está
## pintando (ver previsualizar()/limpiar_previsualizacion(), usados por
## CamaraCenital entre el primer y el segundo click, una vez por fotograma
## mientras el jugador mueve el mouse). Se reutilizan de un fotograma al
## siguiente en vez de destruir y recrear cada MeshInstance3D — con un
## rectángulo grande (más de la mitad de la zona de influencia, cientos de
## celdas) recrear todo cada fotograma se sentía como una ralentización
## progresiva al "estirar" la selección (reportado jugando en vivo,
## 2026-09-23). Los planos sobrantes de un fotograma con menos celdas que el
## anterior solo se ocultan (visible = false), no se liberan: vuelven a
## usarse si la selección vuelve a crecer.
var _planos_previsualizacion: Array[MeshInstance3D] = []
var _usados_previsualizacion := 0

## Malla compartida por todos los planos (todos miden 1x1) y caché de
## materiales por color — evita crear un PlaneMesh y un StandardMaterial3D
## nuevos por celda y por fotograma (ver _obtener_material()).
var _malla_plano: PlaneMesh
var _materiales: Dictionary = {}

## Caché de altura_en()/es_celda_estructural()/TIPOS_CUNA por celda (Vector2i
## -> [altura_superficie, dibuja]), válida solo DENTRO de una misma sesión de
## previsualizar() (el terreno no cambia mientras se arrastra la selección:
## zonificación es un modo excluyente con nivelar/construir/minar). Sin esto,
## con la selección "estirada" sobre terreno con árboles (troncos y follaje
## apilados), altura_en() debe saltar cada bloque de árbol en CADA celda y EN
## CADA FOTOGRAMA — el pool de nodos ya evita recrear la geometría, pero no
## evita repetir esa búsqueda (reportado jugando en vivo, 2026-09-23: seguía
## notándose sobre todo al pintar zonas con árboles). Se limpia al iniciar una
## nueva selección (ver previsualizar()) y en reconstruir(), que se llama
## tras cualquier cambio real de terreno.
var _cache_altura: Dictionary = {}


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_planos_previsualizacion.clear()
	_cache_altura.clear()

	if Zonificacion.nucleo_declarado:
		# influencia_min/max es solo la caja delimitadora de TODA la zona
		# (para acotar este recorrido) — la forma real es la unión de la
		# caja de cada edificio, así que cada celda se confirma por
		# separado con dentro_de_influencia() en vez de pintar el
		# rectángulo completo (que dejaría de reflejar la forma real).
		for x in range(Zonificacion.influencia_min.x, Zonificacion.influencia_max.x + 1):
			for z in range(Zonificacion.influencia_min.y, Zonificacion.influencia_max.y + 1):
				var celda := Vector2i(x, z)
				if Zonificacion.dentro_de_influencia(celda):
					_agregar_plano(celda, COLOR_ZONA_INFLUENCIA, PRIORIDAD_INFLUENCIA)

	for celda in Zonificacion.zonas:
		var tipo: String = Zonificacion.zonas[celda]
		var color: Color = COLOR_POR_ZONA.get(tipo, Color.WHITE)
		_agregar_plano(celda, color, PRIORIDAD_ZONA)


## Dibuja (sin modificar Zonificacion.zonas) el rectángulo entre "esquina_a"
## y "esquina_b" con el color de "tipo", recortado a la zona de influencia
## — misma lógica de recorte que Zonificacion.pintar_zona(), sin escribir
## nada todavía. Reemplaza cualquier previsualización anterior.
func previsualizar(esquina_a: Vector2i, esquina_b: Vector2i, tipo: String) -> void:
	if esquina_a == esquina_b:
		_cache_altura.clear()  # primer click: arranca una nueva sesión de selección
	var color: Color = COLOR_BORRAR if tipo == Zonificacion.MARCADOR_BORRAR else COLOR_POR_ZONA.get(tipo, Color.WHITE)

	var x_min: int = min(esquina_a.x, esquina_b.x)
	var x_max: int = max(esquina_a.x, esquina_b.x)
	var z_min: int = min(esquina_a.y, esquina_b.y)
	var z_max: int = max(esquina_a.y, esquina_b.y)

	_usados_previsualizacion = 0
	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			var celda := Vector2i(x, z)
			if Zonificacion.dentro_de_influencia(celda):
				_dibujar_plano_pool(celda, color, PRIORIDAD_ZONA)

	for i in range(_usados_previsualizacion, _planos_previsualizacion.size()):
		_planos_previsualizacion[i].visible = false


## Dibuja (o reutiliza) el plano en "_planos_previsualizacion[_usados_previsualizacion]"
## para "celda"; lo deja oculto y no cuenta como usado si la celda no se
## dibuja (superficie estructural o cuña de vía, igual que _agregar_plano()).
func _dibujar_plano_pool(celda: Vector2i, color: Color, prioridad: int) -> void:
	if not _cache_altura.has(celda):
		var altura: int = mundo.altura_en(celda.x, celda.y, true)
		var columna := Vector3i(celda.x, altura, celda.y)
		var dibuja: bool = not mundo.es_celda_estructural(columna) and not ViasRenderer.TIPOS_CUNA.has(mundo.obtener_tipo(columna))
		_cache_altura[celda] = [altura, dibuja]
	var entrada: Array = _cache_altura[celda]
	var altura_superficie: int = entrada[0]
	if not entrada[1]:
		return

	var plano: MeshInstance3D
	if _usados_previsualizacion < _planos_previsualizacion.size():
		plano = _planos_previsualizacion[_usados_previsualizacion]
	else:
		plano = MeshInstance3D.new()
		plano.mesh = _malla_compartida()
		add_child(plano)
		_planos_previsualizacion.append(plano)

	plano.material_override = _obtener_material(color, prioridad)
	plano.position = Vector3(celda.x + DESF, altura_superficie + ALTURA_SOBRE_SUPERFICIE, celda.y + DESF)
	plano.visible = true
	_usados_previsualizacion += 1


func limpiar_previsualizacion() -> void:
	for plano in _planos_previsualizacion:
		plano.queue_free()
	_planos_previsualizacion.clear()
	_usados_previsualizacion = 0


func _malla_compartida() -> PlaneMesh:
	if _malla_plano == null:
		_malla_plano = PlaneMesh.new()
		_malla_plano.size = Vector2(1.0, 1.0)
	return _malla_plano


func _obtener_material(color: Color, prioridad: int) -> StandardMaterial3D:
	var clave := "%s|%d" % [color, prioridad]
	if not _materiales.has(clave):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.no_depth_test = false
		material.render_priority = prioridad
		_materiales[clave] = material
	return _materiales[clave]


## Devuelve el MeshInstance3D creado, o null si la celda no se dibujó
## (superficie estructural — ver el chequeo de es_celda_estructural() más
## abajo). El valor de retorno solo lo usa previsualizar(), para poder
## limpiar exactamente sus propios planos sin tocar el resto de hijos.
func _agregar_plano(celda: Vector2i, color: Color, prioridad: int = PRIORIDAD_ZONA) -> MeshInstance3D:
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

	# Mismo motivo que TIPOS_CUNA en ViasRenderer.gd: la superficie de una
	# cuña de vía (rampa/diagonal) ya es la cara visible de esa columna —
	# el tinte de zona pintado encima quedaba flotando sobre la rampa en
	# vez de ocultarse detrás de su geometría (reportado jugando en vivo,
	# 2026-09-23: el plano de zona SIEMPRE se dibuja por encima de la caja
	# delimitadora de la celda, sin importar la profundidad real de una
	# superficie inclinada dentro de esa caja).
	if ViasRenderer.TIPOS_CUNA.has(mundo.obtener_tipo(Vector3i(celda.x, altura_superficie, celda.y))):
		return null

	# El orden de dibujo entre dos superficies translúcidas casi coplanares
	# NO lo decide de forma confiable un margen de altura mínimo (el
	# ordenamiento por transparencia de Godot es por distancia a la cámara,
	# no por altura — con la cenital en ángulo, ambos criterios no siempre
	# coinciden). Ver PRIORIDAD_INFLUENCIA/PRIORIDAD_ZONA más arriba; el
	# overlay de vías (ViasRenderer.gd/ViaPreviewOverlay.gd) usa un
	# render_priority más alto todavía, para quedar siempre por encima de
	# AMBOS sin importar el ángulo de cámara.
	var plano := MeshInstance3D.new()
	plano.mesh = _malla_compartida()
	plano.material_override = _obtener_material(color, prioridad)
	plano.position = Vector3(celda.x + DESF, altura_superficie + ALTURA_SOBRE_SUPERFICIE, celda.y + DESF)
	add_child(plano)
	return plano
