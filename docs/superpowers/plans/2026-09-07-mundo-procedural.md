# Mundo Procedural Finito — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el piso plano placeholder de `VoxelWorld.gd` por un mundo con relieve real, generado una única vez al iniciar la partida mediante ruido determinista.

**Architecture:** Un script nuevo sin nodos de escena, `GeneradorMundo.gd`, envuelve `FastNoiseLite` (nativo de Godot) y expone `altura_en(x, z)` puro y determinista. `VoxelWorld.gd` lo usa para llenar cada columna (superficie + subsuelo de `tierra`/`piedra`) al arrancar. Dos bloques nuevos (`tierra`, `piedra`) se agregan a la `MeshLibrary` existente siguiendo el mismo patrón que los bloques actuales.

**Tech Stack:** Godot Engine 4.7 (GDScript), `FastNoiseLite` nativo, proyecto compartido `godot/`.

**Spec:** `docs/superpowers/specs/2026-09-07-mundo-procedural-design.md`

## Global Constraints

- Usar tabulaciones (tabs) en todo GDScript, no espacios.
- Mantener el español en comentarios, mensajes impresos y nombres de pruebas.
- Tamaño de esta PoC: `ANCHO_MUNDO = 200`, `LARGO_MUNDO = 200`, `PROFUNDIDAD_SUBSUELO = 32` (no los ~300 finales del GDD — ver spec, "Fuera de Alcance").
- Capas de subsuelo: `GROSOR_TIERRA = 4` celdas de `"tierra"` justo bajo la superficie, `"piedra"` en todo lo demás hasta `PROFUNDIDAD_SUBSUELO`.
- Rango de altura de la superficie: `ALTURA_MINIMA = 0`, `ALTURA_MAXIMA = 15`.
- Semilla fija para esta PoC: `SEMILLA_MUNDO = 12345` (desarrollo determinista — semilla real aleatoria es trabajo de una fase posterior).
- No declarar `class_name` en `GeneradorMundo.gd` (sigue el mismo patrón que `Zonificacion.gd`/`Ciudad.gd`/`ZonaOverlay.gd`/`CamaraCenital.gd` en este proyecto, para evitar el bug de caché de clases globales de Godot documentado repetidamente en `PoC_3/`) — se referencia siempre vía `preload(...)`.
- No hacer `git commit` salvo que el usuario lo pida explícitamente (regla general de esta sesión).
- Verificación de cada tarea: `mcp__godot__run_project` + `mcp__godot__get_debug_output` contra la escena relevante, confirmando que no hay `errors` nuevos.

---

### Task 1: `GeneradorMundo.gd` — mapa de alturas puro y determinista

**Files:**
- Create: `godot/scripts/GeneradorMundo.gd`
- Create: `godot/scripts/GeneradorMundoTest.gd`
- Create: `godot/scenes/GeneradorMundoTest.tscn`

**Interfaces:**
- Produces (consumido por la Tarea 3):
  - `GeneradorMundo.ALTURA_MINIMA: int` (constante, `0`)
  - `GeneradorMundo.ALTURA_MAXIMA: int` (constante, `15`)
  - `GeneradorMundo.GROSOR_TIERRA: int` (constante, `4`)
  - `func _init(semilla: int) -> void`
  - `func altura_en(x: int, z: int) -> int`
  - `func tipo_en_profundidad(profundidad_bajo_superficie: int) -> String`

- [ ] **Step 1: Crear `GeneradorMundo.gd`**

```gdscript
extends RefCounted

## Generación pura del mapa de alturas del mundo — sin nodos de escena, sin
## GridMap. Ver spec: docs/superpowers/specs/2026-09-07-mundo-procedural-design.md
## Sin class_name (mismo motivo que Zonificacion.gd/Ciudad.gd: evitar el bug
## de caché de clases globales de Godot) — se usa vía preload().new().

const ALTURA_MINIMA := 0
const ALTURA_MAXIMA := 15
const GROSOR_TIERRA := 4

var _ruido: FastNoiseLite


func _init(semilla: int) -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido.frequency = 0.02


## Altura de la superficie en (x, z), determinista para (semilla, x, z).
## get_noise_2d() devuelve un valor en [-1, 1]; se remapea linealmente a
## [ALTURA_MINIMA, ALTURA_MAXIMA] y se redondea a entero.
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var t: float = (valor + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)


## Tipo de bloque de subsuelo según qué tan profundo está bajo la
## superficie: 0 = la celda de superficie misma, 1 = la primera celda
## debajo, etc. "tierra" cerca de la superficie, "piedra" más profundo —
## relativo a GROSOR_TIERRA, no a un número de capa absoluto (para poder
## escalar PROFUNDIDAD_SUBSUELO más adelante sin tocar esta función).
func tipo_en_profundidad(profundidad_bajo_superficie: int) -> String:
	if profundidad_bajo_superficie < GROSOR_TIERRA:
		return "tierra"
	return "piedra"
```

- [ ] **Step 2: Crear `GeneradorMundoTest.gd`**

```gdscript
extends Node

## Pruebas aisladas de GeneradorMundo.gd (mismo patrón que ZonificacionTest.gd
## y CiudadTest.gd). Corre esta escena (GeneradorMundoTest.tscn) con F6 en el
## editor de Godot y revisa el panel "Output": debe imprimir las 4 pruebas y
## no debe lanzar ningún error de assert().

const GeneradorMundoScript = preload("res://scripts/GeneradorMundo.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Determinismo (misma semilla, mismas coordenadas) ===")
	var gen_a: RefCounted = GeneradorMundoScript.new(12345)
	var gen_b: RefCounted = GeneradorMundoScript.new(12345)
	for i in range(20):
		var x: int = i * 7
		var z: int = i * 3
		assert(gen_a.altura_en(x, z) == gen_b.altura_en(x, z))
	print("OK: 20 puntos de muestra coinciden entre dos instancias con la misma semilla.")

	print("\n=== TEST 2: Alturas dentro del rango esperado ===")
	var gen: RefCounted = GeneradorMundoScript.new(999)
	for x in range(-50, 50, 5):
		for z in range(-50, 50, 5):
			var altura: int = gen.altura_en(x, z)
			assert(altura >= GeneradorMundoScript.ALTURA_MINIMA)
			assert(altura <= GeneradorMundoScript.ALTURA_MAXIMA)
	print("OK: todas las alturas muestreadas (incluyendo coordenadas negativas) están en rango.")

	print("\n=== TEST 3: Semillas distintas producen mapas distintos ===")
	var gen_1: RefCounted = GeneradorMundoScript.new(1)
	var gen_2: RefCounted = GeneradorMundoScript.new(2)
	var hay_diferencia := false
	for x in range(0, 100, 3):
		for z in range(0, 100, 3):
			if gen_1.altura_en(x, z) != gen_2.altura_en(x, z):
				hay_diferencia = true
				break
		if hay_diferencia:
			break
	assert(hay_diferencia)
	print("OK: al menos un punto muestreado difiere entre semilla 1 y semilla 2.")

	print("\n=== TEST 4: tipo_en_profundidad() por capas ===")
	var gen_capas: RefCounted = GeneradorMundoScript.new(1)
	for p in range(GeneradorMundoScript.GROSOR_TIERRA):
		assert(gen_capas.tipo_en_profundidad(p) == "tierra")
	assert(gen_capas.tipo_en_profundidad(GeneradorMundoScript.GROSOR_TIERRA) == "piedra")
	assert(gen_capas.tipo_en_profundidad(GeneradorMundoScript.GROSOR_TIERRA + 10) == "piedra")
	print("OK: tierra hasta GROSOR_TIERRA, piedra en adelante.")

	print("\n=== Las 4 pruebas de GeneradorMundo pasaron correctamente ===")
```

- [ ] **Step 3: Crear `GeneradorMundoTest.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/GeneradorMundoTest.gd" id="1"]

[node name="GeneradorMundoTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: Correr las pruebas vía Godot MCP**

Run: `mcp__godot__run_project` con `projectPath: "<repo>/godot"` y `scene: "res://scenes/GeneradorMundoTest.tscn"`, luego `mcp__godot__get_debug_output`.
Expected: el panel de salida imprime los 4 tests y termina con "Las 4 pruebas de GeneradorMundo pasaron correctamente", `errors` vacío (sin ningún `assert()` fallido). Luego `mcp__godot__stop_project`.

---

### Task 2: Bloques `"tierra"` y `"piedra"` en la `MeshLibrary`

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Modify: `godot/assets/BlockLibrary.res` (regenerado, no editado a mano)

**Interfaces:**
- Produces (consumido por la Tarea 3): dos ítems nuevos en la `MeshLibrary`, con nombres exactos `"tierra"` y `"piedra"` (el string usado por `VoxelWorld.colocar_bloque(celda, tipo)` para buscarlos en `_id_por_tipo`).

- [ ] **Step 1: Leer el estado actual de `BlockLibrarySource.tscn`**

Este archivo ya tiene 8 bloques (`pared`, `puerta_inferior`, `puerta_superior`, `ventana`, `piso`, `cama_cabecera`, `cama_pies`, `baul`), cada uno como un `MeshInstance3D` (con `BoxMesh` + `StandardMaterial3D` de color plano) con un `CollisionShape3D` hijo. `load_steps` actualmente es `25` (8 bloques × 3 sub-recursos cada uno, más 1 por la escena). Confirmar esta estructura leyendo el archivo antes de editar.

- [ ] **Step 2: Agregar los sub-recursos y nodos de `tierra` y `piedra`**

Agregar, después del último `[sub_resource type="BoxShape3D" id="Shape_baul"]` (antes de `[node name="BlockLibrarySource" ...]`):

```
[sub_resource type="StandardMaterial3D" id="Mat_tierra"]
albedo_color = Color(0.45, 0.3, 0.15, 1)

[sub_resource type="BoxMesh" id="Mesh_tierra"]
material = SubResource("Mat_tierra")

[sub_resource type="BoxShape3D" id="Shape_tierra"]

[sub_resource type="StandardMaterial3D" id="Mat_piedra"]
albedo_color = Color(0.45, 0.45, 0.48, 1)

[sub_resource type="BoxMesh" id="Mesh_piedra"]
material = SubResource("Mat_piedra")

[sub_resource type="BoxShape3D" id="Shape_piedra"]
```

Y, después del último bloque de nodos (`[node name="CollisionShape3D" type="CollisionShape3D" parent="baul"]` con su `shape`), agregar:

```
[node name="tierra" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_tierra")

[node name="CollisionShape3D" type="CollisionShape3D" parent="tierra"]
shape = SubResource("Shape_tierra")

[node name="piedra" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_piedra")

[node name="CollisionShape3D" type="CollisionShape3D" parent="piedra"]
shape = SubResource("Shape_piedra")
```

- [ ] **Step 3: Actualizar `load_steps` en la primera línea del archivo**

Cambiar `[gd_scene load_steps=25 format=3]` a `[gd_scene load_steps=31 format=3]` (25 + 6 sub-recursos nuevos).

- [ ] **Step 4: Regenerar `BlockLibrary.res` vía Godot MCP**

Run: `mcp__godot__export_mesh_library` con `projectPath: "<repo>/godot"`, `scenePath: "res://scenes/BlockLibrarySource.tscn"`, `outputPath: "res://assets/BlockLibrary.res"` (sin `meshItemNames`, para incluir todos los ítems — los 8 existentes más `tierra`/`piedra`).
Expected: la llamada reporta éxito, sin errores.

- [ ] **Step 5: Verificar que `Main.tscn` sigue cargando sin errores nuevos**

Run: `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"`, luego `mcp__godot__get_debug_output`.
Expected: mismas advertencias `SHADOWED_GLOBAL_IDENTIFIER`/`WARNING: Integer division` ya conocidas, sin errores nuevos (la `MeshLibrary` regenerada debe seguir teniendo los 8 ítems originales intactos, más los 2 nuevos). `mcp__godot__stop_project` después.

---

### Task 3: Integrar `GeneradorMundo` en `VoxelWorld.gd` y ajustar el spawn en `Main.gd`

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd` (`_ready()`, reemplazar `_generar_piso_inicial()`)
- Modify: `godot/scripts/Main.gd` (`_ready()`)

**Interfaces:**
- Consumes (de la Tarea 1): `GeneradorMundo._init(semilla: int)`, `GeneradorMundo.altura_en(x, z) -> int`, `GeneradorMundo.tipo_en_profundidad(profundidad) -> String`.
- Consumes (de la Tarea 2): tipos de bloque `"tierra"`/`"piedra"` ya disponibles en la `MeshLibrary`.
- Consumes (ya existente): `VoxelWorld.colocar_bloque(celda: Vector3i, tipo: String, por_jugador: bool = false) -> bool`.
- Produces: `VoxelWorld.generador: RefCounted` (instancia de `GeneradorMundo`, pública) — consumida por `Main.gd` para calcular el spawn.

- [ ] **Step 1: Reemplazar `_generar_piso_inicial()` por `_generar_terreno()` en `VoxelWorld.gd`**

Agregar, después de la línea `const TAMANO_CELDA := 1.0`:

```gdscript
const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")

const ANCHO_MUNDO := 200
const LARGO_MUNDO := 200
const PROFUNDIDAD_SUBSUELO := 32
const SEMILLA_MUNDO := 12345

var generador: RefCounted
```

Reemplazar el cuerpo completo de `_ready()`:

```gdscript
func _ready() -> void:
	cell_size = Vector3.ONE * TAMANO_CELDA
	_indexar_biblioteca()
	generador = GeneradorMundo.new(SEMILLA_MUNDO)
	_generar_terreno()
```

Y reemplazar la función `_generar_piso_inicial()` completa por:

```gdscript
## Genera el mundo una única vez al arrancar la escena: para cada columna
## (x, z) coloca la celda de superficie ("piso", reutilizando el bloque
## caminable existente) y el subsuelo debajo (tierra cerca de la
## superficie, piedra más profundo — ver GeneradorMundo.tipo_en_profundidad).
## Ninguna de estas celdas se marca colocado_por_jugador: el terreno del
## mundo nunca puede ser parte de un edificio declarado por el jugador.
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var tipo: String = generador.tipo_en_profundidad(profundidad)
				colocar_bloque(Vector3i(x, altura - profundidad, z), tipo)
```

- [ ] **Step 2: Ajustar el spawn del jugador en `Main.gd`**

Reemplazar el cuerpo de `_ready()` en `Main.gd`:

```gdscript
func _ready() -> void:
	jugador.mundo = mundo
	var altura_spawn: int = mundo.generador.altura_en(0, 0)
	jugador.position = Vector3(0, altura_spawn + 1, 0)
```

- [ ] **Step 3: Verificar `Main.tscn` vía Godot MCP**

Run: `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"`, luego `mcp__godot__get_debug_output`.
Expected: mismas advertencias ya conocidas, sin errores nuevos. La generación de 200×200 columnas (~1.3 millones de llamadas a `colocar_bloque()`) puede tardar varios segundos en cargar — es esperado (ver spec, "Manejo de Errores"), no es un fallo; esperar lo necesario antes de revisar la salida. `mcp__godot__stop_project` después.

- [ ] **Step 4: Verificar que el resto de la suite no se rompió**

Run, una escena a la vez (con `stop_project` entre cada una): `res://scenes/Test.tscn` (14 tests), `res://scenes/CiudadTest.tscn` (7 tests), `res://scenes/ZonificacionTest.tscn` (8 tests). Ninguna de estas usa `VoxelWorld` con la escena real de `Main.tscn` (instancian sus propios `VoxelWorld.new()` sin pasar por `_ready()` de escena, o no lo usan en absoluto), así que deben seguir pasando exactamente igual que antes — confirmar que ninguna quedó afectada por el cambio en `VoxelWorld.gd`.

---

### Task 4: Documentación de PoC 5 y verificación final

**Files:**
- Create: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`

**Interfaces:** ninguna — tarea de documentación y verificación, no produce símbolos de código.

- [ ] **Step 1: Correr toda la suite de verificación del repo**

Run:
```bash
python -m unittest discover -s website -p "test_*.py"
```
Expected: todos los tests pasan (sin relación con este cambio, pero es la verificación estándar del repo).

Confirmar (a partir de los resultados ya obtenidos en las Tareas 1-3): `Test.tscn` 14/14, `CiudadTest.tscn` 7/7, `ZonificacionTest.tscn` 8/8, `GeneradorMundoTest.tscn` 4/4, `Main.tscn` sin errores nuevos.

- [ ] **Step 2: Crear `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`**

```markdown
# **Documento Técnico de Desarrollo: PoC 5 - Mundo Procedural y Puestos de Recolección**

**Identificador del Módulo:** POC-05-MUNDO-PROCEDURAL

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** GDD Sección 11 ("Estilo Gráfico y Estrategia de Assets", bullet "Mundo Procedural Finito"), Sección 5 ("Nivelación de Terreno en Emplazamientos con Relieve"), Sección 3 ("Área de Acción de los Puestos de Recolección"), Sección 3.1 (categoría "Recolección" de la taxonomía de edificios).

**Dependencia Técnica:** Extiende `VoxelWorld.gd` (de `PoC_3`/`PoC_4`, ahora en `godot/`), reemplazando su piso plano placeholder por terreno real generado por ruido.

**✅ Verificado con Godot 4.7 (Steam) vía MCP:** `scenes/GeneradorMundoTest.tscn` corre y los 4 tests de `GeneradorMundoTest.gd` (determinismo, rango de alturas, semillas distintas, capas de subsuelo) pasan sin errores de `assert()`. `scenes/Main.tscn` carga sin errores nuevos con el mundo de 200×200 celdas generado por `GeneradorMundo` (relieve real en vez del piso plano de 11×11 anterior) y el jugador apareciendo sobre la altura real del terreno en `(0,0)`. `Test.tscn` (14 tests), `CiudadTest.tscn` (7 tests) y `ZonificacionTest.tscn` (8 tests) siguen pasando sin cambios.

Esta PoC cubre el **primer sub-proyecto de 3** de la Fase 3 del roadmap (GDD Sección 11 v3.14): Mundo Procedural Finito. Nivelación de Terreno sobre Relieve y Puestos de Recolección quedan para sub-proyectos posteriores (ambos dependen de este).

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de esta Pieza**

* **Mundo con relieve real:** reemplazar el piso plano de `VoxelWorld._generar_piso_inicial()` (11×11 celdas de `"piso"` en `y = -1`) por un mundo de 200×200 celdas con altura variable, generado una única vez al arrancar la escena — sin streaming ni chunks dinámicos (decisión ya tomada en el GDD).
* **Determinismo:** el relieve depende únicamente de una semilla — misma semilla, mismo mundo, siempre. Relevante a futuro para el balance multijugador (GDD Sección 10).
* **Bloques de subsuelo:** dos tipos nuevos, `"tierra"` (capa superior del subsuelo) y `"piedra"` (el resto), agregados a la `MeshLibrary` existente con el mismo patrón de color plano que los demás bloques.

### **1.2 Fuera de Alcance**

* **Profundidad real de ~300 bloques:** esta pieza usa `PROFUNDIDAD_SUBSUELO = 32` — escalar a la cifra final del GDD es optimización futura (200×200×300 ≈ 12 millones de celdas sería demasiado lento de generar de una sola vez sin más trabajo de rendimiento).
* **Biomas/variantes de superficie** (pasto, arena, nieve): evaluar cuando se aborde el sub-proyecto de Puestos de Recolección, si hace falta distinguir tipos de terreno para determinar qué se puede recolectar dónde.
* **Cuevas/cavidades subterráneas:** GDD Sección 8 ("Túneles y Cavernas"), Visión a futuro — depende de la Fase 6 (Combate) del roadmap.
* **Nivelación de terreno al construir sobre relieve** (GDD Sección 5): siguiente sub-proyecto de esta misma Fase — usará `GeneradorMundo.altura_en()`, pero no se implementa en esta pieza.
* **Puestos de Recolección + previsualización en HUD** (GDD Sección 3): tercer sub-proyecto de esta Fase, depende de esta pieza.
* **Semilla aleatoria real / selección de semilla al iniciar partida:** esta pieza usa una constante fija (`SEMILLA_MUNDO = 12345`) para desarrollo determinista.

---

## **FASE 2: PLANEACIÓN**

### **2.1 Arquitectura**

```
godot/
  scenes/
    GeneradorMundoTest.tscn    # Nueva escena de pruebas (sin gameplay)
    BlockLibrarySource.tscn     # + bloques "tierra" y "piedra"
    Main.tscn                    # Sin cambios de estructura (el spawn se ajusta en Main.gd)
  scripts/
    GeneradorMundo.gd            # Nuevo: mapa de alturas puro, sin nodos de escena
    GeneradorMundoTest.gd        # Nuevo: pruebas aisladas
    VoxelWorld.gd                 # _generar_piso_inicial() -> _generar_terreno()
    Main.gd                       # _ready(): spawn sobre la altura real del terreno
  assets/
    BlockLibrary.res              # Regenerado desde BlockLibrarySource.tscn
```

### **2.2 Decisión: Lógica de Terreno Aislada de `GridMap`**

`GeneradorMundo.gd` no depende de ningún nodo de escena — es una clase de datos pura (`RefCounted`) que, dada una semilla, calcula alturas. Esto sigue el mismo patrón ya establecido en el proyecto (`Ciudad.gd`, `Zonificacion.gd`): la lógica que puede probarse sin una escena corriendo, se prueba sin una escena corriendo. `VoxelWorld.gd` es la única pieza que traduce ese mapa de alturas a celdas reales de `GridMap`.

### **2.3 Por Qué `FastNoiseLite` y No una Librería de Terceros**

Se evaluó adoptar `godot_voxel` (Zylann's Voxel Tools), un motor de vóxeles maduro de código abierto — descartado explícitamente: es un motor de mundos infinitos con streaming de chunks y LOD, lo cual contradice la decisión ya tomada en el GDD de usar `GridMap` nativo y finito (sin streaming). Para generar un mapa de alturas por ruido, `FastNoiseLite` ya es nativo de Godot — no hace falta ninguna dependencia externa.

---

## **FASE 3: DESARROLLO**

### **3.1 Implementación**

El archivo completo vive en `godot/scripts/GeneradorMundo.gd`. Fragmento representativo:

```gdscript
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var t: float = (valor + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)
```

`VoxelWorld._generar_terreno()` recorre las 200×200 columnas del mundo, colocando la celda de superficie (`"piso"`, reutilizando el bloque caminable existente) y el subsuelo (`"tierra"`/`"piedra"` según `GeneradorMundo.tipo_en_profundidad()`) debajo. Ninguna de estas celdas se marca `colocado_por_jugador`, así que el terreno generado nunca puede formar parte de un edificio declarado (mismo comportamiento que el piso plano anterior).

### **3.2 Pruebas**

`GeneradorMundoTest.gd` verifica: determinismo (misma semilla → mismo mapa), rango de alturas (`[ALTURA_MINIMA, ALTURA_MAXIMA]` en un muestreo amplio, incluyendo coordenadas negativas), que semillas distintas produzcan mapas distintos, y la clasificación correcta de capas de subsuelo (`tierra` hasta `GROSOR_TIERRA`, `piedra` en adelante).

**Cómo ejecutarlos:** abrir `godot/project.godot` en Godot 4.7+, abrir `scenes/GeneradorMundoTest.tscn` y presionar **F6**. El panel Output debe mostrar los 4 tests y terminar con "Las 4 pruebas de GeneradorMundo pasaron correctamente".

### **3.3 Criterios de Aceptación Técnicos**

1. `altura_en(x, z)` es determinista: misma semilla y coordenadas siempre devuelven el mismo valor.
2. `altura_en(x, z)` nunca devuelve un valor fuera de `[ALTURA_MINIMA, ALTURA_MAXIMA]`.
3. El mundo generado en `Main.tscn` tiene relieve real (alturas variables), no un piso plano.
4. El jugador aparece de pie sobre el terreno real en `(0,0)`, ni flotando ni enterrado.
5. El terreno generado nunca se marca `colocado_por_jugador` — declarar un edificio nunca puede incluirlo accidentalmente.

### **3.4 Verificación Visual/Interactiva**

Verificado sin errores de carga corriendo `Main.tscn` vía MCP (headless) — el aspecto visual real del relieve (montañas/valles perceptibles, tiempo de carga aceptable en la práctica) queda pendiente de confirmación jugando en el editor real, mismo patrón que HUD/zonificación (ver `PoC_4/`).

---

## **Próximos Pasos de esta PoC**

> 1. ~~Mundo Procedural Finito (relieve real, determinista, sin streaming).~~ **Completado:** `GeneradorMundo.gd` + integración en `VoxelWorld.gd` — ver 2.1-3.1. **Pendiente:** confirmar visualmente el relieve y el tiempo de carga real jugando en el editor (ver 3.4); escalar `PROFUNDIDAD_SUBSUELO` hacia los ~300 bloques finales del GDD (optimización futura).
> 2. **Nivelación de Terreno en Emplazamientos con Relieve** (GDD Sección 5): nivelar un edificio al punto más alto de su huella, rellenar con tierra las celdas más bajas, y rechazar emplazamientos con pendiente excesiva — usa `GeneradorMundo.altura_en()`.
> 3. **Puestos de Recolección + previsualización en HUD** (GDD Sección 3): nueva categoría de edificio construible (categoría "Recolección" de la Sección 3.1), con área de acción por tipo y previsualización en vivo al emplazar.
```

- [ ] **Step 3: Actualizar el GDD (Sección 11, fila de Fase 3)**

En la fila de la Fase 3 de la tabla de Hoja de Ruta, marcar el primer sub-proyecto (Mundo Procedural Finito) como completo, siguiendo el mismo estilo que la fila de Fase 2 (mención de qué se verificó, con cifras de tests). Actualizar la línea `**Versión del Documento:**` con un changelog describiendo `GeneradorMundo.gd`, la integración en `VoxelWorld.gd`, y los bloques `tierra`/`piedra` nuevos.

- [ ] **Step 4: Resumen final para el usuario**

Confirmar en el chat: qué se implementó, qué se verificó (headless vía MCP + suite Python), y qué queda pendiente de confirmación visual jugando en el editor real. No hacer `git commit` — dejarlo listo para que el usuario lo pida explícitamente.
