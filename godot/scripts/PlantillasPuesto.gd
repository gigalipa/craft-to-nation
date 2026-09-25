extends RefCounted

## Plantillas prediseñadas de los puestos de recolección (spec: docs/superpowers/
## specs/2026-09-24-edificios-recoleccion-plantillas-design.md). Datos puros y
## funciones estáticas, sin autoload ni class_name (se carga con preload, como
## el resto de scripts sin estado).
##
## Cada plantilla son "capas" de abajo hacia arriba (la capa 0 se coloca en
## objetivo + 1). Una capa es una lista de filas (eje Z); una fila, un texto con
## un carácter por columna (eje X). En la plantilla base la puerta está en la
## fila z = 0 y mira a −Z. Este mismo formato lo producirá luego el conversor
## de .obj de SketchUp, así que el arte reemplaza estas plantillas provisionales
## sin tocar código.

## Carácter -> bloque. "." (y cualquier otro carácter) es vacío.
const BLOQUES := {
	"#": "pared", "V": "ventana", "B": "baul",
	"d": "puerta_inferior", "D": "puerta_superior",
}

const PLANTILLAS := {
	"mina": {"capas": [
		["##d##", "#...#", "#..B#", "#...#", "#####"],
		["##D##", "#...#", "#...#", "#...#", "#####"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
	"caza_recoleccion": {"capas": [
		["##d#", "#..#", "#.B#", "####"],
		["##D#", "V..V", "#..#", "##V#"],
		["####", "####", "####", "####"],
	]},
	"maderero": {"capas": [
		["#d#", "#.#", "#B#", "###"],
		["#D#", "#.#", "#.#", "###"],
		["###", "###", "###", "###"],
	]},
	# Edificio en las filas 0-2 y muelle (cubierta de pared) en las filas 3-5; el
	# agua queda del lado de z alto. "agua_ref" (x, z) es una celda del extremo de agua.
	"pesca_frutos_mar": {"capas": [
		["#d##", "#B.#", "####", "####", "####", "####"],
		["#D##", "V..V", "####", "....", "....", "...."],
		["####", "####", "####", "....", "....", "...."],
	], "agua_ref": Vector2i(0, 5)},
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
	for y in range(capas.size()):
		var filas: Array = capas[y]
		for z in range(filas.size()):
			var fila: String = filas[z]
			for x in range(fila.length()):
				if BLOQUES.has(fila[x]):
					resultado[_girar(Vector3i(x, y, z), d.x, d.y, giros)] = BLOQUES[fila[x]]
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


## Celda local (X, Z) justo fuera de la puerta, fuera de la huella girada.
static func celda_de_servicio(tipo: String, giros: int) -> Vector2i:
	var puerta := _buscar(tipo, "puerta_inferior")
	var d := dimensiones(tipo)
	var fuera := _girar(Vector3i(puerta.x, 0, puerta.z - 1), d.x, d.y, giros)
	return Vector2i(fuera.x, fuera.z)


## Celda local (x, capa, z) del baúl que hace de depósito del puesto.
static func celda_deposito(tipo: String, giros: int) -> Vector3i:
	var d := dimensiones(tipo)
	return _girar(_buscar(tipo, "baul"), d.x, d.y, giros)


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
## la huella girada donde está la puerta, fuera de la huella (mismo criterio que
## NiveladorTerreno.calcular_base_y() para los blueprints). Se nivelan a la altura
## de la puerta y ahí se reserva el despeje de puertas y ventanas.
static func fachada(tipo: String, giros: int) -> Array[Vector2i]:
	var d := dimensiones(tipo)
	var h := huella(tipo, giros)
	var puerta := _girar(_buscar(tipo, "puerta_inferior"), d.x, d.y, giros)
	var servicio := celda_de_servicio(tipo, giros)
	var direccion := Vector2i(servicio.x - puerta.x, servicio.y - puerta.z)
	var resultado: Array[Vector2i] = []
	for x in range(h.x):
		for z in range(h.y):
			var columna := Vector2i(x, z)
			var vecina := columna + direccion
			if vecina.x >= 0 and vecina.x < h.x and vecina.y >= 0 and vecina.y < h.y:
				continue  # no es del borde del lado de la puerta
			for paso in range(1, 3):
				resultado.append(columna + direccion * paso)
	return resultado
