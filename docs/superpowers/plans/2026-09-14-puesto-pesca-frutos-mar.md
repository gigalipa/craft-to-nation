# Puesto de Pesca y Frutos del Mar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar un cuarto tipo de puesto periférico (pesca/frutos del mar) colocable con la tecla `F`, con huella 3×5 anclada mitad en tierra/mitad en agua, pilotes de `"pared"` en las 2 esquinas del extremo de agua, radio de acción de 25 celdas restringido a columnas de agua, y dos señales placeholder normalizadas (peces por ruido, algas/frutos del mar por profundidad relativa según tipo de cuerpo de agua).

**Architecture:** Extiende el patrón genérico de "puesto periférico" ya establecido por mina/caza-recolección/maderero (mismo `modo_colocar_puesto` en `CamaraCenital.gd`, mismo registro en `Recoleccion.puestos`), agregando ramas condicionales por tipo donde el comportamiento difiere (validación de extremos agua/tierra, confirmación con pilotes en vez de drenaje total, radio de acción filtrado a solo-agua). Las dos señales nuevas viven en `GeneradorMundo.gd`, mismo patrón que fauna/frutal/árbol/bioma.

**Tech Stack:** Godot 4.7 GDScript, `FastNoiseLite` nativo, `GridMap`/`MeshLibrary`, MCP de Godot (`mcp__godot__run_project`/`get_debug_output`/`stop_project`/`export_mesh_library`/`add_node`/`save_scene`) para verificación headless y edición de escena.

**Spec:** `docs/superpowers/specs/2026-09-14-puesto-pesca-frutos-mar-design.md`

## Global Constraints

- Huella `ANCHO_HUELLA_PESCA_FRUTOS_MAR = 3`, `ALTO_HUELLA_PESCA_FRUTOS_MAR = 5`. Tecla `F`.
- Extremo de agua: sus 3 celdas Y las 7 celdas de periferia (2 flancos + 5 celdas de la fila de frente) deben ser agua real; el extremo opuesto debe ser tierra firme completa.
- Confirmación: solo las 2 esquinas del extremo de agua se rellenan con `"pared"` (pilotes) hasta la altura objetivo; el resto del agua bajo la huella no se toca. El extremo de tierra se nivela con `"tierra"` igual que los demás puestos.
- `RADIO_AREA_PESCA_FRUTOS_MAR = 25`, origen en el punto medio del extremo de agua, filtrado a solo columnas de agua (ni cuenta ni dibuja tierra).
- Señal de peces: ruido puro (`densidad_peces_en`, mismo patrón que fauna/frutal/árbol), gateada por `es_agua_en()`.
- Señal de algas: `1.0 - profundidad_relativa`, normalizada por columna contra el techo de SU tipo de cuerpo de agua (río → `PROFUNDIDAD_MAXIMA_RIO`; mar/lago → `nivel_mar - ALTURA_MINIMA`).
- Sin producción real, sin inventario, sin cobro de costo — mismo alcance reducido que los otros tres puestos.
- Usa tabulaciones en GDScript. Conserva el español en comentarios, nombres y mensajes de prueba.

---

### Task 1: `GeneradorMundo.gd` — señales de peces y algas

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd`
- Test: `godot/scripts/GeneradorMundoTest.gd`

**Interfaces:**
- Produces: `densidad_peces_en(x: int, z: int) -> float`, `densidad_algas_en(x: int, z: int) -> float`, `_profundidad_relativa_agua_en(x: int, z: int) -> float` (usadas por Task 2 vía duck typing con `Object`, y directamente en las pruebas de este mismo task).
- Consumes: `es_agua_en()`, `es_rio_en()`, `profundidad_rio_en()`, `PROFUNDIDAD_MAXIMA_RIO`, `nivel_mar`, `ALTURA_MINIMA`, `altura_en()` — todos ya existentes, sin cambios de firma.

- [ ] **Step 1: Agregar el campo de ruido y su inicialización**

En la sección de `var _ruido_*: FastNoiseLite` (junto a `_ruido_arbol`, `_ruido_detalle`), agregar:

```gdscript
var _ruido_peces: FastNoiseLite
```

En `_init()`, junto a la inicialización de `_ruido_detalle` (semilla `+ 6`, la última usada), agregar:

```gdscript
# Semilla derivada distinta de _ruido, _ruido_mineral (+1), _ruido_fauna
# (+2), _ruido_frutal (+3), _ruido_arbol (+4), el RNG de _generar_rios()
# (+5) y _ruido_detalle (+6) — siguiente offset libre.
_ruido_peces = FastNoiseLite.new()
_ruido_peces.seed = semilla + 7
_ruido_peces.noise_type = FastNoiseLite.TYPE_PERLIN
_ruido_peces.frequency = 0.05
```

- [ ] **Step 2: Escribir las pruebas que fallan (TEST 31 y TEST 32)**

Al final de `ejecutar_pruebas()` en `GeneradorMundoTest.gd`, justo antes de la línea `print("\n=== Las 30 pruebas de GeneradorMundo pasaron correctamente ===")`, insertar:

```gdscript
	print("\n=== TEST 31: densidad_peces_en() es determinista, está en [0,1], y es 0.0 fuera del agua ===")
	var gen_dens_peces_a: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	var gen_dens_peces_b: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	var vio_fuera_peces := false
	var vio_dentro_peces := false
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var a: float = gen_dens_peces_a.densidad_peces_en(x, z)
			var b: float = gen_dens_peces_b.densidad_peces_en(x, z)
			assert(is_equal_approx(a, b))
			assert(a >= 0.0 and a <= 1.0)
			if not gen_dens_peces_a.es_agua_en(x, z):
				vio_fuera_peces = true
				assert(a == 0.0)
			else:
				vio_dentro_peces = true
	assert(vio_fuera_peces)
	assert(vio_dentro_peces)
	print("OK: densidad_peces_en es determinista, está en [0,1], y es exactamente 0.0 fuera del agua (con muestras dentro y fuera encontradas).")

	print("\n=== TEST 32: densidad_algas_en()/_profundidad_relativa_agua_en() normalizan cada columna contra el techo de SU tipo de cuerpo de agua ===")
	var gen_algas: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var vio_rio_algas := false
	var vio_mar_algas := false
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			if not gen_algas.es_agua_en(x, z):
				continue
			var relativa: float = gen_algas._profundidad_relativa_agua_en(x, z)
			assert(relativa >= 0.0 and relativa <= 1.0)
			assert(is_equal_approx(gen_algas.densidad_algas_en(x, z), 1.0 - relativa))
			if gen_algas.es_rio_en(x, z):
				vio_rio_algas = true
				var esperado_rio: float = float(gen_algas.profundidad_rio_en(x, z)) / float(GeneradorMundoScript.PROFUNDIDAD_MAXIMA_RIO)
				assert(is_equal_approx(relativa, esperado_rio))
			else:
				vio_mar_algas = true
				var techo: int = gen_algas.nivel_mar - GeneradorMundoScript.ALTURA_MINIMA
				var esperado_mar: float = clampf(float(gen_algas.nivel_mar - gen_algas.altura_en(x, z)) / float(techo), 0.0, 1.0)
				assert(is_equal_approx(relativa, esperado_mar))
	assert(vio_rio_algas)
	assert(vio_mar_algas)
	print("OK: la profundidad relativa de cada columna de agua se normaliza contra el techo de su propio tipo (río: PROFUNDIDAD_MAXIMA_RIO; mar/lago: nivel_mar - ALTURA_MINIMA), y densidad_algas_en() es siempre 1.0 menos esa profundidad relativa.")

	print("\n=== Las 32 pruebas de GeneradorMundo pasaron correctamente ===")
```

Y eliminar la línea anterior (`Las 30 pruebas...`) que queda duplicada.

- [ ] **Step 2b: Confirmar que las pruebas nuevas fallan por falta de las funciones**

Ejecutar `GeneradorMundoTest.tscn` vía `mcp__godot__run_project` + `get_debug_output` + `stop_project`.
Esperado: error de parseo/`Invalid call` porque `densidad_peces_en`/`densidad_algas_en`/`_profundidad_relativa_agua_en` no existen todavía.

- [ ] **Step 3: Implementar `densidad_peces_en()`, `_profundidad_relativa_agua_en()` y `densidad_algas_en()`**

Junto a `densidad_arbol_en()` (mismo bloque de señales de terreno), agregar:

```gdscript
## Densidad de peces en la columna de agua (x, z), en [0, 1] — 0.0 si la
## columna no es agua (ver es_agua_en()). Ruido puro (mismo patrón que
## densidad_fauna_en()/densidad_frutal_en()/densidad_arbol_en()): crea
## "nubes" de más/menos peces tanto en el mar como en cualquier río, sin
## relación con la profundidad real de esa columna (decisión explícita:
## una señal solo basada en profundidad resultaba demasiado plana/predecible).
func densidad_peces_en(x: int, z: int) -> float:
	if not es_agua_en(x, z):
		return 0.0
	var valor: float = _ruido_peces.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0


## Profundidad relativa de la columna de agua (x, z) en [0, 1], normalizada
## contra el techo realista de SU tipo de cuerpo de agua (río vs. mar/lago),
## para que un río (profundidad máxima PROFUNDIDAD_MAXIMA_RIO) y un mar
## (profundidad máxima nivel_mar - ALTURA_MINIMA) sean comparables en la
## misma escala relativa. 0.0 si la columna no es agua.
func _profundidad_relativa_agua_en(x: int, z: int) -> float:
	if not es_agua_en(x, z):
		return 0.0
	if es_rio_en(x, z):
		return float(profundidad_rio_en(x, z)) / float(PROFUNDIDAD_MAXIMA_RIO)
	var techo: int = nivel_mar - ALTURA_MINIMA
	if techo <= 0:
		return 0.0
	var profundidad: int = nivel_mar - altura_en(x, z)
	return clampf(float(profundidad) / float(techo), 0.0, 1.0)


## Densidad de algas/frutos del mar en la columna de agua (x, z), en [0, 1]
## — 0.0 si la columna no es agua. Geométrica, no ruido: inversa a la
## profundidad relativa (agua somera = más luz = más señal) — a diferencia
## de densidad_peces_en(), tiene sentido que dependa de geometría real.
func densidad_algas_en(x: int, z: int) -> float:
	if not es_agua_en(x, z):
		return 0.0
	return 1.0 - _profundidad_relativa_agua_en(x, z)
```

- [ ] **Step 4: Ejecutar `GeneradorMundoTest.tscn` y confirmar que las 32 pruebas pasan**

Run: `mcp__godot__run_project` con `scene: "res://scenes/GeneradorMundoTest.tscn"`, luego `get_debug_output`.
Expected: `=== Las 32 pruebas de GeneradorMundo pasaron correctamente ===`, sin errores.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: densidad_peces_en()/densidad_algas_en() para el puesto de pesca"
```

---

### Task 2: `Recoleccion.gd` — constantes, detección y tasas

**Files:**
- Modify: `godot/scripts/Recoleccion.gd`
- Test: `godot/scripts/RecoleccionTest.gd`

**Interfaces:**
- Consumes: cualquier objeto con `es_agua_en(x,z) -> bool`, `densidad_peces_en(x,z) -> float`, `densidad_algas_en(x,z) -> float` (duck typing — en producción es un `GeneradorMundo` real de Task 1; en pruebas, un generador falso).
- Produces: `detectar_pesca_frutos_mar(generador: Object, centro_xz: Vector2i) -> Dictionary` (`{"peces": float, "algas": float}`), `tasas_pesca_frutos_mar(promedios: Dictionary) -> Dictionary` (`{"pesca": float, "frutos_mar": float}`) — consumidas por Task 5.
- No depende de que Task 1 esté fusionado para poder implementarse/probarse (usa un generador falso en las pruebas), pero si Task 1 ya está en la rama, mejor — evita cualquier duda sobre la forma real de `GeneradorMundo`.

- [ ] **Step 1: Agregar las constantes nuevas**

Junto a las constantes de `ANCHO_HUELLA_MADERERO`/`RADIO_AREA_MADERERO` (mismo bloque de constantes por tipo de puesto), agregar:

```gdscript
const ANCHO_HUELLA_PESCA_FRUTOS_MAR := 3
const ALTO_HUELLA_PESCA_FRUTOS_MAR := 5

const RADIO_AREA_PESCA_FRUTOS_MAR := 25
const PASO_MUESTREO_PESCA_FRUTOS_MAR := 2
const TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO := 2.0

# GDD Sección 3 — mismos valores placeholder que los otros tres puestos,
# sin balance real todavía (ver Recoleccion.COSTO_CONSTRUCCION).
const COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_PESCA_FRUTOS_MAR := 3
const CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR := 100
```

- [ ] **Step 2: Escribir las pruebas que fallan (TEST 14, 15 y 16)**

En `RecoleccionTest.gd`, junto a `class GeneradorBiomaFalso`, agregar un segundo generador falso:

```gdscript
class GeneradorAguaFalso:
	func es_agua_en(x: int, z: int) -> bool:
		return x >= 0
	func densidad_peces_en(x: int, z: int) -> float:
		return 0.5 if x >= 0 else 0.0
	func densidad_algas_en(x: int, z: int) -> float:
		return 0.3 if x >= 0 else 0.0
```

Al final de `ejecutar_pruebas()`, reemplazar la línea `print("\n=== Las 13 pruebas de Recoleccion pasaron correctamente ===")` por:

```gdscript
	print("\n=== TEST 14: detectar_pesca_frutos_mar() omite columnas de tierra del promedio (no cuentan como 0.0) ===")
	var generador_agua := GeneradorAguaFalso.new()
	var promedios_pesca: Dictionary = Recoleccion.detectar_pesca_frutos_mar(generador_agua, Vector2i(0, 0))
	print("Promedios (mitad agua/mitad tierra dentro del radio): ", promedios_pesca)
	assert(is_equal_approx(promedios_pesca["peces"], 0.5))
	assert(is_equal_approx(promedios_pesca["algas"], 0.3))
	print("OK: las columnas de tierra dentro del radio se omiten del promedio — si contaran como 0.0, el resultado sería ~la mitad.")

	print("\n=== TEST 15: detectar_pesca_frutos_mar() sin ninguna columna de agua da 0.0/0.0 ===")
	var promedios_sin_agua: Dictionary = Recoleccion.detectar_pesca_frutos_mar(generador_agua, Vector2i(-1000, -1000))
	assert(is_equal_approx(promedios_sin_agua["peces"], 0.0))
	assert(is_equal_approx(promedios_sin_agua["algas"], 0.0))
	print("OK: sin ninguna muestra de agua, ambas señales devuelven 0.0 sin dividir por cero.")

	print("\n=== TEST 16: tasas_pesca_frutos_mar() multiplica cada señal por su tasa base ===")
	var tasas_pesca: Dictionary = Recoleccion.tasas_pesca_frutos_mar({"peces": 0.5, "algas": 0.3})
	assert(is_equal_approx(tasas_pesca["pesca"], 0.5 * Recoleccion.TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO))
	assert(is_equal_approx(tasas_pesca["frutos_mar"], 0.3 * Recoleccion.TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO))

	print("\n=== Las 16 pruebas de Recoleccion pasaron correctamente ===")
```

- [ ] **Step 2b: Confirmar que las pruebas nuevas fallan**

Run `RecoleccionTest.tscn`. Esperado: `Invalid call` en `detectar_pesca_frutos_mar`/`tasas_pesca_frutos_mar` (no existen todavía).

- [ ] **Step 3: Implementar `detectar_pesca_frutos_mar()` y `tasas_pesca_frutos_mar()`**

Junto a `detectar_arbol()`/`tasa_maderero()`, agregar:

```gdscript
## Promedia densidad_peces_en()/densidad_algas_en() (GeneradorMundo, duck
## typing) muestreadas cada PASO_MUESTREO_PESCA_FRUTOS_MAR celdas dentro del
## círculo de radio RADIO_AREA_PESCA_FRUTOS_MAR centrado en centro_xz (el
## punto medio del extremo de agua, no el centro de la huella — ver
## CamaraCenital.gd). A diferencia de detectar_fauna_frutal()/
## detectar_arbol(), las columnas que NO son agua se OMITEN por completo
## (ni cuentan como muestra) en vez de contribuir con 0.0 — este puesto
## siempre tiene tierra firme cerca de su origen por diseño, así que
## incluirla en el promedio lo castigaría sistemáticamente. Devuelve ambas
## claves en 0.0 si no hubo ninguna muestra de agua (evita dividir por cero).
func detectar_pesca_frutos_mar(generador: Object, centro_xz: Vector2i) -> Dictionary:
	var suma_peces := 0.0
	var suma_algas := 0.0
	var muestras := 0
	for dx in range(-RADIO_AREA_PESCA_FRUTOS_MAR, RADIO_AREA_PESCA_FRUTOS_MAR + 1, PASO_MUESTREO_PESCA_FRUTOS_MAR):
		for dz in range(-RADIO_AREA_PESCA_FRUTOS_MAR, RADIO_AREA_PESCA_FRUTOS_MAR + 1, PASO_MUESTREO_PESCA_FRUTOS_MAR):
			if Vector2(dx, dz).length() > RADIO_AREA_PESCA_FRUTOS_MAR:
				continue
			var x: int = centro_xz.x + dx
			var z: int = centro_xz.y + dz
			if not generador.es_agua_en(x, z):
				continue
			suma_peces += generador.densidad_peces_en(x, z)
			suma_algas += generador.densidad_algas_en(x, z)
			muestras += 1
	if muestras == 0:
		return {"peces": 0.0, "algas": 0.0}
	return {"peces": suma_peces / muestras, "algas": suma_algas / muestras}


## Dos tasas independientes ("pesca"/"frutos_mar"), cada una promedio_señal *
## TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO — mismo patrón que
## tasas_caza_recoleccion(), no se suman en un total.
func tasas_pesca_frutos_mar(promedios: Dictionary) -> Dictionary:
	return {
		"pesca": promedios["peces"] * TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO,
		"frutos_mar": promedios["algas"] * TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO,
	}
```

- [ ] **Step 4: Ejecutar `RecoleccionTest.tscn` y confirmar que las 16 pruebas pasan**

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: detectar_pesca_frutos_mar()/tasas_pesca_frutos_mar() en Recoleccion"
```

---

### Task 3: `MeshLibrary` — bloque marcador `"puesto_pesca"`

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Modify (regenerado, no editado a mano): `godot/assets/BlockLibrary.res`

**Interfaces:**
- Produces: bloque `"puesto_pesca"` colocable vía `VoxelWorld.colocar_bloque()` — consumido por Task 5.

Sin prueba GDScript nueva: ningún otro bloque marcador (`"puesto_caza"`, `"puesto_madero"`) tiene una prueba unitaria dedicada a su sola existencia en este proyecto — se verifica junto con la Task 5 al cargar `Main.tscn` sin errores nuevos.

- [ ] **Step 1: Agregar el sub-recurso y nodo en `BlockLibrarySource.tscn`**

Mismo patrón exacto que `"puesto_caza"`/`"puesto_madero"` (`BoxMesh` + `BoxShape3D` + `StandardMaterial3D` de color plano). Editar el `.tscn` directamente como texto (es el formato de escena de Godot, texto plano) — más fiable que una herramienta de nodos para agregar sub-recursos con `SubResource()`. Agregar, junto a los sub-recursos y nodos `puesto_caza`/`puesto_madero` existentes:

```
[sub_resource type="StandardMaterial3D" id="Mat_puesto_pesca"]
albedo_color = Color(0.1, 0.5, 0.55, 1)

[sub_resource type="BoxMesh" id="Mesh_puesto_pesca"]
material = SubResource("Mat_puesto_pesca")

[sub_resource type="BoxShape3D" id="Shape_puesto_pesca"]
```

Y el nodo (junto a `puesto_madero`):

```
[node name="puesto_pesca" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_puesto_pesca")

[node name="CollisionShape3D" type="CollisionShape3D" parent="puesto_pesca"]
shape = SubResource("Shape_puesto_pesca")
```

- [ ] **Step 2: Regenerar `BlockLibrary.res`**

Usar `mcp__godot__export_mesh_library` (mismo comando ya usado para los bloques anteriores) apuntando a `BlockLibrarySource.tscn` -> `godot/assets/BlockLibrary.res`.

- [ ] **Step 3: Verificar que `Main.tscn` sigue cargando sin errores nuevos**

Run `mcp__godot__run_project` con `scene: "res://scenes/Main.tscn"`, esperar unos segundos, `get_debug_output`, `stop_project`. Esperado: mismas 2 advertencias preexistentes de colisión de nombre de clase global, sin errores nuevos.

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res
git commit -m "feat: bloque marcador puesto_pesca en la MeshLibrary"
```

---

### Task 4: `HUD.gd` — ficha del puesto de pesca

**Files:**
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scenes/Main.tscn` (nuevo nodo `PescaFicha`, hermano de `MaderoFicha` en `HUDLayer`)

**Interfaces:**
- Produces: `mostrar_ficha_pesca()`, `actualizar_tasas_pesca(tasas: Dictionary)`, `ocultar_ficha_pesca()` — consumidas por Task 5.
- Consumes: `Recoleccion.COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR`, `PERSONAL_MAXIMO_PESCA_FRUTOS_MAR`, `CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR`, `TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO` (Task 2, ya debe estar fusionada).

Sin prueba GDScript nueva: no existe `HUDTest.gd` ni prueba unitaria de ninguna ficha existente (`MinaFicha`/`CazaFicha`/`MaderoFicha`) — se verifican junto con la Task 5 jugando en vivo.

- [ ] **Step 1: Agregar el nodo `PescaFicha` a `Main.tscn`**

Usar `mcp__godot__add_node` para duplicar la estructura exacta de `MaderoFicha` (un `VBoxContainer` con 4 `Label` hijos: `CostoLabel`, `PersonalLabel`, `AlmacenamientoLabel`, `TasasLabel`), como hermano de `MaderoFicha` bajo `HUDLayer`, con el mismo `offset_left/top/right/bottom` que las demás fichas y `visible = false`. Guardar con `mcp__godot__save_scene`. Si la herramienta no está disponible o falla, editar `Main.tscn` directamente como texto (mismo patrón visto en `MaderoFicha`: `[node name="PescaFicha" type="VBoxContainer" parent="HUDLayer"]` + 4 nodos `Label` hijos) — Godot asigna los `unique_id` faltantes al abrir el proyecto.

- [ ] **Step 2: Agregar los `@onready var` en `HUD.gd`**

Junto a los de `madero_ficha`:

```gdscript
@onready var pesca_ficha: VBoxContainer = $PescaFicha
@onready var pesca_costo_label: Label = $PescaFicha/CostoLabel
@onready var pesca_personal_label: Label = $PescaFicha/PersonalLabel
@onready var pesca_almacenamiento_label: Label = $PescaFicha/AlmacenamientoLabel
@onready var pesca_tasas_label: Label = $PescaFicha/TasasLabel
```

Y junto a `NOMBRES_CAZA_RECOLECCION`:

```gdscript
const NOMBRES_PESCA_FRUTOS_MAR := {
	"pesca": "pesca",
	"frutos_mar": "frutos del mar",
}
```

- [ ] **Step 3: Implementar `mostrar_ficha_pesca()`/`actualizar_tasas_pesca()`/`ocultar_ficha_pesca()`**

Mismo patrón exacto que `mostrar_ficha_caza()`/`actualizar_tasas_caza()`/`ocultar_ficha_caza()`:

```gdscript
## Mismo patrón que mostrar_ficha_caza(): valores FIJOS al activar el modo;
## las tasas sí varían — ver actualizar_tasas_pesca().
func mostrar_ficha_pesca() -> void:
	var partes_costo: Array = []
	for tipo in Recoleccion.COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR:
		partes_costo.append("%d %s" % [Recoleccion.COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR[tipo], tipo])
	pesca_costo_label.text = "Costo: %s" % ", ".join(partes_costo)
	pesca_personal_label.text = "Personal máximo: %d" % Recoleccion.PERSONAL_MAXIMO_PESCA_FRUTOS_MAR
	pesca_almacenamiento_label.text = "Almacenamiento: %d" % Recoleccion.CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR
	pesca_tasas_label.text = "Recolección prevista: -"
	pesca_ficha.visible = true


## Recalculada en vivo cada fotograma mientras el modo colocar-puesto (tipo
## "pesca_frutos_mar") está activo, a partir de
## Recoleccion.tasas_pesca_frutos_mar(). "tasas" puede ser un Dictionary
## vacío ({}) cuando el extremo de agua todavía no es válido — ver
## CamaraCenital.gd.
func actualizar_tasas_pesca(tasas: Dictionary) -> void:
	if tasas.get("pesca", 0.0) <= 0.0 and tasas.get("frutos_mar", 0.0) <= 0.0:
		pesca_tasas_label.text = "Recolección prevista: sin agua detectada"
		return
	var lineas: Array = []
	for tipo in tasas:
		lineas.append("%.1f comida/h por %s" % [tasas[tipo], NOMBRES_PESCA_FRUTOS_MAR.get(tipo, tipo)])
	pesca_tasas_label.text = "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)


func ocultar_ficha_pesca() -> void:
	pesca_ficha.visible = false
```

- [ ] **Step 4: Verificar que `Main.tscn` carga sin errores nuevos**

Run `mcp__godot__run_project` con `Main.tscn`, `get_debug_output`, `stop_project`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/HUD.gd godot/scenes/Main.tscn
git commit -m "feat: ficha de HUD para el puesto de pesca y frutos del mar"
```

---

### Task 5: `CamaraCenital.gd` — tecla, validación de extremos, radio solo-agua y confirmación con pilotes

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes (deben existir ya, Tasks 1-4 fusionadas): `Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR`/`ALTO_HUELLA_PESCA_FRUTOS_MAR`/`RADIO_AREA_PESCA_FRUTOS_MAR`/`detectar_pesca_frutos_mar()`/`tasas_pesca_frutos_mar()`, `hud.mostrar_ficha_pesca()`/`actualizar_tasas_pesca()`/`ocultar_ficha_pesca()`, bloque `"puesto_pesca"`.
- No produce interfaces nuevas para otras tasks (es la integración final).

Este es el único task de "juicio/integración" del plan — requiere leer y modificar varias funciones existentes de un archivo grande, coordinando 4 puntos de extensión. Sin prueba GDScript nueva (ver la nota de la Sección 6 del spec: ninguna validación de `CamaraCenital.gd` tiene prueba unitaria hoy, todas se verifican jugando en vivo o cargando `Main.tscn`).

- [ ] **Step 1: `RADIO_AREA_ACCION_MAX` de 12 a 25**

```gdscript
const RADIO_AREA_ACCION_MAX := 25
```

(Único cambio en `_crear_area_accion()` — sin más lógica nueva; el pool pasa de ~452 a ~1963 planos ocultos.)

- [ ] **Step 2: Helpers de validación del extremo de agua**

Junto a `_huella_tiene_columna_en_tierra()`, agregar:

```gdscript
## true si las "ancho" celdas de la fila "dz" (relativa a "esquina") son
## TODAS agua, false si son TODAS tierra firme, "" (cadena vacía) si están
## mezcladas — usa el bloque REAL actual (mundo.obtener_tipo()), mismo
## criterio que _huella_tiene_columna_en_tierra().
func _fila_uniforme_en(esquina: Vector2i, ancho: int, dz: int) -> String:
	var vistos_agua := 0
	for dx in range(ancho):
		var x: int = esquina.x + dx
		var z: int = esquina.y + dz
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) == "agua":
			vistos_agua += 1
	if vistos_agua == ancho:
		return "agua"
	if vistos_agua == 0:
		return "tierra"
	return ""


## true si las (ancho + 4) celdas que rodean por fuera el extremo de agua
## (fila "fila_agua", "df" = dirección hacia afuera de la huella: -1 si
## fila_agua = 0, +1 si fila_agua = alto - 1) son todas agua: las 2 celdas
## de flanco (a la misma fila que el extremo, una a cada lado) más toda la
## fila inmediatamente al frente, extendida un bloque más allá de cada
## flanco. Exige que el extremo no sea un charco angosto que termine justo
## en el borde de la huella.
func _periferia_extremo_es_agua(esquina: Vector2i, ancho: int, fila_agua: int, df: int) -> bool:
	var fila_frente := fila_agua + df
	for dx in range(-1, ancho + 1):
		var x: int = esquina.x + dx
		var z: int = esquina.y + fila_frente
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
			return false
	for dx in [-1, ancho]:
		var x: int = esquina.x + dx
		var z: int = esquina.y + fila_agua
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
			return false
	return true


## Regla de colocación exclusiva de "pesca_frutos_mar": exactamente uno de
## los dos extremos de "ancho" celdas (dz=0 y dz=alto-1) debe ser
## completamente agua (fila Y periferia) y el opuesto completamente tierra
## firme. Devuelve el dz del extremo de agua (0 o alto-1) si la huella es
## válida, o -1 si no lo es.
func _extremo_agua_de_huella_pesca(esquina: Vector2i, ancho: int, alto: int) -> int:
	var fila_a := _fila_uniforme_en(esquina, ancho, 0)
	var fila_b := _fila_uniforme_en(esquina, ancho, alto - 1)
	if fila_a == "agua" and fila_b == "tierra" and _periferia_extremo_es_agua(esquina, ancho, 0, -1):
		return 0
	if fila_b == "agua" and fila_a == "tierra" and _periferia_extremo_es_agua(esquina, ancho, alto - 1, 1):
		return alto - 1
	return -1
```

- [ ] **Step 3: `_actualizar_area_accion_agua()` — variante del círculo que omite tierra**

Junto a `_actualizar_area_accion()`, agregar:

```gdscript
## Igual que _actualizar_area_accion(), pero además de filtrar por radio,
## oculta cualquier plano cuya columna real no sea agua (mundo.generador.
## es_agua_en()) — exclusivo de "pesca_frutos_mar". Reutiliza el mismo pool
## _area_accion/_offsets_area_accion.
func _actualizar_area_accion_agua(centro: Vector2i, radio: int) -> void:
	for i in range(_offsets_area_accion.size()):
		var offset: Vector2i = _offsets_area_accion[i]
		var plano: MeshInstance3D = _area_accion[i]
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		if offset.length() > radio or not mundo.generador.es_agua_en(x, z):
			plano.visible = false
			continue
		var altura_celda: int = mundo.altura_en(x, z, true)
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE_AREA_ACCION, z + DESF)
		plano.visible = true
```

- [ ] **Step 4: Tecla `F`**

En `_unhandled_input()`, junto a la rama de `KEY_L`:

```gdscript
elif tecla.pressed and tecla.keycode == KEY_F:
	_alternar_modo_colocar_puesto("pesca_frutos_mar", Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR, Recoleccion.ALTO_HUELLA_PESCA_FRUTOS_MAR)
```

- [ ] **Step 5: Fichas en `_alternar_modo_colocar_puesto()`/`_salir_de_modo_colocar_puesto()`**

En ambas funciones, agregar `hud.ocultar_ficha_pesca()` junto a las otras 3 líneas `hud.ocultar_ficha_*()`. En el `if/elif/else` de `_alternar_modo_colocar_puesto()` que hoy es `if mina: elif caza: else: madero`, insertar un `elif` explícito para maderero y un `else` nuevo para pesca (para no dejar "pesca" cayendo en la rama de madero):

```gdscript
if tipo == "mina":
	hud.mostrar_ficha_mina()
elif tipo == "caza_recoleccion":
	hud.mostrar_ficha_caza()
elif tipo == "maderero":
	hud.mostrar_ficha_madero()
else:
	hud.mostrar_ficha_pesca()
```

- [ ] **Step 6: Rama nueva en `_actualizar_previsualizacion_puesto()`**

Reemplazar la línea `and _huella_tiene_columna_en_tierra(esquina, columnas)` de la construcción de `valida` por:

```gdscript
var huella_anclada: bool
var extremo_agua_dz := -1
if _tipo_puesto_activo == "pesca_frutos_mar":
	extremo_agua_dz = _extremo_agua_de_huella_pesca(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	huella_anclada = extremo_agua_dz != -1
else:
	huella_anclada = _huella_tiene_columna_en_tierra(esquina, columnas)
var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
		and not _huella_choca_con_otro_puesto(esquina, columnas) \
		and huella_anclada
```

Y en el `if/elif/else` de ficha/radio (hoy `if mina: elif caza: else: madero`), insertar entre `caza_recoleccion` y el `else` de madero:

```gdscript
elif _tipo_puesto_activo == "pesca_frutos_mar":
	if extremo_agua_dz != -1:
		@warning_ignore("integer_division")
		var centro_agua := Vector2i(esquina.x + _ancho_puesto_activo / 2, esquina.y + extremo_agua_dz)
		var promedios: Dictionary = Recoleccion.detectar_pesca_frutos_mar(mundo.generador, centro_agua)
		var tasas_pesca: Dictionary = Recoleccion.tasas_pesca_frutos_mar(promedios)
		hud.actualizar_tasas_pesca(tasas_pesca)
		_actualizar_area_accion_agua(centro_agua, Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)
	else:
		hud.actualizar_tasas_pesca({})
		_ocultar_area_accion()
```

- [ ] **Step 7: Validación y confirmación en `_procesar_clic_puesto()`**

Reemplazar el bloque `if not _huella_tiene_columna_en_tierra(esquina, columnas): ... return` por:

```gdscript
var extremo_agua_dz := -1
if _tipo_puesto_activo == "pesca_frutos_mar":
	extremo_agua_dz = _extremo_agua_de_huella_pesca(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	if extremo_agua_dz == -1:
		print("Colocación rechazada: la huella necesita un extremo completo sobre agua (con su periferia despejada) y el opuesto completo sobre tierra firme.")
		return
elif not _huella_tiene_columna_en_tierra(esquina, columnas):
	print("Colocación rechazada: la huella necesita al menos una columna sobre tierra firme.")
	return
```

Reemplazar el bloque de drenaje total + relleno (las líneas actuales de
`total_drenado`/`mundo.drenar_agua()`/`relleno`/`total_relleno`) por:

```gdscript
var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
var total_relleno := 0
var total_pilotes := 0
if _tipo_puesto_activo == "pesca_frutos_mar":
	var esquinas_pilote: Array[Vector2i] = [
		Vector2i(esquina.x, esquina.y + extremo_agua_dz),
		Vector2i(esquina.x + _ancho_puesto_activo - 1, esquina.y + extremo_agua_dz),
	]
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			var x: int = esquina.x + dx
			var z: int = esquina.y + dz
			var xz := Vector2i(x, z)
			var es_pilote: bool = esquinas_pilote.has(xz)
			var es_agua_real: bool = mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) == "agua"
			if es_agua_real and not es_pilote:
				continue  # agua abierta bajo la plataforma: no se toca
			var fondo: int = mundo.altura_en(x, z, true)
			var bloque: String = "pared" if es_pilote else "tierra"
			for h in range(fondo + 1, objetivo + 1):
				mundo.colocar_bloque(Vector3i(x, h, z), bloque)
				total_relleno += 1
				if es_pilote:
					total_pilotes += 1
else:
	var total_drenado := 0
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			total_drenado += mundo.drenar_agua(esquina.x + dx, esquina.y + dz)
	if total_drenado > 0:
		print("Agua drenada bajo el puesto: ", total_drenado, " bloques reemplazados por tierra.")
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			mundo.colocar_bloque(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y), "tierra")
		total_relleno += cantidad
if total_pilotes > 0:
	print("Pilotes colocados bajo el puesto: ", total_pilotes, " bloques de \"pared\".")
if total_relleno > 0:
	print("Terreno nivelado bajo el puesto: ", total_relleno, " bloques usados.")
```

(Nota: la variable `objetivo` ya no se recalcula más abajo — la línea
original `var objetivo: int = nivelador_puesto.altura_objetivo(...)` que
existía después del relleno se elimina, queda una sola declaración arriba.)

Y extender el `if/elif/else` de `bloque_marcador`:

```gdscript
var bloque_marcador: String
if _tipo_puesto_activo == "mina":
	bloque_marcador = "mina"
elif _tipo_puesto_activo == "caza_recoleccion":
	bloque_marcador = "puesto_caza"
elif _tipo_puesto_activo == "maderero":
	bloque_marcador = "puesto_madero"
else:
	bloque_marcador = "puesto_pesca"
```

- [ ] **Step 8: Verificar que `Main.tscn` sigue cargando sin errores**

Run `mcp__godot__run_project` con `Main.tscn`, `get_debug_output`, `stop_project`. Esperado: sin errores nuevos (las 2 advertencias preexistentes de colisión de nombre de clase global no cuentan).

- [ ] **Step 9: Ejecutar el resto de la batería de pruebas (regresión)**

`Test.tscn`, `GeneradorMundoTest.tscn`, `RecoleccionTest.tscn`, `NiveladorTerrenoTest.tscn`, `TranslucidosRendererTest.tscn` — todas deben seguir en 100% verde, sin cambios de comportamiento respecto a antes de este task (este task no modifica ninguna de las funciones que esos archivos prueban, salvo indirectamente vía `bloque_marcador`/`_tipo_puesto_activo`, que no tienen prueba unitaria).

- [ ] **Step 10: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: colocación, radio y confirmación con pilotes del puesto de pesca (tecla F)"
```

---

## Verificación manual final (no automatizable, jugando en el editor real)

Después de fusionar las 5 tasks: colocar un puesto de pesca junto a la costa
del mar y junto a un río; confirmar que la huella solo se pone verde con un
extremo real sobre agua (con su periferia de 7 celdas despejada) y el
opuesto sobre tierra; que un extremo de agua angosto (charco pegado a
tierra en algún lado) se rechaza aunque sus 3 celdas centrales sean agua;
que el círculo de 25 celdas no se dibuja sobre tierra; que al confirmar
solo las 2 esquinas del extremo de agua quedan como pilotes de `"pared"` y
el resto del agua bajo la plataforma sigue siendo agua real; que `Ctrl` +
rueda rota la huella (3×5 no es cuadrada); y que la ficha del HUD muestra
"pesca"/"frutos del mar" en vivo según la posición del cursor.
