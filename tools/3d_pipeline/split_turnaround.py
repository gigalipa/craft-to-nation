#!/usr/bin/env python3
"""Recorta un Turnaround Sheet panoramico de 3 paneles (Frontal | Lateral Izq | Espalda)
en 3 imagenes cuadradas centradas con margenes uniformes listas para Hunyuan3D-2mv.

Uso:
    python tools/3d_pipeline/split_turnaround.py --input hoja.png --output-dir scratch/turnaround_out
"""

from __future__ import annotations

import argparse
from pathlib import Path
from PIL import Image


def _crop_and_center(panel: Image.Image, size: int, margin_ratio: float, bg_threshold: int) -> Image.Image:
    rgb = panel.convert("RGB")
    w, h = rgb.size
    px = rgb.load()

    # Encuentra bounding box de pixeles no-blancos (o con alfa > 10 si tiene transparencia)
    has_alpha = panel.mode in ("RGBA", "LA")
    alpha = panel.split()[-1].load() if has_alpha else None

    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if alpha is not None and alpha[x, y] <= 10:
                continue
            r, g, b = px[x, y]
            if r < bg_threshold or g < bg_threshold or b < bg_threshold:
                if x < min_x:
                    min_x = x
                if y < min_y:
                    min_y = y
                if x > max_x:
                    max_x = x
                if y > max_y:
                    max_y = y

    cropped = panel.crop((min_x, min_y, max_x + 1, max_y + 1)) if max_x >= min_x else panel
    cw, ch = cropped.size
    inner = max(1, int(size * (1.0 - 2.0 * margin_ratio)))
    scale = min(inner / max(cw, 1), inner / max(ch, 1))
    nw, nh = max(1, int(round(cw * scale))), max(1, int(round(ch * scale)))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    ox = (size - nw) // 2
    oy = (size - nh) // 2
    canvas.paste(resized.convert("RGBA"), (ox, oy), resized.convert("RGBA") if has_alpha else None)
    return canvas.convert("RGB")


def _find_panel_bounds(img: Image.Image, bg_threshold: int) -> list[tuple[int, int]]:
    """Detecta los 3 paneles buscando los 2 huecos blancos mas anchos entre figuras.
    Cae a tercios iguales si no hay 2 huecos claros."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    has_alpha = img.mode in ("RGBA", "LA")
    alpha = img.split()[-1].load() if has_alpha else None

    col_has_fg = [False] * w
    for x in range(w):
        for y in range(h):
            if alpha is not None and alpha[x, y] <= 10:
                continue
            r, g, b = px[x, y]
            if r < bg_threshold or g < bg_threshold or b < bg_threshold:
                col_has_fg[x] = True
                break

    fg_cols = [x for x, v in enumerate(col_has_fg) if v]
    if not fg_cols:
        pw = w / 3.0
        return [(int(round(i * pw)), int(round((i + 1) * pw))) for i in range(3)]

    first_x, last_x = fg_cols[0], fg_cols[-1]
    gaps: list[tuple[int, int, int]] = []  # (width, start, end)
    x = first_x
    while x <= last_x:
        if not col_has_fg[x]:
            start = x
            while x <= last_x and not col_has_fg[x]:
                x += 1
            gaps.append((x - start, start, x))
        else:
            x += 1

    if len(gaps) >= 2:
        top2 = sorted(sorted(gaps, key=lambda g: g[0], reverse=True)[:2], key=lambda g: g[1])
        c1 = (top2[0][1] + top2[0][2]) // 2
        c2 = (top2[1][1] + top2[1][2]) // 2
        return [(0, c1), (c1, c2), (c2, w)]

    pw = w / 3.0
    return [(int(round(i * pw)), int(round((i + 1) * pw))) for i in range(3)]


def split_turnaround(
    input_path: Path,
    output_dir: Path,
    size: int = 1024,
    margin: float = 0.08,
    bg_threshold: int = 245,
    order: tuple[str, str, str] = ("front", "left", "back"),
) -> dict[str, Path]:
    img = Image.open(input_path)
    _, h = img.size
    bounds = _find_panel_bounds(img, bg_threshold=bg_threshold)
    output_dir.mkdir(parents=True, exist_ok=True)

    outputs: dict[str, Path] = {}
    for (left, right), view in zip(bounds, order):
        panel = img.crop((left, 0, right, h))
        out_img = _crop_and_center(panel, size=size, margin_ratio=margin, bg_threshold=bg_threshold)
        out_path = output_dir / f"{view}.png"
        out_img.save(out_path, format="PNG")
        outputs[view] = out_path
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description="Divide un turnaround sheet de 3 paneles en front/left/back.")
    parser.add_argument("--input", "-i", required=True, type=Path, help="Ruta a la imagen turnaround sheet.")
    parser.add_argument("--output-dir", "-o", required=True, type=Path, help="Carpeta destino para front/left/back.png.")
    parser.add_argument("--size", type=int, default=1024, help="Resolucion cuadrada de salida (default: 1024).")
    parser.add_argument("--margin", type=float, default=0.08, help="Margen uniforme proporcional (default: 0.08).")
    parser.add_argument("--bg-threshold", type=int, default=245, help="Umbral RGB para detectar fondo blanco (default: 245).")
    parser.add_argument(
        "--order",
        default="front,left,back",
        help="Orden de paneles de izquierda a derecha separado por comas (default: front,left,back).",
    )
    args = parser.parse_args()

    order_parts = tuple(p.strip() for p in args.order.split(",") if p.strip())
    if len(order_parts) != 3:
        raise SystemExit(f"--order debe tener exactamente 3 vistas, recibido: {args.order}")

    outputs = split_turnaround(
        input_path=args.input,
        output_dir=args.output_dir,
        size=args.size,
        margin=args.margin,
        bg_threshold=args.bg_threshold,
        order=order_parts,  # type: ignore[arg-type]
    )
    for view, path in outputs.items():
        print(f"{view}: {path}")


if __name__ == "__main__":
    main()
