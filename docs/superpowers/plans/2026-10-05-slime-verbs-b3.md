# The slime's form-4 verbs (B3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each of the slime's 17 new stage-4 forms that has a verb (Bind, Recall, Stalk, Shed, Maelstrom, Flood, Dissolve, Contagion, Network, Guardian, Transmute, Engulf, Copy, Hurl, Ride, Pseudopod, Court) grants it on arrival and it works on an enemy in a test. Quicksilver Slime has no verb: it is a body (fast, near-immune, flees).

**Architecture:** The C1 framework (a `form_verb` skill whose active effect carries a `spec` that `VerbKinds` runs) gains the kinds the verbs need. A table `tools/form_verbs.json` (form id to name, cost, damage value, spec, fidelity) is the one source: `tools/build_form_verbs.py` writes `data/skills/verb_<form>.tres`, and `tools/build_species_forms.py` writes `verb` and the grant into each form. C2 (the other species) adds rows to the same table.

**Tech Stack:** Godot 4.7 GDScript, GUT, Python 3 (generators).

**Spec:** `docs/research/species-form-branches.md` section 8 (the Verb and Gives-up columns) and `docs/superpowers/plans/2026-10-05-verb-framework-c1.md`.

## Global Constraints

- Baseline 2719 tests on `main` (feb6230).
- A verb's text in the design doc is the intent; each table row carries `fidelity`: `full` (does what the text says), `approx` (does the part a test can see, the rest waits for a system that does not exist yet) or `needs` (names that system). `note` says what is missing. The Tree tab keeps showing `verb_text`.
- New spec keys are validated by `VerbKinds.validate` (`SCHEMA`), numbers are numbers, and a bad spec fails the data check, not the cast.
- Damage is `Damage.skill_power(value(), actor_atk())`; a verb with value 0 does no damage. No existing skill's data or behaviour changes (`SporeCloudArea` keeps poison as its default type).
- A verb with nothing in range spends its MP and does nothing; it never errors.
- Quicksilver Slime keeps `verb = ""` and evolves exactly as before.

## Review Focus

- Every verb cast with no foe in range, and every delayed or timed effect (pull field, engulf digest, summoned allies, vine, husk) after its target or the caster is freed, does not error. (Tasks 2, 3)
- A rooted enemy cannot act and cannot be eaten; the root ends; it works on a non-predatable boss. (Task 1)
- A verb's own cooldown (Bind's eight seconds) is honoured and a recast before it costs nothing. (Task 1)
- Nodes a verb spawns (field, ally, vine, husk) end on their own timer and are freed with their room. (Tasks 2, 3)
- Transmute never takes essence it does not hold or leaves a negative count. (Task 4)

---

### Task 1: Cooldown, root, the verb table and three plain verbs

**Files:**
- Create: `tools/form_verbs.json`, `tools/build_form_verbs.py`, `tools/test_build_form_verbs.py`, `tests/test_slime_verbs.gd`, `data/skills/verb_gleipnir.tres`, `verb_shoggoth.tres`, `verb_poltergeist.tres` (generated)
- Modify: `scripts/abilities/verb_kinds.gd` (`cooldown` key, `root` status), `scripts/abilities/verb_ability.gd`, `scripts/enemies/enemy.gd` (`root_for`), `tools/build_species_forms.py` (`verb`, grant), `data/forms/{gleipnir,shoggoth,poltergeist}.tres` (regenerated), `scripts/forms/form_def.gd` comment
- Test: `tests/test_verb_kinds.gd`, `tests/test_slime_verbs.gd`

**Interfaces:**
- Produces: spec keys `cooldown` (seconds, any kind) and status `root` (seconds); `Enemy.root_for(seconds: float) -> void`; `Enemy.is_rooted() -> bool`; `form_verbs.json` rows `{"form": id, "name", "mp", "value", "spec", "fidelity", "note"}` (a list); `build_form_verbs.load_rows() -> list`, `skill_tres(row) -> str`, `build(out="data/skills") -> list of skill ids`; the skill id is `verb_<form>`.

- [ ] **Step 1: Write failing tests.** `test_verb_kinds`: `test_a_spec_cooldown_replaces_the_default` (a verb with `cooldown 5` is not `ready()` after `activate()` for 4 s of `_process`, and is after 5); `test_validate_accepts_cooldown_and_root_and_rejects_text` (`cooldown: "long"` gives `"bolt: cooldown must be a number"`, `status {"root": 2}` is valid). Enemy test (`tests/test_slime_verbs.gd`, real `Enemy` from `res://data/creatures` via `TestDefs`-free `EnemyScene`, as `tests/test_enemy_*` does): `test_a_rooted_enemy_does_not_act_and_is_not_edible` (a non-predatable boss rooted for 1 s stays put while the player stands in chase range, `can_be_predated()` false, then moves after `wait_seconds(1.2)`); `test_root_works_through_a_bind_bolt` (Gleipnir's verb cast at a foe roots it). Data tests: `test_each_verb_row_has_a_form_and_a_skill` (every row's form file exists with `verb = "verb_<form>"` in `grants`), `test_the_data_validates` (`DefValidator.validate` on `res://data/skills` + creatures is empty, `FormValidator.validate` with the form_verb ids is empty), `test_a_form_without_a_row_has_no_verb` (Quicksilver, and any of the 24 built forms). Python: `test_rows_name_known_forms_and_fidelity`, `test_skill_tres_is_a_form_verb_with_the_spec`, `test_a_form_gets_its_verb_and_grant`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_verb_kinds` and `test_slime_verbs`, and `python3 -m unittest tools.test_build_form_verbs`. Expected: FAIL.
- [ ] **Step 3: Implement.** `VerbKinds.SCHEMA` gains a common `cooldown`; `STATUSES` gains `root`; `_apply_status` calls `t.root_for(seconds)` when present. `VerbAbility._perform` sets `_cooldown` to the spec's cooldown after running. `Enemy`: a `_root` timer decremented in `_physics_process`, `active` is false while it runs (so the AI, the contact hit and the eat are off, like a stun that is not edible and works on `predatable == false`); `status` is not changed. The generator and table: rows for `gleipnir` (Bind: `bolt` range 160, half_width 24, pierce false, `status {root: 4.0}`, cooldown 8, mp 8, value 2), `shoggoth` (Pseudopod: `bolt` range 150, half_width 12, mp 3, value 5), `poltergeist` (Hurl: `bolt` range 220, half_width 14, pierce false, mp 4, value 6). Then `python3 tools/build_form_verbs.py && python3 tools/build_species_forms.py` and import twice.
- [ ] **Step 4: Run** the suites above and `tools/run_tests.sh test_form`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: a verb table, a cooldown and a root, and Bind, Pseudopod and Hurl"`.

### Task 2: Fields, chains and dissolving

**Files:**
- Create: `scripts/abilities/verb_field.gd` (a `Node2D` built in code, no scene), `tests/test_verb_fields.gd`
- Modify: `scripts/abilities/verb_kinds.gd`, `scripts/abilities/spore_cloud_area.gd` (`damage_type` option, default `"poison"`), `tools/form_verbs.json`, regenerated data
- Test: `tests/test_verb_fields.gd`

**Interfaces:**
- Produces: kinds `pull` {radius 96, seconds 3, strength 90, damage bool, damage_type, ahead 70}, `aura` {radius 60, seconds 6, damage bool, damage_type}, `chain` {range 160, jump 80, hops 3, damage_type}, `engulf` {range 40, seconds 3}, `dissolve` {range 60, half_width 40}; `zone` gains `damage_type`; `VerbField` (`Node2D`, `launch(actor, spec, power)`); the group `dissolvable` (nodes with `dissolve()`).

- [ ] **Step 1: Write failing tests** (stub foes as in `test_verb_kinds`; a real `Enemy` where the AI matters): `test_a_pull_field_draws_foes_toward_its_centre` (a foe 60 px off the centre is nearer after 0.5 s; one outside the radius is not moved; a foe freed mid-field does not error); `test_a_pull_field_ticks_damage_once_a_second` (`damage true`: two ticks over 2.1 s, none when false); `test_an_aura_follows_the_caster_and_hurts_what_is_near` (the caster moves 100 px, a foe at the new spot takes a tick, an ally does not); `test_an_aura_ends_with_its_caster` (freeing the caster frees the aura); `test_a_chain_jumps_to_the_nearest_foe_not_yet_hit` (foes at 40, 100, 160, 400 px: three hops hit the first three once each, the fourth is out of jump range); `test_a_chain_with_nothing_in_range_does_nothing`; `test_engulf_stuns_the_nearest_predatable_foe_and_digests_it` (a real enemy: stunned, `hp` falls once a second for `seconds`, not eaten, a non-predatable boss is skipped); `test_dissolve_ignores_armour_and_opens_a_dissolvable` (an armoured enemy takes the full value, a `dissolvable` node's `dissolve()` is called, an ordinary node in range is hit normally); `test_a_zone_can_deal_its_own_damage_type` (`damage_type "water"` reaches `receive_hit` as `"water"`; the default stays `"poison"`; validate accepts the key on a zone).
- [ ] **Step 2: Run** `tools/run_tests.sh test_verb_fields`. Expected: FAIL.
- [ ] **Step 3: Implement** the kinds. `VerbField` runs in `_physics_process`: it follows the caster when asked, pulls each living foe with `move_and_collide` toward the centre, ticks damage each whole second, frees itself at the end or when the caster is gone. `chain` is instant. `engulf` stuns with `status.stun(seconds)` and a child `Timer`-free digest in a `VerbField`-style node (one tick a second, `ignore_def`). `dissolve` strikes the burst area with `ignore_def` for an `Enemy` and calls `dissolve()` on `dissolvable` nodes. Rows: `kraken` (Maelstrom: `pull`, damage true, damage_type water, mp 8, value 2, cooldown 6), `tiamat` (Flood: `zone` radius 120, seconds 6, slow, damage_type water, mp 7, value 0, cooldown 8; `approx`: it slows, it does not fill the room with swimmable water), `alkahest` (Dissolve: mp 5, value 6), `pestilence` (Contagion: `chain` poison, mp 6, value 3), `slime_mold` (Network: `zone` radius 140, seconds 8, slow, mp 5; `approx`: no route display), `talos` (Guardian: `aura` radius 60, seconds 6, damage true, mp 7, value 2, cooldown 10; `approx`: no weak-point nail), `cube` (Engulf: mp 6, value 2).
- [ ] **Step 4: Run** `tools/run_tests.sh test_verb_fields`, `test_slime_verbs`, `test_zone`, `test_form`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: pull, aura, chain, engulf and dissolve verbs, and Maelstrom, Guardian, Contagion, Engulf, Dissolve, Flood and Network"`.

### Task 3: Movement, a decoy, allies and a vine

**Files:**
- Create: `scripts/abilities/verb_ally.gd`, `scripts/abilities/verb_vine.gd`, `tests/test_verb_movers.gd`
- Modify: `scripts/abilities/verb_kinds.gd`, `scripts/player/player.gd` (`glide`), `tools/form_verbs.json`, regenerated data
- Test: `tests/test_verb_movers.gd`

**Interfaces:**
- Produces: kinds `glide` {seconds 1.5, fall 40}, `anchor` {}, `decoy` {seconds 1.2, speed 360, ward 0.6}, `summon` {count 3, seconds 10}, `vine` {height 160, seconds 10}; `Player.glide(seconds: float) -> void`; `VerbAlly` (`Node2D`), `VerbVine` (`Node2D` with one-way `StaticBody2D` steps).

- [ ] **Step 1: Write failing tests:** `test_glide_caps_the_fall_speed_for_its_time` (a real player in the air with `velocity.y` 300 falls no faster than `fall` while gliding, and falls normally after `seconds`); `test_a_recall_lays_a_mark_then_returns_to_it` (first cast: the actor does not move and a mark is set; the second, after moving 200 px, puts it back on the mark and clears it; a third lays a new one); `test_a_shed_leaves_a_husk_and_slips_away` (a husk node at the old spot, the caster is warded for `ward` seconds, an impulse away from its facing); `test_a_summon_spawns_allies_that_hit_the_nearest_foe_and_expire` (three allies, a foe near them takes hits, after `seconds` all are gone, a fourth cast never leaves more than `count`); `test_allies_never_hit_their_own_team_or_the_caster`; `test_allies_are_freed_with_their_caster`; `test_a_vine_makes_one_way_steps_that_a_body_can_land_on_and_then_goes` (steps at `height/4` spacing in group `verb_vines`, a falling body stops on one, nothing remains after `seconds`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_verb_movers`. Expected: FAIL.
- [ ] **Step 3: Implement.** `Player.glide` sets a timer; in `_physics_process` after gravity, while it runs and the body is falling, `velocity.y` is capped. `anchor` keeps the mark in actor meta `verb_anchor`. `decoy` adds a fading copy of the actor's sprite (`Vfx.puffs` and a sprite node) and calls `ward`, `apply_impulse`. `VerbAlly` walks along the floor toward the nearest foe and strikes it every 0.8 s for `Damage.skill_power(value, atk)`. `VerbVine` builds `height / 40` one-way steps on the floor under the actor. Rows: `cloud_rider` (Ride: glide, mp 3, `approx`: a plain glide, no cloud drawn), `ariadne` (Recall: anchor, mp 4, `approx`: it returns in one step, not along the trail), `selkie` (Shed: decoy, mp 6, cooldown 10, `approx`: enemies are not drawn to the husk), `king_slime` (Court: summon, mp 8, value 2, cooldown 12, `approx`: allies cannot be hurt), `beanstalk` (Stalk: vine, mp 6, cooldown 6).
- [ ] **Step 4: Run** `tools/run_tests.sh test_verb_movers`, `test_slime_verbs`, `test_player`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: glide, recall, shed, court and stalk verbs"`.

### Task 4: Essence, copying and the record

**Files:**
- Modify: `scripts/abilities/verb_kinds.gd`, `scripts/player/player.gd` (remember the last appraised creature), `tools/form_verbs.json`, regenerated data, `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md`, `docs/research/species-form-branches.md` (a fidelity note)
- Test: `tests/test_verb_essence.gd`

**Interfaces:**
- Produces: kinds `transmute` {from_units 3, to_units 2} and `copy` {seconds 8}; `Player.last_inspected: CreatureDef` (null until something is appraised).

- [ ] **Step 1: Write failing tests:** `test_transmute_turns_the_most_held_element_into_the_least_held` (a rules engine holding water 5, earth 0: after a cast water 2, earth 2; held counts are never negative); `test_transmute_with_less_than_the_cost_does_nothing`; `test_copy_takes_the_last_appraised_creatures_stats_for_its_time` (`atk`/`def`/`spd` of the creature are added, and removed after `seconds`, surviving a skill refresh); `test_copy_with_nothing_appraised_does_nothing`; `test_every_slime_form_four_but_quicksilver_has_a_working_verb` (17 rows, each cast on a stub foe or the actor does something observable).
- [ ] **Step 2: Run** `tools/run_tests.sh test_verb_essence`. Expected: FAIL.
- [ ] **Step 3: Implement.** `transmute` reads `rules.held(e)` and calls `rules.spend_essence(from, from_units)` then emits `ABSORBED` for `to_units` of the target through the player's emit callback; ties by `Essences.ALL` order. `copy` uses `Stats.set_timed_modifiers` with the creature's `stats`. Rows: `philosophers_stone` (Transmute, mp 4, `approx`: no element chooser), `mimic` (Copy, mp 6, `needs`: the creature's own move arrives with the creature kits, F1). Mark B3 built in the roadmap and add the fidelity note to the design doc.
- [ ] **Step 4: Run** `tools/run_tests.sh test_verb_essence`, then the whole suite `TEST_TIMEOUT=1700 tools/run_tests.sh`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: transmute and copy verbs; every slime form-four has its verb"`.
