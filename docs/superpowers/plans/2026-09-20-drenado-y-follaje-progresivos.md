# Drenado de Agua y Eliminación de Follaje Progresivos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que emplazar un blueprint no drene agua ni borre follaje: ambas cosas ocurren celda a celda, en el mismo instante en que el bloque de esa celda se vuelve sólido, con marcadores fantasma superpuestos sobre las celdas ocupadas que esperan su turno.

**Architecture:** `VoxelWorld` deja de sobrescribir agua con fantasmas, sustituye el ocupante (agua/follaje/terreno) al aplicar cada paso mediante `_reemplazar_celda()`, y registra el follaje del edificio por columna para retirarlo con el primer paso de esa columna. `Construccion.celdas_pendientes()` y `VoxelWorld.celdas_fantasma_ocupadas()` alimentan a `FantasmasDestacados`, que dibuja cajas azules sobre las celdas pendientes aún ocupadas. `CamaraCenital` deja de drenar y de borrar follaje al confirmar.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), proyecto en `godot/`. Pruebas: `Test.tscn` (`BlueprintValidatorTest.gd`), `ConstruccionTest.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-20-drenado-y-follaje-progresivos-design.md`

## Global Constraints

- Godot 4.7; en GDScript se usan **tabulaciones**.
- Conservar el español en documentación, mensajes del juego y pruebas.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- Cambios pequeños; no reformatear archivos ajenos al objetivo. Los puestos periféricos NO cambian: `drenar_agua()` y `eliminar_follaje()` siguen existiendo y los puestos las siguen usando al confirmar.
- Al emplazar un blueprint el mundo no se modifica (salvo fantasmas en celdas vacías y el registro interno); todo lo demás ocurre al surtir.
- Fuera de alcance: agua en celdas interiores sin construir; marcadores para terreno sin cavar; color destacado de puertas/ventanas ocupadas por follaje.
- Rama de trabajo: `feat/drenado-y-follaje-progresivos` (ya creada, con el spec). No agregar al commit los archivos sin versionar del usuario (`docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md`, `*.gd.uid`, cambios en el doc de PoC 5).
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```
- Cómo correr una escena (el proyecto usa el MCP de Godot, no CLI): cargar con ToolSearch `select:mcp__godot__run_project,mcp__godot__get_debug_output,mcp__godot__stop_project`; `run_project` con `projectPath = C:\Users\peraz\Projects\Misc\CityCraft\godot` y la escena; esperar unos segundos; leer `get_debug_output`; `stop_project`; confirmar con `Get-Process | Where-Object { $_.ProcessName -like "*godot*" }` (matar huérfanos propios con `Stop-Process -Id <id> -Force`; el PID 4688 preexistente no es nuestro). Éxito = línea final "pasaron correctamente" y ningún `ERROR`/"Assertion failed". Al arrancar `Main.tscn` solo son esperables los avisos preexistentes (constantes `BlueprintValidator`/`Player`, UID inválido de `BlockLibrary.res`).

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `godot/scripts/Construccion.gd` (modificar) | `celdas_pendientes(id)` |
| `godot/scripts/ConstruccionTest.gd` (modificar) | TEST 6 |
| `godot/scripts/VoxelWorld.gd` (modificar) | fantasma solo en celdas vacías, `_reemplazar_celda`, registro/limpieza de follaje, `celdas_fantasma_ocupadas`, limpieza en `eliminar_edificio` |
| `godot/scripts/BlueprintValidatorTest.gd` (modificar) | TEST 53-55 |
| `godot/scripts/CamaraCenital.gd` (modificar) | el clic ya no drena ni borra follaje; registra el follaje |
| `godot/scripts/FantasmasDestacados.gd` (modificar) | marcadores azules sobre celdas ocupadas |
| GDD §5, doc técnico PoC 6 (modificar) | documentación |

---

### Task 1: Núcleo en VoxelWorld y Construccion

**Files:**
- Modify: `godot/scripts/Construccion.gd`, `godot/scripts/VoxelWorld.gd`
- Test: `godot/scripts/ConstruccionTest.gd`, `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: lo ya existente (`colocar_bloque`, `eliminar_follaje`, `registrar_edificio`, `edificio_orden/tipos/progreso`, `edificio_relleno_cola`, `celda_a_edificio`, `Construccion.construccion_de`, `fantasmas_cambiados`).
- Produces (usados por las tareas 2 y 3):
  - `Construccion.celdas_pendientes(id: int) -> Array[Vector3i]`
  - `VoxelWorld.registrar_follaje_pendiente(id: int, celdas: Array) -> void`
  - `VoxelWorld.celdas_fantasma_ocupadas() -> Array[Vector3i]`
  - `VoxelWorld._reemplazar_celda(celda, tipo)`, `_despejar_follaje_de_columna(columna)`, `_colocar_fantasma_si_vacia(celda)` (privadas).
  - Comportamiento: `iniciar_construccion_fantasma()` ya no reemplaza agua con fantasmas.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `ConstruccionTest.gd`, antes de la línea final `print("\n=== Las 5 pruebas de Construccion pasaron correctamente ===")`, agrega:

```gdscript
	print("\n=== TEST 6: celdas_pendientes() devuelve las celdas aún no avanzadas, en orden ===")
	var celdas_6: Array[Vector3i] = [Vector3i(20, 0, 0), Vector3i(21, 0, 0), Vector3i(22, 0, 0)]
	var tipos_6 := {celdas_6[0]: "tierra", celdas_6[1]: "tierra", celdas_6[2]: "tierra"}
	var id_6: int = Construccion.iniciar(celdas_6, tipos_6)
	assert(Construccion.celdas_pendientes(id_6).size() == 3)
	Construccion.avanzar(id_6)
	var pendientes_6: Array[Vector3i] = Construccion.celdas_pendientes(id_6)
	assert(pendientes_6.size() == 2 and pendientes_6[0] == celdas_6[1] and pendientes_6[1] == celdas_6[2])
	assert(Construccion.celdas_pendientes(999999).is_empty(), "un id inexistente no tiene pendientes")
```

y cambia la línea final a `print("\n=== Las 6 pruebas de Construccion pasaron correctamente ===")`.

En `BlueprintValidatorTest.gd`, antes de la línea final `print("\n=== Las 58 pruebas de BlueprintValidator pasaron correctamente ===")`, agrega (usa `mundo_d`, el mundo propio creado en el TEST 49):

```gdscript
	# `arboles` lo crea VoxelWorld._ready(), que no corre en estos mundos de prueba;
	# eliminar_follaje() lo necesita para desregistrar el follaje de su árbol.
	mundo_d.arboles = load("res://scripts/GeneradorArbol.gd").new()

	print("\n=== TEST 53: emplazar no sobrescribe el agua; su celda se vuelve tierra (con limpieza de niveles) solo cuando le toca su paso ===")
	const OX53 := 1600
	var celda_agua_53 := Vector3i(OX53, 1, OX53)          # relleno sobre agua
	var celda_vacia_53 := Vector3i(OX53 + 1, 1, OX53)     # relleno sobre aire
	var celda_estructura_53 := Vector3i(OX53 + 2, 1, OX53)
	mundo_d.colocar_bloque(celda_agua_53, "agua")
	mundo_d._nivel_agua[celda_agua_53] = 3  # simula agua de flujo: colocar_bloque() debe limpiar esta entrada
	var orden_53: Array[Vector3i] = [celda_agua_53, celda_vacia_53]
	mundo_d.iniciar_construccion_fantasma(orden_53, {celda_agua_53: "tierra", celda_vacia_53: "tierra"}, [celda_estructura_53], {celda_estructura_53: "pared"})
	assert(mundo_d.obtener_tipo(celda_agua_53) == "agua", "al emplazar el agua no se drena ni se reemplaza por un fantasma")
	assert(mundo_d.obtener_tipo(celda_vacia_53) == "fantasma", "la celda vacía sí recibe su fantasma")
	var ocupadas_53: Array[Vector3i] = mundo_d.celdas_fantasma_ocupadas()
	assert(ocupadas_53.size() == 1 and ocupadas_53[0] == celda_agua_53, "la celda de agua pendiente se reporta como ocupada")
	mundo_d.surtir_construccion(celda_estructura_53)  # primer paso de la cola: la celda de agua
	assert(mundo_d.obtener_tipo(celda_agua_53) == "tierra", "al llegar su turno, el agua se vuelve tierra sólida")
	assert(not mundo_d._nivel_agua.has(celda_agua_53), "y su entrada de nivel de agua se limpia")
	assert(mundo_d.celdas_fantasma_ocupadas().is_empty())
	print("OK: el agua espera su turno y se drena en el mismo instante en que su celda se vuelve sólida.")

	print("\n=== TEST 54: el follaje registrado desaparece por columna con el primer paso de esa columna, no antes ===")
	const OX54 := 1610
	var relleno_a_54 := Vector3i(OX54, 1, OX54)             # columna A: celda de relleno (vacía -> fantasma)
	var follaje_a_54 := Vector3i(OX54, 2, OX54)             # columna A: follaje sobre el relleno, sin ser celda del edificio
	var estructura_b_54 := Vector3i(OX54 + 1, 1, OX54)      # columna B: celda de estructura ocupada por follaje
	mundo_d.colocar_bloque(follaje_a_54, "follaje")
	mundo_d.colocar_bloque(estructura_b_54, "follaje")
	var orden_54: Array[Vector3i] = [relleno_a_54]
	var id_54: int = mundo_d.iniciar_construccion_fantasma(orden_54, {relleno_a_54: "tierra"}, [estructura_b_54], {estructura_b_54: "pared"})
	mundo_d.registrar_follaje_pendiente(id_54, [follaje_a_54, estructura_b_54])
	assert(mundo_d.obtener_tipo(follaje_a_54) == "follaje" and mundo_d.obtener_tipo(estructura_b_54) == "follaje", "al emplazar el follaje sigue en pie")
	assert(mundo_d.obtener_tipo(relleno_a_54) == "fantasma")
	var ocupadas_54: Array[Vector3i] = mundo_d.celdas_fantasma_ocupadas()
	assert(ocupadas_54.size() == 1 and ocupadas_54[0] == estructura_b_54, "solo la celda de estructura ocupada (el follaje suelto no es del edificio)")
	mundo_d.surtir_construccion(estructura_b_54)  # paso de la columna A (relleno)
	assert(mundo_d.obtener_tipo(relleno_a_54) == "tierra")
	assert(mundo_d.obtener_tipo(follaje_a_54) == "", "el follaje de la columna A desaparece con su primer paso")
	assert(mundo_d.obtener_tipo(estructura_b_54) == "follaje", "el de la columna B espera: su columna aún no tuvo ningún paso")
	var resultado_54: Dictionary = mundo_d.surtir_construccion(estructura_b_54)  # paso de estructura, columna B
	assert(mundo_d.obtener_tipo(estructura_b_54) == "pared", "la celda de estructura pasa de follaje a pared sólida")
	assert(resultado_54["completa"])
	print("OK: el follaje se retira por columna con su primer paso, y la celda de estructura liberada queda sólida.")

	print("\n=== TEST 55: quitar el edificio antes de tiempo deja el follaje registrado sin tocar ===")
	const OX55 := 1620
	var follaje_55 := Vector3i(OX55, 1, OX55)
	var estructura_55 := Vector3i(OX55 + 1, 1, OX55)
	mundo_d.colocar_bloque(follaje_55, "follaje")
	var id_55: int = mundo_d.iniciar_construccion_fantasma([], {}, [estructura_55], {estructura_55: "pared"})
	mundo_d.registrar_follaje_pendiente(id_55, [follaje_55])
	assert(mundo_d.procesar_deconstruccion(estructura_55)["lista_para_remocion"])
	mundo_d.eliminar_edificio(id_55)
	assert(mundo_d.obtener_tipo(follaje_55) == "follaje", "el follaje nunca se tocó")
	mundo_d._despejar_follaje_de_columna(Vector2i(OX55, OX55))
	assert(mundo_d.obtener_tipo(follaje_55) == "follaje", "y ya no hay un registro que lo retire")
	print("OK: eliminar el edificio antes de tiempo no modifica el follaje.")
```

Cambia la línea final a `print("\n=== Las 61 pruebas de BlueprintValidator pasaron correctamente ===")`.

- [ ] **Step 2: Correr las escenas y verificar que fallan**

Run: `res://scenes/ConstruccionTest.tscn` → FAIL en TEST 6 (`Invalid call. Nonexistent function 'celdas_pendientes'`).
Run: `res://scenes/Test.tscn` → FAIL en TEST 53 (`Nonexistent function 'celdas_fantasma_ocupadas'`).

- [ ] **Step 3: Implementar**

En `godot/scripts/Construccion.gd`, tras `construccion_de()` agrega:

```gdscript
## Las celdas de la construcción "id" que siguen pendientes (índice >= el
## siguiente por avanzar), en orden. Vacío si "id" no existe.
func celdas_pendientes(id: int) -> Array[Vector3i]:
	var pendientes: Array[Vector3i] = []
	if not _construcciones.has(id):
		return pendientes
	var datos: Dictionary = _construcciones[id]
	for i in range(datos["indice"], datos["orden"].size()):
		pendientes.append(datos["orden"][i])
	return pendientes
```

En `godot/scripts/VoxelWorld.gd`:

(a) Junto a `var edificio_relleno_cola: Dictionary = {}  # int -> int` agrega:

```gdscript

## Follaje que un edificio recién emplazado tiene encima (huella y fachada),
## por columna: NO se retira al emplazar; desaparece con el primer paso que
## se aplique en esa columna (ver _despejar_follaje_de_columna()) o se descarta
## al eliminar el edificio. Columna Vector2i -> {"id": int, "celdas":
## Array[Vector3i]}. ponytail: si dos edificios registraran la misma columna
## las celdas se mezclan bajo el primer id; las huellas no se solapan y el
## caso de las fachadas queda sin cubrir.
var _follaje_por_columna: Dictionary = {}
var edificio_follaje: Dictionary = {}  # int (id de edificio) -> Array[Vector2i] (columnas que registró)
```

(b) En `iniciar_construccion_fantasma()` reemplaza

```gdscript
	for celda in orden_relleno:
		colocar_bloque(celda, "fantasma")
	for celda in orden_estructura:
		colocar_bloque(celda, "fantasma")
```

por

```gdscript
	for celda in orden_relleno:
		_colocar_fantasma_si_vacia(celda)
	for celda in orden_estructura:
		_colocar_fantasma_si_vacia(celda)
```

y, justo antes de `func iniciar_construccion_fantasma`, deja sus comentarios `##` como están y agrega al final de ese bloque de comentarios:

```gdscript
## Las celdas que ya están ocupadas (terreno, agua, follaje) no reciben
## fantasma: esperan su turno y el ocupante se retira cuando se aplica su paso
## (ver _reemplazar_celda()).
```

(c) Agrega esta función justo ANTES del bloque de comentarios `##` que precede a `func iniciar_construccion_fantasma` (o sea, entre la función anterior y ese bloque de comentarios):

```gdscript
## Coloca "fantasma" solo en una celda VACÍA: una celda ocupada (terreno, agua,
## follaje) espera su turno. colocar_bloque() sí reemplaza el agua, y eso no
## debe pasar al emplazar un blueprint.
func _colocar_fantasma_si_vacia(celda: Vector3i) -> void:
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		colocar_bloque(celda, "fantasma")
```

(d) Antes de `func _aplicar_paso_cola` agrega:

```gdscript
## Sustituye lo que haya en "celda" (fantasma, terreno sin cavar, agua o
## follaje) por un bloque real de "tipo". El agua se sobrescribe con
## colocar_bloque() (limpia _nivel_agua y encola el secado del agua vecina, no
## set_cell_item directo); el follaje se retira con eliminar_follaje() (lo
## desregistra del árbol); todo lo demás se vacía primero. Así el agua se
## drena y el follaje desaparece en el mismo instante en que el bloque sólido
## ocupa la celda.
func _reemplazar_celda(celda: Vector3i, tipo: String) -> void:
	var actual: String = obtener_tipo(celda)
	if actual == "follaje":
		eliminar_follaje(celda)
	elif actual != "agua":
		set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocar_bloque(celda, tipo, true)


## Registra el follaje de "id" (huella y fachada, ver
## CamaraCenital._procesar_clic_blueprint()) para retirarlo por columna con el
## primer paso que se aplique en ella. No modifica el mundo.
func registrar_follaje_pendiente(id: int, celdas: Array) -> void:
	var columnas: Array[Vector2i] = []
	for celda: Vector3i in celdas:
		var columna := Vector2i(celda.x, celda.z)
		if not _follaje_por_columna.has(columna):
			_follaje_por_columna[columna] = {"id": id, "celdas": []}
			columnas.append(columna)
		_follaje_por_columna[columna]["celdas"].append(celda)
	edificio_follaje[id] = columnas
	fantasmas_cambiados.emit()


## Retira el follaje registrado de "columna" que siga siendo follaje (pudo
## talarse o minarse antes) y borra la entrada. Cada celda liberada que
## pertenezca a la estructura pendiente (registrada en celda_a_edificio) o a
## una cola de preparación recibe su "fantasma", para que el edificio fantasma
## no quede con huecos. Se llama antes de aplicar cualquier paso de la columna.
func _despejar_follaje_de_columna(columna: Vector2i) -> void:
	if not _follaje_por_columna.has(columna):
		return
	var celdas: Array = _follaje_por_columna[columna]["celdas"]
	_follaje_por_columna.erase(columna)
	for celda: Vector3i in celdas:
		if obtener_tipo(celda) != "follaje":
			continue
		eliminar_follaje(celda)
		if celda_a_edificio.has(celda) or Construccion.construccion_de(celda) != -1:
			colocar_bloque(celda, "fantasma")


## Celdas pendientes de construir (estructura pendiente y cola de preparación)
## cuyo ocupante actual sigue siendo agua o follaje: no pueden mostrar un
## fantasma (una celda guarda un solo bloque), así que FantasmasDestacados.gd
## dibuja un marcador fantasma encima. Lógica pura; no dibuja nada.
func celdas_fantasma_ocupadas() -> Array[Vector3i]:
	var resultado: Array[Vector3i] = []
	for id in edificio_orden:
		var pendientes: Array[Vector3i] = []
		var orden: Array = edificio_orden[id]
		for i in range(edificio_progreso[id], orden.size()):
			pendientes.append(orden[i])
		if edificio_relleno_cola.has(id):
			pendientes.append_array(Construccion.celdas_pendientes(edificio_relleno_cola[id]))
		for celda in pendientes:
			var tipo: String = obtener_tipo(celda)
			if tipo == "agua" or tipo == "follaje":
				resultado.append(celda)
	return resultado
```

(e) Reemplaza el cuerpo de `_aplicar_paso_cola()` por:

```gdscript
func _aplicar_paso_cola(resultado: Dictionary) -> void:
	var celda: Vector3i = resultado["celda"]
	var tipo: String = resultado["tipo"]
	_despejar_follaje_de_columna(Vector2i(celda.x, celda.z))
	if tipo == "aire" or tipo == "fantasma":
		_retirar_bloque(celda)
		if tipo == "fantasma":
			colocar_bloque(celda, "fantasma")
	else:
		_reemplazar_celda(celda, tipo)
	fantasmas_cambiados.emit()
```

y en su comentario cambia "\"tierra\" (relleno) convierte la celda fantasma en bloque real." por "\"tierra\" (relleno) convierte la celda —fantasma, agua o follaje— en bloque real (ver _reemplazar_celda())."

(f) En `surtir_construccion()` reemplaza

```gdscript
	set_cell_item(celda_a_surtir, GridMap.INVALID_CELL_ITEM)
	colocar_bloque(celda_a_surtir, tipo, true)
	edificio_progreso[id] = progreso + 1
```

por

```gdscript
	_despejar_follaje_de_columna(Vector2i(celda_a_surtir.x, celda_a_surtir.z))
	_reemplazar_celda(celda_a_surtir, tipo)
	edificio_progreso[id] = progreso + 1
```

(g) En `eliminar_edificio()`, tras `edificio_relleno_cola.erase(id)` agrega:

```gdscript
	# El follaje registrado que aún no se retiró se queda donde está: al
	# emplazar no se modificó nada, y quitar el edificio a tiempo no debe hacerlo.
	for columna: Vector2i in edificio_follaje.get(id, []):
		if _follaje_por_columna.has(columna) and _follaje_por_columna[columna]["id"] == id:
			_follaje_por_columna.erase(columna)
	edificio_follaje.erase(id)
```

- [ ] **Step 4: Correr las escenas y verificar que pasan**

Run: `res://scenes/ConstruccionTest.tscn` → "Las 6 pruebas de Construccion pasaron correctamente".
Run: `res://scenes/Test.tscn` → "Las 61 pruebas de BlueprintValidator pasaron correctamente" (incluidas TEST 18/22/24/25/48/48b-e/49-52 que ejercitan `surtir_construccion`, `_aplicar_paso_cola`, `eliminar_edificio`). Si alguna prueba existente falla porque dependía de que un fantasma reemplazara agua, NO la cambies: repórtalo (DONE_WITH_CONCERNS) con el nombre de la prueba.
Run: `res://scenes/RecoleccionTest.tscn` (usa `minar_bloque`) → debe seguir pasando.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Construccion.gd godot/scripts/VoxelWorld.gd godot/scripts/ConstruccionTest.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: agua y follaje se retiran celda a celda al volverse sólido su bloque (núcleo en VoxelWorld)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: El clic de emplazar deja de drenar y de borrar follaje

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd` (`_procesar_clic_blueprint`; comentario de `_actualizar_resumen_materiales`)

**Interfaces:**
- Consumes: `VoxelWorld.registrar_follaje_pendiente(id, celdas)` (Task 1), `ev["resultado_huella"]["follaje_a_eliminar"]` y `ev["resultado_fachada"]["follaje_a_eliminar"]` (ya existentes en `_evaluar_blueprint`).
- Produces: nada consumido por otras tareas.

`CamaraCenital` no tiene pruebas automáticas: la verificación es arranque de `Main.tscn` sin errores + regresión de las escenas de pruebas + comprobación manual. Localiza el código por contenido.

- [ ] **Step 1: Quitar el borrado de follaje y el drenado del clic**

En `_procesar_clic_blueprint()` elimina completo este bloque:

```gdscript
	for celda_follaje in ev["resultado_huella"]["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)
	for celda_follaje in ev["resultado_fachada"]["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for rel in ev["columnas_union"]:
		total_drenado += mundo.drenar_agua(esquina.x + rel.x, esquina.y + rel.y)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

```

- [ ] **Step 2: Altura de las celdas de relleno sin agua**

En el mismo método reemplaza

```gdscript
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
```

por

```gdscript
		# Sin agua: al emplazar el agua sigue en el mundo y las celdas de agua
		# bajo el nivel de la losa son parte del relleno (ver VoxelWorld._reemplazar_celda()).
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y, true)
```

- [ ] **Step 3: Registrar el follaje tras iniciar la construcción**

Tras la línea `var id_edificio: int = mundo.iniciar_construccion_fantasma(...)` y antes de `metadata["id_edificio"] = id_edificio` agrega:

```gdscript
	# El follaje NO se borra al emplazar: se registra y desaparece por columna con
	# el primer paso que se aplique en ella (ver VoxelWorld.registrar_follaje_pendiente()).
	var follaje: Array = []
	follaje.append_array(ev["resultado_huella"]["follaje_a_eliminar"])
	follaje.append_array(ev["resultado_fachada"]["follaje_a_eliminar"])
	mundo.registrar_follaje_pendiente(id_edificio, follaje)
```

- [ ] **Step 4: Comentarios**

En el comentario `##` de `_procesar_clic_blueprint` reemplaza "drena el agua bajo la huella y la fachada, calcula" por "NO modifica el terreno (el agua y el follaje se retiran celda a celda al surtir), calcula" (ajusta la frase para que siga leyéndose bien). En el comentario de `_actualizar_resumen_materiales`, elimina el párrafo `## ponytail: sobre una huella con agua, la previsualización cuenta la excavación con el fondo real…` (ya no aplica: el clic tampoco drena, así que previsualización y clic usan el mismo fondo).

- [ ] **Step 5: Verificar arranque y regresión**

Run: `res://scenes/Main.tscn` un instante: sin errores de script en `CamaraCenital.gd` (solo los avisos preexistentes); luego `stop_project` y comprobar procesos.
Run: `res://scenes/Test.tscn` (61) y `res://scenes/NiveladorTerrenoTest.tscn` (20) — deben seguir pasando.

- [ ] **Step 6: Verificación manual (la hace el usuario, se lista en el reporte)**

En `Main.tscn`: colocar un blueprint sobre agua y bajo árboles (`B`). Comprobar que al confirmar el agua y el follaje NO cambian; que al surtir con clic derecho cada celda de agua bajo el edificio se vuelve tierra en su turno y el follaje de cada columna desaparece con el primer paso de esa columna; que quitar el edificio antes de tiempo deja el agua y los árboles como estaban.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: emplazar un blueprint ya no drena agua ni borra follaje (se registra el follaje)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 3: Marcadores fantasma sobre las celdas ocupadas

**Files:**
- Modify: `godot/scripts/FantasmasDestacados.gd`

**Interfaces:**
- Consumes: `VoxelWorld.celdas_fantasma_ocupadas() -> Array[Vector3i]` (Task 1), `VoxelWorld.celdas_fantasma_destacadas()`, `VoxelWorld.COLOR_DESTACADO` (ya existentes).
- Produces: nada consumido por otras tareas.

El dibujo no tiene prueba automática (depende del render); la lógica de datos ya está cubierta en la Task 1.

- [ ] **Step 1: Implementar**

En `FantasmasDestacados.gd`:

(a) Amplía el comentario de cabecera: tras la frase "…solo visual: GridMap sigue siendo la única fuente de verdad de ocupación/colisión." agrega una línea `## También dibuja un marcador fantasma azul sobre las celdas pendientes que aún están ocupadas por agua o follaje (una celda guarda un solo bloque, no admite un fantasma real; ver docs/superpowers/specs/2026-09-20-drenado-y-follaje-progresivos-design.md).`

(b) Junto a `const TAMANO_MARCADOR := 1.02` agrega:

```gdscript

## Mismo azul translúcido del bloque "fantasma" (Mat_fantasma en
## BlockLibrarySource.tscn): el marcador hace que una celda ocupada por agua o
## follaje se lea como un fantasma más del edificio.
const COLOR_FANTASMA_OCUPADO := Color(0.6, 0.7, 1.0, 0.35)
```

(c) Reemplaza `_reconstruir()` completa (y su comentario) por:

```gdscript
## Pocas celdas por edificio, así que se recrean todas en vez de mantener un pool.
func _reconstruir() -> void:
	for marcador in _marcadores:
		marcador.queue_free()
	_marcadores.clear()
	var destacadas: Dictionary = voxel_world.celdas_fantasma_destacadas()
	for celda: Vector3i in destacadas:
		_agregar_marcador(celda, voxel_world.COLOR_DESTACADO[destacadas[celda]])
	for celda: Vector3i in voxel_world.celdas_fantasma_ocupadas():
		_agregar_marcador(celda, COLOR_FANTASMA_OCUPADO)


func _agregar_marcador(celda: Vector3i, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var marcador := MeshInstance3D.new()
	marcador.mesh = _malla
	marcador.material_override = material
	marcador.position = Vector3(celda) + Vector3(DESF, DESF, DESF)
	add_child(marcador)
	_marcadores.append(marcador)
```

- [ ] **Step 2: Verificar arranque y regresión**

Run: `res://scenes/Main.tscn` un instante: sin errores de script en `FantasmasDestacados.gd` (solo los avisos preexistentes); `stop_project` y comprobar procesos.
Run: `res://scenes/Test.tscn` (61) — debe seguir pasando.

- [ ] **Step 3: Verificación manual (la hace el usuario)**

Colocar un blueprint sobre agua y bajo árboles: las celdas del edificio (relleno o estructura pendiente) ocupadas por agua o follaje muestran encima una caja azul translúcida como el resto del fantasma; desaparece cuando esa celda se vuelve sólida o el follaje de su columna se retira; las puertas/ventanas conservan su color (magenta/verde lima).

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/FantasmasDestacados.gd
git commit -m "feat: marcadores fantasma sobre las celdas del edificio ocupadas por agua o follaje" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 4: Documentación y verificación final

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (§5)
- Modify: `PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md`

- [ ] **Step 1: GDD §5**

Lee la sección (CLAUDE.md lo exige) y usa Glob para el nombre exacto del archivo. Al final de la viñeta `> * **Nivel de Puerta y Excavación:** …` agrega, en la misma viñeta y respetando estilo y saltos de línea (CRLF si los usa; el diff debe ser de una línea):

```
 Al emplazar un edificio no se modifica el terreno: el agua bajo su huella se rellena con tierra y el follaje se retira celda a celda, en el mismo instante en que el bloque fantasma de esa celda se vuelve sólido (el follaje que no cae en una celda del edificio, con el primer paso de su columna); mientras esperan, esas celdas muestran encima un marcador fantasma. El agua bajo el edificio cuesta relleno de tierra.
```

- [ ] **Step 2: Doc técnico PoC 6**

Lee la subsección "Puertas a nivel de suelo (2026-09-20)" y los párrafos siguientes. Agrega un párrafo después de los existentes (no dentro de la lista "Pendientes anotados"), con el mismo estilo y finales de línea (edición a nivel de bytes; el diff debe ser de pocas líneas):

```
Drenado y follaje progresivos (2026-09-20): al emplazar un blueprint el clic ya no llama a `drenar_agua()` ni a `eliminar_follaje()` (los puestos periféricos sí las siguen usando). `iniciar_construccion_fantasma()` solo pone fantasma en celdas vacías (antes `colocar_bloque()` reemplazaba el agua); las celdas ocupadas por terreno, agua o follaje esperan su turno y `VoxelWorld._reemplazar_celda()` retira el ocupante al aplicar su paso (el agua con `colocar_bloque()`, que limpia `_nivel_agua` y el secado; el follaje con `eliminar_follaje()`). El agua bajo el nivel de la losa es ahora relleno de tierra (cuenta en el resumen de materiales). El follaje detectado se registra por columna (`registrar_follaje_pendiente()`) y se retira con el primer paso que se aplique en esa columna (`_despejar_follaje_de_columna()`); `eliminar_edificio()` descarta el registro, así que quitar el edificio a tiempo no toca el follaje. `celdas_fantasma_ocupadas()` alimenta a `FantasmasDestacados`, que dibuja un marcador azul sobre las celdas pendientes aún ocupadas por agua o follaje. Fuera de alcance: agua en celdas interiores sin construir. Spec: `docs/superpowers/specs/2026-09-20-drenado-y-follaje-progresivos-design.md`.
```

- [ ] **Step 3: Verificación final**

Run: `res://scenes/Test.tscn` ("Las 61 pruebas de BlueprintValidator pasaron correctamente"), `res://scenes/ConstruccionTest.tscn` ("Las 6 pruebas de Construccion pasaron correctamente"), `res://scenes/NiveladorTerrenoTest.tscn` (20), `res://scenes/RecoleccionTest.tscn` (debe pasar) y `res://scenes/Main.tscn` sin errores nuevos. Comprobar procesos Godot.

- [ ] **Step 4: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: drenado de agua y eliminación de follaje progresivos (GDD §5 y PoC 6)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```
