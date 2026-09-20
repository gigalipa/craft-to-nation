# Población y Vivienda (Plan 1 de 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar la demografía de PoC 1 por los 7 tipos de población del Excel con vivienda fraccionaria ("x Cama"), un registro de edificios residenciales por id con límites de camas por piso y pisos por casa según el nivel de ciudad, y migración de colonos como número puro en `Ciudad.gd`.

**Architecture:** Todo es lógica pura en el autoload `Ciudad.gd` (sin nodos de escena), verificada con `CiudadTest.tscn`. `BlueprintValidator` gana una regla pura de límites que `Player.gd` y `CamaraCenital.gd` invocan con `Ciudad.NIVELES_VIVIENDA[Ciudad.nivel]`. El HUD solo cambia una línea. Este plan no crea NPC: eso es el Plan 2.

**Tech Stack:** Godot 4.7 (GDScript), pruebas como escenas `*Test.tscn` con `assert()`.

**Spec:** `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md` (Secciones 4 y "Documentación"). Este plan cubre la Sección 4 completa. Los planes 2 (Secciones 2, 3, 3b) y 3 (Sección 6) dependen de este.

## Global Constraints

- GDScript con **tabulaciones** (CLAUDE.md).
- Documentación, mensajes del juego, comentarios y pruebas en **español**, igual que el código existente.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python (CLAUDE.md).
- No tocar `docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md` ni el diff de `PoC_5/` (trabajo en curso del usuario, sin terminar). En cada commit, `git add` solo los archivos listados en el paso, nunca `git add -A` ni `git add .`.
- Verificación (CLAUDE.md): ejecutar `godot/scenes/Test.tscn` con Godot 4.7 además de las demás escenas `*Test.tscn` afectadas, y confirmar que todas las aserciones pasan.
- Autoloads: `extends Node`, sin `class_name` (evita el bug de caché de clases globales de Godot).
- Tabla de población, verbatim del spec: ciudadano 2/0/0 x4; desempleado 3/0/0 x4; obrero 5/0/0 x4; tecnico 3/0/0 x3; especialista 2/1/1 x2; investigador 1/0/2 x1; militar 4/3/0 x3 (comida/combustible/energía, x_cama). Solo `comida` se aplica.
- `NIVELES_VIVIENDA = {1: {camas_por_piso: 2, pisos: 2}, 2: {4, 4}, 3: {4, 8}}`.
- Migración: `TASA_MIGRACION := 0.5` colonos/h; llega un `desempleado` si el tick no tuvo hambruna y `vivienda_libre ≥ 1 / x_cama["desempleado"]`.
- Orden de desahucio: `desempleado, ciudadano, obrero, tecnico` (luego `especialista, investigador, militar` como último recurso para garantizar que termina). La hambruna sigue quitando `militar, obrero, tecnico`.
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```

## Cómo ejecutar una escena de pruebas (headless)

Desde la raíz del repo (`C:\Users\peraz\Projects\Misc\CityCraft`), en bash:

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Una escena que pasa imprime exactamente una línea `=== Las N pruebas de ... pasaron correctamente ===` y ninguna línea con `Assertion`, `SCRIPT ERROR` o `Parse Error`. (Al salir, Godot imprime siempre `WARNING: ... ObjectDB instances were leaked` y `ERROR: ... resources still in use`; es ruido conocido, el `grep` de arriba lo ignora.)

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `godot/scripts/Ciudad.gd` | Modificar | Taxonomía de 7 tipos, `NIVELES_VIVIENDA`, registro por edificio, vivienda fraccionaria, desahucio, migración, señal `tick_simulado` |
| `godot/scripts/CiudadTest.gd` | Modificar | Pruebas 1-8 adaptadas, pruebas 9-15 nuevas |
| `godot/scripts/BlueprintValidator.gd` | Modificar | `validar_limites_vivienda()` y parámetro opcional en `validar_blueprint()` |
| `godot/scripts/BlueprintValidatorTest.gd` | Modificar | Pruebas 62-63 (escena `Test.tscn`) |
| `godot/scripts/Player.gd` | Modificar | Registrar/retirar edificio con id y camas por piso; pasar límites al declarar |
| `godot/scripts/CamaraCenital.gd` | Modificar | Rechazar el emplazamiento de un blueprint que excede los límites del nivel actual |
| `godot/scripts/HUD.gd` | Modificar | Línea de población con vivienda ocupada/capacidad |
| `docs/superpowers/plans/2026-09-20-poblacion-vivienda.md` | Este archivo | |
| `GDD` Secciones 5 y 6 | Modificar | Documentar niveles de vivienda y taxonomía |

---

### Task 0: Rama aislada y documentos de diseño

**Files:**
- Create (commit): `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`, `docs/superpowers/plans/2026-09-20-poblacion-vivienda.md`, `docs/superpowers/plans/2026-09-20-colonos-pathfinding.md`, `docs/superpowers/plans/2026-09-20-fantasmas-permeables.md`

**Interfaces:**
- Produces: la rama `feat/colonos-y-vivienda`, sobre la que trabajan los tres planes.

- [ ] **Step 1: Crear la rama desde `main` conservando el trabajo sin guardar del usuario**

`git switch -c` no toca los archivos modificados ni sin seguimiento, así que el trabajo en curso del usuario (PoC 5, `docs/Recursos.xlsx`, etc.) se queda donde está.

```bash
git switch -c feat/colonos-y-vivienda
git status --short
```

Expected: `Switched to a new branch 'feat/colonos-y-vivienda'` y la misma lista de archivos modificados/sin seguimiento que antes.

- [ ] **Step 2: Commitear solo el spec y los tres planes**

```bash
git add docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md docs/superpowers/plans/2026-09-20-poblacion-vivienda.md docs/superpowers/plans/2026-09-20-colonos-pathfinding.md docs/superpowers/plans/2026-09-20-fantasmas-permeables.md
git commit -m "docs: diseño y planes de colonos NPC, pathfinding y vivienda" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
git status --short
```

Expected: el commit contiene 4 archivos; `git status` sigue mostrando los archivos del usuario sin tocar.

---

### Task 1: Taxonomía de 7 tipos, vivienda fraccionaria y registro por edificio

**Files:**
- Modify: `godot/scripts/Ciudad.gd` (constantes `CONSUMO_POR_ROL` y `CAMAS_POR_PISO_PERMITIDO`; `_init`; `capacidad_camas_construida`; `capacidad_habitacional`; `regular_densidad_vertical`; `registrar_edificio_residencial`/`retirar_edificio_residencial`; `simular_tick`)
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Consumes: nada de otras tareas.
- Produces (los usan las Tareas 2, 3, 4 y el Plan 2):
  - `Ciudad.TIPOS_POBLACION: Dictionary` — tipo → `{"comida", "combustible", "energia", "x_cama"}`.
  - `Ciudad.NIVELES_VIVIENDA: Dictionary` — nivel (int) → `{"camas_por_piso": int, "pisos": int}`.
  - `Ciudad.edificios_residenciales: Dictionary` — id de edificio (int) → `Array[int]` (camas por piso).
  - `Ciudad.registrar_edificio_residencial(id: int, camas_por_piso: Array) -> void` (idempotente por id).
  - `Ciudad.retirar_edificio_residencial(id: int) -> void`.
  - `Ciudad.capacidad_camas_construida: int` (propiedad derivada).
  - `Ciudad.vivienda_ocupada: float` y `Ciudad.vivienda_libre: float` (propiedades derivadas).
  - `Ciudad.demografia` con las claves `ciudadano, desempleado, obrero, tecnico, especialista, investigador, militar`.

- [ ] **Step 1: Adaptar las pruebas 1-8 y agregar las pruebas 9-13 (fallarán)**

En `godot/scripts/CiudadTest.gd`, dentro de `ejecutar_pruebas()`:

**(a)** Justo después de `var jugador: RefCounted = CiudadScript.Avatar.new(urbe)` agregar la vivienda y desactivar la migración (las pruebas 1-6 fijan la demografía a mano; `migracion_activa` se crea en la Tarea 2, hasta entonces esta línea hará fallar el parseo, y eso es esperado en este paso):

```gdscript
	# Las pruebas 1-6 fijan la demografía a mano: se les da vivienda de sobra
	# (5 edificios de 2 pisos x 2 camas = 20 camas en el nivel 1) y se apaga
	# la migración para que no altere las cifras.
	for id_edificio in range(1, 6):
		urbe.registrar_edificio_residencial(id_edificio, [2, 2])
	urbe.migracion_activa = false
```

**(b)** Renombrar las claves de demografía en las pruebas 1, 5 y 6:

| Antes | Después |
|---|---|
| `urbe.demografia["trabajador_tipo_1"] = 2` (TEST 1) | `urbe.demografia["obrero"] = 2` |
| `urbe.demografia["jovenes"] = 1` (TEST 1) | `urbe.demografia["ciudadano"] = 1` |
| `urbe.demografia["trabajador_tipo_1"] = 6` (TEST 5) | `urbe.demografia["obrero"] = 6` |

(Las claves `investigador` y `militar` de las pruebas 2, 3 y 6 no cambian.)

**(c)** Reemplazar por completo los bloques `TEST 7` y `TEST 8` (desde `print("\n=== TEST 7: ...` hasta el último `assert` de TEST 8) por:

```gdscript
	print("\n=== TEST 7: Registro de Edificios Residenciales por id ===")
	# Ver Player.gd::_completar_construccion: al completar un edificio
	# residencial se registran sus camas POR PISO, identificadas por el id de
	# edificio que asigna VoxelWorld. Se usa una Ciudad nueva para partir de 0.
	var vivienda: Node = CiudadScript.new()
	assert(vivienda.capacidad_camas_construida == 0)
	vivienda.registrar_edificio_residencial(1, [1, 1])
	vivienda.registrar_edificio_residencial(2, [2, 1])
	print("Capacidad de camas tras registrar 2 edificios: ", vivienda.capacidad_camas_construida)
	assert(vivienda.capacidad_camas_construida == 5)

	print("\n=== TEST 8: retirar_edificio_residencial() ===")
	vivienda.retirar_edificio_residencial(1)
	assert(vivienda.capacidad_camas_construida == 3)
	vivienda.retirar_edificio_residencial(999)  # un id desconocido no hace nada
	assert(vivienda.capacidad_camas_construida == 3)
	vivienda.retirar_edificio_residencial(2)
	assert(vivienda.capacidad_camas_construida == 0, "Nunca debe bajar de 0")

	print("\n=== TEST 9: Vivienda Fraccionaria (x Cama) ===")
	var v: Node = CiudadScript.new()
	v.registrar_edificio_residencial(1, [2, 2])  # 4 camas en el nivel 1
	v.demografia["obrero"] = 8  # 8 / 4 = 2.0
	v.demografia["tecnico"] = 3  # 3 / 3 = 1.0
	v.demografia["investigador"] = 1  # 1 / 1 = 1.0
	print("Vivienda ocupada: ", v.vivienda_ocupada, " | libre: ", v.vivienda_libre)
	assert(is_equal_approx(v.vivienda_ocupada, 4.0))
	assert(is_equal_approx(v.vivienda_libre, 0.0))
	v.demografia["obrero"] = 4  # 1.0 en vez de 2.0
	assert(is_equal_approx(v.vivienda_libre, 1.0))

	print("\n=== TEST 10: El registro es idempotente por id ===")
	var idem: Node = CiudadScript.new()
	idem.registrar_edificio_residencial(1, [2, 2])
	idem.registrar_edificio_residencial(1, [2, 2])  # el mismo edificio otra vez
	assert(idem.capacidad_camas_construida == 4, "Registrar dos veces el mismo id no debe duplicar las camas")

	print("\n=== TEST 11: La capacidad respeta los pisos y camas por piso del nivel ===")
	var niv: Node = CiudadScript.new()
	niv.registrar_edificio_residencial(1, [4, 4, 4, 4, 4])  # 5 pisos de 4 camas
	assert(niv.capacidad_camas_construida == 4, "Nivel 1: 2 pisos x min(4, 2) camas")
	niv.instalaciones["tipo_2"] = 3  # con solo tipo_2 el índice es 2.0 y hay 3 plantas: nivel potencial 2
	niv.nivel_investigado = 2
	assert(niv.nivel == 2)
	assert(niv.capacidad_camas_construida == 16, "Nivel 2: 4 pisos x min(4, 4) camas")

	print("\n=== TEST 12: Bajar de nivel desahucia a quien vivía en los pisos que dejan de contar ===")
	niv.demografia["obrero"] = 64  # 64 / 4 = 16.0: cabe justo en el nivel 2
	niv.regular_densidad_vertical()
	assert(niv.demografia["obrero"] == 64 and niv.desahuciados == 0)
	niv.instalaciones["tipo_2"] = 0  # el ratio cae: nivel efectivo 1, solo 4 camas cuentan
	assert(niv.nivel == 1)
	niv.regular_densidad_vertical()
	print("Obreros tras bajar de nivel: ", niv.demografia["obrero"], " | desahuciados: ", niv.desahuciados)
	assert(niv.demografia["obrero"] == 16)
	assert(niv.desahuciados == 48)

	print("\n=== TEST 13: Orden de desahucio (primero quien no produce) ===")
	var orden_test: Node = CiudadScript.new()
	orden_test.registrar_edificio_residencial(1, [2, 2])  # 4 camas
	orden_test.demografia["desempleado"] = 8  # 2.0
	orden_test.demografia["ciudadano"] = 4  # 1.0
	orden_test.demografia["obrero"] = 4  # 1.0
	orden_test.demografia["tecnico"] = 3  # 1.0
	orden_test.demografia["militar"] = 4  # 1.33..  -> total 6.33.., sobran 2.33..
	orden_test.regular_densidad_vertical()
	assert(orden_test.demografia["desempleado"] == 0, "los desempleados se desahucian primero")
	assert(orden_test.demografia["ciudadano"] == 2, "luego los ciudadanos, solo los necesarios")
	assert(orden_test.demografia["obrero"] == 4 and orden_test.demografia["tecnico"] == 3 and orden_test.demografia["militar"] == 4)
	assert(orden_test.desahuciados == 10)
```

**(d)** Cambiar la última línea de `ejecutar_pruebas()` por (el número final de pruebas será 15 al terminar la Tarea 2; por ahora son 13):

```gdscript
	print("\n=== Las 13 pruebas de Ciudad pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar la escena y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA con `Parse Error` o `SCRIPT ERROR` (por ejemplo `Invalid call. Nonexistent function 'registrar_edificio_residencial' ...` o `Invalid assignment ... 'migracion_activa'`). No debe aparecer `pasaron correctamente`.

- [ ] **Step 3: Implementar en `Ciudad.gd`**

**(a)** Reemplazar los bloques `CONSUMO_POR_ROL` y `CAMAS_POR_PISO_PERMITIDO` (desde `const CONSUMO_POR_ROL := {` hasta el `}` de `CAMAS_POR_PISO_PERMITIDO`) por:

```gdscript
## Tipos de población (fuente: docs/Recursos.xlsx, hoja "Relacion"; el Excel
## reemplaza la tabla de roles del GDD Sección 6). "x_cama" es cuántos
## habitantes de ese tipo caben por cama construida: cada cama aporta 1
## unidad de vivienda y una persona ocupa 1 / x_cama de ella (vivienda
## fraccionaria compartida, ver vivienda_ocupada). Solo "comida" se aplica
## hoy; combustible y energía quedan transcritos para el sub-proyecto de
## economía (consumo con eficiencia proporcional). "ciudadano" no tiene
## ninguna fuente todavía (no hay nacimientos ni envejecimiento): los
## colonos llegan como "desempleado".
const TIPOS_POBLACION := {
	"ciudadano": {"comida": 2, "combustible": 0, "energia": 0, "x_cama": 4},
	"desempleado": {"comida": 3, "combustible": 0, "energia": 0, "x_cama": 4},
	"obrero": {"comida": 5, "combustible": 0, "energia": 0, "x_cama": 4},
	"tecnico": {"comida": 3, "combustible": 0, "energia": 0, "x_cama": 3},
	"especialista": {"comida": 2, "combustible": 1, "energia": 1, "x_cama": 2},
	"investigador": {"comida": 1, "combustible": 0, "energia": 2, "x_cama": 1},
	"militar": {"comida": 4, "combustible": 3, "energia": 0, "x_cama": 3},
}

## Límites de vivienda por nivel EFECTIVO de ciudad (decisión del usuario,
## 2026-09-20): cuántas camas por piso y cuántos pisos puede tener una casa.
## La población máxima es la vivienda real construida, no un tope por nivel.
## Los 12 pisos quedan reservados para el nivel máximo de desarrollo, que
## todavía no existe.
const NIVELES_VIVIENDA := {
	1: {"camas_por_piso": 2, "pisos": 2},
	2: {"camas_por_piso": 4, "pisos": 4},
	3: {"camas_por_piso": 4, "pisos": 8},
}

## A quién se desahucia primero cuando la vivienda ocupada excede la
## capacidad: primero quien no produce. Los últimos tres solo garantizan que
## el bucle de regular_densidad_vertical() siempre termina.
const ORDEN_DESAHUCIO := ["desempleado", "ciudadano", "obrero", "tecnico", "especialista", "investigador", "militar"]

## A quién quita primero la hambruna (igual que antes de la taxonomía nueva).
const ORDEN_BAJAS_HAMBRUNA := ["militar", "obrero", "tecnico"]
```

**(b)** Agregar `signal tick_simulado` justo antes de `const SEGUNDOS_POR_TICK := 2.0` (se usa en la Tarea 2, pero se declara aquí para no tocar dos veces la cabecera):

```gdscript
## Emitida al final de cada simular_tick(); Colonos.gd (Plan 2) la escucha
## para reconciliar los colonos visibles con demografia.
signal tick_simulado
```

**(c)** En `_init()`, reemplazar el bucle de demografía:

```gdscript
	for tipo in TIPOS_POBLACION:
		demografia[tipo] = 0
```

**(d)** Reemplazar la declaración `var capacidad_camas_construida := 0` y su comentario de arriba (`## Suma de camas de todos los edificios ...`) por:

```gdscript
## Edificios residenciales registrados: id de edificio (el que asigna
## VoxelWorld) -> Array[int] con las camas de CADA piso. Ver
## registrar_edificio_residencial().
var edificios_residenciales: Dictionary = {}

## Si es false, simular_tick() no hace llegar colonos (lo usan las pruebas
## que fijan la demografía a mano).
var migracion_activa := true
var _migrantes_acumulados := 0.0
```

**(e)** Reemplazar el getter `var capacidad_habitacional: int:` (y su `get:`) por las tres propiedades derivadas:

```gdscript
## Camas que cuentan HOY: de cada edificio, solo los pisos que el nivel
## efectivo permite, y de cada piso a lo sumo las camas por piso del nivel.
## Si baja el nivel, los pisos superiores dejan de contar y quien vivía ahí
## se desahucia (GDD Sección 5).
var capacidad_camas_construida: int:
	get:
		var limites: Dictionary = NIVELES_VIVIENDA[nivel]
		var total := 0
		for camas_por_piso: Array in edificios_residenciales.values():
			for i in range(mini(camas_por_piso.size(), limites["pisos"])):
				total += mini(camas_por_piso[i], limites["camas_por_piso"])
		return total

## Suma de 1 / x_cama de cada habitante: la vivienda que ocupa la población.
var vivienda_ocupada: float:
	get:
		var total := 0.0
		for tipo in demografia:
			total += float(demografia[tipo]) / float(TIPOS_POBLACION[tipo]["x_cama"])
		return total

var vivienda_libre: float:
	get: return float(capacidad_camas_construida) - vivienda_ocupada
```

**(f)** Reemplazar la función `regular_densidad_vertical()` completa por:

```gdscript
## Desahucia, de uno en uno y en ORDEN_DESAHUCIO, hasta que la vivienda
## ocupada cabe en la capacidad construida (tolerancia 1e-6 por los
## flotantes de las fracciones).
func regular_densidad_vertical() -> void:
	var capacidad := float(capacidad_camas_construida)
	while vivienda_ocupada > capacidad + 1e-6:
		var desahuciado := false
		for tipo in ORDEN_DESAHUCIO:
			if demografia[tipo] > 0:
				demografia[tipo] -= 1
				desahuciados += 1
				desahuciado = true
				break
		if not desahuciado:
			break
```

**(g)** Reemplazar `registrar_edificio_residencial()` y `retirar_edificio_residencial()` (con sus comentarios `##`) por:

```gdscript
## Registra un edificio residencial completo (ver
## Player.gd::_completar_construccion). "id" es el id de edificio de
## VoxelWorld y "camas_por_piso" las camas de cada piso, en orden. Idempotente
## por id: registrar dos veces el mismo edificio (p. ej. al deconstruirlo y
## volver a completarlo) no duplica sus camas.
func registrar_edificio_residencial(id: int, camas_por_piso: Array) -> void:
	edificios_residenciales[id] = camas_por_piso.duplicate()


## Retira las camas de un edificio residencial que empieza a deconstruirse
## (ver Player.gd::_procesar_deconstruccion) — simétrica a
## registrar_edificio_residencial(). Se llama al INICIAR la deconstrucción de
## un edificio ya terminado (no al completarla): un colono no debería poder
## "vivir" en una cama que ya está siendo desmontada. Un id desconocido no
## hace nada.
func retirar_edificio_residencial(id: int) -> void:
	edificios_residenciales.erase(id)
```

**(h)** En `simular_tick()`, reemplazar el cálculo del gasto de población:

```gdscript
	var gasto_poblacion := 0.0
	for tipo in demografia:
		gasto_poblacion += demografia[tipo] * TIPOS_POBLACION[tipo]["comida"]
	var gasto_total: float = gasto_poblacion + avatar_consumo
```

y la lista de bajas por hambruna (`for rol in ["militar", "trabajador_tipo_1", "trabajador_tipo_2"]:`) por:

```gdscript
		for rol in ORDEN_BAJAS_HAMBRUNA:
```

- [ ] **Step 4: Ejecutar la escena y verificar que pasa**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con la única línea `=== Las 13 pruebas de Ciudad pasaron correctamente ===`.

Nota: `migracion_activa` ya existe (paso 3d) aunque todavía nada la usa; la Tarea 2 la conecta.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/CiudadTest.gd
git commit -m "feat: taxonomía de 7 tipos, vivienda fraccionaria y registro de edificios por id" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: Migración de colonos y señal `tick_simulado`

**Files:**
- Modify: `godot/scripts/Ciudad.gd` (constante, `_migrar()`, final de `simular_tick()`)
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Consumes: `Ciudad.vivienda_libre`, `Ciudad.TIPOS_POBLACION`, `Ciudad.migracion_activa`, `signal tick_simulado` (Tarea 1).
- Produces: `Ciudad.TASA_MIGRACION: float`; `Ciudad._migrar(hambruna: bool) -> int`; `simular_tick()` devuelve además la clave `"migrantes": int`, y emite `tick_simulado` al terminar.

- [ ] **Step 1: Agregar las pruebas 14 y 15 (fallarán)**

En `CiudadTest.gd`, antes de la línea final `print("\n=== Las 13 pruebas ...`, agregar:

```gdscript
	print("\n=== TEST 14: Migración de colonos ===")
	# 14a: con vivienda, llega un desempleado cada 2 ticks (0.5 colonos/h).
	var mig: Node = CiudadScript.new()
	mig.registrar_edificio_residencial(1, [2, 2])  # 4 camas = hasta 16 desempleados
	var res_mig: Dictionary = {}
	for i in range(4):
		res_mig = mig.simular_tick(5.0)
	print("Desempleados tras 4 ticks: ", mig.demografia["desempleado"])
	assert(mig.demografia["desempleado"] == 2)
	assert(res_mig["migrantes"] == 1, "en el tick 4 llegó uno")

	# 14b: sin ninguna vivienda no llega nadie.
	var sin_casa: Node = CiudadScript.new()
	for i in range(10):
		sin_casa.simular_tick(5.0)
	assert(sin_casa.demografia["desempleado"] == 0)

	# 14c: la hambruna bloquea la migración.
	var hambre: Node = CiudadScript.new()
	hambre.registrar_edificio_residencial(1, [2, 2])
	hambre.almacen["comida"].cantidad = 0.0
	for i in range(4):
		hambre.simular_tick(5.0)
	assert(hambre.demografia["desempleado"] == 0)

	# 14d: con la vivienda llena no llegan más, y tampoco se acumula una
	# "bolsa" de migrantes que entre de golpe al liberarse espacio.
	var llena: Node = CiudadScript.new()
	llena.registrar_edificio_residencial(1, [1])  # 1 cama = 4 desempleados
	llena.almacen["comida"].cantidad = 2000.0
	for i in range(20):
		llena.simular_tick(5.0)
	assert(llena.demografia["desempleado"] == 4)
	llena.registrar_edificio_residencial(2, [1])  # otra cama: caben 4 más
	llena.simular_tick(5.0)
	assert(llena.demografia["desempleado"] == 5, "llega de uno en uno, sin ráfaga de 4")

	print("\n=== TEST 15: simular_tick() emite tick_simulado ===")
	var senal: Node = CiudadScript.new()
	var contador := [0]
	senal.tick_simulado.connect(func() -> void: contador[0] += 1)
	senal.simular_tick(5.0)
	senal.simular_tick(5.0)
	assert(contador[0] == 2)
```

y cambiar la línea final a:

```gdscript
	print("\n=== Las 15 pruebas de Ciudad pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar la escena y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA (`Assertion failed` en la prueba 14a: 0 desempleados; o `Invalid access to property or key 'migrantes'`). No debe aparecer `pasaron correctamente`.

- [ ] **Step 3: Implementar la migración**

En `Ciudad.gd`, junto a las demás constantes (después de `ORDEN_BAJAS_HAMBRUNA`):

```gdscript
## Colonos que llegan por hora de juego (placeholder sin balance real). Llega
## un "desempleado" cada vez que el acumulador llega a 1, si hay vivienda
## libre y el tick no tuvo hambruna.
const TASA_MIGRACION := 0.5
```

Agregar la función (por ejemplo justo antes de `simular_tick()`):

```gdscript
## Acumula TASA_MIGRACION y hace llegar desempleados mientras haya vivienda
## para ellos y no haya hambruna. Devuelve cuántos llegaron. Nunca guarda más
## de 1 en el acumulador: sin esto, tras un bloqueo largo entraría una ráfaga
## de golpe al liberarse espacio.
## ponytail: sin cola de migrantes; si el diseño pide una "bolsa" de
## migrantes en espera, sustituir el tope de 1 por un contador real.
func _migrar(hambruna: bool) -> int:
	if not migracion_activa:
		return 0
	_migrantes_acumulados += TASA_MIGRACION
	var llegados := 0
	var espacio_minimo: float = 1.0 / float(TIPOS_POBLACION["desempleado"]["x_cama"])
	while _migrantes_acumulados >= 1.0:
		if hambruna or vivienda_libre < espacio_minimo - 1e-6:
			_migrantes_acumulados = 1.0
			break
		demografia["desempleado"] += 1
		_migrantes_acumulados -= 1.0
		llegados += 1
	return llegados
```

En `simular_tick()`, después del bloque que aplica las bajas por hambruna (`if not exito_comida: ... `) y antes del bucle que calcula `tasa_neta`, agregar:

```gdscript
	var migrantes: int = _migrar(not exito_comida)
```

y reemplazar el `return {...}` final por:

```gdscript
	var resultado := {
		"gasto_comida": gasto_total,
		"hambruna": not exito_comida,
		"bajas": bajas_inanicion,
		"nivel_ciudad": nivel,
		"nivel_potencial": nivel_potencial,
		"bono_moral_variedad": snapped(bono_moral_variedad, 0.01),
		"migrantes": migrantes,
	}
	tick_simulado.emit()
	return resultado
```

- [ ] **Step 4: Ejecutar la escena y verificar que pasa**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: PASS con `=== Las 15 pruebas de Ciudad pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/CiudadTest.gd
git commit -m "feat: migración de colonos por vivienda libre y señal tick_simulado" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 3: Validación de límites de camas por piso y pisos por casa

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd` (nueva función + parámetro en `validar_blueprint`)
- Modify: `godot/scripts/BlueprintValidatorTest.gd` (pruebas 62-63, mensaje final)
- Modify: `godot/scripts/Player.gd` (`_declarar_edificio`)
- Modify: `godot/scripts/CamaraCenital.gd` (`_evaluar_blueprint`, `_mensaje_rechazo_blueprint`, `preload`)

**Interfaces:**
- Consumes: `Ciudad.NIVELES_VIVIENDA` y `Ciudad.nivel` (Tarea 1).
- Produces: `BlueprintValidator.validar_limites_vivienda(blueprint: Dictionary, limites: Dictionary) -> Array` (lista de mensajes de error, vacía si cumple). `BlueprintValidator.validar_blueprint(..., limites_vivienda: Dictionary = {})` (quinto parámetro, opcional).

- [ ] **Step 1: Agregar las pruebas 62 y 63 (fallarán)**

En `godot/scripts/BlueprintValidatorTest.gd`, antes de la última línea `print("\n=== Las 61 pruebas ...`, agregar:

```gdscript
	print("\n=== TEST 62: validar_limites_vivienda() aplica el límite de pisos y de camas por piso ===")
	var limites_n1 := {"camas_por_piso": 2, "pisos": 2}
	var casa_ok := {
		"zona_permitida": "residencial_investigacion",
		"pisos": [
			{"nivel": 0, "camas": [{}, {}]},
			{"nivel": 1, "camas": [{}, {}]},
		],
	}
	assert(BlueprintValidator.validar_limites_vivienda(casa_ok, limites_n1).is_empty(), "2 pisos x 2 camas cabe en el nivel 1")
	var casa_alta := {
		"zona_permitida": "residencial_investigacion",
		"pisos": [
			{"nivel": 0, "camas": [{}]},
			{"nivel": 1, "camas": [{}]},
			{"nivel": 2, "camas": [{}]},
		],
	}
	var errores_alta: Array = BlueprintValidator.validar_limites_vivienda(casa_alta, limites_n1)
	assert(errores_alta.size() == 1, "3 pisos excede los 2 del nivel 1")
	var casa_barracon := {
		"zona_permitida": "residencial_investigacion",
		"pisos": [{"nivel": 0, "camas": [{}, {}, {}, {}, {}]}],
	}
	var errores_barracon: Array = BlueprintValidator.validar_limites_vivienda(casa_barracon, limites_n1)
	assert(errores_barracon.size() == 1, "5 camas en un piso excede las 2 del nivel 1")
	print("OK: ", errores_alta[0], " | ", errores_barracon[0])

	print("\n=== TEST 63: los límites solo aplican a la zona residencial y validar_blueprint() los acepta como parámetro opcional ===")
	var industrial := {
		"zona_permitida": "fabricacion_militar",
		"pisos": [{"nivel": 0, "camas": []}, {"nivel": 1, "camas": []}, {"nivel": 2, "camas": []}],
	}
	assert(BlueprintValidator.validar_limites_vivienda(industrial, limites_n1).is_empty(), "una fábrica no tiene límite de pisos habitables")
	var bp_limites: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	assert(BlueprintValidator.validar_blueprint(bp_limites)["valido"], "sin el parámetro opcional, el blueprint válido sigue válido")
	var limites_cero := {"camas_por_piso": 0, "pisos": 0}
	var res_limites: Dictionary = BlueprintValidator.validar_blueprint(bp_limites, "", {}, {}, limites_cero)
	assert(not res_limites["valido"], "con límites imposibles el blueprint válido queda rechazado")
```

y cambiar la línea final a:

```gdscript
	print("\n=== Las 63 pruebas de BlueprintValidator pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar `Test.tscn` y verificar que falla**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/Test.tscn --quit-after 120 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: FALLA (`Invalid call. Nonexistent function 'validar_limites_vivienda' ...` o `Too many arguments for "validar_blueprint()"`). No debe aparecer `pasaron correctamente`.

- [ ] **Step 3: Implementar en `BlueprintValidator.gd`**

Agregar la función junto a `validar_camas_y_almacenamiento()`:

```gdscript
## Límites de vivienda por nivel de ciudad (GDD Sección 5, decisión del
## usuario 2026-09-20): cuántos pisos puede tener una casa y cuántas camas
## cabe por piso. "limites" es Ciudad.NIVELES_VIVIENDA[nivel]:
## {"camas_por_piso": int, "pisos": int}. Solo aplica a la zona residencial;
## una fábrica o un cuartel no tienen límite de pisos habitables. Evita, por
## ejemplo, un "barracón" de un piso con camas ilimitadas.
static func validar_limites_vivienda(blueprint: Dictionary, limites: Dictionary) -> Array:
	if blueprint.get("zona_permitida", "") != "residencial_investigacion":
		return []
	var errores: Array = []
	var pisos: Array = blueprint["pisos"]
	if pisos.size() > limites["pisos"]:
		errores.append(
			"El Blueprint tiene %d piso(s) y el nivel actual de la ciudad permite %d por casa"
			% [pisos.size(), limites["pisos"]]
		)
	for piso in pisos:
		var camas: int = (piso.get("camas", []) as Array).size()
		if camas > limites["camas_por_piso"]:
			errores.append(
				"Piso %d: tiene %d cama(s), pero el nivel actual permite %d por piso"
				% [piso["nivel"], camas, limites["camas_por_piso"]]
			)
	return errores
```

En la firma de `validar_blueprint(` agregar el quinto parámetro:

```gdscript
static func validar_blueprint(
	blueprint: Dictionary,
	zona_destino: String = "",
	blueprint_anterior: Dictionary = {},
	blueprint_original_produccion: Dictionary = {},
	limites_vivienda: Dictionary = {}
) -> Dictionary:
```

y, justo después de `errores.append_array(validar_zona_permitida(blueprint))`, agregar:

```gdscript
	if not limites_vivienda.is_empty():
		errores.append_array(validar_limites_vivienda(blueprint, limites_vivienda))
```

- [ ] **Step 4: Conectar el límite al declarar un edificio (`Player.gd`)**

En `_declarar_edificio()`, reemplazar el bloque

```gdscript
	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino)
```

por:

```gdscript
	var limites_vivienda: Dictionary = Ciudad.NIVELES_VIVIENDA[Ciudad.nivel]
	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint, "", {}, {}, limites_vivienda)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino, {}, {}, limites_vivienda)
```

- [ ] **Step 5: Conectar el límite al emplazar un blueprint (`CamaraCenital.gd`)**

Bajo los `const ... preload` del inicio del archivo (junto a `NivelacionOverlay`), agregar:

```gdscript
const BlueprintValidator = preload("res://scripts/BlueprintValidator.gd")
```

En `_evaluar_blueprint()`, dentro del diccionario devuelto, agregar la clave (por ejemplo después de `"zona_correcta"`):

```gdscript
		"errores_vivienda": BlueprintValidator.validar_limites_vivienda(_blueprint_activo, Ciudad.NIVELES_VIVIENDA[Ciudad.nivel]),
```

En `_mensaje_rechazo_blueprint()`, justo después del bloque `if not ev["zona_correcta"]: ...`, agregar:

```gdscript
	if not ev["errores_vivienda"].is_empty():
		return "Colocación rechazada: " + ev["errores_vivienda"][0]
```

(El nivel pudo bajar desde que se declaró el blueprint, por eso se revalida al emplazar cada copia.)

- [ ] **Step 6: Ejecutar `Test.tscn` y `CiudadTest` y verificar que pasan**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/Test.tscn --quit-after 120 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Expected: `=== Las 63 pruebas de BlueprintValidator pasaron correctamente ===` y `=== Las 15 pruebas de Ciudad pasaron correctamente ===`, sin líneas de error.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd godot/scripts/Player.gd godot/scripts/CamaraCenital.gd
git commit -m "feat: límites de camas por piso y pisos por casa según el nivel de ciudad" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 4: Registrar edificios por id desde el jugador y actualizar el HUD

**Files:**
- Modify: `godot/scripts/Player.gd` (`_completar_construccion`, `_procesar_deconstruccion`)
- Modify: `godot/scripts/HUD.gd` (línea de población)

**Interfaces:**
- Consumes: `Ciudad.registrar_edificio_residencial(id, camas_por_piso)`, `Ciudad.retirar_edificio_residencial(id)`, `Ciudad.vivienda_ocupada`, `Ciudad.capacidad_camas_construida` (Tarea 1). `metadata["id_edificio"]` (lo fijan `CamaraCenital._procesar_clic_blueprint()` y `Player._declarar_edificio()` antes de llamar a `_completar_construccion`) y `resultado["id"]` de `VoxelWorld.procesar_deconstruccion()`.
- Produces: nada nuevo para otras tareas.

Estas dos funciones dependen del árbol de escena (`hud`, `mundo`), así que no tienen prueba automática; se verifican con la lista manual del final de este plan. El cambio es mecánico y las firmas ya están cubiertas por `CiudadTest`.

- [ ] **Step 1: Registrar el edificio con su id y sus camas por piso**

En `Player._completar_construccion()`, reemplazar

```gdscript
	var total_camas := 0
	for piso in blueprint["pisos"]:
		total_camas += (piso.get("camas", []) as Array).size()
	Ciudad.registrar_edificio_residencial(total_camas)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")
```

por:

```gdscript
	var camas_por_piso: Array[int] = []
	var total_camas := 0
	for piso in blueprint["pisos"]:
		var camas: int = (piso.get("camas", []) as Array).size()
		camas_por_piso.append(camas)
		total_camas += camas
	Ciudad.registrar_edificio_residencial(metadata["id_edificio"], camas_por_piso)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (capacidad de camas actual: ", Ciudad.capacidad_camas_construida, ")")
```

- [ ] **Step 2: Retirar el edificio por id al deconstruirlo**

En `Player._procesar_deconstruccion()`, reemplazar

```gdscript
		Ciudad.retirar_edificio_residencial(resultado["total_camas"])
```

por:

```gdscript
		Ciudad.retirar_edificio_residencial(resultado["id"])
```

- [ ] **Step 3: Cambiar la línea de población del HUD**

En `HUD.gd::_process()`, reemplazar las dos líneas de `poblacion_label` por:

```gdscript
	poblacion_label.text = "Población: %d (vivienda %.1f / %d)" % [Ciudad.censo_total, Ciudad.vivienda_ocupada, Ciudad.capacidad_camas_construida]
	poblacion_label.modulate = COLOR_NEGATIVO if Ciudad.vivienda_ocupada > Ciudad.capacidad_camas_construida else COLOR_POSITIVO
```

- [ ] **Step 4: Comprobar que `Main.tscn` carga sin errores nuevos**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 120 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Invalid" 
```

Expected: sin salida (ninguna línea de error). Si aparece `Invalid access ... 'capacidad_habitacional'` o `'CONSUMO_POR_ROL'`, algo más en el proyecto las usaba: `grep -rn "capacidad_habitacional\|CONSUMO_POR_ROL\|CAMAS_POR_PISO_PERMITIDO" godot/` y adaptarlo.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Player.gd godot/scripts/HUD.gd
git commit -m "feat: registrar edificios residenciales por id y mostrar vivienda en el HUD" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 5: Documentación (GDD Secciones 5 y 6) y verificación final

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (Secciones 5, 6 y encabezado de versión)
- Modify: `PoC_4/Documento Técnico de Desarrollo_ PoC 4 - Integración de Ciudad y Avatar como Autoload.md` (nota breve)

**Interfaces:** ninguna.

- [ ] **Step 1: Actualizar el GDD, Sección 5**

En la viñeta "Volumen Vital y Camas", reemplazar la frase que empieza en "La altura habitable del edificio será limitada según el nivel de la ciudad, es decir: en nivel 0 solo son habitables ..." hasta "... y así consecutivamente." por:

```
Los límites de una casa dependen del nivel de la ciudad: en nivel 1 puede tener hasta 2 pisos con 2 camas por piso (4 camas en total); en nivel 2, hasta 4 pisos con 4 camas por piso; en nivel 3, hasta 8 pisos con 4 camas por piso. (Los 12 pisos quedan reservados para el nivel máximo de desarrollo de la civilización, que todavía no existe.) La población máxima de la ciudad es la vivienda real construida — ver Sección 6, "Vivienda por cama" —, no un tope por nivel: el jugador puede construir tantas casas como sus recursos y el espacio lo permitan, y el reto es decidir cuántas y de qué tamaño para poder alimentarlas y no agotar sus reservas.
```

Y la frase "Si disminuye de nivel, la población de los pisos superiores será desahuciada, ..." se conserva tal cual.

- [ ] **Step 2: Actualizar el GDD, Sección 6**

Reemplazar la tabla "Rol de Población / Consumo" por la de los 7 tipos:

```
| Tipo | Comida (Uds/h) | Combustible (Uds/h) | Energía (Uds/h) | x Cama | Notas |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Ciudadano** | 2 | — | — | 4 | Persona base sin oficio. Sin fuente por ahora (no hay nacimientos ni envejecimiento). |
| **Desempleado** | 3 | — | — | 4 | Adulto apto sin puesto. Los colonos llegan como desempleados. |
| **Obrero** | 5 | — | — | 4 | Fuerza bruta en la Periferia y el Núcleo A (tipo 1). |
| **Técnico** | 3 | — | — | 3 | Zona de fabricación (tipo 2). |
| **Especialista** | 2 | 1 | 1 | 2 | Plantas químicas y ensamblaje (tipo 3). |
| **Investigador** | 1 | — | 2 | 1 | Requiere entrenamiento. |
| **Militar** | 4 | 3 | — | 3 | Requiere entrenamiento. |
```

y agregar debajo:

```
> * **Vivienda por cama ("x Cama"):** cada cama construida aporta 1 unidad de vivienda y cada persona ocupa una fracción: 1/4 un obrero, ciudadano o desempleado; 1/3 un técnico o militar; 1/2 un especialista; 1 entera un investigador. Con 10 camas caben 40 obreros, 10 investigadores o cualquier mezcla que sume 10. Si la vivienda ocupada excede la capacidad, se desahucia primero a quien no produce (desempleados, ciudadanos, obreros, técnicos).
> * **Migración de colonos:** llega un desempleado cada 2 horas de juego (0,5 colonos/h, placeholder) mientras haya vivienda libre y no haya hambruna.
> * **Combustible y energía:** el Excel los asigna a especialistas, investigadores y militares; se aplicarán con el sistema de economía (eficiencia proporcional a lo recibido). Hoy solo se aplica la comida.
```

- [ ] **Step 3: Actualizar el encabezado de versión del GDD**

Cambiar `**Versión del Documento:** 3.29 (` por `**Versión del Documento:** 3.30 (**Vivienda y población (2026-09-20):** taxonomía de 7 tipos del Excel con vivienda fraccionaria ("x Cama"), límites de camas por piso y pisos por casa según el nivel de ciudad (Secciones 5 y 6), migración de colonos. Detalle en `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`.) Versión anterior (3.29): (`.

- [ ] **Step 4: Nota en el documento técnico de PoC 4**

Al final de la sección "Próximos Pasos" (o donde el documento describa el modelo de demografía), agregar:

```
* **Actualización (2026-09-20):** la demografía de `Ciudad.gd` dejó de usar los roles de PoC 1 (jóvenes, trabajador tipo 1/2/3, ancianos) y pasó a los 7 tipos del Excel con vivienda fraccionaria y registro de edificios por id; el límite de población es la vivienda real, no el tope de 4/8/12 por nivel. Ver `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`, Sección 4.
```

- [ ] **Step 5: Verificación final de este plan**

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
for escena in Test CiudadTest ConstruccionTest ZonificacionTest; do
  echo "== $escena"
  "$GD" --headless --path godot res://scenes/$escena.tscn --quit-after 120 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
done
```

Expected: cada escena imprime su línea `pasaron correctamente` y ninguna línea de error.

- [ ] **Step 6: Verificación manual (no se puede automatizar en headless)**

Abrir `godot/scenes/Main.tscn` en el editor de Godot 4.7 y comprobar:
1. Declarar una casa de nivel 1 con 2 pisos y 2 camas por piso: se acepta. Con 3 pisos o 3 camas en un piso: se rechaza con el mensaje de límite.
2. El HUD muestra `Población: 0 (vivienda 0.0 / 4)` tras completar esa casa.
3. Esperar unos segundos: la población sube de a uno cada ~4 s y el HUD refleja la vivienda ocupada (todavía sin NPC visibles: eso es el Plan 2).
4. Deconstruir la casa con `G`: la capacidad vuelve a 0 y la población se desahucia.

- [ ] **Step 7: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_4/Documento Técnico de Desarrollo_ PoC 4 - Integración de Ciudad y Avatar como Autoload.md"
git commit -m "docs: GDD 3.30 — vivienda fraccionaria, taxonomía de 7 tipos y límites por nivel" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

## Self-Review (Plan 1)

**Cobertura del spec, Sección 4:** taxonomía (Tarea 1), `NIVELES_VIVIENDA` con 4/8 pisos (Tarea 1), registro por edificio idempotente (Tarea 1), vivienda fraccionaria (Tarea 1), desahucio por orden y por bajada de nivel (Tarea 1, pruebas 12-13), migración con bloqueo por hambruna/vivienda (Tarea 2), señal `tick_simulado` (Tareas 1-2), validación de límites al declarar y al emplazar (Tarea 3), cambios en `Player.gd` con id (Tarea 4), HUD (Tarea 4), documentación (Tarea 5). Sin brechas.

**Puntos que el ejecutor debe vigilar:**
- `metadata["id_edificio"]` debe existir en `_completar_construccion`. Ya lo fijan `CamaraCenital._procesar_clic_blueprint()` y `Player._declarar_edificio()` antes de llamarla; si `_completar_construccion` se invocara desde otro sitio, faltaría la clave y habría que añadirla ahí.
- El paso 1(a) de la Tarea 1 hace fallar el parseo a propósito (usa `migracion_activa` antes de que exista en el paso 3d): es el "test que falla".
- `Ciudad.nivel` puede ser 1, 2 o 3; `NIVELES_VIVIENDA[nivel]` no tiene otros valores.
