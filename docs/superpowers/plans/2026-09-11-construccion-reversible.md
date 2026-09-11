# Construcción/Deconstrucción Reversible Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two one-way queues (`Construccion.gd` + `VoxelWorld._cola_decon`) that model building construction/deconstruction with a single bidirectional progress-index per building, fixing three playtested UX bugs (wrong deconstruction direction, ghost area-lock after partial deconstruction, no real reversibility).

**Architecture:** Each building gets a fixed cell order (`edificio_orden[id]`) and a single progress counter (`edificio_progreso[id]`) that both `surtir_construccion()` (increments) and `procesar_deconstruccion()` (decrements) move. `Construccion.gd` keeps existing exactly as-is but is used ONLY for terrain-leveling fill going forward; buildings never touch it again.

**Tech Stack:** Godot 4.7 GDScript, GridMap-based voxel world, autoload pattern (`extends Node`, no `class_name`).

**Spec:** `docs/superpowers/specs/2026-09-11-construccion-reversible-design.md`

## Global Constraints

- Tabs for indentation in all GDScript (Godot convention, CLAUDE.md).
- Keep Spanish in all comments, print messages, and test names (CLAUDE.md).
- Do not reformat unrelated code — only touch the functions/consts named in each task.
- Run `godot/scenes/Test.tscn`, `BlueprintValidatorTest.tscn`, `ConstruccionTest.tscn`, and `Main.tscn` (headless parse) after every task — all assertions must pass, `Main.tscn` must show only the expected pre-existing warnings.
- The relleno de nivelación (`Construccion.gd` queue) NEVER becomes part of `edificio_orden`/`celda_a_edificio` — it must remain minable/normal terrain at all times, exactly as established in the prior deconstruction spec (point 2.5).
- `total_camas` in `procesar_deconstruccion()`'s return must be nonzero ONLY on the exact call where `edificio_progreso[id]` crosses from `orden.size()` to `orden.size() - 1` — never on any other call, to keep `Ciudad.registrar_edificio_residencial()`/`retirar_edificio_residencial()` balanced across repeated complete/deconstruct cycles.

---

### Task 1: `VoxelWorld.gd` — new bidirectional data model and core functions

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`

**Interfaces:**
- Produces: `edificio_orden: Dictionary`, `edificio_tipos: Dictionary`, `edificio_progreso: Dictionary`, `edificio_metadata: Dictionary` (all `int id -> ...`, new instance vars); `ordenar_celdas_edificio(celdas_mundo: Dictionary) -> Array` (new PUBLIC function, no leading underscore); `iniciar_construccion_fantasma(orden_relleno: Array, tipos_relleno: Dictionary, orden_estructura: Array, tipos_estructura: Dictionary, metadata: Dictionary = {}) -> int` (NEW signature, 5 params instead of 4); `registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int` (new function); `surtir_construccion(celda: Vector3i) -> Dictionary` (rewritten, same return shape `{"completa": bool, "metadata": Dictionary}` or `{}`); `procesar_deconstruccion(celda: Vector3i) -> Dictionary` (rewritten, same return shape `{"id": int, "completa_reversion": bool, "lista_para_remocion": bool, "total_camas": int}` or `{}`); `eliminar_edificio(id: int) -> Vector2i` (same signature, updated body).
- Consumes: existing `registrar_edificio(celdas: Array) -> int`, `id_de_edificio(celda: Vector3i) -> int`, `colocar_bloque()`, `set_cell_item()`, `obtener_tipo()`, `_revertir_celda()`, `reemparejar_construccion()`, `Construccion.iniciar()/avanzar()/construccion_de()` (all unchanged — Task 1 does not touch their bodies).

- [ ] **Step 1: Remove `_cola_decon`, add the four new dictionaries**

Find this line (near the existing `edificio_a_celdas` declaration):

```gdscript
var _cola_decon: Dictionary = {}  # int (id edificio) -> int (id cola)
```

Replace it with:

```gdscript
## Por edificio (id de VoxelWorld.registrar_edificio()): el orden FIJO de
## sus celdas estructurales (piso -> paredes/puertas/ventanas ->
## mobiliario), sus tipos, y cuántas celdas desde el inicio de ese orden
## son actualmente reales ("progreso"). Reemplaza el modelo de dos colas
## de un solo sentido (Construccion.gd + _cola_decon) por un único índice
## que se mueve en ambas direcciones — ver
## docs/superpowers/specs/2026-09-11-construccion-reversible-design.md.
## Nunca se usa para el relleno de nivelación, que sigue en Construccion.gd
## (proceso de un solo sentido, aislado del edificio desde el spec de
## deconstrucción, punto 2.5).
var edificio_orden: Dictionary = {}  # int -> Array[Vector3i]
var edificio_tipos: Dictionary = {}  # int -> Dictionary (Vector3i -> String)
var edificio_progreso: Dictionary = {}  # int -> int
var edificio_metadata: Dictionary = {}  # int -> Dictionary
```

- [ ] **Step 2: Replace `ORDEN_GRUPOS_DECONSTRUCCION`/`_ordenar_celdas_deconstruccion()`**

Find:

```gdscript
const ORDEN_GRUPOS_DECONSTRUCCION := [
	["cama_cabecera", "cama_pies", "baul"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["piso"],
	["tierra"],
]


## Agrupa y ordena "celdas_mundo" (Vector3i real -> tipo) según
## ORDEN_GRUPOS_DECONSTRUCCION, y dentro de cada grupo por (y, x, z) —
## mismo patrón exacto que CamaraCenital._ordenar_celdas_construccion(),
## con el orden de grupos invertido.
func _ordenar_celdas_deconstruccion(celdas_mundo: Dictionary) -> Array:
	var orden: Array[Vector3i] = []
	for grupo in ORDEN_GRUPOS_DECONSTRUCCION:
		var celdas_grupo: Array[Vector3i] = []
		for celda in celdas_mundo:
			if grupo.has(celdas_mundo[celda]):
				celdas_grupo.append(celda)
		celdas_grupo.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.x != b.x:
				return a.x < b.x
			return a.z < b.z
		)
		orden.append_array(celdas_grupo)
	return orden
```

Replace with:

```gdscript
## Orden canónico y ÚNICO de las celdas estructurales de un edificio —
## piso primero, luego paredes/puertas/ventanas, luego mobiliario. Se usa
## en ambos sentidos: surtir_construccion() avanza edificio_progreso[id] a
## través de este mismo orden, procesar_deconstruccion() lo retrocede. No
## existe un orden "invertido" aparte — decrementar por el mismo camino
## con el que se construyó ya quita primero lo último agregado (mobiliario
## -> paredes -> piso), dando la sensación correcta de "arriba hacia
## abajo" sin ninguna regla especial.
const ORDEN_GRUPOS_EDIFICIO := [
	["piso"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["cama_cabecera", "cama_pies", "baul"],
]


## Agrupa y ordena "celdas_mundo" (Vector3i real -> tipo) según
## ORDEN_GRUPOS_EDIFICIO, y dentro de cada grupo por (y, x, z). Pública
## (sin guion bajo) porque CamaraCenital._procesar_clic_blueprint() la
## llama para calcular "orden_estructura" antes de iniciar_construccion_
## fantasma() (ver Task 3).
func ordenar_celdas_edificio(celdas_mundo: Dictionary) -> Array:
	var orden: Array[Vector3i] = []
	for grupo in ORDEN_GRUPOS_EDIFICIO:
		var celdas_grupo: Array[Vector3i] = []
		for celda in celdas_mundo:
			if grupo.has(celdas_mundo[celda]):
				celdas_grupo.append(celda)
		celdas_grupo.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.x != b.x:
				return a.x < b.x
			return a.z < b.z
		)
		orden.append_array(celdas_grupo)
	return orden
```

- [ ] **Step 3: Rewrite `procesar_deconstruccion()`**

Find the entire current function (starts with the doc comment block above
`func procesar_deconstruccion(celda: Vector3i) -> Dictionary:` and ends at
its closing `return {"id": id, "completa_reversion": resultado["completa"], "lista_para_remocion": resultado["completa"], "total_camas": total_camas}`).
Replace the WHOLE function (doc comment included) with:

```gdscript
## Procesa un intento de deconstrucción apuntando a "celda". Devuelve {} si
## "celda" no pertenece a ningún edificio con edificio_orden registrado
## (p. ej. un puesto periférico, que nunca pasa por aquí). Revierte SIEMPRE
## la celda en orden[progreso - 1] (la última agregada, sin importar cuál
## celda concreta se apuntó) y decrementa el progreso — mismo patrón
## "avanza siempre la primera/última pendiente" que ya usaba
## surtir_construccion(), en reversa.
##
## Devuelve {"id": int, "completa_reversion": bool,
## "lista_para_remocion": bool, "total_camas": int} — "total_camas" es el
## número de "cama_cabecera" del edificio, PERO SOLO tiene sentido cuando
## esta llamada cruza el borde de "edificio recién terminado" hacia
## "edificio ya no completo" (progreso pasa de orden.size() a
## orden.size() - 1); en cualquier otra llamada vale 0, para no
## contabilizar camas más de una vez si se deconstruye y se vuelve a
## completar varias veces (ver Ciudad.registrar_edificio_residencial(),
## que no es idempotente). "lista_para_remocion"/"completa_reversion" son
## true cuando el progreso llega a 0.
func procesar_deconstruccion(celda: Vector3i) -> Dictionary:
	var id: int = id_de_edificio(celda)
	if id == -1 or not edificio_orden.has(id):
		return {}
	var orden: Array = edificio_orden[id]
	var progreso: int = edificio_progreso[id]
	if progreso == 0:
		return {"id": id, "completa_reversion": true, "lista_para_remocion": true, "total_camas": 0}

	var total_camas := 0
	if progreso == orden.size():
		for c in orden:
			if edificio_tipos[id][c] == "cama_cabecera":
				total_camas += 1

	var celda_a_revertir: Vector3i = orden[progreso - 1]
	_revertir_celda(celda_a_revertir)
	edificio_progreso[id] = progreso - 1
	var vacio: bool = edificio_progreso[id] == 0
	return {"id": id, "completa_reversion": vacio, "lista_para_remocion": vacio, "total_camas": total_camas}
```

- [ ] **Step 4: Update `eliminar_edificio()`**

Find:

```gdscript
	edificio_a_celdas.erase(id)
	_cola_decon.erase(id)
	return esquina
```

Replace with:

```gdscript
	edificio_a_celdas.erase(id)
	edificio_orden.erase(id)
	edificio_tipos.erase(id)
	edificio_progreso.erase(id)
	edificio_metadata.erase(id)
	return esquina
```

(Leave the rest of `eliminar_edificio()` — the loop over `celdas`,
`pareja` cleanup, `set_cell_item`, `celda_a_edificio.erase` — untouched.)

- [ ] **Step 5: Rewrite `iniciar_construccion_fantasma()`**

Find:

```gdscript
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, celdas_estructurales: Array, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	var id_edificio: int = registrar_edificio(celdas_estructurales)
	Construccion.iniciar(orden, tipos, metadata)
	return id_edificio
```

Replace with:

```gdscript
## Arranca un edificio fantasma. "orden_relleno"/"tipos_relleno" son las
## celdas de nivelación de terreno (si las hay) — siguen pasando por
## "fantasma" y su propia cola de un solo sentido en Construccion.gd,
## exactamente igual que antes de este rediseño (nunca se registran como
## parte del edificio, ver spec anterior punto 2.5). "orden_estructura" (ya
## en el orden canónico de ordenar_celdas_edificio()) y "tipos_estructura"
## son las celdas del edificio en sí — esas NO pasan por Construccion.gd:
## se registran directamente en edificio_orden/edificio_tipos/
## edificio_progreso (progreso arranca en 0, todas fantasma). Devuelve el
## id nuevo.
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


## Registra un edificio YA terminado (todas sus celdas reales desde el
## inicio) — usado por Player._declarar_edificio() para que un edificio
## declarado a mano (nunca pasó por iniciar_construccion_fantasma()) tenga
## el mismo edificio_orden/edificio_progreso que uno construido por
## blueprint, y así pueda deconstruirse y volver a completarse igual que
## cualquier otro. "celdas_mundo" es Vector3i real -> tipo (todas las
## celdas estructurales ya colocadas). Devuelve el id nuevo.
func registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int:
	var orden: Array = ordenar_celdas_edificio(celdas_mundo)
	var id: int = registrar_edificio(orden)
	edificio_orden[id] = orden
	edificio_tipos[id] = celdas_mundo
	edificio_progreso[id] = orden.size()
	edificio_metadata[id] = metadata
	return id
```

- [ ] **Step 6: Rewrite `surtir_construccion()`**

Find:

```gdscript
func surtir_construccion(celda: Vector3i) -> Dictionary:
	if _cola_decon.values().has(Construccion.construccion_de(celda)):
		return {}
	var id: int = Construccion.construccion_de(celda)
	if id == -1:
		return {}
	var resultado: Dictionary = Construccion.avanzar(id)
	if resultado.is_empty():
		return {}
	set_cell_item(resultado["celda"], GridMap.INVALID_CELL_ITEM)
	colocar_bloque(resultado["celda"], resultado["tipo"], true)
	if resultado["completa"]:
		reemparejar_construccion(resultado["orden"])
	return {"completa": resultado["completa"], "metadata": resultado["metadata"]}
```

Replace with:

```gdscript
## Avanza, según a qué pertenezca "celda": si todavía es parte de una cola
## de RELLENO activa en Construccion.gd, avanza esa cola (comportamiento
## sin cambios respecto a antes de este rediseño) y devuelve un resultado
## sin "completa" (el relleno nunca dispara _completar_construccion()). En
## cualquier otro caso, busca el edificio por id_de_edificio() — sirve
## apuntar a CUALQUIER celda del edificio (p. ej. una pared exterior ya
## real) para surtir la SIGUIENTE celda pendiente en edificio_orden, sin
## importar si "celda" en sí ya es real. No-op ({}) si "celda" no
## pertenece a ningún relleno pendiente NI a ningún edificio con progreso
## incompleto.
func surtir_construccion(celda: Vector3i) -> Dictionary:
	var id_relleno: int = Construccion.construccion_de(celda)
	if id_relleno != -1:
		var resultado_relleno: Dictionary = Construccion.avanzar(id_relleno)
		if resultado_relleno.is_empty():
			return {}
		set_cell_item(resultado_relleno["celda"], GridMap.INVALID_CELL_ITEM)
		colocar_bloque(resultado_relleno["celda"], resultado_relleno["tipo"], true)
		return {"completa": false, "metadata": {}}

	var id: int = id_de_edificio(celda)
	if id == -1 or not edificio_orden.has(id):
		return {}
	var orden: Array = edificio_orden[id]
	var progreso: int = edificio_progreso[id]
	if progreso >= orden.size():
		return {}
	var celda_a_surtir: Vector3i = orden[progreso]
	var tipo: String = edificio_tipos[id][celda_a_surtir]
	set_cell_item(celda_a_surtir, GridMap.INVALID_CELL_ITEM)
	colocar_bloque(celda_a_surtir, tipo, true)
	edificio_progreso[id] = progreso + 1
	var completa: bool = edificio_progreso[id] == orden.size()
	if completa:
		reemparejar_construccion(orden)
	return {"completa": completa, "metadata": edificio_metadata[id]}
```

- [ ] **Step 7: Verify — parse and run tests (expect failures, not yet fixed)**

Run `godot/scenes/BlueprintValidatorTest.tscn` and `godot/scenes/Main.tscn`
headless via the Godot MCP tools. `BlueprintValidatorTest.tscn` WILL fail
at this point (TEST 18/20/22-26 still call the OLD 3-arg
`iniciar_construccion_fantasma()` signature and old `Construccion.cancelar()`-era
assertions) — that is expected; Task 5 fixes the test file. Confirm the
failure is a parse/argument-count error in `BlueprintValidatorTest.gd`
specifically (not an unrelated crash in `VoxelWorld.gd` itself), and that
`Main.tscn` parses cleanly (it doesn't call any of the changed functions
directly).

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/VoxelWorld.gd
git commit -m "feat: VoxelWorld usa un índice de progreso bidireccional por edificio"
```

---

### Task 2: `Construccion.gd` — remove dead `cancelar()`

**Files:**
- Modify: `godot/scripts/Construccion.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new (pure deletion). `iniciar()`, `avanzar()`,
  `construccion_de()` remain unchanged and are still used by the relleno
  queue (Task 1's `iniciar_construccion_fantasma()`/`surtir_construccion()`).

- [ ] **Step 1: Delete `cancelar()`**

Find and delete this entire function (it is the last function in the file):

```gdscript
func cancelar(id: int) -> Array:
	if not _construcciones.has(id):
		return []
	var datos: Dictionary = _construcciones[id]
	var orden: Array = datos["orden"]
	var indice: int = datos["indice"]
	var pendientes: Array = orden.slice(indice)
	for c in orden:
		_celda_a_construccion.erase(c)
	_construcciones.erase(id)
	return pendientes
```

Confirmed via grep that no file calls `Construccion.cancelar()` after
Task 1 (its only caller was the old `VoxelWorld.procesar_deconstruccion()`,
already rewritten). Re-run the grep yourself before deleting to be sure:

```bash
grep -rn "Construccion.cancelar\|\.cancelar(" godot/scripts
```

Expect zero matches outside `Construccion.gd` itself.

- [ ] **Step 2: Verify — headless parse**

Run `godot/scenes/ConstruccionTest.tscn` headless — must still pass all 5
tests (none of them call `cancelar()`).

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/Construccion.gd
git commit -m "refactor: eliminar Construccion.cancelar(), sin llamadores tras el rediseño"
```

---

### Task 3: `CamaraCenital.gd` — collision-check fix, dead code removal, new blueprint call

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes: `mundo.id_de_edificio(celda: Vector3i) -> int` (existing),
  `mundo.ordenar_celdas_edificio(celdas_mundo: Dictionary) -> Array` (new,
  from Task 1), `mundo.iniciar_construccion_fantasma(orden_relleno, tipos_relleno, orden_estructura, tipos_estructura, metadata) -> int`
  (new 5-arg signature, from Task 1).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Fix `_huella_choca_con_otro_puesto()`**

Find:

```gdscript
		var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
		if Construccion.construccion_de(celda_superficie) != -1:
			return true
```

Replace with:

```gdscript
		var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
		if mundo.id_de_edificio(celda_superficie) != -1:
			return true
```

- [ ] **Step 2: Delete `ORDEN_GRUPOS_CONSTRUCCION`/`_ordenar_celdas_construccion()`**

Find and delete this entire const + function:

```gdscript
const ORDEN_GRUPOS_CONSTRUCCION := [
	["piso"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["cama_cabecera", "cama_pies", "baul"],
]
func _ordenar_celdas_construccion(celdas_mundo: Dictionary) -> Array:
	var orden: Array[Vector3i] = []
	for grupo in ORDEN_GRUPOS_CONSTRUCCION:
		var celdas_grupo: Array[Vector3i] = []
		for celda in celdas_mundo:
			if grupo.has(celdas_mundo[celda]):
				celdas_grupo.append(celda)
		celdas_grupo.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.x != b.x:
				return a.x < b.x
			return a.z < b.z
		)
		orden.append_array(celdas_grupo)
	return orden
```

(Confirm via `grep -n "_ordenar_celdas_construccion\|ORDEN_GRUPOS_CONSTRUCCION" godot/scripts/CamaraCenital.gd` that the only remaining reference before this step is its own definition plus the one call site fixed in Step 3.)

- [ ] **Step 3: Rewrite the tail of `_procesar_clic_blueprint()`**

Find (this is the second half of the function, from the relleno
calculation onward):

```gdscript
	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
	var relleno_orden: Array[Vector3i] = []
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			relleno_orden.append(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y))

	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, objetivo + 1 + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]

	var orden: Array = relleno_orden + _ordenar_celdas_construccion(celdas_mundo)
	var tipos: Dictionary = {}
	for celda_r in relleno_orden:
		tipos[celda_r] = "tierra"
	for celda in celdas_mundo:
		tipos[celda] = celdas_mundo[celda]

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
	var id_edificio: int = mundo.iniciar_construccion_fantasma(orden, tipos, celdas_mundo.keys(), metadata)
	metadata["id_edificio"] = id_edificio
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()
```

Replace with:

```gdscript
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

- [ ] **Step 4: Verify — headless parse**

Run `godot/scenes/Main.tscn` headless. Confirm no parse errors and only
the expected pre-existing warnings (see CLAUDE.md/project convention: 2
class-name-collision warnings, or 5 "invalid UID" warnings on a fresh
worktree — both are known-harmless).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "fix: CamaraCenital usa el nuevo modelo de edificio (colisión + blueprint)"
```

---

### Task 4: `Player.gd` — unify `_declarar_edificio()` with `_completar_construccion()`

**Files:**
- Modify: `godot/scripts/Player.gd`

**Interfaces:**
- Consumes: `mundo.registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int` (new, from Task 1); existing `_completar_construccion(metadata: Dictionary) -> void` (unchanged body — already registers camas/zona/puesto, see current `Player.gd:344-361`).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Rewrite `_declarar_edificio()`**

Find the entire current function (from `func _declarar_edificio() -> void:`
through its closing lines that call `Zonificacion.declarar_nucleo()`/
`Zonificacion.ampliar_influencia()`):

```gdscript
func _declarar_edificio() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	var tipo_apuntado: String = mundo.obtener_tipo(celda)
	if tipo_apuntado != "puerta_inferior" and tipo_apuntado != "puerta_superior":
		print("Declarar edificio: apunta a la puerta principal de la estructura.")
		return
	var celdas: Dictionary = mundo.detectar_estructura(celda)
	if celdas.is_empty():
		print("Declarar edificio: esa puerta no fue colocada por el jugador.")
		return
	var blueprint := BlueprintValidator.estructura_a_blueprint(celdas)

	# Huella en planta (X,Z) del edificio, sin repetir celdas — usada tanto
	# para el bootstrap del núcleo urbano como, más adelante, para pintarla
	# como Núcleo A. "celda" es la puerta apuntada, la misma referencia que
	# ya usa detectar_estructura() para "dónde está" el edificio.
	var celda_puerta_xz := Vector2i(celda.x, celda.z)
	var huella: Array = []
	var huella_vista: Dictionary = {}  # Vector2i -> true, para no repetir celdas
	for pos in celdas.keys():
		var punto_xz := Vector2i(pos.x, pos.z)
		if not huella_vista.has(punto_xz):
			huella_vista[punto_xz] = true
			huella.append(punto_xz)

	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino)

	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if resultado["valido"]:
		Blueprints.guardar(blueprint)
		var id_edificio: int = mundo.registrar_edificio(celdas.keys())
		var total_camas := 0
		for piso in blueprint["pisos"]:
			total_camas += (piso.get("camas", []) as Array).size()
		Ciudad.registrar_edificio_residencial(total_camas)
		print("Camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

		if not Zonificacion.nucleo_declarado:
			Zonificacion.declarar_nucleo(huella)
			print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
		else:
			Zonificacion.ampliar_influencia(id_edificio, huella, blueprint["categoria"])
			print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
```

Replace with:

```gdscript
func _declarar_edificio() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	var tipo_apuntado: String = mundo.obtener_tipo(celda)
	if tipo_apuntado != "puerta_inferior" and tipo_apuntado != "puerta_superior":
		print("Declarar edificio: apunta a la puerta principal de la estructura.")
		return
	var celdas: Dictionary = mundo.detectar_estructura(celda)
	if celdas.is_empty():
		print("Declarar edificio: esa puerta no fue colocada por el jugador.")
		return
	var blueprint := BlueprintValidator.estructura_a_blueprint(celdas)

	# Huella en planta (X,Z) del edificio, sin repetir celdas — usada tanto
	# para el bootstrap del núcleo urbano como, más adelante, para pintarla
	# como Núcleo A. "celda" es la puerta apuntada, la misma referencia que
	# ya usa detectar_estructura() para "dónde está" el edificio. "esquina"
	# (mínimo x, mínimo z) se calcula en la misma pasada, para pasarla a
	# _completar_construccion() vía metadata igual que un blueprint.
	var celda_puerta_xz := Vector2i(celda.x, celda.z)
	var huella: Array = []
	var huella_vista: Dictionary = {}  # Vector2i -> true, para no repetir celdas
	var esquina := celda_puerta_xz
	for pos in celdas.keys():
		var punto_xz := Vector2i(pos.x, pos.z)
		esquina.x = min(esquina.x, punto_xz.x)
		esquina.y = min(esquina.y, punto_xz.y)
		if not huella_vista.has(punto_xz):
			huella_vista[punto_xz] = true
			huella.append(punto_xz)

	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino)

	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if not resultado["valido"]:
		return

	Blueprints.guardar(blueprint)
	# Delega en _completar_construccion() (mismo camino que un edificio
	# terminado vía blueprint) para que un edificio declarado a mano quede
	# con el mismo edificio_orden/edificio_progreso — deconstruirlo y
	# volver a completarlo funciona igual que cualquier otro, sin perder
	# sus camas/zona/puesto (ver spec de rediseño, punto 11).
	var metadata := {
		"blueprint": blueprint,
		"huella_xz": huella,
		"esquina": esquina,
		"ancho": blueprint["ancho"],
		"profundidad": blueprint["profundidad"],
	}
	var id_edificio: int = mundo.registrar_edificio_completo(celdas, metadata)
	metadata["id_edificio"] = id_edificio
	_completar_construccion(metadata)
```

- [ ] **Step 2: Verify — headless parse**

Run `godot/scenes/Main.tscn` headless. Confirm no parse errors.

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/Player.gd
git commit -m "refactor: _declarar_edificio() delega en _completar_construccion() para quedar reversible"
```

---

### Task 5: `BlueprintValidatorTest.gd` — rewrite tests for the new mechanism

**Files:**
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: everything produced by Tasks 1-4 (`iniciar_construccion_fantasma()` 5-arg signature, `surtir_construccion()`, `procesar_deconstruccion()`, `edificio_progreso` behavior via `mundo.id_de_edificio()`).
- Produces: nothing (leaf task — updates the test file only).

This task MUST run after Tasks 1-4 are committed, since it exercises their
combined behavior.

- [ ] **Step 1: Update TEST 18's `iniciar_construccion_fantasma()` call**

Find (inside TEST 18):

```gdscript
	mundo.iniciar_construccion_fantasma(orden_18, tipos_18, orden_18)
```

Replace with:

```gdscript
	mundo.iniciar_construccion_fantasma([], {}, orden_18, tipos_18)
```

(No other assertions in TEST 18 change — `surtir_construccion()`'s
observable behavior for a pure-structural fantasma is identical.)

- [ ] **Step 2: Update TEST 20's `iniciar_construccion_fantasma()` call**

Find (inside TEST 20, the "fantasma en curso" sub-case):

```gdscript
	mundo.iniciar_construccion_fantasma(orden_fantasma, tipos_fantasma, orden_fantasma)
```

Replace with:

```gdscript
	mundo.iniciar_construccion_fantasma([], {}, orden_fantasma, tipos_fantasma)
```

- [ ] **Step 3: Rewrite TEST 22 (order + camas + full removal)**

Find the entire TEST 22 block, from
`print("\n=== TEST 22: procesar_deconstruccion()/eliminar_edificio() revierten en orden inverso ===")`
through the line
`print("OK: procesar_deconstruccion() revierte en orden inverso (mobiliario -> estructura -> piso), cuenta camas solo al iniciar, y eliminar_edificio() borra todo.")`.

Replace with:

```gdscript
	print("\n=== TEST 22: procesar_deconstruccion()/eliminar_edificio() revierten en el mismo orden de construcción, mobiliario primero ===")
	const OX10 := 900
	var celda_piso_22 := Vector3i(OX10, 0, OX10)
	var celda_pared_22 := Vector3i(OX10, 1, OX10)
	var celda_cabecera_22 := Vector3i(OX10 + 1, 1, OX10)
	var celda_pies_22 := Vector3i(OX10 + 2, 1, OX10)
	var celda_baul_22 := Vector3i(OX10 + 3, 1, OX10)
	var celdas_mundo_22 := {
		celda_piso_22: "piso",
		celda_pared_22: "pared",
		celda_cabecera_22: "cama_cabecera",
		celda_pies_22: "cama_pies",
		celda_baul_22: "baul",
	}
	var id_22: int = mundo.registrar_edificio_completo(celdas_mundo_22)

	# Primer intento: revierte la ÚLTIMA celda del orden canónico
	# (mobiliario, ordenado por x: cabecera antes que pies antes que
	# baúl) — aunque el jugador haya apuntado a la pared.
	var r1_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(r1_22["id"] == id_22)
	assert(r1_22["total_camas"] == 1, "Debe contar 1 cama_cabecera al cruzar de completo a incompleto")
	assert(mundo.obtener_tipo(celda_baul_22) == "fantasma", "El baúl es el último del orden, se revierte primero")
	assert(mundo.obtener_tipo(celda_pies_22) == "cama_pies", "Todavía no le toca")
	assert(not r1_22["completa_reversion"])

	var r2_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_pies_22) == "fantasma")
	assert(r2_22["total_camas"] == 0, "Solo cuenta en el cruce completo -> incompleto")

	var r3_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_cabecera_22) == "fantasma")

	var r4_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_pared_22) == "fantasma", "Estructura después del mobiliario")
	assert(not r4_22["completa_reversion"])

	var r5_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_piso_22) == "fantasma", "Piso al final")
	assert(r5_22["completa_reversion"] and r5_22["lista_para_remocion"])

	var r6_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(r6_22["lista_para_remocion"])

	var esquina_22: Vector2i = mundo.eliminar_edificio(id_22)
	assert(esquina_22 == Vector2i(OX10, OX10))
	for c_22 in [celda_piso_22, celda_pared_22, celda_cabecera_22, celda_pies_22, celda_baul_22]:
		assert(mundo.obtener_tipo(c_22) == "")
		assert(mundo.id_de_edificio(c_22) == -1)
	print("OK: procesar_deconstruccion() revierte en el mismo orden de construcción recorrido en reversa (mobiliario -> estructura -> piso), cuenta camas solo al cruzar el borde de completo, y eliminar_edificio() borra todo.")
```

- [ ] **Step 4: Rewrite TEST 23 (skip already-fantasma cells)**

Find the entire TEST 23 block, from
`print("\n=== TEST 23: deconstruir un edificio a medio construir salta las celdas ya fantasma ===")`
through
`print("OK: las celdas ya fantasma de un edificio a medio construir no necesitan revertirse.")`.

Replace with:

```gdscript
	print("\n=== TEST 23: deconstruir un edificio a medio construir revierte solo hasta donde llegó el progreso ===")
	const OX11 := 950
	var celda_piso_23 := Vector3i(OX11, 0, OX11)
	var celda_pared_real_23 := Vector3i(OX11, 1, OX11)
	var celda_pared_fantasma_23 := Vector3i(OX11 + 1, 1, OX11)
	var orden_23: Array[Vector3i] = [celda_piso_23, celda_pared_real_23, celda_pared_fantasma_23]
	var tipos_23 := {
		celda_piso_23: "piso",
		celda_pared_real_23: "pared",
		celda_pared_fantasma_23: "pared",
	}
	mundo.iniciar_construccion_fantasma([], {}, orden_23, tipos_23)
	mundo.surtir_construccion(celda_piso_23)  # piso real
	mundo.surtir_construccion(celda_piso_23)  # pared real (2da del orden); la 3ra sigue fantasma
	assert(mundo.obtener_tipo(celda_piso_23) == "piso")
	assert(mundo.obtener_tipo(celda_pared_real_23) == "pared")
	assert(mundo.obtener_tipo(celda_pared_fantasma_23) == "fantasma", "Todavía no se surtió")

	var r1_23: Dictionary = mundo.procesar_deconstruccion(celda_pared_real_23)
	assert(mundo.obtener_tipo(celda_pared_real_23) == "fantasma", "La celda real más reciente (progreso - 1) se revierte")
	assert(mundo.obtener_tipo(celda_pared_fantasma_23) == "fantasma", "Ya lo era, sin cambios")
	assert(not r1_23["completa_reversion"])

	var r2_23: Dictionary = mundo.procesar_deconstruccion(celda_pared_real_23)
	assert(mundo.obtener_tipo(celda_piso_23) == "fantasma")
	assert(r2_23["completa_reversion"] and r2_23["lista_para_remocion"])
	print("OK: deconstruir un edificio a medio construir solo revierte celdas que ya eran reales, hasta llegar a progreso 0.")
```

- [ ] **Step 5: Update TEST 24's `iniciar_construccion_fantasma()` call**

Find (inside TEST 24):

```gdscript
	var orden_24: Array[Vector3i] = [celda_relleno_24, celda_estructural_24]
	var tipos_24 := {celda_relleno_24: "tierra", celda_estructural_24: "pared"}
	mundo.iniciar_construccion_fantasma(orden_24, tipos_24, [celda_estructural_24])
```

Replace with:

```gdscript
	var tipos_24 := {celda_estructural_24: "pared"}
	mundo.iniciar_construccion_fantasma([celda_relleno_24], {celda_relleno_24: "tierra"}, [celda_estructural_24], tipos_24)
```

(Every assertion after this in TEST 24 stays as-is — the relleno cell is
still placed as "fantasma" and stays unregistered/minable, exactly as
before; only the two lines above change since `orden_24` no longer exists
as a combined variable.)

- [ ] **Step 6: Rewrite TEST 25 (partial build + deconstruct, no accidental re-advance)**

Find the entire TEST 25 block, from
`print("\n=== TEST 25: deconstruir un edificio real a medio construir (vía iniciar_construccion_fantasma/surtir_construccion) revierte, no sigue construyendo ===")`
through
`print("OK: deconstruir un edificio a medio construir cancela su cola de construcción y revierte sus celdas reales, sin seguir construyéndolo por accidente.")`.

Replace with:

```gdscript
	print("\n=== TEST 25: pausar una construcción, deconstruir parte, y retomarla — el progreso es el mismo índice en ambos sentidos ===")
	const OX13 := 990
	var celda_piso_25 := Vector3i(OX13, 0, OX13)
	var celda_pared_25 := Vector3i(OX13, 1, OX13)
	var celda_baul_25 := Vector3i(OX13 + 1, 1, OX13)
	var orden_25: Array[Vector3i] = [celda_piso_25, celda_pared_25, celda_baul_25]
	var tipos_25 := {
		celda_piso_25: "piso",
		celda_pared_25: "pared",
		celda_baul_25: "baul",
	}
	mundo.iniciar_construccion_fantasma([], {}, orden_25, tipos_25)
	mundo.surtir_construccion(celda_pared_25)  # convierte la PRIMERA celda pendiente del orden (piso), no la pared -- orden fijo
	assert(mundo.obtener_tipo(celda_piso_25) == "piso", "El piso fue el primero en surtirse (orden fijo, no el que se apunta)")
	assert(mundo.obtener_tipo(celda_pared_25) == "fantasma", "La pared todavía no se ha surtido")
	assert(mundo.obtener_tipo(celda_baul_25) == "fantasma", "El baúl todavía no se ha surtido")

	# Deconstruir apuntando a la pared (todavía fantasma) -- revierte la
	# única celda real (el piso, progreso - 1), sin tocar el baúl (nunca
	# llegó a ser real, no participa).
	var r1_25: Dictionary = mundo.procesar_deconstruccion(celda_pared_25)
	assert(mundo.obtener_tipo(celda_piso_25) == "fantasma", "El piso (única celda real) debe revertirse")
	assert(mundo.obtener_tipo(celda_baul_25) == "fantasma", "El baúl sigue sin construirse")
	assert(r1_25["completa_reversion"] and r1_25["lista_para_remocion"], "Con una sola celda real, la reversión se completa de inmediato")

	# Retomar la construcción desde progreso 0: debe volver a surtir el
	# piso primero, exactamente igual que la primera vez -- MISMO índice,
	# ninguna operación especial de "reanudar".
	mundo.surtir_construccion(celda_pared_25)
	mundo.surtir_construccion(celda_pared_25)
	mundo.surtir_construccion(celda_pared_25)
	assert(mundo.obtener_tipo(celda_piso_25) == "piso")
	assert(mundo.obtener_tipo(celda_pared_25) == "pared")
	assert(mundo.obtener_tipo(celda_baul_25) == "baul")
	print("OK: pausar, deconstruir parcialmente y retomar la construcción usa el mismo índice de progreso en ambos sentidos, sin perder ni duplicar celdas.")
```

- [ ] **Step 7: Leave TEST 26 unchanged**

Confirm TEST 26 (puesto periférico no-op) needs NO changes — it calls
`mundo.registrar_edificio([celda_mina_26])` directly (not
`registrar_edificio_completo()`), so `edificio_orden` never gets an entry
for that id, and `procesar_deconstruccion()`'s
`not edificio_orden.has(id)` check still returns `{}` correctly. Read the
current TEST 26 block to confirm no `Construccion`/old-signature reference
exists in it — if none, skip this step's edit.

- [ ] **Step 8: Add new test case — declared-by-hand building is reversible**

Immediately AFTER TEST 26's closing `print("OK: ...")` line and BEFORE the
final `print("\n=== Las N pruebas de BlueprintValidator pasaron correctamente ===")`,
insert:

```gdscript
	print("\n=== TEST 27: registrar_edificio_completo() deja un edificio declarado a mano tan reversible como uno por blueprint ===")
	const OX15 := 1000
	var celda_piso_27 := Vector3i(OX15, 0, OX15)
	var celda_pared_27 := Vector3i(OX15, 1, OX15)
	var celda_cabecera_27 := Vector3i(OX15 + 1, 1, OX15)
	var celda_pies_27 := Vector3i(OX15 + 2, 1, OX15)
	mundo.colocar_bloque(celda_piso_27, "piso", true)
	mundo.colocar_bloque(celda_pared_27, "pared", true)
	mundo.colocar_bloque(celda_cabecera_27, "cama_cabecera", true)
	mundo.colocar_bloque(celda_pies_27, "cama_pies", true)
	var celdas_mundo_27 := {
		celda_piso_27: "piso",
		celda_pared_27: "pared",
		celda_cabecera_27: "cama_cabecera",
		celda_pies_27: "cama_pies",
	}
	var metadata_27 := {"huella_xz": [Vector2i(OX15, OX15)], "esquina": Vector2i(OX15, OX15), "ancho": 1, "profundidad": 1}
	var id_27: int = mundo.registrar_edificio_completo(celdas_mundo_27, metadata_27)

	# Deconstruye el mobiliario (2 celdas) y confirma que la huella SIGUE
	# registrada (no hay "construcción fantasma" bloqueando) mientras el
	# progreso no llega a 0.
	mundo.procesar_deconstruccion(celda_pared_27)
	var r_parcial_27: Dictionary = mundo.procesar_deconstruccion(celda_pared_27)
	assert(not r_parcial_27["lista_para_remocion"])
	assert(mundo.id_de_edificio(celda_piso_27) != -1, "La huella sigue registrada a medio deconstruir")

	# Retomar y volver a completar: metadata debe seguir intacta (no se
	# perdió al pasar por registrar_edificio_completo() en vez de
	# iniciar_construccion_fantasma()).
	var s1_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	var s2_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	assert(s2_27["completa"])
	assert(s2_27["metadata"] == metadata_27, "La metadata pasada a registrar_edificio_completo() se conserva")
	print("OK: un edificio declarado a mano (registrar_edificio_completo()) es tan reversible como uno por blueprint, sin perder su metadata.")
```

- [ ] **Step 9: Update the final test count and header comment**

Find:

```gdscript
	print("\n=== Las 27 pruebas de BlueprintValidator pasaron correctamente ===")
```

Replace with:

```gdscript
	print("\n=== Las 28 pruebas de BlueprintValidator pasaron correctamente ===")
```

Also update the file's header doc comment (lines ~34-49, describing tests
22-26) to reflect the new mechanism and TEST 27. Find:

```
## que procesar_deconstruccion()/eliminar_edificio()
## revierten un edificio en orden inverso al de construcción, mobiliario
## primero y piso al final (22, ver VoxelWorld.procesar_deconstruccion()),
## que un edificio a medio construir salta las celdas ya fantasma al
## deconstruirse (23), y que iniciar_construccion_fantasma() nunca registra
## el relleno de nivelación como parte del edificio (24, ver
## VoxelWorld.iniciar_construccion_fantasma()), que deconstruir un edificio
## real a medio construir (colocado con iniciar_construccion_fantasma()/
## surtir_construccion(), no un fixture armado a mano) cancela su cola de
## CONSTRUCCIÓN en vez de seguir avanzándola por error (25, ver
## VoxelWorld.procesar_deconstruccion()/Construccion.cancelar()), y que
## procesar_deconstruccion() sobre un puesto periférico (tipo de bloque no
## deconstruible) es un no-op silencioso, nunca un error (26).
## Correr esta escena (Test.tscn) con F6 en el editor de Godot y revisar el
## panel "Output": debe imprimir los 25 tests y no debe lanzar ningún error
## de assert().
```

Replace with:

```
## que procesar_deconstruccion()/eliminar_edificio() revierten un edificio
## recorriendo en reversa el MISMO orden canónico de construcción
## (mobiliario primero, piso al final — un solo índice bidireccional, ver
## docs/superpowers/specs/2026-09-11-construccion-reversible-design.md) (22,
## ver VoxelWorld.procesar_deconstruccion()), que deconstruir un edificio a
## medio construir solo revierte hasta donde llegó el progreso, sin tocar
## celdas que nunca se surtieron (23), y que iniciar_construccion_fantasma()
## nunca registra el relleno de nivelación como parte del edificio (24, ver
## VoxelWorld.iniciar_construccion_fantasma()), que pausar una construcción,
## deconstruir una parte, y retomarla usa el mismo índice de progreso en
## ambos sentidos sin perder ni duplicar celdas (25, ver
## VoxelWorld.surtir_construccion()/procesar_deconstruccion()), que
## procesar_deconstruccion() sobre un puesto periférico (tipo de bloque no
## deconstruible) es un no-op silencioso, nunca un error (26), y que
## registrar_edificio_completo() deja un edificio declarado a mano tan
## reversible como uno por blueprint, sin perder su metadata (27, ver
## Player._declarar_edificio()).
## Correr esta escena (Test.tscn) con F6 en el editor de Godot y revisar el
## panel "Output": debe imprimir los 28 tests y no debe lanzar ningún error
## de assert().
```

- [ ] **Step 10: Run the full test suite**

Run, headless via Godot MCP tools: `godot/scenes/Test.tscn`,
`godot/scenes/BlueprintValidatorTest.tscn`, `godot/scenes/ConstruccionTest.tscn`,
`godot/scenes/ZonificacionTest.tscn`, and `godot/scenes/Main.tscn`. All
assertions must pass; `Main.tscn` must show only the expected pre-existing
warnings.

- [ ] **Step 11: Commit**

```bash
git add godot/scripts/BlueprintValidatorTest.gd
git commit -m "test: reescribir pruebas 18/20/22-26 y agregar TEST 27 para el índice bidireccional"
```

---

## Final Verification (whole branch)

After all 5 tasks are committed:

1. Run every `*Test.tscn` scene in `godot/scenes/` headless — zero
   assertion failures.
2. Run `godot/scenes/Main.tscn` headless — zero parse errors, only the
   expected known warnings.
3. Manually verify (in-editor, by the user) the 5 integration scenarios
   listed in the spec's "Verificación de integración" section:
   direction feels top-down, no ghost-lock after partial deconstruction,
   pause/deconstruct/resume keeps camas balanced, hand-declared buildings
   are reversible, and relleno stays ordinary terrain throughout.
