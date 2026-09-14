# Rediseño del Puesto de Pesca — Huella 4x6, Plataforma de Dos Niveles, Radio por Conectividad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redimensionar la huella del puesto de pesca a 4×6, reemplazar su radio de acción circular por un flood-fill de conectividad real de agua (corrigiendo el bug de charcos sueltos dentro del círculo), y agregar una plataforma de dos niveles que distingue visualmente el extremo muelle (agua) del extremo edificio (tierra).

**Architecture:** El flood-fill de conectividad vive en `Recoleccion.gd` (`celdas_agua_conectadas()`), consumido tanto por la señal (`detectar_pesca_frutos_mar()`, que cambia de firma para recibir el `Dictionary` de celdas ya calculado en vez de escanear un círculo por su cuenta) como por el dibujo del radio en `CamaraCenital.gd` (`_actualizar_area_accion_agua()`, misma firma nueva) — un solo cálculo de conectividad por fotograma, consumido dos veces.

**Tech Stack:** Godot 4.7 GDScript, MCP de Godot para verificación headless.

**Spec:** `docs/superpowers/specs/2026-09-14-puesto-pesca-frutos-mar-design.md` (sección "Actualización posterior (2026-09-14) — huella 4×6, plataforma de dos niveles, radio por conectividad real")

## Global Constraints

- `ANCHO_HUELLA_PESCA_FRUTOS_MAR = 4`, `ALTO_HUELLA_PESCA_FRUTOS_MAR = 6` (antes 3×5). `PASO_MUESTREO_PESCA_FRUTOS_MAR` se elimina.
- `Recoleccion.celdas_agua_conectadas(generador, centro_xz, radio) -> Dictionary` (`Vector2i -> true`): flood-fill de 4 direcciones sobre `generador.es_agua_o_rio_en()`, acotado por `radio` (distancia euclidiana desde `centro_xz`), vacío si `centro_xz` no es agua.
- `detectar_pesca_frutos_mar(generador, celdas_agua: Dictionary) -> Dictionary` — nueva firma, ya NO recibe `centro_xz` ni escanea nada por su cuenta.
- `CamaraCenital._actualizar_area_accion_agua(centro: Vector2i, celdas_agua: Dictionary) -> void` — nueva firma, ya NO recibe `radio`.
- `MAX_ANCHO_HUELLA_PUESTO`/`MAX_ALTO_HUELLA_PUESTO` suben de 5 a 6 en `CamaraCenital.gd` (el pool de la huella fantasma debe caber 4×6/6×4).
- Plataforma de dos niveles: mismo bloque `"puesto_pesca"`, 1 nivel (`objetivo+1`) en toda la huella, 2° nivel (`objetivo+2`) SOLO en la mitad de 3 celdas del eje largo más cercana al extremo edificio (la mitad opuesta al índice de `_extremo_agua_de_huella_pesca()`).
- Sin cambios a la validación de extremos (`_eje_largo_pesca_es_z()`/`_celdas_extremo_pesca()`/`_extremo_uniforme_en()`/`_periferia_extremo_es_agua()`/`_extremo_agua_de_huella_pesca()`) — ya generalizada a cualquier tamaño.
- Usa tabulaciones en GDScript. Conserva el español en comentarios, nombres y mensajes de prueba.

---

### Task 1: `Recoleccion.gd` — flood-fill de conectividad y nueva firma de `detectar_pesca_frutos_mar()`

**Files:**
- Modify: `godot/scripts/Recoleccion.gd`
- Test: `godot/scripts/RecoleccionTest.gd`

**Interfaces:**
- Produces: `celdas_agua_conectadas(generador: Object, centro_xz: Vector2i, radio: int) -> Dictionary`, `detectar_pesca_frutos_mar(generador: Object, celdas_agua: Dictionary) -> Dictionary` (firma cambiada) — consumidas por Task 2.
- Consumes: `generador.es_agua_o_rio_en(x,z)`, `generador.densidad_peces_en(x,z)`, `generador.densidad_algas_en(x,z)` (ya existen, Task de la sesión anterior).

- [ ] **Step 1: Redimensionar constantes y eliminar el muestreo por pasos**

```gdscript
const ANCHO_HUELLA_PESCA_FRUTOS_MAR := 4
const ALTO_HUELLA_PESCA_FRUTOS_MAR := 6
```

Eliminar la línea `const PASO_MUESTREO_PESCA_FRUTOS_MAR := 2` (ya no se usa).

- [ ] **Step 2: Escribir las pruebas que fallan (TEST 14/15 reescritas, TEST 17/18 nuevas)**

En `RecoleccionTest.gd`, agregar junto a `GeneradorAguaFalso` un segundo generador falso para probar conectividad:

```gdscript
## Agua conectada: cuadrado 6x6 en x=[0,5], z=[0,5] (36 celdas), más un
## charco de 1 celda en (10,10) SIN conexión con el cuadrado — separado por
## tierra. Sirve para distinguir un escaneo circular simple (que contaría
## el charco si cae dentro del radio) de un flood-fill real (que no debe
## alcanzarlo).
class GeneradorAguaConectadaFalso:
	func es_agua_o_rio_en(x: int, z: int) -> bool:
		if x == 10 and z == 10:
			return true
		return x >= 0 and x <= 5 and z >= 0 and z <= 5
	func densidad_peces_en(_x: int, _z: int) -> float:
		return 1.0
	func densidad_algas_en(_x: int, _z: int) -> float:
		return 1.0
```

Reemplazar el cuerpo de TEST 14 y TEST 15 (localizar por su `print("\n=== TEST 14: ...")`/`print("\n=== TEST 15: ...")` actuales) por:

```gdscript
	print("\n=== TEST 14: detectar_pesca_frutos_mar() promedia exactamente las celdas del Dictionary recibido ===")
	var generador_agua := GeneradorAguaFalso.new()
	var celdas_prueba: Dictionary = {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true}
	var promedios_pesca: Dictionary = Recoleccion.detectar_pesca_frutos_mar(generador_agua, celdas_prueba)
	print("Promedios (3 celdas dadas): ", promedios_pesca)
	assert(is_equal_approx(promedios_pesca["peces"], 0.5))
	assert(is_equal_approx(promedios_pesca["algas"], 0.3))
	print("OK: detectar_pesca_frutos_mar() promedia exactamente las celdas del Dictionary recibido, sin escanear nada por su cuenta.")

	print("\n=== TEST 15: detectar_pesca_frutos_mar() con un Dictionary vacío da 0.0/0.0 ===")
	var promedios_sin_agua: Dictionary = Recoleccion.detectar_pesca_frutos_mar(generador_agua, {})
	assert(is_equal_approx(promedios_sin_agua["peces"], 0.0))
	assert(is_equal_approx(promedios_sin_agua["algas"], 0.0))
	print("OK: sin ninguna celda de agua, ambas señales devuelven 0.0 sin dividir por cero.")
```

Insertar, después de TEST 16 (`tasas_pesca_frutos_mar()`, sin cambios) y antes de la línea final `print("\n=== Las 16 pruebas...")`:

```gdscript
	print("\n=== TEST 17: celdas_agua_conectadas() sigue solo agua conectada por adyacencia, ignora un charco aislado dentro del mismo radio ===")
	var generador_conectada := GeneradorAguaConectadaFalso.new()
	var celdas: Dictionary = Recoleccion.celdas_agua_conectadas(generador_conectada, Vector2i(0, 0), 25)
	assert(celdas.size() == 36)
	for x in range(6):
		for z in range(6):
			assert(celdas.has(Vector2i(x, z)))
	assert(not celdas.has(Vector2i(10, 10)))
	print("OK: celdas_agua_conectadas() encontró las 36 celdas del cuadrado conectado e ignoró el charco aislado en (10,10).")

	print("\n=== TEST 18: celdas_agua_conectadas() nunca sale del radio, aunque el agua siga conectada más allá ===")
	var generador_infinita := GeneradorAguaFalso.new()
	var celdas_acotadas: Dictionary = Recoleccion.celdas_agua_conectadas(generador_infinita, Vector2i(0, 0), 5)
	assert(celdas_acotadas.size() > 0)
	for xz in celdas_acotadas:
		assert(Vector2(xz).length() <= 5.0)
	print("OK: celdas_agua_conectadas() respeta el radio como tope, aunque el agua siga conectada más allá (GeneradorAguaFalso es infinito en x>=0).")

	print("\n=== Las 18 pruebas de Recoleccion pasaron correctamente ===")
```

Y eliminar la línea anterior `print("\n=== Las 16 pruebas de Recoleccion pasaron correctamente ===")` (queda reemplazada por la de arriba).

- [ ] **Step 2b: Confirmar que las pruebas nuevas fallan**

Run `RecoleccionTest.tscn` vía `mcp__godot__run_project`/`get_debug_output`/`stop_project`. Esperado: `Invalid call`/`Invalid argument` en `celdas_agua_conectadas()` (no existe) y en la nueva firma de `detectar_pesca_frutos_mar()` (todavía espera `Vector2i`, no `Dictionary`).

- [ ] **Step 3: Implementar `celdas_agua_conectadas()` y la nueva `detectar_pesca_frutos_mar()`**

Reemplazar la función `detectar_pesca_frutos_mar()` actual (la que escanea un círculo con `PASO_MUESTREO_PESCA_FRUTOS_MAR`) y agregar la función nueva antes de ella:

```gdscript
## Flood-fill acotado: todas las celdas de agua (mar/lago/río, ver
## GeneradorMundo.es_agua_o_rio_en()) alcanzables desde "centro_xz"
## siguiendo solo adyacencia real (4 direcciones), sin nunca salir del
## círculo de radio "radio". Devuelve un Dictionary (Vector2i -> true) para
## membresía O(1) — usado tanto por el círculo visual
## (CamaraCenital._actualizar_area_accion_agua()) como por
## detectar_pesca_frutos_mar(), para que ambos vean exactamente el mismo
## conjunto de celdas. Vacío si "centro_xz" mismo no es agua.
func celdas_agua_conectadas(generador: Object, centro_xz: Vector2i, radio: int) -> Dictionary:
	var visitadas: Dictionary = {}
	if not generador.es_agua_o_rio_en(centro_xz.x, centro_xz.y):
		return visitadas
	var pendientes: Array[Vector2i] = [centro_xz]
	visitadas[centro_xz] = true
	var direcciones := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not pendientes.is_empty():
		var actual: Vector2i = pendientes.pop_back()
		for dir in direcciones:
			var vecino: Vector2i = actual + dir
			if visitadas.has(vecino):
				continue
			if Vector2(vecino - centro_xz).length() > radio:
				continue
			if not generador.es_agua_o_rio_en(vecino.x, vecino.y):
				continue
			visitadas[vecino] = true
			pendientes.append(vecino)
	return visitadas


## Promedia densidad_peces_en()/densidad_algas_en() sobre "celdas_agua" (ver
## celdas_agua_conectadas()) — ya NO escanea un círculo por su cuenta.
## Devuelve ambas claves en 0.0 si "celdas_agua" está vacío (evita dividir
## por cero).
func detectar_pesca_frutos_mar(generador: Object, celdas_agua: Dictionary) -> Dictionary:
	var suma_peces := 0.0
	var suma_algas := 0.0
	for xz in celdas_agua:
		suma_peces += generador.densidad_peces_en(xz.x, xz.y)
		suma_algas += generador.densidad_algas_en(xz.x, xz.y)
	var muestras: int = celdas_agua.size()
	if muestras == 0:
		return {"peces": 0.0, "algas": 0.0}
	return {"peces": suma_peces / muestras, "algas": suma_algas / muestras}
```

`tasas_pesca_frutos_mar()` no cambia.

- [ ] **Step 4: Ejecutar `RecoleccionTest.tscn` y confirmar que las 18 pruebas pasan**

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/RecoleccionTest.gd
git commit -m "feat: radio de pesca por conectividad real (celdas_agua_conectadas), huella 4x6"
```

---

### Task 2: `CamaraCenital.gd` — huella 4x6, pool de huella más grande, radio por conectividad, plataforma de dos niveles

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes (deben existir ya, Task 1 fusionada): `Recoleccion.celdas_agua_conectadas()`, `Recoleccion.detectar_pesca_frutos_mar(generador, celdas_agua: Dictionary)`, `Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR = 4`, `Recoleccion.ALTO_HUELLA_PESCA_FRUTOS_MAR = 6`.
- No produce interfaces nuevas para otras tasks.

Sin prueba GDScript nueva: mismo precedente ya establecido (ninguna validación/dibujo de `CamaraCenital.gd` tiene prueba unitaria en este proyecto) — verificado por carga headless de `Main.tscn` y jugando en vivo.

- [ ] **Step 1: `MAX_ANCHO_HUELLA_PUESTO`/`MAX_ALTO_HUELLA_PUESTO` de 5 a 6**

```gdscript
const MAX_ANCHO_HUELLA_PUESTO := 6
const MAX_ALTO_HUELLA_PUESTO := 6
```

(Único cambio en `_crear_huella_puesto()` — el pool pasa de 25 a 36 planos fantasma, sin más lógica nueva.)

- [ ] **Step 2: `_actualizar_area_accion_agua()` — nueva firma por conectividad**

Reemplazar la función completa:

```gdscript
## Igual que _actualizar_area_accion(), pero en vez de un radio geométrico
## simple, muestra un plano solo si su celda absoluta está en "celdas_agua"
## (ver Recoleccion.celdas_agua_conectadas()) — exclusivo de
## "pesca_frutos_mar". Reutiliza el mismo pool _area_accion/_offsets_area_accion.
func _actualizar_area_accion_agua(centro: Vector2i, celdas_agua: Dictionary) -> void:
	for i in range(_offsets_area_accion.size()):
		var offset: Vector2i = _offsets_area_accion[i]
		var plano: MeshInstance3D = _area_accion[i]
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		if not celdas_agua.has(Vector2i(x, z)):
			plano.visible = false
			continue
		var altura_celda: int = mundo.altura_en(x, z, true)
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE_AREA_ACCION, z + DESF)
		plano.visible = true
```

- [ ] **Step 3: Rama de pesca en `_actualizar_previsualizacion_puesto()` — calcular conectividad una vez, pasarla a ambas llamadas**

Localizar la rama `elif _tipo_puesto_activo == "pesca_frutos_mar":` (dentro del `if/elif` de ficha/radio) y reemplazarla por:

```gdscript
elif _tipo_puesto_activo == "pesca_frutos_mar":
	if extremo_agua_indice != -1:
		var celdas_extremo := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
		@warning_ignore("integer_division")
		var centro_agua := esquina + celdas_extremo[celdas_extremo.size() / 2]
		var celdas_agua: Dictionary = Recoleccion.celdas_agua_conectadas(mundo.generador, centro_agua, Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)
		var promedios: Dictionary = Recoleccion.detectar_pesca_frutos_mar(mundo.generador, celdas_agua)
		var tasas_pesca: Dictionary = Recoleccion.tasas_pesca_frutos_mar(promedios)
		hud.actualizar_tasas_pesca(tasas_pesca)
		_actualizar_area_accion_agua(centro_agua, celdas_agua)
	else:
		hud.actualizar_tasas_pesca({})
		_ocultar_area_accion()
```

(La única diferencia con la versión actual: antes `centro_agua` se pasaba directo a `detectar_pesca_frutos_mar()` y a `_actualizar_area_accion_agua(centro_agua, Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)`; ahora se calcula `celdas_agua` una sola vez con `celdas_agua_conectadas()` y se reutiliza en ambas llamadas.)

- [ ] **Step 4: Plataforma de dos niveles en `_procesar_clic_puesto()`**

Después del bucle existente que coloca `bloque_marcador` en toda la huella a `objetivo + 1` (el que llena `celdas_puesto`) y ANTES de `mundo.registrar_edificio(celdas_puesto)`, agregar:

```gdscript
if _tipo_puesto_activo == "pesca_frutos_mar":
	var eje_z := _eje_largo_pesca_es_z(_ancho_puesto_activo, _alto_puesto_activo)
	var largo: int = _alto_puesto_activo if eje_z else _ancho_puesto_activo
	@warning_ignore("integer_division")
	var mitad: int = largo / 2
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			var l: int = dz if eje_z else dx
			var es_mitad_edificio: bool = (l >= mitad) if extremo_agua_indice == 0 else (l < mitad)
			if es_mitad_edificio:
				var celda_slab := Vector3i(esquina.x + dx, objetivo + 2, esquina.y + dz)
				mundo.colocar_bloque(celda_slab, bloque_marcador)
				celdas_puesto.append(celda_slab)
```

Nota: en este punto de la función, `bloque_marcador` ya vale `"puesto_pesca"` (asignado más arriba, sin cambios) y `extremo_agua_indice` ya es 0 o 1 (validado al inicio de la función, con `return` temprano si fuera -1).

- [ ] **Step 5: Verificar que `Main.tscn` carga sin errores nuevos**

Run `mcp__godot__run_project` con `Main.tscn`, esperar ~30-40s, `get_debug_output`, `stop_project`. Esperado: solo las advertencias preexistentes de UID/colisión de nombre de clase global.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: huella 4x6, pool de huella a 6x6, y plataforma de dos niveles del puesto de pesca"
```

---

## Verificación manual final (no automatizable, jugando en el editor real)

Colocar un puesto de pesca junto a la costa: confirmar que la huella es 4×6
y que rotar con `Ctrl`+rueda sigue funcionando en las 4 orientaciones;
confirmar que el círculo de acción ya NO se dibuja sobre charcos de agua
sueltos/desconectados (comparar con la captura del bug original); confirmar
que al confirmar la colocación, la mitad del extremo edificio queda con una
plataforma visiblemente más alta (2 niveles) que la mitad del extremo
muelle (1 nivel); confirmar que las señales de pesca/frutos del mar en la
ficha del HUD solo reaccionan a agua realmente conectada.
