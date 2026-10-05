# Form gates (H1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every wolf, undead, spider and goblin form is opened by its design-doc rule, as data: a gate of essence and deed conditions that the run's ledger can satisfy, shown on the cards with progress, and enforced when a form is offered.

**Architecture:** A `FormDef.gate` is a list of condition atoms in the same schema as a skill's `unlock` (`counter`, `reset_counter`, `skill_level`) plus two new kinds, `held` and `any`. `FormGate` evaluates them against the rules engine's ledger. New *deed* events (`defeated` with flag tags, `guard_broken`, `hidden_found`, `room_cleared`, ...) are emitted from the existing mechanics; events that need systems not built yet (grafts, bonds, lessons, traps, a moonlit room) are declared in `Deeds.RESERVED`, so the gates can be written now and a later piece burns the list down. `tools/form_gates.json` is the one table of gates; its builder writes `gate` into `data/forms/*.tres`.

**Tech Stack:** Godot 4.7 GDScript, GUT (`tools/run_tests.sh [filter]`), Python generators (`uv run --with Pillow python -m unittest tools/test_x.py`).

**Spec:** `docs/research/species-form-branches.md` (the "Opened by" column of every table) and `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md`.

## Global Constraints

- Gates apply to the wolf, undead, spider and goblin forms (99). The slime keeps `reveal`/`offer`. A gate is all of its atoms; the parent form is implicit (the tree).
- Essence atoms read the form's `reads`, `counter absorbed {essence}` this life. Total essence by stage, split evenly over the reads (ceil): stage 2 = 26, stage 3 = 34, stage 4 = 44 (the slime offers at 24 to 26). Hard numbers are calibrated in F3.
- A deed atom's `n` is 3 to 6; a streak is `reset_counter` reset on `damaged` (or `skill_missed`). "Plus fire/mind/blood (later)" is an essence atom now (A2 made them real).
- Every atom carries a `text` the cards show ("kills from behind"). Event names come from `Events.ALL`; tags a gate uses come from `Deeds.TAGS`.
- `Deeds.RESERVED` lists the events and tags with no emitter yet; each later piece (items, bonds, areas) removes its own, and the last piece asserts the list is empty.
- No push. No attribution lines in commits.

## Review Focus

- A form whose gate holds only reserved atoms is unreachable until its piece lands, but never errors; `--form=` and the goddess's menu still start any form.
- A kill with no player (an enemy killed by a trap, a fall) and a double kill in one frame emit `defeated` once each and never crash.
- Streaks reset: a hit taken between two kills restarts a no-damage streak, a miss restarts a perfect-hit streak.
- A gate atom with an event or tag nobody declared fails validation, not play.
- Offering a form of the wrong species, or a stage-3 form whose parent is not the current form, is impossible.

---

### Task 1: The gate: vocabulary, atoms and evaluation

**Files:**
- Create: `scripts/forms/form_gate.gd`, `scripts/core/deeds.gd`
- Modify: `scripts/core/events.gd`, `scripts/forms/form_def.gd`, `scripts/forms/form_validator.gd`, `scripts/skills/skill_rules_engine.gd`
- Test: `tests/test_form_gate.gd`

**Interfaces:**
- Produces: `Events.DEFEATED`, `GUARD_BROKEN`, `BARRIER_BROKEN`, `HIDDEN_FOUND`, `ROOM_CLEARED`, `ROOM_ENTERED`, `SKILL_HIT`, `SKILL_MISSED`, `SWITCH_HIT` and the reserved `GRAFT_ATTACHED`, `GRAFT_SHED`, `BOND_FORMED`, `LESSON_LEARNED`, `TRAP_SPRUNG`, `WEAPON_FORGED`, `ITEM_STOLEN`, `WARD_STONE_PLACED`, `PREY_COCOONED`, `GAP_CROSSED`, `LAMP_DRUNK`, `VILLAGE_KEPT`, `ROOM_HELD`, `VIGIL_KEPT`, `CORPSE_LEFT`, `ITEM_CARRIED` (all in `Events.ALL`); `Deeds.TAGS: Dictionary` (event -> allowed tag keys), `Deeds.RESERVED: Dictionary` (event or `event.tag` -> the piece that supplies it); `FormDef.gate: Array`; `SkillRulesEngine.condition_value(c: Dictionary) -> int` (public `_current`, also answering `held`); `FormGate.met(def: FormDef, rules) -> bool`, `FormGate.progress(def, rules) -> Array` of `{"text", "have", "need", "met"}`, `FormGate.summary(def, rules) -> String` ("dark 8/26, kills from behind 2/5"), `FormGate.validate(def) -> PackedStringArray`.

- [ ] **Step 1: Write the failing tests** in `tests/test_form_gate.gd` with a stub `rules` (a `SkillRulesEngine` fed events through `handle_event`, as the engine's own tests do): a counter atom is met at its `n` and not before; a `reset_counter` atom restarts at the reset event; `skill_level` needs the skill owned; `held` reads `held(element)` (absorbed minus spent); `any` is met when one member is and its progress is the best member's; a gate is met only when every atom is; `progress` returns one row per atom with `have` capped at `need`; `summary` lists unmet atoms first; an empty gate is met; `validate` rejects an unknown event, an event used with a tag `Deeds.TAGS` does not allow, `n < 1`, a missing `text`, an unknown kind, an `any` with no members, and accepts a reserved event; `FormValidator.validate` includes a form's gate errors; `Deeds.TAGS` has an entry for every new non-reserved event and `Deeds.RESERVED` names only events in `Events.ALL`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_gate`. Expected: FAIL (classes missing).
- [ ] **Step 3: Implement** the constants and registries, `FormDef.gate` (an `@export var gate: Array`), `condition_value`, and `FormGate` (the `any` kind is handled in `FormGate`, the rest by `condition_value`).
- [ ] **Step 4: Run** the same command, then `test_form_validator`, `test_events`, `test_constants`, `test_skill_rules_engine`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: a form's gate, the deed events and the way to read them`.

### Task 2: Kill deeds

**Files:**
- Create: `scripts/core/deed_tags.gd`
- Modify: `scripts/enemies/enemy.gd`, `scripts/player/player.gd`, `scripts/game.gd`, `scripts/skills/creature_def.gd`, `tools/build_creatures.py`
- Test: `tests/test_deed_tags.gd`, `tests/test_defeated.gd`

**Interfaces:**
- Consumes: Task 1's `Events.DEFEATED`, `Deeds.TAGS`.
- Produces: `Enemy.last_blow: Dictionary` ({"from_behind", "distance", "damage_type", "cause", "marked", "alert", "fleeing"}), `DeedTags.for_defeat(def: CreatureDef, blow: Dictionary, ctx: Dictionary) -> Dictionary` (pure; `ctx` is {"ceiling", "dark"}), `Player.note_defeat(enemy: Enemy) -> void` (emits `defeated`), `CreatureDef.species` set for the three base support monsters.

- [ ] **Step 1: Write the failing tests.** `DeedTags.for_defeat` (pure, table-driven): a tackle from behind sets `behind`; a blow from more than `DeedTags.RANGED_PX` away sets `ranged`; `damage_type == "poison"` sets `poison`; a def with `max_hp >= DeedTags.HEAVY_HP` sets `heavy`; a marked target sets `marked`; a blow on an enemy that was not alert sets `unseen`; a target moving away sets `fleeing`; `ctx.ceiling` and `ctx.dark` pass through; false flags are left out; `source` is the def id and `species` is set only when the def has one. `test_defeated.gd` with real nodes: an enemy killed by a tackle from behind makes the player's ledger count `defeated {behind: true}` once; two enemies downed in the same frame count twice; an enemy downed with no recorded blow counts with no flags and does not crash; eating a goblin base counts `predated {species: "goblin"}`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_deed_tags test_defeated`. Expected: FAIL.
- [ ] **Step 3: Implement.** `Enemy` records `last_blow` in `receive_hit` and `receive_tackle` (before the damage) and `marked` from the `verb_marks` meta the mark verb sets on its target; `Game._spawn` calls `player.note_defeat(node)` from `downed`; `Player.note_defeat` emits `Events.DEFEATED` with `DeedTags.for_defeat(def, blow, {ceiling: the spider body's surface is the ceiling, dark: the area's ambient is dark})`; the generator sets `species` on `wild_slime` (slime), `skeleton` (undead) and `village_goblin` (goblin); `Player._complete_predation` adds the creature's `species` to `predated`.
- [ ] **Step 4: Run** the tests above and `test_enemy_ai`, `test_enemy_verb`, `test_menagerie_data`, `tools/test_build_creatures.py`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: a kill says how it was made`.

### Task 3: The other deeds that exist now

**Files:**
- Modify: `scripts/enemies/enemy.gd`, `scripts/abilities/verb_kinds.gd`, `scripts/world/world.gd`, `scripts/game.gd`, the shortcut switch feature
- Test: `tests/test_deeds_world.gd`

**Interfaces:**
- Consumes: Task 1's events. Produces: emitters for `guard_broken`, `barrier_broken`, `hidden_found`, `room_cleared {room, alone}`, `room_entered {room, area}`, `skill_hit {id}`, `skill_missed {id}`, `switch_hit {far}`.

- [ ] **Step 1: Write the failing tests** (real nodes, events read from the player's ledger): a weak-point tackle on an armored enemy emits `guard_broken` once; a dissolve verb cast over a `dissolvable` node emits `barrier_broken` and over nothing emits nothing; a reveal verb that shows a `hidden` node emits `hidden_found` once per node; downing the last enemy of a room emits `room_cleared {alone: true}` (with `alone` false while a companion is out, tested with a flagged ally node); entering a room emits `room_entered` with its id and area; a strike verb that finds a target emits `skill_hit {id}` and one that finds none emits `skill_missed {id}`; a switch struck from 200 px or more away emits `switch_hit {far: true}`, from near it emits `{}`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_deeds_world`. Expected: FAIL.
- [ ] **Step 3: Implement** each emitter at the one place the thing already happens (the weak-point branch of `receive_tackle`; `VerbKinds._dissolve` and `_reveal`; `World` on room entry and on the last `downed`; `VerbKinds._strike`; the switch's `receive_hit`). Each goes through the player's emit callable, so it lands in the ledger.
- [ ] **Step 4: Run** `test_deeds_world`, `test_verb_kinds`, `test_verb_movers`, `test_world`, `test_enemy_behaviour`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the deeds a form can ask for that the game already has`.

### Task 4: The gates of all 99 forms

**Files:**
- Create: `tools/form_gates.json`, `tools/build_form_gates.py`, `tools/test_build_form_gates.py`
- Modify: `tools/build_species_forms.py` (calls the gate writer), `data/forms/*.tres` (generated), `tests/test_form_data.gd` or the nearest forms-data test
- Test: `tools/test_build_form_gates.py`, `tests/test_form_gates_data.gd`

**Interfaces:**
- Consumes: Tasks 1 to 3's vocabulary. Produces: `build_form_gates.rows() -> list[dict]`, `gate_for(row, form) -> list[dict]` (essence atoms from `reads` and the stage total, then the row's deed atoms), `write(out_dir)`; `form_gates.json` rows `{"form": data id, "atoms": [atom, ...]}` with the deed atoms only.

- [ ] **Step 1: Write the failing tests.** Python: one row per non-slime form and no others; each atom validates against `Deeds`/`Events` (an unknown event or tag fails); the generated gate for every form has one essence atom per `reads` entry with `n = ceil(total / len(reads))` for its stage; "later" elements are essence atoms; the number of reserved atoms per form is listed and each reserved event is in `Deeds.RESERVED`; the written text equals what is checked in (`write` is idempotent). GUT: every form of the four species has a non-empty gate, every gate validates, every wolf, undead, spider and goblin gate's essence atoms read only that form's `reads`, and `Deeds.RESERVED` is exactly the events the data uses that no emitter supplies (the burn-down list).
- [ ] **Step 2: Run** both. Expected: FAIL.
- [ ] **Step 3: Author `tools/form_gates.json`** from the design doc's Opened-by column, one row per form, using: `defeated` with `behind`, `ranged`, `marked`, `poison`, `heavy`, `ceiling`, `dark`, `unseen`, `fleeing`; `reset_counter` of `defeated` reset on `damaged` (no-damage streak), of `skill_hit` reset on `skill_missed` (perfect-hit streak); `counter skill_used {id: <the parent's or the named verb>}` for "Rise used many times", "a Howl power" and the other powers; `guard_broken`, `barrier_broken`, `hidden_found`, `room_cleared {alone}`, `room_entered`, `switch_hit {far}`, `predated {species or source}` for eating goblins and the Taratect; `held {element}` for a full cap; the reserved events for grafts, bonds, lessons, traps, forging, theft, ward-stones, cocoons, gaps, lamps, a kept village, rooms held, a Vigil. An atom the text does not pin down is mapped to the nearest event and the choice is written in the row's `note`. Implement `build_form_gates.py` and run it; run `godot --headless --import` twice.
- [ ] **Step 4: Run** the Python and GUT tests above plus `test_forms_data`, `test_species_data`, `test_content`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: every non-slime form has its gate as data`.

### Task 5: Offers and the cards

**Files:**
- Modify: `scripts/forms/form_offers.gd`, `scripts/player/player.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/skill_screen.gd`, `scripts/ui/skill_tree_model.gd`
- Test: `tests/test_form_offers_gates.gd`, `tests/test_form_tab.gd`, `tests/test_skill_tree_model.gd`

**Interfaces:**
- Consumes: `FormGate`. Produces: `FormOffers.offers` filtering a non-slime form's children by `FormGate.met`; `FormOffers.locked(forms, form, rules) -> Array` (the children whose gate is not met); `form_card` gains `opened_progress: String` (the `FormGate.summary`); the Form tab lists locked children under the offers with their summary.

- [ ] **Step 1: Write the failing tests:** a wolf at stage 1 is offered only the stage-2 forms whose gates its ledger meets (feed it `absorbed {dark}` events and a `defeated {behind}` kill to open Black Dog, and nothing else); a stage-3 form is offered only when its gate is met and only as a child of the current form; a form with a reserved-only gate is never offered and shows in `locked`; the slime's offers are unchanged; the Form tab shows the offered forms and the locked ones with "dark 8/26, kills from behind 2/5"; `form_card` carries the summary; `become_form` and the goddess's menu still reach any form without a gate.
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_offers_gates test_form_tab test_skill_tree_model`. Expected: FAIL.
- [ ] **Step 3: Implement** the filtering in `FormOffers.offers`, `locked`, the card field and the tab rows; the Tree tab names a non-slime stage-2 form once its gate has any progress or it is reached.
- [ ] **Step 4: Run** those and `test_form_offers`, `test_evolution_flow`, `test_player`, `test_species_*`. Expected: PASS, after updating the tests that assumed every stage-2 form of another species is on offer (ledger the ruling).
- [ ] **Step 5: Commit** `feat: a form is offered when its gate is met, and the card says what is missing`.

### Task 6: Docs and the full run

**Files:**
- Modify: `docs/research/species-form-branches.md`, `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md`

- [ ] **Step 1: Update** the design doc's status (gates are data and enforced; the reserved list and which piece supplies each) and the roadmap (a new H1 row, built).
- [ ] **Step 2: Run** `TEST_TIMEOUT=1700 tools/run_tests.sh` and the Python tests. Expected: PASS.
- [ ] **Step 3: Commit** `docs: form gates in the roadmap and the design doc`.
