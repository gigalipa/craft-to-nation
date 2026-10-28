import json
import re
from pathlib import Path

# Cargar glosario y reglas fonéticas
from llm_subtitle_cleaner import clean_text_with_glossary

with open("video_edition/media/processed/live_w2_audio_segments.json", "r", encoding="utf-8") as f:
    raw_segs = json.load(f)

cuts = [
    {"start": 41.0, "end": 95.0, "t_start": 0.0},
    {"start": 95.0, "end": 139.0, "t_start": 53.25},
    {"start": 139.0, "end": 180.0, "t_start": 96.50},
    {"start": 180.0, "end": 215.0, "t_start": 136.75},
    {"start": 740.0, "end": 780.0, "t_start": 171.00},
]

recap_segments = []
seg_id = 0

for cut in cuts:
    c_start = cut["start"]
    c_end = cut["end"]
    t_start = cut["t_start"]
    
    for s in raw_segs:
        if s["end"] > c_start + 0.3 and s["start"] < c_end - 0.3:
            rel_start = max(0.0, s["start"] - c_start)
            rel_end = min(c_end - c_start, s["end"] - c_start)
            
            abs_start = round(t_start + rel_start, 2)
            abs_end = round(t_start + rel_end, 2)
            
            raw_t = s["text"]
            cleaned_t = clean_text_with_glossary(raw_t)
            
            # Limpiezas específicas de pronunciación en live_w2
            cleaned_t = re.sub(r"\bhot\b", "HUD", cleaned_t, flags=re.IGNORECASE)
            cleaned_t = re.sub(r"\bhot bar\b", "hotbar", cleaned_t, flags=re.IGNORECASE)
            cleaned_t = re.sub(r"\bcode\b", "Godot", cleaned_t, flags=re.IGNORECASE)
            cleaned_t = re.sub(r"\bmoralooa\b", "moral baja", cleaned_t, flags=re.IGNORECASE)
            cleaned_t = re.sub(r"\s+", " ", cleaned_t).strip()
            
            if cleaned_t and len(cleaned_t) > 2 and not cleaned_t.startswith("..."):
                recap_segments.append({
                    "id": seg_id,
                    "start": abs_start,
                    "end": abs_end,
                    "text": cleaned_t
                })
                seg_id += 1

out_json = Path("video_edition/media/processed/live_w2_recap_segments.json")
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(recap_segments, f, ensure_ascii=False, indent=2)

print(f"[+] {len(recap_segments)} segmentos mapeados en: {out_json}")

def format_timestamp_srt(seconds: float) -> str:
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    return f"{hrs:02d}:{mins:02d}:{secs:02d},{millis:03d}"

out_srt = Path("video_edition/media/processed/live_w2_recap.srt")
with open(out_srt, "w", encoding="utf-8") as f:
    for i, seg in enumerate(recap_segments, 1):
        s_str = format_timestamp_srt(seg["start"])
        e_str = format_timestamp_srt(seg["end"])
        f.write(f"{i}\n{s_str} --> {e_str}\n{seg['text']}\n\n")

print(f"[+] Archivo SRT generado: {out_srt}")
