# Calendario Editorial - Semana 7: Craft to Nation

**Estrategia de la Semana**: Gran salto de inmersión y acabado visual en **Godot 4**. Mostramos el estado actual del juego con las nuevas **texturas PBR**, iluminación nocturna y el reemplazo completo de las antiguas cápsulas por **población 3D modular** (obreros y obreras con herramientas, canastas de acarreo y 8 animaciones contextuales), además de la aparición del **Avatar 3D** dentro del mundo procedural.

---

## Parrilla de Publicaciones Semanal

| Día | Formato | Pilar de Contenido | Título / Tema Principal | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **Martes** | Devlog Largo Horizontal (16:9) | Avance Visual / Godot 4 | *Craft to Nation \| Devlog #6: Nuevas Texturas, Iluminación Nocturna y Población 3D en Godot 4* | Listo para Publicar (QA PASS) |
| **Miércoles** | Short (9:16) | Población 3D & Animaciones | *Short #1: ¡Adiós a las cápsulas! Nuevas texturas y obreros 3D picando* | Listo para Publicar (QA PASS) |
| **Viernes** | Short (9:16) | Inmersión & Vida en la Colonia | *Short #2: Vida nocturna en la colonia: interiores amueblados y acarreo* | Listo para Publicar (QA PASS) |
| **Domingo** | Short (9:16) | De Blender a Godot 4 | *Short #3: De Blender al mundo procedural: ¡el Avatar 3D ya vive en el juego!* | Listo para Publicar (QA PASS) |

---

## 1. Publicación Principal — Devlog Largo Horizontal (16:9)

- **Archivo Master**: `video_edition/media/processed/devlog_texturas_personajes_3d/devlog_texturas_personajes_3d.mp4`
- **Subtítulos Externos CC**: `video_edition/media/processed/devlog_texturas_personajes_3d/devlog_texturas_personajes_3d.srt`
- **Formato**: Horizontal 16:9 (`1920×1080`, `DAR 16:9`, 30 fps) | `2:49 min` (`169.5s`) | Video limpio sin subtítulos quemados, con 5 pop-ups HUD animados y audio nativo del juego (OST adaptativo + SFX espaciales) normalizado a `-16 LUFS`.

### Paquete YouTube
- **Título**: `Craft to Nation | Devlog #6: Nuevas Texturas, Iluminación Nocturna y Población 3D en Godot 4`
- **Descripción**:
```text
¡Craft to Nation da un salto gigante en inmersión! 🛠️✨

En este devlog mostramos cómo luce actualmente el proyecto en Godot 4 tras integrar las nuevas texturas en bloques y entornos junto a la primera población 3D modular: dejamos atrás las cápsulas de prototipo para dar paso a obreros y obreras con cuerpo masculino/femenino, atuendos, herramientas (pico, martillo, hacha y canastas de acarreo en manos o espalda) y 8 animaciones contextuales, además de nuestro Avatar 3D recién salido de Blender.

⏳ Capítulos:
00:00 Introducción y Menú Principal
00:14 1. Bloques Texturizados e Iluminación Nocturna
00:50 2. Población 3D Modular: Obreros con Picos y Canastas
01:36 3. Interiores Amueblados: Camas, Baúles y Ventanas 1/20
02:04 4. Cámara Cenital y ¡el Avatar 3D en Godot 4!

🎮 Descarga y prueba la versión jugable GRATIS en itch.io:
https://crafttonation.itch.io/craft-to-nation

🌐 Sitio Web y Wiki Oficial: https://crafttonation.netlify.app/
💬 Comunidad y Feedback (GitHub Discussions): https://github.com/gigalipa/craft-to-nation/discussions
🔴 Canal Oficial de YouTube: https://www.youtube.com/@crafttonation
🧵 Threads: @crafttonation

¿Qué te parece el cambio frente a los prototipos anteriores? ¿Qué oficio o personaje te gustaría ver animado después? ¡Cuéntanos en comentarios!

#crafttonation #gamedev #indiedev #godotengine #citybuilder #3dcharacters #indiegame
```

### Post para X (Twitter) — Devlog Largo
```text
¡Así luce #CraftToNation ahora mismo en #GodotEngine! 🛠️🌙

Dejamos atrás las cápsulas y bloques planos: nuevas texturas, iluminación nocturna, obreros/obreras 3D con herramientas y nuestro Avatar 3D ya dentro del mundo.

🎮 Pruébalo gratis en itch.io: https://crafttonation.itch.io/craft-to-nation
🌐 https://crafttonation.netlify.app/

#indiedev #gamedev #citybuilder
```

### Post para Threads (`@crafttonation`) — Devlog Largo
```text
¡Qué cambio se siente al recorrer la colonia ahora! 🌙🧱

Acabo de grabar un vistazo directo de Craft to Nation en Godot 4 con las nuevas texturas y los primeros personajes 3D integrados:
• Obreros y obreras 3D picando adentro de los puestos
• Acarreadores moviendo canastas en manos o espalda por las calles iluminadas
• Interiores con camas, baúles y ventanas de 1/20
• ¡Y el Avatar 3D recién salido de Blender ya dentro del mundo!

🎮 Descarga gratis la build jugable actual en itch.io: https://crafttonation.itch.io/craft-to-nation
💬 Feedback en GitHub Discussions: https://github.com/gigalipa/craft-to-nation/discussions
```

### Borrador para GitHub Discussions
**Título:** `✨ Devlog #6: Nuevas texturas en el mundo y llegada de la población 3D a Godot 4`
```markdown
¡Hola a todos!

Quería compartirles este nuevo avance en video mostrando cómo se ve **Craft to Nation** tras integrar las nuevas texturas del entorno y el primer lote de **personajes 3D modulares** en Godot 4:

- **Adiós cápsulas de prototipo:** Los colonos ahora cuentan con cuerpos base masculino/femenino, vestuario de obrero, herramientas (*pico, martillo, hacha y canasta de acarreo en manos o espalda*) y 8 animaciones contextuales según su estado y oficio.
- **Avatar 3D en el mundo:** El primer personaje modelado y riggeado en Blender ya habita el mundo procedural junto a su lámpara térmica.
- **Atmósfera nocturna e interiores:** Iluminación con farolas, bloques texturizados, interiores con camas/baúles y ventanas de $1/20$ de espesor.

🎮 **Descarga la build jugable en itch.io:** https://crafttonation.itch.io/craft-to-nation
🌐 **Web y Wiki Oficial:** https://crafttonation.netlify.app/

¡Cuéntennos en este hilo qué sensaciones les transmite el nuevo apartado visual!
```

### WhatsApp (Estado / Grupos) — Devlog Largo
```text
¡Nuevo avance de *Craft to Nation*! 🛠️🌙
Así se ve ahora mi videojuego en Godot 4 con las nuevas texturas, iluminación nocturna y los primeros personajes 3D trabajando en la colonia.
🎮 Pruébalo gratis en PC desde itch.io 👉 https://crafttonation.itch.io/craft-to-nation
```

---

## 2. Tres Shorts Virales (Formato Vertical 9:16 — 1080×1920)

### Short #1 (Miércoles) — *Texturas y Colonos en Acción* (`34.0s`)
- **Archivo Master**: `video_edition/media/processed/estado_3d_short_01/estado_3d_short_01.mp4`
- **Subtítulos**: Quemados (Trebuchet MS Bold 66pt) + `.ass` y `.srt`.
- **Gancho Inicial (3s)**: *"¡Adiós a las cápsulas y bloques planos!"*
- **Copy TikTok / Reels / Shorts**:
```text
¡Adiós a las cápsulas de prototipo! 🛠️🔥

Así luce ahora Craft to Nation en Godot 4 con nuevas texturas, iluminación nocturna y nuestros primeros obreros y obreras 3D picando y cargando canastas reales dentro de la colonia 🧱⚙️

🎮 Descarga la versión jugable GRATIS para PC en itch.io:
https://crafttonation.itch.io/craft-to-nation

🌐 Web y Wiki: https://crafttonation.netlify.app/
💬 Comunidad: https://github.com/gigalipa/craft-to-nation/discussions

¿Qué te parece la evolución visual? ¡Te leo abajo! 👇

#crafttonation #indiedev #gamedev #godotengine #citybuilder #3dmodeling #indiegame
```
- **X (Twitter)**:
```text
¡Adiós cápsulas! 🛠️🔥 Así luce #CraftToNation con texturas e iluminación y los nuevos obreros/obreras 3D picando en tiempo real en #GodotEngine.

🎮 Pruébalo gratis: https://crafttonation.itch.io/craft-to-nation #indiedev #gamedev
```
- **Threads (`@crafttonation`)**:
```text
Ver pasar el juego de cápsulas de colores a personajes 3D picando y acarreando canastas bajo las farolas da una satisfacción enorme 🥹🛠️

¿Cuál herramienta o animación quieres ver después en la colonia? 👇
🎮 Juega gratis en itch.io: https://crafttonation.itch.io/craft-to-nation
```

---

### Short #2 (Viernes) — *Vida Nocturna en la Colonia* (`33.0s`)
- **Archivo Master**: `video_edition/media/processed/estado_3d_short_02/estado_3d_short_02.mp4`
- **Subtítulos**: Quemados (Trebuchet MS Bold 66pt) + `.ass` y `.srt`.
- **Gancho Inicial (3s)**: *"¿Cómo se vive de noche dentro de tu colonia?"*
- **Copy TikTok / Reels / Shorts**:
```text
¿Cómo se siente caminar de noche por tu propia colonia? 🌙🏮

En Craft to Nation construyes bloque a bloque en 1ª persona, entras a casas con camas, baúles y ventanas de vidrio, y ves a tus acarreadores trabajando bajo las farolas antes de subir a la vista táctica 🏗️✨

🎮 Pruébalo GRATIS en itch.io:
https://crafttonation.itch.io/craft-to-nation

🌐 Web oficial: https://crafttonation.netlify.app/
💬 Feedback: https://github.com/gigalipa/craft-to-nation/discussions

¿Prefieres construir en 1ª persona o dirigir desde arriba? 👇

#crafttonation #indiegame #gamedev #godotengine #citybuilder #survivalgame #indiedev
```
- **X (Twitter)**:
```text
Recorriendo las calles de noche junto a tus obreros en #CraftToNation 🌙🏮 Casas amuebladas, ventanas de vidrio y acarreo real en #GodotEngine.

🎮 Descarga gratis: https://crafttonation.itch.io/craft-to-nation #indiedev #citybuilder
```
- **Threads (`@crafttonation`)**:
```text
Uno de mis momentos favoritos al probar Craft to Nation es caminar de noche en 1ª persona por los edificios que diseñé y cruzarme con los colonos moviendo recursos bajo las farolas 🌙⚙️

¿Eres más de construir desde el suelo o gestionar desde la cámara aérea? 👇
🎮 https://crafttonation.itch.io/craft-to-nation
```

---

### Short #3 (Domingo) — *¡El Avatar 3D ya está en el juego!* (`32.0s`)
- **Archivo Master**: `video_edition/media/processed/estado_3d_short_03/estado_3d_short_03.mp4`
- **Subtítulos**: Quemados (Trebuchet MS Bold 66pt) + `.ass` y `.srt`.
- **Gancho Inicial (3s)**: *"¿Recuerdas el personaje que modelamos en Blender?"*
- **Copy TikTok / Reels / Shorts**:
```text
De Blender directo al mundo procedural en Godot 4 🚀🎮

El primer personaje 3D que estuvimos preparando ya está dentro de Craft to Nation con su lámpara térmica, compartiendo mundo con los obreros y el bosque voxel 🌲✨

🎮 Descarga la versión jugable GRATIS en itch.io:
https://crafttonation.itch.io/craft-to-nation

🌐 Web y Wiki: https://crafttonation.netlify.app/
💬 GitHub Discussions: https://github.com/gigalipa/craft-to-nation/discussions

¿Qué detalle le añadirías al personaje? ¡Cuéntame en comentarios! 👇

#crafttonation #blender3d #godotengine #indiedev #gamedev #characterdesign #indiegame
```
- **X (Twitter)**:
```text
De Blender a #GodotEngine 🚀 ¡El primer Avatar 3D de #CraftToNation ya vive dentro del mundo procedural con su lámpara térmica!

🎮 Juega la build gratis en itch.io: https://crafttonation.itch.io/craft-to-nation #indiedev #blender3d
```
- **Threads (`@crafttonation`)**:
```text
Hace unos días les mostraba el primer personaje en Blender… ¡y hoy ya está dentro del mundo de Craft to Nation en Godot 4! 🎉🧱

Todavía queda mucho por pulir en animaciones y clases de colonos, pero verlo ahí iluminando con su lámpara térmica se siente increíble.

🎮 Prueba el juego gratis en itch.io: https://crafttonation.itch.io/craft-to-nation
```
