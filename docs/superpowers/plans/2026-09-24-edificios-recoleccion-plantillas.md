# Edificios de recolección jugables reales (plantillas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que un puesto de recolección sea un edificio de bloques con forma propia, puerta de servicio y depósito físico, que se desactive al empezar a deconstruirse y que despida a sus recolectores cuando se agota.

**Architecture:** Un script de datos sin autoload (`PlantillasPuesto.gd`) define, por tipo de puesto, capas de bloques en texto con rotación de 4 giros, celda de servicio y celda del depósito. `CamaraCenital` estampa la plantilla en vez del slab marcador y la registra con `VoxelWorld.registrar_edificio_completo()` (mismo camino que un residencial, así se deconstruye bloque a bloque). `Economia` gana `activo`/`agotado`, la celda de servicio y el depósito; `Colonos` usa una zona de servicio junto a la puerta; `Player` engancha desactivar/reactivar/eliminar y la tecla `E` sobre el baúl.

**Tech Stack:** Godot 4.7 (GDScript), pruebas como escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-24-edificios-recoleccion-plantillas-design.md`.

## Global Constraints

- GDScript con **tabulaciones**. Documentación, comentarios, mensajes del juego y pruebas en **español**.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python. No hacer `git add` de `*.gd.uid` sueltos durante las tareas; los `.uid` de los scripts nuevos se commitean juntos en el commit `chore` del final de la Tarea 6.
- En cada commit, `git add` solo los archivos del paso. **No tocar `docs/Pendientes y próximos pasos.md` salvo en la Tarea 6**, y solo si `git status` no muestra cambios previos del usuario en ese archivo (si los hay, avisar y dejarlo sin commitear).
- Trabajar en la rama `feat/edificios-recoleccion-plantillas` (ya creada); no commitear a `main`.
- No mezclar PoC ni reformatear archivos ajenos al objetivo. Reutilizar código existente; sin abstracciones especulativas.
- Verificación (CLAUDE.md): `godot/scenes/Test.tscn` con Godot 4.7 más las escenas `*Test.tscn` afectadas (`PlantillasPuestoTest`, `EconomiaTest`, `ColonosTest`). Solo esas.
- Comando de pruebas (desde la raíz del repo; en cada tarea se reutiliza):
  ```bash
  GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
  "$GD" --headless --path godot res://scenes/<Escena>.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
  ```
- **Huellas base (ancho en X × alto en Z):** mina 5×5, caza/recolección 4×4, maderero 3×4, pesca 4×6 (`Recoleccion.ANCHO_HUELLA_*`/`ALTO_HUELLA_*`).
- **Convención de plantilla:** la puerta (`puerta_inferior` en la capa 0 y `puerta_superior` en la capa 1) está en la fila `z = 0` y mira a −Z; la capa 0 se coloca en `objetivo + 1`. Giro horario de 90°: `(x, z) → (alto − 1 − z, x)` (misma fórmula que `CamaraCenital._rotar_blueprint`).
- **Zona de servicio:** celdas transitables a distancia de Chebyshev ≤ `RADIO_SERVICIO := 2` de la celda de servicio, fuera de la huella. Una sola celda no basta: `Colonos.ocupadas` no admite dos colonos en la misma celda y un puesto tiene hasta 7 trabajadores.
- **Agotado** = todas las tasas del puesto valen 0 tras `recalcular_tasas()` (solo puestos con `entorno` no vacío y `mundo` inyectado).
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  ```

## Review Focus

Entradas o condiciones que la spec insinúa y ninguna tarea cubriría por sí sola; cada una tiene su prueba en la tarea indicada:

1. **Un acarreador con carga cuando se agota o se desactiva su puesto** debe terminar el viaje y entregar, no perder la carga ni quedarse atascado si el puesto desaparece entretanto (Tarea 3, TEST 28).
2. **Depósito con el inventario casi lleno:** solo pasa lo que cabe y el resto se queda en el almacén local; nada se pierde (Tarea 2, TEST 20).
3. **Deconstruir dos veces / reconstruir:** `desactivar_puesto` es idempotente y `reactivar_puesto` recalcula el agotamiento (si el recurso ya no está, el puesto reactivado queda agotado) (Tarea 2, TEST 19 y TEST 21; Tarea 1, TEST 8).
4. **Pesca girada este-oeste o norte-sur:** el edificio debe caer en el extremo de tierra para los 4 giros (Tarea 1, TEST 6).
5. **Puerta que da a un acantilado, al agua o a otro puesto:** la colocación se rechaza con mensaje antes de tocar el mundo (Tarea 4, verificación manual; la celda de servicio de los 4 giros queda fuera de la huella y adyacente a la puerta en la Tarea 1, TEST 3).
6. **Puestos sin celda de servicio** (los que registran las pruebas antiguas) siguen usando el anillo junto a la huella (Tarea 2, TEST 18; Tarea 3, las pruebas 18–25 existentes siguen pasando).

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `godot/scripts/PlantillasPuesto.gd` (nuevo) | Datos y funciones estáticas: capas por tipo, rotación, celdas en el mundo, celda de servicio, depósito, extremo de agua de la pesca |
| `godot/scripts/PlantillasPuestoTest.gd` + `godot/scenes/PlantillasPuestoTest.tscn` (nuevos) | Pruebas de plantillas y del ciclo deconstruir/completar sobre un `VoxelWorld` real |
| `godot/scripts/Economia.gd` | `activo`, `agotado`, `servicio`, `deposito`, señal `trabajadores_liberados`, desactivar/reactivar, depósito |
| `godot/scripts/Colonos.gd` | Zona de servicio, `retirar_al_entregar`, conexión con `trabajadores_liberados` |
| `godot/scripts/CamaraCenital.gd` | Rotación de 4 giros, validación y estampado de la plantilla, registro como edificio completo |
| `godot/scripts/Player.gd` | Desactivar/reactivar/eliminar por metadata, `E` sobre el baúl |
| `godot/scripts/PanelPuesto.gd` | Título y botones para «inactivo»/«agotado» |
| `godot/scripts/EconomiaTest.gd`, `godot/scripts/ColonosTest.gd` | Pruebas ampliadas |
| Documentos | `PoC_5/...Edificios de Recolección.md` (nuevo), GDD Sección 3, `docs/Pendientes y próximos pasos.md`, spec |

---

### Task 1: Plantillas de puesto (datos, rotación, ciclo deconstruir/completar)

**Files:**
- Create: `godot/scripts/PlantillasPuesto.gd`
- Create: `godot/scripts/PlantillasPuestoTest.gd`
- Create: `godot/scenes/PlantillasPuestoTest.tscn`

**Interfaces:**
- Consumes: `Recoleccion.ANCHO_HUELLA_*`/`ALTO_HUELLA_*` (autoload); `VoxelWorld` (`colocar_bloque`, `registrar_edificio_completo`, `reemparejar_construccion`, `procesar_deconstruccion`, `surtir_construccion`, `edificio_metadata`, `_id_por_tipo`, `obtener_tipo`, `minar_bloque`).
- Produces (todo `static`, en `PlantillasPuesto.gd`, cargado con `preload`):
  - `dimensiones(tipo: String) -> Vector2i` (ancho, alto de la base)
  - `altura(tipo: String) -> int` (número de capas)
  - `huella(tipo: String, giros: int) -> Vector2i` (ancho, alto tras girar)
  - `celdas(tipo: String, giros: int) -> Dictionary` (`Vector3i` local → nombre de bloque; `y = 0` es la capa 0)
  - `en_mundo(tipo: String, giros: int, esquina: Vector2i, y_base: int) -> Dictionary` (`Vector3i` del mundo → bloque)
  - `celda_de_servicio(tipo: String, giros: int) -> Vector2i` (local, fuera de la huella, frente a la puerta)
  - `celda_deposito(tipo: String, giros: int) -> Vector3i` (local, la del `baul`)
  - `indice_extremo_agua(giros: int) -> int` (0 o 1; solo `pesca_frutos_mar`)

- [ ] **Step 1: Crear la escena de prueba**

Archivo `godot/scenes/PlantillasPuestoTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/PlantillasPuestoTest.gd" id="1"]

[node name="PlantillasPuestoTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Escribir la prueba (fallará: `PlantillasPuesto.gd` no existe)**

Archivo `godot/scripts/PlantillasPuestoTest.gd`:

```gdscript
extends Node

## Pruebas de PlantillasPuesto.gd (datos y rotación) y del ciclo real de un
## puesto como edificio completo: estampar, deconstruir (el baúl sale primero,
## la obra guarda su metadata) y volver a completar, sobre un VoxelWorld real
## sin _ready() (mismo patrón que FantasmasPermeablesTest.gd).

const PlantillasPuesto = preload("res://scripts/PlantillasPuesto.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")

const TIPOS := ["mina", "caza_recoleccion", "maderero", "pesca_frutos_mar"]


func _ready() -> void:
	ejecutar_pruebas()


func _mundo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE
	mundo._indexar_biblioteca()
	return mundo


func _huella_esperada(tipo: String) -> Vector2i:
	match tipo:
		"mina":
			return Vector2i(Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
		"caza_recoleccion":
			return Vector2i(Recoleccion.ANCHO_HUELLA_CAZA_RECOLECCION, Recoleccion.ALTO_HUELLA_CAZA_RECOLECCION)
		"maderero":
			return Vector2i(Recoleccion.ANCHO_HUELLA_MADERERO, Recoleccion.ALTO_HUELLA_MADERERO)
	return Vector2i(Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR, Recoleccion.ALTO_HUELLA_PESCA_FRUTOS_MAR)


func _primera(celdas: Dictionary, bloque: String) -> Vector3i:
	for celda in celdas:
		if celdas[celda] == bloque:
			return celda
	assert(false, "no hay un bloque " + bloque)
	return Vector3i.ZERO


func ejecutar_pruebas() -> void:
	print("=== TEST 1: la huella de cada plantilla coincide con la del tipo y todas las capas miden lo mismo ===")
	for tipo in TIPOS:
		assert(PlantillasPuesto.dimensiones(tipo) == _huella_esperada(tipo), tipo + ": huella base")
		for capa in PlantillasPuesto.PLANTILLAS[tipo]["capas"]:
			assert(capa.size() == _huella_esperada(tipo).y, tipo + ": filas por capa")
			for fila in capa:
				assert(fila.length() == _huella_esperada(tipo).x, tipo + ": columnas por fila")
		assert(PlantillasPuesto.altura(tipo) >= 2, tipo + ": al menos puerta de 2 bloques")

	print("\n=== TEST 2: cada plantilla tiene una puerta de 2 bloques en z = 0 y al menos un baúl ===")
	for tipo in TIPOS:
		var base: Dictionary = PlantillasPuesto.celdas(tipo, 0)
		var puertas := 0
		var baules := 0
		for celda in base:
			if base[celda] == "puerta_inferior":
				puertas += 1
				assert(celda.z == 0 and celda.y == 0, tipo + ": puerta a ras de suelo, en la fila frontal")
				assert(base.get(celda + Vector3i(0, 1, 0)) == "puerta_superior", tipo + ": puerta_superior encima")
			elif base[celda] == "baul":
				baules += 1
		assert(puertas == 1, tipo + ": exactamente una puerta")
		assert(baules >= 1, tipo + ": tiene depósito")

	print("\n=== TEST 3: los 4 giros conservan las celdas dentro de la huella y la celda de servicio queda fuera, frente a la puerta ===")
	for tipo in TIPOS:
		for giros in range(4):
			var h: Vector2i = PlantillasPuesto.huella(tipo, giros)
			var d: Vector2i = PlantillasPuesto.dimensiones(tipo)
			assert(h == (d if giros % 2 == 0 else Vector2i(d.y, d.x)), tipo + ": huella girada")
			var celdas_g: Dictionary = PlantillasPuesto.celdas(tipo, giros)
			for celda in celdas_g:
				assert(celda.x >= 0 and celda.x < h.x and celda.z >= 0 and celda.z < h.y, tipo + ": dentro de la huella girada")
			var puerta: Vector3i = _primera(celdas_g, "puerta_inferior")
			var servicio: Vector2i = PlantillasPuesto.celda_de_servicio(tipo, giros)
			assert(servicio.x < 0 or servicio.x >= h.x or servicio.y < 0 or servicio.y >= h.y, tipo + ": servicio fuera de la huella")
			assert(absi(servicio.x - puerta.x) + absi(servicio.y - puerta.z) == 1, tipo + ": servicio adyacente a la puerta")
			assert(celdas_g.get(PlantillasPuesto.celda_deposito(tipo, giros)) == "baul", tipo + ": la celda del depósito es el baúl")

	print("\n=== TEST 4: la puerta mira a −Z sin girar y a +X con un giro horario; cuatro giros vuelven al inicio ===")
	var mina0: Dictionary = PlantillasPuesto.celdas("mina", 0)
	assert(PlantillasPuesto.celda_de_servicio("mina", 0).y == -1, "sin girar, el servicio queda en z = -1")
	assert(_primera(PlantillasPuesto.celdas("mina", 1), "puerta_inferior").x == 4, "girada 90° horario, la puerta cae en el borde x = 4")
	assert(PlantillasPuesto.celda_de_servicio("mina", 1).x == 5, "y el servicio en x = 5")
	for tipo in TIPOS:
		assert(PlantillasPuesto.celdas(tipo, 4) == PlantillasPuesto.celdas(tipo, 0), tipo + ": 4 giros = 0 giros")
	assert(mina0.size() > 0)

	print("\n=== TEST 5: en_mundo() traslada la plantilla a la esquina y a la altura base ===")
	var mundo5: Dictionary = PlantillasPuesto.en_mundo("mina", 0, Vector2i(10, 20), 5)
	assert(mundo5.get(Vector3i(12, 5, 20)) == "puerta_inferior", "puerta en (esquina.x + 2, y_base, esquina.z)")
	assert(mundo5.get(Vector3i(12, 6, 20)) == "puerta_superior")
	assert(mundo5.size() == PlantillasPuesto.celdas("mina", 0).size())

	print("\n=== TEST 6: el extremo de agua de la pesca cambia con el giro (1, 0, 0, 1) ===")
	var indices: Array[int] = []
	for giros in range(4):
		indices.append(PlantillasPuesto.indice_extremo_agua(giros))
	assert(indices == [1, 0, 0, 1], "extremo de agua por giro: " + str(indices))

	print("\n=== TEST 7: todos los bloques de las plantillas existen en la biblioteca del mundo ===")
	var mundo7: Node = _mundo()
	for tipo in TIPOS:
		for bloque in PlantillasPuesto.celdas(tipo, 0).values():
			assert(mundo7._id_por_tipo.has(bloque), "falta el bloque " + bloque)

	print("\n=== TEST 8: un puesto estampado es un edificio completo: no se mina, el baúl sale primero y al volver a completarlo devuelve su metadata ===")
	var mundo8: Node = _mundo()
	var esquina8 := Vector2i(20, 20)
	var celdas8: Dictionary = PlantillasPuesto.en_mundo("maderero", 0, esquina8, 5)
	for celda in celdas8:
		assert(mundo8.colocar_bloque(celda, celdas8[celda]), "se puede colocar " + str(celda))
	var id8: int = mundo8.registrar_edificio_completo(celdas8, {"puesto": esquina8})
	mundo8.reemparejar_construccion(celdas8.keys())
	assert(mundo8.edificio_metadata[id8]["puesto"] == esquina8)
	var deposito_local: Vector3i = PlantillasPuesto.celda_deposito("maderero", 0)
	var deposito8 := Vector3i(esquina8.x + deposito_local.x, 5 + deposito_local.y, esquina8.y + deposito_local.z)
	assert(mundo8.obtener_tipo(deposito8) == "baul")
	assert(not mundo8.minar_bloque(deposito8), "un puesto no se mina bloque a bloque")
	var paso8: Dictionary = mundo8.procesar_deconstruccion(deposito8)
	assert(paso8["id"] == id8 and not paso8["lista_para_remocion"], "es el edificio del puesto y no está vacío")
	assert(mundo8.obtener_tipo(deposito8) == "fantasma", "el baúl es lo primero en revertirse")
	assert(mundo8.edificio_metadata[id8]["puesto"] == esquina8, "la metadata sobrevive a la deconstrucción")
	var avance8: Dictionary = mundo8.surtir_construccion(deposito8)
	assert(avance8.get("completa", false) and avance8["metadata"]["puesto"] == esquina8, "al completarse, devuelve la metadata del puesto")
	assert(mundo8.obtener_tipo(deposito8) == "baul", "el baúl vuelve")

	print("\n=== Las 8 pruebas de PlantillasPuesto pasaron correctamente ===")
```

- [ ] **Step 3: Ejecutar la prueba y ver que falla**

Run: `"$GD" --headless --path godot res://scenes/PlantillasPuestoTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `Parse Error` / `SCRIPT ERROR` por `res://scripts/PlantillasPuesto.gd` inexistente.

- [ ] **Step 4: Implementar `PlantillasPuesto.gd`**

Archivo `godot/scripts/PlantillasPuesto.gd`:

```gdscript
extends RefCounted

## Plantillas prediseñadas de los puestos de recolección (spec: docs/superpowers/
## specs/2026-09-24-edificios-recoleccion-plantillas-design.md). Datos puros y
## funciones estáticas, sin autoload ni class_name (se carga con preload, como
## el resto de scripts sin estado).
##
## Cada plantilla son "capas" de abajo hacia arriba (la capa 0 se coloca en
## objetivo + 1). Una capa es una lista de filas (eje Z); una fila, un texto con
## un carácter por columna (eje X). En la plantilla base la puerta está en la
## fila z = 0 y mira a −Z. Este mismo formato lo producirá luego el conversor
## de .obj de SketchUp, así que el arte reemplaza estas plantillas provisionales
## sin tocar código.

## Carácter -> bloque. "." (y cualquier otro carácter) es vacío.
const BLOQUES := {
	"#": "pared", "V": "ventana", "B": "baul",
	"d": "puerta_inferior", "D": "puerta_superior",
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
	# Edificio en las filas 0-2 y muelle (cubierta de pared) en las filas 3-5; el
	# agua queda del lado de z alto. "agua_ref" (x, z) es una celda del extremo de agua.
	"pesca_frutos_mar": {"capas": [
		["#d##", "#B.#", "####", "####", "####", "####"],
		["#D##", "V..V", "####", "....", "....", "...."],
		["####", "####", "####", "....", "....", "...."],
	], "agua_ref": Vector2i(0, 5)},
}


## (ancho, alto) de la plantilla sin girar.
static func dimensiones(tipo: String) -> Vector2i:
	var capa0: Array = PLANTILLAS[tipo]["capas"][0]
	return Vector2i((capa0[0] as String).length(), capa0.size())


## Número de capas (altura en bloques).
static func altura(tipo: String) -> int:
	return PLANTILLAS[tipo]["capas"].size()


## (ancho, alto) de la huella tras "giros" cuartos de vuelta: se intercambian con giros impar.
static func huella(tipo: String, giros: int) -> Vector2i:
	var d := dimensiones(tipo)
	return d if posmod(giros, 2) == 0 else Vector2i(d.y, d.x)


## Gira "p" (local, en una caja ancho x alto) "giros" cuartos de vuelta horarios:
## (x, z) -> (alto - 1 - z, x), la misma fórmula que CamaraCenital._rotar_blueprint().
static func _girar(p: Vector3i, ancho: int, alto: int, giros: int) -> Vector3i:
	for _i in range(posmod(giros, 4)):
		p = Vector3i(alto - 1 - p.z, p.y, p.x)
		var previo := ancho
		ancho = alto
		alto = previo
	return p


## Celdas locales de la plantilla girada: Vector3i (x, capa, z) -> nombre de bloque.
static func celdas(tipo: String, giros: int) -> Dictionary:
	var d := dimensiones(tipo)
	var resultado := {}
	var capas: Array = PLANTILLAS[tipo]["capas"]
	for y in range(capas.size()):
		var filas: Array = capas[y]
		for z in range(filas.size()):
			var fila: String = filas[z]
			for x in range(fila.length()):
				if BLOQUES.has(fila[x]):
					resultado[_girar(Vector3i(x, y, z), d.x, d.y, giros)] = BLOQUES[fila[x]]
	return resultado


## Igual que celdas(), pero en coordenadas del mundo: la esquina de la huella es
## "esquina" (X, Z) y la capa 0 queda en "y_base".
static func en_mundo(tipo: String, giros: int, esquina: Vector2i, y_base: int) -> Dictionary:
	var resultado := {}
	var local := celdas(tipo, giros)
	for c in local:
		resultado[Vector3i(esquina.x + c.x, y_base + c.y, esquina.y + c.z)] = local[c]
	return resultado


## Primera celda base (sin girar) con ese bloque.
static func _buscar(tipo: String, bloque: String) -> Vector3i:
	var base := celdas(tipo, 0)
	for c in base:
		if base[c] == bloque:
			return c
	assert(false, "la plantilla " + tipo + " no tiene " + bloque)
	return Vector3i.ZERO


## Celda local (X, Z) justo fuera de la puerta, fuera de la huella girada.
static func celda_de_servicio(tipo: String, giros: int) -> Vector2i:
	var puerta := _buscar(tipo, "puerta_inferior")
	var d := dimensiones(tipo)
	var fuera := _girar(Vector3i(puerta.x, 0, puerta.z - 1), d.x, d.y, giros)
	return Vector2i(fuera.x, fuera.z)


## Celda local (x, capa, z) del baúl que hace de depósito del puesto.
static func celda_deposito(tipo: String, giros: int) -> Vector3i:
	var d := dimensiones(tipo)
	return _girar(_buscar(tipo, "baul"), d.x, d.y, giros)


## Solo pesca_frutos_mar: índice (0 = extremo de coordenada baja, 1 = alta) del
## extremo de agua a lo largo del eje largo de la huella girada, con la misma
## convención que CamaraCenital._celdas_extremo_pesca() (eje largo = Z si alto > ancho).
static func indice_extremo_agua(giros: int) -> int:
	var tipo := "pesca_frutos_mar"
	var d := dimensiones(tipo)
	var ref: Vector2i = PLANTILLAS[tipo]["agua_ref"]
	var p := _girar(Vector3i(ref.x, 0, ref.y), d.x, d.y, giros)
	var h := huella(tipo, giros)
	var coordenada: int = p.z if h.y > h.x else p.x
	return 0 if coordenada == 0 else 1
```

- [ ] **Step 5: Ejecutar la prueba y ver que pasa**

Run: `"$GD" --headless --path godot res://scenes/PlantillasPuestoTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `=== Las 8 pruebas de PlantillasPuesto pasaron correctamente ===`

Si TEST 7 falla porque falta un bloque (p. ej. `ventana`), no inventes el bloque: usa solo tipos que `VoxelWorld._id_por_tipo` tenga y ajusta las plantillas. Si TEST 8 falla porque `procesar_deconstruccion`/`surtir_construccion` requieren algo del mundo que este `VoxelWorld` sin `_ready()` no tiene (p. ej. el cuerpo de obra), copia la preparación de `FantasmasPermeablesTest.gd` (`_mundo()` y su TEST 6/7), que ejercita las mismas funciones.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/PlantillasPuesto.gd godot/scripts/PlantillasPuestoTest.gd godot/scenes/PlantillasPuestoTest.tscn
git commit -m "feat: plantillas prediseñadas de puestos de recolección

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Economia — activo, agotado, servicio y depósito

**Files:**
- Modify: `godot/scripts/Economia.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Consumes: `Recoleccion.SIN_PUESTO` (`Vector2i(-99999, -99999)`), `Recoleccion.tasas_de_entorno`, `Ciudad.almacen[recurso].agregar(monto) -> float` (devuelve lo que realmente entró).
- Produces (en `Economia`):
  - `signal trabajadores_liberados(ids: Array)`
  - `const SIN_SERVICIO := Vector2i.MAX`, `const SIN_DEPOSITO := Vector3i.MAX`
  - `registrar_puesto(esquina, tipo, ancho, alto, tasas, entorno := {}, servicio := SIN_SERVICIO, deposito := SIN_DEPOSITO)`
  - claves nuevas en `puestos[esquina]`: `"activo": bool`, `"agotado": bool`, `"servicio": Vector2i`, `"deposito": Vector3i`
  - `desactivar_puesto(esquina)`, `reactivar_puesto(esquina)`
  - `servicio_de(esquina) -> Vector2i` (`SIN_SERVICIO` si no tiene)
  - `puesto_con_deposito(celda: Vector3i) -> Vector2i` (`Recoleccion.SIN_PUESTO` si ninguno)
  - `retirar_deposito(esquina) -> Dictionary` (lo transferido al stock central)

- [ ] **Step 1: Escribir las pruebas nuevas (fallarán)**

En `godot/scripts/EconomiaTest.gd`, reemplaza la última línea de `ejecutar_pruebas()`:

```gdscript
	print("\n=== Las 17 pruebas de Economia pasaron correctamente ===")
```

por:

```gdscript
	print("\n=== TEST 18: un puesto se registra activo, sin agotar y, sin celda de servicio ni depósito, con los valores «ninguno» ===")
	var e18: Node = _nueva(CiudadScript.new())
	assert(e18.puestos[ESQ]["activo"] and not e18.puestos[ESQ]["agotado"])
	assert(e18.servicio_de(ESQ) == EconomiaScript.SIN_SERVICIO, "sin celda de servicio, Colonos usa el anillo de la huella")
	assert(e18.puestos[ESQ]["deposito"] == EconomiaScript.SIN_DEPOSITO)
	assert(e18.servicio_de(Vector2i(0, 0)) == EconomiaScript.SIN_SERVICIO, "puesto inexistente")

	print("\n=== TEST 19: desactivar_puesto() libera a todos, es idempotente, conserva el almacén y no admite contratar ===")
	var e19: Node = _nueva(CiudadScript.new())
	e19.asignar(ESQ, "recolector", 1)
	e19.asignar(ESQ, "acarreador", 2)
	e19.marcar_presente(1, true)
	e19.puestos[ESQ]["almacen"]["madera"] = 5.0
	var liberados19: Array = []
	e19.trabajadores_liberados.connect(func(ids: Array) -> void: liberados19.append_array(ids))
	e19.desactivar_puesto(ESQ)
	liberados19.sort()
	assert(liberados19 == [1, 2], "los dos quedan libres")
	assert(not e19.puestos[ESQ]["activo"] and e19.cupo_libre(ESQ) == 5)
	assert(is_equal_approx(e19.almacen_local(ESQ)["madera"], 5.0), "el almacén local se conserva")
	e19.desactivar_puesto(ESQ)
	assert(liberados19.size() == 2, "desactivar dos veces no vuelve a emitir")
	assert(not e19.asignar(ESQ, "recolector", 3) and not e19.asignar(ESQ, "acarreador", 3), "inactivo: no se contrata")
	e19.marcar_presente(1, true)
	e19.simular_hora()
	assert(is_equal_approx(e19.almacen_local(ESQ)["madera"], 5.0), "inactivo no produce")
	e19.reactivar_puesto(ESQ)
	assert(e19.puestos[ESQ]["activo"] and e19.asignar(ESQ, "recolector", 3), "reactivado: se contrata de nuevo")
	e19.desactivar_puesto(Vector2i(0, 0))  # inexistente: no falla

	print("\n=== TEST 20: retirar_deposito() pasa al stock central solo lo que cabe y deja el resto en el puesto ===")
	var ciudad20: Node = CiudadScript.new()
	var e20: Node = EconomiaScript.new()
	e20.ciudad = ciudad20
	e20.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0}, {}, Vector2i(11, 9), Vector3i(11, 5, 11))
	assert(e20.puesto_con_deposito(Vector3i(11, 5, 11)) == ESQ)
	assert(e20.puesto_con_deposito(Vector3i(0, 0, 0)) == Recoleccion.SIN_PUESTO)
	assert(e20.servicio_de(ESQ) == Vector2i(11, 9))
	ciudad20.almacen["madera"].cantidad = ciudad20.almacen["madera"].limite - 40.0
	e20.puestos[ESQ]["almacen"]["madera"] = 100.0
	var tomado20: Dictionary = e20.retirar_deposito(ESQ)
	assert(is_equal_approx(tomado20["madera"], 40.0), "solo cabían 40")
	assert(is_equal_approx(e20.almacen_local(ESQ)["madera"], 60.0), "el resto queda en el puesto")
	assert(e20.retirar_deposito(ESQ).is_empty(), "con el stock lleno no pasa nada")
	assert(e20.retirar_deposito(Vector2i(0, 0)).is_empty(), "puesto inexistente")

	print("\n=== TEST 21: al agotarse el área se liberan los recolectores, los acarreadores siguen hasta vaciar el almacén y reactivar recalcula el agotamiento ===")
	var mundo21: Node = _mundo_con_veta()
	var e21: Node = EconomiaScript.new()
	e21.ciudad = CiudadScript.new()
	e21.mundo = mundo21
	e21.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e21.asignar(ESQ, "recolector", 1)
	e21.asignar(ESQ, "recolector", 2)
	e21.asignar(ESQ, "acarreador", 3)
	e21.marcar_presente(1, true)
	e21.marcar_presente(2, true)
	var liberados21: Array = []
	e21.trabajadores_liberados.connect(func(ids: Array) -> void: liberados21.append_array(ids))
	e21.recalcular_tasas(ESQ)
	assert(liberados21.is_empty() and not e21.puestos[ESQ]["agotado"], "con veta no se agota")
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		mundo21.minar_bloque(celda)
	e21.puestos[ESQ]["almacen"]["hierro"] = 20.0
	e21.recalcular_tasas(ESQ)
	assert(e21.puestos[ESQ]["agotado"], "sin bloques minerales, todas las tasas son 0")
	liberados21.sort()
	assert(liberados21 == [1, 2], "se liberan los recolectores")
	assert(e21.trabajadores_de(ESQ)["recolectores"] == 0 and e21.trabajadores_de(ESQ)["acarreadores"] == 1, "el acarreador se queda")
	assert(not e21.asignar(ESQ, "recolector", 4), "agotado: no se contratan recolectores")
	e21.simular_hora()
	assert(e21.trabajadores_de(ESQ)["acarreadores"] == 1, "con almacén no se libera al acarreador")
	var carga21: Dictionary = e21.recoger(ESQ, 150.0)
	assert(is_equal_approx(carga21["hierro"], 20.0), "se acarrea el resto")
	e21.simular_hora()
	liberados21.sort()
	assert(liberados21 == [1, 2, 3], "vacío y agotado: se libera al acarreador")
	# Reactivar tras deconstruir con el recurso ya agotado: sigue agotado (recalcula al reactivar).
	e21.desactivar_puesto(ESQ)
	e21.reactivar_puesto(ESQ)
	assert(e21.puestos[ESQ]["agotado"] and not e21.asignar(ESQ, "recolector", 5))
	# Agotamiento con el almacén ya vacío libera a los acarreadores en el mismo recálculo.
	var e21b: Node = EconomiaScript.new()
	e21b.ciudad = CiudadScript.new()
	e21b.mundo = _mundo_con_veta()
	e21b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e21b.asignar(ESQ, "acarreador", 7)
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		e21b.mundo.minar_bloque(celda)
	e21b.recalcular_tasas(ESQ)
	assert(e21b.trabajadores_de(ESQ)["acarreadores"] == 0, "agotado y sin almacén: el acarreador también se libera")

	print("\n=== Las 21 pruebas de Economia pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: error por `servicio_de`/`trabajadores_liberados`/`SIN_SERVICIO` inexistentes.

- [ ] **Step 3: Implementar en `Economia.gd`**

3a. Tras `signal puesto_quitado(ids: Array)` añade:

```gdscript

## Ids de colonos que dejan de trabajar en un puesto que sigue en pie (se
## desactivó por deconstrucción, o se agotó: Colonos.gd los devuelve a
## desempleado, salvo a un acarreador con carga, que termina su viaje).
signal trabajadores_liberados(ids: Array)

## Valores «ninguno» de la celda de servicio (X, Z de la puerta) y del depósito
## (celda del baúl) de un puesto sin plantilla.
const SIN_SERVICIO := Vector2i.MAX
const SIN_DEPOSITO := Vector3i.MAX
```

3b. Reemplaza `registrar_puesto` (firma y diccionario):

```gdscript
## Registra un puesto recién colocado, sin trabajadores. "tasas" son las de
## Recoleccion.tasas_de_entorno() al colocarlo y "entorno" el de
## Recoleccion.entorno_de_puesto() ({} = el puesto no consume ni recalcula).
## "servicio" (X, Z) es la celda exterior frente a su puerta y "deposito" la
## celda de su baúl (ver PlantillasPuesto.gd); sin ellas Colonos usa el anillo
## que rodea la huella y no hay depósito físico.
func registrar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int, tasas: Dictionary, entorno: Dictionary = {}, servicio: Vector2i = SIN_SERVICIO, deposito: Vector3i = SIN_DEPOSITO) -> void:
	puestos[esquina] = {
		"tipo": tipo, "ancho": ancho, "alto": alto,
		"cupo": Recoleccion.cupo_de(tipo),
		"capacidad": Recoleccion.capacidad_almacen_de(tipo),
		"tasas": tasas.duplicate(),
		"entorno": entorno.duplicate(),
		"en_curso": {},
		"recolectores": [], "acarreadores": [],
		"presentes": {}, "almacen": {},
		"activo": true, "agotado": false,
		"servicio": servicio, "deposito": deposito,
	}
```

3c. En `asignar`, tras la línea `if not puestos.has(esquina) or not ROLES.has(rol) or _puesto_de.has(colono_id):` + su `return false`, añade antes del chequeo de cupo:

```gdscript
	var p: Dictionary = puestos[esquina]
	if not p["activo"] or (p["agotado"] and rol == "recolector"):
		return false  # inactivo (se está deconstruyendo) o agotado: sin recolectores nuevos
```

y cambia la línea final `puestos[esquina]["recolectores" if rol == "recolector" else "acarreadores"].append(colono_id)` por `p["recolectores" if rol == "recolector" else "acarreadores"].append(colono_id)`.

3d. En `simular_hora`, reemplaza el arranque del bucle:

```gdscript
	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		var producido: Dictionary = produccion_por_hora(esquina)
```

por:

```gdscript
	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		if not p["activo"]:
			continue
		_liberar_acarreadores_si_agotado(esquina)
		var producido: Dictionary = produccion_por_hora(esquina)
```

3e. En `recalcular_tasas`, tras `p["tasas"] = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"])` añade:

```gdscript
	_actualizar_agotamiento(esquina)
```

3f. Añade estas funciones al final del archivo:

```gdscript


## Celda (X, Z) de servicio del puesto (frente a su puerta) o SIN_SERVICIO.
func servicio_de(esquina: Vector2i) -> Vector2i:
	return puestos[esquina]["servicio"] if puestos.has(esquina) else SIN_SERVICIO


## Esquina del puesto cuyo baúl (depósito) está en "celda", o Recoleccion.SIN_PUESTO.
func puesto_con_deposito(celda: Vector3i) -> Vector2i:
	for esquina in puestos:
		if puestos[esquina]["deposito"] == celda:
			return esquina
	return Recoleccion.SIN_PUESTO


## El avatar toma del depósito: pasa al stock central lo que quepa (el resto se
## queda en el almacén local). Devuelve lo transferido, {} si nada.
func retirar_deposito(esquina: Vector2i) -> Dictionary:
	var tomado: Dictionary = {}
	if not puestos.has(esquina):
		return tomado
	var local: Dictionary = puestos[esquina]["almacen"]
	for recurso in local.keys():
		if not ciudad.almacen.has(recurso):
			continue
		var ingreso: float = ciudad.almacen[recurso].agregar(local[recurso])
		if ingreso <= 1e-9:
			continue
		tomado[recurso] = ingreso
		local[recurso] -= ingreso
		if local[recurso] <= 1e-9:
			local.erase(recurso)
	return tomado


## El puesto empieza a deconstruirse: deja de funcionar y todos sus trabajadores
## quedan libres. Conserva el almacén local (se pierde al eliminar el puesto).
## Idempotente; no-op si el puesto no existe.
func desactivar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina) or not puestos[esquina]["activo"]:
		return
	var p: Dictionary = puestos[esquina]
	p["activo"] = false
	_liberar_de(esquina, p["recolectores"] + p["acarreadores"])


## La obra del puesto volvió a completarse: vuelve a funcionar, sin trabajadores.
## Recalcula el entorno por si el recurso se agotó mientras tanto.
func reactivar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	puestos[esquina]["activo"] = true
	recalcular_tasas(esquina)


static func _sin_tasas(tasas: Dictionary) -> bool:
	for tasa in tasas.values():
		if tasa > 0.0:
			return false
	return true


## Un puesto sin ninguna tasa positiva está agotado: pierde a sus recolectores
## (y a sus acarreadores en cuanto su almacén local se vacía).
func _actualizar_agotamiento(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	p["agotado"] = _sin_tasas(p["tasas"])
	if p["agotado"]:
		_liberar_de(esquina, p["recolectores"].duplicate())
		_liberar_acarreadores_si_agotado(esquina)


func _liberar_acarreadores_si_agotado(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	if p["agotado"] and _total(p["almacen"]) <= 1e-9:
		_liberar_de(esquina, p["acarreadores"].duplicate())


## Libera a "ids" (copia, no la lista viva del puesto) y avisa a Colonos.
func _liberar_de(_esquina: Vector2i, ids: Array) -> void:
	if ids.is_empty():
		return
	for id in ids:
		liberar(id)
	trabajadores_liberados.emit(ids)
```

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `=== Las 21 pruebas de Economia pasaron correctamente ===`

Si una prueba **antigua** (1–17) falla porque ahora un puesto agotado libera a sus recolectores tras `recalcular_tasas` (p. ej. asume que un recolector sigue asignado después de agotar el área), ajusta esa aserción al comportamiento nuevo y dilo en el mensaje del commit; no debilites la lógica nueva.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: puestos activos/agotados, celda de servicio y depósito en Economia

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Colonos — zona de servicio y liberación

**Files:**
- Modify: `godot/scripts/Colonos.gd` (zona de servicio en `_junto_a`/`_ir_junto_a`, `_llevar_al_nucleo`, `_on_trabajadores_liberados`, `_volver_a_desempleado`)
- Test: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- Consumes: `Economia.servicio_de(esquina) -> Vector2i`, `Economia.SIN_SERVICIO`, señal `Economia.trabajadores_liberados(ids)`, `Economia.desactivar_puesto(esquina)`, `Economia.recoger`, `Economia.entregar`.
- Produces: `Colonos._on_trabajadores_liberados(ids: Array)`; clave opcional `c["retirar_al_entregar"]` en el diccionario del colono (leída con `.get(..., false)`, no requiere inicializarla).

- [ ] **Step 1: Escribir las pruebas (fallarán)**

En `godot/scripts/ColonosTest.gd`, reemplaza la última línea de `ejecutar_pruebas()`:

```gdscript
	print("\n=== Las 26 pruebas de Colonos pasaron correctamente ===")
```

por:

```gdscript
	print("\n=== TEST 27: con celda de servicio, los recolectores se reparten por la zona de servicio de la puerta ===")
	var ciudad27: Node = CiudadScript.new()
	var economia27: Node = EconomiaScript.new()
	economia27.ciudad = ciudad27
	# Maderero 2x2 en (2,2); puerta hacia +X: celda de servicio (4,3) fuera de la huella. Zona: x 2..6, z 1..5 sin la huella.
	economia27.registrar_puesto(Vector2i(2, 2), "maderero", 2, 2, {"madera": 3.0}, {}, Vector2i(4, 3))
	var colonos27: Node = _nuevo(_mundo_llano(), ciudad27)
	colonos27.economia = economia27
	var ids27: Array[int] = []
	for celda27 in [Vector3i(8, 1, 1), Vector3i(8, 1, 2), Vector3i(8, 1, 3)]:
		ids27.append(colonos27.agregar_colono("desempleado", celda27))
	ciudad27.demografia["desempleado"] = 3
	for i in range(3):
		assert(colonos27.contratar(Vector2i(2, 2), "recolector"))
	var todos27 := false
	for i in range(600):
		colonos27.avanzar(0.1)
		if economia27.trabajadores_de(Vector2i(2, 2))["presentes"] == 3:
			todos27 = true
			break
	assert(todos27, "los tres llegan a la zona de servicio y quedan presentes")
	var celdas27: Dictionary = {}
	for id27 in ids27:
		var c27: Dictionary = colonos27.colonos[id27]
		assert(absi(c27["celda"].x - 4) <= 2 and absi(c27["celda"].z - 3) <= 2, "dentro de la zona de servicio")
		assert(not (c27["celda"].x in [2, 3] and c27["celda"].z in [2, 3]), "no dentro de la huella")
		celdas27[c27["celda"]] = true
	assert(celdas27.size() == 3, "cada uno en su propia celda")

	print("\n=== TEST 28: agotamiento/desactivación: el recolector vuelve a desempleado y el acarreador con carga termina el viaje ===")
	var ciudad28: Node = CiudadScript.new()
	var colonos28: Node = _nuevo_con_puesto(ciudad28)
	var id_rec28: int = colonos28.agregar_colono("desempleado", Vector3i(6, 1, 1))
	var id_acar28: int = colonos28.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad28.demografia["desempleado"] = 2
	assert(colonos28.contratar(Vector2i(2, 2), "recolector"))
	assert(colonos28.contratar(Vector2i(2, 2), "acarreador"))
	# contratar() toma al desempleado de id menor: el recolector es id_rec28 y el acarreador id_acar28.
	var recolector28: Dictionary = colonos28.colonos[id_rec28]
	var acarreador28: Dictionary = colonos28.colonos[id_acar28]
	assert(recolector28["trabajo"]["rol"] == "recolector" and acarreador28["trabajo"]["rol"] == "acarreador")
	acarreador28["fase"] = "entregar"
	acarreador28["carga"] = {"madera": 50.0}
	var madera28: float = ciudad28.almacen["madera"].cantidad
	colonos28.economia.desactivar_puesto(Vector2i(2, 2))
	assert(recolector28["tipo"] == "desempleado" and recolector28["trabajo"].is_empty(), "el recolector queda libre al instante")
	assert(acarreador28["tipo"] == "obrero" and acarreador28.get("retirar_al_entregar", false), "el acarreador cargado sigue hasta entregar")
	var entrego28 := false
	for i in range(1500):
		colonos28.avanzar(0.1)
		if acarreador28["tipo"] == "desempleado":
			entrego28 = true
			break
	assert(entrego28, "entrega y queda libre (aunque el puesto siga inactivo)")
	assert(is_equal_approx(ciudad28.almacen["madera"].cantidad, madera28 + 50.0), "la carga llegó al núcleo")
	assert(acarreador28["carga"].is_empty() and not acarreador28.get("retirar_al_entregar", false))

	print("\n=== TEST 29: un acarreador con carga cuyo puesto se quita entretanto sigue entregando ===")
	var ciudad29: Node = CiudadScript.new()
	var colonos29: Node = _nuevo_con_puesto(ciudad29)
	var id29: int = colonos29.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad29.demografia["desempleado"] = 1
	assert(colonos29.contratar(Vector2i(2, 2), "acarreador"))
	var c29: Dictionary = colonos29.colonos[id29]
	c29["fase"] = "entregar"
	c29["carga"] = {"madera": 30.0}
	colonos29.economia.trabajadores_liberados.emit([id29])  # agotamiento con carga a cuestas
	colonos29.economia.puestos.erase(Vector2i(2, 2))  # el puesto desaparece antes de que llegue
	var madera29: float = ciudad29.almacen["madera"].cantidad
	var llego29 := false
	for i in range(1500):
		colonos29.avanzar(0.1)
		if c29["tipo"] == "desempleado":
			llego29 = true
			break
	assert(llego29 and is_equal_approx(ciudad29.almacen["madera"].cantidad, madera29 + 30.0), "no se atasca aunque el puesto ya no exista")

	print("\n=== Las 29 pruebas de Colonos pasaron correctamente ===")
```

(El TEST 28 ejercita `desactivar_puesto` real de `Economia`; el TEST 29 emite la señal a mano y borra el puesto para probar que el acarreador no queda esperando a un puesto inexistente.)

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: fallo (no existe `_on_trabajadores_liberados` conectado; el TEST 27 usa el anillo, no la zona de servicio).

- [ ] **Step 3: Implementar en `Colonos.gd`**

3a. Junto a `INTENTOS_SERVICIO` añade:

```gdscript
const RADIO_SERVICIO := 2  # celdas (Chebyshev) alrededor de la celda de servicio de un puesto con puerta
```

3b. Sustituye el setter de `economia`:

```gdscript
var economia: Object = null:  # Economia
	set(valor):
		if economia != null:
			if economia.puesto_quitado.is_connected(_on_puesto_quitado):
				economia.puesto_quitado.disconnect(_on_puesto_quitado)
			if economia.trabajadores_liberados.is_connected(_on_trabajadores_liberados):
				economia.trabajadores_liberados.disconnect(_on_trabajadores_liberados)
		economia = valor
		if valor != null:
			valor.puesto_quitado.connect(_on_puesto_quitado)
			valor.trabajadores_liberados.connect(_on_trabajadores_liberados)
```

3c. Tras `_on_puesto_quitado` añade:

```gdscript


## Trabajadores liberados de un puesto que sigue en pie (agotado o desactivado):
## vuelven a desempleado, salvo un acarreador que lleva carga, que primero
## termina el viaje y la entrega en el núcleo (ver _decidir_trabajo()).
func _on_trabajadores_liberados(ids: Array) -> void:
	for id in ids:
		if not colonos.has(id):
			continue
		var c: Dictionary = colonos[id]
		if c["fase"] == "entregar" and not c["carga"].is_empty():
			c["retirar_al_entregar"] = true
		else:
			_volver_a_desempleado(c)
```

3d. En `_volver_a_desempleado`, añade tras `c["fallos_servicio"] = 0`:

```gdscript
	c["retirar_al_entregar"] = false
```

3e. Reemplaza `_decidir_trabajo` completo por:

```gdscript
func _decidir_trabajo(c: Dictionary) -> void:
	if not _recuperar_si_atrapado(c):
		return
	if c.get("retirar_al_entregar", false):
		# Ya no trabaja en el puesto (agotado o desactivado), pero termina su viaje.
		if _llevar_al_nucleo(c):
			_volver_a_desempleado(c)
		return
	var esquina: Vector2i = c["trabajo"]["puesto"]
	var huella_puesto: Array = economia.huella_de(esquina)
	if huella_puesto.is_empty():
		c["espera"] = ESPERA_TRABAJO  # el puesto ya no existe: Economia avisará
		return
	var servicio: Vector2i = economia.servicio_de(esquina)
	if c["trabajo"]["rol"] == "recolector":
		if _junto_a(c["celda"], huella_puesto, servicio):
			economia.marcar_presente(c["id"], true)
			c["espera"] = ESPERA_TRABAJO
		else:
			_ir_junto_a(c, huella_puesto, servicio)
		return
	if c["fase"] == "entregar":
		if _llevar_al_nucleo(c):
			c["fase"] = "recoger"
		return
	# fase "" o "recoger": ir al puesto y pedir la carga.
	if not _junto_a(c["celda"], huella_puesto, servicio):
		_ir_junto_a(c, huella_puesto, servicio)
		return
	var carga: Dictionary = economia.recoger(esquina, economia.CAPACIDAD_CARGA)
	if carga.is_empty():
		c["espera"] = ESPERA_TRABAJO  # todavía no hay carga (o nada que llevar)
		return
	c["carga"] = carga
	c["fase"] = "entregar"


## Un paso hacia el núcleo urbano con la carga del colono: si ya está junto a él,
## la entrega y devuelve true; si no, planifica la ruta y devuelve false.
func _llevar_al_nucleo(c: Dictionary) -> bool:
	var huella_nucleo: Array = zona.huella_del_nucleo()
	if _junto_a(c["celda"], huella_nucleo):
		economia.entregar(c["carga"])
		c["carga"] = {}
		return true
	_ir_junto_a(c, huella_nucleo)
	return false
```

3f. Sustituye `_junto_a`, `_celdas_junto_a` (se conserva) y `_ir_junto_a` así — `_junto_a` y `_ir_junto_a` ganan un parámetro `servicio` opcional; añade `_en_servicio` y `_celdas_de_servicio`:

```gdscript
## true si "celda" está en la columna pegada (4 direcciones) a alguna celda de
## la huella y no dentro de ella. Con "servicio" (celda de la puerta de un
## puesto), en cambio: dentro de la zona de servicio (RADIO_SERVICIO) y fuera de la huella.
func _junto_a(celda: Vector3i, huella: Array, servicio: Vector2i = Vector2i.MAX) -> bool:
	var xz := Vector2i(celda.x, celda.z)
	if huella.has(xz):
		return false
	if servicio != Vector2i.MAX:
		return absi(xz.x - servicio.x) <= RADIO_SERVICIO and absi(xz.y - servicio.y) <= RADIO_SERVICIO
	for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if huella.has(xz + direccion):
			return true
	return false
```

(`Vector2i.MAX` es `Economia.SIN_SERVICIO`; se usa el literal para que `_junto_a` siga sin depender de la instancia `economia` en las llamadas al núcleo.)

```gdscript
## Celdas transitables de la zona de servicio de un puesto (fuera de la huella,
## sobre la superficie).
func _celdas_de_servicio(servicio: Vector2i, huella: Array) -> Array[Vector3i]:
	var celdas: Array[Vector3i] = []
	for dx in range(-RADIO_SERVICIO, RADIO_SERVICIO + 1):
		for dz in range(-RADIO_SERVICIO, RADIO_SERVICIO + 1):
			var xz := servicio + Vector2i(dx, dz)
			if huella.has(xz):
				continue
			var altura: int = mundo.altura_en(xz.x, xz.y)
			if altura < 0:
				continue
			var candidata := Vector3i(xz.x, altura + 1, xz.y)
			if _buscador.es_transitable(candidata):
				celdas.append(candidata)
	return celdas


## Planifica una ruta hasta la celda libre más cercana junto a la huella (o en la
## zona de servicio, si el puesto tiene puerta); si ninguna de las
## INTENTOS_SERVICIO más cercanas es alcanzable, espera y reintenta.
func _ir_junto_a(c: Dictionary, huella: Array, servicio: Vector2i = Vector2i.MAX) -> void:
	var candidatas: Array[Vector3i] = _celdas_junto_a(huella) if servicio == Vector2i.MAX else _celdas_de_servicio(servicio, huella)
```

y deja el resto del cuerpo original de `_ir_junto_a` (desde `var origen: Vector3i = c["celda"]` hasta el final) sin cambios.

Una celda de la zona de servicio ocupada por otro colono no cuenta como libre para `buscar_ruta` (las opciones de `_opciones_ruta(c)` ya bloquean las ocupadas); con hasta 7 trabajadores y ~20 celdas de zona hay sitio.

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `=== Las 29 pruebas de Colonos pasaron correctamente ===` (las pruebas 18–25 existentes siguen pasando: los puestos que registran no tienen celda de servicio y usan el anillo).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: zona de servicio en la puerta y liberación de trabajadores en Colonos

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: CamaraCenital — rotación de 4 giros y estampado de la plantilla

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd` (constantes, `_alternar_modo_colocar_puesto`, `_rotar_huella_puesto`, `_procesar_clic_puesto`)

**Interfaces:**
- Consumes: `PlantillasPuesto.altura/celda_de_servicio/celda_deposito/en_mundo/indice_extremo_agua`, `NiveladorTerreno.LIMITE_PENDIENTE` (= 2), `mundo.verificar_huella_libre(esquina, columnas, altura)`, `mundo.colocar_bloque`, `mundo.registrar_edificio_completo(celdas: Dictionary, metadata: Dictionary) -> int`, `mundo.reemparejar_construccion(celdas: Array)`, `Economia.registrar_puesto(..., servicio, deposito)`.
- Produces: puestos colocados como edificios completos con `metadata = {"puesto": esquina}`; `_giros_puesto: int` (0–3).

Esta tarea no tiene prueba unitaria (la lógica pura ya está probada en las Tareas 1–2; `CamaraCenital` necesita la escena completa). Se verifica con un arranque headless de `Main.tscn` y con la verificación manual de la Tarea 6.

- [ ] **Step 1: Preload y estado del giro**

Junto a los `const ... = preload(...)` del principio (después de `const ConstructorVias = ...`) añade:

```gdscript
const PlantillasPuesto = preload("res://scripts/PlantillasPuesto.gd")
```

Tras `var _alto_puesto_activo := 0` añade:

```gdscript
## Cuartos de vuelta horarios (0-3) de la plantilla del puesto activo; Ctrl +
## rueda lo avanza (ver _rotar_huella_puesto()) y decide hacia dónde mira la puerta.
var _giros_puesto := 0
```

- [ ] **Step 2: Reiniciar y avanzar el giro**

En `_alternar_modo_colocar_puesto`, tras `_alto_puesto_activo = alto` añade:

```gdscript
	_giros_puesto = 0
```

En `_rotar_huella_puesto`, tras `_alto_puesto_activo = ancho_previo` añade:

```gdscript
	_giros_puesto = (_giros_puesto + 1) % 4
```

y actualiza su comentario de cabecera para que diga que además del intercambio ancho/alto avanza el giro (0–3) de la plantilla, que decide hacia dónde mira la puerta.

- [ ] **Step 3: Validación previa y objetivo antes de mutar el mundo**

En `_procesar_clic_puesto`:

3a. Cambia la llamada a `verificar_huella_libre` para revisar también la altura de la plantilla (el terreno puede estar hasta `LIMITE_PENDIENTE` por debajo de `objetivo`):

```gdscript
	var altura_plantilla: int = PlantillasPuesto.altura(_tipo_puesto_activo) + NiveladorTerreno.LIMITE_PENDIENTE
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas, altura_plantilla)
```

(sustituye la línea `var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas)`; el mensaje de rechazo existente sigue valiendo).

3b. Justo después del bloque `if _tipo_puesto_activo == "pesca_frutos_mar": ... elif not _huella_tiene_columna_en_tierra(...): ... return` (y antes de `var centro_agua := Recoleccion.SIN_CENTRO`) inserta:

```gdscript
	# Giro efectivo de la plantilla: en la pesca, el edificio debe caer en el extremo de tierra.
	var giros := _giros_puesto
	if _tipo_puesto_activo == "pesca_frutos_mar" and PlantillasPuesto.indice_extremo_agua(giros) != extremo_agua_indice:
		giros = (giros + 2) % 4
	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	# La puerta debe dar a suelo firme: a lo sumo 1 bloque de desnivel, sin agua ni otro puesto.
	var servicio: Vector2i = esquina + PlantillasPuesto.celda_de_servicio(_tipo_puesto_activo, giros)
	var altura_servicio: int = mundo.altura_en(servicio.x, servicio.y)
	if absi(altura_servicio - objetivo) > 1 or mundo.obtener_tipo(Vector3i(servicio.x, altura_servicio, servicio.y)) == "agua" or Recoleccion.celda_dentro_de_algun_puesto(servicio):
		print("Colocación rechazada: la puerta del puesto no da a suelo firme y libre.")
		return
```

3c. Borra la línea posterior `var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)` (la que precede a `var total_relleno := 0`), porque `objetivo` ya está declarado arriba.

- [ ] **Step 4: Estampar la plantilla en vez del slab marcador**

Reemplaza todo el bloque desde `var bloque_marcador: String` hasta `mundo.registrar_edificio(celdas_puesto)` (incluye el `if _tipo_puesto_activo == "pesca_frutos_mar":` del slab de dos niveles) por:

```gdscript
	# La plantilla del puesto: bloques reales sobre el terreno nivelado, registrados
	# como edificio completo (se deconstruye bloque a bloque, como un residencial).
	var y_base := objetivo + 1
	var celdas_plantilla: Dictionary = PlantillasPuesto.en_mundo(_tipo_puesto_activo, giros, esquina, y_base)
	var celdas_puesto: Dictionary = {}
	for celda_plantilla in celdas_plantilla:
		if mundo.colocar_bloque(celda_plantilla, celdas_plantilla[celda_plantilla]):
			celdas_puesto[celda_plantilla] = celdas_plantilla[celda_plantilla]
	mundo.registrar_edificio_completo(celdas_puesto, {"puesto": esquina})
	mundo.reemparejar_construccion(celdas_puesto.keys())
	var deposito_local: Vector3i = PlantillasPuesto.celda_deposito(_tipo_puesto_activo, giros)
	var deposito := Vector3i(esquina.x + deposito_local.x, y_base + deposito_local.y, esquina.y + deposito_local.z)
```

y cambia la llamada a `Economia.registrar_puesto` por:

```gdscript
	Economia.registrar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo, tasas_puesto, entorno_puesto, servicio, deposito)
```

(`Recoleccion.colocar_puesto(...)` y el `print` posterior no cambian.)

- [ ] **Step 5: Arranque headless para detectar errores de script**

Run: `"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"`
Expected: sin salida (ninguna línea).

Comprobación estática adicional: `grep -n "bloque_marcador\|registrar_edificio(celdas_puesto)" godot/scripts/CamaraCenital.gd` no debe devolver nada.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: colocar puestos con plantilla y 4 giros, registrados como edificio completo

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Player y panel — deconstrucción, reactivación, depósito e indicadores

**Files:**
- Modify: `godot/scripts/Player.gd` (`_procesar_deconstruccion`, `_completar_construccion`, `_procesar_frutos`)
- Modify: `godot/scripts/PanelPuesto.gd` (`_actualizar`)

**Interfaces:**
- Consumes: `mundo.edificio_metadata` (`int -> Dictionary`, `VoxelWorld`), `Economia.desactivar_puesto/reactivar_puesto/puesto_con_deposito/retirar_deposito`, `Recoleccion.SIN_PUESTO`, `Economia.puestos[esquina]["activo"|"agotado"]`.
- Produces: comportamiento de juego; sin API nueva.

Sin prueba unitaria propia: las piezas puras están probadas (Tarea 1 TEST 8 el ciclo de `VoxelWorld`; Tarea 2 la lógica de `Economia`). Se verifica con arranque headless y con la verificación manual de la Tarea 6.

- [ ] **Step 1: Desactivar al empezar a deconstruir y eliminar por la esquina del puesto**

En `Player._procesar_deconstruccion`, tras `Ciudad.retirar_edificio_residencial(resultado["id"])  # idempotente` añade:

```gdscript
	var metadata_obra: Dictionary = mundo.edificio_metadata.get(resultado["id"], {})
	if metadata_obra.has("puesto"):
		Economia.desactivar_puesto(metadata_obra["puesto"])  # idempotente: un puesto en deconstrucción deja de funcionar
```

y reemplaza el bloque de remoción final:

```gdscript
	if _ticks_listo_para_remocion >= TICKS_REMOCION_FINAL:
		var esquina: Vector2i = mundo.eliminar_edificio(id)
		Zonificacion.retirar_contribucion(id)
```

por:

```gdscript
	if _ticks_listo_para_remocion >= TICKS_REMOCION_FINAL:
		var metadata_final: Dictionary = mundo.edificio_metadata.get(id, {})  # eliminar_edificio() la borra
		var esquina: Vector2i = mundo.eliminar_edificio(id)
		if metadata_final.has("puesto"):
			esquina = metadata_final["puesto"]  # la esquina del puesto, no la de las celdas de la plantilla
		Zonificacion.retirar_contribucion(id)
```

(las líneas `Recoleccion.quitar_puesto(esquina)` y `Economia.quitar_puesto(esquina)` que siguen no cambian).

- [ ] **Step 2: Reactivar al volver a completar la obra**

En `Player._completar_construccion`, tras `if metadata.is_empty(): return` añade:

```gdscript
	if metadata.has("puesto"):
		Economia.reactivar_puesto(metadata["puesto"])
		print("Puesto reactivado en ", metadata["puesto"], ".")
		return
```

y actualiza el comentario de cabecera de la función: ya no dice que un puesto «no pasaría por este registro»; ahora un puesto completado reactiva su `Economia` y sale.

- [ ] **Step 3: `E` sobre el baúl del puesto**

En `Player._procesar_frutos`, tras `var celda := _celda_impactada()` inserta:

```gdscript
	var esquina_deposito: Vector2i = Economia.puesto_con_deposito(celda)
	if esquina_deposito != Recoleccion.SIN_PUESTO:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		var tomado: Dictionary = Economia.retirar_deposito(esquina_deposito)
		if not tomado.is_empty():
			print("Tomado del depósito del puesto: ", tomado)
		return
```

y actualiza el comentario de la función («Frutos: mantener E sobre un árbol con frutos…») para añadir «o sobre el baúl de un puesto: pasa al inventario lo que quepa del almacén local».

- [ ] **Step 4: Panel del puesto**

En `PanelPuesto._actualizar`, reemplaza:

```gdscript
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"])
```

por:

```gdscript
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"]) + estado
```

y reemplaza las dos líneas de `disabled` de los botones `+`:

```gdscript
	_filas["recolector"]["mas"].disabled = sin_cupo
	_filas["acarreador"]["mas"].disabled = sin_cupo
```

por:

```gdscript
	_filas["recolector"]["mas"].disabled = sin_cupo or not puesto["activo"] or puesto["agotado"]
	_filas["acarreador"]["mas"].disabled = sin_cupo or not puesto["activo"]
```

- [ ] **Step 5: Arranque headless**

Run: `"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"`
Expected: sin salida.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Player.gd godot/scripts/PanelPuesto.gd
git commit -m "feat: desactivar, reactivar y depósito de puestos en Player y panel

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Documentación, verificación completa y verificación manual

**Files:**
- Create: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md`
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` (Sección 3, «Área de Acción de los Puestos de Recolección»: viñeta «Producción y Acarreo»)
- Modify: `docs/Pendientes y próximos pasos.md` (mover el punto 1 a «Hecho»; ver restricción de Global Constraints)
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md` (una línea que apunte al nuevo documento en «Fuera de Alcance / Siguiente»)

**Interfaces:** ninguna (documentación y verificación).

- [ ] **Step 1: Documento técnico nuevo**

Crea `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md` con la estructura del documento de la Fase 2A (Identificador `POC-05-ECONOMIA-EDIFICIOS`, motor, dependencias, enlace a la spec y a este plan) y las secciones: **1. Ideación** (objetivo y decisiones del usuario del 2026-09-24, fuera de alcance: costo/obreros NPC, conversor `.obj`, HUD, 2C); **2. Planeación** (arquitectura: `PlantillasPuesto`, colocación con 4 giros, edificio completo, `Economia` `activo`/`agotado`/`servicio`/`deposito`, `Colonos` zona de servicio de radio 2, `Player`/`PanelPuesto`); **3. Desarrollo** (reglas: formato de capas y caracteres, convención de la puerta y el giro, validación de colocación, desactivar/reactivar, agotamiento —recolectores al recalcular; acarreadores al vaciarse el almacén—, depósito con `E`; pruebas `PlantillasPuestoTest`/`EconomiaTest`/`ColonosTest`; supuestos que el usuario puede corregir: almacén conservado mientras está inactivo, radio de servicio 2, plantillas provisionales). Copia los valores y nombres exactos de este plan.

- [ ] **Step 2: GDD**

En la viñeta **«Producción y Acarreo»** de la Sección 3, añade al final una frase: los puestos son edificios de bloques con plantilla (forma propia, puerta de servicio y baúl como depósito físico); un puesto que empieza a deconstruirse se desactiva y libera a sus trabajadores; un puesto cuyo área se agota despide a sus recolectores y conserva a los acarreadores hasta que se vacía su almacén local; enlaza al nuevo documento. Si el encabezado de la sección enumera el estado implementado, añade «edificios con plantilla».

- [ ] **Step 3: Documento de la Fase 2A**

En su sección «Fuera de Alcance / Siguiente», añade una viñeta que diga que los edificios de recolección con plantilla están **implementados** y apunte a `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md`.

- [ ] **Step 4: Pendientes**

Ejecuta `git status --short docs/` y `git diff --stat -- "docs/Pendientes y próximos pasos.md"`. Si el archivo **no** tiene cambios previos, mueve el punto «1. Edificios de recolección jugables reales» a «Hecho» con formato `~~**Edificios de recolección jugables reales** (2026-09-24).~~` + una frase de resumen y el enlace al documento nuevo, y renumera. Si ya tiene cambios sin commitear del usuario, no lo toques y avisa al usuario en el informe final.

- [ ] **Step 5: Verificación completa**

Run, una por una:

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/Test.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/PlantillasPuestoTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/ColonosTest.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"
```

Expected: cada prueba imprime su línea «pasaron correctamente» (8, 21 y 29 pruebas; `Test.tscn` la suya) y `Main.tscn` no imprime nada. Tras la ejecución, verifica con `Get-Process` (PowerShell) que no queden procesos `godot` huérfanos.

- [ ] **Step 6: Commit de documentación y de los `.uid` nuevos**

```bash
git add "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md" "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md"
git commit -m "docs: edificios de recolección con plantilla (documento técnico, GDD, 2A)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git status --short godot/scripts/PlantillasPuesto.gd.uid godot/scripts/PlantillasPuestoTest.gd.uid
```

Si `git status` muestra los `.uid` de `PlantillasPuesto.gd` y `PlantillasPuestoTest.gd` como nuevos, commitéalos aparte (`chore: uid de PlantillasPuesto y su prueba`). Si se modificó `docs/Pendientes y próximos pasos.md` en el Paso 4 y estaba limpio, inclúyelo en el commit de documentación.

- [ ] **Step 7: Verificación manual pendiente (avisar al usuario; requiere jugar en el editor de Godot 4.7)**

Anotar en el informe final que estas comprobaciones quedan por hacer a mano:

1. Colocar cada uno de los 4 puestos (`M`, `H`, `L`, `F`): se ve la plantilla de bloques con su puerta; `Ctrl` + rueda gira la puerta a los 4 lados; la colocación se rechaza con mensaje si la puerta da a agua, acantilado u otro puesto. La pesca cae con el edificio en el extremo de tierra en los 4 giros.
2. Contratar recolectores y acarreadores desde el panel: se reparten por la zona junto a la puerta, producen y acarrean.
3. Mantener `E` apuntando al baúl del puesto pasa al inventario lo que quepa del almacén local.
4. Deconstruir (`G`): al quitar el primer bloque (el baúl) el panel dice «(inactivo)», los trabajadores vuelven a desempleado y los `[+]` se deshabilitan; al terminar de deconstruir, el puesto desaparece; al volver a completar la obra se reactiva.
5. Agotar el área (talar el bosque de un maderero o minar la veta de una mina): tras el siguiente recálculo el panel dice «(agotado)», los recolectores quedan libres, los acarreadores siguen hasta vaciar el almacén y luego también quedan libres.

---

## Self-Review (contra la spec)

- **§1 Plantillas** → Tarea 1 (datos, formato, rotación, celda de servicio, depósito, validaciones en TEST 1–7).
- **§2 Colocación** → Tarea 4 (4 giros, validación de celdas libres con `verificar_huella_libre`, celda de servicio, pesca en el extremo de tierra, `registrar_edificio_completo`). La verificación previa pedida en la spec («cómo se deconstruye hoy un puesto») queda resuelta: hoy un puesto se registraba con `registrar_edificio()` sin `edificio_orden`, así que `procesar_deconstruccion` devolvía `{}` y no se podía deconstruir; ahora sí.
- **§3 Desactivar/reactivar** → Tarea 2 (`desactivar_puesto`/`reactivar_puesto`, TEST 19) y Tarea 5 (enganches en `Player`, eliminación por la esquina de la metadata en lugar de la esquina mínima de las celdas).
- **§4 Agotamiento** → Tarea 2 (TEST 21) y Tarea 3 (TEST 28–29: la carga en camino se entrega).
- **§5 Puerta y depósito** → Tarea 2 (`servicio_de`, `retirar_deposito`), Tarea 3 (zona de servicio) y Tarea 5 (`E` sobre el baúl). **Desviación de la spec, ya reflejada en ella:** la spec decía «una sola celda de servicio»; el plan usa una **zona** de radio 2 porque `Colonos.ocupadas` no admite dos colonos por celda.
- **§6 Pruebas y documentación** → Tareas 1–3 y 6.
- **Consistencia de nombres:** `desactivar_puesto`, `reactivar_puesto`, `servicio_de`, `puesto_con_deposito`, `retirar_deposito`, `trabajadores_liberados`, `SIN_SERVICIO`/`SIN_DEPOSITO`, `celda_de_servicio`, `celda_deposito`, `en_mundo`, `indice_extremo_agua` coinciden entre tareas. `Vector2i.MAX` (literal usado en `Colonos.gd`) es el valor de `Economia.SIN_SERVICIO`.
- **Sin placeholders:** todo paso de código muestra el código.
