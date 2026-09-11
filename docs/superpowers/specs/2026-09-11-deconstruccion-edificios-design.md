# Deconstrucción de Edificios — Diseño

## Contexto

Con blueprints + construcción fantasma (ver spec de blueprints) y edificios
como objeto completo inmunes al minado (ver spec de edificios-objeto-
completo), el jugador puede construir edificios (declarados a mano o vía
blueprint) pero no tiene ninguna forma de deshacerlos: antes de la
inmunidad al minado, "minar bloque a bloque" servía como deshacer informal
(con bugs propios); ahora ni eso existe. Este spec agrega un sistema de
deconstrucción explícito: reutiliza el mismo mecanismo de "construcción
fantasma" (`Construccion.gd`) pero en reversa — cada bloque real vuelve a
ser "fantasma" en el orden opuesto al de construcción, hasta que el
edificio queda vacío y desaparece del todo.

Funciona igual para un edificio ya terminado que para uno a medio
construir (todavía con celdas fantasma sin surtir): las celdas que ya son
fantasma simplemente no necesitan revertirse, así que el mismo flujo las
salta sin ningún caso especial.

## Objetivo

- El jugador puede deconstruir cualquier edificio ya registrado
  (`VoxelWorld.registrar_edificio()`) — declarado a mano o vía blueprint,
  terminado o a medio construir — bloque por bloque, en el orden inverso
  al de construcción (mobiliario → paredes/puertas/ventanas → piso →
  relleno de tierra).
- Una vez que el edificio queda reducido a fantasma vacío (sin ninguna
  celda real restante), sostener la interacción un momento más lo elimina
  por completo.
- Al iniciarse la deconstrucción de un edificio ya terminado, su
  capacidad de camas se retira de inmediato de `Ciudad` (no espera a que
  termine la deconstrucción).
- Al completarse la deconstrucción total de un edificio, la zona de
  influencia se recalcula (puede reducirse) y su reserva en
  `Recoleccion.puestos` (si la tenía) se libera.

## Fuera de alcance

- El núcleo urbano (el primer edificio, `Zonificacion.nucleo_declarado`)
  **no se puede deconstruir** — tiene rol estructural (ancla la zona de
  influencia) y a futuro será el monumento personalizable del jugador.
- La tierra de relleno de nivelación de un blueprint NUNCA es parte del
  edificio a efectos de inmunidad/deconstrucción (ver Diseño, punto 2.5) —
  siempre se comporta como terreno normal, incluso mientras el edificio
  está a medio construir. Deconstruir un edificio nunca la toca; queda el
  terreno nivelado donde antes había un edificio.
- Los puestos periféricos (mina, caza/recolección) no pasan por este
  sistema — no tienen fantasma, siguen colocándose e — por ahora — sin
  poder demolerse (sub-proyecto B: migrarlos a fantasma+suministro, ya
  documentado como pendiente aparte).
- Recuperar materiales/recursos al deconstruir — cada bloque revertido
  simplemente desaparece (vuelve a "fantasma", luego a vacío), sin
  devolver nada a un inventario. Coherente con que construir tampoco
  cuesta nada todavía en esta PoC.
- Deshacer una deconstrucción en curso (volver a "surtir" lo ya revertido)
  — una vez que el jugador empieza a deconstruir, solo puede seguir
  deconstruyendo o parar donde esté (el edificio queda a medio
  deconstruir, sin que nada lo fuerce a completarse).
- **Modo cenital de la tecla `G`** (marcar edificios para que NPCs
  desempleados los deconstruyan): mencionado por el usuario como dirección
  cercana, pero no se implementa en este spec — no existe todavía ningún
  sistema de NPCs en esta PoC. Se documenta aquí únicamente para que el
  nombre de la tecla (`G`) quede reservado y no se reasigne a otra cosa en
  la cámara cenital sin revisar este spec primero.
- Precisión total del "hueco" de un edificio irregular en `Recoleccion.
  puestos` mientras SIGUE EN PIE — ya documentado como fuera de alcance en
  el spec de huellas irregulares. Este spec SÍ libera la reserva completa
  al deconstruir un edificio hasta el final (ver Diseño, punto 5), lo cual
  resuelve el caso "ya no existe pero sigue bloqueando" para siempre —
  la imprecisión del hueco de un edificio irregular *todavía en pie* no
  cambia.

## Diseño

### 1. `Ciudad.gd`: retirar capacidad de camas

Nueva función simétrica a `registrar_edificio_residencial()`:

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

### 2. `VoxelWorld.gd`: índice inverso, orden de deconstrucción, y el flujo completo

**Índice inverso nuevo** — `registrar_edificio()` ya asigna un id por
edificio; ahora también guarda la lista de sus celdas para poder
recuperarlas después (hoy solo existe el mapeo celda→id, no el inverso):

```gdscript
## id de edificio -> Array[Vector3i] de sus celdas registradas (ver
## registrar_edificio()). Permite, dado un id, recuperar TODAS sus celdas
## sin recorrer celda_a_edificio entero — usado por la deconstrucción
## (procesar_deconstruccion()/eliminar_edificio()) para saber qué queda
## por revertir y qué borrar al final.
var edificio_a_celdas: Dictionary = {}  # int -> Array[Vector3i]
```

`registrar_edificio()` gana una línea (`edificio_a_celdas[id] = celdas.duplicate()`)
justo antes de devolver `id`.

```gdscript
## Celda -> id de edificio al que pertenece. Ver id_de_edificio() para
## consultarlo desde fuera con un valor de "no pertenece" explícito (-1)
## en vez de acceder al Dictionary directamente.
func id_de_edificio(celda: Vector3i) -> int:
	return celda_a_edificio.get(celda, -1)
```

**Orden de deconstrucción** — inverso al de `CamaraCenital.
ORDEN_GRUPOS_CONSTRUCCION` (mobiliario primero, relleno de tierra al
final). Se duplica deliberadamente en vez de compartirse con
`CamaraCenital.gd`: mismo criterio de capas que ya usa este archivo
(`VoxelWorld.gd` no depende de `CamaraCenital.gd`).

```gdscript
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

**El flujo completo** — una sola función que Player.gd llama en cada
click/repetición mientras el modo deconstrucción está activo:

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

### 2.5. Aislar la tierra de relleno de la parte estructural

Hoy `iniciar_construccion_fantasma(orden, tipos, metadata)` registra TODO
`orden` (relleno de tierra incluido) como inmune al minado —
`CamaraCenital._procesar_clic_blueprint()` construye `orden` como
`relleno_orden + _ordenar_celdas_construccion(celdas_mundo)`. Esto hace que
la tierra de nivelación se comporte como parte del edificio: inmune
mientras existe, y (si no se corrigiera esto) parte de la deconstrucción.
El usuario prefiere que la tierra de nivelación sea siempre terreno normal,
aislada de la parte estructural — nunca inmune, nunca parte de la
deconstrucción, ni siquiera mientras el edificio está a medio construir.

`iniciar_construccion_fantasma()` gana un parámetro nuevo,
`celdas_estructurales` — el subconjunto de `orden` que SÍ debe registrarse
como parte del edificio (todo excepto el relleno):

```gdscript
## "celdas_estructurales" es el subconjunto de "orden" que representa al
## edificio en sí (paredes, puertas, ventanas, piso, mobiliario) — nunca
## incluye el relleno de nivelación. Solo esas celdas se registran como
## inmunes al minado / parte de la deconstrucción (ver registrar_edificio());
## el relleno de tierra queda fuera desde el primer instante, así que se
## comporta como terreno normal (minable, no participa en deconstruir el
## edificio) incluso mientras el edificio sigue a medio construir.
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, celdas_estructurales: Array, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	registrar_edificio(celdas_estructurales)
	return Construccion.iniciar(orden, tipos, metadata)
```

`CamaraCenital._procesar_clic_blueprint()` pasa `celdas_mundo.keys()`
(las celdas derivadas de `celdas_3d`, que nunca incluyen relleno) como
`celdas_estructurales`:

```gdscript
mundo.iniciar_construccion_fantasma(orden, tipos, celdas_mundo.keys(), metadata)
```

Efecto práctico: una celda de relleno que sigue siendo "fantasma" (sin
surtir todavía) puede minarse con click izquierdo como cualquier otro
bloque — deja un hueco temporal que se rellena solo cuando le toque su
turno de ser surtida (el pedido en `Construccion.gd` no se corrompe: sigue
pendiente igual, solo que su placeholder visual desapareció un momento
antes). Una vez surtida (convertida en "tierra" real), es un bloque más de
terreno colocado por el jugador, minable como cualquier otro — nunca vuelve
a ser inmune ni forma parte de ningún edificio.

### 3. `Recoleccion.gd`: liberar la reserva de un edificio demolido

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

### 4. `Zonificacion.gd`: zona de influencia reducible, con radio por categoría

Hoy `influencia_min`/`influencia_max` solo pueden crecer (`ampliar_influencia()`,
ver spec anterior), y todos los edificios usan el mismo margen
(`MARGEN_ZONA_INFLUENCIA = 15`, el mismo que el núcleo). El usuario pidió
dos cosas nuevas: (a) poder REDUCIR la zona al demoler, y (b) que el radio
dependa de la categoría del edificio — el núcleo sigue en 15, pero
residencial aporta 6, investigación e industrial 10, y militar 12. Nunca se
recuerda QUÉ edificio aportó qué parte del área con qué margen, así que no
hay forma de "quitar" la contribución de uno sin perder las demás. Se
agrega un registro de contribuciones por id de edificio (el mismo id de
`VoxelWorld.registrar_edificio()`), cada una con su propio margen, y la
zona se recalcula desde cero cada vez que algo cambia.

```gdscript
## Margen del núcleo urbano — sin cambios, sigue siendo especial (no tiene
## "categoria", es el único ancla fija de la zona de influencia).
const MARGEN_ZONA_INFLUENCIA := 15

## Margen de ampliación de la zona de influencia por categoría de edificio
## (ver BlueprintValidator.estructura_a_blueprint(), campo "categoria") —
## GDD: residencial aporta menos alcance que investigación/industrial, y
## militar el mayor de los cuatro (después del núcleo). Categorías todavía
## no declarables en esta PoC (investigacion/industrial/militar: no existe
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

## Huella del núcleo urbano (fija desde declarar_nucleo(), nunca se quita —
## el núcleo no es deconstruible, ver spec de deconstrucción) y, por cada
## edificio que ha ampliado la zona desde entonces, su huella Y su margen
## (según su categoría en el momento de ampliar) — juntas son la base para
## recalcular influencia_min/influencia_max desde cero en
## _recalcular_influencia(), cada vez que se agrega (ampliar_influencia())
## o se quita (retirar_contribucion()) una.
var _huella_nucleo: Array = []
var _contribuciones: Dictionary = {}  # int (id de edificio) -> {"huella": Array, "margen": int}
```

`declarar_nucleo()` cambia de calcular `influencia_min`/`influencia_max`
directamente a guardar `_huella_nucleo` y delegar en `_recalcular_influencia()`:

```gdscript
func declarar_nucleo(huella: Array) -> void:
	if nucleo_declarado:
		return
	_huella_nucleo = huella.duplicate()
	nucleo_declarado = true
	_recalcular_influencia()

	for celda in huella:
		zonas[celda] = "residencial_investigacion"
```

`ampliar_influencia()` cambia de firma — ahora recibe también el id del
edificio que amplía y su categoría (para elegir el margen):

```gdscript
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
```

Los dos sitios existentes que llaman `Zonificacion.ampliar_influencia(huella)`
(`Player._declarar_edificio()`/`Player._completar_construccion()`) pasan a
llamar `Zonificacion.ampliar_influencia(id, huella, blueprint["categoria"])`,
usando el id que ya devuelve `mundo.registrar_edificio()` y la categoría
del blueprint declarado/completado en ese mismo punto.

`BlueprintValidator.estructura_a_blueprint()` gana un campo nuevo en el
dict devuelto: `"categoria": "residencial"` (fijo por ahora — es la única
categoría real declarable en esta PoC; cuando existan blueprints de
investigación/industrial/militar, ese campo se ajustará según corresponda).

### 5. `Player.gd`: tecla `G`, modo deconstrucción, y el ciclo de interacción

**Nueva tecla `G`**: alterna un modo (como `modo_colocar_blueprint` en la
cámara cenital), con feedback visual en el HUD.

```gdscript
var modo_deconstruccion := false
var _id_listo_para_remocion := -1
var _ticks_listo_para_remocion := 0

## Cuántos "ticks" de acción repetida (INTERVALO_ACCION_REPETIDA, 0.2s)
## seguidos apuntando al MISMO edificio ya reducido a fantasma vacío hacen
## falta para eliminarlo del todo — demora deliberada (~1s) para evitar
## borrados accidentales al mantener el click presionado.
const TICKS_REMOCION_FINAL := 5
```

En `_input()`, junto a las demás teclas:
```gdscript
if tecla.pressed and tecla.keycode == KEY_G:
	_alternar_modo_deconstruccion()
```

```gdscript
## Activa/desactiva el modo deconstrucción — muestra/oculta el aviso en el
## HUD (ver HUD.gd). Al desactivarse, también se olvida cualquier progreso
## de "sostener para remoción final" (ver _procesar_deconstruccion()) — si
## el jugador sale del modo a medio sostener el click, no debe contar para
## la próxima vez que lo reactive.
func _alternar_modo_deconstruccion() -> void:
	modo_deconstruccion = not modo_deconstruccion
	if modo_deconstruccion:
		hud.mostrar_modo_deconstruccion()
	else:
		hud.ocultar_modo_deconstruccion()
	_id_listo_para_remocion = -1
	_ticks_listo_para_remocion = 0
```

`_minar()` (el manejador del click izquierdo, con repetición ya existente)
revisa el modo PRIMERO:

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

```gdscript
## Se llama en cada click/repetición de _minar() mientras modo_deconstruccion
## está activo. Delega toda la lógica de "qué revertir" en
## VoxelWorld.procesar_deconstruccion() — aquí solo se maneja lo que le
## corresponde al jugador/Ciudad/Zonificacion/Recoleccion: retirar camas la
## primera vez, y contar TICKS_REMOCION_FINAL intentos consecutivos sobre
## el MISMO edificio ya listo para remoción antes de eliminarlo del todo.
func _procesar_deconstruccion(celda: Vector3i) -> void:
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

**Exención del núcleo**: `procesar_deconstruccion()` en `VoxelWorld.gd` no
distingue el núcleo de cualquier otro edificio (ambos están igual de
registrados). La exención se aplica en `Player.gd`, ANTES de llamar a
`mundo.procesar_deconstruccion()`, comparando la huella del edificio
apuntado contra `Zonificacion._huella_nucleo`... pero `_huella_nucleo` es
privada. Se resuelve exponiendo una consulta puntual en `Zonificacion.gd`:

```gdscript
## true si "celda" (X,Z) pertenece a la huella del núcleo urbano — usada
## por Player.gd para negarse a deconstruir el núcleo (exento, ver spec de
## deconstrucción). No expone _huella_nucleo directamente para no acoplar
## a los demás lectores a su representación interna (Array vs Dictionary,
## etc.).
func celda_es_del_nucleo(celda: Vector2i) -> bool:
	return _huella_nucleo.has(celda)
```

`_procesar_deconstruccion()` en `Player.gd` gana, como primera línea:

```gdscript
	if Zonificacion.celda_es_del_nucleo(Vector2i(celda.x, celda.z)):
		print("El núcleo urbano no se puede deconstruir.")
		return
```

**`hud` en `Player.gd`**: no existe hoy (solo `CamaraCenital.gd` lo usa).
Se agrega igual que `mundo` (asignado por `Main.gd`), reutilizando el mismo
patrón que ya usa `CamaraCenital.gd`:

```gdscript
@onready var hud: CanvasLayer = get_node("../HUDLayer")
```

(`Player` es hermano de `HUDLayer` bajo `Main`, igual que `CamaraCenital` —
no hace falta que `Main.gd` lo asigne explícitamente, `get_node("../...")`
ya lo resuelve solo, mismo patrón que `CamaraCenital.gd` línea 135.)

### 6. `HUD.gd` + `Main.tscn`: aviso visual del modo deconstrucción

Nuevo `Label` en la escena (`Main.tscn`, bajo `HUDLayer`, hermano de
`MinaFicha`/`CazaFicha`):

```
[node name="ModoDeconstruccionLabel" type="Label" parent="HUDLayer"]
visible = false
offset_left = 12.0
offset_top = 300.0
offset_right = 420.0
offset_bottom = 330.0
text = "Modo deconstrucción activo (G para cancelar)"
```

`HUD.gd` gana la referencia y las dos funciones mostrar/ocultar, mismo
patrón que `mostrar_ficha_mina()`/`ocultar_ficha_mina()`:

```gdscript
@onready var modo_deconstruccion_label: Label = $ModoDeconstruccionLabel


func mostrar_modo_deconstruccion() -> void:
	modo_deconstruccion_label.visible = true


func ocultar_modo_deconstruccion() -> void:
	modo_deconstruccion_label.visible = false
```

## Pruebas

- **`CiudadTest.gd`**: nuevo caso para `retirar_edificio_residencial()` —
  registra un edificio, lo retira, confirma que el contador vuelve a 0; y
  que nunca baja de 0 (retirar más de lo registrado se clampa).
- **`BlueprintValidatorTest.gd`** (continúa la numeración, ya usa `mundo`
  real): tres casos nuevos — (a) declarar un edificio con blueprint,
  completarlo vía fantasma, deconstruirlo por completo bloque a bloque
  (orden inverso correcto: mobiliario antes que paredes, paredes antes que
  piso) y confirmar que `eliminar_edificio()` borra todas sus celdas y
  libera `celda_a_edificio`; (b) iniciar un edificio fantasma a medio
  construir (algunas celdas ya reales, otras todavía fantasma),
  deconstruirlo, y confirmar que las celdas YA fantasma nunca se "revierten"
  (no aparecen en el orden calculado) — solo las reales; (c) confirmar que
  una celda de RELLENO (pasada en `orden` pero no en `celdas_estructurales`
  al llamar `iniciar_construccion_fantasma()`) nunca queda registrada en
  `celda_a_edificio` — es minable de inmediato aunque siga siendo
  "fantasma", y no aparece en `edificio_a_celdas[id]`.
- **`ZonificacionTest.gd`**: actualizar las 4 llamadas existentes a
  `ampliar_influencia()` (TEST 9) para pasar un id y una categoría
  explícitos. Nuevo caso: ampliar la influencia con dos edificios de
  categorías distintas (p. ej. "residencial" margen 6 y "militar" margen
  12) y confirmar que cada uno expande la zona según SU PROPIO margen, no
  el del otro; retirar la contribución del de mayor margen y confirmar que
  la zona se reduce correctamente a lo que aporta el núcleo + el edificio
  restante (nunca menos que eso).
- **`RecoleccionTest.gd`** (usa el autoload real): nuevo caso para
  `quitar_puesto()` — coloca un puesto, confirma que
  `celda_dentro_de_algun_puesto()` lo detecta, lo quita, confirma que ya
  no lo detecta; quitar una esquina sin nada registrado no falla.
- **`Player.gd`/`HUD.gd`/`Main.tscn`**: sin pruebas automatizadas (lógica
  de input/cámara/escena, mismo patrón que el resto de esta sesión) —
  verificación por parseo headless de `Main.tscn` y confirmación manual del
  usuario jugando en vivo.

## Verificación de integración

Manual en el editor:

1. Declarar un edificio residencial válido, activar `G`, apuntar a una de
   sus paredes y hacer click — debe convertirse en fantasma; repetir hasta
   vaciarlo por completo; sostener el click un momento más — debe
   desaparecer del todo, y `Ciudad.capacidad_camas_construida` debe haberse
   reducido apenas empezó (no al final).
2. Colocar una copia de blueprint (modo `B`, cenital), surtirla
   parcialmente (algunas celdas reales, otras todavía fantasma), volver a
   primera persona, activar `G` y deconstruirla — las celdas ya fantasma no
   deben requerir ninguna acción extra.
3. Confirmar que el núcleo urbano NO se puede deconstruir (mensaje en
   consola, ninguna celda se revierte).
4. Colocar un segundo edificio que amplíe la zona de influencia (radio
   según su categoría — hoy siempre "residencial", margen 6),
   deconstruirlo por completo, y confirmar que la zona de influencia se
   reduce de vuelta (pero no más allá del núcleo + cualquier otro edificio
   que siga en pie).
5. Confirmar que, tras deconstruir por completo un edificio hecho vía
   blueprint, se puede volver a construir algo nuevo exactamente en su
   antigua huella (la reserva en `Recoleccion.puestos` se liberó).
6. Colocar un blueprint sobre terreno irregular (que exija relleno de
   nivelación), surtirlo por completo, y confirmar que la tierra de
   relleno es minable con click izquierdo normal (sin activar el modo
   deconstrucción) tanto mientras el edificio existe como después de
   deconstruirlo — nunca se comporta como parte inmune del edificio.
