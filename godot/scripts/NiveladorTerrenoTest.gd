extends Node

## Pruebas aisladas de NiveladorTerreno.gd (mismo patrón que
## ZonificacionTest.gd). Corre esta escena (NiveladorTerrenoTest.tscn) con
## F6 y revisa el panel "Output": debe imprimir las 20 pruebas y no debe
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
const HUDScript = preload("res://scripts/HUD.gd")


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


## Generador falso: la altura crece 1 por cada paso en X y es constante en Z
## (para probar puertas en lados opuestos con suelos frontales distintos).
class GeneradorRampaX:
	func altura_en(x: int, _z: int) -> int:
		return x


func _rectangulo(ancho: int, alto: int) -> Array[Vector2i]:
	var columnas: Array[Vector2i] = []
	for x in range(ancho):
		for z in range(alto):
			columnas.append(Vector2i(x, z))
	return columnas


## Casa de prueba 4x5x5 (ver spec 2026-09-20): losas de piso (y=0) y techo
## (y=4) de "pared", muro perimetral en y=1..3 con una puerta en x=0 (z=2,
## y=1..2) y una ventana en x=3 (z=2, y=2), cama y baúl adentro. Con
## "puerta_extra_derecha" la ventana se reemplaza por una segunda puerta en
## x=3.
func _casa_4x5(puerta_extra_derecha: bool = false) -> Dictionary:
	var celdas: Dictionary = {}
	for x in range(4):
		for z in range(5):
			celdas[Vector3i(x, 0, z)] = "pared"
			celdas[Vector3i(x, 4, z)] = "pared"
			if x == 0 or x == 3 or z == 0 or z == 4:
				for y in range(1, 4):
					celdas[Vector3i(x, y, z)] = "pared"
	celdas[Vector3i(0, 1, 2)] = "puerta_inferior"
	celdas[Vector3i(0, 2, 2)] = "puerta_superior"
	celdas[Vector3i(3, 2, 2)] = "ventana"
	celdas[Vector3i(1, 1, 1)] = "cama_cabecera"
	celdas[Vector3i(1, 1, 2)] = "cama_pies"
	celdas[Vector3i(2, 1, 3)] = "baul"
	if puerta_extra_derecha:
		celdas[Vector3i(3, 1, 2)] = "puerta_inferior"
		celdas[Vector3i(3, 2, 2)] = "puerta_superior"
	return celdas


## Huella en L (14 columnas): barra x=0..4 x z=0..1 más barra x=0..1 x z=2..3;
## losa "pared" en y=0 y una puerta en (x=3, z=1) (y=1..2) que mira hacia +z.
func _casa_l() -> Dictionary:
	var celdas: Dictionary = {}
	for x in range(5):
		for z in range(2):
			celdas[Vector3i(x, 0, z)] = "pared"
	for x in range(2):
		for z in range(2, 4):
			celdas[Vector3i(x, 0, z)] = "pared"
	celdas[Vector3i(3, 1, 1)] = "puerta_inferior"
	celdas[Vector3i(3, 2, 1)] = "puerta_superior"
	return celdas


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

	print("\n=== TEST 8: altura_objetivo() no debe leer una columna fuera de la lista (regresión) ===")
	# Mismo generador de TEST 6/7 (acantilado en altura 100 en la columna
	# (2,2)), pero ahora la columna EXCLUIDA es la que coincide con el
	# offset relativo (0,0) — exactamente la que altura_objetivo() leía por
	# error antes del fix (sembraba el máximo desde "esquina" directamente,
	# sin pasar por la lista de columnas). Con esquina=(2,2), el offset
	# (0,0) mapea al mundo (2,2), el acantilado — si altura_objetivo()
	# todavía leyera esa celda "gratis", devolvería 100 en vez de 3.
	var columnas_sin_origen: Array[Vector2i] = _rectangulo(3, 3)
	columnas_sin_origen.erase(Vector2i(0, 0))
	assert(columnas_sin_origen.size() == 8)
	assert(nivelador_acantilado.altura_objetivo(Vector2i(2, 2), columnas_sin_origen) == 3)
	print("OK: altura_objetivo() solo lee columnas de la lista, nunca el offset (0,0) por defecto.")

	print("\n=== TEST 9: calcular_base_y() en terreno plano entierra la losa (la puerta queda a nivel del suelo frontal) ===")
	var casa_9: Dictionary = _casa_4x5()
	var base_9: Dictionary = nivelador_plano.calcular_base_y(Vector2i(10, 10), casa_9)
	assert(base_9["valido"])
	assert(base_9["base_y"] == 5, "suelo 5 + 1 - puerta en y=1 = 5: la losa ocupa la Y del suelo, enterrada un bloque (antes quedaba en 6)")
	var excavacion_9: Array[Vector3i] = nivelador_plano.calcular_excavacion(Vector2i(10, 10), _rectangulo(4, 5), 5)
	assert(excavacion_9.size() == 20, "una capa de 20 bloques bajo la huella")
	for celda_9 in excavacion_9:
		assert(celda_9.y == 5)
	assert(nivelador_plano.calcular_relleno_hasta(Vector2i(10, 10), _rectangulo(4, 5), 4).is_empty())

	print("\n=== TEST 10: en una ladera el nivel lo da el suelo frente a la puerta; se cava arriba y se rellena abajo ===")
	# altura_en(x,z) = z. Puerta en (10,12), frente en (9,12), suelo 12 -> base_y 12.
	var base_10: Dictionary = nivelador_suave.calcular_base_y(Vector2i(10, 10), casa_9)
	assert(base_10["valido"] and base_10["base_y"] == 12)
	var excavacion_10: Array[Vector3i] = nivelador_suave.calcular_excavacion(Vector2i(10, 10), _rectangulo(4, 5), 12)
	# Filas z=12,13,14 (alturas 12,13,14) aportan 1+2+3 = 6 celdas por columna X, x4 columnas.
	assert(excavacion_10.size() == 24)
	assert(excavacion_10[0].y == 14 and excavacion_10[excavacion_10.size() - 1].y == 12)
	for i_10 in range(1, excavacion_10.size()):
		assert(excavacion_10[i_10 - 1].y >= excavacion_10[i_10].y, "orden de arriba hacia abajo")
	# Relleno hasta base_y - 1 = 11: solo la fila z=10 (altura 10) necesita 1 bloque por columna.
	var relleno_10: Dictionary = nivelador_suave.calcular_relleno_hasta(Vector2i(10, 10), _rectangulo(4, 5), 11)
	assert(relleno_10.size() == 4)
	assert(relleno_10[Vector2i(10, 10)] == 1)

	print("\n=== TEST 11: puertas en lados con suelos frontales distintos se rechazan ===")
	var nivelador_x: RefCounted = NiveladorTerreno.new(GeneradorRampaX.new())
	var una_puerta_11: Dictionary = nivelador_x.calcular_base_y(Vector2i(10, 10), _casa_4x5())
	assert(una_puerta_11["valido"] and una_puerta_11["base_y"] == 9)  # frente (9,12): suelo 9
	var dos_puertas_11: Dictionary = nivelador_x.calcular_base_y(Vector2i(10, 10), _casa_4x5(true))
	assert(not dos_puertas_11["valido"] and dos_puertas_11["motivo"] == "puertas")  # 9 vs 14

	print("\n=== TEST 12: puerta frente a un desnivel mayor al límite se rechaza ===")
	# Acantilado (altura 100) exactamente en el frente (2,2) de la puerta en (3,2).
	var acantilado_12: Dictionary = nivelador_acantilado.calcular_base_y(Vector2i(3, 0), _casa_4x5())
	assert(not acantilado_12["valido"] and acantilado_12["motivo"] == "pendiente")

	print("\n=== TEST 13: sin puerta, base_y conserva el comportamiento anterior (altura_objetivo + 1) ===")
	var casa_sin_puerta: Dictionary = _casa_4x5()
	casa_sin_puerta.erase(Vector3i(0, 1, 2))
	casa_sin_puerta.erase(Vector3i(0, 2, 2))
	var base_13: Dictionary = nivelador_plano.calcular_base_y(Vector2i(0, 0), casa_sin_puerta)
	assert(base_13["valido"] and base_13["base_y"] == 6)
	# Puerta a 2 bloques sobre la losa (p. ej. un nivel bajo la entrada): la
	# losa baja un bloque más (base_y = 5 + 1 - 2 = 4) y la excavación llega más hondo.
	var casa_sotano: Dictionary = {}
	for rel_13 in _casa_4x5():
		casa_sotano[rel_13 + Vector3i(0, 1, 0)] = _casa_4x5()[rel_13]
	var base_13b: Dictionary = nivelador_plano.calcular_base_y(Vector2i(0, 0), casa_sotano)
	assert(base_13b["valido"] and base_13b["base_y"] == 4)
	assert(nivelador_plano.calcular_excavacion(Vector2i(0, 0), _rectangulo(4, 5), 4).size() == 40, "2 capas (Y=5 y Y=4) x 20 columnas")

	print("\n=== TEST 14: resumen_materiales() del ejemplo 4x5x5 sobre terreno plano (79 piedra, 12 madera, +19 tierra) ===")
	var neto_14: Dictionary = nivelador_plano.resumen_materiales(casa_9, 0, {"tierra": 20})
	assert(neto_14["piedra"] == -79)
	assert(neto_14["madera"] == -12)
	assert(neto_14["tierra"] == 19, "20 excavados - 1 de la ventana")
	var neto_14b: Dictionary = nivelador_plano.resumen_materiales(casa_9, 3, {"tierra": 20})
	assert(neto_14b["tierra"] == 16, "el relleno consume tierra")
	var neto_14c: Dictionary = nivelador_plano.resumen_materiales({Vector3i(0, 0, 0): "ventana"}, 0, {"tierra": 1})
	assert(neto_14c.is_empty(), "un neto de 0 no aparece")

	print("\n=== TEST 15: HUD.texto_materiales() pone lo necesario sin signo (mayor primero) y el sobrante con '+' ===")
	var texto_15: String = HUDScript.texto_materiales({"piedra": -79, "madera": -12, "tierra": 19})
	assert(texto_15 == "Materiales de construcción:\n79 piedra\n12 madera\n+ 19 tierra", texto_15)
	assert(HUDScript.texto_materiales({}) == "Materiales de construcción:\n-")

	print("\n=== TEST 16: calcular_base_y() devuelve la fachada del lado de la puerta, al nivel del suelo frontal ===")
	# Casa 4x5 con la puerta al oeste (x=0, z=2), terreno plano de altura 5, esquina (10,10):
	# toda la cara oeste (5 columnas) x 2 de fondo = 10 columnas a nivel G = 5.
	var base_16: Dictionary = nivelador_plano.calcular_base_y(Vector2i(10, 10), _casa_4x5())
	assert(base_16["valido"])
	var fachada_16: Dictionary = base_16["fachada"]
	assert(fachada_16.size() == 10, "5 columnas de ancho x 2 de fondo")
	for z_16 in range(10, 15):
		assert(fachada_16.get(Vector2i(9, z_16)) == 5, "primera columna delante de la cara oeste")
		assert(fachada_16.get(Vector2i(8, z_16)) == 5, "segunda columna delante de la cara oeste")
	for clave_16 in fachada_16:
		assert(clave_16.x < 10, "ninguna columna de la fachada pertenece a la huella")

	print("\n=== TEST 17: la fachada de una huella en L sigue el contorno real ===")
	# Puerta mirando hacia +z. Bordes que miran a +z: (2,1),(3,1),(4,1) a z=1 y (0,3),(1,3) a z=3.
	var base_17: Dictionary = nivelador_plano.calcular_base_y(Vector2i(10, 10), _casa_l())
	assert(base_17["valido"])
	var fachada_17: Dictionary = base_17["fachada"]
	assert(fachada_17.size() == 10)
	assert(fachada_17.has(Vector2i(12, 12)) and fachada_17.has(Vector2i(14, 13)))  # delante de la barra ancha
	assert(fachada_17.has(Vector2i(10, 14)) and fachada_17.has(Vector2i(11, 15)))  # delante del brazo de la L
	assert(not fachada_17.has(Vector2i(10, 12)) and not fachada_17.has(Vector2i(10, 13)), "esas columnas son de la propia L")

	print("\n=== TEST 18: dos puertas de la misma dirección con suelo frontal distinto se rechazan (aunque su base_y coincida) ===")
	# altura_en = z. Puerta A (y=1) en z=2 -> G=12, base 12. Puerta B (y=2) en z=3 -> G=13, base 13+1-2 = 12: misma base_y, distinto G.
	var casa_18: Dictionary = _casa_4x5()
	casa_18[Vector3i(0, 2, 3)] = "puerta_inferior"
	casa_18[Vector3i(0, 3, 3)] = "puerta_superior"
	var base_18: Dictionary = nivelador_suave.calcular_base_y(Vector2i(10, 10), casa_18)
	assert(not base_18["valido"] and base_18["motivo"] == "puertas")
	assert(base_18["fachada"].is_empty())

	print("\n=== TEST 19: calcular_nivelacion_fachada() cava por encima del nivel y rellena por debajo ===")
	# altura_en = z; nivel 12 en tres columnas de alturas 10, 12 y 14.
	var nivelacion_19: Dictionary = nivelador_suave.calcular_nivelacion_fachada({
		Vector2i(9, 10): 12, Vector2i(9, 12): 12, Vector2i(9, 14): 12,
	})
	var excavacion_19: Array[Vector3i] = nivelacion_19["excavacion"]
	assert(excavacion_19.size() == 2, "solo la columna de altura 14 se cava")
	assert(excavacion_19[0] == Vector3i(9, 14, 14) and excavacion_19[1] == Vector3i(9, 13, 14), "de arriba hacia abajo")
	assert(nivelacion_19["relleno"].size() == 1 and nivelacion_19["relleno"][Vector2i(9, 10)] == 2, "solo la columna de altura 10 necesita 2 bloques")

	print("\n=== TEST 20: el límite de pendiente sobre huella + fachada rechaza donde la huella sola pasaba ===")
	# Acantilado (altura 100) en (2,2): es la segunda columna delante de la puerta con esquina (4,0).
	var base_20: Dictionary = nivelador_acantilado.calcular_base_y(Vector2i(4, 0), _casa_4x5())
	assert(base_20["valido"], "la puerta y su frente inmediato (3,2) están a nivel")
	var union_20: Array[Vector2i] = _rectangulo(4, 5)
	for columna_20: Vector2i in base_20["fachada"]:
		union_20.append(columna_20 - Vector2i(4, 0))
	assert(nivelador_acantilado.verificar_pendiente(Vector2i(4, 0), _rectangulo(4, 5)), "la huella sola es válida")
	assert(not nivelador_acantilado.verificar_pendiente(Vector2i(4, 0), union_20), "con la fachada, el acantilado invalida")

	print("\n=== Las 20 pruebas de NiveladorTerreno pasaron correctamente ===")
