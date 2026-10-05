# Menagerie (F1-lite) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every form's world twin and every support monster exists as a creature in the game: spawns, fights with its form's verb, is edible, wears its form's art, and can be seen together in a Menagerie room started with `--room=menagerie`.

**Architecture:** 168 generated `CreatureDef`s (140 `twin_<form>`, 28 support) beside the 19 shipped ones. `CreatureDef` gains `verb`, `form`, art fields and an `origin`. `Enemy` builds a `VerbAbility` from the verb's skill and casts the kinds an enemy can (a data list in `VerbKinds`). The Menagerie is a generated `RoomDef` played through the editor-Play path (in-memory progress, nothing saved), with every creature dormant until the player stands near it.

**Tech Stack:** Godot 4.7 GDScript, GUT (`tools/run_tests.sh [filter]`), Python generators (`uv run --with Pillow python -m unittest tools/test_x.py`).

**Spec:** `docs/research/species-form-branches.md` §10 (tiers, twins, support monsters) and `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md` (F1).

## Global Constraints

- Twin ids are `twin_<form id>` (the form's `data/forms/<id>.tres` id); support ids are the design table's ids. A form whose twin is an existing creature (spider, gloom_wolf, taratect) gets no new creature.
- Tier table (design §10.1), exact: stage 2 common, essence 3, xp 4; stage 3 elite, essence 8, xp 10; stage 4 rare or boss, essence 12, xp 20. Essence splits evenly over the form's `reads`, the remainder to the first element. Support monsters use the design table's own essence and xp.
- Stats by stage (calibrated on lizard 5/5/1/80, taratect 24/9/2/120): stage 2 `{max_hp 6, atk 3, def 1, spd 90}`, stage 3 `{14, 5, 2, 90}`, stage 4 `{26, 8, 3, 100}`; speed offset by species wolf +20, spider +10, undead -20, slime -20, goblin 0.
- Behaviour flags by species: wolf `pack` and `charges`; goblin `pack`; the rest plain walkers.
- No push, no new areas, no new sprites: art is the form's still, else a shipped creature's frames (`wears`) tinted.
- No attribution lines in commits. Run Python tests with every suite run.

## Review Focus

- A twin whose verb kind an enemy cannot cast (summon, decoy, bridge, vine, reveal, anchor, copy, transmute, dissolve, glide, engulf) still spawns and fights as a plain creature, with no error.
- A creature whose `sprite_set` or frame is missing draws a placeholder and never errors; the validator reports it.
- A stunned, dormant, dying or far-away enemy never casts.
- `--room=menagerie` with the room name misspelt starts the normal game.
- Eating or defeating a twin pays its essence and xp and counts for its form's species unlocks like any creature.

---

### Task 1: CreatureDef fields and their validation

**Files:**
- Modify: `scripts/skills/creature_def.gd`, `scripts/skills/def_validator.gd`
- Test: `tests/test_creature_def_fields.gd`

**Interfaces:**
- Produces: `CreatureDef.verb: String`, `.form: String`, `.origin: String` ("", "twin", "support"), `.species: String`, `.role: String`, `.sprite_set: String`, `.sprite_frame: String`, `.wears: String`, `.sprite_size: float = 1.0`, `.sprite_tint: Color = Color.WHITE`.

- [ ] **Step 1: Write the failing tests** in `tests/test_creature_def_fields.gd`: `test_a_plain_creature_has_no_verb_form_or_art`; `test_the_validator_accepts_a_twin_with_a_known_verb_and_a_real_still` (verb `verb_wolf_fenrir`, set `forms_wolf`, frame `fenrir`); and one error test each for: unknown verb, a verb id that is not a skill with a `spec`, a `sprite_set` that is not an available sheet, a frame the sheet lacks, `wears` naming a creature that is not shipped, an `origin` outside the three values, and `origin == "twin"` with an empty `form`. Build defs with `TestDefs.creature(id, fields)` and call `DefValidator.validate(skills, creatures)` with the real skills from `DefLoader.load_dir("res://data/skills")`; assert on a substring of the error.
- [ ] **Step 2: Run** `tools/run_tests.sh test_creature_def_fields`. Expected: FAIL (properties missing).
- [ ] **Step 3: Add the fields** to `CreatureDef` with the doc comments above, and the checks to `DefValidator._check_creatures` (it already receives `by_id`). A new id outside `Sources.ALL` stays an error, so the test defs use shipped ids with `origin = "twin"` set by hand.
- [ ] **Step 4: Run** the same command. Expected: PASS. Also run `tools/run_tests.sh test_defs` and `test_content`.
- [ ] **Step 5: Commit** `feat: a creature can name a verb, a form and its art`.

### Task 2: The generator, the 168 creatures and the ids

**Files:**
- Create: `tools/build_creatures.py`, `tools/test_build_creatures.py`, `scripts/core/menagerie_ids.gd` (generated), `data/creatures/twin_*.tres` and the 28 support `.tres` (generated)
- Modify: `scripts/core/sources.gd`, `tests/test_constants.gd`, `tests/test_defs.gd`, `tests/test_content.gd` and any other test the suite shows counting 19 creatures or requiring a goddess line per creature
- Test: `tests/test_menagerie_data.gd`

**Interfaces:**
- Consumes: Task 1's fields; `build_evolutions.build()` (its `creatures`, `forms`), `read_forms_data()`.
- Produces: `Sources.SHIPPED` (the 19), `MenagerieIds.TWINS`, `.SUPPORT`, `.ALL`, and `Sources.ALL == SHIPPED + MenagerieIds.ALL` (if a const expression will not compile, make it `static func all()` and move the three call sites). In Python: `creature_rows() -> list[dict]`, `tres(row: dict) -> str`, `ids_gd(rows: list[dict]) -> str`.

- [ ] **Step 1: Write the failing Python tests** in `tools/test_build_creatures.py`: 140 twin rows and 28 support rows; every twin id is `twin_` plus a form id found in `data/forms/`; stats per stage match the Global Constraints and rise with stage; a wolf twin has `pack` and `charges`, a goblin twin `pack`, an undead twin neither; a twin's `verb` equals its form's `verb` and its art equals its form's sprite_set, frame, size and tint; essence totals are 3, 8 and 12 by stage; support rows keep the design table's essence and xp; every support row has a `wears` creature that is shipped, or a sprite set; `tres(row)` for the same row twice is identical (idempotent).
- [ ] **Step 2: Write the failing GUT tests** in `tests/test_menagerie_data.gd`: `Sources.ALL.size() == 187`, `MenagerieIds.TWINS.size() == 140`, `.SUPPORT.size() == 28`; every id has exactly one `CreatureDef` and the content loads with no errors; each twin's `form` is a `FormDef` in `data/forms` of the stated species and its `verb` is that form's `verb`; no twin or support monster has an unknown essence; stage 4 twins out-stat stage 2 twins; the `taratect`, `spider` and `gloom_wolf` defs are unchanged.
- [ ] **Step 3: Run both.** Expected: FAIL.
- [ ] **Step 4: Implement `tools/build_creatures.py`** to the signatures above: stats, flags and a `wears`/tint table for the support monsters by role (flyers wear `bat` or `pale_moth`, hounds `gloom_wolf`, humanoids `bog_lizardman`, the rest `lizard`; tint by the dominant element), `main()` writes the `.tres` files and `scripts/core/menagerie_ids.gd`. Run it, then `godot --headless --import` twice.
- [ ] **Step 5: Update `Sources`** and the tests that pinned 19, and fix whatever else the 187 reveal (a goddess line is a template line by species when none is written, via the existing `fallback`; ledger the ruling). Run `tools/run_tests.sh test_menagerie_data`, `test_constants`, `test_defs`, `test_content`, `test_goddess_lines`, plus the python tests. Expected: PASS.
- [ ] **Step 6: Commit** `feat: a creature for every form's twin and every support monster`.

### Task 3: Enemies cast their form's verb

**Files:**
- Modify: `scripts/enemies/enemy.gd`, `scripts/abilities/verb_kinds.gd`
- Test: `tests/test_enemy_verb.gd`

**Interfaces:**
- Consumes: `CreatureDef.verb`; `Ability` (`setup`, `ready()`, `activate()`, `aim`); `scenes/abilities/verb.tscn`.
- Produces: `VerbKinds.ENEMY_KINDS := ["bolt","burst","ring","dash","zone","mark","pull","aura","chain","heal","ward","buff"]`; `Enemy.apply_impulse(v: Vector2)`, `Enemy.ward(seconds: float)`, `Enemy.verb_casts: int`, constants `VERB_RANGE := 150.0`, `VERB_WINDUP := 0.35`, `VERB_RECOVER := 0.3`.

- [ ] **Step 1: Write the failing tests** (`StubPlayer` as in `test_enemy_ai.gd`): an enemy of a bolt twin casts at a player in line within `VERB_RANGE` once alert (`verb_casts == 1`, the stub took a hit) and not at one beyond it; it waits `VERB_WINDUP` first and `telegraphing()` is true during it; the spec's `cooldown` holds a second cast off; a stunned enemy, a dormant one and a dead one never cast; a heal verb casts only below half HP; a dash twin's `apply_impulse` moves it toward the player; `ward` makes `receive_hit` do nothing for its seconds; a twin whose verb kind is outside `ENEMY_KINDS` builds no ability and still walks; and one loop test: for every twin whose kind is in `ENEMY_KINDS`, an enemy in range of the stub casts once with no script error.
- [ ] **Step 2: Run** `tools/run_tests.sh test_enemy_verb`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `setup`, when `def.verb` names a skill whose active effect has an enemy-castable `spec`, instantiate the verb scene as a child with `actor = self` and `values` from the effect. `_act` runs `_verb_act` first for any kind: alert, within range, ability ready (and for `heal`, hurt), then a `VERB_WINDUP` telegraph, then `aim = direction to the player` and `activate()`, then `VERB_RECOVER` standing still. `apply_impulse` holds a horizontal speed for 0.25 s over `_walk`; `ward` ignores hits for its seconds.
- [ ] **Step 4: Run** `tools/run_tests.sh test_enemy_verb`, then `test_enemy_ai`, `test_enemy_behaviour`, `test_enemy_kind`, `test_verb_kinds`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: an enemy casts its form's verb`.

### Task 4: A creature wears its art

**Files:**
- Modify: `scripts/enemies/enemy.gd`
- Test: `tests/test_enemy_look.gd`

**Interfaces:**
- Consumes: `CreatureDef.sprite_set/sprite_frame/wears/sprite_size/sprite_tint`; `SpriteSheet.load_set`, `.frame_texture`, `.frame_size`.

- [ ] **Step 1: Write the failing tests:** a twin with a still (`twin_wolf_fenrir`) shows that frame, scaled by `sprite_size` and tinted, flipped with `facing`; a support monster with `wears` draws the worn creature's frames, tinted; a def whose sheet or frame is missing draws a visible placeholder (a tinted `lizard` frame) and raises no error; a shipped creature's sprite is exactly as before.
- [ ] **Step 2: Run** `tools/run_tests.sh test_enemy_look`. Expected: FAIL.
- [ ] **Step 3: Implement** a look id (`def.wears` if set, else `def.id`) used by `frame_name`, `_load_sheet` and the clips lookup; a still path in `_build_body` and `_update_visual` for `sprite_set`; the placeholder fallback.
- [ ] **Step 4: Run** `test_enemy_look`, `test_art_visuals`, `test_enemy_in_game` if present, and every `test_enemy_*`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: a creature wears its form's art`.

### Task 5: The Menagerie room and `--room=menagerie`

**Files:**
- Create: `scripts/world/menagerie.gd`, `scripts/world/menagerie_keeper.gd`
- Modify: `scripts/game.gd`
- Test: `tests/test_menagerie.gd`

**Interfaces:**
- Consumes: `Game.play_request` shape (`rooms`, `room`, `pos`).
- Produces: `Menagerie.ROOM_ID := "MENAGERIE"`, `Menagerie.request(creatures: Array) -> Dictionary`, `Menagerie.order(creatures: Array) -> Array` (shipped, then support, then twins by species and stage), `Game.room_arg(args: Array) -> String`, `MenagerieKeeper` with `WAKE_RANGE := 140.0`.

- [ ] **Step 1: Write the failing tests:** `request` returns a room that passes `RoomLint` with one spawn per creature in `order`, spaced at least 56 px, the player's `pos` on the floor at the left end; `order` puts shipped first and stage 2 before 4 within a species; `Game.room_arg(["--room=menagerie"]) == "menagerie"`, a bare or empty flag and any other name give `""`; the keeper leaves enemies beyond `WAKE_RANGE` dormant and wakes those inside it, and re-freezes them when the player leaves; a game launched with `launch_override` args `--room=menagerie` starts in that room with 187 enemies and writes nothing to `Compendium.progress`; `--room=menagre` starts the normal first room.
- [ ] **Step 2: Run** `tools/run_tests.sh test_menagerie`. Expected: FAIL.
- [ ] **Step 3: Implement** `Menagerie` (a long one-screen-high room, floor only, a name tag per spawn), the keeper (a node in the scene toggling `dormant` by distance each physics frame), and in `Game._ready` build the `request` from the flag before `_editor_play` is read.
- [ ] **Step 4: Run** `test_menagerie`, `test_form_flag`, `test_game_start` if present. Then launch `godot --path . -- --room=menagerie` once and look at it. Expected: PASS and the room opens.
- [ ] **Step 5: Commit** `feat: a room to see every creature in, started with --room=menagerie`.

### Task 6: Docs and the full run

**Files:**
- Modify: `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md`, `docs/research/species-form-branches.md`

- [ ] **Step 1: Update** the roadmap's F1 row and status line and the design doc's status paragraph to say what is built (168 creatures, verbs, art, Menagerie) and what is not (areas, per-area spawns, art beyond stills).
- [ ] **Step 2: Run** `TEST_TIMEOUT=1700 tools/run_tests.sh` and `for f in tools/test_*.py; do uv run --with Pillow python -m unittest $f; done`. Expected: PASS.
- [ ] **Step 3: Commit** `docs: the menagerie in the roadmap and the design doc`.
