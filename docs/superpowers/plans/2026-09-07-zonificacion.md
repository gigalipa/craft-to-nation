# Zonificación Pintada sobre el Grid — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar la validación de zona que ya existe en `BlueprintValidator.gd` a un sistema real de zonas pintables sobre el grid (Núcleo A/Núcleo B), con una "zona de influencia" que nace del primer edificio residencial declarado y una cámara cenital mínima para pintar.

**Architecture:** Un nuevo autoload `Zonificacion.gd` (mismo patrón que `Ciudad.gd`) guarda el estado puro (zona de influencia + celdas pintadas) y no depende de ningún nodo de escena. `Player.gd` lo consulta al declarar un edificio. Una cámara cenital mínima (`CamaraCenital.gd`, nuevo `Camera3D` en `Main.tscn`) y un overlay visual (`ZonaOverlay.gd`) permiten pintar y ver las zonas, alternando con la cámara en 1ª persona mediante una tecla de toggle en `Main.gd`.

**Tech Stack:** Godot Engine 4.7 (GDScript), proyecto compartido `godot/`.

**Spec:** `docs/superpowers/specs/2026-09-07-zonificacion-design.md`

## Global Constraints

- Usar tabulaciones (tabs) en todo GDScript, no espacios (regla del repo, ver `CLAUDE.md`).
- Mantener el español en comentarios, mensajes impresos y nombres de pruebas (regla del repo).
- `Vector2i` no tiene componente `.z` — la convención ya usada en `BlueprintValidator.gd` (`_parsear_celda`) es `Vector2i(x, z)`, guardando la coordenada mundial Z en el campo `.y` de `Vector2i`. Seguir esa misma convención en todo este plan.
- No declarar `class_name` en `Zonificacion.gd` (colisionaría con el nombre del autoload — mismo motivo documentado en `Ciudad.gd`).
- Verificación de cada tarea: `mcp__godot__run_project` + `mcp__godot__get_debug_output` contra la escena relevante, confirmando que no hay `errors` nuevos (las dos advertencias `SHADOWED_GLOBAL_IDENTIFIER` de `Player.gd`/`Main.gd` ya son conocidas y se pueden ignorar). No hacer `git commit` en ningún paso — dejar los cambios listos para que el usuario los revise y pida el commit explícitamente (regla general de esta sesión, no del proyecto).

---

### Task 1: Autoload `Zonificacion.gd` — estado puro y lógica de zonas

**Files:**
- Create: `godot/scripts/Zonificacion.gd`
- Create: `godot/scripts/ZonificacionTest.gd`
- Create: `godot/scenes/ZonificacionTest.tscn`
- Modify: `godot/project.godot` (sección `[autoload]`)

**Interfaces:**
- Produces (consumido por las Tareas 2 y 3):
  - `Zonificacion.MARGEN_ZONA_INFLUENCIA: int` (constante, `15`)
  - `Zonificacion.ZONAS_PINTABLES: Array` (constante, `["residencial_investigacion", "fabricacion_militar"]`)
  - `Zonificacion.nucleo_declarado: bool`
  - `Zonificacion.influencia_min: Vector2i`, `Zonificacion.influencia_max: Vector2i`
  - `Zonificacion.zonas: Dictionary` (`Vector2i -> String`)
  - `func declarar_nucleo(huella: Array) -> void` — `huella` es un `Array` de `Vector2i(x, z)`.
  - `func dentro_de_influencia(celda: Vector2i) -> bool`
  - `func pintar_zona(esquina_a: Vector2i, esquina_b: Vector2i, tipo: String) -> int`
  - `func consultar_zona(celda: Vector2i) -> String`

- [ ] **Step 1: Crear `Zonificacion.gd`**

```gdscript
extends Node

## Autoload "Zonificacion": estado puro y lógica de la zona de influencia y
## las zonas pintables (Núcleo A/Núcleo B) sobre el grid XZ. Sin class_name
## (colisionaría con el nombre del autoload, mismo motivo que Ciudad.gd). No
## depende de ningún nodo de escena — ver spec:
## docs/superpowers/specs/2026-09-07-zonificacion-design.md
##
## Convención: Vector2i(x, z) para celdas del grid en planta — Vector2i no
## tiene componente .z, así que la coordenada mundial Z vive en el campo .y
## (misma convención que BlueprintValidator._parsear_celda).

const MARGEN_ZONA_INFLUENCIA := 15
const ZONAS_PINTABLES := ["residencial_investigacion", "fabricacion_militar"]

var nucleo_declarado := false
var influencia_min := Vector2i.ZERO
var influencia_max := Vector2i.ZERO
var zonas: Dictionary = {}  # Vector2i(x,z) -> String


## Bootstrap del núcleo urbano: se llama una sola vez, cuando se declara el
## primer edificio residencial válido (ver Player.gd::_declarar_edificio).
## Llamadas repetidas se ignoran — el núcleo urbano no se puede redeclarar.
func declarar_nucleo(huella: Array) -> void:
	if nucleo_declarado:
		return

	var x_min: int = huella[0].x
	var x_max: int = huella[0].x
	var z_min: int = huella[0].y
	var z_max: int = huella[0].y
	for celda in huella:
		x_min = min(x_min, celda.x)
		x_max = max(x_max, celda.x)
		z_min = min(z_min, celda.y)
		z_max = max(z_max, celda.y)

	influencia_min = Vector2i(x_min - MARGEN_ZONA_INFLUENCIA, z_min - MARGEN_ZONA_INFLUENCIA)
	influencia_max = Vector2i(x_max + MARGEN_ZONA_INFLUENCIA, z_max + MARGEN_ZONA_INFLUENCIA)
	nucleo_declarado = true

	for celda in huella:
		zonas[celda] = "residencial_investigacion"


func dentro_de_influencia(celda: Vector2i) -> bool:
	if not nucleo_declarado:
		return false
	return (
		celda.x >= influencia_min.x and celda.x <= influencia_max.x
		and celda.y >= influencia_min.y and celda.y <= influencia_max.y
	)


## Pinta el rectángulo entre las dos esquinas (inclusive), recortado a la
## zona de influencia. Devuelve cuántas celdas se pintaron realmente, para
## que quien llama (CamaraCenital.gd) pueda avisar si el rectángulo cayó
## total o parcialmente fuera de la zona de influencia.
func pintar_zona(esquina_a: Vector2i, esquina_b: Vector2i, tipo: String) -> int:
	if not ZONAS_PINTABLES.has(tipo):
		return 0

	var x_min: int = min(esquina_a.x, esquina_b.x)
	var x_max: int = max(esquina_a.x, esquina_b.x)
	var z_min: int = min(esquina_a.y, esquina_b.y)
	var z_max: int = max(esquina_a.y, esquina_b.y)

	var pintadas := 0
	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			var celda := Vector2i(x, z)
			if dentro_de_influencia(celda):
				zonas[celda] = tipo
				pintadas += 1
	return pintadas


func consultar_zona(celda: Vector2i) -> String:
	return zonas.get(celda, "periferia")
```

- [ ] **Step 2: Registrar el autoload en `project.godot`**

En `godot/project.godot`, dentro de la sección `[autoload]` (que ya existe con `Ciudad`), agregar una segunda línea:

```
[autoload]

Ciudad="*res://scripts/Ciudad.gd"
Zonificacion="*res://scripts/Zonificacion.gd"
```

- [ ] **Step 3: Crear `ZonificacionTest.gd`**

```gdscript
extends Node

## Pruebas aisladas de Zonificacion.gd (mismo patrón que CiudadTest.gd).
## Corre esta escena (ZonificacionTest.tscn) con F6 en el editor de Godot y
## revisa el panel "Output": debe imprimir las 8 pruebas y no debe lanzar
## ningún error de assert(). No usa el autoload "Zonificacion" — instancia
## una Zonificacion nueva vía preload, para poder correr las pruebas de
## forma aislada y repetible (igual que CiudadTest.gd con Ciudad).

const ZonificacionScript = preload("res://scripts/Zonificacion.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Sin núcleo declarado, todo fuera de influencia ===")
	var zona: Node = ZonificacionScript.new()
	assert(not zona.dentro_de_influencia(Vector2i(0, 0)))
	assert(zona.pintar_zona(Vector2i(-5, -5), Vector2i(5, 5), "residencial_investigacion") == 0)

	print("\n=== TEST 2: declarar_nucleo() con huella no cuadrada (10x7) ===")
	var huella: Array = []
	for x in range(0, 10):
		for z in range(0, 7):
			huella.append(Vector2i(x, z))
	zona.declarar_nucleo(huella)
	assert(zona.nucleo_declarado)
	print("Influencia: ", zona.influencia_min, " a ", zona.influencia_max)
	assert(zona.influencia_min == Vector2i(-15, -15))
	assert(zona.influencia_max == Vector2i(24, 21))
	assert(zona.consultar_zona(Vector2i(0, 0)) == "residencial_investigacion")
	assert(zona.consultar_zona(Vector2i(9, 6)) == "residencial_investigacion")

	print("\n=== TEST 3: dentro_de_influencia() en el borde del margen ===")
	assert(zona.dentro_de_influencia(Vector2i(-15, -15)))
	assert(zona.dentro_de_influencia(Vector2i(24, 21)))
	assert(not zona.dentro_de_influencia(Vector2i(-16, -15)))
	assert(not zona.dentro_de_influencia(Vector2i(25, 21)))

	print("\n=== TEST 4: pintar_zona() con ambas esquinas dentro ===")
	var pintadas: int = zona.pintar_zona(Vector2i(-10, -10), Vector2i(-5, -5), "fabricacion_militar")
	print("Celdas pintadas: ", pintadas)
	assert(pintadas == 36)
	assert(zona.consultar_zona(Vector2i(-10, -10)) == "fabricacion_militar")
	assert(zona.consultar_zona(Vector2i(-5, -5)) == "fabricacion_militar")
	assert(zona.consultar_zona(Vector2i(-7, -7)) == "fabricacion_militar")

	print("\n=== TEST 5: pintar_zona() recortado a la influencia ===")
	var pintadas_recorte: int = zona.pintar_zona(Vector2i(20, 15), Vector2i(30, 25), "residencial_investigacion")
	print("Celdas pintadas (rectángulo parcialmente fuera): ", pintadas_recorte)
	assert(pintadas_recorte == 35)  # x: 20..24 (5) * z: 15..21 (7)

	print("\n=== TEST 6: pintar_zona() con tipo inválido ===")
	assert(zona.pintar_zona(Vector2i(0, 0), Vector2i(1, 1), "periferia") == 0)
	assert(zona.pintar_zona(Vector2i(0, 0), Vector2i(1, 1), "zona_inexistente") == 0)

	print("\n=== TEST 7: consultar_zona() de celda nunca pintada ===")
	assert(zona.consultar_zona(Vector2i(100, 100)) == "periferia")

	print("\n=== TEST 8: declarar_nucleo() llamado dos veces ===")
	var influencia_min_original: Vector2i = zona.influencia_min
	var huella_2: Array = [Vector2i(50, 50)]
	zona.declarar_nucleo(huella_2)
	assert(zona.influencia_min == influencia_min_original)
	assert(zona.consultar_zona(Vector2i(50, 50)) == "periferia")

	print("\n=== Las 8 pruebas de Zonificacion pasaron correctamente ===")
```

- [ ] **Step 4: Crear `ZonificacionTest.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ZonificacionTest.gd" id="1"]

[node name="ZonificacionTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 5: Correr las pruebas vía Godot MCP**

Run: `mcp__godot__run_project` con `projectPath: "C:\Users\peraz\Projects\Misc\CityCraft\godot"` y `scene: "res://scenes/ZonificacionTest.tscn"`, luego `mcp__godot__get_debug_output`.
Expected: el panel de salida imprime los 8 tests y termina con "Las 8 pruebas de Zonificacion pasaron correctamente", `errors` vacío (sin ningún `assert()` fallido). Luego `mcp__godot__stop_project`.

---

### Task 2: `Player.gd` — bootstrap del núcleo y validación de zona real

**Files:**
- Modify: `godot/scripts/Player.gd` (función `_declarar_edificio()`)

**Interfaces:**
- Consumes (de la Tarea 1): `Zonificacion.nucleo_declarado`, `Zonificacion.declarar_nucleo(huella: Array)`, `Zonificacion.consultar_zona(celda: Vector2i) -> String`.
- Consumes (ya existente): `BlueprintValidator.validar_blueprint(blueprint: Dictionary, zona_destino: String = "") -> Dictionary`.
- Produces: ningún símbolo nuevo consumido por otras tareas — este cambio es hoja del árbol de dependencias.

- [ ] **Step 1: Reescribir `_declarar_edificio()` en `Player.gd`**

Reemplazar el cuerpo completo de la función (justo después de `var blueprint := BlueprintValidator.estructura_a_blueprint(celdas)`) por:

```gdscript
func _declarar_edificio() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	var tipo_apuntado: String = mundo.obtener_tipo(celda)
	if tipo_apuntado != "puerta_inferior" and tipo_apuntado != "puerta_superior":
		print("Declarar edificio: apunta a la puerta principal de la estructura.")
		return
	var celdas: Dictionary = mundo.detectar_estructura(celda)
	if celdas.is_empty():
		print("Declarar edificio: esa puerta no fue colocada por el jugador.")
		return
	var blueprint := BlueprintValidator.estructura_a_blueprint(celdas)

	# Huella en planta (X,Z) del edificio, sin repetir celdas — usada tanto
	# para el bootstrap del núcleo urbano como, más adelante, para pintarla
	# como Núcleo A. "celda" es la puerta apuntada, la misma referencia que
	# ya usa detectar_estructura() para "dónde está" el edificio.
	var celda_puerta_xz := Vector2i(celda.x, celda.z)
	var huella: Array = []
	var huella_vista: Dictionary = {}  # Vector2i -> true, para no repetir celdas
	for pos in celdas.keys():
		var punto_xz := Vector2i(pos.x, pos.z)
		if not huella_vista.has(punto_xz):
			huella_vista[punto_xz] = true
			huella.append(punto_xz)

	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino)

	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if resultado["valido"]:
		var total_camas := 0
		for piso in blueprint["pisos"]:
			total_camas += (piso.get("camas", []) as Array).size()
		Ciudad.registrar_edificio_residencial(total_camas)
		print("Camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

		if not Zonificacion.nucleo_declarado:
			Zonificacion.declarar_nucleo(huella)
			print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
```

- [ ] **Step 2: Verificar que `Main.tscn` sigue cargando sin errores nuevos**

Run: `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"`, luego `mcp__godot__get_debug_output`.
Expected: mismas dos advertencias `SHADOWED_GLOBAL_IDENTIFIER` ya conocidas (`Player.gd`/`Main.gd`), sin errores nuevos. `mcp__godot__stop_project` después.

Nota: `_declarar_edificio()` no tiene pruebas automatizadas (depende de `RayCast3D`/`GridMap` en vivo, igual que el resto de `Player.gd` desde PoC_3) — la verificación de comportamiento real (bootstrap, bloqueo por zona) es manual, jugando la escena. Dejar esto anotado para el usuario en el documento técnico de PoC_4 (Tarea 4).

---

### Task 3: Cámara cenital mínima + overlay visual de zonas

**Files:**
- Create: `godot/scripts/CamaraCenital.gd`
- Create: `godot/scripts/ZonaOverlay.gd`
- Modify: `godot/scenes/Main.tscn` (agregar nodos `CamaraCenital` y `ZonaOverlay`)
- Modify: `godot/scripts/Main.gd` (toggle de cámara con tecla `C`)
- Modify: `godot/scripts/Player.gd` (ignorar input propio cuando su cámara no está activa)

**Interfaces:**
- Consumes (de la Tarea 1): `Zonificacion.nucleo_declarado`, `Zonificacion.influencia_min`, `Zonificacion.influencia_max`, `Zonificacion.ZONAS_PINTABLES`, `Zonificacion.zonas`, `Zonificacion.pintar_zona(...)`.
- Consumes (ya existente): `VoxelWorld.local_to_map(pos: Vector3) -> Vector3i`, `Node3D.to_local(pos: Vector3) -> Vector3` (heredado de `GridMap`).
- Produces: `CamaraCenital.posicionar_sobre_influencia() -> void` (usado por `Main.gd`), nodo único `ZonaOverlay` con método `reconstruir() -> void` (usado por `CamaraCenital.gd`).

- [ ] **Step 1: Crear `ZonaOverlay.gd`**

```gdscript
extends Node3D

## Overlay visual de las zonas pintadas (ver Zonificacion.gd, autoload). Un
## plano semitransparente por celda pintada, reconstruido por completo cada
## vez que cambia algo — la zona de influencia está acotada (a lo sumo unos
## cientos de celdas), así que reconstruir todo es más simple que llevar un
## registro incremental de qué celdas ya tienen su plano.

const COLOR_POR_ZONA := {
	"residencial_investigacion": Color(0.2, 0.4, 1.0, 0.4),
	"fabricacion_militar": Color(1.0, 0.5, 0.1, 0.4),
}


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()

	for celda in Zonificacion.zonas:
		var tipo: String = Zonificacion.zonas[celda]
		var color: Color = COLOR_POR_ZONA.get(tipo, Color.WHITE)

		var malla := PlaneMesh.new()
		malla.size = Vector2(1.0, 1.0)

		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.position = Vector3(celda.x, 0.05, celda.y)
		add_child(plano)
```

- [ ] **Step 2: Crear `CamaraCenital.gd`**

```gdscript
extends Camera3D

## Cámara cenital mínima para pintar zonas (ver spec:
## docs/superpowers/specs/2026-09-07-zonificacion-design.md). Sin
## paneo/zoom ni selección de tropas — eso es PoC 5 completo (Fase 3), esta
## versión solo existe para poder pintar zonas desde arriba.

@onready var mundo: Node = get_node("../VoxelWorld")
@onready var overlay: Node3D = get_node("../ZonaOverlay")

var tipo_zona_seleccionada: String = Zonificacion.ZONAS_PINTABLES[0]
var esperando_segunda_esquina := false
var primera_esquina := Vector2i.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 40.0
	rotation_degrees = Vector3(-90, 0, 0)


## Centra la cámara sobre la zona de influencia (o el origen, si todavía no
## existe núcleo urbano declarado). Llamada por Main.gd al activar la
## cámara cenital.
func posicionar_sobre_influencia() -> void:
	var centro: Vector2i
	if Zonificacion.nucleo_declarado:
		centro = (Zonificacion.influencia_min + Zonificacion.influencia_max) / 2
	else:
		centro = Vector2i.ZERO
	global_position = Vector3(centro.x, 20.0, centro.y)


func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return

	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_1:
			tipo_zona_seleccionada = Zonificacion.ZONAS_PINTABLES[0]
			print("Zona seleccionada: ", tipo_zona_seleccionada)
		elif tecla.pressed and tecla.keycode == KEY_2:
			tipo_zona_seleccionada = Zonificacion.ZONAS_PINTABLES[1]
			print("Zona seleccionada: ", tipo_zona_seleccionada)

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			_procesar_clic(boton.position)


## Convierte una posición de pantalla en la celda de grid (X,Z) que hay
## debajo, intersecando el rayo de la cámara con el plano y = 0.
func _celda_bajo_mouse(posicion_pantalla: Vector2) -> Vector2i:
	var origen := project_ray_origin(posicion_pantalla)
	var direccion := project_ray_normal(posicion_pantalla)
	var distancia: float = -origen.y / direccion.y
	var punto: Vector3 = origen + direccion * distancia
	var celda: Vector3i = mundo.local_to_map(mundo.to_local(punto))
	return Vector2i(celda.x, celda.z)


func _procesar_clic(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if not esperando_segunda_esquina:
		primera_esquina = celda
		esperando_segunda_esquina = true
		print("Primera esquina de la zona: ", primera_esquina)
		return

	var pintadas: int = Zonificacion.pintar_zona(primera_esquina, celda, tipo_zona_seleccionada)
	print("Zona '", tipo_zona_seleccionada, "' pintada en ", pintadas, " celda(s).")
	if pintadas == 0 and not Zonificacion.nucleo_declarado:
		print("Todavía no existe una zona de influencia — declara tu primer edificio residencial primero.")
	esperando_segunda_esquina = false
	overlay.reconstruir()
```

- [ ] **Step 3: Agregar los nodos a `Main.tscn`**

Editar `godot/scenes/Main.tscn`: agregar dos `ext_resource` nuevos (subir `load_steps` de 6 a 8) y dos nodos nuevos, hijos de `Main`:

```
[ext_resource type="Script" path="res://scripts/CamaraCenital.gd" id="6"]
[ext_resource type="Script" path="res://scripts/ZonaOverlay.gd" id="7"]
```

```
[node name="CamaraCenital" type="Camera3D" parent="."]
current = false
script = ExtResource("6")

[node name="ZonaOverlay" type="Node3D" parent="."]
visible = false
script = ExtResource("7")
```

- [ ] **Step 4: Agregar el toggle de cámara en `Main.gd`**

Reemplazar el contenido completo de `Main.gd` por:

```gdscript
extends Node3D

const Player = preload("res://scripts/Player.gd")  # TEMP: ver nota de verificación tras mover el proyecto a godot/

@onready var mundo := $VoxelWorld
@onready var jugador: Player = $Player
@onready var camara_cenital: Camera3D = $CamaraCenital
@onready var zona_overlay: Node3D = $ZonaOverlay

var cenital_activa := false


func _ready() -> void:
	jugador.mundo = mundo


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_C:
			_alternar_camara_cenital()


## Alterna entre la cámara en 1ª persona del jugador y la cenital: congela
## el movimiento del jugador mientras la cenital está activa (conserva su
## posición al volver), y muestra/oculta el overlay de zonas — solo debe
## verse desde arriba, nunca en 1ª persona (decisión explícita del usuario).
func _alternar_camara_cenital() -> void:
	cenital_activa = not cenital_activa
	if cenital_activa:
		camara_cenital.posicionar_sobre_influencia()
	camara_cenital.current = cenital_activa
	jugador.camara.current = not cenital_activa
	jugador.set_physics_process(not cenital_activa)
	zona_overlay.visible = cenital_activa
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cenital_activa else Input.MOUSE_MODE_CAPTURED
```

- [ ] **Step 5: `Player.gd` debe ignorar su propio input cuando su cámara no está activa**

Sin este cambio, un clic izquierdo hecho para pintar una zona (con la cenital activa) también dispararía `_minar()` en `Player.gd`, porque `_input()` no distingue qué cámara está activa. Agregar una guarda al inicio de `_input()`:

```gdscript
func _input(event: InputEvent) -> void:
	if not camara.current:
		return
	if event is InputEventKey:
		...
```

(Mantener el resto del cuerpo de la función exactamente igual — solo se agrega la guarda de 2 líneas al principio.)

- [ ] **Step 6: Verificar que `Main.tscn` carga sin errores nuevos**

Run: `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"`, luego `mcp__godot__get_debug_output`.
Expected: mismas dos advertencias `SHADOWED_GLOBAL_IDENTIFIER` ya conocidas, sin errores nuevos (ni de parseo de `CamaraCenital.gd`/`ZonaOverlay.gd`, ni de nodos faltantes en `Main.tscn`). `mcp__godot__stop_project` después.

Nota: la interacción real (toggle con `C`, clics para pintar, overlay visible solo en cenital) solo se puede confirmar jugando la escena en el editor real — igual que el HUD (ver `PoC_4/`, Sección 3.4). Dejar esto anotado como pendiente de confirmación visual en el documento técnico (Tarea 4).

---

### Task 4: Verificación completa y documentación

**Files:**
- Modify: `PoC_4/Documento Técnico de Desarrollo_ PoC 4 - Integración de Ciudad y Avatar como Autoload.md`
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`

**Interfaces:** ninguna — tarea de verificación y documentación, no produce símbolos de código.

- [ ] **Step 1: Correr toda la suite de verificación del repo**

Run:
```bash
python -m unittest discover -s website -p "test_*.py"
```
Expected: todos los tests pasan (sin relación con este cambio, pero es la verificación estándar del repo — ver `CLAUDE.md`).

Run (vía Godot MCP, una escena a la vez, con `stop_project` entre cada una):
- `res://scenes/Test.tscn` (pruebas de `BlueprintValidator`, 13 tests) — deben seguir pasando sin cambios.
- `res://scenes/CiudadTest.tscn` (7 tests) — deben seguir pasando sin cambios.
- `res://scenes/ZonificacionTest.tscn` (8 tests, de la Tarea 1) — deben pasar.
- `res://scenes/Main.tscn` — debe cargar sin errores nuevos.

- [ ] **Step 2: Actualizar `PoC_4/Documento Técnico de Desarrollo_...md`**

Agregar una nueva sección (numerada siguiendo la que ya exista, p. ej. "2.6 Zonificación Pintada sobre el Grid") que documente: el autoload `Zonificacion.gd` y su API, la decisión de bootstrap del núcleo urbano, la cámara cenital mínima y su alcance reducido frente a PoC 5, el overlay visual y su visibilidad condicionada a la cámara activa, y la conexión de `_declarar_edificio()` con `validar_colocacion()` (ya existía en `BlueprintValidator.gd` pero nunca se usaba). Actualizar también:
- El banner superior del documento (qué está ✅ Verificado).
- La sección 1.1 (alcance) agregando el sub-proyecto 4 como completo, y 1.2 (fuera de alcance) listando lo explícitamente diferido (ver "Fuera de Alcance" de la spec).
- Sección 3.2/3.3 (pruebas y criterios de aceptación) con las 8 pruebas de `ZonificacionTest.gd` y los criterios nuevos (bootstrap correcto, recorte a la influencia, bloqueo por zona en `validar_colocacion`).
- "Próximos Pasos": marcar el sub-proyecto 4 como completo (con la nota de que la interacción visual real está pendiente de confirmación en el editor), y agregar como pendientes explícitos: cámara cenital completa (PoC 5), emplazar blueprints desde la vista cenital, y los demás tipos de edificio de la taxonomía (GDD 3.1).

- [ ] **Step 3: Actualizar el GDD**

En la fila de la Fase 2 (Sección 11): marcar los 4 sub-proyectos como completos (con las mismas salvedades de alcance reducido que en PoC_4), y actualizar la línea `**Versión del Documento:**` con un changelog describiendo la zonificación implementada (autoload `Zonificacion`, zona de influencia dinámica, cámara cenital mínima, bloqueo por zona en `declarar_edificio`).

- [ ] **Step 4: Resumen final para el usuario**

Confirmar en el chat: qué se implementó, qué se verificó (headless vía MCP + suite Python), y qué queda pendiente de confirmación visual/interactiva jugando en el editor real (toggle de cámara, pintado por clic, overlay). No hacer `git commit` — dejarlo listo para que el usuario lo pida explícitamente.
