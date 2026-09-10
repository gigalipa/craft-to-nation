extends GridMap

## Mundo voxel acotado sobre GridMap + MeshLibrary (assets/BlockLibrary.res,
## generada desde scenes/BlockLibrarySource.tscn). Reemplaza la versión previa
## de celdas por código (MeshInstance3D/StaticBody3D manuales) ahora que el
## editor de Godot está disponible para exportar la MeshLibrary.

const TAMANO_CELDA := 1.0

const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")
const GeneradorArbol = preload("res://scripts/GeneradorArbol.gd")

const ANCHO_MUNDO := 200
const LARGO_MUNDO := 200
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
## (GeneradorMundo.ALTURA_MAXIMA = 15) y el subsuelo generado por debajo.
const ALTURA_BUSQUEDA_MAX := 50
const ALTURA_BUSQUEDA_MIN := -30

var generador: RefCounted
var arboles: RefCounted

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

## Tipos de bloque generados por _generar_arboles() — ver altura_en() más
## abajo. Bug reportado por el usuario jugando en vivo: altura_en()
## contaba cualquier bloque sólido como "el suelo", así que el overlay de
## zona (ZonaOverlay) y la colocación de minas (CamaraCenital) terminaban
## ubicándose sobre la copa de un árbol en vez del terreno real debajo.
const TIPOS_ARBOL := ["madera", "follaje"]

const VECINOS_3D: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
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


func _ready() -> void:
	cell_size = Vector3.ONE * TAMANO_CELDA
	_indexar_biblioteca()
	generador = GeneradorMundo.new(SEMILLA_MUNDO, ANCHO_MUNDO, LARGO_MUNDO)
	arboles = GeneradorArbol.new()
	_generar_terreno()
	_generar_arboles()


func _indexar_biblioteca() -> void:
	for id in mesh_library.get_item_list():
		var nombre: String = mesh_library.get_item_name(id)
		_id_por_tipo[nombre] = id
		_tipo_por_id[id] = nombre


## Genera el mundo una única vez al arrancar la escena: para cada columna
## (x, z) coloca la celda de superficie ("piso", reutilizando el bloque
## caminable existente) y el subsuelo debajo (tierra cerca de la
## superficie, piedra más profundo, o vetas de "hierro" en la capa profunda
## — ver GeneradorMundo.tipo_en_profundidad), y si la columna queda por
## debajo del nivel de mar, agrega bloques "agua" encima de la superficie
## hasta ese nivel (ver GeneradorMundo.es_agua_en/nivel_mar).
## Ninguna de estas celdas se marca colocado_por_jugador: el terreno del
## mundo nunca puede ser parte de un edificio declarado por el jugador.
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var y: int = altura - profundidad
				var tipo: String = generador.tipo_en_profundidad(x, y, z, profundidad)
				colocar_bloque(Vector3i(x, y, z), tipo)
			if generador.es_agua_en(x, z):
				for y_agua in range(altura + 1, generador.nivel_mar + 1):
					colocar_bloque(Vector3i(x, y_agua, z), "agua")


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
## el agua como la superficie caminable/sólida que es hoy.
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
	if get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
		return false
	if not _id_por_tipo.has(tipo):
		return false
	set_cell_item(celda, _id_por_tipo[tipo])
	if por_jugador:
		colocado_por_jugador[celda] = true
	return true


func minar_bloque(celda: Vector3i) -> bool:
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	return true


func obtener_tipo(celda: Vector3i) -> String:
	return _tipo_por_id.get(get_cell_item(celda), "")


func _celda_libre(celda: Vector3i) -> bool:
	return get_cell_item(celda) == GridMap.INVALID_CELL_ITEM


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


## Revisa cada columna (x, z) de la huella ancho×alto con esquina "esquina".
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
func verificar_huella_libre(esquina: Vector2i, ancho: int, alto: int, altura: int = 1) -> Dictionary:
	var valida := true
	var follaje_a_eliminar: Array[Vector3i] = []
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
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
			if generador.es_agua_en(cx, cz):
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


## Coloca el bloque placeholder "fantasma" en cada celda de "orden" (en el
## mundo real, con colisión) y registra la construcción en Construccion.gd.
## "tipos" mapea cada celda de "orden" a su tipo real de destino, "metadata"
## se guarda intacta para cuando la construcción se complete (ver
## Construccion.iniciar()). No marca colocado_por_jugador todavía: estas
## celdas no son estructura real hasta que se conviertan (ver
## surtir_construccion()).
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	return Construccion.iniciar(orden, tipos, metadata)


## Convierte la siguiente celda pendiente de la construcción a la que
## pertenece "celda_fantasma" (que puede ser cualquier celda fantasma de esa
## construcción, no necesariamente la que se va a convertir — ver
## Construccion.avanzar()). Devuelve {} si no había ninguna construcción en
## esa celda; si no, {"completa": bool, "metadata": Dictionary} — el
## llamador (Player.gd) decide qué hacer al completarse (registrar en
## Ciudad, etc.) usando "metadata". Al completarse, reempareja puertas/camas
## de la construcción antes de devolver (ver reemparejar_construccion()).
func surtir_construccion(celda_fantasma: Vector3i) -> Dictionary:
	var id: int = Construccion.construccion_de(celda_fantasma)
	if id == -1:
		return {}
	var resultado: Dictionary = Construccion.avanzar(id)
	if resultado.is_empty():
		return {}
	set_cell_item(resultado["celda"], GridMap.INVALID_CELL_ITEM)
	colocar_bloque(resultado["celda"], resultado["tipo"], true)
	if resultado["completa"]:
		reemparejar_construccion(resultado["orden"])
	return {"completa": resultado["completa"], "metadata": resultado["metadata"]}


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
## directo (no colocar_bloque(), que rechaza celdas ya ocupadas): el agua ya
## ocupa esas celdas. Devuelve cuántos bloques de agua se reemplazaron (0 si
## la columna no tenía agua).
func drenar_agua(x: int, z: int) -> int:
	var y: int = altura_en(x, z, true) + 1
	var reemplazados := 0
	while obtener_tipo(Vector3i(x, y, z)) == "agua":
		set_cell_item(Vector3i(x, y, z), _id_por_tipo["tierra"])
		y += 1
		reemplazados += 1
	return reemplazados
