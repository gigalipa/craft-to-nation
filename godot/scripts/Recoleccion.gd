extends Node

## Autoload "Recoleccion": estado puro de los puestos periféricos
## colocados (minas, caza/recolección, y futuros tipos); registra cada puesto
## por la esquina de su huella real (ancho × alto), permitiendo validar
## solapamientos entre puestos de cualquier tipo.
## Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd: evitar el bug
## de caché de clases globales de Godot).

const RADIO_AREA_MINA := 6
const PROFUNDIDAD_MINA_NIVEL_1 := 8
const TASA_BASE_POR_CIUDADANO := 2.0
const ANCHO_HUELLA_MINA := 5
const ALTO_HUELLA_MINA := 5

## Catálogo de minerales que una mina puede detectar y recolectar (GDD,
## Sección 4: "Minas — catálogo de hasta 6 tipos"). Whitelist en vez de
## denylist: antes solo se excluían "madera"/"follaje" (árboles), pero eso
## dejaba pasar cualquier otro tipo, incluyendo bloques estructurales
## (pared, ventana, puerta, cama, baúl) si la mina quedaba bajo un
## edificio — bug reportado por el usuario jugando en vivo (la ficha
## mostraba "pared"/"ventana" como si la mina pudiera extraerlos). "cobre",
## "carbon" y "tierras_raras" no tienen bloque real en el mundo todavía
## (solo hierro/tierra/piedra — ver GeneradorMundo.gd), pero se incluyen
## para no requerir tocar este archivo cuando se agreguen sus vetas.
const TIPOS_MINERALES := ["tierra", "piedra", "hierro", "cobre", "carbon", "tierras_raras"]

## Ejemplo "mina manual, Tipo 1" del GDD (Sección 3) — puramente
## informativo por ahora: colocar una mina no cobra nada todavía (mismo
## alcance reducido que la nivelación de terreno, el juego no tiene
## inventario de recursos real).
const COSTO_CONSTRUCCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO := 3
const CAPACIDAD_ALMACENAMIENTO := 100

const ANCHO_HUELLA_MADERERO := 3
const ALTO_HUELLA_MADERERO := 4

const RADIO_AREA_MADERERO := 12
const PASO_MUESTREO_MADERERO := 2  # mismo patrón de muestreo que caza/recolección
const TASA_BASE_MADERERO_POR_CIUDADANO := 2.0

# GDD Sección 3 — mismos valores que la mina por ahora, sin balance real
# todavía (ver Recoleccion.COSTO_CONSTRUCCION más arriba).
const COSTO_CONSTRUCCION_MADERERO := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_MADERERO := 3
const CAPACIDAD_ALMACENAMIENTO_MADERERO := 100

const RADIO_AREA_CAZA_RECOLECCION := 12
const PASO_MUESTREO_CAZA_RECOLECCION := 2  # cada 2 celdas, no las ~450 del área completa
const TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO := 2.0
const ANCHO_HUELLA_CAZA_RECOLECCION := 4
const ALTO_HUELLA_CAZA_RECOLECCION := 4

# GDD Sección 3 — mismos valores que la mina por ahora, sin balance real
# todavía (ver Recoleccion.COSTO_CONSTRUCCION más arriba).
const COSTO_CONSTRUCCION_CAZA_RECOLECCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_CAZA_RECOLECCION := 3
const CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION := 100

const ANCHO_HUELLA_PESCA_FRUTOS_MAR := 4
const ALTO_HUELLA_PESCA_FRUTOS_MAR := 6

const RADIO_AREA_PESCA_FRUTOS_MAR := 25
const TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO := 2.0

# GDD Sección 3 — mismos valores placeholder que los otros tres puestos,
# sin balance real todavía (ver Recoleccion.COSTO_CONSTRUCCION).
const COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_PESCA_FRUTOS_MAR := 3
const CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR := 100

## Vector2i (esquina de la huella, celda de menor X/Z) -> {"tipo": String,
## "ancho": int, "alto": int, "nivel": int}. Antes solo guardaba minas
## indexadas por su único bloque marcador; ahora guarda cualquier puesto
## periférico por la esquina de su huella real, para poder validar choques
## entre puestos de cualquier tipo (ver celda_dentro_de_algun_puesto()).
var puestos: Dictionary = {}


func colocar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int) -> void:
	puestos[esquina] = {"tipo": tipo, "ancho": ancho, "alto": alto, "nivel": 1}


## Libera la reserva de un puesto/edificio en "esquina" — usada al
## completarse la deconstrucción total de un edificio (ver
## VoxelWorld.eliminar_edificio()/Player.gd) para que su footprint vuelva a
## estar disponible para una nueva construcción. No-op si no había nada
## registrado en esa esquina (p. ej. un edificio declarado a mano, que
## nunca pasa por colocar_puesto()).
func quitar_puesto(esquina: Vector2i) -> void:
	puestos.erase(esquina)


## true si "celda" cae dentro de la huella de algún puesto ya colocado (de
## cualquier tipo) — usada al previsualizar una nueva colocación, para
## rechazarla si se solapa con un puesto existente (ver CamaraCenital.gd).
func celda_dentro_de_algun_puesto(celda: Vector2i) -> bool:
	for esquina in puestos:
		var datos: Dictionary = puestos[esquina]
		var ancho: int = datos["ancho"]
		var alto: int = datos["alto"]
		if celda.x >= esquina.x and celda.x < esquina.x + ancho \
				and celda.y >= esquina.y and celda.y < esquina.y + alto:
			return true
	return false


## Cuenta los tipos de bloque REALES dentro de la semiesfera de acción
## (radio horizontal RADIO_AREA_MINA, hacia abajo PROFUNDIDAD_MINA_NIVEL_1)
## centrada en (centro_xz, altura_superficie). "mundo" se le pasa por duck
## typing (necesita solo .obtener_tipo(Vector3i) -> String) — mismo patrón
## que NiveladorTerreno con .altura_en(), para poder probar esta función
## con un VoxelWorld real sin depender de generación de ruido.
func detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Dictionary:
	var conteo: Dictionary = {}  # String (tipo) -> int
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			for dy in range(0, PROFUNDIDAD_MINA_NIVEL_1 + 1):
				var offset := Vector3(dx, -dy, dz)
				if offset.length() > RADIO_AREA_MINA:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				var tipo: String = mundo.material_real(mundo.obtener_tipo(celda))
				if TIPOS_MINERALES.has(tipo):
					conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo


## Tasa de recolección prevista por ciudadano y tipo de recurso, a partir
## del conteo de detectar_recursos() — proporción de cada tipo dentro del
## área multiplicada por TASA_BASE_POR_CIUDADANO. {} si el área no detectó
## nada (evita dividir por cero).
func tasas_recoleccion(conteo: Dictionary) -> Dictionary:
	var total := 0
	for tipo in conteo:
		total += conteo[tipo]
	if total == 0:
		return {}
	var tasas: Dictionary = {}
	for tipo in conteo:
		tasas[tipo] = (float(conteo[tipo]) / float(total)) * TASA_BASE_POR_CIUDADANO
	return tasas


## Promedia densidad_fauna_en()/densidad_frutal_en() (GeneradorMundo — duck
## typing, mismo patrón que NiveladorTerreno con altura_en()) muestreadas
## cada PASO_MUESTREO_CAZA_RECOLECCION celdas dentro del círculo de radio
## RADIO_AREA_CAZA_RECOLECCION centrado en centro_xz. Siempre devuelve ambas
## claves — 0.0 si no hubo ninguna muestra (evita dividir por cero).
func detectar_fauna_frutal(generador: Object, centro_xz: Vector2i) -> Dictionary:
	var suma_fauna := 0.0
	var suma_frutal := 0.0
	var muestras := 0
	for dx in range(-RADIO_AREA_CAZA_RECOLECCION, RADIO_AREA_CAZA_RECOLECCION + 1, PASO_MUESTREO_CAZA_RECOLECCION):
		for dz in range(-RADIO_AREA_CAZA_RECOLECCION, RADIO_AREA_CAZA_RECOLECCION + 1, PASO_MUESTREO_CAZA_RECOLECCION):
			if Vector2(dx, dz).length() > RADIO_AREA_CAZA_RECOLECCION:
				continue
			var x: int = centro_xz.x + dx
			var z: int = centro_xz.y + dz
			suma_fauna += generador.densidad_fauna_en(x, z)
			suma_frutal += generador.densidad_frutal_en(x, z)
			muestras += 1
	if muestras == 0:
		return {"fauna": 0.0, "frutal": 0.0}
	return {"fauna": suma_fauna / muestras, "frutal": suma_frutal / muestras}


## Dos tasas independientes ("caza"/"recoleccion"), cada una promedio_señal *
## TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO — no se suman en un total, igual
## que tasas_recoleccion() no suma sus minerales.
func tasas_caza_recoleccion(promedios: Dictionary) -> Dictionary:
	return {
		"caza": promedios["fauna"] * TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO,
		"recoleccion": promedios["frutal"] * TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO,
	}


## Promedia densidad_arbol_en() (GeneradorMundo — duck typing, mismo patrón
## que detectar_fauna_frutal()) muestreada cada PASO_MUESTREO_MADERERO
## celdas dentro del círculo de radio RADIO_AREA_MADERERO centrado en
## centro_xz. 0.0 si no hubo ninguna muestra (evita dividir por cero).
func detectar_arbol(generador: Object, centro_xz: Vector2i) -> float:
	var suma_arbol := 0.0
	var muestras := 0
	for dx in range(-RADIO_AREA_MADERERO, RADIO_AREA_MADERERO + 1, PASO_MUESTREO_MADERERO):
		for dz in range(-RADIO_AREA_MADERERO, RADIO_AREA_MADERERO + 1, PASO_MUESTREO_MADERERO):
			if Vector2(dx, dz).length() > RADIO_AREA_MADERERO:
				continue
			suma_arbol += generador.densidad_arbol_en(centro_xz.x + dx, centro_xz.y + dz)
			muestras += 1
	if muestras == 0:
		return 0.0
	return suma_arbol / muestras


## Tasa de "madera" prevista por ciudadano, a partir de detectar_arbol() —
## mismo patrón de retorno (Dictionary tipo -> tasa) que tasas_recoleccion()
## y tasas_caza_recoleccion(), para que CamaraCenital/HUD los traten igual.
func tasa_maderero(promedio_arbol: float) -> Dictionary:
	return {"madera": promedio_arbol * TASA_BASE_MADERERO_POR_CIUDADANO}


## Flood-fill acotado: todas las celdas de agua (mar/lago/río, ver
## GeneradorMundo.es_agua_o_rio_en()) alcanzables desde "centro_xz"
## siguiendo solo adyacencia real (4 direcciones), sin nunca salir del
## círculo de radio "radio". Devuelve un Dictionary (Vector2i -> true) para
## membresía O(1) — usado tanto por el círculo visual
## (CamaraCenital._actualizar_area_accion_agua()) como por
## detectar_pesca_frutos_mar(), para que ambos vean exactamente el mismo
## conjunto de celdas. Vacío si "centro_xz" mismo no es agua.
func celdas_agua_conectadas(generador: Object, centro_xz: Vector2i, radio: int) -> Dictionary:
	var visitadas: Dictionary = {}
	if not generador.es_agua_o_rio_en(centro_xz.x, centro_xz.y):
		return visitadas
	var pendientes: Array[Vector2i] = [centro_xz]
	visitadas[centro_xz] = true
	var direcciones := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not pendientes.is_empty():
		var actual: Vector2i = pendientes.pop_back()
		for dir in direcciones:
			var vecino: Vector2i = actual + dir
			if visitadas.has(vecino):
				continue
			if Vector2(vecino - centro_xz).length() > radio:
				continue
			if not generador.es_agua_o_rio_en(vecino.x, vecino.y):
				continue
			visitadas[vecino] = true
			pendientes.append(vecino)
	return visitadas


## Promedia densidad_peces_en()/densidad_algas_en() sobre "celdas_agua" (ver
## celdas_agua_conectadas()) — ya NO escanea un círculo por su cuenta.
## Devuelve ambas claves en 0.0 si "celdas_agua" está vacío (evita dividir
## por cero).
func detectar_pesca_frutos_mar(generador: Object, celdas_agua: Dictionary) -> Dictionary:
	var suma_peces := 0.0
	var suma_algas := 0.0
	for xz in celdas_agua:
		suma_peces += generador.densidad_peces_en(xz.x, xz.y)
		suma_algas += generador.densidad_algas_en(xz.x, xz.y)
	var muestras: int = celdas_agua.size()
	if muestras == 0:
		return {"peces": 0.0, "algas": 0.0}
	return {"peces": suma_peces / muestras, "algas": suma_algas / muestras}


## Dos tasas independientes ("pesca"/"frutos_mar"), cada una promedio_señal *
## TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO — mismo patrón que
## tasas_caza_recoleccion(), no se suman en un total.
func tasas_pesca_frutos_mar(promedios: Dictionary) -> Dictionary:
	return {
		"pesca": promedios["peces"] * TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO,
		"frutos_mar": promedios["algas"] * TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO,
	}
