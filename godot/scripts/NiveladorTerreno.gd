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
func calcular_relleno(esquina: Vector2i, columnas: Array[Vector2i]) -> Dictionary:
	var objetivo: int = altura_objetivo(esquina, columnas)
	var relleno: Dictionary = {}  # Vector2i -> int
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var faltante: int = objetivo - _generador.altura_en(x, z)
		if faltante > 0:
			relleno[Vector2i(x, z)] = faltante
	return relleno
