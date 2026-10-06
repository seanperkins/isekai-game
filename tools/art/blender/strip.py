"""Look at frames: lay the frames of one or more animations in rows, magnified, on the backdrop, with a ground line.

    python3 tools/art/blender/strip.py DIR anim[,anim...] [--zoom 4] [--out strip.png] [--cols 12]

DIR is a folder spike.process wrote (it holds frames/<anim>_<n>.png). Every frame is cropped to the union of the animation's frames so the
body holds still in its cell.
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw

BACKDROP, GROUND, INK = (36, 36, 46, 255), (70, 70, 90, 255), (220, 220, 230, 255)


def frames_of(folder, anim):
    out, i = [], 0
    while os.path.exists(os.path.join(folder, "frames", "%s_%d.png" % (anim, i))):
        out.append(Image.open(os.path.join(folder, "frames", "%s_%d.png" % (anim, i))).convert("RGBA"))
        i += 1
    return out


def union(images):
    boxes = [im.getbbox() for im in images if im.getbbox()]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def strip(folder, anims, zoom=4, cols=12, label=True):
    rows = []
    for anim in anims:
        ims = frames_of(folder, anim)
        if not ims:
            continue
        box = union(ims)
        rows.append((anim, [im.crop(box) for im in ims]))
    pad, head = 6, 14
    cell_w = max(im.width for _, ims in rows for im in ims) * zoom + pad
    cell_h = max(im.height for _, ims in rows for im in ims) * zoom
    lines = [(anim, [ims[i:i + cols] for i in range(0, len(ims), cols)]) for anim, ims in rows]
    height = sum(head + len(chunks) * (cell_h + pad) for _, chunks in lines) + pad
    width = pad + min(cols, max(len(ims) for _, ims in rows)) * cell_w
    sheet = Image.new("RGBA", (width, height), BACKDROP)
    d = ImageDraw.Draw(sheet)
    y = pad
    for anim, chunks in lines:
        if label:
            d.text((pad, y - 2), anim, fill=INK)
        y += head
        for chunk in chunks:
            for c, im in enumerate(chunk):
                big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
                x = pad + c * cell_w
                sheet.alpha_composite(big, (x, y + cell_h - big.height))
                d.line([(x, y + cell_h), (x + cell_w - pad, y + cell_h)], fill=GROUND)
            y += cell_h + pad
    return sheet


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("folder")
    ap.add_argument("anims")
    ap.add_argument("--zoom", type=int, default=4)
    ap.add_argument("--cols", type=int, default=12)
    ap.add_argument("--out")
    a = ap.parse_args(argv)
    out = a.out or os.path.join(a.folder, "strip.png")
    strip(a.folder, a.anims.split(","), a.zoom, a.cols).save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
