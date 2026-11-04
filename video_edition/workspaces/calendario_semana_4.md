# Calendario Editorial - Semana 4: Craft to Nation

**Estrategia de la Semana**: Lanzamiento del Devlog Técnico Especial: *Mi Estación de Trabajo en Antigravity para Desarrollar Craft to Nation*. Exposición detrás de cámaras de la arquitectura de 9 agentes especializados, automatizaciones diarias con Graphify, gestión de cuotas con Model Orchestrator y control de calidad estricto. Difusión multicanal en YouTube, X (Twitter) y Threads, fomentando el debate sobre desarrollo indie asistido por IA responsable y estructurada.

---

## Parrilla de Publicaciones Semanal

| Día | Formato | Pilar de Contenido | Título / Tema Principal | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **Martes** | Devlog Largo Multicámara (16:9) | Detrás de Escenas (Técnico / Tooling) | *Mi Estación de Trabajo de IA para Crear un Videojuego (Antigravity + 8 Agentes)* | Renderizando Master / Listo para QA |
| **Miércoles** | Post de Debate (X / Threads) | Filosofía de Desarrollo & Tooling | *Degradación de Contexto y el Concepto de "Agente Frozen"* | Redactado |
| **Jueves** | Short (9:16) | Inteligencia Artificial & Grafos | *Cómo Graphify evita que la IA alucine en proyectos grandes* | Programado |
| **Viernes** | Short (9:16) | Gamedev & Optimización | *La Filosofía Senior Ponytail: El mejor código es el que no se escribe* | Programado |
| **Sábado** | Post de Comunidad | Ecosistema & Transparencia | *Control Humano en IA: Auditorías programadas sin auto-commits* | Redactado |

---

## Detalle de Entregables y Paquetes de Contenido

### 1. Publicación Principal - Devlog Técnico Multicámara (Martes)
- **Archivo Master**: `video_edition/media/processed/devlog_antigravity_workspace/devlog_antigravity_workspace.mp4`
- **Subtítulos CC**: `video_edition/media/processed/devlog_antigravity_workspace/devlog_antigravity_workspace.srt`
- **Formato**: Horizontal 16:9 (1280x720) | 17:59 min
- **Edición**: Multicámara profesional sincronizada (Plano sobre el hombro con blur atmosférico + Pantalla nativa Antigravity), 10 pop-ups animados Trebuchet MS verde/oro, música ambiental (*Clockwork Logistics*) con ducking y voz normalizada por compresión dinámica.
- **Subtítulos en Video**: Video limpio (Sin subtítulos quemados en imagen; Closed Captions externos `.srt` sincronizados para YouTube).
- **QA Status**: Pendiente de validación final tras render.

#### Paquete de Distribución YouTube:
- **Título**: `Craft to Nation | Mi Estación de Trabajo de IA: 8 Agentes, Graphify y Model Orchestrator`
- **Descripción**:
```markdown
¿Cómo se desarrolla un simulador de colonias y civilizaciones en Godot utilizando IA sin que el código colapse en un mar de alucinaciones?

En este video muestro en detalle cómo tengo configurado mi entorno de trabajo en Antigravity para el desarrollo de Craft to Nation: desde la especialización de 8 agentes dedicados (desarrollo, balance, QA, backlog y redes), hasta el ciclo de vida del contexto («Agente Frozen»), automatizaciones diarias con Graphify y mi propio plugin «Model Orchestrator» para no quemar cuotas de tokens.

⏳ Capítulos y Marcas de Tiempo:
00:00 Introducción: El mito del chat único y la saturación de contexto
00:48 Especialización de Roles: Desarrollo, Balance, QA y Redes
06:22 Degradación de Memoria y el Concepto de "Agente Frozen"
07:18 Reinicio Limpio: Manteniendo la agilidad en sesiones activas
08:35 El Sistema Nervioso: Graphify y navegación de dependencias
10:44 Filosofía Senior: Ponytail, código mínimo y mentalidad YAGNI
11:38 Caja de Herramientas: Superpowers (TDD/SDD) y Remotion
13:10 Plugin Propio: "Model Orchestrator" y gestión inteligente de tokens
15:02 Servidores MCP: Conexión con GitHub, Godot y Netlify
15:52 Automatizaciones en Segundo Plano (Cron 5:00 PM y Auditorías)
16:52 La Regla de Oro: Aprobación humana obligatoria y cierre

🌐 Sitio Web Oficial: https://crafttonation.netlify.app/
💬 Comunidad y Feedback (GitHub Discussions): https://github.com/gigalipa/craft-to-nation/discussions
🔴 Canal Oficial de YouTube: https://www.youtube.com/@crafttonation
🧵 Threads: @crafttonation

Pregunta de debate para la comunidad:
¿Cómo manejas tú el contexto y las tareas repetitivas cuando desarrollas con modelos de lenguaje? ¿Qué opinas de delegar la documentación a tareas cron con aprobación humana previa? Déjanos tu perspectiva en los comentarios.

#crafttonation #gamedev #indiedev #antigravity #aiagents #godotengine #graphify #mcp
```

#### Copys para Redes Sociales:

- **Post en X (Twitter)**:
```text
La mayoría satura un solo chat de IA hasta que olvida funciones previas 📉

Para desarrollar #CraftToNation, convertí @google antigravity en una estación con 8 agentes especializados, navegación por grafos con @graphify y gestión de cuotas de tokens.

🎥 Video completo: https://crafttonation.netlify.app/
💬 Debate en GitHub: https://github.com/gigalipa/craft-to-nation/discussions
```

- **Post en Threads (@crafttonation)**:
```text
¿Cómo evitar que la IA alucine cuando tu proyecto supera los 50 archivos de código? 🧵👇

En el nuevo devlog técnico de Craft to Nation explico nuestra arquitectura:
1. Agentes con roles aislados (Código, QA, Balance, Backlog).
2. El concepto de "Agente Frozen" cuando el contexto se degrada.
3. Graphify como sistema nervioso para consultar dependencias sin comer tokens.
4. Tareas cron diarias con una regla inquebrantable: NINGÚN cambio se aplica sin aprobación humana.

El video completo ya está disponible con desglose paso a paso.
🌐 Web oficial: https://crafttonation.netlify.app/
💬 Súmate a la discusión: https://github.com/gigalipa/craft-to-nation/discussions
```
