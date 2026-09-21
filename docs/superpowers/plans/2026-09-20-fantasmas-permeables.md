# Fantasmas de Obra Permeables hacia Afuera (Plan 3 de 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que los bloques `"fantasma"` de una obra sean transitables solo para quien ya está dentro de su volumen cuando se emplaza (o cuando un edificio completo empieza a deconstruirse), que esa gente pueda salir pero no volver a entrar, que los colonos evacúen solos, y que nadie pueda iniciar la obra mientras haya alguien dentro.

**Architecture:** La colisión de los fantasmas sale del `GridMap` (que no permite colisión por celda ni por cara) y pasa a un `StaticBody3D` por obra con una caja por celda fantasma pendiente (`CuerposObra.gd`). Quien tiene un **permiso de salida** sobre una obra ignora la colisión con **esa** obra: el avatar mediante `add_collision_exception_with`, los colonos mediante `ignorar_fantasmas` en `BuscadorRutas`. `VoxelWorld` guarda los permisos y el volumen de cada obra, emite `obra_a_fantasma(id)` y se niega a avanzar una obra con ocupantes. El permiso se revoca al salir y nunca se vuelve a conceder.

**Tech Stack:** Godot 4.7 (GDScript), `GodotPhysics3D`, pruebas como escenas `*Test.tscn` (una con física real y `await`).

**Spec:** `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md` (Sección 6). **Depende de los Planes 1 y 2**: usa `BuscadorRutas`, `Colonos`, `Player.gd` con `Colonos.actualizar_avatar` y el autoload `Colonos`.

## Global Constraints

- GDScript con **tabulaciones** (CLAUDE.md). Textos, comentarios y pruebas en **español**. Identificadores en ASCII.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python. No tocar `docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md` ni el diff de `PoC_5/`. En cada commit, `git add` solo los archivos del paso.
- Verificación (CLAUDE.md): `godot/scenes/Test.tscn` con Godot 4.7 más las demás escenas `*Test.tscn` afectadas (`ConstruccionTest`, `BuscadorRutasTest`, `ColonosTest`, `FantasmasPermeablesTest`).
- Regla: al emplazar un blueprint (`iniciar_construccion_fantasma`) o al empezar a deconstruir un edificio completo (primer `procesar_deconstruccion` con el edificio entero), cada colono y el avatar cuya celda esté dentro del **volumen** de la obra recibe un permiso de salida. Con permiso ignora la colisión con los fantasmas de **esa** obra. El permiso se revoca al salir del volumen y no se concede de nuevo. Quien no lo tiene ve los fantasmas como sólidos: no puede entrar.
- **Volumen de una obra** = caja envolvente (mínimo y máximo `Vector3i`) de todas sus celdas: estructura y preparación del terreno (relleno y excavación).
- Puerta de inicio de obra: `VoxelWorld.surtir_construccion()` devuelve `{"bloqueada": true}` (no `{}`) mientras haya un permiso vigente sobre la obra, y no la avanza. `Player._colocar()` debe tratarlo: `{}` significaría "no es una obra" y caería a colocar un bloque nuevo.
- Los ids de permiso son `int` para los colonos (su id) y la cadena `"avatar"` para el avatar.
- La colisión de los fantasmas sigue en la **capa 1** (la del mundo) para que el raycast del jugador y el picking de `CamaraCenital.gd` los sigan detectando; los colonos están en la capa 2 (Plan 2).
- Un fantasma huérfano (sin obra) queda sin colisión: `eliminar_edificio()` ya retira los suyos, así que no debería existir; se documenta con `ponytail:` en `VoxelWorld.gd`.
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```

## Cómo ejecutar una escena de pruebas (headless)

Desde la raíz del repo, en bash:

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/BuscadorRutasTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Pasa si imprime una única línea `=== Las N pruebas de ... pasaron correctamente ===` y ninguna con `Assertion`, `SCRIPT ERROR` o `Parse Error`. La escena `FantasmasPermeablesTest` usa `await` sobre fotogramas de física, que en headless avanzan con el reloj real: usa `--quit-after 3000` y la propia escena llama a `get_tree().quit()` al terminar.

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `godot/scripts/BuscadorRutas.gd` | Modificar | `ignorar_fantasmas`, búsqueda genérica `_buscar()` y `buscar_salida()` |
| `godot/scripts/BuscadorRutasTest.gd` | Modificar | Pruebas 15-17 |
| `godot/scripts/CuerposObra.gd` | Crear | Un `StaticBody3D` por obra con una caja por celda fantasma |
| `godot/scripts/FantasmasPermeablesTest.gd` + `godot/scenes/FantasmasPermeablesTest.tscn` | Crear | Pruebas de `CuerposObra` (física real) y de los permisos/puerta de `VoxelWorld` |
| `godot/scripts/VoxelWorld.gd` | Modificar | Sin colisión en el ítem fantasma, cuerpos por obra, volumen, permisos, señal, puerta de inicio |
| `godot/scripts/Player.gd` | Modificar | Tratar `bloqueada`, permiso y excepción de colisión del avatar |
| `godot/scripts/Main.gd` | Modificar | Conectar `obra_a_fantasma` al jugador |
| `godot/scripts/Colonos.gd` | Modificar | Evacuación y uso de `ignorar_fantasmas` |
| `godot/scripts/ColonosTest.gd` | Modificar | Pruebas 14-15 (evacuación) |
| GDD Sección 5, `PoC_8/…` | Modificar | Documentación |

---

### Task 1: `BuscadorRutas` — `ignorar_fantasmas` y `buscar_salida()`

**Files:**
- Modify: `godot/scripts/BuscadorRutas.gd` (reemplazo completo del archivo)
- Modify: `godot/scripts/BuscadorRutasTest.gd`

**Interfaces:**
- Consumes: el `BuscadorRutas` del Plan 2. El `mundo` que recibe ahora también expone `id_de_edificio(celda: Vector3i) -> int` (`VoxelWorld` ya lo tiene), que solo se consulta cuando `ignorar_fantasmas` no está vacío.
- Produces (los usa `Colonos.gd` en la Tarea 5):
  - `es_transitable(celda: Vector3i, ignorar: Array = []) -> bool` y `vecinos(celda: Vector3i, ignorar: Array = []) -> Array[Vector3i]`.
  - `buscar_ruta(origen, destino, opciones)` con `opciones.ignorar_fantasmas: Array` (ids de obra cuyos fantasmas cuentan como libres para este solicitante).
  - `buscar_salida(origen: Vector3i, esta_dentro: Callable, opciones: Dictionary = {}) -> Array[Vector3i]` — ruta más corta (sin incluir el origen) hasta la primera celda transitable para la que `esta_dentro.call(celda)` es `false`; `[]` si no hay o si el origen ya está fuera.
  - El suelo sigue contando un fantasma como sólido incluso con `ignorar_fantasmas` (solo el cuerpo y la cabeza lo atraviesan).

- [ ] **Step 1: Agregar las pruebas 15-17 (fallarán)**

En `godot/scripts/BuscadorRutasTest.gd`, ampliar `MundoFalso` con las obras (dentro de `class MundoFalso extends RefCounted:`, junto a `celdas`):

```gdscript
	var ids: Dictionary = {}  # Vector3i -> int: la obra a la que pertenece cada fantasma

	func id_de_edificio(celda: Vector3i) -> int:
		return ids.get(celda, -1)

	func poner_fantasma(celda: Vector3i, id_obra: int) -> void:
		celdas[celda] = "fantasma"
		ids[celda] = id_obra
```

Antes del `print` final, agregar:

```gdscript
	print("\n=== TEST 15: Un fantasma solo se atraviesa con el permiso de SU obra ===")
	var m14 := MundoFalso.new()
	_llano(m14, 6, 1)  # una sola fila
	m14.poner_fantasma(Vector3i(2, 1, 0), 7)
	m14.poner_fantasma(Vector3i(2, 2, 0), 7)
	var b14 := BuscadorRutas.new(m14)
	assert(not b14.es_transitable(Vector3i(2, 1, 0)), "sin permiso, un fantasma es sólido")
	assert(b14.es_transitable(Vector3i(2, 1, 0), [7]), "con el permiso de su obra, es libre")
	assert(not b14.es_transitable(Vector3i(2, 1, 0), [8]), "el permiso de otra obra no sirve")
	assert(b14.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0)).is_empty())
	var ruta14: Array[Vector3i] = b14.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"ignorar_fantasmas": [7]})
	assert(ruta14.size() == 4 and ruta14.has(Vector3i(2, 1, 0)), "con permiso cruza la pared fantasma")
	assert(b14.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"ignorar_fantasmas": [8]}).is_empty())

	print("\n=== TEST 16: buscar_salida() lleva desde dentro de la obra hasta la primera celda de fuera ===")
	var m15 := MundoFalso.new()
	_llano(m15, 7, 7)
	for x in range(2, 5):  # un cubo fantasma macizo de 3x3x2
		for z in range(2, 5):
			m15.poner_fantasma(Vector3i(x, 1, z), 7)
			m15.poner_fantasma(Vector3i(x, 2, z), 7)
	var b15 := BuscadorRutas.new(m15)
	var esta_dentro := func(celda: Vector3i) -> bool:
		return celda.x >= 2 and celda.x <= 4 and celda.z >= 2 and celda.z <= 4
	var salida15: Array[Vector3i] = b15.buscar_salida(Vector3i(3, 1, 3), esta_dentro, {"ignorar_fantasmas": [7]})
	print("Ruta de salida: ", salida15)
	assert(salida15.size() == 2, "del centro al borde del cubo y un paso más")
	assert(not esta_dentro.call(salida15.back()), "termina fuera del volumen")
	assert(b15.buscar_salida(Vector3i(3, 1, 3), esta_dentro).is_empty(), "sin permiso, el origen es un sólido: no hay ruta")

	print("\n=== TEST 17: Si el origen ya está fuera, no hay nada que recorrer ===")
	assert(b15.buscar_salida(Vector3i(0, 1, 0), esta_dentro).is_empty())
```

y cambiar la última línea a:

```gdscript
	print("\n=== Las 17 pruebas de BuscadorRutas pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/BuscadorRutasTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA (`Too many arguments for "es_transitable()"` o `Nonexistent function 'buscar_salida'`).

- [ ] **Step 3: Reemplazar `godot/scripts/BuscadorRutas.gd`**

```gdscript
extends RefCounted

## A* a pie sobre el mundo voxel. Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Secciones
## 2 y 6).
##
## No usa NavigationServer3D: exige hornear una malla y este mundo cambia
## continuamente (minado, construcción fantasma, agua que fluye). Aquí los
## vecinos se evalúan consultando "mundo" en el momento, así que siempre se
## ve el mundo actual y no hay nada que invalidar.
##
## "mundo" necesita obtener_tipo(celda: Vector3i) -> String ("" = vacía) y,
## solo si se usa ignorar_fantasmas, id_de_edificio(celda: Vector3i) -> int.
## Clase pura (RefCounted), sin nodos: se prueba con un mundo falso.

## Tope de nodos expandidos por consulta: suficiente para cruzar el mapa de
## 200x200. ponytail: búsqueda síncrona con tope fijo; pasar a búsqueda
## asíncrona o jerárquica si el número de NPC lo exige.
const MAX_NODOS_EXPANDIDOS := 20000

## Un NPC sube 1 bloque y cae hasta 3 (como salta y cae el jugador).
const CAIDA_MAXIMA := 3

const ARRIBA := Vector3i(0, 1, 0)

## Celdas por las que un NPC (de 2 celdas de alto) pasa. Todo lo demás es
## sólido, incluidos "fantasma", "follaje", "madera", camas y baúles.
const TIPOS_LIBRES := ["", "puerta_inferior", "puerta_superior"]

const DIRECCIONES: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var mundo: Object
var max_nodos: int = MAX_NODOS_EXPANDIDOS


func _init(p_mundo: Object) -> void:
	mundo = p_mundo


## "ignorar" son ids de obra cuyos bloques "fantasma" cuentan como libres para
## quien pregunta (los que tienen permiso de salida, ver VoxelWorld). Solo
## afecta al cuerpo del NPC; el suelo (ver es_transitable()) sigue viendo un
## fantasma como sólido.
func _libre(celda: Vector3i, ignorar: Array = []) -> bool:
	var tipo: String = mundo.obtener_tipo(celda)
	if TIPOS_LIBRES.has(tipo):
		return true
	return tipo == "fantasma" and not ignorar.is_empty() and ignorar.has(mundo.id_de_edificio(celda))


## Un NPC puede estar en "celda" si ella y la de arriba están libres y la de
## abajo es suelo sólido. Excepción: "celda" puede ser agua si la de arriba es
## libre (agua de 1 bloque de profundidad; con 2 o más ya no se camina, se
## nadaría, y los colonos no nadan). Una cama o un baúl es suelo, así que un
## colono puede pararse encima.
func es_transitable(celda: Vector3i, ignorar: Array = []) -> bool:
	var tipo: String = mundo.obtener_tipo(celda)
	if not (_libre(celda, ignorar) or tipo == "agua"):
		return false
	if not _libre(celda + ARRIBA, ignorar):
		return false
	var suelo: String = mundo.obtener_tipo(celda - ARRIBA)
	return suelo != "agua" and not TIPOS_LIBRES.has(suelo)


## Celdas transitables a un paso de "celda": mismo nivel, subiendo 1 bloque o
## cayendo hasta CAIDA_MAXIMA. Sin diagonales.
func vecinos(celda: Vector3i, ignorar: Array = []) -> Array[Vector3i]:
	var resultado: Array[Vector3i] = []
	for direccion in DIRECCIONES:
		var columna: Vector3i = celda + direccion
		if es_transitable(columna, ignorar):
			resultado.append(columna)
			continue
		var sobre_columna: Vector3i = columna + ARRIBA
		if es_transitable(sobre_columna, ignorar) and _libre(celda + ARRIBA * 2, ignorar):
			resultado.append(sobre_columna)
			continue
		if _libre(columna, ignorar) and _libre(sobre_columna, ignorar):
			for caida in range(1, CAIDA_MAXIMA + 1):
				var abajo: Vector3i = columna - ARRIBA * caida
				if es_transitable(abajo, ignorar):
					resultado.append(abajo)
					break
				if not _libre(abajo, ignorar):
					break
	return resultado


## Celdas a recorrer de "origen" a "destino", SIN incluir el origen; [] si no
## hay ruta (origen o destino no transitables, destino bloqueado, sin camino o
## tope de nodos agotado). opciones.bloqueadas: Dictionary (Vector3i -> true)
## con celdas que no se pueden pisar (otros colonos, el avatar).
## opciones.ignorar_fantasmas: Array de ids de obra cuyos fantasmas son libres
## para este solicitante.
func buscar_ruta(origen: Vector3i, destino: Vector3i, opciones: Dictionary = {}) -> Array[Vector3i]:
	var vacia: Array[Vector3i] = []
	var bloqueadas: Dictionary = opciones.get("bloqueadas", {})
	var ignorar: Array = opciones.get("ignorar_fantasmas", [])
	if origen == destino or bloqueadas.has(destino) or not es_transitable(destino, ignorar):
		return vacia
	return _buscar(
		origen,
		func(celda: Vector3i) -> bool: return celda == destino,
		func(celda: Vector3i) -> int: return _heuristica(celda, destino),
		opciones
	)


## Ruta más corta desde "origen" hasta la primera celda transitable para la
## que esta_dentro.call(celda) es false (la salida de un volumen). Sin
## incluir el origen; [] si no hay ruta o si el origen ya está fuera.
func buscar_salida(origen: Vector3i, esta_dentro: Callable, opciones: Dictionary = {}) -> Array[Vector3i]:
	return _buscar(
		origen,
		func(celda: Vector3i) -> bool: return not esta_dentro.call(celda),
		func(_celda: Vector3i) -> int: return 0,
		opciones
	)


## Búsqueda de coste uniforme/A*: es_meta(celda) -> bool y heuristica(celda) ->
## int. Coste de un paso = 1 + |dy| (así la heurística Manhattan 3D de
## buscar_ruta() es admisible).
func _buscar(origen: Vector3i, es_meta: Callable, heuristica: Callable, opciones: Dictionary) -> Array[Vector3i]:
	var ruta: Array[Vector3i] = []
	var bloqueadas: Dictionary = opciones.get("bloqueadas", {})
	var ignorar: Array = opciones.get("ignorar_fantasmas", [])
	if not es_transitable(origen, ignorar):
		return ruta

	var costo: Dictionary = {origen: 0}
	var padre: Dictionary = {}
	var cerrados: Dictionary = {}
	var abiertos: Array = []
	var desempate := 0
	var h_origen: int = heuristica.call(origen)
	_meter(abiertos, [h_origen, h_origen, desempate, origen])
	var expandidos := 0
	while not abiertos.is_empty():
		var actual: Vector3i = _sacar(abiertos)[3]
		if cerrados.has(actual):
			continue
		if es_meta.call(actual):
			var celda: Vector3i = actual
			while celda != origen:
				ruta.append(celda)
				celda = padre[celda]
			ruta.reverse()
			return ruta
		cerrados[actual] = true
		expandidos += 1
		if expandidos > max_nodos:
			return ruta
		for vecino in vecinos(actual, ignorar):
			if cerrados.has(vecino) or bloqueadas.has(vecino):
				continue
			var nuevo_costo: int = costo[actual] + 1 + absi(vecino.y - actual.y)
			if not costo.has(vecino) or nuevo_costo < costo[vecino]:
				costo[vecino] = nuevo_costo
				padre[vecino] = actual
				desempate += 1
				var h: int = heuristica.call(vecino)
				_meter(abiertos, [nuevo_costo + h, h, desempate, vecino])
	return ruta


static func _heuristica(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y) + absi(a.z - b.z)


## Cola de prioridad: monticulo binario de [f, h, orden_de_inserción, celda].
## Desempata por menor h (más cerca del destino) y luego por orden de inserción,
## que hace determinista la búsqueda. Sin el desempate por h, en terreno llano
## abierto todas las celdas del rectángulo origen-destino tienen el mismo f y
## A* degenera en búsqueda en anchura (agota el tope en rutas largas).
static func _menor(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return a[2] < b[2]


static func _meter(monticulo: Array, elemento: Array) -> void:
	monticulo.append(elemento)
	var i: int = monticulo.size() - 1
	while i > 0:
		var padre_i: int = (i - 1) >> 1
		if not _menor(monticulo[i], monticulo[padre_i]):
			break
		var temporal: Array = monticulo[i]
		monticulo[i] = monticulo[padre_i]
		monticulo[padre_i] = temporal
		i = padre_i


static func _sacar(monticulo: Array) -> Array:
	var cima: Array = monticulo[0]
	var ultimo: Array = monticulo.pop_back()
	if not monticulo.is_empty():
		monticulo[0] = ultimo
		var i := 0
		var n: int = monticulo.size()
		while true:
			var izquierdo := 2 * i + 1
			var derecho := izquierdo + 1
			var menor := i
			if izquierdo < n and _menor(monticulo[izquierdo], monticulo[menor]):
				menor = izquierdo
			if derecho < n and _menor(monticulo[derecho], monticulo[menor]):
				menor = derecho
			if menor == i:
				break
			var temporal: Array = monticulo[i]
			monticulo[i] = monticulo[menor]
			monticulo[menor] = temporal
			i = menor
	return cima
```

- [ ] **Step 4: Ejecutar y verificar que pasa (y que las 13 pruebas anteriores siguen pasando)**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/BuscadorRutasTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: `=== Las 17 pruebas de BuscadorRutas pasaron correctamente ===` y `=== Las 13 pruebas de Colonos pasaron correctamente ===` (Colonos usa el buscador; no debe romperse).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BuscadorRutas.gd godot/scripts/BuscadorRutasTest.gd
git commit -m "feat: BuscadorRutas ignora los fantasmas de una obra con permiso y busca salidas" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: `CuerposObra.gd` — colisión de los fantasmas por obra

**Files:**
- Create: `godot/scripts/CuerposObra.gd`
- Create: `godot/scripts/FantasmasPermeablesTest.gd`
- Create: `godot/scenes/FantasmasPermeablesTest.tscn`

**Interfaces:**
- Consumes: nada de otras tareas.
- Produces (los usa `VoxelWorld.gd` en la Tarea 3):
  - `CuerposObra.new()` — un `Node3D`.
  - `sincronizar(id: int, celdas: Array) -> void` — deja el cuerpo de la obra `id` con una caja (1×1×1, centrada en `celda + 0.5`) por cada `Vector3i` distinto de `celdas`; sin celdas, libera el cuerpo.
  - `liberar(id: int) -> void`.
  - `cuerpo_de(id: int) -> StaticBody3D` (o `null`).
  - `cantidad_formas(id: int) -> int`.

- [ ] **Step 1: Crear la escena y las pruebas (fallarán)**

`godot/scenes/FantasmasPermeablesTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/FantasmasPermeablesTest.gd" id="1"]

[node name="FantasmasPermeablesTest" type="Node"]
script = ExtResource("1")
```

`godot/scripts/FantasmasPermeablesTest.gd`:

```gdscript
extends Node

## Pruebas de los fantasmas de obra permeables hacia afuera: CuerposObra (con
## física real: un CharacterBody3D contra el cuerpo de la obra) y, desde la
## Tarea 3, los permisos y la puerta de inicio de obra de VoxelWorld. Esta
## escena espera fotogramas de física, así que se ejecuta con
## --quit-after 3000 y termina sola con get_tree().quit().

const CuerposObra = preload("res://scripts/CuerposObra.gd")


func _ready() -> void:
	await ejecutar_pruebas()
	get_tree().quit()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: sincronizar() deja una caja por celda distinta y libera al quedar vacío ===")
	var cuerpos := CuerposObra.new()
	add_child(cuerpos)
	cuerpos.sincronizar(1, [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0)])  # repetida: cuenta una vez
	assert(cuerpos.cantidad_formas(1) == 2)
	assert(cuerpos.cuerpo_de(1) != null)
	cuerpos.sincronizar(1, [Vector3i(1, 0, 0)])
	assert(cuerpos.cantidad_formas(1) == 1, "quita las cajas de las celdas que ya no son fantasma")
	cuerpos.sincronizar(2, [Vector3i(5, 0, 0)])
	assert(cuerpos.cuerpo_de(1) != cuerpos.cuerpo_de(2), "cada obra tiene su propio cuerpo")
	cuerpos.sincronizar(1, [])
	assert(cuerpos.cuerpo_de(1) == null and cuerpos.cantidad_formas(1) == 0, "sin fantasmas, el cuerpo se libera")
	assert(cuerpos.cuerpo_de(2) != null, "la otra obra no se toca")
	cuerpos.liberar(2)
	assert(cuerpos.cuerpo_de(2) == null)

	print("\n=== TEST 2: un CharacterBody3D choca con el cuerpo de la obra salvo con una excepción ===")
	cuerpos.sincronizar(3, [Vector3i(0, 0, 0)])  # una caja en [0,1]^3
	var jugador := CharacterBody3D.new()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.4
	capsula.height = 1.8
	forma.shape = capsula
	forma.position = Vector3(0, 0.9, 0)
	jugador.add_child(forma)
	add_child(jugador)
	jugador.global_position = Vector3(3.5, 0.0, 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var camino := Vector3(-3.0, 0.0, 0.0)  # cruza la caja
	assert(jugador.move_and_collide(camino, true) != null, "sin excepción, choca con el fantasma")
	jugador.add_collision_exception_with(cuerpos.cuerpo_de(3))
	assert(jugador.move_and_collide(camino, true) == null, "con la excepción de esa obra, la atraviesa")
	jugador.remove_collision_exception_with(cuerpos.cuerpo_de(3))
	assert(jugador.move_and_collide(camino, true) != null, "al quitarla, vuelve a chocar")
	cuerpos.sincronizar(4, [Vector3i(0, 0, 0)])  # otra obra, en el mismo sitio
	await get_tree().physics_frame
	await get_tree().physics_frame
	jugador.add_collision_exception_with(cuerpos.cuerpo_de(3))
	assert(jugador.move_and_collide(camino, true) != null, "la excepción de una obra no vale para otra")

	print("\n=== Las 2 pruebas de CuerposObra pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/FantasmasPermeablesTest.tscn --quit-after 3000 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA con `Parse Error` (no existe `CuerposObra.gd`).

- [ ] **Step 3: Implementar `godot/scripts/CuerposObra.gd`**

```gdscript
extends Node3D

## Colisión de los bloques "fantasma" de cada obra. GridMap no permite
## colisión por celda ni por cara (su colisión sale de las formas del ítem de
## la MeshLibrary, en una sola capa por nodo), así que el ítem "fantasma" no
## lleva formas (ver VoxelWorld._indexar_biblioteca()) y la colisión la da un
## StaticBody3D POR OBRA con una caja por celda fantasma pendiente. Así quien
## tiene permiso de salida sobre una obra puede ignorar solo ESA obra con
## add_collision_exception_with(). Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Sección 6).
##
## Hijo de VoxelWorld (que está en el origen y usa celdas de 1x1x1, así que las
## coordenadas locales son las del mundo): la caja de la celda c está centrada
## en c + (0.5, 0.5, 0.5). Capa de colisión 1, la del mundo, para que el
## raycast del jugador y el picking de CamaraCenital los siga detectando.

var _caja := BoxShape3D.new()  # 1x1x1 por defecto; se comparte entre todas las formas
var _cuerpos: Dictionary = {}  # int (id de obra) -> StaticBody3D
var _formas: Dictionary = {}  # int -> Dictionary (Vector3i -> CollisionShape3D)


## Deja el cuerpo de la obra "id" con una caja por cada celda distinta de
## "celdas": añade las que faltan y quita las que sobran. Sin celdas libera el
## cuerpo por completo.
func sincronizar(id: int, celdas: Array) -> void:
	var deseadas: Dictionary = {}
	for celda: Vector3i in celdas:
		deseadas[celda] = true
	if deseadas.is_empty():
		liberar(id)
		return
	if not _cuerpos.has(id):
		var nuevo := StaticBody3D.new()
		nuevo.name = "Obra_%d" % id
		add_child(nuevo)
		_cuerpos[id] = nuevo
		_formas[id] = {}
	var cuerpo: StaticBody3D = _cuerpos[id]
	var formas: Dictionary = _formas[id]
	for celda: Vector3i in formas.keys():
		if not deseadas.has(celda):
			var sobrante: CollisionShape3D = formas[celda]
			cuerpo.remove_child(sobrante)
			sobrante.free()
			formas.erase(celda)
	for celda: Vector3i in deseadas:
		if not formas.has(celda):
			var forma := CollisionShape3D.new()
			forma.shape = _caja
			forma.position = Vector3(celda) + Vector3(0.5, 0.5, 0.5)
			cuerpo.add_child(forma)
			formas[celda] = forma


func liberar(id: int) -> void:
	if not _cuerpos.has(id):
		return
	var cuerpo: StaticBody3D = _cuerpos[id]
	remove_child(cuerpo)
	cuerpo.free()
	_cuerpos.erase(id)
	_formas.erase(id)


func cuerpo_de(id: int) -> StaticBody3D:
	return _cuerpos.get(id, null)


func cantidad_formas(id: int) -> int:
	return _formas[id].size() if _formas.has(id) else 0
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/FantasmasPermeablesTest.tscn --quit-after 3000 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con `=== Las 2 pruebas de CuerposObra pasaron correctamente ===`.

Si el TEST 2 falla en la primera colisión (`move_and_collide` devuelve `null`): los fotogramas de física no habían corrido todavía o la cápsula no cruza la caja; comprobar que se esperan los dos `physics_frame` y que `--quit-after` es 3000. Si sigue fallando, es que en este motor las formas añadidas a un `StaticBody3D` que ya está en el árbol necesitan un fotograma más: añadir un tercer `await get_tree().physics_frame` antes de la primera comprobación y dejar la observación anotada en el comentario de la clase.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/CuerposObra.gd* godot/scripts/FantasmasPermeablesTest.gd* godot/scenes/FantasmasPermeablesTest.tscn
git commit -m "feat: CuerposObra, un cuerpo de colisión por obra para sus fantasmas" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 3: `VoxelWorld` — colisión por obra, volumen, permisos y puerta de inicio

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/FantasmasPermeablesTest.gd`

**Interfaces:**
- Consumes: `CuerposObra` (Tarea 2).
- Produces (las usan `Player.gd` y `Colonos.gd` en las Tareas 4 y 5):
  - `signal obra_a_fantasma(id: int)` — se emite al emplazar una obra (`iniciar_construccion_fantasma`) y al empezar a deconstruir un edificio completo.
  - `otorgar_permiso_salida(id_obra: int, entidad) -> void`, `revocar_permiso_salida(id_obra: int, entidad) -> void`, `tiene_permiso_salida(id_obra: int, entidad) -> bool`, `hay_ocupantes(id_obra: int) -> bool`, `obras_con_permiso(entidad) -> Array[int]`. `entidad` es un `int` (colono) o `"avatar"`.
  - `volumen_de_obra(id_obra: int) -> Dictionary` (`{"min": Vector3i, "max": Vector3i}` o `{}`), `celda_en_volumen(id_obra: int, celda: Vector3i) -> bool`.
  - `cuerpos_obra() -> Node3D` y `cuerpo_de_obra(id_obra: int) -> Node` (el `StaticBody3D` de la obra o `null`).
  - `surtir_construccion(celda)` devuelve `{"bloqueada": true}` mientras `hay_ocupantes(id)`.

- [ ] **Step 1: Agregar las pruebas de `VoxelWorld` (fallarán)**

En `FantasmasPermeablesTest.gd`, agregar junto al `preload` existente:

```gdscript
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
```

Agregar este método (mismo patrón de las pruebas existentes: `VoxelWorld.new()` sin `_ready`, así no se genera el terreno):

```gdscript
func _mundo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE
	mundo._indexar_biblioteca()
	return mundo
```

En `ejecutar_pruebas()`, cambiar el `print` final de las 2 pruebas por las siguientes (y el mensaje final por `Las 8 pruebas`):

```gdscript
	print("\n=== TEST 3: el ítem fantasma de la MeshLibrary ya no lleva colisión ===")
	var mundo3 := _mundo()
	assert(mundo3.mesh_library.get_item_shapes(mundo3._id_por_tipo["fantasma"]).is_empty(), "la colisión la dan los cuerpos por obra")

	print("\n=== TEST 4: cada obra tiene un cuerpo con una caja por fantasma pendiente ===")
	var mundo4 := _mundo()
	var c1 := Vector3i(10, 1, 10)
	var c2 := Vector3i(11, 1, 10)
	var id4: int = mundo4.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(mundo4.cuerpos_obra().cantidad_formas(id4) == 2)
	assert(mundo4.cuerpo_de_obra(id4) != null)
	mundo4.surtir_construccion(c1)  # convierte la primera celda pendiente (c1) en pared
	assert(mundo4.cuerpos_obra().cantidad_formas(id4) == 1, "un fantasma menos, una caja menos")
	mundo4.surtir_construccion(c1)  # convierte c2: la obra queda completa
	assert(mundo4.cuerpo_de_obra(id4) == null, "sin fantasmas pendientes, el cuerpo se libera")

	print("\n=== TEST 5: el volumen de la obra es la caja envolvente de sus celdas ===")
	var mundo5 := _mundo()
	var id5: int = mundo5.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(mundo5.volumen_de_obra(id5) == {"min": Vector3i(10, 1, 10), "max": Vector3i(11, 1, 10)})
	assert(mundo5.celda_en_volumen(id5, Vector3i(10, 1, 10)) and mundo5.celda_en_volumen(id5, Vector3i(11, 1, 10)))
	assert(not mundo5.celda_en_volumen(id5, Vector3i(12, 1, 10)) and not mundo5.celda_en_volumen(id5, Vector3i(10, 2, 10)))
	assert(not mundo5.celda_en_volumen(999, c1), "una obra que no existe no tiene volumen")

	print("\n=== TEST 6: los permisos de salida bloquean el inicio de la obra hasta que se revocan ===")
	var mundo6 := _mundo()
	var id6: int = mundo6.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(not mundo6.hay_ocupantes(id6))
	mundo6.otorgar_permiso_salida(id6, 42)
	mundo6.otorgar_permiso_salida(id6, "avatar")
	assert(mundo6.tiene_permiso_salida(id6, 42) and mundo6.hay_ocupantes(id6))
	assert(mundo6.obras_con_permiso("avatar") == [id6] and mundo6.obras_con_permiso(7).is_empty())
	var rechazo: Dictionary = mundo6.surtir_construccion(c1)
	assert(rechazo.get("bloqueada", false), "con alguien dentro no se puede iniciar")
	assert(mundo6.obtener_tipo(c1) == "fantasma", "y no cambia nada")
	mundo6.revocar_permiso_salida(id6, 42)
	assert(mundo6.hay_ocupantes(id6), "aún queda el avatar")
	mundo6.revocar_permiso_salida(id6, "avatar")
	assert(not mundo6.hay_ocupantes(id6))
	var avance: Dictionary = mundo6.surtir_construccion(c1)
	assert(not avance.has("bloqueada") and mundo6.obtener_tipo(c1) == "pared", "sin ocupantes, la obra avanza")

	print("\n=== TEST 7: obra_a_fantasma se emite al emplazar y al empezar a deconstruir un edificio completo ===")
	var mundo7 := _mundo()
	var emitidas: Array[int] = []
	mundo7.obra_a_fantasma.connect(func(id: int) -> void: emitidas.append(id))
	var id7: int = mundo7.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(emitidas == [id7], "al emplazar")
	mundo7.surtir_construccion(c1)
	mundo7.surtir_construccion(c1)  # completa
	assert(emitidas == [id7], "completar no lo emite")
	mundo7.procesar_deconstruccion(c1)  # primer paso con el edificio entero: c2 vuelve a fantasma
	assert(emitidas == [id7, id7], "al empezar a deconstruir un edificio completo")
	assert(mundo7.cuerpos_obra().cantidad_formas(id7) == 1, "el fantasma revertido tiene su caja")
	mundo7.procesar_deconstruccion(c1)  # segundo paso: el edificio ya no estaba entero
	assert(emitidas == [id7, id7], "solo se emite una vez por deconstrucción")

	print("\n=== TEST 8: eliminar el edificio libera su cuerpo, su volumen y sus permisos ===")
	var mundo8 := _mundo()
	var id8: int = mundo8.iniciar_construccion_fantasma([], {}, [c1], {c1: "pared"})
	mundo8.otorgar_permiso_salida(id8, 42)
	mundo8.procesar_deconstruccion(c1)  # sin nada construido: lista para remoción
	mundo8.eliminar_edificio(id8)
	assert(mundo8.cuerpo_de_obra(id8) == null)
	assert(mundo8.volumen_de_obra(id8).is_empty() and not mundo8.hay_ocupantes(id8))

	print("\n=== Las 8 pruebas de fantasmas permeables pasaron correctamente ===")
```

y borrar la línea `print("\n=== Las 2 pruebas de CuerposObra pasaron correctamente ===")`.

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/FantasmasPermeablesTest.tscn --quit-after 3000 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA (`Invalid call. Nonexistent function 'cuerpos_obra'` o `Assertion failed` en el TEST 3).

- [ ] **Step 3: Implementar en `VoxelWorld.gd`**

**(a)** Junto a los otros `const ... preload(...)` del inicio, agregar:

```gdscript
const CuerposObra = preload("res://scripts/CuerposObra.gd")
```

**(b)** Junto a la señal `fantasmas_cambiados` (y sus variables de edificio), agregar:

```gdscript
## Se emite cuando los bloques de una obra pasan a ser fantasma: al emplazar un
## blueprint (iniciar_construccion_fantasma()) y al empezar a deconstruir un
## edificio completo (primer paso de procesar_deconstruccion()). Quien esté
## dentro del volumen de la obra debe recibir un permiso de salida (Player.gd
## para el avatar, Colonos.gd para los colonos).
signal obra_a_fantasma(id: int)

## Permisos de salida: id de obra -> {entidad -> true}. "entidad" es el id de un
## colono (int) o "avatar". Con permiso, la entidad ignora la colisión con los
## fantasmas de ESA obra hasta que sale de su volumen; sin él, los fantasmas
## son sólidos (no se puede entrar). Mientras haya alguno, la obra no puede
## avanzar (ver surtir_construccion()).
var permisos_salida: Dictionary = {}

## Volumen de cada obra: id -> {"min": Vector3i, "max": Vector3i}, la caja
## envolvente de todas sus celdas (estructura y preparación del terreno).
var edificio_volumen: Dictionary = {}

var _cuerpos_obra: Node3D = null
```

**(c)** En `_indexar_biblioteca()`, al final de la función, agregar:

```gdscript
	# La colisión de los fantasmas la dan los cuerpos por obra (CuerposObra),
	# no el GridMap: GridMap no permite colisión por celda ni por cara, y el
	# permiso de salida necesita ignorar SOLO los fantasmas de una obra.
	# ponytail: un fantasma sin obra (huérfano) queda sin colisión;
	# eliminar_edificio() ya retira los suyos, así que no debería existir.
	if _id_por_tipo.has("fantasma"):
		mesh_library.set_item_shapes(_id_por_tipo["fantasma"], [])
```

**(d)** Agregar estas funciones (por ejemplo junto a `celdas_fantasma_ocupadas()`):

```gdscript
## Nodo con los cuerpos de colisión de las obras; se crea la primera vez que
## hace falta (así también existe en las pruebas, que no llaman a _ready()).
func cuerpos_obra() -> Node3D:
	if _cuerpos_obra == null:
		_cuerpos_obra = CuerposObra.new()
		add_child(_cuerpos_obra)
	return _cuerpos_obra


## El StaticBody3D con la colisión de los fantasmas de la obra, o null.
func cuerpo_de_obra(id: int) -> Node:
	return cuerpos_obra().cuerpo_de(id)


## Celdas de la obra "id" que hoy son "fantasma": las pendientes de su
## estructura y las de su cola de preparación del terreno.
func _celdas_fantasma_de(id: int) -> Array[Vector3i]:
	var resultado: Array[Vector3i] = []
	for celda: Vector3i in edificio_orden.get(id, []):
		if obtener_tipo(celda) == "fantasma":
			resultado.append(celda)
	if edificio_relleno_cola.has(id):
		for celda: Vector3i in Construccion.celdas_pendientes(edificio_relleno_cola[id]):
			if obtener_tipo(celda) == "fantasma":
				resultado.append(celda)
	return resultado


## Deja el cuerpo de colisión de la obra "id" con una caja por fantasma
## pendiente. Se llama tras cada operación que cambia sus fantasmas.
func _sincronizar_cuerpo(id: int) -> void:
	cuerpos_obra().sincronizar(id, _celdas_fantasma_de(id))


static func _calcular_volumen(celdas: Array) -> Dictionary:
	if celdas.is_empty():
		return {}
	var minimo: Vector3i = celdas[0]
	var maximo: Vector3i = celdas[0]
	for celda: Vector3i in celdas:
		minimo = Vector3i(mini(minimo.x, celda.x), mini(minimo.y, celda.y), mini(minimo.z, celda.z))
		maximo = Vector3i(maxi(maximo.x, celda.x), maxi(maximo.y, celda.y), maxi(maximo.z, celda.z))
	return {"min": minimo, "max": maximo}


func volumen_de_obra(id: int) -> Dictionary:
	return edificio_volumen.get(id, {})


func celda_en_volumen(id: int, celda: Vector3i) -> bool:
	var volumen: Dictionary = edificio_volumen.get(id, {})
	if volumen.is_empty():
		return false
	var minimo: Vector3i = volumen["min"]
	var maximo: Vector3i = volumen["max"]
	return celda.x >= minimo.x and celda.x <= maximo.x \
		and celda.y >= minimo.y and celda.y <= maximo.y \
		and celda.z >= minimo.z and celda.z <= maximo.z


func otorgar_permiso_salida(id_obra: int, entidad) -> void:
	if not permisos_salida.has(id_obra):
		permisos_salida[id_obra] = {}
	permisos_salida[id_obra][entidad] = true


func revocar_permiso_salida(id_obra: int, entidad) -> void:
	if not permisos_salida.has(id_obra):
		return
	permisos_salida[id_obra].erase(entidad)
	if permisos_salida[id_obra].is_empty():
		permisos_salida.erase(id_obra)


func tiene_permiso_salida(id_obra: int, entidad) -> bool:
	return permisos_salida.has(id_obra) and permisos_salida[id_obra].has(entidad)


## true si alguien sigue dentro de la obra (con permiso vigente): mientras
## tanto no se puede iniciar ni avanzar.
func hay_ocupantes(id_obra: int) -> bool:
	return permisos_salida.has(id_obra)


func obras_con_permiso(entidad) -> Array[int]:
	var resultado: Array[int] = []
	for id_obra: int in permisos_salida:
		if permisos_salida[id_obra].has(entidad):
			resultado.append(id_obra)
	return resultado
```

**(e)** Enganchar las operaciones existentes:

- En `iniciar_construccion_fantasma()`, reemplazar el final

```gdscript
	fantasmas_cambiados.emit()
	return id
```

por:

```gdscript
	edificio_volumen[id] = _calcular_volumen(orden_relleno + orden_estructura)
	_sincronizar_cuerpo(id)
	fantasmas_cambiados.emit()
	obra_a_fantasma.emit(id)
	return id
```

- En `registrar_edificio_completo()`, antes de `return id`, agregar:

```gdscript
	edificio_volumen[id] = _calcular_volumen(orden)
```

- En `surtir_construccion()`, justo después del bloque

```gdscript
	var id: int = id_de_edificio(celda)
	if id == -1:
		return {}
```

agregar la puerta de inicio de obra:

```gdscript
	# Alguien sigue dentro del sitio (tiene permiso de salida): la obra no
	# puede iniciarse ni avanzar hasta que salga. Se devuelve un diccionario NO
	# vacío para que Player._colocar() no lo confunda con "esto no es una obra"
	# y termine colocando un bloque nuevo contra el fantasma.
	if hay_ocupantes(id):
		return {"bloqueada": true}
```

y sincronizar el cuerpo tras cada avance: en la rama de la cola de relleno, después de `_aplicar_paso_cola(resultado_grupo)`:

```gdscript
			_sincronizar_cuerpo(id)
```

y en la rama de la estructura, después de `edificio_progreso[id] = progreso + 1`:

```gdscript
	_sincronizar_cuerpo(id)
```

- En `procesar_deconstruccion()`, después de `fantasmas_cambiados.emit()`, agregar:

```gdscript
	_sincronizar_cuerpo(id)
	if progreso == orden.size():
		obra_a_fantasma.emit(id)  # el edificio entero empieza a volver a fantasma
```

- En `eliminar_edificio()`, antes de su `fantasmas_cambiados.emit()` final, agregar:

```gdscript
	cuerpos_obra().liberar(id)
	edificio_volumen.erase(id)
	permisos_salida.erase(id)
```

- [ ] **Step 4: Ejecutar y verificar que pasa (y que las escenas existentes no se rompen)**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/FantasmasPermeablesTest.tscn --quit-after 3000 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/Test.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/ConstruccionTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: `=== Las 8 pruebas de fantasmas permeables pasaron correctamente ===` (el mensaje final cuenta las 2 de `CuerposObra` más las 6 nuevas), y `=== Las 63 pruebas de BlueprintValidator pasaron correctamente ===` (`Test.tscn` recorre muchas obras fantasma: es la prueba de que sincronizar cuerpos no rompe nada). `ConstruccionTest` no imprime una línea final con «pasaron»: basta con que no aparezca ningún `Assertion`/`SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/FantasmasPermeablesTest.gd
git commit -m "feat: fantasmas de obra con cuerpo propio, permisos de salida y puerta de inicio" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 4: El avatar — permiso, excepción de colisión y aviso de obra bloqueada

**Files:**
- Modify: `godot/scripts/Player.gd`
- Modify: `godot/scripts/Main.gd`

**Interfaces:**
- Consumes: `VoxelWorld.obra_a_fantasma`, `otorgar_permiso_salida`, `revocar_permiso_salida`, `obras_con_permiso`, `celda_en_volumen`, `cuerpo_de_obra` (Tarea 3).
- Produces: `Player._on_obra_a_fantasma(id_obra: int) -> void` (conectada en `Main.gd`).

Estas funciones dependen del árbol de escena (`hud`, `mundo`, física del jugador), así que no tienen prueba automática; el comportamiento físico ya lo cubre el TEST 2 de la Tarea 2 y se verifica con la lista manual del final.

- [ ] **Step 1: Tratar la obra bloqueada al surtir**

En `Player._colocar()`, reemplazar

```gdscript
	var resultado: Dictionary = mundo.surtir_construccion(celda)
	if not resultado.is_empty():
		if resultado.get("completa", false):
			_completar_construccion(resultado["metadata"])
		return
```

por:

```gdscript
	var resultado: Dictionary = mundo.surtir_construccion(celda)
	if not resultado.is_empty():
		if resultado.get("bloqueada", false):
			print("Hay alguien dentro del sitio de la obra: deben salir antes de iniciarla.")
		elif resultado.get("completa", false):
			_completar_construccion(resultado["metadata"])
		return
```

- [ ] **Step 2: Permiso de salida y excepción de colisión del avatar**

Agregar estas funciones a `Player.gd` (por ejemplo tras `_celda_en()`):

```gdscript
## true si los pies o la cabeza del avatar están dentro del volumen de la obra.
func _dentro_de_obra(id_obra: int) -> bool:
	var pies: Vector3i = _celda_en(global_position + Vector3.UP * 0.1)
	return mundo.celda_en_volumen(id_obra, pies) or mundo.celda_en_volumen(id_obra, pies + Vector3i(0, 1, 0))


## Una obra acaba de pasar a fantasma (se emplazó un blueprint o empezó a
## deconstruirse un edificio completo): si el avatar está dentro de su
## volumen, recibe permiso para salir sin chocar con sus fantasmas (Sección 6
## del spec de colonos y pathfinding). Conectada en Main.gd.
func _on_obra_a_fantasma(id_obra: int) -> void:
	if mundo != null and _dentro_de_obra(id_obra):
		mundo.otorgar_permiso_salida(id_obra, "avatar")


## Mantiene la excepción de colisión del avatar con las obras donde tiene
## permiso vigente, y lo revoca (para siempre) al salir de su volumen: desde
## fuera los fantasmas vuelven a ser sólidos y no se puede volver a entrar.
## Se llama cada frame de física (add_collision_exception_with es idempotente,
## y el cuerpo de la obra puede haberse recreado desde el frame anterior).
func _actualizar_permisos_avatar() -> void:
	for id_obra in mundo.obras_con_permiso("avatar"):
		var cuerpo: Node = mundo.cuerpo_de_obra(id_obra)
		if _dentro_de_obra(id_obra):
			if cuerpo != null:
				add_collision_exception_with(cuerpo)
		else:
			mundo.revocar_permiso_salida(id_obra, "avatar")
			if cuerpo != null:
				remove_collision_exception_with(cuerpo)
```

En `_physics_process()`, justo antes de `move_and_slide()`, agregar:

```gdscript
	if mundo != null:
		_actualizar_permisos_avatar()
```

- [ ] **Step 3: Conectar la señal en `Main.gd`**

En `Main._ready()`, después de `Colonos.mundo = mundo`, agregar:

```gdscript
	mundo.obra_a_fantasma.connect(jugador._on_obra_a_fantasma)
```

- [ ] **Step 4: Comprobar que `Main.tscn` arranca sin errores**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Invalid"
```

Expected: sin salida.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Player.gd godot/scripts/Main.gd
git commit -m "feat: el avatar sale de una obra que se emplaza sobre él y no puede volver a entrar" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 5: Colonos — evacuar las obras

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- Consumes: `BuscadorRutas.buscar_salida`, `es_transitable(celda, ignorar)`, `buscar_ruta(..., {"ignorar_fantasmas"})` (Tarea 1); `VoxelWorld.obra_a_fantasma`, `celda_en_volumen`, `otorgar_permiso_salida`, `revocar_permiso_salida` (Tarea 3).
- Produces: cada colono gana los campos `"evacuando": int` (id de la obra que evacúa, `-1` si no) y `"ruta_de_evacuacion": bool`. `Colonos._on_obra_a_fantasma(id_obra: int)`.

- [ ] **Step 1: Ampliar el mundo falso y agregar las pruebas 14 y 15 (fallarán)**

En `ColonosTest.gd`, dentro de `class MundoFalso extends RefCounted:`, agregar:

```gdscript
	var ids: Dictionary = {}  # Vector3i -> int: la obra de cada fantasma
	var volumenes: Dictionary = {}  # int -> {"min": Vector3i, "max": Vector3i}
	var permisos: Dictionary = {}  # int -> Dictionary (entidad -> true)

	func id_de_edificio(celda: Vector3i) -> int:
		return ids.get(celda, -1)

	func poner_fantasma(celda: Vector3i, id_obra: int) -> void:
		celdas[celda] = "fantasma"
		ids[celda] = id_obra

	func celda_en_volumen(id: int, celda: Vector3i) -> bool:
		var v: Dictionary = volumenes.get(id, {})
		if v.is_empty():
			return false
		return celda.x >= v["min"].x and celda.x <= v["max"].x \
			and celda.y >= v["min"].y and celda.y <= v["max"].y \
			and celda.z >= v["min"].z and celda.z <= v["max"].z

	func otorgar_permiso_salida(id_obra: int, entidad) -> void:
		if not permisos.has(id_obra):
			permisos[id_obra] = {}
		permisos[id_obra][entidad] = true

	func revocar_permiso_salida(id_obra: int, entidad) -> void:
		if permisos.has(id_obra):
			permisos[id_obra].erase(entidad)
			if permisos[id_obra].is_empty():
				permisos.erase(id_obra)
```

Antes del `print` final, agregar (y cambiar el final a `Las 15 pruebas`):

```gdscript
	print("\n=== TEST 14: Un colono dentro de una obra recibe permiso, sale y no puede volver a entrar ===")
	var mundo13 := _mundo_llano()
	for x in range(3, 6):  # cubo fantasma macizo de 3x3x2 (obra 7)
		for z in range(3, 6):
			mundo13.poner_fantasma(Vector3i(x, 1, z), 7)
			mundo13.poner_fantasma(Vector3i(x, 2, z), 7)
	mundo13.volumenes[7] = {"min": Vector3i(3, 1, 3), "max": Vector3i(5, 2, 5)}
	var colonos13: Node = _nuevo(mundo13, CiudadScript.new())
	var id13: int = colonos13.agregar_colono("obrero", Vector3i(4, 1, 4))  # en el centro del cubo
	var c13: Dictionary = colonos13.colonos[id13]
	colonos13._on_obra_a_fantasma(7)
	assert(c13["evacuando"] == 7 and mundo13.permisos[7].has(id13), "recibe el permiso y empieza a evacuar")
	var salio := false
	for i in range(100):
		colonos13.avanzar(0.1)
		if c13["evacuando"] == -1:
			salio = true
			break
	assert(salio, "sale del volumen de la obra")
	assert(not mundo13.celda_en_volumen(7, c13["celda"]), "está fuera")
	assert(not mundo13.permisos.has(7), "el permiso se revocó al salir")
	for i in range(600):  # 60 s deambulando: los fantasmas ya son sólidos para él
		colonos13.avanzar(0.1)
		assert(not mundo13.celda_en_volumen(7, c13["celda"]), "no vuelve a entrar")

	print("\n=== TEST 15: Un colono fuera de la obra no recibe permiso ni cambia lo que hace ===")
	var mundo14 := _mundo_llano()
	mundo14.poner_fantasma(Vector3i(4, 1, 4), 9)
	mundo14.volumenes[9] = {"min": Vector3i(4, 1, 4), "max": Vector3i(4, 1, 4)}
	var colonos14: Node = _nuevo(mundo14, CiudadScript.new())
	var id14: int = colonos14.agregar_colono("obrero", Vector3i(1, 1, 1))
	colonos14._on_obra_a_fantasma(9)
	assert(colonos14.colonos[id14]["evacuando"] == -1 and not mundo14.permisos.has(9))

	print("\n=== Las 15 pruebas de Colonos pasaron correctamente ===")
```

y borrar la línea `print("\n=== Las 13 pruebas de Colonos pasaron correctamente ===")`.

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA (`Nonexistent function '_on_obra_a_fantasma'` o acceso a la clave `evacuando`).

- [ ] **Step 3: Implementar la evacuación en `Colonos.gd`**

**(a)** Reemplazar la propiedad `mundo` para conectar la señal de las obras:

```gdscript
var mundo: Object = null:
	set(valor):
		if mundo != null and mundo.has_signal("obra_a_fantasma") and mundo.obra_a_fantasma.is_connected(_on_obra_a_fantasma):
			mundo.obra_a_fantasma.disconnect(_on_obra_a_fantasma)
		mundo = valor
		_buscador = BuscadorRutas.new(valor) if valor != null else null
		if valor != null and valor.has_signal("obra_a_fantasma"):
			valor.obra_a_fantasma.connect(_on_obra_a_fantasma)
```

**(b)** En `agregar_colono()`, agregar dos claves al diccionario del colono:

```gdscript
		"evacuando": -1, "ruta_de_evacuacion": false,
```

(por ejemplo tras `"espera": 0.0, "bloqueo": 0.0,`).

**(c)** En `_retirar()`, antes de `colonos.erase(id)`, agregar:

```gdscript
	if colono["evacuando"] != -1:
		mundo.revocar_permiso_salida(colono["evacuando"], id)
```

**(d)** Agregar las funciones nuevas:

```gdscript
## Ids de obra cuyos fantasmas este colono puede atravesar: solo la que está
## evacuando.
func _ignorar_de(c: Dictionary) -> Array:
	return [c["evacuando"]] if c["evacuando"] != -1 else []


func _opciones_ruta(c: Dictionary) -> Dictionary:
	return {"bloqueadas": _bloqueadas_para(c["id"]), "ignorar_fantasmas": _ignorar_de(c)}


## Una obra acaba de pasar a fantasma: cada colono cuya celda esté dentro de
## su volumen recibe permiso de salida y pasa a evacuar (ver
## _avanzar_evacuacion()). Los de fuera no cambian nada. Conectada a
## VoxelWorld.obra_a_fantasma.
func _on_obra_a_fantasma(id_obra: int) -> void:
	for c in colonos.values():
		if c["evacuando"] == -1 and mundo.celda_en_volumen(id_obra, c["celda"]):
			mundo.otorgar_permiso_salida(id_obra, c["id"])
			c["evacuando"] = id_obra
			c["ruta_de_evacuacion"] = false  # se planifica en el siguiente paso, cuando no esté a medio paso


## Mientras evacúa no hace otra cosa: cuando ya no está dentro del volumen
## revoca su permiso (para siempre) y vuelve a lo suyo; si no, planifica o
## recorre la ruta de salida (que atraviesa los fantasmas de esa obra).
func _avanzar_evacuacion(c: Dictionary, delta: float) -> void:
	var id_obra: int = c["evacuando"]
	if not mundo.celda_en_volumen(id_obra, c["celda"]):
		mundo.revocar_permiso_salida(id_obra, c["id"])
		c["evacuando"] = -1
		c["ruta_de_evacuacion"] = false
		var vacia: Array[Vector3i] = []
		c["ruta"] = vacia
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
		return
	if c["espera"] > 0.0:
		c["espera"] -= delta
		return
	if not c["ruta_de_evacuacion"]:
		var vacia: Array[Vector3i] = []
		c["ruta"] = vacia  # abandona lo que hacía
		_planear_evacuacion(c)
		return
	if c["ruta"].is_empty():
		c["ruta_de_evacuacion"] = false  # se agotó o se rompió: se replanifica
		return
	_iniciar_paso(c, delta)


func _planear_evacuacion(c: Dictionary) -> void:
	var id_obra: int = c["evacuando"]
	var esta_dentro := func(celda: Vector3i) -> bool: return mundo.celda_en_volumen(id_obra, celda)
	var ruta: Array[Vector3i] = _buscador.buscar_salida(c["celda"], esta_dentro, _opciones_ruta(c))
	c["ruta"] = ruta
	c["ruta_de_evacuacion"] = not ruta.is_empty()
	if ruta.is_empty():
		c["espera"] = 1.0  # sin salida ahora mismo: reintenta en un segundo
```

**(e)** En `_avanzar_colono()`, entre el bloque `if c["moviendo"]:` y `if c["espera"] > 0.0:`, agregar:

```gdscript
	if c["evacuando"] != -1:
		_avanzar_evacuacion(c, delta)
		return
```

**(f)** Hacer que las rutas respeten la obra que se evacúa. En `_iniciar_paso()`, reemplazar `if not _buscador.es_transitable(siguiente):` por:

```gdscript
	if not _buscador.es_transitable(siguiente, _ignorar_de(c)):
```

En `_replanificar()`, reemplazar `_buscador.buscar_ruta(c["celda"], destino)` por:

```gdscript
_buscador.buscar_ruta(c["celda"], destino, {"ignorar_fantasmas": _ignorar_de(c)})
```

En `_esquivar()` y en `_elegir_destino()`, reemplazar `{"bloqueadas": _bloqueadas_para(c["id"])}` por `_opciones_ruta(c)`.

- [ ] **Step 4: Ejecutar y verificar que pasa (y que las pruebas 1-12 siguen pasando)**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con `=== Las 15 pruebas de Colonos pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: los colonos evacúan una obra que se emplaza sobre ellos" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 6: Documentación y verificación final

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (Sección 5 y encabezado)
- Modify: `PoC_8/Documento Técnico de Desarrollo_ PoC 8 - Pathfinding a Pie y Colonos NPC.md`

- [ ] **Step 1: GDD, Sección 5**

En "Estado de Implementación de la Construcción Asistida", a continuación de la viñeta **Construcción Fantasma Reversible**, agregar:

```
> * **Fantasmas de Obra Permeables hacia Afuera:** al emplazar un blueprint, o al empezar a deconstruir un edificio completo, los colonos y el avatar que estén dentro del volumen de la obra pueden atravesar sus bloques fantasma para salir, pero no pueden volver a entrar; desde fuera los fantasmas son sólidos. Los colonos evacúan solos. Nadie puede iniciar la construcción mientras haya alguien dentro del sitio (se avisa al jugador). Cada obra tiene su propio cuerpo de colisión, así que el permiso de una obra no sirve para atravesar otra.
```

En el encabezado, anteponer `**Fantasmas de obra permeables (2026-09-20):** los bloques fantasma se pueden atravesar solo hacia afuera por quien ya estaba dentro al emplazar la obra; los colonos evacúan y la obra no se inicia con alguien dentro (Sección 5). ` al texto de la versión 3.31 y cambiar `3.31` por `3.32`.

- [ ] **Step 2: Documento técnico de PoC 8**

En la sección "Fuera de alcance / Próximos pasos", reemplazar la primera viñeta (`Fantasmas de obra permeables hacia afuera (Plan 3 del mismo spec).`) por, y agregar antes de esa sección una nueva:

```
## **Fantasmas de obra permeables hacia afuera**

* **Problema:** al emplazar un blueprint, sus bloques `fantasma` son sólidos; quien estuviera en el sitio quedaba dentro de un sólido (el pathfinding no encontraba ruta desde su celda y el avatar quedaba atrapado).
* **Solución:** `GridMap` no permite colisión por celda ni por cara, así que el ítem `fantasma` de la `MeshLibrary` ya no lleva formas de colisión y cada obra tiene un `StaticBody3D` propio (`CuerposObra.gd`) con una caja por fantasma pendiente. Quien está dentro del volumen de la obra al emplazarla recibe un permiso de salida: el avatar ignora la colisión con ese cuerpo (`add_collision_exception_with`) y los colonos usan `ignorar_fantasmas` en `BuscadorRutas`. El permiso se revoca al salir y no se recupera. Los colonos con permiso evacúan por `buscar_salida()`.
* **Puerta de inicio de obra:** `VoxelWorld.surtir_construccion()` devuelve `{"bloqueada": true}` mientras haya un permiso vigente.
* **Alternativa no elegida:** una malla cóncava con solo las caras externas y `backface_collision = false`, que impediría entrar y dejaría salir sin permisos. No se garantiza que `GodotPhysics3D` la respete para el movimiento de un `CharacterBody3D`; queda como vía a explorar si se quiere simplificar.
```

y en "Fuera de alcance / Próximos pasos" dejar como primera viñeta: `* Deconstrucción marcada desde la cámara cenital con la tecla \`G\` (obreros NPC que desmontan un edificio marcado): diseño documentado en el spec, se implementa con el sub-proyecto de construcción por NPC.`

- [ ] **Step 3: Verificación final del trabajo completo**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
for escena in Test CiudadTest BuscadorRutasTest ColonosTest FantasmasPermeablesTest ConstruccionTest ZonificacionTest BlueprintsTest; do
  echo "== $escena"
  "$GD" --headless --path godot res://scenes/$escena.tscn --quit-after 3000 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
done
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Invalid"
```

Expected: cada escena con su línea `pasaron correctamente` (las que la imprimen) y ninguna línea de error; `Main.tscn` sin salida.

- [ ] **Step 4: Verificación manual (no automatizable en headless)**

En el editor de Godot 4.7, abrir `godot/scenes/Main.tscn` (con una casa construida y colonos dentro y fuera):
1. Emplazar un blueprint desde la cenital (`B`) **encima de colonos y del avatar**: los colonos que quedan dentro caminan hacia fuera atravesando los fantasmas; una vez fuera no pueden volver a entrar.
2. El avatar (en primera persona) dentro del sitio puede salir atravesando los fantasmas; al salir y volver a acercarse, los fantasmas son sólidos.
3. Con el avatar o un colono dentro, intentar surtir (clic derecho) un fantasma muestra el aviso «Hay alguien dentro del sitio de la obra...» y no avanza; sin nadie dentro, avanza normal.
4. Con dos obras vecinas: estar dentro de una no permite atravesar los fantasmas de la otra.
5. Deconstruir (`G`) una casa **con colonos dentro**: al empezar, salen; la capacidad de camas se retira al iniciar.
6. Surtir y deconstruir fantasmas con el raycast (minar/colocar sobre un fantasma) sigue funcionando: ahora el rayo golpea el cuerpo de la obra, no el `GridMap`.
7. En la cenital, el picking sobre un fantasma sigue eligiendo la celda correcta.

- [ ] **Step 5: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_8/Documento Técnico de Desarrollo_ PoC 8 - Pathfinding a Pie y Colonos NPC.md"
git commit -m "docs: fantasmas de obra permeables hacia afuera (GDD 3.32 y PoC 8)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

## Self-Review (Plan 3)

**Cobertura del spec, Sección 6:** permiso al emplazar y al empezar a deconstruir un edificio completo (Tarea 3, señal `obra_a_fantasma`), volumen = caja envolvente incluida la preparación de terreno (Tarea 3), exención por obra (Tareas 2 y 3: cuerpo por obra + excepción), revocación al salir y no re-concesión (Tareas 4 y 5), evacuación de colonos (Tarea 5), puerta de inicio de obra con aviso (Tareas 3 y 4), colisión fuera del `GridMap` (Tarea 3 c), alternativa geométrica documentada (Tarea 6). Diseño futuro de la tecla `G` en la cenital: solo documentado en el spec (fuera de alcance).

**Puntos a verificar (los marca el spec) resueltos aquí:** id del edificio para el registro (Plan 1), colisión del jugador con la puerta (Plan 2, `puerta_*` son libres para el buscador), raycast del jugador y picking de la cenital con cuerpos en vez de `GridMap` (el punto de impacto menos la normal·0,5 cae dentro de la caja, igual que con `GridMap`; se comprueba en la lista manual 6-7).

**Consistencia de nombres:** `otorgar_permiso_salida`/`revocar_permiso_salida`/`tiene_permiso_salida`/`hay_ocupantes`/`obras_con_permiso`/`volumen_de_obra`/`celda_en_volumen`/`cuerpo_de_obra`/`cuerpos_obra` se definen en la Tarea 3 y se usan tal cual en las Tareas 4 y 5 y en el mundo falso de `ColonosTest`. `buscar_salida`, `es_transitable(celda, ignorar)` y `opciones.ignorar_fantasmas` se definen en la Tarea 1.

**Riesgos que el ejecutor debe conocer:**
- Si la física en headless tarda en registrar las formas, el TEST 2 de `CuerposObra` puede necesitar un fotograma más (ver la nota del paso 4 de la Tarea 2).
- `Test.tscn` (63 pruebas de `BlueprintValidator`/`VoxelWorld`) es la red de seguridad de la Tarea 3: recorre muchas obras fantasma y ahora cada una crea y libera cuerpos de colisión.
- `mesh_library.set_item_shapes()` modifica en memoria el recurso compartido `BlockLibrary.res`; no se guarda a disco.
