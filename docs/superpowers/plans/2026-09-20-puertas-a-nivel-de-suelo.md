# Puertas a Nivel de Suelo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que la puerta de todo edificio emplazado por blueprint quede a nivel del suelo natural delante de ella (losa enterrada un bloque), con la excavación y el relleno como trabajo pendiente del jugador y un resumen visual de materiales en el HUD.

**Architecture:** La lógica de niveles/excavación/relleno/materiales es pura y vive en `NiveladorTerreno.gd` (mismo patrón de generadores falsos en las pruebas). `VoxelWorld` gana un helper `_retirar_bloque()` y un aplicador de pasos de cola que entiende "aire"/"fantasma"; la excavación y el relleno viajan en **una sola cola de preparación** de `Construccion.gd` (excavación primero, relleno después), por lo que `iniciar_construccion_fantasma()` no cambia. `CamaraCenital` calcula un único `base_y` para clic y previsualización, y el HUD muestra la ficha "Materiales de construcción" (solo visual).

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), proyecto en `godot/`. Pruebas: escenas `*Test.tscn` con `assert()`.

**Spec:** `docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md` (una desviación deliberada: cola única de preparación en vez de `edificio_excavacion_cola`; se sincroniza en la Task 2).

## Global Constraints

- Godot 4.7; en GDScript se usan **tabulaciones**.
- Conservar el español en documentación, mensajes del juego y pruebas.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- Cambios pequeños; no reformatear archivos ajenos al objetivo. Los puestos periféricos NO cambian (siguen con `altura_objetivo()`).
- `LIMITE_PENDIENTE = 2` se reutiliza para puerta-frente.
- Es solo visual: no existe inventario real; no se cobra ni se consume nada.
- Rama de trabajo: `feat/puertas-a-nivel-de-suelo` (ya creada; se fusiona a `main` al terminar). No agregar al commit los archivos sin versionar del usuario (`docs/Recursos.xlsx`, `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md`, `*.gd.uid`, cambios en el doc de PoC 5).
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6
  ```
- Cómo correr una escena de pruebas (el proyecto usa el MCP de Godot, no CLI headless): `mcp__godot__run_project` con `projectPath = C:\Users\peraz\Projects\Misc\CityCraft\godot` y la escena indicada, leer `mcp__godot__get_debug_output`, luego `mcp__godot__stop_project` y confirmar con `Get-Process | Where-Object { $_.ProcessName -like "*godot*" }` (eliminar huérfanos con `Stop-Process -Id <id> -Force`). Éxito = línea final "pasaron correctamente" y ningún `ERROR`/"Assertion failed".

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `godot/scripts/NiveladorTerreno.gd` (modificar) | `calcular_base_y`, `calcular_excavacion`, `calcular_relleno_hasta`, `resumen_materiales`, `COSTO_POR_CELDA` |
| `godot/scripts/NiveladorTerrenoTest.gd` (modificar) | pruebas 9-15 de lo anterior y del texto del HUD |
| `godot/scripts/VoxelWorld.gd` (modificar) | `_retirar_bloque()`, `_aplicar_paso_cola()`, `surtir_construccion()` los usa |
| `godot/scripts/BlueprintValidatorTest.gd` (modificar) | TEST 48: cola de preparación cava y luego rellena |
| `godot/scripts/HUD.gd` + `godot/scenes/Main.tscn` (modificar) | ficha `MaterialesFicha` y `texto_materiales()` |
| `godot/scripts/CamaraCenital.gd` (modificar) | helper único de `base_y`, clic, previsualización, ficha |
| GDD §5, doc técnico PoC 6, spec | documentación |

---

### Task 1: Lógica pura de nivel base, excavación, relleno y materiales

**Files:**
- Modify: `godot/scripts/NiveladorTerreno.gd`
- Test: `godot/scripts/NiveladorTerrenoTest.gd`

**Interfaces:**
- Consumes: `_generador.altura_en(x, z) -> int` (ya existente por duck typing).
- Produces:
  - `calcular_base_y(esquina: Vector2i, celdas_3d: Dictionary) -> Dictionary` → `{"valido": bool, "base_y": int, "motivo": String, "frentes": Array[Vector2i]}`. `celdas_3d` es `Vector3i relativo -> tipo` (ya rotado, con `y=0` = losa). `motivo` ∈ `""`, `"pendiente"`, `"puertas"`. `base_y` es la Y mundial de la celda `rel.y=0`; en resultados inválidos vale el respaldo `altura_objetivo() + 1`.
  - `calcular_excavacion(esquina: Vector2i, columnas: Array[Vector2i], base_y: int) -> Array[Vector3i]` (celdas mundiales, de arriba hacia abajo).
  - `calcular_relleno_hasta(esquina: Vector2i, columnas: Array[Vector2i], tope: int) -> Dictionary` (`Vector2i(x,z)` mundial → cantidad); `calcular_relleno()` pasa a delegar en él.
  - `resumen_materiales(celdas_3d: Dictionary, relleno_total: int, recogido: Dictionary) -> Dictionary` (material → int neto; negativo = necesario, positivo = sobrante; sin ceros).

- [ ] **Step 1: Escribir las pruebas que fallan**

En `godot/scripts/NiveladorTerrenoTest.gd`, agrega tras `GeneradorConAcantilado` (línea ~48):

```gdscript
## Generador falso: la altura crece 1 por cada paso en X y es constante en Z
## (para probar puertas en lados opuestos con suelos frontales distintos).
class GeneradorRampaX:
	func altura_en(x: int, _z: int) -> int:
		return x
```

Agrega tras `_rectangulo()`:

```gdscript
## Casa de prueba 4x5x5 (ver spec 2026-09-20): losas de piso (y=0) y techo
## (y=4) de "pared", muro perimetral en y=1..3 con una puerta en x=0 (z=2,
## y=1..2) y una ventana en x=3 (z=2, y=2), cama y baúl adentro. Con
## "puerta_extra_derecha" la ventana se reemplaza por una segunda puerta en
## x=3.
func _casa_4x5(puerta_extra_derecha: bool = false) -> Dictionary:
	var celdas: Dictionary = {}
	for x in range(4):
		for z in range(5):
			celdas[Vector3i(x, 0, z)] = "pared"
			celdas[Vector3i(x, 4, z)] = "pared"
			if x == 0 or x == 3 or z == 0 or z == 4:
				for y in range(1, 4):
					celdas[Vector3i(x, y, z)] = "pared"
	celdas[Vector3i(0, 1, 2)] = "puerta_inferior"
	celdas[Vector3i(0, 2, 2)] = "puerta_superior"
	celdas[Vector3i(3, 2, 2)] = "ventana"
	celdas[Vector3i(1, 1, 1)] = "cama_cabecera"
	celdas[Vector3i(1, 1, 2)] = "cama_pies"
	celdas[Vector3i(2, 1, 3)] = "baul"
	if puerta_extra_derecha:
		celdas[Vector3i(3, 1, 2)] = "puerta_inferior"
		celdas[Vector3i(3, 2, 2)] = "puerta_superior"
	return celdas
```

Reemplaza la última línea de `ejecutar_pruebas()` (`print("\n=== Las 8 pruebas de NiveladorTerreno pasaron correctamente ===")`) por las pruebas nuevas seguidas de la línea final actualizada:

```gdscript
	print("\n=== TEST 9: calcular_base_y() en terreno plano entierra la losa (la puerta queda a nivel del suelo frontal) ===")
	var casa_9: Dictionary = _casa_4x5()
	var base_9: Dictionary = nivelador_plano.calcular_base_y(Vector2i(10, 10), casa_9)
	assert(base_9["valido"])
	assert(base_9["base_y"] == 5, "suelo 5 + 1 - puerta en y=1 = 5: la losa ocupa la Y del suelo, enterrada un bloque (antes quedaba en 6)")
	var excavacion_9: Array[Vector3i] = nivelador_plano.calcular_excavacion(Vector2i(10, 10), _rectangulo(4, 5), 5)
	assert(excavacion_9.size() == 20, "una capa de 20 bloques bajo la huella")
	for celda_9 in excavacion_9:
		assert(celda_9.y == 5)
	assert(nivelador_plano.calcular_relleno_hasta(Vector2i(10, 10), _rectangulo(4, 5), 4).is_empty())

	print("\n=== TEST 10: en una ladera el nivel lo da el suelo frente a la puerta; se cava arriba y se rellena abajo ===")
	# altura_en(x,z) = z. Puerta en (10,12), frente en (9,12), suelo 12 -> base_y 12.
	var base_10: Dictionary = nivelador_suave.calcular_base_y(Vector2i(10, 10), casa_9)
	assert(base_10["valido"] and base_10["base_y"] == 12)
	var excavacion_10: Array[Vector3i] = nivelador_suave.calcular_excavacion(Vector2i(10, 10), _rectangulo(4, 5), 12)
	# Filas z=12,13,14 (alturas 12,13,14) aportan 1+2+3 = 6 celdas por columna X, x4 columnas.
	assert(excavacion_10.size() == 24)
	assert(excavacion_10[0].y == 14 and excavacion_10[excavacion_10.size() - 1].y == 12)
	for i_10 in range(1, excavacion_10.size()):
		assert(excavacion_10[i_10 - 1].y >= excavacion_10[i_10].y, "orden de arriba hacia abajo")
	# Relleno hasta base_y - 1 = 11: solo la fila z=10 (altura 10) necesita 1 bloque por columna.
	var relleno_10: Dictionary = nivelador_suave.calcular_relleno_hasta(Vector2i(10, 10), _rectangulo(4, 5), 11)
	assert(relleno_10.size() == 4)
	assert(relleno_10[Vector2i(10, 10)] == 1)

	print("\n=== TEST 11: puertas en lados con suelos frontales distintos se rechazan ===")
	var nivelador_x: RefCounted = NiveladorTerreno.new(GeneradorRampaX.new())
	var una_puerta_11: Dictionary = nivelador_x.calcular_base_y(Vector2i(10, 10), _casa_4x5())
	assert(una_puerta_11["valido"] and una_puerta_11["base_y"] == 9)  # frente (9,12): suelo 9
	var dos_puertas_11: Dictionary = nivelador_x.calcular_base_y(Vector2i(10, 10), _casa_4x5(true))
	assert(not dos_puertas_11["valido"] and dos_puertas_11["motivo"] == "puertas")  # 9 vs 14

	print("\n=== TEST 12: puerta frente a un desnivel mayor al límite se rechaza ===")
	# Acantilado (altura 100) exactamente en el frente (2,2) de la puerta en (3,2).
	var acantilado_12: Dictionary = nivelador_acantilado.calcular_base_y(Vector2i(3, 0), _casa_4x5())
	assert(not acantilado_12["valido"] and acantilado_12["motivo"] == "pendiente")

	print("\n=== TEST 13: sin puerta, base_y conserva el comportamiento anterior (altura_objetivo + 1) ===")
	var casa_sin_puerta: Dictionary = _casa_4x5()
	casa_sin_puerta.erase(Vector3i(0, 1, 2))
	casa_sin_puerta.erase(Vector3i(0, 2, 2))
	var base_13: Dictionary = nivelador_plano.calcular_base_y(Vector2i(0, 0), casa_sin_puerta)
	assert(base_13["valido"] and base_13["base_y"] == 6)
	# Puerta a 2 bloques sobre la losa (p. ej. un nivel bajo la entrada): la
	# losa baja un bloque más (base_y = 5 + 1 - 2 = 4) y la excavación llega más hondo.
	var casa_sotano: Dictionary = {}
	for rel_13 in _casa_4x5():
		casa_sotano[rel_13 + Vector3i(0, 1, 0)] = _casa_4x5()[rel_13]
	var base_13b: Dictionary = nivelador_plano.calcular_base_y(Vector2i(0, 0), casa_sotano)
	assert(base_13b["valido"] and base_13b["base_y"] == 4)
	assert(nivelador_plano.calcular_excavacion(Vector2i(0, 0), _rectangulo(4, 5), 4).size() == 40, "2 capas (Y=5 y Y=4) x 20 columnas")

	print("\n=== TEST 14: resumen_materiales() del ejemplo 4x5x5 sobre terreno plano (79 piedra, 12 madera, +19 tierra) ===")
	var neto_14: Dictionary = nivelador_plano.resumen_materiales(casa_9, 0, {"tierra": 20})
	assert(neto_14["piedra"] == -79)
	assert(neto_14["madera"] == -12)
	assert(neto_14["tierra"] == 19, "20 excavados - 1 de la ventana")
	var neto_14b: Dictionary = nivelador_plano.resumen_materiales(casa_9, 3, {"tierra": 20})
	assert(neto_14b["tierra"] == 16, "el relleno consume tierra")
	var neto_14c: Dictionary = nivelador_plano.resumen_materiales({Vector3i(0, 0, 0): "ventana"}, 0, {"tierra": 1})
	assert(neto_14c.is_empty(), "un neto de 0 no aparece")

	print("\n=== Las 14 pruebas de NiveladorTerreno pasaron correctamente ===")
```

Actualiza el encabezado del archivo: en el comentario superior cambia "debe imprimir las 8 pruebas" por "debe imprimir las 14 pruebas".

- [ ] **Step 2: Correr la escena y verificar que falla**

Run: `NiveladorTerrenoTest.tscn` (ver Global Constraints).
Expected: FAIL — error de parseo/`Invalid call. Nonexistent function 'calcular_base_y'`.

- [ ] **Step 3: Implementar**

En `godot/scripts/NiveladorTerreno.gd`, tras `const LIMITE_PENDIENTE := 2` agrega:

```gdscript
const DIRECCIONES_XZ := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Costo en material de cada tipo de celda estructural de un blueprint (ver
## docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md).
## Solo alimenta el resumen VISUAL del HUD — no existe inventario real.
const COSTO_POR_CELDA := {
	"pared": {"piedra": 1},
	"piso": {"tierra": 1},
	"ventana": {"tierra": 1},
	"puerta_inferior": {"madera": 1},
	"puerta_superior": {"madera": 1},
	"cama_cabecera": {"madera": 2},
	"cama_pies": {"madera": 2},
	"baul": {"madera": 6},
}
```

Reemplaza `calcular_relleno()` (líneas 67-79) por:

```gdscript
## Cuántos bloques de "tierra" hacen falta en cada columna de "columnas"
## para llegar a la altura máxima de esa huella. Solo incluye columnas que
## realmente necesitan relleno (columnas ya a la altura máxima no aparecen).
## Usada por los puestos periféricos; los blueprints usan
## calcular_relleno_hasta() con el tope de su propio nivel base.
func calcular_relleno(esquina: Vector2i, columnas: Array[Vector2i]) -> Dictionary:
	return calcular_relleno_hasta(esquina, columnas, altura_objetivo(esquina, columnas))


## Igual que calcular_relleno() pero con un "tope" explícito: cuántos bloques
## faltan en cada columna para que su superficie llegue a "tope".
func calcular_relleno_hasta(esquina: Vector2i, columnas: Array[Vector2i], tope: int) -> Dictionary:
	var relleno: Dictionary = {}  # Vector2i -> int
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var faltante: int = tope - _generador.altura_en(x, z)
		if faltante > 0:
			relleno[Vector2i(x, z)] = faltante
	return relleno


## Celdas de terreno que hay que retirar bajo la huella: en cada columna,
## todo bloque desde la superficie hasta "base_y" inclusive (nada si la
## columna ya está por debajo). Ordenadas de arriba hacia abajo (y, x, z).
func calcular_excavacion(esquina: Vector2i, columnas: Array[Vector2i], base_y: int) -> Array[Vector3i]:
	var celdas: Array[Vector3i] = []
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		for y in range(_generador.altura_en(x, z), base_y - 1, -1):
			celdas.append(Vector3i(x, y, z))
	celdas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y > b.y
		if a.x != b.x:
			return a.x < b.x
		return a.z < b.z
	)
	return celdas


## Nivel base de un blueprint colocado en "esquina": la Y mundial de su
## celda rel.y=0 (la losa de piso) tal que cada "puerta_inferior" quede a
## nivel del suelo natural delante de ella — base_y = altura_en(frente) + 1 -
## rel.y_puerta. "frente" es el vecino cardinal en XZ que cae fuera de la
## huella (mismo criterio que VoxelWorld.calcular_despeje()). Rechaza
## ("valido": false) si una puerta y su frente difieren en más de
## LIMITE_PENDIENTE ("pendiente") o si dos puertas piden base_y distintos
## ("puertas"). Sin puertas devuelve altura_objetivo() + 1, el
## comportamiento anterior. "frentes" son todas las columnas frontales, para
## que el llamador valide lo que este módulo no ve (agua, límites del mundo).
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
				return {"valido": false, "base_y": respaldo, "motivo": "pendiente", "frentes": frentes}
			frentes.append(frente)
			candidatos[suelo_frente + 1 - rel.y] = true
	if candidatos.size() > 1:
		return {"valido": false, "base_y": respaldo, "motivo": "puertas", "frentes": frentes}
	var base_y: int = respaldo if candidatos.is_empty() else candidatos.keys()[0]
	return {"valido": true, "base_y": base_y, "motivo": "", "frentes": frentes}


## Neto por material de un blueprint: negativo = hace falta, positivo =
## sobra. Resta el costo de cada celda de "celdas_3d" (COSTO_POR_CELDA) y
## "relleno_total" bloques de tierra, y suma "recogido" (material -> cantidad
## obtenida al excavar). Los materiales con neto 0 no aparecen. Solo para el
## resumen visual del HUD — no toca ningún inventario.
func resumen_materiales(celdas_3d: Dictionary, relleno_total: int, recogido: Dictionary) -> Dictionary:
	var neto: Dictionary = {}
	for rel in celdas_3d:
		var costo: Dictionary = COSTO_POR_CELDA.get(celdas_3d[rel], {})
		for material in costo:
			neto[material] = neto.get(material, 0) - costo[material]
	if relleno_total > 0:
		neto["tierra"] = neto.get("tierra", 0) - relleno_total
	for material in recogido:
		neto[material] = neto.get(material, 0) + recogido[material]
	for material in neto.keys():
		if neto[material] == 0:
			neto.erase(material)
	return neto
```

- [ ] **Step 4: Correr la escena y verificar que pasa**

Run: `NiveladorTerrenoTest.tscn`.
Expected: PASS — "=== Las 14 pruebas de NiveladorTerreno pasaron correctamente ===" (las pruebas 1-8 originales incluidas, prueba de regresión de `calcular_relleno`).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/NiveladorTerreno.gd godot/scripts/NiveladorTerrenoTest.gd
git commit -m "feat: nivel base por suelo frontal, excavación, relleno con tope y resumen de materiales (lógica pura)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 2: VoxelWorld — cola de preparación que cava y rellena

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd` (`minar_bloque` ~494-523, `surtir_construccion` ~1280-1319)
- Test: `godot/scripts/BlueprintValidatorTest.gd` (TEST 48, antes de la línea final)
- Modify (doc): `docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md`

**Interfaces:**
- Consumes: `Construccion.iniciar/avanzar` y `iniciar_construccion_fantasma(orden_relleno, tipos_relleno, orden_estructura, tipos_estructura, metadata)` **sin cambios de firma**.
- Produces: en `tipos_relleno`, además de `"tierra"`, dos tipos con significado nuevo: `"aire"` (la celda es terreno real: se retira y queda vacía) y `"fantasma"` (terreno real que además es celda de la estructura: se retira y queda como fantasma). `orden_relleno` puede empezar con celdas de excavación (terreno real) seguidas de las de relleno.

- [ ] **Step 1: Escribir la prueba que falla**

En `BlueprintValidatorTest.gd`, antes de `print("\n=== Las 47 pruebas de BlueprintValidator pasaron correctamente ===")`, agrega:

```gdscript
	print("\n=== TEST 48: la cola de preparación cava terreno real (aire/fantasma) antes de rellenar, y la losa enterrada queda como fantasma ===")
	const OX48 := 1300
	var celda_cavar_48 := Vector3i(OX48, 1, OX48)        # terreno suelto, no es parte del edificio
	var celda_losa_48 := Vector3i(OX48 + 1, 1, OX48)     # terreno que la losa del edificio va a ocupar
	var celda_relleno_48 := Vector3i(OX48 + 2, 1, OX48)  # hueco por rellenar
	mundo.colocar_bloque(celda_cavar_48, "tierra")
	mundo.colocar_bloque(celda_losa_48, "piedra")
	var orden_prep_48: Array[Vector3i] = [celda_cavar_48, celda_losa_48, celda_relleno_48]
	var tipos_prep_48 := {celda_cavar_48: "aire", celda_losa_48: "fantasma", celda_relleno_48: "tierra"}
	mundo.iniciar_construccion_fantasma(orden_prep_48, tipos_prep_48, [celda_losa_48], {celda_losa_48: "pared"})
	assert(mundo.obtener_tipo(celda_cavar_48) == "tierra", "el terreno a cavar sigue intacto al emplazar")
	assert(mundo.obtener_tipo(celda_losa_48) == "piedra")
	assert(mundo.obtener_tipo(celda_relleno_48) == "fantasma")
	assert(not mundo.minar_bloque(celda_losa_48), "la celda de la estructura es inmune al minado normal")

	# Apunta al terreno suelto (no es del edificio): avanza la cola y lo cava.
	var s1_48: Dictionary = mundo.surtir_construccion(celda_cavar_48)
	assert(mundo.obtener_tipo(celda_cavar_48) == "", "la celda 'aire' queda vacía")
	assert(mundo.obtener_tipo(celda_losa_48) == "piedra")
	assert(not s1_48.get("completa", false))

	# Apunta a la estructura: el grupo avanza su cola de preparación primero -> la losa
	# se retira y queda fantasma (la estructura aún no avanza).
	mundo.surtir_construccion(celda_losa_48)
	assert(mundo.obtener_tipo(celda_losa_48) == "fantasma", "la celda 'fantasma' retira el terreno y deja el fantasma")
	assert(mundo.obtener_tipo(celda_relleno_48) == "fantasma", "el relleno espera a que termine la excavación")

	# Ahora el relleno, y por último la estructura.
	var s3_48: Dictionary = mundo.surtir_construccion(celda_losa_48)
	assert(mundo.obtener_tipo(celda_relleno_48) == "tierra")
	assert(not s3_48.get("completa", false))
	var s4_48: Dictionary = mundo.surtir_construccion(celda_losa_48)
	assert(mundo.obtener_tipo(celda_losa_48) == "pared")
	assert(s4_48["completa"])
	print("OK: la cola cava (aire/fantasma) antes de rellenar y solo entonces avanza la estructura.")
```

Cambia la línea final a `print("\n=== Las 48 pruebas de BlueprintValidator pasaron correctamente ===")`.

- [ ] **Step 2: Correr `Test.tscn` y verificar que falla**

Run: `Test.tscn`.
Expected: FAIL en TEST 48 — la celda `"aire"` no se retira (el aplicador actual llama `colocar_bloque(celda, "aire")`, que no existe en la biblioteca), así que `obtener_tipo(celda_cavar_48) == ""` falla o queda `"tierra"`.

- [ ] **Step 3: Implementar**

En `VoxelWorld.gd`, reemplaza el final de `minar_bloque()` (desde `var tipo_anterior: String = obtener_tipo(celda)` hasta `return true`) por:

```gdscript
	_retirar_bloque(celda)
	return true


## Retira "celda" SIN las guardas de minar_bloque() (agua, bedrock,
## inmunidad de edificio, celda vacía): borra su "pareja" si la tiene, avisa
## a los translúcidos y deja escurrir el agua vecina. Lo usan minar_bloque()
## (que ya validó) y el paso de excavación de la cola de preparación
## (_aplicar_paso_cola()), que necesita cavar celdas que YA pertenecen a un
## edificio (la losa enterrada) y que minar_bloque() rechazaría.
func _retirar_bloque(celda: Vector3i) -> void:
	var tipo_anterior: String = obtener_tipo(celda)
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)
	var vecinos_agua: Array[Vector3i] = []
	for delta in VECINOS_3D:
		var vecino: Vector3i = celda + delta
		if obtener_tipo(vecino) == "agua":
			vecinos_agua.append(vecino)
	if not vecinos_agua.is_empty():
		_escurrir_agua_desde(vecinos_agua)
```

Antes de `surtir_construccion()` agrega:

```gdscript
## Aplica un paso ya avanzado de la cola de preparación del terreno (ver
## Construccion.avanzar()): "resultado" trae {"celda", "tipo"}. "tierra"
## (relleno) convierte la celda fantasma en bloque real. "aire" y "fantasma"
## son EXCAVACIÓN: la celda es terreno real y se retira; "fantasma" indica
## que además pertenece a la estructura del edificio (p. ej. la losa
## enterrada) y por eso queda como fantasma en vez de vacía.
func _aplicar_paso_cola(resultado: Dictionary) -> void:
	var celda: Vector3i = resultado["celda"]
	var tipo: String = resultado["tipo"]
	if tipo == "aire" or tipo == "fantasma":
		_retirar_bloque(celda)
		if tipo == "fantasma":
			colocar_bloque(celda, "fantasma")
		return
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocar_bloque(celda, tipo, true)
```

Dentro de `surtir_construccion()` reemplaza las dos parejas de líneas que aplican un paso:

```gdscript
		set_cell_item(resultado_relleno["celda"], GridMap.INVALID_CELL_ITEM)
		colocar_bloque(resultado_relleno["celda"], resultado_relleno["tipo"], true)
```
por `		_aplicar_paso_cola(resultado_relleno)` y

```gdscript
			set_cell_item(resultado_grupo["celda"], GridMap.INVALID_CELL_ITEM)
			colocar_bloque(resultado_grupo["celda"], resultado_grupo["tipo"], true)
```
por `			_aplicar_paso_cola(resultado_grupo)`.

Actualiza el comentario de `iniciar_construccion_fantasma()` ("orden_relleno/tipos_relleno son las celdas de nivelación…") añadiendo: "Puede incluir, ANTES del relleno, celdas de excavación (terreno real) con tipo 'aire' o 'fantasma' — ver _aplicar_paso_cola()."

- [ ] **Step 4: Correr las escenas y verificar que pasan**

Run: `Test.tscn` — Expected: PASS "Las 48 pruebas de BlueprintValidator pasaron correctamente" (incluye TEST 20/24/24b/38-39 que cubren `minar_bloque` refactorizado y el relleno).
Run: `RecoleccionTest.tscn` — Expected: PASS (usa `minar_bloque`).

- [ ] **Step 5: Sincronizar el spec (cola única) y hacer commit**

En `docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md`, sección 2 "Flujo en el mundo", reemplaza el primer bullet ("**Orden:** excavación → relleno → estructura. La excavación es otra cola…") por:

```
- **Orden:** excavación → relleno → estructura. Excavación y relleno viajan
  en **una sola cola de preparación** de `Construccion.gd` (excavación
  primero, relleno después), con la misma referencia `edificio_relleno_cola`;
  así `iniciar_construccion_fantasma()` no cambia y el orden se cumple solo.
  Las celdas de excavación llevan destino `"aire"`, o `"fantasma"` si además
  son celdas de la estructura.
```
y en "Riesgos conocidos" cambia "La cola de excavación reutiliza…" por "El aplicador de pasos (`_aplicar_paso_cola()`) es común a la rama de relleno huérfano y a la de grupo de `surtir_construccion()`".

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md
git commit -m "feat: cola de preparación cava terreno real (aire/fantasma) antes de rellenar" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 3: Ficha "Materiales de construcción" en el HUD

**Files:**
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scenes/Main.tscn` (nodo `MaterialesFicha`, antes de `ModoDeconstruccionLabel`)
- Test: `godot/scripts/NiveladorTerrenoTest.gd` (TEST 15)

**Interfaces:**
- Consumes: el `Dictionary` neto de `NiveladorTerreno.resumen_materiales()`.
- Produces: `HUD.texto_materiales(neto: Dictionary) -> String` (estática); `mostrar_ficha_materiales()`, `actualizar_materiales(neto: Dictionary)`, `ocultar_ficha_materiales()` en la instancia HUD (`hud` en `CamaraCenital`).

- [ ] **Step 1: Escribir la prueba que falla**

En `NiveladorTerrenoTest.gd`, junto a la constante `NiveladorTerreno` agrega `const HUDScript = preload("res://scripts/HUD.gd")` y, antes de la línea final, agrega:

```gdscript
	print("\n=== TEST 15: HUD.texto_materiales() pone lo necesario sin signo (mayor primero) y el sobrante con '+' ===")
	var texto_15: String = HUDScript.texto_materiales({"piedra": -79, "madera": -12, "tierra": 19})
	assert(texto_15 == "Materiales de construcción:\n79 piedra\n12 madera\n+ 19 tierra", texto_15)
	assert(HUDScript.texto_materiales({}) == "Materiales de construcción:\n-")
```

Cambia la línea final y el encabezado a "Las 15 pruebas".

- [ ] **Step 2: Correr la escena y verificar que falla**

Run: `NiveladorTerrenoTest.tscn`. Expected: FAIL — `Nonexistent function 'texto_materiales'`.

- [ ] **Step 3: Implementar**

En `HUD.gd`, tras `@onready var oxigeno_label: Label = $OxigenoLabel` agrega:

```gdscript
@onready var materiales_ficha: Label = $MaterialesFicha
```

Al final del archivo agrega:

```gdscript
## Ficha VISUAL de los materiales que movilizaría el blueprint activo (ver
## docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md):
## no lee ni toca ningún inventario real (no existe todavía).
func mostrar_ficha_materiales() -> void:
	materiales_ficha.text = texto_materiales({})
	materiales_ficha.visible = true


func actualizar_materiales(neto: Dictionary) -> void:
	materiales_ficha.text = texto_materiales(neto)


func ocultar_ficha_materiales() -> void:
	materiales_ficha.visible = false


## "neto" es material -> int (negativo = hace falta, positivo = sobra; ver
## NiveladorTerreno.resumen_materiales()). Lo necesario va sin signo y de
## mayor a menor; el sobrante recogido va después con "+".
static func texto_materiales(neto: Dictionary) -> String:
	var necesarios: Array = []
	var sobrantes: Array = []
	for material in neto:
		var cantidad: int = neto[material]
		if cantidad < 0:
			necesarios.append([-cantidad, material])
		elif cantidad > 0:
			sobrantes.append("+ %d %s" % [cantidad, material])
	necesarios.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lineas: Array = ["Materiales de construcción:"]
	for necesario in necesarios:
		lineas.append("%d %s" % [necesario[0], necesario[1]])
	lineas.append_array(sobrantes)
	if lineas.size() == 1:
		lineas.append("-")
	return "\n".join(lineas)
```

En `Main.tscn`, justo antes de `[node name="ModoDeconstruccionLabel" ...]` inserta:

```
[node name="MaterialesFicha" type="Label" parent="HUDLayer" unique_id=1902384756]
visible = false
offset_left = 12.0
offset_top = 160.0
offset_right = 320.0
offset_bottom = 280.0
text = "Materiales de construcción:"

```

(Antes verifica con Grep que `1902384756` no exista ya en `Main.tscn`.)

- [ ] **Step 4: Correr la escena y verificar que pasa**

Run: `NiveladorTerrenoTest.tscn`. Expected: PASS "Las 15 pruebas de NiveladorTerreno pasaron correctamente".
Run: `Main.tscn` un instante (F5 vía MCP) y confirmar en `get_debug_output` que no hay errores de nodo faltante (`MaterialesFicha`), luego `stop_project`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/HUD.gd godot/scenes/Main.tscn godot/scripts/NiveladorTerrenoTest.gd
git commit -m "feat: ficha visual de materiales de construcción en el HUD" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 4: CamaraCenital — un solo `base_y` para clic y previsualización

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd` (encabezado ~188; tras `_altura_blueprint` ~830; `_actualizar_previsualizacion_blueprint` ~843-869; `_procesar_clic_blueprint` ~1363-1425; `_rotar_blueprint` ~1014-1035; `_alternar_modo_colocar_blueprint` ~1043-1062; `_salir_de_modo_colocar_blueprint` ~1065)

`CamaraCenital` no tiene pruebas automáticas (depende de cámara, ratón y escena): la verificación es manual (Step 5) además de las pruebas puras ya hechas.

**Interfaces:**
- Consumes: `nivelador_puesto.calcular_base_y / calcular_excavacion / calcular_relleno_hasta / resumen_materiales` (Task 1), tipos `"aire"`/`"fantasma"` de la cola (Task 2), `hud.mostrar_ficha_materiales / actualizar_materiales / ocultar_ficha_materiales` (Task 3).
- Produces: nada consumido por otras tareas.

- [ ] **Step 1: Constantes, variable y helpers**

Junto a `var _blueprint_activo: Dictionary = {}` (línea ~188) agrega:

```gdscript
## Última esquina para la que se calculó el resumen de materiales del HUD
## (se recalcula solo si cambia, o si se invalida al rotar/entrar al modo).
const SIN_RESUMEN := Vector2i(-999999, -999999)
var _resumen_blueprint_vigente: Vector2i = SIN_RESUMEN

const MENSAJES_BASE_Y := {
	"pendiente": "Colocación rechazada: el desnivel entre una puerta y el suelo frente a ella supera el límite permitido.",
	"puertas": "Colocación rechazada: las puertas de este edificio quedarían a niveles distintos (el suelo frente a cada una tiene otra altura).",
	"frente": "Colocación rechazada: el suelo frente a una puerta es agua o queda fuera del mundo.",
}
```

Tras `_altura_blueprint()` agrega:

```gdscript
## El suelo frente a una puerta debe ser tierra firme dentro del mundo: ni
## agua ni fuera de los límites. nivelador_puesto ignora el agua
## (_AlturaSinAgua), por eso esto se revisa aquí con el mundo real.
func _frente_es_suelo_firme(frente: Vector2i) -> bool:
	if frente.x < 0 or frente.y < 0 or frente.x >= mundo.ANCHO_MUNDO or frente.y >= mundo.LARGO_MUNDO:
		return false
	return mundo.obtener_tipo(Vector3i(frente.x, mundo.altura_en(frente.x, frente.y), frente.y)) != "agua"


## Nivel base del blueprint activo en "esquina" (ver
## NiveladorTerreno.calcular_base_y()) más la validación de sus frentes.
## Fuente ÚNICA de base_y para el clic y la previsualización. Devuelve el
## mismo diccionario que calcular_base_y(); "motivo" ∈ {"", "pendiente",
## "puertas", "frente"} (clave de MENSAJES_BASE_Y).
func _base_y_blueprint(esquina: Vector2i) -> Dictionary:
	var resultado: Dictionary = nivelador_puesto.calcular_base_y(esquina, _blueprint_activo["celdas_3d"])
	if not resultado["valido"]:
		return resultado
	for frente: Vector2i in resultado["frentes"]:
		if not _frente_es_suelo_firme(frente):
			resultado["valido"] = false
			resultado["motivo"] = "frente"
			return resultado
	return resultado


## Celdas de terreno REAL a retirar bajo la huella (de calcular_excavacion(),
## sin las que ya están vacías, p. ej. cuevas).
func _celdas_excavacion(esquina: Vector2i, columnas: Array[Vector2i], base_y: int) -> Array[Vector3i]:
	var celdas: Array[Vector3i] = []
	for celda in nivelador_puesto.calcular_excavacion(esquina, columnas, base_y):
		if mundo.get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
			celdas.append(celda)
	return celdas


## Cuánto de cada material se recogería al excavar "celdas" (material_real
## de lo que hay ahora en cada una).
func _material_excavado(celdas: Array[Vector3i]) -> Dictionary:
	var recogido: Dictionary = {}
	for celda in celdas:
		var material: String = mundo.material_real(mundo.obtener_tipo(celda))
		recogido[material] = recogido.get(material, 0) + 1
	return recogido


## Actualiza la ficha de materiales del HUD para el blueprint activo en
## "esquina". Se recalcula solo si cambió la esquina (o se invalidó, ver
## SIN_RESUMEN). Si la colocación no es válida muestra "-".
## ponytail: sobre una huella con agua, la previsualización cuenta la
## excavación con el fondo real y no con la tierra que dejará el drenado
## (que ocurre al confirmar); la diferencia solo afecta al número mostrado.
func _actualizar_resumen_materiales(esquina: Vector2i, columnas: Array[Vector2i], base_y: int, valida: bool) -> void:
	var clave: Vector2i = esquina if valida else SIN_RESUMEN
	if clave == _resumen_blueprint_vigente:
		return
	_resumen_blueprint_vigente = clave
	if not valida:
		hud.actualizar_materiales({})
		return
	var relleno: Dictionary = nivelador_puesto.calcular_relleno_hasta(esquina, columnas, base_y - 1)
	var total_relleno := 0
	for cantidad in relleno.values():
		total_relleno += cantidad
	var recogido: Dictionary = _material_excavado(_celdas_excavacion(esquina, columnas, base_y))
	hud.actualizar_materiales(nivelador_puesto.resumen_materiales(_blueprint_activo["celdas_3d"], total_relleno, recogido))
```

- [ ] **Step 2: Previsualización**

En `_actualizar_previsualizacion_blueprint()` reemplaza desde `var valida: bool = ...` hasta el final de la función por:

```gdscript
	var resultado_base: Dictionary = _base_y_blueprint(esquina)
	var valida: bool = zona_correcta and relieve_valido and resultado_huella["valida"] \
			and resultado_base["valido"] \
			and not _huella_choca_con_otro_puesto(esquina, columnas) \
			and _huella_tiene_columna_en_tierra(esquina, columnas)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var base_y: int = resultado_base["base_y"]
	for i in range(_offsets_huella_blueprint.size()):
		var rel: Vector3i = _offsets_huella_blueprint[i]
		var x: int = esquina.x + rel.x
		var y: int = base_y + rel.y
		var z: int = esquina.y + rel.z
		var caja: MeshInstance3D = _huella_blueprint[i]
		var material: StandardMaterial3D = caja.material_override
		material.albedo_color = color
		caja.position = Vector3(x + DESF, y + DESF, z + DESF)
	_actualizar_resumen_materiales(esquina, columnas, base_y, valida)
```

Actualiza el comentario de la función: donde dice "apoyado sobre 'objetivo' — la altura a la que quedaría nivelado el terreno" cámbialo por "en `base_y` — el nivel al que la puerta queda a ras del suelo frontal, ver `_base_y_blueprint()`".

- [ ] **Step 3: Clic de emplazamiento**

En `_procesar_clic_blueprint()`:

(a) Reemplaza
```gdscript
	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, objetivo + 1 + rel.y, esquina.y + rel.z)
```
por
```gdscript
	var resultado_base: Dictionary = _base_y_blueprint(esquina)
	if not resultado_base["valido"]:
		print(MENSAJES_BASE_Y[resultado_base["motivo"]])
		return
	var base_y: int = resultado_base["base_y"]
	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, base_y + rel.y, esquina.y + rel.z)
```

(b) Reemplaza el bloque
```gdscript
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
	var relleno_orden: Array[Vector3i] = []
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			relleno_orden.append(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y))
	var tipos_relleno: Dictionary = {}
	for celda_r in relleno_orden:
		tipos_relleno[celda_r] = "tierra"
```
por
```gdscript
	# Cola de "preparación del terreno" (ver VoxelWorld._aplicar_paso_cola()):
	# primero se CAVA (terreno real sobre la losa), luego se RELLENA (columnas
	# por debajo del nivel de la losa). Una celda cavada que además es de la
	# estructura (la losa enterrada) queda "fantasma", no vacía.
	var excavacion: Array[Vector3i] = _celdas_excavacion(esquina, columnas, base_y)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno_hasta(esquina, columnas, base_y - 1)
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
```

(c) En `metadata` agrega `"base_y": base_y,` tras `"profundidad": alto,`.

(d) Reemplaza el `print("Construcción fantasma iniciada en (", ...)` por:
```gdscript
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — excavación: ", excavacion.size(), " bloques, relleno: ", total_relleno, " — surtir para completarla.")
```

Actualiza el comentario de la función (bloque `##` sobre `_procesar_clic_blueprint`): "calcula el relleno de nivelación" → "calcula el nivel base (`base_y`, puerta a ras del suelo frontal), la excavación y el relleno".

- [ ] **Step 4: Modo colocar-blueprint (ficha y caché)**

- En `_alternar_modo_colocar_blueprint()`, tras `modo_colocar_blueprint = true` agrega:
  ```gdscript
  	_resumen_blueprint_vigente = SIN_RESUMEN
  	hud.mostrar_ficha_materiales()
  ```
- En `_salir_de_modo_colocar_blueprint()`, tras `_blueprint_activo = {}` agrega `hud.ocultar_ficha_materiales()`.
- En `_rotar_blueprint()`, antes de `_mostrar_huella_blueprint(true)` agrega `_resumen_blueprint_vigente = SIN_RESUMEN`.

- [ ] **Step 5: Verificación manual en `Main.tscn`**

Run: `Main.tscn` (F5). Declarar un edificio (apuntar a una puerta + tecla de declarar, flujo existente), pasar a la cámara cenital (`C`), `B` para colocar el blueprint. Comprobar:
1. La ficha "Materiales de construcción" aparece y cambia al mover el cursor; en terreno plano muestra el patrón `N piedra / N madera / + N tierra` (excavación de la huella).
2. Las cajas fantasma quedan con la losa a la Y del suelo (un bloque más bajo que antes) y la puerta a ras del suelo frontal, sobre plano y sobre ladera.
3. Al colocar, la consola imprime excavación/relleno; con clic derecho (surtir) sobre el edificio primero desaparecen los bloques de la huella (cava), luego el relleno, luego la estructura; la puerta termina sin bloque de tierra delante y sin escalón.
4. Rechazos con mensaje: puerta frente a agua; edificio con puertas en lados de distinta altura; desnivel puerta-frente > 2.
5. Sin errores en `get_debug_output`; `stop_project` y `Get-Process` sin huérfanos.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: puertas a nivel de suelo — base_y único para clic y previsualización, excavación y relleno como cola pendiente" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

---

### Task 5: Documentación, verificación final e integración

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (§5 "Nivelación de Terreno…", líneas ~122-127)
- Modify: `PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md`
- Modify (sin versionar, NO agregar al commit): `docs/Pendientes y próximos pasos.md`

- [ ] **Step 1: GDD §5**

Lee primero la sección (CLAUDE.md). Reemplaza la viñeta

`> * **Nivelación al Punto Más Alto:** El edificio se nivela a la altura del punto más alto de su huella (footprint). Las celdas más bajas de la huella requieren bloques de "tierra" como material adicional, para rellenar hasta ese nivel.`

por

```
> * **Nivelación al Punto Más Alto:** Los edificios sin puerta (y los puestos periféricos) se nivelan a la altura del punto más alto de su huella (footprint). Las celdas más bajas de la huella requieren bloques de "tierra" como material adicional, para rellenar hasta ese nivel.
> * **Nivel de Puerta y Excavación:** Todo edificio con puerta toma como nivel de referencia el suelo natural justo delante de ella: la losa de piso se entierra hasta quedar a ras de ese suelo, de modo que la puerta queda a la misma altura que la carretera que se le conecte (sin bloques de tierra delante de la puerta, y nunca más alta que el bloque sólido que tiene enfrente). Las columnas de la huella más altas que la losa se excavan y las más bajas se rellenan con tierra. Cavar es trabajo pendiente del jugador, igual que el relleno; lo excavado (tierra o piedra) se recogerá al inventario cuando este exista. Todas las puertas de un edificio deben coincidir en nivel, y el desnivel entre una puerta y el suelo frente a ella respeta el límite de pendiente.
> * **Materiales de Construcción (resumen):** Al emplazar un edificio el HUD muestra los materiales que movilizaría (necesarios menos lo recogido al excavar). Por ahora es solo informativo: no existe inventario real.
```

Añade al final de la viñeta "Ejemplo:" la aclaración: ` (Ejemplo para edificios sin puerta; en un edificio con puerta el nivel lo fija el suelo frontal, ver arriba.)`

- [ ] **Step 2: Doc técnico PoC 6**

Busca con Grep la sección de nivelación/puestos y la línea "Costo de recursos por nivelar". Agrega, en la sección donde se documentan las decisiones funcionales de los blueprints, un apartado:

```
### Puertas a nivel de suelo (2026-09-20)

Spec: `docs/superpowers/specs/2026-09-20-puertas-a-nivel-de-suelo-design.md`.
El nivel base de un blueprint ya no es `altura_objetivo() + 1` sino el que deja
la puerta a ras del suelo natural delante de ella (`NiveladorTerreno.calcular_base_y()`):
la losa queda enterrada un bloque. Se rechaza si las puertas piden niveles distintos,
si el desnivel puerta-frente supera `LIMITE_PENDIENTE` o si el frente es agua/fuera del mundo.
La excavación (terreno real bajo la huella, "aire"/"fantasma") y el relleno viajan en una
sola cola de preparación de `Construccion.gd`, excavación primero
(`VoxelWorld._aplicar_paso_cola()`). El HUD muestra un resumen VISUAL de materiales
(piedra/madera/tierra, neto = recogido - necesario); sigue sin inventario ni cobro real.
Los puestos periféricos conservan la nivelación al punto más alto.
```

En la línea "Costo de recursos por nivelar…" añade al final: ` El resumen visual de materiales de blueprints (2026-09-20) tampoco cobra nada.`

- [ ] **Step 3: Tachar el pendiente (archivo sin versionar)**

En `docs/Pendientes y próximos pasos.md` tacha la viñeta "Corrección del sistema de construcción, para que las puertas queden…" con `~~…~~` (mismo estilo que los ítems tachados). **No** `git add` este archivo (es del usuario y no está versionado).

- [ ] **Step 4: Verificación final**

Run: `NiveladorTerrenoTest.tscn`, `Test.tscn` (48 pruebas), `RecoleccionTest.tscn`. Expected: todas pasan. Confirmar con `Get-Process` que no queden procesos Godot.

- [ ] **Step 5: Commit de documentación**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md"
git commit -m "docs: puertas a nivel de suelo (GDD §5 y PoC 6)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SJTyjZex75AFX3j4vFf7i6"
```

- [ ] **Step 6: Integrar**

Invocar `superpowers:finishing-a-development-branch` para fusionar `feat/puertas-a-nivel-de-suelo` a `main` (los archivos sin versionar del usuario no deben viajar en ningún commit).
