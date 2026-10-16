extends RefCounted
class_name IconosHUD

## Catálogo y gestor centralizado de íconos vectoriales del HUD.
## Carga perezosa de texturas SVG y generador de etiquetas BBCode.

const RUTA_BASE := "res://assets/icons/"

static var _cache: Dictionary = {}

## Diccionario de alias semánticos hacia el nombre de archivo SVG
const MAPA_ICONOS := {
	# Recursos
	"comida": "comida.svg",
	"madera": "madera.svg",
	"tablas": "tablas.svg",
	"tierra": "tierra.svg",
	"piedra": "piedra.svg",
	"bloques_piedra": "bloques_piedra.svg",
	"hierro": "hierro.svg",
	"cobre": "cobre.svg",
	"carbon": "carbon.svg",
	"tierras_raras": "tierras_raras.svg",
	"acero": "acero.svg",
	"mineral_refinado": "mineral_refinado.svg",
	"agua": "agua.svg",
	"crudo": "crudo.svg",
	"combustible": "combustible.svg",

	# Demografía y Oficios
	"censo": "censo.svg",
	"ciudadano": "ciudadano.svg",
	"desempleado": "desempleado.svg",
	"obrero": "obrero.svg",
	"recolector": "obrero.svg",
	"tecnico": "tecnico.svg",
	"especialista": "especialista.svg",
	"investigador": "investigador.svg",
	"militar": "militar.svg",
	"aprendiz": "aprendiz.svg",
	"acarreador": "acarreador.svg",
	"sin_techo": "sin_techo.svg",
	"cama": "cama.svg",
	"baul": "baul.svg",

	# Barra superior y estados
	"almacen": "almacen.svg",
	"moral_critica": "moral_critica.svg",
	"moral_baja": "moral_baja.svg",
	"moral_neutra": "moral_neutra.svg",
	"moral_alta": "moral_alta.svg",
	"energia_dorado": "energia_dorado.svg",
	"energia_gris": "energia_gris.svg",
	"energia_rojo": "energia_rojo.svg",
	"tasa_arriba": "tasa_arriba.svg",
	"tasa_neutra": "tasa_neutra.svg",
	"tasa_abajo": "tasa_abajo.svg",
	"romano_1": "romano_1.svg",
	"romano_2": "romano_2.svg",
	"romano_3": "romano_3.svg",
	"alerta": "alerta.svg",
	"era": "era.svg",

	# Modos y submenús cenitales
	"modo_ver": "modo_ver.svg",
	"modo_construir": "modo_construir.svg",
	"modo_zonificar": "modo_zonificar.svg",
	"modo_demoler": "modo_demoler.svg",
	"cat_residencial": "cat_residencial.svg",
	"cat_periferico": "cat_periferico.svg",
	"cat_industrial": "cat_industrial.svg",
	"cat_investigacion": "cat_investigacion.svg",
	"cat_vias": "cat_vias.svg",
	"cat_ductos": "cat_ductos.svg",
	"zona_residencial": "zona_residencial.svg",
	"zona_industrial": "zona_industrial.svg",
	"zona_borrar": "zona_borrar.svg",

	# 1ª Persona y Lámpara
	"lampara_electrica_on": "lampara_electrica_on.svg",
	"lampara_electrica_off": "lampara_electrica_off.svg",
	"lampara_termica_on": "lampara_termica_on.svg",
	"lampara_termica_off": "lampara_termica_off.svg",
	"bateria": "bateria.svg",
	"reloj_arena": "reloj_arena.svg",
	"oxigeno": "oxigeno.svg",
	"herr_pico": "herr_pico.svg",
	"herr_pala": "herr_pala.svg",
	"herr_hacha": "herr_hacha.svg",
	"herr_cesta": "herr_cesta.svg",
	"herr_mazo": "herr_mazo.svg",
	"herr_vias": "herr_vias.svg",

	# Navegación y ratón
	"click_izq": "click_izq.svg",
	"click_der": "click_der.svg",
	"scroll": "scroll.svg",
	"mouse_move": "mouse_move.svg",
	"check": "check.svg",
	"cruz": "cruz.svg",
	"brujula": "brujula.svg",
	"ojo": "ojo.svg",

	# Ventanas y factores
	"edificio_engranaje": "edificio_engranaje.svg",
	"corazon_civico": "corazon_civico.svg",
	"productividad": "productividad.svg",
	"balanza": "balanza.svg",
	"cornucopia_llena": "cornucopia_llena.svg",
	"cornucopia_vacia": "cornucopia_vacia.svg",
	"escudo_agrietado": "escudo_agrietado.svg",
	"enchufe_verde": "enchufe_verde.svg",
	"enchufe_rojo": "enchufe_rojo.svg",
	"central_termoelectrica": "central_termoelectrica.svg",
	"ayuntamiento": "ayuntamiento.svg",
	"asignar_nucleo": "asignar_nucleo.svg",

	# Edificio y puesto
	"puerta_abierta": "puerta_abierta.svg",
	"puerta_candado": "puerta_candado.svg",
	"puerta_reloj": "puerta_reloj.svg",
	"candado": "candado.svg",
	"remodelar": "remodelar.svg",
	"prio_baja": "prio_baja.svg",
	"prio_normal": "prio_normal.svg",
	"prio_alta": "prio_alta.svg",
	"tec_metalurgia": "tec_metalurgia.svg",
	"tec_automatizacion": "tec_automatizacion.svg",

	# Botones de acción y LEDs
	"btn_mas": "btn_mas.svg",
	"btn_menos": "btn_menos.svg",
	"btn_pausa": "btn_pausa.svg",
	"btn_play": "btn_play.svg",
	"extraer_todo": "extraer_todo.svg",
	"led_verde": "led_verde.svg",
	"led_gris": "led_gris.svg",
	"led_rojo": "led_rojo.svg",
}


static func ruta(clave: String) -> String:
	if MAPA_ICONOS.has(clave):
		return RUTA_BASE + MAPA_ICONOS[clave]
	if clave.ends_with(".svg"):
		return RUTA_BASE + clave
	return ""


static func icono(clave: String) -> Texture2D:
	if clave == "":
		return null
	if _cache.has(clave):
		return _cache[clave]

	var r := ruta(clave)
	if r == "" or not FileAccess.file_exists(r):
		return null

	var tex: Texture2D = null
	if FileAccess.file_exists(r + ".import"):
		tex = load(r) as Texture2D

	if tex == null:
		var ruta_global := ProjectSettings.globalize_path(r)
		var img := Image.load_from_file(ruta_global)
		if img != null:
			tex = ImageTexture.create_from_image(img)

	if tex != null:
		_cache[clave] = tex
	return tex


static func bbcode(clave: String, tamano: int = 16) -> String:
	var r := ruta(clave)
	if r == "":
		return ""
	return "[img=%dx%d]%s[/img]" % [tamano, tamano, r]


## Crea un TextureRect configurado listo para añadir a la UI.
static func crear_rect(clave: String, tamano: Variant = 16) -> TextureRect:
	var tam: Vector2
	if tamano is Vector2:
		tam = tamano
	elif tamano is int or tamano is float:
		tam = Vector2(float(tamano), float(tamano))
	else:
		tam = Vector2(16, 16)
	var tr := TextureRect.new()
	tr.texture = icono(clave)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = tam
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func icono_recurso(recurso: String) -> String:
	return recurso.to_lower()


static func icono_demografia(tipo: String) -> String:
	match tipo.to_lower():
		"ciudadano": return "ciudadano"
		"desempleado": return "desempleado"
		"obrero", "recolector": return "obrero"
		"tecnico": return "tecnico"
		"especialista": return "especialista"
		"investigador": return "investigador"
		"militar": return "militar"
		"aprendiz": return "aprendiz"
		"acarreador": return "acarreador"
		_: return "ciudadano"


## Mapeo helper para estado de moral a clave de ícono
static func icono_moral(moral: float) -> String:
	if moral <= 20.0:
		return "moral_critica"
	elif moral < 35.0:
		return "moral_baja"
	elif moral < 65.0:
		return "moral_neutra"
	else:
		return "moral_alta"


## Mapeo helper para tasa de cambio
static func icono_tasa(tasa: float) -> String:
	if tasa > 0.05:
		return "tasa_arriba"
	elif tasa < -0.05:
		return "tasa_abajo"
	else:
		return "tasa_neutra"


## Mapeo de números romanos para niveles (1, 2, 3)
static func icono_nivel_romano(nivel: int) -> String:
	match nivel:
		1: return "romano_1"
		2: return "romano_2"
		3: return "romano_3"
		_: return "romano_1"


## Mapeo helper para herramienta de progreso según acción de minado
static func icono_herramienta_minado(tipo_bloque: String) -> String:
	match tipo_bloque:
		"tierra", "adobe":
			return "herr_pala"
		"madera":
			return "herr_hacha"
		"piedra", "hierro", "cobre", "carbon", "tierras_raras":
			return "herr_pico"
		_:
			return "herr_mazo"
