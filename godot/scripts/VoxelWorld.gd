extends GridMap

## Mundo voxel acotado sobre GridMap + MeshLibrary (assets/BlockLibrary.res,
## generada desde scenes/BlockLibrarySource.tscn). Reemplaza la versión previa
## de celdas por código (MeshInstance3D/StaticBody3D manuales) ahora que el
## editor de Godot está disponible para exportar la MeshLibrary.

const TAMANO_CELDA := 1.0

const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")
const GeneradorArbol = preload("res://scripts/GeneradorArbol.gd")
const MATERIAL_AGUA := preload("res://assets/mat_agua.tres")

const ANCHO_MUNDO := 200
const LARGO_MUNDO := 200

## Cuántas celdas de subsuelo cava cada columna bajo SU PROPIA superficie
## (relativo, no un piso absoluto — ver 2026-09-16, PoC_6 3.15): un piso
## absoluto fijo en y = ALTURA_MINIMA - PROFUNDIDAD_SUBSUELO se probó
## primero (fondo plano de verdad), pero con ALTURA_MAXIMA = 130 y un
## relieve que ya no baja de ~50 en casi ningún punto del mundo real, un
## piso absoluto obliga a cavar ~90-130 celdas por columna sin importar cuán
## chico sea este número — 6.3 millones de celdas sólidas en total, que
## revientan un límite interno de GridMap de Godot (overflow de índice,
## crash reproducido con y sin GPU). Cavar relativo a la superficie desacopla
## el volumen total de la altura del terreno (siempre ANCHO×LARGO×(este+1)
## celdas, aquí 1 millón) — y como el relieve ya es suave (ver
## GeneradorMundo._ruido.frequency), el fondo resultante también sale
## razonablemente uniforme, sin ser un piso perfectamente plano.
const PROFUNDIDAD_SUBSUELO := 24

const SEMILLA_MUNDO := 12345

## Umbral de densidad_arbol_en() (rango [0,1]) por encima del cual una
## columna de bioma recibe un árbol real — ver _generar_arboles(). Valor
## inicial calibrado empíricamente, mismo patrón que UMBRAL_HIERRO/
## EXPONENTE_RELIEVE: ajustar aquí si el bosque real resulta demasiado
## denso o demasiado escaso.
const UMBRAL_ARBOL := 0.5

## Celdas vacías mínimas que deben quedar entre los cuadrados de tronco de
## dos árboles distintos — ver _generar_arboles()/_demasiado_cerca_de_otro_
## arbol(). Garantiza que los troncos nunca queden pegados, para que el
## jugador y los NPCs puedan caminar entre los árboles del bosque. Valor
## inicial calibrado empíricamente (feedback jugando en el editor real):
## ajustar aquí si el pasillo entre troncos resulta demasiado angosto.
const GAP_MINIMO_TRONCOS := 2

## Cuántas celdas pueden solaparse como máximo las copas de follaje de dos
## árboles distintos — ver _demasiado_cerca_de_otro_arbol(). A diferencia
## de GAP_MINIMO_TRONCOS (que nunca debe violarse, por transitabilidad),
## esto es puramente estético y a futuro dependerá del tipo de bioma (una
## selva húmeda tolera copas más solapadas que una sabana). Valor inicial
## calibrado empíricamente.
const SOLAPE_MAXIMO_COPAS := 1

## Rango de búsqueda vertical de altura_en() (ver más abajo) — generoso para
## cubrir cualquier construcción del jugador por encima del relieve máximo
## (GeneradorMundo.ALTURA_MAXIMA = 130) y el subsuelo generado por debajo
## (PROFUNDIDAD_SUBSUELO = 24, relativo a cada columna — con ALTURA_MINIMA =
## 0 el punto más bajo posible del subsuelo es y = -24).
const ALTURA_BUSQUEDA_MAX := 165
const ALTURA_BUSQUEDA_MIN := -34

var generador: RefCounted
var arboles: RefCounted

## (x,z) -> {"y_base": int, "caida": int, "direccion": Vector2i} para cada
## columna marcada como cascada (generador.es_cascada_en()) — llenado una
## sola vez en _generar_terreno(). "y_base" es el fondo real tallado de la
## caída (el mínimo entre la profundidad normal del río y la altura de la
## celda de cauce a la que fluye, ver ese mismo cálculo en _generar_terreno);
## "caida"/"direccion" vienen directo de generador.caida_en()/
## direccion_flujo_en(). Consumido por CascadaEffects (partículas) y por
## Player._empuje_corriente() (empuje extra al pie de la caída).
var cascadas: Dictionary = {}  # Vector2i -> Dictionary

## Tipos de bloque que pueden formar parte de un edificio declarado (ver
## detectar_estructura()). "piso" queda deliberadamente fuera: es un
## material de terreno/relleno (ver _generar_terreno() y el modo de
## nivelación de CamaraCenital), nunca un material de construcción — para
## la PoC, el único material estructural es "pared" (más adelante: madera,
## piedra, metal, vidrio). Si el jugador usa "piso" para rellenar un hueco
## de terreno bajo su edificio, ese relleno no debe "pegarse" a la
## estructura declarada ni distorsionar su huella.
const TIPOS_ESTRUCTURA := [
	"pared", "puerta_inferior", "puerta_superior", "ventana",
	"cama_cabecera", "cama_pies", "baul",
]

## La celda de superficie de cada columna del mundo se coloca como "piso"
## (ver _generar_terreno() — reutiliza el bloque caminable), pero
## geológicamente es el mismo material que el subsuelo justo debajo
## ("tierra", ver GeneradorMundo.tipo_en_profundidad()). La distinción
## piso/tierra es puramente visual (bloque caminable vs. bloque de
## relleno); para cualquier consumidor que le importe la IDENTIDAD del
## recurso (minas, a futuro NPCs — ver Recoleccion.detectar_recursos()),
## "piso" debe contarse como "tierra". No afecta renderizado ni
## construcción: "piso" sigue fuera de TIPOS_ESTRUCTURA y sigue siendo un
## bloque distinto en la MeshLibrary.
const MATERIAL_REAL := {"piso": "tierra"}

## Color con el que se destacan las puertas y ventanas de un edificio en
## construcción, para que se distingan del resto de sus celdas fantasma. Una
## sola fuente para la previsualización del blueprint (CamaraCenital.gd) y
## los fantasmas ya emplazados (FantasmasDestacados.gd), así se leen como lo
## mismo. Distintos a propósito del dorado de la previsualización
## (CamaraCenital.COLOR_PUESTO_VALIDO) y del azul del bloque "fantasma".
const COLOR_DESTACADO := {
	"puerta_inferior": Color(1.0, 0.2, 0.8, 0.6),
	"puerta_superior": Color(1.0, 0.2, 0.8, 0.6),
	"ventana": Color(0.5, 1.0, 0.2, 0.6),
}


## Traduce "tipo" (el tipo de bloque real, tal como lo devuelve
## obtener_tipo()) al material que representa para efectos de RECURSO —
## ver MATERIAL_REAL más arriba. Devuelve "tipo" sin cambios si no hay
## traducción registrada.
func material_real(tipo: String) -> String:
	return MATERIAL_REAL.get(tipo, tipo)


## Tipos de bloque generados por _generar_arboles() — ver altura_en() más
## abajo. Bug reportado por el usuario jugando en vivo: altura_en()
## contaba cualquier bloque sólido como "el suelo", así que el overlay de
## zona (ZonaOverlay) y la colocación de minas (CamaraCenital) terminaban
## ubicándose sobre la copa de un árbol en vez del terreno real debajo.
const TIPOS_ARBOL := ["madera", "follaje"]

## Tipos de bloque cuya geometría visible NO la dibuja GridMap (su ítem en
## la MeshLibrary tiene una malla vacía) — la dibuja TranslucidosRenderer,
## que omite las caras compartidas entre dos celdas del MISMO tipo
## translúcido (ver docs/superpowers/specs/2026-09-13-culling-caras-
## translucidas-design.md). GridMap sigue siendo la única fuente de verdad
## para ocupación/colisión: esto es puramente visual.
const TIPOS_TRANSLUCIDOS: Array[String] = ["agua", "ventana"]

const VECINOS_3D: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Las 4 direcciones cardinales en el plano XZ — usadas por
## calcular_despeje() para encontrar el lado "externo" de una celda
## ventana/puerta (cualquier vecino XZ que no pertenezca a la huella del
## propio edificio).
const VECINOS_ORTOGONALES_XZ: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var _id_por_tipo: Dictionary = {}  # String -> int
var _tipo_por_id: Dictionary = {}  # int -> String

## Celdas colocadas por el jugador (Vector3i -> true). El terreno generado por
## _generar_terreno() nunca se marca aquí, así que "declarar un edificio"
## (ver Player.gd) nunca puede incluir el suelo del mundo como parte de la
## estructura, sin importar su tipo de bloque.
var colocado_por_jugador: Dictionary = {}

## Vínculo bidireccional entre las dos celdas de un objeto multi-celda
## (puerta: 2 celdas verticales; cama: 2 celdas horizontales). Minar
## cualquiera de las dos celdas borra ambas — ver minar_bloque().
var pareja: Dictionary = {}  # Vector3i -> Vector3i

## Celda -> id de edificio al que pertenece (fantasma en curso, terminado,
## o puesto periférico). minar_bloque() consulta este registro para negarse
## a minar cualquier celda que forme parte de un edificio: un edificio se
## comporta como un objeto completo, no como un grupo de bloques sueltos
## (igual que ya hacen los árboles vía TIPOS_ARBOL/talar_bloque_de_arbol()).
## No se borra nunca al completarse una construcción fantasma (a diferencia
## de Construccion._celda_a_construccion, que sí se limpia): la inmunidad
## debe seguir vigente después de terminado el edificio, hasta que se
## deconstruya por completo (ver eliminar_edificio()).
var celda_a_edificio: Dictionary = {}  # Vector3i -> int
var _siguiente_id_edificio := 1

## id de edificio -> Array[Vector3i] de sus celdas registradas (ver
## registrar_edificio()). Permite, dado un id, recuperar TODAS sus celdas
## sin recorrer celda_a_edificio entero — la deconstrucción ya no lo usa
## (lee edificio_orden/edificio_progreso en su lugar); lo usa
## eliminar_edificio() para borrar todo rastro del id, y cualquier otro
## llamador que necesite "todas las celdas de un id" sin orden (p. ej. un
## puesto, que no tiene edificio_orden).
var edificio_a_celdas: Dictionary = {}  # int -> Array[Vector3i]

## Emitida cuando una celda cambia DE o A un tipo en TIPOS_TRANSLUCIDOS
## (colocada, minada, revertida a fantasma, o drenada) — TranslucidosRenderer
## la escucha para reconstruir solo los chunks afectados. No se emite para
## ningún otro cambio de bloque (la inmensa mayoría de las llamadas).
signal bloque_translucido_cambiado(celda: Vector3i)

## Por edificio (id de VoxelWorld.registrar_edificio()): el orden FIJO de
## sus celdas estructurales (piso -> paredes/puertas/ventanas ->
## mobiliario), sus tipos, y cuántas celdas desde el inicio de ese orden
## son actualmente reales ("progreso"). Reemplaza el modelo de dos colas
## de un solo sentido (Construccion.gd + _cola_decon) por un único índice
## que se mueve en ambas direcciones — ver
## docs/superpowers/specs/2026-09-11-construccion-reversible-design.md.
## Nunca se usa para el relleno de nivelación, que sigue en Construccion.gd
## (proceso de un solo sentido, aislado del edificio desde el spec de
## deconstrucción, punto 2.5).
var edificio_orden: Dictionary = {}  # int -> Array[Vector3i]
var edificio_tipos: Dictionary = {}  # int -> Dictionary (Vector3i -> String)
var edificio_progreso: Dictionary = {}  # int -> int
var edificio_metadata: Dictionary = {}  # int -> Dictionary

## id de edificio -> id de la cola de Construccion.gd que rellena su
## nivelación de terreno (solo si el blueprint necesitó relleno — ver
## iniciar_construccion_fantasma()). Mientras un edificio tenga entrada
## aquí, surtir_construccion() avanza SIEMPRE esta cola primero, sin
## importar a qué celda del grupo (relleno o estructura) haya apuntado el
## jugador — el relleno debe completarse antes de que la estructura
## empiece a surtirse, para que el jugador interactúe con "el grupo"
## edificio+relleno como una sola unidad. Se borra en cuanto la cola se
## agota (surtir_construccion()) o si el edificio se elimina antes de
## completar su relleno (eliminar_edificio()).
var edificio_relleno_cola: Dictionary = {}  # int -> int

## Por edificio: las celdas de despeje reservadas por sus ventanas/puertas
## (ver calcular_despeje()) y su consulta inversa — mismo patrón que
## edificio_a_celdas/celda_a_edificio. Persiste mientras exista el id del
## edificio, se libera por completo en eliminar_edificio() — ver
## docs/superpowers/specs/2026-09-11-despeje-ventanas-puertas-design.md.
## El despeje de dos edificios DISTINTOS puede solaparse libremente: solo
## se compara celda ESTRUCTURAL nueva contra despeje ajeno
## (verificar_despejes()), nunca despeje contra despeje. Por eso
## celda_a_despeje admite VARIOS dueños por celda (id de edificio -> true):
## si dos edificios comparten una celda de despeje (p. ej. puertas
## enfrentadas), liberar el despeje de uno al deconstruirlo
## (eliminar_edificio()) debe quitar solo SU reserva, nunca la del vecino
## que sigue en pie.
var edificio_despeje: Dictionary = {}  # int -> Array[Vector3i]
var celda_a_despeje: Dictionary = {}  # Vector3i -> Dictionary (id de edificio -> true)


## Asigna un id de edificio nuevo y registra cada celda de "celdas" bajo
## ese id. Devuelve el id asignado — usado por el llamador para asociar
## este edificio con su zona de influencia (Zonificacion.ampliar_influencia())
## y, más adelante, para deconstruirlo (ver procesar_deconstruccion()).
func registrar_edificio(celdas: Array) -> int:
	var id := _siguiente_id_edificio
	_siguiente_id_edificio += 1
	for celda in celdas:
		celda_a_edificio[celda] = id
	edificio_a_celdas[id] = celdas.duplicate()
	return id


## Consulta puntual de celda_a_edificio con un valor de "no pertenece"
## explícito (-1) en vez de acceder al Dictionary directamente.
func id_de_edificio(celda: Vector3i) -> int:
	return celda_a_edificio.get(celda, -1)


## Calcula las celdas de despeje que exige "celdas_mundo" (Vector3i real ->
## tipo, las celdas ESTRUCTURALES de un edificio — mismo formato que
## registrar_edificio_completo()/iniciar_construccion_fantasma() ya usan).
## Para cada celda "ventana" o "puerta_inferior"/"puerta_superior", revisa
## sus 4 vecinos cardinales en XZ; cualquiera que NO pertenezca a la huella
## del propio edificio (es decir, cae fuera de celdas_mundo en esa columna)
## es una dirección "externa". En cada dirección externa se reservan 1
## celda (ventana) o 2 celdas (puerta, en AMBOS niveles) a la misma altura
## Y de la celda original. Devuelve un Array sin duplicados (una celda de
## despeje puede quedar "pedida" por más de una ventana/puerta vecina).
func calcular_despeje(celdas_mundo: Dictionary) -> Array:
	var huella_xz: Dictionary = {}  # Vector2i -> true
	for celda in celdas_mundo:
		huella_xz[Vector2i(celda.x, celda.z)] = true

	var despeje: Dictionary = {}  # Vector3i -> true, para deduplicar
	for celda in celdas_mundo:
		var tipo: String = celdas_mundo[celda]
		var profundidad := 0
		if tipo == "ventana":
			profundidad = 1
		elif tipo == "puerta_inferior" or tipo == "puerta_superior":
			profundidad = 2
		else:
			continue

		for direccion in VECINOS_ORTOGONALES_XZ:
			var vecino_xz := Vector2i(celda.x, celda.z) + direccion
			if huella_xz.has(vecino_xz):
				continue  # vecino es parte del propio edificio, no es "externo"
			for paso in range(1, profundidad + 1):
				var celda_despeje := Vector3i(
					celda.x + direccion.x * paso, celda.y, celda.z + direccion.y * paso
				)
				despeje[celda_despeje] = true
	return despeje.keys()


## Valida si "celdas_mundo" (las celdas estructurales de un edificio a
## punto de colocarse, mismo formato que calcular_despeje()) respeta la
## regla de despeje: (a) ninguna de sus propias celdas de despeje puede
## estar físicamente ocupada (terreno, árbol, o cualquier estructura —
## cualquier bloque real tiene un tipo no vacío, así que basta comparar
## contra "" sin enumerar tipos "sólidos"), y (b) ninguna de sus celdas
## ESTRUCTURALES puede caer dentro del despeje YA RESERVADO de otro
## edificio (celda_a_despeje). El despeje del edificio nuevo NUNCA se
## compara contra el despeje ajeno — dos despejes distintos pueden
## solaparse libremente (puertas enfrentadas, ventana sobre despeje de
## puerta ajena, etc.), ver spec punto de diseño.
func verificar_despejes(celdas_mundo: Dictionary) -> bool:
	for celda in celdas_mundo:
		if celda_a_despeje.has(celda):
			return false
	for celda_despeje in calcular_despeje(celdas_mundo):
		if obtener_tipo(celda_despeje) != "":
			return false
	return true


func _ready() -> void:
	cell_size = Vector3.ONE * TAMANO_CELDA
	_indexar_biblioteca()
	generador = GeneradorMundo.new(SEMILLA_MUNDO, ANCHO_MUNDO, LARGO_MUNDO)
	arboles = GeneradorArbol.new()
	_generar_terreno()
	_generar_arboles()
	_generar_efectos_cascada()
	var translucidos: Node3D = get_node("TranslucidosRenderer")
	translucidos.voxel_world = self
	translucidos._indexar_materiales()
	bloque_translucido_cambiado.connect(translucidos._on_bloque_translucido_cambiado)
	translucidos.reconstruir_todo()


func _indexar_biblioteca() -> void:
	for id in mesh_library.get_item_list():
		var nombre: String = mesh_library.get_item_name(id)
		_id_por_tipo[nombre] = id
		_tipo_por_id[id] = nombre


## Genera el mundo una única vez al arrancar la escena: para cada columna
## (x, z) coloca la celda de superficie ("piso", reutilizando el bloque
## caminable existente) y PROFUNDIDAD_SUBSUELO celdas de subsuelo debajo
## (tierra cerca de la superficie, piedra más profundo, o vetas de "hierro"
## en la capa profunda — ver GeneradorMundo.tipo_en_profundidad), y si la
## columna queda por debajo del nivel de mar, agrega bloques "agua" encima
## de la superficie hasta ese nivel (ver GeneradorMundo.es_agua_en/
## nivel_mar). La excavación es relativa a la superficie de CADA columna
## (no un piso absoluto — ver PROFUNDIDAD_SUBSUELO, 2026-09-16 PoC_6 3.15):
## un piso absoluto se probó primero para que el fondo no copiara el
## relieve de arriba, pero con el relieve real del mundo (que ya no baja de
## ~50 en casi ningún punto) eso disparaba el volumen de celdas sólidas a
## 6.3 millones, reventando un límite interno de GridMap (overflow de
## índice, crash reproducido con y sin GPU). La última celda de cada
## columna (profundidad == PROFUNDIDAD_SUBSUELO) es "bedrock", inminable
## (ver minar_bloque()), para que el jugador nunca pueda cavar hasta el
## vacío — con el relieve ya suave (ver GeneradorMundo._ruido.frequency),
## este fondo relativo sale razonablemente uniforme igual, sin el costo de
## un piso absoluto.
## Ninguna de estas celdas se marca colocado_por_jugador: el terreno del
## mundo nunca puede ser parte de un edificio declarado por el jugador.
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			if generador.es_rio_en(x, z):
				var profundidad_rio: int = generador.profundidad_rio_en(x, z)
				var y_inicio_agua: int = altura - profundidad_rio + 1
				if generador.es_cascada_en(x, z):
					# Cascada real: en vez de solo tallar la profundidad normal
					# de esta celda, el agua sigue cayendo hasta encontrarse con
					# la altura natural de la celda del cauce a la que fluye
					# (direccion_flujo_en()), tallando el acantilado entre
					# ambas — sin esto, cada celda del río solo se talla según
					# su propia altura y el salto queda seco (bug real,
					# encontrado jugando: la cascada no "caía", quedaba un
					# charco flotando sobre un acantilado seco).
					var direccion: Vector2i = generador.direccion_flujo_en(x, z)
					if direccion != Vector2i.ZERO:
						var siguiente := Vector2i(x + direccion.x, z + direccion.y)
						var altura_destino: int = generador.altura_en(siguiente.x, siguiente.y)
						y_inicio_agua = mini(y_inicio_agua, altura_destino + 1)
					cascadas[Vector2i(x, z)] = {
						"y_base": y_inicio_agua,
						"caida": generador.caida_en(x, z),
						"direccion": direccion,
					}
				for y_agua in range(y_inicio_agua, altura + 1):
					colocar_bloque(Vector3i(x, y_agua, z), "agua")
				var profundidad_efectiva: int = altura - y_inicio_agua + 1
				for profundidad in range(profundidad_efectiva, PROFUNDIDAD_SUBSUELO + 1):
					var y: int = altura - profundidad
					var tipo: String = "bedrock" if profundidad == PROFUNDIDAD_SUBSUELO else generador.tipo_en_profundidad(x, y, z, profundidad)
					colocar_bloque(Vector3i(x, y, z), tipo)
				continue
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var y: int = altura - profundidad
				var tipo: String = "bedrock" if profundidad == PROFUNDIDAD_SUBSUELO else generador.tipo_en_profundidad(x, y, z, profundidad)
				colocar_bloque(Vector3i(x, y, z), tipo)
			if generador.es_agua_en(x, z):
				for y_agua in range(altura + 1, generador.nivel_mar + 1):
					colocar_bloque(Vector3i(x, y_agua, z), "agua")


## Partículas de salpicadura al pie de cada cascada registrada en "cascadas"
## (Sección diseño 2026-09-17) — una GPUParticles3D por columna, coloreada con
## MATERIAL_AGUA (mismo material que el bloque de agua, ver TranslucidosRenderer)
## para no depender de un asset nuevo. Sin sonido: no hay ningún asset de
## audio en el repo todavía (decisión explícita del usuario, ver sesión de
## diseño) — cuando se agregue un .ogg/.wav, se puede colgar un
## AudioStreamPlayer3D del mismo nodo.
func _generar_efectos_cascada() -> void:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 25.0
	material.gravity = Vector3(0, -9.8, 0)
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	var malla := QuadMesh.new()
	malla.size = Vector2(0.15, 0.15)
	var material_mesh := StandardMaterial3D.new()
	material_mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_mesh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_mesh.albedo_color = Color(1.0, 1.0, 1.0, 0.6) * MATERIAL_AGUA.albedo_color
	malla.material = material_mesh
	for celda in cascadas:
		var datos: Dictionary = cascadas[celda]
		var particulas := GPUParticles3D.new()
		particulas.amount = 12
		particulas.lifetime = 0.5
		particulas.process_material = material
		particulas.draw_pass_1 = malla
		particulas.position = map_to_local(Vector3i(celda.x, datos["y_base"], celda.y))
		add_child(particulas)


## Altura de la celda sólida más alta en la columna (x, z) del mundo REAL —
## no la del ruido original de GeneradorMundo, que nunca se actualiza tras
## minar, construir o nivelar. Usada por los overlays visuales (ZonaOverlay,
## huella fantasma de nivelación) y por NiveladorTerreno (se le pasa esta
## instancia de VoxelWorld en vez de "generador" para que razone sobre el
## relieve real, no el original) — de otro modo, cualquier zona pintada u
## huella de nivelación sobre una celda ya modificada por el jugador se veía
## a una altura "fantasma" que no correspondía a ningún bloque real.
## Ignora deliberadamente los bloques de árbol (TIPOS_ARBOL): son un
## obstáculo sobre el terreno, no el terreno mismo — sin este salto, el
## overlay de zona y la colocación de minas aterrizaban sobre la copa de
## un árbol en vez del suelo real debajo.
## Por la misma razón, ignora siempre las celdas "fantasma" (placeholder de
## construcción en curso): un fantasma es un obstáculo sobre el terreno,
## nunca el terreno mismo, igual que un árbol — sin este salto,
## _huella_choca_con_otro_puesto() (CamaraCenital) nunca detectaba la
## superposición de un fantasma existente, porque altura_en() devolvía el
## tope del propio fantasma en vez del suelo real debajo.
## "ignorar_agua" (solo para overlays puramente visuales: ZonaOverlay, huella
## fantasma de nivelación, disco de mina) también salta el bloque "agua" para
## que el plano se dibuje al nivel del terreno real, por debajo de la
## superficie del agua — no cambia ningún cálculo de juego real (colocación
## de mina/relleno de nivelación, altura de spawn), que deben seguir viendo
## el agua como el bloque más alto de la columna, aunque ya no sea sólido
## para minado/colocación.
func altura_en(x: int, z: int, ignorar_agua: bool = false) -> int:
	for y in range(ALTURA_BUSQUEDA_MAX, ALTURA_BUSQUEDA_MIN, -1):
		var celda := Vector3i(x, y, z)
		if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
			continue
		var tipo: String = obtener_tipo(celda)
		if TIPOS_ARBOL.has(tipo):
			continue
		if tipo == "fantasma":
			continue
		if ignorar_agua and tipo == "agua":
			continue
		return y
	return generador.altura_en(x, z)  # respaldo, no debería alcanzarse nunca


func colocar_bloque(celda: Vector3i, tipo: String, por_jugador: bool = false) -> bool:
	var actual: int = get_cell_item(celda)
	var tipo_anterior: String = _tipo_por_id.get(actual, "")
	if actual != GridMap.INVALID_CELL_ITEM and tipo_anterior != "agua":
		return false
	if not _id_por_tipo.has(tipo):
		return false
	set_cell_item(celda, _id_por_tipo[tipo])
	if por_jugador:
		colocado_por_jugador[celda] = true
	if tipo_anterior == "agua":
		# Reemplazar agua (de flujo o fuente) por otra cosa: el agua de flujo
		# que dependía de esta celda debe revisar si sigue conectada a una
		# fuente (ver _procesar_secado()); si se reemplaza por más agua, la
		# celda pasa a ser una fuente (sin entrada en _nivel_agua).
		_nivel_agua.erase(celda)
		if tipo != "agua":
			_encolar_secado_alrededor(celda)
	if TIPOS_TRANSLUCIDOS.has(tipo) or TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)
	# Solo si "por_jugador": _generar_terreno() coloca miles de bloques de
	# agua uno por uno al arrancar el mundo (ver ese método) y no debe
	# disparar un escurrimiento por cada uno — un futuro bloque de agua
	# colocado a mano por el jugador (aún sin UI, ver sesión de diseño
	# 2026-09-18) sí debe escurrir de inmediato, igual que al minar.
	if tipo == "agua" and por_jugador:
		_escurrir_agua_desde([celda])
	return true


func minar_bloque(celda: Vector3i) -> bool:
	if obtener_tipo(celda) == "agua":
		return false
	# "bedrock" es el piso absoluto del mundo (PISO_MUNDO) — inminable a
	# propósito, para que el jugador nunca pueda cavar hasta el vacío.
	if obtener_tipo(celda) == "bedrock":
		return false
	if celda_a_edificio.has(celda):
		return false
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
	_retirar_bloque(celda)
	return true


## Retira "celda" SIN las guardas de minar_bloque() (agua, bedrock,
## inmunidad de edificio, celda vacía): borra su "pareja" si la tiene, avisa
## a los translúcidos y deja escurrir el agua vecina. Lo usan minar_bloque()
## (que ya validó) y el paso de excavación de la cola de preparación
## (_aplicar_paso_cola()), que necesita cavar celdas que YA pertenecen a un
## edificio (la losa enterrada) y que minar_bloque() rechazaría.
func _retirar_bloque(celda: Vector3i) -> void:
	var tipo_anterior: String = obtener_tipo(celda)
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)
	var vecinos_agua: Array[Vector3i] = []
	for delta in VECINOS_3D:
		var vecino: Vector3i = celda + delta
		if obtener_tipo(vecino) == "agua":
			vecinos_agua.append(vecino)
	if not vecinos_agua.is_empty():
		_escurrir_agua_desde(vecinos_agua)


func obtener_tipo(celda: Vector3i) -> String:
	return _tipo_por_id.get(get_cell_item(celda), "")


## Datos de cascada de la columna (x,z), o {} si no es cascada — ver
## "cascadas" más arriba. Usado por CascadaEffects y por
## Player._empuje_corriente().
func columna_cascada_en(x: int, z: int) -> Dictionary:
	return cascadas.get(Vector2i(x, z), {})


## Dirección y caída de la corriente de río en (x,z), o {} si no es río (ver
## GeneradorMundo.direccion_flujo_en()/caida_en()). Usado por
## Player._procesar_corriente() para empujar al jugador en el sentido del
## cauce — a mayor "caida", mayor empuje (ver esa función).
func corriente_en(x: int, z: int) -> Dictionary:
	if not generador.es_rio_en(x, z):
		return {}
	return {
		"direccion": generador.direccion_flujo_en(x, z),
		"caida": generador.caida_en(x, z),
	}


func _celda_libre(celda: Vector3i) -> bool:
	return get_cell_item(celda) == GridMap.INVALID_CELL_ITEM


## Techo de celdas ESPARCIDAS LATERALMENTE (no de caída vertical, ver
## _caer_hasta_el_fondo()) por sesión de escurrimiento (desde que la cola deja
## de estar vacía hasta que vuelve a vaciarse, ver _process()): una caverna
## gigante conectada a un lago no debe llenarse entera sin límite. Bajado de
## 500 a 150 (2026-09-18, feedback jugando en vivo: "500 parece ser mucho").
## Variable de instancia (no una constante usada directamente) solo para
## poder forzar un tope pequeño y determinista en las pruebas — ver
## _limite_escurrimiento más abajo. ponytail: límite fijo por sesión — si
## algún día hace falta escurrir más allá de esto, la vía de escape es
## repartirlo en más frames (ya diferido, ver FRENTES_ESCURRIMIENTO_POR_FRAME),
## no subir este número.
const LIMITE_ESCURRIMIENTO := 150

## Cuántos "frentes" de la cola de escurrimiento se expanden por frame (ver
## _process()) — controla qué tan rápido se ve "fluir" el agua nueva en vez
## de aparecer de golpe (diseño 2026-09-18, feedback jugando en vivo: la
## propagación instantánea no se sentía como agua corriendo). Bajarlo hace
## el flujo más lento/visible; subirlo lo acerca de nuevo al llenado
## instantáneo de la versión anterior. Un "frente" es una celda de agua ya
## colocada cuyos 4 vecinos horizontales todavía no se exploraron — cada uno
## puede colocar hasta 4 celdas nuevas (más su propia caída, sin tope), así
## que el avance real por frame es mayor que este número, no igual a él.
const FRENTES_ESCURRIMIENTO_POR_FRAME := 2

## Niveles del agua de flujo (diseño 2026-09-20, pedido del usuario: "a medida
## que el agua se aleja del bloque fuente, que se vea menos lleno; y que cada
## semibloque esté conectado a al menos 1 fuente para existir"). El agua sigue
## siendo el tipo "agua" (nada de lo que ya la consulta cambia): la fuente no
## tiene entrada en _nivel_agua y se ve llena; una celda de flujo guarda su
## nivel — NIVEL_CAIDA (0) para el agua que cae (se ve llena, como en
## Minecraft) o 1..NIVEL_MAXIMO_FLUJO para el agua que corre en plano (cada
## nivel más bajo que el anterior, ver altura_agua_en()). Una caída reinicia
## el nivel: al aterrizar, el agua vuelve a esparcirse con alcance completo.
const NIVEL_CAIDA := 0
const NIVEL_MAXIMO_FLUJO := 7

## Cuántas celdas de la cola de secado se revisan por frame (ver
## _procesar_secado()) — mismo motivo que FRENTES_ESCURRIMIENTO_POR_FRAME: que
## el agua se vea secarse gradualmente en vez de desaparecer de golpe.
const FRENTES_SECADO_POR_FRAME := 3

## Ver LIMITE_ESCURRIMIENTO — variable en vez de constante para que las
## pruebas puedan forzar un tope pequeño en su propia instancia de
## VoxelWorld sin afectar al resto del juego.
var _limite_escurrimiento: int = LIMITE_ESCURRIMIENTO

## Vector3i -> int: nivel de cada celda de agua de FLUJO (ver NIVEL_CAIDA/
## NIVEL_MAXIMO_FLUJO). Una celda de agua sin entrada aquí es una fuente.
var _nivel_agua: Dictionary = {}

## Cola pendiente de escurrimiento: celdas de agua YA colocadas cuyos vecinos
## horizontales todavía no se exploraron — ver _process()/
## _procesar_frente_escurrimiento(). Persiste entre frames a propósito (ver
## FRENTES_ESCURRIMIENTO_POR_FRAME): drenarla de una sola vez, como hacía la
## primera versión de este método, es exactamente lo que se quitó para que
## el escurrimiento se vea como un flujo gradual en vez de instantáneo.
var _cola_escurrimiento: Array[Vector3i] = []

## Celdas de agua de flujo cuya conexión con una fuente hay que volver a
## comprobar (ver _procesar_secado()) — se llena cuando una celda de agua
## deja de serlo (ver _encolar_secado_alrededor()).
var _cola_secado: Array[Vector3i] = []

## Cuenta las celdas esparcidas lateralmente en la sesión de escurrimiento
## en curso (ver LIMITE_ESCURRIMIENTO) — se reinicia a 0 cada vez que
## _cola_escurrimiento vuelve a quedar vacía (_process()), así que cada
## sesión nueva parte de presupuesto completo otra vez.
var _esparcidas_escurrimiento := 0


## Vacía y dentro del rango vertical real del mundo (ver
## _escurrir_agua_desde()) — sin este último chequeo, una celda de agua cerca
## del límite de altura_en() podría escurrir indefinidamente hacia arriba/
## abajo del rango donde el resto del juego busca celdas (GridMap no tiene
## límite propio). Sin límite horizontal a propósito: GridMap tampoco tiene
## columnas "fuera del mundo" reales, LIMITE_ESCURRIMIENTO ya acota
## cualquier fuga en cualquier dirección, y las pruebas colocan bloques
## sueltos en coordenadas fuera de ANCHO_MUNDO/LARGO_MUNDO a propósito para
## aislarse entre sí.
func _celda_escurrible(celda: Vector3i) -> bool:
	if celda.y < ALTURA_BUSQUEDA_MIN or celda.y > ALTURA_BUSQUEDA_MAX:
		return false
	return _celda_libre(celda)


## Nivel de flujo de "celda": -1 si no es agua de flujo (una fuente, o no es
## agua), NIVEL_CAIDA (0) si es agua que cae, 1..NIVEL_MAXIMO_FLUJO si corre
## en plano. Ver _nivel_agua.
func nivel_agua_en(celda: Vector3i) -> int:
	return _nivel_agua.get(celda, -1)


## Altura visible (0..1, fracción del cubo) de la celda de agua "celda": 1.0
## para una fuente o agua que cae, y (8 - nivel) / 8 para agua que corre en
## plano (nivel 1 = 0.875, ..., nivel 7 = 0.125). Usada por
## TranslucidosRenderer para dibujar los semibloques.
func altura_agua_en(celda: Vector3i) -> float:
	var nivel: int = _nivel_agua.get(celda, NIVEL_CAIDA)
	if nivel <= NIVEL_CAIDA:
		return 1.0
	return float(NIVEL_MAXIMO_FLUJO + 1 - nivel) / float(NIVEL_MAXIMO_FLUJO + 1)


## "Distancia a la fuente" efectiva de una celda de agua: 0 para una fuente
## o agua que cae, el nivel para agua que corre en plano.
func _nivel_efectivo(celda: Vector3i) -> int:
	return maxi(_nivel_agua.get(celda, NIVEL_CAIDA), NIVEL_CAIDA)


func _es_agua_de_flujo(celda: Vector3i) -> bool:
	return _nivel_agua.has(celda) and obtener_tipo(celda) == "agua"


## Coloca una celda de agua de flujo con "nivel" (ver NIVEL_CAIDA/
## NIVEL_MAXIMO_FLUJO). colocar_bloque() ya emite bloque_translucido_cambiado;
## el nivel se fija justo después, antes de que TranslucidosRenderer
## reconstruya en su próximo frame.
func _colocar_agua_flujo(celda: Vector3i, nivel: int) -> void:
	colocar_bloque(celda, "agua")
	_nivel_agua[celda] = nivel


## Cambia el nivel de una celda de flujo que ya existe y avisa al renderer.
func _cambiar_nivel_agua(celda: Vector3i, nivel: int) -> void:
	_nivel_agua[celda] = nivel
	bloque_translucido_cambiado.emit(celda)


## Encola "semillas" (agua real, con al menos un vecino vacío) para que
## _process() las escurra gradualmente — ver esa función y
## _procesar_frente_escurrimiento() para el algoritmo (inspirado en
## Minecraft, con niveles y secado — ver NIVEL_MAXIMO_FLUJO y
## _procesar_secado()). Llamada desde minar_bloque() (siempre que la celda
## minada tuviera agua vecina) y desde colocar_bloque() (solo cuando
## "por_jugador", ver esa función). No hace ningún trabajo por sí misma —
## solo encola; así que llamarla nunca bloquea el frame actual.
func _escurrir_agua_desde(semillas: Array[Vector3i]) -> void:
	_cola_escurrimiento.append_array(semillas)


func _process(_delta: float) -> void:
	if _cola_escurrimiento.is_empty():
		_esparcidas_escurrimiento = 0
	else:
		for _i in range(FRENTES_ESCURRIMIENTO_POR_FRAME):
			if not _procesar_frente_escurrimiento():
				break
	for _i in range(FRENTES_SECADO_POR_FRAME):
		if not _procesar_secado():
			break


## Procesa un solo "frente" de _cola_escurrimiento (una celda de agua ya
## colocada cuyos vecinos todavía no se exploraron). Regla (pedido del
## usuario, 2026-09-20, evaluada sobre la celda VECINA según lo que tenga
## debajo):
##  - Primero agota la caída vertical del frente (_caer_hasta_el_fondo(),
##    sin tope: está acotada por la altura del mundo). Al final de la caída
##    hay suelo (sólido o fuente): desde ahí se esparce, con alcance
##    renovado; o agua de flujo: se une a ella y la "alimenta" (pasa a
##    caer, se ve llena), sin esparcirse más desde aquí.
##  - Desde el fondo, para cada vecino horizontal vacío: si debajo hay vacío
##    o agua de flujo (una caída), va SOLO hacia esos; si no hay ninguno,
##    corre en plano a los que tienen debajo un sólido o una fuente. Cada
##    celda nueva lleva un nivel más que el fondo (más baja/delgada), hasta
##    NIVEL_MAXIMO_FLUJO, donde se detiene.
##  - Un vecino que ya es agua de flujo con un nivel más alto (más delgado)
##    que el que le llegaría se "mejora" al nivel menor y se vuelve a
##    encolar — así una segunda fuente cercana puede rellenarlo mejor.
## Respeta _limite_escurrimiento (que SOLO cuenta celdas nuevas esparcidas
## lateralmente). La caída de una celda esparcida se resuelve siempre en el
## mismo paso en que se coloca (nunca queda pendiente para un frente
## futuro), así que ninguna celda puede quedar "flotando" sin importar en
## qué frame se agote el tope (bug real, corregido 2026-09-18). Devuelve
## false si la cola ya estaba vacía. Llamada varias veces por frame desde
## _process(); las pruebas la llaman en un bucle propio (ver
## _drenar_escurrimiento_para_pruebas()).
func _procesar_frente_escurrimiento() -> bool:
	if _cola_escurrimiento.is_empty():
		return false
	var origen: Vector3i = _cola_escurrimiento.pop_front()
	if obtener_tipo(origen) != "agua":
		return true  # se secó antes de que le tocara su turno
	var fondo: Vector3i = _caer_hasta_el_fondo(origen)
	var abajo: Vector3i = fondo + Vector3i(0, -1, 0)
	if _es_agua_de_flujo(abajo):
		# Cae sobre agua de flujo: se une a ella y la alimenta (pasa a caer).
		if _nivel_agua[abajo] > NIVEL_CAIDA:
			_cambiar_nivel_agua(abajo, NIVEL_CAIDA)
			_cola_escurrimiento.append(abajo)
		return true
	var nivel: int = _nivel_efectivo(fondo)
	if nivel >= NIVEL_MAXIMO_FLUJO:
		return true
	var con_caida: Array[Vector3i] = []
	var planas: Array[Vector3i] = []
	for direccion_xz in VECINOS_ORTOGONALES_XZ:
		var lateral: Vector3i = fondo + Vector3i(direccion_xz.x, 0, direccion_xz.y)
		if _es_agua_de_flujo(lateral):
			if _nivel_agua[lateral] > nivel + 1:
				_cambiar_nivel_agua(lateral, nivel + 1)
				_cola_escurrimiento.append(lateral)
			continue
		if not _celda_escurrible(lateral):
			continue
		var debajo: Vector3i = lateral + Vector3i(0, -1, 0)
		if _celda_escurrible(debajo) or _es_agua_de_flujo(debajo):
			con_caida.append(lateral)
		else:
			planas.append(lateral)
	var destinos: Array[Vector3i] = con_caida if not con_caida.is_empty() else planas
	for lateral in destinos:
		if _esparcidas_escurrimiento >= _limite_escurrimiento:
			break
		_colocar_agua_flujo(lateral, nivel + 1)
		_esparcidas_escurrimiento += 1
		_cola_escurrimiento.append(lateral)
	return true


## Deja caer agua desde "origen" hasta que ya no pueda seguir bajando
## (encuentra suelo, otra agua, o el límite vertical real del mundo — ver
## _celda_escurrible()), colocando agua que cae (NIVEL_CAIDA) en cada celda
## de la caída, y devuelve la celda final (el "fondo" real). SIN tope de
## seguridad propio a propósito: una caída vertical está acotada por la
## altura real del mundo (unas 200 celdas en el peor caso), nunca puede ser
## el origen de una fuga descontrolada como sí puede serlo el esparcido
## lateral (una caverna enorme, ver LIMITE_ESCURRIMIENTO).
func _caer_hasta_el_fondo(origen: Vector3i) -> Vector3i:
	var fondo := origen
	var abajo: Vector3i = fondo + Vector3i(0, -1, 0)
	while _celda_escurrible(abajo):
		_colocar_agua_flujo(abajo, NIVEL_CAIDA)
		fondo = abajo
		abajo = fondo + Vector3i(0, -1, 0)
	return fondo


## Encola para revisar (ver _procesar_secado()) los 6 vecinos de "celda" que
## sean agua de flujo — llamado cada vez que una celda de agua deja de serlo
## (reemplazada por un bloque, drenada, o ella misma secada). Barato cuando
## no hay agua de flujo en el mundo (el caso normal): sale de inmediato.
func _encolar_secado_alrededor(celda: Vector3i) -> void:
	if _nivel_agua.is_empty():
		return
	for delta in VECINOS_3D:
		var vecino: Vector3i = celda + delta
		if _nivel_agua.has(vecino):
			_cola_secado.append(vecino)


## Verdadero si "celda" (agua de flujo) sigue conectada a una fuente: agua
## de cualquier tipo justo encima (la alimenta cayendo), o —si corre en
## plano— un vecino horizontal de agua con un nivel efectivo MENOR que el
## suyo. Como cada eslabón tiene un nivel estrictamente menor, no puede
## haber ciclos: la cadena termina en una fuente o en agua que cae, y esta a
## su vez en agua encima, y así hasta una fuente.
func _esta_alimentada(celda: Vector3i) -> bool:
	if obtener_tipo(celda + Vector3i(0, 1, 0)) == "agua":
		return true
	var nivel: int = _nivel_agua[celda]
	if nivel <= NIVEL_CAIDA:
		return false
	for direccion_xz in VECINOS_ORTOGONALES_XZ:
		var vecino: Vector3i = celda + Vector3i(direccion_xz.x, 0, direccion_xz.y)
		if obtener_tipo(vecino) == "agua" and _nivel_efectivo(vecino) < nivel:
			return true
	return false


## Revisa una celda de _cola_secado: si ya no está conectada a una fuente,
## la seca (quita el bloque) y encola a sus vecinos de flujo para que
## revisen lo mismo — así el secado avanza en cadena, gradualmente, desde
## donde se quitó la fuente. Devuelve false si la cola ya estaba vacía.
func _procesar_secado() -> bool:
	if _cola_secado.is_empty():
		return false
	var celda: Vector3i = _cola_secado.pop_front()
	if not _es_agua_de_flujo(celda) or _esta_alimentada(celda):
		return true
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	_nivel_agua.erase(celda)
	bloque_translucido_cambiado.emit(celda)
	_encolar_secado_alrededor(celda)
	return true


## Drena TODAS las colas de agua pendientes (escurrimiento y secado) de una
## sola vez, sin el límite por frame de _process() — solo para pruebas, que
## necesitan el resultado final determinista sin simular el paso de frames
## reales.
func _drenar_escurrimiento_para_pruebas() -> void:
	while not _cola_escurrimiento.is_empty() or not _cola_secado.is_empty():
		while _procesar_frente_escurrimiento():
			pass
		while _procesar_secado():
			pass
	_esparcidas_escurrimiento = 0


## Coloca una puerta de 2 celdas verticales: "base" es la mitad inferior,
## la superior se agrega automáticamente encima. Falla (sin colocar nada)
## si cualquiera de las dos celdas ya está ocupada.
func colocar_puerta(base: Vector3i) -> bool:
	var arriba := base + Vector3i(0, 1, 0)
	if not (_celda_libre(base) and _celda_libre(arriba)):
		return false
	colocar_bloque(base, "puerta_inferior", true)
	colocar_bloque(arriba, "puerta_superior", true)
	pareja[base] = arriba
	pareja[arriba] = base
	return true


## Coloca una cama de 2 celdas horizontales: "base" es la cabecera,
## "direccion" (un vector cardinal, ver Player._direccion_cardinal) indica
## hacia dónde queda el pie de la cama. Falla si falta espacio en cualquiera
## de las dos celdas.
func colocar_cama(base: Vector3i, direccion: Vector3i) -> bool:
	var pies := base + direccion
	if not (_celda_libre(base) and _celda_libre(pies)):
		return false
	colocar_bloque(base, "cama_cabecera", true)
	colocar_bloque(pies, "cama_pies", true)
	pareja[base] = pies
	pareja[pies] = base
	return true


## Flood-fill 3D (6-conectividad) sobre bloques ESTRUCTURALES (ver
## TIPOS_ESTRUCTURA) colocados por el jugador, partiendo de "origen". No
## razona sobre espacio/aire transitable: dos habitaciones con puertas
## propias, cada una cerrada, quedan igualmente unidas si sus paredes se
## tocan físicamente con el pasillo que las conecta. Un bloque de "piso"
## colocado por el jugador (p.ej. relleno de terreno bajo el edificio) ni se
## incluye ni propaga el flood-fill, aunque sea colocado_por_jugador.
## Devuelve {} si "origen" no es un bloque estructural colocado por el
## jugador (p.ej. es terreno, o es "piso").
func detectar_estructura(origen: Vector3i) -> Dictionary:
	if not es_celda_estructural(origen):
		return {}

	var visitados: Dictionary = {}  # Vector3i -> String (tipo)
	var pendientes: Array = [origen]
	while not pendientes.is_empty():
		var actual: Vector3i = pendientes.pop_back()
		if visitados.has(actual) or not es_celda_estructural(actual):
			continue
		visitados[actual] = obtener_tipo(actual)
		for delta in VECINOS_3D:
			var vecino: Vector3i = actual + delta
			if not visitados.has(vecino):
				pendientes.append(vecino)
	return visitados


## Pública (no solo para detectar_estructura): también la usa ZonaOverlay.gd
## para no pintar el overlay de zona sobre el techo de un edificio — un
## bloque "piso" de relleno de terreno (nunca estructural, ver TIPOS_
## ESTRUCTURA) sigue contando como parte del terreno para esto.
func es_celda_estructural(celda: Vector3i) -> bool:
	return colocado_por_jugador.get(celda, false) and TIPOS_ESTRUCTURA.has(obtener_tipo(celda))


## Revisa cada columna de "columnas" (offsets Vector2i relativos a
## "esquina" — ver docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md;
## un rectángulo es solo el caso particular de pasar range(ancho) x
## range(alto), ver CamaraCenital._columnas_rectangulo()).
## altura_en() no salta bloques estructurales (solo TIPOS_ARBOL y "fantasma"),
## así que un muro colocado sobre "piso" se convierte en la propia superficie
## que altura_en() devuelve — por eso el chequeo de estructura se hace SOBRE
## esa superficie (altura_en(x,z)), no una celda encima. "madera"/"follaje",
## en cambio, sí se buscan por ENCIMA de la superficie, porque altura_en()
## salta los árboles al calcularla y por lo tanto la superficie real queda
## justo debajo del árbol.
## "altura" (por defecto 1) es cuántos niveles Y por encima de la superficie
## se revisan en busca de madera/follaje — de superficie+1 a superficie+altura
## inclusive. El valor por defecto basta para los puestos POR AHORA (en esta
## PoC son un marcador de un solo bloque, alcance reducido — en el diseño
## real son construcciones como cualquier otra, con su propia altura, que
## podría variar incluso por era tecnológica, ver GDD Sección 7); cuando un
## puesto deje de ser un marcador de 1 bloque, deberá pasar su altura real
## igual que ya hace un blueprint de varios pisos, para que un tronco o
## pared que sobresalga por encima de superficie+1 también se detecte.
## "madera" o cualquier bloque estructural invalida la huella completa;
## "follaje" se acumula en follaje_a_eliminar (en cualquiera de los niveles
## revisados) sin invalidar (se borra al confirmar la colocación — ver GDD
## Sección 3, "Emplazamiento Dentro de un Bosque"). Usada por la validación
## de choques de los puestos periféricos y blueprints (CamaraCenital.gd) —
## no conoce Recoleccion.puestos, solo bloques reales.
func verificar_huella_libre(esquina: Vector2i, columnas: Array[Vector2i], altura: int = 1) -> Dictionary:
	var valida := true
	var follaje_a_eliminar: Array[Vector3i] = []
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var superficie: int = altura_en(x, z)
		if es_celda_estructural(Vector3i(x, superficie, z)):
			valida = false
			continue
		for dy in range(1, altura + 1):
			var celda := Vector3i(x, superficie + dy, z)
			var tipo: String = obtener_tipo(celda)
			if tipo == "madera":
				valida = false
			elif tipo == "follaje":
				follaje_a_eliminar.append(celda)
	return {"valida": valida, "follaje_a_eliminar": follaje_a_eliminar}


## Coloca árboles reales en las columnas de bioma cuya densidad supera
## UMBRAL_ARBOL. Antes de generar cada árbol, mide su tamaño real
## (arboles.medir_pisada()) para decidir si cabe sin violar
## GAP_MINIMO_TRONCOS/SOLAPE_MAXIMO_COPAS respecto a los árboles ya
## colocados — ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md.
func _generar_arboles() -> void:
	var arboles_colocados: Array[Dictionary] = []
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			if generador.densidad_arbol_en(x, z) <= UMBRAL_ARBOL:
				continue
			var semilla_arbol: int = SEMILLA_MUNDO + x * LARGO_MUNDO + z
			var medida: Dictionary = arboles.medir_pisada(semilla_arbol)
			var lado_tronco: int = medida["lado_tronco"]
			var radio_follaje: int = medida["radio_follaje"]
			@warning_ignore("integer_division")
			var centro_offset: int = (lado_tronco - 1) / 2
			var candidato: Dictionary = {
				"x_min": x, "x_max": x + lado_tronco - 1,
				"z_min": z, "z_max": z + lado_tronco - 1,
				"centro_x": x + centro_offset, "centro_z": z + centro_offset,
				"radio_follaje": radio_follaje,
			}
			if _tronco_toca_agua(candidato):
				continue
			if _demasiado_cerca_de_otro_arbol(candidato, arboles_colocados):
				continue
			var altura: int = generador.altura_en(x, z)
			var base := Vector3i(x, altura + 1, z)
			var forma: Dictionary = arboles.generar_forma_aleatoria(semilla_arbol)
			var celdas_mundiales: Array = []
			var salud := 0
			for offset in forma:
				var celda: Vector3i = base + offset
				var tipo: String = forma[offset]
				if colocar_bloque(celda, tipo):
					celdas_mundiales.append(celda)
					if tipo == "madera":
						salud += 1
			if salud > 0:
				arboles.registrar(celdas_mundiales, salud)
			arboles_colocados.append(candidato)


## true si alguna columna del cuadrado de tronco de "candidato" (no solo la
## celda semilla x,z, que es la única que es_bioma_en()/densidad_arbol_en()
## ya garantizan que no es agua) está sobre agua — con lado_tronco > 1, otra
## esquina del tronco puede caer sobre agua cerca de la orilla aunque la
## semilla sea tierra firme. El árbol entero se coloca con una única altura
## base (ver más abajo), así que un tronco parcialmente sobre agua no se
## puede "hundir" celda por celda sin rehacer su forma — más simple y
## robusto: no generar ese árbol.
func _tronco_toca_agua(candidato: Dictionary) -> bool:
	for cx in range(candidato["x_min"], candidato["x_max"] + 1):
		for cz in range(candidato["z_min"], candidato["z_max"] + 1):
			if generador.es_agua_en(cx, cz) or generador.es_rio_en(cx, cz):
				return true
	return false


## Verdadero si "candidato" quedaría demasiado cerca de algún árbol ya
## colocado en "colocados": sus cuadrados de tronco no dejarían
## GAP_MINIMO_TRONCOS celdas vacías entre sí (chequeo de cajas expandidas,
## correcto también para pares de árboles colocados en diagonal — un
## chequeo de sola distancia entre centros no lo sería, dos cuadrados
## pueden tocarse en una esquina/borde sin que sus centros estén cerca),
## o sus copas de follaje se solaparían más de SOLAPE_MAXIMO_COPAS celdas.
func _demasiado_cerca_de_otro_arbol(candidato: Dictionary, colocados: Array[Dictionary]) -> bool:
	for otro in colocados:
		var cerca_en_x: bool = candidato["x_min"] - GAP_MINIMO_TRONCOS <= otro["x_max"] and candidato["x_max"] + GAP_MINIMO_TRONCOS >= otro["x_min"]
		var cerca_en_z: bool = candidato["z_min"] - GAP_MINIMO_TRONCOS <= otro["z_max"] and candidato["z_max"] + GAP_MINIMO_TRONCOS >= otro["z_min"]
		if cerca_en_x and cerca_en_z:
			return true
		var dx: float = candidato["centro_x"] - otro["centro_x"]
		var dz: float = candidato["centro_z"] - otro["centro_z"]
		var distancia_centros: float = sqrt(dx * dx + dz * dz)
		var solape_copas: float = (candidato["radio_follaje"] + otro["radio_follaje"]) - distancia_centros
		if solape_copas > SOLAPE_MAXIMO_COPAS:
			return true
	return false


## Busca el árbol dueño de "celda"; si no hay ninguno, no hace nada y
## devuelve false. Si hay uno, aplica "dano" a su salud (ver
## GeneradorArbol.danar()); si quedó completamente talado, borra todas sus
## celdas del GridMap de una sola vez (mientras tiene salud restante,
## ningún bloque del árbol se toca) y limpia su registro. Devuelve si el
## árbol quedó completamente talado.
func talar_bloque_de_arbol(celda: Vector3i, dano: int) -> bool:
	var id: int = arboles.obtener_arbol_de(celda)
	if id == -1:
		return false
	var talado: bool = arboles.danar(id, dano)
	if talado:
		for c in arboles.celdas_de(id):
			set_cell_item(c, GridMap.INVALID_CELL_ITEM)
		arboles.eliminar(id)
	return talado


## Elimina un bloque de follaje suelto (cosmético, no un recurso — ver GDD
## Sección 3, "Emplazamiento Dentro de un Bosque") y lo desregistra del árbol
## al que pertenece, si alguno, para no dejar a GeneradorArbol apuntando a
## una celda ya vacía (mismo tipo de desincronización que talar_bloque_de_arbol()
## ya evita). Usada al confirmar la colocación de un puesto periférico cuya
## huella chocó solo con follaje (VoxelWorld.verificar_huella_libre()).
func eliminar_follaje(celda: Vector3i) -> void:
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	var id: int = arboles.obtener_arbol_de(celda)
	if id != -1:
		arboles.eliminar_celda(id, celda)


## Orden canónico y ÚNICO de las celdas estructurales de un edificio —
## piso primero, luego paredes/puertas/ventanas, luego mobiliario. Se usa
## en ambos sentidos: surtir_construccion() avanza edificio_progreso[id] a
## través de este mismo orden, procesar_deconstruccion() lo retrocede. No
## existe un orden "invertido" aparte — decrementar por el mismo camino
## con el que se construyó ya quita primero lo último agregado (mobiliario
## -> paredes -> piso), dando la sensación correcta de "arriba hacia
## abajo" sin ninguna regla especial.
const ORDEN_GRUPOS_EDIFICIO := [
	["piso"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["cama_cabecera", "cama_pies", "baul"],
]


## Agrupa y ordena "celdas_mundo" (Vector3i real -> tipo) según
## ORDEN_GRUPOS_EDIFICIO, y dentro de cada grupo por (y, x, z). Pública
## (sin guion bajo) porque CamaraCenital._procesar_clic_blueprint() la
## llama para calcular "orden_estructura" antes de iniciar_construccion_
## fantasma() (ver Task 3).
func ordenar_celdas_edificio(celdas_mundo: Dictionary) -> Array:
	var orden: Array[Vector3i] = []
	for grupo in ORDEN_GRUPOS_EDIFICIO:
		var celdas_grupo: Array[Vector3i] = []
		for celda in celdas_mundo:
			if grupo.has(celdas_mundo[celda]):
				celdas_grupo.append(celda)
		celdas_grupo.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.x != b.x:
				return a.x < b.x
			return a.z < b.z
		)
		orden.append_array(celdas_grupo)
	return orden


## Procesa un intento de deconstrucción apuntando a "celda". Devuelve {} si
## "celda" no pertenece a ningún edificio con edificio_orden registrado
## (p. ej. un puesto periférico, que nunca pasa por aquí). Revierte SIEMPRE
## la celda en orden[progreso - 1] (la última agregada, sin importar cuál
## celda concreta se apuntó) y decrementa el progreso — mismo patrón
## "avanza siempre la primera/última pendiente" que ya usaba
## surtir_construccion(), en reversa.
##
## Devuelve {"id": int, "completa_reversion": bool,
## "lista_para_remocion": bool, "total_camas": int} — "total_camas" es el
## número de "cama_cabecera" del edificio, PERO SOLO tiene sentido cuando
## esta llamada cruza el borde de "edificio recién terminado" hacia
## "edificio ya no completo" (progreso pasa de orden.size() a
## orden.size() - 1); en cualquier otra llamada vale 0, para no
## contabilizar camas más de una vez si se deconstruye y se vuelve a
## completar varias veces (ver Ciudad.registrar_edificio_residencial(),
## que no es idempotente). "lista_para_remocion"/"completa_reversion" son
## true cuando el progreso llega a 0.
func procesar_deconstruccion(celda: Vector3i) -> Dictionary:
	var id: int = id_de_edificio(celda)
	if id == -1 or not edificio_orden.has(id):
		return {}
	var orden: Array = edificio_orden[id]
	var progreso: int = edificio_progreso[id]
	if progreso == 0:
		return {"id": id, "completa_reversion": true, "lista_para_remocion": true, "total_camas": 0}

	var total_camas := 0
	if progreso == orden.size():
		for c in orden:
			if edificio_tipos[id][c] == "cama_cabecera":
				total_camas += 1

	var celda_a_revertir: Vector3i = orden[progreso - 1]
	_revertir_celda(celda_a_revertir)
	edificio_progreso[id] = progreso - 1
	var vacio: bool = edificio_progreso[id] == 0
	return {"id": id, "completa_reversion": vacio, "lista_para_remocion": vacio, "total_camas": total_camas}


## Convierte "celda" (una celda real) de vuelta a "fantasma" — no marca
## colocado_por_jugador (igual que iniciar_construccion_fantasma()) y
## limpia cualquier entrada previa de esa celda en colocado_por_jugador
## (ya no es estructura real). No toca "pareja": una celda revertida sigue
## inmune al minado (celda_a_edificio no se borra hasta eliminar_edificio()),
## así que minar_bloque() nunca llega a consultar "pareja" para ella
## mientras dure la deconstrucción.
func _revertir_celda(celda: Vector3i) -> void:
	var tipo_anterior: String = obtener_tipo(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	colocar_bloque(celda, "fantasma")
	if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)


## Elimina por completo un edificio ya reducido a fantasma vacío (ver
## procesar_deconstruccion(), "lista_para_remocion" == true): borra todas
## sus celdas del GridMap y limpia celda_a_edificio/edificio_a_celdas — deja
## de ser inmune al minado porque deja de existir. Devuelve la esquina
## (mínimo x, mínimo z entre sus celdas) para que el llamador pueda avisar
## a Recoleccion (quitar_puesto()) — esta función no conoce Recoleccion ni
## Zonificacion, solo el mundo físico. No-op (devuelve Vector2i.ZERO) si
## "id" no existe.
func eliminar_edificio(id: int) -> Vector2i:
	if not edificio_a_celdas.has(id):
		return Vector2i.ZERO
	var celdas: Array = edificio_a_celdas[id]
	var esquina := Vector2i(celdas[0].x, celdas[0].z)
	for celda in celdas:
		esquina.x = min(esquina.x, celda.x)
		esquina.y = min(esquina.y, celda.z)
		if pareja.has(celda):
			pareja.erase(pareja[celda])
			pareja.erase(celda)
		var tipo_anterior: String = obtener_tipo(celda)
		set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
		celda_a_edificio.erase(celda)
		if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
			bloque_translucido_cambiado.emit(celda)
	edificio_a_celdas.erase(id)
	edificio_orden.erase(id)
	edificio_tipos.erase(id)
	edificio_progreso.erase(id)
	edificio_metadata.erase(id)
	# La excavación pendiente (terreno real, "aire"/"fantasma") no debe
	# poder aplicarse ya sin edificio; el relleno pendiente sigue como
	# relleno huérfano (ver surtir_construccion()).
	if edificio_relleno_cola.has(id):
		Construccion.descartar_pendientes(edificio_relleno_cola[id], ["aire", "fantasma"])
	edificio_relleno_cola.erase(id)
	for celda_despeje in edificio_despeje.get(id, []):
		if celda_a_despeje.has(celda_despeje):
			celda_a_despeje[celda_despeje].erase(id)
			if celda_a_despeje[celda_despeje].is_empty():
				celda_a_despeje.erase(celda_despeje)
	edificio_despeje.erase(id)
	return esquina


## Arranca un edificio fantasma. "orden_relleno"/"tipos_relleno" son las
## celdas de nivelación de terreno (si las hay) — siguen pasando por
## "fantasma" y su propia cola de un solo sentido en Construccion.gd,
## exactamente igual que antes de este rediseño (nunca se registran como
## parte del edificio, ver spec anterior punto 2.5). "orden_estructura" (ya
## en el orden canónico de ordenar_celdas_edificio()) y "tipos_estructura"
## son las celdas del edificio en sí — esas NO pasan por Construccion.gd:
## se registran directamente en edificio_orden/edificio_tipos/
## edificio_progreso (progreso arranca en 0, todas fantasma). Devuelve el
## id nuevo. orden_relleno/tipos_relleno pueden incluir, ANTES del relleno,
## celdas de excavación (terreno real) con tipo "aire" o "fantasma" — ver
## _aplicar_paso_cola().
func iniciar_construccion_fantasma(orden_relleno: Array, tipos_relleno: Dictionary, orden_estructura: Array, tipos_estructura: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden_relleno:
		colocar_bloque(celda, "fantasma")
	for celda in orden_estructura:
		colocar_bloque(celda, "fantasma")
	var id: int = registrar_edificio(orden_estructura)
	if not orden_relleno.is_empty():
		edificio_relleno_cola[id] = Construccion.iniciar(orden_relleno, tipos_relleno)
	edificio_orden[id] = orden_estructura
	edificio_tipos[id] = tipos_estructura
	edificio_progreso[id] = 0
	edificio_metadata[id] = metadata
	var despeje: Array = calcular_despeje(tipos_estructura)
	edificio_despeje[id] = despeje
	for celda_despeje in despeje:
		if not celda_a_despeje.has(celda_despeje):
			celda_a_despeje[celda_despeje] = {}
		celda_a_despeje[celda_despeje][id] = true
	return id


## Registra un edificio YA terminado (todas sus celdas reales desde el
## inicio) — usado por Player._declarar_edificio() para que un edificio
## declarado a mano (nunca pasó por iniciar_construccion_fantasma()) tenga
## el mismo edificio_orden/edificio_progreso que uno construido por
## blueprint, y así pueda deconstruirse y volver a completarse igual que
## cualquier otro. "celdas_mundo" es Vector3i real -> tipo (todas las
## celdas estructurales ya colocadas). Devuelve el id nuevo.
func registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int:
	var orden: Array = ordenar_celdas_edificio(celdas_mundo)
	var id: int = registrar_edificio(orden)
	edificio_orden[id] = orden
	edificio_tipos[id] = celdas_mundo
	edificio_progreso[id] = orden.size()
	edificio_metadata[id] = metadata
	var despeje: Array = calcular_despeje(celdas_mundo)
	edificio_despeje[id] = despeje
	for celda_despeje in despeje:
		if not celda_a_despeje.has(celda_despeje):
			celda_a_despeje[celda_despeje] = {}
		celda_a_despeje[celda_despeje][id] = true
	return id


## Aplica un paso ya avanzado de la cola de preparación del terreno (ver
## Construccion.avanzar()): "resultado" trae {"celda", "tipo"}. "tierra"
## (relleno) convierte la celda fantasma en bloque real. "aire" y "fantasma"
## son EXCAVACIÓN: la celda es terreno real y se retira; "fantasma" indica
## que además pertenece a la estructura del edificio (p. ej. la losa
## enterrada) y por eso queda como fantasma en vez de vacía.
func _aplicar_paso_cola(resultado: Dictionary) -> void:
	var celda: Vector3i = resultado["celda"]
	var tipo: String = resultado["tipo"]
	if tipo == "aire" or tipo == "fantasma":
		_retirar_bloque(celda)
		if tipo == "fantasma":
			colocar_bloque(celda, "fantasma")
		return
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocar_bloque(celda, tipo, true)


## Avanza, según a qué pertenezca "celda": si todavía es parte de una cola
## de RELLENO activa en Construccion.gd sin dueño (una celda de nivelación
## suelta, de un edificio ya eliminado — ver eliminar_edificio()), avanza
## esa cola directamente. En cualquier otro caso, busca el edificio por
## id_de_edificio() — sirve apuntar a CUALQUIER celda del GRUPO (relleno o
## estructura) para avanzarlo. Mientras ese edificio tenga una cola de
## relleno pendiente en edificio_relleno_cola, SIEMPRE se avanza esa cola
## primero, sin importar a qué celda del grupo se haya apuntado — el
## jugador interactúa con "el grupo" edificio+relleno como una sola
## unidad, y el relleno debe completarse antes de que la estructura
## empiece a surtirse. Una vez agotada la cola de relleno (o si el
## edificio nunca tuvo relleno), avanza la SIGUIENTE celda pendiente en
## edificio_orden, sin importar si "celda" en sí ya es real. No-op ({}) si
## "celda" no pertenece a ningún relleno huérfano NI a ningún edificio con
## progreso incompleto.
func surtir_construccion(celda: Vector3i) -> Dictionary:
	var id_relleno_huerfano: int = Construccion.construccion_de(celda)
	if id_relleno_huerfano != -1 and id_de_edificio(celda) == -1:
		var resultado_relleno: Dictionary = Construccion.avanzar(id_relleno_huerfano)
		if resultado_relleno.is_empty():
			return {}
		_aplicar_paso_cola(resultado_relleno)
		return {"completa": false, "metadata": {}}

	var id: int = id_de_edificio(celda)
	if id == -1:
		return {}

	if edificio_relleno_cola.has(id):
		var id_cola_relleno: int = edificio_relleno_cola[id]
		var resultado_grupo: Dictionary = Construccion.avanzar(id_cola_relleno)
		if not resultado_grupo.is_empty():
			_aplicar_paso_cola(resultado_grupo)
			if resultado_grupo["completa"]:
				edificio_relleno_cola.erase(id)
			return {"completa": false, "metadata": {}}
		edificio_relleno_cola.erase(id)

	if not edificio_orden.has(id):
		return {}
	var orden: Array = edificio_orden[id]
	var progreso: int = edificio_progreso[id]
	if progreso >= orden.size():
		return {}
	var celda_a_surtir: Vector3i = orden[progreso]
	var tipo: String = edificio_tipos[id][celda_a_surtir]
	set_cell_item(celda_a_surtir, GridMap.INVALID_CELL_ITEM)
	colocar_bloque(celda_a_surtir, tipo, true)
	edificio_progreso[id] = progreso + 1
	var completa: bool = edificio_progreso[id] == orden.size()
	if completa:
		reemparejar_construccion(orden)
	return {"completa": completa, "metadata": edificio_metadata[id]}


## Reconstruye "pareja" para las celdas de una construcción recién
## completada (puertas y camas colocadas por surtir_construccion() una a
## una, sin pasar por colocar_puerta()/colocar_cama(), así que no registran
## "pareja" automáticamente al construirse). Empareja cada "puerta_inferior"
## con la celda justo encima si es "puerta_superior", y cada
## "cama_cabecera" con un vecino horizontal (X o Z) que sea "cama_pies" —
## mismo criterio geométrico que colocar_puerta()/colocar_cama() ya usan al
## construir a mano. Sin esto, minar una puerta/cama de una construcción
## terminada no borraría su mitad opuesta (ver minar_bloque()).
func reemparejar_construccion(celdas: Array) -> void:
	for celda in celdas:
		var tipo: String = obtener_tipo(celda)
		if tipo == "puerta_inferior":
			var arriba: Vector3i = celda + Vector3i(0, 1, 0)
			if obtener_tipo(arriba) == "puerta_superior":
				pareja[celda] = arriba
				pareja[arriba] = celda
		elif tipo == "cama_cabecera":
			for direccion in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var vecino: Vector3i = celda + direccion
				if obtener_tipo(vecino) == "cama_pies":
					pareja[celda] = vecino
					pareja[vecino] = celda
					break


## Reemplaza cada bloque "agua" de la columna (x, z) por "tierra", desde la
## altura real del terreno (altura_en(x, z, true), que ignora el agua) hasta
## la superficie de agua actual. Usada al confirmar un puesto periférico
## cuya huella pisa el agua (ver CamaraCenital.gd) — la construcción "seca"
## la columna bajo de sí en vez de flotar sobre el agua. set_cell_item()
## directo (no colocar_bloque()): el propio bucle ya confirma con
## obtener_tipo() que cada celda es "agua" antes de reemplazarla, así que
## repetir esa comprobación de ocupación dentro de colocar_bloque() sería
## redundante, y drenar_agua() no es una acción del jugador ni necesita su
## valor de retorno o el registro en colocado_por_jugador. Devuelve cuántos
## bloques de agua se reemplazaron (0 si la columna no tenía agua).
func drenar_agua(x: int, z: int) -> int:
	var y: int = altura_en(x, z, true) + 1
	var reemplazados := 0
	while obtener_tipo(Vector3i(x, y, z)) == "agua":
		set_cell_item(Vector3i(x, y, z), _id_por_tipo["tierra"])
		_nivel_agua.erase(Vector3i(x, y, z))
		_encolar_secado_alrededor(Vector3i(x, y, z))
		bloque_translucido_cambiado.emit(Vector3i(x, y, z))
		y += 1
		reemplazados += 1
	return reemplazados
