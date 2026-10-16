import argparse
import shutil
from pathlib import Path


def package_processed_video(output_dir_name: str, file_paths: list[str | Path]) -> Path:
    """Empaqueta un video maestro y todos sus archivos relacionados en su propia subcarpeta dentro de processed/."""
    base_processed = Path("video_edition/media/processed").resolve()
    target_dir = base_processed / output_dir_name
    target_dir.mkdir(parents=True, exist_ok=True)

    moved_files = []
    for fp in file_paths:
        p = Path(fp).resolve()
        if p.exists() and p.is_file():
            dest = target_dir / p.name
            if p != dest:
                shutil.move(str(p), str(dest))
            moved_files.append(dest)

    print(f"[+] Paquete de entrega organizado en: {target_dir}")
    for mf in moved_files:
        print(f"    - {mf.name}")
    return target_dir


def mark_raw_as_done(raw_filename: str) -> Path | None:
    """Mueve el archivo original desde video_edition/media/raw/ hacia video_edition/media/raw/done/."""
    raw_dir = Path("video_edition/media/raw").resolve()
    done_dir = raw_dir / "done"
    done_dir.mkdir(parents=True, exist_ok=True)

    raw_file = raw_dir / raw_filename
    # Si pasaron una ruta completa o con subcarpetas
    if not raw_file.exists():
        raw_file = Path(raw_filename).resolve()

    if raw_file.exists() and raw_file.is_file():
        dest = done_dir / raw_file.name
        shutil.move(str(raw_file), str(dest))
        print(f"[+] Video original movido a 'done': {dest}")
        return dest
    else:
        print(f"[!] No se encontró el archivo original en raw: {raw_filename}")
        return None


def main():
    parser = argparse.ArgumentParser(description="Empaquetador de entregables y gestor de estado raw/done.")
    subparsers = parser.add_subparsers(dest="command")

    # Comando para empaquetar un video y sus derivados
    pack_parser = subparsers.add_parser("package", help="Agrupa un video y sus archivos relacionados en una carpeta propia.")
    pack_parser.add_argument("--name", "-n", required=True, help="Nombre de la carpeta de destino dentro de processed/.")
    pack_parser.add_argument("--files", "-f", nargs="+", required=True, help="Lista de archivos a agrupar (.mp4, .srt, .ass, etc.).")

    # Comando para mover el raw a done
    done_parser = subparsers.add_parser("done", help="Mueve el video original de raw a raw/done.")
    done_parser.add_argument("--raw", "-r", required=True, help="Nombre del archivo original en raw/ (ej. live_w1.mp4).")

    args = parser.parse_args()

    if args.command == "package":
        package_processed_video(args.name, args.files)
    elif args.command == "done":
        mark_raw_as_done(args.raw)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
