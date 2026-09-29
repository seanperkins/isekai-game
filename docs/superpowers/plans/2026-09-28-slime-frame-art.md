# Slime Frame Art (Plan 2 of the forms plans) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw the slime as 21 individually generated frames at 2× size, assemble them into one
sheet with hit shapes traced from each frame, and play them through an animator, so the slime
runs, jumps, clings, spreads and eats (by covering) with real drawn animation.

**Architecture:**
- **Art:** each frame is one Codex image. `assemble_frames.py` fits every frame to its width,
  traces a hurt shape (and an attack shape where the frame has one) from the drawn pixels, and
  packs a sheet plus a JSON description.
- **Game:** a `SpriteSheet` loads the sheet, a `SlimeAnimator` plays clips from
  `data/slime_clips.json`, `SlimeShapes` keeps inert hurt and attack shapes in step with the
  frame, and `EatCover` drapes over the prey.
- **Player:** the Player shows the sheet's frames, and falls back to the old scaled sprite when
  the sheet is missing.

**Tech Stack:** Godot 4.7 (GDScript), GUT 9.7.1, `tools/run_tests.sh`, Python 3 + Pillow (via
`uv`), Codex image generation.

**Spec:** `docs/superpowers/specs/2026-09-28-slime-forms-and-animation-design.md` (sections 0.1,
1.1–1.5; the frame path chosen in 0.4).

## Global Constraints

- Godot 4.7 and GDScript, explicit types wherever inference fails. Tests run with
  `tools/run_tests.sh [file-substring]`. After adding any new `class_name` or asset, run
  `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1` first.
- The internal resolution is 640×360 and the world is 1:1 pixels. **No smoothing, no scaling of
  the new frames in code**: frames are drawn at their final size.
- **The slime is 2× today's size** (`BodyConfig.SCALE`): idle body about 44×36, collision box
  28×24, spread box 28×10, bottom of the body `BodyConfig.BOTTOM` (12 px) below the origin.
- **Every frame is generated individually** and assembled by a tool. A sheet is never generated
  in one shot.
- **Frames face right.** Facing left mirrors the sprite, the shapes and the cover.
- **Hit shapes are inert in this plan** (collision layers 0). Switching the game's damage checks
  to shapes needs enemy shapes too, so it belongs to the enemy plan. Enemy contact stays "touching
  boxes" (`Enemy.is_touching`).
- Don't touch `tools/art/manifest.json`, `tests/test_art_assets.gd`, `scripts/world/*`,
  `data/rooms/*`, `tools/build_world.gd`, `assets/tiles/*`, `assets/backgrounds/*`,
  `art_source/terrain/*` or `tools/art/terrain_*` (the terrain session owns them). The slime sheet
  lives in its own files.
- Work in `.worktrees/slime-frames` on branch `feat/slime-frames`. Git commands need the sandbox
  disabled. `uv`, `codex` and windowed Godot runs are run unsandboxed.

## Review Focus

1. **Frames that drift.** Individually generated frames can change scale, colour or proportions.
   Tests bound every frame's size against the idle frame (Task 3 test
   `test_frames_stay_in_a_consistent_scale`), and the contact sheet is reviewed by eye (Task 8).
2. **Baseline.** Every frame must sit on the floor line, or the slime hops when frames change (Task 3
   test `test_every_frame_touches_the_floor_line`).
3. **Shapes that don't match the art.** A traced hurt shape must contain every drawn pixel and not
   balloon (Task 3 test `test_the_hurt_shape_hugs_the_drawn_pixels`).
4. **Mirroring.** Facing left mirrors the sprite, the shapes and the cover (Task 5 and Task 7 tests).
5. **The prey must reappear on every exit from eating.** Cancel, complete, the prey freed, the
   player dying (Task 7 tests).
6. **A missing sheet must not crash.** The Player falls back to the old scaled sprite (Task 6 test
   `test_the_player_falls_back_without_the_sheet`).

## File Structure

| File | Responsibility |
|---|---|
| `tools/art/slime_frames.json` (new) | The frame list: name, target width, references, prompt, attack region |
| `tools/art/generate_frames.py` (new) | Runs Codex once per frame |
| `tools/art/assemble_frames.py` (new) | Fit, trace hit shapes, pack the sheet |
| `tools/art/test_generate_frames.py`, `tools/art/test_assemble_frames.py` (new) | Python unit tests |
| `tools/art/slime_contact_sheet.py`, `tools/art/slime_gifs.py` (new) | Review packet |
| `art_source/frames/slime/*.png` (generated) | Raw Codex output |
| `assets/sheets/slime.png`, `assets/sheets/slime.json` (generated) | The sheet and its description |
| `scripts/ui/sprite_sheet.gd` (new) | Loads a sheet; frame textures, sizes, shapes |
| `data/slime_clips.json` (new) | State → frames, fps, loop, exit frames |
| `scripts/player/slime_animator.gd` (new) | Plays clips |
| `scripts/player/slime_shapes.gd` (new) | Inert hurt and attack shapes in step with the frame |
| `scripts/player/eat_cover.gd` (new) | The eating cover |
| `scripts/player/player.gd` (modify) | Shows the sheet's frames; shapes; cover |
| `tests/*` | New tests; `tests/test_art_visuals.gd` (modify) |

---

### Task 0: Worktree and baseline

- [ ] **Step 1: Create the worktree from main and bring the plan over**

```bash
cd /Users/sean/sites/isekai-game && git worktree add .worktrees/slime-frames -b feat/slime-frames main && cd .worktrees/slime-frames && git checkout docs/forms-spec -- docs/superpowers/plans/2026-09-28-slime-frame-art.md && mkdir -p .tmp/gdhome .tmp/test-logs .tmp/probe && gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1; tools/run_tests.sh | tail -1
```
Expected: `PASS: 409 tests`.

- [ ] **Step 2: A helper that copies this plan's code blocks into files**

`.tmp/extract.py` (scratch, not committed): it writes every fenced `gdscript` or `python` block whose first line is `# <path>` to that path.
```python
import re, sys, os
plan = open('docs/superpowers/plans/2026-09-28-slime-frame-art.md').read()
for m in re.finditer(r'```(?:gdscript|python)\n# (\S+)\n(.*?)```', plan, re.S):
    if m.group(1) in sys.argv[1:]:
        os.makedirs(os.path.dirname(m.group(1)) or '.', exist_ok=True)
        open(m.group(1), 'w').write(m.group(2))
        print('wrote', m.group(1))
```

---

### Task 1: The frame list, the generator, and the assembler (Python, tested)

**Files:**
- Create: `tools/art/slime_frames.json`, `tools/art/generate_frames.py`, `tools/art/assemble_frames.py`
- Test: `tools/art/test_generate_frames.py`, `tools/art/test_assemble_frames.py`

**Interfaces:**
- Produces:
  - `slime_frames.json`: `{"style": str, "frames": [{"name", "width", "refs": [names], "prompt", "attack_from": float (optional)}]}`.
  - `generate_frames.build_prompt(style, frame) -> str`, `refs_for(frame, out_dir, root) -> list[str]`, `command(out_dir, refs) -> list[str]`, `valid_name(name) -> bool`.
  - `assemble_frames.fit_frame(im, width)`, `boundary_corners(im)`, `convex_hull(points)`, `to_local(points, w, h)`, `trace(im, attack_from)`, `pack(frames)`.
  - The sheet: `assets/sheets/slime.png` and `assets/sheets/slime.json`, `{"set", "image", "frames": {name: {"rect": [x,y,w,h], "hurt": [[x,y],...], "attack": [[x,y],...]}}}`. Shape coordinates are frame-local, in pixels, with the origin at the **bottom centre** of the frame (x right, y down, so the floor line is y = 0 and the frame's top is y = -height).

- [ ] **Step 1: Write the frame list**

Write `tools/art/slime_frames.json` (plain JSON):

```json
{
  "style": "Modern pixel art with soft lighting (Style D): a small translucent glowing blue jelly slime, soft inner glow, gentle highlights, a clean dark-blue outline, chunky readable pixels, two small glossy dark eyes. Match the character, colours and proportions of the reference images exactly. Side view, the slime facing right.",
  "frames": [
    {"name": "idle_1", "width": 44, "refs": [], "prompt": "The slime resting: a rounded dome slightly wider than tall, two eyes near the upper front (right), relaxed."},
    {"name": "idle_2", "width": 44, "refs": ["idle_1"], "prompt": "The same slime breathing out: very slightly flatter and wider (about 5 percent squash), same eyes and colours."},
    {"name": "run_1", "width": 46, "refs": ["idle_1"], "prompt": "The same slime mid-run: leaning forward to the right and stretched slightly horizontally, the back trailing, eyes looking right."},
    {"name": "run_2", "width": 42, "refs": ["idle_1", "run_1"], "prompt": "The same slime in the run's recovery: compressed and a little taller, hunched, bouncing up."},
    {"name": "run_3", "width": 46, "refs": ["idle_1", "run_2"], "prompt": "The same slime stretched forward again like the first run frame, with the trailing back edge pulled in a little."},
    {"name": "run_4", "width": 42, "refs": ["idle_1", "run_3"], "prompt": "The same slime compressed and popping up slightly higher than the resting pose."},
    {"name": "rise", "width": 38, "refs": ["idle_1"], "prompt": "The same slime jumping upward: a tall stretched teardrop, narrower than resting, eyes wide."},
    {"name": "fall", "width": 42, "refs": ["idle_1"], "prompt": "The same slime falling: taller than resting with a wider bottom, its edges trailing upward, eyes wide."},
    {"name": "land", "width": 52, "refs": ["idle_1"], "prompt": "The same slime landing: squashed very flat and wide, eyes squinting."},
    {"name": "hurt", "width": 50, "refs": ["idle_1"], "prompt": "The same slime hit and recoiling: squashed sideways with a slight tilt, eyes squeezed shut in pain."},
    {"name": "rope", "width": 34, "refs": ["idle_1"], "prompt": "The same slime hanging from a thread: stretched tall and thin with a pointed top like a drop being pulled upward."},
    {"name": "wall_1", "width": 44, "refs": ["idle_1"], "prompt": "The same slime clinging to a wall on its RIGHT side: its front edge pressed flat against the wall, two small jelly arms gripping upward on the right, eyes looking up."},
    {"name": "wall_2", "width": 44, "refs": ["idle_1", "wall_1"], "prompt": "The same clinging pose with the grip shifted: the arms a little lower, the body slightly stretched downward."},
    {"name": "tackle", "width": 54, "attack_from": 0.62, "refs": ["idle_1"], "prompt": "The same slime in a charging tackle: stretched long horizontally with a leading edge pointing forward to the right, streamlined, eyes narrowed and determined."},
    {"name": "spread_1", "width": 56, "refs": ["idle_1", "land"], "prompt": "The same slime half flattened, squashing down into a puddle: wider and lower than resting, eyes near the top."},
    {"name": "spread_2", "width": 68, "refs": ["idle_1", "spread_1"], "prompt": "The same slime fully spread into a flat puddle: very wide, low and thin like a pancake, the eyes as two tiny ovals on the top edge."},
    {"name": "cover_1", "width": 44, "refs": ["idle_1"], "prompt": "The same slime lunging: its body arching up and forward to the right like a leap over something, eyes looking down and to the right."},
    {"name": "cover_2", "width": 60, "refs": ["idle_1", "cover_1"], "prompt": "The same slime draping down like a blanket over something below it: a wide low mound with its edges spreading out to the sides, pale glowing blue."},
    {"name": "cover_3", "width": 66, "refs": ["idle_1", "cover_2"], "prompt": "The same slime engulfing something: a wide flat mound with its edges hugging the ground on both sides, glowing, a hollow dark shape suggested inside."},
    {"name": "cover_4", "width": 68, "refs": ["cover_3"], "prompt": "The same engulfing pose pulsing slightly bigger, its edges spread a little more."},
    {"name": "cover_5", "width": 46, "refs": ["idle_1"], "prompt": "The same slime popping back into a round dome after eating, a few tiny sparkle drops around it, happy eyes."}
  ]
}
```

- [ ] **Step 2: Write the failing Python tests**

```python
# tools/art/test_generate_frames.py
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_frames as g  # noqa: E402

FRAME = {"name": "run_2", "width": 42, "refs": ["idle_1", "run_1"], "prompt": "The same slime, running."}


class GenerateFramesTest(unittest.TestCase):
    def test_prompt_carries_the_style_the_frame_the_key_and_the_filename(self):
        p = g.build_prompt("STYLE TEXT", FRAME)
        self.assertTrue(p.startswith("$imagegen"))
        for part in ("STYLE TEXT", "The same slime, running.", "magenta", "as run_2.png"):
            self.assertIn(part, p)

    def test_references_start_with_the_canonical_slime_then_the_frames_own(self):
        refs = g.refs_for(FRAME, "/out", "/repo")
        self.assertEqual(refs, ["/repo/assets/sprites/slime_idle.png", "/out/idle_1.png", "/out/run_1.png"])

    def test_the_command_passes_one_reference_flag_each_and_reads_stdin(self):
        cmd = g.command("/out", ["/a.png", "/b.png"])
        self.assertEqual(cmd[:2], ["codex", "exec"])
        self.assertEqual(cmd.count("-i"), 2)
        self.assertEqual(cmd[-1], "-")
        self.assertEqual(cmd[cmd.index("-C") + 1], "/out")

    def test_names_are_validated(self):
        self.assertTrue(g.valid_name("run_2"))
        for bad in ("../x", "Run", "a b", "", "a.png"):
            self.assertFalse(g.valid_name(bad), bad)

    def test_every_frame_in_the_list_is_well_formed(self):
        import json
        data = json.load(open(os.path.join(os.path.dirname(__file__), "slime_frames.json")))
        names = [f["name"] for f in data["frames"]]
        self.assertEqual(len(names), 21)
        self.assertEqual(len(set(names)), 21)
        for f in data["frames"]:
            self.assertTrue(g.valid_name(f["name"]), f["name"])
            self.assertGreater(f["width"], 20)
            for r in f["refs"]:
                self.assertIn(r, names)
                self.assertLess(names.index(r), names.index(f["name"]), "a reference must come earlier")
        self.assertEqual([f["name"] for f in data["frames"] if "attack_from" in f], ["tackle"])


if __name__ == "__main__":
    unittest.main()
```

```python
# tools/art/test_assemble_frames.py
import os
import sys
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assemble_frames as a  # noqa: E402

MAGENTA = (255, 0, 255, 255)
BLUE = (40, 120, 255, 255)


def frame(w, h, box, color=BLUE):
    """A magenta canvas with a solid rectangle `box` = (x0, y0, x1, y1)."""
    im = Image.new("RGBA", (w, h), MAGENTA)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            im.putpixel((x, y), color)
    return im


class AssembleFramesTest(unittest.TestCase):
    def test_fit_scales_to_the_width_and_keeps_the_aspect(self):
        out = a.fit_frame(frame(100, 50, (20, 10, 80, 40)), 30)  # the subject is 60x30
        self.assertEqual(out.size, (30, 15))

    def test_fit_keys_the_magenta_out_and_keeps_alpha_crisp(self):
        out = a.fit_frame(frame(100, 50, (20, 10, 80, 40)), 30)
        self.assertEqual(out.getpixel((0, 0))[3] in (0, 255), True)
        alphas = {p[3] for p in out.getdata()}
        self.assertTrue(alphas <= {0, 255})
        self.assertEqual(out.getpixel((15, 7))[3], 255)

    def test_fit_rejects_an_empty_frame(self):
        with self.assertRaises(ValueError):
            a.fit_frame(Image.new("RGBA", (10, 10), MAGENTA), 5)

    def test_the_hull_of_a_solid_block_is_its_four_corners(self):
        im = Image.new("RGBA", (10, 6), BLUE)
        hull = a.convex_hull(a.boundary_corners(im))
        self.assertEqual(set(hull), {(0, 0), (10, 0), (10, 6), (0, 6)})

    def test_shapes_are_local_to_the_bottom_centre(self):
        im = Image.new("RGBA", (10, 6), BLUE)
        hurt, attack = a.trace(im, None)
        self.assertEqual(set(map(tuple, hurt)), {(-5.0, -6.0), (5.0, -6.0), (5.0, 0.0), (-5.0, 0.0)})
        self.assertEqual(attack, [])

    def test_the_attack_shape_is_the_front_slice(self):
        im = Image.new("RGBA", (10, 6), BLUE)
        _, attack = a.trace(im, 0.5)
        xs = [p[0] for p in attack]
        self.assertEqual((min(xs), max(xs)), (0.0, 5.0))

    def test_the_hull_contains_every_opaque_pixel_of_a_blob(self):
        im = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
        for y in range(20):
            for x in range(20):
                if (x - 10) ** 2 + (y - 10) ** 2 <= 64:
                    im.putpixel((x, y), BLUE)
        hull = a.convex_hull(a.boundary_corners(im))
        for y in range(20):
            for x in range(20):
                if im.getpixel((x, y))[3] == 255:
                    c = (x + 0.5, y + 0.5)
                    for i in range(len(hull)):
                        p, q = hull[i], hull[(i + 1) % len(hull)]
                        cross = (q[0] - p[0]) * (c[1] - p[1]) - (q[1] - p[1]) * (c[0] - p[0])
                        self.assertGreaterEqual(cross, -1e-9, "pixel %s outside the hull" % (c,))

    def test_pack_places_every_frame_without_overlap_inside_the_sheet(self):
        frames = {"a": Image.new("RGBA", (200, 30)), "b": Image.new("RGBA", (200, 20)),
                  "c": Image.new("RGBA", (200, 40)), "d": Image.new("RGBA", (10, 10))}
        sheet, rects = a.pack(frames)
        self.assertLessEqual(sheet.width, a.SHEET_WIDTH)
        boxes = list(rects.values())
        for i, (x, y, w, h) in enumerate(boxes):
            self.assertTrue(x >= 0 and y >= 0 and x + w <= sheet.width and y + h <= sheet.height)
            for (x2, y2, w2, h2) in boxes[i + 1:]:
                self.assertTrue(x + w <= x2 or x2 + w2 <= x or y + h <= y2 or y2 + h2 <= y)
        self.assertEqual(set(rects), set(frames))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run them to verify they fail**

```
uv run --python 3.12 --with Pillow python -m unittest discover -s tools/art -p "test_*.py"
```
(the whole command, sandbox disabled). Expected: errors `No module named 'generate_frames'` and `'assemble_frames'`.

- [ ] **Step 4: Write the tools**

```python
# tools/art/generate_frames.py
"""Generate frames one at a time with Codex ($imagegen). Every frame is its own image, never a sheet.

Each frame is given the canonical slime as a style reference, plus the earlier frames it lists in
`refs`, so the character stays the same. Output goes to art_source/frames/<set>/<name>.png on a
magenta key. Run unsandboxed from the project root:
  uv run --python 3.12 python tools/art/generate_frames.py slime [frame ...]
"""
import json
import os
import re
import subprocess
import sys

NAME = re.compile(r"^[a-z0-9_]+$")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CANONICAL = "assets/sprites/slime_idle.png"


def valid_name(name):
    return bool(NAME.match(name))


def build_prompt(style, frame):
    return ("$imagegen Generate one image (square): %s Style: %s Fill the whole background with flat "
            "solid magenta #FF00FF, nothing else: no shadow, no text, no border. Save the PNG into the "
            "current working directory as %s.png. Reply with the absolute path of the saved file only."
            % (frame["prompt"], style, frame["name"]))


def refs_for(frame, out_dir, root=ROOT):
    refs = [os.path.join(root, CANONICAL)]
    for r in frame.get("refs", []):
        refs.append(os.path.join(out_dir, r + ".png"))
    return refs


def command(out_dir, refs):
    cmd = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", out_dir,
           "-o", os.path.join(out_dir, ".last.txt")]
    for r in refs:
        cmd += ["-i", r]
    return cmd + ["-"]


def main():
    if len(sys.argv) < 2 or not valid_name(sys.argv[1]):
        raise SystemExit("usage: generate_frames.py <set> [frame ...]")
    rig_set = sys.argv[1]
    data = json.load(open(os.path.join(ROOT, "tools/art/%s_frames.json" % rig_set)))
    wanted = sys.argv[2:] or [f["name"] for f in data["frames"]]
    out_dir = os.path.join(ROOT, "art_source/frames", rig_set)
    os.makedirs(out_dir, exist_ok=True)
    by_name = {f["name"]: f for f in data["frames"]}
    for name in wanted:
        if name not in by_name or not valid_name(name):
            raise SystemExit("unknown frame: %r" % name)
        frame = by_name[name]
        refs = refs_for(frame, out_dir)
        missing = [r for r in refs if not os.path.exists(r)]
        if missing:
            raise SystemExit("%s needs %s generated first" % (name, missing))
        print("generating", name, flush=True)
        subprocess.run(command(out_dir, refs), input=build_prompt(data["style"], frame).encode(),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if not os.path.exists(os.path.join(out_dir, name + ".png")):
            raise SystemExit("codex did not produce %s.png" % name)
        print("wrote", os.path.join(out_dir, name + ".png"), flush=True)


if __name__ == "__main__":
    main()
```

```python
# tools/art/assemble_frames.py
"""Assemble individually generated frames into a sprite sheet and trace hit shapes from them.

Each frame is a Codex image on a magenta key (art_source/frames/<set>/<name>.png). This keys the
magenta out, crops to the drawn pixels, scales to the frame's width in tools/art/<set>_frames.json
(keeping the aspect), thresholds the alpha so edges stay crisp, traces a hurt shape (the convex hull
of the drawn outline) and, where the frame has `attack_from`, an attack shape (the hull of the part
of the outline at or right of that fraction of the width), and packs everything into
assets/sheets/<set>.png + assets/sheets/<set>.json.

Shapes are frame-local pixels with the origin at the bottom centre (x right, y down: the floor
line is y = 0). Run from the project root (the whole command, no cd or pipes):
  uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py slime
"""
import json
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_sheets import crisp_alpha, keyed  # noqa: E402

SRC = "art_source/frames"
OUT = "assets/sheets"
NAME = re.compile(r"^[a-z0-9_]+$")
SHEET_WIDTH = 512
PAD = 1


def fit_frame(im, width):
    """Key out magenta, crop to the drawn pixels, scale to `width` keeping the aspect, crisp the alpha."""
    im = keyed(im.convert("RGBA"))
    box = im.split()[3].getbbox()
    if box is None:
        raise ValueError("frame is empty after keying")
    im = im.crop(box)
    height = max(1, round(im.height * width / im.width))
    return crisp_alpha(im.resize((width, height), Image.BOX))


def boundary_corners(im):
    """Corners of every opaque pixel that touches transparency or the frame edge."""
    w, h = im.size
    px = im.load()

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y][3] >= 128

    pts = set()
    for y in range(h):
        for x in range(w):
            if not opaque(x, y):
                continue
            if all(opaque(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                continue
            pts.update({(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)})
    return pts


def convex_hull(points):
    """Andrew's monotone chain; the hull without a repeated last point."""
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def cross(o, p, q):
        return (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0])

    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def to_local(points, w, h):
    return [[x - w / 2.0, y - float(h)] for x, y in points]


def trace(im, attack_from):
    """(hurt, attack) shapes, frame-local. `attack` is empty unless `attack_from` is given."""
    w, h = im.size
    pts = boundary_corners(im)
    hurt = to_local(convex_hull(pts), w, h)
    attack = []
    if attack_from is not None:
        front = {p for p in pts if p[0] >= attack_from * w}
        if len(front) >= 3:
            attack = to_local(convex_hull(front), w, h)
    return hurt, attack


def pack(frames):
    """Shelf-pack the frames in order. Returns (sheet, {name: (x, y, w, h)})."""
    x = y = row_h = 0
    rects = {}
    for name, im in frames.items():
        if x + im.width + PAD > SHEET_WIDTH and x > 0:
            x = 0
            y += row_h + PAD
            row_h = 0
        rects[name] = (x, y, im.width, im.height)
        x += im.width + PAD
        row_h = max(row_h, im.height)
    sheet = Image.new("RGBA", (SHEET_WIDTH, y + row_h), (0, 0, 0, 0))
    for name, im in frames.items():
        sheet.paste(im, rects[name][:2])
    return sheet, rects


def main():
    if len(sys.argv) != 2 or not NAME.match(sys.argv[1]):
        raise SystemExit("usage: assemble_frames.py <set>")
    rig_set = sys.argv[1]
    data = json.load(open("tools/art/%s_frames.json" % rig_set))
    fitted, shapes = {}, {}
    for f in data["frames"]:
        src = os.path.join(SRC, rig_set, f["name"] + ".png")
        if not os.path.exists(src):
            raise SystemExit("missing %s (generate it first)" % src)
        fitted[f["name"]] = fit_frame(Image.open(src), f["width"])
        shapes[f["name"]] = trace(fitted[f["name"]], f.get("attack_from"))
    sheet, rects = pack(fitted)
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, rig_set + ".png"))
    frames = {n: {"rect": list(rects[n]), "hurt": shapes[n][0], "attack": shapes[n][1]} for n in fitted}
    with open(os.path.join(OUT, rig_set + ".json"), "w") as out:
        json.dump({"set": rig_set, "image": rig_set + ".png", "frames": frames}, out)
    for n, im in fitted.items():
        print("frame", n, im.size)
    print("wrote", os.path.join(OUT, rig_set + ".png"), sheet.size)


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run the tests to verify they pass, then commit**

```
uv run --python 3.12 --with Pillow python -m unittest discover -s tools/art -p "test_*.py"
```
Expected: `Ran 13 tests ... OK`. (The frame-list test also needs `slime_frames.json` from step 1.)

```bash
git add tools/art/slime_frames.json tools/art/generate_frames.py tools/art/assemble_frames.py tools/art/test_generate_frames.py tools/art/test_assemble_frames.py
git commit -m "feat: frame list, one-frame-at-a-time generator, and the sheet assembler with traced hit shapes"
```

---

### Task 2: Generate the slime's frames, one at a time

No code. Each frame is generated individually and looked at before the next depends on it.

**Files:**
- Create (generated): `art_source/frames/slime/*.png`, `assets/sheets/slime.png`, `assets/sheets/slime.json`

- [ ] **Step 1: Generate `idle_1`, the canonical frame, and approve it**

```
uv run --python 3.12 python tools/art/generate_frames.py slime idle_1
```
(the whole command, sandbox disabled; takes a minute or two). **Read `art_source/frames/slime/idle_1.png`.** It must be one slime, in the reference's style, facing right, two eyes, a dome slightly wider than tall, on flat magenta. If not, regenerate this frame alone (edit its prompt in `slime_frames.json` if needed) until it is right. Every other frame references it.

- [ ] **Step 2: Generate the run and idle frames**

`uv run --python 3.12 python tools/art/generate_frames.py slime idle_2 run_1 run_2 run_3 run_4`

- [ ] **Step 3: Generate the air, land, hurt and rope frames**

`uv run --python 3.12 python tools/art/generate_frames.py slime rise fall land hurt rope`

- [ ] **Step 4: Generate the wall, tackle and spread frames**

`uv run --python 3.12 python tools/art/generate_frames.py slime wall_1 wall_2 tackle spread_1 spread_2`

- [ ] **Step 5: Generate the eating cover frames**

`uv run --python 3.12 python tools/art/generate_frames.py slime cover_1 cover_2 cover_3 cover_4 cover_5`

- [ ] **Step 6: Look at all of them and regenerate the weak ones alone**

Make a quick contact sheet of the raw frames, and **Read it**:
```
uv run --python 3.12 --with Pillow python -c "
from PIL import Image; import glob, os
fs = sorted(glob.glob('art_source/frames/slime/*.png'))
tiles = [Image.open(f).convert('RGB').resize((200, 200)) for f in fs]
cols = 7; rows = (len(tiles) + cols - 1) // cols
sheet = Image.new('RGB', (cols * 200, rows * 200), 'white')
for i, t in enumerate(tiles): sheet.paste(t, ((i % cols) * 200, (i // cols) * 200))
os.makedirs('.tmp/slime-frames', exist_ok=True); sheet.save('.tmp/slime-frames/raw.png'); print([os.path.basename(f) for f in fs])"
```
Check each against its prompt and against `idle_1`: same character and colours; the pose reads; nothing but the slime on the key; the spread frames are flat and wide; the cover frames look like draping; the wall frames grip a wall on the right. Regenerate any bad frame alone with `generate_frames.py slime <name>` (adjust its prompt first if the fault is the pose).

- [ ] **Step 7: Assemble the sheet**

```
uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py slime
```
Expected: 21 `frame <name> (w, h)` lines and `wrote assets/sheets/slime.png (512, <h>)`. Check that idle_1 is 44 wide, and that spread_2 is about 68×12–18.

- [ ] **Step 8: Commit**

```bash
gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add art_source/frames assets/sheets
git commit -m "feat: the slime's 21 frames, individually generated, assembled into a sheet"
```

---

### Task 3: SpriteSheet, and tests that pin the art

**Files:**
- Create: `scripts/ui/sprite_sheet.gd`
- Test: `tests/test_sprite_sheet.gd`

**Interfaces:**
- Consumes: `assets/sheets/slime.{png,json}` and `tools/art/slime_frames.json` (Task 1–2).
- Produces `SpriteSheet` (`RefCounted`):
  - `static available(set_name: String) -> bool`, `static load_set(set_name: String) -> SpriteSheet` (null when unavailable)
  - `has_frame(name) -> bool`, `frame_names() -> Array`
  - `frame_texture(name) -> Texture2D` (an `AtlasTexture`, cached, so the same instance every time)
  - `frame_size(name) -> Vector2`
  - `hurt(name) -> PackedVector2Array`, `attack(name) -> PackedVector2Array` (frame-local, origin bottom centre)
  - `texture: Texture2D` (the whole sheet)

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/test_sprite_sheet.gd
extends GutTest
## The generated sheet: every listed frame is there, at its width, on the floor line, in a consistent
## scale, with hit shapes that hug the drawn pixels.

const FRAMES := "res://tools/art/slime_frames.json"

var sheet: SpriteSheet
var listed: Array = []

func before_all() -> void:
	sheet = SpriteSheet.load_set("slime")
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(FRAMES))
	listed = json.data["frames"]

func test_the_sheet_loads_and_lists_every_frame() -> void:
	assert_true(SpriteSheet.available("slime"))
	assert_false(SpriteSheet.available("no_such_set"))
	assert_null(SpriteSheet.load_set("no_such_set"))
	assert_eq(sheet.frame_names().size(), listed.size())
	for f in listed:
		assert_true(sheet.has_frame(f["name"]), f["name"])

func test_frames_are_their_listed_width_and_inside_the_sheet() -> void:
	var whole := sheet.texture.get_size()
	for f in listed:
		var size := sheet.frame_size(f["name"])
		assert_eq(int(size.x), int(f["width"]), f["name"])
		var t := sheet.frame_texture(f["name"]) as AtlasTexture
		assert_true(Rect2(Vector2.ZERO, whole).encloses(t.region), f["name"])
		assert_eq(t.region.size, size)

func test_the_frame_texture_is_cached() -> void:
	assert_same(sheet.frame_texture("idle_1"), sheet.frame_texture("idle_1"))

func test_every_frame_touches_the_floor_line() -> void:
	for f in listed:
		var hurt := sheet.hurt(f["name"])
		var lowest := -INF
		for p in hurt:
			lowest = maxf(lowest, p.y)
		assert_almost_eq(lowest, 0.0, 0.01, "%s: the shape's lowest point is the frame's bottom" % f["name"])

func test_hurt_shapes_are_inside_the_frame_and_have_substance() -> void:
	for f in listed:
		var size := sheet.frame_size(f["name"])
		var hurt := sheet.hurt(f["name"])
		assert_gte(hurt.size(), 3, f["name"])
		for p in hurt:
			assert_between(p.x, -size.x / 2.0 - 0.01, size.x / 2.0 + 0.01, f["name"])
			assert_between(p.y, -size.y - 0.01, 0.01, f["name"])

func test_the_hurt_shape_hugs_the_drawn_pixels() -> void:
	var img := sheet.texture.get_image()
	for name in ["idle_1", "spread_2", "tackle", "cover_3"]:
		var t := sheet.frame_texture(name) as AtlasTexture
		var hurt := sheet.hurt(name)
		var inflated: PackedVector2Array = Geometry2D.offset_polygon(hurt, 0.6)[0]
		var opaque := 0
		var inside := 0
		for y in int(t.region.size.y):
			for x in int(t.region.size.x):
				if img.get_pixel(int(t.region.position.x) + x, int(t.region.position.y) + y).a < 0.5:
					continue
				opaque += 1
				var local := Vector2(x + 0.5 - t.region.size.x / 2.0, y + 0.5 - t.region.size.y)
				if Geometry2D.is_point_in_polygon(local, inflated):
					inside += 1
		assert_eq(inside, opaque, "%s: every drawn pixel is inside its hurt shape" % name)
		assert_lt(_area(hurt), opaque * 1.7, "%s: the shape does not balloon past the art" % name)

func test_only_the_tackle_has_an_attack_shape_and_it_is_in_front() -> void:
	for f in listed:
		var attack := sheet.attack(f["name"])
		if f.has("attack_from"):
			assert_gte(attack.size(), 3, f["name"])
			for p in attack:
				assert_gte(p.x, -sheet.frame_size(f["name"]).x / 2.0 + f["attack_from"] * sheet.frame_size(f["name"]).x - 0.01, f["name"])
		else:
			assert_eq(attack.size(), 0, f["name"])

func test_the_poses_have_the_proportions_their_names_promise() -> void:
	var idle := sheet.frame_size("idle_1")
	assert_eq(int(idle.x), 44)
	assert_gt(sheet.frame_size("rise").y, idle.y, "rising is taller than resting")
	assert_lt(sheet.frame_size("land").y, idle.y, "landing is flatter")
	assert_lt(sheet.frame_size("spread_2").y, idle.y * 0.6, "the puddle is flat")
	assert_gt(sheet.frame_size("spread_2").x, idle.x, "and wide")
	assert_gt(sheet.frame_size("tackle").x, idle.x, "the tackle is stretched")
	assert_gt(sheet.frame_size("rope").y, idle.y, "hanging on a thread is stretched tall")

func test_frames_stay_in_a_consistent_scale() -> void:
	var idle := sheet.frame_size("idle_1")
	for f in listed:
		var h := sheet.frame_size(f["name"]).y
		assert_between(h, idle.y * 0.25, idle.y * 1.6, "%s (%d px) drifted from the idle scale (%d px)" % [f["name"], h, idle.y])

func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_sprite_sheet`
Expected: FAIL with `Identifier "SpriteSheet" not declared`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/ui/sprite_sheet.gd
class_name SpriteSheet
extends RefCounted
## A sheet of individually drawn frames assembled by tools/art/assemble_frames.py, with the hit
## shapes traced from each frame. Shapes are frame-local pixels, origin at the bottom centre.

const DIR := "res://assets/sheets/"

var texture: Texture2D
var _frames := {}   # name -> {"rect": Rect2, "hurt": PackedVector2Array, "attack": PackedVector2Array}
var _atlas := {}    # name -> AtlasTexture

static func available(set_name: String) -> bool:
	return ResourceLoader.exists(DIR + set_name + ".png") and FileAccess.file_exists(DIR + set_name + ".json")

static func load_set(set_name: String) -> SpriteSheet:
	if not available(set_name):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(DIR + set_name + ".json")) != OK:
		push_error("SpriteSheet: cannot read %s.json" % set_name)
		return null
	var sheet := SpriteSheet.new()
	sheet.texture = load(DIR + str(json.data["image"]))
	var frames: Dictionary = json.data["frames"]
	for name in frames:
		var f: Dictionary = frames[name]
		var r: Array = f["rect"]
		sheet._frames[name] = {
			"rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
			"hurt": _points(f["hurt"]),
			"attack": _points(f["attack"])}
	return sheet

static func _points(raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in raw:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out

func has_frame(name: String) -> bool:
	return _frames.has(name)

func frame_names() -> Array:
	return _frames.keys()

func frame_texture(name: String) -> Texture2D:
	if not _atlas.has(name):
		var t := AtlasTexture.new()
		t.atlas = texture
		t.region = _frames[name]["rect"]
		_atlas[name] = t
	return _atlas[name]

func frame_size(name: String) -> Vector2:
	return (_frames[name]["rect"] as Rect2).size

func hurt(name: String) -> PackedVector2Array:
	return _frames[name]["hurt"]

func attack(name: String) -> PackedVector2Array:
	return _frames[name]["attack"]
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_sprite_sheet | tail -1`. Expected: `PASS: 10 tests`.
If a test about the *art* fails (a proportion, the scale bound, the floor line), the fix is
regenerating that frame alone (Task 2, step 6) and re-assembling, not loosening the test. A test
about the *code* that fails is a code bug.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/sprite_sheet.gd scripts/ui/*.uid tests/test_sprite_sheet.gd tests/*.uid
git commit -m "feat: SpriteSheet loads the slime's frames and traced shapes; tests pin the art"
```

---

### Task 4: SlimeAnimator and the clip table

**Files:**
- Create: `scripts/player/slime_animator.gd`, `data/slime_clips.json`
- Test: `tests/test_slime_animator.gd`

**Interfaces:**
- Consumes: `SlimeState.ALL` (already on main), the sheet's frame names.
- Produces `SlimeAnimator` (`RefCounted`): `_init(clips: Dictionary)`, `static load_clips(path: String = CLIPS) -> Dictionary`, `play(state: String)`, `advance(delta: float)`, `frame() -> String`, `state() -> String`; `const CLIPS`, `const EXIT_FPS := 20.0`. A clip is `{"frames": [names], "fps": float, "loop": bool, "exit": [names] (optional)}`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/test_slime_animator.gd
extends GutTest
## State -> clip -> frame name. Pure logic; the sheet is only used to check the names exist.

func _clips() -> Dictionary:
	return {
		"idle": {"frames": ["a", "b"], "fps": 2.0, "loop": true},
		"once": {"frames": ["x", "y", "z"], "fps": 10.0, "loop": false},
		"spread": {"frames": ["s1", "s2"], "fps": 20.0, "loop": false, "exit": ["s2", "s1"]}}

func test_a_loop_cycles_and_wraps() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("idle")
	assert_eq(a.frame(), "a")
	a.advance(0.5)
	assert_eq(a.frame(), "b")
	a.advance(0.5)
	assert_eq(a.frame(), "a")

func test_a_one_shot_holds_its_last_frame() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("once")
	a.advance(5.0)
	assert_eq(a.frame(), "z")

func test_playing_the_same_state_again_does_not_restart_it() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("once")
	a.advance(0.15)
	assert_eq(a.frame(), "y")
	a.play("once")
	assert_eq(a.frame(), "y")

func test_a_new_state_starts_from_its_first_frame() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("once")
	a.advance(0.3)
	a.play("idle")
	assert_eq(a.state(), "idle")
	assert_eq(a.frame(), "a")

func test_leaving_spread_plays_its_exit_frames_first() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("spread")
	a.advance(1.0)
	assert_eq(a.frame(), "s2")
	a.play("idle")
	assert_eq(a.state(), "idle")
	assert_eq(a.frame(), "s2")          # the exit clip runs first
	a.advance(1.0 / SlimeAnimator.EXIT_FPS)
	assert_eq(a.frame(), "s1")
	a.advance(1.0 / SlimeAnimator.EXIT_FPS)
	assert_eq(a.frame(), "a")           # then the new state

func test_an_unknown_state_is_ignored() -> void:
	var a := SlimeAnimator.new(_clips())
	a.play("idle")
	a.play("nonsense")
	assert_eq(a.state(), "idle")

func test_every_state_has_a_clip_of_real_frames() -> void:
	var clips := SlimeAnimator.load_clips()
	var sheet := SpriteSheet.load_set("slime")
	for state in SlimeState.ALL:
		assert_true(clips.has(state), state)
		var clip: Dictionary = clips[state]
		assert_gt(float(clip["fps"]), 0.0, state)
		assert_false(clip["frames"].is_empty(), state)
		for name in clip["frames"] + clip.get("exit", []):
			assert_true(sheet.has_frame(name), "%s uses a frame that is not on the sheet: %s" % [state, name])

func test_the_run_cycle_is_four_frames_and_idle_two() -> void:
	var clips := SlimeAnimator.load_clips()
	assert_eq(clips["run"]["frames"], ["run_1", "run_2", "run_3", "run_4"])
	assert_eq(clips["idle"]["frames"], ["idle_1", "idle_2"])
	assert_eq(clips["spread"]["exit"], ["spread_2", "spread_1"])
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_slime_animator`
Expected: FAIL with `Identifier "SlimeAnimator" not declared`.

- [ ] **Step 3: Write the clip table and the animator**

`data/slime_clips.json`:
```json
{
  "idle": {"frames": ["idle_1", "idle_2"], "fps": 1.5, "loop": true},
  "run": {"frames": ["run_1", "run_2", "run_3", "run_4"], "fps": 10.0, "loop": true},
  "rise": {"frames": ["rise"], "fps": 1.0, "loop": false},
  "fall": {"frames": ["fall"], "fps": 1.0, "loop": false},
  "land": {"frames": ["land"], "fps": 1.0, "loop": false},
  "wall": {"frames": ["wall_1", "wall_2"], "fps": 4.0, "loop": true},
  "tackle": {"frames": ["tackle"], "fps": 1.0, "loop": false},
  "spread": {"frames": ["spread_1", "spread_2"], "fps": 20.0, "loop": false, "exit": ["spread_2", "spread_1"]},
  "hurt": {"frames": ["hurt"], "fps": 1.0, "loop": false},
  "rope": {"frames": ["rope"], "fps": 1.0, "loop": false},
  "cover": {"frames": ["cover_3", "cover_4"], "fps": 8.0, "loop": true}
}
```

```gdscript
# scripts/player/slime_animator.gd
class_name SlimeAnimator
extends RefCounted
## Plays the slime's clips (data/slime_clips.json): state -> frame name. A one-shot holds its last
## frame; a loop wraps. A clip with an "exit" list plays those frames (at EXIT_FPS) when it is left,
## which is how Spread un-squashes instead of snapping.

const CLIPS := "res://data/slime_clips.json"
const EXIT_FPS := 20.0

var clips := {}
var _state := ""
var _time := 0.0
var _exit: Array = []
var _exit_time := 0.0

func _init(p_clips: Dictionary) -> void:
	clips = p_clips

static func load_clips(path: String = CLIPS) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("SlimeAnimator: cannot read %s" % path)
		return {}
	return json.data

func state() -> String:
	return _state

func play(state_name: String) -> void:
	if state_name == _state or not clips.has(state_name):
		return
	var old: Dictionary = clips.get(_state, {})
	if old.has("exit"):
		_exit = old["exit"]
		_exit_time = 0.0
	_state = state_name
	_time = 0.0

func advance(delta: float) -> void:
	if not _exit.is_empty():
		_exit_time += delta
		if int(_exit_time * EXIT_FPS) >= _exit.size():
			_exit = []
		return
	_time += delta

func frame() -> String:
	if not _exit.is_empty():
		return _exit[mini(int(_exit_time * EXIT_FPS), _exit.size() - 1)]
	var clip: Dictionary = clips[_state]
	var frames: Array = clip["frames"]
	var index := int(_time * float(clip["fps"]))
	if bool(clip["loop"]):
		return frames[posmod(index, frames.size())]
	return frames[mini(index, frames.size() - 1)]
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_slime_animator | tail -1`. Expected: `PASS: 8 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/slime_animator.gd scripts/player/*.uid data/slime_clips.json tests/test_slime_animator.gd tests/*.uid
git commit -m "feat: SlimeAnimator plays the slime's clips, with Spread's un-squash exit"
```

---

### Task 5: SlimeShapes (inert hurt and attack shapes)

**Files:**
- Create: `scripts/player/slime_shapes.gd`
- Test: `tests/test_slime_shapes.gd`

**Interfaces:**
- Consumes: `SpriteSheet.hurt`, `attack`, `frame_size`.
- Produces `SlimeShapes` (`Node2D`): `refresh(sheet: SpriteSheet, frame: String, left: bool)`, vars `hurt: Area2D`, `attack: Area2D`, `hurt_poly: CollisionPolygon2D`, `attack_poly: CollisionPolygon2D`. Shapes are in the node's local space (origin = the body's bottom centre), mirrored when `left`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/test_slime_shapes.gd
extends GutTest
## Hurt and attack shapes follow the drawn frame. Inert: nothing collides with them yet.

var sheet: SpriteSheet
var shapes: SlimeShapes

func before_each() -> void:
	sheet = SpriteSheet.load_set("slime")
	shapes = SlimeShapes.new()
	add_child_autofree(shapes)

func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

func test_the_hurt_shape_is_the_frames_traced_shape() -> void:
	shapes.refresh(sheet, "idle_1", false)
	assert_eq(shapes.hurt_poly.polygon, sheet.hurt("idle_1"))
	var b := _bounds(shapes.hurt_poly.polygon)
	assert_almost_eq(b.size.x, 44.0, 2.0)

func test_spread_is_flat_and_wide() -> void:
	shapes.refresh(sheet, "idle_1", false)
	var idle := _bounds(shapes.hurt_poly.polygon)
	shapes.refresh(sheet, "spread_2", false)
	var flat := _bounds(shapes.hurt_poly.polygon)
	assert_lt(flat.size.y, idle.size.y * 0.6)
	assert_gt(flat.size.x, idle.size.x)

func test_only_a_frame_with_an_attack_region_enables_the_attack_shape() -> void:
	shapes.refresh(sheet, "idle_1", false)
	assert_eq(shapes.attack_poly.polygon.size(), 0)
	assert_true(shapes.attack_poly.disabled)
	shapes.refresh(sheet, "tackle", false)
	assert_gte(shapes.attack_poly.polygon.size(), 3)
	assert_false(shapes.attack_poly.disabled)
	assert_gt(_bounds(shapes.attack_poly.polygon).get_center().x, 0.0, "the attack is at the front")

func test_facing_left_mirrors_both_shapes() -> void:
	shapes.refresh(sheet, "tackle", false)
	var hurt_right := _bounds(shapes.hurt_poly.polygon)
	var attack_right := _bounds(shapes.attack_poly.polygon)
	shapes.refresh(sheet, "tackle", true)
	assert_almost_eq(_bounds(shapes.hurt_poly.polygon).get_center().x, -hurt_right.get_center().x, 0.01)
	assert_almost_eq(_bounds(shapes.attack_poly.polygon).get_center().x, -attack_right.get_center().x, 0.01)

func test_the_areas_are_inert() -> void:
	for a in [shapes.hurt, shapes.attack]:
		assert_eq(a.collision_layer, 0)
		assert_eq(a.collision_mask, 0)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_slime_shapes`
Expected: FAIL with `Could not find type "SlimeShapes"`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/player/slime_shapes.gd
class_name SlimeShapes
extends Node2D
## Hurt and attack shapes that follow the slime's drawn frame (traced when the sheet was assembled).
## Inert for now (collision layers 0): the shapes follow the art, and the enemy plan switches the game's
## damage checks over to shapes on both sides. Positions are local: the origin is the body's bottom
## centre, and everything is mirrored when the slime faces left.

var hurt := Area2D.new()
var attack := Area2D.new()
var hurt_poly := CollisionPolygon2D.new()
var attack_poly := CollisionPolygon2D.new()

func _init() -> void:
	hurt.name = "Hurt"
	attack.name = "Attack"
	for a in [hurt, attack]:
		a.collision_layer = 0
		a.collision_mask = 0
	hurt.add_child(hurt_poly)
	attack.add_child(attack_poly)
	add_child(hurt)
	add_child(attack)
	attack_poly.disabled = true

func refresh(sheet: SpriteSheet, frame: String, left: bool) -> void:
	hurt_poly.polygon = _mirrored(sheet.hurt(frame), left)
	var front := sheet.attack(frame)
	attack_poly.polygon = _mirrored(front, left)
	attack_poly.disabled = front.size() < 3

static func _mirrored(points: PackedVector2Array, left: bool) -> PackedVector2Array:
	if not left:
		return points
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(-p.x, p.y))
	return out
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_slime_shapes | tail -1`. Expected: `PASS: 5 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/slime_shapes.gd scripts/player/*.uid tests/test_slime_shapes.gd tests/*.uid
git commit -m "feat: SlimeShapes, inert hurt and attack shapes that follow the drawn frame"
```

---

### Task 6: The Player shows the sheet's frames

**Files:**
- Modify: `scripts/player/player.gd`
- Modify: `tests/test_art_visuals.gd` (drop `test_player_frame_rules`; point the first assertion of `test_player_draws_the_slime_and_flips_with_facing` at the sheet)
- Test: `tests/test_player_frames.gd`

**Interfaces:**
- Consumes: `SpriteSheet`, `SlimeAnimator`, `SlimeShapes`, `SlimeState.pick`, `Player._faces_left`, `BodyConfig`.
- Produces on `Player`: `var use_sheet := true`, `_sheet: SpriteSheet`, `_animator: SlimeAnimator`, `_shapes: SlimeShapes`, `_draw_fallback_sprite()`. The `Player.pick_frame` static function is removed.

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/test_player_frames.gd
extends GutTest
## The Player draws the slime's frames: the right frame for the state, standing on the floor line,
## mirrored when facing left, with shapes that follow. Without the sheet it falls back to the old sprite.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	Input.action_release("aim_down")

func _floor() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, Player.BODY_BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(600, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _sprite() -> Sprite2D:
	return player.get_node("Sprite")

func test_it_starts_on_the_idle_frame() -> void:
	assert_eq(_sprite().texture, player._sheet.frame_texture("idle_1"))
	assert_eq(_sprite().scale, Vector2.ONE)

func test_the_frame_follows_the_state_and_stands_on_the_floor_line() -> void:
	_floor()
	await wait_physics_frames(12)  # the 0.12 s land squash must be over before we expect idle
	player._update_visual(0.016)
	var idle_size := player._sheet.frame_size("idle_1")
	assert_eq(_sprite().texture, player._sheet.frame_texture("idle_1"))
	assert_almost_eq(_sprite().position.y + idle_size.y / 2.0, Player.BODY_BOTTOM, 0.001)
	player.velocity = Vector2(0, -200)
	player.global_position.y -= 30.0
	await wait_physics_frames(1)
	player._update_visual(0.016)
	assert_eq(_sprite().texture, player._sheet.frame_texture("rise"))
	assert_almost_eq(_sprite().position.y + player._sheet.frame_size("rise").y / 2.0, Player.BODY_BOTTOM, 0.001)

func test_holding_down_spreads_and_letting_go_plays_the_exit() -> void:
	_floor()
	await wait_physics_frames(12)
	Input.action_press("aim_down")
	await wait_physics_frames(4)
	assert_true(player.spreading)
	for i in 6:
		player._update_visual(0.05)
	assert_eq(_sprite().texture, player._sheet.frame_texture("spread_2"))
	Input.action_release("aim_down")
	await wait_physics_frames(1)
	assert_false(player.spreading)
	assert_eq(player._animator.state(), "idle")
	var exit_frames := [player._sheet.frame_texture("spread_2"), player._sheet.frame_texture("spread_1")]
	assert_true(exit_frames.has(_sprite().texture), "the un-squash plays the spread frames in reverse first")
	for i in 6:
		player._update_visual(0.05)
	assert_eq(_sprite().texture, player._sheet.frame_texture("idle_1"))

func test_facing_left_mirrors_the_sprite_and_the_shapes() -> void:
	_floor()
	await wait_physics_frames(12)
	player.facing = -1
	player._update_visual(0.016)
	assert_true(_sprite().flip_h)
	assert_eq(player._shapes.hurt_poly.polygon[0].x, -player._sheet.hurt("idle_1")[0].x)
	player.facing = 1
	player._update_visual(0.016)
	assert_false(_sprite().flip_h)

func test_the_wall_grip_is_mirrored_from_the_wall_not_from_facing() -> void:
	assert_true(player._faces_left("wall", Vector2.RIGHT))
	assert_false(player._faces_left("wall", Vector2.LEFT))

func test_the_shapes_follow_the_frame() -> void:
	_floor()
	await wait_physics_frames(12)
	player._update_visual(0.016)
	assert_eq(player._shapes.hurt_poly.polygon, player._sheet.hurt("idle_1"))
	player._tackle_time = 0.1
	player._update_visual(0.016)
	assert_false(player._shapes.attack_poly.disabled)

func test_the_player_falls_back_without_the_sheet() -> void:
	var bare := Player.new()
	bare.use_sheet = false
	bare.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(bare)
	assert_null(bare._sheet)
	var s: Sprite2D = bare.get_node("Sprite")
	bare._update_visual(0.016)
	assert_eq(s.scale, Vector2(BodyConfig.SCALE, BodyConfig.SCALE))
	assert_not_null(s.texture)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_player_frames`
Expected: FAIL: no member `_sheet` / `use_sheet` (SCRIPT ERROR lines).

- [ ] **Step 3: Implement it in `scripts/player/player.gd`**

Variables (beside `var spreading := false`):
```gdscript
## Set false before setup() to draw the old scaled sprite instead of the slime's own frames.
var use_sheet := true
var _sheet: SpriteSheet
var _animator: SlimeAnimator
var _shapes: SlimeShapes
```
Delete the `static func pick_frame(...)` function (and its `##` comment line above it). Replace the
segment of `_update_visual` from the line `Art.set_frame(_sprite, pick_frame(...` to the end of the
function with:
```gdscript
	if _sheet == null:
		_draw_fallback_sprite()
		return
	var state := SlimeState.pick(predation.active(), _invuln > INVULN_SECONDS - HURT_FLASH, rope != null,
		_clinging(), _tackle_time > 0.0, spreading, on_floor, velocity.y, _land_timer, velocity.x)
	_animator.play(state)
	_animator.advance(delta)
	var frame := _animator.frame()
	var left := _faces_left(state, get_wall_normal() if is_on_wall() else Vector2.ZERO)
	_sprite.texture = _sheet.frame_texture(frame)
	_sprite.position.y = BODY_BOTTOM - _sheet.frame_size(frame).y / 2.0
	_sprite.scale = Vector2.ONE
	_sprite.flip_h = left
	_shapes.refresh(_sheet, frame, left)

## The old frames at the body's scale, for when the sheet is missing.
func _draw_fallback_sprite() -> void:
	var name := "slime_eat" if predation.active() else ("slime_jump" if not is_on_floor() \
		else ("slime_land" if _land_timer > 0.0 else "slime_idle"))
	Art.set_frame(_sprite, name, BODY_BOTTOM)
	_sprite.flip_h = facing < 0
	_sprite.scale = Vector2(BodyConfig.SCALE, BodyConfig.SCALE)
	if _sprite.texture != null:
		_sprite.position.y = BODY_BOTTOM - _sprite.texture.get_height() * BodyConfig.SCALE / 2.0
```
In `_build_body`, right after `add_child(_sprite)`:
```gdscript
	if use_sheet and SpriteSheet.available("slime"):
		_sheet = SpriteSheet.load_set("slime")
		_animator = SlimeAnimator.new(SlimeAnimator.load_clips())
		_animator.play("idle")
		var first := _animator.frame()
		_sprite.texture = _sheet.frame_texture(first)
		_sprite.position.y = BODY_BOTTOM - _sheet.frame_size(first).y / 2.0
		_shapes = SlimeShapes.new()
		_shapes.position = Vector2(0.0, BODY_BOTTOM)
		add_child(_shapes)
		_shapes.refresh(_sheet, first, false)
```
`tests/test_art_visuals.gd`: delete the whole `test_player_frame_rules` function, and in
`test_player_draws_the_slime_and_flips_with_facing` replace
`assert_eq(_sprite(p).texture, Art.texture("slime_idle"))` with
`assert_eq(_sprite(p).texture, p._sheet.frame_texture("idle_1"))`.

- [ ] **Step 4: Run it to verify it passes, then the full suite**

Run: import, then `tools/run_tests.sh test_player_frames | tail -1` (expected `PASS: 7 tests`), then `tools/run_tests.sh | tail -1`.
Expected: the full suite green. If `test_holding_down_spreads_and_letting_go_plays_the_exit` is timing-sensitive, adjust the number of `_update_visual` calls, not the assertions' meaning.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player.gd tests/test_player_frames.gd tests/test_art_visuals.gd tests/*.uid
git commit -m "feat: the Player draws the slime's own frames, mirrored and standing on the floor line"
```

---

### Task 7: Eating by covering

**Files:**
- Create: `scripts/player/eat_cover.gd`
- Modify: `scripts/player/player.gd`
- Test: `tests/test_eat_cover.gd`

**Interfaces:**
- Consumes: `PredationHold.progress()` (already on main), `SpriteSheet`.
- Produces `EatCover` (`Node2D`): `const PREY_MIN_SCALE := 0.2`, `const BODY_ALPHA := 0.8`, `const ENGULF_SECONDS := 0.15`, `const RELEASE_FROM := 0.92`; `static cover_frame(progress: float, t: float) -> String`; `begin(target: Node2D, sheet: SpriteSheet)`, `tick(delta: float, progress: float)`, `finish()`; vars `cover: Sprite2D`, `prey_copy: Sprite2D`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/test_eat_cover.gd
extends GutTest
## Eating covers the prey: the slime drapes over it, the prey shrinks inside, and the prey is always
## visible again afterwards, however the hold ends.

var sheet: SpriteSheet

func before_all() -> void:
	sheet = SpriteSheet.load_set("slime")

func _prey() -> Node2D:
	var prey := Node2D.new()
	prey.position = Vector2(100, 50)
	prey.add_child(Art.sprite("bat_1", 6.0))
	add_child_autofree(prey)
	return prey

func _cover(prey: Node2D) -> EatCover:
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey, sheet)
	return cover

func test_the_frame_follows_the_progress() -> void:
	assert_eq(EatCover.cover_frame(0.0, 0.0), "cover_1")
	assert_eq(EatCover.cover_frame(0.15, 0.0), "cover_2")
	assert_eq(EatCover.cover_frame(0.5, 0.0), "cover_3")
	assert_eq(EatCover.cover_frame(0.5, EatCover.ENGULF_SECONDS), "cover_4")
	assert_eq(EatCover.cover_frame(0.5, EatCover.ENGULF_SECONDS * 2.0), "cover_3")
	assert_eq(EatCover.cover_frame(0.95, 0.0), "cover_5")
	assert_eq(EatCover.cover_frame(1.0, 9.0), "cover_5")

func test_it_hides_the_prey_and_draws_a_shrinking_copy_under_a_translucent_slime() -> void:
	var prey := _prey()
	var cover := _cover(prey)
	assert_false(prey.get_node("Sprite").visible)
	assert_almost_eq(cover.cover.modulate.a, EatCover.BODY_ALPHA, 0.001)
	assert_eq(cover.prey_copy.texture, prey.get_node("Sprite").texture)
	cover.tick(0.016, 0.0)
	assert_almost_eq(cover.prey_copy.scale.x, 1.0, 0.001)
	cover.tick(0.016, 1.0)
	assert_almost_eq(cover.prey_copy.scale.x, EatCover.PREY_MIN_SCALE, 0.001)
	assert_lt(cover.prey_copy.z_index, cover.cover.z_index)

func test_the_cover_sprite_changes_frame_with_the_progress() -> void:
	var cover := _cover(_prey())
	cover.tick(0.016, 0.05)
	assert_eq(cover.cover.texture, sheet.frame_texture("cover_1"))
	cover.tick(0.016, 0.95)
	assert_eq(cover.cover.texture, sheet.frame_texture("cover_5"))

func test_the_cover_sits_on_the_prey_and_follows_it() -> void:
	var prey := _prey()
	var cover := _cover(prey)
	var s: Sprite2D = prey.get_node("Sprite")
	var bottom := s.position.y + s.texture.get_height() / 2.0
	assert_almost_eq(cover.global_position.x, prey.global_position.x, 0.001)
	assert_almost_eq(cover.global_position.y, prey.global_position.y + bottom, 0.001)
	prey.global_position += Vector2(0, 20)  # a stunned bat falling
	cover.tick(0.016, 0.5)
	assert_almost_eq(cover.global_position.y, prey.global_position.y + bottom, 0.001)

func test_the_copy_keeps_the_prey_upside_down_when_it_is_downed() -> void:
	var prey := _prey()
	prey.get_node("Sprite").flip_v = true
	prey.get_node("Sprite").modulate = Color(0.6, 0.6, 0.85)
	var cover := _cover(prey)
	assert_true(cover.prey_copy.flip_v)
	assert_eq(cover.prey_copy.modulate, Color(0.6, 0.6, 0.85))

func test_the_cover_mirrors_when_the_prey_is_to_the_left() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey, sheet, true)
	assert_true(cover.cover.flip_h)

func test_finishing_restores_the_prey() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child(cover)
	cover.begin(prey, sheet)
	cover.finish()
	assert_true(prey.get_node("Sprite").visible)
	await wait_process_frames(2)
	assert_false(is_instance_valid(cover))

func test_a_freed_prey_does_not_break_the_cover() -> void:
	var prey := _prey()
	var cover := _cover(prey)
	prey.free()
	cover.tick(0.016, 0.5)
	cover.finish()
	pass_test("no crash")

func _player_with_toad() -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var player := Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(player)
	rules.start_run()
	var skills := {}
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d
	var enemy := Enemy.new()
	for c in DefLoader.load_dir("res://data/creatures"):
		if c.id == "toad":
			enemy.setup(c, skills)
	enemy.position = Vector2(24, 6)
	add_child_autofree(enemy)
	enemy.status.stun()
	return [player, enemy]

func test_the_player_covers_prey_while_eating_and_uncovers_on_cancel() -> void:
	var pair := _player_with_toad()
	var player: Player = pair[0]
	var enemy: Enemy = pair[1]
	player.begin_predate()
	assert_true(player.predation.active())
	assert_not_null(player._cover)
	assert_false(player.get_node("Sprite").visible)
	assert_false(enemy.get_node("Sprite").visible)
	player.cancel_predate()
	assert_null(player._cover)
	assert_true(player.get_node("Sprite").visible)
	assert_true(enemy.get_node("Sprite").visible)

func test_dying_while_eating_uncovers_the_prey() -> void:
	var pair := _player_with_toad()
	var player: Player = pair[0]
	var enemy: Enemy = pair[1]
	player.begin_predate()
	player.health.take_hit(999, "physical")
	assert_true(enemy.get_node("Sprite").visible)
	assert_null(player._cover)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_eat_cover`
Expected: FAIL with `Identifier "EatCover" not declared`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/player/eat_cover.gd
class_name EatCover
extends Node2D
## Eating by covering. The slime's body does not move: this node sits on the prey, hides the prey's own
## sprite, draws a copy that shrinks as the eat bar fills, and lays a translucent cover frame over it.
## The cover frame follows the progress: lunge, drape, engulf (two pulsing frames), release. Finishing
## or cancelling shows the prey's sprite again.

const PREY_MIN_SCALE := 0.2
const BODY_ALPHA := 0.8
const ENGULF_SECONDS := 0.15
const RELEASE_FROM := 0.92

var cover := Sprite2D.new()
var prey_copy := Sprite2D.new()
var _sheet: SpriteSheet
var _target: Node2D
var _prey_sprite: Sprite2D
var _bottom := 0.0
var _tex_height := 0.0
var _time := 0.0

static func cover_frame(progress: float, t: float) -> String:
	if progress >= RELEASE_FROM:
		return "cover_5"
	if progress < 0.1:
		return "cover_1"
	if progress < 0.2:
		return "cover_2"
	return "cover_3" if int(t / ENGULF_SECONDS) % 2 == 0 else "cover_4"

func begin(target: Node2D, sheet: SpriteSheet, left: bool = false) -> void:
	_target = target
	_sheet = sheet
	top_level = true
	_prey_sprite = target.get_node_or_null("Sprite")
	if _prey_sprite != null and _prey_sprite.texture != null:
		_tex_height = float(_prey_sprite.texture.get_height())
		_bottom = _prey_sprite.position.y + _tex_height / 2.0
		prey_copy.texture = _prey_sprite.texture
		prey_copy.flip_h = _prey_sprite.flip_h
		prey_copy.flip_v = _prey_sprite.flip_v
		prey_copy.modulate = _prey_sprite.modulate
		_prey_sprite.visible = false
	global_position = target.global_position + Vector2(0.0, _bottom)
	prey_copy.z_index = 0
	prey_copy.position = Vector2(0.0, -_tex_height / 2.0)
	add_child(prey_copy)
	cover.z_index = 1
	cover.modulate.a = BODY_ALPHA
	cover.flip_h = left
	add_child(cover)
	_show("cover_1")

func tick(delta: float, progress: float) -> void:
	_time += delta
	if is_instance_valid(_target):
		global_position = _target.global_position + Vector2(0.0, _bottom)
	var s := lerpf(1.0, PREY_MIN_SCALE, clampf(progress, 0.0, 1.0))
	prey_copy.scale = Vector2(s, s)
	prey_copy.position.y = -_tex_height * s / 2.0
	_show(cover_frame(progress, _time))

func finish() -> void:
	if is_instance_valid(_prey_sprite):
		_prey_sprite.visible = true
	queue_free()

func _show(frame: String) -> void:
	cover.texture = _sheet.frame_texture(frame)
	cover.position.y = -_sheet.frame_size(frame).y / 2.0
```

`scripts/player/player.gd`: add `var _cover: EatCover`. In `begin_predate()`, after
`predation.start(target, stats.get_stat("predation_time"))`: `_start_cover(target)`. In
`process_predate(delta)`, immediately before `if predation.update(delta):`:
```gdscript
	if _cover != null:
		_cover.tick(delta, predation.progress())
```
In `cancel_predate()`, after `predation.cancel()`: `_end_cover()`. In `_complete_predation(t)`, as the
**first** line (before `predation.cancel()`, so the prey is uncovered before `consume()` frees it):
`_end_cover()`. Add:
```gdscript
func _start_cover(target: Node2D) -> void:
	if _sheet == null:
		return
	_cover = EatCover.new()
	get_parent().add_child(_cover)
	_cover.begin(target, _sheet, target.global_position.x < global_position.x)
	_sprite.visible = false

func _end_cover() -> void:
	if _cover != null and is_instance_valid(_cover):
		_cover.finish()
	_cover = null
	_sprite.visible = true
```
`_on_health_died()` already calls `cancel_predate()`, which now ends the cover.

- [ ] **Step 4: Run it to verify it passes, then the full suite**

Run: import, then `tools/run_tests.sh test_eat_cover | tail -1` (expected `PASS: 12 tests`), then `tools/run_tests.sh | tail -1`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/eat_cover.gd scripts/player/*.uid scripts/player/player.gd tests/test_eat_cover.gd tests/*.uid
git commit -m "feat: eating by covering: the slime drapes over the prey while it shrinks inside"
```

---

### Task 8: The review packet

**Files:**
- Create: `tools/art/slime_contact_sheet.py`, `tools/art/slime_gifs.py`, `tools/slime_in_game.gd`
- Create (scratch): `.tmp/slime-frames/*`

- [ ] **Step 1: Write the contact-sheet and GIF tools**

```python
# tools/art/slime_contact_sheet.py
"""A contact sheet of the slime's frames at 4x, each with its traced hurt shape (red) and attack
shape (yellow), the floor line, and the frame name. Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/slime_contact_sheet.py
"""
import json
import os

from PIL import Image, ImageDraw

SCALE = 4
CELL_W, CELL_H = 68 * SCALE + 24, 60 * SCALE + 36
COLS = 5

sheet = Image.open("assets/sheets/slime.png").convert("RGBA")
data = json.load(open("assets/sheets/slime.json"))["frames"]
names = list(data)
rows = (len(names) + COLS - 1) // COLS
out = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H), (18, 18, 32, 255))
draw = ImageDraw.Draw(out)
for i, name in enumerate(names):
    f = data[name]
    x, y, w, h = f["rect"]
    ox = (i % COLS) * CELL_W + CELL_W // 2
    oy = (i // COLS) * CELL_H + CELL_H - 20  # the floor line
    frame = sheet.crop((x, y, x + w, y + h)).resize((w * SCALE, h * SCALE), Image.NEAREST)
    out.alpha_composite(frame, (ox - w * SCALE // 2, oy - h * SCALE))
    draw.line([(ox - CELL_W // 2 + 6, oy), (ox + CELL_W // 2 - 6, oy)], fill=(70, 70, 110, 255))
    for key, color in (("hurt", (255, 80, 80, 255)), ("attack", (255, 220, 60, 255))):
        pts = [(ox + px * SCALE, oy + py * SCALE) for px, py in f[key]]
        if len(pts) >= 3:
            draw.line(pts + [pts[0]], fill=color, width=1)
    draw.text((ox - CELL_W // 2 + 6, oy + 4), "%s  %dx%d" % (name, w, h), fill=(200, 210, 230, 255))
os.makedirs(".tmp/slime-frames", exist_ok=True)
out.convert("RGB").save(".tmp/slime-frames/contact_sheet.png")
print("wrote .tmp/slime-frames/contact_sheet.png", out.size)
```

```python
# tools/art/slime_gifs.py
"""GIFs of the slime's clips from data/slime_clips.json (run, idle, spread with its exit, cover,
wall), on a floor line at 4x. Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/slime_gifs.py
"""
import json
import os

from PIL import Image, ImageDraw

SCALE = 4
W, H = 76 * SCALE, 64 * SCALE
sheet = Image.open("assets/sheets/slime.png").convert("RGBA")
frames = json.load(open("assets/sheets/slime.json"))["frames"]
clips = json.load(open("data/slime_clips.json"))
os.makedirs(".tmp/slime-frames", exist_ok=True)


def draw_frame(name):
    x, y, w, h = frames[name]["rect"]
    bg = Image.new("RGBA", (W, H), (18, 18, 32, 255))
    floor = H - 16
    ImageDraw.Draw(bg).line([(0, floor), (W, floor)], fill=(70, 70, 110, 255))
    frame = sheet.crop((x, y, x + w, y + h)).resize((w * SCALE, h * SCALE), Image.NEAREST)
    bg.alpha_composite(frame, ((W - w * SCALE) // 2, floor - h * SCALE))
    return bg.convert("P", palette=Image.ADAPTIVE)


def make(name, sequence, fps):
    imgs = [draw_frame(n) for n in sequence]
    imgs[0].save(".tmp/slime-frames/%s.gif" % name, save_all=True, append_images=imgs[1:],
                 duration=int(1000 / fps), loop=0)
    print("wrote", name + ".gif", len(imgs), "frames")


def cycle(clip, repeats):
    return clips[clip]["frames"] * repeats


make("run", cycle("run", 3), clips["run"]["fps"])
make("idle", cycle("idle", 4), clips["idle"]["fps"])
make("wall", cycle("wall", 4), clips["wall"]["fps"])
make("cover", ["cover_1"] * 3 + ["cover_2"] * 3 + ["cover_3", "cover_3", "cover_4", "cover_4"] * 3 + ["cover_5"] * 4, 8)
make("spread", ["idle_1"] * 4 + clips["spread"]["frames"] + ["spread_2"] * 8 + clips["spread"]["exit"] + ["idle_1"] * 4, 10)
```

```gdscript
# tools/slime_in_game.gd
extends SceneTree
## Full frames of the slime in the real Cave: idle, running, jumping, spreading, and covering a stunned
## toad. Needs a real renderer. Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/slime_in_game.gd

const OUT := "res://.tmp/slime-frames/"
var game
var frame := 0
var enemy  # untyped: a -s script cannot see autoloads, and the Player and Enemy scripts use them

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%sgame_%s.png" % [OUT, n]))

func _process(_delta: float) -> bool:
	frame += 1
	var p = game.player
	match frame:
		30:
			_shot("idle")
			Input.action_press("move_right")
		50:
			_shot("run")
			Input.action_release("move_right")
			Input.action_press("jump")
		56:
			Input.action_release("jump")
		62:
			_shot("jump")
		140:
			Input.action_press("aim_down")
		165:
			_shot("spread")
			Input.action_release("aim_down")
			enemy = game._spawn("toad", Vector2(p.global_position.x + 34.0, p.global_position.y))
			game.world.room.add_child(enemy)
			enemy.global_position = Vector2(p.global_position.x + 34.0, p.global_position.y)
			enemy.status.stun()
		200:
			Input.action_press("predate")
		230:
			_shot("cover")
			Input.action_release("predate")
		250:
			quit()
	return false
```

- [ ] **Step 2: Run them and read the results**

```
uv run --python 3.12 --with Pillow python tools/art/slime_contact_sheet.py
uv run --python 3.12 --with Pillow python tools/art/slime_gifs.py
```
(each the whole command, sandbox disabled). Then `gtimeout -k 5 120 env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/slime_in_game.gd 2>&1 | grep -E "ERROR|SCRIPT"` (sandbox disabled; expect no output).
**Read `.tmp/slime-frames/contact_sheet.png` and the `game_*.png` frames.** Check: the frames read as one character; the traced red shapes hug each frame; the tackle's yellow shape is the front slice; the slime stands on the floor line in every frame; in the real Cave the slime is crisp at 2×, spread is a puddle, and cover drapes over the toad.

- [ ] **Step 3: Fix real problems**

A wrong frame: regenerate that frame alone (Task 2, step 6) and re-assemble. A code bug: failing test first. Re-run the full suite.

- [ ] **Step 4: Update the docs and commit**

Append to `docs/playtest-checklist.md`:
```markdown
- [ ] The slime is about twice its old size and drawn frame by frame: idle breathes, run is a four-frame squelch, jump/fall/land squash and stretch, the tackle stretches forward.
- [ ] Hold down (S / ↓ / stick down) on the floor: the slime flattens into a puddle at half speed, and un-squashes when you let go. It can't stand or jump under a low ceiling.
- [ ] Hold K/B next to a stunned enemy: the slime drapes over it and the enemy shrinks inside until it's eaten; letting go reveals the enemy again.
```
```bash
git add tools/art tools/slime_in_game.gd docs/playtest-checklist.md
git commit -m "feat: slime review tools (contact sheet with traced shapes, clip GIFs, in-game shots) and checklist"
```

---

### Task 9: Show Sean and decide (a conversation, not code)

- [ ] **Step 1:** Copy `contact_sheet.png`, `game_*.png` and the GIFs into
`/Users/sean/sites/isekai-game/.tmp/slime-frames-shots/` and send the contact sheet and the run,
spread and cover GIFs to Sean. Describe honestly what looks good, what drifts, and which frames you
would redo.
- [ ] **Step 2:** Ask (AskUserQuestion) which frames, if any, to regenerate, and whether to merge.
Regenerate any named frame alone, re-assemble, re-run the suite, and show the frame again.
- [ ] **Step 3:** When approved, run the final whole-branch review, fix Critical and Important findings, then
merge to main, push, and clean up the worktree.

---

## Self-Review Notes

- **Spec coverage:** 1.1 (all 21 frames and the state table), 1.2 spread frames and exit, 1.3 eating by
  covering (5 frames, prey shrinks, prey hidden and restored), 1.5 the pipeline (individual generation,
  reference chaining, keying and fitting, sheet assembly with baselines, name validation, contact-sheet
  review, per-frame fallback), 0.1 traced hurt and attack shapes (inert), 0.4 the frame path and 2×.
- **Not in this plan:** enemy frames and death effects (the enemy plan), switching damage checks to shapes,
  forms, reincarnation.
- **Rulings made in this plan:** the sheet lives in its own files (no edits to the shared manifest or
  the asset-count test); frames are scaled by width with the aspect kept; hull shapes are unsimplified (a
  test proves they contain every drawn pixel); the cover is translucent by modulate, not by baked alpha
  (the assembler thresholds alpha, so translucency cannot live in the frames).
