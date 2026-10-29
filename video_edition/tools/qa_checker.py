import argparse
import json
import subprocess
import sys
from pathlib import Path


def inspect_video(video_path: Path) -> dict:
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "stream=width,height,duration,codec_type",
        "-of",
        "json",
        str(video_path),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return {}
    return json.loads(res.stdout)


def run_qa_checks(video_path: Path, expected_format: str = "vertical") -> tuple[bool, list[str]]:
    notes = []
    passed = True

    if not video_path.exists():
        return False, [f"El archivo de video no existe: {video_path}"]

    data = inspect_video(video_path)
    streams = data.get("streams", [])
    v_stream = next((s for s in streams if s.get("codec_type") == "video"), None)
    a_stream = next((s for s in streams if s.get("codec_type") == "audio"), None)

    if not v_stream:
        return False, ["No se detectó pista de video en el archivo."]

    # 1. Comprobación de resolución
    width = int(v_stream.get("width", 0))
    height = int(v_stream.get("height", 0))
    if expected_format == "vertical":
        if width == 1080 and height == 1920:
            notes.append(f"[OK] Resolución vertical correcta: {width}x{height} (9:16)")
        else:
            notes.append(f"[ALERTA] Resolución no estándar para vertical: {width}x{height} (esperado 1080x1920)")
            passed = False
    elif expected_format == "horizontal":
        if (width == 1920 and height == 1080) or (width == 1280 and height == 720):
            notes.append(f"[OK] Resolución horizontal correcta: {width}x{height} (16:9)")
        else:
            notes.append(f"[ALERTA] Resolución no estándar para horizontal: {width}x{height} (esperado 1920x1080)")
            passed = False

    # 2. Comprobación de duración
    duration = float(v_stream.get("duration", 0.0))
    if expected_format == "vertical":
        if duration <= 60.0:
            notes.append(f"[OK] Duración óptima para formato corto: {duration:.1f}s (límite 60s)")
        else:
            notes.append(f"[ERROR] Duración excede el límite de Shorts/TikTok: {duration:.1f}s > 60s")
            passed = False

    # 3. Comprobación de audio
    if a_stream:
        notes.append("[OK] Pista de audio presente y activa.")
    else:
        notes.append("[ERROR] El video no tiene pista de audio.")
        passed = False

    # 4. Comprobación de archivos de subtítulos complementarios
    base_stem = video_path.stem.replace("_subtitled", "")
    ass_file = video_path.parent / f"{base_stem}.ass"
    srt_file = video_path.parent / f"{base_stem}.srt"
    if ass_file.exists() or srt_file.exists():
        notes.append("[OK] Archivos de subtítulos sincronizados detectados (.ass/.srt).")
    else:
        notes.append("[INFO] No se encontraron archivos de subtítulos externos asociados.")

    return passed, notes


def main():
    parser = argparse.ArgumentParser(description="Verificador de Control de Calidad (QA) para entregables.")
    parser.add_argument("--video", "-v", required=True, help="Ruta al video generado.")
    parser.add_argument("--format", "-f", choices=["vertical", "horizontal"], default="vertical")

    args = parser.parse_args()
    video_path = Path(args.video)

    passed, notes = run_qa_checks(video_path, args.format)
    print("\n================= REPORTE DE CONTROL DE CALIDAD =================")
    for n in notes:
        print(f"  {n}")
    print("==================================================================")
    print(f"VEREDICTO FINAL: {'[ PASS ]' if passed else '[ NEEDS REVISION ]'}\n")

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
