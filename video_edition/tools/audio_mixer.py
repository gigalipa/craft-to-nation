import argparse
import random
import subprocess
import sys
from pathlib import Path


def get_music_tracks(music_dir: Path, track_type: str = "loop") -> list[Path]:
    if not music_dir.exists():
        return []
    all_tracks = list(music_dir.glob("*.mp3")) + list(music_dir.glob("*.wav")) + list(music_dir.glob("*.ogg"))
    if track_type == "loop":
        return [t for t in all_tracks if "(loop)" in t.name.lower()]
    elif track_type == "menu":
        return [t for t in all_tracks if "(menu)" in t.name.lower()]
    return all_tracks


def get_auto_gain(media_path: Path) -> float:
    """Detecta el pico máximo y calcula la ganancia exacta para alcanzar -1.5 dB de pico."""
    cmd = ["ffmpeg", "-i", str(media_path), "-af", "volumedetect", "-vn", "-f", "null", "NUL"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    for line in res.stderr.splitlines():
        if "max_volume:" in line:
            try:
                max_vol = float(line.split("max_volume:")[1].split("dB")[0].strip())
                gain = -1.5 - max_vol
                return max(0.0, min(gain, 32.0))
            except Exception:
                pass
    return 14.0


def mix_background_music(
    video_path: Path,
    music_path: Path,
    output_path: Path,
    music_volume: float = 0.025,
    has_original_audio: bool = True,
) -> bool:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Calculamos la ganancia exacta para calibrar cualquier micrófono (alto o bajo)
    auto_gain = get_auto_gain(video_path)
    print(f"[*] Ganancia adaptativa calculada para la voz: +{auto_gain:.1f} dB")

    # Si hay audio original:
    # 1. Normalizamos la voz al estándar de redes (-14 LUFS) y estabilizamos picos
    # 2. Aplicamos sidechain compression a la música (ducking agresivo: baja cuando hablas)
    # 3. amix con normalize=0 para que FFmpeg no divida el volumen de la voz a la mitad
    if has_original_audio:
        filter_complex = (
            f"[0:a]volume={auto_gain:.1f}dB,dynaudnorm=p=0.95:m=20.0[voice];"
            f"[1:a]aloop=loop=-1:size=2e+09,volume={music_volume}[bgm_loop];"
            "[bgm_loop][voice]sidechaincompress=threshold=0.015:ratio=16:attack=15:release=850[bgm_ducked];"
            "[voice][bgm_ducked]amix=inputs=2:duration=first:dropout_transition=2:normalize=0[aout]"
        )
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(video_path),
            "-i",
            str(music_path),
            "-filter_complex",
            filter_complex,
            "-map",
            "0:v",
            "-map",
            "[aout]",
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            str(output_path),
        ]
    else:
        # Si no hay audio original, el fondo musical es la pista principal
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(video_path),
            "-i",
            str(music_path),
            "-filter_complex",
            f"[1:a]aloop=loop=-1:size=2e+09,volume={music_volume}[aout]",
            "-map",
            "0:v",
            "-map",
            "[aout]",
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            str(output_path),
        ]

    print(f"[*] Mezclando '{music_path.name}' (vol: {music_volume}) en '{video_path.name}'...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print(f"[+] Video con música generado: {output_path}")
        return True
    else:
        print(f"[-] Error al mezclar música: {res.stderr[-300:]}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Mezclador de música de fondo para devlogs y gameplays.")
    parser.add_argument("--video", "-v", required=True, help="Video de entrada.")
    parser.add_argument("--output", "-o", required=True, help="Video con música de salida.")
    parser.add_argument("--track", "-t", help="Ruta específica al archivo de música MP3.")
    parser.add_argument("--music-dir", "-d", default="arte/mp3", help="Directorio con la biblioteca musical.")
    parser.add_argument("--track-type", choices=["loop", "menu", "any"], default="loop", help="Tipo de pista ('loop' para gameplay, 'menu' para menús).")
    parser.add_argument("--volume", type=float, default=0.025, help="Volumen de la música (0.01 a 1.0).")
    parser.add_argument("--no-original-audio", action="store_true", help="El video no tiene pista de audio original.")

    args = parser.parse_args()
    video_path = Path(args.video)
    if not video_path.exists():
        print(f"[!] Error: El video no existe: {video_path}")
        sys.exit(1)

    music_path = Path(args.track) if args.track else None
    if not music_path or not music_path.exists():
        tracks = get_music_tracks(Path(args.music_dir), track_type=args.track_type)
        if not tracks:
            print(f"[!] Error: No se encontraron pistas de música de tipo '{args.track_type}' en {args.music_dir}")
            sys.exit(1)
        music_path = random.choice(tracks)
        print(f"[*] Pista de fondo seleccionada automáticamente ({args.track_type}): {music_path.name}")

    success = mix_background_music(
        video_path=video_path,
        music_path=music_path,
        output_path=Path(args.output),
        music_volume=args.volume,
        has_original_audio=not args.no_original_audio,
    )

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
