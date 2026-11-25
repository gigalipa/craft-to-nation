import os
import subprocess
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SRC_VIDEO = "video_edition/media/raw/done/personajes_3d_blender_2026-11-23.mp4"
BGM_MUSIC = "godot/assets/musica/Frontier Blueprint (building).mp3"
OVERLAY_DIR = "video_edition/media/raw/overlays_personajes"

SHORT_DIR = "video_edition/media/processed/personajes_3d_short_01"
TEASER_DIR = "video_edition/media/processed/personajes_3d_teaser_16x9"

FONT_BOLD = "C:/Windows/Fonts/trebucbd.ttf"
FONT_REG = "C:/Windows/Fonts/trebuc.ttf"

# Trims silent pauses & menu hesitations -> 30.6s dynamic timeline
CUTS = [
    (0.0, 2.8),    # Clay mesh rotating
    (4.7, 15.6),   # Material Preview reveal + 360 textured orbit
    (21.8, 23.2),  # Orbit to side profile in Pose Mode
    (24.3, 29.0),  # Lifting LeftUpperArm bone smoothly
    (29.0, 30.6),  # Orbiting back to front view
    (34.6, 43.8),  # Character waving hello
]
TOTAL_DUR = 30.6

SUBTITLES = [
    (0.3, 3.2, "¡Craft to Nation empieza a cobrar vida!"),
    (3.3, 8.0, "Ya empecé a crear los personajes 3D del juego."),
    (8.1, 13.5, "Así luce el primer modelo texturizado en Blender."),
    (13.7, 19.8, "No es solo una estatua: ya tiene rig completo."),
    (20.0, 25.3, "Listo para animarlo e integrarlo pronto en Godot 4."),
    (25.4, 30.3, "¡Te saluda desde el taller! ¿Qué clase quieres ver primero?"),
]


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


def write_subtitles(out_dir: str, stem: str, write_ass: bool = True) -> tuple[str, str]:
    srt_path = f"{out_dir}/{stem}.srt"
    with open(srt_path, "w", encoding="utf-8") as f:
        for i, (st, end, text) in enumerate(SUBTITLES, 1):
            f.write(f"{i}\n{format_srt_time(st)} --> {format_srt_time(end)}\n{text}\n\n")

    ass_path = f"{out_dir}/{stem}.ass"
    if write_ass:
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
        for st, end, text in SUBTITLES:
            lines.append(f"Dialogue: 0,{format_ass_time(st)},{format_ass_time(end)},Default,,0,0,0,,{text}\n")
        with open(ass_path, "w", encoding="utf-8") as f:
            f.writelines(lines)
    return ass_path, srt_path


def generate_overlays() -> tuple[str, str]:
    os.makedirs(OVERLAY_DIR, exist_ok=True)

    # 1. Short Header Overlay (1080x270 RGBA)
    short_header_path = f"{OVERLAY_DIR}/short_header.png"
    img = Image.new("RGBA", (1080, 270), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Semi-transparent dark obsidian pill centered (x=140..940, y=105..235) with gold border
    draw.rounded_rectangle(
        [140, 105, 940, 235],
        radius=18,
        fill=(11, 26, 13, 225),
        outline=(246, 196, 36, 255),
        width=3,
    )
    f_sub = ImageFont.truetype(FONT_BOLD, 28)
    f_main = ImageFont.truetype(FONT_BOLD, 42)

    line1 = "CRAFT TO NATION · DEVLOG 3D"
    line2 = "PRIMER PERSONAJE EN BLENDER"
    b1 = draw.textbbox((0, 0), line1, font=f_sub)
    b2 = draw.textbbox((0, 0), line2, font=f_main, stroke_width=1)
    w1 = b1[2] - b1[0]
    w2 = b2[2] - b2[0]
    draw.text(((1080 - w1) // 2, 122), line1, font=f_sub, fill=(246, 196, 36, 255))
    draw.text(((1080 - w2) // 2, 166), line2, font=f_main, fill=(255, 255, 255, 255))
    img.save(short_header_path)

    # 2. Horizontal Lower-Third Overlay (680x105 RGBA)
    lt_path = f"{OVERLAY_DIR}/lower_third_16x9.png"
    lt = Image.new("RGBA", (680, 105), (0, 0, 0, 0))
    dl = ImageDraw.Draw(lt)
    dl.rounded_rectangle(
        [0, 0, 679, 104],
        radius=8,
        fill=(11, 26, 13, 215),
        outline=(20, 66, 20, 255),
        width=2,
    )
    # Left vertical gold accent bar (8px wide)
    dl.rectangle([0, 0, 8, 104], fill=(246, 196, 36, 255))
    f_lt1 = ImageFont.truetype(FONT_BOLD, 34)
    f_lt2 = ImageFont.truetype(FONT_REG, 24)
    dl.text((28, 14), "PRIMER PERSONAJE 3D", font=f_lt1, fill=(246, 196, 36, 255))
    dl.text((28, 60), "Craft to Nation · Modelado y Rig en Blender", font=f_lt2, fill=(255, 255, 255, 255))
    lt.save(lt_path)

    return short_header_path, lt_path


def build_concat_filters() -> list[str]:
    steps = []
    nodes = []
    for i, (st, end) in enumerate(CUTS):
        steps.append(f"[0:v]trim=start={st}:end={end},setpts=PTS-STARTPTS,fps=30[v_cut_{i}]")
        nodes.append(f"[v_cut_{i}]")
    steps.append("".join(nodes) + f"concat=n={len(CUTS)}:v=1:a=0,setsar=1[v_cat]")
    return steps


def encode_with_fallback(cmd_nvenc: list[str], cmd_x264: list[str], label: str) -> None:
    print(f"Rendering {label}...")
    t0 = time.time()
    try:
        subprocess.run(cmd_nvenc, check=True)
    except subprocess.CalledProcessError:
        print(f"NVENC failed for {label}, falling back to libx264...")
        subprocess.run(cmd_x264, check=True)
    print(f"Finished {label} in {time.time() - t0:.1f}s.")


def render_vertical_short(short_header_path: str) -> None:
    os.makedirs(SHORT_DIR, exist_ok=True)
    ass_path, _ = write_subtitles(SHORT_DIR, "personajes_3d_short_01", write_ass=True)
    out_mp4 = f"{SHORT_DIR}/personajes_3d_short_01.mp4"

    ass_esc = ass_path.replace("\\", "/").replace(":", "\\:")
    steps = build_concat_filters()
    steps.extend([
        "[v_cat]split=2[bg_src][fg_src]",
        "[bg_src]crop=960:900:380:82,scale=120:213,scale=1080:1920:flags=bilinear,eq=brightness=-0.12,setsar=1[bg]",
        "[fg_src]crop=960:900:380:82,scale=1080:1012:flags=lanczos,setsar=1[fg]",
        "[bg][fg]overlay=0:270,setsar=1[v_comp]",
        "[v_comp]drawbox=x=0:y=267:w=1080:h=3:color=#F6C424:t=fill,drawbox=x=0:y=1282:w=1080:h=3:color=#F6C424:t=fill[v_framed]",
        "[v_framed][1:v]overlay=0:0,setsar=1[v_header]",
        f"[v_header]ass='{ass_esc}'[v_out]",
        f"[2:a]atrim=0:{TOTAL_DUR},asetpts=PTS-STARTPTS,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:st=0:d=1.0,afade=t=out:st={TOTAL_DUR - 2.0}:d=2.0[aout]",
    ])
    fg = ";".join(steps)

    base = [
        "ffmpeg", "-y",
        "-i", SRC_VIDEO,
        "-i", short_header_path,
        "-i", BGM_MUSIC,
        "-filter_complex", fg,
        "-map", "[v_out]",
        "-map", "[aout]",
    ]
    tail_audio = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", str(TOTAL_DUR), out_mp4]
    cmd_nvenc = base + ["-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "6000k", "-maxrate", "8000k", "-bufsize", "12000k", "-pix_fmt", "yuv420p", "-r", "30"] + tail_audio
    cmd_x264 = base + ["-c:v", "libx264", "-crf", "18", "-preset", "fast", "-pix_fmt", "yuv420p", "-r", "30"] + tail_audio
    encode_with_fallback(cmd_nvenc, cmd_x264, "9:16 Vertical Short")


def render_horizontal_teaser(lt_path: str) -> None:
    os.makedirs(TEASER_DIR, exist_ok=True)
    write_subtitles(TEASER_DIR, "personajes_3d_teaser_16x9", write_ass=False)
    out_mp4 = f"{TEASER_DIR}/personajes_3d_teaser_16x9.mp4"

    steps = build_concat_filters()
    steps.extend([
        "[v_cat]crop=1536:864:2:108,scale=1920:1080:flags=lanczos,setsar=1[v_base]",
        "[1:v]format=rgba,setsar=1,fade=t=in:st=0.5:d=0.5:alpha=1,fade=t=out:st=5.5:d=0.7:alpha=1[lt]",
        "[v_base][lt]overlay=60:915:enable='between(t,0.5,6.3)',setsar=1[v_out]",
        f"[2:a]atrim=0:{TOTAL_DUR},asetpts=PTS-STARTPTS,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:st=0:d=1.0,afade=t=out:st={TOTAL_DUR - 2.0}:d=2.0[aout]",
    ])
    fg = ";".join(steps)

    base = [
        "ffmpeg", "-y",
        "-i", SRC_VIDEO,
        "-loop", "1", "-i", lt_path,
        "-i", BGM_MUSIC,
        "-filter_complex", fg,
        "-map", "[v_out]",
        "-map", "[aout]",
    ]
    tail_audio = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", str(TOTAL_DUR), out_mp4]
    cmd_nvenc = base + ["-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "8000k", "-maxrate", "10000k", "-bufsize", "16000k", "-pix_fmt", "yuv420p", "-r", "30"] + tail_audio
    cmd_x264 = base + ["-c:v", "libx264", "-crf", "18", "-preset", "fast", "-pix_fmt", "yuv420p", "-r", "30"] + tail_audio
    encode_with_fallback(cmd_nvenc, cmd_x264, "16:9 Horizontal Teaser")


if __name__ == "__main__":
    assert Path(SRC_VIDEO).exists(), f"Missing source video: {SRC_VIDEO}"
    assert Path(BGM_MUSIC).exists(), f"Missing BGM track: {BGM_MUSIC}"
    short_hdr, lt_16x9 = generate_overlays()
    render_vertical_short(short_hdr)
    render_horizontal_teaser(lt_16x9)
    print("Both character teasers built successfully!")
