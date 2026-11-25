# Misión: Implementar Pipeline Híbrido Multi-View (Hunyuan3D-2mv + UniRig + Blender CLI/MCP) para "Craft to Nation" (Godot 4)

Necesito que configures e instales un pipeline completo, modular y automatizado para convertir un **trío de imágenes de referencia** de cada personaje (vista **frontal**, **lateral izquierda** y **de espaldas**) en un modelo 3D texturizado, optimizado para rendimiento en tiempo real, riggeado con esqueleto humanoide estándar y exportado en formato **`.glb`** listo para animar en **Godot 4**.

---

## 1. Contexto de Hardware, Presupuesto y Juego
- **Equipo Local:** MSI Thin GF63, Windows 11, CPU i5-11th, 16 GB RAM, GPU NVIDIA RTX 3050 (4 GB VRAM).
- **Restricción crítica de VRAM:** Mi GPU local solo tiene 4 GB de VRAM. **NO** ejecutes modelos de generación 3D o auto-rigging neural en local.
- **Arquitectura Híbrida Obligatoria:**
  1. **Nube Serverless (Modal.com):** Tengo $30 en créditos activos de Modal. Toda la inferencia pesada (**Hunyuan3D-2 Multi-View** + **UniRig**) debe correr en Modal usando contenedores separados (para evitar conflictos de dependencias CUDA/PyTorch), con **`L40S` (48 GB VRAM)** o **`A10G` (24 GB VRAM con liberación explícita de VRAM entre geometría y pintura)**, apagado rápido (`scaledown_window=30`), `timeout=600` y caché persistente de pesos en `modal.Volume` para maximizar mis créditos.
  2. **Local (Windows 11 + Blender CLI / MCP):** Blender local en modo **headless CLI (`blender --background --python ...`)** ejecutará el post-procesado automático y determinista sobre el `.glb` riggeado descargado desde Modal (normalización de escala, origen en los pies, renombrado de huesos al perfil humanoide de Godot 4 y exportación final). **Blender MCP** quedará instalado como modo interactivo opcional para inspecciones o retoques visuales en vivo.
- **Contexto y Presupuesto de Rendimiento de "Craft to Nation":** Aprovecha todo el contexto que ya tienes en este workspace sobre *Craft to Nation* (estilo visual, paleta, proporciones de los ciudadanos/tropas, clases/profesiones y estructura de carpetas del proyecto Godot). Como en pantalla conviven decenas de colonos y unidades militares:
  - **Colonos y unidades estándar:** objetivo de `3,000 – 6,000` triángulos y texturas de `512x512` o `1024x1024`.
  - **Avatar / personajes principales:** objetivo de `8,000 – 12,000` triángulos y texturas de `1024x1024`.

---

## 2. Repositorios Open-Source Oficiales a Utilizar
Utiliza e integra estos repositorios exactos (clónalos o instálalos desde sus URLs completas):

1. **Generación Multi-View Image-to-3D (en Modal — Contenedor 1):**
   - Repositorio: `Tencent-Hunyuan/Hunyuan3D-2`
   - URL completa: `https://github.com/Tencent-Hunyuan/Hunyuan3D-2`
   - **Importante:** Configura específicamente el pipeline **Multi-View (`Hunyuan3D-2mv`)** (pesos en Hugging Face: `tencent/Hunyuan3D-2mv`) junto con el **`FaceReducer` nativo** (reducción de triángulos **ANTES** de pintar y riggear para no romper UVs ni pesos de piel) y el generador de texturas PBR (`Hunyuan3D-Paint`), aceptando las 3 vistas de entrada (`--front`, `--left`, `--back`).

2. **Auto-Rigging Universal (en Modal — Contenedor 2):**
   - Repositorio: `VAST-AI-Research/UniRig`
   - URL completa: `https://github.com/VAST-AI-Research/UniRig`
   - Ejecútalo en su **propia imagen de Modal** (compartiendo el mismo `modal.Volume` con Hunyuan3D-2) inmediatamente después de generar la malla reducida y texturizada para predecir el esqueleto humanoide y los *skinning weights*, exportando a `.glb`.

3. **Control Local de Blender (CLI Headless + MCP Server opcional en Windows 11):**
   - Repositorio: `ahujasid/mcp-for-blender`
   - URL completa: `https://github.com/ahujasid/mcp-for-blender`
   - URL directa del addon: `https://raw.githubusercontent.com/ahujasid/mcp-for-blender/main/addon.py`
   - Instálalo mediante `uv`/`uvx` (`uvx blender-mcp`) y configura el addon `addon.py` dentro de mi instalación local de Blender para inspecciones/retoques interactivos.

4. **Utilidad de Pose (Opcional/Fallback en Blender):**
   - Repositorio: `4onstudios/AutoTPose`
   - URL completa: `https://github.com/4onstudios/AutoTPose`
   - Útil si algún personaje generado requiere ajustar brazos/piernas a T-Pose/A-Pose limpia antes de hacer retargeting en Godot 4.

---

## 3. Fases de Implementación que Debes Ejecutar

### Fase 1: Inspección del Entorno e Instalación CLI de Dependencias Locales
1. **Verificación e Instalación de Blender por CLI:**
   - Comprueba si Blender ya está instalado en Windows 11 (revisando el `PATH` y rutas estándar como `C:\Program Files\Blender Foundation\`).
   - **Si Blender NO está instalado**, instálalo automáticamente mediante CLI usando `winget`:
     ```powershell
     winget install --id BlenderFoundation.Blender -e --accept-package-agreements --accept-source-agreements
     ```
   - Asegúrate de registrar la ruta del ejecutable `blender.exe` para poder invocarlo en modo `--background` desde terminal.
2. **Verificación de `uv` y `modal`:**
   - Verifica si `uv` y el CLI `modal` están instalados. Si faltan, instálalos por CLI:
     ```powershell
     powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
     ```
     y luego `uv tool install modal` (o `pip install modal`).
   - Avísame únicamente si necesitas que ejecute `modal token new` para autenticar mi cuenta en el navegador.
3. **Inspección del Proyecto Godot 4:**
   - Ubica la carpeta raíz del proyecto **Godot 4** (`godot/`) de *Craft to Nation* en este workspace y determina las rutas exactas donde deben exportarse los personajes (`res://assets/personajes/...` o la convención vigente del proyecto).

### Fase 2: Configuración de Blender MCP (Modo Interactivo Opcional)
1. Descarga `addon.py` desde `https://raw.githubusercontent.com/ahujasid/mcp-for-blender/main/addon.py` y cópialo en la carpeta de addons de la versión de Blender recién detectada/instalada en `%APPDATA%\Blender Foundation\Blender\<version>\scripts\addons\`.
2. Configura el servidor MCP `blender-mcp` (`uvx blender-mcp`) en mi configuración MCP para poder ejecutar ajustes interactivos en Blender cuando haga falta revisar visualmente un personaje.
3. Guíame brevemente si necesito abrir Blender una vez para marcar el checkbox del addon y pulsar "Connect to MCP".

### Fase 3: Microservicio Serverless Multi-View en Modal (`tools/3d_pipeline/modal_hunyuan_rig.py`)
1. Crea un script de Modal con **dos imágenes Docker/CUDA independientes** para evitar conflictos de dependencias entre librerías:
   - **`image_hunyuan`:** PyTorch + CUDA + `rembg` + **Hunyuan3D-2 (`Hunyuan3D-2mv` + `FaceReducer` + `Hunyuan3D-Paint`)**.
   - **`image_unirig`:** PyTorch + CUDA + dependencias específicas de **UniRig**.
2. Configura un `modal.Volume` compartido (ej. `hunyuan-unirig-cache`) para almacenar los checkpoints de Hugging Face y el archivo `.glb` intermedio entre ambos contenedores, evitando descargas repetidas en cada ejecución. Incluye `scaledown_window=30` y `timeout=600`.
3. Expón una interfaz CLI limpia para invocar el flujo completo desde local:
   ```bash
   modal run tools/3d_pipeline/modal_hunyuan_rig.py --front <frente.png> --left <lateral_izq.png> --back <espalda.png> --target-faces 5000 --output <salida_raw_rigged.glb>
   ```
   *(Acepta también `--side` como alias de `--left` por comodidad).*
4. El flujo en nube debe ejecutar:
   - **Paso A (Contenedor Hunyuan — GPU `L40S` recomendada, o `A10G` descargando el modelo de geometría + `gc.collect()` + `torch.cuda.empty_cache()` antes de cargar `Hunyuan3D-Paint` para evitar OOM):**
     1. Eliminar el fondo automáticamente (`rembg`) y centrar/normalizar el recorte de las 3 vistas (`front`, `left`, `back`).
     2. Ejecutar **Hunyuan3D-2mv** para reconstruir la geometría 3D coherente desde los 3 ángulos.
     3. Aplicar el **`FaceReducer` nativo de Hunyuan3D-2** al presupuesto `--target-faces` (por defecto `5000` triángulos para colonos/unidades, configurable hasta `10000` para el Avatar) **antes de texturizar**.
     4. Liberar VRAM del generador de geometría y ejecutar **Hunyuan3D-Paint** para hornear texturas PBR limpias sobre la malla ya optimizada.
     5. Guardar el `.glb` intermedio en el `modal.Volume`.
   - **Paso B (Contenedor UniRig — GPU `A10G` o `L4`):**
     1. Leer el `.glb` optimizado y texturizado desde el `modal.Volume`.
     2. Ejecutar **UniRig** para predecir el esqueleto humanoide completo y los *skinning weights* sobre esa topología final.
     3. Devolver el `.glb` riggeado final a mi carpeta temporal local.

### Fase 4: Post-Procesado Local Automatizado en Blender para Godot 4 (`tools/3d_pipeline/blender_godot_prepare.py`)
1. Crea un script de Python para Blender (`bpy`) diseñado para ejecutarse de forma **100% desatendida por CLI headless**:
   ```bash
   blender --background --python tools/3d_pipeline/blender_godot_prepare.py -- --input <salida_raw_rigged.glb> --output <godot/assets/personajes/.../personaje.glb> --height 1.75
   ```
   *(El mismo script debe poder invocarse también desde Blender MCP si se está haciendo un retoque interactivo).*
2. El script debe realizar automáticamente:
   - Importación del `.glb` riggeado descargado de Modal.
   - Verificación del conteo de triángulos y resolución de texturas (redimensionando texturas a `512x512` o `1024x1024` si superan el presupuesto). **Evitar `Decimate` destructivo post-rigging** salvo como fallback explícito (`--force-decimate`) si el `.glb` excediera el límite, ya que la reducción principal se hizo antes de pintar y riggear en Fase 3.
   - Normalización de escala real (1 unidad = 1 metro, altura configurable ej. `1.75 m`) y colocación del origen `(0, 0, 0)` exactamente en la base entre los pies, mirando hacia `-Z` (o `+Z` consistente con la exportación glTF hacia Godot 4).
   - Mapeo y renombrado automático de la jerarquía de huesos al estándar **Godot 4 `SkeletonProfileHumanoid`** (`Root`, `Hips`, `Spine`, `Chest`, `Neck`, `Head`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `RightUpperArm`, `RightLowerArm`, `RightHand`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`, `RightUpperLeg`, `RightLowerLeg`, `RightFoot`) para permitir **Animation Retargeting** compartido entre todos los personajes en Godot.
   - Exportación final en **`.glb` (glTF Binary)** con texturas empaquetadas directo a la carpeta de personajes de Godot.

### Fase 5: Creación de Skill Permanente de Antigravity (`.agents/skills/craft-character-3d/SKILL.md`)
1. Documenta todo el flujo como una *Skill* reutilizable en **`.agents/skills/craft-character-3d/SKILL.md`** (respetando la carpeta plural `.agents/skills/` de este workspace), incluyendo:
   - El comando exacto para procesar cualquier nuevo set de 3 imágenes (`front`, `left`, `back`), incluyendo un script auxiliar en Python (`Pillow`, ej. `tools/3d_pipeline/split_turnaround.py`) por si te entrego una sola imagen panorámica (Turnaround Sheet de 3 paneles) para que la recorte automáticamente en las 3 vistas con márgenes uniformes.
   - Una **plantilla de prompts optimizada para Nano Banana** adaptada al estilo artístico de *Craft to Nation* que exija estrictamente:
     - **3 vistas ortográficas alineadas** (Frontal, **Perfil Izquierdo mirando hacia la izquierda** para coincidir con `--left` de Hunyuan3D-2mv, y Espalda).
     - **A-Pose simétrica** con brazos separados a ~45°, manos abiertas y piernas ligeramente separadas (evitando capas, faldas largas o telas que fusionen las piernas en un solo bloque).
     - **Fondo blanco sólido plano**, iluminación neutra uniforme sin sombras proyectadas en el suelo ni accesorios flotantes.

---

## 4. Instrucciones de Ejecución
- Comienza inspeccionando el workspace actual, el contexto de *Craft to Nation* y mis herramientas instaladas en Windows 11.
- Preséntame brevemente tu plan técnico adaptado al estilo visual del juego antes de instalar dependencias.
- Avanza fase por fase y avísame solo cuando necesites mi intervención manual (como autenticar Modal o habilitar el addon en la interfaz de Blender).
