import os
import subprocess
import time

RAW_DIR = "video_edition/media/raw"
PROCESSED_DIR = "video_edition/media/processed"
BGM_MUSIC = "arte/mp3/Clockwork_logistics (loop).mp3"
HEADER_PATCH = f"{RAW_DIR}/header_patch_debug.png"
RAW_VIDEO = f"{RAW_DIR}/done/Antigravity_Debugging_last_report.mp4" if os.path.exists(f"{RAW_DIR}/done/Antigravity_Debugging_last_report.mp4") else f"{RAW_DIR}/Antigravity_Debugging_last_report.mp4"

SHORTS = [
    {
        "id": "debugging_short_01",
        "title": "Le di 9 bugs de golpe a la IA en Antigravity",
        # Custom cuts: 0:18 (start of prompt) + 11:45 (plan) + 37:35 (tests)
        "segments": [(15, 30), (705, 720), (2255, 2270)],
        "duration": 45.0,
        "subs": [
            (0.5, 4.5, "¿Qué pasa cuando le das 9 bugs de golpe a una IA?"),
            (4.5, 11.5, "En Craft to Nation, el playtest dejó 9 problemas serios de física y demografía."),
            (11.5, 18.5, "En lugar de codear a ciegas, el agente analiza las causas raíz."),
            (18.5, 30.5, "Generó un plan sistemático de 10 puntos antes de tocar una sola línea."),
            (30.5, 38.5, "Y antes de aceptar el commit: 28 suites de pruebas de Godot en vivo."),
            (38.5, 44.5, "28/28 en verde. Cero alucinaciones. Así se desarrolla un indie.")
        ]
    },
    {
        "id": "debugging_short_02",
        "title": "El misterio de los colonos fantasma",
        "segments": [(1160, 1205)],
        "duration": 45.0,
        "subs": [
            (0.5, 5.0, "Teníamos un bug insólito en la economía de nuestra colonia..."),
            (5.0, 12.0, "Al demoler o remodelar una casa, los colonos quedaban 'Sin techo'."),
            (12.0, 20.0, "¡Pero en los puestos de trabajo seguían figurando como empleados!"),
            (20.0, 30.0, "Eran colonos fantasma: cobraban sueldo y ocupaban puestos sin poder trabajar."),
            (30.0, 38.0, "El agente implementó reconciliación automática con Economia.liberar()."),
            (38.0, 44.5, "Problema resuelto. En Craft to Nation nadie cobra sin laburar.")
        ]
    },
    {
        "id": "debugging_short_03",
        "title": "Ventanas de techo que se caían a vertical",
        "segments": [(720, 765)],
        "duration": 45.0,
        "subs": [
            (0.5, 5.0, "Un clásico del desarrollo 3D en Godot..."),
            (5.0, 13.0, "Construyes una casa con claraboyas y ventanas en el techo..."),
            (13.0, 22.0, "¡Y al spawnear desde el blueprint, todas las ventanas rotan a vertical!"),
            (22.0, 31.0, "El bug: el serializador guardaba la celda pero perdía la orientación 3D."),
            (31.0, 38.0, "El agente agregó persistencia de orientaciones_3d en VoxelWorld y Blueprints."),
            (38.0, 44.5, "Ahora los techos de cristal se construyen perfectos.")
        ]
    },
    {
        "id": "debugging_short_04",
        "title": "28 de 28 tests en verde con IA",
        "segments": [(2245, 2290)],
        "duration": 45.0,
        "subs": [
            (0.5, 6.0, "Si usas IA para programar videojuegos, esta es la regla de oro:"),
            (6.0, 14.0, "NUNCA hagas commit sin una suite de pruebas automatizada."),
            (14.0, 24.0, "Tras corregir 9 bugs en 18 archivos, el agente corre run-single-test.ps1."),
            (24.0, 34.0, "Economía, navegación, natación, voxels y demografía... uno por uno."),
            (34.0, 41.0, "28 de 28 suites de pruebas de Godot pasando en verde impecable."),
            (41.0, 44.5, "Así mantienes un proyecto indie vivo sin acumular deuda técnica.")
        ]
    }
]

def format_ass_time(sec):
    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = int(sec % 60)
    cs = int(round((sec - int(sec)) * 100))
    if cs >= 100:
        cs = 99
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"

def create_ass_file(path, subs):
    header = """[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Trebuchet MS,68,&H00FFFFFF,&H000000FF,&H00000000,&HA00B1A0D,-1,0,0,0,100,100,0,0,3,6,0,2,70,70,440,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    lines = [header]
    for st, end, text in subs:
        t_start = format_ass_time(st)
        t_end = format_ass_time(end)
        lines.append(f"Dialogue: 0,{t_start},{t_end},Default,,0,0,0,,{text}\n")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)

def build_short(short_info):
    sid = short_info["id"]
    out_dir = f"{PROCESSED_DIR}/{sid}"
    os.makedirs(out_dir, exist_ok=True)
    out_mp4 = f"{out_dir}/{sid}.mp4"
    ass_path = f"{out_dir}/{sid}.ass"
    srt_path = f"{out_dir}/{sid}.srt"
    
    # 1. Create .ass and .srt files
    create_ass_file(ass_path, short_info["subs"])
    with open(srt_path, "w", encoding="utf-8") as f:
        for i, (st, end, text) in enumerate(short_info["subs"], 1):
            h1, m1, s1 = int(st//3600), int((st%3600)//60), int(st%60)
            ms1 = int(round((st - int(st))*1000))
            h2, m2, s2 = int(end//3600), int((end%3600)//60), int(end%60)
            ms2 = int(round((end - int(end))*1000))
            f.write(f"{i}\n{h1:02d}:{m1:02d}:{s1:02d},{ms1:03d} --> {h2:02d}:{m2:02d}:{s2:02d},{ms2:03d}\n{text}\n\n")

    # 2. Build FFmpeg command
    ass_escaped = ass_path.replace("\\", "/").replace(":", "\\:")
    
    seg_filters = []
    seg_names = []
    for idx, (st, end) in enumerate(short_info["segments"]):
        seg_filters.append(f"[0:v]trim={st}:{end},setpts=PTS-STARTPTS[seg_{idx}]")
        seg_names.append(f"[seg_{idx}]")
    
    concat_str = "".join(seg_names) + f"concat=n={len(seg_names)}:v=1:a=0[v_raw_cat]"
    
    filter_graph = ";".join([
        *seg_filters,
        concat_str,
        # Apply header patch onto concatenated horizontal video
        "[v_raw_cat][1:v]overlay=0:0[v_hp]",
        # Blur confidential project in sidebar (pastel-routine / Oscar Patel)
        "[v_hp]split[v_base][v_crop]",
        "[v_crop]crop=250:54:54:248,avgblur=sizeX=24:sizeY=24[v_blurred]",
        "[v_base][v_blurred]overlay=54:248,setsar=1[v_patched]",
        # Split into background (blurred) and foreground (scaled)
        "[v_patched]split=2[bg_in][fg_in]",
        "[bg_in]scale=120:213,scale=1080:1920:flags=bilinear,setsar=1[bg]",
        "[fg_in]scale=1080:-1,setsar=1[fg]",
        "[bg][fg]overlay=0:(H-h)/2,setsar=1[v_canvas]",
        # Burn subtitles
        f"[v_canvas]ass='{ass_escaped}'[v_out]",
        # Audio
        f"[2:a]volume=0.12,afade=t=in:st=0:d=1,afade=t=out:st={short_info['duration']-1.5}:d=1.5[aout]"
    ])

    cmd = [
        "ffmpeg", "-y",
        "-i", RAW_VIDEO,
        "-i", HEADER_PATCH,
        "-stream_loop", "-1", "-i", BGM_MUSIC,
        "-filter_complex", filter_graph,
        "-map", "[v_out]",
        "-map", "[aout]",
        "-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "5000k", "-maxrate", "7000k", "-bufsize", "10000k", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k",
        "-t", str(short_info["duration"]),
        out_mp4
    ]
    print(f"Rendering {sid}: {short_info['title']}...")
    t0 = time.time()
    subprocess.run(cmd, check=True)
    print(f"Finished {sid} in {time.time()-t0:.1f}s.")

if __name__ == "__main__":
    for s in SHORTS:
        build_short(s)
    print("All 4 shorts rendered successfully!")
