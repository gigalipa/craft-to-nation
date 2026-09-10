# Edificios como Objeto Completo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ninguna celda que forme parte de un edificio registrado (fantasma en curso, terminado, o puesto periférico) puede minarse individualmente con `minar_bloque()`.

**Architecture:** Un registro nuevo `celda_a_edificio: Dictionary` (`Vector3i -> int`) en `VoxelWorld.gd`, poblado en tres puntos de colocación (fantasma, puesto, núcleo declarado manualmente), y una guardia al inicio de `minar_bloque()` que niega el minado de cualquier celda registrada.

**Tech Stack:** Godot 4.7 GDScript, GridMap (`VoxelWorld.gd`), autoloads de estado puro existentes (`Construccion.gd`, `Recoleccion.gd`).

**Spec:** `docs/superpowers/specs/2026-09-10-edificios-objeto-completo-design.md`

## Global Constraints

- El click izquierdo sobre una celda registrada no debe hacer nada (ni imprimir mensaje, ni destruir el bloque) — no "no hay espacio", simplemente `minar_bloque()` devuelve `false` sin efecto, igual que ya pasa hoy al minar una celda vacía.
- El registro NO se borra nunca al completarse una construcción fantasma — es independiente de `Construccion._celda_a_construccion`, que sí se limpia.
- El relleno de tierra de nivelación bajo un PUESTO (no bajo un blueprint) NO se registra — sigue siendo terreno. El relleno de tierra de un BLUEPRINT SÍ se registra, porque forma parte de `orden` en `iniciar_construccion_fantasma()`.
- No se implementa rotación, demolición, ni interacción con objetos internos (puerta/cama/baúl) en este plan — fuera de alcance, ver spec.
- Verificación: ejecutar `godot/scenes/Test.tscn` (todas las aserciones de `BlueprintValidatorTest.gd` deben pasar, incluyendo el nuevo TEST 20) y `godot/scenes/Main.tscn` (sin errores nuevos más allá de las 2 advertencias conocidas de colisión de nombre de clase).

---

### Task 1: Registro de edificio + guardia en minar_bloque() + registro de fantasmas + prueba

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Produces: `VoxelWorld.celda_a_edificio: Dictionary` (`Vector3i -> int`), `VoxelWorld.registrar_edificio(celdas: Array) -> int`. Ambos son consumidos por las Tasks 2 y 3 (llaman `mundo.registrar_edificio(...)`), y por `minar_bloque()` en esta misma task.

- [ ] **Step 1: Agregar el estado del registro junto a `colocado_por_jugador`/`pareja`**

En `godot/scripts/VoxelWorld.gd`, localiza este bloque (alrededor de la línea 79-88):

```gdscript
## Celdas colocadas por el jugador (Vector3i -> true). El terreno generado por
## _generar_terreno() nunca se marca aquí, así que "declarar un edificio"
## (ver Player.gd) nunca puede incluir el suelo del mundo como parte de la
## estructura, sin importar su tipo de bloque.
var colocado_por_jugador: Dictionary = {}

## Vínculo bidireccional entre las dos celdas de un objeto multi-celda
## (puerta: 2 celdas verticales; cama: 2 celdas horizontales). Minar
## cualquiera de las dos celdas borra ambas — ver minar_bloque().
var pareja: Dictionary = {}  # Vector3i -> Vector3i
```

Agrega inmediatamente después (antes de la línea en blanco previa a `func _ready()`):

```gdscript

## Celda -> id de edificio al que pertenece (fantasma en curso, terminado,
## o puesto periférico). minar_bloque() consulta este registro para negarse
## a minar cualquier celda que forme parte de un edificio: un edificio se
## comporta como un objeto completo, no como un grupo de bloques sueltos
## (igual que ya hacen los árboles vía TIPOS_ARBOL/talar_bloque_de_arbol()).
## No se borra nunca al completarse una construcción fantasma (a diferencia
## de Construccion._celda_a_construccion, que sí se limpia): la inmunidad
## debe seguir vigente después de terminado el edificio.
var celda_a_edificio: Dictionary = {}  # Vector3i -> int
var _siguiente_id_edificio := 1


## Asigna un id de edificio nuevo y registra cada celda de "celdas" bajo
## ese id. Devuelve el id asignado (no se usa hoy para nada más que
## depuración/tests, pero deja la puerta abierta a operar sobre "todas las
## celdas de este edificio" en el futuro — p. ej. rotación).
func registrar_edificio(celdas: Array) -> int:
	var id := _siguiente_id_edificio
	_siguiente_id_edificio += 1
	for celda in celdas:
		celda_a_edificio[celda] = id
	return id
```

- [ ] **Step 2: Guardia en `minar_bloque()`**

Localiza (alrededor de la línea 181):

```gdscript
func minar_bloque(celda: Vector3i) -> bool:
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
```

Reemplaza por:

```gdscript
func minar_bloque(celda: Vector3i) -> bool:
	if celda_a_edificio.has(celda):
		return false
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
```

El resto de la función (manejo de `pareja`, `set_cell_item`, etc.) queda igual.

- [ ] **Step 3: Registrar las celdas al iniciar una construcción fantasma**

Localiza (alrededor de la línea 430):

```gdscript
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	return Construccion.iniciar(orden, tipos, metadata)
```

Reemplaza por:

```gdscript
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	registrar_edificio(orden)
	return Construccion.iniciar(orden, tipos, metadata)
```

- [ ] **Step 4: Escribir TEST 20 en `BlueprintValidatorTest.gd`**

Abre `godot/scripts/BlueprintValidatorTest.gd` y localiza cómo TEST 19 instancia `VoxelWorld` (busca `TEST 19` y mira las líneas justo antes, donde se crea la instancia de `VoxelWorld.new()` o se añade como hijo — sigue exactamente ese mismo patrón de setup para no romper la escena). Añade el nuevo bloque de prueba inmediatamente después de TEST 19 y antes de la línea final `print("=== Las 19 pruebas...")`.

Actualiza también:
- El comentario/print final: `"=== Las 19 pruebas de BlueprintValidator pasaron correctamente ==="` → `"=== Las 20 pruebas de BlueprintValidator pasaron correctamente ==="`.
- Cualquier contador de pruebas totales si el archivo lleva uno explícito (revisa el inicio del archivo).

Código de TEST 20 (adapta el nombre de la variable de instancia de `VoxelWorld` al que ya use el archivo — se usa `mundo` como ejemplo, igual que en TEST 15/16/18/19):

```gdscript
	print("\n=== TEST 20: registrar_edificio() vuelve inmune al minado ===")

	# Celda normal, no registrada: sigue minándose igual que siempre.
	var celda_normal := Vector3i(300, 50, 300)
	mundo.colocar_bloque(celda_normal, "pared", true)
	var mineo_normal: bool = mundo.minar_bloque(celda_normal)
	assert(mineo_normal, "Una celda normal, no registrada, debe poder minarse")
	assert(mundo.obtener_tipo(celda_normal) == "", "La celda normal minada debe quedar vacía")

	# Celda registrada directamente (simula un puesto o un núcleo declarado):
	# no debe poder minarse.
	var celda_edificio := Vector3i(301, 50, 300)
	mundo.colocar_bloque(celda_edificio, "pared", true)
	mundo.registrar_edificio([celda_edificio])
	var mineo_edificio: bool = mundo.minar_bloque(celda_edificio)
	assert(not mineo_edificio, "Una celda registrada como parte de un edificio no debe poder minarse")
	assert(mundo.obtener_tipo(celda_edificio) == "pared", "La celda registrada debe seguir intacta tras intentar minarla")

	# Fantasma en curso: inmune desde que se inicia, antes de surtir nada.
	var celda_fantasma := Vector3i(302, 50, 300)
	var orden_fantasma: Array[Vector3i] = [celda_fantasma]
	var tipos_fantasma := {celda_fantasma: "pared"}
	mundo.iniciar_construccion_fantasma(orden_fantasma, tipos_fantasma)
	var mineo_fantasma: bool = mundo.minar_bloque(celda_fantasma)
	assert(not mineo_fantasma, "Una celda fantasma en curso no debe poder minarse")
	assert(mundo.obtener_tipo(celda_fantasma) == "fantasma", "La celda fantasma debe seguir intacta tras intentar minarla")

	# Se completa surtiendo la única celda pendiente: debe seguir inmune
	# después de convertirse en bloque real.
	mundo.surtir_construccion(celda_fantasma)
	var mineo_fantasma_completo: bool = mundo.minar_bloque(celda_fantasma)
	assert(not mineo_fantasma_completo, "Una celda de un edificio ya terminado (vía fantasma) no debe poder minarse")
	assert(mundo.obtener_tipo(celda_fantasma) == "pared", "La celda debe haberse convertido a su tipo real")

	print("OK: minar_bloque() ignora cualquier celda registrada con registrar_edificio(), sea directa, fantasma en curso, o fantasma completada.")
```

**Nota para el implementador:** las coordenadas `(300, 50, 300)`/`(301, 50, 300)`/`(302, 50, 300)` son un ejemplo — si TEST 15/16/18/19 ya usan una convención de "zona de pruebas" alejada del mundo real generado (offset `OX`/`OZ` o similar, para no chocar con terreno/agua/árboles reales de `ANCHO_MUNDO`/`LARGO_MUNDO`), síguela en vez de estos números literales. Verifica con `Read` el patrón exacto de TEST 18/19 antes de escribir las coordenadas finales.

- [ ] **Step 5: Ejecutar `Test.tscn` y verificar las 20 pruebas**

Ejecuta la escena `godot/scenes/Test.tscn` (headless o en el editor) y confirma la salida `"=== Las 20 pruebas de BlueprintValidator pasaron correctamente ==="` sin ningún `assert` fallido, y sin errores nuevos más allá de la advertencia conocida de colisión de nombre de clase `BlueprintValidator`.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: registrar_edificio() vuelve inmunes al minado las celdas de un edificio"
```

---

### Task 2: Registrar puestos periféricos y núcleo declarado manualmente

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/Player.gd`

**Interfaces:**
- Consumes: `VoxelWorld.registrar_edificio(celdas: Array) -> int` (Task 1).

- [ ] **Step 1: Registrar el footprint del puesto al colocar su marcador**

En `godot/scripts/CamaraCenital.gd`, localiza el bloque donde se coloca el marcador del puesto (identificado por la variable `bloque_marcador`, alrededor de la línea 1023-1026):

```gdscript
	var bloque_marcador: String = "mina" if _tipo_puesto_activo == "mina" else "puesto_caza"
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			mundo.colocar_bloque(Vector3i(esquina.x + dx, objetivo + 1, esquina.y + dz), bloque_marcador)
```

Reemplaza por:

```gdscript
	var bloque_marcador: String = "mina" if _tipo_puesto_activo == "mina" else "puesto_caza"
	var celdas_puesto: Array = []
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			var celda_marcador := Vector3i(esquina.x + dx, objetivo + 1, esquina.y + dz)
			mundo.colocar_bloque(celda_marcador, bloque_marcador)
			celdas_puesto.append(celda_marcador)
	mundo.registrar_edificio(celdas_puesto)
```

No registres el relleno de tierra de nivelación (líneas previas de esta misma función) — sigue siendo terreno, no parte del puesto.

- [ ] **Step 2: Registrar el núcleo al declararlo manualmente**

En `godot/scripts/Player.gd`, localiza en `_declarar_edificio()` (alrededor de la línea 219-220):

```gdscript
	if resultado["valido"]:
		Blueprints.guardar(blueprint)
		var total_camas := 0
```

Reemplaza por:

```gdscript
	if resultado["valido"]:
		Blueprints.guardar(blueprint)
		mundo.registrar_edificio(celdas.keys())
		var total_camas := 0
```

`celdas` es la variable ya definida más arriba en la misma función (`var celdas: Dictionary = mundo.detectar_estructura(celda)`), cuyas llaves son las celdas físicas reales de la estructura detectada (sin incluir `"piso"`, por el mismo criterio de siempre).

- [ ] **Step 3: Verificación manual en el editor**

Como `CamaraCenital.gd`/`Player.gd` no tienen pruebas automatizadas (input/cámara), ejecuta primero `godot/scenes/Main.tscn` headless para confirmar que no hay errores de parseo nuevos (solo las 2 advertencias conocidas de colisión de nombre de clase). Luego, pide al usuario que confirme jugando en vivo según la sección "Verificación de integración" del spec:
1. Fantasma: click izquierdo sobre una celda fantasma → no pasa nada.
2. Edificio terminado (vía blueprint): click izquierdo sobre una pared/puerta/cama → no pasa nada.
3. Puesto (mina o caza/recolección): click izquierdo sobre su marcador → no pasa nada.
4. Núcleo urbano declarado manualmente (bloque por bloque, sin blueprint): click izquierdo sobre una de sus paredes → no pasa nada.
5. Terreno normal y árboles: minar/talar sigue funcionando igual que antes.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/CamaraCenital.gd godot/scripts/Player.gd
git commit -m "feat: registrar puestos y núcleo declarado manualmente como edificios inmunes al minado"
```
