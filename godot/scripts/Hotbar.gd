extends PanelContainer

## Hotbar de 1ª persona: una casilla por tipo de bloque (teclas 1-N), con la
## seleccionada resaltada. Cada casilla admite una cantidad opcional: cuántos
## bloques de ese tipo todavía se pueden colocar con el stock actual del
## almacén central. Se autoactualiza en _process() mientras esté visible,
## mismo patrón que VentanaAlmacen.gd/BarraSuperior.gd (sin depender de que
## Player.gd/HUD.gd la llamen en su propio refresco).
##
## El ícono de cada casilla es un render en vivo (ver _renderizar_icono())
## de la malla y el material reales del ítem de assets/BlockLibrary.res: no
## es un dibujo aparte, así que si cambia el material/textura de un bloque
## (o el paquete de texturas completo) el ícono lo refleja solo, sin
## mantener un segundo set de imágenes sincronizado. Antes se usaba
## MeshLibrary.get_item_preview(), pero esa vista previa solo la genera el
## editor: en una build headless/exportada siempre da null (comprobado en
## pruebas 2026-09-30) — de ahí las casillas sin ícono reportadas.

const TemaHUD = preload("res://scripts/TemaHUD.gd")
const NiveladorTerrenoScript = preload("res://scripts/NiveladorTerreno.gd")
const MiniaturaRendererScript = preload("res://scripts/MiniaturaRenderer.gd")

## Nombre completo/real de cada bloque: aparece en el título de la tarjeta
## emergente (PanelContextual.mostrar_bloque_temporal()).
const NOMBRES := {
	"tierra": "Tierra",
	"adobe": "Bloque de adobe",
	"bloque_madera": "Bloque de madera",
	"bloque_piedra": "Bloque de piedra",
	"estructura_hierro": "Estructura de hierro",
	"bloque_acero": "Bloque de acero",
	"vidrio": "Vidrio",
	"puerta": "Puerta",
	"cama": "Cama",
	"baul": "Baúl",
}

## Título corto de cada casilla de la hotbar (decisión del usuario
## 2026-09-30: la casilla usa una palabra corta aunque no sea el nombre real
## del bloque, p. ej. "bloque_madera" se ve "Madera" — el nombre completo
## sigue en la tarjeta emergente, vía NOMBRES/nombre_de()).
const NOMBRES_HOTBAR := {
	"tierra": "Tierra",
	"adobe": "Adobe",
	"bloque_madera": "Madera",
	"bloque_piedra": "Piedra",
	"estructura_hierro": "Estructura",
	"bloque_acero": "Acero",
	"vidrio": "Vidrio",
	"puerta": "Puerta",
	"cama": "Cama",
	"baul": "Baúl",
}

## Tipos cuyo bloque es un objeto interactuable ya colocado (ver
## Player._interactuar()): su tarjeta emergente suma una pista de "E" a las
## acciones, además de "COLOCAR (clic der.)".
const TIPOS_INTERACTIVOS := ["puerta", "cama", "baul"]

## Tipo, uso ideal y método de obtención de cada bloque para la tarjeta
## emergente (PanelContextual.mostrar_bloque_temporal()). El método de
## obtención respeta el costo real de NiveladorTerreno.COSTO_POR_CELDA (p.
## ej. vidrio cuesta tierra, no arena: no existe ese recurso en el juego).
const DESCRIPCION := {
	"tierra": ["Bloque de tipo no estructural.", "Ideal para relleno de terreno y nivelación.", "Se obtiene cavando hierba o tierra."],
	"adobe": ["Bloque de tipo estructural.", "Ideal para cimientos y muros básicos.", "Se obtiene compactando tierra."],
	"bloque_madera": ["Bloque de tipo estructural.", "Ideal para muros, pisos y techos.", "Se obtiene talando árboles."],
	"bloque_piedra": ["Bloque de tipo estructural.", "Ideal para muros resistentes y cimientos.", "Se obtiene minando piedra."],
	"estructura_hierro": ["Bloque de tipo estructural.", "Ideal para refuerzos y estructuras de carga.", "Se obtiene minando y fundiendo hierro."],
	"bloque_acero": ["Bloque de tipo estructural.", "Ideal para estructuras pesadas y muros blindados.", "Se obtiene refinando hierro en una siderúrgica."],
	"vidrio": ["Bloque de tipo estructural translúcido.", "Ideal para ventanas e iluminación natural.", "Se obtiene fundiendo tierra."],
	"puerta": ["Objeto de tipo funcional.", "Entrada y salida de edificaciones y espacios cerrados.", "Se fabrica con madera."],
	"cama": ["Objeto de tipo funcional.", "Descanso de colonos; requisito de todo edificio residencial.", "Se fabrica con madera."],
	"baul": ["Objeto de tipo funcional.", "Almacenamiento de materiales junto a un puesto.", "Se fabrica con madera."],
}

## "cama" son 2 celdas reales de BlockLibrary (ver VoxelWorld.colocar_cama()):
## el ícono junta ambas, con el mismo desfase relativo que se usa al
## colocarla, para mostrar el objeto completo en vez de solo una mitad.
const ITEM_ICONO_COMPUESTO := {
	"cama": [["cama_cabecera", Vector3.ZERO], ["cama_pies", Vector3.RIGHT]],
}

## "vidrio" tiene malla vacía a propósito en BlockLibrary (GridMap solo lo
## usa para ocupación/colisión; lo dibuja TranslucidosRenderer con este
## material — ver TranslucidosRenderer.gd) así que su ícono no puede salir
## de la biblioteca: se arma con un cubo genérico y el material real.
const MATERIAL_VENTANA := preload("res://assets/mat_ventana.tres")

## "puerta" tampoco sale de BlockLibrary: sus celdas puerta_inferior/
## puerta_superior tienen malla vacía a propósito (igual que vidrio/agua —
## Puertas.gd dibuja la lámina real, no GridMap). El ícono viejo mostraba el
## bloque de 2 celdas que YA NO se ve en el juego (reporte del usuario
## 2026-09-30); ahora arma la lámina real con las mismas medidas y color que
## Puertas.gd — ver Puertas.LAMINA/COLOR_LAMINA.
const PuertasScript = preload("res://scripts/Puertas.gd")

const TAMANO_ICONO := 64.0

var _fila := HBoxContainer.new()
var _casillas: Array = []  # de {"contenedor", "caja", "nombre", "cantidad", "valor": int}
var _seleccionada := 0
var _tipos: Array = []

## Copia propia (CACHE_MODE_IGNORE) de la MeshLibrary, independiente de la
## que usa VoxelWorld en el mundo: VoxelWorld._indexar_biblioteca() vacía en
## el sitio la malla de "puerta_inferior"/"puerta_superior" (su lámina la
## da Puertas.gd) — como load() normalmente cachea por ruta, sin esto la
## hotbar podría heredar esa mutación y quedarse sin ícono de puerta según
## el orden de inicialización.
var _biblioteca: MeshLibrary
var _cache_iconos := {}


static func nombre_de(tipo: String) -> String:
	return NOMBRES.get(tipo, tipo.capitalize())


static func nombre_hotbar_de(tipo: String) -> String:
	return NOMBRES_HOTBAR.get(tipo, nombre_de(tipo))


static func descripcion_de(tipo: String) -> Array:
	return DESCRIPCION.get(tipo, ["", "", ""])


## Ícono en miniatura (render en vivo) del bloque/objeto real que representa
## "tipo", o null si no tiene ninguna malla que mostrar. Se cachea por tipo:
## no hace falta volver a renderizar en cada configurar().
func icono_de(tipo: String) -> Texture2D:
	if _cache_iconos.has(tipo):
		return _cache_iconos[tipo]
	var piezas := _piezas_de_icono(tipo)
	var textura: Texture2D = _renderizar_icono(piezas) if not piezas.is_empty() else null
	_cache_iconos[tipo] = textura
	return textura


## Piezas (malla, posición relativa, material o null para el real del ítem)
## que arman el ícono de "tipo": una sola para la mayoría, las 2 celdas
## reales de ITEM_ICONO_COMPUESTO para cama (el objeto completo, no solo una
## mitad), un cubo genérico con MATERIAL_VENTANA para vidrio, y la lámina
## real (medidas y color de Puertas.gd) para puerta.
func _piezas_de_icono(tipo: String) -> Array:
	if tipo == "vidrio":
		var cubo := BoxMesh.new()
		cubo.size = Vector3.ONE
		return [[cubo, Vector3.ZERO, MATERIAL_VENTANA]]
	if tipo == "puerta":
		var lamina := BoxMesh.new()
		lamina.size = PuertasScript.LAMINA
		var material_lamina := StandardMaterial3D.new()
		material_lamina.albedo_color = PuertasScript.COLOR_LAMINA
		return [[lamina, Vector3.ZERO, material_lamina]]
	if ITEM_ICONO_COMPUESTO.has(tipo):
		var piezas: Array = []
		for par in ITEM_ICONO_COMPUESTO[tipo]:
			var malla: Mesh = _malla_de_item(par[0])
			if malla != null:
				piezas.append([malla, par[1], null])
		return piezas
	var malla_simple: Mesh = _malla_de_item(tipo)
	return [[malla_simple, Vector3.ZERO, null]] if malla_simple != null else []


## Malla real del ítem "nombre_item" en la copia propia de BlockLibrary (ver
## _biblioteca), o null si no existe/no tiene malla (p. ej. vidrio).
func _malla_de_item(nombre_item: String) -> Mesh:
	if _biblioteca == null:
		_biblioteca = MiniaturaRendererScript.cargar_biblioteca()
	return MiniaturaRendererScript.malla_de_item(_biblioteca, nombre_item)


func _renderizar_icono(piezas: Array) -> Texture2D:
	return MiniaturaRendererScript.renderizar(piezas, Vector3(1, 1, 1), self)


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -12.0
	_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fila.add_theme_constant_override("separation", 6)
	add_child(_fila)


func configurar(tipos: Array) -> void:
	_tipos = tipos
	for casilla in _casillas:
		casilla["contenedor"].queue_free()
	_casillas.clear()
	for i in range(tipos.size()):
		var tipo: String = tipos[i]
		var contenedor := VBoxContainer.new()
		contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor.add_theme_constant_override("separation", 2)

		# Título corto (nombre_hotbar_de(), no el real): envuelve en 2 líneas
		# si hace falta, ya no desincroniza el margen del panel contextual
		# porque HUD.set_vista() lo calcula del alto real de la hotbar, no de
		# una constante fija.
		var nombre := TemaHUD.etiqueta(nombre_hotbar_de(tipo))
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.autowrap_mode = TextServer.AUTOWRAP_WORD
		nombre.custom_minimum_size.x = TAMANO_ICONO
		contenedor.add_child(nombre)

		var caja := PanelContainer.new()
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.custom_minimum_size = Vector2(TAMANO_ICONO, TAMANO_ICONO)

		var icono := TextureRect.new()
		icono.texture = icono_de(tipo)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(icono)

		# PanelContainer fuerza a TODOS sus hijos directos a ocupar su rect
		# completo en cada sort (fit_child_in_rect), pisando cualquier ancla
		# propia — por eso tecla/cantidad NO quedaban ancladas a las esquinas
		# (se veían centradas verticalmente, reporte 2026-09-30). Un Control
		# simple (no un Container) sí respeta las anclas de SUS hijos, así
		# que tecla/cantidad van dentro de este en vez de directo en "caja".
		var esquinas := Control.new()
		esquinas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(esquinas)

		# Acceso directo, esquina inferior izquierda, color del borde (dorado).
		var tecla := TemaHUD.etiqueta(str((i + 1) % 10))
		tecla.add_theme_font_size_override("font_size", 12)
		tecla.add_theme_color_override("font_color", TemaHUD.DORADO)
		esquinas.add_child(tecla)
		TemaHUD.poner_en_esquina_inferior(tecla, false, TemaHUD.MARGEN_CONTENIDO)  # "esquinas" queda dentro del margen interno de la caja

		# Disponibilidad, esquina inferior derecha (color según selección, ver _resaltar()).
		var cantidad := TemaHUD.etiqueta()
		cantidad.visible = false
		esquinas.add_child(cantidad)
		TemaHUD.poner_en_esquina_inferior(cantidad, true, TemaHUD.MARGEN_CONTENIDO)

		contenedor.add_child(caja)
		_fila.add_child(contenedor)
		_casillas.append({"contenedor": contenedor, "caja": caja, "nombre": nombre, "cantidad": cantidad, "valor": -1})
	_seleccionada = 0
	_resaltar()


func _process(_delta: float) -> void:
	if visible:
		actualizar_cantidades()


## Pone en cada casilla floor(stock del recurso / costo por bloque); oculta
## el número (cantidad -1) en los tipos sin costo definido en
## NiveladorTerreno.COSTO_POR_CELDA.
func actualizar_cantidades() -> void:
	for i in range(_tipos.size()):
		var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(_tipos[i], {})
		if costo.is_empty():
			set_cantidad(i, -1)
			continue
		var minimo := 999999
		for recurso in costo:
			var disponible: int = int(Ciudad.almacen[recurso].cantidad / costo[recurso])
			minimo = mini(minimo, disponible)
		set_cantidad(i, minimo)


func seleccionar(indice: int) -> void:
	if indice < 0 or indice >= _casillas.size():
		return
	_seleccionada = indice
	_resaltar()


func indice_seleccionado() -> int:
	return _seleccionada


## "cantidad" < 0 oculta el número de la casilla.
func set_cantidad(indice: int, cantidad: int) -> void:
	if indice < 0 or indice >= _casillas.size():
		return
	_casillas[indice]["valor"] = cantidad
	var etiqueta: Label = _casillas[indice]["cantidad"]
	etiqueta.visible = cantidad >= 0
	etiqueta.text = str(cantidad)


func cantidad_visible(indice: int) -> bool:
	return _casillas[indice]["cantidad"].visible


## Último valor puesto por set_cantidad()/actualizar_cantidades(), o -1 si
## el tipo no tiene costo definido (ver PanelContextual.mostrar_bloque_temporal()).
func cantidad_de(indice: int) -> int:
	if indice < 0 or indice >= _casillas.size():
		return -1
	return _casillas[indice]["valor"]


## Disponibilidad: gris claro en la casilla activa, gris oscuro en las inactivas.
const GRIS_CLARO := Color(0.82, 0.82, 0.82)
const GRIS_OSCURO := Color(0.42, 0.42, 0.42)


func _resaltar() -> void:
	for i in range(_casillas.size()):
		var seleccionada := i == _seleccionada
		var estilo := TemaHUD.caja(TemaHUD.VERDE_CLARO, Color(1.0, 0.8, 0.3)) if seleccionada else TemaHUD.caja()
		_casillas[i]["caja"].add_theme_stylebox_override("panel", estilo)
		_casillas[i]["nombre"].add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if seleccionada else TemaHUD.TEXTO)
		_casillas[i]["cantidad"].add_theme_color_override("font_color", GRIS_CLARO if seleccionada else GRIS_OSCURO)
