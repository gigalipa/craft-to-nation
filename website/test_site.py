import unittest
from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).parent


class SiteParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.hrefs = []
        self.images = []
        self.inputs = []
        self.scripts = []
        self.text = []
        self.development_entries = []
        self._in_development = False
        self._development_entry = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if "id" in attributes:
            self.ids.add(attributes["id"])
        if tag == "section" and attributes.get("id") == "desarrollo":
            self._in_development = True
        if self._in_development and tag == "div":
            self._development_entry = []
        if tag == "a" and "href" in attributes:
            self.hrefs.append(attributes["href"])
        if tag == "img":
            self.images.append(attributes)
        if tag == "input":
            self.inputs.append(attributes)
        if tag == "script" and "src" in attributes:
            self.scripts.append(attributes["src"])

    def handle_endtag(self, tag):
        if tag == "div" and self._development_entry is not None:
            self.development_entries.append(" ".join("".join(self._development_entry).split()))
            self._development_entry = None
        if tag == "section" and self._in_development:
            self._in_development = False

    def handle_data(self, data):
        self.text.append(data)
        if self._development_entry is not None:
            self._development_entry.append(data)


class CraftToNationSiteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        parser = SiteParser()
        parser.feed((ROOT / "index.html").read_text(encoding="utf-8"))
        cls.site = parser
        cls.parser = parser

    def test_secciones_requeridas(self):
        self.assertTrue({"vision", "experiencia", "inmersion", "sistemas", "desarrollo", "ayudar", "contacto"} <= self.site.ids)

    def test_enlaces_de_contacto(self):
        expected_message = "Hola, vi el sitio de Craft to Nation y me gustaría conocer más sobre el proyecto y cómo puedo ayudar."
        whatsapp = next(link for link in self.site.hrefs if link.startswith("https://wa.me/573208772240"))
        self.assertEqual(expected_message, parse_qs(urlparse(whatsapp).query)["text"][0])

        email = urlparse(next(link for link in self.site.hrefs if link.startswith("mailto:")))
        email_query = parse_qs(email.query)
        self.assertEqual("gigalipa@gmail.com", email.path)
        self.assertEqual("Quiero apoyar Craft to Nation", email_query["subject"][0])
        self.assertEqual(expected_message, email_query["body"][0])

    def test_estado_del_desarrollo(self):
        content = " ".join(self.site.text)
        expected_statuses = {
            "Fase 0": "Completado",
            "Fase 1": "Verificado",
            "Fase 2": "Planeado",
            "Fase 3": "Planeado",
            "Fase 4": "Planeado",
            "Fase 5": "Planeado",
            "Fase 6": "Planeado",
        }
        for phase, status in expected_statuses.items():
            entry = next((entry for entry in self.site.development_entries if phase in entry), None)
            self.assertIsNotNone(entry, phase)
            self.assertIn(status, entry, phase)
        self.assertNotIn("% completado", content.lower())
        for term in ("Blueprints", "JSON", "LAN"):
            self.assertNotRegex(content, re.compile(rf"\b{re.escape(term)}\b", re.IGNORECASE))

    def test_imagenes_tienen_texto_alternativo(self):
        self.assertEqual(9, len(self.site.images))
        self.assertEqual("", self.site.images[0].get("alt"))
        self.assertTrue(all(image.get("alt", "").strip() for image in self.site.images[1:]))
        self.assertEqual(
            [
                "assets/craft-to-nation-mark.png",
                "assets/citycraft-hero.webp",
                "assets/citycraft-world.webp",
                "assets/fp-building.webp",
                "assets/fp-industry.webp",
                "assets/fp-defense.webp",
                "assets/comparison-aerial.webp",
                "assets/fp-defense.webp",
                "assets/craft-to-nation-logo.png",
            ],
            [image.get("src") for image in self.site.images],
        )
        self.assertTrue(all(image.get("width", "").isdigit() and image.get("height", "").isdigit() for image in self.site.images))
        self.assertTrue(all("loading" not in image for image in self.site.images[:2]))
        self.assertTrue(all(image.get("loading") == "lazy" for image in self.site.images[2:]))

    def test_logo_y_favicon_existen(self):
        html = (ROOT / "index.html").read_text(encoding="utf-8")
        self.assertIn('href="favicon.ico"', html)
        self.assertIn('href="assets/favicon-32.png"', html)
        for path in ("favicon.ico", "assets/favicon-32.png", "assets/craft-to-nation-logo.png", "assets/craft-to-nation-mark.png"):
            self.assertTrue((ROOT / path).is_file(), path)

    def test_metadatos_para_compartir(self):
        html = (ROOT / "index.html").read_text(encoding="utf-8")
        expected = {
            'property="og:title" content="Craft to Nation"',
            'property="og:type" content="website"',
            'property="og:url" content="https://crafttonation.netlify.app/"',
            'property="og:image" content="https://crafttonation.netlify.app/assets/craft-to-nation-logo.png"',
            'property="og:image:width" content="512"',
            'property="og:image:height" content="512"',
            'name="twitter:card" content="summary"',
        }
        for metadata in expected:
            self.assertIn(metadata, html)

    def test_logo_completo_encabeza_contacto(self):
        html = (ROOT / "index.html").read_text(encoding="utf-8")
        contacto = html.split('<section id="contacto"', 1)[1].split("</section>", 1)[0]
        self.assertIn('class="contact-logo"', contacto)
        self.assertIn('<h2 id="titulo-contacto"', contacto)
        self.assertLess(contacto.index('class="contact-logo"'), contacto.index('<h2 id="titulo-contacto"'))
        self.assertIn('src="assets/craft-to-nation-logo.png"', contacto)

    def test_local_images_exist(self):
        for image in self.parser.images:
            self.assertTrue((ROOT / image["src"]).is_file(), image["src"])

    def test_accessible_responsive_css_exists(self):
        css = (ROOT / "styles.css").read_text(encoding="utf-8")
        for rule in ("@media (max-width:", "prefers-reduced-motion: reduce", ":focus-visible"):
            self.assertIn(rule, css)
        mobile = css.split("@media (max-width: 760px)", 1)[1].split("@media (prefers-reduced-motion: reduce)", 1)[0]
        self.assertRegex(mobile, r"header\s*{[^}]*flex-wrap:\s*wrap;[^}]*gap:\s*0;")
        self.assertRegex(mobile, r"nav\s*{[^}]*width:\s*100%;")
        self.assertRegex(mobile, r"header\s*>\s*a\s*{[^}]*min-height:\s*44px;[^}]*display:\s*inline-flex;")

    def test_ruta_del_jugador_alinea_puntos_y_conectores(self):
        css = (ROOT / "styles.css").read_text(encoding="utf-8")
        desktop, mobile = css.split("@media (max-width: 760px)", 1)
        mobile = mobile.split("@media (prefers-reduced-motion: reduce)", 1)[0]

        self.assertRegex(desktop, r"#experiencia li::before\s*{[^}]*left:\s*0;")
        self.assertRegex(
            desktop,
            r"#experiencia li:not\(:last-child\)::after\s*{[^}]*left:\s*1\.35rem;[^}]*width:\s*calc\(100% \+ 1rem\);[^}]*height:\s*2px;",
        )
        self.assertRegex(
            mobile,
            r"#experiencia li:not\(:last-child\)::after\s*{[^}]*width:\s*2px;[^}]*height:\s*100%;",
        )

    def test_comparador_de_perspectivas_es_accesible(self):
        control = next((item for item in self.site.inputs if item.get("id") == "perspective-control"), None)
        self.assertIsNotNone(control)
        self.assertEqual("range", control.get("type"))
        self.assertEqual(("0", "100", "50"), (control.get("min"), control.get("max"), control.get("value")))
        self.assertTrue(control.get("aria-label", "").strip())
        self.assertEqual(["script.js"], self.site.scripts)

        script_path = ROOT / "script.js"
        self.assertTrue(script_path.is_file())
        script = script_path.read_text(encoding="utf-8")
        self.assertIn('addEventListener("input"', script)
        self.assertIn('style.setProperty("--position"', script)


if __name__ == "__main__":
    unittest.main()
