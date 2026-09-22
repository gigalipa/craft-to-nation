# Vías de Tierra Pisada Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Primer tipo de vía transitable (`tierra_pisada`) trazable en la cámara cenital: overlay 2×2 sobre terreno/relleno, cuñas para desniveles de 1 bloque, relleno para desniveles de 2-3, bono de velocidad para colonos y avatar, y rechazo de choque con edificios/puestos en ambos sentidos.

**Architecture:** Mismo patrón de capas que el resto del proyecto — autoload de estado puro (`Vias.gd`, como `Zonificacion.gd`), clases `RefCounted` de lógica pura y testeable con mundos falsos (`NiveladorVia.gd`, `TrazadorVias.gd`, `ConstructorVias.gd`, como `NiveladorTerreno.gd`), un renderer de nodo que solo dibuja lo que el estado dice (`ViasRenderer.gd`, calcado de `TranslucidosRenderer.gd`), y el modo de interacción en `CamaraCenital.gd` (como zonificar/colocar puesto). Dos piezas nuevas en la `MeshLibrary` (`cuna_recta`, `cuna_esquina`), regeneradas con el workaround headless porque el bridge del editor de Godot está roto en este entorno.

**Tech Stack:** Godot 4.7 GDScript, MCP de Godot (`mcp__godot__run_project`/`get_debug_output`/`stop_project`) para verificación headless, binario real de Godot para el workaround de MeshLibrary.

**Spec:** `docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md`

## Global Constraints

- Tabulaciones en todo GDScript (exigido por Godot, ver CLAUDE.md).
- Español en comentarios, mensajes y nombres — mismo idioma que el resto del código.
- `Vector2i(x, z)` para columnas del grid en planta (convención ya usada por `Zonificacion.gd`/`NiveladorTerreno.gd`: la coordenada mundial Z vive en `.y`).
- Ningún sistema nuevo cava terreno — solo rellena (spec Sección 2).
- `tierra_pisada`: `ancho 2`, `sentido doble`, `bono_velocidad 1.35`, `costo {}` (gratis). Ningún otro tipo de vía se implementa en este plan.
- `LIMITE_DESNIVEL_VIA := 3` — por encima, el trazador rechaza el tramo (sistema de puentes, fuera de alcance).
- No editar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python (CLAUDE.md).
- `godot/scripts/*.gd` con tabs; los `.tres`/`.tscn` se escriben o regeneran como texto plano, sin depender de `mcp__godot__save_scene`/`get_uid`/`export_mesh_library` (rotos en este entorno — ver memoria de sesión "Godot editor bridge broken").

---

## File Structure

**Nuevos:**
- `godot/scripts/Vias.gd` — autoload, estado (`celdas`, `_columnas`, `TIPOS`) y API pública.
- `godot/scripts/NiveladorVia.gd` — lógica pura: bloque de soporte de un vértice, su nivel, y el plan de relleno+cuña entre dos bloques consecutivos.
- `godot/scripts/TrazadorVias.gd` — A* puro sobre vértices (8 vecinos) para la vista previa/ruta del trazador.
- `godot/scripts/ConstructorVias.gd` — traduce una lista de vértices ya confirmada en cambios reales sobre el mundo y el registro de `Vias.gd`.
- `godot/scripts/ViasRenderer.gd` — overlay visual de los tramos planos (nodo, hijo de `VoxelWorld`).
- `godot/scripts/ViaPreviewOverlay.gd` — planos de vista previa mientras se traza (nodo, hermano de `ZonaOverlay`).
- `godot/scripts/ViasTest.gd` + `godot/scenes/ViasTest.tscn` — pruebas automatizadas de todo lo de arriba.
- `godot/assets/mat_tierra_pisada.tres` — material del overlay plano y del relleno.
- Script temporal (no se commitea) para regenerar `assets/BlockLibrary.res` con las 2 piezas nuevas.

**Modificados:**
- `godot/project.godot` — registra el autoload `Vias`.
- `godot/scenes/BlockLibrarySource.tscn` / `godot/assets/BlockLibrary.res` — regenerados (agrega `cuna_recta`, `cuna_esquina`), sin tocar los ítems existentes.
- `godot/scripts/VoxelWorld.gd` — `id_de_tipo()` público nuevo; `_retirar_bloque()` avisa a `Vias.quitar()`; `_ready()` conecta `ViasRenderer`.
- `godot/scenes/Main.tscn` — agrega `ViasRenderer` (hijo de `VoxelWorld`) y `ViaPreviewOverlay` (hermano de `ZonaOverlay`).
- `godot/scripts/CamaraCenital.gd` — modo trazador (tecla `V`), previsualización, confirmación, y el choque inverso en `_huella_choca_con_otro_puesto()`.
- `godot/scripts/Colonos.gd` / `godot/scripts/Player.gd` — bono de velocidad sobre vía.
- `docs/Pendientes y próximos pasos.md` — marca el punto 1 ("Vías de tierra pisada...") como iniciado/resuelto.

---

### Task 1: `Vias.gd` — registro y catálogo

**Files:**
- Create: `godot/scripts/Vias.gd`
- Create: `godot/scripts/ViasTest.gd`
- Create: `godot/scenes/ViasTest.tscn`
- Modify: `godot/project.godot`

**Interfaces:**
- Produces: `Vias.TIPOS: Dictionary`, `Vias.celdas: Dictionary` (`Vector3i` → `String`), `Vias.es_via(soporte: Vector3i) -> bool`, `Vias.tipo_en(soporte: Vector3i) -> String`, `Vias.bono_en(soporte: Vector3i) -> float`, `Vias.hay_via_en_columna(xz: Vector2i) -> bool`, `Vias.agregar(celdas: Array, tipo: String) -> void`, `Vias.quitar(celdas: Array) -> void`, señal `Vias.vias_cambiadas(celdas: Array)`.

- [ ] **Step 1: Escribir `godot/assets/mat_tierra_pisada.tres`**

```
[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(0.32, 0.21, 0.1, 1)
```

- [ ] **Step 2: Escribir `Vias.gd`**

```gdscript
extends Node

## Autoload "Vias": estado puro y catálogo de las vías (ver GDD Sección 4,
## docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md). Sin
## class_name (colisionaría con el nombre del autoload, mismo motivo que
## Ciudad.gd/Zonificacion.gd). No depende de ningún nodo de escena.
##
## Convención: Vector2i(x, z) para columnas en planta — la coordenada
## mundial Z vive en el campo .y (misma convención que Zonificacion.gd).

## Catálogo por datos. Único tipo implementado: "tierra_pisada". Tipos
## futuros (calzada, vía férrea, cintas, tuberías, calzada peatonal — ver
## GDD Sección 3.1/4) se agregan aquí como filas nuevas cuando se
## implementen, nunca antes.
var TIPOS: Dictionary = {
	"tierra_pisada": {
		"ancho": 2,
		"sentido": "doble",
		"bono_velocidad": 1.35,
		"costo": {},
		"material": preload("res://assets/mat_tierra_pisada.tres"),
	},
}

## Celda de SOPORTE (el bloque que lleva la vía en su cara superior:
## terreno nivelado, relleno, o una cuna_recta/cuna_esquina) -> tipo.
var celdas: Dictionary = {}  # Vector3i -> String

## Índice derivado de "celdas" por columna XZ, para hay_via_en_columna()
## sin recorrer "celdas" entero — mantenido en agregar()/quitar().
var _columnas: Dictionary = {}  # Vector2i -> int (cuántas celdas de esa columna hay en "celdas")

## Emitida cuando agregar()/quitar() cambian el registro — ViasRenderer la
## escucha para reconstruir solo los chunks afectados (ver spec Sección 3).
signal vias_cambiadas(celdas: Array)


func es_via(soporte: Vector3i) -> bool:
	return celdas.has(soporte)


func tipo_en(soporte: Vector3i) -> String:
	return celdas.get(soporte, "")


## Multiplicador de velocidad de la celda de SOPORTE "soporte" (el bloque
## bajo los pies, no la celda donde está parado el personaje) — 1.0 si no
## es vía. Ver spec Sección 7.
func bono_en(soporte: Vector3i) -> float:
	if not es_via(soporte):
		return 1.0
	return TIPOS[tipo_en(soporte)]["bono_velocidad"]


func hay_via_en_columna(xz: Vector2i) -> bool:
	return _columnas.get(xz, 0) > 0


func agregar(celdas_nuevas: Array, tipo: String) -> void:
	for celda: Vector3i in celdas_nuevas:
		if not celdas.has(celda):
			var xz := Vector2i(celda.x, celda.z)
			_columnas[xz] = _columnas.get(xz, 0) + 1
		celdas[celda] = tipo
	vias_cambiadas.emit(celdas_nuevas)


func quitar(celdas_a_quitar: Array) -> void:
	var quitadas: Array = []
	for celda: Vector3i in celdas_a_quitar:
		if not celdas.has(celda):
			continue
		celdas.erase(celda)
		var xz := Vector2i(celda.x, celda.z)
		_columnas[xz] = _columnas.get(xz, 1) - 1
		if _columnas[xz] <= 0:
			_columnas.erase(xz)
		quitadas.append(celda)
	if not quitadas.is_empty():
		vias_cambiadas.emit(quitadas)
```

- [ ] **Step 3: Registrar el autoload**

En `godot/project.godot`, bajo `[autoload]` (junto a los demás), agregar:

```
Vias="*res://scripts/Vias.gd"
```

- [ ] **Step 4: Escribir `godot/scenes/ViasTest.tscn`**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/ViasTest.gd" id="1"]

[node name="ViasTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 5: Escribir `ViasTest.gd` con las primeras pruebas (registro)**

```gdscript
extends Node

## Pruebas aisladas de Vias.gd/NiveladorVia.gd/TrazadorVias.gd/
## ConstructorVias.gd, sin escena visual — corre esta escena y revisa que
## no lance ningún assert(). Mismo patrón que ZonificacionTest.gd/
## NiveladorTerrenoTest.gd.

const NiveladorVia = preload("res://scripts/NiveladorVia.gd")
const TrazadorVias = preload("res://scripts/TrazadorVias.gd")
const ConstructorVias = preload("res://scripts/ConstructorVias.gd")


func _ready() -> void:
	ejecutar_pruebas()
	print("=== TODAS LAS PRUEBAS DE ViasTest PASARON ===")


func ejecutar_pruebas() -> void:
	print("=== TEST 1: agregar()/es_via()/tipo_en() ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var celda := Vector3i(5, 10, 5)
	assert(not Vias.es_via(celda))
	Vias.agregar([celda], "tierra_pisada")
	assert(Vias.es_via(celda))
	assert(Vias.tipo_en(celda) == "tierra_pisada")

	print("\n=== TEST 2: bono_en() ===")
	assert(is_equal_approx(Vias.bono_en(celda), 1.35))
	assert(is_equal_approx(Vias.bono_en(Vector3i(0, 0, 0)), 1.0))

	print("\n=== TEST 3: hay_via_en_columna() ===")
	assert(Vias.hay_via_en_columna(Vector2i(5, 5)))
	assert(not Vias.hay_via_en_columna(Vector2i(0, 0)))

	print("\n=== TEST 4: quitar() ===")
	Vias.quitar([celda])
	assert(not Vias.es_via(celda))
	assert(not Vias.hay_via_en_columna(Vector2i(5, 5)))

	print("\n=== TEST 5: quitar() una celda que no es vía es no-op ===")
	Vias.quitar([Vector3i(1, 1, 1)])  # no debe lanzar error
```

- [ ] **Step 6: Verificar headless**

Run `mcp__godot__run_project` con `scene: "res://scenes/ViasTest.tscn"`, luego `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project` (o el equivalente en Bash si el MCP de Godot no está disponible — ver memoria de sesión sobre `stop_project` poco confiable: confirmar con `Get-Process` que no queden procesos huérfanos). Esperado: `=== TODAS LAS PRUEBAS DE ViasTest PASARON ===` sin ningún error de aserción.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Vias.gd godot/scripts/ViasTest.gd godot/scenes/ViasTest.tscn godot/assets/mat_tierra_pisada.tres godot/project.godot
git commit -m "feat: registro y catálogo de Vias.gd (tierra_pisada)"
```

---

### Task 2: `NiveladorVia.gd` — bloque de soporte y su nivel

**Files:**
- Create: `godot/scripts/NiveladorVia.gd`
- Modify: `godot/scripts/ViasTest.gd`

**Interfaces:**
- Consumes: `NiveladorTerreno.gd` (`altura_objetivo(esquina, columnas)`, `calcular_relleno_hasta(esquina, columnas, tope)` — ya existen, ver `godot/scripts/NiveladorTerreno.gd:76`/`:94`).
- Produces: `NiveladorVia.new(fuente_de_altura: Object)`, `bloque_de_vertice(vertice: Vector2i) -> Array[Vector2i]`, `nivel_de_bloque(vertice: Vector2i) -> int`.

- [ ] **Step 1: Escribir el test de `bloque_de_vertice()`/`nivel_de_bloque()`**

Agregar a `ViasTest.gd`, dentro de `ejecutar_pruebas()` (después del TEST 5), una clase de generador falso y las aserciones:

```gdscript
## Generador falso: altura = x + z (una pendiente diagonal simple para
## probar niveles de bloque distintos entre vértices vecinos).
class GeneradorPendienteDiagonal:
	func altura_en(x: int, z: int) -> int:
		return x + z


## Generador falso: altura constante 10 en todo el mapa.
class GeneradorPlano:
	func altura_en(_x: int, _z: int) -> int:
		return 10
```

y en `ejecutar_pruebas()`:

```gdscript
	print("\n=== TEST 6: bloque_de_vertice() — 4 columnas alrededor del vértice ===")
	var nivelador_plano := NiveladorVia.new(GeneradorPlano.new())
	var bloque: Array[Vector2i] = nivelador_plano.bloque_de_vertice(Vector2i(5, 5))
	assert(bloque.size() == 4)
	for esperado in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		assert(bloque.has(esperado))

	print("\n=== TEST 7: nivel_de_bloque() en terreno plano ===")
	assert(nivelador_plano.nivel_de_bloque(Vector2i(5, 5)) == 10)

	print("\n=== TEST 8: nivel_de_bloque() usa el máximo de las 4 columnas ===")
	var nivelador_diagonal := NiveladorVia.new(GeneradorPendienteDiagonal.new())
	# Vértice (1,1): columnas (0,0)=0, (1,0)=1, (0,1)=1, (1,1)=2 -> máximo 2.
	assert(nivelador_diagonal.nivel_de_bloque(Vector2i(1, 1)) == 2)
```

- [ ] **Step 2: Run test para confirmar que falla**

Run `mcp__godot__run_project` con `ViasTest.tscn`. Esperado: FALLA en el TEST 6 con "Invalid call. Nonexistent function 'bloque_de_vertice'" o similar (la clase `NiveladorVia` no existe todavía).

- [ ] **Step 3: Escribir `NiveladorVia.gd`**

```gdscript
extends RefCounted

## Lógica pura de relleno y cuñas para vías (ver GDD Sección 4, spec
## docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md Sección
## 2) — sin nodos, mismo patrón que NiveladorTerreno.gd. Reutiliza
## NiveladorTerreno para el cálculo de nivel/relleno de un bloque 2x2 en
## vez de reimplementarlo.
##
## No depende de una clase concreta: solo llama a .altura_en(x, z) por
## duck typing sobre lo que se le pase en _init() — mismo contrato que
## NiveladorTerreno.

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")

## Desnivel máximo entre dos bloques de vía consecutivos que esta pieza
## resuelve con relleno + cuña; por encima, el trazador (TrazadorVias)
## rechaza el paso — queda para el sistema de puentes futuro.
const LIMITE_DESNIVEL_VIA := 3

## Las 4 columnas del bloque de soporte de un vértice, relativas a la
## esquina (mínimo x, mínimo z) de ese bloque — ver bloque_de_vertice().
const COLUMNAS_BLOQUE: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
]

var _generador: Object
var _nivelador_terreno: RefCounted


func _init(fuente_de_altura: Object) -> void:
	_generador = fuente_de_altura
	_nivelador_terreno = NiveladorTerreno.new(fuente_de_altura)


## Esquina (mínimo x, mínimo z) del bloque de soporte 2x2 de "vertice" —
## el vértice es la esquina compartida por esas 4 columnas (ver spec
## Sección 1).
func _esquina_de(vertice: Vector2i) -> Vector2i:
	return vertice - Vector2i(1, 1)


## Las 4 columnas (X,Z) del bloque de soporte de "vertice".
func bloque_de_vertice(vertice: Vector2i) -> Array[Vector2i]:
	var esquina: Vector2i = _esquina_de(vertice)
	var columnas: Array[Vector2i] = []
	for rel in COLUMNAS_BLOQUE:
		columnas.append(esquina + rel)
	return columnas


## Altura a la que se nivela el bloque de soporte de "vertice" — el
## máximo entre sus 4 columnas (nunca se cava, ver spec Sección 2).
func nivel_de_bloque(vertice: Vector2i) -> int:
	return _nivelador_terreno.altura_objetivo(_esquina_de(vertice), COLUMNAS_BLOQUE)
```

- [ ] **Step 4: Run test para confirmar que pasa**

Run `mcp__godot__run_project` con `ViasTest.tscn`. Esperado: los TEST 1-8 pasan.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/NiveladorVia.gd godot/scripts/ViasTest.gd
git commit -m "feat: NiveladorVia.bloque_de_vertice()/nivel_de_bloque()"
```

---

### Task 3: `NiveladorVia.gd` — plan de relleno y cuña entre bloques

**Files:**
- Modify: `godot/scripts/NiveladorVia.gd`
- Modify: `godot/scripts/ViasTest.gd`

**Interfaces:**
- Produces: `NiveladorVia.plan_transicion(vertice_a: Vector2i, vertice_b: Vector2i) -> Dictionary` — `{}` si el desnivel es 0; si no, `{"solape": Array[Vector2i], "y_base": int, "diagonal": bool, "direccion_alta": Vector2i, "relleno_extra": Dictionary}` (`relleno_extra`: `Vector2i` columna → `int` altura objetivo, vacío salvo que el desnivel sea 2 o 3).

- [ ] **Step 1: Escribir los tests de `plan_transicion()`**

Agregar a `ejecutar_pruebas()`:

```gdscript
	print("\n=== TEST 9: plan_transicion() con desnivel 0 -> {} ===")
	assert(nivelador_plano.plan_transicion(Vector2i(5, 5), Vector2i(6, 5)).is_empty())

	print("\n=== TEST 10: plan_transicion() paso recto, desnivel 1 -> cuña recta, sin relleno extra ===")
	# GeneradorEscalon: altura 0 para x<5, altura 1 para x>=5 (un escalón).
	var nivelador_escalon := NiveladorVia.new(GeneradorEscalon.new())
	var plan_recto: Dictionary = nivelador_escalon.plan_transicion(Vector2i(5, 5), Vector2i(6, 5))
	assert(not plan_recto.is_empty())
	assert(plan_recto["solape"].size() == 2)  # paso recto: 2 columnas de solape
	assert(not plan_recto["diagonal"])
	assert(plan_recto["y_base"] == 0)
	assert(plan_recto["direccion_alta"] == Vector2i(1, 0))
	assert(plan_recto["relleno_extra"].is_empty())

	print("\n=== TEST 11: plan_transicion() paso diagonal, desnivel 1 -> cuña de esquina ===")
	var plan_diagonal: Dictionary = nivelador_escalon.plan_transicion(Vector2i(5, 5), Vector2i(6, 6))
	assert(plan_diagonal["solape"].size() == 1)  # paso diagonal: 1 columna de solape
	assert(plan_diagonal["diagonal"])

	print("\n=== TEST 12: plan_transicion() con desnivel 3 -> relleno_extra hasta quedar a 1 ===")
	# GeneradorEscalonAlto: altura 0 para x<5, altura 3 para x>=5.
	var nivelador_alto := NiveladorVia.new(GeneradorEscalonAlto.new())
	var plan_alto: Dictionary = nivelador_alto.plan_transicion(Vector2i(5, 5), Vector2i(6, 5))
	assert(plan_alto["y_base"] == 2)  # nivel_alto(3) - 1
	assert(not plan_alto["relleno_extra"].is_empty())
	for columna in plan_alto["relleno_extra"]:
		assert(plan_alto["relleno_extra"][columna] == 2)
```

y las clases falsas correspondientes (junto a `GeneradorPlano`/`GeneradorPendienteDiagonal`):

```gdscript
## Escalón: altura 0 para x<5, altura 1 para x>=5 (desnivel de 1 bloque).
class GeneradorEscalon:
	func altura_en(x: int, _z: int) -> int:
		return 1 if x >= 5 else 0


## Escalón alto: altura 0 para x<5, altura 3 para x>=5 (desnivel de 3).
class GeneradorEscalonAlto:
	func altura_en(x: int, _z: int) -> int:
		return 3 if x >= 5 else 0
```

- [ ] **Step 2: Run test para confirmar que falla**

Esperado: FALLA con "Invalid call. Nonexistent function 'plan_transicion'".

- [ ] **Step 3: Escribir `plan_transicion()` en `NiveladorVia.gd`**

Agregar al final de la clase:

```gdscript
## Columnas absolutas de "columnas" que hace falta rellenar (relativo a
## sí mismas, sin pasar por esquina/relativo de NiveladorTerreno — mismo
## cálculo que calcular_relleno_hasta() pero con columnas ya absolutas).
func _relleno_absoluto(columnas: Array[Vector2i], tope: int) -> Dictionary:
	var relleno: Dictionary = {}
	for col in columnas:
		var faltante: int = tope - _generador.altura_en(col.x, col.y)
		if faltante > 0:
			relleno[col] = faltante
	return relleno


## Plan de transición entre dos bloques de vía consecutivos (un paso, 8
## direcciones — ver spec Sección 2): {} si el desnivel es 0. Si no:
## "solape" son las columnas compartidas por ambos bloques (2 en paso
## recto, 1 en diagonal — ver bloque_de_vertice()); "y_base" es la altura
## del lado bajo de la cuña que va ahí; "diagonal" indica qué pieza usar
## (cuna_esquina si true, cuna_recta si false); "direccion_alta" apunta
## del vértice bajo al alto (para orientar la pieza); "relleno_extra"
## (columnas del bloque bajo, sin las de solape) solo tiene entradas si
## el desnivel es 2 o 3: sube ese bloque hasta quedar a 1 del alto, antes
## de que la cuña resuelva el último escalón.
func plan_transicion(vertice_a: Vector2i, vertice_b: Vector2i) -> Dictionary:
	var paso: Vector2i = vertice_b - vertice_a
	var bloque_a: Array[Vector2i] = bloque_de_vertice(vertice_a)
	var bloque_b: Array[Vector2i] = bloque_de_vertice(vertice_b)
	var solape: Array[Vector2i] = []
	for col in bloque_a:
		if bloque_b.has(col):
			solape.append(col)

	var nivel_a: int = nivel_de_bloque(vertice_a)
	var nivel_b: int = nivel_de_bloque(vertice_b)
	if nivel_a == nivel_b:
		return {}

	var vertice_bajo: Vector2i = vertice_a if nivel_a < nivel_b else vertice_b
	var nivel_bajo: int = mini(nivel_a, nivel_b)
	var nivel_alto: int = maxi(nivel_a, nivel_b)
	var y_base: int = nivel_bajo
	var relleno_extra: Dictionary = {}
	if nivel_alto - nivel_bajo > 1:
		y_base = nivel_alto - 1
		var columnas_a_rellenar: Array[Vector2i] = []
		for col in bloque_de_vertice(vertice_bajo):
			if not solape.has(col):
				columnas_a_rellenar.append(col)
		relleno_extra = _relleno_absoluto(columnas_a_rellenar, y_base)

	return {
		"solape": solape,
		"y_base": y_base,
		"diagonal": paso.x != 0 and paso.y != 0,
		"direccion_alta": paso if nivel_b > nivel_a else -paso,
		"relleno_extra": relleno_extra,
	}
```

- [ ] **Step 4: Run test para confirmar que pasa**

Esperado: TEST 9-12 pasan.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/NiveladorVia.gd godot/scripts/ViasTest.gd
git commit -m "feat: NiveladorVia.plan_transicion() (relleno y cuña entre bloques)"
```

---

### Task 4: piezas `cuna_recta`/`cuna_esquina` en la MeshLibrary

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn` (regenerado por script, no a mano)
- Modify: `godot/assets/BlockLibrary.res` (regenerado por script)
- Modify: `godot/scripts/ViasTest.gd`
- Create/Delete temporal: `godot/scripts/_temp_generar_cunas.gd`

**Interfaces:**
- Produces: 2 ítems nuevos en la `MeshLibrary` compartida, `"cuna_recta"` y `"cuna_esquina"`, cada uno con malla + `ConvexPolygonShape3D`, consumidos por `VoxelWorld._id_por_tipo`/`id_de_tipo()` (Task 5) igual que cualquier otro tipo de bloque.

Sin prueba GDScript para la geometría en sí (es un recurso binario) — se verifica indirectamente (los ítems existen y el mundo carga sin error) y visualmente cuando el usuario juegue.

- [ ] **Step 1: Escribir el script temporal `godot/scripts/_temp_generar_cunas.gd`**

```gdscript
extends SceneTree

## Script de un solo uso para regenerar BlockLibrarySource.tscn/
## BlockLibrary.res con las piezas "cuna_recta"/"cuna_esquina" — el
## bridge del editor de Godot (mcp__godot__save_scene/export_mesh_library)
## está roto en este entorno (ver memoria de sesión), así que se hace vía
## un binario real de Godot en modo headless. BORRAR este archivo al
## terminar (ver Step 3 de esta tarea).

const RUTA_ESCENA := "res://scenes/BlockLibrarySource.tscn"
const RUTA_MESH_LIBRARY := "res://assets/BlockLibrary.res"

## Color de ambas cuñas: mismo tono que assets/mat_tierra_pisada.tres —
## son parte del mismo camino, ver spec Sección 2/3.
const COLOR_CUNA := Color(0.32, 0.21, 0.1, 1)


func _init() -> void:
	var escena: PackedScene = load(RUTA_ESCENA)
	var raiz: Node3D = escena.instantiate()

	_agregar_pieza(raiz, "cuna_recta", _malla_cuna_recta(), _forma_cuna_recta())
	_agregar_pieza(raiz, "cuna_esquina", _malla_cuna_esquina(), _forma_cuna_esquina())

	var empaquetada := PackedScene.new()
	empaquetada.pack(raiz)
	print("Guardar escena: ", ResourceSaver.save(empaquetada, RUTA_ESCENA))

	var biblioteca := MeshLibrary.new()
	var id := 0
	for hijo in raiz.get_children():
		if not (hijo is MeshInstance3D):
			continue
		biblioteca.create_item(id)
		biblioteca.set_item_name(id, hijo.name)
		biblioteca.set_item_mesh(id, hijo.mesh)
		var colision: CollisionShape3D = hijo.get_node_or_null("CollisionShape3D")
		if colision != null:
			biblioteca.set_item_shapes(id, [colision.shape, Transform3D.IDENTITY])
		id += 1
	print("Guardar MeshLibrary: ", ResourceSaver.save(biblioteca, RUTA_MESH_LIBRARY))

	raiz.queue_free()
	quit()


func _agregar_pieza(raiz: Node3D, nombre: String, malla: ArrayMesh, forma: ConvexPolygonShape3D) -> void:
	if raiz.has_node(nombre):
		print(nombre, " ya existe, no se duplica")
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_CUNA
	# Sin depender del orden de los triángulos (derivados a mano, ver
	# abajo): se dibujan ambas caras para no arriesgar una cara invisible
	# por winding invertido — mismo criterio que assets/mat_agua.tres.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla.surface_set_material(0, material)
	var instancia := MeshInstance3D.new()
	instancia.name = nombre
	instancia.mesh = malla
	raiz.add_child(instancia)
	instancia.owner = raiz
	var colision := CollisionShape3D.new()
	colision.name = "CollisionShape3D"
	colision.shape = forma
	instancia.add_child(colision)
	colision.owner = raiz


static func _normal_de(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (b - a).cross(c - a).normalized()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := _normal_de(a, b, c)
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


## Cuña recta: cubo unitario con pendiente a lo largo de Z (altura 0 en
## z=0, altura 1 en z=1), constante en X — el trazador la orienta hacia
## "direccion_alta" rotando alrededor de Y (ver ConstructorVias._orientacion(),
## Task 8), tomando +Z como la dirección de referencia con la que se
## modeló aquí.
static func _malla_cuna_recta() -> ArrayMesh:
	var b00 := Vector3(0, 0, 0)
	var b10 := Vector3(1, 0, 0)
	var b01 := Vector3(0, 0, 1)
	var b11 := Vector3(1, 0, 1)
	var t01 := Vector3(0, 1, 1)
	var t11 := Vector3(1, 1, 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, b00, b10, b11, b01)  # fondo
	_quad(st, b00, b10, t11, t01)  # rampa
	_quad(st, b01, b11, t11, t01)  # pared alta (z=1)
	_tri(st, b00, b01, t01)  # lado x=0
	_tri(st, b10, b11, t11)  # lado x=1
	return st.commit()


static func _forma_cuna_recta() -> ConvexPolygonShape3D:
	var forma := ConvexPolygonShape3D.new()
	forma.points = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1),
		Vector3(0, 1, 1), Vector3(1, 1, 1),
	])
	return forma


## Cuña de esquina: baja en (0,0), alta en (1,1) — superficie plana con
## altura(x,z) = (x+z)/2 (un único plano inclinado, sin quiebre — ver spec
## Sección 2/3). Referencia de orientación: +X+Z es la dirección "alta".
static func _malla_cuna_esquina() -> ArrayMesh:
	var b00 := Vector3(0, 0, 0)
	var b10 := Vector3(1, 0, 0)
	var b11 := Vector3(1, 0, 1)
	var b01 := Vector3(0, 0, 1)
	var t10 := Vector3(1, 0.5, 0)
	var t11 := Vector3(1, 1, 1)
	var t01 := Vector3(0, 0.5, 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, b00, b10, b11, b01)  # fondo
	_quad(st, b00, t10, t11, t01)  # rampa
	_tri(st, b00, b10, t10)  # lado z=0
	_quad(st, b10, b11, t11, t10)  # lado x=1
	_quad(st, b11, b01, t01, t11)  # lado z=1
	_tri(st, b01, b00, t01)  # lado x=0
	return st.commit()


static func _forma_cuna_esquina() -> ConvexPolygonShape3D:
	var forma := ConvexPolygonShape3D.new()
	forma.points = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1),
		Vector3(1, 0.5, 0), Vector3(1, 1, 1), Vector3(0, 0.5, 1),
	])
	return forma
```

- [ ] **Step 2: Ejecutarlo con el binario real de Godot (workaround headless)**

```bash
GODOT="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
PROYECTO="C:/Users/peraz/Projects/Misc/CityCraft/godot"
SALIDA="$CLAUDE_SCRATCHPAD_DIR/salida_cunas.txt"  # o la ruta del scratchpad de la sesión
"$GODOT" --headless --path "$PROYECTO" --script res://scripts/_temp_generar_cunas.gd > "$SALIDA" 2>&1
cat "$SALIDA"
```

Esperado: dos líneas `Guardar escena: 0` y `Guardar MeshLibrary: 0` (`0` = `OK` en `Error`), sin errores de script.

- [ ] **Step 3: Borrar el script temporal**

```bash
rm godot/scripts/_temp_generar_cunas.gd
```

- [ ] **Step 4: Agregar la prueba de existencia de los ítems**

En `ViasTest.gd`, dentro de `ejecutar_pruebas()`:

```gdscript
	print("\n=== TEST 13: la MeshLibrary tiene cuna_recta y cuna_esquina ===")
	var biblioteca: MeshLibrary = preload("res://assets/BlockLibrary.res")
	var nombres: Dictionary = {}
	for id in biblioteca.get_item_list():
		nombres[biblioteca.get_item_name(id)] = true
	assert(nombres.has("cuna_recta"))
	assert(nombres.has("cuna_esquina"))
```

- [ ] **Step 5: Verificar headless (ViasTest + Main sin errores nuevos)**

Run `mcp__godot__run_project` con `ViasTest.tscn` (TEST 13 pasa) y luego con `Main.tscn` (`get_debug_output`, confirmar que sigue cargando sin errores nuevos — la MeshLibrary regenerada debe conservar los ítems existentes).

- [ ] **Step 6: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scripts/ViasTest.gd
git commit -m "feat: piezas cuna_recta/cuna_esquina en la MeshLibrary"
```

---

### Task 5: `ViasRenderer.gd` — overlay de los tramos planos

**Files:**
- Create: `godot/scripts/ViasRenderer.gd`
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scenes/Main.tscn`

**Interfaces:**
- Consumes: `Vias.celdas`, `Vias.es_via()`, `Vias.TIPOS`, `Vias.vias_cambiadas` (Task 1); `TranslucidosRenderer._agregar_cara(st, centro, direccion)` (geometría reutilizada, ver `godot/scripts/TranslucidosRenderer.gd:136`).
- Produces: `VoxelWorld.id_de_tipo(tipo: String) -> int` (público, usado por `ConstructorVias` en Task 7); `_retirar_bloque()` ahora llama a `Vias.quitar([celda])`.

Sin prueba GDScript (es geometría/render, mismo criterio que `TranslucidosRendererTest.gd`: solo carga headless sin error). La cobertura funcional de qué celdas cuentan como vía ya está en `ViasTest.gd` (Task 1); este renderer solo dibuja lo que `Vias.gd` ya diga.

- [ ] **Step 1: Agregar `id_de_tipo()` a `VoxelWorld.gd`**

Justo después de `material_real()` (cerca de la línea 122):

```gdscript
## Id numérico de "tipo" en la MeshLibrary indexada (ver
## _indexar_biblioteca()), o GridMap.INVALID_CELL_ITEM si no existe —
## acceso público de solo lectura a _id_por_tipo para quien necesite
## colocar una celda con GridMap.set_cell_item() directamente (con
## orientación), sin pasar por colocar_bloque() — que no soporta
## orientación y se niega a sobrescribir una celda ya ocupada. Usado por
## ConstructorVias.gd al reemplazar un relleno recién colocado por su
## cuña (ver spec de vías Sección 5).
func id_de_tipo(tipo: String) -> int:
	return _id_por_tipo.get(tipo, GridMap.INVALID_CELL_ITEM)
```

- [ ] **Step 2: Escribir `ViasRenderer.gd`**

```gdscript
extends Node3D

## Overlay visual de los tramos PLANOS de vía (ver spec de vías Sección
## 3): una malla delgada pegada a la cara superior de cada celda de
## soporte registrada en Vias.celdas, salvo que el soporte sea una cuña
## (esa ya es la superficie visible). Mismo patrón de chunks que
## TranslucidosRenderer.gd — reconstruye solo el chunk sucio; reutiliza su
## geometría de cara (_agregar_cara()) en vez de reimplementarla.

const TranslucidosRenderer = preload("res://scripts/TranslucidosRenderer.gd")

const CHUNK_SIZE := 16
const DESF := 0.5
const ARRIBA := Vector3i(0, 1, 0)

## Asignado por VoxelWorld._ready() antes de llamar a reconstruir_todo() —
## mismo patrón que TranslucidosRenderer.voxel_world.
var voxel_world: Node

var _mesh_por_chunk: Dictionary = {}  # Vector3i -> MeshInstance3D
var _chunks_sucios: Dictionary = {}  # Vector3i -> true


static func _chunk_de(celda: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(celda.x) / CHUNK_SIZE),
		floori(float(celda.y) / CHUNK_SIZE),
		floori(float(celda.z) / CHUNK_SIZE),
	)


func _reconstruir_chunk(chunk: Vector3i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origen: Vector3i = chunk * CHUNK_SIZE
	var hay_caras := false
	for dx in range(CHUNK_SIZE):
		for dy in range(CHUNK_SIZE):
			for dz in range(CHUNK_SIZE):
				var celda: Vector3i = origen + Vector3i(dx, dy, dz)
				if not Vias.es_via(celda):
					continue
				var tipo: String = voxel_world.obtener_tipo(celda)
				if tipo == "cuna_recta" or tipo == "cuna_esquina":
					continue
				TranslucidosRenderer._agregar_cara(st, Vector3(celda) + Vector3.ONE * DESF, ARRIBA)
				hay_caras = true

	if not hay_caras:
		if _mesh_por_chunk.has(chunk):
			_mesh_por_chunk[chunk].queue_free()
			_mesh_por_chunk.erase(chunk)
		return

	var malla: ArrayMesh = st.commit()
	var instancia: MeshInstance3D
	if _mesh_por_chunk.has(chunk):
		instancia = _mesh_por_chunk[chunk]
	else:
		instancia = MeshInstance3D.new()
		add_child(instancia)
		_mesh_por_chunk[chunk] = instancia
	instancia.mesh = malla
	instancia.set_surface_override_material(0, Vias.TIPOS["tierra_pisada"]["material"])


## Reconstrucción completa — llamada una vez desde VoxelWorld._ready().
func reconstruir_todo() -> void:
	var chunks: Dictionary = {}
	for celda: Vector3i in Vias.celdas:
		chunks[_chunk_de(celda)] = true
	for chunk in chunks:
		_reconstruir_chunk(chunk)


## Conectada a Vias.vias_cambiadas desde VoxelWorld._ready() — mismo
## motivo que TranslucidosRenderer._on_bloque_translucido_cambiado(): no
## reconstruye de inmediato, solo marca sucio (ver flush_pendientes()).
func _on_vias_cambiadas(celdas: Array) -> void:
	for celda: Vector3i in celdas:
		_chunks_sucios[_chunk_de(celda)] = true


func flush_pendientes() -> void:
	for chunk in _chunks_sucios:
		_reconstruir_chunk(chunk)
	_chunks_sucios.clear()


func _process(_delta: float) -> void:
	flush_pendientes()
```

- [ ] **Step 3: Conectar en `VoxelWorld.gd`**

En `_retirar_bloque()` (cerca de la línea 601), al final del cuerpo (después de `_escurrir_agua_desde(vecinos_agua)`), agregar:

```gdscript
	Vias.quitar([celda])
```

En `_ready()` (cerca de la línea 380), después del bloque de `FantasmasDestacados` (`fantasmas_cambiados.connect(destacados.marcar_sucio)`), agregar:

```gdscript
	var vias_renderer: Node3D = get_node("ViasRenderer")
	vias_renderer.voxel_world = self
	Vias.vias_cambiadas.connect(vias_renderer._on_vias_cambiadas)
	vias_renderer.reconstruir_todo()
```

- [ ] **Step 4: Agregar el nodo a `Main.tscn`**

Agregar un `ext_resource` nuevo (id `"11"`, siguiendo el patrón sin `uid=` de los últimos scripts agregados, ver `godot/scenes/Main.tscn:10-12`):

```
[ext_resource type="Script" path="res://scripts/ViasRenderer.gd" id="11"]
```

Y, como hijo de `VoxelWorld` (junto a `TranslucidosRenderer`/`FantasmasDestacados`):

```
[node name="ViasRenderer" type="Node3D" parent="VoxelWorld"]
script = ExtResource("11")
```

- [ ] **Step 5: Verificar headless**

Run `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"`, `get_debug_output`, `stop_project`. Esperado: sin errores nuevos al cargar (headless no puede probar el dibujado real, pero confirma que `ViasRenderer`/`id_de_tipo()`/el hook de `Vias.quitar()` no rompen la carga).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/ViasRenderer.gd godot/scripts/VoxelWorld.gd godot/scenes/Main.tscn
git commit -m "feat: ViasRenderer (overlay de tramos planos de vía)"
```

---

### Task 6: `TrazadorVias.gd` — A* sobre vértices

**Files:**
- Create: `godot/scripts/TrazadorVias.gd`
- Modify: `godot/scripts/ViasTest.gd`

**Interfaces:**
- Consumes: `NiveladorVia.gd` (Task 2/3).
- Produces: `TrazadorVias.new(mundo: Object)`, `vertice_transitable(vertice: Vector2i) -> bool`, `paso_valido(a: Vector2i, b: Vector2i) -> bool`, `vecinos(vertice: Vector2i) -> Array[Vector2i]`, `buscar_ruta(origen: Vector2i, destino: Vector2i) -> Array[Vector2i]`, `bloque_de_vertice(vertice: Vector2i) -> Array[Vector2i]` (passthrough a `NiveladorVia`, para que `CamaraCenital.gd` no necesite instanciar `NiveladorVia` por separado).

- [ ] **Step 1: Escribir los tests**

Agregar a `ejecutar_pruebas()`:

```gdscript
	print("\n=== TEST 14: TrazadorVias — vecinos() da hasta 8 direcciones en terreno plano libre ===")
	var mundo_falso := MundoFalsoVias.new()
	var trazador := TrazadorVias.new(mundo_falso)
	var vecinos_5_5: Array[Vector2i] = trazador.vecinos(Vector2i(5, 5))
	assert(vecinos_5_5.size() == 8)

	print("\n=== TEST 15: TrazadorVias — un vértice con agua en su bloque no es transitable ===")
	mundo_falso.agua[Vector2i(4, 4)] = true  # una de las 4 columnas del bloque de (5,5)
	assert(not trazador.vertice_transitable(Vector2i(5, 5)))
	mundo_falso.agua.clear()

	print("\n=== TEST 16: TrazadorVias — un vértice con un edificio en su bloque no es transitable ===")
	mundo_falso.edificios[Vector2i(4, 4)] = true
	assert(not trazador.vertice_transitable(Vector2i(5, 5)))
	mundo_falso.edificios.clear()

	print("\n=== TEST 17: TrazadorVias — un árbol NO bloquea (se tala al confirmar) ===")
	mundo_falso.celdas[Vector3i(4, 1, 4)] = "madera"
	assert(trazador.vertice_transitable(Vector2i(5, 5)))
	mundo_falso.celdas.clear()

	print("\n=== TEST 18: TrazadorVias — buscar_ruta() en terreno plano ===")
	var ruta: Array[Vector2i] = trazador.buscar_ruta(Vector2i(0, 0), Vector2i(3, 0))
	assert(ruta.size() == 3)
	assert(ruta[-1] == Vector2i(3, 0))

	print("\n=== TEST 19: TrazadorVias — buscar_ruta() rechaza desnivel > 3 ===")
	var mundo_escalon := MundoFalsoVias.new()
	mundo_escalon.escalon_en_x = 3
	mundo_escalon.altura_escalon = 5  # desnivel de 5 entre x=2 y x=3, por encima del límite de 3
	var trazador_escalon := TrazadorVias.new(mundo_escalon)
	assert(trazador_escalon.buscar_ruta(Vector2i(0, 0), Vector2i(5, 0)).is_empty())
```

y el mundo falso (junto a las demás clases de prueba):

```gdscript
## Mundo falso para TrazadorVias/ConstructorVias: terreno plano en
## altura_en() = 0, salvo un escalón opcional en X (escalon_en_x/
## altura_escalon), con columnas de agua/edificio marcables a mano.
class MundoFalsoVias:
	var celdas: Dictionary = {}  # Vector3i -> String
	var agua: Dictionary = {}  # Vector2i -> true
	var edificios: Dictionary = {}  # Vector2i -> true
	var escalon_en_x := 999999
	var altura_escalon := 0
	var colocado_por_jugador: Dictionary = {}
	var _ids: Dictionary = {"tierra": 1, "cuna_recta": 2, "cuna_esquina": 3}

	func altura_en(x: int, _z: int) -> int:
		return altura_escalon if x >= escalon_en_x else 0

	func obtener_tipo(celda: Vector3i) -> String:
		var xz := Vector2i(celda.x, celda.z)
		if agua.get(xz, false) and celda.y == altura_en(celda.x, celda.z) + 1:
			return "agua"
		return celdas.get(celda, "")

	func id_de_edificio(celda: Vector3i) -> int:
		var xz := Vector2i(celda.x, celda.z)
		return 1 if edificios.get(xz, false) else -1

	func colocar_bloque(celda: Vector3i, tipo: String, _por_jugador: bool = false) -> bool:
		celdas[celda] = tipo
		return true

	func talar_bloque_de_arbol(celda: Vector3i, _dano: int) -> bool:
		if celdas.get(celda, "") != "madera":
			return false
		celdas.erase(celda)
		return true

	func eliminar_follaje(celda: Vector3i) -> void:
		celdas.erase(celda)

	func set_cell_item(celda: Vector3i, id: int, _orientacion: int) -> void:
		for tipo in _ids:
			if _ids[tipo] == id:
				celdas[celda] = tipo
				return

	func id_de_tipo(tipo: String) -> int:
		return _ids.get(tipo, -1)
```

- [ ] **Step 2: Run test para confirmar que falla**

Esperado: FALLA con "Invalid call. Nonexistent function 'vecinos'" (la clase `TrazadorVias` no existe todavía).

- [ ] **Step 3: Escribir `TrazadorVias.gd`**

```gdscript
extends RefCounted

## A* sobre VÉRTICES del grid (esquinas entre 4 celdas), para el trazador
## de vías de CamaraCenital.gd — ver spec de vías Sección 4. Distinto de
## BuscadorRutas.gd (que camina por CELDAS 3D con 4 vecinos, para NPCs):
## aquí se camina por VÉRTICES 2D con 8 vecinos (incluye diagonales), y el
## costo de moverse no depende de la física de un personaje sino de si el
## BLOQUE DE VÍA (NiveladorVia.nivel_de_bloque()) que representa ese
## vértice es alcanzable. Clase pura (RefCounted): "mundo" solo necesita
## altura_en(x, z), obtener_tipo(celda: Vector3i) e
## id_de_edificio(celda: Vector3i) -> int.

const NiveladorVia = preload("res://scripts/NiveladorVia.gd")

## Tope de nodos expandidos por consulta — mismo motivo que
## BuscadorRutas.MAX_NODOS_EXPANDIDOS, ajustado a un mapa más chico (esto
## es una previsualización interactiva, no pathfinding de NPCs).
const MAX_NODOS_EXPANDIDOS := 5000

const DIRECCIONES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var mundo: Object
var _nivelador: RefCounted


func _init(p_mundo: Object) -> void:
	mundo = p_mundo
	_nivelador = NiveladorVia.new(p_mundo)


## Passthrough a NiveladorVia — para que CamaraCenital.gd no necesite
## instanciar NiveladorVia por separado solo para consultar el bloque.
func bloque_de_vertice(vertice: Vector2i) -> Array[Vector2i]:
	return _nivelador.bloque_de_vertice(vertice)


## true si NINGUNA de las 4 columnas del bloque de soporte de "vertice"
## está ocupada por agua o por un edificio/obra — los árboles NO bloquean
## (se talan al confirmar, ver spec de vías Sección 5). Usa la superficie
## real del mundo (mundo.altura_en(x, z) + 1), igual que
## CamaraCenital._huella_choca_con_otro_puesto().
func vertice_transitable(vertice: Vector2i) -> bool:
	for col in _nivelador.bloque_de_vertice(vertice):
		var superficie := Vector3i(col.x, mundo.altura_en(col.x, col.y) + 1, col.y)
		if mundo.obtener_tipo(superficie) == "agua":
			return false
		if mundo.id_de_edificio(superficie) != -1:
			return false
	return true


## true si se puede pasar de "a" a "b" (adyacentes, 1 paso de
## DIRECCIONES): ambos transitables y el desnivel entre sus bloques no
## supera NiveladorVia.LIMITE_DESNIVEL_VIA.
func paso_valido(a: Vector2i, b: Vector2i) -> bool:
	if not (vertice_transitable(a) and vertice_transitable(b)):
		return false
	var desnivel: int = absi(_nivelador.nivel_de_bloque(b) - _nivelador.nivel_de_bloque(a))
	return desnivel <= NiveladorVia.LIMITE_DESNIVEL_VIA


## Vértices alcanzables en 1 paso desde "vertice" (de los 8 de DIRECCIONES).
func vecinos(vertice: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for direccion in DIRECCIONES:
		var candidato: Vector2i = vertice + direccion
		if paso_valido(vertice, candidato):
			resultado.append(candidato)
	return resultado


## Ruta más corta de "origen" a "destino" (SIN incluir el origen); [] si
## no hay ruta, si origen == destino, o si origen/destino no son
## transitables.
func buscar_ruta(origen: Vector2i, destino: Vector2i) -> Array[Vector2i]:
	var vacia: Array[Vector2i] = []
	if origen == destino:
		return vacia
	if not (vertice_transitable(origen) and vertice_transitable(destino)):
		return vacia

	var costo: Dictionary = {origen: 0}
	var padre: Dictionary = {}
	var cerrados: Dictionary = {}
	var abiertos: Array = []
	var desempate := 0
	_meter(abiertos, [_heuristica(origen, destino), desempate, origen])
	var expandidos := 0
	while not abiertos.is_empty():
		var actual: Vector2i = _sacar(abiertos)[2]
		if cerrados.has(actual):
			continue
		if actual == destino:
			var ruta: Array[Vector2i] = []
			var v: Vector2i = actual
			while v != origen:
				ruta.append(v)
				v = padre[v]
			ruta.reverse()
			return ruta
		cerrados[actual] = true
		expandidos += 1
		if expandidos > MAX_NODOS_EXPANDIDOS:
			return vacia
		for vecino in vecinos(actual):
			if cerrados.has(vecino):
				continue
			var nuevo_costo: int = costo[actual] + 1
			if not costo.has(vecino) or nuevo_costo < costo[vecino]:
				costo[vecino] = nuevo_costo
				padre[vecino] = actual
				desempate += 1
				_meter(abiertos, [nuevo_costo + _heuristica(vecino, destino), desempate, vecino])
	return vacia


## Distancia de Chebyshev — admisible con 8 vecinos y costo uniforme 1
## por paso.
static func _heuristica(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Cola de prioridad: montículo binario de [f, orden_de_inserción,
## vértice] — mismo patrón que BuscadorRutas.gd (desempata por orden de
## inserción para que la búsqueda sea determinista).
static func _menor(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	return a[1] < b[1]


static func _meter(monticulo: Array, elemento: Array) -> void:
	monticulo.append(elemento)
	var i: int = monticulo.size() - 1
	while i > 0:
		var padre_i: int = (i - 1) >> 1
		if not _menor(monticulo[i], monticulo[padre_i]):
			break
		var t: Array = monticulo[i]
		monticulo[i] = monticulo[padre_i]
		monticulo[padre_i] = t
		i = padre_i


static func _sacar(monticulo: Array) -> Array:
	var cima: Array = monticulo[0]
	var ultimo: Array = monticulo.pop_back()
	if not monticulo.is_empty():
		monticulo[0] = ultimo
		var i := 0
		var n: int = monticulo.size()
		while true:
			var iz := 2 * i + 1
			var de := iz + 1
			var m := i
			if iz < n and _menor(monticulo[iz], monticulo[m]):
				m = iz
			if de < n and _menor(monticulo[de], monticulo[m]):
				m = de
			if m == i:
				break
			var t: Array = monticulo[i]
			monticulo[i] = monticulo[m]
			monticulo[m] = t
			i = m
	return cima
```

- [ ] **Step 4: Run test para confirmar que pasa**

Esperado: TEST 14-19 pasan.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/TrazadorVias.gd godot/scripts/ViasTest.gd
git commit -m "feat: TrazadorVias (A* sobre vértices, 8 direcciones)"
```

---

### Task 7: `ConstructorVias.gd` — construcción instantánea

**Files:**
- Create: `godot/scripts/ConstructorVias.gd`
- Modify: `godot/scripts/ViasTest.gd`

**Interfaces:**
- Consumes: `NiveladorVia.gd` (Task 2/3), `Vias.agregar()` (Task 1), `MundoFalsoVias` (Task 6, reusado).
- Produces: `ConstructorVias.construir(mundo: Object, vertices: Array[Vector2i], choca: Callable) -> bool` — `choca` es `Callable(columnas_absolutas: Array[Vector2i]) -> bool`, inyectada por el llamador (`CamaraCenital._huella_choca_con_otro_puesto`, ver Task 9) para no acoplar esta clase a `Recoleccion`/`Construccion`.

- [ ] **Step 1: Escribir los tests**

Agregar a `ejecutar_pruebas()`:

```gdscript
	print("\n=== TEST 20: ConstructorVias.construir() en terreno plano registra la vía ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_construir := MundoFalsoVias.new()
	var sin_choque := func(_c: Array) -> bool: return false
	var vertices_rectos: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert(ConstructorVias.construir(mundo_construir, vertices_rectos, sin_choque))
	# 3 vértices en línea recta: bloques (−1..0,−1..0), (0..1,−1..0), (1..2,−1..0)
	# se solapan de a 2 columnas -> 6 columnas de soporte distintas en total.
	var columnas_registradas: Dictionary = {}
	for celda in Vias.celdas:
		columnas_registradas[Vector2i(celda.x, celda.z)] = true
	assert(columnas_registradas.size() == 6)

	print("\n=== TEST 21: ConstructorVias.construir() rechaza si choca ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var con_choque := func(_c: Array) -> bool: return true
	assert(not ConstructorVias.construir(mundo_construir, vertices_rectos, con_choque))
	assert(Vias.celdas.is_empty())

	print("\n=== TEST 22: ConstructorVias.construir() con desnivel de 1 coloca una cuna_recta ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_escalon_construir := MundoFalsoVias.new()
	mundo_escalon_construir.escalon_en_x = 1
	mundo_escalon_construir.altura_escalon = 1
	var vertices_escalon: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	assert(ConstructorVias.construir(mundo_escalon_construir, vertices_escalon, sin_choque))
	var hay_cuna := false
	for celda in mundo_escalon_construir.celdas:
		if mundo_escalon_construir.celdas[celda] == "cuna_recta":
			hay_cuna = true
	assert(hay_cuna)

	print("\n=== TEST 23: ConstructorVias.construir() tala un árbol en el camino ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var mundo_arbol := MundoFalsoVias.new()
	mundo_arbol.celdas[Vector3i(0, 1, 0)] = "madera"  # dentro del bloque de vertice (0,0) o (1,0)
	assert(ConstructorVias.construir(mundo_arbol, [Vector2i(0, 0), Vector2i(1, 0)], sin_choque))
	assert(mundo_arbol.celdas.get(Vector3i(0, 1, 0), "") != "madera")

	print("\n=== TEST 24: ConstructorVias.construir() con menos de 2 vértices no hace nada ===")
	Vias.celdas.clear()
	assert(not ConstructorVias.construir(mundo_construir, [Vector2i(0, 0)], sin_choque))
	assert(Vias.celdas.is_empty())
	Vias.celdas.clear()
	Vias._columnas.clear()
```

- [ ] **Step 2: Run test para confirmar que falla**

Esperado: FALLA con "Invalid call. Nonexistent function 'construir'".

- [ ] **Step 3: Escribir `ConstructorVias.gd`**

```gdscript
extends RefCounted

## Construye instantáneamente los tramos de vía ya confirmados por el
## trazador (ver spec de vías Sección 5) — RefCounted puro, sin nodos,
## probado con un mundo falso (mismo patrón que NiveladorTerreno/
## Construccion). No decide el trazado (eso es TrazadorVias.gd) ni el
## modo de la cámara (CamaraCenital.gd): solo transforma una lista de
## vértices ya aceptada en cambios reales sobre "mundo" y en registros de
## Vias.gd.

const NiveladorVia = preload("res://scripts/NiveladorVia.gd")

const TIPO_VIA := "tierra_pisada"


## Intenta construir la vía que pasa por "vertices" (en orden, sin
## vértices consecutivos repetidos). "mundo" necesita altura_en(x,z),
## obtener_tipo(celda), colocar_bloque(celda,tipo,por_jugador),
## talar_bloque_de_arbol(celda,dano), eliminar_follaje(celda),
## set_cell_item(celda,id,orientacion) e id_de_tipo(tipo) — VoxelWorld
## real los tiene todos (id_de_tipo() nuevo, ver Task 5). "choca" es
## Callable(columnas_absolutas: Array[Vector2i]) -> bool, inyectada por
## el llamador (CamaraCenital._huella_choca_con_otro_puesto — ver spec
## Sección 6) para no acoplar esta clase a Recoleccion/Construccion.
## Devuelve false (nada se construye) si "vertices" tiene menos de 2
## elementos o si "choca" rechaza cualquier columna tocada.
static func construir(mundo: Object, vertices: Array[Vector2i], choca: Callable) -> bool:
	if vertices.size() < 2:
		return false

	var nivelador := NiveladorVia.new(mundo)
	var columnas_totales: Array[Vector2i] = []
	for v in vertices:
		for col in nivelador.bloque_de_vertice(v):
			if not columnas_totales.has(col):
				columnas_totales.append(col)

	if choca.call(columnas_totales):
		return false

	var objetivo_relleno: Dictionary = {}  # Vector2i -> int
	for v in vertices:
		var nivel: int = nivelador.nivel_de_bloque(v)
		for col in nivelador.bloque_de_vertice(v):
			objetivo_relleno[col] = maxi(objetivo_relleno.get(col, nivel), nivel)

	var cunas: Dictionary = {}  # Vector2i -> Dictionary
	for i in range(vertices.size() - 1):
		var plan: Dictionary = nivelador.plan_transicion(vertices[i], vertices[i + 1])
		if plan.is_empty():
			continue
		for col in plan["relleno_extra"]:
			objetivo_relleno[col] = maxi(objetivo_relleno.get(col, 0), plan["y_base"])
		var tipo_cuna: String = "cuna_esquina" if plan["diagonal"] else "cuna_recta"
		for col in plan["solape"]:
			cunas[col] = {"y": plan["y_base"], "tipo": tipo_cuna, "direccion_alta": plan["direccion_alta"]}
	for col in cunas:
		objetivo_relleno.erase(col)

	var celdas_soporte: Array[Vector3i] = []
	for col in objetivo_relleno:
		var y: int = objetivo_relleno[col]
		_nivelar_columna(mundo, col, y)
		celdas_soporte.append(Vector3i(col.x, y, col.y))
	for col in cunas:
		var datos: Dictionary = cunas[col]
		_nivelar_columna(mundo, col, datos["y"])
		var celda_cuna := Vector3i(col.x, datos["y"], col.y)
		mundo.set_cell_item(celda_cuna, mundo.id_de_tipo(datos["tipo"]), _orientacion(datos["direccion_alta"]))
		mundo.colocado_por_jugador[celda_cuna] = true
		celdas_soporte.append(celda_cuna)

	Vias.agregar(celdas_soporte, TIPO_VIA)
	return true


## Rellena "col" con "tierra" desde la superficie actual hasta
## "y_objetivo" (nunca cava). Cualquier árbol/follaje en el camino se
## tala primero (spec Sección 5): mundo.altura_en() ya ignora los
## árboles al calcular la superficie real, así que su tronco cae siempre
## DENTRO de este rango cuando hace falta relleno.
static func _nivelar_columna(mundo: Object, col: Vector2i, y_objetivo: int) -> void:
	var y_actual: int = mundo.altura_en(col.x, col.y)
	for y in range(y_actual + 1, y_objetivo + 1):
		var celda := Vector3i(col.x, y, col.y)
		var tipo: String = mundo.obtener_tipo(celda)
		if tipo == "madera":
			mundo.talar_bloque_de_arbol(celda, 999)
		elif tipo == "follaje":
			mundo.eliminar_follaje(celda)
		mundo.colocar_bloque(celda, "tierra", true)


## Índice de orientación de GridMap (0-23) para que el lado ALTO de una
## cuña quede orientado hacia "direccion_alta" (Vector2i en XZ) — las
## piezas se modelaron con su lado alto hacia +Z (ver Task 4), así que
## basta rotar alrededor de Y el ángulo entre esa referencia y
## "direccion_alta". ponytail: el signo de la rotación se fija
## visualmente en el editor real (Task 9); si sale espejado, invertir
## "-angulo" a "angulo" aquí es el único cambio necesario.
static func _orientacion(direccion_alta: Vector2i) -> int:
	var referencia := Vector2(0, 1)
	var angulo: float = referencia.angle_to(Vector2(direccion_alta.x, direccion_alta.y))
	return GridMap.get_orthogonal_index_from_basis(Basis(Vector3.UP, -angulo))
```

- [ ] **Step 4: Run test para confirmar que pasa**

Esperado: TEST 20-24 pasan.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ConstructorVias.gd godot/scripts/ViasTest.gd
git commit -m "feat: ConstructorVias.construir() (relleno, cuñas, tala y registro)"
```

---

### Task 8: trazador en `CamaraCenital.gd` — modo, entrada y vista previa

**Files:**
- Create: `godot/scripts/ViaPreviewOverlay.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scenes/Main.tscn`

**Interfaces:**
- Consumes: `TrazadorVias.gd` (Task 6).
- Produces: modo `modo_trazar_via` en `CamaraCenital.gd`, tecla `V`, flujo de clics descrito en la spec Sección 4.

Sin prueba GDScript (interacción de teclado/mouse, mismo criterio que el resto de `CamaraCenital.gd` — ninguno de sus modos tiene prueba unitaria). Verificación: carga headless sin error + prueba manual jugando.

- [ ] **Step 1: Escribir `ViaPreviewOverlay.gd`**

```gdscript
extends Node3D

## Vista previa del trazador de vías (tecla V en CamaraCenital.gd) — un
## plano por columna del bloque delimitador de los vértices en curso,
## coloreado válido/inválido. Mismo patrón que ZonaOverlay.gd, pero
## efímero: nunca escribe en Vias.gd, solo se usa mientras el jugador
## traza.

const COLOR_VALIDO := Color(1.0, 0.85, 0.0, 0.4)
const COLOR_INVALIDO := Color(1.0, 0.2, 0.2, 0.4)
const ALTURA_SOBRE_SUPERFICIE := 1.01
const DESF := 0.5

var mundo: Node

var _planos: Array[MeshInstance3D] = []


## "vertices" es el tramo en curso (origen + ruta hasta el cursor, sin
## deduplicar) — dibuja el rectángulo delimitador de cada paso consecutivo
## (más simple que el bloque 2x2 exacto de cada vértice, suficiente para
## la vista previa; la construcción real usa NiveladorVia.bloque_de_vertice()).
func previsualizar_tramo(vertices: Array[Vector2i], valido: bool) -> void:
	limpiar()
	if vertices.size() < 2:
		return
	var color: Color = COLOR_VALIDO if valido else COLOR_INVALIDO
	var columnas: Dictionary = {}  # Vector2i -> true, sin repetir plano
	for i in range(vertices.size() - 1):
		var a: Vector2i = vertices[i]
		var b: Vector2i = vertices[i + 1]
		for x in range(mini(a.x, b.x) - 1, maxi(a.x, b.x) + 1):
			for z in range(mini(a.y, b.y) - 1, maxi(a.y, b.y) + 1):
				columnas[Vector2i(x, z)] = true
	for col in columnas:
		_agregar_plano(col, color)


func limpiar() -> void:
	for plano in _planos:
		plano.queue_free()
	_planos.clear()


func _agregar_plano(col: Vector2i, color: Color) -> void:
	var altura_superficie: int = mundo.altura_en(col.x, col.y, true)
	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var plano := MeshInstance3D.new()
	plano.mesh = malla
	plano.material_override = material
	plano.position = Vector3(col.x + DESF, altura_superficie + ALTURA_SOBRE_SUPERFICIE, col.y + DESF)
	add_child(plano)
	_planos.append(plano)
```

- [ ] **Step 2: Agregar el nodo a `Main.tscn`**

```
[ext_resource type="Script" path="res://scripts/ViaPreviewOverlay.gd" id="12"]
```

Como hermano de `ZonaOverlay`:

```
[node name="ViaPreviewOverlay" type="Node3D" parent="."]
script = ExtResource("12")
```

- [ ] **Step 3: Estado y modo en `CamaraCenital.gd`**

Junto a `var modo_zonificar := false` (cerca de la línea 157):

```gdscript
var modo_trazar_via := false
var _hay_tramo_en_curso := false
var _vertice_inicio_tramo := Vector2i.ZERO
var _tramos_fijos: Array = []  # Array[Array[Vector2i]]
var _trazador_via: RefCounted = null
```

Junto a `const BlueprintValidator = ...` (cerca de la línea 5):

```gdscript
const TrazadorVias = preload("res://scripts/TrazadorVias.gd")
const ConstructorVias = preload("res://scripts/ConstructorVias.gd")
```

Junto a `@onready var overlay: Node3D = get_node("../ZonaOverlay")` (línea 151):

```gdscript
@onready var via_preview: Node3D = get_node("../ViaPreviewOverlay")
```

- [ ] **Step 4: Alternar el modo**

Junto a `_alternar_modo_zonificar()`/`_salir_de_modo_zonificar()` (cerca de la línea 1425):

```gdscript
## Activa/desactiva el modo trazador de vías (tecla `V`). Excluyente con
## los demás modos — ver spec de vías Sección 4.
func _alternar_modo_trazar_via() -> void:
	if modo_trazar_via:
		_salir_de_modo_trazar_via()
		return
	_salir_de_modo_colocar_blueprint()
	_salir_de_modo_colocar_puesto()
	_salir_de_modo_zonificar()
	hud.cerrar_panel_puesto()
	modo_trazar_via = true
	_trazador_via = TrazadorVias.new(mundo)
	_tramos_fijos.clear()
	_hay_tramo_en_curso = false


func _salir_de_modo_trazar_via() -> void:
	modo_trazar_via = false
	_hay_tramo_en_curso = false
	_tramos_fijos.clear()
	via_preview.limpiar()
```

En `salir_de_todos_los_modos()` (línea 1316), agregar la llamada:

```gdscript
	_salir_de_modo_trazar_via()
```

- [ ] **Step 5: Entrada de teclado y mouse**

En `_unhandled_input()` (cerca de la línea 1097), junto a las demás teclas:

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_V:
			_alternar_modo_trazar_via()
```

En la cadena de clic izquierdo (cerca de la línea 1126):

```gdscript
			elif modo_trazar_via:
				_procesar_clic_via(boton.position)
```

En el clic derecho (cerca de la línea 1135, junto a `_cancelar_pintado_zona()`):

```gdscript
			if modo_trazar_via:
				_cancelar_tramo_via()
```

(Nota para quien implemente: revisar si el `elif` de clic derecho actual necesita convertirse en una cadena `if`/`elif` según lo que ya haya ahí — mantener el resto de ramas intactas.)

- [ ] **Step 6: Vértice bajo el mouse**

Junto a `_celda_bajo_mouse()` (línea 1400):

```gdscript
## Igual que _celda_bajo_mouse() pero redondea al VÉRTICE (esquina entre
## 4 celdas) más cercano en vez de a la celda — ver spec de vías Sección
## 1/4. Sin el desplazamiento "hacia adentro de la cara" que usa
## _celda_bajo_mouse(): aquí interesa el punto de impacto real.
func _vertice_bajo_mouse(posicion_pantalla: Vector2) -> Vector2i:
	var origen := project_ray_origin(posicion_pantalla)
	var direccion := project_ray_normal(posicion_pantalla)
	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * ALCANCE_RAYCAST)
	consulta.collision_mask = MASCARA_MUNDO
	var resultado: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	var punto: Vector3
	if resultado.is_empty():
		var distancia: float = -origen.y / direccion.y
		punto = origen + direccion * distancia
	else:
		punto = resultado["position"]
	var local: Vector3 = mundo.to_local(punto)
	return Vector2i(roundi(local.x), roundi(local.z))
```

- [ ] **Step 7: Flujo de clics**

```gdscript
## Clic con el modo trazador activo — ver spec de vías Sección 4.
func _procesar_clic_via(posicion_pantalla: Vector2) -> void:
	var vertice := _vertice_bajo_mouse(posicion_pantalla)
	if not _hay_tramo_en_curso:
		_vertice_inicio_tramo = vertice
		_hay_tramo_en_curso = true
		return

	if vertice == _vertice_inicio_tramo:
		_cancelar_tramo_via()
		return

	var ruta: Array[Vector2i] = _trazador_via.buscar_ruta(_vertice_inicio_tramo, vertice)
	if ruta.is_empty():
		print("Trazado rechazado: no hay ruta posible hasta ese punto.")
		return

	var tramo: Array[Vector2i] = [_vertice_inicio_tramo]
	tramo.append_array(ruta)
	_tramos_fijos.append(tramo)

	if _vertice_pertenece_a_via(vertice):
		_confirmar_trazo_via()
		_hay_tramo_en_curso = false
		_tramos_fijos.clear()
		via_preview.limpiar()
		return

	_vertice_inicio_tramo = vertice


func _cancelar_tramo_via() -> void:
	if not _hay_tramo_en_curso:
		return
	_hay_tramo_en_curso = false
	via_preview.limpiar()
	print("Trazado de vía cancelado.")


## true si CUALQUIER columna del bloque de soporte de "vertice" ya tiene
## una vía registrada — usado para saber si el clic cierra el trazo como
## intersección (ver spec de vías Sección 4).
func _vertice_pertenece_a_via(vertice: Vector2i) -> bool:
	for col in _trazador_via.bloque_de_vertice(vertice):
		var y: int = mundo.altura_en(col.x, col.y)
		if Vias.es_via(Vector3i(col.x, y, col.y)):
			return true
	return false
```

- [ ] **Step 8: Vista previa en `_process()`**

En `_process()` (línea 506-513), agregar una rama antes del `return`:

```gdscript
		if modo_colocar_blueprint:
			_actualizar_previsualizacion_blueprint()
		elif modo_colocar_puesto:
			_actualizar_previsualizacion_puesto()
		elif esperando_segunda_esquina:
			_actualizar_previsualizacion_zona()
		elif modo_trazar_via and _hay_tramo_en_curso:
			_actualizar_preview_via()
		return
```

Y el método:

```gdscript
func _actualizar_preview_via() -> void:
	var vertice := _vertice_bajo_mouse(get_viewport().get_mouse_position())
	var ruta: Array[Vector2i] = _trazador_via.buscar_ruta(_vertice_inicio_tramo, vertice)
	var tramo: Array[Vector2i] = [_vertice_inicio_tramo]
	tramo.append_array(ruta)
	via_preview.previsualizar_tramo(tramo, not ruta.is_empty())
```

- [ ] **Step 9: Placeholder de `_confirmar_trazo_via()`**

Por ahora (se completa en Task 9, que necesita el choque inverso ya en su lugar):

```gdscript
func _confirmar_trazo_via() -> void:
	pass  # completado en Task 9
```

- [ ] **Step 10: Verificar headless**

Run `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"`, `get_debug_output`, `stop_project`. Esperado: sin errores nuevos al cargar (headless no puede enviar teclado/mouse — la interacción real se prueba jugando).

- [ ] **Step 11: Commit**

```bash
git add godot/scripts/ViaPreviewOverlay.gd godot/scripts/CamaraCenital.gd godot/scenes/Main.tscn
git commit -m "feat: modo trazador de vías (tecla V) en CamaraCenital"
```

---

### Task 9: confirmación y choque en ambos sentidos

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes: `ConstructorVias.construir()` (Task 7), `Vias.hay_via_en_columna()` (Task 1), `_huella_choca_con_otro_puesto()` (ya existente, línea 779), `_columnas_relativas()` (ya existente en este archivo — confirmar su firma exacta antes de usarla).

- [ ] **Step 1: Completar `_confirmar_trazo_via()`**

Reemplazar el placeholder del Task 8, Step 9:

```gdscript
## Confirma TODOS los tramos acumulados (_tramos_fijos) de una sola vez —
## ver spec de vías Sección 5. Deduplica vértices consecutivos repetidos
## (el punto de cierre de un tramo es también el inicio del siguiente).
func _confirmar_trazo_via() -> void:
	var vertices: Array[Vector2i] = []
	for tramo in _tramos_fijos:
		for v in tramo:
			if vertices.is_empty() or vertices[-1] != v:
				vertices.append(v)

	var choca := func(columnas_abs: Array[Vector2i]) -> bool:
		if columnas_abs.is_empty():
			return false
		var esquina: Vector2i = columnas_abs[0]
		return _huella_choca_con_otro_puesto(esquina, _columnas_relativas(esquina, columnas_abs))

	if not ConstructorVias.construir(mundo, vertices, choca):
		print("Trazado rechazado: choca con un edificio, puesto u obra existente.")
```

- [ ] **Step 2: Choque inverso — edificio/puesto sobre una vía existente**

En `_huella_choca_con_otro_puesto()` (línea 779), agregar la comprobación:

```gdscript
func _huella_choca_con_otro_puesto(esquina: Vector2i, columnas: Array[Vector2i]) -> bool:
	for rel in columnas:
		var xz := Vector2i(esquina.x + rel.x, esquina.y + rel.y)
		if Recoleccion.celda_dentro_de_algun_puesto(xz):
			return true
		if Vias.hay_via_en_columna(xz):
			return true
		var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
		if mundo.id_de_edificio(celda_superficie) != -1 or Construccion.construccion_de(celda_superficie) != -1:
			return true
	return false
```

- [ ] **Step 3: Verificar headless**

Run `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"` y con `scene: "res://scenes/ViasTest.tscn"` (el Task 7 ya cubre `ConstructorVias` con un `choca` inyectado, así que esta tarea no agrega pruebas nuevas — solo conecta piezas ya probadas). Confirmar sin errores nuevos en ambas.

- [ ] **Step 4: Prueba manual (anotar en el mensaje de commit o al reportar la tarea)**

Jugando en el editor real: trazar una vía con `V` sobre terreno libre y confirmar que aparece; intentar colocar un puesto (`M`/`H`/`L`/`F`) sobre esa vía y confirmar que se rechaza; trazar una vía que cruce la huella de un edificio ya declarado y confirmar que se rechaza sin tocar el terreno.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: confirmación del trazador de vías y choque en ambos sentidos"
```

---

### Task 10: bono de velocidad

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/Player.gd`
- Modify: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- Consumes: `Vias.bono_en(soporte: Vector3i) -> float` (Task 1).

- [ ] **Step 1: Escribir el test en `ColonosTest.gd`**

Agregar una prueba (junto a las demás `assert()` de ese archivo — revisar el patrón exacto de instanciación de `Colonos`/`MundoFalso`/avance de tiempo ya usado ahí antes de escribir esta prueba, para que encaje con el resto del archivo):

```gdscript
	print("=== TEST bono de velocidad: un colono sobre una vía avanza más rápido ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	# (instanciar un Colonos real + MundoFalso con una celda de piso en
	# (0,0,0) y otra en (1,0,0), agregar un colono parado en (0,1,0) con
	# una ruta de 1 paso hacia (1,1,0), avanzar 1 segundo SIN vía y anotar
	# c["progreso"]; repetir el mismo escenario con
	# Vias.agregar([Vector3i(0,0,0)], "tierra_pisada") antes de avanzar, y
	# comprobar que el progreso con vía es 1.35x el progreso sin vía)
	Vias.celdas.clear()
	Vias._columnas.clear()
```

(Nota para quien implemente: completar el cuerpo exacto de la prueba siguiendo el patrón real de `ColonosTest.gd` — instanciación de `ColonosScript.new()`, cómo se agrega un colono con una ruta ya fijada, y cómo se llama a `avanzar(delta)`. El comentario de arriba describe el escenario; el código debe seguir la convención ya usada por las pruebas vecinas en ese mismo archivo.)

- [ ] **Step 2: Run test para confirmar que falla**

Esperado: el progreso con y sin vía es idéntico (el bono todavía no se aplica).

- [ ] **Step 3: Aplicar el bono en `Colonos.gd`**

En `_completar_paso()` (línea 237-250), cambiar:

```gdscript
	c["progreso"] += delta * VELOCIDAD_COLONO
```

por:

```gdscript
	var soporte: Vector3i = c["celda"] + Vector3i(0, -1, 0)
	c["progreso"] += delta * VELOCIDAD_COLONO * Vias.bono_en(soporte)
```

- [ ] **Step 4: Run test para confirmar que pasa**

Esperado: el progreso con vía es 1.35x el progreso sin vía.

- [ ] **Step 5: Aplicar el bono en `Player.gd`**

En `_physics_process()` (cerca de la línea 187-188), antes de fijar `velocity.x/z`:

```gdscript
	var bono := 1.0
	if mundo != null:
		var celda_pies: Vector3i = _celda_en(global_position)
		bono = Vias.bono_en(celda_pies - Vector3i(0, 1, 0))
	velocity.x = direccion.x * VELOCIDAD * bono
	velocity.z = direccion.z * VELOCIDAD * bono
```

(Nota para quien implemente: `_celda_en(global_position)` ya se calcula como `celda_pies` unas líneas arriba en la función real, cerca de la línea 190 — reusar esa variable existente en vez de llamarla dos veces, si el orden del código lo permite.)

- [ ] **Step 6: Verificar headless**

Run `ColonosTest.tscn` (TEST del bono pasa), `Test.tscn`, `PlayerNatacionTest.tscn`, `PlayerOxigenoTest.tscn` (sin errores nuevos — el bono no debe afectar natación/oxígeno).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/Player.gd godot/scripts/ColonosTest.gd
git commit -m "feat: bono de velocidad de Colonos/Player sobre vías"
```

---

### Task 11: verificación final y documentación

**Files:**
- Modify: `docs/Pendientes y próximos pasos.md`

- [ ] **Step 1: Correr toda la verificación afectada**

Vía `mcp__godot__run_project`/`get_debug_output`/`stop_project` (o el binario real si el MCP falla, ver memoria de sesión sobre `stop_project` poco confiable — confirmar con `Get-Process` que no queden procesos huérfanos):

- `Test.tscn`
- `ViasTest.tscn`
- `ColonosTest.tscn`
- `NiveladorTerrenoTest.tscn`
- `PlayerNatacionTest.tscn`
- `PlayerOxigenoTest.tscn`
- `Main.tscn` (solo carga, sin errores nuevos)

Esperado: todas las aserciones pasan, sin errores nuevos en `Main.tscn`.

- [ ] **Step 2: Actualizar `docs/Pendientes y próximos pasos.md`**

Tachar la línea 43 (mismo formato `~~texto~~` que las demás entradas resueltas de ese archivo):

```
~~1\. Vías de "tierra pisada" y carretas (sub-proyecto 6).~~
```

y agregar debajo, antes del punto 2 actual, una nota breve:

```

Implementado (2026-09-22): trazador de vías de tierra pisada en la cámara
cenital (tecla `V`), overlay 2x2, cuñas para desnivel de 1 y relleno para
2-3, bono de velocidad +35% para colonos y avatar — ver
`docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md`. Las
carretas quedan pendientes (dependen de vehículos/unidades, fuera de
alcance de esta pieza).

```

- [ ] **Step 3: Commit**

```bash
git add "docs/Pendientes y próximos pasos.md"
git commit -m "docs: marcar vías de tierra pisada como implementadas"
```

---

## Self-Review

**Cobertura del spec:** Sección 1 (modelo de datos) → Task 1. Sección 2 (relleno/cuñas) → Task 2/3. Sección 3 (piezas + overlay) → Task 4/5. Sección 4 (trazador) → Task 8. Sección 5 (confirmación/construcción) → Task 7/9. Sección 6 (choque inverso) → Task 9. Sección 7 (bono) → Task 10. Sección 8 (fuera de alcance) → ningún task lo implementa, correcto. Sección 9 (verificación) → Task 11.

**Placeholders:** los Steps de Task 8 (líneas de `_unhandled_input`/clic derecho) y Task 10 (test de `ColonosTest.gd`, ajuste de `Player._physics_process()`) llevan una nota explícita para quien implemente porque dependen de leer el código real vecino en el momento de escribir (la estructura exacta de la cadena `if/elif` ya existente, o el patrón de instanciación de pruebas ya en el archivo) — no son placeholders de lo que hay que construir, sino un puntero a verificar contra el archivo real antes de pegar el fragmento, ya que ese archivo puede haber cambiado entre esta escritura y la implementación.

**Consistencia de tipos:** `Vector2i` para columnas/vértices en todo el plan; `Vector3i` para celdas 3D de soporte; `plan_transicion()`/`ConstructorVias.construir()` usan las mismas claves de `Dictionary` (`"solape"`, `"y_base"`, `"diagonal"`, `"direccion_alta"`, `"relleno_extra"`) en Task 3 y Task 7.
