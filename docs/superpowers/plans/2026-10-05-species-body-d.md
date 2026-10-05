# Species in the real Player (D1 to D4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A run can start as the wolf, the goblin, the undead or the spider (the slime stays the default): the Player moves with that species' movement profile and verbs (pounce, vault, roll, slide, mantle, wall jump, crawl, web zip, silk drop), is drawn with its look, fights with its signature move, and the goddess's menu and a `--species=` flag start a run as it.

**Architecture:** The movement model exists as pure steps (`VerbRunner`) driven by `MovementSandbox`, which also owns the world probing and the body. That body logic moves into a reusable `SpeciesBody` (probes, `VerbRunner.step`, the crawl and mantle shifts, the collision box, `move_and_slide`), and both the sandbox and the Player use it. The Player keeps its slime movement untouched and uses `SpeciesBody` only when `species != "slime"`; everything else (health, MP, eating, abilities, water, damage, rooms) is shared. Species data (`SpeciesDef`) and the unlock rules already exist for the goddess's menu; this adds the data for the four species.

**Tech Stack:** Godot 4.7 GDScript, GUT.

**Spec:** `docs/research/species-form-branches.md` (sections 1 and 11), `docs/superpowers/specs/2026-10-04-species-movesets-design.md`, `docs/superpowers/specs/2026-10-04-soul-layer-design.md`, roadmap pieces D1 to D4.

## Global Constraints

- Baseline 2776 tests on `main` (00c3ebb). A slime Player behaves exactly as before: no existing test changes except where it asserted that every species is a slime.
- Species to movement profile: slime to `slime`, wolf to `wolf`, goblin and undead to `biped`, spider to `spider` (`MovementProfile.for_species`).
- The look is `SpeciesLook` (wolf: the Gloom Wolf sheet, goblin and undead: the goblin sheet, spider: the spider sheet) until a form brings its own sheet (G1). A missing sheet draws the plain rectangle, never an error.
- The signature button (the slime's Tackle key) is the species' signature move: pounce, roll or slide, and the zip. A burst that touches a hostile hits it as the slime's Tackle does (`receive_tackle` with the Player's ATK).
- Damage knockback and invulnerability, abilities' `apply_impulse`, `ward`, water and the world's room slide work for every species.
- Species is chosen before `Player.setup()` and never changes in a life.

## Review Focus

- A slime Player (the default) takes the old code path in every method this plan touches. (Tasks 2, 3)
- An ability impulse, a knockback, a water entry, a ward and a room transition on a species body do not leave `SpeciesBody.state.velocity` and the body's `velocity` disagreeing. (Task 2)
- A crawling spider that dies, evolves, is hit, or is carried across a room edge does not end inside a solid and its box returns to normal. (Task 3)
- A roll's or a slide's invulnerability stops damage and ends with the burst. (Task 3)
- A species with no sheet, or a species id nobody knows, falls back (rectangle, slime). (Tasks 2, 4)

---

### Task 1: `SpeciesBody`, and the sandbox uses it

**Files:**
- Create: `scripts/movement/species_body.gd`, `tests/test_species_body.gd`
- Modify: `scripts/movement/movement_sandbox.gd`, `scripts/movement/movement_profile.gd` (`for_species`)
- Test: `tests/test_species_body.gd`, the existing `tests/test_movement_sandbox.gd`

**Interfaces:**
- Produces: `class_name SpeciesBody extends RefCounted`: `_init(p_body: CharacterBody2D, p_shape: CollisionShape2D, p_box: RectangleShape2D)`; `profile: MovementProfile`, `state: MoveState`; `set_profile(p: MovementProfile) -> void`; `fill_input(i: MoveInput, hostile: Callable = Callable()) -> void` (floor, ceiling, clearance, wall side, one-way floor, the crawl, zip, vault, mantle probes, `touching_hostile` from `hostile`); `step(i: MoveInput, dt: float, jump_boost := 1.0, adjust := Callable()) -> void` (runs `VerbRunner.step`, the one-way mask, the crawl or the pull, the box, `adjust(state)` just before the move, `move_and_slide`, copies the body's velocity back into `state`); `is_crawling() -> bool`; `landed() -> bool`; `MovementProfile.for_species(species: String) -> MovementProfile`.

- [ ] **Step 1: Write failing tests** (`StaticBody2D` floor, walls and a ledge built in the test; a `CharacterBody2D` with a `RectangleShape2D` of `BodyConfig.size()`; collision mask 7): `test_fill_input_reads_floor_wall_and_clearance` (on the floor `on_floor`, a wall within 6 px sets `wall_side`, a low ceiling gives `clearance_above` 0); `test_step_walks_at_the_profiles_top_speed_and_jumps` (slime profile: 20 ticks of `dir 1` reach 140 px/s, a jump press launches and the body rises); `test_a_wolf_pounce_moves_along_the_aim` (signature press with aim right gives `state.verb == "pounce"` and speed above 300); `test_a_biped_mantles_a_ledge_it_jumps_at` (a ledge 30 px up and a jump press ends standing on it); `test_a_spider_crawls_up_a_wall` (`dir` into a wall from the floor gives `is_crawling()` and `surface_n` pointing out of the wall); `test_the_box_goes_flat_for_a_roll` (biped roll: box height is the spread size); `test_for_species_maps_each_species_and_refuses_the_unknown` (null for `"newt"`). The sandbox's own tests are the refactor's safety net and must not change.
- [ ] **Step 2: Run** `tools/run_tests.sh test_species_body`. Expected: FAIL.
- [ ] **Step 3: Implement** by moving the sandbox's probes (`_clearance`, `_wall_side`, `_walls_on_floor`, `_step_ahead`, `_mantle`, `_sweep`, `_ray`, `_cast`, `_stands_on_oneway`, `_apply_box`, the crawl application) and their constants into `SpeciesBody`; the sandbox builds one `SpeciesBody` and calls it, keeping its drawing, thread, dust and jump measuring.
- [ ] **Step 4: Run** `tools/run_tests.sh test_species_body`, `test_movement`, `test_verb_runner`, `test_species_look`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: the sandbox's body logic is a SpeciesBody both it and the Player can use"`.

### Task 2: The wolf in the Player

**Files:**
- Modify: `scripts/player/player.gd`, `scripts/movement/species_look.gd` if a helper is missing
- Create: `tests/test_player_species.gd`
- Test: `tests/test_player_species.gd`, `tests/test_player.gd`

**Interfaces:**
- Produces: `Player.species_body: SpeciesBody` (null for the slime); `Player.uses_species_body() -> bool`; species movement in `_physics_process` through `_move_species(delta)`; `Player.signature_hits` handled in `_species_signature()`; `apply_impulse` and knockback write the species state's velocity too.

- [ ] **Step 1: Write failing tests** (a `Player` with `species = "wolf"` set before `setup`, on a built floor, as `tests/test_evolution_flow.gd` does): `test_a_slime_player_has_no_species_body`; `test_a_wolf_runs_faster_than_a_slime` (held `move_right` for 40 frames: the wolf's speed is near 230, a slime's near 140); `test_a_wolf_jumps_with_its_profile` (apex height from `jump_velocity 403`, `gravity 1344`); `test_a_wolf_pounce_hits_an_enemy_it_reaches` (a real `Enemy` ahead takes the Player's ATK through `receive_tackle` once per pounce); `test_a_wolf_is_drawn_with_the_gloom_wolf_sheet` (`body_sheet()` is the wolf's, the sprite visible, `hurt_polygon()` non-empty); `test_a_wolf_without_its_sheet_draws_a_rectangle` (an unknown sheet name does not error); `test_an_ability_impulse_moves_a_wolf` (`apply_impulse(Vector2(300, 0))` gives the body that speed for its dash time, both velocities agree); `test_a_hit_knocks_a_wolf_back` (`receive_hit` with `from` on its left pushes it right); `test_a_wolf_can_eat` (the predation hold works and freezes its walking); `test_a_wolf_in_water_swims` (the water model still applies); `test_the_wolf_evolves_and_keeps_its_movement` (`advance_form("wolf_lupine"` style id of a real stage-2 wolf form, forced) keeps `species_body.profile.id == "wolf"`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_player_species`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `setup` a species other than the default builds `SpeciesBody` after `_build_body` with `MovementProfile.for_species`; the draw reads `SpeciesLook` (a `_update_visual_species`), the sheet is `SpeciesLook.sheet_for` with the slime's the fallback. `_physics_process` splits after the shared early returns: the slime path unchanged; the species path reads input into a `MoveInput` (dir, jump, down, up, aim, signature = the tackle key), calls `species_body.step` with an `adjust` that applies the water model, then runs the shared actions (predation, inspect, actives, channel), then audio, sensors, `tick`, the visual. `state.invulnerable` feeds the same check as `_invuln`. A burst touching a hostile calls `receive_tackle` once. `apply_impulse` and the knockback also set `species_body.state.velocity`.
- [ ] **Step 4: Run** `tools/run_tests.sh test_player_species`, `test_player`, `test_player_water`, `test_evolution_flow`, `test_abilities`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: the wolf in the real Player"`.

### Task 3: The goblin, the undead and the spider in the Player

**Files:**
- Modify: `scripts/player/player.gd`, `scripts/movement/species_look.gd`
- Test: `tests/test_player_species.gd`

**Interfaces:**
- Produces: the biped (`goblin`, `undead`) and spider bodies through the same path; the spider drawn on any surface (`SpeciesLook.surface_angle`, stride frames) with the crawl's box; `Player.invulnerable_now() -> bool` includes a roll or slide's invulnerability.

- [ ] **Step 1: Write failing tests:** `test_a_goblin_and_an_undead_use_the_biped_profile`; `test_a_biped_rolls_and_is_untouchable_while_it_does` (a roll start, a hit during the first 0.2 s does nothing, one after it does); `test_a_biped_slide_is_flat_and_ends` (the box is the low one while it runs and standing again after, with room); `test_a_biped_mantles_a_ledge_in_the_game` (a jump at a ledge ends standing on it); `test_a_biped_wall_jumps` (wall slide, then a kick off); `test_a_spider_crawls_a_wall_and_a_ceiling` (a spider held `move_right` into a wall climbs it, and `move_left` along a ceiling hangs and moves); `test_a_spider_zips_to_a_solid` (signature with an aim: pulled to the first solid within 160 px, the thread drawn); `test_a_spider_drops_on_a_thread_and_lands`; `test_a_crawling_spider_that_is_hit_is_not_left_inside_a_solid` (after `receive_hit` the body is free of overlap and its box is the standing one when it falls); `test_a_crawling_spider_that_dies_ends_cleanly`; `test_a_spider_with_no_sheet_draws_a_rectangle`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_player_species`. Expected: FAIL.
- [ ] **Step 3: Implement.** Port the sandbox's spider drawing (the rotated sprite on a surface, the stride frames, the thread `Line2D`) into `Player` behind `uses_species_body()`; the roll and slide's `state.invulnerable` blocks `receive_hit` and `receive_poison`; the crawl's box swap runs through `SpeciesBody`, and `receive_hit` on a crawler detaches it (`surface_n` ZERO) with the knockback.
- [ ] **Step 4: Run** `tools/run_tests.sh test_player_species`, `test_surface_step`, `test_zip_step`, `test_drop_step`, `test_mantle_step`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: the goblin, the undead and the spider in the real Player"`.

### Task 4: Species data and starting as a species

**Files:**
- Create: `data/species/{wolf,goblin,undead,spider}.tres`, `tests/test_species_data.gd`
- Modify: `scripts/game.gd` (the Player gets `species`), `scripts/world/world_progress.gd` if it clamps species, `tools/build_soul.gd` if it generates species, `README.md` (the `--species=` flag)
- Test: `tests/test_species_data.gd`, `tests/test_game_start.gd` (or the existing start tests)

**Interfaces:**
- Produces: four `SpeciesDef` files (`unlock`: wolf `defeat gloom_wolf`, spider `count spider 5`, goblin `count armed_ant 3`, undead `count bog_lizardman 3`; the last two are stand-ins until the goblin and skeleton creatures exist, F1); `Game.species_arg(args: Array) -> String` (`--species=wolf`, an unknown id reads `"slime"`); `Game` sets `player.species` from `resolve_start`'s `species` (a species with no file reads `"slime"`) before `setup`.

- [ ] **Step 1: Write failing tests:** `test_every_species_in_form_species_has_a_def_that_validates` (`SoulValidator` on the four plus the slime reports nothing, each profile file exists); `test_the_goddess_offers_only_what_is_unlocked` (with Bestiary records for the wolf's rule met, the menu lists slime and wolf, not the spider); `test_species_arg_reads_a_known_species_and_refuses_the_rest` (`--species=wolf` gives wolf, `--species=newt` and a bare `--species` give slime); `test_the_player_is_built_as_the_chosen_species` (a `Game` start with `pending {"species": "spider"}` gives a spider Player); `test_a_malformed_or_unknown_species_starts_a_slime`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_species_data`. Expected: FAIL.
- [ ] **Step 3: Implement** the four `.tres` (display names Wolf, Goblin, Undead, Spider; movement profiles as above), `Game.species_arg`, the Player construction in `Game`, the README flag line.
- [ ] **Step 4: Run** `tools/run_tests.sh test_species`, `test_soul`, `test_game`, then the whole suite `TEST_TIMEOUT=1700 tools/run_tests.sh`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: the four species in the goddess's menu, and a --species flag"`.
