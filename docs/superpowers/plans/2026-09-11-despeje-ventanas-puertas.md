# Despeje de Proximidad para Ventanas y Puertas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent proximity-clearance reservation to every building's windows and doors, so future construction can't crowd them — required for the resource-distribution networks and NPC movement the GDD anticipates.

**Architecture:** Each building gets a set of reserved "despeje" cells computed from its window/door cells (1 cell outward for a window, 2 cells outward at both door levels), tracked the same way as `edificio_a_celdas`/`celda_a_edificio`. Placing a new building is rejected if its own despeje isn't physically empty, or if any of its STRUCTURAL cells land inside another building's reserved despeje — but two different buildings' despeje zones may freely overlap each other.

**Tech Stack:** Godot 4.7 GDScript, GridMap-based voxel world.

**Spec:** `docs/superpowers/specs/2026-09-11-despeje-ventanas-puertas-design.md`

## Global Constraints

- Tabs for indentation in all GDScript (Godot convention, CLAUDE.md).
- Keep Spanish in all comments, print messages, and test names.
- Do not reformat unrelated code — only touch the functions/consts named in each task.
- Run `godot/scenes/Test.tscn` (runs `BlueprintValidatorTest.gd`) and `godot/scenes/Main.tscn` headless after every task — all assertions must pass, `Main.tscn` must show only the expected pre-existing warnings.
- Two different buildings' despeje reservations may overlap each other — the only forbidden overlap is a new building's STRUCTURAL cell landing inside another building's despeje. Never compare despeje-against-despeje between two different buildings.
- The despeje reservation must persist for the lifetime of a building's id and be fully released in `eliminar_edificio()` — no dangling `celda_a_despeje` entries after a building is removed.

---

### Task 1: `VoxelWorld.gd` — despeje data model, calculation, validation, and lifecycle wiring

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`

**Interfaces:**
- Produces: `VECINOS_ORTOGONALES_XZ: Array[Vector2i]` (new const); `edificio_despeje: Dictionary` (int -> Array[Vector3i]), `celda_a_despeje: Dictionary` (Vector3i -> int) (new instance vars); `calcular_despeje(celdas_mundo: Dictionary) -> Array` (new function); `verificar_despejes(celdas_mundo: Dictionary) -> bool` (new function). Both take `celdas_mundo` as `Vector3i -> String` (a building's structural cells) — the exact same shape `iniciar_construccion_fantasma()`'s `tipos_estructura` param and `registrar_edificio_completo()`'s `celdas_mundo` param already use.
- Consumes: existing `obtener_tipo(celda: Vector3i) -> String` (returns `""` for an empty cell — this is what makes "is this cell physically empty" a simple string comparison), `registrar_edificio()`, `ordenar_celdas_edificio()`.

- [ ] **Step 1: Add `VECINOS_ORTOGONALES_XZ` const**

Find the existing `VECINOS_3D` const:

```gdscript
const VECINOS_3D: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
```

Immediately after it, add:

```gdscript
## Las 4 direcciones cardinales en el plano XZ — usadas por
## calcular_despeje() para encontrar el lado "externo" de una celda
## ventana/puerta (cualquier vecino XZ que no pertenezca a la huella del
## propio edificio).
const VECINOS_ORTOGONALES_XZ: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
```

- [ ] **Step 2: Add `edificio_despeje`/`celda_a_despeje` state**

Find the existing declaration block ending in:

```gdscript
var edificio_orden: Dictionary = {}  # int -> Array[Vector3i]
var edificio_tipos: Dictionary = {}  # int -> Dictionary (Vector3i -> String)
var edificio_progreso: Dictionary = {}  # int -> int
var edificio_metadata: Dictionary = {}  # int -> Dictionary
```

Immediately after it, add:

```gdscript
## Por edificio: las celdas de despeje reservadas por sus ventanas/puertas
## (ver calcular_despeje()) y su consulta inversa — mismo patrón que
## edificio_a_celdas/celda_a_edificio. Persiste mientras exista el id del
## edificio, se libera por completo en eliminar_edificio() — ver
## docs/superpowers/specs/2026-09-11-despeje-ventanas-puertas-design.md.
## El despeje de dos edificios DISTINTOS puede solaparse libremente: solo
## se compara celda ESTRUCTURAL nueva contra despeje ajeno
## (verificar_despejes()), nunca despeje contra despeje.
var edificio_despeje: Dictionary = {}  # int -> Array[Vector3i]
var celda_a_despeje: Dictionary = {}  # Vector3i -> int
```

- [ ] **Step 3: Add `calcular_despeje()` and `verificar_despejes()`**

Add these two new functions immediately after `id_de_edificio()`:

```gdscript
func id_de_edificio(celda: Vector3i) -> int:
	return celda_a_edificio.get(celda, -1)


## Calcula las celdas de despeje que exige "celdas_mundo" (Vector3i real ->
## tipo, las celdas ESTRUCTURALES de un edificio — mismo formato que
## registrar_edificio_completo()/iniciar_construccion_fantasma() ya usan).
## Para cada celda "ventana" o "puerta_inferior"/"puerta_superior", revisa
## sus 4 vecinos cardinales en XZ; cualquiera que NO pertenezca a la huella
## del propio edificio (es decir, cae fuera de celdas_mundo en esa columna)
## es una dirección "externa". En cada dirección externa se reservan 1
## celda (ventana) o 2 celdas (puerta, en AMBOS niveles) a la misma altura
## Y de la celda original. Devuelve un Array sin duplicados (una celda de
## despeje puede quedar "pedida" por más de una ventana/puerta vecina).
func calcular_despeje(celdas_mundo: Dictionary) -> Array:
	var huella_xz: Dictionary = {}  # Vector2i -> true
	for celda in celdas_mundo:
		huella_xz[Vector2i(celda.x, celda.z)] = true

	var despeje: Dictionary = {}  # Vector3i -> true, para deduplicar
	for celda in celdas_mundo:
		var tipo: String = celdas_mundo[celda]
		var profundidad := 0
		if tipo == "ventana":
			profundidad = 1
		elif tipo == "puerta_inferior" or tipo == "puerta_superior":
			profundidad = 2
		else:
			continue

		for direccion in VECINOS_ORTOGONALES_XZ:
			var vecino_xz := Vector2i(celda.x, celda.z) + direccion
			if huella_xz.has(vecino_xz):
				continue  # vecino es parte del propio edificio, no es "externo"
			for paso in range(1, profundidad + 1):
				var celda_despeje := Vector3i(
					celda.x + direccion.x * paso, celda.y, celda.z + direccion.y * paso
				)
				despeje[celda_despeje] = true
	return despeje.keys()


## Valida si "celdas_mundo" (las celdas estructurales de un edificio a
## punto de colocarse, mismo formato que calcular_despeje()) respeta la
## regla de despeje: (a) ninguna de sus propias celdas de despeje puede
## estar físicamente ocupada (terreno, árbol, o cualquier estructura —
## cualquier bloque real tiene un tipo no vacío, así que basta comparar
## contra "" sin enumerar tipos "sólidos"), y (b) ninguna de sus celdas
## ESTRUCTURALES puede caer dentro del despeje YA RESERVADO de otro
## edificio (celda_a_despeje). El despeje del edificio nuevo NUNCA se
## compara contra el despeje ajeno — dos despejes distintos pueden
## solaparse libremente (puertas enfrentadas, ventana sobre despeje de
## puerta ajena, etc.), ver spec punto de diseño.
func verificar_despejes(celdas_mundo: Dictionary) -> bool:
	for celda in celdas_mundo:
		if celda_a_despeje.has(celda):
			return false
	for celda_despeje in calcular_despeje(celdas_mundo):
		if obtener_tipo(celda_despeje) != "":
			return false
	return true
```

- [ ] **Step 4: Wire registration into `iniciar_construccion_fantasma()`**

Find:

```gdscript
func iniciar_construccion_fantasma(orden_relleno: Array, tipos_relleno: Dictionary, orden_estructura: Array, tipos_estructura: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden_relleno:
		colocar_bloque(celda, "fantasma")
	if not orden_relleno.is_empty():
		Construccion.iniciar(orden_relleno, tipos_relleno)
	for celda in orden_estructura:
		colocar_bloque(celda, "fantasma")
	var id: int = registrar_edificio(orden_estructura)
	edificio_orden[id] = orden_estructura
	edificio_tipos[id] = tipos_estructura
	edificio_progreso[id] = 0
	edificio_metadata[id] = metadata
	return id
```

Replace with:

```gdscript
func iniciar_construccion_fantasma(orden_relleno: Array, tipos_relleno: Dictionary, orden_estructura: Array, tipos_estructura: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden_relleno:
		colocar_bloque(celda, "fantasma")
	if not orden_relleno.is_empty():
		Construccion.iniciar(orden_relleno, tipos_relleno)
	for celda in orden_estructura:
		colocar_bloque(celda, "fantasma")
	var id: int = registrar_edificio(orden_estructura)
	edificio_orden[id] = orden_estructura
	edificio_tipos[id] = tipos_estructura
	edificio_progreso[id] = 0
	edificio_metadata[id] = metadata
	var despeje: Array = calcular_despeje(tipos_estructura)
	edificio_despeje[id] = despeje
	for celda_despeje in despeje:
		celda_a_despeje[celda_despeje] = id
	return id
```

- [ ] **Step 5: Wire registration into `registrar_edificio_completo()`**

Find:

```gdscript
func registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int:
	var orden: Array = ordenar_celdas_edificio(celdas_mundo)
	var id: int = registrar_edificio(orden)
	edificio_orden[id] = orden
	edificio_tipos[id] = celdas_mundo
	edificio_progreso[id] = orden.size()
	edificio_metadata[id] = metadata
	return id
```

Replace with:

```gdscript
func registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int:
	var orden: Array = ordenar_celdas_edificio(celdas_mundo)
	var id: int = registrar_edificio(orden)
	edificio_orden[id] = orden
	edificio_tipos[id] = celdas_mundo
	edificio_progreso[id] = orden.size()
	edificio_metadata[id] = metadata
	var despeje: Array = calcular_despeje(celdas_mundo)
	edificio_despeje[id] = despeje
	for celda_despeje in despeje:
		celda_a_despeje[celda_despeje] = id
	return id
```

- [ ] **Step 6: Release the reservation in `eliminar_edificio()`**

Find:

```gdscript
	edificio_a_celdas.erase(id)
	edificio_orden.erase(id)
	edificio_tipos.erase(id)
	edificio_progreso.erase(id)
	edificio_metadata.erase(id)
	return esquina
```

Replace with:

```gdscript
	edificio_a_celdas.erase(id)
	edificio_orden.erase(id)
	edificio_tipos.erase(id)
	edificio_progreso.erase(id)
	edificio_metadata.erase(id)
	for celda_despeje in edificio_despeje.get(id, []):
		celda_a_despeje.erase(celda_despeje)
	edificio_despeje.erase(id)
	return esquina
```

- [ ] **Step 7: Verify — headless parse and run**

Run `godot/scenes/Test.tscn` headless via Godot MCP tools (`mcp__godot__run_project`, `mcp__godot__get_debug_output`, `mcp__godot__stop_project`) — all 28 existing assertions must still pass (this task doesn't change any existing test's inputs, only adds new dead-until-called functions and extra bookkeeping in functions the tests already exercise — `iniciar_construccion_fantasma()`/`registrar_edificio_completo()`/`eliminar_edificio()` — so no existing assertion should change behavior). Also run `godot/scenes/Main.tscn` headless — must parse cleanly with only pre-existing warnings.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/VoxelWorld.gd
git commit -m "feat: reservar despeje de proximidad para ventanas y puertas de un edificio"
```

---

### Task 2: `CamaraCenital.gd` — validate despeje when placing a blueprint

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes: `mundo.verificar_despejes(celdas_mundo: Dictionary) -> bool` (from Task 1).
- Produces: nothing new for other tasks.

This task MUST run after Task 1 is committed (`mundo.verificar_despejes()` must exist).

- [ ] **Step 1: Reorder and extend `_procesar_clic_blueprint()`**

Find the entire current function (from `func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:` through its closing `_salir_de_modo_colocar_blueprint()`):

```gdscript
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)
	var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]

	if not _huella_en_zona_correcta(esquina, columnas, _blueprint_activo["zona_permitida"]):
		print("Colocación rechazada: esta zona no acepta este blueprint.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, columnas):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas, altura_blueprint)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, columnas):
		print("Colocación rechazada: la huella choca con un puesto o construcción ya colocada.")
		return
	if not _huella_tiene_columna_en_tierra(esquina, columnas):
		print("Colocación rechazada: la huella necesita al menos una columna sobre tierra firme.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for rel in columnas:
		total_drenado += mundo.drenar_agua(esquina.x + rel.x, esquina.y + rel.y)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
	var relleno_orden: Array[Vector3i] = []
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			relleno_orden.append(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y))
	var tipos_relleno: Dictionary = {}
	for celda_r in relleno_orden:
		tipos_relleno[celda_r] = "tierra"

	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, objetivo + 1 + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]
	var orden_estructura: Array = mundo.ordenar_celdas_edificio(celdas_mundo)

	var huella_xz: Array = []
	var vistos_xz: Dictionary = {}
	for celda in celdas_mundo:
		var xz := Vector2i(celda.x, celda.z)
		if not vistos_xz.has(xz):
			vistos_xz[xz] = true
			huella_xz.append(xz)

	var metadata := {
		"blueprint": _blueprint_activo,
		"huella_xz": huella_xz,
		"esquina": esquina,
		"ancho": ancho,
		"profundidad": alto,
	}
	var id_edificio: int = mundo.iniciar_construccion_fantasma(relleno_orden, tipos_relleno, orden_estructura, celdas_mundo, metadata)
	metadata["id_edificio"] = id_edificio
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()
```

Replace the WHOLE function with:

```gdscript
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)
	var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]

	if not _huella_en_zona_correcta(esquina, columnas, _blueprint_activo["zona_permitida"]):
		print("Colocación rechazada: esta zona no acepta este blueprint.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, columnas):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas, altura_blueprint)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, columnas):
		print("Colocación rechazada: la huella choca con un puesto o construcción ya colocada.")
		return
	if not _huella_tiene_columna_en_tierra(esquina, columnas):
		print("Colocación rechazada: la huella necesita al menos una columna sobre tierra firme.")
		return

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, objetivo + 1 + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]
	if not mundo.verificar_despejes(celdas_mundo):
		print("Colocación rechazada: una ventana o puerta quedaría sin el despeje mínimo, o invade el despeje de otro edificio.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for rel in columnas:
		total_drenado += mundo.drenar_agua(esquina.x + rel.x, esquina.y + rel.y)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
	var relleno_orden: Array[Vector3i] = []
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			relleno_orden.append(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y))
	var tipos_relleno: Dictionary = {}
	for celda_r in relleno_orden:
		tipos_relleno[celda_r] = "tierra"

	var orden_estructura: Array = mundo.ordenar_celdas_edificio(celdas_mundo)

	var huella_xz: Array = []
	var vistos_xz: Dictionary = {}
	for celda in celdas_mundo:
		var xz := Vector2i(celda.x, celda.z)
		if not vistos_xz.has(xz):
			vistos_xz[xz] = true
			huella_xz.append(xz)

	var metadata := {
		"blueprint": _blueprint_activo,
		"huella_xz": huella_xz,
		"esquina": esquina,
		"ancho": ancho,
		"profundidad": alto,
	}
	var id_edificio: int = mundo.iniciar_construccion_fantasma(relleno_orden, tipos_relleno, orden_estructura, celdas_mundo, metadata)
	metadata["id_edificio"] = id_edificio
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()
```

Note what changed: `objetivo` and `celdas_mundo` are now computed BEFORE the follaje/water side effects (previously they were computed after), with the new despeje rejection check placed right after computing `celdas_mundo`. `relleno`/`relleno_orden`/`tipos_relleno`/`orden_estructura` are unchanged internally, just moved later in the function (after the side effects, same relative order as before those side effects). The final `iniciar_construccion_fantasma()` call and everything after it is byte-identical to before.

- [ ] **Step 2: Verify — headless parse and run**

Run `godot/scenes/Main.tscn` headless — must parse cleanly with only pre-existing warnings. Do not run `BlueprintValidatorTest.tscn`'s despeje-specific tests yet (Task 4 adds them) — running the existing 28 tests via `godot/scenes/Test.tscn` should still pass unchanged (this function isn't exercised by any current automated test — confirm via `grep -n "_procesar_clic_blueprint" godot/scripts/BlueprintValidatorTest.gd` that it returns no matches).

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: rechazar la colocación de un blueprint si viola el despeje de ventanas/puertas"
```

---

### Task 3: `Player.gd` — validate despeje when declaring a hand-built structure

**Files:**
- Modify: `godot/scripts/Player.gd`

**Interfaces:**
- Consumes: `mundo.verificar_despejes(celdas: Dictionary) -> bool` (from Task 1) — `celdas` here is the `Dictionary` already returned by `mundo.detectar_estructura()` inside `_declarar_edificio()`, already in the exact `Vector3i -> String` shape `verificar_despejes()` expects.
- Produces: nothing new for other tasks.

This task MUST run after Task 1 is committed.

- [ ] **Step 1: Add the despeje check to `_declarar_edificio()`**

Find:

```gdscript
	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if not resultado["valido"]:
		return

	Blueprints.guardar(blueprint)
```

Replace with:

```gdscript
	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if not resultado["valido"]:
		return
	if not mundo.verificar_despejes(celdas):
		print("Declarar edificio: una ventana o puerta quedaría sin el despeje mínimo, o invade el despeje de otro edificio.")
		return

	Blueprints.guardar(blueprint)
```

- [ ] **Step 2: Verify — headless parse**

Run `godot/scenes/Main.tscn` headless — must parse cleanly with only pre-existing warnings.

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/Player.gd
git commit -m "feat: rechazar declarar un edificio a mano si viola el despeje de ventanas/puertas"
```

---

### Task 4: `BlueprintValidatorTest.gd` — tests for despeje calculation, validation, overlap, and release

**Files:**
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `mundo.calcular_despeje()`, `mundo.verificar_despejes()`, `mundo.registrar_edificio_completo()`, `mundo.eliminar_edificio()` — all from Task 1.
- Produces: nothing (leaf task).

This task MUST run after Task 1 is committed (Tasks 2/3 don't need to be done first — these tests call `VoxelWorld` functions directly, not through `CamaraCenital.gd`/`Player.gd`).

- [ ] **Step 1: Insert TEST 28 through TEST 33**

Find the exact tail of the file:

```gdscript
	var _s1_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	var s2_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	assert(s2_27["completa"])
	assert(s2_27["metadata"] == metadata_27, "La metadata pasada a registrar_edificio_completo() se conserva")
	print("OK: un edificio declarado a mano (registrar_edificio_completo()) es tan reversible como uno por blueprint, sin perder su metadata.")

	print("\n=== Las 28 pruebas de BlueprintValidator pasaron correctamente ===")
```

Replace with:

```gdscript
	var _s1_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	var s2_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	assert(s2_27["completa"])
	assert(s2_27["metadata"] == metadata_27, "La metadata pasada a registrar_edificio_completo() se conserva")
	print("OK: un edificio declarado a mano (registrar_edificio_completo()) es tan reversible como uno por blueprint, sin perder su metadata.")

	print("\n=== TEST 28: calcular_despeje() de una ventana exige 1 celda hacia el lado externo ===")
	const OX16 := 1010
	# Edificio de 1x1: una única celda "ventana" en (OX16, 1, OX16). Su
	# huella es solo esa columna, así que sus 4 vecinos XZ son TODOS
	# externos -- calcular_despeje() debe reservar las 4, una por cada
	# lado, a la misma altura Y.
	var celda_ventana_28 := Vector3i(OX16, 1, OX16)
	var celdas_mundo_28 := {celda_ventana_28: "ventana"}
	var despeje_28: Array = mundo.calcular_despeje(celdas_mundo_28)
	assert(despeje_28.size() == 4, "Una ventana aislada (huella de 1 celda) tiene sus 4 lados externos")
	for direccion_28 in mundo.VECINOS_ORTOGONALES_XZ:
		var esperado_28 := Vector3i(OX16 + direccion_28.x, 1, OX16 + direccion_28.y)
		assert(despeje_28.has(esperado_28), "Falta la celda de despeje en la dirección " + str(direccion_28))
	print("OK: calcular_despeje() reserva exactamente 1 celda por cada lado externo de una ventana.")

	print("\n=== TEST 29: calcular_despeje() de una puerta exige 2 celdas en AMBOS niveles ===")
	const OX17 := 1020
	# Edificio de 1x1 con una puerta completa (2 celdas verticales) en la
	# misma columna. Igual que TEST 28, huella de 1 celda -> los 4 lados
	# son externos, pero ahora con profundidad 2 en cada nivel Y: 4
	# direcciones x 2 niveles x 2 celdas de profundidad = 16 celdas.
	var celda_puerta_inf_29 := Vector3i(OX17, 1, OX17)
	var celda_puerta_sup_29 := Vector3i(OX17, 2, OX17)
	var celdas_mundo_29 := {
		celda_puerta_inf_29: "puerta_inferior",
		celda_puerta_sup_29: "puerta_superior",
	}
	var despeje_29: Array = mundo.calcular_despeje(celdas_mundo_29)
	assert(despeje_29.size() == 16, "4 direcciones x 2 niveles x 2 celdas de profundidad = 16")
	for direccion_29 in mundo.VECINOS_ORTOGONALES_XZ:
		for nivel_29 in [1, 2]:
			for paso_29 in [1, 2]:
				var esperado_29 := Vector3i(
					OX17 + direccion_29.x * paso_29, nivel_29, OX17 + direccion_29.y * paso_29
				)
				assert(despeje_29.has(esperado_29), "Falta despeje de puerta en nivel " + str(nivel_29))
	print("OK: calcular_despeje() reserva 2 celdas de profundidad por cada lado externo de una puerta, en ambos niveles.")

	print("\n=== TEST 30: verificar_despejes() rechaza si el propio despeje no está vacío ===")
	const OX18 := 1030
	var celda_ventana_30 := Vector3i(OX18, 1, OX18)
	var celdas_mundo_30 := {celda_ventana_30: "ventana"}
	var celda_bloqueo_30 := Vector3i(OX18 + 1, 1, OX18)  # una de las 4 celdas de despeje
	mundo.colocar_bloque(celda_bloqueo_30, "madera")
	assert(not mundo.verificar_despejes(celdas_mundo_30), "El despeje de la ventana está ocupado por un árbol")
	mundo.minar_bloque(celda_bloqueo_30)
	assert(mundo.verificar_despejes(celdas_mundo_30), "Con el despeje vacío, la validación debe pasar")
	print("OK: verificar_despejes() rechaza cuando el propio despeje no está físicamente vacío.")

	print("\n=== TEST 31: verificar_despejes() rechaza si una celda estructural nueva invade el despeje ajeno ===")
	const OX19 := 1040
	var celda_ventana_31 := Vector3i(OX19, 1, OX19)
	var celdas_mundo_31a := {celda_ventana_31: "ventana"}
	mundo.colocar_bloque(celda_ventana_31, "ventana", true)
	mundo.registrar_edificio_completo(celdas_mundo_31a)
	# El despeje de esta ventana incluye Vector3i(OX19 + 1, 1, OX19). Un
	# segundo edificio hipotético con una pared exactamente ahí debe ser
	# rechazado.
	var celda_pared_31 := Vector3i(OX19 + 1, 1, OX19)
	var celdas_mundo_31b := {celda_pared_31: "pared"}
	assert(not mundo.verificar_despejes(celdas_mundo_31b), "Una pared nueva no puede caer en el despeje reservado de otro edificio")
	print("OK: verificar_despejes() rechaza una celda estructural nueva que invade el despeje reservado de otro edificio.")

	print("\n=== TEST 32: los despejes de dos edificios distintos pueden solaparse libremente ===")
	const OX20 := 1050
	# Dos edificios de 1x1 con puertas enfrentadas, separados por 2 celdas
	# vacías en X -- sus despejes (2 celdas de profundidad cada uno) se
	# solapan exactamente en el hueco del medio, pero ninguna celda
	# ESTRUCTURAL de uno cae en el despeje del otro.
	var celda_puerta_a_32 := Vector3i(OX20, 1, OX20)
	var celda_puerta_b_32 := Vector3i(OX20 + 3, 1, OX20)
	mundo.colocar_bloque(celda_puerta_a_32, "puerta_inferior", true)
	mundo.colocar_bloque(celda_puerta_a_32 + Vector3i(0, 1, 0), "puerta_superior", true)
	var celdas_mundo_32a := {
		celda_puerta_a_32: "puerta_inferior",
		celda_puerta_a_32 + Vector3i(0, 1, 0): "puerta_superior",
	}
	mundo.registrar_edificio_completo(celdas_mundo_32a)
	var celdas_mundo_32b := {
		celda_puerta_b_32: "puerta_inferior",
		celda_puerta_b_32 + Vector3i(0, 1, 0): "puerta_superior",
	}
	assert(mundo.verificar_despejes(celdas_mundo_32b), "El segundo edificio debe poder colocarse: su despeje se solapa con el del primero, pero ninguna celda estructural invade al otro")
	mundo.colocar_bloque(celda_puerta_b_32, "puerta_inferior", true)
	mundo.colocar_bloque(celda_puerta_b_32 + Vector3i(0, 1, 0), "puerta_superior", true)
	mundo.registrar_edificio_completo(celdas_mundo_32b)
	print("OK: los despejes de dos edificios distintos pueden solaparse sin rechazo, solo se prohíbe invadir con una celda estructural.")

	print("\n=== TEST 33: eliminar_edificio() libera la reserva de despeje ===")
	const OX21 := 1060
	var celda_ventana_33 := Vector3i(OX21, 1, OX21)
	mundo.colocar_bloque(celda_ventana_33, "ventana", true)
	var celdas_mundo_33 := {celda_ventana_33: "ventana"}
	var id_33: int = mundo.registrar_edificio_completo(celdas_mundo_33)
	var celda_pared_33 := Vector3i(OX21 + 1, 1, OX21)  # cae en el despeje de la ventana
	var celdas_mundo_33b := {celda_pared_33: "pared"}
	assert(not mundo.verificar_despejes(celdas_mundo_33b), "Antes de eliminar, el despeje sigue bloqueando")
	mundo.eliminar_edificio(id_33)
	assert(mundo.verificar_despejes(celdas_mundo_33b), "Tras eliminar el edificio, su despeje debe liberarse de inmediato")
	print("OK: eliminar_edificio() libera por completo la reserva de despeje del edificio eliminado.")

	print("\n=== Las 34 pruebas de BlueprintValidator pasaron correctamente ===")
```

- [ ] **Step 2: Update the header doc comment**

Find the header comment's tail (the part describing tests 22-27 and the
final test-count/instruction line):

```
## registrar_edificio_completo() deja un edificio declarado a mano tan
## reversible como uno por blueprint, sin perder su metadata (27, ver
## Player._declarar_edificio()).
## Correr esta escena (Test.tscn) con F6 en el editor de Godot y revisar el
## panel "Output": debe imprimir los 28 tests y no debe lanzar ningún error
## de assert().
```

Replace with:

```
## registrar_edificio_completo() deja un edificio declarado a mano tan
## reversible como uno por blueprint, sin perder su metadata (27, ver
## Player._declarar_edificio()), que calcular_despeje() reserva 1 celda
## externa por ventana y 2 por puerta en ambos niveles (28-29, ver
## docs/superpowers/specs/2026-09-11-despeje-ventanas-puertas-design.md),
## que verificar_despejes() rechaza tanto un despeje propio ocupado (30)
## como una celda estructural nueva que invade el despeje ajeno (31), que
## los despejes de dos edificios distintos pueden solaparse libremente sin
## rechazo (32), y que eliminar_edificio() libera la reserva de despeje de
## inmediato (33).
## Correr esta escena (Test.tscn) con F6 en el editor de Godot y revisar el
## panel "Output": debe imprimir los 34 tests y no debe lanzar ningún error
## de assert().
```

- [ ] **Step 3: Run the full test suite**

Run, headless via Godot MCP tools: `godot/scenes/Test.tscn`, `godot/scenes/Main.tscn`. All assertions must pass (34 tests total); `Main.tscn` must show only the expected pre-existing warnings.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/BlueprintValidatorTest.gd
git commit -m "test: agregar pruebas 28-33 para el despeje de ventanas y puertas"
```

---

## Final Verification (whole branch)

After all 4 tasks are committed:

1. Run `godot/scenes/Test.tscn` headless — 34/34 assertions pass, zero errors.
2. Run `godot/scenes/Main.tscn` headless — zero parse errors, only the expected known warnings.
3. Manually verify (in-editor, by the user) the 4 integration scenarios listed in the spec's "Verificación de integración" section: a blueprint with a window rejected next to a tree/raised terrain, a door/window rejected too close to an existing one, two facing doors 2 cells apart accepted, and deconstructing a building immediately freeing its despeje for new construction.
