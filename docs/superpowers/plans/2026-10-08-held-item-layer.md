# Held-item layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Goblin forms are drawn empty-handed and the game draws what they hold in a layer, so a held item can be swapped at run time.

**Architecture:** The render drops the held gear pieces and records each hand's position and turn per frame; each held piece becomes its own lit one-frame sheet; the sheets carry `hands`, `data/held_items.json` carries the items, grips and each form's defaults and scale. A `HeldItemLayer` child of the body sprite draws the two items. The review page draws the same data.

**Tech Stack:** Python 3 (pure modules + Blender 5.2 headless), GDScript/GUT, plain-JS review page (Node for pure tests).

**Spec:** `docs/superpowers/specs/2026-10-08-held-item-layer-design.md` (read it first; this plan only decides what the spec leaves open).

## Global Constraints

- `build(variant, hold=True)`: every existing caller and test is unchanged by the default.
- `ITEM_PPU` = 30.0. Item art is rendered once as the near hand's piece in standard proportions (form `{}`), never shaded for a side; the layer applies the far dimming `FAR_DIM` = 0.8 once.
- A form's `scale` = `(ppu / ITEM_PPU) * (BASE_BX*bx + BASE_TALL*tall) / (BASE_BX + BASE_TALL)` with the form table's `bx`, `tall` (default 1); `BASE_BX`, `BASE_TALL` from `goblin_skeleton.py`. (The kit's radius factor relative to the standard goblin; the spec writes it `0.5*(bx+tall)`.)
- Hands are frame-local pixels, origin bottom-centre, x right, y down (up negative); `a` is degrees clockwise on screen from the item's own orientation. The engine converts to the centred sprite: `(x, y + frame_height/2)`.
- Item ids: the piece name, or `<piece>_<6 hex of sha1 of the sorted JSON of its non-`side` options>` (the spec's `<piece>_<n>`, made stable when forms are added). Form keys in `data/held_items.json` are runtime ids (`goblin_smith`); the base goblin and a form-less goblin enemy use `goblin`.
- Item JSON is an ordinary `SpriteSheet` set: `image`, `normal`, `frames.item = {rect, hurt: [], attack: []}`; the grip lives in `data/held_items.json`.
- Python tests: `python3 -W error::ResourceWarning -m unittest discover -s tools/art/blender -p "test_*.py"` (assembler tests: `-s tools/art -p test_assemble_frames.py`; review tools: `-s tools/review`). GUT: `tools/run_tests.sh <substring>`. No Godot window or sound: `--headless`.
- Blender (`/Applications/Blender.app`) is required: a Blender-gated test that reports `skipped` is not a pass or a valid RED. Check the run says `OK` with `skipped=0`.
- Commits name their files (`git add <paths> && git commit`), so a new file is never left out.
- No time estimates. No attribution lines in commits.

## Review Focus

Uncovered by the spec's tests but likely to bite; each has its test in the named task.
1. A dying or sliding frame where a held weapon was the lowest part: the empty body is grounded by itself and still inside the canvas (Task 2).
2. A form with no held piece (the base goblin, the village goblin) given an axe at run time: scale and hands exist (Tasks 4, 6, 7).
3. An item set whose option set differs between two forms (mastersmith's big hammer vs the smith's) gets two ids, not one (Task 1).
4. A held item survives an evolution and is cleared by a new run (Task 7).
5. Left-facing, downed (`flip_v`) and eaten goblins keep the item on the hand or drop it as the spec says (Tasks 6, 7).

---

### Task 1: The pure rules (`held.py`)

**Files:** Create `tools/art/blender/held.py`, `tools/art/blender/test_held.py`.

**Interfaces — Produces:**
```python
ITEM_PPU = 30.0
HELD: dict[str, str]                         # piece -> its default hand ("n"/"f")
def item_id(piece: str, kw: dict) -> str
def held_of(gear: list) -> dict              # [(name, kw)...] -> {"n": id or "", "f": id or ""}; two pieces on one hand -> ValueError
def items_of(gear: list) -> dict             # {id: (piece, kw without "side")}
def all_items() -> dict                      # {id: (piece, kw)}: items_of over every goblin_forms.FORMS gear list, plus every HELD piece at default options (item_id(piece, {}))
def form_scale(form: dict, ppu: float) -> float
def project(canvas, ppu, margin, center_x, x, z) -> tuple   # world (x, z) -> canvas pixel (px, py); the camera of stage.camera_params
def bone_turn(rest_head, rest_tail, head, tail) -> float     # (x, z) pairs; degrees clockwise on screen from the rest direction, in (-180, 180]
def local_of(px, py, box) -> tuple           # canvas pixel -> frame-local (x, y) for a cell cut from box (left, top, right, bottom)
def check_empty_handed(meta: dict) -> None   # ValueError naming "hold" unless meta["creature"] != "goblin" or meta.get("hold") is False
def update_table(path, items=None, forms=None) -> None   # merge into the JSON ({"items","forms"}), sorted keys, trailing newline
```
`HELD` = hawk n, club n, dagger n, axe n, spear n, sword_big n, hammer n, hammer_small n, tongs f, pick n, wrench n, staff n, spindle n, pipe n, lyre n, horn n, lantern f, stone n, bowl n, trap n, shield n, sling n, coin f, ring n, offering n, spiked_cap_held n, straw f, doll n.

- [ ] **Step 1: Write `test_held.py`** (pure, imports `held` and `goblin_forms`):
  `test_every_HELD_piece_is_exactly_a_gear_function_bound_to_an_item_bone_with_that_default_side` (parse `goblin_gear.py` with `ast`: functions whose source mentions `"item_"`; compare names and each `side=` default, `shield` has none and is `n`); `test_item_ids_differ_for_different_options_and_not_for_a_different_hand` (`hammer` vs `hammer` with `big=1.15`; `axe` n vs f same id); `test_all_items_covers_every_held_piece_at_default_options_and_every_forms_items_and_gives_big_hammers_and_cyan_lanterns_their_own_ids`; `test_held_of_reads_the_hands_a_form_holds` (smith `{"n": "hammer", "f": "tongs"}`, goblin `{"n": "", "f": ""}`, leprechaun `hammer_small`/`coin`); `test_two_pieces_on_one_hand_is_an_error`; `test_form_scale_is_1_for_a_default_form_at_ITEM_PPU_and_1_0645_times_for_the_paladin` (`bx` 1.12); `test_project_puts_the_ground_on_the_margin_row_and_the_centre_on_the_middle_column` (canvas 96, ppu 30, margin 3, z=0 → py 93, x=center_x → px 48); `test_bone_turn_is_clockwise_degrees` (up→right 90, up→left -90, up→down 180); `test_local_of_matches_the_assemblers_shape_transform` (cell 20x30 cut at box (10, 5, 30, 35): the pixel (20, 35) is (0, 0)); `test_an_armed_goblin_render_is_refused_and_a_wolf_render_is_not`; `test_update_table_merges_and_keeps_other_entries`.
- [ ] **Step 2: Run** `python3 -m unittest discover -s tools/art/blender -p test_held.py` — Expected: FAIL `ModuleNotFoundError: held`.
- [ ] **Step 3: Implement `held.py`** to the signatures above (pure Python; `import goblin_skeleton` for `BASE_BX/BASE_TALL`; id hash `hashlib.sha1(json.dumps(kw, sort_keys=True).encode()).hexdigest()[:6]`).
- [ ] **Step 4: Run** the same command — Expected: all pass. Then the whole discover (Global Constraints) — Expected: no new failure.
- [ ] **Step 5: Commit** `git add tools/art/blender/held.py tools/art/blender/test_held.py && git commit -m "feat: held.py, the pure rules of the held-item layer"`.

---

### Task 2: Render empty-handed with hands (`--empty-hands`)

**Files:** Modify `tools/art/blender/creatures/goblin.py` (`build`), `rigkit.py` (`Rig.discard`, `Rig.bone_world`), `render_set.py`, `spike.py` (`render`, its command), `goblin_tree.py:47`, `species_tree.py:57`. Create `tools/art/blender/test_held_render.py` (Blender-gated like `test_pipeline.py`: `BLENDER` env, skip if absent).

**Interfaces — Consumes:** Task 1 `held.HELD`, `held.project`, `held.bone_turn`. **Produces:** `creature.build(variant=None, hold=True)`; `Rig.discard() -> None`; `Rig.bone_world(name) -> (Vector head, Vector tail)` (world, current pose); `spike.render(creature, out, variant=None, anims=None, ss=4, empty_hands=False)`; `render_set.py --empty-hands`; `meta.json` gains `"hold": false` and `"hands": {"<anim>_<i>": {"n": [px, py, a], "f": [px, py, a]}}` (canvas pixels as `held.project`, `a` from `held.bone_turn` against `rig.rest["item_n"/"item_f"]`, rounded to 2 places).

- [ ] **Step 1: Write failing tests in `test_held_render.py`** (render with `--ss 2`, smith and base goblin, `--anims idle`): 
  `test_an_empty_render_has_the_armed_renders_canvas_and_ppu_and_says_hold_false`; `test_the_empty_alpha_is_a_strict_subset_of_the_armed_alpha_for_the_smith_and_the_giant_killer` (a leftover armed rig would make them equal: also assert the difference is non-empty); `test_hands_land_on_the_skin_of_the_hand` (the near hand's recorded `(px, py)` has a pixel within 1 render pixel of `(104, 124, 66)` ±4 in the raw albedo pass at `ss` scale, for the base goblin `idle_0` and the smith `attack_2`); `test_a_rider_form_has_hands_for_every_frame`; `test_empty_hands_on_a_creature_without_hold_is_an_error` (`--creature wolf --empty-hands` fails naming `hold`); `test_an_empty_dying_frame_is_inside_the_canvas_and_never_below_the_ground` (giant_killer and smith, `--anims die`: every frame's opaque rows end at or above `canvas - margin`, and no opaque pixel touches the canvas edge).
- [ ] **Step 2: Run** `python3 -m unittest tools/art/blender/test_held_render.py` — Expected: FAIL (the render exits non-zero on the unknown option `--empty-hands`), `skipped=0`.
- [ ] **Step 3: `creatures/goblin.py`**: `build(variant=None, hold=True)` skips gear whose name is in `held.HELD` when `hold` is false. **`rigkit.py`**: `Rig.discard` removes every part object, the armature object and its data (`bpy.data.objects.remove(..., do_unlink=True)`); `Rig.bone_world` reads `self.obj.pose.bones[name]` `head`/`tail` through `self.obj.matrix_world`.
- [ ] **Step 4: `render_set.py`**: add `--empty-hands`. If given: the creature's `build` must accept `hold` (else `SystemExit` naming `hold`); build the armed rig, run `creature.setup(rig, variant)` on it, `rig.discard()`, build `hold=False`, and render with that rig and the armed `cfg`. In the frame loop, after posing, record both hands into `meta["hands"]` (only when the rig has `item_n`); set `meta["hold"] = False`. `spike.render` takes `empty_hands` and appends `--empty-hands`; `spike.py`'s own command exposes the flag; `goblin_tree.render_form` and `species_tree` (goblin only) pass `empty_hands=True`; `lookdev.py` stays armed.
- [ ] **Step 5: Run** the Step 2 command, then the full discover — Expected: pass.
- [ ] **Step 6: Commit** `git add tools/art/blender && git commit -m "feat: render goblin forms empty-handed from the armed fit, with each hand's place per frame"`.

---

### Task 3: Item sheets (`held_items.py`)

**Files:** Create `tools/art/blender/creatures/held_item.py`, `tools/art/blender/held_items.py`, `tools/art/blender/test_held_items.py`.

**Interfaces — Consumes:** Task 1 `items_of`, `ITEM_PPU`, `project`, `update_table`; Task 2 `spike.render`. **Produces:** `held_items.py [--out DIR] [--install]`; per item `assets/sheets/held_<id>.png`, `held_<id>_n.png`, `held_<id>.json`; `data/held_items.json["items"][id] = {"set": "held_<id>", "frame": "item", "grip": [gx, gy], "ppu": 30.0}`; the catalogue is `held.all_items()` (Task 1), so a piece no form holds today (the club, the staff) or holds only with other options (the `sword_big` default) is rendered too.

- [ ] **Step 1: Write failing tests** (`test_held_items.py`, Blender-gated for the render ones): `test_a_catalogue_only_default_renders` (the club and the default `sword_big` render and write sheets); `test_an_item_sheet_has_the_json_SpriteSheet_loads` (keys `image`, `normal`, `frames.item.rect/hurt/attack`, `hurt == attack == []`, image and normal the same size); `test_the_grip_is_inside_the_item_and_a_hand_does_not_change_the_item` (`lantern` with `side="n"` and `side="f"` and the same options: one id, one set of pixels; the Puck's cyan lantern is another id with other pixels); `test_the_axe_has_pixels_above_and_beside_the_grip` (the haft goes up, the head to the right).
- [ ] **Step 2: Run** — Expected: FAIL (`held_items` missing).
- [ ] **Step 3: `creatures/held_item.py`** follows the creature protocol `render_set.py` loads: `build(variant)` makes a `Rig`, a `kit.Goblin(rig, {}, "", 1.0)` with only the core skeleton bones (loop `skeleton.core()` through `g.bone(..., raw=True)`), then `gear.GEAR[piece](g, side="n", **kw)` for the item named `variant` (looked up in `held.all_items()`); `setup(rig, variant)` returns `{"canvas": 96, "ppu": held.ITEM_PPU, "margin": 3, "center_x": 0.3, "anims": {"item": (1, lambda i, n: ({}, (0.0, 0.0, 0.0)), False)}, "still": "item_0", "extra": {"loops": {"item": False}, "grip": [px, py]}}` with `[px, py] = held.project(canvas, ppu, margin, center_x, head.x, head.z)` with `head = rig.rest["item_n"][0]` (a Vector: only its x and z are projected).
- [ ] **Step 4: `held_items.py`**: for each item `spike.render("held_item", raw, variant=id, ss=4)` then `spike.process(raw, out)`; crop `frames/item_0.png` and `_n.png` to the alpha bounding box (the same box), convert the grip with `held.local_of(px, py, box)`, write the three sheet files and the `items` entry via `held.update_table`. `--install` writes under the repo (`assets/sheets`, `data/held_items.json`); without it, into `--out`.
- [ ] **Step 5: Run** the tests and the full discover — Expected: pass. Run `python3 tools/art/blender/held_items.py --out .tmp/held` and open two PNGs to see an axe and a lantern.
- [ ] **Step 6: Commit** `git add tools/art/blender && git commit -m "feat: render each held piece as its own lit sprite with a grip"`.

---

### Task 4: The assembler and exports carry hands

**Files:** Modify `tools/art/assemble_frames.py` (`main`, new `local_hands`), `tools/art/blender/export_forms.py` (`spec_of`, `install`), `tools/art/blender/export_base.py` (`install`), tests `tools/art/test_assemble_frames.py`, `tools/art/blender/test_export_forms.py`, `test_export_base.py`.

**Interfaces — Consumes:** Task 1 `check_empty_handed`, `held_of`, `form_scale`, `update_table`; Task 2 `meta["hands"]`. **Produces:** `assemble_frames.local_hands(hands: dict, box: tuple) -> dict` (`{"n": [px, py, a]}` → `{"n": {"x", "y", "a"}}`, `x = px - left - (right-left)/2`, `y = py - bottom`); a frame spec entry may carry `"hands"`, and the sheet JSON frame then carries `"hands"`; `export_forms.spec_of(set_name, names, hands=None)`; both installs call `check_empty_handed(meta)` first and, for goblin exports only (`creature == "goblin"` in `export_forms.install`; the `goblin` spec in `export_base.install`; a wolf, spider, undead or slime install never touches the table), write the form's `forms` entry, looking the table row up first (`goblin_forms.FORMS[form]` in `export_forms.install`, whose `form` is a name such as `"smith"`; `goblin_forms.FORMS["goblin"]` for the base) and passing that dict (`goblin_smith` / `goblin`: `{"scale": form_scale(row, meta["ppu"]), "n": id, "f": id}`, a hand with no item omitted).

- [ ] **Step 1: Write failing tests**: assembler — `test_a_hand_moves_with_its_frames_box_and_is_in_the_sheet_json` (two frames, shared box, assert `hands` equals `local_hands` against that box; a frame without hands has no key); `test_local_hands_matches_held_local_of`; exports — `test_spec_of_carries_each_frames_hands`, `test_install_refuses_an_armed_goblin_render_and_does_not_check_a_wolf` (meta without `hold`), `test_a_wolf_install_leaves_held_items_json_alone`, `test_install_writes_the_form_entry_scale_and_defaults` (smith: scale for its `ppu`, `hammer`/`tongs`; base goblin: scale only), `test_the_base_export_keeps_hands_through_its_renamed_and_picked_frames` (`plan()` renames `run_1` etc.; the frame's hands follow the source name).
- [ ] **Step 2: Run** the three files — Expected: FAIL.
- [ ] **Step 3: Implement.** In `assemble_frames.main` compute the box actually used for each native frame (`shared`, else `centred_box(...)` when `centred_frames`, else `native_box(source)`) and, when the spec entry has `hands`, store `local_hands(...)`; a `hands` entry on a non-native frame is `SystemExit`. `export_base.install` adds `entry["hands"] = meta["hands"][source]` when present.
- [ ] **Step 4: Run** the Step 2 commands and the full discover — Expected: pass.
- [ ] **Step 5: Commit** `git add tools/art && git commit -m "feat: the assembler and both exports carry each frame's hands and write each form's held defaults"`.

---

### Task 5: Regenerate every goblin sheet and install the items

**Files:** Regenerated: `assets/sheets/anim_goblin_*.{png,json}`, `*_n.png`, `assets/sheets/goblin*.{png,json}`, `assets/sheets/held_*`, `art_source/frames/*`, `tools/art/anim_goblin_*_frames.json`, `data/held_items.json`, `data/form_clips.json`, `data/enemy_clips.json`, generated rooms and pages.

- [ ] **Step 1: Items** — `python3 tools/art/blender/held_items.py --install`. Expected: one `held_*.json` per item in `held_items.all_items()`.
- [ ] **Step 2: Render** — `python3 tools/art/blender/goblin_tree.py` (all 29 forms, empty-handed). Expected: 29 folders under `.tmp/goblin-tree`, each `raw/meta.json` has `"hold": false`.
- [ ] **Step 3: Install** — `python3 tools/art/blender/export_forms.py goblin` and `python3 tools/art/blender/export_base.py goblin`. Expected: `installed goblin_<form>` for each; `data/held_items.json["forms"]` has an entry for `goblin` and each installed form.
- [ ] **Step 4: Ripples** (`docs/hand-drawing.md` §"After you change art", in order): `godot --headless --import` (twice in a fresh worktree); `tools/build_areas.sh`; `python3 tools/build_bestiary.py`; `python3 tools/build_evolutions.py`.
- [ ] **Step 5: Verify** — `tools/run_tests.sh animated_forms`, `tools/run_tests.sh size`, `tools/run_tests.sh bestiary`, `tools/run_tests.sh placement` — Expected: pass (sizes unchanged: forms' `sprite_size` is untouched). In the ledger list the frames where the empty body is lower than the armed one (club or staff dragging), from comparing the old and new sheets' hurt-shape heights.
- [ ] **Step 6: Stage the generated art and data by name:** `git add assets/sheets art_source/frames tools/art/goblin_frames.json "tools/art/anim_goblin_*_frames.json" data/held_items.json data/form_clips.json data/enemy_clips.json`.
- [ ] **Step 7: Stage the ripples' output by name:** run `git status --short`; for every changed or new generated room and page it lists (the output of `tools/build_areas.sh`, `build_bestiary.py`, `build_evolutions.py`), confirm by name it is generated and `git add <that path>`. Then `git diff --cached --name-only` must list only generated files (not the plan or any source file) and `git status --short` must show no `??` line for generated output.
- [ ] **Step 8: Commit** `git commit -m "art: goblin forms drawn empty-handed; held items as their own sheets"`.

---

### Task 6: `SpriteSheet.hands`, `HeldItems`, `HeldItemLayer`

**Files:** Modify `scripts/ui/sprite_sheet.gd` (`load_set` reads `hands`, new `hands(name)`, `draw_on` calls `HeldItemLayer.follow_on`). Create `scripts/ui/held_items.gd`, `scripts/ui/held_item_layer.gd`, `tests/test_held_items.gd`, `tests/test_held_item_layer.gd` (each with its `.uid` as Godot makes it).

**Interfaces — Produces:**
```gdscript
# held_items.gd  (class_name HeldItems, static)
static func item(id: String) -> Dictionary        # {} when unknown; {"set","frame","grip": Vector2,"ppu"}
static func form(id: String) -> Dictionary        # {"scale": float, "n": String, "f": String}; "" -> "goblin"; unknown -> {"scale": 1.0, "n": "", "f": ""}
# sprite_sheet.gd
func hands(name: String) -> Dictionary            # {"n": {"x","y","a"}, "f": {...}} or {}
# held_item_layer.gd  (class_name HeldItemLayer, extends Node — not a CanvasItem, so its two pivots are drawn relative to the body sprite itself)
const FAR_DIM := 0.8
static func attach(sprite: Sprite2D) -> HeldItemLayer          # the sprite's layer, made on first use (child named "HeldItemLayer")
static func suspend_on(sprite: Sprite2D) -> void               # hides the sprite's layer but keeps its overrides (a form that draws its armed still); the next bind() shows it again
static func follow_on(sprite: Sprite2D, sheet: SpriteSheet, frame: String, mirrored: bool, lit: bool) -> void   # no-op without a layer
func bind(form_id: String) -> void                  # defaults for hands without an override; "" is "goblin"
func set_item(side: String, id: String) -> bool     # false (hand unchanged) for an unknown non-empty id; "" clears the hand
func clear_overrides() -> void
func item(side: String) -> String
func follow(sheet: SpriteSheet, frame: String, mirrored: bool, lit: bool) -> void
func copy_onto(other: Sprite2D) -> HeldItemLayer    # a layer on `other` with the same items, following the last frame drawn
```

- [ ] **Step 1: Write failing tests.** `test_held_items.gd`: `item("axe")` has a grip inside its frame; `form("goblin_smith")` is `hammer`/`tongs` with scale > 0; `form("")` equals `form("goblin")`; unknown ids are safe; every form entry names items that exist; every item's set loads through `SpriteSheet.load_set` with frame `item`. `test_held_item_layer.gd` (real sheets, a Sprite2D + `attach`): `test_set_item_loads_clears_and_refuses_an_unknown_id`; `test_follow_puts_the_grip_on_the_hand_using_the_frames_real_height` (smith `idle_1`: the item pivot's local position `== (x, y + frame_height/2)` and the item sprite's `offset == -(gx, gy + item_h/2)`); `test_facing_left_mirrors_art_normal_position_grip_and_turn` (asymmetric `axe`, nonzero grip: pivot x negated, `offset.x` sign flipped, rotation sign flipped, and the item sprite's texture is the mirrored lit one `sheet.texture_of(..., true)` for a sheet with normals); `test_near_item_is_above_and_far_item_below_the_body_and_the_far_one_is_dimmed_once` (the layer is not a `CanvasItem`; each hand's pivot is a direct child of the layer whose nearest `CanvasItem` ancestor is the body sprite; the far pivot has `show_behind_parent` true and the near false; `modulate` 0.8 on the far item, 1.0 on the near); `test_a_frame_without_hands_hides_the_items`; `test_each_pivot_is_scaled_by_the_forms_scale`; `test_every_held_piece_can_be_swapped_in` (`set_item("n", id)` is true for the default item of every piece in `held_items.json`); `test_a_flipped_sprite_flips_each_pivot` (`sprite.flip_v = true` → each pivot's `position.y` and `rotation` negate and its `scale.y == -1`; unflipped → the opposite); `test_an_item_is_plain_when_its_body_is_drawn_plain` (`lit=false` → no normal texture); `test_bind_gives_defaults_overrides_survive_a_bind_and_clear_overrides_restores_them`; `test_copy_onto_makes_a_layer_with_the_same_items`.
- [ ] **Step 2: Run** `tools/run_tests.sh held_item` — Expected: FAIL (classes missing).
- [ ] **Step 3: Implement.** `HeldItems` reads `res://data/held_items.json` once (cached). `HeldItemLayer.follow`: per side with an item and a `hands` entry — pivot (Node2D, a child of the layer; the layer is a plain `Node`) position `(±x, y + frame_h/2)` (x negated when mirrored), rotation `±a` degrees to radians, scale `form.scale`; when the sprite is `flip_v`, the pivot's `position.y` and `rotation` negate and `scale.y` is -1; item Sprite2D drawn by `item_sheet.draw_on(sprite, "item", mirrored)` when `lit` else `frame_texture` + `flip_h`, `offset = -(±gx, gy + item_h/2)`; the near pivot draws after the body, the far pivot has `show_behind_parent = true` and its item `modulate = Color(FAR_DIM, FAR_DIM, FAR_DIM)`. `SpriteSheet.draw_on` ends with `HeldItemLayer.follow_on(sprite, self, name, mirrored, has_normals())`. Remember the last `follow` arguments for `copy_onto`.
- [ ] **Step 4: Run** `tools/run_tests.sh held_item` and `tools/run_tests.sh sprite_sheet` — Expected: pass.
- [ ] **Step 5: Commit** `git add scripts/ui tests && git commit -m "feat: HeldItemLayer draws the two held items on a body sprite"`.

---

### Task 7: Wire the enemy, the player and the picture copies

**Files:** Modify `scripts/enemies/enemy.gd` (`_load_form`, the `_still` load, `_draw_still`), `scripts/player/player.gd` (`_use_form_sheet`, base sheet setup near line 540, `_draw_still`, run reset near 2228), `scripts/player/eat_cover.gd` (`begin`), `scripts/enemies/death_fx.gd` (blade halves); tests `tests/test_held_item_wiring.gd`.

**Interfaces — Consumes:** Task 6.

- [ ] **Step 1: Write failing tests** (build the enemy and player the way `tests/test_animated_forms.gd` and `tests/support/enemy_scenarios.gd` do): `test_a_twin_with_its_animated_form_gets_a_layer_bound_to_its_form` (smith: `item("n") == "hammer"`); `test_the_village_goblin_on_the_still_path_gets_a_layer_bound_to_goblin_and_a_swapped_in_axe_follows_its_frame`; `test_a_twin_with_use_sheet_false_or_a_missing_animated_sheet_has_no_layer` (`use_sheet = true` with a form whose clips are removed); `test_a_downed_village_goblins_axe_is_flipped_with_its_body`; `test_the_player_evolving_through_advance_form_into_the_smith_gets_the_hammer_and_tongs_keeps_an_override_across_it_and_a_new_run_clears_it_and_restores_the_base_goblin`; `test_a_form_that_draws_its_armed_still_shows_no_items_and_an_override_survives_it` (override an item, evolve into a form without clips, then into one with clips: the override is still set); `test_the_eating_cover_copy_keeps_the_prey_items`; `test_a_blade_kills_halves_swaps_husk_and_mislead_decoy_have_no_items` (three assertions, each through its real code path: `DeathFx` halves, `VerbMind` swap husk, `VerbKinds` mislead decoy — they copy `sprite.texture`, so none has a `HeldItemLayer` child).
- [ ] **Step 2: Run** `tools/run_tests.sh held_item_wiring` — Expected: FAIL.
- [ ] **Step 3: Implement.** Enemy: after `_load_form` sets `_form_sheet`, `HeldItemLayer.attach(_sprite).bind(def.form)`; where `_still` is loaded and its set is `goblin`, attach and `bind("")`; `_draw_still` calls `HeldItemLayer.follow_on(_sprite, _still, frame, facing < 0, false)` after the texture and flips; nothing is attached for a creature that draws its armed still. Player: `_bind_held_items(id)` attaches/binds. In `_use_form_sheet(def)` it is called with `def.id` inside the `if _use_form_clips(def):` branch before that branch returns (an animated form never reaches the end of the function), and the rest of the function (a form that draws its armed still) calls `HeldItemLayer.suspend_on(_sprite)`. It is also called with `""` after the base sheet is set up and, with `clear_overrides()`, in the reset after `_sheet = _base_sheet`; its `_draw_still` and first-frame setup call `follow_on(..., false)`. `EatCover.begin`, after it sets `prey_copy`'s texture, copies the layer when the prey sprite has one: `var layer := _prey_sprite.get_node_or_null("HeldItemLayer"); if layer != null: layer.copy_onto(prey_copy)`. Blade halves, Swap and Mislead need no code (their copies are bare textures); their tests pin that.
- [ ] **Step 4: Run** `tools/run_tests.sh held_item`, `animated_forms`, `eat_cover`, `death_fx`, `player_form` — Expected: pass.
- [ ] **Step 5: Commit** `git add scripts tests && git commit -m "feat: enemies and the player draw their held items; a swapped item survives an evolution"`.

---

### Task 8: Items on the review page

**Files:** Modify `tools/review/publish.py` (`sheet_listing`, `sheet_media`), `tools/review/app/blocks/sprite-set.js` (`frameSource`), `tools/review/app/blocks/sprites.js`, `tools/review/app/styles.css`, `tools/review/BROWSER_CHECKS.md`, `tools/review/test_publish.py`. Create `tools/review/app/hands.js`, `tools/review/test_hands.py` (Node-driven like `test_chart.py`).

**Interfaces — Produces:**
```js
// hands.js (pure)
export function itemBounds(hand, item, scale)       // {x0, y0, x1, y1} in frame coordinates: the item's w x h rectangle scaled, turned by hand.a about the grip, placed at the hand
export function clipLayout(frames, items)           // {w, h, ax, ay}: integer canvas holding every frame [-w/2,w/2]x[-h,0] and every item's bounds, rounded outward; (ax, ay) is where the origin lands
```
`sprites.json` gains `held: {"forms": {"n": id, "f": id, "scale": k}, "items": {id: {"image", "grip", "w", "h"}}}` and each listing frame `{"rect": [...], "hands": {...}}`.

- [ ] **Step 1: Write failing tests.** `test_hands.py` (Node): `test_with_no_items_the_layout_is_todays_bottom_centre_box` (`ax = w/2`, `ay = h`); `test_a_tall_item_a_wide_one_to_each_side_and_one_below_the_feet_are_inside_the_canvas_with_body_and_hand_aligned`; `test_fractional_edges_round_outward_to_whole_pixels`; `test_item_bounds_turns_about_the_grip`. `test_publish.py`: `test_sheet_listing_carries_hands_and_the_held_defaults_and_scale` (a fake root with `data/held_items.json` and a sheet with `hands`); `test_sheet_media_publishes_the_item_sheets_it_names`; `test_a_form_with_no_entry_lists_no_held_block`.
- [ ] **Step 2: Run** `python3 -m unittest discover -s tools/review -p "test_*.py"` — Expected: FAIL.
- [ ] **Step 3: Implement.** `publish.sheet_listing` reads each frame's `hands` and, from `data/held_items.json`, the form's entry and the images' sizes (`item sheets copied as items/<id>.png`); `sheet_media` returns them. `frameSource` returns `hands` with the rect. `sprites.js`: lay each clip out with `clipLayout`, draw the body at `(ax - w/2, ay - h)` and each item at `(ax + x, ay + y)` turned by `a` about its grip and scaled by `held.forms.scale` (far hand first, dimmed 0.8), and add a picker (a `<select>` per hand listing every item plus "none") that re-lays the clip out, sets the tile's canvas `width`/`height` attributes from the new layout, calls `size()` so the displayed CSS size follows, and sets `tile.last = -2` so a paused page repaints. Frames from a render folder have no hands and show no items.
- [ ] **Step 4: Run** the discover (Python and the JS tests) — Expected: pass.
- [ ] **Step 5: Publish and look.** `python3 tools/review/publish.py sheet goblin_smith --content /Users/sean/sites/isekai-game/.tmp/review --repo /Users/sean/sites/isekai-game/.worktrees/held-items` (that directory is the live review page the user watches, a deliverable and not scratch), open the page with the Chrome tools: the smith shows his hammer and tongs across `walk`; pick an `axe` for the near hand while paused and see it replace the hammer at once; pick the spear while paused and read the canvas's `getBoundingClientRect` before and after (it grows); add these checks to `BROWSER_CHECKS.md`.
- [ ] **Step 6: Commit** `git add tools/review && git commit -m "feat: the review page draws held items and lets you try another"`.

---

## Self-review (done)

Spec coverage: render empty-handed with armed fit, discard, grounding (T2); hands in exports and base (T4); items and grip, JSON schema (T3); `scale` per form incl. empty-handed (T1, T4); coordinates, facing left, lit-like-body, downed, binding, copies, village goblin, use_sheet/missing sheet (T6, T7); review page layout, rounding, repaint (T8); ripples and ladder (T5). Types: `follow_on(sprite, sheet, frame, mirrored, lit)` is the same in T6 and T7; `held.local_of`/`local_hands` agree (T1, T4); item id format is one function (T1).
