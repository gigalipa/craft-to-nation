extends Node

## Autoload "Recoleccion": estado puro de los puestos de recolección
## colocados (solo minas por ahora, ver spec:
## docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md).
## Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd: evitar el bug
## de caché de clases globales de Godot).

const RADIO_AREA_MINA := 6
const PROFUNDIDAD_MINA_NIVEL_1 := 8
const TASA_BASE_POR_CIUDADANO := 2.0

## Ejemplo "mina manual, Tipo 1" del GDD (Sección 3) — puramente
## informativo por ahora: colocar una mina no cobra nada todavía (mismo
## alcance reducido que la nivelación de terreno, el juego no tiene
## inventario de recursos real).
const COSTO_CONSTRUCCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO := 3
const CAPACIDAD_ALMACENAMIENTO := 100

var puestos: Dictionary = {}  # Vector2i (celda de superficie) -> {"nivel": int}


func colocar_mina(celda: Vector2i) -> void:
	puestos[celda] = {"nivel": 1}


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
				if tipo != "":
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
