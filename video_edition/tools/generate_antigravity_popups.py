import os
from PIL import Image, ImageDraw, ImageFont

POPUP_DIR = "video_edition/media/raw/popups_antigravity"
os.makedirs(POPUP_DIR, exist_ok=True)

POPUPS = [
    {
        "id": 0,
        "time": "00:05",
        "tag": "CRAFT TO NATION  |  DEVLOG TÉCNICO",
        "title": "Mi Estación de Trabajo de IA con Antigravity"
    },
    {
        "id": 1,
        "time": "00:48",
        "tag": "ARQUITECTURA DE AGENTES",
        "title": "1. Especialización de Roles: Desarrollo, Balance, QA y Redes"
    },
    {
        "id": 2,
        "time": "06:24",
        "tag": "INGENIERÍA DE CONTEXTO",
        "title": "2. Degradación de Memoria y el Concepto de 'Agente Frozen'"
    },
    {
        "id": 3,
        "time": "08:35",
        "tag": "GRAFO DE CONOCIMIENTO",
        "title": "3. Graphify: Navegación de Dependencias sin Saturar Contexto"
    },
    {
        "id": 4,
        "time": "10:44",
        "tag": "FILOSOFÍA DE DESARROLLO",
        "title": "4. Ponytail: Código Mínimo y Mentalidad Senior YAGNI"
    },
    {
        "id": 5,
        "time": "11:38",
        "tag": "PLUGINS PROFESIONALES",
        "title": "5. Superpowers (TDD/SDD) y Remotion para Edición de Video"
    },
    {
        "id": 6,
        "time": "13:10",
        "tag": "HERRAMIENTAS PROPIAS",
        "title": "6. Model Orchestrator: Gestión Inteligente de Cuotas y Tokens"
    },
    {
        "id": 7,
        "time": "15:02",
        "tag": "MODEL CONTEXT PROTOCOL",
        "title": "7. Servidores MCP: Conexión con GitHub, Godot y Netlify"
    },
    {
        "id": 8,
        "time": "15:52",
        "tag": "AUTOMATIZACIONES CRON",
        "title": "8. Sincronización Diaria (5:00 PM) y Auditoría Estructural"
    },
    {
        "id": 9,
        "time": "16:52",
        "tag": "CONTROL HUMANO",
        "title": "9. La Regla de Oro: Aprobación Humana Obligatoria"
    }
]

font_bold_path = "C:/Windows/Fonts/trebucbd.ttf" if os.path.exists("C:/Windows/Fonts/trebucbd.ttf") else None
font_regular_path = "C:/Windows/Fonts/trebuc.ttf" if os.path.exists("C:/Windows/Fonts/trebuc.ttf") else font_bold_path

font_tag = ImageFont.truetype(font_regular_path, 13) if font_regular_path else ImageFont.load_default()
font_title = ImageFont.truetype(font_bold_path, 18) if font_bold_path else ImageFont.load_default()

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
    
    out_path = f"{POPUP_DIR}/popup_{p['id']}.png"
    img.save(out_path)
    print(f"Generated {out_path} for '{p['title']}'")

print("All popups generated successfully.")
