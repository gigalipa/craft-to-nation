# Construcción/Deconstrucción Reversible — Rediseño

## Contexto

El spec anterior (`2026-09-11-deconstruccion-edificios-design.md`, ya
implementado y en `main`) modeló la deconstrucción como una SEGUNDA cola de
`Construccion.gd` que arranca cuando el jugador empieza a deconstruir,
paralela a la cola de construcción original (`Construccion.cancelar()`
abandona la de construcción si seguía activa). Es decir: dos colas de un
solo sentido cada una, con un punto de "conmutación" entre ellas.

Playtesting reveló que este modelo es la arquitectura equivocada, con tres
síntomas concretos:

1. **Dirección visualmente invertida**: `ORDEN_GRUPOS_DECONSTRUCCION` reversa
   deliberadamente el orden de construcción, pero eso solo controla el
   orden en que se AGREGAN celdas a la nueva cola de reversión — no importa
   qué tan alto o bajo esté cada celda en Y, la sensación reportada fue
   "de abajo hacia arriba" en vez de "de arriba hacia abajo".
2. **Bloqueo fantasma tras deconstruir a medio construir**: al deconstruir un
   edificio que todavía tenía celdas fantasma pendientes,
   `Construccion.cancelar()` abandona esa cola pero dos IDs de cola
   coexisten brevemente (la vieja de construcción, cancelada, y la nueva de
   deconstrucción) y `celda_a_edificio`/`edificio_a_celdas` nunca se tocan
   — la huella sigue registrada como edificio, bloqueando cualquier
   colocación nueva ahí aunque visualmente ya no quede nada.
3. **No hay reversibilidad real**: el modelo es un compromiso de una sola
   vía — "cancela la cola de construcción, arranca la de deconstrucción" —
   sin forma de retomar la construcción después de deconstruir una parte,
   ni de alternar libremente entre avanzar y revertir. El caso de uso real
   (jugador pausa una construcción, deconstruye una parte para recuperar
   material en otro lado, luego regresa a terminarla) no tiene cabida en
   dos colas de un solo sentido.

La causa raíz común: modelar "construir" y "deconstruir" como dos procesos
distintos con colas separadas, en vez de un solo proceso con una posición
que se mueve en ambas direcciones sobre UN orden fijo.

## Objetivo

Reemplazar el mecanismo central de `Construccion.gd`/`VoxelWorld.gd` para
edificios (no para el relleno de nivelación, que sigue igual) por un
**índice de progreso bidireccional** por edificio:

- Cada edificio tiene UN orden fijo de celdas estructurales
  (`edificio_orden[id]`, fijado al declarar/iniciar el edificio, nunca
  cambia) y un contador `edificio_progreso[id]` — cuántas celdas desde el
  inicio de `orden` son actualmente reales.
- **Surtir** (`surtir_construccion()`) incrementa el progreso: convierte
  `orden[progreso]` de fantasma a real.
- **Deconstruir** (`procesar_deconstruccion()`) decrementa el progreso:
  revierte `orden[progreso - 1]` de real a fantasma.
- Es el MISMO orden en ambos sentidos — construir avanza hacia adelante,
  deconstruir retrocede por el mismo camino. Como el orden ya va de piso a
  mobiliario (de abajo hacia arriba), deconstruir naturalmente quita primero
  lo último agregado (mobiliario, luego paredes, luego piso) — de arriba
  hacia abajo, resolviendo el síntoma 1 sin ninguna regla de "reversa".
- El progreso puede subir y bajar libremente, cualquier número de veces, en
  cualquier orden temporal — resuelve el síntoma 3 directamente: pausar,
  deconstruir parcialmente, y retomar la construcción es simplemente seguir
  moviendo el mismo contador.
- No existe ninguna operación de "cancelar" ni una segunda cola: solo hay
  UN estado por edificio (`orden`, `tipos`, `progreso`, `metadata`), así que
  no hay forma de que `celda_a_edificio`/`edificio_a_celdas` queden
  desincronizados de lo que se ve en pantalla — resuelve el síntoma 2.

## Fuera de alcance

- Recuperar materiales al deconstruir (sigue fuera de alcance, como en el
  spec anterior) — este rediseño solo cambia CÓMO se modela la
  reversibilidad, no agrega un inventario.
- NPCs construyendo/deconstruyendo — no existe ningún sistema de NPCs en
  esta PoC; el modelo se diseña para que sea compatible a futuro (cualquier
  actor que llame `surtir_construccion()`/`procesar_deconstruccion()` sobre
  el mismo edificio comparte el mismo progreso, sin importar quién avanza o
  retrocede), pero no se implementa ningún NPC aquí.
- El relleno de nivelación (`Construccion.gd`, cola de una sola vía) no
  cambia de mecanismo — sigue siendo un proceso de un solo sentido, aislado
  de la identidad del edificio desde el spec anterior (punto 2.5). Este
  rediseño solo mueve la parte ESTRUCTURAL del edificio fuera de
  `Construccion.gd` hacia el nuevo modelo de progreso; `Construccion.gd`
  sigue existiendo, pero solo para relleno.
- El núcleo urbano sigue exento de deconstrucción (sin cambios respecto al
  spec anterior).

## Diseño

### 1. `VoxelWorld.gd`: nuevo modelo de datos por edificio

Reemplaza `_cola_decon` (que se elimina) por cuatro diccionarios paralelos,
indexados por el mismo id que ya devuelve `registrar_edificio()`:

```gdscript
## Por edificio (id de VoxelWorld.registrar_edificio()): el orden FIJO de
## sus celdas estructurales (piso -> paredes/puertas/ventanas ->
## mobiliario), sus tipos, y cuántas celdas desde el inicio de ese orden
## son actualmente reales ("progreso"). Reemplaza el modelo de dos colas
## de un solo sentido (Construccion.gd + _cola_decon) por un único índice
## que se mueve en ambas direcciones — ver
## docs/superpowers/specs/2026-09-11-construccion-reversible-design.md.
## Nunca se usa para el relleno de nivelación, que sigue en Construccion.gd
## (proceso de un solo sentido, aislado del edificio desde el spec de
## deconstrucción, punto 2.5).
var edificio_orden: Dictionary = {}  # int -> Array[Vector3i]
var edificio_tipos: Dictionary = {}  # int -> Dictionary (Vector3i -> String)
var edificio_progreso: Dictionary = {}  # int -> int
var edificio_metadata: Dictionary = {}  # int -> Dictionary
```

`_cola_decon` se elimina por completo (única referencia restante tras este
rediseño).

### 2. `VoxelWorld.gd`: orden canónico único, natural (no invertido)

`ORDEN_GRUPOS_DECONSTRUCCION`/`_ordenar_celdas_deconstruccion()` se
renombran y se ajustan: se retira el grupo `["tierra"]` (el relleno ya no
pasa por aquí, ver punto 4) y se restaura el orden NATURAL de construcción
— este orden ahora es el único, usado tanto para surtir como para
deconstruir:

```gdscript
## Orden canónico y ÚNICO de las celdas estructurales de un edificio —
## piso primero, luego paredes/puertas/ventanas, luego mobiliario. Se usa
## en ambos sentidos: surtir_construccion() avanza edificio_progreso[id] a
## través de este mismo orden, procesar_deconstruccion() lo retrocede. No
## existe un orden "invertido" aparte — decrementar por el mismo camino
## con el que se construyó ya quita primero lo último agregado (mobiliario
## -> paredes -> piso), dando la sensación correcta de "arriba hacia
## abajo" sin ninguna regla especial.
const ORDEN_GRUPOS_EDIFICIO := [
	["piso"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["cama_cabecera", "cama_pies", "baul"],
]


## Agrupa y ordena "celdas_mundo" (Vector3i real -> tipo) según
## ORDEN_GRUPOS_EDIFICIO, y dentro de cada grupo por (y, x, z).
func _ordenar_celdas_edificio(celdas_mundo: Dictionary) -> Array:
	var orden: Array[Vector3i] = []
	for grupo in ORDEN_GRUPOS_EDIFICIO:
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

`CamaraCenital.ORDEN_GRUPOS_CONSTRUCCION`/`_ordenar_celdas_construccion()`
se eliminan (dead code tras este rediseño — su único llamador,
`_procesar_clic_blueprint()`, pasa a usar esta función de `VoxelWorld.gd`
en su lugar, ver punto 6).

### 3. `VoxelWorld.gd`: `iniciar_construccion_fantasma()` separa relleno de estructura

Nueva firma — recibe el relleno y la estructura como dos pares
orden/tipos independientes, en vez de un solo `orden` mezclado:

```gdscript
## Arranca un edificio fantasma. "orden_relleno"/"tipos_relleno" son las
## celdas de nivelación de terreno (si las hay) — siguen su propio proceso
## de un solo sentido en Construccion.gd, nunca se registran como parte
## del edificio (igual que el spec anterior, punto 2.5). "orden_estructura"
## (ya en el orden canónico de _ordenar_celdas_edificio()) y "tipos_estructura"
## son las celdas del edificio en sí — se registran en
## edificio_orden/edificio_tipos/edificio_progreso (progreso arranca en 0,
## todas fantasma) en vez de en Construccion.gd. Devuelve el id nuevo.
func iniciar_construccion_fantasma(orden_relleno: Array, tipos_relleno: Dictionary, orden_estructura: Array, tipos_estructura: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden_relleno:
		colocar_bloque(celda, "tierra")
	if not orden_relleno.is_empty():
		Construccion.iniciar(orden_relleno, tipos_relleno)
	for celda in orden_estructura:
		colocar_bloque(celda, "fantasma")
	var id: int = registrar_edificio(orden_estructura)
	edificio_orden[id] = orden_estructura
	edificio_tipos[id] = tipos_estructura
	edificio_progreso[id] = 0
	edificio_metadata[id] = metadata
	return id
```

Nota: el relleno ya NO pasa por "fantasma" — se coloca directamente como
`"tierra"` real y avanza por su propia cola de `Construccion.gd` igual que
antes (sigue siendo terreno normal, minable, ver spec anterior punto 2.5).
Esto es idéntico al comportamiento previo del relleno; lo único que cambia
es que ya no comparte el mismo `orden`/`tipos` que la estructura.

### 4. `VoxelWorld.gd`: `registrar_edificio_completo()` para edificios ya terminados

Nueva función — usada tanto por un edificio declarado a mano
(`Player._declarar_edificio()`) como, internamente, para dejar
`edificio_orden`/`edificio_progreso` consistentes cuando el edificio nace
YA completo (progreso == orden.size() desde el principio):

```gdscript
## Registra un edificio YA terminado (todas sus celdas reales desde el
## inicio) — usado por Player._declarar_edificio() para que un edificio
## declarado a mano (nunca pasó por iniciar_construccion_fantasma()) tenga
## el mismo edificio_orden/edificio_progreso que uno construido por
## blueprint, y así pueda deconstruirse y volver a completarse igual que
## cualquier otro. "celdas_mundo" es Vector3i real -> tipo (todas las
## celdas estructurales ya colocadas). Devuelve el id nuevo.
func registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int:
	var orden: Array = _ordenar_celdas_edificio(celdas_mundo)
	var id: int = registrar_edificio(orden)
	edificio_orden[id] = orden
	edificio_tipos[id] = celdas_mundo
	edificio_progreso[id] = orden.size()
	edificio_metadata[id] = metadata
	return id
```

### 5. `VoxelWorld.gd`: `surtir_construccion()` reescrita

```gdscript
## Avanza el progreso de un edificio en construcción apuntando a "celda".
## Encuentra el edificio por id_de_edificio() (no por pertenecer a una cola
## de Construccion.gd, ya no existe tal cosa para estructura) — así que,
## igual que antes, sirve apuntar a CUALQUIER celda del edificio (p. ej.
## una pared exterior ya real) para surtir la SIGUIENTE celda pendiente en
## orden, sin importar si "celda" en sí ya es real. No-op ({}) si "celda"
## no pertenece a ningún edificio o el edificio ya está completo.
func surtir_construccion(celda: Vector3i) -> Dictionary:
	var id: int = id_de_edificio(celda)
	if id == -1 or not edificio_orden.has(id):
		return {}
	var orden: Array = edificio_orden[id]
	var progreso: int = edificio_progreso[id]
	if progreso >= orden.size():
		return {}
	var celda_a_surtir: Vector3i = orden[progreso]
	var tipo: String = edificio_tipos[id][celda_a_surtir]
	set_cell_item(celda_a_surtir, GridMap.INVALID_CELL_ITEM)
	colocar_bloque(celda_a_surtir, tipo, true)
	edificio_progreso[id] = progreso + 1
	var completa: bool = edificio_progreso[id] == orden.size()
	if completa:
		reemparejar_construccion(orden)
	return {"completa": completa, "metadata": edificio_metadata[id]}
```

`reemparejar_construccion()` no cambia (sigue operando sobre un `Array` de
celdas, que `orden` sigue siendo).

### 6. `VoxelWorld.gd`: `procesar_deconstruccion()` reescrita

```gdscript
## Procesa un intento de deconstrucción apuntando a "celda". Devuelve {} si
## "celda" no pertenece a ningún edificio con edificio_orden registrado
## (p. ej. un puesto periférico, que nunca pasa por aquí). Revierte SIEMPRE
## la celda en orden[progreso - 1] (la última agregada, sin importar cuál
## celda concreta se apuntó) y decrementa el progreso — mismo patrón
## "avanza siempre la primera/última pendiente" que ya usaba
## surtir_construccion(), en reversa.
##
## Devuelve {"id": int, "completa_reversion": bool,
## "lista_para_remocion": bool, "total_camas": int} — "total_camas" es el
## número de "cama_cabecera" del edificio, PERO SOLO tiene sentido cuando
## esta llamada cruza el borde de "edificio recién terminado" hacia
## "edificio ya no completo" (progreso pasa de orden.size() a
## orden.size() - 1); en cualquier otra llamada vale 0, para no
## contabilizar camas más de una vez si se deconstruye y se vuelve a
## completar varias veces (ver Ciudad.registrar_edificio_residencial(),
## que no es idempotente). "lista_para_remocion"/"completa_reversion" son
## true cuando el progreso llega a 0.
func procesar_deconstruccion(celda: Vector3i) -> Dictionary:
	var id: int = id_de_edificio(celda)
	if id == -1 or not edificio_orden.has(id):
		return {}
	var orden: Array = edificio_orden[id]
	var progreso: int = edificio_progreso[id]
	if progreso == 0:
		return {"id": id, "completa_reversion": true, "lista_para_remocion": true, "total_camas": 0}

	var total_camas := 0
	if progreso == orden.size():
		for c in orden:
			if edificio_tipos[id][c] == "cama_cabecera":
				total_camas += 1

	var celda_a_revertir: Vector3i = orden[progreso - 1]
	_revertir_celda(celda_a_revertir)
	edificio_progreso[id] = progreso - 1
	var vacio: bool = edificio_progreso[id] == 0
	return {"id": id, "completa_reversion": vacio, "lista_para_remocion": vacio, "total_camas": total_camas}
```

`_revertir_celda()` no cambia.

**Simetría con el registro de camas**: `_completar_construccion()`
(`Player.gd`) sigue siendo el único punto que LLAMA a
`Ciudad.registrar_edificio_residencial()` al completar la construcción —
sin cambios en este rediseño. Como `total_camas > 0` en
`procesar_deconstruccion()` ahora ocurre exactamente en el cruce
`progreso == orden.size() -> orden.size() - 1` (un evento bien definido,
nunca se repite sin que antes haya un `surtir_construccion()` que vuelva a
completar el edificio y dispare `_completar_construccion()` de nuevo), el
par retirar/registrar queda perfectamente balanceado sin importar cuántas
veces se alterne entre completar y deconstruir parcialmente un mismo
edificio.

### 7. `VoxelWorld.gd`: `eliminar_edificio()` limpia el nuevo estado

```gdscript
func eliminar_edificio(id: int) -> Vector2i:
	if not edificio_a_celdas.has(id):
		return Vector2i.ZERO
	var celdas: Array = edificio_a_celdas[id]
	var esquina := Vector2i(celdas[0].x, celdas[0].z)
	for celda in celdas:
		esquina.x = min(esquina.x, celda.x)
		esquina.y = min(esquina.y, celda.z)
		if pareja.has(celda):
			pareja.erase(pareja[celda])
			pareja.erase(celda)
		set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
		celda_a_edificio.erase(celda)
	edificio_a_celdas.erase(id)
	edificio_orden.erase(id)
	edificio_tipos.erase(id)
	edificio_progreso.erase(id)
	edificio_metadata.erase(id)
	return esquina
```

(La línea `_cola_decon.erase(id)` se retira — ese diccionario ya no
existe.)

### 8. `Construccion.gd`: `cancelar()` se elimina

`cancelar()` queda sin ningún llamador tras este rediseño (su único
llamador, el `procesar_deconstruccion()` viejo, se reescribe por completo
en el punto 6) — se elimina del archivo. `iniciar()`/`avanzar()`/
`construccion_de()` se mantienen sin cambios, usados exclusivamente para
el relleno de nivelación de ahora en adelante.

### 9. `CamaraCenital.gd`: `_huella_choca_con_otro_puesto()` — corrección

```gdscript
func _huella_choca_con_otro_puesto(esquina: Vector2i, columnas: Array[Vector2i]) -> bool:
	for rel in columnas:
		var xz := Vector2i(esquina.x + rel.x, esquina.y + rel.y)
		if Recoleccion.celda_dentro_de_algun_puesto(xz):
			return true
		var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
		if mundo.id_de_edificio(celda_superficie) != -1:
			return true
	return false
```

Antes consultaba `Construccion.construccion_de(celda_superficie) != -1`,
que solo detectaba una celda mientras estuviera activamente en una cola de
`Construccion.gd` (nunca cubría, por ejemplo, un edificio ya 100%
completo, cuya cola ya se había vaciado y borrado). `mundo.id_de_edificio()`
es superconjunto correcto: detecta CUALQUIER celda que pertenezca a un
edificio registrado, completo o no.

### 10. `CamaraCenital.gd`: `_procesar_clic_blueprint()` — nueva llamada

Reemplaza el cálculo de `orden` mezclado (`relleno_orden +
_ordenar_celdas_construccion(celdas_mundo)`) por dos pares separados, y
llama a la nueva firma de `iniciar_construccion_fantasma()`:

```gdscript
	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
	var relleno_orden: Array[Vector3i] = []
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			relleno_orden.append(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y))
	var tipos_relleno: Dictionary = {}
	for celda_r in relleno_orden:
		tipos_relleno[celda_r] = "tierra"

	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, objetivo + 1 + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]
	var orden_estructura: Array = mundo.ordenar_celdas_edificio(celdas_mundo)

	var huella_xz: Array = []
	var vistos_xz: Dictionary = {}
	for celda in celdas_mundo:
		var xz := Vector2i(celda.x, celda.z)
		if not vistos_xz.has(xz):
			vistos_xz[xz] = true
			huella_xz.append(xz)

	var metadata := {
		"blueprint": _blueprint_activo,
		"huella_xz": huella_xz,
		"esquina": esquina,
		"ancho": ancho,
		"profundidad": alto,
	}
	var id_edificio: int = mundo.iniciar_construccion_fantasma(relleno_orden, tipos_relleno, orden_estructura, celdas_mundo, metadata)
	metadata["id_edificio"] = id_edificio
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()
```

`_ordenar_celdas_edificio()` es privada (`_`) en `VoxelWorld.gd`, pero
`CamaraCenital.gd` necesita llamarla desde fuera del autoload/nodo —
se expone como `ordenar_celdas_edificio()` (pública, sin guion bajo) en
`VoxelWorld.gd`; internamente `iniciar_construccion_fantasma()` recibe el
orden ya calculado (no lo recalcula) para no depender de que el llamador
use el mismo criterio por casualidad.

`ORDEN_GRUPOS_CONSTRUCCION`/`_ordenar_celdas_construccion()` se eliminan de
`CamaraCenital.gd` (punto 2).

### 11. `Player.gd`: `_declarar_edificio()` delega en `_completar_construccion()`

Unifica el camino de "declarado a mano" con el de "completado vía
blueprint" para que ambos terminen con `edificio_orden`/`edificio_progreso`
consistentes y una única función (`_completar_construccion()`) responsable
de registrar camas/zona/puesto:

```gdscript
func _declarar_edificio() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	var tipo_apuntado: String = mundo.obtener_tipo(celda)
	if tipo_apuntado != "puerta_inferior" and tipo_apuntado != "puerta_superior":
		print("Declarar edificio: apunta a la puerta principal de la estructura.")
		return
	var celdas: Dictionary = mundo.detectar_estructura(celda)
	if celdas.is_empty():
		print("Declarar edificio: esa puerta no fue colocada por el jugador.")
		return
	var blueprint := BlueprintValidator.estructura_a_blueprint(celdas)

	var celda_puerta_xz := Vector2i(celda.x, celda.z)
	var huella: Array = []
	var huella_vista: Dictionary = {}
	var esquina := Vector2i(celda.x, celda.z)
	for pos in celdas.keys():
		var punto_xz := Vector2i(pos.x, pos.z)
		esquina.x = min(esquina.x, punto_xz.x)
		esquina.y = min(esquina.y, punto_xz.y)
		if not huella_vista.has(punto_xz):
			huella_vista[punto_xz] = true
			huella.append(punto_xz)

	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino)

	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if not resultado["valido"]:
		return

	Blueprints.guardar(blueprint)
	var metadata := {
		"blueprint": blueprint,
		"huella_xz": huella,
		"esquina": esquina,
		"ancho": blueprint["ancho"],
		"profundidad": blueprint["profundidad"],
	}
	var id_edificio: int = mundo.registrar_edificio_completo(celdas, metadata)
	metadata["id_edificio"] = id_edificio
	_completar_construccion(metadata)
```

`_completar_construccion()` ya declara/amplía la zona de influencia y
registra camas — se retira esa lógica duplicada de `_declarar_edificio()`.
Lo único que `_completar_construccion()` hace de más respecto al camino
viejo es `Recoleccion.colocar_puesto()`: un edificio declarado a mano
ahora también reserva su huella en `Recoleccion.puestos` (antes no lo
hacía) — cambio deliberado y deseable, coherente con que ahora es
deconstruible/reconstruible igual que uno por blueprint (sin reserva, dos
edificios declarados a mano podrían superponerse tras deconstruir uno de
ellos).

`blueprint["ancho"]`/`blueprint["profundidad"]` ya existen en el dict que
devuelve `estructura_a_blueprint()` (reutilizados, no se agrega ningún
campo nuevo).

## Pruebas

- **`ConstruccionTest.gd`**: sin cambios de fondo (`iniciar`/`avanzar`/
  `construccion_de` siguen probándose igual) — se elimina cualquier caso
  que probara `cancelar()` si existiera (no existe ninguno hoy, confirmado
  por grep).
- **`BlueprintValidatorTest.gd`**: TEST 22 (orden de reversión), TEST 23
  (mid-construction skip fantasma) y TEST 25 (cancelar y revertir a medio
  construir) se reescriben sobre el nuevo mecanismo:
  - TEST 22 pasa a confirmar que deconstruir un edificio TERMINADO revierte
    en el orden `mobiliario -> paredes -> piso` (progreso baja de
    `orden.size()` a 0 uno por uno) — mismo resultado observable que antes,
    pero ahora es una consecuencia de `orden_estructura` (piso primero) más
    decrementar el índice, no de un `ORDEN_GRUPOS_DECONSTRUCCION` aparte.
  - TEST 23 confirma que, a medio construir (`edificio_progreso[id] <
    orden.size()`), llamar `procesar_deconstruccion()` sobre cualquier
    celda del edificio revierte SIEMPRE `orden[progreso - 1]` — nunca una
    celda todavía fantasma (progreso nunca "salta" una celda no colocada).
  - TEST 25 se reescribe como el caso central del rediseño: iniciar un
    edificio fantasma, surtir 3 de sus N celdas, deconstruir 1 (progreso
    baja a 2), confirmar `mundo.id_de_edificio()` sigue reconociendo la
    huella (no hay "construcción fantasma" bloqueando), volver a surtir
    hasta completarlo, confirmar que `Ciudad.capacidad_camas_construida` se
    contabiliza una sola vez pese al ciclo completar/deconstruir/completar.
  - TEST 26 (puesto no-op) sin cambios — `procesar_deconstruccion()` sigue
    devolviendo `{}` para una celda sin `edificio_orden` registrado.
  - Nuevo caso: declarar un edificio a mano (`_declarar_edificio()`),
    confirmar que queda con `edificio_orden`/`edificio_progreso` igual que
    uno completado por blueprint, deconstruirlo parcialmente y volver a
    completarlo — confirma la unificación del punto 11 (sin este caso, la
    pérdida de `metadata` al deconstruir un edificio declarado a mano
    pasaría inadvertida).
- **`Main.tscn`**: verificación headless de parseo (sin errores nuevos) —
  sigue sin haber pruebas automatizadas de `CamaraCenital.gd`/`Player.gd`
  (lógica de input/cámara), verificado manualmente por el usuario.

## Verificación de integración

Manual en el editor:

1. Colocar un blueprint, surtirlo parcialmente, activar modo deconstrucción
   y deconstruir una parte — confirmar que el orden se siente "de arriba
   hacia abajo" (mobiliario y paredes antes que el piso).
2. Deconstruir un edificio A MEDIO CONSTRUIR (con celdas fantasma
   pendientes) parcialmente, y confirmar que su huella queda libre para
   nueva construcción tan pronto `edificio_progreso` llega a 0 — sin
   "construcción fantasma" residual bloqueando.
3. Construir un edificio hasta la mitad, pausar, deconstruir un par de
   celdas, y luego RETOMAR la construcción (surtir de nuevo) hasta
   completarlo — confirmar que las camas se registran una sola vez en
   `Ciudad.capacidad_camas_construida` pese al vaivén.
4. Declarar un edificio a mano (sin blueprint fantasma), deconstruirlo
   parcialmente y volver a completarlo — confirmar que no se pierden sus
   camas ni su huella en `Recoleccion.puestos`.
5. Confirmar que el relleno de nivelación de terreno sigue comportándose
   igual que antes (minable en cualquier momento, ajeno a la
   deconstrucción del edificio).
