# Economía de construcción para puestos periféricos — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Los 4 puestos de recolección (mina, maderero, caza y recolección, pesca y frutos del mar) dejan de estamparse al instante y pasan por la misma cola de construcción fantasma pagada que ya usan los edificios residenciales — excavar acredita, rellenar/surtir estructura cobra, y el puesto solo se activa (produce, acepta personal) al completarse.

**Architecture:** `CamaraCenital._procesar_clic_puesto()` deja de llamar `VoxelWorld.estampar_puesto()` y en su lugar arma `relleno_orden`/`tipos_relleno`/`orden_estructura`/`tipos_estructura` y llama `iniciar_construccion_fantasma()`, exactamente como ya hace `_procesar_clic_blueprint()` para un residencial (reutilizando `_plan_nivelacion()` para la nivelación no-pesca, con un cálculo propio solo para los pilotes/relleno de pesca). `Player._completar_construccion()` gana una rama nueva (`metadata["puesto_nuevo"]`) que registra el puesto en `Recoleccion`/`Economia` al completarse, en vez de en el clic. Todo el cobro/acreditación/reembolso (`_bloqueado_por_falta_de()`, `_acreditar_excavacion()`, `celdas_pagadas`, `Player._intervalo_accion_actual()`) ya existe y no cambia — solo se alimenta con datos de puesto en vez de residencial.

**Tech Stack:** Godot 4.7, GDScript (tabulaciones), pruebas basadas en `assert()` corridas desde escenas `*Test.tscn`.

**Spec:** `docs/superpowers/specs/2026-09-29-economia-construccion-puestos-design.md` (y, para el mecanismo de cobro/reembolso ya existente que esto reutiliza, `docs/superpowers/specs/2026-09-29-costo-colocacion-bloques-design.md`).

## Global Constraints

- Tabulaciones en GDScript, comentarios en español, sin `.godot/`/`.godot-mcp/`/`.superpowers/` ni cachés de Python (CLAUDE.md).
- El drenado de agua sigue siendo instantáneo y gratis (el agua no es un recurso).
- El puesto NO debe aparecer en `Recoleccion`/`Economia` (ni aceptar personal) hasta que `surtir_construccion()` marque la obra completa.
- Reutilizar `_plan_nivelacion()`/`_bloqueado_por_falta_de()`/`_acreditar_excavacion()`/`celdas_pagadas` tal cual existen — no duplicar su lógica.
- Verificación: correr `godot/scenes/Test.tscn` y cada `*Test.tscn` afectado con Godot 4.7, confirmar que todas las aserciones pasan (CLAUDE.md).

## Review Focus

- Colocar un puesto de pesca (el único con pilotes) debe cobrar piedra por cada pilote y tierra por el resto del relleno, saltando las columnas con agua real (nunca cobra ni acredita agua).
- El puesto NO debe poder recibir personal ni producir mientras sigue siendo fantasma/a medias — solo tras completarse.
- Deconstruir un puesto YA completado debe reembolsar exactamente lo que costó construirlo (ya cubierto por el mecanismo existente, pero hay que confirmar que las celdas de la plantilla del puesto quedan marcadas en `celdas_pagadas` igual que las de un residencial).
- Si falta el recurso a mitad de construir un puesto (relleno, pilote o estructura), el paso debe rechazarse sin perder nada ya cobrado, igual que un residencial.
- El camino existente de reactivar un puesto YA construido que se estaba deconstruyendo (metadata `{"puesto": esquina}`, `Economia.reactivar_puesto()`) no debe romperse por la rama nueva `{"puesto_nuevo": ...}`.

---

## Mapa de archivos

- `godot/scripts/CamaraCenital.gd` — `_procesar_clic_puesto()` reescrita; nada más cambia (la previsualización del fantasma, `_actualizar_fantasma_puesto()`, sigue igual — es solo visual, no toca el mundo).
- `godot/scripts/Player.gd` — `_completar_construccion()` gana la rama `puesto_nuevo`.
- `godot/scripts/VoxelWorld.gd` — sin cambios (todo lo que necesita ya existe: `iniciar_construccion_fantasma`, `_bloqueado_por_falta_de`, `_acreditar_excavacion`, `registrar_follaje_pendiente`, `ordenar_celdas_edificio`).
- `godot/scripts/PuestosPrevisualizacionTest.gd` — nueva prueba de integración para el flujo completo.
- `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md`, `docs/Fichas_Consumo_Produccion.md` — actualización final.

---

### Task 1: `_procesar_clic_puesto()` arma la cola de construcción en vez de estampar

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd:1981-2080` (`_procesar_clic_puesto()`)
- Test: `godot/scripts/PuestosPrevisualizacionTest.gd` (Step 4 de esta tarea)

**Interfaces:**
- Consumes: `VoxelWorld.iniciar_construccion_fantasma(orden_relleno, tipos_relleno, orden_estructura, tipos_estructura, metadata) -> int` (ya existe), `VoxelWorld.ordenar_celdas_edificio(celdas) -> Array` (ya existe), `VoxelWorld.registrar_follaje_pendiente(id, celdas) -> void` (ya existe), `CamaraCenital._plan_nivelacion(esquina, columnas, base_y, fachada) -> {"excavacion": Array[Vector3i], "relleno": Dictionary}` (ya existe, la misma que usa `_procesar_clic_blueprint()`).
- Produces: `_procesar_clic_puesto()` ya NO llama `VoxelWorld.estampar_puesto()` ni `Recoleccion.colocar_puesto()`/`Economia.registrar_puesto()`; en su lugar llama `iniciar_construccion_fantasma()` con `metadata = {"puesto_nuevo": {...}}` (formato consumido por Task 2).

- [ ] **Step 1: Leer el estado actual completo antes de tocarlo**

`_procesar_clic_puesto()` (líneas 1981-2080) y `_plan_nivelacion()` (líneas 1062-1070) ya están en el árbol; `_evaluar_puesto()` (líneas 1901-1951) ya devuelve `"columnas"`, `"fachada"`, `"resultado_base": {"base_y": y_base}` — el mismo formato que `_plan_nivelacion()` espera, así que para los puestos NO-pesca se puede llamar tal cual: `_plan_nivelacion(esquina, ev["columnas"], ev["resultado_base"]["base_y"], ev["fachada"])` cubre footprint (cava lo alto, rellena lo bajo) Y fachada en una sola llamada, igual que hace `_procesar_clic_blueprint()` para un residencial. Para `pesca_frutos_mar` el footprint sigue su cálculo propio de pilotes/agua (líneas 2015-2037 de hoy); llamar `_plan_nivelacion(esquina, [], ev["resultado_base"]["base_y"], ev["fachada"])` (columnas vacías) da SOLO la nivelación de la fachada, para combinarla con el relleno/pilotes propio de pesca.

- [ ] **Step 2: Reescribir `_procesar_clic_puesto()`**

Reemplaza `godot/scripts/CamaraCenital.gd:1981-2080` completo:

```gdscript
func _procesar_clic_puesto(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)
	var ev: Dictionary = _evaluar_puesto(esquina)
	var rechazo: String = _mensaje_rechazo_puesto(ev)
	if rechazo != "":
		print(rechazo)
		hud.notificar(rechazo)
		return
	var columnas: Array[Vector2i] = ev["columnas"]
	var extremo_agua_indice: int = ev["extremo_agua_indice"]
	var giros: int = ev["giros"]
	var objetivo: int = ev["objetivo"]
	var fachada: Dictionary = ev["fachada"]
	var y_base: int = ev["y_base"]
	var base_y: int = ev["resultado_base"]["base_y"]
	var celdas_plantilla: Dictionary = ev["celdas_plantilla"]
	var servicio: Vector2i = esquina + PlantillasPuesto.celda_de_servicio(_tipo_puesto_activo, giros)

	var centro_agua := Recoleccion.SIN_CENTRO
	if _tipo_puesto_activo == "pesca_frutos_mar":
		var celdas_extremo_pesca := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
		@warning_ignore("integer_division")
		centro_agua = esquina + celdas_extremo_pesca[celdas_extremo_pesca.size() / 2]

	# Drenar agua: instantáneo y gratis (el agua no es un recurso), igual que hoy.
	for celda_follaje in ev["resultado_huella"]["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			mundo.drenar_agua(esquina.x + dx, esquina.y + dz)

	# Cola de nivelación pagada: excavar acredita, rellenar cobra tierra,
	# un pilote de pesca cobra piedra (bloque_piedra) — mismo criterio que
	# _procesar_clic_blueprint() para un residencial.
	var relleno_orden: Array[Vector3i] = []
	var tipos_relleno: Dictionary = {}

	if _tipo_puesto_activo == "pesca_frutos_mar":
		var celdas_extremo := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
		var esquinas_pilote: Array[Vector2i] = [
			esquina + celdas_extremo[0],
			esquina + celdas_extremo[celdas_extremo.size() - 1],
		]
		for dx in range(_ancho_puesto_activo):
			for dz in range(_alto_puesto_activo):
				var x: int = esquina.x + dx
				var z: int = esquina.y + dz
				var xz := Vector2i(x, z)
				var es_pilote: bool = esquinas_pilote.has(xz)
				var es_agua_real: bool = mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) == "agua"
				if es_agua_real and not es_pilote:
					continue  # agua abierta bajo la plataforma: no se toca, no cuesta nada
				var fondo: int = mundo.altura_en(x, z, true)
				var bloque: String = "bloque_piedra" if es_pilote else "tierra"
				for h in range(fondo + 1, objetivo + 1):
					var celda_r := Vector3i(x, h, z)
					relleno_orden.append(celda_r)
					tipos_relleno[celda_r] = bloque
		var plan_fachada: Dictionary = _plan_nivelacion(esquina, [], base_y, fachada)
		for celda_e in plan_fachada["excavacion"]:
			relleno_orden.append(celda_e)
			tipos_relleno[celda_e] = "fantasma" if celdas_plantilla.has(celda_e) else "aire"
		for celda_relleno in plan_fachada["relleno"]:
			var cantidad: int = plan_fachada["relleno"][celda_relleno]
			var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y, true)
			for h in range(1, cantidad + 1):
				var celda_r := Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y)
				relleno_orden.append(celda_r)
				tipos_relleno[celda_r] = "tierra"
	else:
		var plan: Dictionary = _plan_nivelacion(esquina, columnas, base_y, fachada)
		for celda_e in plan["excavacion"]:
			relleno_orden.append(celda_e)
			tipos_relleno[celda_e] = "fantasma" if celdas_plantilla.has(celda_e) else "aire"
		for celda_relleno in plan["relleno"]:
			var cantidad: int = plan["relleno"][celda_relleno]
			var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y, true)
			for h in range(1, cantidad + 1):
				var celda_r := Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y)
				relleno_orden.append(celda_r)
				tipos_relleno[celda_r] = "tierra"

	_despejar_vias_de_fachada(fachada)

	var orden_estructura: Array = mundo.ordenar_celdas_edificio(celdas_plantilla)
	var deposito_local: Vector3i = PlantillasPuesto.celda_deposito(_tipo_puesto_activo, giros)
	var deposito := Vector3i(esquina.x + deposito_local.x, y_base + deposito_local.y, esquina.y + deposito_local.z)
	var metadata := {
		"puesto_nuevo": {
			"tipo": _tipo_puesto_activo,
			"esquina": esquina,
			"ancho": _ancho_puesto_activo,
			"alto": _alto_puesto_activo,
			"centro": centro,
			"centro_agua": centro_agua,
			"servicio": servicio,
			"deposito": deposito,
			"y_base": y_base,
		},
	}
	var id_edificio: int = mundo.iniciar_construccion_fantasma(relleno_orden, tipos_relleno, orden_estructura, celdas_plantilla, metadata)
	var follaje: Array = []
	follaje.append_array(ev["resultado_huella"]["follaje_a_eliminar"])
	follaje.append_array(ev["resultado_fachada"]["follaje_a_eliminar"])
	mundo.registrar_follaje_pendiente(id_edificio, follaje)
	print("Construcción fantasma del puesto '%s' iniciada en (%d, %d) — surtir para completarla." % [_tipo_puesto_activo, esquina.x, esquina.y])
```

Nota: `ev["resultado_huella"]["follaje_a_eliminar"]` se elimina dos veces en el código de arriba (una vez al drenar agua "instantáneo", igual que hoy hacía antes de estampar, y otra vez pasado a `registrar_follaje_pendiente`) — esto reproduce el comportamiento actual (el follaje de la huella se limpia de inmediato) mientras que el de la FACHADA pasa a limpiarse gradual como en un residencial; si al implementar se prefiere que TODO el follaje (huella + fachada) se limpie gradual por consistencia total con residencial, quitar el bucle `for celda_follaje in ev["resultado_huella"]["follaje_a_eliminar"]: mundo.eliminar_follaje(celda_follaje)` y dejar que `registrar_follaje_pendiente()` (que ya recibe huella + fachada) se encargue de ambas — decisión menor, sin impacto económico (el follaje nunca tuvo costo).

- [ ] **Step 3: Confirmar que no queda ninguna llamada suelta a `estampar_puesto`/`colocar_puesto`/`registrar_puesto` en el flujo de clic**

Run: `grep -n "estampar_puesto\|Recoleccion.colocar_puesto\|Economia.registrar_puesto" godot/scripts/CamaraCenital.gd`
Expected: sin resultados (todo se movió a `Player._completar_construccion()`, Task 2).

- [ ] **Step 4: Prueba de integración**

Agrega a `godot/scripts/PuestosPrevisualizacionTest.gd` (mismo patrón que TEST 6, instancia manual de `CamaraCenital`/`hud` sin escena):

```gdscript
	print("=== TEST 7: colocar un puesto arma una cola de construcción pagada, no lo estampa al instante ===")
	var mundo7: Node = _mundo_plano()
	var camara7: Camera3D = _camara(mundo7, "maderero")
	camara7.hud = HUDScript.new()
	add_child(camara7.hud)
	var esquina7 := Vector2i(20, 20)
	var ev7: Dictionary = camara7._evaluar_puesto(esquina7)
	assert(camara7._mensaje_rechazo_puesto(ev7) == "", "válida sobre suelo plano")
	for recurso7 in ["tierra", "madera", "piedra"]:
		Ciudad.almacen[recurso7].cantidad = 0.0
	camara7._procesar_clic_puesto(Vector2.ZERO)  # posicion_pantalla no se usa una vez fijado esquina7 vía _celda_bajo_mouse en la prueba real; aquí se llama directo con el mismo cálculo de esquina que _evaluar_puesto
```

`_procesar_clic_puesto()` recalcula `esquina` a partir de `_celda_bajo_mouse(posicion_pantalla)`, que depende del mouse/cámara reales — no disponibles en una `CamaraCenital` sin árbol. Para probar el flujo de clic aisladamente, factoriza la lógica de `_procesar_clic_puesto()` (Step 2) en dos partes: una función privada `_confirmar_puesto(esquina: Vector2i) -> void` con TODO el cuerpo de Step 2 desde `var ev: Dictionary = _evaluar_puesto(esquina)` en adelante, y `_procesar_clic_puesto(posicion_pantalla)` se reduce a calcular `esquina` y llamar `_confirmar_puesto(esquina)`. Así la prueba llama `camara7._confirmar_puesto(esquina7)` directamente, igual que ya hace `PuestosPrevisualizacionTest.gd` con `_evaluar_puesto()`/`_actualizar_fantasma_puesto()` hoy.

Con esa factorización, la prueba real:

```gdscript
	print("=== TEST 7: colocar un puesto arma una cola de construcción pagada, no lo estampa al instante ===")
	var mundo7: Node = _mundo_plano()
	var camara7: Camera3D = _camara(mundo7, "maderero")
	camara7.hud = HUDScript.new()
	add_child(camara7.hud)
	var esquina7 := Vector2i(20, 20)
	var ev7: Dictionary = camara7._evaluar_puesto(esquina7)
	assert(camara7._mensaje_rechazo_puesto(ev7) == "", "válida sobre suelo plano")
	for recurso7 in ["tierra", "madera", "piedra"]:
		Ciudad.almacen[recurso7].cantidad = 0.0
	camara7._confirmar_puesto(esquina7)
	var celda_muro_7: Vector3i = ev7["celdas_plantilla"].keys()[0]
	assert(mundo7.obtener_tipo(celda_muro_7) == "fantasma", "la plantilla queda como fantasma, no estampada")
	assert(not Recoleccion.puestos.has(esquina7), "no se registra en Recoleccion hasta completarse")
	camara7.hud.queue_free()
	camara7.free()
	mundo7.free()
```

(revisa el nombre real del diccionario/función de `Recoleccion` que lista puestos activos — por ejemplo `Recoleccion.puestos` o el que corresponda — con `grep -n "var puestos\|func tiene_puesto" godot/scripts/Recoleccion.gd` antes de escribir esta aserción).

- [ ] **Step 5: Correr las pruebas y confirmar RED antes de implementar, luego GREEN**

Run: `"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --quit-after 5 --path godot res://scenes/PuestosPrevisualizacionTest.tscn`
Expected (antes del Step 2): falla por `_confirmar_puesto`/comportamiento inexistente. Expected (después): pasa sin `SCRIPT ERROR`.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CamaraCenital.gd godot/scripts/PuestosPrevisualizacionTest.gd
git commit -m "feat: colocar un puesto arma una cola de construcción fantasma pagada, ya no lo estampa al instante"
```

---

### Task 2: `Player._completar_construccion()` activa el puesto solo al terminar

**Files:**
- Modify: `godot/scripts/Player.gd:1084-1119` (`_completar_construccion()`)
- Test: continúa TEST 7 de `PuestosPrevisualizacionTest.gd` (Task 1 Step 4), ampliada aquí

**Interfaces:**
- Consumes: `metadata["puesto_nuevo"]` (formato producido por Task 1), `Recoleccion.entorno_de_puesto(tipo, mundo, centro, altura, centro_agua) -> Dictionary`, `Recoleccion.tasas_de_entorno(tipo, mundo, entorno) -> Dictionary`, `Recoleccion.colocar_puesto(esquina, tipo, ancho, alto) -> void`, `Economia.registrar_puesto(esquina, tipo, ancho, alto, tasas, entorno, servicio, deposito, y_base) -> void` (todas ya existen).
- Produces: sin cambio de firma pública; `_completar_construccion()` reconoce un caso más.

- [ ] **Step 1: Agregar la rama `puesto_nuevo`, ANTES de la rama existente `metadata.has("puesto")`**

Modifica `godot/scripts/Player.gd:1084-1091` (justo al principio de `_completar_construccion()`, antes del `if metadata.has("puesto"):` que ya existe para reactivar un puesto interrumpido):

```gdscript
func _completar_construccion(metadata: Dictionary) -> void:
	if metadata.is_empty():
		return
	if metadata.has("puesto_nuevo"):
		var info: Dictionary = metadata["puesto_nuevo"]
		var centro: Vector2i = info["centro"]
		var altura: int = mundo.altura_en(centro.x, centro.y)
		var entorno: Dictionary = Recoleccion.entorno_de_puesto(info["tipo"], mundo, centro, altura, info["centro_agua"])
		var tasas: Dictionary = Recoleccion.tasas_de_entorno(info["tipo"], mundo, entorno)
		Recoleccion.colocar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"])
		Economia.registrar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"], tasas, entorno, info["servicio"], info["deposito"], info["y_base"])
		print("Puesto '%s' construido en (%d, %d)." % [info["tipo"], info["esquina"].x, info["esquina"].y])
		hud.notificar("Puesto construido.")
		return
	if metadata.has("puesto"):
		Economia.reactivar_puesto(metadata["puesto"])
		print("Puesto reactivado en ", metadata["puesto"], ".")
		hud.notificar("Puesto reactivado.")
		return
	var blueprint: Dictionary = metadata["blueprint"]
```

(el resto de la función, desde `var blueprint: Dictionary = metadata["blueprint"]` en adelante, no cambia).

- [ ] **Step 2: Completar TEST 7 hasta el final de la construcción**

Amplía el TEST 7 de Task 1 Step 4: después de confirmar que queda como fantasma, financia el almacén y sigue llamando `mundo.surtir_construccion()` hasta que `resultado["completa"]` sea `true`, entonces llama `jugador._completar_construccion(resultado["metadata"])` (necesita una instancia de `Player`, `PlayerScript.new()`, igual que ya hace `ExtraccionTest.gd` TEST 7) y confirma que `Recoleccion`/`Economia` ya tienen el puesto registrado. Ejemplo completo (reemplaza el final del TEST 7 del Task 1):

```gdscript
	Ciudad.almacen["madera"].cantidad = 999999.0
	Ciudad.almacen["tierra"].cantidad = 999999.0
	Ciudad.almacen["piedra"].cantidad = 999999.0
	var jugador7: CharacterBody3D = PlayerScript.new()
	jugador7.mundo = mundo7
	jugador7.hud = camara7.hud
	var resultado7: Dictionary
	var limite7 := 0
	while limite7 < 500:
		resultado7 = mundo7.surtir_construccion(celda_muro_7)
		limite7 += 1
		if resultado7.get("completa", false):
			break
		if resultado7.is_empty():
			# la celda apuntada ya se completó; sigue con cualquier otra
			# celda todavía fantasma de la plantilla
			var otra_celda_7: Vector3i = celda_muro_7
			for c7 in ev7["celdas_plantilla"]:
				if mundo7.obtener_tipo(c7) == "fantasma":
					otra_celda_7 = c7
					break
			if otra_celda_7 == celda_muro_7 and mundo7.obtener_tipo(celda_muro_7) != "fantasma":
				break  # no queda nada fantasma: terminado por otro camino
			celda_muro_7 = otra_celda_7
	assert(resultado7.get("completa", false), "la construcción se completó dentro del límite de pasos")
	jugador7._completar_construccion(resultado7["metadata"])
	assert(Recoleccion.puestos.has(esquina7), "el puesto se registró en Recoleccion al completarse")
	jugador7.free()
```

(`Recoleccion.puestos: Dictionary` — confirmado en `godot/scripts/Recoleccion.gd:145` — es el diccionario esquina -> {"tipo", "ancho", "alto", "nivel"} que `colocar_puesto()` llena; el punto central a probar es: NO registrado antes de completar, SÍ registrado después).

- [ ] **Step 3: Correr las pruebas**

Run: mismo comando del Task 1 Step 5.
Expected: sin `SCRIPT ERROR`.

- [ ] **Step 4: Correr TODA la suite afectada**

Por las dudas de que el reordenamiento de `_completar_construccion()` haya afectado el camino existente de residenciales/reactivación: correr `Test.tscn` (BlueprintValidator, incluye TEST 88 de deconstrucción/reembolso) y `PuestosPrevisualizacionTest.tscn` completos, confirmar 0 `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Player.gd godot/scripts/PuestosPrevisualizacionTest.gd
git commit -m "feat: el puesto se registra en Recoleccion/Economia solo al completar su construcción"
```

---

### Task 3: Documentación

**Files:**
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md`
- Modify: `docs/Fichas_Consumo_Produccion.md` (si corresponde)

**Interfaces:** ninguna.

- [ ] **Step 1: Actualizar el documento técnico de PoC 5**

Busca la descripción de `estampar_puesto()`/colocación instantánea (`grep -n "estampar\|instant" "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md"`) y actualízala: los puestos ahora se colocan como fantasma y se construyen gradualmente, igual que un edificio residencial, con costo real de materiales.

- [ ] **Step 2: Nota en Fichas_Consumo_Produccion.md**

Si esa tabla todavía dice que colocar puestos es gratis/instantáneo en algún punto, márcalo como resuelto (mismo estilo `~~...~~ — ✅ hecho (fecha)` que ya usa el documento).

- [ ] **Step 3: Commit**

```bash
git add "PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md" "docs/Fichas_Consumo_Produccion.md"
git commit -m "docs: puestos periféricos se construyen gradual y con costo real, ya no se estampan al instante"
```

---

## Self-Review

**Cobertura del spec:** Sección 1 (alcance) → Tasks 1-2. Sección 2 (`_procesar_clic_puesto`) → Task 1. Sección 3 (activación al completar) → Task 2. Sección 4 (pruebas) → Task 1 Step 4, Task 2 Step 2. Sección 5 (documentación) → Task 3.

**Placeholders:** ninguno — cada step trae código real; `Recoleccion.puestos` (Task 2 Step 2) se verificó directamente en `Recoleccion.gd:145` antes de escribir el plan.

**Consistencia de tipos:** `metadata["puesto_nuevo"]` (Task 1) trae exactamente las 9 claves que Task 2 Step 1 lee (`tipo`, `esquina`, `ancho`, `alto`, `centro`, `centro_agua`, `servicio`, `deposito`, `y_base`) — verificado cruzando ambos bloques de código.

**Review Focus:** pilotes de pesca cobrando piedra vs. relleno cobrando tierra, saltando agua real → Task 1 Step 2 (código) + Step 4 (puede ampliarse con un caso de pesca si al implementar se ve necesario). Puesto inactivo hasta completar → Task 2 Step 2. Reembolso al deconstruir un puesto completado → ya cubierto por el mecanismo existente (`celdas_pagadas`), sin tarea propia porque no requiere código nuevo — confirmar con una aserción manual si se quiere evidencia extra. Rechazo sin pérdida a mitad de construir → ya cubierto por `_bloqueado_por_falta_de()` (sin cambios), la Task 1 solo lo alimenta con datos de puesto. Camino de reactivación existente no se rompe → Task 2 Step 1 (la rama nueva va ANTES pero no reemplaza la vieja) + Step 4 (correr `Test.tscn` completo).
