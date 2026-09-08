# Cuerpos de Agua (PoC 5, sub-proyecto 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generar cuerpos de agua (océanos/lagos) en el mundo procedural de Craft to Nation mediante un nivel de mar derivado por percentil, sobre un relieve más escarpado que el actual.

**Architecture:** `GeneradorMundo.gd` (clase pura `RefCounted`, sin nodos de escena) gana una redistribución por curva de potencia en `altura_en()` para relieve más marcado, y calcula `nivel_mar` (percentil sobre la distribución real de alturas) más `es_agua_en(x, z)` en `_init()`. `VoxelWorld._generar_terreno()` consume `es_agua_en`/`nivel_mar` para rellenar con bloques `"agua"` las columnas sumergidas, reutilizando el bucle de generación existente. Un bloque `"agua"` (color plano, sin transparencia) se agrega a la `MeshLibrary` del proyecto.

**Tech Stack:** Godot 4.7, GDScript, `FastNoiseLite` nativo.

**Spec:** `docs/superpowers/specs/2026-09-08-cuerpos-de-agua-design.md`

## Global Constraints

- Usa tabulaciones en GDScript (exigido por Godot).
- Conserva el español en comentarios, nombres de prueba y documentación.
- No edites `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- No agregues dependencias nuevas ni abstracciones especulativas — reutiliza el patrón existente de `GeneradorMundo.gd`/`VoxelWorld.gd`.
- Fuera de alcance (documentado en la spec, no implementar aquí): ríos con corriente/cascadas, percentil configurable por "tipo de mundo", reglas de minado/construcción sobre agua, material transparente para el bloque de agua.
- El bloque `"agua"` usa color plano placeholder, mismo patrón que `tierra`/`piedra`/`hierro` (sin textura ni transparencia).
- Verificación final: ejecutar `godot/scenes/Test.tscn` y `godot/scenes/GeneradorMundoTest.tscn` con Godot 4.7 (vía las herramientas `mcp__godot__*` disponibles en esta sesión, o el editor real) y confirmar que todas las aserciones pasan, sin errores nuevos al cargar `Main.tscn`.
- Actualiza el documento técnico de PoC 5 y la fila de la Fase 3 en el GDD cuando el sub-proyecto quede completo (regla de `CLAUDE.md`).

---

## Contexto de archivos existentes (léelo antes de tocar código)

- `godot/scripts/GeneradorMundo.gd`: clase pura con `altura_en(x, z)` (heightmap vía `FastNoiseLite`, rango `[0, 15]`) y `tipo_en_profundidad(...)`. Constructor actual: `_init(semilla: int)`.
- `godot/scripts/VoxelWorld.gd`: `GridMap` con `ANCHO_MUNDO := 200`, `LARGO_MUNDO := 200`, `SEMILLA_MUNDO := 12345`. `_generar_terreno()` (líneas ~80-88) recorre todas las columnas, coloca `"piso"` en la superficie y capas de subsuelo debajo. `_ready()` (línea 62) llama `generador = GeneradorMundo.new(SEMILLA_MUNDO)`.
- `godot/scripts/GeneradorMundoTest.gd`: 6 pruebas existentes, todas instancian `GeneradorMundoScript.new(<semilla>)` con un solo argumento. Se corre vía `godot/scenes/GeneradorMundoTest.tscn`.
- `godot/scenes/BlockLibrarySource.tscn`: fuente de la `MeshLibrary`. Cada bloque es un grupo de 3 `sub_resource` (`StandardMaterial3D`, `BoxMesh`, `BoxShape3D`) más un `MeshInstance3D`+`CollisionShape3D` en la sección `[node]`. `assets/BlockLibrary.res` se regenera desde esta escena exportando la `MeshLibrary` (herramienta `mcp__godot__export_mesh_library`, o manualmente en el editor: seleccionar la raíz de la escena → "Escena" → "Convertir a... → MeshLibrary").
- Único llamador de producción de `GeneradorMundo.new()`: `VoxelWorld.gd:62`. Ningún test de `RecoleccionTest.gd`/`BlueprintValidatorTest.gd` dispara `_ready()` de `VoxelWorld` (instancian `VoxelWorld.new()` sin agregarlo al árbol de escena), así que no llaman a `GeneradorMundo.new()` — no se ven afectados por el cambio de firma del constructor.

---

### Task 1: Relieve escarpado (redistribución por curva de potencia)

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd`
- Modify: `godot/scripts/GeneradorMundoTest.gd`
- Test scene: `godot/scenes/GeneradorMundoTest.tscn`

**Interfaces:**
- Consumes: nada nuevo de otras tareas.
- Produces: `GeneradorMundo.altura_en(x, z)` (firma sin cambios) ahora aplica una redistribución por curva de potencia antes de remapear a altura — consumido sin cambios por `tipo_en_profundidad()`, `VoxelWorld._generar_terreno()`, y por el muestreo de `nivel_mar` de la Task 2. Nueva función estática pura `GeneradorMundo._redistribuir(valor: float, exponente: float) -> float`, consumida internamente por `altura_en()` y directamente por la prueba de esta tarea.

- [ ] **Step 1: Escribe la prueba que debe fallar**

Abre `godot/scripts/GeneradorMundoTest.gd`. Después del bloque del "TEST 6" (línea ~96, justo antes de la línea `print("\n=== Las 6 pruebas de GeneradorMundo pasaron correctamente ===")`), inserta:

```gdscript
	print("\n=== TEST 7: la redistribución por curva de potencia acentúa los extremos sin cambiar el signo ===")
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(0.0, 2.0), 0.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(1.0, 2.0), 1.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(-1.0, 2.0), -1.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(0.5, 2.0), 0.25))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(-0.5, 2.0), -0.25))
	print("OK: _redistribuir(0.5, 2.0) == 0.25 (se aplana), extremos ±1 y 0 quedan sin cambio, signo se conserva.")
```

Y cambia esa línea final de `"Las 6 pruebas"` a `"Las 7 pruebas"`.

- [ ] **Step 2: Corre la escena y confirma que falla**

Usa `mcp__godot__run_project` con la escena `res://scenes/GeneradorMundoTest.tscn`, luego `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project`.
Esperado: error de script — `_redistribuir` no existe todavía en `GeneradorMundoScript` (p. ej. "Invalid call. Nonexistent function '_redistribuir'").

- [ ] **Step 3: Implementa el mínimo necesario**

En `godot/scripts/GeneradorMundo.gd`, después de la constante `UMBRAL_HIERRO` (línea 20), agrega:

```gdscript
## Exponente de la redistribución por curva de potencia aplicada a la altura
## (ver altura_en() y _redistribuir()) para producir picos y cuencas más
## marcados en vez de colinas suaves — necesario para que el criterio de
## nivel de mar (ver nivel_mar más abajo) separe tierra firme de zonas
## inundadas de forma perceptible. Valor inicial calibrado empíricamente,
## mismo patrón que UMBRAL_HIERRO — ajustar aquí si al probar en el editor
## el relieve resulta demasiado suave o demasiado abrupto.
const EXPONENTE_RELIEVE := 2.0
```

Reemplaza el cuerpo de `altura_en()` (líneas ~46-50):

```gdscript
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var valor_redistribuido: float = _redistribuir(valor, EXPONENTE_RELIEVE)
	var t: float = (valor_redistribuido + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)


## Acentúa los valores cercanos a ±1 (picos/cuencas) y aplana los cercanos a
## 0 (llanos), preservando el signo y los extremos exactos (-1, 0, 1).
## Función estática pura (sin depender de _ruido) para poder probarla con
## valores conocidos.
static func _redistribuir(valor: float, exponente: float) -> float:
	return sign(valor) * pow(abs(valor), exponente)
```

- [ ] **Step 4: Corre la escena y confirma que las 7 pruebas pasan**

Repite el Step 2. Esperado: se imprimen las 7 pruebas con "OK", termina con "Las 7 pruebas de GeneradorMundo pasaron correctamente", sin ningún "Assertion failed".

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd
git commit -m "feat: escarpar el relieve con una redistribución por curva de potencia"
```

---

### Task 2: Nivel de mar por percentil + `es_agua_en`

**Files:**
- Modify: `godot/scripts/GeneradorMundo.gd`
- Modify: `godot/scripts/GeneradorMundoTest.gd`
- Modify: `godot/scripts/VoxelWorld.gd`
- Test scene: `godot/scenes/GeneradorMundoTest.tscn`

**Interfaces:**
- Consumes: `GeneradorMundo.altura_en(x, z)` de la Task 1 (sin cambios de firma).
- Produces: `GeneradorMundo._init(semilla: int, ancho_mundo: int, largo_mundo: int)` (firma nueva, 3 argumentos obligatorios — rompe cualquier llamada con 1 argumento). `GeneradorMundo.nivel_mar: int` (propiedad pública, calculada en `_init`). `GeneradorMundo.es_agua_en(x: int, z: int) -> bool`. `GeneradorMundo.PERCENTIL_NIVEL_MAR := 0.15` (constante pública). Estos tres se consumen en la Task 4 (`VoxelWorld._generar_terreno()`).

- [ ] **Step 1: Escribe las pruebas que deben fallar**

En `godot/scripts/GeneradorMundoTest.gd`, después del bloque del nuevo "TEST 7" (agregado en la Task 1) y antes del `print` final, inserta:

```gdscript
	print("\n=== TEST 8: nivel_mar es determinista para (semilla, ancho, largo) dados ===")
	var gen_mar_a: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	var gen_mar_b: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	assert(gen_mar_a.nivel_mar == gen_mar_b.nivel_mar)
	print("OK: nivel_mar coincide entre dos instancias con la misma semilla y grid.")

	print("\n=== TEST 9: es_agua_en coincide con altura_en(x,z) < nivel_mar ===")
	var gen_agua: RefCounted = GeneradorMundoScript.new(777, 60, 60)
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var esperado: bool = gen_agua.altura_en(x, z) < gen_agua.nivel_mar
			assert(gen_agua.es_agua_en(x, z) == esperado)
	print("OK: es_agua_en() coincide con el criterio altura_en(x,z) < nivel_mar en todos los puntos muestreados.")

	print("\n=== TEST 10: la fracción de columnas inundadas se aproxima al percentil configurado ===")
	var gen_pct: RefCounted = GeneradorMundoScript.new(2026, 100, 100)
	var total := 0
	var inundadas := 0
	for x in range(100):
		for z in range(100):
			total += 1
			if gen_pct.es_agua_en(x, z):
				inundadas += 1
	var fraccion: float = float(inundadas) / float(total)
	assert(abs(fraccion - GeneradorMundoScript.PERCENTIL_NIVEL_MAR) < 0.05)
	print("OK: fracción inundada %.3f está dentro de ±0.05 del percentil configurado (%.2f)." % [fraccion, GeneradorMundoScript.PERCENTIL_NIVEL_MAR])
```

Cambia la línea final de `"Las 7 pruebas"` a `"Las 10 pruebas"`.

**No cambies todavía** las 8 llamadas existentes a `GeneradorMundoScript.new(<semilla>)` de los Tests 1-6 ni la de `VoxelWorld.gd:62` — eso es el Step 3, junto con el cambio de firma (ambos deben cambiar en el mismo paso porque el archivo no compila si la firma cambia sin actualizar sus llamadores).

- [ ] **Step 2: Corre la escena y confirma que falla**

Repite `mcp__godot__run_project` / `get_debug_output` / `stop_project` sobre `GeneradorMundoTest.tscn`.
Esperado: error — `GeneradorMundoScript.new(555, 60, 60)` falla porque `_init()` solo acepta 1 argumento todavía (p. ej. "Too many arguments for '_init()' call").

- [ ] **Step 3: Implementa el cambio de firma, `nivel_mar` y `es_agua_en`, y actualiza todos los llamadores**

En `godot/scripts/GeneradorMundo.gd`, agrega después de `EXPONENTE_RELIEVE`:

```gdscript
## Percentil (sobre la distribución real de altura_en() en todo el grid) que
## define nivel_mar — ver _calcular_nivel_mar(). Fijo por ahora; en un
## desarrollo futuro dependerá del "tipo de mundo" elegido (archipiélago,
## continental, etc.) — ver spec docs/superpowers/specs/2026-09-08-cuerpos-de-agua-design.md.
const PERCENTIL_NIVEL_MAR := 0.15
```

Agrega la propiedad pública justo antes de `var _ruido: FastNoiseLite`:

```gdscript
## Altura por debajo de la cual una columna se considera inundada (ver
## es_agua_en()). Calculada una vez en _init() a partir de
## PERCENTIL_NIVEL_MAR sobre la distribución real del grid (ancho_mundo x
## largo_mundo) — no es un valor fijo, para ser robusta a cambios de
## semilla, frecuencia de ruido o EXPONENTE_RELIEVE.
var nivel_mar: int
```

Reemplaza `_init()` (líneas ~26-40):

```gdscript
func _init(semilla: int, ancho_mundo: int, largo_mundo: int) -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_PERLIN
	_ruido.frequency = 0.02

	# Semilla derivada (no la misma que _ruido) para que las vetas de hierro
	# no queden correlacionadas con el relieve de superficie — sigue siendo
	# determinista: misma semilla de entrada, mismas vetas siempre.
	_ruido_mineral = FastNoiseLite.new()
	_ruido_mineral.seed = semilla + 1
	_ruido_mineral.noise_type = FastNoiseLite.TYPE_PERLIN
	# Frecuencia baja a propósito (más baja que _ruido) para producir vetas/
	# grumos grandes y deformes en vez de ruido puntual disperso celda a celda.
	_ruido_mineral.frequency = 0.05

	nivel_mar = _calcular_nivel_mar(ancho_mundo, largo_mundo)
```

Agrega, después de `tipo_en_profundidad()`:

```gdscript
## Altura correspondiente al percentil PERCENTIL_NIVEL_MAR de la
## distribución real de altura_en() sobre el grid (ancho_mundo x
## largo_mundo) — ver nivel_mar.
func _calcular_nivel_mar(ancho_mundo: int, largo_mundo: int) -> int:
	var alturas: Array = []
	for x in range(ancho_mundo):
		for z in range(largo_mundo):
			alturas.append(altura_en(x, z))
	alturas.sort()
	var indice: int = clampi(int(alturas.size() * PERCENTIL_NIVEL_MAR), 0, alturas.size() - 1)
	return alturas[indice]


## Verdadero si la columna (x, z) queda por debajo del nivel de mar. Usada
## por VoxelWorld para rellenar de agua (ver Task 4), y pensada para que
## sub-proyectos futuros (adyacencia de puestos de caza/pesca, obstáculos
## para puentes de PoC 9) la consulten sin repetir este cálculo.
func es_agua_en(x: int, z: int) -> bool:
	return altura_en(x, z) < nivel_mar
```

Ahora actualiza los 8 llamadores existentes en `godot/scripts/GeneradorMundoTest.gd` (Tests 1-6), agregando ancho/largo. Usa estos valores (coinciden con el rango de coordenadas que cada prueba ya recorre, o el tamaño real del mundo para el Test 6):

- Test 1 (línea ~18-19): `GeneradorMundoScript.new(12345, 60, 60)` para `gen_a` y `gen_b`.
- Test 2 (línea ~27): `GeneradorMundoScript.new(999, 100, 100)`.
- Test 3 (línea ~36-37): `GeneradorMundoScript.new(1, 100, 100)` y `GeneradorMundoScript.new(2, 100, 100)`.
- Test 4 (línea ~50): `GeneradorMundoScript.new(1, 10, 10)`.
- Test 5 (línea ~58): `GeneradorMundoScript.new(42, 60, 60)`.
- Test 6 (línea ~86): `GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)` — usa las dimensiones reales del mundo, mismo criterio que ya usa ese test para la semilla real.

Por último, en `godot/scripts/VoxelWorld.gd:62`, cambia:

```gdscript
	generador = GeneradorMundo.new(SEMILLA_MUNDO)
```

por:

```gdscript
	generador = GeneradorMundo.new(SEMILLA_MUNDO, ANCHO_MUNDO, LARGO_MUNDO)
```

- [ ] **Step 4: Corre la escena y confirma que las 10 pruebas pasan**

Repite el Step 2. Esperado: se imprimen las 10 pruebas con "OK", termina con "Las 10 pruebas de GeneradorMundo pasaron correctamente", sin ningún "Assertion failed".

- [ ] **Step 5: Corre Test.tscn como regresión**

Usa `mcp__godot__run_project` sobre `res://scenes/Test.tscn` (BlueprintValidatorTest, no debería verse afectado por este cambio — instancia `VoxelWorld.new()` sin disparar `_ready()`, así que nunca llama a `GeneradorMundo.new()`). Esperado: las 14 aserciones siguen pasando igual que antes, sin errores nuevos.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/GeneradorMundo.gd godot/scripts/GeneradorMundoTest.gd godot/scripts/VoxelWorld.gd
git commit -m "feat: nivel de mar por percentil y es_agua_en en GeneradorMundo"
```

---

### Task 3: Bloque `"agua"` en la MeshLibrary

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Regenerate: `godot/assets/BlockLibrary.res`

**Interfaces:**
- Consumes: nada de las tareas anteriores.
- Produces: el tipo de bloque `"agua"` disponible en `assets/BlockLibrary.res`, consumido por `VoxelWorld.colocar_bloque(celda, "agua")` en la Task 4.

- [ ] **Step 1: Agrega el bloque a la escena fuente**

En `godot/scenes/BlockLibrarySource.tscn`, después del bloque `[sub_resource type="BoxShape3D" id="Shape_mina"]` (última línea del archivo, línea 98), agrega:

```
[sub_resource type="StandardMaterial3D" id="Mat_agua"]
albedo_color = Color(0.2, 0.45, 0.85, 1)

[sub_resource type="BoxMesh" id="Mesh_agua"]
material = SubResource("Mat_agua")

[sub_resource type="BoxShape3D" id="Shape_agua"]
```

Y después del nodo `[node name="CollisionShape3D" type="CollisionShape3D" parent="mina"]` / `shape = SubResource("Shape_mina")` (últimas líneas del archivo), agrega:

```
[node name="agua" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_agua")

[node name="CollisionShape3D" type="CollisionShape3D" parent="agua"]
shape = SubResource("Shape_agua")
```

Actualiza también la cabecera `[gd_scene load_steps=37 format=3]` a `load_steps=40` (se agregan 3 sub-recursos nuevos). Nota: si el número queda ligeramente desalineado, Godot lo recalcula sin error al guardar la escena desde el editor — no es un valor que el parser valide estrictamente.

- [ ] **Step 2: Regenera la MeshLibrary**

Usa `mcp__godot__export_mesh_library` sobre `res://scenes/BlockLibrarySource.tscn` con destino `res://assets/BlockLibrary.res` (mismo flujo que se usó para agregar `tierra`/`piedra`/`hierro`/`mina`). Si la herramienta no está disponible en el entorno de ejecución, hazlo manualmente en el editor de Godot: abre `BlockLibrarySource.tscn`, selecciona el nodo raíz, "Escena" → "Convertir a..." → "MeshLibrary", y guarda sobre `res://assets/BlockLibrary.res`.

- [ ] **Step 3: Verifica que el bloque quedó indexado**

Usa `mcp__godot__run_project` sobre `res://scenes/Test.tscn` (o cualquier escena que cargue `BlockLibrary.res`) y revisa `mcp__godot__get_debug_output` — no debe haber errores de carga de recursos. `VoxelWorld._indexar_biblioteca()` recorre `mesh_library.get_item_list()`, así que si `"agua"` no aparece en `_id_por_tipo` al depurar, la exportación no incluyó el nuevo bloque — repite el Step 2.

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res
git commit -m "feat: agregar bloque placeholder de agua a la MeshLibrary"
```

---

### Task 4: Relleno de agua en `VoxelWorld._generar_terreno()`

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`

**Interfaces:**
- Consumes: `generador.es_agua_en(x, z) -> bool` y `generador.nivel_mar: int` (Task 2); tipo de bloque `"agua"` en la `MeshLibrary` (Task 3).
- Produces: columnas sumergidas del mundo real quedan rellenas de bloques `"agua"` hasta `nivel_mar` — consumido visualmente por `Main.tscn`, y en el futuro por sub-proyectos de puestos de caza/pesca y puentes (vía `generador.es_agua_en`, no vía inspección directa de bloques).

- [ ] **Step 1: Modifica `_generar_terreno()`**

En `godot/scripts/VoxelWorld.gd`, reemplaza el cuerpo de `_generar_terreno()` (líneas ~80-88):

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

Actualiza también el comentario de la función (líneas ~73-79) para mencionar el relleno de agua:

```gdscript
## Genera el mundo una única vez al arrancar la escena: para cada columna
## (x, z) coloca la celda de superficie ("piso", reutilizando el bloque
## caminable existente) y el subsuelo debajo (tierra cerca de la
## superficie, piedra más profundo, o vetas de "hierro" en la capa profunda
## — ver GeneradorMundo.tipo_en_profundidad), y si la columna queda por
## debajo del nivel de mar, agrega bloques "agua" encima de la superficie
## hasta ese nivel (ver GeneradorMundo.es_agua_en/nivel_mar).
## Ninguna de estas celdas se marca colocado_por_jugador: el terreno del
## mundo nunca puede ser parte de un edificio declarado por el jugador.
```

- [ ] **Step 2: Verificación final — Test.tscn y GeneradorMundoTest.tscn**

Corre ambas escenas vía `mcp__godot__run_project` + `get_debug_output` + `stop_project`, una a la vez:
- `res://scenes/Test.tscn`: las 14 aserciones de `BlueprintValidatorTest` deben seguir pasando.
- `res://scenes/GeneradorMundoTest.tscn`: las 10 aserciones deben seguir pasando.

- [ ] **Step 3: Verificación de carga sin errores — Main.tscn**

Corre `res://scenes/Main.tscn` vía `mcp__godot__run_project`, espera unos segundos, revisa `mcp__godot__get_debug_output` (sin errores de carga ni excepciones), y detén con `mcp__godot__stop_project`. Esto confirma que el mundo real (200×200, `SEMILLA_MUNDO`) genera sin fallos con agua y relieve escarpado — el aspecto visual real (relieve perceptible, agua visible en las cuencas correctas) queda pendiente de confirmación jugando en el editor real, mismo patrón que sub-proyectos anteriores de PoC 5.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/VoxelWorld.gd
git commit -m "feat: rellenar cuerpos de agua bajo el nivel de mar en VoxelWorld"
```

---

### Task 5: Documentar el sub-proyecto como completo

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`

**Interfaces:**
- Consumes: el resultado de las Tasks 1-4 (para describir qué quedó implementado).
- Produces: nada consumido por código — es documentación, requerida por la regla de `CLAUDE.md` ("Actualiza el documento técnico cuando cambie una decisión funcional de una PoC").

- [ ] **Step 1: Actualiza el GDD**

En `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`, dentro de la fila de la Fase 3 (sección 11), busca el texto `(4) Generación de Cuerpos de Agua — **pendiente**` y reemplázalo por una descripción de lo implementado (nivel de mar por percentil 15%, redistribución por curva de potencia para relieve escarpado, bloque `"agua"` placeholder), en el mismo estilo narrativo que los sub-proyectos 1-3 ya documentados en esa misma fila (que describen qué se verificó y qué queda pendiente/reducido). Marca explícitamente que ríos con corriente/cascadas y el percentil por "tipo de mundo" quedan para un desarrollo futuro.

- [ ] **Step 2: Actualiza el documento técnico de PoC 5**

En `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`, busca el párrafo que describe el sub-proyecto 4 ("Generación de Cuerpos de Agua... sin diseño todavía") y agrégale una sección "Verificado (PoC 5, sub-proyecto 4)" con el mismo nivel de detalle técnico que las secciones "Verificado" de los sub-proyectos 1 y 2 ya presentes en ese documento (nombres de constantes reales, valores calibrados, qué pruebas cubren qué). Referencia la spec: `docs/superpowers/specs/2026-09-08-cuerpos-de-agua-design.md`.

- [ ] **Step 3: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: document water bodies (PoC 5, sub-project 4) as complete"
```
