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
        "es/guia/inicio.html",
        "es/guia/recursos.html",
        "es/guia/edificios.html",
        "es/guia/colonos.html",
        "es/dev/gdd.html",
        "es/dev/godot.html",
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

    # Verificar contenido de la página principal
    index_content = (dist_dir / "index.html").read_text(encoding="utf-8")
    if "Craft to Nation" not in index_content:
        print("FAIL: El archivo index.html no contiene el título esperado de Craft to Nation.")
        return False

    print("PASS: Verificación del bundle de la wiki aprobada exitosamente.")
    print(f"  Total páginas validadas: {len(required_files)}")
    print(f"  Bundles JS: {len(js_files)} | Bundles CSS: {len(css_files)}")
    return True

if __name__ == "__main__":
    if not verify_bundle():
        sys.exit(1)
