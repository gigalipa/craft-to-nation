# Economía de Puestos: producción y acarreo (sub-proyecto 2A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que los cuatro puestos de recolección produzcan recursos reales: el jugador asigna colonos como recolectores y acarreadores desde un panel (clic en el puesto, cenital), los recolectores producen en el almacén local del puesto, los acarreadores caminan cargando hasta el núcleo urbano y el stock central de 8 recursos crece.

**Architecture:** `Economia.gd` es un autoload nuevo de lógica pura (mismo patrón que `Ciudad`/`Recoleccion`, dependencia `ciudad` inyectable) que guarda por puesto sus trabajadores, su almacén local y sus tasas, y produce cada `Ciudad.tick_simulado`. `Colonos.gd` solo ejecuta el movimiento (ir al puesto, recoger, ir al núcleo, entregar) y cambia el tipo del colono entre `desempleado` y `obrero` vía `Ciudad.reasignar_tipo`. El panel del puesto se construye por código (`PanelPuesto.gd`) y lo aloja `HUD.gd`; `CamaraCenital.gd` lo abre con clic izquierdo sobre un puesto cuando no hay un rectángulo de zona a medias.

**Tech Stack:** Godot 4.7 (GDScript), pruebas como escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-21-economia-puestos-produccion-acarreo-design.md`. Se apoya en el sub-proyecto 1 ya mergeado (`Colonos`, `BuscadorRutas`, `Ciudad.demografia`).

## Global Constraints

- GDScript con **tabulaciones** (CLAUDE.md). Autoloads: `extends Node`, sin `class_name`.
- Documentación, mensajes del juego, comentarios y pruebas en **español**.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python. No tocar `docs/Pendientes y próximos pasos.md` ni el diff de `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`. `docs/Recursos.xlsx` y `docs/Fichas_Consumo_Produccion.md` **solo** se editan en la Tarea 8 (el usuario lo pidió expresamente). No hacer `git add` de los `*.gd.uid` sueltos que ya están sin versionar. En cada commit, `git add` solo los archivos del paso.
- Verificación (CLAUDE.md): `godot/scenes/Test.tscn` con Godot 4.7 más las demás escenas `*Test.tscn` afectadas.
- **Cupos de trabajadores por puesto** (decisión del usuario): maderero 5, caza/recolección 7, pesca 7, mina 5 — compartidos entre recolectores y acarreadores. Almacén local por puesto: 100 (total entre recursos).
- **Tasas base del Excel** (`docs/Recursos.xlsx`, por trabajador y hora): tierra 1; piedra, hierro, cobre, carbón y tierras raras 5 (mina: cada una × su fracción en el área); madera 5 × densidad de árboles; caza 15 × densidad de fauna; frutos 5 × densidad frutal (Excel, columna `Árbol (obj)`, Comida 5; se interpreta como frutos — el usuario puede corregirlo); pesca 5 × densidad de peces; algas 1 × densidad de algas. Las claves de tasa existentes se conservan: mina → nombre del mineral; caza/recolección → `"caza"`, `"recoleccion"`; pesca → `"pesca"`, `"frutos_mar"`; maderero → `"madera"`. En `Economia`, `caza`/`recoleccion`/`pesca`/`frutos_mar` se suman en el recurso `"comida"`.
- Stock central: 8 recursos — `madera`, `comida`, `hierro` (como hoy) y `tierra`, `piedra`, `cobre`, `carbon`, `tierras_raras` (nuevos, cantidad inicial 0). Límite 1000 cada uno, salvo comida (2000).
- `CAPACIDAD_CARGA := 20` unidades por viaje de acarreo (placeholder).
- Ciclo del tiempo: 1 tick de `Ciudad` = 2 s reales = 1 hora de juego; un colono camina 2,5 celdas/s.
- Solo esta rebanada: **no** hay extracción física ni agotamiento (2B), ni refinerías/agua/energía (2C), ni costo de construcción de los puestos (sub-proyecto 3), ni representación visual de la carga.
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```

## Cómo ejecutar una escena de pruebas (headless)

Desde la raíz del repo, en bash:

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Pasa si imprime una única línea `=== Las N pruebas de ... pasaron correctamente ===` y ninguna con `Assertion`, `SCRIPT ERROR` o `Parse Error`. (El ruido `ObjectDB instances were leaked` al salir es conocido.) Para `ColonosTest` usa `--quit-after 300`.

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `godot/scripts/Ciudad.gd` | Modificar | Almacén de 8 recursos, `reasignar_tipo`, `tasa_neta` entre cierres de tick |
| `godot/scripts/CiudadTest.gd` | Modificar | Pruebas 18–20 |
| `godot/scripts/Recoleccion.gd` | Modificar | Tasas del Excel, cupos 5/7/7/5, `cupo_de`, `capacidad_almacen_de`, `esquina_de_puesto_en` |
| `godot/scripts/RecoleccionTest.gd` | Modificar | Ajustar pruebas 2, 9, 13, 16; añadir 19–21 |
| `godot/scripts/Zonificacion.gd` | Modificar | `huella_del_nucleo()` |
| `godot/scripts/ZonificacionTest.gd` | Modificar | Prueba 14 |
| `godot/scripts/Economia.gd` | Crear | Autoload puro: puestos, trabajadores, producción, `recoger`, `entregar` |
| `godot/scripts/EconomiaTest.gd`, `godot/scenes/EconomiaTest.tscn` | Crear | Pruebas de `Economia` |
| `godot/project.godot` | Modificar | Registrar el autoload `Economia` (antes de `Colonos`) |
| `godot/scripts/Colonos.gd` | Modificar | `contratar`, `despedir`, comportamiento de recolector y acarreador |
| `godot/scripts/ColonosTest.gd` | Modificar | Pruebas 18–23 |
| `godot/scripts/PanelPuesto.gd` | Crear | Panel del puesto (UI por código) |
| `godot/scripts/HUD.gd`, `godot/scenes/Main.tscn` | Modificar | Lista de control de recursos y alojar el panel |
| `godot/scripts/CamaraCenital.gd` | Modificar | Clic sobre un puesto abre el panel; registrar el puesto con sus tasas |
| `godot/scripts/Player.gd` | Modificar | `Economia.quitar_puesto` al deconstruir |
| GDD y `PoC_5/` (documento nuevo) | Modificar/Crear | Documentación (Tarea 8) |
| `docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md` | Modificar | Completarlos con la información actualizada (Tarea 8) |

---

### Task 1: `Ciudad` — almacén de 8 recursos, `reasignar_tipo`, `tasa_neta` entre cierres

**Files:**
- Modify: `godot/scripts/Ciudad.gd` (`_init` ~línea 153, `simular_tick` ~línea 359, nueva función junto a `regular_densidad_vertical`)
- Test: `godot/scripts/CiudadTest.gd` (añadir pruebas 18–20 y cambiar el banner final)

**Interfaces:**
- Consumes: nada de tareas previas.
- Produces:
  - `Ciudad.almacen` con las claves `madera, comida, hierro, tierra, piedra, cobre, carbon, tierras_raras` (cada una un `Ciudad.Recurso`).
  - `Ciudad.reasignar_tipo(de: String, a: String) -> bool` (mueve 1 unidad de `demografia[de]` a `demografia[a]`; `false` y sin cambios si `demografia[de] <= 0`).
  - `Recurso.tasa_neta` = cambio de `cantidad` entre el cierre del `simular_tick` anterior y el de este (el primer tick compara contra la cantidad con la que empezó).

- [ ] **Step 1: Escribir las pruebas que fallan**

En `godot/scripts/CiudadTest.gd`, sustituir la última línea del archivo (`print("\n=== Las 17 pruebas de Ciudad pasaron correctamente ===")`) por:

```gdscript
	print("\n=== TEST 18: el almacén tiene los 8 recursos de la economía ===")
	var ocho: Node = CiudadScript.new()
	for clave in ["madera", "comida", "hierro", "tierra", "piedra", "cobre", "carbon", "tierras_raras"]:
		assert(ocho.almacen.has(clave), "falta el recurso " + clave)
	assert(ocho.almacen.size() == 8)
	assert(ocho.almacen["tierra"].cantidad == 0.0 and ocho.almacen["tierras_raras"].limite == 1000.0)
	assert(ocho.almacen["comida"].limite == 2000.0)

	print("\n=== TEST 19: reasignar_tipo() mueve un habitante de un tipo a otro ===")
	var reasig: Node = CiudadScript.new()
	reasig.demografia["desempleado"] = 2
	assert(reasig.reasignar_tipo("desempleado", "obrero"))
	assert(reasig.demografia["desempleado"] == 1 and reasig.demografia["obrero"] == 1)
	assert(reasig.censo_total == 2, "el censo total no cambia")
	assert(reasig.reasignar_tipo("desempleado", "obrero"))
	assert(not reasig.reasignar_tipo("desempleado", "obrero"), "sin desempleados no reasigna")
	assert(reasig.demografia["desempleado"] == 0 and reasig.demografia["obrero"] == 2)

	print("\n=== TEST 20: tasa_neta se mide entre cierres de tick consecutivos ===")
	var neta: Node = CiudadScript.new()
	neta.migracion_activa = false
	neta.simular_tick(0.0)  # primer tick: sin consumo, todas las tasas en 0
	assert(neta.almacen["madera"].tasa_neta == 0.0)
	# Una entrega ENTRE ticks (la de un acarreador) debe verse en la tasa del siguiente.
	neta.almacen["madera"].agregar(30.0)
	neta.simular_tick(0.0)
	assert(is_equal_approx(neta.almacen["madera"].tasa_neta, 30.0), "la entrega entre ticks cuenta")
	neta.simular_tick(0.0)
	assert(neta.almacen["madera"].tasa_neta == 0.0, "sin entregas, vuelve a 0")

	print("\n=== Las 20 pruebas de Ciudad pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: FALLA (assert en el TEST 18: `almacen.size() == 8`, o error de función `reasignar_tipo` inexistente).

- [ ] **Step 3: Implementar**

En `godot/scripts/Ciudad.gd`:

1. Añadir, junto a `var _migrantes_acumulados := 0.0`:

```gdscript
## Cantidad de cada recurso al cierre del último simular_tick(); base de
## Recurso.tasa_neta (ver simular_tick()).
var _cantidad_al_cierre: Dictionary = {}
```

2. En `_init`, reemplazar el bloque `almacen = { ... }` por:

```gdscript
	almacen = {
		"madera": Recurso.new("Madera", 200, 1000),
		# Placeholder hasta que exista producción de comida: con 150 el avatar
		# (5 por tick de 2 s) la agotaba en 60 s y, sin comida, cada tick es
		# hambruna, lo que bloquea para siempre la migración de colonos.
		"comida": Recurso.new("Comida", 2000, 2000),
		"hierro": Recurso.new("Hierro", 50, 1000),
		# Recursos que llegan de los puestos (sub-proyecto 2A): empiezan en 0.
		"tierra": Recurso.new("Tierra", 0, 1000),
		"piedra": Recurso.new("Piedra", 0, 1000),
		"cobre": Recurso.new("Cobre", 0, 1000),
		"carbon": Recurso.new("Carbón", 0, 1000),
		"tierras_raras": Recurso.new("Tierras raras", 0, 1000),
	}
```

3. En `Recurso`, actualizar el comentario de `tasa_neta`:

```gdscript
	## Cambio neto de "cantidad" entre el cierre del simular_tick() anterior y
	## el de este (positivo = ganancia, negativo = consumo neto): así incluye lo
	## que llega entre ticks, como las entregas de los acarreadores. Usado por
	## el HUD (lista de recursos).
	var tasa_neta: float = 0.0
```

4. Añadir tras `regular_densidad_vertical()`:

```gdscript
## Mueve un habitante de un tipo de población a otro (p. ej. desempleado ->
## obrero al asignarlo a un puesto). Falso, sin cambios, si no queda ninguno
## del tipo de origen.
func reasignar_tipo(de: String, a: String) -> bool:
	if demografia[de] <= 0:
		return false
	demografia[de] -= 1
	demografia[a] += 1
	return true
```

5. En `simular_tick`, sustituir las primeras líneas (el bloque `var cantidad_antes ...` con su `for`) por:

```gdscript
	# tasa_neta se mide entre cierres de tick consecutivos, no dentro de un
	# tick: así incluye lo que se agrega entre ticks (entregas de acarreadores).
	# El primer tick no tiene cierre previo y usa la cantidad con la que empieza.
	var referencia: Dictionary = _cantidad_al_cierre.duplicate()
	if referencia.is_empty():
		for clave in almacen:
			referencia[clave] = (almacen[clave] as Recurso).cantidad
```

y el bucle final de `tasa_neta` por:

```gdscript
	for clave in almacen:
		var recurso: Recurso = almacen[clave]
		recurso.tasa_neta = recurso.cantidad - float(referencia[clave])
		_cantidad_al_cierre[clave] = recurso.cantidad
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: el mismo comando del Step 2.
Expected: PASS — una línea `=== Las 20 pruebas de Ciudad pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/CiudadTest.gd
git commit -m "feat: almacén de 8 recursos, reasignar_tipo y tasa_neta entre cierres de tick" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: `Recoleccion` y `Zonificacion` — tasas del Excel, cupos y accesores

**Files:**
- Modify: `godot/scripts/Recoleccion.gd` (constantes de tasa y `PERSONAL_MAXIMO*`, `tasas_recoleccion`, `tasas_caza_recoleccion`, `tasa_maderero`, `tasas_pesca_frutos_mar`, funciones nuevas)
- Modify: `godot/scripts/Zonificacion.gd` (`huella_del_nucleo`)
- Test: `godot/scripts/RecoleccionTest.gd`, `godot/scripts/ZonificacionTest.gd`

**Interfaces:**
- Consumes: nada de tareas previas.
- Produces:
  - `Recoleccion.cupo_de(tipo: String) -> int` (5/7/7/5 para `"mina"`, `"caza_recoleccion"`, `"pesca_frutos_mar"`, `"maderero"` según corresponda; 0 para otro tipo).
  - `Recoleccion.capacidad_almacen_de(tipo: String) -> int` (100 para los cuatro; 0 para otro).
  - `Recoleccion.SIN_PUESTO := Vector2i(-99999, -99999)` y `Recoleccion.esquina_de_puesto_en(celda: Vector2i) -> Vector2i` (esquina del puesto de trabajo cuya huella contiene `celda`, o `SIN_PUESTO`; los edificios `"blueprint"` no cuentan).
  - Las funciones `tasas_*` devuelven las mismas claves que antes con las tasas base del Excel.
  - `Zonificacion.huella_del_nucleo() -> Array` (copia de las celdas `Vector2i` del núcleo; `[]` si no hay núcleo).

- [ ] **Step 1: Escribir las pruebas**

En `godot/scripts/RecoleccionTest.gd`:

a) TEST 2 (líneas ~113-114): sustituir los dos `assert` por:

```gdscript
	assert(is_equal_approx(tasas["piedra"], 3.75))  # 3/4 * 5.0 (Excel: piedra 5/h)
	assert(is_equal_approx(tasas["hierro"], 1.25))  # 1/4 * 5.0
	var tasas_tierra: Dictionary = Recoleccion.tasas_recoleccion({"tierra": 1, "hierro": 1})
	assert(is_equal_approx(tasas_tierra["tierra"], 0.5), "la tierra se extrae a 1/h: 1/2 * 1.0")
	assert(is_equal_approx(tasas_tierra["hierro"], 2.5), "1/2 * 5.0")
```

b) TEST 9 (líneas ~171-172): sustituir por:

```gdscript
	assert(is_equal_approx(tasas_caza["caza"], 0.5 * Recoleccion.TASA_BASE_CAZA_POR_CIUDADANO))
	assert(is_equal_approx(tasas_caza["recoleccion"], 0.25 * Recoleccion.TASA_BASE_FRUTOS_POR_CIUDADANO))
	assert(is_equal_approx(tasas_caza["caza"], 7.5) and is_equal_approx(tasas_caza["recoleccion"], 1.25))
```

c) TEST 13 (línea ~253): no requiere edición; `TASA_BASE_MADERERO_POR_CIUDADANO` sigue existiendo (ahora vale 5.0) y el assert usa la constante.

d) TEST 16 (líneas ~277-278): sustituir por:

```gdscript
	assert(is_equal_approx(tasas_pesca["pesca"], 0.5 * Recoleccion.TASA_BASE_PESCA_POR_CIUDADANO))
	assert(is_equal_approx(tasas_pesca["frutos_mar"], 0.3 * Recoleccion.TASA_BASE_ALGAS_POR_CIUDADANO))
	assert(is_equal_approx(tasas_pesca["pesca"], 2.5) and is_equal_approx(tasas_pesca["frutos_mar"], 0.3))
```

e) Al final, sustituir la línea del banner (`=== Las 18 pruebas de Recoleccion ...`) por:

```gdscript
	print("\n=== TEST 19: cupo_de() y capacidad_almacen_de() por tipo de puesto ===")
	assert(Recoleccion.cupo_de("maderero") == 5)
	assert(Recoleccion.cupo_de("caza_recoleccion") == 7)
	assert(Recoleccion.cupo_de("pesca_frutos_mar") == 7)
	assert(Recoleccion.cupo_de("mina") == 5)
	assert(Recoleccion.cupo_de("blueprint") == 0)
	assert(Recoleccion.capacidad_almacen_de("mina") == 100 and Recoleccion.capacidad_almacen_de("maderero") == 100)
	assert(Recoleccion.capacidad_almacen_de("blueprint") == 0)

	print("\n=== TEST 20: esquina_de_puesto_en() encuentra el puesto por cualquier celda de su huella ===")
	Recoleccion.puestos.clear()
	Recoleccion.colocar_puesto(Vector2i(10, 10), "maderero", 3, 4)
	Recoleccion.colocar_puesto(Vector2i(30, 30), "blueprint", 5, 5)
	assert(Recoleccion.esquina_de_puesto_en(Vector2i(10, 10)) == Vector2i(10, 10))
	assert(Recoleccion.esquina_de_puesto_en(Vector2i(12, 13)) == Vector2i(10, 10), "la esquina opuesta también")
	assert(Recoleccion.esquina_de_puesto_en(Vector2i(13, 10)) == Recoleccion.SIN_PUESTO, "justo fuera de la huella")
	assert(Recoleccion.esquina_de_puesto_en(Vector2i(31, 31)) == Recoleccion.SIN_PUESTO, "un edificio (blueprint) no es un puesto de trabajo")
	Recoleccion.puestos.clear()

	print("\n=== Las 20 pruebas de Recoleccion pasaron correctamente ===")
```

En `godot/scripts/ZonificacionTest.gd`, sustituir la última línea (banner de 13) por:

```gdscript
	print("\n=== TEST 14: huella_del_nucleo() devuelve una copia de la huella declarada ===")
	var con_nucleo: Node = ZonificacionScript.new()
	assert(con_nucleo.huella_del_nucleo().is_empty(), "sin núcleo, vacía")
	con_nucleo.declarar_nucleo([Vector2i(1, 1), Vector2i(2, 1)])
	var huella_n: Array = con_nucleo.huella_del_nucleo()
	assert(huella_n.size() == 2 and huella_n.has(Vector2i(2, 1)))
	huella_n.clear()
	assert(con_nucleo.huella_del_nucleo().size() == 2, "modificar la copia no altera el núcleo")

	print("\n=== Las 14 pruebas de Zonificacion pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `RecoleccionTest.tscn` y `ZonificacionTest.tscn` (mismo comando, `--quit-after 60`).
Expected: FALLA (constantes `TASA_BASE_CAZA_POR_CIUDADANO`… inexistentes → Parse Error; `huella_del_nucleo` inexistente).

- [ ] **Step 3: Implementar**

En `godot/scripts/Recoleccion.gd`:

1. Reemplazar `const TASA_BASE_POR_CIUDADANO := 2.0` (línea 18) por:

```gdscript
## Unidades por trabajador y hora de cada mineral (docs/Recursos.xlsx). La tasa
## de un mineral en una mina es su fracción en el área × esta tasa base.
const TASAS_BASE_MINERAL := {
	"tierra": 1.0, "piedra": 5.0, "hierro": 5.0,
	"cobre": 5.0, "carbon": 5.0, "tierras_raras": 5.0,
}

## Marca de "no hay puesto" para esquina_de_puesto_en().
const SIN_PUESTO := Vector2i(-99999, -99999)
## Los únicos tipos de puesto donde se asignan trabajadores (los edificios
## registrados con tipo "blueprint" comparten el registro pero no son puestos).
const TIPOS_PUESTO_TRABAJO := ["mina", "caza_recoleccion", "maderero", "pesca_frutos_mar"]
```

2. `const PERSONAL_MAXIMO := 3` → `const PERSONAL_MAXIMO := 5`; `PERSONAL_MAXIMO_MADERERO := 3` → `5`; `PERSONAL_MAXIMO_CAZA_RECOLECCION := 3` → `7`; `PERSONAL_MAXIMO_PESCA_FRUTOS_MAR := 3` → `7`. Añadir encima de `const PERSONAL_MAXIMO` el comentario `## Cupos de trabajadores (decisión del usuario, 2026-09-21): mina 5, maderero 5, caza/recolección 7, pesca 7.`

3. `const TASA_BASE_MADERERO_POR_CIUDADANO := 2.0` → `5.0`.

4. Reemplazar `const TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO := 2.0` por:

```gdscript
const TASA_BASE_CAZA_POR_CIUDADANO := 15.0  # Excel: venado 15/h
const TASA_BASE_FRUTOS_POR_CIUDADANO := 5.0  # Excel: columna "Árbol (obj)", Comida 5/h (se interpreta como frutos)
```

5. Reemplazar `const TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO := 2.0` por:

```gdscript
const TASA_BASE_PESCA_POR_CIUDADANO := 5.0  # Excel: pescado 5/h
const TASA_BASE_ALGAS_POR_CIUDADANO := 1.0  # Excel: algas 1/h
```

6. En `tasas_recoleccion`, cambiar la línea del cálculo por
`tasas[tipo] = (float(conteo[tipo]) / float(total)) * TASAS_BASE_MINERAL[tipo]` y actualizar el comentario de la función ("multiplicada por la tasa base de ese mineral (TASAS_BASE_MINERAL)").

7. En `tasas_caza_recoleccion`:

```gdscript
	return {
		"caza": promedios["fauna"] * TASA_BASE_CAZA_POR_CIUDADANO,
		"recoleccion": promedios["frutal"] * TASA_BASE_FRUTOS_POR_CIUDADANO,
	}
```

y en `tasas_pesca_frutos_mar`:

```gdscript
	return {
		"pesca": promedios["peces"] * TASA_BASE_PESCA_POR_CIUDADANO,
		"frutos_mar": promedios["algas"] * TASA_BASE_ALGAS_POR_CIUDADANO,
	}
```

Actualizar los comentarios de ambas funciones ("cada señal × la tasa base propia del Excel").

8. Añadir después de `celda_dentro_de_algun_puesto()`:

```gdscript
## Cupo de trabajadores (recolectores + acarreadores) de un tipo de puesto; 0
## para un tipo que no es puesto de trabajo.
func cupo_de(tipo: String) -> int:
	match tipo:
		"mina": return PERSONAL_MAXIMO
		"maderero": return PERSONAL_MAXIMO_MADERERO
		"caza_recoleccion": return PERSONAL_MAXIMO_CAZA_RECOLECCION
		"pesca_frutos_mar": return PERSONAL_MAXIMO_PESCA_FRUTOS_MAR
	return 0


## Capacidad del almacén local de un tipo de puesto (total entre recursos).
func capacidad_almacen_de(tipo: String) -> int:
	match tipo:
		"mina": return CAPACIDAD_ALMACENAMIENTO
		"maderero": return CAPACIDAD_ALMACENAMIENTO_MADERERO
		"caza_recoleccion": return CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION
		"pesca_frutos_mar": return CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR
	return 0


## Esquina del puesto de trabajo (mina, caza/recolección, maderero, pesca)
## cuya huella contiene "celda", o SIN_PUESTO. Ignora los edificios
## registrados con tipo "blueprint". Usada por CamaraCenital para abrir el
## panel del puesto al hacer clic.
func esquina_de_puesto_en(celda: Vector2i) -> Vector2i:
	for esquina in puestos:
		var datos: Dictionary = puestos[esquina]
		if not TIPOS_PUESTO_TRABAJO.has(datos["tipo"]):
			continue
		if celda.x >= esquina.x and celda.x < esquina.x + datos["ancho"] \
				and celda.y >= esquina.y and celda.y < esquina.y + datos["alto"]:
			return esquina
	return SIN_PUESTO
```

En `godot/scripts/Zonificacion.gd`, después de `celda_es_del_nucleo()`:

```gdscript
## Copia de las celdas (X,Z) de la huella del núcleo urbano; [] si todavía no
## se declaró. La usan los acarreadores para saber dónde entregar (Colonos.gd).
func huella_del_nucleo() -> Array:
	return _huella_nucleo.duplicate()
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `RecoleccionTest.tscn`, `ZonificacionTest.tscn` y `CamaraCenital`-dependientes no aplican; comprobar además que nada más usa las constantes renombradas: `grep -rn "TASA_BASE_POR_CIUDADANO\|TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO\|TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO" godot/` debe dar vacío.
Expected: PASS — `Las 20 pruebas de Recoleccion` y `Las 14 pruebas de Zonificacion`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd godot/scripts/Zonificacion.gd godot/scripts/ZonificacionTest.gd
git commit -m "feat: tasas del Excel, cupos de puesto y accesores de Recoleccion/Zonificacion" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 3: `Economia.gd` — autoload de producción y acarreo

**Files:**
- Create: `godot/scripts/Economia.gd`
- Create: `godot/scripts/EconomiaTest.gd`, `godot/scenes/EconomiaTest.tscn`
- Modify: `godot/project.godot` (sección `[autoload]`)

**Interfaces:**
- Consumes: `Ciudad.almacen[r].agregar(monto)` (Tarea 1); `Recoleccion.cupo_de(tipo)`, `Recoleccion.capacidad_almacen_de(tipo)` (Tarea 2, autoload global).
- Produces (todo en el autoload `Economia`):
  - `signal puesto_quitado(ids: Array)` — ids de colonos liberados por `quitar_puesto`.
  - `const CAPACIDAD_CARGA := 20.0`
  - `var ciudad: Object`, `var puestos: Dictionary` (esquina `Vector2i` → datos).
  - `registrar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int, tasas: Dictionary) -> void`
  - `quitar_puesto(esquina: Vector2i) -> void`
  - `tiene_puesto(esquina: Vector2i) -> bool`
  - `huella_de(esquina: Vector2i) -> Array` (celdas `Vector2i`; `[]` si no existe)
  - `asignar(esquina: Vector2i, rol: String, colono_id: int) -> bool` (`rol` ∈ `"recolector"`, `"acarreador"`)
  - `liberar(colono_id: int) -> void`
  - `ultimo_de(esquina: Vector2i, rol: String) -> int` (`-1` si no hay)
  - `marcar_presente(colono_id: int, presente: bool) -> void`
  - `cupo_libre(esquina: Vector2i) -> int`
  - `trabajadores_de(esquina: Vector2i) -> Dictionary` (`{"recolectores": n, "acarreadores": n, "presentes": n}`)
  - `produccion_por_hora(esquina: Vector2i) -> Dictionary` (recurso → unidades/h con los recolectores presentes ahora)
  - `almacen_local(esquina: Vector2i) -> Dictionary` (recurso → cantidad, copia)
  - `simular_hora() -> void` (una hora de producción; la llama `Ciudad.tick_simulado`)
  - `recoger(esquina: Vector2i, capacidad: float) -> Dictionary` y `entregar(carga: Dictionary) -> void`

- [ ] **Step 1: Escribir la prueba que falla**

Crear `godot/scenes/EconomiaTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/EconomiaTest.gd" id="1"]

[node name="EconomiaTest" type="Node"]
script = ExtResource("1")
```

Crear `godot/scripts/EconomiaTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de Economia.gd, sin escena: una Ciudad real instanciada
## fuera del árbol (igual que ColonosTest.gd) y una Economia nueva con esa
## ciudad inyectada. Corre esta escena y revisa que no lance ningún assert().

const EconomiaScript = preload("res://scripts/Economia.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")

const ESQ := Vector2i(10, 10)


func _ready() -> void:
	ejecutar_pruebas()


## Una Economia con un maderero (5 de cupo) en ESQ y tasa 3 madera/h.
func _nueva(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0})
	return economia


func ejecutar_pruebas() -> void:
	print("=== TEST 1: registrar_puesto() y huella_de() ===")
	var e1: Node = _nueva(CiudadScript.new())
	assert(e1.tiene_puesto(ESQ) and not e1.tiene_puesto(Vector2i(0, 0)))
	assert(e1.huella_de(ESQ).size() == 12 and e1.huella_de(ESQ).has(Vector2i(12, 13)))
	assert(e1.huella_de(Vector2i(0, 0)).is_empty())
	assert(e1.cupo_libre(ESQ) == 5, "el maderero admite 5 trabajadores")
	assert(e1.trabajadores_de(ESQ) == {"recolectores": 0, "acarreadores": 0, "presentes": 0})

	print("\n=== TEST 2: asignar() respeta el cupo total y no repite colonos ===")
	for id in range(1, 6):
		assert(e1.asignar(ESQ, "recolector" if id <= 3 else "acarreador", id))
	assert(e1.cupo_libre(ESQ) == 0)
	assert(not e1.asignar(ESQ, "recolector", 6), "cupo lleno")
	assert(e1.trabajadores_de(ESQ)["recolectores"] == 3 and e1.trabajadores_de(ESQ)["acarreadores"] == 2)
	e1.liberar(4)
	assert(e1.cupo_libre(ESQ) == 1)
	assert(not e1.asignar(ESQ, "recolector", 1), "un colono ya asignado no se asigna otra vez")
	assert(not e1.asignar(Vector2i(0, 0), "recolector", 9), "un puesto inexistente no admite trabajadores")
	assert(not e1.asignar(ESQ, "jardinero", 9), "rol desconocido")
	assert(e1.ultimo_de(ESQ, "recolector") == 3 and e1.ultimo_de(ESQ, "acarreador") == 5)
	assert(e1.ultimo_de(Vector2i(0, 0), "recolector") == -1)

	print("\n=== TEST 3: solo producen los recolectores PRESENTES ===")
	var e3: Node = _nueva(CiudadScript.new())
	e3.asignar(ESQ, "recolector", 1)
	e3.asignar(ESQ, "recolector", 2)
	e3.asignar(ESQ, "acarreador", 3)
	e3.simular_hora()
	assert(e3.almacen_local(ESQ).is_empty(), "nadie presente: no produce")
	e3.marcar_presente(1, true)
	e3.marcar_presente(3, true)  # un acarreador no cuenta como productor
	assert(e3.trabajadores_de(ESQ)["presentes"] == 1)
	e3.simular_hora()
	assert(is_equal_approx(e3.almacen_local(ESQ)["madera"], 3.0))
	assert(is_equal_approx(e3.produccion_por_hora(ESQ)["madera"], 3.0))
	e3.marcar_presente(2, true)
	e3.simular_hora()
	assert(is_equal_approx(e3.almacen_local(ESQ)["madera"], 9.0), "3 + 2 recolectores x 3")
	e3.marcar_presente(2, false)
	assert(e3.trabajadores_de(ESQ)["presentes"] == 1)

	print("\n=== TEST 4: el almacén local tiene tope (100) y el exceso se pierde ===")
	var e4: Node = _nueva(CiudadScript.new())
	e4.registrar_puesto(Vector2i(50, 50), "mina", 5, 5, {"hierro": 30.0, "piedra": 10.0})
	e4.asignar(Vector2i(50, 50), "recolector", 1)
	e4.marcar_presente(1, true)
	for i in range(10):
		e4.simular_hora()
	var local4: Dictionary = e4.almacen_local(Vector2i(50, 50))
	assert(is_equal_approx(local4["hierro"] + local4["piedra"], 100.0), "nunca pasa de 100 en total")
	assert(is_equal_approx(local4["hierro"] / local4["piedra"], 3.0), "conserva la proporción de la tasa")

	print("\n=== TEST 5: caza, frutos, pesca y algas suman en comida ===")
	var e5: Node = _nueva(CiudadScript.new())
	e5.registrar_puesto(Vector2i(60, 60), "caza_recoleccion", 4, 4, {"caza": 7.5, "recoleccion": 1.25})
	e5.asignar(Vector2i(60, 60), "recolector", 1)
	e5.marcar_presente(1, true)
	e5.simular_hora()
	var local5: Dictionary = e5.almacen_local(Vector2i(60, 60))
	assert(local5.size() == 1 and is_equal_approx(local5["comida"], 8.75))
	e5.registrar_puesto(Vector2i(70, 70), "pesca_frutos_mar", 4, 6, {"pesca": 2.5, "frutos_mar": 0.3})
	e5.asignar(Vector2i(70, 70), "recolector", 2)
	e5.marcar_presente(2, true)
	e5.simular_hora()
	assert(is_equal_approx(e5.almacen_local(Vector2i(70, 70))["comida"], 2.8))

	print("\n=== TEST 6: recoger() entrega carga completa, o el resto si ya no hay recolectores ===")
	var e6: Node = _nueva(CiudadScript.new())
	e6.asignar(ESQ, "recolector", 1)
	e6.marcar_presente(1, true)
	for i in range(3):
		e6.simular_hora()  # 9 madera
	assert(e6.recoger(ESQ, 20.0).is_empty(), "con recolectores presentes espera a tener la carga completa")
	for i in range(4):
		e6.simular_hora()  # 21 madera
	var carga6: Dictionary = e6.recoger(ESQ, 20.0)
	assert(is_equal_approx(carga6["madera"], 20.0))
	assert(is_equal_approx(e6.almacen_local(ESQ)["madera"], 1.0), "queda el resto")
	assert(e6.recoger(ESQ, 20.0).is_empty(), "queda 1 y sigue habiendo un recolector presente")
	e6.marcar_presente(1, false)
	var resto6: Dictionary = e6.recoger(ESQ, 20.0)
	assert(is_equal_approx(resto6["madera"], 1.0), "sin recolectores presentes se lleva lo que quede")
	assert(e6.almacen_local(ESQ).is_empty(), "el almacén queda vacío, sin claves en cero")
	assert(e6.recoger(ESQ, 20.0).is_empty(), "vacío: nada que llevar")
	assert(e6.recoger(Vector2i(0, 0), 20.0).is_empty(), "puesto inexistente")

	print("\n=== TEST 7: recoger() reparte la carga entre recursos sin pasarse ===")
	var e7: Node = _nueva(CiudadScript.new())
	e7.registrar_puesto(Vector2i(50, 50), "mina", 5, 5, {"hierro": 12.0, "piedra": 12.0})
	e7.asignar(Vector2i(50, 50), "recolector", 1)
	e7.marcar_presente(1, true)
	e7.simular_hora()
	e7.simular_hora()  # 24 hierro + 24 piedra = 48 en total
	var carga7: Dictionary = e7.recoger(Vector2i(50, 50), 20.0)
	var total7 := 0.0
	for v in carga7.values():
		total7 += v
	assert(is_equal_approx(total7, 20.0), "lleva exactamente la capacidad")
	var quedan7 := 0.0
	for v in e7.almacen_local(Vector2i(50, 50)).values():
		quedan7 += v
	assert(is_equal_approx(quedan7, 28.0))

	print("\n=== TEST 8: entregar() suma al stock central y respeta su límite ===")
	var ciudad8: Node = CiudadScript.new()
	var e8: Node = _nueva(ciudad8)
	var antes8: float = ciudad8.almacen["madera"].cantidad
	e8.entregar({"madera": 20.0, "tierras_raras": 4.0})
	assert(is_equal_approx(ciudad8.almacen["madera"].cantidad, antes8 + 20.0))
	assert(is_equal_approx(ciudad8.almacen["tierras_raras"].cantidad, 4.0))
	e8.entregar({"madera": 5000.0})
	assert(ciudad8.almacen["madera"].cantidad == ciudad8.almacen["madera"].limite, "lo que no cabe se pierde")

	print("\n=== TEST 9: quitar_puesto() libera a los trabajadores y avisa ===")
	var e9: Node = _nueva(CiudadScript.new())
	e9.asignar(ESQ, "recolector", 1)
	e9.asignar(ESQ, "acarreador", 2)
	var avisados := []
	e9.puesto_quitado.connect(func(ids: Array) -> void: avisados.append_array(ids))
	e9.quitar_puesto(ESQ)
	assert(not e9.tiene_puesto(ESQ))
	assert(avisados.size() == 2 and avisados.has(1) and avisados.has(2))
	assert(e9.asignar(Vector2i(0, 0), "recolector", 1) == false)
	e9.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0})
	assert(e9.asignar(ESQ, "recolector", 1), "los colonos liberados quedan libres para otro puesto")
	e9.quitar_puesto(Vector2i(0, 0))  # inexistente: no hace nada

	print("\n=== TEST 10: simular_hora() se dispara con Ciudad.tick_simulado ===")
	var ciudad10: Node = CiudadScript.new()
	ciudad10.migracion_activa = false
	var e10: Node = _nueva(ciudad10)
	e10._ready()  # conecta el tick (fuera del árbol no se llama solo)
	e10.asignar(ESQ, "recolector", 1)
	e10.marcar_presente(1, true)
	ciudad10.simular_tick(0.0)
	assert(is_equal_approx(e10.almacen_local(ESQ)["madera"], 3.0))

	print("\n=== Las 10 pruebas de Economia pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: FALLA (`Economia.gd` no existe → error al cargar el preload).

- [ ] **Step 3: Implementar**

Crear `godot/scripts/Economia.gd`:

```gdscript
extends Node

## Autoload "Economia": producción y acarreo de los puestos de recolección
## (sub-proyecto 2A, ver docs/superpowers/specs/2026-09-21-economia-puestos-
## produccion-acarreo-design.md). Estado y reglas puros, sin escena (mismo
## patrón que Ciudad.gd/Recoleccion.gd): guarda por puesto sus trabajadores,
## su almacén local y sus tasas, y produce una hora de juego por cada
## Ciudad.tick_simulado. El movimiento físico de los colonos (ir al puesto,
## recoger, llevar al núcleo) lo ejecuta Colonos.gd, que llama a
## marcar_presente(), recoger() y entregar(). "ciudad" es inyectable para
## probar sin escena (EconomiaTest.gd).

## Ids de los colonos que se quedaron sin puesto porque este se quitó
## (Colonos.gd los vuelve a desempleado).
signal puesto_quitado(ids: Array)

## Unidades que un acarreador lleva por viaje (placeholder sin balance real).
const CAPACIDAD_CARGA := 20.0

const ROLES := ["recolector", "acarreador"]

## Las tasas de un puesto usan las claves de Recoleccion.tasas_*(); estas cuatro
## son formas de obtener comida y se suman en el recurso "comida". El resto de
## claves (minerales, "madera") ya son el nombre del recurso.
const RECURSO_DE_TASA := {
	"caza": "comida", "recoleccion": "comida",
	"pesca": "comida", "frutos_mar": "comida",
}

var ciudad: Object = null  # Ciudad

## Vector2i (esquina de la huella) -> {"tipo", "ancho", "alto", "cupo",
## "capacidad", "tasas" (clave de tasa -> unidades por recolector y hora),
## "recolectores": Array[int], "acarreadores": Array[int],
## "presentes": Dictionary (id de recolector -> true),
## "almacen": Dictionary (recurso -> float)}.
var puestos: Dictionary = {}
## id de colono -> esquina del puesto donde trabaja.
var _puesto_de: Dictionary = {}


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	ciudad.tick_simulado.connect(simular_hora)


## Registra un puesto recién colocado, sin trabajadores. "tasas" son las de
## Recoleccion.tasas_*() calculadas al colocarlo (no se recalculan mientras no
## haya agotamiento de recursos).
func registrar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int, tasas: Dictionary) -> void:
	puestos[esquina] = {
		"tipo": tipo, "ancho": ancho, "alto": alto,
		"cupo": Recoleccion.cupo_de(tipo),
		"capacidad": Recoleccion.capacidad_almacen_de(tipo),
		"tasas": tasas.duplicate(),
		"recolectores": [], "acarreadores": [],
		"presentes": {}, "almacen": {},
	}


## Quita el puesto (se deconstruyó): su almacén local se pierde y sus
## trabajadores quedan libres; se avisa con puesto_quitado. No-op si no existe.
func quitar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var ids: Array = p["recolectores"] + p["acarreadores"]
	for id in ids:
		_puesto_de.erase(id)
	puestos.erase(esquina)
	puesto_quitado.emit(ids)


func tiene_puesto(esquina: Vector2i) -> bool:
	return puestos.has(esquina)


## Celdas (X,Z) de la huella del puesto; [] si no existe.
func huella_de(esquina: Vector2i) -> Array:
	if not puestos.has(esquina):
		return []
	var celdas: Array = []
	for dx in range(puestos[esquina]["ancho"]):
		for dz in range(puestos[esquina]["alto"]):
			celdas.append(Vector2i(esquina.x + dx, esquina.y + dz))
	return celdas


func cupo_libre(esquina: Vector2i) -> int:
	if not puestos.has(esquina):
		return 0
	var p: Dictionary = puestos[esquina]
	return p["cupo"] - p["recolectores"].size() - p["acarreadores"].size()


## Asigna un colono a un puesto con un rol. Falso si el puesto no existe, el
## rol no es válido, el cupo está lleno o el colono ya trabaja en algún puesto.
func asignar(esquina: Vector2i, rol: String, colono_id: int) -> bool:
	if not puestos.has(esquina) or not ROLES.has(rol) or _puesto_de.has(colono_id):
		return false
	if cupo_libre(esquina) <= 0:
		return false
	puestos[esquina]["recolectores" if rol == "recolector" else "acarreadores"].append(colono_id)
	_puesto_de[colono_id] = esquina
	return true


## Quita a un colono de su puesto (despido o muerte). No-op si no trabaja.
func liberar(colono_id: int) -> void:
	if not _puesto_de.has(colono_id):
		return
	var p: Dictionary = puestos[_puesto_de[colono_id]]
	p["recolectores"].erase(colono_id)
	p["acarreadores"].erase(colono_id)
	p["presentes"].erase(colono_id)
	_puesto_de.erase(colono_id)


## El último colono asignado con ese rol, o -1: a quien despide el panel.
func ultimo_de(esquina: Vector2i, rol: String) -> int:
	if not puestos.has(esquina):
		return -1
	var lista: Array = puestos[esquina]["recolectores" if rol == "recolector" else "acarreadores"]
	return lista.back() if not lista.is_empty() else -1


## Un recolector está (o deja de estar) en su puesto: solo entonces produce.
## Ignora a quien no sea recolector asignado.
func marcar_presente(colono_id: int, presente: bool) -> void:
	if not _puesto_de.has(colono_id):
		return
	var p: Dictionary = puestos[_puesto_de[colono_id]]
	if not p["recolectores"].has(colono_id):
		return
	if presente:
		p["presentes"][colono_id] = true
	else:
		p["presentes"].erase(colono_id)


func trabajadores_de(esquina: Vector2i) -> Dictionary:
	if not puestos.has(esquina):
		return {"recolectores": 0, "acarreadores": 0, "presentes": 0}
	var p: Dictionary = puestos[esquina]
	return {
		"recolectores": p["recolectores"].size(),
		"acarreadores": p["acarreadores"].size(),
		"presentes": p["presentes"].size(),
	}


## Unidades por hora de cada recurso con los recolectores presentes ahora.
func produccion_por_hora(esquina: Vector2i) -> Dictionary:
	var resultado: Dictionary = {}
	if not puestos.has(esquina):
		return resultado
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	for clave in p["tasas"]:
		var recurso: String = RECURSO_DE_TASA.get(clave, clave)
		resultado[recurso] = resultado.get(recurso, 0.0) + p["tasas"][clave] * presentes
	return resultado


func almacen_local(esquina: Vector2i) -> Dictionary:
	return puestos[esquina]["almacen"].duplicate() if puestos.has(esquina) else {}


static func _total(almacen: Dictionary) -> float:
	var total := 0.0
	for v in almacen.values():
		total += v
	return total


## Una hora de juego de producción en todos los puestos: cada recolector
## presente suma su tasa al almacén local. Si el total local llegaría a
## pasar de la capacidad, solo entra lo que cabe, en proporción (el exceso se
## pierde: la producción se frena contra el tope y avisa de que falta acarreo).
func simular_hora() -> void:
	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		var producido: Dictionary = produccion_por_hora(esquina)
		var total_producido := _total(producido)
		if total_producido <= 0.0:
			continue
		var espacio: float = p["capacidad"] - _total(p["almacen"])
		if espacio <= 0.0:
			continue
		var factor: float = minf(1.0, espacio / total_producido)
		for recurso in producido:
			p["almacen"][recurso] = p["almacen"].get(recurso, 0.0) + producido[recurso] * factor


## Un acarreador que está en el puesto pide su carga: hasta "capacidad"
## unidades, repartidas por recurso en el orden del almacén. Solo se la dan si
## el almacén ya tiene la carga completa, o si no hay recolectores presentes
## y queda algo (así ningún resto queda atascado ni se hacen viajes de una
## unidad mientras se sigue produciendo). {} si no se cumple.
func recoger(esquina: Vector2i, capacidad: float) -> Dictionary:
	if not puestos.has(esquina):
		return {}
	var p: Dictionary = puestos[esquina]
	var total := _total(p["almacen"])
	if total <= 1e-9:
		return {}
	if total < capacidad and not p["presentes"].is_empty():
		return {}
	var carga: Dictionary = {}
	var restante := capacidad
	for recurso in p["almacen"].keys():
		if restante <= 1e-9:
			break
		var tomado: float = minf(p["almacen"][recurso], restante)
		carga[recurso] = tomado
		restante -= tomado
		p["almacen"][recurso] -= tomado
		if p["almacen"][recurso] <= 1e-9:
			p["almacen"].erase(recurso)
	return carga


## Un acarreador llegó al núcleo urbano: suma su carga al stock central. Lo
## que no cabe (stock lleno) se pierde.
func entregar(carga: Dictionary) -> void:
	for recurso in carga:
		if ciudad.almacen.has(recurso):
			ciudad.almacen[recurso].agregar(carga[recurso])
```

En `godot/project.godot`, sección `[autoload]`, insertar entre `Recoleccion=...` y `Blueprints=...`... la posición no importa mientras esté antes de `Colonos`; dejar así:

```
Recoleccion="*res://scripts/Recoleccion.gd"
Economia="*res://scripts/Economia.gd"
Blueprints="*res://scripts/Blueprints.gd"
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: el comando del Step 2.
Expected: PASS — `=== Las 10 pruebas de Economia pasaron correctamente ===`.

Nota para el implementador: en el TEST 6 la producción del hora 3 acumula 9 y de la 7 acumula 21; si `recoger` devolviera carga con 9 (< 20) el assert falla, que es lo esperado por la regla "carga completa o sin recolectores presentes".

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd godot/scenes/EconomiaTest.tscn godot/project.godot
git commit -m "feat: autoload Economia con producción, almacén local y acarreo" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 4: `Colonos` — contratar, despedir y trabajar

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Test: `godot/scripts/ColonosTest.gd` (pruebas 18–23 y banner)

**Interfaces:**
- Consumes: `Economia.asignar/liberar/ultimo_de/marcar_presente/recoger/entregar/huella_de/tiene_puesto/cupo_libre`, `Economia.CAPACIDAD_CARGA`, signal `puesto_quitado` (Tarea 3); `Ciudad.reasignar_tipo` (Tarea 1); `Zonificacion.huella_del_nucleo()` (Tarea 2); `BuscadorRutas.buscar_ruta/es_transitable` (existentes).
- Produces:
  - `Colonos.economia: Object` (inyectable; por defecto el autoload `Economia`).
  - `Colonos.contratar(esquina: Vector2i, rol: String) -> bool` y `Colonos.despedir(esquina: Vector2i, rol: String) -> bool`.
  - Cada colono lleva ahora las claves `"trabajo"` (`{}` o `{"puesto": Vector2i, "rol": String}`), `"carga"` (`Dictionary`) y `"fase"` (`String`: `""`/`"recoger"`/`"entregar"`).

Comportamiento (spec Sección 3): un colono con `trabajo` no deambula. *Recolector:* camina a una celda transitable junto a la huella de su puesto y se queda ahí, marcándose presente. *Acarreador:* ciclo `recoger` (en el puesto, `Economia.recoger`; si viene vacío espera 1 s y reintenta) → camina al núcleo → `Economia.entregar` → vuelve. Al llegar no espera el 1–3 s del deambular. Un colono que empieza a dar un paso deja de estar presente.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `godot/scripts/ColonosTest.gd`:

a) Añadir bajo los `const ... preload` del inicio:

```gdscript
const EconomiaScript = preload("res://scripts/Economia.gd")
```

b) Añadir a `ZonaFalsa` (clase de prueba existente) el método:

```gdscript
	## Núcleo urbano falso: un bloque de 2x2 en (7,7)-(8,8).
	func huella_del_nucleo() -> Array:
		return [Vector2i(7, 7), Vector2i(8, 7), Vector2i(7, 8), Vector2i(8, 8)]
```

c) Añadir junto a `_nuevo()` un ayudante:

```gdscript
## Colonos con una Economia real (ciudad inyectada) y un maderero de 2x2 en
## (2, 2) con tasa 3 madera/h; mundo llano de 10x10 y el núcleo en (7..8, 7..8).
func _nuevo_con_puesto(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(Vector2i(2, 2), "maderero", 2, 2, {"madera": 3.0})
	var colonos: Node = _nuevo(_mundo_llano(), ciudad)
	colonos.economia = economia
	return colonos
```

d) Sustituir la última línea (banner de 17) por:

```gdscript
	print("\n=== TEST 18: contratar() convierte a un desempleado en obrero asignado al puesto ===")
	var ciudad18: Node = CiudadScript.new()
	var colonos18: Node = _nuevo_con_puesto(ciudad18)
	ciudad18.demografia["desempleado"] = 2
	colonos18.reconciliar()
	assert(colonos18.contratar(Vector2i(2, 2), "recolector"))
	assert(ciudad18.demografia["desempleado"] == 1 and ciudad18.demografia["obrero"] == 1)
	assert(_contar(colonos18, "obrero") == 1 and _contar(colonos18, "desempleado") == 1)
	var trabajador18: Dictionary = {}
	for c in colonos18.colonos.values():
		if c["tipo"] == "obrero":
			trabajador18 = c
	assert(trabajador18["trabajo"] == {"puesto": Vector2i(2, 2), "rol": "recolector"})
	assert(colonos18.economia.trabajadores_de(Vector2i(2, 2))["recolectores"] == 1)
	colonos18.reconciliar()  # la demografía y los colonos siguen coincidiendo: no crea ni retira
	assert(colonos18.colonos.size() == 2)
	assert(not colonos18.contratar(Vector2i(99, 99), "recolector"), "puesto inexistente")
	assert(colonos18.contratar(Vector2i(2, 2), "acarreador"))
	assert(not colonos18.contratar(Vector2i(2, 2), "acarreador"), "ya no quedan desempleados")
	assert(ciudad18.demografia["obrero"] == 2 and ciudad18.demografia["desempleado"] == 0)

	print("\n=== TEST 19: despedir() devuelve al último a desempleado y libera el cupo ===")
	assert(colonos18.despedir(Vector2i(2, 2), "acarreador"))
	assert(ciudad18.demografia["desempleado"] == 1 and ciudad18.demografia["obrero"] == 1)
	assert(colonos18.economia.trabajadores_de(Vector2i(2, 2))["acarreadores"] == 0)
	assert(not colonos18.despedir(Vector2i(2, 2), "acarreador"), "no queda ninguno")
	var despedido19: int = -1
	for c in colonos18.colonos.values():
		if c["tipo"] == "desempleado":
			despedido19 = c["id"]
	assert(colonos18.colonos[despedido19]["trabajo"].is_empty())

	print("\n=== TEST 20: un recolector camina a su puesto, queda presente y produce ===")
	var ciudad20: Node = CiudadScript.new()
	var colonos20: Node = _nuevo_con_puesto(ciudad20)
	var id20: int = colonos20.agregar_colono("desempleado", Vector3i(6, 1, 1))
	ciudad20.demografia["desempleado"] = 1
	assert(colonos20.contratar(Vector2i(2, 2), "recolector"))
	var c20: Dictionary = colonos20.colonos[id20]
	var llego20 := false
	for i in range(400):
		colonos20.avanzar(0.1)
		if colonos20.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 1:
			llego20 = true
			break
	assert(llego20, "llega junto al puesto y se marca presente")
	assert(absi(c20["celda"].x - 2) <= 2 and absi(c20["celda"].z - 2) <= 2, "está junto a la huella 2x2 de (2,2)")
	assert(not (c20["celda"].x in [2, 3] and c20["celda"].z in [2, 3]), "no está dentro de la huella")
	colonos20.economia.simular_hora()
	assert(is_equal_approx(colonos20.economia.almacen_local(Vector2i(2, 2))["madera"], 3.0))
	for i in range(100):  # se queda ahí: no deambula
		colonos20.avanzar(0.1)
	assert(colonos20.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 1, "sigue en su puesto")

	print("\n=== TEST 21: un acarreador lleva la carga al núcleo y la entrega ===")
	var ciudad21: Node = CiudadScript.new()
	var colonos21: Node = _nuevo_con_puesto(ciudad21)
	var madera_inicial: float = ciudad21.almacen["madera"].cantidad
	colonos21.economia.puestos[Vector2i(2, 2)]["almacen"]["madera"] = 30.0  # almacén local con carga de sobra
	var id21: int = colonos21.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad21.demografia["desempleado"] = 1
	assert(colonos21.contratar(Vector2i(2, 2), "acarreador"))
	var entregado21 := false
	for i in range(1500):  # hasta 150 s de juego
		colonos21.avanzar(0.1)
		if ciudad21.almacen["madera"].cantidad > madera_inicial:
			entregado21 = true
			break
	assert(entregado21, "el acarreador entrega en el núcleo")
	assert(is_equal_approx(ciudad21.almacen["madera"].cantidad, madera_inicial + 20.0), "una carga de 20")
	assert(is_equal_approx(colonos21.economia.almacen_local(Vector2i(2, 2))["madera"], 10.0), "quedan 10 en el puesto")
	assert(colonos21.colonos[id21]["carga"].is_empty(), "ya no lleva nada")

	print("\n=== TEST 22: retirar a un trabajador (o quitar su puesto) lo libera ===")
	var ciudad22: Node = CiudadScript.new()
	var colonos22: Node = _nuevo_con_puesto(ciudad22)
	ciudad22.demografia["desempleado"] = 2
	colonos22.reconciliar()
	colonos22.contratar(Vector2i(2, 2), "recolector")
	colonos22.contratar(Vector2i(2, 2), "acarreador")
	assert(colonos22.economia.cupo_libre(Vector2i(2, 2)) == 3)
	var obrero22: int = -1
	for c in colonos22.colonos.values():
		if c["trabajo"].get("rol", "") == "acarreador":
			obrero22 = c["id"]
	colonos22._retirar(obrero22)
	assert(colonos22.economia.cupo_libre(Vector2i(2, 2)) == 4, "retirarlo libera su cupo")
	colonos22.economia.quitar_puesto(Vector2i(2, 2))
	for c in colonos22.colonos.values():
		assert(c["trabajo"].is_empty() and c["tipo"] == "desempleado", "al quitarse el puesto, vuelve a desempleado")
	# El acarreador retirado con _retirar() no se descontó de la demografía (solo se
	# probó la liberación); el recolector devuelto pasó de obrero a desempleado.
	assert(ciudad22.demografia["obrero"] == 1 and ciudad22.demografia["desempleado"] == 1)

	print("\n=== TEST 23: la evacuación de una obra tiene prioridad sobre el trabajo ===")
	var ciudad23: Node = CiudadScript.new()
	var mundo23 := _mundo_llano()
	for x in range(3, 6):
		for z in range(3, 6):
			mundo23.poner_fantasma(Vector3i(x, 1, z), 7)
			mundo23.poner_fantasma(Vector3i(x, 2, z), 7)
	mundo23.volumenes[7] = {"min": Vector3i(3, 1, 3), "max": Vector3i(5, 2, 5)}
	var economia23: Node = EconomiaScript.new()
	economia23.ciudad = ciudad23
	economia23.registrar_puesto(Vector2i(0, 0), "maderero", 2, 2, {"madera": 3.0})
	var colonos23: Node = _nuevo(mundo23, ciudad23)
	colonos23.economia = economia23
	var id23: int = colonos23.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad23.demografia["desempleado"] = 1
	assert(colonos23.contratar(Vector2i(0, 0), "recolector"))
	colonos23._on_obra_a_fantasma(7)
	assert(colonos23.colonos[id23]["evacuando"] == 7)
	var salio23 := false
	for i in range(100):
		colonos23.avanzar(0.1)
		if colonos23.colonos[id23]["evacuando"] == -1:
			salio23 = true
			break
	assert(salio23 and not mundo23.celda_en_volumen(7, colonos23.colonos[id23]["celda"]), "sale de la obra aunque tenga trabajo")

	print("\n=== Las 23 pruebas de Colonos pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: FALLA (`economia`/`contratar` inexistentes → SCRIPT ERROR o Parse Error).

- [ ] **Step 3: Implementar**

En `godot/scripts/Colonos.gd`:

1. Constantes nuevas, tras `PROBABILIDAD_CASA`:

```gdscript
const ESPERA_TRABAJO := 1.0  # segundos que espera un recolector/acarreador antes de volver a decidir
const INTENTOS_SERVICIO := 6  # celdas junto a una huella que se prueban al buscar ruta
```

2. Propiedad `economia` tras `var zona: Object = null`:

```gdscript
var economia: Object = null:  # Economia
	set(valor):
		if economia != null and economia.puesto_quitado.is_connected(_on_puesto_quitado):
			economia.puesto_quitado.disconnect(_on_puesto_quitado)
		economia = valor
		if valor != null:
			valor.puesto_quitado.connect(_on_puesto_quitado)
```

3. En `_ready`, añadir tras `if zona == null: zona = Zonificacion`:

```gdscript
	if economia == null:
		economia = Economia
```

4. En el diccionario de `agregar_colono`, añadir las tres claves nuevas tras `"evacuando": -1, "ruta_de_evacuacion": false,`:

```gdscript
		"trabajo": {}, "carga": {}, "fase": "",
```

y actualizar el comentario del diccionario `colonos` con `"trabajo", "carga", "fase"`.

5. En `_retirar`, tras `var colono: Dictionary = colonos[id]`:

```gdscript
	if not colono["trabajo"].is_empty():
		economia.liberar(id)
```

6. En `_avanzar_colono`, sustituir el bloque `if c["ruta"].is_empty(): _elegir_destino(c); return` por:

```gdscript
	if c["ruta"].is_empty():
		if c["trabajo"].is_empty():
			_elegir_destino(c)
		else:
			_decidir_trabajo(c)
		return
```

7. En `_iniciar_paso`, tras `c["moviendo"] = true` añadir:

```gdscript
	if not c["trabajo"].is_empty():
		economia.marcar_presente(c["id"], false)  # se aleja del puesto: deja de producir
```

8. En `_completar_paso`, sustituir el `if c["ruta"].is_empty(): c["espera"] = ...` final por:

```gdscript
	if c["ruta"].is_empty() and c["trabajo"].is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
```

(un trabajador que llega no espera el 1–3 s del deambular).

9. Añadir al final del archivo (o tras `_elegir_destino`):

```gdscript
## Contrata a un desempleado (el de id menor) para un puesto con un rol
## ("recolector" o "acarreador"): pasa a obrero en Ciudad.demografia y en el
## colono. Falso si no hay desempleados, el puesto no existe o no tiene cupo.
func contratar(esquina: Vector2i, rol: String) -> bool:
	var desempleados: Array[int] = _ids_de_tipo("desempleado")
	if desempleados.is_empty():
		return false
	desempleados.sort()
	var id: int = desempleados[0]
	if not economia.asignar(esquina, rol, id):
		return false
	ciudad.reasignar_tipo("desempleado", "obrero")
	var c: Dictionary = colonos[id]
	c["tipo"] = "obrero"
	c["trabajo"] = {"puesto": esquina, "rol": rol}
	c["fase"] = ""
	c["carga"] = {}
	_dejar_lo_que_hacia(c)
	return true


## Despide al último colono contratado con ese rol en el puesto; vuelve a
## desempleado y pierde lo que llevara. Falso si no hay ninguno.
func despedir(esquina: Vector2i, rol: String) -> bool:
	var id: int = economia.ultimo_de(esquina, rol)
	if id == -1 or not colonos.has(id):
		return false
	economia.liberar(id)
	_volver_a_desempleado(colonos[id])
	return true


## El puesto se quitó (se deconstruyó): sus trabajadores ya fueron liberados en
## Economia; aquí solo vuelven a desempleado. Conectada a Economia.puesto_quitado.
func _on_puesto_quitado(ids: Array) -> void:
	for id in ids:
		if colonos.has(id):
			_volver_a_desempleado(colonos[id])


func _volver_a_desempleado(c: Dictionary) -> void:
	c["trabajo"] = {}
	c["carga"] = {}
	c["fase"] = ""
	c["tipo"] = "desempleado"
	ciudad.reasignar_tipo("obrero", "desempleado")
	_dejar_lo_que_hacia(c)


## Abandona la ruta en curso (si no está a medio paso) para que el colono
## decida de nuevo con su oficio nuevo o sin él.
func _dejar_lo_que_hacia(c: Dictionary) -> void:
	if c["moviendo"] or c["evacuando"] != -1:
		return  # termina el paso o la evacuación y decide después
	var vacia: Array[Vector3i] = []
	c["ruta"] = vacia
	c["espera"] = 0.0


## Lo que hace un trabajador cuando está quieto, sin ruta ni espera: un
## recolector va a su puesto y se queda (presente); un acarreador cicla
## puesto -> núcleo -> puesto.
func _decidir_trabajo(c: Dictionary) -> void:
	var esquina: Vector2i = c["trabajo"]["puesto"]
	var huella_puesto: Array = economia.huella_de(esquina)
	if huella_puesto.is_empty():
		c["espera"] = ESPERA_TRABAJO  # el puesto ya no existe: Economia avisará
		return
	if c["trabajo"]["rol"] == "recolector":
		if _junto_a(c["celda"], huella_puesto):
			economia.marcar_presente(c["id"], true)
			c["espera"] = ESPERA_TRABAJO
		else:
			_ir_junto_a(c, huella_puesto)
		return
	var huella_nucleo: Array = zona.huella_del_nucleo()
	if c["fase"] == "entregar":
		if _junto_a(c["celda"], huella_nucleo):
			economia.entregar(c["carga"])
			c["carga"] = {}
			c["fase"] = "recoger"
		else:
			_ir_junto_a(c, huella_nucleo)
		return
	# fase "" o "recoger": ir al puesto y pedir la carga.
	if not _junto_a(c["celda"], huella_puesto):
		_ir_junto_a(c, huella_puesto)
		return
	var carga: Dictionary = economia.recoger(esquina, economia.CAPACIDAD_CARGA)
	if carga.is_empty():
		c["espera"] = ESPERA_TRABAJO  # todavía no hay carga (o nada que llevar)
		return
	c["carga"] = carga
	c["fase"] = "entregar"


## true si "celda" está en la columna pegada (4 direcciones) a alguna celda de
## la huella y no dentro de ella.
func _junto_a(celda: Vector3i, huella: Array) -> bool:
	var xz := Vector2i(celda.x, celda.z)
	if huella.has(xz):
		return false
	for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if huella.has(xz + direccion):
			return true
	return false


## Celdas transitables en el anillo que rodea una huella (una por columna,
## sobre la superficie).
func _celdas_junto_a(huella: Array) -> Array[Vector3i]:
	var vistas := {}
	var celdas: Array[Vector3i] = []
	for celda: Vector2i in huella:
		for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var vecina: Vector2i = celda + direccion
			if huella.has(vecina) or vistas.has(vecina):
				continue
			vistas[vecina] = true
			var altura: int = mundo.altura_en(vecina.x, vecina.y)
			if altura < 0:
				continue
			var candidata := Vector3i(vecina.x, altura + 1, vecina.y)
			if _buscador.es_transitable(candidata):
				celdas.append(candidata)
	return celdas


## Planifica una ruta hasta la celda libre más cercana junto a la huella; si
## ninguna de las INTENTOS_SERVICIO más cercanas es alcanzable, espera y reintenta.
func _ir_junto_a(c: Dictionary, huella: Array) -> void:
	var candidatas: Array[Vector3i] = _celdas_junto_a(huella)
	var origen: Vector3i = c["celda"]
	candidatas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return (a - origen).length_squared() < (b - origen).length_squared())
	var opciones := _opciones_ruta(c)
	for i in range(mini(candidatas.size(), INTENTOS_SERVICIO)):
		var ruta: Array[Vector3i] = _buscador.buscar_ruta(origen, candidatas[i], opciones)
		if not ruta.is_empty():
			c["ruta"] = ruta
			return
	c["espera"] = ESPERA_TRABAJO
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `ColonosTest.tscn` con `--quit-after 300`, y además `EconomiaTest.tscn`, `BuscadorRutasTest.tscn`, `FantasmasPermeablesTest.tscn` (`--quit-after 3000`) para descartar regresiones en el comportamiento de los colonos.
Expected: PASS — `Las 23 pruebas de Colonos`, `Las 10 pruebas de Economia`, y sin cambios en las otras.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: colonos trabajadores (recolectores y acarreadores de puestos)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 5: Integración — registrar y quitar puestos con sus tasas

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd` (`_procesar_clic_puesto`, ~líneas 1483-1562; función nueva `_tasas_de_puesto`)
- Modify: `godot/scripts/Player.gd` (~línea 491)

**Interfaces:**
- Consumes: `Economia.registrar_puesto(esquina, tipo, ancho, alto, tasas)`, `Economia.quitar_puesto(esquina)` (Tarea 3); `Recoleccion.tasas_*`/`detectar_*` (existentes con las tasas de la Tarea 2).
- Produces: cada puesto colocado queda registrado en `Economia` con las tasas de su área; al deconstruirlo por completo se quita.

Sin prueba unitaria (usa `mundo`/cámara reales); se verifica al arrancar `Main.tscn` (Tarea 8) y a mano.

- [ ] **Step 1: Añadir `_tasas_de_puesto` a `CamaraCenital.gd`**

Insertar justo antes de `func _procesar_clic_puesto(`:

```gdscript
## Tasas por trabajador y hora del puesto activo en "centro" (las mismas
## funciones y áreas que usa la previsualización), para guardarlas en Economia
## al colocarlo. Hay que llamarla ANTES de nivelar/marcar el terreno: la mina
## cuenta los bloques reales del área.
func _tasas_de_puesto(centro: Vector2i, esquina: Vector2i, extremo_agua_indice: int) -> Dictionary:
	if _tipo_puesto_activo == "mina":
		var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, mundo.altura_en(centro.x, centro.y))
		return Recoleccion.tasas_recoleccion(conteo)
	if _tipo_puesto_activo == "caza_recoleccion":
		return Recoleccion.tasas_caza_recoleccion(Recoleccion.detectar_fauna_frutal(mundo.generador, centro))
	if _tipo_puesto_activo == "pesca_frutos_mar":
		var celdas_extremo := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
		@warning_ignore("integer_division")
		var centro_agua := esquina + celdas_extremo[celdas_extremo.size() / 2]
		var celdas_agua: Dictionary = Recoleccion.celdas_agua_conectadas(mundo.generador, centro_agua, Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)
		return Recoleccion.tasas_pesca_frutos_mar(Recoleccion.detectar_pesca_frutos_mar(mundo.generador, celdas_agua))
	return Recoleccion.tasa_maderero(Recoleccion.detectar_arbol(mundo.generador, centro))


```

- [ ] **Step 2: Calcularlas al colocar y registrar el puesto**

En `_procesar_clic_puesto`, justo antes de `for celda_follaje in resultado_huella["follaje_a_eliminar"]:` insertar:

```gdscript
	var tasas_puesto: Dictionary = _tasas_de_puesto(centro, esquina, extremo_agua_indice)

```

y tras la línea `Recoleccion.colocar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo)` añadir:

```gdscript
	Economia.registrar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo, tasas_puesto)
```

- [ ] **Step 3: Quitar el puesto al deconstruir**

En `godot/scripts/Player.gd`, tras `Recoleccion.quitar_puesto(esquina)` (línea ~491) añadir:

```gdscript
		Economia.quitar_puesto(esquina)  # libera a sus trabajadores (no-op si era un edificio)
```

- [ ] **Step 4: Verificar que carga sin errores**

Run: `"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion"`
Expected: sin salida (Main arranca limpio).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/CamaraCenital.gd godot/scripts/Player.gd
git commit -m "feat: registrar los puestos en Economia con sus tasas y quitarlos al deconstruir" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 6: Panel del puesto, clic en la cenital y lista de recursos

**Files:**
- Create: `godot/scripts/PanelPuesto.gd`
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scenes/Main.tscn` (quitar 5 etiquetas de comida/crítico)
- Modify: `godot/scripts/CamaraCenital.gd` (`_procesar_clic`, `salir_de_todos_los_modos`)

**Interfaces:**
- Consumes: `Recoleccion.esquina_de_puesto_en`, `Recoleccion.SIN_PUESTO` (Tarea 2); `Economia.puestos/trabajadores_de/almacen_local/produccion_por_hora/cupo_libre/tiene_puesto` (Tarea 3); `Colonos.contratar/despedir` (Tarea 4); `Ciudad.almacen`, `Ciudad.demografia`.
- Produces: `HUD.abrir_panel_puesto(esquina: Vector2i)`, `HUD.cerrar_panel_puesto()`; el HUD muestra los 8 recursos de `Ciudad.almacen` (cantidad / límite y tasa por tick).

Interfaz por código (sin `.tscn` nuevo) para no tocar a mano escenas; verificación visual manual en el editor.

- [ ] **Step 1: Crear `PanelPuesto.gd`**

```gdscript
extends PanelContainer

## Panel de un puesto de recolección (clic izquierdo sobre él en la cenital,
## ver CamaraCenital._procesar_clic). Se construye por código: título, filas
## "Recolectores [-] n [+]" y "Acarreadores [-] n [+]", desempleados libres,
## almacén local, producción y distancia al núcleo. Las reglas viven en
## Economia/Colonos; esto solo las muestra y les pasa los clics.

const NOMBRES_PUESTO := {
	"mina": "Mina",
	"caza_recoleccion": "Caza y recolección",
	"maderero": "Puesto maderero",
	"pesca_frutos_mar": "Pesca y frutos del mar",
}

var esquina := Recoleccion.SIN_PUESTO

var _titulo := Label.new()
var _trabajadores := Label.new()
var _libres := Label.new()
var _almacen := Label.new()
var _produccion := Label.new()
var _distancia := Label.new()
var _filas := {}  # rol -> {"cantidad": Label, "menos": Button, "mas": Button}


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -280.0
	offset_top = 12.0
	offset_right = -12.0
	var caja := VBoxContainer.new()
	add_child(caja)
	caja.add_child(_titulo)
	for rol in ["recolector", "acarreador"]:
		caja.add_child(_crear_fila(rol))
	for etiqueta in [_trabajadores, _libres, _almacen, _produccion, _distancia]:
		caja.add_child(etiqueta)


func _crear_fila(rol: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = "Recolectores" if rol == "recolector" else "Acarreadores"
	nombre.custom_minimum_size.x = 110.0
	var menos := Button.new()
	menos.text = "-"
	menos.pressed.connect(func() -> void: Colonos.despedir(esquina, rol))
	var cantidad := Label.new()
	cantidad.custom_minimum_size.x = 24.0
	cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mas := Button.new()
	mas.text = "+"
	mas.pressed.connect(func() -> void: Colonos.contratar(esquina, rol))
	for nodo in [nombre, menos, cantidad, mas]:
		fila.add_child(nodo)
	_filas[rol] = {"cantidad": cantidad, "menos": menos, "mas": mas}
	return fila


func abrir(nueva_esquina: Vector2i) -> void:
	esquina = nueva_esquina
	visible = true
	_actualizar()


func cerrar() -> void:
	visible = false
	esquina = Recoleccion.SIN_PUESTO


func _process(_delta: float) -> void:
	if not visible:
		return
	if not Economia.tiene_puesto(esquina):
		cerrar()  # el puesto se deconstruyó con el panel abierto
		return
	_actualizar()


func _actualizar() -> void:
	var puesto: Dictionary = Economia.puestos[esquina]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var libres: int = Ciudad.demografia["desempleado"]
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"])
	_filas["recolector"]["cantidad"].text = str(t["recolectores"])
	_filas["acarreador"]["cantidad"].text = str(t["acarreadores"])
	_filas["recolector"]["menos"].disabled = t["recolectores"] == 0
	_filas["acarreador"]["menos"].disabled = t["acarreadores"] == 0
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0 or libres <= 0
	_filas["recolector"]["mas"].disabled = sin_cupo
	_filas["acarreador"]["mas"].disabled = sin_cupo
	_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	_libres.text = "Desempleados libres: %d" % libres
	_almacen.text = "Almacén local: " + _texto_recursos(Economia.almacen_local(esquina), "vacío") + " (máx. %d)" % puesto["capacidad"]
	_produccion.text = "Producción: " + _texto_recursos(Economia.produccion_por_hora(esquina), "ninguna", "/h")
	_distancia.text = "Distancia al núcleo: %s" % _distancia_al_nucleo()


static func _texto_recursos(recursos: Dictionary, vacio: String, sufijo: String = "") -> String:
	var partes: Array = []
	for recurso in recursos:
		partes.append("%.1f %s%s" % [recursos[recurso], recurso, sufijo])
	return ", ".join(partes) if not partes.is_empty() else vacio


## Celdas (en línea recta sobre X,Z) entre el centro del puesto y el centro del
## núcleo; "-" si todavía no hay núcleo.
func _distancia_al_nucleo() -> String:
	var nucleo: Array = Zonificacion.huella_del_nucleo()
	if nucleo.is_empty():
		return "-"
	var suma := Vector2.ZERO
	for celda: Vector2i in nucleo:
		suma += Vector2(celda)
	var centro_nucleo: Vector2 = suma / nucleo.size()
	var puesto: Dictionary = Economia.puestos[esquina]
	var centro_puesto := Vector2(esquina) + Vector2(puesto["ancho"], puesto["alto"]) / 2.0
	return "%d celdas" % roundi(centro_nucleo.distance_to(centro_puesto))
```

- [ ] **Step 2: `HUD.gd` — panel y lista de recursos**

En `godot/scripts/HUD.gd`:

a) Sustituir `NOMBRES_RECURSO` por:

```gdscript
const NOMBRES_RECURSO := {
	"comida": "Comida",
	"madera": "Madera",
	"hierro": "Hierro",
	"tierra": "Tierra",
	"piedra": "Piedra",
	"cobre": "Cobre",
	"carbon": "Carbón",
	"tierras_raras": "Tierras raras",
}

const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")
```

b) Quitar las 5 líneas `@onready var comida_stock_label ... critico_tasa_label` y añadir:

```gdscript
@onready var recursos_lista: VBoxContainer = $HUD

var _recursos_labels := {}  # clave de Ciudad.almacen -> Label
var _panel_puesto: PanelContainer
```

(la lista se crea dentro del propio `$HUD` VBox, tras la línea de moral).

c) Añadir `_ready`:

```gdscript
func _ready() -> void:
	# Lista de control de recursos: una fila por recurso del almacén central.
	for clave in Ciudad.almacen:
		var etiqueta := Label.new()
		recursos_lista.add_child(etiqueta)
		_recursos_labels[clave] = etiqueta
	_panel_puesto = PanelPuestoScript.new()
	add_child(_panel_puesto)
```

d) En `_process`, sustituir desde `_actualizar_recurso("comida", ...)` hasta el final (incluye el bloque de `clave_critica`) por:

```gdscript
	for clave in _recursos_labels:
		_actualizar_recurso(clave, _recursos_labels[clave])
```

e) Reemplazar `_actualizar_recurso` por:

```gdscript
func _actualizar_recurso(clave: String, etiqueta: Label) -> void:
	var recurso = Ciudad.almacen[clave]
	var tasa: float = recurso.tasa_neta
	var signo := "+" if tasa >= 0 else ""
	etiqueta.text = "  %s: %.0f / %.0f  (%s%.1f /tick)" % [NOMBRES_RECURSO.get(clave, clave), recurso.cantidad, recurso.limite, signo, tasa]
	etiqueta.modulate = COLOR_POSITIVO if tasa >= 0 else COLOR_NEGATIVO
```

f) Añadir al final del archivo:

```gdscript
func abrir_panel_puesto(esquina: Vector2i) -> void:
	_panel_puesto.abrir(esquina)


func cerrar_panel_puesto() -> void:
	_panel_puesto.cerrar()
```

Actualizar el comentario de cabecera del archivo: "comida + recurso crítico" → "lista de los recursos del almacén con su tasa neta".

- [ ] **Step 3: `Main.tscn` — quitar las etiquetas viejas**

En `godot/scenes/Main.tscn`, borrar los bloques de nodo `ComidaStockLabel`, `ComidaTasaLabel`, `CriticoNombreLabel`, `CriticoStockLabel`, `CriticoTasaLabel` (líneas ~81-99: cada bloque son las 3-4 líneas desde `[node name="..." ...]` hasta la línea en blanco), y en el nodo `HUD` cambiar `offset_bottom = 140.0` por `offset_bottom = 300.0`. No tocar nada más del archivo.

- [ ] **Step 4: `CamaraCenital.gd` — clic sobre un puesto**

Sustituir el inicio de `_procesar_clic` por:

```gdscript
func _procesar_clic(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if not esperando_segunda_esquina:
		# Sin un rectángulo de zona a medias, un clic sobre un puesto de trabajo
		# abre su panel; en cualquier otro sitio lo cierra y empieza la zona.
		var esquina_puesto := Recoleccion.esquina_de_puesto_en(celda)
		if esquina_puesto != Recoleccion.SIN_PUESTO:
			hud.abrir_panel_puesto(esquina_puesto)
			return
		hud.cerrar_panel_puesto()
		primera_esquina = celda
```

(conservando el resto de esa rama: `esperando_segunda_esquina = true`, el `print`, `overlay.previsualizar(...)` y `return`), y en `salir_de_todos_los_modos()` añadir al final `hud.cerrar_panel_puesto()`.

- [ ] **Step 5: Verificar que arranca y no hay errores de script**

Run: `"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"`
Expected: sin salida. Además comprobar que ninguna otra cosa usa las etiquetas quitadas: `grep -rn "comida_stock_label\|critico_" godot/scripts` debe dar vacío.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/PanelPuesto.gd godot/scripts/HUD.gd godot/scenes/Main.tscn godot/scripts/CamaraCenital.gd
git commit -m "feat: panel del puesto, clic en la cenital y lista de control de recursos" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 7: Verificación completa de la suite

**Files:** ninguno (solo ejecutar; corregir en la tarea correspondiente si algo falla).

- [ ] **Step 1: Ejecutar todas las escenas de prueba**

Desde la raíz, en bash (usa `$GD` definido arriba):

```bash
for t in Test BlueprintsTest BuscadorRutasTest CadenaMineralesTest CiudadTest ColonosTest ConstruccionTest EconomiaTest GeneradorArbolTest GeneradorMundoTest NiveladorTerrenoTest PlayerNatacionTest PlayerOxigenoTest RecoleccionTest TranslucidosRendererTest ZonificacionTest; do
  echo "== $t"; "$GD" --headless --path godot res://scenes/$t.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
done
echo "== FantasmasPermeablesTest"; "$GD" --headless --path godot res://scenes/FantasmasPermeablesTest.tscn --quit-after 3000 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
echo "== Main"; "$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion"
```

Expected: cada suite imprime su línea `pasaron correctamente` (Ciudad 20, Colonos 23, Economia 10, Recoleccion 20, Zonificacion 14; el resto con sus conteos de antes: Blueprints 4, BuscadorRutas 17, CadenaMinerales 8, Construccion 6, FantasmasPermeables 8, GeneradorArbol 11, GeneradorMundo 33, NiveladorTerreno 20, PlayerNatacion 9, PlayerOxigeno 4, Test 63, TranslucidosRenderer) y `Main` no imprime nada. Una escena que solo tenga una línea de error se investiga antes de seguir; no se ajustan aserciones para hacerlas pasar.

---

### Task 8: Documentación (GDD, Excel y fichas) y verificación manual

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (subir a la versión 3.34)
- Create: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md`
- Modify: `docs/Recursos.xlsx` (hojas `Niveles` corregida, `Puestos` y `Economia` nuevas)
- Modify: `docs/Fichas_Consumo_Produccion.md`
- Do **not** modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md` (trabajo en curso del usuario) ni `docs/Pendientes y próximos pasos.md`.

**Aviso sobre el worktree:** `docs/Recursos.xlsx` y `docs/Fichas_Consumo_Produccion.md` están **sin versionar** en el árbol principal (`C:\Users\peraz\Projects\Misc\CityCraft`), así que no existen en un worktree nuevo. En los pasos 4 y 5, copiarlos desde el árbol principal al worktree (`cp <árbol principal>/docs/Recursos.xlsx docs/`), editarlos ahí y commitearlos en la rama (pasan a estar versionados por primera vez). **Al mergear a `main`**, quien mergee debe antes mover fuera del árbol principal esas dos copias sin versionar (se reemplazan por las de la rama; Git se negaría a sobrescribirlas) y confirmar con el usuario que no tenía cambios propios pendientes en ellas.

- [ ] **Step 1: GDD 3.34**

Leer las secciones del GDD que hablan de puestos de recolección, producción y acarreo (buscar `Puesto`, `Producción`, `acarreo`, y el encabezado de versión/historial) y: (a) subir la versión a 3.34 en su historial con una línea "Los puestos de recolección producen recursos reales: el jugador asigna recolectores y acarreadores desde un panel (clic en el puesto, cenital); cupos maderero 5, caza/recolección 7, pesca 7, mina 5; los acarreadores llevan la carga a pie hasta el núcleo urbano, que es el almacén central; el almacén central guarda 8 recursos"; (b) describir el mismo flujo en la sección de puestos, sin borrar lo que no cambia. Mantener el español y el estilo del documento.

- [ ] **Step 2: Documento técnico nuevo de la PoC 5, fase 2A**

Crear el archivo indicado con: objetivo; arquitectura (`Economia.gd`, `Colonos.gd`, `PanelPuesto.gd`, cambios en `Ciudad`/`Recoleccion`/`Zonificacion`/`CamaraCenital`/`HUD`); tabla de constantes y placeholders (cupos 5/7/7/5, almacén local 100, `CAPACIDAD_CARGA` 20, tasas del Excel con la de frutos marcada como interpretación de la columna "Árbol (obj)", stock 1000/2000); reglas (producción solo con recolectores presentes, tope y pérdida, `recoger` con carga completa o sin recolectores presentes, `entregar` con pérdida por stock lleno); balance esperado (un acarreador mueve unas 1,25 unidades/h a 40 celdas frente a 5-15 unidades/h de un recolector); y "fuera de alcance / siguiente" (2B extracción física y agotamiento, 2C transformación, moral/nivel del puesto y drones futuros). Basarlo en el spec `docs/superpowers/specs/2026-09-21-economia-puestos-produccion-acarreo-design.md`.

- [ ] **Step 3: Confirmar contra el código los valores que irán al Excel y a las fichas**

Antes de escribir números en el Excel o en las fichas, releer en el código ya implementado (no de memoria): `Recoleccion.gd` (`TASAS_BASE_MINERAL`, `TASA_BASE_*_POR_CIUDADANO`, `PERSONAL_MAXIMO*`, `CAPACIDAD_ALMACENAMIENTO*`, `ANCHO_/ALTO_HUELLA_*`, `RADIO_AREA_*`, `PROFUNDIDAD_MINA_NIVEL_*`), `Economia.gd` (`CAPACIDAD_CARGA`), `Ciudad.gd` (`SEGUNDOS_POR_TICK`, `NIVELES_VIVIENDA`, `TASA_MIGRACION`, límites y stock inicial de `almacen`, `TIPOS_POBLACION`) y `Colonos.gd` (`VELOCIDAD_COLONO`). Si algún valor difiere de los que aparecen abajo, gana el código y se anota la diferencia en el mensaje final.

- [ ] **Step 4: Completar `docs/Recursos.xlsx`**

Copiar el archivo al worktree (ver aviso), guardar una copia de respaldo fuera del repo y ejecutar este script desde la raíz del worktree (`python`, con `openpyxl`; escribirlo en el scratchpad, no en el repo):

```python
import shutil
from copy import copy
import openpyxl
from openpyxl.styles import Alignment, Font

RUTA = "docs/Recursos.xlsx"
shutil.copy(RUTA, "<scratchpad>/Recursos_respaldo.xlsx")
wb = openpyxl.load_workbook(RUTA)


def encabezado(ws, fila, titulos):
    for col, texto in enumerate(titulos, start=1):
        celda = ws.cell(fila, col, texto)
        celda.font = Font(bold=True)
        celda.alignment = Alignment(wrap_text=True, vertical="top")


# 1) Niveles: la vivienda real por nivel de ciudad (Ciudad.NIVELES_VIVIENDA).
ws = wb["Niveles"]
ws["B2"] = "Camas por piso"
ws["G2"] = "Pisos máximos"
ws["G2"]._style = copy(ws["F2"]._style)
for fila, (camas, pisos) in {3: (2, 2), 4: (4, 4), 5: (4, 8)}.items():
    ws.cell(fila, 2, camas)
    ws.cell(fila, 7, pisos)
    ws.cell(fila, 7)._style = copy(ws.cell(fila, 6)._style)

# 2) Puestos: cupos, almacén, huella, área y tasas por trabajador y hora.
if "Puestos" in wb.sheetnames:
    del wb["Puestos"]
ws = wb.create_sheet("Puestos")
encabezado(ws, 1, ["Puesto", "Clave de tasa", "Recurso en el almacén", "Tasa base (unid/trabajador/hora)",
                   "Se multiplica por", "Personal máximo", "Almacén local", "Huella (ancho x alto)",
                   "Radio del área", "Estado", "Fuente"])
MINA = (5, 100, "5 x 5", "6 (profundidad 8/16/24 según nivel)")  # personal, almacén, huella, radio
filas = [
    ("Mina", "tierra", "tierra", 1, "fracción de tierra en el área", *MINA, "Implementado", "Recoleccion.gd"),
    *[("Mina", m, m, 5, f"fracción de {m} en el área", *MINA, "Implementado", "Recoleccion.gd")
      for m in ["piedra", "hierro", "cobre", "carbon", "tierras_raras"]],
    ("Maderero", "madera", "madera", 5, "densidad de árboles", 5, 100, "3 x 4", "12", "Implementado", "Recoleccion.gd"),
    ("Caza y recolección", "caza", "comida", 15, "densidad de fauna (Excel: venado)", 7, 100, "4 x 4", "12", "Implementado", "Recoleccion.gd"),
    ("Caza y recolección", "recoleccion", "comida", 5, "densidad frutal (Excel: columna Árbol (obj), Comida 5; interpretada como frutos)", 7, 100, "4 x 4", "12", "Implementado", "Recoleccion.gd"),
    ("Pesca y frutos del mar", "pesca", "comida", 5, "densidad de peces", 7, 100, "4 x 6", "25 (agua conectada)", "Implementado", "Recoleccion.gd"),
    ("Pesca y frutos del mar", "frutos_mar", "comida", 1, "densidad de algas", 7, 100, "4 x 6", "25 (agua conectada)", "Implementado", "Recoleccion.gd"),
    ("Caza (conejo)", "-", "comida", 8, "-", "-", "-", "-", "-", "Propuesta (Excel), no implementada", "docs/Recursos.xlsx, hoja Relacion"),
    ("Pozo de petróleo", "-", "crudo", 2, "-", "-", "-", "-", "-", "Propuesta (Excel), no implementada", "docs/Recursos.xlsx, hoja Relacion"),
    ("Pozo de agua", "-", "agua", 2, "-", "-", "-", "-", "-", "Propuesta (Excel), no implementada", "docs/Recursos.xlsx, hoja Relacion"),
]
for fila, datos in enumerate(filas, start=2):
    for col, valor in enumerate(datos, start=1):
        ws.cell(fila, col, valor)
for col, ancho in zip("ABCDEFGHIJK", [24, 14, 20, 18, 46, 12, 12, 16, 30, 32, 34]):
    ws.column_dimensions[col].width = ancho

# 3) Economia: parámetros de tiempo, acarreo, almacenes y población.
if "Economia" in wb.sheetnames:
    del wb["Economia"]
ws = wb.create_sheet("Economia")
encabezado(ws, 1, ["Parámetro", "Valor", "Unidad", "Fuente"])
parametros = [
    ("Duración de un tick", 2, "segundos reales = 1 hora de juego", "Ciudad.SEGUNDOS_POR_TICK"),
    ("Velocidad de un colono", 2.5, "celdas por segundo (5 por hora de juego)", "Colonos.VELOCIDAD_COLONO"),
    ("Carga de un acarreador", 20, "unidades por viaje (placeholder)", "Economia.CAPACIDAD_CARGA"),
    ("Almacén local de un puesto", 100, "unidades, total entre recursos", "Recoleccion.CAPACIDAD_ALMACENAMIENTO*"),
    ("Límite del stock central", 1000, "unidades por recurso (comida: 2000)", "Ciudad.almacen"),
    ("Stock inicial: comida", 2000, "unidades (al máximo)", "Ciudad.almacen"),
    ("Stock inicial: madera", 200, "unidades", "Ciudad.almacen"),
    ("Stock inicial: hierro", 50, "unidades", "Ciudad.almacen"),
    ("Stock inicial: tierra, piedra, cobre, carbón, tierras raras", 0, "unidades", "Ciudad.almacen"),
    ("Migración de colonos", 0.5, "colonos por hora de juego (solo con vivienda libre y sin hambruna)", "Ciudad.TASA_MIGRACION"),
    ("Consumo de un obrero asignado a un puesto", 5, "comida por hora (un desempleado consume 3)", "Ciudad.TIPOS_POBLACION"),
]
for fila, datos in enumerate(parametros, start=2):
    for col, valor in enumerate(datos, start=1):
        ws.cell(fila, col, valor)
for col, ancho in zip("ABCD", [52, 10, 62, 40]):
    ws.column_dimensions[col].width = ancho

wb.save(RUTA)

# Verificación: las hojas originales que no se tocaron conservan sus valores.
antes = openpyxl.load_workbook("<scratchpad>/Recursos_respaldo.xlsx")
despues = openpyxl.load_workbook(RUTA)
for nombre in ["Relacion", "Recetas"]:
    for fila in antes[nombre].iter_rows():
        for celda in fila:
            assert despues[nombre][celda.coordinate].value == celda.value, (nombre, celda.coordinate)
print("Hojas:", despues.sheetnames)
```

Sustituir `<scratchpad>` por la ruta real del scratchpad. Expected: imprime `Hojas: ['Relacion', 'Recetas', 'Niveles', 'Puestos', 'Economia']` sin `AssertionError`. Si el script falla porque el Excel está abierto en otro programa, pedir al usuario que lo cierre.

- [ ] **Step 5: Completar `docs/Fichas_Consumo_Produccion.md`**

Copiar el archivo al worktree (ver aviso) y editarlo así, en el mismo estilo y en español (no inventar cifras: cada número sale del Excel o del código releído en el Step 3):

1. **Encabezado:** añadir que la transcripción incluye ahora las hojas `Niveles`, `Puestos` y `Economia`, y citar `Economia.gd`.
2. **Sección 1 (Unidades):** en la nota de **"x Cama"**, sustituir "significado no aclarado" por el significado ya implementado: cuántos habitantes de ese tipo caben por cada cama construida; cada cama aporta 1 unidad de vivienda y una persona ocupa `1 / x_cama` de ella (vivienda fraccionaria compartida, `Ciudad.vivienda_ocupada`). Añadir una nota: un `obrero` es ahora un desempleado asignado a un puesto (`Colonos.contratar`), así que pasa de consumir 3 a 5 comida/h; combustible y energía siguen sin aplicarse. Añadir el límite de vivienda por nivel de ciudad (camas por piso × pisos: nivel 1 = 2 × 2, nivel 2 = 4 × 4, nivel 3 = 4 × 8).
3. **Sección 2 (Puestos):** convertir la tabla en la del Step 4 (hoja `Puestos`): estado **Implementado** para tierra, piedra, hierro, cobre, carbón, tierras raras, madera, caza (venado, 15), frutos (5, de la columna "Árbol (obj)" del Excel, que la tabla anterior omitía), pesca (5) y algas (1); **Propuesta (Excel)** solo para conejo (8), pozo de petróleo (2) y pozo de agua (2). Añadir por puesto: personal máximo (mina 5, maderero 5, caza/recolección 7, pesca 7), almacén local 100, huella y radio. **Eliminar** el párrafo "no coincide con el cálculo real todavía implementado" (ya coincide) y sustituirlo por la fórmula vigente: tasa de un recurso = tasa base del Excel × fracción o densidad del área detectada, por trabajador presente y hora; el `TASA_BASE_POR_CIUDADANO = 2.0` genérico ya no existe.
4. **Nueva sección "Acarreo y almacén central":** producción → almacén local (tope 100, exceso se pierde) → acarreador a pie (carga 20, ciclo puesto → núcleo → puesto) → stock central de 8 recursos (límite 1000; comida 2000); la comida de caza/frutos/pesca/algas se suma en `comida`; un tick = 2 s reales = 1 hora de juego. Indicar qué falta: extracción física y agotamiento (2B), refinerías/energía (2C), carretas y carreteras (sub-proyecto 6), moral y nivel del puesto, drones.
5. **Sección 3 (Refinerías) y 4 (Fábricas):** sin cambios de contenido; solo comprobar que sus estados siguen siendo ciertos.
6. **Pendientes:** quitar el punto de "x Cama"; conservar el de conciliar comida por tipo de unidad con la hambre por nivel de avatar; añadir "confirmar que la columna `Árbol (obj)` (Comida 5) es la tasa de frutos" y "balance del acarreo (`CAPACIDAD_CARGA`, cupos) tras jugar".

- [ ] **Step 6: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md" docs/Recursos.xlsx docs/Fichas_Consumo_Produccion.md
git commit -m "docs: GDD 3.34, PoC 5 fase 2A, Recursos.xlsx y fichas de consumo/producción actualizados" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

Al terminar, anotar en el mensaje final la **verificación manual** que hace el usuario en el editor con Godot 4.7: (1) colocar cada uno de los 4 puestos (M, H, L, F) y hacer clic sobre él en la cenital abre el panel; un clic sobre otro sitio lo cierra y no rompe el pintado de zonas; (2) con desempleados libres, `+` en Recolectores y Acarreadores los pone a caminar al puesto y a producir; (3) el almacén local sube y el acarreador lleva la carga al núcleo y el stock central sube en la lista del HUD; (4) el stock de comida sostiene a la población con un puesto de caza/recolección o pesca atendido; (5) `-` despide y el cupo se libera; (6) deconstruir un puesto por completo devuelve a sus trabajadores a desempleados y cierra el panel.

---

## Self-Review (hecha al escribir el plan)

- **Cobertura del spec:** modelo/roles/cupos (T2, T3); stock de 8 recursos (T1); tasas del Excel (T2); tick, tope local, `recoger`/`entregar` (T3); `Ciudad.reasignar_tipo`, `tasa_neta` entre cierres (T1); colonos trabajadores, contratar/despedir, presencia, ciclo del acarreador, `puesto_quitado` (T4); `huella_del_nucleo`, `esquina_de_puesto_en` (T2); registrar/quitar puestos (T5); panel, clic sin zona a medias, lista de recursos (T6); pruebas, suite, Main (T7); GDD/PoC/verificación manual (T8). El "`PERSONAL_MAXIMO*` 5/7/7/5" está en T2.
- **Desviación consciente del spec:** `registrar_puesto` recibe `ancho, alto` además de `tipo` y `tasas` (Economia necesita la huella para `huella_de`, que usa Colonos; así Colonos no depende del autoload `Recoleccion` y sigue siendo inyectable).
- **Consistencia de tipos:** `Economia` (T3) expone exactamente lo que consumen T4 (`asignar, liberar, ultimo_de, marcar_presente, recoger, entregar, huella_de, cupo_libre, trabajadores_de, puesto_quitado, CAPACIDAD_CARGA`), T5 (`registrar_puesto, quitar_puesto`) y T6 (`puestos, tiene_puesto, almacen_local, produccion_por_hora`). `Recoleccion.SIN_PUESTO`/`esquina_de_puesto_en` (T2) los usan T6. `Zonificacion.huella_del_nucleo` (T2) la usan T4 y T6.
- **Riesgos conocidos para el implementador:** (1) `ColonosTest` usa mundos falsos: `_celdas_junto_a` depende de `mundo.altura_en`, que ya existe en `MundoFalso`. (2) El TEST 20/21 de Colonos dependen del A\*; si un caso no llega en el tiempo dado, primero revisar la geometría del mundo de prueba antes de subir los límites de iteraciones. (3) Al editar `Main.tscn` a mano, no cambiar los `unique_id` de los demás nodos.
