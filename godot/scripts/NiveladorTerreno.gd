extends RefCounted

## Lógica pura de nivelación de terreno (ver GDD Sección 5, "Nivelación de
## Terreno en Emplazamientos con Relieve") — sin nodos de escena, mismo
## patrón que Zonificacion.gd/Ciudad.gd. Calcula si una huella (cualquier
## conjunto de columnas, no necesariamente un rectángulo — ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md) respeta
## el límite de pendiente, y cuántos bloques de "tierra" hacen falta para
## nivelarla a su punto más alto.
##
## No depende de una clase concreta: solo llama a .altura_en(x, z) por duck
## typing sobre lo que se le pase en _init(). En el juego real se le pasa
## VoxelWorld (VoxelWorld.altura_en(), que refleja el relieve REAL —
## minado/construcción/nivelaciones ya hechas), no GeneradorMundo
## directamente (su altura_en() es el ruido original, nunca se actualiza).
## Las pruebas (NiveladorTerrenoTest.gd) le pasan generadores falsos con
## pendientes exactas y controladas, ya que GeneradorMundo real usa ruido.

const LIMITE_PENDIENTE := 2

const DIRECCIONES_XZ := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Costo en material de cada tipo de celda estructural de un blueprint (ver
## docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md).
## Solo alimenta el resumen VISUAL del HUD — no existe inventario real.
const COSTO_POR_CELDA := {
	"pared": {"piedra": 1},
	"piso": {"tierra": 1},
	"ventana": {"tierra": 1},
	"puerta_inferior": {"madera": 1},
	"puerta_superior": {"madera": 1},
	"cama_cabecera": {"madera": 2},
	"cama_pies": {"madera": 2},
	"baul": {"madera": 6},
}

## Sin tipo estático: puede ser un RefCounted (GeneradorMundo, los
## generadores falsos de las pruebas) o un Node (VoxelWorld real, que
## extiende GridMap) — lo único que importa es que tenga altura_en(x, z).
var _generador: Object


func _init(fuente_de_altura: Object) -> void:
	_generador = fuente_de_altura


## Revisa cada par de columnas horizontal/verticalmente adyacentes DENTRO de
## "columnas" (offsets Vector2i relativos a "esquina") — rechaza si algún
## desnivel entre dos columnas AMBAS presentes en la lista supera
## LIMITE_PENDIENTE. Una columna vecina que no esté en "columnas" (el hueco
## de una huella irregular, p. ej. un edificio en L) nunca se compara —
## mismo criterio que ya usa BlueprintValidator.validar_cerramiento() para
## decidir qué vecino cuenta. Un rectángulo es solo el caso particular de
## pasar todas las columnas de range(ancho) x range(alto) (ver
## CamaraCenital._columnas_rectangulo()).
func verificar_pendiente(esquina: Vector2i, columnas: Array[Vector2i]) -> bool:
	var presentes: Dictionary = {}
	for rel in columnas:
		presentes[rel] = true
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var altura: int = _generador.altura_en(x, z)
		if presentes.has(rel + Vector2i(1, 0)):
			if abs(altura - _generador.altura_en(x + 1, z)) > LIMITE_PENDIENTE:
				return false
		if presentes.has(rel + Vector2i(0, 1)):
			if abs(altura - _generador.altura_en(x, z + 1)) > LIMITE_PENDIENTE:
				return false
	return true


## Altura máxima entre las columnas de "columnas" — a esta altura se nivela
## todo. Público porque también lo usa CamaraCenital.gd para posicionar el
## recuadro fantasma de previsualización.
func altura_objetivo(esquina: Vector2i, columnas: Array[Vector2i]) -> int:
	var maximo: int = _generador.altura_en(esquina.x + columnas[0].x, esquina.y + columnas[0].y)
	for rel in columnas:
		maximo = max(maximo, _generador.altura_en(esquina.x + rel.x, esquina.y + rel.y))
	return maximo


## Cuántos bloques de "tierra" hacen falta en cada columna de "columnas"
## para llegar a la altura máxima de esa huella. Solo incluye columnas que
## realmente necesitan relleno (columnas ya a la altura máxima no aparecen).
## Usada por los puestos periféricos; los blueprints usan
## calcular_relleno_hasta() con el tope de su propio nivel base.
func calcular_relleno(esquina: Vector2i, columnas: Array[Vector2i]) -> Dictionary:
	return calcular_relleno_hasta(esquina, columnas, altura_objetivo(esquina, columnas))


## Igual que calcular_relleno() pero con un "tope" explícito: cuántos bloques
## faltan en cada columna para que su superficie llegue a "tope".
func calcular_relleno_hasta(esquina: Vector2i, columnas: Array[Vector2i], tope: int) -> Dictionary:
	var relleno: Dictionary = {}  # Vector2i -> int
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var faltante: int = tope - _generador.altura_en(x, z)
		if faltante > 0:
			relleno[Vector2i(x, z)] = faltante
	return relleno


## Celdas de terreno que hay que retirar bajo la huella: en cada columna,
## todo bloque desde la superficie hasta "base_y" inclusive (nada si la
## columna ya está por debajo). Ordenadas de arriba hacia abajo (y, x, z).
func calcular_excavacion(esquina: Vector2i, columnas: Array[Vector2i], base_y: int) -> Array[Vector3i]:
	var celdas: Array[Vector3i] = []
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		for y in range(_generador.altura_en(x, z), base_y - 1, -1):
			celdas.append(Vector3i(x, y, z))
	celdas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y > b.y
		if a.x != b.x:
			return a.x < b.x
		return a.z < b.z
	)
	return celdas


## Nivel base de un blueprint colocado en "esquina": la Y mundial de su
## celda rel.y=0 (la losa de piso) tal que cada "puerta_inferior" quede a
## nivel del suelo natural delante de ella — base_y = altura_en(frente) + 1 -
## rel.y_puerta. "frente" es el vecino cardinal en XZ que cae fuera de la
## huella (mismo criterio que VoxelWorld.calcular_despeje()). Rechaza
## ("valido": false) si una puerta y su frente difieren en más de
## LIMITE_PENDIENTE ("pendiente") o si dos puertas piden base_y distintos
## ("puertas"). Sin puertas devuelve altura_objetivo() + 1, el
## comportamiento anterior. "frentes" son todas las columnas frontales, para
## que el llamador valide lo que este módulo no ve (agua, límites del mundo).
func calcular_base_y(esquina: Vector2i, celdas_3d: Dictionary) -> Dictionary:
	var huella: Dictionary = {}  # Vector2i -> true
	var columnas: Array[Vector2i] = []
	for rel in celdas_3d:
		var xz := Vector2i(rel.x, rel.z)
		if not huella.has(xz):
			huella[xz] = true
			columnas.append(xz)
	var respaldo: int = altura_objetivo(esquina, columnas) + 1

	var frentes: Array[Vector2i] = []
	var candidatos: Dictionary = {}  # int base_y -> true
	for rel in celdas_3d:
		if celdas_3d[rel] != "puerta_inferior":
			continue
		var xz := Vector2i(rel.x, rel.z)
		for direccion: Vector2i in DIRECCIONES_XZ:
			if huella.has(xz + direccion):
				continue
			var columna_puerta := esquina + xz
			var frente := columna_puerta + direccion
			var suelo_frente: int = _generador.altura_en(frente.x, frente.y)
			if abs(_generador.altura_en(columna_puerta.x, columna_puerta.y) - suelo_frente) > LIMITE_PENDIENTE:
				return {"valido": false, "base_y": respaldo, "motivo": "pendiente", "frentes": frentes}
			frentes.append(frente)
			candidatos[suelo_frente + 1 - rel.y] = true
	if candidatos.size() > 1:
		return {"valido": false, "base_y": respaldo, "motivo": "puertas", "frentes": frentes}
	var base_y: int = respaldo if candidatos.is_empty() else candidatos.keys()[0]
	return {"valido": true, "base_y": base_y, "motivo": "", "frentes": frentes}


## Neto por material de un blueprint: negativo = hace falta, positivo =
## sobra. Resta el costo de cada celda de "celdas_3d" (COSTO_POR_CELDA) y
## "relleno_total" bloques de tierra, y suma "recogido" (material -> cantidad
## obtenida al excavar). Los materiales con neto 0 no aparecen. Solo para el
## resumen visual del HUD — no toca ningún inventario.
func resumen_materiales(celdas_3d: Dictionary, relleno_total: int, recogido: Dictionary) -> Dictionary:
	var neto: Dictionary = {}
	for rel in celdas_3d:
		var costo: Dictionary = COSTO_POR_CELDA.get(celdas_3d[rel], {})
		for material in costo:
			neto[material] = neto.get(material, 0) - costo[material]
	if relleno_total > 0:
		neto["tierra"] = neto.get("tierra", 0) - relleno_total
	for material in recogido:
		neto[material] = neto.get(material, 0) + recogido[material]
	for material in neto.keys():
		if neto[material] == 0:
			neto.erase(material)
	return neto
