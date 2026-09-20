# Puertas a Nivel de Suelo — Diseño

## Contexto

Hoy `CamaraCenital._procesar_clic_blueprint()` emplaza el blueprint con su
celda `y=0` (la losa de piso) en `objetivo + 1`, donde `objetivo` es la
altura del punto más alto de la huella (`NiveladorTerreno.altura_objetivo()`).
La puerta (`y=1`) queda entonces en `objetivo + 2`: un bloque por encima del
suelo exterior. La distribución de recursos (Fase 5) exige que la puerta de
un edificio esté a la misma altura que la carretera para considerarse
"conectada" a la red, y la carretera se construirá sobre el suelo natural,
sin agregar bloques.

Pendiente original (`docs/Pendientes y próximos pasos.md`): corregir el
sistema de construcción para que las puertas queden a nivel de suelo,
cavando o elevando el piso bajo la huella según haga falta.

## Reglas pedidas por el usuario

1. Toda construcción tiene una losa sólida de suelo y la puerta se coloca
   sobre ella. El **nivel de referencia** es el suelo delante de la puerta
   (la primera celda de su despeje). La losa se **entierra** un bloque:
   queda a ras de ese suelo.
2. La puerta **nunca** queda con bloques de tierra al frente, ni más alta
   que el bloque sólido que tiene adelante.
3. **Cavar es trabajo pendiente**, igual que el relleno: sigue el patrón
   "siguiente celda pendiente del grupo" de `Construccion.gd`.
4. Al emplazar un blueprint, el HUD muestra los materiales que se
   movilizarían, restando lo recogido al cavar. **Es solo visual**: no
   existe inventario real y no se cobra nada; eso queda para cuando se
   desarrolle el inventario.

## Alcance

Dentro: nivel base por suelo frontal, excavación y relleno con el tope
nuevo, cola de excavación, previsualización coherente, resumen visual de
materiales en el HUD, pruebas, documentación.

Fuera: inventario real, consumo/cobro de materiales, restaurar lo cavado o
rellenado al deconstruir (igual que hoy con el relleno), carreteras, puestos
periféricos (no tienen puertas y conservan su nivelación actual).

## Diseño

### 1. Geometría (`NiveladorTerreno.gd`, lógica pura)

- **`base_y(esquina, celdas_3d, huella_xz, fuente)`**: para cada
  `puerta_inferior` con celda externa de frente `f` (vecino cardinal en XZ
  fuera de la huella, el mismo criterio que `VoxelWorld.calcular_despeje()`),
  `base_y = altura_en(f) + 1 − rel.y_puerta`, siendo `base_y` la Y mundial
  de la celda `rel.y = 0` del blueprint. Devuelve `objetivo + 1` (el
  comportamiento actual) si el blueprint no tiene puerta.
- **Puertas que discrepan:** si dos puertas dan `base_y` distintos se
  rechaza el emplazamiento, con mensaje explícito.
- **Frente inválido:** se rechaza si el bloque superficial del frente es
  agua o cae fuera del mundo. El despeje existente (`verificar_despejes()`)
  sigue rechazando árboles o estructuras en las 2 celdas de frente.
- **Pendiente puerta-frente:** además de `verificar_pendiente()` sobre la
  huella, la columna de cada puerta contra su columna frontal respeta el
  mismo `LIMITE_PENDIENTE = 2`. Evita excavaciones enormes por una puerta
  frente a un desnivel grande.
- **Excavación:** en cada columna de la huella, todo bloque sólido con
  `y ≥ base_y` hasta la superficie (celdas ordenadas de arriba hacia abajo).
- **Relleno:** de `superficie + 1` a `base_y − 1` en columnas más bajas.
  `calcular_relleno()` recibe el tope como parámetro (por defecto
  `altura_objetivo()`, así los puestos no cambian) y se le pasa
  `base_y − 1`.

### 2. Flujo en el mundo (`CamaraCenital.gd`, `VoxelWorld.gd`)

- **Orden:** excavación → relleno → estructura. Excavación y relleno viajan
  en **una sola cola de preparación** de `Construccion.gd` (excavación
  primero, relleno después), con la misma referencia `edificio_relleno_cola`;
  así `iniciar_construccion_fantasma()` no cambia y el orden se cumple solo.
  Las celdas de excavación llevan destino `"aire"`, o `"fantasma"` si además
  son celdas de la estructura.
- **Celdas de estructura sobre terreno:** `colocar_bloque()` rechaza celdas
  ocupadas, así que la losa no puede nacer como fantasma sobre el terreno.
  Al cavarse una celda que coincide con una de la estructura, el paso deja
  ahí un `fantasma` en vez de vacío.
- **Retirar un bloque:** las celdas de estructura ya están en
  `celda_a_edificio` y `minar_bloque()` las rechaza. Se extrae de
  `minar_bloque()` un helper `_retirar_bloque(celda)` (todo lo posterior a
  las guardas: pareja, translucidos, escurrimiento de agua vecina) que
  reutilizan `minar_bloque()` y el paso de excavación.
- **Emplazar y previsualizar** comparten un único helper de `base_y`
  (clic y `_actualizar_previsualizacion_blueprint()`); las cajas fantasma se
  dibujan a la altura real y la previsualización se marca inválida si
  falla cualquiera de las reglas nuevas.
- **Al emplazar**, `base_y` y los conteos se guardan en `metadata` del
  edificio.

### 3. Resumen visual de materiales

- Función pura (mismo módulo que la nivelación) que recibe las celdas del
  blueprint, el relleno y la excavación planificados y devuelve el neto por
  material.
- **Costos por celda:** `pared` 1 piedra; `puerta_inferior`/`puerta_superior`
  1 madera cada una (2 en total); `ventana` 1 tierra; `cama_cabecera`/
  `cama_pies` 2 madera cada una (4 en total); `baul` 6 madera; `piso`
  1 tierra (vía `VoxelWorld.MATERIAL_REAL`); cada bloque de relleno 1 tierra.
- **Recogido:** cada celda excavada aporta su `material_real()` (tierra o
  piedra si se cava profundo).
- **Neto = recogido − necesario.** Necesidades primero, sin signo
  (`79 piedra`, `12 madera`); sobrante con `+` (`+ 19 tierra`); un déficit
  se muestra como necesidad.
- **HUD:** ficha "Materiales de construcción" con el patrón existente
  (`mostrar_ficha_*`/`actualizar_*`/`ocultar_ficha_*` en `HUD.gd`). Aparece
  mientras hay un blueprint activo, se actualiza al mover el cursor y se
  oculta al salir del modo colocar-blueprint.
- **Ejemplo verificado con el usuario:** casa 4×5×5 (losas incluidas) de
  `pared`, 1 puerta, 1 ventana, 1 cama, 1 baúl sobre terreno plano →
  79 piedra, 12 madera, `+ 19 tierra` (excavación 20 − ventana 1).

## Pruebas

En `NiveladorTerrenoTest.tscn` (mismo patrón de fuentes de altura falsas):

- `base_y` con suelo frontal a distinta altura que el punto más alto.
- Rechazo por puertas con `base_y` distintos, frente en agua, y pendiente
  puerta-frente excesiva.
- Excavación y relleno con el tope nuevo (terreno plano: solo excavación;
  ladera: ambos).
- Resumen de materiales con el ejemplo 4×5×5 (79/12/+19).
- Regresión: los puestos siguen usando `altura_objetivo()`.

En `ConstruccionTest.tscn` / pruebas de `VoxelWorld` que ya existan: orden
excavación → relleno → estructura, y celda de estructura sobre terreno que
queda `fantasma` tras cavarse.

Verificación: `godot/scenes/Test.tscn` y las escenas `*Test.tscn`
afectadas, con Godot 4.7.

## Documentación

- GDD §5: nota sobre nivel de puerta y cavar como trabajo pendiente en
  "Nivelación de Terreno".
- Doc técnico de PoC 6: decisión funcional nueva y resumen visual de
  materiales (sin inventario).
- `docs/Pendientes y próximos pasos.md`: tachar el pendiente.

## Riesgos conocidos

- El aplicador de pasos (`_aplicar_paso_cola()`) es común a la rama de
  relleno huérfano y a la de grupo de `surtir_construccion()`.
- Blueprints con la losa a más de un bloque bajo la puerta (sótanos)
  implican `base_y` más profundo: la excavación sigue la misma regla y no
  requiere caso especial, pero conviene una prueba.
