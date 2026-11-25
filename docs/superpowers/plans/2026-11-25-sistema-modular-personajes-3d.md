# Sistema Modular de Personajes 3D — Plan de Implementación

> **For agentic workers:** REQUIRED: Use subagent-driven-development (if subagents available) or executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar la arquitectura modular plug-and-play de personajes 3D (2 cuerpos base M/F, 4 tonos de piel, 2 capas rango + equipamiento por oficio, color de equipo y regla de género en sucesión con seguro anti-bloqueo) conservando fallbacks automáticos a placeholders mientras los assets `.glb` se van añadiendo.

**Architecture:** Se introducen dos módulos puros desacoplados (`CatalogoPersonajes.gd` para resolución de rutas/slots/equipamiento y caché de materiales `mat_piel`/`mat_color_equipo`, y `PersonajeModular.gd` como nodo visual con dirty-checking dentro de `ColonosRenderer.gd`). Los datos persistentes viven en `Colonos.gd` (`genero`, `tono_piel`, `equipo_id`, `orientacion_y`) y `Ciudad.gd` (`genero_avatar`, `tono_piel_avatar`, `color_equipo`, `colores_equipos`, sucesión filtrada por género), sincronizados con `GestorPartida.gd`, `AvatarAnimador.gd` y `Player.gd`. Sin `.glb` nuevos en disco, todo colono renderiza su cápsula + distintivo de equipo + casco/escudo militar existente sin romper ninguna escena previa.

**Tech Stack:** Godot 4.7 / GDScript 2.0, `SkeletonProfileHumanoid`, `BoneAttachment3D`, `StandardMaterial3D`, PowerShell test runner (`tools/run-godot-tests.ps1`).

**Spec:** [2026-11-25-sistema-modular-personajes-3d-design.md](file:///c:/Users/peraz/Projects/Misc/CityCraft/docs/superpowers/specs/2026-11-25-sistema-modular-personajes-3d-design.md)

---

### Global Constraints
- Mantener compatibilidad estricta con las 38 escenas de prueba existentes (`tools/run-godot-tests.ps1`), en especial `PlayerCombateComandanteTest.gd` (`CascoMilitar`, `EscudoMilitar`, `AroSeleccion` como hijos del `AnimatableBody3D` cuando `modo_visual() == "placeholder"`), `CiudadTest.gd` y `GestorPartidaTest.gd`.
- Respetar el patrón del proyecto: autoloads sin `class_name` y scripts cargados mediante `preload("res://scripts/...")` para evitar el bug de caché de clases globales en headless.
- Cero errores o warnings nuevos en Godot headless (`SCRIPT ERROR`, `ERROR:`, `Parse Error`, `Assertion failed`).
- Mantener la filosofía **Ponytail**: caché simple de `PackedScene`/`StandardMaterial3D` y dirty-checking por firma; documentar optimización futura de miles de NPCs con comentario `ponytail:`.

### Execution Lines & Dependency Matrix
| Task | Depende de | Archivos principales | Paralelizable |
| :--- | :--- | :--- | :--- |
| Task 1: Constantes y guía de assets | — | `godot/scripts/ajustes.gd`, `godot/assets/personajes/README.md` | Sí |
| Task 2: `CatalogoPersonajes.gd` y `PersonajeModular.gd` | Task 1 | `godot/scripts/CatalogoPersonajes.gd`, `godot/scripts/PersonajeModular.gd` | No |
| Task 3: Identidad persistente y Sucesión | Task 1–2 | `godot/scripts/Colonos.gd`, `godot/scripts/Ciudad.gd` | Sí (con Task 4 tras Task 2) |
| Task 4: Integración visual (`ColonosRenderer`, `AvatarAnimador`, `Player`) | Task 2–3 | `godot/scripts/ColonosRenderer.gd`, `godot/scripts/AvatarAnimador.gd`, `godot/scripts/Player.gd` | No |
| Task 5: Suite de pruebas y persistencia | Task 3–4 | `godot/scripts/PersonajeModularTest.gd`, `godot/scenes/PersonajeModularTest.tscn`, `godot/scripts/GestorPartidaTest.gd`, `tools/run-godot-tests.ps1` | No |
| Task 6: Importación y verificación total (39 escenas) | Task 5 | Suite completa Godot headless | No |

### Review Focus
1. **Retrocompatibilidad de saves antiguos:** verificar que `Colonos.importar_estado()` y `Ciudad.importar_estado()` migren partidas previas sin campos `genero`/`tono_piel`/`equipo_id`/`color_equipo` sin fallos de tipos estrictos (`Variant` vs `int`/`Color`).
2. **Preservación de contratos militares existentes:** en modo `placeholder`, `CascoMilitar`, `EscudoMilitar` y `AroSeleccion` deben seguir siendo hijos directos de `AnimatableBody3D` con idénticos nombres y visibilidad para `PlayerCombateComandanteTest.gd`.
3. **Seguro anti-bloqueo en sucesión:** comprobar que `Ciudad.suceder_avatar(Colonos)` nunca devuelva `"sin_sucesor_elegible"` mientras `demografia["militar"] > 0`, aun cuando todos los militares disponibles sean del género contrario al avatar.

### Interfaces & Contracts
- `CatalogoPersonajes.resolver_modelo_capa1(rango: String, genero: String, existe_fn: Callable = Callable()) -> Dictionary` (`{"modo": "atuendo"|"base"|"placeholder", "ruta_atuendo": String, "ruta_base": String}`)
- `CatalogoPersonajes.resolver_equipamiento(colono: Dictionary, tipo_puesto: String = "", era: int = 1) -> Dictionary` (`slot -> pieza_id`)
- `CatalogoPersonajes.aplicar_materiales_identidad(raiz: Node, tono_piel: int, color_equipo: Color) -> Dictionary` (`{"piel": int, "equipo": int}`)
- `PersonajeModular.actualizar_colono(colono: Dictionary, tipo_puesto: String, color_equipo: Color, era: int = 1) -> void`
- `Colonos.agregar_colono(tipo: String, celda: Vector3i, hogar: int = -1, identidad: Dictionary = {}) -> int`
- `Colonos.consumir_sucesor_para_avatar(genero_avatar: String, tipo_preferido: String = "militar") -> Dictionary`
- `Ciudad.suceder_avatar(colonos_ref: Object = null) -> String`
- `AvatarAnimador.aplicar_identidad_visual(tono_piel: int, color_equipo: Color) -> Dictionary`
- `AvatarAnimador.equipar_en_mano(lado: String, pieza_id: String, tono_piel: int = 1, color_equipo: Color = Ajustes.COLOR_EQUIPO_DEFECTO) -> bool`

---

### Task 1: Constantes en `ajustes.gd` y guía drop-in de assets

**Files:**
- Modify: `godot/scripts/ajustes.gd`
- Create: `godot/assets/personajes/README.md`

- [ ] **Step 1:** Añadir en `godot/scripts/ajustes.gd` (justo debajo de `COLORES_COLONOS` / `COLOR_CARGA_DEFECTO`) las constantes `TONOS_PIEL_COLONOS`, `NOMBRES_TONOS_PIEL`, `GENEROS_VALIDOS`, `COLORES_EQUIPO_PALETA` y `COLOR_EQUIPO_DEFECTO`:
```gdscript
static var TONOS_PIEL_COLONOS: Array[Color] = [
	Color("#f4d6c1"),  # 0: pálido
	Color("#e0b38f"),  # 1: claro
	Color("#a8704a"),  # 2: moreno
	Color("#5c3a24"),  # 3: oscuro
]
static var NOMBRES_TONOS_PIEL: Array[String] = ["palido", "claro", "moreno", "oscuro"]
static var GENEROS_VALIDOS: Array[String] = ["M", "F"]
static var COLORES_EQUIPO_PALETA: Dictionary = {
	"azul_nacion": Color("#2d6cdf"),
	"rojo_carmesi": Color("#c93838"),
	"verde_bosque": Color("#2e8f57"),
	"dorado_real": Color("#d4a437"),
	"purpura_imperial": Color("#7d48b8"),
	"turquesa_costa": Color("#2299a8"),
}
static var COLOR_EQUIPO_DEFECTO: Color = Color("#2d6cdf")
```
- [ ] **Step 2:** Crear `godot/assets/personajes/README.md` documentando la estructura `base/`, `atuendos/`, `equipamiento/`, `animaciones/` y `avatar/`, junto con las reglas de huesos (`SkeletonProfileHumanoid`, `Head`, `Chest`, `RightHand`, `LeftHand`) y materiales (`mat_piel`, `mat_color_equipo`).

---

### Task 2: Catálogo y nodo visual modular (`CatalogoPersonajes.gd` + `PersonajeModular.gd`)

**Files:**
- Create: `godot/scripts/CatalogoPersonajes.gd`
- Create: `godot/scripts/PersonajeModular.gd`

- [ ] **Step 1:** Crear `godot/scripts/CatalogoPersonajes.gd` (`extends RefCounted`) con:
  - Rutas base y mapa `SLOTS_HUESO` (`Head`, `Chest`, `RightHand`, `LeftHand`).
  - Helpers puros `normalizar_genero`, `sufijo_genero`, `normalizar_tono_piel`, `color_piel`.
  - Resolución Capa 1 (`resolver_modelo_capa1`) y Capa 2 (`resolver_ruta_equipamiento`, `resolver_equipamiento` cubriendo los 21 puestos, obras, investigador itinerante y militar).
  - Caché estático de escenas, biblioteca de animaciones opcional (`humanoide_base.glb`) y materiales (`obtener_material_piel`, `obtener_material_equipo`, `aplicar_materiales_identidad`, `buscar_nodo_por_clase`, `limpiar_caches`).
- [ ] **Step 2:** Crear `godot/scripts/PersonajeModular.gd` (`extends Node3D`) con:
  - Gestión completa de los 3 modos (`"atuendo"`, `"base"`, `"placeholder"`), soporte Modo A (esqueleto propio) y Modo B (reparenado al `Skeleton3D` base).
  - Dirty-checking por firma (`_firma_capa1`, `_firma_identidad`, `_firma_capa2`).
  - Instanciación de `BoneAttachment3D` por slot y acoplamiento dinámico de piezas de `equipamiento/<pieza>.glb`.
  - Fallback placeholder con `CapsuleMesh` (0.3×1.8) + `DistintivoEquipo` (`CylinderMesh` teñido con `color_equipo`).
  - Rotación `rotation.y` según `orientacion_y` y reproducción segura de animaciones NPC (`Idle`, `Walking`, `Mining_Swing`) cuando existan en el modelo.

---

### Task 3: Identidad persistente y Sucesión por género (`Colonos.gd` + `Ciudad.gd`)

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/Ciudad.gd`

- [ ] **Step 1:** En `godot/scripts/Colonos.gd`:
  - Precargar `CatalogoPersonajes = preload("res://scripts/CatalogoPersonajes.gd")`.
  - Extender `agregar_colono(tipo, celda, hogar = -1, identidad = {})` asignando `"genero"`, `"tono_piel"`, `"equipo_id"` y `"orientacion_y"`.
  - Actualizar `"orientacion_y"` en `_completar_paso()` a partir del desplazamiento XZ.
  - Migrar saves legacy sin esos campos en `importar_estado()`.
  - Añadir `elegir_candidato_sucesion(genero_avatar, tipo_preferido)` y `consumir_sucesor_para_avatar(genero_avatar, tipo_preferido)` aplicando el filtro por género y el seguro anti-bloqueo cuando hay `0` militares de ese género.
- [ ] **Step 2:** En `godot/scripts/Ciudad.gd`:
  - Añadir `genero_avatar`, `tono_piel_avatar`, `color_equipo`, `colores_equipos`, `ultimo_resultado_sucesion` y restablecerlos en `reiniciar()`.
  - Añadir `establecer_color_equipo()`, `registrar_color_equipo()`, `color_de_equipo()`.
  - Ampliar `suceder_avatar(colonos_ref = null)` para seleccionar sucesor vía `Colonos` respetando el género del avatar y preservando el retorno de `"game_over"` / `"sin_sucesor_elegible"` / `"sucesion_exitosa"`.
  - Persistir/restaurar los nuevos campos en `exportar_estado()` y `importar_estado()`.

---

### Task 4: Integración en `ColonosRenderer.gd`, `AvatarAnimador.gd` y `Player.gd`

**Files:**
- Modify: `godot/scripts/ColonosRenderer.gd`
- Modify: `godot/scripts/AvatarAnimador.gd`
- Modify: `godot/scripts/Player.gd`

- [ ] **Step 1:** Refactorizar `godot/scripts/ColonosRenderer.gd` para usar `PersonajeModular` dentro de cada `AnimatableBody3D` (con `_modulares[id]`), manteniendo `CascoMilitar`, `EscudoMilitar` y `AroSeleccion` compatibles en modo `"placeholder"` y ocultando automáticamente los dos primeros cuando un modelo 3D real sustituya al placeholder.
- [ ] **Step 2:** En `godot/scripts/AvatarAnimador.gd`, añadir `aplicar_identidad_visual(tono_piel, color_equipo)` y `equipar_en_mano(lado, pieza_id, tono_piel, color_equipo)` sobre `RightHand`/`LeftHand` usando `CatalogoPersonajes`.
- [ ] **Step 3:** En `godot/scripts/Player.gd`, aplicar identidad inicial en `_ready()`, delegar la sucesión con `Ciudad.suceder_avatar(Colonos)` actualizando el aspecto tras el relevo, y añadir `_sincronizar_equipamiento_avatar()` en cambios de modo/arma.

---

### Task 5: Suite de pruebas `PersonajeModularTest` y cobertura en `GestorPartidaTest`

**Files:**
- Create: `godot/scripts/PersonajeModularTest.gd`
- Create: `godot/scenes/PersonajeModularTest.tscn`
- Modify: `godot/scripts/GestorPartidaTest.gd`
- Modify: `tools/run-godot-tests.ps1`

- [ ] **Step 1:** Crear `PersonajeModularTest.gd` y `PersonajeModularTest.tscn` cubriendo:
  - Identidad aleatoria/explícita, inmutabilidad tras cambios de rango y migración de saves antiguos.
  - Resolución Capa 1 (`atuendo` → `base` → `placeholder`) y Capa 2 (todos los oficios principales + militar).
  - Teñido de superficies sintéticas `mat_piel` y `mat_color_equipo.001` en `CatalogoPersonajes.aplicar_materiales_identidad()`.
  - `ColonosRenderer` + `PersonajeModular` ante transiciones de rol (`desempleado` → `tecnico` en `mina` → `militar`) y color de equipo.
  - Sucesión por género (`M` vs `F`) y seguro anti-bloqueo sin candidatos militares del mismo género.
  - Métodos `aplicar_identidad_visual()` y `equipar_en_mano()` en `AvatarAnimador` sobre `Player.tscn`.
- [ ] **Step 2:** Añadir `test_persistencia_identidad_personajes_y_equipo()` en `godot/scripts/GestorPartidaTest.gd` verificando round-trip JSON de identidad de colonos, avatar y colores de equipo.
- [ ] **Step 3:** Registrar `"PersonajeModularTest.tscn"` en `$expectedScenes` dentro de `tools/run-godot-tests.ps1`.

---

### Task 6: Importación y verificación en Godot Headless

- [ ] **Step 1:** Ejecutar importación headless si hay recursos/escenas nuevos:
```powershell
& "C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path godot --import --quit
```
- [ ] **Step 2:** Ejecutar la suite completa:
```powershell
pwsh -File tools/run-godot-tests.ps1
```
- [ ] **Step 3:** Confirmar salida exacta: `Las 39 escenas de prueba pasaron sin errores.` y 0 errores de script o parser.
