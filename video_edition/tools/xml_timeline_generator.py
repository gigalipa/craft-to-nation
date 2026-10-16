import argparse
import json
from pathlib import Path


def sec_to_frames(sec: float, fps: int = 30) -> int:
    return int(round(sec * fps))


def generate_fcp7_xml(
    project_name: str,
    video_path: Path,
    music_path: Path | None,
    cuts: list[dict],
    output_xml: Path,
    fps: int = 30,
    width: int = 1920,
    height: int = 1080,
) -> Path:
    """Genera archivo FCP 7 XML (.xml) 100% compatible con DaVinci Resolve (Free y Studio)."""
    output_xml.parent.mkdir(parents=True, exist_ok=True)

    # Rutas URL absolutas compatibles
    v_url = video_path.resolve().as_uri()
    m_url = music_path.resolve().as_uri() if music_path and music_path.exists() else None

    # Cálculo de frames totales
    total_timeline_frames = sum(sec_to_frames(c["end"] - c["start"], fps) for c in cuts)

    xml_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE xmeml>',
        '<xmeml version="5">',
        '  <sequence>',
        f'    <name>{project_name}</name>',
        f'    <duration>{total_timeline_frames}</duration>',
        '    <rate>',
        f'      <timebase>{fps}</timebase>',
        '      <ntsc>FALSE</ntsc>',
        '    </rate>',
        '    <media>',
        '      <video>',
        '        <format>',
        '          <samplecharacteristics>',
        f'            <width>{width}</width>',
        f'            <height>{height}</height>',
        '            <pixelaspectratio>square</pixelaspectratio>',
        '          </samplecharacteristics>',
        '        </format>',
        '        <track>',
    ]

    curr_timeline_frame = 0
    for idx, c in enumerate(cuts, 1):
        in_frame = sec_to_frames(c["start"], fps)
        out_frame = sec_to_frames(c["end"], fps)
        clip_duration = out_frame - in_frame
        clip_name = c.get("name", f"Clip {idx}")

        xml_lines.extend([
            f'          <clipitem id="clipitem-v{idx}">',
            f'            <name>{clip_name}</name>',
            f'            <duration>{clip_duration}</duration>',
            '            <rate>',
            f'              <timebase>{fps}</timebase>',
            '              <ntsc>FALSE</ntsc>',
            '            </rate>',
            f'            <in>{in_frame}</in>',
            f'            <out>{out_frame}</out>',
            f'            <start>{curr_timeline_frame}</start>',
            f'            <end>{curr_timeline_frame + clip_duration}</end>',
            '            <file id="file-video">',
            f'              <name>{video_path.name}</name>',
            f'              <pathurl>{v_url}</pathurl>',
            '              <rate>',
            f'                <timebase>{fps}</timebase>',
            '                <ntsc>FALSE</ntsc>',
            '              </rate>',
            '              <media>',
            '                <video>',
            '                  <samplecharacteristics>',
            f'                    <width>{width}</width>',
            f'                    <height>{height}</height>',
            '                  </samplecharacteristics>',
            '                </video>',
            '              </media>',
            '            </file>',
            '          </clipitem>',
        ])
        curr_timeline_frame += clip_duration

    xml_lines.extend([
        '        </track>',
        '      </video>',
        '      <audio>',
    ])

    # Pista de audio 1: Audio original sincronizado
    xml_lines.append('        <track>')
    curr_timeline_frame = 0
    for idx, c in enumerate(cuts, 1):
        in_frame = sec_to_frames(c["start"], fps)
        out_frame = sec_to_frames(c["end"], fps)
        clip_duration = out_frame - in_frame
        xml_lines.extend([
            f'          <clipitem id="clipitem-a-orig{idx}">',
            f'            <name>Audio {idx}</name>',
            f'            <duration>{clip_duration}</duration>',
            '            <rate>',
            f'              <timebase>{fps}</timebase>',
            '              <ntsc>FALSE</ntsc>',
            '            </rate>',
            f'            <in>{in_frame}</in>',
            f'            <out>{out_frame}</out>',
            f'            <start>{curr_timeline_frame}</start>',
            f'            <end>{curr_timeline_frame + clip_duration}</end>',
            '            <file id="file-video" />',
            '          </clipitem>',
        ])
        curr_timeline_frame += clip_duration
    xml_lines.append('        </track>')

    # Pista de audio 2: Música de fondo si existe
    if m_url and music_path:
        xml_lines.extend([
            '        <track>',
            '          <clipitem id="clipitem-music">',
            f'            <name>{music_path.name}</name>',
            f'            <duration>{total_timeline_frames}</duration>',
            '            <rate>',
            f'              <timebase>{fps}</timebase>',
            '              <ntsc>FALSE</ntsc>',
            '            </rate>',
            '            <in>0</in>',
            f'            <out>{total_timeline_frames}</out>',
            '            <start>0</start>',
            f'            <end>{total_timeline_frames}</end>',
            '            <file id="file-music">',
            f'              <name>{music_path.name}</name>',
            f'              <pathurl>{m_url}</pathurl>',
            '              <rate>',
            f'                <timebase>{fps}</timebase>',
            '                <ntsc>FALSE</ntsc>',
            '              </rate>',
            '            </file>',
            '          </clipitem>',
            '        </track>',
        ])

    xml_lines.extend([
        '      </audio>',
        '    </media>',
        '  </sequence>',
        '</xmeml>',
    ])

    output_xml.write_text("\n".join(xml_lines), encoding="utf-8")
    print(f"[+] Archivo FCP 7 XML generado: {output_xml}")
    print(f"[*] Duración total de la línea de tiempo: {total_timeline_frames / fps:.1f} segundos ({total_timeline_frames} frames)")
    return output_xml


def main():
    parser = argparse.ArgumentParser(description="Generador de proyectos FCP 7 XML para DaVinci Resolve.")
    parser.add_argument("--video", "-v", required=True, help="Ruta al video raw.")
    parser.add_argument("--cuts-json", "-c", required=True, help="JSON con lista de cortes.")
    parser.add_argument("--music", "-m", help="Ruta al MP3 de música (opcional).")
    parser.add_argument("--output", "-o", required=True, help="Ruta del archivo .xml de salida.")

    args = parser.parse_args()
    video_path = Path(args.video).resolve()
    raw_json = json.loads(Path(args.cuts_json).read_text(encoding="utf-8"))

    cuts_data = raw_json.get("cuts", raw_json) if isinstance(raw_json, dict) else raw_json
    project_name = raw_json.get("project_name", "Craft to Nation Timeline") if isinstance(raw_json, dict) else "Craft to Nation Timeline"

    music_path = Path(args.music).resolve() if args.music else None
    if not music_path and isinstance(raw_json, dict) and raw_json.get("music_file"):
        music_path = Path(raw_json["music_file"]).resolve()

    generate_fcp7_xml(
        project_name=project_name,
        video_path=video_path,
        music_path=music_path,
        cuts=cuts_data,
        output_xml=Path(args.output).resolve(),
    )


if __name__ == "__main__":
    main()
