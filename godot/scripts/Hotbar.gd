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

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
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
	"mesa_estudio": "Mesa de estudio",
}

const NOMBRES_EN := {
	"tierra": "Dirt",
	"adobe": "Adobe block",
	"bloque_madera": "Wood block",
	"bloque_piedra": "Stone block",
	"estructura_hierro": "Iron structure",
	"bloque_acero": "Steel block",
	"vidrio": "Glass",
	"puerta": "Door",
	"cama": "Bed",
	"baul": "Chest",
	"mesa_estudio": "Study table",
}

## Título corto de cada casilla de la hotbar (decisión del usuario
## 2026-09-30: la casilla usa una palabra corta aunque no sea el nombre real
## del bloque, p. ej. "bloque_madera" se ve "Madera" — el nombre completo
## sigue en la tarjeta emergente, vía NOMBRES/nombre_de()).
static var NOMBRES_HOTBAR: Dictionary = Strings.HOTBAR_NOMBRES

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

static var TAMANO_ICONO: float = float(Ajustes.MINIATURA_TAMANO)

var _fila := HBoxContainer.new()
var _casillas: Array = []  # de {"contenedor", "caja", "nombre", "cantidad", "valor": int}
var _seleccionada := 0
var _tipos: Array = []
var _tipos_bloques_guardados: Array = []
var _modo_especial := false
var _items_especiales: Array = []

## Copia propia (CACHE_MODE_IGNORE) de la MeshLibrary, independiente de la
## que usa VoxelWorld en el mundo: VoxelWorld._indexar_biblioteca() vacía en
## el sitio la malla de "puerta_inferior"/"puerta_superior" (su lámina la
## da Puertas.gd) — como load() normalmente cachea por ruta, sin esto la
## hotbar podría heredar esa mutación y quedarse sin ícono de puerta según
## el orden de inicialización.
var _biblioteca: MeshLibrary
var _cache_iconos := {}


static func nombre_de(tipo: String) -> String:
	var ajustes = preload("res://scripts/ajustes.gd")
	if ajustes.idioma == "en":
		return NOMBRES_EN.get(tipo, NOMBRES.get(tipo, tipo.capitalize()))
	return NOMBRES.get(tipo, tipo.capitalize())


static func nombre_hotbar_de(tipo: String) -> String:
	return Strings.HOTBAR_NOMBRES.get(tipo, nombre_de(tipo))


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
		var piezas: Array = []
		var panel := BoxMesh.new()
		panel.size = Vector3(1.0, 1.0, 0.05)
		piezas.append([panel, Vector3.ZERO, MATERIAL_VENTANA])
		return piezas
	if tipo == "puerta":
		var piezas: Array = []
		var lamina := BoxMesh.new()
		lamina.size = PuertasScript.LAMINA
		var material_lamina := StandardMaterial3D.new()
		material_lamina.albedo_color = PuertasScript.COLOR_LAMINA
		piezas.append([lamina, Vector3.ZERO, material_lamina])
		# Picaporte dorado
		var picaporte := BoxMesh.new()
		picaporte.size = Vector3(0.08, 0.12, 0.16)
		var mat_pica := StandardMaterial3D.new()
		mat_pica.albedo_color = Color(0.85, 0.7, 0.2)
		piezas.append([picaporte, Vector3(0.3, 0.0, 0.0), mat_pica])
		# Bisagras oscuras
		var bisagra := BoxMesh.new()
		bisagra.size = Vector3(0.04, 0.15, 0.14)
		var mat_bis := StandardMaterial3D.new()
		mat_bis.albedo_color = Color(0.15, 0.15, 0.15)
		piezas.append([bisagra, Vector3(-0.38, 0.5, 0.0), mat_bis])
		piezas.append([bisagra, Vector3(-0.38, -0.5, 0.0), mat_bis])
		return piezas
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
	if Configuracion != null:
		Configuracion.configuracion_cambiada.connect(_on_configuracion_cambiada)


func _on_configuracion_cambiada(clave: String, _valor: Variant) -> void:
	if clave == "idioma":
		actualizar_textos()


func actualizar_textos() -> void:
	if _modo_especial:
		for i in range(_casillas.size()):
			if i < _items_especiales.size():
				var item: Dictionary = _items_especiales[i]
				var lbl_esp: Label = _casillas[i]["nombre"]
				if lbl_esp != null:
					var nk: String = str(item.get("nombre_key", ""))
					lbl_esp.text = Strings.t(nk) if nk != "" else str(item.get("nombre", ""))
		return
	for i in range(_casillas.size()):
		if i < _tipos.size():
			var tipo: String = _tipos[i]
			var lbl: Label = _casillas[i]["nombre"]
			if lbl != null:
				lbl.text = nombre_hotbar_de(tipo)


func configurar(tipos: Array) -> void:
	_tipos = tipos
	_tipos_bloques_guardados = tipos.duplicate()
	_modo_especial = false
	_items_especiales.clear()
	var entradas: Array = []
	for t in tipos:
		var tipo: String = str(t)
		entradas.append({"nombre": nombre_hotbar_de(tipo), "icono": icono_de(tipo)})
	_reconstruir_casillas(entradas)


func configurar_modo_especial(items: Array) -> void:
	_modo_especial = true
	_items_especiales = items.duplicate()
	_tipos = []
	var entradas: Array = []
	for item in items:
		var d: Dictionary = item
		var nk: String = str(d.get("nombre_key", ""))
		var txt: String = Strings.t(nk) if nk != "" else str(d.get("nombre", ""))
		entradas.append({"nombre": txt, "icono": d.get("icono", null)})
	_reconstruir_casillas(entradas)


func restaurar_bloques() -> void:
	if not _tipos_bloques_guardados.is_empty():
		configurar(_tipos_bloques_guardados.duplicate())


func _reconstruir_casillas(entradas: Array) -> void:
	for casilla in _casillas:
		var cont: Control = casilla["contenedor"]
		if cont.get_parent() == _fila:
			_fila.remove_child(cont)
		cont.queue_free()
	_casillas.clear()
	for i in range(entradas.size()):
		var entrada: Dictionary = entradas[i]
		var contenedor := VBoxContainer.new()
		contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor.add_theme_constant_override("separation", 2)

		var nombre := TemaHUD.etiqueta(str(entrada.get("nombre", "")))
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.autowrap_mode = TextServer.AUTOWRAP_OFF if _modo_especial else TextServer.AUTOWRAP_WORD
		nombre.custom_minimum_size.x = maxf(TAMANO_ICONO, 68.0) if _modo_especial else TAMANO_ICONO
		contenedor.add_child(nombre)

		var caja := PanelContainer.new()
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.custom_minimum_size = Vector2(TAMANO_ICONO, TAMANO_ICONO)
		caja.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var icono := TextureRect.new()
		icono.texture = entrada.get("icono", null)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(icono)

		var esquinas := Control.new()
		esquinas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(esquinas)

		var tecla := TemaHUD.etiqueta(str((i + 1) % 10))
		tecla.add_theme_font_size_override("font_size", 12)
		tecla.add_theme_color_override("font_color", TemaHUD.DORADO)
		esquinas.add_child(tecla)
		TemaHUD.poner_en_esquina_inferior(tecla, false, TemaHUD.MARGEN_CONTENIDO)

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
	if visible and not _modo_especial:
		actualizar_cantidades()


## Pone en cada casilla floor(stock del recurso / costo por bloque); oculta
## el número (cantidad -1) en los tipos sin costo definido en
## NiveladorTerreno.COSTO_POR_CELDA.
func actualizar_cantidades() -> void:
	if _modo_especial:
		return
	for i in range(_tipos.size()):
		var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(_tipos[i], {})
		if costo.is_empty():
			set_cantidad(i, -1)
			continue
		var minimo := 999999
		for recurso in costo:
			var stock: float = Ciudad.almacen[recurso].cantidad
			if recurso == "madera" and Ciudad.almacen.has("tablas"):
				stock += Ciudad.almacen["tablas"].cantidad  # las tablas cuentan como madera (Ciudad.consumir_costo)
			elif recurso == "piedra" and Ciudad.almacen.has("bloques_piedra"):
				stock += Ciudad.almacen["bloques_piedra"].cantidad  # los bloques de piedra cuentan como piedra
			elif recurso == "vidrio" and Ciudad.almacen.has("tierra"):
				stock = Ciudad.almacen["vidrio"].cantidad + floorf(Ciudad.almacen["tierra"].cantidad / 3.0)  # 1 ventana = 1 vidrio o 3 tierra
			var disponible: int = int(stock / costo[recurso])
			minimo = mini(minimo, disponible)
		set_cantidad(i, minimo)


func seleccionar(indice: int) -> void:
	if indice < 0 or indice >= _casillas.size():
		return
	if _seleccionada != indice:
		Sonidos.reproducir("sfx_ui_hotbar_slot", -4.0, 0.05)
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
		var estilo := TemaHUD.caja(TemaHUD.VERDE_CLARO, Ajustes.COLOR_HUD_HOTBAR_SELECCION_BORDE) if seleccionada else TemaHUD.caja()
		_casillas[i]["caja"].add_theme_stylebox_override("panel", estilo)
		_casillas[i]["nombre"].add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE if seleccionada else TemaHUD.TEXTO)
		_casillas[i]["cantidad"].add_theme_color_override("font_color", GRIS_CLARO if seleccionada else GRIS_OSCURO)
