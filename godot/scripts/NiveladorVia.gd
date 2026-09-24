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


## Los niveles de "vertices" (mismo orden) después de suavizar los
## mínimos locales — decisión del usuario jugando en vivo, 2026-09-23: un
## vértice interior más bajo que SUS DOS VECINOS INMEDIATOS en el trazo
## ya confirmado (una "V": baja y vuelve a subir) se sube al nivel MÁS
## ALTO de esos dos vecinos, en vez de bajar y volver a subir con dos
## rampas — mismo criterio de "nunca cavar" que ya sigue el resto del
## sistema. Solo mira vecinos INMEDIATOS: una "V" ancha (2+ vértices
## seguidos por debajo de sus hombros) no se nivela de punta a punta.
## ponytail: si hace falta ese caso más ancho, agregar una pasada que
## propague el nivel hacia los vecinos hasta encontrar un punto que ya
## no sea mínimo local.
func niveles_efectivos(vertices: Array[Vector2i]) -> Array[int]:
	var niveles: Array[int] = []
	for v in vertices:
		niveles.append(nivel_de_bloque(v))
	for i in range(1, niveles.size() - 1):
		if niveles[i] < niveles[i - 1] and niveles[i] < niveles[i + 1]:
			niveles[i] = maxi(niveles[i - 1], niveles[i + 1])
	return niveles


## Las columnas compartidas por los bloques de soporte de "vertice_a" y
## "vertice_b" (2 en un paso recto, 1 en diagonal — ver
## bloque_de_vertice()) — las columnas "bisagra" que conectan ambos
## tramos. Reutilizada por plan_transicion() y por quien necesite saber
## qué columnas NO son un extremo suelto del trazo (ver ConstructorVias).
func columnas_solape(vertice_a: Vector2i, vertice_b: Vector2i) -> Array[Vector2i]:
	var bloque_a: Array[Vector2i] = bloque_de_vertice(vertice_a)
	var bloque_b: Array[Vector2i] = bloque_de_vertice(vertice_b)
	var solape: Array[Vector2i] = []
	for col in bloque_a:
		if bloque_b.has(col):
			solape.append(col)
	return solape


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
## direcciones — ver spec Sección 2). "nivel_a"/"nivel_b" son los niveles
## YA CALCULADOS de cada vértice (ver niveles_efectivos() — el llamador
## los suaviza para toda la ruta ANTES de pedir cada plan, así una "V" se
## nivela una sola vez en vez de que cada plan recalcule el nivel bruto
## por su cuenta). {} si el desnivel es 0. Si no:
## "y_base" es la altura del lado bajo de las cuñas que van ahí;
## "relleno_extra" (columnas del bloque bajo, sin las que se vuelven
## cuña) solo tiene entradas si el desnivel es 2 o 3: sube ese bloque
## hasta quedar a 1 del alto, antes de que las cuñas resuelvan el último
## escalón; "cunas" es un Array de {"columna": Vector2i, "tipo": String
## ("cuna_recta"/"cuna_esquina"), "direccion_alta": Vector2i} — una
## entrada por celda que se vuelve cuña.
##
## En un paso RECTO, "cunas" trae las 2 columnas de solape (ver
## bloque_de_vertice()), ambas cuna_recta con la misma direccion_alta.
##
## En un paso DIAGONAL, la columna de solape se vuelve cuna_esquina, pero
## sola deja bordes bruscos contra los 4 lados (su altura varía de 0 a
## 0.5 en las dos aristas que no tocan ni el vértice bajo ni el alto —
## ver spec). El sistema completo (geometría exacta de
## docs/Rampa_CtN.obj, decisión del usuario jugando en vivo, 2026-09-22)
## agrega, alrededor de la esquina, las 4 columnas de ARISTA de los dos
## bloques (2 cuna_diag_bajo del lado bajo, 2 cuna_diag_arriba del lado
## alto) más 2 columnas de remate en las esquinas del "diamante" de 3x3
## que forman ambos bloques juntos (cuna_diag_lat_izq/cuna_diag_lat_der,
## en las direcciones (dz,-dx) y (-dz,dx) desde la esquina — las 2
## esquinas del diamante que NO están sobre el eje de direccion_alta).
## Las 2 columnas restantes del diamante (las diagonal-opuestas dentro de
## cada bloque) siguen planas. Las piezas *_bajo/*_arriba/*_lat_* se
## modelaron para direccion_alta=(1,-1); _orientacion() las rota para
## cualquier otra diagonal.
func plan_transicion(vertice_a: Vector2i, vertice_b: Vector2i, nivel_a: int, nivel_b: int) -> Dictionary:
	var paso: Vector2i = vertice_b - vertice_a
	var solape: Array[Vector2i] = columnas_solape(vertice_a, vertice_b)

	if nivel_a == nivel_b:
		return {}

	var vertice_bajo: Vector2i = vertice_a if nivel_a < nivel_b else vertice_b
	var nivel_bajo: int = mini(nivel_a, nivel_b)
	var nivel_alto: int = maxi(nivel_a, nivel_b)
	var diagonal: bool = paso.x != 0 and paso.y != 0
	var direccion_alta: Vector2i = paso if nivel_b > nivel_a else -paso
	var y_base: int = nivel_alto - 1 if nivel_alto - nivel_bajo > 1 else nivel_bajo

	var cunas: Array[Dictionary] = []
	for col in solape:
		cunas.append({"columna": col, "tipo": "cuna_esquina" if diagonal else "cuna_recta", "direccion_alta": direccion_alta})

	var columnas_extra: Array[Vector2i] = []
	if diagonal:
		var columna_solape: Vector2i = solape[0]
		var dx: int = direccion_alta.x
		var dz: int = direccion_alta.y
		for col in bloque_de_vertice(vertice_bajo):
			if col == columna_solape:
				continue
			var delta: Vector2i = columna_solape - col
			if absi(delta.x) + absi(delta.y) != 1:
				continue  # solo vecinos de ARISTA — el 4º, diagonal-opuesto, sigue plano
			columnas_extra.append(col)
			cunas.append({"columna": col, "tipo": "cuna_diag_bajo", "direccion_alta": direccion_alta})
		for col in bloque_de_vertice(vertice_bajo + direccion_alta):  # bloque del vértice ALTO
			if col == columna_solape:
				continue
			var delta: Vector2i = col - columna_solape
			if absi(delta.x) + absi(delta.y) != 1:
				continue  # solo vecinos de ARISTA — el 4º, diagonal-opuesto, sigue plano
			cunas.append({"columna": col, "tipo": "cuna_diag_arriba", "direccion_alta": direccion_alta})
		cunas.append({"columna": columna_solape + Vector2i(dz, -dx), "tipo": "cuna_diag_lat_izq", "direccion_alta": direccion_alta})
		cunas.append({"columna": columna_solape + Vector2i(-dz, dx), "tipo": "cuna_diag_lat_der", "direccion_alta": direccion_alta})

		# diag_lat: relleno opcional 1 celda más allá de cada cuna_diag_arriba
		# (misma dirección), SOLO si el terreno natural ahí no llega a la
		# altura alta de la rampa — sin esto, esa esquina de la rampa
		# quedaría con un hueco visible contra el terreno real (decisión del
		# usuario jugando en vivo, 2026-09-22). Si el terreno ya llega solo,
		# no se toca nada ahí.
		for offset in [Vector2i(2 * dx, 0), Vector2i(0, 2 * dz)]:
			var col_diag_lat: Vector2i = columna_solape + offset
			if _generador.altura_en(col_diag_lat.x, col_diag_lat.y) < y_base:
				cunas.append({"columna": col_diag_lat, "tipo": "diag_lat", "direccion_alta": direccion_alta})

	var relleno_extra: Dictionary = {}
	if nivel_alto - nivel_bajo > 1:
		var columnas_a_rellenar: Array[Vector2i] = []
		for col in bloque_de_vertice(vertice_bajo):
			if not solape.has(col) and not columnas_extra.has(col):
				columnas_a_rellenar.append(col)
		relleno_extra = _relleno_absoluto(columnas_a_rellenar, y_base)

	return {
		"y_base": y_base,
		"relleno_extra": relleno_extra,
		"cunas": cunas,
	}


## Para un paso DIAGONAL entre "vertice_a" y "vertice_b" (8 direcciones,
## ambos componentes de la diferencia no nulos), las 2 columnas "notch" —
## la diagonal-opuesta a la de solape dentro de cada uno de los dos
## bloques (ver plan_transicion(): son las que siguen planas incluso con
## desnivel) — junto con la esquina LOCAL de esa columna (0 o 1 en cada
## eje) que su overlay plano debe OMITIR, para que el borde visual de una
## vía diagonal quede recto en vez de escalonado (spec de vías Sección 1,
## decisión del usuario jugando en vivo, 2026-09-22). La esquina omitida
## es siempre la más alejada de la columna de solape: en la columna
## "detrás" de vertice_a, la que apunta en -paso; en la de "delante" de
## vertice_b, la que apunta en +paso. [] si el paso no es diagonal — NO
## depende de si hay desnivel (a diferencia de plan_transicion(), que
## devuelve {} sin desnivel): el recorte del overlay hace falta igual.
func notches_de_paso(vertice_a: Vector2i, vertice_b: Vector2i) -> Array[Dictionary]:
	var paso: Vector2i = vertice_b - vertice_a
	if paso.x == 0 or paso.y == 0:
		return []

	var columna_solape: Vector2i = columnas_solape(vertice_a, vertice_b)[0]

	@warning_ignore("integer_division")
	var esquina_a := Vector2i((1 - signi(paso.x)) / 2, (1 - signi(paso.y)) / 2)
	@warning_ignore("integer_division")
	var esquina_b := Vector2i((1 + signi(paso.x)) / 2, (1 + signi(paso.y)) / 2)
	return [
		{"columna": columna_solape - paso, "esquina_omitida": esquina_a},
		{"columna": columna_solape + paso, "esquina_omitida": esquina_b},
	]
