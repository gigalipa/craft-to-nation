import json
import re
from pathlib import Path

# Cargar glosario y reglas fonéticas
GAME_CORRECTIONS = [
    (r"\bal maz[oóeé]n\b", "almacén"),
    (r"\bmaz[oóeé]n\b", "almacén"),
    (r"\bcentra\b", "central"),
    (r"\bacentrar\b", "la central"),
    (r"\bque m[aá]s de algunos\b", "quema de algunos"),
    (r"\bque amar\b", "quemar"),
    (r"\botro seco\b", "otro puesto"),
    (r"\botro puesto de casa\b", "otro puesto de caza"),
    (r"\bpuestos de casa\b", "puestos de caza"),
    (r"\bentremer t[eé]cnicos\b", "entrenar técnicos"),
    (r"\bobrer de templados\b", "obrero desempleado"),
    (r"\bobrero desempleado o suficiente\b", "obrero desempleado, lo suficiente"),
    (r"\bzona de silencia\b", "zona residencial"),
    (r"\bcon presidencial\b", "zona residencial"),
    (r"\bno son eficacos zona residencial\b", "no es una zona residencial"),
    (r"\bpuesto maelero\b", "puesto maderero"),
    (r"\bcarreror\b", "cargador"),
    (r"\bretivamente\b", "efectivamente"),
    (r"\bacerradero\b", "aserradero"),
    (r"\bdel prehistoria\b", "de la prehistoria"),
    (r"\bmedioal\b", "medieval"),
    (r"\bsteampank\b", "Steampunk"),
    (r"\benijan\b", "elijan"),
    (r"\bEasy Punk\b", "Dieselpunk"),
    (r"\bSolar Punk\b", "Solarpunk"),
    (r"\benlige\b", "elija"),
    (r"\bpueda revolucionar\b", "pueda evolucionar"),
    (r"\bevolucionando la ciudad\b", "evolucionado la ciudad"),
]

def clean_text(text: str) -> str:
    cleaned = text
    for pat, rep in GAME_CORRECTIONS:
        cleaned = re.sub(pat, rep, cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned

# Leer segmentos originales del live completo
with open("video_edition/media/processed/live_w1_audio_segments.json", "r", encoding="utf-8") as f:
    raw_segs = json.load(f)

# Cortes definidos en live_recap_edit.json
cuts = [
    {"start": 120.0, "end": 165.0, "t_start": 0.0},
    {"start": 1055.0, "end": 1095.0, "t_start": 44.25},
    {"start": 2115.0, "end": 2160.0, "t_start": 83.50},
    {"start": 2795.0, "end": 2840.0, "t_start": 127.75},
    {"start": 5048.0, "end": 5085.0, "t_start": 172.00},
]

recap_segments = []
seg_id = 0

for cut in cuts:
    c_start = cut["start"]
    c_end = cut["end"]
    t_start = cut["t_start"]
    
    for s in raw_segs:
        # Si el segmento se solapa significativamente con el corte
        if s["end"] > c_start + 0.5 and s["start"] < c_end - 0.5:
            # Calcular tiempo relativo dentro del corte
            rel_start = max(0.0, s["start"] - c_start)
            rel_end = min(c_end - c_start, s["end"] - c_start)
            
            # Tiempo absoluto en el timeline del recap
            abs_start = round(t_start + rel_start, 2)
            abs_end = round(t_start + rel_end, 2)
            
            raw_t = s["text"]
            cleaned_t = clean_text(raw_t)
            
            if cleaned_t and len(cleaned_t) > 2 and not cleaned_t.startswith("..."):
                recap_segments.append({
                    "id": seg_id,
                    "start": abs_start,
                    "end": abs_end,
                    "text": cleaned_t
                })
                seg_id += 1

# Guardar segmentos limpios
out_json = Path("video_edition/media/processed/live_w1_recap_master_segments.json")
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(recap_segments, f, ensure_ascii=False, indent=2)

print(f"[+] {len(recap_segments)} segmentos mapeados y corregidos en: {out_json}")

# Generar SRT
out_srt = Path("video_edition/media/processed/live_w1_recap_master.srt")

def format_timestamp_srt(seconds: float) -> str:
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    return f"{hrs:02d}:{mins:02d}:{secs:02d},{millis:03d}"

with open(out_srt, "w", encoding="utf-8") as f:
    for i, seg in enumerate(recap_segments, 1):
        s_str = format_timestamp_srt(seg["start"])
        e_str = format_timestamp_srt(seg["end"])
        f.write(f"{i}\n{s_str} --> {e_str}\n{seg['text']}\n\n")

print(f"[+] Archivo SRT generado: {out_srt}")
