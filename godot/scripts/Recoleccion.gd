extends Node

## Autoload "Recoleccion": estado puro de los puestos periféricos
## colocados (minas, caza/recolección, y futuros tipos); registra cada puesto
## por la esquina de su huella real (ancho × alto), permitiendo validar
## solapamientos entre puestos de cualquier tipo.
## Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd: evitar el bug
## de caché de clases globales de Godot).

const Ajustes = preload("res://scripts/ajustes.gd")

static var RADIO_AREA_MINA: int = Ajustes.RECOLECCION_RADIO_AREA_MINA
static var PROFUNDIDAD_MINA_NIVEL_1: int = Ajustes.RECOLECCION_PROFUNDIDAD_MINA_NIVEL_1
## Alcance hacia abajo de una mina mejorada (nivel 2) y avanzada (nivel 3) —
## ver detectar_recursos(). Coinciden con GeneradorMundo.PROFUNDIDAD_HIERRO/
## PROFUNDIDAD_TIERRAS_RARAS a propósito: nivel 2 recién empieza a cubrir bien
## la veta de hierro y nivel 3 recién empieza a cubrir bien tierras raras.
static var PROFUNDIDAD_MINA_NIVEL_2: int = Ajustes.RECOLECCION_PROFUNDIDAD_MINA_NIVEL_2
static var PROFUNDIDAD_MINA_NIVEL_3: int = Ajustes.RECOLECCION_PROFUNDIDAD_MINA_NIVEL_3
## Puestos de recolección con niveles 1-3 (ver docs/superpowers/specs/2026-10-02-niveles-de-puesto-empleo-por-tipo-design.md).
const TIPOS_CON_NIVELES := ["mina", "maderero", "caza_recoleccion", "pesca_frutos_mar"]
## Velocidad del puesto por nivel. La mina no la usa (ver multiplicador_de_nivel()): su nivel amplía el volumen.
static var MULTIPLICADOR_NIVEL: Dictionary = Ajustes.RECOLECCION_MULTIPLICADOR_NIVEL
## Unidades por trabajador y hora de cada mineral (docs/Recursos.xlsx). La tasa
## de un mineral en una mina es su fracción en el área × esta tasa base.
static var TASAS_BASE_MINERAL: Dictionary = Ajustes.RECOLECCION_TASAS_BASE_MINERAL

## Marca de "no hay puesto" para esquina_de_puesto_en().
const SIN_PUESTO := Vector2i(-99999, -99999)
## Los únicos tipos de puesto donde se asignan trabajadores (los edificios
## registrados con tipo "blueprint" comparten el registro pero no son puestos).
## Madera/h por recolector bajo la cual un maderero se da por agotado (decisión del usuario, 2026-10-02).
static var UMBRAL_AGOTADO_MADERERO: float = Ajustes.RECOLECCION_UMBRAL_AGOTADO_MADERERO

const TIPOS_PUESTO_TRABAJO := ["mina", "caza_recoleccion", "maderero", "pesca_frutos_mar", "siderurgica", "refineria_tierras_raras", "aserradero", "fabrica_bloques", "vidriera", "carbonera", "refineria_petrolera", "productor_combustible", "central_termoelectrica", "escuela_tecnica", "escuela_especialistas", "universidad", "estacion_bombeo", "centro_extraccion", "almacen", "taller_transporte"]
## Escuelas: tipo de puesto -> {"origen", "destino", "horas"} (tipos de Ciudad.TIPOS_POBLACION). Una cohorte de
## x_cama[origen] colonos de origen sale como x_cama[destino] colonos de destino: la vivienda ocupada se
## conserva (4 obreros = 3 técnicos, 3 técnicos = 2 especialistas) y quien sobra se va de la ciudad.
static var ESCUELAS: Dictionary = Ajustes.RECOLECCION_ESCUELAS
static var ANCHO_HUELLA_MINA: int = Ajustes.RECOLECCION_ANCHO_HUELLA_MINA
static var ALTO_HUELLA_MINA: int = Ajustes.RECOLECCION_ALTO_HUELLA_MINA

## Catálogo de minerales que una mina puede detectar y recolectar (GDD,
## Sección 4: "Minas — catálogo de hasta 6 tipos"). Whitelist en vez de
## denylist: antes solo se excluían "madera"/"follaje" (árboles), pero eso
## dejaba pasar cualquier otro tipo, incluyendo bloques estructurales
## (muros, vidrio, puerta, cama, baúl) si la mina quedaba bajo un
## edificio — bug reportado por el usuario jugando en vivo (la ficha
## mostraba materiales de muro/vidrio como si la mina pudiera extraerlos). "cobre",
## "carbon" y "tierras_raras" no tienen bloque real en el mundo todavía
## (solo hierro/tierra/piedra — ver GeneradorMundo.gd), pero se incluyen
## para no requerir tocar este archivo cuando se agreguen sus vetas.
const TIPOS_MINERALES := ["tierra", "piedra", "hierro", "cobre", "carbon", "tierras_raras"]

const GeneradorMundoScript = preload("res://scripts/GeneradorMundo.gd")

## Unidades de recurso que rinde un bloque de extracción (sub-proyecto 2B, ver
## docs/superpowers/specs/2026-09-24-extraccion-fisica-agotamiento-design.md).
## "madera" es por celda de tronco. Placeholders de balance; agua (2) y
## petróleo (2) quedan reservados para el sub-proyecto de fluidos.
static var RENDIMIENTO_POR_BLOQUE: Dictionary = Ajustes.RECOLECCION_RENDIMIENTO_POR_BLOQUE

## Segundos que el avatar tarda en minar un bloque por tipo (material real,
## "hierba" cuenta como "tierra"), como en Minecraft. Los tipos sin entrada
## (construcciones del jugador) usan TIEMPO_MINADO_DEFECTO. Placeholders.
static var TIEMPO_MINADO: Dictionary = Ajustes.RECOLECCION_TIEMPO_MINADO
static var TIEMPO_MINADO_DEFECTO: float = Ajustes.RECOLECCION_TIEMPO_MINADO_DEFECTO
## Sin herramientas todavía: cuando existan, dividirá el tiempo de minado.
static var MULTIPLICADOR_HERRAMIENTA: float = Ajustes.RECOLECCION_MULTIPLICADOR_HERRAMIENTA
## Segundos de golpes sostenidos por cada punto de salud (una celda de tronco) de un árbol.
static var TIEMPO_TALA_POR_SALUD: float = Ajustes.RECOLECCION_TIEMPO_TALA_POR_SALUD
## Frutos que el avatar recolecta de un árbol (no lo consume): segundos, comida a
## densidad frutal 1.0 y horas de juego que el árbol tarda en volver a dar frutos.
static var TIEMPO_RECOLECCION_FRUTOS: float = Ajustes.RECOLECCION_TIEMPO_RECOLECCION_FRUTOS
static var COMIDA_POR_RECOLECCION: float = Ajustes.RECOLECCION_COMIDA_POR_RECOLECCION
static var HORAS_REBROTE_FRUTOS: int = Ajustes.RECOLECCION_HORAS_REBROTE_FRUTOS

## Una mina solo extrae bloques al menos a esta profundidad bajo la superficie
## natural de su columna (GROSOR_TIERRA - 2), para que el terreno de arriba no
## quede flotando ni con un hueco en la superficie.
static var PROFUNDIDAD_MINIMA_EXTRACCION: int = Ajustes.RECOLECCION_PROFUNDIDAD_MINIMA_EXTRACCION

## Centinela: "no hay centro de agua" en entorno_de_puesto().
const SIN_CENTRO := Vector2i(-99999, -99999)
## Centinela: "no queda ningún bloque que extraer" en siguiente_bloque_mina().
const SIN_BLOQUE := Vector3i(-99999, -99999, -99999)

## Cupos de trabajadores (decisión del usuario, 2026-09-21): mina 5, maderero 5, caza/recolección 7, pesca 7.
static var PERSONAL_MAXIMO: int = Ajustes.RECOLECCION_PERSONAL_MAXIMO
static var CAPACIDAD_ALMACENAMIENTO: int = Ajustes.RECOLECCION_CAPACIDAD_ALMACENAMIENTO

static var ANCHO_HUELLA_MADERERO: int = Ajustes.RECOLECCION_ANCHO_HUELLA_MADERERO
static var ALTO_HUELLA_MADERERO: int = Ajustes.RECOLECCION_ALTO_HUELLA_MADERERO

static var RADIO_AREA_MADERERO: int = Ajustes.RECOLECCION_RADIO_AREA_MADERERO
static var PASO_MUESTREO_MADERERO: int = Ajustes.RECOLECCION_PASO_MUESTREO_MADERERO  # mismo patrón de muestreo que caza/recolección
static var TASA_BASE_MADERERO_POR_CIUDADANO: float = Ajustes.RECOLECCION_TASA_BASE_MADERERO_POR_CIUDADANO

static var PERSONAL_MAXIMO_MADERERO: int = Ajustes.RECOLECCION_PERSONAL_MAXIMO_MADERERO
static var CAPACIDAD_ALMACENAMIENTO_MADERERO: int = Ajustes.RECOLECCION_CAPACIDAD_ALMACENAMIENTO_MADERERO

static var RADIO_AREA_CAZA_RECOLECCION: int = Ajustes.RECOLECCION_RADIO_AREA_CAZA_RECOLECCION
static var PASO_MUESTREO_CAZA_RECOLECCION: int = Ajustes.RECOLECCION_PASO_MUESTREO_CAZA_RECOLECCION  # cada 2 celdas, no las ~450 del área completa
static var TASA_BASE_CAZA_POR_CIUDADANO: float = Ajustes.RECOLECCION_TASA_BASE_CAZA_POR_CIUDADANO  # decisión del usuario 2026-09-21: sube de 14 a 17 (antes 10 y luego 14) para que caza y recolección (~12,2 comida/h de media a las densidades medias fauna 0.45, frutal 0.46) sea la opción estable frente a la pesca (media ~8,6, hasta ~14 en costa grande y profunda) y no obligue a ciudades costeras
static var TASA_BASE_FRUTOS_POR_CIUDADANO: float = Ajustes.RECOLECCION_TASA_BASE_FRUTOS_POR_CIUDADANO  # Excel: columna "Árbol (obj)" era 5 (se interpreta como frutos); decisión del usuario 2026-09-21: sube a 10, ver TASA_BASE_CAZA_POR_CIUDADANO
static var ANCHO_HUELLA_CAZA_RECOLECCION: int = Ajustes.RECOLECCION_ANCHO_HUELLA_CAZA_RECOLECCION
static var ALTO_HUELLA_CAZA_RECOLECCION: int = Ajustes.RECOLECCION_ALTO_HUELLA_CAZA_RECOLECCION

static var PERSONAL_MAXIMO_CAZA_RECOLECCION: int = Ajustes.RECOLECCION_PERSONAL_MAXIMO_CAZA_RECOLECCION
static var CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION: int = Ajustes.RECOLECCION_CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION

static var ANCHO_HUELLA_PESCA_FRUTOS_MAR: int = Ajustes.RECOLECCION_ANCHO_HUELLA_PESCA_FRUTOS_MAR
static var ALTO_HUELLA_PESCA_FRUTOS_MAR: int = Ajustes.RECOLECCION_ALTO_HUELLA_PESCA_FRUTOS_MAR

static var RADIO_AREA_PESCA_FRUTOS_MAR: int = Ajustes.RECOLECCION_RADIO_AREA_PESCA_FRUTOS_MAR
static var TASA_BASE_PESCA_POR_CIUDADANO: float = Ajustes.RECOLECCION_TASA_BASE_PESCA_POR_CIUDADANO  # decisión del usuario 2026-09-21: sube de 12 a 17 para compensar el descuento por profundidad (peces ponderados ×0,5 a ×1,5) y que la media del mundo siga en ~8,6 comida/h
static var TASA_BASE_ALGAS_POR_CIUDADANO: float = Ajustes.RECOLECCION_TASA_BASE_ALGAS_POR_CIUDADANO  # balance decidido el 2026-09-21; la densidad de algas depende de la profundidad, así que el promedio es aproximado
## Los peces rinden más en agua profunda: cada celda pesa PECES_FACTOR_SOMERO + profundidad relativa
## (×0,5 en el agua más somera hasta ×1,5 en la más profunda). Decisión 2026-09-21.
static var PECES_FACTOR_SOMERO: float = Ajustes.RECOLECCION_PECES_FACTOR_SOMERO
## Escala por tamaño del agua conectada (decisión 2026-09-21): celdas / AGUA_REFERENCIA, acotado entre
## ESCALA_AGUA_MIN y ESCALA_AGUA_MAX. 450 celdas es la mediana del mundo actual dentro del radio de 25.
static var AGUA_REFERENCIA: float = Ajustes.RECOLECCION_AGUA_REFERENCIA
static var ESCALA_AGUA_MIN: float = Ajustes.RECOLECCION_ESCALA_AGUA_MIN
static var ESCALA_AGUA_MAX: float = Ajustes.RECOLECCION_ESCALA_AGUA_MAX

static var PERSONAL_MAXIMO_PESCA_FRUTOS_MAR: int = Ajustes.RECOLECCION_PERSONAL_MAXIMO_PESCA_FRUTOS_MAR
static var CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR: int = Ajustes.RECOLECCION_CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR

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


## Cupo de trabajadores (recolectores + acarreadores + aprendices) de un tipo de puesto; 0
## para un tipo que no es puesto de trabajo.
func cupo_de(tipo: String) -> int:
	match tipo:
		"mina": return PERSONAL_MAXIMO
		"maderero": return PERSONAL_MAXIMO_MADERERO
		"caza_recoleccion": return PERSONAL_MAXIMO_CAZA_RECOLECCION
		"pesca_frutos_mar": return PERSONAL_MAXIMO_PESCA_FRUTOS_MAR
		"universidad": return 3
		"central_termoelectrica": return 4
		"estacion_bombeo", "centro_extraccion": return 3
		"almacen": return 0
		"taller_transporte": return 4
	if CadenaMinerales.REFINERIAS.has(tipo):
		return CadenaMinerales.PERSONAL_MAXIMO_REFINERIA
	if ESCUELAS.has(tipo):
		return Ciudad.TIPOS_POBLACION[ESCUELAS[tipo]["origen"]]["x_cama"]  # el cupo es la cohorte
	return 0


## Capacidad del almacén local de un tipo de puesto (total entre recursos).
func capacidad_almacen_de(tipo: String) -> int:
	match tipo:
		"mina": return CAPACIDAD_ALMACENAMIENTO
		"maderero": return CAPACIDAD_ALMACENAMIENTO_MADERERO
		"caza_recoleccion": return CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION
		"pesca_frutos_mar": return CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR
		"central_termoelectrica": return 300
		"estacion_bombeo", "centro_extraccion": return 500
		"almacen": return 3000
		"taller_transporte": return 500
	if CadenaMinerales.REFINERIAS.has(tipo):
		return CadenaMinerales.CAPACIDAD_ALMACENAMIENTO_REFINERIA
	return 0


## Radio de un puesto de área circular en ese nivel: +50 % del radio base por nivel (12 → 18 → 24; 25 → 37 → 50).
func radio_de_nivel(radio_base: int, nivel: int) -> int:
	return int(radio_base * (1.0 + 0.5 * (nivel - 1)))


## Profundidad acumulada de una mina en ese nivel (nivel 1 si no es 2 ni 3).
func profundidad_de_nivel(nivel: int) -> int:
	match nivel:
		2: return PROFUNDIDAD_MINA_NIVEL_2
		3: return PROFUNDIDAD_MINA_NIVEL_3
	return PROFUNDIDAD_MINA_NIVEL_1


## Multiplicador de velocidad de un puesto en ese nivel: la mina no tiene (1.0).
func multiplicador_de_nivel(tipo: String, nivel: int) -> float:
	if tipo == "mina":
		return 1.0
	return MULTIPLICADOR_NIVEL.get(nivel, 1.0)


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
			# la superficie natural de esta columna y naturales (ver es_extraible()).
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
				if TIPOS_MINERALES.has(tipo) and (profundidad_minima == 0 or es_extraible(mundo, celda)):
					conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo


## detectar_recursos() tal como lo ve la mina real: solo subsuelo natural desde
## PROFUNDIDAD_MINIMA_EXTRACCION. Es lo que usan la previsualización, las tasas
## del puesto y la extracción, para que tasa y consumo coincidan.
func detectar_recursos_extraibles(mundo: Object, centro_xz: Vector2i, altura_superficie: int, profundidad: int = PROFUNDIDAD_MINA_NIVEL_1) -> Dictionary:
	return detectar_recursos(mundo, centro_xz, altura_superficie, profundidad, PROFUNDIDAD_MINIMA_EXTRACCION)


## Un bloque es extraíble por una mina si es terreno natural (ni árbol, ni
## estructura, ni parte de un edificio, ni agua) y no lo colocó el jugador.
func es_extraible(mundo: Object, celda: Vector3i) -> bool:
	return mundo.es_terreno_natural(celda) and not mundo.colocado_por_jugador.has(celda)


## Unidades de recurso que rinde un bloque del tipo "tipo" (0.0 si no rinde).
func rendimiento_de(tipo: String) -> float:
	return RENDIMIENTO_POR_BLOQUE.get(tipo, 0.0)



## Segundos que tarda el avatar en minar un bloque del material "tipo".
func tiempo_minado_de(tipo: String) -> float:
	return TIEMPO_MINADO.get(tipo, TIEMPO_MINADO_DEFECTO) * MULTIPLICADOR_HERRAMIENTA


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
func detectar_fauna_frutal(generador: Object, centro_xz: Vector2i, radio: int = RADIO_AREA_CAZA_RECOLECCION) -> Dictionary:
	var suma_fauna := 0.0
	var suma_frutal := 0.0
	var muestras := 0
	for dx in range(-radio, radio + 1, PASO_MUESTREO_CAZA_RECOLECCION):
		for dz in range(-radio, radio + 1, PASO_MUESTREO_CAZA_RECOLECCION):
			if Vector2(dx, dz).length() > radio:
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
func detectar_arbol(generador: Object, centro_xz: Vector2i, radio: int = RADIO_AREA_MADERERO) -> float:
	var suma_arbol := 0.0
	var muestras := 0
	for dx in range(-radio, radio + 1, PASO_MUESTREO_MADERERO):
		for dz in range(-radio, radio + 1, PASO_MUESTREO_MADERERO):
			if Vector2(dx, dz).length() > radio:
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


## Flood-fill acotado sobre el agua REAL del mundo (bloques "agua", no el
## generador): las columnas (X,Z) alcanzables desde "centro_xz" por la
## superficie del agua, en 4 direcciones y sin salir del círculo de "radio".
## La superficie es la del bloque de agua más alto del centro; una columna
## vecina entra si tiene agua a ese nivel (o, si ahí hay aire, un escalón más
## abajo — río que baja). Así, un piso o tierra puesto en la superficie, o un
## drenaje, la corta; y agua que el jugador conecta la une. Devuelve
## Vector2i -> true, usado tanto por el círculo visual como por las tasas.
## Vacío si el centro no tiene agua.
static func _superficie_abierta_en(mundo: Object, xz: Vector2i) -> int:
	var y_max: int = mundo.ALTURA_BUSQUEDA_MAX if ("ALTURA_BUSQUEDA_MAX" in mundo) else 165
	var y_min: int = mundo.ALTURA_BUSQUEDA_MIN if ("ALTURA_BUSQUEDA_MIN" in mundo) else -34
	for y in range(y_max, y_min, -1):
		if mundo.obtener_tipo(Vector3i(xz.x, y, xz.y)) == "agua":
			if mundo.obtener_tipo(Vector3i(xz.x, y + 1, xz.y)) == "":
				return y
	return y_min - 1


## Celdas de agua contiguas conectadas a "centro_xz" a la misma altura de
## superficie, hasta "radio". Cualquier obstáculo a esa altura (isla, piso,
## drenaje, la corta; y agua que el jugador conecta la une. Devuelve
## Vector2i -> true, usado tanto por el círculo visual como por las tasas.
## Vacío si el centro (ni sus celdas adyacentes) no tiene agua.
func celdas_agua_conectadas(mundo: Object, centro_xz: Vector2i, radio: int) -> Dictionary:
	var visitadas: Dictionary = {}
	var y_min: int = mundo.ALTURA_BUSQUEDA_MIN if ("ALTURA_BUSQUEDA_MIN" in mundo) else -34
	var origen: Vector2i = centro_xz
	var y_superficie: int = _superficie_abierta_en(mundo, origen)

	if y_superficie < y_min:
		# Si centro_xz no es agua abierta (ej. muelle construido encima o pilote),
		# buscar agua abierta en las celdas inmediatamente adyacentes.
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cand: Vector2i = centro_xz + dir
			var y_cand: int = _superficie_abierta_en(mundo, cand)
			if y_cand >= y_min:
				origen = cand
				y_superficie = y_cand
				break

	if y_superficie < y_min:
		var y_max: int = mundo.ALTURA_BUSQUEDA_MAX if ("ALTURA_BUSQUEDA_MAX" in mundo) else 165
		for y in range(y_max, y_min, -1):
			if mundo.obtener_tipo(Vector3i(centro_xz.x, y, centro_xz.y)) == "agua":
				y_superficie = y
				break

	if y_superficie < y_min:
		return visitadas

	var pendientes: Array[Vector2i] = [origen]
	visitadas[origen] = true
	var direcciones := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not pendientes.is_empty():
		var actual: Vector2i = pendientes.pop_back()
		for dir in direcciones:
			var vecino: Vector2i = actual + dir
			if visitadas.has(vecino) or Vector2(vecino - centro_xz).length() > radio:
				continue
			var a_nivel: String = mundo.obtener_tipo(Vector3i(vecino.x, y_superficie, vecino.y))
			if a_nivel != "agua" and not (a_nivel == "" and mundo.obtener_tipo(Vector3i(vecino.x, y_superficie - 1, vecino.y)) == "agua"):
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
				if mundo.material_real(mundo.obtener_tipo(celda)) != recurso or not es_extraible(mundo, celda):
					continue
				var distancia := float(dx * dx + dy * dy + dz * dz)
				if distancia < mejor_distancia or (distancia == mejor_distancia and celda.y > mejor.y):
					mejor_distancia = distancia
					mejor = celda
	return mejor


## Bloques de crudo conectados en el pozo a partir de la columna de perforación.
func bloques_crudo_pozo(mundo: Object, columna_pozo: Vector2i, y_sup: int, y_fondo: int) -> Array[Vector3i]:
	var bloques: Array[Vector3i] = []
	var visitadas: Dictionary = {}
	var cola: Array[Vector3i] = []
	# Semillas: bloques de crudo en o adyacentes a la columna entre y_fondo e y_sup
	for y in range(y_fondo, y_sup + 1):
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var celda := Vector3i(columna_pozo.x + dx, y, columna_pozo.y + dz)
				if mundo.obtener_tipo(celda) == "crudo" and not visitadas.has(celda):
					visitadas[celda] = true
					cola.append(celda)
					bloques.append(celda)
	var dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	var idx := 0
	while idx < cola.size():
		var actual: Vector3i = cola[idx]
		idx += 1
		for d in dirs:
			var vecino: Vector3i = actual + d
			if not visitadas.has(vecino) and mundo.obtener_tipo(vecino) == "crudo":
				visitadas[vecino] = true
				cola.append(vecino)
				bloques.append(vecino)
	return bloques


## Siguiente bloque de crudo a extraer: el de mayor Y (y en caso de empate, menor distancia a la columna).
func siguiente_bloque_crudo_pozo(mundo: Object, columna_pozo: Vector2i, y_sup: int, y_fondo: int) -> Vector3i:
	var bloques := bloques_crudo_pozo(mundo, columna_pozo, y_sup, y_fondo)
	if bloques.is_empty():
		return SIN_BLOQUE
	var mejor: Vector3i = bloques[0]
	for b in bloques:
		if b.y > mejor.y:
			mejor = b
		elif b.y == mejor.y:
			var d_b := (Vector2i(b.x, b.z) - columna_pozo).length_squared()
			var d_m := (Vector2i(mejor.x, mejor.z) - columna_pozo).length_squared()
			if d_b < d_m:
				mejor = b
	return mejor


## Cantidad de bloques de crudo restantes en el pozo.
func contar_crudo_pozo(mundo: Object, columna_pozo: Vector2i, y_sup: int, y_fondo: int) -> int:
	return bloques_crudo_pozo(mundo, columna_pozo, y_sup, y_fondo).size()


## Árboles vivos registrados a "radio" celdas o menos de "centro".
func arboles_vivos_en(mundo: Object, centro: Vector2i, radio: int) -> int:
	return mundo.arboles.ids_en_radio(centro, radio).size()


## Lo que un puesto necesita recordar del mundo para recalcular sus tasas y
## extraer: "centro" y "altura" (superficie en el centro al colocarlo);
## "centro_agua" (pesca); "radio_arboles" y "arboles_ref" (árboles vivos en su
## área al colocarlo — caza/recolección y maderero).
func entorno_de_puesto(tipo: String, mundo: Object, centro: Vector2i, altura: int, centro_agua: Vector2i = SIN_CENTRO, datos_perforacion: Dictionary = {}) -> Dictionary:
	var entorno := {"centro": centro, "altura": altura}
	if centro_agua != SIN_CENTRO:
		entorno["centro_agua"] = centro_agua
	if not datos_perforacion.is_empty():
		entorno["datos_perforacion"] = datos_perforacion.duplicate()
	if tipo == "caza_recoleccion" or tipo == "maderero":
		var radio: int = RADIO_AREA_MADERERO if tipo == "maderero" else RADIO_AREA_CAZA_RECOLECCION
		entorno["radio_arboles"] = radio
		entorno["arboles_ref"] = arboles_vivos_en(mundo, centro, radio)
	return entorno


## El entorno de un puesto al nivel "nivel": amplía el radio con que cuenta sus árboles (caza/recolección y
## maderero) y suma a su referencia los árboles vivos del anillo nuevo, para que talar el anillo base siga
## bajando el factor. Devuelve una copia; llamarla otra vez con el mismo nivel no cambia nada.
func entorno_de_nivel(tipo: String, mundo: Object, entorno: Dictionary, nivel: int) -> Dictionary:
	var nuevo: Dictionary = entorno.duplicate()
	if not nuevo.has("radio_arboles"):
		return nuevo
	var base: int = RADIO_AREA_MADERERO if tipo == "maderero" else RADIO_AREA_CAZA_RECOLECCION
	var radio: int = radio_de_nivel(base, nivel)
	if radio <= nuevo["radio_arboles"]:
		return nuevo
	nuevo["arboles_ref"] += arboles_vivos_en(mundo, nuevo["centro"], radio) - arboles_vivos_en(mundo, nuevo["centro"], nuevo["radio_arboles"])
	nuevo["radio_arboles"] = radio
	return nuevo


## Tasas por trabajador de la franja de cada nivel de una mina (la franja del nivel N es lo que añade
## su profundidad sobre la del nivel anterior; no suma los niveles previos): [nivel 1, nivel 2, nivel 3].
func tasas_mina_por_nivel(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Array:
	var niveles: Array = []
	var anterior: Dictionary = {}
	for nivel in range(1, 4):
		var conteo: Dictionary = detectar_recursos_extraibles(mundo, centro_xz, altura_superficie, profundidad_de_nivel(nivel))
		var franja: Dictionary = {}
		for tipo in conteo:
			var nuevos: int = conteo[tipo] - anterior.get(tipo, 0)
			if nuevos > 0:
				franja[tipo] = nuevos
		niveles.append(tasas_recoleccion(franja))
		anterior = conteo
	return niveles


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
func tasas_de_entorno(tipo: String, mundo: Object, entorno: Dictionary, nivel: int = 1) -> Dictionary:
	if tipo == "estacion_bombeo":
		return {"agua": Ajustes.RECOLECCION_TASA_BASE_ESTACION_BOMBEO_AGUA}
	if tipo == "centro_extraccion":
		var dp: Dictionary = entorno.get("datos_perforacion", {})
		var tipo_p: String = dp.get("tipo_pozo", entorno.get("tipo_pozo", "agua"))
		if tipo_p == "crudo":
			if dp.has("perforacion"):
				var restantes: int = contar_crudo_pozo(mundo, dp["perforacion"], dp["y_superficie"], dp["y_fondo"])
				if restantes <= 0:
					return {"crudo": 0.0}
			return {"crudo": Ajustes.RECOLECCION_TASA_BASE_CENTRO_EXTRACCION_CRUDO}
		return {"agua": Ajustes.RECOLECCION_TASA_BASE_CENTRO_EXTRACCION_AGUA}
	var centro: Vector2i = entorno["centro"]
	if tipo == "mina":
		return tasas_recoleccion(detectar_recursos_extraibles(mundo, centro, entorno["altura"], profundidad_de_nivel(nivel)))
	if tipo == "pesca_frutos_mar":
		if not entorno.has("centro_agua"):
			return {}
		var celdas_agua: Dictionary = celdas_agua_conectadas(mundo, entorno["centro_agua"], radio_de_nivel(RADIO_AREA_PESCA_FRUTOS_MAR, nivel))
		return tasas_pesca_frutos_mar(detectar_pesca_frutos_mar(mundo.generador, celdas_agua))
	var tasas: Dictionary
	# Un maderero sin árboles al colocarse no tiene nada que talar (factor_arboles() da 1.0 ahí).
	if tipo == "maderero" and entorno.get("arboles_ref", 0) <= 0:
		return {"madera": 0.0}
	if tipo == "caza_recoleccion":
		tasas = tasas_caza_recoleccion(detectar_fauna_frutal(mundo.generador, centro, radio_de_nivel(RADIO_AREA_CAZA_RECOLECCION, nivel)))
	else:
		tasas = tasa_maderero(detectar_arbol(mundo.generador, centro, radio_de_nivel(RADIO_AREA_MADERERO, nivel)))
	var factor := factor_arboles(mundo, entorno)
	for clave in tasas:
		tasas[clave] *= factor
	# Un maderero por debajo del umbral está agotado: no conserva empleados improductivos.
	if tipo == "maderero" and tasas["madera"] < UMBRAL_AGOTADO_MADERERO:
		tasas["madera"] = 0.0
	return tasas
