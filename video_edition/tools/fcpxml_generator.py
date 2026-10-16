import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path


def create_fcpxml_timeline(
    project_name: str,
    video_path: Path,
    music_path: Path | None,
    cuts: list[dict],  # [{'start': 10.0, 'end': 40.0, 'name': 'Clip 1'}]
    output_xml: Path,
    frame_rate: int = 30,
    width: int = 1920,
    height: int = 1080,
) -> Path:
    """Genera un archivo FCPXML estándar compatible con DaVinci Resolve (versión Free y Studio)."""
    output_xml.parent.mkdir(parents=True, exist_ok=True)

    fcpxml = ET.Element("fcpxml", version="1.8")
    resources = ET.SubElement(fcpxml, "resources")

    # Formato de video
    format_id = "r1"
    ET.SubElement(
        resources,
        "format",
        id=format_id,
        frameDuration=f"1/{frame_rate}s",
        width=str(width),
        height=str(height),
    )

    # Recurso de video
    asset_video_id = "r2"
    ET.SubElement(
        resources,
        "asset",
        id=asset_video_id,
        name=video_path.name,
        src=video_path.as_uri(),
        format=format_id,
        hasVideo="1",
        hasAudio="1",
    )

    # Recurso de música
    asset_music_id = "r3"
    if music_path and music_path.exists():
        ET.SubElement(
            resources,
            "asset",
            id=asset_music_id,
            name=music_path.name,
            src=music_path.as_uri(),
            hasAudio="1",
        )

    # Biblioteca y evento
    library = ET.SubElement(fcpxml, "library")
    event = ET.SubElement(library, "event", name="Craft to Nation")
    project = ET.SubElement(event, "project", name=project_name)

    # Secuencia (Timeline)
    sequence = ET.SubElement(
        project,
        "sequence",
        format=format_id,
        tcStart="0s",
    )
    spine = ET.SubElement(sequence, "spine")

    # Inserción de clips en la línea de tiempo
    timeline_offset = 0.0
    for i, cut in enumerate(cuts):
        start_sec = cut["start"]
        end_sec = cut["end"]
        duration_sec = end_sec - start_sec

        clip_el = ET.SubElement(
            spine,
            "asset-clip",
            name=f"{cut.get('name', f'Clip {i+1}')}",
            ref=asset_video_id,
            offset=f"{timeline_offset:.3f}s",
            start=f"{start_sec:.3f}s",
            duration=f"{duration_sec:.3f}s",
            format=format_id,
        )

        # Si hay transiciones deseadas entre cortes
        if cut.get("transition_after"):
            ET.SubElement(
                spine,
                "transition",
                name="Cross Dissolve",
                offset=f"{(timeline_offset + duration_sec - 0.5):.3f}s",
                duration="1.0s",
            )

        timeline_offset += duration_sec

    # Pista de música de fondo en spine/audio
    if music_path and music_path.exists() and timeline_offset > 0:
        # Añadimos la pista musical de fondo sincronizada
        ET.SubElement(
            spine[0] if len(spine) > 0 else spine,
            "asset-clip",
            name=music_path.name,
            ref=asset_music_id,
            lane="-1",
            offset="0s",
            duration=f"{timeline_offset:.3f}s",
            role="dialogue",
        )

    tree = ET.ElementTree(fcpxml)
    ET.indent(tree, space="  ", level=0)
    tree.write(str(output_xml), encoding="utf-8", xml_declaration=True)

    print(f"[+] Archivo FCPXML generado exitosamente: {output_xml}")
    return output_xml


def main():
    parser = argparse.ArgumentParser(description="Generador de proyectos FCPXML para DaVinci Resolve.")
    parser.add_argument("--video", "-v", required=True, help="Ruta al video de gameplay/devlog.")
    parser.add_argument("--cuts-json", "-c", required=True, help="Archivo JSON con lista de cortes [{'start': 0, 'end': 30}].")
    parser.add_argument("--output", "-o", required=True, help="Ruta de salida del archivo .fcpxml.")
    parser.add_argument("--music", "-m", help="Ruta a pista musical de fondo (opcional).")
    parser.add_argument("--name", "-n", default="Craft to Nation - Devlog Timeline", help="Nombre del proyecto/timeline.")

    args = parser.parse_args()
    video_path = Path(args.video).resolve()
    raw_json = json.loads(Path(args.cuts_json).read_text(encoding="utf-8"))
    music_path = Path(args.music).resolve() if args.music else None
    if isinstance(raw_json, dict):
        cuts_data = raw_json.get("cuts", [])
        project_name = raw_json.get("project_name", args.name)
        if not music_path and raw_json.get("music_file"):
            music_path = Path(raw_json["music_file"]).resolve()
    else:
        cuts_data = raw_json
        project_name = args.name

    create_fcpxml_timeline(
        project_name=project_name,
        video_path=video_path,
        music_path=music_path,
        cuts=cuts_data,
        output_xml=Path(args.output).resolve(),
    )


if __name__ == "__main__":
    main()
