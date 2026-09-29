# Terrain Art, Layers and Prefabs — Design

Status: draft (2026-09-28). Builds on `2026-09-28-exploration-world-design.md`. Owner: the terrain
session (branch `terrain-art`). The slime/enemy session owns characters and never touches the
paths listed under "Ownership".

## Goal

Rooms should read like Hollow Knight: a deep, layered cave with a dark playable plane, rich terrain
edges and glowing life. Today a room is a flat backdrop, one 32×32 ground tile stretched over
thin 12 px ledges, and a few sprites. This pass adds depth layers, real terrain mass and
reusable room pieces (prefabs), one biome at a time.

## Decisions

| Topic | Decision |
|---|---|
| Scale | World stays 1:1 pixels, camera zoom 1 at 640×360. Base tile 32 px (the slime is ~44×36, about 1.4 tiles wide), 8 px sub-grid |
| First biome | Cave (C1–C6). Sean approves it, then Grotto and Flooded Tunnels are generated in parallel |
| Tone | The first area is **bright, prismatic and alive**, not dark or sad (Sean, 2026-09-28): warm stone, vivid moss and flowers, rainbow crystals, drifting glow motes. Later biomes keep that luminous, lively tone in their own hues |
| The dark pass | The first, darker Cave pass is kept as a reserved biome, `deep` (`art_source/terrain/deep`, `assets/tiles/deep`, `assets/backgrounds/deep`, `deep_*` decor). A room uses it by setting `area = "deep"`. No room does yet |
| Ambient light | Per biome (`TerrainArt.AMBIENT`): the Cave is near-white, `deep` is dim. `game.gd` tweens the CanvasModulate on room entry |
| Lighting | No torches in the wilderness. Light comes from crystals, glow fungus, hanging lichen |
| Physics | Unchanged. Collision stays the room's `Rect2` solids. Art is drawn over them |
| Prefabs | Authoring-time macros: `build_world.gd` stamps a prefab into a `RoomDef`'s `solids`/`decor`. No new runtime data |
| Pipeline | Codex image generation (`/Users/sean/.local/bin/codex`, not the cmux shim), one piece per image, never a sheet (Sean's standing rule). Each piece is anchored with `--image` on `art_source/sprites_tiles_d.png` and then the biome's approved fill tile. A Python tool keys, downscales, quantizes to a shared palette and forces seams to match. If seams cannot be made to match, ask Sean before falling back to a sheet |
| Parallax | `scripts/world/terrain_parallax.gd`, our own node. Godot's `Parallax2D` anchors layers to the world origin and rooms sit far from it, so the layers never showed. Our node places each layer from the camera centre, scrolls sideways only, and repeats in x |
| Loader | `scripts/world/terrain_art.gd` loads `res://assets/tiles/<biome>/` and `res://assets/backgrounds/<biome>/`. `scripts/ui/art.gd` is not edited (the slime session may change it) |

## Depth layers (back to front)

Per biome. Parallax factor is the fraction of camera movement.

| # | Layer | z | Parallax | Content |
|---|---|---|---|---|
| 1 | `far_haze` | −30 | 0.10 | Luminous distant cavern, light shafts, low contrast |
| 2 | `far_rock` | −28 | 0.25 | Far formations and crystal spires with a few glow dots |
| 3 | `mid_rock` | −26 | 0.50 | Bigger formations, vines, flowers, prismatic crystals |
| 4 | `BackWall` | −20 | 1.00 | Recessed rock face at 40% opacity so the layers behind show through |
| 5 | Terrain | 0 | 1.00 | Painted over the collision rects, then decor and actors |
| 6 | `Motes` | 8 | 1.00 | Additive glow motes drifting up in rainbow colours |
| 7 | `foreground` | 12 | screen | A frame of leaves, vines and crystal tips glued to the screen edges, never over the middle |

`far_haze` and `far_rock` are cropped at the best-matching column so they wrap without blending.
`mid_rock` is mirrored (image plus its reflection) because the model could not tile it. All three
use `light_mask` 2, which no `PointLight2D` uses, so crystals and fungus do not wash them out; the
CanvasModulate still tints them. A test compares the wrap seam with the image's normal
column-to-column difference.

## Platform readability

Sean's rule: platforms must be clearly visible and never blend into the background. So:

- Every walkable edge (ledge, floor top, ceiling underside, wall face) has a 1 px deep-plum outline
  baked in by `terrain_build.py`; ledges also get a soft contact shadow below.
- Backdrop layers are dimmed by distance (`far_rock` 0.7, `mid_rock` 0.5), the back wall is a dim
  25% overlay, and the foreground frame is 60% opaque so it never hides a ledge.
- Point lights on painted rooms are weaker (`RoomBuilder.PAINTED_LIGHT`, pool lights too) so pale stone
  does not blow out to white.
- `tests/test_terrain.gd` checks the outline, the layer dimming order and the see-through frame.

## Terrain painting

The Cave's solids are mostly thin 12 px ledges plus generated walls (20 px) and floor (40 px). Two
painters, both drawing over the existing rects (collision untouched):

- **Mass painter** for rects at least 32 px in both directions: fill tiled 32 px from the rect's
  origin (three fill variants picked by position hash), edge strips only on sides not covered by
  another solid, corner pieces where two exposed sides meet, edges cropped at the rect's end.
- **Ledge painter** for thin rects: left cap, tiling middle, right cap, with a moss/glow lip on
  top and small drip pieces underneath.

`RoomDef.WALL` (20) and `RoomDef.FLOOR` (40) stay as they are: the floor top at y=320, the start
position, every floor crystal and the reachability tests depend on them. The 40 px floor is painted
as a 32 px cap plus 8 px of fill, and wall art is cropped to 20 px.

## Prefabs

A prefab is a small dict in `tools/prefabs.gd`: `id`, `size`, `solids`, `decor`, optional `spawn_slots`, and the surface it
attaches to (`floor`, `ceiling`, `wall_l`, `wall_r`). `stamp(room, prefab, pos, flip_x)` appends
offset copies into the room's arrays. Rules:

- Prefabs fill room interiors only. They never touch an exit span. Every exit stays at least 36 px
  wide (tested by the slime session's exit-fit test).
- Platform gaps obey the jump limits: apex about 60 px, ledge steps at most 54 px.
- Each biome ships eight to ten.

Cave set (first, built): mound (stepped, walkable), arch, pillars, outcrop (walkable), stalactites
(ceiling) and scatter (decor only). Design notes: stalagmite mound (stepped mass), crystal alcove (recess with a lit crystal), root
bridge, stalactite cluster, rubble pile, twin pillars, zig-zag shaft ledges, low shelf with a
glowing puddle. Grotto and Flooded sets follow the approved Cave one.

## Decor

Per biome about ten sprites, each generated alone, keyed, downscaled to game size. The Cave gains
`glow_fungus`, `lichen_hang`, `wall_crystal`, `stalagmite`, `root_hang`, `rubble`, `flowers`,
`puddle_glow`, and three prismatic crystals (`crystal_rose`, `crystal_gold`, `crystal_prism`), and loses the torch (art, six decor entries in `tools/build_world.gd`, generated
`data/rooms/C1–C5.tres`, the manifest entry). A test fails if any room decor id is `torch`. `tests/test_art_assets.gd` hard-codes 44 sprites
and the torch and the slime session's new character entries both change that count, so the count
is agreed with the slime session first (a count derived from the manifest is safer).

## Ownership

Mine: `assets/tiles/<biome>/`, `assets/backgrounds/<biome>/`, `art_source/terrain/`,
`tools/art/terrain_*`, `scripts/world/*`, `data/rooms/*`, `tools/build_world.gd`, `tools/prefabs.gd`.
Theirs: `scripts/player/*`, `scripts/enemies/*`, `scripts/rig/*`, character art, `tools/art/manifest.json`
character entries. Ask first: `project.godot`, `scenes/`, shared tests.

## Verification

- `tools/run_tests.sh` passes (the sprite-count test changes when the torch goes).
- Layers, painter and prefab stamping have GUT tests (sizes, no magenta fringe, seam continuity,
  exits still ≥ 36 px, prefab solids inside room bounds, no overlap with exits).
- In-engine screenshots of two or three Cave rooms show every layer, the painted terrain and at
  least one prefab. They go to Sean with `SendUserFile`. Grotto and Flooded start only after
  Sean says "approved".

## Out of scope

Slopes, destructible walls, animated water, music, enemy art, new areas beyond the three.
