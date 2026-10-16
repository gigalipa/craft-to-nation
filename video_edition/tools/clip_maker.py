import argparse
import subprocess
import sys
from pathlib import Path


def time_to_seconds(time_str: str) -> float:
    """Convierte HH:MM:SS o SS a segundos flotantes."""
    if not time_str:
        return 0.0
    parts = time_str.split(":")
    if len(parts) == 3:
        return float(parts[0]) * 3600 + float(parts[1]) * 60 + float(parts[2])
    elif len(parts) == 2:
        return float(parts[0]) * 60 + float(parts[1])
    return float(time_str)


def build_filter_complex(format_type: str, blur_bg: bool) -> str:
    """Construye la cadena de filtros para FFmpeg."""
    if format_type == "vertical":
        if blur_bg:
            # Fondo 1080x1920 recortado y desenfocado + Frente centrado manteniendo aspecto
            return (
                "[0:v]split=2[bg_in][fg_in];"
                "[bg_in]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,"
                "boxblur=20:5,eq=brightness=-0.15[bg];"
                "[fg_in]scale=1080:-1[fg];"
                "[bg][fg]overlay=(W-w)/2:(H-h)/2[outv]"
            )
        else:
            # Recorte 9:16 directo al centro
            return "[0:v]crop=ih*9/16:ih:(iw-ow)/2:0,scale=1080:1920[outv]"
    elif format_type == "horizontal":
        return "[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2[outv]"
    return ""


def run_ffmpeg_cut(
    input_path: Path,
    output_path: Path,
    start: float,
    end: float | None = None,
    format_type: str = "vertical",
    blur_bg: bool = True,
    use_nvenc: bool = True,
) -> bool:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    filter_str = build_filter_complex(format_type, blur_bg)

    # Intentamos primero con NVENC si se solicitó, con fallback a libx264
    encoders = ["h264_nvenc", "libx264"] if use_nvenc else ["libx264"]

    for encoder in encoders:
        cmd = ["ffmpeg", "-y", "-ss", str(start)]
        if end is not None:
            cmd.extend(["-to", str(end)])
        cmd.extend(["-i", str(input_path)])

        if filter_str:
            cmd.extend(["-filter_complex", filter_str, "-map", "[outv]", "-map", "0:a?"])
        else:
            cmd.extend(["-map", "0:v?", "-map", "0:a?"])

        cmd.extend(["-c:v", encoder])
        if encoder == "h264_nvenc":
            cmd.extend(["-preset", "p4", "-cq", "23"])
        else:
            cmd.extend(["-preset", "veryfast", "-crf", "22"])

        cmd.extend(["-c:a", "aac", "-b:a", "192k", str(output_path)])

        print(f"[*] Ejecutando corte con encoder '{encoder}'...")
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            print(f"[+] Clip generado con éxito: {output_path}")
            return True
        else:
            print(f"[-] Error con encoder '{encoder}': {res.stderr[-300:]}")
            if encoder == encoders[-1]:
                return False
    return False


def main():
    parser = argparse.ArgumentParser(description="Recorte y formateo de clips para redes sociales.")
    parser.add_argument("--input", "-i", required=True, help="Ruta al video original.")
    parser.add_argument("--output", "-o", required=True, help="Ruta del video de salida.")
    parser.add_argument("--start", "-s", default="0", help="Inicio del corte (segundos o HH:MM:SS).")
    parser.add_argument("--end", "-e", default=None, help="Fin del corte (segundos o HH:MM:SS).")
    parser.add_argument("--format", "-f", choices=["vertical", "horizontal", "original"], default="vertical")
    parser.add_argument("--no-blur", action="store_true", help="Usa recorte central directo en lugar de fondo blur.")
    parser.add_argument("--cpu", action="store_true", help="Fuerza uso de CPU (libx264) en vez de NVIDIA NVENC.")

    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[!] Error: El archivo no existe: {input_path}")
        sys.exit(1)

    output_path = Path(args.output)
    start_sec = time_to_seconds(args.start)
    end_sec = time_to_seconds(args.end) if args.end else None

    success = run_ffmpeg_cut(
        input_path=input_path,
        output_path=output_path,
        start=start_sec,
        end=end_sec,
        format_type=args.format,
        blur_bg=not args.no_blur,
        use_nvenc=not args.cpu,
    )

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
