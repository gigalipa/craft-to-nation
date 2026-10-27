extends RefCounted
## Fuente única centralizada de todos los textos visibles en la interfaz gráfica
## del jugador en Craft to Nation.
##
## Resuelve los textos en función de `Ajustes.idioma` (actualmente `"es"`).
## Permite traducir el juego a múltiples idiomas en el futuro cambiando
## `Ajustes.idioma` y llamando a `Strings.actualizar_idioma()`.

const Ajustes = preload("res://scripts/ajustes.gd")


# ==============================================================================
# CATÁLOGO GENERAL DE RECURSOS, ZONAS, PUESTOS, ROLES Y MORAL
# ==============================================================================
static var NOMBRES_RECURSO: Dictionary = {
	"madera": "Madera",
	"tablas": "Tablas",
	"comida": "Comida",
	"tierra": "Tierra",
	"piedra": "Piedra",
	"bloques_piedra": "Bloques de piedra",
	"hierro": "Hierro",
	"cobre": "Cobre",
	"carbon": "Carbón",
	"tierras_raras": "Tierras raras",
	"acero": "Acero",
	"mineral_refinado": "Mineral refinado",
	"agua": "Agua",
	"crudo": "Crudo",
	"combustible": "Combustible",
	"caza": "Comida (caza)",
	"recoleccion": "Comida (frutos)",
	"pesca": "Comida (pesca)",
	"frutos_mar": "Comida (algas)",
}

static var NOMBRES_SUB_COMIDA: Dictionary = {
	"pesca": "Pesca y frutos del mar",
	"recoleccion_caza": "Caza y recolección",
	"sembradios": "Sembradíos y agricultura",
	"granjas_animales": "Granjas animales",
	"hidroponia": "Cultivo hidropónico",
	"sintetico": "Alimentos sintéticos",
}

static var NOMBRES_RECURSO_ALMACEN_INICIAL: Dictionary = {
	"madera": "Madera",
	"comida": "Comida",
	"hierro": "Hierro",
	"tierra": "Tierra",
	"piedra": "Piedra",
	"cobre": "Cobre",
	"carbon": "Carbón",
	"tierras_raras": "Tierras raras",
	"acero": "Acero",
	"mineral_refinado": "Mineral refinado",
	"tablas": "Tablas",
	"bloques_piedra": "Bloques de piedra",
	"agua": "Agua",
	"crudo": "Crudo",
	"combustible": "Combustible",
}

static var NOMBRES_RECURSO_LEGIBLE_DUCTO: Dictionary = {
	"bloque_acero": "Bloque de acero",
	"estructura_hierro": "Estructura de hierro",
	"bloque_piedra": "Bloque de piedra",
	"bloque_madera": "Bloque de madera",
}

static var NOMBRES_FLUIDO: Dictionary = {
	"agua": "Agua",
	"crudo": "Crudo",
	"combustible": "Combustible",
	"": "Sin fluido (vacío)",
}

static var NOMBRES_ZONA: Dictionary = {
	"residencial_investigacion": "Residencial / Investigación",
	"fabricacion_militar": "Fabricación / Militar",
	"periferia": "Periferia",
	"borrar": "Borrar zona",
}

static var NOMBRES_MORAL: Dictionary = {
	"euforica": "Eufórica",
	"estable": "Estable",
	"baja": "Baja",
	"critica": "Crítica",
}

static var NOMBRES_PUESTO: Dictionary = {
	"mina": "Mina",
	"caza_recoleccion": "Puesto de caza y recolección",
	"maderero": "Puesto maderero",
	"pesca_frutos_mar": "Puesto de pesca y frutos del mar",
	"siderurgica": "Siderúrgica",
	"refineria_tierras_raras": "Refinería de tierras raras",
	"aserradero": "Aserradero",
	"fabrica_bloques": "Fábrica de bloques",
	"carbonera": "Carbonera",
	"refineria_petrolera": "Refinería petrolera",
	"productor_combustible": "Productor de combustible",
	"central_termoelectrica": "Central termoeléctrica",
	"escuela_tecnica": "Escuela técnica",
	"escuela_especialistas": "Escuela de especialistas",
	"universidad": "Universidad",
	"estacion_bombeo": "Estación de bombeo",
	"centro_extraccion": "Centro de extracción",
	"almacen": "Almacén",
}

static var SUBTITULOS_PUESTO: Dictionary = {
	"mina": "Puesto de extracción",
	"caza_recoleccion": "Puesto de recolección",
	"maderero": "Puesto de recolección",
	"pesca_frutos_mar": "Puesto costero",
	"siderurgica": "Refinería",
	"refineria_tierras_raras": "Refinería",
	"aserradero": "Taller de aserrado",
	"fabrica_bloques": "Taller de cantería",
	"carbonera": "Horno de carbón",
	"refineria_petrolera": "Destilería industrial",
	"productor_combustible": "Planta sintética",
	"central_termoelectrica": "Generación eléctrica",
	"escuela_tecnica": "Centro de formación",
	"escuela_especialistas": "Centro de formación",
	"universidad": "Centro de investigación",
	"estacion_bombeo": "Extracción superficial de agua",
	"centro_extraccion": "Extracción subterránea por pozo",
	"almacen": "Depósito logístico e industrial",
}

static var NOMBRES_OFICIO: Dictionary = {
	"desempleado": "Desempleados",
	"obrero": "Obreros",
	"tecnico": "Técnicos",
	"especialista": "Especialistas",
	"investigador": "Investigadores",
}

static var NOMBRES_ROL_EDIFICIO: Dictionary = {
	"ciudadano": "Ciudadanos",
	"desempleado": "Desempleados",
	"obrero": "Obreros",
	"tecnico": "Técnicos",
	"especialista": "Especialistas",
	"investigador": "Investigadores",
	"militar": "Militares",
}

static var NOMBRES_PRIORIDAD: Dictionary = {
	2: "Alta",
	1: "Normal",
	0: "Baja",
}

static var INFO_TECHS: Dictionary:
	get:
		var n2_pisos: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(2, {}).get("pisos", 4)
		var n2_camas: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(2, {}).get("camas_por_piso", 4)
		var n3_pisos: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(3, {}).get("pisos", 8)
		var n3_camas: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(3, {}).get("camas_por_piso", 4)
		return {
			2: {"nombre": "Metalurgia Aplicada", "beneficios": "Habilita Nivel 2 de ciudad (hasta %d pisos y %d camas/piso) e instalaciones intermedias." % [n2_pisos, n2_camas]},
			3: {"nombre": "Automatización Industrial", "beneficios": "Habilita Nivel 3 de ciudad (hasta %d pisos y %d camas/piso), refinería petrolera y plantas avanzadas." % [n3_pisos, n3_camas]},
		}

static var INFO_PUERTOS_BLOQUE: Dictionary = {
	"puerto_in": "Entrada",
	"puerto_out": "Salida",
	"puerto_agua_in": "Entrada agua",
	"puerto_agua_out": "Salida agua",
	"puerto_crudo_in": "Entrada crudo",
	"puerto_crudo_out": "Salida crudo",
	"puerto_combustible_in": "Entrada combustible",
	"puerto_combustible_out": "Salida combustible",
}


# ==============================================================================
# HOTBAR, BARRA DE MODOS, BARRA SUPERIOR Y HUD GENERAL
# ==============================================================================
static var HOTBAR_NOMBRES: Dictionary = {
	"mano": "Mano",
	"tierra": "Tierra",
	"adobe": "Adobe",
	"bloque_madera": "Madera",
	"bloque_piedra": "Piedra",
	"estructura_hierro": "Hierro",
	"bloque_acero": "Acero",
	"vidrio": "Vidrio",
	"puerta": "Puerta",
	"cama": "Cama",
	"baul": "Baúl",
	"lampara": "Lámpara",
}

static var HOTBAR_CONTROLES_AVATAR: String = "WASD: mover · Espacio: saltar · Clic izq (mantener): minar / talar / cosechar · Clic der: colocar / usar · C: cámara cenital"
static var HOTBAR_PAGINA_TOOLTIP: String = "Cambiar página de bloques (Tab)"
static var HOTBAR_BTN_MODOS_TEXTO: String = "M\nModos"
static var HOTBAR_BTN_MODOS_TOOLTIP: String = "Mostrar/ocultar modos de cámara cenital"

static var BARRA_MODOS_CATALOGOS_CONSTRUIR: Dictionary = {
	"residencial": [
		{"id": "residencial:0", "nombre": "Residencial 1"},
		{"id": "residencial:1", "nombre": "Residencial 2"},
		{"id": "residencial:2", "nombre": "Residencial 3"},
		{"id": "residencial:3", "nombre": "Residencial 4"},
		{"id": "residencial:4", "nombre": "Residencial 5"},
	],
	"recoleccion": [
		{"id": "mina", "nombre": "Mina"},
		{"id": "maderero", "nombre": "Maderero"},
		{"id": "caza_recoleccion", "nombre": "Caza/Recol."},
		{"id": "pesca_frutos_mar", "nombre": "Pesca"},
		{"id": "estacion_bombeo", "nombre": "Est. Bombeo"},
		{"id": "centro_extraccion", "nombre": "Centro Extrac."},
	],
	"procesamiento": [
		{"id": "aserradero", "nombre": "Aserradero"},
		{"id": "fabrica_bloques", "nombre": "Fáb. Bloques"},
		{"id": "carbonera", "nombre": "Carbonera"},
		{"id": "siderurgica", "nombre": "Siderúrgica"},
		{"id": "refineria_tierras_raras", "nombre": "Ref. Tierras"},
		{"id": "refineria_petrolera", "nombre": "Ref. Petrolera"},
		{"id": "productor_combustible", "nombre": "Prod. Combust."},
	],
	"energia": [
		{"id": "central_termoelectrica", "nombre": "Termoeléctrica"},
	],
	"logistica": [
		{"id": "almacen", "nombre": "Almacén"},
		{"id": "acueducto", "nombre": "Acueducto"},
		{"id": "tuberia", "nombre": "Tubería"},
	],
	"educacion": [
		{"id": "escuela_tecnica", "nombre": "Esc. Técnica"},
		{"id": "escuela_especialistas", "nombre": "Esc. Espec."},
		{"id": "universidad", "nombre": "Universidad"},
	],
}

static var BARRA_MODOS_ITEMS: Dictionary = {
	"libre": {
		"tecla": "", "etiqueta": "Inspección", "icono": "libre",
		"titulo": "Modo libre (inspección)",
		"descripcion": "Clic izq sobre un puesto o edificio para abrir su ficha.\nWASD: mover · Q/E: rotar · R/F: inclinar · Z/X: altura · Rueda: zoom · C: volver al avatar",
	},
	"zonificar": {
		"tecla": "Z", "etiqueta": "Zonificar", "icono": "zonificar",
		"titulo": "Zonificación",
		"descripcion": "Clic izq en dos esquinas para pintar o borrar el rectángulo (dentro de la zona de influencia).",
		"submodos": [
			{"id": "residencial_investigacion", "tecla": "1", "etiqueta": "Residencial"},
			{"id": "fabricacion_militar", "tecla": "2", "etiqueta": "Fabricación"},
			{"id": "borrar", "tecla": "0", "etiqueta": "Borrar"},
		],
	},
	"construir": {
		"tecla": "B", "etiqueta": "Construir", "icono": "construir",
		"titulo": "Construcción",
		"descripcion": "Selecciona una categoría para desplegar sus edificaciones disponibles.",
		"submodos": [
			{"id": "cat_residencial", "tecla": "1", "etiqueta": "Residencial", "icono": "cat_residencial", "categoria": "residencial"},
			{"id": "cat_recoleccion", "tecla": "2", "etiqueta": "Recolección", "icono": "cat_recoleccion", "categoria": "recoleccion"},
			{"id": "cat_procesamiento", "tecla": "3", "etiqueta": "Procesam.", "icono": "cat_procesamiento", "categoria": "procesamiento"},
			{"id": "cat_energia", "tecla": "4", "etiqueta": "Energía", "icono": "cat_energia", "categoria": "energia"},
			{"id": "cat_logistica", "tecla": "5", "etiqueta": "Logística", "icono": "cat_logistica", "categoria": "logistica"},
			{"id": "cat_educacion", "tecla": "6", "etiqueta": "Educación", "icono": "cat_educacion", "categoria": "educacion"},
		],
	},
	"nivelar": {
		"tecla": "N", "etiqueta": "Nivelar", "icono": "nivelar",
		"titulo": "Nivelación de terreno",
		"descripcion": "Clic izq en dos esquinas para nivelar a la altura del primer clic · Clic der: cancelar",
	},
	"vias": {
		"tecla": "V", "etiqueta": "Vías", "icono": "vias",
		"titulo": "Trazado de vías (tierra pisada)",
		"descripcion": "Clic izq encadena tramos desde la zona de influencia · Doble clic confirma · Clic der deshace",
	},
	"demoler": {
		"tecla": "X", "etiqueta": "Demoler", "icono": "demoler",
		"titulo": "Demolición",
		"descripcion": "Edificios: clic izq marca/desmarca.\nVías: clic izq en inicio y fin del tramo (o sección 2x2) para ordenar su demolición.",
		"submodos": [
			{"id": "edificio", "tecla": "1", "etiqueta": "Edificio"},
			{"id": "via_tramo", "tecla": "2", "etiqueta": "Tramo vía"},
			{"id": "via_seccion", "tecla": "3", "etiqueta": "Sección 2x2"},
		],
	},
}

static var BARRA_MODOS_ACCIONES: Dictionary = {
	"girar": {"tecla": "R", "etiqueta": "Girar 90°"},
	"deshacer": {"tecla": "Clic der", "etiqueta": "Último punto"},
	"cancelar": {"tecla": "Esc", "etiqueta": "Salir del modo"},
}

static var BARRA_MODOS_RESIDENCIAL_SIN_DISENO: String = "Residencial %d (Sin diseño)"
static var BARRA_MODOS_PAGINA_TOOLTIP: String = "Cambiar página"
static var BARRA_MODOS_DESC_CONSTRUIR_RESIDENCIAL: String = "R: girar 90° · Clic izq: emplazar fantasma · Esc: cancelar"
static var BARRA_MODOS_DESC_CONSTRUIR_GENERICO: String = "R: girar 90° · Clic izq: emplazar · Esc: cancelar"
static var BARRA_MODOS_DESC_DEMOLER_VIA_TRAMO: String = "Demoler tramo de vía: Clic izq en punto A y luego en punto B de la vía conectada · Clic der: cancelar punto A"
static var BARRA_MODOS_DESC_DEMOLER_VIA_SECCION: String = "Demoler sección 2x2: Clic izq sobre cualquier bloque de vía para ordenar demoler su sección 2x2"

static var BARRA_SUPERIOR_NIVEL_CIUDAD: String = "Nv. %d"
static var BARRA_SUPERIOR_POBLACION_TOOLTIP: String = "Ver población por tipo"
static var BARRA_SUPERIOR_ALMACEN_TOOLTIP: String = "Ver recursos del almacén"
static var BARRA_SUPERIOR_ENERGIA_TOOLTIP: String = "Ver balance de red eléctrica"
static var BARRA_SUPERIOR_MORAL_TOOLTIP: String = "Ver estado de moral y migración"

static var HUD_TEXTO_OXIGENO: String = "Oxígeno  %d%%"
static var PANEL_CONTEXTUAL_TECLA_CERRAR: String = "[Esc] Salir del modo"


# ==============================================================================
# PANEL DE PUESTO (PanelPuesto.gd)
# ==============================================================================
static var PANEL_PUESTO_NIVEL_INSTALACION: String = "%s · Instalación Nv. %d"
static var PANEL_PUESTO_SECCION_EMPLEADOS: String = "EMPLEADOS"
static var PANEL_PUESTO_SECCION_FORMACION: String = "FORMACIÓN"
static var PANEL_PUESTO_SECCION_INVESTIGACION: String = "PROYECTOS DE INVESTIGACIÓN"
static var PANEL_PUESTO_SECCION_ESTADO_OPERATIVO: String = "ESTADO OPERATIVO"
static var PANEL_PUESTO_SECCION_PRODUCCION: String = "PRODUCCIÓN"
static var PANEL_PUESTO_SECCION_ALMACEN_LOCAL: String = "ALMACÉN LOCAL"
static var PANEL_PUESTO_SECCION_CONEXIONES: String = "CONEXIONES DE TUBERÍA"
static var PANEL_PUESTO_SECCION_OBRA: String = "OBRA"
static var PANEL_PUESTO_BTN_CERRAR_TOOLTIP: String = "Cerrar (Esc)"
static var PANEL_PUESTO_BTN_CONTRATAR_TOOLTIP: String = "Contratar"
static var PANEL_PUESTO_BTN_DESPEDIR_TOOLTIP: String = "Despedir"
static var PANEL_PUESTO_ROL_OPERADORES: String = "Operadores"
static var PANEL_PUESTO_ROL_TECNICOS: String = "Técnicos"
static var PANEL_PUESTO_ROL_ACARREADORES: String = "Acarreadores"
static var PANEL_PUESTO_ROL_APRENDICES: String = "Aprendices"
static var PANEL_PUESTO_ROL_INVESTIGADORES: String = "Investigadores"
static var PANEL_PUESTO_ROL_OBREROS: String = "Obreros"
static var PANEL_PUESTO_ROL_ESPECIALISTAS: String = "Especialistas"
static var PANEL_PUESTO_DISPONIBLES_FORMATO: String = "Disponibles: %s"
static var PANEL_PUESTO_DISPONIBLES_PARTE: String = "%s: %d"
static var PANEL_PUESTO_PRIORIDAD_CONSTRUCCION: String = "Prioridad de construcción"
static var PANEL_PUESTO_BTN_CAMBIAR_PRIORIDAD_TOOLTIP: String = "Clic para cambiar prioridad (Baja -> Normal -> Alta)"
static var PANEL_PUESTO_BTN_DEMOLER: String = "Demoler puesto"
static var PANEL_PUESTO_BTN_CANCELAR_DEMOLICION: String = "Cancelar demolición"
static var PANEL_PUESTO_BTN_PAUSAR_OBRA: String = "Pausar obra"
static var PANEL_PUESTO_BTN_REANUDAR_OBRA: String = "Reanudar obra"
static var PANEL_PUESTO_COMBUSTIBLE_CARBON: String = "Combustible: Carbón (Acarreo)"
static var PANEL_PUESTO_COMBUSTIBLE_LIQUIDO: String = "Combustible: Crudo / Combustible (Tubería)"
static var PANEL_PUESTO_BTN_COMBUSTIBLE_TOOLTIP: String = "Clic para alternar tipo de combustible de la central"
static var PANEL_PUESTO_RESERVA_CENTRAL_FORMATO: String = "Reserva central: %s"
static var PANEL_PUESTO_BTN_RESERVA_TOOLTIP: String = "Mínimo de insumo que los acarreadores dejan sin tocar en el almacén central (clic para cambiar)"
static var PANEL_PUESTO_OBRA_CONSTRUCCION: String = "En construcción (%d%%) · Obreros: %d"
static var PANEL_PUESTO_OBRA_DEMOLICION: String = "En demolición (%d%%) · Obreros: %d"
static var PANEL_PUESTO_OBRA_PAUSADA_SUFIJO: String = " · Pausada"
static var PANEL_PUESTO_OBRA_FALTA_MATERIAL: String = "\nFalta: %s"
static var PANEL_PUESTO_CUPO_TRABAJADORES: String = "Cupo: %d / %d trabajadores"
static var PANEL_PUESTO_NIVEL_ACTUAL: String = "Nivel %d"
static var PANEL_PUESTO_TECH_COMPLETADA: String = "✓ %s (Completada)"
static var PANEL_PUESTO_TECH_RECURSOS: String = "Recursos: %d Hierro, %d Madera · %d h-inv"
static var PANEL_PUESTO_TECH_YA_EN_CURSO: String = "En curso en otra universidad"
static var PANEL_PUESTO_TECH_ESTADO_PAUSADA: String = "Pausada"
static var PANEL_PUESTO_TECH_ESTADO_INVESTIGANDO: String = "Investigando"
static var PANEL_PUESTO_TECH_PROGRESO: String = "%s: %.1f / %d h (%d%%)"
static var PANEL_PUESTO_BTN_REANUDAR: String = "Reanudar"
static var PANEL_PUESTO_BTN_PAUSAR: String = "Pausar"
static var PANEL_PUESTO_BTN_CANCELAR: String = "Cancelar"
static var PANEL_PUESTO_TECH_FALTA_SOFISTICACION: String:
	get:
		return "Requiere sofisticación Nv. %%d (actual: %%.2f, inst. Nv.%%d: %%d/%d)" % Ajustes.CIUDAD_MINIMO_INSTALACIONES_NIVEL
static var PANEL_PUESTO_TECH_SIN_INVESTIGADORES: String = "Asigna investigadores para iniciar"
static var PANEL_PUESTO_TECH_FALTAN_RECURSOS: String = "Faltan recursos en almacén"
static var PANEL_PUESTO_BTN_INICIAR_INVESTIGACION: String = "Iniciar investigación"
static var PANEL_PUESTO_COHORTE_GRADUA: String = "Cada cohorte de %d gradúa %d %s (%d h)"
static var PANEL_PUESTO_COHORTE_PROGRESO: String = "Progreso: %d / %d h (%d%%)"
static var PANEL_PUESTO_COHORTE_ESTUDIANDO: String = "Estudiando (+1 h/tick)"
static var PANEL_PUESTO_COHORTE_ESPERANDO_LLEGADA: String = "En pausa: esperando que lleguen los aprendices (%d / %d)"
static var PANEL_PUESTO_COHORTE_ASIGNA_MAS: String = "Asigna %d aprendiz más para iniciar (%d / %d)"
static var PANEL_PUESTO_COHORTE_ASIGNA_MAS_PLURAL: String = "Asigna %d aprendices más para iniciar (%d / %d)"
static var PANEL_PUESTO_CENTRAL_CONECTADA: String = "Red eléctrica: Conectada"
static var PANEL_PUESTO_CENTRAL_DESCONECTADA: String = "Red eléctrica: Sin conexión a la red urbana"
static var PANEL_PUESTO_CENTRAL_PRODUCCION: String = "Producción actual: %.0f / %.0f u. energía (Demanda red: %.0f)"
static var PANEL_PUESTO_CENTRAL_ORDEN_QUEMA: String = "Orden de quema: Combustible -> Crudo -> Carbón"
static var PANEL_PUESTO_CENTRAL_FALTA_COMBUSTIBLE: String = "Sin combustible en almacén local"
static var PANEL_PUESTO_CENTRAL_OPERATIVA: String = "Operativa (%d técnicos presentes)"
static var PANEL_PUESTO_CENTRAL_ESPERANDO_TECNICOS: String = "Esperando técnicos en planta"
static var PANEL_PUESTO_EXTRACCION_SIN_CONEXION: String = "Sin conexión eléctrica (requiere vía conectada a la ciudad)"
static var PANEL_PUESTO_EXTRACCION_DEFICIT_ELECTRICO: String = "Déficit eléctrico: operando al %d%%"
static var PANEL_PUESTO_EXTRACCION_RED_ACTIVA: String = "Red eléctrica: Activa (100%%)"
static var PANEL_PUESTO_POZO_CRUDO_AGOTADO: String = "Pozo de crudo: AGOTADO (0 u.)"
static var PANEL_PUESTO_POZO_CRUDO_RESTANTE: String = "Crudo restante en pozo: %d bloques (%d u.)"
static var PANEL_PUESTO_FUENTE_AGUA_INFINITA: String = "Fuente de agua: Infinita"
static var PANEL_PUESTO_PROD_ESTACION_BOMBEO: String:
	get:
		return "Agua: +%%.1f/h (%%d presentes × %.1f/h)" % Ajustes.RECOLECCION_TASA_BASE_ESTACION_BOMBEO_AGUA

static var PANEL_PUESTO_PROD_CENTRO_EXTRACCION_CRUDO: String:
	get:
		return "Crudo: +%%.1f/h (%%d presentes × %.1f/h × %%%%d%%%% energía)" % Ajustes.RECOLECCION_TASA_BASE_CENTRO_EXTRACCION_CRUDO

static var PANEL_PUESTO_PROD_CENTRO_EXTRACCION_AGUA: String:
	get:
		return "Agua: +%%.1f/h (%%d presentes × %.1f/h × %%%%d%%%% energía)" % Ajustes.RECOLECCION_TASA_BASE_CENTRO_EXTRACCION_AGUA
static var PANEL_PUESTO_REFINERIA_RECETA: String = "Receta: %s → %d %s"
static var PANEL_PUESTO_REFINERIA_SIN_CONEXION: String = "Sin conexión eléctrica (requiere vía conectada a la ciudad)"
static var PANEL_PUESTO_REFINERIA_DEFICIT_ELECTRICO: String = "Déficit eléctrico: operando al %d%%"
static var PANEL_PUESTO_REFINERIA_FALTA_INSUMO: String = "Sin insumo: esperando %s"
static var PANEL_PUESTO_REFINERIA_LOTES_HORA: String = "%.1f lotes/h (%d presentes)"
static var PANEL_PUESTO_REFINERIA_CONSUMO: String = "%s: -%.1f/h"
static var PANEL_PUESTO_REFINERIA_PRODUCCION: String = "%s: +%.1f/h"
static var PANEL_PUESTO_AREA_AGOTADA: String = "Área agotada"
static var PANEL_PUESTO_AREA_AGOTADA_NV: String = "Área agotada a Nv. %d (asigna %s para ampliar)"
static var PANEL_PUESTO_SIN_RECURSOS_EN_AREA: String = "Sin recursos en el área"
static var PANEL_PUESTO_TASA_RECURSO_LINEA: String = "%s: +%.1f/h  (%.1f/trab.)"
static var PANEL_PUESTO_ALMACEN_SOLIDO_RESUMEN: String = "Sólidos: %d / %d"
static var PANEL_PUESTO_ALMACEN_FLUIDO_COMPARTIDO: String = "Fluidos (compartido): %d / %d"
static var PANEL_PUESTO_ALMACEN_PETROLERA_RESUMEN: String:
	get:
		return "%%d / %%d (Crudo máx %d · Comb. máx %d)" % [
			int(Ajustes.CADENA_MINERALES_LIMITE_CRUDO_REFINERIA),
			int(Ajustes.CADENA_MINERALES_RESERVA_COMBUSTIBLE_REFINERIA)
		]
static var PANEL_PUESTO_ALMACEN_CAPACIDAD_RESUMEN: String = "%d / %d"
static var PANEL_PUESTO_ALMACEN_VACIO: String = "Vacío"
static var PANEL_PUESTO_CONEXIONES_NINGUNA: String = "Ningún puerto detectado"
static var PANEL_PUESTO_PUERTO_ESTADO_CONECTADO: String = "Conectado"
static var PANEL_PUESTO_PUERTO_ESTADO_DERRAME: String = "Derrame activo (extremo abierto)"
static var PANEL_PUESTO_PUERTO_ESTADO_DESCONECTADO: String = "Desconectado"
static var PANEL_PUESTO_PUERTO_DIRECCION_ENTRADA: String = "Entrada"
static var PANEL_PUESTO_PUERTO_DIRECCION_SALIDA: String = "Salida"
static var PANEL_PUESTO_PUERTO_LINEA: String = "• %s de %s: %s"


# ==============================================================================
# PANEL DE EDIFICIO (PanelEdificio.gd)
# ==============================================================================
static var PANEL_EDIFICIO_NOMBRES_CONSTRUCCION: Dictionary = {
	"residencial": "Vivienda residencial",
	"maderero": "Aserradero maderero",
	"mina": "Mina de extracción",
	"caza_recoleccion": "Puesto de caza y recolección",
	"pesca_frutos_mar": "Muelle de pesca",
	"siderurgica": "Siderúrgica",
	"refineria_tierras_raras": "Refinería de tierras raras",
	"aserradero": "Aserradero industrial",
	"fabrica_bloques": "Fábrica de bloques",
	"carbonera": "Carbonera",
	"refineria_petrolera": "Refinería petrolera",
	"productor_combustible": "Planta de combustible",
	"central_termoelectrica": "Central termoeléctrica",
	"escuela_tecnica": "Escuela técnica",
	"escuela_especialistas": "Escuela de especialistas",
	"universidad": "Universidad",
	"estacion_bombeo": "Estación de bombeo",
	"centro_extraccion": "Centro de extracción",
	"almacen": "Almacén general",
}

static var PANEL_EDIFICIO_DESCRIPCIONES: Dictionary = {
	"nucleo": "Centro cívico y logístico de la ciudad. Almacena los recursos globales y coordina la llegada de colonos.",
	"residencial": "Aloja a los trabajadores de la ciudad y amplía la capacidad del almacén central mediante sus baúles.",
}

static var PANEL_EDIFICIO_TITULO_DEFECTO: String = "Edificio"
static var PANEL_EDIFICIO_SUBTITULO_DEFECTO: String = "Estructura"
static var PANEL_EDIFICIO_SECCION_RESIDENTES: String = "RESIDENTES Y CAPACIDAD"
static var PANEL_EDIFICIO_SECCION_COLONIZACION: String = "COLONIZACIÓN E INMIGRACIÓN"
static var PANEL_EDIFICIO_BTN_COLONIZABLE_ACTIVO: String = "Colonizable: Sí (Abierto a inmigrantes)"
static var PANEL_EDIFICIO_BTN_COLONIZABLE_INACTIVO: String = "Colonizable: No (Buffer de reubicación)"
static var PANEL_EDIFICIO_BTN_COLONIZABLE_TOOLTIP: String = "Alterna si los nuevos inmigrantes pueden ocupar camas en este edificio o si se reserva para reubicaciones."
static var PANEL_EDIFICIO_SECCION_ESTADO_OBRA: String = "ESTADO Y OBRA"
static var PANEL_EDIFICIO_PRIORIDAD_CONSTRUCCION: String = "Prioridad de construcción"
static var PANEL_EDIFICIO_SECCION_GESTION_CIVICA: String = "GESTIÓN CÍVICA"
static var PANEL_EDIFICIO_RACIONAMIENTO_INACTIVO: String = "Racionamiento: Inactivo"
static var PANEL_EDIFICIO_RACIONAMIENTO_ACTIVO: String = "Racionamiento: Activo (-35% comida, moral máx. 35)"
static var PANEL_EDIFICIO_RACIONAMIENTO_TOOLTIP: String = "Reduce el consumo de comida un 35% a costa de fijar el límite superior de moral en 35."
static var PANEL_EDIFICIO_BTN_TRASLADAR_NUCLEO: String = "Convertir en nuevo Núcleo Urbano"
static var PANEL_EDIFICIO_BTN_TRASLADAR_NUCLEO_TOOLTIP: String:
	get:
		return "Programa la mudanza del Núcleo Urbano a este edificio (tarda %d h de juego)" % Ajustes.CIUDAD_HORAS_TRASLADO_NUCLEO
static var PANEL_EDIFICIO_BTN_REMODELAR: String = "Remodelar edificio"
static var PANEL_EDIFICIO_BTN_REMODELAR_TOOLTIP: String = "Desdeclara el edificio para editar sus bloques libremente sin demolerlo"
static var PANEL_EDIFICIO_BTN_PAUSAR_OBRA: String = "Pausar obra"
static var PANEL_EDIFICIO_BTN_REANUDAR_OBRA: String = "Reanudar obra"
static var PANEL_EDIFICIO_BTN_DEMOLER: String = "Demoler edificio"
static var PANEL_EDIFICIO_MODAL_TITULO_CONFIRMAR: String = "Confirmar acción"
static var PANEL_EDIFICIO_BTN_CONFIRMAR: String = "Confirmar"
static var PANEL_EDIFICIO_BTN_CANCELAR: String = "Cancelar"
static var PANEL_EDIFICIO_TITULO_NUCLEO: String = "Núcleo Urbano"
static var PANEL_EDIFICIO_SUBTITULO_NUCLEO: String = "Edificio principal (ID #%d)"
static var PANEL_EDIFICIO_SUBTITULO_ID: String = "%s (ID #%d)"
static var PANEL_EDIFICIO_INFO_NUCLEO_CAPACIDAD: String:
	get:
		var accion: String = "Duplica" if is_equal_approx(Ajustes.CIUDAD_FACTOR_NUCLEO, 2.0) else "Multiplica"
		var mult_nucleo: String = str(int(Ajustes.CIUDAD_FACTOR_NUCLEO)) if is_equal_approx(Ajustes.CIUDAD_FACTOR_NUCLEO, roundf(Ajustes.CIUDAD_FACTOR_NUCLEO)) else str(Ajustes.CIUDAD_FACTOR_NUCLEO)
		return "Capacidad estructural: %%d camas · %%d baúles\n%s el límite base del almacén central (×%s)." % [accion, mult_nucleo]
static var PANEL_EDIFICIO_INFO_CAMAS_BAULES: String = "Camas: %d efectivas (%d construidas) · Baúles: %d (+%d cap. almacén)"
static var PANEL_EDIFICIO_RESIDENTES_ENCABEZADO: String = "\nResidentes actuales (%d):"
static var PANEL_EDIFICIO_RESIDENTES_NINGUNO: String = "\nSin residentes asignados actualmente."
static var PANEL_EDIFICIO_COLONIZACION_ABIERTA: String = "Abierto: los nuevos colonos pueden inmigrar directamente a este edificio."
static var PANEL_EDIFICIO_COLONIZACION_TEMPORIZADOR: String = "Buffer temporal: se abrirá automáticamente a inmigración en %d h."
static var PANEL_EDIFICIO_COLONIZACION_CERRADA: String = "Reservado como buffer: solo recibe colonos reubicados por remodelación o mudanza."
static var PANEL_EDIFICIO_ESTADO_COMPLETO: String = "Estado: Construido (100%)"
static var PANEL_EDIFICIO_ESTADO_DEMOLICION_PROG: String = "Estado: Demolición programada (inicia en %d h)"
static var PANEL_EDIFICIO_ESTADO_DEMOLICION: String = "Estado: En demolición (%d%%) · Obreros: %d"
static var PANEL_EDIFICIO_ESTADO_CONSTRUCCION: String = "Estado: En construcción (%d%%) · Obreros: %d"
static var PANEL_EDIFICIO_MATERIALES_RESTANTES: String = "Materiales restantes: %s"
static var PANEL_EDIFICIO_BTN_CANCELAR_TRASLADO: String = "Cancelar traslado del Núcleo (%d h restantes)"
static var PANEL_EDIFICIO_BTN_CANCELAR_DEMOLICION_PROG: String = "Cancelar demolición programada (%d h)"
static var PANEL_EDIFICIO_BTN_CANCELAR_DEMOLICION: String = "Cancelar demolición"
static var PANEL_EDIFICIO_MODAL_TITULO_REMODELAR: String = "Confirmar remodelación"
static var PANEL_EDIFICIO_MODAL_TEXTO_REMODELAR_NUCLEO: String = "El Núcleo Urbano pasará a edición libre. Podrás modificar sus bloques y volver a declararlo al terminar."
static var PANEL_EDIFICIO_MODAL_TEXTO_REMODELAR_SIN_TECHO: String:
	get:
		return "Al remodelar este edificio, %%d colono(s) no tendrán cama libre y quedarán sin techo (%d h de tolerancia antes de irse)." % Ajustes.CIUDAD_TOLERANCIA_SIN_TECHO_HORAS
static var PANEL_EDIFICIO_MODAL_TEXTO_REMODELAR_REUBICADOS: String = "Los residentes actuales se reubicarán en las camas libres de la ciudad mientras editas la estructura."
static var PANEL_EDIFICIO_MODAL_TITULO_TRASLADO: String = "Confirmar traslado del Núcleo"
static var PANEL_EDIFICIO_MODAL_TEXTO_TRASLADO_DEFICIT: String:
	get:
		return "El traslado tardará %d horas. Atención: el nuevo edificio tiene menor capacidad que el antiguo y %%d colono(s) podrían ser desahuciados." % Ajustes.CIUDAD_HORAS_TRASLADO_NUCLEO
static var PANEL_EDIFICIO_MODAL_TEXTO_TRASLADO_OK: String:
	get:
		return "El traslado tardará %d horas. El antiguo Núcleo pasará a ser residencial y los colonos intercambiarán sus hogares automáticamente." % Ajustes.CIUDAD_HORAS_TRASLADO_NUCLEO
static var PANEL_EDIFICIO_MODAL_TITULO_DEMOLER: String = "Programar demolición"
static var PANEL_EDIFICIO_MODAL_TEXTO_DEMOLER: String:
	get:
		return "La demolición se programará para iniciar dentro de %d horas de simulación (puedes cancelarla antes de que empiece)." % Ajustes.OBRAS_HORAS_PROGRAMADAS
static var PANEL_EDIFICIO_NOTIF_REMODELACION_INICIADA: String = "Remodelación iniciada."
static var PANEL_EDIFICIO_ERR_REMODELACION: String = "No se pudo iniciar remodelación: %s"


# ==============================================================================
# PANEL DE CANALIZACIÓN Y PANEL DE LÁMPARA
# ==============================================================================
static var PANEL_CANALIZACION_TITULO_ACUEDUCTO: String = "Acueducto"
static var PANEL_CANALIZACION_TITULO_TUBERIA: String = "Tubería Industrial"
static var PANEL_CANALIZACION_SUBTITULO_RED: String = "Red de canalización #%d"
static var PANEL_CANALIZACION_SECCION_FLUJO: String = "ESTADO Y FLUJO"
static var PANEL_CANALIZACION_SECCION_ESTRUCTURA: String = "ESTRUCTURA"
static var PANEL_CANALIZACION_SECCION_CONEXIONES: String = "PUERTOS CONECTADOS"
static var PANEL_CANALIZACION_FLUJO_ACTIVO: String = "Flujo activo (Red cerrada)"
static var PANEL_CANALIZACION_DERRAME_ACTIVO: String = "Derrame activo en %d punto(s)"
static var PANEL_CANALIZACION_EXTREMO_ABIERTO: String = "Extremo abierto (%d sin conectar)"
static var PANEL_CANALIZACION_EN_ESPERA: String = "En espera (Sin flujo)"
static var PANEL_CANALIZACION_FLUIDO_ESTADO: String = "Fluido: %s\nEstado: %s"
static var PANEL_CANALIZACION_LONGITUD_SOPORTES: String = "Longitud: %d bloques de ducto\nSoportes: %d bloques de columna"
static var PANEL_CANALIZACION_SIN_PUERTOS: String = "Ningún edificio conectado a esta red."
static var PANEL_CANALIZACION_PUERTO_ITEM: String = "• %s (%s de %s) — %s"

static var PANEL_LAMPARA_TITULO: String = "Lámpara"
static var PANEL_LAMPARA_SUBTITULO: String = "Iluminación"
static var PANEL_LAMPARA_SECCION_ESTADO: String = "ESTADO Y SUMINISTRO"
static var PANEL_LAMPARA_CONECTADA_RED: String = "Conectada a la red eléctrica (Generación activa)"
static var PANEL_LAMPARA_USANDO_BATERIA: String = "Usando batería de respaldo (%.0f%% - %.0f h restantes)"
static var PANEL_LAMPARA_SIN_ENERGIA: String = "Sin energía eléctrica ni batería"
static var PANEL_LAMPARA_ENCENDIDA_CON: String = "Encendida con %s"
static var PANEL_LAMPARA_APAGADA_SIN_SUMINISTRO: String = "Apagada (Sin suministro disponible)"
static var PANEL_LAMPARA_MODO_Y_RANGO: String = "Modo: %s · Rango: %d bloques"
static var PANEL_LAMPARA_BATERIA_Y_COMBUSTIBLE: String = "Batería: %.0f%% (%.1f / %.0f h)  |  Combustible: %.1f h"


# ==============================================================================
# VENTANAS DEL HUD (Almacén, Baúl, Energía, Moral, Ocupaciones, Población)
# ==============================================================================
static var VENTANA_ALMACEN_TITULO: String = "Almacén"
static var VENTANA_ALMACEN_RECURSO_CRITICO: String = "Recurso crítico: %s (%s/h)"
static var VENTANA_ALMACEN_TODO_ESTABLE: String = "Todo estable"

static var VENTANA_BAUL_TITULO_DEFECTO: String = "Baúl"
static var VENTANA_BAUL_SUBTITULO_DEPOSITO: String = "Depósito del puesto"
static var VENTANA_BAUL_COL_RECURSO: String = "Recurso"
static var VENTANA_BAUL_COL_PUESTO: String = "Puesto"
static var VENTANA_BAUL_COL_CIUDAD: String = "Ciudad"
static var VENTANA_BAUL_BTN_TOMAR_TOOLTIP: String:
	get:
		return "Tomar hasta %d del puesto al inventario" % int(Ajustes.VENTANA_BAUL_PASO_UNIDAD)
static var VENTANA_BAUL_BTN_CARGAR_TOOLTIP: String:
	get:
		return "Cargar hasta %d del inventario al puesto" % int(Ajustes.VENTANA_BAUL_PASO_UNIDAD)
static var VENTANA_BAUL_BTN_TOMAR_TODO: String = "Tomar todo"
static var VENTANA_BAUL_BTN_CARGAR_TODO: String = "Cargar todo"
static var VENTANA_BAUL_CAPACIDAD_PUESTO: String = "Capacidad del puesto: %d / %d"
static var VENTANA_BAUL_SIN_RECURSOS: String = "Sin recursos"

static var VENTANA_ENERGIA_TITULO: String = "Red Eléctrica"
static var VENTANA_ENERGIA_CAPACIDAD: String = "Capacidad instalada"
static var VENTANA_ENERGIA_DEMANDA: String = "Demanda conectada"
static var VENTANA_ENERGIA_ENTREGADA: String = "Energía entregada"
static var VENTANA_ENERGIA_COBERTURA: String = "Cobertura de red"
static var VENTANA_ENERGIA_UNIDADES_H: String = "%.1f u/h"
static var VENTANA_ENERGIA_ESTADO_DEFICIT: String = "Estado: DÉFICIT ELÉCTRICO (Producción reducida al %d%%)"
static var VENTANA_ENERGIA_ESTADO_SIN_DEMANDA: String = "Estado: Sin demanda activa"
static var VENTANA_ENERGIA_ESTADO_ESTABLE: String = "Estado: Suministro estable (100%)"
static var VENTANA_ENERGIA_SECCION_DESGLOSE: String = "Instalaciones conectadas:"
static var VENTANA_ENERGIA_CENTRAL_ACTIVA: String = "Activa"
static var VENTANA_ENERGIA_CENTRAL_SIN_PERSONAL_O_COMB: String = "Sin personal/comb."
static var VENTANA_ENERGIA_CENTRAL_DESCONECTADA: String = "Desconectada"
static var VENTANA_ENERGIA_CENTRAL_ITEM: String = "• Central Termoeléctrica (%s): %s"
static var VENTANA_ENERGIA_CONSUMIDOR_CONECTADO: String = "Conectado (-%.0f u/h)"
static var VENTANA_ENERGIA_CONSUMIDOR_DESCONECTADO: String = "Sin vía a la ciudad"
static var VENTANA_ENERGIA_CONSUMIDOR_ITEM: String = "• %s (%d op.): %s"
static var VENTANA_ENERGIA_SIN_INSTALACIONES: String = "Ninguna instalación eléctrica construida."

static var VENTANA_MORAL_TITULO: String = "Moral Ciudadana"
static var VENTANA_MORAL_VALOR_ESTADO: String = "%.1f / 100 (%s)"
static var VENTANA_MORAL_TENDENCIA: String = "%s%.2f pts/día"
static var VENTANA_MORAL_PRODUCTIVIDAD: String = "Productividad laboral: ×%.2f (%s%d%%)"
static var VENTANA_MORAL_MIGRACION_EXODO: String = "Éxodo (%d/mes)"
static var VENTANA_MORAL_MIGRACION_INMIGRACION: String = "+%.1f colonos/mes%s"
static var VENTANA_MORAL_MIGRACION_SIN_CAMAS: String = " (Faltan camas)"
static var VENTANA_MORAL_MIGRACION_DESBORDA: String = " (Desborda a sin techo)"
static var VENTANA_MORAL_FLUJO_MIGRATORIO: String = "Flujo migratorio: %s"
static var VENTANA_MORAL_SECCION_FACTORES: String = "Factores diarios activos:"
static var VENTANA_MORAL_FACTOR_INERCIA: String:
	get:
		return "• Inercia hacia neutral (%d): %%s%%.2f/día" % int(Ajustes.CIUDAD_MORAL_NEUTRAL)
static var VENTANA_MORAL_FACTOR_ALIMENTACION_OK: String:
	get:
		return "• Alimentación y variedad (%%d/%d): +%%.2f/día" % Ajustes.CIUDAD_CATEGORIAS_COMIDA.size()
static var VENTANA_MORAL_FACTOR_ESCASEZ: String = "• Escasez / Déficit de recursos: %.2f/día"
static var VENTANA_MORAL_FACTOR_EMPLEO: String = "• Nivel de empleo (%d%%): %s%.2f/día"
static var VENTANA_MORAL_FACTOR_SIN_TECHO: String:
	get:
		return "• Ciudadanos sin techo (%%d): %%.2f/día (%dh máx)" % Ajustes.CIUDAD_TOLERANCIA_SIN_TECHO_HORAS
static var VENTANA_MORAL_FACTOR_PELIGRO: String:
	get:
		return "• Peligrosidad reciente (%d días): %%.2f/día" % int(Ajustes.CIUDAD_VENTANA_PELIGRO_HORAS / 24.0)
static var VENTANA_MORAL_BTN_BOOST_ACTIVO: String = "Atractivo migratorio activo (%d d restantes)"
static var VENTANA_MORAL_BTN_BOOST_ACTIVAR: String:
	get:
		var mult_boost: String = str(int(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION)) if is_equal_approx(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION, roundf(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION)) else str(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION)
		return "Promover inmigración (×%s por %d días)" % [
			mult_boost,
			int(Ajustes.CIUDAD_HORAS_POR_MES / 24.0)
		]
static var VENTANA_MORAL_BTN_BOOST_BLOQUEADO_EXODO: String = "Boost no disponible: Éxodo migratorio activo"
static var VENTANA_MORAL_MIGRACION_EXODO_CEREBROS: String = "Migración: ⚠ Éxodo de cerebros (%d/mes)"
static var VENTANA_MORAL_MIGRACION_CON_CAMAS: String = "Migración: Inmigración con camas (%d/mes)"
static var VENTANA_MORAL_MIGRACION_MASIVA: String = "Migración: Inmigración masiva (%d/mes)"
static var VENTANA_MORAL_MIGRACION_BOOST_FORMATO: String = "Migración: %s (+%s/mes · Base %s ×%s)"
static var VENTANA_MORAL_BOOST_DETALLE_ACTIVO: String = "⚡ Boost activo: +%s/mes (Base %s ×%s) · %d d restantes"
static var VENTANA_MORAL_BOOST_DETALLE_BLOQUEADO: String = "Boost bloqueado: la moral actual produce emigración"
static var VENTANA_MORAL_BOOST_DETALLE_DISPONIBLE: String:
	get:
		var mult_boost: String = str(int(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION)) if is_equal_approx(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION, roundf(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION)) else str(Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION)
		return "Atractivo migratorio disponible (×%s por %d días)" % [
			mult_boost,
			int(Ajustes.CIUDAD_HORAS_POR_MES / 24.0)
		]
static func formatear_numero(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)):
		return str(int(valor))
	return "%.1f" % valor
static var VENTANA_MORAL_TENDENCIA_DIA: String = "Tendencia: %+.2f / día"
static var VENTANA_MORAL_PRODUCTIVIDAD_X: String = "Productividad laboral: %.2fx"
static var VENTANA_MORAL_FACTOR_INERCIA_FORMATO: String:
	get:
		return "• Tendencia natural al equilibrio (%d%%%%): %%+.2f/día" % int(Ajustes.CIUDAD_MORAL_NEUTRAL)

static var VENTANA_OCUPACIONES_TITULO: String = "Ocupaciones y Puestos"
static var VENTANA_OCUPACIONES_RESUMEN_LIBRES: String = "Libres: %d Desemp. · %d Téc. · %d Esp. · %d Inv."
static var VENTANA_OCUPACIONES_SIN_PUESTOS: String = "No hay puestos de trabajo activos."
static var VENTANA_OCUPACIONES_ESTADO_AGOTADO: String = " [Agotado]"
static var VENTANA_OCUPACIONES_ESTADO_FALTA_INSUMO: String = " [Falta insumo]"
static var VENTANA_OCUPACIONES_PUESTO_TRABAJADORES: String = "%d/%d trab.%s"
static var VENTANA_OCUPACIONES_BTN_IR_TOOLTIP: String = "Centrar cámara y abrir panel del puesto"

static var VENTANA_POBLACION_TITULO: String = "Población"
static var VENTANA_POBLACION_DESCRIPCION_NIVEL: Dictionary:
	get:
		var n1_p: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(1, {}).get("pisos", 2)
		var n1_c: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(1, {}).get("camas_por_piso", 2)
		var n2_p: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(2, {}).get("pisos", 4)
		var n2_c: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(2, {}).get("camas_por_piso", 4)
		var n3_p: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(3, {}).get("pisos", 8)
		var n3_c: int = Ajustes.CIUDAD_NIVELES_VIVIENDA.get(3, {}).get("camas_por_piso", 4)
		return {
			1: "Nivel 1 — Asentamiento Primitivo (máx. %d pisos, %d camas/piso)" % [n1_p, n1_c],
			2: "Nivel 2 — Villa Industrial (máx. %d pisos, %d camas/piso)" % [n2_p, n2_c],
			3: "Nivel 3 — Metrópoli Automatizada (máx. %d pisos, %d camas/piso)" % [n3_p, n3_c],
		}

static var VENTANA_POBLACION_ROLES: Array:
	get:
		var roles: Array = []
		var defs: Array = [
			["ciudadano", "Ciudadanos"],
			["desempleado", "Desempleados"],
			["obrero", "Obreros"],
			["tecnico", "Técnicos"],
			["especialista", "Especialistas"],
			["investigador", "Investigadores"],
			["militar", "Militares"],
		]
		for item in defs:
			var rol_id: String = item[0]
			var plural: String = item[1]
			var x_cama: int = Ajustes.CIUDAD_TIPOS_POBLACION.get(rol_id, {}).get("x_cama", 1)
			var texto_cama: String = "1 cama" if x_cama == 1 else "1/%d cama" % x_cama
			roles.append([rol_id, plural, texto_cama])
		return roles

static var VENTANA_POBLACION_FILA_SIN_TECHO: String:
	get:
		return "Sin techo (%dh máx)" % Ajustes.CIUDAD_TOLERANCIA_SIN_TECHO_HORAS
static var VENTANA_POBLACION_FILA_SIN_CAMA: String = "Sin cama"
static var VENTANA_POBLACION_FILA_TOTAL: String = "Total habitantes"
static var VENTANA_POBLACION_VIVIENDA: String = "Vivienda ocupada: %.2f / %d camas (%.2f libres)"
static var VENTANA_POBLACION_SOFISTICACION: String = "Sofisticación: %.2f (Potencial Nv. %d · Investigado Nv. %d)"
static var VENTANA_POBLACION_INSTALACIONES: String = "Instalaciones: Nv.1: %d · Nv.2: %d · Nv.3: %d"
static var VENTANA_POBLACION_BTN_OCUPACIONES: String = "Gestionar ocupaciones y puestos..."


# ==============================================================================
# JUGADOR, LÁMPARAS, CÁMARA CENITAL Y NOTIFICACIONES EN PARTIDA
# ==============================================================================
static var LAMPARA_NOMBRES_MODO: Dictionary = {
	"electrica": "Eléctrica",
	"combustible": "Combustible",
	"carbon": "Carbón",
	"madera": "Madera",
}

static var NOTIF_NUEVO_COLONO: String = "Nuevo colono en la ciudad."
static var NOTIF_TECNICOS_FORMADOS: String = "Se formaron %d técnicos."
static var NOTIF_RECURSO_MENOS_5_PCT: String = "Queda menos del 5%% de %s."

static var PLAYER_NOTIF_STOCK_DEBUG: String:
	get:
		return "[DEBUG] Stock inicial de prueba cargado (1000 por recurso, %d comida)." % int(Ajustes.CIUDAD_COMIDA_INICIAL)
static var PLAYER_NOTIF_MADERA_RECOGIDA: String = "+%d madera"
static var PLAYER_NOTIF_MADERA_ALMACEN_LLENO: String = "+%d madera (almacén lleno, se perdió %d)"
static var PLAYER_NOTIF_BAUL_NO_PUESTO: String = "Este baúl no pertenece a un puesto de trabajo con depósito activo."
static var PLAYER_NOTIF_ARBOL_SIN_FRUTOS: String = "Este árbol no tiene frutos disponibles todavía."
static var PLAYER_NOTIF_FRUTOS_RECOLECTADOS: String = "Has recolectado %s de comida."
static var PLAYER_MODO_DECONSTRUIR_TITULO: String = "Deconstruir"
static var PLAYER_MODO_DECONSTRUIR_INSTRUCCIONES: String = "(clic izq.) DECONSTRUIR\n(clic der.) MARCAR PARA DEMOLICIÓN\n[G] Salir del modo deconstrucción"
static var PLAYER_MODO_VIAS_TITULO: String = "Vías"
static var PLAYER_MODO_VIAS_INSTRUCCIONES: String = "(clic izq.) CONSTRUIR VÍA\n(clic der.) DEMOLER VÍA\n[V] Salir del modo vías"
static var PLAYER_NOTIF_SIN_OBRA_VIA: String = "No hay ninguna obra de vía pendiente en esa celda."
static var PLAYER_NOTIF_VIA_COMPLETADA: String = "Vía completada."
static var PLAYER_NOTIF_SIN_VIA_CONSTRUIDA: String = "No hay ninguna vía construida en esa celda."
static var PLAYER_NOTIF_SIN_EDIFICIO_PARA_MARCAR: String = "No hay ningún edificio ahí para marcar."
static var PLAYER_NOTIF_EDIFICIO_MARCADO_DEMOLICION: String = "Edificio marcado para demolición."
static var PLAYER_NOTIF_MARCA_DEMOLICION_QUITADA: String = "Marca de demolición quitada."
static var PLAYER_NOTIF_MODO_DECONSTRUCCION_BLOQUEA: String = "Modo Deconstrucción activo: no se puede %s. Pulsa G para salir."
static var PLAYER_ACCION_MINAR_NI_TALAR: String = "minar ni talar"
static var PLAYER_NOTIF_OBRA_OCUPADA: String = "Hay alguien dentro del sitio de la obra %d: deben salir antes de iniciarla."
static var PLAYER_NOTIF_FALTA_MATERIAL_OBRA: String = "No hay suficiente %s para continuar la obra."
static var PLAYER_NOTIF_COLOCAR_SOBRE_JUGADOR: String = "No se puede colocar un bloque donde está parado el jugador."
static var PLAYER_NOTIF_SIN_ESPACIO_COLOCAR: String = "No hay espacio suficiente para colocar: %s"
static var PLAYER_NOTIF_FALTA_MATERIAL_COLOCAR: String = "No hay suficiente %s para colocar: %s"
static var PLAYER_ERR_SIN_VESTIBULO_EXTERNO: String = "ninguna puerta externa tiene un vestíbulo libre para entrar."
static var PLAYER_OBJETO_UNA_CAMA: String = "Una cama"
static var PLAYER_OBJETO_UN_BAUL: String = "Un baúl"
static var PLAYER_ERR_SIN_CAMINO_A_PUERTA: String = "%s no tiene un camino transitable hasta ninguna puerta externa."
static var PLAYER_NOTIF_DECLARAR_APUNTA_PUERTA: String = "Declarar edificio: apunta a la puerta principal de la estructura."
static var PLAYER_NOTIF_DECLARAR_YA_DECLARADO: String = "Declarar edificio: ese edificio ya fue declarado."
static var PLAYER_NOTIF_DECLARAR_PUERTA_NO_JUGADOR: String = "Declarar edificio: esa puerta no fue colocada por el jugador."
static var PLAYER_NOTIF_DECLARAR_FORMATO: String = "Declarar edificio: %s"
static var PLAYER_NOTIF_REMODELAR_APUNTA_PUERTA: String = "Remodelar edificio: apunta a la puerta principal de la estructura."
static var PLAYER_NOTIF_REMODELAR_NO_DECLARADO: String = "Remodelar edificio: esa estructura no es un edificio declarado."
static var PLAYER_NOTIF_REMODELAR_NO_TERMINADO: String = "Remodelar edificio: solo se pueden remodelar edificios terminados."
static var PLAYER_NOTIF_REMODELACION_INICIADA: String = "Remodelación iniciada."
static var PLAYER_NOTIF_REMODELAR_FORMATO: String = "Remodelar edificio: %s"
static var PLAYER_ERR_NO_SE_PUDO_REMODELAR: String = "no se pudo remodelar."
static var PLAYER_NOTIF_SIN_ENERGIA_LAMPARA: String = "Sin energía ni combustible para la lámpara"

static var CAMARA_MENSAJES_BASE_Y: Dictionary = {
	"pendiente": "Colocación rechazada: el desnivel entre una puerta y el suelo frente a ella supera el límite permitido.",
	"puertas": "Colocación rechazada: las puertas de este edificio quedarían a niveles distintos (el suelo frente a cada una tiene otra altura).",
	"frente": "Colocación rechazada: el suelo frente a una puerta es agua o queda fuera del mundo.",
}

static var CAMARA_DISTANCIA_AL_NUCLEO: String = "🧭 Distancia al núcleo: %d celdas"
static var CAMARA_RECHAZO_PREFIJO: String = "Colocación rechazada: "
static var CAMARA_RECHAZO_FORMATO: String = "Colocación rechazada: %s"
static var CAMARA_RECHAZO_BLUEPRINT_ZONA: String = "Colocación rechazada: esta zona no acepta este blueprint."
static var CAMARA_RECHAZO_BLUEPRINT_PENDIENTE: String = "Colocación rechazada: la pendiente de esta huella (o del frente de sus puertas) supera el límite permitido."
static var CAMARA_RECHAZO_BLUEPRINT_HUELLA_OCUPADA: String = "Colocación rechazada: la huella choca con un recurso de madera o una estructura existente."
static var CAMARA_RECHAZO_BLUEPRINT_FRENTE_OCUPADO: String = "Colocación rechazada: el frente de una puerta choca con un recurso de madera o una estructura existente."
static var CAMARA_RECHAZO_BLUEPRINT_CHOCA_PUESTO: String = "Colocación rechazada: la huella (o el frente de una puerta) choca con un puesto o construcción ya colocada."
static var CAMARA_RECHAZO_BLUEPRINT_SIN_TIERRA: String = "Colocación rechazada: la huella necesita al menos una columna sobre tierra firme."

static var CAMARA_ATAJO_ROTAR: String = "[Ctrl+scroll] ROTAR"
static var CAMARA_ATAJO_COLOCAR: String = "(clic izq.) COLOCAR"
static var CAMARA_ATAJO_SALIR: String = "[Esc] SALIR"
static var CAMARA_REQ_ESCUELA_TECNICA: String = "Requiere al menos 1 Escuela técnica construida."
static var CAMARA_REQ_ESCUELA_ESPECIALISTAS: String = "Requiere al menos 1 Escuela de especialistas construida."
static var CAMARA_REQ_METALURGIA_APLICADA: String = "Requiere Metalurgia Aplicada."
static var CAMARA_NOTIF_SIN_BLUEPRINT: String = "No hay ningún blueprint guardado todavía — declara un edificio primero."

static var CAMARA_MODO_TRAZAR_VIA_TITULO: String = "Trazar vía"
static var CAMARA_ATAJO_FIJAR_PUNTO: String = "(clic izq.) FIJAR PUNTO"
static var CAMARA_ATAJO_DOBLE_CLIC_CONFIRMAR: String = "(doble clic) CONFIRMAR"
static var CAMARA_ATAJO_CLIC_DER_CANCELAR: String = "(clic der.) CANCELAR"
static var CAMARA_NOTIF_DUCTO_PUNTOS_MINIMOS: String = "Trazado incompleto: requiere al menos 2 puntos."
static var CAMARA_NOTIF_DUCTO_TRAZADO_INVALIDO: String = "Trazado inválido."
static var CAMARA_NOTIF_DUCTO_FALTA_MATERIAL: String = "Materiales insuficientes para construir el trazado."
static var CAMARA_NOTIF_DUCTO_ERROR_CONSTRUIR: String = "Error al construir canalización."
static var CAMARA_NOTIF_CANALIZACION_CONSTRUIDA: String = "Canalización construida."

static var CAMARA_MODO_DEMOLER_TITULO: String = "Demoler"
static var CAMARA_ATAJO_MARCAR_DEMOLICION: String = "(clic izq.) MARCAR PARA DEMOLICIÓN"
static var CAMARA_ATAJO_CONFIRMAR_AREA: String = "(clic izq.) CONFIRMAR ÁREA"
static var CAMARA_ATAJO_FIJAR_ESQUINA: String = "(clic izq.) FIJAR ESQUINA"
static var CAMARA_ZONIFICACION_TITULO_FORMATO: String = "Zonificación: %s"
static var CAMARA_ZONA_BORRAR: String = "Borrar"
static var CAMARA_ZONA_RESIDENCIAL: String = "Zona Residencial"
static var CAMARA_ZONA_INDUSTRIAL: String = "Zona Industrial"
static var CAMARA_ZONA_CAT_RESIDENCIAL: String = "Categorías permitidas: Residencial, Investigación"
static var CAMARA_ZONA_CAT_INDUSTRIAL: String = "Categorías permitidas: Industrial"

static var CAMARA_MODO_DEMOLER_VIA_TITULO: String = "Demoler Vía"
static var CAMARA_ATAJO_RECORRER_VIA: String = "(mover) RECORRER VÍA"
static var CAMARA_ATAJO_ELEGIR_RAMA: String = "(clic izq.) ELEGIR RAMA"
static var CAMARA_ATAJO_DOBLE_CLIC_DEMOLER: String = "(doble clic) CONFIRMAR DEMOLICIÓN"
static var CAMARA_NOTIF_EDIFICIO_MARCADO_DEMOLICION: String = "Edificio marcado para demolición."
static var CAMARA_NOTIF_MARCA_DEMOLICION_QUITADA: String = "Marca de demolición quitada."
static var CAMARA_NOTIF_NADA_PARA_DEMOLER: String = "No hay ningún edificio ni vía ahí para demoler."
static var CAMARA_NOTIF_ORDEN_DEMOLICION_VIA: String = "Orden de demolición de vía enviada."
static var CAMARA_NOTIF_SIN_ZONA_INFLUENCIA: String = "Todavía no existe una zona de influencia — declara tu primer edificio residencial primero."
static var CAMARA_NOTIF_VIA_SIN_RUTA: String = "Trazado rechazado: no hay ruta posible hasta ese punto."
static var CAMARA_NOTIF_VIA_CHOCA: String = "Trazado rechazado: choca con un edificio, puesto u obra existente."
static var CAMARA_NOTIF_OBRA_VIA_PLANIFICADA: String = "Obra de vía planificada."

static var CAMARA_RECHAZO_PUESTO_REQ_ESC_TECNICA: String = "Colocación rechazada: requiere al menos 1 escuela técnica construida."
static var CAMARA_RECHAZO_PUESTO_REQ_ESC_ESPEC: String = "Colocación rechazada: requiere al menos 1 escuela de especialistas construida."
static var CAMARA_RECHAZO_PUESTO_BOMBEO_AGUA: String:
	get:
		return "Colocación rechazada: la estación de bombeo requiere al menos %d bloques de profundidad de agua bajo su muelle." % Ajustes.RECOLECCION_PROFUNDIDAD_MINIMA_EXTRACCION
static var CAMARA_RECHAZO_PUESTO_SIN_POZO: String = "Colocación rechazada: no se detecta depósito subterráneo de agua o crudo."
static var CAMARA_RECHAZO_PUESTO_EN_INFLUENCIA: String = "No se puede colocar un puesto dentro de la zona de influencia."
static var CAMARA_NOMBRE_UNA_UNIVERSIDAD: String = "una universidad"
static var CAMARA_NOMBRE_UNA_ESCUELA: String = "una escuela"
static var CAMARA_NOMBRE_UN_ALMACEN: String = "un almacén"
static var CAMARA_NOMBRE_UNA_CENTRAL: String = "una central termoeléctrica"
static var CAMARA_NOMBRE_UNA_REFINERIA: String = "una refinería"
static var CAMARA_RECHAZO_PUESTO_SOLO_EN_INFLUENCIA: String = "Colocación rechazada: %s solo puede construirse dentro de la zona de influencia."
static var CAMARA_RECHAZO_PUESTO_SOLO_ZONA_RES: String = "Colocación rechazada: %s solo puede construirse sobre una zona residencial."
static var CAMARA_RECHAZO_PUESTO_SOLO_ZONA_IND: String = "Colocación rechazada: una refinería, central o almacén solo puede construirse sobre una zona industrial."
static var CAMARA_RECHAZO_PUESTO_PENDIENTE_HUELLA: String = "Colocación rechazada: la pendiente de esta huella supera el límite permitido."
static var CAMARA_RECHAZO_PUESTO_CHOCA: String = "Colocación rechazada: la huella choca con un puesto ya colocado."
static var CAMARA_RECHAZO_PUESTO_PESCA_EXTREMOS: String = "Colocación rechazada: la huella necesita un extremo completo sobre agua (con su periferia despejada) y el opuesto completo sobre tierra firme."
static var CAMARA_RECHAZO_PUESTO_PENDIENTE_PUERTA: String = "Colocación rechazada: la pendiente de la huella (o del frente de la puerta) supera el límite permitido."
static var CAMARA_RECHAZO_PUESTO_FRENTE_RECURSO: String = "Colocación rechazada: el frente de la puerta choca con un recurso de madera o una estructura existente."
static var CAMARA_RECHAZO_PUESTO_FRENTE_PUESTO: String = "Colocación rechazada: el frente de la puerta choca con un puesto o construcción ya colocada."
static var CAMARA_RECHAZO_PUESTO_HUELLA_RECURSO: String = "Colocación rechazada: la huella choca con un recurso de madera o una estructura existente."
static var CAMARA_RECHAZO_PUESTO_SIN_TIERRA: String = "Colocación rechazada: la huella necesita al menos una columna sobre tierra firme."


# ==============================================================================
# MUNDO, VALIDADOR DE BLUEPRINTS, OBRAS Y FINALIZACIÓN DE OBRAS
# ==============================================================================
static var MUNDO_DESPEJE_MURO_EN_VECINO: String = "Un bloque de muro, puerta o vidrio nuevo cae dentro del espacio reservado de un edificio vecino."
static var MUNDO_DESPEJE_VIDRIO_INVALIDO: String = "Un vidrio no tiene el espacio libre exigido hacia afuera."
static var MUNDO_DESPEJE_PUERTO_INVALIDO: String = "Un puerto de tubería no tiene el espacio libre exigido hacia afuera."
static var MUNDO_DESPEJE_PUERTA_INVALIDO: String = "Una puerta no tiene el espacio libre exigido hacia afuera."
static var MUNDO_DESPEJE_CAMA_LADO_INVALIDO: String = "Una cama no tiene un lado despejado para levantarse (debe ser el mismo lado junto a la cabecera y junto a los pies)."
static var MUNDO_DESPEJE_CAMA_ALTURA_INVALIDA: String:
	get:
		return "Una cama no tiene las %d celdas libres exigidas por encima de uno de sus extremos." % Ajustes.MUNDO_DESPEJE_ALTURA_CAMA

static var BLUEPRINT_ORDINALES: Array = ["primer", "segundo", "tercer", "cuarto", "quinto", "sexto", "séptimo", "octavo", "noveno", "décimo"]
static var BLUEPRINT_PISO_ORDINAL_FORMATO: String = "%s piso"
static var BLUEPRINT_PISO_NUMERO_FORMATO: String = "piso %d"
static var BLUEPRINT_FALTA_UN_FORMATO: String = "falta un %s"
static var BLUEPRINT_FALTAN_VARIOS_FORMATO: String = "faltan %d %s"
static var BLUEPRINT_NOMBRE_RESIDENCIA_FORMATO: String = "Residencia %dx%d"
static var BLUEPRINT_ERR_HUECO_PARED: String = "El %s tiene un hueco en la pared cerca de (%d, %d): ahí hay '%s', que no cierra el perímetro."
static var BLUEPRINT_ERR_ESQUINA_NO_PARED: String = "La esquina (%d, %d) del %s debe ser una pared, no '%s'."
static var BLUEPRINT_ERR_FALTA_SUELO: String = "Al %s le falta un suelo sólido debajo."
static var BLUEPRINT_ERR_FALTA_TECHO: String = "Al %s le falta un techo sólido encima."
static var BLUEPRINT_ERR_PISO_MUY_BAJO: String = "El %s es muy bajo (%d bloque(s) de alto); necesita al menos %d."
static var BLUEPRINT_ERR_FALTA_PUERTA: String = "Falta una puerta en el %s."
static var BLUEPRINT_ERR_FALTA_VENTANA: String = "Falta una ventana en el %s."
static var BLUEPRINT_ERR_PUERTA_SIN_ESPACIO_2D: String = "El %s tiene una puerta sin espacio libre justo detrás."
static var BLUEPRINT_ERR_PUERTA_SIN_ESPACIO_3D: String = "Al %s le falta espacio libre justo detrás de una puerta."
static var BLUEPRINT_ERR_EXCEDE_PISOS: String = "Esta casa tiene %d piso(s), pero el nivel actual de la ciudad solo permite %d por casa."
static var BLUEPRINT_ERR_EXCEDE_CAMAS_POR_PISO: String = "El %s tiene %d cama(s), pero el nivel actual solo permite %d por piso."
static var BLUEPRINT_ERR_SIN_CAMAS: String = "Este edificio no tiene ninguna cama."
static var BLUEPRINT_ERR_FALTAN_BAULES: String = "Hay %s y %s: %s."
static var BLUEPRINT_ERR_ZONA_PERMITIDA_INVALIDA: String = "zona_permitida inválida o ausente: '%s'"
static var BLUEPRINT_ERR_ZONA_DESTINO_INCORRECTA: String = "'%s' es para la zona %s; no se puede colocar en %s."
static var BLUEPRINT_ERR_EVOLUCION_HUELLA: String = "Piso %d de la nueva versión excede la huella de la planta base original"
static var BLUEPRINT_ERR_PERSONALIZACION_HUELLA: String = "La personalización modificó la huella del edificio de producción"
static var BLUEPRINT_ERR_PERSONALIZACION_CONEXIONES: String = "La personalización modificó el número de conexiones (entradas/salidas)"
static var BLUEPRINT_ERR_VOLUMEN_NO_SELLADO: String = "El edificio no tiene ningún volumen interior sellado: hay una fuga hacia afuera o no hay ningún espacio interior."

static var CIUDAD_ERR_NO_RESIDENCIAL_NI_NUCLEO: String = "El edificio no es residencial ni núcleo."

static var OBRAS_ERR_NO_ES_EDIFICIO: String = "Eso no es un edificio."
static var OBRAS_ERR_NUCLEO_NO_DEMOLIBLE: String = "El núcleo urbano no se puede demoler."
static var OBRAS_AVISO_DEMOLICION_INICIADA: String = "Demolición iniciada."
static var OBRAS_AVISO_FALTA_MATERIAL: String = "Obra detenida: falta %s."
static var OBRAS_NOMBRE_EDIFICIO_FORMATO: String = "Edificio %d"
static var OBRAS_TIPO_EDIFICIO: String = "Edificio"
static var OBRAS_TIPO_PUESTO: String = "Puesto"
static var OBRAS_AVISO_EDIFICIO_DEMOLIDO: String = "Edificio demolido."
static var OBRAS_AVISO_VIA_COMPLETADA: String = "Vía completada."
static var OBRAS_AVISO_TRAMO_VIA_DEMOLIDO: String = "Tramo de vía demolido."

static var FINALIZACION_AVISO_EDIFICIO_CONSTRUIDO: String = "Edificio construido: %s."
static var FINALIZACION_AVISO_PUESTO_REACTIVADO: String = "Puesto reactivado."
static var FINALIZACION_AVISO_NUCLEO_DECLARADO: String = "Núcleo urbano declarado."
static var FINALIZACION_NOMBRE_EDIFICIO_RESIDENCIAL: String = "Edificio residencial"
static var FINALIZACION_ERR_EDIFICIO_NO_EXISTE: String = "El edificio no existe."
static var FINALIZACION_NOMBRE_EL_NUCLEO: String = "el núcleo urbano"
static var FINALIZACION_NOMBRE_EL_EDIFICIO_ID: String = "el edificio %d"
static var FINALIZACION_AVISO_REMODELACION_INICIADA: String = "Remodelación iniciada para %s: ahora en edición libre."
static var FINALIZACION_AVISO_REMODELACION_SIN_TECHO: String = " (%d colono(s) sin techo)."

static var VIAS_NOMBRE_TIERRA_PISADA: String = "Vía de tierra pisada"
static var VIAS_TEXTO_SI: String = "Sí"
static var VIAS_TEXTO_NO: String = "No"
static var VIAS_TEXTO_NA: String = "N/A"
static var VIAS_COSTO_POR_CELDA_FORMATO: String = "%s/celda"
static var VIAS_FICHA_TECNICA_FORMATO: String = "%s\nRecursos: %s\nVelocidad: %s\nTransmisión de energía: %s\nTránsito vehicular: %s"

static var CANALIZACIONES_NOMBRE_ACUEDUCTO: String = "Acueducto"
static var CANALIZACIONES_NOMBRE_TUBERIA: String = "Tubería"
static var CANALIZACIONES_FICHA_TECNICA_FORMATO: String:
	get:
		return "%%s\nFluidos: %%s\nMateriales: %%s\nDespeje: %d bloques\nColumnas: cada %d bloques" % [
			Ajustes.CANALIZACIONES_ALTURA_DESPEJE,
			Ajustes.CANALIZACIONES_INTERVALO_COLUMNAS
		]
static var CANALIZACIONES_ERR_TRAMO_VACIO: String = "Tramo vacío."
static var CANALIZACIONES_ERR_INVADE_PUERTO: String = "Trazado inválido: la tubería invade el espacio reservado del puerto de %s."


# ==============================================================================
# INVESTIGACIÓN DESCENTRALIZADA, PACING DE ERAS (IDU) Y DOCTRINAS
# ==============================================================================
static var ERA_NOMBRES: Dictionary = {
	1: "Era 1: Asentamiento Pionero",
	2: "Era 2: Manufactura Temprana",
	3: "Era 3: Industrialización Plena",
	4: "Era 4: Doctrina Cúspide",
}

static var DOCTRINA_NOMBRES: Dictionary = {
	"dieselpunk": "Dieselpunk",
	"cyberpunk": "Cyberpunk",
	"solarpunk": "Solarpunk",
	"polivalente": "Polivalente",
}

static var PROYECTO_BTN_INSTALAR: String = "Instalar Mejora"
static var PROYECTO_ESTADO_ESPERANDO_PERSONAL: String = "Esperando personal científico"
static var PROYECTO_ESTADO_EN_EJECUCION: String = "Investigación aplicada en curso"
static var PROYECTO_AVISO_INSTALADO: String = "Mejora instalada: %s."

static var RECONVERSION_BTN_INICIAR: String = "Iniciar Reconversión Industrial"
static var RECONVERSION_ESTADO_EN_CURSO: String = "Reconversión industrial en curso"
static var RECONVERSION_AVISO_COMPLETADA: String = "Reconversión completada: %s."
static var RECONVERSION_ERR_MISMA_DOCTRINA: String = "El edificio ya cuenta con esa doctrina."
static var RECONVERSION_TOOLTIP: String = "Sustituye la especialización doctrinal del edificio con una tasa de reforma del 50% de materiales de mejora y 25% del costo base."

static var BARRA_SUPERIOR_ERA_FORMATO: String = "Era %d"
static var BARRA_SUPERIOR_IDU_FORMATO: String = "IDU: %.2f"
static var BARRA_SUPERIOR_IDU_TOOLTIP_FORMATO: String = "Índice de Desarrollo Urbano: %.2f\nSofisticación Infraestructura (S): %.2f\nCualificación Laboral (Q): %.2f\nMasa Crítica Ciencia (K): %.2f"

# ==============================================================================
# LOGÍSTICA Y UNIDADES DE TRANSPORTE
# ==============================================================================
static var TRANSPORTE_NOMBRES: Dictionary = {
	"acarreador_pie": "Acarreador a Pie",
	"carreta_mano": "Carreta de Mano",
	"carro_caballos": "Carro de Tiro (Caballos)",
	"camion_diesel": "Camión Pesado Diésel",
	"dron_carga": "Dron Autónomo de Carga",
	"trolebus_solar": "Trolebús Eléctrico Bio-Vía",
}

static var TRANSPORTE_ESTADOS: Dictionary = {
	"NORMAL": "Normal",
	"RALENTIZADO": "Ralentizado (Sin insumos)",
	"BLOQUEADO": "Bloqueado (Requiere vía continua)",
	"normal": "Normal",
	"ralentizado": "Ralentizado (Sin insumos)",
	"bloqueado": "Bloqueado (Requiere vía continua)",
}

static var TRANSPORTE_ESTADO_RALENTIZADO: String = "Ralentizado (Sin insumos)"
static var TRANSPORTE_ESTADO_BLOQUEADO: String = "Bloqueado (Requiere vía continua)"
static var TRANSPORTE_AVISO_BLOQUEO_VIA: String = "Ruta bloqueada: el vehículo requiere una vía afirmada continua."




# ==============================================================================
# DICCIONARIO MULTI-IDIOMA Y RESOLUCIÓN DINÁMICA POR `Ajustes.idioma`
# ==============================================================================
static var TRADUCCIONES: Dictionary = {
	"es": {},
}


## Obtiene un valor de texto para el idioma activo en `Ajustes.idioma`,
## cayendo al valor estático en español si aún no existe traducción.
static func t(clave: String) -> Variant:
	var lang: String = Ajustes.idioma
	if TRADUCCIONES.has(lang) and (TRADUCCIONES[lang] as Dictionary).has(clave):
		return TRADUCCIONES[lang][clave]
	return null
