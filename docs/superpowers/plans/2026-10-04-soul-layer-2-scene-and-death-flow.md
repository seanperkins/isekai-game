# Soul Layer 2: The Scene and the Death Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dying opens the goddess's scene: her line for what killed you on the death card, then one menu to pick where, who and a head start, and the next life starts exactly so. Replaces `ReincarnationMenu` and the pool-choice flow.

**Architecture:** `Player` records the cause of its last hit; `Goddess` (new, pure) bundles the soul inputs and builds plan 1's `GoddessModel` and her line; `GoddessMenu` (new `CanvasLayer`) draws and drives the model; `Run` and `Game` swap the old choice flow for it. Places are still the four pools until plan 3.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1. Plan 1 (`scripts/soul/`, `data/soul|species|perks|goddess/`) is on `main`.

**Spec:** `docs/superpowers/specs/2026-10-04-soul-layer-design.md`. Execute in this worktree (`.worktrees/soul-scene`, branch `feat/soul-scene`, cut from `main`).

## Global Constraints

- Menu layer 40 (above the death card at 30 and the skill screen at 20); death card `Run.DEATH_CARD_SECONDS` 1.5 (existing). Virtual screen 640x360, font size 12.
- Controls: Up/Down (`ui_up`/`aim_up`, `ui_down`/`aim_down`) move the row; `tab_prev`/`tab_next` (Q/E, shoulders) switch panel; Left/Right (`move_left`/`ui_left`, `move_right`/`ui_right`) adjust the head start; `menu_accept`/`ui_accept` (Enter, A) is "be reborn". The left stick goes through `NavStep`. No mouse.
- `--soul=N`: an integer 0 to 9999, anything else reads 0, larger clamps; `Game._ready` sets (never adds to) `Compendium.soul.session_points`, outside an editor Play.
- `pending_start` and the saved choice keep the key `pool` for the altar id until plan 3 renames pools: `{"pool", "species", "kit"}`.
- Pool kits stay in the room files and are ignored (the world validator still requires them). `RebirthChoice.pools` stays; only `decide`, `accept` and `LOCKED_NAME` go.
- Never edit `scripts/movement/`, `data/movement/`, the movement tests, `room_lint.gd` or `world_validator.gd`. `player.gd` gets one variable and one assignment, nothing else; tell Sean before Task 2 so the movement agent knows.
- Tests that touch `Compendium.soul` or `Compendium.progress` set known values first and restore them after. After creating a `.gd` with a `class_name`, run `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and commit its `.uid`. No attribution lines in commits, no estimates.

## Review Focus

- A death with no goddess, or with nothing listening for the menu, must still restart: the game never hangs (Task 5).
- A purchase the soul points cannot pay for is never given, and the cost is spent once (Task 5).
- The left stick must not step twice per push, and joypad motion must not reach the world while the menu is open (Task 4).
- `last_hit_cause` is set before `died` fires, and a hit blocked by invulnerability does not overwrite it (Task 2).
- One death is counted and given one line even if `died` fires twice (Task 5).

### Task 1: `NavStep`

**Files:**
- Create: `scripts/ui/nav_step.gd`
- Modify: `scripts/ui/skill_screen.gd` (the `NAV_*` constants at 45-48, `_nav_dir` and `_nav_timer`, `nav_step` at 285, `_process` at 302)
- Test: `tests/test_nav_step.gd`; regression `tests/test_menu_input.gd`

**Interfaces:**
- Produces: `NavStep` (`RefCounted`): `const THRESHOLD := 0.5`, `DELAY := 0.35`, `REPEAT := 0.12`; `func step(stick: Vector2, delta: float) -> Vector2i` (the dominant axis past the threshold as a four-way direction, edge-triggered, then repeating while held); `func reset() -> void`.

- [ ] **Step 1: Write the failing tests** in `tests/test_nav_step.gd`, mirroring `tests/test_menu_input.gd` lines 60-79 on a `NavStep.new()`: `test_a_push_steps_once_then_repeats_after_the_delay` (down `Vector2(0, 0.8)` gives `Vector2i.DOWN`, held 0.016 and 0.2 give ZERO, a further 0.2 gives DOWN, then 0.05 ZERO and 0.1 DOWN, a release gives ZERO, up gives UP); `test_the_dominant_axis_wins_and_a_small_push_is_ignored` (`Vector2(0.9, 0.3)` is RIGHT, `Vector2(0.3, -0.9)` is UP, `Vector2(0.3, 0.3)` is ZERO, each after a release); `test_reset_makes_the_next_push_a_fresh_edge` (push, `reset()`, push again gives a step).
- [ ] **Step 2: Run** `tools/run_tests.sh nav_step`. Expected: FAIL, `Parse Error` for `NavStep`.
- [ ] **Step 3: Implement** `NavStep` by moving the body of `SkillScreen.nav_step` into `step`, with its own `_dir` and `_timer`. In `SkillScreen`: delete the `NAV_*` constants and the two variables, add `var _nav := NavStep.new()`, make `nav_step(stick, delta)` return `_nav.step(stick, delta)`, and replace `_nav_dir = Vector2i.ZERO` in `_process` with `_nav.reset()`.
- [ ] **Step 4: Run** `tools/run_tests.sh nav_step`, then `tools/run_tests.sh menu_input`, then `tools/run_tests.sh skill_screen`. Expected: PASS for all.
- [ ] **Step 5: Commit** `git add scripts/ui tests/test_nav_step.gd* && git commit -m "refactor: NavStep, the stick's repeat logic, extracted from SkillScreen"`.

### Task 2: The cause of the player's last hit

**Files:**
- Modify: `scripts/player/player.gd` (`receive_hit` at 743), `scripts/enemies/enemy.gd` (contact at 329, `_slam` at 618), `scripts/enemies/spear.gd` (`_hit` at 19)
- Test: `tests/test_player_death_cause.gd` (not `test_death_cause.gd`, which is the creatures' death effects)

**Interfaces:**
- Produces: `Player.last_hit_cause: String`, set by `receive_hit(raw, damage_type, from, cause)` to `cause`, or to `damage_type` when `cause` is empty. Contact and the drake's slam pass `def.id`; the spear passes `"spear"`; `receive_poison` already reaches `receive_hit(application, "poison")`.

- [ ] **Step 1: Write the failing tests.** A `CauseStub` (`Node2D`, `team := "player"`, `facing := 1`, `func is_on_floor() -> bool: return true`, and `receive_hit(raw, damage_type, _from := Vector2.INF, cause := "")` appending `[raw, damage_type, cause]` to `hits`), added to group `player`, and a real `Player` built as in `tests/test_soul_perks.gd`. Tests: `test_the_cause_is_recorded` (`receive_hit(3, "physical", Vector2.INF, "bat")` sets `last_hit_cause` to `bat`); `test_no_cause_falls_back_to_the_damage_type` (`receive_hit(3, "poison")` gives `poison`); `test_a_hit_blocked_by_invulnerability_keeps_the_earlier_cause` (hit with `bat`, then at once with `spear`: still `bat`); `test_the_cause_is_set_before_died_fires` (connect `died` to a lambda recording `last_hit_cause`, take a lethal hit with cause `spear`, the recorded value is `spear`); `test_contact_names_the_creature` (an `Enemy` for `bat` at `Vector2.ZERO` as in `tests/test_enemy_ai.gd:48`, stub at `Vector2(4, 0)`, two physics frames, `hits[0][2]` is `bat`); `test_the_drake_slam_names_the_drake` (an `Enemy` for `stone_drake` with physics off, stub at `Vector2.ZERO`, `enemy._slam(stub)`, `hits[0][2]` is `stone_drake`); `test_the_spear_names_itself` (`Spear.new()`, `_hit(stub)`, `hits[0][2]` is `spear`).
- [ ] **Step 2: Run** `tools/run_tests.sh player_death_cause`. Expected: FAIL (`last_hit_cause` not declared; the stub's `hits[0][2]` empty).
- [ ] **Step 3: Implement.** In `player.gd` add `var last_hit_cause := ""`, rename the `_cause` parameter to `cause`, and assign `last_hit_cause = cause if cause != "" else damage_type` after the invulnerable-or-dead early return and before the `health.take_hit` line (that call fires `died`). Pass `def.id` as the fourth argument at the two `enemy.gd` sites and `"spear"` in `spear.gd`.
- [ ] **Step 4: Run** `tools/run_tests.sh player_death_cause`, then `tools/run_tests.sh enemy_ai`, `spear`, `death_cause`. Expected: PASS for all.
- [ ] **Step 5: Commit** `git add scripts/player/player.gd scripts/enemies tests/test_player_death_cause.gd* && git commit -m "feat: the player records the cause of its last hit"`.

### Task 3: `Goddess`

**Files:**
- Create: `scripts/soul/goddess.gd`
- Test: `tests/test_goddess.gd`

**Interfaces:**
- Consumes: `GoddessModel`, `HeadStart`, `SpeciesCatalog`, `SoulProgress`, `SoulRules`, `GoddessLines`, `PerkDef` (plan 1); `RebirthChoice.pools` entries `{"id", "name", ...}`; `WorldProgress.is_attuned`, `last_choice`; `CompendiumModel.bestiary_ids`, `creature_record`, `skill_name`.
- Produces: `Goddess` (`RefCounted`): `var soul: SoulProgress`, `var perks: Array`; `_init(p_soul: SoulProgress, p_rules: SoulRules, p_lines: GoddessLines, p_catalog: Dictionary, p_perks: Array, p_compendium: CompendiumModel, p_skill_defs: Array)`; `static func load_default(soul, compendium, skill_defs) -> Goddess` (rules from `res://data/soul/soul_rules.tres`, lines from `res://data/goddess/lines.tres`, `SpeciesCatalog.load_all()`, `DefLoader.load_dir("res://data/perks", "PerkDef")`); `func line_for_death(cause: String) -> String` (calls `soul.note_death()` first, then `lines.line_for(cause, soul.deaths, rules.many_deaths)`); `func model(progress: WorldProgress, pools: Array) -> GoddessModel`.

- [ ] **Step 1: Write the failing tests** with a `_goddess(points := 0)` fixture (in-memory `SoulProgress` with `points` set, default `SoulRules`, lines `{"bat": ["b0", "b1"]}` with `many_deaths ["m0"]` and `fallback "f"`, a catalog of `slime` (default) and `wolf` (`defeat` of `gloom_wolf`), no perks, a `CompendiumModel` from the shipped skill and creature defs) and pools as in `tests/test_rebirth_flow.gd` `_pools()`. Tests: `test_places_are_the_attuned_pools_default_first` (default only gives `["C1"]`; after `progress.attune("G1")` gives `["C1", "G1"]` named `Cave mouth` and `Grotto rebirth pool`; an empty `pools` gives the default `C1`); `test_species_follow_the_bestiary` (only `slime`; after `compendium.on_creature_defeated("gloom_wolf")` the model offers `slime` then `wolf`); `test_powers_are_the_owned_once_ones_with_their_names` (raise `leap` to `OWNED_ONCE`, the Head start panel has a row named as `compendium.skill_name("leap")`); `test_the_last_choice_is_preselected` (attune `G1`, `set_last_choice("G1")`, `selected_place()` is `G1`); `test_line_for_death_counts_the_death_first` (cause `bat`: the first call returns `b1` and `soul.deaths` is 1; the second returns `b0`; the fifth returns `m0`; an unknown cause returns `f`); `test_load_default_reads_the_shipped_data` (`Goddess.load_default(SoulProgress.new(), compendium, skills)` has the `stats` perk in `perks` and `line_for_death("bat")` is a non-empty string).
- [ ] **Step 2: Run** `tools/run_tests.sh test_goddess.gd`. Expected: FAIL, `Parse Error` for `Goddess`.
- [ ] **Step 3: Implement** `Goddess`. `model` builds `places` from the attuned pools (`[{"id", "name"}]`, falling back to `[{"id": WorldProgress.DEFAULT_POOL, "name": "Cave mouth"}]` when none), `species` from `SpeciesCatalog.unlocked(catalog, records)` with `records` taken from `compendium.creature_record` over `compendium.bestiary_ids()`, `powers` from `HeadStart.eligible_powers(compendium, skill_defs)` as `[{"id", "name": compendium.skill_name(id)}]`, then `GoddessModel.new(places, species, powers, soul, rules, progress.last_choice())`.
- [ ] **Step 4: Run** `tools/run_tests.sh test_goddess.gd`. Expected: PASS (the file filter keeps it from matching `test_goddess_lines` and `test_goddess_model`).
- [ ] **Step 5: Commit** `git add scripts/soul/goddess.gd* tests/test_goddess.gd* && git commit -m "feat: Goddess builds her scene model and her line for a death"`.

### Task 4: `GoddessMenu`

**Files:**
- Create: `scripts/ui/goddess_menu.gd`
- Test: `tests/test_goddess_menu.gd`

**Interfaces:**
- Consumes: `GoddessModel` and its `Pane` enum (plan 1), `NavStep` (Task 1), `Controls.last_stick`.
- Produces: `GoddessMenu` (`CanvasLayer`, layer 40, hidden until opened): `signal confirmed(result: Dictionary)`; `open(model: GoddessModel, line: String) -> void`; `is_open() -> bool`; `move(step: int)`, `switch_panel(step: int)`, `adjust(step: int)` (each acts on the model and redraws); `confirm() -> bool` (false when the model's `confirm()` is empty; otherwise closes, emits `confirmed` with the result and returns true); `line_text() -> String`; `header(pane: int) -> String` (`WHERE`, `WHO`, `HEAD START`, in square brackets for the current pane); `panel_rows(pane: int) -> Array`; `footer_text() -> String`.
- Row text: a highlighted row starts `"> "`, others two spaces. Where and Who rows are the names. Head start: `"> Level +0  next 2"` (`"max"` in place of `next N` at the cap) and `"  [ ] Leap  3"` (`[x]` when taken). Footer: `"Soul points 12    Cost 2    Enter: be reborn"`, ending `"Not enough soul points"` instead of the Enter hint when the cost is above the points.

- [ ] **Step 1: Write the failing tests** with a model of places `C1` and `G1`, species `slime`, power `leap` (as `tests/test_goddess_model.gd`) and 12 soul points. Tests: `test_it_does_nothing_until_opened` (not open; `confirm()` false; `move(1)` leaves the model alone); `test_open_shows_her_line_and_the_panels` (`line_text()` is the given line; `panel_rows(P.WHERE)` is `["> Cave mouth", "  Grotto"]`; `header(P.WHERE)` is `[WHERE]` and `header(P.WHO)` is `WHO`); `test_keys_drive_the_model` (push key events through `_unhandled_input`: `KEY_DOWN` moves the Where row, `KEY_Q` wraps to Head start so `header(P.HEAD_START)` is bracketed, `KEY_RIGHT` buys a level so `panel_rows(P.HEAD_START)[0]` is `"> Level +1  next 3"` and the footer shows `Cost 2`, `KEY_LEFT` undoes it); `test_a_purchase_beyond_the_points_is_refused` (4 points, three levels bought: `confirm()` false, the menu stays open, the footer ends `Not enough soul points`); `test_confirm_closes_and_emits_the_result` (default cart: `confirm()` true, `is_open()` false, one `confirmed` carrying `{"altar": "C1", "species": "slime", "kit": {}, "cost": 0}`); `test_the_stick_steps_once_per_push` (set `Controls.last_stick = Vector2(0, 0.9)`, call `_process(0.016)` twice: one row moved; restore `Controls.last_stick` after); `test_joypad_motion_is_swallowed_while_open_and_ignored_when_closed` (an `InputEventJoypadMotion` pushed to an open menu is handled and moves nothing).
- [ ] **Step 2: Run** `tools/run_tests.sh goddess_menu`. Expected: FAIL, `Parse Error` for `GoddessMenu`.
- [ ] **Step 3: Implement** `GoddessMenu`. Layout: a shade `ColorRect` (0, 0, 0.05, 0.9) over 640x360; her line in a centered, wrapped `Label` at (40, 24) size (560, 40); three panels at x 32, 232 and 432, y 84, size (176, 200), each a header `Label` over a column of row `Label`s; the footer centered at (40, 318). `_unhandled_input` follows the Global Constraints actions and ignores `InputEventJoypadMotion` except to mark it handled while open; `_process` reads `NavStep.step(Controls.last_stick, delta)` while open (`y` moves, `x` adjusts) and resets the `NavStep` while closed. Colors as `ReincarnationMenu` (light blue text, `Color(0.75, 0.9, 1.0)`).
- [ ] **Step 4: Run** `tools/run_tests.sh goddess_menu`. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/ui/goddess_menu.gd* tests/test_goddess_menu.gd* && git commit -m "feat: GoddessMenu, the three-panel rebirth scene"`.

### Task 5: The death flow

**Files:**
- Modify: `scripts/run.gd`, `scripts/game.gd` (`_ready` 37-102, `begin_life` 106, `resolve_start` 158), `scripts/world/rebirth_choice.gd` (remove `decide`, `accept`, `LOCKED_NAME`)
- Delete: `scripts/ui/reincarnation_menu.gd` and its `.uid`, `tests/test_reincarnation_menu.gd` and its `.uid`
- Test: rewrite the first seven tests and update the `resolve_start` tests in `tests/test_rebirth_flow.gd`; trim `tests/test_rebirth_choice.gd` to its two `pools` tests (lines 10-29); edit `tests/test_editor_play.gd:76`; create `tests/test_game_soul.gd`

**Interfaces:**
- Consumes: `Goddess`, `GoddessModel.confirm`/`need_menu` (Tasks 3 and plan 1), `GoddessMenu` (Task 4), `SoulPerks.apply` (plan 1), `Player.last_hit_cause` (Task 2).
- Produces: `Run.goddess: Goddess`; `Run.bind(player, world, progress = null, pools = [], p_goddess = null)`; `signal goddess_needed(model: GoddessModel, line: String)`; `Run.accept(result: Dictionary)`; `Run.line_text() -> String`. `Run.choice_needed` and `Run.choose` are gone. `Game.goddess: Goddess`, `Game.goddess_menu: GoddessMenu`, `static Game.soul_points_arg(args: Array) -> int`. `Game.resolve_start` returns `{"default", "kit", "species"}` plus `room`, `pos` and `pool` for an altar; `kit` and `species` come from `pending` (a non-Dictionary kit or non-String species falls back to `{}` and `"slime"`), never from the pool.

- [ ] **Step 1: Write the failing tests.** In `tests/test_rebirth_flow.gd` the `Mortal` stub gains `var last_hit_cause := ""`, `_run(progress, pools, goddess := null)` binds the goddess, and a `_goddess(points := 0)` fixture as in Task 3. New tests replace the seven choice tests: `test_with_nothing_to_choose_death_restarts_directly_and_records_the_start` (0 points, only `C1`: one restart, `pending_start` is `{"pool": "C1", "species": "slime", "kit": {}}`, no `goddess_needed`); `test_the_card_shows_her_line_for_the_cause_and_counts_one_death` (cause `bat`: `line_text()` is `b1`, `soul.deaths` 1, a second `died.emit()` changes neither); `test_a_second_altar_asks_and_waits` (attune `G1`, last choice `G1`: one `goddess_needed` whose model selects `G1`, no restart until `accept(model.confirm())`, then one restart and `pending_start["pool"]` is `G1`); `test_points_to_spend_open_the_menu_even_with_one_altar` (5 points); `test_accept_spends_the_cost_and_carries_the_kit` (9 points, three levels bought on the model, `accept` leaves 0 points and `pending_start["kit"]` is `{"level": 4}`); `test_a_purchase_the_points_cannot_pay_is_not_given` (`accept({"altar": "C1", "species": "slime", "kit": {"level": 9}, "cost": 99})` with 5 points: the kit is `{}` and the points are untouched); `test_a_choice_is_taken_once_and_an_empty_one_is_ignored` (a second `accept`, `accept({})` and `accept` with nothing pending do nothing); `test_with_no_menu_listening_the_default_is_taken` (5 points, no listener: one restart, points unchanged); `test_without_a_goddess_the_last_attuned_choice_is_taken` (no goddess, `G1` attuned and last: `pending_start["pool"]` is `G1`, kit `{}`). Keep `test_a_run_bound_without_progress_behaves_as_before`. Update the `resolve_start` tests: the default result is `{"default": true, "kit": {}, "species": "slime"}`; an attuned pool starts at its room and spot with the kit and species from `pending` (`{"pool": "G1", "species": "slime", "kit": {"skills": ["leap"], "level": 3}}`), not the pool's own kit; an unknown or unattuned pool falls back to the default location and still carries the kit. `tests/test_game_soul.gd` (snapshot and restore `Compendium.soul.points`, `perks`, `deaths`, `session_points`): `test_soul_points_arg` (`["--soul=5"]` is 5, `["--soul=-3"]` 0, `["--soul=x"]` 0, `["--soul=99999"]` 9999, `[]` 0, `["--evolve", "--soul=7"]` 7); `test_begin_life_applies_bought_perks_after_the_kit` (load the game scene; set `Compendium.soul.perks = {}`, call `game.begin_life({"default": true, "kit": {}, "species": "slime"})` and note `player.health.max_hp`; set `perks = {"stats": 1}`, call `begin_life` again: `max_hp` is up 2); `test_game_ready_sets_session_points_rather_than_adding` (set `Compendium.soul.session_points = 5`, load the scene: it is 0, since the flag is absent and `_ready` sets rather than adds). In `tests/test_editor_play.gd:76` connect `game.run.goddess_needed` (a three-argument lambda) instead of `choice_needed`.
- [ ] **Step 2: Run** `tools/run_tests.sh rebirth_flow`, `test_game_soul`, `rebirth_choice`. Expected: FAIL (`Parse Error`: `Run.bind` takes four arguments, no `accept`, `soul_points_arg` missing).
- [ ] **Step 3: Implement `Run`.** Keep `_ending`, the card and `death_card_visible`; keep the label as `_card_label`. On death read the cause with `player.get("last_hit_cause")` (a non-String reads as `""`), set `_line` from `goddess.line_for_death(cause)` when a goddess is bound and show it on the card (the old "You dissolve." text when none). After the card, `_resolve`: no progress restarts as before; otherwise with a goddess `var model := goddess.model(_progress, _pools)`; when `model.need_menu()` is false, or nothing is connected to `goddess_needed`, or `model.confirm()` is empty, call `_begin(model.confirm())`; else keep `_model` and emit `goddess_needed(model, _line)`. With no goddess, `_begin` the last choice's altar if attuned (else `C1`) with an empty kit. `accept(result)` ignores an empty result or no pending `_model`, clears `_model`, then `_begin(result)`. `_begin(result)` reads `altar`, `species`, `kit`, `cost` with the defaults `C1`, `slime`, `{}`, 0; when `cost > 0` and `goddess.soul.spend(cost)` fails (or there is no goddess) the kit becomes `{}`; then it sets `pending_start = {"pool": altar, "species": species, "kit": kit}`, calls `set_last_choice(altar, species)` and emits `restart_requested`. Remove `choice_needed`, `choose`, `_decision`.
- [ ] **Step 4: Implement `Game`.** In `_ready`: `goddess = null if _editor_play else Goddess.load_default(Compendium.soul, Compendium.model, SkillRules.skill_defs)`; `run.bind(player, world, null if _editor_play else Compendium.progress, pools, goddess)`; replace the `ReincarnationMenu` lines with `goddess_menu = GoddessMenu.new()`, `add_child`, `run.goddess_needed.connect(goddess_menu.open)`, `goddess_menu.confirmed.connect(run.accept)`; and outside an editor Play `Compendium.soul.session_points = Game.soul_points_arg(OS.get_cmdline_user_args())`. `begin_life` applies the kit as now, then, when `goddess != null`, `SoulPerks.apply(player, Compendium.soul, goddess.perks)`. `soul_points_arg` scans for the first `--soul=` argument (`is_valid_int`, clamp 0..9999). `resolve_start` returns `kit` and `species` from `pending` as in Interfaces. Delete `ReincarnationMenu` and its test, and remove `decide`, `accept` and `LOCKED_NAME` from `RebirthChoice` with their tests.
- [ ] **Step 5: Run** `tools/run_tests.sh rebirth_flow`, `test_game_soul`, `rebirth_choice`, `test_run`, `editor_play`, `rebirth_progress`, `goddess`. Expected: PASS for all.
- [ ] **Step 6: Commit** `git add -A scripts tests && git commit -m "feat: dying opens the goddess's scene; the pool choice menu is gone"`.

### Task 6: Through real input, in the real scene

**Files:**
- Test: `tests/test_goddess_flow.gd`

**Interfaces:**
- Consumes: everything above; `Game.goddess_menu`, `Run.goddess` (assignable), `Game.resolve_start`, `Game.begin_life`.

- [ ] **Step 1: Write the test** `test_dying_buys_a_head_start_and_the_next_life_has_it`. Load `res://scenes/main.tscn`, wait two physics frames. Give `game.run.goddess` a fixture `Goddess` (in-memory `SoulProgress` with 20 points, shipped rules and lines, `SpeciesCatalog.load_all()`, no perks, a fresh `CompendiumModel` with `leap` raised to `OWNED_ONCE`). Snapshot `Compendium.progress.last_choice()` and clear `pending_start`; disconnect `game.run.restart_requested` from `game._restart` and count restarts instead (a real restart would reload the test runner's scene). Kill the player with `game.player.receive_hit(9999, "physical", Vector2.INF, "bat")`, wait `Run.DEATH_CARD_SECONDS + 0.3`. Assert `game.goddess_menu.is_open()` and `line_text()` equals the fixture's line for `bat`. Push key events through `get_viewport().push_input` (as `tests/test_editor_play.gd` `_key`): `KEY_Q` (to Head start), `KEY_RIGHT` twice (two levels), `KEY_DOWN` (the power row), `KEY_RIGHT` (take `leap`), `KEY_ENTER`. Assert one restart, `Compendium.progress.pending_start` equals `{"pool": "C1", "species": "slime", "kit": {"skills": ["leap"], "level": 3}}`, and the fixture soul has 12 points (20 minus 2, 3 and 3). Then `game.begin_life(Game.resolve_start(pools, pending, Compendium.progress.is_attuned))` with the real `RebirthChoice.pools(game.world.rooms)`: `player.progression.level` is 3 and `SkillRules.owned()` has `leap`. Restore the last choice and clear `pending_start`; end with `SkillRules.reset_run()` and `Announcer.queue.clear()`.
- [ ] **Step 2: Run** `tools/run_tests.sh goddess_flow`. Expected: PASS (every part exists after Task 5; a FAIL here is a wiring bug to fix in Task 5's code, not in the test). If `begin_life` on the dead player misbehaves, assert on a second freshly loaded `Game` instead and ledger the ruling.
- [ ] **Step 3: Run the whole suite** `TEST_TIMEOUT=900 tools/run_tests.sh`. Expected: PASS, no `SCRIPT ERROR`.
- [ ] **Step 4: Commit** `git add tests/test_goddess_flow.gd* && git commit -m "test: dying buys a head start through real input and the next life has it"`.
