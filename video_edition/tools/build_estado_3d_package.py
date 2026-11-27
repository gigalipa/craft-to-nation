import os
import shutil
import subprocess
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SRC_VIDEO = "video_edition/media/raw/done/avance_texturas_personajes_2026-11-26.mp4"
OVERLAY_DIR = "video_edition/media/raw/overlays_estado_3d"
PROCESSED_DIR = "video_edition/media/processed"

FONT_BOLD = "C:/Windows/Fonts/trebucbd.ttf"
FONT_REG = "C:/Windows/Fonts/trebuc.ttf"


def format_ass_time(sec: float) -> str:
    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = int(sec % 60)
    cs = min(99, int(round((sec - int(sec)) * 100)))
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def format_srt_time(sec: float) -> str:
    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = int(sec % 60)
    ms = min(999, int(round((sec - int(sec)) * 1000)))
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def write_srt(path: str, cues: list[tuple[float, float, str]]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        for i, (st, end, text) in enumerate(cues, 1):
            f.write(f"{i}\n{format_srt_time(st)} --> {format_srt_time(end)}\n{text}\n\n")


def write_ass(path: str, cues: list[tuple[float, float, str]]) -> None:
    header = """[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Trebuchet MS,66,&H00FFFFFF,&H000000FF,&H00000000,&HB00B1A0D,-1,0,0,0,100,100,0,0,3,6,0,2,65,65,420,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    lines = [header]
    for st, end, text in cues:
        lines.append(f"Dialogue: 0,{format_ass_time(st)},{format_ass_time(end)},Default,,0,0,0,,{text}\n")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)


def fit_font(draw: ImageDraw.ImageDraw, text: str, font_path: str, start_size: int, max_width: int) -> ImageFont.FreeTypeFont:
    size = start_size
    while size > 12:
        font = ImageFont.truetype(font_path, size)
        bb = draw.textbbox((0, 0), text, font=font)
        if (bb[2] - bb[0]) <= max_width:
            return font
        size -= 1
    return ImageFont.truetype(font_path, 12)


def generate_popup_png(pid: int, tag: str, title: str) -> str:
    os.makedirs(OVERLAY_DIR, exist_ok=True)
    W, H = 580, 78
    img = Image.new("RGBA", (W, H), (13, 42, 18, 235))
    draw = ImageDraw.Draw(img)
    draw.rectangle([(0, 0), (W - 1, H - 1)], outline=(246, 196, 36, 255), width=2)
    draw.rectangle([(0, 0), (5, H - 1)], fill=(246, 196, 36, 255))

    f_tag = fit_font(draw, tag, FONT_BOLD, 14, W - 36)
    f_title = fit_font(draw, title, FONT_BOLD, 19, W - 36)
    draw.text((20, 12), tag, fill=(246, 196, 36, 255), font=f_tag)
    draw.text((20, 36), title, fill=(255, 255, 255, 255), font=f_title)

    out_path = f"{OVERLAY_DIR}/popup_{pid}.png"
    img.save(out_path)
    return out_path


def generate_short_header_png(sid: str, tag: str, title: str) -> str:
    os.makedirs(OVERLAY_DIR, exist_ok=True)
    img = Image.new("RGBA", (1080, 270), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(
        [110, 105, 970, 235],
        radius=18,
        fill=(11, 26, 13, 225),
        outline=(246, 196, 36, 255),
        width=3,
    )
    f_tag = fit_font(draw, tag, FONT_BOLD, 28, 810)
    f_title = fit_font(draw, title, FONT_BOLD, 42, 810)
    b1 = draw.textbbox((0, 0), tag, font=f_tag)
    b2 = draw.textbbox((0, 0), title, font=f_title)
    draw.text(((1080 - (b1[2] - b1[0])) // 2, 122), tag, font=f_tag, fill=(246, 196, 36, 255))
    draw.text(((1080 - (b2[2] - b2[0])) // 2, 166), title, font=f_title, fill=(255, 255, 255, 255))

    out_path = f"{OVERLAY_DIR}/header_{sid}.png"
    img.save(out_path)
    return out_path


def encode_with_fallback(cmd_nvenc: list[str], cmd_x264: list[str], label: str) -> None:
    print(f"Rendering {label}...")
    t0 = time.time()
    try:
        subprocess.run(cmd_nvenc, check=True)
    except subprocess.CalledProcessError:
        print(f"NVENC failed for {label}, falling back to libx264...")
        subprocess.run(cmd_x264, check=True)
    print(f"Finished {label} in {time.time() - t0:.1f}s.")


def build_long_devlog() -> None:
    out_dir = f"{PROCESSED_DIR}/devlog_texturas_personajes_3d"
    os.makedirs(out_dir, exist_ok=True)
    out_mp4 = f"{out_dir}/devlog_texturas_personajes_3d.mp4"
    out_srt = f"{out_dir}/devlog_texturas_personajes_3d.srt"

    total_dur = 169.5

    srt_cues = [
        (1.0, 6.5, "Bienvenidos al nuevo avance visual de Craft to Nation en Godot 4."),
        (7.0, 14.0, "Iniciamos desde el menú principal con el slideshow animado de la colonia."),
        (15.0, 24.5, "Así luce el mundo de noche con los nuevos materiales y texturas PBR."),
        (25.0, 32.0, "Observa a nuestros obreros 3D desplazándose con canastas de acarreo."),
        (32.5, 42.0, "En el interior del taller: obreros y obreras 3D picando en tiempo real."),
        (43.0, 56.0, "Las calles iluminadas conectan puestos y viviendas con relieve real."),
        (57.0, 74.0, "Ocho clips de animación se eligen dinámicamente según oficio y movimiento."),
        (76.0, 88.0, "Visitamos el interior amueblado de las casas: camas, baúles y ventanas 1/20."),
        (89.0, 106.0, "La canasta de carga alterna entre manos y espalda durante el acarreo."),
        (107.0, 120.0, "Recorremos el límite con el bosque procedural bajo la luz nocturna."),
        (121.0, 136.0, "Cambiamos a la cámara cenital táctica para ver todo el asentamiento vivo."),
        (137.0, 149.0, "Incluso los árboles y el terreno cobran nueva profundidad con las texturas."),
        (150.0, 161.0, "Acercamiento al Avatar 3D recién integrado desde Blender con lámpara térmica."),
        (161.5, 168.5, "Prueba la build jugable gratis en crafttonation.itch.io/craft-to-nation."),
    ]
    write_srt(out_srt, srt_cues)

    popups = [
        (0, 1.5, 6.5, "CRAFT TO NATION · DEVLOG VISUAL", "Texturas PBR y Población 3D en Godot 4"),
        (1, 15.5, 21.5, "NUEVO APARTADO VISUAL", "1. Bloques Texturizados e Iluminación Nocturna"),
        (2, 32.0, 38.0, "POBLACIÓN 3D MODULAR", "2. Obreros y Obreras con Picos y Canastas"),
        (3, 78.0, 84.0, "VIDA EN LA COLONIA", "3. Interiores: Camas, Baúles y Ventanas 1/20"),
        (4, 150.0, 156.5, "DE BLENDER A GODOT 4", "4. ¡El Avatar 3D Ya Está Dentro del Mundo!"),
    ]

    inputs = ["-i", SRC_VIDEO]
    for pid, _, _, tag, title in popups:
        png = generate_popup_png(pid, tag, title)
        inputs.extend(["-loop", "1", "-i", png])

    steps = [
        # Trim & xfade video (14.5 + 155.5 - 0.5 = 169.5s)
        "[0:v]trim=start=0.0:end=14.5,setpts=PTS-STARTPTS,fps=30,setsar=1[v0]",
        "[0:v]trim=start=49.5:end=205.0,setpts=PTS-STARTPTS,fps=30,setsar=1[v1]",
        "[v0][v1]xfade=transition=fade:duration=0.5:offset=14.0,setsar=1[v_joined]",
        # Acrossfade + loudnorm audio
        "[0:a]atrim=start=0.0:end=14.5,asetpts=PTS-STARTPTS[a0]",
        "[0:a]atrim=start=49.5:end=205.0,asetpts=PTS-STARTPTS[a1]",
        f"[a0][a1]acrossfade=d=0.5:c1=tri:c2=tri,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=out:st={total_dur - 1.5}:d=1.5[a_out]",
    ]

    curr_v = "v_joined"
    for idx, (pid, st, end, _, _) in enumerate(popups):
        inp_idx = 1 + idx
        steps.append(
            f"[{inp_idx}:v]format=rgba,setsar=1,fade=t=in:st={st}:d=0.4:alpha=1,fade=t=out:st={end - 0.4}:d=0.4:alpha=1[pop_{pid}]"
        )
        next_v = f"v_pop_{pid}"
        steps.append(
            f"[{curr_v}][pop_{pid}]overlay=1308:62:enable='between(t,{st},{end})',setsar=1[{next_v}]"
        )
        curr_v = next_v

    fg = ";".join(steps)
    base = [
        "ffmpeg", "-y",
        *inputs,
        "-filter_complex", fg,
        "-map", f"[{curr_v}]",
        "-map", "[a_out]",
    ]
    tail = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", str(total_dur), out_mp4]
    cmd_nvenc = base + ["-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "8000k", "-maxrate", "10000k", "-bufsize", "16000k", "-pix_fmt", "yuv420p", "-r", "30"] + tail
    cmd_x264 = base + ["-c:v", "libx264", "-crf", "18", "-preset", "fast", "-pix_fmt", "yuv420p", "-r", "30"] + tail
    encode_with_fallback(cmd_nvenc, cmd_x264, "16:9 Long Devlog")


SHORTS = [
    {
        "id": "estado_3d_short_01",
        "tag": "CRAFT TO NATION · DEVLOG 3D",
        "title": "TEXTURAS Y COLONOS EN ACCIÓN",
        "segments": [(50.0, 62.5), (67.5, 73.5), (74.0, 89.5)],
        "duration": 34.0,
        "subs": [
            (0.3, 5.0, "¡Adiós a las cápsulas y bloques planos!"),
            (5.2, 12.2, "Así luce ahora Craft to Nation con texturas e iluminación."),
            (12.5, 18.3, "¡Mira a los nuevos obreros y obreras 3D picando adentro!"),
            (18.6, 26.5, "Cada colono cambia de herramienta y carga canastas reales."),
            (26.8, 33.6, "¡Ya puedes probar el juego gratis en itch.io!"),
        ],
    },
    {
        "id": "estado_3d_short_02",
        "tag": "CRAFT TO NATION · INMERSIÓN",
        "title": "VIDA NOCTURNA EN LA COLONIA",
        "segments": [(93.5, 102.5), (113.5, 120.0), (128.0, 145.5)],
        "duration": 33.0,
        "subs": [
            (0.3, 5.0, "¿Cómo se vive de noche dentro de tu colonia?"),
            (5.2, 8.9, "En 1ª persona recorres las calles junto a tus obreros."),
            (9.1, 15.3, "Entras a las casas con camas, baúles y ventanas de vidrio."),
            (15.6, 25.4, "Afuera, los acarreadores suben recursos bajo las farolas."),
            (25.7, 32.6, "Construye bloque a bloque y gestiónalo desde el aire."),
        ],
    },
    {
        "id": "estado_3d_short_03",
        "tag": "CRAFT TO NATION · GODOT 4",
        "title": "¡EL AVATAR 3D YA ESTÁ EN EL JUEGO!",
        "segments": [(162.0, 174.0), (179.5, 193.0), (198.5, 205.0)],
        "duration": 32.0,
        "subs": [
            (0.3, 5.5, "¿Recuerdas el personaje que modelamos en Blender?"),
            (5.7, 12.0, "¡Ya vive dentro del mundo procedural en Godot 4!"),
            (12.3, 18.8, "Desde la cámara cenital ves a los obreros trabajando..."),
            (19.0, 25.4, "...y aquí está nuestro Avatar 3D con su lámpara térmica."),
            (25.6, 31.6, "¿Qué te parece el cambio visual? ¡Pruébalo en itch.io!"),
        ],
    },
]


def build_short(info: dict) -> None:
    sid = info["id"]
    out_dir = f"{PROCESSED_DIR}/{sid}"
    os.makedirs(out_dir, exist_ok=True)
    out_mp4 = f"{out_dir}/{sid}.mp4"
    ass_path = f"{out_dir}/{sid}.ass"
    srt_path = f"{out_dir}/{sid}.srt"
    dur = info["duration"]

    write_ass(ass_path, info["subs"])
    write_srt(srt_path, info["subs"])
    hdr_png = generate_short_header_png(sid, info["tag"], info["title"])
    ass_esc = ass_path.replace("\\", "/").replace(":", "\\:")

    steps = []
    v_nodes = []
    a_nodes = []
    for idx, (st, end) in enumerate(info["segments"]):
        seg_dur = end - st
        steps.append(f"[0:v]trim=start={st}:end={end},setpts=PTS-STARTPTS,fps=30,setsar=1[vs_{idx}]")
        steps.append(
            f"[0:a]atrim=start={st}:end={end},asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.05,afade=t=out:st={seg_dur - 0.05}:d=0.05[as_{idx}]"
        )
        v_nodes.append(f"[vs_{idx}]")
        a_nodes.append(f"[as_{idx}]")

    n = len(info["segments"])
    steps.append("".join(v_nodes) + f"concat=n={n}:v=1:a=0,setsar=1[v_cat]")
    steps.append("".join(a_nodes) + f"concat=n={n}:v=0:a=1,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=out:st={dur - 1.5}:d=1.5[a_out]")

    steps.extend([
        "[v_cat]split=2[bg_src][fg_src]",
        "[bg_src]crop=980:918:470:52,scale=120:213,scale=1080:1920:flags=bilinear,eq=brightness=-0.14,setsar=1[bg]",
        "[fg_src]crop=980:918:470:52,scale=1080:1012:flags=lanczos,setsar=1[fg]",
        "[bg][fg]overlay=0:270,setsar=1[v_comp]",
        "[v_comp]drawbox=x=0:y=267:w=1080:h=3:color=#F6C424:t=fill,drawbox=x=0:y=1282:w=1080:h=3:color=#F6C424:t=fill[v_framed]",
        "[v_framed][1:v]overlay=0:0,setsar=1[v_hdr]",
        f"[v_hdr]ass='{ass_esc}'[v_out]",
    ])
    fg = ";".join(steps)

    base = [
        "ffmpeg", "-y",
        "-i", SRC_VIDEO,
        "-i", hdr_png,
        "-filter_complex", fg,
        "-map", "[v_out]",
        "-map", "[a_out]",
    ]
    tail = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", str(dur), out_mp4]
    cmd_nvenc = base + ["-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "6000k", "-maxrate", "8000k", "-bufsize", "12000k", "-pix_fmt", "yuv420p", "-r", "30"] + tail
    cmd_x264 = base + ["-c:v", "libx264", "-crf", "18", "-preset", "fast", "-pix_fmt", "yuv420p", "-r", "30"] + tail
    encode_with_fallback(cmd_nvenc, cmd_x264, f"9:16 Short ({sid})")


if __name__ == "__main__":
    assert Path(SRC_VIDEO).exists(), f"Missing source video: {SRC_VIDEO}"
    try:
        build_long_devlog()
        for s in SHORTS:
            build_short(s)
    finally:
        shutil.rmtree(OVERLAY_DIR, ignore_errors=True)
    print("All 4 deliverables built and temporary overlays cleaned!")
