extends RefCounted

## Plantillas prediseñadas de los puestos de recolección (spec: docs/superpowers/
## specs/2026-09-24-edificios-recoleccion-plantillas-design.md). Datos puros y
## funciones estáticas, sin autoload ni class_name (se carga con preload, como
## el resto de scripts sin estado).
##
## Cada plantilla son "capas" de abajo hacia arriba. La capa 0 es una losa de
## piso sólida (enterrada al nivel del suelo natural frente a la puerta, ver
## NiveladorTerreno.calcular_base_y()); la puerta vive en la capa 1, un bloque
## arriba, así que el frente de la puerta queda a la MISMA altura de siempre
## (suelo natural + 1) pero ahora hay una losa real bajo ella en vez de dejar
## el terreno natural como piso implícito (revisión de código, 2026-09-29).
## Una capa es una lista de filas (eje Z); una fila, un texto con un carácter
## por columna (eje X). En la plantilla base la puerta está en la fila z = 0 y
## mira a −Z. Este mismo formato lo producirá luego el conversor de .obj de
## SketchUp, así que el arte reemplaza estas plantillas provisionales sin
## tocar código.

## Carácter -> bloque fijo (no depende del puesto). "." (y cualquier otro
## carácter) es vacío. "#" es especial: se resuelve con el material propio
## de cada plantilla (ver MATERIAL más abajo), no con un tipo fijo.
const BLOQUES := {
	"V": "vidrio", "B": "baul", "M": "mesa_estudio",
	"d": "puerta_inferior", "D": "puerta_superior",
	# Edificios con entrada y salida separadas (refinerías y, más adelante, fábricas): las
	# cintas y tuberías futuras necesitan dos puertas. Mismo bloque que "d"/"D"; la letra
	# solo dice cuál es cuál (ver celda_de_servicio()/celda_de_salida()).
	"e": "puerta_inferior", "E": "puerta_superior",
	"s": "puerta_inferior", "S": "puerta_superior",
}

## Material de muro de cada tipo de puesto (era de prehistoria: cada uno usa
## lo que tenga más a mano según su oficio — ver docs/superpowers/specs/
## 2026-09-29-costo-colocacion-bloques-design.md, Sección 5).
const MATERIAL := {
	"mina": "adobe",
	"caza_recoleccion": "bloque_madera",
	"maderero": "bloque_madera",
	"pesca_frutos_mar": "bloque_piedra",
	"siderurgica": "bloque_piedra",
	"refineria_tierras_raras": "estructura_hierro",
	"carbonera": "adobe",
	"aserradero": "bloque_madera",
	"escuela_tecnica": "adobe",
	"escuela_especialistas": "bloque_piedra",
	"universidad": "bloque_piedra",
	"refineria_petrolera": "estructura_hierro",
	"productor_combustible": "bloque_piedra",
	"central_termoelectrica": "bloque_piedra",
}

const PLANTILLAS := {
	"mina": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##d##", "#...#", "#..B#", "#...#", "#####"],
		["##D##", "#...#", "#...#", "#...#", "#####"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
	"caza_recoleccion": {"capas": [
		["####", "####", "####", "####"],
		["##d#", "#..#", "#.B#", "####"],
		["##D#", "V..V", "#..#", "##V#"],
		["####", "####", "####", "####"],
	]},
	"maderero": {"capas": [
		["###", "###", "###", "###"],
		["#d#", "#.#", "#B#", "###"],
		["#D#", "#.#", "#.#", "###"],
		["###", "###", "###", "###"],
	]},
	# Losa (fila 0) + edificio en las filas 0-3 (interior libre en las filas 1-2,
	# con el baúl al fondo) y muelle (cubierta de muro) en las filas 4-5; el agua
	# queda del lado de z alto. "agua_ref" (x, z) es una celda del extremo de agua.
	"pesca_frutos_mar": {"capas": [
		["####", "####", "####", "####", "####", "####"],
		["#d##", "#..#", "#.B#", "####", "####", "####"],
		["#D##", "V..V", "#..#", "####", "....", "...."],
		["####", "####", "####", "####", "....", "...."],
	], "agua_ref": Vector2i(0, 5)},
	# Entrada (z = 0) y salida (z = 4) en lados opuestos; baúl como almacén local. Las dos capas
	# sobre el techo son la chimenea ("chimenea" = su columna local (x, z), ver celda_chimenea()).
	"siderurgica": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##e##", "#...#", "#..B#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "##S##"],
		["#####", "#####", "#####", "#####", "#####"],
		[".....", ".....", "...#.", ".....", "....."],
		[".....", ".....", "...#.", ".....", "....."],
	], "chimenea": Vector2i(3, 2)},
	# Cada refinería se reconoce de lejos por su material, su silueta y su indicador (ver HumoRefinerias.gd).
	# Torre de hierro: chimenea alta (3 capas) en una esquina; el baúl al otro lado.
	"refineria_tierras_raras": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##e##", "#B..#", "#...#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "##S##"],
		["#####", "#####", "#####", "#####", "#####"],
		[".....", ".#...", ".....", ".....", "....."],
		[".....", ".#...", ".....", ".....", "....."],
		[".....", ".#...", ".....", ".....", "....."],
	], "chimenea": Vector2i(1, 1)},
	# Carbonera de adobe: dos chimeneas bajas y gruesas (el humo sale de la de (3, 3)).
	"carbonera": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##e##", "#...#", "#B..#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "##S##"],
		["#####", "#####", "#####", "#####", "#####"],
		[".....", ".#...", ".....", "...#.", "....."],
	], "chimenea": Vector2i(3, 3)},
	# Aserradero: galpón largo de madera (5 x 6) con una tolva sobre el techo; sale aserrín de ella.
	"aserradero": {"capas": [
		["#####", "#####", "#####", "#####", "#####", "#####"],
		["##e##", "#...#", "#..B#", "#...#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "#...#", "##S##"],
		["#####", "#####", "#####", "#####", "#####", "#####"],
		[".....", ".....", ".....", "..#..", ".....", "....."],
	], "chimenea": Vector2i(2, 3)},
	# Escuela técnica (primer edificio de investigación): una sola puerta (como un puesto) y un interior de
	# 3 x 3 con 4 mesas de estudio (M, una por aprendiz) al fondo y a un lado; quedan 4 sitios libres más el
	# vestíbulo. Sin baúl: no maneja recursos (ver celda_deposito()).
	"escuela_tecnica": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##d##", "#...#", "#..M#", "#MMM#", "#####"],
		["##D##", "V...V", "#...#", "V...V", "#####"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
	# Escuela de especialistas: interior de 3 x 3 con 3 mesas de estudio (M, una por aprendiz)
	# al fondo; quedan 5 sitios libres más el vestíbulo. Sin baúl: no maneja recursos.
	"escuela_especialistas": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##d##", "#...#", "#...#", "#MMM#", "#####"],
		["##D##", "V...V", "#...#", "V...V", "#####"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
	# Universidad: interior de 3 x 3 con 3 mesas de estudio (M, una por investigador)
	# al fondo; quedan 5 sitios libres más el vestíbulo. Sin baúl: no maneja recursos.
	"universidad": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##d##", "#...#", "#...#", "#MMM#", "#####"],
		["##D##", "V...V", "#...#", "V...V", "#####"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
	# Refinería petrolera: torre de refinación de 3 capas de chimenea en el centro (2, 2).
	"refineria_petrolera": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##e##", "#...#", "#..B#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "##S##"],
		["#####", "#####", "#####", "#####", "#####"],
		[".....", ".....", "..#..", ".....", "....."],
		[".....", ".....", "..#..", ".....", "....."],
		[".....", ".....", "..#..", ".....", "....."],
	], "chimenea": Vector2i(2, 2)},
	# Productor de combustible: chimenea en (3, 3) y baúl en (1, 1).
	"productor_combustible": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##e##", "#B..#", "#...#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "##S##"],
		["#####", "#####", "#####", "#####", "#####"],
		[".....", ".....", ".....", "...#.", "....."],
		[".....", ".....", ".....", "...#.", "....."],
	], "chimenea": Vector2i(3, 3)},
	# Central termoeléctrica: chimenea alta en (1, 1).
	"central_termoelectrica": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##e##", "#...#", "#..B#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "##S##"],
		["#####", "#####", "#####", "#####", "#####"],
		[".....", ".#...", ".....", ".....", "....."],
		[".....", ".#...", ".....", ".....", "....."],
		[".....", ".#...", ".....", ".....", "....."],
	], "chimenea": Vector2i(1, 1)},
}


## (ancho, alto) de la plantilla sin girar.
static func dimensiones(tipo: String) -> Vector2i:
	var capa0: Array = PLANTILLAS[tipo]["capas"][0]
	return Vector2i((capa0[0] as String).length(), capa0.size())


## Número de capas (altura en bloques).
static func altura(tipo: String) -> int:
	return PLANTILLAS[tipo]["capas"].size()


## (ancho, alto) de la huella tras "giros" cuartos de vuelta: se intercambian con giros impar.
static func huella(tipo: String, giros: int) -> Vector2i:
	var d := dimensiones(tipo)
	return d if posmod(giros, 2) == 0 else Vector2i(d.y, d.x)


## Gira "p" (local, en una caja ancho x alto) "giros" cuartos de vuelta horarios:
## (x, z) -> (alto - 1 - z, x), la misma fórmula que CamaraCenital._rotar_blueprint().
static func _girar(p: Vector3i, ancho: int, alto: int, giros: int) -> Vector3i:
	for _i in range(posmod(giros, 4)):
		p = Vector3i(alto - 1 - p.z, p.y, p.x)
		var previo := ancho
		ancho = alto
		alto = previo
	return p


## Celdas locales de la plantilla girada: Vector3i (x, capa, z) -> nombre de bloque.
static func celdas(tipo: String, giros: int) -> Dictionary:
	var d := dimensiones(tipo)
	var resultado := {}
	var capas: Array = PLANTILLAS[tipo]["capas"]
	var material_muro: String = MATERIAL[tipo]
	for y in range(capas.size()):
		var filas: Array = capas[y]
		for z in range(filas.size()):
			var fila: String = filas[z]
			for x in range(fila.length()):
				var caracter: String = fila[x]
				if caracter == "#":
					resultado[_girar(Vector3i(x, y, z), d.x, d.y, giros)] = material_muro
				elif BLOQUES.has(caracter):
					resultado[_girar(Vector3i(x, y, z), d.x, d.y, giros)] = BLOQUES[caracter]
	return resultado


## Igual que celdas(), pero en coordenadas del mundo: la esquina de la huella es
## "esquina" (X, Z) y la capa 0 queda en "y_base".
static func en_mundo(tipo: String, giros: int, esquina: Vector2i, y_base: int) -> Dictionary:
	var resultado := {}
	var local := celdas(tipo, giros)
	for c in local:
		resultado[Vector3i(esquina.x + c.x, y_base + c.y, esquina.y + c.z)] = local[c]
	return resultado


## Primera celda base (sin girar) con ese bloque.
static func _buscar(tipo: String, bloque: String) -> Vector3i:
	var base := celdas(tipo, 0)
	for c in base:
		if base[c] == bloque:
			return c
	assert(false, "la plantilla " + tipo + " no tiene " + bloque)
	return Vector3i.ZERO


## Primera celda base (sin girar) cuyo carácter esté en "caracteres" (p. ej. "de" =
## la puerta de entrada de cualquier tipo; "ds" = la de salida: en los puestos de una
## sola puerta, "d" sirve para las dos).
static func _buscar_caracter(tipo: String, caracteres: String) -> Vector3i:
	var capas: Array = PLANTILLAS[tipo]["capas"]
	for y in range(capas.size()):
		var filas: Array = capas[y]
		for z in range(filas.size()):
			var fila: String = filas[z]
			for x in range(fila.length()):
				if caracteres.contains(fila[x]):
					return Vector3i(x, y, z)
	assert(false, "la plantilla " + tipo + " no tiene " + caracteres)
	return Vector3i.ZERO


## Sentido (sin girar) en que "puerta" mira hacia afuera: el borde de la huella donde está.
static func _hacia_afuera(tipo: String, puerta: Vector3i) -> Vector3i:
	var d := dimensiones(tipo)
	if puerta.z == 0:
		return Vector3i(0, 0, -1)
	if puerta.z == d.y - 1:
		return Vector3i(0, 0, 1)
	if puerta.x == 0:
		return Vector3i(-1, 0, 0)
	return Vector3i(1, 0, 0)


## Celda local (X, Z) justo fuera de la puerta marcada con "caracteres", girada.
static func _celda_fuera(tipo: String, giros: int, caracteres: String) -> Vector2i:
	var puerta := _buscar_caracter(tipo, caracteres)
	var d := dimensiones(tipo)
	var fuera := _girar(Vector3i(puerta.x, 0, puerta.z) + _hacia_afuera(tipo, puerta), d.x, d.y, giros)
	return Vector2i(fuera.x, fuera.z)


## Celda local (X, Z) justo fuera de la puerta de entrada (la única, en un puesto
## de recolección), fuera de la huella girada.
static func celda_de_servicio(tipo: String, giros: int) -> Vector2i:
	return _celda_fuera(tipo, giros, "de")


## Celda local (X, Z) justo fuera de la puerta de salida; igual a celda_de_servicio()
## en los tipos de una sola puerta.
static func celda_de_salida(tipo: String, giros: int) -> Vector2i:
	return _celda_fuera(tipo, giros, "ds")


## Celda local (x, capa, z) girada de la puerta inferior de entrada: la que marca la altura
## del edificio (NiveladorTerreno.calcular_base_y(), "puerta_guia"); el terreno frente a la
## puerta de salida se nivela a ese mismo nivel.
static func puerta_de_entrada(tipo: String, giros: int) -> Vector3i:
	var d := dimensiones(tipo)
	return _girar(_buscar_caracter(tipo, "de"), d.x, d.y, giros)


## Celda local (x, capa, z) girada del baúl que hace de depósito del puesto; Vector3i.MAX (igual que
## Economia.SIN_DEPOSITO) si la plantilla no lleva baúl, como la escuela técnica.
static func celda_deposito(tipo: String, giros: int) -> Vector3i:
	if not celdas(tipo, 0).values().has("baul"):
		return Vector3i.MAX
	var d := dimensiones(tipo)
	return _girar(_buscar(tipo, "baul"), d.x, d.y, giros)


## Celda local (x, capa, z) girada del tope de la chimenea de un tipo que la tiene (la refinería):
## de ahí sale su indicador de actividad (el humo, ver HumoRefinerias.gd).
static func celda_chimenea(tipo: String, giros: int) -> Vector3i:
	var d := dimensiones(tipo)
	var columna: Vector2i = PLANTILLAS[tipo]["chimenea"]
	return _girar(Vector3i(columna.x, altura(tipo) - 1, columna.y), d.x, d.y, giros)


## Solo pesca_frutos_mar: índice (0 = extremo de coordenada baja, 1 = alta) del
## extremo de agua a lo largo del eje largo de la huella girada, con la misma
## convención que CamaraCenital._celdas_extremo_pesca() (eje largo = Z si alto > ancho).
static func indice_extremo_agua(giros: int) -> int:
	var tipo := "pesca_frutos_mar"
	var d := dimensiones(tipo)
	var ref: Vector2i = PLANTILLAS[tipo]["agua_ref"]
	var p := _girar(Vector3i(ref.x, 0, ref.y), d.x, d.y, giros)
	var h := huella(tipo, giros)
	var coordenada: int = p.z if h.y > h.x else p.x
	return 0 if coordenada == 0 else 1


## Columnas locales (X, Z) de la fachada: las 2 columnas delante de TODO el lado de
## la huella girada donde está cada puerta (entrada y salida), fuera de la huella (mismo
## criterio que NiveladorTerreno.calcular_base_y() para los blueprints). Se nivelan a la
## altura de la puerta y ahí se reserva el despeje de puertas y ventanas.
static func fachada(tipo: String, giros: int) -> Array[Vector2i]:
	var d := dimensiones(tipo)
	var h := huella(tipo, giros)
	var resultado: Array[Vector2i] = []
	var vistas := {}
	for caracteres in ["de", "ds"]:
		var puerta := _girar(_buscar_caracter(tipo, caracteres), d.x, d.y, giros)
		var servicio := _celda_fuera(tipo, giros, caracteres)
		var direccion := Vector2i(servicio.x - puerta.x, servicio.y - puerta.z)
		for x in range(h.x):
			for z in range(h.y):
				var columna := Vector2i(x, z)
				var vecina := columna + direccion
				if vecina.x >= 0 and vecina.x < h.x and vecina.y >= 0 and vecina.y < h.y:
					continue  # no es del borde del lado de la puerta
				for paso in range(1, 3):
					var candidata := columna + direccion * paso
					if not vistas.has(candidata):
						vistas[candidata] = true
						resultado.append(candidata)
	return resultado
