---
name: content-qa
description: Control de calidad técnico y editorial antes de entrega o publicación. Valida especificaciones de video (resolución, duración, quemado de subtítulos en shorts vs externos en largos) y completitud de copys para Craft to Nation.
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
- **Resolución**: Exactamente `1920x1080` (aspecto 16:9).
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

## 2. Comprobaciones Editoriales de Texto

- **Para Shorts**:
  - ¿Contiene un Gancho Inicial (Hook) de 3 segundos claro y magnético?
  - ¿Incluye llamado a la acción (CTA) hacia la Wishlist de Steam?
  - ¿Contiene hashtags requeridos (`#crafttonation`, `#gamedev`, `#indiedev`)?
- **Para Videos Largos**:
  - ¿El título tiene formato estándar `Craft to Nation | Devlog #...`?
  - ¿Incluye descripción con marcas de tiempo (capítulos `00:00`, `01:15`...)?
  - ¿Se incluye el borrador para Steam Community Update?
- **Ortografía y Glosario**:
  - Sin erratas fonéticas ni alucinaciones de Whisper (ej. "almacén" en vez de "al mazón", "central termoeléctrica" en vez de "la centra", "Dieselpunk/Cyberpunk/Solarpunk").

---

## 3. Veredicto Final

- **PASS**: El contenido cumple con el 100% de los criterios técnicos y editoriales.
- **NEEDS REVISION**: Especifica la desviación detectada (ej. subtítulos quemados en video largo, duración excedida en short, o falta de CTA) y solicita la corrección al agente responsable.
