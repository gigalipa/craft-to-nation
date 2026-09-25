# HUD por modos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el HUD de texto por un HUD visual por modos: barra superior con datos de `Ciudad`, barra de modos y panel contextual en la cenital, hotbar 1–6 y panel contextual en primera persona.

**Architecture:** Cuatro widgets `Control` pequeños (`BarraSuperior`, `PanelContextual`, `BarraModos`, `Hotbar`) más un helper de estilo (`TemaHUD`). `HUD.gd` los crea y sigue siendo el único punto de contacto de `Player.gd` y `CamaraCenital.gd`, con una API nueva (`mostrar_contexto`, `set_modo`, `set_tipo_hotbar`, `set_vista`) que reemplaza las etiquetas de modo y las cuatro fichas de puesto.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), pruebas por escena `*Test.tscn` con `assert()`.

**Spec:** `docs/superpowers/specs/2026-09-25-hud-por-modos-design.md`

## Global Constraints

- Godot 4.7; GDScript indentado con **tabulaciones**.
- Conservar el español en mensajes, comentarios y pruebas.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- Ningún atajo de teclado cambia: 1ª persona 1–6, G, B, E; cenital Z, V, B, M/H/L/F, Esc. Los clics de la barra llaman a las mismas funciones que las teclas.
- Se conservan sin cambios: `PanelPuesto`, barra de progreso, oxígeno, ficha de materiales (solo se reubican sus offsets).
- No tocar el GDD ni `README.md`: tienen cambios sin commitear del usuario. Al final se le avisa qué línea añadir.
- Verificación (CLAUDE.md, y solo las escenas afectadas): `godot/scenes/HUDTest.tscn` y `godot/scenes/Test.tscn`, más ejecutar `Main.tscn` a mano. Confirmar que todas las aserciones pasan.

## Review Focus

- Almacén de `Ciudad` sin alguna clave de la barra superior → mostrar `0`, no fallar (Task 1).
- Moral negativa o por encima de `Ciudad.BONO_MORAL_MAXIMO` → la barra se acota a 0–1 (Task 1).
- Panel contextual sin costo ni línea extra (zonas, vías, deconstruir) → esas filas quedan ocultas, sin líneas vacías (Task 2).
- Botón de modo pulsado cuyo modo no llega a activarse (p. ej. Construir sin blueprint guardado) → la barra vuelve a reflejar el modo real (Task 3).
- Índice de hotbar fuera de rango → se ignora sin error (Task 3).
- Cambio directo entre puestos (M → H) y `salir_de_todos_los_modos()` al volver a 1ª persona → resaltado y panel coherentes, sin restos del modo anterior (Task 4, verificación manual).

## Desviaciones respecto a la spec (se documentan en Task 5)

- El estilo común son helpers estáticos en `TemaHUD.gd`, no un recurso `Theme`.
- La tira de 4 puestos se despliega bajo el botón Puestos de la barra vertical (no sobre el panel contextual).
- No hay miniatura en el panel contextual (no hay arte). `valido` es tri-estado (`true`/`false`/`null` = no aplica).

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `godot/scripts/TemaHUD.gd` (nuevo) | Colores y `StyleBoxFlat` del estilo verde/dorado, etiqueta y botón estilizados |
| `godot/scripts/BarraSuperior.gd` (nuevo) | Recursos, población, moral, nivel; lee `Ciudad` |
| `godot/scripts/PanelContextual.gd` (nuevo) | Ítem activo: nombre, costo, acciones, validez, línea extra |
| `godot/scripts/BarraModos.gd` (nuevo) | Botones de modo (cenital) + subtira de puestos; señales de clic |
| `godot/scripts/Hotbar.gd` (nuevo) | Casillas 1–6 de 1ª persona |
| `godot/scripts/HUD.gd` (reescrito) | Fachada: crea los widgets, expone la API, conserva progreso/oxígeno/materiales/PanelPuesto |
| `godot/scripts/HUDTest.gd`, `godot/scenes/HUDTest.tscn` (nuevos) | Pruebas de los widgets y formateadores |
| `godot/scenes/Main.tscn` | Se eliminan los nodos del HUD antiguo; se reubican Materiales y Oxígeno |
| `godot/scripts/Main.gd` | Avisa `hud.set_vista()` al alternar cámara |
| `godot/scripts/CamaraCenital.gd` | Cambia las llamadas antiguas del HUD por la API nueva |
| `godot/scripts/Player.gd` | Hotbar y panel contextual en 1ª persona |
| `godot/scripts/PanelPuesto.gd` | `offset_top` 12 → 72 (para no tapar la barra superior) |

---

### Task 1: TemaHUD y BarraSuperior

**Files:**
- Create: `godot/scripts/TemaHUD.gd`
- Create: `godot/scripts/BarraSuperior.gd`
- Create: `godot/scripts/HUDTest.gd`
- Create: `godot/scenes/HUDTest.tscn`

**Interfaces:**
- Produces: `TemaHUD` (RefCounted, solo estáticos): constantes `VERDE`, `VERDE_CLARO`, `DORADO`, `TEXTO`, `VALIDO`, `INVALIDO` (Color); `caja(fondo: Color = VERDE, borde: Color = DORADO) -> StyleBoxFlat`; `aplicar_panel(panel: PanelContainer) -> void`; `etiqueta(texto: String = "") -> Label`; `estilizar_boton(boton: Button) -> void`.
- Produces: `BarraSuperior` (PanelContainer): `var recursos: Array` (claves de `Ciudad.almacen`, por defecto `["comida", "madera", "piedra", "hierro"]`); `static texto_poblacion(censo: int, camas: int) -> String`; `static fraccion_moral(bono: float) -> float`; `actualizar() -> void`; `texto_de(clave: String) -> String`; `moral_valor() -> float`. `_process` llama a `actualizar()`.

- [ ] **Step 1: Crear la escena y el script de pruebas (con la prueba de BarraSuperior)**

`godot/scenes/HUDTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/HUDTest.gd" id="1"]

[node name="HUDTest" type="Node"]
script = ExtResource("1")
```

`godot/scripts/HUDTest.gd`:

```gdscript
extends Node

## Pruebas de los widgets del HUD por modos (mismo patrón que PuertasTest.gd).
## Corre HUDTest.tscn y revisa el panel "Output": debe imprimir todas las
## pruebas y la línea final, sin ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md.

const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")


func _ready() -> void:
	ejecutar_pruebas()
	print("HUDTest: todas las pruebas pasaron")


func ejecutar_pruebas() -> void:
	probar_barra_superior()


func probar_barra_superior() -> void:
	print("=== TEST 1: BarraSuperior ===")
	assert(BarraSuperiorScript.texto_poblacion(38, 48) == "Población 38/48")
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO / 2.0) == 0.5)
	# Moral fuera de rango: la barra se acota a 0-1.
	assert(BarraSuperiorScript.fraccion_moral(-3.0) == 0.0)
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO * 4.0) == 1.0)

	var barra: PanelContainer = BarraSuperiorScript.new()
	# Una clave que no está en el almacén muestra 0 en vez de fallar.
	barra.recursos = ["comida", "inexistente"]
	add_child(barra)
	Ciudad.almacen["comida"].cantidad = 126.0
	barra.actualizar()
	assert(barra.texto_de("comida") == "Comida 126", "salió '%s'" % barra.texto_de("comida"))
	assert(barra.texto_de("inexistente") == "Inexistente 0", "salió '%s'" % barra.texto_de("inexistente"))
	barra.queue_free()
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

Run: ejecutar `res://scenes/HUDTest.tscn` con Godot 4.7 (`mcp__godot__run_project` con `scene: res://scenes/HUDTest.tscn` en `godot/`, luego `mcp__godot__get_debug_output`).
Expected: error de carga: `preload("res://scripts/BarraSuperior.gd")` no existe.

- [ ] **Step 3: Implementar `TemaHUD.gd`**

```gdscript
extends RefCounted

## Estilo común del HUD (verde oscuro con marco dorado, ver
## arte/conceptos-hud/). Solo estáticos: cada widget lo usa al construirse.

const VERDE := Color(0.05, 0.13, 0.10, 0.92)
const VERDE_CLARO := Color(0.13, 0.30, 0.21, 0.95)
const DORADO := Color(0.78, 0.62, 0.25)
const TEXTO := Color(0.95, 0.92, 0.82)
const VALIDO := Color(0.45, 0.90, 0.45)
const INVALIDO := Color(1.0, 0.35, 0.35)


static func caja(fondo: Color = VERDE, borde: Color = DORADO) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(8)
	return estilo


## Fondo del widget con marco dorado. No captura el ratón: los clics siguen
## llegando a la cámara salvo sobre los botones.
static func aplicar_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", caja())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func etiqueta(texto: String = "") -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", TEXTO)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


static func estilizar_boton(boton: Button) -> void:
	boton.add_theme_stylebox_override("normal", caja())
	boton.add_theme_stylebox_override("hover", caja(VERDE_CLARO))
	boton.add_theme_stylebox_override("pressed", caja(VERDE_CLARO, Color(1.0, 0.8, 0.3)))
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	boton.add_theme_color_override("font_color", TEXTO)
	boton.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.4))
	boton.focus_mode = Control.FOCUS_NONE
```

- [ ] **Step 4: Implementar `BarraSuperior.gd`**

```gdscript
extends PanelContainer

## Barra superior del HUD (ambas vistas): recursos del almacén central,
## población, moral y nivel urbano. Lee el autoload Ciudad cada fotograma,
## como el HUD anterior. Población en rojo si excede la vivienda construida.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

const NOMBRES_RECURSO := {
	"comida": "Comida",
	"madera": "Madera",
	"piedra": "Piedra",
	"hierro": "Hierro",
}

## Claves de Ciudad.almacen que se muestran, en orden.
var recursos: Array = ["comida", "madera", "piedra", "hierro"]

var _etiquetas_recurso := {}  # clave -> Label
var _poblacion := TemaHUD.etiqueta()
var _moral := TemaHUD.etiqueta()
var _barra_moral := ProgressBar.new()
var _nivel := TemaHUD.etiqueta()


static func texto_poblacion(censo: int, camas: int) -> String:
	return "Población %d/%d" % [censo, camas]


## Fracción 0-1 del bono de moral respecto al máximo (acotada).
static func fraccion_moral(bono: float) -> float:
	return clampf(bono / Ciudad.BONO_MORAL_MAXIMO, 0.0, 1.0)


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = 44.0
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 28)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)
	for clave in recursos:
		var etiqueta := TemaHUD.etiqueta()
		fila.add_child(etiqueta)
		_etiquetas_recurso[clave] = etiqueta
	fila.add_child(_poblacion)
	fila.add_child(_moral)
	_barra_moral.show_percentage = false
	_barra_moral.max_value = 1.0
	_barra_moral.custom_minimum_size = Vector2(90, 10)
	_barra_moral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barra_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(_barra_moral)
	fila.add_child(_nivel)
	actualizar()


func _process(_delta: float) -> void:
	actualizar()


func actualizar() -> void:
	for clave in _etiquetas_recurso:
		var cantidad := 0.0
		if Ciudad.almacen.has(clave):
			cantidad = (Ciudad.almacen[clave] as Ciudad.Recurso).cantidad
		_etiquetas_recurso[clave].text = "%s %.0f" % [NOMBRES_RECURSO.get(clave, String(clave).capitalize()), cantidad]
	_poblacion.text = texto_poblacion(Ciudad.censo_total, Ciudad.capacidad_camas_construida)
	var excede: bool = Ciudad.vivienda_ocupada > Ciudad.capacidad_camas_construida
	_poblacion.add_theme_color_override("font_color", TemaHUD.INVALIDO if excede else TemaHUD.TEXTO)
	_moral.text = "Moral %+.1f" % Ciudad.bono_moral_variedad
	_barra_moral.value = fraccion_moral(Ciudad.bono_moral_variedad)
	_nivel.text = "Nivel %d" % Ciudad.nivel


func texto_de(clave: String) -> String:
	return _etiquetas_recurso[clave].text


func moral_valor() -> float:
	return _barra_moral.value
```

Nota: `Ciudad.Recurso` es la clase interna usada en `Ciudad.gd`; si el cast `(… as Ciudad.Recurso)` no compila desde otro script, usar `Ciudad.almacen[clave].cantidad` (duck typing, como hacía `HUD.gd`).

- [ ] **Step 5: Ejecutar la prueba y verificar que pasa**

Run: igual que el Step 2.
Expected: imprime `=== TEST 1: BarraSuperior ===` y `HUDTest: todas las pruebas pasaron`, sin errores.

- [ ] **Step 6: Commit** (incluye los `.uid` que Godot genera junto a los `.gd` nuevos)

```bash
git add godot/scripts/TemaHUD.gd godot/scripts/BarraSuperior.gd godot/scripts/HUDTest.gd godot/scenes/HUDTest.tscn godot/scripts/*.gd.uid
git commit -m "feat: barra superior del HUD con estilo común y prueba

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: PanelContextual

**Files:**
- Create: `godot/scripts/PanelContextual.gd`
- Modify: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `TemaHUD` (Task 1).
- Produces: `PanelContextual` (PanelContainer): `mostrar(nombre: String, costo: Dictionary, acciones: Array, valido: Variant = null, extra: String = "") -> void` (`valido`: `true`/`false` muestra la validez; cualquier no-bool la oculta); `ocultar() -> void`; `set_margen_inferior(px: float) -> void`; `static texto_costo(costo: Dictionary) -> String`; etiquetas públicas `titulo`, `costo`, `acciones`, `validez`, `extra` (Label).

- [ ] **Step 1: Escribir la prueba que falla**

En `HUDTest.gd`, añadir junto a la otra `const`:

```gdscript
const PanelContextualScript = preload("res://scripts/PanelContextual.gd")
```

En `ejecutar_pruebas()` añadir `probar_panel_contextual()` y al final del archivo:

```gdscript
func probar_panel_contextual() -> void:
	print("=== TEST 2: PanelContextual ===")
	assert(PanelContextualScript.texto_costo({"madera": 24, "piedra": 8}) == "24 madera · 8 piedra")
	assert(PanelContextualScript.texto_costo({}) == "")

	var panel: PanelContainer = PanelContextualScript.new()
	add_child(panel)
	panel.mostrar("Taller maderero", {"madera": 24, "piedra": 8}, ["ROTAR", "COLOCAR"], true, "Personal máximo: 5")
	assert(panel.visible)
	assert(panel.titulo.text == "TALLER MADERERO")
	assert(panel.costo.text == "24 madera · 8 piedra" and panel.costo.visible)
	assert(panel.acciones.text == "ROTAR  ·  COLOCAR")
	assert(panel.validez.visible and panel.validez.text == "Ubicación válida")
	assert(panel.extra.visible and panel.extra.text == "Personal máximo: 5")

	panel.mostrar("Taller maderero", {}, ["COLOCAR"], false)
	assert(panel.validez.text == "Ubicación no válida")

	# Sin costo, sin validez y sin línea extra (zonas, vías, deconstruir): esas
	# filas quedan ocultas, no vacías.
	panel.mostrar("Trazar vía", {}, ["SALIR (Esc)"])
	assert(not panel.costo.visible and not panel.validez.visible and not panel.extra.visible)

	panel.ocultar()
	assert(not panel.visible)
	panel.queue_free()
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `HUDTest.tscn`. Expected: error de carga por `PanelContextual.gd` inexistente.

- [ ] **Step 3: Implementar `PanelContextual.gd`**

```gdscript
extends PanelContainer

## Panel inferior central (ambas vistas): el ítem activo con su costo, las
## acciones disponibles y, si aplica, si la ubicación es válida. Quien manda
## (CamaraCenital, Player) lo empuja vía HUD.mostrar_contexto(); este panel
## no lee ningún estado del juego.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

var titulo := TemaHUD.etiqueta()
var costo := TemaHUD.etiqueta()
var acciones := TemaHUD.etiqueta()
var validez := TemaHUD.etiqueta()
var extra := TemaHUD.etiqueta()

## Se guarda aparte porque HUD.set_vista() puede llamarse antes de _ready().
var _margen_inferior := 12.0


static func texto_costo(costo_dic: Dictionary) -> String:
	var partes: Array = []
	for tipo in costo_dic:
		partes.append("%d %s" % [costo_dic[tipo], tipo])
	return " · ".join(partes)


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	visible = false
	custom_minimum_size.x = 380.0
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -_margen_inferior
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra.custom_minimum_size.x = 360.0
	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)
	for etiqueta in [titulo, costo, extra, acciones, validez]:
		caja.add_child(etiqueta)


## "valido": true/false muestra "Ubicación válida"/"no válida"; cualquier otro
## valor (p. ej. null) oculta esa fila. "extra" vacío oculta su línea.
func mostrar(nombre: String, costo_dic: Dictionary, lista_acciones: Array, valido: Variant = null, texto_extra: String = "") -> void:
	titulo.text = nombre.to_upper()
	costo.text = texto_costo(costo_dic)
	costo.visible = not costo_dic.is_empty()
	acciones.text = "  ·  ".join(lista_acciones)
	acciones.visible = not lista_acciones.is_empty()
	validez.visible = typeof(valido) == TYPE_BOOL
	if validez.visible:
		validez.text = "Ubicación válida" if valido else "Ubicación no válida"
		validez.add_theme_color_override("font_color", TemaHUD.VALIDO if valido else TemaHUD.INVALIDO)
	extra.text = texto_extra
	extra.visible = texto_extra != ""
	visible = true


func ocultar() -> void:
	visible = false


## Distancia al borde inferior: en 1ª persona el panel sube para no tapar la hotbar.
func set_margen_inferior(px: float) -> void:
	_margen_inferior = px
	offset_bottom = -px
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `HUDTest.tscn`. Expected: `=== TEST 2: PanelContextual ===` y la línea final, sin errores.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/PanelContextual.gd godot/scripts/HUDTest.gd godot/scripts/*.gd.uid
git commit -m "feat: panel contextual del HUD

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: BarraModos y Hotbar

**Files:**
- Create: `godot/scripts/BarraModos.gd`
- Create: `godot/scripts/Hotbar.gd`
- Modify: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `TemaHUD` (Task 1).
- Produces: `BarraModos` (PanelContainer): señales `modo_pedido(modo: String)` (ids `"ver"`, `"construir"`, `"zonas"`, `"vias"`, `"puestos"`) y `puesto_pedido(tipo: String)` (ids de `Recoleccion`: `"mina"`, `"caza_recoleccion"`, `"maderero"`, `"pesca_frutos_mar"`); `set_modo(modo: String, puesto: String = "") -> void` (`""` = Ver); `boton_activo() -> String`; `puestos_visibles() -> bool`; `puesto_activo() -> String`; `_botones: Dictionary` (id → Button; usado por la prueba).
- Produces: `Hotbar` (PanelContainer): `configurar(tipos: Array) -> void`; `seleccionar(indice: int) -> void` (fuera de rango: ignora); `indice_seleccionado() -> int`; `set_cantidad(indice: int, cantidad: int) -> void` (`< 0` oculta la cantidad); `cantidad_visible(indice: int) -> bool`; `static nombre_de(tipo: String) -> String`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `HUDTest.gd` añadir las constantes:

```gdscript
const BarraModosScript = preload("res://scripts/BarraModos.gd")
const HotbarScript = preload("res://scripts/Hotbar.gd")
```

En `ejecutar_pruebas()` añadir `probar_barra_modos()` y `probar_hotbar()`, y al final:

```gdscript
func probar_barra_modos() -> void:
	print("=== TEST 3: BarraModos ===")
	var barra: PanelContainer = BarraModosScript.new()
	add_child(barra)
	assert(barra.boton_activo() == "ver", "sin modo debe estar activo Ver")
	assert(not barra.puestos_visibles())

	barra.set_modo("zonas")
	assert(barra.boton_activo() == "zonas")
	barra.set_modo("")
	assert(barra.boton_activo() == "ver")

	barra.set_modo("puestos", "maderero")
	assert(barra.boton_activo() == "puestos" and barra.puestos_visibles())
	assert(barra.puesto_activo() == "maderero")
	barra.set_modo("puestos", "caza_recoleccion")  # cambio directo M -> H
	assert(barra.puesto_activo() == "caza_recoleccion")
	barra.set_modo("")
	assert(not barra.puestos_visibles())

	# Un clic emite la señal; si quien la recibe no cambia el modo (p. ej.
	# Construir sin blueprint guardado), la barra vuelve a reflejar el real.
	var pedidos: Array = []
	barra.modo_pedido.connect(func(modo: String) -> void: pedidos.append(modo))
	barra._botones["vias"].button_pressed = true
	barra._botones["vias"].pressed.emit()
	assert(pedidos == ["vias"], "salió %s" % [pedidos])
	assert(barra.boton_activo() == "ver", "el botón debe volver al modo real, salió %s" % barra.boton_activo())

	var puestos_pedidos: Array = []
	barra.puesto_pedido.connect(func(tipo: String) -> void: puestos_pedidos.append(tipo))
	barra.set_modo("puestos", "mina")
	barra._botones_puesto["pesca_frutos_mar"].pressed.emit()
	assert(puestos_pedidos == ["pesca_frutos_mar"], "salió %s" % [puestos_pedidos])
	barra.queue_free()


func probar_hotbar() -> void:
	print("=== TEST 4: Hotbar ===")
	assert(HotbarScript.nombre_de("baul") == "Baúl")
	assert(HotbarScript.nombre_de("algo_nuevo") == "Algo_nuevo")

	var hotbar: PanelContainer = HotbarScript.new()
	add_child(hotbar)
	hotbar.configurar(["pared", "puerta", "ventana"])
	assert(hotbar.indice_seleccionado() == 0)
	hotbar.seleccionar(2)
	assert(hotbar.indice_seleccionado() == 2)
	# Fuera de rango: se ignora sin error.
	hotbar.seleccionar(7)
	hotbar.seleccionar(-1)
	assert(hotbar.indice_seleccionado() == 2)

	# Las cantidades están ocultas hasta que el inventario las aporte.
	assert(not hotbar.cantidad_visible(0))
	hotbar.set_cantidad(0, 32)
	assert(hotbar.cantidad_visible(0))
	hotbar.set_cantidad(0, -1)
	assert(not hotbar.cantidad_visible(0))
	hotbar.set_cantidad(9, 5)  # fuera de rango: ignora
	hotbar.queue_free()
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `HUDTest.tscn`. Expected: error de carga por scripts inexistentes.

- [ ] **Step 3: Implementar `BarraModos.gd`**

```gdscript
extends PanelContainer

## Barra vertical izquierda de la cenital: un botón por modo y, bajo Puestos,
## una subtira con los 4 tipos de puesto. Solo pide cambios (señales): el modo
## real lo decide CamaraCenital, que lo devuelve con HUD.set_modo(). Tras cada
## clic la barra se resincroniza con el modo real, así un modo que no llega a
## activarse no queda marcado.

signal modo_pedido(modo: String)
signal puesto_pedido(tipo: String)

const TemaHUD = preload("res://scripts/TemaHUD.gd")

## [id, nombre, tecla]
const MODOS := [
	["ver", "Ver", "Esc"],
	["construir", "Construir", "B"],
	["zonas", "Zonas", "Z"],
	["vias", "Vías", "V"],
	["puestos", "Puestos", "M/H/L/F"],
]
const PUESTOS := [
	["mina", "Mina", "M"],
	["caza_recoleccion", "Caza", "H"],
	["maderero", "Madera", "L"],
	["pesca_frutos_mar", "Pesca", "F"],
]

var _botones := {}  # id de modo -> Button
var _botones_puesto := {}  # tipo de puesto -> Button
var _modo := ""
var _puesto := ""


func _ready() -> void:
	TemaHUD.aplicar_panel(self)
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 8.0
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(columna)
	for modo in MODOS:
		var id: String = modo[0]
		var boton := _crear_boton("%s\n[%s]" % [modo[1], modo[2]], Vector2(88, 56))
		boton.pressed.connect(func() -> void:
			modo_pedido.emit(id)
			_refrescar()
		)
		columna.add_child(boton)
		_botones[id] = boton
	for puesto in PUESTOS:
		var tipo: String = puesto[0]
		var boton := _crear_boton("%s [%s]" % [puesto[1], puesto[2]], Vector2(88, 28))
		boton.pressed.connect(func() -> void:
			puesto_pedido.emit(tipo)
			_refrescar()
		)
		columna.add_child(boton)
		_botones_puesto[tipo] = boton
	_refrescar()


func _crear_boton(texto: String, tamano: Vector2) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.custom_minimum_size = tamano
	TemaHUD.estilizar_boton(boton)
	return boton


## "modo" es el id de MODOS ("" = Ver); "puesto" el tipo activo cuando modo es "puestos".
func set_modo(modo: String, puesto: String = "") -> void:
	_modo = modo
	_puesto = puesto
	if is_inside_tree():
		_refrescar()


func _refrescar() -> void:
	var activo := _modo if _modo != "" else "ver"
	for id in _botones:
		_botones[id].set_pressed_no_signal(id == activo)
	for tipo in _botones_puesto:
		_botones_puesto[tipo].visible = _modo == "puestos"
		_botones_puesto[tipo].set_pressed_no_signal(tipo == _puesto)


func boton_activo() -> String:
	return _modo if _modo != "" else "ver"


func puestos_visibles() -> bool:
	return _modo == "puestos"


func puesto_activo() -> String:
	return _puesto
```

Nota: `boton_activo()` devuelve el estado lógico; la prueba comprueba además la resincronización visual indirectamente, porque `_refrescar()` fuerza `set_pressed_no_signal`. Para asertarlo visualmente basta con `barra._botones["vias"].button_pressed == false` tras el clic; añadirlo a la prueba si se quiere.

- [ ] **Step 4: Implementar `Hotbar.gd`**

```gdscript
extends PanelContainer

## Hotbar de 1ª persona: una casilla por tipo de bloque (teclas 1-N), con la
## seleccionada resaltada. Cada casilla admite una cantidad opcional, oculta
## por ahora: el inventario del avatar será el almacén central y la aportará
## cuando exista el consumo de materiales por tipo.

const TemaHUD = preload("res://scripts/TemaHUD.gd")

const NOMBRES := {
	"pared": "Pared",
	"puerta": "Puerta",
	"ventana": "Ventana",
	"piso": "Piso",
	"cama": "Cama",
	"baul": "Baúl",
}

var _fila := HBoxContainer.new()
var _casillas: Array = []  # de {"panel": PanelContainer, "cantidad": Label}
var _seleccionada := 0


static func nombre_de(tipo: String) -> String:
	return NOMBRES.get(tipo, tipo.capitalize())


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
	for casilla in _casillas:
		casilla["panel"].queue_free()
	_casillas.clear()
	for i in range(tipos.size()):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(72, 60)
		var caja := VBoxContainer.new()
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nombre := TemaHUD.etiqueta(nombre_de(tipos[i]))
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cantidad := TemaHUD.etiqueta()
		cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cantidad.visible = false
		var tecla := TemaHUD.etiqueta(str(i + 1))
		tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for etiqueta in [nombre, cantidad, tecla]:
			caja.add_child(etiqueta)
		panel.add_child(caja)
		_fila.add_child(panel)
		_casillas.append({"panel": panel, "cantidad": cantidad})
	_seleccionada = 0
	_resaltar()


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
	var etiqueta: Label = _casillas[indice]["cantidad"]
	etiqueta.visible = cantidad >= 0
	etiqueta.text = str(cantidad)


func cantidad_visible(indice: int) -> bool:
	return _casillas[indice]["cantidad"].visible


func _resaltar() -> void:
	for i in range(_casillas.size()):
		var estilo := TemaHUD.caja(TemaHUD.VERDE_CLARO, Color(1.0, 0.8, 0.3)) if i == _seleccionada else TemaHUD.caja()
		_casillas[i]["panel"].add_theme_stylebox_override("panel", estilo)
```

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run: `HUDTest.tscn`. Expected: `TEST 3` y `TEST 4` impresos, línea final, sin errores.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/BarraModos.gd godot/scripts/Hotbar.gd godot/scripts/HUDTest.gd godot/scripts/*.gd.uid
git commit -m "feat: barra de modos y hotbar del HUD

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Integración (HUD.gd, Main, CamaraCenital, Player)

Se hace en un solo commit: `HUD.gd` elimina la API antigua, así que `CamaraCenital.gd` y `Player.gd` deben migrar a la vez para que el juego no quede roto entre commits.

**Files:**
- Modify: `godot/scripts/HUD.gd` (reescritura)
- Modify: `godot/scenes/Main.tscn`
- Modify: `godot/scripts/Main.gd`
- Modify: `godot/scripts/PanelPuesto.gd:31-37`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/Player.gd`
- Modify: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `BarraSuperior`, `PanelContextual`, `BarraModos`, `Hotbar` (Tasks 1–3).
- Produces (`HUD.gd`): señales `modo_pedido(modo: String)`, `puesto_pedido(tipo: String)`; `mostrar_contexto(nombre: String, costo: Dictionary, acciones: Array, valido: Variant = null, extra: String = "") -> void`; `mostrar_contexto_puesto(tipo: String, valida: bool, tasas: Dictionary) -> void`; `ocultar_contexto() -> void`; `set_modo(modo: String, puesto: String = "") -> void`; `configurar_hotbar(tipos: Array) -> void`; `set_tipo_hotbar(indice: int) -> void`; `set_vista(primera_persona: bool) -> void`; `static costo_de_puesto(tipo: String) -> Dictionary`; `static texto_tasas(tipo: String, tasas: Dictionary) -> String`. Se conservan: `mostrar_progreso`, `ocultar_progreso`, `actualizar_oxigeno`, `ocultar_oxigeno`, `mostrar_ficha_materiales`, `actualizar_materiales`, `ocultar_ficha_materiales`, `static texto_materiales`, `abrir_panel_puesto`, `cerrar_panel_puesto`.

- [ ] **Step 1: Prueba de los formateadores estáticos (falla)**

En `HUDTest.gd` añadir `const HUDScript = preload("res://scripts/HUD.gd")`, llamar a `probar_formateadores_hud()` desde `ejecutar_pruebas()` y añadir:

```gdscript
func probar_formateadores_hud() -> void:
	print("=== TEST 5: formateadores de HUD.gd ===")
	assert(HUDScript.costo_de_puesto("mina") == Recoleccion.COSTO_CONSTRUCCION)
	assert(HUDScript.costo_de_puesto("maderero") == Recoleccion.COSTO_CONSTRUCCION_MADERERO)
	assert(HUDScript.costo_de_puesto("desconocido").is_empty())

	assert(HUDScript.texto_tasas("mina", {}) == "Recolección prevista: sin recursos detectados")
	assert(HUDScript.texto_tasas("mina", {"hierro": 2.0}) == "Recolección prevista por ciudadano:\n  2.0 hierro/h")
	assert(HUDScript.texto_tasas("maderero", {"madera": 0.0}) == "Recolección prevista: sin árboles detectados")
	assert(HUDScript.texto_tasas("maderero", {"madera": 12.0}) == "Recolección prevista por ciudadano:\n  12.0 madera/h")
	assert(HUDScript.texto_tasas("caza_recoleccion", {"caza": 0.0, "recoleccion": 0.0}) == "Recolección prevista: sin fauna ni fruta detectada")
	assert(HUDScript.texto_tasas("caza_recoleccion", {"caza": 3.0, "recoleccion": 0.0}) == "Recolección prevista por ciudadano:\n  3.0 comida/h por caza\n  0.0 comida/h por recolección")
	# Pesca sin extremo de agua válido llega como diccionario vacío.
	assert(HUDScript.texto_tasas("pesca_frutos_mar", {}) == "Recolección prevista: sin agua detectada")
	assert(HUDScript.texto_tasas("pesca_frutos_mar", {"pesca": 1.5, "frutos_mar": 0.5}) == "Recolección prevista por ciudadano:\n  1.5 comida/h por pesca\n  0.5 comida/h por frutos del mar")
```

Run: `HUDTest.tscn`. Expected: FAIL (`costo_de_puesto` no existe en el `HUD.gd` actual).

- [ ] **Step 2: Reescribir `godot/scripts/HUD.gd`**

Sustituir el archivo completo por (las funciones de progreso, oxígeno, materiales y panel de puesto se conservan idénticas a las actuales):

```gdscript
extends CanvasLayer

## HUD por modos (ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md).
## Fachada única para Player y CamaraCenital: crea los widgets (barra superior,
## panel contextual, barra de modos de la cenital, hotbar de 1ª persona) y
## expone la API que los empuja. Conserva la barra de progreso, el oxígeno, la
## ficha de materiales y el panel de puesto.

## Pedidos de la barra de modos (clic): CamaraCenital los traduce a sus
## funciones _alternar_modo_*.
signal modo_pedido(modo: String)
signal puesto_pedido(tipo: String)

const COLOR_POSITIVO := Color.WHITE
const COLOR_NEGATIVO := Color(1.0, 0.3, 0.3)

const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")
const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")
const PanelContextualScript = preload("res://scripts/PanelContextual.gd")
const BarraModosScript = preload("res://scripts/BarraModos.gd")
const HotbarScript = preload("res://scripts/Hotbar.gd")

const NOMBRES_TASA := {
	"caza": "caza",
	"recoleccion": "recolección",
	"pesca": "pesca",
	"frutos_mar": "frutos del mar",
}

@onready var oxigeno_label: Label = $OxigenoLabel
@onready var materiales_ficha: Label = $MaterialesFicha

var _panel_puesto: PanelContainer
var _barra_progreso: ProgressBar
var _barra_superior: PanelContainer
var _contexto: PanelContainer
var _barra_modos: PanelContainer
var _hotbar: PanelContainer


## Los widgets se crean en _init(), no en _ready(): en Main.tscn Player y
## CamaraCenital van antes que HUDLayer, así que su _ready() (que llama a
## configurar_hotbar() y conecta las señales) corre antes que el de este nodo.
func _init() -> void:
	_barra_superior = BarraSuperiorScript.new()
	add_child(_barra_superior)
	_contexto = PanelContextualScript.new()
	add_child(_contexto)
	_barra_modos = BarraModosScript.new()
	_barra_modos.modo_pedido.connect(func(modo: String) -> void: modo_pedido.emit(modo))
	_barra_modos.puesto_pedido.connect(func(tipo: String) -> void: puesto_pedido.emit(tipo))
	add_child(_barra_modos)
	_hotbar = HotbarScript.new()
	add_child(_hotbar)
	_panel_puesto = PanelPuestoScript.new()
	add_child(_panel_puesto)


func _ready() -> void:
	set_vista(true)  # la partida empieza en 1ª persona

	# Barra de progreso de minar/talar/recolectar/deconstruir, bajo la mira.
	_barra_progreso = ProgressBar.new()
	_barra_progreso.show_percentage = false
	_barra_progreso.set_anchors_preset(Control.PRESET_CENTER)
	_barra_progreso.offset_left = -90
	_barra_progreso.offset_right = 90
	_barra_progreso.offset_top = 40
	_barra_progreso.offset_bottom = 54
	_barra_progreso.visible = false
	add_child(_barra_progreso)


## true = 1ª persona (hotbar), false = cenital (barra de modos). Cambiar de
## vista descarta el panel contextual; quien lo alimenta lo vuelve a empujar.
func set_vista(primera_persona: bool) -> void:
	_hotbar.visible = primera_persona
	_barra_modos.visible = not primera_persona
	_contexto.set_margen_inferior(84.0 if primera_persona else 12.0)
	_contexto.ocultar()


func configurar_hotbar(tipos: Array) -> void:
	_hotbar.configurar(tipos)


func set_tipo_hotbar(indice: int) -> void:
	_hotbar.seleccionar(indice)


## "modo" es el id de BarraModos.MODOS ("" = Ver); "puesto" el tipo activo si es "puestos".
func set_modo(modo: String, puesto: String = "") -> void:
	_barra_modos.set_modo(modo, puesto)


func mostrar_contexto(nombre: String, costo: Dictionary, acciones: Array, valido: Variant = null, extra: String = "") -> void:
	_contexto.mostrar(nombre, costo, acciones, valido, extra)


func ocultar_contexto() -> void:
	_contexto.ocultar()


## Panel contextual de un puesto de recolección: costo, personal, almacenamiento
## y, en vivo, la recolección prevista por ciudadano según la posición del cursor.
func mostrar_contexto_puesto(tipo: String, valida: bool, tasas: Dictionary) -> void:
	var extra := "Personal máximo: %d · Almacenamiento: %d\n%s" % [Recoleccion.cupo_de(tipo), Recoleccion.capacidad_almacen_de(tipo), texto_tasas(tipo, tasas)]
	_contexto.mostrar(PanelPuestoScript.NOMBRES_PUESTO.get(tipo, tipo), costo_de_puesto(tipo), ["ROTAR (Ctrl+rueda)", "COLOCAR (clic)"], valida, extra)


static func costo_de_puesto(tipo: String) -> Dictionary:
	match tipo:
		"mina": return Recoleccion.COSTO_CONSTRUCCION
		"caza_recoleccion": return Recoleccion.COSTO_CONSTRUCCION_CAZA_RECOLECCION
		"maderero": return Recoleccion.COSTO_CONSTRUCCION_MADERERO
		"pesca_frutos_mar": return Recoleccion.COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR
	return {}


## Recolección prevista de un puesto. Diccionario vacío = nada detectado (en
## pesca también cuando el extremo de agua todavía no es válido).
static func texto_tasas(tipo: String, tasas: Dictionary) -> String:
	match tipo:
		"mina":
			if tasas.is_empty():
				return "Recolección prevista: sin recursos detectados"
			var lineas: Array = []
			for recurso in tasas:
				lineas.append("%.1f %s/h" % [tasas[recurso], recurso])
			return "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)
		"maderero":
			if tasas.get("madera", 0.0) <= 0.0:
				return "Recolección prevista: sin árboles detectados"
			return "Recolección prevista por ciudadano:\n  %.1f madera/h" % tasas["madera"]
		"caza_recoleccion":
			if tasas.get("caza", 0.0) <= 0.0 and tasas.get("recoleccion", 0.0) <= 0.0:
				return "Recolección prevista: sin fauna ni fruta detectada"
		"pesca_frutos_mar":
			if tasas.get("pesca", 0.0) <= 0.0 and tasas.get("frutos_mar", 0.0) <= 0.0:
				return "Recolección prevista: sin agua detectada"
	var lineas_comida: Array = []
	for clave in tasas:
		lineas_comida.append("%.1f comida/h por %s" % [tasas[clave], NOMBRES_TASA.get(clave, clave)])
	return "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas_comida)


## Llamada cada física por Player._procesar_oxigeno() mientras el jugador
## está en agua o recuperando aire — oculta con ocultar_oxigeno() en cuanto
## vuelve a estar a full fuera del agua, para no saturar el HUD en seco.
func actualizar_oxigeno(fraccion: float) -> void:
	oxigeno_label.text = "Oxígeno: %d%%" % round(fraccion * 100)
	oxigeno_label.modulate = COLOR_NEGATIVO if fraccion < 0.3 else COLOR_POSITIVO
	oxigeno_label.visible = true


func ocultar_oxigeno() -> void:
	oxigeno_label.visible = false


## Ficha VISUAL de los materiales que movilizaría el blueprint activo (ver
## docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md):
## no lee ni toca ningún inventario real (no existe todavía).
func mostrar_ficha_materiales() -> void:
	materiales_ficha.text = texto_materiales({})
	materiales_ficha.visible = true


func actualizar_materiales(neto: Dictionary) -> void:
	materiales_ficha.text = texto_materiales(neto)


func ocultar_ficha_materiales() -> void:
	materiales_ficha.visible = false


## "neto" es material -> int (negativo = hace falta, positivo = sobra; ver
## NiveladorTerreno.resumen_materiales()). Lo necesario va sin signo y de
## mayor a menor; el sobrante recogido va después con "+".
static func texto_materiales(neto: Dictionary) -> String:
	var necesarios: Array = []
	var sobrantes: Array = []
	for material in neto:
		var cantidad: int = neto[material]
		if cantidad < 0:
			necesarios.append([-cantidad, material])
		elif cantidad > 0:
			sobrantes.append("+ %d %s" % [cantidad, material])
	necesarios.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lineas: Array = ["Materiales de construcción:"]
	for necesario in necesarios:
		lineas.append("%d %s" % [necesario[0], necesario[1]])
	lineas.append_array(sobrantes)
	if lineas.size() == 1:
		lineas.append("-")
	return "\n".join(lineas)


func abrir_panel_puesto(esquina: Vector2i) -> void:
	_panel_puesto.abrir(esquina)


func cerrar_panel_puesto() -> void:
	_panel_puesto.cerrar()


## Muestra la barra de progreso bajo la mira. "retrocede" (tala, deconstrucción)
## la pinta en naranja: indica lo que le queda a lo que se está desmontando.
func mostrar_progreso(fraccion: float, retrocede: bool = false) -> void:
	_barra_progreso.value = clampf(fraccion, 0.0, 1.0) * 100.0
	_barra_progreso.modulate = Color(1.0, 0.6, 0.2) if retrocede else Color(0.4, 1.0, 0.4)
	_barra_progreso.visible = true


func ocultar_progreso() -> void:
	_barra_progreso.visible = false
```

Nota: en la rama `caza_recoleccion`/`pesca_frutos_mar` del `match`, si NO se cumple la condición de "nada detectado" el flujo sale del `match` y continúa al formateo común de comida; por eso esas ramas no llevan `return` propio.

- [ ] **Step 3: Limpiar `Main.tscn` y reubicar Materiales y Oxígeno**

Eliminar los nodos del HUD antiguo (el `VBoxContainer` `HUD` con sus 3 etiquetas, las 4 fichas de puesto y las 3 etiquetas de modo):

```bash
python - <<'EOF'
import re, pathlib
ruta = pathlib.Path("godot/scenes/Main.tscn")
s = ruta.read_text(encoding="utf-8")
s = re.sub(r'\[node name="HUD" type="VBoxContainer".*?(?=\[node name="MaterialesFicha")', '', s, flags=re.S)
s = re.sub(r'\[node name="ModoDeconstruccionLabel".*?(?=\[node name="OxigenoLabel")', '', s, flags=re.S)
ruta.write_text(s, encoding="utf-8")
EOF
grep -n "node name=" godot/scenes/Main.tscn | sed -n '/HUDLayer/,$p'
```

Expected: tras `HUDLayer` solo quedan `MaterialesFicha` y `OxigenoLabel`.

Reubicar (evitar la barra de modos de la izquierda y la barra superior). En `Main.tscn`, en `MaterialesFicha`, cambiar `offset_left = 12.0` / `offset_top = 320.0` por `offset_left = 110.0` / `offset_top = 72.0`; en `OxigenoLabel`, cambiar `offset_left = 12.0` / `offset_top = 490.0` por `offset_left = 12.0` / `offset_top = 72.0`. Los `offset_right`/`offset_bottom` de ambos se ajustan para conservar su ancho/alto originales (Materiales: `offset_right = 418.0`, `offset_bottom = 192.0`; Oxígeno: `offset_bottom = 102.0`).

En `PanelPuesto.gd` cambiar `offset_top = 12.0` por `offset_top = 72.0` (línea 34).

- [ ] **Step 4: `Main.gd` avisa la vista**

Añadir junto a los otros `@onready`:

```gdscript
@onready var hud: CanvasLayer = $HUDLayer
```

Y en `_alternar_camara_cenital()`, tras `cenital_activa = not cenital_activa`... al final de la función (después de `Input.mouse_mode = ...`):

```gdscript
	hud.set_vista(not cenital_activa)
```

- [ ] **Step 5: `CamaraCenital.gd` — cablear la barra de modos**

1. En `_ready()` añadir al final:

```gdscript
	hud.modo_pedido.connect(_on_modo_pedido)
	hud.puesto_pedido.connect(_alternar_puesto_por_tipo)
```

2. En `_unhandled_input`, reemplazar las cuatro ramas de puestos por:

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_M:
			_alternar_puesto_por_tipo("mina")
		elif tecla.pressed and tecla.keycode == KEY_H:
			_alternar_puesto_por_tipo("caza_recoleccion")
		elif tecla.pressed and tecla.keycode == KEY_L:
			_alternar_puesto_por_tipo("maderero")
		elif tecla.pressed and tecla.keycode == KEY_F:
			_alternar_puesto_por_tipo("pesca_frutos_mar")
```

3. Añadir tras `_alternar_modo_colocar_puesto()` (antes de `_salir_de_modo_colocar_puesto`):

```gdscript
## Alterna el puesto de "tipo" con su huella: teclas M/H/L/F y subtira de la
## barra de modos (HUD.puesto_pedido).
func _alternar_puesto_por_tipo(tipo: String) -> void:
	match tipo:
		"mina": _alternar_modo_colocar_puesto(tipo, Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
		"caza_recoleccion": _alternar_modo_colocar_puesto(tipo, Recoleccion.ANCHO_HUELLA_CAZA_RECOLECCION, Recoleccion.ALTO_HUELLA_CAZA_RECOLECCION)
		"maderero": _alternar_modo_colocar_puesto(tipo, Recoleccion.ANCHO_HUELLA_MADERERO, Recoleccion.ALTO_HUELLA_MADERERO)
		"pesca_frutos_mar": _alternar_modo_colocar_puesto(tipo, Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR, Recoleccion.ALTO_HUELLA_PESCA_FRUTOS_MAR)


## Clic en un botón de la barra de modos: mismo efecto que su tecla.
func _on_modo_pedido(modo: String) -> void:
	match modo:
		"ver": salir_de_todos_los_modos()
		"construir": _alternar_modo_colocar_blueprint()
		"zonas": _alternar_modo_zonificar()
		"vias": _alternar_modo_trazar_via()
		"puestos":
			if modo_colocar_puesto:
				_salir_de_modo_colocar_puesto()
			else:
				_alternar_puesto_por_tipo("mina")
```

4. Blueprint. En `_alternar_modo_colocar_blueprint()`, tras `hud.mostrar_ficha_materiales()` añadir `hud.set_modo("construir")`. En `_salir_de_modo_colocar_blueprint()` reemplazar el cuerpo por:

```gdscript
func _salir_de_modo_colocar_blueprint() -> void:
	var estaba := modo_colocar_blueprint
	modo_colocar_blueprint = false
	_mostrar_huella_blueprint(false)
	_blueprint_activo = {}
	hud.ocultar_ficha_materiales()
	_overlay_nivelacion.ocultar()
	_overlay_vigente = SIN_RESUMEN
	if estaba:
		hud.set_modo("")
		hud.ocultar_contexto()
```

En `_actualizar_previsualizacion_blueprint()`, justo antes de `_actualizar_resumen_materiales(esquina, ev, valida)` añadir:

```gdscript
	hud.mostrar_contexto("Edificio residencial", {}, ["ROTAR (Ctrl+rueda)", "COLOCAR (clic)"], valida)
```

5. Puestos. En `_alternar_modo_colocar_puesto()`: borrar las 4 líneas `hud.ocultar_ficha_*()` y el bloque `if tipo == "mina": hud.mostrar_ficha_mina() elif … else: hud.mostrar_ficha_pesca()`; en su lugar, tras `_overlay_vigente = SIN_RESUMEN`:

```gdscript
	hud.set_modo("puestos", tipo)
	hud.mostrar_contexto_puesto(tipo, false, {})
```

En `_salir_de_modo_colocar_puesto()`: al inicio `var estaba := modo_colocar_puesto`; borrar las 4 líneas `hud.ocultar_ficha_*()`; al final (tras `_tipo_puesto_activo = ""`):

```gdscript
	if estaba:
		hud.set_modo("")
		hud.ocultar_contexto()
```

Reemplazar `_actualizar_previsualizacion_puesto()` completa por:

```gdscript
func _actualizar_previsualizacion_puesto() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)
	var ev: Dictionary = _evaluar_puesto(esquina)
	var extremo_agua_indice: int = ev["extremo_agua_indice"]
	var valida: bool = _mensaje_rechazo_puesto(ev) == ""
	_actualizar_fantasma_puesto(esquina, ev, valida)
	_actualizar_overlays(esquina, ev)

	var tasas: Dictionary = {}
	if _tipo_puesto_activo == "mina":
		var altura_superficie: int = mundo.altura_en(centro.x, centro.y)
		var conteo: Dictionary = Recoleccion.detectar_recursos_extraibles(mundo, centro, altura_superficie)
		tasas = Recoleccion.tasas_recoleccion(conteo)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_MINA)
	elif _tipo_puesto_activo == "caza_recoleccion":
		var promedios: Dictionary = Recoleccion.detectar_fauna_frutal(mundo.generador, centro)
		tasas = Recoleccion.tasas_caza_recoleccion(promedios)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_CAZA_RECOLECCION)
	elif _tipo_puesto_activo == "pesca_frutos_mar":
		if extremo_agua_indice != -1:
			var celdas_extremo := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
			@warning_ignore("integer_division")
			var centro_agua := esquina + celdas_extremo[celdas_extremo.size() / 2]
			var celdas_agua: Dictionary = Recoleccion.celdas_agua_conectadas(mundo, centro_agua, Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)
			var promedios: Dictionary = Recoleccion.detectar_pesca_frutos_mar(mundo.generador, celdas_agua)
			tasas = Recoleccion.tasas_pesca_frutos_mar(promedios)
			_actualizar_area_accion_agua(centro_agua, celdas_agua)
		else:
			_ocultar_area_accion()
	else:
		var promedio_arbol: float = Recoleccion.detectar_arbol(mundo.generador, centro)
		tasas = Recoleccion.tasa_maderero(promedio_arbol)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_MADERERO)
	hud.mostrar_contexto_puesto(_tipo_puesto_activo, valida, tasas)
```

6. Zonificación. Reemplazar:

```gdscript
func _alternar_modo_zonificar() -> void:
	if modo_zonificar:
		_salir_de_modo_zonificar()
		return
	_salir_de_modo_colocar_blueprint()
	_salir_de_modo_colocar_puesto()
	_salir_de_modo_trazar_via()
	hud.cerrar_panel_puesto()
	modo_zonificar = true
	hud.set_modo("zonas")
	_mostrar_contexto_zona()


func _salir_de_modo_zonificar() -> void:
	var estaba := modo_zonificar
	modo_zonificar = false
	_cancelar_pintado_zona()
	if estaba:
		hud.set_modo("")
		hud.ocultar_contexto()
```

En `_elegir_zona()` cambiar `hud.mostrar_modo_zonificacion(_nombre_zona_seleccionada())` por `_mostrar_contexto_zona()` y añadir:

```gdscript
func _mostrar_contexto_zona() -> void:
	hud.mostrar_contexto("Zonificación: %s" % _nombre_zona_seleccionada(), {}, ["1 Zona A", "2 Zona B", "0 Borrar", "Z/Esc salir"])
```

7. Vías. En `_alternar_modo_trazar_via()` reemplazar `hud.mostrar_modo_trazar_via()` por:

```gdscript
	hud.set_modo("vias")
	hud.mostrar_contexto("Trazar vía", {}, ["FIJAR PUNTO (clic)", "CONFIRMAR (doble clic)", "SALIR (Esc)"])
```

y `_salir_de_modo_trazar_via()` por:

```gdscript
func _salir_de_modo_trazar_via() -> void:
	var estaba := modo_trazar_via
	modo_trazar_via = false
	_hay_tramo_en_curso = false
	_tramos_fijos.clear()
	via_preview.limpiar()
	if estaba:
		hud.set_modo("")
		hud.ocultar_contexto()
```

- [ ] **Step 6: `Player.gd` — hotbar y panel contextual**

1. Con las demás constantes: `const HotbarScript = preload("res://scripts/Hotbar.gd")`.
2. En `_ready()` añadir al final:

```gdscript
	hud.configurar_hotbar(tipos_disponibles)
	hud.set_tipo_hotbar(tipo_seleccionado)
```

3. En `_input`, tras `tipo_seleccionado = indice` añadir `hud.set_tipo_hotbar(indice)`.
4. En `_alternar_modo_deconstruccion()` eliminar el `if/else` de `hud.mostrar_modo_deconstruccion()`/`ocultar_…` (queda solo `modo_deconstruccion = not modo_deconstruccion` y los dos reinicios).
5. Al inicio de `_physics_process`, tras `_procesar_accion_repetida(delta)` añadir `_actualizar_contexto()` y definir:

```gdscript
## Panel contextual de 1ª persona: el tipo de bloque seleccionado (con "hay
## objetivo al alcance" como validez) o, en modo G, el aviso de deconstrucción.
func _actualizar_contexto() -> void:
	if not camara.current:
		return
	if modo_deconstruccion:
		hud.mostrar_contexto("Deconstruir", {}, ["DECONSTRUIR (clic izq.)", "G para salir"])
	else:
		hud.mostrar_contexto(HotbarScript.nombre_de(tipos_disponibles[tipo_seleccionado]), {}, ["COLOCAR (clic der.)"], raycast.is_colliding())
```

- [ ] **Step 7: Verificar que no queda API antigua**

Run: `grep -rn "mostrar_ficha_mina\|mostrar_ficha_caza\|mostrar_ficha_madero\|mostrar_ficha_pesca\|ocultar_ficha_mina\|ocultar_ficha_caza\|ocultar_ficha_madero\|ocultar_ficha_pesca\|actualizar_tasas_\|mostrar_modo_\|ocultar_modo_" godot --include=*.gd --include=*.tscn`
Expected: sin resultados.

- [ ] **Step 8: Ejecutar pruebas automáticas**

Run: `HUDTest.tscn` (Expected: TEST 1–5 impresos y línea final, sin errores) y `Test.tscn` (Expected: todas las aserciones pasan). Según CLAUDE.md, además las `*Test.tscn` que toquen `Player`/`CamaraCenital`: `PlayerNatacionTest.tscn`, `PlayerOxigenoTest.tscn`, `PuestosPrevisualizacionTest.tscn`.

- [ ] **Step 9: Verificación manual en `Main.tscn`**

Ejecutar `Main.tscn` y comprobar (consultar `get_debug_output` por errores; tras `stop_project`, confirmar con `Get-Process` que no queden procesos Godot huérfanos):

1. 1ª persona: barra superior arriba con recursos/población/moral/nivel; hotbar 1–6 abajo; 1–6 cambia la casilla resaltada y el panel muestra el tipo con "Ubicación válida" al apuntar a un bloque y "no válida" al mirar al cielo.
2. G muestra "DECONSTRUIR" en el panel; G de nuevo vuelve a mostrar el tipo. B declara edificio como antes.
3. C (cenital): aparece la barra de modos a la izquierda y desaparece la hotbar. Z/V/B/M/H/L/F activan su modo, resaltan su botón y muestran el panel; cambiar M→H actualiza el resaltado de la subtira; Esc resalta Ver y oculta el panel.
4. Clic en cada botón equivale a su tecla; clic en Construir sin blueprint guardado no deja el botón marcado.
5. Colocar un puesto: el panel muestra costo, personal, almacenamiento, tasa prevista y validez; el clic en un puesto existente sigue abriendo `PanelPuesto` sin solaparse con la barra superior.
6. C de vuelta a 1ª persona: sin restos de modo ni de panel; hotbar visible.

- [ ] **Step 10: Commit**

```bash
git add godot/scripts/HUD.gd godot/scenes/Main.tscn godot/scripts/Main.gd godot/scripts/PanelPuesto.gd godot/scripts/CamaraCenital.gd godot/scripts/Player.gd godot/scripts/HUDTest.gd
git commit -m "feat: HUD por modos integrado (barra de modos, hotbar y panel contextual)

Reemplaza las etiquetas de modo y las cuatro fichas de puesto.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Documentación

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-hud-por-modos-design.md`
- Modify: `docs/Pendientes y próximos pasos.md`
- Modify: `PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md` (párrafo del HUD, cerca de la línea 529)

- [ ] **Step 1: Corregir la spec con las desviaciones**

En la spec: (a) "Theme construido en código" → helpers estáticos en `TemaHUD.gd`; (b) la tira de puestos "sobre el panel" → subtira bajo el botón Puestos de la barra vertical; (c) quitar "miniatura opcional" del panel contextual; (d) firma `mostrar_contexto(nombre, costo, acciones, valido: Variant = null, extra = "")` con `null` = no aplica; (e) añadir `set_vista(primera_persona: bool)` y `mostrar_contexto_puesto(tipo, valida, tasas)` a la API de `HUD.gd`.

- [ ] **Step 2: Actualizar Pendientes y PoC 6**

En `docs/Pendientes y próximos pasos.md`, marcar el punto 1 (HUD visual interactivo) como hecho, indicando qué queda para después: batalla, escuadrón, salud/equipo, cantidades por casilla, herramientas de recolección, modo Demoler en cenital e iconos. En el documento técnico de PoC 6, sustituir la descripción de `ModoZonificacionLabel` por la del HUD por modos (widgets y API nueva).

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-09-25-hud-por-modos-design.md "docs/Pendientes y próximos pasos.md" "PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: HUD por modos en spec, pendientes y documento técnico de PoC 6

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Avisar al usuario del GDD y README**

No se editan (tienen cambios suyos sin commitear). Decirle: la sección de interfaz del GDD y el README deberían mencionar el HUD por modos (barra superior, barra de modos en cenital, hotbar y panel contextual en 1ª persona).
