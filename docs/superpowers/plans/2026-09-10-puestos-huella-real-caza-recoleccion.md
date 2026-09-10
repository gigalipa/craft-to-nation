# Puestos con Huella Real + Puesto de Caza/Recolección — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el marcador de un solo bloque de los puestos periféricos (mina) por una huella real de N×M celdas con validación de choques/relieve y rotación 90°, y agregar un puesto nuevo (caza y recolección) que produce comida a partir de las señales de fauna/frutal ya existentes.

**Architecture:** `Recoleccion.gd` (autoload de estado puro) pasa a registrar cualquier puesto por la esquina de su huella real, en vez de un punto único de mina. `VoxelWorld.gd` gana una función de validación de huella (choque con árboles/estructuras). `NiveladorTerreno.gd` se generaliza para aceptar huellas no cuadradas (reutilizada tanto por el modo de nivelación manual existente como por la nueva validación de relieve de un puesto). `CamaraCenital.gd` unifica el modo de colocación de mina y el nuevo modo de caza/recolección en un solo modo genérico parametrizado por tipo, con rotación via `Ctrl`+rueda del mouse. `HUD.gd` gana una ficha nueva para el puesto de caza/recolección, mismo patrón que la ficha de mina.

**Tech Stack:** Godot 4.7 (GDScript), GridMap + MeshLibrary, autoloads de estado puro (`RefCounted`/`Node` sin nodos de escena propios), MCP de Godot (`mcp__godot__run_project`/`get_debug_output`/`stop_project`/`export_mesh_library`) para verificación headless.

**Spec:** `docs/superpowers/specs/2026-09-10-puestos-huella-real-caza-recoleccion-design.md`

## Global Constraints

- Godot 4.7, GDScript con tabulaciones (no espacios).
- Comentarios y mensajes de consola en español, código (identificadores) también en español, siguiendo la convención ya establecida en el repo.
- Sin producción real por tick, sin cobro del costo de construcción, sin niveles 2/3 de mina — mismo alcance reducido que la spec de minas original.
- El puesto maderero (huella 3×4) queda documentado como constantes únicamente — sin modo de colocación jugable en este plan.
- El puesto de pesca/frutos del mar queda fuera de alcance (categoría de moral aparte, depende de una señal de peces que no existe).
- Cada tarea debe dejar `Test.tscn`/`RecoleccionTest.tscn`/`NiveladorTerrenoTest.tscn` pasando y `Main.tscn` cargando sin errores nuevos (los 2 warnings de "constante con el mismo nombre que una clase global" en `Player.gd:4`/`Main.gd:3` son preexistentes y no cuentan).

---

### Task 1: `Recoleccion.gd` — unificar el registro de puestos por huella real

**Files:**
- Modify: `godot/scripts/Recoleccion.gd`
- Modify: `godot/scripts/RecoleccionTest.gd`

**Interfaces:**
- Consumes: nada nuevo (mismo autoload existente).
- Produces: `Recoleccion.colocar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int) -> void`, `Recoleccion.celda_dentro_de_algun_puesto(celda: Vector2i) -> bool`, `Recoleccion.puestos: Dictionary` (ahora `Vector2i esquina -> {"tipo": String, "ancho": int, "alto": int, "nivel": int}`), constantes `ANCHO_HUELLA_MINA/ALTO_HUELLA_MINA` (5,5), `ANCHO_HUELLA_MADERERO/ALTO_HUELLA_MADERERO` (3,4, documentadas sin uso todavía) — usados por Task 6/7.

- [ ] **Step 1: Reemplazar `colocar_mina()` por `colocar_puesto()` y agregar `celda_dentro_de_algun_puesto()`**

En `godot/scripts/Recoleccion.gd`, reemplazar:

```gdscript
const RADIO_AREA_MINA := 6
const PROFUNDIDAD_MINA_NIVEL_1 := 8
const TASA_BASE_POR_CIUDADANO := 2.0
```

por:

```gdscript
const RADIO_AREA_MINA := 6
const PROFUNDIDAD_MINA_NIVEL_1 := 8
const TASA_BASE_POR_CIUDADANO := 2.0
const ANCHO_HUELLA_MINA := 5
const ALTO_HUELLA_MINA := 5
```

y, más abajo, agregar tras `CAPACIDAD_ALMACENAMIENTO`:

```gdscript
## Documentada para el puesto maderero (GDD Sección 3) — sin puesto jugable
## todavía, solo fija la convención de tamaño junto a las demás huellas.
const ANCHO_HUELLA_MADERERO := 3
const ALTO_HUELLA_MADERERO := 4
```

Reemplazar el bloque completo:

```gdscript
var puestos: Dictionary = {}  # Vector2i (celda de superficie) -> {"nivel": int}


func colocar_mina(celda: Vector2i) -> void:
	puestos[celda] = {"nivel": 1}
```

por:

```gdscript
## Vector2i (esquina de la huella, celda de menor X/Z) -> {"tipo": String,
## "ancho": int, "alto": int, "nivel": int}. Antes solo guardaba minas
## indexadas por su único bloque marcador; ahora guarda cualquier puesto
## periférico por la esquina de su huella real, para poder validar choques
## entre puestos de cualquier tipo (ver celda_dentro_de_algun_puesto()).
var puestos: Dictionary = {}


func colocar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int) -> void:
	puestos[esquina] = {"tipo": tipo, "ancho": ancho, "alto": alto, "nivel": 1}


## true si "celda" cae dentro de la huella de algún puesto ya colocado (de
## cualquier tipo) — usada al previsualizar una nueva colocación, para
## rechazarla si se solapa con un puesto existente (ver CamaraCenital.gd).
func celda_dentro_de_algun_puesto(celda: Vector2i) -> bool:
	for esquina in puestos:
		var datos: Dictionary = puestos[esquina]
		var ancho: int = datos["ancho"]
		var alto: int = datos["alto"]
		if celda.x >= esquina.x and celda.x < esquina.x + ancho \
				and celda.y >= esquina.y and celda.y < esquina.y + alto:
			return true
	return false
```

- [ ] **Step 2: Actualizar el test existente de colocación (TEST 4) y agregar el test de choque entre puestos**

En `godot/scripts/RecoleccionTest.gd`, reemplazar:

```gdscript
	print("\n=== TEST 4: colocar_mina() registra el puesto ===")
	Recoleccion.puestos.clear()  # aislar de otras pruebas que compartan el autoload
	Recoleccion.colocar_mina(Vector2i(5, 5))
	assert(Recoleccion.puestos.has(Vector2i(5, 5)))
	assert(Recoleccion.puestos[Vector2i(5, 5)]["nivel"] == 1)
```

por:

```gdscript
	print("\n=== TEST 4: colocar_puesto() registra el puesto por su huella ===")
	Recoleccion.puestos.clear()  # aislar de otras pruebas que compartan el autoload
	Recoleccion.colocar_puesto(Vector2i(5, 5), "mina", Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
	assert(Recoleccion.puestos.has(Vector2i(5, 5)))
	assert(Recoleccion.puestos[Vector2i(5, 5)]["tipo"] == "mina")
	assert(Recoleccion.puestos[Vector2i(5, 5)]["ancho"] == 5)
	assert(Recoleccion.puestos[Vector2i(5, 5)]["nivel"] == 1)
```

Y, tras el bloque del TEST 5 (el que verifica que `detectar_recursos()` ignora madera/follaje, que termina con el `print("OK: ...")`), agregar antes de la línea final `print("\n=== Las 5 pruebas...")`:

```gdscript
	print("\n=== TEST 6: celda_dentro_de_algun_puesto() detecta solapamiento entre puestos de cualquier tipo ===")
	Recoleccion.puestos.clear()
	Recoleccion.colocar_puesto(Vector2i(0, 0), "mina", Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
	assert(Recoleccion.celda_dentro_de_algun_puesto(Vector2i(2, 2)))       # dentro de la huella 5x5 de (0,0): 0..4
	assert(not Recoleccion.celda_dentro_de_algun_puesto(Vector2i(5, 5)))   # justo fuera de esa huella
	Recoleccion.colocar_puesto(Vector2i(20, 20), "caza_recoleccion", 4, 4)
	assert(Recoleccion.celda_dentro_de_algun_puesto(Vector2i(22, 22)))     # dentro del segundo puesto
	assert(not Recoleccion.celda_dentro_de_algun_puesto(Vector2i(24, 24))) # huella 4x4 de (20,20): 20..23
	print("OK: celda_dentro_de_algun_puesto() detecta el puesto correcto sin importar su tipo.")
```

y cambiar la línea final de:

```gdscript
	print("\n=== Las 5 pruebas de Recoleccion pasaron correctamente ===")
```

a:

```gdscript
	print("\n=== Las 6 pruebas de Recoleccion pasaron correctamente ===")
```

- [ ] **Step 3: Correr las pruebas y verificar que pasan**

Usar las herramientas MCP de Godot: `mcp__godot__run_project` con `projectPath: "C:\Users\peraz\Projects\Misc\CityCraft\godot"` y `scene: "scenes/RecoleccionTest.tscn"`, luego `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project`.
Esperado en `output`: `"=== Las 6 pruebas de Recoleccion pasaron correctamente ==="` y ningún `assert` fallido en `errors`.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: Recoleccion registra puestos por huella real, no un solo bloque"
```

---

### Task 2: `Recoleccion.gd` — señales de caza/recolección (fauna + frutal)

**Files:**
- Modify: `godot/scripts/Recoleccion.gd`
- Modify: `godot/scripts/RecoleccionTest.gd`

**Interfaces:**
- Consumes: `generador.densidad_fauna_en(x: int, z: int) -> float` y `generador.densidad_frutal_en(x: int, z: int) -> float` (ya existen en `GeneradorMundo.gd`, PoC 5 sub-proyecto 3.11).
- Produces: `Recoleccion.detectar_fauna_frutal(generador: Object, centro_xz: Vector2i) -> Dictionary` (`{"fauna": float, "frutal": float}`), `Recoleccion.tasas_caza_recoleccion(promedios: Dictionary) -> Dictionary` (`{"caza": float, "recoleccion": float}`), constantes `RADIO_AREA_CAZA_RECOLECCION`, `ANCHO_HUELLA_CAZA_RECOLECCION`, `ALTO_HUELLA_CAZA_RECOLECCION`, `COSTO_CONSTRUCCION_CAZA_RECOLECCION`, `PERSONAL_MAXIMO_CAZA_RECOLECCION`, `CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION` — usados por Task 6/7.

- [ ] **Step 1: Agregar las constantes de caza/recolección**

En `godot/scripts/Recoleccion.gd`, tras el bloque `ANCHO_HUELLA_MADERERO`/`ALTO_HUELLA_MADERERO` agregado en Task 1, agregar:

```gdscript
const RADIO_AREA_CAZA_RECOLECCION := 12
const PASO_MUESTREO_CAZA_RECOLECCION := 2  # cada 2 celdas, no las ~450 del área completa
const TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO := 2.0
const ANCHO_HUELLA_CAZA_RECOLECCION := 4
const ALTO_HUELLA_CAZA_RECOLECCION := 4

# GDD Sección 3 — mismos valores que la mina por ahora, sin balance real
# todavía (ver Recoleccion.COSTO_CONSTRUCCION más arriba).
const COSTO_CONSTRUCCION_CAZA_RECOLECCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_CAZA_RECOLECCION := 3
const CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION := 100
```

- [ ] **Step 2: Agregar `detectar_fauna_frutal()` y `tasas_caza_recoleccion()`**

Al final de `godot/scripts/Recoleccion.gd`, agregar:

```gdscript
## Promedia densidad_fauna_en()/densidad_frutal_en() (GeneradorMundo — duck
## typing, mismo patrón que NiveladorTerreno con altura_en()) muestreadas
## cada PASO_MUESTREO_CAZA_RECOLECCION celdas dentro del círculo de radio
## RADIO_AREA_CAZA_RECOLECCION centrado en centro_xz. Siempre devuelve ambas
## claves — 0.0 si no hubo ninguna muestra (evita dividir por cero).
func detectar_fauna_frutal(generador: Object, centro_xz: Vector2i) -> Dictionary:
	var suma_fauna := 0.0
	var suma_frutal := 0.0
	var muestras := 0
	for dx in range(-RADIO_AREA_CAZA_RECOLECCION, RADIO_AREA_CAZA_RECOLECCION + 1, PASO_MUESTREO_CAZA_RECOLECCION):
		for dz in range(-RADIO_AREA_CAZA_RECOLECCION, RADIO_AREA_CAZA_RECOLECCION + 1, PASO_MUESTREO_CAZA_RECOLECCION):
			if Vector2(dx, dz).length() > RADIO_AREA_CAZA_RECOLECCION:
				continue
			var x: int = centro_xz.x + dx
			var z: int = centro_xz.y + dz
			suma_fauna += generador.densidad_fauna_en(x, z)
			suma_frutal += generador.densidad_frutal_en(x, z)
			muestras += 1
	if muestras == 0:
		return {"fauna": 0.0, "frutal": 0.0}
	return {"fauna": suma_fauna / muestras, "frutal": suma_frutal / muestras}


## Dos tasas independientes ("caza"/"recoleccion"), cada una promedio_señal *
## TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO — no se suman en un total, igual
## que tasas_recoleccion() no suma sus minerales.
func tasas_caza_recoleccion(promedios: Dictionary) -> Dictionary:
	return {
		"caza": promedios["fauna"] * TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO,
		"recoleccion": promedios["frutal"] * TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO,
	}
```

- [ ] **Step 3: Agregar las pruebas con un generador falso determinista**

En `godot/scripts/RecoleccionTest.gd`, agregar tras la línea `const VoxelWorld = preload("res://scripts/VoxelWorld.gd")` (antes de `func _ready()`):

```gdscript
## Generador falso: densidad de fauna/frutal constante dentro de un
## "bioma" cuadrado (|x|<=10, |z|<=10), 0.0 fuera — mismo patrón de
## generador falso determinista que NiveladorTerrenoTest.gd, para poder
## verificar el promedio con precisión (GeneradorMundo real usa ruido).
class GeneradorBiomaFalso:
	func densidad_fauna_en(x: int, z: int) -> float:
		return 0.8 if abs(x) <= 10 and abs(z) <= 10 else 0.0
	func densidad_frutal_en(x: int, z: int) -> float:
		return 0.4 if abs(x) <= 10 and abs(z) <= 10 else 0.0
```

Y, antes de la línea final `print("\n=== Las 6 pruebas...")` (agregada en Task 1), insertar:

```gdscript
	print("\n=== TEST 7: detectar_fauna_frutal() promedia dentro del radio ===")
	var generador_bioma := GeneradorBiomaFalso.new()
	var promedios: Dictionary = Recoleccion.detectar_fauna_frutal(generador_bioma, Vector2i(0, 0))
	print("Promedios (centro del bioma): ", promedios)
	assert(is_equal_approx(promedios["fauna"], 0.8))
	assert(is_equal_approx(promedios["frutal"], 0.4))

	print("\n=== TEST 8: detectar_fauna_frutal() fuera del bioma da 0.0/0.0 ===")
	var promedios_fuera: Dictionary = Recoleccion.detectar_fauna_frutal(generador_bioma, Vector2i(1000, 1000))
	assert(is_equal_approx(promedios_fuera["fauna"], 0.0))
	assert(is_equal_approx(promedios_fuera["frutal"], 0.0))

	print("\n=== TEST 9: tasas_caza_recoleccion() multiplica cada señal por su tasa base ===")
	var tasas_caza: Dictionary = Recoleccion.tasas_caza_recoleccion({"fauna": 0.5, "frutal": 0.25})
	assert(is_equal_approx(tasas_caza["caza"], 0.5 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))
	assert(is_equal_approx(tasas_caza["recoleccion"], 0.25 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))
```

y cambiar la línea final de `"=== Las 6 pruebas..."` a `"=== Las 9 pruebas de Recoleccion pasaron correctamente ==="`.

- [ ] **Step 4: Correr las pruebas y verificar que pasan**

`mcp__godot__run_project` (scene: `scenes/RecoleccionTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.
Esperado: `"=== Las 9 pruebas de Recoleccion pasaron correctamente ==="`, sin asserts fallidos.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: señales de caza/recolección (fauna+frutal) en Recoleccion"
```

---

### Task 3: `NiveladorTerreno.gd` — generalizar a huellas no cuadradas

**Files:**
- Modify: `godot/scripts/NiveladorTerreno.gd`
- Modify: `godot/scripts/NiveladorTerrenoTest.gd`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `verificar_pendiente(esquina: Vector2i, ancho: int = TAMANO_HUELLA, alto: int = TAMANO_HUELLA) -> bool` — firma con parámetros opcionales, usada por Task 7 con la huella real de cada puesto.

- [ ] **Step 1: Agregar parámetros `ancho`/`alto` opcionales a las 3 funciones**

En `godot/scripts/NiveladorTerreno.gd`, reemplazar las 3 funciones:

```gdscript
func verificar_pendiente(esquina: Vector2i) -> bool:
	for x in range(esquina.x, esquina.x + TAMANO_HUELLA):
		for z in range(esquina.y, esquina.y + TAMANO_HUELLA):
			var altura: int = _generador.altura_en(x, z)
			if x + 1 < esquina.x + TAMANO_HUELLA:
				if abs(altura - _generador.altura_en(x + 1, z)) > LIMITE_PENDIENTE:
					return false
			if z + 1 < esquina.y + TAMANO_HUELLA:
				if abs(altura - _generador.altura_en(x, z + 1)) > LIMITE_PENDIENTE:
					return false
	return true


func altura_objetivo(esquina: Vector2i) -> int:
	var maximo: int = _generador.altura_en(esquina.x, esquina.y)
	for x in range(esquina.x, esquina.x + TAMANO_HUELLA):
		for z in range(esquina.y, esquina.y + TAMANO_HUELLA):
			maximo = max(maximo, _generador.altura_en(x, z))
	return maximo


func calcular_relleno(esquina: Vector2i) -> Dictionary:
	var objetivo: int = altura_objetivo(esquina)
	var relleno: Dictionary = {}
	for x in range(esquina.x, esquina.x + TAMANO_HUELLA):
		for z in range(esquina.y, esquina.y + TAMANO_HUELLA):
			var faltante: int = objetivo - _generador.altura_en(x, z)
			if faltante > 0:
				relleno[Vector2i(x, z)] = faltante
	return relleno
```

por:

```gdscript
## "ancho"/"alto" por defecto son la huella cuadrada TAMANO_HUELLA del modo
## de nivelación manual (tecla B) — quien valida el relieve de un puesto
## periférico (ver CamaraCenital.gd) pasa su propia huella real (p. ej. 5x5
## para una mina, 4x4 para un puesto de caza/recolección).
func verificar_pendiente(esquina: Vector2i, ancho: int = TAMANO_HUELLA, alto: int = TAMANO_HUELLA) -> bool:
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			var altura: int = _generador.altura_en(x, z)
			if x + 1 < esquina.x + ancho:
				if abs(altura - _generador.altura_en(x + 1, z)) > LIMITE_PENDIENTE:
					return false
			if z + 1 < esquina.y + alto:
				if abs(altura - _generador.altura_en(x, z + 1)) > LIMITE_PENDIENTE:
					return false
	return true


func altura_objetivo(esquina: Vector2i, ancho: int = TAMANO_HUELLA, alto: int = TAMANO_HUELLA) -> int:
	var maximo: int = _generador.altura_en(esquina.x, esquina.y)
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			maximo = max(maximo, _generador.altura_en(x, z))
	return maximo


func calcular_relleno(esquina: Vector2i, ancho: int = TAMANO_HUELLA, alto: int = TAMANO_HUELLA) -> Dictionary:
	var objetivo: int = altura_objetivo(esquina, ancho, alto)
	var relleno: Dictionary = {}
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			var faltante: int = objetivo - _generador.altura_en(x, z)
			if faltante > 0:
				relleno[Vector2i(x, z)] = faltante
	return relleno
```

- [ ] **Step 2: Agregar pruebas de huella no cuadrada y de compatibilidad hacia atrás**

En `godot/scripts/NiveladorTerrenoTest.gd`, antes de la línea final `print("\n=== Las 4 pruebas...")`, insertar:

```gdscript
	print("\n=== TEST 5: verificar_pendiente() con ancho/alto explícitos (huella 4x3, no cuadrada) ===")
	# Rampa suave: altura_en(x,z) = z. Huella ancho=4, alto=3 desde (0,0): z
	# va de 0 a 2 (pendiente de 1 por celda, dentro del límite de 2) -> válida.
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0), 4, 3))
	# Rampa pronunciada (altura_en = z*3): cualquier huella con alto>=2 sigue
	# rechazándose.
	assert(not nivelador_pronunciado.verificar_pendiente(Vector2i(0, 0), 4, 3))

	print("\n=== TEST 6: llamar sin ancho/alto sigue siendo la huella cuadrada de siempre ===")
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0)) \
			== nivelador_suave.verificar_pendiente(Vector2i(0, 0), NiveladorTerreno.TAMANO_HUELLA, NiveladorTerreno.TAMANO_HUELLA))
```

y cambiar:

```gdscript
	print("\n=== Las 4 pruebas de NiveladorTerreno pasaron correctamente ===")
```

a:

```gdscript
	print("\n=== Las 6 pruebas de NiveladorTerreno pasaron correctamente ===")
```

- [ ] **Step 3: Correr las pruebas y verificar que pasan**

`mcp__godot__run_project` (scene: `scenes/NiveladorTerrenoTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.
Esperado: `"=== Las 6 pruebas de NiveladorTerreno pasaron correctamente ==="`, sin asserts fallidos.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/NiveladorTerreno.gd godot/scripts/NiveladorTerrenoTest.gd
git commit -m "feat: NiveladorTerreno acepta huellas no cuadradas (ancho/alto)"
```

---

### Task 4: `VoxelWorld.gd` — validación de huella libre (madera/follaje/estructura)

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `altura_en(x, z)`, `obtener_tipo(celda)`, `es_celda_estructural(celda)` (ya existen en el mismo archivo).
- Produces: `verificar_huella_libre(esquina: Vector2i, ancho: int, alto: int) -> Dictionary` (`{"valida": bool, "follaje_a_eliminar": Array[Vector3i]}`) — usada por Task 7.

- [ ] **Step 1: Agregar `verificar_huella_libre()`**

En `godot/scripts/VoxelWorld.gd`, inmediatamente después de la función `es_celda_estructural()` (que termina en `return colocado_por_jugador.get(celda, false) and TIPOS_ESTRUCTURA.has(obtener_tipo(celda))`), agregar:

```gdscript
## Revisa cada columna (x, z) de la huella ancho×alto con esquina "esquina":
## examina el bloque inmediatamente sobre el terreno real (altura_en(x, z) +
## 1). "madera" (tronco de árbol) o cualquier bloque estructural de un
## edificio del jugador (es_celda_estructural()) invalida la huella
## completa. "follaje" no invalida — se acumula en follaje_a_eliminar para
## que el llamador lo borre al confirmar la colocación (es cosmético, no un
## recurso — ver GDD Sección 3, "Emplazamiento Dentro de un Bosque"). Usada
## por la validación de choques de los puestos periféricos (CamaraCenital.gd)
## — no conoce Recoleccion.puestos, solo bloques reales del GridMap.
func verificar_huella_libre(esquina: Vector2i, ancho: int, alto: int) -> Dictionary:
	var valida := true
	var follaje_a_eliminar: Array[Vector3i] = []
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			var y: int = altura_en(x, z) + 1
			var celda := Vector3i(x, y, z)
			var tipo: String = obtener_tipo(celda)
			if tipo == "madera" or es_celda_estructural(celda):
				valida = false
			elif tipo == "follaje":
				follaje_a_eliminar.append(celda)
	return {"valida": valida, "follaje_a_eliminar": follaje_a_eliminar}
```

- [ ] **Step 2: Agregar el test (TEST 16) en `BlueprintValidatorTest.gd`**

En `godot/scripts/BlueprintValidatorTest.gd`, antes de la línea final `print("\n=== Las 15 pruebas de BlueprintValidator pasaron correctamente ===")`, insertar:

```gdscript
	print("\n=== TEST 16: verificar_huella_libre() detecta madera, follaje y estructura ===")
	const OX7 := 500

	# Huella A: "madera" invalida la huella completa.
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(OX7 + dx, 0, OX7 + dz), "piso")
	mundo.colocar_bloque(Vector3i(OX7, 1, OX7), "madera")
	var resultado_madera: Dictionary = mundo.verificar_huella_libre(Vector2i(OX7, OX7), 4, 4)
	assert(not resultado_madera["valida"])

	# Huella B: "follaje" no invalida, se acumula para eliminar.
	var base_b := OX7 + 20
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(base_b + dx, 0, OX7 + dz), "piso")
	mundo.colocar_bloque(Vector3i(base_b + 1, 1, OX7), "follaje")
	var resultado_follaje: Dictionary = mundo.verificar_huella_libre(Vector2i(base_b, OX7), 4, 4)
	assert(resultado_follaje["valida"])
	assert(resultado_follaje["follaje_a_eliminar"].size() == 1)
	assert(resultado_follaje["follaje_a_eliminar"][0] == Vector3i(base_b + 1, 1, OX7))

	# Huella C: un bloque estructural del jugador ("pared") invalida la huella.
	var base_c := OX7 + 40
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(base_c + dx, 0, OX7 + dz), "piso")
	mundo.colocar_bloque(Vector3i(base_c + 2, 1, OX7), "pared", true)
	var resultado_estructura: Dictionary = mundo.verificar_huella_libre(Vector2i(base_c, OX7), 4, 4)
	assert(not resultado_estructura["valida"])

	# Huella D: sin nada encima — válida, sin follaje que eliminar.
	var base_d := OX7 + 60
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(base_d + dx, 0, OX7 + dz), "piso")
	var resultado_libre: Dictionary = mundo.verificar_huella_libre(Vector2i(base_d, OX7), 4, 4)
	assert(resultado_libre["valida"])
	assert(resultado_libre["follaje_a_eliminar"].is_empty())

	print("OK: madera/estructura invalidan la huella, follaje se acumula sin invalidar, huella limpia queda válida.")
```

y cambiar esa línea final a:

```gdscript
	print("\n=== Las 16 pruebas de BlueprintValidator pasaron correctamente ===")
```

También actualizar el comentario de cabecera del archivo (líneas 17-20, que enumera los tests) agregando una frase sobre el TEST 16, y la línea `## panel "Output": debe imprimir los 15 tests...` a `16 tests`.

- [ ] **Step 3: Correr las pruebas y verificar que pasan**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`.
Esperado: `"=== Las 16 pruebas de BlueprintValidator pasaron correctamente ==="`, sin asserts fallidos, solo el warning preexistente de `BlueprintValidatorTest.gd:3`.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: VoxelWorld.verificar_huella_libre() valida choques de huella"
```

---

### Task 5: Bloque `"puesto_caza"` en la MeshLibrary

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Modify (generado, no a mano): `godot/assets/BlockLibrary.res`

**Interfaces:**
- Consumes: patrón ya usado por `"mina"`/`"agua"`/etc. en el mismo archivo.
- Produces: bloque `"puesto_caza"` disponible vía `VoxelWorld.colocar_bloque(celda, "puesto_caza")` — usado por Task 7.

- [ ] **Step 1: Agregar el sub_resource y el nodo del bloque**

En `godot/scenes/BlockLibrarySource.tscn`, inmediatamente después del bloque de `"mina"` (`[sub_resource type="StandardMaterial3D" id="Mat_mina"]` ... `[sub_resource type="BoxShape3D" id="Shape_mina"]`), agregar un nuevo sub_resource con un color distintivo (verde oliva, para diferenciarlo del amarillo de la mina y del verde más claro del follaje):

```
[sub_resource type="StandardMaterial3D" id="Mat_puesto_caza"]
albedo_color = Color(0.55, 0.5, 0.15, 1)

[sub_resource type="BoxMesh" id="Mesh_puesto_caza"]
material = SubResource("Mat_puesto_caza")

[sub_resource type="BoxShape3D" id="Shape_puesto_caza"]
```

Y, junto al nodo `[node name="mina" ...]` (en la sección de nodos, al final del archivo), agregar:

```
[node name="puesto_caza" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_puesto_caza")

[node name="CollisionShape3D" type="CollisionShape3D" parent="puesto_caza"]
shape = SubResource("Shape_puesto_caza")
```

- [ ] **Step 2: Guardar la escena y regenerar la MeshLibrary**

Usar `mcp__godot__save_scene` (`projectPath: "C:\Users\peraz\Projects\Misc\CityCraft\godot"`, `scenePath: "scenes/BlockLibrarySource.tscn"`), luego `mcp__godot__export_mesh_library` (`projectPath` igual, `scenePath: "scenes/BlockLibrarySource.tscn"`, `outputPath: "assets/BlockLibrary.res"`).

- [ ] **Step 3: Verificar que el bloque nuevo se puede colocar**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`. Debe seguir imprimiendo `"=== Las 16 pruebas de BlueprintValidator pasaron correctamente ==="` (el bloque nuevo no afecta ningún test existente, solo confirma que la `MeshLibrary` sigue cargando sin errores tras el cambio).

Adicionalmente, correr `scenes/Main.tscn` de la misma forma y confirmar en `errors` que no aparece ningún error nuevo (solo los 2 warnings preexistentes).

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res
git commit -m "feat: agregar bloque placeholder 'puesto_caza' a la MeshLibrary"
```

---

### Task 6: `HUD.gd` — ficha del puesto de caza/recolección

**Files:**
- Modify: `godot/scenes/Main.tscn`
- Modify: `godot/scripts/HUD.gd`

**Interfaces:**
- Consumes: `Recoleccion.COSTO_CONSTRUCCION_CAZA_RECOLECCION`, `PERSONAL_MAXIMO_CAZA_RECOLECCION`, `CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION` (Task 2).
- Produces: `HUD.mostrar_ficha_caza() -> void`, `HUD.actualizar_tasas_caza(tasas: Dictionary) -> void`, `HUD.ocultar_ficha_caza() -> void` — usadas por Task 7.

- [ ] **Step 1: Agregar el nodo `CazaFicha` a `Main.tscn`**

En `godot/scenes/Main.tscn`, inmediatamente después del bloque de `TasasLabel` de `MinaFicha` (líneas 105-107: `[node name="TasasLabel" type="Label" parent="HUDLayer/MinaFicha"]` / `layout_mode = 2` / `autowrap_mode = 2`), agregar:

```
[node name="CazaFicha" type="VBoxContainer" parent="HUDLayer"]
visible = false
offset_left = 12.0
offset_top = 160.0
offset_right = 320.0
offset_bottom = 280.0

[node name="CostoLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2

[node name="PersonalLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2

[node name="AlmacenamientoLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2

[node name="TasasLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2
autowrap_mode = 2
```

(Mismos offsets que `MinaFicha` — nunca se muestran a la vez, ya que los modos de colocación son mutuamente excluyentes.)

- [ ] **Step 2: Agregar las referencias `@onready` y las 3 funciones en `HUD.gd`**

En `godot/scripts/HUD.gd`, tras la línea `@onready var mina_tasas_label: Label = $MinaFicha/TasasLabel`, agregar:

```gdscript
@onready var caza_ficha: VBoxContainer = $CazaFicha
@onready var caza_costo_label: Label = $CazaFicha/CostoLabel
@onready var caza_personal_label: Label = $CazaFicha/PersonalLabel
@onready var caza_almacenamiento_label: Label = $CazaFicha/AlmacenamientoLabel
@onready var caza_tasas_label: Label = $CazaFicha/TasasLabel
```

Y, al final del archivo (después de `func ocultar_ficha_mina()`), agregar:

```gdscript
## Mismo patrón que mostrar_ficha_mina(): valores FIJOS al activar el modo
## (no cambian según la posición del cursor); las tasas sí varían — ver
## actualizar_tasas_caza().
func mostrar_ficha_caza() -> void:
	var partes_costo: Array = []
	for tipo in Recoleccion.COSTO_CONSTRUCCION_CAZA_RECOLECCION:
		partes_costo.append("%d %s" % [Recoleccion.COSTO_CONSTRUCCION_CAZA_RECOLECCION[tipo], tipo])
	caza_costo_label.text = "Costo: %s" % ", ".join(partes_costo)
	caza_personal_label.text = "Personal máximo: %d" % Recoleccion.PERSONAL_MAXIMO_CAZA_RECOLECCION
	caza_almacenamiento_label.text = "Almacenamiento: %d" % Recoleccion.CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION
	caza_tasas_label.text = "Recolección prevista: -"
	caza_ficha.visible = true


## Recalculada en vivo cada fotograma mientras el modo colocar-puesto (tipo
## "caza_recoleccion") está activo, a partir de
## Recoleccion.tasas_caza_recoleccion(). "tasas" siempre tiene ambas claves
## ("caza"/"recoleccion", ver Recoleccion.gd) — el caso "sin nada detectado"
## se distingue por ambos valores en 0.0, no por un diccionario vacío.
func actualizar_tasas_caza(tasas: Dictionary) -> void:
	if tasas.get("caza", 0.0) <= 0.0 and tasas.get("recoleccion", 0.0) <= 0.0:
		caza_tasas_label.text = "Recolección prevista: sin fauna ni fruta detectada"
		return
	var nombres := {"caza": "caza", "recoleccion": "recolección"}
	var lineas: Array = []
	for tipo in tasas:
		lineas.append("%.1f comida/h por %s" % [tasas[tipo], nombres.get(tipo, tipo)])
	caza_tasas_label.text = "Recolección prevista por ciudadano:\n  " + "\n  ".join(lineas)


func ocultar_ficha_caza() -> void:
	caza_ficha.visible = false
```

- [ ] **Step 3: Verificar que `Main.tscn` sigue cargando sin errores**

`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`. Esperado en `errors`: solo los 2 warnings preexistentes (`BlueprintValidator`/`Player` con el mismo nombre que su clase global) — nada relacionado con `CazaFicha`/`HUD.gd` (un typo en `$CazaFicha` fallaría aquí con un error de nodo no encontrado al primer `_process()`).

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/Main.tscn godot/scripts/HUD.gd
git commit -m "feat: ficha del puesto de caza/recolección en el HUD"
```

---

### Task 7: `CamaraCenital.gd` — modo de colocación genérico con huella, rotación y validación

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes: `Recoleccion.ANCHO_HUELLA_MINA/ALTO_HUELLA_MINA/ANCHO_HUELLA_CAZA_RECOLECCION/ALTO_HUELLA_CAZA_RECOLECCION` (Task 1/2), `Recoleccion.colocar_puesto()/celda_dentro_de_algun_puesto()/detectar_recursos()/tasas_recoleccion()/detectar_fauna_frutal()/tasas_caza_recoleccion()` (Task 1/2), `NiveladorTerreno.verificar_pendiente(esquina, ancho, alto)` (Task 3), `VoxelWorld.verificar_huella_libre(esquina, ancho, alto)` (Task 4), bloque `"puesto_caza"` (Task 5), `HUD.mostrar_ficha_caza()/actualizar_tasas_caza()/ocultar_ficha_caza()` (Task 6).
- Produces: nada consumido por otro archivo — es la integración final. `salir_de_todos_los_modos()` mantiene su firma pública (la llama `Main.gd`).

Este archivo no tiene pruebas automatizadas (lógica de cámara/input, sin framework de test para eso en este repo — mismo criterio que el resto de `CamaraCenital.gd`); la verificación es headless (sin errores nuevos al cargar) más una nota de verificación manual para el usuario al final de la tarea.

- [ ] **Step 1: Reemplazar el estado de "modo mina" por el estado genérico de "modo puesto"**

En `godot/scripts/CamaraCenital.gd`, reemplazar:

```gdscript
const COLOR_MINA_VALIDA := Color(1.0, 0.85, 0.0, 0.4)
const COLOR_MINA_INVALIDA := Color(1.0, 0.2, 0.2, 0.4)
const MITAD_HUELLA := 2  # (NiveladorTerreno.TAMANO_HUELLA - 1) / 2, para una huella de 5x5
```

por:

```gdscript
const COLOR_PUESTO_VALIDO := Color(1.0, 0.85, 0.0, 0.4)
const COLOR_PUESTO_INVALIDO := Color(1.0, 0.2, 0.2, 0.4)

## Sigue usada SOLO por la huella fantasma del modo de nivelación manual
## (_actualizar_huella_fantasma(), sin cambios en esta tarea) — el modo de
## colocación de puestos ya NO la usa, calcula su propio centrado con
## _ancho_puesto_activo/_alto_puesto_activo (ver _actualizar_previsualizacion_puesto()).
const MITAD_HUELLA := 2  # (NiveladorTerreno.TAMANO_HUELLA - 1) / 2, para una huella de 5x5

## El mayor ancho/alto entre los tipos de puesto existentes (mina 5x5, caza
## y recolección 4x4) — tamaño del pool de planos fantasma reutilizable
## entre cualquier tipo (ver _crear_huella_puesto()).
const MAX_ANCHO_HUELLA_PUESTO := 5
const MAX_ALTO_HUELLA_PUESTO := 5
```

**Importante:** a diferencia de `_disco_mina`/`_offsets_disco_mina` (que sí se eliminan por completo, ver Step 2), `MITAD_HUELLA` NO se borra — sigue en uso por `_actualizar_huella_fantasma()` (modo de nivelación, intacto en esta tarea).

Reemplazar:

```gdscript
## Modo de colocación de mina (tecla `M`): un disco fantasma (radio
## Recoleccion.RADIO_AREA_MINA, precalculado en offsets circulares) sigue la
## celda bajo el cursor, dorado si es válida (fuera de la zona de influencia)
## o rojo si no. Mientras el modo está activo, la ficha del HUD se actualiza
## cada fotograma con los recursos reales detectados en esa posición.
var modo_colocar_mina := false
var _disco_mina: Array[MeshInstance3D] = []
var _offsets_disco_mina: Array[Vector2i] = []
```

por:

```gdscript
## Modo de colocación de puesto periférico (mina: tecla `M`; caza y
## recolección: tecla `H`) — un rectángulo fantasma de
## _ancho_puesto_activo x _alto_puesto_activo celdas sigue la celda bajo el
## cursor (esa celda es su CENTRO, igual que la huella de nivelación),
## dorado si las 3 validaciones (zona de influencia, relieve, huella libre +
## sin choque con otro puesto) pasan, o rojo si alguna falla. `Ctrl` + rueda
## del mouse rota la huella 90° (intercambia ancho/alto) — ver
## _rotar_huella_puesto(). Mientras el modo está activo, la ficha del HUD
## correspondiente al tipo se actualiza cada fotograma.
var modo_colocar_puesto := false
var _tipo_puesto_activo := ""  # "mina" | "caza_recoleccion"
var _ancho_puesto_activo := 0
var _alto_puesto_activo := 0
var _huella_rotada := false
var _huella_puesto: Array[MeshInstance3D] = []
```

- [ ] **Step 2: Reemplazar `_crear_disco_mina()` por `_crear_huella_puesto()` y actualizar `_ready()`**

Reemplazar la función completa:

```gdscript
func _crear_disco_mina() -> void:
	for dx in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx, dz).length() <= Recoleccion.RADIO_AREA_MINA:
				_offsets_disco_mina.append(Vector2i(dx, dz))

	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	for i in range(_offsets_disco_mina.size()):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_MINA_VALIDA
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = false
		add_child(plano)
		_disco_mina.append(plano)
```

por:

```gdscript
## Pool de planos fantasma de tamaño fijo (MAX_ANCHO_HUELLA_PUESTO x
## MAX_ALTO_HUELLA_PUESTO), reutilizado por cualquier tipo de puesto — mismo
## patrón de pool que _crear_huella_fantasma(), para no generar basura de
## nodos cada fotograma. Solo se muestran/reposicionan los primeros
## ancho*alto planos de la huella activa (ver _mostrar_huella_puesto()); el
## resto del pool queda oculto.
func _crear_huella_puesto() -> void:
	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	for i in range(MAX_ANCHO_HUELLA_PUESTO * MAX_ALTO_HUELLA_PUESTO):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_PUESTO_VALIDO
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = false
		add_child(plano)
		_huella_puesto.append(plano)
```

En `_ready()`, reemplazar la línea `_crear_disco_mina()` por `_crear_huella_puesto()`.

- [ ] **Step 3: Reemplazar `_alternar_modo_colocar_mina()`/`_salir_de_modo_colocar_mina()`/`_mostrar_disco_mina()` por las versiones genéricas**

Reemplazar el bloque completo:

```gdscript
func _alternar_modo_colocar_mina() -> void:
	modo_colocar_mina = not modo_colocar_mina
	# Ver el comentario equivalente en _alternar_modo_nivelacion().
	if modo_colocar_mina and modo_nivelacion:
		_salir_de_modo_nivelacion()
	_mostrar_disco_mina(modo_colocar_mina)
	if modo_colocar_mina:
		hud.mostrar_ficha_mina()
		print("Modo colocar mina activo: haz clic fuera de la zona de influencia para confirmar (M de nuevo para cancelar).")
	else:
		# _salir_de_modo_colocar_mina() vuelve a poner modo_colocar_mina = false
		# (ya lo está, redundante pero inofensivo) además de ocultar el disco y
		# la ficha del HUD — reutilizado aquí para no duplicar esas dos líneas
		# (mismo patrón que _alternar_modo_nivelacion() con
		# _salir_de_modo_nivelacion()).
		_salir_de_modo_colocar_mina()
		print("Modo colocar mina cancelado.")


func _salir_de_modo_colocar_mina() -> void:
	modo_colocar_mina = false
	_mostrar_disco_mina(false)
	hud.ocultar_ficha_mina()
```

por:

```gdscript
## Activa el modo de colocación del puesto "tipo" (huella ancho x alto). Si
## ya estaba activo ESE MISMO tipo, lo cancela (mismo toggle que antes tenía
## _alternar_modo_colocar_mina()); si estaba activo otro tipo, cambia
## directamente al nuevo sin necesidad de cancelar primero. Reemplaza
## _alternar_modo_colocar_mina() — M y H llaman a esta misma función con su
## tipo/huella respectivos (ver _unhandled_input()).
func _alternar_modo_colocar_puesto(tipo: String, ancho: int, alto: int) -> void:
	if modo_colocar_puesto and _tipo_puesto_activo == tipo:
		_salir_de_modo_colocar_puesto()
		print("Modo colocar %s cancelado." % tipo)
		return
	# Ver el comentario equivalente en _alternar_modo_nivelacion(): los modos
	# son mutuamente excluyentes.
	if modo_nivelacion:
		_salir_de_modo_nivelacion()
	hud.ocultar_ficha_mina()
	hud.ocultar_ficha_caza()
	modo_colocar_puesto = true
	_tipo_puesto_activo = tipo
	_ancho_puesto_activo = ancho
	_alto_puesto_activo = alto
	_huella_rotada = false
	_mostrar_huella_puesto(true)
	if tipo == "mina":
		hud.mostrar_ficha_mina()
	else:
		hud.mostrar_ficha_caza()
	print("Modo colocar %s activo: haz clic para confirmar (misma tecla de nuevo para cancelar)." % tipo)


func _salir_de_modo_colocar_puesto() -> void:
	modo_colocar_puesto = false
	_mostrar_huella_puesto(false)
	hud.ocultar_ficha_mina()
	hud.ocultar_ficha_caza()
	_tipo_puesto_activo = ""


## Ctrl + rueda del mouse, solo con un puesto en modo colocación: rota la
## huella activa 90° (intercambia ancho/alto). Sin efecto visible en mina
## (5x5) ni caza/recolección (4x4) — ambas cuadradas — hasta que exista un
## puesto con huella no cuadrada (p. ej. un futuro maderero, 3x4).
func _rotar_huella_puesto() -> void:
	_huella_rotada = not _huella_rotada
	var ancho_previo := _ancho_puesto_activo
	_ancho_puesto_activo = _alto_puesto_activo
	_alto_puesto_activo = ancho_previo
	_mostrar_huella_puesto(true)
```

Reemplazar la función:

```gdscript
func _mostrar_disco_mina(visible_ahora: bool) -> void:
	for plano in _disco_mina:
		plano.visible = visible_ahora
```

por:

```gdscript
## Muestra los primeros _ancho_puesto_activo * _alto_puesto_activo planos
## del pool (ver _crear_huella_puesto()) y oculta el resto; con
## visible_ahora=false oculta todo el pool.
func _mostrar_huella_puesto(visible_ahora: bool) -> void:
	for plano in _huella_puesto:
		plano.visible = false
	if not visible_ahora:
		return
	for i in range(_ancho_puesto_activo * _alto_puesto_activo):
		_huella_puesto[i].visible = true
```

- [ ] **Step 4: Reemplazar `_actualizar_previsualizacion_mina()` y `_procesar_clic_mina()` por las versiones genéricas**

Reemplazar la función completa:

```gdscript
func _actualizar_previsualizacion_mina() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var valida: bool = not Zonificacion.dentro_de_influencia(centro)
	var color: Color = COLOR_MINA_VALIDA if valida else COLOR_MINA_INVALIDA

	for i in range(_offsets_disco_mina.size()):
		var offset: Vector2i = _offsets_disco_mina[i]
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		var altura_celda: int = mundo.altura_en(x, z)
		var plano: MeshInstance3D = _disco_mina[i]
		var material: StandardMaterial3D = plano.material_override
		material.albedo_color = color
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE, z + DESF)

	var altura_superficie: int = mundo.altura_en(centro.x, centro.y)
	var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
	var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo)
	hud.actualizar_tasas_mina(tasas)
```

por:

```gdscript
## true si algún punto de la huella (ancho x alto activos, esquina
## "esquina") cae dentro de un puesto ya colocado — recorre la huella
## completa contra Recoleccion.celda_dentro_de_algun_puesto() (no basta
## revisar solo las esquinas, sería incorrecto para un rectángulo genérico).
func _huella_choca_con_otro_puesto(esquina: Vector2i) -> bool:
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			if Recoleccion.celda_dentro_de_algun_puesto(Vector2i(esquina.x + dx, esquina.y + dz)):
				return true
	return false


## Recalcula la posición/color de la huella activa según la celda bajo el
## cursor (esa celda es su CENTRO) y la ficha del HUD correspondiente al
## tipo activo. Reemplaza _actualizar_previsualizacion_mina() — ahora
## genérica sobre _tipo_puesto_activo/_ancho_puesto_activo/_alto_puesto_activo.
func _actualizar_previsualizacion_puesto() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)

	var fuera_de_influencia: bool = not Zonificacion.dentro_de_influencia(centro)
	var relieve_valido: bool = nivelador.verificar_pendiente(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var i := 0
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			var x: int = esquina.x + dx
			var z: int = esquina.y + dz
			var altura_celda: int = mundo.altura_en(x, z)
			var plano: MeshInstance3D = _huella_puesto[i]
			var material: StandardMaterial3D = plano.material_override
			material.albedo_color = color
			plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE, z + DESF)
			i += 1

	if _tipo_puesto_activo == "mina":
		var altura_superficie: int = mundo.altura_en(centro.x, centro.y)
		var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
		var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo)
		hud.actualizar_tasas_mina(tasas)
	else:
		var promedios: Dictionary = Recoleccion.detectar_fauna_frutal(mundo.generador, centro)
		var tasas_caza: Dictionary = Recoleccion.tasas_caza_recoleccion(promedios)
		hud.actualizar_tasas_caza(tasas_caza)
```

Reemplazar la función completa:

```gdscript
func _procesar_clic_mina(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if Zonificacion.dentro_de_influencia(celda):
		print("No se puede colocar una mina dentro de la zona de influencia.")
		return

	var altura_superficie: int = mundo.altura_en(celda.x, celda.y)
	mundo.colocar_bloque(Vector3i(celda.x, altura_superficie + 1, celda.y), "mina")
	Recoleccion.colocar_mina(celda)
	print("Mina colocada en (", celda.x, ", ", celda.y, ").")

	_salir_de_modo_colocar_mina()
```

por:

```gdscript
## Confirma la colocación del puesto activo en la celda bajo el cursor si
## las 4 validaciones (zona de influencia, relieve, huella libre, sin choque
## con otro puesto) pasan — si no, imprime el motivo y PERMANECE en modo
## colocar-puesto (a diferencia de la nivelación, que siempre sale tras un
## clic; aquí el jugador puede reintentar de inmediato, igual que la mina
## original). El follaje detectado se elimina, y el marcador se coloca en
## cada celda de la huella A SU PROPIA altura real (no una altura uniforme
## — mismo criterio por-celda que ZonaOverlay), porque colocar_bloque()
## rechaza celdas ya ocupadas (la de superficie ya tiene "piso").
func _procesar_clic_puesto(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)

	if Zonificacion.dentro_de_influencia(centro):
		print("No se puede colocar un puesto dentro de la zona de influencia.")
		return
	if not nivelador.verificar_pendiente(esquina, _ancho_puesto_activo, _alto_puesto_activo):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina):
		print("Colocación rechazada: la huella choca con un puesto ya colocado.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.set_cell_item(celda_follaje, GridMap.INVALID_CELL_ITEM)

	var bloque_marcador: String = "mina" if _tipo_puesto_activo == "mina" else "puesto_caza"
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			var x: int = esquina.x + dx
			var z: int = esquina.y + dz
			var altura_local: int = mundo.altura_en(x, z)
			mundo.colocar_bloque(Vector3i(x, altura_local + 1, z), bloque_marcador)

	Recoleccion.colocar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo)
	print("Puesto '%s' colocado en (%d, %d)." % [_tipo_puesto_activo, esquina.x, esquina.y])

	_salir_de_modo_colocar_puesto()
```

- [ ] **Step 5: Actualizar `_unhandled_input()` (teclas M/H, rotación con Ctrl+rueda, clic izquierdo)**

Reemplazar:

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_nivelacion()
		elif tecla.pressed and tecla.keycode == KEY_M:
			_alternar_modo_colocar_mina()

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_nivelacion:
				_procesar_clic_nivelacion(boton.position)
			elif modo_colocar_mina:
				_procesar_clic_mina(boton.position)
			else:
				_procesar_clic(boton.position)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_UP:
			_intentar_zoom(-VELOCIDAD_ZOOM)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_intentar_zoom(VELOCIDAD_ZOOM)
```

por:

```gdscript
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_nivelacion()
		elif tecla.pressed and tecla.keycode == KEY_M:
			_alternar_modo_colocar_puesto("mina", Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
		elif tecla.pressed and tecla.keycode == KEY_H:
			_alternar_modo_colocar_puesto("caza_recoleccion", Recoleccion.ANCHO_HUELLA_CAZA_RECOLECCION, Recoleccion.ALTO_HUELLA_CAZA_RECOLECCION)

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_nivelacion:
				_procesar_clic_nivelacion(boton.position)
			elif modo_colocar_puesto:
				_procesar_clic_puesto(boton.position)
			else:
				_procesar_clic(boton.position)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_UP:
			if modo_colocar_puesto and Input.is_key_pressed(KEY_CTRL):
				_rotar_huella_puesto()
			else:
				_intentar_zoom(-VELOCIDAD_ZOOM)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if modo_colocar_puesto and Input.is_key_pressed(KEY_CTRL):
				_rotar_huella_puesto()
			else:
				_intentar_zoom(VELOCIDAD_ZOOM)
```

- [ ] **Step 6: Actualizar `_process()`, `_alternar_modo_nivelacion()` y `salir_de_todos_los_modos()`**

En `_process()`, reemplazar las 2 apariciones de:

```gdscript
		elif modo_colocar_mina:
			_actualizar_previsualizacion_mina()
```

por:

```gdscript
		elif modo_colocar_puesto:
			_actualizar_previsualizacion_puesto()
```

(Una está dentro del bloque `if paneo == Vector2.ZERO and not orbita_o_inclina and vuelo == 0.0: ... return`, la otra al final de `_process()`, después de aplicar el movimiento de cámara — ambas deben cambiar igual.)

En `_alternar_modo_nivelacion()`, reemplazar:

```gdscript
	if modo_nivelacion and modo_colocar_mina:
		_salir_de_modo_colocar_mina()
```

por:

```gdscript
	if modo_nivelacion and modo_colocar_puesto:
		_salir_de_modo_colocar_puesto()
```

En `salir_de_todos_los_modos()`, reemplazar:

```gdscript
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_nivelacion()
	_salir_de_modo_colocar_mina()
```

por:

```gdscript
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_nivelacion()
	_salir_de_modo_colocar_puesto()
```

- [ ] **Step 7: Actualizar el comentario de cabecera del archivo**

En el bloque de comentarios al inicio del archivo (líneas ~31-36), reemplazar:

```gdscript
## - Colocación de minas (tecla `M`, ver GDD Sección 3 y
##   docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md):
##   disco de previsualización del área de acción, ficha en vivo en el HUD,
##   confirma solo fuera de la zona de influencia.
```

por:

```gdscript
## - Colocación de puestos periféricos con huella real (mina: tecla `M`;
##   caza y recolección: tecla `H`; ver GDD Sección 3 y
##   docs/superpowers/specs/2026-09-10-puestos-huella-real-caza-recoleccion-design.md):
##   huella fantasma de N×M celdas, rotable 90° con Ctrl+rueda del mouse,
##   ficha en vivo en el HUD, confirma solo si pasan las 4 validaciones
##   (zona de influencia, relieve, huella libre de madera/estructura, sin
##   choque con otro puesto).
```

- [ ] **Step 8: Verificar que `Main.tscn` carga sin errores nuevos**

`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project`. Esperado en `errors`: solo los 2 warnings preexistentes.

- [ ] **Step 9: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: colocación genérica de puestos con huella real, rotación y validación de choques"
```

---

### Task 8: Documentación — actualizar el técnico de PoC 5

**Files:**
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`

**Interfaces:**
- Consumes: nada (solo documentación).
- Produces: nada.

- [ ] **Step 1: Documentar la huella real + el puesto de caza/recolección**

En `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`, en la sección del sub-proyecto 3 (donde se documentó la mina — buscar el párrafo que empieza con `**Alcance reducido, decidido explícitamente:**`), agregar un párrafo nuevo inmediatamente después del párrafo que documenta la conexión de tala a `Player.gd` (el que termina en `"...todo funciona correctamente."`, agregado en la sesión anterior sobre overlays bajo el agua):

```markdown
**Huella real + puesto de caza/recolección (spec: `docs/superpowers/specs/2026-09-10-puestos-huella-real-caza-recoleccion-design.md`):** los puestos periféricos dejan de representarse con un solo bloque marcador — ahora tienen una huella real de N×M celdas (mina 5×5, caza/recolección 4×4; el maderero, sin puesto jugable todavía, queda con su huella de 3×4 documentada como constante). `Recoleccion.puestos` pasa a indexarse por la esquina de la huella, no por un punto único, para poder validar choques entre puestos de cualquier tipo (`celda_dentro_de_algun_puesto()`). La colocación ahora valida 4 condiciones (antes 1): fuera de la zona de influencia, relieve dentro del límite de pendiente (`NiveladorTerreno.verificar_pendiente()`, generalizado a huellas no cuadradas), huella libre de madera/estructura (`VoxelWorld.verificar_huella_libre()`, nuevo — implementa por primera vez la regla ya documentada en el GDD Sección 3 de que el follaje se elimina pero la madera/estructura rechaza), y sin choque con otro puesto. `Ctrl` + rueda del mouse rota la huella 90° — sin efecto visible en mina/caza-recolección (ambas cuadradas) hasta que exista un puesto con huella no cuadrada.

El puesto nuevo de **caza y recolección** (tecla `H`) es un solo edificio que cubre ambas funciones (decisión del usuario: no dos edificios separados), a partir de las señales `densidad_fauna_en()`/`densidad_frutal_en()` ya existentes (ver 3.11) — `Recoleccion.detectar_fauna_frutal()` promedia ambas señales (muestreadas cada 2 celdas) dentro de un radio de 12 celdas, y `tasas_caza_recoleccion()` las convierte en dos tasas de comida independientes ("caza"/"recolección"), mostradas en una ficha nueva del HUD. El puesto de pesca/frutos del mar queda fuera de alcance (categoría de moral aparte, depende de una señal de peces que no existe).

`RecoleccionTest.gd` pasó de 5 a 9 pruebas, `NiveladorTerrenoTest.gd` de 4 a 6, `Test.tscn` de 15 a 16. Verificado sin errores nuevos vía MCP headless (`Test.tscn`, `Main.tscn`); la confirmación jugando en vivo (colocar una mina y un puesto de caza/recolección, ver que la huella sigue el relieve, que chocar con un árbol de madera la pone en rojo, que el follaje se limpia al confirmar, y que `Ctrl`+rueda no cambia nada visible en ninguna de las dos por ser cuadradas) queda pendiente del mismo patrón de verificación visual ya usado en el resto de esta PoC.
```

Y, en la lista de **Pendiente** de esa misma sección (la que menciona "ramas irregulares/ramificaciones reales... puestos madereros y de caza consumiendo estas señales/registros..."), quitar "puestos... de caza" de esa frase (ya no está pendiente) dejando solo "puestos madereros consumiendo estas señales/registros" y agregar al final: "puesto maderero jugable (huella 3×4 ya documentada, sin modo de colocación); puesto de pesca/frutos del mar (categoría de moral aparte, depende de una señal de peces que no existe)".

- [ ] **Step 2: Verificación final completa**

`mcp__godot__run_project` (scene: `scenes/Test.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 16 pruebas de `BlueprintValidator`).
`mcp__godot__run_project` (scene: `scenes/RecoleccionTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 9 pruebas).
`mcp__godot__run_project` (scene: `scenes/NiveladorTerrenoTest.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: 6 pruebas).
`mcp__godot__run_project` (scene: `scenes/Main.tscn`) → `mcp__godot__get_debug_output` → `mcp__godot__stop_project` (esperado: solo los 2 warnings preexistentes).

- [ ] **Step 3: Commit**

```bash
git add "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: registrar huellas reales de puestos y el puesto de caza/recolección"
```
