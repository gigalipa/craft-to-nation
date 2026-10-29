---
name: content-qa
description: Control de calidad técnico y editorial antes de entrega o publicación. Valida especificaciones de video (resolución, duración, quemado de subtítulos en shorts vs externos en largos) y verificación de enlaces reales en copys para Craft to Nation.
---

# Skill: Content QA (Control de Calidad)

Esta skill actúa como el filtro crítico que audita cada entregable antes de darlo por aprobado y presentarlo al usuario o publicarlo en redes.

---

## 1. Comprobaciones Técnicas Automatizadas (`qa_checker.py`)

El QA ejecuta `qa_checker.py` sobre cada video master generado:

### Para Videos Cortos / Shorts (`--format vertical`):
- **Resolución**: Exactamente `1080x1920` (aspecto 9:16).
- **Duración**: Menos de 60 segundos (preferiblemente 30-50s).
- **Pista de Audio**: Audio presente, activo y nivelado con voz clara sobre la música.
- **Subtítulos**: **Deben estar quemados en el video** con estilo HUD (verde oscuro `&H00144214&` y oro `&H0024C4F6&`), sin salirse de los márgenes seguros.
- Comando:
  ```powershell
  python video_edition/tools/qa_checker.py -v "video_edition/media/processed/<nombre_del_video>/<short_master.mp4>"
  ```

### Para Videos Largos / Devlogs / Recaps (`--format horizontal`):
- **Resolución**: `1920x1080` (Full HD recomendado) o `1280x720` (HD aceptado), aspecto 16:9.
- **Duración**: Superior a 60 segundos.
- **Pista de Audio**: Mezcla activa con ducking en transiciones de voz.
- **Subtítulos**:
  - **REGLA MANDATORIA**: El video master **NO debe tener subtítulos quemados en la imagen**.
  - Debe existir el archivo `.srt` sincronizado y corregido al lado del video (para YouTube Closed Captions).
- Comando:
  ```powershell
  python video_edition/tools/qa_checker.py -v "video_edition/media/processed/<nombre_del_video>/<recap_master.mp4>" --format horizontal
  ```

---

## 2. Comprobaciones Editoriales de Texto y Verificación de Enlaces

- **Validación Estricta de Enlaces**:
  - ⚠️ **Steam y Discord ficticios**: RECHAZAR inmediatamente cualquier copy que contenga enlaces inventados a Steam (`store.steampowered.com/...`) o Discord (`discord.gg/...`). La página de Steam aún no existe.
  - **Enlaces verificados y válidos**:
    - Web oficial: `https://crafttonation.netlify.app/`
    - Feedback y comunidad: `https://github.com/gigalipa/craft-to-nation/discussions`
    - YouTube oficial: `https://www.youtube.com/@crafttonation`
- **Para Shorts**:
  - ¿Contiene un Gancho Inicial (Hook) de 3 segundos claro y magnético?
  - ¿Incluye llamado a la acción (CTA) hacia la web oficial o GitHub Discussions?
  - ¿Contiene hashtags requeridos (`#crafttonation`, `#gamedev`, `#indiedev`)?
- **Para Videos Largos**:
  - ¿El título tiene formato estándar `Craft to Nation | Devlog #...`?
  - ¿Incluye descripción con marcas de tiempo (capítulos `00:00`, `01:15`...)?
  - ¿Se incluye el borrador para GitHub Discussions / Devlog Update?
- **Ortografía y Glosario**:
  - Sin erratas fonéticas ni alucinaciones de Whisper (ej. "almacén" en vez de "al mazón", "central termoeléctrica" en vez de "la centra", "Dieselpunk/Cyberpunk/Solarpunk").

---

## 3. Veredicto Final

- **PASS**: El contenido cumple con el 100% de los criterios técnicos y editoriales (incluyendo enlaces verificados).
- **NEEDS REVISION**: Especifica la desviación detectada (ej. subtítulos quemados en video largo, duración excedida en short, falta de CTA, o uso de enlaces falsos/no existentes) y solicita la corrección al agente responsable.

---

## 4. Fuentes de Verdad para Auditoría Técnica y Editorial

- **Validador Técnico y Limpiador Fonético**: [video_edition/tools/qa_checker.py](../../video_edition/tools/qa_checker.py) y [video_edition/tools/llm_subtitle_cleaner.py](../../video_edition/tools/llm_subtitle_cleaner.py).
- **Política de Enlaces y Orquestación**: [AGENTS.md](../../AGENTS.md) y [social/SKILL.md](../social/SKILL.md).
- **Especificaciones Oficiales del Juego**: [Documento de Diseño de Juego (GDD)_ Craft to Nation.md](../../Documento%20de%20Dise%C3%B1o%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md), [README.md](../../README.md), [docs/Pendientes y próximos pasos.md](../../docs/Pendientes%20y%20pr%C3%B3ximos%20pasos.md), [website/wiki/src/es/dev/roadmap.md](../../website/wiki/src/es/dev/roadmap.md) y [godot/scripts/strings.gd](../../godot/scripts/strings.gd).
