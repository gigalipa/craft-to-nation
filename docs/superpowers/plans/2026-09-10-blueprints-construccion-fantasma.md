# Blueprints Reutilizables + Construcción Fantasma (Edificios) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Declarar un edificio guarda su `Blueprint` como plantilla reutilizable; el jugador puede emplazar copias en zonas compatibles como una "construcción fantasma" (bloques placeholder translúcidos con colisión) que se completa surtiéndola progresivamente, celda por celda, en un orden automático fijo.

**Architecture:** Dos autoloads nuevos de estado puro (`Blueprints.gd`, `Construccion.gd`, mismo patrón que `Recoleccion.gd`/`Zonificacion.gd`). `BlueprintValidator.gd` gana un campo `celdas_3d` (forma real sin aplanar) para poder reconstruir un blueprint en el mundo. `VoxelWorld.gd` gana el bloque placeholder `"fantasma"` y las funciones para iniciar/surtir una construcción. `CamaraCenital.gd` reemplaza su modo de nivelación standalone (tecla `B`) por un modo de colocación de blueprint que reutiliza las validaciones ya construidas para puestos periféricos. `Player.gd` gana la interacción de suministro, reutilizando el mecanismo de minar ya existente.

**Tech Stack:** Godot 4.7 (GDScript), GridMap + MeshLibrary, autoloads de estado puro, MCP de Godot (`mcp__godot__run_project`/`get_debug_output`/`stop_project`/`save_scene`/`export_mesh_library`) para verificación headless.

**Spec:** `docs/superpowers/specs/2026-09-10-blueprints-construccion-fantasma-design.md`

## Global Constraints

- Godot 4.7, GDScript con tabulaciones (no espacios).
- Comentarios y mensajes de consola en español, identificadores en español, siguiendo la convención ya establecida en el repo.
- Suministrar una celda fantasma es gratis — sin costo de recursos (mismo alcance reducido que minar/colocar/nivelar).
- Sin rotación de blueprints en esta versión.
- Un blueprint por `zona_permitida`, el más reciente sobrescribe al anterior — sin catálogo.
- El modo de nivelación standalone (tecla `B`, huella fija 5×5) se ELIMINA por completo — la tecla `B` pasa a activar el modo de colocación de blueprint.
- Cada tarea debe dejar `Test.tscn`/`RecoleccionTest.tscn`/`NiveladorTerrenoTest.tscn`/`ConstruccionTest.tscn`/`BlueprintsTest.tscn` pasando y `Main.tscn` cargando sin errores nuevos (en este entorno de desarrollo, los únicos warnings esperados son los 2 de "constante con el mismo nombre que una clase global" en `Player.gd:4`/`Main.gd:3` — si el entorno de ejecución es un worktree nuevo, también pueden aparecer temporalmente warnings de "invalid UID", ya documentados como inofensivos en sesiones anteriores).

---

### Task 1: `BlueprintValidator.gd` — extender el Blueprint con `celdas_3d`/`ancho`/`profundidad`

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: el dict que devuelve `estructura_a_blueprint()` gana 3 claves nuevas: `"celdas_3d"` (`Dictionary Vector3i -> String`, celdas normalizadas al origen SIN aplanar — conserva `"puerta_inferior"`/`"puerta_superior"`/`"cama_cabecera"`/`"cama_pies"` distintos, a diferencia de `"pisos"`), `"ancho"` (`int`), `"profundidad"` (`int`) — usadas por Task 4 (VoxelWorld) y Task 7 (CamaraCenital).

- [ ] **Step 1: Agregar `celdas_3d`/`ancho`/`profundidad` al `return` de `estructura_a_blueprint()`**

En `godot/scripts/BlueprintValidator.gd`, reemplazar el `return` final de la función:

```gdscript
	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
	}
```

por:

```gdscript
	# celdas_3d conserva la forma real completa (puerta_inferior/
	# puerta_superior, cama_cabecera/cama_pies, ventana, etc. en su altura
	# exacta), normalizada al mismo origen (x_min, y_min, z_min) que ya usa
	# el resto de la función — a diferencia de "pisos", que aplana estas
	# celdas a un template 2D por piso para poder validar reglas de
	# perímetro/esquina, esto es lo que permite RECONSTRUIR el edificio
	# exacto al emplazar una copia (ver Construccion.gd). Se construye a
	# partir de "celdas" (el parámetro original, SIN el remapeo de
	# puerta_superior->pared que ya sufrió "celdas_relevantes" más arriba).
	var celdas_3d: Dictionary = {}  # Vector3i (normalizado) -> tipo original
	for pos in celdas.keys():
		celdas_3d[pos - Vector3i(x_min, y_min, z_min)] = celdas[pos]

	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,       # x_max ya es (máximo - x_min), ver arriba
		"profundidad": z_max + 1,
	}
```

- [ ] **Step 2: Agregar el test (TEST 17) en `BlueprintValidatorTest.gd`**

En `godot/scripts/BlueprintValidatorTest.gd`, TEST 10 (buscar `"=== TEST 10: Declarar Edificio - Casa Real Multi-Nivel"`) ya deja calculadas las variables `estructura_casa` y `blueprint_casa` en el mismo scope de `ejecutar_pruebas()`. Insertar el nuevo test justo después de las 2 líneas de TEST 10 (`resultado = BlueprintValidator.validar_blueprint(blueprint_casa)` / `assert(resultado["valido"])`), antes de que empiece `"=== TEST 11"`:

```gdscript
	print("\n=== TEST 17: estructura_a_blueprint() conserva la forma 3D real en celdas_3d ===")
	# Misma casa de TEST 10: reconstruir celdas_3d normalizado a mano y
	# comparar contra la estructura original (también normalizada) — debe
	# conservar los tipos SIN aplanar (puerta_inferior/superior distintos,
	# no colapsados a "puerta"/"pared" como hace "pisos").
	assert(blueprint_casa["ancho"] == 4)
	assert(blueprint_casa["profundidad"] == 5)
	var celdas_3d_casa: Dictionary = blueprint_casa["celdas_3d"]
	assert(celdas_3d_casa.size() == estructura_casa.size())
	var y_min_casa: int = estructura_casa.keys()[0].y
	var x_min_casa: int = estructura_casa.keys()[0].x
	var z_min_casa: int = estructura_casa.keys()[0].z
	for pos in estructura_casa.keys():
		y_min_casa = min(y_min_casa, pos.y)
		x_min_casa = min(x_min_casa, pos.x)
		z_min_casa = min(z_min_casa, pos.z)
	for pos in estructura_casa.keys():
		var normalizado: Vector3i = pos - Vector3i(x_min_casa, y_min_casa, z_min_casa)
		assert(celdas_3d_casa.has(normalizado))
		assert(celdas_3d_casa[normalizado] == estructura_casa[pos])
	# La puerta principal debe seguir apareciendo como 2 celdas distintas
	# (puerta_inferior/puerta_superior en Y consecutiva), no colapsada.
	var puerta_inferior_normalizada := Vector3i(0, 1, 2) - Vector3i(x_min_casa, y_min_casa, z_min_casa)
	var puerta_superior_normalizada := puerta_inferior_normalizada + Vector3i(0, 1, 0)
	assert(celdas_3d_casa[puerta_inferior_normalizada] == "puerta_inferior")
	assert(celdas_3d_casa[puerta_superior_normalizada] == "puerta_superior")
	print("OK: celdas_3d conserva la forma real completa, ancho/profundidad correctos.")
```

Y actualizar la línea final del archivo de `"=== Las 16 pruebas de BlueprintValidator pasaron correctamente ==="` a `"=== Las 17 pruebas de BlueprintValidator pasaron correctamente ==="`. También actualizar el comentario de cabecera del archivo (líneas ~17-20, que enumera los tests) agregando una frase sobre el TEST 17, y `"16 tests"` a `"17 tests"`.

- [ ] **Step 3: Correr las pruebas y verificar que pasan**

`mcp__godot__run_project` (projectPath: `C:\Users\peraz\Projects\Misc\CityCraft\godot`, scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.
Esperado: `"=== Las 17 pruebas de BlueprintValidator pasaron correctamente ==="`, sin asserts fallidos, solo el warning preexistente de `BlueprintValidatorTest.gd:3`.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: BlueprintValidator conserva la forma 3D real (celdas_3d)"
```

---

### Task 2: Autoload `Blueprints.gd` — registro de plantillas reutilizables

**Files:**
- Create: `godot/scripts/Blueprints.gd`
- Create: `godot/scripts/BlueprintsTest.gd`
- Create: `godot/scenes/BlueprintsTest.tscn`
- Modify: `godot/project.godot`
- Modify: `godot/scripts/Player.gd`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `Blueprints.guardar(blueprint: Dictionary) -> void`, `Blueprints.obtener(zona_permitida: String) -> Dictionary` (autoload) — usado por Task 7 (`CamaraCenital.gd`).

- [ ] **Step 1: Crear `godot/scripts/Blueprints.gd`**

```gdscript
extends Node

## Autoload "Blueprints": registro de blueprints reutilizables, uno por
## zona_permitida (el último declarado de esa zona sobrescribe al
## anterior — sin catálogo ni selección manual todavía, ver spec:
## docs/superpowers/specs/2026-09-10-blueprints-construccion-fantasma-design.md).
## Mismo patrón que Recoleccion.gd/Zonificacion.gd: estado puro, sin nodos
## de escena, sin class_name (evita el bug de caché de clases globales).

var _por_zona: Dictionary = {}  # String (zona_permitida) -> Dictionary (blueprint)


func guardar(blueprint: Dictionary) -> void:
	_por_zona[blueprint["zona_permitida"]] = blueprint


func obtener(zona_permitida: String) -> Dictionary:
	return _por_zona.get(zona_permitida, {})
```

- [ ] **Step 2: Registrar el autoload en `godot/project.godot`**

En `godot/project.godot`, sección `[autoload]`, agregar una línea nueva junto a las existentes:

```
Ciudad="*res://scripts/Ciudad.gd"
Zonificacion="*res://scripts/Zonificacion.gd"
Recoleccion="*res://scripts/Recoleccion.gd"
Blueprints="*res://scripts/Blueprints.gd"
```

- [ ] **Step 3: Crear `godot/scripts/BlueprintsTest.gd`**

```gdscript
extends Node

## Pruebas aisladas de Blueprints.gd (mismo patrón que RecoleccionTest.gd).
## Corre esta escena (BlueprintsTest.tscn) con F6 en el editor de Godot y
## revisa el panel "Output": debe imprimir las pruebas y no debe lanzar
## ningún error de assert().


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: obtener() sin nada guardado devuelve {} ===")
	assert(Blueprints.obtener("residencial_investigacion") == {})

	print("\n=== TEST 2: guardar() registra el blueprint por su zona_permitida ===")
	var bp_a := {"zona_permitida": "residencial_investigacion", "nombre": "A"}
	Blueprints.guardar(bp_a)
	assert(Blueprints.obtener("residencial_investigacion") == bp_a)

	print("\n=== TEST 3: guardar() de la misma zona sobrescribe al anterior ===")
	var bp_b := {"zona_permitida": "residencial_investigacion", "nombre": "B"}
	Blueprints.guardar(bp_b)
	assert(Blueprints.obtener("residencial_investigacion") == bp_b)

	print("\n=== TEST 4: zonas distintas no se pisan entre sí ===")
	var bp_militar := {"zona_permitida": "fabricacion_militar", "nombre": "C"}
	Blueprints.guardar(bp_militar)
	assert(Blueprints.obtener("residencial_investigacion") == bp_b)
	assert(Blueprints.obtener("fabricacion_militar") == bp_militar)

	print("\n=== Las 4 pruebas de Blueprints pasaron correctamente ===")
```

- [ ] **Step 4: Crear la escena `godot/scenes/BlueprintsTest.tscn`**

Mismo patrón exacto que `RecoleccionTest.tscn` (un único nodo raíz `Node` con el script `BlueprintsTest.gd` adjunto). Usar `mcp__godot__create_scene` (projectPath: `C:\Users\peraz\Projects\Misc\CityCraft\godot`, la escena que cree) o, si el MCP no ofrece esa granularidad, crear el archivo `.tscn` a mano copiando la estructura de `godot/scenes/RecoleccionTest.tscn` y cambiando la referencia de script a `res://scripts/BlueprintsTest.gd`.

- [ ] **Step 5: Correr las pruebas y verificar que pasan**

`mcp__godot__run_project` (scene: `scenes/BlueprintsTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.
Esperado: `"=== Las 4 pruebas de Blueprints pasaron correctamente ==="`, sin asserts fallidos.

- [ ] **Step 6: Conectar la captura en `Player._declarar_edificio()`**

En `godot/scripts/Player.gd`, dentro de `_declarar_edificio()`, el bloque `if resultado["valido"]:` ya cuenta camas y llama a `Ciudad.registrar_edificio_residencial(total_camas)`. Agregar la línea `Blueprints.guardar(blueprint)` como la PRIMERA línea dentro de ese `if` (antes de contar camas):

```gdscript
	if resultado["valido"]:
		Blueprints.guardar(blueprint)
		var total_camas := 0
		for piso in blueprint["pisos"]:
			total_camas += (piso.get("camas", []) as Array).size()
		Ciudad.registrar_edificio_residencial(total_camas)
```

- [ ] **Step 7: Verificar que `Main.tscn`/`Test.tscn` siguen cargando sin errores**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 17 pruebas de `BlueprintValidator`, sin errores nuevos).
`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: solo los warnings preexistentes documentados en Global Constraints).

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/Blueprints.gd godot/scripts/BlueprintsTest.gd godot/scenes/BlueprintsTest.tscn godot/project.godot godot/scripts/Player.gd
git commit -m "feat: autoload Blueprints registra plantillas al declarar un edificio"
```

---

### Task 3: Autoload `Construccion.gd` — progreso de construcciones fantasma

**Files:**
- Create: `godot/scripts/Construccion.gd`
- Create: `godot/scripts/ConstruccionTest.gd`
- Create: `godot/scenes/ConstruccionTest.tscn`
- Modify: `godot/project.godot`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `Construccion.iniciar(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int`, `Construccion.construccion_de(celda: Vector3i) -> int`, `Construccion.avanzar(id: int) -> Dictionary` (`{"celda": Vector3i, "tipo": String, "completa": bool, "metadata": Dictionary, "orden": Array}`) — usado por Task 4 (`VoxelWorld.gd`).

- [ ] **Step 1: Crear `godot/scripts/Construccion.gd`**

```gdscript
extends Node

## Autoload "Construccion": progreso de construcciones fantasma en curso
## (edificios emplazados desde un blueprint, pendientes de ser surtidos con
## bloques — ver spec:
## docs/superpowers/specs/2026-09-10-blueprints-construccion-fantasma-design.md).
## Una construcción es una lista ORDENADA de celdas pendientes, cada una con
## su tipo real de destino — avanzar() siempre convierte la PRIMERA celda
## pendiente de la lista, sin importar cuál celda fantasma apuntó el
## jugador (ver Player.gd/VoxelWorld.gd): el orden es automático y fijo
## (relleno de tierra -> piso -> paredes/puertas/ventanas -> mobiliario),
## decidido al iniciar la construcción. Mismo patrón de estado puro que
## Recoleccion.gd/Zonificacion.gd/Blueprints.gd.

var _siguiente_id := 1
var _construcciones: Dictionary = {}  # int id -> {"orden": Array[Vector3i], "tipos": Dictionary, "indice": int, "metadata": Dictionary}
var _celda_a_construccion: Dictionary = {}  # Vector3i -> int id


## "orden": Array[Vector3i] ya en el orden exacto de conversión.
## "tipos": Dictionary Vector3i -> String, el tipo real al que se convierte
## cada celda de "orden" cuando le toque su turno.
## "metadata": dato opaco que el llamador necesita al completarse (ver
## avanzar()) — p. ej. para un edificio, {"blueprint": ..., "huella_xz": ...,
## "esquina": ..., "ancho": ..., "profundidad": ...}; {} si no hace falta
## nada. Construccion.gd nunca mira su contenido, solo lo guarda y lo
## devuelve intacto.
func iniciar(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	var id := _siguiente_id
	_siguiente_id += 1
	_construcciones[id] = {"orden": orden, "tipos": tipos, "indice": 0, "metadata": metadata}
	for celda in orden:
		_celda_a_construccion[celda] = id
	return id


func construccion_de(celda: Vector3i) -> int:
	return _celda_a_construccion.get(celda, -1)


## Convierte la SIGUIENTE celda pendiente de la construcción "id" (no
## necesariamente "celda_apuntada", que solo sirvió para identificar la
## construcción). Devuelve {"celda": Vector3i, "tipo": String,
## "completa": bool, "metadata": Dictionary, "orden": Array} —
## "completa" es true si esta era la última celda pendiente, momento en el
## que este autoload limpia su propio registro; "orden" es la lista
## COMPLETA de celdas de la construcción (siempre presente, útil para el
## llamador cuando completa=true — p. ej. para reemparejar puertas/camas,
## ver VoxelWorld.reemparejar_construccion()); "metadata" es la misma que
## se pasó a iniciar(), siempre presente. Falla (dict vacío) si "id" no
## existe o ya está completa.
func avanzar(id: int) -> Dictionary:
	if not _construcciones.has(id):
		return {}
	var datos: Dictionary = _construcciones[id]
	var indice: int = datos["indice"]
	var orden: Array = datos["orden"]
	if indice >= orden.size():
		return {}
	var celda: Vector3i = orden[indice]
	var tipo: String = datos["tipos"][celda]
	var metadata: Dictionary = datos["metadata"]
	datos["indice"] = indice + 1
	var completa: bool = datos["indice"] >= orden.size()
	if completa:
		for c in orden:
			_celda_a_construccion.erase(c)
		_construcciones.erase(id)
	return {"celda": celda, "tipo": tipo, "completa": completa, "metadata": metadata, "orden": orden}
```

- [ ] **Step 2: Registrar el autoload en `godot/project.godot`**

Agregar `Construccion="*res://scripts/Construccion.gd"` a la sección `[autoload]`, junto a los demás.

- [ ] **Step 3: Crear `godot/scripts/ConstruccionTest.gd`**

```gdscript
extends Node

## Pruebas aisladas de Construccion.gd (mismo patrón que
## RecoleccionTest.gd). Corre esta escena (ConstruccionTest.tscn) con F6 en
## el editor de Godot y revisa el panel "Output": debe imprimir las
## pruebas y no debe lanzar ningún error de assert().


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: iniciar() registra todas las celdas de la construcción ===")
	var orden: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	var tipos := {
		Vector3i(0, 0, 0): "tierra",
		Vector3i(1, 0, 0): "piso",
		Vector3i(2, 0, 0): "pared",
	}
	var id: int = Construccion.iniciar(orden, tipos)
	for celda in orden:
		assert(Construccion.construccion_de(celda) == id)
	assert(Construccion.construccion_de(Vector3i(99, 99, 99)) == -1)

	print("\n=== TEST 2: avanzar() convierte la PRIMERA celda pendiente, en orden ===")
	var r1: Dictionary = Construccion.avanzar(id)
	assert(r1["celda"] == Vector3i(0, 0, 0))
	assert(r1["tipo"] == "tierra")
	assert(not r1["completa"])
	var r2: Dictionary = Construccion.avanzar(id)
	assert(r2["celda"] == Vector3i(1, 0, 0))
	assert(r2["tipo"] == "piso")
	assert(not r2["completa"])

	print("\n=== TEST 3: la última celda marca completa=true y limpia el registro ===")
	var r3: Dictionary = Construccion.avanzar(id)
	assert(r3["celda"] == Vector3i(2, 0, 0))
	assert(r3["tipo"] == "pared")
	assert(r3["completa"])
	assert(r3["orden"] == orden)
	for celda in orden:
		assert(Construccion.construccion_de(celda) == -1)

	print("\n=== TEST 4: avanzar() sobre un id ya completado o inexistente devuelve {} ===")
	assert(Construccion.avanzar(id) == {})
	assert(Construccion.avanzar(9999) == {})

	print("\n=== TEST 5: metadata se guarda intacta y se devuelve en cada avanzar() ===")
	var metadata := {"blueprint": {"nombre": "X"}, "esquina": Vector2i(5, 5)}
	var id2: int = Construccion.iniciar([Vector3i(10, 0, 0)], {Vector3i(10, 0, 0): "piso"}, metadata)
	var r4: Dictionary = Construccion.avanzar(id2)
	assert(r4["metadata"] == metadata)
	assert(r4["completa"])

	print("\n=== Las 5 pruebas de Construccion pasaron correctamente ===")
```

- [ ] **Step 4: Crear la escena `godot/scenes/ConstruccionTest.tscn`**

Mismo patrón que `BlueprintsTest.tscn` (Task 2, Step 4) — nodo raíz `Node` con el script `ConstruccionTest.gd`.

- [ ] **Step 5: Correr las pruebas y verificar que pasan**

`mcp__godot__run_project` (scene: `scenes/ConstruccionTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.
Esperado: `"=== Las 5 pruebas de Construccion pasaron correctamente ==="`, sin asserts fallidos.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Construccion.gd godot/scripts/ConstruccionTest.gd godot/scenes/ConstruccionTest.tscn godot/project.godot
git commit -m "feat: autoload Construccion rastrea el progreso de construcciones fantasma"
```

---

### Task 4: `VoxelWorld.gd` — bloque `"fantasma"` + iniciar/surtir/reemparejar

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Modify (generado, no a mano): `godot/assets/BlockLibrary.res`
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `Construccion.iniciar()`/`Construccion.avanzar()` (Task 3), bloque `"fantasma"` en la MeshLibrary.
- Produces: `VoxelWorld.iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int`, `VoxelWorld.surtir_construccion(celda_fantasma: Vector3i) -> Dictionary` (`{"completa": bool, "metadata": Dictionary}` o `{}`) — usados por Task 5 (`Player.gd`) y Task 7 (`CamaraCenital.gd`).

- [ ] **Step 1: Agregar el bloque `"fantasma"` a la MeshLibrary**

En `godot/scenes/BlockLibrarySource.tscn`, siguiendo el mismo patrón que `"mina"`/`"puesto_caza"` (buscar el bloque de sub_resources de `"puesto_caza"` y agregar uno análogo justo después):

```
[sub_resource type="StandardMaterial3D" id="Mat_fantasma"]
transparency = 1
albedo_color = Color(0.6, 0.7, 1.0, 0.35)

[sub_resource type="BoxMesh" id="Mesh_fantasma"]
material = SubResource("Mat_fantasma")

[sub_resource type="BoxShape3D" id="Shape_fantasma"]
```

(`transparency = 1` es `BaseMaterial3D.TRANSPARENCY_ALPHA` — mismo valor que usan los overlays de `CamaraCenital.gd`/`ZonaOverlay.gd` vía código; aquí se fija directamente en el recurso `.tscn`, que es como ya lo hacen los demás bloques placeholder de esta escena.)

Y, en la sección de nodos (junto al nodo `"puesto_caza"`), agregar:

```
[node name="fantasma" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_fantasma")

[node name="CollisionShape3D" type="CollisionShape3D" parent="fantasma"]
shape = SubResource("Shape_fantasma")
```

- [ ] **Step 2: Guardar la escena y regenerar la MeshLibrary**

`mcp__godot__save_scene` (projectPath: `C:\Users\peraz\Projects\Misc\CityCraft\godot`, scenePath: `scenes/BlockLibrarySource.tscn`), luego `mcp__godot__export_mesh_library` (mismo projectPath, scenePath: `scenes/BlockLibrarySource.tscn`, outputPath: `assets/BlockLibrary.res`).

- [ ] **Step 3: Agregar `iniciar_construccion_fantasma()`, `surtir_construccion()` y `reemparejar_construccion()` a `VoxelWorld.gd`**

En `godot/scripts/VoxelWorld.gd`, inmediatamente después de la función `eliminar_follaje()` (que termina en `arboles.eliminar_celda(id, celda)`), agregar:

```gdscript
## Coloca el bloque placeholder "fantasma" en cada celda de "orden" (en el
## mundo real, con colisión) y registra la construcción en Construccion.gd.
## "tipos" mapea cada celda de "orden" a su tipo real de destino, "metadata"
## se guarda intacta para cuando la construcción se complete (ver
## Construccion.iniciar()). No marca colocado_por_jugador todavía: estas
## celdas no son estructura real hasta que se conviertan (ver
## surtir_construccion()).
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	return Construccion.iniciar(orden, tipos, metadata)


## Convierte la siguiente celda pendiente de la construcción a la que
## pertenece "celda_fantasma" (que puede ser cualquier celda fantasma de esa
## construcción, no necesariamente la que se va a convertir — ver
## Construccion.avanzar()). Devuelve {} si no había ninguna construcción en
## esa celda; si no, {"completa": bool, "metadata": Dictionary} — el
## llamador (Player.gd) decide qué hacer al completarse (registrar en
## Ciudad, etc.) usando "metadata". Al completarse, reempareja puertas/camas
## de la construcción antes de devolver (ver reemparejar_construccion()).
func surtir_construccion(celda_fantasma: Vector3i) -> Dictionary:
	var id: int = Construccion.construccion_de(celda_fantasma)
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


## Reconstruye "pareja" para las celdas de una construcción recién
## completada (puertas y camas colocadas por surtir_construccion() una a
## una, sin pasar por colocar_puerta()/colocar_cama(), así que no registran
## "pareja" automáticamente al construirse). Empareja cada "puerta_inferior"
## con la celda justo encima si es "puerta_superior", y cada
## "cama_cabecera" con un vecino horizontal (X o Z) que sea "cama_pies" —
## mismo criterio geométrico que colocar_puerta()/colocar_cama() ya usan al
## construir a mano. Sin esto, minar una puerta/cama de una construcción
## terminada no borraría su mitad opuesta (ver minar_bloque()).
func reemparejar_construccion(celdas: Array) -> void:
	for celda in celdas:
		var tipo: String = obtener_tipo(celda)
		if tipo == "puerta_inferior":
			var arriba: Vector3i = celda + Vector3i(0, 1, 0)
			if obtener_tipo(arriba) == "puerta_superior":
				pareja[celda] = arriba
				pareja[arriba] = celda
		elif tipo == "cama_cabecera":
			for direccion in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var vecino: Vector3i = celda + direccion
				if obtener_tipo(vecino) == "cama_pies":
					pareja[celda] = vecino
					pareja[vecino] = celda
					break
```

- [ ] **Step 4: Agregar el test (TEST 18) en `BlueprintValidatorTest.gd`**

Antes de la línea final `print("\n=== Las 17 pruebas de BlueprintValidator pasaron correctamente ===")`, insertar:

```gdscript
	print("\n=== TEST 18: iniciar_construccion_fantasma()/surtir_construccion() ===")
	const OX8 := 600
	for dx in range(2):
		for dz in range(2):
			mundo.colocar_bloque(Vector3i(OX8 + dx, 0, OX8 + dz), "piso")
	var orden_18: Array[Vector3i] = [
		Vector3i(OX8, 1, OX8), Vector3i(OX8 + 1, 1, OX8),
	]
	var tipos_18 := {
		Vector3i(OX8, 1, OX8): "puerta_inferior",
		Vector3i(OX8 + 1, 1, OX8): "pared",
	}
	mundo.colocar_bloque(Vector3i(OX8, 2, OX8), "puerta_superior")  # ya real, no fantasma: completa el par de la puerta
	mundo.iniciar_construccion_fantasma(orden_18, tipos_18)
	assert(mundo.obtener_tipo(Vector3i(OX8, 1, OX8)) == "fantasma")
	assert(mundo.obtener_tipo(Vector3i(OX8 + 1, 1, OX8)) == "fantasma")

	var s1: Dictionary = mundo.surtir_construccion(Vector3i(OX8 + 1, 1, OX8))  # apunta a la 2da, pero convierte la 1ra (orden fijo)
	assert(mundo.obtener_tipo(Vector3i(OX8, 1, OX8)) == "puerta_inferior")
	assert(mundo.obtener_tipo(Vector3i(OX8 + 1, 1, OX8)) == "fantasma")
	assert(not s1.get("completa", true))

	var s2: Dictionary = mundo.surtir_construccion(Vector3i(OX8 + 1, 1, OX8))
	assert(mundo.obtener_tipo(Vector3i(OX8 + 1, 1, OX8)) == "pared")
	assert(s2["completa"])
	assert(mundo.pareja.get(Vector3i(OX8, 1, OX8)) == Vector3i(OX8, 2, OX8))  # reemparejada al completarse
	assert(mundo.pareja.get(Vector3i(OX8, 2, OX8)) == Vector3i(OX8, 1, OX8))

	var s3: Dictionary = mundo.surtir_construccion(Vector3i(OX8, 1, OX8))  # ya no es una celda fantasma
	assert(s3.is_empty())
	print("OK: la construcción fantasma se surte en orden fijo, se reempareja al completarse, y no puede volver a surtirse.")
```

Actualizar la línea final del archivo a `"=== Las 18 pruebas de BlueprintValidator pasaron correctamente ==="` (y el comentario de cabecera del archivo, igual que en Task 1).

- [ ] **Step 5: Correr las pruebas y verificar que pasan**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.
Esperado: `"=== Las 18 pruebas de BlueprintValidator pasaron correctamente ==="`, sin asserts fallidos.

También correr `scenes/Main.tscn` de la misma forma y confirmar que sigue cargando sin errores nuevos (el bloque `"fantasma"` no afecta nada existente, solo confirma que la `MeshLibrary` sigue siendo válida).

- [ ] **Step 6: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: VoxelWorld coloca y surte construcciones fantasma"
```

---

### Task 5: `Player.gd` — interacción de suministro

**Files:**
- Modify: `godot/scripts/Player.gd`

**Interfaces:**
- Consumes: `mundo.obtener_tipo()`, `mundo.surtir_construccion(celda) -> Dictionary` (Task 4).
- Produces: `Player._completar_construccion(metadata: Dictionary) -> void` — función privada, no consumida por otro archivo (la llama esta misma tarea).

- [ ] **Step 1: Agregar el chequeo de celda fantasma en `_minar()`**

En `godot/scripts/Player.gd`, la función `_minar()` es:

```gdscript
func _minar() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	if mundo.TIPOS_ARBOL.has(mundo.obtener_tipo(celda)):
		mundo.talar_bloque_de_arbol(celda, DANO_TALA)
	else:
		mundo.minar_bloque(celda)
```

Reemplazarla por:

```gdscript
func _minar() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	if mundo.obtener_tipo(celda) == "fantasma":
		var resultado: Dictionary = mundo.surtir_construccion(celda)
		if resultado.get("completa", false):
			_completar_construccion(resultado["metadata"])
	elif mundo.TIPOS_ARBOL.has(mundo.obtener_tipo(celda)):
		mundo.talar_bloque_de_arbol(celda, DANO_TALA)
	else:
		mundo.minar_bloque(celda)
```

- [ ] **Step 2: Agregar `_completar_construccion()`**

Al final de `godot/scripts/Player.gd`, agregar:

```gdscript
## Se llama cuando VoxelWorld.surtir_construccion() indica que una
## construcción fantasma quedó completa. "metadata" es la que se pasó a
## VoxelWorld.iniciar_construccion_fantasma() al colocarla (ver
## CamaraCenital._procesar_clic_blueprint()) — hoy siempre un edificio; un
## puesto periférico completado (sub-proyecto B, futuro) no pasaría por
## este registro de Ciudad/Zonificacion (metadata vacía o de otra forma).
func _completar_construccion(metadata: Dictionary) -> void:
	if metadata.is_empty():
		return
	var blueprint: Dictionary = metadata["blueprint"]
	var total_camas := 0
	for piso in blueprint["pisos"]:
		total_camas += (piso.get("camas", []) as Array).size()
	Ciudad.registrar_edificio_residencial(total_camas)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)

	Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])
```

- [ ] **Step 3: Verificar que `Main.tscn`/`Test.tscn` siguen cargando sin errores**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 18 pruebas, sin errores nuevos — este cambio no toca ninguna función probada por `BlueprintValidatorTest.gd`, es solo una verificación de que no se rompió el parseo).
`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: solo los warnings preexistentes).

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/Player.gd
git commit -m "feat: Player suministra construcciones fantasma reutilizando minar()"
```

---

### Task 6: `CamaraCenital.gd` — eliminar la nivelación standalone, generalizar `_huella_choca_con_otro_puesto`

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes: `Construccion.construccion_de()` (Task 3).
- Produces: `_huella_choca_con_otro_puesto(esquina: Vector2i, ancho: int, alto: int) -> bool` — firma nueva (antes solo tomaba `esquina` y leía `_ancho_puesto_activo`/`_alto_puesto_activo`), usada por Task 7.

Este archivo no tiene pruebas automatizadas (lógica de cámara/input) — la verificación es headless (sin errores nuevos al cargar) más una nota de verificación manual al final del plan.

- [ ] **Step 1: Eliminar el modo de nivelación standalone por completo**

En `godot/scripts/CamaraCenital.gd`, eliminar las siguientes constantes, variables y funciones (todas relacionadas ÚNICA y EXCLUSIVAMENTE con el modo de nivelación manual que este cambio retira):

Eliminar las 2 constantes:
```gdscript
const COLOR_HUELLA_VALIDA := Color(0.2, 1.0, 0.3, 0.4)
const COLOR_HUELLA_INVALIDA := Color(1.0, 0.2, 0.2, 0.4)
```

Eliminar el bloque completo (constante + comentario):
```gdscript
## Sigue usada SOLO por la huella fantasma del modo de nivelación manual
## (_actualizar_huella_fantasma(), sin cambios en esta tarea) — el modo de
## colocación de puestos ya NO la usa, calcula su propio centrado con
## _ancho_puesto_activo/_alto_puesto_activo (ver _actualizar_previsualizacion_puesto()).
const MITAD_HUELLA := 2  # (NiveladorTerreno.TAMANO_HUELLA - 1) / 2, para una huella de 5x5
```

Eliminar el bloque completo (comentario + 2 variables):
```gdscript
## Modo de nivelación de terreno (tecla `B`): un recuadro fantasma de
## NiveladorTerreno.TAMANO_HUELLA x TAMANO_HUELLA sigue la celda bajo el
## cursor (esa celda es el CENTRO de la huella, no la esquina) hasta que el
## jugador hace clic para confirmar. Un mini-plano por celda, cada uno seguio
## la altura real de su propia celda (igual que ZonaOverlay) — un solo plano
## grande a la altura máxima quedaba enterrado bajo el relieve en las
## celdas más bajas de la huella.
var nivelador: RefCounted
var nivelador_puesto: RefCounted
var modo_nivelacion := false
var _huella_fantasma: Array[MeshInstance3D] = []
```

por (conserva `nivelador`/`nivelador_puesto`, que Task 7 sigue necesitando — solo se retira `modo_nivelacion`/`_huella_fantasma`, exclusivos del modo eliminado):

```gdscript
var nivelador: RefCounted
var nivelador_puesto: RefCounted
```

En `_ready()`, eliminar la línea `_crear_huella_fantasma()`.

Eliminar la función completa `_crear_huella_fantasma()` (la que crea `NiveladorTerreno.TAMANO_HUELLA * NiveladorTerreno.TAMANO_HUELLA` planos).

Eliminar la función completa `_actualizar_huella_fantasma()`.

Eliminar la función completa `_alternar_modo_nivelacion()`.

Eliminar la función completa `_salir_de_modo_nivelacion()`.

Eliminar la función completa `_mostrar_huella_fantasma()`.

Eliminar la función completa `_procesar_clic_nivelacion()` (la última función del archivo).

En `_process()`, reemplazar las 2 apariciones de:
```gdscript
		if modo_nivelacion:
			_actualizar_huella_fantasma()
		elif modo_colocar_puesto:
```
por (se agrega el nuevo modo de blueprint, ver Task 7 — por ahora, en esta tarea, solo retirar la rama de nivelación):
```gdscript
		if modo_colocar_puesto:
```

En `_unhandled_input()`, eliminar la línea `elif tecla.pressed and tecla.keycode == KEY_B: _alternar_modo_nivelacion()` (Task 7 le da a `B` un nuevo significado) y, en el bloque de clic izquierdo, eliminar la rama `if modo_nivelacion: _procesar_clic_nivelacion(boton.position)`:
```gdscript
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_nivelacion:
				_procesar_clic_nivelacion(boton.position)
			elif modo_colocar_puesto:
				_procesar_clic_puesto(boton.position)
			else:
				_procesar_clic(boton.position)
```
queda:
```gdscript
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_colocar_puesto:
				_procesar_clic_puesto(boton.position)
			else:
				_procesar_clic(boton.position)
```

En `_alternar_modo_colocar_puesto()`, eliminar el chequeo de exclusión mutua con nivelación:
```gdscript
		# Ver el comentario equivalente en _alternar_modo_nivelacion(): los modos
		# son mutuamente excluyentes.
		if modo_nivelacion:
			_salir_de_modo_nivelacion()
```
(se restituye en Task 7 con el nuevo modo de blueprint en su lugar).

En `salir_de_todos_los_modos()`, eliminar la línea `_salir_de_modo_nivelacion()`:
```gdscript
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_nivelacion()
	_salir_de_modo_colocar_puesto()
```
queda (temporalmente, hasta que Task 7 agregue la salida del modo blueprint):
```gdscript
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_colocar_puesto()
```

- [ ] **Step 2: Corregir el comentario duplicado/mal ubicado sobre `_huella_choca_con_otro_puesto`**

El archivo tiene hoy este bloque (un comentario de `_huella_choca_con_otro_puesto` seguido, sin la función real en medio, por el comentario de `_huella_tiene_esquina_en_tierra`, y la función `_huella_choca_con_otro_puesto` real aparece MÁS ABAJO sin su propio comentario):

```gdscript
## true si algún punto de la huella (ancho x alto activos, esquina
## "esquina") cae dentro de un puesto ya colocado — recorre la huella
## completa contra Recoleccion.celda_dentro_de_algun_puesto() (no basta
## revisar solo las esquinas, sería incorrecto para un rectángulo genérico).
## true si la huella (esquina, ancho x alto) tiene AL MENOS una esquina en
## tierra firme (no sobre agua) — evita construir puestos enteramente
## flotando en medio de un lago. Basta con revisar las 4 esquinas reales de
## la huella, no la huella completa: alcanza con una esquina firme para
## anclar la construcción, y el resto del agua bajo la huella se drena al
## confirmar (ver VoxelWorld.drenar_agua()).
func _huella_tiene_esquina_en_tierra(esquina: Vector2i, ancho: int, alto: int) -> bool:
	var esquinas := [
		esquina,
		Vector2i(esquina.x + ancho - 1, esquina.y),
		Vector2i(esquina.x, esquina.y + alto - 1),
		Vector2i(esquina.x + ancho - 1, esquina.y + alto - 1),
	]
	for e in esquinas:
		if mundo.obtener_tipo(Vector3i(e.x, mundo.altura_en(e.x, e.y), e.y)) != "agua":
			return true
	return false


func _huella_choca_con_otro_puesto(esquina: Vector2i) -> bool:
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			if Recoleccion.celda_dentro_de_algun_puesto(Vector2i(esquina.x + dx, esquina.y + dz)):
				return true
	return false
```

Reemplazar TODO ese bloque (ambas funciones completas, con el comentario arreglado) por:

```gdscript
## true si la huella (esquina, ancho x alto) tiene AL MENOS una esquina en
## tierra firme (no sobre agua) — evita construir puestos enteramente
## flotando en medio de un lago. Basta con revisar las 4 esquinas reales de
## la huella, no la huella completa: alcanza con una esquina firme para
## anclar la construcción, y el resto del agua bajo la huella se drena al
## confirmar (ver VoxelWorld.drenar_agua()).
func _huella_tiene_esquina_en_tierra(esquina: Vector2i, ancho: int, alto: int) -> bool:
	var esquinas := [
		esquina,
		Vector2i(esquina.x + ancho - 1, esquina.y),
		Vector2i(esquina.x, esquina.y + alto - 1),
		Vector2i(esquina.x + ancho - 1, esquina.y + alto - 1),
	]
	for e in esquinas:
		if mundo.obtener_tipo(Vector3i(e.x, mundo.altura_en(e.x, e.y), e.y)) != "agua":
			return true
	return false


## true si algún punto de la huella (esquina, ancho x alto) cae dentro de
## un puesto ya colocado (Recoleccion.puestos, cualquier tipo — mina, caza/
## recolección, o "blueprint") o de una construcción fantasma activa (una
## celda todavía en curso de ser surtida, ver Construccion.gd) — recorre la
## huella completa, no basta revisar solo las esquinas, sería incorrecto
## para un rectángulo genérico. Antes tomaba solo "esquina" y leía
## _ancho_puesto_activo/_alto_puesto_activo — ahora recibe ancho/alto
## explícitos para poder reutilizarse también desde el modo de colocación
## de blueprint (Task 7), que tiene su propio ancho/alto.
func _huella_choca_con_otro_puesto(esquina: Vector2i, ancho: int, alto: int) -> bool:
	for dx in range(ancho):
		for dz in range(alto):
			var xz := Vector2i(esquina.x + dx, esquina.y + dz)
			if Recoleccion.celda_dentro_de_algun_puesto(xz):
				return true
			var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
			if Construccion.construccion_de(celda_superficie) != -1:
				return true
	return false
```

- [ ] **Step 3: Actualizar los 2 call sites existentes de `_huella_choca_con_otro_puesto`**

En `_actualizar_previsualizacion_puesto()`:
```gdscript
	var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina) \
			and _huella_tiene_esquina_en_tierra(esquina, _ancho_puesto_activo, _alto_puesto_activo)
```
cambiar a:
```gdscript
	var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, _ancho_puesto_activo, _alto_puesto_activo) \
			and _huella_tiene_esquina_en_tierra(esquina, _ancho_puesto_activo, _alto_puesto_activo)
```

En `_procesar_clic_puesto()`:
```gdscript
	if _huella_choca_con_otro_puesto(esquina):
```
cambiar a:
```gdscript
	if _huella_choca_con_otro_puesto(esquina, _ancho_puesto_activo, _alto_puesto_activo):
```

- [ ] **Step 4: Actualizar el comentario de cabecera del archivo**

Reemplazar la línea `## Modo de nivelación de terreno con tecla \`B\` (ver GDD Sección 5) — sin` y la línea siguiente `## selección de tropas por arrastre todavía, eso sigue siendo PoC 6/Fase 4.` por:

```gdscript
## - Colocación de blueprint (tecla `B`, ver Task 7 de este plan) reemplaza
##   la antigua nivelación standalone — sin selección de tropas por
##   arrastre todavía, eso sigue siendo PoC 6/Fase 4.
```

- [ ] **Step 5: Verificar que `Main.tscn`/`Test.tscn` siguen cargando sin errores**

En este punto del plan, la tecla `B` no hace nada todavía (su handler se eliminó en el Step 1 y Task 7 lo restituye) — eso es esperado y temporal, no un bug de esta tarea.

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 18 pruebas, sin errores nuevos).
`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: sin errores de GDScript — ningún "Invalid call"/"Nonexistent function"/parse error; solo los warnings preexistentes).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "refactor: eliminar la nivelación standalone, generalizar huella_choca_con_otro_puesto"
```

---

### Task 7: `CamaraCenital.gd` — modo de colocación de blueprint (tecla `B`)

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes: `Blueprints.obtener()` (Task 2), `mundo.iniciar_construccion_fantasma()` (Task 4), `_huella_tiene_esquina_en_tierra()`/`_huella_choca_con_otro_puesto()` (Task 6), `nivelador_puesto`/`mundo.drenar_agua()`/`mundo.verificar_huella_libre()`/`mundo.eliminar_follaje()` (ya existentes).
- Produces: nada consumido por otro archivo — es la integración final de este plan.

Este archivo no tiene pruebas automatizadas — verificación headless más nota de verificación manual al final del plan.

- [ ] **Step 1: Agregar el estado del modo blueprint**

En `godot/scripts/CamaraCenital.gd`, junto a las demás variables de modo (después del bloque de `_area_accion`), agregar:

```gdscript
## Modo de colocación de blueprint (tecla `B`) — reemplaza la antigua
## nivelación standalone. Sigue el mismo patrón visual que el modo de
## colocación de puestos (huella verde/rojo), pero el TAMAÑO de la huella
## varía según el blueprint activo (blueprint["ancho"]/["profundidad"]), así
## que el pool de planos se crea de nuevo cada vez que se activa el modo
## (_crear_huella_blueprint()) en vez de tener un tamaño fijo — solo existe
## un blueprint (residencial) por ahora, activarse no es un evento
## frecuente por fotograma.
var modo_colocar_blueprint := false
var _blueprint_activo: Dictionary = {}
var _huella_blueprint: Array[MeshInstance3D] = []
```

- [ ] **Step 2: Agregar la creación/destrucción del pool de la huella de blueprint**

Después de la función `_crear_area_accion()`, agregar:

```gdscript
## (Re)crea el pool de planos fantasma para la huella del blueprint activo,
## de tamaño EXACTO ancho x alto (a diferencia de _crear_huella_puesto(),
## que usa un pool fijo reutilizado por varios tipos — aquí solo hay un
## blueprint activo a la vez, así que no hace falta sobredimensionar).
## Libera los planos de una activación anterior antes de crear los nuevos.
func _crear_huella_blueprint(ancho: int, alto: int) -> void:
	for plano in _huella_blueprint:
		plano.queue_free()
	_huella_blueprint.clear()

	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	for i in range(ancho * alto):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_PUESTO_VALIDO
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = true
		add_child(plano)
		_huella_blueprint.append(plano)


func _mostrar_huella_blueprint(visible_ahora: bool) -> void:
	for plano in _huella_blueprint:
		plano.visible = visible_ahora
```

- [ ] **Step 3: Agregar la clasificación/orden de celdas de construcción**

Después de `_huella_choca_con_otro_puesto()` (Task 6), agregar:

```gdscript
## Grupos de conversión, en el orden en que se surten (ver spec: relleno de
## tierra -> piso -> paredes/puertas/ventanas -> mobiliario). El relleno de
## tierra no aparece aquí: se calcula y antepone aparte en
## _procesar_clic_blueprint(), antes de estas celdas del blueprint mismo.
const ORDEN_GRUPOS_CONSTRUCCION := [
	["piso"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["cama_cabecera", "cama_pies", "baul"],
]


## Devuelve las celdas de "celdas_mundo" (Vector3i real -> tipo) ordenadas
## para conversión: por grupo (ver ORDEN_GRUPOS_CONSTRUCCION, en ese orden),
## y dentro de cada grupo por (y, x, z) para que el orden sea determinista
## y no dependa del orden de iteración del Dictionary de Godot.
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

- [ ] **Step 4: Agregar la previsualización del blueprint**

Después de `_actualizar_previsualizacion_puesto()`, agregar:

```gdscript
## Recalcula la posición/color de la huella del blueprint activo según la
## celda bajo el cursor (esa celda es su CENTRO, igual que los puestos).
## A diferencia de los puestos (regla: fuera de la zona de influencia),
## aquí la regla de zona es la opuesta: la celda debe caer DENTRO de una
## zona pintada que coincida con blueprint["zona_permitida"].
func _actualizar_previsualizacion_blueprint() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	var zona_correcta: bool = Zonificacion.consultar_zona(centro) == _blueprint_activo["zona_permitida"]
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, ancho, alto)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, ancho, alto)
	var valida: bool = zona_correcta and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, ancho, alto) \
			and _huella_tiene_esquina_en_tierra(esquina, ancho, alto)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var i := 0
	for dx in range(ancho):
		for dz in range(alto):
			var x: int = esquina.x + dx
			var z: int = esquina.y + dz
			var altura_celda: int = mundo.altura_en(x, z, true)
			var plano: MeshInstance3D = _huella_blueprint[i]
			var material: StandardMaterial3D = plano.material_override
			material.albedo_color = color
			plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE, z + DESF)
			i += 1
```

- [ ] **Step 5: Agregar activar/salir del modo blueprint**

Después de `_rotar_huella_puesto()`, agregar:

```gdscript
## Activa/cancela el modo de colocación de blueprint (toggle simple, un solo
## blueprint posible a la vez — a diferencia de _alternar_modo_colocar_puesto(),
## no recibe tipo/ancho/alto porque hoy solo existe un blueprint guardado,
## el de "residencial_investigacion"). Si no hay ningún blueprint guardado
## todavía, avisa y no entra al modo.
func _alternar_modo_colocar_blueprint() -> void:
	if modo_colocar_blueprint:
		_salir_de_modo_colocar_blueprint()
		print("Modo colocar blueprint cancelado.")
		return
	var blueprint: Dictionary = Blueprints.obtener("residencial_investigacion")
	if blueprint.is_empty():
		print("No hay ningún blueprint guardado todavía — declara un edificio primero.")
		return
	if modo_colocar_puesto:
		_salir_de_modo_colocar_puesto()
	_blueprint_activo = blueprint
	_crear_huella_blueprint(blueprint["ancho"], blueprint["profundidad"])
	modo_colocar_blueprint = true
	print("Modo colocar blueprint activo: haz clic dentro de una zona residencial para confirmar (B de nuevo para cancelar).")


func _salir_de_modo_colocar_blueprint() -> void:
	modo_colocar_blueprint = false
	_mostrar_huella_blueprint(false)
	_blueprint_activo = {}
```

- [ ] **Step 6: Agregar la confirmación (crear la construcción fantasma)**

Después de `_procesar_clic_puesto()`, agregar:

```gdscript
## Confirma la colocación del blueprint activo en la celda bajo el cursor
## si las 5 validaciones (zona correcta, relieve, huella libre, sin choque,
## esquina en tierra firme) pasan — si no, imprime el motivo y PERMANECE en
## modo colocar-blueprint. A diferencia de _procesar_clic_puesto() (que
## coloca el marcador de inmediato), esto NO completa nada: drena el agua,
## calcula el relleno de nivelación, reubica blueprint["celdas_3d"] en el
## mundo, arma el orden de conversión (relleno de tierra primero, luego
## piso/paredes-puertas-ventanas/mobiliario — ver _ordenar_celdas_construccion())
## e inicia la construcción fantasma (VoxelWorld.iniciar_construccion_fantasma()) —
## la finalización real ocurre después, celda por celda, cuando el jugador
## la surte (ver Player._minar()/_completar_construccion()).
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	if Zonificacion.consultar_zona(centro) != _blueprint_activo["zona_permitida"]:
		print("Colocación rechazada: esta zona no acepta este blueprint.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, ancho, alto):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, ancho, alto)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, ancho, alto):
		print("Colocación rechazada: la huella choca con un puesto o construcción ya colocada.")
		return
	if not _huella_tiene_esquina_en_tierra(esquina, ancho, alto):
		print("Colocación rechazada: la huella necesita al menos una esquina sobre tierra firme.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for dx in range(ancho):
		for dz in range(alto):
			total_drenado += mundo.drenar_agua(esquina.x + dx, esquina.y + dz)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, ancho, alto)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, ancho, alto)
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
	mundo.iniciar_construccion_fantasma(orden, tipos, metadata)
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()
```

- [ ] **Step 7: Conectar la tecla `B`, el clic izquierdo, y las salidas de modo**

En `_unhandled_input()`, en el bloque de teclas, agregar de nuevo el handler de `B` (con su nuevo significado):

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_colocar_blueprint()
```

(agregar como una rama `elif` más, en el mismo bloque `if event is InputEventKey:` donde están `KEY_1`/`KEY_2`/`KEY_M`/`KEY_H`).

En el bloque de clic izquierdo:
```gdscript
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_colocar_puesto:
				_procesar_clic_puesto(boton.position)
			else:
				_procesar_clic(boton.position)
```
cambiar a:
```gdscript
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_colocar_blueprint:
				_procesar_clic_blueprint(boton.position)
			elif modo_colocar_puesto:
				_procesar_clic_puesto(boton.position)
			else:
				_procesar_clic(boton.position)
```

En `_process()`, las 2 apariciones de:
```gdscript
		if modo_colocar_puesto:
			_actualizar_previsualizacion_puesto()
```
cambiar a:
```gdscript
		if modo_colocar_blueprint:
			_actualizar_previsualizacion_blueprint()
		elif modo_colocar_puesto:
			_actualizar_previsualizacion_puesto()
```

En `_alternar_modo_colocar_puesto()`, restituir la exclusión mutua (ahora con blueprint en vez de nivelación):
```gdscript
	# Ver el comentario equivalente en _alternar_modo_colocar_blueprint(): los
	# modos son mutuamente excluyentes.
	if modo_colocar_blueprint:
		_salir_de_modo_colocar_blueprint()
```
agregarlo justo antes de `hud.ocultar_ficha_mina()` dentro de `_alternar_modo_colocar_puesto()`.

En `salir_de_todos_los_modos()`:
```gdscript
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_colocar_puesto()
```
cambiar a:
```gdscript
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_colocar_blueprint()
	_salir_de_modo_colocar_puesto()
```

- [ ] **Step 8: Verificar que `Main.tscn`/`Test.tscn` cargan sin errores**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 18 pruebas, sin errores nuevos).
`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: sin "Invalid call"/"Nonexistent function"/parse error nuevo; solo los warnings preexistentes).

- [ ] **Step 9: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: modo de colocación de blueprint en la cámara cenital (tecla B)"
```

---

### Task 8: Documentación y verificación final

**Files:**
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`

**Interfaces:**
- Consumes: nada.
- Produces: nada.

- [ ] **Step 1: Agregar una sección nueva al final del documento**

En `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`, al final del archivo (después de la última sección existente), agregar:

```markdown
---

## Blueprints Reutilizables + Construcción Fantasma (sub-proyecto nuevo, sin número de PoC asignado todavía)

No depende del terreno procedural — vive en este documento por continuidad de sesión, pero podría reubicarse a su propia PoC más adelante. Ver spec: `docs/superpowers/specs/2026-09-10-blueprints-construccion-fantasma-design.md`, GDD Sección 5 ("Mecánica de Plantillas y Construcción Asistida").

**Completado (sub-proyecto A — solo edificios; sub-proyecto B, migrar puestos periféricos al mismo mecanismo, queda para después):** declarar un edificio válido ahora guarda su `Blueprint` como plantilla reutilizable (`Blueprints.gd`, uno por `zona_permitida`, el más reciente). El jugador puede emplazar copias con la tecla `B` en la cámara cenital (que reemplaza la antigua nivelación standalone) — huella fantasma del tamaño real del blueprint, 5 validaciones (zona correcta, relieve, huella libre de madera/estructura, sin choque con otro puesto/construcción, esquina en tierra firme). Al confirmar nace una **construcción fantasma**: bloques placeholder `"fantasma"` (translúcidos, con colisión) en la forma exacta del edificio (incluido el relleno de nivelación, que ya no se coloca gratis de inmediato) — `BlueprintValidator.estructura_a_blueprint()` ganó `celdas_3d`/`ancho`/`profundidad` para poder reconstruir la forma real (antes solo guardaba un template 2D aplanado, insuficiente para reconstruir puertas/ventanas/mobiliario en su altura exacta). El jugador la **surte** manteniendo click izquierdo sobre cualquier celda fantasma (reutiliza el mecanismo de minar ya existente) — cada interacción convierte la siguiente celda pendiente en un orden automático fijo (`Construccion.gd`: tierra → piso → paredes/puertas/ventanas → mobiliario), hasta completarse, momento en el que se registra en `Ciudad`/`Zonificacion` igual que declarar un edificio a mano, y se reemparejan puertas/camas (`VoxelWorld.reemparejar_construccion()`).

**Pendiente:** confirmación visual jugando en el editor real (declarar un edificio, activar el modo `B`, emplazar una copia, surtirla completa) — verificado hasta ahora solo vía MCP headless. Sub-proyecto B (puestos periféricos migrados al mismo mecanismo). Rotación de blueprints. Catálogo con selección manual entre varios blueprints guardados. Materiales reales por tipo de bloque (madera/piedra/tela/vidrio) en vez de convertir cada celda fantasma a su bloque final completo de un solo golpe — documentado como dirección futura. Costo de recursos por surtir. NPCs constructores.
```

- [ ] **Step 2: Verificación final completa**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 18 pruebas de `BlueprintValidator`).
`mcp__godot__run_project` (scene: `scenes/BlueprintsTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 4 pruebas).
`mcp__godot__run_project` (scene: `scenes/ConstruccionTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 5 pruebas).
`mcp__godot__run_project` (scene: `scenes/RecoleccionTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 9 pruebas, sin cambios de este plan).
`mcp__godot__run_project` (scene: `scenes/NiveladorTerrenoTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 6 pruebas, sin cambios de este plan — `NiveladorTerreno.gd` no se tocó).
`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: solo los warnings preexistentes documentados en Global Constraints).

- [ ] **Step 3: Commit**

```bash
git add "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: registrar blueprints reutilizables y construcción fantasma"
```
