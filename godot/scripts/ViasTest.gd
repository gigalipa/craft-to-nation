extends Node

## Pruebas aisladas de Vias.gd/NiveladorVia.gd/TrazadorVias.gd/
## ConstructorVias.gd, sin escena visual — corre esta escena y revisa que
## no lance ningún assert(). Mismo patrón que ZonificacionTest.gd/
## NiveladorTerrenoTest.gd.

# Preloads de las clases de lógica pura probadas en este archivo:
const NiveladorVia = preload("res://scripts/NiveladorVia.gd")
const TrazadorVias = preload("res://scripts/TrazadorVias.gd")
const ConstructorVias = preload("res://scripts/ConstructorVias.gd")

## Generador falso: altura = x + z (una pendiente diagonal simple para
## probar niveles de bloque distintos entre vértices vecinos).
class GeneradorPendienteDiagonal:
	func altura_en(x: int, z: int) -> int:
		return x + z


## Generador falso: altura constante 10 en todo el mapa.
class GeneradorPlano:
	func altura_en(_x: int, _z: int) -> int:
		return 10


## Escalón: altura 0 para x<=5, altura 1 para x>5 (desnivel de 1 bloque).
class GeneradorEscalon:
	func altura_en(x: int, _z: int) -> int:
		return 1 if x > 5 else 0


## Escalón alto: altura 0 para x<=5, altura 3 para x>5 (desnivel de 3).
class GeneradorEscalonAlto:
	func altura_en(x: int, _z: int) -> int:
		return 3 if x > 5 else 0


## Mundo falso para TrazadorVias/ConstructorVias: terreno plano en
## altura_en() = 0, salvo un escalón opcional en X (escalon_en_x/
## altura_escalon), con columnas de agua/edificio marcables a mano.
class MundoFalsoVias:
	var celdas: Dictionary = {}  # Vector3i -> String
	var agua: Dictionary = {}  # Vector2i -> true
	var edificios: Dictionary = {}  # Vector2i -> true
	var escalon_en_x := 999999
	var altura_escalon := 0
	var colocado_por_jugador: Dictionary = {}
	var _ids: Dictionary = {
		"tierra": 1, "cuna_recta": 2, "cuna_esquina": 3,
		"cuna_diag_bajo": 4, "cuna_diag_arriba": 5, "cuna_diag_lat_izq": 6, "cuna_diag_lat_der": 7,
	}

	func altura_en(x: int, _z: int) -> int:
		return altura_escalon if x >= escalon_en_x else 0

	func obtener_tipo(celda: Vector3i) -> String:
		var xz := Vector2i(celda.x, celda.z)
		if agua.get(xz, false) and celda.y == altura_en(celda.x, celda.z) + 1:
			return "agua"
		return celdas.get(celda, "")

	func id_de_edificio(celda: Vector3i) -> int:
		var xz := Vector2i(celda.x, celda.z)
		return 1 if edificios.get(xz, false) else -1

	func colocar_bloque(celda: Vector3i, tipo: String, _por_jugador: bool = false) -> bool:
		celdas[celda] = tipo
		return true

	func talar_bloque_de_arbol(celda: Vector3i, _dano: int) -> bool:
		if celdas.get(celda, "") != "madera":
			return false
		celdas.erase(celda)
		return true

	func eliminar_follaje(celda: Vector3i) -> void:
		celdas.erase(celda)

	func set_cell_item(celda: Vector3i, id: int, _orientacion: int) -> void:
		for tipo in _ids:
			if _ids[tipo] == id:
				celdas[celda] = tipo
				return

	func id_de_tipo(tipo: String) -> int:
		return _ids.get(tipo, -1)


func _ready() -> void:
	ejecutar_pruebas()
	print("=== TODAS LAS PRUEBAS DE ViasTest PASARON ===")


func ejecutar_pruebas() -> void:
	print("=== TEST 1: agregar()/es_via()/tipo_en() ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var celda := Vector3i(5, 10, 5)
	assert(not Vias.es_via(celda))
	Vias.agregar([celda], "tierra_pisada")
	assert(Vias.es_via(celda))
	assert(Vias.tipo_en(celda) == "tierra_pisada")

	print("\n=== TEST 2: bono_en() ===")
	assert(is_equal_approx(Vias.bono_en(celda), 1.35))
	assert(is_equal_approx(Vias.bono_en(Vector3i(0, 0, 0)), 1.0))

	print("\n=== TEST 3: hay_via_en_columna() ===")
	assert(Vias.hay_via_en_columna(Vector2i(5, 5)))
	assert(not Vias.hay_via_en_columna(Vector2i(0, 0)))

	print("\n=== TEST 4: quitar() ===")
	Vias.quitar([celda])
	assert(not Vias.es_via(celda))
	assert(not Vias.hay_via_en_columna(Vector2i(5, 5)))

	print("\n=== TEST 5: quitar() una celda que no es vía es no-op ===")
	Vias.quitar([Vector3i(1, 1, 1)])  # no debe lanzar error

	print("\n=== TEST 6: bloque_de_vertice() — 4 columnas alrededor del vértice ===")
	var nivelador_plano := NiveladorVia.new(GeneradorPlano.new())
	var bloque: Array[Vector2i] = nivelador_plano.bloque_de_vertice(Vector2i(5, 5))
	assert(bloque.size() == 4)
	for esperado in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		assert(bloque.has(esperado))

	print("\n=== TEST 7: nivel_de_bloque() en terreno plano ===")
	assert(nivelador_plano.nivel_de_bloque(Vector2i(5, 5)) == 10)

	print("\n=== TEST 8: nivel_de_bloque() usa el máximo de las 4 columnas ===")
	var nivelador_diagonal := NiveladorVia.new(GeneradorPendienteDiagonal.new())
	# Vértice (1,1): columnas (0,0)=0, (1,0)=1, (0,1)=1, (1,1)=2 -> máximo 2.
	assert(nivelador_diagonal.nivel_de_bloque(Vector2i(1, 1)) == 2)

	print("\n=== TEST 9: plan_transicion() con desnivel 0 -> {} ===")
	assert(nivelador_plano.plan_transicion(Vector2i(5, 5), Vector2i(6, 5)).is_empty())

	print("\n=== TEST 10: plan_transicion() paso recto, desnivel 1 -> 2 cuñas rectas, sin relleno extra ===")
	# GeneradorEscalon: altura 0 para x<=5, altura 1 para x>5 (un escalón).
	var nivelador_escalon := NiveladorVia.new(GeneradorEscalon.new())
	var plan_recto: Dictionary = nivelador_escalon.plan_transicion(Vector2i(5, 5), Vector2i(6, 5))
	assert(not plan_recto.is_empty())
	assert(plan_recto["cunas"].size() == 2)  # paso recto: 2 columnas de solape, ambas cuna_recta
	for dato: Dictionary in plan_recto["cunas"]:
		assert(dato["tipo"] == "cuna_recta")
		assert(dato["direccion_alta"] == Vector2i(1, 0))
	assert(plan_recto["y_base"] == 0)
	assert(plan_recto["relleno_extra"].is_empty())

	print("\n=== TEST 11: plan_transicion() paso diagonal, desnivel 1 -> rampa completa de 7 piezas ===")
	var plan_diagonal: Dictionary = nivelador_escalon.plan_transicion(Vector2i(5, 5), Vector2i(6, 6))
	# 1 esquina (solape) + 2 bajo (vecinas de arista del bloque BAJO) + 2
	# arriba (vecinas de arista del bloque ALTO) + 2 remates laterales del
	# "diamante" de 3x3 — ver sistema completo de rampa diagonal
	# (docs/Rampa_CtN.obj). Las 2 columnas diagonal-opuestas de cada
	# bloque (una por bloque) siguen planas.
	assert(plan_diagonal["cunas"].size() == 7)
	var tipos_diagonal: Dictionary = {}
	for dato: Dictionary in plan_diagonal["cunas"]:
		tipos_diagonal[dato["tipo"]] = tipos_diagonal.get(dato["tipo"], 0) + 1
	assert(tipos_diagonal.get("cuna_esquina", 0) == 1)
	assert(tipos_diagonal.get("cuna_diag_bajo", 0) == 2)
	assert(tipos_diagonal.get("cuna_diag_arriba", 0) == 2)
	assert(tipos_diagonal.get("cuna_diag_lat_izq", 0) == 1)
	assert(tipos_diagonal.get("cuna_diag_lat_der", 0) == 1)

	print("\n=== TEST 12: plan_transicion() con desnivel 3 -> relleno_extra hasta quedar a 1 ===")
	# GeneradorEscalonAlto: altura 0 para x<=5, altura 3 para x>5.
	var nivelador_alto := NiveladorVia.new(GeneradorEscalonAlto.new())
	var plan_alto: Dictionary = nivelador_alto.plan_transicion(Vector2i(5, 5), Vector2i(6, 5))
	assert(plan_alto["y_base"] == 2)  # nivel_alto(3) - 1
	assert(not plan_alto["relleno_extra"].is_empty())
	for columna in plan_alto["relleno_extra"]:
		assert(plan_alto["relleno_extra"][columna] == 2)

	print("\n=== TEST 13: la MeshLibrary tiene todas las piezas de cuña ===")
	var biblioteca: MeshLibrary = preload("res://assets/BlockLibrary.res")
	var nombres: Dictionary = {}
	for id in biblioteca.get_item_list():
		nombres[biblioteca.get_item_name(id)] = true
	assert(nombres.has("cuna_recta"))
	assert(nombres.has("cuna_esquina"))
	assert(nombres.has("cuna_diag_bajo"))
	assert(nombres.has("cuna_diag_arriba"))
	assert(nombres.has("cuna_diag_lat_izq"))
	assert(nombres.has("cuna_diag_lat_der"))

	print("\n=== TEST 14: TrazadorVias — vecinos() da hasta 8 direcciones en terreno plano libre ===")
	var mundo_falso := MundoFalsoVias.new()
	var trazador := TrazadorVias.new(mundo_falso)
	var vecinos_5_5: Array[Vector2i] = trazador.vecinos(Vector2i(5, 5))
	assert(vecinos_5_5.size() == 8)

	print("\n=== TEST 15: TrazadorVias — un vértice con agua en su bloque no es transitable ===")
	mundo_falso.agua[Vector2i(4, 4)] = true  # una de las 4 columnas del bloque de (5,5)
	assert(not trazador.vertice_transitable(Vector2i(5, 5)))
	mundo_falso.agua.clear()

	print("\n=== TEST 16: TrazadorVias — un vértice con un edificio en su bloque no es transitable ===")
	mundo_falso.edificios[Vector2i(4, 4)] = true
	assert(not trazador.vertice_transitable(Vector2i(5, 5)))
	mundo_falso.edificios.clear()

	print("\n=== TEST 17: TrazadorVias — un árbol NO bloquea (se tala al confirmar) ===")
	mundo_falso.celdas[Vector3i(4, 1, 4)] = "madera"
	assert(trazador.vertice_transitable(Vector2i(5, 5)))
	mundo_falso.celdas.clear()

	print("\n=== TEST 18: TrazadorVias — buscar_ruta() en terreno plano ===")
	var ruta: Array[Vector2i] = trazador.buscar_ruta(Vector2i(0, 0), Vector2i(3, 0))
	assert(ruta.size() == 3)
	assert(ruta[-1] == Vector2i(3, 0))

	print("\n=== TEST 19: TrazadorVias — buscar_ruta() rechaza desnivel > 3 ===")
	var mundo_escalon := MundoFalsoVias.new()
	mundo_escalon.escalon_en_x = 3
	mundo_escalon.altura_escalon = 5  # desnivel de 5 entre x=2 y x=3, por encima del límite de 3
	var trazador_escalon := TrazadorVias.new(mundo_escalon)
	assert(trazador_escalon.buscar_ruta(Vector2i(0, 0), Vector2i(5, 0)).is_empty())

	print("\n=== TEST 20: ConstructorVias.construir() en terreno plano registra la vía ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_construir := MundoFalsoVias.new()
	var sin_choque := func(_c: Array) -> bool: return false
	var vertices_rectos: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert(ConstructorVias.construir(mundo_construir, vertices_rectos, sin_choque))
	# 3 vértices en línea recta: bloques (−1..0,−1..0), (0..1,−1..0), (1..2,−1..0)
	# se solapan de a 2 columnas -> 8 columnas de soporte distintas en total.
	var columnas_registradas: Dictionary = {}
	for celda_via in Vias.celdas:
		columnas_registradas[Vector2i(celda_via.x, celda_via.z)] = true
	assert(columnas_registradas.size() == 8)

	print("\n=== TEST 21: ConstructorVias.construir() rechaza si choca ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var con_choque := func(_c: Array) -> bool: return true
	assert(not ConstructorVias.construir(mundo_construir, vertices_rectos, con_choque))
	assert(Vias.celdas.is_empty())

	print("\n=== TEST 22: ConstructorVias.construir() con desnivel de 1 coloca cuna_recta en la celda correcta ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_escalon_construir := MundoFalsoVias.new()
	mundo_escalon_construir.escalon_en_x = 1
	mundo_escalon_construir.altura_escalon = 1
	var vertices_escalon: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	assert(ConstructorVias.construir(mundo_escalon_construir, vertices_escalon, sin_choque))
	# nivel(vertice (0,0)) = 0, nivel(vertice (1,0)) = 1 -> y_base = 0. La
	# cuña debe quedar en y_base+1 = 1 (ver C3): su cara inferior descansa
	# sobre la cara superior real del lado bajo (mundo Y=1), tendiendo el
	# puente hasta la cara superior del lado alto (mundo Y=2) — colocarla
	# en y_base=0 cavaría una zanja en vez de tender un puente. El solape
	# recto entre ambos bloques son las columnas (0,-1) y (0,0).
	assert(mundo_escalon_construir.celdas.get(Vector3i(0, 1, -1), "") == "cuna_recta")
	assert(mundo_escalon_construir.celdas.get(Vector3i(0, 1, 0), "") == "cuna_recta")
	assert(mundo_escalon_construir.celdas.get(Vector3i(0, 0, -1), "") != "cuna_recta")
	assert(mundo_escalon_construir.celdas.get(Vector3i(0, 0, 0), "") != "cuna_recta")

	print("\n=== TEST 23: ConstructorVias.construir() tala un árbol en el camino ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_arbol := MundoFalsoVias.new()
	mundo_arbol.celdas[Vector3i(0, 1, 0)] = "madera"  # dentro del bloque de vertice (0,0) o (1,0)
	assert(ConstructorVias.construir(mundo_arbol, [Vector2i(0, 0), Vector2i(1, 0)], sin_choque))
	assert(mundo_arbol.celdas.get(Vector3i(0, 1, 0), "") != "madera")

	print("\n=== TEST 24: ConstructorVias.construir() con menos de 2 vértices no hace nada ===")
	Vias.celdas.clear()
	assert(not ConstructorVias.construir(mundo_construir, [Vector2i(0, 0)], sin_choque))
	assert(Vias.celdas.is_empty())
	Vias.celdas.clear()
	Vias._columnas.clear()

	print("\n=== TEST 25: ConstructorVias.construir() con paso diagonal arma la rampa completa de 7 piezas ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_diagonal_construir := MundoFalsoVias.new()
	mundo_diagonal_construir.escalon_en_x = 1
	mundo_diagonal_construir.altura_escalon = 1
	var vertices_diagonal: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
	assert(ConstructorVias.construir(mundo_diagonal_construir, vertices_diagonal, sin_choque))
	# nivel(vertice (0,0)) = 0, nivel(vertice (1,1)) = 1 -> y_base = 0,
	# todas las cuñas quedan en y_base+1 = 1. El solape diagonal es la
	# columna (0,0). Sistema completo de rampa diagonal (ver
	# docs/Rampa_CtN.obj): 2 vecinas de arista del bloque BAJO ((0,-1) y
	# (-1,0)) llevan cuna_diag_bajo; 2 del bloque ALTO ((1,0) y (0,1))
	# llevan cuna_diag_arriba; los 2 remates del "diamante" de 3x3 ((1,-1)
	# y (-1,1)) llevan cuna_diag_lat_izq/cuna_diag_lat_der. Las 2 columnas
	# diagonal-opuestas de cada bloque ((-1,-1) y (1,1)) siguen planas.
	assert(mundo_diagonal_construir.celdas.get(Vector3i(0, 1, 0), "") == "cuna_esquina")
	assert(mundo_diagonal_construir.celdas.get(Vector3i(0, 1, -1), "") == "cuna_diag_bajo")
	assert(mundo_diagonal_construir.celdas.get(Vector3i(-1, 1, 0), "") == "cuna_diag_bajo")
	assert(mundo_diagonal_construir.celdas.get(Vector3i(1, 1, 0), "") == "cuna_diag_arriba")
	assert(mundo_diagonal_construir.celdas.get(Vector3i(0, 1, 1), "") == "cuna_diag_arriba")
	assert(mundo_diagonal_construir.celdas.get(Vector3i(1, 1, -1), "") == "cuna_diag_lat_izq")
	assert(mundo_diagonal_construir.celdas.get(Vector3i(-1, 1, 1), "") == "cuna_diag_lat_der")
	assert(mundo_diagonal_construir.celdas.get(Vector3i(-1, 0, -1), "") == "")  # diagonal-opuesta del bloque bajo (nivel 0), plana
	assert(mundo_diagonal_construir.celdas.get(Vector3i(1, 1, 1), "") == "")  # diagonal-opuesta del bloque alto (nivel 1), plana

	print("\n=== TEST 26: ConstructorVias.construir() con desnivel de 3 rellena hasta y_base antes de la cuña ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_alto_construir := MundoFalsoVias.new()
	mundo_alto_construir.escalon_en_x = 1
	mundo_alto_construir.altura_escalon = 3
	var vertices_alto: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	assert(ConstructorVias.construir(mundo_alto_construir, vertices_alto, sin_choque))
	# nivel(vertice (0,0)) = 0, nivel(vertice (1,0)) = 3 -> desnivel 3,
	# y_base = nivel_alto - 1 = 2. Las columnas del lado bajo que NO son
	# solape ((-1,-1) y (-1,0)) se rellenan de tierra hasta y=2; la cuña
	# (columnas de solape (0,-1) y (0,0)) queda en y_base+1 = 3.
	assert(mundo_alto_construir.celdas.get(Vector3i(-1, 1, -1), "") == "tierra")
	assert(mundo_alto_construir.celdas.get(Vector3i(-1, 2, -1), "") == "tierra")
	assert(mundo_alto_construir.celdas.get(Vector3i(-1, 1, 0), "") == "tierra")
	assert(mundo_alto_construir.celdas.get(Vector3i(-1, 2, 0), "") == "tierra")
	assert(mundo_alto_construir.celdas.get(Vector3i(0, 3, -1), "") == "cuna_recta")
	assert(mundo_alto_construir.celdas.get(Vector3i(0, 3, 0), "") == "cuna_recta")
