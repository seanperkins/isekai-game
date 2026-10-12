# Primary and secondary hands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A goblin's two hands get roles (primary acts, secondary is the off-hand) in the data, the render's gear placement, the animations, the engine layer and the review page, with a per-form arm mapping and two-handed items.

**Architecture:** Roles sit on top of the physical near/far arms: a form's `handed` (`"n"` default, `"f"` for the paladin) says which arm is primary. The render's `hands` stay physical; `held.py` maps roles to sides when building gear and writing the table; the motion code takes arm bases by role and swaps the arm and item rotations of non-cyclic poses; the layer and the page map a role to a pivot by `handed`.

**Tech Stack:** Python 3 (pure modules + Blender 5.2 headless), GDScript/GUT, plain-JS review page (Node for pure tests).

**Spec:** `docs/superpowers/specs/2026-10-11-hand-roles-design.md` (read it first; this plan only decides what the spec leaves open).

## Global Constraints

- Roles are the strings `"primary"` and `"secondary"`; `handed` is `"n"` or `"f"` (the physical arm of the primary hand). Role logic is **opt-in by the key `handed`** (set on every goblin form by `creatures/goblin._form`): forms without it (the undead's) keep today's near/far behaviour and never reach `held_of`, `validate_form` or the two-handed rule.
- `held.HELD` (piece → its gear function's default physical side) stays as it is. New: `ROLE_OF` (piece → default role): `tongs`, `lantern`, `coin`, `straw` and `shield` are `"secondary"`, every other `HELD` piece `"primary"`. `TWO_HANDED = {"spear", "staff"}`, primary-only.
- Item ids ignore both placement keys (`side`, `hand`); no id changes (the Puck's lantern stays `lantern_3b1f26`).
- The migration of forms' gear touches held pieces only (armor such as the ironboot's pauldron keeps its physical `side`).
- Regression gate: `compare_trees.py` between the baseline render (Task 1) and a fresh render lists no form after Task 2 and exactly `beast_rider`, `paladin`, `wolf_lord` after Task 5.
- Blender (`/Applications/Blender.app`) is required: a Blender-gated test that reports `skipped` is not a pass or a valid RED (`OK` with `skipped=0`). A fresh worktree needs `godot --headless --import` twice before the GUT tests and `test_stage_gaps`.
- Python tests: `python3 -W error::ResourceWarning -m unittest discover -s tools/art/blender -p "test_*.py"` (assembler: `-s tools/art -p test_assemble_frames.py`; review: `-s tools/review`). GUT: `tools/run_tests.sh <substring>`; the full suite once at the end (`TEST_TIMEOUT=1700 tools/run_tests.sh`). Delete stale `__pycache__/*.pyc` if a mutation check restores a file of the same size.
- Commits name their files (`git add <paths> && git commit`). No time estimates. No attribution lines in commits.

## Review Focus

Uncovered by the spec's tests but likely to bite; each has its test in the named task.
1. A far-handed form's walk: each arm keeps its physical swing sign (no same-side arm and leg in step) (Task 3).
2. A two-handed primary in hurt, die and the riders' frames: both hands stay together (Task 3).
3. The undead hoplite (shield near, spear far) poses exactly as before (Task 3).
4. An item override keeps its role across an evolution between a near-handed and a far-handed form (smith to paladin: it moves to the other pivot) (Task 6).
5. Re-installing the item sheets keeps `two_handed` (Task 2).

---

### Task 1: The comparison tool and the baseline render

**Files:** Create `tools/art/blender/compare_trees.py`, `tools/art/blender/test_compare_trees.py`.

**Interfaces — Produces:** `compare_trees.different_forms(base: str, new: str) -> list[str]`: the sorted names of forms in `base` (a `goblin_tree.py` output folder: `<form>/frames/*.png`, `<form>/raw/meta.json`) whose frame files differ in name, size or pixels from `new`'s, whose `meta.json` `hands`, `ppu`, `canvas` or `hold` differ, or that `new` lacks; extra forms in `new` are ignored. CLI `python3 tools/art/blender/compare_trees.py BASE NEW` prints them and exits 1 if any.

- [ ] **Step 1: Import the project once in this fresh worktree** — `godot --headless --import` twice (the Godot-dependent tests, `test_stage_gaps` and the GUT runs after it, need it); later tasks re-import only when they add or change PNGs or scripts.
- [ ] **Step 2: Write `test_compare_trees.py`** (pure, temp trees of tiny PNGs and meta files): `test_identical_trees_differ_nowhere`; `test_one_changed_pixel_names_the_form`; `test_a_missing_frame_or_form_names_it`; `test_changed_hands_ppu_canvas_or_hold_in_the_meta_names_the_form`; `test_extra_forms_in_the_new_tree_are_ignored`.
- [ ] **Step 3: Run** `python3 -m unittest discover -s tools/art/blender -p test_compare_trees.py` — Expected: FAIL `ModuleNotFoundError`.
- [ ] **Step 4: Implement `different_forms`** with PIL (`Image.tobytes()` and `.size`); `main()` for the CLI.
- [ ] **Step 5: Run** the same command — Expected: pass.
- [ ] **Step 6: Render the baseline before anything else changes** — `python3 tools/art/blender/goblin_tree.py --out .tmp/hands-baseline`. Expected: 29 form folders each with `raw/meta.json` (`hold: false`). Also `python3 tools/art/blender/compare_trees.py .tmp/hands-baseline .tmp/hands-baseline` prints nothing.
- [ ] **Step 7: Commit** `git add tools/art/blender/compare_trees.py tools/art/blender/test_compare_trees.py && git commit -m "feat: compare_trees.py, which names the forms whose renders differ"`.

---

### Task 2: Roles in the data and the gear

**Files:** Modify `tools/art/blender/held.py`, `held_items.py`, `goblin_forms.py` (migration), `creatures/goblin.py` (`_form`, `build`), `goblin_gear.py` (`shield`), `test_held.py`, `test_export_forms.py`, `test_export_base.py`, `test_held_items.py`; regenerate `data/held_items.json`.

**Interfaces — Produces** (`held.py`):
```python
ROLE_OF: dict[str, str]; TWO_HANDED: frozenset
def role_of(piece, kw) -> str                 # kw["hand"] else ROLE_OF[piece]
def physical_side(role, handed) -> str        # primary -> handed, secondary -> the other side
def held_of(gear) -> dict                     # {"primary": id or "", "secondary": id or ""}
def primary_piece(gear) -> str | None         # the piece name in the primary role
def validate_form(name, form) -> None         # ValueError naming `name`: bad `handed`, two pieces in a role, a two-handed piece in "secondary", a two-handed primary beside a secondary
def form_entry(form_name, ppu) -> dict        # {"scale", "handed", "primary"?, "secondary"?} (calls validate_form)
```
and `held_items.rewrite_forms(tree, root=ROOT)`: rewrites `data/held_items.json["forms"]` from each `<tree>/<form>/raw/meta.json`'s `ppu` (`goblin_<form>`; the base goblin `goblin`); `held_items.write_item` adds `"two_handed": piece in held.TWO_HANDED`; `goblin_gear.shield(g, color, emblem, side="n", **_)` binds `item_<side>` and sits on the camera side of that arm (`y + 0.07` outward: `-0.07` for `"n"`, `+0.07` for `"f"`).

- [ ] **Step 1: Write the failing tests.** `test_held.py`: `test_ROLE_OF_covers_exactly_HELD_with_the_defaults_above`; `test_role_of_honours_hand_and_physical_side_maps_roles_by_handed`; `test_item_ids_ignore_side_and_hand_and_the_pucks_lantern_keeps_its_id` (`held_of(FORMS["puck"]["gear"])["primary"] == "lantern_3b1f26"`); `test_held_of_reads_roles_and_refuses_two_pieces_in_a_role_a_two_handed_secondary_and_a_two_handed_primary_beside_a_secondary`; `test_validate_form_names_the_form`; `test_every_forms_roles_equal_what_its_sides_were` (a table `OLD_SIDES` of each form's old held `{piece: side}` captured now, before the migration, from `goblin_forms.FORMS` into the test file: `held_of` equals near→primary, far→secondary, and `physical_side(role_of(piece, kw), handed)` is the old side for every piece; the paladin's shield is `hand="primary"` until Task 4); `test_armor_keeps_its_physical_side` (the ironboot's pauldron entry still has `side="f"`); `test_form_entry_has_handed_scale_and_roles`. Export tests: expectations `{"scale", "handed": "n", "primary": ..., "secondary": ...}`. `test_held_items.py`: `test_two_handed_is_written_for_the_spear_and_the_staff_and_not_the_others` (render `spear`, `staff`, `axe`); `rewrite_forms` test (pure: a temp tree with two metas).
- [ ] **Step 2: Capture `OLD_SIDES`** by running a one-off script over `goblin_forms.FORMS` and pasting its output into `test_held.py`, **then run** `python3 -m unittest discover -s tools/art/blender -p "test_held*.py"` — Expected: FAIL (`ROLE_OF`, `role_of` and the rest missing; `test_held_items` Blender renders need `skipped=0`).
- [ ] **Step 3: Implement `held.py`** to the signatures; `_options` drops `side` and `hand`. **Migrate `goblin_forms.py`** with a one-off script (not committed) over held pieces only: `role = "primary" if kw.get("side", HELD[name]) == "n" else "secondary"` (the shield counts as `"n"`), remove `side`, add `hand=role` only when it differs from `ROLE_OF[name]`; the paladin's `G("shield")` becomes `G("shield", hand="primary")` for now.
- [ ] **Step 4: `creatures/goblin.py`:** `_form` adds `handed=forms.FORMS[...].get("handed", "n")` to the form it returns and calls `held.validate_form`; `build` passes each held piece `side=held.physical_side(held.role_of(name, kw), form["handed"])` with `hand` and `side` removed from the options it passes; non-held gear is untouched. **`held_items.py`:** `write_item` takes `piece`; add the `rewrite_forms` command (`python3 tools/art/blender/held_items.py --forms-from DIR`).
- [ ] **Step 5: Run** the Step 2 command — Expected: pass. Then `python3 tools/art/blender/goblin_tree.py --out .tmp/hands-after` and `python3 tools/art/blender/compare_trees.py .tmp/hands-baseline .tmp/hands-after` — Expected: prints nothing (every form's frames and hands identical). Then `python3 tools/art/blender/held_items.py --install` (rewrites the item rows with `two_handed`) and `python3 tools/art/blender/held_items.py --forms-from .tmp/hands-baseline --install` (rewrites the forms table); `git status --short assets` shows nothing changed (if an item sheet differs only by PNG encoding noise, compare its pixels and restore it with `git checkout`).
- [ ] **Step 6: Run** the whole art suite — Expected: `OK`. **Commit** `git add tools/art/blender data/held_items.json && git commit -m "feat: held pieces have roles and a form says which arm is primary; the render places them by role"` (add `assets/sheets/held_*` only if their bytes changed).

---

### Task 3: Roles in the animation

**Files:** Modify `tools/art/blender/biped_motion.py`, `creatures/goblin.py` (`_rider_arms`, `_rider_frame`), `test_biped_motion.py`, `test_attack_kinds.py`, `test_undead_motion.py`.

**Interfaces — Consumes:** Task 2 `held.primary_piece`, `held.TWO_HANDED`, `held.role_of`. **Produces** (`biped_motion.py`): `Body.handed` (the form's `handed` or `None`), `Body.primary` / `Body.secondary` (`"n"`/`"f"`; `"n"`/`"f"` fixed when `handed` is `None`); `two_handed(form) -> bool` (True only with `handed` and a primary piece in `TWO_HANDED`); `arm_pairs(form) -> {"n": (up, fore), "f": (up, fore)}` (base angles from `ARMS[form["arms"]]`: the first pair to the primary arm, the second to the secondary, and the primary's pair to both when `two_handed`); `_swap_hands(body, rot)` (handed `"f"`: exchange the `arm_`, `fore_` and `item_` rotations of the two sides); `_rest_channels(body)` and the rest table inside `die_pose` become **role-keyed**: their `arm_n`, `fore_n`, `item_n` entries hold the rest direction of the *primary* physical arm and item (`arm_<body.primary>`…) and their `_f` entries the secondary's, so a channel authored for the acting arm starts and ends at that arm's own idle pose before `_swap_hands` puts it there; `_two_hand(body, rot)` (a two-handed primary: the secondary arm's rotations := the primary's).

- [ ] **Step 1: Capture the undead golden values** — run a one-off script that poses the spartoi hoplite (`undead_motion`, as `test_undead_motion` builds a body) at idle `t=0.3`, walk `t=0.4`, attack `T_HOLD` and returns `direction_of` of `arm_n`, `fore_n`, `arm_f`, `fore_f`, `item_n`, `item_f` to six places; keep the numbers.
- [ ] **Step 2: Write the failing tests.** `test_biped_motion.py`: `test_arm_pairs_give_a_near_handed_form_the_presets_order_and_a_far_handed_one_the_swapped` ; `test_a_far_handed_walk_keeps_each_arms_physical_swing` (for `t` in 0, 0.1 … 0.9 the near arm's angle in a `handed="f"` body minus its angle in a `handed="n"` body is the same constant, equal to the secondary base minus the primary base); `test_a_far_handed_attack_is_the_near_handed_one_with_the_arm_and_item_rotations_exchanged` (at `T_HOLD` and `T_HIT` only: the idle pose's swing differs by physical side, so the last frame is compared with each body's own idle below); `test_attack_hurt_and_die_start_and_end_at_the_idle_pose_for_both_arms_and_both_items` (for a `handed="f"` body and a `handed="n"` one, each against its **own** idle pose: the first and last attack frames and the last hurt frame equal the idle pose's `arm_`, `fore_` and `item_` rotations on **both** physical sides; the first die frame too); `test_a_two_handed_primary_puts_both_hands_together_in_idle_walk_run_attack_hurt_and_die` (override `gear=[("spear", {})]`, `handed="n"`, `arms="carry"`; for every frame time the secondary arm and item rotations equal the primary's; also for `("staff", {})` with `handed="f"`); `test_a_one_handed_forms_arms_keep_opposite_swing_signs`; `test_attack_kind_comes_from_the_primary_item` (an axe in `hand="primary"` chops whichever arm; a lantern in the secondary does not decide it); `test_a_form_without_handed_is_posed_as_before` (the hoplite's golden values, in `test_undead_motion.py`); riders: `test_a_riders_second_hand_is_on_the_spear_in_every_frame` (`_rider_frame(form, {}, (0,0,0), t, slump)` for `beast_rider` and `wolf_lord`: `arm_f == arm_n`, `fore_f == fore_n`).
- [ ] **Step 3: Run** `python3 -m unittest discover -s tools/art/blender -p "test_biped_motion.py"` (and `test_undead_motion.py`, `test_attack_kinds.py`) — Expected: FAIL on the new tests only.
- [ ] **Step 4: Implement in `biped_motion.py`.** `Body.__init__` reads `handed`; `_arms` takes each physical side's base from `arm_pairs(body.form)` with the swing sign by the physical side; `_rest_channels` and `die_pose`'s rest table are made role-keyed as above; `attack_pose`, `hurt_pose` and `die_pose` call `_swap_hands` last when `handed == "f"`; every pose (`idle_pose`, `gait_pose`, attack, hurt, die) then calls `_two_hand`; `attack_kind(form)` uses `held.primary_piece` for a form with `handed` and the old near-item rule otherwise. In `creatures/goblin.py`, `_rider_arms` takes its bases from `arm_pairs(form)` and `_rider_frame` ends with the same copy for a two-handed primary. Forms without `handed` take none of these branches.
- [ ] **Step 5: Run** the Step 3 commands and the whole art suite — Expected: pass; **commit** `git add tools/art/blender && git commit -m "feat: the goblin's arms follow roles: bases by role and handed, a far-handed form's blows on its far arm, a two-handed item held in both"`.

---

### Task 4: Roles on the review page

**Files:** Modify `tools/review/publish.py`, `tools/review/app/hands.js`, `app/blocks/held-draw.js`, `app/blocks/sprites.js`, `tools/review/BROWSER_CHECKS.md`, `tools/review/test_publish.py`, `tools/review/test_hands.py`.

**Interfaces — Produces:** `sprites.json` `held.form = {"primary", "secondary", "handed", "scale"}` and each item `two_handed`; `hands.js`: `sideOf(role, handed)` (`"primary"` → `handed`, `"secondary"` → the other) and `shownPicks(picks, items)` → `{primary, secondary}` with the secondary shown as `""` while the primary item is two-handed (the stored `picks` untouched).

- [ ] **Step 1: Write the failing tests.** `test_publish.py`: the held-block tests expect `primary`/`secondary`/`handed` and `two_handed`. `test_hands.py` (Node): `test_sideOf_maps_roles_by_handed`; `test_shownPicks_hides_the_secondary_under_a_two_handed_primary_and_keeps_the_stored_choice`.
- [ ] **Step 2: Run** `python3 -m unittest discover -s tools/review -p "test_*.py"` — Expected: FAIL.
- [ ] **Step 3: Implement.** `publish._held` writes the new form block and `two_handed`. `held-draw.js` `defaultItems` returns items by physical side through `sideOf`; `sprites.js` keeps `picked = {primary, secondary}` (the stored choices), the pickers are "primary hand" / "secondary hand" (the secondary list has no two-handed item; the secondary picker is disabled while `shownPicks` shows it empty), and `chosen()` maps the shown roles to the physical sides `n`/`f` with `sideOf` for the layout and drawing.
- [ ] **Step 4: Run** the review suite — Expected: pass. **Browser check** (add a row to `BROWSER_CHECKS.md`): publish `goblin_smith` to a throwaway content folder; the hammer is in the near hand and the tongs in the far hand; pick `spear` for the primary hand while paused and the secondary picker disables and the tongs disappear, pick `axe` again and the tongs return.
- [ ] **Step 5: Commit** `git add tools/review && git commit -m "feat: the review page's pickers are primary and secondary hands"`.

---

### Task 5: The paladin and the riders

**Files:** Modify `tools/art/blender/goblin_forms.py`, `biped_motion.py` (`ARMS["shield_ready"]`), `attack_kinds.py` (remove `throw_free`), `test_attack_kinds.py`, `test_held.py`; create `tools/art/blender/probe_hands.py`; regenerate the paladin, beast rider and wolf lord.

- [ ] **Step 1: Write the failing tests.** `test_held.py`: the migration test now excludes the paladin; `test_the_paladin_holds_a_mace_in_the_primary_hand_and_the_shield_in_the_secondary_with_the_far_arm_primary` (`handed == "f"`, `held_of` roles `club`/`shield`, no `attack` key). `test_attack_kinds.py`: replace `PaladinThrowTest` with `test_the_paladins_attack_resolves_to_the_blessed_throw` (`attack_kinds.resolve(FORMS["paladin"], "goblin_paladin", biped_motion.attack_kind(FORMS["paladin"])) == "throw"`) and `test_the_blessed_throw_is_thrown_from_the_primary_arm_with_the_shield_arm_below_the_head` (the body is `T.body_of("paladin", attack="throw")`, since `T.body_of` copies the raw row and skips the verb resolution `goblin._form` does; with it: at `T_HOLD` the far (primary) hand is above the head and the near (shield) hand below it; at `T_HIT` the far hand is lower and forward of where it was) and keep the timing/ends-at-rest/no-foot-sink test for the paladin. `test_held_render.py`: `test_the_paladins_mace_is_on_the_far_arm_and_his_shield_on_the_near` — runs `probe_hands.py` (builds `creatures/goblin.build("paladin")` in Blender and prints `{part name: its bone}` for the `club`/`handle` and `shield` parts) and asserts the club parts are bound to `item_f` and the shield to `item_n`.
- [ ] **Step 2: Run** those tests — Expected: FAIL.
- [ ] **Step 3: Implement.** The paladin: `handed="f"`, `arms="shield_ready"`, gear `G("club")`, `G("shield")` (its default role), `attack` removed. `ARMS["shield_ready"] = (6, 26, 8, 84, 0.15)` (the mace arm hanging ready, then the shield arm), comment updated; remove `throw_free` from `attack_kinds.SPECS`. `probe_hands.py` is a Blender `-P` script printing JSON.
- [ ] **Step 4: Render every form and run the gate:** `python3 tools/art/blender/goblin_tree.py --out .tmp/hands-after` (a fresh folder: `rm -rf .tmp/hands-after` first), then `python3 tools/art/blender/compare_trees.py .tmp/hands-baseline .tmp/hands-after` — Expected: prints exactly `beast_rider`, `paladin`, `wolf_lord`. Then install those three: `python3 tools/art/blender/export_forms.py goblin paladin beast_rider wolf_lord --from .tmp/hands-after`, `python3 tools/art/blender/held_items.py --forms-from .tmp/hands-after --install`, `godot --headless --import`, `tools/build_areas.sh`.
- [ ] **Step 5: Look at them** (the page reads roles since Task 4). `python3 tools/review/publish.py sheet goblin_paladin --content .tmp/hands-review` (and the two riders), serve it (`python3 tools/review/server.py --content .tmp/hands-review --port 8799 --no-open`) and open the pages: the paladin's mace is drawn behind his body and his shield in front on the near arm, his attack throws from the mace arm, the riders' second hand is on the spear; add a `test_publish.py` test `test_the_paladin_lists_the_far_hand_as_primary` (`handed == "f"`, `primary == "club"`, `secondary == "shield"`). Adjust the paladin's `shield_ready` pair or the gear only if it reads wrong, and record any change as a ledger ruling.
- [ ] **Step 6: Run** the art suite and `tools/run_tests.sh form`, `size`, `placement`, `bestiary` — Expected: pass. **Commit** `git add tools/art assets/sheets data && git commit -m "feat: the paladin holds a mace in his far hand and the shield in his near one, and the spear riders hold the spear in both hands"` (name the regenerated sheets and the test file: `assets/sheets/anim_goblin_{paladin,beast_rider,wolf_lord}*`, `tools/art/anim_goblin_{...}_frames.json`).

---

### Task 6: Roles in the engine

**Files:** Modify `scripts/ui/held_items.gd`, `scripts/ui/held_item_layer.gd`, `tests/test_held_items.gd`, `tests/test_held_item_layer.gd`, `tests/test_held_item_wiring.gd`.

**Interfaces — Produces:** `HeldItems.form(id) -> {"scale": float, "handed": "n"|"f", "primary": String, "secondary": String}` (unknown form: `{"scale": 1.0, "handed": "n", "primary": "", "secondary": ""}`); `HeldItems.item(id)` gains `"two_handed": bool`; `HeldItemLayer.ROLES = ["primary", "secondary"]`; `set_item(role, id) -> bool`, `item(role) -> String`, `hand_of(role) -> String` (the physical side `"n"`/`"f"` by the bound form's handed); `set_item("secondary", id)` is false for a two-handed item and while the primary item is two-handed; `item("secondary")` is `""` while the primary is two-handed (the stored secondary comes back when it is not); `clear_overrides()`, `bind()`, `copy_onto()`, `suspend_on()` keep their meaning.

- [ ] **Step 1: Update and add tests.** Rewrite the three files' uses of `"n"`/`"f"` to roles (`set_item("primary", "axe")`, `item("secondary")`, the wiring tests' `item("n") == "hammer"` as `item("primary")`; the pivot checks stay physical: `HeldItemN`/`HeldItemF`). New: `test_the_roles_are_put_on_the_pivots_by_handed` (bind `goblin_paladin`: `hand_of("primary") == "f"`, the club item sprite is under `HeldItemF`, the shield under `HeldItemN`; bind `goblin_smith`: the reverse); `test_a_two_handed_item_is_primary_only_and_empties_the_secondary_hand` (`set_item("secondary", "spear")` false; `set_item("primary", "spear")` true then `item("secondary") == ""` and `set_item("secondary", "lantern")` false; setting the primary back to `axe` restores the stored secondary); `test_an_override_keeps_its_role_across_an_evolution_between_near_and_far_handed_forms` (smith → paladin: an axe set in the primary hand is on the far pivot after `bind("goblin_paladin")`); `test_the_table_has_two_handed_for_the_spear_and_the_staff_only` and `test_every_form_has_handed_and_roles`.
- [ ] **Step 2: Run** `tools/run_tests.sh held_item` — Expected: FAIL (the table already has the new keys from Task 5).
- [ ] **Step 3: Implement.** `HeldItems.form`/`item` read the new keys. In `HeldItemLayer`, overrides and `_bound` are keyed by role; `_handed` is set by `bind` (and copied by `copy_onto`); `follow` computes, for each physical side, `role = "primary" if side == _handed else "secondary"` and takes `item(role)`; `item("secondary")` applies the two-handed block; `set_item` validates the role name and the two-handed rules. `data/held_items.json` is already regenerated (Task 4).
- [ ] **Step 4: Re-import and run** — `godot --headless --import` (the scripts changed), then `tools/run_tests.sh held_item` and `tools/run_tests.sh sprite_sheet` — Expected: pass. **Commit** `git add scripts/ui tests && git commit -m "feat: the held-item layer works in primary and secondary hands, with the two-handed rule"`.

---

## Self-review (done)

Spec coverage: roles, `handed`, two-handed rule, ids, migration scope, validate (Task 2); arm bases, swap, two-handed copy, riders, opt-in and the hoplite (Task 3); paladin, riders, the regression gate (Tasks 1, 2, 5); page roles and picker state (Task 4); the engine's roles and two-handed rule (Task 6). Names: `ROLE_OF`, `role_of`, `physical_side`, `held_of`, `primary_piece`, `validate_form`, `form_entry`, `arm_pairs`, `two_handed`, `sideOf`, `shownPicks` are each defined once and used under those names.
