extends Node

## Autoload "Recoleccion": estado puro de los puestos periféricos
## colocados (minas, caza/recolección, y futuros tipos); registra cada puesto
## por la esquina de su huella real (ancho × alto), permitiendo validar
## solapamientos entre puestos de cualquier tipo.
## Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd: evitar el bug
## de caché de clases globales de Godot).

const RADIO_AREA_MINA := 6
const PROFUNDIDAD_MINA_NIVEL_1 := 8
## Alcance hacia abajo de una mina mejorada (nivel 2) y avanzada (nivel 3) —
## ver detectar_recursos(). Coinciden con GeneradorMundo.PROFUNDIDAD_HIERRO/
## PROFUNDIDAD_TIERRAS_RARAS a propósito: nivel 2 recién empieza a cubrir bien
## la veta de hierro y nivel 3 recién empieza a cubrir bien tierras raras.
const PROFUNDIDAD_MINA_NIVEL_2 := 16
const PROFUNDIDAD_MINA_NIVEL_3 := 24
## Unidades por trabajador y hora de cada mineral (docs/Recursos.xlsx). La tasa
## de un mineral en una mina es su fracción en el área × esta tasa base.
const TASAS_BASE_MINERAL := {
	"tierra": 1.0, "piedra": 5.0, "hierro": 5.0,
	"cobre": 5.0, "carbon": 5.0, "tierras_raras": 5.0,
}

## Marca de "no hay puesto" para esquina_de_puesto_en().
const SIN_PUESTO := Vector2i(-99999, -99999)
## Los únicos tipos de puesto donde se asignan trabajadores (los edificios
## registrados con tipo "blueprint" comparten el registro pero no son puestos).
const TIPOS_PUESTO_TRABAJO := ["mina", "caza_recoleccion", "maderero", "pesca_frutos_mar"]
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

const GeneradorMundoScript = preload("res://scripts/GeneradorMundo.gd")

## Unidades de recurso que rinde un bloque de extracción (sub-proyecto 2B, ver
## docs/superpowers/specs/2026-09-24-extraccion-fisica-agotamiento-design.md).
## "madera" es por celda de tronco. Placeholders de balance; agua (2) y
## petróleo (2) quedan reservados para el sub-proyecto de fluidos.
const RENDIMIENTO_POR_BLOQUE := {
	"tierra": 1.0, "piedra": 10.0, "hierro": 10.0, "cobre": 10.0,
	"carbon": 10.0, "tierras_raras": 10.0, "madera": 10.0,
}

## Una mina solo extrae bloques al menos a esta profundidad bajo la superficie
## natural de su columna (GROSOR_TIERRA - 2), para que el terreno de arriba no
## quede flotando ni con un hueco en la superficie.
const PROFUNDIDAD_MINIMA_EXTRACCION := GeneradorMundoScript.GROSOR_TIERRA - 2

## Centinela: "no hay centro de agua" en entorno_de_puesto().
const SIN_CENTRO := Vector2i(-99999, -99999)
## Centinela: "no queda ningún bloque que extraer" en siguiente_bloque_mina().
const SIN_BLOQUE := Vector3i(-99999, -99999, -99999)

## Ejemplo "mina manual, Tipo 1" del GDD (Sección 3) — puramente
## informativo por ahora: colocar una mina no cobra nada todavía (mismo
## alcance reducido que la nivelación de terreno, el juego no tiene
## inventario de recursos real).
const COSTO_CONSTRUCCION := {"tierra": 10, "madera": 10, "piedra": 5}
## Cupos de trabajadores (decisión del usuario, 2026-09-21): mina 5, maderero 5, caza/recolección 7, pesca 7.
const PERSONAL_MAXIMO := 5
const CAPACIDAD_ALMACENAMIENTO := 1000

const ANCHO_HUELLA_MADERERO := 3
const ALTO_HUELLA_MADERERO := 4

const RADIO_AREA_MADERERO := 12
const PASO_MUESTREO_MADERERO := 2  # mismo patrón de muestreo que caza/recolección
const TASA_BASE_MADERERO_POR_CIUDADANO := 5.0

# GDD Sección 3 — mismos valores que la mina por ahora, sin balance real
# todavía (ver Recoleccion.COSTO_CONSTRUCCION más arriba).
const COSTO_CONSTRUCCION_MADERERO := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_MADERERO := 5
const CAPACIDAD_ALMACENAMIENTO_MADERERO := 1000

const RADIO_AREA_CAZA_RECOLECCION := 12
const PASO_MUESTREO_CAZA_RECOLECCION := 2  # cada 2 celdas, no las ~450 del área completa
const TASA_BASE_CAZA_POR_CIUDADANO := 17.0  # decisión del usuario 2026-09-21: sube de 14 a 17 (antes 10 y luego 14) para que caza y recolección (~12,2 comida/h de media a las densidades medias fauna 0.45, frutal 0.46) sea la opción estable frente a la pesca (media ~8,6, hasta ~14 en costa grande y profunda) y no obligue a ciudades costeras
const TASA_BASE_FRUTOS_POR_CIUDADANO := 10.0  # Excel: columna "Árbol (obj)" era 5 (se interpreta como frutos); decisión del usuario 2026-09-21: sube a 10, ver TASA_BASE_CAZA_POR_CIUDADANO
const ANCHO_HUELLA_CAZA_RECOLECCION := 4
const ALTO_HUELLA_CAZA_RECOLECCION := 4

# GDD Sección 3 — mismos valores que la mina por ahora, sin balance real
# todavía (ver Recoleccion.COSTO_CONSTRUCCION más arriba).
const COSTO_CONSTRUCCION_CAZA_RECOLECCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_CAZA_RECOLECCION := 7
const CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION := 1000

const ANCHO_HUELLA_PESCA_FRUTOS_MAR := 4
const ALTO_HUELLA_PESCA_FRUTOS_MAR := 6

const RADIO_AREA_PESCA_FRUTOS_MAR := 25
const TASA_BASE_PESCA_POR_CIUDADANO := 17.0  # decisión del usuario 2026-09-21: sube de 12 a 17 para compensar el descuento por profundidad (peces ponderados ×0,5 a ×1,5) y que la media del mundo siga en ~8,6 comida/h
const TASA_BASE_ALGAS_POR_CIUDADANO := 3.0  # balance decidido el 2026-09-21; la densidad de algas depende de la profundidad, así que el promedio es aproximado
## Los peces rinden más en agua profunda: cada celda pesa PECES_FACTOR_SOMERO + profundidad relativa
## (×0,5 en el agua más somera hasta ×1,5 en la más profunda). Decisión 2026-09-21.
const PECES_FACTOR_SOMERO := 0.5
## Escala por tamaño del agua conectada (decisión 2026-09-21): celdas / AGUA_REFERENCIA, acotado entre
## ESCALA_AGUA_MIN y ESCALA_AGUA_MAX. 450 celdas es la mediana del mundo actual dentro del radio de 25.
const AGUA_REFERENCIA := 450.0
const ESCALA_AGUA_MIN := 0.4
const ESCALA_AGUA_MAX := 1.5

# GDD Sección 3 — mismos valores placeholder que los otros tres puestos,
# sin balance real todavía (ver Recoleccion.COSTO_CONSTRUCCION).
const COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_PESCA_FRUTOS_MAR := 7
const CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR := 1000

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


## Cupo de trabajadores (recolectores + acarreadores) de un tipo de puesto; 0
## para un tipo que no es puesto de trabajo.
func cupo_de(tipo: String) -> int:
	match tipo:
		"mina": return PERSONAL_MAXIMO
		"maderero": return PERSONAL_MAXIMO_MADERERO
		"caza_recoleccion": return PERSONAL_MAXIMO_CAZA_RECOLECCION
		"pesca_frutos_mar": return PERSONAL_MAXIMO_PESCA_FRUTOS_MAR
	return 0


## Capacidad del almacén local de un tipo de puesto (total entre recursos).
func capacidad_almacen_de(tipo: String) -> int:
	match tipo:
		"mina": return CAPACIDAD_ALMACENAMIENTO
		"maderero": return CAPACIDAD_ALMACENAMIENTO_MADERERO
		"caza_recoleccion": return CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION
		"pesca_frutos_mar": return CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR
	return 0


## Esquina del puesto de trabajo (mina, caza/recolección, maderero, pesca)
## cuya huella contiene "celda", o SIN_PUESTO. Ignora los edificios
## registrados con tipo "blueprint". Usada por CamaraCenital para abrir el
## panel del puesto al hacer clic.
func esquina_de_puesto_en(celda: Vector2i) -> Vector2i:
	for esquina in puestos:
		var datos: Dictionary = puestos[esquina]
		if not TIPOS_PUESTO_TRABAJO.has(datos["tipo"]):
			continue
		if celda.x >= esquina.x and celda.x < esquina.x + datos["ancho"] \
				and celda.y >= esquina.y and celda.y < esquina.y + datos["alto"]:
			return esquina
	return SIN_PUESTO


## Cuenta los tipos de bloque REALES dentro del semielipsoide de acción
## (radio horizontal RADIO_AREA_MINA, hacia abajo "profundidad" — por defecto
## PROFUNDIDAD_MINA_NIVEL_1, pasar PROFUNDIDAD_MINA_NIVEL_2/3 para una mina
## mejorada/avanzada) centrada en (centro_xz, altura_superficie). Antes era
## una semiesfera real (mismo radio para horizontal y profundidad), lo que
## dejaba "profundidad" sin efecto en la práctica cuando superaba
## RADIO_AREA_MINA (el propio radio ya cortaba el alcance vertical antes de
## llegar ahí) — normalizar cada eje por su propio límite antes de medir la
## distancia (elipsoide) permite variar la profundidad sin tocar el radio
## horizontal. Con profundidad == RADIO_AREA_MINA da exactamente la misma
## semiesfera de antes. "mundo" se le pasa por duck typing (necesita solo
## .obtener_tipo(Vector3i) -> String) — mismo patrón que NiveladorTerreno con
## .altura_en(), para poder probar esta función con un VoxelWorld real sin
## depender de generación de ruido.
func detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int, profundidad: int = PROFUNDIDAD_MINA_NIVEL_1, profundidad_minima: int = 0) -> Dictionary:
	var conteo: Dictionary = {}  # String (tipo) -> int
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			# "profundidad_minima" > 0: solo cuenta bloques extraíbles, por debajo de
			# la superficie natural de esta columna y naturales (ver _es_extraible()).
			var techo: int = 1 << 30
			if profundidad_minima > 0:
				techo = mundo.altura_natural_en(centro_xz.x + dx, centro_xz.y + dz) - profundidad_minima
			for dy in range(0, profundidad + 1):
				var normalizado := Vector3(float(dx) / RADIO_AREA_MINA, float(dy) / profundidad, float(dz) / RADIO_AREA_MINA)
				if normalizado.length() > 1.0:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				if celda.y > techo:
					continue
				var tipo: String = mundo.material_real(mundo.obtener_tipo(celda))
				if TIPOS_MINERALES.has(tipo) and (profundidad_minima == 0 or _es_extraible(mundo, celda)):
					conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo


## detectar_recursos() tal como lo ve la mina real: solo subsuelo natural desde
## PROFUNDIDAD_MINIMA_EXTRACCION. Es lo que usan la previsualización, las tasas
## del puesto y la extracción, para que tasa y consumo coincidan.
func detectar_recursos_extraibles(mundo: Object, centro_xz: Vector2i, altura_superficie: int, profundidad: int = PROFUNDIDAD_MINA_NIVEL_1) -> Dictionary:
	return detectar_recursos(mundo, centro_xz, altura_superficie, profundidad, PROFUNDIDAD_MINIMA_EXTRACCION)


## Un bloque es extraíble por una mina si es terreno natural (ni árbol, ni
## estructura, ni parte de un edificio, ni agua) y no lo colocó el jugador.
func _es_extraible(mundo: Object, celda: Vector3i) -> bool:
	return mundo.es_terreno_natural(celda) and not mundo.colocado_por_jugador.has(celda)


## Unidades de recurso que rinde un bloque del tipo "tipo" (0.0 si no rinde).
func rendimiento_de(tipo: String) -> float:
	return RENDIMIENTO_POR_BLOQUE.get(tipo, 0.0)


## Tasa de recolección prevista por ciudadano y tipo de recurso, a partir
## del conteo de detectar_recursos() — proporción de cada tipo dentro del
## área multiplicada por la tasa base de ese mineral (TASAS_BASE_MINERAL). {} si el área no detectó
## nada (evita dividir por cero).
func tasas_recoleccion(conteo: Dictionary) -> Dictionary:
	var total := 0
	for tipo in conteo:
		total += conteo[tipo]
	if total == 0:
		return {}
	var tasas: Dictionary = {}
	for tipo in conteo:
		tasas[tipo] = (float(conteo[tipo]) / float(total)) * TASAS_BASE_MINERAL[tipo]
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


## Dos tasas independientes ("caza"/"recoleccion"), cada señal × la tasa base
## propia del Excel — no se suman en un total, igual que tasas_recoleccion()
## no suma sus minerales.
func tasas_caza_recoleccion(promedios: Dictionary) -> Dictionary:
	return {
		"caza": promedios["fauna"] * TASA_BASE_CAZA_POR_CIUDADANO,
		"recoleccion": promedios["frutal"] * TASA_BASE_FRUTOS_POR_CIUDADANO,
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


## Promedia sobre "celdas_agua" (ver celdas_agua_conectadas()) — ya NO escanea
## un círculo por su cuenta. Devuelve:
## - "peces": promedio de densidad_peces_en() ponderada por profundidad en cada
##   celda: peces × (PECES_FACTOR_SOMERO + (1 - algas)), porque
##   densidad_algas_en() = 1 - profundidad relativa.
## - "algas": promedio de densidad_algas_en() sin ponderar.
## - "escala": tamaño del agua, celdas / AGUA_REFERENCIA acotado a
##   [ESCALA_AGUA_MIN, ESCALA_AGUA_MAX].
## Las tres claves valen 0.0 si "celdas_agua" está vacío (nada que pescar; evita
## dividir por cero).
func detectar_pesca_frutos_mar(generador: Object, celdas_agua: Dictionary) -> Dictionary:
	var suma_peces := 0.0
	var suma_algas := 0.0
	for xz in celdas_agua:
		var algas: float = generador.densidad_algas_en(xz.x, xz.y)
		suma_peces += generador.densidad_peces_en(xz.x, xz.y) * (PECES_FACTOR_SOMERO + (1.0 - algas))
		suma_algas += algas
	var muestras: int = celdas_agua.size()
	if muestras == 0:
		return {"peces": 0.0, "algas": 0.0, "escala": 0.0}
	return {
		"peces": suma_peces / muestras,
		"algas": suma_algas / muestras,
		"escala": clampf(float(muestras) / AGUA_REFERENCIA, ESCALA_AGUA_MIN, ESCALA_AGUA_MAX),
	}


## Dos tasas independientes ("pesca"/"frutos_mar"), cada señal × la tasa base
## propia del Excel × la escala por tamaño del agua ("escala" es obligatoria,
## viene de detectar_pesca_frutos_mar()) — mismo patrón que
## tasas_caza_recoleccion(), no se suman en un total.
func tasas_pesca_frutos_mar(promedios: Dictionary) -> Dictionary:
	return {
		"pesca": promedios["peces"] * TASA_BASE_PESCA_POR_CIUDADANO * promedios["escala"],
		"frutos_mar": promedios["algas"] * TASA_BASE_ALGAS_POR_CIUDADANO * promedios["escala"],
	}


## Siguiente bloque de "recurso" (p. ej. "hierro") que una mina extrae: el más
## cercano al centro del puesto y, a igual distancia, el menos profundo. Solo
## subsuelo natural desde PROFUNDIDAD_MINIMA_EXTRACCION (ver
## detectar_recursos()). SIN_BLOQUE si no queda ninguno.
func siguiente_bloque_mina(mundo: Object, centro_xz: Vector2i, altura_superficie: int, recurso: String, profundidad: int = PROFUNDIDAD_MINA_NIVEL_1) -> Vector3i:
	var mejor := SIN_BLOQUE
	var mejor_distancia := INF
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			var techo: int = mundo.altura_natural_en(centro_xz.x + dx, centro_xz.y + dz) - PROFUNDIDAD_MINIMA_EXTRACCION
			for dy in range(0, profundidad + 1):
				var normalizado := Vector3(float(dx) / RADIO_AREA_MINA, float(dy) / profundidad, float(dz) / RADIO_AREA_MINA)
				if normalizado.length() > 1.0:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				if celda.y > techo:
					continue
				if mundo.material_real(mundo.obtener_tipo(celda)) != recurso or not _es_extraible(mundo, celda):
					continue
				var distancia := float(dx * dx + dy * dy + dz * dz)
				if distancia < mejor_distancia or (distancia == mejor_distancia and celda.y > mejor.y):
					mejor_distancia = distancia
					mejor = celda
	return mejor


## Árboles vivos registrados a "radio" celdas o menos de "centro".
func arboles_vivos_en(mundo: Object, centro: Vector2i, radio: int) -> int:
	return mundo.arboles.ids_en_radio(centro, radio).size()


## Lo que un puesto necesita recordar del mundo para recalcular sus tasas y
## extraer: "centro" y "altura" (superficie en el centro al colocarlo);
## "centro_agua" (pesca); "radio_arboles" y "arboles_ref" (árboles vivos en su
## área al colocarlo — caza/recolección y maderero).
func entorno_de_puesto(tipo: String, mundo: Object, centro: Vector2i, altura: int, centro_agua: Vector2i = SIN_CENTRO) -> Dictionary:
	var entorno := {"centro": centro, "altura": altura}
	if centro_agua != SIN_CENTRO:
		entorno["centro_agua"] = centro_agua
	if tipo == "caza_recoleccion" or tipo == "maderero":
		var radio: int = RADIO_AREA_MADERERO if tipo == "maderero" else RADIO_AREA_CAZA_RECOLECCION
		entorno["radio_arboles"] = radio
		entorno["arboles_ref"] = arboles_vivos_en(mundo, centro, radio)
	return entorno


## Fracción de los árboles de su área que sigue en pie (tope 1.0). Sin árboles
## de referencia al colocar el puesto no hay nada que escalar: 1.0.
func factor_arboles(mundo: Object, entorno: Dictionary) -> float:
	var referencia: int = entorno.get("arboles_ref", 0)
	if referencia <= 0:
		return 1.0
	return minf(1.0, float(arboles_vivos_en(mundo, entorno["centro"], entorno["radio_arboles"])) / float(referencia))


## Tasas por trabajador y hora de un puesto según el estado ACTUAL del mundo
## (mismas claves que tasas_recoleccion()/tasas_caza_recoleccion()/
## tasa_maderero()/tasas_pesca_frutos_mar()). Caza/recolección y maderero se
## escalan con factor_arboles(): talar el bosque reduce fauna, frutos y madera.
func tasas_de_entorno(tipo: String, mundo: Object, entorno: Dictionary) -> Dictionary:
	var centro: Vector2i = entorno["centro"]
	if tipo == "mina":
		return tasas_recoleccion(detectar_recursos_extraibles(mundo, centro, entorno["altura"]))
	if tipo == "pesca_frutos_mar":
		if not entorno.has("centro_agua"):
			return {}
		var celdas_agua: Dictionary = celdas_agua_conectadas(mundo.generador, entorno["centro_agua"], RADIO_AREA_PESCA_FRUTOS_MAR)
		return tasas_pesca_frutos_mar(detectar_pesca_frutos_mar(mundo.generador, celdas_agua))
	var tasas: Dictionary
	if tipo == "caza_recoleccion":
		tasas = tasas_caza_recoleccion(detectar_fauna_frutal(mundo.generador, centro))
	else:
		tasas = tasa_maderero(detectar_arbol(mundo.generador, centro))
	var factor := factor_arboles(mundo, entorno)
	for clave in tasas:
		tasas[clave] *= factor
	return tasas
