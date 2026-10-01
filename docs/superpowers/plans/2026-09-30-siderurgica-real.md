# Siderúrgica real Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir la siderúrgica (hierro ×2 → acero ×1) en un edificio real colocable, con entrada y salida separadas, técnicos que la operan, acarreo de ida y vuelta, acero en el stock central y `bloque_acero`.

**Architecture:** La siderúrgica es un `tipo` más de `Economia.puestos` (reutiliza registro, cupo, asignación, almacén local, baúl, deconstrucción, panel y colocación en la cenital). La producción sale de `CadenaMinerales.procesar_tick()` sobre el almacén local en vez del entorno. El acarreador de la refinería hace un ciclo núcleo → entrada → salida → núcleo; `Colonos.gd` gana una máquina de fases propia para ese rol. `bloque_acero` es una tarea independiente al final.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), pruebas con `assert()` en escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-30-siderurgica-real-design.md`

## Global Constraints

- Tabulaciones en GDScript, español en comentarios, mensajes y pruebas (`CLAUDE.md`).
- No tocar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python.
- Cambios pequeños; no reformatear código ajeno. No mezclar PoC.
- Almacén local de la siderúrgica: **1000** (igual que los puestos), compartido entre hierro y acero.
- Personal máximo: **3** (`CadenaMinerales.PERSONAL_MAXIMO_REFINERIA_HIERRO`). Operarios de producción: rol `tecnico` (tipo de población `tecnico`); acarreadores: rol `acarreador` (tipo `obrero`).
- Técnicos: asignar un desempleado lo pasa a `tecnico` (`Ciudad.reasignar_tipo("desempleado", "tecnico")`); sin formación previa (placeholder).
- Receta: hierro ×2 → acero ×1, `tasa_base` 2.0 (`CadenaMinerales.RECETAS["hierro"]`), sin cambios.
- `bloque_acero`: **3 acero** por bloque colocado (cobrado y reembolsado igual que `bloque_piedra`).
- Las `mcp__godot__get_uid/save_scene/export_mesh_library` están rotas: regenerar `BlockLibrary.res` con un script headless (memoria `feedback_godot_editor_bridge_broken`).
- Verificación: solo las `*Test.tscn` relacionadas con cada tarea, más `Test.tscn` al final (`CLAUDE.md` y memoria `feedback_scoped_test_runs`). Trabajar en la rama `siderurgica-real`, no en `main`.

### Cómo correr una escena de prueba (Bash)

Las escenas headless nunca terminan solas y un `assert()` fallido no detiene el script (memoria `feedback_godot_headless_testing`). Siempre con `timeout` y buscando fallos en la salida completa:

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
cd /c/Users/peraz/Projects/Misc/CityCraft
timeout -k 5 40 "$GD" --headless --path godot scenes/EconomiaTest.tscn > /tmp/out.txt 2>&1
grep -c -E "Assertion failed|SCRIPT ERROR|Parse Error" /tmp/out.txt   # esperado: 0
tail -3 /tmp/out.txt                                                   # esperado: "Las N pruebas ... pasaron correctamente"
```

El código `124` del `timeout` es normal. Tras cada ejecución, comprueba con `Get-Process godot*` que no queden procesos huérfanos.

## Decisiones tomadas en este plan (confirmar con el usuario)

1. **Costo de construcción = los bloques de la plantilla**, igual que los puestos reales (`NiveladorTerreno.COSTO_POR_CELDA` por celda). Las constantes `COSTO_CONSTRUCCION_REFINERIA_*` de `CadenaMinerales.gd` no las usa nadie y quedan sin tocar; el spec decía "usar esos placeholders", pero el sistema real cobra por bloque.
2. **Material de muro `bloque_piedra`**, con una plantilla provisional de 5×5 y dos puertas en lados opuestos.
3. **Ubicación:** la regla "fuera de la zona de influencia" de los puestos periféricos **no se aplica** a las refinerías (el GDD las ubica en el núcleo industrial); basta suelo libre y plano.
4. **Categoría Industrial** del menú Construir (hoy "Próximamente") recibe el botón de la siderúrgica, con tecla `1`.
5. **`acero` no existe en `Ciudad.almacen`** (hoy `Economia.entregar()` lo descartaría): se agrega, con tope `LIMITE_BASE`.
6. Un acarreador de refinería solo viaja a retirar hierro si hay al menos `Economia.CARGA_MINIMA` (10) unidades que llevar, y solo viaja a recoger acero si hay al menos 10 acumuladas (o va de paso tras dejar hierro). Un resto menor de 10 de acero queda en el almacén local hasta acumular más.
7. `bloque_acero` pasa a ser la **10.ª casilla de la hotbar** (tecla `0`).

## Review Focus

- **Stock central sin hierro:** el acarreador no viaja en vacío ni se queda atascado (Task 4, TEST 39b).
- **Almacén local lleno (1000):** no se retira más hierro del stock central (Task 3, TEST 26).
- **Liberar a un acarreador que lleva hierro:** el hierro vuelve al stock central, no se pierde (Task 4, TEST 40).
- **Despedir a un técnico:** su tipo vuelve a desempleado y la demografía cuadra (hoy `_volver_a_desempleado` asume siempre obrero; Task 4, TEST 37).
- **Entrada y salida a distinto nivel de suelo:** la colocación se rechaza con el mensaje de "puertas" (Task 5, TEST 13).

## File Structure

- Modify `godot/scripts/Ciudad.gd`, `HUD.gd`: recurso `acero` en el stock central y su nombre (Task 1).
- Modify `godot/scripts/PlantillasPuesto.gd`: puertas de entrada/salida, plantilla `siderurgica`, fachada de ambos lados (Task 2).
- Modify `godot/scripts/CadenaMinerales.gd`, `Recoleccion.gd`, `Economia.gd`: tipo, cupo, capacidad, roles, refinado, helpers de acarreo (Task 3).
- Modify `godot/scripts/Colonos.gd`: contratar técnicos, liberación, fases del acarreador de refinería (Task 4).
- Modify `godot/scripts/BarraModos.gd`, `CamaraCenital.gd`, `Player.gd`, `HUD.gd`, `PanelPuesto.gd`: colocación, registro y panel (Task 5).
- Modify `godot/scenes/BlockLibrarySource.tscn`, `godot/assets/BlockLibrary.res`, `VoxelWorld.gd`, `BlueprintValidator.gd`, `Hotbar.gd`, `NiveladorTerreno.gd`, `Player.gd` (Task 6).
- Docs (Task 7).
- Tests: `CiudadTest.gd`, `PlantillasPuestoTest.gd`, `EconomiaTest.gd`, `ColonosTest.gd`, `PuestosPrevisualizacionTest.gd`, `NiveladorTerrenoTest.gd` (+ `HUDTest.gd` si algún assert cambia).

---

### Task 1: `acero` en el stock central

**Files:**
- Modify: `godot/scripts/Ciudad.gd:202-214` y `:411`
- Modify: `godot/scripts/HUD.gd:33-42`
- Test: `godot/scripts/CiudadTest.gd:236-242`

**Interfaces:**
- Produces: `Ciudad.almacen["acero"]` (`Recurso`, cantidad 0, límite `LIMITE_BASE`); `HUD.NOMBRES_RECURSO["acero"] == "Acero"`. Lo consumen `Economia.entregar()` y las tareas 3 y 4.

- [ ] **Step 1: Cambiar la prueba para que falle**

En `CiudadTest.gd`, reemplaza el TEST 18 (líneas 236-242):

```gdscript
	print("\n=== TEST 18: el almacén tiene los 9 recursos de la economía ===")
	var ocho: Node = CiudadScript.new()
	for clave in ["madera", "comida", "hierro", "tierra", "piedra", "cobre", "carbon", "tierras_raras", "acero"]:
		assert(ocho.almacen.has(clave), "falta el recurso " + clave)
	assert(ocho.almacen.size() == 9)
	assert(ocho.almacen["acero"].cantidad == 0.0 and ocho.almacen["acero"].limite == 500.0, "el acero empieza en 0 con el tope inicial")
```

(las líneas siguientes del test, desde `assert(ocho.almacen["tierra"].cantidad == 0.0 ...`, se quedan como están).

- [ ] **Step 2: Correr y ver que falla**

Run: ver "Cómo correr una escena" con `scenes/CiudadTest.tscn`.
Expected: `grep -c "Assertion failed"` > 0 (falta `acero`).

- [ ] **Step 3: Implementar**

En `Ciudad.gd`, dentro del diccionario `almacen = {...}` (tras `"tierras_raras"`, línea 213):

```gdscript
		"tierras_raras": Recurso.new("Tierras raras", 0, LIMITE_BASE),
		"acero": Recurso.new("Acero", 0, LIMITE_BASE),  # lo produce la siderúrgica (ver Economia.gd)
```

En `Ciudad.gd:411` cambia el comentario `(una de las 8 del almacén)` por `(una de las 9 del almacén)`.

En `HUD.gd`, dentro de `NOMBRES_RECURSO` (tras `"tierras_raras"`):

```gdscript
	"tierras_raras": "Tierras raras",
	"acero": "Acero",
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `scenes/CiudadTest.tscn` y `scenes/HUDTest.tscn`.
Expected: 0 fallos en ambas; `CiudadTest` termina con "Las 22 pruebas de Ciudad pasaron correctamente".

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/HUD.gd godot/scripts/CiudadTest.gd
git commit -m "feat: acero en el stock central" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Plantilla de la siderúrgica con entrada y salida

**Files:**
- Modify: `godot/scripts/PlantillasPuesto.gd`
- Test: `godot/scripts/PlantillasPuestoTest.gd` (TEST 11 nuevo, antes de la línea final)

**Interfaces:**
- Produces:
  - `PlantillasPuesto.PLANTILLAS["siderurgica"]`, `MATERIAL["siderurgica"] == "bloque_piedra"`, huella 5×5, 4 capas.
  - `PlantillasPuesto.celda_de_servicio(tipo, giros) -> Vector2i` (ahora: celda frente a la **entrada**; sin cambios para los puestos de una puerta).
  - `PlantillasPuesto.celda_de_salida(tipo, giros) -> Vector2i` (frente a la **salida**; igual a la de servicio en los puestos de una puerta).
  - `PlantillasPuesto.fachada(tipo, giros)` cubre ambos lados.
  - Caracteres de plantilla: `e`/`E` entrada inferior/superior, `s`/`S` salida inferior/superior (mismos bloques que `d`/`D`).

- [ ] **Step 1: Escribir la prueba que falla**

En `PlantillasPuestoTest.gd`, antes de `print("\n=== Las 10 pruebas ...`, agrega y cambia el total a 11:

```gdscript
	print("\n=== TEST 11: la siderúrgica tiene entrada y salida separadas, en lados opuestos, y la fachada cubre ambos ===")
	assert(PlantillasPuesto.dimensiones("siderurgica") == Vector2i(5, 5))
	assert(PlantillasPuesto.MATERIAL["siderurgica"] == "bloque_piedra")
	var base11: Dictionary = PlantillasPuesto.celdas("siderurgica", 0)
	var puertas11 := 0
	for c11 in base11:
		if base11[c11] == "puerta_inferior":
			puertas11 += 1
	assert(puertas11 == 2, "dos puertas: entrada y salida")
	for giros11 in range(4):
		var h11: Vector2i = PlantillasPuesto.huella("siderurgica", giros11)
		var entrada11: Vector2i = PlantillasPuesto.celda_de_servicio("siderurgica", giros11)
		var salida11: Vector2i = PlantillasPuesto.celda_de_salida("siderurgica", giros11)
		assert(entrada11 != salida11, "entrada y salida son celdas distintas")
		for c11 in [entrada11, salida11]:
			assert(c11.x < 0 or c11.x >= h11.x or c11.y < 0 or c11.y >= h11.y, "las celdas de servicio quedan fuera de la huella")
		assert(absi(entrada11.x - salida11.x) + absi(entrada11.y - salida11.y) == 6, "lados opuestos: 5 de huella + 1")
		var fachada11: Array[Vector2i] = PlantillasPuesto.fachada("siderurgica", giros11)
		assert(fachada11.has(entrada11) and fachada11.has(salida11), "la fachada incluye ambas celdas de servicio")
		assert(fachada11.size() == 20, "2 columnas de fondo por los 5 de cada lado, en ambos lados (%d)" % fachada11.size())
	for tipo11 in TIPOS:
		for giros11 in range(4):
			assert(PlantillasPuesto.celda_de_salida(tipo11, giros11) == PlantillasPuesto.celda_de_servicio(tipo11, giros11), tipo11 + ": con una sola puerta, salida == servicio")

	print("\n=== Las 11 pruebas de PlantillasPuesto pasaron correctamente ===")
```

(borra la línea final antigua "Las 10 pruebas").

- [ ] **Step 2: Correr y ver que falla**

Run: `scenes/PlantillasPuestoTest.tscn`.
Expected: fallo/`SCRIPT ERROR` (no existe `siderurgica` ni `celda_de_salida`).

- [ ] **Step 3: Implementar**

En `PlantillasPuesto.gd`:

a) Añade los caracteres a `BLOQUES`:

```gdscript
const BLOQUES := {
	"V": "vidrio", "B": "baul",
	"d": "puerta_inferior", "D": "puerta_superior",
	# Edificios con entrada y salida separadas (refinerías y, más adelante, fábricas): las
	# cintas y tuberías futuras necesitan dos puertas. Mismo bloque que "d"/"D"; la letra
	# solo dice cuál es cuál (ver celda_de_servicio()/celda_de_salida()).
	"e": "puerta_inferior", "E": "puerta_superior",
	"s": "puerta_inferior", "S": "puerta_superior",
}
```

b) `MATERIAL` y `PLANTILLAS`:

```gdscript
	"siderurgica": "bloque_piedra",
```
(en `MATERIAL`), y en `PLANTILLAS`, tras `"pesca_frutos_mar"`:

```gdscript
	# Entrada (z = 0) y salida (z = 4) en lados opuestos; baúl como almacén local.
	"siderurgica": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##e##", "#...#", "#..B#", "#...#", "##s##"],
		["##E##", "V...V", "#...#", "V...V", "##S##"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
```

c) Reemplaza `celda_de_servicio()` (líneas 136-141) y `fachada()` (163-182) por:

```gdscript
## Primera celda base (sin girar) cuyo carácter esté en "caracteres" (p. ej. "de" =
## la puerta de entrada de cualquier tipo; "ds" = la de salida: en los puestos de una
## sola puerta, "d" sirve para las dos).
static func _buscar_caracter(tipo: String, caracteres: String) -> Vector3i:
	var capas: Array = PLANTILLAS[tipo]["capas"]
	for y in range(capas.size()):
		var filas: Array = capas[y]
		for z in range(filas.size()):
			var fila: String = filas[z]
			for x in range(fila.length()):
				if caracteres.contains(fila[x]):
					return Vector3i(x, y, z)
	assert(false, "la plantilla " + tipo + " no tiene " + caracteres)
	return Vector3i.ZERO


## Sentido (sin girar) en que "puerta" mira hacia afuera: el borde de la huella donde está.
static func _hacia_afuera(tipo: String, puerta: Vector3i) -> Vector3i:
	var d := dimensiones(tipo)
	if puerta.z == 0:
		return Vector3i(0, 0, -1)
	if puerta.z == d.y - 1:
		return Vector3i(0, 0, 1)
	if puerta.x == 0:
		return Vector3i(-1, 0, 0)
	return Vector3i(1, 0, 0)


## Celda local (X, Z) justo fuera de la puerta marcada con "caracteres", girada.
static func _celda_fuera(tipo: String, giros: int, caracteres: String) -> Vector2i:
	var puerta := _buscar_caracter(tipo, caracteres)
	var d := dimensiones(tipo)
	var fuera := _girar(Vector3i(puerta.x, 0, puerta.z) + _hacia_afuera(tipo, puerta), d.x, d.y, giros)
	return Vector2i(fuera.x, fuera.z)


## Celda local (X, Z) justo fuera de la puerta de entrada (la única, en un puesto
## de recolección), fuera de la huella girada.
static func celda_de_servicio(tipo: String, giros: int) -> Vector2i:
	return _celda_fuera(tipo, giros, "de")


## Celda local (X, Z) justo fuera de la puerta de salida; igual a celda_de_servicio()
## en los tipos de una sola puerta.
static func celda_de_salida(tipo: String, giros: int) -> Vector2i:
	return _celda_fuera(tipo, giros, "ds")
```

y `fachada()`:

```gdscript
## Columnas locales (X, Z) de la fachada: las 2 columnas delante de TODO el lado de
## la huella girada donde está cada puerta (entrada y salida), fuera de la huella (mismo
## criterio que NiveladorTerreno.calcular_base_y() para los blueprints). Se nivelan a la
## altura de la puerta y ahí se reserva el despeje de puertas y ventanas.
static func fachada(tipo: String, giros: int) -> Array[Vector2i]:
	var d := dimensiones(tipo)
	var h := huella(tipo, giros)
	var resultado: Array[Vector2i] = []
	var vistas := {}
	for caracteres in ["de", "ds"]:
		var puerta := _girar(_buscar_caracter(tipo, caracteres), d.x, d.y, giros)
		var servicio := _celda_fuera(tipo, giros, caracteres)
		var direccion := Vector2i(servicio.x - puerta.x, servicio.y - puerta.z)
		for x in range(h.x):
			for z in range(h.y):
				var columna := Vector2i(x, z)
				var vecina := columna + direccion
				if vecina.x >= 0 and vecina.x < h.x and vecina.y >= 0 and vecina.y < h.y:
					continue  # no es del borde del lado de la puerta
				for paso in range(1, 3):
					var candidata := columna + direccion * paso
					if not vistas.has(candidata):
						vistas[candidata] = true
						resultado.append(candidata)
	return resultado
```

`_buscar()` se conserva (la usan `celda_deposito()`).

- [ ] **Step 4: Correr y ver que pasa**

Run: `scenes/PlantillasPuestoTest.tscn`.
Expected: 0 fallos; "Las 11 pruebas de PlantillasPuesto pasaron correctamente". Los TEST 9 y 10 existentes (mina, caza, maderero, pesca) siguen verdes: el orden de las columnas de la fachada cambia solo por el bucle externo, no su contenido.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/PlantillasPuesto.gd godot/scripts/PlantillasPuestoTest.gd
git commit -m "feat: plantilla de la siderúrgica con entrada y salida separadas" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Economía de la refinería (roles, refinado y helpers de acarreo)

**Files:**
- Modify: `godot/scripts/CadenaMinerales.gd:20-26`
- Modify: `godot/scripts/Recoleccion.gd:29`, `:164-180`
- Modify: `godot/scripts/Economia.gd` (`ROLES`, `registrar_puesto`, `asignar`, `ultimo_de`, `produccion_por_hora`, `simular_hora`, helpers nuevos)
- Test: `godot/scripts/EconomiaTest.gd` (TESTS 24-26 nuevos)

**Interfaces:**
- Consumes: `Ciudad.almacen["acero"]` (Task 1); `CadenaMinerales.procesar_tick()/tasas_refinado()/RECETAS`.
- Produces (todas en `Economia`):
  - `const CARGA_MINIMA := 10.0`; `ROLES := ["recolector", "tecnico", "acarreador"]`.
  - `registrar_puesto(esquina, tipo, ancho, alto, tasas, entorno = {}, servicio = SIN_SERVICIO, deposito = SIN_DEPOSITO, suelo = SIN_SUELO, salida = SIN_SERVICIO)`.
  - `salida_de(esquina: Vector2i) -> Vector2i`; `es_refineria(esquina: Vector2i) -> bool`.
  - `insumo_de(esquina) -> String` (p. ej. `"hierro"`), `producto_de(esquina) -> String` (`"acero"`).
  - `insumo_a_cargar(esquina) -> float`, `cargar_insumo(esquina) -> Dictionary`, `descargar_insumo(esquina, carga: Dictionary) -> void`, `recoger_producto(esquina, capacidad: float) -> Dictionary`, `producto_pendiente(esquina) -> float`.
- Produce en `CadenaMinerales`: `const REFINERIAS := {"siderurgica": "hierro"}` (tipo de edificio → `tipo_entrada` de su receta).
- Los técnicos se guardan en la misma lista interna `"recolectores"` del puesto; `trabajadores_de()` los cuenta bajo `"recolectores"`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `EconomiaTest.gd`, junto a `ESQ` agrega la constante y el helper:

```gdscript
const ESQ_REF := Vector2i(30, 30)


## Una Economia con una siderúrgica de 5x5 en ESQ_REF: entrada al norte, salida al sur.
func _con_siderurgica(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(ESQ_REF, "siderurgica", 5, 5, {}, {}, Vector2i(32, 29), EconomiaScript.SIN_DEPOSITO, EconomiaScript.SIN_SUELO, Vector2i(32, 35))
	return economia
```

Antes de `print("\n=== Las 23 pruebas ...`, agrega y cambia el total a 26:

```gdscript
	print("\n=== TEST 24: la siderúrgica es una refinería con cupo 3, almacén de 1000 y roles técnico/acarreador ===")
	var ciudad24: Node = CiudadScript.new()
	var e24: Node = _con_siderurgica(ciudad24)
	assert(e24.es_refineria(ESQ_REF) and not e24.es_refineria(Vector2i(0, 0)))
	assert(e24.puestos[ESQ_REF]["cupo"] == 3 and e24.puestos[ESQ_REF]["capacidad"] == 1000)
	assert(e24.insumo_de(ESQ_REF) == "hierro" and e24.producto_de(ESQ_REF) == "acero")
	assert(e24.salida_de(ESQ_REF) == Vector2i(32, 35) and e24.servicio_de(ESQ_REF) == Vector2i(32, 29))
	assert(e24.asignar(ESQ_REF, "tecnico", 1), "un técnico entra a la refinería")
	assert(not e24.asignar(ESQ_REF, "recolector", 2), "un recolector no entra a una refinería")
	assert(e24.asignar(ESQ_REF, "acarreador", 3))
	assert(e24.trabajadores_de(ESQ_REF)["recolectores"] == 1, "los técnicos cuentan bajo recolectores")
	assert(e24.ultimo_de(ESQ_REF, "tecnico") == 1 and e24.ultimo_de(ESQ_REF, "acarreador") == 3)
	var e24b: Node = _nueva(ciudad24)
	assert(not e24b.asignar(ESQ, "tecnico", 9), "un técnico no entra a un puesto de recolección")
	var e24c: Node = _nueva(ciudad24)
	e24c.registrar_puesto(Vector2i(60, 60), "siderurgica", 5, 5, {})
	assert(e24c.salida_de(Vector2i(60, 60)) == EconomiaScript.SIN_SERVICIO, "sin salida indicada, SIN_SERVICIO")

	print("\n=== TEST 25: refina hierro en acero según los técnicos presentes, sin producir de la nada ===")
	var ciudad25: Node = CiudadScript.new()
	var e25: Node = _con_siderurgica(ciudad25)
	e25.puestos[ESQ_REF]["almacen"]["hierro"] = 20.0
	e25.simular_hora()
	assert(e25.almacen_local(ESQ_REF) == {"hierro": 20.0}, "sin técnicos presentes no refina ni deja claves en 0")
	e25.asignar(ESQ_REF, "tecnico", 1)
	e25.asignar(ESQ_REF, "tecnico", 2)
	e25.marcar_presente(1, true)
	e25.simular_hora()
	# 1 técnico presente: consume 2 * 1 * 2.0 = 4 hierro y produce 2 acero.
	assert(is_equal_approx(e25.almacen_local(ESQ_REF)["hierro"], 16.0) and is_equal_approx(e25.almacen_local(ESQ_REF)["acero"], 2.0))
	e25.marcar_presente(2, true)
	e25.simular_hora()
	# 2 presentes: consume 8 hierro y produce 4 acero (más técnicos, más rápido).
	assert(is_equal_approx(e25.almacen_local(ESQ_REF)["hierro"], 8.0) and is_equal_approx(e25.almacen_local(ESQ_REF)["acero"], 6.0))
	assert(is_equal_approx(e25.produccion_por_hora(ESQ_REF)["acero"], 4.0), "el panel muestra 4 acero/h con 2 técnicos")
	e25.puestos[ESQ_REF]["almacen"] = {"acero": 5.0}
	e25.simular_hora()
	assert(e25.almacen_local(ESQ_REF) == {"acero": 5.0}, "sin hierro no pasa nada")
	e25.puestos[ESQ_REF]["activo"] = false
	e25.puestos[ESQ_REF]["almacen"] = {"hierro": 20.0}
	e25.simular_hora()
	assert(e25.almacen_local(ESQ_REF) == {"hierro": 20.0}, "una refinería inactiva no refina")

	print("\n=== TEST 26: helpers de acarreo: cargar insumo del stock central, descargarlo y recoger el producto ===")
	var ciudad26: Node = CiudadScript.new()
	var e26: Node = _con_siderurgica(ciudad26)
	ciudad26.almacen["hierro"].cantidad = 300.0
	assert(is_equal_approx(e26.insumo_a_cargar(ESQ_REF), 150.0), "tope de carga: CAPACIDAD_CARGA")
	var carga26: Dictionary = e26.cargar_insumo(ESQ_REF)
	assert(is_equal_approx(carga26["hierro"], 150.0) and is_equal_approx(ciudad26.almacen["hierro"].cantidad, 150.0), "sale del stock central")
	e26.descargar_insumo(ESQ_REF, carga26)
	assert(is_equal_approx(e26.almacen_local(ESQ_REF)["hierro"], 150.0))
	# Almacén local casi lleno (compartido con el producto): solo cabe lo que queda.
	e26.puestos[ESQ_REF]["almacen"] = {"hierro": 900.0, "acero": 70.0}
	assert(is_equal_approx(e26.insumo_a_cargar(ESQ_REF), 30.0), "queda lugar para 30 de 1000")
	e26.puestos[ESQ_REF]["almacen"] = {"hierro": 900.0, "acero": 100.0}
	assert(e26.insumo_a_cargar(ESQ_REF) == 0.0 and e26.cargar_insumo(ESQ_REF).is_empty(), "almacén lleno: no se retira hierro")
	ciudad26.almacen["hierro"].cantidad = 0.0
	e26.puestos[ESQ_REF]["almacen"] = {}
	assert(e26.insumo_a_cargar(ESQ_REF) == 0.0, "stock central sin hierro: nada que cargar")
	# Lo que no cabe al descargar vuelve al stock central (no se pierde).
	e26.puestos[ESQ_REF]["almacen"] = {"acero": 990.0}
	e26.descargar_insumo(ESQ_REF, {"hierro": 40.0})
	assert(is_equal_approx(e26.almacen_local(ESQ_REF)["hierro"], 10.0) and is_equal_approx(ciudad26.almacen["hierro"].cantidad, 30.0))
	# Producto: se recoge hasta la capacidad de carga.
	e26.puestos[ESQ_REF]["almacen"] = {"hierro": 5.0, "acero": 200.0}
	assert(is_equal_approx(e26.producto_pendiente(ESQ_REF), 200.0))
	var producto26: Dictionary = e26.recoger_producto(ESQ_REF, e26.CAPACIDAD_CARGA)
	assert(producto26 == {"acero": 150.0} and is_equal_approx(e26.almacen_local(ESQ_REF)["acero"], 50.0), "solo el producto, hasta 150")
	assert(e26.recoger_producto(Vector2i(0, 0), 150.0).is_empty(), "puesto inexistente")

	print("\n=== Las 26 pruebas de Economia pasaron correctamente ===")
```

(borra la línea final antigua "Las 23 pruebas").

- [ ] **Step 2: Correr y ver que falla**

Run: `scenes/EconomiaTest.tscn`.
Expected: `SCRIPT ERROR`/`Assertion failed` (no existe `es_refineria`, etc.).

- [ ] **Step 3: Implementar**

**`CadenaMinerales.gd`** — reemplaza las líneas 18-26 por:

```gdscript
## Tipo de edificio -> tipo_entrada de su receta (clave de RECETAS). Una refinería es un
## puesto de Economia con tipo en este diccionario (ver Economia.es_refineria()).
const REFINERIAS := {"siderurgica": "hierro"}

# GDD Sección 4 — mismos valores placeholder que los puestos periféricos
# (Recoleccion.COSTO_CONSTRUCCION), sin balance real todavía. El costo REAL de
# construir una refinería es el de los bloques de su plantilla (ver PlantillasPuesto).
const COSTO_CONSTRUCCION_REFINERIA_HIERRO := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_REFINERIA_HIERRO := 3
const CAPACIDAD_ALMACENAMIENTO_REFINERIA_HIERRO := 1000  # igual que los puestos; hierro y acero lo comparten

const COSTO_CONSTRUCCION_REFINERIA_TIERRAS_RARAS := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_REFINERIA_TIERRAS_RARAS := 3
const CAPACIDAD_ALMACENAMIENTO_REFINERIA_TIERRAS_RARAS := 1000
```

**`Recoleccion.gd`**:
- Línea 29: `const TIPOS_PUESTO_TRABAJO := ["mina", "caza_recoleccion", "maderero", "pesca_frutos_mar", "siderurgica"]`
- En `cupo_de()` agrega antes del `return 0`: `"siderurgica": return CadenaMinerales.PERSONAL_MAXIMO_REFINERIA_HIERRO`
- En `capacidad_almacen_de()` agrega: `"siderurgica": return CadenaMinerales.CAPACIDAD_ALMACENAMIENTO_REFINERIA_HIERRO`

**`Economia.gd`**:

a) Constantes (reemplaza `const ROLES` y agrega `CARGA_MINIMA` tras `CAPACIDAD_CARGA`):

```gdscript
## Mínimo de unidades que justifica un viaje del acarreador de una refinería (retirar insumo
## del stock central o recoger producto): evita viajes de 1 unidad. ponytail: un resto menor
## de este valor queda en el almacén local hasta acumular más.
const CARGA_MINIMA := 10.0

## "tecnico" solo existe en las refinerías (opera la receta); "recolector" solo en los puestos de
## recolección. "acarreador" vale en ambos.
const ROLES := ["recolector", "tecnico", "acarreador"]
```

b) `registrar_puesto()` — agrega el parámetro `salida` y la clave:

```gdscript
func registrar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int, tasas: Dictionary, entorno: Dictionary = {}, servicio: Vector2i = SIN_SERVICIO, deposito: Vector3i = SIN_DEPOSITO, suelo: int = SIN_SUELO, salida: Vector2i = SIN_SERVICIO) -> void:
	puestos[esquina] = {
		...
		"servicio": servicio, "deposito": deposito, "suelo": suelo,
		"salida": salida,
	}
```
(solo se añaden `salida: Vector2i = SIN_SERVICIO` al final de la firma y la línea `"salida": salida,`; el resto del diccionario no cambia). Actualiza el comentario de la función: `"salida" (X, Z) es la celda frente a la puerta de salida de una refinería (la de entrada es "servicio"); SIN_SERVICIO en los puestos de una sola puerta.`

c) `asignar()` y `ultimo_de()`:

```gdscript
func asignar(esquina: Vector2i, rol: String, colono_id: int) -> bool:
	if not puestos.has(esquina) or not ROLES.has(rol) or _puesto_de.has(colono_id):
		return false
	if rol != "acarreador" and (rol == "tecnico") != es_refineria(esquina):
		return false  # técnicos solo en refinerías, recolectores solo en puestos de recolección
	var p: Dictionary = puestos[esquina]
	if not p["activo"] or (p["agotado"] and rol == "recolector"):
		return false  # inactivo (se está deconstruyendo) o agotado: sin recolectores nuevos
	if cupo_libre(esquina) <= 0:
		return false
	p[_lista_de(rol)].append(colono_id)
	_puesto_de[colono_id] = esquina
	return true
```

```gdscript
func ultimo_de(esquina: Vector2i, rol: String) -> int:
	if not puestos.has(esquina):
		return -1
	var lista: Array = puestos[esquina][_lista_de(rol)]
	return lista.back() if not lista.is_empty() else -1


## Lista interna donde vive cada rol: los técnicos comparten la de los recolectores (el cupo y la
## presencia funcionan igual; en una refinería son quienes operan la receta).
static func _lista_de(rol: String) -> String:
	return "acarreadores" if rol == "acarreador" else "recolectores"
```

d) `produccion_por_hora()` — al inicio, tras el `if not puestos.has(esquina): return resultado`:

```gdscript
	if es_refineria(esquina):
		var tasas_ref: Dictionary = CadenaMinerales.tasas_refinado({insumo_de(esquina): puestos[esquina]["presentes"].size()})
		for entrada in tasas_ref:
			resultado[tasas_ref[entrada]["tipo_salida"]] = tasas_ref[entrada]["produccion"]
		return resultado
```

e) `simular_hora()` — tras `_liberar_acarreadores_si_agotado(esquina)`:

```gdscript
		if es_refineria(esquina):
			_refinar(esquina)
			continue
```

f) Funciones nuevas (tras `servicio_de()`/`suelo_de()`):

```gdscript
## Celda (X, Z) frente a la puerta de salida de una refinería o SIN_SERVICIO.
func salida_de(esquina: Vector2i) -> Vector2i:
	return puestos[esquina]["salida"] if puestos.has(esquina) else SIN_SERVICIO


## true si el puesto es una refinería (CadenaMinerales.REFINERIAS): produce a partir de su almacén
## local con una receta, en vez de extraer del entorno.
func es_refineria(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and CadenaMinerales.REFINERIAS.has(puestos[esquina]["tipo"])


## Recurso que consume la refinería (tipo_entrada de su receta, p. ej. "hierro").
func insumo_de(esquina: Vector2i) -> String:
	return CadenaMinerales.REFINERIAS[puestos[esquina]["tipo"]]


## Recurso que produce la refinería (p. ej. "acero").
func producto_de(esquina: Vector2i) -> String:
	return CadenaMinerales.RECETAS[insumo_de(esquina)]["tipo_salida"]


## Una hora de refinado: los técnicos presentes consumen insumo del almacén local y lo convierten
## en producto (CadenaMinerales.procesar_tick()). No hay nada que hacer sin ellos. Si el resultado
## no cupiera en el almacén (compartido entre insumo y producto), esa hora no se refina.
## ponytail: todo o nada al llenarse; con las recetas actuales (2 -> 1, 3 -> 1) el total nunca crece,
## así que solo importaría para una receta que multiplique (aserradero).
func _refinar(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	if presentes <= 0:
		return
	var resultado: Dictionary = CadenaMinerales.procesar_tick(1.0, p["almacen"], {insumo_de(esquina): presentes})
	if _total(resultado) > p["capacidad"] + 1e-9:
		return
	for recurso in resultado.keys():
		if resultado[recurso] <= 1e-9:
			resultado.erase(recurso)
	p["almacen"] = resultado


## Unidades de insumo que un acarreador retiraría ahora del stock central para esta refinería: lo que
## quepa en su almacén local, hasta CAPACIDAD_CARGA y lo disponible. 0.0 si no es refinería.
func insumo_a_cargar(esquina: Vector2i) -> float:
	if not es_refineria(esquina):
		return 0.0
	var p: Dictionary = puestos[esquina]
	var disponible: float = ciudad.almacen[insumo_de(esquina)].cantidad
	return maxf(0.0, minf(minf(CAPACIDAD_CARGA, p["capacidad"] - _total(p["almacen"])), disponible))


## El acarreador retira insumo del stock central (ver insumo_a_cargar()). {} si no hay nada que llevar.
func cargar_insumo(esquina: Vector2i) -> Dictionary:
	var cantidad: float = insumo_a_cargar(esquina)
	if cantidad <= 1e-9:
		return {}
	var insumo: String = insumo_de(esquina)
	var sacado: float = ciudad.almacen[insumo].quitar(cantidad)
	return {insumo: sacado} if sacado > 1e-9 else {}


## El acarreador deja su carga en el almacén local; lo que ya no cupiera vuelve al stock central.
func descargar_insumo(esquina: Vector2i, carga: Dictionary) -> void:
	if not puestos.has(esquina):
		entregar(carga)
		return
	var p: Dictionary = puestos[esquina]
	for recurso in carga:
		var cabe: float = minf(carga[recurso], maxf(0.0, p["capacidad"] - _total(p["almacen"])))
		if cabe > 1e-9:
			p["almacen"][recurso] = p["almacen"].get(recurso, 0.0) + cabe
		if carga[recurso] - cabe > 1e-9:
			entregar({recurso: carga[recurso] - cabe})


## Producto refinado esperando en el almacén local.
func producto_pendiente(esquina: Vector2i) -> float:
	if not es_refineria(esquina):
		return 0.0
	return puestos[esquina]["almacen"].get(producto_de(esquina), 0.0)


## El acarreador recoge el producto (nada más) hasta "capacidad". Sin mínimo: el mínimo lo decide
## Colonos al elegir si vale la pena el viaje. {} si no hay nada.
func recoger_producto(esquina: Vector2i, capacidad: float) -> Dictionary:
	var pendiente: float = producto_pendiente(esquina)
	var tomado: float = minf(pendiente, capacidad)
	if tomado <= 1e-9:
		return {}
	var producto: String = producto_de(esquina)
	var local: Dictionary = puestos[esquina]["almacen"]
	local[producto] -= tomado
	if local[producto] <= 1e-9:
		local.erase(producto)
	return {producto: tomado}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `scenes/EconomiaTest.tscn`, `scenes/RecoleccionTest.tscn`, `scenes/CadenaMineralesTest.tscn`.
Expected: 0 fallos en las tres; Economía termina con "Las 26 pruebas de Economia pasaron correctamente". Si `RecoleccionTest` asserta el contenido de `TIPOS_PUESTO_TRABAJO`, actualízalo a incluir `"siderurgica"`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/CadenaMinerales.gd godot/scripts/Recoleccion.gd godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: economía de la refinería (técnicos, refinado y helpers de acarreo)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Colonos — técnicos y acarreo de ida y vuelta

**Files:**
- Modify: `godot/scripts/Colonos.gd:511-530` (`contratar`), `:555-574` (`_on_trabajadores_liberados`, `_volver_a_desempleado`), `:591-630` (`_decidir_trabajo`)
- Test: `godot/scripts/ColonosTest.gd` (TESTS 37-40 nuevos)

**Interfaces:**
- Consumes: todo lo de Economía de la Task 3 (`es_refineria`, `salida_de`, `insumo_a_cargar`, `cargar_insumo`, `descargar_insumo`, `recoger_producto`, `producto_pendiente`, `CARGA_MINIMA`, `CAPACIDAD_CARGA`).
- Produces: `Colonos.contratar(esquina, "tecnico")` (colono y demografía pasan a `tecnico`); fases del acarreador de refinería en `c["fase"]`: `""` (decide), `"cargar"`, `"entrada"`, `"salida"`, `"entregar"`; `Colonos._decidir_acarreo_refineria(c, esquina, huella, entrada, salida)`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `ColonosTest.gd`, junto a `_nuevo_con_puesto()` agrega:

```gdscript
## Colonos con una siderúrgica de 2x2 en (2, 2): entrada al norte (2, 1), salida al sur (3, 4);
## mundo llano de 10x10 y el núcleo en (7..8, 7..8). Sin plantilla (suelo desconocido): los colonos esperan fuera.
func _nuevo_con_siderurgica(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(Vector2i(2, 2), "siderurgica", 2, 2, {}, {}, Vector2i(2, 1), economia.SIN_DEPOSITO, economia.SIN_SUELO, Vector2i(3, 4))
	var colonos: Node = _nuevo(_mundo_llano(), ciudad)
	colonos.economia = economia
	return colonos
```

Antes de `print("\n=== Las 36 pruebas ...`, agrega y cambia el total a 40:

```gdscript
	print("\n=== TEST 37: un técnico pasa a tecnico al contratarlo y vuelve a desempleado al despedirlo ===")
	var ciudad37: Node = CiudadScript.new()
	var colonos37: Node = _nuevo_con_siderurgica(ciudad37)
	var id37: int = colonos37.agregar_colono("desempleado", Vector3i(6, 1, 1))
	ciudad37.demografia["desempleado"] = 1
	assert(not colonos37.contratar(Vector2i(2, 2), "recolector"), "una refinería no acepta recolectores")
	assert(ciudad37.demografia["desempleado"] == 1, "el rechazo no toca la demografía")
	assert(colonos37.contratar(Vector2i(2, 2), "tecnico"))
	assert(colonos37.colonos[id37]["tipo"] == "tecnico" and ciudad37.demografia["tecnico"] == 1 and ciudad37.demografia["desempleado"] == 0)
	assert(colonos37.despedir(Vector2i(2, 2), "tecnico"))
	assert(colonos37.colonos[id37]["tipo"] == "desempleado" and ciudad37.demografia["tecnico"] == 0 and ciudad37.demografia["desempleado"] == 1, "el técnico despedido vuelve a desempleado")

	print("\n=== TEST 38: un técnico camina a la siderúrgica, queda presente y refina ===")
	var ciudad38: Node = CiudadScript.new()
	var colonos38: Node = _nuevo_con_siderurgica(ciudad38)
	colonos38.agregar_colono("desempleado", Vector3i(6, 1, 1))
	ciudad38.demografia["desempleado"] = 1
	assert(colonos38.contratar(Vector2i(2, 2), "tecnico"))
	var llego38 := false
	for i in range(400):
		colonos38.avanzar(0.1)
		if colonos38.economia.trabajadores_de(Vector2i(2, 2))["presentes"] == 1:
			llego38 = true
			break
	assert(llego38, "el técnico llega junto a la entrada y se marca presente")
	colonos38.economia.puestos[Vector2i(2, 2)]["almacen"]["hierro"] = 20.0
	colonos38.economia.simular_hora()
	assert(is_equal_approx(colonos38.economia.almacen_local(Vector2i(2, 2))["acero"], 2.0), "1 técnico: 4 hierro -> 2 acero por hora")

	print("\n=== TEST 39: el acarreador lleva hierro del núcleo a la entrada y trae el acero de la salida al núcleo ===")
	var ciudad39: Node = CiudadScript.new()
	var colonos39: Node = _nuevo_con_siderurgica(ciudad39)
	ciudad39.almacen["hierro"].cantidad = 50.0
	colonos39.economia.puestos[Vector2i(2, 2)]["almacen"]["acero"] = 20.0
	var id39: int = colonos39.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad39.demografia["desempleado"] = 1
	assert(colonos39.contratar(Vector2i(2, 2), "acarreador"))
	assert(colonos39.colonos[id39]["tipo"] == "obrero", "el acarreador es obrero")
	var entrego39 := false
	for i in range(3000):  # hasta 300 s de juego
		colonos39.avanzar(0.1)
		if ciudad39.almacen["acero"].cantidad >= 20.0:
			entrego39 = true
			break
	assert(entrego39, "el acero llega al stock central")
	assert(is_equal_approx(ciudad39.almacen["acero"].cantidad, 20.0))
	assert(is_equal_approx(ciudad39.almacen["hierro"].cantidad, 0.0), "todo el hierro salió del stock central")
	assert(is_equal_approx(colonos39.economia.almacen_local(Vector2i(2, 2))["hierro"], 50.0), "y quedó en el almacén de la siderúrgica")
	assert(not colonos39.economia.almacen_local(Vector2i(2, 2)).has("acero"), "no queda acero")
	assert(colonos39.colonos[id39]["carga"].is_empty())

	print("\n=== TEST 39b: sin hierro en el núcleo ni acero que recoger, el acarreador espera sin viajar ===")
	var ciudad39b: Node = CiudadScript.new()
	var colonos39b: Node = _nuevo_con_siderurgica(ciudad39b)
	var id39b: int = colonos39b.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad39b.demografia["desempleado"] = 1
	colonos39b.contratar(Vector2i(2, 2), "acarreador")
	var celda39b: Vector3i = colonos39b.colonos[id39b]["celda"]
	for i in range(200):
		colonos39b.avanzar(0.1)
	assert(colonos39b.colonos[id39b]["celda"] == celda39b and colonos39b.colonos[id39b]["fase"] == "", "no se mueve ni queda en una fase a medias")
	# Con 9 unidades de acero (< CARGA_MINIMA) tampoco justifica el viaje.
	colonos39b.economia.puestos[Vector2i(2, 2)]["almacen"]["acero"] = 9.0
	for i in range(200):
		colonos39b.avanzar(0.1)
	assert(colonos39b.colonos[id39b]["celda"] == celda39b, "un resto menor al mínimo no mueve al acarreador")

	print("\n=== TEST 40: si la siderúrgica se desactiva con hierro en camino, el acarreador lo devuelve al stock central ===")
	var ciudad40: Node = CiudadScript.new()
	var colonos40: Node = _nuevo_con_siderurgica(ciudad40)
	var id40: int = colonos40.agregar_colono("desempleado", Vector3i(4, 1, 4))
	ciudad40.demografia["desempleado"] = 1
	colonos40.contratar(Vector2i(2, 2), "acarreador")
	var acarreador40: Dictionary = colonos40.colonos[id40]
	acarreador40["fase"] = "entrada"
	acarreador40["carga"] = {"hierro": 30.0}
	var hierro40: float = ciudad40.almacen["hierro"].cantidad
	colonos40.economia.desactivar_puesto(Vector2i(2, 2))
	assert(acarreador40["fase"] == "entregar" and acarreador40.get("retirar_al_entregar", false), "con carga en cualquier fase, termina el viaje al núcleo")
	var devolvio40 := false
	for i in range(1500):
		colonos40.avanzar(0.1)
		if acarreador40["tipo"] == "desempleado":
			devolvio40 = true
			break
	assert(devolvio40, "devuelve la carga y queda libre")
	assert(is_equal_approx(ciudad40.almacen["hierro"].cantidad, hierro40 + 30.0), "el hierro volvió al stock central")
	assert(ciudad40.demografia["obrero"] == 0 and ciudad40.demografia["desempleado"] == 1)

	print("\n=== Las 40 pruebas de Colonos pasaron correctamente ===")
```

(borra la línea final antigua "Las 36 pruebas").

- [ ] **Step 2: Correr y ver que falla**

Run: `scenes/ColonosTest.tscn`.
Expected: fallos en TESTS 37-40 (`contratar(..., "tecnico")` deja al colono como obrero, etc.).

- [ ] **Step 3: Implementar**

En `Colonos.gd`:

a) `contratar()` — el tipo depende del rol (técnicos para refinerías):

```gdscript
## Contrata a un desempleado (el de id menor) para un puesto con un rol
## ("recolector", "tecnico" o "acarreador"): pasa a obrero (a técnico, si el rol es
## "tecnico") en Ciudad.demografia y en el colono. Falso si no hay desempleados, el puesto
## no existe, el rol no es de ese puesto o no tiene cupo.
func contratar(esquina: Vector2i, rol: String) -> bool:
	var desempleados: Array[int] = _ids_de_tipo("desempleado")
	if desempleados.is_empty():
		return false
	desempleados.sort()
	var id: int = desempleados[0]
	if not economia.asignar(esquina, rol, id):
		return false
	var tipo := "tecnico" if rol == "tecnico" else "obrero"
	ciudad.reasignar_tipo("desempleado", tipo)
	var c: Dictionary = colonos[id]
	c["tipo"] = tipo
	c["trabajo"] = {"puesto": esquina, "rol": rol}
	c["fase"] = ""
	c["carga"] = {}
	c["fallos_servicio"] = 0
	_dejar_lo_que_hacia(c)
	return true
```

b) `_on_trabajadores_liberados()` y `_volver_a_desempleado()`:

```gdscript
## Trabajadores liberados de un puesto que sigue en pie (agotado o desactivado):
## vuelven a desempleado, salvo un acarreador que lleva carga (producto o insumo), que
## primero termina el viaje y la entrega en el núcleo (ver _decidir_trabajo()).
func _on_trabajadores_liberados(ids: Array) -> void:
	for id in ids:
		if not colonos.has(id):
			continue
		var c: Dictionary = colonos[id]
		if not c["carga"].is_empty():
			c["fase"] = "entregar"
			c["retirar_al_entregar"] = true
		else:
			_volver_a_desempleado(c)


func _volver_a_desempleado(c: Dictionary) -> void:
	var tipo_previo: String = c["tipo"]
	c["trabajo"] = {}
	c["carga"] = {}
	c["fase"] = ""
	c["fallos_servicio"] = 0
	c["retirar_al_entregar"] = false
	c["tipo"] = "desempleado"
	ciudad.reasignar_tipo(tipo_previo, "desempleado")
	_dejar_lo_que_hacia(c)
```

(`_volver_a_desempleado` solo se llama sobre colonos con trabajo, es decir `obrero` o `tecnico`; antes asumía `obrero`).

c) `_decidir_trabajo()` — el rol productor incluye `tecnico`, y el acarreador de refinería delega. Reemplaza la línea `if c["trabajo"]["rol"] == "recolector":` por `if c["trabajo"]["rol"] != "acarreador":` y, justo después del bloque del recolector (antes de `if c["fase"] == "entregar":`), agrega:

```gdscript
	if economia.es_refineria(esquina):
		_decidir_acarreo_refineria(c, esquina, huella_puesto, servicio, economia.salida_de(esquina))
		return
```

Actualiza el comentario de `_decidir_trabajo()`: `un recolector o técnico va a su puesto y se queda (presente); un acarreador cicla puesto -> núcleo -> puesto (en una refinería, ver _decidir_acarreo_refineria())`.

d) Función nueva, tras `_decidir_trabajo()`:

```gdscript
## Acarreador de una refinería: núcleo (retira insumo) -> entrada (lo deja) -> salida (recoge el
## producto) -> núcleo (lo entrega). La fase "" decide si vale la pena un viaje: retirar insumo si
## hay al menos Economia.CARGA_MINIMA que llevar, o recoger producto si hay al menos esa cantidad
## acumulada; si no, espera donde está, sin viajar en vacío.
func _decidir_acarreo_refineria(c: Dictionary, esquina: Vector2i, huella: Array, entrada: Vector2i, salida: Vector2i) -> void:
	match c["fase"]:
		"entregar":
			if _llevar_al_nucleo(c):
				c["fase"] = ""
		"cargar":
			var nucleo: Array = zona.huella_del_nucleo()
			if not _junto_a(c["celda"], nucleo):
				_ir_junto_a(c, nucleo)
				return
			c["carga"] = economia.cargar_insumo(esquina)
			c["fase"] = "entrada" if not c["carga"].is_empty() else ""
		"entrada":
			if not _junto_a(c["celda"], huella, entrada):
				_ir_junto_a(c, huella, entrada)
				return
			economia.descargar_insumo(esquina, c["carga"])
			c["carga"] = {}
			c["fase"] = "salida"
		"salida":
			if not _junto_a(c["celda"], huella, salida):
				_ir_junto_a(c, huella, salida)
				return
			c["carga"] = economia.recoger_producto(esquina, economia.CAPACIDAD_CARGA)
			c["fase"] = "entregar" if not c["carga"].is_empty() else ""
			if c["carga"].is_empty():
				c["espera"] = ESPERA_TRABAJO
		_:
			if economia.insumo_a_cargar(esquina) >= economia.CARGA_MINIMA:
				c["fase"] = "cargar"
			elif economia.producto_pendiente(esquina) >= economia.CARGA_MINIMA:
				c["fase"] = "salida"
			else:
				c["espera"] = ESPERA_TRABAJO
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `scenes/ColonosTest.tscn`, `scenes/EconomiaTest.tscn`.
Expected: 0 fallos en ambas; Colonos termina con "Las 40 pruebas de Colonos pasaron correctamente". Los TESTS 18-36 existentes (acarreo de un solo sentido, liberación con carga) siguen verdes: con un puesto de recolección el flujo no entra a `_decidir_acarreo_refineria()`. Si TEST 39 agota los 300 s simulados, revisa que `_junto_a(..., entrada)` pueda cumplirse en el mundo de 10×10 (la entrada es (2, 1): las celdas a ≤2 de ella y fuera de la huella existen).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: técnicos y acarreo de ida y vuelta de la siderúrgica" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Colocar la siderúrgica desde la cenital

**Files:**
- Modify: `godot/scripts/BarraModos.gd:71`, `:80`
- Modify: `godot/scripts/CamaraCenital.gd` (`PUESTOS_PERIFERICO` ~1282, `_manejar_tecla_construir` ~1386, `_alternar_puesto_por_tipo` ~1475, `_actualizar_previsualizacion_puesto` ~963, `_evaluar_puesto` ~2185, `_confirmar_puesto` ~2381/2431)
- Modify: `godot/scripts/Player.gd:1086-1099`
- Modify: `godot/scripts/HUD.gd:219` (`texto_tasas`)
- Modify: `godot/scripts/PanelPuesto.gd`
- Test: `godot/scripts/PuestosPrevisualizacionTest.gd` (TEST 13 nuevo)

**Interfaces:**
- Consumes: `PlantillasPuesto` (Task 2), `Economia.registrar_puesto(..., salida)`, `CadenaMinerales.REFINERIAS` (Task 3).
- Produces: botón "Siderúrgica [1]" en Construir → Industrial; `puesto_nuevo["salida"]` en la metadata de la obra; `Economia` registra la refinería con `entorno {}` y `tasas {}`.

- [ ] **Step 1: Escribir la prueba que falla**

En `PuestosPrevisualizacionTest.gd`, antes de `print("\n=== Las 12 pruebas ...`, agrega y cambia el total a 13:

```gdscript
	print("\n=== TEST 13: la siderúrgica se evalúa como un puesto: válida en suelo plano, con fachada de entrada y salida, sin la regla de la zona de influencia ===")
	var mundo13: Node = _mundo_plano()
	var camara13: Camera3D = _camara(mundo13, "siderurgica")
	var esquina13 := Vector2i(10, 10)
	var ev13: Dictionary = camara13._evaluar_puesto(esquina13)
	assert(camara13._mensaje_rechazo_puesto(ev13) == "", "válida sobre suelo plano, salió: %s" % camara13._mensaje_rechazo_puesto(ev13))
	assert(ev13["fachada"].size() == 20, "fachada de ambos lados (%d)" % ev13["fachada"].size())
	var costo13: Dictionary = camara13._resumen_materiales_puesto(esquina13, ev13)["neto"]
	assert(costo13.get("piedra", 0) > 0, "construir una siderúrgica cuesta piedra (muros de bloque_piedra)")
	camara13.free()
	# Dentro de la zona de influencia: una mina se rechaza, la siderúrgica no.
	Zonificacion.declarar_nucleo([Vector2i(20, 20), Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)])
	var camara13b: Camera3D = _camara(mundo13, "mina")
	var ev13b: Dictionary = camara13b._evaluar_puesto(Vector2i(18, 18))
	assert("influencia" in camara13b._mensaje_rechazo_puesto(ev13b), "una mina no se coloca en la zona de influencia")
	camara13b.free()
	var camara13c: Camera3D = _camara(mundo13, "siderurgica")
	var ev13c: Dictionary = camara13c._evaluar_puesto(Vector2i(18, 18))
	assert(not ("influencia" in camara13c._mensaje_rechazo_puesto(ev13c)), "la siderúrgica sí puede ir en la zona de influencia")
	camara13c.free()
	Zonificacion.nucleo_declarado = false  # no contaminar otras pruebas de esta escena
	# Entrada y salida a distinto nivel de suelo: se rechaza como un blueprint con puertas desniveladas.
	for x13 in range(LADO):
		for z13 in range(15, LADO):
			mundo13.colocar_bloque(Vector3i(x13, 1, z13), "tierra")
	var camara13d: Camera3D = _camara(mundo13, "siderurgica")
	var ev13d: Dictionary = camara13d._evaluar_puesto(esquina13)
	assert(camara13d._mensaje_rechazo_puesto(ev13d) == CamaraCenitalScript.MENSAJES_BASE_Y["puertas"], "entrada y salida a distinto nivel: %s" % camara13d._mensaje_rechazo_puesto(ev13d))
	camara13d.free()
	mundo13.free()

	print("\n=== Las 13 pruebas de previsualización de puestos pasaron correctamente ===")
```

(borra la línea final antigua "Las 12 pruebas").

- [ ] **Step 2: Correr y ver que falla**

Run: `scenes/PuestosPrevisualizacionTest.tscn`.
Expected: fallo en TEST 13 (la rama `else` de `_actualizar_previsualizacion_puesto` y la regla de influencia aún tratan a `siderurgica` como un maderero).

- [ ] **Step 3: Implementar**

**`BarraModos.gd`** — línea 71 y 80:

```gdscript
	"industrial": [
		["siderurgica", "Siderúrgica", "1"],
	],
```
```gdscript
const TIPOS_CON_MINIATURA := ["residencial", "mina", "caza_recoleccion", "maderero", "pesca_frutos_mar", "siderurgica"]
```
Actualiza el comentario de `CATEGORIAS` (líneas 46-49): Industrial ya tiene la siderúrgica; solo Investigación sigue sin edificios.

**`CamaraCenital.gd`**:

1. Tras `const PUESTOS_PERIFERICO` (~1282):
```gdscript
const PUESTOS_INDUSTRIAL := ["siderurgica"]
```
2. `_manejar_tecla_construir()` — agrega al `match _categoria_construir:` tras `"periferico"`:
```gdscript
		"industrial":
			if n >= 1 and n <= PUESTOS_INDUSTRIAL.size():
				_alternar_puesto_por_tipo(PUESTOS_INDUSTRIAL[n - 1])
```
3. `_alternar_puesto_por_tipo()` — agrega al `match`:
```gdscript
		"siderurgica":
			var huella_ref: Vector2i = PlantillasPuesto.dimensiones(tipo)
			_alternar_modo_colocar_puesto(tipo, huella_ref.x, huella_ref.y)
```
4. `_actualizar_previsualizacion_puesto()` — antes del `else:` final (el del maderero, ~963) agrega:
```gdscript
		elif CadenaMinerales.REFINERIAS.has(_tipo_puesto_activo):
			_ocultar_area_accion()  # una refinería no tiene área de acción ni tasa de recolección
```
5. `_evaluar_puesto()` — la regla de zona de influencia no aplica a las refinerías:
```gdscript
		"en_influencia": Zonificacion.dentro_de_influencia(centro) and not CadenaMinerales.REFINERIAS.has(_tipo_puesto_activo),
```
6. `_confirmar_puesto()` — tras `var servicio: Vector2i = ...`:
```gdscript
	var salida: Vector2i = esquina + PlantillasPuesto.celda_de_salida(_tipo_puesto_activo, giros)
```
y en el diccionario `"puesto_nuevo"`, tras `"servicio": servicio,`:
```gdscript
				"salida": salida,
```

**`Player.gd`** — `_completar_construccion()`, rama `puesto_nuevo` (líneas 1088-1095): una refinería no tiene entorno que medir ni tasas de recolección (pasarle un entorno no vacío haría que `Recoleccion.tasas_de_entorno()` la tratara como un maderero):

```gdscript
		var info: Dictionary = metadata["puesto_nuevo"]
		var entorno: Dictionary = {}
		var tasas: Dictionary = {}
		if not CadenaMinerales.REFINERIAS.has(info["tipo"]):
			var centro: Vector2i = info["centro"]
			var altura: int = mundo.altura_en(centro.x, centro.y)
			entorno = Recoleccion.entorno_de_puesto(info["tipo"], mundo, centro, altura, info["centro_agua"])
			tasas = Recoleccion.tasas_de_entorno(info["tipo"], mundo, entorno)
		Recoleccion.colocar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"])
		# info["y_base"] es la Y de la losa de piso (capa 0, ver PlantillasPuesto.gd);
		# el piso interior TRANSITABLE (donde viven las puertas) es una capa arriba.
		Economia.registrar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"], tasas, entorno, info["servicio"], info["deposito"], info["y_base"] + 1, info.get("salida", Economia.SIN_SERVICIO))
```
(el resto de la rama —print, notificación, `erase`, `return`— no cambia). Actualiza el texto de la notificación solo si quieres distinguirla; no es necesario.

**`HUD.gd`** — `texto_tasas()`, agrega un caso al `match tipo:` (junto a `"maderero"`):

```gdscript
		"siderurgica":
			var t_ref: Dictionary = CadenaMinerales.tasas_refinado({"hierro": 1})["hierro"]
			return "Refinado previsto por técnico:\n  %.1f hierro/h → %.1f acero/h" % [t_ref["consumo"], t_ref["produccion"]]
```

**`PanelPuesto.gd`**:

a) `NOMBRES_PUESTO`: agrega `"siderurgica": "Siderúrgica",`.
b) `_ready()` — el bucle de filas: `for rol in ["recolector", "tecnico", "acarreador"]:`.
c) `_crear_fila()` — nombre por rol y guardar la fila:

```gdscript
const NOMBRES_ROL := {"recolector": "Recolectores", "tecnico": "Técnicos", "acarreador": "Acarreadores"}
```
(constante junto a `NOMBRES_PUESTO`), en `_crear_fila`: `var nombre := TemaHUD.etiqueta(NOMBRES_ROL[rol])` y al final `_filas[rol] = {"fila": fila, "cantidad": cantidad, "menos": menos, "mas": mas}`.
d) `_actualizar()` — reemplaza las líneas que usan `_filas["recolector"]` (108, 110, 113) por:

```gdscript
	var rol_produccion := "tecnico" if Economia.es_refineria(esquina) else "recolector"
	_filas["recolector"]["fila"].visible = rol_produccion == "recolector"
	_filas["tecnico"]["fila"].visible = rol_produccion == "tecnico"
	_filas[rol_produccion]["cantidad"].text = str(t["recolectores"])  # los técnicos cuentan bajo "recolectores"
	_filas["acarreador"]["cantidad"].text = str(t["acarreadores"])
	_filas[rol_produccion]["menos"].disabled = t["recolectores"] == 0
	_filas["acarreador"]["menos"].disabled = t["acarreadores"] == 0
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0 or libres <= 0
	_filas[rol_produccion]["mas"].disabled = sin_cupo or not puesto["activo"] or puesto["agotado"]
```
(`_filas["acarreador"]["mas"]` y el resto no cambian).
e) Actualiza el comentario de cabecera: "Recolectores/Técnicos".

- [ ] **Step 4: Correr y ver que pasa**

Run: `scenes/PuestosPrevisualizacionTest.tscn`, `scenes/HUDTest.tscn`, `scenes/PlantillasPuestoTest.tscn`, `scenes/CamaraCenitalModosTest.tscn`.
Expected: 0 fallos; Previsualización termina con "Las 13 pruebas ... pasaron correctamente". Si `HUDTest` o `CamaraCenitalModosTest` asertan que Industrial está vacío ("Próximamente") o la longitud de una lista, actualiza esos asserts (`_botones_construccion` ahora tiene `"siderurgica"`; la prueba existente `not _botones_construccion.has("industrial")` sigue válida).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BarraModos.gd godot/scripts/CamaraCenital.gd godot/scripts/Player.gd godot/scripts/HUD.gd godot/scripts/PanelPuesto.gd godot/scripts/PuestosPrevisualizacionTest.gd
git commit -m "feat: colocar y registrar la siderúrgica desde la cenital" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `bloque_acero`

Independiente del resto: puede hacerse antes o después, y se puede aplazar sin romper nada.

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn`, `godot/assets/BlockLibrary.res` (regenerada)
- Create (temporal, se borra): `godot/scripts/_bake_block_library.gd`
- Modify: `godot/scripts/NiveladorTerreno.gd:31-45`, `:260`
- Modify: `godot/scripts/VoxelWorld.gd:89-93`, `:1470-1472`
- Modify: `godot/scripts/BlueprintValidator.gd:527`
- Modify: `godot/scripts/Hotbar.gd:28-31`, `:44-46`, `:65-67`, `:232`
- Modify: `godot/scripts/Player.gd:83`, `:176-178`
- Test: `godot/scripts/NiveladorTerrenoTest.gd` (TEST 22 nuevo), `godot/scripts/HUDTest.gd` si cuenta casillas

**Interfaces:**
- Produces: bloque `bloque_acero` en la `MeshLibrary`, en `NiveladorTerreno.COSTO_POR_CELDA` (`{"acero": 3}`), en `TIPOS_BLOQUE_CONTABLE`, `VoxelWorld.TIPOS_ESTRUCTURA`, `BlueprintValidator.TIPOS_MURO_REAL`, y como 10.ª casilla de `Player.tipos_disponibles` (tecla `0`).

- [ ] **Step 1: Escribir la prueba que falla**

En `NiveladorTerrenoTest.gd`, antes de `print("\n=== Las 21 pruebas ...`, agrega y cambia el total a 22:

```gdscript
	print("\n=== TEST 22: bloque_acero cuesta 3 acero, cuenta como bloque contable y existe en la biblioteca ===")
	assert(NiveladorTerreno.COSTO_POR_CELDA["bloque_acero"] == {"acero": 3})
	assert(NiveladorTerreno.TIPOS_BLOQUE_CONTABLE.has("bloque_acero"))
	var bloques_22: Dictionary = nivelador_plano.contar_bloques({Vector3i(0, 0, 0): "bloque_acero", Vector3i(1, 0, 0): "bloque_acero"}, 0)
	assert(bloques_22["acero"] == 2, "cuenta bloques por recurso crudo")
	var biblioteca_22: MeshLibrary = load("res://assets/BlockLibrary.res")
	assert(biblioteca_22.find_item_by_name("bloque_acero") != -1, "la biblioteca tiene el bloque")
	assert(biblioteca_22.find_item_by_name("estructura_hierro") != -1, "y conserva los anteriores")

	print("\n=== Las 22 pruebas de NiveladorTerreno pasaron correctamente ===")
```

(borra la línea final antigua). Revisa en el test existente 21 cómo se llama la instancia (`nivelador_plano`) y úsala igual.

- [ ] **Step 2: Correr y ver que falla**

Run: `scenes/NiveladorTerrenoTest.tscn`. Expected: fallo (no existe `bloque_acero`).

- [ ] **Step 3: Implementar**

**a) `BlockLibrarySource.tscn`.** Añade al final de los `sub_resource` (tras `Shape_estructura_hierro`):

```
[sub_resource type="StandardMaterial3D" id="Mat_bloque_acero"]
albedo_color = Color(0.72, 0.76, 0.82, 1)

[sub_resource type="BoxMesh" id="Mesh_bloque_acero"]
material = SubResource("Mat_bloque_acero")

[sub_resource type="BoxShape3D" id="Shape_bloque_acero"]
```

y **al final del archivo** (los demás nodos conservan su orden, así los ids de los ítems existentes no cambian):

```
[node name="bloque_acero" type="MeshInstance3D" parent="." unique_id=900000101]
mesh = SubResource("Mesh_bloque_acero")

[node name="CollisionShape3D" type="CollisionShape3D" parent="bloque_acero" unique_id=900000102]
shape = SubResource("Shape_bloque_acero")
```

**b) Hornear la `MeshLibrary`.** Crea `godot/scripts/_bake_block_library.gd`:

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

Run (Bash):
```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
cd /c/Users/peraz/Projects/Misc/CityCraft
git show HEAD:godot/assets/BlockLibrary.res > /tmp/BlockLibrary_antes.res   # respaldo para comparar ítems
timeout -k 5 60 "$GD" --headless --path godot --script res://scripts/_bake_block_library.gd > /tmp/bake_output.txt 2>&1
cat /tmp/bake_output.txt
```
Expected: `Guardado con código: 0`; la lista tiene **un ítem más** que antes, `bloque_acero` al final, y conserva el mismo orden y nombres de los demás (compara con la lista del respaldo si dudas). Si el orden o el conteo no cuadran, no continúes: revisa el `.tscn`. Después: `rm godot/scripts/_bake_block_library.gd godot/scripts/_bake_block_library.gd.uid` (si se generó el `.uid`).

**c) `NiveladorTerreno.gd`:** en `COSTO_POR_CELDA` agrega `"bloque_acero": {"acero": 3},` tras `"estructura_hierro"`; y en `TIPOS_BLOQUE_CONTABLE` agrega `"bloque_acero"`.

**d) `VoxelWorld.gd`:** agrega `"bloque_acero"` a `TIPOS_ESTRUCTURA` (línea 90, tras `"estructura_hierro"`) y a la lista del grupo de muros de `ORDEN_GRUPOS_EDIFICIO` (línea 1471, tras `"estructura_hierro"`). Actualiza el comentario de las líneas 84-86 para nombrarlo.

**e) `BlueprintValidator.gd:527`:** `const TIPOS_MURO_REAL := ["adobe", "bloque_madera", "bloque_piedra", "estructura_hierro", "bloque_acero"]`.

**f) `Hotbar.gd`:** en `NOMBRES` `"bloque_acero": "Bloque de acero",`; en `NOMBRES_HOTBAR` `"bloque_acero": "Acero",`; en `DESCRIPCION`:

```gdscript
	"bloque_acero": ["Bloque de tipo estructural.", "Ideal para estructuras pesadas y muros blindados.", "Se obtiene refinando hierro en una siderúrgica."],
```
y en la línea 232 (etiqueta de la tecla) `str((i + 1) % 10)` para que la décima casilla muestre `0`.

**g) `Player.gd`:** línea 83, agrega `"bloque_acero"` **al final** de `tipos_disponibles` (índice 9, para no mover las teclas 1-9 ya aprendidas):

```gdscript
var tipos_disponibles := ["tierra", "adobe", "bloque_madera", "bloque_piedra", "estructura_hierro", "vidrio", "puerta", "cama", "baul", "bloque_acero"]
```
y en el manejo de teclas (línea ~176), para que `0` seleccione la décima casilla:

```gdscript
			var indice: int = 9 if tecla.keycode == KEY_0 else tecla.keycode - KEY_1
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `scenes/NiveladorTerrenoTest.tscn`, `scenes/ConstruccionTest.tscn`, `scenes/BlueprintsTest.tscn`, `scenes/HUDTest.tscn`, `scenes/MiniaturaRendererTest.tscn`.
Expected: 0 fallos. Si `HUDTest` asserta nueve casillas en la hotbar, actualízalo a diez.

- [ ] **Step 5: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scripts/NiveladorTerreno.gd godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidator.gd godot/scripts/Hotbar.gd godot/scripts/Player.gd godot/scripts/NiveladorTerrenoTest.gd godot/scripts/HUDTest.gd
git commit -m "feat: bloque_acero (3 acero por bloque) y décima casilla de la hotbar" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Documentación y verificación final

**Files:**
- Modify: `docs/Pendientes y próximos pasos.md` (ítem 4, parte 2)
- Modify: `docs/Fichas_Consumo_Produccion.md` (Secciones 3 y 4, tabla de extracción, Pendientes)
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`

- [ ] **Step 1: Actualizar `docs/Pendientes y próximos pasos.md`**

En el ítem 4, parte 2: marca la siderúrgica como hecha (2026-09-30) con una línea que describa lo implementado (edificio real con entrada/salida, técnicos, acarreo de ida y vuelta, acero en el stock, `bloque_acero` = 3 acero) y enlace al spec y al plan. Deja pendientes explícitos: refinería de tierras raras, aserradero y carbonera ("variantes de datos sobre el mismo mecanismo: entrada en `CadenaMinerales.REFINERIAS`, plantilla, nombre y botón").

- [ ] **Step 2: Actualizar `docs/Fichas_Consumo_Produccion.md`**

- Sección 3: la fila de la siderúrgica pasa a "Implementado (edificio real)", con nota: personal máximo 3 técnicos, almacén local 1000 compartido, entrada y salida separadas.
- Línea 93 y 114: quita "refinerías reales colocables" y el pendiente de `bloque_acero` (ya hay fuente de acero).
- Tabla de extracción: agrega la fila `bloque_acero` — 3 acero por bloque — Implementado.
- Sección 1/roles: anota que los técnicos operan las refinerías, que el origen es provisional (desempleado → técnico al asignarlo) y el riesgo de competir con los obreros por desempleados.
- Pendientes: la línea 161 mantiene Aserradero, Carbonera, etc., y quita nada de la siderúrgica; agrega "formación de técnicos" como pendiente.

- [ ] **Step 3: Actualizar el documento técnico de PoC 5**

Anota la decisión funcional: las refinerías son puestos con receta, entrada y salida separadas (preparadas para cintas y tuberías), técnicos como operarios y acarreo de ida y vuelta; incluye la fórmula de velocidad (`cantidad_entrada × técnicos × tasa_base` por hora) y el mínimo de viaje `CARGA_MINIMA`.

- [ ] **Step 4: Verificación final**

Run (cada una con el patrón de "Cómo correr una escena de prueba"): `Test.tscn`, `EconomiaTest`, `ColonosTest`, `PlantillasPuestoTest`, `PuestosPrevisualizacionTest`, `CiudadTest`, `NiveladorTerrenoTest`, `HUDTest`, `CamaraCenitalModosTest`, `RecoleccionTest`, `CadenaMineralesTest`.
Expected: 0 `Assertion failed`/`SCRIPT ERROR` en cada una, y cada escena imprime su línea final de éxito. Luego `Get-Process godot*` (PowerShell) para confirmar que no quedan procesos.

- [ ] **Step 5: Verificación manual (la hace el usuario jugando)**

Con el editor abierto, en la cenital: Construir → Industrial → Siderúrgica (tecla `1`). Comprobar: el fantasma muestra dos puertas en lados opuestos y la nivelación a ambos lados; se puede colocar dentro de la zona de influencia; al completarla aparece su panel con "Técnicos" y "Acarreadores"; con hierro en el stock, un técnico y un acarreador, el acero llega al stock central y se puede colocar `bloque_acero` con la tecla `0`.

- [ ] **Step 6: Commit**

```bash
git add docs "PoC_5"
git commit -m "docs: siderúrgica real (2C parte 2) y bloque_acero" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
