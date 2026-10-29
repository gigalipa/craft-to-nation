#!/usr/bin/env python3
"""
tools/verify_wiki_bundle.py
Verifica la integridad del bundle estático compilado de la wiki de Craft to Nation.
"""

import sys
from pathlib import Path

def verify_bundle():
    dist_dir = Path("website/wiki/dist")
    if not dist_dir.exists():
        print(f"FAIL: El directorio de distribución {dist_dir} no existe.")
        return False

    required_files = [
        "index.html",
        "404.html",
        "es/index.html",
        "es/guide/start.html",
        "es/guide/resources.html",
        "es/guide/buildings.html",
        "es/guide/colonists.html",
        "es/guia/inicio.html",
        "es/guia/recursos.html",
        "es/guia/edificios.html",
        "es/guia/colonos.html",
        "es/dev/gdd.html",
        "es/dev/godot.html",
        "es/dev/logistics.html",
        "es/dev/logistica.html",
        "es/dev/roadmap.html",
        "en/index.html",
        "en/guide/start.html",
        "en/guide/resources.html",
        "en/guide/buildings.html",
        "en/guide/colonists.html",
        "en/dev/gdd.html",
        "en/dev/godot.html",
        "en/dev/logistics.html",
        "en/dev/roadmap.html",
        "fr/index.html",
        "fr/guide/start.html",
        "fr/guide/resources.html",
        "fr/guide/buildings.html",
        "fr/guide/colonists.html",
        "fr/dev/gdd.html",
        "fr/dev/godot.html",
        "fr/dev/logistics.html",
        "fr/dev/roadmap.html",
    ]

    missing = []
    for rel_path in required_files:
        f = dist_dir / rel_path
        if not f.exists():
            missing.append(rel_path)

    if missing:
        print(f"FAIL: Archivos requeridos faltantes en {dist_dir}:")
        for m in missing:
            print(f"  - {m}")
        return False

    # Verificar que existen assets JS y CSS
    assets_dir = dist_dir / "assets"
    if not assets_dir.exists():
        print("FAIL: Directorio de assets no encontrado.")
        return False

    js_files = list(assets_dir.glob("*.js"))
    css_files = list(assets_dir.glob("*.css"))

    if not js_files or not css_files:
        print(f"FAIL: Faltan bundles en assets (JS: {len(js_files)}, CSS: {len(css_files)})")
        return False

    # Verificar contenido de la página principal y enlaces al Sitio Principal en los 3 idiomas
    index_content = (dist_dir / "index.html").read_text(encoding="utf-8")
    en_content = (dist_dir / "en/index.html").read_text(encoding="utf-8")
    fr_content = (dist_dir / "fr/index.html").read_text(encoding="utf-8")

    if "Craft to Nation" not in index_content:
        print("FAIL: El archivo index.html no contiene el título esperado de Craft to Nation.")
        return False

    if "Sitio Principal" not in index_content or "https://crafttonation.netlify.app/" not in index_content:
        print("FAIL: El menú en español no contiene 'Sitio Principal' apuntando a la landing page.")
        return False

    if "Main Site" not in en_content or "https://crafttonation.netlify.app/" not in en_content:
        print("FAIL: El menú en inglés no contiene 'Main Site' apuntando a la landing page.")
        return False

    if "Site Principal" not in fr_content or "https://crafttonation.netlify.app/" not in fr_content:
        print("FAIL: El menú en francés no contiene 'Site Principal' apuntando a la landing page.")
        return False

    # Verificar que no existan fórmulas LaTeX crudas ($...$, \times, \text, \rightarrow) en src/
    src_dir = Path("website/wiki/src")
    for md_file in src_dir.rglob("*.md"):
        text = md_file.read_text(encoding="utf-8")
        if "$" in text or "\\times" in text or "\\text{" in text or "\\rightarrow" in text:
            print(f"FAIL: Se detectó sintaxis LaTeX sin procesar en {md_file}")
            return False

    # Verificar que no se use la variable inexistente --vp-c-bg-mute y que ResourceBadge tenga soporte Dark Mode
    theme_dir = Path("website/wiki/.vitepress/theme")
    for style_file in list(theme_dir.rglob("*.vue")) + list(theme_dir.rglob("*.css")):
        content = style_file.read_text(encoding="utf-8")
        if "--vp-c-bg-mute" in content:
            print(f"FAIL: Se detectó uso de variable inexistente --vp-c-bg-mute en {style_file}")
            return False

    recursos_html = (dist_dir / "es/guia/recursos.html").read_text(encoding="utf-8")
    if "--badge-text-dark" not in recursos_html or "--badge-text-light" not in recursos_html:
        print("FAIL: Los badges de recursos no incluyen variables de contraste para modo claro y oscuro.")
        return False

    print("PASS: Verificación del bundle de la wiki aprobada exitosamente.")
    print(f"  Total páginas validadas: {len(required_files)}")
    print(f"  Bundles JS: {len(js_files)} | Bundles CSS: {len(css_files)}")
    return True

if __name__ == "__main__":
    if not verify_bundle():
        sys.exit(1)
