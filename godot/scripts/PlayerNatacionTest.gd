extends Node

## Pruebas aisladas de Player._profundidad_agua_en_pies() (mismo patrón que
## NiveladorTerrenoTest.gd: un "mundo" falso y determinista en vez de
## VoxelWorld real). Corre esta escena (PlayerNatacionTest.tscn) con F6 y
## revisa el panel "Output": debe imprimir las 4 pruebas y no debe lanzar
## ningún error de assert().

const Player = preload("res://scripts/Player.gd")


## Mundo falso: mapea celdas de grilla a un tipo de bloque ("agua" por
## defecto en las listadas, "aire" en cualquier otra). to_local()/
## local_to_map() son identidad/piso, porque el mundo falso no tiene
## transform propio (equivalente a un GridMap sin rotar en el origen).
class MundoFalso extends Node:
	var celdas_agua: Dictionary = {}  # Vector3i -> true

	func obtener_tipo(celda: Vector3i) -> String:
		return "agua" if celdas_agua.has(celda) else "aire"

	func to_local(global_pos: Vector3) -> Vector3:
		return global_pos

	func local_to_map(local_pos: Vector3) -> Vector3i:
		return Vector3i(floor(local_pos.x), floor(local_pos.y), floor(local_pos.z))


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

	jugador.free()
	print("\n=== Las 4 pruebas de Player._profundidad_agua_en_pies() pasaron correctamente ===")
