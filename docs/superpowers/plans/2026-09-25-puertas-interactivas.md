# Puertas interactivas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el avatar abra y cierre puertas con `E` (lámina fina que gira 90°) y que las puertas se abran solas ante los colonos, sin cambiar el tipo de bloque de las celdas.

**Architecture:** Un nodo nuevo `Puertas` (hijo de `VoxelWorld`) guarda el estado por puerta y le da a cada una un `StaticBody3D` con una lámina de 1 × 2 × 0,1 (malla + colisión); el ítem de la `MeshLibrary` de `puerta_inferior`/`puerta_superior` queda sin malla ni forma. `VoxelWorld` emite una señal nueva `puerta_cambiada(celda)` desde los puntos donde una celda de puerta entra o sale. Los colonos se detectan por proximidad en un chequeo cada 0,25 s. `Player` gana un despachador `_interactuar()` (pulsar `E`).

**Tech Stack:** Godot 4.7 (GDScript), pruebas como escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md`.

## Global Constraints

- GDScript con **tabulaciones**. Documentación, comentarios, mensajes del juego y pruebas en **español**.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python. No hacer `git add` de `*.gd.uid` sueltos durante las tareas; los `.uid` de los scripts nuevos se commitean juntos en el commit `chore` del final de la Tarea 4.
- En cada commit, `git add` solo los archivos del paso. **No tocar `docs/Pendientes y próximos pasos.md` salvo en la Tarea 4**, y solo si `git status` no muestra cambios previos del usuario en ese archivo (si los hay, avisar y dejarlo sin commitear). Nota: en el momento de escribir este plan ese archivo ya tiene cambios del usuario sin commitear.
- Trabajar en la rama `feat/puertas-interactivas` (créala desde `main` en el Paso 0 de la Tarea 1); no commitear a `main`.
- No mezclar PoC ni reformatear archivos ajenos al objetivo. Reutilizar código existente; sin abstracciones especulativas.
- Verificación (CLAUDE.md): `godot/scenes/Test.tscn` con Godot 4.7 más las escenas `*Test.tscn` afectadas (`PuertasTest`, `ColonosTest`, `PlantillasPuestoTest`, `TranslucidosRendererTest`). Solo esas.
- Comando de pruebas (desde la raíz del repo; en cada tarea se reutiliza):
  ```bash
  GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
  "$GD" --headless --path godot res://scenes/<Escena>.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
  ```
  Cada escena de prueba imprime al final una línea con `pasaron correctamente`; si el `grep` no muestra ninguna línea, la prueba falló o no compiló (corre sin el `grep` para ver el error).
- **Constantes de la puerta:** lámina de `Vector3(1, 2, 0.1)` (ancho × alto × grosor), centrada en `celda_inferior + (0.5, 1.0, 0.5)`. Capa de colisión **1** (mundo) si está cerrada, **8** (capa 4) si está abierta; `collision_mask = 0`. Giro en Y: `0` si la pared corre por X, `PI/2` si corre por Z; abrir suma `PI/2`.
- **Clave de una puerta:** su celda **inferior** (`Vector3i`). `Vector3i.MAX` es el centinela "no es una puerta".
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  ```

## Review Focus

Entradas o condiciones que la spec insinúa y ninguna tarea cubriría por sí sola; cada una tiene su prueba en la tarea indicada:

1. **Puerta a medias** (solo la celda superior o solo la inferior, en cualquier orden de colocación) no debe registrarse ni crear cuerpo (Tarea 2, TEST 4).
2. **Puerta abierta que se mina, se revierte a fantasma o pierde su edificio** debe liberar su nodo sin dejar colisión residual (Tarea 2, TEST 4).
3. **Obra donde la puerta se surte antes que sus paredes:** la orientación debe corregirse sola cuando las paredes aparecen (Tarea 3, TEST 5).
4. **`Colonos` vacío o sin fuente:** el chequeo periódico no debe fallar ni abrir nada (Tarea 3, TEST 6).
5. **El avatar cierra una puerta con un colono al lado:** debe reabrirse en el chequeo siguiente; una puerta abierta a mano no se cierra sola (Tarea 3, TEST 6).

---

### Task 1: Señal `puerta_cambiada` y celdas de puerta sin malla ni forma en la MeshLibrary

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd` (constante `TIPOS_PUERTA` junto a `TIPOS_TRANSLUCIDOS` ~línea 150; señal junto a `bloque_translucido_cambiado` ~línea 205; `_indexar_biblioteca()` ~línea 414; `colocar_bloque()` ~línea 585; `_retirar_bloque()` ~línea 640; `_revertir_celda()` ~línea 1364; `eliminar_edificio()` ~línea 1416)
- Create: `godot/scripts/PuertasTest.gd`, `godot/scenes/PuertasTest.tscn`

**Interfaces:**
- Produces: `VoxelWorld.TIPOS_PUERTA: Array[String]` (`["puerta_inferior", "puerta_superior"]`); `signal puerta_cambiada(celda: Vector3i)` — se emite cada vez que una celda de tipo puerta entra (colocada) o sale (minada, revertida a fantasma, edificio eliminado) de `VoxelWorld`; NO se emite para otros tipos.

- [ ] **Step 0: Crear la rama**

```bash
git checkout main && git checkout -b feat/puertas-interactivas
```

- [ ] **Step 1: Escribir la escena y el script de prueba (TEST 1, falla)**

`godot/scenes/PuertasTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/PuertasTest.gd" id="1"]

[node name="PuertasTest" type="Node"]
script = ExtResource("1")
```

`godot/scripts/PuertasTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de la señal VoxelWorld.puerta_cambiada y de Puertas.gd
## (mismo patrón que TranslucidosRendererTest.gd). Corre esta escena
## (PuertasTest.tscn) y revisa el panel "Output": debe imprimir todas las
## pruebas y no lanzar ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md.

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")


func _ready() -> void:
	ejecutar_pruebas()


func _mundo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	return mundo


func ejecutar_pruebas() -> void:
	print("=== TEST 1: puerta_cambiada se emite solo para celdas de puerta ===")
	var mundo: Node = _mundo()
	var emitidas: Array[Vector3i] = []
	mundo.puerta_cambiada.connect(func(celda: Vector3i) -> void:
		emitidas.append(celda)
	)
	var base := Vector3i(0, 0, 0)
	var arriba := Vector3i(0, 1, 0)

	# Una pared no emite.
	mundo.colocar_bloque(Vector3i(5, 0, 0), "pared", true)
	assert(emitidas.is_empty(), "colocar una pared no debe emitir puerta_cambiada")

	# colocar_puerta(): emite las dos celdas, inferior primero.
	assert(mundo.colocar_puerta(base))
	assert(emitidas == [base, arriba], "colocar_puerta() debe emitir base y luego arriba, salió %s" % [emitidas])

	# Minar una de las dos celdas retira las dos y emite las dos.
	emitidas.clear()
	assert(mundo.minar_bloque(base))
	assert(emitidas.has(base) and emitidas.has(arriba), "minar una puerta debe emitir ambas celdas, salió %s" % [emitidas])

	# _revertir_celda(): la celda pasa a fantasma y emite.
	assert(mundo.colocar_puerta(base))
	emitidas.clear()
	mundo._revertir_celda(base)
	assert(emitidas == [base], "revertir a fantasma una celda de puerta debe emitirla, salió %s" % [emitidas])

	# Las celdas de puerta ya no dibujan ni colisionan por GridMap.
	var id_puerta: int = mundo.id_de_tipo("puerta_inferior")
	assert(mundo.mesh_library.get_item_mesh(id_puerta) == null, "el ítem de puerta no debe tener malla")
	assert(mundo.mesh_library.get_item_shapes(id_puerta).is_empty(), "el ítem de puerta no debe tener formas")

	print("OK: puerta_cambiada() se emite exactamente cuando una celda de puerta entra o sale.")
	mundo.free()

	print("\n=== Las pruebas de puertas pasaron correctamente ===")
```

- [ ] **Step 2: Correr para ver que falla**

Run (desde la raíz del repo): comando de pruebas con `PuertasTest`.
Expected: `Parse Error`/`SCRIPT ERROR` porque `puerta_cambiada` no existe (`id_de_tipo()` sí existe, `VoxelWorld.gd:133`).

- [ ] **Step 3: Implementar en `VoxelWorld.gd`**

Junto a `TIPOS_TRANSLUCIDOS` (~línea 150):

```gdscript
## Tipos de las dos celdas de una puerta. Su malla y su colisión NO las da
## GridMap (el ítem queda vacío en _indexar_biblioteca()): las da Puertas.gd,
## con una lámina fina por puerta. Ver
## docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md.
const TIPOS_PUERTA: Array[String] = ["puerta_inferior", "puerta_superior"]
```

Junto a `signal bloque_translucido_cambiado` (~línea 205):

```gdscript
## Emitida cuando una celda de tipo puerta entra (colocada) o sale (minada,
## revertida a fantasma, edificio eliminado). Puertas.gd la escucha para crear
## o destruir el nodo de la puerta. No se emite para ningún otro tipo.
signal puerta_cambiada(celda: Vector3i)
```

En `_indexar_biblioteca()`, después del bloque de `fantasma`:

```gdscript
	# Igual que el fantasma: la lámina y la colisión de las puertas las da
	# Puertas.gd, no el GridMap.
	for tipo in TIPOS_PUERTA:
		if _id_por_tipo.has(tipo):
			mesh_library.set_item_mesh(_id_por_tipo[tipo], null)
			mesh_library.set_item_shapes(_id_por_tipo[tipo], [])
```

En `colocar_bloque()`, justo después del `if TIPOS_TRANSLUCIDOS.has(tipo) or ...: bloque_translucido_cambiado.emit(celda)`:

```gdscript
	if TIPOS_PUERTA.has(tipo):
		puerta_cambiada.emit(celda)
```

En `_retirar_bloque()`: ANTES del `if pareja.has(celda):` ya está `var tipo_anterior`. Después de `set_cell_item(otra, ...)` y sus `erase`, agrega la emisión de `otra`; y tras el `set_cell_item(celda, ...)` la de `celda`. El bloque queda:

```gdscript
	var tipo_anterior: String = obtener_tipo(celda)
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		var tipo_otra: String = obtener_tipo(otra)
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
		if TIPOS_PUERTA.has(tipo_otra):
			puerta_cambiada.emit(otra)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	if TIPOS_PUERTA.has(tipo_anterior):
		puerta_cambiada.emit(celda)
```

(El resto de la función — translúcidos, escurrimiento, `Vias.quitar` — queda igual.)

En `_revertir_celda()`, después de `colocar_bloque(celda, "fantasma")`:

```gdscript
	if TIPOS_PUERTA.has(tipo_anterior):
		puerta_cambiada.emit(celda)
```

En `eliminar_edificio()`, dentro del `if tipo_anterior == "fantasma" or TIPOS_ESTRUCTURA.has(tipo_anterior):`, después de `set_cell_item(...)`:

```gdscript
			if TIPOS_PUERTA.has(tipo_anterior):
				puerta_cambiada.emit(celda)
```

- [ ] **Step 4: Correr para ver que pasa**

Run: comando de pruebas con `PuertasTest`.
Expected: línea `=== Las pruebas de puertas pasaron correctamente ===`.

- [ ] **Step 5: Verificar que no rompe lo existente**

Run: comando de pruebas con `TranslucidosRendererTest` y con `PlantillasPuestoTest`.
Expected: ambas imprimen su línea `pasaron correctamente`.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/PuertasTest.gd godot/scenes/PuertasTest.tscn
git commit -m "$(cat <<'EOF'
feat: señal puerta_cambiada y celdas de puerta sin malla ni forma en GridMap

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `Puertas.gd`: registro, orientación, lámina, colisión y `alternar()`

**Files:**
- Create: `godot/scripts/Puertas.gd`
- Modify: `godot/scripts/VoxelWorld.gd` (`var puertas: Node` + cableado en `_ready()` ~línea 411), `godot/scenes/Main.tscn` (nodo `Puertas`), `godot/scripts/PuertasTest.gd` (TESTS 2 a 4)

**Interfaces:**
- Consumes: `VoxelWorld.puerta_cambiada(celda)`, `VoxelWorld.obtener_tipo(celda) -> String`.
- Produces (en `Puertas.gd`, `extends Node3D`):
  - `var voxel_world: Node`
  - `func _on_puerta_cambiada(celda: Vector3i) -> void`
  - `func existe(base: Vector3i) -> bool`
  - `func esta_abierta(base: Vector3i) -> bool`
  - `func cuerpo_de(base: Vector3i) -> StaticBody3D` (`null` si no existe)
  - `func alternar(base: Vector3i) -> bool` (`false` si `base` no es una puerta; si abre: `manual = true`; si cierra: `manual = false`)
  - `func celda_de_colisionador(colisionador: Object) -> Vector3i` (`Vector3i.MAX` si no es el cuerpo de una puerta)
  - `func actualizar(base: Vector3i) -> void` (recalcula orientación, giro y capa; la usa la Tarea 3)
- `VoxelWorld.puertas: Node` (`null` si la escena no tiene el nodo).

- [ ] **Step 1: Escribir las pruebas (TESTS 2 a 4, fallan)**

En `PuertasTest.gd`, agrega bajo el `const VoxelWorld`:

```gdscript
const PuertasScript = preload("res://scripts/Puertas.gd")
const LAMINA := Vector3(1, 2, 0.1)


## Mundo + Puertas conectados como en Main.tscn (VoxelWorld._ready() no corre
## fuera del árbol, así que el cableado se repite a mano).
func _mundo_con_puertas() -> Array:
	var mundo: Node = _mundo()
	var puertas: Node3D = PuertasScript.new()
	puertas.voxel_world = mundo
	mundo.puertas = puertas
	mundo.puerta_cambiada.connect(puertas._on_puerta_cambiada)
	return [mundo, puertas]


func _liberar(par: Array) -> void:
	par[1].free()
	par[0].free()
```

Antes de la línea `print("\n=== Las pruebas de puertas pasaron correctamente ===")` agrega:

```gdscript
	print("=== TEST 2: registro, orientación, lámina y colisión de una puerta cerrada ===")
	var par: Array = _mundo_con_puertas()
	var m: Node = par[0]
	var p: Node3D = par[1]
	# Pared que corre por X: paredes en (base ± X).
	var b_x := Vector3i(10, 5, 10)
	m.colocar_bloque(b_x + Vector3i(-1, 0, 0), "pared", true)
	m.colocar_bloque(b_x + Vector3i(1, 0, 0), "pared", true)
	assert(m.colocar_puerta(b_x))
	assert(p.existe(b_x), "la puerta colocada debe registrarse")
	assert(not p.esta_abierta(b_x), "nace cerrada")
	var cuerpo: StaticBody3D = p.cuerpo_de(b_x)
	assert(cuerpo.collision_layer == 1 and cuerpo.collision_mask == 0, "cerrada: capa 1 (mundo)")
	assert(cuerpo.position.is_equal_approx(Vector3(b_x) + Vector3(0.5, 1.0, 0.5)), "centrada en las 2 celdas")
	assert(is_equal_approx(cuerpo.rotation.y, 0.0), "pared por X: sin giro")
	var forma: CollisionShape3D = cuerpo.get_child(1)
	assert((forma.shape as BoxShape3D).size.is_equal_approx(LAMINA), "la lámina mide 1 x 2 x 0.1")
	# Pared que corre por Z: paredes en (base ± Z).
	var b_z := Vector3i(20, 5, 10)
	m.colocar_bloque(b_z + Vector3i(0, 0, -1), "pared", true)
	m.colocar_bloque(b_z + Vector3i(0, 0, 1), "pared", true)
	assert(m.colocar_puerta(b_z))
	assert(is_equal_approx(p.cuerpo_de(b_z).rotation.y, PI / 2.0), "pared por Z: giro de 90°")
	# Puerta suelta (sin paredes): toma el eje X y no falla.
	var b_s := Vector3i(30, 5, 10)
	assert(m.colocar_puerta(b_s))
	assert(is_equal_approx(p.cuerpo_de(b_s).rotation.y, 0.0), "puerta suelta: eje X")
	print("OK: registro, orientación, lámina y colisión.")
	_liberar(par)

	print("=== TEST 3: alternar() abre y cierra, cambia capa y giro ===")
	par = _mundo_con_puertas()
	m = par[0]
	p = par[1]
	m.colocar_bloque(b_x + Vector3i(-1, 0, 0), "pared", true)
	m.colocar_bloque(b_x + Vector3i(1, 0, 0), "pared", true)
	assert(m.colocar_puerta(b_x))
	cuerpo = p.cuerpo_de(b_x)
	assert(p.alternar(b_x))
	assert(p.esta_abierta(b_x))
	assert(cuerpo.collision_layer == 8, "abierta: capa 4 (el avatar no la colisiona)")
	assert(is_equal_approx(cuerpo.rotation.y, PI / 2.0), "abrir gira 90° sobre el eje vertical")
	assert(p.alternar(b_x))
	assert(not p.esta_abierta(b_x))
	assert(cuerpo.collision_layer == 1)
	assert(is_equal_approx(cuerpo.rotation.y, 0.0))
	assert(not p.alternar(Vector3i(99, 5, 99)), "alternar() sobre una celda sin puerta devuelve false")
	assert(p.celda_de_colisionador(cuerpo) == b_x, "el cuerpo se identifica con su celda inferior")
	assert(p.celda_de_colisionador(StaticBody3D.new()) == Vector3i.MAX, "otro cuerpo no es una puerta")
	assert(p.celda_de_colisionador(null) == Vector3i.MAX, "null no es una puerta")
	print("OK: alternar(), capa, giro e identificación por colisionador.")
	_liberar(par)

	print("=== TEST 4: ciclo de vida (mitades sueltas, minar, revertir, eliminar) ===")
	par = _mundo_con_puertas()
	m = par[0]
	p = par[1]
	var base := Vector3i(0, 5, 0)
	var sobre := Vector3i(0, 6, 0)
	# Solo la mitad inferior: no se registra.
	m.colocar_bloque(base, "puerta_inferior", true)
	assert(not p.existe(base), "una sola mitad no registra la puerta")
	# Se completa con la superior: se registra.
	m.colocar_bloque(sobre, "puerta_superior", true)
	assert(p.existe(base), "con ambas mitades sí")
	assert(p.get_child_count() == 1)
	# Orden inverso: primero la superior, luego la inferior.
	var base2 := Vector3i(4, 5, 0)
	m.colocar_bloque(base2 + Vector3i(0, 1, 0), "puerta_superior", true)
	assert(not p.existe(base2))
	m.colocar_bloque(base2, "puerta_inferior", true)
	assert(p.existe(base2), "el registro no depende del orden de colocación")
	# Minar una puerta ABIERTA libera su nodo y no deja colisión.
	p.alternar(base2)
	m.pareja[base2] = base2 + Vector3i(0, 1, 0)
	m.pareja[base2 + Vector3i(0, 1, 0)] = base2
	assert(m.minar_bloque(base2))
	assert(not p.existe(base2), "minar la puerta destruye su entrada")
	assert(p.get_child_count() == 1, "y libera su cuerpo (queda solo el de la otra puerta)")
	# Revertir a fantasma una celda de la otra puerta la destruye.
	m._revertir_celda(sobre)
	assert(not p.existe(base), "revertir a fantasma una celda destruye la puerta")
	assert(p.get_child_count() == 0)
	# eliminar_edificio(): una puerta de un edificio registrado desaparece con él.
	m.colocar_bloque(Vector3i(8, 5, 0), "pared", true)
	m.colocar_puerta(Vector3i(9, 5, 0))
	assert(p.existe(Vector3i(9, 5, 0)))
	var id: int = m.registrar_edificio_completo({
		Vector3i(8, 5, 0): "pared",
		Vector3i(9, 5, 0): "puerta_inferior",
		Vector3i(9, 6, 0): "puerta_superior",
	})
	m.eliminar_edificio(id)
	assert(not p.existe(Vector3i(9, 5, 0)), "eliminar el edificio destruye su puerta")
	print("OK: ciclo de vida.")
	_liberar(par)
```

Nota: `registrar_edificio_completo(celdas_mundo: Dictionary)` recibe `Vector3i -> tipo` (ver `VoxelWorld.gd:1530`); `eliminar_edificio()` borra las celdas estructurales (incluidas las de puerta) y ahí debe dispararse `puerta_cambiada`. Si esa parte de TEST 4 falla por montaje (p. ej. `ordenar_celdas_edificio` exige algo que la prueba no da), ajusta las celdas del diccionario, no la aserción de que la puerta desaparece.

- [ ] **Step 2: Correr para ver que falla**

Run: comando de pruebas con `PuertasTest`.
Expected: error porque `Puertas.gd` y `VoxelWorld.puertas` no existen.

- [ ] **Step 3: Crear `godot/scripts/Puertas.gd`**

```gdscript
extends Node3D

## Puertas interactivas: una lámina fina (1 x 2 x 0.1) por puerta, con su propio
## cuerpo de colisión. Las celdas siguen siendo puerta_inferior/puerta_superior
## en VoxelWorld (su ítem de la MeshLibrary no dibuja ni colisiona); aquí vive
## solo el estado abierta/cerrada. Abrir gira la lámina 90° sobre su eje
## vertical central: de cubrir el hueco (capa 1, bloquea) a verse de canto
## (capa 4, el avatar la atraviesa pero el raycast del jugador aún la apunta).
## Ver docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md.
##
## Hijo de VoxelWorld (en el origen, celdas de 1x1x1): coordenadas locales =
## coordenadas del mundo. Clave de cada puerta: su celda INFERIOR.

const LAMINA := Vector3(1, 2, 0.1)
const CAPA_CERRADA := 1  # capa 1: mundo (bloquea al avatar)
const CAPA_ABIERTA := 8  # capa 4: solo el raycast del jugador
const META_CELDA := "celda_puerta"

var voxel_world: Node

var _puertas: Dictionary = {}  # Vector3i (celda inferior) -> Dictionary
var _forma := BoxShape3D.new()
var _malla := BoxMesh.new()
var _material := StandardMaterial3D.new()


func _init() -> void:
	_forma.size = LAMINA
	_malla.size = LAMINA
	_material.albedo_color = Color(0.82, 0.42, 0.0)
	_malla.material = _material


func existe(base: Vector3i) -> bool:
	return _puertas.has(base)


func esta_abierta(base: Vector3i) -> bool:
	return _puertas.has(base) and _puertas[base]["abierta"]


func cuerpo_de(base: Vector3i) -> StaticBody3D:
	return _puertas[base]["cuerpo"] if _puertas.has(base) else null


## Alterna la puerta con celda inferior "base". Abrir a mano la deja abierta
## hasta que se cierre a mano (manual = true); cerrar limpia ese estado.
func alternar(base: Vector3i) -> bool:
	if not _puertas.has(base):
		return false
	var puerta: Dictionary = _puertas[base]
	puerta["abierta"] = not puerta["abierta"]
	puerta["manual"] = puerta["abierta"]
	actualizar(base)
	return true


## Celda inferior de la puerta a la que pertenece "colisionador" (el objeto que
## devuelve RayCast3D.get_collider()), o Vector3i.MAX si no es una puerta.
func celda_de_colisionador(colisionador: Object) -> Vector3i:
	if colisionador is StaticBody3D and (colisionador as StaticBody3D).has_meta(META_CELDA):
		return (colisionador as StaticBody3D).get_meta(META_CELDA)
	return Vector3i.MAX


## Recalcula orientación, giro y capa de la puerta "base" según su estado.
func actualizar(base: Vector3i) -> void:
	var puerta: Dictionary = _puertas[base]
	var cuerpo: StaticBody3D = puerta["cuerpo"]
	var giro: float = 0.0 if _pared_por_x(base) else PI / 2.0
	if puerta["abierta"]:
		giro += PI / 2.0
	cuerpo.rotation.y = giro
	cuerpo.collision_layer = CAPA_ABIERTA if puerta["abierta"] else CAPA_CERRADA


func _on_puerta_cambiada(celda: Vector3i) -> void:
	var tipo: String = voxel_world.obtener_tipo(celda)
	if tipo == "puerta_inferior":
		_sincronizar(celda)
	elif tipo == "puerta_superior":
		_sincronizar(celda + Vector3i(0, -1, 0))
	else:
		# La celda dejó de ser puerta: cae la puerta de la que era mitad.
		_quitar(celda)
		_quitar(celda + Vector3i(0, -1, 0))


func _sincronizar(base: Vector3i) -> void:
	var completa: bool = voxel_world.obtener_tipo(base) == "puerta_inferior" \
			and voxel_world.obtener_tipo(base + Vector3i(0, 1, 0)) == "puerta_superior"
	if completa and not _puertas.has(base):
		_crear(base)
	elif not completa:
		_quitar(base)


func _crear(base: Vector3i) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Puerta_%d_%d_%d" % [base.x, base.y, base.z]
	cuerpo.collision_mask = 0
	cuerpo.position = Vector3(base) + Vector3(0.5, 1.0, 0.5)
	cuerpo.set_meta(META_CELDA, base)
	var malla := MeshInstance3D.new()
	malla.mesh = _malla
	cuerpo.add_child(malla)
	var forma := CollisionShape3D.new()
	forma.shape = _forma
	cuerpo.add_child(forma)
	add_child(cuerpo)
	_puertas[base] = {"abierta": false, "manual": false, "cuerpo": cuerpo}
	actualizar(base)


## free() inmediato (como CuerposObra.liberar()): se llama desde el minado o la
## deconstrucción, fuera de callbacks de consulta de física.
func _quitar(base: Vector3i) -> void:
	if not _puertas.has(base):
		return
	var cuerpo: StaticBody3D = _puertas[base]["cuerpo"]
	remove_child(cuerpo)
	cuerpo.free()
	_puertas.erase(base)


## true si las dos celdas laterales en X de la puerta están ocupadas (la pared
## corre por X) y no lo están las de Z; con ambos pares, o con ninguno, se toma X.
## Un fantasma cuenta como pared (una obra puede surtir la puerta antes que sus
## paredes; el chequeo periódico recalcula cuando aparecen).
func _pared_por_x(base: Vector3i) -> bool:
	var por_x: bool = _ocupada(base + Vector3i(1, 0, 0)) and _ocupada(base + Vector3i(-1, 0, 0))
	var por_z: bool = _ocupada(base + Vector3i(0, 0, 1)) and _ocupada(base + Vector3i(0, 0, -1))
	return por_x or not por_z


func _ocupada(celda: Vector3i) -> bool:
	var tipo: String = voxel_world.obtener_tipo(celda)
	return tipo != "" and tipo != "agua"
```

- [ ] **Step 4: Cablear `VoxelWorld` y `Main.tscn`**

En `VoxelWorld.gd`, junto a `var arboles`/otras variables públicas (cerca de `var pareja`):

```gdscript
## Nodo Puertas (hijo de este mundo en Main.tscn), o null en escenas de prueba
## sin él. Player lo usa para alternar puertas.
var puertas: Node = null
```

Al final de `_ready()` (después de `vias_renderer.reconstruir_todo()`):

```gdscript
	puertas = get_node_or_null("Puertas")
	if puertas != null:
		puertas.voxel_world = self
		puerta_cambiada.connect(puertas._on_puerta_cambiada)
```

En `Main.tscn`, agrega el recurso `[ext_resource type="Script" path="res://scripts/Puertas.gd" id="13"]` junto a los demás y el nodo, después de `ViasRenderer`:

```
[node name="Puertas" type="Node3D" parent="VoxelWorld"]
script = ExtResource("13")
```

- [ ] **Step 5: Correr para ver que pasa**

Run: comando de pruebas con `PuertasTest`.
Expected: `=== Las pruebas de puertas pasaron correctamente ===`.

- [ ] **Step 6: Verificar que Main carga**

Run: `"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 60 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR"`
Expected: sin salida.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Puertas.gd godot/scripts/VoxelWorld.gd godot/scenes/Main.tscn godot/scripts/PuertasTest.gd
git commit -m "$(cat <<'EOF'
feat: Puertas.gd con lámina fina, colisión por puerta y alternar()

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Apertura por proximidad de los colonos

**Files:**
- Modify: `godot/scripts/Puertas.gd`, `godot/scripts/PuertasTest.gd` (TESTS 5 y 6)

**Interfaces:**
- Consumes: `Puertas.actualizar(base)`, `Puertas._puertas` (Tarea 2); `Colonos.colonos: Dictionary` (id → Dictionary con `"celda": Vector3i`).
- Produces: `Puertas.RADIO_APERTURA := 2`, `Puertas.INTERVALO := 0.25`, `var fuente_colonos: Object` (`null` = usar el autoload `Colonos`), `func tick() -> void`.

- [ ] **Step 1: Escribir las pruebas (TESTS 5 y 6, fallan)**

En `PuertasTest.gd`, junto a los otros `const`:

```gdscript
## Fuente de colonos falsa: Puertas solo lee su diccionario "colonos".
class FuenteColonos:
	var colonos: Dictionary = {}

	func poner(id: int, celda: Vector3i) -> void:
		colonos[id] = {"celda": celda}
```

Antes del `print("\n=== Las pruebas de puertas ...` agrega:

```gdscript
	print("=== TEST 5: la orientación se corrige cuando las paredes aparecen después de la puerta ===")
	par = _mundo_con_puertas()
	m = par[0]
	p = par[1]
	var b5 := Vector3i(10, 5, 10)
	assert(m.colocar_puerta(b5))
	assert(is_equal_approx(p.cuerpo_de(b5).rotation.y, 0.0), "sin paredes: eje X")
	m.colocar_bloque(b5 + Vector3i(0, 0, -1), "pared", true)
	m.colocar_bloque(b5 + Vector3i(0, 0, 1), "pared", true)
	p.fuente_colonos = FuenteColonos.new()
	p.tick()
	assert(is_equal_approx(p.cuerpo_de(b5).rotation.y, PI / 2.0), "tras el tick, la pared por Z gira la puerta")
	print("OK: la orientación se recalcula en cada tick.")
	_liberar(par)

	print("=== TEST 6: proximidad de colonos ===")
	par = _mundo_con_puertas()
	m = par[0]
	p = par[1]
	var fuente := FuenteColonos.new()
	p.fuente_colonos = fuente
	var b6 := Vector3i(10, 5, 10)
	assert(m.colocar_puerta(b6))
	# Sin colonos: el tick no falla ni abre nada.
	p.tick()
	assert(not p.esta_abierta(b6), "sin colonos, cerrada")
	# Un colono a 2 celdas (Chebyshev en XZ, misma altura): abre, sin marcarla manual.
	fuente.poner(1, b6 + Vector3i(2, 0, 0))
	p.tick()
	assert(p.esta_abierta(b6), "un colono a RADIO_APERTURA abre la puerta")
	assert(p.cuerpo_de(b6).collision_layer == 8)
	# Se aleja: se cierra sola.
	fuente.poner(1, b6 + Vector3i(6, 0, 0))
	p.tick()
	assert(not p.esta_abierta(b6), "sin nadie cerca, se cierra sola")
	# Otro piso (3 celdas más arriba): no cuenta.
	fuente.poner(1, b6 + Vector3i(1, 3, 0))
	p.tick()
	assert(not p.esta_abierta(b6), "un colono en otro piso no la abre")
	# Abierta a mano: no se cierra sola aunque no haya nadie.
	fuente.colonos.clear()
	assert(p.alternar(b6))
	p.tick()
	assert(p.esta_abierta(b6), "una puerta abierta a mano no se cierra sola")
	# El avatar la cierra con un colono al lado: se reabre en el tick siguiente.
	fuente.poner(1, b6 + Vector3i(1, 0, 0))
	assert(p.alternar(b6))
	assert(not p.esta_abierta(b6), "el avatar la cierra")
	p.tick()
	assert(p.esta_abierta(b6), "con un colono cerca se reabre")
	print("OK: apertura y cierre por proximidad.")
	_liberar(par)
```

- [ ] **Step 2: Correr para ver que falla**

Run: comando de pruebas con `PuertasTest`.
Expected: error: `fuente_colonos`/`tick` no existen.

- [ ] **Step 3: Implementar en `Puertas.gd`**

Junto a las constantes:

```gdscript
const RADIO_APERTURA := 2  # celdas (Chebyshev en XZ): abre antes de que el colono llegue
const INTERVALO := 0.25  # segundos entre chequeos de proximidad
```

Junto a `var voxel_world`:

```gdscript
## Quién aporta el diccionario "colonos" (id -> {"celda": Vector3i}); null =
## el autoload Colonos. Las pruebas inyectan una fuente falsa.
var fuente_colonos: Object = null

var _acumulado := 0.0
```

Funciones nuevas:

```gdscript
func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado >= INTERVALO:
		_acumulado = 0.0
		tick()


## Un chequeo: recalcula la orientación de cada puerta (las paredes de una obra
## pueden aparecer después) y abre/cierra según los colonos cercanos. Una puerta
## abierta a mano (manual) nunca se cierra sola.
func tick() -> void:
	var fuente: Object = fuente_colonos if fuente_colonos != null else Colonos
	var colonos: Dictionary = fuente.colonos
	for base: Vector3i in _puertas:
		var puerta: Dictionary = _puertas[base]
		var cerca := _hay_colono_cerca(base, colonos)
		if cerca and not puerta["abierta"]:
			puerta["abierta"] = true
			puerta["manual"] = false
		elif not cerca and puerta["abierta"] and not puerta["manual"]:
			puerta["abierta"] = false
		actualizar(base)


func _hay_colono_cerca(base: Vector3i, colonos: Dictionary) -> bool:
	for colono: Dictionary in colonos.values():
		var celda: Vector3i = colono["celda"]
		if absi(celda.x - base.x) <= RADIO_APERTURA and absi(celda.z - base.z) <= RADIO_APERTURA \
				and absi(celda.y - base.y) <= 1:
			return true
	return false
```

- [ ] **Step 4: Correr para ver que pasa**

Run: comando de pruebas con `PuertasTest`, luego con `ColonosTest`.
Expected: ambas imprimen su línea `pasaron correctamente`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Puertas.gd godot/scripts/PuertasTest.gd
git commit -m "$(cat <<'EOF'
feat: las puertas se abren solas ante los colonos cercanos

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Interacción del avatar (`E`), documentación y verificación final

**Files:**
- Modify: `godot/scripts/Player.gd` (`_input()` ~línea 123, `_procesar_frutos()` ~línea 271, función nueva `_interactuar()`), `godot/scenes/Player.tscn` (máscara del `RayCast3D`), `PoC_3/Documento Técnico de Desarrollo_ PoC 3 - Prototipo Visual Mínimo en Godot.md` (subsección 3.5), `docs/Pendientes y próximos pasos.md`

**Interfaces:**
- Consumes: `VoxelWorld.puertas`, `Puertas.celda_de_colisionador(Object) -> Vector3i`, `Puertas.alternar(Vector3i) -> bool` (Tarea 2).

- [ ] **Step 1: El raycast del jugador debe ver la capa 4**

En `godot/scenes/Player.tscn`, en el nodo `RayCast3D`, cambia `collision_mask = 1` por `collision_mask = 9` (capas 1 y 4). El cuerpo del jugador (`collision_mask = 3`) no cambia: no incluye la capa 4, así que atraviesa las puertas abiertas.

- [ ] **Step 2: Despachador `_interactuar()` y tecla `E` en `Player.gd`**

En `_input()`, dentro del bloque `if event is InputEventKey:` junto a las otras teclas:

```gdscript
			if tecla.pressed and not tecla.echo and tecla.keycode == KEY_E:
				_interactuar()
```

Función nueva (junto a `_declarar_edificio()`):

```gdscript
## Pulsar E (no mantener) sobre el objeto apuntado. Hoy solo alterna puertas;
## la ventana de contenido del baúl se enchufará aquí (ver "Pendientes").
## Mantener E sigue siendo _procesar_frutos().
func _interactuar() -> void:
	if not raycast.is_colliding() or mundo == null or mundo.puertas == null:
		return
	var base: Vector3i = mundo.puertas.celda_de_colisionador(raycast.get_collider())
	if base != Vector3i.MAX:
		mundo.puertas.alternar(base)
```

En `_procesar_frutos()`, tras el primer `if not raycast.is_colliding() or mundo == null:` (que ya suelta el progreso y retorna), agrega otro guard antes de `var celda := _celda_impactada()`:

```gdscript
	if mundo.puertas != null and mundo.puertas.celda_de_colisionador(raycast.get_collider()) != Vector3i.MAX:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
```

- [ ] **Step 3: Verificar que compila y Main carga**

Run: `"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 60 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR"`
Expected: sin salida. Luego `PlayerNatacionTest` y `PlayerOxigenoTest` (cargan `Player.gd`): ambas con su línea de éxito.

- [ ] **Step 4: Verificación manual en juego (la hace el usuario o se pide)**

No hay forma de automatizar el raycast del avatar contra el cuerpo. Con `Main.tscn` en el editor: construir una pared con una puerta, apuntar a la puerta y pulsar `E`: debe girar de canto y dejar pasar; pulsar `E` otra vez la cierra y bloquea. Comprobar también que mantener `E` sobre un árbol con frutos y sobre el baúl de un puesto sigue funcionando, y que un colono que llega a una puerta cerrada la abre y luego se cierra. Si algo falla, reportarlo antes de seguir.

- [ ] **Step 5: Documentar**

En `PoC_3/Documento Técnico de Desarrollo_ PoC 3 - Prototipo Visual Mínimo en Godot.md`, agrega justo antes de `## **Próximos Pasos de esta PoC**` la subsección:

```markdown
### **3.5 Puertas interactivas (2026-09-25)**

Las puertas (`puerta_inferior` + `puerta_superior`) dejaron de ser bloques sólidos: son una lámina de 1 × 2 × 0,1 bloques, con su propio cuerpo de colisión, gestionada por `Puertas.gd` (hijo de `VoxelWorld`). Las celdas conservan su tipo (validador, colonos y `BuscadorRutas` no cambian); el ítem de la `MeshLibrary` queda sin malla ni forma y el estado abierta/cerrada vive en `Puertas`.

- **Abrir** gira la lámina 90° al instante sobre su eje vertical central: cerrada, cubre el hueco y bloquea al avatar (capa 1); abierta, se ve de canto y el avatar la atraviesa (capa 4, que el raycast del jugador sí detecta).
- **Avatar:** pulsar `E` apuntando a la puerta la alterna (`Player._interactuar()`). Una puerta abierta a mano solo se cierra a mano.
- **Colonos:** no interactúan; la puerta se abre sola si hay un colono a ≤ 2 celdas (Chebyshev en XZ, ±1 de altura) y se cierra cuando se van. Si el avatar cierra una puerta con un colono al lado, se reabre en el chequeo siguiente (cada 0,25 s).
- **Orientación:** se deduce de los vecinos laterales (pared por X o por Z; sin pared, eje X) y se recalcula en cada chequeo, porque una obra puede surtir la puerta antes que sus paredes.
- Sin guardado de partidas no hay migración: toda puerta nace cerrada al colocarse.
- Spec: `docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md`.
```

En `docs/Pendientes y próximos pasos.md`: quitar el punto `### 1. Puertas interactivas` (y renumerar los siguientes 2 → 1, 3 → 2, …, 8 → 7, y la referencia a "(punto 2)" del punto de la ventana del baúl a "(punto 1)"), y agregar al inicio de `## Hecho`:

```markdown
- ~~**Puertas interactivas** (2026-09-25).~~ Las puertas son una lámina fina que gira 90° al abrirse; el avatar las alterna con `E` apuntándolas y los colonos las abren por proximidad (se cierran al irse, salvo las abiertas a mano). Las celdas conservan su tipo; el estado vive en `Puertas.gd` — ver `docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md`. El baúl de un puesto sigue accesible por `E` mantenida hasta que exista su ventana (punto de "Ventana de interacción del baúl").
```

Solo si `git status` no muestra cambios previos del usuario en este archivo (ver Global Constraints); si los hay, hacer estas ediciones igualmente pero **no** incluir el archivo en el commit y avisar.

- [ ] **Step 6: Verificación final (CLAUDE.md, solo las escenas afectadas)**

Run el comando de pruebas para: `Test`, `PuertasTest`, `ColonosTest`, `PlantillasPuestoTest`, `TranslucidosRendererTest`.
Expected: cada una imprime su línea `pasaron correctamente` (si alguna escena no la imprime, corre sin el `grep` y revisa `Assertion`/`SCRIPT ERROR`).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Player.gd godot/scenes/Player.tscn "PoC_3/Documento Técnico de Desarrollo_ PoC 3 - Prototipo Visual Mínimo en Godot.md"
git add godot/scripts/Puertas.gd.uid godot/scripts/PuertasTest.gd.uid 2>/dev/null
git commit -m "$(cat <<'EOF'
feat: el avatar alterna puertas con E; documenta las puertas interactivas

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

Si el archivo de Pendientes no tenía cambios previos del usuario, agrégalo en un commit aparte: `git add "docs/Pendientes y próximos pasos.md" && git commit -m "docs: puertas interactivas pasan a Hecho"` (con el trailer `Co-Authored-By`).
