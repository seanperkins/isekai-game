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

## The pilot: the whole goblin tree

Your answer to "which line" was the goblin tree, so all 28 forms and the base goblin are done the same way (images in `docs/research/images/goblin-tree/`; run `python3 tools/art/blender/goblin_tree.py`).

What it took:

| Piece | Size |
| --- | --- |
| One skeleton and body builder with two proportion knobs (`bx`, `tall`) plus head and ear size | `goblin_kit.py`, 91 lines |
| A gear library: hats, coats, boots, tools, instruments, weapons, a rat backpack, a hawk | `goblin_gear.py`, 60 pieces, 389 lines, each written once and fitted to any body |
| The 28 forms as data: build, colours, gear list, arm pose, stance, mount | `goblin_forms.py`, 132 lines (3 to 8 lines a form) |
| Arm poses, stances, mounts, held-item stabilising, per-form camera fitting | `creatures/goblin.py`, 202 lines |
| The three riders reuse the wolf kit as their mount (`wolf.build_into`, scaled, with barding for the Wolf-Lord) | no new modelling |

Every form gets idle, walk and attack (the riders get the wolf's walk and pounce) with no animating: 29 forms times 20 frames, two passes each, in about a minute. Changing the base body (I made every goblin stockier after the first pass) re-renders the whole tree the same way.

It went into the game with no engine change. The 28 rendered stills were checked and imported into the `forms_goblin` sheet with `tools/art/handdraw.py import forms_goblin <folder> --native --source blender`, and the twins, the player's forms and the Menagerie draw them (`tools/creature_sheet.sh`). Each form is sized to cover roughly the area of the still it replaces: median +10% area, +12% height, with Mastersmith, Ironboot and Giant-Killer the tall outliers (a big hammer, big boots, an oversized sword).

What swapping art costs, which is worth knowing before doing it to more of the game (`docs/hand-drawing.md`, "After you change art"):

- creature placement in the generated rooms uses drawn sizes, so `tools/build_areas.sh` rewrote 21 rooms, and without it two placement tests fail;
- the bestiary and evolutions pages keep their own copies of the sheets and a test pins the bestiary's, so both need rebuilding;
- nothing else broke: 3589 of 3590 passed with the first swap, the one failure being the bestiary copy.

What it looks like, honestly:

- **Each form reads as itself.** The silhouettes differ and the gear is recognisable at game size: the Paladin's sunburst shield, the Rat King's pack of rats, the Gremlin's wrench and scarf, the Giant-Killer's oversized sword, the Redcap's red cap. Every form is consistent with its neighbours in a way the generated stills are not.
- **They have less character.** All 28 share one body, one face (a nose and an amber eye) and one skin colour. The painted originals vary faces, posture and weathering form to form, and that is a lot of what makes them feel like different creatures. The renders are bolder and flatter.
- **The mounted forms are small.** A rider and wolf together cover about 30 px of width, so the rider is only a few pixels of detail.
- **Some gear is crude.** Orpheus's lyre is a gold box, the Pied Piper's pipe a bar, the Changeling's mask a white blob. That is my modelling, not the pipeline's.

What it did not do yet, when this report was written (the spike snapshot; all of it is done since, see `docs/art-kit-guide.md`): the game drew twins as one still with a code-made breath and hop, and the walk, idle and attack frames and the normal maps were rendered but not used. Twins now play their form's clips (`data/form_clips.json`, `Enemy._draw_form_frame`), lit by the room's lights through their normal maps.

Where this leaves the choice: for a line of this shape (many forms on one body plan) the approach pays for itself, since a new form is a few lines and the whole tree stays consistent and re-renderable. It is not a substitute for what a painter does with a single hero creature, and the look is a different style from today's, so the call is yours: render the lines where consistency and quantity matter, and keep hand-drawing or generating the ones that carry a character.

## What bringing this into the game would still need

(The spike's list, all done since: the assembler's cell mode is `common_box`/`centred_frames` in `assemble_frames.py`, the normal maps ship beside every sheet and `SpriteSheet.draw_on` lights them, and the model per creature is the family kits in `docs/art-kit-guide.md`. Palettes per area are still open.)

1. **A cell mode in the assembler.** `assemble_frames.py` crops each frame to its drawn pixels and anchors it bottom-centre, which makes a rendered cycle's feet jitter sideways. A frame set rendered in a fixed cell must keep its canvas (crop once to the union box of the whole animation).
2. **Normal maps in the sheets.** The pipeline already writes `<frame>_n.png`; the game would load them as the normal texture of the sprite for 2D lights. Whether the game uses 2D lights is not verified.
3. **Palettes per area.** `toon.palette_colours` makes a palette from materials; a shared area palette would be the same call on more materials.
4. **A real model per creature.** The spike's creatures are code. The route for 187 creatures is modelling in Blender (by you, or kit-bashed from shared parts), with this code as the render and animation harness.

## Recommendation

Do not move everything to 3D. The evidence supports a narrower step: **choose one many-variant line and build it properly**, with a real model, a real rig and the animations as tables, then judge it in the game next to hand-drawn and generated sprites. The wolf line (21 forms) or the goblin line (28) fit best; the goblin also has Mixamo-style biped motion available. Keep the PNG-per-frame assembler as the seam so a set can be rendered, hand-drawn or generated, and `tools/art/provenance.json` records which.
