# Destacar Puertas y Ventanas en el Fantasma — Diseño

## Contexto

Al emplazar un blueprint, todas sus celdas pendientes se ven igual: un único
bloque `fantasma` azulado (`Mat_fantasma` en `BlockLibrarySource.tscn`).
Puertas y ventanas se pierden entre el resto de las paredes, y el jugador
las necesita ubicar (la puerta define el nivel de la construcción, ver
`2026-09-20-puertas-a-nivel-de-suelo-design.md`).

Pedido del usuario: que los bloques de puertas y ventanas se noten más en el
"fantasma" del edificio, por ejemplo cambiándoles el color. Dos momentos:

- **Pieza A — previsualización al colocar (tecla `B`)**: ya hecha
  (`CamaraCenital._actualizar_previsualizacion_blueprint()`, commit
  `eeb1bb9`), con `VoxelWorld.COLOR_DESTACADO` como única fuente de colores.
- **Pieza B — fantasmas ya emplazados** (este spec): los bloques azulados
  que se surten con clic derecho.

## Decisión de diseño

`fantasma` es un solo tipo de la MeshLibrary y GridMap no admite material
por celda. Se descartaron: (a) tipos nuevos `fantasma_puerta`/
`fantasma_ventana` (exige reexportar la MeshLibrary, cuyo puente del editor
no funciona en este proyecto, y tocar las ~35 referencias a `"fantasma"` en
`VoxelWorld`); se elige (b) **marcadores superpuestos**: un nodo que dibuja
una caja translúcida de color sobre cada celda de puerta/ventana que siga
siendo `fantasma`. GridMap sigue siendo la única fuente de verdad de
ocupación/colisión; el marcador es solo visual.

## Diseño

### 1. Qué se marca (`VoxelWorld.gd`, lógica pura)

`celdas_fantasma_destacadas() -> Dictionary` (`Vector3i` → tipo): para cada
edificio con `edificio_orden`, las celdas del índice `edificio_progreso[id]`
en adelante (las pendientes) cuyo tipo (`edificio_tipos[id][celda]`) esté en
`COLOR_DESTACADO` **y** que hoy sean `fantasma` en el GridMap. Este último
filtro hace que una puerta enterrada bajo terreno todavía sin cavar (cola de
excavación, ver el spec de puertas a nivel de suelo) no se marque hasta que
se cava. Deconstruir revierte celdas a `fantasma` y baja el progreso, así que
vuelven a aparecer sin caso especial.

### 2. Cuándo se redibuja (`VoxelWorld.gd`)

Nueva señal `fantasmas_cambiados`, emitida en cada punto donde puede cambiar
el resultado de `celdas_fantasma_destacadas()`:

- `iniciar_construccion_fantasma()`, al final.
- `surtir_construccion()`, en cada camino que aplica un paso (rama de
  relleno huérfano, rama del grupo y paso de estructura).
- `procesar_deconstruccion()`, tras revertir una celda.
- `eliminar_edificio()`, al final.

### 3. Dibujo (`FantasmasDestacados.gd`, nodo nuevo)

`Node3D` hijo de `VoxelWorld` en `Main.tscn`, mismo patrón que
`TranslucidosRenderer` (referencia `voxel_world` asignada por
`VoxelWorld._ready()`, que conecta la señal). Al recibir `fantasmas_cambiados`
marca "sucio"; en `_process()` reconstruye una sola vez por fotograma: libera
sus cajas anteriores y crea una `MeshInstance3D` con `BoxMesh` de tamaño
`Vector3.ONE * 1.02` por cada celda de `celdas_fantasma_destacadas()`,
posicionada en `celda + DESF` (`DESF = 0.5`, igual que `TranslucidosRenderer`),
con `StandardMaterial3D` sin sombreado, transparencia alfa y el color de
`VoxelWorld.COLOR_DESTACADO[tipo]`. El 1.02 evita el z-fighting con la cara
del bloque `fantasma`. Son pocas celdas por edificio, así que no hace falta
pool ni `MultiMesh`.

## Pruebas

Automáticas, en `BlueprintValidatorTest.gd` (mundo `VoxelWorld.new()` sin
`_ready()`, como las pruebas existentes):

- `celdas_fantasma_destacadas()` devuelve solo puerta (ambas mitades) y
  ventana pendientes, no paredes ni mobiliario.
- Sale del resultado al surtirse esa celda y vuelve al deconstruir.
- Una puerta bajo terreno aún sin cavar no aparece; sí al cavarse.
- `fantasmas_cambiados` se emite en iniciar, surtir, deconstruir y eliminar
  (contador conectado a la señal).

Manual (el dibujo): emplazar un blueprint y comprobar que las puertas
(magenta) y ventanas (verde lima) se destacan sobre los bloques azules, que el
color desaparece al surtir cada una, que reaparece al deconstruir, y que la
previsualización (Pieza A) usa los mismos colores.

Verificación: `godot/scenes/Test.tscn` (48+ pruebas de `VoxelWorld`) y
arranque de `Main.tscn` sin errores nuevos.

## Documentación

Una línea en el doc técnico de PoC 6, en la subsección "Puertas a nivel de
suelo (2026-09-20)": puertas y ventanas se destacan (color propio) en la
previsualización y en los fantasmas emplazados.

## Fuera de alcance

Cambiar el aspecto del bloque `fantasma` en sí o del resto de tipos, marcar
mobiliario (cama, baúl), y destacar puertas/ventanas ya construidas (reales).

## Riesgos conocidos

- Si un futuro paso de la cola cambia una celda `fantasma` sin pasar por los
  puntos de emisión listados, el marcador queda desactualizado hasta el
  siguiente evento; la prueba de emisión cubre los caminos actuales.
