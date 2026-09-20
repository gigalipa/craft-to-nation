# Colonos NPC y Pathfinding a Pie (Plan 2 de 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Colonos NPC que aparecen en el borde de la zona de influencia, viven en las casas (hogar), deambulan por el mundo voxel con un A\* propio, se evitan entre sí y esquivan al avatar, más un cuerpo visible para el avatar.

**Architecture:** `BuscadorRutas.gd` es un A\* puro (`RefCounted`) que consulta el mundo (`obtener_tipo`) en el momento, sin mallas de navegación. `Colonos.gd` es un autoload de estado y comportamiento puro (mismo patrón que `Ciudad.gd`), con dependencias inyectables (`mundo`, `ciudad`, `zona`) para probarlo sin escena. `ColonosRenderer.gd` solo dibuja y da cuerpo físico. `Ciudad.demografia` sigue siendo la fuente de verdad de las cantidades; `Colonos` reconcilia contra ella cuando `Ciudad` emite `tick_simulado`.

**Tech Stack:** Godot 4.7 (GDScript), `GodotPhysics3D`, pruebas como escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md` (Secciones 2, 3 y 3b). **Depende del Plan 1** (`docs/superpowers/plans/2026-09-20-poblacion-vivienda.md`): usa `Ciudad.demografia` con los 7 tipos, `Ciudad.edificios_residenciales`, `Ciudad.TIPOS_POBLACION` y la señal `Ciudad.tick_simulado`. El Plan 3 (fantasmas permeables) añade después `opciones.ignorar_fantasmas`, `buscar_salida()` y la evacuación; este plan no los incluye.

## Global Constraints

- GDScript con **tabulaciones** (CLAUDE.md).
- Documentación, mensajes del juego, comentarios y pruebas en **español**.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python. No tocar `docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md` ni el diff de `PoC_5/`. En cada commit, `git add` solo los archivos del paso.
- Verificación (CLAUDE.md): `godot/scenes/Test.tscn` con Godot 4.7 más las demás escenas `*Test.tscn` afectadas.
- Autoloads: `extends Node`, sin `class_name`.
- El NPC ocupa **2 celdas de alto**. Libres = `""`, `"puerta_inferior"`, `"puerta_superior"`; todo lo demás es sólido para el pathfinding (incluidos `"fantasma"`, `"follaje"`, `"madera"`, camas y baúles). Agua de 1 bloque de profundidad se cruza; de 2 o más, no.
- Movimientos: 4 ortogonales; sube 1 bloque, cae hasta 3 (`CAIDA_MAXIMA := 3`). Coste de un paso = `1 + |dy|`, con heurística Manhattan 3D (admisible con ese coste).
- `MAX_NODOS_EXPANDIDOS := 20000` por consulta.
- Valores placeholder: `VELOCIDAD_COLONO := 2.5` celdas/s, `ESPERA_BLOQUEO := 0.5` s, `INTENTOS_DESTINO := 8`, espera entre destinos de 1 a 3 s, `PROBABILIDAD_CASA := 0.5`.
- El colono no se acuesta en una cama: vive en una casa (hogar = id de edificio residencial de `VoxelWorld`), entra a ella y puede pararse sobre una cama. Los colonos llegan como `desempleado`.
- Los colonos y el avatar **no comparten celda**. El avatar es obstáculo en su celda y, si se mueve, también en la de adelante; los colonos lo esquivan pero **no huyen**.
- El cuerpo del avatar es visible **también en primera persona** (cápsula que termina por debajo del ojo).
- **Capas de colisión:** el mundo (terreno, edificios, fantasmas) está en la capa 1 (la de por defecto). Los cuerpos de los colonos van en la **capa 2**; solo el avatar los ve (`Player.collision_mask = 3`). El raycast del jugador (máscara 1) y el picking de `CamaraCenital.gd` (que se limita a la máscara 1) los atraviesan, para que un clic sobre un colono elija el terreno de debajo y no una celda equivocada.
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```

## Cómo ejecutar una escena de pruebas (headless)

Desde la raíz del repo, en bash:

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/BuscadorRutasTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Pasa si imprime una única línea `=== Las N pruebas de ... pasaron correctamente ===` y ninguna con `Assertion`, `SCRIPT ERROR` o `Parse Error`. (El ruido `ObjectDB instances were leaked` al salir es conocido.)

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `godot/scripts/BuscadorRutas.gd` | Crear | A\* puro: `es_transitable`, `vecinos`, `buscar_ruta` |
| `godot/scripts/BuscadorRutasTest.gd` + `godot/scenes/BuscadorRutasTest.tscn` | Crear | Pruebas con mundo falso |
| `godot/scripts/Colonos.gd` | Crear | Autoload: estado, hogar, reconciliación, movimiento, deambular, evitación |
| `godot/scripts/ColonosTest.gd` + `godot/scenes/ColonosTest.tscn` | Crear | Pruebas sin escena visual |
| `godot/scripts/ColonosRenderer.gd` | Crear | Malla y cuerpo físico por colono |
| `godot/project.godot` | Modificar | Registrar el autoload `Colonos` |
| `godot/scripts/Main.gd`, `godot/scenes/Main.tscn` | Modificar | Asignar `Colonos.mundo` y añadir el nodo `ColonosRenderer` |
| `godot/scripts/Player.gd` | Modificar | Informar a `Colonos` de la celda y velocidad del avatar |
| `godot/scenes/Player.tscn` | Modificar | Máscara de colisión 3 (mundo + colonos) y cuerpo visible del avatar |
| `godot/scripts/CamaraCenital.gd` | Modificar | Limitar sus 4 consultas físicas a la capa 1 (el mundo) |
| `PoC_8/…`, `PoC_4/…`, GDD Secciones 11 y 12 | Crear/Modificar | Documentación |

---

### Task 1: `BuscadorRutas.gd` — transitabilidad y A\*

**Files:**
- Create: `godot/scripts/BuscadorRutas.gd`
- Create: `godot/scripts/BuscadorRutasTest.gd`
- Create: `godot/scenes/BuscadorRutasTest.tscn`

**Interfaces:**
- Consumes: un objeto `mundo` con `obtener_tipo(celda: Vector3i) -> String` (`""` = vacía). Las pruebas usan un mundo falso; el juego pasa `VoxelWorld`.
- Produces (los usan `Colonos.gd` y el Plan 3):
  - `BuscadorRutas.new(mundo: Object)`.
  - `es_transitable(celda: Vector3i) -> bool`.
  - `vecinos(celda: Vector3i) -> Array[Vector3i]`.
  - `buscar_ruta(origen: Vector3i, destino: Vector3i, opciones: Dictionary = {}) -> Array[Vector3i]` — celdas a recorrer **sin incluir el origen**; `[]` si no hay ruta. `opciones.bloqueadas: Dictionary` (Vector3i → true) son celdas que no se pueden pisar.
  - `var max_nodos: int` (por defecto `MAX_NODOS_EXPANDIDOS`), modificable para pruebas.

- [ ] **Step 1: Crear la escena de pruebas y las pruebas (fallarán)**

`godot/scenes/BuscadorRutasTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/BuscadorRutasTest.gd" id="1"]

[node name="BuscadorRutasTest" type="Node"]
script = ExtResource("1")
```

`godot/scripts/BuscadorRutasTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de BuscadorRutas.gd con un mundo falso determinista (mismo
## patrón que RecoleccionTest.gd). Corre esta escena con F6 o en headless y
## revisa la salida: no debe lanzar ningún error de assert().

const BuscadorRutas = preload("res://scripts/BuscadorRutas.gd")


## Mundo mínimo: solo sabe decir qué hay en una celda ("" si está vacía).
class MundoFalso extends RefCounted:
	var celdas: Dictionary = {}

	func obtener_tipo(celda: Vector3i) -> String:
		return celdas.get(celda, "")

	func poner(celda: Vector3i, tipo: String) -> void:
		celdas[celda] = tipo


func _ready() -> void:
	ejecutar_pruebas()


## Suelo de "tierra" en y=0 para x en [0, ancho) y z en [0, largo). Las celdas
## por las que se camina están en y=1.
func _llano(mundo: MundoFalso, ancho: int, largo: int) -> void:
	for x in range(ancho):
		for z in range(largo):
			mundo.poner(Vector3i(x, 0, z), "tierra")


func _adyacentes(a: Vector3i, b: Vector3i) -> bool:
	return absi(a.x - b.x) + absi(a.z - b.z) == 1 and absi(a.y - b.y) <= 3


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Ruta recta en terreno llano ===")
	var m1 := MundoFalso.new()
	_llano(m1, 6, 3)
	var b1 := BuscadorRutas.new(m1)
	var ruta1: Array[Vector3i] = b1.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	print("Ruta: ", ruta1)
	assert(ruta1.size() == 4, "4 pasos en línea recta")
	assert(ruta1.back() == Vector3i(4, 1, 0))
	assert(ruta1[0] != Vector3i(0, 1, 0), "la ruta no incluye el origen")

	print("\n=== TEST 2: Rodea un muro ===")
	var m2 := MundoFalso.new()
	_llano(m2, 6, 8)
	for z in range(7):  # muro en x=2, con hueco en z=7
		m2.poner(Vector3i(2, 1, z), "pared")
		m2.poner(Vector3i(2, 2, z), "pared")
	var ruta2: Array[Vector3i] = BuscadorRutas.new(m2).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(not ruta2.is_empty(), "hay ruta por el hueco")
	assert(ruta2.size() > 4, "es más larga que la recta")
	for celda in ruta2:
		assert(m2.obtener_tipo(celda) == "", "no pisa el muro")

	print("\n=== TEST 3: Sube 1 bloque y no sube 2 ===")
	var m3 := MundoFalso.new()  # una sola fila (z=0): sin rodeos posibles
	_llano(m3, 6, 1)
	m3.poner(Vector3i(2, 1, 0), "tierra")
	m3.poner(Vector3i(3, 1, 0), "tierra")
	var ruta3: Array[Vector3i] = BuscadorRutas.new(m3).buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 2, 0))
	assert(ruta3.size() == 3 and ruta3.back() == Vector3i(3, 2, 0), "sube un escalón de 1 bloque")
	var m3b := MundoFalso.new()
	_llano(m3b, 6, 1)
	for y in range(1, 3):  # muro de 2 bloques
		m3b.poner(Vector3i(2, y, 0), "tierra")
		m3b.poner(Vector3i(3, y, 0), "tierra")
	assert(BuscadorRutas.new(m3b).buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 3, 0)).is_empty(), "no sube 2 bloques")

	print("\n=== TEST 4: Cae hasta 3 bloques y no 4 ===")
	var m4 := MundoFalso.new()
	for y in range(0, 4):  # torre de 4 de tierra en x=0: se pisa en y=4
		m4.poner(Vector3i(0, y, 0), "tierra")
	m4.poner(Vector3i(1, 0, 0), "tierra")
	m4.poner(Vector3i(2, 0, 0), "tierra")
	var ruta4: Array[Vector3i] = BuscadorRutas.new(m4).buscar_ruta(Vector3i(0, 4, 0), Vector3i(1, 1, 0))
	assert(ruta4.size() == 1 and ruta4[0] == Vector3i(1, 1, 0), "cae 3 bloques")
	var m4b := MundoFalso.new()
	for y in range(0, 5):  # torre de 5: caída de 4
		m4b.poner(Vector3i(0, y, 0), "tierra")
	m4b.poner(Vector3i(1, 0, 0), "tierra")
	assert(BuscadorRutas.new(m4b).buscar_ruta(Vector3i(0, 5, 0), Vector3i(1, 1, 0)).is_empty(), "no cae 4 bloques")

	print("\n=== TEST 5: Agua de 1 bloque se cruza, de 2 no ===")
	var m5 := MundoFalso.new()
	_llano(m5, 6, 1)
	m5.poner(Vector3i(2, 1, 0), "agua")
	var ruta5: Array[Vector3i] = BuscadorRutas.new(m5).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(ruta5.size() == 4 and ruta5.has(Vector3i(2, 1, 0)), "cruza 1 bloque de agua")
	var m5b := MundoFalso.new()
	_llano(m5b, 6, 1)
	m5b.poner(Vector3i(2, 1, 0), "agua")
	m5b.poner(Vector3i(2, 2, 0), "agua")
	assert(BuscadorRutas.new(m5b).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0)).is_empty(), "no cruza 2 bloques de agua")

	print("\n=== TEST 6: Las puertas se atraviesan ===")
	var m6 := MundoFalso.new()
	_llano(m6, 6, 1)
	m6.poner(Vector3i(2, 1, 0), "puerta_inferior")
	m6.poner(Vector3i(2, 2, 0), "puerta_superior")
	var ruta6: Array[Vector3i] = BuscadorRutas.new(m6).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(ruta6.size() == 4 and ruta6.has(Vector3i(2, 1, 0)), "pasa por la puerta")

	print("\n=== TEST 7: Un colono puede subirse a una cama ===")
	var m7 := MundoFalso.new()
	_llano(m7, 6, 1)
	m7.poner(Vector3i(2, 1, 0), "cama_cabecera")
	m7.poner(Vector3i(3, 1, 0), "cama_pies")
	var ruta7: Array[Vector3i] = BuscadorRutas.new(m7).buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 2, 0))
	assert(not ruta7.is_empty() and ruta7.back() == Vector3i(3, 2, 0), "llega a estar encima de la cama")

	print("\n=== TEST 8: Sin ruta, origen o destino no transitables ===")
	var m8 := MundoFalso.new()
	_llano(m8, 7, 7)
	for x in range(2, 5):  # destino (3,1,3) encerrado por un anillo de paredes
		for z in range(2, 5):
			if not (x == 3 and z == 3):
				m8.poner(Vector3i(x, 1, z), "pared")
				m8.poner(Vector3i(x, 2, z), "pared")
	var b8 := BuscadorRutas.new(m8)
	assert(b8.buscar_ruta(Vector3i(0, 1, 0), Vector3i(3, 1, 3)).is_empty(), "destino encerrado")
	assert(b8.buscar_ruta(Vector3i(0, 0, 0), Vector3i(1, 1, 0)).is_empty(), "origen dentro de un bloque sólido")
	assert(b8.buscar_ruta(Vector3i(0, 1, 0), Vector3i(1, 5, 0)).is_empty(), "destino en el aire sin suelo")
	assert(b8.buscar_ruta(Vector3i(0, 1, 0), Vector3i(0, 1, 0)).is_empty(), "origen == destino")

	print("\n=== TEST 9: Tope de nodos expandidos ===")
	var m9 := MundoFalso.new()
	_llano(m9, 30, 30)
	var b9 := BuscadorRutas.new(m9)
	assert(not b9.buscar_ruta(Vector3i(0, 1, 0), Vector3i(29, 1, 29)).is_empty(), "con el tope por defecto llega")
	b9.max_nodos = 5
	assert(b9.buscar_ruta(Vector3i(0, 1, 0), Vector3i(29, 1, 29)).is_empty(), "con un tope de 5 nodos se rinde")

	print("\n=== TEST 10: Determinismo ===")
	var m10 := MundoFalso.new()
	_llano(m10, 10, 10)
	m10.poner(Vector3i(4, 1, 4), "pared")
	m10.poner(Vector3i(4, 2, 4), "pared")
	var b10 := BuscadorRutas.new(m10)
	assert(b10.buscar_ruta(Vector3i(0, 1, 0), Vector3i(9, 1, 9)) == b10.buscar_ruta(Vector3i(0, 1, 0), Vector3i(9, 1, 9)))

	print("\n=== TEST 11: Recalcular cuando una celda de la ruta se vuelve sólida ===")
	var m11 := MundoFalso.new()
	_llano(m11, 6, 2)
	var b11 := BuscadorRutas.new(m11)
	var ruta11: Array[Vector3i] = b11.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0))
	assert(ruta11.has(Vector3i(2, 1, 0)))
	m11.poner(Vector3i(2, 1, 0), "pared")
	m11.poner(Vector3i(2, 2, 0), "pared")
	assert(not b11.es_transitable(Vector3i(2, 1, 0)), "la celda ya no es transitable")
	var nueva11: Array[Vector3i] = b11.buscar_ruta(Vector3i(1, 1, 0), Vector3i(4, 1, 0))
	assert(not nueva11.is_empty() and not nueva11.has(Vector3i(2, 1, 0)), "la nueva ruta la evita (ve el mundo actual)")

	print("\n=== TEST 12: Celdas bloqueadas por otros ===")
	var m12 := MundoFalso.new()
	_llano(m12, 6, 2)
	var b12 := BuscadorRutas.new(m12)
	var bloqueadas12 := {Vector3i(2, 1, 0): true}
	var ruta12: Array[Vector3i] = b12.buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"bloqueadas": bloqueadas12})
	assert(not ruta12.is_empty() and not ruta12.has(Vector3i(2, 1, 0)), "esquiva la celda bloqueada")
	assert(b12.buscar_ruta(Vector3i(0, 1, 0), Vector3i(2, 1, 0), {"bloqueadas": bloqueadas12}).is_empty(), "un destino bloqueado no tiene ruta")
	var m12b := MundoFalso.new()
	_llano(m12b, 6, 1)  # una sola fila: bloquear el paso la corta
	assert(BuscadorRutas.new(m12b).buscar_ruta(Vector3i(0, 1, 0), Vector3i(4, 1, 0), {"bloqueadas": bloqueadas12}).is_empty())

	print("\n=== TEST 13: Cada paso es a una celda contigua ===")
	for i in range(1, ruta2.size()):
		assert(_adyacentes(ruta2[i - 1], ruta2[i]), "pasos contiguos")

	print("\n=== Las 13 pruebas de BuscadorRutas pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/BuscadorRutasTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA con `Parse Error` (no existe `res://scripts/BuscadorRutas.gd`). No aparece `pasaron correctamente`.

- [ ] **Step 3: Implementar `godot/scripts/BuscadorRutas.gd`**

```gdscript
extends RefCounted

## A* a pie sobre el mundo voxel. Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Sección 2).
##
## No usa NavigationServer3D: exige hornear una malla y este mundo cambia
## continuamente (minado, construcción fantasma, agua que fluye). Aquí los
## vecinos se evalúan consultando "mundo" en el momento, así que siempre se
## ve el mundo actual y no hay nada que invalidar.
##
## "mundo" solo necesita obtener_tipo(celda: Vector3i) -> String ("" = vacía).
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


func _libre(celda: Vector3i) -> bool:
	return TIPOS_LIBRES.has(mundo.obtener_tipo(celda))


## Un NPC puede estar en "celda" si ella y la de arriba están libres y la de
## abajo es suelo sólido. Excepción: "celda" puede ser agua si la de arriba es
## libre (agua de 1 bloque de profundidad; con 2 o más ya no se camina, se
## nadaría, y los colonos no nadan). Una cama o un baúl es suelo, así que un
## colono puede pararse encima.
func es_transitable(celda: Vector3i) -> bool:
	var tipo: String = mundo.obtener_tipo(celda)
	if not (TIPOS_LIBRES.has(tipo) or tipo == "agua"):
		return false
	if not _libre(celda + ARRIBA):
		return false
	var suelo: String = mundo.obtener_tipo(celda - ARRIBA)
	return suelo != "agua" and not TIPOS_LIBRES.has(suelo)


## Celdas transitables a un paso de "celda": mismo nivel, subiendo 1 bloque o
## cayendo hasta CAIDA_MAXIMA. Sin diagonales.
func vecinos(celda: Vector3i) -> Array[Vector3i]:
	var resultado: Array[Vector3i] = []
	for direccion in DIRECCIONES:
		var columna: Vector3i = celda + direccion
		if es_transitable(columna):
			resultado.append(columna)
			continue
		var sobre_columna: Vector3i = columna + ARRIBA
		if es_transitable(sobre_columna) and _libre(celda + ARRIBA * 2):
			resultado.append(sobre_columna)
			continue
		if _libre(columna) and _libre(sobre_columna):
			for caida in range(1, CAIDA_MAXIMA + 1):
				var abajo: Vector3i = columna - ARRIBA * caida
				if es_transitable(abajo):
					resultado.append(abajo)
					break
				if not _libre(abajo):
					break
	return resultado


## Celdas a recorrer de "origen" a "destino", SIN incluir el origen; [] si no
## hay ruta (origen o destino no transitables, destino bloqueado, sin camino o
## tope de nodos agotado). opciones.bloqueadas: Dictionary (Vector3i -> true)
## con celdas que no se pueden pisar (otros colonos, el avatar).
## Coste de un paso = 1 + |dy| y heurística Manhattan 3D: admisible.
func buscar_ruta(origen: Vector3i, destino: Vector3i, opciones: Dictionary = {}) -> Array[Vector3i]:
	var ruta: Array[Vector3i] = []
	var bloqueadas: Dictionary = opciones.get("bloqueadas", {})
	if origen == destino or bloqueadas.has(destino):
		return ruta
	if not es_transitable(origen) or not es_transitable(destino):
		return ruta

	var costo: Dictionary = {origen: 0}
	var padre: Dictionary = {}
	var cerrados: Dictionary = {}
	var abiertos: Array = []
	var desempate := 0
	_meter(abiertos, [_heuristica(origen, destino), desempate, origen])
	var expandidos := 0
	while not abiertos.is_empty():
		var actual: Vector3i = _sacar(abiertos)[2]
		if cerrados.has(actual):
			continue
		if actual == destino:
			var celda: Vector3i = destino
			while celda != origen:
				ruta.append(celda)
				celda = padre[celda]
			ruta.reverse()
			return ruta
		cerrados[actual] = true
		expandidos += 1
		if expandidos > max_nodos:
			return ruta
		for vecino in vecinos(actual):
			if cerrados.has(vecino) or bloqueadas.has(vecino):
				continue
			var nuevo_costo: int = costo[actual] + 1 + absi(vecino.y - actual.y)
			if not costo.has(vecino) or nuevo_costo < costo[vecino]:
				costo[vecino] = nuevo_costo
				padre[vecino] = actual
				desempate += 1
				_meter(abiertos, [nuevo_costo + _heuristica(vecino, destino), desempate, vecino])
	return ruta


static func _heuristica(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y) + absi(a.z - b.z)


## Cola de prioridad: monticulo binario de [f, orden_de_inserción, celda]. El
## orden de inserción desempata y hace determinista la búsqueda.
static func _menor(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


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

- [ ] **Step 4: Ejecutar y verificar que pasa**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/BuscadorRutasTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con `=== Las 13 pruebas de BuscadorRutas pasaron correctamente ===`. Si el TEST 4 falla en la caída de 3 bloques, revisar en `vecinos()` el bucle de caída: cada celda intermedia debe estar libre para continuar y la primera transitable termina el bucle.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BuscadorRutas.gd* godot/scripts/BuscadorRutasTest.gd* godot/scenes/BuscadorRutasTest.tscn
git commit -m "feat: BuscadorRutas, A* a pie sobre el mundo voxel" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: `Colonos.gd` — estado, hogar y reconciliación

**Files:**
- Create: `godot/scripts/Colonos.gd`
- Create: `godot/scripts/ColonosTest.gd`
- Create: `godot/scenes/ColonosTest.tscn`

**Interfaces:**
- Consumes: `BuscadorRutas` (Tarea 1); `Ciudad.demografia`, `Ciudad.edificios_residenciales`, `Ciudad.TIPOS_POBLACION` (Plan 1); un objeto `zona` con `influencia_min: Vector2i`, `influencia_max: Vector2i` y `dentro_de_influencia(Vector2i) -> bool` (en el juego, `Zonificacion`); un `mundo` con `obtener_tipo`, `altura_en(x: int, z: int) -> int` y `edificio_a_celdas: Dictionary` (en el juego, `VoxelWorld`).
- Produces (las usan las Tareas 3-5 y el Plan 3):
  - Señales `colono_creado(id: int)` y `colono_retirado(id: int)`.
  - `Colonos.colonos: Dictionary` — id → `{"id", "tipo", "hogar", "celda": Vector3i, "posicion": Vector3, "ruta": Array[Vector3i], "progreso": float, "moviendo": bool, "espera": float, "bloqueo": float}`.
  - `Colonos.ocupadas: Dictionary` — `Vector3i` → id de colono.
  - Variables inyectables `mundo`, `ciudad`, `zona` (asignar `mundo` crea el `BuscadorRutas`).
  - `agregar_colono(tipo: String, celda: Vector3i, hogar: int = -1) -> int`, `reconciliar() -> void`.

- [ ] **Step 1: Crear la escena y las pruebas (fallarán)**

`godot/scenes/ColonosTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ColonosTest.gd" id="1"]

[node name="ColonosTest" type="Node"]
script = ExtResource("1")
```

`godot/scripts/ColonosTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de Colonos.gd, sin escena visual: un mundo falso, una zona
## falsa y una Ciudad real instanciada fuera del árbol (igual que
## CiudadTest.gd). Corre esta escena y revisa que no lance ningún assert().

const ColonosScript = preload("res://scripts/Colonos.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")


class MundoFalso extends RefCounted:
	var celdas: Dictionary = {}
	var edificio_a_celdas: Dictionary = {}
	var lado := 10

	func obtener_tipo(celda: Vector3i) -> String:
		return celdas.get(celda, "")

	func poner(celda: Vector3i, tipo: String) -> void:
		celdas[celda] = tipo

	func altura_en(x: int, z: int) -> int:
		return 0 if x >= 0 and x < lado and z >= 0 and z < lado else -1


## Cuadrado [0, lado) x [0, lado) de zona de influencia.
class ZonaFalsa extends RefCounted:
	var influencia_min := Vector2i(0, 0)
	var influencia_max := Vector2i(9, 9)

	func dentro_de_influencia(celda: Vector2i) -> bool:
		return celda.x >= influencia_min.x and celda.x <= influencia_max.x and celda.y >= influencia_min.y and celda.y <= influencia_max.y


func _ready() -> void:
	ejecutar_pruebas()


func _mundo_llano(lado: int = 10, largo: int = -1) -> MundoFalso:
	var mundo := MundoFalso.new()
	mundo.lado = lado
	var z_max: int = lado if largo < 0 else largo
	for x in range(lado):
		for z in range(z_max):
			mundo.poner(Vector3i(x, 0, z), "tierra")
	return mundo


func _nuevo(mundo: MundoFalso, ciudad: Node) -> Node:
	var colonos: Node = ColonosScript.new()
	colonos.ciudad = ciudad
	colonos.zona = ZonaFalsa.new()
	colonos.mundo = mundo
	colonos._rng.seed = 12345
	return colonos


func _contar(colonos: Node, tipo: String) -> int:
	var total := 0
	for c in colonos.colonos.values():
		if c["tipo"] == tipo:
			total += 1
	return total


func ejecutar_pruebas() -> void:
	print("=== TEST 1: reconciliar() crea y retira colonos hasta igualar demografia ===")
	var ciudad1: Node = CiudadScript.new()
	var colonos1: Node = _nuevo(_mundo_llano(), ciudad1)
	var creados := [0]
	var retirados := [0]
	colonos1.colono_creado.connect(func(_id: int) -> void: creados[0] += 1)
	colonos1.colono_retirado.connect(func(_id: int) -> void: retirados[0] += 1)
	ciudad1.demografia["obrero"] = 3
	ciudad1.demografia["militar"] = 1
	colonos1.reconciliar()
	assert(colonos1.colonos.size() == 4)
	assert(_contar(colonos1, "obrero") == 3 and _contar(colonos1, "militar") == 1)
	assert(creados[0] == 4)
	ciudad1.demografia["obrero"] = 1
	colonos1.reconciliar()
	assert(colonos1.colonos.size() == 2)
	assert(retirados[0] == 2)
	for id_ocupante in colonos1.ocupadas.values():
		assert(colonos1.colonos.has(id_ocupante), "ninguna celda queda ocupada por un colono retirado")
	assert(colonos1.ocupadas.size() == 2)

	print("\n=== TEST 2: El hogar es el edificio con menor ocupación relativa ===")
	var ciudad2: Node = CiudadScript.new()
	ciudad2.registrar_edificio_residencial(1, [2, 2])
	ciudad2.registrar_edificio_residencial(2, [2, 2])
	var colonos2: Node = _nuevo(_mundo_llano(), ciudad2)
	ciudad2.demografia["obrero"] = 3
	colonos2.reconciliar()
	var por_hogar := {1: 0, 2: 0}
	for c in colonos2.colonos.values():
		por_hogar[c["hogar"]] += 1
	print("Colonos por hogar: ", por_hogar)
	assert(por_hogar[1] == 2 and por_hogar[2] == 1, "se reparten entre los dos hogares; el empate lo gana el id menor")

	print("\n=== TEST 3: Un hogar demolido reasigna a sus colonos ===")
	ciudad2.retirar_edificio_residencial(1)
	colonos2.reconciliar()
	for c in colonos2.colonos.values():
		assert(c["hogar"] == 2, "todos pasan al único hogar que queda")

	print("\n=== TEST 4: Sin hogares, el colono queda sin hogar (-1) pero existe ===")
	var ciudad4: Node = CiudadScript.new()
	var colonos4: Node = _nuevo(_mundo_llano(), ciudad4)
	ciudad4.demografia["desempleado"] = 1
	colonos4.reconciliar()
	assert(colonos4.colonos.size() == 1)
	for c in colonos4.colonos.values():
		assert(c["hogar"] == -1)

	print("\n=== Las 4 pruebas de Colonos (estado y hogar) pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA con `Parse Error` (no existe `Colonos.gd`).

- [ ] **Step 3: Implementar `godot/scripts/Colonos.gd` (estado, hogar, reconciliación)**

```gdscript
extends Node

## Autoload "Colonos": los ciudadanos NPC de la ciudad. Estado y
## comportamiento puros (sin nodos de escena, como Ciudad.gd/Zonificacion.gd);
## el dibujo y el cuerpo físico los pone ColonosRenderer. Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Sección 3).
##
## Ciudad.demografia sigue siendo la fuente de verdad de las CANTIDADES:
## reconciliar() crea o retira colonos para igualarla cuando Ciudad emite
## tick_simulado. Las dependencias (mundo, ciudad, zona) son inyectables para
## poder probar todo sin escena (ColonosTest.gd).

const BuscadorRutas = preload("res://scripts/BuscadorRutas.gd")

signal colono_creado(id: int)
signal colono_retirado(id: int)

## Valor centinela de "no hay celda": una celda imposible.
const INVALIDA := Vector3i(999999, 999999, 999999)

## Placeholders sin balance real.
const VELOCIDAD_COLONO := 2.5  # celdas por segundo
const ESPERA_ENTRE_DESTINOS_MIN := 1.0
const ESPERA_ENTRE_DESTINOS_MAX := 3.0
const ESPERA_BLOQUEO := 0.5  # segundos esperando antes de esquivar
const INTENTOS_DESTINO := 8
const INTENTOS_APARICION := 200
const PROBABILIDAD_CASA := 0.5  # de deambular hacia su hogar en vez de por la ciudad

## El mundo (VoxelWorld en el juego). Asignarlo crea el buscador de rutas.
var mundo: Object = null:
	set(valor):
		mundo = valor
		_buscador = BuscadorRutas.new(valor) if valor != null else null
var ciudad: Object = null  # Ciudad
var zona: Object = null  # Zonificacion

## id -> {"id", "tipo", "hogar", "celda", "posicion", "ruta", "progreso",
## "moviendo", "espera", "bloqueo"}. "celda" es la celda donde está parado;
## "posicion" (Vector3, los pies) es lo que dibuja el renderer.
var colonos: Dictionary = {}
## Vector3i -> id de colono: la celda que ocupa cada colono y, mientras da un
## paso, también la celda a la que va (reserva).
var ocupadas: Dictionary = {}

var _siguiente_id := 1
var _buscador: RefCounted = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	if zona == null:
		zona = Zonificacion
	ciudad.tick_simulado.connect(reconciliar)


func _process(delta: float) -> void:
	avanzar(delta)


## Agrega un colono en "celda" (que debe ser transitable) y lo devuelve.
func agregar_colono(tipo: String, celda: Vector3i, hogar: int = -1) -> int:
	var id := _siguiente_id
	_siguiente_id += 1
	var ruta: Array[Vector3i] = []
	colonos[id] = {
		"id": id, "tipo": tipo, "hogar": hogar,
		"celda": celda, "posicion": _centro_de(celda),
		"ruta": ruta, "progreso": 0.0, "moviendo": false,
		"espera": 0.0, "bloqueo": 0.0,
	}
	ocupadas[celda] = id
	colono_creado.emit(id)
	return id


## Crea o retira colonos hasta que haya uno por cada unidad de
## Ciudad.demografia[tipo], y reasigna los hogares que ya no existen.
func reconciliar() -> void:
	if _buscador == null:
		return  # todavía no se asignó el mundo (p. ej. una escena de pruebas sin Main)
	var demografia: Dictionary = ciudad.demografia
	for tipo in demografia:
		var existentes: Array[int] = _ids_de_tipo(tipo)
		while existentes.size() > demografia[tipo]:
			_retirar(existentes.pop_back())
		while existentes.size() < demografia[tipo]:
			var celda: Vector3i = _celda_aparicion()
			if celda == INVALIDA:
				break  # sin celda de aparición transitable: se reintenta en el siguiente tick
			existentes.append(agregar_colono(tipo, celda, _elegir_hogar()))
	_reasignar_hogares()


func _ids_de_tipo(tipo: String) -> Array[int]:
	var ids: Array[int] = []
	for id in colonos:
		if colonos[id]["tipo"] == tipo:
			ids.append(id)
	return ids


func _retirar(id: int) -> void:
	var colono: Dictionary = colonos[id]
	ocupadas.erase(colono["celda"])
	if colono["moviendo"] and not colono["ruta"].is_empty():
		ocupadas.erase(colono["ruta"][0])
	colonos.erase(id)
	colono_retirado.emit(id)


## Los pies del colono están en el borde inferior de su celda; x y z, al centro.
func _centro_de(celda: Vector3i) -> Vector3:
	return Vector3(celda.x + 0.5, celda.y, celda.z + 0.5)


## Camas totales de un hogar (suma de las de todos sus pisos).
func _capacidad_hogar(id: int) -> float:
	var total := 0.0
	for camas in ciudad.edificios_residenciales.get(id, []):
		total += camas
	return total


## Vivienda que ocupan sus colonos: cada uno pesa 1 / x_cama.
func _ocupacion_hogar(id: int) -> float:
	var total := 0.0
	for c in colonos.values():
		if c["hogar"] == id:
			total += 1.0 / float(ciudad.TIPOS_POBLACION[c["tipo"]]["x_cama"])
	return total


## El hogar con menor ocupación relativa (ocupación / camas); en empate, el de
## id menor. -1 si no hay ningún edificio residencial con camas. El hogar solo
## determina a dónde entra el colono: el límite vinculante de población es la
## capacidad global de Ciudad, y un hogar puede quedar algo por encima.
## ponytail: no fuerza capacidad por casa; añadirlo si hace falta un tope
## individual.
func _elegir_hogar() -> int:
	var ids: Array = ciudad.edificios_residenciales.keys()
	ids.sort()
	var mejor := -1
	var mejor_ratio := INF
	for id: int in ids:
		var capacidad := _capacidad_hogar(id)
		if capacidad <= 0.0:
			continue
		var ratio := _ocupacion_hogar(id) / capacidad
		if ratio < mejor_ratio - 1e-9:
			mejor = id
			mejor_ratio = ratio
	return mejor


func _reasignar_hogares() -> void:
	for c in colonos.values():
		if c["hogar"] == -1 or not ciudad.edificios_residenciales.has(c["hogar"]):
			c["hogar"] = _elegir_hogar()



## Todavía sin comportamiento: el movimiento se implementa en la Tarea 3.
func avanzar(_delta: float) -> void:
	pass


## Una celda transitable dentro de la zona de influencia, al azar; INVALIDA si
## el azar cayó fuera de la zona o en una celda sin suelo transitable.
func _candidato_exterior() -> Vector3i:
	var minimo: Vector2i = zona.influencia_min
	var maximo: Vector2i = zona.influencia_max
	var x := _rng.randi_range(minimo.x, maximo.x)
	var z := _rng.randi_range(minimo.y, maximo.y)
	if not zona.dentro_de_influencia(Vector2i(x, z)):
		return INVALIDA
	var celda := Vector3i(x, mundo.altura_en(x, z) + 1, z)
	return celda if _buscador.es_transitable(celda) else INVALIDA


## true si algún vecino ortogonal (x, z) queda fuera de la zona de influencia.
func _es_borde_de_zona(xz: Vector2i) -> bool:
	for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not zona.dentro_de_influencia(xz + direccion):
			return true
	return false


## Donde aparece un migrante: una celda transitable libre en el BORDE de la
## zona de influencia (llegan "desde fuera"); si tras INTENTOS_APARICION
## intentos no cae ninguna en el borde, cualquier celda transitable libre.
## ponytail: muestreo aleatorio en la caja de la zona; suficiente mientras la
## zona sea grande y casi convexa.
func _celda_aparicion() -> Vector3i:
	var respaldo := INVALIDA
	for i in range(INTENTOS_APARICION):
		var celda: Vector3i = _candidato_exterior()
		if celda == INVALIDA or ocupadas.has(celda):
			continue
		if _es_borde_de_zona(Vector2i(celda.x, celda.z)):
			return celda
		if respaldo == INVALIDA:
			respaldo = celda
	return respaldo
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con `=== Las 4 pruebas de Colonos (estado y hogar) pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd* godot/scripts/ColonosTest.gd* godot/scenes/ColonosTest.tscn
git commit -m "feat: Colonos, estado, hogar y reconciliación con la demografía" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 3: Movimiento y deambular

**Files:**
- Modify: `godot/scripts/Colonos.gd` (reemplazar `avanzar()`; agregar el movimiento, `_elegir_destino`, candidatos)
- Modify: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- Consumes: todo lo de la Tarea 2; `BuscadorRutas.buscar_ruta`, `es_transitable`.
- Produces: `Colonos.avanzar(delta: float) -> void` (mueve todos los colonos), `Colonos._bloqueadas_para(id: int) -> Dictionary` (celdas ocupadas por otros; en la Tarea 4 suma las del avatar), `Colonos._esquivar(c)` y `Colonos._replanificar(c)` (los completa la Tarea 4; aquí tienen versión mínima).

- [ ] **Step 1: Agregar las pruebas 5-7 (fallarán)**

En `ColonosTest.gd`, antes del `print` final, agregar; y cambiar el final a `Las 7 pruebas`:

```gdscript
	print("\n=== TEST 5: Un colono recorre su ruta celda a celda ===")
	var colonos5: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id5: int = colonos5.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c5: Dictionary = colonos5.colonos[id5]
	var ruta5: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c5["ruta"] = ruta5
	colonos5.avanzar(0.5)  # 0.5 s x 2.5 celdas/s = 1.25: completa el primer paso
	assert(c5["celda"] == Vector3i(2, 1, 1))
	assert(colonos5.ocupadas.has(Vector3i(2, 1, 1)) and not colonos5.ocupadas.has(Vector3i(1, 1, 1)), "libera la celda que deja")
	colonos5.avanzar(0.5)
	assert(c5["celda"] == Vector3i(3, 1, 1))
	assert(c5["ruta"].is_empty())
	assert(colonos5.ocupadas.size() == 1 and colonos5.ocupadas.has(Vector3i(3, 1, 1)))
	assert(c5["espera"] > 0.0, "al llegar espera unos segundos antes de elegir otro destino")

	print("\n=== TEST 6: Deambular: siempre pisa celdas transitables y se mueve ===")
	var mundo6 := _mundo_llano()
	for z in range(0, 10):  # un muro con un hueco que estorba el paso
		if z != 5:
			mundo6.poner(Vector3i(5, 1, z), "pared")
			mundo6.poner(Vector3i(5, 2, z), "pared")
	var colonos6: Node = _nuevo(mundo6, CiudadScript.new())
	var id6: int = colonos6.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c6: Dictionary = colonos6.colonos[id6]
	var celdas_vistas := {}
	for i in range(400):
		colonos6.avanzar(0.1)
		assert(colonos6._buscador.es_transitable(c6["celda"]), "nunca pisa una celda no transitable")
		celdas_vistas[c6["celda"]] = true
	print("Celdas distintas recorridas: ", celdas_vistas.size())
	assert(celdas_vistas.size() > 5, "el colono efectivamente deambula")

	print("\n=== TEST 7: Un colono con hogar entra a su casa ===")
	var ciudad7: Node = CiudadScript.new()
	ciudad7.registrar_edificio_residencial(1, [2, 2])
	var mundo7 := _mundo_llano()
	# Una casita de 3x3: paredes en el borde y una puerta en (6, 1, 5).
	for x in range(6, 9):
		for z in range(5, 8):
			var borde: bool = x == 6 or x == 8 or z == 5 or z == 7
			if borde:
				mundo7.poner(Vector3i(x, 1, z), "pared")
				mundo7.poner(Vector3i(x, 2, z), "pared")
	mundo7.poner(Vector3i(6, 1, 6), "puerta_inferior")
	mundo7.poner(Vector3i(6, 2, 6), "puerta_superior")
	var celdas_casa: Array[Vector3i] = []
	for x in range(6, 9):
		for z in range(5, 8):
			celdas_casa.append(Vector3i(x, 1, z))
			celdas_casa.append(Vector3i(x, 2, z))
	mundo7.edificio_a_celdas[1] = celdas_casa
	var colonos7: Node = _nuevo(mundo7, ciudad7)
	var id7: int = colonos7.agregar_colono("obrero", Vector3i(2, 1, 6), 1)
	var c7: Dictionary = colonos7.colonos[id7]
	var entro := false
	for i in range(3000):
		colonos7.avanzar(0.1)
		if c7["celda"] == Vector3i(7, 1, 6):  # el único interior de la casa
			entro = true
			break
	assert(entro, "con hogar, tarde o temprano entra a su casa por la puerta")

	print("\n=== Las 7 pruebas de Colonos pasaron correctamente ===")
```

y borrar la línea `print("\n=== Las 4 pruebas de Colonos (estado y hogar) pasaron correctamente ===")`.

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA (`Assertion failed` en el TEST 5: el colono no se movió porque `avanzar()` está vacío).

- [ ] **Step 3: Implementar el movimiento en `Colonos.gd`**

Reemplazar el `avanzar(_delta)` provisional por:

```gdscript
func avanzar(delta: float) -> void:
	if _buscador == null:
		return
	for c in colonos.values():
		_avanzar_colono(c, delta)


func _avanzar_colono(c: Dictionary, delta: float) -> void:
	if c["moviendo"]:
		_completar_paso(c, delta)
		return
	if c["espera"] > 0.0:
		c["espera"] -= delta
		return
	if c["ruta"].is_empty():
		_elegir_destino(c)
		return
	_iniciar_paso(c, delta)


## Empieza a caminar hacia la siguiente celda de la ruta, si sigue siendo
## transitable (el mundo pudo cambiar: minado, obra, agua) y nadie la ocupa.
func _iniciar_paso(c: Dictionary, delta: float) -> void:
	var siguiente: Vector3i = c["ruta"][0]
	if not _buscador.es_transitable(siguiente):
		_replanificar(c)
		return
	if _ocupada_por_otro(siguiente, c["id"]):
		c["bloqueo"] += delta
		if c["bloqueo"] >= ESPERA_BLOQUEO:
			c["bloqueo"] = 0.0
			_esquivar(c)
		return
	c["bloqueo"] = 0.0
	ocupadas[siguiente] = c["id"]  # reserva la celda a la que va
	c["moviendo"] = true
	c["progreso"] = 0.0
	_completar_paso(c, delta)


func _completar_paso(c: Dictionary, delta: float) -> void:
	c["progreso"] += delta * VELOCIDAD_COLONO
	var siguiente: Vector3i = c["ruta"][0]
	var t: float = minf(c["progreso"], 1.0)
	c["posicion"] = _centro_de(c["celda"]).lerp(_centro_de(siguiente), t)
	if c["progreso"] < 1.0:
		return
	ocupadas.erase(c["celda"])
	c["celda"] = siguiente
	c["ruta"].pop_front()
	c["moviendo"] = false
	c["progreso"] = 0.0
	if c["ruta"].is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


func _ocupada_por_otro(celda: Vector3i, id: int) -> bool:
	return ocupadas.has(celda) and ocupadas[celda] != id


## Celdas que este colono no puede pisar ahora: las de los demás colonos.
## (La Tarea 4 añade las del avatar.)
func _bloqueadas_para(id: int) -> Dictionary:
	var bloqueadas := {}
	for celda in ocupadas:
		if ocupadas[celda] != id:
			bloqueadas[celda] = true
	return bloqueadas


## Vuelve a calcular la ruta al MISMO destino sin obstáculos de otros
## (el mundo cambió bajo la ruta); si ya no hay ruta, abandona el destino.
func _replanificar(c: Dictionary) -> void:
	var vacia: Array[Vector3i] = []
	if c["ruta"].is_empty():
		return
	var destino: Vector3i = c["ruta"].back()
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino)
	c["ruta"] = nueva if not nueva.is_empty() else vacia
	if nueva.is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


## Otro colono (o el avatar) le cierra el paso: rodea sus celdas; si no hay
## forma, abandona el destino y elige otro tras esperar. Dos colonos de frente
## en un pasillo de 1 celda se resuelven porque ambos abandonan su destino.
## ponytail: sin negociación de prioridad; añadirla si aparecen atascos
## persistentes con mucha población.
func _esquivar(c: Dictionary) -> void:
	var vacia: Array[Vector3i] = []
	var destino: Vector3i = c["ruta"].back()
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, {"bloqueadas": _bloqueadas_para(c["id"])})
	if nueva.is_empty():
		c["ruta"] = vacia
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
	else:
		c["ruta"] = nueva


## Elige el siguiente destino: la mitad de las veces su casa (si tiene), el
## resto un punto de la zona de influencia. Prueba INTENTOS_DESTINO veces hasta
## dar con uno alcanzable; si no, espera y reintenta.
func _elegir_destino(c: Dictionary) -> void:
	var a_casa: bool = c["hogar"] != -1 and _rng.randf() < PROBABILIDAD_CASA
	for i in range(INTENTOS_DESTINO):
		var destino: Vector3i = _candidato_en_casa(c["hogar"]) if a_casa else _candidato_exterior()
		if destino == INVALIDA:
			continue
		var ruta: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, {"bloqueadas": _bloqueadas_para(c["id"])})
		if not ruta.is_empty():
			c["ruta"] = ruta
			return
	c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


## Una celda transitable al azar dentro de la caja envolvente de las celdas del
## hogar (puede quedar sobre una cama o junto a ella); INVALIDA si cae en una
## pared o en el aire.
func _candidato_en_casa(hogar: int) -> Vector3i:
	var celdas: Array = mundo.edificio_a_celdas.get(hogar, [])
	if celdas.is_empty():
		return INVALIDA
	var minimo: Vector3i = celdas[0]
	var maximo: Vector3i = celdas[0]
	for celda: Vector3i in celdas:
		minimo = Vector3i(mini(minimo.x, celda.x), mini(minimo.y, celda.y), mini(minimo.z, celda.z))
		maximo = Vector3i(maxi(maximo.x, celda.x), maxi(maximo.y, celda.y), maxi(maximo.z, celda.z))
	var candidata := Vector3i(
		_rng.randi_range(minimo.x, maximo.x),
		_rng.randi_range(minimo.y, maximo.y),
		_rng.randi_range(minimo.z, maximo.z)
	)
	return candidata if _buscador.es_transitable(candidata) else INVALIDA
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con `=== Las 7 pruebas de Colonos pasaron correctamente ===`. Si el TEST 7 no entra a la casa, comprobar que `(7, 1, 6)` es transitable (suelo `tierra` en `(7, 0, 6)`, aire arriba) y que la puerta `(6, 1, 6)`/`(6, 2, 6)` está en la pared oeste; el colono parte de `(2, 1, 6)` y tiene 3000 pasos de 0,1 s para elegir «a casa» (50 % de los destinos).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: los colonos caminan, deambulan y entran a su casa" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 4: Evitación entre colonos y del avatar

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- Consumes: `Colonos._bloqueadas_para`, `_ocupada_por_otro`, `_esquivar`, `_replanificar` (Tarea 3).
- Produces: `Colonos.celdas_avatar: Dictionary` (Vector3i → true) y `Colonos.actualizar_avatar(celda: Vector3i, velocidad: Vector3) -> void`, que llama `Player.gd` en la Tarea 5. `_ocupada_por_otro` y `_bloqueadas_para` pasan a incluir las celdas del avatar.

- [ ] **Step 1: Agregar las pruebas 8-12 (fallarán)**

En `ColonosTest.gd`, antes del `print` final, agregar; y cambiar el final a `Las 12 pruebas`:

```gdscript
	print("\n=== TEST 8: Dos colonos nunca comparten celda; el bloqueado rodea al otro ===")
	var colonos8: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id_a: int = colonos8.agregar_colono("obrero", Vector3i(1, 1, 1))
	var id_b: int = colonos8.agregar_colono("obrero", Vector3i(2, 1, 1))
	var a8: Dictionary = colonos8.colonos[id_a]
	var b8: Dictionary = colonos8.colonos[id_b]
	b8["espera"] = 999.0  # B se queda quieto estorbando
	var ruta8: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	a8["ruta"] = ruta8
	var llego8 := false
	for i in range(80):
		colonos8.avanzar(0.1)
		assert(a8["celda"] != b8["celda"], "nunca comparten celda")
		assert(colonos8.ocupadas.size() == 2 or colonos8.ocupadas.size() == 3, "solo su celda y, a lo sumo, la reservada")
		if a8["celda"] == Vector3i(3, 1, 1):
			llego8 = true  # al llegar se queda esperando y luego deambularía: se comprueba aquí y se corta
			break
	assert(llego8, "tras esperar, A rodea a B y llega a su destino")

	print("\n=== TEST 9: En un pasillo de una celda, el bloqueado abandona su destino ===")
	var colonos9: Node = _nuevo(_mundo_llano(10, 1), CiudadScript.new())  # una sola fila
	var id_a9: int = colonos9.agregar_colono("obrero", Vector3i(1, 1, 0))
	var id_b9: int = colonos9.agregar_colono("obrero", Vector3i(2, 1, 0))
	var a9: Dictionary = colonos9.colonos[id_a9]
	colonos9.colonos[id_b9]["espera"] = 999.0
	var ruta9: Array[Vector3i] = [Vector3i(2, 1, 0), Vector3i(3, 1, 0)]
	a9["ruta"] = ruta9
	for i in range(6):  # 0.6 s > ESPERA_BLOQUEO
		colonos9.avanzar(0.1)
	assert(a9["ruta"].is_empty() and a9["espera"] > 0.0, "sin forma de rodear, abandona el destino")
	assert(a9["celda"] == Vector3i(1, 1, 0))

	print("\n=== TEST 10: Esquivan la celda del avatar, y la de adelante si se mueve ===")
	var colonos10: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id10: int = colonos10.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c10: Dictionary = colonos10.colonos[id10]
	var ruta10: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c10["ruta"] = ruta10
	colonos10.actualizar_avatar(Vector3i(2, 1, 1), Vector3.ZERO)
	assert(colonos10.celdas_avatar.size() == 1, "quieto: solo su celda")
	var llego10 := false
	for i in range(80):
		colonos10.avanzar(0.1)
		assert(c10["celda"] != Vector3i(2, 1, 1), "nunca pisa la celda del avatar")
		if c10["celda"] == Vector3i(3, 1, 1):
			llego10 = true
			break
	assert(llego10, "rodea al avatar y llega")
	colonos10.actualizar_avatar(Vector3i(5, 1, 5), Vector3(5, 0, 0))
	assert(colonos10.celdas_avatar.has(Vector3i(5, 1, 5)) and colonos10.celdas_avatar.has(Vector3i(6, 1, 5)), "en movimiento: su celda y la de adelante")
	colonos10.actualizar_avatar(Vector3i(5, 1, 5), Vector3(0, 0, -5))
	assert(colonos10.celdas_avatar.has(Vector3i(5, 1, 4)), "el sentido lo da la velocidad")

	print("\n=== TEST 11: No huyen del avatar: un avatar junto a la ruta no la cambia ===")
	var colonos11: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	var id11: int = colonos11.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c11: Dictionary = colonos11.colonos[id11]
	var ruta11: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c11["ruta"] = ruta11
	colonos11.actualizar_avatar(Vector3i(2, 1, 2), Vector3.ZERO)  # pegado a la ruta, no sobre ella
	colonos11.avanzar(0.5)
	colonos11.avanzar(0.5)
	assert(c11["celda"] == Vector3i(3, 1, 1), "sigue su ruta directa, sin desviarse")

	print("\n=== TEST 12: Si el mundo cambia bajo la ruta, recalcula ===")
	var mundo12 := _mundo_llano()
	var colonos12: Node = _nuevo(mundo12, CiudadScript.new())
	var id12: int = colonos12.agregar_colono("obrero", Vector3i(1, 1, 1))
	var c12: Dictionary = colonos12.colonos[id12]
	var ruta12: Array[Vector3i] = [Vector3i(2, 1, 1), Vector3i(3, 1, 1)]
	c12["ruta"] = ruta12
	mundo12.poner(Vector3i(2, 1, 1), "pared")
	mundo12.poner(Vector3i(2, 2, 1), "pared")
	colonos12.avanzar(0.1)
	assert(c12["celda"] == Vector3i(1, 1, 1), "todavía no se movió")
	assert(not c12["ruta"].is_empty() and not c12["ruta"].has(Vector3i(2, 1, 1)), "la nueva ruta evita la celda que se volvió sólida")
	assert(c12["ruta"].back() == Vector3i(3, 1, 1), "al mismo destino")

	print("\n=== Las 12 pruebas de Colonos pasaron correctamente ===")
```

y borrar la línea `print("\n=== Las 7 pruebas de Colonos pasaron correctamente ===")`.

- [ ] **Step 2: Ejecutar y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA (`Invalid call. Nonexistent function 'actualizar_avatar'` en el TEST 10; el 8 y el 9 ya pasan con lo de la Tarea 3 salvo el conteo del TEST 8).

- [ ] **Step 3: Implementar el avatar como obstáculo en `Colonos.gd`**

Agregar, junto a las demás variables de estado:

```gdscript
## Celdas que el avatar ocupa ahora (Vector3i -> true): la suya y, si se está
## moviendo, la de adelante. Los colonos las esquivan pero no huyen: solo
## abandonan su destino si quedan bloqueados (ver _esquivar()).
var celdas_avatar: Dictionary = {}
```

Agregar la función pública:

```gdscript
## La llama Player.gd en cada frame de física con la celda donde está y su
## velocidad. Si se mueve (más de 0.5 celdas/s horizontales), la celda de
## adelante, en el sentido dominante de la velocidad, también cuenta.
func actualizar_avatar(celda: Vector3i, velocidad: Vector3) -> void:
	celdas_avatar.clear()
	celdas_avatar[celda] = true
	var horizontal := Vector2(velocidad.x, velocidad.z)
	if horizontal.length() <= 0.5:
		return
	if absf(horizontal.x) > absf(horizontal.y):
		celdas_avatar[celda + Vector3i(int(signf(horizontal.x)), 0, 0)] = true
	else:
		celdas_avatar[celda + Vector3i(0, 0, int(signf(horizontal.y)))] = true
```

Reemplazar `_ocupada_por_otro()` y `_bloqueadas_para()` por:

```gdscript
func _ocupada_por_otro(celda: Vector3i, id: int) -> bool:
	return (ocupadas.has(celda) and ocupadas[celda] != id) or celdas_avatar.has(celda)


## Celdas que este colono no puede pisar ahora: las de los demás colonos y
## las del avatar.
func _bloqueadas_para(id: int) -> Dictionary:
	var bloqueadas := {}
	for celda in ocupadas:
		if ocupadas[celda] != id:
			bloqueadas[celda] = true
	for celda in celdas_avatar:
		bloqueadas[celda] = true
	return bloqueadas
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con `=== Las 12 pruebas de Colonos pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: los colonos se evitan entre sí y esquivan al avatar" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 5: `ColonosRenderer`, autoload y conexión con `Main` y `Player`

**Files:**
- Create: `godot/scripts/ColonosRenderer.gd`
- Modify: `godot/project.godot` (autoload)
- Modify: `godot/scripts/Main.gd`, `godot/scenes/Main.tscn`
- Modify: `godot/scripts/Player.gd` (`_physics_process`)
- Modify: `godot/scenes/Player.tscn` (nodo raíz: `collision_mask = 3`)
- Modify: `godot/scripts/CamaraCenital.gd` (las 4 consultas físicas)

**Interfaces:**
- Consumes: `Colonos.colonos`, señales `colono_creado`/`colono_retirado`, `Colonos.actualizar_avatar` (Tareas 2 y 4).
- Produces: el autoload global `Colonos`; el nodo `ColonosRenderer` en `Main.tscn`. No hay API nueva para tareas posteriores.

Esta tarea se apoya en escenas y física reales; se verifica con un arranque headless de `Main.tscn` (sin errores) y con la lista manual del final.

- [ ] **Step 1: Crear `godot/scripts/ColonosRenderer.gd`**

```gdscript
extends Node3D

## Dibuja a los colonos (una cápsula placeholder por colono) y les da un cuerpo
## físico para que el avatar no pueda atravesarlos. Toda la lógica vive en el
## autoload Colonos; esto solo refleja su estado. Las unidades definitivas
## (Quaternius/KayKit, GDD Sección 11) solo cambiarían la malla.
## ponytail: un MeshInstance3D + AnimatableBody3D por colono; pasar a
## MultiMesh si la población llega a miles.

const ALTURA_COLONO := 1.8
const RADIO_COLONO := 0.3

const COLORES_TIPO := {
	"ciudadano": Color(0.85, 0.85, 0.85),
	"desempleado": Color(0.75, 0.6, 0.4),
	"obrero": Color(0.9, 0.6, 0.2),
	"tecnico": Color(0.3, 0.6, 0.9),
	"especialista": Color(0.6, 0.4, 0.9),
	"investigador": Color(0.3, 0.8, 0.5),
	"militar": Color(0.8, 0.25, 0.25),
}

var _cuerpos: Dictionary = {}  # int (id de colono) -> AnimatableBody3D


func _ready() -> void:
	Colonos.colono_creado.connect(_on_colono_creado)
	Colonos.colono_retirado.connect(_on_colono_retirado)
	for id in Colonos.colonos:
		_on_colono_creado(id)


func _on_colono_creado(id: int) -> void:
	var tipo: String = Colonos.colonos[id]["tipo"]
	var cuerpo := AnimatableBody3D.new()
	# Capa 2: solo el avatar (Player.collision_mask = 3) choca con los colonos;
	# el raycast del jugador y el picking de CamaraCenital (máscara 1) los
	# atraviesan, así un clic sobre un colono elige el terreno de debajo.
	cuerpo.collision_layer = 2
	cuerpo.collision_mask = 0

	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = RADIO_COLONO
	capsula.height = ALTURA_COLONO
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORES_TIPO.get(tipo, Color.WHITE)
	capsula.material = material
	malla.mesh = capsula
	malla.position = Vector3(0, ALTURA_COLONO / 2.0, 0)
	cuerpo.add_child(malla)

	var forma := CollisionShape3D.new()
	var capsula_fisica := CapsuleShape3D.new()
	capsula_fisica.radius = RADIO_COLONO
	capsula_fisica.height = ALTURA_COLONO
	forma.shape = capsula_fisica
	forma.position = Vector3(0, ALTURA_COLONO / 2.0, 0)
	cuerpo.add_child(forma)

	add_child(cuerpo)
	_cuerpos[id] = cuerpo
	cuerpo.global_position = Colonos.colonos[id]["posicion"]


func _on_colono_retirado(id: int) -> void:
	if _cuerpos.has(id):
		_cuerpos[id].queue_free()
		_cuerpos.erase(id)


func _physics_process(_delta: float) -> void:
	for id in _cuerpos:
		if Colonos.colonos.has(id):
			_cuerpos[id].global_position = Colonos.colonos[id]["posicion"]
```

- [ ] **Step 2: Registrar el autoload `Colonos`**

En `godot/project.godot`, dentro de `[autoload]`, agregar al final (después de `CadenaMinerales=...`, así `Ciudad` y `Zonificacion` ya están inicializados cuando corre `Colonos._ready()`):

```
Colonos="*res://scripts/Colonos.gd"
```

- [ ] **Step 3: Asignar el mundo a `Colonos` y añadir el renderer a `Main`**

En `godot/scripts/Main.gd`, dentro de `_ready()`, después de `jugador.mundo = mundo`:

```gdscript
	Colonos.mundo = mundo
```

En `godot/scenes/Main.tscn`, agregar tras el último `[ext_resource ...]` (el de `id="9"`):

```
[ext_resource type="Script" path="res://scripts/ColonosRenderer.gd" id="10"]
```

y agregar este nodo justo antes de `[node name="Player" parent="." ...`:

```
[node name="ColonosRenderer" type="Node3D" parent="."]
script = ExtResource("10")
```

- [ ] **Step 4: Informar al autoload de dónde está el avatar**

En `Player._physics_process()`, después de la línea `move_and_slide()` (antes de `_procesar_oxigeno(delta)`), agregar:

```gdscript
	if mundo != null:
		# +0.1: la posición del CharacterBody3D queda a veces apenas por debajo
		# del suelo por el margen de colisión; así la celda siempre es la de los pies.
		Colonos.actualizar_avatar(_celda_en(global_position + Vector3.UP * 0.1), velocity)
```

- [ ] **Step 5: El avatar choca con los colonos; el picking de la cenital no**

En `godot/scenes/Player.tscn`, en el nodo raíz `[node name="Player" type="CharacterBody3D"]`, agregar la línea (debajo de `script = ExtResource("1")`):

```
collision_mask = 3
```

En `godot/scripts/CamaraCenital.gd`, agregar junto a las demás constantes del inicio:

```gdscript
## Las consultas físicas de la cámara (picking del terreno, altura mínima,
## colisión de la propia cámara) solo deben ver el mundo (capa 1), no los
## cuerpos de los colonos (capa 2, ver ColonosRenderer.gd).
const MASCARA_MUNDO := 1
```

y fijarla en las 4 consultas. En `_posicion_libre()`, después de `consulta.collide_with_bodies = true`:

```gdscript
	consulta.collision_mask = MASCARA_MUNDO
```

y en `_refinar_foco_por_mira()`, `_altura_bajo_camara()` y `_celda_bajo_mouse()`, justo después de la línea `var consulta := PhysicsRayQueryParameters3D.create(...)`:

```gdscript
	consulta.collision_mask = MASCARA_MUNDO
```

- [ ] **Step 6: Comprobar que `Main.tscn` arranca sin errores y que las pruebas siguen pasando**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Invalid"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: el primer comando no imprime nada (sin errores); el segundo imprime `=== Las 12 pruebas de Colonos pasaron correctamente ===`.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/ColonosRenderer.gd* godot/project.godot godot/scripts/Main.gd godot/scenes/Main.tscn godot/scripts/Player.gd godot/scenes/Player.tscn godot/scripts/CamaraCenital.gd
git commit -m "feat: ColonosRenderer y conexión de Colonos con Main y el avatar" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 6: Cuerpo visible del avatar

**Files:**
- Modify: `godot/scenes/Player.tscn`

**Interfaces:** ninguna nueva.

El cuerpo es una cápsula sin colisión (el `CollisionShape3D` existente sigue siendo la colisión del avatar). Termina a la altura de los hombros (1,4) y la cámara está a 1,6, así que la cámara queda por encima y al mirar hacia abajo se ve la parte superior del cuerpo; si quedara dentro de la cápsula, el culling de caras traseras la haría invisible.

- [ ] **Step 1: Agregar la malla y su material a `Player.tscn`**

En `godot/scenes/Player.tscn`, cambiar la primera línea a `[gd_scene load_steps=5 format=3]` y agregar, junto a los otros `[sub_resource ...]`:

```
[sub_resource type="CapsuleMesh" id="CapsuleMesh_cuerpo"]
radius = 0.3
height = 1.4

[sub_resource type="StandardMaterial3D" id="Material_cuerpo"]
albedo_color = Color(0.9, 0.5, 0.2, 1)
```

y agregar este nodo después del nodo `Colision`:

```
[node name="Cuerpo" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.7, 0)
mesh = SubResource("CapsuleMesh_cuerpo")
surface_material_override/0 = SubResource("Material_cuerpo")
```

- [ ] **Step 2: Comprobar que `Main.tscn` sigue cargando**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Invalid|Failed"
```

Expected: sin salida.

- [ ] **Step 3: Verificación visual (manual, no automatizable en headless)**

Abrir `Main.tscn` en el editor: (a) en primera persona, al mirar hacia abajo se ve la parte superior de la cápsula naranja bajo la cámara y al mirar al frente no estorba; (b) con `C` (cámara cenital) se ve al avatar como una cápsula naranja. Si al mirar al frente se ve un borde de la cápsula, bajar `height` a 1.3 y `position.y` a 0.65; si al mirar hacia abajo no se ve nada, subirla a 1.5 y 0.75.

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/Player.tscn
git commit -m "feat: cuerpo visible para el avatar, también en primera persona" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 7: Documentación y verificación final

**Files:**
- Create: `PoC_8/Documento Técnico de Desarrollo_ PoC 8 - Pathfinding a Pie y Colonos NPC.md`
- Modify: `PoC_4/Documento Técnico de Desarrollo_ PoC 4 - Integración de Ciudad y Avatar como Autoload.md`
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (Sección 11 filas Fase 2 y Fase 5, Sección 12 punto 7, encabezado)
- Modify: `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md` (una línea: coste del paso)

- [ ] **Step 1: Crear el documento técnico de PoC 8**

`PoC_8/Documento Técnico de Desarrollo_ PoC 8 - Pathfinding a Pie y Colonos NPC.md`:

```markdown
# **Documento Técnico de Desarrollo: PoC 8 - Pathfinding a Pie y Colonos NPC**

**Identificador del Módulo:** POC-08-PATHFINDING-COLONOS

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/`.

**Dependencias de Diseño:** GDD Sección 2 (ciclo de juego, Fase 2), Sección 3 (zona de influencia), Sección 6 (población), Sección 11 (Fase 2 y Fase 5).

Spec: `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`. Plan: `docs/superpowers/plans/2026-09-20-colonos-pathfinding.md`.

**Nota de alcance.** La navegación de la Fase 5 (PoC 8) se **adelantó** por decisión explícita del usuario (2026-09-20) para poder construir sobre ella la economía de recursos (acarreo, obreros). Solo cubre caminar a pie por el terreno; las carreteras, carretas, cintas y tuberías siguen siendo de la Fase 5.

## **Decisión: A\* propio, no `NavigationServer3D`**

El GDD (Fase 5) preveía `NavigationServer3D`. No se usa: exige hornear una malla de navegación y este mundo cambia continuamente (minado, construcción fantasma, agua que fluye), lo que obligaría a rehornearla siempre. `BuscadorRutas.gd` evalúa los vecinos consultando `VoxelWorld.obtener_tipo()` en el momento, así que siempre ve el mundo actual y no hay nada que invalidar.

## **`BuscadorRutas.gd`**

Clase pura (`RefCounted`), probada con un mundo falso (`BuscadorRutasTest.gd`, 13 pruebas).

* **Celda transitable:** un NPC ocupa 2 celdas de alto; las dos deben estar libres (`""`, `puerta_inferior`, `puerta_superior`) y la de abajo ser suelo sólido. El agua de 1 bloque de profundidad se cruza; de 2 o más, no. Camas y baúles son suelo (un colono puede pararse encima).
* **Movimientos:** 4 ortogonales; sube 1 bloque, cae hasta 3. Coste `1 + |dy|`, heurística Manhattan 3D, tope de 20 000 nodos expandidos por consulta.
* **Ruta que se rompe:** el colono verifica que la siguiente celda siga siendo transitable antes de cada paso; si no, recalcula.

## **`Colonos.gd` y `ColonosRenderer.gd`**

* **`Colonos` (autoload, estado puro):** `Ciudad.demografia` es la fuente de verdad de las cantidades; `reconciliar()` crea o retira colonos al recibir `Ciudad.tick_simulado`. Cada colono tiene un hogar (edificio residencial con menor ocupación relativa, ponderada por `1 / x_cama`), aparece en el borde de la zona de influencia y deambula: la mitad de las veces hacia su casa (puede quedar sobre una cama o junto a ella) y el resto por la zona de influencia.
* **Evitación:** dos colonos nunca ocupan la misma celda (reserva de la celda siguiente). Si otro colono o el avatar la ocupa, espera 0,5 s, rodea sus celdas y, si no hay forma, abandona el destino. El avatar cuenta como obstáculo en su celda y, si se mueve, en la de adelante; los colonos lo esquivan pero no huyen de él.
* **`ColonosRenderer`:** una cápsula placeholder y un `AnimatableBody3D` por colono, para que el avatar no los atraviese.
* **Cuerpo del avatar:** cápsula visible en primera persona y en la cámara cenital (`Player.tscn`).

## **Fuera de alcance / Próximos pasos**

* Fantasmas de obra permeables hacia afuera (Plan 3 del mismo spec).
* Trabajo, recolección, acarreo, almacenes y construcción por NPC (sub-proyectos 2 y 3).
* Carreteras y carretas; pathfinding asíncrono o jerárquico si la población lo exige; negociación de prioridad entre colonos; unidades definitivas (arte).
* Verificación manual pendiente en el editor real: colonos llegan por el borde, entran a las casas, se paran sobre camas y no atraviesan paredes ni agua profunda.
```

- [ ] **Step 2: Nota en el documento técnico de PoC 4**

Donde `PoC_4/` dice que los NPC colonos quedan pendientes, agregar al final del documento:

```
* **Actualización (2026-09-20):** los colonos NPC (última pieza pendiente de la Fase 2) se implementaron junto con el pathfinding a pie: ver `PoC_8/Documento Técnico de Desarrollo_ PoC 8 - Pathfinding a Pie y Colonos NPC.md`.
```

- [ ] **Step 3: Actualizar el GDD, Sección 11 y 12**

En la fila de la **Fase 2**, reemplazar `NPCs colonos, la última pieza de la Fase 2 original, **queda pendiente**.` por `NPCs colonos, la última pieza de la Fase 2 original, **completo (2026-09-20, ver `PoC_8/`)**: aparecen en el borde de la zona de influencia, viven en las casas, deambulan con un pathfinding a pie propio y se evitan entre sí y al avatar.`.

En la fila de la **Fase 5**, reemplazar `PoC 8 (navegación A\* ponderada por carreteras usando `NavigationServer3D` nativo);` por `PoC 8 (navegación A\* ponderada por carreteras — la parte a pie sobre el terreno ya está implementada con un A\* propio, `BuscadorRutas.gd`, adelantada el 2026-09-20 porque `NavigationServer3D` exigiría rehornear la malla con cada cambio del mundo voxel; queda pendiente la ponderación por carreteras);`.

En la Sección 12, punto 7, reemplazar `**Fase 2 — Colonos NPC** (última pieza pendiente de la Fase 2) y, después` por `~~**Fase 2 — Colonos NPC**~~ **completado** (2026-09-20) y, después`.

Encabezado: anteponer `**Colonos y pathfinding (2026-09-20):** colonos NPC con pathfinding a pie propio (Fase 2 completa; PoC 8 adelantada en su parte a pie), evitación y cuerpo del avatar. ` al texto de la versión 3.30 y cambiar `3.30` por `3.31`.

- [ ] **Step 4: Corregir una línea del spec**

En `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`, reemplazar `coste 1 por paso, heurística
Manhattan 3D` por `coste 1 + |dy| por paso (así la heurística Manhattan 3D sigue siendo admisible), heurística
Manhattan 3D`.

- [ ] **Step 5: Verificación final de este plan**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
for escena in Test CiudadTest BuscadorRutasTest ColonosTest ConstruccionTest ZonificacionTest; do
  echo "== $escena"
  "$GD" --headless --path godot res://scenes/$escena.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
done
```

Expected: cada escena imprime su línea `pasaron correctamente` y ninguna línea de error.

- [ ] **Step 6: Verificación manual (no automatizable en headless)**

En el editor de Godot 4.7, abrir `godot/scenes/Main.tscn`, construir una casa de nivel 1 (2 pisos × 2 camas) y esperar:
1. Llegan colonos por el borde de la zona de influencia, uno cada ~4 s; el HUD sube la población.
2. Caminan hacia la casa, entran por la puerta y se paran sobre las camas o a su lado; salen y deambulan por la zona.
3. No atraviesan paredes, ni agua de 2 o más bloques, ni se caen por acantilados de más de 3 bloques.
4. Dos colonos que se cruzan se esquivan; el avatar no puede atravesarlos y ellos lo rodean sin huir.
5. Al minar un bloque de su ruta, el colono recalcula.
6. El cuerpo del avatar es visible en primera persona (al mirar hacia abajo) y en la cenital (`C`).
7. En la cenital, hacer clic (por ejemplo al pintar una zona o emplazar un blueprint) sobre un colono elige la celda del terreno de debajo, no una celda vecina.

- [ ] **Step 7: Commit**

```bash
git add PoC_8 "PoC_4/Documento Técnico de Desarrollo_ PoC 4 - Integración de Ciudad y Avatar como Autoload.md" "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md
git commit -m "docs: PoC 8 (pathfinding a pie y colonos) y GDD 3.31" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

## Self-Review (Plan 2)

**Cobertura del spec:** Sección 2 (`BuscadorRutas`: transitabilidad, movimientos, A\*, tope, `bloqueadas`, ruta que se rompe) → Tarea 1 y el recálculo de la Tarea 3/4. `ignorar_fantasmas` queda explícitamente para el Plan 3. Sección 3 (autoload, hogar, reasignación, deambular, movimiento, aparición, reconciliación, evitación, cuerpo físico, renderer) → Tareas 2, 3, 4, 5. Sección 3b (cuerpo del avatar visible en primera persona) → Tarea 6. Documentación (GDD 11, PoC_4, PoC_8) → Tarea 7. Sin brechas.

**Consistencia de nombres:** `INVALIDA`, `agregar_colono`, `reconciliar`, `_bloqueadas_para`, `_esquivar`, `_replanificar`, `_candidato_exterior`, `_candidato_en_casa`, `actualizar_avatar`, `celdas_avatar` se definen antes de usarse. `buscar_ruta(origen, destino, opciones)` y `max_nodos` coinciden entre `BuscadorRutas` y sus usos.

**Riesgos que el ejecutor debe conocer:**
- En el TEST 7 de `ColonosTest` la casa es de 3×3 con un único interior `(7, 1, 6)`: el colono solo entra si elige «a casa» y su ruta pasa por la puerta.
- El TEST 8 asume que, mientras B está quieto, `ocupadas` tiene 2 o 3 entradas (celda de A, celda de B y la reserva de A durante un paso).
- `Player.gd` llama a `Colonos.actualizar_avatar` en cada frame de física; si `Player` se usa en una escena sin el autoload `Colonos`, esa llamada falla (todas las escenas del proyecto lo tienen porque es un autoload).
