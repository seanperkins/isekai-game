# Held-item layer: design

Goblin forms are drawn empty-handed, and the game draws what they hold on top of the hand. A goblin that picks up a different item holds that item; today every form's weapon is a mesh rendered into every frame, so the weapon can never change.

## What I understood

On the review page you flagged the goblin: "you have included weapons in their hands. I am guessing we can change that if they pick up a different item." Your design doc gives the goblin one weapon slot and one armor slot "filled from loot", with what the slots hold still open. Success means:

- Every goblin form's sheet is drawn with empty hands. Armor, hats, cloaks and the rest of the form stay in the sheet.
- The game draws the held thing, on the hand, in every frame of every clip, for the player and for every goblin enemy. It turns with the hand, mirrors when the creature faces left, and sits in front of the body for the near hand and behind it for the far hand.
- Each form holds its own thing by default (the smith his hammer, the Piper his pipe), and the held item can be set to another at run time. Changing it changes the picture at once.
- "Held" means everything a hand carries: weapons, instruments, the lantern, the shield, the hawk, the bowl, the coin and the like (your answer: everything held).
- The sizes of forms, and so room placement, do not change because their weapons moved to a layer.
- A copy of a creature's picture (the eating cover's prey, the halves of a blade kill) either shows its items or drops them on purpose: none vanishes by accident.
- You can see it on the review page: a form with its items on, and a picker to try another.

Assumed, not said: the weapon slot, pickup rules, item stats and what a swapped item does to a form's verb are a separate piece; this one builds the capability (your answer: capability only). The 3D model on the review page stays armed for now.

## Decisions

| Question | Decision |
|---|---|
| What is held | The gear pieces that attach to a hand: axe, club, dagger, hammer, hammer_small, spear, sword_big, staff, pick, wrench, tongs, sling, trap, spindle, pipe, lyre, horn, lantern, shield, hawk, bowl, coin, ring, stone, offering, straw, doll, spiked_cap_held. A piece is marked held in `goblin_gear.py` (one registry, `HELD`); the plan confirms each by reading it. Armor (`pauldron`), head and body gear are not held. |
| How it is drawn | The body sheet carries, for every frame, where each hand is and how it is turned (`hands`). Each item is its own one-frame lit sprite with a grip point. The engine puts the item's grip on the hand and rotates it. |
| Who draws it | One engine layer, `HeldItemLayer`, on the player's sprite and on every goblin enemy's. Twins no longer have armed sheets. |
| Where the item art comes from | Each item is rendered once from its existing 3D piece, through the same cel shading and outline as the creatures, with a normal map. |
| Sizes | The fit is measured on the armed model and the frames are rendered from an empty-handed model with that fit (`render_set.py --empty-hands`), so pixels-per-unit, canvas and camera are the armed form's. A form's `size` (the hob at 1.2 times the player) and its place in the ladder are unchanged. The body stands on its feet in every frame: a frame in which a weapon was the lowest point (a club dragging on the floor) no longer lifts the goblin. |
| Item proportions | An item keeps its own proportions on every body: it is rendered once in the standard goblin's proportions and scaled by one number per form, `0.5 * (bx + tall)`, the factor the kit already applies to every gear radius. The old armed render also stretched an item's positions with the body (`bx` up to 1.32), so a hammer on the widest forms (mastersmith, ironboot) was longer than it is now; a held tool should not stretch with the body, and the before/after on the review page shows it. |
| The far hand | Item art is never shaded for a side. The layer dims the far hand's item once. |
| Scope | The capability. The weapon slot, pickup and what a held item does are separate. |

Rejected: pre-rendering every form with every item (28 forms times about 28 items of sheets), and exporting the skeleton so the engine draws body parts as separate sprites (a rewrite of how creatures are drawn).

## Architecture

```
tools/art/blender/goblin_gear.py       HELD: the names of the held pieces
tools/art/blender/creatures/goblin.py  build(variant, hold=True): hold=False leaves the held pieces out
tools/art/blender/render_set.py        --empty-hands: set up from the armed rig, discard it, render from an empty-handed one; meta.json records "hold": false
tools/art/blender/rigkit.py            Rig.discard(): remove the rig's armature and meshes from the scene
tools/art/blender/spike.py             render(..., empty_hands=False) and a --empty-hands option, forwarded to render_set.py
tools/art/blender/goblin_tree.py, species_tree.py   render goblin forms with empty_hands=True (lookdev.py stays armed: nothing it renders is installed)
tools/art/blender/held_items.py        render each held piece alone (colour + normal), find its grip, write assets/sheets/held_<item>.{png,json}, _n.png
tools/art/blender/export_forms.py      refuses an armed goblin render; writes `hands` into each frame's spec and data/held_items.json
tools/art/blender/export_base.py       the same for the player's base goblin (its plan() renames and picks frames, and carries `hands` with them); its gloom_wolf spec is not touched
tools/art/assemble_frames.py           carries `hands` through its box transform into the sheet JSON
data/held_items.json                   the items (grip, sheet) and each form's default per hand
scripts/ui/sprite_sheet.gd             draw_on leaves a note on the sprite; hands(frame) returns a frame's hand data
scripts/ui/held_item_layer.gd          HeldItemLayer: the two item sprites, follows every draw, rebinds on a form change
scripts/player/eat_cover.gd, scripts/enemies/death_fx.gd   the picture copies: the eaten prey keeps its items, a blade kill's halves drop them
scripts/enemies/enemy.gd, scripts/player/player.gd   create the layer with the form's defaults
tools/review/publish.py, app/hands.js, app/blocks/sprite-set.js, app/blocks/sprites.js   the item sheets are published, `hands` reaches the drawing code through a pure placement function, a picker swaps items
```

### Render

- `HELD` lists the piece names. The goblin build takes `hold` (default true, so every existing caller and test is unchanged); with `hold=False` the held pieces are skipped.
- `render_set.py` builds one rig and uses it both to set up (pixels-per-unit, canvas, camera, clips) and to render, so building that rig empty-handed would change the measures. With `--empty-hands` it builds the armed rig, runs `creature.setup` on it, calls `rig.discard()` (new in `rigkit.py`: removes the armature and every mesh of the rig from the scene, so nothing armed is left to be rendered), then builds a second rig with `hold=False` and renders the frames from that rig with the armed setup's poses, camera and canvas. The creature must take `hold` in its `build`; the option on any other creature is an error that says so.
- The empty rig stands on its own feet (`Rig.stand` grounds the lowest part). The two renders therefore differ only inside the held pieces' footprint, except in a grounded frame where a held piece was the lowest part of the armed model: there the empty body is lower. Its canvas still holds it (it is the armed body, lower or equal). The test names those frames and expects only drags and long staffs.
- `meta.json` records `"hold": false` for an empty-handed render. `spike.render(creature, out, variant, anims, ss, empty_hands=False)` and `spike.py`'s command take `--empty-hands` and forward it. `goblin_tree.py` and `species_tree.py` pass it for goblin renders.
- `export_forms.py` and `export_base.py` refuse a render folder of the goblin creature (`meta.creature == "goblin"`) whose `meta.json` does not say `"hold": false`, which includes a render made before this change: an armed render installed beside the layer would draw every weapon twice. Renders of other creatures (the wolf in `export_base.py`'s specs, the other families in `export_forms.py`) are not checked.
- For each frame the render records each hand: the world position of the `item_n` and `item_f` bone heads and the bone's turn from its rest direction, converted to render-canvas pixels with the same camera the picture uses.
- `held_items.py` writes each item as an ordinary `SpriteSheet` set, `assets/sheets/held_<item>.png` with its normal map `held_<item>_n.png` and `held_<item>.json` = `{"image": "held_<item>.png", "normal": "held_<item>_n.png", "frames": {"item": {"rect": [x, y, w, h], "hurt": [], "attack": []}}}` (the loader requires `rect`, `hurt` and `attack` on every frame; the item has no shapes, so the two are empty). The grip lives in `data/held_items.json`, not in the sheet. `held_items.py` renders each held piece alone at a fixed pixels-per-unit (`ITEM_PPU` = 30, about a goblin form's own, so the usual `scale` is near 1), always as the near hand's piece (`side="n"`, never marked far: the render's 0.8 on pieces marked far, such as the far lantern, would otherwise be applied twice) and in the standard goblin's proportions (`bx` = `tall` = 1). Colour and normal pass, outline and lit band as for a creature. The grip is the item bone's rest head, in the item frame's pixels. A piece used by several forms is rendered once; a piece whose look depends on a form option (colour, length) is one item per distinct option set, named `<piece>` or `<piece>_<n>`.

### Data

`assets/sheets/anim_goblin_<form>.json` and `goblin.json`: each frame gains
`"hands": {"n": {"x": 4.0, "y": -21.5, "a": 24.5}, "f": {"x": -3.0, "y": -20.0, "a": -8.0}}`, in the frame-local pixels of the hit shapes (origin at the bottom centre of the frame, x right, y down, so up is negative) and `a` in degrees clockwise on the screen from the item's own orientation. The assembler converts from render-canvas pixels with the box transform it applies to the shapes, so a hand moves with its frame whether the frame is trimmed or sits in a shared box.

`data/held_items.json`:
```json
{"items": {"axe": {"set": "held_axe", "frame": "item", "grip": [6.0, -4.0], "ppu": 30.0}},
 "forms": {"goblin_smith": {"scale": 1.09, "n": "hammer", "f": "tongs"}, "goblin": {"scale": 1.0}}}
```
Forms are keyed by the runtime form id (`goblin_smith`, the id in `data/forms/goblin_smith.tres` and the suffix of `anim_goblin_smith`); the player's base goblin and a goblin enemy with no form (the village goblin) use the key `goblin`, and `bind` treats an empty form id as `goblin`. Every goblin form has an entry, empty-handed ones included, because any hand can be given an item at run time. `scale` is one number per form: the form's pixels-per-unit over `ITEM_PPU`, times `0.5 * (bx + tall)`. The item and its grip are scaled by it together. A hand that holds nothing by default has no item. The player's base goblin sheet (`goblin.json`) carries `hands` for the frames `export_base.py` selects and renames, the same as every form's.

### Engine

- `HeldItemLayer.follow_on(sprite, sheet, frame, mirrored, lit)` (static) finds the sprite's layer and calls its `follow`; it does nothing for a sprite with none. `SpriteSheet.draw_on` calls it with `lit = sheet.has_normals()`, which covers the five player and two enemy `draw_on` sites. The paths that assign a frame without `draw_on` call it too: the enemy's still path (`_draw_still`, which the village goblin takes: `sprite_set = "goblin"`) and the player's first-frame setup and still path, all with `lit = false` because they draw their body plain (the village goblin's sheet has a normal map, but that path ignores it; the item matches its body and the path is left as it is). A sprite that gets no `follow` call in a frame shows no item, so a missed path is a test failure, not a stale item.
- **Coordinates.** The sprite is centred on its texture (`enemy._show_form_frame` puts it at `BODY_BOTTOM - frame_height * size / 2`; the player does the same), while `hands` are in the hit shapes' bottom-centre space. `follow` converts a hand's `(x, y)` to the sprite's local texture pixels, origin at the texture's centre: `(x, y + frame_height / 2)`, with x negated when mirrored. Being a child of the sprite, the item is scaled with it (the twin's `sprite_size`).
- `HeldItemLayer` (a Node2D child of the sprite) holds one pivot per hand, each a Node2D with the item's Sprite2D as its child. `set_item(side, item_id)` loads the item's set through `SpriteSheet` (so it is lit like a creature) and sets an override; `""` clears the hand; `item(side)` returns the id. `follow` places the pivot at the hand, turns it by `a`, scales it by the form's `scale`, draws the near hand's item above the body and the far hand's below it, dimmer by the far-side factor (0.8, applied here and nowhere else).
- **Facing left.** The item sprite is drawn with `SpriteSheet.draw_on(item_sprite, frame, mirrored)`, the call a creature's own sprite uses, so an item's art and its normal map are mirrored the way the body's are (in the texture for a sheet with normals, by `flip_h` for a plain one). When mirrored, the hand's x and the grip's x are negated and the turn `a` flips sign; the grip's position in the item sprite's own centred pixels is `(gx, gy + item_height / 2)` (the grip is in bottom-centre pixels like a hand), so the Sprite2D's `offset` is its negative, `(-gx, -(gy + item_height / 2))`, with `gx` negated when mirrored: the grip, not the picture's centre, sits on the pivot.
- **Lit like its body.** An item is drawn lit (`draw_on`, mirrored in the texture) exactly when `follow_on` was told the body was; otherwise it is drawn plain (`frame_texture`, `flip_h`). A goblin and its axe are never lit differently.
- **Downed.** The enemy's still path flips a downed creature with `flip_v`, which a child node does not inherit. The layer reads `sprite.flip_v` in `follow` and sets its own `scale.y` to -1 for a flipped sprite (its origin is the sprite's centre, so hands, art and turns flip about the body's centre), 1 otherwise.
- **Binding.** `bind(form_id)` sets each hand's item to the form's default for the hands that have no override. Overrides (`set_item`) persist across `bind`, so a held item survives an evolution, until `clear_overrides()`. The enemy binds at setup. The player binds when it changes art (`_use_form_sheet(def)` on an evolution) and when a new run resets the form and restores the base sheet, and `clear_overrides()` runs with that reset.
- **Picture copies.** A creature's frame used as a bare texture elsewhere shows no items unless this list says so. The eating cover's prey copy (`eat_cover.gd`) gets a copy of the layer bound to the same items, so a goblin being eaten keeps its hammer. These drop the items on purpose: the halves of a blade kill (`death_fx.gd`, cut by a shader; a later effect can throw the weapon), Swap's husk (`verb_mind.gd` via `Vfx.puffs`, a translucent decoy that fades), Mislead's decoy (`verb_kinds.gd`, a copy of the caster's texture: the Puck's lantern is not on it), and glimpses (`glimpse.gd`). A death that fades the sprite fades the layer with it. Companions are creatures with their own sheets, not goblin forms, and have no layer. The AI-drawn stills (`forms_goblin`, which the form portraits, `form_effects.gd` and the skill screen use, and which a twin draws only when its animated sheet or clips are missing or `use_sheet` is off, as in headless tests) keep the weapons they were drawn with: they are out of scope, no layer is bound to a creature that draws one. The enemy creates its layer only when the picture it draws is empty-handed art: after `_load_form` has loaded the animated sheet (`_form_sheet != null`), or when its still is the base `goblin` sheet (the village goblin). A twin whose animated sheet or clips are missing falls back to its armed still and has no layer, whatever `use_sheet` says. Tests pin an enemy with `use_sheet = false` and one with `use_sheet = true` and a missing animated sheet: neither has a layer. The plan greps every read of a creature sprite's `texture` and ledgers each copy it finds; one not named here drops its items. GUT tests pin the eating cover, the blade kill's halves, the Swap husk and the Mislead decoy.
- A frame with no `hands` entry hides the items for that frame, never leaves them where they were.

### Review page

`publish.sheet_listing` reads each frame's `hands` into `sprites.json` and adds `held`: the form's defaults with their `scale`, and the catalogue of items (image, grip, `ppu`). `sheet_media` also returns the item sets' images (the page cannot draw what is not published). `sprite-set.js`'s `frameSource` carries a frame's `hands` through to the sprites block, and a picker lists every item to try in either hand, so a change is visible without the game.

Only a frame cut from a sheet has hands (a frame published from a render has none, so it shows no items). The page lays a clip out in a new pure module `app/hands.js`, in the frames' own coordinates (origin at the bottom centre, x right, y down):

- `clipLayout(frames, items)` returns the canvas `{w, h, ax, ay}`: the union of every frame's rectangle `[-w/2, w/2] x [-h, 0]` and every item's bounds (`itemBounds`: the item's rectangle scaled by `scale` and turned by `a` about the grip, placed at the hand), and the anchor `(ax, ay)`, the pixel where the origin lands. An item that sticks out to the left, right, above or below the body widens or heightens the canvas on that side only; with no items the layout is today's (`ax = w/2`, `ay = h`).
- A frame is drawn at `(ax - w/2, ay - h)` (floored), a hand is at `(ax + x, ay + y)`, and the item is drawn there scaled by the page's zoom as the frame is.
- The canvas size is rounded outward to whole pixels (`w = ceil(right) - floor(left)`, likewise `h`, with `ax` and `ay` taken from the floored edges), so a fractional edge is not clipped; the test checks the canvas dimensions as well as the bounds.
- The picker re-lays the clip out when it changes an item and forces a repaint (it clears the tile's last-drawn frame, which the paint loop otherwise skips), so a swap shows at once even when the page is paused; a Node test covers the layout and the browser check swaps an item while paused.

The module is tested under Node like `chart.js`: frames of different sizes in one box; a tall item above the body, a wide one to the right and to the left, and one below the feet, each fully inside the canvas with the body and hand still aligned.

## Error handling

- A form or item named in `held_items.json` that has no sheet is an export error naming it; the game never shows a missing-texture box (the layer hides an item whose set will not load and prints one warning naming it).
- `set_item` with an unknown id is refused and leaves the hand as it was.
- A sheet exported before this change has no `hands`; it keeps working (no items).
- An armed render handed to an export is an error that names the folder.

## Testing

- Python (`tools/art/blender`): every `HELD` name is a gear function; every held piece a form lists has an item; an `--empty-hands` render has the armed render's canvas, pixels-per-unit and camera, and its frames differ from the armed render's only inside the held pieces' footprint (apart from the named frames where a piece was the lowest part); the scene holds one rig when the frames are rendered (no armed mesh is left); `spike.render(..., empty_hands=True)` puts `--empty-hands` on the command; a body rendered with `hold=False` has no pixel of the piece (the same render with `hold=True` does); the exported hand position matches a marker rendered at the bone head (within half a pixel of `x, y`); both export paths refuse an armed goblin render and accept a wolf render with no `hold` key; the base goblin's every frame has `hands`; an item rendered for a far-hand piece has the near piece's colours; the exported `scale` is `(ppu / ITEM_PPU) * 0.5 * (bx + tall)` for the paladin (`bx` 1.12) and for the base goblin, which holds nothing; `assemble_frames.py` converts a hand by the same transform as a shape; `held_items.json` covers every form that holds something.
- GUT (`tests/`): `set_item` loads and clears; `follow` puts the grip on the hand using a real frame of nonzero height (the centre conversion), and facing left, with an asymmetric item and a nonzero grip, mirrors the art, its normal map, the position, the grip and the turn; near above and far below the body, the far dimmed once; a frame with no `hands` hides the items; an unknown id is refused; the layer is scaled with the sprite; `bind` gives a smith its hammer, an override survives an evolution, a new run clears overrides and restores the base goblin's defaults; the village goblin (still path, no form) gets its item layer, bound to `goblin`, and a swapped-in axe follows its frame; the eating cover's prey copy has the items; a blade kill's halves, Swap's husk and Mislead's decoy have none; a downed village goblin's axe is flipped with its body; an item is plain when its body is drawn plain (the still path) and lit when it is lit; loading an item set through `SpriteSheet.load_set` works with the item JSON as written (`rect`, empty `hurt` and `attack`).
- The size ladder and bestiary tests keep passing: forms' sizes are unchanged, and a regenerated sheet's frames are smaller only where a weapon stuck out.
- Review page: `publish.py` writes the item images; `clipLayout` keeps body and hand aligned in a canvas that holds items sticking out in every direction (Node tests); a browser check (the repo's `BROWSER_CHECKS.md`) that a form shows its item at its hand across a clip whose frames differ in size, and that the picker changes it.

## Build order

1. **Render side:** `HELD`, `hold=False`, hands in the render's output, `held_items.py`, with their tests.
2. **Data:** the assembler and `export_forms` write `hands` and `data/held_items.json`; every goblin sheet, the base goblin and the item sets are regenerated; the usual ripples of an art swap (`godot --headless --import`, `tools/build_areas.sh`, `build_bestiary.py`, `build_evolutions.py`).
3. **Engine:** `HeldItemLayer`, the `draw_on` hook, the enemy and player wiring, with the GUT tests.
4. **Review page:** the items on the sprites block and the picker.

Each step ends with the work visible: step 1 as render output, step 2 as sheets, step 3 in the running game, step 4 on the page.

## Risks

- Removing a weapon shrinks frames where it stuck out (the giant killer's sword was his tallest part) and so shrinks their hurt shapes and moves nothing else; placement uses drawn sizes, so rooms are regenerated as for any art swap (last time 21 rooms changed).
- A blade kill drops the items with the picture (the halves are cut by a shader); making the weapon fall is a later effect.
- A form's verb may be shown by its instrument (the Piper's pipe). The layer keeps each form's default, so nothing changes until an item is swapped; what a swapped instrument does to the verb is the separate piece.
- The mounted forms (beast rider, lord of beasts, wolf lord) are goblin forms on a wolf's body. Their hands follow the same bones, so they get items like the rest; the plan checks their rider arm poses.
- This branch is cut from `main`. The goblin study and walk work in `.worktrees/codex-wolf` also changes `goblin_gear.py` and `goblin_kit.py`; the two are merged when the study lands, and the plan notes which files overlap.

## Out of scope

The AI-drawn stills (their weapons stay in the picture), the weapon slot and pickup, item stats and what a held item does, hand poses (open, fist), items on the 3D model, the undead, wolf and spider bodies' held things (only the goblin kit's forms are covered).
