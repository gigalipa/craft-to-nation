# Previsualización isométrica de construcciones (HUD cenital) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Miniaturas isométricas reales de las 5 opciones del submenú Construir del HUD cenital (Residencial + los 4 puestos), rotación sincronizada con Ctrl+rueda, botón Residencial atenuado sin blueprint declarado, y la tecla `B`/botón "Construir" desacoplados de activar la colocación.

**Architecture:** Se extrae el renderizador de miniaturas 3D que ya existe en `Hotbar.gd` (SubViewport aislado + cámara ortográfica de esquina) a un módulo compartido `MiniaturaRenderer.gd`, reutilizado por `Hotbar.gd` (sin cambio de comportamiento) y por `BarraModos.gd` (construcciones completas en vez de bloques sueltos). La rotación 90° de celdas de blueprint, hoy solo inline en `CamaraCenital._rotar_blueprint()`, se extrae a `BlueprintValidator.rotar_celdas_3d()` para reutilizarla en la previsualización. `CamaraCenital.gd` gana un estado de "menú Construir abierto" independiente de "colocación activa", y empuja la rotación en curso al HUD cada vez que gira una construcción.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), pruebas basadas en `assert()` corridas desde escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-30-previsualizacion-construcciones-cenital-design.md`

## Global Constraints

- Tabulaciones (no espacios) en todo GDScript nuevo o modificado.
- Español en comentarios, mensajes del juego y pruebas.
- No reformatear código ajeno al objetivo de cada task.
- No tocar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- No usar `class_name` en módulos de datos/utilidad sin estado (mismo patrón que `PlantillasPuesto.gd`/`Blueprints.gd`: se cargan con `preload()`, evita el bug de caché de clases globales de este proyecto). `BlueprintValidator.gd` ya tiene `class_name` de antes — no se toca esa decisión, solo se le agrega una función.
- Verificación final obligatoria (`CLAUDE.md`): correr `godot/scenes/Test.tscn` y cada `*Test.tscn` afectado con Godot 4.7, confirmar que todas las aserciones pasan.
- Comando headless de referencia (ya usado en planes anteriores de este proyecto): `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/<Nombre>Test.tscn > /tmp/<nombre>.txt 2>&1` (Bash, no PowerShell).

## Review Focus

- Girar con Ctrl+rueda mientras el menú Construir está abierto pero SIN ninguna construcción activa (recién abierto con `B`, nada seleccionado todavía): no debe haber rotación que procesar (el gesto solo existe dentro de `modo_colocar_puesto`/`modo_colocar_blueprint`), así que las miniaturas deben quedar en `_giros_menu == 0` sin crashear.
- Declarar un blueprint residencial DESPUÉS de haber abierto el menú (Residencial ya atenuado en pantalla): el próximo refresco de `BarraModos` debe quitar la atenuación sin que el jugador tenga que cerrar y reabrir el menú.
- Una construcción sin ninguna celda con malla real (p. ej. un blueprint guardado que por algún motivo solo tuviera puertas/vidrio): la miniatura debe quedar vacía (`texture = null`) sin lanzar ningún error, no reventar `MiniaturaRenderer.renderizar()` con una lista de piezas vacía.
- Pulsar `B` dos veces seguidas muy rápido (doble toggle) no debe dejar `_menu_construir_abierto` desincronizado de `modo_colocar_blueprint`/`modo_colocar_puesto` — la segunda pulsación siempre debe cerrar todo, nunca reabrir a medias.
- Cambiar de opción activa dentro del menú ya abierto (p. ej. de Mina a Pesca, sin pasar por Ver) debe reiniciar `_giros_menu`/`_giros_puesto` a 0 y empujarlo al HUD, para que las miniaturas no queden con el giro heredado de la construcción anterior.

---

## Task 1: `MiniaturaRenderer.gd` — extraer el renderizador de miniaturas de `Hotbar.gd`

Refactor puro: mueve la lógica de render 3D a un módulo compartido, sin cambiar el comportamiento visual de la hotbar. Es la base de la que dependen las tasks 2 y 3.

**Files:**
- Create: `godot/scripts/MiniaturaRenderer.gd`
- Create: `godot/scenes/MiniaturaRendererTest.tscn`
- Create: `godot/scripts/MiniaturaRendererTest.gd`
- Modify: `godot/scripts/Hotbar.gd:79-106,173-230`
- Modify: `godot/scripts/PanelContextual.gd:19,200` (comentarios, sin cambio de código)

**Interfaces:**
- Produces: `MiniaturaRenderer.cargar_biblioteca() -> MeshLibrary`, `MiniaturaRenderer.malla_de_item(biblioteca: MeshLibrary, nombre_item: String) -> Mesh`, `MiniaturaRenderer.renderizar(piezas: Array, direccion_camara: Vector3, padre: Node) -> Texture2D` (`piezas` es `Array` de `[Mesh, Vector3 offset, Material o null]`, mismo formato que ya usaba `Hotbar._piezas_de_icono()`). `MiniaturaRenderer.RESOLUCION_ICONO := 128`, `MiniaturaRenderer.NOMBRE_FISICO_BIBLIOTECA := {"adobe": "tierra_compactada"}`.

- [ ] **Step 1: Crear `MiniaturaRenderer.gd`**

```gdscript
extends RefCounted

## Renderizador de miniaturas 3D compartido: arma un SubViewport aislado con
## las piezas dadas (malla real + material real, como el bloque/edificio que
## representan) y una cámara ortográfica diagonal, y devuelve su textura.
## Extraído de Hotbar._renderizar_icono()/_malla_de_item() (2026-09-24) para
## que BarraModos.gd lo reutilice con construcciones completas en vez de un
## solo bloque — ver docs/superpowers/specs/2026-09-30-previsualizacion-
## construcciones-cenital-design.md, Sección 2. Sin class_name (mismo motivo
## que PlantillasPuesto.gd/Blueprints.gd: se carga con preload()).

const RUTA_BIBLIOTECA := "res://assets/BlockLibrary.res"
const RESOLUCION_ICONO := 128

## Nombre de tipo de juego -> nombre real del ítem en BlockLibrary.res,
## cuando difieren (hoy solo "adobe": el bloque se llama "tierra_compactada"
## en la biblioteca — ver VoxelWorld.RENOMBRE_BIBLIOTECA).
const NOMBRE_FISICO_BIBLIOTECA := {
	"adobe": "tierra_compactada",
}


## Copia propia de la MeshLibrary (CACHE_MODE_IGNORE): independiente de la
## que usa VoxelWorld en el mundo, para no heredar mutaciones que
## VoxelWorld._indexar_biblioteca() hace en el sitio (p. ej. vacía la malla
## de puerta_inferior/puerta_superior). Cada llamador cachea el resultado en
## su propia variable de instancia (ver Hotbar._biblioteca/BarraModos._biblioteca).
static func cargar_biblioteca() -> MeshLibrary:
	return ResourceLoader.load(RUTA_BIBLIOTECA, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE)


## Malla real del ítem "nombre_item" en "biblioteca", o null si no existe/no
## tiene malla (p. ej. vidrio, puerta_inferior/puerta_superior: malla vacía a
## propósito, ver VoxelWorld — esos tipos los dibuja otro sistema).
static func malla_de_item(biblioteca: MeshLibrary, nombre_item: String) -> Mesh:
	var nombre_fisico: String = NOMBRE_FISICO_BIBLIOTECA.get(nombre_item, nombre_item)
	for id in biblioteca.get_item_list():
		if biblioteca.get_item_name(id) == nombre_fisico:
			return biblioteca.get_item_mesh(id)
	return null


## Renderiza "piezas" (cada una [malla, posición relativa, material o null
## para el de la propia malla]) juntas en un SubViewport aislado
## (own_world_3d: no interfiere con la escena 3D del juego) y devuelve su
## textura. "direccion_camara" es la dirección diagonal de la cámara
## ortográfica respecto al centro del AABB combinado (p. ej. Vector3(1,1,1)
## para una diagonal simétrica, Vector3(1,1,-1) para la esquina superior-
## derecha-frontal de algo cuyo frente mira a -Z). "padre" es el Node ya en
## el árbol de escena donde se cuelga el SubViewport (hace falta estar en el
## árbol para que el motor lo renderice). UPDATE_ONCE: es una miniatura
## estática, no hace falta re-renderizarla cada frame — quien necesite
## reflejar un cambio (p. ej. una rotación) vuelve a llamar a esta función,
## no reutiliza el mismo SubViewport.
static func renderizar(piezas: Array, direccion_camara: Vector3, padre: Node) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(RESOLUCION_ICONO, RESOLUCION_ICONO)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var aabb: AABB
	for i in range(piezas.size()):
		var malla: Mesh = piezas[i][0]
		var offset: Vector3 = piezas[i][1]
		var material_pieza: Material = piezas[i][2]
		var instancia := MeshInstance3D.new()
		instancia.mesh = malla
		instancia.position = offset
		if material_pieza != null:
			instancia.material_override = material_pieza
		viewport.add_child(instancia)
		var caja := AABB(malla.get_aabb().position + offset, malla.get_aabb().size)
		aabb = caja if i == 0 else aabb.merge(caja)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	viewport.add_child(luz)
	var relleno := DirectionalLight3D.new()
	relleno.light_energy = 0.4
	relleno.rotation_degrees = Vector3(-20.0, 145.0, 0.0)
	viewport.add_child(relleno)

	var centro := aabb.get_center()
	var radio: float = maxf(0.2, aabb.get_longest_axis_size()) * 0.85
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = radio * 2.0
	camara.position = centro + direccion_camara * radio
	viewport.add_child(camara)
	padre.add_child(viewport)
	camara.look_at(centro, Vector3.UP)

	return viewport.get_texture()
```

- [ ] **Step 2: Reescribir `Hotbar.gd` para delegar en `MiniaturaRenderer`**

Elimina las constantes `NOMBRE_FISICO_BIBLIOTECA` (líneas 79-81), `RUTA_BIBLIOTECA` (línea 21) y `RESOLUCION_ICONO` (línea 105) de `Hotbar.gd` — las tres pasan a vivir solo en `MiniaturaRenderer.gd` (Step 1); `RUTA_BIBLIOTECA` queda sin ningún otro uso en este archivo tras el Step 2 de abajo. Agrega el preload nuevo junto a los otros (línea 19-20):

```gdscript
const TemaHUD = preload("res://scripts/TemaHUD.gd")
const NiveladorTerrenoScript = preload("res://scripts/NiveladorTerreno.gd")
const MiniaturaRendererScript = preload("res://scripts/MiniaturaRenderer.gd")
```

Reemplaza el cuerpo de `_malla_de_item()` (líneas ~175-182):

```gdscript
func _malla_de_item(nombre_item: String) -> Mesh:
	if _biblioteca == null:
		_biblioteca = MiniaturaRendererScript.cargar_biblioteca()
	return MiniaturaRendererScript.malla_de_item(_biblioteca, nombre_item)
```

Reemplaza el cuerpo de `_renderizar_icono()` (líneas ~190-229) por:

```gdscript
func _renderizar_icono(piezas: Array) -> Texture2D:
	return MiniaturaRendererScript.renderizar(piezas, Vector3(1, 1, 1), self)
```

- [ ] **Step 3: Actualizar los comentarios de `PanelContextual.gd` que referencian la función movida**

```gdscript
## Miniatura del bloque (ver MiniaturaRenderer.renderizar()). Solo la usa
## mostrar_bloque_temporal().
```

(línea 19) y el comentario equivalente de la línea 200 (`## que Hotbar._renderizar_icono()),` → `## que MiniaturaRenderer.renderizar()),`).

- [ ] **Step 4: Crear el test del nuevo módulo**

`godot/scripts/MiniaturaRendererTest.gd`:

```gdscript
extends Node

## Pruebas de MiniaturaRenderer.gd (mismo patrón que BlueprintsTest.gd).
## Corre MiniaturaRendererTest.tscn y revisa el panel "Output": debe imprimir
## todas las pruebas y la línea final, sin ningún error de assert().

const MiniaturaRenderer = preload("res://scripts/MiniaturaRenderer.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: malla_de_item() devuelve una malla real para un tipo conocido ===")
	var biblioteca: MeshLibrary = MiniaturaRenderer.cargar_biblioteca()
	assert(biblioteca != null, "BlockLibrary.res debe cargar")
	var malla: Mesh = MiniaturaRenderer.malla_de_item(biblioteca, "bloque_piedra")
	assert(malla != null, "bloque_piedra tiene malla real")

	print("\n=== TEST 2: malla_de_item() resuelve el alias adobe -> tierra_compactada ===")
	var malla_adobe: Mesh = MiniaturaRenderer.malla_de_item(biblioteca, "adobe")
	var malla_directa: Mesh = MiniaturaRenderer.malla_de_item(biblioteca, "tierra_compactada")
	assert(malla_adobe != null and malla_adobe == malla_directa, "adobe usa la misma malla que tierra_compactada")

	print("\n=== TEST 3: malla_de_item() devuelve null para un ítem que no existe en la biblioteca ===")
	assert(MiniaturaRenderer.malla_de_item(biblioteca, "no_existe_este_tipo") == null)

	print("\n=== TEST 4: renderizar() con una sola pieza devuelve una textura no nula ===")
	var padre := Node.new()
	add_child(padre)
	var pieza: Array = [[malla, Vector3.ZERO, null]]
	var textura: Texture2D = MiniaturaRenderer.renderizar(pieza, Vector3(1, 1, 1), padre)
	assert(textura != null, "renderizar() con una pieza real devuelve una Texture2D")

	print("\n=== TEST 5: renderizar() con varias piezas en distintas posiciones no revienta ===")
	var piezas: Array = [
		[malla, Vector3.ZERO, null],
		[malla, Vector3(1, 0, 0), null],
		[malla, Vector3(0, 1, 0), null],
	]
	var textura_multi: Texture2D = MiniaturaRenderer.renderizar(piezas, Vector3(1, 1, -1), padre)
	assert(textura_multi != null, "renderizar() con varias piezas devuelve una Texture2D")

	print("\n=== Las 5 pruebas de MiniaturaRenderer pasaron correctamente ===")
```

`godot/scenes/MiniaturaRendererTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MiniaturaRendererTest.gd" id="1"]

[node name="MiniaturaRendererTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 5: Correr el nuevo test y confirmar que pasa**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/MiniaturaRendererTest.tscn > /tmp/miniatura_renderer.txt 2>&1`
Expected: el archivo termina con "=== Las 5 pruebas de MiniaturaRenderer pasaron correctamente ===" y ningún `Assertion failed`.

- [ ] **Step 6: Correr `HUDTest.tscn` para confirmar que la hotbar no cambió de comportamiento**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/HUDTest.tscn > /tmp/hud_task1.txt 2>&1`
Expected: termina con "HUDTest: todas las pruebas pasaron" (el TEST 4/4b de Hotbar sigue pasando exactamente igual que antes del refactor).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/MiniaturaRenderer.gd godot/scripts/MiniaturaRendererTest.gd godot/scenes/MiniaturaRendererTest.tscn godot/scripts/Hotbar.gd godot/scripts/PanelContextual.gd
git commit -m "$(cat <<'EOF'
refactor: extraer MiniaturaRenderer.gd del renderizador de íconos de Hotbar

Hotbar.gd sigue viéndose exactamente igual; el módulo compartido lo
va a reutilizar BarraModos.gd para las miniaturas de construcciones.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `BlueprintValidator.rotar_celdas_3d()` — extraer la rotación 90° de celdas

Extrae la fórmula de rotación que ya usa `CamaraCenital._rotar_blueprint()` a una función pura reutilizable, y hace que `_rotar_blueprint()` la use (sin cambiar su comportamiento).

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd` (agregar función nueva, cerca de `estructura_a_blueprint()`, línea ~529)
- Modify: `godot/scripts/BlueprintValidatorTest.gd:111,2496` (agregar TEST 90, actualizar el conteo final)
- Modify: `godot/scripts/CamaraCenital.gd:1434-1450`

**Interfaces:**
- Consumes: nada nuevo (solo `Vector3i`, `Dictionary` de GDScript).
- Produces: `BlueprintValidator.rotar_celdas_3d(celdas_3d: Dictionary, profundidad_previa: int) -> Dictionary` — usada por `CamaraCenital._rotar_blueprint()` (esta task) y por `BarraModos._celdas_residencial_giradas()` (Task 3).

- [ ] **Step 1: Escribir el test que falla primero**

En `godot/scripts/BlueprintValidatorTest.gd`, agrega antes de la línea final `print("\n=== Las 89 pruebas...`:

```gdscript
	print("\n=== TEST 90: rotar_celdas_3d() aplica la misma fórmula que CamaraCenital._rotar_blueprint() y 4 giros vuelven al original ===")
	var celdas_90 := {
		Vector3i(0, 0, 0): "bloque_madera",
		Vector3i(1, 0, 0): "bloque_piedra",
		Vector3i(0, 1, 0): "puerta_inferior",
	}
	# Caja de ancho 2 (x: 0-1), profundidad 1 (z: 0): girar 90° la lleva a
	# ancho 1, profundidad 2 — (x, z) -> (profundidad_previa - 1 - z, x).
	var giradas_90: Dictionary = BlueprintValidator.rotar_celdas_3d(celdas_90, 1)
	assert(giradas_90[Vector3i(0, 0, 0)] == "bloque_madera", "(0,0,0) -> (1-1-0, 0) = (0,0)")
	assert(giradas_90[Vector3i(0, 0, 1)] == "bloque_piedra", "(1,0,0) -> (1-1-0, 1) = (0,1) en x,z -> Vector3i(0,0,1)")
	assert(giradas_90[Vector3i(0, 1, 0)] == "puerta_inferior", "la capa Y no cambia con la rotación")
	assert(giradas_90.size() == celdas_90.size(), "mismo número de celdas, ninguna se pierde")

	# 4 giros vuelven al original: cada giro intercambia ancho/profundidad,
	# así que hay que alternar la profundidad pasada en cada llamada (mismo
	# manejo que CamaraCenital._rotar_blueprint() hace con _blueprint_activo).
	var celdas_vuelta := celdas_90.duplicate()
	var ancho_vuelta := 2
	var profundidad_vuelta := 1
	for _i in range(4):
		celdas_vuelta = BlueprintValidator.rotar_celdas_3d(celdas_vuelta, profundidad_vuelta)
		var previo := ancho_vuelta
		ancho_vuelta = profundidad_vuelta
		profundidad_vuelta = previo
	assert(celdas_vuelta == celdas_90, "4 giros de 90° devuelven las celdas originales")

	print("\n=== Las 90 pruebas de BlueprintValidator pasaron correctamente ===")
```

Borra el `print("\n=== Las 89 pruebas de BlueprintValidator pasaron correctamente ===")` anterior (línea 2496) — el bloque de arriba ya incluye el nuevo mensaje final de 90.

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/Test.tscn > /tmp/bv_fail.txt 2>&1`
Expected: falla con "Invalid call. Nonexistent function 'rotar_celdas_3d'" (o similar, `BlueprintValidator` todavía no tiene esa función).

- [ ] **Step 3: Implementar `rotar_celdas_3d()`**

En `godot/scripts/BlueprintValidator.gd`, cerca de `estructura_a_blueprint()` (línea ~529), agrega:

```gdscript
## Rota "celdas_3d" (Vector3i local -> tipo de bloque) 90° horario, misma
## fórmula que usa CamaraCenital._rotar_blueprint() para el fantasma en
## colocación: (x, z) -> (profundidad_previa - 1 - z, x), la capa Y no
## cambia. "profundidad_previa" es el tamaño en Z de la caja ANTES de este
## giro (después del giro, la caja mide "profundidad_previa" de ancho). Pura:
## no muta "celdas_3d", devuelve un Dictionary nuevo — quien la llama decide
## si reemplaza su propio estado (ver CamaraCenital._rotar_blueprint()) o
## solo quiere una vista rotada sin tocar nada guardado (ver
## BarraModos._celdas_residencial_giradas()).
static func rotar_celdas_3d(celdas_3d: Dictionary, profundidad_previa: int) -> Dictionary:
	var celdas_rotadas: Dictionary = {}
	for rel in celdas_3d:
		var punto_rotado := Vector3i(profundidad_previa - 1 - rel.z, rel.y, rel.x)
		celdas_rotadas[punto_rotado] = celdas_3d[rel]
	return celdas_rotadas
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/Test.tscn > /tmp/bv_pass.txt 2>&1`
Expected: termina con "=== Las 90 pruebas de BlueprintValidator pasaron correctamente ===", ningún `Assertion failed`.

- [ ] **Step 5: Hacer que `_rotar_blueprint()` use la función extraída**

En `godot/scripts/CamaraCenital.gd`, reemplaza las líneas 1434-1442 (desde `func _rotar_blueprint()` hasta el cierre del bucle de `celdas_rotadas`):

```gdscript
func _rotar_blueprint() -> void:
	var ancho_previo: int = _blueprint_activo["ancho"]
	var profundidad_previa: int = _blueprint_activo["profundidad"]

	_blueprint_activo["celdas_3d"] = BlueprintValidator.rotar_celdas_3d(_blueprint_activo["celdas_3d"], profundidad_previa)
```

(el resto de la función, desde `var huella_rotada` en adelante, queda igual — solo se reemplaza el bucle manual de `celdas_rotadas` por la llamada a `BlueprintValidator.rotar_celdas_3d()`).

- [ ] **Step 6: Correr `PuestosPrevisualizacionTest.tscn` (ejercita colocación de blueprint/rotación indirectamente) para confirmar que no se rompió nada**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/PuestosPrevisualizacionTest.tscn > /tmp/puestos_prev.txt 2>&1`
Expected: termina sin ningún `Assertion failed` (mismo resultado que antes de esta task — esta task no cambia su comportamiento, solo confirma que el refactor de `_rotar_blueprint()` no rompió la colocación de puestos, que comparte código con la de blueprints).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd godot/scripts/CamaraCenital.gd
git commit -m "$(cat <<'EOF'
refactor: extraer BlueprintValidator.rotar_celdas_3d() de CamaraCenital._rotar_blueprint()

Misma fórmula, mismo comportamiento; la reutiliza la previsualización
de BarraModos para rotar la miniatura de Residencial sin duplicar la
lógica de rotación de un blueprint completo.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Miniaturas isométricas en el submenú Construir (`BarraModos.gd`)

Botones de Residencial/Mina/Caza/Madera/Pesca con miniatura 3D real, tamaño fijo, atenuado de Residencial sin blueprint, y la API de rotación que Task 4 conectará desde `CamaraCenital`.

**Files:**
- Modify: `godot/scripts/BarraModos.gd`
- Modify: `godot/scripts/HUD.gd` (delega `set_giros_construccion`)
- Modify: `godot/scripts/HUDTest.gd:316-341` (extender `probar_barra_modos()`)

**Interfaces:**
- Consumes: `MiniaturaRenderer.cargar_biblioteca()`/`malla_de_item()`/`renderizar()` (Task 1); `BlueprintValidator.rotar_celdas_3d()` (Task 2); `PlantillasPuesto.celdas(tipo: String, giros: int) -> Dictionary` (ya existe); `Blueprints.obtener(zona: String) -> Dictionary` (ya existe, autoload).
- Produces: `BarraModos.set_giros(giros: int) -> void` (usada por `HUD.set_giros_construccion()`, Task 4); `HUD.set_giros_construccion(giros: int) -> void` (usada por `CamaraCenital`, Task 4).

- [ ] **Step 1: Escribir las pruebas que fallan primero (extender `probar_barra_modos()` en `HUDTest.gd`)**

Después de la línea 341 (`assert(not barra.construccion_visible() and not barra._panel_sub.visible)`) y antes del bloque de "Un clic emite la señal" (línea ~343), inserta:

```gdscript

	print("=== TEST 3b: Residencial atenuado sin blueprint, normal con uno declarado ===")
	assert(Blueprints.obtener("residencial_investigacion").is_empty(), "arranca vacío en esta escena de prueba")
	barra.set_modo("construir", "")
	assert(barra._botones_construccion["residencial"].modulate.a < 1.0, "sin blueprint: atenuado")
	Blueprints.guardar({"zona_permitida": "residencial_investigacion", "ancho": 1, "profundidad": 1, "celdas_3d": {Vector3i.ZERO: "bloque_madera"}, "huella_relativa": [Vector2i.ZERO]})
	barra.set_modo("construir", "")
	assert(barra._botones_construccion["residencial"].modulate.a == 1.0, "con blueprint declarado: ya no atenuado")

	print("\n=== TEST 3c: las miniaturas de construcción se generan con malla real y cambian con set_giros() ===")
	barra.set_giros(0)
	var miniatura_mina: TextureRect = barra._miniaturas_construccion["mina"]
	assert(miniatura_mina.texture != null, "mina tiene celdas con malla real: miniatura no vacía")
	var miniatura_residencial: TextureRect = barra._miniaturas_construccion["residencial"]
	assert(miniatura_residencial.texture != null, "con el blueprint de un solo bloque_madera declarado arriba, la miniatura no está vacía")
	barra.set_giros(1)
	assert(barra._giros_menu == 1)
	barra.set_giros(5)
	assert(barra._giros_menu == 1, "posmod(5, 4) == 1, mismo valor que antes: set_giros() normaliza a 0-3")
```

- [ ] **Step 2: Correr `HUDTest.tscn` y confirmar que falla**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/HUDTest.tscn > /tmp/hud_fail.txt 2>&1`
Expected: falla en TEST 3b (`_botones_construccion["residencial"].modulate.a` sigue siendo `1.0`, `_miniaturas_construccion`/`set_giros` no existen todavía).

- [ ] **Step 3: Implementar las miniaturas y el atenuado en `BarraModos.gd`**

Agrega los preloads y constantes nuevas cerca de la línea 14:

```gdscript
const TemaHUD = preload("res://scripts/TemaHUD.gd")
const MiniaturaRendererScript = preload("res://scripts/MiniaturaRenderer.gd")
const BlueprintValidatorScript = preload("res://scripts/BlueprintValidator.gd")
const PlantillasPuestoScript = preload("res://scripts/PlantillasPuesto.gd")

## Tipos sin malla real en BlockLibrary (a propósito: otro sistema los
## dibuja — ver VoxelWorld/Puertas.gd/TranslucidosRenderer.gd). La miniatura
## de una construcción completa los salta: es una vista general del
## edificio, no necesita reproducir cada mueble.
const TIPOS_SIN_MALLA_MINIATURA := ["vidrio", "puerta_inferior", "puerta_superior"]

## Esquina superior-derecha-FRONTAL (el frente/puerta de plantillas y
## blueprints mira a -Z, ver PlantillasPuesto.gd) — no la diagonal simétrica
## que usa Hotbar para bloques sueltos sin frente definido.
const DIRECCION_CAMARA_MINIATURA := Vector3(1, 1, -1)
const TAMANO_MINIATURA := 40.0
const ZONA_RESIDENCIAL := "residencial_investigacion"
```

Agrega las variables de instancia nuevas junto a las existentes (cerca de la línea 43):

```gdscript
var _miniaturas_construccion := {}  # "residencial" o tipo de puesto -> TextureRect
var _biblioteca_construccion: MeshLibrary
var _giros_menu := 0
```

Reemplaza el bucle de `CONSTRUCCIONES` en `_ready()` (líneas 75-84) para usar un constructor de botón dedicado:

```gdscript
	var columna_sub := _nueva_columna(_panel_sub)
	for puesto in CONSTRUCCIONES:
		var tipo: String = puesto[0]
		var boton := _crear_boton_construccion(tipo, "%s [%s]" % [puesto[1], puesto[2]])
		boton.pressed.connect(func() -> void:
			construccion_pedida.emit(tipo)
			_refrescar()
		)
		columna_sub.add_child(boton)
		_botones_construccion[tipo] = boton
```

Agrega el constructor nuevo cerca de `_crear_boton()` (después de la línea 111):

```gdscript
## Botón del submenú Construir: miniatura 3D (espacio fijo TAMANO_MINIATURA x
## TAMANO_MINIATURA, ver _actualizar_miniaturas()) arriba, texto+tecla abajo
## — a diferencia de _crear_boton(), que solo pone texto. Los hijos llevan
## MOUSE_FILTER_IGNORE para que el clic siga llegando al Button de abajo.
func _crear_boton_construccion(tipo: String, texto: String) -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.custom_minimum_size = Vector2(88, 64)
	TemaHUD.estilizar_boton(boton)

	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 2)

	var miniatura := TextureRect.new()
	miniatura.custom_minimum_size = Vector2(TAMANO_MINIATURA, TAMANO_MINIATURA)
	miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	miniatura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(miniatura)
	_miniaturas_construccion[tipo] = miniatura

	var etiqueta := TemaHUD.etiqueta(texto)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(etiqueta)

	boton.add_child(columna)
	return boton
```

Agrega las funciones de renderizado (después de `_crear_boton_construccion()`):

```gdscript
## Cambia el giro compartido de las 5 miniaturas (0-3, normalizado con
## posmod) y las vuelve a renderizar. La llama CamaraCenital cada vez que
## Ctrl+rueda rota un puesto o un blueprint en colocación — ver
## HUD.set_giros_construccion().
func set_giros(giros: int) -> void:
	_giros_menu = posmod(giros, 4)
	_actualizar_miniaturas()


func _actualizar_miniaturas() -> void:
	for tipo in _miniaturas_construccion:
		(_miniaturas_construccion[tipo] as TextureRect).texture = _miniatura_de(tipo)


func _miniatura_de(tipo: String) -> Texture2D:
	var celdas: Dictionary = _celdas_residencial_giradas() if tipo == "residencial" else PlantillasPuestoScript.celdas(tipo, _giros_menu)
	if celdas.is_empty():
		return null
	if _biblioteca_construccion == null:
		_biblioteca_construccion = MiniaturaRendererScript.cargar_biblioteca()
	var piezas: Array = []
	for celda in celdas:
		var tipo_bloque: String = celdas[celda]
		if TIPOS_SIN_MALLA_MINIATURA.has(tipo_bloque):
			continue
		var malla: Mesh = MiniaturaRendererScript.malla_de_item(_biblioteca_construccion, tipo_bloque)
		if malla != null:
			piezas.append([malla, Vector3(celda.x, celda.y, celda.z), null])
	if piezas.is_empty():
		return null
	return MiniaturaRendererScript.renderizar(piezas, DIRECCION_CAMARA_MINIATURA, self)


## Celdas del blueprint residencial declarado, giradas _giros_menu cuartos de
## vuelta con la misma fórmula que CamaraCenital._rotar_blueprint() (vía
## BlueprintValidator.rotar_celdas_3d()) — sin mutar el blueprint guardado en
## Blueprints, solo una vista para la miniatura. {} si no hay ninguno
## declarado todavía.
func _celdas_residencial_giradas() -> Dictionary:
	var blueprint: Dictionary = Blueprints.obtener(ZONA_RESIDENCIAL)
	if blueprint.is_empty():
		return {}
	var celdas: Dictionary = blueprint["celdas_3d"]
	var ancho: int = blueprint["ancho"]
	var profundidad: int = blueprint["profundidad"]
	for _i in range(_giros_menu):
		celdas = BlueprintValidatorScript.rotar_celdas_3d(celdas, profundidad)
		var previo := ancho
		ancho = profundidad
		profundidad = previo
	return celdas
```

Modifica `_refrescar()` (líneas 123-132) para atenuar Residencial y refrescar las miniaturas:

```gdscript
func _refrescar() -> void:
	var activo := _modo if _modo != "" else "ver"
	for id in _botones:
		_botones[id].set_pressed_no_signal(id == activo)
	_panel_sub.visible = _modo == "construir"
	for tipo in _botones_construccion:
		_botones_construccion[tipo].set_pressed_no_signal(tipo == _puesto)
	# Residencial sigue siendo clickeable sin blueprint declarado (el clic
	# dispara la misma notificación de siempre, ver CamaraCenital.
	# _alternar_modo_colocar_blueprint()); solo se atenúa como pista visual.
	_botones_construccion["residencial"].modulate = Color(1.0, 1.0, 1.0, 0.4 if Blueprints.obtener(ZONA_RESIDENCIAL).is_empty() else 1.0)
	_panel_zonas.visible = _modo == "zonas"
	for tipo in _botones_zona:
		_botones_zona[tipo].set_pressed_no_signal(tipo == _puesto)
	if _modo == "construir":
		_actualizar_miniaturas()
```

- [ ] **Step 4: Agregar `HUD.set_giros_construccion()`**

En `godot/scripts/HUD.gd`, cerca de `set_modo()` (línea ~161), agrega:

```gdscript
## Rotación compartida de las 5 miniaturas del submenú Construir (0-3, ver
## BarraModos.set_giros()); CamaraCenital la llama cada vez que Ctrl+rueda
## rota un puesto o un blueprint en colocación.
func set_giros_construccion(giros: int) -> void:
	_barra_modos.set_giros(giros)
```

- [ ] **Step 5: Correr `HUDTest.tscn` y confirmar que pasa**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/HUDTest.tscn > /tmp/hud_pass.txt 2>&1`
Expected: termina con "HUDTest: todas las pruebas pasaron", ningún `Assertion failed`.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/BarraModos.gd godot/scripts/HUD.gd godot/scripts/HUDTest.gd
git commit -m "$(cat <<'EOF'
feat: miniaturas isométricas y atenuado de Residencial en el menú Construir

Cada opción del submenú Construir (Residencial + los 4 puestos) suma
una miniatura 3D real de tamaño fijo junto a su texto, con la malla y
el material reales del edificio. Residencial se atenúa visualmente
mientras no haya ningún blueprint declarado.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `CamaraCenital` empuja la rotación en curso al HUD

Conecta las dos rotaciones existentes (puesto y blueprint) a `HUD.set_giros_construccion()`, y reinicia el giro compartido cada vez que empieza una colocación nueva.

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd:218-245` (nueva variable), `:1335-1357,1412-1417,1465-1491` (llamadas nuevas)

**Interfaces:**
- Consumes: `hud.set_giros_construccion(giros: int)` (Task 3).

- [ ] **Step 1: Agregar el contador `_giros_blueprint`**

Junto a `var _blueprint_activo: Dictionary = {}` (línea 245), agrega:

```gdscript
## Giro actual del blueprint en colocación (0-3), solo para sincronizar la
## miniatura del menú Construir (HUD.set_giros_construccion()) — a
## diferencia de _giros_puesto, _rotar_blueprint() no necesitaba llevar un
## contador propio antes de esto (rotaba las celdas directo).
var _giros_blueprint := 0
```

- [ ] **Step 2: Empujar el giro en `_rotar_huella_puesto()`**

En `godot/scripts/CamaraCenital.gd`, al final de `_rotar_huella_puesto()` (línea ~1417, después de `_overlay_vigente = SIN_RESUMEN`):

```gdscript
func _rotar_huella_puesto() -> void:
	var ancho_previo := _ancho_puesto_activo
	_ancho_puesto_activo = _alto_puesto_activo
	_alto_puesto_activo = ancho_previo
	_giros_puesto = (_giros_puesto + 1) % 4
	_overlay_vigente = SIN_RESUMEN
	hud.set_giros_construccion(_giros_puesto)
```

- [ ] **Step 3: Empujar el giro en `_rotar_blueprint()`**

Al final de `_rotar_blueprint()` (después de `_mostrar_huella_blueprint(true)`, que ya quedó como última línea tras la Task 2):

```gdscript
	_giros_blueprint = (_giros_blueprint + 1) % 4
	hud.set_giros_construccion(_giros_blueprint)
```

- [ ] **Step 4: Reiniciar el giro compartido al empezar cada colocación nueva**

En `_alternar_modo_colocar_puesto()` (líneas 1347-1356), la parte final queda así (única línea nueva: `hud.set_giros_construccion(0)`, justo después de `hud.set_modo(...)`):

```gdscript
	modo_colocar_puesto = true
	_tipo_puesto_activo = tipo
	_ancho_puesto_activo = ancho
	_alto_puesto_activo = alto
	_giros_puesto = 0
	_giros_fantasma_puesto = -1
	_overlay_vigente = SIN_RESUMEN
	hud.set_modo("construir", tipo)
	hud.set_giros_construccion(0)
	hud.mostrar_contexto_puesto(tipo, false, {})
	print("Modo colocar %s activo: haz clic para confirmar (misma tecla de nuevo para cancelar)." % tipo)
```

(el HUD ya no muestra el giro heredado de la construcción anterior — ver "Review Focus".)

En `_alternar_modo_colocar_blueprint()` (líneas 1485-1491), la parte final queda así (única línea nueva: `hud.set_giros_construccion(0)`, justo después de `hud.set_modo(...)`):

```gdscript
	_blueprint_activo = blueprint.duplicate()
	_crear_huella_blueprint(_blueprint_activo["celdas_3d"])
	modo_colocar_blueprint = true
	_giros_blueprint = 0
	_resumen_blueprint_vigente = SIN_RESUMEN
	_overlay_vigente = SIN_RESUMEN
	hud.set_modo("construir", "residencial")
	hud.set_giros_construccion(0)
	print("Modo colocar blueprint activo: haz clic dentro de una zona residencial para confirmar (B de nuevo para cancelar, Ctrl+rueda para rotar).")
```

- [ ] **Step 5: Verificación manual (esta task no tiene prueba automatizada — `_rotar_huella_puesto()`/`_rotar_blueprint()` dependen de un `VoxelWorld`/`NiveladorTerreno`/`hud` reales ya cubiertos indirectamente por `PuestosPrevisualizacionTest`, pero la sincronización con el HUD solo se ve jugando)**

Abre `godot/scenes/Test.tscn` o la escena principal en el editor, juega, entra a Construir (`B`), coloca una mina (`M`), gira con Ctrl+rueda y confirma en pantalla que las 5 miniaturas del menú giran juntas; cambia a Pesca (`F`) y confirma que el giro vuelve a 0 (miniaturas en su orientación original) antes de que el jugador vuelva a girar.

- [ ] **Step 6: Correr `PuestosPrevisualizacionTest.tscn` y `Test.tscn` para confirmar que no se rompió nada**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/PuestosPrevisualizacionTest.tscn > /tmp/puestos_task4.txt 2>&1`
Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/Test.tscn > /tmp/bv_task4.txt 2>&1`
Expected: ambos terminan sin ningún `Assertion failed` (estas pruebas no invocan `hud.set_giros_construccion()` directamente — `PuestosPrevisualizacionTest` usa `HUDScript.new()` real, así que la llamada nueva no debe reventar nada, solo confirma que `BarraModos.set_giros()` tolera que la llamen fuera de "construir").

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "$(cat <<'EOF'
feat: sincronizar la rotación de puesto/blueprint con las miniaturas del HUD

Ctrl+rueda empuja el giro actual a HUD.set_giros_construccion(); cada
colocación nueva reinicia el giro compartido a 0.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Tecla `B` / botón "Construir" abren el menú sin activar la colocación

Desacopla "abrir el submenú Construir" de "empezar a colocar Residencial", con un estado propio (`_menu_construir_abierto`) y una segunda pulsación de `B` que cierra todo.

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd:168-245` (nueva variable), `:1278-1279,1370-1374,1513-1518` (nuevas funciones y llamadas)
- Create: `godot/scenes/CamaraCenitalModosTest.tscn`
- Create: `godot/scripts/CamaraCenitalModosTest.gd`

**Interfaces:**
- Produces: `CamaraCenital._alternar_modo_menu_construir() -> void`, `CamaraCenital._salir_de_modo_menu_construir() -> void`.

- [ ] **Step 1: Escribir el test que falla primero**

`godot/scripts/CamaraCenitalModosTest.gd`:

```gdscript
extends Node

## Pruebas de _alternar_modo_menu_construir()/_salir_de_modo_menu_construir()
## (tecla B / botón "Construir" de BarraModos, desacoplados de activar una
## colocación — ver docs/superpowers/specs/2026-09-30-previsualizacion-
## construcciones-cenital-design.md, Sección 6). Solo cubre el camino "abrir
## el menú vacío / cerrarlo de nuevo": el camino que cancela una colocación
## YA activa (mina/blueprint en curso) necesita overlay/nivelador reales, no
## una CamaraCenital sin árbol (mismo motivo que PlantillasPuestoTest.gd no
## instancia el mundo completo) — ese camino se verifica jugando, ver Task 5
## del plan. Corre esta escena y revisa el panel "Output": debe imprimir
## todas las pruebas y la línea final, sin ningún error de assert().

const CamaraCenitalScript = preload("res://scripts/CamaraCenital.gd")
const HUDScript = preload("res://scripts/HUD.gd")


func _ready() -> void:
	ejecutar_pruebas()


func _camara() -> Camera3D:
	var camara: Camera3D = CamaraCenitalScript.new()
	camara.hud = HUDScript.new()
	return camara


func ejecutar_pruebas() -> void:
	print("=== TEST 1: primera pulsación abre el menú sin activar ninguna colocación ===")
	var camara: Camera3D = _camara()
	assert(not camara._menu_construir_abierto)
	camara._alternar_modo_menu_construir()
	assert(camara._menu_construir_abierto, "el menú queda marcado como abierto")
	assert(not camara.modo_colocar_blueprint, "abrir el menú NO activa la colocación de Residencial")
	assert(not camara.modo_colocar_puesto, "abrir el menú NO activa la colocación de un puesto")
	camara.hud.queue_free()

	print("\n=== TEST 2: segunda pulsación con el menú abierto y nada activo lo cierra ===")
	var camara2: Camera3D = _camara()
	camara2._alternar_modo_menu_construir()
	camara2._alternar_modo_menu_construir()
	assert(not camara2._menu_construir_abierto, "segunda pulsación cierra el menú")
	assert(not camara2.modo_colocar_blueprint and not camara2.modo_colocar_puesto)
	camara2.hud.queue_free()

	print("\n=== TEST 3: _giros_menu se reinicia a 0 cada vez que se abre el menú ===")
	var camara3: Camera3D = _camara()
	camara3._alternar_modo_menu_construir()
	assert(camara3.hud._barra_modos._giros_menu == 0, "el HUD recibe 0 al abrir")
	camara3.hud.queue_free()

	print("\n=== Las 3 pruebas de CamaraCenitalModosTest pasaron correctamente ===")
```

`godot/scenes/CamaraCenitalModosTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/CamaraCenitalModosTest.gd" id="1"]

[node name="CamaraCenitalModosTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/CamaraCenitalModosTest.tscn > /tmp/modos_fail.txt 2>&1`
Expected: falla con "Invalid get index '_menu_construir_abierto'" (la variable todavía no existe).

- [ ] **Step 3: Agregar el estado y las funciones nuevas en `CamaraCenital.gd`**

Junto a `var modo_colocar_blueprint := false` (línea 244), agrega:

```gdscript
## true mientras el submenú Construir está visible, con o sin una opción
## activa — a diferencia de modo_colocar_blueprint/modo_colocar_puesto, que
## solo son true cuando hay una construcción CONCRETA en colocación. Lo
## controla _alternar_modo_menu_construir() (tecla B / botón "Construir" de
## BarraModos): abrir el menú ya no activa la colocación de Residencial
## directamente (decisión del usuario, 2026-09-30).
var _menu_construir_abierto := false
```

`_alternar_modo_colocar_blueprint()` no se toca en este Step (sigue exactamente igual: sigue siendo la función que el clic en "Residencial" llama para activar la colocación de verdad). Agrega las dos funciones nuevas justo antes de ella (antes de la línea 1465):

```gdscript
## Tecla B / clic en el botón principal "Construir" de BarraModos: abre o
## cierra el submenú Construir SIN activar ninguna colocación todavía (a
## diferencia de antes, cuando B intentaba colocar Residencial directamente
## y si no había blueprint declarado ni siquiera abría el menú — decisión
## del usuario, 2026-09-30). Elegir una opción dentro del menú ya abierto
## (clic en "Residencial" o en un puesto) sigue llamando a
## _alternar_modo_colocar_blueprint()/_alternar_puesto_por_tipo() sin
## cambios, exactamente igual que antes.
func _alternar_modo_menu_construir() -> void:
	if _menu_construir_abierto or modo_colocar_blueprint or modo_colocar_puesto:
		_salir_de_modo_menu_construir()
		return
	_salir_de_modo_zonificar()
	if modo_trazar_via:
		_salir_de_modo_trazar_via()
	_menu_construir_abierto = true
	hud.set_giros_construccion(0)
	hud.set_modo("construir", "")


## Segunda pulsación de B (o "Construir" de nuevo) con el menú abierto —
## con o sin una opción activa: cierra todo el sistema de construcción y
## vuelve a "Ver", igual que ya hacen Z/V con sus propios modos (nunca
## reactiva Residencial como atajo, aunque comparta tecla con el botón
## principal).
func _salir_de_modo_menu_construir() -> void:
	if modo_colocar_blueprint:
		_salir_de_modo_colocar_blueprint()
	if modo_colocar_puesto:
		_salir_de_modo_colocar_puesto()
	_menu_construir_abierto = false
	hud.set_modo("")
```

- [ ] **Step 4: Cablear `B` y el botón principal a la nueva función**

En `_unhandled_input()` (línea 1278):

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_menu_construir()
```

En `_on_modo_pedido()` (línea ~1371-1375):

```gdscript
func _on_modo_pedido(modo: String) -> void:
	match modo:
		"ver": salir_de_todos_los_modos()
		"construir": _alternar_modo_menu_construir()
		"zonas": _alternar_modo_zonificar()
		"vias": _alternar_modo_trazar_via()
```

`_on_construccion_pedida()` (línea 1380-1384) queda exactamente igual — sigue llamando a `_alternar_modo_colocar_blueprint()`/`_alternar_puesto_por_tipo()` sin cambios.

- [ ] **Step 5: `salir_de_todos_los_modos()` también limpia el menú neutral**

En `salir_de_todos_los_modos()` (línea 1513):

```gdscript
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_colocar_blueprint()
	_salir_de_modo_colocar_puesto()
	_salir_de_modo_zonificar()
	_salir_de_modo_trazar_via()
	_menu_construir_abierto = false
	hud.cerrar_panel_puesto()
```

(cubre ESC y el cambio a 1ª persona con el menú Construir abierto pero sin nada colocándose — ver "Review Focus".)

- [ ] **Step 6: Correr el test y confirmar que pasa**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/CamaraCenitalModosTest.tscn > /tmp/modos_pass.txt 2>&1`
Expected: termina con "=== Las 3 pruebas de CamaraCenitalModosTest pasaron correctamente ===", ningún `Assertion failed`.

- [ ] **Step 7: Correr `PuestosPrevisualizacionTest.tscn` y `Test.tscn` para confirmar que no se rompió nada**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/PuestosPrevisualizacionTest.tscn > /tmp/puestos_task5.txt 2>&1`
Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/Test.tscn > /tmp/bv_task5.txt 2>&1`
Expected: ambos terminan sin ningún `Assertion failed`.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/CamaraCenital.gd godot/scripts/CamaraCenitalModosTest.gd godot/scenes/CamaraCenitalModosTest.tscn
git commit -m "$(cat <<'EOF'
feat: B abre el menú Construir sin activar la colocación de Residencial

Antes, B intentaba colocar el blueprint directamente y ni siquiera
abría el menú si no había ninguno declarado. Ahora B/"Construir" solo
alternan la visibilidad del submenú; elegir una opción adentro sigue
activando la colocación real, sin cambios.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Placeholders de ícono en las barras Modos y Zonas

Deja el espacio y el mecanismo listos para arte futuro en Ver/Construir/Zonas/Vías y Zona A/Zona B/Borrar, sin dibujar ningún ícono real todavía (no hay arte).

**Files:**
- Modify: `godot/scripts/BarraModos.gd:16-36,48-95,105-111`
- Modify: `godot/scripts/HUDTest.gd:316-341`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `BarraModos._crear_boton(texto: String, tamano: Vector2, icono: Texture2D = null) -> Button` (firma ampliada, retrocompatible — todo llamador existente que no pase `icono` se sigue viendo exactamente igual).

- [ ] **Step 1: Escribir el test que falla primero**

En `HUDTest.gd`, dentro de `probar_barra_modos()`, después del bloque agregado en la Task 3 (TEST 3c), agrega:

```gdscript

	print("\n=== TEST 3d: _crear_boton() sin ícono se ve igual que antes; con ícono, antepone un TextureRect ===")
	var boton_sin_icono: Button = barra._crear_boton("Prueba", Vector2(88, 56))
	assert(boton_sin_icono.text == "Prueba", "sin ícono: el texto va directo en el Button, como siempre")
	var textura_prueba := PlaceholderTexture2D.new()
	var boton_con_icono: Button = barra._crear_boton("Prueba", Vector2(88, 56), textura_prueba)
	assert(boton_con_icono.text == "", "con ícono: el texto ya no va en el Button, va en un Label hijo")
	var encontro_icono := false
	for hijo in boton_con_icono.get_children():
		if hijo is TextureRect and (hijo as TextureRect).texture == textura_prueba:
			encontro_icono = true
	assert(encontro_icono, "el TextureRect con la textura pasada está entre los hijos del botón")
```

- [ ] **Step 2: Correr `HUDTest.tscn` y confirmar que falla**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/HUDTest.tscn > /tmp/hud_icono_fail.txt 2>&1`
Expected: falla con "Too many arguments for '_crear_boton()' call" (todavía no acepta el tercer parámetro).

- [ ] **Step 3: Ampliar `_crear_boton()` con el parámetro `icono` opcional**

Reemplaza `_crear_boton()` (líneas 105-111):

```gdscript
## "icono" es opcional (null en todos los llamadores hoy — no hay arte
## todavía, ver docs/superpowers/specs/2026-09-30-previsualizacion-
## construcciones-cenital-design.md, Sección 9): sin él, el botón se ve
## exactamente igual que siempre (texto directo en el Button). Con él,
## antepone un TextureRect de 24x24 y mueve el texto a un Label hijo — deja
## el mecanismo listo para cuando exista el ícono real de cada modo/zona.
func _crear_boton(texto: String, tamano: Vector2, icono: Texture2D = null) -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.custom_minimum_size = tamano
	TemaHUD.estilizar_boton(boton)
	if icono == null:
		boton.text = texto
		return boton

	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 2)

	var imagen := TextureRect.new()
	imagen.custom_minimum_size = Vector2(24, 24)
	imagen.texture = icono
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(imagen)

	var etiqueta := TemaHUD.etiqueta(texto)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(etiqueta)

	boton.add_child(columna)
	return boton
```

- [ ] **Step 4: Agregar el campo `icono` (null) a `MODOS` y `ZONAS`, y pasarlo en sus bucles**

Reemplaza `MODOS` (líneas 17-22):

```gdscript
## [id, nombre, tecla, ícono opcional (null: sin arte todavía)]
const MODOS := [
	["ver", "Ver", "Esc", null],
	["construir", "Construir", "B", null],
	["zonas", "Zonas", "Z", null],
	["vias", "Vías", "V", null],
]
```

Reemplaza `ZONAS` (líneas 32-36):

```gdscript
## [tipo de zona, nombre, tecla, ícono opcional (null: sin arte todavía)]
var ZONAS := [
	[Zonificacion.ZONAS_PINTABLES[0], "Zona A", "1", null],
	[Zonificacion.ZONAS_PINTABLES[1], "Zona B", "2", null],
	[Zonificacion.MARCADOR_BORRAR, "Borrar", "0", null],
]
```

En el bucle de `MODOS` dentro de `_ready()` (línea 66-68):

```gdscript
	for modo in MODOS:
		var id: String = modo[0]
		var boton := _crear_boton("%s\n[%s]" % [modo[1], modo[2]], Vector2(88, 56), modo[3])
```

En el bucle de `ZONAS` (línea 86-88):

```gdscript
	for zona in ZONAS:
		var tipo: String = zona[0]
		var boton := _crear_boton("%s [%s]" % [zona[1], zona[2]], Vector2(88, 36), zona[3])
```

- [ ] **Step 5: Correr `HUDTest.tscn` y confirmar que pasa**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/HUDTest.tscn > /tmp/hud_icono_pass.txt 2>&1`
Expected: termina con "HUDTest: todas las pruebas pasaron", ningún `Assertion failed`.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/BarraModos.gd godot/scripts/HUDTest.gd
git commit -m "$(cat <<'EOF'
feat: placeholder de ícono opcional en los botones de Modos y Zonas

Sin arte todavía (icono = null en todos los casos); deja el mecanismo
listo para cuando exista.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Verificación en vivo y documentación

**Files:**
- Modify: `docs/Pendientes y próximos pasos.md`

- [ ] **Step 1: Correr TODAS las escenas de prueba tocadas o afectadas**

Run cada una (mismo patrón que las tasks anteriores) y confirma que ninguna lanza `Assertion failed`: `Test.tscn`, `HUDTest.tscn`, `MiniaturaRendererTest.tscn`, `CamaraCenitalModosTest.tscn`, `PuestosPrevisualizacionTest.tscn`, `PlantillasPuestoTest.tscn`, `RecoleccionTest.tscn`, `BlueprintsTest.tscn`.

- [ ] **Step 2: Verificación manual en el editor (Godot 4.7)**

Abre la escena principal, juega y confirma a mano:
1. Pulsar `B` sin ningún blueprint residencial declarado abre el submenú Construir con Residencial visiblemente atenuado y los 4 puestos normales.
2. Clic en Residencial atenuado muestra la notificación "declara un edificio primero" y NO entra en modo colocación.
3. Declarar un edificio residencial y volver a abrir Construir: Residencial ya no está atenuado.
4. Activar cada puesto (`M`/`H`/`L`/`F` o clic) y confirmar que su miniatura muestra la huella real (5×5 la mina, 3×4 el maderero, etc.) dentro de la misma caja de tamaño fijo.
5. Con un puesto o Residencial en colocación, girar con Ctrl+rueda: las 5 miniaturas del menú rotan juntas, sincronizadas con el fantasma sobre el mapa.
6. Pulsar `B` dos veces seguidas cierra el menú sin activar Residencial como atajo.
7. Cambiar de un puesto a otro (p. ej. Mina → Pesca) sin salir del modo: la miniatura nueva empieza sin el giro heredado del puesto anterior.
8. La hotbar de 1ª persona (íconos de bloques sueltos) se ve exactamente igual que antes de este trabajo — confirma que el refactor de `MiniaturaRenderer` no la afectó.

- [ ] **Step 3: Actualizar `docs/Pendientes y próximos pasos.md`**

Agrega una entrada nueva en la sección "Hecho" (siguiendo el mismo formato que las entradas existentes, fecha de hoy) resumiendo esta entrega: miniaturas isométricas del menú Construir, rotación sincronizada, Residencial atenuado sin blueprint, `B` desacoplado de la colocación, y placeholders de ícono en Modos/Zonas — referenciando `docs/superpowers/specs/2026-09-30-previsualizacion-construcciones-cenital-design.md`.

- [ ] **Step 4: Commit**

```bash
git add "docs/Pendientes y próximos pasos.md"
git commit -m "$(cat <<'EOF'
docs: marcar hecha la previsualización de construcciones en el HUD cenital

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
