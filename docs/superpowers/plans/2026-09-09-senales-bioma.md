# Señales de Bioma, Fauna y Frutal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar a `GeneradorMundo.gd` un criterio de bioma único y dos señales numéricas de densidad (fauna, frutal) — la capa de datos que sub-proyectos futuros (árboles talables, NPCs de fauna, objetos frutal, puestos de caza/madereros) consumirán.

**Architecture:** Todo vive en `GeneradorMundo.gd` (clase pura `RefCounted`, sin nodos de escena, mismo patrón que el resto del archivo). `es_bioma_en(x,z)` es una función derivada de `es_agua_en`/`altura_en`/`nivel_mar` ya existentes, sin estado nuevo. Las dos densidades usan dos instancias nuevas de `FastNoiseLite` (mismo patrón que `_ruido_mineral`), remapeadas a `[0,1]` y enmascaradas a `0.0` fuera del bioma.

**Tech Stack:** Godot 4.7, GDScript, `FastNoiseLite` nativo.

**Spec:** `docs/superpowers/specs/2026-09-09-senales-bioma-design.md`

## Global Constraints

- Usa tabulaciones en GDScript (exigido por Godot).
- Conserva el español en comentarios, nombres de prueba y documentación.
- No edites `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- No agregues dependencias nuevas ni abstracciones especulativas.
- Sin curva de redistribución en las densidades (a diferencia de `altura_en()`) — remapeo lineal simple de `[-1,1]` a `[0,1]`, sin exponente que calibrar.
- Fuera de alcance (documentado en la spec, no implementar aquí): biomas diferenciados por humedad/temperatura, árboles procedurales con salud/tala, NPCs de fauna, objetos "frutal", puestos de caza/madereros.
- Verificación final: ejecutar `godot/scenes/Test.tscn` y `godot/scenes/GeneradorMundoTest.tscn` con Godot 4.7 (vía las herramientas `mcp__godot__*` disponibles en esta sesión) y confirmar que todas las aserciones pasan, sin errores nuevos.
- Ninguna otra parte del proyecto consume estas funciones todavía — nada más debería romperse ni cambiar de comportamiento.

---

## Contexto de archivos existentes (léelo antes de tocar código)

- `godot/scripts/GeneradorMundo.gd`: clase pura. Ya tiene `ALTURA_MINIMA := 0`, `ALTURA_MAXIMA := 15`, `nivel_mar: int` (propiedad pública calculada en `_init`), `es_agua_en(x, z) -> bool` (`altura_en(x, z) < nivel_mar`), `_ruido: FastNoiseLite` (relieve, semilla base) y `_ruido_mineral: FastNoiseLite` (vetas de hierro, semilla `semilla + 1`, frecuencia `0.05`). `_init(semilla, ancho_mundo, largo_mundo)` construye ambos ruidos y calcula `nivel_mar` al final.
- `godot/scripts/GeneradorMundoTest.gd`: 10 pruebas existentes (`TEST 1` a `TEST 10`), todas dentro de `ejecutar_pruebas()`, terminan con `print("\n=== Las 10 pruebas de GeneradorMundo pasaron correctamente ===")`. Se corre vía `godot/scenes/GeneradorMundoTest.tscn`.
- Ningún otro archivo del proyecto llama a `GeneradorMundo` con funciones nuevas — este plan no toca `VoxelWorld.gd` ni ninguna escena.

---

### Task 1: Criterio de bioma único (`es_bioma_en`)

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd`
- Modify: `godot/scripts/GeneradorMundoTest.gd`
- Test scene: `godot/scenes/GeneradorMundoTest.tscn`

**Interfaces:**
- Consumes: `altura_en(x, z) -> int`, `es_agua_en(x, z) -> bool`, `nivel_mar: int` (ya existentes, sin cambios de firma).
- Produces: `GeneradorMundo.BANDA_BIOMA` (constante pública `int`) y `GeneradorMundo.es_bioma_en(x: int, z: int) -> bool`, consumidos por la Task 2 de este mismo plan.

- [ ] **Step 1: Escribe la prueba que debe fallar**

Abre `godot/scripts/GeneradorMundoTest.gd`. Después del bloque del "TEST 10" (justo antes de la línea `print("\n=== Las 10 pruebas de GeneradorMundo pasaron correctamente ===")`), inserta:

```gdscript
	print("\n=== TEST 11: es_bioma_en coincide con tierra firme dentro de la banda sobre el nivel de mar ===")
	var gen_bioma: RefCounted = GeneradorMundoScript.new(321, 80, 80)
	for x in range(0, 80, 2):
		for z in range(0, 80, 2):
			var altura: int = gen_bioma.altura_en(x, z)
			var esperado: bool = (not gen_bioma.es_agua_en(x, z)) and altura <= gen_bioma.nivel_mar + GeneradorMundoScript.BANDA_BIOMA
			assert(gen_bioma.es_bioma_en(x, z) == esperado)
	print("OK: es_bioma_en() coincide con 'tierra firme y altura <= nivel_mar + BANDA_BIOMA' en todos los puntos muestreados.")
```

Y cambia esa línea final de `"Las 10 pruebas"` a `"Las 11 pruebas"`.

- [ ] **Step 2: Corre la escena y confirma que falla**

Usa `mcp__godot__run_project` con la escena `res://scenes/GeneradorMundoTest.tscn`, luego `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project`.
Esperado: error de script — `es_bioma_en` y `BANDA_BIOMA` no existen todavía en `GeneradorMundoScript` (p. ej. "Invalid call. Nonexistent function 'es_bioma_en'" o "Invalid get index 'BANDA_BIOMA'").

- [ ] **Step 3: Implementa el mínimo necesario**

En `godot/scripts/GeneradorMundo.gd`, agrega después de la constante `PERCENTIL_NIVEL_MAR` (antes del comentario de `nivel_mar`):

```gdscript
## Cuántas unidades de altura por encima de nivel_mar sigue habiendo bioma
## (vegetación/fauna) antes de volverse tierra estéril — ver es_bioma_en().
## Valor inicial calibrado empíricamente, mismo patrón que GROSOR_TIERRA/
## UMBRAL_HIERRO/EXPONENTE_RELIEVE: ajustar aquí si en el editor real la
## banda resulta demasiado angosta o demasiado ancha.
const BANDA_BIOMA := 4
```

Y agrega, después de `es_agua_en()` (al final del archivo):

```gdscript


## Verdadero si la columna (x, z) es tierra firme dentro de la banda de
## bioma (vegetación/fauna) sobre el nivel del mar — falso si es agua o si
## está por encima de esa banda (cumbres estériles). Único tipo de bioma
## por ahora (sin distinguir bosque/pradera/montaña); ver
## densidad_fauna_en()/densidad_frutal_en() para las señales que dependen
## de este criterio.
func es_bioma_en(x: int, z: int) -> bool:
	if es_agua_en(x, z):
		return false
	return altura_en(x, z) <= nivel_mar + BANDA_BIOMA
```

- [ ] **Step 4: Corre la escena y confirma que las 11 pruebas pasan**

Repite el Step 2. Esperado: se imprimen las 11 pruebas con "OK", termina con "Las 11 pruebas de GeneradorMundo pasaron correctamente", sin ningún "Assertion failed".

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: agregar criterio de bioma único (es_bioma_en)"
```

---

### Task 2: Señales de densidad de fauna y frutal

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd`
- Modify: `godot/scripts/GeneradorMundoTest.gd`
- Test scene: `godot/scenes/GeneradorMundoTest.tscn`

**Interfaces:**
- Consumes: `es_bioma_en(x, z) -> bool` (Task 1).
- Produces: `GeneradorMundo.densidad_fauna_en(x: int, z: int) -> float` y `GeneradorMundo.densidad_frutal_en(x: int, z: int) -> float`, ambas en `[0.0, 1.0]`. No hay más tareas en este plan que las consuman — son el punto de entrada para sub-proyectos futuros.

- [ ] **Step 1: Escribe las pruebas que deben fallar**

En `godot/scripts/GeneradorMundoTest.gd`, después del bloque del nuevo "TEST 11" y antes del `print` final, inserta:

```gdscript
	print("\n=== TEST 12: densidad_fauna_en y densidad_frutal_en son deterministas y están en [0,1] ===")
	var gen_dens_a: RefCounted = GeneradorMundoScript.new(444, 60, 60)
	var gen_dens_b: RefCounted = GeneradorMundoScript.new(444, 60, 60)
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var fauna_a: float = gen_dens_a.densidad_fauna_en(x, z)
			var fauna_b: float = gen_dens_b.densidad_fauna_en(x, z)
			assert(is_equal_approx(fauna_a, fauna_b))
			assert(fauna_a >= 0.0 and fauna_a <= 1.0)
			var frutal_a: float = gen_dens_a.densidad_frutal_en(x, z)
			var frutal_b: float = gen_dens_b.densidad_frutal_en(x, z)
			assert(is_equal_approx(frutal_a, frutal_b))
			assert(frutal_a >= 0.0 and frutal_a <= 1.0)
	print("OK: ambas densidades son deterministas para la misma semilla/grid y quedan siempre en [0,1].")

	print("\n=== TEST 13: densidad_fauna_en y densidad_frutal_en son 0.0 fuera del bioma ===")
	var gen_fuera: RefCounted = GeneradorMundoScript.new(888, 80, 80)
	var vio_fuera_de_bioma := false
	for x in range(0, 80, 2):
		for z in range(0, 80, 2):
			if not gen_fuera.es_bioma_en(x, z):
				vio_fuera_de_bioma = true
				assert(gen_fuera.densidad_fauna_en(x, z) == 0.0)
				assert(gen_fuera.densidad_frutal_en(x, z) == 0.0)
	assert(vio_fuera_de_bioma)
	print("OK: ambas densidades son exactamente 0.0 en toda columna fuera del bioma (al menos una encontrada en el muestreo).")

	print("\n=== TEST 14: las señales de bioma funcionan con los parámetros reales del mundo ===")
	var gen_real_bioma: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	for x in range(0, 200, 10):
		for z in range(0, 200, 10):
			var f: float = gen_real_bioma.densidad_fauna_en(x, z)
			var r: float = gen_real_bioma.densidad_frutal_en(x, z)
			assert(f >= 0.0 and f <= 1.0)
			assert(r >= 0.0 and r <= 1.0)
	print("OK: es_bioma_en/densidad_fauna_en/densidad_frutal_en no rompen con SEMILLA_MUNDO/ANCHO_MUNDO/LARGO_MUNDO reales.")
```

Cambia la línea final de `"Las 11 pruebas"` a `"Las 14 pruebas"`.

- [ ] **Step 2: Corre la escena y confirma que falla**

Repite `mcp__godot__run_project` / `get_debug_output` / `stop_project` sobre `GeneradorMundoTest.tscn`.
Esperado: error — `densidad_fauna_en`/`densidad_frutal_en` no existen todavía (p. ej. "Invalid call. Nonexistent function 'densidad_fauna_en'").

- [ ] **Step 3: Implementa el mínimo necesario**

En `godot/scripts/GeneradorMundo.gd`, agrega las dos variables nuevas justo después de `var _ruido_mineral: FastNoiseLite`:

```gdscript
var _ruido_fauna: FastNoiseLite
var _ruido_frutal: FastNoiseLite
```

En `_init()`, después del bloque que construye `_ruido_mineral` (antes de la línea `nivel_mar = _calcular_nivel_mar(...)`), agrega:

```gdscript

	# Semillas derivadas distintas de _ruido (base) y _ruido_mineral
	# (semilla + 1) para que fauna y frutal no queden correlacionadas entre
	# sí ni con el relieve/minerales — igual de deterministas: misma
	# semilla de entrada, mismas señales siempre.
	_ruido_fauna = FastNoiseLite.new()
	_ruido_fauna.seed = semilla + 2
	_ruido_fauna.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_fauna.frequency = 0.05

	_ruido_frutal = FastNoiseLite.new()
	_ruido_frutal.seed = semilla + 3
	_ruido_frutal.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido_frutal.frequency = 0.05
```

Al final del archivo, después de `es_bioma_en()`, agrega:

```gdscript


## Densidad de fauna en la columna (x, z), en [0, 1] — 0.0 si la columna no
## es bioma (ver es_bioma_en()). Un sistema futuro multiplicará esta
## fracción por área para decidir cuántos NPCs de fauna generar; no tiene
## efecto de bloque ni visual todavía.
func densidad_fauna_en(x: int, z: int) -> float:
	if not es_bioma_en(x, z):
		return 0.0
	var valor: float = _ruido_fauna.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0


## Densidad de recursos "frutal" en la columna (x, z), en [0, 1] — 0.0 si la
## columna no es bioma (ver es_bioma_en()). Un sistema futuro multiplicará
## esta fracción por área para decidir cuántos objetos "frutal" generar; no
## tiene efecto de bloque ni visual todavía.
func densidad_frutal_en(x: int, z: int) -> float:
	if not es_bioma_en(x, z):
		return 0.0
	var valor: float = _ruido_frutal.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0
```

- [ ] **Step 4: Corre la escena y confirma que las 14 pruebas pasan**

Repite el Step 2. Esperado: se imprimen las 14 pruebas con "OK", termina con "Las 14 pruebas de GeneradorMundo pasaron correctamente", sin ningún "Assertion failed".

- [ ] **Step 5: Corre Test.tscn como regresión**

Usa `mcp__godot__run_project` sobre `res://scenes/Test.tscn` (`BlueprintValidatorTest` — no debería verse afectado, no toca `GeneradorMundo`). Esperado: las 14 aserciones de esa suite siguen pasando igual que antes, sin errores nuevos.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: agregar señales de densidad de fauna y frutal"
```
