#!/usr/bin/env python3
"""Check sprite sheets for the site: N frames of 256x256 in one row, transparent, nothing
touching a cell's border. Writes <sheet>-view.png (the frames on teal) to look at.

    python3 sprite-check.py out/crab-*.png          # exit 1 when a sheet fails

Needs Pillow. A figure that touches its cell's border, or ends on a straight edge (cut by
the generator), looks clipped when played: regenerate it.
"""
import sys
from PIL import Image

CELL, BORDER, CUT = 256, 4, 16   # CUT: an opaque straight run this long on the figure's edge = clipped


def run(values):
    best = cur = 0
    for v in values:
        cur = cur + 1 if v > 128 else 0
        best = max(best, cur)
    return best


bad = 0
for path in sys.argv[1:]:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    if h != CELL or w % CELL:
        print(f"FAIL {path}: {w}x{h}, want N*{CELL}x{CELL}")
        bad = 1
        continue
    alpha, faults = im.getchannel("A"), []
    for i in range(w // CELL):
        px = alpha.crop((i * CELL, 0, (i + 1) * CELL, CELL)).load()
        edge = sum(1 for a in range(CELL) for b in range(BORDER)
                   for x, y in ((a, b), (a, CELL - 1 - b), (b, a), (CELL - 1 - b, a)) if px[x, y])
        if edge:
            faults.append(f"frame {i + 1}: {edge} px on the border")
        # a natural outline tapers; a pose cut by the generator ends on a straight edge
        box = alpha.crop((i * CELL, 0, (i + 1) * CELL, CELL)).getbbox()
        if box:
            x0, y0, x1, y1 = box
            for side, line in (("left", [px[x0, y] for y in range(y0, y1)]), ("right", [px[x1 - 1, y] for y in range(y0, y1)]),
                               ("top", [px[x, y0] for x in range(x0, x1)])):
                if run(line) >= CUT:
                    faults.append(f"frame {i + 1}: cut straight on the {side}")
    view = Image.new("RGBA", im.size, (20, 196, 189, 255))
    view.alpha_composite(im)
    view.save(path.rsplit(".", 1)[0] + "-view.png")
    print(f"{'FAIL' if faults else 'ok  '} {path}: {w // CELL} frames" + ("; " + ", ".join(faults) if faults else ""))
    bad |= bool(faults)
sys.exit(bad)
