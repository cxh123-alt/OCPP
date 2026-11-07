#!/usr/bin/env python3
"""Paint docs/demo.txt into docs/demo.gif.

The transcript comes from `moon run cli -- demo`; this script only renders
it. Regenerate with:

    moon run cli -- demo > docs/demo.txt
    python scripts/gen_demo_gif.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "demo.txt"
TARGET = ROOT / "docs" / "demo.gif"

PADDING = 26
LINE_HEIGHT = 21
FONT_SIZE = 13

BACKGROUND = (10, 12, 16)
TEXT = (226, 232, 240)
MUTED = (120, 128, 140)
CALL = (110, 231, 183)
REPLY = (147, 197, 253)
HEADER = (251, 191, 36)


def load_font() -> ImageFont.FreeTypeFont:
    candidates = [
        Path("C:/Windows/Fonts/consola.ttf"),
        Path("C:/Windows/Fonts/CascadiaMono.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
        Path("/System/Library/Fonts/Menlo.ttc"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), FONT_SIZE)
    raise SystemExit("no monospace font found")


def colour_for(line: str) -> tuple[int, int, int]:
    stripped = line.strip()
    if stripped.startswith("cp→cs"):
        return CALL
    if stripped.startswith("cs→cp"):
        return REPLY
    if stripped.startswith("OCPP "):
        return HEADER
    if stripped.startswith(("exchanges=", "sessions=", "1.6J", "2.0.1")):
        return MUTED
    return TEXT


def canvas_size(lines: list[str], font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    widest = max(probe.textlength(line, font=font) for line in lines)
    return int(widest) + 2 * PADDING, len(lines) * LINE_HEIGHT + 2 * PADDING


def render(
    lines: list[str],
    shown: int,
    font: ImageFont.FreeTypeFont,
    size: tuple[int, int],
) -> Image.Image:
    image = Image.new("RGB", size, BACKGROUND)
    draw = ImageDraw.Draw(image)
    y = PADDING
    for index, line in enumerate(lines):
        if index > shown:
            break
        draw.text((PADDING, y), line, font=font, fill=colour_for(line))
        y += LINE_HEIGHT
    return image


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing {SOURCE}")
    lines = [line.rstrip() for line in SOURCE.read_text(encoding="utf-8").splitlines()]
    font = load_font()
    size = canvas_size(lines, font)
    frames = [render(lines, index, font, size) for index in range(len(lines))]
    frames.append(render(lines, len(lines) - 1, font, size))
    durations = [70] * len(lines) + [2800]
    frames[0].save(
        TARGET,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
    )
    print(f"wrote {TARGET} ({len(frames)} frames, {size[0]}x{size[1]})")


if __name__ == "__main__":
    sys.exit(main())
