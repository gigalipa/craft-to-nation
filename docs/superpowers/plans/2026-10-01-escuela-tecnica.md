# Escuela técnica Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar la conversión provisional desempleado → técnico por una formación real en un edificio nuevo, la Escuela técnica, donde una cohorte de 4 obreros estudia 24 h y sale como 3 técnicos libres.

**Architecture:** La escuela es un `tipo` más de `Economia.puestos` (como la siderúrgica), con un rol nuevo `aprendiz` que reutiliza la lista `recolectores`, el cupo y la presencia. `Economia` cuenta las horas de la cohorte y avisa con una señal; `Colonos` convierte a los colonos (3 pasan a técnico libre, 1 se va) y ajusta `Ciudad.demografia`. Un técnico despedido conserva su tipo, y las refinerías solo contratan técnicos libres.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), pruebas `godot/scripts/*Test.gd` con sus escenas `godot/scenes/*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-10-01-escuela-tecnica-design.md`

## Global Constraints

- GDScript con **tabulaciones**. Español en comentarios, mensajes del juego y pruebas.
- No tocar `.godot/`, `.godot-mcp/`, `.superpowers/` ni cachés de Python. No reformatear código ajeno.
- Zona: dentro de la zona de influencia y toda la huella sobre **zona residencial** (`Zonificacion.ZONAS_PINTABLES[0]`).
- Cupo del puesto = cohorte = `Ciudad.TIPOS_POBLACION["obrero"]["x_cama"]` (4); salen `Ciudad.TIPOS_POBLACION["tecnico"]["x_cama"]` (3) técnicos; `HORAS_FORMACION` = 24.
- La vivienda ocupada se conserva: 4 obreros (4 × 1/4) = 3 técnicos (3 × 1/3).
- El conteo avanza solo con los 4 aprendices presentes; se pausa si falta alguno y se reinicia si hay menos de 4 asignados.
- Un aprendiz sigue siendo `obrero` en `Ciudad.demografia` mientras estudia. Un técnico despedido o liberado sigue siendo `tecnico` (técnico libre).
- La escuela no lleva baúl: lleva 4 `mesa_estudio` (1 madera cada una, como un baúl). Los baúles son de los edificios residenciales y de los que mueven recursos.
- Fuera de alcance: especialistas, consumo de recursos para formar, arte, niveles de edificio, trabajo de obra de colonos.
- Commits en la rama `feat/escuela-tecnica`, con la línea final `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Cómo correr una prueba

Desde la raíz del repositorio (Git Bash). Las escenas de prueba nunca terminan solas y un `assert()` fallido no detiene el script, así que hay que acotar el tiempo y buscar los fallos en la salida completa:

```bash
GODOT="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
correr() { timeout -k 5 90 "$GODOT" --headless --path godot "scenes/$1.tscn" > "/tmp/ct_$1.txt" 2>&1; grep -E "Assertion failed|SCRIPT ERROR|Parse Error|pasaron|todas las pruebas" "/tmp/ct_$1.txt"; }
correr EconomiaTest
```

Verde = aparece la línea final «pasaron correctamente» y **no** aparece `Assertion failed`, `SCRIPT ERROR` ni `Parse Error`. El código de salida 124 (el timeout) es lo esperado.

## Review Focus

Entradas o condiciones que el spec implica pero que ninguna prueba obvia cubre; cada una tiene su prueba en la tarea que se indica:

1. **Despedir a uno de los 4 aprendices a mitad de estudio:** el conteo se reinicia y con 3 aprendices no se gradúa nadie aunque pasen 30 h (Tarea 1, TEST 29; Tarea 2, TEST 43).
2. **Deconstruir la escuela con la cohorte a medias:** los aprendices vuelven a desempleado (no a técnico ni a obrero) y la demografía cuadra (Tarea 2, TEST 43).
3. **Sin técnicos libres:** contratar un técnico devuelve falso sin tocar la demografía; un desempleado nunca se convierte en técnico (Tarea 2, TEST 37).
4. **Zona equivocada:** la escuela se rechaza fuera de la zona de influencia, sin zona pintada y sobre zona industrial (Tarea 5, TEST 14 de previsualización).
5. **Un colono de la cohorte ya no existe al graduarse** (retirado por hambruna o desahucio en el mismo tick): la graduación no falla (Tarea 2, TEST 44).

---

### Task 1: Escuela en `Recoleccion` y `Economia` (rol aprendiz, conteo y graduación)

**Files:**
- Modify: `godot/scripts/Recoleccion.gd` (constante `ESCUELAS`, `TIPOS_PUESTO_TRABAJO`, `cupo_de`)
- Modify: `godot/scripts/Economia.gd` (señal, constantes, `registrar_puesto`, `asignar`, `liberar`, `simular_hora`, helpers)
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Consumes: `Ciudad.TIPOS_POBLACION[tipo]["x_cama"]`, `Economia.marcar_presente()`, `Economia.liberar()`.
- Produces:
  - `Recoleccion.ESCUELAS: Dictionary` = `{"escuela_tecnica": {"origen": "obrero", "destino": "tecnico"}}`.
  - `Economia.HORAS_FORMACION: int` (24).
  - `Economia.es_escuela(esquina: Vector2i) -> bool`.
  - `Economia.roles_de(esquina: Vector2i) -> Array` (roles válidos del puesto).
  - `signal Economia.cohorte_graduada(esquina: Vector2i, ids: Array)` (los `ids` ya están liberados).
  - Cada puesto guarda `"progreso": float` (horas de la cohorte).

- [ ] **Step 1: Escribir la prueba que falla**

En `godot/scripts/EconomiaTest.gd`, junto a `ESQ_REF` (línea 13), añade la constante:

```gdscript
const ESQ_ESC := Vector2i(50, 50)
```

Después de `_con_siderurgica()` (termina en la línea 49) añade el helper:

```gdscript
## Una Economia con una escuela técnica de 5x5 en ESQ_ESC (cupo 4: el de la cohorte).
func _con_escuela(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(ESQ_ESC, "escuela_tecnica", 5, 5, {})
	return economia
```

Reemplaza la última línea de `ejecutar_pruebas()` (`print("\n=== Las 28 pruebas de Economia pasaron correctamente ===")`) por este bloque:

```gdscript
	print("\n=== TEST 29: la escuela técnica forma cohortes: el conteo solo avanza con los 4 aprendices presentes y a las 24 h se gradúan ===")
	var e29: Node = _con_escuela(CiudadScript.new())
	assert(e29.es_escuela(ESQ_ESC) and not e29.es_refineria(ESQ_ESC) and not e29.es_escuela(Vector2i(0, 0)))
	assert(e29.puestos[ESQ_ESC]["cupo"] == 4 and e29.puestos[ESQ_ESC]["capacidad"] == 0, "cupo = cohorte; sin almacén local")
	assert(e29.roles_de(ESQ_ESC) == ["aprendiz"], "solo aprendices")
	assert(not e29.asignar(ESQ_ESC, "recolector", 1) and not e29.asignar(ESQ_ESC, "tecnico", 1) and not e29.asignar(ESQ_ESC, "acarreador", 1), "la escuela solo admite aprendices")
	var e29b: Node = _nueva(CiudadScript.new())
	assert(not e29b.asignar(ESQ, "aprendiz", 9), "un puesto de recolección no admite aprendices")
	var e29c: Node = _con_siderurgica(CiudadScript.new())
	assert(not e29c.asignar(ESQ_REF, "aprendiz", 9), "una refinería tampoco")
	var graduadas29: Array = []
	e29.cohorte_graduada.connect(func(esquina: Vector2i, ids: Array) -> void: graduadas29.append([esquina, ids]))
	for id29 in range(1, 4):
		assert(e29.asignar(ESQ_ESC, "aprendiz", id29))
		e29.marcar_presente(id29, true)
	for hora29 in range(30):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 0.0 and graduadas29.is_empty(), "con 3 aprendices no hay conteo, pasen las horas que pasen")
	assert(e29.asignar(ESQ_ESC, "aprendiz", 4))
	for hora29 in range(5):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 0.0, "el cuarto está asignado pero no presente: el conteo no empieza")
	e29.marcar_presente(4, true)
	for hora29 in range(5):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 5.0, "con los 4 presentes avanza 1 h por hora de juego")
	e29.marcar_presente(2, false)
	for hora29 in range(3):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 5.0, "si uno falta, el conteo se pausa")
	e29.marcar_presente(2, true)
	for hora29 in range(18):
		e29.simular_hora()
	assert(e29.puestos[ESQ_ESC]["progreso"] == 23.0 and graduadas29.is_empty(), "a las 23 h todavía no se gradúa")
	e29.simular_hora()
	assert(graduadas29.size() == 1 and graduadas29[0][0] == ESQ_ESC and graduadas29[0][1] == [1, 2, 3, 4], "a las 24 h se gradúa la cohorte")
	assert(e29.puestos[ESQ_ESC]["progreso"] == 0.0 and e29.cupo_libre(ESQ_ESC) == 4, "la escuela queda libre para otra cohorte")
	assert(e29.trabajadores_de(ESQ_ESC) == {"recolectores": 0, "acarreadores": 0, "presentes": 0}, "los 4 ya no trabajan ahí")

	print("\n=== TEST 29b: despedir a un aprendiz reinicia el conteo ===")
	var e29d: Node = _con_escuela(CiudadScript.new())
	for id29d in range(1, 5):
		e29d.asignar(ESQ_ESC, "aprendiz", id29d)
		e29d.marcar_presente(id29d, true)
	for hora29d in range(10):
		e29d.simular_hora()
	assert(e29d.puestos[ESQ_ESC]["progreso"] == 10.0)
	e29d.liberar(4)
	assert(e29d.puestos[ESQ_ESC]["progreso"] == 0.0, "al irse uno, la cohorte empieza de nuevo")
	assert(e29d.asignar(ESQ_ESC, "aprendiz", 5))
	assert(e29d.puestos[ESQ_ESC]["progreso"] == 0.0)

	print("\n=== Las 29 pruebas de Economia pasaron correctamente ===")
```

- [ ] **Step 2: Correr la prueba y verificar que falla**

Run: `correr EconomiaTest`
Expected: errores `SCRIPT ERROR` por `es_escuela` / `roles_de` / `cohorte_graduada` inexistentes (o `Parse Error`), y no aparece la línea «Las 29 pruebas».

- [ ] **Step 3: Implementar en `Recoleccion.gd`**

Después de `TIPOS_PUESTO_TRABAJO` (línea 29) sustituye esa línea por estas dos (la escuela es un puesto de trabajo):

```gdscript
const TIPOS_PUESTO_TRABAJO := ["mina", "caza_recoleccion", "maderero", "pesca_frutos_mar", "siderurgica", "refineria_tierras_raras", "aserradero", "carbonera", "escuela_tecnica"]
## Escuelas: tipo de puesto -> {"origen", "destino"} (tipos de Ciudad.TIPOS_POBLACION). Una cohorte de
## x_cama[origen] colonos de origen sale como x_cama[destino] colonos de destino: la vivienda ocupada se
## conserva (4 obreros = 3 técnicos) y quien sobra se va de la ciudad.
const ESCUELAS := {"escuela_tecnica": {"origen": "obrero", "destino": "tecnico"}}
```

En `cupo_de()`, antes del `return 0` final (después del bloque de `REFINERIAS`), añade:

```gdscript
	if ESCUELAS.has(tipo):
		return Ciudad.TIPOS_POBLACION[ESCUELAS[tipo]["origen"]]["x_cama"]  # el cupo es la cohorte
```

Actualiza el comentario de `cupo_de()` si hace falta (los aprendices también cuentan en el cupo). `capacidad_almacen_de()` no cambia: una escuela devuelve 0 (sin almacén local).

- [ ] **Step 4: Implementar en `Economia.gd`**

(a) Junto a las señales (línea 15-20) añade:

```gdscript
## Una escuela completó las horas de su cohorte. Los "ids" ya están liberados de su puesto; Colonos
## los convierte (ver Colonos._on_cohorte_graduada()).
signal cohorte_graduada(esquina: Vector2i, ids: Array)
```

(b) Reemplaza la constante `ROLES` y su comentario (líneas 39-41) por:

```gdscript
## "tecnico" solo existe en las refinerías (opera la receta); "recolector" solo en los puestos de
## recolección; "aprendiz" solo en las escuelas. "acarreador" vale en los puestos de recolección y
## en las refinerías (ver roles_de()).
const ROLES := ["recolector", "tecnico", "aprendiz", "acarreador"]

## Horas de juego que estudia una cohorte antes de graduarse (placeholder sin balance real).
const HORAS_FORMACION := 24
```

(c) En `registrar_puesto()`, en el diccionario, tras la línea `"salida": salida, "chimenea": chimenea,` añade:

```gdscript
		"progreso": 0.0,  # horas que lleva estudiando la cohorte (solo escuelas)
```

También amplía el doc de `registrar_puesto()` con: `"progreso" son las horas de estudio de la cohorte (solo escuelas, ver _formar()).` (una frase).

(d) Reemplaza el cuerpo de `asignar()` (líneas 150-162) por:

```gdscript
func asignar(esquina: Vector2i, rol: String, colono_id: int) -> bool:
	if not puestos.has(esquina) or not roles_de(esquina).has(rol) or _puesto_de.has(colono_id):
		return false  # roles válidos por tipo de puesto: ver roles_de()
	var p: Dictionary = puestos[esquina]
	if not p["activo"] or (p["agotado"] and rol == "recolector"):
		return false  # inactivo (se está deconstruyendo) o agotado: sin recolectores nuevos
	if cupo_libre(esquina) <= 0:
		return false
	p[_lista_de(rol)].append(colono_id)
	_puesto_de[colono_id] = esquina
	return true
```

(e) Justo debajo de `asignar()` añade:

```gdscript
## Roles que admite el puesto: aprendices en una escuela; técnicos y acarreadores en una refinería;
## recolectores y acarreadores en los demás.
func roles_de(esquina: Vector2i) -> Array:
	if es_escuela(esquina):
		return ["aprendiz"]
	return ["tecnico", "acarreador"] if es_refineria(esquina) else ["recolector", "acarreador"]
```

(f) En `liberar()`, antes de `_puesto_de.erase(colono_id)`, añade:

```gdscript
	if es_escuela(_puesto_de[colono_id]):
		p["progreso"] = 0.0  # si se va un aprendiz, la cohorte empieza de nuevo
```

(g) Actualiza el comentario de `_lista_de()` (línea 184-185) a: `## Lista interna donde vive cada rol: los técnicos y los aprendices comparten la de los recolectores (el cupo y la presencia funcionan igual).`

(h) En `simular_hora()`, justo antes de `if es_refineria(esquina):` (línea 256) añade:

```gdscript
			if es_escuela(esquina):
				_formar(esquina)
				continue
```

(i) Junto a `es_refineria()` (línea 412) añade:

```gdscript
## true si el puesto es una escuela (Recoleccion.ESCUELAS): forma a sus aprendices en vez de producir.
func es_escuela(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and Recoleccion.ESCUELAS.has(puestos[esquina]["tipo"])
```

(j) Junto a `_refinar()` añade:

```gdscript
## Una hora de estudio: la cohorte (el cupo completo de aprendices) suma 1 h solo si los aprendices
## están TODOS presentes; si falta alguno el conteo se pausa, y con menos aprendices que el cupo se
## reinicia. A HORAS_FORMACION se gradúa: los aprendices se liberan y Colonos los convierte.
func _formar(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	if p["recolectores"].size() < p["cupo"]:
		p["progreso"] = 0.0
		return
	if p["presentes"].size() < p["cupo"]:
		return
	p["progreso"] += 1.0
	if p["progreso"] < HORAS_FORMACION:
		return
	var ids: Array = p["recolectores"].duplicate()
	for id in ids:
		liberar(id)  # también reinicia "progreso"
	cohorte_graduada.emit(esquina, ids)
```

- [ ] **Step 5: Correr la prueba y verificar que pasa**

Run: `correr EconomiaTest`
Expected: aparece «Las 29 pruebas de Economia pasaron correctamente» y ningún `Assertion failed` / `SCRIPT ERROR`.

También `correr RecoleccionTest` (el cupo y los tipos de puesto cambiaron): sin fallos.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: la escuela técnica forma cohortes de aprendices en Economia

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `Colonos` (aprendices, graduación y técnico libre)

**Files:**
- Modify: `godot/scripts/Colonos.gd` (señal, conexión de `cohorte_graduada`, `contratar`, renombrar `_volver_a_desempleado`, `_on_cohorte_graduada`, helpers)
- Test: `godot/scripts/ColonosTest.gd` (reescribir TEST 37 y 38; añadir 42-44)

**Interfaces:**
- Consumes (Tarea 1): `Economia.cohorte_graduada(esquina, ids)`, `Economia.puestos[esquina]["tipo"]`, `Recoleccion.ESCUELAS`, `Economia.asignar()` con rol `aprendiz`.
- Produces:
  - `Colonos.tecnicos_libres() -> int` (técnicos sin puesto).
  - `signal Colonos.tecnicos_formados(cantidad: int)`.
  - `Colonos.contratar(esquina, rol)`: con rol `tecnico` toma un técnico libre (no convierte desempleados); con `aprendiz`, `recolector` o `acarreador` toma un desempleado y lo pasa a obrero.
  - `Colonos._quedar_sin_puesto(c)` (antes `_volver_a_desempleado`): un técnico conserva su tipo.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `godot/scripts/ColonosTest.gd`, después de `_nuevo_con_siderurgica()` (línea 130) añade el helper:

```gdscript
## Colonos con una escuela técnica de 2x2 en (2, 2) (cupo 4, el de la cohorte); mundo llano de 10x10.
func _nuevo_con_escuela(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(Vector2i(2, 2), "escuela_tecnica", 2, 2, {})
	var colonos: Node = _nuevo(_mundo_llano(), ciudad)
	colonos.economia = economia
	return colonos
```

Reemplaza el TEST 37 completo (de `print("\n=== TEST 37` hasta la línea del último `assert` antes del TEST 38) por:

```gdscript
	print("\n=== TEST 37: una refinería solo contrata técnicos libres; al despedirlos siguen siendo técnicos ===")
	var ciudad37: Node = CiudadScript.new()
	var colonos37: Node = _nuevo_con_siderurgica(ciudad37)
	var id37: int = colonos37.agregar_colono("desempleado", Vector3i(6, 1, 1))
	ciudad37.demografia["desempleado"] = 1
	assert(not colonos37.contratar(Vector2i(2, 2), "recolector"), "una refinería no acepta recolectores")
	assert(not colonos37.contratar(Vector2i(2, 2), "tecnico"), "un desempleado no se convierte en técnico: hace falta formarlo")
	assert(ciudad37.demografia["desempleado"] == 1 and ciudad37.demografia["tecnico"] == 0, "el rechazo no toca la demografía")
	assert(colonos37.colonos[id37]["tipo"] == "desempleado")
	var tecnico37: int = colonos37.agregar_colono("tecnico", Vector3i(6, 1, 2))
	ciudad37.demografia["tecnico"] = 1
	assert(colonos37.tecnicos_libres() == 1)
	assert(colonos37.contratar(Vector2i(2, 2), "tecnico"))
	assert(colonos37.colonos[tecnico37]["tipo"] == "tecnico" and colonos37.colonos[tecnico37]["trabajo"]["puesto"] == Vector2i(2, 2))
	assert(ciudad37.demografia["tecnico"] == 1 and ciudad37.demografia["desempleado"] == 1, "contratar a un técnico libre no cambia la demografía")
	assert(colonos37.tecnicos_libres() == 0, "ya no queda ninguno libre")
	assert(colonos37.despedir(Vector2i(2, 2), "tecnico"))
	assert(colonos37.colonos[tecnico37]["tipo"] == "tecnico" and ciudad37.demografia["tecnico"] == 1 and ciudad37.demografia["desempleado"] == 1, "el técnico despedido sigue siendo técnico")
	assert(colonos37.tecnicos_libres() == 1)
	assert(colonos37.contratar(Vector2i(2, 2), "tecnico"))
	colonos37.economia.quitar_puesto(Vector2i(2, 2))
	assert(colonos37.colonos[tecnico37]["tipo"] == "tecnico" and colonos37.tecnicos_libres() == 1, "al deconstruir la refinería el técnico queda libre")
```

En el TEST 38 (línea ~935) sustituye las dos líneas:

```gdscript
	colonos38.agregar_colono("desempleado", Vector3i(6, 1, 1))
	ciudad38.demografia["desempleado"] = 1
```

por:

```gdscript
	colonos38.agregar_colono("tecnico", Vector3i(6, 1, 1))
	ciudad38.demografia["tecnico"] = 1
```

Reemplaza la última línea de `ejecutar_pruebas()` (`print("\n=== Las 41 pruebas de Colonos pasaron correctamente ===")`) por:

```gdscript
	print("\n=== TEST 42: una cohorte de 4 aprendices estudia 24 h y sale como 3 técnicos libres; el cuarto se va (la vivienda ocupada se conserva) ===")
	var ciudad42: Node = CiudadScript.new()
	var colonos42: Node = _nuevo_con_escuela(ciudad42)
	var ids42: Array[int] = []
	for z42 in range(1, 5):
		ids42.append(colonos42.agregar_colono("desempleado", Vector3i(6, 1, z42)))
	ciudad42.demografia["desempleado"] = 4
	var formados42: Array = []
	colonos42.tecnicos_formados.connect(func(cantidad: int) -> void: formados42.append(cantidad))
	assert(not colonos42.contratar(Vector2i(2, 2), "tecnico") and not colonos42.contratar(Vector2i(2, 2), "acarreador"), "la escuela solo admite aprendices")
	for i42 in range(4):
		assert(colonos42.contratar(Vector2i(2, 2), "aprendiz"))
	assert(ciudad42.demografia["obrero"] == 4 and ciudad42.demografia["desempleado"] == 0, "un aprendiz cuenta como obrero mientras estudia")
	assert(is_equal_approx(ciudad42.vivienda_ocupada, 1.0))
	for id42 in ids42:
		colonos42.economia.marcar_presente(id42, true)
	for hora42 in range(23):
		colonos42.economia.simular_hora()
	assert(formados42.is_empty() and _contar(colonos42, "tecnico") == 0, "a las 23 h todavía no se gradúa")
	colonos42.economia.simular_hora()
	assert(formados42 == [3], "salen 3 técnicos")
	assert(_contar(colonos42, "tecnico") == 3 and colonos42.colonos.size() == 3, "el cuarto colono se fue de la ciudad")
	assert(not colonos42.colonos.has(ids42[3]), "se va el de id mayor")
	assert(ciudad42.demografia["tecnico"] == 3 and ciudad42.demografia["obrero"] == 0 and ciudad42.demografia["desempleado"] == 0)
	assert(is_equal_approx(ciudad42.vivienda_ocupada, 1.0), "la vivienda ocupada se conserva: 4 x 1/4 = 3 x 1/3")
	assert(colonos42.tecnicos_libres() == 3, "los técnicos nuevos quedan sin puesto")
	assert(colonos42.economia.cupo_libre(Vector2i(2, 2)) == 4, "la escuela queda libre para otra cohorte")

	print("\n=== TEST 43: despedir a un aprendiz reinicia la cohorte; deconstruir la escuela devuelve a los aprendices a desempleado ===")
	var ciudad43: Node = CiudadScript.new()
	var colonos43: Node = _nuevo_con_escuela(ciudad43)
	var ids43: Array[int] = []
	for z43 in range(1, 5):
		ids43.append(colonos43.agregar_colono("desempleado", Vector3i(6, 1, z43)))
	ciudad43.demografia["desempleado"] = 4
	for i43 in range(4):
		colonos43.contratar(Vector2i(2, 2), "aprendiz")
	for id43 in ids43:
		colonos43.economia.marcar_presente(id43, true)
	for hora43 in range(10):
		colonos43.economia.simular_hora()
	assert(colonos43.economia.puestos[Vector2i(2, 2)]["progreso"] == 10.0)
	assert(colonos43.despedir(Vector2i(2, 2), "aprendiz"))
	assert(ciudad43.demografia["obrero"] == 3 and ciudad43.demografia["desempleado"] == 1, "el despedido vuelve a desempleado, sin formación")
	assert(colonos43.economia.puestos[Vector2i(2, 2)]["progreso"] == 0.0, "la cohorte empieza de nuevo")
	for hora43 in range(30):
		colonos43.economia.simular_hora()
	assert(_contar(colonos43, "tecnico") == 0 and ciudad43.demografia["tecnico"] == 0, "con 3 aprendices no se gradúa nadie")
	colonos43.economia.quitar_puesto(Vector2i(2, 2))
	assert(ciudad43.demografia["obrero"] == 0 and ciudad43.demografia["desempleado"] == 4 and ciudad43.demografia["tecnico"] == 0, "sin escuela, los aprendices vuelven a desempleado")
	assert(_contar(colonos43, "desempleado") == 4)

	print("\n=== TEST 44: si un colono de la cohorte ya no existe al graduarse, la graduación no falla ===")
	var ciudad44: Node = CiudadScript.new()
	var colonos44: Node = _nuevo_con_escuela(ciudad44)
	var ids44: Array[int] = []
	for z44 in range(1, 5):
		ids44.append(colonos44.agregar_colono("desempleado", Vector3i(6, 1, z44)))
	ciudad44.demografia["desempleado"] = 4
	for i44 in range(4):
		colonos44.contratar(Vector2i(2, 2), "aprendiz")
	for id44 in ids44:
		colonos44.economia.marcar_presente(id44, true)
	colonos44.colonos.erase(ids44[0])  # p. ej. lo retiró una hambruna en el mismo tick
	for hora44 in range(24):
		colonos44.economia.simular_hora()
	assert(_contar(colonos44, "tecnico") == 3, "los tres que quedan se gradúan")

	print("\n=== Las 44 pruebas de Colonos pasaron correctamente ===")
```

- [ ] **Step 2: Correr la prueba y verificar que falla**

Run: `correr ColonosTest`
Expected: `SCRIPT ERROR` por `tecnicos_libres` / `tecnicos_formados` inexistentes, y fallos en el TEST 37/38; no aparece «Las 44 pruebas».

- [ ] **Step 3: Implementar en `Colonos.gd`**

(a) Junto a las señales (línea 15-16) añade:

```gdscript
## Una escuela graduó a una cohorte: "cantidad" colonos pasaron a técnico (el que sobraba se fue).
## ponytail: solo existe la escuela técnica; con la de especialistas se añadirá el tipo destino.
signal tecnicos_formados(cantidad: int)
```

(b) En el setter de `economia` (líneas 48-58), conecta y desconecta la señal nueva. Dentro del `if economia != null:` añade tras el bloque de `trabajadores_liberados`:

```gdscript
			if economia.cohorte_graduada.is_connected(_on_cohorte_graduada):
				economia.cohorte_graduada.disconnect(_on_cohorte_graduada)
```

y dentro de `if valor != null:` añade:

```gdscript
			valor.cohorte_graduada.connect(_on_cohorte_graduada)
```

(c) Reemplaza `contratar()` y su comentario (líneas 513-535) por:

```gdscript
## Contrata a un colono para un puesto con un rol. Para "recolector", "aprendiz" y "acarreador" toma
## a un desempleado (el de id menor) y lo pasa a obrero en Ciudad.demografia y en el colono. Para
## "tecnico" toma a un técnico libre (el de id menor): ya es técnico, así que no cambia de tipo ni la
## demografía; un desempleado nunca se convierte en técnico, hay que formarlo en una escuela. Falso si
## no hay candidato, el puesto no existe, el rol no es de ese puesto o no tiene cupo.
func contratar(esquina: Vector2i, rol: String) -> bool:
	var candidatos: Array[int] = _ids_sin_puesto("tecnico") if rol == "tecnico" else _ids_de_tipo("desempleado")
	if candidatos.is_empty():
		return false
	candidatos.sort()
	var id: int = candidatos[0]
	if not economia.asignar(esquina, rol, id):
		return false
	var tipo := "tecnico" if rol == "tecnico" else "obrero"
	if rol != "tecnico":
		ciudad.reasignar_tipo("desempleado", tipo)
	var c: Dictionary = colonos[id]
	c["tipo"] = tipo
	c["trabajo"] = {"puesto": esquina, "rol": rol}
	c["fase"] = ""
	c["carga"] = {}
	c["fallos_servicio"] = 0
	_dejar_lo_que_hacia(c)
	return true


## Técnicos sin puesto (formados en una escuela y todavía sin empleo).
func tecnicos_libres() -> int:
	return _ids_sin_puesto("tecnico").size()
```

(d) Debajo de `_ids_de_tipo()` (línea 130-135) añade:

```gdscript
## Ids de los colonos de ese tipo que no trabajan en ningún puesto.
func _ids_sin_puesto(tipo: String) -> Array[int]:
	var ids: Array[int] = []
	for id in _ids_de_tipo(tipo):
		if colonos[id]["trabajo"].is_empty():
			ids.append(id)
	return ids
```

(e) Renombra `_volver_a_desempleado` a `_quedar_sin_puesto` en **todas** sus apariciones (`grep -n "_volver_a_desempleado" godot/scripts/*.gd`: la definición y los usos en `despedir`, `_on_puesto_quitado`, `_on_trabajadores_liberados` y `_decidir_trabajo`; las pruebas no la llaman). Actualiza el cuerpo y su comentario:

```gdscript
## El colono deja su puesto. Un técnico conserva su oficio y queda como técnico libre; cualquier otro
## vuelve a desempleado. Pierde lo que llevara (salvo el insumo de refinería en fase "entrada").
func _quedar_sin_puesto(c: Dictionary) -> void:
	var tipo_previo: String = c["tipo"]
	# Solo el insumo de refinería (fase "entrada", ya retirado del stock) se devuelve; el resto de la carga se pierde, para que despedir no teletransporte recursos al stock.
	if c["fase"] == "entrada" and not c["carga"].is_empty():
		economia.entregar(c["carga"])
	c["trabajo"] = {}
	c["carga"] = {}
	c["fase"] = ""
	c["fallos_servicio"] = 0
	c["retirar_al_entregar"] = false
	if tipo_previo != "tecnico":
		c["tipo"] = "desempleado"
		ciudad.reasignar_tipo(tipo_previo, "desempleado")
	_dejar_lo_que_hacia(c)
```

Actualiza también los comentarios de `despedir()` («vuelve a desempleado» → «queda sin puesto») y de `_on_puesto_quitado()` / `_on_trabajadores_liberados()` («vuelven a desempleado» → «quedan sin puesto»).

(f) Después de `_on_trabajadores_liberados()` añade:

```gdscript
## Una escuela graduó a su cohorte (Economia.cohorte_graduada; los ids ya están libres): de cada
## x_cama[origen] colonos salen x_cama[destino] del tipo destino (los de id menor, ya sin puesto) y
## el resto se va de la ciudad; así la vivienda ocupada se conserva y nadie queda desahuciado.
func _on_cohorte_graduada(esquina: Vector2i, ids: Array) -> void:
	var escuela: Dictionary = Recoleccion.ESCUELAS[economia.puestos[esquina]["tipo"]]
	var salen: int = ciudad.TIPOS_POBLACION[escuela["destino"]]["x_cama"]
	var graduados := 0
	var ordenados: Array = ids.duplicate()
	ordenados.sort()
	for id in ordenados:
		if not colonos.has(id):
			continue  # ya no existe (p. ej. lo retiró una hambruna en el mismo tick)
		if graduados < salen:
			ciudad.reasignar_tipo(escuela["origen"], escuela["destino"])
			var c: Dictionary = colonos[id]
			c["tipo"] = escuela["destino"]
			c["trabajo"] = {}
			c["carga"] = {}
			c["fase"] = ""
			c["fallos_servicio"] = 0
			_dejar_lo_que_hacia(c)
			graduados += 1
		else:
			ciudad.demografia[escuela["origen"]] -= 1
			_retirar(id)
	if graduados > 0:
		tecnicos_formados.emit(graduados)
```

- [ ] **Step 4: Correr las pruebas y verificar que pasan**

Run: `correr ColonosTest`
Expected: «Las 44 pruebas de Colonos pasaron correctamente», sin `Assertion failed` ni `SCRIPT ERROR`.

Run: `correr EconomiaTest` y `correr CiudadTest` (no deben cambiar): sin fallos.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/ColonosTest.gd
git commit -m "feat: aprendices, graduación por cohorte y técnico libre en Colonos

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Bloque `mesa_estudio`

**Files:**
- Modify: `godot/scenes/BlockLibrarySource.tscn` (ítem nuevo al final)
- Regenerate: `godot/assets/BlockLibrary.res` (con un script `--headless` temporal; las herramientas MCP del editor no sirven en este proyecto)
- Modify: `godot/scripts/VoxelWorld.gd` (`TIPOS_ESTRUCTURA`, `ORDEN_GRUPOS_EDIFICIO`)
- Modify: `godot/scripts/NiveladorTerreno.gd` (`COSTO_POR_CELDA`)
- Modify: `godot/scripts/Hotbar.gd` (`NOMBRES`)
- Test: `godot/scripts/NiveladorTerrenoTest.gd`

**Interfaces:**
- Produces: tipo de bloque `"mesa_estudio"` (ítem 34 de la `MeshLibrary`, el último), estructura y mobiliario del edificio, con costo `{"madera": 1}` igual al del baúl; nombre «Mesa de estudio» en `Hotbar.nombre_de()`. La plantilla de la Tarea 4 lo usa con el carácter `M`.

- [ ] **Step 1: Escribir la prueba que falla**

En `godot/scripts/NiveladorTerrenoTest.gd`, reemplaza la última línea (`print("\n=== Las 23 pruebas de NiveladorTerreno pasaron correctamente ===")`) por:

```gdscript
	print("\n=== TEST 24: la mesa de estudio cuesta lo mismo que un baúl, es estructura de edificio (mobiliario) y existe en la biblioteca ===")
	assert(NiveladorTerreno.COSTO_POR_CELDA["mesa_estudio"] == NiveladorTerreno.COSTO_POR_CELDA["baul"], "mismo costo que un baúl")
	assert(VoxelWorldScript.TIPOS_ESTRUCTURA.has("mesa_estudio"), "cuenta como estructura del edificio")
	assert(VoxelWorldScript.ORDEN_GRUPOS_EDIFICIO[2].has("mesa_estudio"), "es mobiliario: se construye al final y se deconstruye primero")
	assert(HotbarScript.nombre_de("mesa_estudio") == "Mesa de estudio")
	var biblioteca_24: MeshLibrary = load("res://assets/BlockLibrary.res")
	assert(biblioteca_24.find_item_by_name("mesa_estudio") != -1, "la biblioteca tiene el bloque")
	assert(biblioteca_24.find_item_by_name("baul") != -1 and biblioteca_24.find_item_by_name("bloque_acero") != -1, "y conserva los anteriores")

	print("\n=== Las 24 pruebas de NiveladorTerreno pasaron correctamente ===")
```

Junto a `const HUDScript = preload(...)` (línea 18 del archivo) añade `const VoxelWorldScript = preload("res://scripts/VoxelWorld.gd")` y `const HotbarScript = preload("res://scripts/Hotbar.gd")`.

- [ ] **Step 2: Correr la prueba y verificar que falla**

Run: `correr NiveladorTerrenoTest`
Expected: `SCRIPT ERROR`/`Assertion failed` por la clave `mesa_estudio` inexistente; no aparece «Las 24 pruebas».

- [ ] **Step 3: Escribir el generador de la biblioteca y verificarlo contra la actual**

Crea el script temporal `godot/_tmp_gen_biblioteca.gd` (se borra al terminar; no se commitea):

```gdscript
extends SceneTree

## Reconstruye la MeshLibrary desde BlockLibrarySource.tscn como lo hace el editor (un ítem por hijo
## MeshInstance3D, en orden, con la forma de su CollisionShape3D hija) y la guarda en la ruta que
## llega tras "--" (por defecto res://_tmp_lib.res). Compara los ítems de assets/BlockLibrary.res con
## los nuevos e imprime DIFERENCIAS n (debe ser 0 mientras la fuente no cambie).
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = args[0] if args.size() > 0 else "res://_tmp_lib.res"
	var fuente: Node = load("res://scenes/BlockLibrarySource.tscn").instantiate()
	var lib := MeshLibrary.new()
	for hijo in fuente.get_children():
		var malla := hijo as MeshInstance3D
		if malla == null:
			continue
		var id := lib.get_last_unused_item_id()
		lib.create_item(id)
		lib.set_item_name(id, malla.name)
		lib.set_item_mesh(id, malla.mesh)
		lib.set_item_mesh_transform(id, Transform3D.IDENTITY)
		var formas: Array = []
		for nieto in malla.get_children():
			var colision := nieto as CollisionShape3D
			if colision != null and colision.shape != null:
				formas.append(colision.shape)
				formas.append(colision.transform)
		lib.set_item_shapes(id, formas)
	var vieja: MeshLibrary = load("res://assets/BlockLibrary.res")  # antes de guardar: puede ser el mismo archivo
	var copia_vieja: Array = []
	for id in vieja.get_item_list():
		copia_vieja.append([id, vieja.get_item_name(id), vieja.get_item_mesh(id).get_class(), vieja.get_item_mesh(id).get_aabb(), vieja.get_item_shapes(id).size()])
	print("GUARDADO ", ResourceSaver.save(lib, salida))
	var nueva: MeshLibrary = ResourceLoader.load(salida, "", ResourceLoader.CACHE_MODE_IGNORE)
	print("ITEMS viejo/nuevo ", copia_vieja.size(), " ", nueva.get_item_list().size())
	var diferencias := 0
	for datos in copia_vieja:
		var id: int = datos[0]
		var mismo: bool = nueva.get_item_name(id) == datos[1] \
			and nueva.get_item_mesh(id).get_class() == datos[2] \
			and nueva.get_item_mesh(id).get_aabb() == datos[3] \
			and nueva.get_item_shapes(id).size() == datos[4]
		if not mismo:
			diferencias += 1
			print("DIFERENTE ", id, " ", datos[1])
	print("DIFERENCIAS ", diferencias)
	fuente.free()
	quit()
```

Corre el generador **sin haber tocado todavía la fuente** y a un archivo temporal, para comprobar que reproduce la biblioteca actual:

```bash
timeout -k 5 60 "$GODOT" --headless --path godot --script res://_tmp_gen_biblioteca.gd -- res://_tmp_lib.res > /tmp/ct_gen.txt 2>&1; grep -E "GUARDADO|ITEMS|DIFEREN|SCRIPT ERROR" /tmp/ct_gen.txt
rm godot/_tmp_lib.res
```

Expected: `GUARDADO 0`, `ITEMS viejo/nuevo 34 34`, `DIFERENCIAS 0`. (Los avisos `BUG: Unreferenced static string` y `leaked` del cierre de Godot son ruido conocido.) Si `DIFERENCIAS` no es 0, **detente y consulta**: el generador no reproduce el editor.

- [ ] **Step 4: Añadir el ítem a `BlockLibrarySource.tscn`**

Siguiendo el patrón de `bloque_acero` (commit `93ae0f5`), antes de la primera línea `[node name=...]` añade:

```
[sub_resource type="StandardMaterial3D" id="Mat_mesa_estudio"]
albedo_color = Color(0.78, 0.62, 0.38, 1)

[sub_resource type="BoxMesh" id="Mesh_mesa_estudio"]
material = SubResource("Mat_mesa_estudio")

[sub_resource type="BoxShape3D" id="Shape_mesa_estudio"]
```

y **al final del archivo**, tras el nodo `bloque_acero` (la mesa va última para no mover ningún id):

```

[node name="mesa_estudio" type="MeshInstance3D" parent="." unique_id=900000201]
mesh = SubResource("Mesh_mesa_estudio")

[node name="CollisionShape3D" type="CollisionShape3D" parent="mesa_estudio" unique_id=900000202]
shape = SubResource("Shape_mesa_estudio")
```

(Color de madera clara, distinto del baúl `0.5, 0.35, 0.1`; es un cubo provisional hasta el arte.)

- [ ] **Step 5: Regenerar `assets/BlockLibrary.res`**

```bash
timeout -k 5 60 "$GODOT" --headless --path godot --script res://_tmp_gen_biblioteca.gd -- res://assets/BlockLibrary.res > /tmp/ct_gen.txt 2>&1; grep -E "GUARDADO|ITEMS|DIFEREN|SCRIPT ERROR" /tmp/ct_gen.txt
rm godot/_tmp_gen_biblioteca.gd
```

Expected: `GUARDADO 0`, `ITEMS viejo/nuevo 34 35`, `DIFERENCIAS 0` (los 34 ítems antiguos intactos; el nuevo es el 34). Verifica con `git status --short godot` que solo cambian `BlockLibrary.res` y `BlockLibrarySource.tscn` y que no queda ningún `_tmp_*`.

- [ ] **Step 6: Implementar el resto del bloque**

En `godot/scripts/VoxelWorld.gd`:
- `TIPOS_ESTRUCTURA` (línea ~92): `"cama_cabecera", "cama_pies", "baul", "mesa_estudio",`
- `ORDEN_GRUPOS_EDIFICIO` (línea ~1472): `["cama_cabecera", "cama_pies", "baul", "mesa_estudio"],`

En `godot/scripts/NiveladorTerreno.gd`, en `COSTO_POR_CELDA`, tras la línea `"baul": {"madera": 1},` (línea 48) añade:

```gdscript
	"mesa_estudio": {"madera": 1},  # igual que un baúl (decisión del usuario, 2026-10-01)
```

En `godot/scripts/Hotbar.gd`, en `NOMBRES` (tras `"baul": "Baúl",`) añade `"mesa_estudio": "Mesa de estudio",`. (No va en `NOMBRES_HOTBAR`, `TIPOS_INTERACTIVOS` ni `DESCRIPCION`: no está en la hotbar ni se usa con `E`.)

- [ ] **Step 7: Correr las pruebas y verificar que pasan**

Run: `correr NiveladorTerrenoTest` → «Las 24 pruebas de NiveladorTerreno pasaron correctamente».
Run: `correr ConstruccionTest` y `correr PlantillasPuestoTest` (leen la biblioteca nueva): sin `Assertion failed` / `SCRIPT ERROR` (esta última aún muestra «Las 13 pruebas»).

- [ ] **Step 8: Commit**

```bash
git add godot/scenes/BlockLibrarySource.tscn godot/assets/BlockLibrary.res godot/scripts/VoxelWorld.gd godot/scripts/NiveladorTerreno.gd godot/scripts/Hotbar.gd godot/scripts/NiveladorTerrenoTest.gd
git commit -m "feat: bloque mesa_estudio (1 madera, como un baúl)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Plantilla de la escuela técnica

**Files:**
- Modify: `godot/scripts/PlantillasPuesto.gd` (`BLOQUES`, `MATERIAL`, `PLANTILLAS`, `celda_deposito`)
- Test: `godot/scripts/PlantillasPuestoTest.gd`

**Interfaces:**
- Consumes: `Recoleccion.cupo_de("escuela_tecnica")` = 4 (Tarea 1) y el bloque `mesa_estudio` (Tarea 3).
- Produces: tipo `"escuela_tecnica"` en `PlantillasPuesto` (5×5, una puerta, 4 ventanas, 4 mesas de estudio, **sin baúl**), que funciona con `dimensiones`, `celdas`, `en_mundo`, `celda_de_servicio`, `celda_de_salida` (igual que el servicio), `fachada` y `puerta_de_entrada`. `PlantillasPuesto.celda_deposito()` devuelve `Vector3i.MAX` (= `Economia.SIN_DEPOSITO`) para una plantilla sin baúl. Carácter de plantilla `M` = `mesa_estudio`.

- [ ] **Step 1: Escribir la prueba que falla**

En `godot/scripts/PlantillasPuestoTest.gd`, reemplaza la última línea (`print("\n=== Las 13 pruebas de PlantillasPuesto pasaron correctamente ===")`) por:

```gdscript
	print("\n=== TEST 14: la escuela técnica es un puesto de una sola puerta con 4 mesas de estudio (una por aprendiz), ventanas y sin baúl ===")
	var tipo14 := "escuela_tecnica"
	assert(PlantillasPuesto.dimensiones(tipo14) == Vector2i(5, 5) and PlantillasPuesto.MATERIAL[tipo14] == "adobe")
	var base14: Dictionary = PlantillasPuesto.celdas(tipo14, 0)
	var conteo14 := {"puerta_inferior": 0, "vidrio": 0, "baul": 0, "mesa_estudio": 0}
	for c14 in base14:
		if conteo14.has(base14[c14]):
			conteo14[base14[c14]] += 1
	assert(conteo14["puerta_inferior"] == 1 and conteo14["vidrio"] >= 2, "una puerta y ventanas: %s" % [conteo14])
	assert(conteo14["mesa_estudio"] == Recoleccion.cupo_de(tipo14), "una mesa de estudio por aprendiz: %s" % [conteo14])
	assert(conteo14["baul"] == 0, "sin baúl: no maneja recursos")
	var libres14 := 0
	for x14 in range(1, 4):
		for z14 in range(1, 4):
			if not base14.has(Vector3i(x14, 1, z14)) and base14.has(Vector3i(x14, PlantillasPuesto.altura(tipo14) - 1, z14)):
				libres14 += 1
	assert(libres14 >= Recoleccion.cupo_de(tipo14) + 1, "el piso libre y techado alcanza para los aprendices más el vestíbulo (%d libres)" % libres14)
	var vestibulo14 := Vector3i(2, 1, 1)
	assert(not base14.has(vestibulo14) and not base14.has(vestibulo14 + Vector3i(0, 1, 0)), "el vestíbulo detrás de la puerta está libre")
	var alcanzadas14 := {vestibulo14: true}
	var pendientes14: Array[Vector3i] = [vestibulo14]
	while not pendientes14.is_empty():
		var actual14: Vector3i = pendientes14.pop_back()
		for dir14 in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var vecina14: Vector3i = actual14 + dir14
			if vecina14.x < 1 or vecina14.x > 3 or vecina14.z < 1 or vecina14.z > 3 or base14.has(vecina14) or alcanzadas14.has(vecina14):
				continue
			alcanzadas14[vecina14] = true
			pendientes14.append(vecina14)
	assert(alcanzadas14.size() == libres14, "todo el piso libre del interior es alcanzable desde el vestíbulo")
	for giros14 in range(4):
		assert(PlantillasPuesto.celda_de_salida(tipo14, giros14) == PlantillasPuesto.celda_de_servicio(tipo14, giros14), "con una sola puerta, salida == servicio")
		assert(PlantillasPuesto.fachada(tipo14, giros14).size() == 10, "2 columnas de fondo por los 5 del lado de la puerta")
		assert(PlantillasPuesto.celda_deposito(tipo14, giros14) == Vector3i.MAX, "sin baúl no hay depósito")
	for tipo14b in TIPOS:
		assert(PlantillasPuesto.celda_deposito(tipo14b, 0) != Vector3i.MAX, tipo14b + ": los puestos de recolección siguen teniendo depósito")
	var mundo14: Node = _mundo()
	for bloque14 in base14.values():
		assert(mundo14._id_por_tipo.has(bloque14), "falta el bloque " + bloque14)

	print("\n=== Las 14 pruebas de PlantillasPuesto pasaron correctamente ===")
```

- [ ] **Step 2: Correr la prueba y verificar que falla**

Run: `correr PlantillasPuestoTest`
Expected: `SCRIPT ERROR` (índice inexistente `escuela_tecnica` en `MATERIAL`/`PLANTILLAS`), no aparece «Las 14 pruebas».

- [ ] **Step 3: Implementar la plantilla**

En `godot/scripts/PlantillasPuesto.gd`:

(a) En `BLOQUES` (línea ~24) añade `"M": "mesa_estudio",` (por ejemplo, junto a `"V": "vidrio", "B": "baul",`).

(b) Dentro de `MATERIAL` (tras `"aserradero": "bloque_madera",`) añade:

```gdscript
	"escuela_tecnica": "adobe",
```

(c) Dentro de `PLANTILLAS`, tras la entrada del `aserradero` (antes del `}` de cierre del diccionario, línea ~112), añade:

```gdscript
	# Escuela técnica (primer edificio de investigación): una sola puerta (como un puesto) y un interior de
	# 3 x 3 con 4 mesas de estudio (M, una por aprendiz) al fondo y a un lado; quedan 4 sitios libres más el
	# vestíbulo. Sin baúl: no maneja recursos (ver celda_deposito()).
	"escuela_tecnica": {"capas": [
		["#####", "#####", "#####", "#####", "#####"],
		["##d##", "#...#", "#..M#", "#MMM#", "#####"],
		["##D##", "V...V", "#...#", "V...V", "#####"],
		["#####", "#####", "#####", "#####", "#####"],
	]},
```

(d) Reemplaza `celda_deposito()` (y su comentario) por:

```gdscript
## Celda local (x, capa, z) girada del baúl que hace de depósito del puesto; Vector3i.MAX (igual que
## Economia.SIN_DEPOSITO) si la plantilla no lleva baúl, como la escuela técnica.
static func celda_deposito(tipo: String, giros: int) -> Vector3i:
	if not celdas(tipo, 0).values().has("baul"):
		return Vector3i.MAX
	var d := dimensiones(tipo)
	return _girar(_buscar(tipo, "baul"), d.x, d.y, giros)
```

- [ ] **Step 4: Correr la prueba y verificar que pasa**

Run: `correr PlantillasPuestoTest`
Expected: «Las 14 pruebas de PlantillasPuesto pasaron correctamente», sin `Assertion failed`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/PlantillasPuesto.gd godot/scripts/PlantillasPuestoTest.gd
git commit -m "feat: plantilla de la escuela técnica

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Colocación en la cenital y menú Construir → Investigación

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd` (`PUESTOS_INVESTIGACION`, `_manejar_tecla_construir`, `_alternar_puesto_por_tipo`, `_evaluar_puesto`, `_mensaje_rechazo_puesto`, bloque de previsualización ~línea 963)
- Modify: `godot/scripts/Player.gd:1102` (registro del puesto nuevo)
- Modify: `godot/scripts/HUD.gd` (`texto_tasas`)
- Modify: `godot/scripts/BarraModos.gd` (categoría Investigación, miniatura)
- Test: `godot/scripts/PuestosPrevisualizacionTest.gd`, `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `Recoleccion.ESCUELAS` (Tarea 1), plantilla `escuela_tecnica` (Tarea 4), `Zonificacion.ZONAS_PINTABLES[0]` (residencial).
- Produces: `CamaraCenital.PUESTOS_INVESTIGACION := ["escuela_tecnica"]`; la tecla `4` → `1` o el botón «Escuela técnica» activan la colocación; `_evaluar_puesto()` rechaza fuera de la zona de influencia o fuera de zona residencial para una escuela, con mensajes que contienen «zona de influencia» y «zona residencial».

- [ ] **Step 1: Escribir las pruebas que fallan**

(a) En `godot/scripts/PuestosPrevisualizacionTest.gd`, reemplaza la última línea (`print("\n=== Las 13 pruebas de previsualización de puestos pasaron correctamente ===")`) por:

```gdscript
	print("\n=== TEST 14: la escuela técnica solo se coloca dentro de la zona de influencia y sobre zona residencial ===")
	Recoleccion.puestos.clear()
	var mundo14: Node = _mundo_plano()
	var esquina14 := Vector2i(24, 18)
	var camara14: Camera3D = _camara(mundo14, "escuela_tecnica")
	var ev14: Dictionary = camara14._evaluar_puesto(esquina14)
	var mensaje14: String = camara14._mensaje_rechazo_puesto(ev14)
	assert("zona de influencia" in mensaje14 and "escuela" in mensaje14, "sin núcleo declarado está fuera de la zona de influencia: %s" % mensaje14)
	Zonificacion.declarar_nucleo([Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 31), Vector2i(31, 31)])
	ev14 = camara14._evaluar_puesto(esquina14)
	assert("zona residencial" in camara14._mensaje_rechazo_puesto(ev14), "dentro de la influencia pero sin zona pintada: %s" % camara14._mensaje_rechazo_puesto(ev14))
	Zonificacion.pintar_zona(esquina14, esquina14 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[1])
	ev14 = camara14._evaluar_puesto(esquina14)
	assert("zona residencial" in camara14._mensaje_rechazo_puesto(ev14), "una zona industrial tampoco sirve: %s" % camara14._mensaje_rechazo_puesto(ev14))
	Zonificacion.pintar_zona(esquina14, esquina14 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[0])
	ev14 = camara14._evaluar_puesto(esquina14)
	assert(camara14._mensaje_rechazo_puesto(ev14) == "", "dentro de la influencia y sobre zona residencial es válida: %s" % camara14._mensaje_rechazo_puesto(ev14))
	assert(ev14["fachada"].size() == 10, "fachada de un solo lado (%d)" % ev14["fachada"].size())
	assert(not camara14._resumen_materiales_puesto(esquina14, ev14)["neto"].is_empty(), "construirla cuesta materiales")
	Zonificacion.despintar_zona(esquina14 + Vector2i(0, 4), esquina14 + Vector2i(4, 4))
	assert("zona residencial" in camara14._mensaje_rechazo_puesto(camara14._evaluar_puesto(esquina14)), "toda la huella debe estar sobre zona residencial")
	Zonificacion.pintar_zona(esquina14, esquina14 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[0])
	camara14.hud = HUDScript.new()
	add_child(camara14.hud)
	camara14._confirmar_puesto(esquina14)
	var info14: Dictionary = {}
	for meta14 in mundo14.edificio_metadata.values():
		if meta14.has("puesto_nuevo") and meta14["puesto_nuevo"]["tipo"] == "escuela_tecnica":
			info14 = meta14["puesto_nuevo"]
	assert(not info14.is_empty(), "colocar la escuela inicia su construcción")
	assert(info14["deposito"] == Economia.SIN_DEPOSITO, "sin baúl, el puesto se registra sin depósito")
	camara14.free()
	Zonificacion.nucleo_declarado = false  # no contaminar otras pruebas de esta escena
	mundo14.free()

	print("\n=== Las 14 pruebas de previsualización de puestos pasaron correctamente ===")
```

(b) En `godot/scripts/HUDTest.gd`, reemplaza el bloque del TEST 3a-bis (líneas 359-363) por:

```gdscript
	print("=== TEST 3a-bis: Investigación tiene la Escuela técnica; Industrial no tiene un botón con su propio id ===")
	barra.set_modo("construir", "", "investigacion")
	assert(barra._paneles_construccion["investigacion"].visible)
	assert(barra._botones_construccion.has("escuela_tecnica"), "Investigación ofrece la escuela técnica")
	assert(not barra._botones_construccion.has("industrial"), "no hay ningún tipo de edificio con id 'industrial'")
	barra.set_modo("")
```

y en el TEST 3e cambia los dos `9` por `10` y su texto (líneas 385 y 388):

```gdscript
	assert(barra._viewports_construccion.size() == 10, "una construcción con malla real por cada uno de los 10 tipos con miniatura (mina/caza/madera/pesca/las 4 refinerías/la escuela + residencial con el blueprint declarado arriba)")
```

```gdscript
	assert(barra._viewports_construccion.size() == 10, "sigue habiendo un solo SubViewport trackeado por tipo tras varias rotaciones, no uno acumulado por cada llamada")
```

- [ ] **Step 2: Correr las pruebas y verificar que fallan**

Run: `correr PuestosPrevisualizacionTest` y `correr HUDTest`
Expected: en la primera, `SCRIPT ERROR`/`Assertion failed` (la escuela se evalúa como puesto periférico: mensaje «No se puede colocar un puesto dentro de la zona de influencia» o error por el área de maderero); en la segunda, `Assertion failed` por el botón `escuela_tecnica`.

- [ ] **Step 3: Implementar en `CamaraCenital.gd`**

(a) Junto a `PUESTOS_INDUSTRIAL` (línea 1286) añade:

```gdscript
const PUESTOS_INVESTIGACION := ["escuela_tecnica"]
```

(b) En `_manejar_tecla_construir()` (línea ~1390), añade tras el caso `"industrial"`:

```gdscript
			"investigacion":
				if n >= 1 and n <= PUESTOS_INVESTIGACION.size():
					_alternar_puesto_por_tipo(PUESTOS_INVESTIGACION[n - 1])
```

y en el comentario previo (líneas 1381-1384) sustituye «Industrial/Investigación, que todavía no tienen edificios» por «una categoría con menos edificios».

(c) En `_alternar_puesto_por_tipo()` (línea 1488) cambia el caso por:

```gdscript
		"siderurgica", "refineria_tierras_raras", "aserradero", "carbonera", "escuela_tecnica":
```

(d) En el bloque de previsualización (línea 963) cambia la condición y su comentario:

```gdscript
		elif CadenaMinerales.REFINERIAS.has(_tipo_puesto_activo) or Recoleccion.ESCUELAS.has(_tipo_puesto_activo):
			_ocultar_area_accion()  # ni una refinería ni una escuela tienen área de acción ni tasa de recolección
```

(d2) En `_confirmar_puesto()` (línea ~2439), una plantilla sin baúl devuelve `Vector3i.MAX` de `celda_deposito()`; sumarle la esquina desbordaría. Reemplaza las dos líneas del depósito por:

```gdscript
	var deposito_local: Vector3i = PlantillasPuesto.celda_deposito(_tipo_puesto_activo, giros)
	var deposito := Economia.SIN_DEPOSITO  # una plantilla sin baúl (la escuela) no tiene depósito
	if deposito_local != Vector3i.MAX:
		deposito = Vector3i(esquina.x + deposito_local.x, y_base + deposito_local.y, esquina.y + deposito_local.z)
```

(e) En `_evaluar_puesto()` (líneas 2169-2199) reemplaza la declaración de `es_refineria` y las tres claves que la usan. Antes de `var dentro_de_influencia` deja:

```gdscript
	var es_refineria: bool = CadenaMinerales.REFINERIAS.has(_tipo_puesto_activo)
	var es_escuela: bool = Recoleccion.ESCUELAS.has(_tipo_puesto_activo)
	var es_urbano: bool = es_refineria or es_escuela  # se construyen dentro de la zona de influencia, los demás puestos fuera
```

y en el diccionario:

```gdscript
		"en_influencia": dentro_de_influencia and not es_urbano,  # los puestos periféricos no pueden ir dentro
		"fuera_de_influencia": es_urbano and not dentro_de_influencia,  # las refinerías y la escuela solo pueden ir dentro
		"zona_correcta": not es_urbano or _huella_en_zona_correcta(esquina, columnas, Zonificacion.ZONAS_PINTABLES[0 if es_escuela else 1]),  # la escuela, sobre residencial; las refinerías, sobre industrial
```

(f) En `_mensaje_rechazo_puesto()` (líneas 2219-2225) deja el `if ev["en_influencia"]:` como está y reemplaza los dos `if` siguientes (`fuera_de_influencia` y `zona_correcta`) por:

```gdscript
	var es_escuela: bool = Recoleccion.ESCUELAS.has(_tipo_puesto_activo)
	if ev["fuera_de_influencia"]:
		return "Colocación rechazada: %s solo puede construirse dentro de la zona de influencia." % ("una escuela" if es_escuela else "una refinería")
	if not ev["zona_correcta"]:
		if es_escuela:
			return "Colocación rechazada: una escuela solo puede construirse sobre una zona residencial."
		return "Colocación rechazada: una refinería solo puede construirse sobre una zona industrial."
```

- [ ] **Step 4: Implementar en `Player.gd`**

En `_completar_construccion()` (línea 1102) cambia la condición para que la escuela tampoco calcule un entorno de recolección:

```gdscript
			if not CadenaMinerales.REFINERIAS.has(info["tipo"]) and not Recoleccion.ESCUELAS.has(info["tipo"]):
```

- [ ] **Step 5: Implementar en `HUD.gd`**

En `texto_tasas()` (línea 213), antes de `if CadenaMinerales.REFINERIAS.has(tipo):`, añade (y haz que el nombre de cada tipo salga de `VentanaPoblacion.NOMBRES_TIPO`; comprueba con `grep -n "NOMBRES_TIPO" godot/scripts/VentanaPoblacion.gd` que es una `const` y con `grep -n "VentanaPoblacion" godot/scripts/HUD.gd` si ya hay un `preload` para no duplicarlo):

```gdscript
	if Recoleccion.ESCUELAS.has(tipo):
		var escuela: Dictionary = Recoleccion.ESCUELAS[tipo]
		var nombres: Dictionary = VentanaPoblacionScript.NOMBRES_TIPO
		return "Forma una cohorte de %d %s en %d %s\n  (%d h de estudio)" % [Ciudad.TIPOS_POBLACION[escuela["origen"]]["x_cama"], nombres[escuela["origen"]].to_lower(), Ciudad.TIPOS_POBLACION[escuela["destino"]]["x_cama"], nombres[escuela["destino"]].to_lower(), Economia.HORAS_FORMACION]
```

y, si no existía, junto a los demás `preload` de la parte alta de `HUD.gd` añade `const VentanaPoblacionScript = preload("res://scripts/VentanaPoblacion.gd")`.

- [ ] **Step 6: Implementar en `BarraModos.gd`**

(a) En `CONSTRUCCIONES_POR_CATEGORIA` cambia `"investigacion": [],` por:

```gdscript
	"investigacion": [
		["escuela_tecnica", "Escuela técnica", "1"],
	],
```

(b) Añade `"escuela_tecnica"` al final de `TIPOS_CON_MINIATURA` (línea 85).

(c) Actualiza el comentario de `CATEGORIAS` (líneas 46-49): la categoría Investigación ya tiene la escuela técnica (quita «solo Investigación no tiene edificios todavía…»).

(d) En `_refrescar()` (línea 386) incluye la categoría nueva para que se rendericen sus miniaturas:

```gdscript
	if _modo == "construir" and (_categoria == "residencial" or _categoria == "periferico" or _categoria == "investigacion"):
```

- [ ] **Step 7: Correr las pruebas y verificar que pasan**

Run: `correr PuestosPrevisualizacionTest` → «Las 14 pruebas de previsualización de puestos pasaron correctamente».
Run: `correr HUDTest` → «HUDTest: todas las pruebas pasaron».
Run: `correr CamaraCenitalModosTest` → sin fallos (toca `_manejar_tecla_construir`).
En todas, sin `Assertion failed` / `SCRIPT ERROR`.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/CamaraCenital.gd godot/scripts/Player.gd godot/scripts/HUD.gd godot/scripts/BarraModos.gd godot/scripts/PuestosPrevisualizacionTest.gd godot/scripts/HUDTest.gd
git commit -m "feat: colocar la escuela técnica sobre zona residencial desde Construir -> Investigación

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Panel del puesto, ventana de población y notificación

**Files:**
- Modify: `godot/scripts/PanelPuesto.gd`
- Modify: `godot/scripts/VentanaPoblacion.gd`
- Modify: `godot/scripts/Main.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `Economia.es_escuela()`, `Economia.HORAS_FORMACION`, `Colonos.tecnicos_libres()`, `Colonos.tecnicos_formados` (Tareas 1-2), `puesto["progreso"]`.
- Produces: `PanelPuesto.NOMBRES_PUESTO["escuela_tecnica"]` = «Escuela técnica»; fila «Aprendices» con +/-; la fila «Acarreadores» se oculta en una escuela; la línea de libres dice «Técnicos libres» en una refinería.

- [ ] **Step 1: Escribir la prueba que falla**

En `godot/scripts/HUDTest.gd` añade, junto a los demás `const ... = preload`, `const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")`; en `ejecutar_pruebas()` añade la llamada `probar_panel_escuela()` después de `probar_ventanas_datos()`; y al final del archivo añade la función:

```gdscript
func probar_panel_escuela() -> void:
	print("=== TEST 7: PanelPuesto de una escuela técnica (aprendices, progreso) y de una refinería (técnicos libres) ===")
	var esquina7 := Vector2i(900, 900)
	var esquina7r := Vector2i(930, 900)
	Economia.registrar_puesto(esquina7, "escuela_tecnica", 5, 5, {})
	Economia.registrar_puesto(esquina7r, "siderurgica", 5, 5, {})
	var panel: PanelContainer = PanelPuestoScript.new()
	add_child(panel)
	panel.abrir(esquina7)
	assert(panel._titulo.text == "Escuela técnica")
	assert(panel._filas["aprendiz"]["fila"].visible and not panel._filas["recolector"]["fila"].visible and not panel._filas["tecnico"]["fila"].visible)
	assert(not panel._filas["acarreador"]["fila"].visible, "una escuela no tiene acarreadores")
	assert(not panel._almacen.visible and not panel._produccion.visible, "ni almacén local ni producción")
	assert("Aprendices: 0 / 4" in panel._trabajadores.text and "0 / %d h" % Economia.HORAS_FORMACION in panel._trabajadores.text, "cohorte y horas: %s" % panel._trabajadores.text)
	panel.abrir(esquina7r)
	assert(panel._filas["tecnico"]["fila"].visible and not panel._filas["aprendiz"]["fila"].visible and panel._filas["acarreador"]["fila"].visible)
	assert(panel._almacen.visible and "Técnicos libres: %d" % Colonos.tecnicos_libres() in panel._libres.text, "la refinería pide técnicos libres: %s" % panel._libres.text)
	panel.queue_free()
	Economia.puestos.erase(esquina7)
	Economia.puestos.erase(esquina7r)
```

- [ ] **Step 2: Correr la prueba y verificar que falla**

Run: `correr HUDTest`
Expected: `SCRIPT ERROR` por la fila `"aprendiz"` inexistente en `_filas`, y no aparece «HUDTest: todas las pruebas pasaron».

- [ ] **Step 3: Implementar `PanelPuesto.gd`**

(a) En `NOMBRES_PUESTO` añade `"escuela_tecnica": "Escuela técnica",` y reemplaza `NOMBRES_ROL` por:

```gdscript
const NOMBRES_ROL := {"recolector": "Recolectores", "tecnico": "Técnicos", "aprendiz": "Aprendices", "acarreador": "Acarreadores"}
```

(b) En `_ready()` cambia el bucle de filas (línea 49) por `for rol in ["recolector", "tecnico", "aprendiz", "acarreador"]:` y actualiza el comentario de cabecera del archivo (líneas 3-7) para mencionar «Aprendices».

(c) Reemplaza `_actualizar()` completo (líneas 103-127) por:

```gdscript
func _actualizar() -> void:
	var puesto: Dictionary = Economia.puestos[esquina]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var es_escuela: bool = Economia.es_escuela(esquina)
	var rol_produccion := "aprendiz" if es_escuela else ("tecnico" if Economia.es_refineria(esquina) else "recolector")
	# Quién se puede contratar: técnicos libres (formados en la escuela) para una refinería, desempleados para el resto.
	var libres: int = Colonos.tecnicos_libres() if rol_produccion == "tecnico" else Ciudad.demografia["desempleado"]
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"]) + estado
	for rol in ["recolector", "tecnico", "aprendiz"]:
		_filas[rol]["fila"].visible = rol == rol_produccion
	_filas["acarreador"]["fila"].visible = not es_escuela  # una escuela no mueve recursos
	_filas[rol_produccion]["cantidad"].text = str(t["recolectores"])  # técnicos y aprendices cuentan bajo "recolectores"
	_filas["acarreador"]["cantidad"].text = str(t["acarreadores"])
	_filas[rol_produccion]["menos"].disabled = t["recolectores"] == 0
	_filas["acarreador"]["menos"].disabled = t["acarreadores"] == 0
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0
	_filas[rol_produccion]["mas"].disabled = sin_cupo or libres <= 0 or not puesto["activo"] or puesto["agotado"]
	_filas["acarreador"]["mas"].disabled = sin_cupo or Ciudad.demografia["desempleado"] <= 0 or not puesto["activo"]
	if es_escuela:
		_trabajadores.text = "Aprendices: %d / %d (presentes: %d)\nFormación de la cohorte: %d / %d h" % [t["recolectores"], puesto["cupo"], t["presentes"], int(puesto["progreso"]), Economia.HORAS_FORMACION]
	else:
		_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	_libres.text = ("Técnicos libres: %d" if rol_produccion == "tecnico" else "Desempleados libres: %d") % libres
	_almacen.visible = not es_escuela
	_produccion.visible = not es_escuela
	_almacen.text = "Almacén local: " + _texto_recursos(Economia.almacen_local(esquina), "vacío") + " (máx. %d)" % puesto["capacidad"]
	_produccion.text = "Producción: " + _texto_recursos(Economia.produccion_por_hora(esquina), "ninguna", "/h")
	_distancia.text = "Distancia al núcleo: %s" % _distancia_al_nucleo()
```

- [ ] **Step 4: Implementar `VentanaPoblacion.gd`**

En el bucle de puestos de `_actualizar()` (líneas 100-105), tras calcular `nombre` y antes de la línea de `rol_produccion`, añade:

```gdscript
		if Economia.es_escuela(esquina):
			_caja.add_child(TemaHUD.etiqueta("  %s: %d aprendices" % [nombre, t["recolectores"]]))
			continue
```

- [ ] **Step 5: Implementar la notificación en `Main.gd`**

Tras la línea 33 (`Colonos.colono_creado.connect(...)`) añade:

```gdscript
	Colonos.tecnicos_formados.connect(func(cantidad: int) -> void: hud.notificar("Se formaron %d técnicos." % cantidad))
```

- [ ] **Step 6: Correr la prueba y verificar que pasa**

Run: `correr HUDTest` → «HUDTest: todas las pruebas pasaron», sin `Assertion failed` / `SCRIPT ERROR`.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/PanelPuesto.gd godot/scripts/VentanaPoblacion.gd godot/scripts/Main.gd godot/scripts/HUDTest.gd
git commit -m "feat: panel de aprendices, técnicos libres y aviso de técnicos formados

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Documentación y verificación final

**Files:**
- Modify: `docs/Pendientes y próximos pasos.md`
- Modify: `docs/Fichas_Consumo_Produccion.md`
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`

- [ ] **Step 1: `docs/Pendientes y próximos pasos.md`**

En el punto 4 («~~**Parte 2, resto:** ...»), al final del párrafo sustituye la frase «**Pendiente:** la formación de técnicos (hoy provisional).» por:

```
La formación de técnicos ✅ está hecha (2026-10-01): la **Escuela técnica** (primer edificio de investigación, sobre zona residencial dentro de la influencia, con 4 mesas de estudio —bloque nuevo `mesa_estudio`— en vez de baúl) forma cohortes de 4 obreros que estudian 24 h y salen como 3 técnicos libres (la vivienda ocupada se conserva con `x_cama`; el cuarto colono se va de la ciudad); las refinerías solo contratan técnicos libres y un técnico despedido sigue siendo técnico. Spec: `docs/superpowers/specs/2026-10-01-escuela-tecnica-design.md`.
```

En el punto 6 («Construcción/deconstrucción asistida por NPCs») añade una línea al final de ese bloque: `Los técnicos libres (sin puesto) también harán obras de construcción, demolición y tendido de vías, igual que los obreros desempleados.`

- [ ] **Step 2: `docs/Fichas_Consumo_Produccion.md`**

Sustituye la línea `- **Técnico:** opera las refinerías (siderúrgica). Origen provisional: ...` (línea 30) por:

```
- **Técnico:** opera las refinerías. Se forma en la **Escuela técnica**: una cohorte de 4 obreros (`x_cama` 4) estudia 24 h y sale como 3 técnicos (`x_cama` 3), de modo que la vivienda ocupada se conserva (4 × 1/4 = 3 × 1/3) y el cuarto colono se va de la ciudad. Un técnico sin puesto (técnico libre) conserva el oficio y también podrá trabajar en obras como un obrero desempleado. Las refinerías ya no convierten desempleados.
```

Y en la línea 165 sustituye `- Formación de técnicos: hoy un desempleado se vuelve técnico al asignarlo (provisional).` por `- Formación de especialistas (escuela propia, solo con técnicos libres): sin diseñar; ver docs/ideas-backlog.md.`

- [ ] **Step 3: Documento técnico de PoC 5**

En la sección de la siderúrgica, sustituye la viñeta `* **Técnicos:** un desempleado pasa a técnico al asignarlo (provisional); compite con los obreros por los desempleados.` por:

```
* **Técnicos:** solo se contratan técnicos libres, formados en la Escuela técnica (ver abajo); un técnico despedido sigue siendo técnico.
```

Añade, justo antes de `Ver docs/superpowers/specs/2026-09-30-siderurgica-real-design.md.`, una subsección:

```
### Escuela técnica (2026-10-01)

Decisión funcional: la formación de técnicos es un puesto más de `Economia.puestos` (`escuela_tecnica`, plantilla de 5×5 de adobe con una puerta y 4 mesas de estudio —bloque nuevo `mesa_estudio`, 1 madera como un baúl—, sin baúl porque no maneja recursos; se coloca dentro de la zona de influencia y sobre zona residencial). Su rol es `aprendiz` (cupo 4 = la cohorte, comparte la lista de recolectores). La cohorte suma 1 h de estudio por hora de juego solo mientras los 4 aprendices están presentes (se pausa si falta uno y se reinicia con menos de 4); a `Economia.HORAS_FORMACION` (24) se gradúan: 3 pasan a técnico libre y el cuarto se va de la ciudad, porque cada jerarquía ocupa más vivienda (`Ciudad.TIPOS_POBLACION[...]["x_cama"]`: 4 obreros = 3 técnicos). Un aprendiz cuenta como obrero mientras estudia. Un técnico despedido o liberado (p. ej. al deconstruir su refinería) sigue siendo técnico. Ver `docs/superpowers/specs/2026-10-01-escuela-tecnica-design.md`.
```

En «Próximos Pasos», elimina la viñeta `* **Formación de técnicos** — hoy un desempleado se vuelve técnico al asignarlo (provisional).` y sustitúyela por `* **Formación de técnicos** — ✅ hecha (2026-10-01), ver «Escuela técnica». La de especialistas, los niveles de edificio y la universidad están en `docs/ideas-backlog.md`.`

- [ ] **Step 4: Verificación final**

Corre, una por una, todas las escenas afectadas y la general (según `CLAUDE.md`: `Test.tscn` más las `*Test.tscn` afectadas):

```bash
for t in EconomiaTest ColonosTest PlantillasPuestoTest PuestosPrevisualizacionTest HUDTest RecoleccionTest CamaraCenitalModosTest CiudadTest CadenaMineralesTest Test; do echo "== $t"; correr $t; done
```

Expected: cada escena imprime su línea final de éxito y **ninguna** imprime `Assertion failed`, `SCRIPT ERROR` ni `Parse Error`. Si alguna falla, arréglala antes de seguir (no la ignores aunque «parezca no relacionada»).

Verificación manual (opcional, recomendada por el mantenedor): abre `godot/scenes/Main.tscn`, declara un edificio residencial, pinta una zona residencial dentro de la influencia, elige Construir → Investigación → Escuela técnica, colócala, asigna 4 aprendices desde su panel y comprueba que tras 24 h de juego aparece «Se formaron 3 técnicos.», que 3 colonos cambian de naranja (obrero) a azul (técnico) y que luego se pueden asignar a una siderúrgica.

- [ ] **Step 5: Commit**

```bash
git add "docs/Pendientes y próximos pasos.md" docs/Fichas_Consumo_Produccion.md "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md"
git commit -m "docs: escuela técnica y técnicos libres

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
