# Nivelación del Frente y Overlays de Previsualización Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que al emplazar un edificio se nivele toda la fachada del lado de sus puertas (las 2 columnas delante de todo ese lado, al nivel del suelo frontal de la puerta) y que la previsualización pinte las celdas reservadas delante de puertas y ventanas y la región que será nivelada.

**Architecture:** `NiveladorTerreno.calcular_base_y()` devuelve además la fachada (columna → nivel `G`); `calcular_nivelacion_fachada()` calcula su excavación y relleno. `VoxelWorld.verificar_despejes()` acepta terreno natural sobre `G` en la fachada (se va a cavar). `CamaraCenital` unifica las validaciones en `_evaluar_blueprint()` y la nivelación en `_plan_nivelacion()` (una sola fuente para clic, resumen de materiales y overlays); un nodo nuevo `NivelacionOverlay` dibuja cajas (celdas reservadas) y planos (región nivelada).

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), proyecto en `godot/`. Pruebas: `NiveladorTerrenoTest.tscn`, `Test.tscn` (`BlueprintValidatorTest.gd`).

**Spec:** `docs/superpowers/specs/2026-09-20-nivelacion-frente-y-overlays-design.md`

## Global Constraints

- Godot 4.7; en GDScript se usan **tabulaciones**.
- Conservar el español en documentación, mensajes del juego y pruebas.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- Cambios pequeños; no reformatear archivos ajenos al objetivo. Los puestos periféricos NO cambian (`calcular_relleno()` sigue usando `altura_objetivo()`). `Player._declarar_edificio()` sigue llamando `verificar_despejes(celdas)` sin el argumento nuevo y su comportamiento no cambia.
- `LIMITE_PENDIENTE = 2` se reutiliza; no se agrega tope global de profundidad.
- Es solo visual: no existe inventario real; no se cobra ni se consume nada.
- Los colores de puertas/ventanas destacadas siguen solo en `VoxelWorld.COLOR_DESTACADO`; los colores de los overlays nuevos son constantes de `NivelacionOverlay.gd`.
- Rama de trabajo: `feat/nivelar-frente-y-overlays` (ya creada, con el spec). No agregar al commit los archivos sin versionar del usuario (`docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md`, `*.gd.uid`, cambios en el doc de PoC 5).
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```
- Cómo correr una escena (el proyecto usa el MCP de Godot, no CLI): cargar con ToolSearch `select:mcp__godot__run_project,mcp__godot__get_debug_output,mcp__godot__stop_project`; `run_project` con `projectPath = C:\Users\peraz\Projects\Misc\CityCraft\godot` y la escena; leer `get_debug_output`; `stop_project`; confirmar con `Get-Process | Where-Object { $_.ProcessName -like "*godot*" }` (matar huérfanos propios con `Stop-Process -Id <id> -Force`; el PID 4688 preexistente no es nuestro). Éxito = línea final "pasaron correctamente" y ningún `ERROR`/"Assertion failed". Al arrancar `Main.tscn` solo son esperables los avisos preexistentes (constantes `BlueprintValidator`/`Player`, UID inválido de `BlockLibrary.res`).

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `godot/scripts/NiveladorTerreno.gd` (modificar) | `calcular_base_y` con fachada; `calcular_nivelacion_fachada`; comparador compartido |
| `godot/scripts/NiveladorTerrenoTest.gd` (modificar) | pruebas 16-20 |
| `godot/scripts/VoxelWorld.gd` (modificar) | `es_terreno_natural`, `despeje_bloqueado`, `verificar_despejes(…, terreno_a_nivelar)` |
| `godot/scripts/BlueprintValidatorTest.gd` (modificar) | TEST 51 y 52 |
| `godot/scripts/CamaraCenital.gd` (modificar) | `_evaluar_blueprint`, `_mensaje_rechazo_blueprint`, `_plan_nivelacion`, clic, previsualización, resumen, overlays |
| `godot/scripts/NivelacionOverlay.gd` (crear) | dibuja las cajas y los planos |
| GDD §5, doc técnico PoC 6 (modificar) | documentación |

---

### Task 1: Fachada, su nivel y su nivelación (lógica pura)

**Files:**
- Modify: `godot/scripts/NiveladorTerreno.gd`
- Test: `godot/scripts/NiveladorTerrenoTest.gd`

**Interfaces:**
- Consumes: `_generador.altura_en(x, z) -> int`, `LIMITE_PENDIENTE`, `DIRECCIONES_XZ`, `altura_objetivo()` (ya existentes).
- Produces:
  - `calcular_base_y(esquina, celdas_3d) -> Dictionary` ahora con la clave `"fachada": Dictionary` (columna mundial `Vector2i` → nivel `G`) en **todos** los resultados (`{}` si es inválido). Nuevo motivo de invalidez `"puertas"` cuando dos puertas de la misma dirección piden `G` distintos o una columna cae en dos fachadas con `G` distintos.
  - `calcular_nivelacion_fachada(fachada: Dictionary) -> Dictionary` → `{"excavacion": Array[Vector3i], "relleno": Dictionary}` (excavación de arriba hacia abajo; relleno `Vector2i` → cantidad).

- [ ] **Step 1: Escribir las pruebas que fallan**

En `NiveladorTerrenoTest.gd`, tras `_casa_4x5()` agrega:

```gdscript
## Huella en L (14 columnas): barra x=0..4 x z=0..1 más barra x=0..1 x z=2..3;
## losa "pared" en y=0 y una puerta en (x=3, z=1) (y=1..2) que mira hacia +z.
func _casa_l() -> Dictionary:
	var celdas: Dictionary = {}
	for x in range(5):
		for z in range(2):
			celdas[Vector3i(x, 0, z)] = "pared"
	for x in range(2):
		for z in range(2, 4):
			celdas[Vector3i(x, 0, z)] = "pared"
	celdas[Vector3i(3, 1, 1)] = "puerta_inferior"
	celdas[Vector3i(3, 2, 1)] = "puerta_superior"
	return celdas
```

Reemplaza la última línea de `ejecutar_pruebas()` (`print("\n=== Las 15 pruebas de NiveladorTerreno pasaron correctamente ===")`) por las pruebas nuevas y la línea final actualizada:

```gdscript
	print("\n=== TEST 16: calcular_base_y() devuelve la fachada del lado de la puerta, al nivel del suelo frontal ===")
	# Casa 4x5 con la puerta al oeste (x=0, z=2), terreno plano de altura 5, esquina (10,10):
	# toda la cara oeste (5 columnas) x 2 de fondo = 10 columnas a nivel G = 5.
	var base_16: Dictionary = nivelador_plano.calcular_base_y(Vector2i(10, 10), _casa_4x5())
	assert(base_16["valido"])
	var fachada_16: Dictionary = base_16["fachada"]
	assert(fachada_16.size() == 10, "5 columnas de ancho x 2 de fondo")
	for z_16 in range(10, 15):
		assert(fachada_16.get(Vector2i(9, z_16)) == 5, "primera columna delante de la cara oeste")
		assert(fachada_16.get(Vector2i(8, z_16)) == 5, "segunda columna delante de la cara oeste")
	for clave_16 in fachada_16:
		assert(clave_16.x < 10, "ninguna columna de la fachada pertenece a la huella")

	print("\n=== TEST 17: la fachada de una huella en L sigue el contorno real ===")
	# Puerta mirando hacia +z. Bordes que miran a +z: (2,1),(3,1),(4,1) a z=1 y (0,3),(1,3) a z=3.
	var base_17: Dictionary = nivelador_plano.calcular_base_y(Vector2i(10, 10), _casa_l())
	assert(base_17["valido"])
	var fachada_17: Dictionary = base_17["fachada"]
	assert(fachada_17.size() == 10)
	assert(fachada_17.has(Vector2i(12, 12)) and fachada_17.has(Vector2i(14, 13)))  # delante de la barra ancha
	assert(fachada_17.has(Vector2i(10, 14)) and fachada_17.has(Vector2i(11, 15)))  # delante del brazo de la L
	assert(not fachada_17.has(Vector2i(10, 12)) and not fachada_17.has(Vector2i(10, 13)), "esas columnas son de la propia L")

	print("\n=== TEST 18: dos puertas de la misma dirección con suelo frontal distinto se rechazan (aunque su base_y coincida) ===")
	# altura_en = z. Puerta A (y=1) en z=2 -> G=12, base 12. Puerta B (y=2) en z=3 -> G=13, base 13+1-2 = 12: misma base_y, distinto G.
	var casa_18: Dictionary = _casa_4x5()
	casa_18[Vector3i(0, 2, 3)] = "puerta_inferior"
	casa_18[Vector3i(0, 3, 3)] = "puerta_superior"
	var base_18: Dictionary = nivelador_suave.calcular_base_y(Vector2i(10, 10), casa_18)
	assert(not base_18["valido"] and base_18["motivo"] == "puertas")
	assert(base_18["fachada"].is_empty())

	print("\n=== TEST 19: calcular_nivelacion_fachada() cava por encima del nivel y rellena por debajo ===")
	# altura_en = z; nivel 12 en tres columnas de alturas 10, 12 y 14.
	var nivelacion_19: Dictionary = nivelador_suave.calcular_nivelacion_fachada({
		Vector2i(9, 10): 12, Vector2i(9, 12): 12, Vector2i(9, 14): 12,
	})
	var excavacion_19: Array[Vector3i] = nivelacion_19["excavacion"]
	assert(excavacion_19.size() == 2, "solo la columna de altura 14 se cava")
	assert(excavacion_19[0] == Vector3i(9, 14, 14) and excavacion_19[1] == Vector3i(9, 13, 14), "de arriba hacia abajo")
	assert(nivelacion_19["relleno"].size() == 1 and nivelacion_19["relleno"][Vector2i(9, 10)] == 2, "solo la columna de altura 10 necesita 2 bloques")

	print("\n=== TEST 20: el límite de pendiente sobre huella + fachada rechaza donde la huella sola pasaba ===")
	# Acantilado (altura 100) en (2,2): es la segunda columna delante de la puerta con esquina (4,0).
	var base_20: Dictionary = nivelador_acantilado.calcular_base_y(Vector2i(4, 0), _casa_4x5())
	assert(base_20["valido"], "la puerta y su frente inmediato (3,2) están a nivel")
	var union_20: Array[Vector2i] = _rectangulo(4, 5)
	for columna_20: Vector2i in base_20["fachada"]:
		union_20.append(columna_20 - Vector2i(4, 0))
	assert(nivelador_acantilado.verificar_pendiente(Vector2i(4, 0), _rectangulo(4, 5)), "la huella sola es válida")
	assert(not nivelador_acantilado.verificar_pendiente(Vector2i(4, 0), union_20), "con la fachada, el acantilado invalida")

	print("\n=== Las 20 pruebas de NiveladorTerreno pasaron correctamente ===")
```

Actualiza el encabezado del archivo: en el comentario superior cambia "debe imprimir las 15 pruebas" por "debe imprimir las 20 pruebas".

- [ ] **Step 2: Correr la escena y verificar que falla**

Run: `res://scenes/NiveladorTerrenoTest.tscn`.
Expected: FAIL — las pruebas 1-15 pasan y la 16 falla (`Invalid access to index 'fachada'` o similar).

- [ ] **Step 3: Implementar**

En `NiveladorTerreno.gd`:

(a) Reemplaza el cuerpo de ordenamiento de `calcular_excavacion()` por un comparador compartido. Sustituye

```gdscript
	celdas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y > b.y
		if a.x != b.x:
			return a.x < b.x
		return a.z < b.z
	)
	return celdas
```

por

```gdscript
	celdas.sort_custom(_arriba_abajo)
	return celdas


## Comparador de celdas de excavación: de arriba hacia abajo, luego x, luego z.
static func _arriba_abajo(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y > b.y
	if a.x != b.x:
		return a.x < b.x
	return a.z < b.z
```

(b) Reemplaza `calcular_base_y()` completa (comentario incluido) por:

```gdscript
## Nivel base de un blueprint colocado en "esquina": la Y mundial de su
## celda rel.y=0 (la losa de piso) tal que cada "puerta_inferior" quede a
## nivel del suelo natural delante de ella — base_y = altura_en(frente) + 1 -
## rel.y_puerta. "frente" es el vecino cardinal en XZ que cae fuera de la
## huella (mismo criterio que VoxelWorld.calcular_despeje()). Rechaza
## ("valido": false) si una puerta y su frente difieren en más de
## LIMITE_PENDIENTE ("pendiente") o si dos puertas piden base_y distintos, o
## dos puertas de la misma dirección piden un suelo frontal G distinto, o una
## columna cae en dos fachadas con G distinto ("puertas"). Sin puertas
## devuelve altura_objetivo() + 1, el comportamiento anterior. "frentes" son
## todas las columnas frontales, para que el llamador valide lo que este
## módulo no ve (agua, límites del mundo).
##
## "fachada" (columna mundial Vector2i -> G) es la franja que también se
## nivela (ver docs/superpowers/specs/2026-09-20-nivelacion-frente-y-overlays-
## design.md): para cada dirección con puerta, las 2 columnas delante de TODAS
## las columnas de la huella cuyo vecino en esa dirección queda fuera de ella
## (todo el lado; en una huella en L sigue el contorno), sin contar columnas
## de la propia huella. G es el suelo natural delante de la puerta. Vacía si
## el resultado es inválido.
func calcular_base_y(esquina: Vector2i, celdas_3d: Dictionary) -> Dictionary:
	var huella: Dictionary = {}  # Vector2i -> true
	var columnas: Array[Vector2i] = []
	for rel in celdas_3d:
		var xz := Vector2i(rel.x, rel.z)
		if not huella.has(xz):
			huella[xz] = true
			columnas.append(xz)
	var respaldo: int = altura_objetivo(esquina, columnas) + 1

	var frentes: Array[Vector2i] = []
	var candidatos: Dictionary = {}  # int base_y -> true
	var nivel_por_direccion: Dictionary = {}  # Vector2i (dirección) -> int (G)
	for rel in celdas_3d:
		if celdas_3d[rel] != "puerta_inferior":
			continue
		var xz := Vector2i(rel.x, rel.z)
		for direccion: Vector2i in DIRECCIONES_XZ:
			if huella.has(xz + direccion):
				continue
			var columna_puerta := esquina + xz
			var frente := columna_puerta + direccion
			var suelo_frente: int = _generador.altura_en(frente.x, frente.y)
			if abs(_generador.altura_en(columna_puerta.x, columna_puerta.y) - suelo_frente) > LIMITE_PENDIENTE:
				return _base_y_invalida(respaldo, "pendiente", frentes)
			frentes.append(frente)
			candidatos[suelo_frente + 1 - rel.y] = true
			if nivel_por_direccion.get(direccion, suelo_frente) != suelo_frente:
				return _base_y_invalida(respaldo, "puertas", frentes)
			nivel_por_direccion[direccion] = suelo_frente
	if candidatos.size() > 1:
		return _base_y_invalida(respaldo, "puertas", frentes)

	var fachada: Dictionary = {}  # Vector2i (columna mundial) -> int (G)
	for direccion: Vector2i in nivel_por_direccion:
		var nivel: int = nivel_por_direccion[direccion]
		for c: Vector2i in columnas:
			if huella.has(c + direccion):
				continue
			for paso in range(1, 3):
				var relativa: Vector2i = c + direccion * paso
				if huella.has(relativa):
					continue
				var columna: Vector2i = esquina + relativa
				if fachada.get(columna, nivel) != nivel:
					return _base_y_invalida(respaldo, "puertas", frentes)
				fachada[columna] = nivel

	var base_y: int = respaldo if candidatos.is_empty() else candidatos.keys()[0]
	return {"valido": true, "base_y": base_y, "motivo": "", "frentes": frentes, "fachada": fachada}


func _base_y_invalida(respaldo: int, motivo: String, frentes: Array[Vector2i]) -> Dictionary:
	return {"valido": false, "base_y": respaldo, "motivo": motivo, "frentes": frentes, "fachada": {}}


## Lo que hay que cavar y rellenar para llevar cada columna de "fachada"
## (columna mundial -> nivel G, ver calcular_base_y()) a su nivel: se cava todo
## bloque por encima de G y se rellena de tierra hasta G. Devuelve
## {"excavacion": Array[Vector3i] (de arriba hacia abajo), "relleno":
## Dictionary (Vector2i -> cantidad de bloques)}.
func calcular_nivelacion_fachada(fachada: Dictionary) -> Dictionary:
	var excavacion: Array[Vector3i] = []
	var relleno: Dictionary = {}  # Vector2i -> int
	for columna: Vector2i in fachada:
		var nivel: int = fachada[columna]
		var superficie: int = _generador.altura_en(columna.x, columna.y)
		for y in range(superficie, nivel, -1):
			excavacion.append(Vector3i(columna.x, y, columna.y))
		if nivel > superficie:
			relleno[columna] = nivel - superficie
	excavacion.sort_custom(_arriba_abajo)
	return {"excavacion": excavacion, "relleno": relleno}
```

- [ ] **Step 4: Correr la escena y verificar que pasa**

Run: `res://scenes/NiveladorTerrenoTest.tscn`.
Expected: PASS — "=== Las 20 pruebas de NiveladorTerreno pasaron correctamente ===" (las pruebas 1-15 originales incluidas: `calcular_relleno`/`calcular_excavacion` siguen igual).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/NiveladorTerreno.gd godot/scripts/NiveladorTerrenoTest.gd
git commit -m "feat: fachada del lado de la puerta, su nivel y su nivelación (lógica pura)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: Despeje sobre terreno a nivelar (VoxelWorld)

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd` (`verificar_despejes`, ~línea 313)
- Test: `godot/scripts/BlueprintValidatorTest.gd` (antes de la línea final "Las 54 pruebas…")

**Interfaces:**
- Consumes: `calcular_despeje()`, `obtener_tipo()`, `TIPOS_ARBOL`, `TIPOS_ESTRUCTURA`, `celda_a_edificio`.
- Produces:
  - `es_terreno_natural(celda: Vector3i) -> bool`
  - `despeje_bloqueado(celda: Vector3i, terreno_a_nivelar: Dictionary = {}) -> bool` (`terreno_a_nivelar`: columna `Vector2i` → nivel `G`)
  - `verificar_despejes(celdas_mundo: Dictionary, terreno_a_nivelar: Dictionary = {}) -> bool`

- [ ] **Step 1: Escribir las pruebas que fallan**

En `BlueprintValidatorTest.gd`, antes de `print("\n=== Las 54 pruebas de BlueprintValidator pasaron correctamente ===")`, agrega (usa `mundo_d`, el mundo propio creado en el TEST 49):

```gdscript
	print("\n=== TEST 51: verificar_despejes() acepta terreno natural sobre el nivel en una columna a nivelar, y sigue rechazando árbol, estructura y terreno fuera de la fachada ===")
	const OX51 := 1500
	var celdas_51 := {
		Vector3i(OX51, 1, OX51): "puerta_inferior",
		Vector3i(OX51, 2, OX51): "puerta_superior",
	}
	var despeje_51: Array = mundo_d.calcular_despeje(celdas_51)
	assert(despeje_51.size() == 16, "4 direcciones x 2 pasos x 2 niveles")
	for celda_51 in despeje_51:
		mundo_d.colocar_bloque(celda_51, "tierra")
	var niveles_51: Dictionary = {}
	for celda_51 in despeje_51:
		niveles_51[Vector2i(celda_51.x, celda_51.z)] = 0
	assert(not mundo_d.verificar_despejes(celdas_51), "sin nivelación, el terreno en el despeje rechaza (comportamiento anterior)")
	assert(mundo_d.verificar_despejes(celdas_51, niveles_51), "terreno natural sobre el nivel de una columna a nivelar no bloquea")

	var celda_prueba_51: Vector3i = despeje_51[0]
	var columna_prueba_51 := Vector2i(celda_prueba_51.x, celda_prueba_51.z)
	mundo_d.set_cell_item(celda_prueba_51, GridMap.INVALID_CELL_ITEM)
	mundo_d.colocar_bloque(celda_prueba_51, "madera")
	assert(not mundo_d.verificar_despejes(celdas_51, niveles_51), "un árbol sigue bloqueando")
	mundo_d.set_cell_item(celda_prueba_51, GridMap.INVALID_CELL_ITEM)
	mundo_d.colocar_bloque(celda_prueba_51, "pared")
	assert(not mundo_d.verificar_despejes(celdas_51, niveles_51), "una estructura sigue bloqueando")
	mundo_d.set_cell_item(celda_prueba_51, GridMap.INVALID_CELL_ITEM)
	mundo_d.colocar_bloque(celda_prueba_51, "tierra")
	assert(mundo_d.verificar_despejes(celdas_51, niveles_51), "restaurado el terreno, vuelve a aceptarse")

	var niveles_sin_51: Dictionary = niveles_51.duplicate()
	niveles_sin_51.erase(columna_prueba_51)
	assert(not mundo_d.verificar_despejes(celdas_51, niveles_sin_51), "terreno en una columna que no se nivela sigue bloqueando")
	var niveles_altos_51: Dictionary = niveles_51.duplicate()
	niveles_altos_51[columna_prueba_51] = celda_prueba_51.y
	assert(mundo_d.despeje_bloqueado(celda_prueba_51, niveles_altos_51), "una celda que no está POR ENCIMA del nivel sigue bloqueando")
	assert(not mundo_d.despeje_bloqueado(celda_prueba_51, niveles_51))
	print("OK: el terreno natural sobre el nivel no bloquea; árbol, estructura y columnas fuera de la fachada sí.")

	print("\n=== TEST 52: es_terreno_natural() distingue terreno de árbol, estructura, fantasma, agua, vacío y edificio ===")
	const OX52 := 1510
	var c_tierra_52 := Vector3i(OX52, 1, OX52)
	mundo_d.colocar_bloque(c_tierra_52, "tierra")
	assert(mundo_d.es_terreno_natural(c_tierra_52))
	assert(not mundo_d.es_terreno_natural(Vector3i(OX52 + 1, 1, OX52)), "celda vacía")
	for tipo_52 in ["madera", "follaje", "pared", "fantasma", "agua"]:
		var celda_52 := Vector3i(OX52 + 2, 1, OX52)
		mundo_d.set_cell_item(celda_52, GridMap.INVALID_CELL_ITEM)
		mundo_d.colocar_bloque(celda_52, tipo_52)
		assert(not mundo_d.es_terreno_natural(celda_52), "no es terreno natural: " + tipo_52)
	mundo_d.registrar_edificio([c_tierra_52])
	assert(not mundo_d.es_terreno_natural(c_tierra_52), "una celda que pertenece a un edificio no es terreno")
	print("OK: solo el suelo/subsuelo libre cuenta como terreno natural.")
```

Cambia la línea final a `print("\n=== Las 56 pruebas de BlueprintValidator pasaron correctamente ===")`.

- [ ] **Step 2: Correr `Test.tscn` y verificar que falla**

Run: `res://scenes/Test.tscn`.
Expected: FAIL en TEST 51 — `Invalid call. Nonexistent function 'despeje_bloqueado'` / `Too many arguments for verificar_despejes`.

- [ ] **Step 3: Implementar**

En `VoxelWorld.gd`, reemplaza `verificar_despejes()` (y agrega las dos funciones nuevas justo antes de ella) por:

```gdscript
## true si "celda" es terreno natural (suelo o subsuelo libre): ocupada y ni
## árbol, ni estructura, ni "fantasma", ni agua, ni parte de un edificio.
func es_terreno_natural(celda: Vector3i) -> bool:
	var tipo: String = obtener_tipo(celda)
	if tipo == "" or tipo == "fantasma" or tipo == "agua":
		return false
	if TIPOS_ARBOL.has(tipo) or TIPOS_ESTRUCTURA.has(tipo):
		return false
	return not celda_a_edificio.has(celda)


## true si la celda de despeje "celda" impide colocar el edificio: está
## ocupada, SALVO que sea terreno natural por ENCIMA del nivel de una columna
## que se va a nivelar ("terreno_a_nivelar": columna Vector2i -> nivel G, la
## fachada de un blueprint) — ese terreno se cava al construir, así que no
## bloquea. Árboles, estructuras y otros edificios siempre bloquean. Usada por
## verificar_despejes() y por el overlay de celdas reservadas.
func despeje_bloqueado(celda: Vector3i, terreno_a_nivelar: Dictionary = {}) -> bool:
	if obtener_tipo(celda) == "":
		return false
	var columna := Vector2i(celda.x, celda.z)
	if terreno_a_nivelar.has(columna) and celda.y > terreno_a_nivelar[columna] and es_terreno_natural(celda):
		return false
	return true


## Valida si "celdas_mundo" (las celdas estructurales de un edificio a
## punto de colocarse, mismo formato que calcular_despeje()) respeta la
## regla de despeje: (a) ninguna de sus propias celdas de despeje puede
## estar bloqueada (ver despeje_bloqueado(): cualquier bloque real tiene un
## tipo no vacío, salvo el terreno natural que se va a nivelar), y (b)
## ninguna de sus celdas ESTRUCTURALES puede caer dentro del despeje YA
## RESERVADO de otro edificio (celda_a_despeje). El despeje del edificio nuevo
## NUNCA se compara contra el despeje ajeno — dos despejes distintos pueden
## solaparse libremente (puertas enfrentadas, ventana sobre despeje de
## puerta ajena, etc.), ver spec punto de diseño. "terreno_a_nivelar"
## omitido = comportamiento anterior (lo usa Player._declarar_edificio()).
func verificar_despejes(celdas_mundo: Dictionary, terreno_a_nivelar: Dictionary = {}) -> bool:
	for celda in celdas_mundo:
		if celda_a_despeje.has(celda):
			return false
	for celda_despeje in calcular_despeje(celdas_mundo):
		if despeje_bloqueado(celda_despeje, terreno_a_nivelar):
			return false
	return true
```

- [ ] **Step 4: Correr `Test.tscn` y verificar que pasa**

Run: `res://scenes/Test.tscn`.
Expected: PASS — "=== Las 56 pruebas de BlueprintValidator pasaron correctamente ===" (TEST 28-34 de despeje, que llaman `verificar_despejes` sin el argumento nuevo, siguen pasando).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: el despeje acepta terreno natural sobre el nivel en las columnas a nivelar" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 3: CamaraCenital — evaluación única, plan de nivelación y fachada en el clic

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd` (constantes ~194; helpers tras `_material_excavado` ~886; `_actualizar_resumen_materiales` ~895; `_actualizar_previsualizacion_blueprint` ~921; `_procesar_clic_blueprint` ~1440)

**Interfaces:**
- Consumes: Task 1 (`calcular_base_y` con `"fachada"`, `calcular_nivelacion_fachada`), Task 2 (`verificar_despejes(celdas, fachada)`), y lo ya existente (`_base_y_blueprint`, `_celdas_excavacion`, `_material_excavado`, `_huella_en_zona_correcta`, `_huella_choca_con_otro_puesto`, `_huella_tiene_columna_en_tierra`, `_altura_blueprint`, `MENSAJES_BASE_Y`, `SIN_RESUMEN`).
- Produces (usados por la Task 4):
  - `_evaluar_blueprint(esquina: Vector2i) -> Dictionary` con las claves `"columnas"`, `"resultado_base"`, `"fachada"`, `"columnas_fachada"`, `"columnas_union"`, `"celdas_mundo"`, `"zona_correcta"`, `"relieve_valido"`, `"resultado_huella"`, `"resultado_fachada"`, `"choca"`, `"en_tierra"`, `"despejes_ok"`.
  - `_mensaje_rechazo_blueprint(ev: Dictionary) -> String` (vacío = válida).
  - `_plan_nivelacion(esquina, columnas, base_y, fachada) -> Dictionary` → `{"excavacion": Array[Vector3i], "relleno": Dictionary}`.

`CamaraCenital` no tiene pruebas automáticas (depende de cámara, ratón y escena): la verificación es arranque de `Main.tscn` sin errores + regresión de las escenas de pruebas + comprobación manual (Step 6). Localiza el código por contenido; los números de línea son aproximados.

- [ ] **Step 1: Constante y helpers**

Junto a `const MENSAJES_BASE_Y := {` agrega:

```gdscript
## Altura en bloques del despeje de una puerta: hasta dónde se revisa que el
## frente (la fachada) esté libre de árboles y estructuras.
const ALTURA_PUERTA := 2
```

Tras `_material_excavado()` agrega:

```gdscript
## "columnas_mundo" (Vector2i mundiales) como offsets relativos a "esquina" —
## el mismo formato que "columnas" de la huella.
func _columnas_relativas(esquina: Vector2i, columnas_mundo: Array) -> Array[Vector2i]:
	var relativas: Array[Vector2i] = []
	for columna: Vector2i in columnas_mundo:
		relativas.append(columna - esquina)
	return relativas


## Celdas mundiales del blueprint activo colocado en "esquina" con su celda
## rel.y=0 en "base_y" (Vector3i real -> tipo).
func _celdas_mundo_blueprint(esquina: Vector2i, base_y: int) -> Dictionary:
	var celdas_mundo: Dictionary = {}
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, base_y + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]
	return celdas_mundo


## Todo lo que hay que cavar y rellenar para emplazar el blueprint: la huella
## (hasta `base_y - 1`) más la fachada (cada columna a su nivel). Fuente ÚNICA
## del clic, el resumen de materiales y los overlays. "excavacion" son celdas
## de terreno REAL (sin las ya vacías), huella primero; "relleno" es columna
## mundial -> cantidad de bloques.
func _plan_nivelacion(esquina: Vector2i, columnas: Array[Vector2i], base_y: int, fachada: Dictionary) -> Dictionary:
	var excavacion: Array[Vector3i] = _celdas_excavacion(esquina, columnas, base_y)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno_hasta(esquina, columnas, base_y - 1)
	var nivelacion_fachada: Dictionary = nivelador_puesto.calcular_nivelacion_fachada(fachada)
	for celda: Vector3i in nivelacion_fachada["excavacion"]:
		if mundo.get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
			excavacion.append(celda)
	relleno.merge(nivelacion_fachada["relleno"])
	return {"excavacion": excavacion, "relleno": relleno}


## Evalúa TODAS las condiciones para emplazar el blueprint activo en
## "esquina" sin tocar el mundo: fuente única de la previsualización y del
## clic (ver _mensaje_rechazo_blueprint()). "columnas_union" es la huella más
## la fachada (lo que se nivela), como offsets relativos a "esquina".
func _evaluar_blueprint(esquina: Vector2i) -> Dictionary:
	var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]
	var resultado_base: Dictionary = _base_y_blueprint(esquina)
	var fachada: Dictionary = resultado_base["fachada"]
	var columnas_fachada: Array[Vector2i] = _columnas_relativas(esquina, fachada.keys())
	var columnas_union: Array[Vector2i] = []
	columnas_union.append_array(columnas)
	columnas_union.append_array(columnas_fachada)
	var celdas_mundo: Dictionary = _celdas_mundo_blueprint(esquina, resultado_base["base_y"])
	return {
		"columnas": columnas,
		"resultado_base": resultado_base,
		"fachada": fachada,
		"columnas_fachada": columnas_fachada,
		"columnas_union": columnas_union,
		"celdas_mundo": celdas_mundo,
		"zona_correcta": _huella_en_zona_correcta(esquina, columnas, _blueprint_activo["zona_permitida"]),
		"relieve_valido": nivelador_puesto.verificar_pendiente(esquina, columnas_union),
		"resultado_huella": mundo.verificar_huella_libre(esquina, columnas, _altura_blueprint(_blueprint_activo)),
		"resultado_fachada": mundo.verificar_huella_libre(esquina, columnas_fachada, ALTURA_PUERTA),
		"choca": _huella_choca_con_otro_puesto(esquina, columnas_union),
		"en_tierra": _huella_tiene_columna_en_tierra(esquina, columnas),
		"despejes_ok": mundo.verificar_despejes(celdas_mundo, fachada),
	}


## Motivo de rechazo de una evaluación (_evaluar_blueprint()), en el mismo
## orden en que se validaba al hacer clic; "" si es válida. La previsualización
## considera válida exactamente lo que el clic aceptaría.
func _mensaje_rechazo_blueprint(ev: Dictionary) -> String:
	if not ev["zona_correcta"]:
		return "Colocación rechazada: esta zona no acepta este blueprint."
	if not ev["relieve_valido"]:
		return "Colocación rechazada: la pendiente de esta huella (o del frente de sus puertas) supera el límite permitido."
	if not ev["resultado_huella"]["valida"]:
		return "Colocación rechazada: la huella choca con un recurso de madera o una estructura existente."
	if not ev["resultado_fachada"]["valida"]:
		return "Colocación rechazada: el frente de una puerta choca con un recurso de madera o una estructura existente."
	if ev["choca"]:
		return "Colocación rechazada: la huella (o el frente de una puerta) choca con un puesto o construcción ya colocada."
	if not ev["en_tierra"]:
		return "Colocación rechazada: la huella necesita al menos una columna sobre tierra firme."
	if not ev["resultado_base"]["valido"]:
		return MENSAJES_BASE_Y[ev["resultado_base"]["motivo"]]
	if not ev["despejes_ok"]:
		return "Colocación rechazada: una ventana o puerta quedaría sin el despeje mínimo, o invade el despeje de otro edificio."
	return ""
```

- [ ] **Step 2: Resumen de materiales con la fachada**

Reemplaza `_actualizar_resumen_materiales()` completa (comentario incluido) por:

```gdscript
## Actualiza la ficha de materiales del HUD para el blueprint activo en
## "esquina" (evaluación "ev" de _evaluar_blueprint()). Se recalcula solo si
## cambió la esquina (o se invalidó, ver SIN_RESUMEN). Si la colocación no es
## válida muestra "-". Cuenta la nivelación de la huella Y de la fachada.
## ponytail: sobre una huella con agua, la previsualización cuenta la
## excavación con el fondo real y no con la tierra que dejará el drenado
## (que ocurre al confirmar); la diferencia solo afecta al número mostrado.
func _actualizar_resumen_materiales(esquina: Vector2i, ev: Dictionary, valida: bool) -> void:
	var clave: Vector2i = esquina if valida else SIN_RESUMEN
	if clave == _resumen_blueprint_vigente:
		return
	_resumen_blueprint_vigente = clave
	if not valida:
		hud.actualizar_materiales({})
		return
	var plan: Dictionary = _plan_nivelacion(esquina, ev["columnas"], ev["resultado_base"]["base_y"], ev["fachada"])
	var total_relleno := 0
	for cantidad in plan["relleno"].values():
		total_relleno += cantidad
	var recogido: Dictionary = _material_excavado(plan["excavacion"])
	hud.actualizar_materiales(nivelador_puesto.resumen_materiales(_blueprint_activo["celdas_3d"], total_relleno, recogido))
```

- [ ] **Step 3: Previsualización sobre la evaluación única**

En `_actualizar_previsualizacion_blueprint()`, reemplaza desde `var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]` hasta el final de la función (incluido `_actualizar_resumen_materiales(esquina, columnas, base_y, valida)`) por:

```gdscript
	var ev: Dictionary = _evaluar_blueprint(esquina)
	var valida: bool = _mensaje_rechazo_blueprint(ev) == ""
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var base_y: int = ev["resultado_base"]["base_y"]
	for i in range(_offsets_huella_blueprint.size()):
		var rel: Vector3i = _offsets_huella_blueprint[i]
		var x: int = esquina.x + rel.x
		var y: int = base_y + rel.y
		var z: int = esquina.y + rel.z
		var caja: MeshInstance3D = _huella_blueprint[i]
		var material: StandardMaterial3D = caja.material_override
		# Puertas y ventanas se destacan solo si la colocación es válida; si
		# no, siguen en rojo para no perder el aviso de rechazo.
		var tipo_celda: String = _blueprint_activo["celdas_3d"][rel]
		material.albedo_color = mundo.COLOR_DESTACADO.get(tipo_celda, color) if valida else color
		caja.position = Vector3(x + DESF, y + DESF, z + DESF)
	_actualizar_resumen_materiales(esquina, ev, valida)
```

(Las líneas previas de la función — `var centro := …`, `var ancho …`, `var alto …`, `var esquina := …` — se conservan; solo se reemplaza lo que sigue a `var esquina`. Elimina la línea `var columnas …` de la función porque ya no se usa aquí.) Actualiza el comentario de la función: donde dice "(mismo cálculo que _procesar_clic_blueprint(): esquina + rel, en `base_y` — …)" agrega al final "La validez es exactamente la del clic (`_mensaje_rechazo_blueprint()`), incluidos los despejes y el frente nivelado".

- [ ] **Step 4: Clic de emplazamiento con la fachada**

Reemplaza la función `_procesar_clic_blueprint()` completa (y su comentario `##` superior) por:

```gdscript
## Confirma la colocación del blueprint activo en la celda bajo el cursor
## si _evaluar_blueprint() la acepta (zona, relieve sobre huella + fachada,
## huella y frente libres, sin choque, esquina en tierra firme, nivel base
## `base_y` válido para las puertas y despejes de ventanas/puertas) — si no,
## imprime el motivo (_mensaje_rechazo_blueprint()) y PERMANECE en modo
## colocar-blueprint. A diferencia de _procesar_clic_puesto() (que coloca el
## marcador de inmediato), esto NO completa nada: drena el agua bajo la huella
## y la fachada, calcula el nivel base (`base_y`, puerta a ras del suelo
## frontal) y la nivelación (_plan_nivelacion(): huella + fachada, excavación
## y relleno), reubica blueprint["celdas_3d"] en el mundo e inicia UNA cola
## de preparación del terreno (excavación primero, luego relleno;
## Construccion.gd, vía VoxelWorld.iniciar_construccion_fantasma()) más el
## orden de la estructura del edificio (VoxelWorld.edificio_orden, ver
## VoxelWorld.ordenar_celdas_edificio()) — la finalización real ocurre
## después, celda por celda, cuando el jugador la surte (ver
## Player._minar()/_completar_construccion()); la estructura solo avanza
## cuando la cola de preparación se agota.
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	var ev: Dictionary = _evaluar_blueprint(esquina)
	var mensaje: String = _mensaje_rechazo_blueprint(ev)
	if mensaje != "":
		print(mensaje)
		return
	var columnas: Array[Vector2i] = ev["columnas"]
	var fachada: Dictionary = ev["fachada"]
	var base_y: int = ev["resultado_base"]["base_y"]
	var celdas_mundo: Dictionary = ev["celdas_mundo"]

	for celda_follaje in ev["resultado_huella"]["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)
	for celda_follaje in ev["resultado_fachada"]["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for rel in ev["columnas_union"]:
		total_drenado += mundo.drenar_agua(esquina.x + rel.x, esquina.y + rel.y)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

	# Cola de "preparación del terreno" (ver VoxelWorld._aplicar_paso_cola()):
	# primero se CAVA (terreno real sobre la losa y sobre el nivel de la
	# fachada), luego se RELLENA (columnas por debajo). Una celda cavada que
	# además es de la estructura (la losa enterrada) queda "fantasma", no vacía.
	var plan: Dictionary = _plan_nivelacion(esquina, columnas, base_y, fachada)
	var excavacion: Array[Vector3i] = plan["excavacion"]
	var relleno: Dictionary = plan["relleno"]
	var relleno_orden: Array[Vector3i] = []
	var tipos_relleno: Dictionary = {}
	for celda_e in excavacion:
		relleno_orden.append(celda_e)
		tipos_relleno[celda_e] = "fantasma" if celdas_mundo.has(celda_e) else "aire"
	var total_relleno := 0
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		total_relleno += cantidad
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			var celda_r := Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y)
			relleno_orden.append(celda_r)
			tipos_relleno[celda_r] = "tierra"

	var orden_estructura: Array = mundo.ordenar_celdas_edificio(celdas_mundo)

	var huella_xz: Array = []
	var vistos_xz: Dictionary = {}
	for celda in celdas_mundo:
		var xz := Vector2i(celda.x, celda.z)
		if not vistos_xz.has(xz):
			vistos_xz[xz] = true
			huella_xz.append(xz)

	var metadata := {
		"blueprint": _blueprint_activo,
		"huella_xz": huella_xz,
		"esquina": esquina,
		"ancho": ancho,
		"profundidad": alto,
		"base_y": base_y,
		"fachada": fachada,
	}
	var id_edificio: int = mundo.iniciar_construccion_fantasma(relleno_orden, tipos_relleno, orden_estructura, celdas_mundo, metadata)
	metadata["id_edificio"] = id_edificio
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — excavación: ", excavacion.size(), " bloques, relleno: ", total_relleno, " (huella + frente de las puertas) — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()
```

- [ ] **Step 5: Verificar arranque y regresión**

Run: `res://scenes/Main.tscn` un instante: `get_debug_output` sin errores de script en `CamaraCenital.gd` (solo los avisos preexistentes); `stop_project` y comprobar procesos.
Run: `res://scenes/NiveladorTerrenoTest.tscn` (20 pruebas) y `res://scenes/Test.tscn` (56 pruebas) — deben seguir pasando.

- [ ] **Step 6: Verificación manual (la hace el usuario, se lista en el reporte)**

En `Main.tscn`: declarar un edificio, cenital (`C`), `B`. Sobre plano y sobre ladera: la ficha de materiales incluye la excavación/relleno del frente; la previsualización se marca inválida cuando hay un árbol en el frente o las puertas piden niveles distintos; al confirmar la consola imprime "(huella + frente de las puertas)" y, al surtir con clic derecho, el terreno delante de todo el lado de la puerta queda plano y a ras de la puerta.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: nivelar la fachada del edificio al emplazar (evaluación y plan de nivelación únicos)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 4: Overlays de previsualización (`NivelacionOverlay`)

**Files:**
- Create: `godot/scripts/NivelacionOverlay.gd`
- Modify: `godot/scripts/CamaraCenital.gd` (preload y variable cerca de las constantes; `_ready()` ~223; nueva `_actualizar_overlays`; llamada en `_actualizar_previsualizacion_blueprint`; `_rotar_blueprint`, `_alternar_modo_colocar_blueprint`, `_salir_de_modo_colocar_blueprint`)

**Interfaces:**
- Consumes: Task 3 (`_evaluar_blueprint`, `_plan_nivelacion`, claves de `ev`), `VoxelWorld.calcular_despeje()`, `VoxelWorld.despeje_bloqueado()` (Task 2).
- Produces: `NivelacionOverlay.mostrar(reservadas: Array, region: Array)` y `ocultar()`.
  - `reservadas`: Array de `{"celda": Vector3i, "bloqueada": bool}`.
  - `region`: Array de `{"columna": Vector2i, "y": int, "accion": String}` con `accion` ∈ `"cavar"`, `"rellenar"`, `"nivel"`; `y` es la Y del bloque superior actual de la columna.

El dibujo no tiene prueba automática (depende del render); la lógica de datos ya está cubierta en las tareas 1-2.

- [ ] **Step 1: Crear `godot/scripts/NivelacionOverlay.gd`**

Antes de escribirlo, lee `godot/scripts/ZonaOverlay.gd` y fíjate a qué altura dibuja sus planos de zona; `ALTURA_PLANO` debe quedar unos 0.01 por encima de esa altura (y de `CamaraCenital.ALTURA_SOBRE_SUPERFICIE = 1.01` para los planos de puesto) para que la región nivelada no compita (z-fighting) con las zonas pintadas. Si `ZonaOverlay` usa exactamente 1.01, usa `1.02`.

```gdscript
extends Node3D

## Overlays de la previsualización del blueprint (ver
## docs/superpowers/specs/2026-09-20-nivelacion-frente-y-overlays-design.md):
## (1) las celdas RESERVADAS delante de puertas y ventanas — cajas cian, y
## rojas las bloqueadas por un árbol, una estructura u otro edificio; (2) la
## región NIVELADA — un plano por columna a ras del terreno actual, naranja
## donde se cava, azul donde se rellena y verde tenue donde ya está a nivel.
## Solo visual: CamaraCenital.gd calcula los datos y llama a mostrar()/
## ocultar(); este nodo no conoce el mundo.

## Mismo desfase que CamaraCenital.gd: una celda "celda" ocupa
## [celda, celda+1] en cada eje, así que su centro real está en celda + DESF.
const DESF := 0.5

## Altura de los planos sobre la Y del bloque superior de la columna: un poco
## por encima de los planos de puesto (1.01) y de las zonas pintadas.
const ALTURA_PLANO := 1.02

## Un poco menor que la celda para que la caja no compita con las caras del
## terreno que la rodea.
const TAMANO_CAJA := 0.96

const COLOR_RESERVADA := Color(0.2, 0.9, 1.0, 0.35)
const COLOR_BLOQUEADA := Color(1.0, 0.2, 0.2, 0.5)
const COLOR_REGION := {
	"cavar": Color(1.0, 0.5, 0.1, 0.35),
	"rellenar": Color(0.2, 0.5, 1.0, 0.35),
	"nivel": Color(0.3, 1.0, 0.4, 0.25),
}

var _nodos: Array[MeshInstance3D] = []
var _malla_caja := BoxMesh.new()
var _malla_plano := PlaneMesh.new()


func _init() -> void:
	_malla_caja.size = Vector3.ONE * TAMANO_CAJA
	_malla_plano.size = Vector2(1.0, 1.0)


## "reservadas": Array de {"celda": Vector3i, "bloqueada": bool}. "region":
## Array de {"columna": Vector2i, "y": int, "accion": String}. Reemplaza lo que
## hubiera dibujado antes.
func mostrar(reservadas: Array, region: Array) -> void:
	ocultar()
	for r: Dictionary in reservadas:
		var celda: Vector3i = r["celda"]
		var color: Color = COLOR_BLOQUEADA if r["bloqueada"] else COLOR_RESERVADA
		_agregar(_malla_caja, color, Vector3(celda) + Vector3(DESF, DESF, DESF))
	for p: Dictionary in region:
		var columna: Vector2i = p["columna"]
		_agregar(_malla_plano, COLOR_REGION[p["accion"]], Vector3(columna.x + DESF, p["y"] + ALTURA_PLANO, columna.y + DESF))


func ocultar() -> void:
	for nodo in _nodos:
		nodo.queue_free()
	_nodos.clear()


## Un puñado de nodos por actualización (y solo cuando cambia la esquina), así
## que se recrean todos en vez de mantener un pool.
func _agregar(malla: Mesh, color: Color, posicion: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.material_override = material
	nodo.top_level = true
	nodo.position = posicion
	add_child(nodo)
	_nodos.append(nodo)
```

- [ ] **Step 2: Alimentar el overlay desde CamaraCenital**

(a) Junto al preload de `NiveladorTerreno` (o, si no hay un bloque de preloads, justo antes de `const SIN_RESUMEN`) agrega:

```gdscript
const NivelacionOverlay = preload("res://scripts/NivelacionOverlay.gd")
```

(b) Junto a `var _resumen_blueprint_vigente: Vector2i = SIN_RESUMEN` agrega:

```gdscript
## Última esquina para la que se dibujaron los overlays de nivelación (mismo
## criterio que _resumen_blueprint_vigente).
var _overlay_vigente: Vector2i = SIN_RESUMEN
var _overlay_nivelacion: Node3D
```

(c) En `_ready()`, tras `_crear_area_accion()` agrega:

```gdscript
	_overlay_nivelacion = NivelacionOverlay.new()
	add_child(_overlay_nivelacion)
```

(d) Tras `_actualizar_resumen_materiales()` agrega:

```gdscript
## Dibuja los overlays del blueprint activo en "esquina" (evaluación "ev" de
## _evaluar_blueprint()): las celdas reservadas delante de puertas y ventanas
## (rojas si están bloqueadas, ver VoxelWorld.despeje_bloqueado()) y la región
## nivelada (huella + fachada, por acción). Se recalcula solo si cambió la
## esquina (o se invalidó al rotar/entrar al modo), y también cuando la
## colocación es inválida, para ver qué la bloquea.
func _actualizar_overlays(esquina: Vector2i, ev: Dictionary) -> void:
	if esquina == _overlay_vigente:
		return
	_overlay_vigente = esquina
	var fachada: Dictionary = ev["fachada"]
	var plan: Dictionary = _plan_nivelacion(esquina, ev["columnas"], ev["resultado_base"]["base_y"], fachada)
	var cava: Dictionary = {}  # columna mundial -> true
	for celda: Vector3i in plan["excavacion"]:
		cava[Vector2i(celda.x, celda.z)] = true
	var region: Array = []
	for rel: Vector2i in ev["columnas_union"]:
		var columna: Vector2i = esquina + rel
		var accion := "nivel"
		if cava.has(columna):
			accion = "cavar"
		elif plan["relleno"].has(columna):
			accion = "rellenar"
		region.append({"columna": columna, "y": mundo.altura_en(columna.x, columna.y, true), "accion": accion})
	var reservadas: Array = []
	for celda: Vector3i in mundo.calcular_despeje(ev["celdas_mundo"]):
		reservadas.append({"celda": celda, "bloqueada": mundo.despeje_bloqueado(celda, fachada)})
	_overlay_nivelacion.mostrar(reservadas, region)
```

(e) En `_actualizar_previsualizacion_blueprint()`, tras `_actualizar_resumen_materiales(esquina, ev, valida)` agrega:

```gdscript
	_actualizar_overlays(esquina, ev)
```

(f) En `_rotar_blueprint()`, junto a `_resumen_blueprint_vigente = SIN_RESUMEN` agrega `_overlay_vigente = SIN_RESUMEN`. En `_alternar_modo_colocar_blueprint()`, junto a `_resumen_blueprint_vigente = SIN_RESUMEN` (justo tras `modo_colocar_blueprint = true`) agrega `_overlay_vigente = SIN_RESUMEN`. En `_salir_de_modo_colocar_blueprint()`, tras `hud.ocultar_ficha_materiales()` agrega:

```gdscript
	_overlay_nivelacion.ocultar()
	_overlay_vigente = SIN_RESUMEN
```

- [ ] **Step 3: Verificar arranque**

Run: `res://scenes/Main.tscn` un instante: `get_debug_output` sin errores de script en `CamaraCenital.gd` ni `NivelacionOverlay.gd` (solo los avisos preexistentes); `stop_project` y comprobar procesos. Re-correr `NiveladorTerrenoTest.tscn` (20) y `Test.tscn` (56).

- [ ] **Step 4: Verificación manual (la hace el usuario, se lista en el reporte)**

`B` en cenital, mover el cursor: cajas cian en las celdas reservadas de puertas y ventanas (rojas las que tengan un árbol o estructura); planos de región naranja donde se cava, azul donde se rellena, verde donde ya está a nivel, cubriendo la huella y la franja delante del lado de la puerta; los overlays siguen al cursor y a la rotación (Ctrl+rueda); desaparecen al salir del modo o al colocar; no parpadean contra las zonas pintadas.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/NivelacionOverlay.gd godot/scripts/CamaraCenital.gd
git commit -m "feat: overlays de celdas reservadas y región nivelada en la previsualización del blueprint" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 5: Documentación y verificación final

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (§5, viñeta "Nivel de Puerta y Excavación")
- Modify: `PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md` (subsección "Puertas a nivel de suelo (2026-09-20)")

- [ ] **Step 1: GDD §5**

Lee la sección (CLAUDE.md lo exige) y usa Glob para el nombre exacto del archivo. Al final de la viñeta `> * **Nivel de Puerta y Excavación:** …` (que termina en "…respeta el límite de pendiente.") agrega, en la misma viñeta y respetando el estilo y los saltos de línea del archivo:

```
 También se nivela la **fachada**: las 2 columnas delante de todo el lado del edificio donde hay puerta se llevan al mismo nivel que el suelo frontal de la puerta (se cavan y rellenan igual que la huella, como trabajo pendiente), para que la carretera se conecte sobre terreno plano. Al colocar, la previsualización dibuja las celdas reservadas delante de puertas y ventanas y la región que será nivelada (qué se cava y qué se rellena).
```

- [ ] **Step 2: Doc técnico de PoC 6**

Lee la subsección "Puertas a nivel de suelo (2026-09-20)" y los párrafos que le siguieron (destacado de puertas/ventanas). Agrega un párrafo, con el estilo y los saltos de línea del archivo (conserva los finales de línea CRLF si los tiene):

```
Nivelación del frente y overlays (2026-09-20): `NiveladorTerreno.calcular_base_y()` devuelve además la fachada (las 2 columnas delante de todo el lado del edificio con puerta, columna → nivel G del suelo frontal) y `calcular_nivelacion_fachada()` calcula su excavación y relleno; entran en la misma cola de preparación (`CamaraCenital._plan_nivelacion()`, fuente única del clic, el resumen de materiales y los overlays). `VoxelWorld.verificar_despejes(celdas, terreno_a_nivelar)` acepta terreno natural sobre G en esas columnas (se va a cavar); árboles, estructuras y otros edificios siguen bloqueando. La previsualización valida exactamente lo que el clic acepta (`_evaluar_blueprint()`/`_mensaje_rechazo_blueprint()`) y `NivelacionOverlay` dibuja las celdas reservadas (cian; rojas si están bloqueadas) y la región nivelada (naranja = cavar, azul = rellenar, verde = ya a nivel). Sin tope global de profundidad de excavación; el frente de las ventanas no se nivela. Spec: `docs/superpowers/specs/2026-09-20-nivelacion-frente-y-overlays-design.md`.
```

- [ ] **Step 3: Verificación final**

Run: `res://scenes/NiveladorTerrenoTest.tscn` (esperado "Las 20 pruebas de NiveladorTerreno pasaron correctamente"), `res://scenes/Test.tscn` ("Las 56 pruebas de BlueprintValidator pasaron correctamente"), `res://scenes/RecoleccionTest.tscn` (debe pasar) y `res://scenes/Main.tscn` sin errores nuevos. Comprobar procesos Godot.

- [ ] **Step 4: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: nivelación del frente y overlays (GDD §5 y PoC 6)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```
