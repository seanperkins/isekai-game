# Boss Arenas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A boss room that seals behind the player and opens when the boss dies, a world that warns you a boss is ahead, a lint rule tying room size to creature size, and the Taratect as the first boss in the Deep.

**Architecture:** The room data gains three fields (`boss`, `tremor`, `glimpse`). A pure `BossArenaModel` is the state machine; a `BossArena` node reads the player and the boss each tick and does the work (seal, wake, win). `Enemy` gains a `dormant` flag. `WorldProgress` stores defeated bosses. The warning is a `Tremor` node, a `Glimpse` node and three audio cues. Rooms D2, D6 and a new D7 are edited as data.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-boss-arenas-design.md`.

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; the whole suite takes about 35 s. Run `godot --headless --import` twice after adding a script or a room, and commit `.uid` files.
- Constants (spec): `INTRO_SECONDS` 0.8, `SEAL_AT` 0.4, `SEAL_CLEARANCE` 320, creature fit `1.25 * H` clear height and `2 * W` footing, boss room at least 2 screens in one dimension, boss spawn at least 200 px from the threshold, tremor gaps 5 to 9 s, tremor 0.3 in the approach and 0.6 in the antechamber.
- The antechamber has a glow pool and a tablet, not an altar (one altar per area). No existing mechanic changes: new fields default to empty, `dormant` and `hunting` false. The rooms edited are D2, D6 and the new D7, D3 (its drake's platform, 160 wide, needs 216) and any other room `creature_fit` flags, each edit a ledger line, plus the pins in the Deep tests.
- Web strand and claw mark decor art, a boss health bar, music and boss behaviour are out of scope.
- No attribution lines in commit messages. Do not push.

## Review Focus

1. An ordinary exit never gets a gate, the seal never closes on the player and the player cannot leave before it, even with the Jet Dash (Tasks 1 and 4).
2. A dormant boss cannot be damaged, stunned, threaded, eaten or moved by any path, deals no contact damage and shows its idle frame; awake it hunts the player wherever they are (Task 3).
3. Dying mid-fight rebuilds the arena `waiting` with a full-health boss; a defeated boss never respawns; the Bestiary defeat is recorded before the profile's, and a failed write keeps the boss dead for the session (Task 5).
4. Every shipped room passes `creature_fit` with the drake at 1.5 times its old size, and the new Deep validates (Tasks 1 and 7).
5. The warning fires only in rooms with `tremor`, scales with it, and the glimpse stays behind the solids (Task 6).

---

### Task 1: Room data and lint

**Files:**
- Modify: `scripts/world/room_def.gd`, `scripts/world/room_lint.gd`, `tests/test_room_lint.gd` and `tests/test_room_lint_water.gd` (both pin `RoomLint.RULES.size()` at 16: it becomes 20)
- Test: `tests/test_room_lint_boss.gd` (new), `tests/test_room_def.gd` (the round trip, if the file exists, else the new file)

**Interfaces:**
- Produces on `RoomDef`: `@export var boss := {}` (`{"creature": id, "threshold": Rect2}`), `@export var tremor := 0.0`, `@export var glimpse := {}` (`{"creature": id, "pos": Vector2, "scale": float, optional "frame": String}`). On `RoomLint`: consts `FIT_HEIGHT := 1.25`, `FIT_FOOTING := 2.0`, `SEAL_CLEARANCE := 320.0`, `BOSS_MIN_SCREENS := 2`, `BOSS_SPAWN_GAP := 200.0`; `static func creature_extent(id: String) -> Vector2` (widest and tallest frame of the creature's sheet as it ships, which already carries the size ladder's scale, so nothing is scaled again; ZERO when it has none); rules `creature_fit`, `boss_room`, `tremor_range`, `glimpse` added to `RULES` and to `check_room`.

- [ ] **Step 1: Write the failing tests.** `test_room_lint_boss`, on small `RoomDef` fixtures built like `test_room_lint`'s: `test_a_big_standing_creature_needs_clear_height_and_footing` (the stone drake, whose widest frame is 108 and tallest 99: a room whose ceiling is 120 px above its footing fails, 125 passes; a footing of 215 fails, 216 passes), `test_a_ceiling_anchored_creature_is_checked_for_the_drop` (the taratect: 112 px of drop under its anchor fails at 111, passes at 112; the footing rule is not applied), `test_creatures_without_a_sheet_and_swimmers_are_skipped` (`water_pool`; a swimmer), and one test per boss rule on a fixture that breaks it: `test_a_boss_room_is_two_screens_in_one_dimension`, `..._has_exactly_one_exit`, `..._that_exit_leads_to_a_glow_pool_room_with_no_spawns`, `..._the_boss_is_in_spawns_and_200_px_from_the_threshold`, `..._the_threshold_is_inside_and_320_px_from_every_exit_span`, `..._the_floor_has_no_hole_and_no_water`; `test_tremor_is_zero_to_one`; `test_a_glimpse_needs_a_creature_with_a_sheet_and_a_position_inside_the_room`. `test_room_def`: `test_boss_tremor_and_glimpse_survive_a_save_and_load` (`ResourceSaver` to a temp path and back).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_room_lint_boss`. Expected: FAIL (the fields and rules do not exist).
- [ ] **Step 3: Implement** the exports and the four rules. A standing creature's footing is the contiguous floor or solid top under the spawn and its clear height runs to the nearest solid above; a creature is ceiling-anchored when its def lists the `ceiling_walk` movement (the spider, the taratect and the vine snake do). Each finding uses `_f(r, rule, message)`.
- [ ] **Step 4: Run to see them pass, then every room.** Run: `tools/run_tests.sh test_room_lint_boss` and `tools/run_tests.sh test_room_lint`. Expected: PASS, and the existing rooms report no `creature_fit` finding; one that fails (D3's drake platform, 160 wide against 216) is fixed in its data, a ledger line each, never by loosening the constant.
- [ ] **Step 5: Commit** (`feat: room data for boss rooms, tremor and glimpse, and the creature fit and boss room lint`).

### Task 2: The arena's state machine

**Files:**
- Create: `scripts/world/boss_arena_model.gd`
- Test: `tests/test_boss_arena_model.gd` (new)

**Interfaces:**
- Produces `BossArenaModel` (a `RefCounted`): `enum State { WAITING, INTRO, FIGHT, WON }`, consts `INTRO_SECONDS := 0.8`, `SEAL_AT := 0.4`; `var state := State.WAITING`; `func tick(dt: float, in_threshold: bool, boss_downed: bool) -> PackedStringArray` returning the events of this tick in order from `"intro"` (the crossing: the rumble starts), `"seal"` (at `SEAL_AT`), `"wake"` (at `INTRO_SECONDS`, the state becomes FIGHT) and `"won"` (the state becomes WON); each event once.

- [ ] **Step 1: Write the failing tests.** `test_it_waits_until_the_threshold_is_crossed`; `test_crossing_starts_the_intro_with_one_intro_event`; `test_the_seal_comes_at_0_4_s_and_the_wake_at_0_8_s` (at 60 Hz, within a tick); `test_leaving_the_threshold_during_the_intro_does_not_cancel_it`; `test_a_downed_boss_wins_from_the_fight_only` (`boss_downed` while WAITING or INTRO is ignored, so a boss killed through an intro bug cannot open doors that never shut: it is held and applied at FIGHT); `test_every_event_fires_once_and_won_is_final`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_boss_arena_model`. Expected: FAIL.
- [ ] **Step 3: Implement** `tick` as above.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_boss_arena_model`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the boss arena's state machine`).

### Task 3: A dormant enemy

**Files:**
- Modify: `scripts/enemies/enemy.gd`
- Test: `tests/test_enemy_dormant.gd` (new)

**Interfaces:**
- Produces `Enemy.dormant: bool` (default false; a setter that redraws the idle frame through `_update_visual()`, so it is right whether it is set before or after the enemy enters the tree) and `Enemy.hunting: bool` (default false). While `dormant`: `_physics_process` returns at the top with the velocity zeroed (no gravity, movement or AI; a dropper stays where it spawned), `_untouchable()` and `can_be_hit()` are true and false, `can_be_predated()` is false (so `consume()` is never reached), `receive_hit`, `receive_tackle` and `receive_thread` do nothing, and the contact-damage check treats it as harmless. Every other way to change a dormant enemy is a no-op too: `slow_for()` (the spore cloud calls it directly) and `EnemyStatus.stun()` and its siblings (the Tremor ability calls `status.stun()` itself after `receive_hit`), through an `EnemyStatus.frozen` flag the `dormant` setter sets. Setting `dormant` forces the creature's resting frame (`idle_1`, the Taratect's `hang_1`) whatever status or action state it was in. While `hunting`, `_sense` always sees the player (it ignores `CHASE_RANGE` and line of sight).

- [ ] **Step 1: Write the failing tests** (a real `Enemy` set up the way `test_enemy_state` does): `test_a_dormant_enemy_does_not_move_or_fall` (60 ticks above a floor: position unchanged), `test_a_dormant_enemy_refuses_damage_from_every_path` (`receive_hit` through the area-skill path, `receive_tackle`, `receive_thread`: hp and status unchanged, and it never becomes predatable), `test_the_tremor_ability_and_the_spore_cloud_leave_a_dormant_enemy_unchanged` (real casts: no stun, no slow carried over to the wake), `test_dormancy_set_during_a_windup_or_a_stun_shows_the_resting_frame`, `test_a_dormant_enemy_cannot_be_predated` (`can_be_predated()` false, so `consume()` cannot free it and orphan the arena), `test_a_dormant_enemy_deals_no_contact_damage`, `test_dormancy_shows_the_idle_frame_set_before_or_after_entering_the_tree`, `test_a_hunting_enemy_is_alert_to_a_player_far_outside_chase_range`, `test_waking_it_restores_everything` (dormant false: it moves, can be hit and hurts), `test_the_default_is_awake`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_enemy_dormant`. Expected: FAIL.
- [ ] **Step 3: Implement** the flag and its guards at the entry points the spec lists; `_untouchable()` and `can_be_hit()` read it, so every existing caller is covered.
- [ ] **Step 4: Run to see them pass, then the enemy suites.** Run: `tools/run_tests.sh test_enemy_dormant` and `tools/run_tests.sh test_enemy`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: a dormant enemy, frozen and untouchable`).

### Task 4: The seal and the arena node

**Files:**
- Create: `scripts/world/boss_arena.gd`
- Modify: `scripts/world/room_builder.gd`, `scripts/world/world.gd`
- Test: `tests/test_boss_arena.gd` (new), `tests/test_room_builder.gd` (the gate refactor keeps its tests green)

**Interfaces:**
- Consumes: `BossArenaModel`, `Enemy.dormant`, `RoomBuilder.gate_rect(size, e)`.
- Produces `RoomBuilder.make_gate(room: Node2D, def: RoomDef, e: Dictionary, solids: Array, painted: bool, group: String) -> StaticBody2D` (the solid, with the painted art as its child when `painted`), used by the closed-shortcut path and by the arena. `BossArena` (a `Node2D`): `func setup(def: RoomDef, ctx: Dictionary, boss: Enemy, solids: Array, painted: bool) -> void`; a threshold `Area2D` on the player's layer; each physics tick it calls `model.tick(dt, player_in_threshold, boss_downed)` and handles `"intro"` (world event `boss_intro`), `"seal"` (a `make_gate` solid for every exit of the room in the group `boss_gate`, world event `boss_slam`, `ctx["shake"]`), `"wake"` (`boss.dormant = false` and `boss.hunting = true`, world event `boss_wake`) and `"won"` (frees only the `boss_gate` group, world event `boss_defeated`). `BossArena.locked() -> bool` (true in INTRO and FIGHT); `World._physics_process` ignores exit transitions while the current room's arena is locked. `World.shake(amount: float, seconds: float)` jolts the camera and `World.setup` puts it in `ctx["shake"]`; the arena handles a ctx with no `shake`.

- [ ] **Step 1: Write the failing tests** (real collision, a small boss room fixture with a real player body): `test_ordinary_exits_have_no_gate_and_the_arena_adds_them_at_the_seal` (before the seal the player walks out of the exit; after `SEAL_AT` a body cannot), `test_the_threshold_is_the_only_trigger` (standing 1 px outside it, nothing starts), `test_the_boss_is_dormant_until_the_wake` (`dormant` true through the intro; after it `dormant` false and `hunting` true), `test_the_gate_never_lands_on_the_player_and_the_player_cannot_leave_first` (a player at the minimum clearance who Jet Dashes toward the exit through the real `World` transition path: no gate overlaps the body when it appears, and no transition begins), `test_the_world_ignores_exit_transitions_while_the_arena_is_locked`, `test_the_gate_helper_parents_the_painted_art_and_freeing_the_gate_frees_it` (painted and unpainted), `test_winning_frees_the_arena_gates_and_only_them` (a shortcut gate in the same room stays), `test_the_events_reach_the_world_event_bus_in_order`, `test_the_gate_helper_still_builds_the_shortcut_gates` (the existing builder tests stay green).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_boss_arena`. Expected: FAIL.
- [ ] **Step 3: Implement** the helper by moving the gate-building out of `build_room` unchanged in behaviour, then `BossArena`, then `World.shake` (a short tween of `camera.offset`, decaying) and the `ctx["shake"]` entry.
- [ ] **Step 4: Run to see them pass, then the world suites.** Run: `tools/run_tests.sh test_boss_arena`, `tools/run_tests.sh test_room_builder` and `tools/run_tests.sh test_world`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the boss arena seals its exits and wakes its boss`).

### Task 5: Defeat, persistence and the room build

**Files:**
- Modify: `scripts/world/world_progress.gd`, `scripts/world/room_builder.gd`, `scripts/world/boss_arena.gd`
- Test: `tests/test_boss_defeat.gd` (new), `tests/test_world_progress.gd`

**Interfaces:**
- Produces on `WorldProgress`: `var bosses: Array` (loaded from the profile section `"bosses"`, written by `_save`), `func defeat_boss(id: String) -> void`, `func is_defeated(id: String) -> bool`. `RoomBuilder.build_room`, for a room with `boss`: when `ctx["progress"]` is non-null and `is_defeated(boss.creature)` it spawns no boss and adds no arena; when there is no progress or no valid `spawn` callable (the editor's preview passes `{"progress": null}` and no spawner) it builds the room with no boss and no arena; otherwise it spawns the creature dormant and adds a `BossArena` for it. The arena connects to the boss's `downed` signal (after the connections `Game._spawn` made) and, on the next frame, tells the model and calls `defeat_boss`.

- [ ] **Step 1: Write the failing tests.** `test_world_progress`: `test_a_defeated_boss_is_stored_and_survives_a_reload` (a profile in a temp dir), `test_a_failed_write_keeps_the_boss_dead_for_the_session_and_the_next_save_retries` (a profile whose write fails once). `test_boss_defeat`: `test_a_defeated_boss_is_not_spawned_and_the_room_has_no_arena`, `test_an_undefeated_boss_is_a_full_health_dormant_spawn_every_time_the_room_is_built` (die mid-fight: rebuild: `waiting`, hp full), `test_the_bestiary_defeat_is_recorded_before_the_profile` (a listener connected first to `downed` records an order list; the arena's record comes after, on the next frame), `test_a_predatable_boss_wins_on_downed_not_on_being_eaten` (the Taratect is predatable: its lethal hit emits `downed` through `_on_died`, the gates open, and eating the corpse afterwards changes nothing), `test_stopping_between_the_two_leaves_the_boss_alive` (the profile never written: the next build spawns the boss), `test_the_editor_preview_builds_a_boss_room_with_no_progress_and_no_spawner`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_boss_defeat`. Expected: FAIL.
- [ ] **Step 3: Implement** the section, the two methods, the `build_room` branch and the arena's deferred record.
- [ ] **Step 4: Run to see them pass, then the world suites.** Run: `tools/run_tests.sh test_boss` and `tools/run_tests.sh test_world_progress`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: a defeated boss stays defeated, recorded after the Bestiary`).

### Task 6: The warning

**Files:**
- Create: `scripts/world/tremor.gd`, `scripts/world/glimpse.gd`
- Modify: `scripts/world/room_builder.gd`, `data/audio/cues.json`
- Test: `tests/test_tremor.gd` (new), `tests/test_glimpse.gd` (new), `tests/test_audio_boundary.gd` (stays green)

**Interfaces:**
- Produces `Tremor` (a `Node2D`): `func setup(def: RoomDef, ctx: Dictionary, rng: RandomNumberGenerator) -> void`; every `rng.randf_range(5.0, 9.0)` s it emits the world event `boss_tremor` with `{"strength": def.tremor}`, calls `ctx["shake"].call(def.tremor * 4.0, 0.5)` and drops a few dust specks from the ceiling; with no `ctx["shake"]` it still plays the sound. `Glimpse` (a `Sprite2D`): `static func make(g: Dictionary) -> Sprite2D`, the creature's sheet frame (`frame` or its default), tinted near black at 0.7 alpha, scaled by `g["scale"]`, drifting slowly; `build_room` inserts it right after the backdrop and back wall and before the water and the solids (so its child index is below the first solid's, in painted and unpainted rooms) when `def.glimpse` is non-empty, and adds a `Tremor` when `def.tremor > 0.0`; the event carries `{"strength": def.tremor, "near": def.tremor >= 0.5}`. `cues.json` gains the events `boss_intro`, `boss_tremor` (routed `by` the `near` tag to `boss_tremor_far` and `boss_tremor_near`), `boss_slam`, `boss_wake`, `boss_defeated` and cues for them with the nearest existing sounds as stand-ins (`slime_land_hard` for the tremors, quieter for the far one, and for the slam, `skill_tail_swipe` for the wake, `enemy_death_boss` for the defeat), and `"taratect": "enemy_death_boss"` in the `enemy_died` routing.

- [ ] **Step 1: Write the failing tests.** `test_tremor`: `test_it_fires_on_the_seeded_schedule_with_gaps_of_5_to_9_s`, `test_the_shake_and_the_event_scale_with_the_value` (and the event's `near` is false at 0.3, true at 0.6), `test_a_tremor_with_no_shake_callable_still_emits`, `test_a_room_with_no_tremor_has_none`. `test_glimpse`: `test_the_glimpse_is_the_creatures_own_frame_dark_and_scaled`, `test_it_is_drawn_behind_the_rooms_solids_in_painted_and_unpainted_rooms` (its child index is below the first solid's), `test_it_drifts_but_stays_inside_the_room`. `test_audio_boundary`: every event the boss code emits has an entry, and `enemy_died` for `taratect` routes to `enemy_death_boss`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_tremor` and `tools/run_tests.sh test_glimpse`. Expected: FAIL.
- [ ] **Step 3: Implement** the two nodes, the `build_room` additions and the cue rows.
- [ ] **Step 4: Run to see them pass, then the audio suites.** Run: `tools/run_tests.sh test_tremor`, `tools/run_tests.sh test_glimpse` and `tools/run_tests.sh test_audio`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the world warns you a boss is ahead`).

### Task 7: The Deep

**Files:**
- Modify: `data/rooms/D2.tres`, `data/rooms/D6.tres`, `tests/test_deep_rooms.gd`, `tests/test_deep_data.gd`, `tests/test_deep_slice.gd` (D6's size and floor-hole assertions), `tests/support/shipped_rooms.gd` (the room list), `tests/test_world_size.gd` (the room and screen counts) and any other test that pins D2's top exit or D6's bottom exit
- Create: `data/rooms/D7.tres`
- Test: `tests/test_deep_rooms.gd`

**Interfaces:**
- Consumes everything above. Produces: `D7` at cell (18,5), 1 screen, area `deep`: a bottom exit (span 280 to 360, gate `wall_cling`) to D2, a right exit (span 240 to 320) to D6, a `glow_pool` feature and a `tablet` whose text says something lives beyond, a `glimpse` of the taratect behind a gap, `tremor` 0.6, no spawns. `D6`: cell (19,5), size (2,1), `boss` `{"creature": "taratect", "threshold": Rect2(360, 200, 40, 120)}` (at least 320 px from the left exit), the taratect spawned at the ceiling about 900 px along, a flat floor, a left exit (span 240 to 320) to D7, no bottom exit. `D2`: the chimney's two walls at x 260 and 364 (16 wide, 220 tall) and the top exit span 280 to 360 retargeted to D7 (gate `wall_cling`), `tremor` 0.3. Decor traces use the existing `deep_bones` and hanging pieces.

- [ ] **Step 1: Write the failing tests** in `test_deep_rooms`: `test_the_deep_has_a_boss_arena_d6_two_screens_wide_with_one_exit_to_d7`, `test_d7_is_the_antechamber_a_glow_pool_a_tablet_no_spawns_and_tremor_0_6`, `test_d2_climbs_to_d7_through_a_wall_cling_chimney_and_trembles_0_3`, `test_every_room_passes_the_room_lint_and_the_world_validator` (the existing whole-world tests, now including D7), `test_the_exits_between_d2_d7_and_d6_pair_up`, `test_a_floor_bound_player_in_the_arena_draws_the_awake_taratect_down` (a real taratect, `hunting`, a player on the floor 260 px below its ceiling spawn: within a few seconds it leaves the ceiling).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_deep_rooms`. Expected: FAIL.
- [ ] **Step 3: Edit the room data** as above (by hand or the room editor), then update the pins in the Deep tests that name D6's old bottom exit or D2's old chimney, each change a ledger line with the old and new value.
- [ ] **Step 4: Run the world and room suites.** Run: `tools/run_tests.sh test_deep` and `tools/run_tests.sh test_world`, then `tools/run_tests.sh`. Expected: PASS, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 5: Commit** (`feat: the Taratect's arena and the antechamber in the Deep`).

### Task 8: Docs and the whole suite

**Files:**
- Modify: `docs/rooms.md`, `docs/superpowers/specs/2026-10-04-boss-arenas-design.md`

- [ ] **Step 1: Write the docs.** In `docs/rooms.md` a section "Boss rooms": the three fields, the arena's states, the lint rules, the antechamber and tremor conventions; the spec's status line says built, its open items updated.
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: boss rooms in rooms.md and the spec as built`).
