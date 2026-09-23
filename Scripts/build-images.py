#!/usr/bin/env python3
"""Turn the README screenshots into the web copies the landing page ships.

The PNGs under docs/screenshots are lossless captures at capture resolution —
fine for GitHub, far too heavy for a page whose largest one is the LCP element.
This writes WebP at the sizes the layout actually uses. Window captures are
flattened onto the background they sit on, so their rounded corners and drop
shadows keep blending in. WebP roughly halves JPEG's size at equal quality on
UI screenshots, and every browser that runs macOS 14 supports it.

The hero panel is the exception: it hangs inside the page's drawn Mac screen,
over a gradient, so no flat colour would match. Its capture has the menu-bar
panel on solid black, so the black reachable from the image border is cut out
to transparency instead, leaving the panel with its arrow.

The feature tiles reuse slices of that same capture, so they always show the
panel exactly as the hero does. The slices stay inside the panel's border, so
the page can round their corners itself instead of inheriting a cut edge.

Running this locally and committing the result keeps the Pages build free of
any image tooling; Scripts/build-site.sh only copies what is here.

    Scripts/build-images.py
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/screenshots"
OUT = ROOT / "site/screenshots"

BG_PAGE = (7, 7, 10)  # --bg

# Anything this dark and connected to the border is capture background, not panel.
CUTOUT_MAX_CHANNEL = 8

# name, output stem, target width, background (None = cut out), crop box, WebP quality
IMAGES = [
    ("hero.png", "hero", 766, None, None, 88),
    ("hero.png", "panel-player", 746, None, (10, 30, 756, 420), 86),
    ("hero.png", "panel-favorites", 746, None, (10, 412, 756, 1040), 86),
    ("stats.png", "stats", 1400, BG_PAGE, None, 82),
    ("history.png", "history", 1400, BG_PAGE, None, 82),
    ("streamdeck.png", "streamdeck", 896, BG_PAGE, None, 84),
]


def cut_out_border_black(image: Image.Image) -> Image.Image:
    """Make the near-black region connected to the image border transparent."""
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    outside = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        r, g, b, _ = pixels[x, y]
        return max(r, g, b) <= CUTOUT_MAX_CHANNEL

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if outside[index] or not is_background(x, y):
            continue
        outside[index] = 1
        if x > 0:
            queue.append((x - 1, y))
        if x < width - 1:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y < height - 1:
            queue.append((x, y + 1))

    mask = Image.frombytes("L", (width, height), bytes(255 - 255 * v for v in outside))
    # A hard 1-bit edge would stair-step the rounded corners; a light blur
    # restores the anti-aliasing the black backdrop used to provide.
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))
    rgba.putalpha(mask)
    return rgba


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    total_after = 0
    cutouts: dict[str, Image.Image] = {}

    for name, stem, width, background, crop, quality in IMAGES:
        path = SRC / name
        if not path.exists():
            print(f"missing screenshot: {path}", file=sys.stderr)
            return 1

        if background is None:
            if name not in cutouts:
                cutouts[name] = cut_out_border_black(Image.open(path))
            image = cutouts[name]
        else:
            image = Image.open(path)
            if image.mode in ("RGBA", "LA"):
                flat = Image.new("RGB", image.size, background)
                flat.paste(image, mask=image.getchannel("A"))
                image = flat
            else:
                image = image.convert("RGB")

        if crop is not None:
            image = image.crop(crop)

        if image.width > width:
            height = round(image.height * width / image.width)
            image = image.resize((width, height), Image.LANCZOS)

        destination = OUT / f"{stem}.webp"
        image.save(destination, "WEBP", quality=quality, method=6)
        size = destination.stat().st_size
        total_after += size
        print(f"{destination.name}: {image.width}x{image.height}, {size // 1024} KB")

    print(f"total {total_after // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
