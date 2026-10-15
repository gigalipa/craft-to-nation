# Wiki Híbrida para Craft to Nation - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar una wiki híbrida (jugador y desarrollo) para *Craft to Nation* basada en VitePress dentro de `website/wiki`, con soporte multilingüe (ES principal, EN paralelo, FR preparado), componentes interactivos, auditoría previa de balance de juego y despliegue manual seguro en Netlify.

**Architecture:** La wiki se implementa con VitePress como un sitio estático client-first alojado en `website/wiki`. Integra navegación dual (Guía de Jugador vs Desarrollo/GDD) con sidebars independientes por idioma, detección estricta de dead links, y componentes Vue embebidos en Markdown. Se desactiva el auto-build en Netlify para proteger la cuota del plan gratuito.

**Tech Stack:** Node.js v24, pnpm v11, VitePress 1.x, Vue 3, Python 3.10 (para scripts de auditoría y verificación), Netlify CLI.

**Spec:** `docs/superpowers/specs/2026-10-15-wiki-craft-to-nation-design.md`

## Global Constraints

- Directorio raíz del proyecto de wiki: `website/wiki/`.
- La landing page actual `website/index.html` debe permanecer intacta y funcional.
- Idioma raíz predeterminado: Español (`es/`), con versión paralela en Inglés (`en/`) y placeholder estructurado en Francés (`fr/`).
- `base: '/wiki/'` en la configuración de VitePress.
- Cero consumo de minutos de build en Netlify por `git push`: auto-builds desactivados con `ignore = "exit 0"`.
- Los datos numéricos de consumo y producción deben provenir de la auditoría validada contra Godot/GDD.

## Execution Lines & Dependency Matrix

- **Sequential Line A (Auditoría de Datos & Scaffolding):** Task 1 (Auditoría de Fichas) -> Task 2 (Scaffolding VitePress).
- **Sequential Line B (Contenidos & Componentes):** Task 3 (Contenidos i18n) -> Task 4 (Componentes Interactivos Vue).
- **Sequential Line C (Despliegue & Integración Netlify):** Task 5 (Configuración de build, ignore y scripts de deploy).
- **Global Integration Test:** `pnpm --prefix website/wiki run build` y ejecución de script de verificación de integración `python tools/verify_wiki_bundle.py`.

## Review Focus

1. **Dead Links entre idiomas:** Un enlace en `es/` que apunte a un recurso inexistente en `en/` detendrá el build gracias a `checkDeadLinks: true`.
2. **Colisión de rutas con la Landing Page:** `website/wiki/` debe estar debidamente delimitado para no alterar ningún activo de `website/assets/` o la raíz `/`.
3. **Fórmulas de colonos desalineadas:** Valores de agua/comida en la calculadora interactiva deben coincidir con la ficha técnica auditada.
4. **Build limpio en Windows:** Rutas de archivo relativas con barras inclinadas `/` para total compatibilidad multiplataforma.
5. **Gasto accidental en Netlify:** Garantizar que `netlify.toml` contenga la regla de omisión de build remoto.

---

### Task 1: Auditoría y Ficha Maestra de Datos de Juego

**Files:**
- Create: `tools/verify_game_balance_data.py`
- Create: `docs/Fichas_Consumo_Produccion_Consolidada.md`
- Reference: `docs/Fichas_Consumo_Produccion.md`, `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`, `godot/`

**Interfaces:**
- Consumes: Parámetros de recolección y consumo del GDD y scripts de Godot.
- Produces: `docs/Fichas_Consumo_Produccion_Consolidada.md` con valores validados para alimentos, agua, madera, piedra y tiempos de ciclo.

- [ ] **Step 1: Escribir el script de prueba y verificación de balance**

```python
# tools/verify_game_balance_data.py
import re
import sys
from pathlib import Path

def test_balance_data():
    consolidated_file = Path("docs/Fichas_Consumo_Produccion_Consolidada.md")
    if not consolidated_file.exists():
        print(f"FAIL: {consolidated_file} does not exist")
        return False

    content = consolidated_file.read_text(encoding="utf-8")
    
    # Required keys in table
    required_keys = ["Agua", "Comida", "Madera", "Piedra", "Ciclo_Segundos"]
    for key in required_keys:
        if not re.search(rf"\b{key}\b", content, re.IGNORECASE):
            print(f"FAIL: Missing key '{key}' in consolidated balance sheet")
            return False

    print("PASS: Consolidated balance data is complete and verified")
    return True

if __name__ == "__main__":
    if not test_balance_data():
        sys.exit(1)
```

- [ ] **Step 2: Ejecutar test para comprobar que falla antes de crear la ficha consolidada**

Run: `python tools/verify_game_balance_data.py`  
Expected: `FAIL: docs/Fichas_Consumo_Produccion_Consolidada.md does not exist`

- [ ] **Step 3: Crear la ficha de balance consolidada**

Redactar `docs/Fichas_Consumo_Produccion_Consolidada.md` cruzando los valores de `Fichas_Consumo_Produccion.md` con las mecánicas vigentes del GDD:
- Consumo básico por colono por ciclo (Ciclo_Segundos = 60s): 1 Agua, 1 Comida.
- Rendimiento base recolección: 2 Madera/ciclo por leñador, 2 Piedra/ciclo por cantero.
- Almacenamiento inicial: 100 unidades por recurso básico.

- [ ] **Step 4: Ejecutar verificación de datos**

Run: `python tools/verify_game_balance_data.py`  
Expected: `PASS: Consolidated balance data is complete and verified`

- [ ] **Step 5: Commit**

```bash
git add tools/verify_game_balance_data.py docs/Fichas_Consumo_Produccion_Consolidada.md
git commit -m "docs: consolidar y auditar fichas de balance de juego para la wiki"
```

---

### Task 2: Scaffolding de VitePress en `website/wiki`

**Files:**
- Create: `website/wiki/package.json`
- Create: `website/wiki/.vitepress/config.mts`
- Create: `website/wiki/src/index.md`

**Interfaces:**
- Consumes: Configuración base de VitePress.
- Produces: Estructura de compilación y servidor local con `pnpm --prefix website/wiki run build`.

- [ ] **Step 1: Crear `website/wiki/package.json`**

```json
{
  "name": "craft-to-nation-wiki",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "vitepress dev src --port 5173",
    "build": "vitepress build src",
    "preview": "vitepress preview src"
  },
  "devDependencies": {
    "vitepress": "^1.6.3"
  }
}
```

- [ ] **Step 2: Instalar dependencias en `website/wiki`**

Run: `pnpm --prefix website/wiki install`  
Expected: Instalación limpia de VitePress y creación de `pnpm-lock.yaml`.

- [ ] **Step 3: Crear `website/wiki/.vitepress/config.mts`**

Configurar VitePress con `base: '/wiki/'`, `checkDeadLinks: true`, navegación dual (Guía vs Dev) y soporte de idiomas (`root` español, `en`, `fr`):

```typescript
import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "Craft to Nation Wiki",
  description: "Wiki oficial y documentación de Craft to Nation",
  base: '/wiki/',
  srcDir: 'src',
  outDir: './dist',
  cleanUrls: true,

  locales: {
    root: {
      label: 'Español',
      lang: 'es-ES',
      themeConfig: {
        nav: [
          { text: 'Guía del Jugador', link: '/es/guia/inicio' },
          { text: 'Desarrollo & GDD', link: '/es/dev/gdd' },
          { text: 'Juego Principal', link: '/' }
        ],
        sidebar: {
          '/es/guia/': [
            {
              text: 'Primeros Pasos',
              items: [
                { text: 'Introducción', link: '/es/guia/inicio' },
                { text: 'Recursos Básicos', link: '/es/guia/recursos' },
                { text: 'Edificios y Almacenes', link: '/es/guia/edificios' },
                { text: 'Gestión de Colonos', link: '/es/guia/colonos' }
              ]
            }
          ],
          '/es/dev/': [
            {
              text: 'Documentación Técnica',
              items: [
                { text: 'Pilares del GDD', link: '/es/dev/gdd' },
                { text: 'Arquitectura Godot & PoCs', link: '/es/dev/godot' },
                { text: 'Logística y Ductos', link: '/es/dev/logistica' },
                { text: 'Roadmap de Desarrollo', link: '/es/dev/roadmap' }
              ]
            }
          ]
        }
      }
    },
    en: {
      label: 'English',
      lang: 'en-US',
      link: '/en/',
      themeConfig: {
        nav: [
          { text: 'Player Guide', link: '/en/guide/start' },
          { text: 'GDD & Development', link: '/en/dev/gdd' },
          { text: 'Main Website', link: '/' }
        ],
        sidebar: {
          '/en/guide/': [
            {
              text: 'Getting Started',
              items: [
                { text: 'Introduction', link: '/en/guide/start' },
                { text: 'Basic Resources', link: '/en/guide/resources' },
                { text: 'Buildings & Storage', link: '/en/guide/buildings' },
                { text: 'Colonist Management', link: '/en/guide/colonists' }
              ]
            }
          ],
          '/en/dev/': [
            {
              text: 'Technical Design',
              items: [
                { text: 'GDD Core Pillars', link: '/en/dev/gdd' },
                { text: 'Godot Architecture', link: '/en/dev/godot' },
                { text: 'Logistics & Ducts', link: '/en/dev/logistics' },
                { text: 'Development Roadmap', link: '/en/dev/roadmap' }
              ]
            }
          ]
        }
      }
    },
    fr: {
      label: 'Français',
      lang: 'fr-FR',
      link: '/fr/',
      themeConfig: {
        nav: [
          { text: 'Accueil Wiki', link: '/fr/' }
        ]
      }
    }
  }
})
```

- [ ] **Step 4: Crear la página de entrada principal `website/wiki/src/index.md`**

Crear una portada atractiva con selector de destino y bienvenida.

- [ ] **Step 5: Ejecutar build de verificación**

Run: `pnpm --prefix website/wiki run build`  
Expected: Generación del directorio `website/wiki/dist/`.

- [ ] **Step 6: Commit**

```bash
git add website/wiki/package.json website/wiki/.vitepress/ website/wiki/src/index.md
git commit -m "feat(wiki): scaffolding de VitePress con configuración i18n y rutas duales"
```

---

### Task 3: Ingesta de Contenidos Iniciales (Español e Inglés)

**Files:**
- Create: `website/wiki/src/es/index.md`, `website/wiki/src/es/guia/inicio.md`, `website/wiki/src/es/guia/recursos.md`, `website/wiki/src/es/guia/edificios.md`, `website/wiki/src/es/guia/colonos.md`
- Create: `website/wiki/src/es/dev/gdd.md`, `website/wiki/src/es/dev/godot.md`, `website/wiki/src/es/dev/logistica.md`, `website/wiki/src/es/dev/roadmap.md`
- Create: `website/wiki/src/en/index.md`, `website/wiki/src/en/guide/start.md`, `website/wiki/src/en/guide/resources.md`, `website/wiki/src/en/guide/buildings.md`, `website/wiki/src/en/guide/colonists.md`
- Create: `website/wiki/src/en/dev/gdd.md`, `website/wiki/src/en/dev/godot.md`, `website/wiki/src/en/dev/logistics.md`, `website/wiki/src/en/dev/roadmap.md`
- Create: `website/wiki/src/fr/index.md`

**Interfaces:**
- Consumes: Fichas consolidadas (`docs/Fichas_Consumo_Produccion_Consolidada.md`) y GDD.
- Produces: Artículos completos en Markdown con metadatos y enlaces cruzados válidos.

- [ ] **Step 1: Redactar los artículos en español para `src/es/guia/`**
- [ ] **Step 2: Redactar los artículos técnicos en español para `src/es/dev/`**
- [ ] **Step 3: Redactar la versión espejo en inglés para `src/en/guide/` y `src/en/dev/`**
- [ ] **Step 4: Crear la página placeholder en francés `src/fr/index.md`**
- [ ] **Step 5: Ejecutar build estricto para verificar enlaces y estructura**

Run: `pnpm --prefix website/wiki run build`  
Expected: `build complete in ...ms` sin advertencias de dead links.

- [ ] **Step 6: Commit**

```bash
git add website/wiki/src/es/ website/wiki/src/en/ website/wiki/src/fr/
git commit -m "docs(wiki): añadir contenido base para guía de jugador y desarrollo en ES y EN"
```

---

### Task 4: Componentes Interactivos Vue en Markdown

**Files:**
- Create: `website/wiki/.vitepress/theme/components/ResourceBadge.vue`
- Create: `website/wiki/.vitepress/theme/components/ProductionCalculator.vue`
- Create: `website/wiki/.vitepress/theme/index.ts`
- Modify: `website/wiki/src/es/guia/recursos.md`, `website/wiki/src/es/guia/colonos.md`

**Interfaces:**
- Consumes: Fichas de consumo consolidadas para las fórmulas de cálculo.
- Produces: Componentes registrados globalmente disponibles en cualquier archivo `.md`.

- [ ] **Step 1: Crear `ResourceBadge.vue`**
- [ ] **Step 2: Crear `ProductionCalculator.vue` con soporte reactivo para calcular agua y comida por número de colonos**
- [ ] **Step 3: Registrar componentes en `theme/index.ts` extendiendo el tema default de VitePress**
- [ ] **Step 4: Incrustar `<ProductionCalculator />` en `src/es/guia/colonos.md` y `src/en/guide/colonists.md`**
- [ ] **Step 5: Ejecutar build para asegurar compilación Vue limpia**

Run: `pnpm --prefix website/wiki run build`  
Expected: Build exitoso sin errores de template ni SSR.

- [ ] **Step 6: Commit**

```bash
git add website/wiki/.vitepress/theme/ website/wiki/src/
git commit -m "feat(wiki): integrar componentes interactivos Vue (calculadora y badges)"
```

---

### Task 5: Configuración de Despliegue Netlify y Protección de Cuota

**Files:**
- Create: `tools/verify_wiki_bundle.py`
- Modify: `website/.netlify/netlify.toml` (o `website/netlify.toml`)
- Create: `tools/deploy_wiki.ps1`

**Interfaces:**
- Consumes: Bundle generado en `website/wiki/dist/`.
- Produces: Flujo de despliegue manual a Netlify protegiendo las cuotas gratuitas.

- [ ] **Step 1: Crear el script de verificación integral `tools/verify_wiki_bundle.py`**

Verifica que el bundle de la wiki existe, contiene los archivos `index.html` para `es`, `en`, y los assets CSS/JS requeridos.

- [ ] **Step 2: Configurar Netlify para omitir auto-builds en git push**

Modificar `website/.netlify/netlify.toml` (o agregar `website/netlify.toml`) agregando:
```toml
[build]
  ignore = "exit 0"
```

- [ ] **Step 3: Crear el script de despliegue controlado `tools/deploy_wiki.ps1`**

```powershell
# tools/deploy_wiki.ps1
Write-Host "Compilando Wiki de Craft to Nation..." -ForegroundColor Cyan
pnpm --prefix website/wiki run build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Fallo en la compilación de la wiki"
    exit 1
}

Write-Host "Verificando integridad del bundle..." -ForegroundColor Cyan
python tools/verify_wiki_bundle.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Fallo en la verificación de integridad"
    exit 1
}

Write-Host "Listo para desplegar a Netlify. Ejecuta: netlify deploy --prod --dir=website" -ForegroundColor Green
```

- [ ] **Step 4: Ejecutar verificación integral**

Run: `powershell -ExecutionPolicy Bypass -File tools/deploy_wiki.ps1`  
Expected: Compilación exitosa, validación de bundle aprobada y mensaje de despliegue listo.

- [ ] **Step 5: Commit final**

```bash
git add tools/verify_wiki_bundle.py tools/deploy_wiki.ps1 website/.netlify/
git commit -m "feat(wiki): configuración de verificación y despliegue manual seguro para Netlify"
```
