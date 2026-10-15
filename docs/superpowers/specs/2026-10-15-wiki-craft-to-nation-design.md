# Especificación de Diseño: Wiki Híbrida para Craft to Nation

**Fecha:** 2026-10-15  
**Estado:** Aprobado para Planificación  
**Área:** Documentación, Web & Comunidad  

---

## 1. Visión y Objetivos

El objetivo es crear un sistema de documentación y wiki oficial para *Craft to Nation*, integrado directamente en la estructura web existente (`website/`) y desplegado en Netlify bajo una arquitectura **Docs-as-Code** estática, rápida y sin costos de servidor.

### Objetivos Clave:
1. **Naturaleza Híbrida:** Atender dos audiencias simultáneamente:
   - **Comunidad y Jugadores:** Manual del juego, recetas de crafteo, catálogo de edificios, necesidades de colonos y guías de inicio rápido.
   - **Desarrollo y GDD:** Documentación técnica viva, arquitectura de sistemas en Godot, estado de las PoC, decisiones de diseño y roadmap.
2. **Soporte Multilingüe (i18n):** Idioma principal en Español (`/es/`), soporte paralelo en Inglés (`/en/`), y arquitectura lista para Francés (`/fr/`) a futuro.
3. **Preservación del Plan Gratuito de Netlify:** Compilación local y despliegue manual por CLI, desactivando auto-builds automáticos por cada `git push` para proteger las cuotas mensuales.
4. **Fidelidad de Datos:** Auditoría y sincronización previa de las fichas técnicas contra las mecánicas y código real de Godot antes de redactar valores numéricos.

---

## 2. Arquitectura del Sistema

### 2.1 Ecosistema Tecnológico
* **Generador:** [VitePress](https://vitepress.dev/) (Vite + Vue 3).
* **Runtimes del Entorno:** Node.js v24.x, pnpm v11.x, Python 3.10.x.
* **Paradigma:** Client-First Static Site Generation (SSG). Salida compilada en HTML, CSS y JS puro optimizado.
* **Búsqueda:** MiniSearch local cliente (integrado de forma nativa en VitePress, sin dependencias externas ni indexadores de pago).

### 2.2 Integración en el Directorio `website/`
La landing page actual (`website/index.html`) se mantiene sin alteraciones como la raíz del dominio. La wiki se ubica en `website/wiki/`:

```text
website/
├── index.html              # Landing Page oficial de Craft to Nation
├── styles.css / script.js  # Recursos de la landing
├── assets/                 # Gráficos e ilustraciones compartidas
├── .netlify/               # Configuración local de Netlify CLI
└── wiki/                   # Proyecto VitePress
    ├── package.json        # Dependencias (vitepress) y scripts de build
    ├── .vitepress/
    │   ├── config.mts      # Configuración de rutas, i18n, navbars y sidebars duales
    │   └── theme/          # Paleta visual acorde al estilo del juego
    └── src/                # Archivos fuente en Markdown
        ├── index.md        # Portal de bienvenida / redirección por idioma
        ├── es/             # Español (Predeterminado)
        │   ├── index.md    # Home de la wiki en español
        │   ├── guia/       # Mundo Jugador
        │   │   ├── index.md
        │   │   ├── inicio.md
        │   │   ├── recursos.md
        │   │   ├── edificios.md
        │   │   └── colonos.md
        │   └── dev/        # Mundo Desarrollo & GDD
        │       ├── index.md
        │       ├── gdd.md
        │       ├── godot.md
        │       ├── logistica.md
        │       └── roadmap.md
        ├── en/             # English (Estructura espejo)
        │   ├── index.md
        │   ├── guide/
        │   └── dev/
        └── fr/             # Français (Placeholder estructurado)
            └── index.md
```

### 2.3 Enrutamiento y Navegación Dual
* **Barra Superior (Navbar):**
  * Logo de *Craft to Nation* con enlace a la home de la wiki.
  * Selector de Sección: `Guía del Jugador` | `Desarrollo & GDD`.
  * Selector de Idioma: `🌐 Español` | `English` | `Français`.
  * Buscador rápido integrado.
  * Enlaces externos: Web Principal, Steam (Wishlist) y Discord.
* **Barra Lateral (Sidebar):** Cambia dinámicamente según la sección activa (`guia/` vs `dev/`) y el idioma seleccionado.

---

## 3. Componentes Interactivos y Datos

Al estar basado en Vue 3, las páginas de Markdown pueden incrustar componentes dinámicos cuando sea necesario:
* **`ResourceBadge.vue`:** Muestra un icono y nombre formateado de cualquier recurso (ej. Madera, Piedra, Trigo, Lingotes).
* **`ProductionCalculator.vue`:** Calculadora interactiva donde el usuario ingresa una cantidad de colonos y calcula el consumo diario estimado de agua y comida.
* **Diagramas Mermaid:** Visualización nativa de grafos de transformación (ej. *Árbol $\rightarrow$ Madera en Bruto $\rightarrow$ Tablones $\rightarrow$ Mobiliario*).

---

## 4. Fases de Implementación

### Fase 0: Auditoría y Sincronización de Datos (Pre-requisito)
1. Contrastar `docs/Fichas_Consumo_Produccion.md` y `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` contra las escenas y scripts de `godot/` (recolección, almacenes, necesidades de NPCs).
2. Producir una tabla de referencia consolidada y validada para que los valores mostrados en la wiki sean exactos.

### Fase 1: Scaffolding y Configuración Técnica
1. Inicializar `website/wiki/package.json` con VitePress.
2. Configurar `config.mts` con:
   - Configuración base: `base: '/wiki/'`
   - Detección estricta de enlaces rotos (`checkDeadLinks: true`).
   - Configuración multilingüe completa (`locales` para `root/es`, `en`, `fr`).
   - Navegación dual con sidebars independientes para `guia` y `dev`.
   - Paleta de colores acorde a *Craft to Nation* (tonos tierra, verdes de colonización y detalles oro).

### Fase 2: Redacción e Ingesta de Contenidos Iniciales
1. Crear páginas índice y de bienvenida para `es/` y `en/`.
2. Poblar `es/guia/` con los pilares de supervivencia y gestión del colono.
3. Poblar `es/dev/` con el desglose del GDD y resumen de arquitectura de sistemas.
4. Generar la versión traducida al inglés en `en/`.

### Fase 3: Integración de Build y Despliegue en Netlify
1. Configurar script de compilación en `website/wiki`: `pnpm run build` exporta a `website/wiki/dist/`.
2. Configurar `website/.netlify/netlify.toml` para omitir auto-builds en commits estándar:
   ```toml
   [build]
     ignore = "exit 0"
   ```
3. Establecer el comando de despliegue manual de producción:
   ```powershell
   netlify deploy --prod --dir=website
   ```

---

## 5. Pruebas y Validación

* **Validación de Enlaces (Dead Links):** VitePress valida automáticamente que no existan enlaces rotos internos entre documentos en el paso de build.
* **Previsualización Local:** Ejecución de `pnpm run dev` en `localhost:5173` para revisión visual completa sin coste ni despliegues en la nube.
* **Prueba de Build Limpio:** Confirmar que `pnpm run build` genera todos los bundles HTML sin warnings ni errores.
* **Validación de Cobertura de Idiomas:** Verificar que cada enlace principal en español tenga su contraparte correspondiente en inglés.
