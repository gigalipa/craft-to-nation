# Ríos con Corriente y Cascadas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cauces de río reales (descenso por gradiente, ancho/profundidad tallados, cascadas y resolución de cruces) en `GeneradorMundo.gd`, integrados en `VoxelWorld._generar_terreno()`; más un cambio de comportamiento general del bloque `"agua"` (no sólido para minado/colocación, opacidad reducida para depuración).

**Architecture:** Toda la generación de ríos vive en `GeneradorMundo.gd` como estructuras calculadas una única vez en `_init()` (mismo patrón que `nivel_mar`), expuestas por 4 consultas de solo lectura. La lógica se separa en piezas puras (geometría de franja, fórmula de profundidad, comparador de fuerza, resolución de cruces — testables sin ruido ni mundo real) y piezas que sí consultan `altura_en()`/`es_agua_en()` (trazado del cauce, aplicación de ancho/profundidad, marcado de cascadas). `VoxelWorld._generar_terreno()` consume la nueva API para tallar; `VoxelWorld.minar_bloque()`/`colocar_bloque()` y `BlockLibrarySource.tscn` cambian para que toda el agua deje de ser sólida.

**Tech Stack:** Godot 4.7, GDScript.

**Spec:** `docs/superpowers/specs/2026-09-13-rios-corriente-cascadas-design.md`

## Global Constraints

- Tabulaciones (no espacios) en todo el GDScript nuevo.
- Convención `Vector2i(x, z)` para celdas en planta (la Z del mundo vive en `.y` del `Vector2i`) — misma convención que `Zonificacion.gd`.
- Ningún método nuevo de `GeneradorMundo.gd` cambia la firma de los ya existentes (`altura_en`, `es_agua_en`, `tipo_en_profundidad`, `nivel_mar`, etc.) — solo se agrega.
- Después de cada tarea, ejecutar como mínimo `godot/scenes/GeneradorMundoTest.tscn` y `godot/scenes/Test.tscn` con Godot 4.7 (MCP headless: `mcp__godot__run_project`/`get_debug_output`/`stop_project`) y confirmar que todas las aserciones pasan — regla del `CLAUDE.md` del repo para cambios en `godot/`.
- `Main.tscn` debe seguir cargando sin errores nuevos tras cada tarea que toque `VoxelWorld.gd` o `assets/BlockLibrary.res`.

---

## Task 1: Piezas puras — geometría de franja, fórmula de profundidad, y resolución de cruces

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd` (agregar constantes y funciones estáticas nuevas al final del archivo, después de `densidad_arbol_en()`)
- Test: `godot/scripts/GeneradorMundoTest.gd`

**Interfaces:**
- Produces: `GeneradorMundo._direccion_avance_en(cauce, i) -> Vector2i`, `GeneradorMundo._celdas_franja_en(cauce, i, ancho) -> Array[Vector2i]`, `GeneradorMundo._profundidad_en_franja(indice, ancho) -> int`, `GeneradorMundo._es_mas_fuerte(a, b) -> bool`, `GeneradorMundo._resolver_cruces(rios: Array[Dictionary]) -> void` (todas `static func`, testables por su nombre de clase igual que `_redistribuir()` ya existente). Cada `Dictionary` de "rios" debe tener las claves `"indice"` (int), `"ancho"` (int), `"altura_nacimiento"` (int) y `"cauce_crudo"` (`Array[Vector2i]`) — `_resolver_cruces()` agrega `"cauce_truncado"` (`Array[Vector2i]`) a cada uno.
- Consumes: nada nuevo (funciones puras sobre los datos recibidos).

- [ ] **Step 1: Escribir las pruebas que fallan primero**

Agregar en `godot/scripts/GeneradorMundoTest.gd`, inmediatamente antes de la línea final `print("\n=== Las 15 pruebas de GeneradorMundo pasaron correctamente ===")`:

```gdscript
	print("\n=== TEST 16: _profundidad_en_franja() da el perfil borde-1/centro-hasta-3 ===")
	assert(GeneradorMundoScript._profundidad_en_franja(0, 2) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(1, 2) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(0, 3) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(1, 3) == 2)
	assert(GeneradorMundoScript._profundidad_en_franja(2, 3) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(0, 5) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(1, 5) == 2)
	assert(GeneradorMundoScript._profundidad_en_franja(2, 5) == 3)
	assert(GeneradorMundoScript._profundidad_en_franja(3, 5) == 2)
	assert(GeneradorMundoScript._profundidad_en_franja(4, 5) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(0, 6) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(2, 6) == 3)
	assert(GeneradorMundoScript._profundidad_en_franja(3, 6) == 3)
	assert(GeneradorMundoScript._profundidad_en_franja(5, 6) == 1)
	print("OK: perfiles [1,1] (ancho 2), [1,2,1] (ancho 3), [1,2,3,2,1] (ancho 5), [1,2,3,3,2,1] (ancho 6).")

	print("\n=== TEST 17: _celdas_franja_en() genera 'ancho' celdas perpendiculares al avance ===")
	var cauce_x: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var franja_x: Array[Vector2i] = GeneradorMundoScript._celdas_franja_en(cauce_x, 1, 3)
	assert(franja_x.size() == 3)
	for celda in franja_x:
		assert(celda.x == 1)  # avance en X -> franja se extiende en Z (.y)
	var cauce_z: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var franja_z: Array[Vector2i] = GeneradorMundoScript._celdas_franja_en(cauce_z, 1, 3)
	assert(franja_z.size() == 3)
	for celda in franja_z:
		assert(celda.y == 1)  # avance en Z -> franja se extiende en X
	print("OK: la franja perpendicular al avance tiene 'ancho' celdas y varía en el eje correcto.")

	print("\n=== TEST 18: _resolver_cruces() trunca el río más angosto en el cruce, el más ancho sigue completo ===")
	var rios_cruce: Array[Dictionary] = [
		{"indice": 0, "ancho": 2, "altura_nacimiento": 10, "cauce_crudo": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]},
		{"indice": 1, "ancho": 5, "altura_nacimiento": 8, "cauce_crudo": [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 5), Vector2i(2, 8)]},
	]
	GeneradorMundoScript._resolver_cruces(rios_cruce)
	var truncado_angosto: Array[Vector2i] = rios_cruce[0]["cauce_truncado"]
	var truncado_ancho: Array[Vector2i] = rios_cruce[1]["cauce_truncado"]
	assert(truncado_angosto == [Vector2i(0, 5), Vector2i(1, 5)])  # corta justo antes de (2,5), que gana el más ancho
	assert(truncado_ancho == rios_cruce[1]["cauce_crudo"])  # el más ancho no se trunca
	print("OK: el río de ancho 2 se trunca antes del cruce en (2,5); el de ancho 5 conserva su cauce completo.")

	print("\n=== TEST 19: _resolver_cruces() en empate de ancho, gana el de naciente más alta ===")
	var rios_empate: Array[Dictionary] = [
		{"indice": 0, "ancho": 3, "altura_nacimiento": 10, "cauce_crudo": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]},
		{"indice": 1, "ancho": 3, "altura_nacimiento": 14, "cauce_crudo": [Vector2i(2, 0), Vector2i(2, 5), Vector2i(2, 8)]},
	]
	GeneradorMundoScript._resolver_cruces(rios_empate)
	assert(rios_empate[0]["cauce_truncado"] == [Vector2i(0, 5), Vector2i(1, 5)])
	assert(rios_empate[1]["cauce_truncado"] == rios_empate[1]["cauce_crudo"])
	print("OK: en empate de ancho, el río de naciente más alta (14 > 10) conserva su cauce completo.")

```

Y actualizar la línea final de `print` a `"=== Las 19 pruebas de GeneradorMundo pasaron correctamente ==="`.

- [ ] **Step 2: Ejecutar `GeneradorMundoTest.tscn` y confirmar que TEST 16-19 fallan**

`mcp__godot__run_project` sobre `res://scenes/GeneradorMundoTest.tscn`. Esperado: falla en la primera llamada a `GeneradorMundoScript._profundidad_en_franja` (`Invalid call. Nonexistent function`).

- [ ] **Step 3: Implementar las funciones nuevas**

Agregar en `godot/scripts/GeneradorMundo.gd`, después de la función `densidad_arbol_en()` (última función del archivo hoy):

```gdscript

## Cuántas nacientes de río se generan por mundo (Sección 1 del spec) —
## constante ajustable como UMBRAL_HIERRO/EXPONENTE_RELIEVE.
const NUM_RIOS := 6

## Una columna es candidata a naciente de río si su altura está a lo sumo
## esta distancia por debajo de ALTURA_MAXIMA (Sección 1).
const MARGEN_NACIENTE_RIO := 3

const ANCHO_MINIMO_RIO := 2
const ANCHO_MAXIMO_RIO := 6

## Profundidad máxima tallada en el centro de un río, sin importar cuánto
## crezca el ancho (Sección 3) — un río de ancho 6 no talla más hondo que
## uno de ancho 5, según la fórmula de _profundidad_en_franja().
const PROFUNDIDAD_MAXIMA_RIO := 3

## Caída de altura mínima entre dos celdas consecutivas del cauce para
## marcar ese paso como cascada (Sección 5, es_cascada_en()).
const UMBRAL_CASCADA := 3

## (x,z) -> profundidad tallada (1..PROFUNDIDAD_MAXIMA_RIO). Solo contiene
## celdas que son parte de la franja de algún río — ver es_rio_en().
var _profundidad_rio: Dictionary = {}  # Vector2i -> int

## (x,z) -> dirección unitaria hacia la siguiente celda del cauce — ver
## direccion_flujo_en().
var _direccion_flujo_rio: Dictionary = {}  # Vector2i -> Vector2i

## (x,z) marcadas como cascada — ver es_cascada_en().
var _celdas_cascada: Dictionary = {}  # Vector2i -> true


## Dirección de avance para la franja del paso "i" de "cauce" (Sección 3):
## vector unitario entre la celda anterior y la actual; para la naciente
## (i=0, sin "anterior"), entre la naciente y su primer paso.
## Vector2i.ZERO si "cauce" tiene un único elemento (sin dirección
## definible — caso degenerado de una naciente sin ningún paso siguiente).
static func _direccion_avance_en(cauce: Array[Vector2i], i: int) -> Vector2i:
	if i == 0:
		if cauce.size() > 1:
			return cauce[1] - cauce[0]
		return Vector2i.ZERO
	return cauce[i] - cauce[i - 1]


## Celdas de la franja perpendicular al avance en el paso "i" de "cauce"
## (Sección 3): "ancho" celdas consecutivas centradas aproximadamente en
## cauce[i] (para ancho impar, cauce[i] cae exactamente en el centro).
## Función pura de geometría — no consulta altura ni agua; quien la use
## filtra después qué celdas de la franja son válidas.
static func _celdas_franja_en(cauce: Array[Vector2i], i: int, ancho: int) -> Array[Vector2i]:
	var avance: Vector2i = _direccion_avance_en(cauce, i)
	if avance == Vector2i.ZERO:
		return [cauce[i]]
	var perpendicular: Vector2i = Vector2i(0, 1) if avance.x != 0 else Vector2i(1, 0)
	@warning_ignore("integer_division")
	var desde: int = -(ancho / 2)
	var celdas: Array[Vector2i] = []
	for k in range(ancho):
		celdas.append(cauce[i] + perpendicular * (desde + k))
	return celdas


## Profundidad tallada en la posición "indice" (0-based) de una franja de
## "ancho" celdas (Sección 3): borde = 1, sube hacia el centro hasta
## PROFUNDIDAD_MAXIMA_RIO. Fórmula pura: ancho 2 -> [1,1]; ancho 3 ->
## [1,2,1]; ancho 5 -> [1,2,3,2,1]; ancho 6 -> [1,2,3,3,2,1].
static func _profundidad_en_franja(indice: int, ancho: int) -> int:
	return mini(mini(indice, ancho - 1 - indice) + 1, PROFUNDIDAD_MAXIMA_RIO)


## Compara la "fuerza" de dos ríos para _resolver_cruces() (Sección 2b):
## mayor ancho gana; en empate, mayor altura de nacimiento; en empate
## total, el río generado primero (menor índice). true si "a" es más
## fuerte que "b" — da un orden total estricto, sin empates posibles.
static func _es_mas_fuerte(a: Dictionary, b: Dictionary) -> bool:
	if a["ancho"] != b["ancho"]:
		return a["ancho"] > b["ancho"]
	if a["altura_nacimiento"] != b["altura_nacimiento"]:
		return a["altura_nacimiento"] > b["altura_nacimiento"]
	return a["indice"] < b["indice"]


## Resuelve cruces entre los cauces crudos de "rios" (Sección 2b): agrega a
## cada Dictionary la clave "cauce_truncado" (Array[Vector2i]) — el
## prefijo de su "cauce_crudo" hasta la última celda de la que sigue
## siendo dueño (la primera celda ya reclamada por un río más fuerte corta
## el cauce ahí, sin incluirla). Cada Dictionary de "rios" debe traer
## "indice", "ancho", "altura_nacimiento" y "cauce_crudo". Pura sobre los
## datos recibidos — no consulta altura ni agua reales, así se puede
## probar con cauces sintéticos.
static func _resolver_cruces(rios: Array[Dictionary]) -> void:
	var orden_fuerza: Array[Dictionary] = rios.duplicate()
	orden_fuerza.sort_custom(_es_mas_fuerte)

	var dueño: Dictionary = {}  # Vector2i -> int (índice de río)
	for rio in orden_fuerza:
		for celda: Vector2i in rio["cauce_crudo"]:
			if not dueño.has(celda):
				dueño[celda] = rio["indice"]

	for rio in rios:
		var truncado: Array[Vector2i] = []
		for celda: Vector2i in rio["cauce_crudo"]:
			if dueño[celda] != rio["indice"]:
				break
			truncado.append(celda)
		rio["cauce_truncado"] = truncado
```

- [ ] **Step 4: Ejecutar `GeneradorMundoTest.tscn` de nuevo y confirmar que las 19 pruebas pasan**

Mismo procedimiento del Step 2. Expected: "Las 19 pruebas de GeneradorMundo pasaron correctamente", sin errores de assert.

- [ ] **Step 5: Ejecutar `Test.tscn` (regresión) y confirmar 34/34**

`mcp__godot__run_project` sobre `res://scenes/Test.tscn`. No debería haber ningún cambio de comportamiento (este task no toca `VoxelWorld.gd`).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: piezas puras de ríos — franja, perfil de profundidad y resolución de cruces"
```

---

## Task 2: Trazado del cauce por descenso por gradiente

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd` (agregar `_trazar_rio()` después de `_celdas_cascada`/antes de las funciones estáticas de Task 1, o al final — el orden entre funciones no importa en GDScript)
- Test: `godot/scripts/GeneradorMundoTest.gd`

**Interfaces:**
- Produces: `GeneradorMundo._trazar_rio(origen: Vector2i, ancho_mundo: int, largo_mundo: int) -> Array[Vector2i]` (método de instancia — usa `altura_en()`/`es_agua_en()` de `self`).
- Consumes: `altura_en(x,z)`, `es_agua_en(x,z)` (ya existentes).

- [ ] **Step 1: Escribir las pruebas que fallan primero**

Agregar en `godot/scripts/GeneradorMundoTest.gd`, antes de la línea final de conteo (ahora "19 pruebas" tras Task 1):

```gdscript
	print("\n=== TEST 20: _trazar_rio() es determinista y termina en agua o mesa cerrada ===")
	var gen_rio_a: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var gen_rio_b: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var origen_prueba := Vector2i(100, 100)
	var cauce_a: Array[Vector2i] = gen_rio_a._trazar_rio(origen_prueba, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var cauce_b: Array[Vector2i] = gen_rio_b._trazar_rio(origen_prueba, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	assert(cauce_a == cauce_b)
	assert(cauce_a.size() >= 1)
	assert(cauce_a.size() <= VoxelWorld.ANCHO_MUNDO + VoxelWorld.LARGO_MUNDO)
	var ultima: Vector2i = cauce_a[cauce_a.size() - 1]
	var termino_en_agua: bool = gen_rio_a.es_agua_en(ultima.x, ultima.y)
	var es_mesa_cerrada := true
	if cauce_a.size() >= 2:
		var penultima: Vector2i = cauce_a[cauce_a.size() - 2]
		es_mesa_cerrada = gen_rio_a.altura_en(ultima.x, ultima.y) >= gen_rio_a.altura_en(penultima.x, penultima.y)
	assert(termino_en_agua or cauce_a.size() == 1 or es_mesa_cerrada)
	print("OK: _trazar_rio() es determinista, respeta el tope de pasos, y termina en agua o en una mesa sin vecino más bajo.")

	print("\n=== TEST 21: cada paso del cauce baja de altura hasta llegar a agua ===")
	for i in range(cauce_a.size() - 1):
		var actual: Vector2i = cauce_a[i]
		if gen_rio_a.es_agua_en(actual.x, actual.y):
			break
		var siguiente: Vector2i = cauce_a[i + 1]
		assert(gen_rio_a.altura_en(siguiente.x, siguiente.y) <= gen_rio_a.altura_en(actual.x, actual.y))
	print("OK: ningún paso del cauce sube de altura antes de llegar a una celda de agua.")

```

- [ ] **Step 2: Ejecutar `GeneradorMundoTest.tscn` y confirmar que TEST 20-21 fallan**

Expected: `Invalid call. Nonexistent function '_trazar_rio'`.

- [ ] **Step 3: Implementar `_trazar_rio()`**

Agregar en `godot/scripts/GeneradorMundo.gd`:

```gdscript

## Traza el cauce crudo desde "origen" por descenso por gradiente (Sección
## 2 del spec): en cada paso se mueve a la vecina ortogonal (N/E/S/O, en
## ese orden de desempate) no visitada de menor altura; termina al entrar
## a una celda de agua ya existente (se incluye como último elemento) o si
## ninguna vecina es más baja (mesa/valle cerrado — se conserva el cauce
## parcial, no es un error). Un tope de pasos evita recorridos patológicos
## en mesetas totalmente planas.
func _trazar_rio(origen: Vector2i, ancho_mundo: int, largo_mundo: int) -> Array[Vector2i]:
	var cauce: Array[Vector2i] = [origen]
	var visitadas: Dictionary = {origen: true}
	var actual: Vector2i = origen
	var max_pasos: int = ancho_mundo + largo_mundo
	for _paso in range(max_pasos):
		if es_agua_en(actual.x, actual.y):
			break
		var vecinos: Array[Vector2i] = [
			actual + Vector2i(0, -1),
			actual + Vector2i(1, 0),
			actual + Vector2i(0, 1),
			actual + Vector2i(-1, 0),
		]
		var mejor: Vector2i = actual
		var mejor_altura: int = altura_en(actual.x, actual.y)
		for vecino in vecinos:
			if vecino.x < 0 or vecino.x >= ancho_mundo or vecino.y < 0 or vecino.y >= largo_mundo:
				continue
			if visitadas.has(vecino):
				continue
			var h: int = altura_en(vecino.x, vecino.y)
			if h < mejor_altura:
				mejor_altura = h
				mejor = vecino
		if mejor == actual:
			break
		visitadas[mejor] = true
		cauce.append(mejor)
		actual = mejor
	return cauce
```

- [ ] **Step 4: Ejecutar `GeneradorMundoTest.tscn` de nuevo y confirmar 21/21**

Actualizar la línea final a `"=== Las 21 pruebas de GeneradorMundo pasaron correctamente ==="`.

- [ ] **Step 5: Ejecutar `Test.tscn` (regresión) y confirmar 34/34**

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: trazar cauces de río por descenso por gradiente"
```

---

## Task 3: Orquestador `_generar_rios()` + API pública

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd` (agregar `_aplicar_ancho_profundidad()`, `_marcar_cascadas()`, `_generar_rios()`, las 4 consultas públicas, y la llamada desde `_init()`)
- Test: `godot/scripts/GeneradorMundoTest.gd`

**Interfaces:**
- Produces: `GeneradorMundo.es_rio_en(x,z) -> bool`, `direccion_flujo_en(x,z) -> Vector2i`, `profundidad_rio_en(x,z) -> int`, `es_cascada_en(x,z) -> bool` (API pública final del spec, Sección 5).
- Consumes: todo lo de Task 1 y Task 2.

- [ ] **Step 1: Escribir las pruebas que fallan primero**

Agregar en `godot/scripts/GeneradorMundoTest.gd`, antes de la línea final:

```gdscript
	print("\n=== TEST 22: la generación de ríos es determinista end-to-end ===")
	var gen_full_a: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var gen_full_b: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var vio_rio := false
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			var a_es_rio: bool = gen_full_a.es_rio_en(x, z)
			assert(a_es_rio == gen_full_b.es_rio_en(x, z))
			if a_es_rio:
				vio_rio = true
				assert(gen_full_a.profundidad_rio_en(x, z) == gen_full_b.profundidad_rio_en(x, z))
				assert(gen_full_a.direccion_flujo_en(x, z) == gen_full_b.direccion_flujo_en(x, z))
	assert(vio_rio)
	print("OK: dos instancias con SEMILLA_MUNDO producen exactamente el mismo mapa de ríos, y al menos una celda de río existe.")

	print("\n=== TEST 23: profundidad_rio_en() está siempre en [1, PROFUNDIDAD_MAXIMA_RIO] donde es_rio_en() es true ===")
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			if gen_full_a.es_rio_en(x, z):
				var p: int = gen_full_a.profundidad_rio_en(x, z)
				assert(p >= 1 and p <= GeneradorMundoScript.PROFUNDIDAD_MAXIMA_RIO)
			else:
				assert(gen_full_a.profundidad_rio_en(x, z) == 0)
	print("OK: profundidad_rio_en() nunca sale de rango, y es 0 fuera de cualquier río.")

	print("\n=== TEST 24: direccion_flujo_en() apunta a una celda de igual o menor altura ===")
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			var direccion: Vector2i = gen_full_a.direccion_flujo_en(x, z)
			if direccion == Vector2i.ZERO:
				continue
			var siguiente := Vector2i(x, z) + direccion
			assert(gen_full_a.altura_en(siguiente.x, siguiente.y) <= gen_full_a.altura_en(x, z))
	print("OK: toda dirección de flujo no nula apunta hacia una celda de altura igual o menor.")

	print("\n=== TEST 25: toda celda de cascada es también una celda de río real ===")
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			if gen_full_a.es_cascada_en(x, z):
				assert(gen_full_a.es_rio_en(x, z))
	print("OK: ninguna celda de cascada existe fuera de la franja de un río.")

	print("\n=== TEST 26: es_cascada_en() coincide exactamente con la regla de caída de altura (cauce sintético) ===")
	var gen_casc: RefCounted = GeneradorMundoScript.new(42, 60, 60)
	var celda_a26 := Vector2i(10, 10)
	var celda_b26 := Vector2i(11, 10)
	var cauce_sintetico_26: Array[Vector2i] = [celda_a26, celda_b26]
	gen_casc._marcar_cascadas(cauce_sintetico_26, 3, 60, 60)
	var caida_26: int = gen_casc.altura_en(celda_a26.x, celda_a26.y) - gen_casc.altura_en(celda_b26.x, celda_b26.y)
	var deberia_ser_cascada_26: bool = caida_26 >= GeneradorMundoScript.UMBRAL_CASCADA
	assert(gen_casc.es_cascada_en(celda_a26.x, celda_a26.y) == deberia_ser_cascada_26)
	print("OK (caída real detectada: %d, UMBRAL_CASCADA=%d): es_cascada_en() coincide con la regla exacta de caída de altura." % [caida_26, GeneradorMundoScript.UMBRAL_CASCADA])

```

- [ ] **Step 2: Ejecutar `GeneradorMundoTest.tscn` y confirmar que TEST 22-25 fallan**

Expected: `Invalid call. Nonexistent function 'es_rio_en'` (o similar, la primera función pública que no existe todavía).

- [ ] **Step 3: Implementar la orquestación y la API pública**

Agregar en `godot/scripts/GeneradorMundo.gd`:

```gdscript

## Talla ancho/profundidad reales sobre "cauce" (ya truncado por
## _resolver_cruces(), Sección 2b) — llena _profundidad_rio/
## _direccion_flujo_rio para cada celda de la franja de cada paso,
## saltando celdas ya bajo el mar/lago, fuera del mundo, o ya reclamadas
## por otro río procesado antes (Sección 3).
func _aplicar_ancho_profundidad(cauce: Array[Vector2i], ancho: int, ancho_mundo: int, largo_mundo: int) -> void:
	for i in range(cauce.size()):
		var celda: Vector2i = cauce[i]
		if es_agua_en(celda.x, celda.y):
			continue
		var franja: Array[Vector2i] = _celdas_franja_en(cauce, i, ancho)
		var direccion_publica: Vector2i = cauce[i + 1] - cauce[i] if i + 1 < cauce.size() else Vector2i.ZERO
		for k in range(franja.size()):
			var celda_franja: Vector2i = franja[k]
			if celda_franja.x < 0 or celda_franja.x >= ancho_mundo or celda_franja.y < 0 or celda_franja.y >= largo_mundo:
				continue
			if es_agua_en(celda_franja.x, celda_franja.y):
				continue
			if _profundidad_rio.has(celda_franja):
				continue
			_profundidad_rio[celda_franja] = _profundidad_en_franja(k, ancho)
			_direccion_flujo_rio[celda_franja] = direccion_publica


## Marca cascadas (es_cascada_en) sobre "cauce" (ya truncado): cualquier
## paso cuya caída de altura hacia la siguiente celda sea >= UMBRAL_CASCADA
## marca TODA su franja como cascada (Sección 5).
func _marcar_cascadas(cauce: Array[Vector2i], ancho: int, ancho_mundo: int, largo_mundo: int) -> void:
	for i in range(cauce.size() - 1):
		var actual: Vector2i = cauce[i]
		if es_agua_en(actual.x, actual.y):
			continue
		var siguiente: Vector2i = cauce[i + 1]
		var caida: int = altura_en(actual.x, actual.y) - altura_en(siguiente.x, siguiente.y)
		if caida < UMBRAL_CASCADA:
			continue
		for celda_franja in _celdas_franja_en(cauce, i, ancho):
			if celda_franja.x < 0 or celda_franja.x >= ancho_mundo or celda_franja.y < 0 or celda_franja.y >= largo_mundo:
				continue
			_celdas_cascada[celda_franja] = true


## Genera todos los ríos del mundo (Secciones 1-5 del spec): elige
## nacientes con un RandomNumberGenerator sembrado (semilla+5, siguiente
## hueco libre tras _ruido_arbol en semilla+4), traza su cauce crudo,
## resuelve cruces, y talla ancho/profundidad + cascadas sobre el cauce ya
## truncado de cada uno. Llamada una única vez desde _init(), después de
## calcular nivel_mar (los cauces necesitan es_agua_en() para saber dónde
## terminan).
func _generar_rios(semilla: int, ancho_mundo: int, largo_mundo: int) -> void:
	var candidatos: Array[Vector2i] = []
	for x in range(ancho_mundo):
		for z in range(largo_mundo):
			if altura_en(x, z) >= ALTURA_MAXIMA - MARGEN_NACIENTE_RIO:
				candidatos.append(Vector2i(x, z))
	if candidatos.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = semilla + 5

	var rios: Array[Dictionary] = []
	var num_a_elegir: int = mini(NUM_RIOS, candidatos.size())
	for i in range(num_a_elegir):
		var idx: int = rng.randi() % candidatos.size()
		var origen: Vector2i = candidatos[idx]
		candidatos.remove_at(idx)
		var ancho: int = rng.randi_range(ANCHO_MINIMO_RIO, ANCHO_MAXIMO_RIO)
		rios.append({
			"indice": i,
			"origen": origen,
			"ancho": ancho,
			"altura_nacimiento": altura_en(origen.x, origen.y),
			"cauce_crudo": _trazar_rio(origen, ancho_mundo, largo_mundo),
		})

	_resolver_cruces(rios)

	for rio in rios:
		var truncado: Array[Vector2i] = rio["cauce_truncado"]
		if truncado.size() < 2:
			continue
		_aplicar_ancho_profundidad(truncado, rio["ancho"], ancho_mundo, largo_mundo)
		_marcar_cascadas(truncado, rio["ancho"], ancho_mundo, largo_mundo)


## Verdadero si (x,z) cae dentro de la franja de algún río (Sección 5).
func es_rio_en(x: int, z: int) -> bool:
	return _profundidad_rio.has(Vector2i(x, z))


## Dirección unitaria hacia la siguiente celda del cauce en (x,z), o
## Vector2i.ZERO si no es río o es la celda final (Sección 5).
func direccion_flujo_en(x: int, z: int) -> Vector2i:
	return _direccion_flujo_rio.get(Vector2i(x, z), Vector2i.ZERO)


## Profundidad tallada en (x,z) — 0 si no es río (Sección 5).
func profundidad_rio_en(x: int, z: int) -> int:
	return _profundidad_rio.get(Vector2i(x, z), 0)


## Verdadero si (x,z) es parte de una cascada (Sección 5).
func es_cascada_en(x: int, z: int) -> bool:
	return _celdas_cascada.has(Vector2i(x, z))
```

Y en `_init()`, inmediatamente después de la línea `nivel_mar = _calcular_nivel_mar(ancho_mundo, largo_mundo)`:

```gdscript
	_generar_rios(semilla, ancho_mundo, largo_mundo)
```

- [ ] **Step 4: Ejecutar `GeneradorMundoTest.tscn` de nuevo y confirmar 26/26**

Actualizar la línea final a `"=== Las 26 pruebas de GeneradorMundo pasaron correctamente ==="`. Si `TEST 22` falla su `assert(vio_rio)` (ningún río real generado con `SEMILLA_MUNDO`), ver la nota de calibración en el Step 5 — es una constante ajustable (`MARGEN_NACIENTE_RIO`), no un error de lógica.

- [ ] **Step 5: Calibración empírica si hace falta (mismo patrón que `UMBRAL_HIERRO`/`EXPONENTE_RELIEVE`)**

Si el TEST 22 muestra que `SEMILLA_MUNDO` no genera ningún río real (`vio_rio == false`), es porque `MARGEN_NACIENTE_RIO = 3` deja muy pocas o ninguna columna candidata a naciente con el relieve real del mundo (200×200). Ajustar `MARGEN_NACIENTE_RIO` hacia arriba (más candidatas) y volver a correr el test hasta confirmar al menos un río real — documentar el valor final in-line en el comentario de la constante, igual que se hizo con `UMBRAL_HIERRO`.

- [ ] **Step 6: Ejecutar `Test.tscn` (regresión) y confirmar 34/34**

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: generar ríos completos (nacientes, cruces, ancho/profundidad, cascadas) y exponer su API"
```

---

## Task 4: Tallar los ríos en `VoxelWorld._generar_terreno()`

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd:287-298` (`_generar_terreno()`)

**Interfaces:**
- Consumes: `GeneradorMundo.es_rio_en(x,z)`, `profundidad_rio_en(x,z)` (Task 3).
- Produces: ningún símbolo nuevo — `_generar_terreno()` conserva su firma.

**Estado actual de `_generar_terreno()` (para localizar el punto exacto de cambio):**

```gdscript
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var y: int = altura - profundidad
				var tipo: String = generador.tipo_en_profundidad(x, y, z, profundidad)
				colocar_bloque(Vector3i(x, y, z), tipo)
			if generador.es_agua_en(x, z):
				for y_agua in range(altura + 1, generador.nivel_mar + 1):
					colocar_bloque(Vector3i(x, y_agua, z), "agua")
```

- [ ] **Step 1: Reemplazar `_generar_terreno()`**

```gdscript
func _generar_terreno() -> void:
	for x in range(ANCHO_MUNDO):
		for z in range(LARGO_MUNDO):
			var altura: int = generador.altura_en(x, z)
			if generador.es_rio_en(x, z):
				var profundidad_rio: int = generador.profundidad_rio_en(x, z)
				for y_agua in range(altura - profundidad_rio + 1, altura + 1):
					colocar_bloque(Vector3i(x, y_agua, z), "agua")
				for profundidad in range(profundidad_rio, PROFUNDIDAD_SUBSUELO + 1):
					var y: int = altura - profundidad
					var tipo: String = generador.tipo_en_profundidad(x, y, z, profundidad)
					colocar_bloque(Vector3i(x, y, z), tipo)
				continue
			colocar_bloque(Vector3i(x, altura, z), "piso")
			for profundidad in range(1, PROFUNDIDAD_SUBSUELO + 1):
				var y: int = altura - profundidad
				var tipo: String = generador.tipo_en_profundidad(x, y, z, profundidad)
				colocar_bloque(Vector3i(x, y, z), tipo)
			if generador.es_agua_en(x, z):
				for y_agua in range(altura + 1, generador.nivel_mar + 1):
					colocar_bloque(Vector3i(x, y_agua, z), "agua")
```

(La celda de superficie de una columna de río nunca es `"piso"` — el rango de agua siempre incluye `y = altura`, reemplazando lo que habría sido `"piso"`; el subsuelo continúa exactamente donde el agua tallada termina, sin salto ni solapamiento: `profundidad_rio` capas de agua consumen las profundidades `0..profundidad_rio-1`, y el subsuelo retoma en la profundidad `profundidad_rio`.)

- [ ] **Step 2: Verificar `Main.tscn` carga sin errores**

`mcp__godot__run_project` sobre `res://scenes/Main.tscn` — confirmar en `get_debug_output` que no hay errores nuevos (los `WARNING` preexistentes de `BlueprintValidator`/`Player` no cuentan).

- [ ] **Step 3: Ejecutar `Test.tscn`, `GeneradorMundoTest.tscn`, `CiudadTest.tscn`, `ZonificacionTest.tscn`, `NiveladorTerrenoTest.tscn`, `RecoleccionTest.tscn` (regresión completa)**

Confirmar que ninguno cambia de resultado (mismo conteo de pruebas que antes de este plan, sin errores de assert).

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/VoxelWorld.gd
git commit -m "feat: tallar los ríos reales en VoxelWorld._generar_terreno()"
```

---

## Task 5: Agua no sólida para minado/colocación + opacidad de depuración

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn` (quitar `CollisionShape3D` de `"agua"`, bajar opacidad de `Mat_agua`)
- Modify: `godot/scripts/VoxelWorld.gd:341-365` (`colocar_bloque()`, `minar_bloque()`)
- Modify: `godot/assets/BlockLibrary.res` (reexportado, no editado a mano)
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: ningún símbolo nuevo — cambia el comportamiento de `colocar_bloque()`/`minar_bloque()` ya existentes.

**Estado actual (para localizar el punto exacto de cambio):**

```gdscript
func colocar_bloque(celda: Vector3i, tipo: String, por_jugador: bool = false) -> bool:
	if get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
		return false
	if not _id_por_tipo.has(tipo):
		return false
	set_cell_item(celda, _id_por_tipo[tipo])
	if por_jugador:
		colocado_por_jugador[celda] = true
	return true


func minar_bloque(celda: Vector3i) -> bool:
	if celda_a_edificio.has(celda):
		return false
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	return true
```

- [ ] **Step 1: Escribir las pruebas que fallan primero**

Agregar en `godot/scripts/BlueprintValidatorTest.gd`, inmediatamente antes de la línea final `print("\n=== Las 34 pruebas de BlueprintValidator pasaron correctamente ===")`:

```gdscript
	print("\n=== TEST 35: minar_bloque() no hace nada sobre una celda de agua ===")
	const OX35 := 1050
	var celda_agua_35 := Vector3i(OX35, 1, OX35)
	mundo.colocar_bloque(celda_agua_35, "agua")
	var resultado_35: bool = mundo.minar_bloque(celda_agua_35)
	assert(not resultado_35, "minar_bloque() debe devolver false sobre una celda de agua")
	assert(mundo.obtener_tipo(celda_agua_35) == "agua", "la celda de agua no debe modificarse")

	print("\n=== TEST 36: colocar_bloque() sobre una celda de agua la sustituye ===")
	const OX36 := 1060
	var celda_agua_36 := Vector3i(OX36, 1, OX36)
	mundo.colocar_bloque(celda_agua_36, "agua")
	var resultado_36: bool = mundo.colocar_bloque(celda_agua_36, "piedra")
	assert(resultado_36, "colocar_bloque() debe poder sustituir una celda de agua")
	assert(mundo.obtener_tipo(celda_agua_36) == "piedra", "la celda debe pasar a tener el tipo nuevo")

	print("\n=== TEST 37: colocar_bloque() sigue rechazando celdas no vacías que no son agua ===")
	const OX37 := 1070
	var celda_piedra_37 := Vector3i(OX37, 1, OX37)
	mundo.colocar_bloque(celda_piedra_37, "piedra")
	var resultado_37: bool = mundo.colocar_bloque(celda_piedra_37, "tierra")
	assert(not resultado_37, "colocar_bloque() no debe sustituir una celda sólida que no sea agua")
	assert(mundo.obtener_tipo(celda_piedra_37) == "piedra", "la celda sólida original no debe cambiar")

```

Y actualizar la línea final a `"=== Las 37 pruebas de BlueprintValidator pasaron correctamente ==="`.

- [ ] **Step 2: Ejecutar `Test.tscn` y confirmar que TEST 35-36 fallan**

Expected: TEST 35 falla en `assert(not resultado_35, ...)` (hoy `minar_bloque()` sí mina agua); TEST 36 falla en `assert(resultado_36, ...)` (hoy `colocar_bloque()` rechaza celdas no vacías). TEST 37 ya debería pasar (comportamiento sin cambios) — confirmarlo también antes de tocar código, para tener una base clara de qué cambia y qué no.

- [ ] **Step 3: Aplicar los cambios mínimos en `VoxelWorld.gd`**

```gdscript
func colocar_bloque(celda: Vector3i, tipo: String, por_jugador: bool = false) -> bool:
	var actual: int = get_cell_item(celda)
	if actual != GridMap.INVALID_CELL_ITEM and _tipo_por_id.get(actual, "") != "agua":
		return false
	if not _id_por_tipo.has(tipo):
		return false
	set_cell_item(celda, _id_por_tipo[tipo])
	if por_jugador:
		colocado_por_jugador[celda] = true
	return true


func minar_bloque(celda: Vector3i) -> bool:
	if obtener_tipo(celda) == "agua":
		return false
	if celda_a_edificio.has(celda):
		return false
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	return true
```

- [ ] **Step 4: Ejecutar `Test.tscn` de nuevo y confirmar 37/37**

- [ ] **Step 5: Quitar la colisión del bloque `"agua"` y bajar su opacidad en `BlockLibrarySource.tscn`**

Editar `godot/scenes/BlockLibrarySource.tscn`:

1. En el bloque `[sub_resource type="StandardMaterial3D" id="Mat_agua"]`, agregar `transparency = 1` y cambiar `albedo_color = Color(0.2, 0.45, 0.85, 1)` por `albedo_color = Color(0.2, 0.45, 0.85, 0.45)`.
2. Eliminar por completo el nodo `[node name="CollisionShape3D" type="CollisionShape3D" parent="agua" ...]` (las dos líneas de ese nodo, `shape = SubResource("Shape_agua")` incluida) — el `MeshInstance3D` `"agua"` queda sin hijo de colisión. El `sub_resource type="BoxShape3D" id="Shape_agua"` puede quedar sin usar en el archivo (Godot lo ignora si no hay warnings de recursos huérfanos; si el editor lo señala, se puede borrar también esa línea).

- [ ] **Step 6: Reexportar `assets/BlockLibrary.res`**

```
mcp__godot__export_mesh_library con projectPath=<repo>/godot, scenePath="scenes/BlockLibrarySource.tscn", outputPath="res://assets/BlockLibrary.res"
```

Confirmar en la salida que el ítem `"agua"` se agrega SIN la línea `"Added collision shape from: ..."` (a diferencia de los demás bloques, que sí la muestran) — señal de que quedó sin colisión.

- [ ] **Step 7: Verificar `Main.tscn` carga sin errores**

`mcp__godot__run_project` sobre `res://scenes/Main.tscn`.

- [ ] **Step 8: Ejecutar toda la regresión una vez más**

`Test.tscn` (37/37), `GeneradorMundoTest.tscn` (25/25), `CiudadTest.tscn`, `ZonificacionTest.tscn`, `NiveladorTerrenoTest.tscn`, `RecoleccionTest.tscn` — sin cambios de resultado.

- [ ] **Step 9: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: el agua deja de ser sólida para minado/colocación, y baja su opacidad para depuración"
```

---

## Task 6: Verificación final y reporte

**Files:** ninguno (solo verificación).

- [ ] **Step 1: Ejecutar toda la suite de regresión una vez más de forma consolidada**

`Test.tscn`, `GeneradorMundoTest.tscn`, `CiudadTest.tscn`, `ZonificacionTest.tscn`, `GeneradorArbolTest.tscn`, `NiveladorTerrenoTest.tscn`, `RecoleccionTest.tscn` — todas deben pasar sin errores de `assert()`.

- [ ] **Step 2: `Main.tscn` — confirmación de carga**

`mcp__godot__run_project` sobre `Main.tscn`, confirmar sin errores nuevos en `get_debug_output`.

- [ ] **Step 3: Reportar al usuario**

Resumir: ríos generados (cuántos con `SEMILLA_MUNDO`, si se recalibró `MARGEN_NACIENTE_RIO`), conteo final de pruebas por escena, y que queda pendiente la confirmación visual jugando en el editor real (relieve del cauce, ancho/profundidad perceptibles, cascadas, y que el agua ya no bloquea el raycast) — mismo patrón que otros sub-proyectos de PoC 6, no verificable por herramientas headless.
