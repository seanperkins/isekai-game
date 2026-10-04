# Soul Layer 3: Altars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The four rebirth pools become altars: you attune to one with Inspect, and an in-world menu banks essence into soul points and sells the altar's local perk. The pool kits go, because the head start is bought in the goddess's menu.

**Architecture:** A pure `AltarModel` holds the menu's rows and actions (attune, bank per element, buy the perk); `AltarMenu` draws it and pauses the game while open; an `Altar` world object replaces `RebirthPool` and opens the menu. The feature kind `rebirth_pool` becomes `altar` in the data, the builders, the validator, the lint, the map and the room editor, in two atomic swaps (world, then editor).

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1. Plans 1 and 2 (`scripts/soul/`, `Goddess`, `GoddessMenu`, `NavStep`) are on `main` before this starts.

**Spec:** `docs/superpowers/specs/2026-10-04-soul-layer-design.md`, "Altars (plan 3)". Execute in a worktree cut from `main` (this plan's branch `feat/soul-altars` is cut from `feat/soul-scene`; rebase it onto `main` first).

## Gate: do not start until both are true

- Plan 2 (`feat/soul-scene`) is merged to `main`.
- The movement agent's reach-model plan has landed on `main`: it edits `world_validator.gd` and `room_lint.gd`, which Task 4 edits too. Ask the movement agent (session `isekai-game-da`) before starting and again before merging; never run a full suite while it runs its own.

## Global Constraints

- Altar ids stay `C1`, `G1`, `F1`, `D1`, in the same four rooms, so saves stay valid. `WorldProgress.rebirths` and the Profile section `rebirth_choice` keep their saved keys (`pool` in the latter); nothing migrates.
- An altar's data is `{"kind": "altar", "id", "area", "perk", "pos"}`; `perk` is a perk id or `""` (no local perk yet). Only `stats` ships, at `C1`; `G1`, `F1` and `D1` carry `""`.
- The audio event name stays `pool_attuned` (`data/audio/cues.json` maps it). The default altar `C1` is always attuned.
- A perk bought at an altar applies from the next life; the menu says so. Banking and buying act only at an attuned altar.
- Never edit `scripts/movement/`, `data/movement/` or the movement tests. `room_lint.gd`, `world_validator.gd` and `room_def.gd` change only as Tasks 4 and 5 say.
- Tests that touch `Compendium.soul`, `Compendium.progress` or `SkillRules` snapshot and restore them, including the saved Profile section when the code under test saves. After creating a `.gd` with a `class_name`, run `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and commit its `.uid`. No attribution lines, no estimates.

## Review Focus

- Attuning still announces once ("Your body will remember this place.") and emits `pool_attuned`; the default altar needs no attuning (Task 3, Task 4).
- Bank and perk actions at an unattuned altar do nothing and say so (Task 2).
- The menu cannot open over a pause or on a dead player, and the game is unpaused on close and on restart (Task 3).
- A world with a bad altar (two in one area, an area that disagrees with its room, an unknown perk, another altar's perk, altars but no default, a malformed `perk`) is named by the validator, never a crash, and the startup check sees the perk list although the goddess is created later in `Game._ready` (Task 4).
- An existing save (`rebirths`, `rebirth_choice`) loads unchanged and still starts the right life (Task 4).

### Task 1: Names, with no change in behavior

**Files:**
- Modify: `scripts/world/world_progress.gd` (`DEFAULT_POOL`), `scripts/world/rebirth_choice.gd` (`pools` to `altars`), `scripts/run.gd`, `scripts/game.gd`, `scripts/soul/goddess.gd`, and every test naming them
- Test: the existing suites named in Step 3

**Interfaces:**
- Produces: `WorldProgress.DEFAULT_ALTAR` (was `DEFAULT_POOL`, still `"C1"`); `RebirthChoice.altars(rooms)` (was `pools`); `pending_start` is `{"altar", "species", "kit"}` and `Game.resolve_start` reads `pending["altar"]` and returns `"altar"` for a placed start. `last_choice()` and the saved `rebirth_choice` section keep the key `pool`: it holds an altar id (a saved key, kept so nothing migrates); say so in its doc comment.

- [ ] **Step 1: Rename** `DEFAULT_POOL` to `DEFAULT_ALTAR` everywhere (`grep -rn DEFAULT_POOL scripts tools tests`, 21 sites), `RebirthChoice.pools` to `altars` (callers: `game.gd`, `tests/test_rebirth_choice.gd`, `tests/test_rebirth_kit.gd`, `tests/test_goddess_flow.gd`), the `pools` parameter and variable names to `altars` in `Run.bind`, `Goddess.model` and `Game`, and the `"pool"` key of `pending_start` (written in `Run._begin`, read in `Game.resolve_start`) to `"altar"`, with the tests that assert `pending_start` and the `resolve_start` results.
- [ ] **Step 2: Verify the rename is complete** with `grep -rn "DEFAULT_POOL\|RebirthChoice.pools" scripts tools tests`. Expected: no output.
- [ ] **Step 3: Run** `tools/run_tests.sh rebirth`, `goddess`, `world_progress`, `test_game_soul`, `editor_play`. Expected: PASS for all (nothing behaves differently).
- [ ] **Step 4: Commit** `git add -A scripts tools tests && git commit -m "refactor: altar names for the default altar, the list, and pending_start"`.

### Task 2: `AltarModel`

**Files:**
- Create: `scripts/soul/altar_model.gd`
- Test: `tests/test_altar_model.gd`

**Interfaces:**
- Consumes: `Banking.max_units`, `Banking.bank`, `SoulProgress.buy_perk`, `perk_count`, `total_points`, `PerkDef.price_of`, `SoulRules.bank_rate`, `WorldProgress.attune`, `is_attuned`, `Essences.ALL` (water, earth, air, light, dark).
- Produces: `AltarModel` (`RefCounted`): `_init(altar_id: String, perk: PerkDef, progress: WorldProgress, soul: SoulProgress, rules: SoulRules, engine: SkillRulesEngine, on_attuned := Callable())` (`perk` may be null); `var message := ""`; `attuned() -> bool`; `rows() -> Array` (first `{"kind": "attune", "done": bool}`, then one `{"kind": "element", "element", "held", "units", "points"}` per essence, then, when there is a perk, `{"kind": "perk", "id", "name", "times", "price"}`); `row() -> int`; `move(step: int)` (clamped); `adjust(step: int)` (an element row's `units` changes by `step * bank_rate`, kept within 0 to `Banking.max_units`); `act() -> bool` (the highlighted row's action; false when nothing happened).
- Actions: attune calls `progress.attune(id)` then `on_attuned` and sets `message` `Attuned.`; an element row calls `Banking.bank` with its `units`, sets `message` `Banked N soul points.` and resets `units` (an empty amount sets `Nothing to bank.`); the perk row calls `soul.buy_perk` and sets `<name> bought. It applies from your next life.` or `Not enough soul points.`. Before attuning, element and perk rows do nothing and set `Attune first.`.

- [ ] **Step 1: Write the failing tests.** Fixtures: an engine as `tests/test_banking.gd` builds it, `SoulRules.new()`, `SoulProgress.new(null, ["stats"])`, a `WorldProgress.new()`, and a `stats` `PerkDef` (base 5, step 3). Tests: `test_rows_are_attune_five_elements_then_the_perk` (kinds in order; no perk gives no perk row); `test_attuning_records_it_once_and_calls_back` (`on_attuned` called once, `progress.is_attuned("G1")`, a second `act()` is false); `test_the_default_altar_is_already_attuned` (`"C1"`: the attune row is `done`); `test_banking_and_buying_do_nothing_until_attuned` (`G1`, 27 water held: moving to Water, `adjust(1)` twice, `act()` is false, `message` is `Attune first.`, held and points unchanged; the same on the perk row with points); `test_adjust_steps_by_the_bank_rate_within_what_is_held` (27 water: units 10, 20, then 20 again; `adjust(-1)` back to 10, 0, 0; an element with nothing held stays 0); `test_banking_an_element_turns_the_amount_into_points` (attuned, 27 water, units 20: `act()` true, points 2, `held("water")` 7, `units` 0, `message` `Banked 2 soul points.`; an empty amount is false with `Nothing to bank.`); `test_buying_the_perk_follows_the_price_curve` (20 points: buys at 5 then 8, then `Not enough soul points.` at 11 with 7 left; `times` reads 2); `test_move_clamps`.
- [ ] **Step 2: Run** `tools/run_tests.sh altar_model`. Expected: FAIL, `Parse Error` for `AltarModel`.
- [ ] **Step 3: Implement** `AltarModel` as specified.
- [ ] **Step 4: Run** `tools/run_tests.sh altar_model`. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/soul/altar_model.gd* tests/test_altar_model.gd* && git commit -m "feat: AltarModel, attune, bank and buy at an altar as pure state"`.

### Task 3: `Altar`, `AltarMenu` and the wiring

**Files:**
- Create: `scripts/world/altar.gd`, `scripts/ui/altar_menu.gd`
- Modify: `scripts/soul/goddess.gd` (public `rules`, new `perk_for`), `scripts/world/rebirth_choice.gd` (`_name` becomes public `altar_name`), `scripts/game.gd`
- Test: `tests/test_altar.gd`, `tests/test_altar_menu.gd`, `tests/test_goddess.gd`

**Interfaces:**
- Produces: `Goddess.rules: SoulRules` (public) and `Goddess.perk_for(id: String) -> PerkDef` (null for `""` or unknown); `RebirthChoice.altar_name(f: Dictionary) -> String` (`Cave mouth` for the default, else `<Area> altar`).
- Produces: `Altar` (`Node2D`, interactable, the pool's glow and motes): `setup(f, ctx)` reads `id`, `area`, `perk` (default `""`) and `pos`, and from `ctx` `progress`, `announce` and an optional `altar_menu` Callable; `prompt() -> String` (`attune` until attuned, then `altar`); `interact(player)` calls `ctx["altar_menu"]` with the altar when there is one, else attunes directly; `is_attuned() -> bool`; `announce_attuned()` (emits `pool_attuned` with the altar's position and calls `announce(id, "Your body will remember this place.")`).
- Produces: `AltarMenu` (`CanvasLayer`, layer 25, `process_mode` ALWAYS, hidden until opened): `bind(goddess: Goddess, engine: SkillRulesEngine, progress: WorldProgress, player: Node)` (it keeps `engine`, readable as `AltarMenu.engine`); `open_for(altar: Altar) -> bool` (false, nothing opened, when paused already or the player is dead; builds the `AltarModel` with `goddess.perk_for(altar.perk)` and `altar.announce_attuned` as `on_attuned`; pauses the tree); `open_model(model: AltarModel, title: String)` (what `open_for` ends in, for tests); `close()` (unpauses); `is_open()`; `move`, `adjust`, `act`; `title_text()`, `row_texts() -> Array`, `footer_text() -> String`. Row text: highlighted rows start `"> "`, others two spaces; `Attune` or `Attuned`; `Water  held 27  bank 20 = 2`; `Stronger base stats  x2  next 11`. Footer: `"Soul points 12    <message, or Enter: choose   Back: leave>"`. Keys: the Global Constraints navigation actions of plan 2 (Up/Down rows, Left/Right amount, `menu_accept` act, `menu_back`, `ui_cancel` and `menu` close); the stick through `NavStep`; joypad motion marked handled while open.
- `Game` builds the menu after the skill screen (so it sees input first), binds it, and adds `"altar_menu": func(a): altar_menu.open_for(a)` to the world's ctx outside an editor Play; `_prepare_restart` already unpauses.

- [ ] **Step 1: Write the failing tests.** `test_goddess.gd`: `test_perk_for_finds_a_perk_by_id_and_rules_is_public` (`perk_for("stats")` is the shipped perk with `load_default`; `perk_for("")` and `perk_for("nope")` are null; `rules.bank_rate` is 10). `test_altar.gd`, ported from `tests/test_rebirth_pool.gd` (its builder, attune, announce-once, default-is-harmless and glow tests, on an `Altar` built through `RoomFeatures.make` once Task 4 lands; here call `Altar.new().setup(...)` directly): `test_it_builds_from_data_and_is_interactable` (group `interactable`, `id`, `area`, `perk`); `test_without_a_menu_interacting_attunes_and_says_so_once` (the progress holds it, one announcement, `pool_attuned` emitted); `test_with_a_menu_interacting_opens_it_and_does_not_attune` (a recording Callable gets the altar; not attuned yet); `test_the_prompt_follows_attunement`. `test_altar_menu.gd`: `test_open_for_pauses_and_close_unpauses`; `test_it_refuses_to_open_when_paused_or_the_player_is_dead` (a stub player with `health.is_dead()`); `test_rows_and_footer_read_as_specified` (the Row text strings above on a known model); `test_keys_drive_the_model` (Down to Water, Right twice, Enter banks: points 2; Down five times to the perk row, Enter with 2 points shows `Not enough soul points.`; Back closes and unpauses); `test_the_stick_steps_once_per_push`; `test_joypad_motion_is_handled_while_open`. Restore `Controls.last_stick` and `get_tree().paused` after each test.
- [ ] **Step 2: Run** `tools/run_tests.sh test_goddess.gd`, `altar`, `altar_menu`. Expected: FAIL, `Parse Error` for `Altar`, `AltarMenu` and `perk_for`.
- [ ] **Step 3: Implement** the interfaces above. `Altar` is `RebirthPool` with the `perk` field in place of `kit` and the interaction changed; leave `RebirthPool` in place until Task 4.
- [ ] **Step 4: Run** the same commands, then `tools/run_tests.sh rebirth_pool`. Expected: PASS for all (the old pool object still works).
- [ ] **Step 5: Commit** `git add scripts tests/test_altar.gd* tests/test_altar_menu.gd* tests/test_goddess.gd && git commit -m "feat: Altar, AltarMenu and their wiring"`.

### Task 4: The world swap, `rebirth_pool` to `altar`

**Files:**
- Modify: `data/rooms/C1.tres`, `G1.tres`, `F1.tres`, `D1.tres`; `scripts/world/room_features.gd`, `room_def.gd` (doc line 30), `world_validator.gd` (`FEATURE_KINDS`, `_check_rebirth_pools`, `validate`), `room_lint.gd` (`FEATURE_BOX`, `RULES`, `_pool_clearance`), `rebirth_choice.gd`; `scripts/ui/skill_screen_model.gd` (lines 309 and 310); `scripts/game.gd` (passes the perks to the validator)
- Delete: `scripts/world/rebirth_pool.gd` and its `.uid`
- Test: rename `tests/test_rebirth_pool.gd` to `tests/test_altar_world.gd` (the validator and map tests move there; the builder tests went to `test_altar.gd`); update `test_rebirth_choice.gd`, `test_deep_rooms.gd`, `test_grotto_rooms.gd`, `test_flooded_rooms.gd`, `test_room_lint.gd`

**Interfaces:**
- Produces: the four room files carry `{"area", "id", "kind": "altar", "perk", "pos"}`, `C1` with `"perk": "stats"` and the others `""`, no `kit`. `RoomFeatures.make` builds `"altar"` into an `Altar`. `WorldValidator.validate(rooms, creature_ids = [], perks = null)`: `perks` is an Array of `PerkDef`, and `null` skips the perk checks. `RebirthChoice.altars` entries are `{"id", "area", "room", "pos", "perk", "name"}` (no `kit`) with `name` from `altar_name`. `RoomLint` renames the rule `pool_clearance` to `altar_clearance` (message `... from the altar G1`). `static func Game.world_errors(rooms: Dictionary, creature_ids: Array) -> PackedStringArray` is `WorldValidator.validate` with the shipped perk definitions (`DefLoader.load_dir("res://data/perks", "PerkDef")`): `Game._ready` validates the world before it creates the goddess, so the startup check cannot take the perks from `goddess`. A world with no altar at all still validates (small test worlds have none); the default-altar rule applies once any altar exists, and the shipped-world test pins `C1`.
- Altar checks in `WorldValidator`: the pool checks that exist today (a string `id` and `area`, a Vector2 `pos`, unique ids, the default `C1` present and in the start room) without the `kit` check, plus a string `perk`, an `area` equal to its room's `area` (`altar 'G1' says area 'deep' in a 'grotto' room`), at most one altar per `area` (`area 'x' has two altars`), and, when `perks` is given, a non-empty `perk` names a known perk whose `altar` is that altar's id.

- [ ] **Step 1: Write the failing tests** in `tests/test_altar_world.gd`, from the old validator tests with the new data: `test_the_validator_accepts_a_good_altar` (with the shipped perks); `test_the_validator_names_each_mistake` (a duplicate id, two altars in one area, an altar whose `area` differs from its room's, a perk the data does not hold, a perk whose `altar` is another id, a non-string `perk`, a missing `pos`); `test_malformed_altar_data_is_named_not_a_crash`; `test_game_validates_the_world_with_the_shipped_perks` (`Game.world_errors` on the shipped rooms and creature ids is empty; on a fixture world whose altar names a perk the data lacks it names it; a world with no altar validates); `test_the_default_altar_must_be_in_the_start_room`; `test_a_world_with_altars_must_hold_the_default_one`; `test_the_shipped_world_validates_with_the_shipped_perks` (`C1` holds `stats`, `G1`, `F1` and `D1` hold `""`); `test_the_map_flags_rooms_with_an_altar_and_whether_it_is_attuned` (the `"rebirth"` and `"attuned"` keys, as before); `test_an_old_save_still_starts_the_right_life` (a `WorldProgress` on a Profile holding `rebirths: ["G1"]` and `rebirth_choice: {"pool": "G1", "species": "slime"}` reads `is_attuned("G1")` and `last_choice()["pool"]` `G1`, and `Game.resolve_start` with `{"altar": "G1"}` places the start at G1's room). Update the others: every `kind: "rebirth_pool"` to `"altar"` and every `kit` key dropped from altar fixtures; `test_room_lint.gd` and `test_grotto_rooms.gd` to the `altar_clearance` rule; `test_rebirth_choice.gd` for the new entry shape.
- [ ] **Step 2: Run** `tools/run_tests.sh altar_world`, `rebirth_choice`, `room_lint`, `grotto_rooms`. Expected: FAIL (unknown feature kind `altar`; the rule missing).
- [ ] **Step 3: Implement.** Edit the four room files by hand (each feature dictionary as in Interfaces), the builders, the validator, the lint rename (the `RULES` list, `FEATURE_BOX`, the function, the message and the doc comment), `RebirthChoice.altars`, the map's two lines, and `Game._ready`'s world check, which now calls `Game.world_errors(rooms, _creatures.keys())`. Delete `rebirth_pool.gd`.
- [ ] **Step 4: Run** `tools/run_tests.sh altar_world`, `rebirth_choice`, `room_lint`, `grotto_rooms`, `flooded_rooms`, `deep_rooms`, `world_validator`, `rebirth_progress`, `test_rooms`. Expected: PASS for all. The room editor tests may fail until Task 5; that is expected.
- [ ] **Step 5: Commit** `git add -A scripts data tests && git commit -m "feat: rebirth pools become altars in the data, the validator, the lint and the map"`.

### Task 5: The room editor

**Files:**
- Modify: `scripts/editor/room_edit_model.gd` (`FEATURE_KINDS` line 8, `add_feature` line 522, `get_field` lines 592-595, `set_field` docs and lines 741 and 765-785), `scripts/editor/inspector_panel.gd` (`FIELDS` line 16, `_choices`, the `level` and `skills` widgets at lines 81-84, 177 and 193-195), `scripts/editor/room_view.gd` (line 453), `tools/editor_shots.gd` (line 99)
- Test: `tests/test_room_edit_model.gd`, `test_room_edit_fields.gd`, `test_room_edit_features.gd`, `test_room_editor_scene.gd`

**Interfaces:**
- Produces: `RoomEditModel.FEATURE_KINDS` holds `"altar"`; `add_feature("altar")` creates `{"kind": "altar", "id", "pos", "area": <room area>, "perk": ""}`; `get_field(sel, "perk")` reads it; `set_field(sel, "perk", id)` accepts `""` or a known perk id (`RoomEditModel.perk_ids() -> Array`, from `DefLoader.load_dir("res://data/perks", "PerkDef")`) and refuses anything else with `"'x' is not a perk"`; `kit_level` and `kit_skills` are gone, and asking a non-altar for `perk` is refused (`a switch has no perk`). `InspectorPanel.FIELDS["altar"]` is `[["perk", "Perk", "choice"]]` with the perk ids as the choices. `RoomEditModel.validate()` passes the perk definitions to `WorldValidator.validate`.

- [ ] **Step 1: Write the failing tests** by converting the existing pool tests: `test_an_altar_can_be_added_with_the_rooms_area_and_no_perk`; `test_the_perk_field_accepts_a_known_perk_and_clears_with_empty` (`stats`; `""` removes nothing and stores `""`); `test_the_perk_field_refuses_an_unknown_perk_and_a_non_altar` (the refusal strings above, and nothing pushed to the undo history); `test_the_inspector_offers_none_plus_the_perks_for_an_altar` (the `field_perk` `OptionButton` items are `none` then `stats`; choosing `stats` stores it); `test_the_problems_list_names_an_altar_with_an_unknown_perk`. Drop the `kit_level` and `kit_skills` tests; keep the lint box and the view color tests under the `altar` key.
- [ ] **Step 2: Run** `tools/run_tests.sh room_edit`, `room_editor_scene`. Expected: FAIL.
- [ ] **Step 3: Implement** the interfaces above, deleting the `level` and `skills` widgets and `RebirthKit.skill_defs()` use in the inspector (nothing else uses them: `grep -rn '"level"\|"skills"' scripts/editor` first) and keeping the comment on `set_field` accurate.
- [ ] **Step 4: Run** `tools/run_tests.sh room_edit`, `room_editor_scene`, `editor_play`, `room_view`. Expected: PASS for all.
- [ ] **Step 5: Commit** `git add -A scripts tools tests && git commit -m "feat: the room editor's pool tool becomes the altar tool with a perk choice"`.

### Task 6: `HeadStart.apply`, and the kits go

**Files:**
- Modify: `scripts/soul/head_start.gd` (add `apply`; its header comment names `RebirthKit.apply`), `scripts/game.gd` (`RebirthKit.apply` becomes `HeadStart.apply`; the editor Play still grants its kit through it), `scripts/world/room_lint.gd` (line 45, `hintable_skill_ids`: load and cache its own skill definitions with `DefLoader.load_dir("res://data/skills")` instead of `RebirthKit.skill_defs()`)
- Delete: `scripts/world/rebirth_kit.gd` and its `.uid`
- Test: rename `tests/test_rebirth_kit.gd` to `tests/test_head_start_apply.gd`; update `tests/test_head_start.gd`, `tests/test_rebirth_flow.gd`, `tests/test_player_in_water.gd` (line 45; a player test, not a movement-model test) and `tests/test_room_editor_scene.gd` (lines 341 and 721)

**Interfaces:**
- Produces: `static func HeadStart.apply(player: Player, rules: SkillRulesEngine, compendium: CompendiumModel, kit: Dictionary) -> void`, the body of `RebirthKit.apply` unchanged. `RebirthKit` (`validate`, `skill_defs`, `apply`) no longer exists.

- [ ] **Step 1: Convert the tests.** In the renamed file keep every grant, discovery, starting-level and empty-kit test, calling `HeadStart.apply`; delete the `validate` tests (`test_kit_validation_accepts_good_kits_and_names_bad_ones`, `test_a_kit_may_not_name_an_evolution`) and the four tests that read the shipped pool kits (`test_every_pool_kit_is_valid_and_grants_what_its_row_says`, `test_every_kits_xp_to_the_cap_is_within_the_first_evolution_areas_total`, `test_the_flooded_alone_does_not_fill_an_f1_lifes_first_stage`, `test_no_shipped_pool_carries_a_seeded_affinity`). Add `test_the_largest_head_start_still_leaves_xp_to_the_cap_in_the_first_evolution_areas`: the level `1 + SoulRules.new().level_prices.size()` (5), `need` the sum of `Progression.xp_to_next(l)` from that level to the cap, and `assert_lte(need, areas_total)` with `areas_total` computed as in the deleted test (`ShippedRooms`, `FIRST_EVOLUTION_AREAS`). In `tests/test_head_start.gd` remove the `RebirthKit.validate` loop; in `tests/test_rebirth_flow.gd` and `tests/test_player_in_water.gd:45` call `HeadStart.apply`. In `tests/test_room_editor_scene.gd` use `DefLoader.load_dir("res://data/skills")` for the legal skills at line 341, and replace line 721 with a check that every skill of `RoomEditor.CAVE_MOVEMENT_KIT` is a known skill that is neither an evolution nor enemy-only (the editor Play still grants that kit through `HeadStart.apply`).
- [ ] **Step 2: Run** `tools/run_tests.sh head_start_apply`, `head_start`, `rebirth_flow`. Expected: FAIL (`HeadStart.apply` not declared).
- [ ] **Step 3: Implement** `HeadStart.apply`, switch `Game.begin_life` to it, delete `RebirthKit`, and check `grep -rn RebirthKit scripts tools tests`. Expected: no output.
- [ ] **Step 4: Run** `tools/run_tests.sh head_start_apply`, `head_start`, `rebirth_flow`, `goddess`, `test_game_soul`. Expected: PASS for all.
- [ ] **Step 5: Commit** `git add -A scripts tests && git commit -m "refactor: HeadStart.apply replaces RebirthKit; the pool kits are gone"`.

### Task 7: Through real input, and the docs

**Files:**
- Test: `tests/test_altar_flow.gd`
- Modify: `docs/isekai-chronicles-design-doc.md`, `docs/design-review/index.html`

- [ ] **Step 1: Write the test** `test_banking_and_buying_at_the_cave_altar_gives_the_next_life_the_perk`. Snapshot `Compendium.soul`'s fields (`points`, `perks`, `deaths`, `session_points`), its saved section (`Compendium.profile.dict_section("soul")`) and `get_tree().paused`; at the end restore the fields and write the saved section back (`Compendium.profile.set_section("soul", snapshot)` then `Compendium.profile.save()`), because banking and buying save through the Profile and restoring the fields alone would leave the purchase on disk. Likewise snapshot `Compendium.progress`'s `visited` and `rebirths` arrays and the Profile sections `map`, `rebirths` and `rebirth_choice` (loading the game calls `sanitize()` and `visit()`, which save), restore the arrays and write those sections back with `set_section` and `save()`, and end with `SkillRules.reset_run()` and `Announcer.queue.clear()` as the other game-scene tests do (the next `start_run` clears the shared skill run in any case). Take every snapshot in `before_each` and restore in `after_each`, so a failed assertion cleans up too; in `after_each` free the game scene first (`game.queue_free()`, then await a frame), since GUT frees registered nodes only after `after_each`. Loading the game scene saves Appraisal and Bestiary sightings to the test profile, as every game-scene test in the suite does; `.tmp/gdhome` is scratch and no test assumes those pristine, so this test restores only what it changes on purpose. Load `res://scenes/main.tscn`, wait two physics frames; set `Compendium.soul.points = 0` and `perks = {}`; call `game.begin_life({"default": true, "kit": {}, "species": "slime"})` and note `player.health.max_hp`. Then bind the menu to an isolated engine, so no essence event reaches the real Compendium (absorbed essence unlocks skills, which `CoreWiring` records in `Compendium.model` and saves): `game.altar_menu.bind(game.goddess, engine, Compendium.progress, game.player)` where `engine` is a fresh `SkillRulesEngine` set up with the shipped skill definitions and started (`setup`, `start_run`), with no `CoreWiring`, and `engine.handle_event("absorbed", {"essence": "water", "source": "test"})` 27 times and the same 30 times for `dark`. Read `held` from that `engine`, not from `SkillRules`. Before rebinding, assert `game.altar_menu.engine` is `SkillRules`, which pins that `Game` binds the production engine. Find the `C1` altar in `game.world` (group `interactable`, `id == "C1"`) and call `altar.interact(game.player)`; assert the menu is open and `get_tree().paused`. Push keys through `get_viewport().push_input` with both `keycode` and `physical_keycode` set: Down (Water row), Right twice, Enter (points 2, `held("water")` 7); Down four times (Dark row), Right three times, Enter (points 5); Down (the perk row), Enter (`perk_count("stats")` 1, points 0, the footer says it applies from the next life); Backspace closes the menu and `get_tree().paused` is false. Then `game.begin_life(...)` again: `max_hp` is up 2.
- [ ] **Step 2: Run** `tools/run_tests.sh altar_flow`. Expected: PASS (a FAIL is a wiring bug in Tasks 3 or 4). Then break it on purpose once (comment out the final Enter), see it FAIL, restore it.
- [ ] **Step 3: Docs.** Replace present-tense mentions of rebirth pools and pool kits with altars in `docs/isekai-chronicles-design-doc.md` and `docs/design-review/index.html` (`grep -n -i "rebirth pool\|pool kit"`), keeping the two in step; leave decisions and history as they read.
- [ ] **Step 4: Run the whole suite** `TEST_TIMEOUT=900 tools/run_tests.sh` (the movement agent not running its own). Expected: PASS, no `SCRIPT ERROR`.
- [ ] **Step 5: Commit** `git add -A tests docs && git commit -m "test: banking and buying at an altar through real input; the docs say altars"`.
