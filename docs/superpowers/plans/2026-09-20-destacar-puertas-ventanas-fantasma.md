# Destacar Puertas y Ventanas en el Fantasma Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que las puertas y ventanas pendientes de un edificio ya emplazado (bloques `fantasma`) se vean con un color propio (magenta / verde lima), igual que ya ocurre en la previsualización.

**Architecture:** `VoxelWorld` expone la lógica pura `celdas_fantasma_destacadas()` y una señal `fantasmas_cambiados` emitida en cada punto donde puede cambiar. Un nodo nuevo `FantasmasDestacados` (hijo de `VoxelWorld`, mismo patrón que `TranslucidosRenderer`) redibuja una caja translúcida de color sobre cada celda destacada, una vez por fotograma.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), proyecto en `godot/`. Pruebas: `godot/scenes/Test.tscn` (`BlueprintValidatorTest.gd`, mundo propio `VoxelWorld.new()` sin `_ready()`).

**Spec:** `docs/superpowers/specs/2026-09-20-destacar-puertas-ventanas-fantasma-design.md`

## Global Constraints

- Godot 4.7; en GDScript se usan **tabulaciones**.
- Conservar el español en documentación, mensajes del juego y pruebas.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- Cambios pequeños; no reformatear archivos ajenos al objetivo. No tocar la MeshLibrary ni el bloque `fantasma`.
- Los colores viven **solo** en `VoxelWorld.COLOR_DESTACADO` (ya existe: `puerta_inferior`/`puerta_superior` magenta `Color(1.0, 0.2, 0.8, 0.6)`, `ventana` verde lima `Color(0.5, 1.0, 0.2, 0.6)`). No duplicarlos.
- Rama de trabajo: `feat/destacar-puertas-ventanas-fantasma` (ya creada, con la Pieza A y el spec). No agregar al commit los archivos sin versionar del usuario (`docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md`, `*.gd.uid`, cambios en el doc de PoC 5).
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```
- Cómo correr una escena (el proyecto usa el MCP de Godot, no CLI): cargar con ToolSearch `select:mcp__godot__run_project,mcp__godot__get_debug_output,mcp__godot__stop_project`; `run_project` con `projectPath = C:\Users\peraz\Projects\Misc\CityCraft\godot` y la escena; leer `get_debug_output`; `stop_project`; confirmar con `Get-Process | Where-Object { $_.ProcessName -like "*godot*" }` (matar huérfanos propios con `Stop-Process -Id <id> -Force`; el PID 4688 preexistente no es nuestro). Éxito = línea final "pasaron correctamente" y ningún `ERROR`/"Assertion failed".

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `godot/scripts/VoxelWorld.gd` (modificar) | señal `fantasmas_cambiados`, `celdas_fantasma_destacadas()`, emisión en 5 puntos, conexión en `_ready()` |
| `godot/scripts/BlueprintValidatorTest.gd` (modificar) | TEST 49, 49b y 50 |
| `godot/scripts/FantasmasDestacados.gd` (crear) | dibuja las cajas de color |
| `godot/scenes/Main.tscn` (modificar) | nodo `FantasmasDestacados` hijo de `VoxelWorld` |
| doc técnico PoC 6 (modificar) | una línea |

---

### Task 1: Lógica pura y señal en VoxelWorld

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd` (señal ~línea 192; `_revertir_celda` ~1185; `eliminar_edificio` ~1202; `iniciar_construccion_fantasma` ~1250; `_aplicar_paso_cola` ~1300; `surtir_construccion` ~1327)
- Test: `godot/scripts/BlueprintValidatorTest.gd` (antes de la línea final "Las 50 pruebas…")

**Interfaces:**
- Consumes: `COLOR_DESTACADO` (ya en `VoxelWorld.gd`), `edificio_orden`, `edificio_tipos`, `edificio_progreso`, `obtener_tipo()`.
- Produces:
  - `signal fantasmas_cambiados` (sin argumentos).
  - `celdas_fantasma_destacadas() -> Dictionary` (`Vector3i` → tipo: `"puerta_inferior"`, `"puerta_superior"` o `"ventana"`).

- [ ] **Step 1: Escribir las pruebas que fallan**

En `BlueprintValidatorTest.gd`, antes de `print("\n=== Las 50 pruebas de BlueprintValidator pasaron correctamente ===")`, agrega:

```gdscript
	print("\n=== TEST 49: celdas_fantasma_destacadas() marca solo puertas y ventanas todavía fantasma, y se actualiza al surtir y deconstruir ===")
	# Mundo PROPIO para las pruebas 49-50: celdas_fantasma_destacadas() recorre TODOS los
	# edificios del mundo, y las pruebas anteriores dejan en `mundo` edificios con
	# puertas/ventanas pendientes que falsearían los conteos.
	var mundo_d: Node = VoxelWorld.new()
	mundo_d.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_d.cell_size = Vector3.ONE * 1.0
	mundo_d._indexar_biblioteca()
	const OX49 := 1450
	var pared_49 := Vector3i(OX49, 1, OX49)
	var puerta_inf_49 := Vector3i(OX49 + 1, 1, OX49)
	var puerta_sup_49 := Vector3i(OX49 + 1, 2, OX49)
	var ventana_49 := Vector3i(OX49 + 2, 1, OX49)
	var baul_49 := Vector3i(OX49 + 3, 1, OX49)
	var tipos_49 := {
		pared_49: "pared", puerta_inf_49: "puerta_inferior", puerta_sup_49: "puerta_superior",
		ventana_49: "ventana", baul_49: "baul",
	}
	var orden_49: Array = mundo_d.ordenar_celdas_edificio(tipos_49)
	var id_49: int = mundo_d.iniciar_construccion_fantasma([], {}, orden_49, tipos_49)
	var d_49: Dictionary = mundo_d.celdas_fantasma_destacadas()
	assert(d_49.size() == 3, "solo puerta (2 mitades) y ventana; ni pared ni baúl")
	assert(d_49[puerta_inf_49] == "puerta_inferior")
	assert(d_49[puerta_sup_49] == "puerta_superior")
	assert(d_49[ventana_49] == "ventana")
	assert(not d_49.has(pared_49) and not d_49.has(baul_49))

	# Surtir en el orden fijo [pared, puerta_inf, ventana, puerta_sup, baúl]: cada
	# celda destacada sale del resultado cuando deja de ser fantasma.
	mundo_d.surtir_construccion(pared_49)
	assert(mundo_d.celdas_fantasma_destacadas().size() == 3, "la pared no es destacada")
	mundo_d.surtir_construccion(pared_49)  # puerta_inferior
	assert(not mundo_d.celdas_fantasma_destacadas().has(puerta_inf_49))
	assert(mundo_d.celdas_fantasma_destacadas().size() == 2)
	mundo_d.surtir_construccion(pared_49)  # ventana
	assert(mundo_d.celdas_fantasma_destacadas().size() == 1)
	mundo_d.surtir_construccion(pared_49)  # puerta_superior
	mundo_d.surtir_construccion(pared_49)  # baúl (completa)
	assert(mundo_d.celdas_fantasma_destacadas().is_empty(), "edificio completo: nada pendiente")

	# Deconstruir revierte primero el baúl y luego la puerta superior: esa vuelve a destacarse.
	mundo_d.procesar_deconstruccion(pared_49)  # baúl
	assert(mundo_d.celdas_fantasma_destacadas().is_empty())
	mundo_d.procesar_deconstruccion(pared_49)  # puerta_superior
	var d_decon_49: Dictionary = mundo_d.celdas_fantasma_destacadas()
	assert(d_decon_49.size() == 1 and d_decon_49.has(puerta_sup_49))
	mundo_d.procesar_deconstruccion(pared_49)  # ventana
	mundo_d.procesar_deconstruccion(pared_49)  # puerta_inferior
	mundo_d.procesar_deconstruccion(pared_49)  # pared -> progreso 0
	assert(mundo_d.celdas_fantasma_destacadas().size() == 3)
	mundo_d.eliminar_edificio(id_49)
	assert(mundo_d.celdas_fantasma_destacadas().is_empty(), "un edificio eliminado no deja marcadores")
	print("OK: solo puertas/ventanas pendientes se destacan, y el resultado sigue al surtir, deconstruir y eliminar.")

	print("\n=== TEST 49b: una puerta enterrada bajo terreno sin cavar no se destaca hasta que la cola de excavación la deja como fantasma ===")
	const OX49B := 1460
	var celda_enterrada_49b := Vector3i(OX49B, 1, OX49B)
	mundo_d.colocar_bloque(celda_enterrada_49b, "tierra")
	mundo_d.iniciar_construccion_fantasma(
		[celda_enterrada_49b], {celda_enterrada_49b: "fantasma"},
		[celda_enterrada_49b], {celda_enterrada_49b: "puerta_inferior"}
	)
	assert(mundo_d.obtener_tipo(celda_enterrada_49b) == "tierra")
	assert(mundo_d.celdas_fantasma_destacadas().is_empty(), "todavía es terreno real, no un fantasma")
	mundo_d.surtir_construccion(celda_enterrada_49b)  # cava y deja fantasma
	assert(mundo_d.celdas_fantasma_destacadas().has(celda_enterrada_49b))
	print("OK: la puerta enterrada se destaca recién cuando se cava.")

	print("\n=== TEST 50: fantasmas_cambiados se emite al iniciar, surtir (relleno y estructura), deconstruir y eliminar ===")
	const OX50 := 1470
	var pared_50 := Vector3i(OX50, 1, OX50)
	var ventana_50 := Vector3i(OX50 + 1, 1, OX50)
	var relleno_50 := Vector3i(OX50 + 2, 1, OX50)
	var tipos_50 := {pared_50: "pared", ventana_50: "ventana"}
	var cuenta_50: Array = [0]
	mundo_d.fantasmas_cambiados.connect(func() -> void: cuenta_50[0] += 1)
	var id_50: int = mundo_d.iniciar_construccion_fantasma([relleno_50], {relleno_50: "tierra"}, mundo_d.ordenar_celdas_edificio(tipos_50), tipos_50)
	assert(cuenta_50[0] == 1, "iniciar")
	mundo_d.surtir_construccion(pared_50)  # relleno
	assert(cuenta_50[0] == 2, "surtir: paso de relleno")
	mundo_d.surtir_construccion(pared_50)  # pared
	assert(cuenta_50[0] == 3, "surtir: paso de estructura")
	mundo_d.surtir_construccion(pared_50)  # ventana (completa)
	assert(cuenta_50[0] == 4)
	mundo_d.procesar_deconstruccion(pared_50)  # revierte ventana
	assert(cuenta_50[0] == 5, "deconstruir")
	mundo_d.procesar_deconstruccion(pared_50)  # revierte pared -> progreso 0
	assert(cuenta_50[0] == 6)
	mundo_d.procesar_deconstruccion(pared_50)  # progreso 0: no revierte nada
	assert(cuenta_50[0] == 6, "sin celda revertida no hay emisión")
	mundo_d.eliminar_edificio(id_50)
	assert(cuenta_50[0] == 7, "eliminar")
	print("OK: la señal se emite en cada punto que puede cambiar los marcadores.")
```

Cambia la línea final a `print("\n=== Las 53 pruebas de BlueprintValidator pasaron correctamente ===")`.

- [ ] **Step 2: Correr `Test.tscn` y verificar que falla**

Run: `res://scenes/Test.tscn`.
Expected: FAIL en TEST 49 — `Invalid call. Nonexistent function 'celdas_fantasma_destacadas'` (o error de parseo por `fantasmas_cambiados`).

- [ ] **Step 3: Implementar**

En `VoxelWorld.gd`, tras `signal bloque_translucido_cambiado(celda: Vector3i)` agrega:

```gdscript

## Emitida cuando puede haber cambiado el resultado de
## celdas_fantasma_destacadas() (se inicia, surte, revierte o elimina un
## edificio) — FantasmasDestacados la escucha para redibujar sus marcadores.
## Puede emitirse sin un cambio real (p. ej. un paso de relleno): el
## receptor solo marca "sucio" y reconstruye una vez por fotograma.
signal fantasmas_cambiados
```

Antes de `func _revertir_celda` — es decir, en un lugar cualquiera fuera de otra función, por ejemplo justo antes de `## Elimina por completo un edificio ya reducido…` — agrega:

```gdscript
## Celdas de puerta y ventana que hoy siguen siendo "fantasma": para cada
## edificio, las pendientes (índice >= edificio_progreso) cuyo tipo final está
## en COLOR_DESTACADO y que en el GridMap son realmente "fantasma" — una
## puerta enterrada bajo terreno aún sin cavar (ver
## _aplicar_paso_cola()) no cuenta hasta que se cava. Devuelve Vector3i ->
## tipo. Lógica pura para FantasmasDestacados.gd; no dibuja nada.
func celdas_fantasma_destacadas() -> Dictionary:
	var resultado: Dictionary = {}
	for id in edificio_orden:
		var orden: Array = edificio_orden[id]
		for i in range(edificio_progreso[id], orden.size()):
			var celda: Vector3i = orden[i]
			var tipo: String = edificio_tipos[id][celda]
			if COLOR_DESTACADO.has(tipo) and obtener_tipo(celda) == "fantasma":
				resultado[celda] = tipo
	return resultado


```

En `_revertir_celda()`, tras `if TIPOS_TRANSLUCIDOS.has(tipo_anterior): bloque_translucido_cambiado.emit(celda)` (el `if` final de la función) agrega, al mismo nivel de indentación que ese `if`:

```gdscript
	fantasmas_cambiados.emit()
```

En `eliminar_edificio()`, reemplaza `	edificio_despeje.erase(id)\n	return esquina` por:

```gdscript
	edificio_despeje.erase(id)
	fantasmas_cambiados.emit()
	return esquina
```

En `iniciar_construccion_fantasma()`, reemplaza el final `			celda_a_despeje[celda_despeje][id] = true\n	return id\n\n\n## Registra un edificio YA terminado` por (solo el `return id` de esa función cambia):

```gdscript
			celda_a_despeje[celda_despeje][id] = true
	fantasmas_cambiados.emit()
	return id


## Registra un edificio YA terminado
```

Reemplaza `_aplicar_paso_cola()` por:

```gdscript
func _aplicar_paso_cola(resultado: Dictionary) -> void:
	var celda: Vector3i = resultado["celda"]
	var tipo: String = resultado["tipo"]
	if tipo == "aire" or tipo == "fantasma":
		_retirar_bloque(celda)
		if tipo == "fantasma":
			colocar_bloque(celda, "fantasma")
	else:
		set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
		colocar_bloque(celda, tipo, true)
	fantasmas_cambiados.emit()
```

En `surtir_construccion()`, tras `	edificio_progreso[id] = progreso + 1` agrega:

```gdscript
	fantasmas_cambiados.emit()
```

- [ ] **Step 4: Correr `Test.tscn` y verificar que pasa**

Run: `res://scenes/Test.tscn`.
Expected: PASS — "=== Las 53 pruebas de BlueprintValidator pasaron correctamente ===" (incluye TEST 20/22/24/48/48b/48c, que cubren `surtir_construccion`/`eliminar_edificio` modificados). Solo pueden aparecer los avisos preexistentes de nombres de constantes.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: señal fantasmas_cambiados y celdas_fantasma_destacadas() en VoxelWorld" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: Nodo `FantasmasDestacados`, escena, documentación y verificación

**Files:**
- Create: `godot/scripts/FantasmasDestacados.gd`
- Modify: `godot/scenes/Main.tscn`
- Modify: `godot/scripts/VoxelWorld.gd` (`_ready()`, ~línea 316)
- Modify: doc técnico PoC 6 (`PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md`, subsección "Puertas a nivel de suelo (2026-09-20)")

**Interfaces:**
- Consumes: `VoxelWorld.fantasmas_cambiados`, `VoxelWorld.celdas_fantasma_destacadas()`, `VoxelWorld.COLOR_DESTACADO` (Task 1 / Pieza A).
- Produces: nada consumido por otras tareas.

No hay prueba automática para el dibujo (depende del árbol de escena y del render); la lógica y la señal ya están cubiertas por la Task 1. Verificación: arranque sin errores + comprobación manual.

- [ ] **Step 1: Crear `godot/scripts/FantasmasDestacados.gd`**

```gdscript
extends Node3D

## Marca con un color propio las puertas y ventanas de los edificios en
## construcción que todavía son bloques "fantasma" (ver
## docs/superpowers/specs/2026-09-20-destacar-puertas-ventanas-fantasma-design.md).
## "fantasma" es un solo tipo de la MeshLibrary y GridMap no admite material
## por celda, así que esto dibuja una caja translúcida de color ENCIMA de
## cada celda destacada — solo visual: GridMap sigue siendo la única fuente
## de verdad de ocupación/colisión. Mismo patrón que TranslucidosRenderer:
## VoxelWorld._ready() asigna "voxel_world" y conecta la señal.

## Mismo desfase que CamaraCenital.gd/TranslucidosRenderer.gd: una celda
## "celda" ocupa [celda, celda+1] en cada eje, así que su centro real está
## en celda + DESF.
const DESF := 0.5

## Un poco más grande que la celda para no competir (z-fighting) con las
## caras del bloque "fantasma" que hay debajo.
const TAMANO_MARCADOR := 1.02

## Asignado por VoxelWorld._ready() antes de conectar la señal. Nunca null
## en uso real.
var voxel_world: Node

var _sucio := false
var _marcadores: Array[MeshInstance3D] = []
var _malla := BoxMesh.new()


func _init() -> void:
	_malla.size = Vector3.ONE * TAMANO_MARCADOR


## Conectada a VoxelWorld.fantasmas_cambiados. Solo marca: la reconstrucción
## ocurre una vez por fotograma en _process(), sin importar cuántas veces se
## emita la señal (surtir con clic sostenido la emite muchas veces).
func marcar_sucio() -> void:
	_sucio = true


func _process(_delta: float) -> void:
	if not _sucio:
		return
	_sucio = false
	_reconstruir()


## Pocas celdas por edificio (2 de puerta, unas cuantas de ventana), así que
## se recrean todas en vez de mantener un pool.
func _reconstruir() -> void:
	for marcador in _marcadores:
		marcador.queue_free()
	_marcadores.clear()
	var destacadas: Dictionary = voxel_world.celdas_fantasma_destacadas()
	for celda: Vector3i in destacadas:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = voxel_world.COLOR_DESTACADO[destacadas[celda]]
		var marcador := MeshInstance3D.new()
		marcador.mesh = _malla
		marcador.material_override = material
		marcador.position = Vector3(celda) + Vector3(DESF, DESF, DESF)
		add_child(marcador)
		_marcadores.append(marcador)
```

- [ ] **Step 2: Conectar en `VoxelWorld._ready()`**

En `VoxelWorld.gd`, tras `translucidos.reconstruir_todo()` (última línea de `_ready()`) agrega:

```gdscript
	var destacados: Node3D = get_node("FantasmasDestacados")
	destacados.voxel_world = self
	fantasmas_cambiados.connect(destacados.marcar_sucio)
```

- [ ] **Step 3: Agregar el nodo a `Main.tscn`**

En `godot/scenes/Main.tscn`:

1. Tras la línea `[ext_resource type="Script" path="res://scripts/TranslucidosRenderer.gd" id="8"]` agrega:
   ```
   [ext_resource type="Script" path="res://scripts/FantasmasDestacados.gd" id="9"]
   ```
   (verifica antes con Grep que el id `"9"` no esté usado en el archivo; si lo está, usa el siguiente entero libre).
2. Tras el nodo `TranslucidosRenderer` (es decir, tras sus dos líneas `[node name="TranslucidosRenderer" type="Node3D" parent="VoxelWorld"]` / `script = ExtResource("8")`) agrega:
   ```

   [node name="FantasmasDestacados" type="Node3D" parent="VoxelWorld"]
   script = ExtResource("9")
   ```

- [ ] **Step 4: Verificar arranque y pruebas**

Run: `res://scenes/Main.tscn` un instante (F5 vía MCP): `get_debug_output` sin errores de script ni "Node not found: FantasmasDestacados" (solo los avisos preexistentes: constantes `BlueprintValidator`/`Player`, UID inválido de `BlockLibrary.res`). Luego `stop_project` y comprobar procesos.
Run: `res://scenes/Test.tscn` — Expected: "Las 53 pruebas de BlueprintValidator pasaron correctamente".

- [ ] **Step 5: Documentación**

En la subsección "Puertas a nivel de suelo (2026-09-20)" del doc técnico de PoC 6 (léela antes; conserva el estilo y los saltos de línea del archivo), agrega al final:

```
Puertas y ventanas pendientes se destacan con color propio (puerta magenta, ventana verde lima; `VoxelWorld.COLOR_DESTACADO`) tanto en la previsualización del blueprint como en los fantasmas ya emplazados: `VoxelWorld.celdas_fantasma_destacadas()` + señal `fantasmas_cambiados` + nodo `FantasmasDestacados` (cajas translúcidas superpuestas al bloque `fantasma`, que sigue siendo un único tipo de la MeshLibrary). Spec: `docs/superpowers/specs/2026-09-20-destacar-puertas-ventanas-fantasma-design.md`.
```

- [ ] **Step 6: Verificación manual (la hace el usuario)**

En `Main.tscn`: declarar un edificio, cenital (`C`), `B` y colocar el blueprint. Comprobar: en la previsualización puertas magenta y ventanas verde lima (rojo si es inválido); tras colocar, esos mismos colores sobre los bloques azules del fantasma; al surtir con clic derecho cada puerta/ventana pierde su color al volverse real; al deconstruir (modo `G`) reaparece; el borde de la caja no parpadea contra el bloque azul.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/FantasmasDestacados.gd godot/scripts/VoxelWorld.gd godot/scenes/Main.tscn "PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "feat: destacar puertas y ventanas en los fantasmas emplazados (FantasmasDestacados)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```
