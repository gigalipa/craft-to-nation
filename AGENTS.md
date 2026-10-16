# Orquestación de Agentes: Estudio de Redes Sociales (Craft to Nation)

Este documento define la arquitectura, comandos y responsabilidades del equipo de producción de contenidos para el videojuego *Craft to Nation*.

El usuario interactúa exclusivamente con el **Agente Orquestador (`social`)**, quien interpreta los comandos de alto nivel y coordina la ejecución secuencial de los agentes especialistas (`video-editor`, `gamedev-copywriter`, `content-qa`, `social-strategist`) o dispara las rutinas de automatización programada.

---

## Estructura de Directorios

- `video_edition/tools/`: Scripts de procesamiento acelerados por GPU y Whisper CUDA:
  - `clip_maker.py`: Recorte y reformateo vertical 9:16 con fondo blur (NVENC).
  - `video_editor_studio.py`: Editor cinematográfico multi-corte 16:9 con transiciones (xfade/acrossfade), títulos Trebuchet MS verde/oro y ducking.
  - `subtitle_generator.py`: Transcripción GPU CUDA y quemado/exportación de subtítulos (.ass/.srt).
  - `llm_subtitle_cleaner.py`: Corrector contextual y fonético basado en el glosario oficial del juego.
  - `audio_mixer.py`: Detección de ganancia dinámica (`get_auto_gain`), filtrado de pistas `(loop)` y sidechain ducking.
  - `qa_checker.py`: Validador técnico de entregables (resoluciones, duraciones, pistas y subtítulos).
  - `asset_packager.py`: Empaquetador de entregables en carpetas dedicadas y archivado de originales en `raw/done/`.
- `video_edition/media/raw/`: Grabaciones originales sin editar (`devlog_w{semana}_{num}.mp4`, `live_w{semana}.mp4`).
  - `video_edition/media/raw/done/`: **Carpeta de archivo histórico**. Una vez completado todo el procesamiento y validado por QA, el video original se traslada automáticamente aquí.
- `video_edition/media/processed/`: **Directorio de entregables organizados**. Cada video master reside en su propia subcarpeta con sus archivos asociados:
  - `video_edition/media/processed/<nombre_del_video>/`:
    - `<nombre_del_video>.mp4` (Video master final).
    - `<nombre_del_video>.srt` (Subtítulos sincronizados).
    - `<nombre_del_video>.ass` (Subtítulos estilizados ASS, si aplica).
    - `<nombre_del_video>_segments.json` (Marcas de tiempo de transcripción).
    - `<nombre_del_video>_transcript.txt` (Transcripción textual completa).
- `video_edition/workspaces/`: Calendarios editoriales y borradores de posts en Markdown (`calendario_semana_{num}.md`).
- `arte/`: Biblioteca de recursos visuales y auditivos existentes (logos, sfx, música mp3 en `arte/mp3/`).

---

## Ecosistema de Agentes y Roles

| Rol / Agente | Skill Asignada | Función en el Ecosistema |
| :--- | :--- | :--- |
| **Orquestador General** | `social` | Punto de contacto con el usuario y supervisor de automatización. Descompone los comandos en subtareas, dirige el flujo y ejecuta el archivado final. |
| **Editor de Video** | `video-editor` | Ejecuta las herramientas de FFmpeg, Whisper, corte, transiciones, audio y renderizado por GPU. |
| **Copywriter Indie** | `gamedev-copywriter` | Redacta ganchos virales de 3 segundos, textos para TikTok/Shorts/Reels, posts para X, descripciones de YouTube y Steam Updates. |
| **Control de Calidad** | `content-qa` | Ejecuta auditorías técnicas automatizadas (`qa_checker.py`) y revisiones editoriales de texto. |
| **Estratega Editorial** | `social-strategist` | Mantiene la parrilla semanal en `video_edition/workspaces/calendario_semana_{num}.md` y balancea pilares temáticos. |

---

## Comandos Principales del Usuario

El orquestador `social` responde directamente a los siguientes tres comandos:

### 1. `Genera un video corto a partir de este video: <nombre_del_video.mp4>`
**Objetivo:** Crear un clip viral vertical 9:16 (<60s) con subtítulos quemados y música con ducking.
- **Flujo Orquestado:**
  1. `video-editor`:
     - Selecciona el fragmento más dinámico (30-50s) o usa los timestamps solicitados.
     - Corta a 1080x1920 con fondo desenfocado usando `clip_maker.py -f vertical`.
     - Transcribe con `subtitle_generator.py`.
     - Limpia alucinaciones con `llm_subtitle_cleaner.py`.
     - Quema subtítulos estilo HUD verde/oro (`subtitle_generator.py --burn`).
     - Calcula autogain de voz y mezcla música loop con `audio_mixer.py --track-type loop`.
  2. `gamedev-copywriter`:
     - Redacta gancho de 3s, copy para TikTok/Instagram Reels/YouTube Shorts con hashtags, y post para X con CTA a Steam Wishlist.
  3. `content-qa`:
     - Valida con `qa_checker.py` (9:16, 1080x1920, <60s, audio activo).
  4. `social-strategist`:
     - Añade la entrada al calendario semanal.
  5. **Cierre y Archivado (`social` / `asset_packager.py`)**:
     - Empaqueta el video generado y sus archivos derivados (`.srt`, `.ass`, `.json`, `.txt`) dentro de `video_edition/media/processed/<nombre_del_corto>/`.
     - Mueve el video original de `video_edition/media/raw/<nombre_del_video.mp4>` a `video_edition/media/raw/done/<nombre_del_video.mp4>`.

---

### 2. `Edita este video: <nombre_del_video.mp4>`
**Objetivo:** Producir un devlog largo horizontal 16:9 con montaje multi-corte, transiciones, títulos animados y subtítulos en archivo `.srt` externo.
- **Flujo Orquestado:**
  1. `video-editor`:
     - Identifica bloques clave de desarrollo y construye el archivo `cuts.json` con títulos temáticos.
     - Ejecuta `video_editor_studio.py` (aplica `xfade`, `acrossfade`, títulos inferiores Trebuchet MS, ecualización vocal y música de fondo con ducking).
     - Extrae y corrige la transcripción para generar el archivo `.srt` limpio y sincronizado.
     - **REGLA ESTRICTA:** La versión horizontal larga **NUNCA debe tener subtítulos quemados en la imagen**; se entrega el video limpio y el `.srt` para YouTube Closed Captions.
  2. `gamedev-copywriter`:
     - Título para YouTube (`Craft to Nation | Devlog #...`).
     - Descripción de YouTube con marcas de tiempo (capítulos `00:00`, `01:15`...).
     - Borrador para Steam Community Update.
     - Post promocional en X.
  3. `content-qa`:
     - Valida con `qa_checker.py --format horizontal` (16:9, 1920x1080, audio activo, `.srt` presente y sin subtítulos incrustados).
  4. `social-strategist`:
     - Registra la publicación principal en el calendario semanal.
  5. **Cierre y Archivado (`social` / `asset_packager.py`)**:
     - Empaqueta el video master y su archivo `.srt`, `.json`, `.txt` en `video_edition/media/processed/<nombre_del_devlog>/`.
     - Mueve el video original a `video_edition/media/raw/done/<nombre_del_video.mp4>`.

---

### 3. `Procesa este live: <nombre_del_live.mp4>`
**Objetivo:** Procesar una transmisión en vivo completa (2 a 4 horas) para extraer **1 Video Largo Recap (16:9)** y **al menos 3 Shorts Virales (9:16)**.
- **Flujo Orquestado:**
  1. `video-editor`:
     - **Extracción de Audio Rápida:** Extrae la pista de voz a MP3 mediante FFmpeg.
     - **Transcripción Global:** Transcribe el MP3 con Whisper GPU (`subtitle_generator.py`) obteniendo el JSON completo de marcas de tiempo y el autogain necesario.
     - **Recap Horizontal (16:9):** Monta los 4 a 5 mejores momentos con `video_editor_studio.py` y genera el `.srt` limpio (sin quemar en el video).
     - **3 Shorts Verticales (9:16):** Corta 3 clips independientes de 30-50s (`clip_maker.py`), transcribe, limpia fonética (`llm_subtitle_cleaner.py`), quema subtítulos verde/oro (`--burn`) y mezcla música loop con ducking (`audio_mixer.py`).
  2. `gamedev-copywriter`:
     - Genera el paquete editorial del Recap Largo (YouTube + capítulos + Steam Update).
     - Genera los paquetes de los 3 Shorts (ganchos de 3s + TikTok/Reels/Shorts + X).
  3. `content-qa`:
     - Audita los 4 videos exportados con `qa_checker.py`.
  4. `social-strategist`:
     - Actualiza la parrilla editorial completa de la semana en `video_edition/workspaces/calendario_semana_{num}.md`.
  5. **Cierre y Archivado (`social` / `asset_packager.py`)**:
     - Agrupa cada uno de los 4 videos generados en su propia subcarpeta:
       - `video_edition/media/processed/<recap_largo>/`
       - `video_edition/media/processed/<short_01>/`
       - `video_edition/media/processed/<short_02>/`
       - `video_edition/media/processed/<short_03>/`
     - Mueve la grabación completa de `video_edition/media/raw/<nombre_del_live.mp4>` a `video_edition/media/raw/done/<nombre_del_live.mp4>`.
