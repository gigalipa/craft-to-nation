# Costo de colocación y bloques estructurales reales — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el bloque estructural placeholder único (`pared`) por 4 materiales reales con costo (`tierra_compactada`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`) más `vidrio` (antes `ventana`) y `tierra` (bloque natural colocable), cobrando el recurso crudo al colocar desde la hotbar del avatar y reembolsándolo simétricamente al volver a minar un bloque que el jugador colocó.

**Architecture:** Una sola tabla de datos (`NiveladorTerreno.COSTO_POR_CELDA`, ya existente y hoy solo usada para el resumen visual del HUD) pasa a ser la fuente de verdad real: la usa `Player._colocar()` para cobrar de `Ciudad.almacen` y `VoxelWorld._retirar_bloque()` para reembolsar, además de seguir alimentando el resumen visual. Los 4 materiales de muro se generalizan como familia intercambiable en `VoxelWorld.TIPOS_ESTRUCTURA` y `BlueprintValidator`, donde hoy solo se reconocía el literal `"pared"`.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), pruebas basadas en `assert()` corridas desde escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-29-costo-colocacion-bloques-design.md`

## Global Constraints

- Tabulaciones en GDScript (no espacios), como exige Godot y `CLAUDE.md`.
- No tocar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- Conservar el español en mensajes del juego, comentarios y pruebas.
- `mcp__godot__get_uid`/`save_scene`/`export_mesh_library` están rotos en este proyecto (memoria `feedback_godot_editor_bridge_broken`): usar el workaround headless con el binario real de Godot para regenerar `BlockLibrary.res`, nunca esas herramientas MCP.
- Costos exactos de la Sección 2 del spec (tabla recurso:bloque) — no inventar ni redondear otros valores.
- Verificación final: correr `godot/scenes/Test.tscn` y cada `*Test.tscn` afectado con Godot 4.7, confirmar que todas las aserciones pasan (`CLAUDE.md`).

## Review Focus

- Colocar un bloque con costo cuando el almacén tiene EXACTAMENTE la cantidad justa (borde: ni de más ni de menos) debe permitirlo, no rechazarlo por error de redondeo.
- Minar un bloque de terreno NATURAL (`hierba`, minerales) nunca debe reembolsar nada, aunque su tipo coincida por casualidad con una clave de `COSTO_POR_CELDA` (la extracción natural sigue su propia tabla, `Recoleccion.RENDIMIENTO_POR_BLOQUE`, sin relación con esta).
- Minar una puerta o cama por un extremo (la celda con `pareja`) debe reembolsar el costo de AMBAS celdas (cabecera+pies o inferior+superior), no solo la que se picó.
- Colocar una puerta/cama que falla por falta de espacio (`colocar_puerta`/`colocar_cama` devuelve `false`) no debe dejar cobrado el recurso: hay que reembolsar de inmediato si ya se cobró antes de intentar colocar.
- Las plantillas de puesto que usaban `"pared"`/`"ventana"` a mano en pruebas (`RecoleccionTest.gd`, `PuestosPrevisualizacionTest.gd`, `PlantillasPuestoTest.gd`) deben seguir compilando y pasando tras el renombre — un `assert` con el nombre viejo hoy pasaría silenciosamente si el tipo ya no existe en la `MeshLibrary` y `colocar_bloque` simplemente devuelve `false` sin lanzar error.

---

## Mapa de archivos

- `godot/scenes/BlockLibrarySource.tscn` — escena editable con los mesh de prueba (cubos de color); se le renombran/agregan nodos.
- `godot/assets/BlockLibrary.res` — `MeshLibrary` binaria horneada desde la anterior; se regenera con un script headless temporal.
- `godot/scripts/NiveladorTerreno.gd` — dueño de `COSTO_POR_CELDA`, la tabla de costos real.
- `godot/scripts/VoxelWorld.gd` — `TIPOS_ESTRUCTURA`, `MATERIAL_REAL`, `TIPOS_TRANSLUCIDOS`, `_retirar_bloque()` (reembolso).
- `godot/scripts/BlueprintValidator.gd` — generalización de `"pared"` a familia de materiales de muro.
- `godot/scripts/PlantillasPuesto.gd` — material fijo por tipo de puesto.
- `godot/scripts/Player.gd` — `tipos_disponibles`, cobro en `_colocar()`.
- `godot/scripts/Hotbar.gd` — nombres y cantidad visible por casilla.
- `godot/scripts/CamaraCenital.gd`, `TranslucidosRenderer.gd`, `Recoleccion.gd`, `ZonaOverlay.gd` — referencias sueltas a `"pared"`/`"piso"`/`"ventana"` fuera de los archivos anteriores.
- `docs/Fichas_Consumo_Produccion.md`, `docs/Pendientes y próximos pasos.md` — actualización final.

---

### Task 1: Bloques reales en la MeshLibrary

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`
- Create (temporal, se borra al final): `godot/scripts/_bake_block_library.gd`
- Test: verificación manual vía script headless (sin `*Test.gd` nuevo — es un recurso, no lógica)

**Interfaces:**
- Produces: los ítems de `res://assets/BlockLibrary.res` con nombres `hierba`, `tierra` (sin cambio), `tierra_compactada`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio` — que las Tasks 2-7 asumen ya indexados por `_id_por_tipo`.

- [ ] **Step 1: Renombrar y agregar nodos en `BlockLibrarySource.tscn`**

Edita el archivo a mano (es texto plano):
- Nodo `piso` (línea 330-334) → renómbralo a `hierba` (deja el mesh/color verde tal cual, ya sirve para "capa superficial").
- Nodo `ventana` (línea 324-328) → renómbralo a `vidrio` (deja el `ArrayMesh` vacío tal cual: su malla real la da `TranslucidosRenderer`, no la `MeshLibrary`).
- Nodo `pared` (línea 306-310) → renómbralo a `bloque_piedra` (el gris ya encaja con piedra).
- Agrega 3 nodos nuevos, mismo patrón que los existentes (un `MeshInstance3D` con un `BoxMesh`/`StandardMaterial3D` propios y su `CollisionShape3D` hijo con `BoxShape3D`):

```
[sub_resource type="StandardMaterial3D" id="Mat_tierra_compactada"]
albedo_color = Color(0.5, 0.35, 0.2, 1)

[sub_resource type="BoxMesh" id="Mesh_tierra_compactada"]
material = SubResource("Mat_tierra_compactada")

[sub_resource type="BoxShape3D" id="Shape_tierra_compactada"]

[sub_resource type="StandardMaterial3D" id="Mat_bloque_madera"]
albedo_color = Color(0.45, 0.3, 0.15, 1)

[sub_resource type="BoxMesh" id="Mesh_bloque_madera"]
material = SubResource("Mat_bloque_madera")

[sub_resource type="BoxShape3D" id="Shape_bloque_madera"]

[sub_resource type="StandardMaterial3D" id="Mat_estructura_hierro"]
albedo_color = Color(0.6, 0.35, 0.15, 1)

[sub_resource type="BoxMesh" id="Mesh_estructura_hierro"]
material = SubResource("Mat_estructura_hierro")

[sub_resource type="BoxShape3D" id="Shape_estructura_hierro"]
```

Y sus nodos (junto a los demás `[node ... parent="."]`, antes del cierre del archivo):

```
[node name="tierra_compactada" type="MeshInstance3D" parent="." unique_id=900000001]
mesh = SubResource("Mesh_tierra_compactada")

[node name="CollisionShape3D" type="CollisionShape3D" parent="tierra_compactada" unique_id=900000002]
shape = SubResource("Shape_tierra_compactada")

[node name="bloque_madera" type="MeshInstance3D" parent="." unique_id=900000003]
mesh = SubResource("Mesh_bloque_madera")

[node name="CollisionShape3D" type="CollisionShape3D" parent="bloque_madera" unique_id=900000004]
shape = SubResource("Shape_bloque_madera")

[node name="estructura_hierro" type="MeshInstance3D" parent="." unique_id=900000005]
mesh = SubResource("Mesh_estructura_hierro")

[node name="CollisionShape3D" type="CollisionShape3D" parent="estructura_hierro" unique_id=900000006]
shape = SubResource("Shape_estructura_hierro")
```

- [ ] **Step 2: Escribir el script headless que hornea la MeshLibrary**

Crea `godot/scripts/_bake_block_library.gd` (mismo patrón que ya usó este proyecto antes, ver memoria `feedback_godot_editor_bridge_broken`):

```gdscript
extends SceneTree

func _init() -> void:
	var origen: Node = load("res://scenes/BlockLibrarySource.tscn").instantiate()
	var biblioteca := MeshLibrary.new()
	for hijo in origen.get_children():
		if not (hijo is MeshInstance3D):
			continue
		var id := biblioteca.get_item_list().size()
		biblioteca.create_item(id)
		biblioteca.set_item_name(id, hijo.name)
		biblioteca.set_item_mesh(id, hijo.mesh)
		var colision: CollisionShape3D = hijo.get_node_or_null("CollisionShape3D")
		if colision != null and colision.shape != null:
			biblioteca.set_item_shapes(id, [colision.shape, Transform3D.IDENTITY])
	var error := ResourceSaver.save(biblioteca, "res://assets/BlockLibrary.res")
	print("Guardado con código: ", error)
	print("Ítems: ", biblioteca.get_item_list().size())
	for id in biblioteca.get_item_list():
		print(" - ", biblioteca.get_item_name(id))
	quit()
```

- [ ] **Step 3: Ejecutar el script headless y verificar los nombres**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot --script res://scripts/_bake_block_library.gd > /tmp/bake_output.txt 2>&1` (Bash, no PowerShell — la redirección de PowerShell fue poco fiable según la memoria).

Expected: `Guardado con código: 0` y la lista de ítems incluye `hierba`, `vidrio`, `bloque_piedra`, `tierra_compactada`, `bloque_madera`, `estructura_hierro` (y todos los demás nombres viejos que no se tocaron: `puerta_inferior`, `puerta_superior`, `cama_cabecera`, `cama_pies`, `baul`, `tierra`, `piedra`, `hierro`, `carbon`, `cobre`, `tierras_raras`, `bedrock`, `mina`, `puesto_caza`, `puesto_madero`, `puesto_pesca`, `fantasma`, `agua`, `madera`, `follaje`, `cuna_recta`, `cuna_esquina`, `cuna_diag_bajo`, `cuna_diag_arriba`, `cuna_diag_lat_izq`, `cuna_diag_lat_der`, `diag_lat`). Si falta alguno, revisa el Step 1.

- [ ] **Step 4: Borrar el script temporal**

```bash
rm godot/scripts/_bake_block_library.gd
```

- [ ] **Step 5: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res
git commit -m "feat: bloques estructurales reales en la MeshLibrary (tierra_compactada, bloque_madera, bloque_piedra, estructura_hierro, vidrio, hierba)"
```

---

### Task 2: Tabla real de costos (`NiveladorTerreno.COSTO_POR_CELDA`)

**Files:**
- Modify: `godot/scripts/NiveladorTerreno.gd:23-35`
- Modify: `godot/scripts/NiveladorTerrenoTest.gd` (casos que usan `"pared"`/`"piso"`/`"ventana"` o los montos viejos de puerta/cama/baúl)

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `NiveladorTerreno.COSTO_POR_CELDA: Dictionary` (tipo de celda -> {recurso: cantidad}) — Task 3 y Task 6 lo consumen para reembolso y cobro real; `NiveladorTerreno.resumen_materiales()` sigue consumiéndolo sin cambios de firma.

- [ ] **Step 1: Actualizar la tabla**

Reemplaza `godot/scripts/NiveladorTerreno.gd:23-35`:

```gdscript
## Costo en material de cada tipo de celda estructural (ver docs/superpowers/
## specs/2026-09-29-costo-colocacion-bloques-design.md, Sección 2). Fuente
## real: la usan Player._colocar() para cobrar y VoxelWorld._retirar_bloque()
## para reembolsar al re-minar, además del resumen visual del HUD de abajo.
## "puerta"/"cama" son el costo total de la acción de colocar (dos celdas a
## la vez, ver VoxelWorld.colocar_puerta()/colocar_cama()); "puerta_inferior"/
## "puerta_superior"/"cama_cabecera"/"cama_pies" son el costo POR CELDA,
## usado al reembolsar o al escanear una estructura ya construida.
const COSTO_POR_CELDA := {
	"tierra": {"tierra": 1},
	"tierra_compactada": {"tierra": 1},
	"bloque_madera": {"madera": 5},
	"bloque_piedra": {"piedra": 5},
	"estructura_hierro": {"hierro": 5},
	"vidrio": {"tierra": 1},
	"puerta_inferior": {"madera": 1},
	"puerta_superior": {"madera": 1},
	"puerta": {"madera": 2},
	"cama_cabecera": {"madera": 1},
	"cama_pies": {"madera": 1},
	"cama": {"madera": 2},
	"baul": {"madera": 1},
}
```

- [ ] **Step 2: Buscar y corregir las pruebas que dependían de los montos/tipos viejos**

Run: `grep -n '"pared"\|"piso"\|"ventana"\|cama_cabecera.*2\|baul.*6' godot/scripts/NiveladorTerrenoTest.gd`

Para cada coincidencia de tipo (no de monto): reemplaza `"pared"` por `"bloque_piedra"`, `"piso"` por `"tierra_compactada"` o quítala si el caso probaba específicamente el relleno de piso (ese concepto ya no existe: el relleno de nivelación ahora es siempre `"tierra"`, ver `relleno_total` en `resumen_materiales()`), y `"ventana"` por `"vidrio"`. Para los montos: si una prueba afirma un neto que dependía de `cama_cabecera`/`cama_pies` a 2 c/u o `baul` a 6, actualiza el valor esperado a los nuevos (1 c/u y 1 respectivamente).

- [ ] **Step 3: Correr las pruebas**

Abre `godot/scenes/NiveladorTerrenoTest.tscn` en Godot 4.7 (o `godot.windows.opt.tools.64.exe --path godot godot/scenes/NiveladorTerrenoTest.tscn` headless) y confirma que no salta ningún `assert()`.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/NiveladorTerreno.gd godot/scripts/NiveladorTerrenoTest.gd
git commit -m "feat: NiveladorTerreno.COSTO_POR_CELDA pasa a ser la tabla real de costo/reembolso"
```

---

### Task 3: Reembolso al re-minar (`VoxelWorld.gd`)

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd:80-102` (comentarios + `TIPOS_ESTRUCTURA` + `MATERIAL_REAL`), `:113` (`COLOR_...ventana`), `:150` (`TIPOS_TRANSLUCIDOS`), `:325-425` (comentarios/`tipo == "ventana"`), `:504` (comentario), `:563-617` (`_generar_terreno`, coloca `"piso"` → `"hierba"`), `:763-799` (`minar_bloque`/`_retirar_bloque`, agrega reembolso), `:1418-1419` (agrupación por capas)
- Test: `godot/scripts/ExtraccionTest.gd` (agrega los casos nuevos al final de `ejecutar_pruebas()`)

**Interfaces:**
- Consumes: `NiveladorTerreno.COSTO_POR_CELDA` (Task 2), `Ciudad.almacen[recurso].agregar(monto) -> float` (autoload existente, `Ciudad.gd:125`).
- Produces: `VoxelWorld._retirar_bloque()` reembolsa automáticamente; ningún cambio de firma pública.

- [ ] **Step 1: Renombrar `"piso"`→`"hierba"` y `"ventana"`→`"vidrio"`, quitar `"pared"` de `TIPOS_ESTRUCTURA`**

En `godot/scripts/VoxelWorld.gd`:
- Línea 88: `"pared", "puerta_inferior", "puerta_superior", "ventana",` → `"tierra_compactada", "bloque_madera", "bloque_piedra", "estructura_hierro", "puerta_inferior", "puerta_superior", "vidrio",`
- Línea 102: `const MATERIAL_REAL := {"piso": "tierra"}` → `const MATERIAL_REAL := {"hierba": "tierra"}`
- Línea 113: `"ventana": Color(...)` → `"vidrio": Color(0.5, 1.0, 0.2, 0.6),`
- Línea 150: `const TIPOS_TRANSLUCIDOS: Array[String] = ["agua", "ventana"]` → `["agua", "vidrio"]`
- Líneas 347 y 425: `if tipo == "ventana":` → `if tipo == "vidrio":`
- Línea 617: `colocar_bloque(Vector3i(x, altura, z), "piso")` → `colocar_bloque(Vector3i(x, altura, z), "hierba")`
- Línea 1418-1419: `["piso"],` → `["hierba"],`; `["pared", "puerta_inferior", "puerta_superior", "ventana"],` → `["tierra_compactada", "bloque_madera", "bloque_piedra", "estructura_hierro", "puerta_inferior", "puerta_superior", "vidrio"],`
- Actualiza los comentarios de las líneas 80-84, 92-100, 325-343, 504, 563, 1213-1254 cambiando `"pared"`→los 4 materiales (o "un material de muro"), `"piso"`→`"hierba"`, `"ventana"`→`"vidrio"` donde el texto lo mencione (son prosa, no afectan comportamiento, pero deben quedar consistentes con el código).

- [ ] **Step 2: Escribir las pruebas de reembolso (failing primero)**

Agrega al final de `ejecutar_pruebas()` en `godot/scripts/ExtraccionTest.gd`:

```gdscript
	print("\n=== TEST N: colocar un bloque con costo lo descuenta del almacén ===")
	var mundo_costo: Node = _mundo_nuevo()
	Ciudad.almacen["piedra"].cantidad = 5.0
	assert(mundo_costo.colocar_bloque(Vector3i(0, 0, 0), "bloque_piedra", true))
	assert(Ciudad.almacen["piedra"].consumir(5.0), "el bloque ya descontó las 5 de piedra: no debería quedar más que eso")
	Ciudad.almacen["piedra"].agregar(5.0)  # deja el almacén como estaba para las siguientes pruebas

	print("\n=== TEST N+1: volver a minar un bloque colocado reembolsa exactamente su costo ===")
	Ciudad.almacen["piedra"].cantidad = 0.0
	mundo_costo.colocar_bloque(Vector3i(1, 0, 0), "bloque_piedra", true)
	Ciudad.almacen["piedra"].cantidad = 0.0  # el colocar_bloque de la prueba no cobra: solo VoxelWorld reembolsa
	mundo_costo.minar_bloque(Vector3i(1, 0, 0))
	assert(is_equal_approx(Ciudad.almacen["piedra"].cantidad, 5.0), "reembolsa 5 piedra")

	print("\n=== TEST N+2: minar terreno natural (hierba) no reembolsa nada ===")
	Ciudad.almacen["tierra"].cantidad = 0.0
	mundo_costo.colocar_bloque(Vector3i(2, 0, 0), "hierba")  # por_jugador=false: terreno natural
	mundo_costo.minar_bloque(Vector3i(2, 0, 0))
	assert(mundo_costo.obtener_tipo(Vector3i(2, 0, 0)) == "", "se minó")
	assert(Ciudad.almacen["tierra"].cantidad == 0.0, "hierba natural no reembolsa: no pasa por COSTO_POR_CELDA")

	print("\n=== TEST N+3: minar una puerta por un extremo reembolsa las DOS celdas ===")
	Ciudad.almacen["madera"].cantidad = 0.0
	mundo_costo.colocar_puerta(Vector3i(3, 0, 0))
	mundo_costo.minar_bloque(Vector3i(3, 0, 0))  # mina solo la mitad inferior
	assert(is_equal_approx(Ciudad.almacen["madera"].cantidad, 2.0), "reembolsa 1 + 1 = 2 madera (inferior + superior)")
```

- [ ] **Step 3: Correr y confirmar que fallan** (el reembolso todavía no existe)

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/ExtraccionTest.tscn > /tmp/extraccion_antes.txt 2>&1`
Expected: el proceso termina por un `assert()` fallido en el TEST N+1 (el almacén sigue en 0, no en 5).

- [ ] **Step 4: Implementar el reembolso en `_retirar_bloque()`**

Modifica `godot/scripts/VoxelWorld.gd:776-799` (`_retirar_bloque`):

```gdscript
func _retirar_bloque(celda: Vector3i) -> void:
	var tipo_anterior: String = obtener_tipo(celda)
	if pareja.has(celda):
		var otra: Vector3i = pareja[celda]
		var tipo_otra: String = obtener_tipo(otra)
		set_cell_item(otra, GridMap.INVALID_CELL_ITEM)
		_reembolsar_si_corresponde(otra, tipo_otra)
		colocado_por_jugador.erase(otra)
		pareja.erase(otra)
		pareja.erase(celda)
		if TIPOS_PUERTA.has(tipo_otra):
			puerta_cambiada.emit(otra)
	_reembolsar_si_corresponde(celda, tipo_anterior)
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	if TIPOS_PUERTA.has(tipo_anterior):
		puerta_cambiada.emit(celda)
	if TIPOS_TRANSLUCIDOS.has(tipo_anterior):
		bloque_translucido_cambiado.emit(celda)
	var vecinos_agua: Array[Vector3i] = []
	for delta in VECINOS_3D:
		var vecino: Vector3i = celda + delta
		if obtener_tipo(vecino) == "agua":
			vecinos_agua.append(vecino)
	if not vecinos_agua.is_empty():
		_escurrir_agua_desde(vecinos_agua)


## Reembolsa a Ciudad.almacen el costo de "tipo" (NiveladorTerreno.
## COSTO_POR_CELDA, por celda individual, no la clave "puerta"/"cama" de
## acción completa) si "celda" fue colocada por el jugador. Terreno natural
## (nunca colocado_por_jugador) y tipos sin costo (p.ej. "hierba") no
## reembolsan nada.
func _reembolsar_si_corresponde(celda: Vector3i, tipo: String) -> void:
	if not colocado_por_jugador.get(celda, false):
		return
	var costo: Dictionary = NiveladorTerreno.COSTO_POR_CELDA.get(tipo, {})
	for recurso in costo:
		Ciudad.almacen[recurso].agregar(costo[recurso])
```

Nota: `NiveladorTerreno` es un `RefCounted` sin autoload — agrega `const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")` junto a los demás `preload`/`const` del principio de `VoxelWorld.gd` si no existe ya.

- [ ] **Step 5: Correr las pruebas de nuevo y confirmar que pasan**

Run: mismo comando del Step 3.
Expected: sin ningún `assert()` fallido, termina con `quit()` limpio (o el proceso corre hasta el final sin abortar).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/ExtraccionTest.gd
git commit -m "feat: reembolsar el costo de un bloque colocado al volver a minarlo"
```

---

### Task 4: Generalizar "pared" a familia de materiales (`BlueprintValidator.gd`)

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd:16-36` (constantes), `:107` (chequeo de esquina), `:499-509` (`estructura_a_blueprint`, remapeo de `puerta_superior`), `:647-666` (fusión de capas)
- Modify: `godot/scripts/BlueprintValidatorTest.gd` (llamadas a `colocar_bloque(..., "pared")`/`"ventana"`/`"piso"`, ver líneas 262, 499, 532, 556-557, 565-569, 644-648, 993, 1150, 1155, 1703, 1721-1733)

**Interfaces:**
- Consumes: `VoxelWorld.TIPOS_ESTRUCTURA` (Task 3) como referencia conceptual (no se importa directamente: `BlueprintValidator` mantiene su propia lista, igual que hoy).
- Produces: `BlueprintValidator.TIPOS_MURO_GENERICO: Array[String]` — nueva constante que Task 5 (opcionalmente) puede reutilizar para validar que el material de una plantilla es válido.

- [ ] **Step 1: Nueva constante y generalización de las 3 constantes existentes**

Reemplaza `godot/scripts/BlueprintValidator.gd:16-36`:

```gdscript
const ZONAS_VALIDAS := ["residencial_investigacion", "fabricacion_militar", "periferia"]
## Los 4 materiales de muro reales son intercambiables entre sí a efectos de
## Blueprint: cualquiera de ellos puede aparecer en cualquier celda de muro
## de una plantilla, igual que antes solo existía "pared" (ver docs/
## superpowers/specs/2026-09-29-costo-colocacion-bloques-design.md, Sección 4).
const TIPOS_MURO_GENERICO := ["tierra_compactada", "bloque_madera", "bloque_piedra", "estructura_hierro"]
const TIPOS_CELDA_SOLIDA := TIPOS_MURO_GENERICO + ["puerta", "vidrio"]
## Bloques "estructurales" (material de construcción: muros, puertas,
## vidrio) vs. mobiliario (cama, baúl) vs. relleno de terreno ("hierba").
## "hierba" es la superficie natural del terreno (ver VoxelWorld.MATERIAL_REAL
## y _generar_terreno()/nivelación), nunca un material de construcción.
## Coincide, por tanto, con TIPOS_CELDA_SOLIDA (regla de perímetro 2D).
const TIPOS_ESTRUCTURALES := TIPOS_MURO_GENERICO + ["puerta", "vidrio"]
## Relleno genérico sin significado especial a nivel de Blueprint: una celda
## con CUALQUIERA de estos tipos, heredada de la plantilla de suelo/techo
## (ver estructura_a_blueprint), siempre puede ser sobrescrita por el bloque
## real de una capa de muro (aunque ese bloque real sea también un material
## de muro genérico) — solo un tipo ESPECIAL (puerta/vidrio/cama/baúl) ya
## asignado se protege de ser pisado por un material de muro posterior.
## "hierba" ya no puede aparecer aquí (nunca es estructural), pero
## VoxelWorld.detectar_estructura() ya la excluye del flood-fill, así que
## este caso ni siquiera llega a estructura_a_blueprint().
const TIPOS_RELLENO_GENERICO := TIPOS_MURO_GENERICO
```

- [ ] **Step 2: Chequeo de esquina (línea ~107)**

Cambia:
```gdscript
			if es_perpendicular and tipo != "pared":
```
por:
```gdscript
			if es_perpendicular and not TIPOS_MURO_GENERICO.has(tipo):
```

- [ ] **Step 3: Remapeo de `puerta_superior` en `estructura_a_blueprint()` (línea ~499-509)**

El remapeo hoy fija literalmente `"pared"`; como cualquier material de muro sirve para "tapar el hueco fantasma" de la misma manera, usa el primero de la familia como relleno neutro:

```gdscript
static func estructura_a_blueprint(celdas: Dictionary) -> Dictionary:
	# "puerta_superior" se remapea a un material de muro genérico (nunca se
	# omite): físicamente tapa el muro, y si se omitiera por completo dejaría
	# un "agujero fantasma" en su capa de Y — si esa capa fuera además el
	# techo del edificio, _es_losa_solida() la rechazaría por esa única
	# celda faltante, aunque el techo esté completo. Cualquier material de
	# muro nunca compite con "puerta" (la mitad inferior) gracias a la regla
	# de fusión que no pisa un tipo especial ya asignado con un material de
	# muro de otra capa (ver más abajo).
	var celdas_relevantes: Dictionary = {}
	for pos in celdas.keys():
		celdas_relevantes[pos] = TIPOS_MURO_GENERICO[0] if celdas[pos] == "puerta_superior" else celdas[pos]
	if celdas_relevantes.is_empty():
		return {}
```

(el resto de la función, tras la línea 510, no cambia).

- [ ] **Step 4: Fusión de capas (línea ~647-666)**

Cambia el comentario y la condición:
```gdscript
			for clave in celdas_por_capa[indices_capa[j]]:
				var tipo_capa = celdas_por_capa[indices_capa[j]][clave]
				if not plantilla.has(clave) or TIPOS_RELLENO_GENERICO.has(plantilla[clave]) or not TIPOS_MURO_GENERICO.has(tipo_capa):
					plantilla[clave] = tipo_capa
```

(antes decía `tipo_capa != "pared"`; ahora dos materiales de muro DISTINTOS en la misma celda entre capas siguen sin competir entre sí — gana el último, igual que antes dos `"pared"` no competían — y solo un tipo especial sigue ganando siempre).

- [ ] **Step 5: Actualizar `BlueprintValidatorTest.gd`**

Run: `grep -n '"pared"\|"ventana"\|"piso"' godot/scripts/BlueprintValidatorTest.gd`

Para cada línea: los usos de `"pared"` como "cualquier bloque estructural genérico de prueba" → `"bloque_piedra"`; `"ventana"` → `"vidrio"`; `"piso"` → si la prueba pretendía "relleno de terreno natural" usa `"hierba"`, si pretendía "el jugador rellenó con un bloque de tierra a mano" usa `"tierra"` (revisa el comentario de cada caso para elegir). Presta atención especial a:
- Línea ~1721-1733 (`TEST 52`): la lista `["madera", "follaje", "pared", "fantasma", "agua"]` pasa a `["madera", "follaje", "bloque_piedra", "fantasma", "agua"]`.
- Línea ~262-264 (comentario sobre `colocado_por_jugador`): actualizar el texto si menciona `"pared"` explícitamente.

- [ ] **Step 6: Correr las pruebas**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/BlueprintsTest.tscn > /tmp/blueprints.txt 2>&1` (y cualquier otra escena que cargue `BlueprintValidatorTest.gd`, revisa `godot/scenes/*.tscn` con `grep -l BlueprintValidatorTest`).
Expected: sin `assert()` fallido.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: generalizar BlueprintValidator de un único pared a la familia de materiales de muro"
```

---

### Task 5: Material fijo por tipo de puesto (`PlantillasPuesto.gd`)

**Files:**
- Modify: `godot/scripts/PlantillasPuesto.gd:16-45`
- Modify: `godot/scripts/PlantillasPuestoTest.gd`, `godot/scripts/PuestosPrevisualizacionTest.gd`, `godot/scripts/RecoleccionTest.gd` (donde referencien `"pared"`/`"ventana"` de una plantilla)

**Interfaces:**
- Consumes: nombres de material de Task 1 (`tierra_compactada`, `bloque_madera`, `bloque_piedra`) y `vidrio` de Task 3.
- Produces: `PlantillasPuesto.celdas()`/`en_mundo()` devuelven el material real de cada puesto en vez de `"pared"`; sin cambio de firma.

- [ ] **Step 1: Actualizar `BLOQUES` y `PLANTILLAS`**

Reemplaza `godot/scripts/PlantillasPuesto.gd:16-45`:

```gdscript
## Carácter -> bloque fijo (no depende del puesto). "." (y cualquier otro
## carácter) es vacío. "#" es especial: se resuelve con el material propio
## de cada plantilla (ver MATERIAL más abajo), no con un tipo fijo.
const BLOQUES := {
	"V": "vidrio", "B": "baul",
	"d": "puerta_inferior", "D": "puerta_superior",
}

## Material de muro de cada tipo de puesto (era de prehistoria: cada uno usa
## lo que tenga más a mano según su oficio — ver docs/superpowers/specs/
## 2026-09-29-costo-colocacion-bloques-design.md, Sección 5).
const MATERIAL := {
	"mina": "tierra_compactada",
	"caza_recoleccion": "bloque_madera",
	"maderero": "bloque_madera",
	"pesca_frutos_mar": "bloque_piedra",
}

const PLANTILLAS := {
	"mina": {"capas": [
		["##d##", "#...#", "#..B#", "#...#", "#####"],
		["##D##", "#...#", "#...#", "#...#", "#####"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
	"caza_recoleccion": {"capas": [
		["##d#", "#..#", "#.B#", "####"],
		["##D#", "V..V", "#..#", "##V#"],
		["####", "####", "####", "####"],
	]},
	"maderero": {"capas": [
		["#d#", "#.#", "#B#", "###"],
		["#D#", "#.#", "#.#", "###"],
		["###", "###", "###", "###"],
	]},
	# Edificio en las filas 0-3 (interior libre en las filas 1-2, con el baúl al fondo)
	# y muelle (cubierta de pared) en las filas 4-5; el agua queda del lado de z alto.
	# "agua_ref" (x, z) es una celda del extremo de agua.
	"pesca_frutos_mar": {"capas": [
		["#d##", "#..#", "#.B#", "####", "####", "####"],
		["#D##", "V..V", "#..#", "####", "....", "...."],
		["####", "####", "####", "####", "....", "...."],
	], "agua_ref": Vector2i(0, 5)},
}
```

- [ ] **Step 2: Resolver `"#"` con el material real en `celdas()`**

Modifica `celdas()` (hoy en la línea 77-88):

```gdscript
static func celdas(tipo: String, giros: int) -> Dictionary:
	var d := dimensiones(tipo)
	var resultado := {}
	var capas: Array = PLANTILLAS[tipo]["capas"]
	var material_muro: String = MATERIAL[tipo]
	for y in range(capas.size()):
		var filas: Array = capas[y]
		for z in range(filas.size()):
			var fila: String = filas[z]
			for x in range(fila.length()):
				var caracter: String = fila[x]
				if caracter == "#":
					resultado[_girar(Vector3i(x, y, z), d.x, d.y, giros)] = material_muro
				elif BLOQUES.has(caracter):
					resultado[_girar(Vector3i(x, y, z), d.x, d.y, giros)] = BLOQUES[caracter]
	return resultado
```

- [ ] **Step 3: Actualizar `_buscar()` si depende de `BLOQUES["#"]`**

Revisa `_buscar(tipo, bloque)` (línea 102-108): sigue funcionando sin cambios porque busca por el VALOR ya resuelto (`base[c] == bloque`), y quien llama a `_buscar(tipo, "puerta_inferior")` (en `celda_de_servicio`/`fachada`) sigue usando un tipo fijo del `BLOQUES` dict, no `"#"`. No hace falta tocarlo — solo confírmalo leyendo las líneas 101-116 tras el Step 2.

- [ ] **Step 4: Actualizar las pruebas**

Run: `grep -rn '"pared"\|"ventana"' godot/scripts/PlantillasPuestoTest.gd godot/scripts/PuestosPrevisualizacionTest.gd godot/scripts/RecoleccionTest.gd`

Para cada coincidencia que espera el material de un puesto concreto, usa la tabla de `MATERIAL` del Step 1 (p.ej. una prueba de `"mina"` que esperaba `"pared"` ahora espera `"tierra_compactada"`; `"ventana"` siempre pasa a `"vidrio"` sin importar el puesto).

- [ ] **Step 5: Correr las pruebas**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/PlantillasPuestoTest.tscn > /tmp/plantillas.txt 2>&1` (y `PuestosPrevisualizacionTest.tscn`, `RecoleccionTest.tscn`).
Expected: sin `assert()` fallido.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/PlantillasPuesto.gd godot/scripts/PlantillasPuestoTest.gd godot/scripts/PuestosPrevisualizacionTest.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: cada tipo de puesto construye con su material fijo (era prehistórica)"
```

---

### Task 6: Cobro al colocar desde la hotbar (`Player.gd`)

**Files:**
- Modify: `godot/scripts/Player.gd:83` (`tipos_disponibles`), `:771-806` (`_colocar()`)
- Test: manual (ver Task 8 para la escena `Test.tscn` completa) — `Player.gd` no tiene pruebas automatizadas aisladas hoy (usa `PlayerNatacionTest`/`PlayerOxigenoTest` para otros aspectos, ninguno cubre colocación); esta task se verifica jugando, más las pruebas indirectas de `ExtraccionTest`/`BlueprintValidatorTest` ya escritas en tasks previas.

**Interfaces:**
- Consumes: `NiveladorTerreno.COSTO_POR_CELDA` (Task 2), `Ciudad.almacen[recurso].consumir(monto) -> bool` y `.agregar(monto) -> float` (autoload existente).
- Produces: `Player.tipos_disponibles` con 9 entradas; sin cambio de firma pública.

- [ ] **Step 1: Nueva lista de tipos disponibles**

Cambia `godot/scripts/Player.gd:83`:
```gdscript
var tipos_disponibles := ["tierra", "tierra_compactada", "bloque_madera", "bloque_piedra", "estructura_hierro", "vidrio", "puerta", "cama", "baul"]
```

- [ ] **Step 2: Cobrar antes de colocar**

Reemplaza `godot/scripts/Player.gd:771-806` (`_colocar()`):

```gdscript
func _colocar() -> void:
	if not raycast.is_colliding() or mundo == null or _colocacion_bloqueada_tras_completar:
		return
	var celda := _celda_impactada()
	var resultado: Dictionary = mundo.surtir_construccion(celda)
	if not resultado.is_empty():
		if resultado.get("bloqueada", false):
			_avisar_colocacion_rechazada("Hay alguien dentro del sitio de la obra %d: deben salir antes de iniciarla." % resultado["id"])
		elif resultado.get("completa", false):
			_completar_construccion(resultado["metadata"])
			_colocacion_bloqueada_tras_completar = true
		return
	var normal := raycast.get_collision_normal()
	var celda_destino := celda + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	var tipo: String = tipos_disponibles[tipo_seleccionado]
	var segunda_celda := celda_destino
	if tipo == "puerta":
		segunda_celda = celda_destino + Vector3i(0, 1, 0)
	elif tipo == "cama":
		segunda_celda = celda_destino + _direccion_cardinal()
	if _celda_ocupada_por_jugador(celda_destino) or _celda_ocupada_por_jugador(segunda_celda):
		_avisar_colocacion_rechazada("No se puede colocar un bloque donde está parado el jugador.")
		return
	if not _cobrar_colocacion(tipo):
		return
	var colocado: bool
	if tipo == "puerta":
		colocado = mundo.colocar_puerta(celda_destino)
	elif tipo == "cama":
		colocado = mundo.colocar_cama(celda_destino, _direccion_cardinal())
	else:
		colocado = mundo.colocar_bloque(celda_destino, tipo, true)
	if not colocado:
		_reembolsar_colocacion(tipo)
		_avisar_colocacion_rechazada("No hay espacio suficiente para colocar: %s" % tipo)


## Descuenta de Ciudad.almacen el costo de "tipo" (NiveladorTerrenoScript.
## COSTO_POR_CELDA); true si se cobró (o si "tipo" no tiene costo definido).
## false y sin cobrar nada si falta stock — usa el mismo recurso para
## avisar cuál falta.
func _cobrar_colocacion(tipo: String) -> bool:
	var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(tipo, {})
	for recurso in costo:
		if not Ciudad.almacen[recurso].consumir(costo[recurso]):
			_avisar_colocacion_rechazada("No hay suficiente %s para colocar: %s" % [recurso, tipo])
			return false
	return true


## Simétrico a _cobrar_colocacion(): usado cuando el cobro tuvo éxito pero
## colocar_puerta()/colocar_cama()/colocar_bloque() igual falló (sitio
## ocupado) — evita perder el recurso ya descontado.
func _reembolsar_colocacion(tipo: String) -> void:
	var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(tipo, {})
	for recurso in costo:
		Ciudad.almacen[recurso].agregar(costo[recurso])
```

Agrega el preload junto a los demás `const ...Script = preload(...)` del principio de `Player.gd` (busca el patrón con `grep -n "^const.*Script = preload" godot/scripts/Player.gd` para ubicarlo):
```gdscript
const NiveladorTerrenoScript = preload("res://scripts/NiveladorTerreno.gd")
```

- [ ] **Step 3: Verificación manual**

Abre `godot/scenes/Test.tscn` o la escena principal en el editor, juega, y confirma a mano: colocar `tierra_compactada`/`bloque_madera`/`bloque_piedra`/`estructura_hierro`/`vidrio` con stock suficiente descuenta del almacén (ábrelo con la ventana de Almacén); sin stock suficiente, rechaza con la notificación y no descuenta; colocar puerta/cama descuenta 2 madera; colocar baúl descuenta 1 madera.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/Player.gd
git commit -m "feat: cobrar el recurso crudo al colocar un bloque desde la hotbar"
```

---

### Task 7: Cantidad visible en la hotbar (`Hotbar.gd` + `HUD.gd`)

**Files:**
- Modify: `godot/scripts/Hotbar.gd:10-17` (`NOMBRES`)
- Modify: `godot/scripts/HUD.gd` (agrega la función de refresco) y su punto de llamada en `Player.gd` o `HUD.gd` (el que ya refresca la ventana de Almacén "en vivo" — localízalo con `grep -n "VentanaAlmacen\|_refrescar\|_process" godot/scripts/HUD.gd`)
- Test: `godot/scripts/HUDTest.gd` (agrega un caso)

**Interfaces:**
- Consumes: `Hotbar.set_cantidad(indice: int, cantidad: int) -> void` (ya existe), `Player.tipos_disponibles` (Task 6), `NiveladorTerreno.COSTO_POR_CELDA` (Task 2), `Ciudad.almacen`.
- Produces: `HUD` (o quien corresponda tras localizarlo) expone `actualizar_cantidades_hotbar(tipos: Array) -> void`, llamado cada vez que cambia el almacén.

- [ ] **Step 1: Nombres nuevos**

Reemplaza `godot/scripts/Hotbar.gd:10-17`:
```gdscript
const NOMBRES := {
	"tierra": "Tierra",
	"tierra_compactada": "Tierra compactada",
	"bloque_madera": "Bloque de madera",
	"bloque_piedra": "Bloque de piedra",
	"estructura_hierro": "Estructura de hierro",
	"vidrio": "Vidrio",
	"puerta": "Puerta",
	"cama": "Cama",
	"baul": "Baúl",
}
```

- [ ] **Step 2: Localizar dónde vive el hotbar dentro de `HUD.gd` y agregar el refresco**

Run: `grep -n "Hotbar\|hotbar" godot/scripts/HUD.gd`

Agrega una función (junto al resto de funciones públicas de refresco que ya existan, mismo patrón que la ventana de Almacén):
```gdscript
## Actualiza la casilla de cada tipo con floor(stock del recurso / costo por
## bloque); oculta el número (cantidad -1) en los tipos sin costo definido
## (hoy ninguno, pero deja el hueco por si se agrega uno sin costo).
func actualizar_cantidades_hotbar(tipos: Array) -> void:
	for i in range(tipos.size()):
		var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(tipos[i], {})
		if costo.is_empty():
			hotbar.set_cantidad(i, -1)
			continue
		var minimo := 999999
		for recurso in costo:
			var disponible: int = int(Ciudad.almacen[recurso].cantidad / costo[recurso])
			minimo = mini(minimo, disponible)
		hotbar.set_cantidad(i, minimo)
```

(usa el nombre real del nodo/variable del hotbar dentro de `HUD.gd`, que el `grep` del Step 2 revela — probablemente `hotbar` o `$Hotbar`; agrega `const NiveladorTerrenoScript = preload("res://scripts/NiveladorTerreno.gd")` junto a los demás `preload` si falta).

- [ ] **Step 3: Llamarla cuando cambia el almacén**

Busca dónde `HUD.gd`/`Player.gd` ya refresca la ventana de Almacén en vivo (`grep -n "func _process\|VentanaAlmacen" godot/scripts/HUD.gd godot/scripts/Player.gd`) y agrega `hud.actualizar_cantidades_hotbar(tipos_disponibles)` en el mismo punto (mismo tick que ya usa esa ventana, para no crear un segundo timer).

- [ ] **Step 4: Prueba**

Agrega a `godot/scripts/HUDTest.gd` (junto a los demás casos de `Hotbar`):
```gdscript
	print("\n=== TEST N: actualizar_cantidades_hotbar muestra stock ÷ costo ===")
	Ciudad.almacen["piedra"].cantidad = 12.0
	hud_prueba.actualizar_cantidades_hotbar(["bloque_piedra"])
	assert(hud_prueba.hotbar.cantidad_visible(0))
```
(ajusta `hud_prueba`/`hotbar` al nombre real de las variables ya usadas en ese archivo — revísalo antes de escribir la prueba).

- [ ] **Step 5: Correr las pruebas**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot godot/scenes/HUDTest.tscn > /tmp/hud.txt 2>&1`
Expected: sin `assert()` fallido.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Hotbar.gd godot/scripts/HUD.gd godot/scripts/HUDTest.gd
git commit -m "feat: mostrar en la hotbar cuántos bloques se pueden colocar de cada tipo"
```

---

### Task 8: Barrido de referencias sueltas y verificación completa

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd:1849,2012`, `godot/scripts/TranslucidosRenderer.gd:4,11,127`, `godot/scripts/Recoleccion.gd:39,57`, `godot/scripts/ZonaOverlay.gd:198`
- Modify: cualquier prueba restante que el barrido descubra

**Interfaces:**
- Consumes: nada nuevo.
- Produces: nada nuevo (limpieza final).

- [ ] **Step 1: `CamaraCenital.gd`**

Línea 2012 (pilotes del muelle de pesca): `var bloque: String = "pared" if es_pilote else "tierra"` → `var bloque: String = "bloque_piedra" if es_pilote else "tierra"`. Línea 1849 (comentario): cambia `"pared"` por `"bloque_piedra"`.

- [ ] **Step 2: `TranslucidosRenderer.gd`**

Línea 127: `_material_por_tipo["ventana"] = MATERIAL_VENTANA` → `_material_por_tipo["vidrio"] = MATERIAL_VENTANA` (deja el nombre de la constante `MATERIAL_VENTANA` sin tocar: es solo un identificador interno). Líneas 4 y 11 (comentarios): `"ventana"` → `"vidrio"`.

- [ ] **Step 3: `Recoleccion.gd` y `ZonaOverlay.gd`**

Son solo comentarios (líneas 39, 57 y 198 respectivamente): actualiza `"pared"`/`"ventana"`/`"piso"` a los nombres nuevos donde aparezcan.

- [ ] **Step 4: Barrido final de verificación**

Run: `grep -rn '"pared"\|"piso"\b' godot/scripts/*.gd | grep -v Test`
Expected: sin resultados (todo lo no-test ya quedó renombrado). Si aparece algo, revísalo caso por caso (puede ser una prueba mal clasificada por el filtro, o algo que las tasks anteriores pasaron por alto).

Run: `grep -rln '"ventana"' godot/scripts/*.gd | grep -v Test`
Expected: sin resultados.

- [ ] **Step 5: Correr TODA la suite de pruebas afectada**

Por cada escena en esta lista, ábrela en Godot 4.7 (editor o headless) y confirma que no salta ningún `assert()`: `Test.tscn`, `BlueprintsTest.tscn`, `ExtraccionTest.tscn`, `NiveladorTerrenoTest.tscn`, `PlantillasPuestoTest.tscn`, `PuestosPrevisualizacionTest.tscn`, `RecoleccionTest.tscn`, `HUDTest.tscn`, `TranslucidosRendererTest.tscn`, `ConstruccionTest.tscn`, `FantasmasPermeablesTest.tscn`, `PuertasTest.tscn`, `ColonosTest.tscn`, `BuscadorRutasTest.tscn` (esta lista sale de los `grep` de "pared"/"piso"/"ventana" en archivos `*Test.gd` hechos al inicio del plan — cualquiera que use esos literales pudo verse afectado).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CamaraCenital.gd godot/scripts/TranslucidosRenderer.gd godot/scripts/Recoleccion.gd godot/scripts/ZonaOverlay.gd
git commit -m "docs: renombrar comentarios y referencias sueltas a los nuevos nombres de bloque"
```

---

### Task 9: Documentación

**Files:**
- Modify: `docs/Fichas_Consumo_Produccion.md` (sección "Extracción: bloques minables..." y la nota de "Pendientes")
- Modify: `docs/Pendientes y próximos pasos.md` (punto 4)

**Interfaces:** ninguna (solo texto).

- [ ] **Step 1: Actualizar la tabla de extracción**

En `docs/Fichas_Consumo_Produccion.md`, sección "Extracción: bloques minables, unidades de recurso y bloques colocables": cambia el estado de cada fila de "Extracción implementada; construcción propuesta" a "**Implementado**" con los valores reales de la Sección 2 del spec (tierra=1, piedra=5 por `bloque_piedra`, madera=5 por `bloque_madera`, hierro=5 por `estructura_hierro`), y agrega una fila para `vidrio` (tierra×1). Anota que `bloque_acero` queda pendiente (sin fuente real de acero).

- [ ] **Step 2: Marcar resuelto el pendiente de reembolso**

En la sección "Pendientes" del mismo archivo, marca como resuelta la línea "Definir el costo en unidades de recurso del bloque de madera colocable... Implica también programar el reembolso al volver a minar un bloque colocado" (tacharla con `~~...~~` y una nota de fecha, mismo estilo que usa `docs/Pendientes y próximos pasos.md` en su sección "Hecho").

- [ ] **Step 3: Actualizar el punto 4 de Pendientes**

En `docs/Pendientes y próximos pasos.md`, punto 4 ("PoC 5, sub-proyecto 2C — transformación"): marca la parte de costo/reembolso de colocación como hecha (misma convención `~~texto~~ — ✅ hecho (fecha)` que usan los otros puntos) y deja explícito que sigue pendiente la segunda pieza (refinerías reales colocables: aserradero, carbonera, siderúrgica, refinería de tierras raras).

- [ ] **Step 4: Commit**

```bash
git add "docs/Fichas_Consumo_Produccion.md" "docs/Pendientes y próximos pasos.md"
git commit -m "docs: marcar hecho el costo de colocación y reembolso de bloques (2C, parte 1)"
```

---

## Self-Review

**Cobertura del spec:** Sección 1 (alcance) → Tasks 1-7 cubren todo lo "dentro"; lo "fuera" (bloque_acero, selector de material por blueprint, refinerías) queda explícitamente sin tarea, por diseño. Sección 2 (costos) → Task 2. Sección 3 (renombres) → Tasks 1, 3, 8. Sección 4 (generalización) → Task 4. Sección 5 (plantillas) → Task 5. Sección 6 (cobro/reembolso) → Tasks 3, 6. Sección 7 (HUD) → Task 7. Sección 8 (pruebas) → repartidas en cada task + Task 8 Step 5. Sección 9 (documentación) → Task 9.

**Placeholders:** ninguno pendiente — cada step trae código real o un `grep`/comando concreto a ejecutar.

**Consistencia de tipos:** `COSTO_POR_CELDA` (Task 2) es la única fuente; Task 3 (`_reembolsar_si_corresponde`), Task 6 (`_cobrar_colocacion`/`_reembolsar_colocacion`) y Task 7 (`actualizar_cantidades_hotbar`) la consumen con la misma forma `{recurso: cantidad}`. `Player.tipos_disponibles` (Task 6) coincide exactamente con las claves de `Hotbar.NOMBRES` (Task 7).

**Review Focus:** las 5 líneas de la sección de arriba tienen su prueba: borde de stock exacto (Task 3 Step 2, reutilizable en Task 6 Step 3 manual), terreno natural no reembolsa (Task 3 TEST N+2), puerta/cama reembolsan las 2 celdas (Task 3 TEST N+3), colocación fallida no pierde recurso (Task 6 `_reembolsar_colocacion`, verificado a mano en Step 3), plantillas de prueba actualizadas (Task 5 Step 4).
