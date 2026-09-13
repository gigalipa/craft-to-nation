# Culling de Caras Translúcidas (agua/ventana) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar el "panel" visible entre dos bloques translúcidos adyacentes del mismo tipo (`"agua"` o `"ventana"`), dibujando solo las caras realmente expuestas de esos bloques en vez de la malla completa de cubo que coloca `GridMap` por celda.

**Architecture:** `GridMap` (`VoxelWorld.gd`) sigue siendo la única fuente de verdad para ocupación/colisión/lógica de juego — nada de eso cambia. Se agrega un nodo hermano/hijo nuevo, `TranslucidosRenderer` (`Node3D`), que mantiene su propia geometría (una malla por chunk de 16³ celdas, por tipo translúcido) generada con `SurfaceTool`, omitiendo cualquier cara compartida entre dos celdas del MISMO tipo translúcido. Los ítems `"agua"`/`"ventana"` de la `MeshLibrary` pasan a tener una malla vacía (0 superficies) para que `GridMap` deje de dibujar su propio cubo completo ahí — su colisión (solo aplica a `"ventana"`) no se toca. `VoxelWorld` emite una señal nueva cuando una celda translúcida cambia (colocada, minada, revertida, drenada), y `TranslucidosRenderer` la escucha para reconstruir solo los chunks afectados.

**Tech Stack:** Godot 4.7 GDScript, `GridMap` + `MeshLibrary`, `SurfaceTool`/`ArrayMesh`.

**Spec:** `docs/superpowers/specs/2026-09-13-culling-caras-translucidas-design.md`

## Global Constraints

- `GridMap` sigue siendo la única fuente de verdad para ocupación/colisión/lógica de juego (minado, construcción, detección de estructura, despejes) — ningún cambio de este plan debe alterar ese comportamiento.
- Regla de culling única y exacta: una cara entre una celda translúcida y su vecino se omite SI Y SOLO SI el vecino es del MISMO tipo translúcido. Cualquier otra combinación (aire, sólido, u otro tipo translúcido distinto) dibuja la cara.
- `CHUNK_SIZE := 16`.
- Tipos translúcidos de esta etapa: `"agua"` y `"ventana"` — constante `VoxelWorld.TIPOS_TRANSLUCIDOS := ["agua", "ventana"]`.
- Usa tabulaciones en GDScript (convención del proyecto). Conserva el español en comentarios y mensajes de prueba, igual que el resto del código existente.
- Verificación tras cada tarea: correr `godot/scenes/Test.tscn` (BlueprintValidatorTest, 37 pruebas antes de este plan) y la nueva escena `godot/scenes/TranslucidosRendererTest.tscn`, confirmando que todas las aserciones pasan sin errores nuevos.

---

### Task 1: Señal de cambio en `VoxelWorld.gd` + arranque del archivo de pruebas

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Create: `godot/scripts/TranslucidosRendererTest.gd`
- Create: `godot/scenes/TranslucidosRendererTest.tscn`

**Interfaces:**
- Produces: `VoxelWorld.TIPOS_TRANSLUCIDOS: Array[String]` (constante), `VoxelWorld.bloque_translucido_cambiado(celda: Vector3i)` (señal), emitida desde `colocar_bloque()`, `minar_bloque()`, `_revertir_celda()`, `eliminar_edificio()`, `drenar_agua()`.

- [ ] **Step 1: Agregar `TIPOS_TRANSLUCIDOS` y la señal**

En `godot/scripts/VoxelWorld.gd`, junto a `TIPOS_ARBOL` (línea ~89), agrega:

```gdscript
## Tipos de bloque cuya geometría visible NO la dibuja GridMap (su ítem en
## la MeshLibrary tiene una malla vacía) — la dibuja TranslucidosRenderer,
## que omite las caras compartidas entre dos celdas del MISMO tipo
## translúcido (ver docs/superpowers/specs/2026-09-13-culling-caras-
## translucidas-design.md). GridMap sigue siendo la única fuente de verdad
## para ocupación/colisión: esto es puramente visual.
const TIPOS_TRANSLUCIDOS: Array[String] = ["agua", "ventana"]
```

Junto a las `var` de nivel de clase (después de `var edificio_a_celdas`, línea ~138, o en cualquier punto antes de `_ready()`), agrega la señal:

```gdscript
## Emitida cuando una celda cambia DE o A un tipo en TIPOS_TRANSLUCIDOS
## (colocada, minada, revertida a fantasma, o drenada) — TranslucidosRenderer
## la escucha para reconstruir solo los chunks afectados. No se emite para
## ningún otro cambio de bloque (la inmensa mayoría de las llamadas).
signal bloque_translucido_cambiado(celda: Vector3i)
```

- [ ] **Step 2: Emitir la señal en `colocar_bloque()`**

Reemplaza la función completa (línea ~367):

```gdscript
func colocar_bloque(celda: Vector3i, tipo: String, por_jugador: bool = false) -> bool:
	var actual: int = get_cell_item(celda)
	var tipo_anterior: String = _tipo_por_id.get(actual, "")
	if actual != GridMap.INVALID_CELL_ITEM and tipo_anterior != "agua":
		return false
	if not _id_por_tipo.has(tipo):
		return false
	set_cell_item(celda, _id_por_tipo[tipo])
	if por_jugador:
		colocado_por_jugador[celda] = true
	if TIPOS_TRANSLUCIDOS.has(tipo) or TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)
	return true
```

Nota: `colocar_bloque()` puede sustituir una celda de `"agua"` existente por otro tipo (comportamiento ya existente) — por eso se revisa tanto `tipo` (el nuevo) como `tipo_anterior` (el que había, casi siempre `""` salvo el caso de sustituir agua).

- [ ] **Step 3: Emitir la señal en `minar_bloque()`**

Reemplaza la función completa (línea ~379):

```gdscript
func minar_bloque(celda: Vector3i) -> bool:
	if obtener_tipo(celda) == "agua":
		return false
	if celda_a_edificio.has(celda):
		return false
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
	var tipo_anterior: String = obtener_tipo(celda)
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)
	return true
```

- [ ] **Step 4: Emitir la señal en `_revertir_celda()`**

Reemplaza la función completa (línea ~714):

```gdscript
func _revertir_celda(celda: Vector3i) -> void:
	var tipo_anterior: String = obtener_tipo(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	colocar_bloque(celda, "fantasma")
	if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)
```

- [ ] **Step 5: Emitir la señal en `eliminar_edificio()`**

En `godot/scripts/VoxelWorld.gd` (línea ~728), dentro del `for celda in celdas:`, agrega la captura del tipo anterior y la emisión:

```gdscript
	for celda in celdas:
		esquina.x = min(esquina.x, celda.x)
		esquina.y = min(esquina.y, celda.z)
		if pareja.has(celda):
			pareja.erase(pareja[celda])
			pareja.erase(celda)
		var tipo_anterior: String = obtener_tipo(celda)
		set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
		celda_a_edificio.erase(celda)
		if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
			bloque_translucido_cambiado.emit(celda)
```

- [ ] **Step 6: Emitir la señal en `drenar_agua()`**

Reemplaza la función completa (línea ~904):

```gdscript
func drenar_agua(x: int, z: int) -> int:
	var y: int = altura_en(x, z, true) + 1
	var reemplazados := 0
	while obtener_tipo(Vector3i(x, y, z)) == "agua":
		set_cell_item(Vector3i(x, y, z), _id_por_tipo["tierra"])
		bloque_translucido_cambiado.emit(Vector3i(x, y, z))
		y += 1
		reemplazados += 1
	return reemplazados
```

(El tipo es siempre `"agua"` aquí, por la propia condición del `while`, así que no hace falta consultar `TIPOS_TRANSLUCIDOS`.)

- [ ] **Step 7: Crear la escena de pruebas**

Crea `godot/scenes/TranslucidosRendererTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/TranslucidosRendererTest.gd" id="1"]

[node name="TranslucidosRendererTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 8: Escribir TEST 1 (la señal se emite solo para cambios translúcidos)**

Crea `godot/scripts/TranslucidosRendererTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de la señal VoxelWorld.bloque_translucido_cambiado y de
## TranslucidosRenderer (mismo patrón que GeneradorMundoTest.gd/
## BlueprintValidatorTest.gd). Corre esta escena (TranslucidosRendererTest.tscn)
## con F6 en el editor de Godot y revisa el panel "Output": debe imprimir
## todas las pruebas y no debe lanzar ningún error de assert().
## Ver docs/superpowers/specs/2026-09-13-culling-caras-translucidas-design.md.

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: bloque_translucido_cambiado() se emite solo para cambios que involucran un tipo translúcido ===")
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()

	var celdas_emitidas: Array[Vector3i] = []
	mundo.bloque_translucido_cambiado.connect(func(celda: Vector3i) -> void:
		celdas_emitidas.append(celda)
	)

	# Colocar un bloque sólido (pared): NO debe emitir.
	mundo.colocar_bloque(Vector3i(0, 0, 0), "pared", true)
	assert(celdas_emitidas.is_empty(), "colocar un bloque sólido no debe emitir la señal")

	# Colocar agua: SÍ debe emitir.
	mundo.colocar_bloque(Vector3i(1, 0, 0), "agua")
	assert(celdas_emitidas == [Vector3i(1, 0, 0)], "colocar agua debe emitir exactamente esa celda")

	# Sustituir esa agua por piedra: SÍ debe emitir (el tipo ANTERIOR era translúcido).
	celdas_emitidas.clear()
	mundo.colocar_bloque(Vector3i(1, 0, 0), "piedra")
	assert(celdas_emitidas == [Vector3i(1, 0, 0)], "sustituir agua por un tipo no translúcido debe emitir igual")

	# Colocar una ventana y minarla: ambos deben emitir.
	celdas_emitidas.clear()
	mundo.colocar_bloque(Vector3i(2, 0, 0), "ventana", true)
	assert(celdas_emitidas == [Vector3i(2, 0, 0)], "colocar una ventana debe emitir")
	celdas_emitidas.clear()
	mundo.minar_bloque(Vector3i(2, 0, 0))
	assert(celdas_emitidas == [Vector3i(2, 0, 0)], "minar una ventana debe emitir")

	# Minar un bloque no translúcido: NO debe emitir.
	celdas_emitidas.clear()
	mundo.minar_bloque(Vector3i(0, 0, 0))
	assert(celdas_emitidas.is_empty(), "minar un bloque sólido no debe emitir la señal")

	# drenar_agua(): cada celda de agua reemplazada debe emitir.
	mundo.colocar_bloque(Vector3i(3, 0, 0), "tierra")
	mundo.colocar_bloque(Vector3i(3, 1, 0), "agua")
	mundo.colocar_bloque(Vector3i(3, 2, 0), "agua")
	celdas_emitidas.clear()
	var reemplazados: int = mundo.drenar_agua(3, 0)
	assert(reemplazados == 2)
	assert(celdas_emitidas == [Vector3i(3, 1, 0), Vector3i(3, 2, 0)], "drenar_agua() debe emitir cada celda reemplazada, en orden")

	print("OK: bloque_translucido_cambiado() se emite exactamente cuando un tipo translúcido entra o sale de una celda.")

	print("\n=== Las pruebas de TranslucidosRenderer pasaron correctamente ===")
```

- [ ] **Step 9: Ejecutar y confirmar**

Correr `godot/scenes/TranslucidosRendererTest.tscn` (mcp__godot__run_project con `projectPath` la carpeta `godot`, luego `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project`) y confirmar que imprime `OK` en TEST 1 y termina con `=== Las pruebas de TranslucidosRenderer pasaron correctamente ===`, sin ningún `SCRIPT ERROR` ni `Assertion failed`.

- [ ] **Step 10: Regresión completa y commit**

Correr también `godot/scenes/Test.tscn` (BlueprintValidatorTest, deben seguir pasando las 37 pruebas — este cambio no debe alterar ningún comportamiento existente) y `godot/scenes/GeneradorMundoTest.tscn` (30 pruebas, sin relación directa pero usa `VoxelWorld` como preload de constantes). Confirmado todo verde:

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/TranslucidosRendererTest.gd godot/scenes/TranslucidosRendererTest.tscn
git commit -m "feat: señal VoxelWorld.bloque_translucido_cambiado para cambios de bloques translúcidos"
```

---

### Task 2: `TranslucidosRenderer.gd` — geometría pura (chunking, culling, caras)

**Files:**
- Create: `godot/scripts/TranslucidosRenderer.gd`
- Modify: `godot/scripts/TranslucidosRendererTest.gd`

**Interfaces:**
- Consumes: `VoxelWorld.TIPOS_TRANSLUCIDOS`, `VoxelWorld.VECINOS_3D` (Task 1 y ya existente).
- Produces: `TranslucidosRenderer.CHUNK_SIZE: int`, `TranslucidosRenderer._chunk_de(celda: Vector3i) -> Vector3i` (static), `TranslucidosRenderer._cara_visible(tipo_propio: String, tipo_vecino: String) -> bool` (static), `TranslucidosRenderer._esquinas_cara(centro: Vector3, direccion: Vector3i) -> Array[Vector3]` (static) — usados por Task 3.

- [ ] **Step 1: Crear el script con las funciones puras**

Crea `godot/scripts/TranslucidosRenderer.gd`:

```gdscript
extends Node3D

## Dibuja la geometría visible de los bloques translúcidos (VoxelWorld.
## TIPOS_TRANSLUCIDOS: "agua", "ventana") con culling de caras internas —
## GridMap coloca la malla COMPLETA de un cubo por celda sin saber qué hay
## en las celdas vecinas, así que dos celdas translúcidas del mismo tipo
## pegadas dibujan ambas su cara compartida, y el alpha blend las combina
## en un "panel" visible (bug real, reportado jugando en vivo). Ver
## docs/superpowers/specs/2026-09-13-culling-caras-translucidas-design.md.
## GridMap sigue siendo la ÚNICA fuente de verdad para ocupación/colisión:
## los ítems "agua"/"ventana" de la MeshLibrary tienen una malla vacía
## (ver BlockLibrarySource.tscn), así que este nodo es todo lo que se ve.

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const MATERIAL_AGUA := preload("res://assets/mat_agua.tres")
const MATERIAL_VENTANA := preload("res://assets/mat_ventana.tres")

const CHUNK_SIZE := 16

## Para cada dirección cardinal (una de VoxelWorld.VECINOS_3D), los dos ejes
## tangentes [u, v] de la cara perpendicular a esa dirección, en el orden
## que da u×v == direccion (ver _esquinas_cara()) — así el sentido de
## dibujado (CCW visto desde la dirección) queda garantizado por
## construcción, no por prueba y error visual.
const _EJES_POR_DIRECCION := {
	Vector3i(1, 0, 0): [Vector3(0, 1, 0), Vector3(0, 0, 1)],
	Vector3i(-1, 0, 0): [Vector3(0, 0, 1), Vector3(0, 1, 0)],
	Vector3i(0, 1, 0): [Vector3(0, 0, 1), Vector3(1, 0, 0)],
	Vector3i(0, -1, 0): [Vector3(1, 0, 0), Vector3(0, 0, 1)],
	Vector3i(0, 0, 1): [Vector3(1, 0, 0), Vector3(0, 1, 0)],
	Vector3i(0, 0, -1): [Vector3(0, 1, 0), Vector3(1, 0, 0)],
}

## Asignado por VoxelWorld._ready() antes de llamar a reconstruir_todo() —
## ver Sección 6 del spec. Nunca null en uso real; en pruebas se asigna a
## mano sobre un VoxelWorld.new() fuera del árbol (mismo patrón que
## BlueprintValidatorTest.gd).
var voxel_world: Node

var _material_por_tipo: Dictionary = {}  # String -> Material
var _mesh_por_chunk: Dictionary = {}  # String -> Dictionary (Vector3i -> MeshInstance3D)


## Clave de chunk de "celda" — división de PISO real (floori()), no
## truncamiento, para que coordenadas negativas (el mundo las admite, ver
## VoxelWorld.ALTURA_BUSQUEDA_MIN) den chunks negativos consistentes en vez
## de "rebotar" hacia 0.
static func _chunk_de(celda: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(celda.x) / CHUNK_SIZE),
		floori(float(celda.y) / CHUNK_SIZE),
		floori(float(celda.z) / CHUNK_SIZE),
	)


## true si debe dibujarse la cara entre una celda de tipo "tipo_propio" (uno
## de VoxelWorld.TIPOS_TRANSLUCIDOS) y su vecino de tipo "tipo_vecino" ("" si
## el vecino está vacío). Se omite ÚNICAMENTE cuando ambos lados son del
## MISMO tipo translúcido — cualquier otra combinación (aire, sólido, u otro
## tipo translúcido distinto) sí se dibuja.
static func _cara_visible(tipo_propio: String, tipo_vecino: String) -> bool:
	return tipo_vecino != tipo_propio


## Las 4 esquinas (orden CCW visto desde "direccion") de la cara de un cubo
## unitario centrado en "centro", en la dirección "direccion". Función pura
## de geometría — no toca SurfaceTool ni GridMap, testable comparando el
## producto cruzado de sus dos primeras aristas contra "direccion".
static func _esquinas_cara(centro: Vector3, direccion: Vector3i) -> Array[Vector3]:
	var ejes: Array = _EJES_POR_DIRECCION[direccion]
	var u: Vector3 = ejes[0]
	var v: Vector3 = ejes[1]
	var normal := Vector3(direccion.x, direccion.y, direccion.z) * 0.5
	var centro_cara: Vector3 = centro + normal
	var esquinas: Array[Vector3] = [
		centro_cara - u * 0.5 - v * 0.5,
		centro_cara + u * 0.5 - v * 0.5,
		centro_cara + u * 0.5 + v * 0.5,
		centro_cara - u * 0.5 + v * 0.5,
	]
	return esquinas
```

- [ ] **Step 2: TEST 2 — `_chunk_de()`**

En `godot/scripts/TranslucidosRendererTest.gd`, agrega al final de `ejecutar_pruebas()` (antes del `print` final de cierre, que se mueve al final del archivo — ver Step 4 de esta tarea):

```gdscript
	print("\n=== TEST 2: _chunk_de() agrupa por chunks de CHUNK_SIZE, con división de piso real ===")
	const CS := TranslucidosRendererScript.CHUNK_SIZE
	assert(TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0)) == Vector3i(0, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(CS - 1, CS - 1, CS - 1)) == Vector3i(0, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(CS, 0, 0)) == Vector3i(1, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(-1, 0, 0)) == Vector3i(-1, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(-CS, 0, 0)) == Vector3i(-1, 0, 0))
	assert(TranslucidosRendererScript._chunk_de(Vector3i(-CS - 1, 0, 0)) == Vector3i(-2, 0, 0))
	print("OK: _chunk_de() da la misma clave dentro de un chunk, cambia al cruzar el borde, y respeta coordenadas negativas.")
```

Agrega el preload al inicio del archivo, junto al de `VoxelWorld`:

```gdscript
const TranslucidosRendererScript = preload("res://scripts/TranslucidosRenderer.gd")
```

- [ ] **Step 3: TEST 3 — `_cara_visible()`**

Agrega:

```gdscript
	print("\n=== TEST 3: _cara_visible() solo oculta la cara entre dos celdas del MISMO tipo translúcido ===")
	assert(TranslucidosRendererScript._cara_visible("agua", "agua") == false)
	assert(TranslucidosRendererScript._cara_visible("ventana", "ventana") == false)
	assert(TranslucidosRendererScript._cara_visible("agua", "") == true)
	assert(TranslucidosRendererScript._cara_visible("agua", "ventana") == true)
	assert(TranslucidosRendererScript._cara_visible("agua", "pared") == true)
	assert(TranslucidosRendererScript._cara_visible("ventana", "") == true)
	print("OK: _cara_visible() oculta agua-agua y ventana-ventana; cualquier otra combinación se dibuja.")
```

- [ ] **Step 4: TEST 4 — `_esquinas_cara()` (sentido de dibujado correcto)**

Agrega, y mueve el `print("\n=== Las pruebas de TranslucidosRenderer pasaron correctamente ===")` para que quede DESPUÉS de este bloque:

```gdscript
	print("\n=== TEST 4: _esquinas_cara() da 4 esquinas en sentido CCW visto desde la dirección de la cara ===")
	for direccion: Vector3i in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]:
		var esquinas: Array[Vector3] = TranslucidosRendererScript._esquinas_cara(Vector3.ZERO, direccion)
		assert(esquinas.size() == 4)
		var arista1: Vector3 = esquinas[1] - esquinas[0]
		var arista2: Vector3 = esquinas[2] - esquinas[0]
		var normal_calculada: Vector3 = arista1.cross(arista2).normalized()
		var normal_esperada := Vector3(direccion.x, direccion.y, direccion.z)
		assert(normal_calculada.is_equal_approx(normal_esperada), "la cara en dirección %s debe tener normal %s, dio %s" % [direccion, normal_esperada, normal_calculada])
		for esquina in esquinas:
			assert(absf(esquina.dot(normal_esperada) - 0.5) < 0.0001, "cada esquina debe quedar en la cara del cubo unitario, a 0.5 de distancia en la dirección de la normal")
	print("OK: las 4 esquinas de cada una de las 6 caras quedan en sentido CCW visto desde su dirección, sobre la superficie del cubo unitario.")
```

- [ ] **Step 5: Ejecutar y confirmar**

Correr `godot/scenes/TranslucidosRendererTest.tscn` — deben pasar TEST 1-4. Correr también `godot/scenes/Test.tscn` (37/37, sin cambios esperados).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/TranslucidosRenderer.gd godot/scripts/TranslucidosRendererTest.gd
git commit -m "feat: geometría pura de TranslucidosRenderer (chunking, regla de culling, caras de cubo)"
```

---

### Task 3: `TranslucidosRenderer.gd` — construcción de malla real e integración con `VoxelWorld`

**Files:**
- Create: `godot/assets/mat_agua.tres`
- Create: `godot/assets/mat_ventana.tres`
- Modify: `godot/scripts/TranslucidosRenderer.gd`
- Modify: `godot/scripts/TranslucidosRendererTest.gd`

**Interfaces:**
- Consumes: `TranslucidosRenderer._chunk_de()`, `_cara_visible()`, `_esquinas_cara()` (Task 2); `VoxelWorld.obtener_tipo()`, `VoxelWorld.get_used_cells()` (nativo de `GridMap`), `VoxelWorld.VECINOS_3D`, `VoxelWorld.TIPOS_TRANSLUCIDOS`.
- Produces: `TranslucidosRenderer._indexar_materiales()`, `TranslucidosRenderer.reconstruir_todo()`, `TranslucidosRenderer._on_bloque_translucido_cambiado(celda: Vector3i)` — usados por Task 4 desde `VoxelWorld._ready()`.

- [ ] **Step 1: Crear los recursos de material**

Crea `godot/assets/mat_agua.tres`:

```
[gd_resource type="StandardMaterial3D" format=3]

[resource]
transparency = 1
albedo_color = Color(0.2, 0.45, 0.85, 0.45)
```

Crea `godot/assets/mat_ventana.tres`:

```
[gd_resource type="StandardMaterial3D" format=3]

[resource]
transparency = 1
albedo_color = Color(0.6, 0.8, 1, 0.5)
```

(Mismos valores que los `StandardMaterial3D` `Mat_agua`/`Mat_ventana` actuales de `BlockLibrarySource.tscn` — esa escena se actualiza recién en la Task 4, cuando la malla de esos ítems se vacía y esos materiales dejan de tener uso ahí.)

- [ ] **Step 2: `_indexar_materiales()`**

En `godot/scripts/TranslucidosRenderer.gd`, agrega:

```gdscript
## Carga los materiales de cada tipo translúcido — recursos independientes
## (ver mat_agua.tres/mat_ventana.tres), no leídos de mesh_library: una vez
## vacía la malla del ítem correspondiente (Task 4), ya no habría ninguna
## superficie de la que sacar el material original.
func _indexar_materiales() -> void:
	_material_por_tipo["agua"] = MATERIAL_AGUA
	_material_por_tipo["ventana"] = MATERIAL_VENTANA
```

- [ ] **Step 3: `_agregar_cara()` y `_reconstruir_chunk()`**

Agrega:

```gdscript
func _agregar_cara(st: SurfaceTool, centro: Vector3, direccion: Vector3i) -> void:
	var esquinas: Array[Vector3] = _esquinas_cara(centro, direccion)
	var normal := Vector3(direccion.x, direccion.y, direccion.z)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(esquinas[i])


## Reconstruye desde cero la malla de "chunk" para "tipo": recorre las
## CHUNK_SIZE³ celdas del chunk, y para cada celda de ese tipo agrega solo
## las caras que _cara_visible() aprueba contra cada uno de sus 6 vecinos
## (consultando voxel_world.obtener_tipo(), que cruza libremente el borde
## del chunk hacia chunks vecinos). Si el chunk queda sin ninguna cara para
## ese tipo, borra su MeshInstance3D si existía; si tiene al menos una,
## crea (la primera vez) o reutiliza su MeshInstance3D.
func _reconstruir_chunk(chunk: Vector3i, tipo: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origen: Vector3i = chunk * CHUNK_SIZE
	var hay_caras := false
	for dx in range(CHUNK_SIZE):
		for dy in range(CHUNK_SIZE):
			for dz in range(CHUNK_SIZE):
				var celda: Vector3i = origen + Vector3i(dx, dy, dz)
				if voxel_world.obtener_tipo(celda) != tipo:
					continue
				for direccion: Vector3i in VoxelWorld.VECINOS_3D:
					var vecino: Vector3i = celda + direccion
					var tipo_vecino: String = voxel_world.obtener_tipo(vecino)
					if not _cara_visible(tipo, tipo_vecino):
						continue
					_agregar_cara(st, Vector3(celda), direccion)
					hay_caras = true

	if not hay_caras:
		if _mesh_por_chunk.has(tipo) and _mesh_por_chunk[tipo].has(chunk):
			_mesh_por_chunk[tipo][chunk].queue_free()
			_mesh_por_chunk[tipo].erase(chunk)
		return

	var malla: ArrayMesh = st.commit()
	var instancia: MeshInstance3D
	if _mesh_por_chunk.has(tipo) and _mesh_por_chunk[tipo].has(chunk):
		instancia = _mesh_por_chunk[tipo][chunk]
	else:
		instancia = MeshInstance3D.new()
		add_child(instancia)
		if not _mesh_por_chunk.has(tipo):
			_mesh_por_chunk[tipo] = {}
		_mesh_por_chunk[tipo][chunk] = instancia
	instancia.mesh = malla
	instancia.set_surface_override_material(0, _material_por_tipo[tipo])
```

- [ ] **Step 4: `reconstruir_todo()` y el handler incremental**

Agrega:

```gdscript
## Reconstrucción completa — llamada una única vez desde VoxelWorld._ready(),
## después de _generar_terreno() (Sección 5 del spec). Recorre
## get_used_cells() (nativo de GridMap, ya filtra a celdas ocupadas) UNA
## vez, agrupa por chunk, y reconstruye cada chunk afectado una sola vez —
## sin pasar por bloque_translucido_cambiado celda por celda durante la
## generación masiva inicial (miles de celdas de agua).
func reconstruir_todo() -> void:
	var chunks_por_tipo: Dictionary = {}  # String -> Dictionary (Vector3i -> true)
	for celda in voxel_world.get_used_cells():
		var tipo: String = voxel_world.obtener_tipo(celda)
		if not VoxelWorld.TIPOS_TRANSLUCIDOS.has(tipo):
			continue
		var chunk: Vector3i = _chunk_de(celda)
		if not chunks_por_tipo.has(tipo):
			chunks_por_tipo[tipo] = {}
		chunks_por_tipo[tipo][chunk] = true
	for tipo in chunks_por_tipo:
		for chunk in chunks_por_tipo[tipo]:
			_reconstruir_chunk(chunk, tipo)


## Conectado a VoxelWorld.bloque_translucido_cambiado desde VoxelWorld._ready()
## (Sección 6 del spec — NO desde el propio _ready() de este nodo, porque
## los hijos ejecutan _ready() antes que su padre, y "voxel_world" todavía
## no estaría asignado). Marca sucios el chunk de "celda" y los de sus 6
## vecinos directos (una celda en el borde de un chunk afecta el cálculo de
## caras expuestas del chunk vecino también) y los reconstruye de inmediato
## para AMBOS tipos translúcidos — evento raro (un bloque a la vez), así
## que reconstruir de más no es un problema de rendimiento.
func _on_bloque_translucido_cambiado(celda: Vector3i) -> void:
	var chunks_afectados: Dictionary = {}  # Vector3i -> true
	chunks_afectados[_chunk_de(celda)] = true
	for delta: Vector3i in VoxelWorld.VECINOS_3D:
		chunks_afectados[_chunk_de(celda + delta)] = true
	for chunk in chunks_afectados:
		for tipo in VoxelWorld.TIPOS_TRANSLUCIDOS:
			_reconstruir_chunk(chunk, tipo)
```

- [ ] **Step 5: TEST 5 — culling real entre dos celdas de agua adyacentes**

En `godot/scripts/TranslucidosRendererTest.gd`, agrega (después de TEST 4, antes del cierre):

```gdscript
	print("\n=== TEST 5: reconstruir_todo() omite la cara compartida entre dos celdas de agua adyacentes ===")
	var mundo_t5: Node = VoxelWorld.new()
	mundo_t5.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t5.cell_size = Vector3.ONE * 1.0
	mundo_t5._indexar_biblioteca()
	mundo_t5.colocar_bloque(Vector3i(0, 0, 0), "agua")
	mundo_t5.colocar_bloque(Vector3i(1, 0, 0), "agua")
	var render_t5: Node3D = TranslucidosRendererScript.new()
	render_t5.voxel_world = mundo_t5
	render_t5._indexar_materiales()
	render_t5.reconstruir_todo()
	# Dos celdas de agua sueltas, cada una expone 5 caras (todas menos la que
	# comparten entre sí) = 10 caras = 20 triángulos = 60 vértices (sin
	# indexar, cada cara agrega sus propios 6 vértices — ver _agregar_cara()).
	var chunk_t5: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var instancia_t5: MeshInstance3D = render_t5._mesh_por_chunk["agua"][chunk_t5]
	var conteo_vertices_t5: int = instancia_t5.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t5 == 10 * 6, "dos celdas de agua adyacentes deben exponer 10 caras (60 vértices), no 12 (72)")
	print("OK: reconstruir_todo() omite exactamente la cara compartida entre dos celdas de agua adyacentes.")

	print("\n=== TEST 6: una celda de agua junto a un bloque sólido SÍ dibuja esa cara ===")
	var mundo_t6: Node = VoxelWorld.new()
	mundo_t6.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t6.cell_size = Vector3.ONE * 1.0
	mundo_t6._indexar_biblioteca()
	mundo_t6.colocar_bloque(Vector3i(0, 0, 0), "agua")
	mundo_t6.colocar_bloque(Vector3i(1, 0, 0), "pared", true)
	var render_t6: Node3D = TranslucidosRendererScript.new()
	render_t6.voxel_world = mundo_t6
	render_t6._indexar_materiales()
	render_t6.reconstruir_todo()
	var chunk_t6: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var instancia_t6: MeshInstance3D = render_t6._mesh_por_chunk["agua"][chunk_t6]
	var conteo_vertices_t6: int = instancia_t6.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_vertices_t6 == 6 * 6, "una celda de agua sola (junto a un sólido, no otra agua) debe exponer sus 6 caras completas")
	print("OK: una celda de agua junto a un bloque sólido dibuja las 6 caras completas (la pared no es del mismo tipo translúcido).")

	print("\n=== TEST 7: la reconstrucción incremental (señal) converge al mismo resultado que reconstruir_todo() ===")
	var mundo_t7: Node = VoxelWorld.new()
	mundo_t7.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_t7.cell_size = Vector3.ONE * 1.0
	mundo_t7._indexar_biblioteca()
	var render_t7: Node3D = TranslucidosRendererScript.new()
	render_t7.voxel_world = mundo_t7
	render_t7._indexar_materiales()
	mundo_t7.bloque_translucido_cambiado.connect(render_t7._on_bloque_translucido_cambiado)
	mundo_t7.colocar_bloque(Vector3i(0, 0, 0), "agua")  # dispara la señal -> reconstrucción incremental
	mundo_t7.colocar_bloque(Vector3i(1, 0, 0), "agua")  # dispara la señal de nuevo, sobre el chunk ya construido
	var chunk_t7: Vector3i = TranslucidosRendererScript._chunk_de(Vector3i(0, 0, 0))
	var conteo_incremental_t7: int = render_t7._mesh_por_chunk["agua"][chunk_t7].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(conteo_incremental_t7 == 10 * 6, "el camino incremental debe dar el mismo resultado que reconstruir_todo() (TEST 5) para el mismo estado final")
	print("OK: colocar bloques uno a uno vía señal converge exactamente al mismo resultado que reconstruir_todo().")
```

- [ ] **Step 6: Ejecutar y confirmar**

Correr `godot/scenes/TranslucidosRendererTest.tscn` — deben pasar TEST 1-7. Correr `godot/scenes/Test.tscn` (37/37).

- [ ] **Step 7: Commit**

```bash
git add godot/assets/mat_agua.tres godot/assets/mat_ventana.tres godot/scripts/TranslucidosRenderer.gd godot/scripts/TranslucidosRendererTest.gd
git commit -m "feat: TranslucidosRenderer construye la malla real por chunk con culling de caras"
```

---

### Task 4: Vaciar la malla de GridMap para agua/ventana y conectar todo en `Main.tscn`

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scenes/Main.tscn`

**Interfaces:**
- Consumes: `TranslucidosRenderer.voxel_world`, `_indexar_materiales()`, `reconstruir_todo()`, `_on_bloque_translucido_cambiado()` (Tasks 2-3); `VoxelWorld.bloque_translucido_cambiado` (Task 1).

- [ ] **Step 1: Vaciar la malla de `"agua"` y `"ventana"` en `BlockLibrarySource.tscn`**

En `godot/scenes/BlockLibrarySource.tscn`, reemplaza el bloque de `"ventana"`:

```
[sub_resource type="StandardMaterial3D" id="Mat_ventana"]
transparency = 1
albedo_color = Color(0.6, 0.8, 1, 0.5)

[sub_resource type="BoxMesh" id="Mesh_ventana"]
material = SubResource("Mat_ventana")

[sub_resource type="BoxShape3D" id="Shape_ventana"]
```

por:

```
[sub_resource type="ArrayMesh" id="Mesh_ventana"]

[sub_resource type="BoxShape3D" id="Shape_ventana"]
```

Y el bloque de `"agua"`:

```
[sub_resource type="StandardMaterial3D" id="Mat_agua"]
transparency = 1
albedo_color = Color(0.2, 0.45, 0.85, 0.45)

[sub_resource type="BoxMesh" id="Mesh_agua"]
material = SubResource("Mat_agua")

[sub_resource type="BoxShape3D" id="Shape_agua"]
```

por:

```
[sub_resource type="ArrayMesh" id="Mesh_agua"]

[sub_resource type="BoxShape3D" id="Shape_agua"]
```

(Los nodos `"ventana"`/`"agua"` y el `CollisionShape3D` hijo de `"ventana"` no cambian — siguen referenciando `Mesh_ventana`/`Shape_ventana` y `Mesh_agua` por nombre exactamente igual.)

- [ ] **Step 2: Reexportar la `MeshLibrary`**

Reexportar `assets/BlockLibrary.res` desde `BlockLibrarySource.tscn` (`mcp__godot__export_mesh_library`, mismo mecanismo ya usado en la spec de ríos para cambios de `BlockLibrarySource.tscn`).

- [ ] **Step 3: Agregar el nodo `TranslucidosRenderer` a `Main.tscn`**

En `godot/scenes/Main.tscn`, agrega el `ext_resource` del script (junto a los demás, cerca de la línea 9) y el nodo como hijo de `VoxelWorld`:

```
[ext_resource type="Script" path="res://scripts/TranslucidosRenderer.gd" id="8"]
```

```
[node name="TranslucidosRenderer" type="Node3D" parent="VoxelWorld"]
script = ExtResource("8")
```

(Ajusta el número de `id` del `ext_resource` al siguiente libre en el archivo real — revisa los `id="N"` ya usados antes de escribir el nuevo.)

- [ ] **Step 4: Conectar todo desde `VoxelWorld._ready()`**

En `godot/scripts/VoxelWorld.gd`, reemplaza `_ready()`:

```gdscript
func _ready() -> void:
	cell_size = Vector3.ONE * TAMANO_CELDA
	_indexar_biblioteca()
	generador = GeneradorMundo.new(SEMILLA_MUNDO, ANCHO_MUNDO, LARGO_MUNDO)
	arboles = GeneradorArbol.new()
	_generar_terreno()
	_generar_arboles()
	var translucidos: Node3D = get_node("TranslucidosRenderer")
	translucidos.voxel_world = self
	translucidos._indexar_materiales()
	bloque_translucido_cambiado.connect(translucidos._on_bloque_translucido_cambiado)
	translucidos.reconstruir_todo()
```

- [ ] **Step 5: Regresión completa**

Correr, en este orden:
1. `godot/scenes/TranslucidosRendererTest.tscn` — TEST 1-7 deben seguir pasando (nada de esta tarea cambia la lógica de `TranslucidosRenderer.gd`, solo la conecta).
2. `godot/scenes/Test.tscn` — 37/37 (la colisión de `"ventana"` debe seguir intacta; si alguna prueba la usa y falla, es señal de que `Shape_ventana` se desconectó al editar el `.tscn` — revisar el Step 1).
3. `godot/scenes/GeneradorMundoTest.tscn` — 30/30.
4. `godot/scenes/Main.tscn` — confirmar que carga sin errores nuevos en la salida de depuración (`mcp__godot__get_debug_output` tras `mcp__godot__run_project`).

- [ ] **Step 6: Verificación visual (pide confirmación del usuario)**

Este cambio es visual — pide al usuario que abra el editor y coloque agua junto a agua, y una ventana junto a otra ventana (dos paredes contiguas con ventana), y confirme que ya no se ve el panel interno, y que sigue viéndose la superficie del agua y los laterales expuestos de las ventanas.

- [ ] **Step 7: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scenes/Main.tscn godot/scripts/VoxelWorld.gd
git commit -m "feat: GridMap deja de dibujar agua/ventana; TranslucidosRenderer las reemplaza con culling de caras"
```
