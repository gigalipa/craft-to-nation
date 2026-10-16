---
name: video-editor
description: Realiza cortes, formateo (vertical 9:16 con blur o horizontal 16:9), transiciones cinematográficas, subtitulado dinámico Whisper CUDA y renderizado acelerado por GPU NVENC para videos, devlogs y lives de Craft to Nation.
---

# Skill: Video Editor Técnico (Craft to Nation)

Esta skill ejecuta el montaje técnico, procesamiento audiovisual y renderizado acelerado por hardware (NVIDIA NVENC) a partir de grabaciones en `video_edition/media/raw/` para producir masters finales en `video_edition/media/processed/`.

---

## Herramientas de Edición (`video_edition/tools/`)

1. **`clip_maker.py`**:
   - Recorta clips y genera formato vertical 9:16 (1080x1920) con fondo desenfocado (blur) para no perder el HUD del juego.
   - Usa NVENC para renderizado instantáneo.
   - Comando tipo:
     ```powershell
     python video_edition/tools/clip_maker.py -i "<input.mp4>" -o "video_edition/media/processed/<output_raw.mp4>" -s <start> -e <end> -f vertical
     ```

2. **`video_editor_studio.py`**:
   - Editor cinematográfico multi-corte en 16:9 (1920x1080).
   - Ensambla fragmentos con transiciones suaves (`xfade=transition=fade` y `acrossfade`), títulos inferiores animados de sección (Trebuchet MS en amarillo dorado `0xF6C424` con borde verde `0x144214`), normalización vocal adaptativa y música loop con sidechain ducking.
   - Comando tipo:
     ```powershell
     python video_editor_studio.py -v "<raw.mp4>" -c "<cuts.json>" -o "video_edition/media/processed/<master.mp4>"
     ```

3. **`subtitle_generator.py`**:
   - Transcriptor GPU basado en Whisper CUDA (`base`).
   - Genera subtítulos `.ass` estilizados, archivos `.srt` y segmentos `.json`.
   - Permite quemar subtítulos en la imagen (`--burn`) o cargarlos desde JSON corregido (`--from-json`).

4. **`llm_subtitle_cleaner.py`**:
   - Limpia alucinaciones fonéticas de Whisper (como coreano en silencios o palabras rotas) y aplica el glosario de *Craft to Nation* (*"almacén"*, *"central termoeléctrica"*, *"aserradero"*, *"Dieselpunk / Cyberpunk / Solarpunk"*).
   - Comando tipo:
     ```powershell
     python video_edition/tools/llm_subtitle_cleaner.py -i "<raw_segments.json>" -o "<clean_segments.json>"
     ```

5. **`audio_mixer.py`**:
   - Calcula ganancia adaptativa (`get_auto_gain`) para elevar la voz humana al estándar de -1.5 dB de pico (añadiendo de +15 dB a +30 dB automáticamente si el micrófono grabó muy bajo).
   - Filtra exclusivamente música `(loop)` de `arte/mp3/` (ignora las de menú).
   - Aplica sidechain compressor agresivo (`threshold=0.015`, `ratio=16:1`, `attack=15`, `release=850ms`, `volume=0.025`) para que la música se atenúe cada vez que el desarrollador habla.

---

## Reglas Críticas de Formato y Subtitulado

### 1. Formato Corto / Vertical (Shorts, Reels, TikTok)
- **Aspecto**: 9:16 (1080x1920).
- **Duración**: Entre 20 y 58 segundos (límite estricto 60s).
- **Subtítulos**: **OBLIGATORIO QUEMARLOS EN EL VIDEO** (`--burn`).
  - Color de texto: Verde oscuro HUD (`&H00144214&`).
  - Borde y sombra: Amarillo dorado (`&H0024C4F6&`).
  - Posición: Central-inferior (MarginV 350).
- **Flujo de Ejecución**:
  `clip_maker.py` (corte vertical) -> `subtitle_generator.py` (transcripción) -> `llm_subtitle_cleaner.py` (limpieza) -> `subtitle_generator.py --from-json ... --burn` (quemado) -> `audio_mixer.py --track-type loop` (música y ducking).

### 2. Formato Largo / Horizontal (Devlogs de YouTube, Steam Updates, Recap de Live)
- **Aspecto**: 16:9 (1920x1080 Full HD).
- **Duración**: Típicamente 3 a 8 minutos.
- **Subtítulos**: **ESTRICTAMENTE PROHIBIDO QUEMAR SUBTÍTULOS EN EL VIDEO**.
  - El video master debe exportarse limpio de subtítulos flotantes (solo contiene títulos animados de capítulo en la esquina inferior).
  - Los subtítulos se entregan como archivo `.srt` externo limpio y sincronizado para YouTube Closed Captions.
- **Flujo de Ejecución**:
  `video_editor_studio.py` (montaje multi-corte y música) -> Mapeo y limpieza de transcripción con `llm_subtitle_cleaner.py` -> Exportar archivo `.srt`.

---

## Flujo Especial para Streams / Lives Largos (`live_w{semana}.mp4`)
Cuando el video de entrada es un streaming de 2 a 4 horas:
1. **Extracción de audio preliminar**: Extraer audio puro a MP3 para no sobrecargar memoria ni GPU:
   ```powershell
   ffmpeg -y -i "video_edition/media/raw/live_w1.mp4" -vn -c:a libmp3lame -b:a 192k "video_edition/media/processed/live_w1_audio.mp3"
   ```
2. **Transcripción global**: Transcribir el MP3 completo en GPU con Whisper CUDA (`subtitle_generator.py`) para generar el mapa temporal completo (`segments.json`).
3. **Producción simultánea**:
   - Generar **1 Video Recap Largo (16:9)** con 4 a 5 mejores momentos mediante `video_editor_studio.py` y su archivo `.srt` externo.
   - Generar **al menos 3 Shorts Virales (9:16)** independientes con subtítulos verde/oro quemados y música ducking.

---

## Organización de Entregables y Archivado (`asset_packager.py`)
Una vez finalizada la exportación de cualquier video (corto o largo):
1. **Carpeta propia por video**: Cada video y sus archivos relacionados se agrupan en su propia subcarpeta:
   - `video_edition/media/processed/<nombre_del_video>/` conteniendo el video `.mp4`, `.srt`, `.ass`, `_segments.json` y `_transcript.txt`.
   - Se ejecuta:
     ```powershell
     python video_edition/tools/asset_packager.py package -n "<nombre_del_video>" -f "<archivo1>" "<archivo2>" ...
     ```
2. **Archivado del original**: Se traslada el archivo bruto de `video_edition/media/raw/<video.mp4>` a `video_edition/media/raw/done/<video.mp4>`:
   ```powershell
   python video_edition/tools/asset_packager.py done -r "<video.mp4>"
   ```
