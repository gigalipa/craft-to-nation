# Construcción y demolición por colonos — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que los colonos libres construyan las obras de edificio/puesto y demuelan los edificios marcados, con el jugador pudiendo ayudar a mano.

**Architecture:** Un script estático `FinalizacionObras` (lógica de fin de obra y demolición extraída de `Player`) lo comparten `Player` y un autoload nuevo `Obras`. `Obras` decide qué obras ofrecer (derivadas de `VoxelWorld`, sin lista propia de obras), guarda las marcas de demolición y ejecuta un paso de trabajo. `Colonos` solo añade una rama «tarea de obra» para los colonos libres. Un overlay rojo dibuja los edificios marcados.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), pruebas `*Test.tscn` headless.

**Spec:** `docs/superpowers/specs/2026-10-02-obras-por-colonos-design.md`

## Global Constraints

- Godot 4.7, GDScript con **tabulaciones**; comentarios, mensajes y pruebas en **español**.
- Cambios pequeños: no reformatear código ajeno; reutilizar lo existente; no tocar `.godot/`, `.godot-mcp/`, `.superpowers/`.
- No editar `Main.tscn` (hay un `Main.tscn*.tmp` sin versionar): los nodos nuevos se crean desde código en `Main.gd`.
- Colonos libres = `tipo == "desempleado"`, o `tipo == "tecnico"`, y en ambos casos con `c["trabajo"].is_empty()`.
- Prioridad: construir antes que demoler; a igualdad, la obra más cercana (en empate, id menor).
- Un paso de obra dura lo mismo que para el jugador: el de minar el material si el paso es excavación (`"aire"`/`"fantasma"`), `INTERVALO_PASO = 0.20` s en el resto. La demolición usa siempre `INTERVALO_PASO`.
- Las vías quedan fuera de alcance. El núcleo urbano no se puede marcar.
- El jugador tiene preferencia: tras cualquier acción suya sobre un edificio (surtir o deconstruir), `Obras.reclamar(id)` lo deja reclamado `DURACION_RECLAMO_MS = 3000` ms y los colonos lo ceden. Cualquier obra se puede pausar/reanudar con `Obras.alternar_pausa(id)`.
- Clic izquierdo en la cenital (sin herramienta) sobre un edificio u obra abre `PanelEdificio` (abajo a la derecha); sobre un puesto terminado, `PanelPuesto` (que gana un botón «Demoler»).
- Verificación (CLAUDE.md): ejecutar `godot/scenes/Test.tscn` más las escenas afectadas. Comando (desde la raíz del repo, Git Bash):
  `"/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" --headless --path godot scenes/<Escena>.tscn > /tmp/<Escena>.log 2>&1` envuelto en `timeout 400`. **Verde** = aparece la línea final de éxito de la escena y `grep -E "Assertion failed|SCRIPT ERROR|Parse Error" /tmp/<Escena>.log` no devuelve nada (`assert()` no detiene la ejecución: hay que buscar en toda la salida).
- Trabajo en la rama `feat/obras-colonos` (ya creada). No hacer push sin que el usuario lo pida.
- Al escribir archivos con scripts Python en Bash, no usar `\\n` en cadenas (el entorno des-escapa las barras): usar `chr(92)` o la herramienta Edit.

## Review Focus

Entradas/condiciones que la especificación implica y que más probablemente fallen; cada una tiene su prueba en la tarea indicada.

1. Un edificio que el jugador deconstruye a medias en 1ª persona **no debe** ser reconstruido por los colonos a su espalda (Tarea 2: `abandonadas`; Tarea 4: `Player` llama a `Obras.abandonar`).
2. Un colono con empleo (o aprendiz) nunca toma tareas de obra, y contratar a un colono con tarea la cancela (Tarea 3).
3. Una obra pausada por falta de material no se ofrece de nuevo hasta que haya ese recurso, y el aviso sale una sola vez (Tarea 2).
4. Una obra o un edificio eliminado con un colono trabajando en él: el colono suelta la tarea sin error (Tareas 2 y 3).
5. Marcar el núcleo urbano se rechaza; marcar y desmarcar alternan; desmarcar a medias no reconstruye (Tarea 2).
6. Mientras el jugador actúa sobre un edificio (reclamado) o la obra está pausada, ni se ofrece ni se trabaja; al caducar el reclamo, vuelve (Tareas 2 y 4).
7. La ventana del edificio muestra salud 100 % en un edificio completo, materiales faltantes solo si falta construir, y cambia las etiquetas de sus botones según el estado (Tarea 5).

---

### Task 1: `FinalizacionObras` y refactor de `Player`

**Files:**
- Create: `godot/scripts/FinalizacionObras.gd`
- Modify: `godot/scripts/Player.gd` (`_completar_construccion` ~l.1113, `_procesar_deconstruccion` ~l.722, `_intervalo_accion_actual` ~l.248, constante `INTERVALO_ACCION_REPETIDA` l.78, y un `const` de preload arriba)
- Test: `godot/scripts/BlueprintValidatorTest.gd` (TEST 92 antes del `print` final; actualizar el contador a 92)

**Interfaces:**
- Produces (todo `static`): `FinalizacionObras.INTERVALO_PASO: float`, `completar_construccion(mundo, metadata) -> String` (mensaje para notificar, `""` si no hay), `al_deconstruir(mundo, resultado)`, `retirar_edificio(mundo, id)`, `intervalo_del_paso(mundo, celda) -> float`.
- Consumes: `VoxelWorld` (`edificio_metadata`, `eliminar_edificio`, `proximo_paso_pendiente`, `material_real`, `obtener_tipo`, `altura_en`) y los autoloads `Ciudad`, `Zonificacion`, `Recoleccion`, `Economia`, `CadenaMinerales`.

- [ ] **Step 1: Escribir la prueba que falla (TEST 92)**

En `BlueprintValidatorTest.gd`, junto a los demás `const ... = preload`, añadir:

```gdscript
const FinalizacionObras = preload("res://scripts/FinalizacionObras.gd")
```

Antes de `print("\n=== Las 91 pruebas ...` insertar y cambiar ese texto a «Las 92 pruebas»:

```gdscript
	print("\n=== TEST 92: FinalizacionObras: el intervalo de un paso, completar sin metadata y retirar un edificio por completo ===")
	const OX92 := 1200
	mundo.colocar_bloque(Vector3i(OX92, 0, OX92), "tierra", true)
	mundo.colocar_bloque(Vector3i(OX92, 1, OX92), "bloque_piedra", true)
	var id_92: int = mundo.registrar_edificio_completo({Vector3i(OX92, 0, OX92): "tierra", Vector3i(OX92, 1, OX92): "bloque_piedra"})
	assert(FinalizacionObras.completar_construccion(mundo, {}) == "", "sin metadata no hay nada que completar ni avisar")
	assert(FinalizacionObras.intervalo_del_paso(mundo, Vector3i(OX92, 1, OX92)) == FinalizacionObras.INTERVALO_PASO, "un edificio completo no tiene paso de excavación: intervalo fijo")
	var r92: Dictionary = {}
	for _i in range(5):
		r92 = mundo.procesar_deconstruccion(Vector3i(OX92, 1, OX92))
		FinalizacionObras.al_deconstruir(mundo, r92)
		if r92["lista_para_remocion"]:
			break
	assert(r92["lista_para_remocion"], "tras revertir todas las celdas queda listo para remoción")
	FinalizacionObras.retirar_edificio(mundo, id_92)
	assert(not mundo.edificio_a_celdas.has(id_92), "retirar_edificio elimina el edificio")
	print("OK: FinalizacionObras funciona igual que el flujo previo de Player.")

```

- [ ] **Step 2: Ejecutar `Test.tscn` y verificar que falla**

Run: comando de verificación con `Test`. Expected: `Parse Error` (no existe `FinalizacionObras.gd`).

- [ ] **Step 3: Crear `FinalizacionObras.gd`**

```gdscript
extends RefCounted

## Lógica de fin de obra y de demolición compartida por Player (jugador) y Obras
## (colonos): registrar lo construido, retirar lo demolido y medir cuánto dura un
## paso. Solo estáticos y sin estado; los mensajes se devuelven para que cada
## llamador los muestre a su manera (Player al HUD, Obras por su señal "aviso").

## Intervalo (s) entre pasos de colocar/surtir/deconstruir: el mismo para el jugador y los colonos.
const INTERVALO_PASO := 0.20


## Se llama cuando VoxelWorld.surtir_construccion() indica que una construcción
## fantasma quedó completa. "metadata" es la que se pasó a
## VoxelWorld.iniciar_construccion_fantasma() al colocarla: un edificio
## residencial, un puesto nuevo ("puesto_nuevo") o un puesto que se volvió a
## completar tras deconstruirse ("puesto"; solo reactiva su Economia). Devuelve
## el mensaje para notificar ("" si no hay).
static func completar_construccion(mundo: Node, metadata: Dictionary) -> String:
	if metadata.is_empty():
		return ""
	if metadata.has("puesto_nuevo"):
		var info: Dictionary = metadata["puesto_nuevo"]
		var entorno: Dictionary = {}
		var tasas: Dictionary = {}
		if not CadenaMinerales.REFINERIAS.has(info["tipo"]) and not Recoleccion.ESCUELAS.has(info["tipo"]):
			var centro: Vector2i = info["centro"]
			var altura: int = mundo.altura_en(centro.x, centro.y)
			entorno = Recoleccion.entorno_de_puesto(info["tipo"], mundo, centro, altura, info["centro_agua"])
			tasas = Recoleccion.tasas_de_entorno(info["tipo"], mundo, entorno)
		Recoleccion.colocar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"])
		# info["y_base"] es la Y de la losa de piso (capa 0, ver PlantillasPuesto.gd);
		# el piso interior TRANSITABLE (donde vive la puerta) es una capa arriba.
		Economia.registrar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"], tasas, entorno, info["servicio"], info["deposito"], info["y_base"] + 1, info.get("salida", Economia.SIN_SERVICIO), info.get("chimenea", Economia.SIN_DEPOSITO))
		print("Puesto '%s' construido en (%d, %d)." % [info["tipo"], info["esquina"].x, info["esquina"].y])
		metadata.erase("puesto_nuevo")  # a partir de aquí, un reconstruir cae en la rama "puesto" (reactivar), no en esta (evita re-registrar y huérfanos en _puesto_de — revisión de código, 2026-09-29).
		return "Puesto construido."
	if metadata.has("puesto"):
		Economia.reactivar_puesto(metadata["puesto"])
		print("Puesto reactivado en ", metadata["puesto"], ".")
		return "Puesto reactivado."
	var blueprint: Dictionary = metadata["blueprint"]

	# El primer edificio declarado es el núcleo urbano: no es habitable, así que
	# no suma camas (no llegan colonos todavía) ni baúles al tope del almacén; en
	# cambio, declararlo duplica los topes del inventario.
	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		Ciudad.ampliar_almacen()
		print("Núcleo urbano declarado (no habitable: no llegan colonos todavía). Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max, ". Topes del inventario duplicados.")
		Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])
		return "Núcleo urbano declarado."

	var camas_por_piso: Array[int] = []
	var total_camas := 0
	for piso in blueprint["pisos"]:
		var camas: int = (piso.get("camas", []) as Array).size()
		camas_por_piso.append(camas)
		total_camas += camas
	var baules: int = BlueprintValidator.contar_baules(blueprint)
	Ciudad.registrar_edificio_residencial(metadata["id_edificio"], camas_por_piso, baules)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (capacidad de camas actual: ", Ciudad.capacidad_camas_construida, "), baúles: ", baules)

	Zonificacion.ampliar_influencia(metadata.get("id_edificio", -1), metadata["huella_xz"], blueprint["categoria"])
	print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
	return "Edificio construido."


## Efectos de revertir una celda de un edificio ("resultado" es lo que devuelve
## VoxelWorld.procesar_deconstruccion()): retirar sus camas de Ciudad (idempotente)
## y dejar de producir si es un puesto (idempotente).
static func al_deconstruir(mundo: Node, resultado: Dictionary) -> void:
	Ciudad.retirar_edificio_residencial(resultado["id"])
	var metadata_obra: Dictionary = mundo.edificio_metadata.get(resultado["id"], {})
	if metadata_obra.has("puesto"):
		Economia.desactivar_puesto(metadata_obra["puesto"])
	if resultado["total_camas"] > 0:
		print("Deconstrucción iniciada: ", resultado["total_camas"], " cama(s) retiradas de Ciudad.")


## Elimina por completo un edificio ya reducido a fantasma vacío y limpia lo que
## dependía de él.
static func retirar_edificio(mundo: Node, id: int) -> void:
	var metadata_final: Dictionary = mundo.edificio_metadata.get(id, {})  # eliminar_edificio() la borra
	var esquina: Vector2i = mundo.eliminar_edificio(id)
	if metadata_final.has("puesto"):
		esquina = metadata_final["puesto"]  # la esquina del puesto, no la de las celdas de la plantilla
	Zonificacion.retirar_contribucion(id)
	Recoleccion.quitar_puesto(esquina)
	Economia.quitar_puesto(esquina)  # libera a sus trabajadores (no-op si era un edificio)
	print("Edificio deconstruido por completo.")


## Intervalo hasta el próximo paso de la obra a la que pertenece "celda": el mismo
## tiempo que minar a mano el material si el paso es de EXCAVACIÓN (ver
## VoxelWorld.proximo_paso_pendiente()), y INTERVALO_PASO en el resto (colocar,
## relleno, estructura) — nivelar un sitio no debe vaciar una veta más rápido que
## minarla uno mismo (decisión del usuario, 2026-09-29).
static func intervalo_del_paso(mundo: Node, celda: Vector3i) -> float:
	var paso: Dictionary = mundo.proximo_paso_pendiente(celda)
	if paso.is_empty() or (paso["tipo"] != "aire" and paso["tipo"] != "fantasma"):
		return INTERVALO_PASO
	var material: String = mundo.material_real(mundo.obtener_tipo(paso["celda"]))
	return Recoleccion.tiempo_minado_de(material)
```

- [ ] **Step 4: Refactorizar `Player.gd`**

(a) Junto a los demás `const ... = preload` (l.4-8) añadir `const FinalizacionObras = preload("res://scripts/FinalizacionObras.gd")`, y cambiar `const INTERVALO_ACCION_REPETIDA := 0.20` (l.78) por `const INTERVALO_ACCION_REPETIDA := FinalizacionObras.INTERVALO_PASO` (conservar su comentario).

(b) Reemplazar el cuerpo completo de `_completar_construccion` (desde `if metadata.is_empty():` hasta el último `print("Zona de influencia ampliada...")`, conservando el comentario de documentación de la función) por:

```gdscript
func _completar_construccion(metadata: Dictionary) -> void:
	var aviso: String = FinalizacionObras.completar_construccion(mundo, metadata)
	if aviso != "":
		hud.notificar(aviso)
```

(c) En `_procesar_deconstruccion`, reemplazar el bloque que va de `Ciudad.retirar_edificio_residencial(resultado["id"])  # idempotente` hasta el `print("Deconstrucción iniciada: ...` (el `if resultado["total_camas"] > 0:` incluido) por `FinalizacionObras.al_deconstruir(mundo, resultado)`; y reemplazar el bloque dentro de `if _ticks_listo_para_remocion >= TICKS_REMOCION_FINAL:` (desde `var metadata_final` hasta el `print("Edificio deconstruido por completo.")`, sin tocar `_alternar_modo_deconstruccion()` que sigue después) por `FinalizacionObras.retirar_edificio(mundo, id)`.

(d) Reemplazar el cuerpo de `_intervalo_accion_actual` por:

```gdscript
func _intervalo_accion_actual() -> float:
	if mundo == null or not raycast.is_colliding():
		return INTERVALO_ACCION_REPETIDA
	return FinalizacionObras.intervalo_del_paso(mundo, _celda_impactada())
```

- [ ] **Step 5: Ejecutar `Test.tscn` y verificar que pasa**

Run: comando de verificación con `Test`. Expected: verde y aparece «Las 92 pruebas de BlueprintValidator pasaron correctamente» (la prueba 91 de `Player` sigue pasando: valida que el refactor no cambió la deconstrucción).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/FinalizacionObras.gd godot/scripts/Player.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "refactor: la finalización de obras y demolición de Player pasa a FinalizacionObras

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Autoload `Obras` y `ObrasTest`

**Files:**
- Create: `godot/scripts/Obras.gd`, `godot/scripts/ObrasTest.gd`, `godot/scenes/ObrasTest.tscn`
- Modify: `godot/project.godot` (sección `[autoload]`: añadir `Obras` **antes** de `Colonos`)

**Interfaces:**
- Consumes (Tarea 1): `FinalizacionObras.INTERVALO_PASO`, `intervalo_del_paso`, `completar_construccion`, `al_deconstruir`, `retirar_edificio`.
- Consumes (`VoxelWorld`, o su doble de prueba): `edificio_orden`, `edificio_progreso`, `edificio_a_celdas`, `edificio_metadata`, `surtir_construccion(celda)`, `procesar_deconstruccion(celda)`, `proximo_paso_pendiente(celda)`.
- Produces: señales `marca_cambiada(id: int, marcado: bool)` y `aviso(texto: String)`; propiedades `mundo`, `ciudad`, `zona`, `marcados`, `abandonadas`, `pausadas`, y los puntos de inyección `al_completar`, `al_deconstruir`, `al_retirar` (Callables); funciones `alternar_marca(id) -> String` (`""` = hecho, si no, el motivo del rechazo), `esta_marcado(id) -> bool`, `abandonar(id)`, `olvidar(id)`, `siguiente_tarea(desde: Vector3i, id_colono := -1) -> Dictionary` (`{"tipo": "construir"|"demoler", "id": int}` o `{}`), `huella_de(id) -> Array` (de `Vector2i`), `trabajar(id, tipo) -> Dictionary` (`{"estado": "avanzo"|"pausada"|"bloqueada"|"completa"|"terminada"|"invalida", "espera": float}`), `vetar(id, id_colono)`, `pausar(id, recurso)`, `reclamar(id)`, `esta_reclamada(id) -> bool`, `alternar_pausa(id)`, `esta_pausada_por_jugador(id) -> bool`, `resumen_de(id) -> Dictionary` (`{"nombre", "tipo", "estado": "construccion"|"demolicion"|"completo", "pausada": bool, "salud": float 0..1, "faltantes": Dictionary recurso -> cantidad}` o `{}` si no existe) e `id_en_columna(columna: Vector2i) -> int` (id del edificio con alguna celda en esa columna, o -1). El doble de prueba del mundo necesita además `edificio_tipos` (id -> {celda -> tipo}).

- [ ] **Step 1: Escribir `ObrasTest.gd` y la escena (la prueba falla porque no existe `Obras.gd`)**

`godot/scenes/ObrasTest.tscn` (mismo formato que `PlayerOxigenoTest.tscn`):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ObrasTest.gd" id="1"]

[node name="ObrasTest" type="Node"]
script = ExtResource("1")
```

`godot/scripts/ObrasTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de Obras.gd (autoload): un mundo falso con obras de pocas
## celdas, una Ciudad real instanciada fuera del árbol y una zona falsa. Las
## funciones de fin de obra (al_completar/al_deconstruir/al_retirar) se
## sustituyen por registradores, así que no tocan los autoloads reales.

const ObrasScript = preload("res://scripts/Obras.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")
const FinalizacionObras = preload("res://scripts/FinalizacionObras.gd")


class MundoObraFalso extends RefCounted:
	var edificio_orden: Dictionary = {}
	var edificio_progreso: Dictionary = {}
	var edificio_a_celdas: Dictionary = {}
	var edificio_metadata: Dictionary = {}
	var edificio_tipos: Dictionary = {}  # id -> {celda -> tipo final}
	var resultados_surtir: Array = []  # se consumen en orden
	var resultados_deconstruir: Array = []
	var eliminados: Array = []

	## Un edificio de "celdas" celdas en fila a lo largo de x desde "origen", con "progreso" celdas hechas.
	func agregar(id: int, origen: Vector3i, celdas: int, progreso: int) -> void:
		var lista: Array[Vector3i] = []
		for i in range(celdas):
			lista.append(origen + Vector3i(i, 0, 0))
		edificio_orden[id] = lista
		edificio_a_celdas[id] = lista
		edificio_progreso[id] = progreso
		edificio_metadata[id] = {}
		edificio_tipos[id] = {}
		for celda in lista:
			edificio_tipos[id][celda] = "bloque_piedra"

	func surtir_construccion(_celda: Vector3i) -> Dictionary:
		return resultados_surtir.pop_front() if not resultados_surtir.is_empty() else {}

	func procesar_deconstruccion(_celda: Vector3i) -> Dictionary:
		return resultados_deconstruir.pop_front() if not resultados_deconstruir.is_empty() else {}

	func proximo_paso_pendiente(_celda: Vector3i) -> Dictionary:
		return {}

	func eliminar_edificio(id: int) -> Vector2i:
		eliminados.append(id)
		edificio_orden.erase(id)
		edificio_a_celdas.erase(id)
		edificio_progreso.erase(id)
		edificio_metadata.erase(id)
		return Vector2i.ZERO


## Zona falsa: solo la celda (0, 0) es del núcleo urbano.
class ZonaFalsa extends RefCounted:
	func celda_es_del_nucleo(celda: Vector2i) -> bool:
		return celda == Vector2i(0, 0)


func _ready() -> void:
	ejecutar_pruebas()


func _nuevas(mundo: MundoObraFalso, ciudad: Node = null) -> Node:
	var obras: Node = ObrasScript.new()
	obras.mundo = mundo
	obras.ciudad = ciudad if ciudad != null else CiudadScript.new()
	obras.zona = ZonaFalsa.new()
	obras.al_completar = func(_m: Object, _meta: Dictionary) -> String: return "listo"
	obras.al_deconstruir = func(_m: Object, _r: Dictionary) -> void: pass
	obras.al_retirar = func(_m: Object, _id: int) -> void: pass
	return obras


func ejecutar_pruebas() -> void:
	print("=== TEST 1: siguiente_tarea elige la obra pendiente más cercana y prefiere construir a demoler ===")
	var mundo1 := MundoObraFalso.new()
	mundo1.agregar(1, Vector3i(10, 0, 10), 3, 1)  # lejos
	mundo1.agregar(2, Vector3i(3, 0, 3), 3, 0)  # cerca
	mundo1.agregar(3, Vector3i(4, 0, 4), 3, 3)  # completo
	var obras1: Node = _nuevas(mundo1)
	var t1: Dictionary = obras1.siguiente_tarea(Vector3i(2, 1, 2))
	assert(t1 == {"tipo": "construir", "id": 2}, "la obra pendiente más cercana: %s" % str(t1))
	assert(obras1.siguiente_tarea(Vector3i(11, 1, 11)) == {"tipo": "construir", "id": 1}, "desde el otro lado, la otra")
	assert(obras1.alternar_marca(3) == "", "se puede marcar el edificio completo")
	assert(obras1.siguiente_tarea(Vector3i(2, 1, 2))["id"] == 2, "con construcción pendiente se prefiere construir aunque haya una demolición más cerca")
	mundo1.edificio_progreso[1] = 3
	mundo1.edificio_progreso[2] = 3
	assert(obras1.siguiente_tarea(Vector3i(2, 1, 2)) == {"tipo": "demoler", "id": 3}, "sin nada que construir, demoler lo marcado")
	assert(ObrasScript.new().siguiente_tarea(Vector3i.ZERO).is_empty(), "sin mundo no hay tarea")

	print("\n=== TEST 2: marcar y desmarcar alternan, el núcleo se rechaza, y desmarcar a medias no reconstruye ===")
	var mundo2 := MundoObraFalso.new()
	mundo2.agregar(1, Vector3i(5, 0, 5), 4, 4)
	mundo2.agregar(2, Vector3i(0, 0, 0), 4, 4)  # contiene la celda (0, 0): el núcleo
	var obras2: Node = _nuevas(mundo2)
	var cambios2: Array = []
	obras2.marca_cambiada.connect(func(id: int, marcado: bool) -> void: cambios2.append([id, marcado]))
	assert(obras2.alternar_marca(2) != "", "el núcleo urbano se rechaza con un motivo")
	assert(not obras2.esta_marcado(2) and cambios2.is_empty(), "y no queda marcado")
	assert(obras2.alternar_marca(99) != "", "un id que no es un edificio se rechaza")
	assert(obras2.alternar_marca(1) == "" and obras2.esta_marcado(1), "marcar")
	mundo2.edificio_progreso[1] = 2  # los colonos ya demolieron la mitad
	assert(obras2.alternar_marca(1) == "" and not obras2.esta_marcado(1), "desmarcar")
	assert(cambios2 == [[1, true], [1, false]], "cada cambio emite la señal: %s" % str(cambios2))
	assert(obras2.siguiente_tarea(Vector3i(6, 1, 6)).is_empty(), "un edificio desmarcado a medias queda abandonado: los colonos no lo reconstruyen")
	obras2.abandonar(1)
	mundo2.edificio_progreso[1] = 4
	assert(obras2.siguiente_tarea(Vector3i(6, 1, 6)).is_empty(), "completo no tiene trabajo")

	print("\n=== TEST 3: Player deconstruyendo a mano abandona la obra; olvidar la limpia ===")
	var mundo3 := MundoObraFalso.new()
	mundo3.agregar(1, Vector3i(5, 0, 5), 4, 2)
	var obras3: Node = _nuevas(mundo3)
	assert(obras3.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "obra pendiente")
	obras3.abandonar(1)
	assert(obras3.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "abandonada: ya no se ofrece")
	obras3.olvidar(1)
	assert(obras3.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "olvidar la quita de abandonadas (un edificio nuevo con ese id vuelve a ser candidato)")

	print("\n=== TEST 4: una obra sin material se pausa, se avisa una vez y vuelve cuando hay el recurso ===")
	var mundo4 := MundoObraFalso.new()
	mundo4.agregar(1, Vector3i(5, 0, 5), 4, 0)
	var ciudad4: Node = CiudadScript.new()
	ciudad4.almacen["piedra"].cantidad = 0.0
	var obras4: Node = _nuevas(mundo4, ciudad4)
	var avisos4: Array = []
	obras4.aviso.connect(func(texto: String) -> void: avisos4.append(texto))
	mundo4.resultados_surtir = [{"insuficiente": true, "recurso": "piedra", "tipo": "bloque_piedra"}, {"insuficiente": true, "recurso": "piedra", "tipo": "bloque_piedra"}]
	var r4: Dictionary = obras4.trabajar(1, "construir")
	assert(r4["estado"] == "pausada", "sin material: pausada")
	assert(obras4.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "una obra pausada no se ofrece mientras falte el recurso")
	obras4.trabajar(1, "construir")
	assert(avisos4.size() == 1, "el aviso sale una sola vez por obra y recurso: %d" % avisos4.size())
	ciudad4.almacen["piedra"].cantidad = 50.0
	assert(obras4.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "con el recurso de nuevo, se ofrece")
	mundo4.resultados_surtir = [{"completa": false, "metadata": {}}]
	assert(obras4.trabajar(1, "construir")["estado"] == "avanzo" and not obras4.pausadas.has(1), "al avanzar deja de estar pausada")

	print("\n=== TEST 5: trabajar construye paso a paso, completa con aviso y reporta bloqueos o fin ===")
	var mundo5 := MundoObraFalso.new()
	mundo5.agregar(1, Vector3i(5, 0, 5), 4, 0)
	var obras5: Node = _nuevas(mundo5)
	var avisos5: Array = []
	obras5.aviso.connect(func(texto: String) -> void: avisos5.append(texto))
	mundo5.resultados_surtir = [{"completa": false, "metadata": {}}, {"bloqueada": true, "id": 1}, {"completa": true, "metadata": {}}, {}]
	var avance5: Dictionary = obras5.trabajar(1, "construir")
	assert(avance5["estado"] == "avanzo" and is_equal_approx(avance5["espera"], FinalizacionObras.INTERVALO_PASO), "avanzar espera el intervalo del paso")
	assert(obras5.trabajar(1, "construir")["estado"] == "bloqueada", "con ocupantes dentro, bloqueada")
	assert(obras5.trabajar(1, "construir")["estado"] == "completa" and avisos5 == ["listo"], "al completar se ejecuta al_completar y se avisa")
	assert(obras5.trabajar(1, "construir")["estado"] == "terminada", "sin nada que surtir, terminada")
	assert(obras5.trabajar(77, "construir")["estado"] == "invalida", "una obra que ya no existe es inválida, sin error")

	print("\n=== TEST 6: demoler revierte celda a celda y, al quedar vacío, retira el edificio y lo desmarca ===")
	var mundo6 := MundoObraFalso.new()
	mundo6.agregar(1, Vector3i(5, 0, 5), 2, 2)
	var obras6: Node = _nuevas(mundo6)
	var retirados6: Array = []
	obras6.al_retirar = func(_m: Object, id: int) -> void: retirados6.append(id)
	obras6.alternar_marca(1)
	mundo6.resultados_deconstruir = [
		{"id": 1, "completa_reversion": false, "lista_para_remocion": false, "total_camas": 0},
		{"id": 1, "completa_reversion": true, "lista_para_remocion": true, "total_camas": 0},
	]
	assert(obras6.trabajar(1, "demoler")["estado"] == "avanzo", "revierte una celda")
	assert(obras6.esta_marcado(1) and retirados6.is_empty(), "sigue marcado y en pie")
	assert(obras6.trabajar(1, "demoler")["estado"] == "completa" and retirados6 == [1], "al quedar vacío se retira")
	assert(not obras6.esta_marcado(1), "y deja de estar marcado")
	assert(obras6.trabajar(1, "demoler")["estado"] == "invalida", "ya no existe: inválida")

	print("\n=== TEST 7: un colono vetado no recibe esa obra; huella_de devuelve las columnas del edificio ===")
	var mundo7 := MundoObraFalso.new()
	mundo7.agregar(1, Vector3i(5, 0, 5), 3, 0)
	var obras7: Node = _nuevas(mundo7)
	obras7.vetar(1, 42)
	assert(obras7.siguiente_tarea(Vector3i(5, 1, 5), 42).is_empty(), "vetada para el colono 42")
	assert(obras7.siguiente_tarea(Vector3i(5, 1, 5), 43)["id"] == 1, "no para otro")
	assert(obras7.huella_de(1) == [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)], "huella: una entrada por columna")
	assert(obras7.huella_de(9).is_empty(), "un id desconocido no tiene huella")

	print("\n=== TEST 8: el jugador tiene preferencia (reclamo con caducidad) y puede pausar cualquier obra ===")
	var mundo8 := MundoObraFalso.new()
	mundo8.agregar(1, Vector3i(5, 0, 5), 3, 0)
	mundo8.agregar(2, Vector3i(8, 0, 8), 2, 2)
	var obras8: Node = _nuevas(mundo8)
	obras8.alternar_marca(2)
	obras8.reclamar(1)
	assert(obras8.esta_reclamada(1), "recién reclamada")
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 2, "mientras el jugador la tiene, los colonos toman otra tarea (aquí, la demolición)")
	assert(obras8.trabajar(1, "construir")["estado"] == "pausada", "y quien ya estaba en ella la cede")
	obras8._reclamos[1] = 0  # caducó
	assert(not obras8.esta_reclamada(1), "el reclamo caduca")
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "al caducar vuelve a ofrecerse")
	obras8.alternar_pausa(1)
	assert(obras8.esta_pausada_por_jugador(1) and obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 2, "una obra pausada no se ofrece")
	assert(obras8.trabajar(1, "construir")["estado"] == "pausada", "ni se trabaja")
	obras8.alternar_pausa(2)
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "también se puede pausar una demolición")
	obras8.alternar_pausa(1)
	obras8.alternar_pausa(2)
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "reanudar la devuelve")
	obras8.olvidar(1)
	assert(not obras8.esta_pausada_por_jugador(1) and not obras8.esta_reclamada(1), "olvidar limpia la pausa y el reclamo")

	print("\n=== TEST 9: resumen_de da el estado, la salud y los materiales que faltan; id_en_columna encuentra el edificio ===")
	var mundo9 := MundoObraFalso.new()
	mundo9.agregar(1, Vector3i(5, 0, 5), 4, 1)  # 3 celdas por hacer, 5 de piedra cada una
	mundo9.agregar(2, Vector3i(9, 0, 9), 2, 2)  # completo
	var obras9: Node = _nuevas(mundo9)
	var res9: Dictionary = obras9.resumen_de(1)
	assert(res9["estado"] == "construccion" and not res9["pausada"], "en construcción")
	assert(is_equal_approx(res9["salud"], 0.25), "salud = fracción construida: %f" % res9["salud"])
	assert(res9["faltantes"] == {"piedra": 15}, "faltan 3 celdas x 5 de piedra: %s" % str(res9["faltantes"]))
	assert(res9["nombre"] == "Edificio 1" and res9["tipo"] == "Edificio", "sin metadata, nombre genérico")
	var res9b: Dictionary = obras9.resumen_de(2)
	assert(res9b["estado"] == "completo" and is_equal_approx(res9b["salud"], 1.0) and res9b["faltantes"].is_empty(), "un edificio completo: 100 % y nada que falte")
	obras9.alternar_marca(2)
	obras9.alternar_pausa(2)
	assert(obras9.resumen_de(2)["estado"] == "demolicion" and obras9.resumen_de(2)["pausada"], "marcado: demolición; y se refleja la pausa")
	mundo9.edificio_metadata[1] = {"blueprint": {"nombre": "Casa", "categoria": "residencial"}}
	assert(obras9.resumen_de(1)["nombre"] == "Casa" and obras9.resumen_de(1)["tipo"] == "Residencial", "nombre y tipo del blueprint")
	assert(obras9.resumen_de(99).is_empty(), "un id desconocido no tiene resumen")
	assert(obras9.id_en_columna(Vector2i(6, 5)) == 1 and obras9.id_en_columna(Vector2i(0, 0)) == -1, "id_en_columna")

	print("\n=== Las 9 pruebas de Obras pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar `ObrasTest.tscn` y verificar que falla**

Run: comando de verificación con `ObrasTest`. Expected: `Parse Error: Could not preload resource script "res://scripts/Obras.gd"`.

- [ ] **Step 3: Crear `Obras.gd`**

```gdscript
extends Node

## Coordinador de las obras que hacen los colonos libres (ver
## docs/superpowers/specs/2026-10-02-obras-por-colonos-design.md). Las obras de
## construcción NO se registran aquí: se derivan de VoxelWorld (un edificio con
## progreso incompleto que nadie abandonó). Lo que sí guarda son las marcas de
## demolición, las obras pausadas por falta de material, las abandonadas
## (deconstruidas a medias por el jugador o desmarcadas: no se reconstruyen solas)
## y los vetos temporales por colono. No mueve colonos: Colonos.gd pide
## siguiente_tarea() y llama a trabajar().

const FinalizacionObras = preload("res://scripts/FinalizacionObras.gd")
const NiveladorTerrenoScript = preload("res://scripts/NiveladorTerreno.gd")
const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")

## Cambió la marca de demolición de un edificio (la dibuja MarcasDemolicionOverlay).
signal marca_cambiada(id: int, marcado: bool)
## Mensaje para el jugador (Main lo envía al HUD).
signal aviso(texto: String)

const ESPERA_BLOQUEADA := 1.0  # s que espera un colono si hay alguien dentro de la obra
const DURACION_VETO_MS := 30000  # una obra a la que un colono no pudo llegar se le oculta ese tiempo
const DURACION_RECLAMO_MS := 3000  # tras actuar el jugador a mano sobre un edificio, los colonos se lo ceden ese tiempo

## El mundo (VoxelWorld en el juego), asignado por Main.
var mundo: Object = null
var ciudad: Object = null  # Ciudad
var zona: Object = null  # Zonificacion

## Funciones de fin de obra; sustituibles en las pruebas.
var al_completar: Callable = FinalizacionObras.completar_construccion
var al_deconstruir: Callable = FinalizacionObras.al_deconstruir
var al_retirar: Callable = FinalizacionObras.retirar_edificio

var marcados: Dictionary = {}  # id -> true
var abandonadas: Dictionary = {}  # id -> true
var pausadas: Dictionary = {}  # id -> recurso que falta
var pausadas_por_jugador: Dictionary = {}  # id -> true (pausa pedida desde la ventana del edificio)
var _vetos: Dictionary = {}  # "id:colono" -> ms hasta los que dura
var _reclamos: Dictionary = {}  # id -> ms hasta los que el jugador lo tiene reclamado


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	if zona == null:
		zona = Zonificacion


func esta_marcado(id: int) -> bool:
	return marcados.has(id)


## Marca o desmarca un edificio para demolición. Devuelve "" si lo hizo, o el
## motivo del rechazo. Desmarcar uno ya a medio demoler lo deja abandonado.
func alternar_marca(id: int) -> String:
	if marcados.has(id):
		marcados.erase(id)
		if mundo != null and mundo.edificio_orden.has(id) and mundo.edificio_progreso[id] < mundo.edificio_orden[id].size():
			abandonadas[id] = true
		marca_cambiada.emit(id, false)
		return ""
	if mundo == null or not mundo.edificio_orden.has(id):
		return "Eso no es un edificio."
	for celda: Vector3i in mundo.edificio_a_celdas[id]:
		if zona.celda_es_del_nucleo(Vector2i(celda.x, celda.z)):
			return "El núcleo urbano no se puede demoler."
	marcados[id] = true
	abandonadas.erase(id)
	marca_cambiada.emit(id, true)
	return ""


## El jugador deconstruyó parte de este edificio a mano: los colonos no lo reconstruyen.
func abandonar(id: int) -> void:
	abandonadas[id] = true


## El edificio dejó de existir (o se retiró): borra todo rastro de él.
func olvidar(id: int) -> void:
	var estaba_marcado := marcados.erase(id)
	abandonadas.erase(id)
	pausadas.erase(id)
	pausadas_por_jugador.erase(id)
	_reclamos.erase(id)
	if estaba_marcado:
		marca_cambiada.emit(id, false)


func vetar(id: int, id_colono: int) -> void:
	_vetos["%d:%d" % [id, id_colono]] = Time.get_ticks_msec() + DURACION_VETO_MS


func _vetada(id: int, id_colono: int) -> bool:
	return _vetos.get("%d:%d" % [id, id_colono], 0) > Time.get_ticks_msec()


## El jugador acaba de construir o deconstruir este edificio a mano: los colonos le ceden la obra un rato.
func reclamar(id: int) -> void:
	_reclamos[id] = Time.get_ticks_msec() + DURACION_RECLAMO_MS


func esta_reclamada(id: int) -> bool:
	return _reclamos.get(id, 0) > Time.get_ticks_msec()


## Pausa o reanuda la obra (de construcción o de demolición) a petición del jugador. No impide que
## el jugador la siga a mano.
func alternar_pausa(id: int) -> void:
	if pausadas_por_jugador.has(id):
		pausadas_por_jugador.erase(id)
	else:
		pausadas_por_jugador[id] = true


func esta_pausada_por_jugador(id: int) -> bool:
	return pausadas_por_jugador.has(id)


## Una obra no se ofrece ni se trabaja mientras el jugador la tiene reclamada o pausada.
func _cedida(id: int) -> bool:
	return pausadas_por_jugador.has(id) or esta_reclamada(id)


## Una obra sin material se pausa; el aviso sale solo la primera vez que falta ese recurso.
func pausar(id: int, recurso: String) -> void:
	if pausadas.get(id, "") != recurso:
		aviso.emit("Obra detenida: falta %s." % recurso)
	pausadas[id] = recurso


func _hay_recurso(recurso: String) -> bool:
	var almacen: Dictionary = ciudad.almacen
	if recurso == "madera":
		return almacen["tablas"].cantidad + almacen["madera"].cantidad > 0.0
	return almacen.has(recurso) and almacen[recurso].cantidad > 0.0


func _candidatas(tipo: String) -> Array[int]:
	var ids: Array[int] = []
	if mundo == null:
		return ids
	if tipo == "demoler":
		for id: int in marcados:
			if mundo.edificio_orden.has(id) and not _cedida(id):
				ids.append(id)
		return ids
	for id: int in mundo.edificio_orden:
		if marcados.has(id) or abandonadas.has(id) or _cedida(id):
			continue
		if mundo.edificio_progreso[id] >= mundo.edificio_orden[id].size():
			continue
		if pausadas.has(id) and not _hay_recurso(pausadas[id]):
			continue
		ids.append(id)
	return ids


## La tarea que le toca a un colono libre que está en "desde": primero construir,
## luego demoler; en cada grupo la obra más cercana (en empate, la de id menor).
## {} si no hay trabajo para él.
func siguiente_tarea(desde: Vector3i, id_colono: int = -1) -> Dictionary:
	for tipo in ["construir", "demoler"]:
		var mejor := -1
		var mejor_distancia := INF
		for id in _candidatas(tipo):
			if _vetada(id, id_colono):
				continue
			var distancia: float = Vector3(desde).distance_to(Vector3(mundo.edificio_a_celdas[id][0]))
			if distancia < mejor_distancia - 0.0001 or (absf(distancia - mejor_distancia) <= 0.0001 and id < mejor):
				mejor = id
				mejor_distancia = distancia
		if mejor != -1:
			return {"tipo": tipo, "id": mejor}
	return {}


## Columnas (x, z) del edificio: junto a ellas se para el colono. Vacío si no existe.
func huella_de(id: int) -> Array:
	var huella: Array = []
	if mundo == null or not mundo.edificio_a_celdas.has(id):
		return huella
	for celda: Vector3i in mundo.edificio_a_celdas[id]:
		var columna := Vector2i(celda.x, celda.z)
		if not huella.has(columna):
			huella.append(columna)
	return huella


## Id del edificio que tiene alguna celda en la columna "columna" (x, z), o -1.
func id_en_columna(columna: Vector2i) -> int:
	if mundo == null:
		return -1
	for id: int in mundo.edificio_a_celdas:
		for celda: Vector3i in mundo.edificio_a_celdas[id]:
			if celda.x == columna.x and celda.z == columna.y:
				return id
	return -1


## Datos para la ventana del edificio: nombre y tipo; estado ("demolicion" si está marcado,
## "construccion" si le faltan celdas, "completo"); si el jugador la pausó; salud (fracción
## construida, 0..1: 1.0 en un edificio completo) y los materiales que faltan para terminarlo
## (el costo de las celdas aún sin construir). {} si el edificio no existe.
func resumen_de(id: int) -> Dictionary:
	if mundo == null or not mundo.edificio_orden.has(id):
		return {}
	var orden: Array = mundo.edificio_orden[id]
	var progreso: int = mundo.edificio_progreso[id]
	var faltantes := {}
	for i in range(progreso, orden.size()):
		var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(mundo.edificio_tipos[id][orden[i]], {})
		for recurso in costo:
			faltantes[recurso] = faltantes.get(recurso, 0) + costo[recurso]
	var estado := "completo"
	if marcados.has(id):
		estado = "demolicion"
	elif progreso < orden.size():
		estado = "construccion"
	var meta: Dictionary = mundo.edificio_metadata.get(id, {})
	var nombre := "Edificio %d" % id
	var tipo := "Edificio"
	if meta.has("puesto_nuevo") or meta.has("puesto"):
		var tipo_puesto: String = meta["puesto_nuevo"]["tipo"] if meta.has("puesto_nuevo") else Economia.puestos.get(meta["puesto"], {}).get("tipo", "")
		nombre = PanelPuestoScript.NOMBRES_PUESTO.get(tipo_puesto, nombre)
		tipo = "Puesto"
	elif meta.has("blueprint"):
		nombre = str(meta["blueprint"].get("nombre", nombre))
		tipo = str(meta["blueprint"].get("categoria", tipo)).capitalize()
	return {
		"nombre": nombre, "tipo": tipo, "estado": estado, "pausada": pausadas_por_jugador.has(id),
		"salud": float(progreso) / maxf(float(orden.size()), 1.0), "faltantes": faltantes,
	}


## Un paso de trabajo de un colono sobre la obra "id" ("construir" o "demoler").
## Devuelve {"estado", "espera"}: "avanzo" (sigue), "pausada" (falta material),
## "bloqueada" (alguien dentro), "completa" (terminó este edificio), "terminada"
## (no había nada que surtir) o "invalida" (el edificio ya no existe); "espera" es
## cuánto debe esperar el colono antes de volver a decidir.
func trabajar(id: int, tipo: String) -> Dictionary:
	if mundo == null or not mundo.edificio_orden.has(id):
		olvidar(id)
		return {"estado": "invalida", "espera": 0.0}
	if _cedida(id):
		return {"estado": "pausada", "espera": ESPERA_BLOQUEADA}  # el jugador la tiene o la pausó
	var celda: Vector3i = mundo.edificio_a_celdas[id][0]
	if tipo == "demoler":
		return _demoler_un_paso(id, celda)
	return _construir_un_paso(id, celda)


func _construir_un_paso(id: int, celda: Vector3i) -> Dictionary:
	var r: Dictionary = mundo.surtir_construccion(celda)
	if r.is_empty():
		return {"estado": "terminada", "espera": 0.0}
	if r.get("bloqueada", false):
		return {"estado": "bloqueada", "espera": ESPERA_BLOQUEADA}
	if r.get("insuficiente", false):
		pausar(id, r["recurso"])
		return {"estado": "pausada", "espera": 0.0}
	pausadas.erase(id)
	if r.get("completa", false):
		var mensaje: String = al_completar.call(mundo, r["metadata"])
		if mensaje != "":
			aviso.emit(mensaje)
		return {"estado": "completa", "espera": 0.0}
	return {"estado": "avanzo", "espera": FinalizacionObras.intervalo_del_paso(mundo, celda)}


func _demoler_un_paso(id: int, celda: Vector3i) -> Dictionary:
	var r: Dictionary = mundo.procesar_deconstruccion(celda)
	if r.is_empty():
		olvidar(id)
		return {"estado": "invalida", "espera": 0.0}
	al_deconstruir.call(mundo, r)
	if r["lista_para_remocion"]:
		al_retirar.call(mundo, id)
		olvidar(id)
		aviso.emit("Edificio demolido.")
		return {"estado": "completa", "espera": 0.0}
	return {"estado": "avanzo", "espera": FinalizacionObras.INTERVALO_PASO}
```

- [ ] **Step 4: Registrar el autoload**

En `godot/project.godot`, sección `[autoload]`, añadir la línea siguiente **justo antes** de `Colonos="*res://scripts/Colonos.gd"` (así existe cuando `Colonos._ready` la lee):

```
Obras="*res://scripts/Obras.gd"
```

- [ ] **Step 5: Ejecutar `ObrasTest.tscn` y verificar que pasa**

Run: comando de verificación con `ObrasTest`. Expected: verde y «Las 9 pruebas de Obras pasaron correctamente». Si `FinalizacionObras.completar_construccion` (valor de Callable) no es válido en el `var al_completar`, cambiar esas tres líneas a `Callable(FinalizacionObras, "completar_construccion")` (y análogas) y repetir.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Obras.gd godot/scripts/ObrasTest.gd godot/scenes/ObrasTest.tscn godot/project.godot
git commit -m "feat: autoload Obras (tareas de construcción y demolición, marcas, pausas y vetos)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Rama «tarea de obra» en `Colonos`

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Test: `godot/scripts/ColonosTest.gd` (TEST 46 al final; actualizar el contador a 46)

**Interfaces:**
- Consumes (Tarea 2): `obras.siguiente_tarea(celda, id)`, `obras.huella_de(id)`, `obras.trabajar(id, tipo) -> {"estado","espera"}`, `obras.vetar(id, id_colono)`.
- Produces: propiedad `Colonos.obras`; campo `c["tarea"]` (`{}` o `{"tipo", "id"}`); `Colonos.obreros_en(id: int) -> int` (colonos cuya tarea es esa obra; lo usa la ventana del edificio).

- [ ] **Step 1: Escribir la prueba que falla (TEST 46)**

En `ColonosTest.gd`, junto a las demás clases internas añadir:

```gdscript
## Obras falsas: ofrece una tarea fija y anota cada llamada a trabajar().
class ObrasFalsa extends RefCounted:
	var tarea: Dictionary = {}
	var huella: Array = []
	var resultado: Dictionary = {"estado": "avanzo", "espera": 0.0}
	var trabajos: Array = []
	var vetos: Array = []

	func siguiente_tarea(_desde: Vector3i, _id_colono: int = -1) -> Dictionary:
		return tarea

	func huella_de(_id: int) -> Array:
		return huella

	func trabajar(id: int, tipo: String) -> Dictionary:
		trabajos.append([id, tipo])
		return resultado

	func vetar(id: int, id_colono: int) -> void:
		vetos.append([id, id_colono])
```

Antes del `print("\n=== Las 45 pruebas ...` insertar (y cambiar ese texto a «Las 46 pruebas»):

```gdscript
	print("\n=== TEST 46: un colono libre va a la obra, trabaja y repite; uno con empleo o con un aprendizaje la ignora; contratar cancela la tarea ===")
	var ciudad46: Node = CiudadScript.new()
	var colonos46: Node = _nuevo_con_puesto(ciudad46)
	var obras46 := ObrasFalsa.new()
	obras46.tarea = {"tipo": "construir", "id": 5}
	obras46.huella = [Vector2i(6, 6), Vector2i(7, 6)]  # una obra de 2 columnas lejos del maderero
	colonos46.obras = obras46
	var id46: int = colonos46.agregar_colono("desempleado", Vector3i(1, 1, 7))
	var c46: Dictionary = colonos46.colonos[id46]
	for _i in range(400):
		colonos46.avanzar(0.1)
		if not obras46.trabajos.is_empty():
			break
	assert(not obras46.trabajos.is_empty() and obras46.trabajos[0] == [5, "construir"], "el colono libre llegó a la obra y trabajó en ella")
	assert(colonos46._junto_a(c46["celda"], obras46.huella), "y trabajó pegado a la obra")
	assert(colonos46.obreros_en(5) == 1 and colonos46.obreros_en(6) == 0, "obreros_en cuenta a los que tienen esa obra como tarea")
	var trabajos_antes46: int = obras46.trabajos.size()
	obras46.resultado = {"estado": "completa", "espera": 0.0}
	for _i in range(60):
		colonos46.avanzar(0.1)
	assert(obras46.trabajos.size() > trabajos_antes46, "mientras la obra avanza, sigue trabajando")
	# Una obra «completa» suelta la tarea: sin trabajo nuevo, el colono vuelve a deambular.
	obras46.tarea = {}
	for _i in range(60):
		colonos46.avanzar(0.1)
	assert(c46["tarea"].is_empty(), "sin obra, el colono no conserva la tarea")
	# Un colono con puesto no pide obras.
	var obras46b := ObrasFalsa.new()
	obras46b.tarea = {"tipo": "construir", "id": 9}
	obras46b.huella = [Vector2i(6, 6)]
	var ciudad46b: Node = CiudadScript.new()
	var colonos46b: Node = _nuevo_con_puesto(ciudad46b)
	colonos46b.obras = obras46b
	var empleado46: int = colonos46b.agregar_colono("desempleado", Vector3i(1, 1, 7))
	ciudad46b.demografia["desempleado"] = 1
	assert(colonos46b.contratar(Vector2i(2, 2), "recolector"), "se contrata al desempleado")
	for _i in range(100):
		colonos46b.avanzar(0.1)
	assert(obras46b.trabajos.is_empty() and colonos46b.colonos[empleado46]["tarea"].is_empty(), "un colono con empleo ignora las obras")
	# Contratar a quien ya tenía tarea la cancela.
	var obras46c := ObrasFalsa.new()
	obras46c.tarea = {"tipo": "construir", "id": 9}
	obras46c.huella = [Vector2i(6, 6)]
	var ciudad46c: Node = CiudadScript.new()
	var colonos46c: Node = _nuevo_con_puesto(ciudad46c)
	colonos46c.obras = obras46c
	var libre46: int = colonos46c.agregar_colono("desempleado", Vector3i(1, 1, 7))
	ciudad46c.demografia["desempleado"] = 1
	for _i in range(3):
		colonos46c.avanzar(0.1)
	assert(not colonos46c.colonos[libre46]["tarea"].is_empty(), "el libre ya tomó una tarea")
	assert(colonos46c.contratar(Vector2i(2, 2), "recolector"), "se contrata")
	assert(colonos46c.colonos[libre46]["tarea"].is_empty(), "contratar cancela la tarea de obra")
	# Un técnico libre también construye.
	var obras46d := ObrasFalsa.new()
	obras46d.tarea = {"tipo": "demoler", "id": 3}
	obras46d.huella = [Vector2i(6, 6)]
	var colonos46d: Node = _nuevo(_mundo_llano(), CiudadScript.new())
	colonos46d.obras = obras46d
	var tecnico46: int = colonos46d.agregar_colono("tecnico", Vector3i(1, 1, 7))
	for _i in range(400):
		colonos46d.avanzar(0.1)
		if not obras46d.trabajos.is_empty():
			break
	assert(not obras46d.trabajos.is_empty() and obras46d.trabajos[0] == [3, "demoler"], "un técnico libre también demuele")
	assert(colonos46d.colonos.has(tecnico46))
```

- [ ] **Step 2: Ejecutar `ColonosTest.tscn` y verificar que falla**

Run: comando de verificación con `ColonosTest`. Expected: fallo (`Invalid assignment of property 'obras'` / aserciones fallidas).

- [ ] **Step 3: Implementar en `Colonos.gd`**

(a) Tras `const RADIO_SERVICIO := 2 ...` añadir:

```gdscript
const FALLOS_PARA_VETAR := 3  # búsquedas fallidas seguidas hacia una obra antes de dejarla (a ese colono) un rato
```

(b) Tras la declaración de `var economia` (después de su `set`, antes del comentario `## id -> {"id", ...`) añadir:

```gdscript
## Coordinador de obras (Obras en el juego): reparte la construcción y demolición a los colonos libres.
var obras: Object = null
```

(c) En `_ready()`, tras `if economia == null: economia = Economia` añadir:

```gdscript
	if obras == null:
		obras = Obras
```

(d) En `agregar_colono`, en el diccionario del colono, cambiar `"trabajo": {}, "carga": {}, "fase": "", "fallos_servicio": 0,` por `"trabajo": {}, "tarea": {}, "carga": {}, "fase": "", "fallos_servicio": 0,`, y en el comentario de `colonos` (l.66-67) añadir `"tarea"` a la lista de campos.

(e) En `_avanzar_colono`, reemplazar:

```gdscript
		if c["trabajo"].is_empty():
			_elegir_destino(c)
		else:
			_decidir_trabajo(c)
```

por:

```gdscript
		if c["trabajo"].is_empty():
			_decidir_ocioso(c)
		else:
			_decidir_trabajo(c)
```

(f) En `_completar_paso`, cambiar `if c["ruta"].is_empty() and c["trabajo"].is_empty():` por `if c["ruta"].is_empty() and c["trabajo"].is_empty() and c["tarea"].is_empty():` (quien va a una obra no espera entre destinos).

(g) Al inicio de `_dejar_lo_que_hacia`, antes de `c["busqueda"] = {}`, añadir `c["tarea"] = {}`.

(h) Justo antes de `_decidir_trabajo` (antes de su comentario de documentación) añadir:

```gdscript
## Colonos que ahora mismo tienen como tarea la obra "id" (para la ventana del edificio).
func obreros_en(id: int) -> int:
	var total := 0
	for c in colonos.values():
		if not c["tarea"].is_empty() and c["tarea"]["id"] == id:
			total += 1
	return total


## Un colono libre (desempleado, o técnico sin puesto) ayuda en las obras: toma la tarea que le
## ofrece Obras (construir o demoler lo más cercano) y la sigue hasta que se acaba; sin obras
## deambula. Un colono con puesto ni pasa por aquí.
func _decidir_ocioso(c: Dictionary) -> void:
	if obras != null and (c["tipo"] == "desempleado" or c["tipo"] == "tecnico"):
		if c["tarea"].is_empty():
			c["tarea"] = obras.siguiente_tarea(c["celda"], c["id"])
		if not c["tarea"].is_empty():
			_trabajar_en_obra(c)
			return
	_elegir_destino(c)


## Va junto a la obra de su tarea y, ya allí, hace un paso (el tiempo que dure el paso es la
## espera). Suelta la tarea si la obra se acabó, no existe o no se puede alcanzar.
func _trabajar_en_obra(c: Dictionary) -> void:
	var tarea: Dictionary = c["tarea"]
	var huella: Array = obras.huella_de(tarea["id"])
	if huella.is_empty():
		c["tarea"] = {}  # la obra ya no existe
		return
	if not _junto_a(c["celda"], huella):
		if c["fallos_servicio"] >= FALLOS_PARA_VETAR:
			obras.vetar(tarea["id"], c["id"])
			c["tarea"] = {}
			c["fallos_servicio"] = 0
			return
		_ir_junto_a(c, huella)
		return
	var resultado: Dictionary = obras.trabajar(tarea["id"], tarea["tipo"])
	c["espera"] = resultado["espera"]
	match resultado["estado"]:
		"avanzo":
			pass
		"bloqueada":
			pass  # alguien está saliendo de la obra: espera y reintenta
		_:
			c["tarea"] = {}  # pausada, completa, terminada o inválida: pide otra tarea
			if resultado["estado"] == "pausada":
				c["espera"] = ESPERA_TRABAJO
```

- [ ] **Step 4: Ejecutar `ColonosTest.tscn` y verificar que pasa**

Run: comando de verificación con `ColonosTest`. Expected: verde y «Las 46 pruebas de Colonos pasaron correctamente». Si el colono del TEST 46 no llega en 400 iteraciones, comprobar que `_junto_a` usa `Vector2i` en la huella y que `_celdas_junto_a(huella)` devuelve celdas en `_mundo_llano()` (lado 10, suelo a y=0, colono en y=1).

- [ ] **Step 5: Ejecutar `EconomiaTest.tscn` y `BuscadorRutasTest.tscn` (regresión)**

Expected: verde en ambas.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: los colonos libres construyen y demuelen las obras que les ofrece Obras

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Marcar desde 1ª persona y la cenital; cableado en `Main`

**Files:**
- Modify: `godot/scripts/Player.gd` (clic derecho con el modo G; `_procesar_deconstruccion`), `godot/scripts/CamaraCenital.gd` (clic en `modo_demoler`, ~l.1356 y `_alternar_modo_demoler`), `godot/scripts/Main.gd` (conexiones)
- Test: `godot/scripts/BlueprintValidatorTest.gd` (TEST 93)

**Interfaces:**
- Consumes: `Obras.alternar_marca(id) -> String`, `Obras.abandonar(id)`, `Obras.mundo`, señal `Obras.aviso(texto)`.
- Produces: `Player._marcar_demolicion()` (clic derecho con `modo_deconstruccion`); en la cenital, el clic con `modo_demoler` alterna la marca del edificio bajo el cursor.

- [ ] **Step 1: Escribir la prueba que falla (TEST 93)**

Antes del `print("\n=== Las 92 pruebas ...` (cambiarlo a «Las 93 pruebas») añadir:

```gdscript
	print("\n=== TEST 93: deconstruir a mano abandona la obra para los colonos, y el clic derecho en modo deconstrucción alterna la marca ===")
	const OX93 := 1300
	mundo.colocar_bloque(Vector3i(OX93, 0, OX93), "tierra", true)
	mundo.colocar_bloque(Vector3i(OX93, 1, OX93), "bloque_piedra", true)
	mundo.colocar_bloque(Vector3i(OX93 + 1, 1, OX93), "bloque_piedra", true)
	var id_93: int = mundo.registrar_edificio_completo({Vector3i(OX93, 0, OX93): "tierra", Vector3i(OX93, 1, OX93): "bloque_piedra", Vector3i(OX93 + 1, 1, OX93): "bloque_piedra"})
	var obras_93: Node = Obras
	obras_93.mundo = mundo
	var hud_falso_93 := HudFalso91.new()
	var jugador_93 := Player.new()
	jugador_93.mundo = mundo
	jugador_93.hud = hud_falso_93
	jugador_93._alternar_modo_deconstruccion()
	jugador_93._procesar_deconstruccion(Vector3i(OX93, 1, OX93))
	assert(obras_93.abandonadas.has(id_93), "una celda deconstruida a mano marca el edificio como abandonado")
	assert(obras_93.esta_reclamada(id_93), "y lo reclama: los colonos se lo ceden mientras el jugador actúa")
	assert(obras_93.siguiente_tarea(Vector3i(OX93, 1, OX93 + 3)).get("tipo", "") != "construir" or obras_93.siguiente_tarea(Vector3i(OX93, 1, OX93 + 3))["id"] != id_93, "los colonos no lo reconstruyen")
	jugador_93._marcar_demolicion_de(id_93)
	assert(obras_93.esta_marcado(id_93), "el clic derecho marca el edificio")
	jugador_93._marcar_demolicion_de(id_93)
	assert(not obras_93.esta_marcado(id_93), "y otro clic lo desmarca")
	jugador_93._marcar_demolicion_de(-1)
	assert(hud_falso_93.avisos.size() >= 1, "sin edificio bajo la mira se avisa")
	obras_93.olvidar(id_93)
	obras_93.mundo = null
	jugador_93.free()
	hud_falso_93.free()
	print("OK: la 1ª persona abandona al deconstruir y marca con el clic derecho.")

```

- [ ] **Step 2: Ejecutar `Test.tscn` y verificar que falla**

Expected: fallo (`_marcar_demolicion_de` no existe / `Obras.abandonadas` sin el id).

- [ ] **Step 3: Implementar en `Player.gd`**

(a) En `_procesar_deconstruccion`, justo después de la línea que llama a `FinalizacionObras.al_deconstruir(mundo, resultado)` (tras el `if resultado.is_empty(): ... return`), añadir:

```gdscript
	Obras.abandonar(resultado["id"])  # lo que se deconstruye a mano no lo reconstruyen los colonos
```

(b) En `_input`, rama `MOUSE_BUTTON_RIGHT`, dentro del `if modo_deconstruccion:` que ya existe, sustituir el `if boton.pressed: _avisar_modo_deconstruccion("colocar bloques")` por:

```gdscript
					if boton.pressed:
						_marcar_demolicion()
```

(c) Junto a `_avisar_modo_deconstruccion` añadir:

```gdscript
## Clic derecho con el modo deconstrucción: marca (o desmarca) para demolición el edificio
## bajo la mira; los colonos libres lo demolerán.
func _marcar_demolicion() -> void:
	var id := -1
	if raycast.is_colliding() and mundo != null:
		id = mundo.id_de_edificio(_celda_impactada())
	_marcar_demolicion_de(id)


func _marcar_demolicion_de(id: int) -> void:
	if id == -1:
		hud.notificar("No hay ningún edificio ahí para marcar.")
		return
	var motivo: String = Obras.alternar_marca(id)
	if motivo != "":
		hud.notificar(motivo)
	elif Obras.esta_marcado(id):
		hud.notificar("Edificio marcado para demolición.")
	else:
		hud.notificar("Marca de demolición quitada.")
```

(e) Preferencia del jugador: en `_colocar`, justo dentro de `if not resultado.is_empty():` (tras `var resultado: Dictionary = mundo.surtir_construccion(celda)`), añadir como primera línea `Obras.reclamar(mundo.id_de_edificio(celda))`; y en `_procesar_deconstruccion`, junto a `Obras.abandonar(...)`, añadir `Obras.reclamar(resultado["id"])`.

(d) La función `_avisar_modo_deconstruccion("colocar bloques")` deja de usarse para el clic derecho (sigue usándose para minar/talar): no borrarla.

- [ ] **Step 4: Implementar en `CamaraCenital.gd`**

(a) En el manejador de clic, sustituir `pass  # marcar edificios para demolición: fuera de alcance por ahora (ver modo_demoler)` por `_procesar_clic_demoler(boton.position)`.

(b) Junto a `_procesar_clic_interaccion` añadir:

```gdscript
## Clic con el modo demoler: marca (o desmarca) para demolición el edificio bajo el cursor.
## La celda de superficie puede ser la del techo o el suelo contiguo, así que se prueba también la de debajo.
func _procesar_clic_demoler(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	var id: int = mundo.id_de_edificio(celda)
	if id == -1:
		id = mundo.id_de_edificio(celda + Vector3i(0, -1, 0))
	if id == -1:
		hud.notificar("No hay ningún edificio ahí para marcar.")
		return
	var motivo: String = Obras.alternar_marca(id)
	if motivo != "":
		hud.notificar(motivo)
	elif Obras.esta_marcado(id):
		hud.notificar("Edificio marcado para demolición.")
	else:
		hud.notificar("Marca de demolición quitada.")
```

(c) En `_alternar_modo_demoler`, cambiar el contexto por `hud.mostrar_contexto("Demoler", {}, ["(clic izq.) MARCAR PARA DEMOLICIÓN\n[Esc] Salir"])` y actualizar el comentario de documentación de la función (ya no es «solo el interruptor»).

- [ ] **Step 5: Cablear en `Main.gd`**

En `_ready()`, junto a `Colonos.mundo = mundo` (l.30) añadir:

```gdscript
	Obras.mundo = mundo
	Obras.aviso.connect(hud.notificar)
```

(Si `hud` no está disponible en ese punto de `_ready()`, colocar las dos líneas tras la línea que lo asigna; revisar el orden en `Main.gd`.)

- [ ] **Step 6: Ejecutar pruebas**

Run: `Test`, `HUDTest`, `CamaraCenitalModosTest`, `ColonosTest`, `ObrasTest`. Expected: verde en todas; en `Test`, «Las 93 pruebas ...». Si `CamaraCenitalModosTest` afirma el texto de la tarjeta «Demoler», actualizarlo al nuevo.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Player.gd godot/scripts/CamaraCenital.gd godot/scripts/Main.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: marcar edificios para demolición con el clic derecho (G) y desde la cenital

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Ventana del edificio (`PanelEdificio`) y botón «Demoler» en el panel del puesto

**Files:**
- Create: `godot/scripts/PanelEdificio.gd`
- Modify: `godot/scripts/HUD.gd` (crear el panel y abrirlo/cerrarlo), `godot/scripts/CamaraCenital.gd` (`_procesar_clic_interaccion` y un helper compartido con `_procesar_clic_demoler`), `godot/scripts/PanelPuesto.gd` (botón «Demoler»)
- Test: `godot/scripts/HUDTest.gd` (`probar_panel_edificio`)

**Interfaces:**
- Consumes (Tareas 2 y 3): `Obras.resumen_de(id)`, `alternar_pausa(id)`, `alternar_marca(id) -> String`, `esta_marcado(id)`, `id_en_columna(columna)`; `Colonos.obreros_en(id)`; `Ciudad.almacen` (cada recurso tiene `.cantidad`; `"madera"` suma `"tablas"`).
- Produces: `PanelEdificio` (`PanelContainer`) con `abrir(id: int)`, `cerrar()`, señal `aviso(texto: String)` y propiedades inyectables `obras`, `colonos`, `ciudad` (por defecto los autoloads); `HUD.abrir_panel_edificio(id: int)`; `HUD.cerrar_panel_puesto()` pasa a cerrar también el panel del edificio; `PanelPuesto` gana la señal `aviso`.

- [ ] **Step 1: Escribir la prueba que falla (HUDTest)**

En `HUDTest.gd`, junto a las demás clases internas, añadir:

```gdscript
class ObrasPanelFalso extends RefCounted:
	var resumen: Dictionary = {}
	var marcados: Dictionary = {}
	var pausas := 0
	var rechazo := ""

	func resumen_de(_id: int) -> Dictionary:
		return resumen

	func alternar_pausa(_id: int) -> void:
		pausas += 1
		resumen["pausada"] = not resumen["pausada"]

	func alternar_marca(id: int) -> String:
		if rechazo != "":
			return rechazo
		if marcados.has(id):
			marcados.erase(id)
			resumen["estado"] = "construccion"
		else:
			marcados[id] = true
			resumen["estado"] = "demolicion"
		return ""

	func esta_marcado(id: int) -> bool:
		return marcados.has(id)


class ColonosPanelFalso extends RefCounted:
	func obreros_en(_id: int) -> int:
		return 3
```

Y una función llamada desde `ejecutar_pruebas()` junto a las demás `probar_*` (con su `print` de cabecera):

```gdscript
func probar_panel_edificio() -> void:
	print("=== TEST: PanelEdificio muestra los datos del edificio y sus botones actúan sobre Obras ===")
	var PanelEdificioScript = preload("res://scripts/PanelEdificio.gd")
	var ciudad: Node = preload("res://scripts/Ciudad.gd").new()
	ciudad.almacen["piedra"].cantidad = 4.0
	var obras := ObrasPanelFalso.new()
	obras.resumen = {"nombre": "Casa", "tipo": "Residencial", "estado": "construccion", "pausada": false, "salud": 0.25, "faltantes": {"piedra": 15}}
	var panel: PanelContainer = PanelEdificioScript.new()
	panel.obras = obras
	panel.colonos = ColonosPanelFalso.new()
	panel.ciudad = ciudad
	add_child(panel)
	var avisos: Array = []
	panel.aviso.connect(func(texto: String) -> void: avisos.append(texto))
	panel.abrir(7)
	assert(panel.visible, "se abre")
	assert(panel._titulo.text == "Casa" and panel._tipo.text.contains("Residencial"), "nombre y tipo")
	assert(panel._estado.text.contains("En construcción") and not panel._estado.text.contains("pausada"), "estado")
	assert(panel._salud.text == "Salud: 25 %", "salud: %s" % panel._salud.text)
	assert(panel._obreros.visible and panel._obreros.text == "Obreros: 3", "obreros")
	assert(panel._materiales.visible and panel._materiales.text.contains("15") and panel._materiales.text.contains("4"), "faltan 15 de piedra y hay 4: %s" % panel._materiales.text)
	assert(panel._pausar.visible and panel._pausar.text == "Pausar construcción" and panel._demoler.text == "Demoler", "botones")
	panel._pausar.pressed.emit()
	assert(obras.pausas == 1 and panel._pausar.text == "Reanudar" and panel._estado.text.contains("pausada"), "pausar actúa sobre Obras y cambia la etiqueta")
	panel._demoler.pressed.emit()
	assert(obras.marcados.has(7) and panel._demoler.text == "Cancelar demolición" and panel._pausar.text == "Reanudar", "demoler marca el edificio")
	obras.rechazo = "El núcleo urbano no se puede demoler."
	panel._demoler.pressed.emit()
	assert(avisos == ["El núcleo urbano no se puede demoler."], "un rechazo se avisa")
	obras.resumen = {"nombre": "Casa", "tipo": "Residencial", "estado": "completo", "pausada": false, "salud": 1.0, "faltantes": {}}
	panel._actualizar()
	assert(panel._salud.text == "Salud: 100 %" and not panel._materiales.visible and not panel._obreros.visible and not panel._pausar.visible, "completo: 100 %, sin materiales, sin obreros y sin botón de pausa")
	obras.resumen = {}
	panel._process(0.0)
	assert(not panel.visible, "se cierra solo si el edificio desaparece")
	panel.queue_free()
	ciudad.free()
```

- [ ] **Step 2: Ejecutar `HUDTest.tscn` y verificar que falla**

Expected: `Parse Error` (no existe `PanelEdificio.gd`).

- [ ] **Step 3: Crear `PanelEdificio.gd`**

```gdscript
extends PanelContainer

## Ventana de un edificio u obra (clic izquierdo sobre él en la cenital, ver
## CamaraCenital._procesar_clic_interaccion). Muestra nombre, tipo, estado, salud, obreros y
## materiales que faltan, y tiene los botones «Pausar/Reanudar» y «Demoler/Cancelar demolición».
## Las reglas viven en Obras/Colonos; esto solo las muestra y les pasa los clics.

const HUDScript = preload("res://scripts/HUD.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")

## Mensaje para el jugador (el HUD lo envía a las notificaciones).
signal aviso(texto: String)

const NOMBRES_ESTADO := {"construccion": "En construcción", "demolicion": "En demolición", "completo": "Completo"}

var id := -1
var obras: Object = null
var colonos: Object = null
var ciudad: Object = null

var _titulo := TemaHUD.etiqueta()
var _tipo := TemaHUD.etiqueta()
var _estado := TemaHUD.etiqueta()
var _salud := TemaHUD.etiqueta()
var _obreros := TemaHUD.etiqueta()
var _materiales := TemaHUD.etiqueta()
var _pausar := Button.new()
var _demoler := Button.new()


func _ready() -> void:
	if obras == null:
		obras = Obras
	if colonos == null:
		colonos = Colonos
	if ciudad == null:
		ciudad = Ciudad
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP  # los botones necesitan capturar el clic
	# Abajo a la derecha, como el panel del puesto: arriba las notificaciones ocupan ese lugar.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -280.0
	offset_bottom = -12.0
	offset_right = -12.0
	custom_minimum_size.x = 268.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var caja := VBoxContainer.new()
	add_child(caja)
	_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	caja.add_child(_titulo)
	for etiqueta in [_tipo, _estado, _salud, _obreros, _materiales]:
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 250.0
		caja.add_child(etiqueta)
	for boton in [_pausar, _demoler]:
		TemaHUD.estilizar_boton(boton)
		caja.add_child(boton)
	_pausar.pressed.connect(func() -> void:
		obras.alternar_pausa(id)
		_actualizar())
	_demoler.pressed.connect(_on_demoler)


func abrir(nuevo_id: int) -> void:
	if obras.resumen_de(nuevo_id).is_empty():
		return
	id = nuevo_id
	visible = true
	_actualizar()


func cerrar() -> void:
	visible = false
	id = -1


func _process(_delta: float) -> void:
	if not visible:
		return
	if obras.resumen_de(id).is_empty():
		cerrar()  # el edificio desapareció con la ventana abierta
		return
	_actualizar()


func _on_demoler() -> void:
	var motivo: String = obras.alternar_marca(id)
	if motivo != "":
		aviso.emit(motivo)
	_actualizar()


func _actualizar() -> void:
	var r: Dictionary = obras.resumen_de(id)
	if r.is_empty():
		return
	var estado: String = r["estado"]
	_titulo.text = r["nombre"]
	_tipo.text = "Tipo: %s" % r["tipo"]
	_estado.text = "Estado: " + NOMBRES_ESTADO[estado] + (" (pausada)" if r["pausada"] and estado != "completo" else "")
	_salud.text = "Salud: %d %%" % roundi(r["salud"] * 100.0)
	var en_obra: bool = estado != "completo"
	_obreros.visible = en_obra
	_obreros.text = "Obreros: %d" % colonos.obreros_en(id)
	var faltan: bool = estado == "construccion" and not r["faltantes"].is_empty()
	_materiales.visible = faltan
	if faltan:
		var partes: Array = []
		for recurso in r["faltantes"]:
			partes.append("%d %s (hay %d)" % [r["faltantes"][recurso], HUDScript.NOMBRES_RECURSO.get(recurso, recurso), int(_en_almacen(recurso))])
		_materiales.text = "Faltan: " + ", ".join(partes)
	_pausar.visible = en_obra
	_pausar.text = "Reanudar" if r["pausada"] else ("Pausar demolición" if estado == "demolicion" else "Pausar construcción")
	_demoler.text = "Cancelar demolición" if estado == "demolicion" else "Demoler"


func _en_almacen(recurso: String) -> float:
	var almacen: Dictionary = ciudad.almacen
	if recurso == "madera":
		return almacen["tablas"].cantidad + almacen["madera"].cantidad
	return almacen[recurso].cantidad if almacen.has(recurso) else 0.0
```

- [ ] **Step 4: Cablear en `HUD.gd`**

(a) Junto a `const PanelPuestoScript = ...` (l.24) añadir `const PanelEdificioScript = preload("res://scripts/PanelEdificio.gd")`; junto a `var _panel_puesto: PanelContainer` (l.59) añadir `var _panel_edificio: PanelContainer`.

(b) Tras las líneas que crean `_panel_puesto` (`_panel_puesto = PanelPuestoScript.new()` / `add_child(_panel_puesto)`, ~l.99-100) añadir:

```gdscript
	_panel_puesto.aviso.connect(notificar)
	_panel_edificio = PanelEdificioScript.new()
	add_child(_panel_edificio)
	_panel_edificio.aviso.connect(notificar)
```

(c) Reemplazar `abrir_panel_puesto` y `cerrar_panel_puesto` por:

```gdscript
func abrir_panel_puesto(esquina: Vector2i) -> void:
	_panel_edificio.cerrar()
	_panel_puesto.abrir(esquina)


func cerrar_panel_puesto() -> void:
	_panel_puesto.cerrar()
	_panel_edificio.cerrar()


## Ventana de un edificio u obra (ver PanelEdificio).
func abrir_panel_edificio(id: int) -> void:
	_panel_puesto.cerrar()
	_panel_edificio.abrir(id)
```

- [ ] **Step 5: Añadir «Demoler» a `PanelPuesto.gd`**

(a) Tras las `const`, añadir `signal aviso(texto: String)`; junto a las demás variables, `var _demoler := Button.new()`.

(b) En `_ready()`, tras el bucle que añade `_trabajadores, _libres, ...` a `caja`, añadir:

```gdscript
	TemaHUD.estilizar_boton(_demoler)
	_demoler.pressed.connect(_on_demoler)
	caja.add_child(_demoler)
```

(c) Añadir:

```gdscript
## Marca (o desmarca) el edificio del puesto para demolición, sin activar la herramienta.
func _on_demoler() -> void:
	var id: int = Obras.id_en_columna(esquina)
	if id == -1:
		aviso.emit("No se encontró el edificio del puesto.")
		return
	var motivo: String = Obras.alternar_marca(id)
	if motivo != "":
		aviso.emit(motivo)
```

(d) Al final de `_actualizar()` añadir:

```gdscript
	_demoler.text = "Cancelar demolición" if Obras.esta_marcado(Obras.id_en_columna(esquina)) else "Demoler"
```

- [ ] **Step 6: Clic en la cenital**

En `CamaraCenital.gd` añadir el helper y usarlo en dos sitios:

```gdscript
## Id del edificio en "celda" o, si no hay, en la de debajo (la celda de superficie puede ser el techo
## o el suelo contiguo); -1 si no hay ninguno.
func _edificio_bajo_celda(celda: Vector3i) -> int:
	var id: int = mundo.id_de_edificio(celda)
	if id == -1:
		id = mundo.id_de_edificio(celda + Vector3i(0, -1, 0))
	return id
```

`_procesar_clic_demoler` (Tarea 4): reemplazar sus cuatro primeras líneas (`var celda ...` hasta el `if id == -1:` de la celda de debajo) por `var id := _edificio_bajo_celda(_celda_bajo_mouse(posicion_pantalla))`, conservando el resto.

`_procesar_clic_interaccion`: reemplazar su cuerpo por:

```gdscript
func _procesar_clic_interaccion(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	var esquina_puesto := Recoleccion.esquina_de_puesto_en(celda)
	if esquina_puesto != Recoleccion.SIN_PUESTO:
		hud.abrir_panel_puesto(esquina_puesto)
		return
	var id := _edificio_bajo_celda(celda)
	if id != -1:
		hud.abrir_panel_edificio(id)
	else:
		hud.cerrar_panel_puesto()
```

- [ ] **Step 7: Ejecutar pruebas**

Run: `HUDTest`, `CamaraCenitalModosTest`, `PuestosPrevisualizacionTest`, `ObrasTest`, `ColonosTest`, `Test`. Expected: verde en todas. Si `HUDTest` no llama a `probar_panel_edificio`, añadir la llamada en `ejecutar_pruebas()`.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/PanelEdificio.gd godot/scripts/HUD.gd godot/scripts/PanelPuesto.gd godot/scripts/CamaraCenital.gd godot/scripts/HUDTest.gd
git commit -m "feat: ventana del edificio con pausa y demolición, y botón Demoler en el panel del puesto

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Overlay rojo de las marcas y documentación

**Files:**
- Create: `godot/scripts/MarcasDemolicionOverlay.gd`
- Modify: `godot/scripts/Main.gd` (crear el overlay en `_ready()`), `docs/Pendientes y próximos pasos.md`, `docs/superpowers/specs/2026-10-02-obras-por-colonos-design.md`, el documento técnico de la PoC afectada
- Test: `godot/scripts/HUDTest.gd` (aserciones del overlay)

**Interfaces:**
- Consumes: `Obras.marca_cambiada(id, marcado)`, `Obras.marcados`, `mundo.edificio_a_celdas[id]`.
- Produces: `MarcasDemolicionOverlay` (`Node3D`) con `reconstruir()` y propiedades `mundo`, `obras` inyectables; una caja translúcida roja por celda de cada edificio marcado.

- [ ] **Step 1: Escribir la prueba que falla (HUDTest)**

En `HUDTest.gd` añadir una función `probar_marcas_demolicion()` llamada desde `ejecutar_pruebas()` junto a las otras (seguir el patrón de las demás funciones `probar_*` y su `print`):

```gdscript
func probar_marcas_demolicion() -> void:
	print("=== TEST: MarcasDemolicionOverlay dibuja una caja roja por celda de cada edificio marcado ===")
	var MarcasScript = preload("res://scripts/MarcasDemolicionOverlay.gd")
	var obras := ObrasFalsa.new()
	obras.marcados = {7: true}
	obras.celdas = {7: [Vector3i(1, 1, 1), Vector3i(2, 1, 1)], 8: [Vector3i(5, 1, 5)]}
	var overlay: Node3D = MarcasScript.new()
	overlay.obras = obras
	add_child(overlay)
	overlay.reconstruir()
	assert(overlay.get_child_count() == 2, "una caja por celda del edificio marcado y ninguna del otro: %d" % overlay.get_child_count())
	obras.marcados = {}
	overlay.reconstruir()
	assert(overlay.get_child_count() == 0, "al desmarcar se quitan")
	obras.marcados = {8: true}
	obras.marca_cambiada.emit(8, true)
	assert(overlay.get_child_count() == 1, "la señal marca_cambiada reconstruye")
	overlay.queue_free()
```

con la clase de apoyo (junto a las demás clases internas de `HUDTest.gd`):

```gdscript
class ObrasFalsa extends RefCounted:
	signal marca_cambiada(id: int, marcado: bool)
	var marcados: Dictionary = {}
	var celdas: Dictionary = {}
	func celdas_de(id: int) -> Array:
		return celdas.get(id, [])
```

- [ ] **Step 2: Ejecutar `HUDTest.tscn` y verificar que falla**

Expected: `Parse Error` (no existe `MarcasDemolicionOverlay.gd`).

- [ ] **Step 3: Crear `MarcasDemolicionOverlay.gd`**

```gdscript
extends Node3D

## Tinte rojo translúcido sobre los edificios marcados para demolición (ver Obras.gd): una caja
## por celda del edificio, reconstruida entera cada vez que cambia una marca (hay pocos edificios
## marcados). Mismo patrón que ZonaOverlay.gd y NivelacionOverlay.gd; no toca el mundo.

const COLOR := Color(1.0, 0.15, 0.15, 0.35)
const DESF := 0.5  # una celda ocupa [celda, celda+1]: su centro está en celda + DESF
const PRIORIDAD := 3

## Quién dice qué edificios están marcados (Obras en el juego) y de qué celdas se compone cada uno.
var obras: Object = null:
	set(valor):
		if obras != null and obras.marca_cambiada.is_connected(_on_marca_cambiada):
			obras.marca_cambiada.disconnect(_on_marca_cambiada)
		obras = valor
		if obras != null:
			obras.marca_cambiada.connect(_on_marca_cambiada)

var _malla: BoxMesh
var _material: StandardMaterial3D


func _init() -> void:
	_malla = BoxMesh.new()
	_malla.size = Vector3.ONE * 1.02  # un pelo más grande: evita el z-fighting con las caras del edificio
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.render_priority = PRIORIDAD


func _on_marca_cambiada(_id: int, _marcado: bool) -> void:
	reconstruir()


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
		remove_child(hijo)
	if obras == null:
		return
	for id: int in obras.marcados:
		for celda: Vector3i in obras.celdas_de(id):
			var caja := MeshInstance3D.new()
			caja.mesh = _malla
			caja.material_override = _material
			caja.position = Vector3(celda) + Vector3(DESF, DESF, DESF)
			add_child(caja)
```

- [ ] **Step 4: Añadir `celdas_de(id)` a `Obras.gd` y probar**

En `Obras.gd`, junto a `huella_de`:

```gdscript
## Celdas (Vector3i) del edificio; vacío si no existe. Lo usa MarcasDemolicionOverlay.
func celdas_de(id: int) -> Array:
	if mundo == null or not mundo.edificio_a_celdas.has(id):
		return []
	return mundo.edificio_a_celdas[id]
```

Y en `ObrasTest.gd`, antes del `print` final (y cambiar el contador a «Las 10 pruebas»):

```gdscript
	print("\n=== TEST 10: celdas_de devuelve las celdas del edificio ===")
	var mundo10 := MundoObraFalso.new()
	mundo10.agregar(1, Vector3i(5, 0, 5), 2, 0)
	var obras10: Node = _nuevas(mundo10)
	assert(obras10.celdas_de(1) == [Vector3i(5, 0, 5), Vector3i(6, 0, 5)] and obras10.celdas_de(9).is_empty())
```

- [ ] **Step 5: Crear el overlay desde código en `Main.gd`**

En `_ready()`, tras las líneas de `Obras` del Task 4, añadir:

```gdscript
	var marcas_demolicion := preload("res://scripts/MarcasDemolicionOverlay.gd").new()
	marcas_demolicion.obras = Obras
	add_child(marcas_demolicion)
```

- [ ] **Step 6: Ejecutar pruebas**

Run: `HUDTest`, `ObrasTest`, `Test`. Expected: verde. Si `queue_free()` seguido de `remove_child` en `reconstruir()` rompe el conteo en la prueba, dejar solo `remove_child(hijo)` + `hijo.queue_free()` (ese orden).

- [ ] **Step 7: Documentación**

- `docs/Pendientes y próximos pasos.md`: marcar 7b como ✅ (2026-10-02) en la sección 4b y describir en el punto 6 de la lista principal («Construcción/deconstrucción asistida por NPCs») que ya está hecha para edificios y puestos, y que quedan pendientes el tendido de vías, el tope de cuadrilla y las prioridades de obra.
- Especificación: en «Flujo → Demolición», sustituir el punto 4 por: «Al desmarcar, los colonos dejan de deconstruir. El edificio queda a medias como obra fantasma **abandonada**: los colonos no lo reconstruyen solos (igual que lo que el jugador deconstruye a mano); el jugador puede reconstruirlo en 1ª persona.»
- Documento técnico: añadir una sección breve «Obras por colonos» a `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md` con las decisiones de la especificación (Obras, FinalizacionObras, rama de Colonos, abandonadas, vetos).

- [ ] **Step 8: Verificación final y commit**

Run: `Test`, `ObrasTest`, `ColonosTest`, `HUDTest`, `CamaraCenitalModosTest`, `EconomiaTest`, `BuscadorRutasTest`, `PuestosPrevisualizacionTest`. Expected: verde en todas.

```bash
git add godot/scripts/MarcasDemolicionOverlay.gd godot/scripts/Obras.gd godot/scripts/ObrasTest.gd godot/scripts/Main.gd godot/scripts/HUDTest.gd docs
git commit -m "feat: tinte rojo de los edificios marcados y documentación de las obras por colonos

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
