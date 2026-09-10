# Edificios como Objeto Completo (inmunes al minado bloque por bloque) — Diseño

## Contexto

Con blueprints + construcción fantasma ya implementados (ver
`docs/superpowers/specs/2026-09-10-blueprints-construccion-fantasma-design.md`),
cada celda de un edificio —fantasma o ya terminado— sigue siendo, para
`VoxelWorld`, un bloque más del `GridMap`, indistinguible de cualquier otro
bloque suelto. Jugando en vivo se detectó que esto permite:

- Minar con click izquierdo cualquier celda "fantasma" mientras se está
  surtiendo una construcción (antes de este fix ya se corrigió que el
  surtido use click derecho, pero el click izquierdo seguía minando la
  celda fantasma en vez de no hacer nada).
- Minar bloque por bloque un edificio ya terminado (pared, puerta, ventana,
  cama, baúl), exactamente igual que un bloque de terreno cualquiera.

La corrección: un edificio (fantasma o terminado) debe comportarse como un
objeto completo frente al minado, igual que ya se comportan los árboles
(`TIPOS_ARBOL`, `talar_bloque_de_arbol()`, registrados en `GeneradorArbol`)
frente a `_minar()` — no una colección de celdas independientes. Esto además
sienta la base para rotar un edificio completo más adelante (mover/rotar el
conjunto de celdas registrado, no bloque por bloque), aunque la rotación en
sí queda fuera de alcance de este spec.

## Objetivo

Ninguna celda que forme parte de un edificio registrado (fantasma en curso,
terminado, o puesto periférico) puede minarse individualmente con
`minar_bloque()`. El click izquierdo sobre esa celda no tiene efecto —no se
imprime mensaje, no se destruye nada— igual que hoy no pasa nada al minar
una celda ya vacía.

## Fuera de alcance

- Rotación de edificios completos (mencionada como beneficio futuro, no se
  implementa aquí).
- Interacción con objetos internos del edificio (abrir puerta, usar cama,
  abrir baúl, mesa de trabajo) — sigue sin existir como mecánica.
- Demolición/deconstrucción de un edificio completo como objeto (no hay
  mecanismo para "deshacer" un edificio ya construido; solo se bloquea el
  minado bloque por bloque).
- Personalización del núcleo urbano como monumento (trofeos, moral) —
  mencionada por el usuario como contexto futuro; el núcleo se registra
  como inmune igual que cualquier otro edificio declarado, sin tratamiento
  especial en este spec.
- Migración de los puestos periféricos al mecanismo de fantasma+suministro
  (sub-proyecto B, ya documentado como pendiente en el spec de blueprints).
  Los puestos periféricos siguen siendo marcadores de bloque(s) reales
  colocados de inmediato, pero SÍ se incluyen en el registro de inmunidad
  de este spec (ver más abajo) — no hay que esperar a esa migración.

## Diseño

### Registro de celdas de edificio (`VoxelWorld.gd`)

Nuevo estado, mismo patrón que `colocado_por_jugador`/`pareja` (diccionarios
por celda, sin autoload nuevo — es estado del mundo físico, vive donde ya
viven `colocado_por_jugador` y `pareja`):

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

### Guardia en `minar_bloque()`

```gdscript
func minar_bloque(celda: Vector3i) -> bool:
	if celda_a_edificio.has(celda):
		return false
	if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
		return false
	...
```

Se coloca como primera condición: ni siquiera se evalúa si la celda tiene un
bloque real, porque una celda fantasma también debe negarse (y sí tiene un
`get_cell_item()` válido, el bloque placeholder). `Player._minar()` no
necesita ningún cambio — ya ignora el valor de retorno de `minar_bloque()`,
así que "no hacer nada" es automático.

### Puntos de registro

**1. Fantasma en curso** — `iniciar_construccion_fantasma()`, que ya coloca
el bloque `"fantasma"` en cada celda de `orden`, registra esas mismas
celdas de inmediato:

```gdscript
func iniciar_construccion_fantasma(orden: Array, tipos: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden:
		colocar_bloque(celda, "fantasma")
	registrar_edificio(orden)
	return Construccion.iniciar(orden, tipos, metadata)
```

Incluye el relleno de tierra de nivelación (primer grupo de
`ORDEN_GRUPOS_CONSTRUCCION`, ver spec de blueprints): forma parte del
`orden` del blueprint, así que queda protegido igual que paredes/puertas.
El registro NO se borra cuando `Construccion` limpia su propio
`_celda_a_construccion` al completarse (son registros independientes con
propósitos distintos) — la inmunidad persiste después de terminado el
edificio, que es justamente el objetivo.

**2. Puesto periférico** — en `CamaraCenital.gd`, en el punto donde ya se
coloca el bloque marcador del puesto (footprint completo, no fantasma):

```gdscript
var bloque_marcador: String = "mina" if _tipo_puesto_activo == "mina" else "puesto_caza"
var celdas_puesto: Array = []
for dx in range(_ancho_puesto_activo):
	for dz in range(_alto_puesto_activo):
		var celda := Vector3i(esquina.x + dx, objetivo + 1, esquina.y + dz)
		mundo.colocar_bloque(celda, bloque_marcador)
		celdas_puesto.append(celda)
mundo.registrar_edificio(celdas_puesto)
```

El relleno de tierra de nivelación bajo el puesto (líneas previas, ya
existentes) NO se incluye en `celdas_puesto` — sigue siendo terreno, mismo
criterio que `TIPOS_ESTRUCTURA` ya aplica al excluir `"piso"` de la
detección de estructura de un edificio.

**3. Núcleo declarado manualmente** — `Player._declarar_edificio()`, en la
rama donde `resultado["valido"]` es verdadero (bloque por bloque, sin pasar
por fantasma):

```gdscript
if resultado["valido"]:
	Blueprints.guardar(blueprint)
	mundo.registrar_edificio(celdas.keys())
	...  # resto sin cambios
```

`celdas` ya es el diccionario devuelto por `mundo.detectar_estructura(celda)`
unas líneas antes — sus llaves son exactamente las celdas físicas de la
estructura detectada (sin incluir "piso", por el mismo motivo de siempre).

### Qué no requiere cambios

- `surtir_construccion()` (click derecho): sigue igual, la celda ya está
  registrada desde `iniciar_construccion_fantasma()`.
- `_colocar()` (colocar un bloque nuevo contra una cara): coloca contra la
  celda ADYACENTE, vacía por definición — nunca contra una celda ya
  registrada.
- `reemparejar_construccion()`, `Construccion.gd`, `Blueprints.gd`: sin
  cambios, son registros independientes con su propio propósito.

## Pruebas

Se extiende `BlueprintValidatorTest.gd` (ya instancia un `VoxelWorld` real
para los TEST 15/16/18/19) con un TEST 20:

- Coloca un par de celdas reales y llama `mundo.registrar_edificio([...])`.
- Confirma que `mundo.minar_bloque(celda_registrada)` devuelve `false` y el
  bloque sigue presente (`obtener_tipo()` sin cambios).
- Confirma que una celda normal, no registrada, sigue minándose igual que
  antes (`minar_bloque()` devuelve `true`, la celda queda vacía).
- Confirma el caso fantasma: `iniciar_construccion_fantasma()` deja las
  celdas inmunes de inmediato (antes de surtir ninguna), y siguen inmunes
  después de completarse la construcción (surtiendo todas con
  `surtir_construccion()`).

## Verificación de integración

Manual en el editor (no hay test automatizado de `Player.gd`/
`CamaraCenital.gd`, mismo patrón que el resto de la sesión):

1. Colocar un blueprint (fantasma) y hacer click izquierdo sobre una celda
   fantasma → no pasa nada.
2. Surtir el edificio completo (click derecho) y hacer click izquierdo
   sobre una pared/puerta/cama del edificio terminado → no pasa nada.
3. Colocar un puesto (mina o caza/recolección) y hacer click izquierdo
   sobre su marcador → no pasa nada.
4. Declarar el núcleo urbano bloque por bloque (flujo manual, sin
   blueprint) y hacer click izquierdo sobre una de sus paredes → no pasa
   nada.
5. Confirmar que minar un bloque de terreno normal, o talar un árbol,
   sigue funcionando exactamente igual que antes.
