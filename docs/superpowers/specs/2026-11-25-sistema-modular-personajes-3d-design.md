# Especificación Técnica: Sistema Modular de Personajes 3D

**Fecha:** 2026-11-25  
**Autor:** Antigravity / Pair Programming  
**Estado:** Aprobado para Implementación de Arquitectura Plug-and-Play  
**Contexto del Proyecto:** Craft to Nation — Reemplazo progresivo de cápsulas placeholder en `ColonosRenderer.gd` e integración con `AvatarAnimador.gd`, `Colonos.gd`, `Ciudad.gd` y `tools/3d_pipeline/` (`craft-character-3d`)

---

## 1. Resumen Ejecutivo y Relación con Documentos Previos

Este documento especifica la arquitectura completa para el **Sistema Modular de Personajes 3D** de *Craft to Nation* (origen: `docs/ideas-backlog.md`, líneas 162–180), diseñado para operar en **dos fases complementarias**:

1. **Arquitectura Plug-and-Play (implementable de inmediato sin tener aún los `.glb`):**
   - Persiste identidad (`genero`, `tono_piel`, `equipo_id`, `orientacion_y`) en `Colonos.gd`, `Ciudad.gd` y `GestorPartida.gd`.
   - Implementa la regla de género en Elecciones / Sucesión del Avatar (`Ciudad.suceder_avatar`) con seguro anti-bloqueo.
   - Introduce `CatalogoPersonajes.gd` y `PersonajeModular.gd` dentro de `ColonosRenderer.gd` (y métodos de identidad/equipamiento en `AvatarAnimador.gd` / `Player.gd`) con **detección automática en tiempo de ejecución** de los `.glb` presentes y **fallback transparente a los placeholders actuales** (cápsula + distintivo de equipo + casco/escudo procedural militar) cuando aún no exista el asset correspondiente.
2. **Integración Progresiva de Assets (drop-in sin tocar código):**
   - Al generar cuerpos base, atuendos o herramientas mediante el pipeline híbrido (`docs/prompt_img-2-3D.md` y `.agents/skills/craft-character-3d/SKILL.md`), basta colocar cada `.glb` en su ruta estándar dentro de `godot/assets/personajes/` para que todos los colonos y el avatar lo adopten automáticamente.

### Documentos Relacionados
- `docs/ideas-backlog.md` (Sección «Sistema modular de personajes 3D») — Requisitos funcionales del usuario.
- `docs/prompt_img-2-3D.md` y `.agents/skills/craft-character-3d/SKILL.md` — Pipeline Hunyuan3D-2mv + UniRig en Modal + post-procesado Blender (`blender_godot_prepare.py`, `blender_mixamo_retarget.py`).
- `godot/scripts/AvatarAnimador.gd` y `godot/scenes/Player.tscn` — Precedente probado de integración 3D con `avatar.glb` (47 animaciones, `SkeletonProfileHumanoid`, frente en `+Z` rotado `PI`, `BoneAttachment3D` en `RightHand`/`LeftHand`).
- `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md` — Base de simulación de `Colonos.gd` y `ColonosRenderer.gd`.

---

## 2. Estructura de Carpetas y Convención de Assets 3D (`res://assets/personajes/`)

```text
godot/assets/personajes/
├── README.md                      # Guía rápida de convenciones y checklist drop-in
├── avatar/
│   ├── avatar.glb                 # ✅ Existente (Avatar masculino jugable)
│   └── avatar_f.glb               # ⏳ Futuro (Avatar femenino jugable)
├── base/
│   ├── cuerpo_m.glb               # ⏳ Futuro (Cuerpo base masculino humanoide)
│   └── cuerpo_f.glb               # ⏳ Futuro (Cuerpo base femenino humanoide)
├── animaciones/
│   └── humanoide_base.glb         # ⏳ Futuro (Biblioteca compartida opcional de clips NLA)
├── atuendos/                      # ⏳ Futuros: 1 por rango × 2 géneros
│   ├── ciudadano_m.glb / ciudadano_f.glb
│   ├── desempleado_m.glb / desempleado_f.glb
│   ├── obrero_m.glb / obrero_f.glb
│   ├── tecnico_m.glb / tecnico_f.glb
│   ├── especialista_m.glb / especialista_f.glb
│   ├── investigador_m.glb / investigador_f.glb
│   └── militar_m.glb / militar_f.glb
└── equipamiento/                  # ⏳ Futuros: accesorios rígidos válidos para M/F
    ├── martillo.glb
    ├── pico.glb
    ├── casco_minero.glb
    ├── hacha.glb
    ├── canasta_acarreo.glb
    ├── arco_caza.glb
    ├── cana_pesca.glb
    ├── gafas_industriales.glb
    ├── maletin_ciencia.glb
    ├── casco_militar.glb
    ├── espada.glb
    ├── escudo.glb
    └── arco.glb
```

### Estándar Técnico de Cada `.glb` (Compatible con `blender_godot_prepare.py`)
- **Altura normalizada:** `1.80 m` (coincide con `PersonajeModular.ALTURA_PLACEHOLDER` y `Player.tscn`).
- **Origen:** `(0, 0, 0)` exactamente en el suelo entre ambos pies.
- **Orientación de exportado:** frente mirando hacia **`+Z`** (idéntico a `avatar.glb` tras `blender_godot_prepare.py`), por lo que en Godot el nodo raíz visual se rota `rotation.y = PI` para mirar hacia `-Z` (hacia donde apunta la dirección de marcha calculada).
- **Esqueleto obligatorio en cuerpos base y atuendos riggeados:** `SkeletonProfileHumanoid` de Godot 4 (`Root`, `Hips`, `Spine`, `Chest`, `UpperChest`, `Neck`, `Head`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `RightUpperArm`, `RightLowerArm`, `RightHand`, piernas y pies).
- **Presupuesto geométrico para colonos (multitud):** `3,000 – 6,000` triángulos por personaje completo, texturas `512×512` o `1024×1024`.
- **Dos modos válidos para `atuendos/<rango>_<m|f>.glb`:**
  - **Modo A (Escena riggeada completa, recomendado para Hunyuan3D-2mv + UniRig):** El `.glb` del atuendo ya incluye malla + `Skeleton3D` humanoide + (opcional) `AnimationPlayer`. Es la ruta directa del pipeline `craft-character-3d`.
  - **Modo B (Malla skinned sin esqueleto propio):** Si un atuendo se exporta solo con `MeshInstance3D` skinneado al mismo bind pose humanoide de `cuerpo_<m|f>.glb`, `PersonajeModular.gd` lo detecta, instancia `base/cuerpo_<m|f>.glb` como raíz con esqueleto y reparenta los `MeshInstance3D` del atuendo debajo del `Skeleton3D` asignando `mesh.skeleton = NodePath("..")`.

---

## 3. Convención de Materiales y Paletas (`mat_piel` y `mat_color_equipo`)

Para variar tonos de piel y colores de equipo/facción **sin duplicar archivos `.glb`**:

1. **4 Tonos de Piel Decorativos (`Ajustes.TONOS_PIEL_COLONOS`):**
   | Índice | Clave (`Ajustes.NOMBRES_TONOS_PIEL`) | Hexadecimal | Uso |
   | :--- | :--- | :--- | :--- |
   | `0` | `palido` | `#f4d6c1` | Piel muy clara |
   | `1` | `claro` | `#e0b38f` | Piel clara (valor por defecto en `Ajustes.COLOR_PIEL_COLONO`) |
   | `2` | `moreno` | `#a8704a` | Piel morena |
   | `3` | `oscuro` | `#5c3a24` | Piel oscura |

2. **Paleta de Colores de Equipo (`Ajustes.COLORES_EQUIPO_PALETA`):**
   - `"azul_nacion"` (`#2d6cdf`, por defecto en `Ajustes.COLOR_EQUIPO_DEFECTO`)
   - `"rojo_carmesi"` (`#c93838`)
   - `"verde_bosque"` (`#2e8f57`)
   - `"dorado_real"` (`#d4a437`)
   - `"purpura_imperial"` (`#7d48b8`)
   - `"turquesa_costa"` (`#2299a8`)

3. **Regla de Nomenclatura de Materiales en Blender / glTF:**
   - Toda superficie de piel (rostro, cuello, manos, antebrazos descubiertos) debe tener un material cuyo nombre empiece por **`mat_piel`** (o **`skin`**, insensible a mayúsculas y tolerante a sufijos `.001` de Blender).
   - Toda zona distintiva de facción/equipo (brazalete, pañuelo, ribete, hombrera, penacho o escudo) debe tener un material cuyo nombre empiece por **`mat_color_equipo`** (o **`team_color`**, igualmente tolerante a sufijos).
   - `CatalogoPersonajes.aplicar_materiales_identidad(raiz, tono_piel, color_equipo)` recorre los `MeshInstance3D` de `raiz`, clona el `StandardMaterial3D` base preservando textura albedo/normal/roughness y ajusta `albedo_color` mediante caché compartido por `(material_id, tono_o_color)`. De este modo una textura gris/blanca en el slot de equipo se tiñe limpiamente sin crear un material único por cada ciudadano.

---

## 4. Modelo de Datos e Identidad Persistente

### 4.1 `Colonos.gd`
Cada entrada en `Colonos.colonos[id]` incorpora 4 campos persistentes:

| Campo | Tipo | Valores válidos | Origen / Ciclo de vida |
| :--- | :--- | :--- | :--- |
| `"genero"` | `String` | `"M"`, `"F"` | Asignado en `agregar_colono()` (aleatorio 50/50 salvo parámetro `identidad`). **Inmutable** ante ascensos, graduaciones, alistamiento o desempleo. |
| `"tono_piel"` | `int` | `0..3` | Asignado aleatoriamente en `agregar_colono()` (salvo `identidad`). **Inmutable** durante toda la vida del colono. |
| `"equipo_id"` | `String` | `"jugador"` (futuros `"enemigo_*"`, etc.) | Asignado en `agregar_colono()` (por defecto `"jugador"`). |
| `"orientacion_y"` | `float` | Radianes (`atan2(dx, dz)`) | Actualizado en `_completar_paso()` según el vector de desplazamiento horizontal hacia la celda siguiente. |

- **Firma ampliada:** `agregar_colono(tipo: String, celda: Vector3i, hogar: int = -1, identidad: Dictionary = {}) -> int` — 100% compatible con llamadas existentes de 3 argumentos.
- **Retrocompatibilidad en `importar_estado(d)`:** Si un archivo `.json` guardado anteriormente carece de estos campos, `Colonos.importar_estado()` asigna de forma determinista por `cid`:
  - `genero`: `"M"` si `cid % 2 == 0` else `"F"`
  - `tono_piel`: `posmod(cid, TONOS_PIEL_COLONOS.size())`
  - `equipo_id`: `"jugador"`
  - `orientacion_y`: `0.0`

### 4.2 `Ciudad.gd` y `GestorPartida.gd`
`Ciudad.gd` expone y persiste:
- `genero_avatar: String = "M"`
- `tono_piel_avatar: int = 1`
- `color_equipo: Color = Ajustes.COLOR_EQUIPO_DEFECTO`
- `colores_equipos: Dictionary = {"jugador": Ajustes.COLOR_EQUIPO_DEFECTO}`
- `ultimo_resultado_sucesion: Dictionary = {}`
- Helpers públicos: `establecer_color_equipo(color)`, `registrar_color_equipo(equipo_id, color)`, `color_de_equipo(equipo_id)`.
- `Ciudad.exportar_estado()` serializa los colores como cadenas hexadecimales (`"#" + col.to_html(false)`) junto con `genero_avatar` y `tono_piel_avatar`, y `Ciudad.importar_estado()` restaura valores seguros si el guardado es anterior.

---

## 5. Regla de Género en Elecciones / Sucesión del Avatar y Seguro Anti-Bloqueo

- **Tono de piel:** Puramente decorativo; no restringe empleos, rendimiento ni elegibilidad. Al ocurrir una sucesión real, el nuevo avatar adopta el `tono_piel` del candidato elegido.
- **Filtro de género en `Ciudad.suceder_avatar(colonos_ref = null)`:**
  1. Si `censo_total == 0` → `"game_over"`.
  2. Si `demografia["militar"] <= 0` → `"sin_sucesor_elegible"`.
  3. Si se pasa `colonos_ref` (como hace `Player._ejecutar_sucesion()` pasando `Colonos`):
     - Invoca `Colonos.consumir_sucesor_para_avatar(genero_avatar, "militar")`.
     - **Caso normal:** Existe al menos un militar en `Colonos.colonos` con `c["genero"] == genero_avatar`. Se elige al de mayor `salud` (desempate por menor `id`), se retira de `Colonos`, se descuenta 1 de `demografia["militar"]` y se registra `origen = "candidato_mismo_genero"`.
     - **Seguro anti-bloqueo:** Si `demografia["militar"] > 0` pero hay `0` militares vivos del mismo género `genero_avatar` (por ejemplo, todos los reclutados al azar resultaron del género opuesto en una colonia pequeña):
       - Para mantener la paridad exacta con `demografia["militar"] -= 1`, retira un militar de respaldo (si existe) y toma el `tono_piel` de un ciudadano del género correcto (o aleatorio `0..3`), manteniendo `Ciudad.genero_avatar` intacto y devolviendo `"sucesion_exitosa"` con `origen = "relevo_nucleo_antibloqueo"`.
       - De este modo **ninguna partida se bloquea nunca por azar demográfico**.

---

## 6. Arquitectura Visual en 2 Capas y Fallback Progresivo

Para evitar crear $7 \times 2 \times 21 \times 4 = 1,176+$ combinaciones estáticas, la representación de cada ciudadano se divide en:

### 6.1 Capa 1 — Atuendo Base por Rango (`CatalogoPersonajes.resolver_modelo_capa1`)
Dada `(rango, genero)` (`rango` ∈ `ciudadano`, `desempleado`, `obrero`, `tecnico`, `especialista`, `investigador`, `militar`; `genero` ∈ `M`, `F`):
1. Si existe `res://assets/personajes/atuendos/<rango>_<m|f>.glb` → **`modo = "atuendo"`** (Modo A si tiene `Skeleton3D`; Modo B acoplado a `base/cuerpo_<m|f>.glb` si es solo malla).
2. Si no, si existe `res://assets/personajes/base/cuerpo_<m|f>.glb` → **`modo = "base"`** (fallback al cuerpo humanoide neutro mientras llega ese atuendo concreto).
3. Si no existe ninguno → **`modo = "placeholder"`** (cápsula clásica de `ColonosRenderer` teñida por `Ajustes.COLORES_COLONOS[rango]`, añadiendo un nodo hijo `DistintivoEquipo` —banda cilíndrica en el torso— teñido con `color_equipo`).

### 6.2 Capa 2 — Equipamiento Modular por Oficio (`CatalogoPersonajes.resolver_equipamiento`)
Piezas rígidas instanciadas dinámicamente como hijas de `BoneAttachment3D` sobre `Head`, `Chest` (fallback `UpperChest`/`Spine`), `RightHand` y `LeftHand`:

| Contexto del colono (orden de prioridad) | `Head` | `Chest` | `RightHand` | `LeftHand` |
| :--- | :--- | :--- | :--- | :--- |
| **`tipo == "militar"` (infantería)** | `casco_militar` | — | `espada` | `escudo` |
| **`tipo == "militar"` (`subtipo_militar == "arquero"`)** | `casco_militar` | — | — | `arco` |
| **`tarea.tipo == "investigador_itinerante"`** | — | — | — | `maletin_ciencia` |
| **`not tarea.is_empty()` (obras / demolición / vías)** | — | — | `martillo` | — |
| **`trabajo.rol == "acarreador"`** | — | `canasta_acarreo` | — | — |
| **Puesto: `mina`** | `casco_minero` | — | `pico` | — |
| **Puesto: `centro_extraccion`** | `casco_minero` | — | `martillo` | — |
| **Puesto: `maderero`, `aserradero`** | — | — | `hacha` | — |
| **Puesto: `caza_recoleccion`** | — | — | — | `arco_caza` |
| **Puesto: `pesca_frutos_mar`** | — | — | `cana_pesca` | — |
| **Puestos industriales/refinerías (`siderurgica`, `refineria_tierras_raras`, `fabrica_bloques`, `vidriera`, `carbonera`, `refineria_petrolera`, `productor_combustible`, `central_termoelectrica`, `estacion_bombeo`, `taller_transporte`)** | `gafas_industriales` | — | `martillo` | — |
| **Formación/ciencia (`escuela_tecnica`, `escuela_especialistas`, `universidad`)** | — | — | — | `maletin_ciencia` |
| **Puesto: `cuartel`** | `casco_militar` | — | — | — |
| **Puesto: `almacen`** | — | `canasta_acarreo` | — | — |
| **Desempleado / ocioso sin tarea** | — | — | — | — |

### 6.3 Integración en Escena (`ColonosRenderer.gd`, `AvatarAnimador.gd`, `Player.gd`)
- **`ColonosRenderer.gd`:** Cada colono conserva su `AnimatableBody3D` (`collision_layer = 2`) y añade un hijo `PersonajeModular` (responsable de Capa 1 + materiales de identidad + Capa 2 + orientación + animación básica `Idle`/`Walking`/`Mining_Swing`).
  - Los nodos procedurales existentes `CascoMilitar` y `EscudoMilitar` se mantienen como hijos del `AnimatableBody3D`, pero **solo son visibles cuando `es_militar and modular.modo_visual() == "placeholder"`**: en cuanto exista el `.glb` 3D del soldado/base, ceden su lugar a las piezas en `BoneAttachment3D`.
  - `AroSeleccion` y `_marcadores_ordenes` permanecen sin cambios visuales.
- **Dirty-checking por firma:** `PersonajeModular` guarda `_firma_capa1`, `_firma_identidad` y `_firma_capa2` y solo reconstruye nodos o reasigna materiales cuando algo cambia realmente, evitando asignaciones por frame en `_physics_process`.
  - `ponytail:` Un `Node3D` (`PersonajeModular`) por colono con `PackedScene` y materiales cacheados escala cómodamente a decenas/centenas de colonos; si la población creciera a miles simultáneos visibles, añadir LOD de distancia o instanciado `MultiMesh` por rango.
- **`AvatarAnimador.gd` y `Player.gd`:**
  - Al iniciar (`Player._ready()`) y tras cada sucesión (`Player._ejecutar_sucesion()`), `Player` sincroniza `Ciudad.tono_piel_avatar` y `Ciudad.color_equipo` sobre `AvatarAnimador.aplicar_identidad_visual(...)`.
  - Al entrar/salir del modo Batalla (`R`) o cambiar de arma (`espada`/`arco`), `Player._sincronizar_equipamiento_avatar()` llama a `_animador.equipar_en_mano(...)` sobre `RightHand`/`LeftHand`; mientras `espada.glb`/`arco.glb` no existan en disco, es un no-op seguro.

---

## 7. Integración con el Pipeline 3D (`craft-character-3d`)

Cuando el usuario cree nuevos assets usando `.agents/skills/craft-character-3d/SKILL.md`:
1. **Cuerpos base (`base/cuerpo_m.glb`, `base/cuerpo_f.glb`):**
   - Generar con `modal_hunyuan_rig.py --target-faces 15000` + `blender_godot_prepare.py --height 1.80 --force-decimate 5500 --head-protect-fraction 0.22 --max-tex 512`.
   - En Blender (CLI o `blender-mcp`), asignar el slot de material de la piel con nombre `mat_piel` antes de exportar a `godot/assets/personajes/base/cuerpo_<m|f>.glb`.
2. **Atuendos por rango (`atuendos/<rango>_<m|f>.glb`):**
   - Usar la paleta cromática de `Ajustes.COLORES_COLONOS` para mantener legibilidad desde cámara cenital.
   - Incluir un brazalete/pañuelo/ribete con material `mat_color_equipo` y marcar la piel visible con `mat_piel`.
3. **Equipamiento (`equipamiento/<pieza>.glb`):**
   - Objetos rígidos centrados en su punto de agarre (p. ej. empuñadura para `RightHand`/`LeftHand`, base interior del casco para `Head`, cara frontal para `Chest`), escala en metros reales.
4. **Animaciones compartidas (`animaciones/humanoide_base.glb`):**
   - Biblioteca opcional generada desde `tools/3d_pipeline/mixamo_library/` con `Idle`, `Walking`, `Mining_Swing` sobre `SkeletonProfileHumanoid`.

---

## 8. Futuras Extensiones (Fuera del Alcance Actual)
- Selector interactivo en `MenuInicio.gd` ("Nueva Partida") para escoger género inicial, tono de piel inicial y color de nación/equipo.
- Carga automática de `avatar_f.glb` en `Player.gd` cuando `Ciudad.genero_avatar == "F"`.
- Equipamiento diferenciado por Era (`era_actual` 1–4, p. ej. arco → rifle → visor/exoesqueleto).
- Animaciones específicas de acarreo, minado, tala, arquería y escudo para colonos NPC.

---

## 9. Criterios de Aceptación y Plan de Pruebas

1. **Identidad y Serialización (`PersonajeModularTest`, `GestorPartidaTest`):**
   - Todo colono creado recibe `genero` ∈ `{"M","F"}`, `tono_piel` ∈ `[0..3]`, `equipo_id` e `orientacion_y`.
   - Cambiar de rango/empleo no muta ni `genero` ni `tono_piel`.
   - Guardar y cargar restaura identidad de colonos, `Ciudad.genero_avatar`, `Ciudad.tono_piel_avatar`, `Ciudad.color_equipo` y `Ciudad.colores_equipos`; los guardados legacy sin esas claves se migran limpiamente al importar.
2. **Resolución Modular y Materiales (`PersonajeModularTest`):**
   - `CatalogoPersonajes.resolver_modelo_capa1()` respeta la prioridad `atuendo` → `base` → `placeholder`.
   - `CatalogoPersonajes.resolver_equipamiento()` devuelve las piezas exactas para obra, acarreo, mina, maderero, caza, pesca, refinería, investigador itinerante y militar.
   - `CatalogoPersonajes.aplicar_materiales_identidad()` tiñe `mat_piel*` según el índice `0..3` y `mat_color_equipo*` según el color de equipo con caché compartido.
   - Sin `.glb` presentes, `ColonosRenderer` sigue pasando íntegramente `PlayerCombateComandanteTest` (`CascoMilitar`, `EscudoMilitar`, `AroSeleccion`) y muestra además `DistintivoEquipo`.
3. **Sucesión con Género y Seguro Anti-Bloqueo (`PersonajeModularTest`, `CiudadTest`):**
   - Avatar `"M"` elige candidato `"M"` aunque haya `"F"` disponibles (y viceversa).
   - Con `demografia["militar"] > 0` y `0` militares del mismo género, el seguro anti-bloqueo resuelve `"sucesion_exitosa"` sin bloquear ni corromper el censo.
4. **Regresión Cero:**
   - La suite completa ejecutada con `pwsh -File tools/run-godot-tests.ps1` (incluyendo `PersonajeModularTest.tscn`, **39 escenas en total**) pasa al 100% sin errores de parser ni runtime.
