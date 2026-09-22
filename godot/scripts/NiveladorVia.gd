extends RefCounted

## Lógica pura de relleno y cuñas para vías (ver GDD Sección 4, spec
## docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md Sección
## 2) — sin nodos, mismo patrón que NiveladorTerreno.gd. Reutiliza
## NiveladorTerreno para el cálculo de nivel/relleno de un bloque 2x2 en
## vez de reimplementarlo.
##
## No depende de una clase concreta: solo llama a .altura_en(x, z) por
## duck typing sobre lo que se le pase en _init() — mismo contrato que
## NiveladorTerreno.

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")

## Desnivel máximo entre dos bloques de vía consecutivos que esta pieza
## resuelve con relleno + cuña; por encima, el trazador (TrazadorVias)
## rechaza el paso — queda para el sistema de puentes futuro.
const LIMITE_DESNIVEL_VIA := 3

## Las 4 columnas del bloque de soporte de un vértice, relativas a la
## esquina (mínimo x, mínimo z) de ese bloque — ver bloque_de_vertice().
const COLUMNAS_BLOQUE: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
]

var _generador: Object
var _nivelador_terreno: RefCounted


func _init(fuente_de_altura: Object) -> void:
	_generador = fuente_de_altura
	_nivelador_terreno = NiveladorTerreno.new(fuente_de_altura)


## Esquina (mínimo x, mínimo z) del bloque de soporte 2x2 de "vertice" —
## el vértice es la esquina compartida por esas 4 columnas (ver spec
## Sección 1).
func _esquina_de(vertice: Vector2i) -> Vector2i:
	return vertice - Vector2i(1, 1)


## Las 4 columnas (X,Z) del bloque de soporte de "vertice".
func bloque_de_vertice(vertice: Vector2i) -> Array[Vector2i]:
	var esquina: Vector2i = _esquina_de(vertice)
	var columnas: Array[Vector2i] = []
	for rel in COLUMNAS_BLOQUE:
		columnas.append(esquina + rel)
	return columnas


## Altura a la que se nivela el bloque de soporte de "vertice" — el
## máximo entre sus 4 columnas (nunca se cava, ver spec Sección 2).
func nivel_de_bloque(vertice: Vector2i) -> int:
	return _nivelador_terreno.altura_objetivo(_esquina_de(vertice), COLUMNAS_BLOQUE)
