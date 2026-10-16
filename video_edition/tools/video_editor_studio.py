import argparse
import json
import subprocess
import sys
from pathlib import Path


def escape_ffmpeg_text(text: str) -> str:
    """Escapa caracteres especiales para el filtro drawtext de FFmpeg."""
    return (
        text.replace("\\", "\\\\")
        .replace(":", "\\:")
        .replace("'", "\\'")
        .replace("%", "\\%")
        .replace(",", "\\,")
    )


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


def build_studio_edit(
    video_path: Path,
    music_path: Path,
    cuts: list[dict],
    output_path: Path,
    transition_duration: float = 0.75,
    music_volume: float = 0.025,
) -> bool:
    """Corta fragmentos, aplica transiciones xfade, títulos con efecto y mezcla de audio con ducking."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_dir = output_path.parent / "temp_studio"
    temp_dir.mkdir(parents=True, exist_ok=True)

    n_cuts = len(cuts)
    if n_cuts == 0:
        print("[!] No hay cortes definidos.")
        return False

    auto_gain = get_auto_gain(video_path)
    print(f"[*] Ganancia adaptativa calculada para el video: +{auto_gain:.1f} dB")
    print(f"[*] Procesando {n_cuts} segmentos con títulos y normalización...")
    cut_files = []

    # 1. Cortar y preparar cada segmento con su título animado si existe
    for idx, c in enumerate(cuts, 1):
        start = c["start"]
        end = c["end"]
        duration = end - start
        title = c.get("title") or c.get("name", "")
        clean_title = escape_ffmpeg_text(title)

        seg_file = temp_dir / f"seg_{idx}.mp4"
        cut_files.append((seg_file, duration))

        # Filtro de video: Escalar a 1920x1080 + Título verde y dorado con fade
        # Verde oscuro: 0x144214, Borde Dorado: 0xF6C424
        # El título aparece en segundo 0.5 con fade in de 0.5s y dura 3.5s
        v_filters = [
            "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1"
        ]

        if clean_title:
            # Título animado con caja o borde dorado en esquina inferior izquierda
            # Usamos fontfile directo para compatibilidad garantizada en Windows
            drawtext = (
                f"drawtext=text='{clean_title}':fontfile='C\\:/Windows/Fonts/trebuc.ttf':fontsize=44:"
                f"fontcolor=0xF6C424:bordercolor=0x144214:borderw=4:"
                f"x=80:y=H-140:"
                f"enable='between(t,0.5,4.0)':alpha='if(lt(t,1.0),(t-0.5)/0.5,if(lt(t,3.5),1,(4.0-t)/0.5))'"
            )
            v_filters.append(drawtext)

        # Audio de cada corte: Realce, ecualización vocal y normalización para voz cristalina
        a_filter = f"highpass=f=80,volume={auto_gain:.1f}dB,dynaudnorm=p=0.95:m=20.0,equalizer=f=2500:width_type=q:w=1:g=3.5"

        cmd = [
            "ffmpeg",
            "-y",
            "-ss",
            str(start),
            "-to",
            str(end),
            "-i",
            str(video_path),
            "-vf",
            ",".join(v_filters),
            "-af",
            a_filter,
            "-c:v",
            "h264_nvenc",
            "-preset",
            "p4",
            "-cq",
            "22",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            str(seg_file),
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[-] Error preparando segmento {idx}: {res.stderr[-300:]}")
            return False

    print("[*] Ensamblando segmentos con transiciones de video (xfade) y audio (acrossfade)...")

    # 2. Encadenar los segmentos con xfade (Cross Dissolve)
    # Construcción de la cadena filter_complex para N segmentos
    inputs = []
    for f, _ in cut_files:
        inputs.extend(["-i", str(f)])

    filter_chains = []
    curr_v = "[0:v]"
    curr_a = "[0:a]"
    offset = cut_files[0][1] - transition_duration

    for i in range(1, n_cuts):
        next_v = f"[{i}:v]"
        next_a = f"[{i}:a]"
        out_v = f"[v{i}]"
        out_a = f"[a{i}]"

        # Transición xfade disolvencia (fade)
        filter_chains.append(
            f"{curr_v}{next_v}xfade=transition=fade:duration={transition_duration}:offset={offset:.3f}{out_v}"
        )
        # Transición suave de audio acrossfade
        filter_chains.append(
            f"{curr_a}{next_a}acrossfade=d={transition_duration}{out_a}"
        )

        curr_v = out_v
        curr_a = out_a
        offset += cut_files[i][1] - transition_duration

    # 3. Mezclar con la música de fondo en loop con ducking
    inputs.extend(["-i", str(music_path)])
    music_idx = n_cuts

    # Dividimos la voz procesada en dos pistas: una para sidechain y otra para la mezcla final
    filter_chains.append(f"{curr_a}asplit=2[voice_main][voice_sc]")
    filter_chains.append(
        f"[{music_idx}:a]aloop=loop=-1:size=2e+09,volume={music_volume}[bgm_loop]"
    )
    filter_chains.append(
        "[bgm_loop][voice_sc]sidechaincompress=threshold=0.015:ratio=16:attack=15:release=850[bgm_ducked]"
    )
    filter_chains.append(
        "[voice_main][bgm_ducked]amix=inputs=2:duration=first:dropout_transition=2:normalize=0[final_audio]"
    )

    full_filter = ";".join(filter_chains)

    master_cmd = ["ffmpeg", "-y"] + inputs + [
        "-filter_complex",
        full_filter,
        "-map",
        curr_v,
        "-map",
        "[final_audio]",
        "-c:v",
        "h264_nvenc",
        "-preset",
        "p4",
        "-cq",
        "22",
        "-c:a",
        "aac",
        "-b:a",
        "192k",
        str(output_path),
    ]

    print("[*] Renderizando video master final con aceleración GPU...")
    res = subprocess.run(master_cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print(f"[+] Video Master generado exitosamente: {output_path}")
        # Limpieza de temporales
        for f, _ in cut_files:
            try:
                f.unlink()
            except Exception:
                pass
        try:
            temp_dir.rmdir()
        except Exception:
            pass
        return True
    else:
        print(f"[-] Error en el ensamblado final: {res.stderr[-400:]}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Editor de video cinematográfico con transiciones y títulos.")
    parser.add_argument("--video", "-v", required=True, help="Video original.")
    parser.add_argument("--cuts-json", "-c", required=True, help="JSON con lista de cortes.")
    parser.add_argument("--music", "-m", help="Pista de música (opcional, busca loop por defecto).")
    parser.add_argument("--output", "-o", required=True, help="Ruta de salida del video editado.")

    args = parser.parse_args()
    video_path = Path(args.video).resolve()
    raw_json = json.loads(Path(args.cuts_json).read_text(encoding="utf-8"))

    cuts_data = raw_json.get("cuts", raw_json) if isinstance(raw_json, dict) else raw_json
    music_path = Path(args.music).resolve() if args.music else None
    if not music_path and isinstance(raw_json, dict) and raw_json.get("music_file"):
        music_path = Path(raw_json["music_file"]).resolve()

    if not music_path or not music_path.exists():
        # Fallback a una pista loop existente
        music_path = Path("arte/mp3/Morning_at_the_Steel_Spire (loop).mp3").resolve()

    success = build_studio_edit(
        video_path=video_path,
        music_path=music_path,
        cuts=cuts_data,
        output_path=Path(args.output).resolve(),
    )

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
