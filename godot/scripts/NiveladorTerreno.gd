extends RefCounted

## Lógica pura de nivelación de terreno (ver GDD Sección 5, "Nivelación de
## Terreno en Emplazamientos con Relieve") — sin nodos de escena, mismo
## patrón que Zonificacion.gd/Ciudad.gd. Dado el GeneradorMundo del mundo
## actual, calcula si una huella cuadrada de TAMANO_HUELLA celdas respeta el
## límite de pendiente, y cuántos bloques de "tierra" hacen falta para
## nivelarla a su punto más alto.

const TAMANO_HUELLA := 5
const LIMITE_PENDIENTE := 2

var _generador: RefCounted


func _init(generador: RefCounted) -> void:
	_generador = generador


## Revisa cada par de celdas horizontal/verticalmente adyacentes dentro de
## la huella (5x5 celdas, "esquina" es la esquina inferior de menor X/Z) —
## rechaza si algún desnivel entre vecinas supera LIMITE_PENDIENTE.
func verificar_pendiente(esquina: Vector2i) -> bool:
	for x in range(esquina.x, esquina.x + TAMANO_HUELLA):
		for z in range(esquina.y, esquina.y + TAMANO_HUELLA):
			var altura: int = _generador.altura_en(x, z)
			if x + 1 < esquina.x + TAMANO_HUELLA:
				if abs(altura - _generador.altura_en(x + 1, z)) > LIMITE_PENDIENTE:
					return false
			if z + 1 < esquina.y + TAMANO_HUELLA:
				if abs(altura - _generador.altura_en(x, z + 1)) > LIMITE_PENDIENTE:
					return false
	return true


## Altura máxima dentro de la huella — a esta altura se nivela todo. Público
## porque también lo usa CamaraCenital.gd para posicionar el recuadro
## fantasma de previsualización.
func altura_objetivo(esquina: Vector2i) -> int:
	var maximo: int = _generador.altura_en(esquina.x, esquina.y)
	for x in range(esquina.x, esquina.x + TAMANO_HUELLA):
		for z in range(esquina.y, esquina.y + TAMANO_HUELLA):
			maximo = max(maximo, _generador.altura_en(x, z))
	return maximo


## Cuántos bloques de "tierra" hacen falta en cada celda de la huella para
## llegar a la altura máxima de esa huella. Solo incluye celdas que
## realmente necesitan relleno (celdas ya a la altura máxima no aparecen).
func calcular_relleno(esquina: Vector2i) -> Dictionary:
	var objetivo: int = altura_objetivo(esquina)
	var relleno: Dictionary = {}  # Vector2i -> int
	for x in range(esquina.x, esquina.x + TAMANO_HUELLA):
		for z in range(esquina.y, esquina.y + TAMANO_HUELLA):
			var faltante: int = objetivo - _generador.altura_en(x, z)
			if faltante > 0:
				relleno[Vector2i(x, z)] = faltante
	return relleno
