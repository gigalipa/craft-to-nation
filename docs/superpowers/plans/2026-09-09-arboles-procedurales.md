# Árboles Procedurales Talables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generar árboles procedurales (tronco + follaje, tamaño variable) en las columnas de bioma del mundo, que se comportan como un solo objeto con salud propia — talar reduce la salud, y el árbol completo desaparece de golpe al agotarse.

**Architecture:** Nueva clase pura `GeneradorArbol.gd` (mismo patrón que `GeneradorMundo.gd`/`NiveladorTerreno.gd`, sin nodos de escena) genera la forma procedural determinista de un árbol y mantiene el registro de árboles vivos (id, celdas, salud). `GeneradorMundo.gd` gana una cuarta señal de densidad (`densidad_arbol_en`, mismo patrón que fauna/frutal). `VoxelWorld.gd` coloca los árboles reales durante la generación del mundo (nueva pasada `_generar_arboles()`) y expone `talar_bloque_de_arbol()` para aplicar daño.

**Tech Stack:** Godot 4.7, GDScript, `RandomNumberGenerator` nativo.

**Spec:** `docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md`

## Global Constraints

- Usa tabulaciones en GDScript (exigido por Godot).
- Conserva el español en comentarios, nombres de prueba y documentación.
- No edites `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- No agregues dependencias nuevas ni abstracciones especulativas.
- Constantes exactas de la spec: `ALTURA_TRONCO_MIN := 3`, `ALTURA_TRONCO_MAX := 8`, `RADIO_TRONCO_MIN := 1`, `RADIO_TRONCO_MAX := 4`, `RADIO_FOLLAJE_MIN := 1`, `RADIO_FOLLAJE_MAX := 2` (en `GeneradorArbol.gd`); `UMBRAL_ARBOL := 0.5`, `ESPACIADO_MINIMO_ARBOL := 3` (en `VoxelWorld.gd`).
- Fuera de alcance (documentado en la spec, no implementar aquí): conectar la tala al input real del jugador (`Player.gd`); ramas irregulares; que talar produzca recurso real en un inventario; puestos madereros consumiendo el registro de árboles; que el follaje cuente como madera.
- La salud del árbol es el número de celdas `"tronco"` realmente colocadas (no una fórmula — cuenta las que `colocar_bloque` aceptó), no `altura_tronco` sola.
- Verificación final: ejecutar `godot/scenes/Test.tscn`, `godot/scenes/GeneradorMundoTest.tscn` y `godot/scenes/GeneradorArbolTest.tscn` con Godot 4.7 (vía las herramientas `mcp__godot__*` disponibles en esta sesión) y confirmar que todas las aserciones pasan, sin errores nuevos al cargar `Main.tscn`.
- Actualiza el documento técnico de PoC 5 y el GDD cuando el sub-proyecto quede completo (regla de `CLAUDE.md`) — incluye también la documentación pendiente de las señales de bioma/fauna/frutal (sub-proyecto previo, nunca documentado en GDD/PoC_5).

---

## Contexto de archivos existentes (léelo antes de tocar código)

- `godot/scripts/GeneradorMundo.gd`: clase pura. Ya tiene `es_bioma_en(x,z) -> bool`, `densidad_fauna_en(x,z) -> float`, `densidad_frutal_en(x,z) -> float` (ambas `[0,1]`, cero fuera del bioma, cada una con su propio `FastNoiseLite`: `_ruido_fauna` semilla `semilla+2`, `_ruido_frutal` semilla `semilla+3`). `_init(semilla, ancho_mundo, largo_mundo)` construye todos los ruidos y calcula `nivel_mar` al final.
- `godot/scripts/GeneradorMundoTest.gd`: 14 pruebas existentes (`TEST 1` a `TEST 14`), terminan con `print("\n=== Las 14 pruebas de GeneradorMundo pasaron correctamente ===")`.
- `godot/scripts/VoxelWorld.gd`: `GridMap` con `ANCHO_MUNDO := 200`, `LARGO_MUNDO := 200`, `SEMILLA_MUNDO := 12345`. `_ready()` construye `generador`, llama `_generar_terreno()`. `colocar_bloque(celda, tipo, por_jugador=false) -> bool` (falla si la celda ya está ocupada o el tipo no existe en la MeshLibrary). `altura_en(x,z) -> int` (altura real de la celda sólida más alta, ya generada). No hay ningún registro de "objetos multi-celda generados por el mundo" todavía — el único patrón existente (`pareja`) es 1:1 y es solo para puerta/cama colocadas por el jugador, no aplica aquí.
- `godot/scenes/BlockLibrarySource.tscn`: fuente de la `MeshLibrary`, `load_steps=40` actualmente. Cada bloque es un grupo de 3 `sub_resource` (`StandardMaterial3D`, `BoxMesh`, `BoxShape3D`) más un `MeshInstance3D`+`CollisionShape3D` en `[node]`. El último bloque agregado es `"agua"` (líneas 100-106 para sub-recursos, 182-186 para nodos).
- `godot/scenes/GeneradorMundoTest.tscn`: escena mínima — `[ext_resource type="Script" path="res://scripts/GeneradorMundoTest.gd" id="1"]` + un nodo `Node` con `script = ExtResource("1")`. `GeneradorArbolTest.tscn` (nueva, Task 1) sigue exactamente este mismo patrón con el script nuevo.

---

### Task 1: `GeneradorArbol.gd` — forma procedural del árbol

**Files:**
- Create: `godot/scripts/GeneradorArbol.gd`
- Create: `godot/scripts/GeneradorArbolTest.gd`
- Create: `godot/scenes/GeneradorArbolTest.tscn`

**Interfaces:**
- Consumes: nada de otras tareas.
- Produces: `GeneradorArbol.generar_forma_aleatoria(semilla_arbol: int) -> Dictionary` (`Vector3i` → `String`, `"tronco"` o `"follaje"`), consumida por la Task 2 (registro) y la Task 5 (`VoxelWorld._generar_arboles()`).

- [ ] **Step 1: Crea el archivo de clase con las constantes y la firma vacía**

Crea `godot/scripts/GeneradorArbol.gd`:

```gdscript
extends RefCounted

## Generación procedural de la forma de un árbol (tronco + follaje) y su
## registro de salud/tala — sin nodos de escena. Ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md.
## Sin class_name (mismo motivo que GeneradorMundo.gd/Zonificacion.gd:
## evitar el bug de caché de clases globales de Godot) — se usa vía
## preload().new().

const ALTURA_TRONCO_MIN := 3
const ALTURA_TRONCO_MAX := 8
const RADIO_TRONCO_MIN := 1
const RADIO_TRONCO_MAX := 4
const RADIO_FOLLAJE_MIN := 1
const RADIO_FOLLAJE_MAX := 2


## Forma procedural determinista de un árbol: tronco recto (cilindro de
## radio variable) rematado por una copa esférica de follaje. La misma
## semilla_arbol produce siempre la misma altura de tronco, el mismo radio
## de tronco, el mismo radio de follaje y exactamente los mismos offsets.
## Devuelve un Dictionary Vector3i -> String ("tronco" o "follaje"), con
## offsets relativos a la base del árbol (Vector3i(0,0,0) es el centro de
## la capa de tronco más baja).
func generar_forma_aleatoria(semilla_arbol: int) -> Dictionary:
	return {}
```

- [ ] **Step 2: Crea la escena de prueba**

Crea `godot/scenes/GeneradorArbolTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/GeneradorArbolTest.gd" id="1"]

[node name="GeneradorArbolTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Escribe las pruebas que deben fallar**

Crea `godot/scripts/GeneradorArbolTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de GeneradorArbol.gd (mismo patrón que
## GeneradorMundoTest.gd). Corre esta escena (GeneradorArbolTest.tscn) con
## F6 en el editor de Godot y revisa el panel "Output": debe imprimir
## todas las pruebas y no debe lanzar ningún error de assert().

const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: generar_forma_aleatoria es determinista para la misma semilla ===")
	var gen_a: RefCounted = GeneradorArbolScript.new()
	var gen_b: RefCounted = GeneradorArbolScript.new()
	var forma_a: Dictionary = gen_a.generar_forma_aleatoria(123)
	var forma_b: Dictionary = gen_b.generar_forma_aleatoria(123)
	assert(forma_a.size() == forma_b.size())
	for offset in forma_a:
		assert(forma_b.has(offset))
		assert(forma_a[offset] == forma_b[offset])
	print("OK: la misma semilla_arbol produce exactamente los mismos offsets y tipos.")

	print("\n=== TEST 2: todo offset 'tronco' respeta el rango de altura y el disco de radio ===")
	var gen_rango: RefCounted = GeneradorArbolScript.new()
	for semilla in [1, 2, 3, 42, 999]:
		var forma: Dictionary = gen_rango.generar_forma_aleatoria(semilla)
		var altura_recuperada := 0
		var radio_recuperado := 0
		for offset in forma:
			if forma[offset] == "tronco":
				altura_recuperada = max(altura_recuperada, offset.y + 1)
				if offset.z == 0 and offset.x >= 0:
					radio_recuperado = max(radio_recuperado, offset.x)
		assert(altura_recuperada >= GeneradorArbolScript.ALTURA_TRONCO_MIN)
		assert(altura_recuperada <= GeneradorArbolScript.ALTURA_TRONCO_MAX)
		assert(radio_recuperado >= GeneradorArbolScript.RADIO_TRONCO_MIN)
		assert(radio_recuperado <= GeneradorArbolScript.RADIO_TRONCO_MAX)
		for offset in forma:
			if forma[offset] == "tronco":
				assert(offset.y >= 0 and offset.y < altura_recuperada)
				assert(offset.x * offset.x + offset.z * offset.z <= radio_recuperado * radio_recuperado)
	print("OK: la altura y el radio recuperados de las celdas 'tronco' quedan dentro de los rangos configurados, y ninguna celda 'tronco' cae fuera de su propio disco/altura.")

	print("\n=== TEST 3: el follaje nunca sobrescribe una celda de tronco ===")
	var gen_solape: RefCounted = GeneradorArbolScript.new()
	var forma_solape: Dictionary = gen_solape.generar_forma_aleatoria(7)
	var altura_solape := 0
	var radio_solape := 0
	for offset in forma_solape:
		if forma_solape[offset] == "tronco":
			altura_solape = max(altura_solape, offset.y + 1)
			if offset.z == 0 and offset.x >= 0:
				radio_solape = max(radio_solape, offset.x)
	for y in range(altura_solape):
		for dx in range(-radio_solape, radio_solape + 1):
			for dz in range(-radio_solape, radio_solape + 1):
				if dx * dx + dz * dz <= radio_solape * radio_solape:
					var celda := Vector3i(dx, y, dz)
					assert(forma_solape.get(celda, "") == "tronco")
	print("OK: toda celda dentro del disco/altura del tronco quedó marcada 'tronco', incluso donde el follaje podría solaparse.")

	print("\n=== Las 3 pruebas de GeneradorArbol pasaron correctamente ===")
```

- [ ] **Step 4: Corre la escena y confirma que falla**

Usa `ToolSearch` con la query `"select:mcp__godot__run_project,mcp__godot__get_debug_output,mcp__godot__stop_project"` si esas herramientas no están cargadas. Luego `mcp__godot__run_project` con la escena `res://scenes/GeneradorArbolTest.tscn` (proyecto `godot/project.godot`), luego `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project`.
Esperado: falla — `generar_forma_aleatoria` devuelve `{}` (vacío), así que las aserciones de TEST 1 podrían pasar trivialmente (dos vacíos son iguales) pero TEST 2 falla porque `altura_recuperada` nunca sube de `0`, violando `assert(altura_recuperada >= ALTURA_TRONCO_MIN)`.

- [ ] **Step 5: Implementa la generación real**

Reemplaza el cuerpo de `generar_forma_aleatoria()` en `godot/scripts/GeneradorArbol.gd`:

```gdscript
func generar_forma_aleatoria(semilla_arbol: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla_arbol
	var altura_tronco: int = rng.randi_range(ALTURA_TRONCO_MIN, ALTURA_TRONCO_MAX)
	var radio_tronco: int = rng.randi_range(RADIO_TRONCO_MIN, RADIO_TRONCO_MAX)
	var radio_follaje: int = rng.randi_range(RADIO_FOLLAJE_MIN, RADIO_FOLLAJE_MAX)

	var forma: Dictionary = {}
	for y in range(altura_tronco):
		for dx in range(-radio_tronco, radio_tronco + 1):
			for dz in range(-radio_tronco, radio_tronco + 1):
				if dx * dx + dz * dz <= radio_tronco * radio_tronco:
					forma[Vector3i(dx, y, dz)] = "tronco"

	var centro_follaje := Vector3i(0, altura_tronco, 0)
	for dx in range(-radio_follaje, radio_follaje + 1):
		for dy in range(-radio_follaje, radio_follaje + 1):
			for dz in range(-radio_follaje, radio_follaje + 1):
				if dx * dx + dy * dy + dz * dz <= radio_follaje * radio_follaje:
					var offset: Vector3i = centro_follaje + Vector3i(dx, dy, dz)
					if not forma.has(offset):
						forma[offset] = "follaje"

	return forma
```

- [ ] **Step 6: Corre la escena y confirma que las 3 pruebas pasan**

Repite el Step 4. Esperado: se imprimen las 3 pruebas con "OK", termina con "Las 3 pruebas de GeneradorArbol pasaron correctamente", sin ningún "Assertion failed".

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/GeneradorArbol.gd godot/scripts/GeneradorArbolTest.gd godot/scenes/GeneradorArbolTest.tscn
git commit -m "feat: generar la forma procedural de un árbol (tronco + follaje)"
```

---

### Task 2: `GeneradorArbol.gd` — registro de salud y tala

**Files:**
- Modify: `godot/scripts/GeneradorArbol.gd`
- Modify: `godot/scripts/GeneradorArbolTest.gd`
- Test scene: `godot/scenes/GeneradorArbolTest.tscn`

**Interfaces:**
- Consumes: nada de `generar_forma_aleatoria()` directamente (son funciones independientes en la misma instancia).
- Produces: `GeneradorArbol.registrar(celdas_mundiales: Array, salud_maxima: int) -> int`, `GeneradorArbol.obtener_arbol_de(celda: Vector3i) -> int`, `GeneradorArbol.celdas_de(id: int) -> Array`, `GeneradorArbol.danar(id: int, dano: int) -> bool`, `GeneradorArbol.eliminar(id: int) -> void` — todas consumidas por la Task 5 (`VoxelWorld._generar_arboles()`/`talar_bloque_de_arbol()`).

- [ ] **Step 1: Escribe las pruebas que deben fallar**

En `godot/scripts/GeneradorArbolTest.gd`, después del bloque del "TEST 3" y antes del `print` final, inserta:

```gdscript
	print("\n=== TEST 4: registrar/obtener_arbol_de/celdas_de son consistentes ===")
	var gen_reg: RefCounted = GeneradorArbolScript.new()
	var celdas_1: Array = [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0)]
	var id_1: int = gen_reg.registrar(celdas_1, 2)
	var celdas_2: Array = [Vector3i(10, 0, 10), Vector3i(10, 1, 10)]
	var id_2: int = gen_reg.registrar(celdas_2, 2)
	assert(id_1 != id_2)
	for celda in celdas_1:
		assert(gen_reg.obtener_arbol_de(celda) == id_1)
	for celda in celdas_2:
		assert(gen_reg.obtener_arbol_de(celda) == id_2)
	assert(gen_reg.celdas_de(id_1) == celdas_1)
	assert(gen_reg.celdas_de(id_2) == celdas_2)
	print("OK: cada celda registrada devuelve el id correcto, y celdas_de() devuelve exactamente el conjunto original.")

	print("\n=== TEST 5: obtener_arbol_de devuelve -1 para una celda nunca registrada ===")
	assert(gen_reg.obtener_arbol_de(Vector3i(999, 999, 999)) == -1)
	print("OK: una celda que nunca fue registrada devuelve -1.")

	print("\n=== TEST 6: danar reduce la salud y solo devuelve true al agotarla ===")
	var gen_danio: RefCounted = GeneradorArbolScript.new()
	var id_danio: int = gen_danio.registrar([Vector3i(5, 0, 5)], 5)
	assert(gen_danio.danar(id_danio, 2) == false)
	assert(gen_danio.danar(id_danio, 2) == false)
	assert(gen_danio.danar(id_danio, 2) == true)
	print("OK: un árbol de salud 5 sigue en pie tras 2+2 de daño, y queda talado al recibir el tercer golpe de 2 (acumulado 6 >= 5).")

	print("\n=== TEST 7: danar con daño mayor a la salud restante talan de inmediato ===")
	var gen_danio_grande: RefCounted = GeneradorArbolScript.new()
	var id_grande: int = gen_danio_grande.registrar([Vector3i(6, 0, 6)], 3)
	assert(gen_danio_grande.danar(id_grande, 10) == true)
	print("OK: un daño mayor a la salud restante tala el árbol en un solo golpe.")

	print("\n=== TEST 8: eliminar limpia el registro por completo ===")
	var gen_elim: RefCounted = GeneradorArbolScript.new()
	var celdas_elim: Array = [Vector3i(7, 0, 7), Vector3i(7, 1, 7)]
	var id_elim: int = gen_elim.registrar(celdas_elim, 2)
	gen_elim.eliminar(id_elim)
	for celda in celdas_elim:
		assert(gen_elim.obtener_arbol_de(celda) == -1)
	assert(gen_elim.celdas_de(id_elim) == [])
	print("OK: tras eliminar, ninguna de sus celdas ni su id siguen en el registro.")

	print("\n=== Las 8 pruebas de GeneradorArbol pasaron correctamente ===")
```

Y borra la línea anterior `print("\n=== Las 3 pruebas de GeneradorArbol pasaron correctamente ===")` (queda reemplazada por la nueva línea final de arriba).

- [ ] **Step 2: Corre la escena y confirma que falla**

Repite `mcp__godot__run_project` / `get_debug_output` / `stop_project` sobre `GeneradorArbolTest.tscn`.
Esperado: error — `registrar`/`obtener_arbol_de`/`celdas_de`/`danar`/`eliminar` no existen todavía en `GeneradorArbolScript` (p. ej. "Invalid call. Nonexistent function 'registrar'").

- [ ] **Step 3: Implementa el registro**

En `godot/scripts/GeneradorArbol.gd`, agrega después de las constantes (antes de `generar_forma_aleatoria`):

```gdscript
var _siguiente_id := 0
var _arboles: Dictionary = {}  # int -> {"celdas": Array, "salud": int}
var _celda_a_arbol: Dictionary = {}  # Vector3i -> int
```

Y agrega, al final del archivo, después de `generar_forma_aleatoria()`:

```gdscript


## Registra un árbol nuevo con las celdas mundiales dadas (tronco y
## follaje) y la salud máxima indicada (número de celdas "tronco" — ver
## generar_forma_aleatoria()). Devuelve el id asignado.
func registrar(celdas_mundiales: Array, salud_maxima: int) -> int:
	var id: int = _siguiente_id
	_siguiente_id += 1
	_arboles[id] = {"celdas": celdas_mundiales, "salud": salud_maxima}
	for celda in celdas_mundiales:
		_celda_a_arbol[celda] = id
	return id


## -1 si la celda no pertenece a ningún árbol registrado.
func obtener_arbol_de(celda: Vector3i) -> int:
	return _celda_a_arbol.get(celda, -1)


## Todas las celdas mundiales (tronco y follaje) del árbol con ese id.
## Array vacío si el id no existe (p. ej. ya fue eliminado).
func celdas_de(id: int) -> Array:
	if not _arboles.has(id):
		return []
	return _arboles[id]["celdas"]


## Resta "dano" a la salud del árbol "id". Devuelve true si la salud quedó
## en 0 o menos (árbol completamente talado) — no borra bloques ni el
## registro, eso es responsabilidad del llamador (ver VoxelWorld.
## talar_bloque_de_arbol(), Task 5).
func danar(id: int, dano: int) -> bool:
	if not _arboles.has(id):
		return false
	_arboles[id]["salud"] -= dano
	return _arboles[id]["salud"] <= 0


## Limpia el registro del árbol "id": su entrada y todas sus celdas del
## índice inverso.
func eliminar(id: int) -> void:
	if not _arboles.has(id):
		return
	for celda in _arboles[id]["celdas"]:
		_celda_a_arbol.erase(celda)
	_arboles.erase(id)
```

- [ ] **Step 4: Corre la escena y confirma que las 8 pruebas pasan**

Repite el Step 2. Esperado: se imprimen las 8 pruebas con "OK", termina con "Las 8 pruebas de GeneradorArbol pasaron correctamente", sin ningún "Assertion failed".

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/GeneradorArbol.gd godot/scripts/GeneradorArbolTest.gd
git commit -m "feat: agregar registro de salud y tala de árboles"
```

---

### Task 3: `densidad_arbol_en` — cuarta señal en `GeneradorMundo.gd`

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd`
- Modify: `godot/scripts/GeneradorMundoTest.gd`
- Test scene: `godot/scenes/GeneradorMundoTest.tscn`

**Interfaces:**
- Consumes: `es_bioma_en(x, z) -> bool` (ya existente).
- Produces: `GeneradorMundo.densidad_arbol_en(x: int, z: int) -> float` (`[0,1]`, `0.0` fuera del bioma), consumida por la Task 5 (`VoxelWorld._generar_arboles()`).

- [ ] **Step 1: Escribe la prueba que debe fallar**

En `godot/scripts/GeneradorMundoTest.gd`, después del bloque del "TEST 14" (el último existente) y antes del `print` final, inserta:

```gdscript
	print("\n=== TEST 15: densidad_arbol_en es determinista, está en [0,1], y es 0.0 fuera del bioma ===")
	var gen_dens_arbol_a: RefCounted = GeneradorMundoScript.new(333, 60, 60)
	var gen_dens_arbol_b: RefCounted = GeneradorMundoScript.new(333, 60, 60)
	var vio_fuera_arbol := false
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var a: float = gen_dens_arbol_a.densidad_arbol_en(x, z)
			var b: float = gen_dens_arbol_b.densidad_arbol_en(x, z)
			assert(is_equal_approx(a, b))
			assert(a >= 0.0 and a <= 1.0)
			if not gen_dens_arbol_a.es_bioma_en(x, z):
				vio_fuera_arbol = true
				assert(a == 0.0)
	assert(vio_fuera_arbol)
	print("OK: densidad_arbol_en es determinista, está en [0,1], y es exactamente 0.0 fuera del bioma (al menos una columna encontrada).")

	print("\n=== Las 15 pruebas de GeneradorMundo pasaron correctamente ===")
```

Y borra la línea anterior `print("\n=== Las 14 pruebas de GeneradorMundo pasaron correctamente ===")`.

- [ ] **Step 2: Corre la escena y confirma que falla**

Usa `mcp__godot__run_project` con `res://scenes/GeneradorMundoTest.tscn`, luego `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project`.
Esperado: error — `densidad_arbol_en` no existe todavía (p. ej. "Invalid call. Nonexistent function 'densidad_arbol_en'").

- [ ] **Step 3: Implementa la señal**

En `godot/scripts/GeneradorMundo.gd`, agrega la variable nueva justo después de `var _ruido_frutal: FastNoiseLite`:

```gdscript
var _ruido_arbol: FastNoiseLite
```

En `_init()`, después del bloque que construye `_ruido_frutal` (antes de la línea `nivel_mar = _calcular_nivel_mar(...)`), agrega:

```gdscript

	# Semilla derivada distinta de _ruido, _ruido_mineral (semilla+1),
	# _ruido_fauna (semilla+2) y _ruido_frutal (semilla+3) — igual de
	# determinista: misma semilla de entrada, misma densidad de árboles
	# siempre.
	_ruido_arbol = FastNoiseLite.new()
	_ruido_arbol.seed = semilla + 4
	_ruido_arbol.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_arbol.frequency = 0.05
```

Al final del archivo, después de `densidad_frutal_en()`, agrega:

```gdscript


## Densidad de árboles en la columna (x, z), en [0, 1] — 0.0 si la columna
## no es bioma (ver es_bioma_en()). VoxelWorld._generar_arboles() coloca un
## árbol real donde esta densidad supera un umbral (ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md).
func densidad_arbol_en(x: int, z: int) -> float:
	if not es_bioma_en(x, z):
		return 0.0
	var valor: float = _ruido_arbol.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0
```

- [ ] **Step 4: Corre la escena y confirma que las 15 pruebas pasan**

Repite el Step 2. Esperado: se imprimen las 15 pruebas con "OK", termina con "Las 15 pruebas de GeneradorMundo pasaron correctamente", sin ningún "Assertion failed".

- [ ] **Step 5: Corre Test.tscn como regresión**

Usa `mcp__godot__run_project` sobre `res://scenes/Test.tscn`. Esperado: las 14 aserciones de `BlueprintValidatorTest` siguen pasando igual que antes.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: agregar densidad_arbol_en en GeneradorMundo"
```

---

### Task 4: Bloques `"tronco"` y `"follaje"` en la MeshLibrary

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Regenerate: `godot/assets/BlockLibrary.res`

**Interfaces:**
- Consumes: nada de las tareas anteriores.
- Produces: los tipos de bloque `"tronco"` y `"follaje"` disponibles en `assets/BlockLibrary.res`, consumidos por `VoxelWorld.colocar_bloque()` en la Task 5.

- [ ] **Step 1: Agrega los bloques a la escena fuente**

En `godot/scenes/BlockLibrarySource.tscn`, después del bloque `[sub_resource type="BoxShape3D" id="Shape_agua"]` (última línea de sub-recursos, línea 106), agrega:

```
[sub_resource type="StandardMaterial3D" id="Mat_tronco"]
albedo_color = Color(0.4, 0.26, 0.13, 1)

[sub_resource type="BoxMesh" id="Mesh_tronco"]
material = SubResource("Mat_tronco")

[sub_resource type="BoxShape3D" id="Shape_tronco"]

[sub_resource type="StandardMaterial3D" id="Mat_follaje"]
albedo_color = Color(0.15, 0.5, 0.2, 1)

[sub_resource type="BoxMesh" id="Mesh_follaje"]
material = SubResource("Mat_follaje")

[sub_resource type="BoxShape3D" id="Shape_follaje"]
```

Y después del nodo `[node name="CollisionShape3D" type="CollisionShape3D" parent="agua"]` / `shape = SubResource("Shape_agua")` (últimas líneas del archivo), agrega:

```
[node name="tronco" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_tronco")

[node name="CollisionShape3D" type="CollisionShape3D" parent="tronco"]
shape = SubResource("Shape_tronco")

[node name="follaje" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_follaje")

[node name="CollisionShape3D" type="CollisionShape3D" parent="follaje"]
shape = SubResource("Shape_follaje")
```

Actualiza la cabecera `[gd_scene load_steps=40 format=3]` a `load_steps=46` (se agregan 6 sub-recursos nuevos, 3 por bloque). Nota: si el número queda ligeramente desalineado, Godot lo recalcula sin error al guardar la escena desde el editor.

- [ ] **Step 2: Regenera la MeshLibrary**

Usa `mcp__godot__export_mesh_library` sobre `res://scenes/BlockLibrarySource.tscn` con destino `res://assets/BlockLibrary.res` (mismo flujo que se usó para agregar `agua`/`mina`/etc.). Si la herramienta no está disponible, hazlo manualmente en el editor: abre `BlockLibrarySource.tscn`, selecciona el nodo raíz, "Escena" → "Convertir a..." → "MeshLibrary", guarda sobre `res://assets/BlockLibrary.res`.

- [ ] **Step 3: Verifica que los bloques quedaron indexados**

Usa `mcp__godot__run_project` sobre `res://scenes/Test.tscn` y revisa `mcp__godot__get_debug_output` — sin errores de carga de recursos. Si tienes duda de que "tronco"/"follaje" quedaron en la MeshLibrary, revisa la salida de `mcp__godot__export_mesh_library` del Step 2 (debe listar ambos nombres con un ID asignado, mismo patrón que en tareas anteriores).

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res
git commit -m "feat: agregar bloques placeholder de tronco y follaje a la MeshLibrary"
```

---

### Task 5: `VoxelWorld` — generar árboles reales y talarlos

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`

**Interfaces:**
- Consumes: `generador.densidad_arbol_en(x,z) -> float` (Task 3), `generador.altura_en(x,z) -> int` (ya existente), `GeneradorArbol.generar_forma_aleatoria/registrar/obtener_arbol_de/celdas_de/danar` (Tasks 1-2), tipos de bloque `"tronco"`/`"follaje"` (Task 4).
- Produces: `VoxelWorld.talar_bloque_de_arbol(celda: Vector3i, dano: int) -> bool` — consumido en el futuro por `Player.gd` (fuera de alcance de este plan).

- [ ] **Step 1: Instancia el generador de árboles y agrega las constantes**

En `godot/scripts/VoxelWorld.gd`, agrega después de `const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")`:

```gdscript
const GeneradorArbol = preload("res://scripts/GeneradorArbol.gd")
```

Agrega después de `const SEMILLA_MUNDO := 12345`:

```gdscript

## Umbral de densidad_arbol_en() (rango [0,1]) por encima del cual una
## columna de bioma recibe un árbol real — ver _generar_arboles(). Valor
## inicial calibrado empíricamente, mismo patrón que UMBRAL_HIERRO/
## EXPONENTE_RELIEVE: ajustar aquí si el bosque real resulta demasiado
## denso o demasiado escaso.
const UMBRAL_ARBOL := 0.5

## Distancia horizontal mínima (en celdas) entre las bases de dos árboles,
## para que sus copas no se superpongan — ver _generar_arboles().
const ESPACIADO_MINIMO_ARBOL := 3
```

Agrega después de `var generador: RefCounted`:

```gdscript
var arboles: RefCounted
```

En `_ready()`, después de la línea `generador = GeneradorMundo.new(SEMILLA_MUNDO, ANCHO_MUNDO, LARGO_MUNDO)` y ANTES de `_generar_terreno()`, agrega:

```gdscript
	arboles = GeneradorArbol.new()
```

Y después de la línea `_generar_terreno()`, agrega:

```gdscript
	_generar_arboles()
```

(El orden final de `_ready()` queda: indexar biblioteca, crear `generador`, crear `arboles`, `_generar_terreno()`, `_generar_arboles()`.)

- [ ] **Step 2: Implementa `_generar_arboles()`**

Agrega al final del archivo:

```gdscript


## Coloca árboles reales en las columnas de bioma cuya densidad supera
## UMBRAL_ARBOL, respetando ESPACIADO_MINIMO_ARBOL entre bases para que
## las copas no se superpongan — ver spec:
## docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md.
func _generar_arboles() -> void:
	var bases_colocadas: Array[Vector2i] = []
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			if generador.densidad_arbol_en(x, z) <= UMBRAL_ARBOL:
				continue
			var demasiado_cerca := false
			for base_previa in bases_colocadas:
				var dx: int = x - base_previa.x
				var dz: int = z - base_previa.y
				if dx * dx + dz * dz <= ESPACIADO_MINIMO_ARBOL * ESPACIADO_MINIMO_ARBOL:
					demasiado_cerca = true
					break
			if demasiado_cerca:
				continue
			var altura: int = generador.altura_en(x, z)
			var base := Vector3i(x, altura + 1, z)
			var semilla_arbol: int = SEMILLA_MUNDO + x * LARGO_MUNDO + z
			var forma: Dictionary = arboles.generar_forma_aleatoria(semilla_arbol)
			var celdas_mundiales: Array = []
			var salud := 0
			for offset in forma:
				var celda: Vector3i = base + offset
				var tipo: String = forma[offset]
				if colocar_bloque(celda, tipo):
					celdas_mundiales.append(celda)
					if tipo == "tronco":
						salud += 1
			if salud > 0:
				arboles.registrar(celdas_mundiales, salud)
			bases_colocadas.append(Vector2i(x, z))
```

- [ ] **Step 3: Implementa `talar_bloque_de_arbol()`**

Agrega al final del archivo:

```gdscript


## Busca el árbol dueño de "celda"; si no hay ninguno, no hace nada y
## devuelve false. Si hay uno, aplica "dano" a su salud (ver
## GeneradorArbol.danar()); si quedó completamente talado, borra todas sus
## celdas del GridMap de una sola vez (mientras tiene salud restante,
## ningún bloque del árbol se toca) y limpia su registro. Devuelve si el
## árbol quedó completamente talado.
func talar_bloque_de_arbol(celda: Vector3i, dano: int) -> bool:
	var id: int = arboles.obtener_arbol_de(celda)
	if id == -1:
		return false
	var talado: bool = arboles.danar(id, dano)
	if talado:
		for c in arboles.celdas_de(id):
			set_cell_item(c, GridMap.INVALID_CELL_ITEM)
		arboles.eliminar(id)
	return talado
```

- [ ] **Step 4: Verificación — Test.tscn, GeneradorMundoTest.tscn, GeneradorArbolTest.tscn**

Corre las tres escenas vía `mcp__godot__run_project` + `get_debug_output` + `stop_project`, una a la vez:
- `res://scenes/Test.tscn`: las 14 aserciones de `BlueprintValidatorTest` deben seguir pasando.
- `res://scenes/GeneradorMundoTest.tscn`: las 15 aserciones deben seguir pasando.
- `res://scenes/GeneradorArbolTest.tscn`: las 8 aserciones deben seguir pasando.

- [ ] **Step 5: Verificación de carga sin errores — Main.tscn**

Corre `res://scenes/Main.tscn` vía `mcp__godot__run_project`. El mundo real (200×200) ahora genera terreno, agua Y árboles — dale un margen de espera generoso (al menos 40-60 segundos, con dos o tres chequeos de `mcp__godot__get_debug_output` espaciados) antes de concluir que algo falló; un output que no cambia entre dos chequeos separados por ~15-20s con el proceso todavía corriendo es una señal razonable de que sigue generando, no de que está colgado. Revisa que no haya errores de carga ni excepciones de GDScript nuevas (los 5 warnings de "invalid UID" ya documentados como preexistentes en tareas anteriores no cuentan). Detén con `mcp__godot__stop_project`. La confirmación visual real (formas de árbol razonables, sin superposición de copas) queda pendiente de revisión jugando en el editor real, mismo patrón que el resto de PoC 5.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/VoxelWorld.gd
git commit -m "feat: generar árboles reales en VoxelWorld y agregar talar_bloque_de_arbol"
```

---

### Task 6: Documentar el sub-proyecto como completo (incluye señales de bioma pendientes de documentar)

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`

**Interfaces:**
- Consumes: el resultado de las Tasks 1-5 (para describir qué quedó implementado).
- Produces: nada consumido por código — es documentación, requerida por la regla de `CLAUDE.md`.

- [ ] **Step 1: Actualiza el documento técnico de PoC 5**

En `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`, agrega una nueva sub-sección (numeración siguiente a la última existente, p. ej. "3.11") describiendo:
1. Las señales de bioma/fauna/frutal (`es_bioma_en`, `BANDA_BIOMA := 4`, `densidad_fauna_en`, `densidad_frutal_en`) del sub-proyecto anterior — **nunca documentadas hasta ahora**, referencia la spec `docs/superpowers/specs/2026-09-09-senales-bioma-design.md`.
2. Los árboles procedurales de este plan (`GeneradorArbol.gd`: forma con tronco de radio/altura variable + follaje, registro de salud/tala; `densidad_arbol_en`; `VoxelWorld._generar_arboles()`/`talar_bloque_de_arbol()`) — referencia la spec `docs/superpowers/specs/2026-09-09-arboles-procedurales-design.md`.

Usa el mismo nivel de detalle técnico (nombres reales de constantes/funciones, qué pruebas cubren qué) que las secciones "Verificado" existentes (3.5 en adelante). Menciona explícitamente qué queda pendiente: conexión con `Player.gd`, ramas irregulares, puestos madereros, biomas diferenciados por humedad/temperatura, percentil de nivel de mar por tipo de mundo, confirmación visual jugando en el editor real.

- [ ] **Step 2: Actualiza el GDD**

En `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`, dentro de la fila de la Fase 3 (Sección 11), busca la frase sobre el sub-proyecto 3 ("Puestos de Recolección... alcance reducido a minas... Los puestos de caza y recolección de plantas quedan pendientes... dependen de biomas/vegetación/fauna reales") y actualízala para reflejar que las señales de bioma/fauna/frutal y los árboles procedurales ya existen (aunque los puestos madereros/caza en sí sigan sin implementarse) — sigue el mismo estilo narrativo que las demás entradas de esa fila.

- [ ] **Step 3: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: document biome signals and procedural trees (PoC 5) as complete"
```
