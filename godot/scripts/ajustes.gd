extends RefCounted
## Fuente única centralizada de valores numéricos de configuración, balance de
## juego, tiempos, dimensiones, parámetros de interfaz y colores (en formato
## hexadecimal) de Craft to Nation.
##
## Todos los valores se declaran como `static var` para permitir su modificación
## en tiempo de ejecución desde el futuro menú de Ajustes (menú principal) o
## desde la configuración personalizada de "Nueva partida".

# ==============================================================================
# IDIOMA DE LA INTERFAZ
# ==============================================================================
static var idioma: String = "es"


# ==============================================================================
# COLORES DE LA INTERFAZ (HUD) Y TEMAS (HEXADECIMAL)
# ==============================================================================
static var COLOR_HUD_VERDE: Color = Color("#0d2119eb")
static var COLOR_HUD_VERDE_CLARO: Color = Color("#214d36f2")
static var COLOR_HUD_DORADO: Color = Color("#c79e40")
static var COLOR_HUD_TEXTO: Color = Color("#f2ebd1")
static var COLOR_HUD_VALIDO: Color = Color("#73e673")
static var COLOR_HUD_INVALIDO: Color = Color("#ff5959")
static var COLOR_HUD_SOMBRA: Color = Color("#00000073")
static var COLOR_HUD_TEXTO_DESHABILITADO: Color = Color("#f2ebd173")

static var COLOR_HUD_TEXTO_DORADO_SUAVE: Color = Color(1.0, 0.85, 0.4)
static var COLOR_HUD_TEXTO_ATENUADO: Color = Color("#f2ebd199")
static var COLOR_HUD_TEXTO_DESCRIPCION: Color = Color("#f2ebd1d9")
static var COLOR_HUD_TEXTO_ADVERTENCIA: Color = Color("#ffcc33")
static var COLOR_HUD_TEXTO_PELIGRO: Color = Color("#ff734d")
static var COLOR_HUD_TEXTO_INFO_AZUL: Color = Color("#99d9ff")
static var COLOR_HUD_TEXTO_INFO_CELESTE: Color = Color("#80d9ff")
static var COLOR_HUD_TEXTO_GRIS_SUAVE: Color = Color("#d9d9d9bf")

static var COLOR_HUD_RETICULA: Color = Color("#ffffffcc")
static var COLOR_HUD_PROGRESO_FONDO: Color = Color("#0000008c")
static var COLOR_HUD_OXIGENO_NORMAL: Color = Color("#33bfff")
static var COLOR_HUD_OXIGENO_BAJO: Color = Color("#ff3333")

static var COLOR_HUD_HOTBAR_SELECCION_FONDO: Color = Color("#2e6647fa")
static var COLOR_HUD_HOTBAR_SELECCION_BORDE: Color = Color("#ffd966")
static var COLOR_HUD_HOTBAR_SELECCION_SOMBRA: Color = Color("#ffd96659")
static var COLOR_HUD_SUBPANEL_FONDO: Color = Color("#08140fd9")
static var COLOR_HUD_SUBPANEL_BORDE: Color = Color("#c79e4059")

static var COLOR_HUD_BARRA_FONDO_OSCURO: Color = Color("#1a1a1acc")
static var COLOR_HUD_BARRA_LAMPARA_RELLENO: Color = Color("#ffcc33e6")
static var COLOR_HUD_MODAL_INACTIVO: Color = Color("#ffffff8c")
static var COLOR_HUD_MODAL_ACTIVO: Color = Color("#ffffffff")

static var COLOR_MORAL_EUFORICA: Color = Color("#33e666")
static var COLOR_MORAL_ESTABLE: Color = Color("#ffd933")
static var COLOR_MORAL_BAJA: Color = Color("#ff8c1a")
static var COLOR_MORAL_CRITICA: Color = Color("#ff3333")
static var COLOR_HUD_TEXTO_VERDE_CLARO: Color = Color("#d9f299")
static var COLOR_HUD_TEXTO_VERDE: Color = Color("#99ff99")


# ==============================================================================
# COLORES DE MUNDO, BLOQUES, OVERLAYS Y RENDERIZADORES (HEXADECIMAL)
# ==============================================================================
static var COLOR_DESTACADO: Dictionary = {
	"puerta_inferior": Color("#ff33cc99"),
	"puerta_superior": Color("#ff33cc99"),
	"vidrio": Color("#80ff3399"),
	"puerto_agua_in": Color("#3399e6cc"),
	"puerto_agua_out": Color("#1a4db3cc"),
	"puerto_crudo_in": Color("#664d1ae6"),
	"puerto_crudo_out": Color("#402e0de6"),
	"puerto_combustible_in": Color("#e6801acc"),
	"puerto_combustible_out": Color("#cc331acc"),
}

static var COLORES_PUERTO: Dictionary = {
	"puerto_agua_in": Color("#3399e6"),
	"puerto_agua_out": Color("#1a4db3"),
	"puerto_crudo_in": Color("#664d1a"),
	"puerto_crudo_out": Color("#402e0d"),
	"puerto_combustible_in": Color("#e6801a"),
	"puerto_combustible_out": Color("#cc331a"),
}

static var COLOR_DUCTO_ACUEDUCTO: Color = Color("#b3a68c")
static var COLOR_DUCTO_TUBERIA: Color = Color("#59616b")

static var COLOR_LAMPARA_BLOQUE_ALBEDO: Color = Color("#fff2bf")
static var COLOR_LAMPARA_BLOQUE_EMISION: Color = Color("#ffd966")
static var COLOR_LUZ_LAMPARA_ELECTRICA: Color = Color("#fffaf2")
static var COLOR_LUZ_LAMPARA_COMBUSTIBLE: Color = Color("#ffe6b3")
static var COLOR_LUZ_LAMPARA_CARBON: Color = Color("#ffcc80")
static var COLOR_LUZ_LAMPARA_MADERA: Color = Color("#ffa659")

static var COLOR_TRANSLUCIDO_FANTASMA: Color = Color("#99d9ff59")
static var COLOR_TRANSLUCIDO_VIDRIO: Color = Color("#bfebf273")
static var COLOR_TRANSLUCIDO_AGUA: Color = Color("#2e73d1b8")
static var COLOR_TRANSLUCIDO_CRUDO: Color = Color("#14120ff5")
static var COLOR_TRANSLUCIDO_COMBUSTIBLE: Color = Color("#d9941fd9")

static var COLOR_CARA_APUNTADA: Color = Color("#ffe66666")
static var COLOR_FANTASMA_DESTACADO_EMISION: Color = Color("#ffffff")
static var COLOR_PUERTA_LAMINA: Color = Color("#73421f")
static var COLOR_HUMO_REFINERIA: Color = Color("#2e2e33bf")

static var COLORES_COLONOS: Dictionary = {
	"ciudadano": Color("#b8ad99"),
	"desempleado": Color("af946dff"),
	"obrero": Color("#cc8533"),
	"tecnico": Color("#3878c7"),
	"especialista": Color("#40a661"),
	"investigador": Color("#8c52bf"),
	"militar": Color("#bf3833"),
}

static var COLORES_RECURSO_CARGA: Dictionary = {
	"madera": Color("#73471f"),
	"tablas": Color("#bf8c4d"),
	"comida": Color("#cc4033"),
	"tierra": Color("#593d24"),
	"piedra": Color("#85878c"),
	"hierro": Color("#b86b38"),
	"cobre": Color("#d17838"),
	"carbon": Color("#242429"),
	"tierras_raras": Color("#40b89e"),
	"acero": Color("#8ca3b8"),
	"mineral_refinado": Color("#a659d9"),
	"crudo": Color("#141210"),
	"combustible": Color("#e6a626"),
	"agua": Color("#2680d9"),
}

static var COLOR_PIEL_COLONO: Color = Color("#e0b38f")
static var COLOR_PELO_COLONO: Color = Color("#382414")
static var COLOR_PANTALON_COLONO: Color = Color("#2e333d")
static var COLOR_ZAPATO_COLONO: Color = Color("#241a12")
static var COLOR_HERRAMIENTA_MANGO: Color = Color("#6b421f")
static var COLOR_HERRAMIENTA_METAL: Color = Color("#99a1ad")
static var COLOR_CASCO_AMARILLO: Color = Color("#f2c726")
static var COLOR_CASCO_BLANCO: Color = Color("#ebeef2")
static var COLOR_LIBRO_TAPA: Color = Color("#611f24")
static var COLOR_LIBRO_HOJAS: Color = Color("#f2ebd9")
static var COLOR_CARGA_DEFECTO: Color = Color("#ccb373")

static var COLOR_MARCA_DEMOLICION: Color = Color("#ff4026b8")
static var COLOR_MARCA_PROGRAMADA: Color = Color("#ffbf1ab8")

static var COLOR_NIVELACION_RESERVADA: Color = Color("#33e6ff59")
static var COLOR_NIVELACION_BLOQUEADA: Color = Color("#ff333380")
static var COLOR_NIVELACION_REGION: Dictionary = {
	"cavar": Color("#ff801a59"),
	"rellenar": Color("#3380ff59"),
	"nivel": Color("#4dff6640"),
}

static var COLOR_DEMOLICION_VIA: Color = Color("#ff800073")
static var COLOR_OUTLINE_DEMOLICION_VIA: Color = Color("#ff8000f2")
static var COLOR_VIA_OBRA_CONTORNO: Color = Color("#ffd933e6")
static var COLOR_VIA_PREVIEW_VALIDO: Color = Color("#ffd90066")
static var COLOR_VIA_PREVIEW_INVALIDO: Color = Color("#ff333366")

static var COLOR_POR_ZONA: Dictionary = {
	"residencial_investigacion": Color("#3366ff26"),
	"fabricacion_militar": Color("#ff801a26"),
}
static var COLOR_ZONA_INFLUENCIA: Color = Color("#ffffff05")
static var COLOR_ZONA_BORRAR: Color = Color("#8080804d")

static var COLOR_PUESTO_VALIDO: Color = Color("#ffd90066")
static var COLOR_PUESTO_INVALIDO: Color = Color("#ff333366")
static var COLOR_AREA_ACCION: Color = Color("#4db3ff26")


# ==============================================================================
# PARÁMETROS GEOMÉTRICOS Y MÉTRICAS DEL HUD
# ==============================================================================
static var HUD_MARGEN_X: float = 5.0
static var HUD_MARGEN_Y: float = 2.0
static var HUD_MARGEN_CONTENIDO: int = 8
static var HUD_MARGEN_BOTON_LATERAL: int = 12
static var HUD_MARGEN_BOTON_VERTICAL: int = 4
static var HUD_RADIO_ESQUINA_PANEL: int = 6
static var HUD_RADIO_ESQUINA_BOTON: int = 4
static var HUD_ANCHO_BORDE_PANEL: int = 2
static var HUD_ANCHO_BORDE_BOTON: int = 1
static var HUD_TAMANO_SOMBRA: int = 6
static var HUD_DESPLAZAMIENTO_SOMBRA: Vector2 = Vector2(0, 2)

static var HUD_ANCHO_BARRA_PROGRESO: float = 120.0
static var HUD_ALTO_BARRA_PROGRESO: float = 8.0
static var HUD_SEPARACION_BAJO_MIRA: float = 18.0
static var HUD_ANCHO_BARRA_OXIGENO: float = 160.0
static var HUD_ALTO_BARRA_OXIGENO: float = 10.0
static var HUD_SEPARACION_OXIGENO_MIRA: float = 34.0
static var HUD_UMBRAL_OXIGENO_BAJO: float = 0.3

static var HOTBAR_RANURAS: int = 10
static var HOTBAR_POR_PAGINA: int = 10
static var HOTBAR_ANCHO_RANURA: int = 72
static var HOTBAR_ALTO_RANURA: int = 58
static var HOTBAR_TAMANO_ICONO: int = 28

static var BARRA_MODOS_POR_PAGINA: int = 5
static var BARRA_MODOS_ANCHO_BOTON: int = 92
static var BARRA_MODOS_ALTO_BOTON: int = 74
static var BARRA_MODOS_TAMANO_ICONO: int = 38
static var BARRA_MODOS_DESPLAZAMIENTO_Y: float = -76.0
static var BARRA_MODOS_SEPARACION_SUBPANEL: float = 6.0

static var NOTIFICACIONES_DURACION: float = 5.0
static var NOTIFICACIONES_DURACION_VISIBLE: float = 2.5
static var NOTIFICACIONES_DURACION_FADE: float = 0.25
static var NOTIFICACIONES_ANCHO: float = 320.0
static var NOTIFICACIONES_MAX_VISIBLES: int = 5

static var VENTANA_POBLACION_POSICION_INICIAL: Vector2 = Vector2(12, 46)
static var VENTANA_OCUPACIONES_POSICION_INICIAL: Vector2 = Vector2(280, 46)
static var VENTANA_ALMACEN_POSICION_INICIAL: Vector2 = Vector2(220, 46)
static var VENTANA_ENERGIA_POSICION_INICIAL: Vector2 = Vector2(360, 46)
static var VENTANA_MORAL_POSICION_INICIAL: Vector2 = Vector2(420, 46)
static var VENTANA_BAUL_PASO_UNIDAD: float = 10.0

static var MINIATURA_TAMANO: int = 64
static var MINIATURA_ORIGEN_BASE: Vector3 = Vector3(0.0, -500.0, 0.0)
static var MINIATURA_SEPARACION_SLOTS: float = 80.0


# ==============================================================================
# MUNDO, FLUJO DE FLUIDOS Y GENERACIÓN PROCEDURAL
# ==============================================================================
static var TAMANO_CELDA: float = 1.0
static var ANCHO_MUNDO: int = 200
static var LARGO_MUNDO: int = 200
static var PROFUNDIDAD_SUBSUELO: int = 24
static var SEMILLA_MUNDO: int = 12345
static var UMBRAL_ARBOL: float = 0.5
static var GAP_MINIMO_TRONCOS: int = 2
static var SOLAPE_MAXIMO_COPAS: int = 1
static var ALTURA_BUSQUEDA_MAX: int = 165
static var ALTURA_BUSQUEDA_MIN: int = -34

static var LIMITE_ESCURRIMIENTO: int = 150
static var FRENTES_ESCURRIMIENTO_POR_FRAME: int = 2
static var NIVEL_CAIDA: int = 0
static var NIVEL_MAXIMO_FLUJO: int = 7
static var ALCANCE_FLUJO_AGUA: int = 7
static var ALCANCE_FLUJO_COMBUSTIBLE: int = 5
static var ALCANCE_FLUJO_CRUDO: int = 3
static var FRENTES_SECADO_POR_FRAME: int = 3

static var MUNDO_ALTURA_MINIMA: int = 0
static var MUNDO_ALTURA_MAXIMA: int = 130
static var MUNDO_DESPEJE_ALTURA_CAMA: int = 2
static var MUNDO_GROSOR_TIERRA: int = 4
static var MUNDO_UMBRAL_HIERRO: float = 0.2
static var MUNDO_PROFUNDIDAD_CARBON: int = 4
static var MUNDO_UMBRAL_CARBON: float = -0.1
static var MUNDO_PROFUNDIDAD_COBRE: int = 6
static var MUNDO_UMBRAL_COBRE: float = 0.12
static var MUNDO_PROFUNDIDAD_HIERRO: int = 8
static var MUNDO_PROFUNDIDAD_TIERRAS_RARAS: int = 16
static var MUNDO_UMBRAL_TIERRAS_RARAS: float = 0.3
static var MUNDO_PROFUNDIDAD_POZOS: int = 4
static var MUNDO_UMBRAL_POZO: float = 0.35
static var MUNDO_MARGEN_POZO_BUFFER: float = 0.20
static var MUNDO_UMBRAL_ZONA_BOSQUE: float = 0.0
static var MUNDO_EXPONENTE_RELIEVE: float = 0.5
static var MUNDO_AMPLITUD_DETALLE_RELIEVE: float = 3.0
static var MUNDO_AMPLITUD_MEDIA_RELIEVE: float = 10.0
static var MUNDO_ALTURA_BASE_MAXIMA: float = 30.0
static var MUNDO_NUM_MONTANAS: int = 2
static var MUNDO_RADIO_MONTANA_MIN: float = 45.0
static var MUNDO_RADIO_MONTANA_MAX: float = 70.0
static var MUNDO_MARGEN_BORDE_MONTANA: int = 35
static var MUNDO_PERCENTIL_NIVEL_MAR: float = 0.15
static var MUNDO_BANDA_BIOMA: int = 34
static var MUNDO_NUM_RIOS: int = 6
static var MUNDO_MARGEN_NACIENTE_RIO: Array[int] = [35, 17]
static var MUNDO_MIN_DISTANCIA_NACIENTES: int = 10
static var MUNDO_ANCHO_MINIMO_RIO: int = 2
static var MUNDO_ANCHO_MAXIMO_RIO: int = 8
static var MUNDO_PROFUNDIDAD_MAXIMA_RIO: int = 3
static var MUNDO_UMBRAL_CASCADA: int = 3
static var MUNDO_RADIO_VISTA_RIO: int = 5

static var ARBOL_ALTURA_TRONCO_MIN: int = 3
static var ARBOL_ALTURA_TRONCO_MAX: int = 8
static var ARBOL_LADO_TRONCO_MIN: int = 1
static var ARBOL_LADO_TRONCO_MAX: int = 2


# ==============================================================================
# JUGADOR, LÁMPARAS Y CONTROLES EN PRIMERA PERSONA (Player, Main)
# ==============================================================================
static var MAIN_DURACION_TRANSICION_CAMARA: float = 0.6

static var PLAYER_VELOCIDAD: float = 5.0
static var PLAYER_GRAVEDAD: float = 19.6
static var PLAYER_VELOCIDAD_SALTO: float = 6.86
static var PLAYER_SENSIBILIDAD_MOUSE: float = 0.003
static var PLAYER_ALCANCE_RAYCAST: float = 5.0
static var PLAYER_DANO_TALA: int = 1
static var PLAYER_VELOCIDAD_NATACION: float = 3.0
static var PLAYER_VELOCIDAD_HUNDIMIENTO: float = 1.0
static var PLAYER_FACTOR_VISCOSIDAD_CRUDO: float = 0.20
static var PLAYER_EMPUJE_RIO_MINIMO: float = 0.4
static var PLAYER_EMPUJE_RIO_POR_CAIDA: float = 0.7
static var PLAYER_EMPUJE_CASCADA_BASE_MINIMO: float = 0.5
static var PLAYER_EMPUJE_CASCADA_BASE_MAXIMO: float = 9.0
static var PLAYER_CAIDA_EMPUJE_SATURA: int = 12
static var PLAYER_MARGEN_PIE_CASCADA: int = 2
static var PLAYER_AMPLITUD_FLOTACION: float = 0.08
static var PLAYER_FRECUENCIA_FLOTACION: float = 1.0
static var PLAYER_OXIGENO_MAXIMO: float = 10.0
static var PLAYER_TASA_CONSUMO_OXIGENO: float = 1.0
static var PLAYER_TASA_RECUPERACION_OXIGENO: float = 2.0
static var PLAYER_INTERVALO_AVISO_DECONSTRUCCION_MS: int = 2000
static var PLAYER_TICKS_REMOCION_FINAL: int = 5
static var PLAYER_BATERIA_LAMPARA_MAX: float = 72.0
static var PLAYER_RECARGA_BATERIA_POR_HORA: float = 7.2
static var PLAYER_STOCK_INICIAL_DEBUG: float = 1000.0
static var PLAYER_LIMITE_INICIAL_DEBUG: float = 2000.0
static var PLAYER_COMIDA_INICIAL_DEBUG: float = 5000.0


# ==============================================================================
# CÁMARA CENITAL Y CONSTRUCTOR (CamaraCenital)
# ==============================================================================
static var CAMARA_CENITAL_DISTANCIA_INICIAL: float = 25.0
static var CAMARA_CENITAL_DISTANCIA_MIN: float = 8.0
static var CAMARA_CENITAL_DISTANCIA_MAX: float = 60.0
static var CAMARA_CENITAL_VELOCIDAD_ZOOM: float = 2.5
static var CAMARA_CENITAL_MARGEN_COLISION_ACTIVACION: float = 1.0
static var CAMARA_CENITAL_PASO_INCLINACION_ESCALADA: float = deg_to_rad(2.0)
static var CAMARA_CENITAL_MARGEN_INCLINACION_ACTIVACION: float = deg_to_rad(4.0)
static var CAMARA_CENITAL_ANGULO_INCLINACION_INICIAL: float = deg_to_rad(55.0)
static var CAMARA_CENITAL_ANGULO_INCLINACION_MIN: float = deg_to_rad(10.0)
static var CAMARA_CENITAL_ANGULO_INCLINACION_MAX: float = deg_to_rad(89.9)
static var CAMARA_CENITAL_VELOCIDAD_INCLINACION: float = deg_to_rad(60.0)
static var CAMARA_CENITAL_VELOCIDAD_PANEO: float = 20.0
static var CAMARA_CENITAL_VELOCIDAD_ORBITA: float = deg_to_rad(90.0)
static var CAMARA_CENITAL_ALTURA_MAXIMA: float = 300.0
static var CAMARA_CENITAL_VELOCIDAD_ALTURA_MIN: float = 15.0
static var CAMARA_CENITAL_VELOCIDAD_ALTURA_MAX: float = 300.0
static var CAMARA_CENITAL_RADIO_AREA_ACCION_MAX: int = 25
static var CAMARA_CENITAL_ALCANCE_RAYCAST: float = 200.0
static var CAMARA_CENITAL_MASCARA_MUNDO: int = 1
static var CAMARA_CENITAL_ORIGEN_RAYCAST_VERTICAL_Y: float = 100.0
static var CAMARA_CENITAL_ALCANCE_RAYCAST_VERTICAL: float = 150.0
static var CAMARA_CENITAL_DESF: float = 0.5
static var CAMARA_CENITAL_ALTURA_SOBRE_SUPERFICIE: float = 1.01
static var CAMARA_CENITAL_ALTURA_SOBRE_SUPERFICIE_AREA_ACCION: float = 1.001
static var CAMARA_CENITAL_TIEMPO_DOBLE_CLIC_MS: int = 400
static var CAMARA_CENITAL_MAX_NODOS_PREVIEW_VIA: int = 600
static var CAMARA_CENITAL_ALTURA_PUERTA: int = 2
static var CAMARA_CENITAL_DURACION_CENTRADO: float = 0.4
static var CAMARA_CENITAL_FOV: float = 60.0


# ==============================================================================
# SIMULACIÓN DE CIUDAD, POBLACIÓN, MORAL E INVESTIGACIÓN (Ciudad)
# ==============================================================================
static var CIUDAD_SEGUNDOS_POR_TICK: float = 2.0
static var CIUDAD_TIPOS_POBLACION: Dictionary = {
	"ciudadano": {"comida": 2.0, "combustible": 0.0, "energia": 0.0, "x_cama": 4},
	"desempleado": {"comida": 3.0, "combustible": 0.0, "energia": 0.0, "x_cama": 4},
	"obrero": {"comida": 4.0, "combustible": 0.0, "energia": 0.0, "x_cama": 4},
	"tecnico": {"comida": 3.0, "combustible": 0.0, "energia": 0.5, "x_cama": 3},
	"especialista": {"comida": 2.0, "combustible": 1.0, "energia": 1.0, "x_cama": 2},
	"investigador": {"comida": 2.0, "combustible": 0.0, "energia": 2.0, "x_cama": 1},
	"militar": {"comida": 3.0, "combustible": 1.0, "energia": 0.0, "x_cama": 3},
}

## Gasto adicional para militares desplegados en el exterior
static var MILITAR_CONSUMO_COMIDA_DESPLEGADO: float = 5.0
static var MILITAR_CONSUMO_COMBUSTIBLE_DESPLEGADO: float = 2.0

## Orden de consumo de sub-categorías de comida (fresco a no perecedero)
static var CIUDAD_ORDEN_CONSUMO_COMIDA: Array = [
	"pesca",
	"recoleccion_caza",
	"sembradios",
	"granjas_animales",
	"hidroponia",
	"sintetico",
]

## Monocultivo y variedad dietética
static var CIUDAD_GRACIA_MONOCULTIVO_HORAS: int = 360
static var CIUDAD_PENALIZACION_MONOCULTIVO_MORAL: float = -0.2
static var CIUDAD_BONO_DIETA_2_3_FUENTES: float = 0.3
static var CIUDAD_BONO_DIETA_4_5_FUENTES: float = 1.0
static var CIUDAD_BONO_DIETA_6_FUENTES: float = 2.0

## Suelo mínimo de productividad para comida
static var PRODUCTIVIDAD_SUELO_ALIMENTOS: float = 0.75

## Decreto de Racionamiento Estricto
static var RACIONAMIENTO_REDUCCION_CONSUMO: float = 0.35
static var RACIONAMIENTO_TECHO_MORAL: float = 35.0
static var CIUDAD_NIVELES_VIVIENDA: Dictionary = {
	1: {"camas_por_piso": 2, "pisos": 2},
	2: {"camas_por_piso": 4, "pisos": 4},
	3: {"camas_por_piso": 4, "pisos": 8},
}
static var CIUDAD_ORDEN_DESAHUCIO: Array = ["desempleado", "ciudadano", "obrero", "tecnico", "especialista", "investigador", "militar"]
static var CIUDAD_ORDEN_BAJAS_HAMBRUNA: Array = ["militar", "obrero", "tecnico", "especialista", "investigador", "desempleado", "ciudadano"]
static var CIUDAD_HORAS_POR_MES: float = 720.0
static var CIUDAD_COSTOS_INVESTIGACION: Dictionary = {
	2: {"nombre": "Metalurgia Aplicada", "hierro": 300, "madera": 200, "horas_investigador": 20},
	3: {"nombre": "Automatización Industrial", "hierro": 800, "madera": 100, "horas_investigador": 50},
}
static var CIUDAD_TIPO_INSTALACION: Dictionary = {
	"siderurgica": 2, "refineria_tierras_raras": 2, "aserradero": 2, "carbonera": 2,
	"refineria_petrolera": 3, "productor_combustible": 3, "central_termoelectrica": 3,
}
static var CIUDAD_MINIMO_INSTALACIONES_NIVEL: int = 3
static var CIUDAD_INDICE_SOFISTICACION_NIVEL_2: float = 1.7
static var CIUDAD_INDICE_SOFISTICACION_NIVEL_3: float = 2.5
static var CIUDAD_CATEGORIAS_COMIDA: Array = [
	"sembradios", "granjas_animales", "recoleccion_caza",
	"hidroponia", "pesca", "sintetico",
]
static var CIUDAD_VENTANA_TASA_PROMEDIO: int = 10
static var CIUDAD_BONO_MORAL_MAXIMO: float = 15.0
static var CIUDAD_VELOCIDAD_SUAVIZADO_MORAL: float = 0.15
static var CIUDAD_MORAL_INICIAL: float = 75.0
static var CIUDAD_MORAL_NEUTRAL: float = 50.0
static var CIUDAD_INERCIA_MORAL: float = 0.02
static var CIUDAD_TOLERANCIA_SIN_TECHO_HORAS: int = 72
static var CIUDAD_TOLERANCIA_DESEMPLEO_HORAS: int = 240
static var CIUDAD_VENTANA_PELIGRO_HORAS: int = 168
static var CIUDAD_HORAS_TRASLADO_NUCLEO: int = 5
static var CIUDAD_ORDEN_EXODO_MORAL: Array = ["investigador", "especialista", "tecnico", "militar", "obrero", "desempleado", "ciudadano"]

## Escalas de migración mensual neta (ciudadanos/mes) según el nivel de moral [0, 100].
## Cada tramo define el umbral superior de moral y la tasa neta mensual correspondiente.
static var CIUDAD_TRAMOS_MIGRACION: Array = [
	{"umbral_moral": 5.0, "tasa_mensual": -5.0},
	{"umbral_moral": 10.0, "tasa_mensual": -3.0},
	{"umbral_moral": 15.0, "tasa_mensual": -2.0},
	{"umbral_moral": 20.0, "tasa_mensual": -1.0},
	{"umbral_moral": 25.0, "tasa_mensual": 1.0},
	{"umbral_moral": 35.0, "tasa_mensual": 2.0},
	{"umbral_moral": 50.0, "tasa_mensual": 3.0},
	{"umbral_moral": 75.0, "tasa_mensual": 3.0},
	{"umbral_moral": 100.0, "tasa_mensual": 5.0},
]

## Umbrales de régimen migratorio según moral
static var CIUDAD_UMBRAL_EXODO_MORAL: float = 20.0
static var CIUDAD_UMBRAL_INMIGRACION_MASIVA: float = 50.0
static var CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION: float = 2.5

## Factores de cálculo del multiplicador de productividad laboral
static var CIUDAD_PRODUCTIVIDAD_BASE: float = 0.5
static var CIUDAD_PRODUCTIVIDAD_EXPONENCIAL_BASE: float = 2.0
static var CIUDAD_PRODUCTIVIDAD_DIVISOR_MORAL: float = 50.0

static var CIUDAD_LIMITE_BASE: float = 500.0
static var CIUDAD_LIMITE_BASE_COMIDA: float = 5000.0
static var CIUDAD_FACTOR_NUCLEO: float = 2.0
static var CIUDAD_BONO_BAUL: float = 100.0
static var CIUDAD_BONO_BAUL_COMIDA: float = 400.0
static var CIUDAD_COMIDA_INICIAL: float = 5000.0
static var CIUDAD_MADERA_INICIAL: float = 200.0

## Umbrales de comida y moral
static var CIUDAD_UMBRAL_COMIDA_SUPERAVIT: float = 0.90
static var CIUDAD_UMBRAL_COMIDA_ESTABLE: float = 0.80
static var CIUDAD_HORAS_AUTONOMIA_ALARMA: float = 72.0
static var CIUDAD_PESO_ESCASEZ_COMIDA: float = 3.0
static var CIUDAD_BONO_SUPERAVIT_COMIDA: float = 0.4
static var CIUDAD_UMBRAL_NOTIF_RECURSO_BAJO: float = 0.05
static var CIUDAD_UMBRAL_REARME_RECURSO_BAJO: float = 0.15


# ==============================================================================
# ECONOMÍA, ENERGÍA, COLONOS Y RUTAS (Economia, Energia, Colonos, BuscadorRutas)
# ==============================================================================
static var ECONOMIA_CAPACIDAD_CARGA: float = 150.0
static var ECONOMIA_PORCENTAJES_RESERVA_INSUMO: Array[float] = [0.0, 0.10, 0.20, 0.35, 0.50]
static var ECONOMIA_VALORES_RESERVA_INSUMO: Array[float] = [0.0, 50.0, 100.0, 250.0, 500.0]
static var ECONOMIA_CARGA_MINIMA: float = 10.0
static var ECONOMIA_HORAS_FORMACION: int = 24
static var ECONOMIA_TICKS_RECALCULO: int = 6

static var ENERGIA_CONSUMO_COMBUSTIBLE_POR_LOTE: float = 1.0
static var ENERGIA_POR_LOTE_CENTRAL: float = 20.0
static var ENERGIA_ORDEN_COMBUSTIBLES: Array = ["combustible", "crudo", "carbon"]

static var COLONOS_VELOCIDAD_COLONO: float = 2.5
static var COLONOS_ESPERA_ENTRE_DESTINOS_MIN: float = 1.0
static var COLONOS_ESPERA_ENTRE_DESTINOS_MAX: float = 3.0
static var COLONOS_ESPERA_BLOQUEO: float = 0.5
static var COLONOS_INTENTOS_DESTINO: int = 8
static var COLONOS_INTENTOS_APARICION: int = 200
static var COLONOS_PROBABILIDAD_CASA: float = 0.5
static var COLONOS_ESPERA_TRABAJO: float = 1.0
static var COLONOS_NODOS_POR_FRAME: int = 300
static var COLONOS_FALLOS_PARA_VETAR: int = 3
static var COLONOS_RADIO_SERVICIO: int = 2
static var COLONOS_TOPE_NODOS_DESTINO: int = 2500

static var BUSCADOR_RUTAS_MAX_NODOS_EXPANDIDOS: int = 30000
static var BUSCADOR_RUTAS_CAIDA_MAXIMA: int = 3


# ==============================================================================
# RECOLECCIÓN, MINERÍA Y CADENA DE MINERALES (Recoleccion, CadenaMinerales)
# ==============================================================================
static var RECOLECCION_RADIO_AREA_MINA: int = 6
static var RECOLECCION_PROFUNDIDAD_MINA_NIVEL_1: int = 8
static var RECOLECCION_PROFUNDIDAD_MINA_NIVEL_2: int = 16
static var RECOLECCION_PROFUNDIDAD_MINA_NIVEL_3: int = 24
static var RECOLECCION_MULTIPLICADOR_NIVEL: Dictionary = {1: 1.0, 2: 1.5, 3: 2.0}
static var RECOLECCION_TASAS_BASE_MINERAL: Dictionary = {
	"tierra": 1.0, "piedra": 5.0, "hierro": 5.0,
	"cobre": 5.0, "carbon": 5.0, "tierras_raras": 5.0,
}
static var RECOLECCION_UMBRAL_AGOTADO_MADERERO: float = 0.5
static var RECOLECCION_ESCUELAS: Dictionary = {
	"escuela_tecnica": {"origen": "obrero", "destino": "tecnico", "horas": 24},
	"escuela_especialistas": {"origen": "tecnico", "destino": "especialista", "horas": 48},
}
static var RECOLECCION_ANCHO_HUELLA_MINA: int = 5
static var RECOLECCION_ALTO_HUELLA_MINA: int = 5
static var RECOLECCION_RENDIMIENTO_POR_BLOQUE: Dictionary = {
	"tierra": 1.0, "piedra": 10.0, "hierro": 10.0, "cobre": 10.0,
	"carbon": 10.0, "tierras_raras": 10.0, "madera": 10.0,
	"crudo": 10.0,
}
static var RECOLECCION_TIEMPO_MINADO: Dictionary = {
	"tierra": 0.4, "piedra": 1.2, "carbon": 1.2,
	"hierro": 1.6, "cobre": 1.6, "tierras_raras": 2.4,
}
static var RECOLECCION_TIEMPO_MINADO_DEFECTO: float = 0.6
static var RECOLECCION_MULTIPLICADOR_HERRAMIENTA: float = 1.0
static var RECOLECCION_TIEMPO_TALA_POR_SALUD: float = 1.0
static var RECOLECCION_TIEMPO_RECOLECCION_FRUTOS: float = 2.0
static var RECOLECCION_COMIDA_POR_RECOLECCION: float = 60.0
static var RECOLECCION_HORAS_REBROTE_FRUTOS: int = 24
static var RECOLECCION_PROFUNDIDAD_MINIMA_EXTRACCION: int = 2
static var RECOLECCION_PERSONAL_MAXIMO: int = 5
static var RECOLECCION_CAPACIDAD_ALMACENAMIENTO: int = 1000
static var RECOLECCION_TASA_BASE_ESTACION_BOMBEO_AGUA: float = 2.0
static var RECOLECCION_TASA_BASE_CENTRO_EXTRACCION_CRUDO: float = 2.5
static var RECOLECCION_TASA_BASE_CENTRO_EXTRACCION_AGUA: float = 5.0

static var RECOLECCION_ANCHO_HUELLA_MADERERO: int = 3
static var RECOLECCION_ALTO_HUELLA_MADERERO: int = 4
static var RECOLECCION_RADIO_AREA_MADERERO: int = 12
static var RECOLECCION_PASO_MUESTREO_MADERERO: int = 2
static var RECOLECCION_TASA_BASE_MADERERO_POR_CIUDADANO: float = 5.0
static var RECOLECCION_PERSONAL_MAXIMO_MADERERO: int = 5
static var RECOLECCION_CAPACIDAD_ALMACENAMIENTO_MADERERO: int = 1000

static var RECOLECCION_RADIO_AREA_CAZA_RECOLECCION: int = 12
static var RECOLECCION_PASO_MUESTREO_CAZA_RECOLECCION: int = 2
static var RECOLECCION_TASA_BASE_CAZA_POR_CIUDADANO: float = 17.0
static var RECOLECCION_TASA_BASE_FRUTOS_POR_CIUDADANO: float = 10.0
static var RECOLECCION_ANCHO_HUELLA_CAZA_RECOLECCION: int = 4
static var RECOLECCION_ALTO_HUELLA_CAZA_RECOLECCION: int = 4
static var RECOLECCION_PERSONAL_MAXIMO_CAZA_RECOLECCION: int = 7
static var RECOLECCION_CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION: int = 1000

static var RECOLECCION_ANCHO_HUELLA_PESCA_FRUTOS_MAR: int = 4
static var RECOLECCION_ALTO_HUELLA_PESCA_FRUTOS_MAR: int = 6
static var RECOLECCION_RADIO_AREA_PESCA_FRUTOS_MAR: int = 25
static var RECOLECCION_TASA_BASE_PESCA_POR_CIUDADANO: float = 17.0
static var RECOLECCION_TASA_BASE_ALGAS_POR_CIUDADANO: float = 3.0
static var RECOLECCION_PECES_FACTOR_SOMERO: float = 0.5
static var RECOLECCION_AGUA_REFERENCIA: float = 450.0
static var RECOLECCION_ESCALA_AGUA_MIN: float = 0.4
static var RECOLECCION_ESCALA_AGUA_MAX: float = 1.5
static var RECOLECCION_PERSONAL_MAXIMO_PESCA_FRUTOS_MAR: int = 7
static var RECOLECCION_CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR: int = 1000

static var CADENA_MINERALES_RECETAS: Dictionary = {
	"hierro": {"entradas": {"hierro": 3, "carbon": 4}, "tipo_salida": "acero", "cantidad_salida": 2, "tasa_base": 2.0, "energia_por_lote": 0},
	"tierras_raras": {"entradas": {"tierras_raras": 3}, "tipo_salida": "mineral_refinado", "cantidad_salida": 1, "tasa_base": 0.5, "energia_por_lote": 0},
	"aserradero": {"entradas": {"madera": 1}, "tipo_salida": "tablas", "cantidad_salida": 3, "tasa_base": 0.5, "energia_por_lote": 0},
	"fabrica_bloques": {"entradas": {"piedra": 1}, "tipo_salida": "bloques_piedra", "cantidad_salida": 3, "tasa_base": 0.5, "energia_por_lote": 0},
	"carbonera": {"entradas": {"madera": 3}, "tipo_salida": "carbon", "cantidad_salida": 1, "tasa_base": 2.0, "energia_por_lote": 0},
	"petroleo": {"entradas": {"crudo": 2}, "tipo_salida": "combustible", "cantidad_salida": 1, "tasa_base": 1.0, "energia_por_lote": 1},
	"combustible_sintetico": {"entradas": {"carbon": 3, "agua": 1}, "tipo_salida": "combustible", "cantidad_salida": 2, "tasa_base": 1.0, "energia_por_lote": 1},
}
static var CADENA_MINERALES_PERSONAL_MAXIMO_REFINERIA: int = 4
static var CADENA_MINERALES_CAPACIDAD_ALMACENAMIENTO_REFINERIA: int = 1000
static var CADENA_MINERALES_LIMITE_CRUDO_REFINERIA: float = 400.0
static var CADENA_MINERALES_RESERVA_COMBUSTIBLE_REFINERIA: float = 600.0


# ==============================================================================
# CONSTRUCCIÓN, OBRAS, NIVELACIÓN, VÍAS, CANALIZACIONES Y ZONIFICACIÓN
# ==============================================================================
static var FINALIZACION_OBRAS_INTERVALO_PASO: float = 0.20

static var OBRAS_ESPERA_BLOQUEADA: float = 1.0
static var OBRAS_HORAS_PROGRAMADAS: int = 5
static var OBRAS_DURACION_VETO_MS: int = 30000
static var OBRAS_DURACION_RECLAMO_MS: int = 3000
static var OBRAS_PRIORIDAD_ALTA: int = 2
static var OBRAS_PRIORIDAD_NORMAL: int = 1
static var OBRAS_PRIORIDAD_BAJA: int = 0

static var NIVELADOR_TERRENO_LIMITE_PENDIENTE: int = 2
static var NIVELADOR_TERRENO_COSTO_POR_CELDA: Dictionary = {
	"tierra": {"tierra": 1},
	"adobe": {"tierra": 1},
	"bloque_madera": {"madera": 5},
	"bloque_piedra": {"piedra": 5},
	"estructura_hierro": {"hierro": 5},
	"bloque_acero": {"acero": 3},
	"vidrio": {"tierra": 1},
	"puerta_inferior": {"madera": 1},
	"puerta_superior": {"madera": 1},
	"puerta": {"madera": 2},
	"cama_cabecera": {"madera": 1},
	"cama_pies": {"madera": 1},
	"cama": {"madera": 2},
	"baul": {"madera": 1},
	"mesa_estudio": {"madera": 1},
}

static var NIVELADOR_VIA_LIMITE_DESNIVEL_VIA: int = 3
static var TRAZADOR_VIAS_MAX_NODOS_EXPANDIDOS: int = 5000
static var VIAS_COSTE_TERRENO_NATURAL: int = 8
static var VIAS_BONO_VELOCIDAD_TIERRA_PISADA: float = 1.35
static var VIAS_COSTE_RUTA_TIERRA_PISADA: int = 3

static var CANALIZACIONES_ALTURA_DESPEJE: int = 3
static var CANALIZACIONES_ALTURA_DUCTO_RELATIVA: int = 4
static var CANALIZACIONES_INTERVALO_COLUMNAS: int = 5

static var ZONIFICACION_MARGEN_ZONA_INFLUENCIA: int = 15
static var ZONIFICACION_MARGEN_POR_CATEGORIA: Dictionary = {
	"residencial": 6,
	"investigacion": 10,
	"industrial": 10,
	"militar": 12,
}
static var ZONIFICACION_MARGEN_CATEGORIA_DEFECTO: int = 6

static var BLUEPRINTS_MAX_RESIDENCIALES: int = 5
static var BLUEPRINT_ALTURA_MINIMA_PISO: int = 3

static var CARA_APUNTADA_DESFASE: float = 0.005
static var FANTASMAS_DESTACADOS_TAMANO_CAJA: float = 1.01
static var MARCAS_DEMOLICION_TAMANO_CAJA: float = 1.02
static var TRANSLUCIDOS_CHUNK_SIZE: int = 16
static var VIAS_RENDERER_CHUNK_SIZE: int = 16
static var VIAS_RENDERER_ALTURA_SOBRE_SOPORTE: float = 1.005
static var PUERTAS_DURACION_GIRO: float = 0.2
static var PUERTAS_GROSOR: float = 0.1
static var HUMO_REFINERIAS_PARTICULAS: int = 16
static var HUMO_REFINERIAS_TIEMPO_VIDA: float = 2.6


# ==============================================================================
# INVESTIGACIÓN DESCENTRALIZADA, PACING DE ERAS (IDU) Y DOCTRINAS
# ==============================================================================
static var IDU_PESO_EDIFICIOS: float = 0.40
static var IDU_PESO_LABORAL: float = 0.35
static var IDU_PESO_CIENCIA: float = 0.25

static var IDU_UMBRAL_ERA_2: float = 1.50
static var IDU_UMBRAL_ERA_3: float = 2.50
static var IDU_UMBRAL_ERA_4: float = 3.50

static var CIENCIAS_TEORICAS_CATALOGO: Dictionary = {
	"metalurgia_hornos": {
		"nombre": "Metalurgia de Hornos",
		"era": 2,
		"costo_puntos": 100,
		"prerrequisito": "",
		"costo_recursos": {"hierro": 50, "madera": 50},
	},
	"hidraulica_canales": {
		"nombre": "Hidráulica de Canales",
		"era": 2,
		"costo_puntos": 120,
		"prerrequisito": "",
		"costo_recursos": {"piedra": 50, "madera": 50},
	},
	"traccion_animal_engranajes": {
		"nombre": "Tracción Animal y Engranajes",
		"era": 2,
		"costo_puntos": 150,
		"prerrequisito": "",
		"costo_recursos": {"madera": 100, "hierro": 30},
	},
	"termodinamica_vapor": {
		"nombre": "Termodinámica y Vapor",
		"era": 3,
		"costo_puntos": 300,
		"prerrequisito": "metalurgia_hornos",
		"costo_recursos": {"acero": 50, "carbon": 50},
	},
	"redes_electricas_bobinado": {
		"nombre": "Redes Eléctricas y Bobinado",
		"era": 3,
		"costo_puntos": 350,
		"prerrequisito": "hidraulica_canales",
		"costo_recursos": {"cobre": 50, "hierro": 50},
	},
	"quimica_hidrocarburos": {
		"nombre": "Química de Hidrocarburos",
		"era": 3,
		"costo_puntos": 400,
		"prerrequisito": "termodinamica_vapor",
		"costo_recursos": {"crudo": 50, "carbon": 50},
	},
	"automatizacion_cibernetica": {
		"nombre": "Automatización y Cibernética",
		"era": 4,
		"costo_puntos": 800,
		"prerrequisito": "redes_electricas_bobinado",
		"costo_recursos": {"tierras_raras": 50, "cobre": 50},
		"doctrina": "cyberpunk",
	},
	"combustion_pesada_blindajes": {
		"nombre": "Combustión Pesada y Blindajes",
		"era": 4,
		"costo_puntos": 800,
		"prerrequisito": "quimica_hidrocarburos",
		"costo_recursos": {"acero": 100, "combustible": 50},
		"doctrina": "dieselpunk",
	},
	"biotecnologia_fototermia": {
		"nombre": "Biotecnología y Fototermia",
		"era": 4,
		"costo_puntos": 800,
		"prerrequisito": "quimica_hidrocarburos",
		"costo_recursos": {"tierras_raras": 30, "piedra": 50},
		"doctrina": "solarpunk",
	},
}

static var MEJORAS_PRACTICAS_CATALOGO: Dictionary = {
	"inyeccion_forzada": {
		"nombre": "Inyección Forzada",
		"edificio_tipo": "siderurgica",
		"req": "metalurgia_hornos",
		"prerrequisito": "metalurgia_hornos",
		"era": 2,
		"investigadores": 1,
		"doctrina": "dieselpunk",
		"puntos_doctrina": 10,
		"costo": {"hierro": 100, "madera": 50},
		"tiempo": 20.0,
		"excluye": [],
	},
	"caldera_diesel": {
		"nombre": "Caldera Diésel de Alta Presión",
		"edificio_tipo": "central_termoelectrica",
		"req": "quimica_hidrocarburos",
		"prerrequisito": "quimica_hidrocarburos",
		"era": 3,
		"investigadores": 2,
		"doctrina": "dieselpunk",
		"puntos_doctrina": 15,
		"excluye": ["ciclo_solarpunk"],
		"costo": {"acero": 100, "combustible": 50},
		"tiempo": 30.0,
	},
	"ciclo_solarpunk": {
		"nombre": "Ciclo Geotérmico / Biocombustión Solarpunk",
		"edificio_tipo": "central_termoelectrica",
		"req": "biotecnologia_fototermia",
		"prerrequisito": "biotecnologia_fototermia",
		"era": 4,
		"investigadores": 3,
		"doctrina": "solarpunk",
		"puntos_doctrina": 15,
		"excluye": ["caldera_diesel"],
		"costo": {"cristal": 100, "tierras_raras": 30},
		"tiempo": 40.0,
	},
	"control_cibernetico": {
		"nombre": "Control Cibernético de Procesos",
		"edificio_tipo": "central_termoelectrica",
		"req": "automatizacion_cibernetica",
		"prerrequisito": "automatizacion_cibernetica",
		"era": 4,
		"investigadores": 3,
		"doctrina": "cyberpunk",
		"puntos_doctrina": 15,
		"costo": {"tierras_raras": 50, "acero": 100},
		"tiempo": 40.0,
		"excluye": [],
	},
	"riego_acueducto": {
		"nombre": "Riego por Acueducto",
		"edificio_tipo": "sembradios",
		"req": "hidraulica_canales",
		"prerrequisito": "hidraulica_canales",
		"era": 2,
		"investigadores": 1,
		"doctrina": "solarpunk",
		"puntos_doctrina": 10,
		"costo": {"piedra": 100, "madera": 50},
		"tiempo": 20.0,
		"excluye": [],
	},
	"micorrizas_agricolas": {
		"nombre": "Micorrizas Agrícolas Modificadas",
		"edificio_tipo": "sembradios",
		"req": "biotecnologia_fototermia",
		"prerrequisito": "biotecnologia_fototermia",
		"era": 4,
		"investigadores": 3,
		"doctrina": "solarpunk",
		"puntos_doctrina": 20,
		"costo": {"cristal": 50, "tierras_raras": 20},
		"tiempo": 35.0,
		"excluye": [],
	},
}

static var RECONVERSION_FACTOR_MATERIALES_MEJORA: float = 0.50
static var RECONVERSION_FACTOR_COSTO_EDIFICIO: float = 0.25
static var RECONVERSION_FACTOR_TIEMPO: float = 1.5
static var RECONVERSION_PRODUCCION_PENALIZADA: float = 0.25

