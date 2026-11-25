# Especificación Técnica: Sistema de Música Adaptativa Contextual (OST por Estado de Juego)

**Estado:** Aprobado para implementación  
**Fecha:** 2026-11-20  
**Módulos Afectados:** `godot/scripts/Sonidos.gd`, `godot/scripts/SonidosTest.gd`, `godot/scripts/Main.gd`, `godot/scripts/MenuInicio.gd`, `godot/scripts/ajustes.gd`, `godot/assets/musica/`.

---

## 1. Objetivo

Reemplazar la reproducción lineal fija de 3 pistas en `Sonidos.gd` por un **Director de Música Adaptativa Contextual** que reproduzca dinámicamente las pistas de `arte/ost/` (y `godot/assets/musica/`) según el estado real de la partida y la etiqueta entre paréntesis en el nombre del archivo:
- `(menu)` — Menú principal y pantallas de bienvenida/carga.
- `(exploration)` — Exploración fuera del área de influencia o antes de fundar la ciudad.
- `(building)` — Construcción, planeación cenital y estancia dentro de la colonia residencial/cívica.
- `(industry)` — Estancia o enfoque sobre el polígono industrial y edificios productivos pesados.
- `(battle)` — Combate activo de tropas, defensas o avatar.

---

## 2. Preparación y Normalización de Assets (`arte/ost/` → `godot/assets/musica/`)

### 2.1. Conversión obligatoria de archivos `.m4a` a `.mp3`
Godot 4 no importa nativamente contenedores `.m4a` (AAC) como `AudioStream`. Antes o durante el paso de importación, el agente de desarrollo debe convertir con `ffmpeg` (`-c:a libmp3lame -q:a 2`) los 4 archivos `.m4a` de `arte/ost/` a `.mp3` y copiar las 16 pistas de `arte/ost/` dentro de `godot/assets/musica/` (conservando también `The_Architect_s_Decree (menu).mp3` ya existente):

| Categoría | Archivo en `arte/ost/` | Archivo destino en `res://assets/musica/` |
| :--- | :--- | :--- |
| `menu` | `Menu & Loading Theme (menu).mp3` | `Menu & Loading Theme (menu).mp3` |
| `menu` | *(ya en `godot/assets/musica/`)* | `The_Architect_s_Decree (menu).mp3` |
| `exploration` | `Untamed Horizons (exploration).m4a` | `Untamed Horizons (exploration).mp3` *(convertido)* |
| `exploration` | `Wilderness & Discovery (exploration).m4a` | `Wilderness & Discovery (exploration).mp3` *(convertido)* |
| `building` | `Cozy_colony (building).mp3` | `Cozy_colony (building).mp3` |
| `building` | `Foundations & Frameworks (building).m4a` | `Foundations & Frameworks (building).mp3` *(convertido)* |
| `building` | `Frontier Blueprint (building).m4a` | `Frontier Blueprint (building).mp3` *(convertido)* |
| `building` | `Seamless_loop  (building).mp3` | `Seamless_loop  (building).mp3` |
| `industry` | `Automated Pulse (industry).mp3` | `Automated Pulse (industry).mp3` |
| `industry` | `Clockwork_logistics (industry).mp3` | `Clockwork_logistics (industry).mp3` |
| `industry` | `Clockwork_logistics_2 (industry).mp3` | `Clockwork_logistics_2 (industry).mp3` |
| `industry` | `Glitch_drift (industry).mp3` | `Glitch_drift (industry).mp3` |
| `industry` | `Glitch_drift_2 (industry).mp3` | `Glitch_drift_2 (industry).mp3` |
| `industry` | `Morning_at_the_Steel_Spire (industry).mp3` | `Morning_at_the_Steel_Spire (industry).mp3` |
| `battle` | `Hard_stop (battle).mp3` | `Hard_stop (battle).mp3` |
| `battle` | `Hard_stop_2 (battle).mp3` | `Hard_stop_2 (battle).mp3` |
| `battle` | `Siege Protocols (battle).mp3` | `Siege Protocols (battle).mp3` |

> **Limpieza de duplicados antiguos:** Los archivos previos en `godot/assets/musica/` con sufijo `(loop).mp3` que sean duplicados exactos de los nuevos con sufijo `(building)`, `(industry)` o `(battle)` deben reemplazarse por las versiones etiquetadas por contexto para no duplicar el peso del repositorio.

### 2.2. Clasificación automática por etiqueta `(contexto)`
`Sonidos.gd` debe clasificar las pistas extrayendo la etiqueta entre paréntesis al final del nombre base (ej. `extraer_contexto_musical(nombre_archivo: String) -> String`):
- Reconoce: `"menu"`, `"exploration"`, `"building"`, `"industry"`, `"battle"`.
- Permite tanto escaneo del directorio `res://assets/musica/` con `DirAccess` como un diccionario de respaldo (`CATALOGO_MUSICA_POR_CONTEXTO`) para exportación empaquetada donde `DirAccess` solo ve `.import`.

---

## 3. Parámetros en `ajustes.gd`

Agregar en `godot/scripts/ajustes.gd` las constantes configurables del director musical:

```gdscript
# ==============================================================================
# MÚSICA ADAPTATIVA CONTEXTUAL (Sonidos)
# ==============================================================================
static var MUSICA_CROSSFADE_AMBIENTAL_S: float = 3.0
static var MUSICA_CROSSFADE_BATALLA_S: float = 0.8
static var MUSICA_HISTERESIS_AMBIENTAL_S: float = 4.0
static var MUSICA_PERMANENCIA_MINIMA_PISTA_S: float = 15.0
static var MUSICA_COOLDOWN_BATALLA_S: float = 15.0
static var MUSICA_RADIO_DETECCION_INDUSTRIA: float = 12.0
static var MUSICA_INTERVALO_EVALUACION_S: float = 1.0
```

---

## 4. Máquina de Estados Musicales y Reglas de Prioridad

El director musical maneja 5 contextos con la siguiente jerarquía estricta (de mayor a menor prioridad):

### Prioridad 1: `"menu"`
- **Activación:** Cuando el juego está en `MenuInicio.gd` o antes de entrar a la escena jugable principal (`Main.gd`).
- **Transición:** Inmediata (o crossfade estándar al entrar a partida).

### Prioridad 2: `"battle"`
- **Activación:** Se dispara inmediatamente cuando:
  1. Cualquier unidad militar aliada, cuartel o el Avatar (`Player.gd`) realiza un ataque en combate o recibe daño hostil (`Sonidos.notificar_evento_combate()`), **o**
  2. El Avatar en 1ª persona está en modo combate/comando activo con enfrentamiento en curso.
- **Mantenimiento (Cooldown):** Una vez activado `"battle"`, permanece activo hasta que transcurran `Ajustes.MUSICA_COOLDOWN_BATALLA_S` (`15.0 s`) desde el último evento de combate registrado.
- **Transición:** Crossfade rápido de `Ajustes.MUSICA_CROSSFADE_BATALLA_S` (`0.8 s`). Ignora los temporizadores de histéresis ambiental.

### Prioridad 3: `"industry"`
- **Activación (cuando no hay batalla):**
  - Se toma como **punto de foco** la posición del Avatar (`player.global_position`) si la cámara activa es 1ª persona, o el punto focal en el suelo de la cámara cenital (`camara_cenital`) si está en vista cenital.
  - Es `"industry"` si:
    1. La celda 2D del punto de foco está dentro (o a distancia $\le$ `MUSICA_RADIO_DETECCION_INDUSTRIA` bloques) de una celda marcada con la zona `"fabricacion_militar"` en `Zonificacion.gd`, **o**
    2. El punto de foco está a $\le$ `MUSICA_RADIO_DETECCION_INDUSTRIA` bloques de un puesto industrial/extractor activo (`mina`, `pozo_agua`, `extractor_crudo`, `aserradero`, `carbonera`, `fabrica_bloques`, `siderurgica`, `refineria_cobre`, `refineria_tierras_raras`, `refineria_petrolera`, `productor_combustible`, `planta_concreto`, `fabrica_componentes`, `central_termoelectrica`), **o**
    3. El jugador tiene abierto en el HUD el panel contextual de uno de esos edificios industriales o `VentanaEnergia`.

### Prioridad 4: `"building"`
- **Activación (cuando no aplica `"battle"` ni `"industry"`):**
  1. El jugador tiene activo en `BarraModos.gd` cualquier modo de construcción, trazado de zonas, trazado de vías/canalizaciones, estampado de blueprints o emplazamiento de puestos, **o**
  2. El punto de foco (Avatar en 1ª persona o `CamaraCenital`) se encuentra **dentro del Área de Influencia de la ciudad** (`zonificacion.dentro_de_influencia(celda_foco)`), **o**
  3. El Avatar en 1ª persona acaba de colocar o demoler bloques de construcción en los últimos `10 s`.

### Prioridad 5: `"exploration"`
- **Activación (estado base por defecto en partida):**
  1. Cuando la ciudad aún no ha declarado su primer Núcleo Urbano (`ciudad.id_nucleo == -1`) y el jugador no está usando un modo de construcción cenital, **o**
  2. Cuando el punto de foco (Avatar en 1ª persona o `CamaraCenital` en observación libre sin herramienta activa) se encuentra **fuera del Área de Influencia de la ciudad** (`not zonificacion.dentro_de_influencia(celda_foco)`).

---

## 5. Arquitectura en `Sonidos.gd`: Crossfade, Histéresis y Shuffle Bag

### 5.1. Doble reproductor para Crossfade (`_player_musica` + `_player_musica_fade`)
- `Sonidos.gd` mantiene dos `AudioStreamPlayer` para música (`_player_musica` como canal principal activo y `_player_musica_secundario` para el fundido cruzado).
- Al cambiar de contexto musical (p. ej. de `"building"` a `"industry"`):
  1. El reproductor que estaba sonando pasa a ser el saliente y un `Tween` interpola su `volume_db` hasta `-60.0 dB` en `duracion_fade` segundos, deteniéndolo al terminar.
  2. El otro reproductor carga la siguiente pista del nuevo contexto, inicia en `-40.0 dB` y sube mediante el mismo `Tween` hasta `volumen_musica_db` en `duracion_fade` segundos.
  3. Si `actualizar_volumen_musica()` es llamado por el usuario desde el menú de opciones durante o después de un crossfade, el reproductor activo ajusta su techo a `volumen_musica_db` (o silencia ambos si `musica_habilitada == false`).

### 5.2. Histéresis Anti-Rebote entre estados ambientales
Para evitar cambios bruscos al cruzar brevemente una frontera de zona:
- Se distinguen **estados urgentes** (`"menu"`, `"battle"`) y **estados ambientales** (`"exploration"`, `"building"`, `"industry"`).
- Si el evaluador solicita pasar de un estado ambiental $A$ a otro estado ambiental $B$:
  1. El estado candidato $B$ debe mantenerse como resultado continuo durante al menos `MUSICA_HISTERESIS_AMBIENTAL_S` (`4.0 s`).
  2. La pista actual del estado $A$ debe haber sonado al menos `MUSICA_PERMANENCIA_MINIMA_PISTA_S` (`15.0 s`), salvo cuando la pista actual ya haya terminado de reproducirse.
- Si el nuevo estado es `"menu"` o `"battle"`, el cambio se ejecuta **inmediatamente** sin esperar histéresis ni permanencia mínima.

### 5.3. Rotación por categoría sin repetición (*Shuffle Bag*)
- Cada uno de los 5 contextos mantiene su propia cola barajada (`_colas_contexto[contexto]`) y recuerda la última pista reproducida (`_ultima_pista_contexto[contexto]`).
- Cuando una pista termina (`finished`), el reproductor activo solicita automáticamente la siguiente pista del **mismo contexto actual** (`en_bucle = false` a nivel de stream individual para permitir avanzar a la siguiente canción del pool del contexto; si el contexto solo tiene 1 pista, la vuelve a reproducir).
- Al barajar de nuevo una bolsa de $\ge 2$ pistas, si la primera pista de la nueva bolsa coincide con `_ultima_pista_contexto[contexto]`, se intercambia con la última de la bolsa para garantizar que nunca suene la misma canción dos veces seguidas.

### 5.4. API Pública en `Sonidos.gd`
Mantener compatibilidad total con las llamadas existentes (`reproducir_musica_menu()`, `reproducir_musica_juego()`, `detener_musica()`) y añadir:
- `establecer_contexto_musica(nuevo_contexto: String, forzar_inmediato: bool = false) -> void`: solicita o fuerza la transición al contexto indicado (`"menu"`, `"exploration"`, `"building"`, `"industry"`, `"battle"`).
- `evaluar_contexto_musical(estado_juego: Dictionary, delta: float) -> String`: recibe las señales del estado actual desde `Main.gd` (si hay combate activo, si está en industria, si está en modo construcción o dentro de influencia), aplica los temporizadores de cooldown de batalla e histéresis, y dispara `establecer_contexto_musica()` cuando corresponde.
- `notificar_evento_combate() -> void`: reinicia el temporizador de `MUSICA_COOLDOWN_BATALLA_S` y activa el contexto `"battle"`.
- `obtener_contexto_musica_actual() -> String`: retorna el contexto musical activo.

---

## 6. Criterios de Aceptación y Pruebas Unitarias (`SonidosTest.gd`)

Ampliar `godot/scripts/SonidosTest.gd` con pruebas automatizadas para verificar:
1. **Clasificación y carga de las 17 pistas:** Verificar que los 5 contextos (`menu`, `exploration`, `building`, `industry`, `battle`) tengan todas sus pistas registradas y que cada archivo en `res://assets/musica/` cargue un `AudioStream` válido con duración $> 0$.
2. **Prioridad de la máquina de estados:**
   - Sin núcleo ni influencia → `"exploration"`.
   - Dentro de influencia o con herramienta de construcción → `"building"`.
   - En zona `"fabricacion_militar"` o junto a industria → `"industry"` (prevalece sobre `"building"`).
   - Al llamar a `notificar_evento_combate()` → pasa inmediatamente a `"battle"` (prevalece sobre `"industry"`, `"building"` y `"exploration"`) y tras expirar `MUSICA_COOLDOWN_BATALLA_S` regresa al estado ambiental correspondiente.
3. **Histéresis anti-rebote:** Simular un cambio ambiental de `"building"` a `"industry"` durante solo `2.0 s` (< `4.0 s` de histéresis) y regresar a `"building"`; comprobar que el contexto activo nunca cambió a `"industry"`. Simular `4.5 s` continuos (con permanencia cumplida) y comprobar que sí transiciona a `"industry"`.
4. **Shuffle Bag sin repetición consecutiva:** En un contexto con $\ge 2$ pistas (ej. `"building"` o `"industry"`), solicitar 10 pistas consecutivas y verificar que ninguna pista sea idéntica a la inmediatamente anterior.
