# Puesto de Pesca y Frutos del Mar — Diseño

**Alcance:** PoC 6 (Fase 3 del roadmap, GDD Sección 11), cuarto tipo de puesto
periférico de la categoría "Recolección" (GDD Sección 3). Cierra el pendiente
dejado explícitamente fuera de alcance en
`docs/superpowers/specs/2026-09-10-puestos-huella-real-caza-recoleccion-design.md`
("el puesto de pesca/frutos del mar queda fuera de alcance... depende de
ríos/lagos con peces, señal que no existe todavía") — esa dependencia ya
existe (`PoC_6/`, secciones 3.10/3.11: ríos con corriente, `es_agua_en()`,
`es_rio_en()`, y el patrón ya probado de señales de ruido por celda).

**Repo:** `C:\Users\peraz\Projects\Misc\CityCraft`, proyecto Godot 4.7 compartido en `godot/`.

## Decisiones de alcance confirmadas con el usuario

- Huella **3×5** (`ANCHO_HUELLA_PESCA_FRUTOS_MAR = 3`, `ALTO_HUELLA_PESCA_FRUTOS_MAR = 5`),
  rotable con `Ctrl`+rueda como el maderero. Cabe en el pool fijo de planos
  fantasma (`MAX_ANCHO_HUELLA_PUESTO = 5`, `MAX_ALTO_HUELLA_PUESTO = 5`) sin
  tocarlo.
- Tecla `F` (de "Fishing" — mismo criterio de mnemónico en inglés que M/H/L;
  el usuario aclaró que estos atajos podrán cambiar más adelante cuando
  exista una interfaz gráfica de menú de construcción).
- **Regla de colocación nueva y exclusiva de este puesto:** de los dos
  extremos de 3 celdas (las filas `dz=0` y `dz=alto-1` del rectángulo 3×5),
  exactamente uno debe estar **completamente** sobre agua y el opuesto
  **completamente** sobre tierra firme. Las 3 filas intermedias (`dz=1..3`)
  no tienen restricción — son la zona de transición del muelle. Si ambos
  extremos son agua, ambos son tierra, o cualquiera de los dos está
  mezclado, la colocación se rechaza. Esto reemplaza, solo para este tipo,
  la regla genérica `_huella_tiene_columna_en_tierra()` (que exige apenas
  una columna en tierra en cualquier parte de la huella).
- **Periferia del extremo de agua también debe ser agua real (7 celdas):**
  no basta con que las 3 celdas del extremo sean agua — el extremo no puede
  ser un charco angosto que termine justo en el borde de la huella. Se
  exige agua en las 7 celdas que rodean ese extremo por los 3 lados
  expuestos (izquierda, derecha y frente; el lado de "atrás" no se revisa,
  es el que conecta con la huella): las 2 celdas de flanco (una a cada lado
  del extremo, a su misma fila) más toda la fila inmediatamente al frente,
  extendida un bloque más allá de cada flanco (5 celdas de ancho, ya que el
  extremo mide 3) — `2 + (ancho + 2) = ancho + 4 = 7` para `ancho = 3`.
  Geométricamente son "dos L" que envuelven cada esquina exterior del
  extremo (flanco + diagonal + celda de frente adyacente, 3 celdas cada
  una) más el bloque central de frente — 7 celdas en total, todas
  obligatoriamente agua.
- **Confirmación con pilotes, no drenaje total (decisión explícita del
  usuario):** a diferencia de los demás puestos (que drenan y nivelan a
  `"tierra"` toda su huella), aquí solo las **2 esquinas** del extremo de
  agua (los dos vértices de esa fila de 3 celdas) se rellenan hasta la
  altura objetivo con bloque `"pared"` (pilotes/estacas — placeholder de
  PoC; el usuario ya anticipó que más adelante el material del pilote podrá
  variar según la era de la construcción: madera, piedra, o piedra+hierro
  para concreto — **no se implementa esa variación todavía**, queda
  anotada como trabajo futuro). El resto de las celdas de agua bajo la
  huella (la celda central del extremo de agua, y cualquier agua en las
  filas intermedias) **no se toca**: sigue siendo agua real, abierta bajo
  la plataforma. El extremo de tierra y cualquier otra columna ya seca de
  las filas intermedias se nivelan con `"tierra"` exactamente igual que
  cualquier otro puesto.
- **Radio de acción:** 25 celdas (`RADIO_AREA_PESCA_FRUTOS_MAR = 25`),
  medido desde el **punto medio del extremo de agua** (`dx = ancho/2` de esa
  fila — al ser `ancho = 3` impar, cae exacto en una celda, sin redondeos),
  no desde el centro geométrico de toda la huella como los demás puestos.
- El área de acción **no cuenta ni dibuja ninguna columna que no sea agua**
  — a diferencia de `_actualizar_area_accion()` (usada por mina/caza/madero),
  que sencillamente recorre un círculo geométrico sin filtrar por tipo de
  terreno. Aquí cada columna de tierra dentro del círculo se omite por
  completo, tanto visualmente (no se dibuja su plano) como en el promedio de
  las señales (no cuenta como muestra). Motivo: este puesto, por diseño,
  siempre tiene su origen justo en la costa — incluir la tierra como parte
  del denominador castigaría sistemáticamente el promedio solo por estar,
  como se requiere, junto a la orilla.
- **Profundidad:** para el volumen de agua dentro del radio se considera
  toda la profundidad de cada columna (sin tope artificial de "niveles"
  como la semiesfera de la mina) — pero, como se explica más abajo, la
  señal de peces terminó siendo ruido puro (no depende de la profundidad
  real), así que en la práctica solo la señal de algas/frutos del mar usa
  la profundidad.
- **Dos señales placeholder** (mientras no existan NPCs acuáticos ni bloques
  de algas/frutos del mar reales), ambas normalizadas a `[0, 1]` — mismo
  formato que fauna/frutal/árbol:
  - **Peces:** nueva señal de **ruido** en `GeneradorMundo`
    (`densidad_peces_en(x, z)`), exactamente el mismo patrón que
    `densidad_fauna_en()`/`densidad_frutal_en()`/`densidad_arbol_en()`
    (`FastNoiseLite` propio, `frequency = 0.05`), pero con guarda
    `es_agua_en(x, z)` en vez de `es_bioma_en(x, z)`. Decisión explícita del
    usuario tras notar que una señal puramente basada en profundidad real
    sería demasiado determinista/plana — el ruido crea "nubes" de más/menos
    peces tanto en el mar como en cualquier río, sin importar la
    profundidad ni el tipo de cuerpo de agua.
  - **Algas/frutos del mar:** señal **geométrica** (no ruido), inversamente
    proporcional a la profundidad relativa de cada columna de agua respecto
    al máximo realista de SU tipo de cuerpo de agua — agua somera (más luz)
    da más señal que agua profunda. Se mantiene basada en geometría real (a
    diferencia de peces) porque tiene sentido biológico: el crecimiento de
    algas depende de la luz solar, que sí es una función determinista de la
    profundidad, mientras que los peces son población migratoria/aleatoria.
  - **Normalización por tipo de cuerpo de agua (clave para que un río no
    quede sistemáticamente "vacío" frente al mar):** cada columna de agua
    normaliza su profundidad contra el techo realista de SU PROPIO tipo,
    no contra una única constante global:
    - Columna de río (`es_rio_en(x, z)` verdadero): profundidad real =
      `profundidad_rio_en(x, z)`, techo = `PROFUNDIDAD_MAXIMA_RIO` (ya
      existe, `= 3`).
    - Columna de mar/lago (agua no fluvial): profundidad real =
      `nivel_mar - altura_en(x, z)`, techo = `nivel_mar - ALTURA_MINIMA`
      (la profundidad máxima teóricamente posible en este mundo).
    Así, un río completamente lleno (profundidad 3 de 3) da la misma señal
    de "agua somera/profunda" que un punto de mar en su extremo
    correspondiente, en vez de que el río siempre parezca superficial
    comparado con la escala del océano.
- Sigue sin producción real por tick, sin inventario, sin cobro del costo de
  construcción — mismo alcance reducido que los otros tres puestos.

## 1. `GeneradorMundo.gd` — dos señales nuevas

Siguiente semilla derivada libre: `semilla + 7` (usadas hasta ahora: base=0,
mineral=+1, fauna=+2, frutal=+3, árbol=+4, RNG de ríos=+5, detalle=+6).

```gdscript
_ruido_peces = FastNoiseLite.new()
_ruido_peces.seed = semilla + 7
_ruido_peces.noise_type = FastNoiseLite.TYPE_PERLIN
_ruido_peces.frequency = 0.05
```

```gdscript
## true si (x, z) es agua de cualquier tipo — mar/lago (es_agua_en()) o río
## (es_rio_en(), que puede estar muy por encima del nivel del mar). Punto
## único para cualquier lógica que deba tratar ambos tipos de agua por
## igual (señales de peces/algas, radio de acción del puesto de pesca).
func es_agua_o_rio_en(x: int, z: int) -> bool:
	return es_agua_en(x, z) or es_rio_en(x, z)


## Densidad de peces en la columna de agua (x, z), en [0, 1] — 0.0 si la
## columna no es agua (ver es_agua_o_rio_en()). Ruido puro (mismo patrón que
## densidad_fauna_en()/densidad_frutal_en()/densidad_arbol_en()): crea
## "nubes" de más/menos peces tanto en el mar como en cualquier río, sin
## relación con la profundidad real de esa columna (decisión explícita:
## una señal solo basada en profundidad resultaba demasiado plana/predecible).
func densidad_peces_en(x: int, z: int) -> float:
	if not es_agua_o_rio_en(x, z):
		return 0.0
	var valor: float = _ruido_peces.get_noise_2d(x, z)
	return (valor + 1.0) / 2.0


## Profundidad relativa de la columna de agua (x, z) en [0, 1], normalizada
## contra el techo realista de SU tipo de cuerpo de agua (río vs. mar/lago —
## ver "Normalización por tipo de cuerpo de agua" en la sección de
## decisiones), para que un río (profundidad máxima 3) y un mar (profundidad
## máxima nivel_mar - ALTURA_MINIMA) sean comparables en la misma escala.
## 0.0 si la columna no es agua.
func _profundidad_relativa_agua_en(x: int, z: int) -> float:
	if not es_agua_en(x, z):
		return 0.0
	if es_rio_en(x, z):
		return float(profundidad_rio_en(x, z)) / float(PROFUNDIDAD_MAXIMA_RIO)
	var techo: int = nivel_mar - ALTURA_MINIMA
	if techo <= 0:
		return 0.0
	var profundidad: int = nivel_mar - altura_en(x, z)
	return clampf(float(profundidad) / float(techo), 0.0, 1.0)


## Densidad de algas/frutos del mar en la columna de agua (x, z), en [0, 1]
## — 0.0 si la columna no es agua (ver es_agua_o_rio_en()). Geométrica, no
## ruido: inversa a la profundidad relativa (agua somera = más luz = más
## señal) — a diferencia de densidad_peces_en(), tiene sentido que dependa
## de geometría real.
func densidad_algas_en(x: int, z: int) -> float:
	if not es_agua_o_rio_en(x, z):
		return 0.0
	return 1.0 - _profundidad_relativa_agua_en(x, z)
```

## 2. `Recoleccion.gd` — constantes, detección y tasas

```gdscript
const ANCHO_HUELLA_PESCA_FRUTOS_MAR := 3
const ALTO_HUELLA_PESCA_FRUTOS_MAR := 5

const RADIO_AREA_PESCA_FRUTOS_MAR := 25
const PASO_MUESTREO_PESCA_FRUTOS_MAR := 2  # mismo patrón de muestreo que caza/recolección y maderero
const TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO := 2.0

# GDD Sección 3 — mismos valores placeholder que los otros tres puestos,
# sin balance real todavía (ver Recoleccion.COSTO_CONSTRUCCION).
const COSTO_CONSTRUCCION_PESCA_FRUTOS_MAR := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_PESCA_FRUTOS_MAR := 3
const CAPACIDAD_ALMACENAMIENTO_PESCA_FRUTOS_MAR := 100
```

```gdscript
## Promedia densidad_peces_en()/densidad_algas_en() (GeneradorMundo, duck
## typing) muestreadas cada PASO_MUESTREO_PESCA_FRUTOS_MAR celdas dentro del
## círculo de radio RADIO_AREA_PESCA_FRUTOS_MAR centrado en centro_xz (el
## punto medio del extremo de agua, no el centro de la huella — ver
## CamaraCenital.gd). A diferencia de detectar_fauna_frutal()/
## detectar_arbol(), las columnas que NO son agua se OMITEN por completo
## (ni cuentan como muestra) en vez de contribuir con 0.0 — este puesto
## siempre tiene tierra firme cerca de su origen por diseño, así que
## incluirla en el promedio lo castigaría sistemáticamente. Devuelve ambas
## claves en 0.0 si no hubo ninguna muestra de agua (evita dividir por cero).
func detectar_pesca_frutos_mar(generador: Object, centro_xz: Vector2i) -> Dictionary:
	var suma_peces := 0.0
	var suma_algas := 0.0
	var muestras := 0
	for dx in range(-RADIO_AREA_PESCA_FRUTOS_MAR, RADIO_AREA_PESCA_FRUTOS_MAR + 1, PASO_MUESTREO_PESCA_FRUTOS_MAR):
		for dz in range(-RADIO_AREA_PESCA_FRUTOS_MAR, RADIO_AREA_PESCA_FRUTOS_MAR + 1, PASO_MUESTREO_PESCA_FRUTOS_MAR):
			if Vector2(dx, dz).length() > RADIO_AREA_PESCA_FRUTOS_MAR:
				continue
			var x: int = centro_xz.x + dx
			var z: int = centro_xz.y + dz
			if not generador.es_agua_o_rio_en(x, z):
				continue
			suma_peces += generador.densidad_peces_en(x, z)
			suma_algas += generador.densidad_algas_en(x, z)
			muestras += 1
	if muestras == 0:
		return {"peces": 0.0, "algas": 0.0}
	return {"peces": suma_peces / muestras, "algas": suma_algas / muestras}


## Dos tasas independientes ("pesca"/"frutos_mar"), cada una promedio_señal *
## TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO — mismo patrón que
## tasas_caza_recoleccion(), no se suman en un total.
func tasas_pesca_frutos_mar(promedios: Dictionary) -> Dictionary:
	return {
		"pesca": promedios["peces"] * TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO,
		"frutos_mar": promedios["algas"] * TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO,
	}
```

## 3. `CamaraCenital.gd` — validación de extremos, radio solo-agua y confirmación con pilotes

### 3.1 Nueva validación de colocación (reemplaza `_huella_tiene_columna_en_tierra` solo para este tipo)

```gdscript
## true si las "ancho" celdas de la fila "dz" (relativa a "esquina") son
## TODAS agua, false si son TODAS tierra firme, "" (cadena vacía) si están
## mezcladas — usa el bloque REAL actual (mundo.obtener_tipo()), mismo
## criterio que _huella_tiene_columna_en_tierra(), no el ruido del
## generador (el agua puede haber sido drenada por una construcción vecina).
func _fila_uniforme_en(esquina: Vector2i, ancho: int, dz: int) -> String:
	var vistos_agua := 0
	for dx in range(ancho):
		var x: int = esquina.x + dx
		var z: int = esquina.y + dz
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) == "agua":
			vistos_agua += 1
	if vistos_agua == ancho:
		return "agua"
	if vistos_agua == 0:
		return "tierra"
	return ""


## true si las (ancho + 4) celdas que rodean por fuera el extremo de agua
## (fila "fila_agua", "df" = dirección hacia afuera de la huella: -1 si
## fila_agua = 0, +1 si fila_agua = alto - 1) son todas agua: las 2 celdas
## de flanco (a la misma fila que el extremo, una a cada lado) más toda la
## fila inmediatamente al frente, extendida un bloque más allá de cada
## flanco. Exige que el extremo no sea un charco angosto que termine justo
## en el borde de la huella — ver "Periferia del extremo de agua" en las
## decisiones de alcance.
func _periferia_extremo_es_agua(esquina: Vector2i, ancho: int, fila_agua: int, df: int) -> bool:
	var fila_frente := fila_agua + df
	for dx in range(-1, ancho + 1):
		var x: int = esquina.x + dx
		var z: int = esquina.y + fila_frente
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
			return false
	for dx in [-1, ancho]:
		var x: int = esquina.x + dx
		var z: int = esquina.y + fila_agua
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
			return false
	return true


## Regla de colocación exclusiva de "pesca_frutos_mar": exactamente uno de
## los dos extremos de "ancho" celdas (dz=0 y dz=alto-1) debe ser
## completamente agua (fila Y periferia — ver _periferia_extremo_es_agua())
## y el opuesto completamente tierra firme. Devuelve el dz del extremo de
## agua (0 o alto-1) si la huella es válida, o -1 si no lo es (ambos
## extremos iguales, cualquiera mezclado, o la periferia del extremo de
## agua no está despejada).
func _extremo_agua_de_huella_pesca(esquina: Vector2i, ancho: int, alto: int) -> int:
	var fila_a := _fila_uniforme_en(esquina, ancho, 0)
	var fila_b := _fila_uniforme_en(esquina, ancho, alto - 1)
	if fila_a == "agua" and fila_b == "tierra" and _periferia_extremo_es_agua(esquina, ancho, 0, -1):
		return 0
	if fila_b == "agua" and fila_a == "tierra" and _periferia_extremo_es_agua(esquina, ancho, alto - 1, 1):
		return alto - 1
	return -1
```

### 3.2 `_actualizar_previsualizacion_puesto()` — rama nueva + validez condicional por tipo

Reemplaza la línea única `and _huella_tiene_columna_en_tierra(esquina, columnas)` por una
rama condicional (el resto de la función no cambia):

```gdscript
var huella_anclada: bool
var extremo_agua_dz := -1
if _tipo_puesto_activo == "pesca_frutos_mar":
	extremo_agua_dz = _extremo_agua_de_huella_pesca(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	huella_anclada = extremo_agua_dz != -1
else:
	huella_anclada = _huella_tiene_columna_en_tierra(esquina, columnas)
var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
		and not _huella_choca_con_otro_puesto(esquina, columnas) \
		and huella_anclada
```

Y una rama nueva en el `if/elif` de ficha/radio (se inserta entre la de
`"caza_recoleccion"` y el `else` de maderero, que queda sin cambios):

```gdscript
elif _tipo_puesto_activo == "pesca_frutos_mar":
	if extremo_agua_dz != -1:
		@warning_ignore("integer_division")
		var centro_agua := Vector2i(esquina.x + _ancho_puesto_activo / 2, esquina.y + extremo_agua_dz)
		var promedios: Dictionary = Recoleccion.detectar_pesca_frutos_mar(mundo.generador, centro_agua)
		var tasas_pesca: Dictionary = Recoleccion.tasas_pesca_frutos_mar(promedios)
		hud.actualizar_tasas_pesca(tasas_pesca)
		_actualizar_area_accion_agua(centro_agua, Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)
	else:
		hud.actualizar_tasas_pesca({})
		_ocultar_area_accion()
```

### 3.3 `_actualizar_area_accion_agua()` — variante que omite columnas de tierra

Nueva función, hermana de `_actualizar_area_accion()` (que no se modifica —
sigue sirviendo a mina/caza/madero sin cambios):

```gdscript
## Igual que _actualizar_area_accion(), pero además de filtrar por radio,
## oculta cualquier plano cuya columna real no sea agua (mundo.generador.
## es_agua_o_rio_en()) — exclusivo de "pesca_frutos_mar": el radio de este
## puesto nunca se dibuja ni se cuenta sobre tierra firme (ver decisiones de
## alcance). Reutiliza el mismo pool _area_accion/_offsets_area_accion.
func _actualizar_area_accion_agua(centro: Vector2i, radio: int) -> void:
	for i in range(_offsets_area_accion.size()):
		var offset: Vector2i = _offsets_area_accion[i]
		var plano: MeshInstance3D = _area_accion[i]
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		if offset.length() > radio or not mundo.generador.es_agua_o_rio_en(x, z):
			plano.visible = false
			continue
		var altura_celda: int = mundo.altura_en(x, z, true)
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE_AREA_ACCION, z + DESF)
		plano.visible = true
```

**`RADIO_AREA_ACCION_MAX` sube de 12 a 25** (es el único cambio a
`_crear_area_accion()` — el pool pasa de generarse una vez al arrancar la
escena, sin más lógica nueva). Efecto secundario aceptado: el pool de planos
fantasma del círculo de área de acción crece de ~452 a ~1963 nodos
`MeshInstance3D` (todos ocultos hasta que un puesto está en modo
colocación) — mismo patrón de pool precalculado ya usado, solo más grande.
No se espera impacto perceptible (son nodos ocultos, sin colisión ni
lógica), pero se documenta como el costo aceptado de la decisión de radio
25.

### 3.4 Tecla y modo de colocación

```gdscript
elif tecla.pressed and tecla.keycode == KEY_F:
	_alternar_modo_colocar_puesto("pesca_frutos_mar", Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR, Recoleccion.ALTO_HUELLA_PESCA_FRUTOS_MAR)
```

En `_alternar_modo_colocar_puesto()` y `_salir_de_modo_colocar_puesto()`, el
patrón "ocultar todas las fichas, mostrar la del tipo activo" se extiende
con `hud.ocultar_ficha_pesca()`/`hud.mostrar_ficha_pesca()` (mismo patrón
exacto que las otras tres, sin lógica nueva).

### 3.5 `_procesar_clic_puesto()` — validación y confirmación con pilotes

Reemplaza el bloque `if not _huella_tiene_columna_en_tierra(...)` con una
rama condicional (idéntica idea que en la previsualización):

```gdscript
var extremo_agua_dz := -1
if _tipo_puesto_activo == "pesca_frutos_mar":
	extremo_agua_dz = _extremo_agua_de_huella_pesca(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	if extremo_agua_dz == -1:
		print("Colocación rechazada: la huella necesita un extremo completo sobre agua y el opuesto completo sobre tierra firme.")
		return
elif not _huella_tiene_columna_en_tierra(esquina, columnas):
	print("Colocación rechazada: la huella necesita al menos una columna sobre tierra firme.")
	return
```

Y reemplaza el bloque de drenaje + relleno (líneas del `total_drenado`/
`relleno` actuales) con una rama condicional — la rama `else` es el código
ya existente, sin cambios:

```gdscript
var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
var total_relleno := 0
var total_pilotes := 0
if _tipo_puesto_activo == "pesca_frutos_mar":
	var esquinas_pilote: Array[Vector2i] = [
		Vector2i(esquina.x, esquina.y + extremo_agua_dz),
		Vector2i(esquina.x + _ancho_puesto_activo - 1, esquina.y + extremo_agua_dz),
	]
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			var x: int = esquina.x + dx
			var z: int = esquina.y + dz
			var xz := Vector2i(x, z)
			var es_pilote: bool = esquinas_pilote.has(xz)
			var es_agua_real: bool = mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) == "agua"
			if es_agua_real and not es_pilote:
				continue  # agua abierta bajo la plataforma: no se toca
			var fondo: int = mundo.altura_en(x, z, true)
			var bloque: String = "pared" if es_pilote else "tierra"
			for h in range(fondo + 1, objetivo + 1):
				mundo.colocar_bloque(Vector3i(x, h, z), bloque)
				total_relleno += 1
				if es_pilote:
					total_pilotes += 1
else:
	# Código existente sin cambios: drenar_agua() + calcular_relleno() con "tierra" para toda la huella.
	...
if total_pilotes > 0:
	print("Pilotes colocados bajo el puesto: ", total_pilotes, " bloques de \"pared\".")
if total_relleno > 0:
	print("Terreno nivelado bajo el puesto: ", total_relleno, " bloques usados.")
```

Nota de implementación: `colocar_bloque()` reemplaza tanto celdas vacías
como celdas de `"agua"` (ver su guarda `tipo_anterior != "agua"` en
`VoxelWorld.gd`), así que el bucle `for h in range(fondo + 1, objetivo + 1)`
no necesita llamar `drenar_agua()` por separado en las columnas de pilote —
sustituye cualquier `"agua"` que encuentre a su paso directamente por
`"pared"` en un solo bucle, y sigue rellenando con `"pared"` el resto hasta
`objetivo` sin más pasos.

**Bloque marcador:** el bucle final que coloca `bloque_marcador` en toda la
huella a `objetivo + 1` **no cambia** — se extiende el `if/elif` existente
(`"mina"`/`"caza_recoleccion"`/`else` maderero) con
`elif _tipo_puesto_activo == "pesca_frutos_mar": bloque_marcador = "puesto_pesca"`.
El piso marcador de una celda de alto queda así elevado sobre el agua
abierta entre los 2 pilotes, como la cubierta de un muelle.

## 4. `MeshLibrary` — bloque nuevo `"puesto_pesca"`

Mismo patrón placeholder que `"puesto_caza"`/`"puesto_madero"` en
`BlockLibrarySource.tscn` (`BoxMesh` + `BoxShape3D` + `StandardMaterial3D`
de color plano) — color propuesto `Color(0.1, 0.5, 0.55, 1)` (verde-azulado,
evoca agua/muelle). Regenerar `BlockLibrary.res` tras el cambio.

## 5. HUD (`HUD.gd`)

Nueva ficha `PescaFicha`, mismo patrón `VBoxContainer` + labels que
`MaderoFicha`: costo/personal/almacenamiento fijos (las constantes nuevas de
la Sección 2) y dos líneas de tasa ("X comida/h por pesca", "Y comida/h por
frutos del mar"), recalculadas en vivo.

```gdscript
func mostrar_ficha_pesca() -> void
func actualizar_tasas_pesca(tasas: Dictionary) -> void
func ocultar_ficha_pesca() -> void
```

## 6. Pruebas

- **`GeneradorMundoTest.gd`:** nuevo test de `densidad_peces_en()`
  (determinista, en `[0, 1]`, `0.0` fuera de agua — mismo patrón que el test
  de `densidad_arbol_en()`); nuevo test de `densidad_algas_en()` con una
  columna de río sintética (profundidad conocida vía un generador de altura
  falso determinista, mismo patrón que `NiveladorTerrenoTest.gd`) y una
  columna de mar/lago sintética, verificando que ambas usan su propio techo
  de normalización (una columna de río a profundidad máxima da la misma
  señal de algas que una de mar a su propia profundidad máxima, pese a que
  las profundidades absolutas sean muy distintas); caso borde fuera de agua
  (`0.0` en ambas).
- **`RecoleccionTest.gd`:** `detectar_pesca_frutos_mar()` con un generador
  falso determinista (celdas de agua y tierra fijas conocidas) verificando
  que las columnas de tierra dentro del radio se omiten del promedio (no
  cuentan como `0.0`) — caso que distingue esta función de
  `detectar_fauna_frutal()`; `tasas_pesca_frutos_mar()` con promedios
  conocidos verifica la multiplicación exacta por la tasa base.
- **`_extremo_agua_de_huella_pesca()`/`_fila_uniforme_en()` (`CamaraCenital.gd`):
  sin prueba automatizada nueva** — no existe hoy ningún `CamaraCenitalTest.gd`
  ni prueba unitaria para ninguna de sus validaciones equivalentes ya
  existentes (`_huella_tiene_columna_en_tierra()`, `_huella_choca_con_otro_puesto()`,
  etc. — todas dependen de un `VoxelWorld` real y solo se verifican jugando
  en vivo o cargando `Main.tscn`); esta función nueva sigue el mismo
  precedente, verificada en el siguiente punto.
- **Verificación manual en el editor** (mismo patrón que el resto de esta
  PoC): colocar un puesto de pesca junto a la costa del mar y junto a un
  río, confirmar visualmente que la huella solo se pone verde con un
  extremo real sobre agua y el opuesto sobre tierra, que un extremo de agua
  demasiado angosto (p. ej. justo en la entrada de una cala estrecha, con
  tierra pegada a alguno de los 3 lados expuestos) se rechaza pese a que
  las 3 celdas del extremo sean agua, que el círculo de área de acción (25
  celdas) no se dibuja sobre tierra, que al confirmar solo las 2 esquinas
  del extremo de agua quedan como pilotes sólidos y el resto del agua bajo
  la plataforma sigue siendo agua real, y que `Ctrl`+rueda rota la huella
  (3×5 no es cuadrada).

## Fuera de alcance (explícito)

- Material del pilote variable por era de construcción (madera/piedra/
  piedra+hierro) — el usuario ya lo anticipó como dirección futura; por
  ahora siempre es `"pared"`.
- NPCs acuáticos (peces) y bloques reales de algas/frutos del mar — las dos
  señales son placeholders puros, sin efecto de bloque ni de jugabilidad
  todavía, mismo alcance reducido que fauna/frutal/árbol en 3.11.
- Producción real por tick, inventario de recursos, cobro del costo de
  construcción, niveles 2/3 — mismo alcance reducido que los otros tres
  puestos.
- Que el piso marcador de la plataforma tenga soporte visual/físico más
  allá de las 2 esquinas de pilote (una plataforma real necesitaría vigas
  intermedias) — aceptado como abstracción de PoC, igual que los demás
  puestos son un simple "piso de bloques" de una celda de alto.
- Validar que el extremo de agua no quede en un cuerpo de agua demasiado
  pequeño o angosto para que el radio de 25 tenga sentido — no hay mínimo
  de agua contigua exigido, solo que el extremo esté completo.
- Que la rotación (`Ctrl`+rueda) determine cuál de los dos extremos queda
  "al frente" (mirando a una dirección cardinal específica) — hoy sigue sin
  importar si el extremo de tierra queda al norte, sur, este u oeste,
  siempre que exista un extremo completo de agua y el opuesto completo de
  tierra en cualquiera de los dos ejes del mundo. Cuando este puesto pase a
  ser un edificio jugable con puertas de entrega de recursos en su extremo
  de tierra, esa orientación específica sí importará y requerirá una pasada
  de diseño propia (el usuario ya lo anticipó).

**Actualización posterior — corrección de rotación este-oeste:** la primera
versión de esta huella (ver más arriba) solo validaba el eje Z (`dz=0`/
`dz=alto-1`) como extremo, así que rotar con `Ctrl`+rueda cambiaba las
proporciones de la huella (3×5 ↔ 5×3) pero seguía revisando filas de 5
celdas en vez de columnas de 3 — la colocación este-oeste era imposible
(reportado por el usuario jugando en vivo, con captura). Corregido
generalizando `_fila_uniforme_en()`/`_periferia_extremo_es_agua()`/
`_extremo_agua_de_huella_pesca()` (ahora `_extremo_uniforme_en()`/
`_periferia_extremo_es_agua()`/`_extremo_agua_de_huella_pesca()`, con un
nuevo par `_eje_largo_pesca_es_z()`/`_celdas_extremo_pesca()`) para que el
eje validado como extremo se derive de si `alto > ancho` (eje largo en Z,
sin rotar) o `ancho > alto` (eje largo en X, rotado) — `_extremo_agua_de_huella_pesca()`
devuelve ahora un ÍNDICE de extremo (0 o 1), no una coordenada `dz`, para
que sea válido en ambas orientaciones. El puesto ya puede colocarse mirando
a cualquiera de los 4 puntos cardinales.

## Actualización posterior (2026-09-14) — huella 4×6, plataforma de dos niveles, radio por conectividad real

Redecisión del usuario tras probar la v1 en vivo, con dos motivos: (1) el
radio de acción contaba agua sin conexión real con la estructura (charcos
sueltos dentro del círculo de 25 celdas — ver captura); (2) se adopta
nomenclatura fija para los dos extremos, útil desde ya para cuando este
puesto sea un edificio jugable real: **extremo muelle** (el lado sobre el
agua) y **extremo edificio** (el lado sobre tierra firme, donde en el
futuro irán las puertas de entrega de recursos al sistema de transporte —
no implementado todavía, solo la nomenclatura y la reserva visual de esta
sección).

**Cambios de alcance (reemplazan los valores equivalentes de más arriba):**

- **Huella 4×6** (`ANCHO_HUELLA_PESCA_FRUTOS_MAR = 4`, `ALTO_HUELLA_PESCA_FRUTOS_MAR = 6`,
  antes 3×5). Los extremos ahora son los lados de **4** celdas (antes 3). La
  regla de validación (un extremo completo de agua + periferia de
  `ancho_extremo + 4` celdas despejada, el opuesto completo de tierra) NO
  cambia de lógica — ya estaba generalizada a cualquier `ancho`/`alto` por
  la corrección de rotación de más arriba, así que solo cambian las
  constantes; `_eje_largo_pesca_es_z()`/`_celdas_extremo_pesca()`/
  `_extremo_uniforme_en()`/`_periferia_extremo_es_agua()`/
  `_extremo_agua_de_huella_pesca()` siguen sin tocarse.
- **`MAX_ANCHO_HUELLA_PUESTO`/`MAX_ALTO_HUELLA_PUESTO` suben de 5 a 6**
  (`CamaraCenital.gd`) — el pool fijo de planos fantasma de la huella
  (`_crear_huella_puesto()`) se dimensiona por el mayor rectángulo que
  cualquier puesto pueda necesitar; 4×6 (o 6×4 rotado) ya no cabe en el
  límite anterior de 5×5. El pool pasa de 25 a 36 planos — mismo patrón de
  pool sobre-dimensionado y filtrado en vivo ya usado, solo más grande.
- **Radio de acción por conectividad real, no por círculo simple (corrige
  el bug de la captura):** nueva `Recoleccion.celdas_agua_conectadas(generador, centro_xz, radio) -> Dictionary`
  (`Vector2i -> true`) — flood-fill acotado: parte de `centro_xz` (debe ser
  agua) y se expande por adyacencia real de 4 direcciones SOLO a través de
  columnas `generador.es_agua_o_rio_en()`, sin nunca salir del círculo de
  radio `radio` (mismo `RADIO_AREA_PESCA_FRUTOS_MAR = 25` de antes — ver
  Decisión confirmada: "mismo radio de 25 como tope"). Un charco
  desconectado dentro del círculo pero sin camino de agua continuo hasta la
  estructura ya NO cuenta, a diferencia del escaneo circular anterior.
  - `detectar_pesca_frutos_mar(generador, celdas_agua: Dictionary) -> Dictionary`
    cambia de firma: ya NO recibe `centro_xz` y escanea un círculo por su
    cuenta — recibe directamente el `Dictionary` de `celdas_agua_conectadas()`
    y promedia `densidad_peces_en()`/`densidad_algas_en()` sobre exactamente
    esas celdas, sin muestreo por pasos (se elimina
    `PASO_MUESTREO_PESCA_FRUTOS_MAR`: como el conjunto ya es agua real
    conectada, casi siempre mucho más chico que el círculo completo, visitar
    cada celda es barato).
  - `CamaraCenital._actualizar_area_accion_agua()` cambia de firma —
    ya NO recibe `radio` y filtra por `es_agua_o_rio_en()` por su cuenta;
    recibe el mismo `Dictionary` de `celdas_agua_conectadas()` y solo
    muestra un plano si su celda absoluta está en ese conjunto. El punto
    clave: el círculo visual y las señales de peces/algas ahora consumen
    **el mismo cálculo de conectividad**, calculado una sola vez por
    fotograma en `_actualizar_previsualizacion_puesto()` — antes eran dos
    escaneos circulares independientes que casualmente coincidían.
- **Plataforma de dos niveles, sin bloque nuevo:** el piso marcador
  (`"puesto_pesca"`) se coloca en TODA la huella a `objetivo + 1` (igual que
  antes), y además una segunda capa a `objetivo + 2`, mismo bloque, SOLO en
  la mitad de la huella más cercana al extremo edificio (`ancho_extremo × 3`
  celdas — la mitad del eje largo de 6, ya que el extremo edificio es el
  opuesto al índice de `_extremo_agua_de_huella_pesca()`). La mitad hacia el
  extremo muelle queda con 1 solo nivel (como el resto de los puestos). Esto
  diferencia visualmente los dos extremos sin necesitar un asset nuevo en la
  `MeshLibrary`.

### Código de referencia (`Recoleccion.gd`)

```gdscript
const ANCHO_HUELLA_PESCA_FRUTOS_MAR := 4
const ALTO_HUELLA_PESCA_FRUTOS_MAR := 6
# PASO_MUESTREO_PESCA_FRUTOS_MAR eliminada — ya no se usa (ver más arriba).

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
## Devuelve ambas claves en 0.0 si "celdas_agua" está vacío.
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

### Código de referencia (`CamaraCenital.gd`)

```gdscript
const MAX_ANCHO_HUELLA_PUESTO := 6
const MAX_ALTO_HUELLA_PUESTO := 6

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

En `_actualizar_previsualizacion_puesto()`, la rama `elif _tipo_puesto_activo == "pesca_frutos_mar":` calcula `celdas_agua_conectadas()` UNA VEZ y la pasa a ambas llamadas:

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

En `_procesar_clic_puesto()`, tras el bucle existente que coloca `bloque_marcador` en toda la huella a `objetivo + 1` (sin cambios), se agrega la segunda capa de la mitad del extremo edificio:

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

(Este bloque va DESPUÉS de que `celdas_puesto` ya tiene las celdas de la
primera capa y ANTES de `mundo.registrar_edificio(celdas_puesto)`, para que
la segunda capa también quede registrada/inmune al minado.)

### Fuera de alcance (sin cambios respecto a la sección anterior)

Las puertas de entrega de recursos en el extremo edificio, y cualquier
lógica de transporte/logística conectada a ellas, siguen sin implementarse
— esta actualización solo reserva la nomenclatura y la diferencia visual
(plataforma de 2 niveles) para cuando ese trabajo llegue.
