# Puestos de Recolección (Minas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add mines as a placeable "Recolección" building: real iron veins in the subsoil, a placement mode in the cenital camera with a live area-of-action preview and HUD stat card, driven by resources actually detected in the world.

**Architecture:** A new `FastNoiseLite`-driven ore layer in `GeneradorMundo.gd` (same pattern as its existing height noise). A new pure-state autoload `Recoleccion.gd` (same pattern as `Zonificacion.gd`) holds placed mines and the resource-detection/rate-preview math. `CamaraCenital.gd` gains a third placement mode (same pattern as terrain leveling: a toggle key, a live ghost preview, a confirm click) that reads `Recoleccion` and writes into `VoxelWorld`/`HUD`.

**Tech Stack:** Godot 4.7, GDScript, project at `godot/` (Windows paths — this plan's shell steps use PowerShell/`Bash` tool conventions already used in this repo's sessions; Godot verification always goes through the `mcp__godot__*` MCP tools, never a headless CLI).

**Spec:** `docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md`

## Global Constraints

- Only mines in this pass — no lumberjacks/hunting/gathering posts (they need biomes/vegetation/fauna/water, none of which exist yet).
- Only mine level 1 — no levels 2/3 (waiting on the GDD's "Mejoramiento de edificios" future work).
- No real production tick, no resource inventory, no charging the build cost — placement is free, exactly like terrain leveling.
- Iron veins use real 3D noise (`FastNoiseLite`), never mock/fixed values.
- `PROFUNDIDAD_SUBSUELO` goes from 8 to 24.
- Mine placement only allowed outside the zona de influencia (`not Zonificacion.dentro_de_influencia(celda)`).
- GDScript: tabs for indentation, explicit `var x: Type = ...` instead of `:=` wherever the right-hand side is a dynamically-typed call (recurring bug pattern in this codebase — Godot cannot infer through a duck-typed/`Object`-typed call).
- Every `.gd`/`.tscn` change must be verified by actually running the affected scene(s) via `mcp__godot__run_project` + `mcp__godot__get_debug_output` + `mcp__godot__stop_project` — reading the code is not verification.
- Comments and print/test output stay in Spanish, matching every other file in this codebase.

---

### Task 1: Iron veins in the subsoil + `PROFUNDIDAD_SUBSUELO` bump

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd`
- Modify: `godot/scripts/VoxelWorld.gd:14` (`PROFUNDIDAD_SUBSUELO`), `VoxelWorld.gd:79-86` (`_generar_terreno()`)
- Modify: `godot/scenes/BlockLibrarySource.tscn` (new `"hierro"` block)
- Modify: `godot/scripts/GeneradorMundoTest.gd` (fix Test 4's call signature, add Test 5)
- Test: `godot/scenes/GeneradorMundoTest.tscn` (existing scene, no changes needed — it already just points at the script)

**Interfaces:**
- Produces: `GeneradorMundo.tipo_en_profundidad(x: int, y: int, z: int, profundidad_bajo_superficie: int) -> String` — **signature change** from the current `tipo_en_profundidad(profundidad_bajo_superficie: int) -> String`. Used by Task 2/3's `Recoleccion.gd` indirectly (it reads placed blocks via `VoxelWorld.obtener_tipo()`, not this function directly) and by `VoxelWorld._generar_terreno()` (this task).
- Produces: a `"hierro"` item in `assets/BlockLibrary.res`, usable by `VoxelWorld.colocar_bloque(celda, "hierro")` like any other block type.

- [ ] **Step 1: Read the current files to confirm line numbers before editing**

Read `godot/scripts/GeneradorMundo.gd` and `godot/scripts/VoxelWorld.gd:1-90` — confirm they match what's described below (this codebase has been edited heavily this session; re-read before trusting any line number in this plan).

- [ ] **Step 2: Add the ore-vein noise field to `GeneradorMundo.gd`**

Replace the whole file with:

```gdscript
extends RefCounted

## Generación pura del mapa de alturas del mundo — sin nodos de escena, sin
## GridMap. Ver spec: docs/superpowers/specs/2026-09-07-mundo-procedural-design.md,
## docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md (vetas
## de hierro). Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd:
## evitar el bug de caché de clases globales de Godot) — se usa vía preload().new().

const ALTURA_MINIMA := 0
const ALTURA_MAXIMA := 15
const GROSOR_TIERRA := 4

## Umbral de get_noise_3d() (rango [-1, 1]) por encima del cual una celda de
## piedra se convierte en hierro — ver tipo_en_profundidad(). Calibrado para
## que el hierro sea claramente minoritario frente a la piedra.
const UMBRAL_HIERRO := 0.55

var _ruido: FastNoiseLite
var _ruido_mineral: FastNoiseLite


func _init(semilla: int) -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido.frequency = 0.02

	# Semilla derivada (no la misma que _ruido) para que las vetas de hierro
	# no queden correlacionadas con el relieve de superficie — sigue siendo
	# determinista: misma semilla de entrada, mismas vetas siempre.
	_ruido_mineral = FastNoiseLite.new()
	_ruido_mineral.seed = semilla + 1
	_ruido_mineral.noise_type = FastNoiseLite.TYPE_PERLIN
	# Frecuencia baja a propósito (más baja que _ruido) para producir vetas/
	# grumos grandes y deformes en vez de ruido puntual disperso celda a celda.
	_ruido_mineral.frequency = 0.05


## Altura de la superficie en (x, z), determinista para (semilla, x, z).
## get_noise_2d() devuelve un valor en [-1, 1]; se remapea linealmente a
## [ALTURA_MINIMA, ALTURA_MAXIMA] y se redondea a entero.
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var t: float = (valor + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)


## Tipo de bloque de subsuelo en la columna/profundidad dados: "tierra" cerca
## de la superficie (por debajo de GROSOR_TIERRA), "piedra" más profundo, o
## "hierro" si el ruido de vetas supera UMBRAL_HIERRO en esa celda exacta —
## el hierro NUNCA aparece en la capa de tierra, sin importar el ruido (el
## chequeo de profundidad corta antes de consultar _ruido_mineral). (x, y, z)
## son coordenadas absolutas del mundo (y = altura de superficie -
## profundidad_bajo_superficie) — necesarias para el ruido 3D, a diferencia
## de la versión anterior de esta función que solo dependía de la profundidad
## relativa.
func tipo_en_profundidad(x: int, y: int, z: int, profundidad_bajo_superficie: int) -> String:
	if profundidad_bajo_superficie < GROSOR_TIERRA:
		return "tierra"
	if _ruido_mineral.get_noise_3d(x, y, z) > UMBRAL_HIERRO:
		return "hierro"
	return "piedra"
```

- [ ] **Step 3: Update the single call site in `VoxelWorld.gd`**

In `godot/scripts/VoxelWorld.gd`, change:

```gdscript
const PROFUNDIDAD_SUBSUELO := 8
```

to:

```gdscript
const PROFUNDIDAD_SUBSUELO := 24
```

And change `_generar_terreno()` from:

```gdscript
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var tipo: String = generador.tipo_en_profundidad(profundidad)
				colocar_bloque(Vector3i(x, altura - profundidad, z), tipo)
```

to:

```gdscript
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var y: int = altura - profundidad
				var tipo: String = generador.tipo_en_profundidad(x, y, z, profundidad)
				colocar_bloque(Vector3i(x, y, z), tipo)
```

- [ ] **Step 4: Add the `"hierro"` block to `BlockLibrarySource.tscn`**

Open `godot/scenes/BlockLibrarySource.tscn`. Find the `"piedra"` block's sub-resources and node (the last block in the file). Immediately after the `Shape_piedra` sub-resource block, add:

```
[sub_resource type="StandardMaterial3D" id="Mat_hierro"]
albedo_color = Color(0.72, 0.42, 0.2, 1)

[sub_resource type="BoxMesh" id="Mesh_hierro"]
material = SubResource("Mat_hierro")

[sub_resource type="BoxShape3D" id="Shape_hierro"]
```

And immediately after the `piedra` node's `CollisionShape3D` child (at the end of the file), add:

```
[node name="hierro" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_hierro")

[node name="CollisionShape3D" type="CollisionShape3D" parent="hierro"]
shape = SubResource("Shape_hierro")
```

Also bump the `load_steps` count in the `[gd_scene ...]` header line at the top of the file by 3 (one new sub-resource type × 3 sub-resources = +3; there is no `load_steps` contribution from nodes, only sub-resources) — read the current value first and add 3 to it.

- [ ] **Step 5: Regenerate `assets/BlockLibrary.res`**

```
mcp__godot__export_mesh_library({
  projectPath: "C:\\Users\\peraz\\Projects\\Misc\\CityCraft\\godot",
  scenePath: "scenes/BlockLibrarySource.tscn",
  outputPath: "assets/BlockLibrary.res"
})
```

- [ ] **Step 6: Fix Test 4's call signature and add Test 5 in `GeneradorMundoTest.gd`**

Replace Test 4 (currently calling `tipo_en_profundidad(p)` with one argument, which will now fail to compile) with:

```gdscript
	print("\n=== TEST 4: tipo_en_profundidad() por capas (tierra/piedra) ===")
	var gen_capas: RefCounted = GeneradorMundoScript.new(1)
	for p in range(GeneradorMundoScript.GROSOR_TIERRA):
		assert(gen_capas.tipo_en_profundidad(0, 10 - p, 0, p) == "tierra")
	var tipo_profundo: String = gen_capas.tipo_en_profundidad(0, 10 - GeneradorMundoScript.GROSOR_TIERRA, 0, GeneradorMundoScript.GROSOR_TIERRA)
	assert(tipo_profundo == "piedra" or tipo_profundo == "hierro")
	print("OK: tierra hasta GROSOR_TIERRA; piedra o hierro en adelante (nunca tierra).")

	print("\n=== TEST 5: Las vetas de hierro nunca aparecen en la capa de tierra, y sí varían la piedra ===")
	var gen_vetas: RefCounted = GeneradorMundoScript.new(42)
	var vio_tierra := false
	var vio_piedra := false
	var vio_hierro := false
	for x in range(0, 60, 2):
		for z in range(0, 60, 2):
			for p in range(0, 20):
				var tipo: String = gen_vetas.tipo_en_profundidad(x, 100 - p, z, p)
				if p < GeneradorMundoScript.GROSOR_TIERRA:
					assert(tipo == "tierra")
					vio_tierra = true
				elif tipo == "piedra":
					vio_piedra = true
				elif tipo == "hierro":
					vio_hierro = true
	assert(vio_tierra)
	assert(vio_piedra)
	assert(vio_hierro)
	print("OK: capa de tierra siempre 'tierra'; capa profunda produjo tanto 'piedra' como 'hierro' en el muestreo.")

	print("\n=== Las 5 pruebas de GeneradorMundo pasaron correctamente ===")
```

(This replaces the old Test 4 body AND the final `print("\n=== Las 4 pruebas...")` line — the new Test 5 block above already includes the correct final print, delete the old one.)

- [ ] **Step 7: Run `GeneradorMundoTest.tscn` and verify all 5 tests pass**

```
mcp__godot__run_project({ projectPath: "C:\\Users\\peraz\\Projects\\Misc\\CityCraft\\godot", scene: "res://scenes/GeneradorMundoTest.tscn" })
mcp__godot__get_debug_output({})
mcp__godot__stop_project({})
```

Expected: output ends with "Las 5 pruebas de GeneradorMundo pasaron correctamente", no `assert()` failures, no new errors. If Test 5 fails to observe both `"piedra"` and `"hierro"` in the sample, `UMBRAL_HIERRO` is miscalibrated (too high = no hierro ever; too low = no piedra ever) — adjust `UMBRAL_HIERRO` in `GeneradorMundo.gd` (try `0.4` or `0.65`) and re-run before moving on; do not weaken the test to work around it.

- [ ] **Step 8: Run `Main.tscn` and confirm it still loads, and record the load time**

```
mcp__godot__run_project({ projectPath: "C:\\Users\\peraz\\Projects\\Misc\\CityCraft\\godot", scene: "res://scenes/Main.tscn" })
mcp__godot__get_debug_output({})
mcp__godot__stop_project({})
```

Expected: no new errors (the two pre-existing `class_name` shadow warnings for `BlueprintValidator`/`Player` are fine, unrelated). `PROFUNDIDAD_SUBSUELO` tripling (8→24) will increase generation/load time — note the approximate wall-clock time this took in your task report. Do not block on this number; just record it (PoC_5's doc already tracks load-time history for this exact tradeoff — see `PoC_5/Documento Técnico de Desarrollo_...md` section 3.1).

- [ ] **Step 9: Run the other existing test scenes to check for regressions**

```
mcp__godot__run_project({ projectPath: "...", scene: "res://scenes/Test.tscn" })
mcp__godot__get_debug_output({})
mcp__godot__stop_project({})
```
Expected: "Las 14 pruebas de BlueprintValidator pasaron correctamente", same as before this task (this task doesn't touch `BlueprintValidator`/`VoxelWorld.detectar_estructura`, this is a pure regression check).

- [ ] **Step 10: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/VoxelWorld.gd godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: generate iron veins in the subsoil with 3D noise

PROFUNDIDAD_SUBSUELO goes from 8 to 24 to give the veins room to vary
in depth. tipo_en_profundidad() gains x/y/z parameters to sample the
new ore-vein noise field; iron never appears above GROSOR_TIERRA.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HPFtVtJrZaGuihfR5DVmS6"
```

---

### Task 2: `Recoleccion.gd` autoload — placement data and resource detection

**Files:**
- Create: `godot/scripts/Recoleccion.gd`
- Create: `godot/scripts/RecoleccionTest.gd`
- Create: `godot/scenes/RecoleccionTest.tscn`
- Modify: `godot/project.godot` (register the autoload)

**Interfaces:**
- Consumes: `VoxelWorld.obtener_tipo(celda: Vector3i) -> String` (existing, from Task 1's world — unchanged by Task 1).
- Produces: autoload `Recoleccion` with `RADIO_AREA_MINA: int`, `PROFUNDIDAD_MINA_NIVEL_1: int`, `TASA_BASE_POR_CIUDADANO: float`, `COSTO_CONSTRUCCION: Dictionary`, `PERSONAL_MAXIMO: int`, `CAPACIDAD_ALMACENAMIENTO: int`, `puestos: Dictionary`, `colocar_mina(celda: Vector2i) -> void`, `detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Dictionary`, `tasas_recoleccion(conteo: Dictionary) -> Dictionary`. Task 3 (`CamaraCenital.gd`, `HUD.gd`) calls all of these by exact name.

- [ ] **Step 1: Write `Recoleccion.gd`**

```gdscript
extends Node

## Autoload "Recoleccion": estado puro de los puestos de recolección
## colocados (solo minas por ahora, ver spec:
## docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md).
## Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd: evitar el bug
## de caché de clases globales de Godot).

const RADIO_AREA_MINA := 6
const PROFUNDIDAD_MINA_NIVEL_1 := 8
const TASA_BASE_POR_CIUDADANO := 2.0

## Ejemplo "mina manual, Tipo 1" del GDD (Sección 3) — puramente
## informativo por ahora: colocar una mina no cobra nada todavía (mismo
## alcance reducido que la nivelación de terreno, el juego no tiene
## inventario de recursos real).
const COSTO_CONSTRUCCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO := 3
const CAPACIDAD_ALMACENAMIENTO := 100

var puestos: Dictionary = {}  # Vector2i (celda de superficie) -> {"nivel": int}


func colocar_mina(celda: Vector2i) -> void:
	puestos[celda] = {"nivel": 1}


## Cuenta los tipos de bloque REALES dentro de la semiesfera de acción
## (radio horizontal RADIO_AREA_MINA, hacia abajo PROFUNDIDAD_MINA_NIVEL_1)
## centrada en (centro_xz, altura_superficie). "mundo" se le pasa por duck
## typing (necesita solo .obtener_tipo(Vector3i) -> String) — mismo patrón
## que NiveladorTerreno con .altura_en(), para poder probar esta función
## con un VoxelWorld real sin depender de generación de ruido.
func detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Dictionary:
	var conteo: Dictionary = {}  # String (tipo) -> int
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			for dy in range(0, PROFUNDIDAD_MINA_NIVEL_1 + 1):
				var offset := Vector3(dx, -dy, dz)
				if offset.length() > RADIO_AREA_MINA:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				var tipo: String = mundo.obtener_tipo(celda)
				if tipo != "":
					conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo


## Tasa de recolección prevista por ciudadano y tipo de recurso, a partir
## del conteo de detectar_recursos() — proporción de cada tipo dentro del
## área multiplicada por TASA_BASE_POR_CIUDADANO. {} si el área no detectó
## nada (evita dividir por cero).
func tasas_recoleccion(conteo: Dictionary) -> Dictionary:
	var total := 0
	for tipo in conteo:
		total += conteo[tipo]
	if total == 0:
		return {}
	var tasas: Dictionary = {}
	for tipo in conteo:
		tasas[tipo] = (float(conteo[tipo]) / float(total)) * TASA_BASE_POR_CIUDADANO
	return tasas
```

- [ ] **Step 2: Register the autoload in `project.godot`**

In `godot/project.godot`, find:

```
[autoload]

Ciudad="*res://scripts/Ciudad.gd"
Zonificacion="*res://scripts/Zonificacion.gd"
```

Change to:

```
[autoload]

Ciudad="*res://scripts/Ciudad.gd"
Zonificacion="*res://scripts/Zonificacion.gd"
Recoleccion="*res://scripts/Recoleccion.gd"
```

- [ ] **Step 3: Write `RecoleccionTest.gd`**

```gdscript
extends Node

## Pruebas aisladas de Recoleccion.gd (mismo patrón que
## NiveladorTerrenoTest.gd/BlueprintValidatorTest.gd). Corre esta escena
## (RecoleccionTest.tscn) con F6 en el editor de Godot y revisa el panel
## "Output": debe imprimir las pruebas y no debe lanzar ningún error de
## assert().

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: detectar_recursos() cuenta tipos reales dentro del radio ===")
	# VoxelWorld.new() sin _ready() (evita la generación automática del mundo
	# de 200x200) — mismo patrón que BlueprintValidatorTest.gd.
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()

	# Superficie plana en y=10 rellena de "piedra" en un radio generoso, con
	# 2 celdas de "hierro" colocadas a mano dentro del radio de acción — el
	# resto queda como aire (no cuenta, "" en obtener_tipo()).
	var centro := Vector2i(0, 0)
	var altura_superficie := 10
	for dx in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx, dz).length() > Recoleccion.RADIO_AREA_MINA:
				continue
			mundo.colocar_bloque(Vector3i(dx, altura_superficie - 1, dz), "piedra")
	mundo.minar_bloque(Vector3i(0, altura_superficie - 1, 0))
	mundo.colocar_bloque(Vector3i(0, altura_superficie - 1, 0), "hierro")
	mundo.minar_bloque(Vector3i(1, altura_superficie - 1, 0))
	mundo.colocar_bloque(Vector3i(1, altura_superficie - 1, 0), "hierro")

	var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
	print("Conteo detectado: ", conteo)
	assert(conteo.get("hierro", 0) == 2)
	assert(conteo.get("piedra", 0) > 0)
	assert(not conteo.has(""))

	print("\n=== TEST 2: tasas_recoleccion() reparte proporcionalmente ===")
	var conteo_simple := {"piedra": 3, "hierro": 1}
	var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo_simple)
	print("Tasas: ", tasas)
	assert(is_equal_approx(tasas["piedra"], 1.5))  # 3/4 * 2.0
	assert(is_equal_approx(tasas["hierro"], 0.5))  # 1/4 * 2.0

	print("\n=== TEST 3: tasas_recoleccion() con conteo vacío no divide por cero ===")
	var tasas_vacias: Dictionary = Recoleccion.tasas_recoleccion({})
	assert(tasas_vacias.is_empty())

	print("\n=== TEST 4: colocar_mina() registra el puesto ===")
	Recoleccion.puestos.clear()  # aislar de otras pruebas que compartan el autoload
	Recoleccion.colocar_mina(Vector2i(5, 5))
	assert(Recoleccion.puestos.has(Vector2i(5, 5)))
	assert(Recoleccion.puestos[Vector2i(5, 5)]["nivel"] == 1)

	print("\n=== Las 4 pruebas de Recoleccion pasaron correctamente ===")
```

- [ ] **Step 4: Create `RecoleccionTest.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/RecoleccionTest.gd" id="1"]

[node name="RecoleccionTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 5: Run `RecoleccionTest.tscn` and verify all 4 tests pass**

```
mcp__godot__run_project({ projectPath: "C:\\Users\\peraz\\Projects\\Misc\\CityCraft\\godot", scene: "res://scenes/RecoleccionTest.tscn" })
mcp__godot__get_debug_output({})
mcp__godot__stop_project({})
```

Expected: "Las 4 pruebas de Recoleccion pasaron correctamente", no assert failures. If `conteo.get("piedra", 0)` is 0 in Test 1, the radius/offset math has a bug — the hemisphere should contain many more piedra cells than the 2 hand-placed hierro cells.

- [ ] **Step 6: Regression check — run `Main.tscn`**

```
mcp__godot__run_project({ projectPath: "...", scene: "res://scenes/Main.tscn" })
mcp__godot__get_debug_output({})
mcp__godot__stop_project({})
```
Expected: no new errors (the autoload load order matters — `Recoleccion` has no dependency on `Ciudad`/`Zonificacion` so order in `project.godot` doesn't matter here, but confirm no autoload-related error appears).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd godot/scenes/RecoleccionTest.tscn godot/project.godot
git commit -m "feat: add Recoleccion autoload for mine placement and resource detection

Pure-state autoload (same pattern as Zonificacion.gd): tracks placed
mines and computes real resource counts/rates within a mine's
hemispherical area of action by reading actual VoxelWorld blocks.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HPFtVtJrZaGuihfR5DVmS6"
```

---

### Task 3: Mine placement mode (cenital camera) + HUD stat card

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn` (new `"mina"` marker block)
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scenes/Main.tscn` (new HUD nodes for the mine stat card)

**Interfaces:**
- Consumes: `Recoleccion.RADIO_AREA_MINA`, `Recoleccion.detectar_recursos()`, `Recoleccion.tasas_recoleccion()`, `Recoleccion.colocar_mina()`, `Recoleccion.COSTO_CONSTRUCCION`, `Recoleccion.PERSONAL_MAXIMO`, `Recoleccion.CAPACIDAD_ALMACENAMIENTO` (Task 2). `Zonificacion.dentro_de_influencia(celda: Vector2i) -> bool` (existing). `VoxelWorld.altura_en()`, `VoxelWorld.colocar_bloque()` (existing). `CamaraCenital._celda_bajo_mouse()`, `CamaraCenital.DESF`, `CamaraCenital.ALTURA_SOBRE_SUPERFICIE` (existing, this same file).
- Produces: `HUD.mostrar_ficha_mina() -> void`, `HUD.actualizar_tasas_mina(tasas: Dictionary) -> void`, `HUD.ocultar_ficha_mina() -> void` — no other file calls these except `CamaraCenital.gd` (this task).

- [ ] **Step 1: Re-read `CamaraCenital.gd` and `HUD.gd` in full before editing**

Both files have been edited heavily this session — confirm current line numbers/content match this plan's expectations before making any edit below.

- [ ] **Step 2: Add the `"mina"` marker block to `BlockLibrarySource.tscn`**

Same procedure as Task 1 Step 4, appended after the `"hierro"` block this time. Sub-resources:

```
[sub_resource type="StandardMaterial3D" id="Mat_mina"]
albedo_color = Color(1.0, 0.85, 0.0, 1)

[sub_resource type="BoxMesh" id="Mesh_mina"]
material = SubResource("Mat_mina")

[sub_resource type="BoxShape3D" id="Shape_mina"]
```

Node (at the end of the file):

```
[node name="mina" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_mina")

[node name="CollisionShape3D" type="CollisionShape3D" parent="mina"]
shape = SubResource("Shape_mina")
```

Bump `load_steps` in the header by 3 again (read the current value first, it was already bumped once in Task 1).

Regenerate the mesh library:
```
mcp__godot__export_mesh_library({
  projectPath: "C:\\Users\\peraz\\Projects\\Misc\\CityCraft\\godot",
  scenePath: "scenes/BlockLibrarySource.tscn",
  outputPath: "assets/BlockLibrary.res"
})
```

- [ ] **Step 3: Add the mine placement mode to `CamaraCenital.gd`**

Add these constants near `COLOR_HUELLA_VALIDA`/`COLOR_HUELLA_INVALIDA` (same block):

```gdscript
const COLOR_MINA_VALIDA := Color(1.0, 0.85, 0.0, 0.4)
const COLOR_MINA_INVALIDA := Color(1.0, 0.2, 0.2, 0.4)
```

Add these vars near `var modo_nivelacion := false` / `var _huella_fantasma: Array[MeshInstance3D] = []`:

```gdscript
## Modo de colocación de mina (tecla `M`): un disco fantasma (radio
## Recoleccion.RADIO_AREA_MINA, precalculado en offsets circulares) sigue la
## celda bajo el cursor, verde si es válida (fuera de la zona de influencia)
## o rojo si no. Mientras el modo está activo, la ficha del HUD se actualiza
## cada fotograma con los recursos reales detectados en esa posición.
var modo_colocar_mina := false
var _disco_mina: Array[MeshInstance3D] = []
var _offsets_disco_mina: Array[Vector2i] = []
```

Add `@onready var hud: CanvasLayer = get_node("../HUDLayer")` next to the existing `@onready var mundo`/`@onready var overlay` lines.

In `_ready()`, add a call to a new `_crear_disco_mina()` right after the existing `_crear_huella_fantasma()` call.

Add this new function right after `_crear_huella_fantasma()`:

```gdscript
## Precalcula los offsets (dx, dz) dentro del círculo de radio
## Recoleccion.RADIO_AREA_MINA (mismo criterio de distancia que
## Recoleccion.detectar_recursos(), en el plano horizontal) y crea un plano
## fantasma por offset — mismo patrón de pool reutilizable que
## _crear_huella_fantasma(), para no generar basura de nodos cada fotograma.
func _crear_disco_mina() -> void:
	for dx in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx, dz).length() <= Recoleccion.RADIO_AREA_MINA:
				_offsets_disco_mina.append(Vector2i(dx, dz))

	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	for i in range(_offsets_disco_mina.size()):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_MINA_VALIDA
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = false
		add_child(plano)
		_disco_mina.append(plano)
```

In `_process()`, the current early-return branch reads:

```gdscript
	if paneo == Vector2.ZERO and not orbita_o_inclina and vuelo == 0.0:
		if modo_nivelacion:
			_actualizar_huella_fantasma()
		elif esperando_segunda_esquina:
			_actualizar_previsualizacion_zona()
		return
```

Change to:

```gdscript
	if paneo == Vector2.ZERO and not orbita_o_inclina and vuelo == 0.0:
		if modo_nivelacion:
			_actualizar_huella_fantasma()
		elif modo_colocar_mina:
			_actualizar_previsualizacion_mina()
		elif esperando_segunda_esquina:
			_actualizar_previsualizacion_zona()
		return
```

And the tail of `_process()` (after the collision commit/revert block) reads:

```gdscript
	if modo_nivelacion:
		_actualizar_huella_fantasma()
	elif esperando_segunda_esquina:
		_actualizar_previsualizacion_zona()
```

Change to:

```gdscript
	if modo_nivelacion:
		_actualizar_huella_fantasma()
	elif modo_colocar_mina:
		_actualizar_previsualizacion_mina()
	elif esperando_segunda_esquina:
		_actualizar_previsualizacion_zona()
```

Add this new function right after `_actualizar_huella_fantasma()`:

```gdscript
## Recalcula la posición/color del disco de área de acción según la celda
## bajo el cursor (verde fuera de la zona de influencia = válida, rojo
## dentro = inválida) y la ficha de recolección prevista en el HUD, a partir
## de los recursos reales detectados por Recoleccion.detectar_recursos().
func _actualizar_previsualizacion_mina() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var valida: bool = not Zonificacion.dentro_de_influencia(centro)
	var color: Color = COLOR_MINA_VALIDA if valida else COLOR_MINA_INVALIDA

	for i in range(_offsets_disco_mina.size()):
		var offset: Vector2i = _offsets_disco_mina[i]
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		var altura_celda: int = mundo.altura_en(x, z)
		var plano: MeshInstance3D = _disco_mina[i]
		var material: StandardMaterial3D = plano.material_override
		material.albedo_color = color
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE, z + DESF)

	var altura_superficie: int = mundo.altura_en(centro.x, centro.y)
	var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
	var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo)
	hud.actualizar_tasas_mina(tasas)
```

In `_unhandled_input()`, the key-handling `if event is InputEventKey:` block currently ends with the `KEY_B` branch:

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_nivelacion()
```

Add right after it (still inside the same `if event is InputEventKey:` block):

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_M:
			_alternar_modo_colocar_mina()
```

The mouse-button branch currently reads:

```gdscript
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_nivelacion:
				_procesar_clic_nivelacion(boton.position)
			else:
				_procesar_clic(boton.position)
```

Change to:

```gdscript
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_nivelacion:
				_procesar_clic_nivelacion(boton.position)
			elif modo_colocar_mina:
				_procesar_clic_mina(boton.position)
			else:
				_procesar_clic(boton.position)
```

Add these new functions right after `_mostrar_huella_fantasma()`:

```gdscript
func _alternar_modo_colocar_mina() -> void:
	modo_colocar_mina = not modo_colocar_mina
	_mostrar_disco_mina(modo_colocar_mina)
	if modo_colocar_mina:
		hud.mostrar_ficha_mina()
		print("Modo colocar mina activo: haz clic fuera de la zona de influencia para confirmar (M de nuevo para cancelar).")
	else:
		hud.ocultar_ficha_mina()
		print("Modo colocar mina cancelado.")


func _mostrar_disco_mina(visible_ahora: bool) -> void:
	for plano in _disco_mina:
		plano.visible = visible_ahora
```

Add this new function right after `_procesar_clic()`:

```gdscript
## Confirma la colocación de la mina en la celda bajo el cursor si está
## fuera de la zona de influencia — si no, imprime el rechazo y SIGUE en
## modo colocar-mina (a diferencia de la nivelación, que siempre sale del
## modo tras un clic; aquí el jugador puede reintentar de inmediato). El
## bloque marcador se coloca UNA celda por encima de la superficie
## (altura_superficie + 1): la celda de superficie ya está ocupada por el
## bloque "piso" del terreno, así que colocar el marcador ahí mismo siempre
## fallaría (VoxelWorld.colocar_bloque() rechaza celdas ya ocupadas).
func _procesar_clic_mina(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if Zonificacion.dentro_de_influencia(celda):
		print("No se puede colocar una mina dentro de la zona de influencia.")
		return

	var altura_superficie: int = mundo.altura_en(celda.x, celda.y)
	mundo.colocar_bloque(Vector3i(celda.x, altura_superficie + 1, celda.y), "mina")
	Recoleccion.colocar_mina(celda)
	print("Mina colocada en (", celda.x, ", ", celda.y, ").")

	modo_colocar_mina = false
	_mostrar_disco_mina(false)
	hud.ocultar_ficha_mina()
```

- [ ] **Step 4: Update the header doc comment in `CamaraCenital.gd`**

The file's top comment block lists controls (paneo/órbita/inclinación/altura/zoom/nivelación). Add one more bullet before the final "Modo de nivelación..." line:

```gdscript
## - Colocación de minas (tecla `M`, ver GDD Sección 3 y
##   docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md):
##   disco de previsualización del área de acción, ficha en vivo en el HUD,
##   confirma solo fuera de la zona de influencia.
```

- [ ] **Step 5: Add the mine stat card to `HUD.gd`**

Add these `@onready` vars right after the existing ones (`critico_tasa_label`):

```gdscript
@onready var mina_ficha: VBoxContainer = $MinaFicha
@onready var mina_costo_label: Label = $MinaFicha/CostoLabel
@onready var mina_personal_label: Label = $MinaFicha/PersonalLabel
@onready var mina_almacenamiento_label: Label = $MinaFicha/AlmacenamientoLabel
@onready var mina_tasas_label: Label = $MinaFicha/TasasLabel
```

Add these functions at the end of the file (after `_actualizar_recurso()`):

```gdscript
## Muestra la ficha de la mina con sus valores FIJOS (costo, personal,
## almacenamiento — no cambian según la posición del cursor, a diferencia
## de las tasas de recolección, que sí — ver actualizar_tasas_mina()).
func mostrar_ficha_mina() -> void:
	var partes_costo: Array = []
	for tipo in Recoleccion.COSTO_CONSTRUCCION:
		partes_costo.append("%d %s" % [Recoleccion.COSTO_CONSTRUCCION[tipo], tipo])
	mina_costo_label.text = "Costo: %s" % ", ".join(partes_costo)
	mina_personal_label.text = "Personal máximo: %d" % Recoleccion.PERSONAL_MAXIMO
	mina_almacenamiento_label.text = "Almacenamiento: %d" % Recoleccion.CAPACIDAD_ALMACENAMIENTO
	mina_tasas_label.text = "Recolección prevista: -"
	mina_ficha.visible = true


## Recalculada en vivo cada fotograma mientras el modo colocar-mina está
## activo, a partir de Recoleccion.tasas_recoleccion().
func actualizar_tasas_mina(tasas: Dictionary) -> void:
	if tasas.is_empty():
		mina_tasas_label.text = "Recolección prevista: sin recursos detectados"
		return
	var lineas: Array = []
	for tipo in tasas:
		lineas.append("%.1f %s/h" % [tasas[tipo], tipo])
	mina_tasas_label.text = "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)


func ocultar_ficha_mina() -> void:
	mina_ficha.visible = false
```

- [ ] **Step 6: Add the `MinaFicha` nodes to `Main.tscn`**

Open `godot/scenes/Main.tscn`. Find the `[node name="HUD" type="VBoxContainer" parent="HUDLayer" ...]` block and all its child `Label` nodes — the `MinaFicha` container is a **sibling of `HUD`**, not a child (so it doesn't interleave with the demographic labels), placed lower on screen. After the last existing node in the file (`CriticoTasaLabel`), add:

```
[node name="MinaFicha" type="VBoxContainer" parent="HUDLayer"]
visible = false
offset_left = 12.0
offset_top = 160.0
offset_right = 320.0
offset_bottom = 280.0

[node name="CostoLabel" type="Label" parent="HUDLayer/MinaFicha"]
layout_mode = 2

[node name="PersonalLabel" type="Label" parent="HUDLayer/MinaFicha"]
layout_mode = 2

[node name="AlmacenamientoLabel" type="Label" parent="HUDLayer/MinaFicha"]
layout_mode = 2

[node name="TasasLabel" type="Label" parent="HUDLayer/MinaFicha"]
layout_mode = 2
autowrap_mode = 2
```

- [ ] **Step 7: Run `Main.tscn` and verify it loads with no new errors**

```
mcp__godot__run_project({ projectPath: "C:\\Users\\peraz\\Projects\\Misc\\CityCraft\\godot", scene: "res://scenes/Main.tscn" })
mcp__godot__get_debug_output({})
mcp__godot__stop_project({})
```

Expected: same two pre-existing benign warnings as always (`class_name` shadowing for `BlueprintValidator`/`Player`), nothing new — in particular no `Node not found: "MinaFicha"` or similar `@onready` resolution error, which would mean Step 6's node path doesn't match Step 5's `$MinaFicha` lookups exactly.

- [ ] **Step 8: Regression check — run `Test.tscn`, `CiudadTest.tscn`, `ZonificacionTest.tscn`, `NiveladorTerrenoTest.tscn`, `RecoleccionTest.tscn`**

Run each the same way (`run_project` → `get_debug_output` → `stop_project`), confirm each still prints its full "pasaron correctamente" line with no new errors. None of this task's changes touch the systems these test, so this is a pure regression check.

- [ ] **Step 9: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scripts/CamaraCenital.gd godot/scripts/HUD.gd godot/scenes/Main.tscn
git commit -m "feat: mine placement mode in the cenital camera with a live HUD preview

Tecla M toggles a placement mode: a disc-shaped ghost preview (radius
Recoleccion.RADIO_AREA_MINA) follows the cursor, colored by whether
the cell is outside the zona de influencia, while the HUD shows a
live-updating resource-yield card computed from real detected blocks.
Confirming places a 'mina' marker block and registers the mine in
Recoleccion.puestos.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HPFtVtJrZaGuihfR5DVmS6"
```

---

### Task 4: Manual verification + documentation

**Files:**
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (version bump only — no functional/design change from what's already written there)

**Interfaces:** None — this task only touches docs, after Tasks 1-3 are complete and verified.

- [ ] **Step 1: Manual play-test in the editor**

Run `Main.tscn` interactively (not headless): declare a residential building to bootstrap the zona de influencia (existing flow, tecla `B` residencial or however the current save state does it), switch to cenital camera (`C`), press `M`, move the cursor around — confirm the disc preview follows the terrain, turns red inside the zona de influencia and gold outside it, and the HUD card's "Recolección prevista" line changes as you move over different subsoil composition. Click outside the zona de influencia to confirm placement — confirm the gold marker block appears one cell above the surface and the HUD card hides. Press `M` again over different terrain to place a second mine and confirm the first one's marker persists.

This step needs a human at the keyboard/screen (or a `claude-in-chrome`-style interactive session) — the previous three tasks' `mcp__godot__run_project`/`get_debug_output` calls only catch script errors, not visual/UX correctness. Record what you observed (or ask the user to do this pass and report back) before writing the "Verificado" language in Step 2 — do not claim visual behavior is correct without having actually seen it.

- [ ] **Step 2: Update `PoC_5/Documento Técnico de Desarrollo_...md`**

Mark sub-project 3 ("Puestos de Recolección + previsualización en HUD") as complete with reduced scope (mines only, no lumberjacks/hunting/gathering — those wait on sub-project 4/biomes), in the same style as sub-projects 1 and 2's "Verificado" write-ups elsewhere in that file (see Sección 3.1-3.7 for the established pattern: what was built, what bugs were found and fixed during verification, what's explicitly out of scope). Update the roadmap-status line near the top of the file (currently says "2 primeros sub-proyectos de 4") to "3 primeros sub-proyectos de 4". Update the "Próximos Pasos" list entry for sub-project 3 from its current "pending" wording to completed, matching how sub-projects 1/2 are marked there (`~~...~~ **Completado...**`).

- [ ] **Step 3: Bump the GDD version**

In `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`, update the `**Versión del Documento:**` line (single line, replace the previous version entirely — this repo does not keep a version changelog chain in this field, confirmed convention from prior sessions) to record: mines implemented as the first "Recolección" building (GDD Sección 3/3.1), with real iron veins in the subsoil, area-of-action preview and HUD stat card in the cenital camera; lumberjack/hunting/gathering posts remain pending on biomes/vegetation/fauna (sub-project 4). Reference `PoC_5/`, the relevant section from Step 2.

- [ ] **Step 4: Commit**

```bash
git add "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md" "Documento de Diseño de Juego (GDD)_ Craft to Nation.md"
git commit -m "docs: document mines (PoC 5, sub-project 3) as complete

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HPFtVtJrZaGuihfR5DVmS6"
```
