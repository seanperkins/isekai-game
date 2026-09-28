"""Print bounding boxes of sprites on a magenta-keyed sheet (connected non-magenta regions,
merged when closer than --gap px). Used once to author tools/art/manifest.json."""
import argparse
from PIL import Image


def is_key(p, tol):
    r, g, b = p[:3]
    return r >= 255 - tol and g <= tol and b >= 255 - tol


def boxes(path, tol, gap, min_area):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    found = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if seen[i] or is_key(px[x, y], tol):
                continue
            stack = [(x, y)]
            seen[i] = 1
            x0 = x1 = x
            y0 = y1 = y
            n = 0
            while stack:
                cx, cy = stack.pop()
                n += 1
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and not is_key(px[nx, ny], tol):
                            seen[j] = 1
                            stack.append((nx, ny))
            if n >= min_area:
                found.append([x0, y0, x1, y1])
    merged = True
    while merged:
        merged = False
        for a in range(len(found)):
            for b in range(a + 1, len(found)):
                A, B = found[a], found[b]
                if A[0] - gap <= B[2] and B[0] - gap <= A[2] and A[1] - gap <= B[3] and B[1] - gap <= A[3]:
                    found[a] = [min(A[0], B[0]), min(A[1], B[1]), max(A[2], B[2]), max(A[3], B[3])]
                    del found[b]
                    merged = True
                    break
            if merged:
                break
    return sorted(found, key=lambda r: (r[1] // 120, r[0]))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--tol", type=int, default=60)
    ap.add_argument("--gap", type=int, default=12)
    ap.add_argument("--min-area", type=int, default=80)
    a = ap.parse_args()
    for r in boxes(a.sheet, a.tol, a.gap, a.min_area):
        print(r, "size", r[2] - r[0] + 1, r[3] - r[1] + 1)
