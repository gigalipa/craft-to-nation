# HUD por modos — diseño

Fecha: 2026-09-25. Punto 1 de `docs/Pendientes y próximos pasos.md` ("HUD visual interactivo").
Conceptos visuales de referencia: `arte/conceptos-hud/` (capturas de construcción en 1ª persona, batalla en 1ª persona y cámara cenital).

## Objetivo

Reemplazar el HUD de texto plano (`godot/scripts/HUD.gd`) por un HUD visual organizado **por modos**, con un esqueleto común a las dos vistas:

- **Barra superior** (ambas vistas): recursos, población, moral y nivel urbano, con datos reales de `Ciudad`.
- **Panel contextual inferior** (ambas vistas): ítem activo, costo, acciones y validez.
- **Barra de modos vertical izquierda** (cenital): un botón por modo, con su tecla.
- **Hotbar 1–6** (primera persona): los tipos de bloque actuales, con la casilla seleccionada resaltada.

Estilo común: verde oscuro con marco dorado (ver capturas), definido como helpers estáticos en `TemaHUD.gd` (no un recurso `Theme`).

## Fuera de alcance

- Batalla, escuadrón, salud y equipo (no hay sistema detrás).
- Cantidades por casilla en la hotbar. El inventario del avatar será el almacén central (`Ciudad`/`Economia`), no los almacenes dedicados; la hotbar deja un campo de cantidad opcional, vacío por ahora.
- Herramientas de recolección (pala, pico, hacha): llegarán después, como casillas nuevas.
- Modo Demoler en cenital: no existe todavía (la deconstrucción solo funciona en 1ª persona con G). No se muestra su botón hasta que exista.
- Barra de progreso, oxígeno y ficha de materiales se conservan tal cual. `PanelPuesto` conserva su lógica; su estilo pasó a `TemaHUD` (ver ajuste 2026-09-27).
- Iconos: no hay arte. Los botones y casillas usan nombre + tecla; cada uno admite un `icono: Texture2D` opcional para enchufarlo después.

## Controles (sin cambios)

Ningún atajo cambia. En 1ª persona: 1–6 tipo de bloque, G deconstruir, B declarar edificio, E interactuar. En cenital: Z zonas, V vías, B blueprint, M/H/L/F puestos, Esc salir de todos los modos. Los clics en la barra de modos llaman a las mismas funciones `_alternar_modo_*` que las teclas.

## Arquitectura

`HUD.gd` sigue siendo el único punto de contacto de `Player.gd` y `CamaraCenital.gd`; delega en widgets `Control` pequeños, cada uno con una sola responsabilidad.

| Pieza | Vista | Muestra | Fuente de datos |
|---|---|---|---|
| `BarraSuperior` | ambas | de lado a lado; de izquierda a derecha: población `censo/camas (desempleados)`, moral, comida (`cantidad/límite` propios + tasa `+x/h`), almacenamiento total (Σ cantidades / Σ límites y Σ tasas), recurso crítico (tasa más negativa o, si ninguno decrece, la menor positiva; la tasa 0 no cuenta), era y nivel. Población y Almacén son clicables (señal `dato_pedido`, ver abajo) | `Ciudad`, leído cada fotograma. Población y moral sin tasa (`Ciudad` no la calcula). La era es un texto fijo (`Era 1 · Prehistórica`) hasta que exista `Ciudad.era` |
| `PanelContextual` | ambas | nombre, costo, acciones, validez ("Ubicación válida"/"no válida", opcional) y una línea opcional de tasas previstas (sin miniatura: no hay arte) | empujado por `CamaraCenital` (blueprint/puesto activo) y `Player` (raycast) |
| `BarraModos` | cenital | esquina inferior izquierda: barra principal (Ver, Construir, Zonas, Vías; activo resaltado y tecla) y, a su derecha, una barra de subherramientas según el modo (Construir: Residencial y los 4 puestos; Zonas: Zona A/B/Borrar) | `CamaraCenital` avisa el modo activo |
| `Hotbar` | 1ª persona | casillas 1–6 (icono/nombre), seleccionada resaltada, cantidad opcional | `Player.tipos_disponibles` y `tipo_seleccionado` |

Scripts nuevos en `godot/scripts/` (uno por pieza, más el `Theme`). Sin autoload nuevo ni registro de modos: la lista de modos es una constante en `BarraModos`.

### API nueva de `HUD.gd`

- `mostrar_contexto(nombre: String, costo: Dictionary, acciones: Array, valido: Variant = null, extra: String = "")` / `ocultar_contexto()` — `valido` `true`/`false` muestra la validez; `null` la oculta.
- `mostrar_contexto_puesto(tipo: String, valida: bool, tasas: Dictionary)` — costo, personal, almacenamiento y tasas previstas de un puesto.
- `mostrar_contexto_temporal(nombre, costo, acciones, segundos = 2.5)` — panel que aparece con fade-in deslizante hacia arriba desde la hotbar y se desvanece solo; sin validez. Lo usa `Player` al elegir 1–6. El panel de deconstrucción (G) es fijo (`mostrar_contexto`) hasta desactivar G.
- `set_vista(primera_persona: bool)` — muestra la hotbar (1ª persona) o la barra de modos (cenital) y descarta el panel contextual.
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

Construir (B) activa el blueprint residencial y despliega a su derecha el menú Residencial + los 4 puestos (mina, caza/recolección, maderero, pesca); elegir uno equivale a su tecla (B, M/H/L/F). Las teclas siguen funcionando directamente.

### 1ª persona

`Hotbar` muestra los 6 tipos de `Player.tipos_disponibles`. `Player` avisa la selección con `HUD.set_tipo_hotbar()`. `PanelContextual` muestra el tipo apuntado con `COLOCAR` y su validez según el raycast. G (deconstruir) sigue en G; mientras esté activo se indica en el panel. La cantidad por casilla queda vacía hasta que se defina el consumo de materiales.

## Feedback de colocación en 1ª persona

`CaraApuntada.gd`: quad verde translúcido y brillante (con pulso suave) sobre la cara del bloque que apunta el raycast del avatar. Solo se muestra si el raycast golpea algo (su largo, 5 bloques, es el alcance de colocar y minar). Reemplaza la línea "Ubicación válida" del panel en 1ª persona. Es un quad de 1×1: sobre piezas que no son un cubo entero (puerta, ventana) no ajusta perfecto.

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

## Ajuste 2026-09-27: ventanas de Población/Almacén y estilo de PanelPuesto

- `BarraSuperior`: población pasa a `censo/camas (desempleados)`; comida pasa a mostrar su propio `cantidad/límite` (antes solo cantidad), ambos con su tasa.
- Clic en "Población" o "Almacén" (solo tiene efecto en la cenital: `CamaraCenital` conecta `HUD.dato_pedido`, `Player` no) abre una ventana emergente, estilo `TemaHUD`, con botón de cierre:
  - `VentanaPoblacion.gd`: demografía por tipo (`Ciudad.demografia`), camas construidas y, por puesto (`Economia.puestos`), su tipo y cantidad de recolectores/acarreadores (`Economia.trabajadores_de`).
  - `VentanaAlmacen.gd`: una fila por recurso de `Ciudad.almacen`, con cantidad/límite y tasa.
  - `HUD.abrir_ventana_dato(cual)` abre la ventana pedida; ambas pueden estar abiertas a la vez (decisión del usuario, 2026-09-27) — cada una tiene su propia esquina por defecto para no solaparse.
  - Ambas se actualizan en vivo (`_process()`) mientras están visibles, son arrastrables (clic y arrastre sobre cualquier parte que no sea el botón de cierre) y aparecen por defecto en la esquina superior izquierda (Población arriba, Almacén debajo). Al ser hijas de `HUD` (nunca se destruyen), su posición y si el usuario las dejó abiertas o cerradas persisten solas mientras dura la partida — incluida cada vez que se vuelve a la cenital: `HUD.set_vista()` las oculta con `ocultar_temporalmente()` al entrar a 1ª persona (sin tocar su posición ni marcarlas cerradas) y las restaura con `restaurar()` al volver.
- `PanelPuesto.gd` (ventana de asignación de trabajadores de un puesto) pasa a usar `TemaHUD.aplicar_panel/etiqueta/estilizar_boton`, sin cambiar su lógica ni su posición.
- `CamaraCenital.posicionar_sobre()` ya no reinicia `angulo_inclinacion`/`distancia_camara` al activarse (quedan como en el último uso de la cenital), pero `angulo_orbital` NO se recuerda (ajuste 2026-09-27, tercera vuelta): cada vez que se activa la cenital se recalcula para orbitar detrás de hacia dónde mira el avatar (`atan2` de `jugador.global_transform.basis.z`, que es "atrás" — lo opuesto de `-basis.z`, el "adelante" de `Player._direccion_cardinal()` —, seguimiento en 3ª persona), porque el avatar puede haber girado. `posicionar_sobre(foco_xz, angulo_avatar)` recibe ese ángulo; lo calcula `Main._alternar_camara_cenital()`.

## Ajuste 2026-09-27 (2): ambas ventanas abiertas a la vez y transición animada de cámara

- `HUD.abrir_ventana_dato()` ya no cierra la otra ventana: Población y Almacén pueden estar abiertas al mismo tiempo.
- Cambiar de cámara (`C`) ya no es instantáneo: `Main._alternar_camara_cenital()` anima un vuelo de `DURACION_TRANSICION` (0.6 s) entre la vista saliente y la entrante.
  - `Main._camara_transicion` (un `Camera3D` libre, hijo de `Main`) es la única cámara `current` durante el vuelo; su `global_transform` se interpola con un `Tween` (`TRANS_CUBIC`/`EASE_IN_OUT`) desde el transform de la cámara saliente hasta el de la entrante — el `Tween` interpola `Transform3D` con slerp de rotación de forma nativa, sin código de cuaterniones a mano. Su `fov` se interpola en paralelo (mismo `Tween`, `set_parallel(true)` + `chain()` antes del callback final): `CamaraCenital` usa `fov = 60` y la de 1ª persona el valor por defecto (75) — sin interpolar el fov también, había un salto de encuadre justo al intercambiar la cámara activa (reportado por el usuario, 2026-09-27).
  - Mientras dura: `CamaraCenital.current` y `Player.camara.current` en falso (ninguna de las dos procesa: `CamaraCenital._process()`/`_unhandled_input()` vuelven de inmediato si `current` es falso), `Player.set_physics_process(false)` y el ratón liberado (`MOUSE_MODE_VISIBLE`, lo que también desactiva el mouse-look de `Player`, condicionado a `MOUSE_MODE_CAPTURED`). `Main._en_transicion` bloquea una segunda pulsación de `C` hasta terminar.
  - `HUD.iniciar_transicion(a_cenital, duracion)` hace un crossfade: desvanece la saliente (`_hotbar` o `_barra_modos`) durante la mitad de la duración, cambia la visibilidad real con `set_vista()` en el punto medio (con alfa en 0, sin salto visible) y aparece la entrante en la segunda mitad. `_contexto` se oculta al empezar. La barra superior (común a ambas vistas) no se desvanece.
  - Al llegar (`Main._terminar_transicion()`): se fijan las cámaras reales (`current`), se restaura `Player.set_physics_process()`, `zona_overlay`/`mira_ui` según la vista de destino y el modo mouse (capturado en 1ª persona).

## Documentación a actualizar

GDD (sección de interfaz), `docs/Pendientes y próximos pasos.md` (marcar el punto 1 hecho al terminar) y el documento técnico de la PoC vigente.
