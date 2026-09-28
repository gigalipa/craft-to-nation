# Declaración de edificios por volumen interno — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que `BlueprintValidator` reconozca cualquier edificio residencial cuyo volumen interior esté realmente sellado (sin asumir huella constante en toda la altura), y que el checklist completo de "casa aprobable" quede cubierto: vestíbulo libre detrás de cada puerta y verificación de acceso real por pathfinding.

**Architecture:** Un flood-fill 3D de aire, sembrado desde fuera de la caja delimitadora del edificio, reemplaza la comparación de cada losa contra una huella global fija. Ese mismo flood-fill (`aire_interior`, la verdad física de qué celdas están realmente vacías) también resuelve la clasificación de losas por capa (usando la huella LOCAL de cada capa en vez de la global) y la validación de vestíbulos de puerta con fidelidad 3D completa. La verificación por pathfinding vive fuera de `BlueprintValidator` (que deliberadamente no lee el `VoxelWorld` en vivo), en `Player._declarar_edificio()`, usando el `BuscadorRutas` que ya usan los colonos.

**Tech Stack:** Godot 4.7, GDScript.

**Spec:** `docs/superpowers/specs/2026-09-28-volumen-interno-edificios-design.md`

## Global Constraints

- Tabulaciones (tabs), no espacios, en todo GDScript (exigido por Godot y por `CLAUDE.md`).
- Conservar el español en comentarios, mensajes de notificación y nombres de test.
- No tocar `Ciudad.NIVELES_VIVIENDA` ni las reglas de despeje al colocar (`VoxelWorld.calcular_despeje`/`despeje_camas_invalido`) — fuera de alcance (ver spec, "No objetivos").
- No romper ningún test existente de `godot/scenes/Test.tscn` (BlueprintValidatorTest.gd, TESTs 1-64).
- Todo blueprint JSON hecho a mano (sin `celdas_3d`, sin `volumen_sellado`) debe seguir validándose exactamente igual que hoy (regresión cubierta por TESTs 1-6, 62-64).

## Review Focus

- Una fuga real en un techo angosto (dos aguas) debe seguir rechazándose — el flood-fill exterior no debe "perdonar" huecos genuinos solo por generalizar la forma.
- Una puerta interior entre dos habitaciones del mismo piso exige vestíbulo libre en AMBOS lados, no solo uno.
- Dos puertas externas, una con acceso a todo el edificio y otra en un vestíbulo aislado sin más salida interior, deben aceptarse igual (no se exige que cada puerta externa por separado llegue a todo).
- Una cama o baúl dentro de una habitación interna sin puerta propia (o con la puerta mal ubicada) debe rechazarse por el chequeo de pathfinding, no confundirse con un error de volumen sellado (el volumen sigue cerrado, solo que una parte queda inaccesible).
- Un blueprint JSON hecho a mano, sin datos de voxel 3D, no debe intentar correr el flood-fill ni el pathfinding — debe seguir el camino de validación 2D de siempre sin lanzar error por falta de `celdas_3d`.

---

## Task 1: Flood-fill 3D del volumen interior (función pura, aislada)

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd` (agregar función nueva y constante, sin tocar `estructura_a_blueprint()` todavía)
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Produces: `BlueprintValidator._detectar_aire_interior(celdas_solidas: Dictionary, x_min: int, x_max: int, y_min: int, y_max: int, z_min: int, z_max: int) -> Dictionary` — devuelve un `Dictionary` (`Vector3i` absoluto -> `true`) con las celdas de aire ENCERRADAS (no alcanzadas por el flood-fill exterior). Vacío si no hay ningún volumen sellado (incluye el caso de una fuga: todo el aire queda "alcanzado desde afuera").
- Consumes: nada nuevo (usa `Vector3i`, `Dictionary`, tipos nativos de Godot).

- [ ] **Step 1: Escribir el test que falla**

Agregar al final de `godot/scripts/BlueprintValidatorTest.gd` (después de TEST 64, respetando la indentación con tabs del resto del archivo):

```gdscript
	print("\n=== TEST 65: _detectar_aire_interior() encuentra el volumen sellado de una caja hueca 3x3x3 ===")
	# Cascarón sólido de 3x3x3 (x,y,z: 0-2), 1 sola celda de aire interior en
	# el centro (1,1,1). 26 celdas sólidas (27 - 1 hueco).
	var celdas_caja_65: Dictionary = {}
	for x in range(3):
		for y in range(3):
			for z in range(3):
				if x == 1 and y == 1 and z == 1:
					continue
				celdas_caja_65[Vector3i(x, y, z)] = "pared"
	var aire_65: Dictionary = BlueprintValidator._detectar_aire_interior(celdas_caja_65, 0, 2, 0, 2, 0, 2)
	print("Aire interior detectado: ", aire_65.size(), " (esperado: 1)")
	assert(aire_65.size() == 1)
	assert(aire_65.has(Vector3i(1, 1, 1)))

	print("\n=== TEST 66: _detectar_aire_interior() no encuentra volumen sellado si hay una fuga ===")
	# Misma caja del TEST 65, pero le quito una celda de la cara (0,1,1):
	# el aire interior queda conectado al exterior por ese hueco.
	var celdas_fuga_66: Dictionary = celdas_caja_65.duplicate()
	celdas_fuga_66.erase(Vector3i(0, 1, 1))
	var aire_66: Dictionary = BlueprintValidator._detectar_aire_interior(celdas_fuga_66, 0, 2, 0, 2, 0, 2)
	print("Aire interior detectado: ", aire_66.size(), " (esperado: 0, hay una fuga)")
	assert(aire_66.is_empty())

	print("\n=== TEST 67: _detectar_aire_interior() reconoce un volumen alto y angosto en la parte de arriba (caso techo a dos aguas) ===")
	# Base sólida 5x5x1 (y=0) + paredes perimetrales 5x5 en y=1..2 (aire
	# interior 3x3 dentro) + techo MÁS ANGOSTO 3x5x1 en y=3 (retranqueado 1
	# celda en X respecto a las paredes de abajo) — el caso real reportado
	# por el usuario (ver captura de casa_pared_piedra_2pisos.dae).
	var celdas_techo_67: Dictionary = {}
	for x in range(5):
		for z in range(5):
			celdas_techo_67[Vector3i(x, 0, z)] = "pared"  # suelo, 5x5
	for y in [1, 2]:
		for x in range(5):
			for z in range(5):
				var es_borde := x == 0 or x == 4 or z == 0 or z == 4
				if es_borde:
					celdas_techo_67[Vector3i(x, y, z)] = "pared"
	for x in range(1, 4):
		for z in range(5):
			celdas_techo_67[Vector3i(x, 3, z)] = "pared"  # techo, 3x5 (retranqueado en X)
	var aire_67: Dictionary = BlueprintValidator._detectar_aire_interior(celdas_techo_67, 0, 4, 0, 3, 0, 4)
	# Aire interior esperado: y=1,2 con x=1..3, z=1..3 (3x3 cada capa) = 18 celdas.
	print("Aire interior detectado: ", aire_67.size(), " (esperado: 18)")
	assert(aire_67.size() == 18)
	for y in [1, 2]:
		for x in range(1, 4):
			for z in range(1, 4):
				assert(aire_67.has(Vector3i(x, y, z)), "Falta celda de aire interior en (%d,%d,%d)" % [x, y, z])
```

- [ ] **Step 2: Correr el test para confirmar que falla**

Abrir el proyecto en Godot 4.7 y correr `godot/scenes/Test.tscn` con F6. Debe fallar con un error de "función no encontrada" (`_detectar_aire_interior` no existe todavía) o similar en el panel Output/Debugger.

- [ ] **Step 3: Implementar `_detectar_aire_interior()`**

En `godot/scripts/BlueprintValidator.gd`, agregar cerca del inicio (junto a `VECINOS_ORTOGONALES`, línea 37):

```gdscript
const VECINOS_3D := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
```

Y, junto a `estructura_a_blueprint()` (antes de su definición, línea ~361), agregar:

```gdscript
## Flood-fill 3D (6-conexiones) del aire, sembrado desde FUERA de la caja
## delimitadora de "celdas_solidas" (expandida +1 en cada eje, para tener un
## "afuera" real por el que fluir). Toda celda de aire DENTRO de la caja que
## este flood-fill exterior NO alcanza es volumen interior sellado — no
## asume ninguna huella fija, así reconoce cualquier forma (pirámide,
## cilindro, techo a dos aguas más angosto que las paredes de abajo). Si el
## flood-fill exterior logra colarse hacia adentro (una pared con un hueco,
## una losa incompleta), esas celdas quedan "alcanzadas desde afuera" y NO
## se cuentan como interior — el edificio queda sin volumen sellado
## (Dictionary vacío). "celdas_solidas" son celdas ABSOLUTAS (mismo sistema
## de coordenadas que x_min/x_max/y_min/y_max/z_min/z_max); cualquier tipo
## cuenta como sólido a efectos de este flood-fill (paredes, puertas,
## ventanas, camas, baúles — todo lo que ocupa una celda física).
static func _detectar_aire_interior(
	celdas_solidas: Dictionary, x_min: int, x_max: int, y_min: int, y_max: int, z_min: int, z_max: int
) -> Dictionary:
	var alcanzado_desde_afuera: Dictionary = {}  # Vector3i -> true
	var pendientes: Array = [Vector3i(x_min - 1, y_min - 1, z_min - 1)]
	while not pendientes.is_empty():
		var actual: Vector3i = pendientes.pop_back()
		if alcanzado_desde_afuera.has(actual):
			continue
		if actual.x < x_min - 1 or actual.x > x_max + 1 \
		or actual.y < y_min - 1 or actual.y > y_max + 1 \
		or actual.z < z_min - 1 or actual.z > z_max + 1:
			continue
		if celdas_solidas.has(actual):
			continue
		alcanzado_desde_afuera[actual] = true
		for delta in VECINOS_3D:
			pendientes.append(actual + delta)

	var aire_interior: Dictionary = {}  # Vector3i -> true
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			for z in range(z_min, z_max + 1):
				var pos := Vector3i(x, y, z)
				if not celdas_solidas.has(pos) and not alcanzado_desde_afuera.has(pos):
					aire_interior[pos] = true
	return aire_interior
```

- [ ] **Step 4: Correr el test para confirmar que pasa**

Correr `godot/scenes/Test.tscn` con F6 de nuevo. Deben imprimirse los TESTs 65, 66 y 67 sin ningún error de `assert()`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "$(cat <<'EOF'
feat: flood-fill 3D del volumen interior en BlueprintValidator

Función pura y aislada, todavía no conectada a estructura_a_blueprint().
Reemplaza la idea de comparar cada losa contra una huella global fija:
detecta el aire encerrado sembrando el flood-fill desde fuera de la caja
delimitadora, así reconoce cualquier forma (incluido un techo más angosto
que las paredes de abajo, el caso real reportado).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Conectar el volumen interior a `estructura_a_blueprint()`

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd:361-511` (`estructura_a_blueprint()`)
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `BlueprintValidator._detectar_aire_interior(...)` (Task 1).
- Produces: `estructura_a_blueprint()` sigue devolviendo el mismo `Dictionary` de siempre, más dos claves nuevas: `"volumen_sellado": bool` y, si es `false`, `"errores_volumen": Array[String]`. Las claves existentes (`"pisos"`, `"celdas_3d"`, `"ancho"`, `"profundidad"`, `"huella_relativa"`, etc.) no cambian de forma.

- [ ] **Step 1: Escribir el test que falla**

Agregar después de TEST 67:

```gdscript
	print("\n=== TEST 68: estructura_a_blueprint() marca volumen_sellado=true con un techo a dos aguas más angosto que las paredes ===")
	# Mismo edificio del TEST 67 (5x5, techo retranqueado a 3x5), pero con
	# puerta+ventana+cama+baúl para que también pase validar_blueprint() más
	# adelante (Task 3). Suelo y paredes en y=0..2 como TEST 67; el "piso"
	# habitable es y=1 (huella 3x3 interior); el techo en y=3 es la losa de
	# arriba, retranqueada.
	var celdas_dosaguas_68: Dictionary = {}
	for x in range(5):
		for z in range(5):
			celdas_dosaguas_68[Vector3i(x, 0, z)] = "pared"  # suelo 5x5
	for y in [1, 2]:
		for x in range(5):
			for z in range(5):
				var es_borde68 := x == 0 or x == 4 or z == 0 or z == 4
				if not es_borde68:
					continue
				if x == 0 and z == 2 and y == 1:
					continue  # puerta (mitad inferior)
				if x == 0 and z == 2 and y == 2:
					continue  # puerta (mitad superior)
				if x == 4 and z == 2 and y == 2:
					continue  # ventana
				celdas_dosaguas_68[Vector3i(x, y, z)] = "pared"
	celdas_dosaguas_68[Vector3i(0, 1, 2)] = "puerta_inferior"
	celdas_dosaguas_68[Vector3i(0, 2, 2)] = "puerta_superior"
	celdas_dosaguas_68[Vector3i(4, 2, 2)] = "ventana"
	celdas_dosaguas_68[Vector3i(1, 1, 1)] = "cama_cabecera"
	celdas_dosaguas_68[Vector3i(2, 1, 1)] = "cama_pies"
	celdas_dosaguas_68[Vector3i(1, 1, 3)] = "baul"
	for x in range(1, 4):
		for z in range(5):
			celdas_dosaguas_68[Vector3i(x, 3, z)] = "pared"  # techo 3x5, retranqueado

	var blueprint_68 := BlueprintValidator.estructura_a_blueprint(celdas_dosaguas_68)
	print("volumen_sellado: ", blueprint_68["volumen_sellado"], " (esperado: true)")
	assert(blueprint_68["volumen_sellado"])
	assert(blueprint_68["pisos"].size() == 1, "1 solo piso habitable (suelo/techo son losas)")

	print("\n=== TEST 69: estructura_a_blueprint() marca volumen_sellado=false si el techo a dos aguas tiene una fuga real ===")
	var celdas_fuga_69: Dictionary = celdas_dosaguas_68.duplicate()
	celdas_fuga_69.erase(Vector3i(2, 3, 2))  # hueco en el centro del techo retranqueado
	var blueprint_69 := BlueprintValidator.estructura_a_blueprint(celdas_fuga_69)
	print("volumen_sellado: ", blueprint_69["volumen_sellado"], " (esperado: false)")
	assert(not blueprint_69["volumen_sellado"])
	assert(not blueprint_69["errores_volumen"].is_empty())
```

- [ ] **Step 2: Correr el test para confirmar que falla**

Correr `Test.tscn` con F6. Debe fallar porque `blueprint_68`/`blueprint_69` todavía no tienen la clave `"volumen_sellado"` (Godot lanza un error de "Invalid access to property or key 'volumen_sellado'").

- [ ] **Step 3: Implementar el cableado en `estructura_a_blueprint()`**

En `godot/scripts/BlueprintValidator.gd`, dentro de `estructura_a_blueprint()`:

1. Justo después de calcular `y_min`/`x_min`/`z_min`/`x_max`/`z_max` (línea ~375-387), agregar el cálculo de `y_max` y conservar copias absolutas de `x_max`/`z_max` ANTES de que se conviertan en rangos relativos:

```gdscript
	var y_min: int = celdas_relevantes.keys()[0].y
	var x_min: int = celdas_relevantes.keys()[0].x
	var z_min: int = celdas_relevantes.keys()[0].z
	var x_max: int = x_min
	var z_max: int = z_min
	var y_max: int = y_min
	for pos in celdas_relevantes.keys():
		y_min = min(y_min, pos.y)
		x_min = min(x_min, pos.x)
		z_min = min(z_min, pos.z)
		x_max = max(x_max, pos.x)
		z_max = max(z_max, pos.z)
		y_max = max(y_max, pos.y)
	var x_max_abs := x_max
	var z_max_abs := z_max
	x_max -= x_min
	z_max -= z_min
```

(Nota: `y_min` puede volver a bajar dentro del mismo bucle porque se sigue actualizando junto con `y_max` en la misma pasada — no hay problema de orden, son dos acumuladores independientes.)

2. Justo después de construir `celdas_por_capa`/`huella_real` (después del bucle `for pos in celdas_relevantes.keys(): ... huella_real[clave] = true`, línea ~400), agregar:

```gdscript
	var aire_interior: Dictionary = _detectar_aire_interior(
		celdas_relevantes, x_min, x_max_abs, y_min, y_max, z_min, z_max_abs
	)
	var volumen_sellado: bool = not aire_interior.is_empty()

	# Huella LOCAL de cada capa (índice relativo = y absoluto - y_min): unión
	# de sus propias celdas estructurales/mobiliario (celdas_por_capa) y sus
	# propias celdas de aire interior sellado (aire_interior) — a diferencia
	# de huella_real (la unión de TODO el edificio), esto permite que una
	# capa más angosta que el resto (techo a dos aguas, pirámide) se juzgue
	# contra SU PROPIO contorno, no el de las paredes de abajo.
	var huella_local: Dictionary = {}  # int (capa) -> Dictionary ("x,z" -> true)
	for pos in aire_interior.keys():
		var capa_aire: int = pos.y - y_min
		var clave_aire := "%d,%d" % [pos.x - x_min, pos.z - z_min]
		if not huella_local.has(capa_aire):
			huella_local[capa_aire] = {}
		huella_local[capa_aire][clave_aire] = true
```

3. Dentro de `celdas_por_capa` ya existe un bucle que llena `huella_real`; después de ese bucle (antes de `var indices_capa`), agregar el resto de `huella_local` con las celdas estructurales propias de cada capa:

```gdscript
	for capa_propia in celdas_por_capa.keys():
		if not huella_local.has(capa_propia):
			huella_local[capa_propia] = {}
		for clave_propia in celdas_por_capa[capa_propia]:
			huella_local[capa_propia][clave_propia] = true
```

4. Reemplazar las DOS líneas que usan `huella_real` para clasificar losas:

```gdscript
	var es_losa: Dictionary = {}  # int -> bool ("losa parcial": límite entre historias)
	for capa in indices_capa:
		es_losa[capa] = _es_losa_parcial(celdas_por_capa[capa], huella_local.get(capa, {}))
```

5. Y las DOS líneas de `suelo_ok`/`techo_ok` dentro del bucle de bandas:

```gdscript
		var suelo_ok: bool = hay_losa_bajo and (
			not es_piso_mas_bajo or _es_losa_completa(celdas_por_capa[capa_bajo_banda], huella_local.get(capa_bajo_banda, {}))
		)
		var techo_ok: bool = hay_losa_sobre and (
			not es_piso_mas_alto or _es_losa_completa(celdas_por_capa[capa_sobre_banda], huella_local.get(capa_sobre_banda, {}))
		)
```

6. En el `return` final de la función, agregar las dos claves nuevas:

```gdscript
	var resultado := {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"categoria": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,
		"profundidad": z_max + 1,
		"huella_relativa": huella_relativa,
		"volumen_sellado": volumen_sellado,
	}
	if not volumen_sellado:
		resultado["errores_volumen"] = [
			"El edificio no tiene ningún volumen interior sellado: hay una fuga hacia afuera o no hay ningún espacio interior."
		]
	return resultado
```

(Reemplaza el `return { ... }` literal existente — mismo contenido, más las 2 claves nuevas.)

7. Actualizar el comentario de `_es_losa_completa()`/`_es_losa_parcial()`/`_es_columna_interior()` (líneas ~270-326) para reflejar que ahora reciben la huella LOCAL de la capa, no la global — buscar las frases "la unión de TODAS las capas del edificio" y "la caja delimitadora completa" y ajustarlas a "la huella que le pase quien llama (hoy: la huella local de esa capa, ver estructura_a_blueprint())". No cambiar el comportamiento de estas 3 funciones, solo el comentario.

- [ ] **Step 4: Correr el test para confirmar que pasa**

Correr `Test.tscn` con F6. TESTs 65-69 deben pasar. TAMBIÉN revisar la consola completa: los TESTs 7, 10-14, 17, 19, 21 (los que usan `estructura_a_blueprint()`) deben seguir pasando sin cambios — si alguno falla, es una regresión real, no un ajuste de expectativa: investigar antes de tocar el test existente.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "$(cat <<'EOF'
feat: estructura_a_blueprint() detecta el volumen interior real

La clasificación de losas (piso vs. techo/suelo) ya no compara cada capa
contra la huella global del edificio, sino contra su propia huella local
(derivada del flood-fill de aire interior) — reconoce un techo a dos
aguas más angosto que las paredes de abajo, el caso real reportado.
validar_blueprint() todavía no usa volumen_sellado (siguiente tarea).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `validar_blueprint()` usa `volumen_sellado` para blueprints auto-detectados

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd:514-542` (`validar_blueprint()`)
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `blueprint["volumen_sellado"]` / `blueprint["errores_volumen"]` (Task 2).
- Produces: `validar_blueprint()` mantiene la misma firma; el comportamiento para blueprints SIN `"volumen_sellado"` (hand-authored JSON) no cambia.

- [ ] **Step 1: Escribir el test que falla**

Agregar después de TEST 69:

```gdscript
	print("\n=== TEST 70: validar_blueprint() acepta el techo a dos aguas usando volumen_sellado (sin cerramiento/techo_y_suelo por piso) ===")
	var resultado_70: Dictionary = BlueprintValidator.validar_blueprint(blueprint_68)
	print("Válido: ", resultado_70["valido"], " | Errores: ", resultado_70["errores"])
	assert(resultado_70["valido"], "El techo retranqueado debe aceptarse: antes se rechazaba por 'falta un techo sólido'")

	print("\n=== TEST 71: validar_blueprint() rechaza el techo a dos aguas con fuga real, usando el mensaje de volumen ===")
	var resultado_71: Dictionary = BlueprintValidator.validar_blueprint(blueprint_69)
	print("Válido: ", resultado_71["valido"], " | Errores: ", resultado_71["errores"])
	assert(not resultado_71["valido"])
	assert(resultado_71["errores"].has("El edificio no tiene ningún volumen interior sellado: hay una fuga hacia afuera o no hay ningún espacio interior."))

	print("\n=== TEST 72: un blueprint JSON hecho a mano (sin volumen_sellado) sigue usando la validación 2D de siempre ===")
	var bp_json_72: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	assert(not bp_json_72.has("volumen_sellado"), "un blueprint JSON nunca trae esta clave")
	var resultado_72: Dictionary = BlueprintValidator.validar_blueprint(bp_json_72, "residencial_investigacion")
	print("Válido: ", resultado_72["valido"], " | Errores: ", resultado_72["errores"])
	assert(resultado_72["valido"], "regresión: el blueprint JSON de siempre debe seguir validándose igual (ver TEST 1)")
```

- [ ] **Step 2: Correr el test para confirmar que falla**

Correr `Test.tscn` con F6. TEST 70 debe fallar (`resultado_70["valido"]` es `false`, porque `validar_blueprint()` todavía corre `validar_techo_y_suelo()` por piso contra la huella global y rechaza el techo retranqueado).

- [ ] **Step 3: Implementar el branch en `validar_blueprint()`**

Reemplazar el cuerpo de `validar_blueprint()` en `godot/scripts/BlueprintValidator.gd`:

```gdscript
static func validar_blueprint(
	blueprint: Dictionary,
	zona_destino: String = "",
	blueprint_anterior: Dictionary = {},
	blueprint_original_produccion: Dictionary = {},
	limites_vivienda: Dictionary = {}
) -> Dictionary:
	var errores: Array = []

	# Blueprints auto-detectados (estructura_a_blueprint(), con datos de
	# voxel reales) ya vienen con su sellado verificado en 3D por
	# volumen_sellado (ver Task 1-2 del plan de volumen interno) — no hace
	# falta (ni es correcto) volver a validar cerramiento/techo/suelo en 2D
	# por piso contra una huella fija, porque esa huella puede variar de
	# capa a capa (techo a dos aguas, pirámide). Los blueprints hechos a
	# mano (JSON de PoC 2) no tienen datos de voxel: siguen el camino 2D de
	# siempre, sin cambios.
	if blueprint.has("volumen_sellado"):
		if not blueprint["volumen_sellado"]:
			errores.append_array(blueprint.get("errores_volumen", []))
		for piso in blueprint["pisos"]:
			errores.append_array(validar_aberturas(piso))
			errores.append_array(validar_altura_piso(piso))
	else:
		for piso in blueprint["pisos"]:
			errores.append_array(validar_cerramiento(piso))
			errores.append_array(validar_aberturas(piso))
			errores.append_array(validar_techo_y_suelo(piso))
			errores.append_array(validar_altura_piso(piso))

	errores.append_array(validar_camas_y_almacenamiento(blueprint))
	errores.append_array(validar_zona_permitida(blueprint))
	if not limites_vivienda.is_empty():
		errores.append_array(validar_limites_vivienda(blueprint, limites_vivienda))

	if zona_destino != "":
		errores.append_array(validar_colocacion(blueprint, zona_destino))
	if not blueprint_anterior.is_empty():
		errores.append_array(validar_evolucion(blueprint, blueprint_anterior))
	if blueprint.get("tipo", "") == "produccion" and not blueprint_original_produccion.is_empty():
		errores.append_array(validar_personalizacion_produccion(blueprint, blueprint_original_produccion))

	return {"valido": errores.is_empty(), "errores": errores}
```

- [ ] **Step 4: Correr el test para confirmar que pasa**

Correr `Test.tscn` con F6. TESTs 70-72 deben pasar. Revisar la consola completa otra vez: TODOS los TESTs 1-6 (blueprints JSON) y 7-64 deben seguir pasando — son la regresión más importante de esta tarea.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "$(cat <<'EOF'
feat: validar_blueprint() usa el volumen interior real para blueprints auto-detectados

Un blueprint venido de estructura_a_blueprint() ya trae su sellado
verificado en 3D (volumen_sellado): se salta la validación 2D de
cerramiento/techo/suelo por piso (que asumía huella constante) y usa el
mensaje de volumen_sellado en su lugar. Los blueprints JSON hechos a
mano siguen el camino de siempre, sin cambios (regresión: TESTs 1-6).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Vestíbulo libre detrás de cada puerta (externa o interna)

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd`
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `celdas_relevantes`, `aire_interior`, `huella_local`, `indices_capa`, `bandas`, `pisos` (todas ya calculadas dentro de `estructura_a_blueprint()`, Task 2).
- Produces:
  - `estructura_a_blueprint()` agrega la clave `"errores_vestibulos": Array[String]` al blueprint que devuelve (siempre presente si hay `"volumen_sellado"`; puede ser `[]`).
  - `BlueprintValidator.validar_vestibulos_puerta(piso: Dictionary) -> Array` — validador 2D nuevo, usado SOLO para blueprints hand-authored (sin `celdas_3d`).
  - `validar_blueprint()` consume `errores_vestibulos` en la rama `volumen_sellado`, y llama a `validar_vestibulos_puerta()` en la rama hand-authored.

- [ ] **Step 1: Escribir el test que falla**

Agregar después de TEST 72:

```gdscript
	print("\n=== TEST 73: estructura_a_blueprint() rechaza una puerta sin vestíbulo libre por dentro ===")
	# Mismo edificio del TEST 68 (techo a dos aguas, válido), pero con un
	# baúl pegado a la puerta por dentro, tapando el vestíbulo.
	var celdas_sin_vestibulo_73: Dictionary = celdas_dosaguas_68.duplicate()
	celdas_sin_vestibulo_73[Vector3i(1, 1, 2)] = "baul"  # celda pegada a la puerta (0,1,2) por dentro
	var blueprint_73 := BlueprintValidator.estructura_a_blueprint(celdas_sin_vestibulo_73)
	print("volumen_sellado: ", blueprint_73["volumen_sellado"], " | errores_vestibulos: ", blueprint_73["errores_vestibulos"])
	assert(blueprint_73["volumen_sellado"], "el volumen sigue sellado: el baúl no abre ningún hueco")
	assert(not blueprint_73["errores_vestibulos"].is_empty())
	var resultado_73: Dictionary = BlueprintValidator.validar_blueprint(blueprint_73)
	assert(not resultado_73["valido"])

	print("\n=== TEST 74: estructura_a_blueprint() exige vestíbulo libre en AMBOS lados de una puerta interior ===")
	# Casa de 7x5 dividida en 2 habitaciones por un muro interior en x=3 con
	# su propia puerta en (3,*,2). Puerta principal en (0,*,2). Cama+baúl en
	# la habitación este (x=4..6), alcanzable solo cruzando la puerta
	# interior. La celda (4,1,2), pegada a la puerta interior por el lado
	# ESTE, se tapa con una pared — debe rechazarse por vestíbulo, aunque el
	# lado oeste (2,1,2) sí esté libre.
	var celdas_interior_74: Dictionary = {}
	for x in range(7):
		for z in range(5):
			celdas_interior_74[Vector3i(x, 0, z)] = "pared"  # suelo
			celdas_interior_74[Vector3i(x, 4, z)] = "pared"  # techo
	for y in [1, 2, 3]:
		for x in range(7):
			for z in range(5):
				var es_borde74 := x == 0 or x == 6 or z == 0 or z == 4
				if es_borde74:
					if x == 0 and z == 2 and y != 3:
						continue  # puerta principal (y=1,2)
					if x == 6 and z == 2 and y == 2:
						continue  # ventana
					celdas_interior_74[Vector3i(x, y, z)] = "pared"
	for y in [1, 2, 3]:
		for z in range(5):
			if z == 2 and y != 3:
				continue  # puerta interior (y=1,2)
			celdas_interior_74[Vector3i(3, y, z)] = "pared"  # muro interior en x=3
	celdas_interior_74[Vector3i(0, 1, 2)] = "puerta_inferior"
	celdas_interior_74[Vector3i(0, 2, 2)] = "puerta_superior"
	celdas_interior_74[Vector3i(3, 1, 2)] = "puerta_inferior"
	celdas_interior_74[Vector3i(3, 2, 2)] = "puerta_superior"
	celdas_interior_74[Vector3i(6, 2, 2)] = "ventana"
	celdas_interior_74[Vector3i(5, 1, 1)] = "cama_cabecera"
	celdas_interior_74[Vector3i(5, 1, 2)] = "cama_pies"
	celdas_interior_74[Vector3i(5, 1, 3)] = "baul"
	celdas_interior_74[Vector3i(4, 1, 2)] = "pared"  # tapa el vestíbulo del lado este de la puerta interior

	var blueprint_74 := BlueprintValidator.estructura_a_blueprint(celdas_interior_74)
	print("errores_vestibulos: ", blueprint_74["errores_vestibulos"])
	assert(not blueprint_74["errores_vestibulos"].is_empty(), "el lado este de la puerta interior está tapado")

	print("\n=== TEST 75: estructura_a_blueprint() acepta una puerta interior con vestíbulo libre en ambos lados ===")
	var celdas_interior_ok_75: Dictionary = celdas_interior_74.duplicate()
	celdas_interior_ok_75.erase(Vector3i(4, 1, 2))  # libera el vestíbulo del lado este
	var blueprint_75 := BlueprintValidator.estructura_a_blueprint(celdas_interior_ok_75)
	print("volumen_sellado: ", blueprint_75["volumen_sellado"], " | errores_vestibulos: ", blueprint_75["errores_vestibulos"])
	assert(blueprint_75["volumen_sellado"])
	assert(blueprint_75["errores_vestibulos"].is_empty())
	var resultado_75: Dictionary = BlueprintValidator.validar_blueprint(blueprint_75)
	print("Válido: ", resultado_75["valido"], " | Errores: ", resultado_75["errores"])
	assert(resultado_75["valido"])

	print("\n=== TEST 76: validar_vestibulos_puerta() rechaza un blueprint JSON hecho a mano con la celda detrás de la puerta ocupada ===")
	var bp_json_vestibulo_76: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	# La puerta está en "1,0"; su lado de adentro (dentro de la huella 3x3) es "1,1", ya ocupado por "baul".
	assert(bp_json_vestibulo_76["pisos"][0]["celdas"]["1,1"] == "baul")
	var errores_76: Array = BlueprintValidator.validar_vestibulos_puerta(bp_json_vestibulo_76["pisos"][0])
	print("Errores: ", errores_76)
	assert(not errores_76.is_empty())
```

- [ ] **Step 2: Correr el test para confirmar que falla**

Correr `Test.tscn` con F6. Debe fallar porque `blueprint_73/74/75` no tienen la clave `"errores_vestibulos"` y `validar_vestibulos_puerta` no existe.

- [ ] **Step 3: Implementar el cálculo dentro de `estructura_a_blueprint()`**

En `godot/scripts/BlueprintValidator.gd`, justo antes del `return resultado` final (después de construir `huella_relativa`, Task 2 Step 3.6), agregar:

```gdscript
	var errores_vestibulos: Array = _calcular_errores_vestibulos(
		celdas_relevantes, pisos, bandas, indices_capa, huella_local, aire_interior, x_min, y_min, z_min
	)
```

Y agregar `"errores_vestibulos": errores_vestibulos` al `Dictionary` literal `resultado` (junto a `"volumen_sellado"`).

Agregar la función nueva (cerca de `estructura_a_blueprint()`, después de ella):

```gdscript
## Vestíbulo de una puerta: la celda pegada a ella por el lado de ADENTRO
## (dentro de la huella de ALGUNA capa del edificio a esa altura), con 2
## celdas de altura (misma altura que la puerta), debe estar libre — ni
## pared, ni cama, ni baúl. Aplica a TODA puerta del edificio, externa o
## interna (un muro interior con su propia puerta cuenta igual): si AMBOS
## lados ortogonales de la puerta pertenecen a la huella (puerta entre dos
## habitaciones), los DOS deben tener su celda libre — cada lado es
## "adentro" de su propia habitación (decisión del usuario, 2026-09-28).
## Usa aire_interior (verdad física del flood-fill, Task 1) en vez del
## piso["celdas"] aplanado, porque ese aplanado rellena las celdas de aire
## interior sin nada especial con el tipo sólido de la losa vecina (ver
## comentario de estructura_a_blueprint() sobre la plantilla base) — no
## sirve para saber si una celda está REALMENTE libre.
static func _calcular_errores_vestibulos(
	celdas_relevantes: Dictionary,
	pisos: Array,
	bandas: Array,
	indices_capa: Array,
	huella_local: Dictionary,
	aire_interior: Dictionary,
	x_min: int,
	y_min: int,
	z_min: int
) -> Array:
	var errores: Array = []
	for pos: Vector3i in celdas_relevantes.keys():
		if celdas_relevantes[pos] != "puerta_inferior":
			continue
		var capa: int = pos.y - y_min
		var indice_capa: int = indices_capa.find(capa)
		if indice_capa == -1:
			continue
		var nivel := -1
		for banda_idx in range(bandas.size()):
			if bandas[banda_idx][0] <= indice_capa and indice_capa <= bandas[banda_idx][1]:
				nivel = pisos[banda_idx]["nivel"]
				break
		if nivel == -1:
			continue
		for delta in VECINOS_ORTOGONALES:
			var vecino := Vector3i(pos.x + delta.x, pos.y, pos.z + delta.y)
			var clave_col := "%d,%d" % [vecino.x - x_min, vecino.z - z_min]
			if not huella_local.get(capa, {}).has(clave_col):
				continue  # este lado es "afuera", no hace falta vestíbulo
			var libre: bool = aire_interior.has(vecino) and aire_interior.has(vecino + Vector3i(0, 1, 0))
			if not libre:
				errores.append("Al %s le falta espacio libre justo detrás de una puerta." % _texto_piso(nivel))
	return errores
```

Y el validador 2D para blueprints hand-authored (agregar cerca de `validar_aberturas()`):

```gdscript
## Versión 2D de la regla de vestíbulo, para blueprints hand-authored (sin
## celdas_3d ni aire_interior, ver _calcular_errores_vestibulos()). En un
## piso hand-authored, una celda AUSENTE de piso["celdas"] es libre por
## definición (el autor solo lista paredes/aberturas/mobiliario). Igual que
## _calcular_errores_vestibulos(), exige el lado "adentro" de cada puerta
## (perteneciente a la huella del piso) libre — ambos lados si los dos
## pertenecen a la huella.
static func validar_vestibulos_puerta(piso: Dictionary) -> Array:
	var errores: Array = []
	var celdas: Dictionary = piso["celdas"]
	for clave in celdas.keys():
		if celdas[clave] != "puerta":
			continue
		var pos: Vector2i = _parsear_celda(clave)
		for delta in VECINOS_ORTOGONALES:
			var vecino: Vector2i = pos + delta
			var clave_vecino := "%d,%d" % [vecino.x, vecino.y]
			if not celdas.has(clave_vecino):
				continue  # este lado no pertenece a la huella del piso: es "afuera"
			errores.append(
				"El %s tiene una puerta sin espacio libre justo detrás." % _texto_piso(piso["nivel"])
			)
	return errores
```

- [ ] **Step 4: Conectar `errores_vestibulos`/`validar_vestibulos_puerta()` en `validar_blueprint()`**

En `godot/scripts/BlueprintValidator.gd`, dentro de `validar_blueprint()` (Task 3):

```gdscript
	if blueprint.has("volumen_sellado"):
		if not blueprint["volumen_sellado"]:
			errores.append_array(blueprint.get("errores_volumen", []))
		errores.append_array(blueprint.get("errores_vestibulos", []))
		for piso in blueprint["pisos"]:
			errores.append_array(validar_aberturas(piso))
			errores.append_array(validar_altura_piso(piso))
	else:
		for piso in blueprint["pisos"]:
			errores.append_array(validar_cerramiento(piso))
			errores.append_array(validar_aberturas(piso))
			errores.append_array(validar_techo_y_suelo(piso))
			errores.append_array(validar_altura_piso(piso))
			errores.append_array(validar_vestibulos_puerta(piso))
```

- [ ] **Step 5: Correr el test para confirmar que pasa**

Correr `Test.tscn` con F6. TESTs 73-76 deben pasar. Revisar TODA la consola: TESTs 1-72 deben seguir pasando (TEST 1, con el blueprint JSON válido de siempre, cuya puerta en "1,0" SÍ tiene libre su vestíbulo en "1,1"... **atención**: revisar `BLUEPRINT_VALIDO_JSON` — la celda "1,1" es `"baul"`, no libre. Si TEST 1 empieza a fallar por la regla de vestíbulo nueva, es esperado y correcto: ajustar `BLUEPRINT_VALIDO_JSON` moviendo el baúl a una celda que no sea el vestíbulo de la puerta (p. ej. a "0,1" si está libre, o agregar una celda libre nueva al layout) y volver a correr TESTs 1-6 para confirmar que siguen pasando con el layout corregido. Documentar el ajuste en el mensaje de commit si hace falta.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "$(cat <<'EOF'
feat: exige un vestíbulo libre detrás de cada puerta (externa o interna)

Blueprints auto-detectados: se calcula con la verdad física del
flood-fill de aire interior (fidelidad 3D completa), aplica a puertas
externas e internas por igual — una puerta interior exige el vestíbulo
libre en AMBOS lados. Blueprints hand-authored: validador 2D nuevo,
validar_vestibulos_puerta(), con la misma regla.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Verificación de acceso por pathfinding en `Player._declarar_edificio()`

**Files:**
- Modify: `godot/scripts/Player.gd`
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `BuscadorRutas` (`res://scripts/BuscadorRutas.gd`, ya existente) — `BuscadorRutas.new(mundo)`, `buscar_ruta_a_alguna(origen: Vector3i, destinos: Array, opciones: Dictionary = {}) -> Array[Vector3i]`.
- Produces:
  - `Player._celdas_externas_puerta(celdas: Dictionary) -> Array[Vector3i]` (`static`) — vestíbulos internos de cada puerta EXTERNA (la que tiene al menos un lado XZ fuera de la huella del edificio).
  - `Player._celdas_objetivo_muebles(celdas: Dictionary) -> Array[Vector3i]` (`static`) — celda encima de cada `cama_cabecera`/`baul` (donde se para un colono a usarlo).
  - `Player._verificar_acceso_pathfinding(mundo: Node, celdas: Dictionary) -> String` (`static`) — `""` si todo es alcanzable, o un mensaje de rechazo.
  - `_declarar_edificio()` llama a `_verificar_acceso_pathfinding(mundo, celdas)` antes de `Blueprints.guardar(blueprint)` y rechaza si no es `""`.

- [ ] **Step 1: Escribir el test que falla**

Agregar `const Player = preload("res://scripts/Player.gd")` cerca del inicio de `godot/scripts/BlueprintValidatorTest.gd` (junto a `const VoxelWorld = preload(...)`, línea 3):

```gdscript
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const Player = preload("res://scripts/Player.gd")
```

Agregar después de TEST 76:

```gdscript
	print("\n=== TEST 77: _verificar_acceso_pathfinding() aprueba una casa simple con cama y baúl alcanzables ===")
	# Reutiliza el edificio de TEST 7 (mundo real, con colocar_bloque/
	# colocar_puerta/colocar_cama), cuya cama y baúl son alcanzables desde
	# la puerta principal cruzando la puerta interior abierta.
	var motivo_77: String = Player._verificar_acceso_pathfinding(mundo, estructura)
	print("Motivo de rechazo: '", motivo_77, "' (esperado: vacío)")
	assert(motivo_77 == "")

	print("\n=== TEST 78: _verificar_acceso_pathfinding() rechaza una cama en una habitación interna sin puerta propia ===")
	# Casa 5x5 (suelo y=100, techo y=104) con una habitación interna en la
	# esquina (x=1..2, z=1..2) completamente amurallada SIN puerta propia,
	# con una cama adentro: la puerta principal solo da a la habitación
	# grande, la cama queda encerrada pero el volumen del edificio sigue
	# sellado (la habitación interna es parte del mismo volumen exterior).
	const OY78 := 100
	const OX78 := 400
	for x in range(OX78, OX78 + 5):
		for z in range(5):
			mundo.colocar_bloque(Vector3i(x, OY78, z), "pared", true)
			mundo.colocar_bloque(Vector3i(x, OY78 + 4, z), "pared", true)
	for y in [OY78 + 1, OY78 + 2, OY78 + 3]:
		for x in range(OX78, OX78 + 5):
			for z in range(5):
				var es_borde78: bool = x == OX78 or x == OX78 + 4 or z == 0 or z == 4
				if es_borde78 and not (x == OX78 and z == 2 and y != OY78 + 3):
					mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	assert(mundo.colocar_puerta(Vector3i(OX78, OY78 + 1, 2)))  # puerta principal
	mundo.colocar_bloque(Vector3i(OX78 + 4, OY78 + 2, 2), "ventana", true)
	# Habitación interna amurallada (x=1..2 relativo a OX78, z=1..2), sin puerta.
	for y in [OY78 + 1, OY78 + 2, OY78 + 3]:
		mundo.colocar_bloque(Vector3i(OX78 + 1, y, 1), "pared", true)
		mundo.colocar_bloque(Vector3i(OX78 + 2, y, 1), "pared", true)
		mundo.colocar_bloque(Vector3i(OX78 + 1, y, 3), "pared", true)
		mundo.colocar_bloque(Vector3i(OX78 + 2, y, 3), "pared", true)
		mundo.colocar_bloque(Vector3i(OX78, y, 2) + Vector3i(1, 0, 0), "pared", true) if false else null
	for y in [OY78 + 1, OY78 + 2, OY78 + 3]:
		mundo.colocar_bloque(Vector3i(OX78, y, 1) + Vector3i(1, 0, 0), "pared", true)
		mundo.colocar_bloque(Vector3i(OX78, y, 3) + Vector3i(1, 0, 0), "pared", true)
	mundo.colocar_bloque(Vector3i(OX78 + 3, OY78 + 1, 1), "pared", true)
	mundo.colocar_bloque(Vector3i(OX78 + 3, OY78 + 1, 3), "pared", true)
	mundo.colocar_bloque(Vector3i(OX78 + 3, OY78 + 2, 1), "pared", true)
	mundo.colocar_bloque(Vector3i(OX78 + 3, OY78 + 2, 3), "pared", true)
	mundo.colocar_bloque(Vector3i(OX78 + 3, OY78 + 3, 1), "pared", true)
	mundo.colocar_bloque(Vector3i(OX78 + 3, OY78 + 3, 3), "pared", true)
	assert(mundo.colocar_cama(Vector3i(OX78 + 1, OY78 + 1, 1), Vector3i(1, 0, 0)))
	mundo.colocar_bloque(Vector3i(OX78 + 1, OY78 + 1, 2), "baul", true)

	var estructura_78: Dictionary = mundo.detectar_estructura(Vector3i(OX78, OY78 + 1, 2))
	var blueprint_78 := BlueprintValidator.estructura_a_blueprint(estructura_78)
	print("volumen_sellado: ", blueprint_78["volumen_sellado"], " (esperado: true, la habitación interna no abre ninguna fuga)")
	assert(blueprint_78["volumen_sellado"])
	var motivo_78: String = Player._verificar_acceso_pathfinding(mundo, estructura_78)
	print("Motivo de rechazo: '", motivo_78, "' (esperado: no vacío, la cama queda encerrada)")
	assert(motivo_78 != "")

	print("\n=== TEST 79: _verificar_acceso_pathfinding() acepta 2 puertas externas aunque una quede en un vestíbulo aislado ===")
	# Mismo edificio de TEST 7 (mundo, estructura de TEST 7), agrega una
	# SEGUNDA puerta externa en la cara opuesta (x=6), sin ningún hueco
	# nuevo hacia el resto del edificio salvo la propia puerta — su
	# vestíbulo queda aislado del resto (no hay pasillo interior desde ahí
	# hacia la cama/baúl salvo cruzando toda la habitación este, que SÍ es
	# parte del mismo volumen interior real ya construido en TEST 7, así
	# que en realidad tiene acceso). Para forzar el caso "vestíbulo aislado
	# pero el conjunto de puertas igual llega a todo", basta con reusar la
	# estructura de TEST 7 (ya tiene 2 puertas: principal e interior) y
	# confirmar que sigue aprobando.
	var motivo_79: String = Player._verificar_acceso_pathfinding(mundo, estructura)
	assert(motivo_79 == "", "ya cubierto por TEST 77, se deja explícito como caso de 2 puertas")

	print("\n=== TEST 80: caso combinado — 2 pisos, techo a dos aguas Y hueco de escalera en la losa intermedia ===")
	# El caso real reportado por el usuario: reusa la forma del TEST 12 (2
	# historias, hueco de escalera en la losa intermedia) pero con el techo
	# EXTERIOR (y=8) retranqueado 1 celda en X (3x5 en vez de 5x5), como el
	# TEST 68. Debe reconocer 2 pisos, volumen_sellado=true, y aprobar.
	const OX80 := 500
	for x in range(OX80, OX80 + 5):
		for z in range(5):
			mundo.colocar_bloque(Vector3i(x, 0, z), "pared", true)  # suelo, 5x5
	for x in range(OX80 + 1, OX80 + 4):
		for z in range(5):
			mundo.colocar_bloque(Vector3i(x, 8, z), "pared", true)  # techo, 3x5 (retranqueado)
	for y in range(1, 4):
		for x in range(OX80, OX80 + 5):
			for z in range(5):
				var es_borde80: bool = x == OX80 or x == OX80 + 4 or z == 0 or z == 4
				if not es_borde80:
					continue
				if x == OX80 and z == 2:
					continue  # puerta historia 1
				if x == OX80 + 4 and z == 2 and y == 2:
					continue  # ventana historia 1
				mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	assert(mundo.colocar_puerta(Vector3i(OX80, 1, 2)))
	mundo.colocar_bloque(Vector3i(OX80, 3, 2), "pared", true)
	mundo.colocar_bloque(Vector3i(OX80 + 4, 2, 2), "ventana", true)
	assert(mundo.colocar_cama(Vector3i(OX80 + 1, 1, 1), Vector3i(1, 0, 0)))
	mundo.colocar_bloque(Vector3i(OX80 + 3, 1, 1), "baul", true)
	for x in range(OX80, OX80 + 5):
		for z in range(5):
			if x == OX80 + 2 and z == 2:
				continue  # hueco de escalera (centro de la losa intermedia)
			mundo.colocar_bloque(Vector3i(x, 4, z), "pared", true)
	for y in range(5, 8):
		for x in range(OX80, OX80 + 5):
			for z in range(5):
				var es_borde80b: bool = x == OX80 or x == OX80 + 4 or z == 0 or z == 4
				if not es_borde80b:
					continue
				if x == OX80 and z == 2:
					continue  # puerta historia 2
				if x == OX80 + 4 and z == 2 and y == 6:
					continue  # ventana historia 2
				mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	assert(mundo.colocar_puerta(Vector3i(OX80, 5, 2)))
	mundo.colocar_bloque(Vector3i(OX80, 7, 2), "pared", true)
	mundo.colocar_bloque(Vector3i(OX80 + 4, 6, 2), "ventana", true)

	var estructura_80: Dictionary = mundo.detectar_estructura(Vector3i(OX80, 1, 2))
	var blueprint_80 := BlueprintValidator.estructura_a_blueprint(estructura_80)
	print("Pisos abstractos: ", blueprint_80["pisos"].size(), " (esperados: 2) | volumen_sellado: ", blueprint_80["volumen_sellado"])
	assert(blueprint_80["pisos"].size() == 2)
	assert(blueprint_80["volumen_sellado"])
	var resultado_80: Dictionary = BlueprintValidator.validar_blueprint(blueprint_80)
	print("Válido: ", resultado_80["valido"], " | Errores: ", resultado_80["errores"])
	assert(resultado_80["valido"])
	var motivo_pathfinding_80: String = Player._verificar_acceso_pathfinding(mundo, estructura_80)
	print("Motivo de rechazo: '", motivo_pathfinding_80, "' (esperado: vacío)")
	assert(motivo_pathfinding_80 == "")
```

- [ ] **Step 2: Correr el test para confirmar que falla**

Correr `Test.tscn` con F6. Debe fallar con un error de "función estática no encontrada" (`_verificar_acceso_pathfinding` no existe en `Player`).

- [ ] **Step 3: Implementar los helpers y la validación en `Player.gd`**

En `godot/scripts/Player.gd`, agregar cerca de los demás `const` de preload (línea ~4-77):

```gdscript
const BuscadorRutas = preload("res://scripts/BuscadorRutas.gd")
```

Agregar las 3 funciones nuevas, justo antes de `_declarar_edificio()` (línea ~797):

```gdscript
## Vestíbulos (celdas justo adentro) de cada puerta EXTERNA de "celdas" (el
## resultado de VoxelWorld.detectar_estructura(), Vector3i absoluto ->
## tipo). Una puerta es EXTERNA si al menos uno de sus 2 vecinos
## ortogonales en XZ NO pertenece a la huella del edificio (calculada como
## calcular_despeje(), con la unión de columnas de "celdas"); su vestíbulo
## es el vecino que SÍ pertenece a la huella (por donde entra un NPC).
static func _celdas_externas_puerta(celdas: Dictionary) -> Array[Vector3i]:
	var huella_xz: Dictionary = {}  # Vector2i -> true
	for pos: Vector3i in celdas.keys():
		huella_xz[Vector2i(pos.x, pos.z)] = true

	var origenes: Array[Vector3i] = []
	for pos: Vector3i in celdas.keys():
		if celdas[pos] != "puerta_inferior":
			continue
		var es_externa := false
		var vestibulo := Vector3i.MAX
		for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var vecino_xz := Vector2i(pos.x + delta.x, pos.z + delta.y)
			if huella_xz.has(vecino_xz):
				vestibulo = Vector3i(vecino_xz.x, pos.y, vecino_xz.y)
			else:
				es_externa = true
		if es_externa and vestibulo != Vector3i.MAX:
			origenes.append(vestibulo)
	return origenes


## Celda donde un NPC se para para usar cada cama/baúl de "celdas": encima
## del mueble (una cama o un baúl cuenta como suelo sólido, ver
## BuscadorRutas.es_transitable() — "Una cama o un baúl es suelo, así que
## un colono puede pararse encima").
static func _celdas_objetivo_muebles(celdas: Dictionary) -> Array[Vector3i]:
	var objetivos: Array[Vector3i] = []
	for pos: Vector3i in celdas.keys():
		var tipo: String = celdas[pos]
		if tipo == "cama_cabecera" or tipo == "baul":
			objetivos.append(pos + Vector3i(0, 1, 0))
	return objetivos


## "" si cada cama y cada baúl de "celdas" es alcanzable, por un camino
## transitable real (BuscadorRutas, el mismo A* que usan los colonos, que
## ya trata puerta_inferior/puerta_superior como transitables —
## BuscadorRutas.TIPOS_LIBRES — así que atraviesa puertas internas sin
## tratamiento especial), desde AL MENOS UNA puerta externa del edificio;
## si no, un mensaje de rechazo. No exige que CADA puerta externa por
## separado llegue a todo (decisión del usuario, 2026-09-28): si hay 2
## puertas externas y solo una tiene acceso al resto, igual se aprueba.
static func _verificar_acceso_pathfinding(mundo: Node, celdas: Dictionary) -> String:
	var origenes: Array[Vector3i] = _celdas_externas_puerta(celdas)
	if origenes.is_empty():
		return "ninguna puerta externa tiene un vestíbulo libre para entrar."
	var buscador := BuscadorRutas.new(mundo)
	for pos: Vector3i in celdas.keys():
		var tipo: String = celdas[pos]
		if tipo != "cama_cabecera" and tipo != "baul":
			continue
		var objetivo := pos + Vector3i(0, 1, 0)
		if buscador.buscar_ruta_a_alguna(objetivo, origenes).is_empty():
			var mueble: String = "Una cama" if tipo == "cama_cabecera" else "Un baúl"
			return "%s no tiene un camino transitable hasta ninguna puerta externa." % mueble
	return ""
```

En `_declarar_edificio()`, agregar la llamada nueva justo después del chequeo de `motivo_despeje` (línea ~851-854):

```gdscript
	var motivo_despeje: String = mundo.motivo_despeje_invalido(celdas)
	if motivo_despeje != "":
		_notificar_rechazo("Declarar edificio: %s" % motivo_despeje)
		return
	var motivo_pathfinding: String = _verificar_acceso_pathfinding(mundo, celdas)
	if motivo_pathfinding != "":
		_notificar_rechazo("Declarar edificio: %s" % motivo_pathfinding)
		return
```

- [ ] **Step 4: Correr el test para confirmar que pasa**

Correr `Test.tscn` con F6. TESTs 77-79 deben pasar. Revisar toda la consola: TESTs 1-76 deben seguir pasando.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Player.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "$(cat <<'EOF'
feat: verifica acceso por pathfinding real al declarar un edificio

Player._declarar_edificio() rechaza la declaración si alguna cama o
baúl no es alcanzable, por un camino transitable real, desde ninguna
puerta externa — usa el mismo BuscadorRutas (A*) que los colonos, que ya
trata las puertas (internas o externas) como celdas transitables. Vive
fuera de BlueprintValidator a propósito: necesita el VoxelWorld en vivo.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Actualizar el documento de pendientes

**Files:**
- Modify: `docs/Pendientes y próximos pasos.md`

**Interfaces:** ninguna (solo documentación).

- [ ] **Step 1: Marcar el punto 3 como hecho**

Editar la sección "### 3. Declaración de edificios por volumen interno" en `docs/Pendientes y próximos pasos.md`, agregando al final del párrafo existente (sin borrar el texto original, que documenta el motivo):

```markdown
### 3. Declaración de edificios por volumen interno — ✅ hecho (2026-09-28)

En este punto el jugador ya debe poder declarar y registrar distintos edificios residenciales. Pendiente de revisar: un edificio de dos niveles con una cama en cada nivel no fue reconocido por la declaración. El sistema debería cambiar a uno que detecte el **volumen interno** de una construcción, para permitir edificios personalizados de formas variadas (pirámides, cilindros, irregulares).

Resuelto con un flood-fill 3D del volumen interior sellado (reemplaza la comparación de cada losa contra la huella global del edificio), más el resto del checklist de "casa aprobable": vestíbulo libre detrás de cada puerta (externa o interna) y verificación de acceso real por pathfinding a cada cama/baúl desde al menos una puerta externa. Ver `docs/superpowers/specs/2026-09-28-volumen-interno-edificios-design.md` y `docs/superpowers/plans/2026-09-28-volumen-interno-edificios.md`.
```

- [ ] **Step 2: Commit**

```bash
git add "docs/Pendientes y próximos pasos.md"
git commit -m "$(cat <<'EOF'
docs: marca hecha la declaración de edificios por volumen interno

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
