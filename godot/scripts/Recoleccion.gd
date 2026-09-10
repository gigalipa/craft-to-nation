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

## Tipos de bloque que detectar_recursos() ignora explícitamente: son
## recursos de otro dominio (madera/follaje de árboles — ver
## GeneradorArbol.gd/VoxelWorld._generar_arboles() — pertenecen a futuros
## puestos madereros, no a minas). Bug reportado por el usuario jugando en
## vivo: la ficha de una mina mostraba "tronco"/"follaje" en su conteo de
## recursos detectados.
const TIPOS_NO_MINERALES := ["madera", "follaje"]

## Ejemplo "mina manual, Tipo 1" del GDD (Sección 3) — puramente
## informativo por ahora: colocar una mina no cobra nada todavía (mismo
## alcance reducido que la nivelación de terreno, el juego no tiene
## inventario de recursos real).
const COSTO_CONSTRUCCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO := 3
const CAPACIDAD_ALMACENAMIENTO := 100

## Documentada para el puesto maderero (GDD Sección 3) — sin puesto jugable
## todavía, solo fija la convención de tamaño junto a las demás huellas.
const ANCHO_HUELLA_MADERERO := 3
const ALTO_HUELLA_MADERERO := 4

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

## Vector2i (esquina de la huella, celda de menor X/Z) -> {"tipo": String,
## "ancho": int, "alto": int, "nivel": int}. Antes solo guardaba minas
## indexadas por su único bloque marcador; ahora guarda cualquier puesto
## periférico por la esquina de su huella real, para poder validar choques
## entre puestos de cualquier tipo (ver celda_dentro_de_algun_puesto()).
var puestos: Dictionary = {}


func colocar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int) -> void:
	puestos[esquina] = {"tipo": tipo, "ancho": ancho, "alto": alto, "nivel": 1}


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
				var tipo: String = mundo.obtener_tipo(celda)
				if tipo != "" and not TIPOS_NO_MINERALES.has(tipo):
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
