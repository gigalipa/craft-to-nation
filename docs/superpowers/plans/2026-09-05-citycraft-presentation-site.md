# CityCraft Presentation Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir una landing estática en español que presente la visión completa de CityCraft, muestre su progreso real y facilite apoyo por WhatsApp o correo.

**Architecture:** Un solo documento semántico contiene todo el contenido y usa anclas nativas para navegar. Una hoja CSS implementa la dirección visual “Frontera viva”, adaptación móvil y accesibilidad; dos imágenes conceptuales locales aportan el acabado PBR/low-poly sin depender de servicios externos.

**Tech Stack:** HTML5, CSS3 y Python 3 estándar para la prueba de humo; sin framework, paquetes, backend ni JavaScript.

**Spec:** `docs/superpowers/specs/2026-09-05-citycraft-presentation-site-design.md`

## Global Constraints

- Crear todo el sitio publicable dentro de `website/`.
- Escribir el contenido en español para público técnico y no técnico.
- Priorizar la visión futura, pero marcar claramente el estado real del desarrollo.
- Usar la dirección visual aprobada “Frontera viva”.
- Usar `+57 320 877 2240` y `gigalipa@gmail.com` como únicos contactos.
- No añadir framework, gestor de paquetes, backend, formulario, analítica ni CMS.
- No inventar porcentajes de avance.
- Identificar las imágenes generadas como visualizaciones conceptuales.
- No hay pasos de commit: `CityCraft` no es actualmente un repositorio Git.

## File Structure

- Create: `website/index.html` — contenido, navegación semántica y enlaces de contacto.
- Create: `website/styles.css` — sistema visual, layouts adaptables y accesibilidad.
- Create: `website/assets/citycraft-hero.png` — imagen conceptual principal.
- Create: `website/assets/citycraft-world.png` — panorama conceptual de los sistemas conectados.
- Create: `website/test_site.py` — prueba estándar, sin dependencias, del contrato mínimo del sitio.

---

### Task 1: Contenido y estructura semántica

**Files:**
- Create: `website/test_site.py`
- Create: `website/index.html`

**Interfaces:**
- Consumes: GDD actualizado y especificación aprobada.
- Produces: secciones con identificadores `vision`, `experiencia`, `sistemas`, `desarrollo`, `ayudar` y `contacto`; enlaces externos listos para estilizar.

- [ ] **Step 1: Write the failing contract test**

Crear `website/test_site.py` con `unittest`, `html.parser.HTMLParser` y `pathlib.Path`. La prueba debe:

```python
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).parent


class SiteParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links, self.images = set(), [], []

    def handle_starttag(self, tag, attrs):
        data = dict(attrs)
        if "id" in data:
            self.ids.add(data["id"])
        if tag == "a" and "href" in data:
            self.links.append(data["href"])
        if tag == "img":
            self.images.append(data)


class SiteContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.html = (ROOT / "index.html").read_text(encoding="utf-8")
        cls.parser = SiteParser()
        cls.parser.feed(cls.html)

    def test_required_sections_exist(self):
        self.assertTrue({"vision", "experiencia", "sistemas", "desarrollo", "ayudar", "contacto"} <= self.parser.ids)

    def test_contacts_are_correct(self):
        links = "\n".join(map(unquote, self.parser.links))
        self.assertIn("https://wa.me/573208772240", links)
        self.assertIn("Hola, vi el sitio de CityCraft", links)
        self.assertIn("mailto:gigalipa@gmail.com", links)

    def test_progress_is_honest(self):
        self.assertIn("Completado", self.html)
        self.assertIn("En validación", self.html)
        self.assertIn("Planeado", self.html)
        self.assertNotIn("% completado", self.html.lower())

    def test_images_have_alt_text(self):
        self.assertTrue(self.parser.images)
        self.assertTrue(all(image.get("alt", "").strip() for image in self.parser.images))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python website/test_site.py`

Expected: ERROR con `FileNotFoundError` para `website/index.html`.

- [ ] **Step 3: Create the minimal semantic page**

Crear `website/index.html` con:

- `<html lang="es">`, viewport, descripción y enlace a `styles.css`.
- Encabezado con logotipo textual y enlaces a `#vision`, `#desarrollo` y `#ayudar`.
- Hero con “Sobrevive · Construye · Lidera”, el titular “Una ciudad levantada con tus propias manos” y enlaces a `#vision` y `#ayudar`.
- `#experiencia`: cuatro pasos — Sobrevive, Funda, Automatiza, Lidera.
- `#sistemas`: cámara dual, blueprints, población viva, logística, combate táctico y multijugador.
- `#desarrollo`: Fase 0 “Completado”; PoC 3 “En validación”; Fases 2–6 “Planeado”.
- `#ayudar`: difusión, retroalimentación/pruebas, programación y financiación.
- `#contacto`: enlaces completos:

```html
<a href="https://wa.me/573208772240?text=Hola%2C%20vi%20el%20sitio%20de%20CityCraft%20y%20me%20gustar%C3%ADa%20conocer%20m%C3%A1s%20sobre%20el%20proyecto%20y%20c%C3%B3mo%20puedo%20ayudar.">Escribir por WhatsApp</a>
<a href="mailto:gigalipa@gmail.com?subject=Quiero%20apoyar%20CityCraft&amp;body=Hola%2C%20vi%20el%20sitio%20de%20CityCraft%20y%20me%20gustar%C3%ADa%20conocer%20m%C3%A1s%20sobre%20el%20proyecto%20y%20c%C3%B3mo%20puedo%20ayudar.">Enviar un correo</a>
```

- Dos `<img>` con rutas `assets/citycraft-hero.png` y `assets/citycraft-world.png`, texto alternativo descriptivo y leyenda visible “Visualización conceptual”.
- Pie que diga “CityCraft es un proyecto independiente actualmente en desarrollo”.

- [ ] **Step 4: Run the contract test**

Run: `python website/test_site.py`

Expected: cuatro pruebas PASS aunque las imágenes todavía no existan.

---

### Task 2: Arte conceptual original

**Files:**
- Create: `website/assets/citycraft-hero.png`
- Create: `website/assets/citycraft-world.png`
- Modify: `website/test_site.py`

**Interfaces:**
- Consumes: rutas de imágenes declaradas en `index.html` y dirección “Frontera viva”.
- Produces: dos PNG locales sin texto incrustado, seguros para recorte con `object-fit: cover`.

- [ ] **Step 1: Extend the failing asset test**

Añadir a `SiteContractTest`:

```python
def test_local_images_exist(self):
    for image in self.parser.images:
        self.assertTrue((ROOT / image["src"]).is_file(), image["src"])
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python website/test_site.py`

Expected: FAIL para `assets/citycraft-hero.png`.

- [ ] **Step 3: Generate the hero image**

Usar ImageGen con este prompt y guardar el resultado como `website/assets/citycraft-hero.png`:

```text
Wide cinematic key art for an original indie strategy city-builder named CityCraft, no text or logos. A warm living frontier settlement made of simple voxel-like block architecture with realistic PBR stone, timber and metal materials; foreground seen from a human first-person height with a handcrafted shelter and a few friendly low-poly settlers; the settlement grows toward an industrial fortified city in the distance with workshops, rail lines, farms and amber window lights. Green hills and vegetation, sunrise breaking through soft mist, hopeful but grounded mood, polished game concept art, clear large shapes, earthy green and warm amber palette, not Minecraft, no copyrighted characters, 16:9 composition with calm dark negative space on the left for website headline.
```

- [ ] **Step 4: Generate the systems panorama**

Usar ImageGen con este prompt y guardar el resultado como `website/assets/citycraft-world.png`:

```text
Wide elevated three-quarter concept view of an original living voxel city-builder world, no text or logos. Show one connected city ecosystem: green residential and research core, adjacent stone-and-metal industrial district, remote mine and lumber camp, farms, roads, railway, conveyor belts and pipes visibly connecting the districts, small low-poly citizens and soldiers, fortified perimeter and watchtower. Realistic PBR material textures on simple block geometry, warm daylight and amber industrial glow, welcoming natural landscape combined with mature frontier industry, detailed but readable, 16:9.
```

- [ ] **Step 5: Inspect both images and rerun tests**

Abrir ambas imágenes y confirmar: no texto deformado, no logotipos, lectura clara en 16:9 y coherencia visual entre ellas.

Run: `python website/test_site.py`

Expected: cinco pruebas PASS.

---

### Task 3: Dirección visual y adaptación móvil

**Files:**
- Create: `website/styles.css`
- Modify: `website/test_site.py`

**Interfaces:**
- Consumes: clases y secciones semánticas de `index.html`.
- Produces: presentación “Frontera viva” usable desde 320 px y compatible con movimiento reducido.

- [ ] **Step 1: Extend the failing CSS contract test**

Añadir:

```python
def test_accessible_responsive_css_exists(self):
    css = (ROOT / "styles.css").read_text(encoding="utf-8")
    self.assertIn("@media (max-width:", css)
    self.assertIn("prefers-reduced-motion: reduce", css)
    self.assertIn(":focus-visible", css)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python website/test_site.py`

Expected: ERROR con `FileNotFoundError` para `website/styles.css`.

- [ ] **Step 3: Implement the visual system**

Crear `website/styles.css` con estos tokens y reglas:

```css
:root {
  --ink: #121815;
  --surface: #1b241f;
  --surface-soft: #263329;
  --paper: #f3e8d1;
  --muted: #b7bba9;
  --amber: #e4a847;
  --leaf: #71845f;
  --line: rgba(243, 232, 209, 0.16);
  --serif: Georgia, "Times New Roman", serif;
  --sans: Inter, ui-sans-serif, system-ui, sans-serif;
}
```

- Fondo carbón/verde oscuro, texto crema y acento ámbar; no cargar fuentes externas.
- Contenedor central de máximo `1180px` y separación fluida con `clamp()`.
- Hero de dos columnas; imagen a sangre en un lateral y degradado que conserva legibilidad del titular.
- Títulos serif expresivos y cuerpo sans-serif legible.
- Pasos de experiencia conectados como progresión y tarjetas sobrias para sistemas/ayuda.
- Estado del desarrollo en una línea temporal con las etiquetas Completado, En validación y Planeado, acompañadas por texto además de color.
- Enlaces de contacto como botones grandes; WhatsApp es primario y correo secundario.
- Textura visual mediante degradados CSS discretos, sin descargar mapas PBR solo para decoración.
- `:focus-visible` con contorno ámbar de al menos `3px`.
- `@media (max-width: 760px)` para apilar columnas, simplificar navegación y mantener objetivos táctiles de al menos `44px`.
- `@media (prefers-reduced-motion: reduce)` para eliminar desplazamiento suave y transiciones.

- [ ] **Step 4: Run the complete automated check**

Run: `python website/test_site.py`

Expected: seis pruebas PASS.

---

### Task 4: Verificación visual y entrega

**Files:**
- Modify: `website/index.html` solo si la inspección encuentra contenido cortado, enlaces ambiguos o jerarquía incorrecta.
- Modify: `website/styles.css` solo si la inspección encuentra desbordamiento, contraste insuficiente o controles pequeños.

**Interfaces:**
- Consumes: sitio estático completo.
- Produces: entrega verificada y lista para abrir o publicar posteriormente.

- [ ] **Step 1: Start a local HTTP server**

Run from the project root:

```powershell
python -m http.server 8000 --directory "C:\Users\peraz\Projects\Misc\CityCraft\website"
```

Expected: servidor disponible en `http://localhost:8000/` sin respuestas 404.

- [ ] **Step 2: Inspect desktop layout**

Abrir `http://localhost:8000/` a 1440 × 900 y comprobar: hero legible, ambas imágenes visibles, orden narrativo claro, estados de progreso diferenciados y ausencia de desplazamiento horizontal.

- [ ] **Step 3: Inspect mobile layout**

Abrir la misma URL a 390 × 844 y comprobar: navegación usable, columnas apiladas, texto sin recortes, botones de contacto de al menos 44 px y ausencia de desplazamiento horizontal.

- [ ] **Step 4: Verify links without sending messages**

Inspeccionar los destinos de WhatsApp y correo. Confirmar número, destinatario y mensaje prediseñado, pero no enviar comunicaciones externas.

- [ ] **Step 5: Run final verification**

Run: `python website/test_site.py`

Expected: seis pruebas PASS.

- [ ] **Step 6: Stop the local server and report the deliverable**

Entregar enlaces locales a `website/index.html`, `website/styles.css` y la prueba. Indicar que publicación, dominio, analítica y pagos siguen fuera de alcance.
