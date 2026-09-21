#!/usr/bin/env python3
"""Render site/og.png, the 1200x630 social preview for the landing page.

Same palette as the page: dark canvas, the app's menu bar mark, the station
accents behind the headline, and the real hero screenshot. Run it again
whenever the hero screenshot or the wording changes.

    Scripts/build-og.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
HERO = ROOT / "docs/screenshots/hero.png"
OUT = ROOT / "site/og.png"

W, H = 1200, 630
BG = (8, 8, 12)
INK = (244, 244, 247)
INK_2 = (160, 160, 175)
INK_3 = (109, 109, 124)
LINE = (255, 255, 255, 26)

# Sampled from the hero screenshot: the station tint and the panel's purple.
ACCENT = (154, 45, 214)
MAGENTA = (255, 43, 230)

SANS = "/System/Library/Fonts/HelveticaNeue.ttc"
MONO = "/System/Library/Fonts/Menlo.ttc"


def font(path: str, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size, index=index)
    except OSError:
        return ImageFont.load_default(size)


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius=radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def draw_mark(draw: ImageDraw.ImageDraw, x: int, y: int, scale: float) -> None:
    """The menu bar mark: an upright bar plus a heart, same shape as the favicon."""

    def s(value: float) -> float:
        return value * scale

    draw.rounded_rectangle((x + s(4), y + s(8), x + s(8), y + s(24)), radius=s(1), fill=INK)

    cx, cy, r = x + s(20), y + s(15), s(4.6)
    draw.ellipse((cx - s(4.7) - r, cy - r, cx - s(4.7) + r, cy + r), fill=INK)
    draw.ellipse((cx + s(4.7) - r, cy - r, cx + s(4.7) + r, cy + r), fill=INK)
    draw.polygon(
        [(cx - s(9.0), cy + s(0.6)), (cx + s(9.0), cy + s(0.6)), (cx, cy + s(9.6))],
        fill=INK,
    )


def main() -> int:
    if not HERO.exists():
        print(f"missing asset: {HERO}", file=sys.stderr)
        return 1

    canvas = Image.new("RGBA", (W, H), (*BG, 255))

    # The same two station accents that sit behind the hero on the page.
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((-220, -260, 520, 480), fill=(*ACCENT, 104))
    glow_draw.ellipse((260, -380, 900, 260), fill=(*MAGENTA, 58))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(170)))

    hero = Image.open(HERO).convert("RGBA")
    hero_h = 494
    hero_w = round(hero.width * hero_h / hero.height)
    hero = rounded(hero.resize((hero_w, hero_h), Image.LANCZOS), 20)
    hero_x, hero_y = 838, 68

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste(
        (0, 0, 0, 150),
        (hero_x, hero_y + 26, hero_x + hero_w, hero_y + 26 + hero_h),
        hero.split()[3],
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(34)))
    canvas.alpha_composite(hero, (hero_x, hero_y))

    draw = ImageDraw.Draw(canvas)

    draw_mark(draw, 78, 76, 1.05)
    draw.text((120, 80), "ILoveMusic", font=font(SANS, 27, index=1), fill=INK)

    draw.text((76, 198), "Radio aus der", font=font(SANS, 68, index=1), fill=INK)
    draw.text((76, 274), "Menüleiste.", font=font(SANS, 68, index=1), fill=MAGENTA)

    draw.text(
        (78, 414),
        "Native I Love Music App für macOS.\nFavoriten, Statistik, Discord, Stream Deck.",
        font=font(SANS, 25),
        fill=INK_2,
        spacing=13,
    )

    draw.line((78, 512, 698, 512), fill=LINE, width=1)
    draw.text(
        (78, 536),
        "MACOS 14+   ·   APPLE SILICON   ·   OPEN SOURCE",
        font=font(MONO, 17),
        fill=INK_3,
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
