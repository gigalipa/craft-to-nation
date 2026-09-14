# Cadena de Minerales (PoC 5, sub-proyecto 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar un autoload de lógica pura (`CadenaMinerales.gd`) con las recetas de refinado `hierro→acero` y `tierras_raras→mineral_refinado`, una escena de pruebas automatizadas, y una escena de demostración interactiva para probar el balance en vivo — primer sub-proyecto del Catálogo de Recursos (GDD Sección 4).

**Architecture:** Mismo patrón que `Ciudad.gd`/`Zonificacion.gd`/`Recoleccion.gd`: autoload sin `class_name`, lógica pura sin nodos de escena, catálogo de recetas como constante, funciones puras que no mutan sus argumentos. Reutiliza `Recoleccion.TIPOS_MINERALES` como catálogo de minerales crudos en vez de redefinirlo.

**Tech Stack:** Godot 4.7 GDScript, MCP de Godot para verificación headless.

**Spec:** `docs/superpowers/specs/2026-09-14-cadena-minerales-design.md`

## Global Constraints

- `RECETAS: Dictionary` indexado por `tipo_entrada`, cada entrada `{"tipo_salida": String, "cantidad_entrada": int, "cantidad_salida": int, "tasa_base": float}`. Exactamente 2 recetas: `"hierro"` → `{"tipo_salida": "acero", "cantidad_entrada": 2, "cantidad_salida": 1, "tasa_base": 2.0}`, `"tierras_raras"` → `{"tipo_salida": "mineral_refinado", "cantidad_entrada": 3, "cantidad_salida": 1, "tasa_base": 2.0}`.
- `procesar_tick(delta, almacen, trabajadores) -> Dictionary` NUNCA muta `almacen` — siempre devuelve un `Dictionary` nuevo. Un tipo sin receta se copia sin cambios. El consumo nunca deja el insumo negativo (se limita a lo disponible).
- `tasas_refinado(trabajadores) -> Dictionary` NO incluye una clave para una receta sin trabajadores asignados (ausencia de clave, no un valor en 0.0).
- `PERSONAL_MAXIMO_*` es solo informativo — ningún código de este plan lo aplica como límite real.
- No se toca `Ciudad.gd`, `Recoleccion.gd`, `VoxelWorld.gd` ni ningún flujo de colocación real — todo el estado de este sub-proyecto vive en `CadenaMinerales.gd` (recetas puras) y en el `Dictionary` local de la escena de demostración.
- Usa tabulaciones en GDScript. Conserva el español en comentarios, nombres y mensajes de prueba.

---

### Task 1: `CadenaMinerales.gd` — autoload con las recetas de refinado

**Files:**
- Create: `godot/scripts/CadenaMinerales.gd`
- Create: `godot/scripts/CadenaMineralesTest.gd`
- Create: `godot/scenes/CadenaMineralesTest.tscn`
- Modify: `godot/project.godot` (registrar el autoload)

**Interfaces:**
- Produces: `CadenaMinerales.RECETAS` (const), `CadenaMinerales.procesar_tick(delta: float, almacen: Dictionary, trabajadores: Dictionary) -> Dictionary`, `CadenaMinerales.tasas_refinado(trabajadores: Dictionary) -> Dictionary` — consumidas por Task 2.
- Consumes: ninguna (autocontenido; no depende de `Recoleccion.gd` en tiempo de ejecución, solo lo menciona en comentarios como referencia del catálogo de crudos).

- [ ] **Step 1: Registrar el autoload en `project.godot`**

En la sección `[autoload]`, junto a las líneas existentes, agregar (después de `Construccion`):

```
CadenaMinerales="*res://scripts/CadenaMinerales.gd"
```

- [ ] **Step 2: Crear `CadenaMineralesTest.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/CadenaMineralesTest.gd" id="1"]

[node name="CadenaMineralesTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Escribir las pruebas que fallan**

Crear `godot/scripts/CadenaMineralesTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de CadenaMinerales.gd (mismo patrón que
## RecoleccionTest.gd/NiveladorTerrenoTest.gd). Corre esta escena
## (CadenaMineralesTest.tscn) con F6 en el editor de Godot y revisa el
## panel "Output": debe imprimir las pruebas y no debe lanzar ningún error
## de assert().


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: procesar_tick() con ambas recetas a la vez, insumo suficiente ===")
	var almacen_1 := {"hierro": 100.0, "tierras_raras": 100.0}
	var trabajadores_1 := {"hierro": 1, "tierras_raras": 1}
	var resultado_1: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_1, trabajadores_1)
	# hierro: consumo = 2 * 1 * 2.0 * 1.0 = 4.0 -> 2 lotes -> 2.0 acero
	assert(is_equal_approx(resultado_1["hierro"], 96.0))
	assert(is_equal_approx(resultado_1["acero"], 2.0))
	# tierras_raras: consumo = 3 * 1 * 2.0 * 1.0 = 6.0 -> 2 lotes -> 2.0 mineral_refinado
	assert(is_equal_approx(resultado_1["tierras_raras"], 94.0))
	assert(is_equal_approx(resultado_1["mineral_refinado"], 2.0))
	print("OK: ambas recetas se procesan en el mismo tick sin interferir entre sí.")

	print("\n=== TEST 2: procesar_tick() sin trabajadores no cambia el almacén ===")
	var almacen_2 := {"hierro": 50.0, "tierras_raras": 50.0}
	var resultado_2: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_2, {})
	assert(is_equal_approx(resultado_2["hierro"], 50.0))
	assert(is_equal_approx(resultado_2["tierras_raras"], 50.0))
	assert(not resultado_2.has("acero"))
	assert(not resultado_2.has("mineral_refinado"))
	print("OK: sin trabajadores asignados, ninguna receta se ejecuta.")

	print("\n=== TEST 3: procesar_tick() con insumo insuficiente consume solo lo disponible ===")
	var almacen_3 := {"hierro": 3.0}
	var trabajadores_3 := {"hierro": 1}
	# demanda teórica = 2 * 1 * 2.0 * 1.0 = 4.0, pero solo hay 3.0 disponibles
	var resultado_3: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_3, trabajadores_3)
	assert(is_equal_approx(resultado_3["hierro"], 0.0))
	# 3.0 consumidos / 2 por lote = 1.5 lotes -> 1.5 acero (no 2.0, la producción "completa")
	assert(is_equal_approx(resultado_3["acero"], 1.5))
	print("OK: el consumo se limita a lo disponible, y la producción refleja exactamente lo consumido.")

	print("\n=== TEST 4: procesar_tick() no muta el Dictionary 'almacen' recibido ===")
	var almacen_4 := {"hierro": 20.0}
	var copia_4 := almacen_4.duplicate()
	CadenaMinerales.procesar_tick(1.0, almacen_4, {"hierro": 1})
	assert(almacen_4 == copia_4)
	print("OK: 'almacen' queda exactamente igual después de la llamada — procesar_tick() devuelve un Dictionary nuevo.")

	print("\n=== TEST 5: procesar_tick() copia sin cambios un tipo sin receta (p. ej. cobre) ===")
	var almacen_5 := {"cobre": 42.0, "hierro": 10.0}
	var resultado_5: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_5, {"hierro": 1})
	assert(is_equal_approx(resultado_5["cobre"], 42.0))
	print("OK: un mineral sin receta (cobre) pasa sin cambios al resultado.")

	print("\n=== TEST 6: tasas_refinado() con ambas recetas activas ===")
	var tasas_6: Dictionary = CadenaMinerales.tasas_refinado({"hierro": 2, "tierras_raras": 1})
	# hierro: consumo = 2 * 2 * 2.0 = 8.0/h -> produccion = (8.0/2)*1 = 4.0/h
	assert(is_equal_approx(tasas_6["hierro"]["consumo"], 8.0))
	assert(is_equal_approx(tasas_6["hierro"]["produccion"], 4.0))
	assert(tasas_6["hierro"]["tipo_salida"] == "acero")
	# tierras_raras: consumo = 3 * 1 * 2.0 = 6.0/h -> produccion = (6.0/3)*1 = 2.0/h
	assert(is_equal_approx(tasas_6["tierras_raras"]["consumo"], 6.0))
	assert(is_equal_approx(tasas_6["tierras_raras"]["produccion"], 2.0))
	print("OK: tasas_refinado() calcula el consumo/producción por hora exactos para cada receta activa.")

	print("\n=== TEST 7: tasas_refinado() omite (no pone en 0.0) una receta sin trabajadores ===")
	var tasas_7: Dictionary = CadenaMinerales.tasas_refinado({"hierro": 1})
	assert(tasas_7.has("hierro"))
	assert(not tasas_7.has("tierras_raras"))
	print("OK: una receta sin trabajadores asignados no aparece como clave en el resultado.")

	print("\n=== TEST 8: determinismo — mismos argumentos dan siempre el mismo resultado ===")
	var almacen_8 := {"hierro": 77.0, "tierras_raras": 33.0}
	var trabajadores_8 := {"hierro": 2, "tierras_raras": 1}
	var resultado_8a: Dictionary = CadenaMinerales.procesar_tick(0.5, almacen_8, trabajadores_8)
	var resultado_8b: Dictionary = CadenaMinerales.procesar_tick(0.5, almacen_8, trabajadores_8)
	assert(resultado_8a == resultado_8b)
	var tasas_8a: Dictionary = CadenaMinerales.tasas_refinado(trabajadores_8)
	var tasas_8b: Dictionary = CadenaMinerales.tasas_refinado(trabajadores_8)
	assert(tasas_8a == tasas_8b)
	print("OK: procesar_tick()/tasas_refinado() son deterministas para los mismos argumentos.")

	print("\n=== Las 8 pruebas de CadenaMinerales pasaron correctamente ===")
```

- [ ] **Step 3b: Confirmar que las pruebas fallan por falta del autoload**

Run `mcp__godot__run_project` con `scene: "res://scenes/CadenaMineralesTest.tscn"`, luego `get_debug_output`. Esperado: error porque `CadenaMinerales` no existe todavía (el autoload registrado en Step 1 apunta a un archivo que aún no existe, o el identificador `CadenaMinerales` no está definido).

- [ ] **Step 4: Implementar `CadenaMinerales.gd`**

Crear `godot/scripts/CadenaMinerales.gd` con el contenido exacto de la Sección 1 del spec (`docs/superpowers/specs/2026-09-14-cadena-minerales-design.md`) — copiar el bloque de código completo (constantes `RECETAS`/`COSTO_CONSTRUCCION_*`/`PERSONAL_MAXIMO_*`/`CAPACIDAD_ALMACENAMIENTO_*` y las dos funciones `procesar_tick()`/`tasas_refinado()`, incluida la nota de `PERSONAL_MAXIMO_*` como comentario).

- [ ] **Step 5: Ejecutar `CadenaMineralesTest.tscn` y confirmar que las 8 pruebas pasan**

Run `mcp__godot__run_project`/`get_debug_output`/`stop_project`. Esperado: `=== Las 8 pruebas de CadenaMinerales pasaron correctamente ===`, sin errores.

- [ ] **Step 6: Verificar que el resto del proyecto sigue cargando sin errores nuevos**

Run `Main.tscn` (el autoload nuevo se inicializa con todos los demás) — esperar ~30-40s, `get_debug_output`, `stop_project`. Esperado: solo las advertencias preexistentes.

- [ ] **Step 7: Commit**

```bash
git add godot/project.godot godot/scripts/CadenaMinerales.gd godot/scripts/CadenaMineralesTest.gd godot/scenes/CadenaMineralesTest.tscn
git commit -m "feat: CadenaMinerales.gd — recetas hierro->acero y tierras_raras->mineral_refinado"
```

---

### Task 2: `CadenaMineralesDemo.tscn`/`.gd` — demostración interactiva

**Files:**
- Create: `godot/scripts/CadenaMineralesDemo.gd`
- Create: `godot/scenes/CadenaMineralesDemo.tscn`

**Interfaces:**
- Consumes (debe existir ya, Task 1 fusionada): `CadenaMinerales.procesar_tick()`, `CadenaMinerales.tasas_refinado()`.
- No produce interfaces nuevas para otras tasks.

Sin prueba GDScript automatizada — es una escena de demostración manual (mismo criterio que `CamaraCenital.gd`: ninguna de sus interacciones de teclado tiene prueba unitaria, se verifica jugando/probando en vivo). Verificación: carga headless sin errores + una pasada manual describiendo qué se vería.

- [ ] **Step 1: Crear la escena `CadenaMineralesDemo.tscn`**

Estructura: un nodo raíz `Node2D` (no necesita mundo 3D) con el script, y un hijo `Label` para el texto. Usar `mcp__godot__add_node`/`mcp__godot__save_scene` si están disponibles (`ToolSearch` con `select:mcp__godot__add_node,mcp__godot__save_scene` si están diferidas), o escribir el `.tscn` directamente como texto:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/CadenaMineralesDemo.gd" id="1"]

[node name="CadenaMineralesDemo" type="Node2D"]
script = ExtResource("1")

[node name="Texto" type="Label" parent="."]
offset_right = 600.0
offset_bottom = 400.0
```

- [ ] **Step 2: Implementar `CadenaMineralesDemo.gd`**

```gdscript
extends Node2D

## Escena de demostración standalone (PoC 5, sub-proyecto 1) para probar en
## vivo los números de balance de CadenaMinerales.RECETAS — NO se integra
## con Ciudad.almacen ni con ningún estado real del juego, usa su propio
## almacén simulado. Ver docs/superpowers/specs/2026-09-14-cadena-minerales-design.md,
## sección 3.
##
## Controles:
##   1-6: agrega 10 unidades del mineral correspondiente (mismo orden que
##        Recoleccion.TIPOS_MINERALES: tierra/piedra/hierro/cobre/carbon/tierras_raras)
##   Q/W: resta/suma 1 trabajador a la refinería de hierro (mínimo 0)
##   A/S: resta/suma 1 trabajador a la refinería de tierras raras (mínimo 0)
##   Espacio: avanza un tick de 1.0 hora

const ORDEN_MINERALES := ["tierra", "piedra", "hierro", "cobre", "carbon", "tierras_raras"]
const TECLAS_MINERALES := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]

@onready var texto: Label = $Texto

var almacen: Dictionary = {}
var trabajadores: Dictionary = {"hierro": 0, "tierras_raras": 0}


func _ready() -> void:
	_actualizar_texto()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var tecla := event as InputEventKey

	var indice_mineral := TECLAS_MINERALES.find(tecla.keycode)
	if indice_mineral != -1:
		var tipo: String = ORDEN_MINERALES[indice_mineral]
		almacen[tipo] = almacen.get(tipo, 0.0) + 10.0
		_actualizar_texto()
		return

	match tecla.keycode:
		KEY_Q:
			trabajadores["hierro"] = maxi(trabajadores["hierro"] - 1, 0)
		KEY_W:
			trabajadores["hierro"] += 1
		KEY_A:
			trabajadores["tierras_raras"] = maxi(trabajadores["tierras_raras"] - 1, 0)
		KEY_S:
			trabajadores["tierras_raras"] += 1
		KEY_SPACE:
			almacen = CadenaMinerales.procesar_tick(1.0, almacen, trabajadores)
		_:
			return
	_actualizar_texto()


func _actualizar_texto() -> void:
	var lineas: Array = ["=== Cadena de Minerales — Demo ===", ""]
	lineas.append("Trabajadores: hierro=%d (Q/W)  tierras_raras=%d (A/S)" % [trabajadores["hierro"], trabajadores["tierras_raras"]])
	lineas.append("")
	lineas.append("Almacén (1-6 agregan 10 de cada mineral):")
	var hay_almacen := false
	for tipo in almacen:
		if almacen[tipo] > 0.0:
			lineas.append("  %s: %.1f" % [tipo, almacen[tipo]])
			hay_almacen = true
	if not hay_almacen:
		lineas.append("  (vacío)")
	lineas.append("")
	lineas.append("Tasas por hora (Espacio avanza 1 tick):")
	var tasas: Dictionary = CadenaMinerales.tasas_refinado(trabajadores)
	if tasas.is_empty():
		lineas.append("  (ninguna receta activa)")
	else:
		for tipo_entrada in tasas:
			var info: Dictionary = tasas[tipo_entrada]
			lineas.append("  %s: -%.1f/h -> %s +%.1f/h" % [tipo_entrada, info["consumo"], info["tipo_salida"], info["produccion"]])
	texto.text = "\n".join(lineas)
```

- [ ] **Step 3: Verificar carga headless sin errores**

Run `mcp__godot__run_project` con `scene: "res://scenes/CadenaMineralesDemo.tscn"`, `get_debug_output`, `stop_project`. Esperado: sin errores (headless no puede enviar eventos de teclado, así que solo se confirma que la escena carga y `_ready()` corre sin excepciones — la interacción real queda para que el usuario la pruebe jugando).

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/CadenaMineralesDemo.gd godot/scenes/CadenaMineralesDemo.tscn
git commit -m "feat: escena de demostración interactiva de CadenaMinerales"
```

---

### Task 3: Documentación — corrección del GDD y documento técnico de PoC 5

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`
- Create: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`

**Interfaces:** ninguna (documentación pura, sin código).

- [ ] **Step 1: Corregir la contradicción del GDD (Sección 4)**

Buscar la frase (Sección 4, "Catálogo de Recursos y Cadenas de Producción", primer bullet sobre minas) que dice:

> el carbón alimenta la carbonera y el productor de combustible (ver abajo).

Reemplazar por:

> el carbón alimenta el productor de combustible (ver abajo) — la carbonera, en cambio, consume madera para producir carbón (ver el bullet siguiente sobre madera), no al revés.

- [ ] **Step 2: Actualizar la Sección 11 del GDD (tabla de la Fase 3)**

En la fila de "Fase 3" (la que empieza con "En progreso — PoC 6..."), en la parte que describe PoC 5 (actualmente "pendiente de brainstorm/spec/plan propio"), actualizar para reflejar que el sub-proyecto de minerales está completo, con madera/fluidos/energía listados como sub-proyectos pendientes de esta misma PoC. Redactar en el mismo estilo y nivel de detalle que las demás entradas de esa tabla (frases largas con `~~tachado~~` para lo completado — ver el patrón ya usado en esa misma tabla para PoC 6).

- [ ] **Step 3: Crear `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`**

Mismo patrón que `PoC_6/Documento Técnico de Desarrollo_ PoC 6 - Mundo Procedural y Puestos de Recolección.md` (Alcance, Decisiones, Código de referencia, Pruebas, Verificado, Próximos Pasos). Contenido:

- **Alcance:** primer sub-proyecto de la Sección 4 del GDD, acotado a minerales — link a `docs/superpowers/specs/2026-09-14-cadena-minerales-design.md`.
- **Decisiones:** las mismas de la sección "Decisiones de alcance confirmadas con el usuario" del spec, en prosa (catálogo de crudos reutilizado de `Recoleccion.TIPOS_MINERALES`, 2 recetas placeholder, corrección de la contradicción del GDD sobre la carbonera, alcance de lógica pura + demo sin refinerías colocables todavía).
- **`CadenaMinerales.gd`:** describir `RECETAS`/`procesar_tick()`/`tasas_refinado()` (sin repetir el código completo — referenciar el archivo real).
- **Verificado:** vía MCP headless (`CadenaMineralesTest.tscn` 8/8, `Main.tscn` sin errores nuevos).
- **Próximos pasos:** madera (aserradero/carbonera), fluidos (agua/crudo/combustible), energía — cada uno como sub-proyecto futuro de PoC 5; refinerías reales colocables en el mundo como PoC/sub-proyecto posterior una vez probado el balance.

- [ ] **Step 4: Commit**

```bash
git add "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md"
git commit -m "docs: corregir contradicción de la carbonera en el GDD y documentar PoC 5 (minerales)"
```

---

## Verificación manual final (no automatizable)

Abrir `CadenaMineralesDemo.tscn` en el editor de Godot y jugar con los
controles: agregar minerales con `1`-`6`, asignar trabajadores con
`Q`/`W`/`A`/`S`, avanzar ticks con `Espacio`, y confirmar que el texto en
pantalla refleja los números esperados (consumo/producción por hora, y el
almacén evolucionando tick a tick) — sin necesidad de tocar código para
verificarlo, ya que las 8 pruebas automatizadas de la Task 1 ya cubren la
aritmética exacta.
