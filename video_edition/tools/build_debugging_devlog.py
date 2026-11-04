import os
import subprocess
import time

RAW_DIR = "video_edition/media/raw"
DONE_DIR = "video_edition/media/raw/done"
OUT_DIR = "video_edition/media/processed/devlog_debugging_live"
os.makedirs(OUT_DIR, exist_ok=True)

VIDEO_INPUT = f"{DONE_DIR}/Antigravity_Debugging_last_report.mp4"
if not os.path.exists(VIDEO_INPUT):
    VIDEO_INPUT = f"{RAW_DIR}/Antigravity_Debugging_last_report.mp4"

HEADER_PATCH = f"{RAW_DIR}/header_patch_debug.png"
BGM_INPUT = "arte/mp3/Glitch_drift (loop).mp3"
POPUP_DIR = f"{RAW_DIR}/popups_debugging"
MASTER_OUT = f"{OUT_DIR}/devlog_debugging_live.mp4"

# Raw cuts: (start_raw_sec, end_raw_sec, speed_multiplier)
# Excludes static pauses and intro pauses (00:06-00:26 and 00:33-00:40)
RAW_CUTS = [
    (0.0, 6.0, 1.0),         # 0: Intro inicial (0.0 - 6.0s)
    (26.0, 33.0, 1.0),       # 1: Prompt pegado (6.0 - 13.0s)
    (40.0, 45.0, 1.0),       # 2: Prompt enviado (13.0 - 18.0s)
    (45.0, 291.0, 6.0),      # 3: Investigación activa (18.0 - 59.0s)
    (409.8, 423.0, 6.0),     # 4: Continuación activa (59.0 - 61.2s)
    (543.0, 555.0, 6.0),     # 5: Continuación activa (61.2 - 63.2s)
    (651.0, 705.0, 6.0),     # 6: Final análisis (63.2 - 72.2s)
    (705.0, 765.0, 1.0),     # 7: Plan de corrección y aprobación (72.2 - 132.2s)
    (765.0, 1317.0, 6.0),    # 8: Edición GDScript (132.2 - 224.2s)
    (1371.0, 1905.0, 6.0),   # 9: Edición GDScript (224.2 - 313.2s)
    (1917.0, 1929.0, 6.0),   # 10: Edición GDScript (313.2 - 315.2s)
    (1941.0, 2250.0, 6.0),   # 11: Edición GDScript (315.2 - 366.7s)
    (2250.0, 2296.5, 10.0),  # 12: 28 tests en segundo plano (x10) (366.7 - 371.3s)
    (2296.5, 2298.5, 1.0),   # 13: Finalización de tests (371.3 - 373.3s)
    (2298.5, 2361.5, 6.0),   # 14: Trabajo del agente (x6) (373.3 - 383.8s)
    (2361.5, 2377.5, 1.0)    # 15: Reporte 28/28 en verde y cierre (383.8 - 399.8s)
]

TOTAL_DUR = 399.85  # ~6 min 40s

# Popups: (id, start_sec, end_sec) on the new output timeline
POPUPS = [
    (0, 2.0, 8.0),        # Intro y prompt
    (1, 22.0, 28.0),      # Rastreo de subgrafos
    (2, 75.0, 81.0),      # Plan de corrección
    (3, 135.0, 141.0),    # Cirugía en GDScript
    (4, 367.0, 373.0),    # Ejecución masiva de 28 tests
    (5, 385.0, 391.0)     # 28/28 en verde y cierre
]

inputs = [
    "-i", VIDEO_INPUT,
    "-i", HEADER_PATCH,
    "-stream_loop", "-1", "-i", BGM_INPUT
]

for p in POPUPS:
    pid = p[0]
    inputs.extend(["-loop", "1", "-i", f"{POPUP_DIR}/popup_{pid}.png"])

filter_steps = []

# Step 1: Overlay header patch onto raw video to correct "Objetivo" text
filter_steps.append("[0:v][1:v]overlay=0:0,setsar=1[v_hp]")

# Step 1b: Blur confidential project in sidebar (pastel-routine / Oscar Patel) at x=54, y=248, w=250, h=54
filter_steps.append("[v_hp]split[v_base][v_crop]")
filter_steps.append("[v_crop]crop=250:54:54:248,avgblur=sizeX=24:sizeY=24[v_blurred]")
filter_steps.append("[v_base][v_blurred]overlay=54:248,setsar=1[v_patched]")

# Step 2: Split into 16 segments and apply selective speed changes
split_str = "".join([f"[s_in_{i}]" for i in range(len(RAW_CUTS))])
filter_steps.append(f"[v_patched]split={len(RAW_CUTS)}{split_str}")

seg_nodes = []
for i, (st, end, sp) in enumerate(RAW_CUTS):
    out_node = f"v_seg_{i}"
    seg_nodes.append(f"[{out_node}]")
    if sp == 1.0:
        filter_steps.append(f"[s_in_{i}]trim={st}:{end},setpts=PTS-STARTPTS,setsar=1[{out_node}]")
    else:
        filter_steps.append(f"[s_in_{i}]trim={st}:{end},setpts=(PTS-STARTPTS)/{sp},setsar=1[{out_node}]")

# Step 3: Concat 16 segments
concat_str = "".join(seg_nodes) + f"concat=n={len(RAW_CUTS)}:v=1:a=0,setsar=1[v_concat]"
filter_steps.append(concat_str)

curr_v = "v_concat"

# Step 4: Overlay popups sequentially (inputs start at index 3)
for idx, (pid, st, end) in enumerate(POPUPS):
    inp_idx = 3 + idx
    st_out = end - 0.4
    pop_node = f"pop_{pid}"
    filter_steps.append(
        f"[{inp_idx}:v]format=rgba,setsar=1,fade=t=in:st={st}:d=0.4:alpha=1,fade=t=out:st={st_out}:d=0.4:alpha=1[{pop_node}]"
    )
    next_v = f"v_pop_ov_{pid}"
    filter_steps.append(
        f"[{curr_v}][{pop_node}]overlay=40:604:enable='between(t,{st},{end})',setsar=1[{next_v}]"
    )
    curr_v = next_v

final_v = curr_v

# Step 5: Audio - background music loop at volume 0.045 with fade in and fade out
filter_steps.append(
    f"[2:a]volume=0.045,afade=t=in:st=0:d=2,afade=t=out:st={TOTAL_DUR-3.0}:d=3[aout]"
)

filter_complex_str = ";".join(filter_steps)

cmd = [
    "ffmpeg", "-y",
    *inputs,
    "-filter_complex", filter_complex_str,
    "-map", f"[{final_v}]",
    "-map", "[aout]",
    "-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "4000k", "-maxrate", "6000k", "-bufsize", "8000k", "-pix_fmt", "yuv420p",
    "-c:a", "aac", "-b:a", "192k",
    "-t", str(TOTAL_DUR),
    MASTER_OUT
]

print("Starting Refined Debugging Master Devlog Render (NVENC, 6m40s)...")
t0 = time.time()
res = subprocess.run(cmd)
elapsed = time.time() - t0

if res.returncode == 0:
    print(f"Refined Master render finished successfully in {elapsed:.1f}s (~{elapsed/60:.1f} min).")
else:
    print(f"Master render failed with exit code {res.returncode}")
