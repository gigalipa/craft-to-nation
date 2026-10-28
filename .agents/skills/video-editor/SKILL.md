---
name: video-editor
description: Realiza composición programática con Remotion (React/TypeScript), formateo (9:16 vertical con blur y 16:9 cinematográfico), títulos animados HUD Trebuchet MS, subtítulos dinámicos con @remotion/captions, transcripción Whisper CUDA y renderizado acelerado para videos, devlogs y lives de Craft to Nation.
---

# Skill: Video Editor Técnico con Remotion (Craft to Nation)

Esta skill ejecuta el montaje técnico, composición programática con **Remotion (React/TypeScript)**, procesamiento audiovisual y renderizado acelerado por hardware a partir de grabaciones en `video_edition/media/raw/` para producir masters finales en `video_edition/media/processed/`.

El agente aprovecha el plugin y las skills oficiales de Remotion (`remotion-best-practices`, `remotion-markup`, `remotion-captions`, `remotion-render`, `remotion-studio`, `remotion-create`) para crear composiciones reactivas, tipografía cinética y transiciones profesionales.

---

## Ecosistema de Edición con Remotion

### 1. Composiciones en Remotion (`video_edition/remotion/`)
- **Composiciones Verticales (`ShortVideo` - 9:16, 1080x1920)**:
  - Fondo dinámico con efecto *box-blur* y brillo atenuado (`filter: 'blur(20px) brightness(0.85)'`) para mantener visible la acción sin recortar información del HUD.
  - Video central escalado manteniendo el aspect ratio nativo.
  - Subtítulos dinámicos cinéticos mediante `@remotion/captions`, aplicando estilo HUD de *Craft to Nation*:
    - Color de texto principal: Verde oscuro HUD (`#144214`).
    - Borde/Sombra/Glow: Amarillo dorado HUD (`#F6C424`).
    - Tipografía: `Trebuchet MS`, peso bold, alineación central inferior (`bottom: 350px`) para evitar colisión con la interfaz de TikTok/Instagram Reels/Shorts.
  - Pista de audio principal con normalización adaptativa y música loop en segundo plano con sidechain ducking reactivo (baja de volumen durante locución).
- **Composiciones Horizontales (`DevlogRecap` - 16:9, 1920x1080)**:
  - Montaje secuencial multi-corte usando `<Series>` y transiciones suaves (`@remotion/transitions`, como `fade` o `slide`).
  - Títulos inferiores animados de sección (*Lower Thirds*): Caja con borde verde (`#144214`), fondo semitransparente y tipografía Trebuchet MS dorada (`#F6C424`), animada con `spring()` o `interpolate()`.
  - **REGLA ESTRICTA:** El master horizontal se exporta limpio de subtítulos en pantalla. Se genera el archivo `.srt` sincronizado para YouTube Closed Captions.

### 2. Cadena de Transcripción y Datos
- **Whisper GPU CUDA (`video_edition/tools/subtitle_generator.py`)**:
  - Extrae audio y genera marcas de tiempo precisas en JSON por bloques para videos de cualquier duración sin desbordar memoria.
- **Limpieza de Glosario (`video_edition/tools/llm_subtitle_cleaner.py`)**:
  - Corrige fonética y alucinaciones fonéticas aplicando el glosario oficial (*"almacén"*, *"central termoeléctrica"*, *"aserradero"*, *"Dieselpunk/Cyberpunk/Solarpunk"*).
- **Consumo en Remotion**:
  - Remotion importa directamente el `clean_segments.json` generado para posicionar cada palabra/frase con precisión de fotograma (`useCurrentFrame()`).

### 3. Herramientas Auxiliares de Audio y Empaquetado
- **`audio_mixer.py`**:
  - Detección de ganancia automática (`get_auto_gain`) a -1.5 dB de pico (-14 LUFS).
  - Filtrado de pistas `(loop)` en `arte/mp3/`.
- **`asset_packager.py`**:
  - Empaqueta el video renderizado y sus complementos (`.srt`, `.ass`, `.json`, `.txt`) en `video_edition/media/processed/<nombre_del_video>/` y traslada el original a `video_edition/media/raw/done/`.
- **`qa_checker.py`**:
  - Validador técnico de entregables (resolución, duración, pistas de audio).

---

## Reglas Críticas de Formato y Subtitulado

### 1. Formato Corto / Vertical (Shorts, Reels, TikTok)
- **Aspecto**: 9:16 (1080x1920, 30 fps o 60 fps).
- **Duración**: Entre 20 y 58 segundos (límite estricto 60s).
- **Subtítulos**: **OBLIGATORIO RENDERIZARLOS/QUEMARLOS EN EL VIDEO**.
  - Tipografía: `Trebuchet MS`, tamaño acorde a pantalla móvil.
  - Color de texto: Verde oscuro HUD (`#144214` o `&H00144214&`).
  - Borde y sombra: Amarillo dorado HUD (`#F6C424` o `&H0024C4F6&`).
  - Posición: Central-inferior segura (`MarginV 350` / `bottom: 350px`).
- **Flujo de Ejecución**:
  1. Definir timestamps de corte del bruto.
  2. Transcribir y limpiar fonética con `subtitle_generator.py` y `llm_subtitle_cleaner.py`.
  3. Componer la escena en Remotion con fondo blur, video centrado, subtítulos dinámicos HUD y música loop con ducking.
  4. Previsualizar con `npx remotion studio` si se requiere ajuste fino visual.
  5. Renderizar video final con `npx remotion render` (o fallback optimizado con NVENC).

### 2. Formato Largo / Horizontal (Devlogs de YouTube, GitHub Discussions Updates, Recap de Live)
- **Aspecto**: 16:9 (1920x1080 Full HD).
- **Duración**: Típicamente 3 a 8 minutos.
- **Subtítulos**: **ESTRICTAMENTE PROHIBIDO QUEMAR SUBTÍTULOS EN EL VIDEO**.
  - El video master debe exportarse limpio de subtítulos flotantes (solo contiene títulos animados de sección en la esquina inferior izquierda).
  - Los subtítulos se entregan como archivo `.srt` externo sincronizado para YouTube Closed Captions.
- **Flujo de Ejecución**:
  1. Identificar bloques temáticos y duraciones en el timeline.
  2. Ensamblar composición Remotion en 16:9 con transiciones suaves y títulos animados de capítulo.
  3. Exportar archivo `.srt` limpio y sincronizado.
  4. Renderizar master horizontal limpio.

---

## Flujo para Transmisiones en Vivo (Lives)
1. **Extracción y Transcripción Global**:
   - Extraer audio puro a MP3 con FFmpeg.
   - Transcribir en bloques con Whisper GPU (`subtitle_generator.py`) obteniendo el JSON de marcas de tiempo y el autogain.
2. **Producción Paralela**:
   - **1 Video Recap Largo (16:9)**: Montar 4-5 mejores momentos en Remotion con transiciones, títulos animados y archivo `.srt` externo limpio.
   - **Al menos 3 Shorts Virales (9:16)**: Componer 3 clips independientes de 30-50s con fondo blur, subtítulos kinéticos HUD verde/oro quemados y música loop con ducking.
3. **Auditoría y Empaquetado**:
   - Validar con `qa_checker.py`.
   - Empaquetar entregables en carpetas dedicadas y archivar la grabación original en `video_edition/media/raw/done/`.

---

## Fuentes de Verdad y Conexiones del Repositorio

- **Orquestación y Reglas Generales**: [AGENTS.md](../../AGENTS.md) y [social/SKILL.md](../social/SKILL.md).
- **Componentes Remotion**: [Root.tsx](../../video_edition/remotion/src/Root.tsx), [VerticalShort.tsx](../../video_edition/remotion/src/VerticalShort.tsx), [DevlogRecap.tsx](../../video_edition/remotion/src/DevlogRecap.tsx), [LowerThird.tsx](../../video_edition/remotion/src/LowerThird.tsx).
- **Scripts de Procesamiento (`video_edition/tools/`)**: [clip_maker.py](../../video_edition/tools/clip_maker.py), [video_editor_studio.py](../../video_edition/tools/video_editor_studio.py), [subtitle_generator.py](../../video_edition/tools/subtitle_generator.py), [llm_subtitle_cleaner.py](../../video_edition/tools/llm_subtitle_cleaner.py), [audio_mixer.py](../../video_edition/tools/audio_mixer.py), [qa_checker.py](../../video_edition/tools/qa_checker.py), [asset_packager.py](../../video_edition/tools/asset_packager.py).
- **Glosario y Textos Oficiales del Juego**: [godot/scripts/strings.gd](../../godot/scripts/strings.gd) y [Documento de Diseño de Juego (GDD)_ Craft to Nation.md](../../Documento%20de%20Dise%C3%B1o%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md).
