# The Opening (soul layer, plan 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A brand-new profile opens with the rigged three-truck dodge, then the goddess's menu with her first words; it plays once.

**Architecture:** `OpeningDef` (data) feeds a pure `OpeningModel`; `OpeningScene` (a paused `CanvasLayer`) drives it from keys and hands off to the existing `GoddessMenu` through a new `Run.open_first_meeting`. `SoulProgress.opening_seen` gates it; `Game` decides, saves the unseen flag before the first map write, and plays it last in `_ready`.

**Tech Stack:** Godot 4.7 / GDScript / GUT 9.7.1. `tools/run_tests.sh [substring]` runs suites at a fixed 60 fps.

**Spec:** `docs/superpowers/specs/2026-10-04-the-opening-design.md` (reviewed: `docs/ledgers/soul-layer-4-spec-review.md`).

## Global Constraints

- The scene is a `CanvasLayer` at layer 45, `PROCESS_MODE_ALWAYS`; `GoddessMenu` stays at layer 40. No skip, no mouse; it marks every key and joypad event handled while playing.
- Saved key: `opening_seen` (bool) in the Profile `soul` section; no key means "seen" iff the profile already holds progress (a non-empty `map`, `compendium` or `bestiary` section). Dev flags `-- --opening` (once per process) and `-- --skip-opening`; headless runs and editor Play never open it.
- Touch nothing under `scripts/movement/`, `data/movement/`, the movement tests or `scripts/player/player.gd` (another agent owns movement). Do not run two full suites at once, and never `pkill` Godot.
- A gameplay script may not name a cue id (`tests/test_audio_boundary.gd`): the event is `opening_hit`, the cue is `opening_impact`. (Superseded: the cue is now `op_crash`; see `docs/ledgers/opening-sound-ledger.md`.) Every emitted `world_event` needs a `data/audio/cues.json` entry, and every mapped event must be emitted (or reserved).
- The runner takes one substring: where a step lists several suites, run each in its own `tools/run_tests.sh <name>` invocation.
- GUT: build `InputEventKey` with `physical_keycode` as well as `keycode`; never await while the tree is paused; restore `Controls.last_stick/using_joypad/last_device/last_pad_name` and `get_tree().paused`; `PackedStringArray` has no `.any`, so assert on `"\n".join(errors)`.
- After creating a `class_name` script run `HOME="$PWD/.tmp/gdhome" godot --headless --import`, and commit its `.uid` file with it. Commit messages carry no attribution lines.

## Review Focus

- A profile with progress (a map, or only migrated compendium or bestiary data) never sees the truck and a brand-new one always does, even after a headless or skipped first launch (Task 3 load rule, Task 5 `wants_opening`, Task 6 two-launch test).
- The opening cannot start over a pause, in an editor Play or in a headless run, and the paused world under it cannot hurt the player (Task 4, Task 5).
- Quitting mid-opening replays it; accepting her menu ends it, and a death afterwards is death 1 (Task 3, Task 5, Task 6).
- A malformed `opening.tres` is named, never a crash, never leaves the game paused or the flag saved (Task 1, Task 5).
- The truck's hit is audible while the tree is paused (Task 4).

Two refinements of the spec, recorded in its text: the generator is its own `tools/build_opening.gd` (re-running `tools/build_soul.gd` would overwrite Sean's edited copy), and the cue is `opening_impact`.

---

### Task 1: The opening's data and its validator

**Files:**
- Create: `scripts/soul/opening_def.gd`, `scripts/soul/opening_validator.gd`, `tools/build_opening.gd`, `data/opening/opening.tres` (generated)
- Test: `tests/test_opening_def.gd`, `tests/test_opening_validator.gd`

**Interfaces:**
- Produces: `class_name OpeningDef extends Resource` with `@export var choices: Array`, `trucks: Array`, `fallback: String`, `goddess_line: String` and `func result_for(truck: int, choice_id: String) -> String` (the truck's `results[choice_id]`, else `fallback`; an out-of-range truck gives `fallback`). `class_name OpeningValidator` with `static func validate(def: OpeningDef) -> PackedStringArray`. Entries: `choices` is `[{"id", "label"}]`, `trucks` is `[{"prompt", "results": {choice_id: line}}]`.

- [ ] **Step 1: Write the failing tests.** `test_opening_def.gd` builds a two-choice, two-truck fixture and asserts `test_result_for_returns_the_trucks_line_else_the_fallback` (a listed id, an id the truck lacks, truck `-1` and truck `5` give the fallback). `test_opening_validator.gd`: `test_a_good_def_validates_clean`; `test_each_mistake_is_named` (one fixture per mistake, asserting `assert_string_contains` on the joined errors: empty `choices`, empty `trucks`, blank and duplicate choice id, blank label, blank prompt, `results` naming an unknown choice, a blank result line, blank `fallback`, blank `goddess_line`); `test_wrong_types_are_named_not_crashed` (a `choices` entry that is an int, a choice id that is an int, a `trucks` entry that is an int, `results` a String, a result an int: every call returns errors and none crashes; the typed `Array` fields cannot hold a non-Array, so that case is Godot's to refuse at load); `test_the_shipped_opening_pins_its_shape` (loads `res://data/opening/opening.tres`: no errors, 3 trucks, choice ids exactly `["dodge", "jump", "pray", "run"]`, a non-blank `goddess_line`, and the twelve result lines distinct).
- [ ] **Step 2: Run** `tools/run_tests.sh opening_def` and `opening_validator`. Expected: FAIL (`OpeningDef` not declared).
- [ ] **Step 3: Implement** `OpeningDef` and `OpeningValidator` (error strings begin `opening: `). Then `tools/build_opening.gd` (`extends SceneTree`, run once like `tools/build_soul.gd`): it builds the def and saves it with `tools/build_soul.gd`'s `_save` helper copied verbatim (the globalized directory, the `ResourceSaver.save` result checked, `quit(1)` on any failure). Copy: choices Dodge, Jump, Pray, Run; three truck prompts ("A truck is coming.", "Another truck is coming.", "Somehow, a third truck."); twelve deadpan result lines, all different, each ending with the truck connecting, flagged in a header comment as placeholder copy for Sean to rewrite; a `fallback` line; `goddess_line` like "I am so sorry. That truck was never meant to be there. Come, let me make it up to you." Import first (the generator names `OpeningDef`, which the global class cache learns only from an import), run `env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_opening.gd`, then import again.
- [ ] **Step 4: Run** the two suites plus `soul_validator`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A scripts tools tests data && git commit -m "feat: the opening's data, its validator and the placeholder copy"`.

### Task 2: `OpeningModel`

**Files:**
- Create: `scripts/soul/opening_model.gd`
- Test: `tests/test_opening_model.gd`

**Interfaces:**
- Consumes: `OpeningDef` (Task 1).
- Produces: `class_name OpeningModel extends RefCounted`; `enum Phase {PROMPT, RESULT, DONE}`; `var phase: Phase`; `_init(p_def: OpeningDef)`; `truck() -> int`; `truck_count() -> int`; `prompt() -> String` ("" once done); `rows() -> Array` (the choice labels in PROMPT, else `[]`); `row() -> int`; `move(step: int) -> void` (PROMPT only, clamped); `act() -> bool` (PROMPT takes the highlighted choice into RESULT; RESULT enters the next truck's PROMPT with the row reset to 0, or DONE after the last; false in DONE); `chosen() -> String` (the choice id taken this truck); `result_line() -> String` (RESULT only, else ""); `done() -> bool`.

- [ ] **Step 1: Write the failing tests** against a fixture def (three trucks, three choices, every line distinct): `test_it_starts_on_the_first_trucks_prompt`; `test_move_clamps_at_both_ends_and_is_ignored_outside_a_prompt`; `test_acting_takes_the_highlighted_choice_and_shows_its_line` (each of the three rows gives `def.result_for(0, id)` on a fresh model); `test_the_next_truck_starts_with_the_row_reset`; `test_the_third_result_ends_it` (`done()`, `prompt() == ""`, `rows() == []`, `result_line() == ""`, `act()` false); `test_it_plays_all_three_trucks_with_different_choices`.
- [ ] **Step 2: Run** `tools/run_tests.sh opening_model`. Expected: FAIL (`OpeningModel` not declared).
- [ ] **Step 3: Implement** `OpeningModel` per the interface; import for the `.uid`.
- [ ] **Step 4: Run** `tools/run_tests.sh opening_model`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A scripts tests && git commit -m "feat: OpeningModel, the three-truck state machine"`.

### Task 3: `SoulProgress.opening_seen`

**Files:**
- Modify: `scripts/soul/soul_progress.gd`, and any existing test that asserts the whole saved `soul` section (`grep -n 'dict_section("soul")' tests`)
- Test: `tests/test_soul_opening.gd`

**Interfaces:**
- Produces: `var opening_seen := false`; `func begin_opening() -> void` (saves, so the section holds the current value explicitly); `func finish_opening() -> void` (sets true, saves). `_save()` always writes `"opening_seen"` beside `points`, `perks` and `deaths`. Load: a saved boolean wins; otherwise `opening_seen` is true when the profile holds progress (a non-empty `map` list, `compendium` dict or `bestiary` dict); with no profile it is false.

- [ ] **Step 1: Write the failing tests** (the scratch-profile helpers of `test_soul_progress.gd`): `test_a_fresh_profile_has_not_seen_the_opening`; `test_a_profile_with_a_map_and_no_flag_counts_as_seen`; `test_a_migrated_profile_with_only_compendium_or_bestiary_progress_counts_as_seen` (each section alone, a non-empty dict, no map); `test_an_explicit_false_wins_over_a_map`; `test_begin_opening_saves_an_explicit_false_and_it_reloads_unseen_even_with_a_map` (call `begin_opening()`, then `profile.set_section("map", ["C1"])`, save, reload: unseen); `test_finish_opening_saves_true_and_reloads_seen`; `test_every_save_carries_the_flag` (`add(1)` on a fresh soul writes `opening_seen == false`); `test_a_malformed_flag_follows_the_map_rule` (`"yes"` with and without a map). Update the existing whole-section assertions to include `"opening_seen"`.
- [ ] **Step 2: Run** `tools/run_tests.sh soul_opening` and `soul_progress`. Expected: FAIL.
- [ ] **Step 3: Implement** in `soul_progress.gd` per the interface (the load rule beside the other fields in `_init`; `_save()` adds the key).
- [ ] **Step 4: Run** `soul_opening`, `soul_progress`, `soul`, `goddess`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A scripts tests && git commit -m "feat: SoulProgress.opening_seen, with old saves counting as seen"`.

### Task 4: `OpeningScene` and the hit cue

**Files:**
- Create: `scripts/ui/opening_scene.gd`, `scripts/ui/opening_stage.gd`
- Modify: `data/audio/cues.json`
- Test: `tests/test_opening_scene.gd`, `tests/test_audio_catalog.gd`

**Interfaces:**
- Consumes: `OpeningDef`, `OpeningModel`, `NavStep`.
- Produces: `class_name OpeningScene extends CanvasLayer` (layer 45, `PROCESS_MODE_ALWAYS`, `visible = false` until played) with `signal finished`, `const APPROACH_SECONDS := 1.0`, `play(def: OpeningDef) -> bool` (false, changing nothing, when the tree is paused or it is playing), `is_playing() -> bool`, `text_lines() -> Array` (the prompt, or the result line), `row_texts() -> Array` ("> " on the highlighted row, two spaces on the others, only in a prompt). `class_name OpeningStage extends Node2D` (child `Stage`): `var approach := 0.0`, `var flash := 0.0`, and a `_draw` of a road strip, a truck (body, cab, wheels, headlight; x from `approach`) and a figure in `draw_rect`/`draw_circle`, so a `CanvasLayer` is not asked to draw.
- Event: each time a truck hits (entering RESULT) it emits `EventBus.world_event.emit("opening_hit", {})`; `cues.json` maps `opening_hit` to a new cue `opening_impact` with `"bus": "UI"`, the `enemy_impact` files, no `positional`.

- [ ] **Step 1: Write the failing tests.** `test_opening_scene.gd` (restore `Controls` pad fields and `paused` in `before_each`/`after_each`; free the scene before restoring): `test_play_pauses_and_shows_the_first_prompt_and_rows`; `test_it_refuses_when_paused_or_already_playing`; `test_keys_walk_the_three_trucks` (Down moves the row, Enter takes it and the text becomes the result line, Enter again shows truck two's prompt; after the third result `finished` fires exactly once, the layer is hidden, `is_playing()` is false and the tree is still paused); `test_the_stick_steps_once_per_push` (as `test_altar_menu.gd`); `test_nothing_behind_it_gets_a_key_while_it_plays` (a probe node with `process_mode = PROCESS_MODE_ALWAYS`, added before the scene, counts `_unhandled_input` events: an `InputEventKey` for Escape and a `menu` `InputEventAction` reach no probe; joypad motion too); `test_each_hit_emits_opening_hit_once` (count the event over three trucks); `test_the_truck_slides_in` (`_process(APPROACH_SECONDS)` takes `Stage.approach` to 1.0). In `test_audio_catalog.gd` add `test_the_opening_hit_cue_is_on_the_ui_bus_and_not_positional` (bus `UI`, no `positional`, the event routes to `opening_impact`).
- [ ] **Step 2: Run** `tools/run_tests.sh opening_scene` and `audio_catalog`. Expected: FAIL.
- [ ] **Step 3: Implement** `OpeningScene` (a black `ColorRect` shade, a `Label` for the text, a `VBoxContainer` of row labels in 12 pt like `AltarMenu`, `Stage` child; `_unhandled_input` marks every `InputEventKey`/`InputEventJoypadButton`/`InputEventJoypadMotion`/`InputEventAction` handled and maps up/down/accept like `AltarMenu`; `_process` steps `NavStep` and advances `approach`/`flash`); `finish` hides the layer, leaves the tree paused and emits `finished`. Add the `cues.json` event and cue. Import.
- [ ] **Step 4: Run** `opening_scene`, `audio`. Expected: PASS (the boundary tests see `opening_hit` emitted and mapped).
- [ ] **Step 5: Commit** `git add -A scripts tests data && git commit -m "feat: OpeningScene, the truck dodge, and its audible hit"`.

### Task 5: The hand-off and `Game`

**Files:**
- Modify: `scripts/run.gd`, `scripts/ui/goddess_menu.gd`, `scripts/game.gd`
- Test: `tests/test_first_meeting.gd`, `tests/test_goddess_menu.gd`, `tests/test_game_opening.gd`, `tests/test_editor_play.gd`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces: `Run.open_first_meeting(line: String) -> bool`: false, nothing happening, with no goddess, no progress, a choice pending, `_ending`, or an empty `model.confirm()`; otherwise it remembers the model, flags the opening and emits `goddess_needed(model, line)` (with no listener it calls `_begin(model.confirm())`). `_begin` calls `goddess.soul.finish_opening()` when flagged. `GoddessMenu._init` sets `process_mode = Node.PROCESS_MODE_ALWAYS`. On `Game`: `const OPENING_PATH`, `static var launch_override := {}` (tests set its `args` and `headless` keys; `_ready` clears it), `static var opening_flag_used := false`, `static func wants_opening(soul: SoulProgress, args: Array, headless: bool, editor_play: bool, flag_used := false) -> bool` (checked in this order: editor play false; `--skip-opening` false; a headless run false, so even `--opening` cannot start an opening nobody can advance; `--opening` true unless `flag_used`; else `not soul.opening_seen`), `static func load_opening(path := OPENING_PATH) -> OpeningDef` (null, after a `push_error` naming the path and the reason, on a failed load, a loaded resource that is not an `OpeningDef` (checked with `is` before the validator ever sees it), or any validator error), `var opening: OpeningScene`, `func start_opening(def: OpeningDef = null) -> bool` (false in an editor Play; loads via `load_opening` when `def` is null; null returns false; else returns `opening.play(def)`; on `finished` it calls `run.open_first_meeting(def.goddess_line)` and unpauses if that is false).

- [ ] **Step 1: Write the failing tests.** `test_first_meeting.gd` (a `Goddess` fixture as in `test_goddess_flow.gd`, a `WorldProgress.new()`, a `Run` bound with no real player): `test_it_opens_her_menu_with_the_line_and_counts_no_death` (`goddess_needed` once with the line; `soul.deaths` stays 0); `test_accepting_it_begins_the_cave_altar_life_and_marks_the_opening_seen` (`accept(model.confirm())` gives one `restart_requested`, `progress.pending_start == {"altar": "C1", "species": "slime", "kit": {}}`, `soul.opening_seen`); `test_it_refuses_in_every_guarded_case` (no goddess, no progress, called twice, mid-death via a `Mortal` `died` signal, a goddess with an empty species catalog); `test_with_no_listener_it_begins_directly`. `test_goddess_menu.gd`: `test_the_menu_works_over_a_paused_tree` (process mode ALWAYS; paused, push Enter, `confirmed` fires; unpause). `test_game_opening.gd`: `test_wants_opening_follows_flags_and_the_saved_flag` (editor play, `--skip-opening` beating `--opening`, `--opening` on a seen profile, `--opening` while headless is false, `flag_used`, headless, an unseen windowed profile, a seen windowed one); `test_load_opening_returns_the_shipped_def`; `test_a_malformed_opening_is_refused_and_named` (save a def with a String `results` under `user://`, and a second resource of another type, a `SoulRules`, under `user://`; each gets `assert_push_error` naming the path, null returned, tree not paused; delete the files); `test_start_opening_refuses_over_a_pause` (paused, `play` false, `soul.opening_seen` and the pause untouched); in `test_editor_play.gd`, `test_start_opening_refuses_in_an_editor_play` (a game loaded from a play request: `start_opening()` is false and the tree is not paused).
- [ ] **Step 2: Run** `tools/run_tests.sh first_meeting`, `goddess_menu`, `game_opening`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `Game._ready`, straight after `_editor_play` is known and before `world.setup`: `launch := Game.launch_override` (cleared at once), `args := launch.get("args", OS.get_cmdline_user_args())`, `headless := launch.get("headless", DisplayServer.get_name() == "headless")`, `wanted := Game.wants_opening(Compendium.soul, args, headless, _editor_play, Game.opening_flag_used)`; if `wanted` and `args` holds `--opening` set `Game.opening_flag_used`; when not in an editor Play and (`wanted` or `not Compendium.soul.opening_seen`) then `opening_def = Game.load_opening()` and, with a def and `not Compendium.soul.opening_seen`, `Compendium.soul.begin_opening()` whether or not it is wanted (a comment says why: the first room's map save would otherwise make an unplayed profile look old); `start_opening` at the end runs only when `wanted`. Add the `OpeningScene` child last in `_ready` (after the altar menu), and at the very end `if wanted and opening_def != null: start_opening(opening_def)`. `Run.open_first_meeting` and `_begin`'s flag as specified; `GoddessMenu` process mode. Import.
- [ ] **Step 4: Run** `first_meeting`, `goddess`, `game_opening`, `test_run`, `rebirth_flow`, `game_soul`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A scripts tests && git commit -m "feat: the first meeting and the game's opening wiring"`.

### Task 6: Through real input, and the docs

**Files:**
- Test: `tests/test_opening_flow.gd`
- Modify: `docs/isekai-chronicles-design-doc.md`, `docs/design-review/index.html`, `docs/playtest-checklist.md`

- [ ] **Step 1: Write the test** `test_a_new_profile_plays_the_trucks_then_meets_her_and_begins_the_first_life`, plus `test_a_forced_replay_of_a_seen_profile_keeps_it_seen`. Snapshot in `before_each` (restore in `after_each`, freeing the game scene first, as `test_altar_flow.gd` does): `Compendium.soul` fields and `profile.dict_section("soul")`, `Compendium.progress.visited/rebirths/pending_start/last_choice`, the Profile `map`, `rebirths` and `rebirth_choice` sections, `get_tree().paused`, `Game.opening_flag_used`; write the sections back with `set_section` and `save()`. First test: `soul.opening_seen = false`, `Game.launch_override = {"headless": false}` (the real decision for a windowed launch of an unseen profile), load `res://scenes/main.tscn`, wait two physics frames; assert the opening is playing and the tree paused, and that a fresh `Profile` read of `user://profile.json` holds an explicit `soul.opening_seen == false` (the unseen flag reached disk before the map). Replace `game.run.restart_requested`'s `game._restart` with a handler that counts and calls `game._prepare_restart()` (the real restart's cleanup, including the unpause, minus the scene reload; without it the tree stays paused and the timed death below never advances). While the first prompt shows, push the `menu` action and assert `game.skill_screen.visible` is false and the opening is still playing. Pin the state a prior run may have left (snapshot and restore it, as `test_goddess_flow.gd` does): `Compendium.progress.set_last_choice("C1", "slime")`, `pending_start = {}`, `Compendium.soul.deaths = 0`. Push keys with `keycode` and `physical_keycode`, one truck at a time: truck 1 Enter (Dodge) then Enter on its result; truck 2 Down, Enter (Jump), Enter; truck 3 Down twice, Enter (Pray), Enter; then assert the opening layer is hidden, `goddess_menu.is_open()`, `goddess_menu.line_text()` equals the def's `goddess_line`, Enter, the counter is 1, `pending_start == {"altar": "C1", "species": "slime", "kit": {}}`, `soul.opening_seen` and a re-read profile says true, `soul.deaths == 0`, and a later `game.player.receive_hit(9999, "physical", Vector2.INF, "bat")` reads as death 1 after `Run.DEATH_CARD_SECONDS`. Second test: `opening_seen = true`, `Game.launch_override = {"headless": false, "args": ["--opening"]}`, `Game.opening_flag_used = false`, load: playing, and the on-disk flag is still true before the end; finishing keeps true. Third, `test_a_headless_first_launch_leaves_a_fresh_profile_unseen`: with `opening_seen = false` and no override (the runner is headless, so it does not want the opening), load the scene, wait, and assert a fresh `Profile` read of `user://profile.json` holds an explicit `soul.opening_seen == false` while its `map` is non-empty, and that `SoulProgress.new(that profile, [])` reloads unseen. Fourth, `test_a_skipped_first_launch_leaves_a_fresh_profile_unseen`: `launch_override = {"headless": false, "args": ["--skip-opening"]}`, an unseen profile: the opening is not playing and the same explicit `false` is on disk.
- [ ] **Step 2: Run** `tools/run_tests.sh opening_flow`. Expected: PASS (FAIL means a wiring bug in Task 4 or 5). Then comment out the last Enter, see it FAIL, restore it.
- [ ] **Step 3: Docs.** The design doc's "Opening sequence" section and its checklist line say what is built (placeholder copy, the dev flags, old saves count as seen); `docs/design-review/index.html` likewise, and its "In the game today" soul list; `docs/playtest-checklist.md` gains a first-launch item (fresh profile or `-- --opening`: black screen, three trucks, every choice fails, her first words, one confirm, then the Cave; relaunch skips it; `-- --skip-opening`). Keep the doc and the page in step.
- [ ] **Step 4: Run the whole suite** `TEST_TIMEOUT=900 tools/run_tests.sh`. Expected: PASS, no `SCRIPT ERROR`.
- [ ] **Step 5: Commit** `git add -A tests docs && git commit -m "test: the opening through real input; the docs say what is built"`.
