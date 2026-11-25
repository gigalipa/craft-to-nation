import os
import subprocess
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SRC_VIDEO = "video_edition/media/raw/done/personajes_3d_animacion_2026-11-24.mp4"
BGM_MUSIC = "godot/assets/musica/Foundations & Frameworks (building).mp3"
OVERLAY_DIR = "video_edition/media/raw/overlays_anim"
OUT_DIR = "video_edition/media/processed/personajes_3d_animacion_short_01"

FONT_BOLD = "C:/Windows/Fonts/trebucbd.ttf"
TOTAL_DUR = 20.6

SUBTITLES = [
    (0.3, 4.2, "¡Nuestro primer personaje 3D ya camina!"),
    (4.4, 9.2, "Probando el ciclo de caminata en 360° en Blender."),
    (9.4, 13.1, "El rig mueve piernas, brazos y equipo con fluidez."),
    (13.3, 17.4, "Malla base vs. modelo texturizado en cámara lenta."),
    (17.5, 20.4, "¡Pronto en Godot 4! ¿Qué sigue: correr o talar?"),
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


def write_subtitles(stem: str) -> tuple[str, str]:
    os.makedirs(OUT_DIR, exist_ok=True)
    srt_path = f"{OUT_DIR}/{stem}.srt"
    ass_path = f"{OUT_DIR}/{stem}.ass"

    with open(srt_path, "w", encoding="utf-8") as f:
        for i, (st, end, text) in enumerate(SUBTITLES, 1):
            f.write(f"{i}\n{format_srt_time(st)} --> {format_srt_time(end)}\n{text}\n\n")

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

    # 1. Header PNG (1080x260 RGBA)
    hdr_path = f"{OVERLAY_DIR}/anim_header.png"
    hdr = Image.new("RGBA", (1080, 260), (0, 0, 0, 0))
    dh = ImageDraw.Draw(hdr)
    dh.rounded_rectangle(
        [120, 95, 960, 225],
        radius=18,
        fill=(11, 26, 13, 225),
        outline=(246, 196, 36, 255),
        width=3,
    )
    f_sub = ImageFont.truetype(FONT_BOLD, 28)
    f_main = ImageFont.truetype(FONT_BOLD, 42)
    l1 = "CRAFT TO NATION · ANIMACIÓN 3D"
    l2 = "PRIMER CICLO DE CAMINATA"
    b1 = dh.textbbox((0, 0), l1, font=f_sub)
    b2 = dh.textbbox((0, 0), l2, font=f_main)
    dh.text(((1080 - (b1[2] - b1[0])) // 2, 112), l1, font=f_sub, fill=(246, 196, 36, 255))
    dh.text(((1080 - (b2[2] - b2[0])) // 2, 156), l2, font=f_main, fill=(255, 255, 255, 255))
    hdr.save(hdr_path)

    # 2. Split Labels PNG (1080x990 RGBA) for Act 2
    lbl_path = f"{OVERLAY_DIR}/split_labels.png"
    lbl = Image.new("RGBA", (1080, 990), (0, 0, 0, 0))
    dl = ImageDraw.Draw(lbl)
    f_pill = ImageFont.truetype(FONT_BOLD, 22)

    for box, text in [([20, 16, 212, 66], "MALLA (CLAY)"), ([868, 16, 1060, 66], "TEXTURIZADO")]:
        dl.rounded_rectangle(box, radius=10, fill=(11, 26, 13, 210), outline=(246, 196, 36, 255), width=2)
        tb = dl.textbbox((0, 0), text, font=f_pill)
        tw = tb[2] - tb[0]
        th = tb[3] - tb[1]
        cx = (box[0] + box[2] - tw) // 2
        cy = (box[1] + box[3] - th) // 2 - 2
        dl.text((cx, cy), text, font=f_pill, fill=(246, 196, 36, 255))
    lbl.save(lbl_path)

    return hdr_path, lbl_path


def render_animation_short() -> None:
    stem = "personajes_3d_animacion_short_01"
    ass_path, _ = write_subtitles(stem)
    hdr_path, lbl_path = generate_overlays()
    out_mp4 = f"{OUT_DIR}/{stem}.mp4"
    ass_esc = ass_path.replace("\\", "/").replace(":", "\\:")

    filter_steps = [
        # Act 1 (0.0s - 13.2s): Full Hero 360 Textured Walk
        "[0:v]trim=start=0.6:end=13.8,setpts=PTS-STARTPTS,fps=30,crop=578:530:800:102,scale=1080:990:flags=lanczos,setsar=1[act1]",
        # Act 2 (13.2s - 20.6s, 0.7x slow-mo): Split-Screen Malla (Clay) vs Textura
        "[0:v]trim=start=0.8:end=6.0,setpts=(PTS-STARTPTS)/0.7,fps=30,split=2[a2_l][a2_r]",
        "[a2_l]crop=300:552:126:80,scale=538:990:flags=lanczos,pad=1080:990:0:0:#F6C424,setsar=1[pane_l]",
        "[a2_r]crop=300:552:892:80,scale=538:990:flags=lanczos,setsar=1[pane_r]",
        "[pane_l][pane_r]overlay=542:0,trim=0:7.4,setpts=PTS-STARTPTS,setsar=1[act2]",
        # Concatenate Hero Window (20.6s of 1080x990)
        "[act1][act2]concat=n=2:v=1:a=0,setsar=1[hero]",
        # Blurred 9:16 Background + Centered Hero at y=260
        "[hero]split=2[bg_src][fg_src]",
        "[bg_src]scale=120:213,scale=1080:1920:flags=bilinear,eq=brightness=-0.12,setsar=1[bg]",
        "[bg][fg_src]overlay=0:260,setsar=1[v_comp]",
        "[v_comp]drawbox=x=0:y=257:w=1080:h=3:color=#F6C424:t=fill,drawbox=x=0:y=1250:w=1080:h=3:color=#F6C424:t=fill[v_framed]",
        "[v_framed][1:v]overlay=0:0,setsar=1[v_hdr]",
        "[v_hdr][2:v]overlay=0:260:enable='gte(t,13.2)',setsar=1[v_lbl]",
        f"[v_lbl]ass='{ass_esc}'[v_out]",
        f"[3:a]atrim=0:{TOTAL_DUR},asetpts=PTS-STARTPTS,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:st=0:d=0.8,afade=t=out:st={TOTAL_DUR - 1.8}:d=1.8[aout]",
    ]
    fg = ";".join(filter_steps)

    base = [
        "ffmpeg", "-y",
        "-i", SRC_VIDEO,
        "-i", hdr_path,
        "-loop", "1", "-i", lbl_path,
        "-i", BGM_MUSIC,
        "-filter_complex", fg,
        "-map", "[v_out]",
        "-map", "[aout]",
    ]
    tail_audio = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", str(TOTAL_DUR), out_mp4]
    cmd_nvenc = base + ["-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "6000k", "-maxrate", "8000k", "-bufsize", "12000k", "-pix_fmt", "yuv420p", "-r", "30"] + tail_audio
    cmd_x264 = base + ["-c:v", "libx264", "-crf", "18", "-preset", "fast", "-pix_fmt", "yuv420p", "-r", "30"] + tail_audio

    print("Rendering 9:16 Character Animation Short...")
    t0 = time.time()
    try:
        subprocess.run(cmd_nvenc, check=True)
    except subprocess.CalledProcessError:
        print("NVENC failed, falling back to libx264...")
        subprocess.run(cmd_x264, check=True)
    print(f"Finished 9:16 Character Animation Short in {time.time() - t0:.1f}s.")


if __name__ == "__main__":
    assert Path(SRC_VIDEO).exists(), f"Missing source video: {SRC_VIDEO}"
    assert Path(BGM_MUSIC).exists(), f"Missing BGM track: {BGM_MUSIC}"
    render_animation_short()
