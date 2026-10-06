"""How much a looping animation shimmers: pixels that change and change straight back (A, B, A) between three frames, and how much of the
sprite changes from one frame to the next. Pure Pillow. A smooth cycle moves its edges, not its insides."""
from PIL import Image


def _frames(paths):
    out = []
    for p in paths:
        with Image.open(p) as im:
            out.append(im.convert("RGBA").copy())
    return out


def measure(paths):
    """{"changed": mean share of drawn pixels that differ between consecutive frames, "flicker": share of pixel-triples that go A, B, A}."""
    ims = _frames(paths)
    n = len(ims)
    px = [im.load() for im in ims]
    w, h = ims[0].size
    changed = flick = drawn = triples = 0
    for i in range(n):
        a, b, c = px[i], px[(i + 1) % n], px[(i + 2) % n]
        for y in range(h):
            for x in range(w):
                pa, pb, pc = a[x, y], b[x, y], c[x, y]
                if pa[3] == 0 and pb[3] == 0:
                    continue
                drawn += 1
                changed += pa != pb
                if pa[3] or pc[3]:
                    triples += 1
                    flick += (pa == pc and pa != pb)
    return {"changed": changed / float(max(1, drawn)), "flicker": flick / float(max(1, triples))}
