import os
import subprocess
import time

RAW_DIR = "video_edition/media/raw"
DONE_DIR = "video_edition/media/raw/done"
OUT_DIR = "video_edition/media/processed/devlog_antigravity_workspace"
os.makedirs(OUT_DIR, exist_ok=True)

# Locate raw inputs (whether in raw/ or archived in done/)
SCREEN_INPUT = f"{RAW_DIR}/presentacion_entorno_screen_and_audio.mp4"
if not os.path.exists(SCREEN_INPUT):
    SCREEN_INPUT = f"{DONE_DIR}/presentacion_entorno_screen_and_audio.mp4"

CAM_INPUT = f"{RAW_DIR}/presentacion_entorno_over_shoulder.mp4"
if not os.path.exists(CAM_INPUT):
    CAM_INPUT = f"{DONE_DIR}/presentacion_entorno_over_shoulder.mp4"

BGM_INPUT = "arte/mp3/Clockwork_logistics (loop).mp3"
POPUP_DIR = f"{RAW_DIR}/popups_antigravity"
MASTER_OUT = f"{OUT_DIR}/devlog_antigravity_workspace.mp4"

# Popups timing: [id, start, end]
POPUPS = [
    (0, 5.0, 11.0),
    (1, 48.0, 54.0),
    (2, 384.0, 390.0),
    (3, 515.0, 521.0),
    (4, 644.0, 650.0),
    (5, 698.0, 704.0),
    (6, 790.0, 796.0),
    (7, 902.0, 908.0),
    (8, 952.0, 958.0),
    (9, 1012.0, 1018.0)
]

# Screen intervals: [(start, end)]
SCREEN_INTERVALS = [
    (33.0, 382.0),
    (438.0, 642.0),
    (695.0, 788.0),
    (855.0, 1010.0)
]

# Build command
inputs = [
    "-i", SCREEN_INPUT,
    "-i", CAM_INPUT,
    "-stream_loop", "-1", "-i", BGM_INPUT
]

for p in POPUPS:
    pid = p[0]
    inputs.extend(["-loop", "1", "-i", f"{POPUP_DIR}/popup_{pid}.png"])

filter_steps = []

# 1. Base Camera Layer: Crop vertical camera (620x1080), create fast bokeh background (1280x720)
# and center camera foreground (414x720) with strict setsar=1
filter_steps.append(
    "[1:v]trim=start=0.1283,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=5,split=2[cam1][cam2];"
    "[cam1]crop=620:1080:640:0,scale=80:45,scale=1280:720:flags=bilinear,setsar=1[cambg];"
    "[cam2]crop=620:1080:640:0,scale=414:720,setsar=1[camfg];"
    "[cambg][camfg]overlay=(W-w)/2:0,setsar=1[v_cam]"
)

# 2. Split screen into intervals with smooth cross-fades and setsar=1
split_str = "".join([f"[scr_in_{i}]" for i in range(len(SCREEN_INTERVALS))])
filter_steps.append(f"[0:v]split={len(SCREEN_INTERVALS)}{split_str}")

for i, (st, end) in enumerate(SCREEN_INTERVALS):
    dur = end - st
    st_out = end - 0.4
    filter_steps.append(
        f"[scr_in_{i}]trim={st}:{end},setpts=PTS-STARTPTS+{st}/TB,format=rgba,setsar=1,"
        f"fade=t=in:st={st}:d=0.4:alpha=1,fade=t=out:st={st_out}:d=0.4:alpha=1[scr_{i}]"
    )

# 3. Overlay screen intervals sequentially onto v_cam
curr_v = "v_cam"
for i, (st, end) in enumerate(SCREEN_INTERVALS):
    next_v = f"v_scr_ov_{i}"
    filter_steps.append(
        f"[{curr_v}][scr_{i}]overlay=0:0:enable='between(t,{st},{end})'[{next_v}]"
    )
    curr_v = next_v

# 4. Overlay Popups sequentially
# Input index for popups starts at 3
for idx, (pid, st, end) in enumerate(POPUPS):
    inp_idx = 3 + idx
    st_out = end - 0.4
    pop_node = f"pop_{pid}"
    filter_steps.append(
        f"[{inp_idx}:v]format=rgba,setsar=1,fade=t=in:st={st}:d=0.4:alpha=1,fade=t=out:st={st_out}:d=0.4:alpha=1[{pop_node}]"
    )
    next_v = f"v_pop_ov_{pid}"
    filter_steps.append(
        f"[{curr_v}][{pop_node}]overlay=40:604:enable='between(t,{st},{end})'[{next_v}]"
    )
    curr_v = next_v

# Final video node with explicit setsar=1
filter_steps.append(f"[{curr_v}]setsar=1[v_final]")
final_v = "v_final"

# 5. Audio filter: voice with dynaudnorm + looped BGM at volume 0.035
filter_steps.append(
    "[0:a]dynaudnorm=p=0.9:m=5.0:r=0.9[voice];"
    "[2:a]volume=0.035[bgm];"
    "[voice][bgm]amix=inputs=2:duration=first:dropout_transition=2[aout]"
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
    "-t", "1079.6",
    MASTER_OUT
]

print("Starting Master Multicam Render with NVENC Hardware Acceleration (True 16:9)...")
start_time = time.time()
res = subprocess.run(cmd)
elapsed = time.time() - start_time

if res.returncode == 0:
    print(f"Render completed successfully in {elapsed:.1f} seconds (~{elapsed/60:.1f} min).")
else:
    print(f"Render failed with returncode {res.returncode}")
