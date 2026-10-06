# Hand-drawing assets that already exist

Every sprite goes through one seam: a PNG per frame at `art_source/frames/<set>/<name>.png` (transparent or magenta background), a spec
`tools/art/<set>_frames.json` that names the frames and their width in game pixels, and `tools/art/assemble_frames.py`, which builds the
sheet the game reads and traces the hurt and attack shapes. It does not care how a PNG was made, so a drawing from Procreate or Aseprite
goes in the same way a generated one does. `tools/art/handdraw.py` wraps the steps around that seam.

```sh
python3 tools/art/handdraw.py inventory                    # every set: frames, hand-drawn so far, sources on this disk
python3 tools/art/handdraw.py pack forms_wolf              # templates + BRIEF.md in .tmp/handdraw/forms_wolf
python3 tools/art/handdraw.py check forms_wolf ~/Desktop/wolf       # problems, and preview.png (yours at game size beside today's)
python3 tools/art/handdraw.py import forms_wolf ~/Desktop/wolf      # install, rebuild the sheet, record it as hand-drawn
tools/creature_sheet.sh                                    # see it in the game's own drawing, among every creature
```

Add `--native` to any of them when you draw at the final pixel size (below). `pack --frames fenrir,warg` limits it to some frames.
Needs Pillow (`python3 -c "import PIL"`; otherwise `uv run --python 3.12 --with Pillow python tools/art/handdraw.py ...`).

## Two routes

**Paint big** (Procreate on the iPad). The template is 1254 px square, the size of the generated sources: the current art is faded under a
red floor line, a dotted margin and a centre line. Add a layer above it, draw the creature facing right with its lowest point on the red line
and nothing else (no ground, shadow, text or effects), hide the template layer, export a PNG with a transparent background. The pipeline then
shrinks your drawing to the frame's width (a 76 px sprite is a 16x shrink), so keep outlines fat (at least about 16 px) and details bold.
`check` warns when fine lines will drop out.

**Native** (Aseprite on the Mac, or Procreate at a tiny canvas). The template is the sprite's own size plus a margin. Draw the real pixels with
a pixel brush and no smoothing. The frame is taken exactly as drawn, never resized or blended, and `"native": true` is written into that
frame's entry in the spec. This is the better route for animation and for touching up a sprite that is nearly right: open the built sprite,
fix pixels, export.

## Rules `check` enforces

| Finding | Level | Meaning |
| --- | --- | --- |
| `empty` | error | nothing drawn, or everything is magenta |
| `solid_background` | error | the background is not transparent (a template left visible gives this) |
| `touches_edge` | error | the drawing runs into the canvas edge, so it is probably cut off (paint big only) |
| `unknown_frame` | error | the file name is not a frame of the set |
| `thin_detail` | warn | fine lines are dropping out at game size (paint big only) |
| `key_colour` | warn | opaque pixels are close to magenta, the background key, and will be erased: use pale lavender or soft rose for pinks |
| `stray_specks` | warn | a separate mark of 3 px or less at game size |

`import` stops on any error and changes nothing. On success it copies the frames in, keeps what it replaced in `art_source/.replaced/<set>/<time>/`
(git-ignored; copy a file back to undo), rebuilds `assets/sheets/<set>.png` and `.json`, and records the frames in `tools/art/provenance.json`
as hand-drawn, so `inventory` always says what is left to redraw.

## Things to know

- A recolor set (`pale_moth`, `storm_eel`, `taratect`) is built from another set's frames: draw the base set instead (`import` says which).
- Sets with a shared `anchor` scale size every frame against the anchor frame, so the preview's size is approximate for them; the assembler
  prints the real sizes when it rebuilds.
- Most of the 140 twin stills live in `forms_wolf`, `forms_goblin`, `forms_undead`, `forms_spider` and `forms_slime`, one frame per form (the
  slime line also reuses the shipped `slime` set). The hi-res sources of the `forms_*` sets are git-ignored (about 160 MB): back them up, or
  `pack` falls back to the built sprite as the underlay.
- Hurt and attack shapes are traced from your outline automatically; you do not draw them.
