# Deconstrucción de Edificios Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El jugador puede deconstruir cualquier edificio ya registrado (declarado a mano o vía blueprint, terminado o a medio construir) bloque por bloque en orden inverso al de construcción, hasta eliminarlo por completo — la tierra de nivelación queda aislada (nunca se deconstruye), la capacidad de camas se retira al iniciar (no al terminar), y la zona de influencia (con radio según la categoría del edificio) se reduce correctamente al completar la demolición.

**Architecture:** Se reutiliza `Construccion.gd` (ya usado para la construcción fantasma) en reversa: cada bloque real se registra como "pendiente de convertir a fantasma", en el orden opuesto al de construcción. Un nuevo índice inverso en `VoxelWorld` (id de edificio -> sus celdas) permite recuperar qué queda por revertir. `Zonificacion` gana un registro de contribuciones por edificio (con su propio margen según categoría) para poder crecer y reducir la zona de influencia con el mismo cálculo. Una tecla nueva (`G`) en `Player.gd` alterna un modo de deconstrucción con feedback en el HUD.

**Tech Stack:** Godot 4.7 GDScript.

**Spec:** `docs/superpowers/specs/2026-09-11-deconstruccion-edificios-design.md`

## Global Constraints

- La tierra de relleno de nivelación de un blueprint NUNCA se registra como parte del edificio (ni inmune al minado, ni parte de la deconstrucción) — desde el primer instante en que se coloca como fantasma.
- El núcleo urbano NO se puede deconstruir.
- Los puestos periféricos (mina, caza/recolección) NO pasan por este sistema.
- Deconstruir no recupera recursos — cada bloque revertido simplemente desaparece.
- La capacidad de camas (`Ciudad.capacidad_camas_construida`) se retira al INICIAR la deconstrucción de un edificio (primera vez que se llama `procesar_deconstruccion()` para ese id), no al completarla.
- El margen de ampliación de zona de influencia depende de la categoría del edificio: residencial 6, investigación/industrial 10, militar 12 (núcleo: 15, sin cambios, no depende de categoría).
- Verificación: ejecutar `godot/scenes/Test.tscn`, `godot/scenes/CiudadTest.tscn`, `godot/scenes/RecoleccionTest.tscn`, `godot/scenes/ZonificacionTest.tscn` (todas las aserciones deben pasar) y `godot/scenes/Main.tscn` (sin errores nuevos más allá de las advertencias conocidas de colisión de nombre de clase / UID inválido en worktrees nuevos).

---

### Task 1: `Ciudad.gd` — retirar capacidad de camas

**Files:**
- Modify: `godot/scripts/Ciudad.gd`
- Modify: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Produces: `Ciudad.retirar_edificio_residencial(total_camas: int) -> void`. Consumido por Task 7 (`Player.gd`).

- [ ] **Step 1: Agregar `retirar_edificio_residencial()`**

En `godot/scripts/Ciudad.gd`, localiza:

```gdscript
## Registra un edificio residencial recién declarado válido (ver
## Player.gd::_declarar_edificio). ponytail: no deduplica — declarar el mismo
## edificio dos veces suma sus camas dos veces; corregir cuando exista un
## registro real de edificios declarados (identidad/posición), no solo un
## contador acumulado.
func registrar_edificio_residencial(total_camas: int) -> void:
	capacidad_camas_construida += total_camas
```

Agrega inmediatamente después:

```gdscript


## Retira la capacidad de camas de un edificio residencial que empieza a
## deconstruirse (ver Player.gd::_procesar_deconstruccion) — simétrica a
## registrar_edificio_residencial(). Se llama al INICIAR la deconstrucción
## de un edificio ya terminado (no al completarla): un ciudadano no debería
## poder "vivir" en una cama que ya está siendo desmontada, aunque las
## paredes tarden más en desaparecer. clamp a 0 por seguridad (nunca debería
## bajar de 0 si la contabilidad es correcta, pero un edificio nunca debe
## dejar el contador en negativo).
func retirar_edificio_residencial(total_camas: int) -> void:
	capacidad_camas_construida = max(0, capacidad_camas_construida - total_camas)
```

- [ ] **Step 2: Agregar TEST 8 en `CiudadTest.gd`**

Localiza:

```gdscript
	print("\n=== TEST 7: Registro de Edificios Residenciales Declarados ===")
	# Ver Player.gd::_declarar_edificio: al declarar un edificio válido, suma
	# las camas de todos sus pisos a Ciudad.capacidad_camas_construida.
	assert(urbe.capacidad_camas_construida == 0)
	urbe.registrar_edificio_residencial(2)
	urbe.registrar_edificio_residencial(3)
	print("Capacidad de camas construida tras declarar 2 edificios: ", urbe.capacidad_camas_construida)
	assert(urbe.capacidad_camas_construida == 5)

	print("\n=== Las 7 pruebas de Ciudad pasaron correctamente ===")
```

Reemplaza por:

```gdscript
	print("\n=== TEST 7: Registro de Edificios Residenciales Declarados ===")
	# Ver Player.gd::_declarar_edificio: al declarar un edificio válido, suma
	# las camas de todos sus pisos a Ciudad.capacidad_camas_construida.
	assert(urbe.capacidad_camas_construida == 0)
	urbe.registrar_edificio_residencial(2)
	urbe.registrar_edificio_residencial(3)
	print("Capacidad de camas construida tras declarar 2 edificios: ", urbe.capacidad_camas_construida)
	assert(urbe.capacidad_camas_construida == 5)

	print("\n=== TEST 8: retirar_edificio_residencial() ===")
	# Ver Player.gd::_procesar_deconstruccion: al iniciar la deconstrucción
	# de un edificio ya terminado, retira su capacidad de camas.
	urbe.retirar_edificio_residencial(2)
	print("Capacidad de camas construida tras retirar 2: ", urbe.capacidad_camas_construida)
	assert(urbe.capacidad_camas_construida == 3)
	urbe.retirar_edificio_residencial(100)  # más de lo que queda
	assert(urbe.capacidad_camas_construida == 0, "Nunca debe bajar de 0")

	print("\n=== Las 8 pruebas de Ciudad pasaron correctamente ===")
```

- [ ] **Step 3: Ejecutar `CiudadTest.tscn` y verificar las 8 pruebas**

Ejecuta `godot/scenes/CiudadTest.tscn` (headless o en el editor) y confirma la salida `"=== Las 8 pruebas de Ciudad pasaron correctamente ==="` sin ningún `assert` fallido, sin errores nuevos.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/CiudadTest.gd
git commit -m "feat: retirar capacidad de camas al iniciar la deconstrucción de un edificio"
```

---

### Task 2: `Recoleccion.gd` — liberar la reserva de un edificio demolido

**Files:**
- Modify: `godot/scripts/Recoleccion.gd`
- Modify: `godot/scripts/RecoleccionTest.gd`

**Interfaces:**
- Produces: `Recoleccion.quitar_puesto(esquina: Vector2i) -> void`. Consumido por Task 7 (`Player.gd`).

- [ ] **Step 1: Agregar `quitar_puesto()`**

En `godot/scripts/Recoleccion.gd`, localiza:

```gdscript
func colocar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int) -> void:
	puestos[esquina] = {"tipo": tipo, "ancho": ancho, "alto": alto, "nivel": 1}
```

Agrega inmediatamente después:

```gdscript


## Libera la reserva de un puesto/edificio en "esquina" — usada al
## completarse la deconstrucción total de un edificio (ver
## VoxelWorld.eliminar_edificio()/Player.gd) para que su footprint vuelva a
## estar disponible para una nueva construcción. No-op si no había nada
## registrado en esa esquina (p. ej. un edificio declarado a mano, que
## nunca pasa por colocar_puesto()).
func quitar_puesto(esquina: Vector2i) -> void:
	puestos.erase(esquina)
```

- [ ] **Step 2: Agregar TEST 10 en `RecoleccionTest.gd`**

Al final del archivo, localiza:

```gdscript
	print("\n=== TEST 9: tasas_caza_recoleccion() multiplica cada señal por su tasa base ===")
	var tasas_caza: Dictionary = Recoleccion.tasas_caza_recoleccion({"fauna": 0.5, "frutal": 0.25})
	assert(is_equal_approx(tasas_caza["caza"], 0.5 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))
	assert(is_equal_approx(tasas_caza["recoleccion"], 0.25 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))

	print("\n=== Las 9 pruebas de Recoleccion pasaron correctamente ===")
```

Reemplaza por:

```gdscript
	print("\n=== TEST 9: tasas_caza_recoleccion() multiplica cada señal por su tasa base ===")
	var tasas_caza: Dictionary = Recoleccion.tasas_caza_recoleccion({"fauna": 0.5, "frutal": 0.25})
	assert(is_equal_approx(tasas_caza["caza"], 0.5 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))
	assert(is_equal_approx(tasas_caza["recoleccion"], 0.25 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))

	print("\n=== TEST 10: quitar_puesto() libera la reserva ===")
	Recoleccion.puestos.clear()
	Recoleccion.colocar_puesto(Vector2i(50, 50), "blueprint", 5, 5)
	assert(Recoleccion.celda_dentro_de_algun_puesto(Vector2i(52, 52)))
	Recoleccion.quitar_puesto(Vector2i(50, 50))
	assert(not Recoleccion.celda_dentro_de_algun_puesto(Vector2i(52, 52)))
	Recoleccion.quitar_puesto(Vector2i(999, 999))  # no existía, no debe fallar
	print("OK: quitar_puesto() libera la reserva; quitar una esquina sin nada registrado no falla.")

	print("\n=== Las 10 pruebas de Recoleccion pasaron correctamente ===")
```

- [ ] **Step 3: Ejecutar `RecoleccionTest.tscn` y verificar las 10 pruebas**

Ejecuta `godot/scenes/RecoleccionTest.tscn` y confirma la salida `"=== Las 10 pruebas de Recoleccion pasaron correctamente ==="` sin ningún `assert` fallido, sin errores nuevos.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: liberar la reserva de un puesto/edificio al deconstruirlo"
```

---

### Task 3: `BlueprintValidator.gd` — campo "categoria"

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Produces: `estructura_a_blueprint()` gana el campo `"categoria": "residencial"` en el dict devuelto. Consumido por Task 7 (`Player.gd`, al llamar `Zonificacion.ampliar_influencia(id, huella, blueprint["categoria"])`).

- [ ] **Step 1: Agregar `"categoria"` al dict devuelto por `estructura_a_blueprint()`**

En `godot/scripts/BlueprintValidator.gd`, localiza:

```gdscript
	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,       # x_max ya es (máximo - x_min), ver arriba
		"profundidad": z_max + 1,
		"huella_relativa": huella_relativa,
	}
```

Reemplaza por:

```gdscript
	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"categoria": "residencial",  # ponytail: única categoría real declarable en esta PoC; ver Zonificacion.MARGEN_POR_CATEGORIA
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,       # x_max ya es (máximo - x_min), ver arriba
		"profundidad": z_max + 1,
		"huella_relativa": huella_relativa,
	}
```

- [ ] **Step 2: Agregar una aserción de `"categoria"` en TEST 17**

En `godot/scripts/BlueprintValidatorTest.gd`, localiza (dentro de TEST 17):

```gdscript
	assert(blueprint_casa["ancho"] == 4)
	assert(blueprint_casa["profundidad"] == 5)
```

Reemplaza por:

```gdscript
	assert(blueprint_casa["ancho"] == 4)
	assert(blueprint_casa["profundidad"] == 5)
	assert(blueprint_casa["categoria"] == "residencial")
```

- [ ] **Step 3: Ejecutar `Test.tscn` y verificar que las 21 pruebas siguen pasando**

Ejecuta `godot/scenes/Test.tscn` y confirma que las 21 pruebas existentes siguen pasando (sin cambio de conteo en este task), sin errores nuevos.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: agregar campo categoria a estructura_a_blueprint()"
```

---

### Task 4: `Zonificacion.gd` — zona de influencia reducible, con radio por categoría

**Files:**
- Modify: `godot/scripts/Zonificacion.gd`
- Modify: `godot/scripts/ZonificacionTest.gd`

**Interfaces:**
- Produces: `Zonificacion.ampliar_influencia(id: int, huella: Array, categoria: String) -> void` (firma nueva, reemplaza la de un solo argumento), `Zonificacion.retirar_contribucion(id: int) -> void`, `Zonificacion.celda_es_del_nucleo(celda: Vector2i) -> bool`. Consumidos por Task 7 (`Player.gd`).

- [ ] **Step 1: Reescribir `godot/scripts/Zonificacion.gd` completo**

Reemplaza TODO el contenido del archivo por:

```gdscript
extends Node

## Autoload "Zonificacion": estado puro y lógica de la zona de influencia y
## las zonas pintables (Núcleo A/Núcleo B) sobre el grid XZ. Sin class_name
## (colisionaría con el nombre del autoload, mismo motivo que Ciudad.gd). No
## depende de ningún nodo de escena — ver spec:
## docs/superpowers/specs/2026-09-07-zonificacion-design.md,
## docs/superpowers/specs/2026-09-11-deconstruccion-edificios-design.md
##
## Convención: Vector2i(x, z) para celdas del grid en planta — Vector2i no
## tiene componente .z, así que la coordenada mundial Z vive en el campo .y
## (misma convención que BlueprintValidator._parsear_celda).

## Margen del núcleo urbano — sin cambios, sigue siendo especial (no tiene
## "categoria", es el único ancla fija de la zona de influencia).
const MARGEN_ZONA_INFLUENCIA := 15

## Margen de ampliación de la zona de influencia por categoría de edificio
## (ver BlueprintValidator.estructura_a_blueprint(), campo "categoria") —
## residencial aporta menos alcance que investigación/industrial, y militar
## el mayor de los cuatro (después del núcleo). Categorías todavía no
## declarables en esta PoC (investigacion/industrial/militar: no existe
## ningún blueprint de esos tipos, "categoria" siempre vale "residencial"
## por ahora) quedan definidas igual, listas para cuando existan.
const MARGEN_POR_CATEGORIA := {
	"residencial": 6,
	"investigacion": 10,
	"industrial": 10,
	"militar": 12,
}
## Margen de respaldo si "categoria" no coincide con ninguna clave conocida
## — nunca debería ocurrir con blueprints reales (estructura_a_blueprint()
## siempre asigna una categoría válida), defensivo por si acaso.
const MARGEN_CATEGORIA_DEFECTO := 6

const ZONAS_PINTABLES := ["residencial_investigacion", "fabricacion_militar"]

var nucleo_declarado := false
var influencia_min := Vector2i.ZERO
var influencia_max := Vector2i.ZERO
var zonas: Dictionary = {}  # Vector2i(x,z) -> String

## Huella del núcleo urbano (fija desde declarar_nucleo(), nunca se quita —
## el núcleo no es deconstruible, ver spec de deconstrucción) y, por cada
## edificio que ha ampliado la zona desde entonces, su huella Y su margen
## (según su categoría en el momento de ampliar) — juntas son la base para
## recalcular influencia_min/influencia_max desde cero en
## _recalcular_influencia(), cada vez que se agrega (ampliar_influencia())
## o se quita (retirar_contribucion()) una.
var _huella_nucleo: Array = []
var _contribuciones: Dictionary = {}  # int (id de edificio) -> {"huella": Array, "margen": int}


## Bootstrap del núcleo urbano: se llama una sola vez, cuando se declara el
## primer edificio residencial válido (ver Player.gd::_declarar_edificio).
## Llamadas repetidas se ignoran — el núcleo urbano no se puede redeclarar.
func declarar_nucleo(huella: Array) -> void:
	if nucleo_declarado:
		return
	_huella_nucleo = huella.duplicate()
	nucleo_declarado = true
	_recalcular_influencia()

	for celda in huella:
		zonas[celda] = "residencial_investigacion"


## Registra la huella de "id" (con el margen correspondiente a "categoria")
## como contribución a la zona de influencia y recalcula influencia_min/
## influencia_max desde cero (ver _recalcular_influencia()) — reemplaza el
## crecimiento incremental por uno recalculado siempre desde la base, para
## que retirar_contribucion() pueda reducir la zona correctamente más
## adelante. No-op si el núcleo todavía no fue declarado. "id" es el mismo
## que devuelve VoxelWorld.registrar_edificio() para ese edificio;
## "categoria" es blueprint["categoria"].
func ampliar_influencia(id: int, huella: Array, categoria: String) -> void:
	if not nucleo_declarado:
		return
	var margen: int = MARGEN_POR_CATEGORIA.get(categoria, MARGEN_CATEGORIA_DEFECTO)
	_contribuciones[id] = {"huella": huella.duplicate(), "margen": margen}
	_recalcular_influencia()


## Quita la contribución de "id" (ver ampliar_influencia()) y recalcula la
## zona de influencia desde cero — puede REDUCIRLA, a diferencia de
## ampliar_influencia(). Se llama al completarse la deconstrucción total de
## un edificio (ver VoxelWorld.eliminar_edificio()/Player.gd). No-op si
## "id" no tenía ninguna contribución registrada (p. ej. el edificio nunca
## amplió la zona porque ya estaba contenida en ella).
func retirar_contribucion(id: int) -> void:
	if not _contribuciones.has(id):
		return
	_contribuciones.erase(id)
	_recalcular_influencia()


## Recalcula influencia_min/influencia_max como la unión de: la caja
## delimitadora de _huella_nucleo expandida por MARGEN_ZONA_INFLUENCIA, y
## la de cada contribución vigente expandida por SU PROPIO margen (no un
## margen único al final — cada edificio "empuja" la zona hasta su propio
## alcance, no el de otro). Misma fórmula que ya usaban declarar_nucleo()/
## ampliar_influencia() por separado, unificada en un solo lugar para que
## crecer y reducir usen exactamente el mismo cálculo.
func _recalcular_influencia() -> void:
	var min_x: int = _huella_nucleo[0].x - MARGEN_ZONA_INFLUENCIA
	var max_x: int = _huella_nucleo[0].x + MARGEN_ZONA_INFLUENCIA
	var min_z: int = _huella_nucleo[0].y - MARGEN_ZONA_INFLUENCIA
	var max_z: int = _huella_nucleo[0].y + MARGEN_ZONA_INFLUENCIA
	for celda in _huella_nucleo:
		min_x = min(min_x, celda.x - MARGEN_ZONA_INFLUENCIA)
		max_x = max(max_x, celda.x + MARGEN_ZONA_INFLUENCIA)
		min_z = min(min_z, celda.y - MARGEN_ZONA_INFLUENCIA)
		max_z = max(max_z, celda.y + MARGEN_ZONA_INFLUENCIA)
	for contribucion in _contribuciones.values():
		var margen: int = contribucion["margen"]
		for celda in contribucion["huella"]:
			min_x = min(min_x, celda.x - margen)
			max_x = max(max_x, celda.x + margen)
			min_z = min(min_z, celda.y - margen)
			max_z = max(max_z, celda.y + margen)
	influencia_min = Vector2i(min_x, min_z)
	influencia_max = Vector2i(max_x, max_z)


func dentro_de_influencia(celda: Vector2i) -> bool:
	if not nucleo_declarado:
		return false
	return (
		celda.x >= influencia_min.x and celda.x <= influencia_max.x
		and celda.y >= influencia_min.y and celda.y <= influencia_max.y
	)


## true si "celda" (X,Z) pertenece a la huella del núcleo urbano — usada
## por Player.gd para negarse a deconstruir el núcleo (exento, ver spec de
## deconstrucción). No expone _huella_nucleo directamente para no acoplar
## a los demás lectores a su representación interna.
func celda_es_del_nucleo(celda: Vector2i) -> bool:
	return _huella_nucleo.has(celda)


## Pinta el rectángulo entre las dos esquinas (inclusive), recortado a la
## zona de influencia. Devuelve cuántas celdas se pintaron realmente, para
## que quien llama (CamaraCenital.gd) pueda avisar si el rectángulo cayó
## total o parcialmente fuera de la zona de influencia.
func pintar_zona(esquina_a: Vector2i, esquina_b: Vector2i, tipo: String) -> int:
	if not ZONAS_PINTABLES.has(tipo):
		return 0

	var x_min: int = min(esquina_a.x, esquina_b.x)
	var x_max: int = max(esquina_a.x, esquina_b.x)
	var z_min: int = min(esquina_a.y, esquina_b.y)
	var z_max: int = max(esquina_a.y, esquina_b.y)

	var pintadas := 0
	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			var celda := Vector2i(x, z)
			if dentro_de_influencia(celda):
				zonas[celda] = tipo
				pintadas += 1
	return pintadas


func consultar_zona(celda: Vector2i) -> String:
	return zonas.get(celda, "periferia")
```

- [ ] **Step 2: Actualizar `ZonificacionTest.gd`**

Localiza (TEST 9 completo, hasta el final del archivo):

```gdscript
	print("\n=== TEST 9: ampliar_influencia() ===")
	var zona_sin_nucleo: Node = ZonificacionScript.new()
	zona_sin_nucleo.ampliar_influencia([Vector2i(100, 100)])
	assert(not zona_sin_nucleo.nucleo_declarado, "ampliar_influencia() no debe declarar un núcleo por sí sola")
	assert(zona_sin_nucleo.influencia_min == Vector2i.ZERO and zona_sin_nucleo.influencia_max == Vector2i.ZERO, "Sin núcleo declarado, ampliar_influencia() no debe hacer nada")

	var influencia_min_antes: Vector2i = zona.influencia_min
	zona.ampliar_influencia([Vector2i(100, 100)])
	print("Influencia tras ampliar con huella lejana: ", zona.influencia_min, " a ", zona.influencia_max)
	assert(zona.influencia_min == influencia_min_antes, "Una huella lejana solo debe crecer el máximo, no mover el mínimo")
	assert(zona.influencia_max == Vector2i(115, 115), "El máximo debe crecer para incluir la huella + el margen")

	var influencia_max_ampliada: Vector2i = zona.influencia_max
	zona.ampliar_influencia([Vector2i(0, 0)])
	assert(zona.influencia_min == influencia_min_antes and zona.influencia_max == influencia_max_ampliada, "Una huella ya contenida no debe reducir la zona de influencia")

	print("\n=== Las 9 pruebas de Zonificacion pasaron correctamente ===")
```

Reemplaza por:

```gdscript
	print("\n=== TEST 9: ampliar_influencia() con margen según categoría ===")
	var zona_sin_nucleo: Node = ZonificacionScript.new()
	zona_sin_nucleo.ampliar_influencia(1, [Vector2i(100, 100)], "militar")
	assert(not zona_sin_nucleo.nucleo_declarado, "ampliar_influencia() no debe declarar un núcleo por sí sola")
	assert(zona_sin_nucleo.influencia_min == Vector2i.ZERO and zona_sin_nucleo.influencia_max == Vector2i.ZERO, "Sin núcleo declarado, ampliar_influencia() no debe hacer nada")

	var influencia_min_antes: Vector2i = zona.influencia_min
	var influencia_max_antes: Vector2i = zona.influencia_max

	# Edificio residencial (margen 6) lejos del núcleo.
	zona.ampliar_influencia(101, [Vector2i(100, 100)], "residencial")
	print("Influencia tras ampliar con un residencial: ", zona.influencia_min, " a ", zona.influencia_max)
	assert(zona.influencia_min == influencia_min_antes, "Solo debe crecer el máximo, no mover el mínimo")
	assert(zona.influencia_max == Vector2i(106, 106), "Margen residencial (6): 100+6=106")

	# Edificio militar (margen 12), más lejos todavía — debe crecer más que el residencial.
	zona.ampliar_influencia(102, [Vector2i(200, 200)], "militar")
	print("Influencia tras ampliar con un militar: ", zona.influencia_min, " a ", zona.influencia_max)
	assert(zona.influencia_max == Vector2i(212, 212), "Margen militar (12): 200+12=212")

	# Categoría desconocida cae al margen de respaldo (6, igual que residencial).
	zona.ampliar_influencia(103, [Vector2i(300, 300)], "categoria_inexistente")
	assert(zona.influencia_max == Vector2i(306, 306), "Categoría desconocida usa MARGEN_CATEGORIA_DEFECTO")

	print("\n=== TEST 10: retirar_contribucion() reduce la zona correctamente ===")
	zona.retirar_contribucion(103)
	assert(zona.influencia_max == Vector2i(212, 212), "Al quitar la contribución más lejana, vuelve a lo que aporta el militar")
	zona.retirar_contribucion(102)
	assert(zona.influencia_max == Vector2i(106, 106), "Al quitar también el militar, vuelve a lo que aporta el residencial")
	zona.retirar_contribucion(101)
	assert(zona.influencia_max == influencia_max_antes, "Sin ninguna contribución, vuelve exactamente a la del núcleo")
	zona.retirar_contribucion(999)  # no existía, no debe fallar
	assert(zona.influencia_max == influencia_max_antes, "Retirar un id inexistente no debe hacer nada")
	print("OK: cada edificio amplía la zona según su propio margen por categoría, y retirar_contribucion() la reduce correctamente.")

	print("\n=== Las 10 pruebas de Zonificacion pasaron correctamente ===")
```

También actualiza el comentario de cabecera del archivo (línea ~5, "debe imprimir las 9 pruebas") a "las 10 pruebas".

- [ ] **Step 3: Ejecutar `ZonificacionTest.tscn` y verificar las 10 pruebas**

Ejecuta `godot/scenes/ZonificacionTest.tscn` y confirma la salida `"=== Las 10 pruebas de Zonificacion pasaron correctamente ==="` sin ningún `assert` fallido, sin errores nuevos.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/Zonificacion.gd godot/scripts/ZonificacionTest.gd
git commit -m "feat: zona de influencia reducible, con margen de ampliación según categoría de edificio"
```

---

### Task 5: `VoxelWorld.gd` + `CamaraCenital.gd` — motor de deconstrucción y aislamiento del relleno

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Produces: `VoxelWorld.edificio_a_celdas: Dictionary`, `VoxelWorld.id_de_edificio(celda) -> int`, `VoxelWorld.procesar_deconstruccion(celda) -> Dictionary`, `VoxelWorld.eliminar_edificio(id) -> Vector2i`. Consumidos por Task 7 (`Player.gd`).
- Consumes: nada de las Tasks 1-4 (independiente).
- **Nota de fusión:** este task también modifica `BlueprintValidatorTest.gd`, que la Task 3 ya modificó (TEST 17, sección distinta del archivo). Ejecuta este task DESPUÉS de la Task 3 para evitar conflictos.

- [ ] **Step 1: Registro inverso `edificio_a_celdas` en `registrar_edificio()`**

Localiza:

```gdscript
## Celda -> id de edificio al que pertenece (fantasma en curso, terminado,
## o puesto periférico). minar_bloque() consulta este registro para negarse
## a minar cualquier celda que forme parte de un edificio: un edificio se
## comporta como un objeto completo, no como un grupo de bloques sueltos
## (igual que ya hacen los árboles vía TIPOS_ARBOL/talar_bloque_de_arbol()).
## No se borra nunca al completarse una construcción fantasma (a diferencia
## de Construccion._celda_a_construccion, que sí se limpia): la inmunidad
## debe seguir vigente después de terminado el edificio.
var celda_a_edificio: Dictionary = {}  # Vector3i -> int
var _siguiente_id_edificio := 1


## Asigna un id de edificio nuevo y registra cada celda de "celdas" bajo
## ese id. Devuelve el id asignado (no se usa hoy para nada más que
## depuración/tests, pero deja la puerta abierta a operar sobre "todas las
## celdas de este edificio" en el futuro — p. ej. rotación).
func registrar_edificio(celdas: Array) -> int:
	var id := _siguiente_id_edificio
	_siguiente_id_edificio += 1
	for celda in celdas:
		celda_a_edificio[celda] = id
	return id
```

Reemplaza por:

```gdscript
## Celda -> id de edificio al que pertenece (fantasma en curso, terminado,
## o puesto periférico). minar_bloque() consulta este registro para negarse
## a minar cualquier celda que forme parte de un edificio: un edificio se
## comporta como un objeto completo, no como un grupo de bloques sueltos
## (igual que ya hacen los árboles vía TIPOS_ARBOL/talar_bloque_de_arbol()).
## No se borra nunca al completarse una construcción fantasma (a diferencia
## de Construccion._celda_a_construccion, que sí se limpia): la inmunidad
## debe seguir vigente después de terminado el edificio, hasta que se
## deconstruya por completo (ver eliminar_edificio()).
var celda_a_edificio: Dictionary = {}  # Vector3i -> int
var _siguiente_id_edificio := 1

## id de edificio -> Array[Vector3i] de sus celdas registradas (ver
## registrar_edificio()). Permite, dado un id, recuperar TODAS sus celdas
## sin recorrer celda_a_edificio entero — usado por la deconstrucción
## (procesar_deconstruccion()/eliminar_edificio()) para saber qué queda por
## revertir y qué borrar al final.
var edificio_a_celdas: Dictionary = {}  # int -> Array[Vector3i]


## Asigna un id de edificio nuevo y registra cada celda de "celdas" bajo
## ese id. Devuelve el id asignado — usado por el llamador para asociar
## este edificio con su zona de influencia (Zonificacion.ampliar_influencia())
## y, más adelante, para deconstruirlo (ver procesar_deconstruccion()).
func registrar_edificio(celdas: Array) -> int:
	var id := _siguiente_id_edificio
	_siguiente_id_edificio += 1
	for celda in celdas:
		celda_a_edificio[celda] = id
	edificio_a_celdas[id] = celdas.duplicate()
	return id


## Consulta puntual de celda_a_edificio con un valor de "no pertenece"
## explícito (-1) en vez de acceder al Dictionary directamente.
func id_de_edificio(celda: Vector3i) -> int:
	return celda_a_edificio.get(celda, -1)
```

- [ ] **Step 2: Aislar el relleno en `iniciar_construccion_fantasma()`**

Localiza:

```gdscript
## Coloca el bloque placeholder "fantasma" en cada celda de "orden" (en el
## mundo real, con colisión) y registra la construcción en Construccion.gd.
## "tipos" mapea cada celda de "orden" a su tipo real de destino, "metadata"
## se guarda intacta para cuando la construcción se complete (ver
## Construccion.iniciar()). No marca colocado_por_jugador todavía: estas
## celdas no son estructura real hasta que se conviertan (ver
## surtir_construccion()).
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	registrar_edificio(orden)
	return Construccion.iniciar(orden, tipos, metadata)
```

Reemplaza por:

```gdscript
## Coloca el bloque placeholder "fantasma" en cada celda de "orden" (en el
## mundo real, con colisión) y registra la construcción en Construccion.gd.
## "tipos" mapea cada celda de "orden" a su tipo real de destino, "metadata"
## se guarda intacta para cuando la construcción se complete (ver
## Construccion.iniciar()). No marca colocado_por_jugador todavía: estas
## celdas no son estructura real hasta que se conviertan (ver
## surtir_construccion()).
## "celdas_estructurales" es el subconjunto de "orden" que representa al
## edificio en sí (paredes, puertas, ventanas, piso, mobiliario) — NUNCA
## incluye el relleno de nivelación. Solo esas celdas se registran como
## inmunes al minado / parte de la deconstrucción (ver registrar_edificio());
## el relleno de tierra queda fuera desde el primer instante, así que se
## comporta como terreno normal (minable, no participa en deconstruir el
## edificio) incluso mientras el edificio sigue a medio construir — ver
## docs/superpowers/specs/2026-09-11-deconstruccion-edificios-design.md.
## Devuelve el id de EDIFICIO (el de registrar_edificio(), no el de
## Construccion.iniciar() — ningún llamador usaba ese valor de retorno
## hasta ahora, así que este cambio es seguro) para que el llamador
## (CamaraCenital._procesar_clic_blueprint()) lo guarde en "metadata" y
## Player._completar_construccion() pueda usarlo directamente al ampliar
## la zona de influencia, sin tener que volver a buscarlo por celda.
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, celdas_estructurales: Array, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	var id_edificio: int = registrar_edificio(celdas_estructurales)
	Construccion.iniciar(orden, tipos, metadata)
	return id_edificio
```

- [ ] **Step 3: Agregar el orden de deconstrucción y `_ordenar_celdas_deconstruccion()`**

Localiza (justo antes de `iniciar_construccion_fantasma()`, después de `eliminar_follaje()`):

```gdscript
func eliminar_follaje(celda: Vector3i) -> void:
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	var id: int = arboles.obtener_arbol_de(celda)
	if id != -1:
		arboles.eliminar_celda(id, celda)
```

Agrega inmediatamente después (antes del comentario de `iniciar_construccion_fantasma()`):

```gdscript


## Grupos de reversión, en el orden en que se deconstruye — inverso al de
## construcción (ver CamaraCenital.ORDEN_GRUPOS_CONSTRUCCION: relleno de
## tierra -> piso -> paredes/puertas/ventanas -> mobiliario). Se duplica
## deliberadamente en vez de compartirse con CamaraCenital.gd: mismo
## criterio de capas que ya usa este archivo (VoxelWorld.gd no depende de
## CamaraCenital.gd). "tierra" solo aparece aquí por completitud — en la
## práctica nunca llega a _ordenar_celdas_deconstruccion() porque el
## relleno nunca se registra como parte del edificio (ver
## iniciar_construccion_fantasma()).
const ORDEN_GRUPOS_DECONSTRUCCION := [
	["cama_cabecera", "cama_pies", "baul"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["piso"],
	["tierra"],
]


## Agrupa y ordena "celdas_mundo" (Vector3i real -> tipo) según
## ORDEN_GRUPOS_DECONSTRUCCION, y dentro de cada grupo por (y, x, z) —
## mismo patrón exacto que CamaraCenital._ordenar_celdas_construccion(),
## con el orden de grupos invertido.
func _ordenar_celdas_deconstruccion(celdas_mundo: Dictionary) -> Array:
	var orden: Array[Vector3i] = []
	for grupo in ORDEN_GRUPOS_DECONSTRUCCION:
		var celdas_grupo: Array[Vector3i] = []
		for celda in celdas_mundo:
			if grupo.has(celdas_mundo[celda]):
				celdas_grupo.append(celda)
		celdas_grupo.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.x != b.x:
				return a.x < b.x
			return a.z < b.z
		)
		orden.append_array(celdas_grupo)
	return orden
```

- [ ] **Step 4: Agregar `procesar_deconstruccion()`, `_revertir_celda()` y `eliminar_edificio()`**

Inmediatamente después de `_ordenar_celdas_deconstruccion()` (antes de `iniciar_construccion_fantasma()`), agrega:

```gdscript


## Procesa un intento de deconstrucción apuntando a "celda". Devuelve {} si
## "celda" no pertenece a ningún edificio registrado. Si pertenece:
##
## - Si ya hay una cola de reversión activa que incluye "celda" (o
##   cualquier otra celda del mismo edificio — Construccion.gd, mismo
##   patrón "avanza siempre la primera pendiente" que surtir_construccion(),
##   en reversa), la avanza: revierte la siguiente celda real pendiente a
##   "fantasma".
## - Si no hay cola activa: calcula las celdas REALES actuales del edificio
##   (ignora las que ya son "fantasma" — un edificio a medio construir
##   simplemente no las incluye, no hace falta "revertirlas"). Si no queda
##   ninguna celda real, el edificio ya está listo para remoción final (ver
##   eliminar_edificio()) — devuelve eso sin iniciar nada. Si quedan celdas
##   reales, las ordena con _ordenar_celdas_deconstruccion() y arranca la
##   cola con Construccion.iniciar(), revirtiendo también la PRIMERA celda
##   en la misma llamada (a diferencia de iniciar_construccion_fantasma(),
##   que solo coloca los fantasmas sin convertir nada todavía, aquí no
##   hace falta un paso de "colocación" previo — el edificio ya existe).
##
## Devuelve {"id": int, "completa_reversion": bool,
## "lista_para_remocion": bool, "total_camas": int} — "total_camas" es el
## número de "cama_cabecera" que tenía el edificio en el momento de esta
## llamada, PERO SOLO tiene sentido la primera vez que se llama para un
## edificio (cuando arranca la cola); en cualquier otra llamada vale 0 (el
## llamador ya lo usó y no debe volver a aplicarlo). "lista_para_remocion"
## es true tanto si la reversión se acaba de completar en esta MISMA
## llamada como si el edificio ya estaba 100% fantasma antes de llamar.
func procesar_deconstruccion(celda: Vector3i) -> Dictionary:
	var id: int = id_de_edificio(celda)
	if id == -1:
		return {}

	var id_cola: int = Construccion.construccion_de(celda)
	if id_cola != -1:
		var resultado: Dictionary = Construccion.avanzar(id_cola)
		if resultado.is_empty():
			return {}
		_revertir_celda(resultado["celda"])
		return {
			"id": id,
			"completa_reversion": resultado["completa"],
			"lista_para_remocion": resultado["completa"],
			"total_camas": 0,
		}

	var celdas_reales: Dictionary = {}  # Vector3i -> tipo
	var total_camas := 0
	for c in edificio_a_celdas[id]:
		var tipo: String = obtener_tipo(c)
		if tipo == "fantasma":
			continue
		celdas_reales[c] = tipo
		if tipo == "cama_cabecera":
			total_camas += 1

	if celdas_reales.is_empty():
		return {"id": id, "completa_reversion": true, "lista_para_remocion": true, "total_camas": 0}

	var orden: Array = _ordenar_celdas_deconstruccion(celdas_reales)
	var tipos: Dictionary = {}
	for c in orden:
		tipos[c] = "fantasma"
	Construccion.iniciar(orden, tipos)

	var resultado: Dictionary = Construccion.avanzar(Construccion.construccion_de(celda))
	_revertir_celda(resultado["celda"])
	return {
		"id": id,
		"completa_reversion": resultado["completa"],
		"lista_para_remocion": resultado["completa"],
		"total_camas": total_camas,
	}


## Convierte "celda" (una celda real) de vuelta a "fantasma" — no marca
## colocado_por_jugador (igual que iniciar_construccion_fantasma()) y
## limpia cualquier entrada previa de esa celda en colocado_por_jugador
## (ya no es estructura real). No toca "pareja": una celda revertida sigue
## inmune al minado (celda_a_edificio no se borra hasta eliminar_edificio()),
## así que minar_bloque() nunca llega a consultar "pareja" para ella
## mientras dure la deconstrucción.
func _revertir_celda(celda: Vector3i) -> void:
	set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
	colocado_por_jugador.erase(celda)
	colocar_bloque(celda, "fantasma")


## Elimina por completo un edificio ya reducido a fantasma vacío (ver
## procesar_deconstruccion(), "lista_para_remocion" == true): borra todas
## sus celdas del GridMap y limpia celda_a_edificio/edificio_a_celdas — deja
## de ser inmune al minado porque deja de existir. Devuelve la esquina
## (mínimo x, mínimo z entre sus celdas) para que el llamador pueda avisar
## a Recoleccion (quitar_puesto()) — esta función no conoce Recoleccion ni
## Zonificacion, solo el mundo físico. No-op (devuelve Vector2i.ZERO) si
## "id" no existe.
func eliminar_edificio(id: int) -> Vector2i:
	if not edificio_a_celdas.has(id):
		return Vector2i.ZERO
	var celdas: Array = edificio_a_celdas[id]
	var esquina := Vector2i(celdas[0].x, celdas[0].z)
	for celda in celdas:
		esquina.x = min(esquina.x, celda.x)
		esquina.y = min(esquina.y, celda.z)
		set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
		celda_a_edificio.erase(celda)
	edificio_a_celdas.erase(id)
	return esquina
```

- [ ] **Step 5: Actualizar el llamador en `CamaraCenital.gd`**

Localiza:

```gdscript
	var metadata := {
		"blueprint": _blueprint_activo,
		"huella_xz": huella_xz,
		"esquina": esquina,
		"ancho": ancho,
		"profundidad": alto,
	}
	mundo.iniciar_construccion_fantasma(orden, tipos, metadata)
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")
```

Reemplaza por:

```gdscript
	var metadata := {
		"blueprint": _blueprint_activo,
		"huella_xz": huella_xz,
		"esquina": esquina,
		"ancho": ancho,
		"profundidad": alto,
	}
	var id_edificio: int = mundo.iniciar_construccion_fantasma(orden, tipos, celdas_mundo.keys(), metadata)
	metadata["id_edificio"] = id_edificio
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")
```

(`metadata` es un `Dictionary`, pasado por referencia a `Construccion.iniciar()` — agregarle `"id_edificio"` DESPUÉS de esa llamada sigue estando disponible cuando `Construccion.avanzar()` lo devuelva más tarde en `surtir_construccion()`/`Player._completar_construccion()`, porque es el mismo objeto Dictionary en memoria, no una copia.)

- [ ] **Step 6: Actualizar los 2 llamados existentes a `iniciar_construccion_fantasma()` en `BlueprintValidatorTest.gd` (TEST 18 y TEST 20)**

Localiza (TEST 18):

```gdscript
	mundo.colocar_bloque(Vector3i(OX8, 2, OX8), "puerta_superior")  # ya real, no fantasma: completa el par de la puerta
	mundo.iniciar_construccion_fantasma(orden_18, tipos_18)
```

Reemplaza por:

```gdscript
	mundo.colocar_bloque(Vector3i(OX8, 2, OX8), "puerta_superior")  # ya real, no fantasma: completa el par de la puerta
	mundo.iniciar_construccion_fantasma(orden_18, tipos_18, orden_18)
```

Localiza (TEST 20):

```gdscript
	var celda_fantasma := Vector3i(802, 50, 800)
	var orden_fantasma: Array[Vector3i] = [celda_fantasma]
	var tipos_fantasma := {celda_fantasma: "pared"}
	mundo.iniciar_construccion_fantasma(orden_fantasma, tipos_fantasma)
```

Reemplaza por:

```gdscript
	var celda_fantasma := Vector3i(802, 50, 800)
	var orden_fantasma: Array[Vector3i] = [celda_fantasma]
	var tipos_fantasma := {celda_fantasma: "pared"}
	mundo.iniciar_construccion_fantasma(orden_fantasma, tipos_fantasma, orden_fantasma)
```

(En ambos casos, pasar el mismo array como `celdas_estructurales` preserva exactamente el comportamiento e inmunidad que estos tests ya verificaban — ninguno de los dos ejercita relleno.)

- [ ] **Step 7: Agregar TEST 22, TEST 23 y TEST 24 en `BlueprintValidatorTest.gd`**

Localiza el final del archivo:

```gdscript
	print("OK: estructura_a_blueprint() reconoce la huella en L y validar_blueprint() la acepta.")

	print("\n=== Las 21 pruebas de BlueprintValidator pasaron correctamente ===")
```

Reemplaza por:

```gdscript
	print("OK: estructura_a_blueprint() reconoce la huella en L y validar_blueprint() la acepta.")

	print("\n=== TEST 22: procesar_deconstruccion()/eliminar_edificio() revierten en orden inverso ===")
	const OX10 := 900
	var celda_piso_22 := Vector3i(OX10, 0, OX10)
	var celda_pared_22 := Vector3i(OX10, 1, OX10)
	var celda_cabecera_22 := Vector3i(OX10 + 1, 1, OX10)
	var celda_pies_22 := Vector3i(OX10 + 2, 1, OX10)
	var celda_baul_22 := Vector3i(OX10 + 3, 1, OX10)
	mundo.colocar_bloque(celda_piso_22, "piso", true)
	mundo.colocar_bloque(celda_pared_22, "pared", true)
	mundo.colocar_bloque(celda_cabecera_22, "cama_cabecera", true)
	mundo.colocar_bloque(celda_pies_22, "cama_pies", true)
	mundo.colocar_bloque(celda_baul_22, "baul", true)
	var id_22: int = mundo.registrar_edificio([celda_piso_22, celda_pared_22, celda_cabecera_22, celda_pies_22, celda_baul_22])

	# Primer intento: arranca la cola y revierte la PRIMERA celda del orden
	# inverso (mobiliario primero, ordenado por x: cabecera antes que pies
	# antes que baúl) — aunque el jugador haya apuntado a la pared.
	var r1_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(r1_22["id"] == id_22)
	assert(r1_22["total_camas"] == 1, "Debe contar 1 cama_cabecera al iniciar")
	assert(mundo.obtener_tipo(celda_cabecera_22) == "fantasma")
	assert(mundo.obtener_tipo(celda_pies_22) == "cama_pies", "Todavía no le toca")
	assert(not r1_22["completa_reversion"])

	var r2_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_pies_22) == "fantasma")
	assert(r2_22["total_camas"] == 0, "Solo cuenta la primera vez que arranca la cola")

	var r3_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_baul_22) == "fantasma")

	var r4_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_pared_22) == "fantasma", "Estructura después del mobiliario")
	assert(not r4_22["completa_reversion"])

	var r5_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_piso_22) == "fantasma", "Piso al final")
	assert(r5_22["completa_reversion"] and r5_22["lista_para_remocion"])

	var r6_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(r6_22["lista_para_remocion"])

	var esquina_22: Vector2i = mundo.eliminar_edificio(id_22)
	assert(esquina_22 == Vector2i(OX10, OX10))
	for c_22 in [celda_piso_22, celda_pared_22, celda_cabecera_22, celda_pies_22, celda_baul_22]:
		assert(mundo.obtener_tipo(c_22) == "")
		assert(mundo.id_de_edificio(c_22) == -1)
	print("OK: procesar_deconstruccion() revierte en orden inverso (mobiliario -> estructura -> piso), cuenta camas solo al iniciar, y eliminar_edificio() borra todo.")

	print("\n=== TEST 23: deconstruir un edificio a medio construir salta las celdas ya fantasma ===")
	const OX11 := 950
	var celda_piso_23 := Vector3i(OX11, 0, OX11)
	var celda_pared_real_23 := Vector3i(OX11, 1, OX11)
	var celda_pared_fantasma_23 := Vector3i(OX11 + 1, 1, OX11)
	mundo.colocar_bloque(celda_piso_23, "piso", true)
	mundo.colocar_bloque(celda_pared_real_23, "pared", true)
	mundo.colocar_bloque(celda_pared_fantasma_23, "fantasma")  # todavía sin surtir
	mundo.registrar_edificio([celda_piso_23, celda_pared_real_23, celda_pared_fantasma_23])

	var r1_23: Dictionary = mundo.procesar_deconstruccion(celda_pared_real_23)
	assert(mundo.obtener_tipo(celda_pared_real_23) == "fantasma", "La única pared real se revierte")
	assert(mundo.obtener_tipo(celda_pared_fantasma_23) == "fantasma", "Ya lo era, sin cambios")
	assert(not r1_23["completa_reversion"])

	var r2_23: Dictionary = mundo.procesar_deconstruccion(celda_pared_real_23)
	assert(mundo.obtener_tipo(celda_piso_23) == "fantasma")
	assert(r2_23["completa_reversion"] and r2_23["lista_para_remocion"])
	print("OK: las celdas ya fantasma de un edificio a medio construir no necesitan revertirse.")

	print("\n=== TEST 24: iniciar_construccion_fantasma() no registra el relleno como parte del edificio ===")
	const OX12 := 970
	var celda_relleno_24 := Vector3i(OX12, 1, OX12)
	var celda_estructural_24 := Vector3i(OX12 + 1, 1, OX12)
	var orden_24: Array[Vector3i] = [celda_relleno_24, celda_estructural_24]
	var tipos_24 := {celda_relleno_24: "tierra", celda_estructural_24: "pared"}
	mundo.iniciar_construccion_fantasma(orden_24, tipos_24, [celda_estructural_24])
	assert(mundo.id_de_edificio(celda_relleno_24) == -1, "El relleno nunca se registra, aunque esté en 'orden'")
	assert(mundo.id_de_edificio(celda_estructural_24) != -1, "La celda estructural sí se registra")
	var mineo_relleno_24: bool = mundo.minar_bloque(celda_relleno_24)
	assert(mineo_relleno_24, "El relleno, aunque siga siendo fantasma, es minable de inmediato (no es inmune)")
	assert(mundo.obtener_tipo(celda_relleno_24) == "", "Se minó de verdad")
	var mineo_estructural_24: bool = mundo.minar_bloque(celda_estructural_24)
	assert(not mineo_estructural_24, "La celda estructural sigue inmune")
	print("OK: el relleno de nivelación nunca queda registrado como parte del edificio, aunque comparta 'orden' con las celdas estructurales.")

	print("\n=== Las 25 pruebas de BlueprintValidator pasaron correctamente ===")
```

También actualiza el comentario de cabecera del archivo ("debe imprimir los 21 tests") a "los 25 tests", y agrega una línea breve a la lista de qué prueba cada test (22: deconstrucción en orden inverso; 23: edificio a medio construir; 24: relleno aislado).

- [ ] **Step 8: Ejecutar `Test.tscn` y `Main.tscn`**

Ejecuta `godot/scenes/Test.tscn` y confirma la salida `"=== Las 25 pruebas de BlueprintValidator pasaron correctamente ==="` sin ningún `assert` fallido. Ejecuta `godot/scenes/Main.tscn` y confirma que no hay errores nuevos (la firma de `iniciar_construccion_fantasma()` cambió, así que confirma que el único llamador de producción, `CamaraCenital._procesar_clic_blueprint()`, sigue compilando y ejecutándose sin error de argumentos).

- [ ] **Step 9: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/CamaraCenital.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: motor de deconstrucción en VoxelWorld y aislamiento del relleno de nivelación"
```

---

### Task 6: `HUD.gd` + `Main.tscn` — aviso visual del modo deconstrucción

**Files:**
- Modify: `godot/scenes/Main.tscn`
- Modify: `godot/scripts/HUD.gd`

**Interfaces:**
- Produces: `HUD.mostrar_modo_deconstruccion() -> void`, `HUD.ocultar_modo_deconstruccion() -> void`. Consumidos por Task 7 (`Player.gd`).
- Consumes: nada de las Tasks 1-5 (independiente).

- [ ] **Step 1: Agregar el nodo `Label` a `Main.tscn`**

En `godot/scenes/Main.tscn`, localiza el bloque de `CazaFicha` (el último nodo bajo `HUDLayer`):

```
[node name="CazaFicha" type="VBoxContainer" parent="HUDLayer"]
visible = false
offset_left = 12.0
offset_top = 160.0
offset_right = 320.0
offset_bottom = 280.0

[node name="CostoLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2

[node name="PersonalLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2

[node name="AlmacenamientoLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2

[node name="TasasLabel" type="Label" parent="HUDLayer/CazaFicha"]
layout_mode = 2
autowrap_mode = 2
```

Agrega inmediatamente después (al final del archivo, todavía bajo `HUDLayer`):

```
[node name="ModoDeconstruccionLabel" type="Label" parent="HUDLayer"]
visible = false
offset_left = 12.0
offset_top = 300.0
offset_right = 420.0
offset_bottom = 330.0
text = "Modo deconstrucción activo (G para cancelar)"
```

Si el editor de Godot no está disponible para verificar la escena, usa `mcp__godot__add_node` (parent: `HUDLayer`, type: `Label`, name: `ModoDeconstruccionLabel`) seguido de `mcp__godot__save_scene` en vez de editar el `.tscn` a mano — cualquiera de los dos métodos es válido, el resultado debe ser el mismo nodo con las mismas propiedades.

- [ ] **Step 2: Agregar la referencia y las funciones en `HUD.gd`**

Localiza:

```gdscript
@onready var caza_ficha: VBoxContainer = $CazaFicha
@onready var caza_costo_label: Label = $CazaFicha/CostoLabel
@onready var caza_personal_label: Label = $CazaFicha/PersonalLabel
@onready var caza_almacenamiento_label: Label = $CazaFicha/AlmacenamientoLabel
@onready var caza_tasas_label: Label = $CazaFicha/TasasLabel
```

Agrega inmediatamente después:

```gdscript

@onready var modo_deconstruccion_label: Label = $ModoDeconstruccionLabel
```

Localiza el final del archivo:

```gdscript
func ocultar_ficha_caza() -> void:
	caza_ficha.visible = false
```

Agrega inmediatamente después:

```gdscript


## Muestra/oculta el aviso de que el modo deconstrucción está activo (ver
## Player.gd::_alternar_modo_deconstruccion(), tecla G).
func mostrar_modo_deconstruccion() -> void:
	modo_deconstruccion_label.visible = true


func ocultar_modo_deconstruccion() -> void:
	modo_deconstruccion_label.visible = false
```

- [ ] **Step 3: Ejecutar `Main.tscn` y verificar que no hay errores nuevos**

Ejecuta `godot/scenes/Main.tscn` y confirma que no hay errores de parseo (el nuevo nodo/referencia debe cargar sin problemas) más allá de las advertencias conocidas.

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/Main.tscn godot/scripts/HUD.gd
git commit -m "feat: aviso en el HUD para el modo deconstrucción"
```

---

### Task 7: `Player.gd` — tecla G, modo deconstrucción, y el ciclo completo de interacción

**Files:**
- Modify: `godot/scripts/Player.gd`

**Interfaces:**
- Consumes: `Ciudad.retirar_edificio_residencial()` (Task 1), `Recoleccion.quitar_puesto()` (Task 2), `blueprint["categoria"]` (Task 3), `Zonificacion.ampliar_influencia(id, huella, categoria)`/`retirar_contribucion(id)`/`celda_es_del_nucleo(celda)` (Task 4), `VoxelWorld.procesar_deconstruccion()`/`eliminar_edificio()`/`registrar_edificio()` (ya existente, Task 5), `HUD.mostrar_modo_deconstruccion()`/`ocultar_modo_deconstruccion()` (Task 6).

Este task depende de que las Tasks 1-6 ya estén completas.

- [ ] **Step 1: Agregar estado y referencia al HUD**

Localiza:

```gdscript
var mundo: Node  # asignada por Main.gd al iniciar la escena

var _minando := false
var _colocando := false
var _temporizador_accion := 0.0
```

Reemplaza por:

```gdscript
var mundo: Node  # asignada por Main.gd al iniciar la escena
@onready var hud: CanvasLayer = get_node("../HUDLayer")

var _minando := false
var _colocando := false
var _temporizador_accion := 0.0

var modo_deconstruccion := false
var _id_listo_para_remocion := -1
var _ticks_listo_para_remocion := 0

## Cuántos "ticks" de acción repetida (INTERVALO_ACCION_REPETIDA, 0.2s)
## seguidos apuntando al MISMO edificio ya reducido a fantasma vacío hacen
## falta para eliminarlo del todo — demora deliberada (~1s) para evitar
## borrados accidentales al mantener el click presionado.
const TICKS_REMOCION_FINAL := 5
```

- [ ] **Step 2: Tecla `G` en `_input()`**

Localiza:

```gdscript
		if tecla.pressed and tecla.keycode == KEY_B:
			_declarar_edificio()
		if tecla.pressed and tecla.keycode == KEY_K:
			_morir_jugador()
```

Reemplaza por:

```gdscript
		if tecla.pressed and tecla.keycode == KEY_B:
			_declarar_edificio()
		if tecla.pressed and tecla.keycode == KEY_G:
			_alternar_modo_deconstruccion()
		if tecla.pressed and tecla.keycode == KEY_K:
			_morir_jugador()
```

- [ ] **Step 3: `_alternar_modo_deconstruccion()`**

Localiza:

```gdscript
func _minar() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	if mundo.TIPOS_ARBOL.has(mundo.obtener_tipo(celda)):
		mundo.talar_bloque_de_arbol(celda, DANO_TALA)
	else:
		mundo.minar_bloque(celda)
```

Reemplaza por:

```gdscript
## Activa/desactiva el modo deconstrucción — muestra/oculta el aviso en el
## HUD. Al desactivarse, también se olvida cualquier progreso de "sostener
## para remoción final" (ver _procesar_deconstruccion()) — si el jugador
## sale del modo a medio sostener el click, no debe contar para la próxima
## vez que lo reactive.
func _alternar_modo_deconstruccion() -> void:
	modo_deconstruccion = not modo_deconstruccion
	if modo_deconstruccion:
		hud.mostrar_modo_deconstruccion()
	else:
		hud.ocultar_modo_deconstruccion()
	_id_listo_para_remocion = -1
	_ticks_listo_para_remocion = 0


func _minar() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	if modo_deconstruccion:
		_procesar_deconstruccion(celda)
		return
	if mundo.TIPOS_ARBOL.has(mundo.obtener_tipo(celda)):
		mundo.talar_bloque_de_arbol(celda, DANO_TALA)
	else:
		mundo.minar_bloque(celda)


## Se llama en cada click/repetición de _minar() mientras modo_deconstruccion
## está activo. Delega toda la lógica de "qué revertir" en
## VoxelWorld.procesar_deconstruccion() — aquí solo se maneja lo que le
## corresponde al jugador/Ciudad/Zonificacion/Recoleccion: negarse sobre el
## núcleo urbano (exento), retirar camas la primera vez, y contar
## TICKS_REMOCION_FINAL intentos consecutivos sobre el MISMO edificio ya
## listo para remoción antes de eliminarlo del todo.
func _procesar_deconstruccion(celda: Vector3i) -> void:
	if Zonificacion.celda_es_del_nucleo(Vector2i(celda.x, celda.z)):
		print("El núcleo urbano no se puede deconstruir.")
		return

	var resultado: Dictionary = mundo.procesar_deconstruccion(celda)
	if resultado.is_empty():
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0
		return

	if resultado["total_camas"] > 0:
		Ciudad.retirar_edificio_residencial(resultado["total_camas"])
		print("Deconstrucción iniciada: ", resultado["total_camas"], " cama(s) retiradas de Ciudad.")

	if not resultado["lista_para_remocion"]:
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0
		return

	var id: int = resultado["id"]
	if _id_listo_para_remocion == id:
		_ticks_listo_para_remocion += 1
	else:
		_id_listo_para_remocion = id
		_ticks_listo_para_remocion = 1

	if _ticks_listo_para_remocion >= TICKS_REMOCION_FINAL:
		var esquina: Vector2i = mundo.eliminar_edificio(id)
		Zonificacion.retirar_contribucion(id)
		Recoleccion.quitar_puesto(esquina)
		print("Edificio deconstruido por completo.")
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0
```

- [ ] **Step 4: Pasar el id y la categoría a `Zonificacion.ampliar_influencia()` en `_declarar_edificio()`**

Localiza (bloque completo, desde `if resultado["valido"]:` hasta el final de la función):

```gdscript
	if resultado["valido"]:
		Blueprints.guardar(blueprint)
		mundo.registrar_edificio(celdas.keys())
		var total_camas := 0
		for piso in blueprint["pisos"]:
			total_camas += (piso.get("camas", []) as Array).size()
		Ciudad.registrar_edificio_residencial(total_camas)
		print("Camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

		if not Zonificacion.nucleo_declarado:
			Zonificacion.declarar_nucleo(huella)
			print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
		else:
			Zonificacion.ampliar_influencia(huella)
			print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
```

Reemplaza por (un solo cambio: `mundo.registrar_edificio(...)` guarda su id en una variable, reutilizada en la rama `else` para pasarla junto con la categoría a `ampliar_influencia()` — el núcleo no necesita ese id para nada más, ya que nunca se deconstruye):

```gdscript
	if resultado["valido"]:
		Blueprints.guardar(blueprint)
		var id_edificio: int = mundo.registrar_edificio(celdas.keys())
		var total_camas := 0
		for piso in blueprint["pisos"]:
			total_camas += (piso.get("camas", []) as Array).size()
		Ciudad.registrar_edificio_residencial(total_camas)
		print("Camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

		if not Zonificacion.nucleo_declarado:
			Zonificacion.declarar_nucleo(huella)
			print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
		else:
			Zonificacion.ampliar_influencia(id_edificio, huella, blueprint["categoria"])
			print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
```

- [ ] **Step 5: Pasar el id y la categoría a `Zonificacion.ampliar_influencia()` en `_completar_construccion()`**

Localiza:

```gdscript
func _completar_construccion(metadata: Dictionary) -> void:
	if metadata.is_empty():
		return
	var blueprint: Dictionary = metadata["blueprint"]
	var total_camas := 0
	for piso in blueprint["pisos"]:
		total_camas += (piso.get("camas", []) as Array).size()
	Ciudad.registrar_edificio_residencial(total_camas)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
	else:
		Zonificacion.ampliar_influencia(metadata["huella_xz"])
		print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)

	Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])
```

Reemplaza por:

```gdscript
func _completar_construccion(metadata: Dictionary) -> void:
	if metadata.is_empty():
		return
	var blueprint: Dictionary = metadata["blueprint"]
	var total_camas := 0
	for piso in blueprint["pisos"]:
		total_camas += (piso.get("camas", []) as Array).size()
	Ciudad.registrar_edificio_residencial(total_camas)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
	else:
		Zonificacion.ampliar_influencia(metadata["id_edificio"], metadata["huella_xz"], blueprint["categoria"])
		print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)

	Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])
```

`metadata["id_edificio"]` ya viene poblado desde `CamaraCenital._procesar_clic_blueprint()` (Task 5, Step 5) — es el mismo Dictionary de principio a fin (por referencia), así que llega intacto hasta aquí sin que este task tenga que buscarlo de nuevo.

- [ ] **Step 6: Ejecutar `Test.tscn`, `NiveladorTerrenoTest.tscn`, `CiudadTest.tscn`, `RecoleccionTest.tscn`, `ZonificacionTest.tscn` y `Main.tscn`**

Confirma que las pruebas de todos los archivos anteriores (25 + 8 + 8 + 10 + 10) siguen pasando sin cambios (este task no las modifica), y que `Main.tscn` no muestra errores nuevos más allá de las advertencias conocidas.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Player.gd
git commit -m "feat: tecla G para deconstruir edificios, con exención del núcleo y feedback en el HUD"
```
