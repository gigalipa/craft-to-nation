import argparse
import json
import subprocess
import sys
from pathlib import Path
import torch
import whisper


def format_timestamp_ass(seconds: float) -> str:
    """Convierte segundos flotantes al formato H:MM:SS.cc de ASS."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = seconds % 60
    return f"{hours}:{minutes:02d}:{secs:05.2f}"


def format_timestamp_srt(seconds: float) -> str:
    """Convierte segundos flotantes al formato HH:MM:SS,mmm de SRT."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds - int(seconds)) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def create_ass_content(segments: list[dict]) -> str:
    """Genera archivo de subtítulos .ass con estilo optimizado para video vertical (TikTok/Shorts)."""
    # MarginV=350 asegura que los botones y la descripción de TikTok/Reels no tapen el texto
    # Estilo Craft to Nation:
    # PrimaryColour: Verde oscuro del juego (&H00153D12&)
    # OutlineColour: Dorado / Amarillo HUD (&H0032C8F8&)
    # BackColour: Sombra oscura (&H800A1808&)
    header = """[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: CraftToNation,Trebuchet MS,66,&H00144214,&H00000000,&H0024C4F6,&H80061206,-1,0,0,0,100,100,0,0,1,6,3,2,50,50,350,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    events = []
    for seg in segments:
        start_str = format_timestamp_ass(seg["start"])
        end_str = format_timestamp_ass(seg["end"])
        text = seg["text"].strip().replace("\n", " ")
        events.append(f"Dialogue: 0,{start_str},{end_str},CraftToNation,,0,0,0,,{text}")

    return header + "\n".join(events) + "\n"


def create_srt_content(segments: list[dict]) -> str:
    """Genera archivo de subtítulos estándar .srt."""
    lines = []
    for i, seg in enumerate(segments, 1):
        start_str = format_timestamp_srt(seg["start"])
        end_str = format_timestamp_srt(seg["end"])
        text = seg["text"].strip()
        lines.append(f"{i}\n{start_str} --> {end_str}\n{text}\n")
    return "\n".join(lines)


def transcribe_video(
    video_path: Path,
    model_name: str = "base",
    language: str = "es",
) -> list[dict]:
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"[*] Cargando modelo Whisper '{model_name}' en dispositivo: {device.upper()}...")
    model = whisper.load_model(model_name, device=device)

    print(f"[*] Cargando audio '{video_path.name}'...")
    audio = whisper.load_audio(str(video_path))
    sample_rate = 16000
    total_seconds = len(audio) / sample_rate
    print(f"[*] Duración detectada: {total_seconds:.1f}s ({total_seconds/3600:.2f}h)")

    chunk_duration = 600.0  # 10 minutos por bloque para evitar saturación de memoria RAM en STFT
    if total_seconds <= chunk_duration:
        result = model.transcribe(audio, language=language, fp16=(device == "cuda"))
        return result["segments"]

    print(f"[*] Audio largo detectado (> {chunk_duration}s). Procesando en bloques de {chunk_duration}s...")
    all_segments = []
    seg_id = 0
    chunk_samples = int(chunk_duration * sample_rate)

    for start_sample in range(0, len(audio), chunk_samples):
        end_sample = min(len(audio), start_sample + chunk_samples)
        chunk_audio = audio[start_sample:end_sample]
        offset_sec = start_sample / sample_rate

        print(f"    - Transcribiendo bloque {offset_sec:.1f}s a {end_sample/sample_rate:.1f}s...")
        res = model.transcribe(chunk_audio, language=language, fp16=(device == "cuda"))
        for s in res.get("segments", []):
            s_copy = dict(s)
            s_copy["id"] = seg_id
            s_copy["start"] = round(s["start"] + offset_sec, 2)
            s_copy["end"] = round(s["end"] + offset_sec, 2)
            all_segments.append(s_copy)
            seg_id += 1

    return all_segments


def burn_subtitles(
    video_path: Path,
    ass_path: Path,
    output_path: Path,
    use_nvenc: bool = True,
) -> bool:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    # En Windows, para el filtro ass en ffmpeg usamos barras diagonales normales escapando dos puntos
    escaped_ass = str(ass_path.resolve()).replace("\\", "/").replace(":", "\\:")

    encoders = ["h264_nvenc", "libx264"] if use_nvenc else ["libx264"]

    for encoder in encoders:
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(video_path),
            "-vf",
            f"ass='{escaped_ass}'",
            "-c:v",
            encoder,
        ]
        if encoder == "h264_nvenc":
            cmd.extend(["-preset", "p4", "-cq", "23"])
        else:
            cmd.extend(["-preset", "veryfast", "-crf", "22"])

        cmd.extend(["-c:a", "copy", str(output_path)])

        print(f"[*] Quemando subtítulos con encoder '{encoder}'...")
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            print(f"[+] Video con subtítulos generado: {output_path}")
            return True
        else:
            print(f"[-] Error al quemar subtítulos ({encoder}): {res.stderr[-300:]}")
            if encoder == encoders[-1]:
                return False
    return False


def main():
    parser = argparse.ArgumentParser(description="Generador y quemador de subtítulos dinámicos con Whisper GPU.")
    parser.add_argument("--input", "-i", required=True, help="Video o audio de entrada.")
    parser.add_argument("--output", "-o", help="Video con subtítulos quemados (opcional).")
    parser.add_argument("--model", "-m", default="base", help="Modelo Whisper (tiny, base, small, medium).")
    parser.add_argument("--lang", "-l", default="es", help="Idioma (código ISO, ej. 'es').")
    parser.add_argument("--burn", "-b", action="store_true", help="Quemar subtítulos directamente en el video.")
    parser.add_argument("--from-json", help="Ruta a archivo JSON con segmentos [{'start': 0, 'end': 4, 'text': '...'}] (para videos sin voz).")

    args = parser.parse_args()
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[!] Error: Archivo no encontrado: {input_path}")
        sys.exit(1)

    if args.from_json:
        json_path = Path(args.from_json)
        print(f"[*] Cargando subtítulos descriptivos desde: {json_path.name}")
        segments = json.loads(json_path.read_text(encoding="utf-8"))
    else:
        segments = transcribe_video(input_path, model_name=args.model, language=args.lang)

    # Rutas para archivos auxiliares
    base_name = input_path.stem
    work_dir = input_path.parent
    ass_path = work_dir / f"{base_name}.ass"
    srt_path = work_dir / f"{base_name}.srt"
    txt_path = work_dir / f"{base_name}_transcript.txt"

    # Guardar .ass
    ass_path.write_text(create_ass_content(segments), encoding="utf-8")
    print(f"[+] Archivo ASS generado: {ass_path}")

    # Guardar .srt
    srt_path.write_text(create_srt_content(segments), encoding="utf-8")
    print(f"[+] Archivo SRT generado: {srt_path}")

    # Guardar segments JSON con timestamps para análisis
    json_path = work_dir / f"{base_name}_segments.json"
    json_path.write_text(json.dumps(segments, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[+] Archivo de segmentos JSON guardado en: {json_path}")

    # Guardar texto continuo
    full_text = " ".join(seg["text"].strip() for seg in segments)
    txt_path.write_text(full_text, encoding="utf-8")
    print(f"[+] Transcripción completa guardada en: {txt_path}")

    if args.burn:
        output_video = Path(args.output) if args.output else work_dir / f"{base_name}_subtitled.mp4"
        burn_subtitles(input_path, ass_path, output_video)


if __name__ == "__main__":
    main()
