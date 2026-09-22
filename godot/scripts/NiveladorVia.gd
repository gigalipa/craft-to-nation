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


## Columnas absolutas de "columnas" que hace falta rellenar (relativo a
## sí mismas, sin pasar por esquina/relativo de NiveladorTerreno — mismo
## cálculo que calcular_relleno_hasta() pero con columnas ya absolutas).
func _relleno_absoluto(columnas: Array[Vector2i], tope: int) -> Dictionary:
	var relleno: Dictionary = {}
	for col in columnas:
		var faltante: int = tope - _generador.altura_en(col.x, col.y)
		if faltante > 0:
			relleno[col] = faltante
	return relleno


## Plan de transición entre dos bloques de vía consecutivos (un paso, 8
## direcciones — ver spec Sección 2): {} si el desnivel es 0. Si no:
## "solape" son las columnas compartidas por ambos bloques (2 en paso
## recto, 1 en diagonal — ver bloque_de_vertice()); "y_base" es la altura
## del lado bajo de la cuña que va ahí; "diagonal" indica qué pieza usar
## (cuna_esquina si true, cuna_recta si false); "direccion_alta" apunta
## del vértice bajo al alto (para orientar la pieza); "relleno_extra"
## (columnas del bloque bajo, sin las de solape) solo tiene entradas si
## el desnivel es 2 o 3: sube ese bloque hasta quedar a 1 del alto, antes
## de que la cuña resuelva el último escalón.
func plan_transicion(vertice_a: Vector2i, vertice_b: Vector2i) -> Dictionary:
	var paso: Vector2i = vertice_b - vertice_a
	var bloque_a: Array[Vector2i] = bloque_de_vertice(vertice_a)
	var bloque_b: Array[Vector2i] = bloque_de_vertice(vertice_b)
	var solape: Array[Vector2i] = []
	for col in bloque_a:
		if bloque_b.has(col):
			solape.append(col)

	var nivel_a: int = nivel_de_bloque(vertice_a)
	var nivel_b: int = nivel_de_bloque(vertice_b)
	if nivel_a == nivel_b:
		return {}

	var vertice_bajo: Vector2i = vertice_a if nivel_a < nivel_b else vertice_b
	var nivel_bajo: int = mini(nivel_a, nivel_b)
	var nivel_alto: int = maxi(nivel_a, nivel_b)
	var y_base: int = nivel_bajo
	var relleno_extra: Dictionary = {}
	if nivel_alto - nivel_bajo > 1:
		y_base = nivel_alto - 1
		var columnas_a_rellenar: Array[Vector2i] = []
		for col in bloque_de_vertice(vertice_bajo):
			if not solape.has(col):
				columnas_a_rellenar.append(col)
		relleno_extra = _relleno_absoluto(columnas_a_rellenar, y_base)

	return {
		"solape": solape,
		"y_base": y_base,
		"diagonal": paso.x != 0 and paso.y != 0,
		"direccion_alta": paso if nivel_b > nivel_a else -paso,
		"relleno_extra": relleno_extra,
	}
