# Essence Overhaul, Part 1: Forms by Powers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first body evolution offers every lineage whose power the player has reached, instead of ranking an essence-affinity ratio, and the rebirth pools stop carrying seeded affinity.

**Architecture:** `FormDef.powers` names the skills that open each lineage; a new public `FormOffers.open_lineages(forms, rules)` reads `SkillRulesEngine.level_of`; the whole affinity machinery (`supply`, `affinity`, `absorbed_units`, `ELIGIBLE`, `MAX_OFFERS`, `FIRST_EVOLUTION_AREAS`, `Progression.seeded`, the kit `affinity` key, `RebirthKit.eligible_lineages`) is deleted in one atomic task so the suite stays green.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`).

**Spec:** `docs/superpowers/specs/2026-10-03-essence-overhaul-design.md` (approved by Sean; the "Forms", "Lineage powers", "Rebirth kits" and "Sequencing" step 1 rows). This is part 1 of 3: part 2 is `2026-10-03-essence-overhaul-2-element-vocabulary.md`, part 3 is `2026-10-03-essence-overhaul-3-price-held-ep.md`. Each part leaves the suite green and can ship alone.

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. A SCRIPT ERROR or Parse Error anywhere fails the whole run (`tools/run_tests.sh` reads the log). Accessing a member that does not exist on a statically typed value is a parse error, so a deleted member must go in the same task as every reader of it.
- No new `class_name` script is added in this part, so no `.uid` file or import is needed.
- A lineage is **open** when `rules.level_of(power) > 0` for any of its powers (`level_of` keeps answering the level a retired parent reached, so an evolved power still opens its lineage).
- Stage 1 to 2 offers every open lineage in `FormOffers.LINEAGE_ORDER` (`weaver, tide, toxic, bulwark, echo`), plus `greater_slime` when fewer than two are open. No ranking, no cap. Stage 2 to 3 and 3 to 4 are unchanged.
- Lineage powers: weaver `sticky_thread` · tide `hydraulic_propulsion` · toxic `poison_breath`, `spore_cloud` · bulwark `body_armor`, `hardened_shell`, `tremor` · echo `echolocation` · greater: none.
- The rebirth pools keep `skills` and `level`; `affinity` goes. The pools themselves are replaced by altars in a later milestone, not here.
- `.tres` files under `data/forms/` are the source of truth for forms (the generator's header says "run once, then edit the .tres freely"): edit both the generator and the five files, and do not regenerate over hand edits.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`; work on a branch cut from `docs/design-direction`, not on `main`.
- Test commands: `tools/run_tests.sh <substring>` for a subset (a substring of the test file name), `TEST_TIMEOUT=900 tools/run_tests.sh` for the whole suite. Success prints `PASS: N tests`.

## Review Focus

1. **A player with no powers.** The default pool's kit is `{}` and a fresh life owns only Appraisal. Expect: `open_lineages` is empty and the offer is exactly `["greater_slime"]`, not an error and not an empty list (Task 3 tests).
2. **A power that evolved away.** After Poison Breath becomes Miasma the parent leaves `owned()` but keeps its level. Expect: Toxic stays open (Task 3, `level_of` stub test).
3. **A granted-but-undiscovered kit skill.** Kits grant skills quietly (`grant(id, false)`); the power is owned at level 1. Expect: it opens its lineage (Task 3, real-engine test with `grant(..., false)`).
4. **The Form tab with five offers.** The offer list can now hold five lineages. Expect: every offer is a selectable row and none is dropped (Task 3, `test_form_tab`).
5. **A shipped room or tool still naming `affinity`.** A leftover key must not crash anything. Expect: `RebirthKit.validate` ignores it, the three shipped pools carry none, and the closing grep finds no reader (Task 3).

---

## File map

- Modify `scripts/forms/form_def.gd` — add `powers`, later remove `essences`.
- Modify `scripts/forms/form_validator.gd` — the `powers` rule.
- Modify `scripts/forms/form_offers.gd` — rewritten (full new content below).
- Modify `scripts/player/player.gd` — `form_offers()`.
- Modify `scripts/world/rebirth_kit.gd` — drop `ESSENCES`, the affinity validation, `eligible_lineages`, the seed loop.
- Modify `scripts/actors/progression.gd` — drop `seeded`.
- Modify `tools/build_forms.gd` — `powers_of()` replaces `essences_of()`.
- Modify `data/forms/{weaver,tide,toxic,bulwark,echo}.tres` — `powers` replaces `essences`.
- Modify `data/rooms/{G1,F1,D1}.tres` — drop the kit `affinity` block.
- Modify tests: `test_forms`, `test_form_offers` (rewritten), `test_first_evolution_areas` (rewritten), `test_form_tab`, `test_rebirth_kit`, `test_rebirth_pool`, `test_rebirth_flow`, `test_room_edit_model`, `test_room_edit_fields`, `test_room_editor_scene`.
- Modify docs/comments: `scripts/editor/room_edit_model.gd` (one comment), `docs/playtest-checklist.md` (one line).

---

### Task 1: `FormDef.powers`, its data and its validator rule (additive)

`essences` stays on `FormDef` until Task 3 (`FormOffers` still reads it), so this task changes nothing that exists.

**Files:**
- Modify: `scripts/forms/form_def.gd`
- Modify: `scripts/forms/form_validator.gd`
- Modify: `tools/build_forms.gd`
- Modify: `data/forms/weaver.tres`, `tide.tres`, `toxic.tres`, `bulwark.tres`, `echo.tres`
- Test: `tests/test_forms.gd`

**Interfaces:**
- Consumes: `FormDef`, `FormValidator.validate(forms, skill_ids, check_art)`, `FormLoader.load_all()`.
- Produces: `FormDef.powers: Array` (skill ids; non-empty on the five stage-2 lineage forms, empty on every other form); `FormValidator` errors containing `only stage-2` and the unknown skill id.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_forms.gd`:

```gdscript
func test_every_lineage_form_names_the_powers_that_open_it() -> void:
	var expected := {
		"weaver": ["sticky_thread"],
		"tide": ["hydraulic_propulsion"],
		"toxic": ["poison_breath", "spore_cloud"],
		"bulwark": ["body_armor", "hardened_shell", "tremor"],
		"echo": ["echolocation"],
	}
	for id in expected:
		assert_eq((forms[id] as FormDef).powers, expected[id], id)
	for id in forms:
		if not expected.has(id):
			assert_eq((forms[id] as FormDef).powers, [], "%s opens nothing" % id)

func test_the_validator_rejects_an_unknown_power_and_a_power_on_a_later_stage() -> void:
	var bad := forms.duplicate()
	var weaver := (forms["weaver"] as FormDef).duplicate() as FormDef
	weaver.powers = ["no_such_skill"]
	bad["weaver"] = weaver
	assert_string_contains("\n".join(FormValidator.validate(bad, skill_ids)), "no_such_skill")
	var snare := (forms["snare"] as FormDef).duplicate() as FormDef
	snare.powers = ["sticky_thread"]
	bad = forms.duplicate()
	bad["snare"] = snare
	assert_string_contains("\n".join(FormValidator.validate(bad, skill_ids)), "only stage-2")
	var empty := (forms["echo"] as FormDef).duplicate() as FormDef
	empty.powers = []
	bad = forms.duplicate()
	bad["echo"] = empty
	assert_string_contains("\n".join(FormValidator.validate(bad, skill_ids)), "opening power")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh test_forms`
Expected: `FAIL: engine error or empty run` with an `Invalid access to property or key 'powers'` line (the property does not exist yet).

- [ ] **Step 3: Add the property, the validator rule, the generator table and the data**

In `scripts/forms/form_def.gd`, after the `essences` export, add:

```gdscript
## The skills that open this lineage (stage-2 lineage forms only): reaching any of them, or having evolved one, offers the lineage.
@export var powers: Array = []
```

In `scripts/forms/form_validator.gd`, after the `for t in f.traits:` loop, insert:

```gdscript
		if f.stage == 2 and f.lineage != "greater":
			if f.powers.is_empty():
				errs.append("%s: a lineage form needs at least one opening power" % id)
		elif not f.powers.is_empty():
			errs.append("%s: only stage-2 lineage forms list powers" % id)
		for p in f.powers:
			if not skill_ids.has(p):
				errs.append("%s: lists unknown power '%s'" % [id, p])
```

In `tools/build_forms.gd`, replace

```gdscript
		if f.stage == 2 and f.lineage != "greater":
			f.essences = essences_of(f.lineage)
```

with

```gdscript
		if f.stage == 2 and f.lineage != "greater":
			f.essences = essences_of(f.lineage)
			f.powers = powers_of(f.lineage)
```

and append at the end of the file:

```gdscript

static func powers_of(lineage: String) -> Array:
	match lineage:
		"weaver":
			return ["sticky_thread"]
		"tide":
			return ["hydraulic_propulsion"]
		"toxic":
			return ["poison_breath", "spore_cloud"]
		"bulwark":
			return ["body_armor", "hardened_shell", "tremor"]
		"echo":
			return ["echolocation"]
	return []
```

Add the property to the five data files without regenerating (the files are hand-editable; a regeneration could clobber edits). Run:

```bash
python3 - <<'EOF'
rows = {
    "weaver": '["sticky_thread"]',
    "tide": '["hydraulic_propulsion"]',
    "toxic": '["poison_breath", "spore_cloud"]',
    "bulwark": '["body_armor", "hardened_shell", "tremor"]',
    "echo": '["echolocation"]',
}
for lineage, powers in rows.items():
    path = f"data/forms/{lineage}.tres"
    text = open(path).read()
    lines = text.split("\n")
    out = []
    for line in lines:
        out.append(line)
        if line.startswith("essences = "):
            out.append(f"powers = {powers}")
    assert any(l.startswith("powers = ") for l in out), path
    open(path, "w").write("\n".join(out))
EOF
git diff --stat data/forms
```

Expected: five files changed, one inserted line each.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh test_forms`
Expected: `PASS: <n> tests`

- [ ] **Step 5: Commit**

```bash
git add scripts/forms/form_def.gd scripts/forms/form_validator.gd tools/build_forms.gd data/forms tests/test_forms.gd
git commit -m "feat: forms name the powers that open their lineage"
```

---

### Task 2: Free the room-editor tests from G1's affinity (they pass before and after)

Three editor tests used G1's `affinity` as the probe for "an unrelated kit key survives an edit". Task 3 deletes the key, so the probes move to a key the tests set themselves, while the data still holds `affinity` and everything stays green.

**Files:**
- Test: `tests/test_room_edit_model.gd`, `tests/test_room_edit_fields.gd`, `tests/test_room_editor_scene.gd`

**Interfaces:**
- Consumes: `RoomEditModel.set_field`, `get_field`, `rooms`, `ShippedRooms.load_all()`.
- Produces: tests that depend on no shipped kit key other than `skills` and `level`.

- [ ] **Step 1: Rewrite the three probes**

In `tests/test_room_edit_model.gd`, replace `_kit_pool` and `test_a_nested_value_is_copied_too` with:

```gdscript
func _kit_pool(rooms: Dictionary) -> Dictionary:
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			if f.get("kind", "") == "rebirth_pool" and (f["kit"] as Dictionary).has("skills"):
				return {"room": id, "feature": f}
	return {}

func test_a_nested_value_is_copied_too() -> void:
	var original := _kit_pool(source)
	assert_false(original.is_empty(), "a shipped room has a rebirth pool whose kit lists skills")
	var copy := _kit_pool(model.rooms)
	var before: Array = original["feature"]["kit"]["skills"].duplicate()
	copy["feature"]["kit"]["skills"].append("zzz")
	assert_eq(original["feature"]["kit"]["skills"], before)
```

In `tests/test_room_edit_fields.gd`, replace `test_a_pools_level_and_skills_merge_into_the_kit_and_keep_the_rest` with:

```gdscript
func test_a_pools_level_and_skills_merge_into_the_kit_and_keep_the_rest() -> void:
	var sel := _feature_sel("G1", "rebirth_pool")
	model.rooms["G1"].features[sel["index"]]["kit"]["note"] = "keep me"
	assert_eq(model.set_field(sel, "kit_level", 5), "")
	assert_eq(model.get_field(sel, "kit_level"), 5)
	assert_eq(model.set_field(sel, "kit_skills", ["leap"]), "")
	assert_eq(model.get_field(sel, "kit_skills"), ["leap"])
	assert_eq(model.rooms["G1"].features[sel["index"]]["kit"].get("note", ""), "keep me", "another kit key survives every edit")
	assert_eq(model.set_field(sel, "kit_level", 0), "", "0 unsets the level")
	assert_false(model.rooms["G1"].features[sel["index"]]["kit"].has("level"))
```

In `tests/test_room_editor_scene.gd`, replace the head and the two affinity lines of `test_ticking_a_skill_and_choosing_a_level_write_the_kit_and_keep_the_affinity`:

```gdscript
func test_ticking_a_skill_and_choosing_a_level_write_the_kit_and_keep_the_rest() -> void:
	var idx: int = model.rooms["G1"].features.find_custom(func(f): return f["kind"] == "rebirth_pool")
	var sel := {"room": "G1", "kind": "feature", "index": idx}
	model.rooms["G1"].features[idx]["kit"]["note"] = "keep me"
```

(the line `var affinity: Dictionary = ...` is deleted) and replace the final assertion `assert_eq(model.rooms["G1"].features[idx]["kit"].get("affinity", {}), affinity)` with:

```gdscript
	assert_eq(model.rooms["G1"].features[idx]["kit"].get("note", ""), "keep me")
```

- [ ] **Step 2: Run the three files**

Run: `tools/run_tests.sh test_room_edit` then `tools/run_tests.sh test_room_editor_scene`
Expected: `PASS: <n> tests` for each (the data still has `affinity`; the probes no longer need it).

- [ ] **Step 3: Commit**

```bash
git add tests/test_room_edit_model.gd tests/test_room_edit_fields.gd tests/test_room_editor_scene.gd
git commit -m "test: the editor tests probe their own kit key, not G1's affinity"
```

---

### Task 3: Offer every open lineage and delete the affinity machinery (one atomic change)

`FormOffers.supply`, `affinity` and `absorbed_units` are read by `RebirthKit.eligible_lineages`, `Player.form_offers` and several tests; `FormDef.essences` is read by `FormOffers`; `Progression.seeded` is read by `Player` and `RebirthKit.apply`. Any partial removal is a parse error, so this task changes all of them together.

**Files:**
- Modify (rewrite): `scripts/forms/form_offers.gd`
- Modify: `scripts/forms/form_def.gd`, `tools/build_forms.gd`, `data/forms/{weaver,tide,toxic,bulwark,echo}.tres`
- Modify: `scripts/player/player.gd:561-568`
- Modify: `scripts/world/rebirth_kit.gd`, `scripts/actors/progression.gd`
- Modify: `data/rooms/G1.tres`, `data/rooms/F1.tres`, `data/rooms/D1.tres`
- Modify: `scripts/editor/room_edit_model.gd:625` (comment), `docs/playtest-checklist.md:100`
- Test: `tests/test_form_offers.gd` (rewrite), `tests/test_first_evolution_areas.gd` (rewrite), `tests/test_form_tab.gd`, `tests/test_rebirth_kit.gd`, `tests/test_rebirth_pool.gd`, `tests/test_rebirth_flow.gd`

**Interfaces:**
- Consumes: `FormDef.powers` (Task 1), `SkillRulesEngine.level_of(id) -> int`, `FormLoader.stage2_forms(forms)`, `FormLoader.children_of(forms, id)`, `Form.stage`, `Form.form_id`.
- Produces: `FormOffers.LINEAGE_ORDER: Array`, `FormOffers.FALLBACK: String`, `FormOffers.lineage_powers(forms: Dictionary) -> Dictionary` (lineage → Array of skill ids), `FormOffers.open_lineages(forms: Dictionary, rules) -> Array` (lineage ids in `LINEAGE_ORDER`), `FormOffers.offers(forms: Dictionary, form: Form, rules) -> Array` (form ids). Part 3 of the overhaul and the skill tree plan rely on these exact names and signatures.

- [ ] **Step 1: Rewrite the two offer tests first (they fail against the old code)**

Replace the whole of `tests/test_form_offers.gd` with:

```gdscript
extends GutTest
## Which bodies a slime is offered when it can evolve: every lineage whose power it has reached.

## A stand-in for SkillRulesEngine: FormOffers only asks level_of.
class FakeRules:
	var levels := {}
	func level_of(id: String) -> int:
		return int(levels.get(id, 0))

var forms := {}

func before_all() -> void:
	forms = FormLoader.load_all()

func _rules(levels: Dictionary) -> FakeRules:
	var r := FakeRules.new()
	r.levels = levels
	return r

func test_lineage_powers_are_read_from_the_stage_two_forms() -> void:
	var p := FormOffers.lineage_powers(forms)
	assert_eq(p["weaver"], ["sticky_thread"])
	assert_eq(p["toxic"], ["poison_breath", "spore_cloud"])
	assert_eq(p["bulwark"], ["body_armor", "hardened_shell", "tremor"])
	assert_false(p.has("greater"), "the Greater lineage opens on nothing")

func test_a_lineage_is_open_when_one_of_its_powers_has_been_reached() -> void:
	assert_eq(FormOffers.open_lineages(forms, _rules({})), [])
	assert_eq(FormOffers.open_lineages(forms, _rules({"sticky_thread": 1})), ["weaver"])
	assert_eq(FormOffers.open_lineages(forms, _rules({"spore_cloud": 2})), ["toxic"], "either of Toxic's powers opens it")

func test_a_power_that_evolved_away_still_opens_its_lineage() -> void:
	# level_of keeps answering the level a retired parent reached, so Poison Breath becoming Miasma does not close Toxic
	assert_eq(FormOffers.open_lineages(forms, _rules({"poison_breath": 4})), ["toxic"])

func test_open_lineages_come_back_in_lineage_order_whatever_was_reached_first() -> void:
	var r := _rules({"echolocation": 5, "tremor": 1, "hydraulic_propulsion": 3, "sticky_thread": 2})
	assert_eq(FormOffers.open_lineages(forms, r), ["weaver", "tide", "bulwark", "echo"])

func test_every_open_lineage_is_offered_with_no_cap_and_no_ranking() -> void:
	var all := _rules({"sticky_thread": 1, "hydraulic_propulsion": 1, "poison_breath": 1, "body_armor": 1, "echolocation": 1})
	assert_eq(FormOffers.offers(forms, Form.new(), all), ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_nothing_reached_offers_only_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({})), ["greater_slime"])

func test_one_open_lineage_is_offered_with_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({"echolocation": 1})), ["echo", "greater_slime"])

func test_two_open_lineages_never_add_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({"echolocation": 1, "tremor": 1})), ["bulwark", "echo"])

func test_stage_two_offers_its_two_children_stage_three_its_sovereign_stage_four_nothing() -> void:
	var f := Form.new()
	var none := _rules({})
	f.advance("weaver", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["arachne", "snare"])
	f.advance("snare", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["silkbound"])
	f.advance("silkbound", forms)
	assert_eq(FormOffers.offers(forms, f, none), [])

func test_greater_slime_leads_to_vast_and_radiant_then_prime() -> void:
	var f := Form.new()
	var none := _rules({})
	f.advance("greater_slime", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["radiant", "vast"])
	f.advance("vast", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["prime"])

func test_a_real_engine_opens_a_lineage_when_a_power_is_granted_quietly() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	rules.start_run()
	assert_eq(FormOffers.open_lineages(forms, rules), [], "a fresh life owns only Appraisal")
	rules.grant("hydraulic_propulsion", false)  # a rebirth kit's way of giving a skill
	assert_eq(FormOffers.open_lineages(forms, rules), ["tide"])
```

Replace the whole of `tests/test_first_evolution_areas.gd` with (the supply tests go; the stage-1 cap check stays, with its own area list):

```gdscript
extends GutTest
## The areas a stage-1 life plays before its first evolution reach stage 1's cap, and the cap lands in the last of them.

## The Cave and the Grotto. (This list lived on FormOffers while the affinity ratio divided by their supply.)
const FIRST_EVOLUTION_AREAS := ["cave", "grotto"]

func _creatures() -> Dictionary:
	var out := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		out[c.id] = c
	return out

func test_the_first_evolution_areas_are_derived_not_trusted() -> void:
	# the ungated first-time XP of these areas reaches stage 1's cap, and without the last area it does not
	var rooms := ShippedRooms.load_all()
	var creatures := _creatures()
	var reach := WorldValidator.reachable(rooms, true)
	var by_area := {}
	for id in reach:
		var r: RoomDef = rooms[id]
		for s in r.spawns:
			var c: CreatureDef = creatures[s["id"]]
			by_area[r.area] = int(by_area.get(r.area, 0)) + c.xp * (1 if c.id == "water_pool" else 2)
	var total := 0
	for a in FIRST_EVOLUTION_AREAS:
		total += int(by_area.get(a, 0))
	assert_gte(total, Progression.stage_total(1), "cave plus grotto reach the cap")
	var without_last: int = total - int(by_area.get(FIRST_EVOLUTION_AREAS.back(), 0))
	assert_lt(without_last, Progression.stage_total(1), "the cap lands in the last of them")
```

- [ ] **Step 2: Run both to verify they fail**

Run: `tools/run_tests.sh test_form_offers`
Expected: `FAIL: engine error or empty run` (`FormOffers.lineage_powers` and `open_lineages` do not exist; `offers` takes four arguments).

- [ ] **Step 3: Rewrite `scripts/forms/form_offers.gd` in full**

```gdscript
class_name FormOffers
extends RefCounted
## Which bodies the slime is offered when it can evolve. Pure functions over data.
##   Stage 1 to 2: every lineage whose power the player has reached (open_lineages), in LINEAGE_ORDER, plus the
##     Greater Slime fallback when fewer than two lineages are open. No ranking and no cap.
##   Stage 2 to 3: the form's two children. Stage 3 to 4: the lineage's one Sovereign. Stage 4: none.

const LINEAGE_ORDER := ["weaver", "tide", "toxic", "bulwark", "echo"]
const FALLBACK := "greater_slime"

## lineage -> the skill ids that open it, read from the stage-2 forms (the Greater lineage opens on nothing).
static func lineage_powers(forms: Dictionary) -> Dictionary:
	var out := {}
	for f in FormLoader.stage2_forms(forms):
		if (f as FormDef).lineage != "greater":
			out[(f as FormDef).lineage] = (f as FormDef).powers
	return out

## The lineages the player has opened this life, in LINEAGE_ORDER. A lineage is open when any of its powers has been reached:
## `rules.level_of` keeps answering the level a retired parent reached, so an evolved power still opens its lineage.
static func open_lineages(forms: Dictionary, rules) -> Array:
	var powers := lineage_powers(forms)
	var out: Array = []
	for l in LINEAGE_ORDER:
		if not powers.has(l) or not forms.has(l):
			continue
		for p in powers[l]:
			if rules.level_of(p) > 0:
				out.append(l)
				break
	return out

## The form ids on offer for `form` (a Form), given the rules state.
static func offers(forms: Dictionary, form: Form, rules) -> Array:
	if form.stage == 1:
		return _first_offers(forms, rules)
	var out: Array = []
	for k in FormLoader.children_of(forms, form.form_id):
		out.append((k as FormDef).id)
	return out

static func _first_offers(forms: Dictionary, rules) -> Array:
	var out := open_lineages(forms, rules)
	if out.size() < 2 and forms.has(FALLBACK):
		out.append(FALLBACK)
	return out
```

- [ ] **Step 4: Switch the player, the form def, the generator and the five form files**

In `scripts/player/player.gd`, replace the loop line in `form_offers()`:

```gdscript
	for id in FormOffers.offers(forms, form, FormOffers.absorbed_units(_rules, progression.seeded), FormOffers.default_supply(forms)):
```

with:

```gdscript
	for id in FormOffers.offers(forms, form, _rules):
```

In `scripts/forms/form_def.gd`, delete these two lines:

```gdscript
## The essences that make this lineage's affinity (stage-2 forms only).
@export var essences: Array = []
```

In `tools/build_forms.gd`, delete the line `f.essences = essences_of(f.lineage)` (keep `f.powers = powers_of(f.lineage)`), and delete the whole `static func essences_of(lineage: String) -> Array:` function at the end of the file.

Remove the `essences` line from the five data files:

```bash
python3 - <<'EOF'
for lineage in ["weaver", "tide", "toxic", "bulwark", "echo"]:
    path = f"data/forms/{lineage}.tres"
    lines = open(path).read().split("\n")
    kept = [l for l in lines if not l.startswith("essences = ")]
    assert len(kept) == len(lines) - 1, path
    open(path, "w").write("\n".join(kept))
EOF
git diff --stat data/forms
```

Expected: five files, one deleted line each.

- [ ] **Step 5: Delete the kit affinity and the seeds**

In `scripts/world/rebirth_kit.gd`, make these exact replacements.

Header (lines 3-4):

```gdscript
## A rebirth pool's head start: {"skills": [ids], "level": int, "affinity": {essence: units}}. All keys
## are optional (the Cave mouth's kit is {}). validate() checks the data; apply() (below) gives it.
```

becomes

```gdscript
## A rebirth pool's head start: {"skills": [ids], "level": int}. Both keys are optional (the Cave mouth's
## kit is {}). validate() checks the data; apply() (below) gives it.
```

Delete the constant and its comment:

```gdscript
## Essences a kit may seed (the forms' lineages read these).
const ESSENCES := ["sound", "flight", "poison", "water", "armor", "earth", "thread", "spore", "shell"]

```

Delete the affinity block of `validate` (everything from `var seeds = kit.get("affinity", {})` through the closing `errs.append("kit affinity for '%s' has negative units" % e)`), so the function ends with the level check and `return errs`.

Delete the whole function `eligible_lineages` and its doc comment (`## How many lineages a seeded affinity leaves eligible ...` through its `return n`).

In `apply`, change the doc comment tail from `a starting level gives its bonuses but no EP; seeded affinity counts for the first\n## evolution only.` to `a starting level gives its bonuses but no EP.`, and delete these three lines:

```gdscript
	var seeds: Dictionary = kit.get("affinity", {})
	for e in seeds:
		player.progression.seeded[e] = int(player.progression.seeded.get(e, 0)) + int(seeds[e])
```

In `scripts/actors/progression.gd`, delete:

```gdscript
## Essence units a rebirth kit seeded: they count toward the first evolution's affinity and nothing else.
var seeded := {}
```

Remove the `affinity` block from the three pool rooms:

```bash
python3 - <<'EOF'
import re
for room in ["G1", "F1", "D1"]:
    path = f"data/rooms/{room}.tres"
    text = open(path).read()
    new = re.sub(r'"affinity": \{\n(?:"[a-z]+": \d+,?\n)+\},\n', "", text)
    assert new != text, path
    open(path, "w").write(new)
EOF
git diff data/rooms | grep '^[-+]' | grep -v '^+++\|^---'
```

Expected: only the removed `affinity` lines for each room.

Update the comment at `scripts/editor/room_edit_model.gd:625`: replace `merged into the kit so every other key (G1's affinity) is kept;` with `merged into the kit so every other key is kept;`. In `docs/playtest-checklist.md:100` replace `G1's affinity is untouched in the saved file.` with `G1's other kit keys are untouched in the saved file.`

- [ ] **Step 6: Fix the tests that read the removed members**

`tests/test_form_tab.gd`: replace the line

```gdscript
	var expected := FormOffers.offers(player.forms, player.form, FormOffers.absorbed_units(rules), FormOffers.default_supply(player.forms))
```

with

```gdscript
	var expected := FormOffers.offers(player.forms, player.form, rules)
```

`tests/test_rebirth_pool.gd`:
- in `test_the_validator_accepts_a_good_pool` change the kit to `{"skills": ["leap"], "level": 3}`;
- in `test_the_validator_names_each_mistake` delete the two lines that assert `"essence"` and `"units"` for `affinity`;
- in `test_the_validator_names_malformed_pool_data_instead_of_crashing` delete the `assert_string_contains(... {"affinity": [1]} ..., "affinity")` line.

`tests/test_rebirth_flow.gd`, in `test_a_kit_applies_after_start_run_and_never_survives_into_the_next_life`: change the kit to `{"skills": ["leap"], "level": 3}` and delete the line `assert_true(player.progression.seeded.is_empty())`.

`tests/test_rebirth_kit.gd`:
- change the file's header comment to `## A rebirth pool's head start: granted skills that count as known but not discovered, and a starting level without EP.`;
- in `after_each` delete the line `FormOffers._default_supply = {}  # forget a supply ...`;
- delete the helper `_pin_supply_to_the_shipped_rooms` and its comment;
- delete `test_seeded_affinity_counts_toward_the_first_evolution_and_nothing_else`;
- replace `test_applying_a_kit_after_a_second_run_start_does_not_stack` with:

```gdscript
func test_applying_a_kit_after_a_second_run_start_does_not_stack() -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"], "level": 3})
	rules.start_run()
	assert_eq(player.progression.level, 1)
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"], "level": 3})
	assert_eq(player.progression.level, 3)
	assert_eq(player.stats.level_bonus("max_hp"), 2 * Player.LEVEL_UP_BONUS["max_hp"])
```

- in `test_an_empty_kit_changes_nothing` delete the `seeded.is_empty()` line;
- replace `test_kit_validation_accepts_good_kits_and_names_bad_ones` with:

```gdscript
func test_kit_validation_accepts_good_kits_and_names_bad_ones() -> void:
	assert_eq(RebirthKit.validate({"skills": ["leap", "wall_cling"], "level": 3}).size(), 0)
	assert_gt(RebirthKit.validate({"skills": ["nope"]}).size(), 0)
	assert_gt(RebirthKit.validate({"level": 11}).size(), 0)
	assert_eq(RebirthKit.validate({"affinity": {"bogus": 1}}).size(), 0, "a leftover key is ignored, not an error")
```

- delete `test_the_eligibility_check_bites_on_a_poorly_seeded_kit`, `_units`, and `test_every_pool_leaves_two_lineages_eligible_and_its_seeds_matter`; keep `_creatures`, `AREA_KITS` and the tests after it;
- add near the top of the file, below the `var player` declarations: `const FIRST_EVOLUTION_AREAS := ["cave", "grotto"]` and replace both `FormOffers.FIRST_EVOLUTION_AREAS` uses (in `test_every_kits_xp_to_the_cap_is_within_the_first_evolution_areas_total` and `test_the_flooded_alone_does_not_fill_an_f1_lifes_first_stage`) with `FIRST_EVOLUTION_AREAS`;
- add this test at the end of the file:

```gdscript
func test_no_shipped_pool_carries_a_seeded_affinity() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	for p in RebirthChoice.pools(rooms):
		assert_false((p["kit"] as Dictionary).has("affinity"), "pool %s" % p["id"])
```

- [ ] **Step 7: Run the affected tests**

Run each: `tools/run_tests.sh test_form_offers`, `tools/run_tests.sh test_first_evolution`, `tools/run_tests.sh test_form_tab`, `tools/run_tests.sh test_rebirth`, `tools/run_tests.sh test_room_edit`, `tools/run_tests.sh test_forms`
Expected: `PASS: <n> tests` for each. `test_form_tab` offers: its `_eat_everything` feeds trait essences, which still exist in this part, so the skills unlock as before and the five lineages are offered.

- [ ] **Step 8: Closing grep and the full suite**

Run:

```bash
grep -rnE "FormOffers\.(supply|default_supply|affinity|absorbed_units|ELIGIBLE|MAX_OFFERS|FIRST_EVOLUTION_AREAS)|progression\.seeded|\.seeded\b|eligible_lineages|RebirthKit\.ESSENCES|essences_of" scripts tests tools docs/playtest-checklist.md --include='*.gd' --include='*.md'
```

Expected: no output (the specs, plans and ledgers under `docs/superpowers` and `docs/ledgers` may still mention the old names as history).

Run: `TEST_TIMEOUT=900 tools/run_tests.sh`
Expected: `PASS: <n> tests` with no `SCRIPT ERROR`.

- [ ] **Step 9: Commit**

```bash
git add -A scripts tests tools data docs/playtest-checklist.md
git commit -m "feat: the first evolution offers every lineage whose power you reached

Forms name their opening powers, FormOffers.open_lineages replaces the
affinity ratio, and the supply, affinity, seeded-essence and kit-affinity
machinery goes with it."
```

---

## Self-Review

**Spec coverage** (essence overhaul spec, step 1 of "Sequencing" and the rows it names):

| Spec requirement | Task |
|---|---|
| `FormDef.essences` becomes `FormDef.powers`; generator and `.tres` updated | 1, 3 |
| `FormValidator` rule for `powers` (known skill ids, stage-2 only) | 1 |
| `FormOffers.open_lineages` public, in `LINEAGE_ORDER`; no ranking, no cap; Greater Slime when fewer than two open | 3 |
| `MAX_OFFERS`, `ELIGIBLE`, `supply`, `default_supply`, `affinity`, `absorbed_units`, `FIRST_EVOLUTION_AREAS`, `Progression.seeded` removed | 3 |
| Kits keep `skills` and `level`, lose `affinity`; `eligible_lineages` and `ESSENCES` removed | 3 |
| Room editor: comment and tests that probed G1's affinity | 2, 3 |
| `test_first_evolution_areas` keeps its cap check with the constant in the test | 3 |
| Closing grep for the retired names | 3 |

Not in this part (parts 2 and 3): the element vocabulary, mixes, the calibration, the price, `held`, EP removal, the HUD line, hints and wording.

**Placeholder scan:** none; every code step carries its code, and every deletion names the exact text.

**Type consistency:** `open_lineages(forms: Dictionary, rules) -> Array` and `offers(forms: Dictionary, form: Form, rules) -> Array` are defined in Task 3 and are the only names later parts and the tree plan consume; `lineage_powers(forms) -> Dictionary` is used by `open_lineages` and by its own test; `FormDef.powers` is defined in Task 1 and read in Task 3.
