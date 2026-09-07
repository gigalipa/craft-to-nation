# Diseño: Zonificación Pintada sobre el Grid (PoC 4, sub-proyecto 4)

**Fecha:** 2026-09-07
**Roadmap:** GDD Sección 11, Fase 2 ("Ciudad y Demografía Visibles") — último de los 4 sub-proyectos, ver `PoC_4/`.
**Depende de:** GDD Sección 3 y 3.1 (zonificación urbana y taxonomía de edificios), `PoC_3`/`PoC_4` (`VoxelWorld.gd`, `Player.gd`, `BlueprintValidator.gd`, `Ciudad.gd`, todos en `godot/`).

## Contexto

El GDD (Sección 3) ya definía 3 distritos territoriales (Núcleo A residencial/investigación, Núcleo B industrial/militar, periferia) y `BlueprintValidator.gd` ya tenía la validación de zona (`ZONAS_VALIDAS`, `validar_zona_permitida`, `validar_colocacion`) escrita pero nunca conectada — `Player.gd::_declarar_edificio()` llama a `validar_blueprint(blueprint)` sin `zona_destino`, así que el chequeo de zona nunca se ejecuta hoy.

Este sub-proyecto conecta esa validación a un sistema real de zonas pintables sobre el grid, más una "zona de influencia" (área alrededor del núcleo urbano donde se puede pintar) y una cámara cenital mínima (requisito de UX que el GDD describe como parte de PoC 5/Fase 3, pero que esta pieza necesita ya, en una versión reducida, solo para pintar zonas — no incluye selección por arrastre de tropas ni las demás mecánicas de PoC 5).

Solo existe un tipo de edificio construible hoy (residencial). La taxonomía completa de tipos de edificio (GDD Sección 3.1: investigación, industrial, producción, militar, recolección, defensivo) es diseño para el futuro — esta PoC implementa la regla de zona de forma genérica (sobre el campo `zona_permitida` del Blueprint, que ya existe), para que agregar los demás tipos después no requiera tocar la lógica de validación.

## Decisiones Confirmadas con el Usuario

1. **Cámara cenital mínima ahora**, no la versión completa de PoC 5. Sin paneo/zoom, sin selección de tropas — solo toggle + mirar hacia abajo + pintar zonas.
2. **Zona de influencia:** no es un cuadrado de lado fijo — es la caja delimitadora (bounding box) de la huella del primer edificio, expandida `MARGEN_ZONA_INFLUENCIA := 15` celdas hacia cada uno de los 4 lados. Ej.: huella de 10×7 → zona de influencia de (15+10+15)×(15+7+15) = 40×37.
3. **Bootstrap del núcleo urbano:** el primer edificio residencial válido declarado se acepta **sin exigir zona pintada** (todavía no existe ninguna). Su propia declaración: (a) crea la zona de influencia a partir de la caja delimitadora de su huella + el margen de 15 celdas por lado, (b) pinta automáticamente su huella como `"residencial_investigacion"`. Edificios declarados después sí exigen zona real.
4. **Pintado por rectángulo de 2 clics** (estilo SimCity): con la cámara cenital activa, el jugador selecciona un tipo de zona con una tecla numérica (`1`/`2` — solo Núcleo A/B son pintables explícitamente; `"periferia"` es el valor por defecto de toda celda no pintada), hace clic en una esquina, mueve el mouse y hace clic en la esquina opuesta; se pinta el rectángulo resultante, recortado a la zona de influencia.
5. **Visualización:** overlay traslúcido (planos semitransparentes con material de transparencia estándar de Godot — no hace falta escribir un shader a mano), visible **solo** desde la cámara cenital; invisible en 1ª persona.
6. **Alcance del bloqueo en esta PoC:** solo al declarar edificio (`Player.gd::_declarar_edificio`). El GDD real también lo aplicaría al emplazar un blueprint desde la vista cenital, pero esa mecánica de "colocar edificios desde arriba" no existe todavía (depende de PoC 5 completo) — queda fuera de alcance.

## Arquitectura

```
godot/
  project.godot              # [autoload] + Zonificacion="*res://scripts/Zonificacion.gd"
  scenes/
    Main.tscn                 # + CamaraCenital (Camera3D), + ZonaOverlay (Node3D)
    ZonificacionTest.tscn     # Nueva escena de pruebas (sin gameplay), mismo patrón que CiudadTest.tscn
  scripts/
    Zonificacion.gd            # Nuevo autoload: estado + lógica pura de zonas
    ZonificacionTest.gd        # Puerto de pruebas aisladas (como CiudadTest.gd)
    CamaraCenital.gd            # Nuevo: cámara ortogonal, toggle, pintado por 2 clics
    Main.gd                     # + toggle de cámara (tecla C), pausa input del jugador mientras está activa
    Player.gd                   # _declarar_edificio(): bootstrap vs. validación de zona real
    BlueprintValidator.gd       # Sin cambios de lógica — ya tenía validar_colocacion/zona_permitida
```

### Componentes

**`Zonificacion.gd` (autoload, sin `class_name`, mismo patrón que `Ciudad.gd`):**
- Estado: `nucleo_declarado: bool`, `influencia_min: Vector2i`, `influencia_max: Vector2i` (esquinas de la caja delimitadora, ambas inclusive), `zonas: Dictionary` (`Vector2i(x,z) -> String`).
- `const MARGEN_ZONA_INFLUENCIA := 15`
- `const ZONAS_PINTABLES := ["residencial_investigacion", "fabricacion_militar"]`
- `func declarar_nucleo(huella: Array[Vector2i]) -> void`: bootstrap — calcula la caja delimitadora de `huella` (min/max de X y Z entre todas sus celdas), fija `influencia_min`/`influencia_max` expandiendo esa caja `MARGEN_ZONA_INFLUENCIA` celdas por lado, marca `nucleo_declarado = true`, y pinta cada celda de `huella` como `"residencial_investigacion"`. Debe llamarse una sola vez; llamadas repetidas se ignoran (`if nucleo_declarado: return`).
- `func dentro_de_influencia(celda: Vector2i) -> bool`: `celda.x` entre `influencia_min.x` e `influencia_max.x` (inclusive), mismo para Z. Devuelve `false` si `not nucleo_declarado`.
- `func pintar_zona(esquina_a: Vector2i, esquina_b: Vector2i, tipo: String) -> int`: recorre el rectángulo entre las dos esquinas (min/max de X y Z), pinta cada celda dentro de `dentro_de_influencia()` con `tipo` (debe estar en `ZONAS_PINTABLES`, si no, no hace nada y devuelve 0), y devuelve cuántas celdas pintó realmente (para que `CamaraCenital.gd` pueda informar al jugador si el rectángulo cayó total o parcialmente fuera de la zona de influencia).
- `func consultar_zona(celda: Vector2i) -> String`: devuelve `zonas.get(celda, "periferia")`.

**`CamaraCenital.gd` (script de un `Camera3D` en `Main.tscn`):**
- Proyección ortogonal (`projection = PROJECTION_ORTHOGONAL`), posicionada sobre el centro de la caja de influencia (`(influencia_min + influencia_max) / 2`, o el origen si `not nucleo_declarado`) mirando hacia abajo (`rotation_degrees.x = -90`).
- Estado local: `tipo_zona_seleccionada: String`, `primera_esquina: Vector2i` con `bool esperando_segunda_esquina`.
- `_unhandled_input`: si la cámara no está `current`, ignora todo. Teclas `1`/`2` seleccionan `ZONAS_PINTABLES[0]`/`[1]`. Clic izquierdo: convierte la posición del mouse a una celda de grid (raycast contra un plano `y = 0`, luego `VoxelWorld.local_to_map`); primer clic guarda `primera_esquina`; segundo clic llama a `Zonificacion.pintar_zona(primera_esquina, celda_actual, tipo_zona_seleccionada)`, imprime el resultado, y resetea el estado de "esperando segunda esquina".

**`ZonaOverlay` (nodo `Node3D` en `Main.tscn`, gestionado desde `CamaraCenital.gd` o un script propio):**
- Un `MeshInstance3D` (plano delgado, `PlaneMesh`) por celda pintada, con `StandardMaterial3D` semitransparente (color por tipo: azul para `residencial_investigacion`, naranja para `fabricacion_militar`), posicionado en `y = 0.05` (justo sobre el piso).
- Se reconstruye (o se agregan solo las celdas nuevas) cada vez que `pintar_zona()` pinta algo — el enfoque más simple es reconstruir todo el overlay a partir de `Zonificacion.zonas` cada vez que cambia, dado que el máximo son 225 celdas (15×15).
- Visibilidad: `visible = (camara_cenital.current)`, actualizado en el toggle de `Main.gd`.

**`Main.gd` (cambios):**
- Tecla de toggle (`C`): alterna `camara_cenital.current` / `jugador.camara.current`, y llama a `jugador.set_physics_process(!cenital_activa)` para congelar el movimiento del jugador mientras la cenital está activa (el jugador no se mueve, pero conserva su posición al volver). También alterna `zona_overlay.visible`.

**`Player.gd::_declarar_edificio()` (cambios):**
- `celda_puerta_xz := Vector2i(celda.x, celda.z)` — la misma `celda` que ya usa la función (la puerta apuntada, origen de `detectar_estructura()`). Es la referencia única para "dónde está" el edificio, tanto para el centro del bootstrap como para consultar su zona.
- Calcula la huella XZ del edificio (celdas únicas `Vector2i(pos.x, pos.z)` de `celdas.keys()`, el diccionario que devuelve `detectar_estructura`).
- Si `not Zonificacion.nucleo_declarado`: valida con `BlueprintValidator.validar_blueprint(blueprint)` (sin `zona_destino`, como hoy). Si resulta válido, además de lo que ya hace (registrar camas), llama a `Zonificacion.declarar_nucleo(huella)`.
- Si `Zonificacion.nucleo_declarado`: calcula `zona_destino = Zonificacion.consultar_zona(celda_puerta_xz)` y valida con `BlueprintValidator.validar_blueprint(blueprint, zona_destino)` — ahora sí participa `validar_colocacion()`.

## Flujo de Datos

1. Jugador construye y declara su primera casa (`B`, en 1ª persona) → bootstrap: núcleo urbano + zona de influencia + Núcleo A auto-pintado en su huella.
2. Jugador presiona `C` → cámara cenital activa, movimiento del jugador congelado, overlay de zonas visible.
3. Jugador selecciona tipo de zona (`1`/`2`), hace 2 clics → `Zonificacion.pintar_zona()` pinta el rectángulo recortado a la zona de influencia → overlay se actualiza.
4. Jugador presiona `C` de nuevo → vuelve a 1ª persona, overlay oculto, movimiento reanudado.
5. Jugador construye y declara una segunda casa en una celda pintada como Núcleo A → válida. En una celda pintada como Núcleo B o sin pintar (periferia) → inválida, con el mismo mensaje de error que ya genera `validar_colocacion()`.

## Manejo de Errores / Casos Límite

- Pintar antes de que exista zona de influencia: `dentro_de_influencia()` devuelve `false` para todo, `pintar_zona()` no pinta nada (devuelve 0) — `CamaraCenital.gd` debe imprimir un mensaje si el resultado es 0 y `not Zonificacion.nucleo_declarado`.
- Rectángulo con una esquina dentro y otra fuera de la influencia: se pintan solo las celdas dentro (recorte, no todo-o-nada).
- Declarar un segundo edificio residencial *antes* de pintar ninguna zona explícita: su huella cae en celdas "periferia" (no pintadas) → inválido, con el error existente de `validar_colocacion` ("no puede colocarse en la zona 'periferia'"). Esperado: el jugador debe pintar Núcleo A alrededor de su núcleo antes de expandirse.
- `declarar_nucleo()` llamado dos veces (no debería ocurrir en el flujo normal, pero por seguridad): la segunda llamada se ignora sin efecto.

## Pruebas

`ZonificacionTest.gd` (mismo patrón que `CiudadTest.gd`, corrido vía `ZonificacionTest.tscn` con F6):
1. `dentro_de_influencia()` es `false` antes de `declarar_nucleo()`.
2. `declarar_nucleo()` fija `nucleo_declarado = true`, calcula `influencia_min`/`influencia_max` como la caja delimitadora de la huella expandida `MARGEN_ZONA_INFLUENCIA` por lado, y pinta la huella dada como `"residencial_investigacion"`. Verificar con una huella no cuadrada (p. ej. 10×7) que la caja de influencia resultante sea `(15+10+15)×(15+7+15)`.
3. `dentro_de_influencia()` es `true` para una celda de la huella y para una celda justo en el borde del margen, y `false` para una celda un paso más allá del margen, tras `declarar_nucleo()`.
4. `pintar_zona()` con ambas esquinas dentro de la influencia pinta el rectángulo completo (verificar `consultar_zona()` en varias celdas del rectángulo, incluidas las esquinas).
5. `pintar_zona()` con una esquina fuera de la influencia solo pinta las celdas dentro (recorte).
6. `pintar_zona()` con un `tipo` fuera de `ZONAS_PINTABLES` no pinta nada y devuelve 0.
7. `consultar_zona()` de una celda nunca pintada devuelve `"periferia"`.
8. `declarar_nucleo()` llamado dos veces: la segunda no cambia `influencia_min`/`influencia_max` ni repinta.

La cámara cenital, el pintado por mouse y el overlay visual solo se pueden confirmar por carga sin errores vía MCP (headless) — la confirmación visual/interactiva real requiere el editor de Godot, mismo patrón que el HUD (ver `PoC_4/`, Sección 3.4).

## Fuera de Alcance (explícito)

- Selección por arrastre de tropas, transición suave de cámara, paneo/zoom de la cenital — eso es PoC 5 completo (Fase 3).
- Emplazar blueprints completos desde la vista cenital (el GDD real lo exige, pero depende de mecánicas que no existen todavía).
- Los demás tipos de edificio de la taxonomía (GDD Sección 3.1): investigación, industrial, producción, militar, recolección, defensivo. La regla de recolección/defensivo respecto a "dentro/fuera de zona de influencia" (no de Núcleo A/B) no se implementa todavía — no hay ningún edificio de esas categorías construible.
- Redimensionar o mover la zona de influencia una vez creada.
- Deshacer/repintar una celda ya pintada con otro tipo (`pintar_zona` simplemente sobrescribe — comportamiento aceptable para esta PoC, no se pidió protección contra sobrescritura accidental).
