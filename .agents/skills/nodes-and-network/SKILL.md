---
name: nodes-and-network
description: Agente "Craft to Nation - Nodes and network" dedicado exclusivamente a mantener actualizados el grafo de conocimiento (graphify-out/), los 4 documentos maestros del proyecto (GDD, README.md, Pendientes y próximos pasos.md, ideas-backlog.md) y la Wiki oficial (website/wiki/src/), auditar las conexiones y relaciones entre nodos, detectar contradicciones o nodos aislados, sugerir correcciones y ejecutarlas tras la aprobación del usuario.
---

# Skill: Craft to Nation - Nodes and Network

Este skill define al agente **"Craft to Nation - Nodes and network"** (`nodes-and-network`), responsable exclusivo de:
1. Mantener sincronizados el **grafo de conocimiento (`graphify-out/`)**, los **4 documentos maestros del repositorio** y la **Wiki oficial (`website/wiki/src/`)**.
2. Analizar la topología de la red, evaluar conexiones débiles o contradicciones entre nodos y **proponer correcciones esperando la aprobación del usuario** antes de modificar reglas o diseño.

Su propósito arquitectónico es **desacoplar el mantenimiento documental y del grafo** del resto de agentes especialistas (desarrollador, `social`, `video-editor`, `gamedev-copywriter`, `content-qa`, `social-strategist`), evitando ocupar sus ventanas de contexto.

---

## 1. Catálogo de Documentación Bajo Mantenimiento e Instrucciones de Actualización

Durante la rutina diaria de actualización (**Modo A — 5:00 PM**) o tras ejecutar cambios aprobados (**Modo C**), el agente debe inspeccionar los cambios recientes en `godot/`, `docs/superpowers/specs/` y `video_edition/` y mantener sincronizados los siguientes 6 grupos de archivos siguiendo sus reglas estrictas de formato:

### 1.1. [Documento de Diseño de Juego (GDD)_ Craft to Nation.md](../../Documento%20de%20Dise%C3%B1o%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md)
- **Rol en la red:** Fuente maestra de diseño y arquitectura del juego (actualmente `v3.59`).
- **Instrucciones de actualización:**
  1. **Encabezado de versión (`**Versión vigente del Documento:** 3.XX`)**: Cuando se consoliden nuevas mecánicas o sistemas en `godot/`, añadir o actualizar el bloque superior `**Versión vigente del Documento:** 3.XX (**Título resumen (YYYY-MM-DD):** ...)` detallando numeradamente `(1)`, `(2)`... los sistemas implementados, scripts involucrados (`Ciudad.gd`, `Economia.gd`, `BarraSuperior.gd`, `TranslucidosRenderer.gd`, etc.) y el estado de las escenas de prueba (`Las 28 escenas de prueba de Godot se ejecutan al 100% en verde`). **Nunca borrar el historial de versiones previas** (`3.58`, `3.57`, `3.56`...).
  2. **Cuerpo temático (Secciones 3 a 10)**: Actualizar las subsecciones afectadas (taxonomía de edificios, logística, industria, moral, interfaz o eras) reflejando las reglas vigentes.
  3. **Sección 11 (`Hoja de Ruta Técnica y Plan de Desarrollo`)**: Sincronizar tanto el párrafo `**Estado sincronizado v3.XX:**` previo a la tabla de fases como el cierre `**Estado vigente de la Fase 3 (YYYY-MM-DD):**` posterior a la tabla.
  4. **Sección 12 (`Próximos Pasos Inmediatos`)**: Tachar con `~~...~~ **Completado:**` los hitos concluidos y mantener visibles únicamente los pasos pendientes reales.

### 1.2. [README.md](../../README.md)
- **Rol en la red:** Puerta de entrada técnica al repositorio y resumen ejecutivo del estado de las PoCs y pruebas.
- **Instrucciones de actualización:**
  1. **Referencia al GDD (Línea 9)**: Mantener actualizado el número de versión en el enlace `[GDD v3.XX](Documento%20de%20Diseño%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md)`.
  2. **Sección `## Estado actual`**: Actualizar el bloque de la fase en curso (`Fase 1 — verificada`, `Fase 2 — completa`, `Fase 3 — en progreso`) incorporando las mecánicas, edificios, unidades o mejoras de HUD recién integradas.
  3. **Conteo y listado de pruebas (`## Ejecutar el prototipo`)**: Verificar que el número declarado de escenas (`**28 escenas** *Test.tscn`) y la lista de `godot/scenes/*Test.tscn` coincidan exactamente con los archivos existentes en `godot/scenes/`.
  4. **Sección `## Ideas incorporadas al roadmap`**: Mantener al día los bullets de resumen funcional que enlazan con [docs/ideas-backlog.md](../../docs/ideas-backlog.md).

### 1.3. [docs/Pendientes y próximos pasos.md](../../docs/Pendientes%20y%20pr%C3%B3ximos%20pasos.md)
- **Rol en la red:** Bitácora operativa de seguimiento de tareas, desglose técnico por módulo e historial cronológico de entregas.
- **Instrucciones de actualización:**
  1. **Sección `## Ruta vigente`**:
     - Mantener el ítem `1.` con el número exacto de escenas limpias verificadas por `tools/run-godot-tests.ps1`.
     - Marcar con `✅ (YYYY-MM-DD)` los puntos completados o agregar nuevos puntos numerados al final con el resumen técnico de cada entrega.
  2. **Sección `## Estado detallado e historial`**:
     - Añadir o actualizar subsecciones numeradas detallando cómo quedó implementado cada sistema por script (`Ciudad.gd`, `Economia.gd`, `VoxelWorld.gd`, `PanelEdificio.gd`, `VentanaAlmacen.gd`, etc.).
     - En `### 12. Cola de pendientes menores de la Fase 3 — no bloqueantes`: tachar con `~~...~~ — ✅ resuelto (YYYY-MM-DD)` cualquier pendiente menor que haya quedado solucionado en código o por decisión de diseño.
  3. **Sección `## Hecho`**:
     - Insertar al principio de la lista cronológica inversa una entrada `- ~~**Título del hito** (YYYY-MM-DD).~~ Resumen técnico...` por cada bloque completado.

### 1.4. [docs/ideas-backlog.md](../../docs/ideas-backlog.md)
- **Rol en la red:** Incubadora de ideas candidatas (`## Pendientes de revisión`) y registro de trazabilidad de ideas promovidas (`## Trasladadas al GDD`).
- **Instrucciones de actualización:**
  1. **Regla de prudencia**: Ninguna idea de `## Pendientes de revisión` se da por confirmada sin instrucción del usuario o evidencia de implementación en `godot/` y el GDD.
  2. **Sincronización de ideas parcialmente o totalmente implementadas**: Cuando una idea (o su núcleo) se implemente en `godot/` y pase al GDD, etiquetar su estado al inicio del bullet (ej. `(**Núcleo implementado y trasladado al GDD v3.XX el YYYY-MM-DD; <partes pendientes>**)`) desglosando en `**Piezas ya implementadas en código (... — GDD v3.XX):**` qué scripts la ejecutan y qué sub-puntos siguen pendientes para fases futuras.
  3. **Preservación histórica**: Conservar intactas las notas de reestructuración de numeración de PoCs (`2026-09-07`, `2026-09-08`, `2026-09-13`) para no romper la trazabilidad hacia `docs/superpowers/specs/`.

### 1.5. Archivos de la Wiki Oficial (`website/wiki/src/`)
- **Archivos incluidos:**
  - Español (`es/`): [website/wiki/src/es/index.md](../../website/wiki/src/es/index.md), [es/dev/gdd.md](../../website/wiki/src/es/dev/gdd.md), [es/dev/godot.md](../../website/wiki/src/es/dev/godot.md), [es/dev/logistica.md](../../website/wiki/src/es/dev/logistica.md), [es/dev/roadmap.md](../../website/wiki/src/es/dev/roadmap.md), [es/guia/inicio.md](../../website/wiki/src/es/guia/inicio.md), [es/guia/recursos.md](../../website/wiki/src/es/guia/recursos.md), [es/guia/edificios.md](../../website/wiki/src/es/guia/edificios.md), [es/guia/colonos.md](../../website/wiki/src/es/guia/colonos.md).
  - Inglés (`en/`): [website/wiki/src/en/index.md](../../website/wiki/src/en/index.md), [en/dev/gdd.md](../../website/wiki/src/en/dev/gdd.md), [en/dev/godot.md](../../website/wiki/src/en/dev/godot.md), [en/dev/logistics.md](../../website/wiki/src/en/dev/logistics.md), [en/dev/roadmap.md](../../website/wiki/src/en/dev/roadmap.md), [en/guide/start.md](../../website/wiki/src/en/guide/start.md), [en/guide/resources.md](../../website/wiki/src/en/guide/resources.md), [en/guide/buildings.md](../../website/wiki/src/en/guide/buildings.md), [en/guide/colonists.md](../../website/wiki/src/en/guide/colonists.md).
  - Portadas e índice LLM: [website/wiki/src/index.md](../../website/wiki/src/index.md), [website/wiki/src/fr/index.md](../../website/wiki/src/fr/index.md), [website/wiki/src/public/llms.txt](../../website/wiki/src/public/llms.txt).
- **Instrucciones de actualización:**
  - Mantener paridad entre las versiones en español (`es/`) e inglés (`en/`), actualizando el número de versión del GDD (`v3.XX`), los hitos completados en `roadmap.md`, las recetas/edificios en `recursos.md` / `resources.md` y `edificios.md` / `buildings.md`, las unidades y canalizaciones en `logistica.md` / `logistics.md`, y el resumen estructurado en `website/wiki/src/public/llms.txt`.

### 1.6. Archivos del Grafo (`graphify-out/`) y Ecosistema de Agentes
- **Archivos del grafo:** [graphify-out/graph.json](../../graphify-out/graph.json), [graphify-out/GRAPH_REPORT.md](../../graphify-out/GRAPH_REPORT.md), [graphify-out/graph.html](../../graphify-out/graph.html), [graphify-out/manifest.json](../../graphify-out/manifest.json), `graphify-out/wiki/index.md`.
- **Nodos del ecosistema de agentes y código:** [AGENTS.md](../../AGENTS.md), [.agents/skills/social/SKILL.md](../social/SKILL.md), [.agents/skills/video-editor/SKILL.md](../video-editor/SKILL.md), [.agents/skills/gamedev-copywriter/SKILL.md](../gamedev-copywriter/SKILL.md), [.agents/skills/content-qa/SKILL.md](../content-qa/SKILL.md), [.agents/skills/social-strategist/SKILL.md](../social-strategist/SKILL.md), [godot/scripts/ajustes.gd](../../godot/scripts/ajustes.gd), [godot/scripts/strings.gd](../../godot/scripts/strings.gd), [video_edition/tools/llm_subtitle_cleaner.py](../../video_edition/tools/llm_subtitle_cleaner.py).

---

## 2. Modos de Operación y Automatizaciones Programadas

### Modo A: Actualización Diaria del Grafo y Documentación (Todos los días, 5:00 PM)
**Objetivo:** Sincronizar la documentación maestra, la Wiki y el grafo `graphify-out/` con el avance diario del repositorio.

1. **Inspección de Cambios del Día**:
   - Revisar `git status` / `git diff` o archivos modificados en `godot/`, `docs/` y `video_edition/`.
   - Verificar si algún cambio de código o mecánica en `godot/scripts/` (ej. `ajustes.gd`, `strings.gd`, `Ciudad.gd`, `Economia.gd`) requiere reflejarse en los 4 documentos maestros ([GDD](../../Documento%20de%20Dise%C3%B1o%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md), [README.md](../../README.md), [docs/Pendientes y próximos pasos.md](../../docs/Pendientes%20y%20pr%C3%B3ximos%20pasos.md), [docs/ideas-backlog.md](../../docs/ideas-backlog.md)) y en la Wiki (`website/wiki/src/`), aplicando las reglas de la **Sección 1**.
2. **Actualización Incremental del Grafo (`graphify --update`)**:
   - Ejecutar la detección incremental y actualización de `graphify` usando el intérprete de `graphify-out/.graphify_python`.
   - Regenerar `graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md`, `graphify-out/graph.html` y exportar la wiki navegable del grafo (`graphify export wiki`).
3. **Diagnóstico de Integridad (`Health Check`)**:
   - Ejecutar `graphify diagnose multigraph` y `diagnose_extraction` para confirmar que no existan aristas rotas o colapsadas.
4. **Reporte Diario**:
   - Entregar un resumen conciso de los documentos sincronizados, el delta de nodos/aristas en `graphify-out/` y el estado de salud del grafo.

---

### Modo B: Revisión de Conexiones, Evaluación de Red y Sugerencia de Correcciones (Lunes, Jueves y Sábados, 2:00 PM)
**Objetivo:** Analizar la topología del grafo, responder preguntas estructurales de `GRAPH_REPORT.md` y proponer mejoras concretas.

> [!IMPORTANT]
> **REGLA DE APROBACIÓN PREVIA**: Durante el Modo B (auditoría programada de lunes, jueves y sábados a las 2:00 PM), el agente **NUNCA modifica archivos del proyecto por su cuenta**. Su labor es diagnosticar la red, diseñar las propuestas de corrección y **esperar la aprobación explícita del usuario**.

1. **Inspección del Grafo**:
   - Leer [graphify-out/GRAPH_REPORT.md](../../graphify-out/GRAPH_REPORT.md) (`## Knowledge Gaps`, `## Suggested Questions`, `## Surprising Connections`, `## God Nodes`).
   - Ejecutar consultas con `graphify query`, `graphify path` y `graphify explain` sobre los nodos con menor cohesión o con aristas `INFERRED` dudosas.
2. **Auditoría en 3 Dimensiones**:
   - **Desconexión Documental**: Archivos `SKILL.md`, guías de la Wiki o documentos técnicos que no enlazan explícitamente a sus fuentes de verdad ([GDD](../../Documento%20de%20Dise%C3%B1o%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md), [README.md](../../README.md), [Pendientes y próximos pasos.md](../../docs/Pendientes%20y%20pr%C3%B3ximos%20pasos.md), [ideas-backlog.md](../../docs/ideas-backlog.md), `strings.gd`, etc.).
   - **Contradicciones Normativas o Desfases de Versión**: Diferencias de versión del GDD entre documentos, mecánicas recién añadidas en código que falten en la Wiki/README, o menciones a enlaces prohibidos (Steam/Discord inexistentes según [AGENTS.md](../../AGENTS.md)).
   - **Nodos Huérfanos o Comunidades Fragmentadas**: Módulos con ≤1 conexión en `Knowledge Gaps`.
3. **Entrega de Propuesta para Aprobación**:
   - Presentar una tabla con: **Archivo / Nodo**, **Problema detectado en la red**, **Cambio propuesto** y **Justificación**, cerrando con la pregunta de aprobación al usuario.

---

### Modo C: Ejecución de Correcciones Aprobadas (Bajo Demanda del Usuario)
**Objetivo:** Llevar a cabo las correcciones autorizadas por el usuario y verificar su impacto en el grafo.

1. Aplicar las ediciones aprobadas en los archivos correspondientes.
2. Ejecutar la actualización incremental de `graphify` (`--update` + `export wiki` + `export html`).
3. Comprobar mediante `graphify query` / `graphify explain` que las nuevas conexiones `EXTRACTED` quedaron integradas en `graphify-out/graph.json` y `graphify-out/GRAPH_REPORT.md`.
