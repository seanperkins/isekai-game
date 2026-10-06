# Blender spike: the Dead Cells way, for the goblin, spider and wolf

2026-10-06, branch `feat/blender-spike`. A spike, not a decision: it answers "what would a low-poly rigged 3D model rendered down to a pixel sprite look like and cost here". The models are mine, made from primitives in code, so they say little about what a person modelling in Blender would make; they say a lot about the pipeline.

## What Dead Cells does (from their own write-up)

Low-detail 3D models and a standard skeleton in 3DS Max; animation keyed pose to pose at 30 fps; a homebrew tool renders each frame very small with antialiasing off, cel-shaded, and writes a PNG plus a normal map per frame so the game can light the sprite. Colour comes from the render step, not painted textures. One artist for the first year. They accept less detail than hand-drawn pixel art in exchange for fast retakes, reusable animation and easy pose changes. Source: [Game Developer](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-).

## What was built

```sh
python3 tools/art/blender/spike.py goblin [--variant redcap]     # or spider, wolf; about two seconds each
python3 -m unittest tools/art/blender/test_toon.py tools/art/blender/test_pipeline.py
```

| Piece | Where | Runs in |
| --- | --- | --- |
| A tiny kit: low-poly parts (ellipsoid, tapered limb, box) bound rigidly to a real armature; forward-kinematics posing about world axes; a ground lock that stands in for foot IK | `tools/art/blender/rigkit.py` | Blender |
| One module per creature: its bones, parts, colours and animations as short tables | `tools/art/blender/creatures/{goblin,spider,wolf}.py` (129, 114, 117 lines) | Blender |
| Renders every frame twice with Cycles at one sample and no filtering: a flat colour pass and a camera-space normal pass | `render_set.py` | Blender, headless, no window |
| Cel shade from the normal (three bands), cool-shadow and warm-light hue shift, shrink with crisp alpha, dark outline, one palette made of the creature's own materials | `toon.py` | Pillow only |
| Runs both, writes frames, normal maps, GIFs and a board against today's sprites | `spike.py` | Python |

Rigs are ordinary armatures: `--save-blend FILE` writes the goblin as a `.blend` that reloads headless with 1 armature, 14 bones and 24 meshes (not opened in the Blender window in this spike). Animation tables are plain functions, so a change to a stride re-renders every frame in seconds.

## What it looks like

`docs/research/images/blender-pipeline/summary.png` (today's sprites on top of each block, then the render), the `*.gif` loops beside it, and `goblin-variants.png`.

What worked:

- **Readable and consistent in motion.** All three creatures read at 40 to 55 game pixels, and the cycles are steady because every frame comes from one pose function. There is no drift between frames, which the generated art needs retakes to avoid.
- **Variants are nearly free.** Redcap and shaman are a dict of colours plus a hat or staff on the same rig and the same animations (see `goblin.py`, `VARIANTS`). A 140-twin world is mostly "this body, other parts".
- **Animation as data.** Idle, walk and attack for the goblin; idle, crawl and lunge for the spider; idle, trot and pounce for the wolf, all as short tables.
- **A palette from the materials** (not from pixel counts) kept the wolf's small glowing eye and violet star; an automatic palette merged them away. It also makes a creature's colours a thing you can read and change.

What did not:

- **It is a different look.** Today's sprites are painterly: fur, scales, a face, texture. The render is smooth, flat-banded and toy-like. This is Dead Cells' trade ("a disappointing level of detail") and you said a small style change is acceptable, but this is more than small unless the models and colours carry more character than primitives can.
- **Dark creatures go muddy.** Three bands on near-black fur leave little to see; the hue shift and a warm highlight helped but the wolf is still flatter than the original. Lighter base colours with stronger shadow tints would fix some of it.
- **My models are crude.** Rod legs, no fur, a small face. A person with a tablet and Blender (or someone sculpting) would do far better; this proves the pipeline, not the art.
- **Not measured:** frame-to-frame pixel flicker (Dead Cells' one unsolved problem), and how it looks in the game rather than on a board.

## Tools that already exist (checked, none installed or run)

| Tool | What it gives | Licence, Blender or Godot version | Fit |
| --- | --- | --- | --- |
| [Spider Walker](https://github.com/iltaen/spider_walker) | Procedural multi-leg walking with foot raycasts and a "Bake Legs" to a keyframed Action | MIT, Blender 5.2+ | The spider's gait. Needs leg controller bones that are not children of the body bone |
| [Retarget](https://extensions.blender.org/add-ons/retarget/), [Mixaify](https://blenderartists.org/t/addon-mixaify-mixamo-to-rigify/1630129), [Expy Kit](https://www.blendernation.com/2022/06/04/blender-expy-kit-addon-easy-mixamo-to-rigify-retargeting/) | Retarget free Mixamo animations onto a Rigify rig | Free, Blender 5+ (Retarget) | Goblin and undead biped animations without keying them |
| [Auto-Rig Pro](https://superhivemarket.com/products/auto-rig-pro) | Rigging, remap of animations onto custom rigs, game export | Paid | Only if hand rigging becomes the bottleneck |
| [Godot Pixel Renderer](https://github.com/bukkbeek/GodotPixelRenderer) | 3D (GLB) to pixel art with Sobel outlines, 2 to 32 colour quantisation, dithering, normal and specular export, PNG sequences and sheets | MIT, Godot 4.4+ (4.6 in v1.3) | The closest ready-made match to the toon step, in our own engine. GUI only as far as its README says, so not scriptable |
| [Voxel Sprite Cruncher](https://haynes-y.itch.io/voxel-sprite-cruncher-3d-to-pixel-spritesheet) | GLB or FBX to sprite sheet with normal maps and a Godot playback script, "inspired by Dead Cells" | Pay what you want, licence not stated, v1.0 | Small and new; worth a look, not a dependency |
| [Sprite Sheet Maker](https://extensions.blender.org/add-ons/sprite-sheet-maker/) | Auto camera, pixelation, sheets from an animation | GPL-3, Blender 5.1+, updated Sep 2026 | Does what `spike.py` does for batching; no normal maps stated |
| [Blender-pixelart](https://github.com/twanofzo1/Blender-pixelart) | A `.blend` compositor setup that writes diffuse and normal PNGs | MIT, tiny and quiet | The same idea as `toon.py` |
| [True Pixel Art Generator](https://superhivemarket.com/products/true-pixel-art-generator-v2) | Pixel export with outlines, palette, GIF | $1, Blender 4.0 to 5.0 (not 5.2) | Out of date for 5.2 |

In your Blender 5.2: one user add-on, MPFB (MakeHuman). Bundled with Blender itself are Rigify, the glTF and FBX exporters (the input Godot Pixel Renderer wants), BVH import and the pose library.

My reading: the render and shade step is small enough (`toon.py` is 135 lines; the whole harness is about 600, all tested) that owning it is cheaper than depending on a GUI tool, and it can run in a batch or CI. The things worth borrowing are Spider Walker for multi-leg gaits and a Mixamo retargeter for biped motion. Godot Pixel Renderer is the one to compare `toon.py` against for look.

## What bringing this into the game would still need

1. **A cell mode in the assembler.** `assemble_frames.py` crops each frame to its drawn pixels and anchors it bottom-centre, which makes a rendered cycle's feet jitter sideways. A frame set rendered in a fixed cell must keep its canvas (crop once to the union box of the whole animation).
2. **Normal maps in the sheets.** The pipeline already writes `<frame>_n.png`; the game would load them as the normal texture of the sprite for 2D lights. Whether the game uses 2D lights is not verified.
3. **Palettes per area.** `toon.palette_colours` makes a palette from materials; a shared area palette would be the same call on more materials.
4. **A real model per creature.** The spike's creatures are code. The route for 187 creatures is modelling in Blender (by you, or kit-bashed from shared parts), with this code as the render and animation harness.

## Recommendation

Do not move everything to 3D. The evidence supports a narrower step: **choose one many-variant line and build it properly**, with a real model, a real rig and the animations as tables, then judge it in the game next to hand-drawn and generated sprites. The wolf line (21 forms) or the goblin line (28) fit best; the goblin also has Mixamo-style biped motion available. Keep the PNG-per-frame assembler as the seam so a set can be rendered, hand-drawn or generated, and `tools/art/provenance.json` records which.
