#!/usr/bin/env python3
"""Generate the placeholder tray icon (local-only asset, gitignored).

P0.2 stand-in icon: transparent background, blue ring, white clock hands.
The real icon design is deferred. Usage:
    python3 new-app/scripts/gen_tray_icon.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "apps/planner/assets/tray/planner_tray.png"
BLUE = (0, 85, 255, 255)      # #0055ff
WHITE = (242, 242, 242, 255)  # #f2f2f2

size = 128
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
c = size / 2

# Filled disc + outer ring.
d.ellipse([6, 6, size - 6, size - 6], fill=BLUE)
d.ellipse([6, 6, size - 6, size - 6], outline=WHITE, width=6)

# Clock hands (12 -> center -> 3).
d.line([c, 34, c, c + 6], fill=WHITE, width=8)
d.line([c, c, c + 30, c], fill=WHITE, width=8)
d.ellipse([c - 7, c - 7, c + 7, c + 7], fill=WHITE)

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT)
print(f"wrote {OUT}")
