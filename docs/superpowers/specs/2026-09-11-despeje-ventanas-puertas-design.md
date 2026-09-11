# Despeje de Proximidad para Ventanas y Puertas — Diseño

## Contexto

El GDD prevé redes de distribución de recursos y movimiento de NPCs que
dependen de que los edificios tengan acceso físico despejado: una puerta
necesita espacio para que un medio de transporte cargue/descargue, y una
ventana necesita quedar realmente al exterior, no tapada por otra
construcción. Hoy nada impide construir un edificio pegado directamente a
la ventana o la puerta de otro — el jugador pidió resolver esto ahora,
antes de que existan NPCs o transporte, para no tener que revisar cada
edificio ya construido más adelante.

Regla pedida por el usuario:
- Toda celda **ventana** necesita 1 celda vacía hacia su lado externo.
- Toda celda **puerta** (`puerta_inferior` y `puerta_superior`, ambos
  niveles) necesita 2 celdas vacías hacia su lado externo, para que quepa
  un medio de transporte.
- La limitación aplica contra bloques estructurales, terreno y árboles.
- Los despejes de dos edificios DISTINTOS pueden solaparse libremente
  (dos puertas enfrentadas separadas por 2 bloques, o el despeje de una
  ventana cayendo sobre el despeje de una puerta ajena) — lo único
  prohibido es que una celda **estructural** de un edificio caiga dentro
  del despeje reservado de otro.
- La reserva de despeje de un edificio persiste mientras exista su id, y
  se libera por completo al deconstruirlo/eliminarlo (mismo ciclo de vida
  que `celda_a_edificio`).

## Objetivo

- Ningún blueprint ni edificio declarado a mano puede colocarse si alguna
  de sus propias celdas de despeje (calculadas a partir de sus ventanas y
  puertas) no está físicamente vacía en el momento de la colocación.
- Ningún blueprint ni edificio declarado a mano puede colocarse si alguna
  de sus celdas **estructurales** cae dentro del despeje ya reservado de
  OTRO edificio existente.
- Una vez colocado, el despeje de un edificio queda reservado (aunque la
  celda siga físicamente vacía) y bloquea construcciones futuras ahí,
  hasta que el edificio se deconstruya/elimine por completo
  (`eliminar_edificio()`).
- Los despejes de dos edificios distintos pueden solaparse sin problema —
  solo se valida estructura-contra-despeje, nunca despeje-contra-despeje.

## Fuera de alcance

- **Medios de transporte**: no existen todavía en esta PoC. El despeje
  garantiza que esas celdas queden vacías y reservadas; cuando se
  implemente el sistema de transporte, esa pieza futura deberá tratarse
  como una excepción explícita a "no ocupar despeje ajeno" (dependencia
  documentada aquí, no resuelta en este spec).
- **Revalidación continua**: si el terreno cambia después (p. ej. una
  futura mecánica de crecimiento de bosque) e invade un despeje ya
  reservado, no se detecta ni se corrige — solo se valida al momento de
  construir.
- **Puestos periféricos** (mina, caza/recolección): no tienen celdas
  `ventana`/`puerta`, así que nunca generan despeje propio. Tampoco se les
  exige respetar el despeje ajeno en este spec — viven fuera de la zona
  de influencia por diseño (`Zonificacion.dentro_de_influencia()`), lejos
  de los edificios residenciales que sí tienen ventanas/puertas. Si algún
  día un puesto pudiera colocarse cerca de un edificio, esto tendría que
  revisarse.
- **Minado/colocación de bloques sueltos** (`Player._minar()`/`_colocar()`
  fuera del flujo de construcción de edificios): no consulta la reserva de
  despeje — mismo criterio que ya usan las reservas de
  `Recoleccion.puestos`, que tampoco se aplican ahí.

## Diseño

### 1. `VoxelWorld.gd`: nuevo modelo de datos y dirección cardinal en XZ

Nuevo const, mismo patrón que `BlueprintValidator.VECINOS_ORTOGONALES`
(junto a `VECINOS_3D`):

```gdscript
## Las 4 direcciones cardinales en el plano XZ — usadas por
## calcular_despeje() para encontrar el lado "externo" de una celda
## ventana/puerta (cualquier vecino XZ que no pertenezca a la huella del
## propio edificio).
const VECINOS_ORTOGONALES_XZ: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
```

Nuevo estado, junto a `edificio_orden`/etc.:

```gdscript
## Por edificio: las celdas de despeje reservadas por sus ventanas/puertas
## (ver calcular_despeje()) y su consulta inversa — mismo patrón que
## edificio_a_celdas/celda_a_edificio. Persiste mientras exista el id del
## edificio, se libera por completo en eliminar_edificio() — ver
## docs/superpowers/specs/2026-09-11-despeje-ventanas-puertas-design.md.
## El despeje de dos edificios DISTINTOS puede solaparse libremente: solo
## se compara celda ESTRUCTURAL nueva contra despeje ajeno
## (verificar_despejes()), nunca despeje contra despeje.
var edificio_despeje: Dictionary = {}  # int -> Array[Vector3i]
var celda_a_despeje: Dictionary = {}  # Vector3i -> int
```

### 2. `VoxelWorld.gd`: `calcular_despeje()`

```gdscript
## Calcula las celdas de despeje que exige "celdas_mundo" (Vector3i real ->
## tipo, las celdas ESTRUCTURALES de un edificio — mismo formato que
## registrar_edificio_completo()/iniciar_construccion_fantasma() ya usan).
## Para cada celda "ventana" o "puerta_inferior"/"puerta_superior", revisa
## sus 4 vecinos cardinales en XZ; cualquiera que NO pertenezca a la huella
## del propio edificio (es decir, cae fuera de celdas_mundo en esa columna)
## es una dirección "externa". En cada dirección externa se reservan 1
## celda (ventana) o 2 celdas (puerta, en AMBOS niveles) a la misma altura
## Y de la celda original. Devuelve un Array sin duplicados (una celda de
## despeje puede quedar "pedida" por más de una ventana/puerta vecina).
func calcular_despeje(celdas_mundo: Dictionary) -> Array:
	var huella_xz: Dictionary = {}  # Vector2i -> true
	for celda in celdas_mundo:
		huella_xz[Vector2i(celda.x, celda.z)] = true

	var despeje: Dictionary = {}  # Vector3i -> true, para deduplicar
	for celda in celdas_mundo:
		var tipo: String = celdas_mundo[celda]
		var profundidad := 0
		if tipo == "ventana":
			profundidad = 1
		elif tipo == "puerta_inferior" or tipo == "puerta_superior":
			profundidad = 2
		else:
			continue

		for direccion in VECINOS_ORTOGONALES_XZ:
			var vecino_xz := Vector2i(celda.x, celda.z) + direccion
			if huella_xz.has(vecino_xz):
				continue  # vecino es parte del propio edificio, no es "externo"
			for paso in range(1, profundidad + 1):
				var celda_despeje := Vector3i(
					celda.x + direccion.x * paso, celda.y, celda.z + direccion.y * paso
				)
				despeje[celda_despeje] = true
	return despeje.keys()
```

### 3. `VoxelWorld.gd`: `verificar_despejes()`

```gdscript
## Valida si "celdas_mundo" (las celdas estructurales de un edificio a
## punto de colocarse, mismo formato que calcular_despeje()) respeta la
## regla de despeje: (a) ninguna de sus propias celdas de despeje puede
## estar físicamente ocupada (terreno, árbol, o cualquier estructura —
## cualquier bloque real tiene un tipo no vacío, así que basta comparar
## contra "" sin enumerar tipos "sólidos"), y (b) ninguna de sus celdas
## ESTRUCTURALES puede caer dentro del despeje YA RESERVADO de otro
## edificio (celda_a_despeje). El despeje del edificio nuevo NUNCA se
## compara contra el despeje ajeno — dos despejes distintos pueden
## solaparse libremente (puertas enfrentadas, ventana sobre despeje de
## puerta ajena, etc.), ver spec punto de diseño.
func verificar_despejes(celdas_mundo: Dictionary) -> bool:
	for celda in celdas_mundo:
		if celda_a_despeje.has(celda):
			return false
	for celda_despeje in calcular_despeje(celdas_mundo):
		if obtener_tipo(celda_despeje) != "":
			return false
	return true
```

### 4. `VoxelWorld.gd`: registrar y liberar la reserva

`iniciar_construccion_fantasma()` gana el registro de despeje, calculado
sobre `tipos_estructura` (ya es Vector3i -> tipo de las celdas
estructurales, formato exacto que `calcular_despeje()` espera):

```gdscript
func iniciar_construccion_fantasma(orden_relleno: Array, tipos_relleno: Dictionary, orden_estructura: Array, tipos_estructura: Dictionary, metadata: Dictionary = {}) -> int:
	for celda in orden_relleno:
		colocar_bloque(celda, "fantasma")
	if not orden_relleno.is_empty():
		Construccion.iniciar(orden_relleno, tipos_relleno)
	for celda in orden_estructura:
		colocar_bloque(celda, "fantasma")
	var id: int = registrar_edificio(orden_estructura)
	edificio_orden[id] = orden_estructura
	edificio_tipos[id] = tipos_estructura
	edificio_progreso[id] = 0
	edificio_metadata[id] = metadata
	var despeje: Array = calcular_despeje(tipos_estructura)
	edificio_despeje[id] = despeje
	for celda_despeje in despeje:
		celda_a_despeje[celda_despeje] = id
	return id
```

`registrar_edificio_completo()` gana la misma lógica, sobre `celdas_mundo`:

```gdscript
func registrar_edificio_completo(celdas_mundo: Dictionary, metadata: Dictionary = {}) -> int:
	var orden: Array = ordenar_celdas_edificio(celdas_mundo)
	var id: int = registrar_edificio(orden)
	edificio_orden[id] = orden
	edificio_tipos[id] = celdas_mundo
	edificio_progreso[id] = orden.size()
	edificio_metadata[id] = metadata
	var despeje: Array = calcular_despeje(celdas_mundo)
	edificio_despeje[id] = despeje
	for celda_despeje in despeje:
		celda_a_despeje[celda_despeje] = id
	return id
```

`eliminar_edificio()` libera la reserva junto con el resto del estado del
id:

```gdscript
	edificio_a_celdas.erase(id)
	edificio_orden.erase(id)
	edificio_tipos.erase(id)
	edificio_progreso.erase(id)
	edificio_metadata.erase(id)
	for celda_despeje in edificio_despeje.get(id, []):
		celda_a_despeje.erase(celda_despeje)
	edificio_despeje.erase(id)
	return esquina
```

(Esta última línea reemplaza el actual `return esquina` — todo lo demás de
`eliminar_edificio()` queda igual.)

### 5. `CamaraCenital.gd`: validar despeje al colocar un blueprint

`_procesar_clic_blueprint()` necesita `celdas_mundo` (y por lo tanto
`objetivo`, del que depende su altura real) ANTES de decidir si rechaza la
colocación — hoy ambos se calculan DESPUÉS de las validaciones existentes
y de los efectos secundarios (talar follaje, drenar agua). Se reordena
para calcular `objetivo`/`celdas_mundo` justo después de las validaciones
existentes y ANTES de cualquier efecto secundario, para poder rechazar por
despeje sin haber alterado ya el mundo:

```gdscript
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)
	var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]

	if not _huella_en_zona_correcta(esquina, columnas, _blueprint_activo["zona_permitida"]):
		print("Colocación rechazada: esta zona no acepta este blueprint.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, columnas):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas, altura_blueprint)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, columnas):
		print("Colocación rechazada: la huella choca con un puesto o construcción ya colocada.")
		return
	if not _huella_tiene_columna_en_tierra(esquina, columnas):
		print("Colocación rechazada: la huella necesita al menos una columna sobre tierra firme.")
		return

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, objetivo + 1 + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]
	if not mundo.verificar_despejes(celdas_mundo):
		print("Colocación rechazada: una ventana o puerta quedaría sin el despeje mínimo, o invade el despeje de otro edificio.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for rel in columnas:
		total_drenado += mundo.drenar_agua(esquina.x + rel.x, esquina.y + rel.y)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

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

Cambios respecto a la versión actual: `objetivo` y `celdas_mundo` se
calculan ANTES de talar follaje/drenar agua (en vez de después), se agrega
el rechazo por despeje justo después de calcularlos, y `relleno`/
`relleno_orden`/`tipos_relleno`/`orden_estructura` se calculan más abajo,
después de los efectos secundarios — sin cambios en su lógica interna, solo
de orden. Nada de esto afecta lo que ya se probaba (mismo resultado final
en `celdas_mundo`/`orden_estructura`/`metadata`).

### 6. `Player.gd`: validar despeje al declarar un edificio a mano

`_declarar_edificio()` ya tiene `celdas` (Vector3i -> tipo, de
`detectar_estructura()`) en el formato exacto que `verificar_despejes()`
espera. Se agrega el chequeo junto al de `resultado["valido"]`:

```gdscript
	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if not resultado["valido"]:
		return
	if not mundo.verificar_despejes(celdas):
		print("Declarar edificio: una ventana o puerta quedaría sin el despeje mínimo, o invade el despeje de otro edificio.")
		return

	Blueprints.guardar(blueprint)
```

(Reemplaza el bloque `if not resultado["valido"]: return` seguido
directamente de `Blueprints.guardar(blueprint)` — se inserta el nuevo
chequeo entre ambos, sin tocar nada más de la función.)

## Pruebas

Todas en `BlueprintValidatorTest.gd` (usa `mundo` real, mismo patrón que
las pruebas 18-27):

- **TEST 28** — `calcular_despeje()` para una ventana en una pared exterior
  (un edificio de 1x1 con una sola pared tipo "ventana" en un lado):
  confirma que devuelve exactamente 1 celda, a 1 columna de distancia en
  la dirección externa correcta, y que NO incluye ninguna celda hacia el
  interior de la huella.
- **TEST 29** — `calcular_despeje()` para una puerta (`puerta_inferior` +
  `puerta_superior` en la misma columna): confirma 4 celdas totales (2 de
  profundidad en cada uno de los 2 niveles Y), todas en la dirección
  externa correcta.
- **TEST 30** — `verificar_despejes()` rechaza cuando el propio despeje no
  está vacío: coloca un bloque de terreno (o un árbol) exactamente en la
  celda de despeje de una ventana antes de intentar registrar el edificio,
  confirma que devuelve `false`; quita ese bloque y confirma que pasa a
  `true`.
- **TEST 31** — `verificar_despejes()` rechaza cuando una celda
  ESTRUCTURAL del edificio nuevo cae en el despeje reservado de OTRO
  edificio: registra un primer edificio con una ventana (vía
  `registrar_edificio_completo()`), confirma que una pared nueva colocada
  exactamente en su celda de despeje es rechazada por
  `verificar_despejes()` de un segundo edificio hipotético.
- **TEST 32** — dos despejes de edificios distintos SÍ pueden solaparse:
  dos edificios con puertas enfrentadas separadas por 2 celdas (o una
  ventana cuyo despeje cae sobre el despeje de una puerta ajena) — ambos
  se registran sin rechazo, confirmando que `verificar_despejes()` nunca
  compara despeje contra despeje.
- **TEST 33** — `eliminar_edificio()` libera la reserva de despeje:
  registra un edificio con ventana, confirma que su celda de despeje
  bloquea a un segundo edificio hipotético (vía `verificar_despejes()`),
  elimina el primero con `eliminar_edificio()`, confirma que la misma
  validación ahora pasa.

## Verificación de integración

Manual en el editor:

1. Colocar un blueprint con ventana pegado a un árbol o a una pared de
   terreno elevado en su lado de la ventana — debe rechazarse con el
   mensaje de despeje.
2. Colocar dos blueprints de forma que una puerta del segundo apunte hacia
   una ventana ya construida del primero, separados por menos de 1 celda —
   debe rechazarse.
3. Colocar dos blueprints con sus puertas enfrentadas, separadas
   exactamente por 2 celdas — debe aceptarse (los despejes se solapan,
   ninguna celda estructural invade al otro).
4. Deconstruir por completo un edificio con ventana, y confirmar que
   inmediatamente se puede construir otra cosa en la celda que antes era
   su despeje.
