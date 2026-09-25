# HUD por modos — diseño

Fecha: 2026-09-25. Punto 1 de `docs/Pendientes y próximos pasos.md` ("HUD visual interactivo").
Conceptos visuales de referencia: `arte/conceptos-hud/` (capturas de construcción en 1ª persona, batalla en 1ª persona y cámara cenital).

## Objetivo

Reemplazar el HUD de texto plano (`godot/scripts/HUD.gd`) por un HUD visual organizado **por modos**, con un esqueleto común a las dos vistas:

- **Barra superior** (ambas vistas): recursos, población, moral y nivel urbano, con datos reales de `Ciudad`.
- **Panel contextual inferior** (ambas vistas): ítem activo, costo, acciones y validez.
- **Barra de modos vertical izquierda** (cenital): un botón por modo, con su tecla.
- **Hotbar 1–6** (primera persona): los tipos de bloque actuales, con la casilla seleccionada resaltada.

Estilo común: verde oscuro con marco dorado (ver capturas), definido en un solo `Theme` construido en código.

## Fuera de alcance

- Batalla, escuadrón, salud y equipo (no hay sistema detrás).
- Cantidades por casilla en la hotbar. El inventario del avatar será el almacén central (`Ciudad`/`Economia`), no los almacenes dedicados; la hotbar deja un campo de cantidad opcional, vacío por ahora.
- Herramientas de recolección (pala, pico, hacha): llegarán después, como casillas nuevas.
- Modo Demoler en cenital: no existe todavía (la deconstrucción solo funciona en 1ª persona con G). No se muestra su botón hasta que exista.
- `PanelPuesto`, barra de progreso, oxígeno y ficha de materiales se conservan tal cual.
- Iconos: no hay arte. Los botones y casillas usan nombre + tecla; cada uno admite un `icono: Texture2D` opcional para enchufarlo después.

## Controles (sin cambios)

Ningún atajo cambia. En 1ª persona: 1–6 tipo de bloque, G deconstruir, B declarar edificio, E interactuar. En cenital: Z zonas, V vías, B blueprint, M/H/L/F puestos, Esc salir de todos los modos. Los clics en la barra de modos llaman a las mismas funciones `_alternar_modo_*` que las teclas.

## Arquitectura

`HUD.gd` sigue siendo el único punto de contacto de `Player.gd` y `CamaraCenital.gd`; delega en widgets `Control` pequeños, cada uno con una sola responsabilidad.

| Pieza | Vista | Muestra | Fuente de datos |
|---|---|---|---|
| `BarraSuperior` | ambas | comida, madera, piedra, hierro, población `x/y`, moral y nivel | `Ciudad`, leído cada fotograma (como hoy) |
| `PanelContextual` | ambas | miniatura opcional, nombre, costo, acciones, validez (✓/✗) y una línea opcional de tasas previstas | empujado por `CamaraCenital` (blueprint/puesto activo) y `Player` (raycast) |
| `BarraModos` | cenital | Ver, Construir, Zonas, Vías, Puestos; activo resaltado y tecla | `CamaraCenital` avisa el modo activo |
| `Hotbar` | 1ª persona | casillas 1–6 (icono/nombre), seleccionada resaltada, cantidad opcional | `Player.tipos_disponibles` y `tipo_seleccionado` |

Scripts nuevos en `godot/scripts/` (uno por pieza, más el `Theme`). Sin autoload nuevo ni registro de modos: la lista de modos es una constante en `BarraModos`.

### API nueva de `HUD.gd`

- `mostrar_contexto(nombre: String, costo: Dictionary, acciones: Array, valido: bool, extra: String = "")` / `ocultar_contexto()`
- `set_modo(modo: String)` — resalta el botón del modo activo (`""` = Ver).
- `set_tipo_hotbar(indice: int)` — casilla seleccionada en 1ª persona.

`extra` transporta la línea de tasas de recolección previstas: se conservan como información útil al colocar puestos aunque la captura de concepto no las incluya.

### Se elimina de `HUD.gd`

Etiquetas de nivel/población/moral/recursos (pasan a `BarraSuperior`); `mostrar_modo_deconstruccion`/`ocultar_…`, `mostrar_modo_zonificacion`/`ocultar_…`, `mostrar_modo_trazar_via`/`ocultar_…` (pasan a `set_modo` y al panel); las cuatro fichas de puesto (`mostrar_ficha_*`, `actualizar_tasas_*`, `ocultar_ficha_*` para mina, caza, madero, pesca) y sus nodos en `Main.tscn`. Los constantes `NOMBRES_*` se conservan donde aún los use el formato de tasas.

### Mapeo de modos (cenital)

| Botón | Modo real | Tecla |
|---|---|---|
| Ver | ninguno (estado por defecto) | Esc |
| Construir | blueprint (`_alternar_modo_colocar_blueprint`) | B |
| Zonas | zonificar (`_alternar_modo_zonificar`) | Z |
| Vías | trazar vía (`_alternar_modo_trazar_via`) | V |
| Puestos | colocar puesto; tira de 4 tipos sobre el panel | M/H/L/F |

Puestos abre una tira con los 4 tipos (mina, caza/recolección, maderero, pesca); elegir uno equivale a su tecla. Las teclas siguen funcionando directamente.

### 1ª persona

`Hotbar` muestra los 6 tipos de `Player.tipos_disponibles`. `Player` avisa la selección con `HUD.set_tipo_hotbar()`. `PanelContextual` muestra el tipo apuntado con `COLOCAR` y su validez según el raycast. G (deconstruir) sigue en G; mientras esté activo se indica en el panel. La cantidad por casilla queda vacía hasta que se defina el consumo de materiales.

## Errores y casos límite

- `Ciudad.almacen` sin alguna de las 4 claves de la barra: mostrar 0, no fallar.
- Ningún modo activo: `set_modo("")` resalta Ver; el panel contextual se oculta.
- Modos mutuamente excluyentes (ya lo son en `CamaraCenital`): `set_modo` solo refleja el estado, no lo decide.

## Pruebas

`godot/scenes/HUDTest.tscn` (+ script `HUDTest.gd`, mismo patrón de las demás `*Test.tscn`), con aserciones sobre:

- texto de `BarraSuperior` frente a valores conocidos de `Ciudad`;
- formato de costo y validez en `PanelContextual`;
- casilla seleccionada en `Hotbar`;
- botón resaltado en `BarraModos` por `set_modo`.

Verificación manual en la escena principal (cenital y 1ª persona) de que cada tecla sigue activando su modo y el HUD lo refleja. Además de `HUDTest.tscn`, ejecutar `Test.tscn` y las `*Test.tscn` que toquen `Player`/`CamaraCenital`, según CLAUDE.md.

## Documentación a actualizar

GDD (sección de interfaz), `docs/Pendientes y próximos pasos.md` (marcar el punto 1 hecho al terminar) y el documento técnico de la PoC vigente.
