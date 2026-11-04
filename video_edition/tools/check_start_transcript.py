import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open('video_edition/media/raw/presentacion_entorno_screen_and_audio_segments.json', 'r', encoding='utf-8') as f:
    segs = json.load(f)

for s in segs[:15]:
    print(f"[{s['start']:.2f} -> {s['end']:.2f}] {s['text']}")
