---
name: craft-character-3d
description: Pipeline hibrido Multi-View Image-to-3D (Hunyuan3D-2mv + UniRig en Modal y Blender CLI/MCP local) adaptado a la arquitectura modular drop-in de Craft to Nation (Godot 4) para crear Avatar, cuerpos base, atuendos Capa 1, props rigidos Capa 2, animaciones Mixamo y blendshapes ARKit/Lip-Sync, asi como para corregir y mejorar modelos existentes.
---

# Skill: Pipeline Modular de Personajes 3D para *Craft to Nation* (`craft-character-3d`)

Esta skill define el flujo oficial para crear, ensamblar, animar y perfeccionar los assets 3D modulares (`.glb`) de **Craft to Nation** en **Godot 4** (`godot/assets/personajes/`), alineado con `CatalogoPersonajes.gd`, `PersonajeModular.gd`, `AvatarAnimador.gd`, `ColonosRenderer.gd` y `ajustes.gd`.

---

## 1. Arquitectura Modular Drop-In, Presupuestos y Reglas de Hardware

- **GPU Local:** RTX 3050 (4 GB VRAM). **NUNCA** ejecutar inferencia neural 3D ni auto-rigging en local. Toda inferencia pesada corre en **Modal** (perfil `gigalipa`, entorno `-e crafttonation`) con caché persistente en el volumen `hunyuan-unirig-cache`.
- **Blender Local:** `C:\Program Files\Blender Foundation\Blender 5.3\blender.exe` en modo `--background` (headless) para post-procesado determinista, y opcionalmente **Blender MCP (`blender-mcp`)** para retoques visuales interactivos.

### Estructura de Carpetas Plug-and-Play (`godot/assets/personajes/`)
El motor carga automáticamente los `.glb` colocados en estas rutas sin editar GDScript:

```text
godot/assets/personajes/
├── avatar/
│   ├── avatar.glb                 # Avatar masculino jugable (existente)
│   └── avatar_f.glb               # Avatar femenino jugable
├── base/
│   ├── cuerpo_m.glb               # Cuerpo base masculino (fallback Capa 1 + esqueleto Modo B)
│   └── cuerpo_f.glb               # Cuerpo base femenino (fallback Capa 1 + esqueleto Modo B)
├── animaciones/
│   └── humanoide_base.glb         # 8 clips canónicos compartidos para colonos
├── atuendos/                      # Capa 1: <rango>_<m|f>.glb (14 variantes)
│   ├── ciudadano_m.glb / ciudadano_f.glb
│   ├── desempleado_m.glb / desempleado_f.glb
│   ├── obrero_m.glb / obrero_f.glb
│   ├── tecnico_m.glb / tecnico_f.glb
│   ├── especialista_m.glb / especialista_f.glb
│   ├── investigador_m.glb / investigador_f.glb
│   └── militar_m.glb / militar_f.glb
└── equipamiento/                  # Capa 2: <pieza>.glb (props rígidos sin rig, compartidos M/F)
    ├── martillo.glb / pico.glb / hacha.glb / cana_pesca.glb / espada.glb
    ├── arco_caza.glb / maletin_ciencia.glb / escudo.glb / arco.glb
    ├── casco_minero.glb / gafas_industriales.glb / casco_militar.glb
    └── canasta_acarreo.glb
```

### Matriz de los 5 Tipos de Asset
| Tipo de Asset | Ruta Exacta en Godot 4 | Rig / Esqueleto | Presupuesto Triángulos / Textura | Blendshapes / Animaciones |
| :--- | :--- | :--- | :--- | :--- |
| **Avatar Jugable** (`M`/`F`) | `avatar/avatar.glb`, `avatar/avatar_f.glb` | `SkeletonProfileHumanoid` (`Head` + `Neck` obligatorios para `_OcultarCabezaModifier` en 1ª persona, + `RightHand`, `LeftHand`) | `8,000 – 12,000` tris (`--target-faces 25000` Modal + `--force-decimate 11500` Blender), `1024×1024`, `1.80 m` | `arkit52` + clips completos de `AvatarAnimador.gd` |
| **Cuerpo Base** (`M`/`F`) | `base/cuerpo_m.glb`, `base/cuerpo_f.glb` | `SkeletonProfileHumanoid` (`Head`, `Chest`/`UpperChest`/`Spine`, `RightHand`, `LeftHand`) | `3,000 – 6,000` tris (`--target-faces 15000` Modal + `--force-decimate 5500` Blender), `512` o `1024`, `1.80 m` | `lipsync` (18 shapes) + clips básicos opcionales |
| **Atuendos Capa 1** (`<rango>_<m\|f>`) | `atuendos/<rango>_<m\|f>.glb` | Modo A: riggeado autónomo con `SkeletonProfileHumanoid` (`Head`, `Chest`/`UpperChest`/`Spine`, `RightHand`, `LeftHand`) | `3,000 – 6,000` tris (`--target-faces 15000` Modal + `--force-decimate 5500` Blender), `512` o `1024`, `1.80 m` | `lipsync` (18 shapes); hereda `humanoide_base.glb` |
| **Equipamiento Capa 2** (`<pieza>`) | `equipamiento/<pieza>.glb` | **SIN RIG (`--skip-rig`)** — malla rígida estática con pivote en `(0,0,0)` según slot | `300 – 1,500` tris (`--target-faces 1500` Modal + `--target-tris 1000` Blender), `256` o `512` | Ninguno |
| **Biblioteca Animaciones** | `animaciones/humanoide_base.glb` | `SkeletonProfileHumanoid` con `AnimationPlayer` | Malla mínima / base | `Idle`, `Walking`, `Hauler_Box_Idle`, `Hauler_Carry`, `Fishing_Cast`, `Mining_Dig`, `Heavy_Swing`, `Work_Table` |

### Catálogo Oficial de Equipamiento Rígido Capa 2 (`equipamiento/<pieza>.glb`)
| Archivo | Slot (`BoneAttachment3D`) | Tamaño (`--size`) | Oficio / Puesto (`CatalogoPersonajes.gd`) |
| :--- | :--- | :--- | :--- |
| `martillo.glb` | `RightHand` | `0.45 m` | Construcción general, `centro_extraccion`, refinerías/fábricas |
| `pico.glb` | `RightHand` | `0.68 m` | `mina` |
| `hacha.glb` | `RightHand` | `0.65 m` | `maderero`, `aserradero` |
| `cana_pesca.glb` | `RightHand` | `1.35 m` | `pesca_frutos_mar` |
| `espada.glb` | `RightHand` | `0.85 m` | `militar` (infantería), Avatar en modo batalla |
| `arco_caza.glb` | `LeftHand` | `0.95 m` | `caza_recoleccion` |
| `maletin_ciencia.glb` | `LeftHand` | `0.40 m` | `escuela_tecnica`, `escuela_especialistas`, `universidad`, `investigador_itinerante` |
| `escudo.glb` | `LeftHand` | `0.65 m` | `militar` (infantería) |
| `arco.glb` | `LeftHand` | `1.05 m` | `militar` (`arquero`), Avatar en modo batalla |
| `casco_minero.glb` | `Head` | `0.27 m` | `mina`, `centro_extraccion` |
| `gafas_industriales.glb` | `Head` | `0.22 m` | `siderurgica`, `refineria_*`, `fabrica_bloques`, `vidriera`, `carbonera`, `central_termoelectrica`, `estacion_bombeo`, `taller_transporte` |
| `casco_militar.glb` | `Head` | `0.27 m` | `militar`, `cuartel` |
| `canasta_acarreo.glb` | `Chest` | `0.45 m` | `acarreador`, `almacen` |

### Materiales Dinámicos de Identidad (`CatalogoPersonajes.aplicar_materiales_identidad`)
- **Piel variable (4 tonos automáticos en `ajustes.gd` → `#f4d6c1`, `#e0b38f`, `#a8704a`, `#5c3a24`):** nombrar el slot de material en Blender comenzando por **`mat_piel`** (o `skin`).
- **Color de equipo/facción (6 paletas en `ajustes.gd` → `azul_nacion`, `rojo_carmesi`, `verde_bosque`, `dorado_real`, `purpura_imperial`, `turquesa_costa`):** nombrar el slot de material comenzando por **`mat_color_equipo`** (o `team_color`), usando base blanca/neutra clara para que el tinte en tiempo real se vea limpio tanto en Capa 1 como en props de Capa 2 (`escudo`, `casco_militar`, etc.).

---

## 2. Generación de Turnaround Sheet (Nano Banana) desde Órdenes Cortas

Cuando el usuario pida crear un nuevo personaje o prop con una frase corta (ej. *"Crea el atuendo de obrera"*, *"Diseña el pico del minero"* o *"Crea el avatar femenino"*), **NO** pases esa frase cruda al generador de imágenes. Sigue obligatoriamente este flujo de 3 pasos:

### Paso 1: Conceptualización según el Lore, Género y Separación Capa 1 vs Capa 2
1. Consulta el GDD, `godot/scripts/ajustes.gd` (`COLORES_COLONOS`, `TONOS_PIEL_COLONOS`, `COLORES_EQUIPO_PALETA`), `CatalogoPersonajes.gd` y los assets existentes en `godot/assets/personajes/` para alinear proporciones, estética y destino exacto.
2. **Regla estricta de Separación Capa 1 vs Capa 2 (CRÍTICA para `base/` y `atuendos/`):**
   - Los **cascos** (`casco_minero`, `casco_militar`), **gafas en los ojos** (`gafas_industriales`), **canastas de carga** (`canasta_acarreo`) y **herramientas/armas de mano** (`pico`, `martillo`, `hacha`, `espada`, `escudo`, `arco`, `maletin_ciencia`, `cana_pesca`) se acoplan aparte en Godot mediante Capa 2 (`BoneAttachment3D`).
   - Por lo tanto, en `base/` y `atuendos/<rango>_<m|f>.glb`: **NO** pongas cascos, gafas sobre los ojos ni objetos en las manos; deja la cabeza descubierta con cabello limpio, manos abiertas/relajadas en T-Pose y un acento textil blanco/gris neutro (brazalete, cuello o ribete) apto para `mat_color_equipo`.
3. **Regla anti-artefactos 3D:** evita capas sueltas muy largas, faldas/túnicas que fusionen las piernas y telas transparentes.

### Paso 2: Construcción del Prompt Técnico para Nano Banana
Envía a `image-generator` (aspecto `16:9` o `3:1`) la plantilla exacta según sea **Personaje Humanoide** o **Prop Rígido Capa 2**:

#### Plantilla A — Personajes Humanoides (`avatar/`, `base/`, `atuendos/`)
```text
3D character turnaround sheet, full-body orthographic views arranged horizontally side by side in 3 equal panels: [1] strict front view, [2] strict left side profile view, [3] strict back view. Subject: [GÉNERO M/F, RANGO O ROL, Y ATUENDO DETALLADO SEGÚN CRAFT TO NATION SIN CASCOS NI HERRAMIENTAS EN LAS MANOS, INCLUYENDO UN DETALLE TEXTIL NEUTRO BLANCO PARA COLOR DE EQUIPO]. Art style: stylized low-mid poly 3D game character, hand-painted PBR textures, clean geometric shapes matching Craft to Nation aesthetic. Pose: strict symmetrical T-pose, both arms perfectly straight and horizontal at 90 degrees from the torso, palms facing down, hands empty, legs straight and slightly apart, standing upright at the exact same ground line across all 3 views. Framing: full body from head to boots with generous white margin around the character, perfectly aligned horizontal proportions (eyes, shoulders, belt, knees, and soles match at the exact same Y-axis height across all three panels). Background: 100% pure solid flat white background (#FFFFFF), no ground shadows, no cast shadows, no text, no labels, no dividing lines, even soft studio lighting, ambient occlusion only.
```

#### Plantilla B — Props Rígidos Capa 2 (`equipamiento/<pieza>.glb`)
```text
3D game prop turnaround sheet, isolated object orthographic views arranged horizontally side by side in 3 equal panels: [1] strict front view, [2] strict left side profile view, [3] strict back view. Subject: [DESCRIPCIÓN DETALLADA DEL EQUIPO/HERRAMIENTA/CASCO/ESCUDO SEGÚN CRAFT TO NATION, SIN MANOS NI PERSONAJE SOSTENIÉNDOLO, ORIENTACIÓN VERTICAL/LIMPIA PARA ANCLAJE EN BONE ATTACHMENT]. Art style: stylized low-mid poly 3D game prop, hand-painted PBR textures, clean geometric silhouettes matching Craft to Nation aesthetic. Framing: full object centered with generous white margin, perfectly aligned horizontal proportions across all three panels. Background: 100% pure solid flat white background (#FFFFFF), no ground shadows, no cast shadows, no text, no labels, no dividing lines, even soft studio lighting, ambient occlusion only.
```

### Paso 3: Recorte Automático (Slicing), Aprobación y Ejecución 3D
1. Divide la imagen panorámica en 3 recortes cuadrados (`1:1`) con `split_turnaround.py`:
   ```powershell
   python tools/3d_pipeline/split_turnaround.py `
     --input "<ruta_turnaround.png>" `
     --output-dir "scratch/3d_jobs/<nombre>/views" `
     --order front,side,back `
     --size 1024
   ```
2. **Compuerta de aprobación obligatoria:** muestra brevemente la imagen generada y los detalles de diseño (ruta destino, capa, género/rango o slot) y **pide aprobación explícita** antes de lanzar Modal.

### Paleta Oficial de Clases (`godot/scripts/ajustes.gd`)
| Clase | Color Principal | Sugerencia de Vestuario Capa 1 (sin casco ni herramientas en mano) |
| :--- | :--- | :--- |
| `ciudadano` | `#b8ad99` (beige/arena) | Túnica/chaqueta práctica tonos tierra, pantalones cómodos, botas |
| `desempleado` | `#af946d` (ocre) | Ropa sencilla de colono recién llegado, chaleco ligero |
| `obrero` | `#cc8533` (ámbar/cobre) | Overol resistente, cinturón utilitario vacío, botas reforzadas |
| `tecnico` | `#3878c7` (azul industrial) | Chaqueta técnica azul, guantes aislantes, bolsillos laterales |
| `especialista` | `#40a661` (verde esmeralda) | Uniforme de precisión verde, chaleco utilitario compacto |
| `investigador` | `#8c52bf` (púrpura) | Abrigo corto de laboratorio sobre la rodilla (sin unir piernas), cuello alto |
| `militar` | `#bf3833` (rojo carmesí) | Peto/uniforme táctico rojo con hombreras y ribete blanco para equipo |

---

## 3. Flujo de Ejecución 3D por Tipo de Asset

### 3A. Humanoides (`avatar/`, `base/`, `atuendos/<rango>_<m|f>.glb`)
1. **Modal (Hunyuan3D-2mv + FaceReducer + Paint + UniRig):**
   - Avatar (`avatar.glb` / `avatar_f.glb`): `--target-faces 25000`
   - Base (`cuerpo_m/f.glb`) y Atuendos (`<rango>_<m|f>.glb`): `--target-faces 15000`
   ```powershell
   modal run -e crafttonation tools/3d_pipeline/modal_hunyuan_rig.py `
     --front "scratch/3d_jobs/<nombre>/views/front.png" `
     --side "scratch/3d_jobs/<nombre>/views/side.png" `
     --back "scratch/3d_jobs/<nombre>/views/back.png" `
     --target-faces 15000 `
     --output "scratch/3d_jobs/<nombre>/<nombre>_raw_rigged.glb"
   ```
2. **Post-procesado Headless en Blender (`blender_godot_prepare.py`):**
   - Avatar: `--force-decimate 11500 --max-tex 1024`
   - Base y Atuendos: `--force-decimate 5500 --max-tex 1024` (o `512`)
   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
     --python tools/3d_pipeline/blender_godot_prepare.py -- `
     --input "scratch/3d_jobs/<nombre>/<nombre>_raw_rigged.glb" `
     --output "godot/assets/personajes/<subcarpeta>/<archivo>.glb" `
     --height 1.80 `
     --max-tex 1024 `
     --force-decimate 5500 `
     --head-protect-fraction 0.22
   ```
3. **Verificación obligatoria (`blender_character_edit.py`):**
   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
     --python tools/3d_pipeline/blender_character_edit.py -- `
     --input "godot/assets/personajes/<subcarpeta>/<archivo>.glb" `
     --inspect `
     --render-preview "scratch/3d_jobs/<nombre>/preview.png"
   ```
   Verifica en el JSON `CTN_INSPECT`:
   - `modular_slots`: `Head`, `Chest`, `RightHand`, `LeftHand` en `true` (y `Neck: true` obligatorio en Avatares para `_OcultarCabezaModifier`).
   - `identity_materials`: informa si existen `mat_piel` y `mat_color_equipo` (o renómbralos con `--rename-material`).
   - Visualiza `preview.png` con `read_file`.

### 3B. Props Rígidos Capa 2 (`equipamiento/<pieza>.glb`)
1. **Modal SIN UniRig (`--skip-rig`):**
   ```powershell
   modal run -e crafttonation tools/3d_pipeline/modal_hunyuan_rig.py `
     --front "scratch/3d_jobs/<pieza>/views/front.png" `
     --side "scratch/3d_jobs/<pieza>/views/side.png" `
     --back "scratch/3d_jobs/<pieza>/views/back.png" `
     --target-faces 1500 `
     --skip-rig `
     --output "scratch/3d_jobs/<pieza>/<pieza>_raw.glb"
   ```
2. **Post-procesado de Prop (`blender_prop_prepare.py`):**
   Elimina cualquier esqueleto residual, escala al tamaño real del slot, coloca el origen `(0,0,0)` en el agarre/cabeza/espalda y exporta `.glb` ligero:
   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
     --python tools/3d_pipeline/blender_prop_prepare.py -- `
     --input "scratch/3d_jobs/<pieza>/<pieza>_raw.glb" `
     --output "godot/assets/personajes/equipamiento/<pieza>.glb" `
     --slot RightHand `
     --size 0.65 `
     --target-tris 1000 `
     --max-tex 512 `
     --render-preview "scratch/3d_jobs/<pieza>/preview.png"
   ```
   - Si la pieza debe teñirse con el color del equipo (ej. `escudo`, `casco_militar`), usa `--rename-material "Material_0=mat_color_equipo"` o separa/asigna el material en Blender MCP.
   - Revisa `preview.png` con `read_file` antes de entregar.

### 3C. Biblioteca Compartida de Animaciones (`animaciones/humanoide_base.glb`)
Cuando falte o se quiera actualizar `godot/assets/personajes/animaciones/humanoide_base.glb`, parte de un rig `SkeletonProfileHumanoid` (`cuerpo_m.glb` o `avatar.glb`) y conserva exactamente los ocho nombres canónicos: `Idle`, `Walking`, `Hauler_Box_Idle`, `Hauler_Carry`, `Fishing_Cast`, `Mining_Dig`, `Heavy_Swing` y `Work_Table`. Usa `blender_retarget_mixamo.py`; para un GLB multiacción selecciona la acción fuente exacta con `Nombre=ruta.glb::AccionFuente`. Verifica nombres, verticalidad del rig y poses representativas en los cuatro cuerpos antes de reemplazar la biblioteca.

---

## 4. Flujo de Correcciones, Modificaciones y Mejoras sobre Modelos Existentes

Elige el nivel mínimo necesario sin gastar créditos de Modal innecesariamente:

### Nivel 1: Ajustes Rápidos Locales Headless (`blender_character_edit.py`)
```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
  --python tools/3d_pipeline/blender_character_edit.py -- `
  --input "godot/assets/personajes/<subcarpeta>/<archivo>.glb" `
  --output "godot/assets/personajes/<subcarpeta>/<archivo>.glb" `
  --height 1.80 `
  --rename-material "Material_0=mat_color_equipo" `
  --roughness 0.78 `
  --max-tex 512 `
  --render-preview "scratch/3d_jobs/<nombre>/preview_v2.png"
```
Banderas útiles: `--scale-xyz`, `--rotate-z`, `--recenter-feet`, `--tint "#hex" --tint-strength 0.35`, `--rename-bone "Viejo=Nuevo"`, `--rename-material "Viejo=Nuevo"`, `--pose-adjust "LeftUpperArm:0,0,-10"`, `--shading smooth|flat`, `--decimate-ratio 0.75`.

### Nivel 2: Retoques Finos o Separación de Slots de Material (Script `bpy` o Blender MCP)
- Para separar islas de malla (ej. asignar `mat_piel` solo al rostro/manos y `mat_color_equipo` a un brazalete/escudo), limpiar artefactos o ajustar pesos de piel, escribe un script `bpy` puntual o usa **`blender-mcp`**.

### Nivel 3: Re-ejecución Selectiva en Modal
- `--rig-only` para re-riggear una malla editada en Blender.
- Regeneración completa variando `--seed`, `--steps` o `--target-faces` si cambia el turnaround.

---

## 5. Movimientos Corporales con Mixamo (`arte/animations/` y `.fbx` → `.glb`)

El proyecto ya cuenta con paquetes Mixamo descargados en **`arte/animations/`** (`Male_Locomotion_Pack`, `Female_Locomotion_Pack`, `Action_Adventure_Pack`, `Pro_Sword_and_Shield_Pack`, `Pro_Longbow_Pack`, `command`, más clips individuales como `Walking.fbx`, `Swimming.fbx`, `Heavy Weapon Swing.fbx`, `Kneeling Down.fbx`, `Dying.fbx`). Para nuevos clips en [mixamo.com](https://www.mixamo.com/): `FBX Binary`, `Without Skin`, `30 FPS`, `In Place` para locomoción, guardados en `arte/animations/` o `tools/3d_pipeline/mixamo_library/`.

### Nombres Exactos Esperados por Godot 4
- **Colonos (`PersonajeModular.gd` + `animaciones/humanoide_base.glb`):**
  - *Loop:* `Idle`, `Walking`, `Hauler_Box_Idle`, `Hauler_Carry`, `Fishing_Cast`, `Work_Table`.
  - *No-loop:* `Mining_Dig`, `Heavy_Swing`; `PersonajeModular` elige de nuevo al finalizar, por lo que minería puede repetir el mismo clip consecutivamente.
  - *Prioridad de acarreo:* un `acarreador` nunca hereda la animación del edificio donde trabaja; usa `Hauler_Carry` si se mueve o lleva carga y `Hauler_Box_Idle` si está quieto y vacío.
- **Avatar (`AvatarAnimador.gd`):**
  - *Loop:* `Idle`, `Walking`, `Walking_Backward`, `Strafe_Left`, `Strafe_Right`, `Running`, `Strafe_Left_Run`, `Strafe_Right_Run`, `Falling_Idle`, `Treading_Water`, `Swimming`, `Mining_Swing`, `Cenital_Kneel_Idle`, `Sword_Idle`, `Sword_Run`, `Sword_Strafe`, `Sword_Block_Idle`, `Bow_Idle`, `Bow_Aim_Hold`, `Bow_Aim_Walk_Forward`, `Bow_Aim_Walk_Back`, `Bow_Aim_Walk_Left`, `Bow_Aim_Walk_Right`.
  - *Puntuales:* `Jump_Start`, `Jump_Land`, `Cenital_Kneel_Down`, `Cenital_Stand_Up`, `Sword_Equip`, `Sword_Sheath`, `Sword_Slash`, `Sword_Slash_2`, `Bow_Equip`, `Bow_Disarm`, `Bow_Release`, `Command_Charge`, `Command_Point`, `Command_Rally`, `Hit_React`, `Death`.

### Scripts de Transferencia
- **Con recorte de frames, velocidad y alineación de extremidades (`blender_retarget_mixamo.py` — recomendado para producción):**
  ```powershell
  & "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
    --python tools/3d_pipeline/blender_retarget_mixamo.py -- `
    --character "godot/assets/personajes/avatar/avatar_f.glb" `
    --add "Idle=arte/animations/Female_Locomotion_Pack/idle.fbx" `
    --add "Walking=arte/animations/Female_Locomotion_Pack/walking.fbx" `
    --add "Mining_Swing=arte/animations/Heavy Weapon Swing.fbx|10:42|1.2" `
    --output "godot/assets/personajes/avatar/avatar_f.glb"
  ```
- **Por carpeta en lote (`blender_mixamo_retarget.py`):**
  ```powershell
  & "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
    --python tools/3d_pipeline/blender_mixamo_retarget.py -- `
    --input "godot/assets/personajes/base/cuerpo_m.glb" `
    --fbx-dir "tools/3d_pipeline/mixamo_library" `
    --in-place `
    --output "godot/assets/personajes/base/cuerpo_m.glb"
  ```

---

## 6. Expresiones Faciales y Lip-Sync (Blendshapes ARKit)

Añade *shape keys* compatibles con **Apple ARKit** sobre la cabeza del personaje en Blender headless, exportados como *Morph Targets* dentro del `.glb`:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
  --python tools/3d_pipeline/blender_arkit_blendshapes.py -- `
  --input "godot/assets/personajes/avatar/avatar_f.glb" `
  --output "godot/assets/personajes/avatar/avatar_f.glb" `
  --preset arkit52 `
  --render-expression-sheet "scratch/3d_jobs/avatar_f/face_sheet.png"
```
- **Presets por tipo de personaje:**
  - `arkit52` (52 blendshapes completos): para **Avatar (`avatar.glb` / `avatar_f.glb`)** y héroes.
  - `lipsync` (18 blendshapes esenciales): para **Cuerpos base (`base/`)** y **Atuendos (`atuendos/`)** de colonos.
- **Calibración:** `--mouth-v` (default `0.18`), `--eye-v` (`0.41`), `--brow-v` (`0.49`), `--intensity` (`1.0`), `--face-dir +Y`, `--add-demo-clips`.
- **Inspección obligatoria:** revisa el PNG 2×2 generado por `--render-expression-sheet` con `read_file`.
- **Uso en Godot 4:** `mesh_instance.set("blend_shapes/jawOpen", 0.75)`.
