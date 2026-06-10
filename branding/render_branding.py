#!/usr/bin/env python3
"""
Generate all FoundryMTR Launcher branding PNGs from scratch using Pillow.

Outputs:
    png/icon_16.png       Tiny tray/favicon
    png/icon_32.png       Small UI
    png/icon_48.png       Linux small
    png/icon_64.png       Standard UI
    png/icon_128.png      Large UI
    png/icon_256.png      Mac standard
    png/icon_512.png      Hi-DPI Mac
    png/icon_1024.png     Source for app icons
    png/logo_320x320.png  Helios standard logo
    png/SealCircle.png    Helios alternate icon name (256px)
    png/wordmark.png      Horizontal wordmark with sub-label
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import os

# FoundryMTR color palette
INK     = (10, 14, 20, 255)
RAIL    = (21, 27, 35, 255)
CHALK   = (242, 244, 247, 255)
SIGNAL  = (232, 37, 43, 255)
FOG     = (139, 149, 163, 255)
TRANSPARENT = (0, 0, 0, 0)

OUT = Path(__file__).parent / "png"
OUT.mkdir(exist_ok=True, parents=True)


def find_font(weight: str = "Bold") -> str:
    """Find a usable bold sans-serif font on the system."""
    candidates = [
        f"/usr/share/fonts/truetype/dejavu/DejaVuSans-{weight}.ttf",
        f"/usr/share/fonts/truetype/liberation/LiberationSans-{weight}.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",  # fallback
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    raise RuntimeError("No suitable font found on system")


BOLD_FONT = find_font("Bold")
REG_FONT = find_font("Bold")  # use bold for everything since this is signage


def draw_roundel(size: int, include_sublabel: bool = False) -> Image.Image:
    """
    Draw a FoundryMTR roundel: outer ring, inner dark fill, horizontal signal bar with FMTR text.

    The roundel takes the full image. Bar is centered vertically.
    """
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(img)

    # Calculate geometry scaled to size
    center = size / 2
    # If we're showing a sub-label, shrink the roundel a bit to leave room
    if include_sublabel:
        outer_radius = size * 0.36
        roundel_center_y = size * 0.42  # shift roundel up
    else:
        outer_radius = size * 0.42
        roundel_center_y = center
    ring_width = max(2, int(size * 0.055))
    inner_radius = outer_radius - ring_width / 2 - 1

    # Outer ring (filled circle in signal, then inner circle in ink)
    d.ellipse(
        [center - outer_radius, roundel_center_y - outer_radius,
         center + outer_radius, roundel_center_y + outer_radius],
        fill=SIGNAL
    )
    d.ellipse(
        [center - inner_radius, roundel_center_y - inner_radius,
         center + inner_radius, roundel_center_y + inner_radius],
        fill=INK
    )

    # Horizontal bar — extends slightly past the ring on both sides for that classic
    # transit roundel look. Centered vertically on the roundel.
    bar_height = outer_radius * 0.42
    bar_y_top = roundel_center_y - bar_height / 2
    bar_y_bot = roundel_center_y + bar_height / 2
    bar_x_left = center - outer_radius * 1.18
    bar_x_right = center + outer_radius * 1.18

    d.rectangle(
        [bar_x_left, bar_y_top, bar_x_right, bar_y_bot],
        fill=SIGNAL
    )

    # Roundel text "FMTR" (matches the sanctioned internal prefix; one-constant
    # cosmetic change if the owner later wants a different glyph)
    # Pick font size by fitting roughly 65% of bar height
    font_size = int(bar_height * 0.65)
    try:
        font = ImageFont.truetype(BOLD_FONT, font_size)
    except Exception:
        font = ImageFont.load_default()

    text = "FMTR"
    bbox = d.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = center - text_w / 2 - bbox[0]
    text_y = roundel_center_y - text_h / 2 - bbox[1]

    d.text((text_x, text_y), text, fill=CHALK, font=font)

    # Optional sub-label below the roundel
    if include_sublabel and size >= 200:
        sub_text = "RAILWAY · NETWORK"
        sub_size = max(10, int(size * 0.04))
        try:
            sub_font = ImageFont.truetype(BOLD_FONT, sub_size)
        except Exception:
            sub_font = ImageFont.load_default()

        # Tracked-out caps — draw each char with manual letter-spacing
        spacing = sub_size * 0.35
        chars = list(sub_text)
        char_widths = []
        for c in chars:
            cb = d.textbbox((0, 0), c, font=sub_font)
            char_widths.append(cb[2] - cb[0])
        total_w = sum(char_widths) + spacing * (len(chars) - 1)
        x = center - total_w / 2
        sub_y = roundel_center_y + outer_radius + sub_size * 1.2
        for i, c in enumerate(chars):
            d.text((x, sub_y), c, fill=CHALK, font=sub_font)
            x += char_widths[i] + spacing

    return img


def draw_wordmark(width: int = 1280, height: int = 192) -> Image.Image:
    """Horizontal wordmark: small roundel + 'FOUNDRYMTR' text."""
    img = Image.new("RGBA", (width, height), TRANSPARENT)
    d = ImageDraw.Draw(img)

    # Small roundel on the left
    roundel_size = int(height * 0.85)
    roundel = draw_roundel(roundel_size, include_sublabel=False)
    roundel_y = (height - roundel_size) // 2
    img.paste(roundel, (16, roundel_y), roundel)

    # Wordmark text — size to fit available width
    text_x = roundel_size + 40
    available_w = width - text_x - 32

    word_text = "FOUNDRYMTR"
    sub_text = "PASSENGER LAUNCHER · v1.0"

    # Pick word font size that fits within available width
    word_font_size = int(height * 0.26)
    while word_font_size > 12:
        try:
            word_font = ImageFont.truetype(BOLD_FONT, word_font_size)
        except Exception:
            word_font = ImageFont.load_default()
            break
        wb = d.textbbox((0, 0), word_text, font=word_font)
        if (wb[2] - wb[0]) <= available_w:
            break
        word_font_size -= 2

    sub_font_size = int(word_font_size * 0.42)
    try:
        sub_font = ImageFont.truetype(REG_FONT, sub_font_size)
    except Exception:
        sub_font = ImageFont.load_default()

    word_bbox = d.textbbox((0, 0), word_text, font=word_font)
    word_h = word_bbox[3] - word_bbox[1]

    # Position word above center, sub below
    word_y = height / 2 - word_h - 4
    d.text((text_x, word_y), word_text, fill=CHALK, font=word_font)

    sub_y = height / 2 + 8
    d.text((text_x, sub_y), sub_text, fill=FOG, font=sub_font)

    return img


def main():
    # Standard icon sizes
    sizes = [16, 32, 48, 64, 128, 256, 512, 1024]
    for s in sizes:
        img = draw_roundel(s, include_sublabel=False)
        out = OUT / f"icon_{s}.png"
        img.save(out, "PNG", optimize=True)
        print(f"  OK  {out.name}  ({s}x{s})")

    # Helios standard logo (320x320, with sub-label)
    logo = draw_roundel(320, include_sublabel=True)
    logo.save(OUT / "logo_320x320.png", "PNG", optimize=True)
    print(f"  OK  logo_320x320.png  (320x320 with sub-label)")

    # Helios SealCircle (alternate icon name)
    seal = draw_roundel(256, include_sublabel=False)
    seal.save(OUT / "SealCircle.png", "PNG", optimize=True)
    print(f"  OK  SealCircle.png  (256x256)")

    # Horizontal wordmark
    wm = draw_wordmark(1280, 192)
    wm.save(OUT / "wordmark.png", "PNG", optimize=True)
    print(f"  OK  wordmark.png  (1280x192)")

    print(f"\nAll branding rendered to: {OUT}")


if __name__ == "__main__":
    main()
