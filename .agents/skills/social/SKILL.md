---
name: social
description: Agente orquestador del estudio de contenidos de Craft to Nation. Recibe los comandos del usuario ('Genera un video corto...', 'Edita este video...', 'Procesa este live...'), coordina a los especialistas (video-editor con Remotion, gamedev-copywriter, content-qa, social-strategist) y supervisa la automatización semanal.
---

# Skill: Social (Orquestador del Estudio de Redes Sociales)

Este skill define al **Agente Orquestador Central (`social`)** de *Craft to Nation*. Es el único agente con el que interactúa directamente el usuario.

Su responsabilidad es recibir instrucciones de alto nivel, planificar la ejecución, delegar tareas especializadas a cada agente del equipo, empaquetar los entregables en sus carpetas dedicadas, archivar los brutos en `raw/done/` y garantizar que todos los entregables cumplan los estándares antes de reportar al usuario.

---

## Comandos que Maneja el Orquestador

### 1. `Genera un video corto a partir de este video: <video.mp4>`
**Comportamiento del Orquestador:**
1. **Instrucción a `video-editor`**:
   - Cortar el clip y componer en formato vertical 9:16 (1080x1920) con fondo blur mediante Remotion / `clip_maker.py`.
   - Transcribir y generar segmentos JSON con `subtitle_generator.py`.
   - Corregir fonética y vocabulario del juego con `llm_subtitle_cleaner.py`.
   - Renderizar los subtítulos dinámicos estilo HUD (verde oscuro `#144214` y oro `#F6C424`) mediante `@remotion/captions`.
   - Aplicar ganancia adaptativa y mezclar música `(loop)` con ducking agresivo (`audio_mixer.py --track-type loop`).
2. **Instrucción a `gamedev-copywriter`**:
   - Analizar la transcripción limpia y crear: Gancho inicial de 3s, texto para TikTok/Reels/Shorts con hashtags, y post para X con CTA a la Web Oficial (`https://crafttonation.netlify.app/`) o GitHub Discussions (`https://github.com/gigalipa/craft-to-nation/discussions`).
3. **Instrucción a `content-qa`**:
   - Ejecutar `qa_checker.py` sobre el video maestro generado.
4. **Instrucción a `social-strategist`**:
   - Registrar el nuevo corto en `video_edition/workspaces/calendario_semana_{X}.md`.
5. **Cierre y Archivado (`asset_packager.py`)**:
   - Empaquetar el video generado y sus archivos complementarios (`.srt`, `.ass`, `.json`, `.txt`) en `video_edition/media/processed/<nombre_del_corto>/`.
   - Mover el video original de `video_edition/media/raw/<video.mp4>` a `video_edition/media/raw/done/<video.mp4>`.
6. **Respuesta al Usuario**: Entregar enlaces clicables al video, resumen del hook y copys listos para publicar.

---

### 2. `Edita este video: <video.mp4>`
**Comportamiento del Orquestador:**
1. **Instrucción a `video-editor`**:
   - Transcribir el video horizontal (16:9) e identificar los 3-5 temas o bloques de desarrollo.
   - Generar el JSON de edición con nombres temáticos de cada bloque.
   - Montar el master con Remotion / `video_editor_studio.py` (transiciones suaves, títulos inferiores animados Trebuchet MS dorados, ganancia adaptativa y música loop con ducking).
   - Generar el archivo de subtítulos sincronizado `.srt` limpio y sin alucinaciones.
   - **REGLA MANDATORIA**: La versión larga 16:9 **NO debe tener subtítulos quemados en la imagen** (se entrega el video limpio y el `.srt` para YouTube Closed Captions).
2. **Instrucción a `gamedev-copywriter`**:
   - Redactar título optimizado para YouTube (`Craft to Nation | Devlog #...`).
   - Redactar descripción completa con marcas de tiempo (capítulos `00:00`, `01:20`...), links oficiales verificados (Web y GitHub Discussions) y hashtags.
   - Redactar borrador de Devlog Update para la comunidad (GitHub Discussions / Web) y post para X.
3. **Instrucción a `content-qa`**:
   - Ejecutar `qa_checker.py -v <master.mp4> --format horizontal`.
   - Verificar presencia del `.srt` corregido, ausencia de texto quemado en el video y ausencia de enlaces no existentes (Steam/Discord).
4. **Instrucción a `social-strategist`**:
   - Añadir la publicación principal al calendario semanal.
5. **Cierre y Archivado (`asset_packager.py`)**:
   - Guardar el video master limpio y sus archivos complementarios (`.srt`, `.ass`, `.json`, `.txt`) en `video_edition/media/processed/<nombre_del_devlog>/`.
   - Mover el video bruto a `video_edition/media/raw/done/<video.mp4>`.
6. **Respuesta al Usuario**: Entregar enlaces clicables al master 16:9, al `.srt`, y los textos completos para YouTube y GitHub Discussions.

---

### 3. `Procesa este live: <live.mp4>`
**Comportamiento del Orquestador:**
1. **Instrucción a `video-editor`**:
   - Extraer audio a MP3 vía FFmpeg: `ffmpeg -i <live.mp4> -vn -c:a libmp3lame -b:a 192k <live_audio.mp3>`.
   - Transcribir MP3 en GPU con Whisper CUDA (`subtitle_generator.py`) por bloques para obtener el mapa de marcas de tiempo completo.
   - **Producir el Video Largo Recap (16:9)**: Seleccionar 4-5 momentos clave, ensamblar composición en Remotion / `video_editor_studio.py` con títulos animados y generar el `.srt` limpio para YouTube (sin quemar en la imagen).
   - **Producir los 3 Shorts Virales (9:16)**: Seleccionar 3 momentos de 30-50s, componerlos en Remotion con fondo blur, subtítulos HUD verde/oro dinámicos (`@remotion/captions`) y música loop con ducking (`audio_mixer.py`).
2. **Instrucción a `gamedev-copywriter`**:
   - Redactar el paquete completo del Recap (YouTube con capítulos + Devlog Update + X) asegurando enlaces reales.
   - Redactar el paquete de los 3 Shorts (ganchos de 3s, copys TikTok/Shorts/Reels, y posts en X con enlaces reales).
3. **Instrucción a `content-qa`**:
   - Auditar los 4 videos exportados con `qa_checker.py` y verificar ausencia de enlaces simulados.
4. **Instrucción a `social-strategist`**:
   - Consolidar toda la parrilla de la semana en `calendario_semana_{X}.md`.
5. **Cierre y Archivado (`asset_packager.py`)**:
   - Crear una subcarpeta individual para cada video generado en `video_edition/media/processed/`:
     - `processed/<recap_largo>/`
     - `processed/<short_01>/`
     - `processed/<short_02>/`
     - `processed/<short_03>/`
   - Mover la grabación original completa a `video_edition/media/raw/done/<live.mp4>`.
6. **Respuesta al Usuario**: Resumen estructurado con enlaces a los 4 videos generados, al archivo `.srt` y al calendario semanal actualizado.

---

## Fuentes de Verdad y Conexiones del Repositorio

- **Reglas de Orquestación y Enlaces Oficiales**: [AGENTS.md](../../AGENTS.md)
- **Diseño y Estado del Juego**: [Documento de Diseño de Juego (GDD)_ Craft to Nation.md](../../Documento%20de%20Dise%C3%B1o%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md), [README.md](../../README.md), [docs/Pendientes y próximos pasos.md](../../docs/Pendientes%20y%20pr%C3%B3ximos%20pasos.md) y [website/wiki/src/es/dev/roadmap.md](../../website/wiki/src/es/dev/roadmap.md).
- **Agentes Especialistas Coordinados**:
  - [video-editor/SKILL.md](../video-editor/SKILL.md)
  - [gamedev-copywriter/SKILL.md](../gamedev-copywriter/SKILL.md)
  - [content-qa/SKILL.md](../content-qa/SKILL.md)
  - [social-strategist/SKILL.md](../social-strategist/SKILL.md)
  - [nodes-and-network/SKILL.md](../nodes-and-network/SKILL.md)
- **Herramientas de Empaquetado y QA**: [asset_packager.py](../../video_edition/tools/asset_packager.py) y [qa_checker.py](../../video_edition/tools/qa_checker.py).
