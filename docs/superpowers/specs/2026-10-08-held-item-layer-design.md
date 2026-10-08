# Held-item layer: design

Goblin forms are drawn empty-handed, and the game draws what they hold on top of the hand. A goblin that picks up a different item holds that item; today every form's weapon is a mesh rendered into every frame, so the weapon can never change.

## What I understood

On the review page you flagged the goblin: "you have included weapons in their hands. I am guessing we can change that if they pick up a different item." Your design doc gives the goblin one weapon slot and one armor slot "filled from loot", with what the slots hold still open. Success means:

- Every goblin form's sheet is drawn with empty hands. Armor, hats, cloaks and the rest of the form stay in the sheet.
- The game draws the held thing, on the hand, in every frame of every clip, for the player and for every goblin enemy. It turns with the hand, mirrors when the creature faces left, and sits in front of the body for the near hand and behind it for the far hand.
- Each form holds its own thing by default (the smith his hammer, the Piper his pipe), and the held item can be set to another at run time. Changing it changes the picture at once.
- "Held" means everything a hand carries: weapons, instruments, the lantern, the shield, the hawk, the bowl, the coin and the like (your answer: everything held).
- The sizes of forms, and so room placement, do not change because their weapons moved to a layer.
- You can see it on the review page: a form with its items on, and a picker to try another.

Assumed, not said: the weapon slot, pickup rules, item stats and what a swapped item does to a form's verb are a separate piece; this one builds the capability (your answer: capability only). The 3D model on the review page stays armed for now.

## Decisions

| Question | Decision |
|---|---|
| What is held | The gear pieces that attach to a hand: axe, club, dagger, hammer, hammer_small, spear, sword_big, staff, pick, wrench, tongs, sling, trap, spindle, pipe, lyre, horn, lantern, shield, hawk, bowl, coin, ring, stone, offering, straw, doll, spiked_cap_held. A piece is marked held in `goblin_gear.py` (one registry, `HELD`); the plan confirms each by reading it. Armor (`pauldron`), head and body gear are not held. |
| How it is drawn | The body sheet carries, for every frame, where each hand is and how it is turned (`hands`). Each item is its own one-frame lit sprite with a grip point. The engine puts the item's grip on the hand and rotates it. |
| Who draws it | One engine layer, `HeldItemLayer`, on the player's sprite and on every goblin enemy's. Twins no longer have armed sheets. |
| Where the item art comes from | Each item is rendered once from its existing 3D piece, through the same cel shading and outline as the creatures, with a normal map. |
| Sizes | A form's pixels-per-unit is still fitted from its armed model, then the body is rendered empty-handed at that scale. A form's `size` (the hob at 1.2 times the player) and its place in the ladder are unchanged. |
| Scope | The capability. The weapon slot, pickup and what a held item does are separate. |

Rejected: pre-rendering every form with every item (28 forms times about 28 items of sheets), and exporting the skeleton so the engine draws body parts as separate sprites (a rewrite of how creatures are drawn).

## Architecture

```
tools/art/blender/goblin_gear.py       HELD: the names of the held pieces
tools/art/blender/creatures/goblin.py  build(variant, hold=True): hold=False leaves the held pieces out; the fit still comes from the armed build
tools/art/blender/held_items.py        render each held piece alone (colour + normal), find its grip, write assets/sheets/held_<item>.{png,json}, _n.png
tools/art/blender/export_forms.py      writes `hands` into each frame's spec and data/held_items.json
tools/art/assemble_frames.py           carries `hands` through its box transform into the sheet JSON
data/held_items.json                   the items (grip, sheet) and each form's default per hand
scripts/ui/sprite_sheet.gd             draw_on leaves a note on the sprite; hands(frame) returns a frame's hand data
scripts/ui/held_item_layer.gd          HeldItemLayer: the two item sprites, follows every draw
scripts/enemies/enemy.gd, scripts/player/player.gd   create the layer with the form's defaults
tools/review/                          the sprites block draws the items; a picker swaps them
```

### Render

- `HELD` lists the piece names. The goblin build takes `hold` (default true, so every existing caller and test is unchanged); with `hold=False` the held pieces are skipped. `export_forms.py` and `export_base.py` render bodies with `hold=False`. The camera and pixels-per-unit come from the armed build.
- For each frame the render records each hand: the world position of the `item_n` and `item_f` bone heads and the bone's turn from its rest direction. It converts them to render-canvas pixels with the same camera the picture uses.
- `held_items.py` renders each held piece alone, as the form that uses it builds it, at a fixed pixels-per-unit (`ITEM_PPU` = 30, about a goblin form's own, so the usual `scale` is near 1), colour and normal pass, outline and lit band as for a creature. The grip is the item bone's rest head, in the item frame's pixels. A piece used by several forms (the shield, the hammer) is rendered once; a piece whose look depends on a form option (colour, length) is one item per distinct option set, named `<piece>` or `<piece>_<n>`.

### Data

`assets/sheets/anim_<form>.json` and `goblin.json`: each frame gains
`"hands": {"n": {"x": 4.0, "y": -21.5, "a": 24.5}, "f": {"x": -3.0, "y": -20.0, "a": -8.0}}`, in the frame-local pixels of the hit shapes (origin at the bottom centre of the frame, x right, y down, so up is negative) and `a` in degrees clockwise on the screen from the item's own orientation. The assembler converts from render-canvas pixels with the box transform it applies to the shapes, so a hand moves with its frame whether the frame is trimmed or sits in a shared box.

`data/held_items.json`:
```json
{"items": {"axe": {"set": "held_axe", "frame": "item", "grip": [6.0, -4.0], "ppu": 30.0}},
 "forms": {"goblin_smith": {"n": {"item": "hammer_small", "scale": 1.0}, "f": {"item": "coin", "scale": 1.0}}, "goblin": {}}}
```
`scale` is the form's pixels-per-unit over the item's (`ppu`), times whatever a form's proportions do to held gear (the plan reads `Goblin.P` to see whether they do). A form that holds nothing in a hand has no entry for it; a hand can still be given an item at run time.

### Engine

- `SpriteSheet.draw_on` stores on the sprite what it drew (`held_frame`: the sheet, the frame name, whether mirrored) and, if the sprite has a `HeldItemLayer`, calls its `follow`. Every one of the five player and two enemy call sites is covered by that one change (the eating cover is a separate sprite and holds no items).
- `HeldItemLayer` (a Node2D child of the sprite) holds two Sprite2D children, one per hand. `set_item(side, item_id)` loads the item's set through `SpriteSheet` (so it is lit like a creature) and `""` clears it; `item(side)` returns the id. `follow` places a hand's item at the hand's `x, y` (negated in x when mirrored), turns it by `a` about the grip (the sign flips when mirrored), draws the near hand's item above the body and the far hand's below it, dimmer by the render's far-side factor (0.8). It is a child of the sprite, so the twin's `sprite_size` scales it with the body.
- `HeldItemLayer.attach(sprite, form_id)` reads `data/held_items.json` and sets the form's defaults. `enemy.gd` calls it for a goblin form's twin; `player.gd` for the goblin body.
- A frame with no `hands` entry hides the items for that frame, never leaves them where they were.

### Review page

`publish.py` writes each frame's `hands` and the held items into `sprites.json`; the `sprites` block draws an item at its hand, and a picker lists every item to try in either hand, so a change is visible without the game.

## Error handling

- A form or item named in `held_items.json` that has no sheet is an export error naming it; the game never shows a missing-texture box (the layer hides an item whose set will not load and prints one warning naming it).
- `set_item` with an unknown id is refused and leaves the hand as it was.
- A sheet exported before this change has no `hands`; it keeps working (no items).

## Testing

- Python (`tools/art/blender`): every `HELD` name is a gear function; every held piece a form lists has an item; a body rendered with `hold=False` has no pixel of the piece (the same render with `hold=True` does); the exported hand position matches a marker rendered at the bone head (the marker's centre within half a pixel of `x, y`); the fit (and so each form's size) is the same with and without the hold; `assemble_frames.py` converts a hand by the same transform as a shape; `held_items.json` covers every form that holds something.
- GUT (`tests/`): `set_item` loads and clears; `follow` puts the grip on the hand and mirrors position and turn; near above and far below the body; a frame with no `hands` hides the items; an unknown id is refused; the layer is scaled with the sprite.
- The size ladder and bestiary tests keep passing: forms' sizes are unchanged, and a regenerated sheet's frames are smaller only where a weapon stuck out.
- Review page: a browser check (the repo's `BROWSER_CHECKS.md`) that a form shows its item and the picker changes it.

## Build order

1. **Render side:** `HELD`, `hold=False`, hands in the render's output, `held_items.py`, with their tests.
2. **Data:** the assembler and `export_forms` write `hands` and `data/held_items.json`; every goblin sheet, the base goblin and the item sets are regenerated; the usual ripples of an art swap (`godot --headless --import`, `tools/build_areas.sh`, `build_bestiary.py`, `build_evolutions.py`).
3. **Engine:** `HeldItemLayer`, the `draw_on` hook, the enemy and player wiring, with the GUT tests.
4. **Review page:** the items on the sprites block and the picker.

Each step ends with the work visible: step 1 as render output, step 2 as sheets, step 3 in the running game, step 4 on the page.

## Risks

- Removing a weapon shrinks frames where it stuck out (the giant killer's sword was his tallest part) and so shrinks their hurt shapes and moves nothing else; placement uses drawn sizes, so rooms are regenerated as for any art swap (last time 21 rooms changed).
- A form's verb may be shown by its instrument (the Piper's pipe). The layer keeps each form's default, so nothing changes until an item is swapped; what a swapped instrument does to the verb is the separate piece.
- The mounted forms (beast rider, lord of beasts, wolf lord) are goblin forms on a wolf's body. Their hands follow the same bones, so they get items like the rest; the plan checks their rider arm poses.
- This branch is cut from `main`. The goblin study and walk work in `.worktrees/codex-wolf` also changes `goblin_gear.py` and `goblin_kit.py`; the two are merged when the study lands, and the plan notes which files overlap.

## Out of scope

The weapon slot and pickup, item stats and what a held item does, hand poses (open, fist), items on the 3D model, the undead, wolf and spider bodies' held things (only the goblin kit's forms are covered), and the AI-drawn stills.
