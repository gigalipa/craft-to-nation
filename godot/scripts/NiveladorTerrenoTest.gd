extends Node

## Pruebas aisladas de NiveladorTerreno.gd (mismo patrón que
## ZonificacionTest.gd). Corre esta escena (NiveladorTerrenoTest.tscn) con
## F6 y revisa el panel "Output": debe imprimir las pruebas y no debe
## lanzar ningún error de assert(). Usa un generador de alturas falso y
## determinista (no GeneradorMundo real, que usa ruido) para poder construir
## pendientes exactas y verificar el cálculo de relleno con precisión.

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")


## Generador falso: la altura crece 1 celda por cada paso en Z (pendiente de
## 1, dentro del límite de 2) y es constante en X.
class GeneradorRampaSuave:
	func altura_en(_x: int, z: int) -> int:
		return z


## Generador falso: la altura crece 3 celdas por cada paso en Z (pendiente
## de 3, fuera del límite de 2).
class GeneradorRampaPronunciada:
	func altura_en(_x: int, z: int) -> int:
		return z * 3


## Generador falso: altura constante (terreno plano, sin pendiente).
class GeneradorPlano:
	func altura_en(_x: int, _z: int) -> int:
		return 5


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Pendiente suave (1 por celda) se acepta ===")
	var nivelador_suave: RefCounted = NiveladorTerreno.new(GeneradorRampaSuave.new())
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0)))

	print("\n=== TEST 2: Pendiente pronunciada (3 por celda) se rechaza ===")
	var nivelador_pronunciado: RefCounted = NiveladorTerreno.new(GeneradorRampaPronunciada.new())
	assert(not nivelador_pronunciado.verificar_pendiente(Vector2i(0, 0)))

	print("\n=== TEST 3: Terreno plano no necesita relleno ===")
	var nivelador_plano: RefCounted = NiveladorTerreno.new(GeneradorPlano.new())
	assert(nivelador_plano.verificar_pendiente(Vector2i(0, 0)))
	var relleno_plano: Dictionary = nivelador_plano.calcular_relleno(Vector2i(0, 0))
	print("Relleno en terreno plano: ", relleno_plano.size(), " celdas (esperadas: 0)")
	assert(relleno_plano.is_empty())

	print("\n=== TEST 4: Relleno correcto sobre una rampa suave (huella 5x5) ===")
	# Huella de (0,0) a (4,4): altura_en(x,z) = z, así que la fila z=4 es la
	# más alta (altura 4) y las demás necesitan relleno hasta llegar a 4:
	# z=0 -> 4 de relleno (x5 celdas), z=1 -> 3, z=2 -> 2, z=3 -> 1, z=4 -> 0.
	# Total: (4+3+2+1+0) * 5 = 50.
	var relleno_rampa: Dictionary = nivelador_suave.calcular_relleno(Vector2i(0, 0))
	var total_relleno := 0
	for cantidad in relleno_rampa.values():
		total_relleno += cantidad
	print("Total de bloques de relleno: ", total_relleno, " (esperados: 50)")
	assert(total_relleno == 50)
	assert(relleno_rampa[Vector2i(0, 0)] == 4)
	assert(not relleno_rampa.has(Vector2i(0, 4)))  # ya está a la altura máxima

	print("\n=== TEST 5: verificar_pendiente() con ancho/alto explícitos (huella 4x3, no cuadrada) ===")
	# Rampa suave: altura_en(x,z) = z. Huella ancho=4, alto=3 desde (0,0): z
	# va de 0 a 2 (pendiente de 1 por celda, dentro del límite de 2) -> válida.
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0), 4, 3))
	# Rampa pronunciada (altura_en = z*3): cualquier huella con alto>=2 sigue
	# rechazándose.
	assert(not nivelador_pronunciado.verificar_pendiente(Vector2i(0, 0), 4, 3))

	print("\n=== TEST 6: llamar sin ancho/alto sigue siendo la huella cuadrada de siempre ===")
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0)) \
			== nivelador_suave.verificar_pendiente(Vector2i(0, 0), NiveladorTerreno.TAMANO_HUELLA, NiveladorTerreno.TAMANO_HUELLA))

	print("\n=== Las 6 pruebas de NiveladorTerreno pasaron correctamente ===")
