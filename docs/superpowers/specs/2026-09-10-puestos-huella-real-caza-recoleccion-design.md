# Puestos de Recolección con Huella Real + Puesto de Caza/Recolección — Diseño

**Alcance:** PoC 5, sub-proyecto 5 (Fase 3 del roadmap, GDD Sección 11). Extiende
`docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md` en dos direcciones:

1. Los puestos periféricos dejan de representarse con un solo bloque marcador y pasan
   a tener una **huella real** de N×M celdas (construcción completa, no un punto),
   con posibilidad de **rotarla 90°** antes de confirmar.
2. Se agrega un **puesto de caza y recolección** nuevo (GDD Sección 3): un solo
   edificio que cubre caza (fauna) y recolección de plantas (frutal) a la vez —
   decisión explícita del usuario. El puesto de pesca/frutos del mar queda
   **fuera de alcance**, aparte, para más adelante (categoría de moral distinta,
   depende de ríos/lagos con peces, señal que no existe todavía).

El puesto maderero (GDD Sección 3) sigue sin sub-proyecto propio ni modo de
colocación jugable — solo se fija su huella (3×4) para que la convención de
tamaños quede documentada junto a las otras dos.

**Repo:** `C:\Users\peraz\Projects\Misc\CityCraft`, proyecto Godot 4.7 compartido en `godot/`.

## Decisiones de alcance confirmadas con el usuario

- Un solo puesto de "caza y recolección" (no dos edificios separados) — cubre
  `densidad_fauna_en()` y `densidad_frutal_en()` a la vez.
- Huellas: mina 5×5 (ya eran esos los planos de su disco, ahora son la huella real),
  caza/recolección 4×4, maderero 3×4 (documentada, sin puesto jugable).
- Radio de área de acción: el mismo que ya estaba previsto para cada tipo
  (`RADIO_AREA_MINA = 6`, `RADIO_AREA_CAZA_RECOLECCION = 12`, nuevo), medido ahora
  desde el **centro geométrico de la huella**, no desde un punto.
- Rotación genérica (`Ctrl` + rueda del mouse, 90°) implementada ya, aunque no
  tenga efecto visible en mina/caza-recolección (ambas cuadradas) hasta que
  exista el maderero — el usuario prefirió tener el mecanismo listo y probado
  ahora en vez de re-abrirlo después.
- Validación de choques: **sí**, ahora. Una huella se rechaza si choca con
  `"madera"` (tronco de árbol), con un bloque estructural de un edificio del
  jugador, o con la huella de **otro puesto ya colocado** (de cualquier tipo).
  Si choca solo con `"follaje"`, éste se elimina automáticamente al confirmar
  (no invalida) — regla ya escrita en el GDD (Sección 3, "Emplazamiento Dentro
  de un Bosque"), implementada por primera vez aquí.
- Validación de relieve: **sí**, ahora — reutiliza
  `NiveladorTerreno.verificar_pendiente()`, generalizada para aceptar
  `ancho`/`alto` en vez de un tamaño cuadrado fijo.
- Tasa de comida de caza/recolección: promedio de densidad muestreada cada
  `PASO_MUESTREO_CAZA_RECOLECCION = 2` celdas dentro del radio × una tasa base
  por señal — dos líneas independientes en el HUD ("caza" y "recolección"),
  sin sumarlas (igual que la mina no suma sus minerales).
- Sigue sin producción real por tick, sin cobro del costo de construcción y
  sin niveles 2/3 — mismo alcance reducido que la mina original.

## 1. `Recoleccion.gd` — unifica mina y caza/recolección en un solo registro

Hoy `puestos: Dictionary` guarda `Vector2i (celda de superficie) -> {"nivel": int}`
solo para minas. Pasa a guardar **cualquier tipo de puesto**, indexado por la
**esquina** de su huella (celda de menor X/Z), para poder validar choques entre
puestos de cualquier tipo con una sola función:

```gdscript
const RADIO_AREA_MINA := 6
const PROFUNDIDAD_MINA_NIVEL_1 := 8
const TASA_BASE_POR_CIUDADANO := 2.0

const ANCHO_HUELLA_MINA := 5
const ALTO_HUELLA_MINA := 5

const RADIO_AREA_CAZA_RECOLECCION := 12
const PASO_MUESTREO_CAZA_RECOLECCION := 2
const TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO := 2.0
const ANCHO_HUELLA_CAZA_RECOLECCION := 4
const ALTO_HUELLA_CAZA_RECOLECCION := 4

# Documentada, sin puesto jugable todavía (ver GDD Sección 3, puesto maderero).
const ANCHO_HUELLA_MADERERO := 3
const ALTO_HUELLA_MADERERO := 4

var puestos: Dictionary = {}  # Vector2i (esquina) -> {"tipo": String, "ancho": int, "alto": int, "nivel": int}


func colocar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int) -> void:
	puestos[esquina] = {"tipo": tipo, "ancho": ancho, "alto": alto, "nivel": 1}


## true si "celda" cae dentro de la huella (esquina..esquina+ancho-1,
## alto-1) de algún puesto ya colocado, de cualquier tipo — usada por la
## validación de choques al previsualizar una nueva colocación.
func celda_dentro_de_algun_puesto(celda: Vector2i) -> bool:
	for esquina in puestos:
		var datos: Dictionary = puestos[esquina]
		if celda.x >= esquina.x and celda.x < esquina.x + int(datos["ancho"]) \
				and celda.y >= esquina.y and celda.y < esquina.y + int(datos["alto"]):
			return true
	return false


## Cuenta los tipos reales dentro de la semiesfera (radio RADIO_AREA_MINA,
## hacia abajo PROFUNDIDAD_MINA_NIVEL_1) centrada en (centro_xz, altura_superficie)
## — centro_xz es ahora el CENTRO GEOMÉTRICO de la huella, no la esquina.
## Sin cambios de comportamiento respecto a la spec de minas original.
func detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Dictionary:
	... # sin cambios de firma ni de lógica


## Promedia densidad_fauna_en()/densidad_frutal_en() (GeneradorMundo, no
## VoxelWorld — duck typing, mismo patrón que NiveladorTerreno con
## altura_en()) muestreadas cada PASO_MUESTREO_CAZA_RECOLECCION celdas dentro
## del círculo de radio RADIO_AREA_CAZA_RECOLECCION centrado en centro_xz.
## Siempre devuelve ambas claves (0.0 si no hay muestras, p. ej. radio menor
## que el paso) — nunca divide por cero.
func detectar_fauna_frutal(generador: Object, centro_xz: Vector2i) -> Dictionary:
	# {"fauna": promedio, "frutal": promedio}
	...


## A partir de detectar_fauna_frutal(): dos líneas independientes ("caza" y
## "recoleccion"), cada una promedio_señal * TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO.
## No se suman en un total — igual que la mina no suma sus minerales.
func tasas_caza_recoleccion(promedios: Dictionary) -> Dictionary:
	# {"caza": .., "recoleccion": ..}
	...
```

`colocar_mina(celda)` (la función existente) se elimina — su único llamador
(`CamaraCenital._procesar_clic_mina`) pasa a llamar `colocar_puesto(esquina, "mina", ANCHO_HUELLA_MINA, ALTO_HUELLA_MINA)`.
`RecoleccionTest.gd` se actualiza en el mismo sentido (ver Sección 5).

## 2. `VoxelWorld.gd` — validación de huella libre

Nueva función pública, independiente de `Recoleccion` (no conoce puestos, solo
bloques reales — sigue el mismo principio de responsabilidad única que
`altura_en()`/`obtener_tipo()`):

```gdscript
## Revisa cada columna (x, z) de la huella ancho×alto con esquina "esquina":
## si el bloque inmediatamente sobre el terreno real (altura_en(x, z) + 1) es
## "madera", o es un bloque estructural colocado por el jugador
## (colocado_por_jugador.has(...)), la huella completa es inválida. Si es
## "follaje", se acumula en follaje_a_eliminar (no invalida — se borra al
## confirmar). No revisa Recoleccion.puestos: eso lo hace el llamador
## (Recoleccion no es una dependencia de VoxelWorld).
func verificar_huella_libre(esquina: Vector2i, ancho: int, alto: int) -> Dictionary:
	# {"valida": bool, "follaje_a_eliminar": Array[Vector3i]}
	...
```

## 3. `NiveladorTerreno.gd` — generalizar a huellas no cuadradas

`TAMANO_HUELLA` deja de ser el único tamaño posible. `verificar_pendiente()`,
`altura_objetivo()` y `calcular_relleno()` ganan parámetros opcionales
`ancho: int = TAMANO_HUELLA` y `alto: int = TAMANO_HUELLA` — el modo de
nivelación manual (tecla `B`) sigue llamándolas sin argumentos (comportamiento
idéntico, huella cuadrada fija), mientras que la validación de relieve de un
puesto pasa su `ancho`/`alto` real. Sin cambios de comportamiento para el modo
de nivelación existente.

## 4. Colocación en `CamaraCenital.gd`

**Refactor necesario, no opcional:** hoy `modo_colocar_mina` ya duplica casi
entero el patrón de `modo_nivelacion` (disco/huella fantasma, validación,
ficha del HUD, entrar/salir mutuamente excluyente). Agregar un tercer modo
casi idéntico (`modo_colocar_caza_recoleccion`) copiando el bloque otra vez
sería el mismo bug arrastrado tres veces si algo cambia — se unifica en un
solo modo genérico de "colocar puesto", parametrizado por tipo:

```gdscript
## Modo de colocación de puesto periférico (mina o caza/recolección — tecla
## M o H). Reemplaza los antiguos modo_colocar_mina + _disco_mina dedicados.
var modo_colocar_puesto := false
var _tipo_puesto_activo := ""       # "mina" | "caza_recoleccion"
var _ancho_puesto_activo := 0
var _alto_puesto_activo := 0
var _huella_rotada := false          # Ctrl+rueda intercambia ancho/alto
var _huella_puesto: Array[MeshInstance3D] = []   # tamaño máximo (5x5), se muestran solo ancho*alto
```

- Teclas: `M` activa `_entrar_modo_colocar_puesto("mina", ANCHO_HUELLA_MINA, ALTO_HUELLA_MINA)`;
  nueva tecla `H` activa `_entrar_modo_colocar_puesto("caza_recoleccion", ANCHO_HUELLA_CAZA_RECOLECCION, ALTO_HUELLA_CAZA_RECOLECCION)`.
  Mutuamente excluyente con `modo_nivelacion` (mismo patrón ya existente).
- `Ctrl` + rueda del mouse, **solo si `modo_colocar_puesto` está activo**: alterna
  `_huella_rotada` e intercambia ancho/alto activos. Sin `Ctrl`, la rueda sigue
  siendo zoom de cámara (comportamiento existente, sin cambios) — se distingue
  con `Input.is_key_pressed(KEY_CTRL)` en el mismo bloque `MOUSE_BUTTON_WHEEL_UP/DOWN`
  de `_unhandled_input()`.
- Cada fotograma (`_actualizar_previsualizacion_puesto()`, reemplaza a
  `_actualizar_previsualizacion_mina()`): calcula `esquina = celda_bajo_mouse - Vector2i(ancho/2, alto/2)`
  (división entera, mismo criterio que `MITAD_HUELLA` ya usado), corre las 3
  validaciones (`not Zonificacion.dentro_de_influencia(centro)`, `nivelador.verificar_pendiente(esquina, ancho, alto)`,
  `mundo.verificar_huella_libre(esquina, ancho, alto)["valida"]`), pinta cada
  plano de la huella (verde si las 3 pasan, rojo si alguna falla), y si el
  tipo es `"caza_recoleccion"` recalcula la ficha del HUD con
  `Recoleccion.detectar_fauna_frutal()`/`tasas_caza_recoleccion()`; si es
  `"mina"`, sigue usando `detectar_recursos()`/`tasas_recoleccion()` como hoy
  (centro geométrico en vez de esquina).
- Al confirmar clic (`_procesar_clic_puesto()`, reemplaza a `_procesar_clic_mina()`):
  si las 3 validaciones pasan, elimina el follaje detectado
  (`mundo.set_cell_item(c, GridMap.INVALID_CELL_ITEM)` por cada celda de
  `follaje_a_eliminar`), coloca el bloque marcador (`"mina"` o `"puesto_caza"`)
  en cada una de las `ancho*alto` columnas de la huella (a `altura_en(x,z)+1`
  de esa columna, no una altura uniforme — mismo criterio por-celda que
  `ZonaOverlay`), llama `Recoleccion.colocar_puesto(esquina, tipo, ancho, alto)`,
  y sale del modo. Si alguna validación falla, imprime cuál y **permanece**
  en modo colocar-puesto (igual que la mina hoy, a diferencia de la
  nivelación que siempre sale tras un clic).

**Bloque nuevo:** `"puesto_caza"` en la `MeshLibrary`, mismo patrón placeholder
de color plano que `"mina"`.

## 5. HUD (`HUD.gd`)

Nueva ficha `CazaFicha` (nodo hermano de `MinaFicha` en la escena, mismo
patrón de `VBoxContainer` + labels): costo/personal/almacenamiento fijos
(constantes nuevas `COSTO_CONSTRUCCION_CAZA_RECOLECCION`, `PERSONAL_MAXIMO_CAZA_RECOLECCION`,
`CAPACIDAD_ALMACENAMIENTO_CAZA_RECOLECCION` en `Recoleccion.gd` — mismos
valores que la mina por ahora, sin balance real todavía) y dos líneas de tasa
("X comida/h por caza", "Y comida/h por recolección"), recalculadas en vivo.

```gdscript
func mostrar_ficha_caza() -> void
func actualizar_tasas_caza(tasas: Dictionary) -> void
func ocultar_ficha_caza() -> void
```

## 6. Pruebas

- **`RecoleccionTest.gd`:** se actualiza el test existente de `colocar_mina`
  a `colocar_puesto(..., "mina", 5, 5)`; nuevo test de `celda_dentro_de_algun_puesto()`
  (dentro/fuera de la huella, con dos puestos de tipos distintos); nuevo test
  de `detectar_fauna_frutal()` con un generador falso determinista (mismo
  patrón que `NiveladorTerrenoTest.gd`: `densidad_fauna_en`/`densidad_frutal_en`
  fijas conocidas, no ruido real) verificando el promedio exacto y el caso
  borde fuera de bioma (`0.0`/`0.0`); `tasas_caza_recoleccion()` con promedios
  conocidos verifica la multiplicación exacta por cada tasa base.
- **`Test.tscn` (pruebas de `VoxelWorld`):** nuevo test de `verificar_huella_libre()`
  con una huella de prueba que choca con `"madera"` (inválida), con
  `"follaje"` (válida, aparece en `follaje_a_eliminar`), con un bloque
  `colocado_por_jugador` (inválida), y sin nada (válida, lista vacía).
- **`NiveladorTerrenoTest.gd`:** nuevo test con `ancho`/`alto` explícitos
  distintos de `TAMANO_HUELLA` (p. ej. 4×4), y un test que confirma que
  llamar sin argumentos sigue dando el mismo resultado que antes (no rompe
  el modo de nivelación manual).
- **Verificación manual en el editor** (como el resto de esta PoC): colocar
  una mina y un puesto de caza/recolección, confirmar visualmente que ambas
  huellas siguen el relieve, que chocar con un árbol de madera la pone en
  rojo, que el follaje se limpia al confirmar, que `Ctrl`+rueda no cambia
  nada visible (ambas huellas son cuadradas) y que la rueda sin `Ctrl` sigue
  haciendo zoom normal.

## Fuera de alcance (explícito)

- Puesto maderero jugable (solo su huella 3×4 queda documentada).
- Puesto de pesca/frutos del mar (categoría de moral aparte, depende de una
  señal de peces/ríos que no existe).
- Niveles 2/3 de mina, producción real por tick, inventario de recursos,
  cobro del costo de construcción — mismo alcance reducido que la spec de
  minas original.
- Que el follaje eliminado o la validación de huella libre generen ningún
  recurso o notificación adicional más allá de lo ya descrito.
- Área de acción ovalada del maderero (solo tiene sentido cuando el maderero
  exista como puesto jugable).
