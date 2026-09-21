#!/usr/bin/env python3
"""Turn the README screenshots into the web copies the landing page ships.

The PNGs under docs/screenshots are lossless captures at capture resolution —
fine for GitHub, far too heavy for a page whose largest one is the LCP element.
This writes WebP at the sizes the layout actually uses, flattened onto the
background colour of the section each one sits in, so their rounded corners and
drop shadows keep blending in. WebP roughly halves JPEG's size at equal quality
on UI screenshots, and every browser that runs macOS 14 supports it.

Running this locally and committing the result keeps the Pages build free of
any image tooling; Scripts/build-site.sh only copies what is here.

    Scripts/build-images.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/screenshots"
OUT = ROOT / "site/screenshots"

BG_PAGE = (8, 8, 12)      # --bg, the plain sections
BG_SUNK = (12, 12, 18)    # --bg-soft, the .band.alt sections

# name, target width, background to flatten onto, WebP quality
IMAGES = [
    ("hero.png", 766, BG_PAGE, 86),
    ("stats.png", 1400, BG_SUNK, 82),
    ("history.png", 1400, BG_SUNK, 82),
    ("streamdeck.png", 896, BG_SUNK, 84),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    total_before = 0
    total_after = 0

    for name, width, background, quality in IMAGES:
        path = SRC / name
        if not path.exists():
            print(f"missing screenshot: {path}", file=sys.stderr)
            return 1

        image = Image.open(path)
        total_before += path.stat().st_size

        if image.mode in ("RGBA", "LA"):
            flat = Image.new("RGB", image.size, background)
            flat.paste(image, mask=image.getchannel("A"))
            image = flat
        else:
            image = image.convert("RGB")

        if image.width > width:
            height = round(image.height * width / image.width)
            image = image.resize((width, height), Image.LANCZOS)

        destination = OUT / f"{Path(name).stem}.webp"
        image.save(destination, "WEBP", quality=quality, method=6)
        size = destination.stat().st_size
        total_after += size
        print(f"{destination.name}: {image.width}x{image.height}, {size // 1024} KB")

    print(f"total {total_before // 1024} KB -> {total_after // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
