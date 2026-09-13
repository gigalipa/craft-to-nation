# Piso como Tierra Expuesta (Identidad de Recurso) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer que la capa superficial del mundo (bloques `"piso"`, colocados por `VoxelWorld._generar_terreno()` en la celda más alta de cada columna) se cuente como `"tierra"` real cuando un puesto de recolección (mina, y a futuro NPCs) detecta recursos — sin cambiar el renderizado ni las reglas de construcción, donde `"piso"` debe seguir siendo un tipo de bloque distinto y nunca estructural.

**Architecture:** `"piso"` sigue existiendo tal cual como tipo de bloque (mesh, colocación manual del jugador, exclusión de `TIPOS_ESTRUCTURA`). Se agrega una única función de traducción de "identidad de recurso" en `VoxelWorld.gd` (fuente única de verdad sobre semántica de bloques, junto a `TIPOS_ESTRUCTURA`/`TIPOS_ARBOL`), y el único consumidor actual que le importa esa identidad — `Recoleccion.detectar_recursos()` — la usa antes de contar. Ningún otro archivo cambia.

**Tech Stack:** Godot 4.7, GDScript.

**Spec:** No hay spec architectural — este cambio se clasificó como **bounded** en `superpowers:brainstorming` (código ya existente, cambio pequeño y bien delimitado) y el diseño se presentó y aprobó en chat. Este plan documento es la única referencia escrita; no existe un archivo de spec separado en `docs/superpowers/specs/`.

## Global Constraints

- No modificar `TIPOS_ESTRUCTURA`, `BlueprintValidator.gd`, `Construccion.gd` ni ningún test de construcción/blueprints — `"piso"` debe seguir comportándose exactamente igual en esos flujos (nunca estructural, tipo de relleno de terreno).
- No tocar el mesh/render de `"piso"` ni `"tierra"` en `assets/BlockLibrary.res`.
- **Coordinación con trabajo paralelo:** el usuario está trabajando en simultáneo con otro agente en cambios de minas dentro de `Recoleccion.gd`. Este plan toca `Recoleccion.gd` en un solo punto muy acotado (dentro de `detectar_recursos()`, ver Tarea 2) — si al ejecutar este plan `Recoleccion.gd` ya no coincide con el fragmento citado abajo, DETENTE y pide al usuario que confirme cómo reconciliar antes de editar, no intentes adivinar el merge.
- Usar tabulaciones (no espacios) en todo el GDScript nuevo, como exige el repo.
- Después de implementar, ejecutar `godot/scenes/Test.tscn` y `godot/scenes/RecoleccionTest.tscn` con Godot 4.7 y confirmar que todas las aserciones pasan (regla del `CLAUDE.md` del repo para cambios en `godot/`).

---

## Task 1: `VoxelWorld.material_real()` — mapeo de identidad de recurso

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd:62` (insertar la constante y la función nuevas entre `TIPOS_ESTRUCTURA` (líneas 58-61) y el comentario de `TIPOS_ARBOL` (línea 63))
- Test: `godot/scripts/RecoleccionTest.gd` (se agrega en la Tarea 2, junto con el test de integración — `material_real()` es una función de una sola línea de lookup, no necesita su propio archivo de test aislado; sigue el mismo patrón que `TIPOS_NO_MINERALES` en `Recoleccion.gd`, que tampoco tiene test dedicado por separado)

**Interfaces:**
- Produces: `VoxelWorld.material_real(tipo: String) -> String` — dado un tipo de bloque real, devuelve el material que representa para efectos de RECURSO (no de renderizado ni de construcción). Hoy solo traduce `"piso"` → `"tierra"`; cualquier otro tipo se devuelve sin cambios.

- [ ] **Step 1: Insertar la constante y la función en `VoxelWorld.gd`**

Editar `godot/scripts/VoxelWorld.gd`, insertando el siguiente bloque inmediatamente después de la línea 61 (el `]` que cierra `TIPOS_ESTRUCTURA`) y antes de la línea 63 (`## Tipos de bloque generados por _generar_arboles()...`):

```gdscript

## La celda de superficie de cada columna del mundo se coloca como "piso"
## (ver _generar_terreno() — reutiliza el bloque caminable), pero
## geológicamente es el mismo material que el subsuelo justo debajo
## ("tierra", ver GeneradorMundo.tipo_en_profundidad()). La distinción
## piso/tierra es puramente visual (bloque caminable vs. bloque de
## relleno); para cualquier consumidor que le importe la IDENTIDAD del
## recurso (minas, a futuro NPCs — ver Recoleccion.detectar_recursos()),
## "piso" debe contarse como "tierra". No afecta renderizado ni
## construcción: "piso" sigue fuera de TIPOS_ESTRUCTURA y sigue siendo un
## bloque distinto en la MeshLibrary.
const MATERIAL_REAL := {"piso": "tierra"}


## Traduce "tipo" (el tipo de bloque real, tal como lo devuelve
## obtener_tipo()) al material que representa para efectos de RECURSO —
## ver MATERIAL_REAL más arriba. Devuelve "tipo" sin cambios si no hay
## traducción registrada.
func material_real(tipo: String) -> String:
	return MATERIAL_REAL.get(tipo, tipo)
```

Resultado esperado: `VoxelWorld.gd` queda con `TIPOS_ESTRUCTURA` (líneas 58-61), luego el bloque nuevo (`MATERIAL_REAL` + `material_real()`), y a continuación el comentario/constante `TIPOS_ARBOL` que ya existía — sin reordenar nada más del archivo.

- [ ] **Step 2: Verificar que el archivo compila (carga sin errores en el editor)**

Este paso no tiene test automatizado propio — `material_real()` se ejerce end-to-end en la Tarea 2. Confirma únicamente que Godot no reporta errores de sintaxis al abrir el proyecto (por ejemplo, abriendo `godot/scenes/Test.tscn` en el editor o vía el MCP de Godot si está disponible: `get_debug_output` no debe mostrar errores de parseo de `VoxelWorld.gd`).

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/VoxelWorld.gd
git commit -m "feat: VoxelWorld.material_real() traduce piso a tierra para identidad de recurso"
```

---

## Task 2: Usar `material_real()` en `Recoleccion.detectar_recursos()`

**Files:**
- Modify: `godot/scripts/Recoleccion.gd:100-102` (dentro de `detectar_recursos()`)
- Test: `godot/scripts/RecoleccionTest.gd` (nuevo TEST 11, agregado al final de `ejecutar_pruebas()`, antes de la línea de cierre `print("\n=== Las 10 pruebas de Recoleccion pasaron correctamente ===")` — que además debe actualizarse a "11 pruebas")

**Interfaces:**
- Consumes: `VoxelWorld.material_real(tipo: String) -> String` (Tarea 1).
- Produces: ningún símbolo nuevo — `detectar_recursos()` conserva su firma `detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Dictionary`.

**Estado actual de `detectar_recursos()` (para localizar el punto exacto de cambio — si no coincide, ver "Coordinación con trabajo paralelo" en Global Constraints):**

```gdscript
func detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Dictionary:
	var conteo: Dictionary = {}  # String (tipo) -> int
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			for dy in range(0, PROFUNDIDAD_MINA_NIVEL_1 + 1):
				var offset := Vector3(dx, -dy, dz)
				if offset.length() > RADIO_AREA_MINA:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				var tipo: String = mundo.obtener_tipo(celda)
				if tipo != "" and not TIPOS_NO_MINERALES.has(tipo):
					conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo
```

- [ ] **Step 1: Escribir el test que falla primero**

Agregar en `godot/scripts/RecoleccionTest.gd`, inmediatamente antes de la línea final `print("\n=== Las 10 pruebas de Recoleccion pasaron correctamente ===")`:

```gdscript
	print("\n=== TEST 11: detectar_recursos() cuenta 'piso' como 'tierra' (superficie expuesta) ===")
	var mundo_superficie: Node = VoxelWorld.new()
	mundo_superficie.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_superficie.cell_size = Vector3.ONE * 1.0
	mundo_superficie._indexar_biblioteca()
	assert(mundo_superficie.material_real("piso") == "tierra")
	assert(mundo_superficie.material_real("piedra") == "piedra")  # sin traducción, se devuelve igual

	# Misma superficie plana que TEST 1, pero con la capa expuesta como
	# "piso" (dy=0) y "tierra" real justo debajo (dy=1) — replica lo que
	# hace VoxelWorld._generar_terreno() en el mundo real.
	var centro_superficie := Vector2i(100, 100)
	var altura_sup := 10
	for dx in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx, dz).length() > Recoleccion.RADIO_AREA_MINA:
				continue
			mundo_superficie.colocar_bloque(Vector3i(centro_superficie.x + dx, altura_sup, centro_superficie.y + dz), "piso")
			mundo_superficie.colocar_bloque(Vector3i(centro_superficie.x + dx, altura_sup - 1, centro_superficie.y + dz), "tierra")

	var conteo_superficie: Dictionary = Recoleccion.detectar_recursos(mundo_superficie, centro_superficie, altura_sup)
	print("Conteo detectado (piso + tierra): ", conteo_superficie)
	assert(not conteo_superficie.has("piso"))
	assert(conteo_superficie.get("tierra", 0) > 0)
	# La celda dy=0 (el disco completo de radio 6, todas "piso") y la celda
	# dy=1 (mismo disco, todas "tierra" real) deben sumarse en un solo
	# conteo de "tierra": el total tiene que ser el doble de un solo disco.
	var celdas_un_disco := 0
	for dx2 in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz2 in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx2, dz2).length() <= Recoleccion.RADIO_AREA_MINA:
				celdas_un_disco += 1
	assert(conteo_superficie["tierra"] == celdas_un_disco * 2)
	print("OK: la capa superficial 'piso' se cuenta como 'tierra', sumada a la 'tierra' real de debajo.")

```

- [ ] **Step 2: Ejecutar `RecoleccionTest.tscn` y confirmar que TEST 11 falla**

Abre `godot/scenes/RecoleccionTest.tscn` en el editor de Godot 4.7 (F6, o mediante el MCP de Godot: `run_project` apuntando a esa escena) y revisa el panel "Output".

Expected: falla en `assert(mundo_superficie.material_real("piso") == "tierra")` — el método `material_real()` todavía no existe si la Tarea 1 no se aplicó, o falla en `assert(not conteo_superficie.has("piso"))` si la Tarea 1 ya está pero `detectar_recursos()` aún no la usa.

- [ ] **Step 3: Aplicar el cambio mínimo en `Recoleccion.gd`**

Reemplazar en `godot/scripts/Recoleccion.gd`, dentro de `detectar_recursos()`:

```gdscript
				var tipo: String = mundo.obtener_tipo(celda)
				if tipo != "" and not TIPOS_NO_MINERALES.has(tipo):
					conteo[tipo] = conteo.get(tipo, 0) + 1
```

por:

```gdscript
				var tipo: String = mundo.material_real(mundo.obtener_tipo(celda))
				if tipo != "" and not TIPOS_NO_MINERALES.has(tipo):
					conteo[tipo] = conteo.get(tipo, 0) + 1
```

(`material_real("")` devuelve `""` sin traducción — el chequeo `tipo != ""` sigue funcionando igual que antes para celdas de aire.)

- [ ] **Step 4: Ejecutar `RecoleccionTest.tscn` de nuevo y confirmar que las 11 pruebas pasan**

Mismo procedimiento del Step 2. Expected: sin errores de assert en el Output, y el mensaje final debe leerse "Las 11 pruebas de Recoleccion pasaron correctamente".

- [ ] **Step 5: Actualizar el contador final de pruebas**

En `godot/scripts/RecoleccionTest.gd`, cambiar:

```gdscript
	print("\n=== Las 10 pruebas de Recoleccion pasaron correctamente ===")
```

por:

```gdscript
	print("\n=== Las 11 pruebas de Recoleccion pasaron correctamente ===")
```

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: las minas cuentan la capa superficial 'piso' como recurso 'tierra'"
```

---

## Task 3: Verificación de regresión completa (`Test.tscn`)

**Files:** ninguno (solo verificación — regla del `CLAUDE.md` del repo para cambios en `godot/`).

**Interfaces:** ninguna nueva.

- [ ] **Step 1: Ejecutar `godot/scenes/Test.tscn` completo**

Abre `godot/scenes/Test.tscn` en Godot 4.7 (F6, o `run_project` vía MCP) y confirma en el Output que las 14 pruebas existentes (BlueprintValidator/VoxelWorld/Construccion, incluyendo las de `calcular_despeje()`/`verificar_despejes()`) siguen pasando sin cambios — esta tarea no debería tocar ningún comportamiento de construcción, pero `Test.tscn` es la escena de regresión general exigida por el `CLAUDE.md` del repo.

Expected: sin errores de assert, mismo conteo de pruebas que antes de este plan.

- [ ] **Step 2: Ejecutar `godot/scenes/RecoleccionTest.tscn` una vez más de forma aislada**

Repite el Step 4 de la Tarea 2, ahora como confirmación final independiente (no como parte del ciclo TDD de esa tarea).

Expected: "Las 11 pruebas de Recoleccion pasaron correctamente", sin errores.

- [ ] **Step 3: Reportar al usuario**

No hay commit en este paso (es solo verificación). Informa al usuario que `Test.tscn` (14/14) y `RecoleccionTest.tscn` (11/11) pasan, y que `BlueprintValidator.gd`/`Construccion.gd` no se tocaron.

