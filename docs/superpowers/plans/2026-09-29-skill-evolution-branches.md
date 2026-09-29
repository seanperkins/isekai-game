# Skill Evolution Branches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Sean's standing choice: native, inline). Steps use checkbox (`- [ ]`) syntax.

**Goal:** An evolved skill replaces the skill it evolved from, and every evolvable base skill offers two directions the player picks between (one is permanent for the life).

**Architecture:** Branch state is derived from `SkillRulesEngine._owned` plus each evolution's `replaces` (`is_retired`, `is_closed`, `siblings_of`), so nothing new is stored. Five engine edits enforce it; the validator makes every sibling share one `skill_level` unlock; the Skills tab shows the choices with a two-press confirm. Five new abilities are built on one shared piece, a general zone (`SporeCloudArea`), plus `Ability.terrain_hit` and existing target selection.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1. Tests: `tools/run_tests.sh [substr]` (whole suite about 185 s). Content is regenerated with `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd` (and `tools/build_forms.gd`).

**Spec:** `docs/superpowers/specs/2026-09-29-skill-evolution-branches-design.md` (debated, three rounds plus verification). Read it before Task 1; it is the authority.

## Global Constraints

- Evolutions are single-level: `max_level` 1, no `levels_on`, at most one `values` entry per active effect. Their unlock is exactly one `skill_level` condition on their `replaces`; siblings share its `n`.
- `owned()` means held now (retired parents excluded); `level_of(id)` means level reached (retired parents keep theirs).
- `grant()` refuses evolutions. Only `evolve()` takes one. Forms and kits grant base skills only.
- New MP costs: Binding Web 4, Miasma 5, Venom Bolt 5, Healing Spores 4, Puffball 5. Existing: Swing Thread 4, Water Blade 5, Jet Dash 5.
- Numbers: Binding Web patch radius 40, 4 s, damage 0, slowing; Miasma cone 56 at 9 damage plus a cloud radius 36, 3 s, 1 poison a second, no slow; Venom Bolt range 260, half-width 20, 9 poison; Healing Spores radius 40, 4 s, heals 1 a second; Puffball radius 64, 3 s, pod velocity `aim * 220 + Vector2(0, -150)`, gravity 600, at most 40 segments of 1/30 s.
- Commit messages carry no attribution lines. Each task ends with a commit; work in this worktree (`.worktrees/evo-branches`, branch `feat/evolution-branches`).
- After adding a `class_name`, scene or asset run `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1`.

## Review Focus

The inputs the spec implies that no task's own tests exercise most obviously, each pinned by a test in the named task:
1. A retired parent levelled by `recheck_levels()` after a stage-cap rise (Task 1).
2. A fast enemy crossing a web patch between one-second ticks (Task 5).
3. A `starting` evolution bypassing `grant()` (Task 2).
4. The "???" row lighting up for a retired parent (Task 4).
5. An upward Puffball lob that never lands inside the arc cap (Task 8).

## File Map

- Modify: `scripts/skills/skill_rules_engine.gd`, `scripts/skills/skill_def.gd`, `scripts/skills/def_validator.gd`, `scripts/world/rebirth_kit.gd`, `scripts/compendium/compendium_model.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/skill_screen.gd`, `scripts/forms/form_effects.gd`, `scripts/abilities/ability.gd`, `scripts/abilities/thread_ability.gd`, `scripts/abilities/spore_cloud_area.gd`, `scripts/enemies/enemy.gd` (a comment), `tools/build_content.gd`, `tools/build_forms.gd`, `data/audio/cues.json`, `tools/art/skill_icons_grotto_frames.json`, `docs/playtest-checklist.md`; regenerate `data/skills/*.tres`, `data/forms/*.tres`.
- Create: `scripts/abilities/binding_web.gd`, `miasma.gd`, `venom_bolt.gd`, `healing_spores.gd`, `puffball.gd` and their `scenes/abilities/*.tscn`; `assets/sprites/icon_<id>.png` x5; tests `tests/test_evolution_branches.gd`, `tests/test_evolution_screen.gd`, `tests/test_evolution_abilities.gd`, `tests/test_evolution_trees.gd`, `tests/test_zone.gd`.
- Tests that change: listed in Task 2 and Task 3.

---

### Task 1: Engine — retire the parent, close the siblings

**Files:** Modify `scripts/skills/skill_rules_engine.gd`; Create `tests/test_evolution_branches.gd`.

**Interfaces:**
- Produces: `SkillRulesEngine.is_retired(id) -> bool`, `is_closed(id) -> bool`, `siblings_of(id) -> Array`; `owned()` excludes retired ids; `grant()` returns false for evolutions.

- [ ] **Step 1: Write the failing tests** — create `tests/test_evolution_branches.gd`:

```gdscript
extends GutTest
## Evolutions replace their parent, and taking one branch closes its siblings.

var engine: SkillRulesEngine
var leveled: Array
var readied: Array

func _hydro() -> SkillDef:
	return TestDefs.skill("hydraulic_propulsion", {"source": "essence",
		"unlock": [TestDefs.counter("absorbed", 1, {"essence": "water"})],
		"levels_on": {"event": "skill_used", "tags": {"id": "hydraulic_propulsion"}}, "level_curve": 2, "max_level": 8})

func _evo(id: String, extra := {}) -> SkillDef:
	var f := {"source": "evolution", "replaces": "hydraulic_propulsion", "unlock": [TestDefs.level("hydraulic_propulsion", 2)]}
	f.merge(extra, true)
	return TestDefs.skill(id, f)

func _make() -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.report_error = func(msg: String) -> void: fail_test("unexpected engine error: " + msg)
	engine.setup([_evo("dash"), _evo("blade"), _hydro()])  # listener order must not matter
	leveled = []
	readied = []
	engine.skill_leveled.connect(func(id: String, lv: int) -> void: leveled.append("%s:%d" % [id, lv]))
	engine.evolution_ready.connect(func(id: String) -> void: readied.append(id))
	engine.start_run()

func _reach_level_2() -> void:
	engine.handle_event("absorbed", {"essence": "water"})
	for i in 2:
		engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})

func test_both_branches_become_ready_together() -> void:
	_make()
	_reach_level_2()
	assert_eq(engine.ready_evolutions().size(), 2)
	assert_true(engine.is_evolution_ready("blade") and engine.is_evolution_ready("dash"))
	assert_eq(engine.siblings_of("blade"), ["dash"])

func test_evolving_retires_the_parent_and_hides_it_from_owned() -> void:
	_make()
	_reach_level_2()
	assert_true(engine.evolve("blade"))
	assert_true(engine.owned().has("blade"))
	assert_false(engine.owned().has("hydraulic_propulsion"))
	assert_true(engine.is_retired("hydraulic_propulsion"))
	assert_eq(engine.level_of("hydraulic_propulsion"), 2, "level_of is the level reached")

func test_evolving_closes_the_siblings() -> void:
	_make()
	_reach_level_2()
	readied.clear()
	assert_true(engine.evolve("blade"))
	assert_true(engine.is_closed("dash"))
	assert_false(engine.is_closed("blade"))
	assert_false(engine.is_evolution_ready("dash"))
	assert_eq(engine.ready_evolutions(), [])
	assert_false(engine.evolve("dash"))
	assert_eq(readied, [], "no evolution_ready is emitted for the sibling during evolve()")

func test_a_retired_parent_does_not_level_through_recheck_levels() -> void:
	_make()
	engine.set_stage_cap(2)
	engine.handle_event("absorbed", {"essence": "water"})
	for i in 12:  # banks casts well past the cap: capped at level 2
		engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_eq(engine.level_of("hydraulic_propulsion"), 2)
	assert_true(engine.evolve("blade"))
	var gained := [-1]
	engine.rechecked.connect(func(n: int) -> void: gained[0] = n)
	leveled.clear()
	engine.set_stage_cap(5)  # what advance_form does, then recheck_levels()
	engine.recheck_levels()
	assert_eq(leveled, [], "the retired parent must not level")
	assert_eq(gained[0], 0)
	engine.handle_event("skill_used", {"id": "blade"})  # and one more cast does not catch it up either
	assert_eq(leveled, [])
	assert_eq(engine.level_of("hydraulic_propulsion"), 2)

func test_grant_refuses_an_evolution() -> void:
	_make()
	assert_false(engine.grant("blade"))
	assert_false(engine.grant("blade", false))
	assert_false(engine.owned().has("blade"))

func test_a_retired_parent_is_not_granted_again() -> void:
	_make()
	_reach_level_2()
	engine.evolve("blade")
	assert_false(engine.grant("hydraulic_propulsion"))
	engine.handle_event("absorbed", {"essence": "water"})
	assert_false(engine.owned().has("hydraulic_propulsion"))

func test_start_run_reopens_every_branch() -> void:
	_make()
	_reach_level_2()
	engine.evolve("blade")
	engine.start_run()
	assert_eq(engine.owned(), [])
	assert_false(engine.is_closed("dash"))
	assert_false(engine.is_retired("hydraulic_propulsion"))
```

- [ ] **Step 2: Run to see RED** — `tools/run_tests.sh test_evolution_branches`. Expected: parse errors naming `is_retired` / `siblings_of` (RED, the API does not exist).

- [ ] **Step 3: Implement** in `scripts/skills/skill_rules_engine.gd`.
  1. Beside `var _granted := {}` add `var _children := {}  # parent id -> evolution ids whose replaces is it`.
  2. In `setup`, after `_listeners.clear()` add `_children.clear()`, and inside the loop after `_defs[d.id] = d`:
     ```gdscript
     		if d.source == "evolution" and d.replaces != "":
     			if not _children.has(d.replaces):
     				_children[d.replaces] = []
     			_children[d.replaces].append(d.id)
     ```
  3. Replace `owned()`:
     ```gdscript
     ## Skills held now. A parent that evolved is retired: still in the ledger (so its unlock and level cannot fire again) but
     ## not held. `level_of` answers the level a skill REACHED, including a retired one.
     func owned() -> Array:
     	return _owned.keys().filter(func(id: String) -> bool: return not is_retired(id))

     ## True when an evolution that replaces `id` is owned.
     func is_retired(id: String) -> bool:
     	for c in _children.get(id, []):
     		if _owned.has(c):
     			return true
     	return false

     ## An evolution that can no longer be taken this life: not owned, and a sibling took the branch.
     func is_closed(id: String) -> bool:
     	var d: SkillDef = _defs.get(id)
     	return d != null and d.source == "evolution" and d.replaces != "" and not _owned.has(id) and is_retired(d.replaces)

     ## The other evolutions that share this one's parent.
     func siblings_of(id: String) -> Array:
     	var d: SkillDef = _defs.get(id)
     	if d == null or d.replaces == "":
     		return []
     	return _children.get(d.replaces, []).filter(func(c: String) -> bool: return c != id)
     ```
  4. `evolve()`: after `_ready_evolutions.erase(id)` add `for sib in siblings_of(id): _ready_evolutions.erase(sib)`. Update its doc: "Unlocks a ready evolution (the caller has paid its EP) and closes its siblings."
  5. `grant()`: replace `if not run_active or not _defs.has(id) or _owned.has(id): return false` and delete the `_ready_evolutions.erase(id)` line: the guard becomes `if not run_active or not _defs.has(id) or _owned.has(id) or _defs[id].source == "evolution": return false`. Add to its doc: "Refuses an evolution: only evolve() takes one."
  6. `recheck_levels()`: `for id in _owned.keys():` becomes `for id in owned():`.
  7. `_evaluate`: first statement `if is_retired(d.id) or is_closed(d.id):\n\t\treturn`.
  8. Fix doc comments: `evolution_cost` ("one EP per parent skill: always one now"), `is_capped` and `recheck_levels` ("held skills").

- [ ] **Step 4: Run to see GREEN** — `tools/run_tests.sh test_evolution_branches`. Expected: `PASS: 7 tests`.

- [ ] **Step 5: Mutation check** — temporarily change `for id in owned():` in `recheck_levels` back to `_owned.keys()`; `test_a_retired_parent_does_not_level_through_recheck_levels` must fail; restore.

- [ ] **Step 6: Commit** — `git add -A scripts tests && git commit -m "feat: an evolution retires its parent and closes its siblings (derived state)"`.

---

### Task 2: Validator rules, the three shipped evolutions, and the tests that pin the old unlocks

**Files:** Modify `scripts/skills/def_validator.gd`, `scripts/skills/skill_def.gd`, `tools/build_content.gd`, regenerate `data/skills/*.tres`, tests `test_def_validator.gd`, `test_levels.gd`, `test_scripted_run.gd`, `test_content.gd`, `test_skill_screen.gd`, `test_skill_rules_levels.gd`, `test_rebirth_kit.gd`.

**Interfaces:** Produces the validator rules of the spec; the three evolutions unlock at their parent's level 3 alone with `replaces` set.

- [ ] **Step 1: Write failing validator tests** — append to `tests/test_def_validator.gd` (read `_valid_skills()` and `_errors_with()` at the top of the file first; the fixtures below build on them):

```gdscript
# --- evolutions replace their parent, alone, single-level, never starting ---

func _with_parent() -> Array:
	var s := _valid_skills()
	s.append(TestDefs.skill("parent", {"source": "essence", "unlock": [TestDefs.counter("jumped", 1)],
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/water_blade.tscn"}], "mp_cost": 3}))
	return s

func _evo(id: String, extra := {}) -> SkillDef:
	var f := {"source": "evolution", "replaces": "parent", "unlock": [TestDefs.level("parent", 3)],
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/water_blade.tscn"}], "mp_cost": 4}
	f.merge(extra, true)
	return TestDefs.skill(id, f)

func test_a_well_formed_pair_of_evolutions_is_valid() -> void:
	var s := _with_parent()
	s.append(_evo("a"))
	s.append(_evo("b"))
	assert_eq(_errors_with(s), "")

func test_an_evolution_needs_replaces() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"replaces": ""}))
	assert_string_contains(_errors_with(s), "an evolution needs replaces")

func test_an_evolution_needs_an_active_scene() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"effects": [{"kind": "capability", "flag": "a"}], "mp_cost": 0}))
	assert_string_contains(_errors_with(s), "an evolution needs an active scene")

func test_an_evolution_must_not_be_starting() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"starting": true}))
	assert_string_contains(_errors_with(s), "must not be starting")

func test_an_evolution_unlock_is_exactly_one_skill_level_on_its_parent() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"unlock": [TestDefs.level("parent", 3), TestDefs.level("leap", 2)]}))
	assert_string_contains(_errors_with(s), "exactly one skill_level condition on its replaces")

func test_an_evolution_is_single_level() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"max_level": 2, "levels_on": {"event": "jumped", "tags": {}}, "level_curve": 5,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/water_blade.tscn", "values": [1, 2]}]}))
	assert_string_contains(_errors_with(s), "an evolution is single-level")

func test_siblings_share_the_unlock_level() -> void:
	var s := _with_parent()
	s.append(_evo("a"))
	s.append(_evo("b", {"unlock": [TestDefs.level("parent", 4)]}))
	assert_string_contains(_errors_with(s), "must unlock at the same level")

func test_an_evolution_of_an_evolution_is_rejected() -> void:
	var s := _with_parent()
	s.append(_evo("a"))
	s.append(_evo("b", {"replaces": "a", "unlock": [TestDefs.level("a", 1)]}))
	assert_string_contains(_errors_with(s), "which is itself an evolution")
```
Also rewrite `test_replaces_must_name_a_parent` (`test_def_validator.gd:144-149`): keep the first assertion (`replaces 'appraisal', which is not a parent`), and drop the trailing `s[-1].replaces = "leap"` / `assert_eq(..., "")` lines, since a valid evolution is now covered by `test_a_well_formed_pair_of_evolutions_is_valid`.

- [ ] **Step 2: Run RED** — `tools/run_tests.sh test_def_validator`. Expected: the eight new tests fail (messages absent).

- [ ] **Step 3: Implement** in `scripts/skills/def_validator.gd`. After the existing `replaces` check in `_check_skill` add:
```gdscript
	if d.source == "evolution":
		_check_evolution(w, d, by_id, errors)
```
and add:
```gdscript
## An evolution turns its parent into it: one skill_level unlock on the parent, single-level, an active, never starting.
static func _check_evolution(w: String, d: SkillDef, by_id: Dictionary, errors: PackedStringArray) -> void:
	if d.replaces == "":
		errors.append("%s: an evolution needs replaces (the parent it turns into)" % w)
	elif by_id.has(d.replaces):
		var parent: SkillDef = by_id[d.replaces]
		if parent.source == "evolution":
			errors.append("%s: replaces '%s', which is itself an evolution" % [w, d.replaces])
		elif SkillEffects.active_scene(parent) == "":
			errors.append("%s: replaces '%s', which has no active scene" % [w, d.replaces])
	if SkillEffects.active_scene(d) == "":
		errors.append("%s: an evolution needs an active scene" % w)
	if d.starting:
		errors.append("%s: an evolution must not be starting (only evolve() takes it)" % w)
	if d.unlock.size() != 1 or d.unlock[0].get("kind", "") != "skill_level" or d.unlock[0].get("id", "") != d.replaces:
		errors.append("%s: an evolution's unlock is exactly one skill_level condition on its replaces" % w)
	if d.max_level != 1 or not d.levels_on.is_empty():
		errors.append("%s: an evolution is single-level (max_level 1, no levels_on)" % w)

## Evolutions that share a parent unlock at the same parent level, so they are offered together.
static func _check_siblings(by_id: Dictionary, errors: PackedStringArray) -> void:
	var first := {}  # parent id -> [evolution id, n]
	for d in by_id.values():
		if d.source != "evolution" or d.replaces == "" or d.unlock.size() != 1:
			continue
		var n := int(d.unlock[0].get("n", 0))
		if not first.has(d.replaces):
			first[d.replaces] = [d.id, n]
		elif first[d.replaces][1] != n:
			errors.append("%s: evolutions of '%s' must unlock at the same level (%s needs %d, %s needs %d)" % [
				_where(d), d.replaces, first[d.replaces][0], first[d.replaces][1], d.id, n])
```
and call `_check_siblings(by_id, errors)` in `validate` after the `_check_skill` loop. In `scripts/skills/skill_def.gd` change the `replaces` comment to `## The parent this evolution turns into: the branch key (siblings share it) and the active slot it takes over.`

- [ ] **Step 4: Run GREEN** — `tools/run_tests.sh test_def_validator` → all pass.

- [ ] **Step 5: Change the shipped data.** In `tools/build_content.gd`: set the comment `# --- Evolutions (hidden, parents kept) ---` to `# --- Evolutions (each replaces its parent; siblings unlock together on it) ---`; Water Blade: `"unlock": [_lv("hydraulic_propulsion", 3)]` and add `"replaces": "hydraulic_propulsion"`; Swing Thread: `"unlock": [_lv("sticky_thread", 3)]` (keep its `replaces`); Jet Dash: `"unlock": [_lv("hydraulic_propulsion", 3)]` and add `"replaces": "hydraulic_propulsion"`. Regenerate: `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd`; `git diff --stat data/skills` shows exactly three files changed.

- [ ] **Step 6: Run the suite, fix the tests the data change breaks** (each one intended by the spec). Run `tools/run_tests.sh > .tmp/t2.txt 2>&1` and read the failures. Expected failures and their edits:
  - `test_content.gd:42`: `assert_eq(_skill("jet_dash").parent_ids(), ["hydraulic_propulsion"])`.
  - `test_skill_screen.gd:71`: `"Hydraulic Propulsion Lv3"`.
  - `test_levels.gd` `test_evolution_waits_until_ep_is_spent` (line 93 on): Hydraulic Propulsion levels every 6 casts, so Lv3 needs 12. Rewrite as:
    ```gdscript
    func test_evolution_waits_until_ep_is_spent() -> void:
    	var ready: Array = []
    	rules.evolution_ready.connect(func(id: String) -> void: ready.append(id))
    	_emit("absorbed", {"essence": "water"}, 4)
    	_emit("skill_used", {"id": "hydraulic_propulsion"}, 12)  # Lv3: both branches open together
    	assert_eq(rules.level_of("water_blade"), 0)
    	assert_true(rules.is_evolution_ready("water_blade") and rules.is_evolution_ready("jet_dash"))
    	assert_eq(ready.size(), 2)
    	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)
    	assert_eq(ready.size(), 2)  # announced once each
    	assert_eq(rules.evolution_cost("water_blade"), 1)
    	assert_eq(rules.evolution_cost("jet_dash"), 1)
    	assert_true(rules.evolve("water_blade"))
    	assert_eq(rules.level_of("water_blade"), 1)
    	assert_false(rules.evolve("water_blade"))
    	assert_false(rules.evolve("jet_dash"))  # closed: its sibling was taken
    	assert_true(rules.is_closed("jet_dash"))
    ```
    In the tests at lines 110-125 and 127-142 change each `_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)` that precedes an evolve to `12`. In `test_skill_screen_lists_ready_evolutions_and_evolves_on_accept` the row is still `"Water Blade  EVOLVE 1 EP"`, and `accept()` will evolve after two presses in Task 4: for now leave it; it is rewritten in Task 4 (mark with a `# Task 4` comment and expect it to fail until then; if it fails now, that is acceptable and noted in the ledger). Update the stale comments at lines 154-164 (`# Lv3`, "Jet Dash ready too") to describe both branches being ready at once.
  - `test_scripted_run.gd:53-55`: `_emit("skill_used", ..., 12)  # Lv3 -> both Water Blade and Jet Dash are ready`; keep `assert_true(rules.evolve("water_blade"))` and the later `level_of("hydraulic_propulsion") >= 1` (why `level_of` means reached).
  - `test_skill_rules_levels.gd:75-90` (`test_two_parent_evolution_needs_both`): this is an engine-only fixture with an unvalidated two-parent evolution; replace it with a single-parent-at-level test so it stops pinning a shape the data rule forbids:
    ```gdscript
    func test_an_evolution_waits_for_its_parents_level() -> void:
    	var hydro := TestDefs.skill("hydraulic_propulsion", {"source": "essence",
    		"unlock": [TestDefs.counter("absorbed", 1, {"essence": "water"})],
    		"levels_on": {"event": "skill_used", "tags": {"id": "hydraulic_propulsion"}}, "level_curve": 1, "max_level": 5})
    	var dash := TestDefs.skill("jet_dash", {"source": "evolution", "replaces": "hydraulic_propulsion",
    		"unlock": [TestDefs.level("hydraulic_propulsion", 3)]})
    	_make([hydro, dash])
    	engine.handle_event("absorbed", {"essence": "water"})
    	engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})
    	assert_false(engine.is_evolution_ready("jet_dash"))
    	engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})
    	assert_true(engine.is_evolution_ready("jet_dash"))
    	assert_true(engine.evolve("jet_dash"))
    	assert_eq(engine.level_of("jet_dash"), 1)
    ```
  - `test_rebirth_kit.gd:146`: the message becomes `"Swing Thread needs Sticky Thread 3"`.
  Re-run until only Task-4-owned failures remain.

- [ ] **Step 7: Commit** — `git add -A scripts tests tools data && git commit -m "feat: evolutions unlock together on their parent alone; validator rules; three shipped evolutions replace their parent"`.

---

### Task 3: Forms and kits grant base skills only; the Form card lists receivable grants

**Files:** Modify `scripts/world/rebirth_kit.gd`, `tools/build_forms.gd`, `scripts/ui/skill_screen.gd`, `tests/test_forms.gd`, `tests/test_rebirth_kit.gd`, `tests/test_form_tab.gd`; regenerate `data/forms/*.tres`.

- [ ] **Step 1: Failing tests.**
  - `tests/test_rebirth_kit.gd`: 
    ```gdscript
    func test_a_kit_may_not_name_an_evolution() -> void:
    	assert_string_contains("\n".join(RebirthKit.validate({"skills": ["water_blade"]})), "kit names evolution 'water_blade'")
    	assert_eq(RebirthKit.validate({"skills": ["hydraulic_propulsion"]}), PackedStringArray())
    ```
  - `tests/test_forms.gd` (read its loader header first; it loads `res://data/forms` and `res://data/skills`):
    ```gdscript
    func test_no_form_grants_an_evolution() -> void:
    	var by_id := {}
    	for d in DefLoader.load_dir("res://data/skills"):
    		by_id[d.id] = d
    	for f in _forms().values():
    		for g in (f as FormDef).grants:
    			assert_ne((by_id[g] as SkillDef).source, "evolution", "%s grants %s" % [f.id, g])
    ```
    (use the file's own helper name for the forms dictionary in place of `_forms()`).
  - `tests/test_form_tab.gd`: a test that a form whose only grant is a retired parent shows no "Grants:" line: build the screen as the file's other tests do, evolve `hydraulic_propulsion` into `water_blade` in `rules`, select the Tide form and assert `"\n".join(screen.detail_texts())` does not contain `"Grants:"`; with an unretired grant it does contain it.

- [ ] **Step 2: Run RED** for those three files.

- [ ] **Step 3: Implement.**
  - `RebirthKit.validate`: after the `enemy_only` branch add `elif (by_id[s] as SkillDef).source == "evolution":\n\t\t\terrs.append("kit names evolution '%s' (only evolve() takes one)" % s)`.
  - `tools/build_forms.gd`: Tempest grants `["hydraulic_propulsion"]`, blurb `"A storm held in a body."`; Tidal Sovereign grants `["hydraulic_propulsion"]`. Regenerate `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_forms.gd`.
  - `scripts/ui/skill_screen.gd` form card: build `names` first, skipping any grant `_rules.is_retired(g)` (and any the player already holds via `_rules.owned().has(g)` need not be filtered), then `if not names.is_empty():` add the label. (Replaces the `if not sel.grants.is_empty():` guard at line 685.)

- [ ] **Step 4: GREEN**, then the full suite is not needed yet. **Step 5: Commit** — `git commit -m "feat: forms and kits grant base skills only; the form card lists receivable grants"`.

---

### Task 4: Compendium, the skill rows, and the two-press evolve on the Skills tab

**Files:** Modify `scripts/compendium/compendium_model.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/skill_screen.gd`; Create `tests/test_evolution_screen.gd`; modify `tests/test_levels.gd` (`test_skill_screen_lists_ready_evolutions_and_evolves_on_accept`).

**Interfaces:** Consumes `rules.is_retired/is_closed/siblings_of/owned` from Task 1.

- [ ] **Step 1: Failing tests** — `tests/test_evolution_screen.gd`, using the same `before_each` as `tests/test_levels.gd` (real defs, `Player`, `SkillScreen`); copy that setup and its `_emit` helper. Tests:
  ```gdscript
  func _ready_both() -> void:
  	_emit("absorbed", {"essence": "water"}, 4)
  	_emit("skill_used", {"id": "hydraulic_propulsion"}, 12)  # Lv3

  func _screen() -> SkillScreen:
  	var s := SkillScreen.new()
  	add_child_autofree(s)
  	s.bind(player, rules, compendium, skills_by_id.values())
  	s.open()
  	return s

  func _select(s: SkillScreen, id: String) -> void:
  	var guard := 0
  	while s.selected_id() != id and guard < 60:
  		s.move(1)
  		guard += 1
  	assert_eq(s.selected_id(), id)

  func test_the_first_press_arms_and_the_second_evolves() -> void:
  	_ready_both()
  	player.award_xp(10)
  	var s := _screen()
  	_select(s, "water_blade")
  	s.accept()
  	assert_eq(rules.level_of("water_blade"), 0, "the first press only arms")
  	assert_string_contains("\n".join(s.detail_texts()), "Press again to choose")
  	s.accept()
  	assert_eq(rules.level_of("water_blade"), 1)
  	assert_true(rules.is_closed("jet_dash"))

  func test_the_card_names_what_it_replaces_and_closes() -> void:
  	_ready_both()
  	var s := _screen()
  	_select(s, "water_blade")
  	var text := "\n".join(s.detail_texts())
  	assert_string_contains(text, "Replaces Hydraulic Propulsion")
  	assert_string_contains(text, "Closes: Jet Dash")

  func test_moving_the_selection_disarms() -> void:
  	_ready_both()
  	player.award_xp(10)
  	var s := _screen()
  	_select(s, "water_blade")
  	s.accept()
  	s.move(1)
  	s.move(-1)
  	assert_false("\n".join(s.detail_texts()).contains("Press again to choose"))
  	s.accept()
  	assert_eq(rules.level_of("water_blade"), 0, "armed again, not evolved")

  func test_closing_disarms() -> void:
  	_ready_both()
  	player.award_xp(10)
  	var s := _screen()
  	_select(s, "water_blade")
  	s.accept()
  	s.close()
  	s.open()
  	_select(s, "water_blade")
  	s.accept()
  	assert_eq(rules.level_of("water_blade"), 0)

  func test_an_ep_short_press_never_evolves_and_the_card_says_how_to_earn_ep() -> void:
  	_ready_both()
  	var s := _screen()
  	_select(s, "water_blade")
  	s.accept()
  	s.accept()
  	assert_eq(rules.level_of("water_blade"), 0)
  	var text := "\n".join(s.detail_texts())
  	assert_string_contains(text, "Level up to earn EP")
  	assert_false(text.contains("Press again to choose"))

  func test_a_retired_parent_is_not_a_row_and_does_not_light_the_locked_row() -> void:
  	_ready_both()
  	rules.evolve("water_blade")
  	var rows := SkillScreenModel.skill_rows(rules, skills_by_id.values())
  	assert_false(rows.any(func(r): return r.get("id", "") == "hydraulic_propulsion"))
  	var essence_locked := false
  	var in_essence := false
  	for r in rows:
  		if r["kind"] == "header":
  			in_essence = r["text"] == "ESSENCE"
  		elif in_essence and r["kind"] == "locked":
  			essence_locked = true
  	# other essence skills are still locked in a fresh run, so assert on the retired parent specifically:
  	assert_false(rows.any(func(r): return r["kind"] == "skill" and r["id"] == "hydraulic_propulsion"))

  func test_a_closed_evolution_does_not_count_toward_the_locked_row() -> void:
  	_ready_both()
  	rules.evolve("water_blade")
  	# jet_dash is closed. Once every other locked skill is owned the row must vanish; check the rule directly:
  	var d: SkillDef = skills_by_id["jet_dash"]
  	assert_true(rules.is_closed(d.id))
  	assert_eq(rules.level_of(d.id), 0)
  	var counted := SkillScreenModel.counts_as_locked(rules, d)
  	assert_false(counted)

  func test_appraisal_lv4_does_not_advertise_a_closed_evolution() -> void:
  	_ready_both()
  	rules.evolve("water_blade")
  	var report := compendium.self_report(4, rules)
  	assert_false(report["evolutions"].any(func(e): return e["id"] == "jet_dash"))

  func test_an_evolved_skills_card_says_where_it_came_from() -> void:
  	_ready_both()
  	player.award_xp(10)
  	var s := _screen()
  	_select(s, "water_blade")
  	s.accept()
  	s.accept()
  	_select(s, "water_blade")
  	assert_string_contains("\n".join(s.detail_texts()), "Evolved from Hydraulic Propulsion")
  ```
  Also rewrite the old `tests/test_levels.gd` `test_skill_screen_lists_ready_evolutions_and_evolves_on_accept` to press `accept()` twice before asserting `level_of("water_blade") == 1`, and use 12 casts.

- [ ] **Step 2: RED** — `tools/run_tests.sh test_evolution_screen`.

- [ ] **Step 3: Implement.**
  - `SkillScreenModel`: add
    ```gdscript
    ## True when a skill the player has not reached should make the "???" row show: non-secret, not ready, not closed, level 0.
    static func counts_as_locked(rules, d: SkillDef) -> bool:
    	return rules.level_of(d.id) == 0 and not d.secret and not rules.is_evolution_ready(d.id) and not rules.is_closed(d.id)
    ```
    In `skill_rows`: `var held: Array = rules.owned()` before the group loop; replace `if rules.level_of(d.id) > 0:` with `if held.has(d.id):` and `elif not d.secret and not rules.is_evolution_ready(d.id):` with `elif counts_as_locked(rules, d):`. Update its doc to say rows are held skills.
  - `CompendiumModel.self_report`: in the evolution branch add `if rules.is_closed(id): continue` before computing `parents` (so the closed evolution is not advertised nor raised). Update the doc "Lv4: evolutions whose parents are all owned and that are not closed".
  - `SkillScreen`: `var _armed := ""` beside `_sel`. In `_refresh()`, in the skills/compendium/bestiary path immediately after `_sel = clampi(_sel, 0, maxi(0, _selectable.size() - 1))`, add (with the comment) `# An armed evolution stays armed only while it is the selected row. A tab switch resets _sel to 0, which is what disarms across tabs.` and `if _armed != selected_id():\n\t\t_armed = ""`. In `close()` add `_armed = ""`. In `accept()`, in the `"ready"` branch replace the body with:
    ```gdscript
    	if id != "" and _rows[_selectable[_sel]]["kind"] == "ready":
    		if _armed != id:
    			if _player.progression.ep >= _rules.evolution_cost(id):
    				_armed = id  # the choice is permanent for the life: confirm with a second press
    		elif _player.try_evolve(id):
    			_armed = ""
    			EventBus.world_event.emit("menu_confirm", {})
    		_refresh()
    		return
    ```
    (An EP-short press leaves `_armed` empty and does nothing, as the card says.) Update the `accept()` doc comment.
    In `_build_detail`'s ready branch, replace the block so the card shows: name (y 50), "Ready to evolve" (68), description (100, height 30), `"Replaces %s" % parent name` (y 130, small), `"Closes: " + ", ".join(sibling names)` when any (y 141, small), the cost line (y 156), and the action line (y 170): `"Level up to earn EP"` when short, else `"Press again to choose"` when `_armed == id`, else `"[Enter] Evolve"`. For an owned evolved skill (the non-ready path after `SkillScreenModel.detail`), add `"Evolved from %s"` (parent name) as the last line when `d.source == "evolution" and d.replaces != ""`. Parent/sibling names come from `_defs[...]`.
  - `SkillScreenModel.ACTIVE_LABEL`: leave for Task 6+ (each ability adds its label).

- [ ] **Step 4: GREEN** — `tools/run_tests.sh test_evolution_screen` and `test_levels` pass.
- [ ] **Step 5: Look at it.** Write a scratch script `.tmp/evo/screen_shot.gd` modelled on `tools/room_shots.gd` (windowed, unsandboxed): boot `scenes/main.tscn`, give the player 10 XP, emit 4 water absorbs and 12 `skill_used` events through `SkillRules`, open the skill screen (`game.skill_screen.open()` or the node the game holds; grep `SkillScreen` in `scripts/game.gd`), select Water Blade, save a screenshot; run `godot --path . -s res://.tmp/evo/screen_shot.gd` unsandboxed; Read the PNG. Text must not overlap or clip; adjust the y positions if it does. Delete the scratch script afterwards.
- [ ] **Step 6: Commit** — `git commit -m "feat: choose an evolution with a confirming second press; retired parents and closed branches leave the rows"`.

---

### Task 5: The zone, and `terrain_hit` moves up to `Ability`

**Files:** Modify `scripts/abilities/spore_cloud_area.gd`, `scripts/abilities/ability.gd`, `scripts/abilities/thread_ability.gd`, `scripts/enemies/enemy.gd` (the `slow_for` doc comment); Create `tests/test_zone.gd`.

**Interfaces:** Produces `SporeCloudArea.launch(at, radius, seconds, actor, opts := {})` with `opts` keys `damage` (1), `slow` (true), `heals` (0), `color`; `Ability.terrain_hit(from, to)`.

- [ ] **Step 1: Failing tests** — `tests/test_zone.gd` (copy `StubActor`, `_toad`, `before_all/before_each` from `tests/test_spore_cloud.gd`; the healing stub needs a `health`):
  ```gdscript
  class HealActor extends Node2D:
  	var team := "player"
  	var facing := 1
  	var health := Health.new(10)

  func _zone(at: Vector2, radius: float, seconds: float, opts := {}, who: Node2D = null) -> SporeCloudArea:
  	var z := SporeCloudArea.new()
  	add_child_autofree(z)
  	z.launch(at, radius, seconds, who if who != null else actor, opts)
  	return z

  func test_a_fast_enemy_crossing_between_ticks_is_slowed() -> void:
  	var toad := _toad(Vector2(-50, 0))
  	_zone(Vector2.ZERO, 40.0, 4.0, {"damage": 0})
  	var slowed_inside := false
  	for i in 60:  # 90 px/s for 1 s: crosses x -50 .. +40 in 1 s, before the first tick
  		toad.position.x += 90.0 / 60.0
  		await get_tree().physics_frame
  		if absf(toad.position.x) <= 40.0 and toad._speed() < Enemy.BASE_SPEED * toad.stats.get_stat("spd") / 100.0:
  			slowed_inside = true
  	assert_true(slowed_inside, "slowed while inside, without waiting for a tick")

  func test_damage_zero_leaves_an_enemy_untouched() -> void:
  	var toad := _toad(Vector2(10, 0))
  	_zone(Vector2.ZERO, 40.0, 2.0, {"damage": 0})
  	var hp := toad.health.hp
  	await wait_physics_frames(130)
  	assert_eq(toad.health.hp, hp)
  	assert_eq(toad._hurt_t, 0.0, "no hit means no hurt timer")

  func test_a_zone_ticks_once_per_whole_second_and_expires() -> void:
  	for seconds in [1.0, 2.0, 3.0, 4.0]:
  		var toad := _toad(Vector2(10, 0))
  		toad.health.max_hp = 99
  		toad.health.hp = 99
  		var z := _zone(Vector2.ZERO, 40.0, seconds)
  		await wait_physics_frames(int(seconds * 60.0) + 12)
  		assert_eq(99 - toad.health.hp, int(seconds), "%s s zone ticks that many times" % seconds)
  		assert_false(is_instance_valid(z) and z.is_inside_tree(), "expired")
  		toad.queue_free()

  func test_healing_heals_the_caster_only_inside_and_on_the_tick() -> void:
  	var slime := HealActor.new()
  	add_child_autofree(slime)
  	slime.health.hp = 5
  	_zone(Vector2.ZERO, 40.0, 3.0, {"damage": 0, "heals": 1}, slime)
  	await wait_physics_frames(30)
  	assert_eq(slime.health.hp, 5, "nothing before the first second")
  	await wait_physics_frames(40)
  	assert_eq(slime.health.hp, 6)
  	slime.position = Vector2(200, 0)  # steps out
  	await wait_physics_frames(60)
  	assert_eq(slime.health.hp, 6)

  func test_the_default_options_are_spore_clouds() -> void:
  	var toad := _toad(Vector2(10, 0))
  	_zone(Vector2.ZERO, 24.0, 2.0)  # the old four-argument call
  	var hp := toad.health.hp
  	await wait_physics_frames(72)
  	assert_eq(toad.health.hp, hp - 1)
  ```
  (`Health.new(10)`, `_hurt_t` and `_speed()` are used by existing tests; read `scripts/actors/health.gd` and `enemy.gd` to confirm the constructor/field names and adapt.) Also add to `tests/test_grapple.gd` one test that `Ability.terrain_hit` finds rock through an `Ability` that is not a `ThreadAbility`: instantiate `res://scenes/abilities/water_blade.tscn`, set it up on the `RopeActor`, `_solid(Rect2(40, -10, 10, 20))`, assert `terrain_hit(Vector2.ZERO, Vector2(100, 0))` returns a point with `x ≈ 40`.

- [ ] **Step 2: RED**, then **Step 3: Implement.**
  - `Ability`: move `terrain_hit` here verbatim from `ThreadAbility`; delete it there.
  - Rewrite `scripts/abilities/spore_cloud_area.gd`:
    ```gdscript
    class_name SporeCloudArea
    extends Node2D
    ## A lingering zone the player leaves behind: Spore Cloud, Binding Web's patch, Miasma, Healing Spores and Puffball. For
    ## `seconds` it slows every enemy inside it each physics frame (Enemy.slow_for is idempotent, so a fast enemy crossing
    ## between ticks is still slowed) and, once each whole second, hurts them (`damage`, poison; 0 means no hit at all) and
    ## heals its caster if the caster is inside (`heals`). Group `player_clouds`; it never hurts the caster or its team and is
    ## not a `hazards` node.

    const TICK_SECONDS := 1.0
    const EPS := 1e-4  # a tick is due within this of its second, so N whole seconds tick N times whatever the float drift

    var radius := 24.0
    var damage := 1
    var slow := true
    var heals := 0
    var _seconds := 0.0
    var _elapsed := 0.0
    var _ticks := 0
    var _actor: Node2D

    func launch(at: Vector2, p_radius: float, seconds: float, actor: Node2D, opts := {}) -> void:
    	global_position = at
    	radius = p_radius
    	_seconds = seconds
    	_actor = actor
    	damage = int(opts.get("damage", 1))
    	slow = bool(opts.get("slow", true))
    	heals = int(opts.get("heals", 0))
    	add_to_group("player_clouds")
    	for c in get_children():
    		c.queue_free()
    	var haze := ColorRect.new()  # drawn at the real radius, so a higher level shows a bigger cloud
    	haze.color = opts.get("color", Color(0.7, 0.95, 0.4, 0.3))
    	haze.size = Vector2(radius * 2.0, radius * 2.0)
    	haze.position = -haze.size / 2.0
    	add_child(haze)

    func _physics_process(delta: float) -> void:
    	if not is_instance_valid(_actor):
    		queue_free()
    		return
    	_elapsed += delta
    	if slow:
    		for n in _enemies_inside():
    			n.slow_for(Enemy.SLOW_SECONDS)
    	while float(_ticks + 1) * TICK_SECONDS <= _elapsed + EPS and float(_ticks + 1) * TICK_SECONDS <= _seconds + EPS:
    		_ticks += 1
    		_pulse()
    	if _elapsed >= _seconds - EPS:
    		queue_free()

    func _pulse() -> void:
    	if damage > 0:
    		for n in _enemies_inside():
    			n.receive_hit(damage, "poison", global_position, "poison")
    	if heals > 0 and _actor.global_position.distance_to(global_position) <= radius:
    		var h = _actor.get("health")
    		if h != null:
    			h.heal(heals)

    func _enemies_inside() -> Array:
    	var out: Array = []
    	for n in get_tree().get_nodes_in_group("actors"):
    		if n == _actor or not n.has_method("receive_hit") or n.get("team") == _actor.get("team"):
    			continue
    		if n.has_method("can_be_hit") and not n.can_be_hit():
    			continue
    		if n.global_position.distance_to(global_position) <= radius:
    			out.append(n)
    	return out
    ```
    Check that `Enemy.SLOW_SECONDS` exists (it is used by the old cloud) and that the existing `test_spore_cloud.gd` expectations still hold (`one poison damage after the first second` at 72 frames; expiry at 0.5 s within 50 frames). Update the `slow_for` doc comment in `enemy.gd` to name the zone and Binding Web.

- [ ] **Step 4: GREEN** — `tools/run_tests.sh test_zone`, `test_spore_cloud`, `test_grapple` pass.
- [ ] **Step 5: Commit** — `git commit -m "feat: SporeCloudArea is a general zone (damage, slow, heals, colour); terrain_hit moves up to Ability"`.

---

### Task 6: Binding Web (thread tree, second branch)

**Files:** Modify `scripts/abilities/thread_ability.gd`, `scripts/forms/form_effects.gd`, `scripts/ui/skill_screen_model.gd`, `tools/build_content.gd`, `data/audio/cues.json`, regenerate `data/skills`; Create `scripts/abilities/binding_web.gd`, `scenes/abilities/binding_web.tscn`; Create `tests/test_evolution_abilities.gd`.

- [ ] **Step 1: Failing tests** — `tests/test_evolution_abilities.gd` starts with the `RopeActor` stub, `_solid`, `_enemy` and `_cast` helpers copied from `tests/test_grapple.gd` (the zone is added to `actor.get_parent()`, which is the test node here). Tests for Binding Web:
  ```gdscript
  func _patches() -> Array:
  	return get_tree().get_nodes_in_group("player_clouds")

  func test_binding_web_holds_an_enemy_and_leaves_a_patch_at_it() -> void:
  	var e := _enemy(Vector2(60, 0))
  	await _cast("binding_web", Vector2(1, 0), [2])
  	assert_eq(e.threads, [2], "held at once (tier 2)")
  	assert_eq(actor.ropes, [])
  	assert_eq(_patches().size(), 1)
  	assert_almost_eq((_patches()[0] as Node2D).global_position.x, 60.0, 1.0)

  func test_binding_web_never_ropes_and_webs_the_rock_it_meets() -> void:
  	_solid(Rect2(80, -50, 20, 100))
  	await _cast("binding_web", Vector2(1, 0), [2])
  	assert_eq(actor.ropes, [], "no rope")
  	assert_eq(_patches().size(), 1)
  	assert_almost_eq((_patches()[0] as Node2D).global_position.x, 80.0, 2.0)

  func test_binding_web_webs_full_range_in_open_air() -> void:
  	await _cast("binding_web", Vector2(1, 0), [2])
  	assert_eq(_patches().size(), 1)
  	assert_almost_eq((_patches()[0] as Node2D).global_position.x, 120.0, 1.0)

  func test_the_patch_does_no_damage() -> void:
  	await _cast("binding_web", Vector2(1, 0), [2])
  	assert_eq((_patches()[0] as SporeCloudArea).damage, 0)
  ```
  Add a test that `sticky_thread` still ropes and leaves no patch (regression for `_land`), and one that `FormEffects.mp_cost({"trait_spinner": 1}, "binding_web", 4) == 3`.

- [ ] **Step 2: RED**, then **Step 3: Implement.**
  - `ThreadAbility`: add `var ropes := true`, and
    ```gdscript
    ## Called with where the thread ended (the enemy it held, the rock it met, or full range). The base does nothing.
    func _land(_end: Vector2) -> void:
    	pass
    ```
    In `_perform`: after the target branch's `Vfx.line` add `_land(target.global_position)`; change the `elif anchor != null and actor.has_method("attach_rope"):` to `elif ropes and anchor != null and actor.has_method("attach_rope"):`; the `else` branch becomes `var end: Vector2 = anchor if (anchor != null and not ropes) else from + dir * rope_range` then `Vfx.line(actor, from, end, THREAD_COLOR, 1.0, 0.35)` and `_land(end)`. Update the file header (it now covers Binding Web).
  - `scripts/abilities/binding_web.gd`:
    ```gdscript
    extends ThreadAbility
    ## Evolved Sticky Thread: never ropes. Holds an enemy at once and leaves a web patch where the thread ends, slowing anything inside.

    const PATCH_RADIUS := 40.0
    const PATCH_SECONDS := 4.0

    func _init() -> void:
    	rope_range = 120.0
    	ropes = false

    func _land(end: Vector2) -> void:
    	var patch := SporeCloudArea.new()
    	actor.get_parent().add_child(patch)
    	patch.launch(end, PATCH_RADIUS, PATCH_SECONDS, actor, {"damage": 0, "slow": true, "color": Color(0.95, 0.95, 1.0, 0.35)})
    ```
    and `scenes/abilities/binding_web.tscn` copied from `water_blade.tscn` with the script path and node name `BindingWeb`.
  - `tools/build_content.gd`, in the evolutions block:
    ```gdscript
    		_s({"id": "binding_web", "display_name": "Binding Web", "source": "evolution",
    			"description": "Hold an enemy with thread and leave a web that slows anything inside.", "hint": "",
    			"announce": "Skill evolved. Acquired [Binding Web].",
    			"unlock": [_lv("sticky_thread", 3)], "effects": [_active("binding_web", [2])], "mp_cost": 4,
    			"replaces": "sticky_thread"}),
    ```
    Regenerate skills. `FormEffects.THREAD_SKILLS` gains `"binding_web"`. `SkillScreenModel.ACTIVE_LABEL` gains `"binding_web": "Hold tier"`. `data/audio/cues.json` `skill_used` gains `"binding_web": "skill_sticky_thread"`.
  - Icons are generated in Task 9 (until then `Art.texture("icon_binding_web")` is missing: `test_art_assets` fails red on its own and is fixed in Task 9; the skill screen shows a fallback).

- [ ] **Step 4: GREEN** — the ability tests, `test_grapple`, `test_def_validator`, `test_content` pass. **Step 5: Commit** — `git commit -m "feat: Binding Web, Sticky Thread's second branch"`.

---

### Task 7: Poison Breath's branches — Miasma and Venom Bolt

**Files:** Create `scripts/abilities/miasma.gd`, `venom_bolt.gd` and scenes; modify `tools/build_content.gd`, `skill_screen_model.gd` (`ACTIVE_LABEL`), `data/audio/cues.json`, regenerate skills; extend `tests/test_evolution_abilities.gd`.

- [ ] **Step 1: Failing tests** (the `RopeActor.receive_hit` stub records nothing, so add `hits: Array` to the stub: `func receive_hit(raw, type, _from = Vector2.INF, _cause = ""): hits.append([raw, type])`, and give enemies a `global_position`; adjust `_enemy` accordingly):
  ```gdscript
  func test_venom_bolt_pierces_every_enemy_on_its_line_once() -> void:
  	var a := _enemy(Vector2(60, 0))
  	var b := _enemy(Vector2(200, 4))
  	var off := _enemy(Vector2(120, 80))
  	await _cast("venom_bolt", Vector2(1, 0), [9])
  	assert_eq(a.hits, [[9, "poison"]])
  	assert_eq(b.hits, [[9, "poison"]])
  	assert_eq(off.hits, [])

  func test_venom_bolt_stops_at_rock_and_at_260_px() -> void:
  	var behind := _enemy(Vector2(120, 0))
  	var far := _enemy(Vector2(270, 0))
  	_solid(Rect2(90, -40, 10, 80))
  	await _cast("venom_bolt", Vector2(1, 0), [9])
  	assert_eq(behind.hits, [], "the rock ends the line")
  	assert_eq(far.hits, [])

  func test_venom_bolt_reaches_an_enemy_at_the_range_edge() -> void:
  	var edge := _enemy(Vector2(255, 15))
  	await _cast("venom_bolt", Vector2(1, 0), [9])
  	assert_eq(edge.hits.size(), 1)

  func test_miasma_hits_the_cone_and_leaves_a_poisoning_non_slowing_cloud_at_its_end() -> void:
  	var e := _enemy(Vector2(40, 0))
  	await _cast("miasma", Vector2(1, 0), [9])
  	assert_eq(e.hits, [[9, "poison"]])
  	assert_eq(_patches().size(), 1)
  	var z: SporeCloudArea = _patches()[0]
  	assert_almost_eq(z.global_position.x, 56.0, 1.0)
  	assert_false(z.slow)
  	assert_eq(z.damage, 1)

  func test_miasma_never_puts_its_cloud_behind_a_wall() -> void:
  	_solid(Rect2(30, -50, 10, 100))
  	await _cast("miasma", Vector2(1, 0), [9])
  	assert_lt((_patches()[0] as Node2D).global_position.x, 32.0)
  ```
- [ ] **Step 2: RED**, **Step 3: Implement.**
  - `venom_bolt.gd`:
    ```gdscript
    extends Ability
    ## Evolved Poison Breath: an instant line along the aim that pierces. Every enemy on it takes the poison once; rock ends it.

    const RANGE := 260.0
    const HALF_WIDTH := 20.0

    func _perform() -> void:
    	var dir := aim_dir()
    	var from := actor.global_position
    	var rock = terrain_hit(from, from + dir * RANGE)
    	var reach := RANGE if rock == null else from.distance_to(rock)
    	for t in targets_in_front(reach, HALF_WIDTH):
    		t.receive_hit(value(), "poison", from, "poison")
    	Vfx.line(actor, from, from + dir * reach, Color(0.55, 0.95, 0.3), 2.0, 0.25)
    ```
  - `miasma.gd`:
    ```gdscript
    extends "res://scripts/abilities/poison_breath.gd"
    ## Evolved Poison Breath: the cone as today, and a poison cloud lingers where it ends (never inside or behind rock).

    const CLOUD_RADIUS := 36.0
    const CLOUD_SECONDS := 3.0

    func _perform() -> void:
    	super._perform()
    	var dir := aim_dir()
    	var from := actor.global_position
    	var end := from + dir * RANGE
    	var rock = terrain_hit(from, end)
    	if rock != null:
    		end = rock - dir * 2.0
    	var cloud := SporeCloudArea.new()
    	actor.get_parent().add_child(cloud)
    	cloud.launch(end, CLOUD_RADIUS, CLOUD_SECONDS, actor, {"damage": 1, "slow": false, "color": Color(0.5, 0.9, 0.3, 0.3)})
    ```
  - scenes; skill defs (`unlock [_lv("poison_breath", 4)]`, `"replaces": "poison_breath"`, values `[9]`, MP 5, descriptions "Breathe poison and leave a lingering cloud where it ends." / "A piercing bolt of poison along your aim."); `ACTIVE_LABEL` `"miasma": "Damage", "venom_bolt": "Damage"`; cues `"miasma": "skill_poison_breath", "venom_bolt": "skill_poison_spit"`. Regenerate skills.
- [ ] **Step 4: GREEN. Step 5: Commit** — `git commit -m "feat: Poison Breath evolves into Miasma or Venom Bolt"`.

---

### Task 8: Spore Cloud's branches — Healing Spores and Puffball

**Files:** Create `scripts/abilities/healing_spores.gd`, `puffball.gd`, scenes; modify `tools/build_content.gd`, `ACTIVE_LABEL`, cues, regenerate skills; extend `tests/test_evolution_abilities.gd`.

- [ ] **Step 1: Failing tests** (the stub actor needs `health`: add `var health := Health.new(10)` to `RopeActor` or use a dedicated `HealActor`):
  ```gdscript
  func test_healing_spores_drops_a_healing_non_damaging_cloud_around_the_caster() -> void:
  	await _cast("healing_spores", Vector2(1, 0), [40])
  	var z: SporeCloudArea = _patches()[0]
  	assert_eq([z.radius, z.damage, z.heals, z.slow], [40.0, 0, 1, true])
  	assert_lt(actor.global_position.distance_to(z.global_position), z.radius, "the slime is inside at cast time")

  func test_puffball_lands_on_the_floor_on_a_horizontal_aim() -> void:
  	_solid(Rect2(-400, 12, 800, 20))  # floor 12 px below the caster
  	await _cast("puffball", Vector2(1, 0), [64])
  	var z: SporeCloudArea = _patches()[0]
  	assert_eq([z.radius, z.damage, z.slow], [64.0, 1, true])
  	assert_between(z.global_position.x, 105.0, 135.0)
  	assert_almost_eq(z.global_position.y, 12.0, 3.0)

  func test_puffball_lands_on_a_45_degree_aim_on_flat_ground() -> void:
  	_solid(Rect2(-400, 12, 800, 20))
  	await _cast("puffball", Vector2(1, -1).normalized(), [64])
  	var z: SporeCloudArea = _patches()[0]
  	assert_almost_eq(z.global_position.y, 12.0, 3.0, "it came down to the floor, not the arc cap")
  	assert_between(z.global_position.x, 150.0, 190.0)

  func test_puffball_straight_up_comes_back_down() -> void:
  	_solid(Rect2(-400, 12, 800, 20))
  	await _cast("puffball", Vector2(0, -1), [64])
  	assert_almost_eq((_patches()[0] as Node2D).global_position.y, 12.0, 3.0)

  func test_puffball_bursts_against_a_wall() -> void:
  	_solid(Rect2(60, -100, 10, 200))
  	await _cast("puffball", Vector2(1, 0), [64])
  	assert_lt((_patches()[0] as Node2D).global_position.x, 62.0)

  func test_puffball_over_a_pit_stops_at_the_cap() -> void:
  	await _cast("puffball", Vector2(1, 0), [64])  # no floor at all
  	assert_eq(_patches().size(), 1)
  ```
- [ ] **Step 2: RED**, **Step 3: Implement.**
  - `healing_spores.gd`:
    ```gdscript
    extends Ability
    ## Evolved Spore Cloud: a cloud that mends the slime and slows enemies. The value is its radius in px.

    const SECONDS := 4.0

    func _perform() -> void:
    	var cloud := SporeCloudArea.new()
    	actor.get_parent().add_child(cloud)
    	cloud.launch(actor.global_position + aim_dir() * 32.0, float(value()), SECONDS, actor,
    		{"damage": 0, "slow": true, "heals": 1, "color": Color(0.6, 1.0, 0.7, 0.3)})
    ```
  - `puffball.gd`:
    ```gdscript
    extends Ability
    ## Evolved Spore Cloud: a pod lobbed along the aim bursts where it lands into a wide cloud. The landing point is computed
    ## at cast time by stepping the arc, so nothing flies (the effects spec draws the pod). The value is the cloud's radius.

    const SPEED := 220.0
    const LIFT := 150.0
    const GRAVITY := 600.0
    const STEP := 1.0 / 30.0
    const MAX_STEPS := 40
    const SECONDS := 3.0

    func landing_point() -> Vector2:
    	var pos := actor.global_position
    	var vel := aim_dir() * SPEED + Vector2(0.0, -LIFT)
    	for i in MAX_STEPS:
    		var next := pos + vel * STEP
    		vel.y += GRAVITY * STEP
    		var rock = terrain_hit(pos, next)
    		if rock != null:
    			return rock - (next - pos).normalized() * 2.0
    		pos = next
    	return pos

    func _perform() -> void:
    	var cloud := SporeCloudArea.new()
    	actor.get_parent().add_child(cloud)
    	cloud.launch(landing_point(), float(value()), SECONDS, actor)
    ```
  - scenes; defs (`unlock [_lv("spore_cloud", 4)]`, `replaces "spore_cloud"`, values `[40]` and `[64]`, MP 4 and 5, descriptions "A cloud of spores that mends you and slows enemies." / "Lob a spore pod that bursts into a wide cloud."); `ACTIVE_LABEL` `"healing_spores": "Radius", "puffball": "Radius"`; cues `"healing_spores": "skill_poison_breath", "puffball": "skill_poison_breath"`. Regenerate.
  - If a landing-y assertion fails by more than the tolerance, the arc numbers (not the test) are re-derived from the spec: 45 degree lands about 164 px out at 1.06 s.
- [ ] **Step 4: GREEN. Step 5: Commit** — `git commit -m "feat: Spore Cloud evolves into Healing Spores or Puffball"`.

---

### Task 9: Icons, cues, MP table, content pins, end-to-end trees, docs

**Files:** Modify `tools/art/skill_icons_grotto_frames.json`, create `assets/sprites/icon_{binding_web,miasma,venom_bolt,healing_spores,puffball}.png`, `tests/test_mana.gd`, `tests/test_content.gd`, `tests/test_autoloads.gd`, `docs/playtest-checklist.md`; Create `tests/test_evolution_trees.gd`.

- [ ] **Step 1: Failing pins.**
  - `tests/test_mana.gd:70-72`: extend `costs` with `"binding_web": 4, "miasma": 5, "venom_bolt": 5, "healing_spores": 4, "puffball": 5`.
  - `tests/test_content.gd:23` and `tests/test_autoloads.gd:4`: the skill total 24 becomes 29.
  - `tests/test_content.gd`: 
    ```gdscript
    func test_every_parent_has_exactly_two_evolutions() -> void:
    	var counts := {}
    	for d in skills:
    		if d.source == "evolution":
    			counts[d.replaces] = int(counts.get(d.replaces, 0)) + 1
    	assert_eq(counts, {"sticky_thread": 2, "hydraulic_propulsion": 2, "poison_breath": 2, "spore_cloud": 2})
    ```
    (use the file's own name for the loaded skill array).
  - `tests/test_evolution_trees.gd` (same `before_each` as `test_levels.gd`): one test looping over the four trees:
    ```gdscript
    const TREES := [["sticky_thread", ["swing_thread", "binding_web"]], ["hydraulic_propulsion", ["water_blade", "jet_dash"]],
    	["poison_breath", ["miasma", "venom_bolt"]], ["spore_cloud", ["healing_spores", "puffball"]]]

    func test_each_tree_evolves_each_branch_in_a_fresh_run() -> void:
    	for tree in TREES:
    		var parent: String = tree[0]
    		for chosen in tree[1]:
    			rules.start_run()
    			player.skillset.reset()
    			assert_true(rules.grant(parent, true), parent)
    			var d: SkillDef = skills_by_id[parent]
    			var need: int = (int((skills_by_id[chosen] as SkillDef).unlock[0]["n"]) - 1) * d.level_curve
    			_emit("skill_used", {"id": parent}, need)
    			for c in tree[1]:
    				assert_true(rules.is_evolution_ready(c), "%s ready" % c)
    			assert_true(rules.evolve(chosen), chosen)
    			assert_true(player.skillset.slots.slots.has(chosen), "%s is slotted" % chosen)
    			assert_false(player.skillset.slots.slots.has(parent), "%s left the slot" % parent)
    			for c in tree[1]:
    				if c != chosen:
    					assert_true(rules.is_closed(c))
    ```
    (a parent gained by `grant` has `_owned` base equal to the current counter, so `need` casts reach the level).
- [ ] **Step 2: Icons.** Append five frames to `tools/art/skill_icons_grotto_frames.json` (same shape as `icon_spore_cloud`: `name`, `width` 128, `refs` `[]`, one-sentence prompt): Binding Web (a silver web patch with a bound glowing thread across it), Miasma (a green poison cloud with a drifting skull-less wisp, cone shape), Venom Bolt (a green glowing bolt with a droplet tip), Healing Spores (a pink-green spore cloud with a small plus glow), Puffball (a round puffball pod bursting into spores). Generate unsandboxed as the whole command: `uv run --python 3.12 python tools/art/generate_frames.py skill_icons_grotto icon_binding_web` (repeat per frame; read `generate_frames.py`'s usage first and follow the Grotto precedent exactly), then `uv run --python 3.12 --with Pillow python tools/art/make_icons.py`. Look at all five PNGs (Read); regenerate one alone if unclear. Run the import.
- [ ] **Step 3: Docs.** `docs/playtest-checklist.md`: replace the evolution lines (`:27`, `:33`) with: reach Sticky Thread level 3, both Swing Thread and Binding Web appear; the first Enter arms; the second evolves; the sibling disappears; the parent no longer casts; repeat for the other three parents; die and rebirth reopens all.
- [ ] **Step 4: Full suite** — `tools/run_tests.sh > .tmp/t9.txt 2>&1; tail -20 .tmp/t9.txt`. Expected: all green (fix anything the earlier tasks left red, e.g. the `test_art_assets` icon checks, `test_audio_catalog`).
- [ ] **Step 5: Screenshots.** A windowed run of the game with the skill screen open on the evolution row for two trees (the Task 4 scratch script, parameterised), and one cast each of Binding Web, Miasma and Puffball in a room (`tools/room_shots.gd` style): Read the images; the effects are plain (the effects spec improves them) but must be visible and at the right place.
- [ ] **Step 6: Commit** — `git commit -m "feat: skill icons, pins and end-to-end trees for the evolution branches"`.

---

## Final steps (executing-plans)

Whole-branch review with an opus reviewer (`review-package` script per the skill), one fix pass, then `finishing-a-development-branch`: merge to `main`, run the full suite on the merged tree, push, relaunch the game (`godot --path . > .tmp/gameN.log 2>&1 &`).
