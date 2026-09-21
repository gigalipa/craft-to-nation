# Economía de Puestos: producción y acarreo (sub-proyecto 2A) — Diseño

**Alcance:** rebanada **2A** del sub-proyecto 2 ("núcleo de economía") de la
lógica de recursos (ver `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`,
tabla de sub-proyectos y "Decisiones globales ya tomadas"). Convierte los
cuatro puestos de recolección existentes —hoy solo marcadores— en fuentes
reales de recursos: el jugador asigna colonos a un puesto, los recolectores
producen en su almacén local, los acarreadores caminan cargando hasta el
núcleo urbano y el stock central de la ciudad crece. Incluye la comida, así
que por primera vez la ciudad puede sostenerse sola.

**Repo:** `C:\Users\peraz\Projects\Misc\CityCraft`, proyecto Godot 4.7 en `godot/`.

## Contexto y rebanadas

El sub-proyecto 2 se divide en tres rebanadas, cada una con su spec, plan e
implementación:

| Rebanada | Contenido | Estado |
|---|---|---|
| **2A** | Producción y acarreo de los 4 puestos existentes, stock central multi-recurso, panel de trabajadores y control de recursos | **Este spec** |
| 2B | Extracción física y agotamiento: los colonos retiran bloques reales (minas, canteras), talan árboles caminando, la comida se recalcula según el entorno, el bosque puede agotarse | Futuro |
| 2C | Transformación: aserradero, carbonera, siderúrgica, refinería de tierras raras (recetas de `CadenaMinerales`), luego fluidos y energía | Futuro |

Estado de partida (verificado en el código): `Recoleccion.puestos` guarda
`esquina -> {tipo, ancho, alto, nivel}`, sin trabajadores ni almacén; también
registra ahí los edificios terminados con `tipo = "blueprint"`. Las funciones
de detección (`detectar_recursos`, `tasas_recoleccion`,
`tasas_caza_recoleccion`, `tasa_maderero`, `detectar_pesca_frutos_mar`...)
existen pero usan una tasa genérica de 2.0. `Ciudad.almacen` solo tiene
madera, comida y hierro, y solo se consume.

## Decisiones confirmadas con el usuario (2026-09-21)

- **Asignación manual** desde la cenital: el jugador reparte colonos entre
  recolección y acarreo de cada puesto. Un puesto nuevo empieza con 0
  trabajadores.
- **Los colonos se mueven físicamente:** los recolectores caminan al puesto y
  producen solo mientras están presentes; los acarreadores caminan entre el
  puesto y el núcleo cargando recursos.
- **Se abre el panel con clic izquierdo sobre un puesto cuando no hay una
  herramienta activa.** Hoy cualquier clic izquierdo en la cenital inicia un
  rectángulo de zona (siempre hay una zona seleccionada), así que la regla es:
  clic sobre la huella de un puesto de los 4 tipos **sin un rectángulo de zona
  a medias** abre el panel; en cualquier otro caso funciona como hoy.
- **Enfoque A:** autoload nuevo `Economia.gd` (lógica pura, mismo patrón que
  `Ciudad`/`Zonificacion`/`Recoleccion`); `Colonos` solo ejecuta movimiento.
- **Tasas del Excel** (`docs/Recursos.xlsx`) por recurso, repartidas según la
  composición del área (decisión ya tomada en el spec del 2026-09-20).

## Alcance

**Entra:** los 4 puestos (mina, caza/recolección, maderero, pesca/frutos del
mar); recursos tierra, piedra, hierro, cobre, carbón, tierras raras, madera y
comida; stock central de 8 recursos; asignación, producción, almacén local,
acarreo a pie, panel del puesto y lista de control de recursos en el HUD.

**No entra:** retirar bloques o árboles reales y agotar recursos (2B);
refinerías, agua, petróleo, energía y combustible (2C y posteriores); costo de
construcción de los puestos y obreros NPC que construyen (sub-proyecto 3);
almacenes dedicados y carreteras (sub-proyecto 6); representación visual de la
carga (`ponytail:`, ver Sección 3).

## Sección 1 — Modelo

- **Trabajadores.** Asignar un colono a un puesto lo convierte de
  `desempleado` en `obrero` (su consumo de comida pasa de 3 a 5 por hora);
  liberarlo lo devuelve a `desempleado`. Cupo por puesto: el `PERSONAL_MAXIMO*` que
  ya define `Recoleccion` para cada tipo (hoy 3, ya mostrado en las fichas),
  compartido entre recolectores y acarreadores.
- **Roles.** *Recolector:* produce mientras está presente en el puesto.
  *Acarreador:* lleva del almacén local del puesto al núcleo urbano, que es el
  único almacén central.
- **Stock central.** `Ciudad.almacen` pasa a tener los ocho recursos
  (`madera`, `comida`, `hierro` como hoy y `tierra`, `piedra`, `cobre`,
  `carbon`, `tierras_raras` nuevos, con cantidad inicial 0). Límite
  placeholder de 1000 por recurso, salvo comida (2000).
- **Un puesto nuevo no produce nada** hasta que haya recolectores presentes.
  Sin acarreadores, el almacén local se llena y la producción se detiene: esa
  es la señal al jugador de que necesita más acarreo.

## Sección 2 — `Economia.gd` (autoload, lógica pura)

Estado por puesto, indexado por la esquina de su huella (igual que
`Recoleccion.puestos`): `{"tipo": String, "recolectores": Array[int],
"acarreadores": Array[int], "presentes": Dictionary (id -> true), "almacen":
Dictionary (recurso -> float), "tasas": Dictionary (recurso -> unidades por
recolector y hora)}`.

Constantes: cupo y almacén local se leen de `Recoleccion`
(`PERSONAL_MAXIMO*` y `CAPACIDAD_ALMACENAMIENTO*`, hoy 3 y 100 en los cuatro
tipos; el almacén cuenta el total entre recursos). Solo `CAPACIDAD_CARGA :=
20` es nueva (placeholder).

**Tasas** (por recolector y hora; se guardan en el puesto al colocarlo con las
funciones de detección de `Recoleccion`, que dejan de usar el 2.0 genérico y
pasan a leer `Recoleccion.TASAS_BASE`):

| Puesto | Recurso | Tasa base | Se multiplica por |
|---|---|---|---|
| Mina | hierro, piedra, cobre, carbón, tierras raras | 5 | fracción de ese mineral en el área |
| Mina | tierra | 1 | fracción de tierra en el área |
| Maderero | madera | 5 | densidad de árboles |
| Caza/recolección | comida (caza) | 15 | densidad de fauna |
| Caza/recolección | comida (frutos) | 5 (**cifra propuesta: el Excel no la trae**) | densidad frutal |
| Pesca/frutos del mar | comida (pesca) | 5 | densidad de peces |
| Pesca/frutos del mar | comida (algas) | 1 | densidad de algas |

Un recolector de caza/recolección o de pesca produce **ambas** señales a la
vez y se suman en `comida` (supuesto explícito; las funciones actuales las
devuelven por separado, sin sumarlas). Un minero reparte su esfuerzo entre
minerales según la composición del área, como ya se decidió.

**Tick.** `Economia` escucha `Ciudad.tick_simulado` (1 tick = 1 hora de
juego). Para cada puesto, cada recolector presente suma `tasa × 1 h` a su
`almacen`; si el total local supera `CAPACIDAD_ALMACEN_LOCAL`, el exceso se
pierde (la producción se detiene contra el tope).

**Acarreo.**
- `recoger(esquina, capacidad) -> Dictionary` devuelve (y descuenta del
  almacén local) hasta `capacidad` unidades, repartidas en el orden de los
  recursos del almacén, **solo si** el total local ya es ≥ `capacidad` **o**
  el puesto no tiene recolectores presentes y aún hay algo; en otro caso
  devuelve `{}`. Así ningún resto queda atascado y un acarreador no hace
  viajes de una sola unidad.
- `entregar(carga)` suma cada recurso al stock central
  (`Ciudad.almacen[r].agregar(...)`); lo que no cabe se pierde.

**Balance a tener presente.** Un tick son 2 s reales y un colono camina 2,5
celdas/s (5 celdas por hora de juego): un puesto a 40 celdas del núcleo son
8 h de ida, y un acarreador mueve unas 1,25 unidades/h con carga 20, frente a
5–15 unidades/h de un recolector. Harán falta varios acarreadores por
recolector; el coste del transporte da el incentivo para las carreteras y
carretas futuras. La perilla es `CAPACIDAD_CARGA`.

**API pública:**
- `registrar_puesto(esquina, tipo, tasas)` y `quitar_puesto(esquina)` (libera a
  todos sus trabajadores; el almacén local se pierde).
- `asignar(esquina, rol, colono_id) -> bool` (falla si el cupo está lleno) y
  `liberar(colono_id)`.
- `marcar_presente(colono_id, presente: bool)`.
- `trabajadores_de(esquina) -> Dictionary` (`{"recolectores": n, "acarreadores":
  n, "presentes": n}`), `produccion_por_hora(esquina) -> Dictionary`,
  `almacen_local(esquina) -> Dictionary`, `capacidad_libre_de_cupo(esquina) -> int`.
- `recoger(esquina, capacidad)` y `entregar(carga)`.
Dependencias inyectables (`ciudad`) para probar sin escena, como `Colonos`.

## Sección 3 — Los colonos como trabajadores (`Colonos.gd`)

Cada colono gana `"trabajo"` (`{puesto: Vector2i, rol: String}`, vacío si no
trabaja), `"carga"` (`Dictionary`) y `"fase"` (para el ciclo del acarreador).

**Contratar y despedir.** El panel llama a `Colonos.contratar(esquina, rol) ->
bool` y `Colonos.despedir(esquina, rol) -> bool`:
- `contratar` elige el `desempleado` sin trabajo de id menor, llama a
  `Ciudad.reasignar_tipo("desempleado", "obrero")` (método nuevo que mueve el
  contador de `demografia` de forma consistente, para que `reconciliar()` no
  cree ni retire colonos), fija `tipo = "obrero"` y su `trabajo`, y registra la
  asignación con `Economia.asignar`; devuelve `false` si no hay desempleado
  libre o el cupo está lleno.
- `despedir` libera al último colono asignado con ese rol y lo devuelve a
  `desempleado`.
- Si un colono trabajador se retira (hambruna, desahucio), `_retirar` avisa a
  `Economia.liberar` antes de borrarlo.

**Comportamiento.** Un colono con trabajo deja de deambular; la evacuación de
obras conserva su prioridad y la evitación es la misma de siempre.
- *Recolector:* camina hasta una celda transitable junto a la huella de su
  puesto y se queda ahí, avisando `Economia.marcar_presente(id, true)`. Si no
  hay ruta, reintenta cada segundo y no produce mientras tanto.
- *Acarreador,* en ciclo: (1) va al puesto y pide `Economia.recoger`; (2) si
  recibe `{}`, espera ahí un segundo y reintenta; (3) con carga, camina a la
  celda transitable más cercana a la huella del núcleo; (4) entrega
  (`Economia.entregar`) y vuelve al puesto.
- `Zonificacion` gana `huella_del_nucleo()` (hoy solo expone
  `celda_es_del_nucleo`), para calcular la celda de entrega.
- Si el puesto se deconstruye, `Economia.quitar_puesto` libera a sus
  trabajadores (vuelven a `desempleado`, dejan de trabajar y reanudan el
  deambular).
- `ponytail:` la carga no tiene representación visual (un color o icono sobre
  el colono); añadirla cuando el arte lo pida.
- Las dependencias (`economia`) son inyectables como `ciudad`/`zona`, para
  probar sin escena con una `Economia` falsa.

## Sección 4 — Panel del puesto y control de recursos

**Abrir el panel.** En `CamaraCenital._procesar_clic`: si no hay rectángulo de
zona a medias (`not esperando_segunda_esquina`) y la celda cae en la huella de
un puesto de los 4 tipos (`Recoleccion.esquina_de_puesto_en(celda)`, método
nuevo; los edificios de tipo `"blueprint"` no abren nada), se abre el panel; si
no, el clic funciona como hoy. El panel se cierra al hacer clic fuera de un
puesto (que además empieza un rectángulo de zona como hoy).

**Panel** (nodo nuevo en `HUDLayer`, mismo estilo que las fichas):
título con el tipo de puesto; `Recolectores [-] n [+]` y `Acarreadores [-] n
[+]` (el total no pasa del cupo; `[+]` se desactiva sin desempleados libres);
desempleados libres; almacén local (total y por recurso); producción actual
en unidades/hora; distancia al núcleo en celdas. Se actualiza cada fotograma.

**Registrar y quitar puestos.** `CamaraCenital`, al colocar un puesto, llama a
`Economia.registrar_puesto(esquina, tipo, tasas)` con las tasas que ya calcula
para su ficha. `Player.gd`, al eliminar un edificio, llama a
`Economia.quitar_puesto` junto a `Recoleccion.quitar_puesto`.

**Control de recursos.** Lista permanente en el HUD con los 8 recursos:
cantidad, límite y tasa por tick; reemplaza las dos líneas separadas de comida
y "recurso crítico". `Ciudad.tasa_neta` pasa a medirse **entre finales de tick
consecutivos** (no dentro de `simular_tick`), para incluir lo que entregan los
acarreadores entre ticks; el primer tick compara contra la cantidad inicial,
así que el comportamiento observable de las pruebas actuales no cambia.

## Sección 5 — Pruebas, verificación, documentación y plan

**Pruebas nuevas o ampliadas (escenas `*Test.tscn`):**
- `EconomiaTest` (nueva, lógica pura, con una `Ciudad` falsa): registrar y
  quitar puesto; producción solo con recolectores presentes; tope de 100 y
  pérdida del exceso; cupo de 3 (asignar falla al llenarse); `liberar` y
  `quitar_puesto`; `recoger` (con carga completa, sin recolectores presentes,
  con almacén vacío, y que no descuenta de más); `entregar` con stock casi
  lleno; caza+frutos suman en comida.
- `RecoleccionTest`: las tasas nuevas del Excel; `esquina_de_puesto_en`.
- `CiudadTest`: `almacen` con 8 recursos; `reasignar_tipo`; `tasa_neta` entre
  finales de tick incluye entregas hechas entre ticks.
- `ZonificacionTest`: `huella_del_nucleo()`.
- `ColonosTest`: `contratar`/`despedir` (tipo, `demografia` consistente,
  cupo); un recolector camina, queda presente y `Economia` lo cuenta; un
  acarreador completa un ciclo con una `Economia` falsa; retirar un colono
  trabajador lo libera; la evacuación de obras sigue teniendo prioridad sobre
  el trabajo.
- Ejecución obligatoria (CLAUDE.md): `godot/scenes/Test.tscn` más todas las
  escenas afectadas.

**Verificación manual (no automatizable):** clic en un puesto abre el panel y
no rompe el pintado de zonas; asignar recolectores y acarreadores los pone a
caminar y trabajar; el stock central de comida sube y la ciudad sostiene a sus
colonos; el panel refleja almacén local y producción; deconstruir un puesto
devuelve a sus trabajadores.

**Documentación:** GDD (Secciones 3, 4 y 6: producción y acarreo, versión
3.34) y un documento técnico nuevo `PoC_5/Documento Técnico ... 2A ...md`
(sin tocar `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de
Recursos y Cadenas de Producción.md`, que tiene trabajo en curso del usuario
sin terminar). `docs/Recursos.xlsx` no se modifica.

**Partición prevista del plan (una sola implementación, tareas
independientes y probables):** (1) `Ciudad`: 8 recursos, `reasignar_tipo`,
`tasa_neta`; (2) `Recoleccion` (tasas del Excel, `esquina_de_puesto_en`) y
`Zonificacion.huella_del_nucleo`; (3) `Economia.gd` + `EconomiaTest`; (4)
`Colonos`: contratar/despedir, recolector, acarreador; (5) integración en
`CamaraCenital`/`Player` (registrar y quitar puestos, clic); (6) panel del
puesto y lista de recursos en el HUD y `Main.tscn`; (7) documentación y
verificación final.

## Supuestos que el usuario puede corregir

- Tasa de recolección de frutos: 5/h (el Excel no la trae).
- Cupo de trabajadores = `PERSONAL_MAXIMO*` existente (3), común a
  recolectores y acarreadores; con 3 casi no cabe la proporción acarreo/
  recolección que pide el balance, así que probablemente conviene subirlo.
- Capacidad de carga de 20 unidades por viaje.
- Un recolector de caza/recolección o de pesca produce las dos señales a la
  vez y se suman en comida.
- La producción se calcula con las tasas tomadas al colocar el puesto (no se
  recalcula mientras no haya agotamiento; eso es la 2B).
