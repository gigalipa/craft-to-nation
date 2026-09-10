extends RefCounted

## Lógica pura de nivelación de terreno (ver GDD Sección 5, "Nivelación de
## Terreno en Emplazamientos con Relieve") — sin nodos de escena, mismo
## patrón que Zonificacion.gd/Ciudad.gd. Calcula si una huella cuadrada de
## TAMANO_HUELLA celdas respeta el límite de pendiente, y cuántos bloques de
## "tierra" hacen falta para nivelarla a su punto más alto.
##
## No depende de una clase concreta: solo llama a .altura_en(x, z) por duck
## typing sobre lo que se le pase en _init(). En el juego real se le pasa
## VoxelWorld (VoxelWorld.altura_en(), que refleja el relieve REAL —
## minado/construcción/nivelaciones ya hechas), no GeneradorMundo
## directamente (su altura_en() es el ruido original, nunca se actualiza).
## Las pruebas (NiveladorTerrenoTest.gd) le pasan generadores falsos con
## pendientes exactas y controladas, ya que GeneradorMundo real usa ruido.

const TAMANO_HUELLA := 5
const LIMITE_PENDIENTE := 2

## Sin tipo estático: puede ser un RefCounted (GeneradorMundo, los
## generadores falsos de las pruebas) o un Node (VoxelWorld real, que
## extiende GridMap) — lo único que importa es que tenga altura_en(x, z).
var _generador: Object


func _init(fuente_de_altura: Object) -> void:
	_generador = fuente_de_altura


## Revisa cada par de celdas horizontal/verticalmente adyacentes dentro de
## la huella (5x5 celdas, "esquina" es la esquina inferior de menor X/Z) —
## rechaza si algún desnivel entre vecinas supera LIMITE_PENDIENTE.
## "ancho"/"alto" por defecto son la huella cuadrada TAMANO_HUELLA del modo
## de nivelación manual (tecla B) — quien valida el relieve de un puesto
## periférico (ver CamaraCenital.gd) pasa su propia huella real (p. ej. 5x5
## para una mina, 4x4 para un puesto de caza/recolección).
func verificar_pendiente(esquina: Vector2i, ancho: int = TAMANO_HUELLA, alto: int = TAMANO_HUELLA) -> bool:
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			var altura: int = _generador.altura_en(x, z)
			if x + 1 < esquina.x + ancho:
				if abs(altura - _generador.altura_en(x + 1, z)) > LIMITE_PENDIENTE:
					return false
			if z + 1 < esquina.y + alto:
				if abs(altura - _generador.altura_en(x, z + 1)) > LIMITE_PENDIENTE:
					return false
	return true


## Altura máxima dentro de la huella — a esta altura se nivela todo. Público
## porque también lo usa CamaraCenital.gd para posicionar el recuadro
## fantasma de previsualización.
func altura_objetivo(esquina: Vector2i, ancho: int = TAMANO_HUELLA, alto: int = TAMANO_HUELLA) -> int:
	var maximo: int = _generador.altura_en(esquina.x, esquina.y)
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			maximo = max(maximo, _generador.altura_en(x, z))
	return maximo


## Cuántos bloques de "tierra" hacen falta en cada celda de la huella para
## llegar a la altura máxima de esa huella. Solo incluye celdas que
## realmente necesitan relleno (celdas ya a la altura máxima no aparecen).
func calcular_relleno(esquina: Vector2i, ancho: int = TAMANO_HUELLA, alto: int = TAMANO_HUELLA) -> Dictionary:
	var objetivo: int = altura_objetivo(esquina, ancho, alto)
	var relleno: Dictionary = {}  # Vector2i -> int
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			var faltante: int = objetivo - _generador.altura_en(x, z)
			if faltante > 0:
				relleno[Vector2i(x, z)] = faltante
	return relleno
