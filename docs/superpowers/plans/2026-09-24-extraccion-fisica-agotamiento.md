# Extracción física y agotamiento (PoC 5, sub-proyecto 2B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que los puestos de recolección consuman de verdad el mundo (bloques de mina, árboles) y recalculen su tasa según lo que queda en su área, y que el avatar mine, tale y recolecte frutos con tiempo y un indicador de avance, sobre un inventario limitado que arranca la partida.

**Architecture:** `Recoleccion.gd` gana la tabla de rendimiento, la selección de bloques de mina y las funciones de tasas (movidas desde `CamaraCenital`). `Economia.gd` guarda por puesto un "entorno" y un bloque en curso por recurso, descuenta cada unidad producida del mundo (`VoxelWorld`, inyectado) y recalcula tasas cada 6 h. `Ciudad.almacen` es el inventario del avatar: topes iniciales bajos, ampliación al declarar el núcleo y bono por baúles. `Player.gd` pasa a minar/talar/recolectar por tiempo con un `ProgresoAccion` puro y una barra en el HUD.

**Tech Stack:** Godot 4.7 (GDScript), pruebas como escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-24-extraccion-fisica-agotamiento-design.md`.

## Global Constraints

- GDScript con **tabulaciones**. Documentación, comentarios, mensajes del juego y pruebas en **español**.
- No editar ni agregar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python. No hacer `git add` de los `*.gd.uid` sueltos. En cada commit, `git add` solo los archivos del paso.
- **No tocar `docs/Pendientes y próximos pasos.md`** salvo en la Tarea 12 (tiene cambios sin commitear del usuario: hacer `git add` solo si el diff previo del usuario ya está commiteado, o dejarlo sin commitear y avisar).
- No mezclar PoC ni reformatear archivos ajenos al objetivo. Reutilizar código existente; sin abstracciones especulativas.
- Verificación (CLAUDE.md): `godot/scenes/Test.tscn` con Godot 4.7 más las escenas `*Test.tscn` afectadas. Solo se ejecutan las escenas relacionadas con el cambio.
- **Rendimiento por bloque** (unidades): tierra 1; piedra, hierro, cobre, carbón, tierras raras y tronco 10.
- **Mina:** solo extrae bloques con profundidad ≥ `GROSOR_TIERRA - 2` (= 2) bajo la superficie **natural** de su columna; bloques puestos por el jugador, de un edificio, árboles y agua nunca cuentan.
- **Recálculo de tasas:** cada `TICKS_RECALCULO := 6` horas de juego (1 tick = 1 hora).
- **Inventario:** base 500 por recurso y 5000 de comida; al declarar el núcleo ×2; cada baúl de un edificio residencial **posterior al núcleo** suma +100 (+400 comida). El núcleo no suma camas ni baúles. `COMIDA_INICIAL := 1500`.
- **Placeholders de balance** (constantes únicas, ajustables): tiempos de minado por tipo, `TIEMPO_TALA_POR_SALUD := 1.0`, `COMIDA_POR_RECOLECCION := 60.0`, `HORAS_REBROTE_FRUTOS := 24`, `TIEMPO_RECOLECCION_FRUTOS := 2.0`, multiplicador de herramienta 1.
- Fuera de alcance: bomba extractora y petróleo, cobro de construcción, herramientas, caza y pesca manual, indicador de avance para la **construcción** por fantasmas.
- Commits terminan con:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  ```

## Review Focus

- Una mina cuya área se agotó por completo: producción 0, sin error, y `recalcular_tasas` deja `{}` (Tarea 5).
- Un puesto con **0 árboles** al colocarse (`arboles_ref == 0`): factor 1, sin división por cero (Tarea 3).
- El avatar tala el árbol o mina el bloque que un puesto tenía "en curso": el puesto descarta el bloque en curso y no produce gratis (Tarea 4).
- Deconstruir un edificio con baúles baja el límite por debajo del stock: el stock se conserva y no entra nada nuevo, sin cantidades negativas (Tarea 7).
- Mantener el clic mirando agua o aire, o soltarlo/cambiar de bloque a medias: sin rendimiento, sin error, avance reiniciado (Tareas 9 y 10).

## Cómo ejecutar una escena de pruebas (headless)

Desde la raíz del repo, en bash:

```bash
GD="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
```

Pasa si imprime una única línea `=== Las N pruebas de ... pasaron correctamente ===` y ninguna con `Assertion`, `SCRIPT ERROR` o `Parse Error`. (El ruido `ObjectDB instances were leaked` al salir es conocido.)

En cada archivo de pruebas existente, las pruebas nuevas se insertan **justo antes** de la línea final `print("\n=== Las N pruebas ... pasaron correctamente ===")`, y se sube `N`.

## Estructura de archivos

| Archivo | Responsabilidad en 2B |
|---|---|
| `godot/scripts/GeneradorArbol.gd` | Consultas del registro de árboles (salud, radio, más cercano). |
| `godot/scripts/Recoleccion.gd` | Rendimiento, tiempos, selección de bloque de mina, entorno y tasas de un puesto. |
| `godot/scripts/Economia.gd` | Extracción por hora, bloque en curso, recálculo periódico. |
| `godot/scripts/Ciudad.gd` | Topes, ampliación, baúles, `horas_juego`, corrección de `agregar`. |
| `godot/scripts/VoxelWorld.gd` | `altura_natural_en`, `es_minable`, extracción del avatar, frutos. |
| `godot/scripts/ProgresoAccion.gd` (nuevo) | Avance de una acción con reinicio, puro. |
| `godot/scripts/ExtraccionTest.gd` + `godot/scenes/ExtraccionTest.tscn` (nuevos) | Pruebas de `ProgresoAccion`, tiempos, extracción del avatar y frutos. |
| `godot/scripts/HUD.gd` | Barra de progreso. |
| `godot/scripts/Player.gd` | Minado/tala/frutos por tiempo, núcleo sin camas. |
| `godot/scripts/BlueprintValidator.gd` | `contar_baules()`. |
| `godot/scripts/CamaraCenital.gd`, `Main.gd` | Usan `Recoleccion.entorno_de_puesto`/`tasas_de_entorno`; inyectan el mundo en `Economia`. |

---

### Task 0: Rama de trabajo

- [ ] **Step 1: Crear la rama** (el trabajo SDD va en una rama aislada, no en `main`)

```bash
git checkout -b feat/2b-extraccion-agotamiento
```

Expected: `Switched to a new branch 'feat/2b-extraccion-agotamiento'`.

---

### Task 1: `GeneradorArbol` — consultas del registro

**Files:**
- Modify: `godot/scripts/GeneradorArbol.gd` (funciones `registrar`, y funciones nuevas al final)
- Test: `godot/scripts/GeneradorArbolTest.gd`

**Interfaces:**
- Produces: `salud_de(id: int) -> int` (0 si no existe o ya talado), `salud_maxima_de(id: int) -> int`, `ids_en_radio(centro: Vector2i, radio: int) -> Array`, `mas_cercano_en_radio(centro: Vector2i, radio: int) -> int` (`-1` si no hay). La posición de un árbol es la de su primera celda registrada.

- [ ] **Step 1: Escribir la prueba que falla** — insertar en `GeneradorArbolTest.gd` antes de la línea final (`Las 11 pruebas`) y subir a 12:

```gdscript
	print("\n=== TEST 12: ids_en_radio(), mas_cercano_en_radio(), salud_de() y salud_maxima_de() ===")
	var gen_radio: RefCounted = GeneradorArbolScript.new()
	var cerca: int = gen_radio.registrar([Vector3i(10, 5, 10), Vector3i(10, 6, 10)], 2)
	var lejos: int = gen_radio.registrar([Vector3i(30, 5, 30)], 1)
	assert(gen_radio.ids_en_radio(Vector2i(10, 10), 5) == [cerca])
	assert(gen_radio.ids_en_radio(Vector2i(20, 20), 30).size() == 2)
	assert(gen_radio.mas_cercano_en_radio(Vector2i(28, 28), 30) == lejos)
	assert(gen_radio.mas_cercano_en_radio(Vector2i(100, 100), 5) == -1, "sin árboles en el radio")
	assert(gen_radio.salud_de(cerca) == 2 and gen_radio.salud_maxima_de(cerca) == 2)
	gen_radio.danar(cerca, 1)
	assert(gen_radio.salud_de(cerca) == 1 and gen_radio.salud_maxima_de(cerca) == 2)
	gen_radio.eliminar(cerca)
	assert(gen_radio.salud_de(cerca) == 0 and gen_radio.salud_maxima_de(cerca) == 0)
	assert(gen_radio.ids_en_radio(Vector2i(10, 10), 5).is_empty())
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/GeneradorArbolTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR` / `Parse Error` (función inexistente).

- [ ] **Step 3: Implementar** — en `GeneradorArbol.gd` reemplazar la línea del diccionario `_arboles` de `registrar()` y el comentario del campo, y agregar las funciones nuevas al final del archivo.

Cambiar el comentario de la línea 16:

```gdscript
var _arboles: Dictionary = {}  # int -> {"celdas": Array, "salud": int, "salud_max": int, "xz": Vector2i}
```

Reemplazar el cuerpo de `registrar()`:

```gdscript
func registrar(celdas_mundiales: Array, salud_maxima: int) -> int:
	var id: int = _siguiente_id
	_siguiente_id += 1
	var referencia := Vector2i.ZERO
	if not celdas_mundiales.is_empty():
		referencia = Vector2i(celdas_mundiales[0].x, celdas_mundiales[0].z)
	_arboles[id] = {"celdas": celdas_mundiales, "salud": salud_maxima, "salud_max": salud_maxima, "xz": referencia}
	for celda in celdas_mundiales:
		_celda_a_arbol[celda] = id
	return id
```

Agregar al final del archivo:

```gdscript


## Salud restante del árbol "id" (0 si no existe o ya está talado).
func salud_de(id: int) -> int:
	if not _arboles.has(id):
		return 0
	return maxi(0, _arboles[id]["salud"])


## Salud con la que se registró el árbol "id" (0 si no existe).
func salud_maxima_de(id: int) -> int:
	if not _arboles.has(id):
		return 0
	return _arboles[id]["salud_max"]


## Ids de los árboles cuya columna de referencia (la de su primera celda)
## cae a "radio" celdas o menos de "centro", en orden de registro.
func ids_en_radio(centro: Vector2i, radio: int) -> Array:
	var ids: Array = []
	for id in _arboles:
		if Vector2(_arboles[id]["xz"] - centro).length() <= radio:
			ids.append(id)
	return ids


## Id del árbol más cercano a "centro" dentro de "radio", o -1 si no hay.
func mas_cercano_en_radio(centro: Vector2i, radio: int) -> int:
	var mejor := -1
	var mejor_distancia := INF
	for id in ids_en_radio(centro, radio):
		var distancia: float = Vector2(_arboles[id]["xz"] - centro).length_squared()
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = id
	return mejor
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: el mismo comando del Step 2.
Expected: `=== Las 12 pruebas de GeneradorArbol pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/GeneradorArbol.gd godot/scripts/GeneradorArbolTest.gd
git commit -m "feat: consultas de salud y radio en el registro de árboles" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `Recoleccion` — rendimiento, tiempos y detección de subsuelo

**Files:**
- Modify: `godot/scripts/Recoleccion.gd` (constantes tras `TIPOS_MINERALES`; `detectar_recursos`; funciones nuevas)
- Modify: `godot/scripts/VoxelWorld.gd` (`altura_natural_en`, tras `altura_en`)
- Test: `godot/scripts/RecoleccionTest.gd`

**Interfaces:**
- Produces: `Recoleccion.RENDIMIENTO_POR_BLOQUE`, `Recoleccion.PROFUNDIDAD_MINIMA_EXTRACCION` (= 2), `Recoleccion.rendimiento_de(tipo: String) -> float`, `Recoleccion.detectar_recursos(mundo, centro_xz, altura_superficie, profundidad = NIVEL_1, profundidad_minima = 0)`, `Recoleccion.detectar_recursos_extraibles(mundo, centro_xz, altura_superficie, profundidad = NIVEL_1) -> Dictionary`, `VoxelWorld.altura_natural_en(x: int, z: int) -> int`.
- Con `profundidad_minima = 0` (por defecto) `detectar_recursos` se comporta exactamente como hoy: las pruebas existentes no cambian.

- [ ] **Step 1: Escribir la prueba que falla** — insertar en `RecoleccionTest.gd` (antes de `Las 24 pruebas`, subir a 25):

```gdscript
	print("\n=== TEST 25: detectar_recursos_extraibles() solo cuenta subsuelo natural desde la profundidad mínima ===")
	assert(Recoleccion.PROFUNDIDAD_MINIMA_EXTRACCION == 2, "GROSOR_TIERRA (4) - 2")
	assert(Recoleccion.rendimiento_de("tierra") == 1.0 and Recoleccion.rendimiento_de("piedra") == 10.0)
	assert(Recoleccion.rendimiento_de("madera") == 10.0 and Recoleccion.rendimiento_de("agua") == 0.0)
	var mundo_ext: Node = VoxelWorld.new()
	mundo_ext.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_ext.cell_size = Vector3.ONE * 1.0
	mundo_ext._indexar_biblioteca()
	var c_ext := Vector2i(300, 300)
	# Superficie en y=9 (dos columnas). Bajo el centro: hierro a profundidad 1 (y=8, intocable)
	# y a profundidad 2 y 3 (y=7 y y=6). En la otra columna, un hierro puesto por el jugador (y=5).
	mundo_ext.colocar_bloque(Vector3i(300, 9, 300), "piedra")
	mundo_ext.colocar_bloque(Vector3i(301, 9, 300), "piedra")
	mundo_ext.colocar_bloque(Vector3i(300, 8, 300), "hierro")
	mundo_ext.colocar_bloque(Vector3i(300, 7, 300), "hierro")
	mundo_ext.colocar_bloque(Vector3i(300, 6, 300), "hierro")
	mundo_ext.colocar_bloque(Vector3i(301, 5, 300), "hierro", true)
	var todo_ext: Dictionary = Recoleccion.detectar_recursos(mundo_ext, c_ext, 10)
	assert(todo_ext.get("piedra", 0) == 2 and todo_ext.get("hierro", 0) == 4, "por defecto cuenta todo, como antes")
	var extraible: Dictionary = Recoleccion.detectar_recursos_extraibles(mundo_ext, c_ext, 10)
	assert(not extraible.has("piedra"), "la superficie (profundidad 0) no se toca")
	assert(extraible.get("hierro", 0) == 2, "solo y=7 e y=6: no y=8 (profundidad 1) ni el bloque del jugador")
	print("OK: la mina solo ve subsuelo natural desde la profundidad 2.")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/RecoleccionTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error` (constante y funciones inexistentes).

- [ ] **Step 3: Implementar**

En `VoxelWorld.gd`, justo después de la función `altura_en()`, agregar:

```gdscript


## Altura de la superficie NATURAL de la columna (x,z): la del generador, sin
## contar lo que el jugador construyó ni los árboles (una mina mide su
## profundidad desde aquí, ver Recoleccion.PROFUNDIDAD_MINIMA_EXTRACCION).
## Sin generador (mundos de prueba armados a mano) usa el bloque más alto
## real, ignorando el agua.
func altura_natural_en(x: int, z: int) -> int:
	if generador != null:
		return generador.altura_en(x, z)
	return altura_en(x, z, true)
```

En `Recoleccion.gd`, agregar tras `TIPOS_MINERALES` (línea 43):

```gdscript

const GeneradorMundoScript = preload("res://scripts/GeneradorMundo.gd")

## Unidades de recurso que rinde un bloque de extracción (sub-proyecto 2B, ver
## docs/superpowers/specs/2026-09-24-extraccion-fisica-agotamiento-design.md).
## "madera" es por celda de tronco. Placeholders de balance; agua (2) y
## petróleo (2) quedan reservados para el sub-proyecto de fluidos.
const RENDIMIENTO_POR_BLOQUE := {
	"tierra": 1.0, "piedra": 10.0, "hierro": 10.0, "cobre": 10.0,
	"carbon": 10.0, "tierras_raras": 10.0, "madera": 10.0,
}

## Una mina solo extrae bloques al menos a esta profundidad bajo la superficie
## natural de su columna (GROSOR_TIERRA - 2), para que el terreno de arriba no
## quede flotando ni con un hueco en la superficie.
const PROFUNDIDAD_MINIMA_EXTRACCION := GeneradorMundoScript.GROSOR_TIERRA - 2

## Centinela: "no hay centro de agua" en entorno_de_puesto().
const SIN_CENTRO := Vector2i(-99999, -99999)
## Centinela: "no queda ningún bloque que extraer" en siguiente_bloque_mina().
const SIN_BLOQUE := Vector3i(-99999, -99999, -99999)
```

Reemplazar la función `detectar_recursos` completa (líneas 187-199) por:

```gdscript
func detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int, profundidad: int = PROFUNDIDAD_MINA_NIVEL_1, profundidad_minima: int = 0) -> Dictionary:
	var conteo: Dictionary = {}  # String (tipo) -> int
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			# "profundidad_minima" > 0: solo cuenta bloques extraíbles, por debajo de
			# la superficie natural de esta columna y naturales (ver _es_extraible()).
			var techo: int = 1 << 30
			if profundidad_minima > 0:
				techo = mundo.altura_natural_en(centro_xz.x + dx, centro_xz.y + dz) - profundidad_minima
			for dy in range(0, profundidad + 1):
				var normalizado := Vector3(float(dx) / RADIO_AREA_MINA, float(dy) / profundidad, float(dz) / RADIO_AREA_MINA)
				if normalizado.length() > 1.0:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				if celda.y > techo:
					continue
				var tipo: String = mundo.material_real(mundo.obtener_tipo(celda))
				if TIPOS_MINERALES.has(tipo) and (profundidad_minima == 0 or _es_extraible(mundo, celda)):
					conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo


## detectar_recursos() tal como lo ve la mina real: solo subsuelo natural desde
## PROFUNDIDAD_MINIMA_EXTRACCION. Es lo que usan la previsualización, las tasas
## del puesto y la extracción, para que tasa y consumo coincidan.
func detectar_recursos_extraibles(mundo: Object, centro_xz: Vector2i, altura_superficie: int, profundidad: int = PROFUNDIDAD_MINA_NIVEL_1) -> Dictionary:
	return detectar_recursos(mundo, centro_xz, altura_superficie, profundidad, PROFUNDIDAD_MINIMA_EXTRACCION)


## Un bloque es extraíble por una mina si es terreno natural (ni árbol, ni
## estructura, ni parte de un edificio, ni agua) y no lo colocó el jugador.
func _es_extraible(mundo: Object, celda: Vector3i) -> bool:
	return mundo.es_terreno_natural(celda) and not mundo.colocado_por_jugador.has(celda)


## Unidades de recurso que rinde un bloque del tipo "tipo" (0.0 si no rinde).
func rendimiento_de(tipo: String) -> float:
	return RENDIMIENTO_POR_BLOQUE.get(tipo, 0.0)
```

- [ ] **Step 4: Ejecutar y verificar que pasa** (todas las pruebas antiguas siguen igual)

Run: el comando del Step 2.
Expected: `=== Las 25 pruebas de Recoleccion pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd godot/scripts/VoxelWorld.gd
git commit -m "feat: rendimiento por bloque y detección de subsuelo extraíble para minas" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: `Recoleccion` — selección de bloque de mina, entorno y tasas de un puesto

**Files:**
- Modify: `godot/scripts/Recoleccion.gd` (funciones nuevas al final)
- Test: `godot/scripts/RecoleccionTest.gd`

**Interfaces:**
- Consumes: `Recoleccion.detectar_recursos_extraibles`, `GeneradorArbol.ids_en_radio` (Tarea 1), `mundo.altura_natural_en`, `mundo.es_terreno_natural`, `mundo.colocado_por_jugador`, `mundo.material_real`, `mundo.obtener_tipo`, `mundo.arboles`, `mundo.generador`.
- Produces:
  - `siguiente_bloque_mina(mundo, centro_xz, altura_superficie, recurso: String, profundidad = NIVEL_1) -> Vector3i` (`SIN_BLOQUE` si no queda ninguno; el más cercano al centro y, a igual distancia, el menos profundo).
  - `arboles_vivos_en(mundo, centro: Vector2i, radio: int) -> int`.
  - `entorno_de_puesto(tipo: String, mundo, centro: Vector2i, altura: int, centro_agua: Vector2i = SIN_CENTRO) -> Dictionary` con claves `centro`, `altura`, opcionales `centro_agua`, `radio_arboles`, `arboles_ref`.
  - `factor_arboles(mundo, entorno: Dictionary) -> float` (1.0 si `arboles_ref` es 0 o falta; tope 1.0).
  - `tasas_de_entorno(tipo: String, mundo, entorno: Dictionary) -> Dictionary` (mismas claves de tasa que `tasas_*`).
- Tipos de puesto válidos: `"mina"`, `"caza_recoleccion"`, `"pesca_frutos_mar"`, `"maderero"`.

- [ ] **Step 1: Escribir la prueba que falla** — insertar en `RecoleccionTest.gd` (antes de `Las 25 pruebas`, subir a 27). Primero, junto a las otras clases falsas del principio del archivo (tras `GeneradorProfundidadFalso`), agregar:

```gdscript
## Mundo falso para las tasas de un puesto: solo lo que tasas_de_entorno() lee de él.
class MundoFalso:
	var generador
	var arboles
```

Y las pruebas:

```gdscript
	print("\n=== TEST 26: siguiente_bloque_mina() elige el más cercano al centro, sin tocar la superficie ===")
	var mundo_sig: Node = VoxelWorld.new()
	mundo_sig.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_sig.cell_size = Vector3.ONE * 1.0
	mundo_sig._indexar_biblioteca()
	var c_sig := Vector2i(400, 400)
	mundo_sig.colocar_bloque(Vector3i(400, 9, 400), "piedra")
	mundo_sig.colocar_bloque(Vector3i(401, 9, 400), "piedra")
	mundo_sig.colocar_bloque(Vector3i(400, 8, 400), "hierro")  # profundidad 1: intocable
	mundo_sig.colocar_bloque(Vector3i(400, 7, 400), "hierro")  # distancia² 9
	mundo_sig.colocar_bloque(Vector3i(401, 7, 400), "hierro")  # distancia² 10
	mundo_sig.colocar_bloque(Vector3i(400, 6, 400), "hierro")  # distancia² 16
	var tasas_mina: Dictionary = Recoleccion.tasas_de_entorno("mina", mundo_sig, {"centro": c_sig, "altura": 10})
	assert(tasas_mina.size() == 1 and is_equal_approx(tasas_mina["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]), "solo hierro extraíble: 3 bloques")
	assert(Recoleccion.siguiente_bloque_mina(mundo_sig, c_sig, 10, "piedra") == Recoleccion.SIN_BLOQUE, "la piedra está en la superficie")
	var b1: Vector3i = Recoleccion.siguiente_bloque_mina(mundo_sig, c_sig, 10, "hierro")
	assert(b1 == Vector3i(400, 7, 400))
	mundo_sig.minar_bloque(b1)
	var b2: Vector3i = Recoleccion.siguiente_bloque_mina(mundo_sig, c_sig, 10, "hierro")
	assert(b2 == Vector3i(401, 7, 400))
	mundo_sig.minar_bloque(b2)
	assert(Recoleccion.siguiente_bloque_mina(mundo_sig, c_sig, 10, "hierro") == Vector3i(400, 6, 400))
	mundo_sig.minar_bloque(Vector3i(400, 6, 400))
	assert(Recoleccion.siguiente_bloque_mina(mundo_sig, c_sig, 10, "hierro") == Recoleccion.SIN_BLOQUE)
	assert(Recoleccion.tasas_de_entorno("mina", mundo_sig, {"centro": c_sig, "altura": 10}).is_empty(), "mina agotada: sin tasas")

	print("\n=== TEST 27: entorno_de_puesto() y tasas_de_entorno() escalan con los árboles vivos ===")
	var mundo_arb := MundoFalso.new()
	mundo_arb.generador = GeneradorBiomaFalso.new()
	mundo_arb.arboles = preload("res://scripts/GeneradorArbol.gd").new()
	var ids_arb: Array = []
	for i in range(1, 5):
		ids_arb.append(mundo_arb.arboles.registrar([Vector3i(i, 5, i)], 3))
	var entorno_caza: Dictionary = Recoleccion.entorno_de_puesto("caza_recoleccion", mundo_arb, Vector2i(0, 0), 5)
	assert(entorno_caza["arboles_ref"] == 4 and entorno_caza["radio_arboles"] == Recoleccion.RADIO_AREA_CAZA_RECOLECCION)
	assert(not entorno_caza.has("centro_agua"))
	var tasas_caza_llena: Dictionary = Recoleccion.tasas_de_entorno("caza_recoleccion", mundo_arb, entorno_caza)
	assert(is_equal_approx(tasas_caza_llena["caza"], 0.8 * Recoleccion.TASA_BASE_CAZA_POR_CIUDADANO))
	assert(is_equal_approx(tasas_caza_llena["recoleccion"], 0.4 * Recoleccion.TASA_BASE_FRUTOS_POR_CIUDADANO))
	mundo_arb.arboles.eliminar(ids_arb[0])
	mundo_arb.arboles.eliminar(ids_arb[1])
	assert(Recoleccion.factor_arboles(mundo_arb, entorno_caza) == 0.5)
	var tasas_caza_mitad: Dictionary = Recoleccion.tasas_de_entorno("caza_recoleccion", mundo_arb, entorno_caza)
	assert(is_equal_approx(tasas_caza_mitad["caza"], 0.5 * tasas_caza_llena["caza"]), "talar el bosque reduce la caza")
	assert(is_equal_approx(tasas_caza_mitad["recoleccion"], 0.5 * tasas_caza_llena["recoleccion"]), "y los frutos")
	var entorno_mad: Dictionary = Recoleccion.entorno_de_puesto("maderero", mundo_arb, Vector2i(0, 0), 5)
	assert(entorno_mad["arboles_ref"] == 2 and entorno_mad["radio_arboles"] == Recoleccion.RADIO_AREA_MADERERO)
	assert(is_equal_approx(Recoleccion.tasas_de_entorno("maderero", mundo_arb, entorno_mad)["madera"], 0.6 * Recoleccion.TASA_BASE_MADERERO_POR_CIUDADANO))
	mundo_arb.arboles.eliminar(ids_arb[2])
	assert(Recoleccion.factor_arboles(mundo_arb, entorno_mad) == 0.5)
	# Sin árboles al colocar el puesto: factor 1, sin dividir por cero.
	var mundo_sin := MundoFalso.new()
	mundo_sin.generador = GeneradorBiomaFalso.new()
	mundo_sin.arboles = preload("res://scripts/GeneradorArbol.gd").new()
	var entorno_sin: Dictionary = Recoleccion.entorno_de_puesto("maderero", mundo_sin, Vector2i(0, 0), 5)
	assert(entorno_sin["arboles_ref"] == 0 and Recoleccion.factor_arboles(mundo_sin, entorno_sin) == 1.0)
	# Pesca: recalcula con el agua conectada; sin centro de agua no hay tasas.
	var mundo_agua := MundoFalso.new()
	mundo_agua.generador = GeneradorAguaConectadaFalso.new()
	mundo_agua.arboles = preload("res://scripts/GeneradorArbol.gd").new()
	var entorno_agua: Dictionary = Recoleccion.entorno_de_puesto("pesca_frutos_mar", mundo_agua, Vector2i(2, 2), 5, Vector2i(2, 2))
	var celdas_agua_ent: Dictionary = Recoleccion.celdas_agua_conectadas(mundo_agua.generador, Vector2i(2, 2), Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)
	var esperado_agua: Dictionary = Recoleccion.tasas_pesca_frutos_mar(Recoleccion.detectar_pesca_frutos_mar(mundo_agua.generador, celdas_agua_ent))
	assert(Recoleccion.tasas_de_entorno("pesca_frutos_mar", mundo_agua, entorno_agua) == esperado_agua)
	assert(Recoleccion.tasas_de_entorno("pesca_frutos_mar", mundo_agua, Recoleccion.entorno_de_puesto("pesca_frutos_mar", mundo_agua, Vector2i(2, 2), 5)).is_empty())
	print("OK: entorno y tasas de un puesto se recalculan desde el mundo.")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/RecoleccionTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error`.

- [ ] **Step 3: Implementar** — agregar al final de `Recoleccion.gd`:

```gdscript


## Siguiente bloque de "recurso" (p. ej. "hierro") que una mina extrae: el más
## cercano al centro del puesto y, a igual distancia, el menos profundo. Solo
## subsuelo natural desde PROFUNDIDAD_MINIMA_EXTRACCION (ver
## detectar_recursos()). SIN_BLOQUE si no queda ninguno.
func siguiente_bloque_mina(mundo: Object, centro_xz: Vector2i, altura_superficie: int, recurso: String, profundidad: int = PROFUNDIDAD_MINA_NIVEL_1) -> Vector3i:
	var mejor := SIN_BLOQUE
	var mejor_distancia := INF
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			var techo: int = mundo.altura_natural_en(centro_xz.x + dx, centro_xz.y + dz) - PROFUNDIDAD_MINIMA_EXTRACCION
			for dy in range(0, profundidad + 1):
				var normalizado := Vector3(float(dx) / RADIO_AREA_MINA, float(dy) / profundidad, float(dz) / RADIO_AREA_MINA)
				if normalizado.length() > 1.0:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				if celda.y > techo:
					continue
				if mundo.material_real(mundo.obtener_tipo(celda)) != recurso or not _es_extraible(mundo, celda):
					continue
				var distancia := float(dx * dx + dy * dy + dz * dz)
				if distancia < mejor_distancia or (distancia == mejor_distancia and celda.y > mejor.y):
					mejor_distancia = distancia
					mejor = celda
	return mejor


## Árboles vivos registrados a "radio" celdas o menos de "centro".
func arboles_vivos_en(mundo: Object, centro: Vector2i, radio: int) -> int:
	return mundo.arboles.ids_en_radio(centro, radio).size()


## Lo que un puesto necesita recordar del mundo para recalcular sus tasas y
## extraer: "centro" y "altura" (superficie en el centro al colocarlo);
## "centro_agua" (pesca); "radio_arboles" y "arboles_ref" (árboles vivos en su
## área al colocarlo — caza/recolección y maderero).
func entorno_de_puesto(tipo: String, mundo: Object, centro: Vector2i, altura: int, centro_agua: Vector2i = SIN_CENTRO) -> Dictionary:
	var entorno := {"centro": centro, "altura": altura}
	if centro_agua != SIN_CENTRO:
		entorno["centro_agua"] = centro_agua
	if tipo == "caza_recoleccion" or tipo == "maderero":
		var radio: int = RADIO_AREA_MADERERO if tipo == "maderero" else RADIO_AREA_CAZA_RECOLECCION
		entorno["radio_arboles"] = radio
		entorno["arboles_ref"] = arboles_vivos_en(mundo, centro, radio)
	return entorno


## Fracción de los árboles de su área que sigue en pie (tope 1.0). Sin árboles
## de referencia al colocar el puesto no hay nada que escalar: 1.0.
func factor_arboles(mundo: Object, entorno: Dictionary) -> float:
	var referencia: int = entorno.get("arboles_ref", 0)
	if referencia <= 0:
		return 1.0
	return minf(1.0, float(arboles_vivos_en(mundo, entorno["centro"], entorno["radio_arboles"])) / float(referencia))


## Tasas por trabajador y hora de un puesto según el estado ACTUAL del mundo
## (mismas claves que tasas_recoleccion()/tasas_caza_recoleccion()/
## tasa_maderero()/tasas_pesca_frutos_mar()). Caza/recolección y maderero se
## escalan con factor_arboles(): talar el bosque reduce fauna, frutos y madera.
func tasas_de_entorno(tipo: String, mundo: Object, entorno: Dictionary) -> Dictionary:
	var centro: Vector2i = entorno["centro"]
	if tipo == "mina":
		return tasas_recoleccion(detectar_recursos_extraibles(mundo, centro, entorno["altura"]))
	if tipo == "pesca_frutos_mar":
		if not entorno.has("centro_agua"):
			return {}
		var celdas_agua: Dictionary = celdas_agua_conectadas(mundo.generador, entorno["centro_agua"], RADIO_AREA_PESCA_FRUTOS_MAR)
		return tasas_pesca_frutos_mar(detectar_pesca_frutos_mar(mundo.generador, celdas_agua))
	var tasas: Dictionary
	if tipo == "caza_recoleccion":
		tasas = tasas_caza_recoleccion(detectar_fauna_frutal(mundo.generador, centro))
	else:
		tasas = tasa_maderero(detectar_arbol(mundo.generador, centro))
	var factor := factor_arboles(mundo, entorno)
	for clave in tasas:
		tasas[clave] *= factor
	return tasas
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: el comando del Step 2.
Expected: `=== Las 27 pruebas de Recoleccion pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: selección de bloque de mina y tasas de un puesto según su entorno" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `Economia` — extracción física y agotamiento

**Files:**
- Modify: `godot/scripts/Economia.gd`
- Modify: `godot/scripts/VoxelWorld.gd` (`retirar_bloque_extraido`)
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Consumes: `Recoleccion.siguiente_bloque_mina`, `Recoleccion.rendimiento_de`, `Recoleccion.SIN_BLOQUE`, `mundo.arboles.mas_cercano_en_radio/celdas_de/salud_de`, `mundo.talar_bloque_de_arbol`.
- Produces: `Economia.mundo: Object` (VoxelWorld inyectable, `null` = sin extracción); `registrar_puesto(esquina, tipo, ancho, alto, tasas, entorno: Dictionary = {})`; `VoxelWorld.retirar_bloque_extraido(celda: Vector3i) -> void`.
- Comportamiento: en `simular_hora`, mina y maderero con `mundo` y `entorno` no vacío solo suman al almacén local lo que **de verdad** pudieron extraer; caza/recolección y pesca no consumen.

- [ ] **Step 1: Escribir la prueba que falla** — en `EconomiaTest.gd`: agregar tras `const CiudadScript` (línea 8):

```gdscript
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")
```

Agregar tras `_nueva()`:

```gdscript
## Un VoxelWorld sin _ready() (mismo patrón que RecoleccionTest.gd) con el registro de árboles listo.
func _mundo_nuevo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	mundo.arboles = GeneradorArbolScript.new()
	return mundo


## Veta de 3 bloques de hierro (30 unidades) bajo (500,500): superficie en y=9 y un hierro a
## profundidad 1 (y=8) que la mina no toca; extraíbles: (500,7,500), (501,7,500) y (500,6,500), en ese orden.
func _mundo_con_veta() -> Node:
	var mundo: Node = _mundo_nuevo()
	mundo.colocar_bloque(Vector3i(500, 9, 500), "piedra")
	mundo.colocar_bloque(Vector3i(501, 9, 500), "piedra")
	mundo.colocar_bloque(Vector3i(500, 8, 500), "hierro")
	mundo.colocar_bloque(Vector3i(500, 7, 500), "hierro")
	mundo.colocar_bloque(Vector3i(501, 7, 500), "hierro")
	mundo.colocar_bloque(Vector3i(500, 6, 500), "hierro")
	return mundo


## Un árbol de 3 troncos (salud 3 = 30 unidades de madera) en (600,600), registrado en el mundo.
func _mundo_con_arbol() -> Array:
	var mundo: Node = _mundo_nuevo()
	var celdas: Array = [Vector3i(600, 5, 600), Vector3i(600, 6, 600), Vector3i(600, 7, 600)]
	for celda in celdas:
		mundo.colocar_bloque(celda, "madera")
	var id: int = mundo.arboles.registrar(celdas, 3)
	return [mundo, id]
```

Y las pruebas (antes de `Las 10 pruebas`, subir a 13):

```gdscript
	print("\n=== TEST 11: una mina consume sus bloques y se agota ===")
	var mundo11: Node = _mundo_con_veta()
	var e11: Node = EconomiaScript.new()
	e11.ciudad = CiudadScript.new()
	e11.mundo = mundo11
	var esq11 := Vector2i(50, 50)
	e11.registrar_puesto(esq11, "mina", 5, 5, {"hierro": 12.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e11.asignar(esq11, "recolector", 1)
	e11.marcar_presente(1, true)
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 12.0))
	assert(mundo11.obtener_tipo(Vector3i(500, 7, 500)) == "", "el bloque más cercano ya se retiró")
	assert(mundo11.obtener_tipo(Vector3i(501, 7, 500)) == "hierro", "el segundo va a medias (8 de 10)")
	assert(mundo11.obtener_tipo(Vector3i(500, 8, 500)) == "hierro", "la profundidad 1 nunca se toca")
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 24.0))
	assert(mundo11.obtener_tipo(Vector3i(501, 7, 500)) == "", "una hora agotó un bloque y empezó el siguiente")
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 30.0), "solo quedaban 6 unidades de las 12 pedidas")
	assert(mundo11.obtener_tipo(Vector3i(500, 6, 500)) == "")
	e11.simular_hora()
	assert(is_equal_approx(e11.almacen_local(esq11)["hierro"], 30.0), "mina agotada: no produce nada más")
	assert(mundo11.obtener_tipo(Vector3i(500, 8, 500)) == "hierro" and mundo11.obtener_tipo(Vector3i(500, 9, 500)) == "piedra")

	print("\n=== TEST 12: un maderero tala árboles enteros y se agota ===")
	var datos12: Array = _mundo_con_arbol()
	var mundo12: Node = datos12[0]
	var id12: int = datos12[1]
	var e12: Node = EconomiaScript.new()
	e12.ciudad = CiudadScript.new()
	e12.mundo = mundo12
	var entorno12 := {"centro": Vector2i(600, 600), "altura": 5, "radio_arboles": 12, "arboles_ref": 1}
	e12.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 12.0}, entorno12)
	e12.asignar(ESQ, "recolector", 1)
	e12.marcar_presente(1, true)
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 12.0))
	assert(mundo12.arboles.salud_de(id12) == 2, "un tronco (10 unidades) ya se consumió")
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 24.0))
	assert(mundo12.arboles.salud_de(id12) == 1)
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 30.0), "el árbol solo rendía 30")
	assert(mundo12.arboles.salud_de(id12) == 0 and mundo12.obtener_tipo(Vector3i(600, 5, 600)) == "", "el árbol cayó entero")
	e12.simular_hora()
	assert(is_equal_approx(e12.almacen_local(ESQ)["madera"], 30.0), "sin árboles no hay madera")

	print("\n=== TEST 13: si el avatar tala el árbol o mina el bloque en curso, el puesto no produce gratis ===")
	var datos13: Array = _mundo_con_arbol()
	var e13: Node = EconomiaScript.new()
	e13.ciudad = CiudadScript.new()
	e13.mundo = datos13[0]
	e13.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 12.0}, {"centro": Vector2i(600, 600), "altura": 5, "radio_arboles": 12, "arboles_ref": 1})
	e13.asignar(ESQ, "recolector", 1)
	e13.marcar_presente(1, true)
	e13.simular_hora()
	datos13[0].talar_bloque_de_arbol(Vector3i(600, 5, 600), 99)  # el avatar lo derriba
	e13.simular_hora()
	assert(is_equal_approx(e13.almacen_local(ESQ)["madera"], 12.0), "el bloque en curso ya no existe: no suma")
	var mundo13b: Node = _mundo_con_veta()
	var e13b: Node = EconomiaScript.new()
	e13b.ciudad = CiudadScript.new()
	e13b.mundo = mundo13b
	e13b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e13b.asignar(ESQ, "recolector", 1)
	e13b.marcar_presente(1, true)
	e13b.simular_hora()  # deja (500,7,500) a medias
	mundo13b.minar_bloque(Vector3i(500, 7, 500))  # el avatar lo mina
	e13b.simular_hora()
	assert(mundo13b.obtener_tipo(Vector3i(501, 7, 500)) == "hierro", "el puesto pasa al siguiente bloque sin retirarlo entero")
	assert(is_equal_approx(e13b.almacen_local(ESQ)["hierro"], 10.0))
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error` (`mundo` y el 6.º parámetro no existen).

- [ ] **Step 3: Implementar**

En `VoxelWorld.gd`, justo después de `_retirar_bloque()`, agregar:

```gdscript


## Retira "celda" porque un puesto la extrajo (sin las guardas de minar_bloque()).
## No-op si ya está vacía (p. ej. el avatar la minó antes).
func retirar_bloque_extraido(celda: Vector3i) -> void:
	if get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
		_retirar_bloque(celda)
```

En `Economia.gd`:

1) Tras `const ROLES` agregar:

```gdscript

## Tipos de puesto que consumen el mundo al producir; caza/recolección y pesca
## no consumen bloques (sus tasas dependen del entorno, ver recalcular_tasas()).
const TIPOS_QUE_CONSUMEN := ["mina", "maderero"]
```

2) Tras `var ciudad: Object = null  # Ciudad` agregar:

```gdscript
## VoxelWorld, inyectable (Main.gd lo asigna). Sin él los puestos producen sin
## consumir el mundo.
var mundo: Object = null
```

3) Cambiar el comentario y el diccionario del puesto (líneas 34-38) para incluir `"entorno"` y `"en_curso"`, y reemplazar `registrar_puesto()`:

```gdscript
## Vector2i (esquina de la huella) -> {"tipo", "ancho", "alto", "cupo",
## "capacidad", "tasas" (clave de tasa -> unidades por recolector y hora),
## "entorno" (lo que Recoleccion.entorno_de_puesto() recordó del mundo al
## colocarlo), "en_curso" (recurso -> {"tipo": "bloque"|"arbol", "restante"
## en unidades, y "celda" o "id"}: el bloque o árbol que se está agotando),
## "recolectores": Array[int], "acarreadores": Array[int],
## "presentes": Dictionary (id de recolector -> true),
## "almacen": Dictionary (recurso -> float)}.
```

```gdscript
## Registra un puesto recién colocado, sin trabajadores. "tasas" son las de
## Recoleccion.tasas_de_entorno() al colocarlo y "entorno" el de
## Recoleccion.entorno_de_puesto() ({} = el puesto no consume ni recalcula).
func registrar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int, tasas: Dictionary, entorno: Dictionary = {}) -> void:
	puestos[esquina] = {
		"tipo": tipo, "ancho": ancho, "alto": alto,
		"cupo": Recoleccion.cupo_de(tipo),
		"capacidad": Recoleccion.capacidad_almacen_de(tipo),
		"tasas": tasas.duplicate(),
		"entorno": entorno.duplicate(),
		"en_curso": {},
		"recolectores": [], "acarreadores": [],
		"presentes": {}, "almacen": {},
	}
```

4) Reemplazar `simular_hora()` (y su comentario) por:

```gdscript
## Una hora de juego de producción en todos los puestos: cada recolector
## presente suma su tasa al almacén local, pero solo lo que el entorno permita
## extraer (mina y maderero consumen bloques y árboles reales; ver _extraer()).
## Si el total local llegaría a pasar de la capacidad, solo entra lo que cabe,
## en proporción (el exceso se pierde: la producción se frena contra el tope y
## avisa de que falta acarreo).
func simular_hora() -> void:
	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		var producido: Dictionary = produccion_por_hora(esquina)
		var total_producido := _total(producido)
		if total_producido <= 0.0:
			continue
		var espacio: float = p["capacidad"] - _total(p["almacen"])
		if espacio <= 0.0:
			continue
		var factor: float = minf(1.0, espacio / total_producido)
		for recurso in producido:
			var concedido: float = _extraer(esquina, recurso, producido[recurso] * factor)
			if concedido > 0.0:
				p["almacen"][recurso] = p["almacen"].get(recurso, 0.0) + concedido


## Descuenta del mundo hasta "unidades" de "recurso" para el puesto y devuelve
## cuántas se pudieron extraer de verdad (menos si el área se agotó). Trabaja
## sobre el bloque o árbol "en curso" del recurso: cuando se agota, se retira
## del mundo y se pasa al siguiente. Sin mundo o sin entorno, o en puestos que
## no consumen, devuelve "unidades" sin tocar nada.
func _extraer(esquina: Vector2i, recurso: String, unidades: float) -> float:
	var p: Dictionary = puestos[esquina]
	if mundo == null or p["entorno"].is_empty() or not TIPOS_QUE_CONSUMEN.has(p["tipo"]):
		return unidades
	var extraido := 0.0
	while unidades - extraido > 1e-9:
		var actual: Dictionary = p["en_curso"].get(recurso, {})
		if not actual.is_empty() and not _en_curso_valido(actual):
			actual = {}  # el avatar lo derribó o lo minó: se descarta
		if actual.is_empty():
			actual = _siguiente_bloque(p, recurso)
			if actual.is_empty():
				p["en_curso"].erase(recurso)
				break
			p["en_curso"][recurso] = actual
		var tomado: float = minf(unidades - extraido, actual["restante"])
		actual["restante"] -= tomado
		extraido += tomado
		if actual["restante"] <= 1e-9:
			_terminar_bloque(actual)
			p["en_curso"].erase(recurso)
	return extraido


## Bloque de mina o árbol siguiente para "recurso" ({} si no queda ninguno).
func _siguiente_bloque(p: Dictionary, recurso: String) -> Dictionary:
	var entorno: Dictionary = p["entorno"]
	if p["tipo"] == "mina":
		var celda: Vector3i = Recoleccion.siguiente_bloque_mina(mundo, entorno["centro"], entorno["altura"], recurso)
		if celda == Recoleccion.SIN_BLOQUE:
			return {}
		return {"tipo": "bloque", "celda": celda, "restante": Recoleccion.rendimiento_de(recurso)}
	var id: int = mundo.arboles.mas_cercano_en_radio(entorno["centro"], entorno["radio_arboles"])
	if id == -1:
		return {}
	return {"tipo": "arbol", "id": id, "restante": Recoleccion.rendimiento_de("madera")}


## Sigue existiendo el bloque o árbol "en curso" (el avatar pudo quitarlo antes).
func _en_curso_valido(actual: Dictionary) -> bool:
	if actual["tipo"] == "bloque":
		return mundo.obtener_tipo(actual["celda"]) != ""
	return mundo.arboles.salud_de(actual["id"]) > 0


## Un bloque quedó agotado: se retira del mundo; un árbol pierde 1 de salud
## (una celda de tronco, 10 unidades) y cae entero al llegar a 0.
func _terminar_bloque(actual: Dictionary) -> void:
	if actual["tipo"] == "bloque":
		mundo.retirar_bloque_extraido(actual["celda"])
		return
	var celdas: Array = mundo.arboles.celdas_de(actual["id"])
	if not celdas.is_empty():
		mundo.talar_bloque_de_arbol(celdas[0], 1)
```

- [ ] **Step 4: Ejecutar y verificar que pasa** (las 10 pruebas antiguas usan `mundo == null`)

Run: el comando del Step 2.
Expected: `=== Las 13 pruebas de Economia pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd godot/scripts/VoxelWorld.gd
git commit -m "feat: los puestos de mina y maderero consumen bloques y árboles reales" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: `Economia` — recálculo periódico de tasas

**Files:**
- Modify: `godot/scripts/Economia.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Consumes: `Recoleccion.tasas_de_entorno` (Tarea 3), `Economia.mundo` (Tarea 4).
- Produces: `Economia.TICKS_RECALCULO := 6`; `recalcular_tasas(esquina: Vector2i) -> void`; `recalcular_todas() -> void`. `simular_hora()` llama a `recalcular_todas()` cada `TICKS_RECALCULO` horas.

- [ ] **Step 1: Escribir la prueba que falla** — en `EconomiaTest.gd`, junto a `_mundo_con_arbol()` agregar la clase falsa (al inicio del archivo, tras las constantes):

```gdscript
## Generador falso: fauna 0.8 y frutal 0.4 en todas partes.
class GeneradorFaunaFalso:
	func densidad_fauna_en(_x: int, _z: int) -> float:
		return 0.8
	func densidad_frutal_en(_x: int, _z: int) -> float:
		return 0.4
	func densidad_arbol_en(_x: int, _z: int) -> float:
		return 0.6

## Solo lo que tasas_de_entorno() lee del mundo para caza/recolección.
class MundoBosqueFalso:
	var generador = GeneradorFaunaFalso.new()
	var arboles = preload("res://scripts/GeneradorArbol.gd").new()
```

Y las pruebas (antes de `Las 13 pruebas`, subir a 15):

```gdscript
	print("\n=== TEST 14: las tasas se recalculan cada TICKS_RECALCULO horas ===")
	assert(EconomiaScript.TICKS_RECALCULO == 6)
	var e14: Node = EconomiaScript.new()
	e14.ciudad = CiudadScript.new()
	e14.mundo = _mundo_con_veta()
	# Tasa desactualizada a propósito (1/h): al recalcular, hierro vale 5 (1 tipo x tasa base 5).
	e14.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 1.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e14.asignar(ESQ, "recolector", 1)
	e14.marcar_presente(1, true)
	for i in range(EconomiaScript.TICKS_RECALCULO - 1):
		e14.simular_hora()
	assert(is_equal_approx(e14.produccion_por_hora(ESQ)["hierro"], 1.0), "todavía no toca recalcular")
	e14.simular_hora()
	assert(is_equal_approx(e14.produccion_por_hora(ESQ)["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]))

	print("\n=== TEST 15: recalcular_tasas() con el área agotada deja la producción en 0, y caza/recolección sigue los árboles ===")
	var e15: Node = EconomiaScript.new()
	e15.ciudad = CiudadScript.new()
	var mundo15: Node = _mundo_con_veta()
	e15.mundo = mundo15
	e15.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 10})
	e15.asignar(ESQ, "recolector", 1)
	e15.marcar_presente(1, true)
	for celda in [Vector3i(500, 7, 500), Vector3i(501, 7, 500), Vector3i(500, 6, 500)]:
		mundo15.minar_bloque(celda)
	e15.recalcular_tasas(ESQ)
	assert(e15.produccion_por_hora(ESQ).is_empty(), "sin bloques extraíbles no hay tasas")
	e15.simular_hora()
	assert(e15.almacen_local(ESQ).is_empty())
	e15.recalcular_tasas(Vector2i(0, 0))  # puesto inexistente: no falla
	var mundo_bosque := MundoBosqueFalso.new()
	var ids15: Array = []
	for i in range(1, 5):
		ids15.append(mundo_bosque.arboles.registrar([Vector3i(i, 5, i)], 3))
	var e15b: Node = EconomiaScript.new()
	e15b.ciudad = CiudadScript.new()
	e15b.mundo = mundo_bosque
	var esq15 := Vector2i(70, 70)
	var entorno15: Dictionary = Recoleccion.entorno_de_puesto("caza_recoleccion", mundo_bosque, Vector2i(0, 0), 5)
	e15b.registrar_puesto(esq15, "caza_recoleccion", 4, 4, Recoleccion.tasas_de_entorno("caza_recoleccion", mundo_bosque, entorno15), entorno15)
	e15b.asignar(esq15, "recolector", 1)
	e15b.marcar_presente(1, true)
	var comida_llena: float = e15b.produccion_por_hora(esq15)["comida"]
	mundo_bosque.arboles.eliminar(ids15[0])
	mundo_bosque.arboles.eliminar(ids15[1])
	e15b.recalcular_tasas(esq15)
	assert(is_equal_approx(e15b.produccion_por_hora(esq15)["comida"], comida_llena * 0.5), "la mitad de los árboles: la mitad de la comida")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/EconomiaTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error` (`TICKS_RECALCULO`/`recalcular_tasas` inexistentes).

- [ ] **Step 3: Implementar** — en `Economia.gd`:

Tras `TIPOS_QUE_CONSUMEN`:

```gdscript

## Cada cuántas horas de juego se recalculan las tasas de todos los puestos
## según lo que queda en su entorno (árboles, bloques de mina, agua).
const TICKS_RECALCULO := 6
```

Tras `var mundo: Object = null`:

```gdscript
var _horas_desde_recalculo := 0
```

Al final de `simular_hora()` (después del `for esquina in puestos:` completo, con un solo nivel de sangría) agregar:

```gdscript
	_horas_desde_recalculo += 1
	if _horas_desde_recalculo >= TICKS_RECALCULO:
		_horas_desde_recalculo = 0
		recalcular_todas()
```

Y tras `simular_hora()` agregar:

```gdscript


## Vuelve a medir el entorno de cada puesto y actualiza sus tasas.
func recalcular_todas() -> void:
	for esquina in puestos:
		recalcular_tasas(esquina)


## Actualiza las tasas de un puesto con el estado actual del mundo (ver
## Recoleccion.tasas_de_entorno()). No-op sin mundo, sin entorno o si el puesto
## no existe.
func recalcular_tasas(esquina: Vector2i) -> void:
	if mundo == null or not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	if p["entorno"].is_empty():
		return
	p["tasas"] = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"])
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: el comando del Step 2.
Expected: `=== Las 15 pruebas de Economia pasaron correctamente ===`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: los puestos recalculan su tasa periódicamente según su entorno" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Conectar la cenital y `Main` con el entorno de los puestos

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd` (línea ~869, la función `_tasas_de_puesto` ~1759-1771, línea ~1823 y ~1904)
- Modify: `godot/scripts/Main.gd`

**Interfaces:**
- Consumes: `Recoleccion.entorno_de_puesto`, `Recoleccion.tasas_de_entorno`, `Recoleccion.detectar_recursos_extraibles`, `Recoleccion.SIN_CENTRO`, `Economia.registrar_puesto(..., entorno)`, `Economia.mundo`.

- [ ] **Step 1: `Main.gd`** — tras `Colonos.mundo = mundo` agregar:

```gdscript
	Economia.mundo = mundo
```

- [ ] **Step 2: Previsualización de la mina** — en `CamaraCenital.gd` (~línea 869) cambiar:

```gdscript
		var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
```

por:

```gdscript
		var conteo: Dictionary = Recoleccion.detectar_recursos_extraibles(mundo, centro, altura_superficie)
```

- [ ] **Step 3: Tasas al colocar** — eliminar por completo la función `_tasas_de_puesto()` con su comentario (~líneas 1755-1771). En `_procesar_clic_puesto()`, reemplazar la línea

```gdscript
	var tasas_puesto: Dictionary = _tasas_de_puesto(centro, esquina, extremo_agua_indice)
```

por (mismo lugar: ANTES de nivelar/marcar el terreno, porque la mina cuenta los bloques reales del área):

```gdscript
	var centro_agua := Recoleccion.SIN_CENTRO
	if _tipo_puesto_activo == "pesca_frutos_mar":
		var celdas_extremo_pesca := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
		@warning_ignore("integer_division")
		centro_agua = esquina + celdas_extremo_pesca[celdas_extremo_pesca.size() / 2]
	var entorno_puesto: Dictionary = Recoleccion.entorno_de_puesto(_tipo_puesto_activo, mundo, centro, mundo.altura_en(centro.x, centro.y), centro_agua)
	var tasas_puesto: Dictionary = Recoleccion.tasas_de_entorno(_tipo_puesto_activo, mundo, entorno_puesto)
```

Y en la llamada de registro (~línea 1904) cambiar:

```gdscript
	Economia.registrar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo, tasas_puesto)
```

por:

```gdscript
	Economia.registrar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo, tasas_puesto, entorno_puesto)
```

- [ ] **Step 4: Verificar que no queda ningún uso de `_tasas_de_puesto`**

Run (Grep): `_tasas_de_puesto` en `godot/scripts`.
Expected: sin resultados.

- [ ] **Step 5: Verificar que `Main.tscn` carga sin errores**

Run: `"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"`
Expected: sin salida.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CamaraCenital.gd godot/scripts/Main.gd
git commit -m "feat: la cenital registra el entorno de cada puesto y Economia recibe el mundo" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: `Ciudad` — topes del inventario, baúles y horas de juego

**Files:**
- Modify: `godot/scripts/Ciudad.gd`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Produces: constantes `LIMITE_BASE := 500.0`, `LIMITE_BASE_COMIDA := 5000.0`, `FACTOR_NUCLEO := 2.0`, `BONO_BAUL := 100.0`, `BONO_BAUL_COMIDA := 400.0`, `COMIDA_INICIAL := 1500.0`; `Ciudad.almacen_ampliado: bool`; `ampliar_almacen() -> void` (idempotente); `recalcular_limites() -> void`; `registrar_edificio_residencial(id: int, camas_por_piso: Array, baules: int = 0)`; `horas_juego: int` (sube 1 por `simular_tick`); `Recurso.agregar` ya no reduce la cantidad cuando `cantidad > limite`.

- [ ] **Step 1: Escribir las pruebas** — en `CiudadTest.gd`:

(a) TEST 17: cambiar la línea
`assert(recien_nacida.almacen["comida"].cantidad == recien_nacida.almacen["comida"].limite, "la comida inicial debe ser igual a su límite")` por
`assert(recien_nacida.almacen["comida"].cantidad == recien_nacida.COMIDA_INICIAL, "la comida inicial es COMIDA_INICIAL")`.

(b) TEST 18: reemplazar las tres aserciones finales (`ocho.almacen["tierra"]...` , `cantidad == limite` y `limite > 1000.0`) por:

```gdscript
	assert(ocho.almacen["tierra"].cantidad == 0.0 and ocho.almacen["tierras_raras"].limite == 500.0, "el tope inicial de un recurso es 500")
	assert(ocho.almacen["comida"].cantidad == ocho.COMIDA_INICIAL, "la comida inicial es COMIDA_INICIAL")
	assert(ocho.almacen["comida"].limite == 5000.0, "el tope inicial de comida es 5000")
```

(c) Nueva prueba antes de `Las 21 pruebas` (subir a 22):

```gdscript
	print("\n=== TEST 22: topes iniciales, ampliar_almacen(), bono por baúles y stock que excede el tope ===")
	var lim: Node = CiudadScript.new()
	assert(lim.almacen["piedra"].limite == 500.0 and lim.almacen["comida"].limite == 5000.0)
	lim.ampliar_almacen()
	assert(lim.almacen["piedra"].limite == 1000.0 and lim.almacen["comida"].limite == 10000.0, "declarar el núcleo duplica los topes")
	lim.ampliar_almacen()
	assert(lim.almacen["piedra"].limite == 1000.0, "ampliar_almacen() es idempotente")
	lim.registrar_edificio_residencial(7, [2], 3)
	assert(lim.almacen["piedra"].limite == 1300.0 and lim.almacen["comida"].limite == 11200.0, "3 baúles: +300 (+1200 comida)")
	lim.registrar_edificio_residencial(7, [2], 3)
	assert(lim.almacen["piedra"].limite == 1300.0, "registrar dos veces el mismo edificio no duplica sus baúles")
	lim.registrar_edificio_residencial(8, [1])
	assert(lim.almacen["piedra"].limite == 1300.0, "sin baúles no cambia el tope")
	lim.almacen["piedra"].cantidad = 1250.0
	lim.retirar_edificio_residencial(7)
	assert(lim.almacen["piedra"].limite == 1000.0, "deconstruir el edificio quita su bono")
	assert(lim.almacen["piedra"].cantidad == 1250.0, "el stock que excede el nuevo tope se conserva")
	assert(lim.almacen["piedra"].agregar(50.0) == 0.0 and lim.almacen["piedra"].cantidad == 1250.0, "sin espacio no entra nada y nada se destruye")
	assert(lim.horas_juego == 0)
	lim.simular_tick(0.0)
	lim.simular_tick(0.0)
	assert(lim.horas_juego == 2, "cada tick es una hora de juego")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/CiudadTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error`.

- [ ] **Step 3: Implementar** — en `Ciudad.gd`:

1) Tras `const VELOCIDAD_SUAVIZADO_MORAL := 0.15` agregar:

```gdscript

## Inventario del avatar = almacén central (ver docs/superpowers/specs/
## 2026-09-24-extraccion-fisica-agotamiento-design.md, Sección 6). Al empezar
## la partida los topes son bajos; declarar el núcleo los duplica y cada baúl
## de un edificio residencial posterior suma un bono. Placeholders de balance.
const LIMITE_BASE := 500.0
const LIMITE_BASE_COMIDA := 5000.0
const FACTOR_NUCLEO := 2.0
const BONO_BAUL := 100.0
const BONO_BAUL_COMIDA := 400.0
## Comida con la que empieza la partida: 300 ticks de un avatar (5/h) sin producción.
const COMIDA_INICIAL := 1500.0
```

2) En `Recurso.agregar()`, evitar que un stock por encima del tope (tras deconstruir un edificio con baúles) se reduzca:

```gdscript
	func agregar(monto: float) -> float:
		var espacio_libre: float = max(0.0, limite - cantidad)
		var ingreso_real: float = min(espacio_libre, monto)
		cantidad += ingreso_real
		return ingreso_real
```

3) Reemplazar el diccionario `almacen = {...}` de `_init()` (líneas 175-187) por:

```gdscript
	almacen = {
		"madera": Recurso.new("Madera", 200, LIMITE_BASE),
		"comida": Recurso.new("Comida", COMIDA_INICIAL, LIMITE_BASE_COMIDA),
		"hierro": Recurso.new("Hierro", 50, LIMITE_BASE),
		# Recursos que llegan de los puestos y del avatar: empiezan en 0.
		"tierra": Recurso.new("Tierra", 0, LIMITE_BASE),
		"piedra": Recurso.new("Piedra", 0, LIMITE_BASE),
		"cobre": Recurso.new("Cobre", 0, LIMITE_BASE),
		"carbon": Recurso.new("Carbón", 0, LIMITE_BASE),
		"tierras_raras": Recurso.new("Tierras raras", 0, LIMITE_BASE),
	}
```

4) Tras `var edificios_residenciales: Dictionary = {}` agregar:

```gdscript
## id de edificio residencial -> cantidad de baúles (cada uno suma al tope del
## almacén, ver recalcular_limites()).
var baules_por_edificio: Dictionary = {}
## true desde que se declara el núcleo urbano (duplica los topes).
var almacen_ampliado := false
## Horas de juego transcurridas (1 por simular_tick); reloj de los frutos del avatar.
var horas_juego := 0
```

5) Reemplazar `registrar_edificio_residencial()` y `retirar_edificio_residencial()` por:

```gdscript
func registrar_edificio_residencial(id: int, camas_por_piso: Array, baules: int = 0) -> void:
	edificios_residenciales[id] = camas_por_piso.duplicate()
	baules_por_edificio[id] = baules
	recalcular_limites()
```

```gdscript
func retirar_edificio_residencial(id: int) -> void:
	edificios_residenciales.erase(id)
	baules_por_edificio.erase(id)
	recalcular_limites()


## Se declaró el núcleo urbano: los topes del almacén se duplican. Idempotente.
func ampliar_almacen() -> void:
	almacen_ampliado = true
	recalcular_limites()


## tope = base x (FACTOR_NUCLEO si el núcleo está declarado) + baúles x bono.
## Si el tope baja por debajo del stock (se deconstruyó un edificio), el stock
## se conserva y simplemente no entra nada nuevo (ver Recurso.agregar()).
func recalcular_limites() -> void:
	var factor: float = FACTOR_NUCLEO if almacen_ampliado else 1.0
	var baules := 0
	for cantidad in baules_por_edificio.values():
		baules += cantidad
	for clave in almacen:
		var comida: bool = clave == "comida"
		var base: float = LIMITE_BASE_COMIDA if comida else LIMITE_BASE
		var bono: float = BONO_BAUL_COMIDA if comida else BONO_BAUL
		(almacen[clave] as Recurso).limite = base * factor + baules * bono
```

(El comentario doc existente de `retirar_edificio_residencial` se conserva encima de su `func`.)

6) En `simular_tick()`, justo antes de `tick_simulado.emit()` (línea ~448) agregar:

```gdscript
	horas_juego += 1
```

- [ ] **Step 4: Ejecutar y verificar que pasa** (también las escenas que dependen de los topes)

Run:
```bash
for t in CiudadTest EconomiaTest ColonosTest; do echo "== $t"; "$GD" --headless --path godot res://scenes/$t.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"; done
```
Expected: cada una imprime su línea `pasaron correctamente` y nada más. Si `ColonosTest` falla por un tope o una cantidad inicial, ajustar solo esa aserción al nuevo valor (500 / `COMIDA_INICIAL`) y anotarlo en el commit.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/CiudadTest.gd
git commit -m "feat: topes iniciales del inventario, ampliación por núcleo y bono por baúles" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: El núcleo no es habitable; baúles de los edificios residenciales

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd` (`contar_baules`)
- Modify: `godot/scripts/Player.gd` (`_completar_construccion`)
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Produces: `BlueprintValidator.contar_baules(blueprint: Dictionary) -> int` (estático).
- Comportamiento: el primer edificio completado declara el núcleo (`Zonificacion.declarar_nucleo` + `Ciudad.ampliar_almacen()`) y **no** registra camas ni baúles; los siguientes llaman `Ciudad.registrar_edificio_residencial(id, camas_por_piso, baules)`.

- [ ] **Step 1: Escribir la prueba que falla** — insertar en `BlueprintValidatorTest.gd` antes de `Las 63 pruebas` y subir a 64 (mirar cómo TEST 62/63 arman un blueprint válido y reutilizar ese patrón; el blueprint solo necesita `pisos` con `celdas`):

```gdscript
	print("\n=== TEST 64: contar_baules() suma los baúles de todos los pisos ===")
	var bp_baules := {"pisos": [
		{"celdas": {Vector3i(0, 0, 0): "baul", Vector3i(1, 0, 0): "pared", Vector3i(2, 0, 0): "baul"}},
		{"celdas": {Vector3i(0, 0, 0): "baul"}},
	]}
	assert(BlueprintValidator.contar_baules(bp_baules) == 3)
	assert(BlueprintValidator.contar_baules({"pisos": []}) == 0)
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/Test.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error`.

- [ ] **Step 3: Implementar**

En `BlueprintValidator.gd`, justo antes de `validar_camas_y_almacenamiento` (y de su comentario) agregar:

```gdscript
## Cantidad total de baúles de un blueprint, en todos sus pisos. Cada baúl de
## un edificio residencial sube el tope del almacén de la ciudad (ver
## Ciudad.recalcular_limites()).
static func contar_baules(blueprint: Dictionary) -> int:
	var total := 0
	for piso in blueprint["pisos"]:
		for tipo in (piso["celdas"] as Dictionary).values():
			if tipo == "baul":
				total += 1
	return total


```

En `Player.gd`, reemplazar el cuerpo de `_completar_construccion()` (desde `if metadata.is_empty():` hasta el final de la función) por:

```gdscript
	if metadata.is_empty():
		return
	var blueprint: Dictionary = metadata["blueprint"]

	# El primer edificio declarado es el núcleo urbano: no es habitable, así que
	# no suma camas (no llegan colonos todavía) ni baúles al tope del almacén; en
	# cambio, declararlo duplica los topes del inventario.
	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		Ciudad.ampliar_almacen()
		print("Núcleo urbano declarado (no habitable: no llegan colonos todavía). Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max, ". Topes del inventario duplicados.")
		return

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
```

- [ ] **Step 4: Ejecutar y verificar que pasa, y que `Main.tscn` sigue cargando**

Run:
```bash
"$GD" --headless --path godot res://scenes/Test.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"
```
Expected: `=== Las 64 pruebas de BlueprintValidator pasaron correctamente ===` y la segunda sin salida.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd godot/scripts/Player.gd
git commit -m "feat: el primer edificio declarado es el núcleo y no es habitable; baúles suman al tope" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: `ProgresoAccion` y barra de progreso en el HUD

**Files:**
- Create: `godot/scripts/ProgresoAccion.gd`
- Create: `godot/scripts/ExtraccionTest.gd`, `godot/scenes/ExtraccionTest.tscn`
- Modify: `godot/scripts/HUD.gd`

**Interfaces:**
- Produces: `ProgresoAccion` (RefCounted, sin `class_name`; se usa vía `preload().new()`): `avanzar(clave: String, duracion: float, delta: float) -> bool` (true al completar; reinicia el acumulado pero conserva la clave), `soltar() -> void`, `fraccion() -> float`. `HUD.mostrar_progreso(fraccion: float, retrocede: bool = false)` y `HUD.ocultar_progreso()`.
- `ExtraccionTest.gd` empieza aquí con la sección de `ProgresoAccion` y crece en la Tarea 10 (con su línea final `Las N pruebas`).

- [ ] **Step 1: Crear la escena y la prueba que falla**

`godot/scenes/ExtraccionTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ExtraccionTest.gd" id="1"]

[node name="ExtraccionTest" type="Node"]
script = ExtResource("1")
```

`godot/scripts/ExtraccionTest.gd`:

```gdscript
extends Node

## Pruebas aisladas de la extracción del avatar (sub-proyecto 2B): ProgresoAccion,
## tiempos de minado, extraer_por_avatar() y frutos de VoxelWorld. Sin escena de
## juego (mismo patrón que RecoleccionTest.gd). Corre esta escena y revisa que
## no lance ningún assert().

const ProgresoAccionScript = preload("res://scripts/ProgresoAccion.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: ProgresoAccion avanza, se completa y se reinicia ===")
	var progreso: RefCounted = ProgresoAccionScript.new()
	assert(progreso.fraccion() == 0.0)
	assert(not progreso.avanzar("celda:a", 1.0, 0.4))
	assert(is_equal_approx(progreso.fraccion(), 0.4))
	assert(not progreso.avanzar("celda:a", 1.0, 0.4))
	assert(progreso.avanzar("celda:a", 1.0, 0.4), "0.4 + 0.4 + 0.4 >= 1.0 completa")
	assert(progreso.fraccion() == 0.0, "al completar, el avance vuelve a 0")

	print("\n=== TEST 2: cambiar de objetivo o soltar reinicia el avance ===")
	progreso.avanzar("celda:a", 1.0, 0.5)
	assert(not progreso.avanzar("celda:b", 1.0, 0.1), "otro bloque: empieza de cero")
	assert(is_equal_approx(progreso.fraccion(), 0.1))
	progreso.soltar()
	assert(progreso.fraccion() == 0.0)
	assert(not progreso.avanzar("celda:b", 1.0, 0.1))
	assert(is_equal_approx(progreso.fraccion(), 0.1), "tras soltar no se conserva nada")
	assert(progreso.avanzar("arbol:3", 0.0, 0.0), "una duración 0 completa de inmediato, sin dividir por cero")

	print("\n=== Las 2 pruebas de la extracción del avatar pasaron correctamente ===")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/ExtraccionTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error` (falta `ProgresoAccion.gd`).

- [ ] **Step 3: Implementar** — `godot/scripts/ProgresoAccion.gd`:

```gdscript
extends RefCounted

## Avance de una acción sostenida del avatar (minar un bloque, talar, recolectar
## frutos) con reinicio, como Minecraft: si se suelta o se cambia de objetivo,
## el avance vuelve a 0. Puro y sin escena (mismo patrón que
## GeneradorArbol.gd); Player.gd lo usa y HUD.gd dibuja la barra. Sin
## class_name: se usa vía preload().new().

var _clave := ""
var _acumulado := 0.0
var _duracion := 1.0


## Suma "delta" segundos al avance sobre "clave" (p. ej. "celda:(1, 2, 3)" o
## "arbol:7"). Si la clave cambió, empieza de cero. Devuelve true al completarse
## "duracion" y reinicia el acumulado (la clave se conserva, para seguir con el
## mismo árbol).
func avanzar(clave: String, duracion: float, delta: float) -> bool:
	if clave != _clave:
		_clave = clave
		_acumulado = 0.0
	_duracion = duracion
	_acumulado += delta
	if _acumulado >= _duracion:
		_acumulado = 0.0
		return true
	return false


## Se soltó el clic o ya no hay objetivo: el avance se pierde.
func soltar() -> void:
	_clave = ""
	_acumulado = 0.0


## Avance actual entre 0 y 1.
func fraccion() -> float:
	if _duracion <= 0.0:
		return 0.0
	return clampf(_acumulado / _duracion, 0.0, 1.0)
```

En `HUD.gd`: agregar tras `var _panel_puesto: PanelContainer`:

```gdscript
var _barra_progreso: ProgressBar
```

Al final de `_ready()` agregar:

```gdscript
	# Barra de progreso de minar/talar/recolectar/deconstruir, bajo la mira.
	_barra_progreso = ProgressBar.new()
	_barra_progreso.show_percentage = false
	_barra_progreso.set_anchors_preset(Control.PRESET_CENTER)
	_barra_progreso.offset_left = -90
	_barra_progreso.offset_right = 90
	_barra_progreso.offset_top = 40
	_barra_progreso.offset_bottom = 54
	_barra_progreso.visible = false
	add_child(_barra_progreso)
```

Y al final del archivo agregar:

```gdscript


## Muestra la barra de progreso bajo la mira. "retrocede" (tala, deconstrucción)
## la pinta en naranja: indica lo que le queda a lo que se está desmontando.
func mostrar_progreso(fraccion: float, retrocede: bool = false) -> void:
	_barra_progreso.value = clampf(fraccion, 0.0, 1.0) * 100.0
	_barra_progreso.modulate = Color(1.0, 0.6, 0.2) if retrocede else Color(0.4, 1.0, 0.4)
	_barra_progreso.visible = true


func ocultar_progreso() -> void:
	_barra_progreso.visible = false
```

- [ ] **Step 4: Ejecutar y verificar que pasa, y que `Main.tscn` carga**

Run:
```bash
"$GD" --headless --path godot res://scenes/ExtraccionTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"
```
Expected: `=== Las 2 pruebas de la extracción del avatar pasaron correctamente ===` y la segunda sin salida.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ProgresoAccion.gd godot/scripts/ExtraccionTest.gd godot/scenes/ExtraccionTest.tscn godot/scripts/HUD.gd
git commit -m "feat: ProgresoAccion con reinicio y barra de progreso en el HUD" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: Extracción del avatar y frutos en `VoxelWorld`

**Files:**
- Modify: `godot/scripts/Recoleccion.gd` (constantes de tiempos y frutos, `tiempo_minado_de`)
- Modify: `godot/scripts/VoxelWorld.gd` (`es_minable`, `minar_bloque`, `extraer_por_avatar`, frutos)
- Test: `godot/scripts/ExtraccionTest.gd`

**Interfaces:**
- Consumes: `Recoleccion.rendimiento_de`, `mundo.es_terreno_natural`, `mundo.colocado_por_jugador`, `mundo.arboles`, `mundo.generador.densidad_frutal_en`.
- Produces:
  - `Recoleccion.TIEMPO_MINADO`, `TIEMPO_MINADO_DEFECTO := 0.6`, `MULTIPLICADOR_HERRAMIENTA := 1.0`, `TIEMPO_TALA_POR_SALUD := 1.0`, `TIEMPO_RECOLECCION_FRUTOS := 2.0`, `COMIDA_POR_RECOLECCION := 60.0`, `HORAS_REBROTE_FRUTOS := 24`; `tiempo_minado_de(tipo: String) -> float`.
  - `VoxelWorld.es_minable(celda) -> bool`; `extraer_por_avatar(celda) -> Dictionary` (`{}` si no se pudo minar o no rinde: agua, bedrock, edificio, bloque puesto por el jugador; si no `{recurso: unidades}`); `frutos_disponibles(celda, hora: int) -> float`; `recolectar_frutos(celda, hora: int) -> float`.

- [ ] **Step 1: Escribir las pruebas que fallan** — en `ExtraccionTest.gd`: agregar tras `const ProgresoAccionScript`:

```gdscript
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")

## Generador falso: densidad frutal fija, la que se le asigne.
class GeneradorFrutalFalso:
	var densidad := 0.5
	func densidad_frutal_en(_x: int, _z: int) -> float:
		return densidad


func _mundo_nuevo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	mundo.arboles = GeneradorArbolScript.new()
	return mundo
```

Y antes de la línea final (que pasa de `Las 2 pruebas` a `Las 5 pruebas`, TEST 1 a 5):

```gdscript
	print("\n=== TEST 3: tiempo_minado_de() por tipo y multiplicador de herramienta ===")
	assert(Recoleccion.tiempo_minado_de("tierra") < Recoleccion.tiempo_minado_de("piedra"))
	assert(Recoleccion.tiempo_minado_de("piedra") < Recoleccion.tiempo_minado_de("tierras_raras"))
	assert(Recoleccion.tiempo_minado_de("pared") == Recoleccion.TIEMPO_MINADO_DEFECTO * Recoleccion.MULTIPLICADOR_HERRAMIENTA, "tipo sin tabla: tiempo por defecto")
	assert(Recoleccion.MULTIPLICADOR_HERRAMIENTA == 1.0, "sin herramientas todavía")

	print("\n=== TEST 4: extraer_por_avatar() rinde solo por terreno natural ===")
	var mundo: Node = _mundo_nuevo()
	mundo.colocar_bloque(Vector3i(0, 0, 0), "piedra")
	mundo.colocar_bloque(Vector3i(1, 0, 0), "tierra")
	mundo.colocar_bloque(Vector3i(2, 0, 0), "piso")
	mundo.colocar_bloque(Vector3i(3, 0, 0), "piedra", true)  # lo puso el jugador
	mundo.colocar_bloque(Vector3i(4, 0, 0), "pared")
	mundo.celda_a_edificio[Vector3i(4, 0, 0)] = 1  # parte de un edificio
	mundo.colocar_bloque(Vector3i(5, 0, 0), "agua")
	assert(mundo.extraer_por_avatar(Vector3i(0, 0, 0)) == {"piedra": 10.0})
	assert(mundo.obtener_tipo(Vector3i(0, 0, 0)) == "", "el bloque se retiró")
	assert(mundo.extraer_por_avatar(Vector3i(1, 0, 0)) == {"tierra": 1.0})
	assert(mundo.extraer_por_avatar(Vector3i(2, 0, 0)) == {"tierra": 1.0}, "la capa piso cuenta como tierra")
	assert(mundo.extraer_por_avatar(Vector3i(3, 0, 0)).is_empty(), "un bloque del jugador no rinde")
	assert(mundo.obtener_tipo(Vector3i(3, 0, 0)) == "", "pero sí se retira, como siempre")
	assert(not mundo.es_minable(Vector3i(4, 0, 0)) and mundo.extraer_por_avatar(Vector3i(4, 0, 0)).is_empty())
	assert(mundo.obtener_tipo(Vector3i(4, 0, 0)) == "pared", "un edificio no se mina")
	assert(not mundo.es_minable(Vector3i(5, 0, 0)) and mundo.extraer_por_avatar(Vector3i(5, 0, 0)).is_empty(), "el agua no se mina")
	assert(not mundo.es_minable(Vector3i(9, 9, 9)) and mundo.extraer_por_avatar(Vector3i(9, 9, 9)).is_empty(), "el aire tampoco")

	print("\n=== TEST 5: frutos: rinden según la densidad frutal y rebrotan tras HORAS_REBROTE_FRUTOS ===")
	var mundo_f: Node = _mundo_nuevo()
	var generador_f := GeneradorFrutalFalso.new()
	mundo_f.generador = generador_f
	var tronco := Vector3i(10, 5, 10)
	mundo_f.colocar_bloque(tronco, "madera")
	mundo_f.arboles.registrar([tronco], 1)
	assert(is_equal_approx(mundo_f.frutos_disponibles(tronco, 0), Recoleccion.COMIDA_POR_RECOLECCION * 0.5))
	assert(is_equal_approx(mundo_f.recolectar_frutos(tronco, 0), Recoleccion.COMIDA_POR_RECOLECCION * 0.5))
	assert(mundo_f.frutos_disponibles(tronco, 1) == 0.0 and mundo_f.recolectar_frutos(tronco, 1) == 0.0, "recién recolectado: sin frutos")
	assert(mundo_f.obtener_tipo(tronco) == "madera", "recolectar frutos no consume el árbol")
	assert(mundo_f.frutos_disponibles(tronco, Recoleccion.HORAS_REBROTE_FRUTOS - 1) == 0.0)
	assert(mundo_f.frutos_disponibles(tronco, Recoleccion.HORAS_REBROTE_FRUTOS) > 0.0, "rebrota pasadas las horas")
	generador_f.densidad = 0.0
	assert(mundo_f.frutos_disponibles(tronco, 1000) == 0.0, "sin frutales en la zona no hay frutos")
	assert(mundo_f.recolectar_frutos(Vector3i(50, 5, 50), 1000) == 0.0, "una celda sin árbol no da frutos")
```

Y la línea final pasa a: `print("\n=== Las 5 pruebas de la extracción del avatar pasaron correctamente ===")`.

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `"$GD" --headless --path godot res://scenes/ExtraccionTest.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"`
Expected: `SCRIPT ERROR`/`Parse Error`.

- [ ] **Step 3: Implementar**

En `Recoleccion.gd`, tras `RENDIMIENTO_POR_BLOQUE` agregar:

```gdscript

## Segundos que el avatar tarda en minar un bloque por tipo (material real,
## "piso" cuenta como "tierra"), como en Minecraft. Los tipos sin entrada
## (construcciones del jugador) usan TIEMPO_MINADO_DEFECTO. Placeholders.
const TIEMPO_MINADO := {
	"tierra": 0.4, "piedra": 1.2, "carbon": 1.2,
	"hierro": 1.6, "cobre": 1.6, "tierras_raras": 2.4,
}
const TIEMPO_MINADO_DEFECTO := 0.6
## Sin herramientas todavía: cuando existan, dividirá el tiempo de minado.
const MULTIPLICADOR_HERRAMIENTA := 1.0
## Segundos de golpes sostenidos por cada punto de salud (una celda de tronco) de un árbol.
const TIEMPO_TALA_POR_SALUD := 1.0
## Frutos que el avatar recolecta de un árbol (no lo consume): segundos, comida a
## densidad frutal 1.0 y horas de juego que el árbol tarda en volver a dar frutos.
const TIEMPO_RECOLECCION_FRUTOS := 2.0
const COMIDA_POR_RECOLECCION := 60.0
const HORAS_REBROTE_FRUTOS := 24
```

Y tras `rendimiento_de()` agregar:

```gdscript


## Segundos que tarda el avatar en minar un bloque del material "tipo".
func tiempo_minado_de(tipo: String) -> float:
	return TIEMPO_MINADO.get(tipo, TIEMPO_MINADO_DEFECTO) * MULTIPLICADOR_HERRAMIENTA
```

En `VoxelWorld.gd`, reemplazar `minar_bloque()` (con todas sus guardas) por `es_minable()` + `minar_bloque()`:

```gdscript
## true si el avatar puede minar "celda": ni agua, ni "bedrock" (el piso
## absoluto del mundo, inminable a propósito para que nadie cave hasta el
## vacío), ni parte de un edificio, ni una celda vacía.
func es_minable(celda: Vector3i) -> bool:
	var tipo: String = obtener_tipo(celda)
	if tipo == "agua" or tipo == "bedrock":
		return false
	if celda_a_edificio.has(celda):
		return false
	return get_cell_item(celda) != GridMap.INVALID_CELL_ITEM


func minar_bloque(celda: Vector3i) -> bool:
	if not es_minable(celda):
		return false
	_retirar_bloque(celda)
	return true
```

Tras `retirar_bloque_extraido()` (Tarea 4) agregar:

```gdscript


## El avatar termina de minar "celda": la retira y devuelve las unidades que
## rinde ({recurso: unidades}). Solo rinde el terreno natural: un bloque puesto
## por el jugador se retira pero no rinde (colocar es gratis todavía; si
## rindiera, colocar y minar en bucle crearía recursos de la nada). {} si no se
## pudo minar o no rinde.
func extraer_por_avatar(celda: Vector3i) -> Dictionary:
	var natural: bool = es_terreno_natural(celda) and not colocado_por_jugador.has(celda)
	var recurso: String = material_real(obtener_tipo(celda))
	if not minar_bloque(celda):
		return {}
	var unidades: float = Recoleccion.rendimiento_de(recurso)
	if not natural or unidades <= 0.0:
		return {}
	return {recurso: unidades}


## Hora de juego a partir de la cual cada árbol vuelve a dar frutos (id de
## árbol -> hora). Ausente = ya tiene frutos.
var _rebrote_frutos: Dictionary = {}


## Comida que daría recolectar los frutos del árbol de "celda" ahora (0.0 si
## no es un árbol, ya se recolectó hace menos de HORAS_REBROTE_FRUTOS horas, o
## no hay frutales en la zona). Sale de la misma señal de densidad frutal que
## usan los puestos de caza/recolección.
func frutos_disponibles(celda: Vector3i, hora: int) -> float:
	var id: int = arboles.obtener_arbol_de(celda)
	if id == -1 or hora < _rebrote_frutos.get(id, 0):
		return 0.0
	return Recoleccion.COMIDA_POR_RECOLECCION * generador.densidad_frutal_en(celda.x, celda.z)


## Recolecta los frutos del árbol de "celda": devuelve la comida y deja al
## árbol sin frutos HORAS_REBROTE_FRUTOS horas. No consume el árbol.
func recolectar_frutos(celda: Vector3i, hora: int) -> float:
	var comida: float = frutos_disponibles(celda, hora)
	if comida <= 0.0:
		return 0.0
	_rebrote_frutos[arboles.obtener_arbol_de(celda)] = hora + Recoleccion.HORAS_REBROTE_FRUTOS
	return comida
```

- [ ] **Step 4: Ejecutar y verificar que pasa** (y que las pruebas que usan `minar_bloque` siguen igual)

Run:
```bash
for t in ExtraccionTest RecoleccionTest ConstruccionTest; do echo "== $t"; "$GD" --headless --path godot res://scenes/$t.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"; done
```
Expected: cada una imprime su línea `pasaron correctamente` y nada más.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/VoxelWorld.gd godot/scripts/ExtraccionTest.gd
git commit -m "feat: extracción del avatar por bloque natural, tiempos de minado y frutos con rebrote" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 11: `Player` — minar, talar y recolectar frutos con tiempo e indicador

**Files:**
- Modify: `godot/scripts/Player.gd`

**Interfaces:**
- Consumes: `ProgresoAccion` (Tarea 9), `HUD.mostrar_progreso/ocultar_progreso` (Tarea 9), `Recoleccion.tiempo_minado_de/TIEMPO_TALA_POR_SALUD/TIEMPO_RECOLECCION_FRUTOS` y `VoxelWorld.es_minable/extraer_por_avatar/frutos_disponibles/recolectar_frutos` (Tarea 10), `Ciudad.horas_juego` (Tarea 7), `Economia.entregar(carga)` (suma al inventario; lo que no cabe se pierde), `arboles.salud_de/salud_maxima_de` (Tarea 1).
- Comportamiento: mantener el clic izquierdo mina el bloque bajo la mira (barra de avance; al soltar o cambiar de bloque se reinicia); sobre un árbol, tala (la barra muestra la salud restante, el daño se conserva); mantener `E` sobre un árbol recolecta sus frutos; el modo deconstrucción conserva su contador de "sostener" y lo muestra en la barra.

- [ ] **Step 1: Variables y constante** — tras `const INTERVALO_ACCION_REPETIDA := 0.20` (línea 72) actualizar su comentario y agregar el preload; tras `var _temporizador_accion := 0.0` agregar el estado:

Reemplazar el comentario de `INTERVALO_ACCION_REPETIDA` (líneas 70-73) por:

```gdscript
## Intervalo entre repeticiones de colocar (y de deconstruir, con su contador de
## "sostener") mientras se mantiene el click presionado. Minar, talar y recolectar
## frutos ya no repiten: avanzan por tiempo con ProgresoAccion (ver Recoleccion.
## tiempo_minado_de()).
```

Tras esa constante:

```gdscript
const ProgresoAccionScript = preload("res://scripts/ProgresoAccion.gd")
```

Tras `var _temporizador_accion := 0.0`:

```gdscript
var _progreso_accion: RefCounted = ProgresoAccionScript.new()
var _recolectando_frutos := false  # tecla E mantenida
```

- [ ] **Step 2: Entrada** — en `_input()`, tras la línea `if tecla.pressed and tecla.keycode == KEY_K:` y su llamada (`_morir_jugador()`), agregar:

```gdscript
		if tecla.keycode == KEY_E:
			_recolectando_frutos = tecla.pressed
```

Y reemplazar el bloque del botón izquierdo:

```gdscript
		if boton.button_index == MOUSE_BUTTON_LEFT:
			_minando = boton.pressed
			if boton.pressed:
				_temporizador_accion = 0.0
				_minar()
```

por:

```gdscript
		if boton.button_index == MOUSE_BUTTON_LEFT:
			_minando = boton.pressed
			if boton.pressed and modo_deconstruccion:
				_temporizador_accion = 0.0
				_deconstruir()
```

- [ ] **Step 3: Acción sostenida** — reemplazar `_procesar_accion_repetida()` completo (con su comentario) por:

```gdscript
## Mientras el jugador mantiene un botón: E recolecta frutos, el clic izquierdo
## mina/tala (por tiempo) o deconstruye (por repetición, con su contador) y el
## derecho coloca (por repetición). Prioridad frutos > izquierdo > derecho, como
## antes lo era izquierdo > derecho: la intención del jugador en un instante es
## una sola acción. Sin ninguna, el avance se pierde y la barra se oculta.
func _procesar_accion_repetida(delta: float) -> void:
	if _recolectando_frutos:
		_procesar_frutos(delta)
		return
	if _minando:
		_procesar_minado(delta)
		return
	_progreso_accion.soltar()
	hud.ocultar_progreso()
	if not _colocando:
		return
	_temporizador_accion += delta
	if _temporizador_accion < INTERVALO_ACCION_REPETIDA:
		return
	_temporizador_accion = 0.0
	_colocar()


## Guarda en el inventario (= almacén central) lo que rindió una extracción del
## avatar; lo que no cabe por tope lleno se pierde, como las entregas de los acarreadores.
func _guardar_en_inventario(rendido: Dictionary) -> void:
	if rendido.is_empty():
		return
	Economia.entregar(rendido)
	print("Recolectado: ", rendido)


## Un frame de clic izquierdo mantenido: deconstruir (repetición + contador),
## talar (si el objetivo es un árbol) o minar (por tiempo del tipo de bloque).
func _procesar_minado(delta: float) -> void:
	if modo_deconstruccion:
		_temporizador_accion += delta
		if _temporizador_accion >= INTERVALO_ACCION_REPETIDA:
			_temporizador_accion = 0.0
			_deconstruir()
		if _ticks_listo_para_remocion > 0:
			hud.mostrar_progreso(float(_ticks_listo_para_remocion) / TICKS_REMOCION_FINAL, true)
		else:
			hud.ocultar_progreso()
		return
	if not raycast.is_colliding() or mundo == null:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var celda := _celda_impactada()
	if mundo.TIPOS_ARBOL.has(mundo.obtener_tipo(celda)):
		_procesar_tala(celda, delta)
		return
	if not mundo.es_minable(celda):
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var duracion: float = Recoleccion.tiempo_minado_de(mundo.material_real(mundo.obtener_tipo(celda)))
	if _progreso_accion.avanzar("celda:%s" % celda, duracion, delta):
		_guardar_en_inventario(mundo.extraer_por_avatar(celda))
		_progreso_accion.soltar()
		hud.ocultar_progreso()
	else:
		hud.mostrar_progreso(_progreso_accion.fraccion(), false)


## Talar: cada TIEMPO_TALA_POR_SALUD segundos sostenidos resta 1 de salud al árbol
## y rinde 10 de madera. El daño se conserva al soltar (la salud vive en el árbol);
## la barra muestra la salud que le queda.
func _procesar_tala(celda: Vector3i, delta: float) -> void:
	var id: int = mundo.arboles.obtener_arbol_de(celda)
	if id == -1:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	if _progreso_accion.avanzar("arbol:%d" % id, Recoleccion.TIEMPO_TALA_POR_SALUD, delta):
		var derribado: bool = mundo.talar_bloque_de_arbol(celda, DANO_TALA)
		_guardar_en_inventario({"madera": Recoleccion.rendimiento_de("madera") * DANO_TALA})
		if derribado:
			_progreso_accion.soltar()
			hud.ocultar_progreso()
			return
	hud.mostrar_progreso(float(mundo.arboles.salud_de(id)) / mundo.arboles.salud_maxima_de(id), true)


## Frutos: mantener E sobre un árbol con frutos. No consume el árbol (ver
## VoxelWorld.recolectar_frutos()).
func _procesar_frutos(delta: float) -> void:
	if not raycast.is_colliding() or mundo == null:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var celda := _celda_impactada()
	if mundo.frutos_disponibles(celda, Ciudad.horas_juego) <= 0.0:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var id: int = mundo.arboles.obtener_arbol_de(celda)
	if _progreso_accion.avanzar("frutos:%d" % id, Recoleccion.TIEMPO_RECOLECCION_FRUTOS, delta):
		_guardar_en_inventario({"comida": mundo.recolectar_frutos(celda, Ciudad.horas_juego)})
		_progreso_accion.soltar()
		hud.ocultar_progreso()
	else:
		hud.mostrar_progreso(_progreso_accion.fraccion(), false)
```

- [ ] **Step 4: Deconstrucción** — reemplazar `_minar()` completo:

```gdscript
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
```

por:

```gdscript
## Un intento de deconstrucción sobre el bloque bajo la mira (modo G). Minar y
## talar ahora van por tiempo (ver _procesar_minado()).
func _deconstruir() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	_procesar_deconstruccion(_celda_impactada())
```

Y en el comentario de `_procesar_deconstruccion()`, cambiar "Se llama en cada click/repetición de _minar()" por "Se llama en cada click/repetición de _deconstruir()".

- [ ] **Step 5: Verificar que no queda ninguna referencia a `_minar()` y que todo carga**

Run (Grep): `_minar()` en `godot/scripts/Player.gd`.
Expected: sin resultados (los comentarios que la mencionen se actualizan).

Run:
```bash
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"
for t in PlayerOxigenoTest PlayerNatacionTest ExtraccionTest; do echo "== $t"; "$GD" --headless --path godot res://scenes/$t.tscn --quit-after 60 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"; done
```
Expected: `Main.tscn` sin salida; cada escena de pruebas imprime su línea `pasaron correctamente`.

- [ ] **Step 6: Verificación manual en el editor (Godot 4.7)** — abrir `godot/scenes/Main.tscn` y ejecutar:

1. Mantener clic izquierdo sobre tierra/piedra: la barra verde sube, al llenarse el bloque desaparece y la consola imprime `Recolectado: {...}`; la lista de recursos del HUD sube.
2. Empezar a minar y apuntar a otro bloque (o soltar el clic): la barra se reinicia.
3. Mantener clic sobre un árbol: la barra naranja muestra la salud restante y baja cada segundo; al soltar y volver, el daño se conserva; el árbol cae entero al llegar a 0 y la madera sube.
4. Mantener `E` sobre un árbol: la barra sube y suma comida; repetirlo enseguida en el mismo árbol no da nada (rebrote de 24 h).
5. `G` (deconstrucción) sobre un edificio: la barra naranja avanza con el contador de "sostener".
6. Mirar agua o el cielo con el clic mantenido: no pasa nada ni hay errores en consola.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/Player.gd
git commit -m "feat: el avatar mina, tala y recolecta frutos por tiempo con barra de avance" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 12: Documentación, Excel y cierre

**Files:**
- Create: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md`
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md`
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`
- Modify: `docs/Recursos.xlsx` (hoja `Economia`)
- Modify: `docs/Pendientes y próximos pasos.md`

- [ ] **Step 1: Documento técnico de 2B** — crear el archivo `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md` con el mismo formato que el de 2A (título `# **Documento Técnico de Desarrollo: PoC 5 - Fase 2B - Extracción Física y Agotamiento**`, `**Identificador del Módulo:** POC-05-ECONOMIA-2B`, motor, dependencias, enlace al spec `docs/superpowers/specs/2026-09-24-extraccion-fisica-agotamiento-design.md` y a este plan) y estas secciones, copiando los valores exactos del spec y de este plan:

   - **FASE 1: IDEACIÓN** — 1.1 Objetivo (puestos que consumen el mundo, tasas que se recalculan, recolección del avatar con inventario limitado); decisiones confirmadas con el usuario (2026-09-24): consumo abstracto por tick, rendimiento 10/1/2 y las tres capas extracción → unidad de recurso → construcción, mina desde `GROSOR_TIERRA - 2`, caza/recolección escala con los árboles y no los consume, minado con tiempo y barra de avance, inventario 500/5000 que se duplica con el núcleo y +100/+400 por baúl de un edificio residencial posterior al núcleo, núcleo no habitable, frutos como única comida manual por ahora. 1.2 Fuera de alcance (bomba extractora y petróleo, cobro de construcción, herramientas, caza y pesca manual, indicador para la construcción por fantasmas).
   - **FASE 2: PLANEACIÓN** — 2.1 Arquitectura (los archivos de la tabla "Estructura de archivos" de este plan, una línea por archivo); 2.2 Constantes y placeholders (tabla con `RENDIMIENTO_POR_BLOQUE`, `PROFUNDIDAD_MINIMA_EXTRACCION`, `TICKS_RECALCULO`, topes y bono por baúl, `COMIDA_INICIAL`, tiempos de minado, `TIEMPO_TALA_POR_SALUD`, frutos).
   - **FASE 3: DESARROLLO** — 3.1 Reglas (extracción por hora y bloque en curso; qué consume cada tipo de puesto; recálculo; inventario y núcleo), 3.2 Pruebas (`EconomiaTest`, `RecoleccionTest`, `CiudadTest`, `GeneradorArbolTest`, `BlueprintValidatorTest`, `ExtraccionTest` nueva), 3.3 Verificación manual (la lista del Step 6 de la Tarea 11 más: colocar un maderero y una mina, asignarles recolectores, ver bajar la tasa en el panel al talar/agotar; jugada completa desde la partida vacía hasta la llegada de los primeros colonos con el segundo edificio residencial), 3.4 Supuestos que el usuario puede corregir (rendimiento 10 para todos los sólidos; tiempos, `COMIDA_INICIAL` = 1500, `COMIDA_POR_RECOLECCION`, `HORAS_REBROTE_FRUTOS` y `TICKS_RECALCULO` son placeholders; el avatar rinde más rápido que un recolector, perilla de balance).

- [ ] **Step 2: Ajustar el documento de 2A** — en `## 1.2 Fuera de Alcance / Siguiente`, al inicio del bullet "**2B — extracción física y agotamiento:**" agregar "(**implementado**, ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md`)"; y en `### 3.5`, el último bullet ("La producción usa las tasas tomadas al colocar el puesto…") reemplazarlo por: "Las tasas se guardan al colocar el puesto y se recalculan cada 6 horas de juego según el entorno (fase 2B)."

- [ ] **Step 3: GDD** — en `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`, título de la sección "Área de Acción de los Puestos de Recolección" (línea 66): cambiar "pero sin extracción física de bloques ni agotamiento" por "y consumen de verdad los bloques y árboles de su área (2B)"; en el bullet "Producción y Acarreo (implementado, sub-proyecto 2A)" reemplazar la última oración ("Por ahora no se retiran bloques ni árboles reales ni se agota el entorno (sub-proyecto 2B), y los cupos…") por: "Desde el sub-proyecto 2B las minas y los madereros retiran bloques y árboles reales (solo el subsuelo desde la profundidad 2 en las minas), las tasas de todos los puestos se recalculan cada 6 horas de juego según lo que queda en su área (árboles vivos para caza/recolección y maderero, bloques minerales para la mina, agua conectada para la pesca), y los cupos y la capacidad de carga siguen siendo placeholders de balance."; y en la Fase 1 del roadmap (línea 26, "Génesis y Supervivencia") agregar tras "para saciar su hambre inicial (tasa de 5/h)": "; mina, tala y recolecta frutos con tiempo por bloque, sobre un inventario limitado (500 por recurso, 5000 de comida) que se duplica al declarar el núcleo urbano (no habitable) y crece con los baúles de los edificios residenciales; los primeros colonos llegan con el primer edificio residencial posterior al núcleo". Subir la versión del documento (línea 6) con una entrada breve "3.40 (**Extracción física y agotamiento (2026-09-24)**: …)" siguiendo el formato de las entradas anteriores.

- [ ] **Step 4: Excel (hoja `Economia`)** — con el `python` del repo (openpyxl ya lo usó la hoja `Extraccion`), sin tocar otras hojas:

```bash
python - <<'E'
import openpyxl
wb = openpyxl.load_workbook('docs/Recursos.xlsx')
ws = wb['Economia']
ws['A6'] = 'Límite del stock central (inventario del avatar)'
ws['B6'] = 500
ws['C6'] = 'unidades por recurso al inicio (comida: 5000); ×2 al declarar el núcleo; +100 por baúl (comida +400) de cada edificio residencial posterior al núcleo'
ws['D6'] = 'Ciudad.LIMITE_BASE / LIMITE_BASE_COMIDA / FACTOR_NUCLEO / BONO_BAUL / BONO_BAUL_COMIDA'
ws['B7'] = 1500
ws['C7'] = 'unidades (300 ticks de un avatar sin producción)'
ws['D7'] = 'Ciudad.COMIDA_INICIAL'
for fila in [
    ['Ticks entre recálculos de tasas', 6, 'horas de juego', 'Economia.TICKS_RECALCULO'],
    ['Profundidad mínima de extracción de una mina', 2, 'bloques bajo la superficie natural (GROSOR_TIERRA - 2)', 'Recoleccion.PROFUNDIDAD_MINIMA_EXTRACCION'],
    ['Comida por recolección de frutos (a densidad 1.0)', 60, 'unidades; el árbol no se consume', 'Recoleccion.COMIDA_POR_RECOLECCION'],
    ['Rebrote de frutos', 24, 'horas de juego', 'Recoleccion.HORAS_REBROTE_FRUTOS'],
    ['Tiempo de recolección de frutos', 2, 'segundos', 'Recoleccion.TIEMPO_RECOLECCION_FRUTOS'],
    ['Tiempo de tala por punto de salud', 1, 'segundos', 'Recoleccion.TIEMPO_TALA_POR_SALUD'],
]:
    ws.append(fila)
wb.save('docs/Recursos.xlsx')
E
git status --short docs/Recursos.xlsx
```

Expected: `M docs/Recursos.xlsx` (ya estaba modificado por la hoja `Extraccion`; esto se suma).

- [ ] **Step 5: `docs/Pendientes y próximos pasos.md`** — (este archivo tiene cambios sin commitear del usuario: revisar `git diff` antes; editar sobre el estado actual, no revertir nada). Mover el punto "1. PoC 5, sub-proyecto 2B" a la sección `## Hecho` como `- ~~**PoC 5, sub-proyecto 2B: extracción física y agotamiento** (2026-09-24).~~ Los puestos de mina y maderero consumen bloques y árboles reales, las tasas de todos los puestos se recalculan cada 6 horas de juego según su entorno, y el avatar mina, tala y recolecta frutos con tiempo e indicador de avance sobre un inventario limitado que arranca la partida — ver \`PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md\`.`, y renumerar los puntos restantes de "Ruta a seguir" (2→1, 3→2, …). Actualizar además, en los puntos que mencionan "2B" o "extracción real" (construcción/deconstrucción asistida por NPCs), el texto para decir que ya existe.

- [ ] **Step 6: Verificación final** — ejecutar todas las escenas relacionadas con el cambio:

```bash
for t in Test GeneradorArbolTest RecoleccionTest EconomiaTest CiudadTest ColonosTest ExtraccionTest ConstruccionTest ZonificacionTest; do echo "== $t"; "$GD" --headless --path godot res://scenes/$t.tscn --quit-after 300 2>&1 | grep -E "pasaron correctamente|Assertion|SCRIPT ERROR|Parse Error"; done
"$GD" --headless --path godot res://scenes/Main.tscn --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Assertion|Invalid|Node not found"
```

Expected: cada escena imprime su línea `pasaron correctamente` y nada con `Assertion`/`SCRIPT ERROR`/`Parse Error`; `Main.tscn` sin salida. Completar la verificación manual de la Tarea 11 (Step 6) y anotar el resultado en el documento de 2B.

- [ ] **Step 7: Commit** (sin `docs/Pendientes y próximos pasos.md` si aún tiene cambios previos del usuario sin resolver; en ese caso dejarlo sin commitear y avisar)

```bash
git add "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md" "Documento de Diseño de Juego (GDD)_ Craft to Nation.md" docs/Recursos.xlsx
git commit -m "docs: documentar la extracción física y el agotamiento (2B)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

**Cobertura del spec:** §2 modelo de recursos → T2 (tabla) + Excel (ya hecho) + T12; §3 extracción de puestos → T3 (selección, entorno) + T4 (consumo, agotamiento, bloque en curso, mina desde profundidad 2, maderero por salud, caza/pesca sin consumo); §4 recálculo → T5 + T6 (entorno y `Economia.mundo`); §5 avatar → T9 (indicador), T10 (extracción, frutos, tiempos), T11 (minado/tala/frutos/deconstrucción); §6 inventario y arranque → T7 (topes, baúles, `horas_juego`) + T8 (núcleo sin camas, baúles del núcleo excluidos); §8 pruebas → una por tarea; §9 documentación → T12.

**Placeholders:** ninguno; las constantes de balance están nombradas y con valor. **Tipos:** `siguiente_bloque_mina`, `entorno_de_puesto`, `tasas_de_entorno`, `factor_arboles`, `SIN_CENTRO`/`SIN_BLOQUE`, `registrar_puesto(..., entorno)`, `extraer_por_avatar`, `frutos_disponibles`/`recolectar_frutos(celda, hora)`, `mostrar_progreso(fraccion, retrocede)` se definen en una tarea y se usan con la misma firma en las siguientes.
