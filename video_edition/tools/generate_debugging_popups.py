import os
from PIL import Image, ImageDraw, ImageFont

POPUP_DIR = "video_edition/media/raw/popups_debugging"
os.makedirs(POPUP_DIR, exist_ok=True)

POPUPS = [
    {
        "id": 0,
        "tag": "CRAFT TO NATION  |  DEVLOG TÉCNICO",
        "title": "Sesión de Debugging en Vivo: 9 Bugs y 1 Sugerencia de QA"
    },
    {
        "id": 1,
        "tag": "INGENIERÍA DE CONTEXTO",
        "title": "1. Rastreo de Subgrafos y Dependencias de Código"
    },
    {
        "id": 2,
        "tag": "CONTROL HUMANO",
        "title": "2. Plan de Corrección Estructurado (Aprobación Requerida)"
    },
    {
        "id": 3,
        "tag": "DESARROLLO SISTEMÁTICO (TDD)",
        "title": "3. Cirugía en GDScript: Vías, Desahucios y Ventanas 3D"
    },
    {
        "id": 4,
        "tag": "SUITES DE PRUEBA GODOT",
        "title": "4. La Prueba de Fuego: Ejecución Masiva de 28 Tests"
    },
    {
        "id": 5,
        "tag": "VERIFICACIÓN FINAL",
        "title": "5. 28/28 Tests en Verde: Sincronización y Cierre"
    }
]

font_bold_path = "C:/Windows/Fonts/trebucbd.ttf"
font_regular_path = "C:/Windows/Fonts/trebuc.ttf"

font_tag = ImageFont.truetype(font_regular_path, 13)
font_title = ImageFont.truetype(font_bold_path, 18)

W, H = 580, 76

for p in POPUPS:
    img = Image.new("RGBA", (W, H), (13, 42, 18, 235))
    draw = ImageDraw.Draw(img)
    
    # Gold border
    draw.rectangle([(0, 0), (W - 1, H - 1)], outline=(212, 175, 55, 255), width=2)
    # Left gold accent bar
    draw.rectangle([(0, 0), (6, H - 1)], fill=(212, 175, 55, 255))
    
    # Tag
    draw.text((22, 12), p["tag"], fill=(212, 175, 55, 255), font=font_tag)
    # Title
    draw.text((22, 34), p["title"], fill=(255, 255, 255, 255), font=font_title)
    
    pid = p["id"]
    out_path = f"{POPUP_DIR}/popup_{pid}.png"
    img.save(out_path)
    print(f"Generated {out_path} for '{p['title']}'")

print("All debugging popups generated successfully.")
