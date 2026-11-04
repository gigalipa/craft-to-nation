import json

with open('video_edition/media/raw/presentacion_entorno_screen_and_audio_segments.json', 'r', encoding='utf-8') as f:
    segs = json.load(f)

with open('video_edition/media/raw/full_transcript_timed.txt', 'w', encoding='utf-8') as out:
    for s in segs:
        m_s = int(s['start'] // 60)
        s_s = int(s['start'] % 60)
        m_e = int(s['end'] // 60)
        s_e = int(s['end'] % 60)
        out.write(f"[{m_s:02d}:{s_s:02d} - {m_e:02d}:{s_e:02d}] {s['text']}\n")

print("Saved full_transcript_timed.txt")
