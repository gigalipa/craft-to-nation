import argparse
import json
import re
import sys
from pathlib import Path


# Glosario y reglas fonéticas frecuentes de Craft to Nation / Gamedev
GAME_CORRECTIONS = [
    (r"\bbaúla\b", "bahía"),
    (r"\bbaula\b", "bahía"),
    (r"\ben esta leerla\b", "en esta hilera"),
    (r"\ben esta lera\b", "en esta hilera"),
    (r"\bbluprint\b", "blueprint"),
    (r"\bbluprints\b", "blueprints"),
    (r"\btenserrados\b", "estén cerrados"),
    (r"\bun biólogo\b", "como válido"),
    (r"\bun bólogo\b", "un bloque"),
    (r"\byo trobo a UL\b", "y otro baúl"),
    (r"\bel prehistoria\b", "la prehistoria"),
    (r"\bmedioal\b", "medieval"),
    (r"\bEasy Punk\b", "Dieselpunk"),
    (r"\bADD, penino, color.*\b", "Dieselpunk, Cyberpunk o Solarpunk."),
    (r"\bpenino\b", "Dieselpunk"),
    (r"\bcolor, o color\b", "Cyberpunk o Solarpunk"),
    (r"\bpor el\?\?\b", ""),
    (r"\bhecho de muy snacks entonces\b", ""),
    (r"\bmazón\b", "almacén"),
    (r"\bal mazón\b", "almacén"),
    (r"\btiericamente\b", "teóricamente"),
    (r"\bla edificio industriales\b", "los edificios industriales"),
    (r"\bdos puntos en coma, más de la ta bien\b", "2.1 con madera está bien"),
    (r"\bdonde hay un por acá y bastante\b", "por acá hay bastante"),
    (r"\b4 puntos\b", ""),
    (r"\botro seco\b", "otro puesto"),
    (r"\botro puesto de casa\b", "otro puesto de caza"),
]


def clean_text_with_glossary(text: str) -> str:
    cleaned = text
    for pattern, replacement in GAME_CORRECTIONS:
        cleaned = re.sub(pattern, replacement, cleaned, flags=re.IGNORECASE)
    # Limpiar espacios múltiples y puntuación rota
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


def clean_segments(segments: list[dict]) -> list[dict]:
    cleaned_segments = []
    for seg in segments:
        raw_text = seg.get("text", "")
        fixed_text = clean_text_with_glossary(raw_text)
        # Si el segmento quedó vacío tras eliminar alucinaciones de Whisper, lo ignoramos
        if fixed_text and fixed_text != "...":
            seg_copy = dict(seg)
            seg_copy["text"] = fixed_text
            cleaned_segments.append(seg_copy)
    return cleaned_segments


def main():
    parser = argparse.ArgumentParser(description="Limpiador y corrector contextual de subtítulos para Craft to Nation.")
    parser.add_argument("--input", "-i", required=True, help="Archivo JSON de segmentos original.")
    parser.add_argument("--output", "-o", required=True, help="Archivo JSON de segmentos corregido.")

    args = parser.parse_args()
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[!] Error: No existe {input_path}")
        sys.exit(1)

    segments = json.loads(input_path.read_text(encoding="utf-8"))
    cleaned = clean_segments(segments)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(cleaned, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[+] Subtítulos corregidos guardados en: {out_path} ({len(cleaned)} segmentos)")


if __name__ == "__main__":
    main()
