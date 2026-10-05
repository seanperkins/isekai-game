# The verb framework (C1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A form's verb can be written as data: a skill whose active effect carries a small `spec` ({"kind": "bolt", ...}) that one generic ability turns into behaviour, so a verb needs no new script. A form grants its verb on arrival and the verb replaces its parent form's in the active slot.

**Architecture:** `Ability` gains `spec`; `SkillEffects.active_spec(def)` reads it from the effect and `Player._ability` hands it over. `VerbAbility` (one scene, one script) runs `VerbKinds.run(ability, spec)`, a table of nine primitives built on the existing `Ability` helpers (`targets_in_front`, `targets_around`, `terrain_hit`), `SporeCloudArea` for zones and `Vfx`. A new skill source `form_verb` is granted by forms, never unlocked, and kept out of the Compendium. `FormDef.verb` names a form's verb so `Player.advance_form` can swap it for the previous form's.

**Tech Stack:** Godot 4.7 GDScript, GUT.

**Spec:** `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md` (C1) and `docs/research/species-form-branches.md` (the Verb column).

## Global Constraints

- Baseline 2680 tests on `main` (the shipped art in the main checkout breaks two bestiary tests there until the art is built into the page; this worktree has no art).
- The nine kinds and their parameters, exactly: `bolt` {range 260, half_width 20, pierce true}, `burst` {range 60, half_width 40}, `ring` {radius 72}, `dash` {speed 500, vertical 0.6, hit_range 40, hit_half_width 24}, `zone` {radius 60, seconds 3, slow bool, heals int, damage bool}, `mark` {range 200, delay 4.0}, `heal` {hp 0, mp 0}, `ward` {seconds 2.0}, `buff` {stats {stat: amount}, seconds 5.0}. Damage kinds also take `damage_type` (default `"physical"`) and `status` ({"slow": seconds, "stun": seconds}).
- Damage is `Damage.skill_power(value(), actor_atk())` with `value()` from the effect's `values`.
- A `form_verb` skill needs no `unlock`, has `mp_cost > 0`, `max_level 1` and is never in the Compendium, the rebirth kit or the tablet hints.
- No existing skill's data or behaviour changes.

## Review Focus

- A spec with an unknown kind, a missing required value or a non-number where a number belongs fails validation, not at cast time. (Task 2)
- A bolt, burst or ring never hits the caster's team, and a dead or freed target in a delayed mark does not crash. (Tasks 1, 2)
- Evolving twice: the second verb replaces the first in the same slot, and the slot count never exceeds four. (Task 3)
- A form with no verb evolves exactly as before. (Task 3)
- `form_verb` skills never appear as unknown entries in the Compendium or in a rebirth kit's eligible powers. (Task 3)

---

### Task 1: `Ability.spec` and the damage kinds

**Files:**
- Create: `scripts/abilities/verb_ability.gd`, `scripts/abilities/verb_kinds.gd`, `scenes/abilities/verb.tscn`
- Modify: `scripts/abilities/ability.gd`, `scripts/core/skill_effects.gd`, `scripts/player/player.gd` (`_ability`)
- Test: `tests/test_verb_kinds.gd` (new)

**Interfaces:**
- Produces: `Ability.spec: Dictionary`; `SkillEffects.active_spec(def: SkillDef) -> Dictionary`; `class_name VerbAbility extends Ability`; `VerbKinds.KINDS: Array`; `static func VerbKinds.run(ability: Ability, spec: Dictionary) -> void`.

- [ ] **Step 1: Write failing tests** (a `FakeActor` as in `tests/test_abilities.gd`, with `health`-less foes recording `receive_hit(raw, type, from, cause)` and `slow_for(seconds)`): `test_active_spec_is_read_from_the_effect` (a SkillDef with `effects = [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [4], "spec": {"kind": "bolt"}}]` gives `{"kind": "bolt"}`; a def without one gives `{}`); `test_a_bolt_pierces_everything_in_front_within_its_range` (foes at x 40, 120, 300 and one behind and an ally: the two in range take `[4, "physical"]`, the others nothing); `test_a_bolt_that_does_not_pierce_hits_the_nearest_only`; `test_a_burst_hits_a_short_wide_area_in_front`; `test_a_ring_hits_every_foe_within_its_radius_and_not_the_ally`; `test_a_status_slows_what_it_hits` (`status {"slow": 2.0}` calls `slow_for(2.0)`); `test_the_damage_type_is_the_specs` (`damage_type "poison"`); `test_an_unknown_kind_does_nothing_and_does_not_crash`. Each builds `VerbAbility` from `res://scenes/abilities/verb.tscn`, sets `spec`, `setup(actor, [4], 1)` and calls `activate()`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_verb_kinds`. Expected: FAIL.
- [ ] **Step 3: Implement** the three kinds in `VerbKinds` (damage helper `_strike(ability, targets, spec)` applies power, type, status), `VerbAbility._perform()` calling `VerbKinds.run(self, spec)`, the scene, `Ability.spec`, `active_spec`, and `Player._ability` setting `node.spec`.
- [ ] **Step 4: Run** `tools/run_tests.sh test_verb_kinds` and `tools/run_tests.sh test_abilities`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "feat: a verb as data: bolt, burst and ring"`.

### Task 2: The other six kinds and spec validation

**Files:**
- Modify: `scripts/abilities/verb_kinds.gd`, `scripts/player/player.gd` (`ward`)
- Test: `tests/test_verb_kinds.gd`

**Interfaces:**
- Produces: kinds `dash`, `zone`, `mark`, `heal`, `ward`, `buff`; `static func VerbKinds.validate(spec: Dictionary) -> PackedStringArray` (messages: `"unknown verb kind 'x'"`, `"<kind>: <key> must be a number"`, `"<kind>: unknown key '<key>'"`, `"buff: stats must be a dictionary of stat id to number"`); `Player.ward(seconds: float) -> void` (raises `_invuln` to at least `seconds`).

- [ ] **Step 1: Write failing tests:** `test_a_dash_launches_the_caster_and_hits_what_is_in_its_way` (impulse `Vector2(500, 0)` for aim right; a foe 30 px ahead takes the damage); `test_a_zone_spawns_a_cloud_that_slows` (a `SporeCloudArea` appears under the actor's parent); `test_a_mark_hits_the_nearest_foe_after_its_delay_and_survives_its_death` (use `get_tree().create_timer` driven by `await wait_seconds(0.2)` with `delay 0.1`; a second case frees the foe first); `test_heal_restores_hp_and_mp` (an actor with `health` and `mana`); `test_ward_makes_the_caster_untouchable` (a real `Player`: `ward(1.0)` then `receive_hit` does nothing); `test_buff_adds_a_stat_modifier_and_removes_it_when_it_ends` (a real `Player`: `spd` rises then returns); `test_validate_accepts_every_default_spec` (one minimal spec per kind validates empty); `test_validate_reports_the_exact_messages`.
- [ ] **Step 2: Run, expect FAIL; Step 3: implement; Step 4: run `tools/run_tests.sh test_verb_kinds`, expect PASS; Step 5: commit** `git commit -am "feat: dash, zone, mark, heal, ward and buff verbs, and spec validation"`.

### Task 3: The `form_verb` source and a form's verb

**Files:**
- Modify: `scripts/skills/def_validator.gd`, `scripts/compendium/compendium_model.gd`, `scripts/soul/head_start.gd`, `scripts/forms/form_def.gd`, `scripts/forms/form_validator.gd`, `scripts/player/player.gd` (`advance_form`), `scripts/ui/skill_screen_model.gd` if it lists unknown skills
- Test: `tests/test_form_verbs.gd` (new)

**Interfaces:**
- Produces: skill source `"form_verb"` (in `DefValidator.SOURCES`; exempt from the unlock rule; its active `spec` validated with `VerbKinds.validate`); `FormDef.verb: String` (a skill id; `FormValidator` checks it names a `form_verb` skill and is in `grants`); `advance_form` swaps the previous form's verb for the new one in the same slot.

- [ ] **Step 1: Write failing tests** with fixture skills built in memory (`TestDefs.skill` with `source = "form_verb"`, an active effect with a bolt spec, `mp_cost = 2`) and fixture forms added to a `Player`'s `forms`: `test_a_form_verb_skill_validates_without_an_unlock`; `test_a_form_verb_with_a_bad_spec_is_reported`; `test_the_compendium_has_no_slot_for_a_form_verb`; `test_a_rebirth_kit_never_offers_a_form_verb` (`HeadStart.eligible_powers`); `test_evolving_into_a_form_grants_its_verb_into_a_slot` (the verb is owned and in `skillset.slots`); `test_using_the_verb_spends_mp_and_hits_a_foe` (an `Enemy` in front takes the bolt); `test_the_next_form_replaces_the_verb_in_the_same_slot` (evolve twice: one slot id changed from verb A to B, `slots.owned` lacks A, four slots at most); `test_a_form_without_a_verb_evolves_as_before` (the slot list is unchanged); `test_form_validator_checks_the_verb_is_granted_and_known`.
- [ ] **Step 2: Run, expect FAIL; Step 3: implement** (the compendium and kit filters mirror `enemy_only`; `advance_form` calls `skillset.slots.replace(old, new)` before granting, only when both ids are non-empty); **Step 4: run** `tools/run_tests.sh`, expect `PASS`; **Step 5: commit** `git add -A && git commit -m "feat: a form grants its verb and the next form's verb takes its slot"`.
