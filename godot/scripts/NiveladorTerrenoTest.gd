extends Node

## Pruebas aisladas de NiveladorTerreno.gd (mismo patrón que
## ZonificacionTest.gd). Corre esta escena (NiveladorTerrenoTest.tscn) con
## F6 y revisa el panel "Output": debe imprimir las 7 pruebas y no debe
## lanzar ningún error de assert(). Usa un generador de alturas falso y
## determinista (no GeneradorMundo real, que usa ruido) para poder construir
## pendientes exactas y verificar el cálculo de relleno con precisión.
##
## verificar_pendiente()/altura_objetivo()/calcular_relleno() reciben
## "columnas": Array[Vector2i] de offsets relativos a "esquina" (ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md) — un
## rectángulo es solo un caso particular (todas las columnas de
## range(ancho) x range(alto)), generado aquí mismo con _rectangulo() sin
## depender de ningún helper compartido con CamaraCenital.gd.

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


## Generador falso: altura constante (3) salvo en (2, 2), un "acantilado"
## (altura 100) — usado para probar que una columna FUERA de la lista de
## columnas de la huella nunca se compara, sin importar cuán extremo sea su
## desnivel real (ver TEST 6/7).
class GeneradorConAcantilado:
	func altura_en(x: int, z: int) -> int:
		if x == 2 and z == 2:
			return 100
		return 3


func _rectangulo(ancho: int, alto: int) -> Array[Vector2i]:
	var columnas: Array[Vector2i] = []
	for x in range(ancho):
		for z in range(alto):
			columnas.append(Vector2i(x, z))
	return columnas


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Pendiente suave (1 por celda) se acepta ===")
	var nivelador_suave: RefCounted = NiveladorTerreno.new(GeneradorRampaSuave.new())
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0), _rectangulo(5, 5)))

	print("\n=== TEST 2: Pendiente pronunciada (3 por celda) se rechaza ===")
	var nivelador_pronunciado: RefCounted = NiveladorTerreno.new(GeneradorRampaPronunciada.new())
	assert(not nivelador_pronunciado.verificar_pendiente(Vector2i(0, 0), _rectangulo(5, 5)))

	print("\n=== TEST 3: Terreno plano no necesita relleno ===")
	var nivelador_plano: RefCounted = NiveladorTerreno.new(GeneradorPlano.new())
	assert(nivelador_plano.verificar_pendiente(Vector2i(0, 0), _rectangulo(5, 5)))
	var relleno_plano: Dictionary = nivelador_plano.calcular_relleno(Vector2i(0, 0), _rectangulo(5, 5))
	print("Relleno en terreno plano: ", relleno_plano.size(), " celdas (esperadas: 0)")
	assert(relleno_plano.is_empty())

	print("\n=== TEST 4: Relleno correcto sobre una rampa suave (huella 5x5) ===")
	# Huella de (0,0) a (4,4): altura_en(x,z) = z, así que la fila z=4 es la
	# más alta (altura 4) y las demás necesitan relleno hasta llegar a 4:
	# z=0 -> 4 de relleno (x5 celdas), z=1 -> 3, z=2 -> 2, z=3 -> 1, z=4 -> 0.
	# Total: (4+3+2+1+0) * 5 = 50.
	var relleno_rampa: Dictionary = nivelador_suave.calcular_relleno(Vector2i(0, 0), _rectangulo(5, 5))
	var total_relleno := 0
	for cantidad in relleno_rampa.values():
		total_relleno += cantidad
	print("Total de bloques de relleno: ", total_relleno, " (esperados: 50)")
	assert(total_relleno == 50)
	assert(relleno_rampa[Vector2i(0, 0)] == 4)
	assert(not relleno_rampa.has(Vector2i(0, 4)))  # ya está a la altura máxima

	print("\n=== TEST 5: verificar_pendiente() con columnas no cuadradas (huella 4x3) ===")
	# Rampa suave: altura_en(x,z) = z. Huella ancho=4, alto=3 desde (0,0): z
	# va de 0 a 2 (pendiente de 1 por celda, dentro del límite de 2) -> válida.
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0), _rectangulo(4, 3)))
	# Rampa pronunciada (altura_en = z*3): cualquier huella con alto>=2 sigue
	# rechazándose.
	assert(not nivelador_pronunciado.verificar_pendiente(Vector2i(0, 0), _rectangulo(4, 3)))

	print("\n=== TEST 6: verificar_pendiente() con huella irregular ignora columnas fuera de la lista ===")
	# Huella en L (cuadrado 3x3 menos la esquina (2,2)): 8 columnas en vez de
	# las 9 del rectángulo completo. El generador pone un "acantilado"
	# (altura 100 vs. 3 en el resto) exactamente en (2,2), la columna
	# EXCLUIDA — verificar_pendiente() nunca la compara, así que la huella en
	# L sigue siendo válida pese al desnivel extremo que tendría si se
	# incluyera esa columna.
	var nivelador_acantilado: RefCounted = NiveladorTerreno.new(GeneradorConAcantilado.new())
	var columnas_l: Array[Vector2i] = _rectangulo(3, 3)
	columnas_l.erase(Vector2i(2, 2))
	assert(columnas_l.size() == 8)
	assert(nivelador_acantilado.verificar_pendiente(Vector2i(0, 0), columnas_l))
	# Control: el mismo generador, mismo origen, pero con el rectángulo
	# COMPLETO (incluyendo (2,2)) sí debe rechazarse — confirma que la
	# exclusión de (2,2) es la que hace la diferencia, no un fallo silencioso
	# del generador o de la huella.
	assert(not nivelador_acantilado.verificar_pendiente(Vector2i(0, 0), _rectangulo(3, 3)))

	print("\n=== TEST 7: altura_objetivo()/calcular_relleno() con huella irregular ignoran el acantilado ===")
	assert(nivelador_acantilado.altura_objetivo(Vector2i(0, 0), columnas_l) == 3)
	var relleno_l: Dictionary = nivelador_acantilado.calcular_relleno(Vector2i(0, 0), columnas_l)
	print("Relleno de la huella en L (acantilado excluido): ", relleno_l.size(), " celdas (esperadas: 0)")
	assert(relleno_l.is_empty())

	print("\n=== Las 7 pruebas de NiveladorTerreno pasaron correctamente ===")
