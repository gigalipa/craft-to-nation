extends Node

## Pruebas aisladas de Player._profundidad_agua_en_pies() y de las funciones
## puras de empuje de corriente/cascada (_empuje_rio()/_empuje_base_cascada(),
## Sección diseño 2026-09-17) (mismo patrón que NiveladorTerrenoTest.gd: un
## "mundo" falso y determinista en vez de VoxelWorld real). Corre esta escena
## (PlayerNatacionTest.tscn) con F6 y revisa el panel "Output": debe imprimir
## las 9 pruebas y no debe lanzar ningún error de assert().

const Player = preload("res://scripts/Player.gd")
const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")


## Mundo falso: mapea celdas de grilla a un tipo de bloque ("agua" por
## defecto en las listadas, "aire" en cualquier otra). to_local()/
## local_to_map() son identidad/piso, porque el mundo falso no tiene
## transform propio (equivalente a un GridMap sin rotar en el origen).
class MundoFalso extends Node:
	var celdas_agua: Dictionary = {}  # Vector3i -> true
	var corriente_por_celda: Dictionary = {}  # Vector2i(x,z) -> Dictionary
	var cascada_por_celda: Dictionary = {}  # Vector2i(x,z) -> Dictionary

	func obtener_tipo(celda: Vector3i) -> String:
		return "agua" if celdas_agua.has(celda) else "aire"

	func to_local(global_pos: Vector3) -> Vector3:
		return global_pos

	func local_to_map(local_pos: Vector3) -> Vector3i:
		return Vector3i(floor(local_pos.x), floor(local_pos.y), floor(local_pos.z))

	func corriente_en(x: int, z: int) -> Dictionary:
		return corriente_por_celda.get(Vector2i(x, z), {})

	func columna_cascada_en(x: int, z: int) -> Dictionary:
		return cascada_por_celda.get(Vector2i(x, z), {})


func _agua_en_columna(mundo: MundoFalso, x: int, z: int, y_desde: int, y_hasta: int) -> void:
	for y in range(y_desde, y_hasta + 1):
		mundo.celdas_agua[Vector3i(x, y, z)] = true


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	var jugador := Player.new()

	print("=== TEST 1: pies fuera del agua -> profundidad 0 ===")
	var mundo_seco := MundoFalso.new()
	jugador.mundo = mundo_seco
	print("Profundidad: ", jugador._profundidad_agua_en(Vector3(0, 5, 0)), " (esperada: 0)")
	assert(jugador._profundidad_agua_en(Vector3(0, 5, 0)) == 0)

	print("\n=== TEST 2: charco de 1 solo bloque -> profundidad 1 (no alcanza para nadar) ===")
	var mundo_charco := MundoFalso.new()
	_agua_en_columna(mundo_charco, 0, 0, 5, 5)
	jugador.mundo = mundo_charco
	print("Profundidad: ", jugador._profundidad_agua_en(Vector3(0, 5, 0)), " (esperada: 1)")
	assert(jugador._profundidad_agua_en(Vector3(0, 5, 0)) == 1)

	print("\n=== TEST 3: agua de 3 bloques — en el bloque superior la profundidad sigue siendo 1 ===")
	var mundo_profundo := MundoFalso.new()
	_agua_en_columna(mundo_profundo, 0, 0, 5, 7)  # y=5 (fondo) .. y=7 (superficie)
	jugador.mundo = mundo_profundo
	print("Profundidad en el bloque superior (y=7): ", jugador._profundidad_agua_en(Vector3(0, 7, 0)), " (esperada: 1)")
	assert(jugador._profundidad_agua_en(Vector3(0, 7, 0)) == 1)

	print("\n=== TEST 4: mismo cuerpo de agua — al hundirse al 2do bloque, la profundidad sube a 2 (y a 3 en el fondo) ===")
	print("Profundidad en el 2do bloque (y=6): ", jugador._profundidad_agua_en(Vector3(0, 6, 0)), " (esperada: 2)")
	assert(jugador._profundidad_agua_en(Vector3(0, 6, 0)) == 2)
	print("Profundidad en el fondo (y=5): ", jugador._profundidad_agua_en(Vector3(0, 5, 0)), " (esperada: 3)")
	assert(jugador._profundidad_agua_en(Vector3(0, 5, 0)) == 3)

	print("\n=== TEST 5: _empuje_rio() crece con la caída hasta el umbral de cascada, sin ser nunca 0 en llano ===")
	var empuje_llano: float = Player._empuje_rio(0)
	var empuje_pendiente: float = Player._empuje_rio(1)
	var empuje_umbral: float = Player._empuje_rio(GeneradorMundo.UMBRAL_CASCADA)
	var empuje_mas_alla: float = Player._empuje_rio(GeneradorMundo.UMBRAL_CASCADA + 5)
	print("Empuje llano (caida=0): ", empuje_llano, " (esperado > 0)")
	assert(empuje_llano > 0.0)
	assert(empuje_pendiente > empuje_llano)
	assert(empuje_umbral > empuje_pendiente)
	# Más allá del umbral de cascada, el empuje de RÍO satura (el empuje
	# relevante pasa a ser el de pie de cascada, ver TEST 6).
	assert(is_equal_approx(empuje_mas_alla, empuje_umbral))

	print("\n=== TEST 6: _empuje_base_cascada() satura entre un salto justo en el umbral y uno grande ===")
	var empuje_base_umbral: float = Player._empuje_base_cascada(GeneradorMundo.UMBRAL_CASCADA)
	var empuje_base_medio: float = Player._empuje_base_cascada(GeneradorMundo.UMBRAL_CASCADA + 4)
	var empuje_base_grande: float = Player._empuje_base_cascada(Player.CAIDA_EMPUJE_SATURA)
	var empuje_base_mas_alla: float = Player._empuje_base_cascada(Player.CAIDA_EMPUJE_SATURA + 10)
	print("Empuje de pie de cascada — umbral: ", empuje_base_umbral, ", grande: ", empuje_base_grande)
	assert(is_equal_approx(empuje_base_umbral, Player.EMPUJE_CASCADA_BASE_MINIMO))
	assert(empuje_base_medio > empuje_base_umbral and empuje_base_medio < empuje_base_grande)
	assert(is_equal_approx(empuje_base_grande, Player.EMPUJE_CASCADA_BASE_MAXIMO))
	assert(is_equal_approx(empuje_base_mas_alla, Player.EMPUJE_CASCADA_BASE_MAXIMO))

	jugador.free()

	print("\n=== TEST 7: _procesar_corriente() NO empuja si la celda de los pies no es agua real, aunque el generador la marque como río/cascada ===")
	# Reproduce el bug real (2026-09-18): un pasillo minado detrás de una
	# cascada sigue devolviendo corriente_en()/columna_cascada_en() no vacíos
	# (datos estáticos del generador, no saben que el jugador vació la
	# celda) — sin el chequeo de agua real en _procesar_corriente(), el
	# empuje seguía "halando" al jugador hacia afuera del pasillo seco.
	var mundo_pasillo_seco := MundoFalso.new()
	mundo_pasillo_seco.corriente_por_celda[Vector2i(0, 0)] = {"direccion": Vector2i(1, 0), "caida": 5}
	mundo_pasillo_seco.cascada_por_celda[Vector2i(0, 0)] = {"y_base": 0, "caida": 5, "direccion": Vector2i(1, 0)}
	var jugador_seco := Player.new()
	jugador_seco.mundo = mundo_pasillo_seco
	jugador_seco.velocity = Vector3.ZERO
	jugador_seco._procesar_corriente(Vector3i(0, 0, 0))
	print("Velocidad tras _procesar_corriente() en celda seca: ", jugador_seco.velocity, " (esperada: (0,0,0))")
	assert(jugador_seco.velocity == Vector3.ZERO)
	jugador_seco.free()

	print("\n=== TEST 8: _procesar_corriente() SÍ empuja cuando la celda de los pies es agua real ===")
	var mundo_con_agua := MundoFalso.new()
	mundo_con_agua.celdas_agua[Vector3i(0, 0, 0)] = true
	mundo_con_agua.corriente_por_celda[Vector2i(0, 0)] = {"direccion": Vector2i(1, 0), "caida": 0}
	var jugador_mojado := Player.new()
	jugador_mojado.mundo = mundo_con_agua
	jugador_mojado.velocity = Vector3.ZERO
	jugador_mojado._procesar_corriente(Vector3i(0, 0, 0))
	print("Velocidad tras _procesar_corriente() en agua real: ", jugador_mojado.velocity, " (esperada: x > 0)")
	assert(jugador_mojado.velocity.x > 0.0)
	jugador_mojado.free()

	print("\n=== TEST 9: _limitar_al_mundo() confina la posición al mapa ===")
	var dentro := Vector3(50.0, 12.5, 80.0)
	assert(Player._limitar_al_mundo(dentro, 200, 200) == dentro, "dentro del mapa no cambia")
	assert(Player._limitar_al_mundo(Vector3(-3.0, 7.0, 10.0), 200, 200) == Vector3(0.4, 7.0, 10.0), "x < 0 -> radio")
	assert(Player._limitar_al_mundo(Vector3(250.0, 7.0, 10.0), 200, 200) == Vector3(199.6, 7.0, 10.0), "x > ancho -> ancho - radio")
	assert(Player._limitar_al_mundo(Vector3(10.0, 7.0, -3.0), 200, 150) == Vector3(10.0, 7.0, 0.4), "z < 0 -> radio")
	assert(Player._limitar_al_mundo(Vector3(10.0, 7.0, 300.0), 200, 150) == Vector3(10.0, 7.0, 149.6), "z > largo -> largo - radio")
	assert(Player._limitar_al_mundo(Vector3(-9.0, -500.0, 999.0), 200, 200).y == -500.0, "y nunca se modifica")
	var en_limite := Vector3(0.4, 3.0, 199.6)
	assert(Player._limitar_al_mundo(en_limite, 200, 200) == en_limite, "exactamente en el límite no cambia")

	print("\n=== Las 9 pruebas de Player pasaron correctamente ===")
