# Declaración de edificios por volumen interno — diseño

Punto 3 de `docs/Pendientes y próximos pasos.md`. Fecha: 2026-09-28.

## Objetivo

Que `BlueprintValidator` reconozca cualquier edificio residencial cuyo volumen interior esté realmente sellado, sin asumir que la huella (contorno en planta) es constante en toda la altura del edificio. Hoy no lo hace: un edificio de dos niveles con techo a dos aguas (más angosto que las paredes, ver captura de referencia en `arte/dae/casa_pared_piedra_2pisos.dae`) no se reconoce, porque el algoritmo actual exige que la losa superior cubra el 100 % de la huella de TODO el edificio (`huella_real`, la unión 2D de todas las capas), no solo la suya propia.

De paso, se completa el checklist de "casa aprobable" que el usuario definió en esta sesión (ver Decisiones del usuario). La mayoría de esas reglas ya existen en otro punto del flujo (colocación, no declaración); este documento identifica cuáles y agrega solo las que faltan.

## Decisiones del usuario

- Alcance: cambia CÓMO se detecta la forma (volumen interno real vía flood-fill), no los límites de balance (`Ciudad.NIVELES_VIVIENDA`, camas por piso / pisos por nivel de ciudad se mantienen igual).
- El checklist completo de "casa aprobable" (12 reglas, ver abajo) se resuelve en esta misma iteración, no se recorta a solo el volumen.
- El caso real que rompía la detección: el techo (última losa) tiene una huella más angosta que las paredes de abajo (retranqueo tipo dos-aguas), NO una diferencia de huella entre piso 1 y piso 2 (esos comparten huella, con un hueco de escalera en la losa intermedia — caso ya cubierto por el algoritmo actual, TEST 12).
- La regla "espacio libre detrás de la puerta" aplica a **toda puerta**, externa o interna (entre dos habitaciones).
- La verificación por pathfinding exige que cada cama y cada baúl sea alcanzable desde **al menos una** puerta externa (no hace falta que cada puerta externa por separado llegue a todo). El pathfinder debe atravesar cualquier puerta (externa o interna) como celda transitable normal, para soportar habitaciones internas con su propia puerta.

## Checklist de "casa aprobable" y dónde vive cada regla

| # | Regla | Dónde vive hoy | Cambia en este trabajo |
|---|---|---|---|
| 1 | Volumen cerrado | `BlueprintValidator` (cerramiento/techo/suelo por piso) | **Sí — rediseño central** |
| 2 | Mínimo 1 puerta | `validar_aberturas` (por piso) | No |
| 3 | Mínimo 1 ventana | `validar_aberturas` (por piso) | No |
| 4 | Mínimo 1 cama | `validar_camas_y_almacenamiento` | No |
| 5 | Mínimo 1 baúl por cama | `validar_camas_y_almacenamiento` | No |
| 6 | Espacio a un lado de cada cama | `VoxelWorld.despeje_camas_invalido()` (al colocar) | No |
| 7 | 2 bloques encima de cada cama | `VoxelWorld.despeje_camas_invalido()` (al colocar) | No |
| 8 | 1 bloque libre detrás de la puerta (dentro) | No existe para casas (sí para Puestos) | **Sí — nuevo, en `BlueprintValidator`** |
| 9 | 2 bloques reservados afuera de la(s) puerta(s) | `VoxelWorld.calcular_despeje()` (al colocar) | No |
| 10 | 1 bloque reservado afuera de la(s) ventana(s) | `VoxelWorld.calcular_despeje()` (al colocar) | No |
| 11 | Pathfinding: acceso real a puertas/camas/baúles | No existe | **Sí — nuevo, en `Player._declarar_edificio()`** |
| 12 | Límite de camas por piso según nivel | `validar_limites_vivienda` | No |
| 13 | Límite de pisos según nivel | `validar_limites_vivienda` | No |

(La numeración del usuario tenía 12 puntos; aquí quedan 13 porque puerta y ventana se separaron para la tabla — son la misma regla original.)

## Parte A — Volumen interior por flood-fill (reglas 1, y la base de 12-13)

### Algoritmo actual y su límite

`estructura_a_blueprint()` agrupa capas de Y en "pisos" (bandas separadas por "losas": capas mayormente sólidas). Una losa se juzga completa/parcial comparando sus celdas contra `huella_real`, la unión 2D de TODAS las capas del edificio. Esto asume que el contorno es constante en toda la altura — se rompe con cualquier retranqueo (techo a dos aguas, torre que se angosta, formas redondeadas).

### Algoritmo nuevo

Reemplazo la comparación contra `huella_real` por un flood-fill 3D (6-conectividad) de AIRE, sembrado desde **fuera** de la caja delimitadora del edificio (expandida +1 en cada eje, para tener un "afuera" real por el que fluir). Toda celda de aire dentro de esa caja que el flood-fill exterior NO alcanza es volumen interior sellado, sin importar la forma:

- No hace falta ninguna huella de referencia: una pirámide, un cilindro o un techo a dos aguas se sellan solos si son físicamente estancos.
- Si el flood-fill exterior logra colarse adentro (una pared con hueco, una losa incompleta), esas celdas quedan marcadas "alcanzadas desde afuera" → no hay volumen interior sellado → el edificio es inválido.
- Puertas y ventanas siguen ocupando su celda como bloque sólido a efectos de este flood-fill (igual que hoy son bloqueantes para `es_celda_estructural`); no son "huecos" para el sellado, son mobiliario que el jugador coloca sobre una pared ya cerrada.

Esto sustituye `validar_cerramiento` + `validar_techo_y_suelo` **solo para blueprints auto-detectados** (los que vienen de `estructura_a_blueprint()`, con datos de voxel reales). Los blueprints JSON hechos a mano (PoC 2, sin datos de voxel) no tienen forma de correr un flood-fill 3D — conservan la validación 2D por piso de siempre.

Mecanismo de compatibilidad: `estructura_a_blueprint()` agrega al blueprint una clave nueva `"volumen_sellado"` (bool) y, si es `false`, un mensaje de error en una lista `"errores_volumen"`. `validar_blueprint()` revisa: si el blueprint TIENE la clave `"volumen_sellado"`, usa ese resultado en vez de correr `validar_cerramiento`/`validar_techo_y_suelo` por piso; si no la tiene (blueprint hecho a mano), corre la validación 2D de siempre. Ningún blueprint JSON existente se ve afectado (nunca trae esa clave).

### Pisos (bandas) siguen derivándose, para las reglas 12-13

Los límites de camas/piso y pisos por nivel (reglas 12-13) siguen necesitando el concepto de "piso". La segmentación en bandas (dónde empieza/termina cada historia) se mantiene con la misma idea de "losa parcial/completa", pero la referencia para decidir si una capa de Y es losa deja de ser `huella_real` global: pasa a ser la huella LOCAL de esa capa dentro del volumen ya detectado por el flood-fill (columnas que en esa capa son estructurales o aire interior sellado). Esto es lo que permite reconocer el techo angosto como losa superior válida (su propia huella, no la de las paredes de abajo) sin dejar de exigir puerta/ventana por piso y separar historias con hueco de escalera (TEST 12 sigue pasando sin cambios).

## Parte B — Vestíbulo de puerta (regla 8)

Nueva función `BlueprintValidator.validar_vestibulos_puerta(piso: Dictionary) -> Array`, corrida junto a `validar_aberturas` dentro de `validar_blueprint()`. Reutiliza el concepto ya existente para Puestos (`PlantillasPuestoTest`): la celda pegada a la puerta por el lado de ADENTRO del piso, con 2 de altura, debe estar libre en el blueprint (ni pared, ni cama, ni baúl). Aplica a cada puerta del piso — externa o interna (una pared interior con su propia puerta cuenta igual).

Determinar "adentro" para una puerta: de las dos celdas ortogonales a la puerta en el plano X/Z, la que SÍ pertenece a la huella del piso (celdas del blueprint) es "adentro"; si ambas pertenecen (puerta interior entre dos habitaciones del mismo piso), ambos lados deben tener su celda libre — cada lado es "adentro" de su propia habitación.

## Parte C — Verificación por pathfinding (regla 11)

`BlueprintValidator` declara explícitamente que NO lee el `VoxelWorld` en vivo — un pathfinder real necesita mundo vivo, así que esta regla no puede vivir ahí. Vive en `Player._declarar_edificio()`, que ya tiene acceso al `VoxelWorld` y a `BuscadorRutas` (el mismo A* que usan los colonos).

Flujo, después de que `validar_blueprint()` da válido pero antes de registrar el edificio:

1. Para cada piso, reunir las celdas de vestíbulo de sus puertas EXTERNAS (celdas cuyo lado "afuera" no pertenece a ningún piso del edificio — distingue puerta externa de interna).
2. Con `BuscadorRutas` configurado para tratar toda celda de puerta (externa o interna) como transitable normal (además del aire), correr `buscar_ruta_a_alguna()` desde el conjunto de vestíbulos externos hacia cada cama y cada baúl del edificio completo (no solo del piso de la puerta: una escalera conecta pisos).
3. Si alguna cama o baúl queda sin ruta, se rechaza la declaración con un mensaje que identifica cuál mueble y en qué piso.

No hace falta que cada puerta externa por separado llegue a todo — basta con que el conjunto de puertas externas, combinado, alcance cada mueble (decisión del usuario).

## Testing

Godot 4.7, `godot/scenes/BlueprintValidatorTest.tscn` (o el `*Test.tscn` que corresponda) más los que ya cubren despeje/colonos si se tocan. Casos nuevos:

- Techo a dos aguas (más angosto que las paredes) sobre una casa de 1 piso — hoy rechazada por "falta un techo sólido", debe aceptarse.
- Mismo caso pero con una fuga real (un hueco en el techo angosto) — debe seguir rechazándose (el flood-fill exterior se cuela).
- Edificio de 2 pisos con techo a dos aguas en la losa superior Y hueco de escalera en la intermedia (el caso real reportado) — debe reconocer 2 pisos y validar.
- Puerta sin celda libre detrás (dentro) — debe rechazarse con el mensaje nuevo.
- Habitación interna con su propia puerta y una cama dentro, alcanzable cruzando la puerta interna desde la puerta externa — debe aprobarse.
- Cama en una habitación interna SIN puerta propia (o con la puerta bloqueada/mal ubicada) — debe rechazarse por pathfinding, no por cerramiento (el volumen sigue sellado, solo que inaccesible).
- Dos puertas externas: una lleva a todo el edificio, la otra queda en un vestíbulo aislado sin más acceso interior — debe aceptarse igual (regla: basta con que el conjunto de puertas alcance todo).
- Blueprint JSON hecho a mano (sin `celdas_3d`/`volumen_sellado`) sigue validándose con las reglas 2D de siempre — regresión, ningún test existente debe romperse.

## No objetivos

- No cambian `Ciudad.NIVELES_VIVIENDA` ni las reglas de balance de camas/pisos.
- No se toca la regla de despeje al COLOCAR (reglas 6-7, 9-10): siguen en `VoxelWorld`, sin cambios.
- No se migra el flujo de Puestos de extracción a este nuevo validador — solo edificios residenciales declarados vía `BlueprintValidator`.
