# Niveles de puesto y empleo por tipo — Plan de implementación

> **Para agentes:** SUB-SKILL REQUERIDA: usar superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea por tarea. Los pasos usan casillas (`- [ ]`) para el seguimiento.

**Meta:** Que los 4 puestos de recolección tengan niveles 1–3 derivados de quién trabaja en ellos, y que el panel del puesto permita contratar obreros, técnicos y especialistas por separado; la tarjeta de la mina muestra los recursos por nivel.

**Arquitectura:** `Recoleccion` (autoload) gana los ayudantes de nivel (radio, profundidad, multiplicador, entorno por nivel, franjas de la mina). `Economia` guarda por puesto su `nivel` y el `rango` de cada recolector, deriva el nivel del rango mínimo, decide a quién admite y aplica el agotamiento «a su nivel». `Colonos.contratar` acepta los oficios `tecnico` y `especialista`, `PanelPuesto` muestra una fila por oficio y `HUD` muestra las franjas de la mina.

**Tecnología:** Godot 4.7, GDScript (tabulaciones), pruebas `*Test.tscn` headless.

**Especificación:** `docs/superpowers/specs/2026-10-02-niveles-de-puesto-empleo-por-tipo-design.md`

## Restricciones globales

- Rangos de oficio: obrero = 1, técnico = 2, especialista = 3. Nivel del puesto = rango mínimo entre sus **recolectores** (los acarreadores no cuentan); sin recolectores conserva su último nivel, que parte en 1.
- Se admite un oficio de rango igual o superior al nivel; estando agotado a su nivel, solo rangos superiores.
- Tienen niveles solo `mina`, `maderero`, `caza_recoleccion` y `pesca_frutos_mar` (`Recoleccion.TIPOS_CON_NIVELES`). Refinerías, aserradero, carbonera y escuela no cambian.
- Mina: profundidad 0–8 / 8–16 / 16–24 (`PROFUNDIDAD_MINA_NIVEL_1/2/3`), sin multiplicador de velocidad. Caza, maderero y pesca: radio base ×1 / ×1,5 / ×2 (`int(radio * (1 + 0,5 * (nivel - 1)))`: 12→18→24 y 25→37→50) y velocidad ×1 / ×1,5 / ×2.
- El área de trabajo es acumulada (nivel N = franjas 1..N); las franjas por separado solo se muestran en la tarjeta de la mina (se omiten los recursos con menos de 0,3/h).
- Contratar o despedir recalcula el nivel y, si cambia, las tasas y el agotamiento al instante.
- Español en notificaciones, comentarios y pruebas; tabulaciones en GDScript; no tocar `.godot/`.
- Trabajo en una rama aislada (p. ej. `feat/niveles-puesto`) que se fusiona a `main` al final, no directamente sobre `main`.
- Ejecución de pruebas headless (ver memoria del proyecto): `GODOT` es el ejecutable de Godot 4.7; envolver en timeout porque la escena nunca termina sola, y revisar la salida completa: `timeout -k 5 60 "$GODOT" --headless --path godot scenes/EconomiaTest.tscn > salida.txt 2>&1; grep -nE "Assertion failed|SCRIPT ERROR|pasaron" salida.txt`. Un `assert()` fallido no detiene la ejecución: la línea final de éxito no basta. En un worktree nuevo hace falta antes una pasada de importación: `"$GODOT" --headless --editor --path godot --quit`.

## Foco de revisión

- Despedir al último recolector de un puesto de nivel 2 o 3 lo deja en ese nivel (no vuelve a admitir obreros). Lo fija la prueba 31.
- Un maderero colocado donde no había árboles (`arboles_ref` = 0) que sube de nivel y tiene árboles en el anillo nuevo debe empezar a producir. Prueba 30.
- El botón «−» de la fila Técnicos no debe despedir a un obrero, ni el de Obreros a un técnico (`ultimo_de` por oficio). Prueba 32.
- Un especialista o técnico despedido o liberado por agotamiento sigue siendo de su tipo (no vuelve a «desempleado»). Prueba 47 de Colonos.
- Una contratación rechazada por nivel no toca la demografía ni el tipo del colono candidato. Prueba 47 de Colonos.

## Estructura de archivos

- `godot/scripts/Recoleccion.gd` — ayudantes de nivel, `entorno_de_nivel`, `tasas_mina_por_nivel`, `tasas_de_entorno` con parámetro `nivel`, radios parametrizables en `detectar_fauna_frutal`/`detectar_arbol`.
- `godot/scripts/Economia.gd` — nivel, rangos, admisión, agotamiento por nivel, multiplicador de velocidad, `ultimo_de` por oficio.
- `godot/scripts/Colonos.gd` — `contratar` con `especialista`, `especialistas_libres`, `_quedar_sin_puesto` conserva al especialista.
- `godot/scripts/PanelPuesto.gd` — una fila por oficio, nivel en el título, libres por fila.
- `godot/scripts/HUD.gd` y `godot/scripts/CamaraCenital.gd` — tarjeta de la mina por nivel.
- Pruebas: `EconomiaTest.gd` (30–33), `ColonosTest.gd` (47), `HUDTest.gd` (panel con niveles, tarjeta de la mina y ajuste de la prueba 7).
- Documentación: `docs/Pendientes y próximos pasos.md`, el documento técnico de PoC 5 (Fase 2A), `docs/ideas-backlog.md` y una corrección menor de la especificación.

---

### Tarea 1: Ayudantes de nivel en `Recoleccion`

**Archivos:**
- Modificar: `godot/scripts/Recoleccion.gd` (constantes tras la línea 17; `detectar_fauna_frutal` ~292; `detectar_arbol` ~324; `tasas_de_entorno` ~477; funciones nuevas)
- Prueba: `godot/scripts/EconomiaTest.gd` (TEST 30, antes de la línea final «Las 29 pruebas…»)

**Interfaces:**
- Produce (todas en el autoload `Recoleccion`):
  - `const TIPOS_CON_NIVELES: Array`, `const MULTIPLICADOR_NIVEL: Dictionary`.
  - `radio_de_nivel(radio_base: int, nivel: int) -> int`.
  - `profundidad_de_nivel(nivel: int) -> int`.
  - `multiplicador_de_nivel(tipo: String, nivel: int) -> float`.
  - `entorno_de_nivel(tipo: String, mundo: Object, entorno: Dictionary, nivel: int) -> Dictionary` (copia, idempotente).
  - `tasas_mina_por_nivel(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Array` (3 diccionarios de tasas por trabajador, uno por franja).
  - `tasas_de_entorno(tipo, mundo, entorno, nivel: int = 1) -> Dictionary` (parámetro nuevo opcional).
  - `detectar_fauna_frutal(generador, centro_xz, radio: int = RADIO_AREA_CAZA_RECOLECCION)` y `detectar_arbol(generador, centro_xz, radio: int = RADIO_AREA_MADERERO)`.

- [ ] **Paso 1: Escribir la prueba que falla**

En `EconomiaTest.gd`, justo antes de `print("\n=== Las 29 pruebas de Economia pasaron correctamente ===")`, agregar (y cambiar esa línea final a «Las 30 pruebas…»):

```gdscript
	print("\n=== TEST 30: niveles — radios, profundidades, multiplicadores, entorno por nivel y franjas de la mina ===")
	assert(Recoleccion.radio_de_nivel(12, 1) == 12 and Recoleccion.radio_de_nivel(12, 2) == 18 and Recoleccion.radio_de_nivel(12, 3) == 24)
	assert(Recoleccion.radio_de_nivel(25, 2) == 37 and Recoleccion.radio_de_nivel(25, 3) == 50)
	assert(Recoleccion.profundidad_de_nivel(1) == 8 and Recoleccion.profundidad_de_nivel(2) == 16 and Recoleccion.profundidad_de_nivel(3) == 24)
	assert(Recoleccion.multiplicador_de_nivel("mina", 3) == 1.0, "la mina no gana velocidad")
	assert(Recoleccion.multiplicador_de_nivel("maderero", 2) == 1.5 and Recoleccion.multiplicador_de_nivel("pesca_frutos_mar", 3) == 2.0)
	assert(Recoleccion.multiplicador_de_nivel("maderero", 1) == 1.0)
	var mundo30 := MundoBosqueFalso.new()
	for i in range(1, 5):
		mundo30.arboles.registrar([Vector3i(i, 5, i)], 3)
	mundo30.arboles.registrar([Vector3i(15, 5, 0)], 3)  # a 15 celdas: fuera del radio 12, dentro del 18
	var entorno30: Dictionary = Recoleccion.entorno_de_puesto("maderero", mundo30, Vector2i(0, 0), 5)
	assert(entorno30["radio_arboles"] == 12 and entorno30["arboles_ref"] == 4)
	var nivel2_30: Dictionary = Recoleccion.entorno_de_nivel("maderero", mundo30, entorno30, 2)
	assert(nivel2_30["radio_arboles"] == 18 and nivel2_30["arboles_ref"] == 5, "el anillo nuevo suma su árbol a la referencia")
	assert(Recoleccion.entorno_de_nivel("maderero", mundo30, nivel2_30, 2) == nivel2_30, "es idempotente")
	assert(entorno30["radio_arboles"] == 12, "no toca el entorno original")
	# Un maderero colocado sin árboles (referencia 0) empieza a producir al subir si el anillo nuevo tiene árboles.
	var mundo30b := MundoBosqueFalso.new()
	mundo30b.arboles.registrar([Vector3i(15, 5, 0)], 3)
	var vacio30: Dictionary = Recoleccion.entorno_de_puesto("maderero", mundo30b, Vector2i(0, 0), 5)
	assert(vacio30["arboles_ref"] == 0 and Recoleccion.tasas_de_entorno("maderero", mundo30b, vacio30)["madera"] == 0.0)
	var sube30: Dictionary = Recoleccion.entorno_de_nivel("maderero", mundo30b, vacio30, 2)
	assert(sube30["arboles_ref"] == 1 and Recoleccion.tasas_de_entorno("maderero", mundo30b, sube30, 2)["madera"] > 0.0)
	# Franjas de la mina: el hierro de la veta (y=7) queda a 21-22 de profundidad con altura 28 (solo franja del nivel 3) y a 3-4 con altura 10 (solo nivel 1).
	var franjas30: Array = Recoleccion.tasas_mina_por_nivel(_mundo_con_veta(), Vector2i(500, 500), 28)
	assert(franjas30.size() == 3 and franjas30[0].is_empty() and franjas30[1].is_empty(), "a 21-22 de profundidad: solo la franja del nivel 3")
	assert(is_equal_approx(franjas30[2]["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]))
	var franjas30b: Array = Recoleccion.tasas_mina_por_nivel(_mundo_con_veta(), Vector2i(500, 500), 10)
	assert(franjas30b[0].has("hierro") and franjas30b[1].is_empty() and franjas30b[2].is_empty(), "a 3-4 de profundidad: solo el nivel 1")
```

- [ ] **Paso 2: Ejecutar la prueba y verla fallar**

Ejecutar `scenes/EconomiaTest.tscn` (ver «Restricciones globales»). Esperado: `SCRIPT ERROR` por `radio_de_nivel` inexistente en `Recoleccion`.

- [ ] **Paso 3: Implementar**

En `Recoleccion.gd`, tras `const PROFUNDIDAD_MINA_NIVEL_3 := 24`:

```gdscript
## Puestos de recolección con niveles 1-3 (ver docs/superpowers/specs/2026-10-02-niveles-de-puesto-empleo-por-tipo-design.md).
const TIPOS_CON_NIVELES := ["mina", "maderero", "caza_recoleccion", "pesca_frutos_mar"]
## Velocidad del puesto por nivel. La mina no la usa (ver multiplicador_de_nivel()): su nivel amplía el volumen.
const MULTIPLICADOR_NIVEL := {1: 1.0, 2: 1.5, 3: 2.0}
```

Cambiar la firma y el cuerpo de `detectar_fauna_frutal` para usar un radio (reemplaza las cuatro apariciones de `RADIO_AREA_CAZA_RECOLECCION` dentro de la función):

```gdscript
func detectar_fauna_frutal(generador: Object, centro_xz: Vector2i, radio: int = RADIO_AREA_CAZA_RECOLECCION) -> Dictionary:
	var suma_fauna := 0.0
	var suma_frutal := 0.0
	var muestras := 0
	for dx in range(-radio, radio + 1, PASO_MUESTREO_CAZA_RECOLECCION):
		for dz in range(-radio, radio + 1, PASO_MUESTREO_CAZA_RECOLECCION):
			if Vector2(dx, dz).length() > radio:
				continue
```

(el resto de la función queda igual). Igual con `detectar_arbol`:

```gdscript
func detectar_arbol(generador: Object, centro_xz: Vector2i, radio: int = RADIO_AREA_MADERERO) -> float:
	var suma_arbol := 0.0
	var muestras := 0
	for dx in range(-radio, radio + 1, PASO_MUESTREO_MADERERO):
		for dz in range(-radio, radio + 1, PASO_MUESTREO_MADERERO):
			if Vector2(dx, dz).length() > radio:
				continue
```

Agregar después de `capacidad_almacen_de()`:

```gdscript
## Radio de un puesto de área circular en ese nivel: +50 % del radio base por nivel (12 → 18 → 24; 25 → 37 → 50).
func radio_de_nivel(radio_base: int, nivel: int) -> int:
	return int(radio_base * (1.0 + 0.5 * (nivel - 1)))


## Profundidad acumulada de una mina en ese nivel (nivel 1 si no es 2 ni 3).
func profundidad_de_nivel(nivel: int) -> int:
	match nivel:
		2: return PROFUNDIDAD_MINA_NIVEL_2
		3: return PROFUNDIDAD_MINA_NIVEL_3
	return PROFUNDIDAD_MINA_NIVEL_1


## Multiplicador de velocidad de un puesto en ese nivel: la mina no tiene (1.0).
func multiplicador_de_nivel(tipo: String, nivel: int) -> float:
	if tipo == "mina":
		return 1.0
	return MULTIPLICADOR_NIVEL.get(nivel, 1.0)
```

Agregar tras `entorno_de_puesto()`:

```gdscript
## El entorno de un puesto al nivel "nivel": amplía el radio con que cuenta sus árboles (caza/recolección y
## maderero) y suma a su referencia los árboles vivos del anillo nuevo, para que talar el anillo base siga
## bajando el factor. Devuelve una copia; llamarla otra vez con el mismo nivel no cambia nada.
func entorno_de_nivel(tipo: String, mundo: Object, entorno: Dictionary, nivel: int) -> Dictionary:
	var nuevo: Dictionary = entorno.duplicate()
	if not nuevo.has("radio_arboles"):
		return nuevo
	var base: int = RADIO_AREA_MADERERO if tipo == "maderero" else RADIO_AREA_CAZA_RECOLECCION
	var radio: int = radio_de_nivel(base, nivel)
	if radio <= nuevo["radio_arboles"]:
		return nuevo
	nuevo["arboles_ref"] += arboles_vivos_en(mundo, nuevo["centro"], radio) - arboles_vivos_en(mundo, nuevo["centro"], nuevo["radio_arboles"])
	nuevo["radio_arboles"] = radio
	return nuevo


## Tasas por trabajador de la franja de cada nivel de una mina (la franja del nivel N es lo que añade
## su profundidad sobre la del nivel anterior; no suma los niveles previos): [nivel 1, nivel 2, nivel 3].
func tasas_mina_por_nivel(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Array:
	var niveles: Array = []
	var anterior: Dictionary = {}
	for nivel in range(1, 4):
		var conteo: Dictionary = detectar_recursos_extraibles(mundo, centro_xz, altura_superficie, profundidad_de_nivel(nivel))
		var franja: Dictionary = {}
		for tipo in conteo:
			var nuevos: int = conteo[tipo] - anterior.get(tipo, 0)
			if nuevos > 0:
				franja[tipo] = nuevos
		niveles.append(tasas_recoleccion(franja))
		anterior = conteo
	return niveles
```

Reemplazar `tasas_de_entorno` completa por (mismo comportamiento con `nivel` = 1):

```gdscript
func tasas_de_entorno(tipo: String, mundo: Object, entorno: Dictionary, nivel: int = 1) -> Dictionary:
	var centro: Vector2i = entorno["centro"]
	if tipo == "mina":
		return tasas_recoleccion(detectar_recursos_extraibles(mundo, centro, entorno["altura"], profundidad_de_nivel(nivel)))
	if tipo == "pesca_frutos_mar":
		if not entorno.has("centro_agua"):
			return {}
		var celdas_agua: Dictionary = celdas_agua_conectadas(mundo, entorno["centro_agua"], radio_de_nivel(RADIO_AREA_PESCA_FRUTOS_MAR, nivel))
		return tasas_pesca_frutos_mar(detectar_pesca_frutos_mar(mundo.generador, celdas_agua))
	var tasas: Dictionary
	# Un maderero sin árboles al colocarse no tiene nada que talar (factor_arboles() da 1.0 ahí).
	if tipo == "maderero" and entorno.get("arboles_ref", 0) <= 0:
		return {"madera": 0.0}
	if tipo == "caza_recoleccion":
		tasas = tasas_caza_recoleccion(detectar_fauna_frutal(mundo.generador, centro, radio_de_nivel(RADIO_AREA_CAZA_RECOLECCION, nivel)))
	else:
		tasas = tasa_maderero(detectar_arbol(mundo.generador, centro, radio_de_nivel(RADIO_AREA_MADERERO, nivel)))
	var factor := factor_arboles(mundo, entorno)
	for clave in tasas:
		tasas[clave] *= factor
	# Un maderero por debajo del umbral está agotado: no conserva empleados improductivos.
	if tipo == "maderero" and tasas["madera"] < UMBRAL_AGOTADO_MADERERO:
		tasas["madera"] = 0.0
	return tasas
```

- [ ] **Paso 4: Ejecutar la prueba y verla pasar**

Ejecutar `EconomiaTest.tscn` y `RecoleccionTest.tscn` (los radios por defecto no cambian). Esperado: ningún `Assertion failed` ni `SCRIPT ERROR`; «Las 30 pruebas de Economia pasaron correctamente».

- [ ] **Paso 5: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: ayudantes de nivel de puesto en Recoleccion (radio, profundidad, velocidad, entorno y franjas de mina)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Tarea 2: Nivel, admisión y agotamiento por nivel en `Economia`

**Archivos:**
- Modificar: `godot/scripts/Economia.gd` (`ROLES` línea 46; `registrar_puesto` ~105-119; `asignar`/`roles_de`/`liberar`/`ultimo_de` ~158-199; `produccion_por_hora` ~233; `recalcular_tasas` ~306; `_siguiente_bloque` ~346; `_actualizar_agotamiento` ~709)
- Prueba: `godot/scripts/EconomiaTest.gd` (TESTS 31, 32 y 33)

**Interfaces:**
- Consume: `Recoleccion.TIPOS_CON_NIVELES`, `multiplicador_de_nivel`, `profundidad_de_nivel`, `entorno_de_nivel`, `tasas_de_entorno(..., nivel)` (Tarea 1).
- Produce (en `Economia`):
  - `const RANGO_DE_ROL := {"recolector": 1, "tecnico": 2, "especialista": 3}`.
  - `tiene_niveles(esquina: Vector2i) -> bool`.
  - `nivel_de(esquina: Vector2i) -> int`.
  - `contar_rango(esquina: Vector2i, rango: int) -> int`.
  - `admite_rol(esquina: Vector2i, rol: String) -> bool`.
  - `roles_de` incluye `"especialista"` en los puestos de recolección; `ultimo_de(esquina, rol)` devuelve al último colono de ese **oficio**.
  - Campos `p["nivel"]: int` y `p["rangos"]: Dictionary` (id de recolector → rango) en cada puesto.

- [ ] **Paso 1: Escribir las pruebas que fallan**

En `EconomiaTest.gd`, antes de la línea final (que pasa a decir «Las 33 pruebas…»):

```gdscript
	print("\n=== TEST 31: el nivel del puesto es el rango mínimo de sus recolectores y limita a quién admite ===")
	var e31: Node = _nueva(CiudadScript.new())
	assert(e31.nivel_de(ESQ) == 1 and e31.tiene_niveles(ESQ))
	assert(e31.asignar(ESQ, "recolector", 1) and e31.asignar(ESQ, "tecnico", 2))
	assert(e31.nivel_de(ESQ) == 1, "con un obrero manda el mínimo")
	e31.liberar(1)
	assert(e31.nivel_de(ESQ) == 2, "solo técnicos: nivel 2")
	assert(not e31.asignar(ESQ, "recolector", 3), "un obrero no entra a un puesto de nivel 2")
	assert(e31.asignar(ESQ, "especialista", 4), "un especialista sí")
	assert(e31.nivel_de(ESQ) == 2 and e31.contar_rango(ESQ, 2) == 1 and e31.contar_rango(ESQ, 3) == 1)
	e31.liberar(2)
	assert(e31.nivel_de(ESQ) == 3, "solo especialistas: nivel 3")
	assert(not e31.asignar(ESQ, "tecnico", 5))
	e31.liberar(4)
	assert(e31.nivel_de(ESQ) == 3 and e31.puestos[ESQ]["recolectores"].is_empty(), "sin recolectores conserva su nivel")
	var e31b: Node = _nueva(CiudadScript.new())
	assert(e31b.asignar(ESQ, "especialista", 1) and e31b.nivel_de(ESQ) == 3, "con especialistas desde el inicio arranca en nivel 3")
	var e31c: Node = _con_siderurgica(CiudadScript.new())
	assert(not e31c.tiene_niveles(ESQ_REF) and e31c.nivel_de(ESQ_REF) == 1)
	assert(e31c.asignar(ESQ_REF, "tecnico", 1) and e31c.nivel_de(ESQ_REF) == 1, "una refinería no tiene niveles")
	var e31d: Node = _con_escuela(CiudadScript.new())
	assert(not e31d.asignar(ESQ_ESC, "tecnico", 1) and not e31d.asignar(ESQ_ESC, "especialista", 1), "la escuela solo admite aprendices")

	print("\n=== TEST 32: los acarreadores no cuentan para el nivel; velocidad por nivel; ultimo_de() por oficio ===")
	var e32: Node = _nueva(CiudadScript.new())
	assert(e32.asignar(ESQ, "acarreador", 1) and e32.nivel_de(ESQ) == 1)
	assert(e32.asignar(ESQ, "tecnico", 2) and e32.nivel_de(ESQ) == 2, "el acarreador (obrero) no frena el nivel")
	e32.marcar_presente(2, true)
	assert(is_equal_approx(e32.produccion_por_hora(ESQ)["madera"], 3.0 * 1.5), "nivel 2: velocidad x1,5")
	assert(e32.ultimo_de(ESQ, "tecnico") == 2 and e32.ultimo_de(ESQ, "recolector") == -1 and e32.ultimo_de(ESQ, "acarreador") == 1)
	var e32b: Node = EconomiaScript.new()
	e32b.ciudad = CiudadScript.new()
	e32b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0})
	assert(e32b.asignar(ESQ, "recolector", 1) and e32b.asignar(ESQ, "tecnico", 2))
	assert(e32b.ultimo_de(ESQ, "recolector") == 1 and e32b.ultimo_de(ESQ, "tecnico") == 2, "cada fila despide a los de su oficio")
	e32b.liberar(1)
	e32b.marcar_presente(2, true)
	assert(e32b.nivel_de(ESQ) == 2 and is_equal_approx(e32b.produccion_por_hora(ESQ)["hierro"], 5.0), "la mina no gana velocidad con el nivel")

	print("\n=== TEST 33: agotado a su nivel, el puesto despide a los de rango mínimo y sube con quien queda ===")
	var e33: Node = EconomiaScript.new()
	e33.ciudad = CiudadScript.new()
	e33.mundo = _mundo_con_veta()
	# Con altura 28 el hierro (y=7) queda a 21-22 de profundidad: solo es alcanzable en el nivel 3.
	e33.registrar_puesto(ESQ, "mina", 5, 5, {}, {"centro": Vector2i(500, 500), "altura": 28})
	e33.recalcular_tasas(ESQ)
	assert(e33.puestos[ESQ]["agotado"] and e33.nivel_de(ESQ) == 1)
	assert(not e33.asignar(ESQ, "recolector", 1), "agotado en nivel 1: no entran obreros")
	assert(e33.asignar(ESQ, "tecnico", 2))
	assert(e33.nivel_de(ESQ) == 2 and e33.puestos[ESQ]["agotado"] and e33.puestos[ESQ]["recolectores"].is_empty(), "sube a 2, sigue agotado y despide al técnico")
	assert(not e33.asignar(ESQ, "tecnico", 3), "agotado en nivel 2: solo especialistas")
	assert(e33.asignar(ESQ, "especialista", 4))
	assert(e33.nivel_de(ESQ) == 3 and not e33.puestos[ESQ]["agotado"] and e33.puestos[ESQ]["recolectores"] == [4], "en nivel 3 alcanza el hierro")
	assert(is_equal_approx(e33.puestos[ESQ]["tasas"]["hierro"], Recoleccion.TASAS_BASE_MINERAL["hierro"]))
	# Personal mixto: al agotarse se va el obrero, el especialista se queda y el puesto sube.
	var e33b: Node = EconomiaScript.new()
	e33b.ciudad = CiudadScript.new()
	e33b.mundo = _mundo_con_veta()
	e33b.registrar_puesto(ESQ, "mina", 5, 5, {"hierro": 5.0}, {"centro": Vector2i(500, 500), "altura": 28})
	assert(e33b.asignar(ESQ, "recolector", 1) and e33b.asignar(ESQ, "especialista", 2) and e33b.nivel_de(ESQ) == 1)
	e33b.recalcular_tasas(ESQ)
	assert(e33b.puestos[ESQ]["recolectores"] == [2] and e33b.nivel_de(ESQ) == 3 and not e33b.puestos[ESQ]["agotado"])
```

- [ ] **Paso 2: Ejecutar y ver fallar**

Ejecutar `EconomiaTest.tscn`. Esperado: `SCRIPT ERROR` por `nivel_de`/`tiene_niveles` inexistentes en `Economia`.

- [ ] **Paso 3: Implementar**

En `Economia.gd`:

1. Reemplazar la constante `ROLES` (y su comentario) por:

```gdscript
## "tecnico" opera la receta en las refinerías y, en los puestos de recolección, recolecta como técnico;
## "recolector" (un obrero) y "especialista" solo existen en los puestos de recolección; "aprendiz" solo en las
## escuelas. "acarreador" vale en los puestos de recolección y en las refinerías (ver roles_de()).
const ROLES := ["recolector", "tecnico", "especialista", "aprendiz", "acarreador"]

## Rango de oficio de quien recolecta: es el nivel mínimo de puesto que ocupa (ver nivel_de()). Obrero 1,
## técnico 2, especialista 3.
const RANGO_DE_ROL := {"recolector": 1, "tecnico": 2, "especialista": 3}
```

2. Junto a `var _horas_desde_recalculo := 0` agregar:

```gdscript
## true mientras _actualizar_agotamiento() libera personal y reevalúa el área: evita que cada liberación
## recalcule por su cuenta.
var _recalculando := false
```

3. En `registrar_puesto`, en el diccionario del puesto, tras `"progreso": 0.0, ...` agregar (antes del `}` de cierre):

```gdscript
		"nivel": 1,  # 1-3, solo en los puestos con niveles: rango mínimo de sus recolectores (ver nivel_de())
		"rangos": {},  # id de recolector -> rango de su oficio (RANGO_DE_ROL)
```

4. Reemplazar `asignar` y `roles_de` por:

```gdscript
## Asigna un colono a un puesto con un rol. Falso si el puesto no existe, el
## rol no es válido, el cupo está lleno, el colono ya trabaja en algún puesto o el
## nivel del puesto no admite ese oficio (ver admite_rol()).
func asignar(esquina: Vector2i, rol: String, colono_id: int) -> bool:
	if not puestos.has(esquina) or not roles_de(esquina).has(rol) or _puesto_de.has(colono_id):
		return false  # roles válidos por tipo de puesto: ver roles_de()
	var p: Dictionary = puestos[esquina]
	if not p["activo"] or not admite_rol(esquina, rol):
		return false  # inactivo (se está deconstruyendo) o su nivel no admite ese oficio
	if cupo_libre(esquina) <= 0:
		return false
	p[_lista_de(rol)].append(colono_id)
	_puesto_de[colono_id] = esquina
	if tiene_niveles(esquina) and RANGO_DE_ROL.has(rol):
		p["rangos"][colono_id] = RANGO_DE_ROL[rol]
		_actualizar_nivel(esquina)
	return true


## Roles que admite el puesto: aprendices en una escuela; técnicos y acarreadores en una refinería;
## obreros (recolector), técnicos, especialistas y acarreadores en los demás.
func roles_de(esquina: Vector2i) -> Array:
	if es_escuela(esquina):
		return ["aprendiz"]
	return ["tecnico", "acarreador"] if es_refineria(esquina) else ["recolector", "tecnico", "especialista", "acarreador"]


## true si el puesto tiene niveles (Recoleccion.TIPOS_CON_NIVELES).
func tiene_niveles(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and Recoleccion.TIPOS_CON_NIVELES.has(puestos[esquina]["tipo"])


## Nivel del puesto (1-3): el rango mínimo de sus recolectores; sin recolectores conserva el último (parte en 1).
func nivel_de(esquina: Vector2i) -> int:
	return puestos[esquina]["nivel"] if puestos.has(esquina) else 1


## Recolectores del puesto cuyo oficio tiene ese rango (1 obrero, 2 técnico, 3 especialista).
func contar_rango(esquina: Vector2i, rango: int) -> int:
	if not puestos.has(esquina):
		return 0
	var total := 0
	for r in puestos[esquina]["rangos"].values():
		if r == rango:
			total += 1
	return total


## true si el nivel actual del puesto admite ese oficio: rango igual o superior al nivel y, estando agotado
## a su nivel, solo un rango superior (así un técnico puede reabrir un puesto de obreros agotado). Siempre
## true en los puestos sin niveles y para los acarreadores. No mira el cupo ni si está activo.
func admite_rol(esquina: Vector2i, rol: String) -> bool:
	if not tiene_niveles(esquina) or not RANGO_DE_ROL.has(rol):
		return true
	var p: Dictionary = puestos[esquina]
	var rango: int = RANGO_DE_ROL[rol]
	return rango > p["nivel"] or (rango == p["nivel"] and not p["agotado"])


## Recalcula el nivel como el rango mínimo de los recolectores; sin recolectores lo conserva. Si cambió,
## reevalúa de inmediato el área, las tasas y el agotamiento (salvo dentro de _actualizar_agotamiento()).
func _actualizar_nivel(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	if p["rangos"].is_empty():
		return
	var minimo := 99
	for rango in p["rangos"].values():
		minimo = mini(minimo, rango)
	if minimo == p["nivel"]:
		return
	p["nivel"] = minimo
	if not _recalculando:
		recalcular_tasas(esquina)
```

5. Reemplazar `liberar` y `ultimo_de` por:

```gdscript
## Quita a un colono de su puesto (despido o muerte). No-op si no trabaja.
func liberar(colono_id: int) -> void:
	if not _puesto_de.has(colono_id):
		return
	var esquina: Vector2i = _puesto_de[colono_id]
	var p: Dictionary = puestos[esquina]
	p["recolectores"].erase(colono_id)
	p["acarreadores"].erase(colono_id)
	p["presentes"].erase(colono_id)
	p["rangos"].erase(colono_id)
	if es_escuela(esquina):
		p["progreso"] = 0.0  # si se va un aprendiz, la cohorte empieza de nuevo
	_puesto_de.erase(colono_id)
	if tiene_niveles(esquina):
		_actualizar_nivel(esquina)  # al irse el de rango mínimo, el nivel puede subir


## El último colono asignado con ese rol, o -1: a quien despide el panel. En los puestos con niveles es el
## último con ese oficio (el botón «−» de Técnicos no despide a un obrero).
func ultimo_de(esquina: Vector2i, rol: String) -> int:
	if not puestos.has(esquina):
		return -1
	var p: Dictionary = puestos[esquina]
	var lista: Array = p[_lista_de(rol)]
	if tiene_niveles(esquina) and RANGO_DE_ROL.has(rol):
		for i in range(lista.size() - 1, -1, -1):
			if p["rangos"].get(lista[i], 0) == RANGO_DE_ROL[rol]:
				return lista[i]
		return -1
	return lista.back() if not lista.is_empty() else -1
```

6. En `produccion_por_hora`, sustituir el final del bucle de tasas (dentro del puesto de recolección) por:

```gdscript
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	var multiplicador: float = Recoleccion.multiplicador_de_nivel(p["tipo"], p["nivel"])
	for clave in p["tasas"]:
		var recurso: String = RECURSO_DE_TASA.get(clave, clave)
		resultado[recurso] = resultado.get(recurso, 0.0) + p["tasas"][clave] * presentes * multiplicador
	return resultado
```

7. En `recalcular_tasas`, reemplazar la línea `p["tasas"] = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"])` por:

```gdscript
	p["entorno"] = Recoleccion.entorno_de_nivel(p["tipo"], mundo, p["entorno"], p["nivel"])
	p["tasas"] = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"], p["nivel"])
```

8. En `_siguiente_bloque`, la llamada de la mina pasa a:

```gdscript
		var celda: Vector3i = Recoleccion.siguiente_bloque_mina(mundo, entorno["centro"], entorno["altura"], recurso, Recoleccion.profundidad_de_nivel(p["nivel"]))
```

9. Reemplazar `_actualizar_agotamiento` por:

```gdscript
## Un puesto sin ninguna tasa positiva está agotado a su nivel actual: pierde a los recolectores de rango
## mínimo (y a sus acarreadores en cuanto su almacén local se vacía). Si quien queda tiene un rango mayor,
## el nivel sube, el área crece y se reevalúa el agotamiento; así hasta el nivel 3.
func _actualizar_agotamiento(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	p["agotado"] = _sin_tasas(p["tasas"])
	if p["agotado"]:
		_recalculando = true
		while p["agotado"]:
			var nivel_previo: int = p["nivel"]
			_liberar_de(esquina, _recolectores_de_rango(p, nivel_previo))
			if p["nivel"] == nivel_previo:
				break  # nadie más sube el nivel: se queda agotado
			p["entorno"] = Recoleccion.entorno_de_nivel(p["tipo"], mundo, p["entorno"], p["nivel"])
			p["tasas"] = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"], p["nivel"])
			p["agotado"] = _sin_tasas(p["tasas"])
		_recalculando = false
	_liberar_acarreadores_si_agotado(esquina)


## Ids de los recolectores del puesto cuyo oficio tiene ese rango (copia).
func _recolectores_de_rango(p: Dictionary, rango: int) -> Array:
	var ids: Array = []
	for id in p["rangos"]:
		if p["rangos"][id] == rango:
			ids.append(id)
	return ids
```

- [ ] **Paso 4: Ejecutar y ver pasar**

Ejecutar `EconomiaTest.tscn`. Esperado: «Las 33 pruebas de Economia pasaron correctamente» y ningún `Assertion failed`/`SCRIPT ERROR`. Si un TEST antiguo (p. ej. 19, 21 o 29) falla, revisar: un puesto agotado sigue sin admitir obreros nuevos, y la escuela solo admite `aprendiz`.

- [ ] **Paso 5: Commit**

```bash
git add godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: nivel de puesto derivado del personal, admisión por rango y agotamiento por nivel en Economia

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Tarea 3: Contratar por oficio en `Colonos`

**Archivos:**
- Modificar: `godot/scripts/Colonos.gd` (`contratar` ~559-582, `tecnicos_libres` ~586, `_quedar_sin_puesto` ~666)
- Prueba: `godot/scripts/ColonosTest.gd` (TEST 47, antes de la línea final «Las 46 pruebas…»)

**Interfaces:**
- Consume: `Economia.asignar(esquina, rol, id)` con roles `tecnico` y `especialista` (Tarea 2), `Economia.nivel_de`.
- Produce: `Colonos.contratar(esquina, rol)` acepta `"recolector"`, `"tecnico"`, `"especialista"`, `"aprendiz"`, `"acarreador"`; `Colonos.especialistas_libres() -> int`.

- [ ] **Paso 1: Escribir la prueba que falla**

En `ColonosTest.gd`, antes de `print("\n=== Las 46 pruebas de Colonos pasaron correctamente ===")` (que pasa a «Las 47 pruebas…»):

```gdscript
	print("\n=== TEST 47: contratar() por oficio en un puesto con niveles; un especialista despedido sigue siéndolo ===")
	var ciudad47: Node = CiudadScript.new()
	var colonos47: Node = _nuevo_con_puesto(ciudad47)  # maderero de 2x2 en (2, 2)
	var desempleado47: int = colonos47.agregar_colono("desempleado", Vector3i(6, 1, 1))
	var tecnico47: int = colonos47.agregar_colono("tecnico", Vector3i(6, 1, 2))
	var especialista47: int = colonos47.agregar_colono("especialista", Vector3i(6, 1, 3))
	ciudad47.demografia["desempleado"] = 1
	ciudad47.demografia["tecnico"] = 1
	ciudad47.demografia["especialista"] = 1
	assert(colonos47.especialistas_libres() == 1 and colonos47.tecnicos_libres() == 1)
	assert(colonos47.contratar(Vector2i(2, 2), "tecnico"))
	assert(colonos47.economia.nivel_de(Vector2i(2, 2)) == 2, "solo técnicos: nivel 2")
	assert(not colonos47.contratar(Vector2i(2, 2), "recolector"), "un obrero no entra a un puesto de nivel 2")
	assert(colonos47.colonos[desempleado47]["tipo"] == "desempleado" and ciudad47.demografia["desempleado"] == 1 and ciudad47.demografia["obrero"] == 0, "el rechazo no toca al colono ni la demografía")
	assert(colonos47.contratar(Vector2i(2, 2), "especialista"))
	assert(colonos47.colonos[especialista47]["tipo"] == "especialista" and colonos47.colonos[especialista47]["trabajo"]["puesto"] == Vector2i(2, 2))
	assert(ciudad47.demografia["especialista"] == 1 and ciudad47.demografia["tecnico"] == 1 and ciudad47.demografia["desempleado"] == 1, "contratar un oficio ya formado no cambia la demografía")
	assert(colonos47.especialistas_libres() == 0)
	assert(colonos47.despedir(Vector2i(2, 2), "especialista"))
	assert(colonos47.colonos[especialista47]["tipo"] == "especialista" and ciudad47.demografia["especialista"] == 1 and colonos47.especialistas_libres() == 1, "el especialista despedido sigue siéndolo")
	assert(colonos47.despedir(Vector2i(2, 2), "tecnico"))
	assert(colonos47.colonos[tecnico47]["tipo"] == "tecnico" and colonos47.economia.nivel_de(Vector2i(2, 2)) == 2, "vacío conserva el nivel 2")
	assert(not colonos47.contratar(Vector2i(2, 2), "recolector"), "ya no admite obreros")
```

- [ ] **Paso 2: Ejecutar y ver fallar**

Ejecutar `scenes/ColonosTest.tscn`. Esperado: `SCRIPT ERROR` por `especialistas_libres` inexistente.

- [ ] **Paso 3: Implementar**

En `Colonos.gd`, reemplazar `contratar` (y su comentario) por:

```gdscript
## Contrata a un colono para un puesto con un rol. Para "recolector", "aprendiz" y "acarreador" toma
## a un desempleado (el de id menor) y lo pasa a obrero en Ciudad.demografia y en el colono. Para
## "tecnico" y "especialista" toma a un libre de ese oficio (el de id menor): ya tiene su oficio, así que no
## cambia de tipo ni la demografía; un desempleado nunca se convierte en técnico ni en especialista, hay que
## formarlo. Falso si no hay candidato, el puesto no existe, el rol no es de ese puesto, no tiene cupo o su nivel
## no admite ese oficio (en ese caso no se toca nada).
func contratar(esquina: Vector2i, rol: String) -> bool:
	var es_oficio: bool = rol == "tecnico" or rol == "especialista"
	var candidatos: Array[int] = _ids_sin_puesto(rol) if es_oficio else _ids_de_tipo("desempleado")
	if candidatos.is_empty():
		return false
	candidatos.sort()
	var id: int = candidatos[0]
	if not economia.asignar(esquina, rol, id):
		return false
	var tipo: String = rol if es_oficio else "obrero"
	if not es_oficio:
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

Agregar tras `tecnicos_libres()`:

```gdscript
## Especialistas sin puesto (hoy ninguno: la escuela de especialistas todavía no existe).
func especialistas_libres() -> int:
	return _ids_sin_puesto("especialista").size()
```

En `_quedar_sin_puesto`, cambiar el condicional y el comentario de la función:

```gdscript
## El colono deja su puesto. Un técnico o un especialista conserva su oficio y queda libre; cualquier otro
## vuelve a desempleado. Pierde lo que llevara (salvo el insumo de refinería en fase "entrada").
```

```gdscript
	if tipo_previo != "tecnico" and tipo_previo != "especialista":
```

- [ ] **Paso 4: Ejecutar y ver pasar**

Ejecutar `ColonosTest.tscn` y `EconomiaTest.tscn`. Esperado: «Las 47 pruebas de Colonos pasaron correctamente» y sin `Assertion failed`.

- [ ] **Paso 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: contratar técnicos y especialistas en los puestos con niveles

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Tarea 4: Filas por oficio y nivel en `PanelPuesto`

**Archivos:**
- Modificar: `godot/scripts/PanelPuesto.gd`
- Prueba: `godot/scripts/HUDTest.gd` (ajustar TEST 7, `probar_panel_escuela`; agregar `probar_panel_niveles` y llamarla desde `ejecutar_pruebas()` tras `probar_panel_escuela()`)

**Interfaces:**
- Consume: `Economia.tiene_niveles`, `nivel_de`, `contar_rango`, `admite_rol`, `RANGO_DE_ROL` (Tarea 2); `Colonos.contratar`/`despedir`/`tecnicos_libres`/`especialistas_libres` (Tarea 3).
- Produce: `PanelPuesto._filas[rol]` con claves `"fila"`, `"cantidad"`, `"menos"`, `"mas"` y nueva `"libres"` (Label) para los roles `recolector`, `tecnico`, `especialista`, `aprendiz`, `acarreador`.

- [ ] **Paso 1: Escribir las pruebas (ajuste + nueva)**

En `HUDTest.gd`, en `probar_panel_escuela`, reemplazar la línea 707:

```gdscript
	assert(panel._almacen.visible and "Técnicos libres: %d" % Colonos.tecnicos_libres() in panel._libres.text, "la refinería pide técnicos libres: %s" % panel._libres.text)
```

por:

```gdscript
	assert(panel._almacen.visible and panel._filas["tecnico"]["libres"].text == "(%d libres)" % Colonos.tecnicos_libres(), "la refinería muestra los técnicos libres: %s" % panel._filas["tecnico"]["libres"].text)
	assert(not panel._filas["especialista"]["fila"].visible and not panel._filas["recolector"]["fila"].visible, "una refinería no tiene filas de obreros ni de especialistas")
```

Agregar `probar_panel_niveles()` a la lista de `ejecutar_pruebas()` tras `probar_panel_escuela()` y definirla tras `probar_panel_escuela`:

```gdscript
func probar_panel_niveles() -> void:
	print("=== TEST 8: PanelPuesto de un puesto con niveles (una fila por oficio, nivel en el título) ===")
	var esquina8 := Vector2i(960, 900)
	Economia.registrar_puesto(esquina8, "maderero", 3, 4, {"madera": 3.0})
	var panel: PanelContainer = PanelPuestoScript.new()
	add_child(panel)
	panel.abrir(esquina8)
	assert(panel._titulo.text == "Puesto maderero, nivel 1", "nivel en el título: %s" % panel._titulo.text)
	assert(panel._filas["recolector"]["fila"].visible and panel._filas["tecnico"]["fila"].visible and panel._filas["acarreador"]["fila"].visible)
	assert(not panel._filas["aprendiz"]["fila"].visible)
	assert(panel._filas["especialista"]["fila"].visible == (Colonos.especialistas_libres() > 0), "la fila de especialistas solo aparece si hay alguno")
	assert(panel._filas["tecnico"]["libres"].text == "(%d libres)" % Colonos.tecnicos_libres())
	assert(panel._filas["recolector"]["libres"].text == "(%d libres)" % Ciudad.demografia["desempleado"])
	Economia.asignar(esquina8, "tecnico", 99999)
	panel._actualizar()
	assert(panel._titulo.text == "Puesto maderero, nivel 2", "con un técnico sube a nivel 2: %s" % panel._titulo.text)
	assert(panel._filas["recolector"]["mas"].disabled, "un puesto de nivel 2 no admite obreros")
	assert(panel._filas["tecnico"]["cantidad"].text == "1" and panel._filas["recolector"]["cantidad"].text == "0")
	assert(not panel._filas["tecnico"]["menos"].disabled and panel._filas["recolector"]["menos"].disabled)
	Economia.liberar(99999)
	panel.queue_free()
	Economia.puestos.erase(esquina8)
```

(`PanelPuestoScript` ya existe como constante precargada en `HUDTest.gd`: la usa `probar_panel_escuela`.)

- [ ] **Paso 2: Ejecutar y ver fallar**

Ejecutar `scenes/HUDTest.tscn`. Esperado: error por la clave `"libres"` inexistente en `_filas`.

- [ ] **Paso 3: Implementar**

En `PanelPuesto.gd`:

1. Cambiar `NOMBRES_ROL`:

```gdscript
const NOMBRES_ROL := {"recolector": "Obreros", "tecnico": "Técnicos", "especialista": "Especialistas", "aprendiz": "Aprendices", "acarreador": "Acarreadores"}
```

2. Actualizar el comentario de cabecera: «filas "Obreros/Técnicos/Especialistas/Aprendices [-] n [+] (libres)" y "Acarreadores …"; el título muestra el nivel del puesto».

3. En `_ready`, el bucle de filas pasa a:

```gdscript
	for rol in ["recolector", "tecnico", "especialista", "aprendiz", "acarreador"]:
		caja.add_child(_crear_fila(rol))
```

4. En `_crear_fila`: `nombre.custom_minimum_size.x = 96.0`, y agregar la etiqueta de libres:

```gdscript
	var libres := TemaHUD.etiqueta()
	libres.custom_minimum_size.x = 70.0
	for nodo in [nombre, menos, cantidad, mas, libres]:
		fila.add_child(nodo)
	_filas[rol] = {"fila": fila, "cantidad": cantidad, "menos": menos, "mas": mas, "libres": libres}
	return fila
```

(reemplaza las dos últimas líneas de bucle/asignación previas).

5. Reemplazar `_actualizar` completa por:

```gdscript
func _actualizar() -> void:
	var puesto: Dictionary = Economia.puestos[esquina]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var es_escuela: bool = Economia.es_escuela(esquina)
	var con_niveles: bool = Economia.tiene_niveles(esquina)
	# Oficios que producen aquí: aprendices en la escuela, solo técnicos en la refinería, los tres oficios en los puestos con niveles.
	var oficios: Array = ["aprendiz"] if es_escuela else (["recolector", "tecnico", "especialista"] if con_niveles else ["tecnico"])
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	var nivel := ", nivel %d" % Economia.nivel_de(esquina) if con_niveles else ""
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"]) + nivel + estado
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0
	for rol in ["recolector", "tecnico", "especialista", "aprendiz"]:
		var fila: Dictionary = _filas[rol]
		var empleados: int = _empleados(rol, t, con_niveles)
		var libres: int = _libres_de(rol)
		fila["fila"].visible = oficios.has(rol) and (rol != "especialista" or libres > 0 or empleados > 0)
		fila["cantidad"].text = str(empleados)
		fila["libres"].text = "(%d libres)" % libres
		fila["menos"].disabled = empleados == 0
		fila["mas"].disabled = sin_cupo or libres <= 0 or not puesto["activo"] or not Economia.admite_rol(esquina, rol)
	var acarreadores: Dictionary = _filas["acarreador"]
	acarreadores["fila"].visible = not es_escuela  # una escuela no mueve recursos
	acarreadores["cantidad"].text = str(t["acarreadores"])
	acarreadores["libres"].text = "(%d libres)" % Ciudad.demografia["desempleado"]
	acarreadores["menos"].disabled = t["acarreadores"] == 0
	acarreadores["mas"].disabled = sin_cupo or Ciudad.demografia["desempleado"] <= 0 or not puesto["activo"]
	if es_escuela:
		_trabajadores.text = "Aprendices: %d / %d (presentes: %d)\nFormación de la cohorte: %d / %d h" % [t["recolectores"], puesto["cupo"], t["presentes"], int(puesto["progreso"]), Economia.HORAS_FORMACION]
	else:
		_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	# Solo la refinería necesita la pista de dónde salen sus técnicos.
	_libres.visible = not es_escuela and not con_niveles and Colonos.tecnicos_libres() == 0
	_libres.text = "Sin técnicos libres: fórmalos en una escuela técnica"
	_almacen.visible = not es_escuela
	_produccion.visible = not es_escuela
	_almacen.text = "Almacén local: " + _texto_recursos(Economia.almacen_local(esquina), "vacío") + " (máx. %d)" % puesto["capacidad"]
	_produccion.text = "Producción: " + _texto_recursos(Economia.produccion_por_hora(esquina), "ninguna", "/h")
	_distancia.text = "Distancia al núcleo: %s" % _distancia_al_nucleo()
	_demoler.text = "Cancelar demolición" if Obras.esta_marcado(Obras.id_en_columna(esquina)) else "Demoler"


## Cuántos del oficio "rol" trabajan en el puesto: en los puestos con niveles se cuenta por rango; en la
## refinería y la escuela, todos sus recolectores (técnicos o aprendices).
func _empleados(rol: String, t: Dictionary, con_niveles: bool) -> int:
	if con_niveles:
		return Economia.contar_rango(esquina, Economia.RANGO_DE_ROL.get(rol, 0))
	return t["recolectores"]


## Colonos libres de ese oficio que se podrían contratar: técnicos y especialistas libres, o desempleados.
func _libres_de(rol: String) -> int:
	match rol:
		"tecnico": return Colonos.tecnicos_libres()
		"especialista": return Colonos.especialistas_libres()
	return Ciudad.demografia["desempleado"]
```

- [ ] **Paso 4: Ejecutar y ver pasar**

Ejecutar `HUDTest.tscn`. Esperado: «HUDTest: todas las pruebas pasaron» y sin `Assertion failed`/`SCRIPT ERROR`.

- [ ] **Paso 5: Revisión visual rápida**

Abrir una partida (escena principal), colocar un maderero y hacer clic en él: comprobar que el título dice «Puesto maderero, nivel 1», que las filas Obreros y Técnicos caben en el ancho del panel (268 px) y que contratar un técnico libre (si existe) sube el nivel. Si el texto de la fila se corta, bajar `custom_minimum_size.x` de `nombre` o `libres` en `_crear_fila`.

- [ ] **Paso 6: Commit**

```bash
git add godot/scripts/PanelPuesto.gd godot/scripts/HUDTest.gd
git commit -m "feat: panel del puesto con una fila por oficio, libres por fila y nivel en el título

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Tarea 5: Tarjeta de la mina por nivel

**Archivos:**
- Modificar: `godot/scripts/HUD.gd` (`mostrar_contexto_puesto` ~222; función estática nueva junto a `texto_tasas`), `godot/scripts/CamaraCenital.gd` (`_actualizar_previsualizacion_puesto` ~984-1012)
- Prueba: `godot/scripts/HUDTest.gd` (`probar_formateadores_hud`, tras la línea 663)

**Interfaces:**
- Consume: `Recoleccion.tasas_mina_por_nivel(mundo, centro, altura) -> Array` (Tarea 1).
- Produce: `HUD.texto_tasas_mina_por_nivel(niveles: Array) -> String` (estática) y `HUD.mostrar_contexto_puesto(tipo, valida, tasas, costo = {}, bloques = {}, tasas_por_nivel: Array = [])`.

- [ ] **Paso 1: Escribir la prueba que falla**

En `HUDTest.gd`, dentro de `probar_formateadores_hud`, tras la última aserción de `texto_tasas`:

```gdscript
	assert(HUDScript.texto_tasas_mina_por_nivel([{"hierro": 2.0, "tierra": 0.1}, {}, {"hierro": 5.0}]) == "Recolección prevista por trabajador:\n  Nivel 1: 2.0 hierro/h\n  Nivel 2: nada\n  Nivel 3: 5.0 hierro/h", "se omiten las tasas menores de 0,3/h y cada nivel muestra solo su franja")
	assert(HUDScript.texto_tasas_mina_por_nivel([{}, {}, {}]) == "Recolección prevista por trabajador:\n  Nivel 1: nada\n  Nivel 2: nada\n  Nivel 3: nada")
```

- [ ] **Paso 2: Ejecutar y ver fallar**

Ejecutar `scenes/HUDTest.tscn`. Esperado: `SCRIPT ERROR` por `texto_tasas_mina_por_nivel` inexistente.

- [ ] **Paso 3: Implementar**

En `HUD.gd`, junto a las demás constantes de la clase agregar:

```gdscript
## Tasas por debajo de esta (unidades por trabajador y hora) no se listan en la tarjeta de la mina.
const UMBRAL_TASA_TARJETA := 0.3
```

Cambiar `mostrar_contexto_puesto` para recibir las franjas y usarlas en la mina:

```gdscript
func mostrar_contexto_puesto(tipo: String, valida: bool, tasas: Dictionary, costo: Dictionary = {}, bloques: Dictionary = {}, tasas_por_nivel: Array = []) -> void:
	var almacenamiento := "" if Recoleccion.ESCUELAS.has(tipo) else " · Almacenamiento: %d" % Recoleccion.capacidad_almacen_de(tipo)
	var prevision: String = texto_tasas_mina_por_nivel(tasas_por_nivel) if tipo == "mina" and not tasas_por_nivel.is_empty() else texto_tasas(tipo, tasas)
	var extra := "Personal máximo: %d%s\n%s" % [Recoleccion.cupo_de(tipo), almacenamiento, prevision]
	_contexto.mostrar(PanelPuestoScript.NOMBRES_PUESTO.get(tipo, tipo), costo, ["[Ctrl+rueda] ROTAR", "COLOCAR (clic)"], valida, extra, bloques)
```

Agregar antes de `texto_tasas`:

```gdscript
## Recolección prevista de una mina por nivel: la franja de cada nivel por separado (sin sumar los anteriores),
## omitiendo lo que rinde menos de UMBRAL_TASA_TARJETA. "niveles" viene de Recoleccion.tasas_mina_por_nivel().
static func texto_tasas_mina_por_nivel(niveles: Array) -> String:
	var lineas: Array = []
	for i in range(niveles.size()):
		var partes: Array = []
		for recurso in niveles[i]:
			if niveles[i][recurso] >= UMBRAL_TASA_TARJETA:
				partes.append("%.1f %s/h" % [niveles[i][recurso], recurso])
		lineas.append("  Nivel %d: %s" % [i + 1, ", ".join(partes) if not partes.is_empty() else "nada"])
	return "Recolección prevista por trabajador:\n" + "\n".join(lineas)
```

En `CamaraCenital.gd`, en `_actualizar_previsualizacion_puesto`: declarar `var tasas_por_nivel: Array = []` junto a `var tasas: Dictionary = {}`, calcularlo en la rama de la mina y pasarlo al HUD:

```gdscript
	var tasas: Dictionary = {}
	var tasas_por_nivel: Array = []
	if _tipo_puesto_activo == "mina":
		var altura_superficie: int = mundo.altura_en(centro.x, centro.y)
		var conteo: Dictionary = Recoleccion.detectar_recursos_extraibles(mundo, centro, altura_superficie)
		tasas = Recoleccion.tasas_recoleccion(conteo)
		tasas_por_nivel = Recoleccion.tasas_mina_por_nivel(mundo, centro, altura_superficie)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_MINA)
```

y la última línea de la función:

```gdscript
	hud.mostrar_contexto_puesto(_tipo_puesto_activo, valida, tasas, resumen["neto"], resumen["bloques"], tasas_por_nivel)
```

- [ ] **Paso 4: Ejecutar y ver pasar**

Ejecutar `HUDTest.tscn` y `CamaraCenitalModosTest.tscn`. Esperado: sin `Assertion failed`/`SCRIPT ERROR`.

- [ ] **Paso 5: Revisión visual rápida**

En una partida, activar la herramienta de la mina y mover el cursor sobre terreno con vetas: la tarjeta lista «Nivel 1/2/3» con sus recursos; comprobar que no hay tirones al mover el ratón (se calculan 3 franjas por actualización).

- [ ] **Paso 6: Commit**

```bash
git add godot/scripts/HUD.gd godot/scripts/CamaraCenital.gd godot/scripts/HUDTest.gd
git commit -m "feat: la tarjeta de la mina muestra los recursos de la franja de cada nivel

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Tarea 6: Documentación y verificación final

**Archivos:**
- Modificar: `docs/Pendientes y próximos pasos.md` (puntos 2, 3 y 6 de la sección 4b), `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md` (sección nueva al final), `docs/ideas-backlog.md` (entrada «Jerarquía de empleo…»), `docs/superpowers/specs/2026-10-02-niveles-de-puesto-empleo-por-tipo-design.md` (corrección)

- [ ] **Paso 1: Marcar los pendientes**

En `docs/Pendientes y próximos pasos.md`, sección 4b, anteponer `✅ (fecha de hoy)` y una línea de resumen a los puntos 2, 3 y 6, conservando el texto original:
- Punto 2: «Hecho: una fila -/+ por oficio (Obreros, Técnicos, Especialistas) más Acarreadores, con los libres de cada tipo».
- Punto 3: «Hecho para los 4 puestos de recolección: el nivel sale del rango mínimo de los recolectores, un puesto agotado a su nivel despide al rango mínimo y sube con quien queda; mina por franjas de profundidad, caza/maderero/pesca por anillos del +50 % y velocidad ×1,5/×2. Quedan fuera la escuela de especialistas y la investigación; ver la especificación `2026-10-02-niveles-de-puesto-empleo-por-tipo-design.md`».
- Punto 6: «Hecho: la tarjeta de la mina lista los recursos de la franja de cada nivel (omite < 0,3/h)».

- [ ] **Paso 2: Documento técnico de PoC 5**

Al final de `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md` agregar la sección:

```markdown
## Niveles de puesto y empleo por tipo (2026-10-02)

Los puestos de mina, maderero, caza/recolección y pesca tienen nivel 1–3. El nivel no se compra: sale del rango de sus recolectores (obrero 1, técnico 2, especialista 3) y es el mínimo entre ellos; los acarreadores no cuentan. Sin recolectores el puesto conserva su último nivel.

- **Admisión:** un puesto admite oficios de rango igual o superior a su nivel. Agotado a su nivel, solo admite rangos superiores.
- **Agotamiento por nivel:** al agotarse el área del nivel actual se despide a los recolectores de rango mínimo; si queda personal de rango mayor, el nivel sube, el área crece y se reevalúa el agotamiento.
- **Mina:** profundidad acumulada 8 / 16 / 24 sobre el mismo radio; sin multiplicador de velocidad. La tarjeta de colocación lista las tasas de la franja de cada nivel.
- **Caza/recolección, maderero y pesca:** radio base ×1 / ×1,5 / ×2 (12→18→24 y 25→37→50) y velocidad ×1 / ×1,5 / ×2. Al subir de nivel, la referencia de árboles suma los árboles vivos del anillo nuevo.
- **Panel del puesto:** una fila -/+ por oficio con los libres de cada tipo; el título muestra el nivel.
- Código: `Economia.nivel_de()`, `admite_rol()`, `_actualizar_agotamiento()`; `Recoleccion.radio_de_nivel()`, `profundidad_de_nivel()`, `entorno_de_nivel()`, `tasas_mina_por_nivel()`.
- Pendiente: escuela de especialistas, universidad e investigación, y niveles de refinerías.
```

- [ ] **Paso 3: Backlog y corrección de la especificación**

En `docs/ideas-backlog.md`, al inicio del texto de la entrada «Jerarquía de empleo, niveles de edificio e investigación en universidad», insertar: «**Parte hecha (2026-10-02):** empleo jerárquico y niveles de los 4 puestos de recolección según quién trabaja, sin investigación (ver `docs/superpowers/specs/2026-10-02-niveles-de-puesto-empleo-por-tipo-design.md`). Pendiente: universidad e investigación, escuela de especialistas y niveles de refinerías.»

En la especificación, en «Tarjeta de la mina (punto 6)», reemplazar «Se reutiliza `detectar_recursos` con `profundidad_minima`.» por «Se calcula como diferencia de `detectar_recursos_extraibles` entre profundidades consecutivas (`Recoleccion.tasas_mina_por_nivel`).»

- [ ] **Paso 4: Verificación final**

Ejecutar en el proyecto compartido (CLAUDE.md): `scenes/Test.tscn`, `EconomiaTest.tscn`, `ColonosTest.tscn`, `RecoleccionTest.tscn`, `HUDTest.tscn` y `CamaraCenitalModosTest.tscn`; en cada una revisar la salida completa con `grep -nE "Assertion failed|SCRIPT ERROR"`. Esperado: sin coincidencias y las líneas de éxito de cada escena.

- [ ] **Paso 5: Commit**

```bash
git add "docs/Pendientes y próximos pasos.md" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md" docs/ideas-backlog.md docs/superpowers/specs/2026-10-02-niveles-de-puesto-empleo-por-tipo-design.md
git commit -m "docs: niveles de puesto y empleo por tipo (pendientes, PoC 5, backlog y especificación)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
