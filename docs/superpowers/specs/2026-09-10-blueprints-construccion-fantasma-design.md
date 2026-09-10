# Blueprints Reutilizables + Construcción Fantasma (Edificios) — Diseño

**Alcance:** PoC 5 (sub-proyecto nuevo, sin número asignado todavía — no depende del terreno procedural, podría vivir en su propia PoC más adelante). GDD Sección 5 ("Mecánica de Plantillas y Construcción Asistida"). Sub-proyecto A de dos: este cubre **solo edificios declarados** (residencial, por ahora la única categoría real). Sub-proyecto B (después, spec propia) migrará los puestos periféricos (mina/caza-recolección) al mismo mecanismo de fantasma+suministro — **fuera de alcance aquí**.

**Repo:** `C:\Users\peraz\Projects\Misc\CityCraft`, proyecto Godot 4.7 compartido en `godot/`.

## La mecánica, en una frase

Declarar un edificio ya no solo lo registra en `Ciudad`/`Zonificacion` — también guarda su `Blueprint` como plantilla reutilizable. El jugador puede emplazar copias de esa plantilla en cualquier zona compatible: la copia nace como una **construcción fantasma** (bloques placeholder translúcidos, con colisión, en la forma exacta del edificio incluido el relleno de nivelación) que el jugador **surte** interactuando con ella — cada interacción convierte la siguiente celda pendiente (en un orden automático fijo) a su bloque real, hasta que la construcción queda completa y deja de ser fantasma.

## Decisiones de alcance confirmadas con el usuario

- **Gratis:** surtir una celda fantasma no consume ningún recurso — mismo alcance reducido que el resto del juego (minar/colocar/nivelar ya son gratis). Cuando exista producción/inventario real, ahí se conectará un costo.
- **Captura general:** cualquier edificio declarado válido guarda su blueprint (no un caso especial solo para el primero) — hoy en la práctica solo existe la categoría residencial, pero el mecanismo no se limita a ella.
- **Un blueprint por zona, el más reciente:** sin catálogo ni selección manual todavía. `Blueprints.gd` guarda como máximo un blueprint por `zona_permitida`; declarar un nuevo edificio de esa zona sobrescribe el guardado anterior. El menú/catálogo de construcción con múltiples blueprints por categoría es una pieza de UI futura, fuera de alcance.
- **Orden de suministro automático, sin selección de tipo:** el jugador (o, a futuro, un NPC) no elige qué tipo de bloque aporta — cada interacción rellena la siguiente celda pendiente en un orden fijo (relleno de tierra → piso → paredes/puertas/ventanas → mobiliario). Los objetos compuestos (cama, puerta, baúl) y los materiales reales por tipo de bloque (madera/piedra/tela/vidrio, variando por nivel/diseño) quedan **documentados como dirección futura, sin implementar** — hoy cada celda fantasma se convierte directamente a su bloque final de un solo golpe.
- **Sin rotación** en esta primera versión — la copia siempre se coloca con la misma orientación del original. Rotar un blueprint completo (paredes+puertas+ventanas+mobiliario) es una transformación de coordenadas mayor que rotar un rectángulo vacío (como ya hacen los puestos); se puede agregar después reutilizando el mismo control (Ctrl+rueda).
- **Solo el jugador surte por ahora** — no hay NPCs constructores todavía (eso es Fase 2/6 del roadmap). La interacción está diseñada para no necesitar cambios cuando existan: cualquier agente que pueda "apuntar" a una celda fantasma y disparar `surtir_construccion()` sirve.
- **Reemplaza la nivelación standalone:** la tecla `B` en la cámara cenital deja de tener un modo de nivelación independiente (huella fija 5×5, relleno gratis inmediato) — pasa a activar el modo de colocación de blueprint, y el relleno de nivelación de una construcción real pasa a ser parte de su lista de celdas fantasma (ya no gratis/inmediato). `NiveladorTerreno.gd` no cambia — se sigue usando para decidir SI la huella es nivelable (pendiente dentro del límite) y CUÁNTO relleno hace falta, solo que ese relleno ahora se coloca como fantasma en vez de "tierra" real de inmediato.

## 1. Extensión del `Blueprint` (`BlueprintValidator.gd`)

**Problema encontrado:** `estructura_a_blueprint()` ya normaliza las celdas capturadas, pero las aplana a un template 2D por piso (`"pisos"[i]["celdas"]`, `Dictionary "x,z" -> tipo`) pensado solo para **validar** reglas (perímetro, esquinas, ventana mínima) — pierde la altura exacta de puertas (2 celdas, inferior/superior), ventanas y mobiliario dentro del piso. Insuficiente para **reconstruir** la forma 3D real al emplazar una copia.

**Fix — dos campos nuevos, aditivos, sin tocar `"pisos"` ni `validar_blueprint()`:**

```gdscript
static func estructura_a_blueprint(celdas: Dictionary) -> Dictionary:
	# ... (lógica existente sin cambios hasta el final) ...

	# NUEVO: celdas_3d conserva la forma real completa (puerta_inferior/
	# puerta_superior, cama_cabecera/cama_pies, ventana, etc. en su altura
	# exacta), normalizada al mismo origen (x_min, y_min, z_min) que ya usa
	# el resto de la función — a diferencia de "pisos", que aplana estas
	# celdas a un template 2D por piso para poder validar reglas de
	# perímetro/esquina, esto es lo que permite RECONSTRUIR el edificio
	# exacto al emplazar una copia (ver Construccion.gd).
	var celdas_3d: Dictionary = {}  # Vector3i (normalizado) -> tipo original
	for pos in celdas.keys():
		celdas_3d[pos - Vector3i(x_min, y_min, z_min)] = celdas[pos]

	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,       # x_max ya es (máximo - x_min), ver arriba
		"profundidad": z_max + 1,
	}
```

`x_max`/`z_max` ya se calculan hoy (líneas existentes, restados a `x_min`/`z_min` para normalizar) — `"ancho"`/`"profundidad"` son ese mismo valor +1 (convertir "índice máximo" a "cantidad de celdas").

## 2. Autoload `Blueprints.gd` (registro de plantillas)

Mismo patrón que `Recoleccion.gd`/`Zonificacion.gd`: estado puro, sin nodos de escena, sin `class_name`.

```gdscript
extends Node

## Autoload "Blueprints": registro de blueprints reutilizables, uno por
## zona_permitida (el último declarado de esa zona sobrescribe al
## anterior — sin catálogo ni selección manual todavía, ver spec).

var _por_zona: Dictionary = {}  # String (zona_permitida) -> Dictionary (blueprint)


func guardar(blueprint: Dictionary) -> void:
	_por_zona[blueprint["zona_permitida"]] = blueprint


func obtener(zona_permitida: String) -> Dictionary:
	return _por_zona.get(zona_permitida, {})
```

`Player._declarar_edificio()` llama `Blueprints.guardar(blueprint)` justo después de confirmar `resultado["valido"]` (mismo bloque donde ya llama a `Ciudad.registrar_edificio_residencial()`).

## 3. Autoload `Construccion.gd` (progreso de construcciones fantasma)

Mismo patrón de estado puro. Rastrea, por construcción activa, el orden de conversión y cuánto se ha surtido — no conoce bloques ni `VoxelWorld` directamente (duck typing desde `VoxelWorld`, igual que `Recoleccion`).

```gdscript
extends Node

## Autoload "Construccion": progreso de construcciones fantasma en curso
## (edificios emplazados desde un blueprint, pendientes de ser surtidos con
## bloques). Una construcción es una lista ORDENADA de celdas pendientes,
## cada una con su tipo real de destino — avanzar() siempre convierte la
## PRIMERA celda pendiente de la lista, sin importar cuál
## celda fantasma apuntó el jugador (ver Player.gd/VoxelWorld.gd): el orden
## es automático y fijo (relleno de tierra -> piso -> paredes/puertas/
## ventanas -> mobiliario), decidido al iniciar la construcción.

var _siguiente_id := 1
var _construcciones: Dictionary = {}  # int id -> {"orden": Array[Vector3i], "tipos": Dictionary, "indice": int, "metadata": Dictionary}
var _celda_a_construccion: Dictionary = {}  # Vector3i -> int id


## "orden": Array[Vector3i] ya en el orden exacto de conversión.
## "tipos": Dictionary Vector3i -> String, el tipo real al que se convierte
## cada celda de "orden" cuando le toque su turno.
## "metadata": dato opaco que el llamador necesita al completarse (ver
## avanzar()) — p. ej. para un edificio, {"blueprint": blueprint,
## "huella_xz": Array} (ver Sección 8); {} si no hace falta nada (caso de
## un puesto periférico, sub-proyecto B). Construccion.gd nunca mira su
## contenido, solo lo guarda y lo devuelve intacto.
func iniciar(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	var id := _siguiente_id
	_siguiente_id += 1
	_construcciones[id] = {"orden": orden, "tipos": tipos, "indice": 0, "metadata": metadata}
	for celda in orden:
		_celda_a_construccion[celda] = id
	return id


func construccion_de(celda: Vector3i) -> int:
	return _celda_a_construccion.get(celda, -1)


## Convierte la SIGUIENTE celda pendiente de la construcción "id" (no
## necesariamente "celda_apuntada", que solo sirvió para identificar la
## construcción). Devuelve {"celda": Vector3i, "tipo": String, "completa": bool,
## "metadata": Dictionary} — "completa" es true si esta era la última celda
## pendiente, momento en el que el llamador (VoxelWorld.surtir_construccion())
## debe limpiar el registro; "metadata" es la misma que se pasó a iniciar(),
## siempre presente (no solo cuando completa=true), para que el llamador no
## tenga que guardarla aparte. Falla (dict vacío) si "id" no existe o ya
## está completa.
func avanzar(id: int) -> Dictionary:
	if not _construcciones.has(id):
		return {}
	var datos: Dictionary = _construcciones[id]
	var indice: int = datos["indice"]
	var orden: Array = datos["orden"]
	if indice >= orden.size():
		return {}
	var celda: Vector3i = orden[indice]
	var tipo: String = datos["tipos"][celda]
	var metadata: Dictionary = datos["metadata"]
	datos["indice"] = indice + 1
	var completa: bool = datos["indice"] >= orden.size()
	if completa:
		for c in orden:
			_celda_a_construccion.erase(c)
		_construcciones.erase(id)
	return {"celda": celda, "tipo": tipo, "completa": completa, "metadata": metadata}
```

## 4. Bloque `"fantasma"` en la MeshLibrary

Mismo patrón placeholder que `"mina"`/`"puesto_caza"` en `godot/scenes/BlockLibrarySource.tscn`, pero con material translúcido (`TRANSPARENCY_ALPHA`, alpha bajo — p. ej. `Color(0.6, 0.7, 1.0, 0.35)`, un azul/blanco "de obra en construcción", distinto de cualquier color de overlay ya usado). A diferencia de los overlays de previsualización (planos sin colisión), este es un bloque real del `GridMap` — tiene colisión, para que el raycast de `Player.gd` lo detecte igual que cualquier otro bloque.

## 5. `VoxelWorld.gd` — iniciar y surtir una construcción fantasma

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
	return Construccion.iniciar(orden, tipos, metadata)


## Convierte la siguiente celda pendiente de la construcción a la que
## pertenece "celda_fantasma" (que puede ser cualquier celda fantasma de esa
## construcción, no necesariamente la que se va a convertir — ver
## Construccion.avanzar()). Devuelve {} si no había ninguna construcción en
## esa celda; si no, {"completa": bool, "metadata": Dictionary} — el
## llamador (Player.gd) decide qué hacer al completarse (registrar en
## Ciudad, etc., ver Sección 8) usando "metadata".
func surtir_construccion(celda_fantasma: Vector3i) -> Dictionary:
	var id: int = Construccion.construccion_de(celda_fantasma)
	if id == -1:
		return {}
	var resultado: Dictionary = Construccion.avanzar(id)
	if resultado.is_empty():
		return {}
	set_cell_item(resultado["celda"], GridMap.INVALID_CELL_ITEM)
	colocar_bloque(resultado["celda"], resultado["tipo"], true)
	return {"completa": resultado["completa"], "metadata": resultado["metadata"]}
```

`surtir_construccion()` no distingue "puerta_inferior" de cualquier otro tipo — `colocar_bloque()` ya acepta cualquier tipo registrado en la `MeshLibrary`, y el emparejamiento `pareja` (usado por `minar_bloque()` para borrar la mitad opuesta de una puerta/cama) se reconstruye por separado al completar la construcción (ver Sección 8) — mientras se está surtiendo, una puerta a medio construir puede tener su mitad inferior real y la superior todavía fantasma, sin `pareja` registrada aún, lo cual es correcto (no se puede minar algo que no es un bloque real completo).

## 6. Interacción de suministro (`Player.gd`)

Reutiliza el mecanismo de minar ya existente, sin controles nuevos: en `_minar()`, antes del chequeo de árbol, se agrega:

```gdscript
if mundo.obtener_tipo(celda) == "fantasma":
	var resultado: Dictionary = mundo.surtir_construccion(celda)
	if resultado.get("completa", false):
		_completar_construccion(resultado["metadata"])
	return
```

Como `_minar()` ya se dispara con click izquierdo sostenido (repetición cada `INTERVALO_ACCION_REPETIDA`), suministrar es simplemente **mantener click izquierdo apuntando a cualquier celda fantasma** de la construcción — no hace falta apuntar a la celda exacta que se va a convertir, porque el orden es automático. `_completar_construccion()` es la nueva función de `Player.gd` descrita en la Sección 8 (Finalización).

## 7. Modo de colocación de blueprint (`CamaraCenital.gd`, tecla `B`)

Reemplaza el modo de nivelación standalone existente (`modo_nivelacion`, `_actualizar_huella_fantasma()`, `_procesar_clic_nivelacion()`, `_huella_fantasma`, `NiveladorTerreno.calcular_relleno()` de uso inmediato) por un modo de colocación de blueprint que reutiliza la mayor parte de la infraestructura ya construida para puestos periféricos (huella genérica, validaciones, drenaje de agua):

- `B` activa el modo si `Blueprints.obtener("residencial_investigacion")` no está vacío (única zona con blueprint por ahora); si está vacío, imprime `"No hay ningún blueprint guardado todavía — declara un edificio primero."` y no entra al modo.
- Huella fantasma de `blueprint["ancho"]` × `blueprint["profundidad"]` celdas, mismo patrón visual que `_huella_puesto` (pool de planos, verde/rojo).
- Validaciones (reutilizando las funciones ya genéricas de la Tarea 7 de puestos, con una diferencia): relieve (`nivelador_puesto.verificar_pendiente()`), huella libre de madera/estructura (`VoxelWorld.verificar_huella_libre()`), esquina en tierra firme (`_huella_tiene_esquina_en_tierra()`), sin choque con otra construcción/puesto ya colocado (`_huella_choca_con_otro_puesto()` — el nombre no cambia, pero ahora también debe registrar los blueprints colocados en el mismo `Recoleccion.puestos` o un registro equivalente, ver nota abajo). En vez de "fuera de la zona de influencia" (regla de puestos, que van en la Periferia), la regla aquí es: `Zonificacion.consultar_zona(centro) == blueprint["zona_permitida"]`.
- **Reutilización de `Recoleccion.puestos`:** aunque una construcción de blueprint no es un "puesto" periférico, se registra igual en `Recoleccion.puestos` con `Recoleccion.colocar_puesto(esquina, "blueprint", ancho, alto)` — el registro ya es genérico por diseño (`tipo: String` sin restricción de valores, ver Tarea 1 de la spec de puestos), y `celda_dentro_de_algun_puesto()` ya recorre cualquier tipo sin distinción. Evita introducir un segundo registro de "cosas colocadas en el mundo" solo para blueprints. Se registra recién cuando la construcción queda COMPLETA (no al iniciarla como fantasma) — mientras está en construcción, otra huella no debería poder solaparse con ella tampoco, así que `_huella_choca_con_otro_puesto()` debe considerar también las celdas fantasma activas (`Construccion.construccion_de(celda) != -1`), no solo `Recoleccion.puestos`.
- Sin rotación (Ctrl+rueda no hace nada en este modo).

Al confirmar con clic (huella válida):
1. Drena el agua bajo la huella (`VoxelWorld.drenar_agua()`, igual que puestos).
2. Calcula el relleno de nivelación con `nivelador_puesto.altura_objetivo()`/`calcular_relleno()` — pero en vez de colocarlo como `"tierra"` de inmediato, sus celdas (`Vector3i` real, tipo `"tierra"`) se agregan al INICIO de la lista de conversión.
3. Reubica `blueprint["celdas_3d"]` en el mundo: cada celda relativa `(dx, dy, dz)` se traduce a `Vector3i(esquina.x + dx, altura_objetivo + 1 + dy, esquina.y + dz)` (la construcción se apoya sobre el terreno ya nivelado).
4. Ordena esas celdas reubicadas: `"piso"` primero, luego paredes/puertas/ventanas (cualquier tipo en `TIPOS_ESTRUCTURA` o `"puerta_inferior"`/`"puerta_superior"`), luego mobiliario (`"cama_cabecera"`/`"cama_pies"`/`"baul"`) al final — orden estable dentro de cada grupo (p. ej. por `y`, luego `x`, luego `z`, para que no sea arbitrario/aleatorio).
5. `VoxelWorld.iniciar_construccion_fantasma(relleno + celdas_ordenadas, tipos, {"blueprint": blueprint, "huella_xz": huella_xz})` — `huella_xz` es la huella en planta de la construcción reubicada (mismo cálculo que ya hace `_declarar_edificio()` a partir de sus celdas), guardada para `Zonificacion.declarar_nucleo()` si hiciera falta al completarse (ver Sección 8).

## 8. Finalización

La colocación del blueprint (Sección 7) no completa nada de inmediato — solo deja la construcción fantasma en curso, con `metadata = {"blueprint": blueprint, "huella_xz": Array}` (la huella en planta, mismo formato que ya arma `_declarar_edificio()` para `Zonificacion.declarar_nucleo()`). La finalización ocurre dentro del flujo de suministro (Sección 6), cuando `mundo.surtir_construccion()` devuelve `"completa": true`:

- **`Player._completar_construccion(metadata)`** ejecuta el mismo registro que hoy hace `_declarar_edificio()` al validar: cuenta camas del blueprint (`metadata["blueprint"]["pisos"]`, mismo cálculo que ya usa `_declarar_edificio()`) y llama `Ciudad.registrar_edificio_residencial(total_camas)`; si `not Zonificacion.nucleo_declarado`, además `Zonificacion.declarar_nucleo(metadata["huella_xz"])`.
- **Emparejamiento `pareja`:** al completarse, recorrer las celdas de la construcción buscando pares `puerta_inferior`/`puerta_superior` (misma X/Z, Y consecutiva) y `cama_cabecera`/`cama_pies` (misma Y, adyacentes en X o Z) para registrarlos en `VoxelWorld.pareja`, igual que `colocar_puerta()`/`colocar_cama()` ya hacen al construir a mano — sin esto, minar una puerta/cama de una construcción terminada no borraría su mitad opuesta (comportamiento inconsistente con el resto del juego). Detalle de implementación (algoritmo exacto de emparejamiento), no de diseño.
- Un puesto periférico completado (sub-proyecto B, futuro) no pasaría por este registro de `Ciudad`/`Zonificacion` — la distinción por `metadata`/tipo de construcción es justamente lo que permite que ambos casos compartan `Construccion.gd`/`surtir_construccion()` sin condicionales ad-hoc dentro de ese código genérico.

## Pruebas

- **`ConstruccionTest.gd`** (nueva escena, mismo patrón que `RecoleccionTest.gd`): `iniciar()` registra la construcción y todas sus celdas en `_celda_a_construccion`; `avanzar()` devuelve las celdas en el orden exacto de `orden`, con el `tipo` correcto de `tipos`; la última llamada devuelve `"completa": true` y limpia el registro (`construccion_de()` vuelve a `-1` para esas celdas); `avanzar()` sobre un id ya completado o inexistente devuelve `{}` sin errores.
- **`BlueprintValidatorTest.gd`** (ampliar): un test nuevo verifica que `estructura_a_blueprint()` sobre una estructura conocida (reutilizar el fixture de la casa real multi-nivel ya existente) devuelve `celdas_3d` con las mismas celdas que la entrada (normalizadas al origen, sin aplanar — una puerta debe seguir apareciendo como dos celdas `puerta_inferior`/`puerta_superior` en Y consecutiva) y `ancho`/`profundidad` coherentes con las dimensiones reales de la estructura.
- **`VoxelWorldTest`** (dentro de `BlueprintValidatorTest.gd`, mismo patrón que el test de `verificar_huella_libre()`): `iniciar_construccion_fantasma()` coloca `"fantasma"` en cada celda de la lista dada; `surtir_construccion()` sobre cualquiera de esas celdas convierte la PRIMERA pendiente (no la apuntada) al tipo correcto y avanza; tras surtir todas, la última llamada devuelve `"completa": true` (con la `metadata` pasada a `iniciar_construccion_fantasma()`) y ninguna celda de esa construcción sigue siendo `"fantasma"`.
- **Verificación manual en el editor** (como el resto de esta PoC): declarar un edificio residencial, entrar al modo `B` en la cámara cenital, confirmar que aparece la huella fantasma del tamaño correcto, colocar una copia sobre terreno con desnivel (confirmar drenaje/nivelación fantasma), acercarse en 1ª persona y mantener click izquierdo sobre el fantasma — confirmar que las celdas se convierten en el orden esperado (tierra → piso → paredes/puertas/ventanas → mobiliario) y que, al completarse, el edificio cuenta como declarado (camas registradas en `Ciudad`, HUD actualizado).

## Fuera de alcance (explícito)

- Sub-proyecto B: migrar puestos periféricos (mina/caza-recolección) al mismo mecanismo de fantasma+suministro — spec propia, después.
- Rotación de blueprints antes de colocar.
- Catálogo de blueprints con selección manual entre varios guardados por zona (hoy: uno por zona, el último).
- NPCs constructores — el suministro es solo del jugador; el diseño no bloquea agregarlos después (cualquier agente que dispare `surtir_construccion()` sirve).
- Materiales reales por tipo de bloque (madera/piedra/tela/vidrio variando por nivel/diseño) — cada celda fantasma se convierte a su bloque final completo de un solo golpe, sin descomponerlo en materiales. Dirección futura documentada, no implementada.
- Costo de recursos por surtir una celda — gratis, como el resto de esta PoC.
- Deshacer/cancelar una construcción fantasma ya iniciada (hoy, una vez confirmada la colocación, solo se puede completar surtiéndola — no hay forma de removerla a medio construir).

